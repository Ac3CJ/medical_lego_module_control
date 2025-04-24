import 'package:get/get.dart';
import 'dart:async';
import 'module.dart';
import 'module_type.dart';

// This Class should be used to abstract all of the BLE stuff from the main code, meaning that only the data from the app gets sent here.
// The data should be handled and converted to BLE stuff in module.dart

class ModuleManager {
  // Private
  List<Module> _modules = [];
  ModuleType _managerType;

  Timer? _statusCheckTimer;
  RxBool _isActive = false.obs;
  Rx<StatusType> _managerStatus = StatusType.disconnected.obs;

  // Public
  double moduleIntensity = 0;
  double moduleTime = 0;

  // Constructor
  ModuleManager(this._managerType){
    _startStatusCheckTimer();
  }

  // Destructor
  void dispose() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = null;
  }

  // Getters
  List<Module> get allModules => List.from(_modules);
  List<Module> get connectedModules => _modules.where((module) => module.isConnected.value).toList();
  ModuleType get managerType => _managerType;
  RxBool get isActive => _isActive;

  // Private Methods
  void _startStatusCheckTimer() {
    // Check status every second
    _statusCheckTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _updateManagerStatus();
    });
  }

  void _updateManagerStatus() {
    final connected = connectedModules;
    
    if (connected.isEmpty) {
      _managerStatus.value = StatusType.disconnected;
      _isActive.value = false;
      return;
    }

    // Check if any module is active
    final anyActive = connected.any((module) => module.moduleStatus == StatusType.active);
    
    if (anyActive) {
      _managerStatus.value = StatusType.active;
      _isActive.value = true;
    } else {
      _managerStatus.value = StatusType.connected;
      _isActive.value = false;
    }
  }

  // Public Methods
  void addNewModule(Module newModule) {
    if (newModule.moduleType != _managerType) {
      print('Wrong Module Type!');
      return;
    }

    if (!_modules.any((m) => m.serialNumber == newModule.serialNumber)) {
      _modules.add(newModule);
      // Automatically connect to other modules
      for (var existingModule in _modules) {
        if (existingModule.serialNumber != newModule.serialNumber) {
          existingModule.addConnection(newModule.serialNumber);
          newModule.addConnection(existingModule.serialNumber);
        }
      }
    }
    _updateManagerStatus();
  }

  void removeModule(String serialNumber) {
    _modules.removeWhere((m) => m.serialNumber == serialNumber);
    // Remove this module from all other modules' connected devices
    for (var module in _modules) {
      module.removeConnection(serialNumber);
    }
    _updateManagerStatus();
  }

  void sendCommandToAll(double targetIntensity, double targetTime) {
    moduleIntensity = targetIntensity;
    moduleTime = targetTime;
    for (var module in connectedModules) {
      module.sendCommand(targetIntensity, targetTime);
    }
    _updateManagerStatus();
  }

  void sendCommandToModule(String serialNumber, double targetIntensity, double targetTime) {
    moduleIntensity = targetIntensity;
    moduleTime = targetTime;
    final module = _modules.firstWhere(
      (m) => m.serialNumber == serialNumber,
      orElse: () => throw Exception('Module not found'),
    );
    module.sendCommand(targetIntensity, targetTime);
    _updateManagerStatus();
  }

  void printAllModules() {
    for (var module in _modules) {
      print(module.toString());
    }
  }
}