import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/state_manager.dart';
import 'package:get/get.dart';
import 'models/module.dart';
import 'models/module_manager.dart';
import 'models/module_type.dart';
import 'models/bluetooth_service.dart';
import 'models/user.dart';

// Extensions
extension ParseToString on String {
  String capitalise() {
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}

// Main Code
void main() {
  FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Module Control Debug Console',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Refresh Trigger
  final _refreshTrigger = false.obs;

  // Create lists to hold the values for each row
  List<double> intensityValues = [50, 50, 50]; // Initial intensity values (0-100)
  List<double> timeValues = [5, 5, 5]; // Initial time values (0-10 minutes)

  // Initialise the Managers
  late Map<ModuleType, ModuleManager> moduleManagers;

  // Initialise Bluetooth Services
  late BleController bleController;

  // For User ID
  final TextEditingController _userIdController = TextEditingController();
  final user = User(); // Get the singleton instance

  @override
  void initState(){
    super.initState();

    // Initialise values based on ModuleType count
    final moduleCount = ModuleType.values.length;
    intensityValues = List<double>.filled(moduleCount, 50);
    timeValues = List<double>.filled(moduleCount, 5);

    // Module Management
    moduleManagers = createModuleManagers();
    // _initialiseDemoModules();

    // Bluetooth Services
    bleController = BleController(moduleManagers);
    bleController.scanDevices();
  }

  @override
  void dispose() {
    bleController.dispose(); // Make sure to dispose the controller
    _userIdController.dispose();
    super.dispose();
  }

  // Module Management Methods
  Map<ModuleType, ModuleManager> createModuleManagers() {
    final Map<ModuleType, ModuleManager> managers = {};
    
    for (final type in ModuleType.values) {
      managers[type] = ModuleManager(type);
    }
    
    return managers;
  }

  // Building the Widgets
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control Panel'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [ 
            // User ID Input
            _buildUserIdInput(),

            // Therapy Control
            const SizedBox(height: 20),
            ...List.generate((ModuleType.values.length-1), (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildControlRow(index),
              );
            }),
            
            // Add the module status table
            _buildModuleStatusTable(),

            // Add Bluetooth Device List
            _bluetoothDeviceList(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserIdInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<Map<String, String>>(
          stream: user.stream,
          initialData: user.currentData, // Provide initial data from the singleton
          builder: (context, snapshot) {
            final data = snapshot.data ?? {'userId': '', 'timestamp': ''};
            return Text(
              data['userId']!.isEmpty
                ? 'No Current User'
                : 'Current User: ${data['userId']} at ${data['timestamp']}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _userIdController,
          decoration: InputDecoration(
            hintText: 'Enter User ID',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.keyboard_return, color: Colors.blue),
              onPressed: _submitUserId,
            ),
          ),
          onSubmitted: (_) => _submitUserId(),
        ),
      ],
    );
  }

  void _submitUserId() {
    if (_userIdController.text.isNotEmpty) {
      User().changeUserId(_userIdController.text); // Access via instance
      _userIdController.clear();
      setState(() {});
    }
  }

  Widget _buildControlRow(int index) {
    ModuleManager? manager = moduleManagers[ModuleType.values[index]];
    final moduleType = ModuleType.values[index].toShortString().capitalise();
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // Big Button - Now changes based on active status
          SizedBox(
            width: double.infinity,
            height: 32,
            child: Obx(() {
              final isActive = manager?.isActive.value ?? false;
              return ElevatedButton(
                onPressed: () {
                  if (isActive) {
                    // Stop therapy - send 0 intensity and 0 time
                    manager?.sendCommandToAll(0, 0);
                  } else {
                    // Start therapy - use current slider values
                    manager?.sendCommandToAll(intensityValues[index], timeValues[index]);
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$moduleType Module - ${isActive ? 'Stopped' : 'Started'}'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive ? Colors.red[700] : Colors.blue[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  '$moduleType Therapy: ${isActive ? 'Stop' : 'Run'}',
                  style: const TextStyle(fontSize: 20, color: Colors.white),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          
          // Intensity Slider
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Intensity (0-100%)'),
              Slider(
                value: intensityValues[index],
                min: 0,
                max: 100,
                divisions: 100,
                label: intensityValues[index].round().toString(),
                onChanged: (value) {
                  setState(() {
                    intensityValues[index] = value;
                  });
                },
              ),
              Text(
                '${intensityValues[index].round()}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Time Slider
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Time (0-10 minutes)'),
              Slider(
                value: timeValues[index],
                min: 0,
                max: 10,
                divisions: 20,
                label: '${timeValues[index]} min',
                onChanged: (value) {
                  setState(() {
                    timeValues[index] = value;
                  });
                },
              ),
              Text(
                '${timeValues[index]} minutes',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModuleStatusTable() {
    return Card(
      margin: const EdgeInsets.only(top: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Connected Modules',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            // Watch the refresh trigger to rebuild when needed
            Obx(() {
              // This dummy variable just forces the Obx to rebuild
              final _ = _refreshTrigger.value;
              
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: ModuleType.values.map((type) {
                  final modules = moduleManagers[type]?.allModules ?? [];
                  if (modules.isEmpty) return const SizedBox.shrink();
                  
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${type.toShortString().capitalise()} (${modules.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...modules.map((module) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (module.isConnected.value) {
                                        module.disconnect();
                                      } else {
                                        module.connect();
                                      }
                                      _refreshTrigger.toggle(); // Trigger update
                                    },
                                    child: Obx(() => Text(
                                      module.moduleId,
                                      style: TextStyle(
                                        color: module.isConnected.value 
                                            ? Colors.green 
                                            : Colors.grey,
                                      ),
                                    )),
                                  ),
                                  Text(
                                    'Location: 0x${(module.locationId as int).toRadixString(16).toUpperCase().padLeft(2,'0')}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Obx(() => Text(
                                    'Intensity: ${module.moduleIntensity.value.toInt()}%',
                                    style: const TextStyle(fontSize: 12),
                                  )),
                                  Obx(() => Text(
                                    'Target Time: ${module.moduleTime.value.toStringAsFixed(1)} Min',
                                    style: const TextStyle(fontSize: 12),
                                  )),
                                  Obx(() => Text(
                                    'Elapsed: ${module.moduleElapsedTime.value.toInt()} Sec',
                                    style: const TextStyle(fontSize: 12),
                                  )),
                                  Text(
                                    'Status: ${module.moduleStatus.toShortString().capitalise()}',
                                    //'Status: Test',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Obx(() => Text(
                                    'RSSI: ${module.rssi.value} dBm',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _getRssiColor(module.rssi.value),
                                    ),
                                  )),
                                  Obx(() => Text(
                                    'Battery: ${module.moduleBatteryLife.value}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _getBatteryColor(module.moduleBatteryLife.value),
                                    ),
                                  )),
                                  Text(
                                    'FW Version: ${module.firmwareVersion}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _bluetoothDeviceList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.5),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      margin: const EdgeInsets.all(16),
      child: GetBuilder<BleController>(
        init: bleController, // Use the class-level instance
        builder: (bleController) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 70,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                child: Center(
                  child: Text(
                    'Bluetooth Devices',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => bleController.scanDevices(),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.blue,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      child: const Text(
                        'Scan for Devices',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<List<ScanResult>>(
                      stream: bleController.scanResults,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          );
                        }
                        else if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        }
                        else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'No devices found. Tap Scan to search.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }
                        else {
                          return ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 300),
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: snapshot.data!.length,
                              itemBuilder: (context, index) {
                                final data = snapshot.data![index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 1,
                                  child: ListTile(
                                    title: Text(
                                      data.device.platformName.isNotEmpty 
                                          ? data.device.platformName 
                                          : 'Unknown Device',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    subtitle: Text(data.device.remoteId.toString()),
                                    trailing: Text(
                                      '${data.rssi} dBm',
                                      style: TextStyle(
                                        color: _getRssiColor(data.rssi),
                                      ),
                                    ),
                                    onTap: () async {
                                      await bleController.connectToDevice(data.device);
                                      // Get the updated values from the controller
                                      final deviceId = bleController.currentDeviceId.value;
                                      final macAddress = bleController.currentDeviceMacAddress.value;
                                      final locationId = bleController.currentDeviceLocationId.value;
                                      final fwVersion = bleController.currentDeviceFwVersion.value;
                                      
                                      if (deviceId.isNotEmpty && macAddress.isNotEmpty && locationId.isNotEmpty) {
                                        final moduleType = deviceId.split('-')[0];
                                        final location = int.tryParse(locationId) ?? 0;
                                        
                                        switch(moduleType) {
                                          case 'TMP': 
                                            moduleManagers[ModuleType.temperature]?.addNewModule(
                                              Module(macAddress, deviceId, location, fwVersion, data.device));
                                          case 'IR': 
                                            moduleManagers[ModuleType.infrared]?.addNewModule(
                                              Module(macAddress, deviceId, location, fwVersion, data.device));
                                          case 'VBR': 
                                            moduleManagers[ModuleType.vibration]?.addNewModule(
                                              Module(macAddress, deviceId, location, fwVersion, data.device));
                                        }
                                        // Trigger Refresh
                                        _refreshTrigger.toggle();
                                        setState(() {});
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getRssiColor(int rssi) {
    if (rssi >= -50) return Colors.green;
    if (rssi >= -70) return Colors.lightGreen;
    if (rssi >= -85) return Colors.orange;
    return Colors.red;
  }
  
  Color _getBatteryColor(int batteryLife) {
    if (batteryLife >= 75) return Colors.green;
    if (batteryLife >= 50) return Colors.orange;
    if (batteryLife >= 25) return Colors.deepOrange;
    return Colors.red;
  }
}