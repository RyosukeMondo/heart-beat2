//! Curated workout template library.
//!
//! Provides pre-built workout templates that can be converted into personalized
//! training plans. All functions are pure with no I/O dependencies.

use chrono::Utc;
use serde::{Deserialize, Serialize};

use crate::domain::heart_rate::Zone;
use crate::domain::training_plan::{TrainingPhase, TrainingPlan, TransitionCondition};

/// Sport category for a workout template.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Sport {
    /// Running workouts.
    Running,
    /// Cycling workouts.
    Cycling,
    /// Swimming workouts.
    Swimming,
    /// Sport-agnostic workouts.
    General,
}

/// Difficulty level for a workout template.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Difficulty {
    /// Suitable for newcomers.
    Beginner,
    /// Requires moderate fitness base.
    Intermediate,
    /// High-intensity, for experienced athletes.
    Advanced,
}

/// A reusable workout template that can be personalized into a TrainingPlan.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct WorkoutTemplate {
    /// Unique identifier (kebab-case slug).
    pub id: String,
    /// Human-readable workout name.
    pub name: String,
    /// Brief description of the workout structure.
    pub description: String,
    /// Target sport category.
    pub sport: Sport,
    /// Difficulty level.
    pub difficulty: Difficulty,
    /// Total estimated duration in minutes.
    pub estimated_duration_mins: u32,
    /// Ordered training phases that compose the workout.
    pub phases: Vec<TrainingPhase>,
}

impl WorkoutTemplate {
    /// Convert this template into a personalized training plan.
    pub fn to_plan(&self, max_hr: u16) -> TrainingPlan {
        TrainingPlan {
            name: self.name.clone(),
            phases: self.phases.clone(),
            created_at: Utc::now(),
            max_hr,
        }
    }
}

/// Build a single time-elapsed phase.
fn phase(name: &str, zone: Zone, duration_secs: u32) -> TrainingPhase {
    TrainingPhase {
        name: name.to_string(),
        target_zone: zone,
        duration_secs,
        transition: TransitionCondition::TimeElapsed,
    }
}

/// Build interval phases: `count` repetitions of (work + recovery).
fn interval_phases(
    count: u32,
    work_zone: Zone,
    work_secs: u32,
    recovery_zone: Zone,
    recovery_secs: u32,
) -> Vec<TrainingPhase> {
    let mut phases = Vec::with_capacity((count * 2) as usize);
    for i in 1..=count {
        phases.push(phase(&format!("Interval {i} - Work"), work_zone, work_secs));
        phases.push(phase(
            &format!("Interval {i} - Recovery"),
            recovery_zone,
            recovery_secs,
        ));
    }
    phases
}

/// Return all curated workout templates.
pub fn get_default_templates() -> Vec<WorkoutTemplate> {
    vec![
        easy_recovery(),
        base_endurance(),
        tempo_run(),
        threshold_intervals(),
        vo2_max_intervals(),
        pyramid_intervals(),
        cycling_sweet_spot(),
        long_endurance(),
    ]
}

/// Filter templates by sport.
pub fn get_templates_by_sport(sport: Sport) -> Vec<WorkoutTemplate> {
    get_default_templates()
        .into_iter()
        .filter(|t| t.sport == sport)
        .collect()
}

/// Filter templates by difficulty.
pub fn get_templates_by_difficulty(difficulty: Difficulty) -> Vec<WorkoutTemplate> {
    get_default_templates()
        .into_iter()
        .filter(|t| t.difficulty == difficulty)
        .collect()
}

fn easy_recovery() -> WorkoutTemplate {
    WorkoutTemplate {
        id: "easy-recovery".into(),
        name: "Easy Recovery".into(),
        description: "Light recovery session entirely in Zone 1.".into(),
        sport: Sport::Running,
        difficulty: Difficulty::Beginner,
        estimated_duration_mins: 30,
        phases: vec![phase("Recovery", Zone::Zone1, 1800)],
    }
}

fn base_endurance() -> WorkoutTemplate {
    WorkoutTemplate {
        id: "base-endurance".into(),
        name: "Base Endurance".into(),
        description: "Warmup, steady Zone 2 effort, cooldown.".into(),
        sport: Sport::Running,
        difficulty: Difficulty::Beginner,
        estimated_duration_mins: 45,
        phases: vec![
            phase("Warmup", Zone::Zone1, 600),
            phase("Steady", Zone::Zone2, 1800),
            phase("Cooldown", Zone::Zone1, 300),
        ],
    }
}

fn tempo_run() -> WorkoutTemplate {
    WorkoutTemplate {
        id: "tempo-run".into(),
        name: "Tempo Run".into(),
        description: "Sustained tempo effort in Zone 3 with warmup and cooldown.".into(),
        sport: Sport::Running,
        difficulty: Difficulty::Intermediate,
        estimated_duration_mins: 40,
        phases: vec![
            phase("Warmup", Zone::Zone2, 600),
            phase("Tempo", Zone::Zone3, 1200),
            phase("Cooldown", Zone::Zone1, 600),
        ],
    }
}

fn threshold_intervals() -> WorkoutTemplate {
    let mut phases = vec![phase("Warmup", Zone::Zone2, 600)];
    phases.extend(interval_phases(4, Zone::Zone4, 240, Zone::Zone2, 180));
    phases.push(phase("Cooldown", Zone::Zone1, 420));

    WorkoutTemplate {
        id: "threshold-intervals".into(),
        name: "Threshold Intervals".into(),
        description: "4x(4min Z4 / 3min Z2) with warmup and cooldown.".into(),
        sport: Sport::Running,
        difficulty: Difficulty::Intermediate,
        estimated_duration_mins: 45,
        phases,
    }
}

fn vo2_max_intervals() -> WorkoutTemplate {
    let mut phases = vec![phase("Warmup", Zone::Zone2, 300)];
    phases.extend(interval_phases(5, Zone::Zone5, 180, Zone::Zone2, 120));
    phases.push(phase("Cooldown", Zone::Zone1, 300));

    WorkoutTemplate {
        id: "vo2-max-intervals".into(),
        name: "VO2 Max Intervals".into(),
        description: "5x(3min Z5 / 2min Z2) for maximal aerobic development.".into(),
        sport: Sport::Running,
        difficulty: Difficulty::Advanced,
        estimated_duration_mins: 35,
        phases,
    }
}

fn pyramid_intervals() -> WorkoutTemplate {
    WorkoutTemplate {
        id: "pyramid-intervals".into(),
        name: "Pyramid Intervals".into(),
        description: "Ascending then descending intensity pyramid.".into(),
        sport: Sport::Running,
        difficulty: Difficulty::Advanced,
        estimated_duration_mins: 50,
        phases: vec![
            phase("Warmup", Zone::Zone2, 900),
            phase("Build Z3", Zone::Zone3, 300),
            phase("Build Z4", Zone::Zone4, 240),
            phase("Peak Z5", Zone::Zone5, 120),
            phase("Descend Z4", Zone::Zone4, 240),
            phase("Descend Z3", Zone::Zone3, 300),
            phase("Cooldown", Zone::Zone1, 900),
        ],
    }
}

fn cycling_sweet_spot() -> WorkoutTemplate {
    WorkoutTemplate {
        id: "cycling-sweet-spot".into(),
        name: "Cycling Sweet Spot".into(),
        description: "Sustained effort at the Z3/Z4 boundary for cycling.".into(),
        sport: Sport::Cycling,
        difficulty: Difficulty::Intermediate,
        estimated_duration_mins: 60,
        phases: vec![
            phase("Warmup", Zone::Zone2, 900),
            phase("Sweet Spot", Zone::Zone4, 1800),
            phase("Cooldown", Zone::Zone1, 900),
        ],
    }
}

fn long_endurance() -> WorkoutTemplate {
    WorkoutTemplate {
        id: "long-endurance".into(),
        name: "Long Endurance".into(),
        description: "Extended Zone 2 session for aerobic base building.".into(),
        sport: Sport::General,
        difficulty: Difficulty::Intermediate,
        estimated_duration_mins: 90,
        phases: vec![
            phase("Warmup", Zone::Zone1, 600),
            phase("Endurance", Zone::Zone2, 4200),
            phase("Cooldown", Zone::Zone1, 600),
        ],
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_templates_count() {
        let templates = get_default_templates();
        assert_eq!(templates.len(), 8);
    }

    #[test]
    fn test_all_templates_have_unique_ids() {
        let templates = get_default_templates();
        let mut ids: Vec<&str> = templates.iter().map(|t| t.id.as_str()).collect();
        ids.sort();
        ids.dedup();
        assert_eq!(ids.len(), 8);
    }

    #[test]
    fn test_all_templates_validate_as_plans() {
        for template in get_default_templates() {
            let plan = template.to_plan(180);
            assert!(
                plan.validate().is_ok(),
                "Template '{}' produced invalid plan: {:?}",
                template.id,
                plan.validate().err()
            );
        }
    }

    #[test]
    fn test_all_templates_duration_matches() {
        for template in get_default_templates() {
            let total_secs: u32 = template.phases.iter().map(|p| p.duration_secs).sum();
            let total_mins = total_secs / 60;
            assert_eq!(
                total_mins, template.estimated_duration_mins,
                "Template '{}': phases sum to {}min but estimated {}min",
                template.id, total_mins, template.estimated_duration_mins,
            );
        }
    }

    #[test]
    fn test_easy_recovery_structure() {
        let t = easy_recovery();
        assert_eq!(t.phases.len(), 1);
        assert_eq!(t.phases[0].target_zone, Zone::Zone1);
        assert_eq!(t.difficulty, Difficulty::Beginner);
    }

    #[test]
    fn test_threshold_intervals_structure() {
        let t = threshold_intervals();
        // warmup + 4*(work+recovery) + cooldown = 10
        assert_eq!(t.phases.len(), 10);
        assert_eq!(t.phases[0].target_zone, Zone::Zone2); // warmup
        assert_eq!(t.phases[1].target_zone, Zone::Zone4); // first work
        assert_eq!(t.phases[2].target_zone, Zone::Zone2); // first recovery
    }

    #[test]
    fn test_vo2_max_intervals_structure() {
        let t = vo2_max_intervals();
        // warmup + 5*(work+recovery) + cooldown = 12
        assert_eq!(t.phases.len(), 12);
        assert_eq!(t.phases[1].target_zone, Zone::Zone5);
    }

    #[test]
    fn test_pyramid_intervals_structure() {
        let t = pyramid_intervals();
        assert_eq!(t.phases.len(), 7);
        let zones: Vec<Zone> = t.phases.iter().map(|p| p.target_zone).collect();
        assert_eq!(
            zones,
            vec![
                Zone::Zone2,
                Zone::Zone3,
                Zone::Zone4,
                Zone::Zone5,
                Zone::Zone4,
                Zone::Zone3,
                Zone::Zone1,
            ]
        );
    }

    #[test]
    fn test_to_plan_sets_max_hr() {
        let template = easy_recovery();
        let plan = template.to_plan(195);
        assert_eq!(plan.max_hr, 195);
        assert_eq!(plan.name, "Easy Recovery");
        assert_eq!(plan.phases.len(), 1);
    }

    #[test]
    fn test_to_plan_preserves_phases() {
        let template = tempo_run();
        let plan = template.to_plan(180);
        assert_eq!(plan.phases, template.phases);
    }

    #[test]
    fn test_filter_by_sport_running() {
        let running = get_templates_by_sport(Sport::Running);
        assert!(running.len() >= 5);
        assert!(running.iter().all(|t| t.sport == Sport::Running));
    }

    #[test]
    fn test_filter_by_sport_cycling() {
        let cycling = get_templates_by_sport(Sport::Cycling);
        assert_eq!(cycling.len(), 1);
        assert_eq!(cycling[0].id, "cycling-sweet-spot");
    }

    #[test]
    fn test_filter_by_sport_swimming_empty() {
        let swimming = get_templates_by_sport(Sport::Swimming);
        assert!(swimming.is_empty());
    }

    #[test]
    fn test_filter_by_sport_general() {
        let general = get_templates_by_sport(Sport::General);
        assert_eq!(general.len(), 1);
        assert_eq!(general[0].id, "long-endurance");
    }

    #[test]
    fn test_filter_by_difficulty_beginner() {
        let beginner = get_templates_by_difficulty(Difficulty::Beginner);
        assert_eq!(beginner.len(), 2);
        assert!(beginner
            .iter()
            .all(|t| t.difficulty == Difficulty::Beginner));
    }

    #[test]
    fn test_filter_by_difficulty_intermediate() {
        let intermediate = get_templates_by_difficulty(Difficulty::Intermediate);
        assert_eq!(intermediate.len(), 4);
        assert!(intermediate
            .iter()
            .all(|t| t.difficulty == Difficulty::Intermediate));
    }

    #[test]
    fn test_filter_by_difficulty_advanced() {
        let advanced = get_templates_by_difficulty(Difficulty::Advanced);
        assert_eq!(advanced.len(), 2);
        assert!(advanced
            .iter()
            .all(|t| t.difficulty == Difficulty::Advanced));
    }

    #[test]
    fn test_all_templates_serialize_roundtrip() {
        for template in get_default_templates() {
            let json = serde_json::to_string(&template).unwrap();
            let deserialized: WorkoutTemplate = serde_json::from_str(&json).unwrap();
            assert_eq!(template, deserialized);
        }
    }

    #[test]
    fn test_cycling_sweet_spot_is_cycling() {
        let t = cycling_sweet_spot();
        assert_eq!(t.sport, Sport::Cycling);
        assert_eq!(t.estimated_duration_mins, 60);
    }

    #[test]
    fn test_long_endurance_duration() {
        let t = long_endurance();
        assert_eq!(t.estimated_duration_mins, 90);
        let total_secs: u32 = t.phases.iter().map(|p| p.duration_secs).sum();
        assert_eq!(total_secs, 5400);
    }
}
