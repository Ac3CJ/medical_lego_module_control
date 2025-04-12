import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'module_type.dart';

class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  // Filter for specific device names or service UUIDs
  final List<String> _targetDevicePrefixes = ['TMP-', 'IR-', 'VBR-', 'CJ02-'];
  final List<Guid> _targetServiceUuids = [
    Guid('0000180a-0000-1000-8000-00805f9b34fb'), // Common device info service
    Guid('FFF6'), // Common Matter service
  ];

  Stream<BluetoothDevice> startScan(BuildContext context) {
    // Request permissions
    _requestPermissions();

    // Start scanning
    FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 20),
      withServices: _targetServiceUuids,
    );

    // Listen for scan results
    return FlutterBluePlus.scanResults
        .where((results) => results.isNotEmpty)
        .asyncMap((results) => results)
        .expand((results) => results)
        .where((result) => _isTargetDevice(result.device))
        .map((result) => result.device)
        .distinct()
        .transform(StreamTransformer.fromHandlers(handleData: (data, sink) { print(data); sink.add(data); }));
  }

  bool _isTargetDevice(BluetoothDevice device) {
    // Check if device name matches any prefix
    final name = device.platformName;
    return _targetDevicePrefixes.any((prefix) => name.startsWith(prefix));
  }

  Future<void> _requestPermissions() async {
    await Permission.location.request();
    await Permission.bluetooth.request();
    await Permission.bluetoothConnect.request();
    await Permission.bluetoothScan.request();
  }

  void _showDeviceFoundDialog(BuildContext context, BluetoothDevice device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Device Found'),
        content: Text('Found compatible device: ${device.platformName}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Dismiss'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Add your connection logic here
            },
            child: Text('Connect'),
          ),
        ],
      ),
    );
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }
}