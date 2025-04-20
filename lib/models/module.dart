import 'package:flutter_blue_plus/flutter_blue_plus.dart';
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

  // Public
  bool isConnected = true;
  List<String> connectedDevices = [];
  Map moduleCommand = {
    'intensity': 0,
    'time': 0
  };

  // Constructor
  Module(this._serialNumber, this._moduleId, this._locationId, {BluetoothDevice? bleDevice}) {
    // Assign the module type based on the ID
    switch(_moduleId.split('-')[0]) {
      case 'TMP': _moduleType = ModuleType.temperature;
      case 'IR': _moduleType = ModuleType.infrared;
      case 'VBR': _moduleType = ModuleType.vibration;
      default: _moduleType = ModuleType.unknown;
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
  void connect() {
    isConnected = true;
    _status = StatusType.connected;
    // Add any connection logic here
  }

  void disconnect() {
    isConnected = false;
    _status = StatusType.disconnected;
    // Add any disconnection logic here
  }

  void sendCommand(Map command) {
    if (!isConnected) {
      throw Exception('Cannot send command to disconnected module');
    }
    // Implement specific command handling in subclasses
    _status = StatusType.active;
    moduleCommand = command;
    print('Module: $serialNumber\t$command');
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
    return 'Module(Serial Number: $_serialNumber, type: $_moduleType, ID: $_moduleId, connected: $isConnected, port: $_locationId)';
  }
}

class BleDeviceManager {
  // Services
  static final _therapyControlService = Guid('00000001-710e-4a5b-8d75-3e5b444bc3cf');
  static final _moduleInfoService = Guid('00000011-710e-4a5b-8d75-3e5b444bc3cf');
  
  // Characteristics
  static final _timeElapsedChar = Guid('00000002-710e-4a5b-8d75-3e5b444bc3cf');
  static final _intensityChar = Guid('00000003-710e-4a5b-8d75-3e5b444bc3cf');
  static final _targetTimeChar = Guid('00000004-710e-4a5b-8d75-3e5b444bc3cf');
  static final _statusChar = Guid('00000005-710e-4a5b-8d75-3e5b444bc3cf');
  static final _deviceIdChar = Guid('00000012-710e-4a5b-8d75-3e5b444bc3cf');
  static final _locationIdChar = Guid('00000013-710e-4a5b-8d75-3e5b444bc3cf');

  final BluetoothDevice device;

  BleDeviceManager(this.device);
}