#ifndef THERAPY_CONTROLLER_H
#define THERAPY_CONTROLLER_H

#include <Arduino.h>
#include "ble/TherapyService.h"
#include "ble/ModuleInfoService.h"

// Forward declare TherapyService
class TherapyService;
class ModuleInfoService;

class TherapyController {
public:
    TherapyController();

    // Link back to the BLE service (set after both are constructed)
    void setTherapyService(TherapyService* service);
    void setModuleInfoService(ModuleInfoService* service);

    // Callbacks from TherapyService
    void onTargetTimeUpdated(unsigned int targetTime);
    void onIntensityUpdated(byte intensity);
    void onTimeStampUpdated(const String& timeStamp);
    void onUserIdUpdated(const String& userId);

    // Control functions
    void startTherapy();
    void stopTherapy();
    void update();  // called in loop()

    bool getIsTherapyActive();

private:
    // Internal state
    unsigned int _targetTime;
    byte _intensity;
    String _timeStamp;
    String _userId;
    byte _batteryLife;
    String _status;

    bool _therapyActive;
    unsigned long _therapyStartTime;  // millis()
    unsigned int _elapsedTime;

    //String _lastStatus;

    // Value Updating Intervales
    unsigned long _lastBleSyncTime;
    const unsigned long _bleSyncInterval = 1000;  // 1 second

    unsigned long _lastBatteryUpdate = 0;
    const unsigned long _batteryUpdateInterval = 5000; // 5 seconds

    // Pointers for Services
    TherapyService* _therapyService;
    ModuleInfoService* _moduleInfoService;

    void updateBleStatus();  // push updates to BLE

    // Interval Based Update Methods
    void updateBattery();
    void updateBleValues();
};

#endif // THERAPY_CONTROLLER_H
