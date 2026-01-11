//! Custom notification port implementation example.
//!
//! This example demonstrates how to implement the NotificationPort trait to create
//! custom notification handlers. This is useful for:
//! - Integrating with different notification systems
//! - Logging notifications to files
//! - Sending alerts via custom channels (email, SMS, webhooks, etc.)
//!
//! Run with: cargo run --example custom_notifier

use async_trait::async_trait;
use heart_beat::domain::heart_rate::Zone;
use heart_beat::ports::notification::{NotificationEvent, NotificationPort};
use heart_beat::state::session::ZoneDeviation;
use std::fs::OpenOptions;
use std::io::Write;

/// Custom notification handler that logs to both console and file.
///
/// This implementation demonstrates:
/// - File-based notification logging
/// - Formatted console output
/// - Timestamp tracking
/// - Different handling for different notification types
pub struct FileAndConsoleNotifier {
    log_file_path: String,
    enable_console: bool,
}

impl FileAndConsoleNotifier {
    /// Create a new notifier that logs to the specified file.
    pub fn new(log_file_path: String) -> Self {
        Self {
            log_file_path,
            enable_console: true,
        }
    }

    /// Log a message to the file.
    fn log_to_file(&self, message: &str) -> anyhow::Result<()> {
        let mut file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.log_file_path)?;

        let timestamp = chrono::Local::now().format("%Y-%m-%d %H:%M:%S");
        writeln!(file, "[{}] {}", timestamp, message)?;

        Ok(())
    }

    /// Print to console.
    fn print_to_console(&self, message: &str) {
        if self.enable_console {
            println!("{}", message);
        }
    }
}

#[async_trait]
impl NotificationPort for FileAndConsoleNotifier {
    async fn notify(&self, event: NotificationEvent) -> anyhow::Result<()> {
        // Format message based on event type
        let message = match &event {
            NotificationEvent::ZoneDeviation { deviation, current_bpm, target_zone } => {
                match deviation {
                    ZoneDeviation::TooLow => {
                        format!("⬇️  TOO LOW: {} BPM (Target: Zone {:?})", current_bpm, target_zone)
                    }
                    ZoneDeviation::TooHigh => {
                        format!("⬆️  TOO HIGH: {} BPM (Target: Zone {:?})", current_bpm, target_zone)
                    }
                    ZoneDeviation::InZone => {
                        format!("✓ IN ZONE: {} BPM (Zone {:?})", current_bpm, target_zone)
                    }
                }
            }
            NotificationEvent::PhaseTransition { from_phase, to_phase, phase_name } => {
                format!("🔄 Phase Change: {} → {} ({})", from_phase, to_phase, phase_name)
            }
            NotificationEvent::BatteryLow { percentage } => {
                format!("🔋 Low Battery: {}%", percentage)
            }
            NotificationEvent::ConnectionLost => {
                "❌ Connection Lost!".to_string()
            }
            NotificationEvent::WorkoutReady { plan_name } => {
                format!("✅ Ready: {}", plan_name)
            }
        };

        // Log to file
        self.log_to_file(&message)?;

        // Print to console
        self.print_to_console(&message);

        Ok(())
    }
}

/// Example of a simple in-memory notification collector.
///
/// This is useful for testing or collecting notifications for later analysis.
pub struct NotificationCollector {
    notifications: std::sync::Arc<tokio::sync::Mutex<Vec<String>>>,
}

impl NotificationCollector {
    pub fn new() -> Self {
        Self {
            notifications: std::sync::Arc::new(tokio::sync::Mutex::new(Vec::new())),
        }
    }

    pub async fn get_notifications(&self) -> Vec<String> {
        self.notifications.lock().await.clone()
    }

    pub async fn clear(&self) {
        self.notifications.lock().await.clear();
    }
}

#[async_trait]
impl NotificationPort for NotificationCollector {
    async fn notify(&self, event: NotificationEvent) -> anyhow::Result<()> {
        let entry = format!("{:?}", event);
        self.notifications.lock().await.push(entry);
        Ok(())
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    println!("Heart Beat - Custom Notification Example");
    println!("=========================================\n");

    // Example 1: File and console notifier
    println!("Example 1: File and Console Notifier\n");

    let log_path = "/tmp/heart_beat_notifications.log";
    let notifier = FileAndConsoleNotifier::new(log_path.to_string());

    // Simulate various notifications
    notifier.notify(NotificationEvent::WorkoutReady {
        plan_name: "Interval Training".to_string(),
    }).await?;

    notifier.notify(NotificationEvent::PhaseTransition {
        from_phase: 0,
        to_phase: 1,
        phase_name: "Warmup".to_string(),
    }).await?;

    notifier.notify(NotificationEvent::ZoneDeviation {
        deviation: ZoneDeviation::TooHigh,
        current_bpm: 165,
        target_zone: Zone::Zone2,
    }).await?;

    notifier.notify(NotificationEvent::ZoneDeviation {
        deviation: ZoneDeviation::InZone,
        current_bpm: 140,
        target_zone: Zone::Zone2,
    }).await?;

    notifier.notify(NotificationEvent::BatteryLow {
        percentage: 15,
    }).await?;

    println!("\nNotifications logged to: {}\n", log_path);

    // Example 2: In-memory collector
    println!("Example 2: In-Memory Notification Collector\n");

    let collector = NotificationCollector::new();

    collector.notify(NotificationEvent::WorkoutReady {
        plan_name: "5K Training".to_string(),
    }).await?;

    collector.notify(NotificationEvent::ZoneDeviation {
        deviation: ZoneDeviation::TooLow,
        current_bpm: 110,
        target_zone: Zone::Zone3,
    }).await?;

    collector.notify(NotificationEvent::ConnectionLost).await?;

    let notifications = collector.get_notifications().await;
    println!("Collected {} notifications:", notifications.len());
    for (i, notification) in notifications.iter().enumerate() {
        println!("  {}. {}", i + 1, notification);
    }

    println!("\nClearing notifications...");
    collector.clear().await;
    println!("Notifications remaining: {}", collector.get_notifications().await.len());

    println!("\n✓ Examples complete!");
    println!("\nKey takeaways:");
    println!("  - Implement NotificationPort trait for custom notification handling");
    println!("  - Use async_trait for async methods");
    println!("  - NotificationEvent enum provides structured event data");
    println!("  - Can combine multiple output targets (file, console, network, etc.)");

    Ok(())
}
