# Requirements Document

## Introduction

Data export enables users to export their training session data for analysis in external tools, spreadsheets, or sharing with coaches. This supports the product vision of "Session logs exportable for post-training analysis".

## Alignment with Product Vision

From product.md: "Session logs exportable for post-training analysis" and future vision includes "Collaboration: Coach/athlete data sharing for remote training supervision".

## Requirements

### Requirement 1: Export Session to CSV

**User Story:** As an athlete, I want to export my session data to CSV, so that I can analyze it in Excel or other tools.

#### Acceptance Criteria

1. WHEN user taps "Export" on session detail THEN system SHALL generate CSV file
2. IF CSV is generated THEN file SHALL contain: timestamp, bpm, zone, phase columns
3. WHEN CSV is ready THEN system SHALL trigger share sheet for saving/sharing

### Requirement 2: Export Session to JSON

**User Story:** As a developer/coach, I want to export session data to JSON, so that I can process it programmatically.

#### Acceptance Criteria

1. WHEN user selects JSON export THEN system SHALL generate complete session JSON
2. IF exported THEN JSON SHALL include all session metadata and HR samples
3. WHEN JSON is ready THEN system SHALL offer share/save options

### Requirement 3: Export Summary Report

**User Story:** As an athlete, I want a readable summary report, so that I can share my workout with others.

#### Acceptance Criteria

1. WHEN user taps "Share Summary" THEN system SHALL generate text summary
2. IF summary is generated THEN it SHALL include: date, duration, plan, avg/max HR, zones
3. WHEN summary is ready THEN system SHALL open share sheet

### Requirement 4: Batch Export

**User Story:** As an athlete, I want to export multiple sessions at once, so that I can backup my training data.

#### Acceptance Criteria

1. WHEN user selects multiple sessions THEN "Export All" SHALL be available
2. IF batch export THEN system SHALL create ZIP archive with all sessions
3. WHEN archive is ready THEN system SHALL offer download/share

## Non-Functional Requirements

### Code Architecture and Modularity
- **Single Responsibility Principle**: Each export format has own formatter
- **Modular Design**: ExportService with format-specific implementations
- **Clear Interfaces**: ExportFormat enum, export(session, format) function

### Performance
- Export generation under 2 seconds for single session
- Batch export shows progress indicator

### Compatibility
- CSV readable by Excel, Google Sheets
- JSON valid per JSON specification
