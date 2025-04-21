import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'module_type.dart';

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
  double targetIntensity = 0;
  double targetTime = 0;
  Map moduleCommand = {
    'intensity': 0,
    'time': 0
  };

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

  // Getters
  String get moduleId => _moduleId;
  String get serialNumber => _serialNumber;
  ModuleType get moduleType => _moduleType;
  StatusType get moduleStatus => _status;
  num get locationId => _locationId;
  num get moduleIntensity => moduleCommand['intensity'];
  num get moduleTime => moduleCommand['time'];

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

  void sendCommand(double targetIntensity, double targetTime) async{
    if (!isConnected.value) {
      throw Exception('Cannot send command to disconnected module');
    }

    this.targetIntensity = targetIntensity;
    this.targetTime = targetTime;

    _bleManager?.setIntensity(targetIntensity.toInt());
    _bleManager?.setTargetTime((targetTime.toInt())*60); // TARGET TIME IS READ IN MINUTES

    _status = StatusType.active;
    print('MAC: $_serialNumber\tModule ID: $_moduleId\tIntensity: ${targetIntensity.toString()}\tTarget Time: ${targetTime.toString()}');
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
  
  BleServiceManager(this.device);

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

  // UTF-8 String helper methods
  String _decodeUtf8(List<int> bytes) {
    return utf8.decode(bytes, allowMalformed: true);
  }

  List<int> _encodeUtf8(String value) {
    return utf8.encode(value);
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
    // final bytes = _writeInt32(percentage);
    final bytes = _encodeUtf8(percentage.toString());
    await _writeCharacteristic(intensityChar, therapyControlService, bytes);
  }

  Future<int> getTargetTime() async {
    final data = await _readCharacteristic(targetTimeChar, therapyControlService);
    return _readInt32(data);
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