//! Composable logging infrastructure with broadcast, ring buffer, and file appender.
//!
//! Provides:
//! - A log broadcast channel so multiple consumers (debug server, file logger) can subscribe
//! - A ring buffer of recent log entries for instant retrieval
//! - Optional file-based daily-rotating log appender via `tracing-appender`

use crate::api::LogMessage;
use parking_lot::RwLock;
use std::collections::VecDeque;
use std::io::Write;
use std::path::Path;
use std::sync::OnceLock;
use tokio::sync::broadcast;
use tracing_appender::non_blocking::WorkerGuard;
use tracing_subscriber::{
    fmt::{format::FmtSpan, MakeWriter},
    EnvFilter,
};

const LOG_CHANNEL_CAPACITY: usize = 256;
const RING_BUFFER_CAPACITY: usize = 1000;

// Global broadcast sender for log messages
static LOG_TX: OnceLock<broadcast::Sender<LogMessage>> = OnceLock::new();

// Global ring buffer for recent log entries
static LOG_RING: OnceLock<RwLock<VecDeque<LogMessage>>> = OnceLock::new();

// Keep file appender guard alive for the lifetime of the process
static _FILE_GUARD: OnceLock<WorkerGuard> = OnceLock::new();

fn get_or_create_log_sender() -> broadcast::Sender<LogMessage> {
    LOG_TX
        .get_or_init(|| {
            let (tx, _rx) = broadcast::channel(LOG_CHANNEL_CAPACITY);
            tx
        })
        .clone()
}

fn get_ring_buffer() -> &'static RwLock<VecDeque<LogMessage>> {
    LOG_RING.get_or_init(|| RwLock::new(VecDeque::with_capacity(RING_BUFFER_CAPACITY)))
}

/// Subscribe to the live log stream. Returns a broadcast receiver.
pub fn subscribe_log_stream() -> broadcast::Receiver<LogMessage> {
    get_or_create_log_sender().subscribe()
}

/// Emit a log message to all subscribers and the ring buffer.
pub fn emit_log(msg: LogMessage) {
    // Push into ring buffer
    {
        let ring = get_ring_buffer();
        let mut buf = ring.write();
        if buf.len() >= RING_BUFFER_CAPACITY {
            buf.pop_front();
        }
        buf.push_back(msg.clone());
    }
    // Broadcast (ignore if no receivers)
    let tx = get_or_create_log_sender();
    let _ = tx.send(msg);
}

/// Get recent log entries from the ring buffer.
///
/// Optionally filter by minimum level and limit the number of entries returned.
pub fn get_recent_logs(level_filter: Option<&str>, limit: usize) -> Vec<LogMessage> {
    let ring = get_ring_buffer();
    let buf = ring.read();
    let iter = buf.iter().rev();

    let filtered: Vec<LogMessage> = if let Some(min_level) = level_filter {
        let min_ord = level_ordinal(min_level);
        iter.filter(|m| level_ordinal(&m.level) >= min_ord)
            .take(limit)
            .cloned()
            .collect()
    } else {
        iter.take(limit).cloned().collect()
    };

    // Reverse back to chronological order
    filtered.into_iter().rev().collect()
}

fn level_ordinal(level: &str) -> u8 {
    match level.to_uppercase().as_str() {
        "TRACE" => 0,
        "DEBUG" => 1,
        "INFO" => 2,
        "WARN" | "WARNING" => 3,
        "ERROR" => 4,
        _ => 2,
    }
}

/// Custom writer that broadcasts parsed log lines to the log channel + ring buffer.
struct BroadcastLogWriter;

impl Write for BroadcastLogWriter {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        let log_str = String::from_utf8_lossy(buf);

        // Parse tracing format (with_ansi=false):
        // "2026-03-20T07:00:46.891Z  INFO heart_beat::api: message"
        // or without time: "INFO heart_beat::api: message"
        let trimmed = log_str.trim();
        if trimmed.is_empty() {
            return Ok(buf.len());
        }

        let timestamp = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_millis() as u64;

        // Try to find a log level keyword to orient parsing
        let level_keywords = ["TRACE", "DEBUG", " INFO", " WARN", "ERROR"];
        let mut found_level = None;
        let mut level_end = 0;

        for keyword in &level_keywords {
            if let Some(pos) = trimmed.find(keyword) {
                found_level = Some(keyword.trim().to_string());
                level_end = pos + keyword.len();
                break;
            }
        }

        if let Some(level) = found_level {
            let rest = trimmed[level_end..].trim();
            let (target, message) = if let Some(idx) = rest.find(": ") {
                (rest[..idx].trim().to_string(), rest[idx + 2..].to_string())
            } else {
                ("unknown".to_string(), rest.to_string())
            };

            emit_log(LogMessage {
                level,
                target,
                timestamp,
                message,
            });
        }

        Ok(buf.len())
    }

    fn flush(&mut self) -> std::io::Result<()> {
        Ok(())
    }
}

impl<'a> MakeWriter<'a> for BroadcastLogWriter {
    type Writer = BroadcastLogWriter;
    fn make_writer(&'a self) -> Self::Writer {
        BroadcastLogWriter
    }
}

/// Initialize the server/CLI logging subsystem.
///
/// Sets up:
/// 1. Console output (stderr)
/// 2. Broadcast channel + ring buffer (via `BroadcastLogWriter`)
/// 3. Optional daily-rotating file appender if `log_dir` is provided
///
/// This is used by the debug server and CLI binaries (NOT by Flutter, which
/// uses `api::init_logging` with its own `StreamSink`).
pub fn init_server_logging(log_dir: Option<&Path>, verbose: bool) {
    let env_filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| {
        if verbose {
            EnvFilter::new("debug")
        } else {
            EnvFilter::new("info")
        }
    });

    if let Some(dir) = log_dir {
        // Set up file appender with daily rotation
        let file_appender = tracing_appender::rolling::daily(dir, "heart-beat.log");
        let (non_blocking, guard) = tracing_appender::non_blocking(file_appender);
        let _ = _FILE_GUARD.set(guard);

        // Combined writer: stderr + file + broadcast
        let subscriber = tracing_subscriber::fmt()
            .with_writer(move || -> Box<dyn Write> {
                Box::new(CombinedWriter {
                    stderr: std::io::stderr(),
                    file: non_blocking.clone(),
                    broadcast: BroadcastLogWriter,
                })
            })
            .with_ansi(false)
            .with_env_filter(env_filter)
            .with_target(true)
            .with_level(true)
            .with_thread_ids(false)
            .with_thread_names(false)
            .with_span_events(FmtSpan::NONE)
            .finish();

        tracing::subscriber::set_global_default(subscriber)
            .expect("Failed to set global tracing subscriber");
    } else {
        // stderr + broadcast only
        let subscriber = tracing_subscriber::fmt()
            .with_writer(move || -> Box<dyn Write> {
                Box::new(CombinedWriter {
                    stderr: std::io::stderr(),
                    file: std::io::sink(),
                    broadcast: BroadcastLogWriter,
                })
            })
            .with_ansi(false)
            .with_env_filter(env_filter)
            .with_target(true)
            .with_level(true)
            .with_thread_ids(false)
            .with_thread_names(false)
            .with_span_events(FmtSpan::NONE)
            .finish();

        tracing::subscriber::set_global_default(subscriber)
            .expect("Failed to set global tracing subscriber");
    }
}

/// Writer that fans out to stderr, a file, and the broadcast channel.
struct CombinedWriter<F: Write> {
    stderr: std::io::Stderr,
    file: F,
    broadcast: BroadcastLogWriter,
}

impl<F: Write> Write for CombinedWriter<F> {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        let _ = self.stderr.write(buf);
        let _ = self.file.write(buf);
        let _ = self.broadcast.write(buf);
        Ok(buf.len())
    }

    fn flush(&mut self) -> std::io::Result<()> {
        let _ = self.stderr.flush();
        let _ = self.file.flush();
        Ok(())
    }
}
