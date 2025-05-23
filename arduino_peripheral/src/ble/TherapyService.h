#ifndef THERAPY_SERVICE_H
#define THERAPY_SERVICE_H

#include <ArduinoBLE.h>
#include <functional>

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
    void setStatus(const String& value);
    void setTimeStamp(const String& value);
    void setUserId(const String& value);

    
    
    // Callback setters
    void setIntensityCallback(std::function<void(byte)> callback);
    void setTargetTimeCallback(std::function<void(unsigned int)> callback);
    void setTimeStampCallback(std::function<void(const String&)> callback);
    void setUserIdCallback(std::function<void(const String&)> callback);

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
    BLEStringCharacteristic _statusChar;
    BLEStringCharacteristic _timeStampChar;
    BLEStringCharacteristic _userIdChar;
    
    // Descriptors
    BLEDescriptor _timeElapsedDesc;
    BLEDescriptor _intensityDesc;
    BLEDescriptor _targetTimeDesc;
    //BLEDescriptor _clientConfigDesc;
    
    // Callbacks
    std::function<void(byte)> _intensityCallback = nullptr;
    std::function<void(unsigned int)> _targetTimeCallback = nullptr;
    std::function<void(const String&)> _timeStampCallback = nullptr;
    std::function<void(const String&)> _userIdCallback = nullptr;

    static TherapyService* _instance;

    static void intensityWriteHandler(BLEDevice central, BLECharacteristic characteristic);
    static void targetTimeWriteHandler(BLEDevice central, BLECharacteristic characteristic);
    static void timeStampWriteHandler(BLEDevice central, BLECharacteristic characteristic);
    static void userIdWriteHandler(BLEDevice central, BLECharacteristic characteristic);
    
    void setupCharacteristics();
    void initializeValues();
};

#endif