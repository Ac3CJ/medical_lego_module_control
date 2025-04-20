import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';
import 'dart:async';

class BleController extends GetxController {
  // Private
  final List<String> _targetDevicePrefixes = ['LM Health'];

  // Target Service and Characteristic UUIDs
  final Guid _informationServiceUuid = Guid('00000011-710e-4a5b-8d75-3e5b444bc3cf');
  final Guid _deviceIdCharUuid = Guid('00000012-710e-4a5b-8d75-3e5b444bc3cf');
  final Guid _locationIdCharUuid = Guid('00000013-710e-4a5b-8d75-3e5b444bc3cf');

  // Identification Fields
  RxString _currentDeviceId = ''.obs;
  RxString _currentDeviceLocationId = ''.obs;
  RxString _currentDeviceMacAddress = ''.obs;

  // Getters
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults.map(
    (results) => results.where((result) {
      final deviceName = result.device.platformName;
      if (deviceName.isEmpty) return false;
      return _targetDevicePrefixes.any((prefix) => deviceName.startsWith(prefix));
    }).toList(),
  );
    
  RxString get currentDeviceId => _currentDeviceId;
  RxString get currentDeviceLocationId => _currentDeviceLocationId;
  RxString get currentDeviceMacAddress => _currentDeviceMacAddress;

  // Private Methods
  Future<void> _requestPermissions() async {
    await Permission.location.request();
    await Permission.bluetooth.request();
    await Permission.bluetoothConnect.request();
    await Permission.bluetoothScan.request();
  }

  Future<void> _fetchDeviceInformation(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      final infoService = services.firstWhere(
        (service) => service.serviceUuid == _informationServiceUuid,
        orElse: () => throw Exception('Information service not found'),
      );

      final deviceIdChar = infoService.characteristics.firstWhere(
        (c) => c.characteristicUuid == _deviceIdCharUuid,
        orElse: () => throw Exception('Device ID characteristic not found'),
      );
      final locationIdChar = infoService.characteristics.firstWhere(
        (c) => c.characteristicUuid == _locationIdCharUuid,
        orElse: () => throw Exception('Location ID characteristic not found'),
      );

      final deviceIdValue = await deviceIdChar.read();
      final locationIdValue = await locationIdChar.read();

      _currentDeviceId.value = String.fromCharCodes(deviceIdValue);
      _currentDeviceLocationId.value = String.fromCharCodes(locationIdValue);

      print('Device ID: ${_currentDeviceId.value}');
      print('Location ID: ${_currentDeviceLocationId.value}');
      print('MAC Address: ${_currentDeviceMacAddress.value}');
    } catch (e) {
      print('Error fetching device information: $e');
    }
  }

  // Public Methods
  Future<void> scanDevices() async {
    await _requestPermissions();
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(timeout: Duration(seconds: 15));

      _currentDeviceMacAddress.value = device.remoteId.str;

      device.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.connected) {
          print('Device Connected to: ${device.platformName}');
          await _fetchDeviceInformation(device);
        } else {
          print('Device Disconnected');
        }
      });
    } catch (e) {
      print('Connection error: $e');
    }
  }

  @override
  void onClose() {
    FlutterBluePlus.stopScan();
    super.onClose();
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