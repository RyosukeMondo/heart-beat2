# Heart Beat User Guide

Welcome to Heart Beat - your intelligent training companion for heart rate zone-based workouts using the Coospo HW9 heart rate monitor!

## Table of Contents

1. [Understanding Heart Rate Zones](#understanding-heart-rate-zones)
2. [Calculating Your Maximum Heart Rate](#calculating-your-maximum-heart-rate)
3. [Creating Training Plans](#creating-training-plans)
4. [CLI Guide](#cli-guide)
5. [Mobile App Guide](#mobile-app-guide)
6. [Training Tips](#training-tips)
7. [Glossary](#glossary)

---

## Understanding Heart Rate Zones

Heart rate zones are ranges of heartbeats per minute (BPM) that correspond to different training intensities. Training in specific zones helps you achieve different fitness goals.

### The Five Training Zones

Heart Beat uses a 5-zone system based on your maximum heart rate:

| Zone | % of Max HR | Intensity | Feel | Purpose | Example Activities |
|------|-------------|-----------|------|---------|-------------------|
| **Zone 1** | 50-60% | Very Light | Easy conversation, breathing normal | Recovery, warm-up | Easy walk, cool-down |
| **Zone 2** | 60-70% | Light | Can talk comfortably | Base fitness, fat burning | Easy run, long bike ride |
| **Zone 3** | 70-80% | Moderate | Can talk in short sentences | Aerobic endurance | Tempo run, sustained effort |
| **Zone 4** | 80-90% | Hard | Difficult to talk | Lactate threshold, speed | Interval training, hill repeats |
| **Zone 5** | 90-100% | Maximum | Can't talk, breathing hard | Maximum effort, power | Sprint intervals, race finish |

### Training Benefits by Zone

**Zone 1 (Recovery)**
- Promotes blood flow for recovery
- Develops basic endurance
- Safe for daily training
- *Example: 30-minute easy walk after hard workout*

**Zone 2 (Endurance)**
- Builds aerobic base
- Improves fat metabolism
- Foundation for all training
- *Example: 60-minute easy run at conversational pace*

**Zone 3 (Tempo)**
- Increases aerobic capacity
- Improves efficiency
- Moderately challenging
- *Example: 20-minute sustained effort at "comfortably hard" pace*

**Zone 4 (Threshold)**
- Raises lactate threshold
- Improves speed endurance
- High training stimulus
- *Example: 5x5 minutes at hard effort with 2-minute recovery*

**Zone 5 (VO2 Max)**
- Maximal oxygen uptake
- Increases top-end speed
- Very high stress - use sparingly
- *Example: 8x400m sprints with full recovery*

---

## Calculating Your Maximum Heart Rate

Your maximum heart rate (max HR) is the highest number of beats per minute your heart can achieve during all-out effort.

### Quick Estimate (Age-Based)

The simplest formula:

```
Max HR = 220 - Your Age
```

**Example:** A 30-year-old person would have an estimated max HR of 190 BPM.

### More Accurate Formulas

**Tanaka Formula** (slightly more accurate):
```
Max HR = 208 - (0.7 × Your Age)
```

**Example:** 208 - (0.7 × 30) = 187 BPM

### Field Test (Most Accurate)

For the best results, perform a field test:

1. **Warm up** for 15 minutes in Zone 2
2. **Run or cycle at increasing intensity** for 3 minutes
3. **Sprint all-out** for 1 minute
4. **Record your highest HR** during the sprint
5. **Cool down** for 10 minutes in Zone 1

⚠️ **Important:** Only perform field tests if you're healthy and cleared for intense exercise. Consider consulting a doctor first.

### Zone Calculation Examples

Once you have your max HR, calculate your zones:

**Example: Max HR = 180 BPM**

| Zone | Calculation | BPM Range |
|------|-------------|-----------|
| Zone 1 | 180 × 0.50 to 180 × 0.60 | 90-108 BPM |
| Zone 2 | 180 × 0.60 to 180 × 0.70 | 108-126 BPM |
| Zone 3 | 180 × 0.70 to 180 × 0.80 | 126-144 BPM |
| Zone 4 | 180 × 0.80 to 180 × 0.90 | 144-162 BPM |
| Zone 5 | 180 × 0.90 to 180 × 1.00 | 162-180 BPM |

---

## Creating Training Plans

Training plans define structured workouts with multiple phases. Each phase has a target zone and duration.

### JSON Format

Training plans are defined in JSON format:

```json
{
  "name": "Easy Recovery Run",
  "max_hr": 180,
  "created_at": "2024-01-10T12:00:00Z",
  "phases": [
    {
      "name": "Warmup",
      "target_zone": "Zone1",
      "duration_secs": 600,
      "transition": "TimeElapsed"
    },
    {
      "name": "Main Set",
      "target_zone": "Zone2",
      "duration_secs": 1800,
      "transition": "TimeElapsed"
    },
    {
      "name": "Cooldown",
      "target_zone": "Zone1",
      "duration_secs": 300,
      "transition": "TimeElapsed"
    }
  ]
}
```

### Plan Components

**Required Fields:**
- `name` - Descriptive name for the workout
- `max_hr` - Your maximum heart rate (used for zone calculations)
- `created_at` - ISO 8601 timestamp
- `phases` - Array of training phases

**Phase Fields:**
- `name` - Phase name (e.g., "Warmup", "Work", "Recovery")
- `target_zone` - One of: Zone1, Zone2, Zone3, Zone4, Zone5
- `duration_secs` - Expected duration in seconds
- `transition` - How to move to next phase (see below)

### Transition Types

**TimeElapsed** - Automatically advance after duration:
```json
{
  "transition": "TimeElapsed"
}
```

**HeartRateReached** - Advance when HR target is held:
```json
{
  "transition": {
    "HeartRateReached": {
      "target_bpm": 120,
      "hold_secs": 30
    }
  }
}
```
*Useful for warmups - only advance when you're actually warmed up!*

### Example Plans

See the `docs/plans/` directory for ready-to-use training plans:

- `beginner-base-building.json` - 3×30 minutes in Zone 2
- `5k-training.json` - Intervals and tempo work
- `marathon-pace.json` - Long Zone 3 efforts
- `recovery-run.json` - Easy Zone 1-2 recovery

You can copy and modify these templates for your own training.

---

## CLI Guide

The command-line interface provides full control over Heart Beat for testing and development.

### Prerequisites

- Rust 1.75 or later installed
- Coospo HW9 heart rate monitor
- Linux system with Bluetooth support

### Building the CLI

```bash
# Build the CLI
cargo build --release

# The binary is at: target/release/cli
```

### Available Commands

All commands support verbose logging with the `-v` or `--verbose` flag.

#### Device Management (`devices` command)

**Scan for nearby devices:**
```bash
cargo run --bin cli -- devices scan
```

**Connect to a device:**
```bash
cargo run --bin cli -- devices connect <MAC_ADDRESS>
```

**Show connected device info:**
```bash
cargo run --bin cli -- devices info
```

**Disconnect from current device:**
```bash
cargo run --bin cli -- devices disconnect
```

#### Training Sessions (`session` command)

**Start a training session:**
```bash
cargo run --bin cli -- session start --plan path/to/plan.json --device <MAC_ADDRESS>
```

The session display shows:
- Current phase name and target zone
- Real-time heart rate and zone status
- Phase timer (elapsed/remaining)
- Audio/visual alerts when out of zone

**Pause the active session:**
```bash
cargo run --bin cli -- session pause
```

**Resume a paused session:**
```bash
cargo run --bin cli -- session resume
```

**Stop session and show summary:**
```bash
cargo run --bin cli -- session stop
```

Session summary includes:
- Total duration and phases completed
- Average heart rate per phase
- Time spent in each zone
- Overall zone accuracy percentage

#### Mock Data Testing (`mock` command)

Generate simulated heart rate data for testing without hardware:

```bash
cargo run --bin cli -- mock --plan path/to/plan.json
```

This simulates realistic heart rate transitions based on your training plan's target zones.

#### Training Plan Management (`plan` command)

**List all saved plans:**
```bash
cargo run --bin cli -- plan list
```

**Show plan details:**
```bash
cargo run --bin cli -- plan show path/to/plan.json
```

**Validate a plan file:**
```bash
cargo run --bin cli -- plan validate path/to/plan.json
```

Checks for:
- Valid JSON format
- Required fields present
- Duration > 0 for all phases
- Total duration < 4 hours
- Valid zone names and heart rate targets

**Create a new plan interactively:**
```bash
cargo run --bin cli -- plan create
```

The interactive creator guides you through:
1. Plan name and max HR
2. Adding phases (name, zone, duration)
3. Choosing transition conditions
4. Saving to a JSON file

---

## Mobile App Guide

The Heart Beat mobile app provides a user-friendly interface for Android devices.

### Installation

1. Download the APK from the releases page
2. Enable "Install from unknown sources" if needed
3. Install the APK
4. Grant Bluetooth and Location permissions when prompted

### First Time Setup

1. **Open the app** - You'll see the home screen
2. **Tap "Scan Devices"** - The app searches for heart rate monitors
3. **Select your device** - Tap your HR monitor from the list
4. **Grant permissions** - Allow Bluetooth and location access
5. **Connect** - Tap "Connect" to pair with your device

### Running a Workout

1. **Select a training plan** - Choose from presets or create custom
2. **Review the plan** - Check phases and target zones
3. **Start the session** - Tap "Start Workout"
4. **Monitor your progress** - Watch real-time HR and zone feedback
5. **Complete or stop** - Session ends automatically or tap "Stop"

### Biofeedback Alerts

The app provides instant feedback when your heart rate deviates from the target zone:

**Visual Alerts:**
- 🟢 Green - You're in the target zone
- 🟡 Yellow - Slightly out of zone (±5 BPM)
- 🔴 Red - Significantly out of zone (>5 BPM)

**Audio Alerts:**
- Gentle beep when exiting zone
- Different tones for "speed up" vs "slow down"

**Vibration:**
- Short vibration when zone deviation occurs
- Helps during outdoor training when screen isn't visible

### Creating Custom Plans

1. **Tap "Plans" tab**
2. **Tap "+" to create new**
3. **Enter plan details:**
   - Name your workout
   - Add phases one by one
   - Set target zone and duration for each phase
   - Choose transition type
4. **Save the plan**
5. **Run it from the Plans list**

### Session History

View your completed workouts:

1. **Tap "History" tab**
2. **Select a session** to view details:
   - Duration and completion status
   - Average heart rate by phase
   - Time in each zone
   - Zone deviation events

### Settings

Configure the app to your preferences:

- **Max Heart Rate** - Update your max HR for accurate zones
- **Audio Alerts** - Enable/disable sound notifications
- **Vibration** - Toggle vibration feedback
- **Background Service** - Keep session running when screen is off
- **Auto-pause** - Pause session when HR sensor disconnects

---

## Glossary

**BLE (Bluetooth Low Energy)** - Wireless technology used by heart rate monitors to communicate with phones and computers.

**BPM (Beats Per Minute)** - Measurement of heart rate; how many times your heart beats in one minute.

**Heart Rate Zone** - A range of heart rates that corresponds to a specific training intensity.

**HRV (Heart Rate Variability)** - Variation in time between heartbeats; used to assess recovery and training readiness.

**Kalman Filter** - Mathematical algorithm that smooths heart rate data to remove noise and artifacts.

**Lactate Threshold** - The intensity at which lactate begins to accumulate in the blood; typically around Zone 4.

**Max HR (Maximum Heart Rate)** - The highest heart rate you can achieve during maximum physical exertion.

**Phase** - A single segment of a training plan with a specific target zone and duration.

**Session** - A complete workout consisting of one or more phases.

**Tempo Run** - Sustained effort at Zone 3 intensity; comfortably hard pace you can hold for 20-60 minutes.

**Threshold Training** - High-intensity work in Zone 4 to improve lactate clearance and speed endurance.

**Training Plan** - A structured workout with defined phases, zones, and transitions.

**Transition Condition** - Rule that determines when to move from one phase to the next.

**VO2 Max** - Maximum rate of oxygen consumption; improved through Zone 5 training.

**Warmup** - Initial phase of easy activity (typically Zone 1-2) to prepare the body for harder work.

---

## Tips for Effective Training

### For Beginners

1. **Start in Zone 2** - Build your base before adding intensity
2. **Don't skip warmup** - 10-15 minutes in Zone 1-2 prevents injury
3. **Listen to your body** - Zones are guidelines, not absolute rules
4. **Consistency over intensity** - Regular Zone 2 work beats sporadic hard efforts

### For Experienced Athletes

1. **Polarized training** - 80% Zone 2, 20% Zone 4-5 for optimal results
2. **Respect recovery** - Zone 1 days are productive, not wasted
3. **Track HRV** - Use heart rate variability to guide training intensity
4. **Periodize** - Alternate hard weeks with recovery weeks

### Common Mistakes to Avoid

❌ **Training too hard too often** - Most runs should be Zone 2
❌ **Ignoring warmup** - Jumping straight to Zone 4 risks injury
❌ **No easy days** - Zone 3 "junk miles" prevent recovery
❌ **Using estimated max HR without testing** - Individual variation is huge
❌ **Chasing others' zones** - Your Zone 2 is personal to you

### Troubleshooting

**HR monitor shows erratic readings:**
- Moisten the sensor strap
- Ensure tight contact with skin
- Check battery level
- Move away from electrical interference

**Can't reach target zone:**
- You may need a fitness test to update max HR
- Check if you're fatigued or need recovery
- Verify zone calculation is correct
- Consider environmental factors (heat, altitude)

**Constantly above target zone:**
- Slow down! Zone 2 should feel easy
- Check that max HR is accurate
- You might be more fit than you think

---

## Support and Resources

- **Documentation:** See `docs/` directory for technical details
- **Training Plans:** Browse `docs/plans/` for workout templates
- **Issue Tracker:** Report bugs on GitHub
- **Community:** Join discussions in GitHub Discussions

Happy training! 🏃‍♂️💪
