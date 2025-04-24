import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
//import 'dart:typed_data';
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
  // Private
  final String _serialNumber;
  final String _moduleId;
  final num _locationId; 
  ModuleType _moduleType = ModuleType.unknown;
  StatusType _status = StatusType.disconnected;
  
  bool _isBle = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;

  BluetoothDevice? _device;
  BleServiceManager? _bleManager;
  StreamSubscription<BluetoothConnectionState>? _deviceConnectionState;

  // RSSI 
  RxInt _rssi = (-100).obs; // Initialize with a default low value
  static const Duration _rssiUpdateInterval = Duration(seconds: 2);
  Timer? _rssiTimer;

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
  RxInt get rssi => _rssi;

  RxDouble get moduleIntensity {
    if (_isBle) {
      if (_bleManager == null) return 0.0.obs;
      return _bleManager!.intensityValue;
      }
    return targetIntensity;
  }

  RxDouble get moduleTime {
    if (_isBle) {
      if (_bleManager == null) return 0.0.obs;
      return _bleManager!.targetTimeValue;
      }
    return targetIntensity;  
  }

  RxDouble get moduleElapsedTime {
    if (_isBle) {
      if (_bleManager == null) return 0.0.obs;
      return _bleManager!.elapsedTimeValue;
      }
    return elapsedTime;  
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

  void dispose() async {
    try {
      // Cancel the RSSI timer
      _rssiTimer?.cancel();
      _rssiTimer = null;
      // Cancel the connection state listener first
      await _deviceConnectionState?.cancel();
      _deviceConnectionState = null;

      // Disconnect from the device if connected
      if (isConnected.value) {
        await disconnect();
      }

      // Dispose of the BLE manager
      _bleManager?.dispose();
      _bleManager = null;

      // Clear all Rx variables
      isConnected.close();
      targetIntensity.close();
      targetTime.close();
      elapsedTime.close();

      // Clear connected devices list
      connectedDevices.clear();

      print('Module $_serialNumber disposed successfully');
    } catch (e) {
      print('Error disposing Module $_serialNumber: $e');
    }
  }

  // Private Methods
  void _manageRssiUpdates() {
    if (_isBle && isConnected.value && _device != null) {
      // Start RSSI updates if not already running
      if (_rssiTimer == null || !_rssiTimer!.isActive) {
        _rssiTimer = Timer.periodic(_rssiUpdateInterval, (_) async {
          try {
            if (isConnected.value && _device != null) {
              final newRssi = await _device!.readRssi();
              _rssi.value = newRssi;
            }
          } catch (e) {
            print('Error reading RSSI: $e');
            _rssi.value = -100; // Reset to minimum value on error
          }
        });
      }
    } else {
      // Stop RSSI updates if not connected
      _rssiTimer?.cancel();
      _rssiTimer = null;
      _rssi.value = -100; // Reset to minimum value when disconnected
    }
  }

  Future<void> _attemptReconnect() async {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('[MODULE] Max reconnection attempts ($_maxReconnectAttempts) reached for $_serialNumber');
      _reconnectAttempts = 0;
      return;
    }

    _reconnectAttempts++;
    print('[MODULE] Attempting to reconnect ($_reconnectAttempts/$_maxReconnectAttempts) to $_serialNumber');
    
    try {
      await Future.delayed(Duration(seconds: 1)); // Add a small delay before reconnecting
      await connect();
    } catch (e) {
      print('[MODULE] Reconnection attempt $_reconnectAttempts failed: $e');
      if (_reconnectAttempts < _maxReconnectAttempts) {
        await _attemptReconnect(); // Recursively attempt reconnection
      }
    }
  }

  Future<void> _handleConnection() async {
    print('[MODULE] Connected to: ${_device?.platformName}');
    isConnected.value = true;
    _status = StatusType.connected;
    _reconnectAttempts = 0; // Reset reconnect attempts on successful connection

    _bleManager ??= BleServiceManager(_device!); // Initialize BLE manager if not available
    _manageRssiUpdates(); // Start RSSI updates
  }

  Future<void> _handleDisconnection() async {
    print('[MODULE] Abrupt Disconnect from device');
    isConnected.value = false;
    _status = StatusType.disconnected;
    _manageRssiUpdates(); // This will stop RSSI updates

    // Clean Up BLE manager to avoid memory leaks
    _bleManager?.dispose();
    _bleManager = null;

    // Attempt to reconnect
    await _attemptReconnect();
  }

  Future<void> _handleConnectionError(dynamic error) async {
    print('Connection error: $error');
    isConnected.value = false;
    _status = StatusType.disconnected;
    _manageRssiUpdates(); // This will stop RSSI updates

    _bleManager?.dispose();
    _bleManager = null;

    // Attempt to reconnect
    await _attemptReconnect();
  }

  // Public Methods
  Future<void> connect() async {
    if (_isBle) {
      try {
        await _deviceConnectionState?.cancel(); // Avoid double subscriptions
        await _device?.connect(autoConnect: true, timeout: Duration(seconds: 5), mtu: null);

        _deviceConnectionState = _device?.connectionState.listen((state) async {
          if (state == BluetoothConnectionState.connected) {
            print('[MODULE] Connected to: ${_device?.platformName}');
            await _handleConnection();
          } else {
            await _handleDisconnection();
          }
        });
      } catch (e) {
        await _handleConnectionError(e);
      }
      return;
    }
    // Non-BLE Connection
    isConnected.value = true;
    _status = StatusType.connected;
  }

  Future<void> disconnect() async {
    print('[MODULE] Disconnected from device');
    isConnected.value = false;
    _status = StatusType.disconnected;
    _reconnectAttempts = 0; // Reset reconnect attempts on manual disconnect

    await _deviceConnectionState?.cancel();
    await _device?.disconnect();

    _bleManager?.dispose();
    _bleManager = null;
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
  // Services
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

  // Private
  bool _isTherapyActive = false;

  // Constructor
  BleServiceManager(this.device) {
    _initStatusMonitoring();
  }

  // Destructor
  void dispose() async {
    try {
      // Cancel all active subscriptions
      await _statusSubscription?.cancel();
      await _elapsedTimeSubscription?.cancel();

      // Clear Rx variables
      intensityValue.close();
      targetTimeValue.close();
      elapsedTimeValue.close();

      // Reset state
      _isTherapyActive = false;
      _statusSubscription = null;
      _elapsedTimeSubscription = null;

      print('BleServiceManager for device ${device.remoteId} disposed');
    } catch (e) {
      print('Error disposing BleServiceManager: $e');
    }
  }

  // Private Methods
  void _initStatusMonitoring() {
    _statusSubscription = getStatus().listen((status) {
      // Handle status changes
      if (status == 'Active') {
        _startElapsedTimeMonitoring();
        _isTherapyActive = true;
      } else {
        _stopElapsedTimeMonitoring();
      }
    }, onError: (error) {
      print('Error in status stream: $error');
    });
  }

  void _startElapsedTimeMonitoring() {
    if (!_isTherapyActive) {_elapsedTimeSubscription?.cancel();} // Cancel any existing subscription
    
    //print('[MODULE] TIME ELAPSED READING');
    _elapsedTimeSubscription = getTimeElapsed().listen((time) {
      //print('[MODULE] TIME: $time');
      elapsedTimeValue.value = time;
    }, onError: (error) {
      print('Error in elapsed time stream: $error');
    });
  }

  void _stopElapsedTimeMonitoring() {
    _elapsedTimeSubscription?.cancel();
    _elapsedTimeSubscription = null;
    elapsedTimeValue.value = 0.0; // Reset elapsed time when not active
    _isTherapyActive = false;
  }

  Future<void> refreshValues() async {
    intensityValue.value = (await getIntensity());
    targetTimeValue.value = (await getTargetTime());
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