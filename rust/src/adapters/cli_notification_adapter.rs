//! CLI notification adapter for terminal output.
//!
//! This module provides a CLI implementation of the NotificationPort trait that
//! displays notifications in the terminal using colored text and emojis. This is
//! useful for CLI-based biofeedback during training sessions.

use crate::ports::notification::{NotificationEvent, NotificationPort};
use crate::state::session::ZoneDeviation;
use anyhow::Result;
use async_trait::async_trait;
use colored::Colorize;
use flutter_rust_bridge::frb;

/// CLI notification adapter that prints colored notifications to stdout.
///
/// This adapter provides terminal-based biofeedback by printing notifications
/// with ANSI colors and emoji indicators. It's designed for CLI applications
/// where users monitor their training session in a terminal.
///
/// # Color scheme
/// - Zone deviations: Blue (too low), Red (too high), Green (in zone)
/// - Phase transitions: Yellow
/// - Battery warnings: Yellow
/// - Connection loss: Red + bold
/// - Workout ready: Green
#[frb(opaque)]
#[derive(Debug, Clone, Copy, Default)]
pub struct CliNotificationAdapter;

impl CliNotificationAdapter {
    /// Create a new CLI notification adapter.
    pub fn new() -> Self {
        Self
    }
}

#[async_trait]
impl NotificationPort for CliNotificationAdapter {
    async fn notify(&self, event: NotificationEvent) -> Result<()> {
        match event {
            NotificationEvent::ZoneDeviation {
                deviation,
                current_bpm,
                target_zone,
            } => {
                match deviation {
                    ZoneDeviation::TooLow => {
                        println!(
                            "{} BPM: {} (Target: {})",
                            "⬇️  TOO LOW".blue().bold(),
                            current_bpm,
                            target_zone
                        );
                    }
                    ZoneDeviation::TooHigh => {
                        println!(
                            "{} BPM: {} (Target: {})",
                            "⬆️  TOO HIGH".red().bold(),
                            current_bpm,
                            target_zone
                        );
                    }
                    ZoneDeviation::InZone => {
                        println!(
                            "{} BPM: {} (Target: {})",
                            "✓ IN ZONE".green().bold(),
                            current_bpm,
                            target_zone
                        );
                    }
                }
            }
            NotificationEvent::PhaseTransition {
                from_phase,
                to_phase,
                phase_name,
            } => {
                println!(
                    "\n{} {} → {} ({})\n",
                    "🔄 PHASE CHANGE".yellow().bold(),
                    from_phase,
                    to_phase,
                    phase_name
                );
            }
            NotificationEvent::BatteryLow { percentage } => {
                println!(
                    "{} {}%",
                    "🔋 LOW BATTERY".yellow().bold(),
                    percentage
                );
            }
            NotificationEvent::ConnectionLost => {
                println!("{}", "❌ CONNECTION LOST".red().bold());
            }
            NotificationEvent::WorkoutReady { plan_name } => {
                println!(
                    "{} {}",
                    "🏃 WORKOUT READY:".green().bold(),
                    plan_name
                );
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::heart_rate::Zone;

    // Note: These tests verify the adapter doesn't panic or error,
    // but don't capture stdout. Manual testing or integration tests
    // with stdout capture would be needed to verify actual output.

    #[tokio::test]
    async fn test_zone_deviation_too_low() {
        let adapter = CliNotificationAdapter::new();
        let result = adapter
            .notify(NotificationEvent::ZoneDeviation {
                deviation: ZoneDeviation::TooLow,
                current_bpm: 100,
                target_zone: Zone::Zone3,
            })
            .await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_zone_deviation_too_high() {
        let adapter = CliNotificationAdapter::new();
        let result = adapter
            .notify(NotificationEvent::ZoneDeviation {
                deviation: ZoneDeviation::TooHigh,
                current_bpm: 180,
                target_zone: Zone::Zone2,
            })
            .await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_zone_deviation_in_zone() {
        let adapter = CliNotificationAdapter::new();
        let result = adapter
            .notify(NotificationEvent::ZoneDeviation {
                deviation: ZoneDeviation::InZone,
                current_bpm: 140,
                target_zone: Zone::Zone3,
            })
            .await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_phase_transition() {
        let adapter = CliNotificationAdapter::new();
        let result = adapter
            .notify(NotificationEvent::PhaseTransition {
                from_phase: 0,
                to_phase: 1,
                phase_name: "Main Set".to_string(),
            })
            .await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_battery_low() {
        let adapter = CliNotificationAdapter::new();
        let result = adapter
            .notify(NotificationEvent::BatteryLow { percentage: 15 })
            .await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_connection_lost() {
        let adapter = CliNotificationAdapter::new();
        let result = adapter
            .notify(NotificationEvent::ConnectionLost)
            .await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_workout_ready() {
        let adapter = CliNotificationAdapter::new();
        let result = adapter
            .notify(NotificationEvent::WorkoutReady {
                plan_name: "Test Workout".to_string(),
            })
            .await;
        assert!(result.is_ok());
    }
}
