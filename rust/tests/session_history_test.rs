//! Integration tests for session history functionality.
//!
//! This test verifies the end-to-end session storage lifecycle: creating sessions,
//! saving them, listing them, retrieving individual sessions, and deleting them.
//! It also validates that summary statistics are correctly calculated.

use chrono::{Duration, Utc};
use heart_beat::adapters::file_session_repository::FileSessionRepository;
use heart_beat::domain::session_history::{
    CompletedSession, HrSample, SessionStatus, SessionSummary,
};
use heart_beat::ports::session_repository::SessionRepository;
use tempfile::TempDir;

/// Helper to create a test session with custom parameters.
fn create_test_session(
    id: &str,
    plan_name: &str,
    start_offset_hours: i64,
    duration_secs: u32,
    samples: Vec<HrSample>,
    status: SessionStatus,
) -> CompletedSession {
    let start_time = Utc::now() - Duration::hours(start_offset_hours);
    let end_time = start_time + Duration::seconds(duration_secs as i64);

    // Calculate summary from samples
    let summary =
        SessionSummary::from_samples(&samples, duration_secs, [0, duration_secs, 0, 0, 0]);

    CompletedSession {
        id: id.to_string(),
        plan_name: plan_name.to_string(),
        start_time,
        end_time,
        status,
        hr_samples: samples,
        phases_completed: 1,
        summary,
    }
}

/// Test the complete CRUD cycle: save, list, get, delete.
///
/// This integration test verifies:
/// 1. Multiple sessions can be saved
/// 2. List returns all sessions in correct order (most recent first)
/// 3. Individual sessions can be retrieved by ID
/// 4. Sessions can be deleted
/// 5. After deletion, sessions are no longer accessible
#[tokio::test]
async fn test_session_crud_cycle() {
    // Setup: Create temporary directory for test isolation
    let temp_dir = TempDir::new().expect("Failed to create temp dir");
    let repo = FileSessionRepository::with_directory(temp_dir.path().to_path_buf())
        .await
        .expect("Failed to create repository");

    // Create test data: three sessions with different timestamps
    let now = Utc::now();
    let session1 = create_test_session(
        "session-001",
        "Base Endurance",
        24, // 24 hours ago
        3600,
        vec![
            HrSample {
                timestamp: now - Duration::hours(24),
                bpm: 130,
            },
            HrSample {
                timestamp: now - Duration::hours(24) + Duration::minutes(30),
                bpm: 135,
            },
        ],
        SessionStatus::Completed,
    );

    let session2 = create_test_session(
        "session-002",
        "Tempo Run",
        12, // 12 hours ago
        1800,
        vec![
            HrSample {
                timestamp: now - Duration::hours(12),
                bpm: 150,
            },
            HrSample {
                timestamp: now - Duration::hours(12) + Duration::minutes(15),
                bpm: 155,
            },
        ],
        SessionStatus::Completed,
    );

    let session3 = create_test_session(
        "session-003",
        "VO2 Max Intervals",
        1, // 1 hour ago
        2400,
        vec![
            HrSample {
                timestamp: now - Duration::hours(1),
                bpm: 170,
            },
            HrSample {
                timestamp: now - Duration::hours(1) + Duration::minutes(20),
                bpm: 175,
            },
        ],
        SessionStatus::Stopped,
    );

    // Test 1: Save all sessions
    repo.save(&session1).await.expect("Failed to save session1");
    repo.save(&session2).await.expect("Failed to save session2");
    repo.save(&session3).await.expect("Failed to save session3");

    // Test 2: List sessions - should return all 3, sorted by start time (most recent first)
    let list = repo.list().await.expect("Failed to list sessions");
    assert_eq!(list.len(), 3, "Should have 3 sessions");
    assert_eq!(list[0].id, "session-003", "Most recent session first");
    assert_eq!(list[1].id, "session-002", "Second most recent");
    assert_eq!(list[2].id, "session-001", "Oldest session last");

    // Verify preview data is correct
    assert_eq!(list[0].plan_name, "VO2 Max Intervals");
    assert_eq!(list[0].duration_secs, 2400);
    assert_eq!(list[0].avg_hr, 172); // (170 + 175) / 2 = 172.5 -> 172

    // Test 3: Get individual sessions by ID
    let retrieved1 = repo
        .get("session-001")
        .await
        .expect("Failed to get session1");
    assert!(retrieved1.is_some(), "Session1 should exist");
    assert_eq!(
        retrieved1.unwrap(),
        session1,
        "Retrieved session should match original"
    );

    let retrieved2 = repo
        .get("session-002")
        .await
        .expect("Failed to get session2");
    assert!(retrieved2.is_some(), "Session2 should exist");
    assert_eq!(
        retrieved2.unwrap(),
        session2,
        "Retrieved session should match original"
    );

    // Test 4: Get non-existent session
    let not_found = repo
        .get("nonexistent-id")
        .await
        .expect("Get should succeed even for non-existent ID");
    assert!(
        not_found.is_none(),
        "Non-existent session should return None"
    );

    // Test 5: Delete a session
    repo.delete("session-002")
        .await
        .expect("Failed to delete session2");

    // Verify deletion: list should now have 2 sessions
    let list_after_delete = repo
        .list()
        .await
        .expect("Failed to list sessions after delete");
    assert_eq!(
        list_after_delete.len(),
        2,
        "Should have 2 sessions after deletion"
    );
    assert!(!list_after_delete.iter().any(|s| s.id == "session-002"));

    // Verify get returns None for deleted session
    let deleted_session = repo
        .get("session-002")
        .await
        .expect("Get should succeed for deleted session");
    assert!(
        deleted_session.is_none(),
        "Deleted session should return None"
    );

    // Test 6: Delete non-existent session (should succeed silently)
    repo.delete("already-deleted")
        .await
        .expect("Deleting non-existent session should succeed");

    // Test 7: Delete remaining sessions
    repo.delete("session-001")
        .await
        .expect("Failed to delete session1");
    repo.delete("session-003")
        .await
        .expect("Failed to delete session3");

    // Verify all sessions deleted
    let empty_list = repo.list().await.expect("Failed to list empty sessions");
    assert_eq!(
        empty_list.len(),
        0,
        "List should be empty after all deletions"
    );
}

/// Test that summary statistics are correctly calculated from HR samples.
///
/// Verifies:
/// 1. Average HR is calculated correctly
/// 2. Min/Max HR are identified correctly
/// 3. Empty samples result in zero stats
/// 4. Single sample works correctly
#[tokio::test]
async fn test_summary_statistics_calculation() {
    let temp_dir = TempDir::new().expect("Failed to create temp dir");
    let repo = FileSessionRepository::with_directory(temp_dir.path().to_path_buf())
        .await
        .expect("Failed to create repository");

    let now = Utc::now();

    // Test case 1: Multiple samples with clear avg/min/max
    let samples = vec![
        HrSample {
            timestamp: now,
            bpm: 100,
        },
        HrSample {
            timestamp: now + Duration::seconds(60),
            bpm: 150,
        },
        HrSample {
            timestamp: now + Duration::seconds(120),
            bpm: 200,
        },
    ];

    let session1 = create_test_session(
        "stats-test-1",
        "Statistics Test",
        0,
        180,
        samples,
        SessionStatus::Completed,
    );

    repo.save(&session1).await.expect("Failed to save session");

    let retrieved = repo
        .get("stats-test-1")
        .await
        .expect("Failed to get session")
        .expect("Session should exist");

    // Verify statistics: avg = (100 + 150 + 200) / 3 = 450 / 3 = 150
    assert_eq!(retrieved.summary.avg_hr, 150, "Average HR should be 150");
    assert_eq!(retrieved.summary.min_hr, 100, "Min HR should be 100");
    assert_eq!(retrieved.summary.max_hr, 200, "Max HR should be 200");

    // Test case 2: Empty samples
    let empty_session = create_test_session(
        "stats-test-2",
        "Empty Session",
        0,
        60,
        vec![],
        SessionStatus::Interrupted,
    );

    repo.save(&empty_session)
        .await
        .expect("Failed to save empty session");

    let retrieved_empty = repo
        .get("stats-test-2")
        .await
        .expect("Failed to get empty session")
        .expect("Empty session should exist");

    assert_eq!(
        retrieved_empty.summary.avg_hr, 0,
        "Empty session avg HR should be 0"
    );
    assert_eq!(
        retrieved_empty.summary.min_hr, 0,
        "Empty session min HR should be 0"
    );
    assert_eq!(
        retrieved_empty.summary.max_hr, 0,
        "Empty session max HR should be 0"
    );

    // Test case 3: Single sample
    let single_sample = vec![HrSample {
        timestamp: now,
        bpm: 142,
    }];

    let single_session = create_test_session(
        "stats-test-3",
        "Single Sample",
        0,
        30,
        single_sample,
        SessionStatus::Completed,
    );

    repo.save(&single_session)
        .await
        .expect("Failed to save single sample session");

    let retrieved_single = repo
        .get("stats-test-3")
        .await
        .expect("Failed to get single sample session")
        .expect("Single sample session should exist");

    assert_eq!(
        retrieved_single.summary.avg_hr, 142,
        "Single sample: avg should equal the value"
    );
    assert_eq!(
        retrieved_single.summary.min_hr, 142,
        "Single sample: min should equal the value"
    );
    assert_eq!(
        retrieved_single.summary.max_hr, 142,
        "Single sample: max should equal the value"
    );
}

/// Test that sessions are sorted correctly by start time.
///
/// Verifies that list() returns sessions in descending order by start_time
/// (most recent first).
#[tokio::test]
async fn test_session_sorting() {
    let temp_dir = TempDir::new().expect("Failed to create temp dir");
    let repo = FileSessionRepository::with_directory(temp_dir.path().to_path_buf())
        .await
        .expect("Failed to create repository");

    // Create sessions with specific timestamps (out of order)
    let session_oldest = create_test_session(
        "oldest",
        "Old Session",
        72, // 3 days ago
        1800,
        vec![],
        SessionStatus::Completed,
    );

    let session_newest = create_test_session(
        "newest",
        "New Session",
        1, // 1 hour ago
        1800,
        vec![],
        SessionStatus::Completed,
    );

    let session_middle = create_test_session(
        "middle",
        "Middle Session",
        36, // 36 hours ago
        1800,
        vec![],
        SessionStatus::Completed,
    );

    // Save in random order
    repo.save(&session_middle)
        .await
        .expect("Failed to save middle session");
    repo.save(&session_oldest)
        .await
        .expect("Failed to save oldest session");
    repo.save(&session_newest)
        .await
        .expect("Failed to save newest session");

    // List should return in order: newest, middle, oldest
    let list = repo.list().await.expect("Failed to list sessions");
    assert_eq!(list.len(), 3);
    assert_eq!(list[0].id, "newest", "First should be newest");
    assert_eq!(list[1].id, "middle", "Second should be middle");
    assert_eq!(list[2].id, "oldest", "Third should be oldest");
}
