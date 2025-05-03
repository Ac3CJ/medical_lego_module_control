#ifndef THERAPY_SERVICE_H
#define THERAPY_SERVICE_H

#include <ArduinoBLE.h>
#include "BleConfig.h"
#include "BleUtils.h"

class TherapyService {
public:
    TherapyService();
    
    BLEService& getService();
    void setupService();
    
    // Characteristic access methods
    void setTimeElapsed(unsigned int value);
    void setIntensity(byte value);
    void setTargetTime(unsigned int value);
    void setStatus(bool value);
    void setTimeStamp(const String& value);
    void setUserId(const String& value);
    
    // Callback setters
    void setIntensityCallback(void (*callback)(byte));
    void setTargetTimeCallback(void (*callback)(unsigned int));
    void setTimeStampCallback(void (*callback)(const String&));
    void setUserIdCallback(void (*callback)(const String&));

    void onIntensityWrite(BLEDevice central, BLECharacteristic characteristic);
    void onTargetTimeWrite(BLEDevice central, BLECharacteristic characteristic);
    void onTimeStampWrite(BLEDevice central, BLECharacteristic characteristic);
    void onUserIdWrite(BLEDevice central, BLECharacteristic characteristic);
    
    void update();

private:
    BLEService _service;
    
    // Characteristics
    BLECharacteristic _timeElapsedChar;
    BLECharacteristic _intensityChar;
    BLECharacteristic _targetTimeChar;
    BLECharacteristic _statusChar;
    BLEStringCharacteristic _timeStampChar;
    BLEStringCharacteristic _userIdChar;
    
    // Descriptors
    BLEDescriptor _timeElapsedDesc;
    BLEDescriptor _intensityDesc;
    BLEDescriptor _targetTimeDesc;
    //BLEDescriptor _clientConfigDesc;
    
    // Callbacks
    void (*_intensityCallback)(byte) = nullptr;
    void (*_targetTimeCallback)(unsigned int) = nullptr;
    void (*_timeStampCallback)(const String&) = nullptr;
    void (*_userIdCallback)(const String&) = nullptr;

    static TherapyService* _instance;

    static void intensityWriteHandler(BLEDevice central, BLECharacteristic characteristic);
    static void targetTimeWriteHandler(BLEDevice central, BLECharacteristic characteristic);
    static void timeStampWriteHandler(BLEDevice central, BLECharacteristic characteristic);
    static void userIdWriteHandler(BLEDevice central, BLECharacteristic characteristic);
    
    void setupCharacteristics();
    void initializeValues();
};

#endif