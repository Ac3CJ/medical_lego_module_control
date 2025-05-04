#ifndef BLE_MANAGER_H
#define BLE_MANAGER_H

#include <ArduinoBLE.h>

#include "BleConfig.h"
#include "TherapyService.h"
#include "ModuleInfoService.h"
#include "controller/TherapyController.h"

class BleManager {
public:
    BleManager(TherapyService& therapyService, ModuleInfoService& moduleInfoService, TherapyController& therapyController);
    bool begin();
    void update();
    void advertise();
    
private:
    TherapyService& _therapyService;
    ModuleInfoService& _moduleInfoService;
    TherapyController& _therapyController;
    
    void setupBle();
    void setConnectionParameters();
    void linkServiceAndController();
};

#endif