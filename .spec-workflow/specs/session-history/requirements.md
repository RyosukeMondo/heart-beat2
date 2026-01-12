# Requirements Document

## Introduction

Session history persists completed workout sessions to local storage, enabling users to review past training data and track progress over time. This supports the product vision of providing training load analysis and session logs.

## Alignment with Product Vision

From product.md: "Session logs exportable for post-training analysis" and future vision includes "Analytics: Long-term HRV trends, training load analysis". Session history is the foundation for these features.

## Requirements

### Requirement 1: Session Recording

**User Story:** As an athlete, I want my workout sessions to be recorded automatically, so that I can review them later.

#### Acceptance Criteria

1. WHEN a training session completes THEN system SHALL persist session data to local storage
2. IF session is interrupted THEN system SHALL save partial session with "interrupted" status
3. WHEN session is saved THEN system SHALL include: start time, end time, plan name, HR samples, phase completions

### Requirement 2: Session Listing

**User Story:** As an athlete, I want to see a list of my past sessions, so that I can track my training consistency.

#### Acceptance Criteria

1. WHEN user opens history screen THEN system SHALL display sessions sorted by date (newest first)
2. IF no sessions exist THEN system SHALL display empty state message
3. WHEN session is listed THEN display SHALL show: date, duration, plan name, avg HR

### Requirement 3: Session Detail View

**User Story:** As an athlete, I want to view details of a past session, so that I can analyze my performance.

#### Acceptance Criteria

1. WHEN user taps a session THEN system SHALL display full session details
2. IF session has HR samples THEN detail view SHALL show min/max/avg HR
3. WHEN viewing detail THEN system SHALL show phase-by-phase breakdown

### Requirement 4: Session Deletion

**User Story:** As an athlete, I want to delete old sessions, so that I can manage my storage.

#### Acceptance Criteria

1. WHEN user selects delete THEN system SHALL show confirmation dialog
2. IF user confirms THEN system SHALL remove session from storage
3. WHEN session is deleted THEN list SHALL update immediately

## Non-Functional Requirements

### Code Architecture and Modularity
- **Single Responsibility Principle**: Session storage separate from session execution
- **Modular Design**: SessionRepository trait with file-based implementation
- **Clear Interfaces**: CRUD operations for sessions

### Performance
- Session list load under 500ms for 100 sessions
- Lazy load HR samples only when viewing detail

### Storage
- JSON format for portability
- Store in app-specific directory (~/.heart-beat/sessions/)
