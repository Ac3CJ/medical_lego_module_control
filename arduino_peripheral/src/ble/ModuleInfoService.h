#ifndef MODULE_INFO_SERVICE_H
#define MODULE_INFO_SERVICE_H

#include <ArduinoBLE.h>
#include <Arduino.h>
#include "BleConfig.h"

class ModuleInfoService {
public:
    ModuleInfoService();
    
    BLEService& getService();
    void setupService();
    
    void setDeviceId(const String& id);
    void setLocationId(byte location);
    void setBatteryLife(byte level);
    void setFirmwareVersion(const String& version);
    
    void updateBatteryLevel();

private:
    BLEService _service;
    
    BLEStringCharacteristic _deviceIdChar;
    BLECharacteristic _locationIdChar;
    BLECharacteristic _batteryLifeChar;
    BLEStringCharacteristic _firmwareVersionChar;
    
    
    void setupCharacteristics();
    void initializeValues();
};

#endif