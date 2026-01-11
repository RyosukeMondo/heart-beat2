# Design Document

## Architecture Overview

Enhanced CLI with subcommand structure and rich terminal UI. Delegates to existing core logic, focuses on presentation and UX.

```
cli.rs (clap subcommands)
     ↓
  ┌──────┼───────┐
  ↓      ↓       ↓
devices session  plan
  ↓      ↓       ↓
api.rs  executor domain
```

## Command Structure

### Root Command
```bash
heart-beat-cli [OPTIONS] <COMMAND>

Commands:
  devices    Manage BLE device connections
  session    Run training sessions
  mock       Generate simulated HR data
  plan       Manage training plans
  help       Print help information
```

### Devices Subcommand
```bash
cli devices scan                 # Scan for devices
cli devices connect <id>         # Connect to device
cli devices info                 # Show connected device info
cli devices disconnect           # Disconnect current device
```

**Output Example:**
```
┌──────────────────┬──────────────┬──────┬─────────────┐
│ Name             │ ID           │ RSSI │ Services    │
├──────────────────┼──────────────┼──────┼─────────────┤
│ Coospo HW9       │ AA:BB:CC:... │ -45  │ HR, Battery │
│ Unknown Device   │ DD:EE:FF:... │ -67  │ HR          │
└──────────────────┴──────────────┴──────┴─────────────┘
```

### Session Subcommand
```bash
cli session start <plan.json>    # Start session with plan
cli session pause                # Pause active session
cli session resume               # Resume paused session
cli session stop                 # Stop and summarize session
```

**Live Display:**
```
╔════════════════════════════════════════════════════════╗
║             5K Tempo Run - Phase 2/3                   ║
║ Tempo Work                                             ║
╠════════════════════════════════════════════════════════╣
║                                                        ║
║                       156 BPM                          ║
║                                                        ║
║  ┌────────────────────────────────────────────────┐   ║
║  │█████████████████ Zone 3 ███████████████████   │   ║
║  └────────────────────────────────────────────────┘   ║
║                                                        ║
║  Elapsed: 12:34  │  Remaining: 07:26  │  Target: Z3  ║
║                                                        ║
║  ✓ IN ZONE                                             ║
╚════════════════════════════════════════════════════════╝
```

### Mock Subcommand
```bash
cli mock steady --bpm 140
cli mock ramp --start 120 --end 180 --duration 60
cli mock interval --low 130 --high 170 --work 30 --rest 30
cli mock dropout --probability 0.1
```

**Pattern Generation:**
```rust
// Steady with noise
fn steady_pattern(bpm: u16) -> impl Stream<Item = u16> {
    let mut rng = thread_rng();
    tokio_stream::StreamExt::throttle(
        stream::repeat_with(move || {
            let noise = rng.gen_range(-2..=2);
            (bpm as i16 + noise).clamp(30, 220) as u16
        }),
        Duration::from_millis(1000)
    )
}

// Ramp
fn ramp_pattern(start: u16, end: u16, duration_secs: u32) -> impl Stream {
    let delta = (end as f32 - start as f32) / duration_secs as f32;
    stream::unfold((0, start as f32), move |(i, current)| async move {
        if i >= duration_secs {
            return None;
        }
        let bpm = current as u16;
        tokio::time::sleep(Duration::from_secs(1)).await;
        Some((bpm, (i + 1, current + delta)))
    })
}
```

### Plan Subcommand
```bash
cli plan list                    # List all saved plans
cli plan show <name>             # Display plan details
cli plan validate <file>         # Validate plan file
cli plan create                  # Interactive plan creator
```

**Interactive Creator:**
```
? Plan name: Morning Intervals
? Add a phase? Yes
  ? Phase name: Warmup
  ? Target zone: Zone 2
  ? Duration (seconds): 600
  ? Transition: Time Elapsed
? Add another phase? Yes
  ? Phase name: Intervals
  ? Target zone: Zone 5
  ? Duration (seconds): 180
  ? Transition: Time Elapsed
? Add another phase? No
✓ Plan saved to ~/.heart-beat/plans/morning-intervals.json
```

## Terminal UI Components

### SessionDisplay
```rust
pub struct SessionDisplay {
    plan_name: String,
    current_phase: usize,
    total_phases: usize,
    phase_name: String,
    current_bpm: u16,
    target_zone: Zone,
    elapsed_secs: u32,
    remaining_secs: u32,
    deviation: ZoneDeviation,
}

impl SessionDisplay {
    pub fn render(&self) -> Result<()> {
        // Clear screen and move to top
        execute!(stdout(), Clear(ClearType::All), MoveTo(0, 0))?;

        // Render header
        self.render_header()?;

        // Render BPM (large)
        self.render_bpm()?;

        // Render zone bar
        self.render_zone_bar()?;

        // Render progress
        self.render_progress()?;

        // Render deviation alert
        self.render_deviation()?;

        stdout().flush()?;
        Ok(())
    }

    fn render_zone_bar(&self) -> Result<()> {
        let color = match self.target_zone {
            Zone::Zone1 => Color::Blue,
            Zone::Zone2 => Color::Green,
            Zone::Zone3 => Color::Yellow,
            Zone::Zone4 => Color::DarkYellow,
            Zone::Zone5 => Color::Red,
        };

        let bar = "█".repeat(40);
        println!("  {}", bar.color(color));
        Ok(())
    }
}
```

## File Locations

Plans stored in:
```
~/.heart-beat/
  plans/
    tempo-run.json
    base-endurance.json
    vo2-intervals.json
  sessions/
    session-2026-01-11-120000.json  # Session logs
```

## Error Handling

User-friendly error messages:
```rust
match result {
    Err(e) if e.to_string().contains("no device") => {
        eprintln!("{} No device connected. Run 'cli devices connect <id>' first.",
            "Error:".red().bold());
    }
    Err(e) if e.to_string().contains("invalid plan") => {
        eprintln!("{} Invalid training plan. Run 'cli plan validate <file>' to check.",
            "Error:".red().bold());
    }
    Err(e) => {
        eprintln!("{} {}", "Error:".red().bold(), e);
    }
}
```

## Testing Strategy

### Manual Testing
- Test each subcommand with valid/invalid inputs
- Verify table formatting on different terminal sizes
- Test Ctrl+C handling during session
- Verify mock patterns are realistic

### Integration Tests
- CLI invocation via Command::new("cli")
- Capture stdout and verify output
- Test session state persistence across pause/resume
