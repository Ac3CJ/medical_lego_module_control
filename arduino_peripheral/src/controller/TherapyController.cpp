#include <Arduino.h>
#include "TherapyController.h"

TherapyController::TherapyController()
    : _targetTime(0), _intensity(0), _therapyActive(false),
      _therapyStartTime(0), _elapsedTime(0), _batteryLife(0x64),
      _therapyService(nullptr), _moduleInfoService(nullptr),
      _lastBleSyncTime(0), _lastBatteryUpdate(0),
      _status("Inactive") {
}

// ============================== GETTERS ==============================
bool TherapyController::getIsTherapyActive() {
    return _therapyActive;
}

// ============================== SETTERS ==============================
void TherapyController::setTherapyService(TherapyService* service) {
    _therapyService = service;
}

void TherapyController::setModuleInfoService(ModuleInfoService* service) {
    _moduleInfoService = service;
}

// ============================== CHARACTERISTIC UPDATE CALLBACKS ==============================
void TherapyController::onTargetTimeUpdated(unsigned int targetTime) {
    _targetTime = targetTime;
    Serial.print("Controller: Target time updated: ");
    Serial.println(_targetTime);
}

void TherapyController::onIntensityUpdated(byte intensity) {
    _intensity = intensity;
    Serial.print("Controller: Intensity updated: ");
    Serial.println(_intensity);
}

void TherapyController::onTimeStampUpdated(const String& timeStamp) {
    _timeStamp = timeStamp;
    Serial.print("Controller: Time stamp updated: ");
    Serial.println(_timeStamp);
}

void TherapyController::onUserIdUpdated(const String& userId) {
    _userId = userId;
    Serial.print("Controller: User ID updated: ");
    Serial.println(_userId);
}

// ============================== GENERAL METHODS ==============================

void TherapyController::startTherapy() {
    if (_therapyActive) return;
    _therapyActive = true;
    _therapyStartTime = millis();
    _elapsedTime = 0;
    _status = "Active";
    Serial.println("Therapy started");

    if (_therapyService) _therapyService->setStatus(_status);
}

void TherapyController::stopTherapy() {
    if (!_therapyActive) return;
    _therapyActive = false;
    Serial.println("Therapy stopped");

    _intensity = 0;
    _targetTime = 0;
    _status = "Inactive";
    if (_therapyService) {
        // Bump these values
        _therapyService->setIntensity(1);
        _therapyService->setTargetTime(1);
        delay(10);
        _therapyService->setIntensity(0);
        _therapyService->setTargetTime(0);
        _therapyService->setStatus(_status);
        _therapyService->setTimeElapsed(_elapsedTime);
    }

    // Reset elapsed time
    _elapsedTime = 0;

    // Force BLE status sync
    updateBleStatus();
}

void TherapyController::update() {
    // =================== ACTIVE THERAPY ===================
    if (_therapyActive) {
        _elapsedTime = (millis() - _therapyStartTime) / 1000;

        if (_status != "Active") {
            _status = "Active";
            _therapyService->setStatus(_status);
        }

        // Check to stop therapy
        if (_elapsedTime >= _targetTime) stopTherapy(); 
    } 

    // =================== INACTIVE MODE ===================
    else {
        _elapsedTime = 0;

        if (_status != "Inactive") {
            _status = "Inactive";
            _therapyService->setStatus(_status);
        }

        // Check to start therapy
        if (_intensity > 0 && _targetTime > 0) startTherapy();
    }
    updateBattery();
    updateBleValues();
}

void TherapyController::updateBleStatus() {
    if (_therapyService) {
        _therapyService->setTimeElapsed(_elapsedTime);
        _therapyService->setTargetTime(_targetTime);
        _therapyService->setIntensity(_intensity);
        _therapyService->setTimeStamp(_timeStamp);
        _therapyService->setUserId(_userId);
        _therapyService->setStatus(_status);
    }
    if (_moduleInfoService) {
        _moduleInfoService->setBatteryLife(_batteryLife);
    }
}

void TherapyController::updateBattery() {
    if (!_moduleInfoService) return;  // Safety check

    if (millis() - _lastBatteryUpdate >= _batteryUpdateInterval) {
        if (_batteryLife > 0) _batteryLife--;
        else _batteryLife = 0x64;
        _lastBatteryUpdate = millis();
    }
}

void TherapyController::updateBleValues() {
    if (millis() - _lastBleSyncTime >= _bleSyncInterval) {
        Serial.printf("Device %s | ", _status);
        Serial.printf("Time: %d Intensity: %d Target Time: %d Battery: %d\n", _elapsedTime, _intensity, _targetTime, _batteryLife);
        updateBleStatus();
        _lastBleSyncTime = millis();
    }
}