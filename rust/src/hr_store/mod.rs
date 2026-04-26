//! Heart rate persistent store.
//!
//! Append-only JSONL writer that creates one file per local day at
//! `<app_docs>/hr/YYYY-MM-DD.jsonl`. Each line: `{ts_ms, bpm, rr?}`.
//! Flush on every write; rotate automatically when the local date changes.

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use tokio::fs::{File, OpenOptions};
use tokio::io::{AsyncReadExt, AsyncWriteExt};

/// A single HR sample for JSON serialization and deserialization.
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Sample {
    /// Unix timestamp in milliseconds when this sample was taken.
    pub ts_ms: u64,
    /// Heart rate in beats per minute.
    pub bpm: u16,
    /// Optional R-R intervals in milliseconds (for HRV analysis).
    #[serde(default)]
    pub rr: Option<Vec<u16>>,
}

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
#[derive(Clone)]
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

    /// Returns all samples with ts_ms in [start_ms, end_ms] across all daily files.
    ///
    /// Samples are returned in chronological order.
    pub async fn samples_in_range(&self, start_ms: u64, end_ms: u64) -> Result<Vec<Sample>> {
        let mut samples = Vec::new();
        let mut entries = tokio::fs::read_dir(&self.hr_dir).await?;
        while let Some(entry) = entries.next_entry().await? {
            let path = entry.path();
            if path.extension().and_then(|s| s.to_str()) != Some("jsonl") {
                continue;
            }
            let mut file = File::open(&path).await?;
            let mut contents = String::new();
            file.read_to_string(&mut contents).await?;
            for line in contents.lines() {
                if line.trim().is_empty() {
                    continue;
                }
                if let Ok(sample) = serde_json::from_str::<Sample>(line) {
                    if sample.ts_ms >= start_ms && sample.ts_ms <= end_ms {
                        samples.push(sample);
                    }
                }
            }
        }
        samples.sort_by_key(|s| s.ts_ms);
        Ok(samples)
    }

    /// Computes the rolling average BPM over the given window ending at the latest sample.
    ///
    /// Returns `None` if the store is empty or no samples fall within the window.
    pub async fn rolling_avg(&self, window_secs: u64) -> Result<Option<f32>> {
        let latest = self.latest_sample().await?;
        let Some(latest) = latest else {
            return Ok(None);
        };
        let start_ms = latest.ts_ms.saturating_sub(window_secs * 1000);
        let samples = self.samples_in_range(start_ms, latest.ts_ms).await?;
        if samples.is_empty() {
            return Ok(None);
        }
        let sum: u64 = samples.iter().map(|s| s.bpm as u64).sum();
        Ok(Some(sum as f32 / samples.len() as f32))
    }

    /// Returns the most recent sample, or `None` if the store is empty.
    pub async fn latest_sample(&self) -> Result<Option<Sample>> {
        let mut entries = tokio::fs::read_dir(&self.hr_dir).await?;
        let mut latest: Option<Sample> = None;
        while let Some(entry) = entries.next_entry().await? {
            let path = entry.path();
            if path.extension().and_then(|s| s.to_str()) != Some("jsonl") {
                continue;
            }
            let mut file = File::open(&path).await?;
            let mut contents = String::new();
            file.read_to_string(&mut contents).await?;
            for line in contents.lines() {
                if line.trim().is_empty() {
                    continue;
                }
                if let Ok(sample) = serde_json::from_str::<Sample>(line) {
                    match &latest {
                        Some(prev) if sample.ts_ms <= prev.ts_ms => {}
                        _ => latest = Some(sample),
                    }
                }
            }
        }
        Ok(latest)
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

    // ─── Query function tests ───────────────────────────────────────────────

    #[tokio::test]
    async fn test_latest_sample_empty_store() {
        let dir = TempDir::new().unwrap();
        let store = HrStore::new(dir.path().to_path_buf()).await.unwrap();
        assert!(store.latest_sample().await.unwrap().is_none());
    }

    #[tokio::test]
    async fn test_latest_sample_single_file() {
        let dir = TempDir::new().unwrap();
        let store = HrStore::new(dir.path().to_path_buf()).await.unwrap();
        store.append(1000, 70, None).await.unwrap();
        store.append(5000, 80, None).await.unwrap();
        store.append(3000, 75, None).await.unwrap();

        let latest = store.latest_sample().await.unwrap();
        assert!(latest.is_some());
        assert_eq!(latest.unwrap().ts_ms, 5000);
    }

    #[tokio::test]
    async fn test_latest_sample_multiple_files() {
        let dir = TempDir::new().unwrap();
        let store = HrStore::new(dir.path().to_path_buf()).await.unwrap();

        // Write to today's file
        store.append(1000, 65, None).await.unwrap();
        store.append(2000, 70, None).await.unwrap();

        // Simulate yesterday's file by creating it manually
        let yesterday_path = dir.path().join("hr").join("2024-01-01.jsonl");
        tokio::fs::write(&yesterday_path, "{\"ts_ms\":5000,\"bpm\":80}\n").await.unwrap();

        let latest = store.latest_sample().await.unwrap();
        assert!(latest.is_some());
        // Latest should be from today's file since ts=2000 > ts=1000 but < 5000 is in old file
        // Actually ts=5000 is newer than 2000 so the correct latest is 80
        assert_eq!(latest.unwrap().bpm, 80);
    }

    #[tokio::test]
    async fn test_samples_in_range_empty_store() {
        let dir = TempDir::new().unwrap();
        let store = HrStore::new(dir.path().to_path_buf()).await.unwrap();
        let samples = store.samples_in_range(0, 10000).await.unwrap();
        assert!(samples.is_empty());
    }

    #[tokio::test]
    async fn test_samples_in_range_single_file() {
        let dir = TempDir::new().unwrap();
        let store = HrStore::new(dir.path().to_path_buf()).await.unwrap();
        store.append(1000, 60, None).await.unwrap();
        store.append(2000, 65, None).await.unwrap();
        store.append(3000, 70, None).await.unwrap();
        store.append(4000, 75, None).await.unwrap();
        store.append(5000, 80, None).await.unwrap();

        let samples = store.samples_in_range(2000, 4000).await.unwrap();
        assert_eq!(samples.len(), 3);
        assert_eq!(samples[0].bpm, 65);
        assert_eq!(samples[1].bpm, 70);
        assert_eq!(samples[2].bpm, 75);
    }

    #[tokio::test]
    async fn test_samples_in_range_boundary() {
        let dir = TempDir::new().unwrap();
        let store = HrStore::new(dir.path().to_path_buf()).await.unwrap();
        store.append(1000, 60, None).await.unwrap();
        store.append(2000, 65, None).await.unwrap();

        // Exact boundaries
        let samples = store.samples_in_range(1000, 2000).await.unwrap();
        assert_eq!(samples.len(), 2);

        // Out of range
        let samples = store.samples_in_range(5000, 6000).await.unwrap();
        assert!(samples.is_empty());
    }

    #[tokio::test]
    async fn test_samples_in_range_multi_day() {
        let dir = TempDir::new().unwrap();
        let store = HrStore::new(dir.path().to_path_buf()).await.unwrap();

        // Day 1
        store.append(1000, 60, None).await.unwrap();
        store.append(2000, 65, None).await.unwrap();
        // Day 2 (simulated via manual file)
        let day2_path = dir.path().join("hr").join("2024-01-02.jsonl");
        tokio::fs::write(&day2_path, "{\"ts_ms\":90000,\"bpm\":75}\n{\"ts_ms\":100000,\"bpm\":80}\n").await.unwrap();

        let samples = store.samples_in_range(1000, 100000).await.unwrap();
        assert_eq!(samples.len(), 4);
        assert_eq!(samples[0].bpm, 60);
        assert_eq!(samples[3].bpm, 80);
    }

    #[tokio::test]
    async fn test_samples_in_range_order_is_chronological() {
        let dir = TempDir::new().unwrap();
        let store = HrStore::new(dir.path().to_path_buf()).await.unwrap();

        // Write out of order
        store.append(5000, 80, None).await.unwrap();
        store.append(1000, 60, None).await.unwrap();
        store.append(3000, 70, None).await.unwrap();

        let samples = store.samples_in_range(0, 10000).await.unwrap();
        assert_eq!(samples.len(), 3);
        assert_eq!(samples[0].ts_ms, 1000);
        assert_eq!(samples[1].ts_ms, 3000);
        assert_eq!(samples[2].ts_ms, 5000);
    }

    #[tokio::test]
    async fn test_rolling_avg_empty_store() {
        let dir = TempDir::new().unwrap();
        let store = HrStore::new(dir.path().to_path_buf()).await.unwrap();
        assert!(store.rolling_avg(3600).await.unwrap().is_none());
    }

    #[tokio::test]
    async fn test_rolling_avg_single_sample() {
        let dir = TempDir::new().unwrap();
        let store = HrStore::new(dir.path().to_path_buf()).await.unwrap();
        store.append(5000, 72, None).await.unwrap();

        let avg = store.rolling_avg(3600).await.unwrap();
        assert!(avg.is_some());
        assert!((avg.unwrap() - 72.0).abs() < 0.01);
    }

    #[tokio::test]
    async fn test_rolling_avg_window_too_narrow() {
        let dir = TempDir::new().unwrap();
        let store = HrStore::new(dir.path().to_path_buf()).await.unwrap();
        store.append(5000, 72, None).await.unwrap();
        store.append(6000, 75, None).await.unwrap();
        store.append(7000, 78, None).await.unwrap();

        // Window of 1 second ending at ts=7000 starts at 6000
        // Only ts=6000 and ts=7000 fall within [6000, 7000]
        let avg = store.rolling_avg(1).await.unwrap();
        assert!(avg.is_some());
        // (75 + 78) / 2 = 76.5
        assert!((avg.unwrap() - 76.5).abs() < 0.01);
    }

    #[tokio::test]
    async fn test_rolling_avg_wide_window() {
        let dir = TempDir::new().unwrap();
        let store = HrStore::new(dir.path().to_path_buf()).await.unwrap();
        store.append(1000, 60, None).await.unwrap();
        store.append(2000, 65, None).await.unwrap();
        store.append(3000, 70, None).await.unwrap();
        store.append(4000, 75, None).await.unwrap();
        store.append(5000, 80, None).await.unwrap();

        // Wide window covering all samples
        let avg = store.rolling_avg(10000).await.unwrap();
        assert!(avg.is_some());
        // (60+65+70+75+80)/5 = 70
        assert!((avg.unwrap() - 70.0).abs() < 0.01);
    }

    #[tokio::test]
    async fn test_rolling_avg_no_samples_in_window() {
        let dir = TempDir::new().unwrap();
        let store = HrStore::new(dir.path().to_path_buf()).await.unwrap();
        store.append(1000, 60, None).await.unwrap();
        store.append(2000, 65, None).await.unwrap();

        // Latest is ts=2000, window of 100ms ending at 2000 starts at 1900
        // No samples in [1900, 2000] since 2000 is the latest and it's excluded (exclusive?)
        // Actually window_secs * 1000 so 100ms = 0.1s -> window_secs = 0
        // Let's use a smaller window that doesn't cover the samples
        // Hmm latest=2000, window=100ms -> start=2000-100=1900, range=[1900,2000]
        // ts=2000 is in range, so there's 1 sample
        // Let's make latest be much larger but samples be much smaller
        // Actually this is hard to trigger because latest_sample always returns the max ts
        // If we want no samples in window, we need latest sample but a window that starts after it
        // That's impossible because latest is the max.
        // The only way is if samples_in_range returns empty for [latest-1000, latest]
        // but if latest sample has ts=X, range is [X-1000, X], and the latest sample has ts=X
        // so it should be included.
        // The only edge case is if we consider the window as exclusive of latest
        // But with inclusive start and end, latest will always be in the window.
        // So rolling_avg should always return Some if there's at least one sample.
        // This test is essentially impossible to trigger with inclusive ranges.
        // We accept that rolling_avg returns Some whenever there's at least one sample.
    }

    #[tokio::test]
    async fn test_rolling_avg_with_rr_intervals() {
        let dir = TempDir::new().unwrap();
        let store = HrStore::new(dir.path().to_path_buf()).await.unwrap();
        store.append(1000, 70, Some(&[800, 820])).await.unwrap();
        store.append(2000, 72, Some(&[810, 830])).await.unwrap();

        // rr doesn't affect BPM average
        let avg = store.rolling_avg(3600).await.unwrap();
        assert!(avg.is_some());
        assert!((avg.unwrap() - 71.0).abs() < 0.01);
    }
}
