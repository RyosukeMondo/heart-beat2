//! Session Repository Port
//!
//! This module defines the `SessionRepository` trait, which abstracts session
//! storage operations for testability and swappability. This allows the domain
//! logic to work with different storage backends (file system, database, etc.).

use crate::domain::session_history::CompletedSession;
use anyhow::Result;
use async_trait::async_trait;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// Preview of a session for list views.
///
/// Contains summary information needed for displaying sessions in a list,
/// without loading the full session data (which may include thousands of
/// HR samples).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SessionSummaryPreview {
    /// Unique identifier for this session.
    pub id: String,

    /// Name of the training plan that was executed.
    pub plan_name: String,

    /// When the session started.
    pub start_time: DateTime<Utc>,

    /// Total duration in seconds.
    pub duration_secs: u32,

    /// Average heart rate during the session.
    pub avg_hr: u16,

    /// Final status of the session.
    pub status: String,
}

/// Abstraction for session storage operations.
///
/// This trait defines the interface for persisting and retrieving completed
/// training sessions. It can be implemented with different storage backends:
/// file system, SQLite, cloud storage, etc.
#[async_trait]
pub trait SessionRepository: Send + Sync {
    /// Save a completed session.
    ///
    /// Persists the session data including all heart rate samples, phase results,
    /// and summary statistics.
    ///
    /// # Arguments
    ///
    /// * `session` - The completed session to save
    ///
    /// # Errors
    ///
    /// Returns an error if the session cannot be saved due to I/O issues,
    /// permission problems, or serialization failures.
    async fn save(&self, session: &CompletedSession) -> Result<()>;

    /// List all sessions with summary information.
    ///
    /// Returns a lightweight list of session previews without loading full
    /// session data. This is optimized for displaying a list of sessions
    /// in a UI.
    ///
    /// # Returns
    ///
    /// A vector of session previews, typically sorted by start time (most recent first).
    ///
    /// # Errors
    ///
    /// Returns an error if the session list cannot be read due to I/O issues
    /// or permission problems.
    async fn list(&self) -> Result<Vec<SessionSummaryPreview>>;

    /// Get a complete session by its ID.
    ///
    /// Loads the full session data including all heart rate samples and phase results.
    ///
    /// # Arguments
    ///
    /// * `id` - The unique identifier of the session to retrieve
    ///
    /// # Returns
    ///
    /// The complete session if found, or `None` if no session with the given ID exists.
    ///
    /// # Errors
    ///
    /// Returns an error if the session cannot be read due to I/O issues,
    /// deserialization failures, or permission problems. Returns `Ok(None)` if
    /// the session doesn't exist.
    async fn get(&self, id: &str) -> Result<Option<CompletedSession>>;

    /// Delete a session by its ID.
    ///
    /// Permanently removes the session and all its data.
    ///
    /// # Arguments
    ///
    /// * `id` - The unique identifier of the session to delete
    ///
    /// # Errors
    ///
    /// Returns an error if the session cannot be deleted due to I/O issues
    /// or permission problems. Succeeds silently if the session doesn't exist.
    async fn delete(&self, id: &str) -> Result<()>;
}
