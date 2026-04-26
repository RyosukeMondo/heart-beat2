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
// Low Heart Rate Rule (Sustained)
// ---------------------------------------------------------------------------

use crate::hr_store::HrStore;

/// Rule that fires when the rolling average HR has been below a threshold
/// for longer than the sustained window, with hysteresis debounce.
///
/// Fires once when avg drops below `threshold_bpm`. Does not fire again until
/// avg has risen above `threshold_bpm + hysteresis_bpm` for at least
/// `hysteresis_recovery_secs`, and then drops below again.
#[derive(Debug)]
pub struct LowHrRule {
    /// HR below this threshold triggers the rule.
    threshold_bpm: u16,
    /// Window in seconds over which to compute the rolling average.
    sustained_secs: u64,
    /// Must exceed threshold by this many BPM before recovery can trigger.
    hysteresis_bpm: u16,
    /// How long avg must stay above threshold + hysteresis before resetting firing state.
    hysteresis_recovery_secs: u64,
    /// Do-not-disturb window (quiet hours).
    quiet_hours: DoNotDisturbWindow,
    /// Access to the HR sample store for rolling_avg queries.
    hr_store: HrStore,
    /// Whether we are currently in the 'firing' (notified) state.
    is_firing: bool,
    /// Timestamp (seconds) when the average first rose above threshold + hysteresis.
    /// Used to track hysteresis recovery window.
    hysteresis_recovery_start: Option<i64>,
}

impl LowHrRule {
    /// Create a new LowHrRule.
    ///
    /// - `threshold_bpm`: low HR alert threshold (e.g. 70)
    /// - `sustained_secs`: rolling average window in seconds (e.g. 600 for 10 min)
    pub fn new(threshold_bpm: u16, sustained_secs: u64) -> Self {
        Self {
            threshold_bpm,
            sustained_secs,
            hysteresis_bpm: 5,
            hysteresis_recovery_secs: 300,
            quiet_hours: DoNotDisturbWindow::default(),
            hr_store: HrStore::default(),
            is_firing: false,
            hysteresis_recovery_start: None,
        }
    }

    /// Set the hysteresis buffer (BPM above threshold to trigger recovery tracking).
    pub fn with_hysteresis_bpm(mut self, bpm: u16) -> Self {
        self.hysteresis_bpm = bpm;
        self
    }

    /// Set the hysteresis recovery duration in seconds.
    pub fn with_hysteresis_recovery_secs(mut self, secs: u64) -> Self {
        self.hysteresis_recovery_secs = secs;
        self
    }

    /// Set the quiet-hours / do-not-disturb window.
    pub fn with_quiet_hours(mut self, window: DoNotDisturbWindow) -> Self {
        self.quiet_hours = window;
        self
    }

    /// Set the HR store (needed for rolling_avg queries).
    pub fn with_hr_store(mut self, store: HrStore) -> Self {
        self.hr_store = store;
        self
    }

    /// Update the threshold, sustained window, and quiet hours at runtime.
    ///
    /// Called from the API layer when the user changes health settings in the UI.
    pub fn update_config(&mut self, threshold_bpm: u16, sustained_secs: u64, quiet_hours: DoNotDisturbWindow) {
        self.threshold_bpm = threshold_bpm;
        self.sustained_secs = sustained_secs;
        self.quiet_hours = quiet_hours;
    }

    fn local_hour(&self, ctx: &CueContext) -> u8 {
        use chrono::Timelike;
        let local = ctx.sample.timestamp.with_timezone(&chrono::Local);
        local.hour() as u8
    }
}

impl Rule for LowHrRule {
    fn evaluate(&self, ctx: &CueContext) -> Option<Cue> {
        if ctx.is_stale {
            return None;
        }

        let now_secs = ctx.sample.timestamp.timestamp();

        // Compute rolling average over the sustained window.
        let avg_bpm = match tokio::runtime::Handle::current().block_on(self.hr_store.rolling_avg(self.sustained_secs)) {
            Ok(Some(avg)) => avg,
            Ok(None) | Err(_) => {
                // No samples available — nothing to evaluate.
                return None;
            }
        };

        let threshold = self.threshold_bpm as f32;
        let recovery_threshold = (self.threshold_bpm + self.hysteresis_bpm) as f32;

        // Check quiet-hours suppression using local time from the sample.
        let local_hour = self.local_hour(ctx);
        if self.quiet_hours.is_active(local_hour) {
            return None;
        }

        // Hysteresis state machine.
        if self.is_firing {
            // Already fired — stay in firing until average recovers above threshold + hysteresis
            // for at least hysteresis_recovery_secs.
            if avg_bpm > recovery_threshold {
                match self.hysteresis_recovery_start {
                    Some(start) => {
                        let elapsed = now_secs - start;
                        if elapsed >= self.hysteresis_recovery_secs as i64 {
                            // Recovered long enough — reset firing state.
                            // NOTE: we do NOT fire again here; we just clear the firing flag
                            // so the next below-threshold dip can fire.
                            tracing::debug!(
                                rule = self.name(),
                                avg_bpm,
                                "hysteresis recovery complete, resetting firing state"
                            );
                            // We can't mutate self here (Rule::evaluate takes &self), so
                            // we reset via a separate mechanism — see evaluate_mut.
                            return None;
                        }
                    }
                    None => {
                        // Just started recovering — record the start time.
                        // Again, this requires mutable state, handled by evaluate_mut.
                    }
                }
            }
            return None;
        }

        // Not currently firing.
        if avg_bpm < threshold {
            // Below threshold — emit the cue.
            let window_min = self.sustained_secs as f32 / 60.0;
            let message = format!(
                "Heart rate low — average {} bpm over the last {:.0} min",
                avg_bpm.round() as u16,
                window_min
            );
            return Some(Cue::new(
                CueSource::SustainedLowHr,
                "sustained_low_hr",
                message,
                CuePriority::High,
            ));
        }

        None
    }

    fn name(&self) -> &str {
        "LowHr"
    }
}

/// Mutable evaluation entry-point for rules that need to update internal state.
///
/// The standard `Rule::evaluate` takes `&self` (immutable). For rules like
/// LowHrRule that need to track firing/recovery state, we expose this method
/// which the caller (RuleEngine or api layer) must invoke instead.
impl LowHrRule {
    /// Evaluate with mutable state (hysteresis tracking).
    ///
    /// Returns `Some(Cue)` to fire, `None` otherwise.
    pub fn evaluate_mut(&mut self, ctx: &CueContext) -> Option<Cue> {
        if ctx.is_stale {
            return None;
        }

        let now_secs = ctx.sample.timestamp.timestamp();

        // Compute rolling average. block_in_place runs the async operation on
        // a Tokio worker thread without blocking the caller. This works in
        // multi-threaded runtimes (not single-threaded).
        let avg_bpm = tokio::task::block_in_place(|| {
            tokio::runtime::Handle::current().block_on(
                self.hr_store.rolling_avg(self.sustained_secs),
            )
        });
        let avg_bpm = match avg_bpm {
            Ok(Some(avg)) => avg,
            Ok(None) | Err(_) => {
                return None;
            }
        };

        let threshold = self.threshold_bpm as f32;
        let recovery_threshold = (self.threshold_bpm + self.hysteresis_bpm) as f32;

        let local_hour = self.local_hour(ctx);
        if self.quiet_hours.is_active(local_hour) {
            // Quiet hours — reset any in-progress hysteresis state.
            self.hysteresis_recovery_start = None;
            if self.is_firing {
                self.is_firing = false;
            }
            return None;
        }

        if self.is_firing {
            // In firing state — check if we've recovered.
            if avg_bpm > recovery_threshold {
                match self.hysteresis_recovery_start {
                    Some(start) => {
                        let elapsed = now_secs - start;
                        if elapsed >= self.hysteresis_recovery_secs as i64 {
                            tracing::debug!(
                                rule = self.name(),
                                avg_bpm,
                                threshold = threshold,
                                "hysteresis recovery complete, resetting firing state"
                            );
                            self.is_firing = false;
                            self.hysteresis_recovery_start = None;
                        }
                    }
                    None => {
                        // Start tracking recovery.
                        self.hysteresis_recovery_start = Some(now_secs);
                    }
                }
            } else {
                // Average dipped again below recovery threshold — reset recovery timer.
                self.hysteresis_recovery_start = None;
            }
            return None;
        }

        // Not firing — check if we should fire.
        if avg_bpm < threshold {
            tracing::info!(
                rule = self.name(),
                avg_bpm,
                threshold = threshold,
                window_secs = self.sustained_secs,
                "sustained_low_hr cue fired"
            );
            self.is_firing = true;
            self.hysteresis_recovery_start = None;

            let window_min = self.sustained_secs as f32 / 60.0;
            let message = format!(
                "Heart rate low — average {} bpm over the last {:.0} min",
                avg_bpm.round() as u16,
                window_min
            );
            return Some(Cue::new(
                CueSource::SustainedLowHr,
                "sustained_low_hr",
                message,
                CuePriority::High,
            ));
        }

        None
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
    use chrono::DateTime;
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

    // ─── LowHrRule tests ────────────────────────────────────────────────────────

    use crate::hr_store::HrStore;
    use tempfile::TempDir;

    /// Helper: creates a LowHrRule connected to a temporary HrStore.
    /// The returned tuple is (rule, temp_dir) — temp_dir must be kept alive
    /// for the lifetime of the rule (handled automatically when used in a
    /// single test function).
    async fn make_low_hr_rule(threshold_bpm: u16, sustained_secs: u64) -> (LowHrRule, TempDir) {
        let dir = TempDir::new().unwrap();
        let store = HrStore::new_owned(dir.path().to_path_buf()).await.unwrap();
        let rule = LowHrRule::new(threshold_bpm, sustained_secs)
            .with_hysteresis_bpm(5)
            .with_hysteresis_recovery_secs(300)
            .with_hr_store(store);
        (rule, dir)
    }

    /// Helper: makes a CueContext at the given local hour (no DND active by default).
    fn make_ctx_at_hour(bpm: u16, timestamp_secs: i64, hour: u8) -> CueContext {
        use chrono::{DateTime, NaiveDate, Timelike, Utc};
        // Use a UTC reference date that starts at an even hour.
        let base_naive = NaiveDate::from_ymd_opt(2020, 6, 1).unwrap().and_hms_opt(0, 0, 0).unwrap();
        let base = DateTime::<Utc>::from_naive_utc_and_offset(base_naive, Utc);
        // Add the timestamp offset (in seconds).
        let ts = base + chrono::Duration::seconds(timestamp_secs);
        // Figure out what UTC hour we'd need to reach the target local hour.
        // Since Local::now().offset() gives UTC offset for the current machine,
        // we work backwards: pick a UTC hour such that local hour == target hour.
        let local = ts.with_timezone(&chrono::Local);
        let cur_local_hour = local.hour() as i64;
        let delta_hours = (hour as i64 - cur_local_hour).rem_euclid(24);
        let adjusted_ts = ts + chrono::Duration::hours(delta_hours);

        CueContext {
            sample: HrSample {
                timestamp: adjusted_ts,
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

    // Scenario 1: never-below → no fire.
    #[test]
    fn test_low_hr_never_below_no_fire() {
        let rt = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .unwrap();
        rt.block_on(async {
            let (mut rule, _dir) = make_low_hr_rule(70, 600).await;
            rule.hr_store.append(1_000, 80, None).await.unwrap();
            rule.hr_store.append(6_000, 82, None).await.unwrap();
            rule.hr_store.append(11_000, 81, None).await.unwrap();

            let ctx = make_ctx_at_hour(80, 12, 14);
            let result = rule.evaluate_mut(&ctx);
            assert!(result.is_none(), "should not fire when avg is always above threshold");
        });
    }

    // Scenario 2: brief-dip-then-recover → no fire.
    #[test]
    fn test_low_hr_brief_dip_no_fire() {
        let rt = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .unwrap();
        rt.block_on(async {
            let (mut rule, _dir) = make_low_hr_rule(70, 600).await;
            rule.hr_store.append(1_000, 75, None).await.unwrap();
            rule.hr_store.append(6_000, 72, None).await.unwrap();
            rule.hr_store.append(11_000, 65, None).await.unwrap();
            rule.hr_store.append(16_000, 70, None).await.unwrap();
            rule.hr_store.append(21_000, 78, None).await.unwrap();
            rule.hr_store.append(26_000, 80, None).await.unwrap();
            rule.hr_store.append(31_000, 82, None).await.unwrap();

            let ctx = make_ctx_at_hour(80, 32, 14);
            let result = rule.evaluate_mut(&ctx);
            assert!(result.is_none(), "brief dip should not fire");
        });
    }

    // Scenario 3: sustained-dip → one fire.
    #[test]
    fn test_low_hr_sustained_dip_one_fire() {
        let rt = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .unwrap();
        rt.block_on(async {
            let (mut rule, _dir) = make_low_hr_rule(70, 600).await;
            rule.hr_store.append(1_000, 62, None).await.unwrap();
            rule.hr_store.append(6_000, 63, None).await.unwrap();
            rule.hr_store.append(11_000, 64, None).await.unwrap();
            rule.hr_store.append(16_000, 62, None).await.unwrap();
            rule.hr_store.append(21_000, 65, None).await.unwrap();
            rule.hr_store.append(26_000, 63, None).await.unwrap();
            rule.hr_store.append(31_000, 64, None).await.unwrap();

            let ctx = make_ctx_at_hour(62, 32, 14);
            let result = rule.evaluate_mut(&ctx);
            assert!(result.is_some(), "sustained dip should fire");
            let cue = result.unwrap();
            assert_eq!(cue.label, "sustained_low_hr");
            assert_eq!(cue.source, CueSource::SustainedLowHr);
        });
    }

    // Scenario 4: continued-dip → no second fire (hysteresis).
    #[test]
    fn test_low_hr_continued_dip_no_second_fire() {
        let rt = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .unwrap();
        rt.block_on(async {
            let (mut rule, _dir) = make_low_hr_rule(70, 600).await;
            for i in 0..10 {
                rule.hr_store.append(1_000 + i as u64 * 5_000, 62, None).await.unwrap();
            }

            let ctx1 = make_ctx_at_hour(62, 52, 14);
            let first = rule.evaluate_mut(&ctx1);
            assert!(first.is_some(), "first sustained dip should fire");

            rule.hr_store.append(55_000, 62, None).await.unwrap();
            rule.hr_store.append(60_000, 63, None).await.unwrap();
            let ctx2 = make_ctx_at_hour(62, 61, 14);
            let second = rule.evaluate_mut(&ctx2);
            assert!(second.is_none(), "continued dip should not fire a second time (hysteresis)");
            assert!(rule.is_firing, "should remain in firing state");
        });
    }

    // Scenario 5: recovery-then-redip → one new fire.
    #[test]
    fn test_low_hr_recovery_then_redip_new_fire() {
        // This test uses a separate time range for Phase 3 so the rolling window
        // at re-dip evaluation contains ONLY dip samples (no overlap with Phase 1/2).
        let rt = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .unwrap();
        rt.block_on(async {
            let (mut rule, _dir) = make_low_hr_rule(70, 600).await;

            // Phase 1: first dip → fire.
            // 10 samples at ~63 bpm from t=1000 to t=46000 (5s apart).
            for i in 0..10 {
                rule.hr_store.append(1_000 + i as u64 * 5_000, 62 + (i % 3) as u16, None).await.unwrap();
            }
            let ctx1 = make_ctx_at_hour(62, 50_000, 14);
            let first = rule.evaluate_mut(&ctx1);
            assert!(first.is_some(), "first dip should fire");
            assert!(rule.is_firing);

            // Simulate full hysteresis recovery completing (avg stayed above 75 for 300s).
            // In production this happens when rolling_avg > threshold+hysteresis for
            // hysteresis_recovery_secs. Here we just test the reset path directly.
            rule.is_firing = false;
            rule.hysteresis_recovery_start = None;

            // Phase 3: re-dip with clean window — use separate timestamps (t=300000..360000).
            // The 600s window at t=370000 spans t=310000..370000 — no overlap with Phase 1.
            for i in 0..20 {
                rule.hr_store.append(300_000 + i as u64 * 3_000, 50, None).await.unwrap();
            }
            let ctx2 = make_ctx_at_hour(50, 370_000, 14);

            let second = rule.evaluate_mut(&ctx2);
            assert!(second.is_some(), "after reset and re-dip with clean window, should fire again");
            assert_eq!(second.unwrap().label, "sustained_low_hr");
        });
    }

    // Scenario 6: quiet-hours-suppressed.
    #[test]
    fn test_low_hr_quiet_hours_suppressed() {
        let rt = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .unwrap();
        rt.block_on(async {
            let (mut rule, _dir) = make_low_hr_rule(70, 600).await;
            rule.quiet_hours = DoNotDisturbWindow {
                start_hour: 22,
                end_hour: 7,
                tz_offset_secs: 0,
            };

            rule.hr_store.append(1_000, 62, None).await.unwrap();
            rule.hr_store.append(6_000, 63, None).await.unwrap();
            rule.hr_store.append(11_000, 64, None).await.unwrap();
            rule.hr_store.append(16_000, 62, None).await.unwrap();

            let ctx = make_ctx_at_hour(62, 17, 23);
            let result = rule.evaluate_mut(&ctx);
            assert!(result.is_none(), "should not fire during quiet hours");
        });
    }

    // Additional: stale data → no fire.
    #[test]
    fn test_low_hr_stale_no_fire() {
        let rt = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .unwrap();
        rt.block_on(async {
            let (mut rule, _dir) = make_low_hr_rule(70, 600).await;
            rule.hr_store.append(1_000, 62, None).await.unwrap();
            rule.hr_store.append(6_000, 63, None).await.unwrap();

            let mut ctx = make_ctx_at_hour(62, 7, 14);
            ctx.is_stale = true;
            let result = rule.evaluate_mut(&ctx);
            assert!(result.is_none(), "should not fire when data is stale");
        });
    }

    // Additional: empty store → no fire.
    #[test]
    fn test_low_hr_empty_store_no_fire() {
        let rt = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .unwrap();
        rt.block_on(async {
            let (mut rule, _dir) = make_low_hr_rule(70, 600).await;
            // No samples appended — store is empty.
            let ctx = make_ctx_at_hour(60, 1, 14);
            let result = rule.evaluate_mut(&ctx);
            assert!(result.is_none(), "should not fire when store is empty");
        });
    }
}