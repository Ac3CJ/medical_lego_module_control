import 'module.dart';
import 'module_type.dart';

class ModuleManager {
  // Private
  List<Module> _modules = [];
  ModuleType _managerType;

  // Public
  Map moduleCommand = {
    'intensity': 0,
    'time': 0
  };

  // Constructor
  ModuleManager(this._managerType);

  // Getters
  List<Module> get allModules => List.from(_modules);
  List<Module> get connectedModules => _modules.where((module) => module.isConnected).toList();
  ModuleType get managerType => _managerType;

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
  }

  void removeModule(String serialNumber) {
    _modules.removeWhere((m) => m.serialNumber == serialNumber);
    // Remove this module from all other modules' connected devices
    for (var module in _modules) {
      module.removeConnection(serialNumber);
    }
  }

  void sendCommandToAll(Map command) {
    for (var module in connectedModules) {
      module.sendCommand(command);
    }
  }

  void sendCommandToModule(String serialNumber, Map command) {
    final module = _modules.firstWhere(
      (m) => m.serialNumber == serialNumber,
      orElse: () => throw Exception('Module not found'),
    );
    module.sendCommand(command);
  }

  void printAllModules() {
    for (var module in _modules) {
      print(module.toString());
    }
  }
}