# Design Document

## Architecture Overview

Flutter application following Material Design 3, consuming Rust core via FRB. Three-screen structure: Home (scan), Session (monitor), Settings (config).

```
Flutter App
├─ main.dart (Entry point)
├─ screens/
│  ├─ home_screen.dart (Device scan)
│  ├─ session_screen.dart (Live HR)
│  └─ settings_screen.dart (Config)
├─ widgets/
│  ├─ hr_display.dart
│  ├─ zone_indicator.dart
│  └─ battery_status.dart
└─ services/
   ├─ permission_service.dart
   └─ background_service.dart
```

## Screen Designs

### HomeScreen
```dart
class HomeScreen extends StatefulWidget {
  State: idle | scanning | error

  UI:
  - AppBar("Heart Beat")
  - Center:
    - If idle: ElevatedButton("Scan for Devices")
    - If scanning: CircularProgressIndicator + "Scanning..."
    - If error: Text(error) + ElevatedButton("Retry")
  - ListView<DiscoveredDevice>:
    - ListTile(
        leading: Icon(Icons.bluetooth),
        title: device.name ?? "Unknown",
        subtitle: "RSSI: ${device.rssi}",
        onTap: navigate to SessionScreen(device.id)
      )
}
```

### SessionScreen
```dart
class SessionScreen extends StatefulWidget {
  final String deviceId;

  State: connecting | connected | streaming | error

  UI:
  - AppBar(deviceId, actions: [disconnect button])
  - If connecting: Center(CircularProgressIndicator)
  - If connected:
    - StreamBuilder<FilteredHeartRate>(
        stream: api.createHrStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Loading();

          return Column(
            children: [
              HrDisplay(bpm: snapshot.data.filteredBpm),
              ZoneIndicator(zone: calculateZone(snapshot.data.filteredBpm)),
              BatteryStatus(level: snapshot.data.batteryLevel),
              Spacer(),
              FloatingActionButton.extended(
                label: "Start Workout",
                icon: Icon(Icons.play_arrow),
                onPressed: () => startWorkout(),
              ),
            ],
          );
        }
      )
}
```

### SettingsScreen
```dart
class SettingsScreen extends StatefulWidget {
  State: max_hr (int)

  UI:
  - AppBar("Settings")
  - Form:
    - TextFormField(
        label: "Max Heart Rate",
        initialValue: loadMaxHr(),
        keyboardType: TextInputType.number,
        validator: (v) => validateRange(v, 100, 220),
        onSaved: (v) => saveMaxHr(v),
      )
    - ElevatedButton("Save")
}
```

## Widget Designs

### HrDisplay
```dart
class HrDisplay extends StatelessWidget {
  final int bpm;

  Widget build(context) {
    return Column(
      children: [
        Text(
          "$bpm",
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            fontSize: 72,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text("BPM", style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}
```

### ZoneIndicator
```dart
class ZoneIndicator extends StatelessWidget {
  final Zone? zone;

  Color getZoneColor(Zone? zone) {
    return switch (zone) {
      Zone.Zone1 => Colors.blue,
      Zone.Zone2 => Colors.green,
      Zone.Zone3 => Colors.yellow,
      Zone.Zone4 => Colors.orange,
      Zone.Zone5 => Colors.red,
      null => Colors.grey,
    };
  }

  Widget build(context) {
    return Container(
      width: 300,
      height: 40,
      decoration: BoxDecoration(
        color: getZoneColor(zone),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          zone?.name ?? "Below Zone 1",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
```

## Service Designs

### PermissionService
```dart
class PermissionService {
  Future<bool> requestBluetoothPermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      if (androidInfo.version.sdkInt >= 31) {
        // Android 12+
        final status = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();

        return status.values.every((s) => s.isGranted);
      } else {
        // Android < 12
        final status = await [
          Permission.bluetooth,
          Permission.location,
        ].request();

        return status.values.every((s) => s.isGranted);
      }
    }

    return true; // iOS handles automatically
  }
}
```

### BackgroundService
```dart
class BackgroundService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'heart_beat_channel',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(),
    );
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    if (service is AndroidServiceInstance) {
      service.on('stopService').listen((event) {
        service.stopSelf();
      });
    }

    service.on('updateBpm').listen((event) {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Heart Rate Monitor",
          content: "Current: ${event!['bpm']} BPM",
        );
      }
    });
  }

  Future<void> startService() async {
    final service = FlutterBackgroundService();
    await service.startService();
  }

  Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }
}
```

## State Management

Using StatefulWidget with setState for simplicity. Stream-based reactivity via StreamBuilder for HR data.

### Why Not Provider/Riverpod?
- Single-screen data flow (no complex state sharing)
- StreamBuilder handles reactive updates naturally
- Keeps dependencies minimal

## Navigation

Simple named routes:
```dart
MaterialApp(
  routes: {
    '/': (context) => HomeScreen(),
    '/session': (context) => SessionScreen(
      deviceId: ModalRoute.of(context)!.settings.arguments as String,
    ),
    '/settings': (context) => SettingsScreen(),
  },
)
```

## Error Handling

All Rust errors converted to Dart exceptions via FRB. Caught in try-catch and displayed via SnackBar or AlertDialog.

```dart
try {
  await api.connectDevice(deviceId);
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text("Connection failed: $e")),
  );
}
```

## Testing Strategy

### Widget Tests
- HomeScreen scan button triggers permission request
- SessionScreen displays StreamBuilder data
- SettingsScreen form validation

### Integration Tests (Patrol)
- Full flow: launch → scan → connect → verify HR display
- Permission dialog handling
- Background service notification
