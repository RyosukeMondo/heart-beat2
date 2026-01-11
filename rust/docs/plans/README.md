# Training Plan Templates

This directory contains ready-to-use training plan templates in JSON format. Each plan is designed for specific training goals and can be loaded directly by the Heart Beat CLI or mobile app.

## Available Plans

### beginner-base-building.json
**Purpose:** Build aerobic base fitness for beginner runners  
**Duration:** 40 minutes  
**Target Athlete:** New runners or those returning after a break  
**Intensity:** Low (Zone 1-2)  

**Description:**  
A gentle 40-minute workout focused on building aerobic capacity without overexertion. Perfect for establishing a training routine or active recovery between harder workouts.

**Phases:**
1. Warmup (5 min, Zone 1) - Easy walking/jogging to prepare body
2. Easy Aerobic (30 min, Zone 2) - Comfortable conversational pace
3. Cooldown (5 min, Zone 1) - Gradual return to resting state

**How to use:**
```bash
# CLI
heart-beat session start --plan docs/plans/beginner-base-building.json

# Or copy and customize
cp docs/plans/beginner-base-building.json my-custom-plan.json
# Edit my-custom-plan.json with your preferred max_hr
heart-beat session start --plan my-custom-plan.json
```

---

### 5k-training.json
**Purpose:** Improve 5K race performance through intervals and tempo work  
**Duration:** 42 minutes  
**Target Athlete:** Intermediate runners training for 5K races  
**Intensity:** Moderate to High (Zone 2-4)  

**Description:**  
Classic interval workout combining three hard 3-minute efforts with recovery periods, followed by a 10-minute tempo run. Builds speed, lactate threshold, and mental toughness for 5K racing.

**Phases:**
1. Warmup (10 min, Zone 2) - Prepare for high-intensity work
2. 3× Intervals (3 min hard Zone 4 + 2 min recovery Zone 2)
3. Tempo Run (10 min, Zone 3) - Sustained hard effort
4. Cooldown (5 min, Zone 1) - Recovery

**Training Notes:**
- Run intervals on track or flat road for best results
- Aim for consistent pacing across all three intervals
- Tempo section should feel "comfortably hard"
- Allow 48 hours recovery before next hard workout

---

### marathon-pace.json
**Purpose:** Practice sustained marathon race pace  
**Duration:** 70 minutes  
**Target Athlete:** Experienced runners training for half/full marathons  
**Intensity:** Moderate (Zone 2-3)  

**Description:**  
Long Zone 3 run split into three 20-minute segments to simulate marathon pacing. Teaches body to sustain aerobic effort and helps dial in race-day nutrition and hydration strategies.

**Phases:**
1. Warmup (10 min, Zone 2)
2. Marathon Pace - Part 1 (20 min, Zone 3)
3. Marathon Pace - Part 2 (20 min, Zone 3)  
4. Marathon Pace - Part 3 (20 min, Zone 3)
5. Cooldown (10 min, Zone 2)

**Training Notes:**
- Practice race-day fueling during this workout
- Focus on maintaining even effort across all three segments
- HR should remain steady in Zone 3 throughout
- If HR drifts into Zone 4, slow down slightly

---

### recovery-run.json
**Purpose:** Active recovery between hard training sessions  
**Duration:** 40 minutes  
**Target Athlete:** All levels (day after hard workout or race)  
**Intensity:** Very Low (Zone 1-2)  

**Description:**  
Easy recovery run to promote blood flow and facilitate muscle repair without adding training stress. Should feel almost effortless throughout.

**Phases:**
1. Easy Start (10 min, Zone 1) - Very gentle warmup
2. Light Aerobic (20 min, Zone 2) - Comfortable, conversational pace
3. Easy Finish (10 min, Zone 1) - Wind down

**Training Notes:**
- If you can't hold a conversation, you're going too hard
- Purpose is recovery, not fitness gains
- Skip if feeling fatigued or injured
- Can be replaced with cross-training (swimming, cycling)

---

## Customizing Plans

All plans use the JSON format expected by the Heart Beat library. To customize:

### Adjusting Max Heart Rate

Update the `max_hr` field with your personal maximum:

```json
{
  "name": "My Custom Plan",
  "max_hr": 185,  ← Change this to your max HR
  ...
}
```

**Finding Your Max HR:**
- **Formula:** 220 - age (rough estimate)
- **Lab Test:** Most accurate, requires professional testing
- **Field Test:** All-out 3-5 minute effort after warmup
- **Smart Watch:** Review historical data for highest recorded HR

### Adjusting Duration

Modify `duration_secs` for any phase:

```json
{
  "name": "Warmup",
  "target_zone": "Zone2",
  "duration_secs": 600,  ← 600 seconds = 10 minutes
  "transition": "TimeElapsed"
}
```

### Heart Rate Zones

The system uses 5-zone model based on % of max HR:

| Zone | % Max HR | Effort Level | Purpose |
|------|----------|--------------|---------|
| Zone1 | 50-60% | Very Light | Recovery, warmup |
| Zone2 | 60-70% | Light | Base endurance, fat burning |
| Zone3 | 70-80% | Moderate | Tempo, marathon pace |
| Zone4 | 80-90% | Hard | Lactate threshold, 5K-10K pace |
| Zone5 | 90-100% | Maximum | VO2 max, sprints |

Available values for `target_zone`:
- `"Zone1"`
- `"Zone2"`
- `"Zone3"`
- `"Zone4"`
- `"Zone5"`

### Advanced: Heart Rate Reached Transition

Instead of time-based transitions, you can wait for specific HR:

```json
{
  "name": "Build to Threshold",
  "target_zone": "Zone4",
  "duration_secs": 600,
  "transition": {
    "HeartRateReached": {
      "target_bpm": 165,
      "hold_secs": 30
    }
  }
}
```

This phase waits for HR to reach 165 BPM and hold for 30 seconds before advancing.

---

## Loading Plans

### CLI Usage

```bash
# Start a session with a template
heart-beat session start --plan docs/plans/5k-training.json --device <device-id>

# View plan details
heart-beat plan show --file docs/plans/marathon-pace.json

# Validate a plan
heart-beat plan validate --file docs/plans/beginner-base-building.json
```

### Programmatic Usage

```rust
use heart_beat::domain::training_plan::TrainingPlan;
use std::fs;

let plan_json = fs::read_to_string("docs/plans/5k-training.json")?;
let plan: TrainingPlan = serde_json::from_str(&plan_json)?;

// Validate before use
plan.validate()?;
```

---

## Safety Guidelines

⚠️ **Important Safety Notes:**

1. **Consult a physician** before starting any training program, especially if:
   - You have cardiovascular issues
   - You're over 40 and new to exercise
   - You have any chronic health conditions

2. **Listen to your body:**
   - Chest pain, dizziness, or unusual shortness of breath = STOP
   - Skip workouts when sick or injured
   - HR zones are guidelines, not absolute rules

3. **Progression:**
   - Start with easier plans (recovery, base building)
   - Master Zone 2 before attempting Zone 4-5 workouts
   - Increase volume/intensity gradually (10% per week)

4. **Recovery:**
   - Hard workouts require 48 hours recovery
   - Include at least one rest day per week
   - Sleep 7-9 hours for optimal adaptation

---

## Contributing Plans

Have a great training plan to share? Submit a pull request!

**Guidelines:**
- Total duration < 4 hours (library limit)
- All phases have clear names
- Target zones are physiologically appropriate
- Include description in this README
- Test the plan yourself first

---

For more information, see:
- [User Guide](../user-guide.md) - End-user documentation
- [API Examples](../api-examples.md) - Programmatic usage
- [Development Guide](../development.md) - Contributing to the project
