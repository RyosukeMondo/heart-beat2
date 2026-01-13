//! Heart rate domain types and parsing logic.
//!
//! This module provides core data types for heart rate monitoring, including
//! measurements, zones, and related utilities. All types are designed to be
//! pure data structures with no I/O dependencies.

use serde::{Deserialize, Serialize};
use std::fmt;
use std::time::Instant;

/// Heart rate training zones based on percentage of max heart rate.
///
/// These zones are commonly used in exercise physiology to categorize
/// training intensity levels.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
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

    /// High-precision timestamp when the BLE notification was received.
    ///
    /// Captured using a monotonic clock (std::time::Instant) immediately upon
    /// receiving the BLE notification. Used for end-to-end latency measurement
    /// from BLE event to UI update. This is relative to an arbitrary epoch and
    /// is only meaningful for calculating durations.
    ///
    /// Set to `None` by the parser and populated by the caller immediately
    /// after receiving the BLE notification.
    pub receive_timestamp: Option<Instant>,
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

/// A discovered BLE device during scanning.
///
/// This struct represents a device found during BLE scanning operations,
/// containing the minimal information needed to identify and connect to the device.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DiscoveredDevice {
    /// Platform-specific device identifier.
    ///
    /// This is typically a UUID on iOS/macOS or a MAC address on Linux/Android.
    pub id: String,

    /// Advertised device name, if available.
    ///
    /// Not all devices advertise a name in their BLE advertisements.
    pub name: Option<String>,

    /// Received Signal Strength Indicator in dBm.
    ///
    /// Typically ranges from -100 (weak) to -30 (strong). Used to estimate
    /// proximity and connection quality.
    pub rssi: i16,
}

/// Heart rate data after processing through filtering and HRV calculation.
///
/// This struct represents the final output after raw BLE measurements have been
/// parsed, validated, filtered, and enriched with HRV metrics. It's designed
/// to be serializable for transmission to Flutter via Flutter Rust Bridge.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct FilteredHeartRate {
    /// Unfiltered BPM directly from the heart rate sensor.
    pub raw_bpm: u16,

    /// Kalman-filtered BPM for smoother visualization.
    ///
    /// This value has been processed through a Kalman filter to reduce
    /// sensor noise and provide a more stable reading.
    pub filtered_bpm: u16,

    /// Heart Rate Variability metric (RMSSD) in milliseconds.
    ///
    /// Available only when RR-intervals are present in the sensor data.
    /// RMSSD (Root Mean Square of Successive Differences) is a time-domain
    /// HRV metric used for stress and recovery assessment.
    pub rmssd: Option<f64>,

    /// Filter confidence/variance in BPM².
    ///
    /// Represents the Kalman filter's estimated uncertainty in the filtered value.
    /// Lower values indicate higher confidence (filter has converged), while higher
    /// values indicate lower confidence (filter is warming up or tracking changes).
    ///
    /// This field is optional for backward compatibility. When present:
    /// - Values < 1.0: High confidence, filter has converged
    /// - Values 1.0-5.0: Moderate confidence, filter is stable
    /// - Values > 5.0: Low confidence, filter is warming up or adjusting to changes
    ///
    /// UI can use this to display confidence indicators or warning messages.
    pub filter_variance: Option<f64>,

    /// Device battery level as a percentage (0-100).
    ///
    /// May be `None` if the device doesn't support battery level reporting
    /// or if it hasn't been read yet.
    pub battery_level: Option<u8>,

    /// Unix timestamp in milliseconds when this measurement was processed.
    ///
    /// This is the system time when the data was processed, not the sensor
    /// measurement time.
    pub timestamp: u64,

    /// Microseconds elapsed since an arbitrary epoch when BLE notification was received.
    ///
    /// This is a high-precision monotonic timestamp captured immediately upon
    /// receiving the BLE notification, represented as microseconds. Used for
    /// end-to-end latency calculation from BLE event to UI update.
    ///
    /// The epoch is arbitrary (based on system boot or process start), so this
    /// value is only meaningful for computing durations, not absolute times.
    /// UI layer can compare this against its own monotonic timestamp to calculate
    /// latency: `Duration = UI_timestamp - receive_timestamp_micros`.
    ///
    /// `None` if timestamp capture was not available or not enabled.
    pub receive_timestamp_micros: Option<u64>,
}

/// Parse a BLE Heart Rate Measurement characteristic value.
///
/// This function parses raw BLE packets according to the Bluetooth Heart Rate Service
/// specification (GATT Characteristic UUID 0x2A37). The packet format is:
///
/// - Byte 0: Flags
///   - Bit 0: Heart Rate Value Format (0 = UINT8, 1 = UINT16)
///   - Bit 1-2: Sensor Contact Status (00/01 = not supported/not detected, 10/11 = supported/detected)
///   - Bit 3: Energy Expended Status (0 = not present, 1 = present)
///   - Bit 4: RR-Interval (0 = not present, 1 = present)
///   - Bit 5-7: Reserved
/// - Byte 1+: Heart Rate Value (UINT8 or UINT16 based on bit 0)
/// - Optional: Energy Expended (UINT16) if bit 3 is set
/// - Optional: RR-Intervals (one or more UINT16 values) if bit 4 is set
///
/// # Arguments
///
/// * `data` - Raw byte array from BLE Heart Rate Measurement characteristic
///
/// # Returns
///
/// * `Ok(HeartRateMeasurement)` - Parsed measurement on success
/// * `Err` - If the packet is invalid or malformed
///
/// # Examples
///
/// ```
/// use heart_beat::domain::heart_rate::parse_heart_rate;
///
/// // Simple UINT8 format with sensor contact
/// let data = &[0x06, 72]; // Flags=0x06 (sensor contact detected), BPM=72
/// let measurement = parse_heart_rate(data).unwrap();
/// assert_eq!(measurement.bpm, 72);
/// assert_eq!(measurement.sensor_contact, true);
/// ```
pub fn parse_heart_rate(data: &[u8]) -> anyhow::Result<HeartRateMeasurement> {
    use anyhow::bail;

    // Minimum packet size is 2 bytes (flags + UINT8 BPM)
    if data.len() < 2 {
        bail!("Heart rate packet too short: {} bytes", data.len());
    }

    let flags = data[0];
    let mut offset = 1;

    // Bit 0: Heart Rate Value Format (0 = UINT8, 1 = UINT16)
    let is_uint16 = (flags & 0x01) != 0;

    // Parse BPM value
    let bpm = if is_uint16 {
        if data.len() < offset + 2 {
            bail!("Insufficient data for UINT16 heart rate value");
        }
        let value = u16::from_le_bytes([data[offset], data[offset + 1]]);
        offset += 2;
        value
    } else {
        let value = data[offset] as u16;
        offset += 1;
        value
    };

    // Bits 1-2: Sensor Contact Status
    // 00 or 01 = not supported or not detected
    // 10 or 11 = supported and detected
    let sensor_contact_bits = (flags >> 1) & 0x03;
    let sensor_contact = sensor_contact_bits >= 2;

    // Bit 3: Energy Expended Status
    let has_energy_expended = (flags & 0x08) != 0;
    if has_energy_expended {
        // Skip energy expended field (UINT16)
        if data.len() < offset + 2 {
            bail!("Insufficient data for energy expended field");
        }
        offset += 2;
    }

    // Bit 4: RR-Interval present
    let has_rr_intervals = (flags & 0x10) != 0;
    let mut rr_intervals = Vec::new();

    if has_rr_intervals {
        // RR-intervals are UINT16 values in 1/1024 second resolution
        while offset + 1 < data.len() {
            if data.len() < offset + 2 {
                // Incomplete RR-interval at end of packet - ignore it
                break;
            }
            let rr = u16::from_le_bytes([data[offset], data[offset + 1]]);
            rr_intervals.push(rr);
            offset += 2;
        }
    }

    Ok(HeartRateMeasurement {
        bpm,
        rr_intervals,
        sensor_contact,
        receive_timestamp: None, // Set by caller after parsing
    })
}

#[cfg(test)]
#[allow(clippy::useless_vec)]
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
            receive_timestamp: None,
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
            receive_timestamp: None,
        };

        let display = measurement.to_string();
        assert!(display.contains("Contact: No"));
        assert!(display.contains("RR-intervals: 0"));
    }

    // Parser tests

    #[test]
    fn test_parse_heart_rate_uint8_with_contact() {
        // Flags: 0x06 = 0b00000110 (UINT8 format, sensor contact detected)
        // BPM: 72
        let data = &[0x06, 72];
        let result = parse_heart_rate(data).unwrap();

        assert_eq!(result.bpm, 72);
        assert!(result.sensor_contact);
        assert_eq!(result.rr_intervals.len(), 0);
    }

    #[test]
    fn test_parse_heart_rate_uint8_no_contact() {
        // Flags: 0x00 = 0b00000000 (UINT8 format, no sensor contact)
        // BPM: 65
        let data = &[0x00, 65];
        let result = parse_heart_rate(data).unwrap();

        assert_eq!(result.bpm, 65);
        assert!(!result.sensor_contact);
        assert_eq!(result.rr_intervals.len(), 0);
    }

    #[test]
    fn test_parse_heart_rate_uint16_with_contact() {
        // Flags: 0x07 = 0b00000111 (UINT16 format, sensor contact detected)
        // BPM: 150 (0x0096 in little-endian)
        let data = &[0x07, 0x96, 0x00];
        let result = parse_heart_rate(data).unwrap();

        assert_eq!(result.bpm, 150);
        assert!(result.sensor_contact);
        assert_eq!(result.rr_intervals.len(), 0);
    }

    #[test]
    fn test_parse_heart_rate_with_rr_intervals() {
        // Flags: 0x16 = 0b00010110 (UINT8 format, sensor contact, RR-intervals present)
        // BPM: 72
        // RR-intervals: 820, 830, 815 (in 1/1024 second units, little-endian)
        let data = &[
            0x16, 72, 0x34, 0x03, // RR: 820 (0x0334)
            0x3E, 0x03, // RR: 830 (0x033E)
            0x2F, 0x03, // RR: 815 (0x032F)
        ];
        let result = parse_heart_rate(data).unwrap();

        assert_eq!(result.bpm, 72);
        assert!(result.sensor_contact);
        assert_eq!(result.rr_intervals, vec![820, 830, 815]);
    }

    #[test]
    fn test_parse_heart_rate_with_energy_expended() {
        // Flags: 0x0E = 0b00001110 (UINT8 format, sensor contact, energy expended)
        // BPM: 75
        // Energy Expended: 1234 (0x04D2 in little-endian) - should be skipped
        let data = &[0x0E, 75, 0xD2, 0x04];
        let result = parse_heart_rate(data).unwrap();

        assert_eq!(result.bpm, 75);
        assert!(result.sensor_contact);
        assert_eq!(result.rr_intervals.len(), 0);
    }

    #[test]
    fn test_parse_heart_rate_with_energy_and_rr() {
        // Flags: 0x1E = 0b00011110 (UINT8, sensor contact, energy, RR-intervals)
        // BPM: 80
        // Energy Expended: 500 (0x01F4)
        // RR-intervals: 750 (0x02EE)
        let data = &[0x1E, 80, 0xF4, 0x01, 0xEE, 0x02];
        let result = parse_heart_rate(data).unwrap();

        assert_eq!(result.bpm, 80);
        assert!(result.sensor_contact);
        assert_eq!(result.rr_intervals, vec![750]);
    }

    #[test]
    fn test_parse_heart_rate_packet_too_short() {
        let data = &[0x06]; // Only flags, no BPM
        let result = parse_heart_rate(data);

        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("too short"));
    }

    #[test]
    fn test_parse_heart_rate_empty_packet() {
        let data = &[];
        let result = parse_heart_rate(data);

        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("too short"));
    }

    #[test]
    fn test_parse_heart_rate_uint16_truncated() {
        // Flags indicate UINT16 but only 1 byte of data
        let data = &[0x01, 72];
        let result = parse_heart_rate(data);

        assert!(result.is_err());
        assert!(result
            .unwrap_err()
            .to_string()
            .contains("Insufficient data for UINT16"));
    }

    #[test]
    fn test_parse_heart_rate_energy_truncated() {
        // Flags indicate energy expended but insufficient bytes
        let data = &[0x0E, 72, 0xD2]; // Missing second byte of energy
        let result = parse_heart_rate(data);

        assert!(result.is_err());
        assert!(result
            .unwrap_err()
            .to_string()
            .contains("Insufficient data for energy"));
    }

    #[test]
    fn test_parse_heart_rate_rr_incomplete() {
        // RR-intervals flag set but incomplete data (should handle gracefully)
        // Flags: 0x16 (UINT8, sensor contact, RR-intervals)
        // BPM: 72
        // Partial RR-interval: only 1 byte instead of 2
        let data = &[0x16, 72, 0x34];
        let result = parse_heart_rate(data).unwrap();

        assert_eq!(result.bpm, 72);
        assert!(result.sensor_contact);
        // Incomplete RR-interval should be ignored
        assert_eq!(result.rr_intervals.len(), 0);
    }

    #[test]
    fn test_parse_heart_rate_multiple_rr_intervals() {
        // Test with many RR-intervals
        let data = &[
            0x16, 70, // Flags and BPM
            0x00, 0x03, // RR: 768
            0x10, 0x03, // RR: 784
            0x20, 0x03, // RR: 800
            0x30, 0x03, // RR: 816
            0x40, 0x03, // RR: 832
        ];
        let result = parse_heart_rate(data).unwrap();

        assert_eq!(result.bpm, 70);
        assert_eq!(result.rr_intervals, vec![768, 784, 800, 816, 832]);
    }

    #[test]
    fn test_parse_heart_rate_sensor_contact_bit_patterns() {
        // Test all sensor contact bit patterns
        // Bits 1-2: 00 = not supported (value 0)
        let data = &[0x00, 60];
        assert!(!parse_heart_rate(data).unwrap().sensor_contact);

        // Bits 1-2: 01 = not detected (value 1)
        let data = &[0x02, 60];
        assert!(!parse_heart_rate(data).unwrap().sensor_contact);

        // Bits 1-2: 10 = detected (value 2)
        let data = &[0x04, 60];
        assert!(parse_heart_rate(data).unwrap().sensor_contact);

        // Bits 1-2: 11 = detected (value 3)
        let data = &[0x06, 60];
        assert!(parse_heart_rate(data).unwrap().sensor_contact);
    }

    // Property-based tests using proptest
    mod proptests {
        use super::*;
        use proptest::prelude::*;

        // Property 1: Parser should never panic on any arbitrary byte sequence
        proptest! {
            #[test]
            fn parser_never_panics_on_arbitrary_input(data in prop::collection::vec(any::<u8>(), 0..100)) {
                // The parser should either succeed or return an error, but never panic
                let _ = parse_heart_rate(&data);
            }
        }

        // Property 2: Valid UINT8 packets should always parse successfully
        proptest! {
            #[test]
            fn valid_uint8_packets_parse_correctly(
                bpm in 0u8..=255,
                sensor_contact in 0u8..=3,
            ) {
                // Build a valid UINT8 packet with varying sensor contact bits
                let flags = (sensor_contact << 1) & 0x06; // Bits 1-2 for sensor contact
                let data = vec![flags, bpm];

                let result = parse_heart_rate(&data);
                prop_assert!(result.is_ok());

                let measurement = result.unwrap();
                prop_assert_eq!(measurement.bpm, bpm as u16);
                prop_assert_eq!(measurement.sensor_contact, sensor_contact >= 2);
                prop_assert_eq!(measurement.rr_intervals.len(), 0);
            }
        }

        // Property 3: Valid UINT16 packets should always parse successfully
        proptest! {
            #[test]
            fn valid_uint16_packets_parse_correctly(
                bpm in 0u16..=65535,
                sensor_contact in 0u8..=3,
            ) {
                // Build a valid UINT16 packet
                let flags = 0x01 | ((sensor_contact << 1) & 0x06); // Bit 0 set for UINT16
                let bpm_bytes = bpm.to_le_bytes();
                let data = vec![flags, bpm_bytes[0], bpm_bytes[1]];

                let result = parse_heart_rate(&data);
                prop_assert!(result.is_ok());

                let measurement = result.unwrap();
                prop_assert_eq!(measurement.bpm, bpm);
                prop_assert_eq!(measurement.sensor_contact, sensor_contact >= 2);
                prop_assert_eq!(measurement.rr_intervals.len(), 0);
            }
        }

        // Property 4: Valid packets with RR-intervals should parse correctly
        proptest! {
            #[test]
            fn valid_packets_with_rr_intervals_parse_correctly(
                bpm in 30u8..=220,
                rr_intervals in prop::collection::vec(300u16..=2000, 1..=10),
            ) {
                // Build a valid UINT8 packet with RR-intervals
                // Flags: 0x16 = sensor contact + RR-intervals present
                let mut data = vec![0x16, bpm];

                // Add RR-intervals in little-endian format
                for rr in &rr_intervals {
                    let rr_bytes = rr.to_le_bytes();
                    data.push(rr_bytes[0]);
                    data.push(rr_bytes[1]);
                }

                let result = parse_heart_rate(&data);
                prop_assert!(result.is_ok());

                let measurement = result.unwrap();
                prop_assert_eq!(measurement.bpm, bpm as u16);
                prop_assert_eq!(measurement.sensor_contact, true);
                prop_assert_eq!(measurement.rr_intervals, rr_intervals);
            }
        }

        // Property 5: Packets with energy expended should be handled correctly
        proptest! {
            #[test]
            fn packets_with_energy_expended_handled_correctly(
                bpm in 30u8..=220,
                energy in 0u16..=65535,
            ) {
                // Build a valid UINT8 packet with energy expended
                // Flags: 0x0E = sensor contact + energy expended
                let energy_bytes = energy.to_le_bytes();
                let data = vec![0x0E, bpm, energy_bytes[0], energy_bytes[1]];

                let result = parse_heart_rate(&data);
                prop_assert!(result.is_ok());

                let measurement = result.unwrap();
                prop_assert_eq!(measurement.bpm, bpm as u16);
                prop_assert_eq!(measurement.sensor_contact, true);
                // Energy expended should be skipped, not in output
                prop_assert_eq!(measurement.rr_intervals.len(), 0);
            }
        }

        // Property 6: Complex packets with all fields should parse correctly
        proptest! {
            #[test]
            fn complex_packets_with_all_fields_parse_correctly(
                bpm in 30u8..=220,
                energy in 0u16..=65535,
                rr_intervals in prop::collection::vec(300u16..=2000, 1..=5),
            ) {
                // Build a packet with UINT8 BPM, energy expended, and RR-intervals
                // Flags: 0x1E = sensor contact + energy expended + RR-intervals
                let mut data = vec![0x1E, bpm];

                // Add energy expended
                let energy_bytes = energy.to_le_bytes();
                data.push(energy_bytes[0]);
                data.push(energy_bytes[1]);

                // Add RR-intervals
                for rr in &rr_intervals {
                    let rr_bytes = rr.to_le_bytes();
                    data.push(rr_bytes[0]);
                    data.push(rr_bytes[1]);
                }

                let result = parse_heart_rate(&data);
                prop_assert!(result.is_ok());

                let measurement = result.unwrap();
                prop_assert_eq!(measurement.bpm, bpm as u16);
                prop_assert_eq!(measurement.sensor_contact, true);
                prop_assert_eq!(measurement.rr_intervals, rr_intervals);
            }
        }

        // Property 7: Truncated packets should return errors, not panic
        proptest! {
            #[test]
            fn truncated_packets_return_errors(
                flags in any::<u8>(),
                remaining_bytes in prop::collection::vec(any::<u8>(), 0..5),
            ) {
                let mut data = vec![flags];
                data.extend_from_slice(&remaining_bytes);

                // Parser should either succeed or return Err, never panic
                let result = parse_heart_rate(&data);

                // If it's a valid packet structure, it should parse
                // If it's truncated or invalid, it should return Err
                // We just verify it doesn't panic
                let _ = result;
            }
        }
    }
}
