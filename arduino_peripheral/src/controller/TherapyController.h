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

    bool _therapyActive;
    unsigned long _therapyStartTime;  // millis()
    unsigned int _elapsedTime;

    unsigned long _lastBleSyncTime;
    const unsigned long _bleSyncInterval = 1000;  // 1 second

    TherapyService* _therapyService;  // pointer back to BLE service
    ModuleInfoService* _moduleInfoService;

    void updateBleStatus();  // push updates to BLE
};

#endif // THERAPY_CONTROLLER_H
