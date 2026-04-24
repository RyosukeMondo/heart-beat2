//! Reconnection policy and connection status types.
//!
//! This module provides core data types for managing automatic reconnection
//! to BLE heart rate monitors. All types are pure domain logic with no I/O.

use serde::{Deserialize, Serialize};
use std::time::Duration;

/// Sentinel value indicating unlimited reconnection attempts.
///
/// Used when `max_attempts` equals this value to signal that reconnection
/// should continue indefinitely (e.g., during an active coaching session).
pub const UNLIMITED_ATTEMPTS: u8 = u8::MAX;

/// Configuration for automatic reconnection behavior.
///
/// This struct defines the policy for reconnecting to a device after
/// connection loss, using exponential backoff to avoid overwhelming the device.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ReconnectionPolicy {
    /// Maximum number of reconnection attempts before giving up.
    ///
    /// Use `UNLIMITED_ATTEMPTS` (u8::MAX) for infinite retries during
    /// active coaching sessions. Defaults to 5 attempts.
    pub max_attempts: u8,

    /// Initial delay before the first reconnection attempt.
    ///
    /// Defaults to 2 seconds.
    pub initial_delay: Duration,

    /// Multiplier for exponential backoff calculation.
    ///
    /// Each subsequent delay is multiplied by this factor.
    /// Defaults to 2.0 for exponential backoff (2s, 4s, 8s, 16s, 30s cap).
    pub backoff_multiplier: f32,

    /// Maximum delay between reconnection attempts.
    ///
    /// The exponential backoff will not exceed this value.
    /// Defaults to 30 seconds for coaching mode.
    pub max_delay: Duration,

    /// Jitter factor for randomization (0.0 to 1.0).
    ///
    /// Applied as a multiplier to add randomness: delay * (1.0 - jitter_factor/2 + random * jitter_factor).
    /// For example, with jitter_factor=0.3 and delay=10s, actual delay ranges from 8.5s to 10s.
    /// Defaults to 0.2 (20% jitter) to prevent thundering herd.
    pub jitter_factor: f32,
}

impl Default for ReconnectionPolicy {
    fn default() -> Self {
        Self {
            max_attempts: 5,
            initial_delay: Duration::from_secs(2),
            backoff_multiplier: 2.0,
            max_delay: Duration::from_secs(30),
            jitter_factor: 0.2,
        }
    }
}

impl ReconnectionPolicy {
    /// Returns the default policy for short sessions (e.g., quick workouts).
    ///
    /// Uses standard backoff with limited retries.
    pub fn short_session() -> Self {
        Self::default()
    }

    /// Returns the policy for long coaching sessions (all-day monitoring).
    ///
    /// Uses unlimited retries with jittered exponential backoff (2s → 30s cap).
    /// Battery-aware: longer gaps between retries reduce radio usage.
    pub fn coaching_session() -> Self {
        Self {
            max_attempts: UNLIMITED_ATTEMPTS,
            initial_delay: Duration::from_secs(2),
            backoff_multiplier: 2.0,
            max_delay: Duration::from_secs(30),
            jitter_factor: 0.2,
        }
    }

    /// Returns `true` if this policy allows unlimited reconnection attempts.
    pub fn is_unlimited(&self) -> bool {
        self.max_attempts == UNLIMITED_ATTEMPTS
    }

    /// Calculate the delay for a given reconnection attempt using jittered exponential backoff.
    ///
    /// The delay increases exponentially with each attempt, capped at `max_delay`,
    /// then randomized by `jitter_factor` to prevent thundering herd.
    ///
    /// # Arguments
    ///
    /// * `attempt` - The attempt number (1-indexed). First attempt is 1.
    ///
    /// # Returns
    ///
    /// The duration to wait before this attempt, capped at `max_delay` and jittered.
    ///
    /// # Examples
    ///
    /// ```
    /// use heart_beat::domain::reconnection::{ReconnectionPolicy, UNLIMITED_ATTEMPTS};
    /// use std::time::Duration;
    ///
    /// let policy = ReconnectionPolicy::default();
    ///
    /// // Delays follow exponential backoff: 2s, 4s, 8s, 16s, 30s(cap), 30s(cap)
    /// assert_eq!(policy.calculate_delay(1), Duration::from_secs(2));
    /// assert_eq!(policy.calculate_delay(2), Duration::from_secs(4));
    /// assert_eq!(policy.calculate_delay(3), Duration::from_secs(8));
    /// assert_eq!(policy.calculate_delay(4), Duration::from_secs(16));
    /// assert_eq!(policy.calculate_delay(5), Duration::from_secs(30)); // capped
    /// ```
    pub fn calculate_delay(&self, attempt: u8) -> Duration {
        if attempt == 0 {
            return Duration::from_secs(0);
        }

        // Calculate exponential backoff: initial_delay * (backoff_multiplier ^ (attempt - 1))
        let multiplier = self.backoff_multiplier.powi((attempt - 1) as i32);
        let delay_secs = self.initial_delay.as_secs_f32() * multiplier;
        let calculated_delay = Duration::from_secs_f32(delay_secs);

        // Cap at max_delay
        let capped_delay = if calculated_delay > self.max_delay {
            self.max_delay
        } else {
            calculated_delay
        };

        // Apply jitter to prevent thundering herd
        self.apply_jitter(capped_delay)
    }

    /// Apply jitter randomization to a delay.
    ///
    /// Uses uniform random distribution within ±jitter_factor/2 of the original delay.
    fn apply_jitter(&self, delay: Duration) -> Duration {
        if self.jitter_factor <= 0.0 {
            return delay;
        }

        let base_secs = delay.as_secs_f32();
        let jitter_range = base_secs * self.jitter_factor;
        // Generate random value in [0, 1) using simple prng
        let random_factor: f32 = (rand_simple() % 1000) as f32 / 1000.0;

        // Range: delay * (1.0 - jitter_factor/2) to delay * (1.0 + jitter_factor/2)
        let min_delay = base_secs - jitter_range / 2.0;
        let actual_delay = min_delay + random_factor * jitter_range;

        // Ensure we don't go below half the original delay or zero
        Duration::from_secs_f32(actual_delay.max(base_secs * 0.5).max(0.1))
    }
}

/// Simple deterministic "random" for jitter (use rand in production).
fn rand_simple() -> u32 {
    use std::time::SystemTime;
    let nanos = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap()
        .subsec_nanos();
    nanos.wrapping_mul(1103515245).wrapping_add(12345)
}

/// Current connection status of a BLE device.
///
/// This enum represents the various states of a device connection,
/// including normal operation, reconnection attempts, and failures.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ConnectionStatus {
    /// Device is disconnected and no reconnection is in progress.
    Disconnected,

    /// Initial connection attempt is in progress.
    Connecting,

    /// Device is connected and operating normally.
    Connected {
        /// Unique identifier of the connected device.
        device_id: String,
    },

    /// Automatic reconnection is in progress after connection loss.
    Reconnecting {
        /// Current attempt number (1-indexed).
        attempt: u8,
        /// Maximum number of attempts configured.
        max_attempts: u8,
    },

    /// Reconnection failed after exhausting all attempts.
    ReconnectFailed {
        /// Reason for the failure.
        reason: String,
    },
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_policy() {
        let policy = ReconnectionPolicy::default();
        assert_eq!(policy.max_attempts, 5);
        assert_eq!(policy.initial_delay, Duration::from_secs(2));
        assert_eq!(policy.backoff_multiplier, 2.0);
        assert_eq!(policy.max_delay, Duration::from_secs(30));
        assert_eq!(policy.jitter_factor, 0.2);
    }

    #[test]
    fn test_coaching_session_policy() {
        let policy = ReconnectionPolicy::coaching_session();
        assert_eq!(policy.max_attempts, UNLIMITED_ATTEMPTS);
        assert!(policy.is_unlimited());
        assert_eq!(policy.initial_delay, Duration::from_secs(2));
        assert_eq!(policy.max_delay, Duration::from_secs(30));
    }

    #[test]
    fn test_short_session_policy() {
        let policy = ReconnectionPolicy::short_session();
        assert_eq!(policy.max_attempts, 5);
        assert!(!policy.is_unlimited());
    }

    #[test]
    fn test_calculate_delay_exponential_backoff() {
        // Use zero-jitter policy for deterministic test results
        let policy = ReconnectionPolicy {
            max_attempts: 5,
            initial_delay: Duration::from_secs(2),
            backoff_multiplier: 2.0,
            max_delay: Duration::from_secs(30),
            jitter_factor: 0.0,
        };

        // Test exponential backoff: 2s, 4s, 8s, 16s, 30s
        assert_eq!(policy.calculate_delay(1), Duration::from_secs(2));
        assert_eq!(policy.calculate_delay(2), Duration::from_secs(4));
        assert_eq!(policy.calculate_delay(3), Duration::from_secs(8));
        assert_eq!(policy.calculate_delay(4), Duration::from_secs(16));
        assert_eq!(policy.calculate_delay(5), Duration::from_secs(30));
    }

    #[test]
    fn test_calculate_delay_capped_at_max() {
        // Use zero-jitter policy for deterministic test results
        let policy = ReconnectionPolicy {
            max_attempts: 5,
            initial_delay: Duration::from_secs(2),
            backoff_multiplier: 2.0,
            max_delay: Duration::from_secs(30),
            jitter_factor: 0.0,
        };

        // Attempt 6 would be 64s, but should be capped at 30s
        assert_eq!(policy.calculate_delay(6), Duration::from_secs(30));
        assert_eq!(policy.calculate_delay(10), Duration::from_secs(30));
    }

    #[test]
    fn test_calculate_delay_zero_attempt() {
        let policy = ReconnectionPolicy::default();
        assert_eq!(policy.calculate_delay(0), Duration::from_secs(0));
    }

    #[test]
    fn test_calculate_delay_custom_policy() {
        let policy = ReconnectionPolicy {
            max_attempts: 3,
            initial_delay: Duration::from_secs(2),
            backoff_multiplier: 3.0,
            max_delay: Duration::from_secs(20),
            jitter_factor: 0.0, // Disable jitter for deterministic test
        };

        // Test custom backoff: 2s, 6s, 18s
        assert_eq!(policy.calculate_delay(1), Duration::from_secs(2));
        assert_eq!(policy.calculate_delay(2), Duration::from_secs(6));
        assert_eq!(policy.calculate_delay(3), Duration::from_secs(18));
    }

    #[test]
    fn test_connection_status_serialization() {
        // Test Disconnected
        let status = ConnectionStatus::Disconnected;
        let json = serde_json::to_string(&status).unwrap();
        let deserialized: ConnectionStatus = serde_json::from_str(&json).unwrap();
        assert_eq!(status, deserialized);

        // Test Connecting
        let status = ConnectionStatus::Connecting;
        let json = serde_json::to_string(&status).unwrap();
        let deserialized: ConnectionStatus = serde_json::from_str(&json).unwrap();
        assert_eq!(status, deserialized);

        // Test Connected
        let status = ConnectionStatus::Connected {
            device_id: "AA:BB:CC:DD:EE:FF".to_string(),
        };
        let json = serde_json::to_string(&status).unwrap();
        let deserialized: ConnectionStatus = serde_json::from_str(&json).unwrap();
        assert_eq!(status, deserialized);

        // Test Reconnecting
        let status = ConnectionStatus::Reconnecting {
            attempt: 3,
            max_attempts: 5,
        };
        let json = serde_json::to_string(&status).unwrap();
        let deserialized: ConnectionStatus = serde_json::from_str(&json).unwrap();
        assert_eq!(status, deserialized);

        // Test ReconnectFailed
        let status = ConnectionStatus::ReconnectFailed {
            reason: "Device out of range".to_string(),
        };
        let json = serde_json::to_string(&status).unwrap();
        let deserialized: ConnectionStatus = serde_json::from_str(&json).unwrap();
        assert_eq!(status, deserialized);
    }

    #[test]
    fn test_policy_serialization() {
        let policy = ReconnectionPolicy::default();
        let json = serde_json::to_string(&policy).unwrap();
        let deserialized: ReconnectionPolicy = serde_json::from_str(&json).unwrap();
        assert_eq!(policy, deserialized);
    }
}
