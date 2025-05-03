#include "TherapyService.h"
#include <Arduino.h>

//#define BYTE_ARRAY_SIZE = 5;

TherapyService::TherapyService() 
    : _service(THERAPY_CONTROL_SERVICE_UUID),
      //_timeElapsedChar(TIME_ELAPSED_UUID, BLERead | BLENotify, 5),
      _timeElapsedChar(TIME_ELAPSED_UUID, BLERead | BLENotify),
      _intensityChar(INTENSITY_UUID, BLERead | BLEWrite | BLENotify),
      _targetTimeChar(TARGET_TIME_UUID, BLERead | BLEWrite | BLENotify),
      _statusChar(STATUS_UUID, BLERead | BLENotify),
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
    //_timeElapsedChar.addDescriptor(_clientConfigDesc);
    _intensityChar.addDescriptor(_intensityDesc);
    //_intensityChar.addDescriptor(_clientConfigDesc);
    _targetTimeChar.addDescriptor(_targetTimeDesc);
    // _targetTimeChar.addDescriptor(_clientConfigDesc);
    
    // Add characteristics to service
    _service.addCharacteristic(_timeElapsedChar);
    _service.addCharacteristic(_intensityChar);
    _service.addCharacteristic(_targetTimeChar);
    _service.addCharacteristic(_statusChar);
    _service.addCharacteristic(_timeStampChar);
    _service.addCharacteristic(_userIdChar);
}

void TherapyService::initializeValues() {
    _timeElapsedChar.setValue(0);
    _intensityChar.setValue(DEFAULT_INTENSITY);
    _targetTimeChar.setValue(DEFAULT_TARGET_TIME);
    _statusChar.setValue(0); // Idle
    _timeStampChar.setValue("03-05-2025T00:00:00");
    _userIdChar.setValue("CJ_02");
}

void TherapyService::setTimeElapsed(unsigned int value) {
    byte byteArray[5]; // Maximum 6 bytes needed for UTF-8 representation of unsigned int
    size_t length;
    
    BleUtils::uintToUtf8Bytes(value, byteArray, length);
    //_timeElapsedChar.setValue(byteArray, length);

    Serial.println("Time Elapsed Updating");
    for (int i = 0; i < length; i++) {
        Serial.printf("Value: %d | 0x%x\n", byteArray[i], byteArray[i]);
    }
    Serial.printf("Real Value: %d | 0x%x\n", value, value);

    _timeElapsedChar.setValue(value);

}

void TherapyService::update() {
    // Placeholder for periodic updates
    static unsigned long lastUpdate = 0;
    const unsigned long updateInterval = 1000;
    
    if (millis() - lastUpdate >= updateInterval) {
        lastUpdate = millis();
        
        // Get current value by reading the byte array
        //const byte* currentValue = _timeElapsedChar.value();
        //size_t length = _timeElapsedChar.valueLength();
        
        // Convert back to unsigned int and increment timer
        unsigned int elapsedTime = 0;
        //memcpy(&elapsedTime, currentValue, sizeof(unsigned int));
        //elapsedTime = BleUtils::utf8BytesToUint(_timeElapsedChar.value(), 5);
        elapsedTime = _timeElapsedChar.value();
        elapsedTime++;
        setTimeElapsed(elapsedTime);
        //Serial.printf("Elapsed Time: %f", elapsedTime);
    }
}