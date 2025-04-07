import 'package:flutter/material.dart';


// MIGHT NEED TO MAKE THIS AN OBJECT TO PREVENT CONFUSION IN THE FUTURE
// Debug Variables
Map moduleMap = {
  1: 'Heat',
  2: 'Infrared',
  3: 'Vibration'
};

bool heatModuleConnected = false;
bool infraredModuleConnected = false;
bool vibrationModuleConnected = false;

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
            // Row 1
            _buildControlRow(0),
            const SizedBox(height: 20),
            
            // Row 2
            _buildControlRow(1),
            const SizedBox(height: 20),
            
            // Row 3
            _buildControlRow(2),
          ],
        ),
      ),
    );
  }

  Widget _buildControlRow(int index) {
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
              onPressed: () {
                // Action when button is pressed
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${moduleMap[index+1]} Module - Intensity: ${intensityValues[index].toInt()}%, Time: ${timeValues[index]} min'),
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
                '${moduleMap[index+1]} Module',
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
}