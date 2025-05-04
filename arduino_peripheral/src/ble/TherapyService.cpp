#include "TherapyService.h"
#include <Arduino.h>

TherapyService* TherapyService::_instance = nullptr;

TherapyService::TherapyService() 
    : _service(THERAPY_CONTROL_SERVICE_UUID),
      _timeElapsedChar(TIME_ELAPSED_UUID, BLERead | BLENotify, sizeof(unsigned int)),
      _intensityChar(INTENSITY_UUID, BLERead | BLEWrite | BLENotify, 3), // Set to 3 since 100% is the maximum
      _targetTimeChar(TARGET_TIME_UUID, BLERead | BLEWrite | BLENotify, sizeof(unsigned int)),
      _statusChar(STATUS_UUID, BLERead | BLENotify, 20), // Set to 1 since there will only be 2 modes NOTE: CHANGE TO BOOL LATER
      _timeStampChar(TIME_STAMP_UUID, BLERead | BLEWrite, 20),
      _userIdChar(USER_ID_UUID, BLERead | BLEWrite, 50),
      _timeElapsedDesc(DESCRIPTION_UUID, "Time Elapsed in Seconds"),
      _intensityDesc(DESCRIPTION_UUID, "Intensity Percentage"),
      _targetTimeDesc(DESCRIPTION_UUID, "Target Time in Seconds") {_instance = this;}

BLEService& TherapyService::getService() {
        return _service;
}

void TherapyService::setupService() {
    setupCharacteristics();
    initializeValues();
}

void TherapyService::setupCharacteristics() {
    // Add descriptors
    _timeElapsedChar.addDescriptor(_timeElapsedDesc);
    _intensityChar.addDescriptor(_intensityDesc);
    _targetTimeChar.addDescriptor(_targetTimeDesc);

    // Add characteristics to service
    _service.addCharacteristic(_timeElapsedChar);
    _service.addCharacteristic(_intensityChar);
    _service.addCharacteristic(_targetTimeChar);
    _service.addCharacteristic(_statusChar);
    _service.addCharacteristic(_timeStampChar);
    _service.addCharacteristic(_userIdChar);

    // Set event handlers to static functions
    _intensityChar.setEventHandler(BLEWritten, TherapyService::intensityWriteHandler);
    _targetTimeChar.setEventHandler(BLEWritten, TherapyService::targetTimeWriteHandler);
    _timeStampChar.setEventHandler(BLEWritten, TherapyService::timeStampWriteHandler);
    _userIdChar.setEventHandler(BLEWritten, TherapyService::userIdWriteHandler);
}

void TherapyService::initializeValues() {
    unsigned int initialTime = 0;
    setTimeElapsed(initialTime);
    setIntensity(DeviceConfig::DEFAULT_INTENSITY);
    setTargetTime(DeviceConfig::DEFAULT_TARGET_TIME);
    setStatus(DeviceConfig::DEFAULT_STATUS);
    setTimeStamp(DeviceConfig::DEFAULT_TIMESTAMP);
    setUserId(DeviceConfig::DEFAULT_USER_ID);
}

// ======================================================== WRITE CHARACTERISTICS ========================================================

void TherapyService::onIntensityWrite(BLEDevice central, BLECharacteristic characteristic) {
    byte writtenValue[3];  // 3 bytes based on your UTF-8 encoding
    characteristic.readValue(writtenValue, sizeof(writtenValue));
    byte intensity = BleUtils::utf8ToByte(writtenValue, sizeof(writtenValue));

    setIntensity(intensity);

    if (_intensityCallback) {
        _intensityCallback(intensity);
    }
}

void TherapyService::onTargetTimeWrite(BLEDevice central, BLECharacteristic characteristic) {
    int length = characteristic.valueLength();  // get actual bytes sent
    length = min(length, 4);  // Cap to 4 bytes for safety
    
    const uint8_t* data = characteristic.value();  // raw data pointer

    // Convert the received UTF-8 bytes to unsigned int
    unsigned int targetTime = BleUtils::utf8ToUint(data, length);

    setTargetTime(targetTime);

    if (_targetTimeCallback) {
        _targetTimeCallback(targetTime);
    }
}

void TherapyService::onTimeStampWrite(BLEDevice central, BLECharacteristic characteristic) {
    int length = characteristic.valueLength();  // get the actual length
    const uint8_t* data = characteristic.value();

    String timeStamp;
    for (int i = 0; i < length; i++) {
        timeStamp += (char)data[i];  // append each byte as char
    }

    setTimeStamp(timeStamp);

    if (_timeStampCallback) {
        _timeStampCallback(timeStamp);
    }
}

void TherapyService::onUserIdWrite(BLEDevice central, BLECharacteristic characteristic) {
    int length = characteristic.valueLength();
    const uint8_t* data = characteristic.value();

    String userId;
    for (int i = 0; i < length; i++) {
        userId += (char)data[i];
    }

    setUserId(userId);

    if (_userIdCallback) {
        _userIdCallback(userId);
    }
}

void TherapyService::intensityWriteHandler(BLEDevice central, BLECharacteristic characteristic) {
    if (_instance) {
        _instance->onIntensityWrite(central, characteristic);
    }
}

void TherapyService::targetTimeWriteHandler(BLEDevice central, BLECharacteristic characteristic) {
    if (_instance) {
        _instance->onTargetTimeWrite(central, characteristic);
    }
}

void TherapyService::timeStampWriteHandler(BLEDevice central, BLECharacteristic characteristic) {
    if (_instance) {
        _instance->onTimeStampWrite(central, characteristic);
    }
}

void TherapyService::userIdWriteHandler(BLEDevice central, BLECharacteristic characteristic) {
    if (_instance) {
        _instance->onUserIdWrite(central, characteristic);
    }
}

// ======================================================== CALLBACKS ========================================================

void TherapyService::setIntensityCallback(std::function<void(byte)> callback) {
    _intensityCallback = callback;
}

void TherapyService::setTargetTimeCallback(std::function<void(unsigned int)> callback) {
    _targetTimeCallback = callback;
}

void TherapyService::setTimeStampCallback(std::function<void(const String&)> callback) {
    _timeStampCallback = callback;
}

void TherapyService::setUserIdCallback(std::function<void(const String&)> callback) {
    _userIdCallback = callback;
}


// ======================================================== SET CHARACTERISTICS ========================================================

void TherapyService::setTimeElapsed(unsigned int value) {
    byte byteArray[sizeof(unsigned int)];
    size_t length;

    BleUtils::uintToUtf8(value, byteArray, length);
    _timeElapsedChar.writeValue(byteArray, length);
}

void TherapyService::setIntensity(byte value) {
    byte byteArray[3];
    size_t length;

    BleUtils::byteToUtf8(value, byteArray, length);
    _intensityChar.writeValue(byteArray, length);
}

void TherapyService::setTargetTime(unsigned int value) {
    byte byteArray[sizeof(unsigned int)];
    size_t length;

    BleUtils::uintToUtf8(value, byteArray, length);
    _targetTimeChar.writeValue(byteArray, length);
}

void TherapyService::setStatus(const String& value) {
    _statusChar.writeValue(value);
}

void TherapyService::setTimeStamp(const String& value) {
    _timeStampChar.writeValue(value);
}

void TherapyService::setUserId(const String& value) {
    _userIdChar.writeValue(value);
}

void TherapyService::update() {
    static unsigned long lastUpdate = 0;
    const unsigned long updateInterval = 1000;
    
    if (millis() - lastUpdate >= updateInterval) {
        lastUpdate = millis();
        
        // Read current value
        unsigned int elapsedTime = BleUtils::utf8ToUint(_timeElapsedChar.value(), 4);
        elapsedTime++;
        setTimeElapsed(elapsedTime);
    }
}