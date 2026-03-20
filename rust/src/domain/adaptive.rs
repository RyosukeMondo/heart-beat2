//! Adaptive training plan adjustments based on readiness and training load.
//!
//! Pure functions for adjusting training plans according to the athlete's
//! current readiness score and Training Stress Balance (TSB).

use serde::{Deserialize, Serialize};

use crate::domain::heart_rate::Zone;
#[allow(unused_imports)] // TransitionCondition used in tests
use crate::domain::training_plan::{TrainingPhase, TrainingPlan, TransitionCondition};

/// Reason why a training plan was adjusted.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum AdjustmentReason {
    /// Readiness score < 40: significant reduction needed.
    LowReadiness,
    /// Readiness score 40-60: slight intensity reduction.
    ModerateFatigue,
    /// Readiness score > 80: athlete can push harder.
    WellRecovered,
    /// TSB very negative (< -30): override to recovery session.
    OverreachRisk,
    /// Readiness score 60-80: plan is appropriate as-is.
    NoAdjustment,
}

/// A computed adjustment to apply to a training plan.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Adjustment {
    /// Why this adjustment was computed.
    pub reason: AdjustmentReason,
    /// Zone shift to apply (-2 to +1).
    pub zone_delta: i8,
    /// Duration multiplier (0.5 to 1.2).
    pub duration_factor: f64,
    /// Human-readable explanation of the adjustment.
    pub message: String,
}

/// A training plan after adaptive adjustments have been applied.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct AdaptedPlan {
    /// Name of the original plan before adjustment.
    pub original_name: String,
    /// Phases after zone and duration adjustments.
    pub adjusted_phases: Vec<TrainingPhase>,
    /// The adjustment that was applied.
    pub adjustment: Adjustment,
}

/// Compute the appropriate adjustment for the athlete's current state.
///
/// TSB override takes precedence: if TSB < -30, the athlete is at
/// overreach risk regardless of readiness score.
pub fn compute_adjustment(readiness_score: u8, tsb: Option<f64>) -> Adjustment {
    if let Some(tsb_val) = tsb {
        if tsb_val < -30.0 {
            return Adjustment {
                reason: AdjustmentReason::OverreachRisk,
                zone_delta: -2,
                duration_factor: 0.5,
                message: "High fatigue - recovery session recommended".to_string(),
            };
        }
    }

    match readiness_score {
        0..=39 => Adjustment {
            reason: AdjustmentReason::LowReadiness,
            zone_delta: -2,
            duration_factor: 0.6,
            message: "Take it easy today".to_string(),
        },
        40..=60 => Adjustment {
            reason: AdjustmentReason::ModerateFatigue,
            zone_delta: -1,
            duration_factor: 0.8,
            message: "Reduced intensity recommended".to_string(),
        },
        61..=80 => Adjustment {
            reason: AdjustmentReason::NoAdjustment,
            zone_delta: 0,
            duration_factor: 1.0,
            message: "Good to go as planned".to_string(),
        },
        81..=u8::MAX => Adjustment {
            reason: AdjustmentReason::WellRecovered,
            zone_delta: 1,
            duration_factor: 1.1,
            message: "Feeling fresh - push a bit harder".to_string(),
        },
    }
}

/// Shift a zone by the given delta, clamping to Zone1..Zone5.
pub fn shift_zone(zone: Zone, delta: i8) -> Zone {
    let zone_num: i8 = match zone {
        Zone::Zone1 => 1,
        Zone::Zone2 => 2,
        Zone::Zone3 => 3,
        Zone::Zone4 => 4,
        Zone::Zone5 => 5,
    };
    let shifted = (zone_num + delta).clamp(1, 5);
    match shifted {
        1 => Zone::Zone1,
        2 => Zone::Zone2,
        3 => Zone::Zone3,
        4 => Zone::Zone4,
        _ => Zone::Zone5,
    }
}

/// Apply duration factor to a phase duration, enforcing a minimum of 60 seconds.
fn apply_duration_factor(duration_secs: u32, factor: f64) -> u32 {
    let adjusted = (duration_secs as f64 * factor).round() as u32;
    adjusted.max(60)
}

/// Adapt a training plan based on the athlete's readiness and training load.
///
/// Computes an adjustment from the readiness score and optional TSB, then
/// applies zone shifts and duration scaling to every phase.
pub fn adapt_plan(plan: &TrainingPlan, readiness_score: u8, tsb: Option<f64>) -> AdaptedPlan {
    let adjustment = compute_adjustment(readiness_score, tsb);
    let adjusted_phases = plan
        .phases
        .iter()
        .map(|phase| TrainingPhase {
            name: phase.name.clone(),
            target_zone: shift_zone(phase.target_zone, adjustment.zone_delta),
            duration_secs: apply_duration_factor(phase.duration_secs, adjustment.duration_factor),
            transition: phase.transition.clone(),
        })
        .collect();

    AdaptedPlan {
        original_name: plan.name.clone(),
        adjusted_phases,
        adjustment,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;

    fn make_plan(phases: Vec<(Zone, u32)>) -> TrainingPlan {
        TrainingPlan {
            name: "Test Plan".to_string(),
            phases: phases
                .into_iter()
                .enumerate()
                .map(|(i, (zone, dur))| TrainingPhase {
                    name: format!("Phase {}", i + 1),
                    target_zone: zone,
                    duration_secs: dur,
                    transition: TransitionCondition::TimeElapsed,
                })
                .collect(),
            created_at: Utc::now(),
            max_hr: 180,
        }
    }

    #[test]
    fn test_readiness_ranges_and_boundaries() {
        // LowReadiness: 0..=39
        for score in [0u8, 20, 39] {
            let adj = compute_adjustment(score, None);
            assert_eq!(adj.reason, AdjustmentReason::LowReadiness);
            assert_eq!(adj.zone_delta, -2);
            assert!((adj.duration_factor - 0.6).abs() < f64::EPSILON);
            assert_eq!(adj.message, "Take it easy today");
        }
        // ModerateFatigue: 40..=60
        for score in [40u8, 50, 60] {
            let adj = compute_adjustment(score, None);
            assert_eq!(adj.reason, AdjustmentReason::ModerateFatigue);
            assert_eq!(adj.zone_delta, -1);
            assert!((adj.duration_factor - 0.8).abs() < f64::EPSILON);
            assert_eq!(adj.message, "Reduced intensity recommended");
        }
        // NoAdjustment: 61..=80
        for score in [61u8, 70, 80] {
            let adj = compute_adjustment(score, None);
            assert_eq!(adj.reason, AdjustmentReason::NoAdjustment);
            assert_eq!(adj.zone_delta, 0);
            assert!((adj.duration_factor - 1.0).abs() < f64::EPSILON);
            assert_eq!(adj.message, "Good to go as planned");
        }
        // WellRecovered: 81..=255
        for score in [81u8, 100, 255] {
            let adj = compute_adjustment(score, None);
            assert_eq!(adj.reason, AdjustmentReason::WellRecovered);
            assert_eq!(adj.zone_delta, 1);
            assert!((adj.duration_factor - 1.1).abs() < f64::EPSILON);
            assert_eq!(adj.message, "Feeling fresh - push a bit harder");
        }
    }

    #[test]
    fn test_tsb_override_and_boundary() {
        // TSB < -30 overrides even high readiness
        let adj = compute_adjustment(100, Some(-31.0));
        assert_eq!(adj.reason, AdjustmentReason::OverreachRisk);
        assert_eq!(adj.zone_delta, -2);
        assert!((adj.duration_factor - 0.5).abs() < f64::EPSILON);
        assert_eq!(adj.message, "High fatigue - recovery session recommended");

        // More negative TSB also triggers
        let adj = compute_adjustment(90, Some(-50.0));
        assert_eq!(adj.reason, AdjustmentReason::OverreachRisk);

        // Exactly -30 does NOT trigger override
        let adj = compute_adjustment(90, Some(-30.0));
        assert_eq!(adj.reason, AdjustmentReason::WellRecovered);

        // Positive TSB has no effect
        let adj = compute_adjustment(50, Some(10.0));
        assert_eq!(adj.reason, AdjustmentReason::ModerateFatigue);

        // None TSB has no effect
        let adj = compute_adjustment(50, None);
        assert_eq!(adj.reason, AdjustmentReason::ModerateFatigue);
    }

    #[test]
    fn test_shift_zone_basic() {
        assert_eq!(shift_zone(Zone::Zone3, 0), Zone::Zone3);
        assert_eq!(shift_zone(Zone::Zone2, 1), Zone::Zone3);
        assert_eq!(shift_zone(Zone::Zone3, -1), Zone::Zone2);
        assert_eq!(shift_zone(Zone::Zone4, -2), Zone::Zone2);
    }

    #[test]
    fn test_shift_zone_clamping() {
        // Clamp at Zone1
        assert_eq!(shift_zone(Zone::Zone1, -1), Zone::Zone1);
        assert_eq!(shift_zone(Zone::Zone1, -2), Zone::Zone1);
        assert_eq!(shift_zone(Zone::Zone2, -2), Zone::Zone1);
        assert_eq!(shift_zone(Zone::Zone5, -10), Zone::Zone1);
        // Clamp at Zone5
        assert_eq!(shift_zone(Zone::Zone5, 1), Zone::Zone5);
        assert_eq!(shift_zone(Zone::Zone4, 2), Zone::Zone5);
        assert_eq!(shift_zone(Zone::Zone1, 10), Zone::Zone5);
    }

    #[test]
    fn test_shift_zone_identity_all() {
        let zones = [
            Zone::Zone1,
            Zone::Zone2,
            Zone::Zone3,
            Zone::Zone4,
            Zone::Zone5,
        ];
        for zone in zones {
            assert_eq!(shift_zone(zone, 0), zone);
        }
    }

    #[test]
    fn test_duration_factor_cases() {
        assert_eq!(apply_duration_factor(600, 1.0), 600);
        assert_eq!(apply_duration_factor(600, 0.8), 480);
        assert_eq!(apply_duration_factor(600, 1.1), 660);
    }

    #[test]
    fn test_duration_factor_minimum_clamping() {
        // 100 * 0.5 = 50, clamped to 60
        assert_eq!(apply_duration_factor(100, 0.5), 60);
        // 100 * 0.6 = 60, stays 60
        assert_eq!(apply_duration_factor(100, 0.6), 60);
        // Already at minimum
        assert_eq!(apply_duration_factor(60, 1.0), 60);
        // Very short phase
        assert_eq!(apply_duration_factor(30, 0.5), 60);
    }

    #[test]
    fn test_adapt_plan_no_adjustment() {
        let plan = make_plan(vec![(Zone::Zone2, 600), (Zone::Zone4, 1200)]);
        let adapted = adapt_plan(&plan, 70, None);

        assert_eq!(adapted.original_name, "Test Plan");
        assert_eq!(adapted.adjustment.reason, AdjustmentReason::NoAdjustment);
        assert_eq!(adapted.adjusted_phases[0].target_zone, Zone::Zone2);
        assert_eq!(adapted.adjusted_phases[0].duration_secs, 600);
        assert_eq!(adapted.adjusted_phases[1].target_zone, Zone::Zone4);
        assert_eq!(adapted.adjusted_phases[1].duration_secs, 1200);
    }

    #[test]
    fn test_adapt_plan_low_readiness() {
        let plan = make_plan(vec![
            (Zone::Zone2, 600),
            (Zone::Zone4, 1200),
            (Zone::Zone1, 300),
        ]);
        let adapted = adapt_plan(&plan, 30, None);

        assert_eq!(adapted.adjustment.reason, AdjustmentReason::LowReadiness);
        assert_eq!(adapted.adjusted_phases[0].target_zone, Zone::Zone1);
        assert_eq!(adapted.adjusted_phases[1].target_zone, Zone::Zone2);
        assert_eq!(adapted.adjusted_phases[2].target_zone, Zone::Zone1);
        assert_eq!(adapted.adjusted_phases[0].duration_secs, 360);
        assert_eq!(adapted.adjusted_phases[1].duration_secs, 720);
        assert_eq!(adapted.adjusted_phases[2].duration_secs, 180);
    }

    #[test]
    fn test_adapt_plan_well_recovered() {
        let plan = make_plan(vec![(Zone::Zone3, 1200), (Zone::Zone5, 600)]);
        let adapted = adapt_plan(&plan, 90, None);

        assert_eq!(adapted.adjustment.reason, AdjustmentReason::WellRecovered);
        assert_eq!(adapted.adjusted_phases[0].target_zone, Zone::Zone4);
        assert_eq!(adapted.adjusted_phases[1].target_zone, Zone::Zone5);
        assert_eq!(adapted.adjusted_phases[0].duration_secs, 1320);
        assert_eq!(adapted.adjusted_phases[1].duration_secs, 660);
    }

    #[test]
    fn test_adapt_plan_overreach_risk() {
        let plan = make_plan(vec![(Zone::Zone5, 300), (Zone::Zone3, 1200)]);
        let adapted = adapt_plan(&plan, 85, Some(-40.0));

        assert_eq!(adapted.adjustment.reason, AdjustmentReason::OverreachRisk);
        assert_eq!(adapted.adjusted_phases[0].target_zone, Zone::Zone3);
        assert_eq!(adapted.adjusted_phases[1].target_zone, Zone::Zone1);
        assert_eq!(adapted.adjusted_phases[0].duration_secs, 150);
        assert_eq!(adapted.adjusted_phases[1].duration_secs, 600);
    }

    #[test]
    fn test_adapt_plan_moderate_fatigue() {
        let plan = make_plan(vec![(Zone::Zone4, 1200)]);
        let adapted = adapt_plan(&plan, 50, None);

        assert_eq!(adapted.adjustment.reason, AdjustmentReason::ModerateFatigue);
        assert_eq!(adapted.adjusted_phases[0].target_zone, Zone::Zone3);
        assert_eq!(adapted.adjusted_phases[0].duration_secs, 960);
    }

    #[test]
    fn test_adapt_plan_duration_clamped() {
        let plan = make_plan(vec![(Zone::Zone3, 90)]);
        let adapted = adapt_plan(&plan, 20, None);
        // 90 * 0.6 = 54, clamped to 60
        assert_eq!(adapted.adjusted_phases[0].duration_secs, 60);
    }

    #[test]
    fn test_adapt_plan_preserves_names_and_transitions() {
        let plan = TrainingPlan {
            name: "HR Plan".to_string(),
            phases: vec![TrainingPhase {
                name: "Target HR".to_string(),
                target_zone: Zone::Zone4,
                duration_secs: 600,
                transition: TransitionCondition::HeartRateReached {
                    target_bpm: 160,
                    hold_secs: 10,
                },
            }],
            created_at: Utc::now(),
            max_hr: 180,
        };
        let adapted = adapt_plan(&plan, 50, None);

        assert_eq!(adapted.adjusted_phases[0].name, "Target HR");
        assert_eq!(
            adapted.adjusted_phases[0].transition,
            TransitionCondition::HeartRateReached {
                target_bpm: 160,
                hold_secs: 10
            }
        );
    }

    #[test]
    fn test_adapt_plan_empty_phases() {
        let plan = TrainingPlan {
            name: "Empty".to_string(),
            phases: vec![],
            created_at: Utc::now(),
            max_hr: 180,
        };
        let adapted = adapt_plan(&plan, 70, None);

        assert!(adapted.adjusted_phases.is_empty());
        assert_eq!(adapted.adjustment.reason, AdjustmentReason::NoAdjustment);
    }

    #[test]
    fn test_serialization_round_trips() {
        // Adjustment round-trip
        let adj = compute_adjustment(50, None);
        let json = serde_json::to_string(&adj).unwrap();
        let de: Adjustment = serde_json::from_str(&json).unwrap();
        assert_eq!(adj, de);

        // AdaptedPlan round-trip
        let plan = make_plan(vec![(Zone::Zone3, 600)]);
        let adapted = adapt_plan(&plan, 85, None);
        let json = serde_json::to_string(&adapted).unwrap();
        let de: AdaptedPlan = serde_json::from_str(&json).unwrap();
        assert_eq!(adapted, de);

        // All AdjustmentReason variants
        let reasons = [
            AdjustmentReason::LowReadiness,
            AdjustmentReason::ModerateFatigue,
            AdjustmentReason::WellRecovered,
            AdjustmentReason::OverreachRisk,
            AdjustmentReason::NoAdjustment,
        ];
        for reason in reasons {
            let json = serde_json::to_string(&reason).unwrap();
            let de: AdjustmentReason = serde_json::from_str(&json).unwrap();
            assert_eq!(reason, de);
        }
    }
}
