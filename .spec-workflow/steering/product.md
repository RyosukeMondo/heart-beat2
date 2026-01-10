# Product Overview

## Product Purpose
A deterministic healthcare telemetry system that enables users to perform planned heart rate training using the Coospo HW9 optical heart rate monitor. The system provides real-time biofeedback to help users maintain target heart rate zones during exercise, transforming passive health monitoring into an active training tool with medical-grade reliability.

## Target Users
- **Endurance Athletes**: Runners, cyclists, and triathletes who follow structured heart rate zone training plans
- **Health-Conscious Individuals**: Users seeking guided exercise programs based on physiological metrics
- **Rehabilitation Patients**: Individuals following prescribed cardiac rehabilitation programs requiring precise heart rate control

**Pain Points Addressed**:
- Unreliable heart rate readings during intense exercise (motion artifacts)
- Lack of real-time guidance for maintaining target heart rate zones
- Disconnect between training plans and actual execution
- GC-induced latency in traditional mobile health apps

## Key Features

1. **Real-time Heart Rate Streaming**: Continuous BLE connection to Coospo HW9 with Kalman-filtered signal processing for noise reduction
2. **Planned Training Execution**: Scheduler-driven training sessions with automatic zone transitions (WarmUp → Work → Recovery)
3. **Biofeedback Loop**: Audio/visual notifications when heart rate deviates from target zone
4. **HRV Analysis**: Real-time heart rate variability calculation (RMSSD/SDNN) for fatigue and stress monitoring
5. **Cross-Platform Development**: Linux CLI for rapid debugging, Android app for production use

## Business Objectives

- Deliver sub-100ms latency from sensor event to UI update
- Achieve 60+ minute continuous session reliability without data drops
- Provide Kalman-filtered BPM accuracy within ±5 BPM of ground truth
- Maintain 80%+ test coverage on Rust core logic

## Success Metrics

- **Session Reliability**: 99% of training sessions complete without BLE disconnection requiring user intervention
- **Latency**: P95 latency < 100ms from HR measurement to UI display
- **Accuracy**: Filtered BPM within ±5 BPM compared to reference ECG device
- **Coverage**: Rust core maintains 80%+ code coverage via cargo-tarpaulin

## Product Principles

1. **Determinism First**: All core logic must be predictable and verifiable at compile time through Rust's ownership model
2. **Hardware Abstraction**: Coospo HW9 treated as pure input device; feedback via phone audio/display to avoid reverse engineering
3. **Linux-First Development**: CLI debugging on Linux enables rapid iteration without Android deploy overhead

## Monitoring & Visibility (if applicable)

- **Dashboard Type**: Mobile app (Flutter) with optional developer CLI for debugging
- **Real-time Updates**: StreamSink from Rust core to Flutter via FRB v2; reactive UI with StreamBuilder
- **Key Metrics Displayed**: Current BPM, target zone, session timer, HRV indicators, battery level
- **Sharing Capabilities**: Session logs exportable for post-training analysis

## Future Vision

### Potential Enhancements
- **Remote Access**: Cloud sync for training history and cross-device session continuity
- **Analytics**: Long-term HRV trends, training load analysis, recovery recommendations
- **Collaboration**: Coach/athlete data sharing for remote training supervision
