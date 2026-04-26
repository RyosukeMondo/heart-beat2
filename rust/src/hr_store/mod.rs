//! Heart rate persistent store.
//!
//! Append-only JSONL writer that creates one file per local day at
//! `<app_docs>/hr/YYYY-MM-DD.jsonl`. Each line: `{ts_ms, bpm, rr?}`.
//! Flush on every write; rotate automatically when the local date changes.

use anyhow::{Context, Result};
use serde::Serialize;
use std::path::PathBuf;
use tokio::fs::{File, OpenOptions};
use tokio::io::{AsyncReadExt, AsyncWriteExt};

/// A single HR sample for JSON serialization.
#[derive(Serialize)]
struct SampleRecord<'a> {
    ts_ms: u64,
    bpm: u16,
    #[serde(skip_serializing_if = "Option::is_none")]
    rr: Option<&'a [u16]>,
}

/// Thread-safe handle to the HR store.
///
/// Created once via `HrStore::new` and reused across all samples.
/// Internally re-opens the file if the local date has rolled over.
pub struct HrStore {
    /// Directory containing daily `.jsonl` files.
    hr_dir: PathBuf,
    /// Path to today's file (updated on rotation).
    #[allow(dead_code)]
    today_path: PathBuf,
}

impl HrStore {
    /// Open (or create) the HR store under `data_dir/hr/`.
    ///
    /// Creates the `hr/` subdirectory if it does not exist.
    pub async fn new(data_dir: PathBuf) -> Result<Self> {
        let hr_dir = data_dir.join("hr");
        tokio::fs::create_dir_all(&hr_dir)
            .await
            .with_context(|| format!("Failed to create hr directory: {:?}", hr_dir))?;

        let today_path = Self::today_path(&hr_dir);

        Ok(Self {
            hr_dir,
            today_path,
        })
    }

    /// Returns the path where today's file should live.
    fn today_path(hr_dir: &PathBuf) -> PathBuf {
        let today = chrono::Local::now().format("%Y-%m-%d").to_string();
        hr_dir.join(format!("{}.jsonl", today))
    }

    /// Append a single sample to the store, rotating the file if midnight has passed.
    ///
    /// The line is immediately flushed (`sync_all`) to guarantee durability.
    pub async fn append(&self, ts_ms: u64, bpm: u16, rr_intervals: Option<&[u16]>) -> Result<()> {
        let expected = Self::today_path(&self.hr_dir);
        let mut file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(&expected)
            .await
            .with_context(|| format!("Failed to open hr file: {:?}", expected))?;

        let line = self.format_line(ts_ms, bpm, rr_intervals)?;
        file.write_all(line.as_bytes()).await?;
        file.write_all(b"\n").await?;
        file.sync_all().await?;
        Ok(())
    }

    fn format_line(
        &self,
        ts_ms: u64,
        bpm: u16,
        rr_intervals: Option<&[u16]>,
    ) -> Result<String> {
        let record = SampleRecord {
            ts_ms,
            bpm,
            rr: rr_intervals,
        };
        serde_json::to_string(&record).context("Failed to serialize HR sample")
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[tokio::test]
    async fn test_append_creates_file() {
        let dir = TempDir::new().unwrap();
        let data_dir = dir.path().to_path_buf();

        let store = HrStore::new(data_dir.clone()).await.unwrap();

        store.append(1000, 72, None).await.unwrap();

        let today = chrono::Local::now().format("%Y-%m-%d").to_string();
        let expected_path = data_dir.join("hr").join(format!("{}.jsonl", today));

        // Debug: print directory contents
        let mut entries = tokio::fs::read_dir(&data_dir).await.unwrap();
        while let Some(entry) = entries.next_entry().await.unwrap() {
            eprintln!("DIR CONTENTS: {:?}", entry.path());
        }

        assert!(expected_path.exists(), "File not found at {:?}", expected_path);
    }

    #[tokio::test]
    async fn test_append_writes_valid_jsonl() {
        let dir = TempDir::new().unwrap();
        let store = HrStore::new(dir.path().to_path_buf()).await.unwrap();

        store.append(1000, 72, Some(&[820, 830])).await.unwrap();
        store.append(2000, 75, None).await.unwrap();

        let today = chrono::Local::now().format("%Y-%m-%d").to_string();
        let file_path = dir.path().join("hr").join(format!("{}.jsonl", today));

        let mut contents = String::new();
        File::open(&file_path)
            .await
            .unwrap()
            .read_to_string(&mut contents)
            .await
            .unwrap();

        let lines: Vec<&str> = contents.lines().collect();
        assert_eq!(lines.len(), 2);

        // Each line should be valid JSON
        for line in &lines {
            let _: serde_json::Value = serde_json::from_str(line).unwrap();
        }

        // First line should have ts_ms, bpm, and rr
        let first: serde_json::Value = serde_json::from_str(lines[0]).unwrap();
        assert_eq!(first["ts_ms"], 1000);
        assert_eq!(first["bpm"], 72);
        assert_eq!(first["rr"], serde_json::json!([820, 830]));

        // Second line should NOT have rr field
        let second: serde_json::Value = serde_json::from_str(lines[1]).unwrap();
        assert_eq!(second["ts_ms"], 2000);
        assert_eq!(second["bpm"], 75);
        assert!(second.get("rr").is_none() || second["rr"].is_null());
    }

    #[tokio::test]
    async fn test_flush_on_every_write() {
        let dir = TempDir::new().unwrap();
        let store = HrStore::new(dir.path().to_path_buf()).await.unwrap();

        // Write a sample and sync
        store.append(1000, 70, None).await.unwrap();

        let today = chrono::Local::now().format("%Y-%m-%d").to_string();
        let file_path = dir.path().join("hr").join(format!("{}.jsonl", today));

        // Verify file is readable immediately after append returns
        let mut contents = String::new();
        File::open(&file_path)
            .await
            .unwrap()
            .read_to_string(&mut contents)
            .await
            .unwrap();

        assert!(contents.contains("70"));
    }

    #[tokio::test]
    async fn test_multiple_samples_same_file() {
        let dir = TempDir::new().unwrap();
        let store = HrStore::new(dir.path().to_path_buf()).await.unwrap();

        for i in 0..100 {
            store.append(i * 1000, 60 + (i % 40) as u16, None).await.unwrap();
        }

        let today = chrono::Local::now().format("%Y-%m-%d").to_string();
        let file_path = dir.path().join("hr").join(format!("{}.jsonl", today));

        let mut contents = String::new();
        File::open(&file_path)
            .await
            .unwrap()
            .read_to_string(&mut contents)
            .await
            .unwrap();

        let lines: Vec<&str> = contents.lines().collect();
        assert_eq!(lines.len(), 100);
    }
}
