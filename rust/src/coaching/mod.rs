//! Coaching subsystem — rule engine for real-time HR coaching cues.
//!
//! # Architecture
//!
//! The coaching subsystem evaluates incoming HR samples against a set of
//! configurable rules and emits [`Cue`] events when conditions are met.
//!
//! ## Core concepts
//!
//! - [`Rule`]: A pluggable evaluator that inspects a sample + context and
//!   optionally returns a [`Cue`].
//! - [`Cue`]: A coaching directive to surface to the user.
//! - [`CueContext`]: Shared state passed to every rule on each evaluation.
//! - [`DoNotDisturbWindow`]: Suppresses audio/notification cues during configured hours.
//! - [`CueCadence`]: Prevents the same cue from firing within a minimum interval.
//!
//! # Usage
//!
//! ```
//! use heart_beat::coaching::{RuleEngine, TargetZoneRule, InactivityRule};
//!
//! let engine = RuleEngine::new()
//!     .with_rule(TargetZoneRule::new(120, 150))
//!     .with_rule(InactivityRule::new(60, 300));
//! ```

pub mod cue;
pub mod rule;

pub use cue::{Cue, CueContext, CuePriority};
pub use rule::{InactivityRule, OverworkRule, Rule, RuleEngine, TargetZoneRule};