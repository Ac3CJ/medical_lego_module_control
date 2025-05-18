#include "BleManager.h"

void onBLEConnected(BLEDevice central);
void onBLEDisconnected(BLEDevice central);

BleManager::BleManager(TherapyService& therapyService, 
                       ModuleInfoService& moduleInfoService) 
    : _therapyService(therapyService), 
      _moduleInfoService(moduleInfoService) {}

bool BleManager::begin() {
    if (!BLE.begin()) {
        return false;
    }

    // Set up connection event handlers
    BLE.setEventHandler(BLEConnected, onBLEConnected);
    BLE.setEventHandler(BLEDisconnected, onBLEDisconnected);
    
    setupBle();
    setConnectionParameters();
    return true;
}

void BleManager::setupBle() {
    BLE.setDeviceName(DeviceConfig::NAME);
    BLE.setLocalName(DeviceConfig::NAME);
    BLE.setAppearance(0x0000); // Generic appearance
    
    // Add services
    _therapyService.setupService();
    _moduleInfoService.setupService();
    
    BLE.addService(_therapyService.getService());
    BLE.addService(_moduleInfoService.getService());

    Serial.printf("Advertising as %s...", DeviceConfig::NAME);
}

void BleManager::setConnectionParameters() {
    BLE.setConnectionInterval(0x001E, 0x001E); // 30ms
    BLE.setSupervisionTimeout(500); // 5 seconds
}

void BleManager::update() {
    BLE.poll();
    //_therapyController.update();
}

void BleManager::advertise() {
    BLE.advertise();
}

// Implementation of the event handler functions
void onBLEConnected(BLEDevice central) {
    Serial.println("Device Connected");
    // Try to read the central's name
    if (central.hasLocalName()) {
        Serial.print("Connected to: ");
        Serial.println(central.localName());
    } else {
        Serial.print("Connected to device (MAC: ");
        Serial.print(central.address());
    }
    Serial.println();
    
}

void onBLEDisconnected(BLEDevice central) {
    Serial.println("Device Disconnected");
}