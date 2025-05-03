#ifndef BLE_MANAGER_H
#define BLE_MANAGER_H

#include <ArduinoBLE.h>
#include "BleConfig.h"
#include "TherapyService.h"
#include "ModuleInfoService.h"

class BleManager {
public:
    BleManager(TherapyService& therapyService, ModuleInfoService& moduleInfoService);
    bool begin();
    void update();
    void advertise();
    
private:
    TherapyService& _therapyService;
    ModuleInfoService& _moduleInfoService;
    
    void setupBle();
    void setConnectionParameters();
};

#endif