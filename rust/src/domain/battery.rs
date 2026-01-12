//! Battery level domain types.
//!
//! This module provides core data types for battery monitoring from BLE devices.
//! All types are designed to be pure data structures with no I/O dependencies.

use serde::{Deserialize, Serialize};
use std::time::SystemTime;

/// Battery level measurement from a BLE device.
///
/// This struct represents the battery state of a connected device following
/// the Bluetooth Battery Service specification (0x180F).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct BatteryLevel {
    /// Battery level as a percentage (0-100).
    ///
    /// May be `None` if the device doesn't support battery level reporting
    /// or if it hasn't been read yet.
    pub level: Option<u8>,

    /// Whether the device is currently charging.
    ///
    /// This field indicates if the device is connected to a power source.
    pub is_charging: bool,

    /// Timestamp when this battery level was measured.
    ///
    /// This is the system time when the battery level was read from the device.
    pub timestamp: SystemTime,
}

impl BatteryLevel {
    /// Check if the battery level is low (below 15%).
    ///
    /// Returns `true` if the battery level is known and below the 15% threshold.
    /// Returns `false` if the battery level is at or above 15%, or if it's unknown.
    ///
    /// # Examples
    ///
    /// ```
    /// use heart_beat::domain::battery::BatteryLevel;
    /// use std::time::SystemTime;
    ///
    /// let battery = BatteryLevel {
    ///     level: Some(14),
    ///     is_charging: false,
    ///     timestamp: SystemTime::now(),
    /// };
    /// assert!(battery.is_low());
    ///
    /// let battery = BatteryLevel {
    ///     level: Some(15),
    ///     is_charging: false,
    ///     timestamp: SystemTime::now(),
    /// };
    /// assert!(!battery.is_low());
    /// ```
    pub fn is_low(&self) -> bool {
        match self.level {
            Some(level) => level < 15,
            None => false,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_is_low_boundary_values() {
        let timestamp = SystemTime::now();

        // Test at 14% - should be low
        let battery = BatteryLevel {
            level: Some(14),
            is_charging: false,
            timestamp,
        };
        assert!(battery.is_low());

        // Test at 15% - should NOT be low (boundary)
        let battery = BatteryLevel {
            level: Some(15),
            is_charging: false,
            timestamp,
        };
        assert!(!battery.is_low());

        // Test at 16% - should NOT be low
        let battery = BatteryLevel {
            level: Some(16),
            is_charging: false,
            timestamp,
        };
        assert!(!battery.is_low());

        // Test at 0% - should be low
        let battery = BatteryLevel {
            level: Some(0),
            is_charging: false,
            timestamp,
        };
        assert!(battery.is_low());

        // Test at 100% - should NOT be low
        let battery = BatteryLevel {
            level: Some(100),
            is_charging: false,
            timestamp,
        };
        assert!(!battery.is_low());
    }

    #[test]
    fn test_is_low_none_level() {
        let timestamp = SystemTime::now();

        // Test with None level - should NOT be low
        let battery = BatteryLevel {
            level: None,
            is_charging: false,
            timestamp,
        };
        assert!(!battery.is_low());
    }

    #[test]
    fn test_serialization() {
        let timestamp = SystemTime::now();
        let battery = BatteryLevel {
            level: Some(75),
            is_charging: true,
            timestamp,
        };

        // Test serialization round-trip
        let json = serde_json::to_string(&battery).unwrap();
        let deserialized: BatteryLevel = serde_json::from_str(&json).unwrap();

        assert_eq!(battery.level, deserialized.level);
        assert_eq!(battery.is_charging, deserialized.is_charging);
        assert_eq!(battery.timestamp, deserialized.timestamp);
    }

    #[test]
    fn test_serialization_none_level() {
        let timestamp = SystemTime::now();
        let battery = BatteryLevel {
            level: None,
            is_charging: false,
            timestamp,
        };

        // Test serialization round-trip with None
        let json = serde_json::to_string(&battery).unwrap();
        let deserialized: BatteryLevel = serde_json::from_str(&json).unwrap();

        assert_eq!(battery.level, deserialized.level);
        assert_eq!(battery.is_charging, deserialized.is_charging);
        assert_eq!(battery.timestamp, deserialized.timestamp);
    }
}
