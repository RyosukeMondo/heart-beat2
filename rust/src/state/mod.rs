//! State management module for connection lifecycle and session execution.
//!
//! This module contains state machines for managing various application states,
//! particularly the BLE connection lifecycle and training session execution.

pub mod connectivity;
pub mod session;

pub use connectivity::{
    reconnect_delay, ConnectionContext, ConnectionEvent, ConnectionState, ConnectionStateMachine,
};
pub use session::{SessionEvent, SessionState, SessionStateMachineWrapper, ZoneDeviation};
