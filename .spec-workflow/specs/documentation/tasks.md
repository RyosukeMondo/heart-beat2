# Tasks Document

- [x] 1.1 Create comprehensive README.md
  - File: `README.md` (root)
  - Add project description, features, quick start, build instructions
  - Include badges for CI, coverage, license
  - Purpose: Primary entry point for new developers and users
  - _Leverage: existing project structure_
  - _Requirements: 1_
  - _Prompt: Role: Technical writer with software background | Task: Create README.md with sections: Overview (what/why), Features (bullet list from product.md), Tech Stack (Rust/Flutter/FRB), Prerequisites (Rust 1.75+, Flutter 3.16+, Android SDK), Quick Start (CLI and Flutter), Project Structure (tree), Development (link to docs/development.md), License. Add CI badge placeholder. Use clear, friendly language | Restrictions: Keep under 300 lines, use tables for clarity | Success: New developer can build and run project following README only_

- [ ] 2.1 Create architecture documentation
  - File: `docs/architecture.md`
  - Document hexagonal architecture, module boundaries, data flow
  - Include Mermaid diagrams for visualization
  - Purpose: Explain system design and structure
  - _Leverage: structure.md, existing codebase_
  - _Requirements: 2_
  - _Prompt: Role: Software architect and technical writer | Task: Create architecture.md with sections: Architecture Overview (hexagonal pattern), Module Breakdown (domain/ports/adapters/state/scheduler), Dependency Graph (Mermaid), Data Flow (BLE packet → FilteredHeartRate → UI), State Machines (connectivity, session diagrams), Key Design Decisions (why statig, why FRB v2). Add Mermaid diagrams showing module dependencies and data flow | Restrictions: Diagrams must be accurate, explain "why" not just "what" | Success: Developer understands where to add features_

- [ ] 2.2 Create module-specific docs
  - Files: `rust/src/domain/README.md`, `rust/src/state/README.md`, etc.
  - Document each major module's purpose and public API
  - Purpose: In-context documentation for module exploration
  - _Leverage: existing code and comments_
  - _Requirements: 2_
  - _Prompt: Role: Technical writer | Task: Create README.md in rust/src/domain/, rust/src/state/, rust/src/scheduler/, rust/src/adapters/. Each explains: module purpose, key types, main functions, usage examples, testing approach. Keep brief (50-100 lines each). Link to relevant files | Restrictions: Focus on public API, not implementation details | Success: Developer can understand module without reading all code_

- [x] 3.1 Add comprehensive doc comments
  - Files: All `rust/src/**/*.rs` public items
  - Add /// doc comments with examples to all public functions
  - Purpose: Generate quality cargo doc output
  - _Leverage: rustdoc standards_
  - _Requirements: 3_
  - _Prompt: Role: Rust documentation specialist | Task: Add doc comments (///) to all public functions, structs, enums in domain/, ports/, adapters/, state/, scheduler/, api.rs. Include: brief description, arguments explanation, return value, example usage, errors/panics if applicable. Use rustdoc code blocks with ```rust | Restrictions: Examples must compile, keep examples simple | Success: cargo doc generates complete documentation_

- [x] 3.2 Create API usage examples
  - File: `docs/api-examples.md`
  - Show common usage patterns with code examples
  - Purpose: Quick reference for library users
  - _Leverage: integration tests as source_
  - _Requirements: 3_
  - _Prompt: Role: Developer advocate | Task: Create api-examples.md with examples: Scanning for devices, Connecting and streaming HR, Running a training session, Using mock adapter for testing, Creating custom NotificationPort. Each example is complete, runnable code with explanations. Add "Common Patterns" section | Restrictions: All examples must compile and run | Success: Library user can copy-paste examples and run them_

- [ ] 4.1 Create user manual
  - File: `docs/user-guide.md`
  - Explain training zones, plan creation, CLI usage, app usage
  - Purpose: End-user documentation
  - _Leverage: product.md features_
  - _Requirements: 4_
  - _Prompt: Role: Fitness technology writer | Task: Create user-guide.md with sections: Understanding Heart Rate Zones (5 zones explained), Calculating Max HR (formulas), Creating Training Plans (JSON format with examples), CLI Guide (all commands with examples), Mobile App Guide (screenshots with descriptions). Use friendly, non-technical language. Add glossary | Restrictions: Assume user has basic fitness knowledge, avoid jargon | Success: Non-developer user can create and run training plans_

- [x] 4.2 Create training plan templates
  - Files: `docs/plans/` with example JSON files
  - Provide ready-to-use training plans for common goals
  - Purpose: Quick start for users
  - _Leverage: domain/training_plan.rs examples_
  - _Requirements: 4_
  - _Prompt: Role: Running coach and developer | Task: Create docs/plans/ directory with JSON files: beginner-base-building.json (3x30min Z2), 5k-training.json (intervals + tempo), marathon-pace.json (long Z3 runs), recovery-run.json (easy Z1-Z2). Add docs/plans/README.md explaining each plan's purpose, target athlete, and how to use | Restrictions: Plans must be realistic and safe | Success: User can copy plan and start training immediately_

- [ ] 5.1 Create development guide
  - File: `docs/development.md`
  - Document setup, workflow, testing, contribution process
  - Purpose: Onboard contributors
  - _Leverage: existing tooling and CI_
  - _Requirements: 5_
  - _Prompt: Role: Open source maintainer | Task: Create development.md with sections: Setup (Rust/Flutter install, clone, build), Development Workflow (edit → test → commit), Testing (cargo test, coverage), Code Standards (clippy, fmt, line limits from CLAUDE.md), PR Process (branch, commit, tests, review), Debugging (CLI first, logs, common issues). Add troubleshooting section | Restrictions: Instructions must work on Linux, be step-by-step | Success: Contributor can set up and submit PR following guide_

- [ ] 5.2 Create CONTRIBUTING.md
  - File: `CONTRIBUTING.md` (root)
  - Link to development.md, explain code of conduct and license
  - Purpose: Standard GitHub contribution guide
  - _Leverage: docs/development.md_
  - _Requirements: 5_
  - _Prompt: Role: Open source maintainer | Task: Create CONTRIBUTING.md with sections: Welcome, Code of Conduct (link to CODE_OF_CONDUCT.md), How to Contribute (bug reports, features, docs), Development Setup (link to docs/development.md), Pull Request Process (branch naming, commit messages, tests required, review process), Style Guide (link to CLAUDE.md). Keep concise | Restrictions: Friendly tone, encourage first-time contributors | Success: GitHub shows CONTRIBUTING.md on PR page_

- [ ] 5.3 Add inline code examples
  - Files: `examples/` directory with runnable examples
  - Create standalone examples for common use cases
  - Purpose: Demonstrate library usage
  - _Leverage: integration tests_
  - _Requirements: 3_
  - _Prompt: Role: Developer relations engineer | Task: Create examples/ directory with: basic_scan.rs (scan and list devices), stream_hr.rs (connect and stream HR data), mock_session.rs (run session with mock adapter), custom_notifier.rs (implement NotificationPort). Each is standalone binary with main(). Add examples/README.md explaining how to run | Restrictions: Must build with cargo run --example <name> | Success: Examples run without modification_
