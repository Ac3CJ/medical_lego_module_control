import 'package:flutter/material.dart';
import 'models/module.dart';
import 'models/module_manager.dart';
import 'models/module_type.dart';


// MIGHT NEED TO MAKE THIS AN OBJECT TO PREVENT CONFUSION IN THE FUTURE
// Debug Variables
Map moduleMap = {
  1: 'Heat',
  2: 'Infrared',
  3: 'Vibration'
};

// Extensions
extension ParseToString on String {
  String capitalise() {
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}

// Main Code
void main() {
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
      home: const SliderDemoPage(),
    );
  }
}

class SliderDemoPage extends StatefulWidget {
  const SliderDemoPage({super.key});

  @override
  State<SliderDemoPage> createState() => _SliderDemoPageState();
}

class _SliderDemoPageState extends State<SliderDemoPage> {
  // Create lists to hold the values for each row
  List<double> intensityValues = [50, 50, 50]; // Initial intensity values (0-100)
  List<double> timeValues = [5, 5, 5]; // Initial time values (0-10 minutes)

  // Initialise the Managers
  late ModuleManager temperatureModuleManager;
  late ModuleManager infraredModuleManager;
  late ModuleManager vibrationModuleManager;
  late Map<ModuleType, ModuleManager> moduleManagers;

  @override
  void initState(){
    super.initState();

    // Initialize values based on ModuleType count
    final moduleCount = ModuleType.values.length;
    intensityValues = List<double>.filled(moduleCount, 50);
    timeValues = List<double>.filled(moduleCount, 5);

    moduleManagers = createModuleManagers();

    _initialiseDemoModules();
  }

  Map<ModuleType, ModuleManager> createModuleManagers() {
    final Map<ModuleType, ModuleManager> managers = {};
    
    for (final type in ModuleType.values) {
      managers[type] = ModuleManager(type);
    }
    
    return managers;
  }

  void _initialiseDemoModules() {
    moduleManagers[ModuleType.temperature]?.addNewModule(Module('TMP-001', 0x00, 0x00));
    moduleManagers[ModuleType.temperature]?.addNewModule(Module('TMP-002', 0x00, 0x01));
    moduleManagers[ModuleType.temperature]?.addNewModule(Module('TMP-003', 0x00, 0x02));

    moduleManagers[ModuleType.infrared]?.addNewModule(Module('IR-001', 0x01, 0x00));
    moduleManagers[ModuleType.infrared]?.addNewModule(Module('IR-002', 0x01, 0x01));
    moduleManagers[ModuleType.infrared]?.addNewModule(Module('IR-003', 0x01, 0x02));

    moduleManagers[ModuleType.vibration]?.addNewModule(Module('VBR-001', 0x02, 0x00));
    moduleManagers[ModuleType.vibration]?.addNewModule(Module('VBR-002', 0x02, 0x01));
    moduleManagers[ModuleType.vibration]?.addNewModule(Module('VBR-003', 0x02, 0x02));
    moduleManagers[ModuleType.vibration]?.addNewModule(Module('VBR-004', 0x02, 0x03));
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
            ...List.generate((ModuleType.values.length-1), (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildControlRow(index),
              );
            }),
            
            // Add the module status table
            _buildModuleStatusTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlRow(int index) {
    //final moduleType = ModuleType.values[index];
    ModuleManager? manager = moduleManagers[ModuleType.values[index]];
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // Big Button
          SizedBox(
            width: double.infinity,
            height: 32,
            child: ElevatedButton(
              onPressed: () { // Action when button is pressed
              setState(() {
                manager?.sendCommandToAll(intensityValues[index], timeValues[index]);
              });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${ModuleType.values[index].toShortString().capitalise()} Module - Intensity: ${manager?.moduleIntensity}%, Time: ${manager?.moduleTime} min'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                '${ModuleType.values[index].toShortString().capitalise()} Module',
                style: const TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),
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
            // Create a column for each module type
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: ModuleType.values.map((type) {
                final modules = moduleManagers[type]?.allModules ?? [];
                if (modules.isEmpty) return const SizedBox.shrink();
                
                final typeIndex = ModuleType.values.indexOf(type);
                final currentIntensity = intensityValues[typeIndex];
                final currentTime = timeValues[typeIndex];
                
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
                        // Parse through each module
                        ...modules.map((module) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  module.serialNumber,
                                  style: TextStyle(
                                    color: module.isConnected 
                                        ? Colors.green 
                                        : Colors.grey,
                                  ),
                                ),
                                Text(
                                  'Location: 0x${(module.locationId as int).toRadixString(16).toUpperCase().padLeft(2,'0')}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  'Intensity: ${module.moduleIntensity}%',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  'Time: ${module.moduleTime} min',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                );
              }).toList(),
          ),
        ],
      ),
      ),
    );
  }
}