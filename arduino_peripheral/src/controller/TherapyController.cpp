#include <Arduino.h>
#include "TherapyController.h"

TherapyController::TherapyController()
    : _targetTime(0), _intensity(0), _therapyActive(false),
      _therapyStartTime(0), _elapsedTime(0), _therapyService(nullptr), _moduleInfoService(nullptr),
      _lastBleSyncTime(0) {
}

bool TherapyController::getIsTherapyActive() {
    return _therapyActive;
}

void TherapyController::setTherapyService(TherapyService* service) {
    _therapyService = service;
}

void TherapyController::setModuleInfoService(ModuleInfoService* service) {
    _moduleInfoService = service;
}

void TherapyController::onTargetTimeUpdated(unsigned int targetTime) {
    _targetTime = targetTime;
    Serial.print("Controller: Target time updated: ");
    Serial.println(_targetTime);

    // Start therapy if intensity is also set
    if (_intensity > 0 && !_therapyActive) {
        startTherapy();
    }

    updateBleStatus();
}

void TherapyController::onIntensityUpdated(byte intensity) {
    _intensity = intensity;
    Serial.print("Controller: Intensity updated: ");
    Serial.println(_intensity);

    // Start therapy if target time is also set
    if (_targetTime > 0 && !_therapyActive) {
        startTherapy();
    }

    updateBleStatus();
}

void TherapyController::onTimeStampUpdated(const String& timeStamp) {
    _timeStamp = timeStamp;
    Serial.print("Controller: Time stamp updated: ");
    Serial.println(_timeStamp);

    updateBleStatus();
}

void TherapyController::onUserIdUpdated(const String& userId) {
    _userId = userId;
    Serial.print("Controller: User ID updated: ");
    Serial.println(_userId);

    updateBleStatus();
}

void TherapyController::startTherapy() {
    if (_therapyActive) return;
    _therapyActive = true;
    _therapyStartTime = millis();
    _elapsedTime = 0;
    Serial.println("Therapy started");

    _therapyService->setStatus("Active");
}

void TherapyController::stopTherapy() {
    if (!_therapyActive) return;
    _therapyActive = false;
    Serial.println("Therapy stopped");

    if (_therapyService) {
        //_intensity = 0;
        //_targetTime = 0;
        
        //_therapyService->setIntensity(0);
        //_therapyService->setTargetTime((unsigned int) 0);
        _therapyService->setStatus("Inactive");
        _therapyService->setTimeElapsed(_elapsedTime);
    }
}

void TherapyController::update() {
    if (_therapyActive) {
        _elapsedTime = (millis() - _therapyStartTime) / 1000;
        

        // Check if it's time to sync BLE values
        if (millis() - _lastBleSyncTime >= _bleSyncInterval) {
            updateBleStatus();
            _lastBleSyncTime = millis();
            Serial.printf("Time: %d\tIntensity: %d\tTarget Time: %d\n", _elapsedTime, _intensity, _targetTime);
        }

        if (_elapsedTime >= _targetTime) {
            stopTherapy();
        }
    } else { // Inactivite State
        _therapyService->setStatus("Inactive");
        _elapsedTime = 0;

        // Sync BLE
        if (millis() - _lastBleSyncTime >= _bleSyncInterval) {
            updateBleStatus();
            _lastBleSyncTime = millis();
        }
    }
}

void TherapyController::updateBleStatus() {
    if (_therapyService) {
        _therapyService->setTimeElapsed(_elapsedTime);
        _therapyService->setTargetTime(_targetTime);
        _therapyService->setIntensity(_intensity);
        _therapyService->setTimeStamp(_timeStamp);
        _therapyService->setUserId(_userId);
    }
}
