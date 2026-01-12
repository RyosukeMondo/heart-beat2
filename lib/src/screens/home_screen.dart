import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../bridge/api_generated.dart/api.dart';
import '../bridge/api_generated.dart/domain/heart_rate.dart';

/// Home screen for device scanning and selection
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<DiscoveredDevice> _devices = [];
  bool _isScanning = false;
  String? _error;

  Future<void> _scanForDevices() async {
    setState(() {
      _isScanning = true;
      _error = null;
      _devices = [];
    });

    try {
      // Request Bluetooth permissions
      final bluetoothScan = await Permission.bluetoothScan.request();
      final bluetoothConnect = await Permission.bluetoothConnect.request();
      final location = await Permission.locationWhenInUse.request();

      if (!bluetoothScan.isGranted ||
          !bluetoothConnect.isGranted ||
          !location.isGranted) {
        if (!mounted) return;
        setState(() {
          _error = 'Bluetooth permissions are required';
          _isScanning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth permissions denied. Please enable them in settings.'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Scan for devices
      final devices = await scanDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _isScanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Scan failed: $e';
        _isScanning = false;
      });
    }
  }

  void _connectToDevice(DiscoveredDevice device) {
    Navigator.pushNamed(
      context,
      '/session',
      arguments: {'device_id': device.id, 'device_name': device.name},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('homeScreen'),
      appBar: AppBar(
        title: const Text('Heart Beat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.pushNamed(context, '/history');
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isScanning ? null : _scanForDevices,
                icon: _isScanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bluetooth_searching),
                label: Text(_isScanning ? 'Scanning...' : 'Scan for Devices'),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Text(
                      _isScanning
                          ? 'Scanning for heart rate monitors...'
                          : 'Tap "Scan for Devices" to find heart rate monitors',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return ListTile(
                        leading: const Icon(Icons.favorite),
                        title: Text(device.name ?? 'Unknown Device'),
                        subtitle: Text('RSSI: ${device.rssi} dBm'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => _connectToDevice(device),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
