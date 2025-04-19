import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:typed_data';

class BleController extends GetxController{
  // FlutterBluePlus flutterBlue = FlutterBluePlus();

  // Filter for specific device names or service UUIDs
  final List<String> _targetDevicePrefixes = ['TMP-', 'IR-', 'VBR-', 'CJ02-', 'LMTherapy-',];
  final List<Guid> _targetServiceUuids = [
    // Guid('0000180a-0000-1000-8000-00805f9b34fb'), // Common device info service
    // Guid('FFF6'), // Common Matter service
    Guid('00000001-710e-4a5b-8d75-3e5b444bc3cf'), // Therapy Control service
    Guid('00000011-710e-4a5b-8d75-3e5b444bc3cf'), // Module Information service
  ];

  // Getters
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  // Private Methods
  Future<void> _requestPermissions() async {
    await Permission.location.request();
    await Permission.bluetooth.request();
    await Permission.bluetoothConnect.request();
    await Permission.bluetoothScan.request();
  }

  // Public Methods
  Future scanDevices() async {
    _requestPermissions();

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    //FlutterBluePlus.stopScan();
  }
}

/*
class BleDeviceManager {
  static final therapyControlService = Guid('00000001-710e-4a5b-8d75-3e5b444bc3cf');
  static final moduleInfoService = Guid('00000011-710e-4a5b-8d75-3e5b444bc3cf');
  
  // Characteristics
  static final timeElapsedChar = Guid('00000002-710e-4a5b-8d75-3e5b444bc3cf');
  static final intensityChar = Guid('00000003-710e-4a5b-8d75-3e5b444bc3cf');
  static final targetTimeChar = Guid('00000004-710e-4a5b-8d75-3e5b444bc3cf');
  static final statusChar = Guid('00000005-710e-4a5b-8d75-3e5b444bc3cf');
  static final deviceIdChar = Guid('00000012-710e-4a5b-8d75-3e5b444bc3cf');
  static final locationIdChar = Guid('00000013-710e-4a5b-8d75-3e5b444bc3cf');

  final BluetoothDevice device;
  
  BleDeviceManager(this.device);

  Future<void> connect() async {
    await device.connect(autoConnect: false);
    await device.discoverServices();
  }

  Future<void> disconnect() async {
    await device.disconnect();
  }

  // Helper Methods
  int _readInt32(List<int> bytes) {
    final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
    return byteData.getInt32(0, Endian.little);
  }

  int _readUint8(List<int> bytes) {
    return bytes[0];
  }

  List<int> _writeInt32(int value) {
    final byteData = ByteData(4);
    byteData.setInt32(0, value, Endian.little);
    return byteData.buffer.asUint8List().toList();
  }


  // Therapy Control Service Methods
  Stream<int> getTimeElapsed() {
    return _setupNotification(timeElapsedChar, therapyControlService)
        .map((data) => _readInt32(data));
  }

  Future<int> getIntensity() async {
    final data = await _readCharacteristic(intensityChar, therapyControlService);
    return _readUint8(data);
  }

  Future<void> setIntensity(int percentage) async {
    if (percentage < 0 || percentage > 100) {
      throw ArgumentError('Intensity must be between 0 and 100');
    }
    await _writeCharacteristic(intensityChar, therapyControlService, [percentage]);
  }

  Future<int> getTargetTime() async {
    final data = await _readCharacteristic(targetTimeChar, therapyControlService);
    return _readInt32(data);
  }

  Future<void> setTargetTime(int seconds) async {
    final bytes = _writeInt32(seconds);
    await _writeCharacteristic(targetTimeChar, therapyControlService, bytes);
  }

  Stream<String> getStatus() {
    return _setupNotification(statusChar, therapyControlService)
        .map((data) => String.fromCharCodes(data));
  }

  // Module Information Service Methods
  Future<String> getDeviceId() async {
    final data = await _readCharacteristic(deviceIdChar, moduleInfoService);
    return String.fromCharCodes(data);
  }

  Future<String> getLocationId() async {
    final data = await _readCharacteristic(locationIdChar, moduleInfoService);
    return String.fromCharCodes(data);
  }

  // Base BLE Operations
  Future<List<int>> _readCharacteristic(Guid charUuid, Guid serviceUuid) async {
    final services = await device.discoverServices();
    final service = services.firstWhere((s) => s.uuid == serviceUuid);
    final characteristic = service.characteristics.firstWhere((c) => c.uuid == charUuid);
    return await characteristic.read();
  }

  Future<void> _writeCharacteristic(Guid charUuid, Guid serviceUuid, List<int> value) async {
    final services = await device.discoverServices();
    final service = services.firstWhere((s) => s.uuid == serviceUuid);
    final characteristic = service.characteristics.firstWhere((c) => c.uuid == charUuid);
    await characteristic.write(value);
  }

  Stream<List<int>> _setupNotification(Guid charUuid, Guid serviceUuid) {
    return device.discoverServices().then((services) {
      final service = services.firstWhere((s) => s.uuid == serviceUuid);
      final characteristic = service.characteristics.firstWhere((c) => c.uuid == charUuid);
      characteristic.setNotifyValue(true);
      return characteristic.onValueReceived;
    }).asStream().asyncExpand((s) => s);
  }
}*/