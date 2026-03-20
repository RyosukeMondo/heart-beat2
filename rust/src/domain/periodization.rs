//! Periodized training calendar and training block management.
//!
//! Pure domain module for multi-week training periodization. Provides block-based
//! plan construction, schedule generation, and compliance tracking with no I/O.

use chrono::{Duration, NaiveDate};
use serde::{Deserialize, Serialize};

/// Type of training block within a periodized plan.
///
/// Each variant carries typical volume/intensity characteristics used
/// for schedule generation and progress display.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum BlockType {
    /// High volume, low intensity. Aerobic foundation building.
    Base,
    /// Moderate volume, increasing intensity. Threshold and tempo work.
    Build,
    /// Reduced volume, high intensity. Race-specific sharpening.
    Peak,
    /// Low volume, low intensity. Pre-race freshening.
    Taper,
    /// Minimal load. Active rest between training cycles.
    Recovery,
}

/// A named block of weeks within a periodized plan.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TrainingBlock {
    /// Human-readable name for this block (e.g., "Base Building").
    pub name: String,
    /// Category that determines volume/intensity characteristics.
    pub block_type: BlockType,
    /// Number of weeks this block spans.
    pub weeks: u8,
    /// Target number of training sessions per week.
    pub sessions_per_week: u8,
    /// Guidance text describing the block's purpose.
    pub description: String,
}

/// A single scheduled workout on a specific date.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ScheduledSession {
    /// Calendar date this session is scheduled for.
    pub date: NaiveDate,
    /// Descriptive name of the workout (e.g., "Tempo Run").
    pub workout_name: String,
    /// Block type providing intensity context for this session.
    pub intensity: BlockType,
    /// Whether the athlete has completed this session.
    pub completed: bool,
}

/// A complete periodized training plan spanning multiple blocks.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PeriodizationPlan {
    /// Human-readable plan name.
    pub name: String,
    /// Training goal description (e.g., "Complete a 5K race").
    pub goal: String,
    /// First day of the plan (typically a Monday).
    pub start_date: NaiveDate,
    /// Ordered sequence of training blocks.
    pub blocks: Vec<TrainingBlock>,
}

impl PeriodizationPlan {
    /// Total number of weeks across all blocks.
    pub fn total_weeks(&self) -> u32 {
        self.blocks.iter().map(|b| b.weeks as u32).sum()
    }

    /// Date after the final week of the plan.
    pub fn end_date(&self) -> NaiveDate {
        self.start_date + Duration::weeks(self.total_weeks() as i64)
    }

    /// Find which block contains `today`, returning its index and reference.
    ///
    /// Returns `None` if `today` is before the plan start or after the plan end.
    pub fn current_block(&self, today: NaiveDate) -> Option<(usize, &TrainingBlock)> {
        if today < self.start_date {
            return None;
        }

        let mut block_start = self.start_date;
        for (idx, block) in self.blocks.iter().enumerate() {
            let block_end = block_start + Duration::weeks(block.weeks as i64);
            if today < block_end {
                return Some((idx, block));
            }
            block_start = block_end;
        }
        None
    }
}

/// Create a 12-week 5K race plan.
///
/// Structure: 4 weeks Base, 4 weeks Build, 2 weeks Peak, 2 weeks Taper.
pub fn create_5k_plan(start_date: NaiveDate) -> PeriodizationPlan {
    PeriodizationPlan {
        name: "5K Race Plan".to_string(),
        goal: "Complete a 5K race with strong finish".to_string(),
        start_date,
        blocks: vec![
            TrainingBlock {
                name: "Base Building".to_string(),
                block_type: BlockType::Base,
                weeks: 4,
                sessions_per_week: 4,
                description: "Build aerobic foundation with easy runs".to_string(),
            },
            TrainingBlock {
                name: "Fitness Building".to_string(),
                block_type: BlockType::Build,
                weeks: 4,
                sessions_per_week: 4,
                description: "Introduce tempo and interval sessions".to_string(),
            },
            TrainingBlock {
                name: "Race Sharpening".to_string(),
                block_type: BlockType::Peak,
                weeks: 2,
                sessions_per_week: 4,
                description: "Race-pace workouts and final sharpening".to_string(),
            },
            TrainingBlock {
                name: "Pre-Race Taper".to_string(),
                block_type: BlockType::Taper,
                weeks: 2,
                sessions_per_week: 3,
                description: "Reduce volume to arrive fresh on race day".to_string(),
            },
        ],
    }
}

/// Create a flexible general fitness plan with proportional block distribution.
///
/// Distributes weeks: ~40% Base, ~30% Build, ~20% Peak, ~10% Taper (min 1 each).
pub fn create_general_fitness_plan(start_date: NaiveDate, weeks: u8) -> PeriodizationPlan {
    let (base_w, build_w, peak_w, taper_w) = distribute_weeks(weeks);

    PeriodizationPlan {
        name: "General Fitness Plan".to_string(),
        goal: "Improve overall cardiovascular fitness".to_string(),
        start_date,
        blocks: vec![
            TrainingBlock {
                name: "Aerobic Base".to_string(),
                block_type: BlockType::Base,
                weeks: base_w,
                sessions_per_week: 3,
                description: "Build endurance with steady-state runs".to_string(),
            },
            TrainingBlock {
                name: "Strength & Speed".to_string(),
                block_type: BlockType::Build,
                weeks: build_w,
                sessions_per_week: 4,
                description: "Add tempo and hill work".to_string(),
            },
            TrainingBlock {
                name: "Peak Fitness".to_string(),
                block_type: BlockType::Peak,
                weeks: peak_w,
                sessions_per_week: 3,
                description: "High-intensity maintenance".to_string(),
            },
            TrainingBlock {
                name: "Active Recovery".to_string(),
                block_type: BlockType::Taper,
                weeks: taper_w,
                sessions_per_week: 2,
                description: "Easy movement and recovery".to_string(),
            },
        ],
    }
}

/// Distribute total weeks into (base, build, peak, taper) with min 1 each.
fn distribute_weeks(total: u8) -> (u8, u8, u8, u8) {
    let total = total.max(4); // Need at least 4 weeks (1 per block)
    let base = ((total as f32) * 0.4).round() as u8;
    let build = ((total as f32) * 0.3).round() as u8;
    let peak = ((total as f32) * 0.2).round() as u8;

    let base = base.max(1);
    let build = build.max(1);
    let peak = peak.max(1);
    // Taper gets whatever remains, minimum 1
    let assigned = base + build + peak;
    let taper = if assigned >= total {
        1
    } else {
        total - assigned
    };

    (base, build, peak, taper.max(1))
}

/// Generate a week of scheduled sessions for a given training block.
///
/// Spreads sessions across the week avoiding consecutive hard days where possible.
/// Session names are chosen based on the block type.
pub fn generate_week_schedule(
    block: &TrainingBlock,
    week_start: NaiveDate,
) -> Vec<ScheduledSession> {
    let n = block.sessions_per_week.min(7) as usize;
    let day_offsets = pick_training_days(n);
    let names = session_names_for_block(&block.block_type, n);

    day_offsets
        .into_iter()
        .zip(names)
        .map(|(offset, name)| ScheduledSession {
            date: week_start + Duration::days(offset as i64),
            workout_name: name,
            intensity: block.block_type,
            completed: false,
        })
        .collect()
}

/// Choose day-of-week offsets (0=Mon..6=Sun) that spread sessions and avoid
/// consecutive hard days.
fn pick_training_days(count: usize) -> Vec<u32> {
    match count {
        0 => vec![],
        1 => vec![1],                   // Wednesday
        2 => vec![1, 4],                // Wed, Sat
        3 => vec![0, 2, 5],             // Mon, Wed, Sat
        4 => vec![0, 2, 4, 6],          // Mon, Wed, Fri, Sun
        5 => vec![0, 1, 3, 4, 6],       // Mon, Tue, Thu, Fri, Sun
        6 => vec![0, 1, 2, 3, 4, 6],    // Mon-Fri + Sun
        _ => vec![0, 1, 2, 3, 4, 5, 6], // Every day
    }
}

/// Return descriptive session names based on block type.
fn session_names_for_block(block_type: &BlockType, count: usize) -> Vec<String> {
    let pool: &[&str] = match block_type {
        BlockType::Base => &[
            "Easy Run",
            "Long Run",
            "Recovery Jog",
            "Aerobic Run",
            "Easy Run",
            "Steady Run",
            "Long Run",
        ],
        BlockType::Build => &[
            "Tempo Run",
            "Intervals",
            "Easy Run",
            "Hill Repeats",
            "Tempo Run",
            "Recovery Jog",
            "Long Run",
        ],
        BlockType::Peak => &[
            "Race Pace",
            "Speed Work",
            "Easy Run",
            "Race Pace",
            "Sharpener",
            "Easy Run",
            "Time Trial",
        ],
        BlockType::Taper => &[
            "Easy Shakeout",
            "Light Strides",
            "Rest Jog",
            "Easy Shakeout",
            "Light Strides",
            "Rest Jog",
            "Walk",
        ],
        BlockType::Recovery => &[
            "Walk",
            "Easy Spin",
            "Stretch Session",
            "Walk",
            "Easy Spin",
            "Stretch Session",
            "Rest",
        ],
    };
    pool.iter().take(count).map(|s| s.to_string()).collect()
}

/// Compute the fraction of scheduled sessions that were completed.
///
/// Matches scheduled sessions against `completed_dates`. A session counts as
/// completed if its date appears in the completed list. Returns 0.0..=1.0.
pub fn compute_compliance(scheduled: &[ScheduledSession], completed_dates: &[NaiveDate]) -> f64 {
    if scheduled.is_empty() {
        return 0.0;
    }

    let completed_count = scheduled
        .iter()
        .filter(|s| completed_dates.contains(&s.date))
        .count();

    completed_count as f64 / scheduled.len() as f64
}

#[cfg(test)]
mod tests {
    use super::*;

    fn d(y: i32, m: u32, day: u32) -> NaiveDate {
        NaiveDate::from_ymd_opt(y, m, day).unwrap()
    }

    fn block(bt: BlockType, spw: u8) -> TrainingBlock {
        TrainingBlock {
            name: format!("{bt:?}"),
            block_type: bt,
            weeks: 1,
            sessions_per_week: spw,
            description: String::new(),
        }
    }

    fn sess(date: NaiveDate, bt: BlockType) -> ScheduledSession {
        ScheduledSession {
            date,
            workout_name: "X".into(),
            intensity: bt,
            completed: false,
        }
    }

    #[test]
    fn block_type_copy_eq() {
        let a = BlockType::Base;
        let b = a;
        assert_eq!(a, b);
        assert_ne!(BlockType::Base, BlockType::Peak);
    }

    #[test]
    fn plan_total_weeks_and_end_date() {
        let start = d(2026, 1, 5);
        let plan = create_5k_plan(start);
        assert_eq!(plan.total_weeks(), 12);
        assert_eq!(plan.end_date(), start + Duration::weeks(12));
    }

    #[test]
    fn current_block_boundary_cases() {
        let start = d(2026, 1, 5);
        let plan = create_5k_plan(start);
        // Before plan
        assert!(plan.current_block(d(2026, 1, 4)).is_none());
        // On start date -> first block
        let (idx, blk) = plan.current_block(start).unwrap();
        assert_eq!((idx, blk.block_type), (0, BlockType::Base));
        // Mid-build (week 5)
        let (idx, blk) = plan.current_block(start + Duration::weeks(5)).unwrap();
        assert_eq!((idx, blk.block_type), (1, BlockType::Build));
        // Last day of plan
        let (idx, blk) = plan
            .current_block(plan.end_date() - Duration::days(1))
            .unwrap();
        assert_eq!((idx, blk.block_type), (3, BlockType::Taper));
        // After plan
        assert!(plan.current_block(plan.end_date()).is_none());
    }

    #[test]
    fn create_5k_plan_structure() {
        let plan = create_5k_plan(d(2026, 4, 1));
        assert_eq!(plan.blocks.len(), 4);
        let expected = [
            (BlockType::Base, 4),
            (BlockType::Build, 4),
            (BlockType::Peak, 2),
            (BlockType::Taper, 2),
        ];
        for (blk, (bt, w)) in plan.blocks.iter().zip(expected) {
            assert_eq!((blk.block_type, blk.weeks), (bt, w));
        }
    }

    #[test]
    fn general_fitness_12_and_20_weeks() {
        let plan12 = create_general_fitness_plan(d(2026, 1, 1), 12);
        assert_eq!(plan12.blocks.len(), 4);
        assert_eq!(plan12.blocks.iter().map(|b| b.weeks).sum::<u8>(), 12);

        let plan20 = create_general_fitness_plan(d(2026, 1, 1), 20);
        assert_eq!((plan20.blocks[0].weeks, plan20.blocks[1].weeks), (8, 6));
        assert_eq!((plan20.blocks[2].weeks, plan20.blocks[3].weeks), (4, 2));
    }

    #[test]
    fn general_fitness_clamps_small_input() {
        let plan = create_general_fitness_plan(d(2026, 1, 1), 2);
        assert!(plan.blocks.iter().all(|b| b.weeks >= 1));
        assert!(plan.blocks.iter().map(|b| b.weeks).sum::<u8>() >= 4);
    }

    #[test]
    fn distribute_weeks_invariants() {
        for total in 4..=52u8 {
            let (a, b, c, dd) = distribute_weeks(total);
            assert!(a >= 1 && b >= 1 && c >= 1 && dd >= 1);
            assert!(a + b + c + dd >= total);
        }
    }

    #[test]
    fn schedule_count_and_bounds() {
        let monday = d(2026, 3, 16);
        let sunday = monday + Duration::days(6);
        let sessions = generate_week_schedule(&block(BlockType::Build, 5), monday);
        assert_eq!(sessions.len(), 5);
        for s in &sessions {
            assert!(s.date >= monday && s.date <= sunday);
            assert!(!s.completed);
        }
    }

    #[test]
    fn schedule_no_consecutive_hard_days() {
        let sessions = generate_week_schedule(&block(BlockType::Base, 3), d(2026, 3, 16));
        let mut dates: Vec<_> = sessions.iter().map(|s| s.date).collect();
        dates.sort();
        for w in dates.windows(2) {
            assert!((w[1] - w[0]).num_days() >= 2, "consecutive: {w:?}");
        }
    }

    #[test]
    fn schedule_names_by_block_type() {
        let peak = generate_week_schedule(&block(BlockType::Peak, 3), d(2026, 3, 16));
        assert!(peak.iter().any(|s| s.workout_name == "Race Pace"));
        let taper = generate_week_schedule(&block(BlockType::Taper, 2), d(2026, 3, 16));
        assert_eq!(taper[0].workout_name, "Easy Shakeout");
        assert_eq!(taper[1].workout_name, "Light Strides");
    }

    #[test]
    fn schedule_zero_sessions() {
        assert!(generate_week_schedule(&block(BlockType::Recovery, 0), d(2026, 3, 16)).is_empty());
    }

    #[test]
    fn compliance_scenarios() {
        // Empty
        assert_eq!(compute_compliance(&[], &[]), 0.0);
        // None completed
        assert_eq!(
            compute_compliance(&[sess(d(2026, 3, 16), BlockType::Base)], &[]),
            0.0
        );
        // All completed
        let (d1, d2) = (d(2026, 3, 16), d(2026, 3, 18));
        assert_eq!(
            compute_compliance(
                &[sess(d1, BlockType::Base), sess(d2, BlockType::Base)],
                &[d1, d2]
            ),
            1.0
        );
        // Partial (2 of 4)
        let dates: Vec<_> = (0..4)
            .map(|i| d(2026, 3, 16) + Duration::days(i * 2))
            .collect();
        let sched: Vec<_> = dates.iter().map(|&dt| sess(dt, BlockType::Build)).collect();
        let result = compute_compliance(&sched, &[dates[0], dates[2]]);
        assert!((result - 0.5).abs() < f64::EPSILON);
        // Extra completed dates ignored
        assert_eq!(
            compute_compliance(&[sess(d1, BlockType::Base)], &[d1, d2]),
            1.0
        );
    }

    #[test]
    fn serde_round_trips() {
        // BlockType variants
        for bt in [
            BlockType::Base,
            BlockType::Build,
            BlockType::Peak,
            BlockType::Taper,
            BlockType::Recovery,
        ] {
            let back: BlockType =
                serde_json::from_str(&serde_json::to_string(&bt).unwrap()).unwrap();
            assert_eq!(bt, back);
        }
        // Full plan
        let plan = create_5k_plan(d(2026, 4, 1));
        let back: PeriodizationPlan =
            serde_json::from_str(&serde_json::to_string(&plan).unwrap()).unwrap();
        assert_eq!(plan, back);
        // ScheduledSession
        let s = ScheduledSession {
            date: d(2026, 3, 16),
            workout_name: "Tempo".into(),
            intensity: BlockType::Build,
            completed: true,
        };
        let back: ScheduledSession =
            serde_json::from_str(&serde_json::to_string(&s).unwrap()).unwrap();
        assert_eq!(s, back);
    }
}
