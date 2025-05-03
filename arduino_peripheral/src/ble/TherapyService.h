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
    void setStatus(byte value);
    void setTimeStamp(const String& value);
    void setUserId(const String& value);
    
    // Callback setters
    void setIntensityCallback(void (*callback)(byte));
    void setTargetTimeCallback(void (*callback)(unsigned int));
    void setTimeStampCallback(void (*callback)(const String&));
    void setUserIdCallback(void (*callback)(const String&));
    
    void update();

private:
    BLEService _service;
    
    // Characteristics
    BLECharacteristic _timeElapsedChar;
    BLEByteCharacteristic _intensityChar;
    BLEUnsignedIntCharacteristic _targetTimeChar;
    BLEByteCharacteristic _statusChar;
    BLEStringCharacteristic _timeStampChar;
    BLEStringCharacteristic _userIdChar;
    
    // Descriptors
    BLEDescriptor _timeElapsedDesc;
    BLEDescriptor _intensityDesc;
    BLEDescriptor _targetTimeDesc;
    //BLEDescriptor _clientConfigDesc;
    
    // Callbacks
    void (*_intensityCallback)(byte);
    void (*_targetTimeCallback)(unsigned int);
    void (*_timeStampCallback)(const String&);
    void (*_userIdCallback)(const String&);
    
    void setupCharacteristics();
    void initializeValues();
};

#endif