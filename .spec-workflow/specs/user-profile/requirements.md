# Requirements Document

## Introduction

User profile manages athlete settings including max heart rate, heart rate zones, and preferred units. This enables personalized training zone calculations and session analysis.

## Alignment with Product Vision

From product.md: Zone calculation requires user's max HR for accurate zone determination. The tech.md mentions "Max HR persistence" and settings screen displays "zone information display with color indicators".

## Requirements

### Requirement 1: Max Heart Rate Setting

**User Story:** As an athlete, I want to set my max heart rate, so that my training zones are accurate.

#### Acceptance Criteria

1. WHEN user enters max HR THEN system SHALL validate range (100-220)
2. IF max HR is valid THEN system SHALL persist to local storage
3. WHEN max HR changes THEN zone calculations SHALL use new value immediately

### Requirement 2: Age-Based Max HR Calculation

**User Story:** As an athlete, I want the app to estimate my max HR from my age, so I don't need to know it exactly.

#### Acceptance Criteria

1. WHEN user enters age THEN system SHALL calculate estimated max HR (220 - age)
2. IF using age-based THEN user CAN override with actual max HR
3. WHEN age changes THEN estimated max HR SHALL update

### Requirement 3: Custom Zone Configuration

**User Story:** As an advanced athlete, I want to customize my zone thresholds, so they match my tested values.

#### Acceptance Criteria

1. WHEN user accesses zone settings THEN system SHALL display 5 zones with current thresholds
2. IF user edits zone boundary THEN system SHALL validate (no overlap, ascending order)
3. WHEN zones are saved THEN all zone calculations SHALL use custom values

### Requirement 4: Profile Persistence

**User Story:** As an athlete, I want my settings to persist across app restarts, so I don't need to reconfigure.

#### Acceptance Criteria

1. WHEN app starts THEN system SHALL load saved profile
2. IF no profile exists THEN system SHALL use defaults (max HR 180, standard zones)
3. WHEN profile changes THEN system SHALL save immediately

## Non-Functional Requirements

### Code Architecture and Modularity
- **Single Responsibility Principle**: Profile storage separate from zone calculation
- **Modular Design**: UserProfile domain type, ProfileRepository port
- **Clear Interfaces**: Get/set profile, calculate zones

### Security
- Profile stored locally only, no cloud sync
- No personally identifiable information stored

### Usability
- Default values sensible for most users
- Clear zone visualization in settings
