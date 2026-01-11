# Contributing to Heart Beat

Thank you for your interest in contributing to Heart Beat! We welcome contributions from developers of all experience levels. Whether you're fixing a bug, adding a feature, improving documentation, or sharing ideas, your help is appreciated.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How You Can Contribute](#how-you-can-contribute)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Pull Request Process](#pull-request-process)
- [Style Guide](#style-guide)
- [Testing Guidelines](#testing-guidelines)
- [Community](#community)

## Code of Conduct

This project adheres to a code of conduct that all contributors are expected to follow. By participating, you agree to:

- Be respectful and inclusive in all interactions
- Welcome newcomers and help them get oriented
- Focus on constructive feedback and collaboration
- Respect differing viewpoints and experiences
- Accept responsibility and apologize when mistakes happen

Please report any unacceptable behavior to the project maintainers.

## How You Can Contribute

There are many ways to contribute to Heart Beat:

### Reporting Bugs

Found a bug? Help us fix it:

1. **Check existing issues** - Someone may have already reported it
2. **Create a detailed issue** - Include:
   - Clear description of the problem
   - Steps to reproduce
   - Expected vs actual behavior
   - Your environment (OS, Rust version, Flutter version)
   - Relevant logs or error messages
   - Screenshots/recordings if applicable

**Tip:** Use the issue templates if available - they guide you through providing the right information.

### Suggesting Features

Have an idea for improvement?

1. **Search existing issues** - Your idea might already be under discussion
2. **Open a feature request** - Explain:
   - What problem does this solve?
   - How would it work?
   - Why is this valuable?
   - Are there any alternatives?

Keep feature requests focused on user/developer needs rather than specific implementations.

### Improving Documentation

Documentation contributions are incredibly valuable:

- Fix typos or clarify confusing sections
- Add missing code examples
- Improve API documentation with better descriptions
- Create tutorials or guides
- Update outdated information
- Add diagrams or visualizations

Even small improvements help make the project more accessible.

### Contributing Code

Ready to write code? Great! See [Development Setup](#development-setup) below.

**Good first contributions:**
- Fix documentation typos or broken links
- Add test coverage for untested code
- Implement features marked as "good first issue"
- Improve error messages or logging
- Add examples to doc comments

## Getting Started

### Before You Start

1. **Find an issue to work on** - Browse the [issue tracker](https://github.com/heart-beat/heart-beat/issues)
   - Look for `good first issue` labels if you're new
   - Check `help wanted` for areas where we need assistance
   - Comment on the issue to let others know you're working on it

2. **Discuss major changes** - For significant features or refactors:
   - Open an issue first to discuss the approach
   - Wait for maintainer feedback before investing time
   - This prevents wasted effort on changes that might not fit the project

3. **Fork the repository** - Click "Fork" on GitHub to create your copy

## Development Setup

### Prerequisites

You'll need the following tools installed:

| Tool | Version | Purpose |
|------|---------|---------|
| Rust | 1.75+ | Core library development |
| Flutter | 3.16+ | Mobile app development |
| Android SDK | API 26-34 | Android builds |
| Android NDK | r25c+ | Rust cross-compilation |
| Git | 2.0+ | Version control |

### Quick Setup

```bash
# 1. Fork and clone your fork
git clone https://github.com/YOUR_USERNAME/heart-beat.git
cd heart-beat

# 2. Add upstream remote
git remote add upstream https://github.com/heart-beat/heart-beat.git

# 3. Build and test Rust core
cd rust
cargo build
cargo test

# 4. Build Flutter app
cd ..
flutter pub get
flutter build apk --debug
```

**Full setup instructions:** See our comprehensive [Development Guide](docs/development.md) for:
- Detailed installation steps
- Environment configuration
- Troubleshooting common issues
- Development workflow best practices

## Pull Request Process

### Creating Your PR

1. **Create a feature branch**

```bash
git checkout -b feature/descriptive-name
# or
git checkout -b fix/bug-description
```

**Branch naming:**
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation changes
- `test/` - Test additions/improvements
- `refactor/` - Code refactoring

2. **Make your changes**

Follow the [Style Guide](#style-guide) and write tests for new functionality.

3. **Commit with clear messages**

```bash
git add .
git commit -m "feat(module): brief description

Detailed explanation of what changed and why.

Fixes #123"
```

**Commit message format:**
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:** `feat`, `fix`, `docs`, `test`, `refactor`, `perf`, `chore`

**Examples:**
```
feat(domain): add RMSSD calculation for HRV analysis
fix(cli): correct zone boundary calculation in display
docs(api): add comprehensive examples for training plan API
test(filters): add property tests for Kalman filter stability
```

4. **Run the quality checks**

```bash
# Rust checks
cd rust
cargo test --all-features
cargo clippy --all-targets --all-features -- -D warnings
cargo fmt --check

# Flutter checks
cd ..
flutter analyze
flutter test
```

All checks must pass before submitting your PR.

5. **Push your branch**

```bash
git push -u origin feature/descriptive-name
```

6. **Create the Pull Request**

On GitHub:
- Click "New Pull Request"
- Choose your branch
- Fill out the PR template with:
  - **Summary** - What does this PR do?
  - **Motivation** - Why is this change needed?
  - **Changes** - What specifically changed?
  - **Testing** - How can reviewers test this?
  - **Screenshots** - For UI changes

**Link related issues:** Use "Fixes #123" or "Closes #456" in the description.

### PR Requirements

Before your PR can be merged:

- [ ] All tests pass (Rust and Flutter)
- [ ] Code follows style guidelines (clippy, fmt, analyze)
- [ ] New code has appropriate test coverage
- [ ] Public APIs have documentation comments
- [ ] No compiler warnings
- [ ] Commit messages follow the format
- [ ] PR description is complete and clear

### Review Process

**What to expect:**

1. **Automated checks** - CI will run tests and linting
2. **Maintainer review** - Code review from project maintainers
3. **Feedback** - Suggestions for improvements or questions
4. **Iteration** - Make requested changes and push new commits
5. **Approval** - Once approved, your PR will be merged

**During review:**
- Be responsive to feedback
- Ask questions if feedback is unclear
- Mark conversations as resolved after addressing them
- Don't force-push while review is in progress (pushes new commits instead)

**After approval:**
- Maintainers will merge using "Squash and merge"
- Your branch will be deleted automatically
- Celebrate your contribution!

## Style Guide

### Rust Code Style

**Formatting:**
```bash
cargo fmt
```

All code must pass `cargo fmt --check` - CI enforces this.

**Linting:**
```bash
cargo clippy --all-targets --all-features -- -D warnings
```

Zero warnings allowed - fix or explicitly allow with documented reasoning.

**Code quality rules:**
- **Line length:** ≤100 characters (rustfmt default)
- **Documentation:** All public items need `///` doc comments
- **Error handling:** Use `anyhow::Result` for fallible functions
- **Async traits:** Use `#[async_trait]` for async trait methods
- **Naming conventions:**
  - Types: `PascalCase`
  - Functions/variables: `snake_case`
  - Constants: `SCREAMING_SNAKE_CASE`
  - Modules: `snake_case`

**Documentation example:**
```rust
/// Calculate the training zone for a given heart rate.
///
/// Uses percentage of max HR to determine zone (1-5).
///
/// # Arguments
///
/// * `bpm` - Current heart rate in beats per minute
/// * `max_hr` - User's maximum heart rate
///
/// # Returns
///
/// * `Ok(Some(Zone))` - The appropriate training zone
/// * `Ok(None)` - BPM below training threshold
/// * `Err` - Invalid max_hr
///
/// # Examples
///
/// ```
/// use heart_beat::domain::training_plan::calculate_zone;
///
/// let zone = calculate_zone(140, 200).unwrap();
/// assert_eq!(zone, Some(Zone::Zone3));
/// ```
pub fn calculate_zone(bpm: u16, max_hr: u16) -> Result<Option<Zone>> {
    // Implementation...
}
```

### Flutter/Dart Style

Follow official Dart style guide:

```bash
flutter format lib/
flutter analyze
```

### General Guidelines

**Keep it simple:**
- Don't over-engineer solutions
- Avoid premature optimization
- Only add complexity when needed
- Prefer clarity over cleverness

**Write tests:**
- Unit tests for business logic
- Integration tests for workflows
- Property tests for algorithms
- Mock tests for external dependencies

**Document your code:**
- Public APIs must have doc comments
- Complex logic needs inline comments
- Examples help users understand usage
- Update docs when behavior changes

## Testing Guidelines

### Writing Tests

**Every contribution should include tests:**

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_zone_calculation() {
        let zone = calculate_zone(140, 200).unwrap();
        assert_eq!(zone, Some(Zone::Zone3));
    }
}
```

### Test Categories

- **Unit tests** - Test individual functions/methods
- **Integration tests** - Test module interactions
- **Property tests** - Test algorithm invariants
- **Mock tests** - Test with mocked dependencies

### Coverage Requirements

- **Minimum:** 80% line coverage (enforced by CI)
- **Target:** 85%+ for new code
- **Critical paths:** 95%+ (domain logic, state machines)

Check coverage locally:
```bash
cargo install cargo-tarpaulin
cargo tarpaulin --out Html --output-dir coverage
xdg-open coverage/index.html
```

## Community

### Getting Help

**Stuck? Have questions?**

1. **Check the docs** - Start with [Development Guide](docs/development.md)
2. **Search issues** - Your question might already be answered
3. **Ask in discussions** - GitHub Discussions for questions
4. **Create an issue** - For bugs or feature requests

**When asking for help:**
- Describe what you're trying to do
- Show what you've tried
- Include error messages and logs
- Mention your environment (OS, versions)
- Provide minimal reproducible examples

### Recognizing Contributors

We value all contributions and recognize contributors in:
- Release notes
- Project README
- Contributor list
- Special thanks for significant contributions

Your contributions make this project better for everyone. Thank you!

---

## Quick Reference

**Common tasks:**

```bash
# Setup
git clone https://github.com/YOUR_USERNAME/heart-beat.git
cd heart-beat
git remote add upstream https://github.com/heart-beat/heart-beat.git

# Development
git checkout -b feature/my-feature
# ... make changes ...
cargo test && cargo clippy && cargo fmt

# Submit
git add .
git commit -m "feat(scope): description"
git push -u origin feature/my-feature
# Create PR on GitHub

# Stay updated
git fetch upstream
git rebase upstream/main
```

**Need more details?**
- [Development Guide](docs/development.md) - Complete development workflow
- [Architecture Guide](docs/architecture.md) - System design and structure
- [API Examples](docs/api-examples.md) - Code usage patterns

---

**Happy contributing!** We're excited to have you as part of the Heart Beat community.
