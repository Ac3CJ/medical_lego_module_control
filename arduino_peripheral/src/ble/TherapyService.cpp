#include "TherapyService.h"
#include <Arduino.h>

//#define BYTE_ARRAY_SIZE = 5;

TherapyService::TherapyService() 
    : _service(THERAPY_CONTROL_SERVICE_UUID),
      _timeElapsedChar(TIME_ELAPSED_UUID, BLERead | BLENotify, sizeof(unsigned int)),
      //_timeElapsedChar(TIME_ELAPSED_UUID, BLERead | BLENotify),
      _intensityChar(INTENSITY_UUID, BLERead | BLEWrite | BLENotify, 3), // Set to 3 since 100% is the maximum
      _targetTimeChar(TARGET_TIME_UUID, BLERead | BLEWrite | BLENotify, sizeof(unsigned int)),
      _statusChar(STATUS_UUID, BLERead | BLENotify, 1), // Set to 1 since there will only be 2 modes
      _timeStampChar(TIME_STAMP_UUID, BLERead | BLEWrite, 20),
      _userIdChar(USER_ID_UUID, BLERead | BLEWrite, 50),
      _timeElapsedDesc(DESCRIPTION_UUID, "Time Elapsed in Seconds"),
      _intensityDesc(DESCRIPTION_UUID, "Intensity Percentage"),
      _targetTimeDesc(DESCRIPTION_UUID, "Target Time in Seconds") {}

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
}

void TherapyService::initializeValues() {
    unsigned int initialTime = 0;
    setTimeElapsed(initialTime);
    setIntensity(DeviceConfig::DEFAULT_INTENSITY);
    setTargetTime(DeviceConfig::DEFAULT_TARGET_TIME);
    setStatus(false);
    setTimeStamp("03-05-2025T00:00:00");
    setUserId("CJ_02");
}

void TherapyService::setTimeElapsed(unsigned int value) {
    byte byteArray[sizeof(unsigned int)];
    size_t length;

    BleUtils::uintToUtf8(value, byteArray, length);
    _timeElapsedChar.setValue(byteArray, length);
    
    // Debugging Messages
    /*     
    Serial.println("Time Elapsed Updating");
    for (int i = 0; i < length; i++) {
        Serial.printf("Value: %d | 0x%x\n", byteArray[i], byteArray[i]);
    }
    Serial.printf("Real Value: %d | 0x%x\n", value, value); 
    */
}

void TherapyService::setIntensity(byte value) {
    byte byteArray[3];
    size_t length;

    BleUtils::byteToUtf8(value, byteArray, length);
    _intensityChar.setValue(byteArray, length);
}

void TherapyService::setTargetTime(unsigned int value) {
    byte byteArray[sizeof(unsigned int)];
    size_t length;

    BleUtils::uintToUtf8(value, byteArray, length);
    _targetTimeChar.setValue(byteArray, length);
}

void TherapyService::setStatus(bool value) {
    byte byteArray[1];
    size_t length;

    BleUtils::boolToUtf8(value, byteArray, length);
    _statusChar.setValue(byteArray, length);
}

void TherapyService::setTimeStamp(const String& value) {
    _timeStampChar.setValue(value);
}

void TherapyService::setUserId(const String& value) {
    _userIdChar.setValue(value);
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