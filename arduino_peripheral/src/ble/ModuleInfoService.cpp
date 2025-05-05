#include "ble/ModuleInfoService.h"
#include "BleUtils.h"

ModuleInfoService::ModuleInfoService() 
    : _service(MODULE_INFO_SERVICE_UUID),
      _deviceIdChar(DEVICE_ID_UUID, BLERead, 50),
      _locationIdChar(LOCATION_ID_UUID, BLERead, 3),
      _batteryLifeChar(BATTERY_LIFE_UUID, BLERead | BLENotify, 3),
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
    setDeviceId(DeviceConfig::DEVICE_ID);
    setLocationId(DeviceConfig::LOCATION);
    setBatteryLife(0x64); // 100% Charge
    setFirmwareVersion(DeviceConfig::FIRMWARE_VERSION);
}

void ModuleInfoService::setDeviceId(const String& id) {
    if (id.length() <= 50) { // Match max characteristic size
        _deviceIdChar.writeValue(id);
    }
}

void ModuleInfoService::setLocationId(byte location) {
    byte byteArray[3];
    size_t length;

    BleUtils::byteToUtf8(location, byteArray, length);
    _locationIdChar.writeValue(byteArray, length);
}

void ModuleInfoService::setBatteryLife(byte level) {
    // Constrain to 0-100%
    byte constrainedLevel = constrain(level, 0, 100);
    byte byteArray[3];
    size_t length;

    BleUtils::byteToUtf8(constrainedLevel, byteArray, length);
    _batteryLifeChar.writeValue(byteArray, length);
}

void ModuleInfoService::setFirmwareVersion(const String& version) {
    if (version.length() <= 20) {
        _firmwareVersionChar.writeValue(version);
    }
}

void ModuleInfoService::updateBatteryLevel() {
    size_t length = _batteryLifeChar.valueLength();
    byte currentBattery = BleUtils::utf8ToByte(_batteryLifeChar.value(), length);
    
    if (currentBattery > 0) {
        currentBattery--;
    } else {
        currentBattery = 0x64; // Reset to 100%
    }
    Serial.printf("Battery Level: %d\n", currentBattery);
    setBatteryLife(currentBattery);
}