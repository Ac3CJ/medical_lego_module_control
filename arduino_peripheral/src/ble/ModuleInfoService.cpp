#include "ble/ModuleInfoService.h"

ModuleInfoService::ModuleInfoService() 
    : _service(MODULE_INFO_SERVICE_UUID),
      _deviceIdChar(DEVICE_ID_UUID, BLERead, 50),
      _locationIdChar(LOCATION_ID_UUID, BLERead),
      _batteryLifeChar(BATTERY_LIFE_UUID, BLERead | BLENotify),
      _firmwareVersionChar(FIRMWARE_VERSION_UUID, BLERead, 20) {}

BLEService& ModuleInfoService::getService() {
    return _service;
}

void ModuleInfoService::setupService() {
    setupCharacteristics();
    initializeValues();
}

void ModuleInfoService::setupCharacteristics() {
    // Add client config descriptor for notifiable characteristics
    //_batteryLifeChar.addDescriptor(_clientConfigDesc);
    
    // Add characteristics to service
    _service.addCharacteristic(_deviceIdChar);
    _service.addCharacteristic(_locationIdChar);
    _service.addCharacteristic(_batteryLifeChar);
    _service.addCharacteristic(_firmwareVersionChar);
}

void ModuleInfoService::initializeValues() {
    // Set default values
    _deviceIdChar.setValue("TMP-001");
    _locationIdChar.setValue(1);
    _batteryLifeChar.setValue(100); // 100% charged
    _firmwareVersionChar.setValue("1.0.0");
}

void ModuleInfoService::setDeviceId(const String& id) {
    if (id.length() <= 50) { // Match max characteristic size
        _deviceIdChar.setValue(id);
    }
}

void ModuleInfoService::setLocationId(byte location) {
        _locationIdChar.setValue(location);
}

void ModuleInfoService::setBatteryLife(byte level) {
    // Constrain to 0-100%
    byte constrainedLevel = constrain(level, 0, 100);
    _batteryLifeChar.setValue(constrainedLevel);
}

void ModuleInfoService::setFirmwareVersion(const String& version) {
    if (version.length() <= 20) {
        _firmwareVersionChar.setValue(version);
    }
}

void ModuleInfoService::update() {
    // Placeholder for periodic updates
    static unsigned long lastUpdate = 0;
    const unsigned long updateInterval = 5000; // 5 seconds
    
    if (millis() - lastUpdate >= updateInterval) {
        lastUpdate = millis();
        byte currentBattery = _batteryLifeChar.value();
        if (currentBattery > 0) {
            setBatteryLife(currentBattery - 1);
        }
    }
}