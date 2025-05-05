#include "BleManager.h"

void onBLEConnected(BLEDevice central);
void onBLEDisconnected(BLEDevice central);

BleManager::BleManager(TherapyService& therapyService, 
                       ModuleInfoService& moduleInfoService,
                       TherapyController& therapyController) 
    : _therapyService(therapyService), 
      _moduleInfoService(moduleInfoService),
      _therapyController(therapyController) {}

bool BleManager::begin() {
    if (!BLE.begin()) {
        return false;
    }

    // Set up connection event handlers
    BLE.setEventHandler(BLEConnected, onBLEConnected);
    BLE.setEventHandler(BLEDisconnected, onBLEDisconnected);

    // Link service with controller
    linkServiceAndController();
    
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

void BleManager::linkServiceAndController() {
    // BLE writes -> Controller callbacks
    _therapyService.setTargetTimeCallback([this](unsigned int targetTime) {
        _therapyController.onTargetTimeUpdated(targetTime);
    });
    _therapyService.setIntensityCallback([this](byte intensity) {
        _therapyController.onIntensityUpdated(intensity);
    });
    _therapyService.setTimeStampCallback([this](const String& timeStamp) {
        _therapyController.onTimeStampUpdated(timeStamp);
    });
    _therapyService.setUserIdCallback([this](const String& userId) {
        _therapyController.onUserIdUpdated(userId);
    });

    // Controller -> Service feedback
    _therapyController.setTherapyService(&_therapyService);
    _therapyController.setModuleInfoService(&_moduleInfoService);
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