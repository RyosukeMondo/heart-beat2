//! Heart rate domain types and parsing logic.
//!
//! This module provides core data types for heart rate monitoring, including
//! measurements, zones, and related utilities. All types are designed to be
//! pure data structures with no I/O dependencies.

use std::fmt;

/// Heart rate training zones based on percentage of max heart rate.
///
/// These zones are commonly used in exercise physiology to categorize
/// training intensity levels.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Zone {
    /// Zone 1: 50-60% of max HR (very light, recovery)
    Zone1,
    /// Zone 2: 60-70% of max HR (light, fat burning)
    Zone2,
    /// Zone 3: 70-80% of max HR (moderate, aerobic)
    Zone3,
    /// Zone 4: 80-90% of max HR (hard, anaerobic threshold)
    Zone4,
    /// Zone 5: 90-100% of max HR (maximum effort)
    Zone5,
}

impl fmt::Display for Zone {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Zone::Zone1 => write!(f, "Zone 1 (Recovery)"),
            Zone::Zone2 => write!(f, "Zone 2 (Fat Burning)"),
            Zone::Zone3 => write!(f, "Zone 3 (Aerobic)"),
            Zone::Zone4 => write!(f, "Zone 4 (Threshold)"),
            Zone::Zone5 => write!(f, "Zone 5 (Maximum)"),
        }
    }
}

/// A heart rate measurement from a BLE heart rate sensor.
///
/// This struct represents a single measurement packet received from a heart rate
/// monitor following the Bluetooth Heart Rate Service specification (0x180D).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HeartRateMeasurement {
    /// Heart rate in beats per minute.
    pub bpm: u16,

    /// RR-intervals in 1/1024 second resolution.
    ///
    /// RR-intervals represent the time between successive heartbeats and are
    /// used for heart rate variability (HRV) analysis. The values are stored
    /// in units of 1/1024 seconds as specified by the Bluetooth SIG.
    pub rr_intervals: Vec<u16>,

    /// Whether the sensor has detected skin contact.
    ///
    /// When `false`, the BPM reading may be unreliable as the sensor is not
    /// properly positioned against the skin.
    pub sensor_contact: bool,
}

impl fmt::Display for HeartRateMeasurement {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "HR: {} BPM, Contact: {}, RR-intervals: {}",
            self.bpm,
            if self.sensor_contact { "Yes" } else { "No" },
            self.rr_intervals.len()
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_zone_display() {
        assert_eq!(Zone::Zone1.to_string(), "Zone 1 (Recovery)");
        assert_eq!(Zone::Zone2.to_string(), "Zone 2 (Fat Burning)");
        assert_eq!(Zone::Zone3.to_string(), "Zone 3 (Aerobic)");
        assert_eq!(Zone::Zone4.to_string(), "Zone 4 (Threshold)");
        assert_eq!(Zone::Zone5.to_string(), "Zone 5 (Maximum)");
    }

    #[test]
    fn test_heart_rate_measurement_display() {
        let measurement = HeartRateMeasurement {
            bpm: 72,
            rr_intervals: vec![820, 830, 815],
            sensor_contact: true,
        };

        let display = measurement.to_string();
        assert!(display.contains("72 BPM"));
        assert!(display.contains("Contact: Yes"));
        assert!(display.contains("RR-intervals: 3"));
    }

    #[test]
    fn test_heart_rate_measurement_no_contact() {
        let measurement = HeartRateMeasurement {
            bpm: 0,
            rr_intervals: vec![],
            sensor_contact: false,
        };

        let display = measurement.to_string();
        assert!(display.contains("Contact: No"));
        assert!(display.contains("RR-intervals: 0"));
    }
}
