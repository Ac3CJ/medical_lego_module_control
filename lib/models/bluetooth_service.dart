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
      //await device.connect(timeout: Duration(seconds: 15));
      await device.connect();

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