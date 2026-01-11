//! Mock training session example.
//!
//! This example demonstrates how to run a complete training session using the mock
//! adapter. This is useful for:
//! - Testing without physical hardware
//! - Developing new features
//! - Simulating different training scenarios
//!
//! Run with: cargo run --example mock_session

use heart_beat::adapters::mock_adapter::{MockAdapter, MockConfig};
use heart_beat::domain::filters::KalmanFilter;
use heart_beat::domain::heart_rate::{parse_heart_rate, Zone};
use heart_beat::domain::training_plan::{
    calculate_zone, TrainingPhase, TrainingPlan, TransitionCondition,
};
use heart_beat::ports::ble_adapter::BleAdapter;
use std::time::{Duration, Instant};
use tokio::time::timeout;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize logging
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .init();

    println!("Heart Beat - Mock Training Session");
    println!("===================================\n");

    // Define a simple training plan
    let training_plan = TrainingPlan {
        name: "Interval Training".to_string(),
        phases: vec![
            TrainingPhase {
                name: "Warmup".to_string(),
                duration_secs: 120, // 2 minutes
                target_zone: Zone::Zone2,
                transition: TransitionCondition::TimeElapsed,
            },
            TrainingPhase {
                name: "Interval 1".to_string(),
                duration_secs: 60, // 1 minute
                target_zone: Zone::Zone4,
                transition: TransitionCondition::TimeElapsed,
            },
            TrainingPhase {
                name: "Recovery".to_string(),
                duration_secs: 60, // 1 minute
                target_zone: Zone::Zone2,
                transition: TransitionCondition::TimeElapsed,
            },
            TrainingPhase {
                name: "Interval 2".to_string(),
                duration_secs: 60, // 1 minute
                target_zone: Zone::Zone4,
                transition: TransitionCondition::TimeElapsed,
            },
            TrainingPhase {
                name: "Cooldown".to_string(),
                duration_secs: 60, // 1 minute
                target_zone: Zone::Zone1,
                transition: TransitionCondition::TimeElapsed,
            },
        ],
        max_hr: 200,
        created_at: chrono::Utc::now(),
    };

    println!("Training Plan: {}", training_plan.name);
    let total_secs: u32 = training_plan.phases.iter().map(|p| p.duration_secs).sum();
    println!(
        "Total Duration: {} minutes {} seconds",
        total_secs / 60,
        total_secs % 60
    );
    println!("Max HR: {} BPM\n", training_plan.max_hr);

    println!("Phases:");
    for (i, phase) in training_plan.phases.iter().enumerate() {
        println!(
            "  {}. {} - {}s (Zone {:?})",
            i + 1,
            phase.name,
            phase.duration_secs,
            phase.target_zone
        );
    }
    println!();

    // Create mock adapter
    let config = MockConfig {
        baseline_bpm: 120, // Start at exercise heart rate
        noise_range: 8,
        spike_probability: 0.05,
        spike_magnitude: 12,
        update_rate: 2.0, // 2 Hz for faster demo
        battery_level: 90,
    };

    let adapter = MockAdapter::with_config(config);

    // Connect to mock device
    println!("Connecting to mock heart rate monitor...");
    adapter.start_scan().await?;
    let devices = adapter.get_discovered_devices().await;
    adapter.connect(&devices[0].id).await?;
    println!("Connected!\n");

    // Subscribe to HR notifications
    let mut hr_receiver = adapter.subscribe_hr().await?;
    let mut kalman_filter = KalmanFilter::default();

    // Run the training session (abbreviated for demo)
    println!("Starting training session...\n");
    let session_start = Instant::now();
    let demo_duration = Duration::from_secs(10); // Run for 10 seconds as demo

    let mut current_phase_idx = 0;
    let mut samples_collected = 0;
    let mut zone_violations = 0;

    while session_start.elapsed() < demo_duration {
        // Check if we should move to next phase (simplified)
        let elapsed_secs = session_start.elapsed().as_secs();
        if elapsed_secs > 0
            && elapsed_secs.is_multiple_of(3)
            && current_phase_idx < training_plan.phases.len() - 1
        {
            current_phase_idx += 1;
            println!(
                "\n>>> Phase Change: {} <<<\n",
                training_plan.phases[current_phase_idx].name
            );
            tokio::time::sleep(Duration::from_millis(100)).await;
        }

        let current_phase = &training_plan.phases[current_phase_idx];

        // Receive and process heart rate data
        match timeout(Duration::from_secs(1), hr_receiver.recv()).await {
            Ok(Some(packet)) => {
                if let Ok(measurement) = parse_heart_rate(&packet) {
                    let raw_bpm = measurement.bpm;
                    let filtered_bpm = kalman_filter.update(raw_bpm as f64).round() as u16;

                    // Calculate current zone
                    let current_zone = calculate_zone(filtered_bpm, training_plan.max_hr)?;

                    // Check if in target zone
                    let in_zone = current_zone == Some(current_phase.target_zone);
                    if !in_zone {
                        zone_violations += 1;
                    }

                    samples_collected += 1;

                    // Display status
                    let status = if in_zone { "✓" } else { "!" };
                    println!(
                        "[{}s] {} HR: {} BPM | Phase: {} | Target: Zone {:?} | Current: Zone {:?}",
                        elapsed_secs,
                        status,
                        filtered_bpm,
                        current_phase.name,
                        current_phase.target_zone,
                        current_zone.unwrap_or(Zone::Zone1),
                    );
                }
            }
            Ok(None) => break,
            Err(_) => continue,
        }
    }

    // Session summary
    println!("\n=== Session Complete ===");
    println!("Duration: {} seconds", session_start.elapsed().as_secs());
    println!("Samples collected: {}", samples_collected);
    println!("Zone violations: {}", zone_violations);
    println!(
        "Compliance: {:.1}%",
        100.0 * (samples_collected - zone_violations) as f64 / samples_collected as f64
    );

    // Disconnect
    adapter.disconnect().await?;
    println!("\nSession ended. Great work!");

    Ok(())
}
