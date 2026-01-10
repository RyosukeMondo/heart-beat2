//! Session scheduler module for executing training sessions.
//!
//! This module provides the `SessionExecutor` for managing training session execution,
//! including tick-based progress tracking, HR monitoring, persistence, and cron scheduling.

pub mod executor;

pub use executor::*;
