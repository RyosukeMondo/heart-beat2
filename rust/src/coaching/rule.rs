//! Pluggable rules for the coaching engine.

use crate::coaching::cue::{Cue, CueCadence, CueContext, CuePriority, CueSource, DoNotDisturbWindow};
use serde::{Deserialize, Serialize};

/// A pluggable rule that evaluates [`HrSample`] stream and emits [`Cue`]s.
pub trait Rule: Send + Sync {
    /// Evaluate the current sample + context.
    ///
    /// Returns `Some(Cue)` if the rule wants to fire, `None` otherwise.
    fn evaluate(&self, ctx: &CueContext) -> Option<Cue>;

    /// Short name for this rule, used in debug logs.
    fn name(&self) -> &str;
}

// ---------------------------------------------------------------------------
// Target Zone Rule
// ---------------------------------------------------------------------------

/// Fire when HR has been outside the target band for too long.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TargetZoneRule {
    low_bpm: u16,
    high_bpm: u16,
    /// Seconds outside the band before firing.
    min_violation_secs: f64,
}

impl TargetZoneRule {
    pub fn new(low_bpm: u16, high_bpm: u16) -> Self {
        Self {
            low_bpm,
            high_bpm,
            min_violation_secs: 30.0,
        }
    }

    /// Configure how many seconds outside the zone triggers the cue.
    pub fn with_min_violation_secs(mut self, secs: f64) -> Self {
        self.min_violation_secs = secs;
        self
    }
}

impl Rule for TargetZoneRule {
    fn evaluate(&self, ctx: &CueContext) -> Option<Cue> {
        if ctx.is_stale {
            return None;
        }

        let bpm = ctx.sample.bpm as f64;
        let is_below = bpm < self.low_bpm as f64;
        let is_above = bpm > self.high_bpm as f64;

        if !is_below && !is_above {
            return None;
        }

        if ctx.zone_violation_secs < self.min_violation_secs {
            return None;
        }

        let (label, message, priority) = if is_below {
            ("raise_hr", format!("Raise heart rate to {}–{} bpm (you're at {})", self.low_bpm, self.high_bpm, ctx.sample.bpm), CuePriority::Normal)
        } else {
            ("cool_down", format!("Cool down — target {}–{} bpm (you're at {})", self.low_bpm, self.high_bpm, ctx.sample.bpm), CuePriority::Normal)
        };

        Some(Cue::new(CueSource::TargetZone, label, message, priority))
    }

    fn name(&self) -> &str {
        "TargetZone"
    }
}

// ---------------------------------------------------------------------------
// Inactivity Rule
// ---------------------------------------------------------------------------

/// Fire when HR has stayed below a threshold for too long.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InactivityRule {
    /// HR below this triggers inactivity tracking.
    idle_bpm_threshold: u16,
    /// Seconds below threshold before firing.
    idle_duration_secs: f64,
}

impl InactivityRule {
    pub fn new(idle_bpm_threshold: u16, idle_duration_secs: f64) -> Self {
        Self {
            idle_bpm_threshold,
            idle_duration_secs,
        }
    }
}

impl Rule for InactivityRule {
    fn evaluate(&self, ctx: &CueContext) -> Option<Cue> {
        if ctx.is_stale {
            return None;
        }

        if ctx.sample.bpm as f64 >= self.idle_bpm_threshold as f64 {
            return None;
        }

        if ctx.inactivity_secs < self.idle_duration_secs {
            return None;
        }

        let message = format!(
            "Stand up and move — HR has been below {} bpm for {:.0} min",
            self.idle_bpm_threshold,
            ctx.inactivity_secs / 60.0
        );

        Some(Cue::new(CueSource::Inactivity, "stand_up", message, CuePriority::Normal))
    }

    fn name(&self) -> &str {
        "Inactivity"
    }
}

// ---------------------------------------------------------------------------
// Overwork Rule
// ---------------------------------------------------------------------------

/// Fire when HR has been above a ceiling for too long.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OverworkRule {
    upper_bpm: u16,
    /// Seconds above ceiling before firing.
    max_duration_secs: f64,
}

impl OverworkRule {
    pub fn new(upper_bpm: u16, max_duration_secs: f64) -> Self {
        Self {
            upper_bpm,
            max_duration_secs,
        }
    }
}

impl Rule for OverworkRule {
    fn evaluate(&self, ctx: &CueContext) -> Option<Cue> {
        if ctx.is_stale {
            return None;
        }

        if ctx.sample.bpm as f64 <= self.upper_bpm as f64 {
            return None;
        }

        if ctx.overwork_secs < self.max_duration_secs {
            return None;
        }

        let message = format!(
            "Ease off — HR has been above {} bpm for {:.0} min",
            self.upper_bpm,
            ctx.overwork_secs / 60.0
        );

        Some(Cue::new(CueSource::Overwork, "ease_off", message, CuePriority::High))
    }

    fn name(&self) -> &str {
        "Overwork"
    }
}

// ---------------------------------------------------------------------------
// Rule Engine
// ---------------------------------------------------------------------------

/// The coaching rule engine — evaluates a list of rules on each HR sample.
#[derive(Default)]
pub struct RuleEngine {
    rules: Vec<Box<dyn Rule>>,
    cadence: CueCadence,
    dnd_window: DoNotDisturbWindow,
}

impl RuleEngine {
    pub fn new() -> Self {
        Self::default()
    }

    /// Add a rule to the engine.
    pub fn with_rule<R: Rule + 'static>(mut self, rule: R) -> Self {
        self.rules.push(Box::new(rule));
        self
    }

    /// Set the do-not-disturb window.
    pub fn with_dnd_window(mut self, window: DoNotDisturbWindow) -> Self {
        self.dnd_window = window;
        self
    }

    /// Set the cue cadence throttle (minimum seconds between same cue).
    pub fn with_cadence_secs(mut self, secs: i64) -> Self {
        self.cadence = CueCadence::new(secs);
        self
    }

    /// Evaluate all rules against the given context.
    ///
    /// Returns the first non-throttled cue that a rule emits, if any.
    /// DND is respected — audio/notification cues are suppressed during DND hours.
    pub fn evaluate(&mut self, ctx: &CueContext) -> Option<Cue> {
        let now = ctx.sample.timestamp;

        for rule in &self.rules {
            if let Some(cue) = rule.evaluate(ctx) {
                // Respect cadence throttle
                if !self.cadence.can_emit(&cue.label, now) {
                    tracing::debug!(rule = rule.name(), label = %cue.label, "cue throttled by cadence");
                    continue;
                }

                // Respect DND for audio/notification cues
                if ctx.dnd_active && cue.priority < CuePriority::High {
                    tracing::debug!(rule = rule.name(), label = %cue.label, "cue suppressed by DND");
                    continue;
                }

                self.cadence.record(&cue.label, now);
                tracing::info!(rule = rule.name(), cue = %cue.label, message = %cue.message);
                return Some(cue);
            }
        }
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::{DateTime, Utc};
    use crate::domain::HrSample;

    fn make_ctx(bpm: u16, timestamp_secs: i64) -> CueContext {
        CueContext {
            sample: HrSample {
                timestamp: DateTime::from_timestamp(timestamp_secs, 0).unwrap(),
                bpm,
            },
            rolling_avg_bpm: bpm as f64,
            zone_violation_secs: 0.0,
            overwork_secs: 0.0,
            inactivity_secs: 0.0,
            is_stale: false,
            dnd_active: false,
            dnd_window: DoNotDisturbWindow::default(),
        }
    }

    #[test]
    fn test_target_zone_below_fires() {
        let mut engine = RuleEngine::new()
            .with_rule(TargetZoneRule::new(120, 150))
            .with_cadence_secs(300);

        let mut ctx = make_ctx(100, 0);
        ctx.zone_violation_secs = 31.0; // above 30s threshold

        let cue = engine.evaluate(&ctx);
        assert!(cue.is_some());
        assert_eq!(cue.unwrap().label, "raise_hr");
    }

    #[test]
    fn test_target_zone_within_band_no_cue() {
        let mut engine = RuleEngine::new()
            .with_rule(TargetZoneRule::new(120, 150))
            .with_cadence_secs(300);

        let ctx = make_ctx(135, 0);

        assert!(engine.evaluate(&ctx).is_none());
    }

    #[test]
    fn test_inactivity_fires() {
        let mut engine = RuleEngine::new()
            .with_rule(InactivityRule::new(60, 180.0))
            .with_cadence_secs(300);

        let mut ctx = make_ctx(55, 0);
        ctx.inactivity_secs = 200.0; // above 180s threshold

        let cue = engine.evaluate(&ctx);
        assert!(cue.is_some());
        assert_eq!(cue.unwrap().label, "stand_up");
    }

    #[test]
    fn test_overwork_fires() {
        let mut engine = RuleEngine::new()
            .with_rule(OverworkRule::new(160, 480.0))
            .with_cadence_secs(300);

        let mut ctx = make_ctx(170, 0);
        ctx.overwork_secs = 500.0; // above 480s threshold

        let cue = engine.evaluate(&ctx);
        assert!(cue.is_some());
        assert_eq!(cue.unwrap().label, "ease_off");
    }

    #[test]
    fn test_stale_data_no_cue() {
        let mut engine = RuleEngine::new()
            .with_rule(TargetZoneRule::new(120, 150))
            .with_cadence_secs(300);

        let mut ctx = make_ctx(100, 0);
        ctx.zone_violation_secs = 31.0;
        ctx.is_stale = true;

        assert!(engine.evaluate(&ctx).is_none());
    }

    #[test]
    fn test_cadence_throttle() {
        let mut engine = RuleEngine::new()
            .with_rule(TargetZoneRule::new(120, 150))
            .with_cadence_secs(120);

        let mut ctx = make_ctx(100, 0);
        ctx.zone_violation_secs = 31.0;

        let first = engine.evaluate(&ctx);
        assert!(first.is_some());

        // Immediate second call should be throttled
        let second = engine.evaluate(&ctx);
        assert!(second.is_none());
    }

    #[test]
    fn test_dnd_suppresses_low_priority() {
        let mut engine = RuleEngine::new()
            .with_rule(TargetZoneRule::new(120, 150))
            .with_cadence_secs(300)
            .with_dnd_window(DoNotDisturbWindow {
                start_hour: 0,
                end_hour: 23, // covers all hours
                tz_offset_secs: 0,
            });

        let mut ctx = make_ctx(100, 0);
        ctx.zone_violation_secs = 31.0;
        ctx.dnd_active = true;

        // DND is active, Normal-priority cue should be suppressed
        assert!(engine.evaluate(&ctx).is_none());
    }
}