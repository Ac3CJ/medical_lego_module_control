import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
//import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'module_type.dart';
import 'user.dart';

enum StatusType {
  connected,    // This means the module is inactive as well
  disconnected, // Device is no longer connected to module
  active,       // Therapy is active
  // inactive,
  // pairing,
}

extension ParseToString on StatusType {
  String toShortString() {
    return toString().split('.').last;
  }
}

class Module {
  // Private
  final String _serialNumber;
  final String _moduleId;
  num _locationId; 
  String _firmwareVersion;
  ModuleType _moduleType = ModuleType.unknown;
  StatusType _status = StatusType.disconnected; // Keep this value for potential future
  
  bool _isBle = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;

  BluetoothDevice? _device;
  BleServiceManager? _bleManager;
  StreamSubscription<BluetoothConnectionState>? _deviceConnectionState;
  StreamSubscription<String>? _statusSubscription;

  RxInt _batteryLevel = 0.obs;
  //RxBool _isActive = false.obs;

  // RSSI 
  RxInt _rssi = (-100).obs; // Initialize with a default low value
  static const Duration _bleStateUpdateInterval = Duration(seconds: 2);
  Timer? _bleStateTimer;

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
  num get locationId => _locationId;
  String get firmwareVersion => _firmwareVersion;

  // Get Device Details from BLE
  RxInt get rssi => _rssi;

  RxInt get moduleBatteryLife {
    if (_isBle) {
      if (_bleManager == null) {return 0.obs;}
      return _bleManager!.batteryLifeValue;
    }
    return _batteryLevel;
  }
  // StatusType get moduleStatus => _status;
  StatusType get moduleStatus {
    if (!isConnected.value) {
      _status = StatusType.disconnected;
      return _status;
    }

    _refreshDeviceState();

    if (_bleManager == null || !(_bleManager!.isTherapyActive.value)) {
      _status = StatusType.connected;
      return _status;
    }
    _status = StatusType.active;
    return _status;
  }

  RxDouble get moduleIntensity {
    if (_isBle) {
      if (_bleManager == null) {return 0.0.obs;}
      return _bleManager!.intensityValue;
    }
    return targetIntensity;
  }

  RxDouble get moduleTime {
    if (_isBle) {
      if (_bleManager == null) {return 0.0.obs;}
      return _bleManager!.targetTimeValue;
      }
    return targetTime;  
  }

  RxDouble get moduleElapsedTime {
    if (_isBle) {
      if (_bleManager == null) {return 0.0.obs;}
      return _bleManager!.elapsedTimeValue;
      }
    return elapsedTime;  
  }

  // Constructor
  Module(this._serialNumber, this._moduleId, this._locationId, this._firmwareVersion, [this._device]) {
    // Assign the module type based on the ID
    switch(_moduleId.split('-')[0]) {
      case 'TMP': _moduleType = ModuleType.temperature;
      case 'IR': _moduleType = ModuleType.infrared;
      case 'VBR': _moduleType = ModuleType.vibration;
      default: _moduleType = ModuleType.unknown;
    }
    if (_device != null) {
      _isBle = true;
      // _bleManager = BleServiceManager(_device!);
      // _setupStatusListener(); 
    }
  }

  void dispose() async {
    try {
      // Cancel all subscriptions
      await _statusSubscription?.cancel();
      _statusSubscription = null;

      // Cancel the RSSI timer
      _bleStateTimer?.cancel();
      _bleStateTimer = null;
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
      _batteryLevel.close();

      // Clear connected devices list
      connectedDevices.clear();

      print('Module $_serialNumber disposed successfully');
    } catch (e) {
      print('Error disposing Module $_serialNumber: $e');
    }
  }

  // Private Methods
  Future <void> _refreshDeviceState() async {
    if (_isBle && isConnected.value && _device != null) {
      try {
        // Update RSSI Value
        final newRssi = await _device!.readRssi();
        _rssi.value = newRssi;

        // Update Status
        if (_bleManager != null) {
          _status = _bleManager!.isTherapyActive.value 
            ? StatusType.active 
            : StatusType.connected;
        }

        // Refresh all BLE values
        await _bleManager?.refreshValues();
      } catch (e) {
        print('Error refreshing device state: $e');
        _rssi.value = -100; // Reset to minimum value on error
      }
    }
  }


  void _manageBleStateUpdates() {
    if (_isBle && isConnected.value && _device != null) {
      // Start RSSI updates if not already running
      if (_bleStateTimer == null || !_bleStateTimer!.isActive) {
        _bleStateTimer = Timer.periodic(_bleStateUpdateInterval, (_) async {
          await _refreshDeviceState();
        });
      }
    } else {
      // Stop RSSI updates if not connected
      _bleStateTimer?.cancel();
      _bleStateTimer = null;
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
    _manageBleStateUpdates(); // Start RSSI updates
  }

  Future<void> _handleDisconnection() async {
    print('[MODULE] Abrupt Disconnect from device');
    isConnected.value = false;
    _status = StatusType.disconnected;
    _manageBleStateUpdates(); // This will stop RSSI updates

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
    _manageBleStateUpdates(); // This will stop RSSI updates

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

    // Update Local Values
    targetIntensity.value = intensity;
    targetTime.value = targetT;

    // Send to BLE Device
    _bleManager?.setIntensity(intensity.toInt());
    _bleManager?.setTargetTime(((targetT*60).toInt())); // TARGET TIME IS READ IN MINUTES

    // Send user info if available
    final user = User();
    if (user.currentUserId.isNotEmpty) {
      _bleManager?.setUserId(user.currentUserId);
      _bleManager?.setTimestamp(user.currentTimestamp);
    }

    _bleManager?.refreshValues();
    _status = StatusType.active;
    print('[MODULE] MAC: $_serialNumber\tModule ID: $_moduleId\tIntensity: ${intensity.toString()}\tTarget Time: ${targetT.toString()}');
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
  static final timeStampChar = Guid('00000006-710e-4a5b-8d75-3e5b444bc3cf');
  static final userIdChar = Guid('00000007-710e-4a5b-8d75-3e5b444bc3cf');

  static final deviceIdChar = Guid('00000012-710e-4a5b-8d75-3e5b444bc3cf');
  static final locationIdChar = Guid('00000013-710e-4a5b-8d75-3e5b444bc3cf');
  static final batteryLevelChar = Guid('00000014-710e-4a5b-8d75-3e5b444bc3cf'); 
  static final firmwareVersionChar = Guid('00000015-710e-4a5b-8d75-3e5b444bc3cf');

  BluetoothDevice device;
  
  RxDouble intensityValue = 0.0.obs;
  RxDouble targetTimeValue = 0.0.obs;
  RxDouble elapsedTimeValue = 0.0.obs;
  RxInt batteryLifeValue = 0.obs;
  RxString statusValue = ''.obs;

  // Stream subscriptions
  StreamSubscription<String>? _statusSubscription;
  StreamSubscription<double>? _elapsedTimeSubscription;
  StreamSubscription<int>? _batterySubscription;

  // Private
  RxBool _isTherapyActive = false.obs;

  // Getter
  RxBool get isTherapyActive => _isTherapyActive;

  // Constructor
  BleServiceManager(this.device) {
    _initStatusMonitoring();
    _initBatteryMonitoring();
    _initElapsedTimeMonitoring();
  }

  // Destructor
  void dispose() async {
    try {
      // Cancel all active subscriptions
      await _statusSubscription?.cancel();
      await _elapsedTimeSubscription?.cancel();
      await _batterySubscription?.cancel();

      // Clear Rx variables
      intensityValue.close();
      targetTimeValue.close();
      elapsedTimeValue.close();

      // Reset state
      _isTherapyActive.value = false;
      _statusSubscription = null;
      _elapsedTimeSubscription = null;
      _batterySubscription = null;

      print('BleServiceManager for device ${device.remoteId} disposed');
    } catch (e) {
      print('Error disposing BleServiceManager: $e');
    }
  }

  // Private Methods
  void _initStatusMonitoring() {
    _statusSubscription = getStatus().listen((status) {
      // Handle status changes
      statusValue.value = status;
/*       if (status == 'Active') {
        _startElapsedTimeMonitoring();
        _isTherapyActive.value = true;
      } else {
        _stopElapsedTimeMonitoring();
      } */
    }, onError: (error) {
      print('Error in status stream: $error');
    });
  }

  void _initBatteryMonitoring() {
    _batterySubscription?.cancel();
    
    _batterySubscription = getBatteryLevel().listen((batteryLife) {
      batteryLifeValue.value = batteryLife;
      print('[MODULE] BATTERY LIFE: ${batteryLifeValue.value}');
    }, onError: (error) {
      print('Error in battery level stream: $error');
    });
  }

  void _initElapsedTimeMonitoring() {
    _elapsedTimeSubscription?.cancel();
    
    _elapsedTimeSubscription = getTimeElapsed().listen((time) {
      elapsedTimeValue.value = time;
    }, onError: (error) {
       print('Error in elapsed time stream: $error');print('Error in battery level stream: $error');
    });
  }

  void _startElapsedTimeMonitoring() {
    _elapsedTimeSubscription?.cancel(); // Cancel any existing subscription
    
    _elapsedTimeSubscription = getTimeElapsed().listen((time) {
      elapsedTimeValue.value = time;
    }, onError: (error) {
      print('Error in elapsed time stream: $error');
    });
  }

  void _stopElapsedTimeMonitoring() {
    _elapsedTimeSubscription?.cancel();
    _elapsedTimeSubscription = null;
    elapsedTimeValue.value = 0.0; // Reset elapsed time when not active
    _isTherapyActive.value = false;

    intensityValue.value = 0;
    targetTimeValue.value = 0;
  }

  Future<void> refreshValues() async {
    intensityValue.value = (await getIntensity());
    targetTimeValue.value = (await getTargetTime());
    // batteryLifeValue.value = (await readBatteryLevel());
    statusValue.value = (await readStatus());

    if (statusValue.value == 'Active') {
      _isTherapyActive.value = true;
    } else {
      _isTherapyActive.value = false;
    }
  }

  // UTF-8 String Helper Methods
  String _decodeUtf8(List<int> bytes) {
    return utf8.decode(bytes, allowMalformed: true);
  }

  List<int> _encodeUtf8(String value) {
    return utf8.encode(value);
  }

  // Battery Service Methods
  Stream<int> getBatteryLevel() {
    return _setupNotification(batteryLevelChar, moduleInfoService)
        .map((data) => int.parse(_decodeUtf8(data)));
  }

  Future<int> readBatteryLevel() async {
    final data = await _readCharacteristic(batteryLevelChar, moduleInfoService);
    final value = int.parse(_decodeUtf8(data)); // CONVERT SECONDS TO MINUTES
    batteryLifeValue = value.obs;
    return value;
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
    final bytes = _encodeUtf8(seconds.toString());
    await _writeCharacteristic(targetTimeChar, therapyControlService, bytes);
  }

  Stream<String> getStatus() {
    return _setupNotification(statusChar, therapyControlService)
        .map((data) => _decodeUtf8(data));
  }

  Future<String> readStatus() async {
    final data = await _readCharacteristic(statusChar, therapyControlService);
    final value = _decodeUtf8(data); // CONVERT SECONDS TO MINUTES
    statusValue = value.obs;
    return value;
  }

  Future<void> setTimestamp(String timestamp) async {
    final bytes = _encodeUtf8(timestamp);
    await _writeCharacteristic(timeStampChar, therapyControlService, bytes);
  }

  Future<void> setUserId(String userId) async {
    final bytes = _encodeUtf8(userId);
    await _writeCharacteristic(userIdChar, therapyControlService, bytes);
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

  Future<String> getFirmwareVersion() async {
    final data = await _readCharacteristic(firmwareVersionChar, moduleInfoService);
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