//! Training plan data structures and zone calculation logic.
//!
//! This module provides core types for defining structured training plans with
//! multiple phases, automatic zone transitions, and validation. All types are
//! pure data structures with no I/O dependencies.

use crate::domain::heart_rate::Zone;
use anyhow::{anyhow, bail, Result};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// A complete training plan with multiple phases.
///
/// Represents a structured workout with automatic zone transitions,
/// personalized to the user's maximum heart rate.
///
/// # Examples
///
/// ```
/// use heart_beat::domain::training_plan::{TrainingPlan, TrainingPhase, TransitionCondition};
/// use heart_beat::domain::heart_rate::Zone;
/// use chrono::Utc;
///
/// let plan = TrainingPlan {
///     name: "Easy Run".to_string(),
///     phases: vec![
///         TrainingPhase {
///             name: "Warmup".to_string(),
///             target_zone: Zone::Zone2,
///             duration_secs: 600,
///             transition: TransitionCondition::TimeElapsed,
///         },
///     ],
///     created_at: Utc::now(),
///     max_hr: 180,
/// };
/// ```
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TrainingPlan {
    /// Human-readable name for the training plan.
    pub name: String,

    /// Ordered sequence of training phases.
    pub phases: Vec<TrainingPhase>,

    /// Timestamp when the plan was created.
    pub created_at: DateTime<Utc>,

    /// User's maximum heart rate in BPM.
    ///
    /// Used for zone calculation. Typically 220 - age, but should be
    /// personalized through testing for accuracy.
    pub max_hr: u16,
}

/// A single phase within a training plan.
///
/// Each phase has a target heart rate zone, expected duration, and
/// transition condition that determines when to move to the next phase.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TrainingPhase {
    /// Human-readable name for this phase (e.g., "Warmup", "Work", "Recovery").
    pub name: String,

    /// Target heart rate zone for this phase.
    pub target_zone: Zone,

    /// Expected duration in seconds.
    ///
    /// Used as the transition criterion for TimeElapsed, or as guidance
    /// for HeartRateReached transitions.
    pub duration_secs: u32,

    /// Condition that triggers transition to the next phase.
    pub transition: TransitionCondition,
}

/// Condition that determines when to transition to the next phase.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum TransitionCondition {
    /// Transition after the phase duration has elapsed.
    TimeElapsed,

    /// Transition when heart rate reaches and holds at target.
    ///
    /// The user must maintain the target BPM for the specified number of
    /// consecutive seconds before transitioning.
    HeartRateReached {
        /// Target heart rate in BPM that must be reached.
        target_bpm: u16,

        /// Number of consecutive seconds the target must be held.
        hold_secs: u32,
    },
}

/// Calculate the training zone for a given heart rate.
///
/// Uses the percentage of maximum heart rate to determine the zone:
/// - Zone 1: 50-60% (Recovery)
/// - Zone 2: 60-70% (Endurance/Fat Burning)
/// - Zone 3: 70-80% (Aerobic/Tempo)
/// - Zone 4: 80-90% (Threshold)
/// - Zone 5: 90-100% (VO2 Max/Maximum)
///
/// # Arguments
///
/// * `bpm` - Current heart rate in beats per minute
/// * `max_hr` - User's maximum heart rate
///
/// # Returns
///
/// * `Ok(Some(Zone))` - The appropriate training zone
/// * `Ok(None)` - BPM is below 50% of max_hr (below training threshold)
/// * `Err` - max_hr is invalid (<100 or >220)
///
/// # Examples
///
/// ```
/// use heart_beat::domain::training_plan::calculate_zone;
/// use heart_beat::domain::heart_rate::Zone;
///
/// // 126 BPM at 180 max_hr = 70% = Zone 3
/// assert_eq!(calculate_zone(126, 180).unwrap(), Some(Zone::Zone3));
///
/// // 90 BPM at 200 max_hr = 45% = Below training threshold
/// assert_eq!(calculate_zone(90, 200).unwrap(), None);
///
/// // Invalid max_hr
/// assert!(calculate_zone(120, 50).is_err());
/// ```
pub fn calculate_zone(bpm: u16, max_hr: u16) -> Result<Option<Zone>> {
    if max_hr < 100 || max_hr > 220 {
        return Err(anyhow!("Invalid max_hr: {} (must be 100-220)", max_hr));
    }

    let pct = (bpm as f32 / max_hr as f32) * 100.0;

    match pct {
        p if p < 50.0 => Ok(None),
        p if p < 60.0 => Ok(Some(Zone::Zone1)),
        p if p < 70.0 => Ok(Some(Zone::Zone2)),
        p if p < 80.0 => Ok(Some(Zone::Zone3)),
        p if p < 90.0 => Ok(Some(Zone::Zone4)),
        _ => Ok(Some(Zone::Zone5)),
    }
}

impl TrainingPlan {
    /// Validate that the training plan is well-formed.
    ///
    /// Checks:
    /// - At least one phase exists
    /// - All phase durations are positive
    /// - Total duration is less than 4 hours (14400 seconds)
    /// - HeartRateReached targets are physiologically valid (30-220 BPM)
    ///
    /// # Returns
    ///
    /// * `Ok(())` - Plan is valid
    /// * `Err` - Plan is invalid with descriptive error message
    ///
    /// # Examples
    ///
    /// ```
    /// use heart_beat::domain::training_plan::{TrainingPlan, TrainingPhase, TransitionCondition};
    /// use heart_beat::domain::heart_rate::Zone;
    /// use chrono::Utc;
    ///
    /// let mut plan = TrainingPlan {
    ///     name: "Test".to_string(),
    ///     phases: vec![],
    ///     created_at: Utc::now(),
    ///     max_hr: 180,
    /// };
    ///
    /// // Empty plan should fail validation
    /// assert!(plan.validate().is_err());
    ///
    /// // Add a valid phase
    /// plan.phases.push(TrainingPhase {
    ///     name: "Work".to_string(),
    ///     target_zone: Zone::Zone3,
    ///     duration_secs: 1200,
    ///     transition: TransitionCondition::TimeElapsed,
    /// });
    ///
    /// // Now should be valid
    /// assert!(plan.validate().is_ok());
    /// ```
    pub fn validate(&self) -> Result<()> {
        if self.phases.is_empty() {
            bail!("Plan must have at least 1 phase");
        }

        let total_secs: u32 = self.phases.iter().map(|p| p.duration_secs).sum();
        if total_secs > 14400 {
            bail!("Plan exceeds 4 hours (total: {}s)", total_secs);
        }

        for (idx, phase) in self.phases.iter().enumerate() {
            if phase.duration_secs == 0 {
                bail!("Phase {} '{}' has zero duration", idx, phase.name);
            }

            // Validate HeartRateReached targets
            if let TransitionCondition::HeartRateReached { target_bpm, .. } = phase.transition {
                if target_bpm < 30 || target_bpm > 220 {
                    bail!(
                        "Phase {} '{}' has invalid target_bpm: {} (must be 30-220)",
                        idx,
                        phase.name,
                        target_bpm
                    );
                }
            }
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // Zone calculation tests

    #[test]
    fn test_calculate_zone_all_zones() {
        let max_hr = 200;

        // Zone 1: 50-60% = 100-120 BPM
        assert_eq!(calculate_zone(100, max_hr).unwrap(), Some(Zone::Zone1));
        assert_eq!(calculate_zone(119, max_hr).unwrap(), Some(Zone::Zone1));

        // Zone 2: 60-70% = 120-140 BPM
        assert_eq!(calculate_zone(120, max_hr).unwrap(), Some(Zone::Zone2));
        assert_eq!(calculate_zone(139, max_hr).unwrap(), Some(Zone::Zone2));

        // Zone 3: 70-80% = 140-160 BPM
        assert_eq!(calculate_zone(140, max_hr).unwrap(), Some(Zone::Zone3));
        assert_eq!(calculate_zone(159, max_hr).unwrap(), Some(Zone::Zone3));

        // Zone 4: 80-90% = 160-180 BPM
        assert_eq!(calculate_zone(160, max_hr).unwrap(), Some(Zone::Zone4));
        assert_eq!(calculate_zone(179, max_hr).unwrap(), Some(Zone::Zone4));

        // Zone 5: 90-100% = 180-200 BPM
        assert_eq!(calculate_zone(180, max_hr).unwrap(), Some(Zone::Zone5));
        assert_eq!(calculate_zone(200, max_hr).unwrap(), Some(Zone::Zone5));
    }

    #[test]
    fn test_calculate_zone_below_threshold() {
        // Below 50% should return None
        assert_eq!(calculate_zone(90, 200).unwrap(), None);
        assert_eq!(calculate_zone(99, 200).unwrap(), None);
    }

    #[test]
    fn test_calculate_zone_edge_cases() {
        // Test boundary conditions
        let max_hr = 180;

        // Exactly 50% (90 BPM) should be Zone 1
        assert_eq!(calculate_zone(90, max_hr).unwrap(), Some(Zone::Zone1));

        // Just below 50% should be None
        assert_eq!(calculate_zone(89, max_hr).unwrap(), None);

        // Exactly 100% should be Zone 5
        assert_eq!(calculate_zone(180, max_hr).unwrap(), Some(Zone::Zone5));

        // Above 100% should still be Zone 5
        assert_eq!(calculate_zone(190, max_hr).unwrap(), Some(Zone::Zone5));
    }

    #[test]
    fn test_calculate_zone_invalid_max_hr() {
        // max_hr too low
        assert!(calculate_zone(120, 99).is_err());
        assert!(calculate_zone(120, 50).is_err());

        // max_hr too high
        assert!(calculate_zone(120, 221).is_err());
        assert!(calculate_zone(120, 250).is_err());
    }

    #[test]
    fn test_calculate_zone_valid_max_hr_range() {
        // Boundaries should work
        assert!(calculate_zone(50, 100).is_ok());
        assert!(calculate_zone(110, 220).is_ok());
    }

    // Validation tests

    #[test]
    fn test_validate_empty_plan() {
        let plan = TrainingPlan {
            name: "Empty".to_string(),
            phases: vec![],
            created_at: Utc::now(),
            max_hr: 180,
        };

        let result = plan.validate();
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("at least 1 phase"));
    }

    #[test]
    fn test_validate_zero_duration_phase() {
        let plan = TrainingPlan {
            name: "Invalid".to_string(),
            phases: vec![TrainingPhase {
                name: "Bad Phase".to_string(),
                target_zone: Zone::Zone2,
                duration_secs: 0,
                transition: TransitionCondition::TimeElapsed,
            }],
            created_at: Utc::now(),
            max_hr: 180,
        };

        let result = plan.validate();
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("zero duration"));
    }

    #[test]
    fn test_validate_exceeds_max_duration() {
        let plan = TrainingPlan {
            name: "Too Long".to_string(),
            phases: vec![TrainingPhase {
                name: "Marathon".to_string(),
                target_zone: Zone::Zone2,
                duration_secs: 14401, // 4 hours + 1 second
                transition: TransitionCondition::TimeElapsed,
            }],
            created_at: Utc::now(),
            max_hr: 180,
        };

        let result = plan.validate();
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("exceeds 4 hours"));
    }

    #[test]
    fn test_validate_invalid_heart_rate_target() {
        let plan = TrainingPlan {
            name: "Invalid HR".to_string(),
            phases: vec![TrainingPhase {
                name: "Bad Target".to_string(),
                target_zone: Zone::Zone5,
                duration_secs: 300,
                transition: TransitionCondition::HeartRateReached {
                    target_bpm: 250, // Too high
                    hold_secs: 10,
                },
            }],
            created_at: Utc::now(),
            max_hr: 180,
        };

        let result = plan.validate();
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("invalid target_bpm"));
    }

    #[test]
    fn test_validate_valid_plan() {
        let plan = TrainingPlan {
            name: "Valid Plan".to_string(),
            phases: vec![
                TrainingPhase {
                    name: "Warmup".to_string(),
                    target_zone: Zone::Zone2,
                    duration_secs: 600,
                    transition: TransitionCondition::TimeElapsed,
                },
                TrainingPhase {
                    name: "Work".to_string(),
                    target_zone: Zone::Zone4,
                    duration_secs: 1200,
                    transition: TransitionCondition::HeartRateReached {
                        target_bpm: 160,
                        hold_secs: 10,
                    },
                },
            ],
            created_at: Utc::now(),
            max_hr: 180,
        };

        assert!(plan.validate().is_ok());
    }

    #[test]
    fn test_validate_exactly_4_hours() {
        let plan = TrainingPlan {
            name: "Max Duration".to_string(),
            phases: vec![TrainingPhase {
                name: "Long Run".to_string(),
                target_zone: Zone::Zone2,
                duration_secs: 14400, // Exactly 4 hours
                transition: TransitionCondition::TimeElapsed,
            }],
            created_at: Utc::now(),
            max_hr: 180,
        };

        assert!(plan.validate().is_ok());
    }

    // Example training plan fixtures

    /// Tempo run: warmup, sustained tempo effort, cooldown.
    ///
    /// Total duration: 40 minutes
    /// - 10min Zone2 warmup
    /// - 20min Zone3 tempo work
    /// - 10min Zone1 cooldown
    pub fn tempo_run() -> TrainingPlan {
        TrainingPlan {
            name: "5K Tempo Run".to_string(),
            phases: vec![
                TrainingPhase {
                    name: "Warmup".to_string(),
                    target_zone: Zone::Zone2,
                    duration_secs: 600,
                    transition: TransitionCondition::TimeElapsed,
                },
                TrainingPhase {
                    name: "Tempo".to_string(),
                    target_zone: Zone::Zone3,
                    duration_secs: 1200,
                    transition: TransitionCondition::TimeElapsed,
                },
                TrainingPhase {
                    name: "Cooldown".to_string(),
                    target_zone: Zone::Zone1,
                    duration_secs: 600,
                    transition: TransitionCondition::TimeElapsed,
                },
            ],
            created_at: Utc::now(),
            max_hr: 180,
        }
    }

    /// Base endurance run: steady aerobic effort.
    ///
    /// Total duration: 45 minutes
    /// - 45min Zone2 steady state
    pub fn base_endurance() -> TrainingPlan {
        TrainingPlan {
            name: "Base Endurance".to_string(),
            phases: vec![TrainingPhase {
                name: "Steady State".to_string(),
                target_zone: Zone::Zone2,
                duration_secs: 2700,
                transition: TransitionCondition::TimeElapsed,
            }],
            created_at: Utc::now(),
            max_hr: 180,
        }
    }

    /// VO2 max intervals: warmup, 5x (3min hard, 2min recovery), cooldown.
    ///
    /// Total duration: 35 minutes
    /// - 5min Zone2 warmup
    /// - 5x [3min Zone5 work, 2min Zone2 recovery]
    /// - 5min Zone1 cooldown
    pub fn vo2_intervals() -> TrainingPlan {
        let mut phases = vec![TrainingPhase {
            name: "Warmup".to_string(),
            target_zone: Zone::Zone2,
            duration_secs: 300,
            transition: TransitionCondition::TimeElapsed,
        }];

        // 5 intervals: 3min work + 2min recovery
        for i in 1..=5 {
            phases.push(TrainingPhase {
                name: format!("Interval {} - Work", i),
                target_zone: Zone::Zone5,
                duration_secs: 180,
                transition: TransitionCondition::TimeElapsed,
            });
            phases.push(TrainingPhase {
                name: format!("Interval {} - Recovery", i),
                target_zone: Zone::Zone2,
                duration_secs: 120,
                transition: TransitionCondition::TimeElapsed,
            });
        }

        phases.push(TrainingPhase {
            name: "Cooldown".to_string(),
            target_zone: Zone::Zone1,
            duration_secs: 300,
            transition: TransitionCondition::TimeElapsed,
        });

        TrainingPlan {
            name: "VO2 Max Intervals".to_string(),
            phases,
            created_at: Utc::now(),
            max_hr: 180,
        }
    }

    #[test]
    fn test_tempo_run_fixture() {
        let plan = tempo_run();
        assert!(plan.validate().is_ok());
        assert_eq!(plan.phases.len(), 3);
        assert_eq!(plan.name, "5K Tempo Run");

        // Verify total duration
        let total: u32 = plan.phases.iter().map(|p| p.duration_secs).sum();
        assert_eq!(total, 2400); // 40 minutes
    }

    #[test]
    fn test_base_endurance_fixture() {
        let plan = base_endurance();
        assert!(plan.validate().is_ok());
        assert_eq!(plan.phases.len(), 1);
        assert_eq!(plan.name, "Base Endurance");
        assert_eq!(plan.phases[0].duration_secs, 2700); // 45 minutes
    }

    #[test]
    fn test_vo2_intervals_fixture() {
        let plan = vo2_intervals();
        assert!(plan.validate().is_ok());
        assert_eq!(plan.phases.len(), 12); // warmup + 5*(work+recovery) + cooldown

        // Verify total duration: 5min + 5*(3min+2min) + 5min = 35min
        let total: u32 = plan.phases.iter().map(|p| p.duration_secs).sum();
        assert_eq!(total, 2100); // 35 minutes
    }

    #[test]
    fn test_example_plans_serialize() {
        // All example plans should serialize/deserialize correctly
        let plans = vec![tempo_run(), base_endurance(), vo2_intervals()];

        for plan in plans {
            let json = serde_json::to_string(&plan).unwrap();
            let deserialized: TrainingPlan = serde_json::from_str(&json).unwrap();
            assert_eq!(plan.name, deserialized.name);
            assert_eq!(plan.phases.len(), deserialized.phases.len());
        }
    }
}
