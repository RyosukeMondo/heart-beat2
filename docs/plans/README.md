# Training Plan Templates

This directory contains ready-to-use training plan templates. Copy and modify these JSON files to create your own workouts.

## Available Plans

### 1. Beginner Base Building (`beginner-base-building.json`)

**Purpose:** Build aerobic base fitness for new runners or during recovery periods

**Target Athlete:** Beginners or returning athletes

**Structure:**
- 10-minute warmup (Zone 1)
- 30-minute easy aerobic work (Zone 2)
- 5-minute cooldown (Zone 1)

**Total Duration:** 45 minutes

**How to Use:**
```bash
heart-beat-cli session run --plan docs/plans/beginner-base-building.json
```

**Training Notes:**
- Perform 3-4 times per week
- Zone 2 should feel conversational - slow down if needed
- Focus on consistency over speed
- Build duration gradually (add 5-10 minutes weekly)

---

### 2. 5K Interval Training (`5k-training.json`)

**Purpose:** Improve speed and lactate threshold for 5K race performance

**Target Athlete:** Intermediate runners training for 5K races

**Structure:**
- 10-minute warmup (Zone 2)
- 4 × 5-minute work intervals (Zone 4)
- 3-minute recovery between intervals (Zone 2)
- 10-minute cooldown (Zone 1)

**Total Duration:** 52 minutes

**How to Use:**
```bash
heart-beat-cli session run --plan docs/plans/5k-training.json
```

**Training Notes:**
- Perform once per week during race prep
- Work intervals should feel "hard but sustainable"
- Focus on maintaining steady HR in Zone 4
- Take an extra recovery day after this workout
- Can adjust work/rest ratio: beginners use 1:1, advanced use 2:1 or 3:1

---

### 3. Marathon Pace Training (`marathon-pace.json`)

**Purpose:** Build endurance at marathon race pace (Zone 3)

**Target Athlete:** Marathon runners developing race-specific fitness

**Structure:**
- 15-minute warmup (Zone 2)
- 20-minute marathon pace block 1 (Zone 3)
- 5-minute recovery jog (Zone 2)
- 20-minute marathon pace block 2 (Zone 3)
- 10-minute cooldown (Zone 1)

**Total Duration:** 70 minutes

**How to Use:**
```bash
heart-beat-cli session run --plan docs/plans/marathon-pace.json
```

**Training Notes:**
- Perform every 1-2 weeks during marathon training
- Zone 3 is "comfortably hard" - sustainable for 60+ minutes
- This should feel like goal marathon pace
- Gradually increase block durations (up to 30-40 minutes each)
- Follow with easy recovery day

---

### 4. Easy Recovery Run (`recovery-run.json`)

**Purpose:** Active recovery to promote blood flow without adding training stress

**Target Athlete:** All levels, especially after hard workouts or races

**Structure:**
- 10-minute gentle start (Zone 1) with HR-based transition
- 20-minute easy aerobic (Zone 2)
- 5-minute cooldown (Zone 1)

**Total Duration:** 35 minutes

**How to Use:**
```bash
heart-beat-cli session run --plan docs/plans/recovery-run.json
```

**Training Notes:**
- Perform 1-2 days after hard workouts
- Should feel extremely easy - slower than you think!
- Uses HR-based transition to ensure proper warmup
- Don't skip these - recovery runs enable harder training
- If you can't stay in Zone 1-2, take a rest day instead

---

## Customizing Plans

### Adjusting for Your Max HR

All templates use `max_hr: 180` as a placeholder. Update this to your actual max HR:

```json
{
  "name": "Your Workout",
  "max_hr": 185,  ← Change this to your max HR
  "created_at": "2024-01-10T12:00:00Z",
  "phases": [...]
}
```

### Adding Phases

Copy and paste phase blocks to create longer workouts:

```json
{
  "name": "Extended Intervals",
  "target_zone": "Zone4",
  "duration_secs": 300,
  "transition": "TimeElapsed"
}
```

### Transition Types

**Time-based** (most common):
```json
"transition": "TimeElapsed"
```

**HR-based** (for warmups):
```json
"transition": {
  "HeartRateReached": {
    "target_bpm": 120,
    "hold_secs": 30
  }
}
```

### Duration Conversion

Quick reference for `duration_secs`:

| Minutes | Seconds |
|---------|---------|
| 5 min   | 300     |
| 10 min  | 600     |
| 15 min  | 900     |
| 20 min  | 1200    |
| 30 min  | 1800    |
| 45 min  | 2700    |
| 60 min  | 3600    |

---

## Training Principles

### Weekly Structure Example

**Monday:** Recovery run (30 min Zone 1-2)
**Tuesday:** Intervals (5K training plan)
**Wednesday:** Easy run (45 min Zone 2)
**Thursday:** Rest or recovery run (30 min Zone 1)
**Friday:** Tempo run (marathon pace plan)
**Saturday:** Long run (60-90 min Zone 2)
**Sunday:** Rest

### Polarized Training

For optimal results, follow the 80/20 rule:
- **80% of training** in Zone 1-2 (easy/recovery)
- **20% of training** in Zone 4-5 (hard intervals)
- **Avoid Zone 3** except for race-specific work

### Progression Guidelines

1. **First 4 weeks:** Base building, all Zone 1-2
2. **Weeks 5-8:** Add one interval session per week
3. **Weeks 9-12:** Add tempo work, maintain intervals
4. **Week 13:** Recovery week (50% volume, all Zone 1-2)
5. **Repeat cycle** with increased durations

---

## Creating Your Own Plans

Use the CLI interactive creator:

```bash
heart-beat-cli plan create
```

Or copy a template and modify it:

```bash
cp docs/plans/beginner-base-building.json my-custom-plan.json
# Edit my-custom-plan.json with your preferred text editor
heart-beat-cli plan validate my-custom-plan.json
```

---

## Safety Guidelines

⚠️ **Important:**
- Always include warmup and cooldown phases
- Zone 5 workouts should be short (< 5 minutes total)
- Recovery runs are training, not junk miles
- If you can't complete a workout, stop and recover
- Consult a doctor before starting intense training

**Signs to stop immediately:**
- Chest pain or pressure
- Dizziness or lightheadedness
- Unusual shortness of breath
- Irregular heart rhythm

---

## Further Resources

- **User Guide:** `docs/user-guide.md` - Complete training zone guide
- **API Examples:** `docs/api-examples.md` - Create plans programmatically
- **Development Guide:** `docs/development.md` - Build custom tools

Happy training! 🏃‍♂️
