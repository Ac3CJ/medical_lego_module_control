import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'module_type.dart';

// FIND A WAY TO MAKE IT SO THAT MODULES CAN DISCONNECT AND RECONNECT, FINDING OUT WHEN IT HAPPENS

// Module Status is held as a binary value
// 0x00 -> Off
// 0x01 -> Inactive
// 0x02 -> Active
// 0x03 -> Pairing
enum StatusType {
  connected,
  disconnected,
  active,
  inactive,
  pairing,
}

class Module {
  //Private
  final String _serialNumber;
  final String _moduleId;
  final num _locationId; 
  ModuleType _moduleType = ModuleType.unknown;
  StatusType _status = StatusType.disconnected;
  
  bool _isBle = false;

  BluetoothDevice? _device;
  BleServiceManager? _bleManager;

  // Public
  RxBool isConnected = false.obs;
  List<String> connectedDevices = [];
  RxDouble targetIntensity = 0.0.obs;
  RxDouble targetTime = 0.0.obs;
  RxDouble elapsedTime = 0.0.obs;

  // Getters
  String get moduleId => _moduleId;
  String get serialNumber => _serialNumber;
  ModuleType get moduleType => _moduleType;
  StatusType get moduleStatus => _status;
  num get locationId => _locationId;

  RxDouble get moduleIntensity {
    if (_isBle) {return _bleManager!.intensityValue;}
    return targetIntensity.value.obs;
  }

  RxDouble get moduleTime {
    if (_isBle) {return _bleManager!.targetTimeValue;}
    return (targetIntensity.value).obs;  
  }

  RxDouble get moduleElapsedTime {
    if (_isBle) {return _bleManager!.elapsedTimeValue;}
    return elapsedTime.value.obs;  
  }

  // Constructor
  Module(this._serialNumber, this._moduleId, this._locationId, [this._device]) {
    // Assign the module type based on the ID
    switch(_moduleId.split('-')[0]) {
      case 'TMP': _moduleType = ModuleType.temperature;
      case 'IR': _moduleType = ModuleType.infrared;
      case 'VBR': _moduleType = ModuleType.vibration;
      default: _moduleType = ModuleType.unknown;
    }
    if (_device != null) {
      _isBle = true;
      _bleManager = BleServiceManager(_device!);
    }
  }

  // Private Methods
  /*void updateStatus(num newStatus) {
    _status = newStatus;
  }*/

  // Public Methods
  Future<void> connect() async {
    if (_isBle) {
      try {
        await _device?.connect(timeout: Duration(seconds: 15));

        _device?.connectionState.listen((state) async {
          if (state == BluetoothConnectionState.connected) {
            print('Device Connected to: ${_device?.platformName}');
            isConnected.value = true;
            _status = StatusType.connected;
            return;
          } else {
            print('Device Disconnected');
          }
        });
      } catch (e) {
        print('Connection error: $e');
      }

      isConnected.value = false;
      _status = StatusType.disconnected;
      return;
    }
    isConnected.value = true;
    _status = StatusType.connected;
  }

  Future<void> disconnect() async {
    isConnected.value = false;
    _status = StatusType.disconnected;
    await _device?.disconnect();
  }

  void sendCommand(double intensity, double targetT) async{
    if (!isConnected.value) {
      throw Exception('Cannot send command to disconnected module');
    }

    targetIntensity.value = intensity;
    targetTime.value = targetT;

    _bleManager?.setIntensity(intensity.toInt());
    _bleManager?.setTargetTime(((targetT*60).toInt())); // TARGET TIME IS READ IN MINUTES

    _bleManager?.refreshValues();
    _status = StatusType.active;
    print('MAC: $_serialNumber\tModule ID: $_moduleId\tIntensity: ${intensity.toString()}\tTarget Time: ${targetT.toString()}');
  }

  void addConnection(String deviceSerialNumber) {
    if (!connectedDevices.contains(deviceSerialNumber)) {
      connectedDevices.add(deviceSerialNumber);
    }
  }

  void removeConnection(String deviceSerialNumber) {
    connectedDevices.remove(deviceSerialNumber);
  }

  @override
  String toString() {
    return 'Module(Serial Number: $_serialNumber, type: $_moduleType, ID: $_moduleId, connected: ${isConnected.value}, port: $_locationId)';
  }
}

class BleServiceManager {
  static final therapyControlService = Guid('00000001-710e-4a5b-8d75-3e5b444bc3cf');
  static final moduleInfoService = Guid('00000011-710e-4a5b-8d75-3e5b444bc3cf');
  
  // Characteristics
  static final timeElapsedChar = Guid('00000002-710e-4a5b-8d75-3e5b444bc3cf');
  static final intensityChar = Guid('00000003-710e-4a5b-8d75-3e5b444bc3cf');
  static final targetTimeChar = Guid('00000004-710e-4a5b-8d75-3e5b444bc3cf');
  static final statusChar = Guid('00000005-710e-4a5b-8d75-3e5b444bc3cf');
  static final deviceIdChar = Guid('00000012-710e-4a5b-8d75-3e5b444bc3cf');
  static final locationIdChar = Guid('00000013-710e-4a5b-8d75-3e5b444bc3cf');

  BluetoothDevice device;
  
  RxDouble intensityValue = 0.0.obs;
  RxDouble targetTimeValue = 0.0.obs;
  RxDouble elapsedTimeValue = 0.0.obs;

  // Stream subscriptions
  StreamSubscription<String>? _statusSubscription;
  StreamSubscription<double>? _elapsedTimeSubscription;

  BleServiceManager(this.device) {
    _initStatusMonitoring();
  }

  void dispose() {
    _statusSubscription?.cancel();
    _elapsedTimeSubscription?.cancel();
  }

  void _initStatusMonitoring() {
    _statusSubscription = getStatus().listen((status) {
      // Handle status changes
      if (status == 'Active') {
        _startElapsedTimeMonitoring();
      } else {
        _stopElapsedTimeMonitoring();
      }
    }, onError: (error) {
      print('Error in status stream: $error');
    });
  }

  Future<void> refreshValues() async {
    intensityValue.value = (await getIntensity());
    targetTimeValue.value = (await getTargetTime());
  }

    void _startElapsedTimeMonitoring() {
    _elapsedTimeSubscription?.cancel(); // Cancel any existing subscription
    
    _elapsedTimeSubscription = getTimeElapsed().listen((time) {
      print('[TEST] CURRENT TIME IS: $time');
      elapsedTimeValue.value = time;
    }, onError: (error) {
      print('Error in elapsed time stream: $error');
    });
  }

  void _stopElapsedTimeMonitoring() {
    _elapsedTimeSubscription?.cancel();
    _elapsedTimeSubscription = null;
    elapsedTimeValue.value = 0.0; // Reset elapsed time when not active
  }

  // UTF-8 String Helper Methods
  String _decodeUtf8(List<int> bytes) {
    return utf8.decode(bytes, allowMalformed: true);
  }

  List<int> _encodeUtf8(String value) {
    return utf8.encode(value);
  }

  // Therapy Control Service Methods
  Stream<double> getTimeElapsed() {
    return _setupNotification(timeElapsedChar, therapyControlService)
        .map((data) => double.parse(_decodeUtf8(data)));
  }

  Future<double> getIntensity() async {
    final data = await _readCharacteristic(intensityChar, therapyControlService);
    final value = double.parse(_decodeUtf8(data));
    intensityValue = value.obs;
    return value;
  }

  Future<void> setIntensity(int percentage) async {
    if (percentage < 0 || percentage > 100) {
      throw ArgumentError('Intensity must be between 0 and 100');
    }
    // final bytes = _writeInt32(percentage);
    final bytes = _encodeUtf8(percentage.toString());
    await _writeCharacteristic(intensityChar, therapyControlService, bytes);
  }

  Future<double> getTargetTime() async {
    final data = await _readCharacteristic(targetTimeChar, therapyControlService);
    final value = (double.parse(_decodeUtf8(data)))/60; // CONVERT SECONDS TO MINUTES
    targetTimeValue = value.obs;
    return value;
  }

  Future<void> setTargetTime(int seconds) async {
    // final bytes = _writeInt32(seconds);
    final bytes = _encodeUtf8(seconds.toString());
    await _writeCharacteristic(targetTimeChar, therapyControlService, bytes);
  }

  Stream<String> getStatus() {
    return _setupNotification(statusChar, therapyControlService)
        .map((data) => _decodeUtf8(data));
  }

  // Module Information Service Methods
  Future<String> getDeviceId() async {
    final data = await _readCharacteristic(deviceIdChar, moduleInfoService);
    return _decodeUtf8(data);
  }

  Future<String> getLocationId() async {
    final data = await _readCharacteristic(locationIdChar, moduleInfoService);
    return _decodeUtf8(data);
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
}