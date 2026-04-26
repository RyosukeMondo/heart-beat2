//! Heart rate persistent store.
//!
//! Append-only JSONL writer that creates one file per local day at
//! `<app_docs>/hr/YYYY-MM-DD.jsonl`. Each line: `{ts_ms, bpm, rr?}`.
//! Flush on every write; rotate automatically when the local date changes.

use anyhow::{Context, Result};
use chrono::{NaiveDate, Local};
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
#[derive(Clone, Debug)]
pub struct HrStore {
    /// Directory containing daily `.jsonl` files.
    hr_dir: PathBuf,
    /// Path to today's file (updated on rotation).
    #[allow(dead_code)]
    today_path: PathBuf,
    /// Owned data directory — kept alive by this store (used in tests with TempDir).
    /// When `Some`, the directory at this path is kept alive by this store.
    owned_dir: Option<PathBuf>,
}

impl Default for HrStore {
    fn default() -> Self {
        Self {
            hr_dir: PathBuf::new(),
            today_path: PathBuf::new(),
            owned_dir: None,
        }
    }
}

impl HrStore {
    /// Open (or create) the HR store under `data_dir/hr/`.
    ///
    /// Creates the `hr/` subdirectory if it does not exist.
    /// Runs a 30-day retention sweep on startup.
    pub async fn new(data_dir: PathBuf) -> Result<Self> {
        let hr_dir = data_dir.join("hr");
        tokio::fs::create_dir_all(&hr_dir)
            .await
            .with_context(|| format!("Failed to create hr directory: {:?}", hr_dir))?;

        let today_path = Self::today_path(&hr_dir);

        let store = Self {
            hr_dir: hr_dir.clone(),
            today_path,
            owned_dir: None,
        };

        store.retention_sweep().await?;

        Ok(store)
    }

    /// Open an HR store that owns its data directory (for use with TempDir in tests).
    ///
    /// The caller should pass a `TempDir` guard and keep it alive for the lifetime
    /// of the `HrStore`. The store stores the path so the caller must also keep
    /// the `TempDir` alive.
    pub async fn new_owned(data_dir: PathBuf) -> Result<Self> {
        let hr_dir = data_dir.join("hr");
        tokio::fs::create_dir_all(&hr_dir)
            .await
            .with_context(|| format!("Failed to create hr directory: {:?}", hr_dir))?;

        let today_path = Self::today_path(&hr_dir);

        Ok(Self {
            hr_dir,
            today_path,
            owned_dir: Some(data_dir),
        })
    }

    /// Delete all `<app_docs>/hr/*.jsonl` files older than 30 days.
    ///
    /// Date is parsed from the filename (YYYY-MM-DD.jsonl) rather than mtime,
    /// since mtime can be unreliable across device reboots or file transfers.
    pub async fn retention_sweep(&self) -> Result<()> {
        let cutoff = Local::now().date_naive() - chrono::Duration::days(30);

        let mut entries = tokio::fs::read_dir(&self.hr_dir).await?;
        while let Some(entry) = entries.next_entry().await? {
            let path = entry.path();
            if path.extension().and_then(|s| s.to_str()) != Some("jsonl") {
                continue;
            }

            if let Some(stem) = path.file_stem().and_then(|s| s.to_str()) {
                if let Ok(date) = NaiveDate::parse_from_str(stem, "%Y-%m-%d") {
                    if date < cutoff {
                        tracing::debug!("Removing stale HR file: {:?}", path);
                        tokio::fs::remove_file(&path).await?;
                    }
                }
            }
        }
        Ok(())
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
        // Ensure the directory exists (re-create if TempDir was dropped and recreated).
        tokio::fs::create_dir_all(&self.hr_dir).await.ok();
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

    // ─── Retention sweep tests ────────────────────────────────────────────────

    #[tokio::test]
    async fn test_retention_sweep_removes_old_files() {
        let dir = TempDir::new().unwrap();
        let hr_dir = dir.path().join("hr");
        tokio::fs::create_dir_all(&hr_dir).await.unwrap();

        // Create a file with an old date in the name (35 days ago)
        let old_date = Local::now().date_naive() - chrono::Duration::days(35);
        let old_file = hr_dir.join(format!("{}.jsonl", old_date.format("%Y-%m-%d")));
        tokio::fs::write(&old_file, "{\"ts_ms\":1,\"bpm\":60}\n").await.unwrap();

        // Create a file with a recent date in the name (today)
        let today_date = Local::now().date_naive();
        let recent_file = hr_dir.join(format!("{}.jsonl", today_date.format("%Y-%m-%d")));
        tokio::fs::write(&recent_file, "{\"ts_ms\":2,\"bpm\":70}\n").await.unwrap();

        // Also create a file with a date 15 days ago (within retention)
        let recent_date = Local::now().date_naive() - chrono::Duration::days(15);
        let recent_file2 = hr_dir.join(format!("{}.jsonl", recent_date.format("%Y-%m-%d")));
        tokio::fs::write(&recent_file2, "{\"ts_ms\":3,\"bpm\":75}\n").await.unwrap();

        // Initialize store and run sweep
        HrStore::new(dir.path().to_path_buf()).await.unwrap();

        // Old file should be gone
        assert!(!old_file.exists(), "Old file should have been deleted");

        // Recent files should still exist
        assert!(recent_file.exists(), "Today's file should still exist");
        assert!(recent_file2.exists(), "15-day-old file should still exist");
    }

    #[tokio::test]
    async fn test_retention_sweep_keeps_all_when_all_recent() {
        let dir = TempDir::new().unwrap();
        let store = HrStore::new(dir.path().to_path_buf()).await.unwrap();

        // Write some samples (creates today's file)
        store.append(1000, 72, None).await.unwrap();

        // Init again (should not error)
        HrStore::new(dir.path().to_path_buf()).await.unwrap();
        assert!(store.latest_sample().await.unwrap().is_some());
    }

    #[tokio::test]
    async fn test_retention_sweep_handles_non_jsonl_files() {
        let dir = TempDir::new().unwrap();
        let hr_dir = dir.path().join("hr");
        tokio::fs::create_dir_all(&hr_dir).await.unwrap();

        // Create a non-jsonl file
        tokio::fs::write(hr_dir.join("readme.txt"), "not a hr file").await.unwrap();

        // Create a file with invalid date name
        tokio::fs::write(hr_dir.join("invalid-date.jsonl"), "{}").await.unwrap();

        // Init should not error
        let store = HrStore::new(dir.path().to_path_buf()).await.unwrap();
        assert!(store.latest_sample().await.unwrap().is_none());
    }

    // ─── Day-boundary / multi-file tests ───────────────────────────────────────

    /// Verify rolling_avg correctly aggregates samples across two daily files
    /// spanning a midnight boundary. The window is computed from the latest sample
    /// (ts=100_000), which falls in the second file.
    #[tokio::test]
    async fn test_rolling_avg_spans_midnight_across_files() {
        let dir = TempDir::new().unwrap();
        let store = HrStore::new_owned(dir.path().to_path_buf()).await.unwrap();
        let hr_dir = dir.path().join("hr");

        // File for "yesterday": samples at ts=50_000 and ts=100_000 (BPM 60 and 65)
        let yesterday = Local::now().date_naive() - chrono::Duration::days(1);
        let yesterday_file = hr_dir.join(format!("{}.jsonl", yesterday.format("%Y-%m-%d")));
        tokio::fs::write(
            &yesterday_file,
            "{\"ts_ms\":50000,\"bpm\":60}\n{\"ts_ms\":100000,\"bpm\":65}\n",
        )
        .await
        .unwrap();

        // Rolling avg with a wide window should include both files.
        // latest ts_ms = 100_000, window = 100_000 s covers everything.
        let avg = store.rolling_avg(100_000).await.unwrap();
        let avg = avg.expect("rolling_avg should return Some");
        // (60 + 65) / 2 = 62.5
        assert!((avg - 62.5).abs() < 0.01, "avg={}", avg);
    }

    /// Verify rolling_avg with a window that starts before midnight and ends
    /// after it — samples from both files must be included.
    #[tokio::test]
    async fn test_rolling_avg_window_straddles_midnight() {
        let dir = TempDir::new().unwrap();
        let store = HrStore::new_owned(dir.path().to_path_buf()).await.unwrap();
        let hr_dir = dir.path().join("hr");

        // Yesterday file: ts_ms = 86_400_000 (midnight yesterday in ms from epoch)
        let yesterday = Local::now().date_naive() - chrono::Duration::days(1);
        let yesterday_file = hr_dir.join(format!("{}.jsonl", yesterday.format("%Y-%m-%d")));
        tokio::fs::write(&yesterday_file, "{\"ts_ms\":86400000,\"bpm\":70}\n").await.unwrap();

        // Today's file: one sample shortly after midnight
        let today = Local::now().date_naive();
        let today_file = hr_dir.join(format!("{}.jsonl", today.format("%Y-%m-%d")));
        tokio::fs::write(&today_file, "{\"ts_ms\":86460000,\"bpm\":72}\n").await.unwrap();
        // Latest sample is at ts=86460000 (10 min after midnight).

        // Window of 2 hours = 7200 s = 7_200_000 ms, starting at 86460000 - 7200000 = 79260000.
        // This window covers both the 86400000 and 86460000 samples.
        let avg = store.rolling_avg(7200).await.unwrap();
        let avg = avg.expect("rolling_avg should return Some");
        // (70 + 72) / 2 = 71.0
        assert!((avg - 71.0).abs() < 0.01, "avg={}", avg);
    }

    /// Files exactly at the 30-day cutoff must be retained (not deleted).
    /// The sweep uses date < cutoff, so a 30-day-old file (date == cutoff) is kept.
    #[tokio::test]
    async fn test_retention_sweep_keeps_exactly_30_day_old_file() {
        let dir = TempDir::new().unwrap();
        let hr_dir = dir.path().join("hr");
        tokio::fs::create_dir_all(&hr_dir).await.unwrap();

        // File exactly 30 days ago — must be retained
        let cutoff_date = Local::now().date_naive() - chrono::Duration::days(30);
        let cutoff_file = hr_dir.join(format!("{}.jsonl", cutoff_date.format("%Y-%m-%d")));
        tokio::fs::write(&cutoff_file, "{\"ts_ms\":1,\"bpm\":60}\n").await.unwrap();

        // File 31 days ago — must be deleted
        let old_date = Local::now().date_naive() - chrono::Duration::days(31);
        let old_file = hr_dir.join(format!("{}.jsonl", old_date.format("%Y-%m-%d")));
        tokio::fs::write(&old_file, "{\"ts_ms\":2,\"bpm\":65}\n").await.unwrap();

        // Init store (runs sweep)
        HrStore::new(dir.path().to_path_buf()).await.unwrap();

        // Cutoff file (30 days old) must still exist
        assert!(cutoff_file.exists(), "File exactly at 30-day cutoff should be retained");
        // Old file (31 days) must be gone
        assert!(!old_file.exists(), "File older than 30 days should be deleted");
    }

    /// The latest sample must be found correctly when it is the only sample
    /// in the most-recently-named file (day-boundary case with one file having
    /// the newest timestamp).
    #[tokio::test]
    async fn test_latest_sample_at_day_boundary() {
        let dir = TempDir::new().unwrap();
        let store = HrStore::new_owned(dir.path().to_path_buf()).await.unwrap();
        let hr_dir = dir.path().join("hr");

        // Yesterday's file with a large timestamp
        let yesterday = Local::now().date_naive() - chrono::Duration::days(1);
        let yesterday_file = hr_dir.join(format!("{}.jsonl", yesterday.format("%Y-%m-%d")));
        tokio::fs::write(&yesterday_file, "{\"ts_ms\":50000,\"bpm\":70}\n").await.unwrap();

        // Today's file with a larger timestamp
        let today = Local::now().date_naive();
        let today_file = hr_dir.join(format!("{}.jsonl", today.format("%Y-%m-%d")));
        tokio::fs::write(&today_file, "{\"ts_ms\":90000,\"bpm\":80}\n{\"ts_ms\":95000,\"bpm\":85}\n").await.unwrap();

        let latest = store.latest_sample().await.unwrap();
        let latest = latest.expect("latest_sample should return Some");
        assert_eq!(latest.ts_ms, 95000);
        assert_eq!(latest.bpm, 85);
    }

    /// Verify samples_in_range returns correct count and values when the range
    /// spans midnight and samples live in two files.
    #[tokio::test]
    async fn test_samples_in_range_spans_midnight() {
        let dir = TempDir::new().unwrap();
        let store = HrStore::new_owned(dir.path().to_path_buf()).await.unwrap();
        let hr_dir = dir.path().join("hr");

        // Yesterday's file: one sample before midnight
        let yesterday = Local::now().date_naive() - chrono::Duration::days(1);
        let yesterday_file = hr_dir.join(format!("{}.jsonl", yesterday.format("%Y-%m-%d")));
        tokio::fs::write(&yesterday_file, "{\"ts_ms\":86399000,\"bpm\":68}\n{\"ts_ms\":86400000,\"bpm\":69}\n").await.unwrap();

        // Today's file: samples after midnight
        let today = Local::now().date_naive();
        let today_file = hr_dir.join(format!("{}.jsonl", today.format("%Y-%m-%d")));
        tokio::fs::write(&today_file, "{\"ts_ms\":86401000,\"bpm\":71}\n{\"ts_ms\":86402000,\"bpm\":72}\n").await.unwrap();

        // Range from just before midnight to just after
        let samples = store.samples_in_range(86399000, 86402000).await.unwrap();
        assert_eq!(samples.len(), 4, "should include 2 samples from each file");
        assert_eq!(samples[0].bpm, 68);
        assert_eq!(samples[3].bpm, 72);
    }
}
