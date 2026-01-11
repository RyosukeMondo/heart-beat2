# Tasks Document

- [x] 1.1 Restructure CLI with clap subcommands
  - File: `rust/src/bin/cli.rs`
  - Replace simple args with clap v4 derive API
  - Add subcommands: devices, session, mock, plan
  - Purpose: Organize CLI into logical command groups
  - _Leverage: clap crate with derive macros_
  - _Requirements: All_
  - _Prompt: Role: Rust CLI architect | Task: Restructure cli.rs using clap v4 derive API. Create enum Commands { Devices(DevicesCmd), Session(SessionCmd), Mock(MockCmd), Plan(PlanCmd) }. Each subcommand is its own enum with #[command(subcommand)]. Add help text and examples | Restrictions: Must maintain backward compatibility for basic scan/connect | Success: cli --help shows all subcommands with descriptions_

- [ ] 1.2 Implement devices subcommand
  - File: `rust/src/bin/cli.rs`
  - Add devices scan, connect, info, disconnect commands
  - Use comfy-table for formatted output
  - Purpose: Rich device management
  - _Leverage: api::scan_devices, api::connect_device_
  - _Requirements: 1_
  - _Prompt: Role: Rust CLI developer | Task: Implement DevicesCmd enum with Scan, Connect{id}, Info, Disconnect variants. Scan uses comfy-table to display devices with columns: Name, ID, RSSI, Services. Connect shows progress with spinners. Info displays battery and signal strength. Add colored output | Restrictions: Must handle errors gracefully, show user-friendly messages | Success: Table output is readable, progress indicators work_
  - _Status: Scan and Connect are implemented. Info and Disconnect still need implementation._

- [ ] 2.1 Implement session subcommand
  - File: `rust/src/bin/cli.rs`
  - Add session start, pause, resume, stop commands
  - Real-time display with crossterm for terminal manipulation
  - Purpose: Execute training sessions from CLI
  - _Leverage: scheduler::SessionExecutor_
  - _Requirements: 2_
  - _Prompt: Role: Rust TUI developer | Task: Implement SessionCmd enum with Start{plan_path}, Pause, Resume, Stop. On start, load TrainingPlan from JSON, create SessionExecutor, display live updates: current phase, elapsed/remaining time, current BPM, target zone. Use crossterm to update in-place (no scrolling). Color zone indicator | Restrictions: Must handle Ctrl+C gracefully (save state), update at 1Hz minimum | Success: Session display updates smoothly, shows all metrics_
  - _Status: Start is implemented. Pause, Resume, and Stop with summary still need implementation._

- [x] 3.1 Implement enhanced mock subcommand
  - File: `rust/src/bin/cli.rs`
  - Add mock scenarios: steady, ramp, interval, dropout
  - Generate realistic HR patterns with noise
  - Purpose: Test edge cases without hardware
  - _Leverage: api::start_mock_mode, rand crate_
  - _Requirements: 3_
  - _Prompt: Role: Rust simulation developer | Task: Implement MockCmd enum with Steady{bpm}, Ramp{start, end, duration}, Interval{low, high, work_secs, rest_secs}, Dropout{probability}. Generate FilteredHeartRate with noise using rand::thread_rng().gen_range(). Emit via api::emit_hr_data(). Add timestamp and natural variability | Restrictions: BPM must stay in 30-220 range, noise realistic (±5 BPM max) | Success: Mock patterns are realistic, interval timing accurate_

- [x] 4.1 Implement plan subcommand
  - File: `rust/src/bin/cli.rs`
  - Add plan list, show, validate, create commands
  - Interactive plan creation with dialoguer crate
  - Purpose: Manage training plans
  - _Leverage: domain::TrainingPlan_
  - _Requirements: 4_
  - _Prompt: Role: Rust interactive CLI developer | Task: Implement PlanCmd enum with List, Show{name}, Validate{path}, Create. List reads ~/.heart-beat/plans/*.json. Show displays plan in comfy-table with phases. Validate checks TrainingPlan::validate(). Create uses dialoguer for interactive input (name, phases loop, zone selection, duration). Save to JSON | Restrictions: Create must validate all inputs, handle user cancellation | Success: Interactive wizard is intuitive, plans save correctly_

- [x] 5.1 Add real-time session display
  - File: `rust/src/bin/cli.rs` (helper module)
  - Create SessionDisplay struct for terminal UI
  - Use crossterm for cursor control and colors
  - Purpose: Professional TUI for session monitoring
  - _Leverage: crossterm, colored crates_
  - _Requirements: 2_
  - _Prompt: Role: Rust TUI specialist | Task: Create SessionDisplay struct with render() method. Display layout: header (plan name), current phase bar, BPM (large font), zone indicator (colored bar), time remaining, zone deviation alerts. Use crossterm to move cursor and update in-place. Handle terminal resize. Add Ctrl+C handler to pause session | Restrictions: Must work on Linux terminal, handle small terminal sizes | Success: Display updates smoothly, looks professional_

- [x] 5.2 Add Cargo.toml dependencies
  - File: `rust/Cargo.toml`
  - Add comfy-table, crossterm, dialoguer, indicatif
  - Update clap features
  - Purpose: Support enhanced CLI features
  - _Leverage: existing Cargo.toml_
  - _Requirements: All_
  - _Prompt: Role: Rust dependency manager | Task: Add dependencies: comfy-table = "7", crossterm = "0.27", dialoguer = "0.11", indicatif = "0.17". Update clap features to include "derive". Verify all dependencies compile together | Restrictions: Use stable versions, avoid conflicts | Success: cargo build succeeds with new dependencies_
