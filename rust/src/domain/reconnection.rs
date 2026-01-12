//! Reconnection policy and connection status types.
//!
//! This module provides core data types for managing automatic reconnection
//! to BLE heart rate monitors. All types are pure domain logic with no I/O.

use serde::{Deserialize, Serialize};
use std::time::Duration;

/// Configuration for automatic reconnection behavior.
///
/// This struct defines the policy for reconnecting to a device after
/// connection loss, using exponential backoff to avoid overwhelming the device.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ReconnectionPolicy {
    /// Maximum number of reconnection attempts before giving up.
    ///
    /// Defaults to 5 attempts.
    pub max_attempts: u8,

    /// Initial delay before the first reconnection attempt.
    ///
    /// Defaults to 1 second.
    pub initial_delay: Duration,

    /// Multiplier for exponential backoff calculation.
    ///
    /// Each subsequent delay is multiplied by this factor.
    /// Defaults to 2.0 for exponential backoff (1s, 2s, 4s, 8s, 16s).
    pub backoff_multiplier: f32,

    /// Maximum delay between reconnection attempts.
    ///
    /// The exponential backoff will not exceed this value.
    /// Defaults to 16 seconds.
    pub max_delay: Duration,
}

impl Default for ReconnectionPolicy {
    fn default() -> Self {
        Self {
            max_attempts: 5,
            initial_delay: Duration::from_secs(1),
            backoff_multiplier: 2.0,
            max_delay: Duration::from_secs(16),
        }
    }
}

impl ReconnectionPolicy {
    /// Calculate the delay for a given reconnection attempt using exponential backoff.
    ///
    /// The delay increases exponentially with each attempt, capped at `max_delay`.
    ///
    /// # Arguments
    ///
    /// * `attempt` - The attempt number (1-indexed). First attempt is 1.
    ///
    /// # Returns
    ///
    /// The duration to wait before this attempt, capped at `max_delay`.
    ///
    /// # Examples
    ///
    /// ```
    /// use heart_beat::domain::reconnection::ReconnectionPolicy;
    /// use std::time::Duration;
    ///
    /// let policy = ReconnectionPolicy::default();
    ///
    /// assert_eq!(policy.calculate_delay(1), Duration::from_secs(1));
    /// assert_eq!(policy.calculate_delay(2), Duration::from_secs(2));
    /// assert_eq!(policy.calculate_delay(3), Duration::from_secs(4));
    /// assert_eq!(policy.calculate_delay(4), Duration::from_secs(8));
    /// assert_eq!(policy.calculate_delay(5), Duration::from_secs(16));
    /// assert_eq!(policy.calculate_delay(6), Duration::from_secs(16)); // capped
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
        if calculated_delay > self.max_delay {
            self.max_delay
        } else {
            calculated_delay
        }
    }
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
        assert_eq!(policy.initial_delay, Duration::from_secs(1));
        assert_eq!(policy.backoff_multiplier, 2.0);
        assert_eq!(policy.max_delay, Duration::from_secs(16));
    }

    #[test]
    fn test_calculate_delay_exponential_backoff() {
        let policy = ReconnectionPolicy::default();

        // Test exponential backoff: 1s, 2s, 4s, 8s, 16s
        assert_eq!(policy.calculate_delay(1), Duration::from_secs(1));
        assert_eq!(policy.calculate_delay(2), Duration::from_secs(2));
        assert_eq!(policy.calculate_delay(3), Duration::from_secs(4));
        assert_eq!(policy.calculate_delay(4), Duration::from_secs(8));
        assert_eq!(policy.calculate_delay(5), Duration::from_secs(16));
    }

    #[test]
    fn test_calculate_delay_capped_at_max() {
        let policy = ReconnectionPolicy::default();

        // Attempt 6 would be 32s, but should be capped at 16s
        assert_eq!(policy.calculate_delay(6), Duration::from_secs(16));
        assert_eq!(policy.calculate_delay(10), Duration::from_secs(16));
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
