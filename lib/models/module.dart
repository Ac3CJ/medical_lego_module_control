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
  String _serialNumber;
  num _moduleId;
  num _locationId; 
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
  Module(this._serialNumber, this._moduleId, this._locationId) {
    // Assign the module type based on the ID
    switch(_moduleId) {
      case 0x00: _moduleType = ModuleType.temperature;
      case 0x01: _moduleType = ModuleType.infrared;
      case 0x02: _moduleType = ModuleType.vibration;
      default: _moduleType = ModuleType.unknown;
    }
  }

  // Getters
  num get moduleId => _moduleId;
  String get serialNumber => _serialNumber;
  ModuleType get moduleType => _moduleType;
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