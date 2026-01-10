//! State management module for connection lifecycle.
//!
//! This module contains state machines for managing various application states,
//! particularly the BLE connection lifecycle.

pub mod connectivity;

pub use connectivity::{ConnectionEvent, ConnectionState, ConnectionStateMachine};
