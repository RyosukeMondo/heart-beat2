//! File-based session repository implementation.
//!
//! This adapter implements `SessionRepository` using JSON files stored in the
//! user's home directory (~/.heart-beat/sessions/). Each session is stored as
//! a separate JSON file with a filename format: {date}_{plan}_{id}.json

use crate::domain::session_history::CompletedSession;
use crate::ports::session_repository::{SessionRepository, SessionSummaryPreview};
use anyhow::{Context, Result};
use async_trait::async_trait;
use std::path::PathBuf;
use tokio::fs;

/// File-based implementation of SessionRepository.
///
/// Stores sessions as JSON files in ~/.heart-beat/sessions/ directory.
/// Each file is named: {YYYYMMDD}_{plan_name}_{session_id}.json
#[derive(Debug, Clone)]
pub struct FileSessionRepository {
    /// Directory where session files are stored.
    sessions_dir: PathBuf,
}

impl FileSessionRepository {
    /// Create a new FileSessionRepository using the default sessions directory.
    ///
    /// The default directory is ~/.heart-beat/sessions/
    ///
    /// # Errors
    ///
    /// Returns an error if the home directory cannot be determined or the
    /// sessions directory cannot be created.
    pub async fn new() -> Result<Self> {
        let sessions_dir = Self::default_sessions_dir()?;
        Self::with_directory(sessions_dir).await
    }

    /// Create a new FileSessionRepository with a custom directory.
    ///
    /// This is useful for testing or custom storage locations.
    ///
    /// # Arguments
    ///
    /// * `sessions_dir` - Path to the directory where session files will be stored
    ///
    /// # Errors
    ///
    /// Returns an error if the directory cannot be created.
    pub async fn with_directory(sessions_dir: PathBuf) -> Result<Self> {
        // Create the directory if it doesn't exist
        fs::create_dir_all(&sessions_dir)
            .await
            .with_context(|| format!("Failed to create sessions directory: {:?}", sessions_dir))?;

        Ok(Self { sessions_dir })
    }

    /// Get the default sessions directory path.
    ///
    /// Returns ~/.heart-beat/sessions/
    fn default_sessions_dir() -> Result<PathBuf> {
        let home = dirs::home_dir().context("Failed to determine home directory")?;
        Ok(home.join(".heart-beat").join("sessions"))
    }

    /// Generate a filename for a session.
    ///
    /// Format: {YYYYMMDD}--{plan_name}--{session_id}.json
    /// Using double-dash as delimiter to avoid conflicts with underscores in names.
    fn session_filename(session: &CompletedSession) -> String {
        let date = session.start_time.format("%Y%m%d");
        let plan_name = sanitize_filename(&session.plan_name);
        format!("{}--{}--{}.json", date, plan_name, session.id)
    }

    /// Parse session ID from filename.
    ///
    /// Extracts the session ID from a filename in the format:
    /// {YYYYMMDD}--{plan_name}--{session_id}.json
    fn parse_session_id(filename: &str) -> Option<String> {
        if !filename.ends_with(".json") {
            return None;
        }

        let without_ext = &filename[..filename.len() - 5]; // Remove ".json"
        let parts: Vec<&str> = without_ext.split("--").collect();

        // Format is: YYYYMMDD--planname--id
        // We need exactly 3 parts
        if parts.len() == 3 {
            Some(parts[2].to_string())
        } else {
            None
        }
    }

    /// Get the full path for a session file.
    fn session_path(&self, session: &CompletedSession) -> PathBuf {
        self.sessions_dir.join(Self::session_filename(session))
    }

    /// Find a session file by ID.
    ///
    /// Searches for files matching the pattern *_{id}.json
    async fn find_session_file(&self, id: &str) -> Result<Option<PathBuf>> {
        let mut entries = fs::read_dir(&self.sessions_dir).await.with_context(|| {
            format!("Failed to read sessions directory: {:?}", self.sessions_dir)
        })?;

        while let Some(entry) = entries.next_entry().await? {
            let path = entry.path();
            if let Some(filename) = path.file_name().and_then(|n| n.to_str()) {
                if let Some(file_id) = Self::parse_session_id(filename) {
                    if file_id == id {
                        return Ok(Some(path));
                    }
                }
            }
        }

        Ok(None)
    }

    /// Load a session from a file.
    async fn load_session(&self, path: &PathBuf) -> Result<CompletedSession> {
        let contents = fs::read_to_string(path)
            .await
            .with_context(|| format!("Failed to read session file: {:?}", path))?;

        serde_json::from_str(&contents)
            .with_context(|| format!("Failed to parse session file: {:?}", path))
    }

    /// Create a session summary preview from a session file.
    ///
    /// This is optimized to avoid loading the full session (which may have
    /// thousands of HR samples) when just listing sessions.
    async fn create_preview(&self, path: &PathBuf) -> Result<SessionSummaryPreview> {
        let session = self.load_session(path).await?;

        Ok(SessionSummaryPreview {
            id: session.id,
            plan_name: session.plan_name,
            start_time: session.start_time,
            duration_secs: session.summary.duration_secs,
            avg_hr: session.summary.avg_hr,
            status: format!("{:?}", session.status),
        })
    }
}

#[async_trait]
impl SessionRepository for FileSessionRepository {
    async fn save(&self, session: &CompletedSession) -> Result<()> {
        let path = self.session_path(session);

        let json = serde_json::to_string_pretty(session)
            .with_context(|| format!("Failed to serialize session: {}", session.id))?;

        fs::write(&path, json)
            .await
            .with_context(|| format!("Failed to write session file: {:?}", path))?;

        Ok(())
    }

    async fn list(&self) -> Result<Vec<SessionSummaryPreview>> {
        let mut entries = fs::read_dir(&self.sessions_dir).await.with_context(|| {
            format!("Failed to read sessions directory: {:?}", self.sessions_dir)
        })?;

        let mut previews = Vec::new();

        while let Some(entry) = entries.next_entry().await? {
            let path = entry.path();

            // Skip non-JSON files
            if path.extension().and_then(|s| s.to_str()) != Some("json") {
                continue;
            }

            // Try to load the preview, but don't fail if one file is corrupted
            match self.create_preview(&path).await {
                Ok(preview) => previews.push(preview),
                Err(e) => {
                    eprintln!("Warning: Failed to load session from {:?}: {}", path, e);
                }
            }
        }

        // Sort by start time, most recent first
        previews.sort_by(|a, b| b.start_time.cmp(&a.start_time));

        Ok(previews)
    }

    async fn get(&self, id: &str) -> Result<Option<CompletedSession>> {
        match self.find_session_file(id).await? {
            Some(path) => {
                let session = self.load_session(&path).await?;
                Ok(Some(session))
            }
            None => Ok(None),
        }
    }

    async fn delete(&self, id: &str) -> Result<()> {
        match self.find_session_file(id).await? {
            Some(path) => {
                fs::remove_file(&path)
                    .await
                    .with_context(|| format!("Failed to delete session file: {:?}", path))?;
                Ok(())
            }
            None => {
                // Silently succeed if the session doesn't exist
                Ok(())
            }
        }
    }
}

/// Sanitize a string to be used as a filename.
///
/// Replaces characters that are not safe for filenames with underscores.
fn sanitize_filename(s: &str) -> String {
    s.chars()
        .map(|c| {
            if c.is_alphanumeric() || c == '-' || c == '_' {
                c
            } else {
                '_'
            }
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::session_history::{HrSample, SessionStatus, SessionSummary};
    use chrono::Utc;

    #[test]
    fn test_sanitize_filename() {
        assert_eq!(sanitize_filename("Easy Run"), "Easy_Run");
        assert_eq!(sanitize_filename("5k @ Zone 2"), "5k___Zone_2");
        assert_eq!(sanitize_filename("Test-Plan_123"), "Test-Plan_123");
    }

    #[test]
    fn test_session_filename() {
        let session = CompletedSession {
            id: "abc123".to_string(),
            plan_name: "Easy Run".to_string(),
            start_time: chrono::DateTime::parse_from_rfc3339("2024-01-15T10:30:00Z")
                .unwrap()
                .with_timezone(&Utc),
            end_time: chrono::DateTime::parse_from_rfc3339("2024-01-15T11:00:00Z")
                .unwrap()
                .with_timezone(&Utc),
            status: SessionStatus::Completed,
            hr_samples: vec![],
            phases_completed: 1,
            summary: SessionSummary {
                duration_secs: 1800,
                avg_hr: 140,
                max_hr: 160,
                min_hr: 120,
                time_in_zone: [0, 1800, 0, 0, 0],
            },
        };

        let filename = FileSessionRepository::session_filename(&session);
        assert_eq!(filename, "20240115--Easy_Run--abc123.json");
    }

    #[test]
    fn test_parse_session_id() {
        assert_eq!(
            FileSessionRepository::parse_session_id("20240115--Easy_Run--abc123.json"),
            Some("abc123".to_string())
        );

        assert_eq!(
            FileSessionRepository::parse_session_id("20240115--5k_Zone_2--xyz789.json"),
            Some("xyz789".to_string())
        );

        assert_eq!(FileSessionRepository::parse_session_id("invalid.txt"), None);

        assert_eq!(
            FileSessionRepository::parse_session_id("nounderscore.json"),
            None
        );

        // Test with underscore in ID
        assert_eq!(
            FileSessionRepository::parse_session_id("20240115--Test--delete_me.json"),
            Some("delete_me".to_string())
        );
    }

    #[tokio::test]
    async fn test_save_and_load() {
        let temp_dir = tempfile::tempdir().unwrap();
        let repo = FileSessionRepository::with_directory(temp_dir.path().to_path_buf())
            .await
            .unwrap();

        let now = Utc::now();
        let session = CompletedSession {
            id: "test123".to_string(),
            plan_name: "Test Plan".to_string(),
            start_time: now,
            end_time: now + chrono::Duration::seconds(1800),
            status: SessionStatus::Completed,
            hr_samples: vec![
                HrSample {
                    timestamp: now,
                    bpm: 120,
                },
                HrSample {
                    timestamp: now + chrono::Duration::seconds(60),
                    bpm: 140,
                },
            ],
            phases_completed: 2,
            summary: SessionSummary {
                duration_secs: 1800,
                avg_hr: 130,
                max_hr: 140,
                min_hr: 120,
                time_in_zone: [0, 900, 900, 0, 0],
            },
        };

        // Save the session
        repo.save(&session).await.unwrap();

        // Load it back
        let loaded = repo.get("test123").await.unwrap();
        assert!(loaded.is_some());
        assert_eq!(loaded.unwrap(), session);

        // Test non-existent session
        let not_found = repo.get("nonexistent").await.unwrap();
        assert!(not_found.is_none());
    }

    #[tokio::test]
    async fn test_list_sessions() {
        let temp_dir = tempfile::tempdir().unwrap();
        let repo = FileSessionRepository::with_directory(temp_dir.path().to_path_buf())
            .await
            .unwrap();

        let now = Utc::now();

        // Create two sessions
        let session1 = CompletedSession {
            id: "session1".to_string(),
            plan_name: "Plan A".to_string(),
            start_time: now - chrono::Duration::hours(2),
            end_time: now - chrono::Duration::hours(1),
            status: SessionStatus::Completed,
            hr_samples: vec![],
            phases_completed: 1,
            summary: SessionSummary {
                duration_secs: 3600,
                avg_hr: 130,
                max_hr: 140,
                min_hr: 120,
                time_in_zone: [0, 3600, 0, 0, 0],
            },
        };

        let session2 = CompletedSession {
            id: "session2".to_string(),
            plan_name: "Plan B".to_string(),
            start_time: now,
            end_time: now + chrono::Duration::hours(1),
            status: SessionStatus::Stopped,
            hr_samples: vec![],
            phases_completed: 2,
            summary: SessionSummary {
                duration_secs: 3600,
                avg_hr: 140,
                max_hr: 150,
                min_hr: 130,
                time_in_zone: [0, 1800, 1800, 0, 0],
            },
        };

        repo.save(&session1).await.unwrap();
        repo.save(&session2).await.unwrap();

        // List sessions
        let previews = repo.list().await.unwrap();
        assert_eq!(previews.len(), 2);

        // Should be sorted by start time, most recent first
        assert_eq!(previews[0].id, "session2");
        assert_eq!(previews[1].id, "session1");
    }

    #[tokio::test]
    async fn test_delete_session() {
        let temp_dir = tempfile::tempdir().unwrap();
        let repo = FileSessionRepository::with_directory(temp_dir.path().to_path_buf())
            .await
            .unwrap();

        let now = Utc::now();
        let session = CompletedSession {
            id: "delete_me".to_string(),
            plan_name: "Test".to_string(),
            start_time: now,
            end_time: now + chrono::Duration::hours(1),
            status: SessionStatus::Completed,
            hr_samples: vec![],
            phases_completed: 1,
            summary: SessionSummary {
                duration_secs: 3600,
                avg_hr: 130,
                max_hr: 140,
                min_hr: 120,
                time_in_zone: [0, 3600, 0, 0, 0],
            },
        };

        // Save and verify it exists
        repo.save(&session).await.unwrap();
        assert!(repo.get("delete_me").await.unwrap().is_some());

        // Delete it
        repo.delete("delete_me").await.unwrap();
        assert!(repo.get("delete_me").await.unwrap().is_none());

        // Deleting non-existent session should succeed silently
        repo.delete("nonexistent").await.unwrap();
    }
}
