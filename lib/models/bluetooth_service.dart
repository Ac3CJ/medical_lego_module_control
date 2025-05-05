import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:module_control/models/module_manager.dart';
import 'package:module_control/models/module_type.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';
import 'dart:async';

class BleController extends GetxController {
  // Private
  final List<String> _targetDevicePrefixes = ['LM Health'];
  Map<ModuleType, ModuleManager> moduleManagers;

  // Target Service and Characteristic UUIDs
  final Guid _informationServiceUuid = Guid('00000011-710e-4a5b-8d75-3e5b444bc3cf');
  final Guid _deviceIdCharUuid = Guid('00000012-710e-4a5b-8d75-3e5b444bc3cf');
  final Guid _locationIdCharUuid = Guid('00000013-710e-4a5b-8d75-3e5b444bc3cf');
  final Guid _firmwareVersionChar = Guid('00000015-710e-4a5b-8d75-3e5b444bc3cf');

  // Identification Fields
  RxString _currentDeviceId = ''.obs;
  RxString _currentDeviceLocationId = ''.obs;
  RxString _currentDeviceMacAddress = ''.obs;
  RxString _currentDeviceFwVersion = ''.obs;

  // Streams
  StreamSubscription<BluetoothConnectionState>? _currentDeviceConnectionState;

  // Getters
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults.map(
    (results) => results.where((result) {
      final deviceName = result.device.platformName;
      if (deviceName.isEmpty) return false;
      
      // Check if device matches target prefixes
      final isTargetDevice = _targetDevicePrefixes.any((prefix) => deviceName.startsWith(prefix));
      if (!isTargetDevice) return false;
      
      // Get all connected device serial numbers from all managers
      final connectedSerials = moduleManagers.values
          .expand((manager) => manager.allModules)
          .map((module) => module.serialNumber)
          .toSet();
      
      // Check if this device's MAC is already managed
      final macAddress = result.device.remoteId.str;
      return !connectedSerials.contains(macAddress);
    }).toList(),
  );
    
  RxString get currentDeviceId => _currentDeviceId;
  RxString get currentDeviceLocationId => _currentDeviceLocationId;
  RxString get currentDeviceMacAddress => _currentDeviceMacAddress;
  RxString get currentDeviceFwVersion => _currentDeviceFwVersion;

  // Constructor
  BleController(this.moduleManagers);

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
      final fwVersionChar = infoService.characteristics.firstWhere(
        (c) => c.characteristicUuid == _firmwareVersionChar,
        orElse: () => throw Exception('Location ID characteristic not found'),
      );

      final deviceIdValue = await deviceIdChar.read();
      final locationIdValue = await locationIdChar.read();
      final fwVersionValue = await fwVersionChar.read();

      _currentDeviceId.value = String.fromCharCodes(deviceIdValue);
      _currentDeviceLocationId.value = String.fromCharCodes(locationIdValue);
      _currentDeviceFwVersion.value = String.fromCharCodes(fwVersionValue);

      print('Device ID: ${_currentDeviceId.value}');
      print('Location ID: ${_currentDeviceLocationId.value}');
      print('MAC Address: ${_currentDeviceMacAddress.value}');
      print('FW Version: ${_currentDeviceFwVersion.value}');
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
    // Create a completer to wait for the full connection process
    final completer = Completer<void>();
    
    await device.connect();

    _currentDeviceMacAddress.value = device.remoteId.str;

    _currentDeviceConnectionState = device.connectionState.listen((state) async {
      if (state == BluetoothConnectionState.connected) {
        print('Device Connected to: ${device.platformName}');
        try {
          await _fetchDeviceInformation(device);
          await _currentDeviceConnectionState?.cancel(); // Cancel the subscription for handover to Module class
          _currentDeviceConnectionState = null;
          completer.complete(); // Only complete when everything is done
        } catch (e) {
          completer.completeError(e);
        }
      } else {
        print('Device Disconnected');
        // You might want to handle disconnection during connection attempt
        if (!completer.isCompleted) {
          completer.completeError(Exception('Disconnected during connection'));
        }
      }
    });

    // Wait for either the connection to complete or timeout
    return completer.future.timeout(Duration(seconds: 15), onTimeout: () {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Connection timed out'));
      }
      throw Exception('Connection timed out');
    });
  } catch (e) {
    print('Connection error: $e');
    rethrow; // Important to rethrow so the caller knows about the error
  }
}

  void cancelConnectionStateSubscription() {
    _currentDeviceConnectionState?.cancel();
    _currentDeviceConnectionState = null;
  }

  @override
  void onClose() {
    FlutterBluePlus.stopScan();
    super.onClose();
  }
}