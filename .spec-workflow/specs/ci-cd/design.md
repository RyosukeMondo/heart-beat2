# Design Document

## CI/CD Pipeline Overview

```
┌─────────────────────────────────────────────────────┐
│                   Git Push/PR                       │
└────────────────────┬────────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        ↓            ↓            ↓
    ┌────────┐  ┌────────┐  ┌──────────┐
    │ Lint   │  │ Test   │  │ Coverage │
    │        │  │        │  │          │
    │ Rust   │  │ Rust   │  │ 80% min  │
    │ Flutter│  │ Flutter│  │          │
    └────────┘  └────────┘  └──────────┘
        │            │            │
        └────────────┼────────────┘
                     │ ✓ All pass
                     ↓
            ┌─────────────────┐
            │  PR Mergeable   │
            └─────────────────┘
                     │
                     │ Merge to main
                     ↓
            ┌─────────────────┐
            │  Tag v1.0.0     │
            └─────────────────┘
                     │
                     ↓
        ┌────────────┼────────────┐
        ↓            ↓            ↓
    ┌────────┐  ┌────────┐  ┌────────┐
    │ Build  │  │ Build  │  │ Build  │
    │ Linux  │  │ macOS  │  │ APK    │
    └────────┘  └────────┘  └────────┘
        │            │            │
        └────────────┼────────────┘
                     ↓
            ┌─────────────────┐
            │ GitHub Release  │
            │ + Binaries      │
            └─────────────────┘
```

## GitHub Actions Workflows

### 1. ci.yml - Main CI Pipeline

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test-rust:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        rust: [stable, beta]
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@master
        with:
          toolchain: ${{ matrix.rust }}
      - uses: Swatinem/rust-cache@v2
      - name: Run tests
        run: cargo test --all --verbose
      - name: Run doc tests
        run: cargo test --doc

  lint-rust:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: clippy, rustfmt
      - name: Check formatting
        run: cargo fmt --all -- --check
      - name: Clippy
        run: cargo clippy --all-targets --all-features -- -D warnings

  test-flutter:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
      - name: Install dependencies
        run: flutter pub get
      - name: Run tests
        run: flutter test
      - name: Analyze
        run: flutter analyze
```

### 2. coverage.yml - Coverage Tracking

```yaml
name: Coverage

on:
  push:
    branches: [main]
  pull_request:

jobs:
  coverage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: llvm-tools-preview
      - uses: Swatinem/rust-cache@v2
      - name: Install cargo-llvm-cov
        run: cargo install cargo-llvm-cov
      - name: Generate coverage
        run: cargo llvm-cov --all-features --lcov --output-path lcov.info
      - name: Upload to Codecov
        uses: codecov/codecov-action@v3
        with:
          files: lcov.info
          fail_ci_if_error: true
      - name: Check coverage threshold
        run: |
          coverage=$(cargo llvm-cov --all-features --summary-only | grep -oP 'TOTAL.*\K\d+\.\d+')
          if (( $(echo "$coverage < 80" | bc -l) )); then
            echo "Coverage $coverage% is below 80% threshold"
            exit 1
          fi
```

### 3. release.yml - Automated Releases

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build-cli:
    strategy:
      matrix:
        include:
          - os: ubuntu-latest
            target: x86_64-unknown-linux-gnu
          - os: macos-latest
            target: x86_64-apple-darwin
          - os: windows-latest
            target: x86_64-pc-windows-msvc
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - name: Build
        run: cargo build --release --bin cli
      - name: Strip binary (Unix)
        if: runner.os != 'Windows'
        run: strip target/release/cli
      - name: Create archive
        run: |
          cd target/release
          tar czf heart-beat-cli-${{ matrix.target }}.tar.gz cli
      - name: Upload to release
        uses: softprops/action-gh-release@v1
        with:
          files: target/release/*.tar.gz

  build-apk:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v3
        with:
          distribution: 'zulu'
          java-version: '17'
      - uses: subosito/flutter-action@v2
      - name: Build Rust library
        run: |
          cd rust
          cargo build --release --lib
      - name: Build APK
        run: flutter build apk --release
      - name: Sign APK
        run: |
          # Use GitHub secrets for signing
          jarsigner -keystore ${{ secrets.KEYSTORE }} \
            -storepass ${{ secrets.KEYSTORE_PASSWORD }} \
            build/app/outputs/flutter-apk/app-release.apk \
            ${{ secrets.KEY_ALIAS }}
      - name: Upload APK
        uses: softprops/action-gh-release@v1
        with:
          files: build/app/outputs/flutter-apk/app-release.apk
```

### 4. benchmark.yml - Performance Tracking

```yaml
name: Benchmark

on:
  pull_request:
    paths:
      - 'rust/src/**'
      - 'rust/benches/**'

jobs:
  benchmark:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: dtolnay/rust-toolchain@stable
      - name: Run benchmarks (main)
        run: |
          git checkout main
          cargo bench --bench latency_bench -- --save-baseline main
      - name: Run benchmarks (PR)
        run: |
          git checkout ${{ github.head_ref }}
          cargo bench --bench latency_bench -- --baseline main
      - name: Comment results
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const results = fs.readFileSync('target/criterion/report/index.html', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Benchmark Results\n\n${results}`
            })
```

## Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

set -e

echo "Running pre-commit checks..."

# Format check
echo "→ Checking code formatting..."
if ! cargo fmt --all -- --check; then
    echo "❌ Code is not formatted. Run: cargo fmt --all"
    exit 1
fi

# Clippy
echo "→ Running clippy..."
if ! cargo clippy --all-targets -- -D warnings; then
    echo "❌ Clippy found issues"
    exit 1
fi

# Fast tests only
echo "→ Running unit tests..."
if ! cargo test --lib --no-fail-fast; then
    echo "❌ Tests failed"
    exit 1
fi

echo "✓ All checks passed"
```

## Benchmark Suite

```rust
// rust/benches/latency_bench.rs
use criterion::{black_box, criterion_group, criterion_main, Criterion};
use heart_beat::{parse_heart_rate, KalmanFilter, FilteredHeartRate};

fn packet_parsing(c: &mut Criterion) {
    let packet = vec![0x16, 140, 0, 0]; // 140 BPM, no RR intervals

    c.bench_function("parse_heart_rate", |b| {
        b.iter(|| parse_heart_rate(black_box(&packet)))
    });
}

fn kalman_filtering(c: &mut Criterion) {
    let mut filter = KalmanFilter::new(0.1, 2.0);

    c.bench_function("kalman_filter_update", |b| {
        b.iter(|| filter.update(black_box(140.0)))
    });
}

fn full_pipeline(c: &mut Criterion) {
    let packet = vec![0x16, 140, 0, 0];
    let mut filter = KalmanFilter::new(0.1, 2.0);

    c.bench_function("full_pipeline", |b| {
        b.iter(|| {
            let hr = parse_heart_rate(black_box(&packet)).unwrap();
            filter.update(hr.bpm as f32)
        })
    });
}

criterion_group!(benches, packet_parsing, kalman_filtering, full_pipeline);
criterion_main!(benches);
```

## Latency Acceptance Test

```rust
// rust/tests/latency_test.rs
use tokio::time::Instant;
use heart_beat::*;

#[tokio::test]
async fn test_p95_latency_under_100ms() {
    let mut latencies = Vec::new();
    let packet = vec![0x16, 140, 0, 0];

    // Run 1000 iterations
    for _ in 0..1000 {
        let start = Instant::now();

        // Full pipeline
        let hr = parse_heart_rate(&packet).unwrap();
        let mut filter = KalmanFilter::new(0.1, 2.0);
        let filtered = filter.update(hr.bpm as f32);
        emit_hr_data(FilteredHeartRate {
            raw_bpm: hr.bpm,
            filtered_bpm: filtered as u16,
            rmssd: None,
            battery_level: None,
            timestamp: std::time::SystemTime::now(),
        });

        let elapsed = start.elapsed();
        latencies.push(elapsed.as_micros());
    }

    latencies.sort();
    let p95_idx = (latencies.len() as f32 * 0.95) as usize;
    let p95 = latencies[p95_idx];

    println!("P50: {}μs", latencies[latencies.len() / 2]);
    println!("P95: {}μs", p95);
    println!("P99: {}μs", latencies[(latencies.len() as f32 * 0.99) as usize]);

    assert!(p95 < 100_000, "P95 latency {}μs exceeds 100ms", p95);
}
```

## Cache Strategy

Aggressive caching for speed:
- Cargo registry and git dependencies
- Cargo build artifacts
- Flutter pub cache
- Criterion baselines

Key: `${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.lock') }}`

## Testing Strategy

### CI Matrix Testing
- Rust: stable, beta
- OS: Linux (primary), macOS, Windows
- Flutter: latest stable

### Flaky Test Handling
- Retry failed tests up to 3 times
- Mark truly flaky tests with `#[ignore]`
- Track flaky test rate in metrics
