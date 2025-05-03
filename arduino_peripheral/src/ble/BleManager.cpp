#include "BleManager.h"

BleManager::BleManager(TherapyService& therapyService, ModuleInfoService& moduleInfoService) 
    : _therapyService(therapyService), _moduleInfoService(moduleInfoService) {}

bool BleManager::begin() {
    if (!BLE.begin()) {
        return false;
    }
    
    setupBle();
    setConnectionParameters();
    return true;
}

void BleManager::setupBle() {
    BLE.setDeviceName(DEVICE_NAME);
    BLE.setLocalName(DEVICE_NAME);
    BLE.setAppearance(0x0000); // Generic appearance
    
    // Add services
    _therapyService.setupService();
    _moduleInfoService.setupService();
    
    BLE.addService(_therapyService.getService());
    BLE.addService(_moduleInfoService.getService());
}

void BleManager::setConnectionParameters() {
    BLE.setConnectionInterval(0x001E, 0x001E); // 30ms
    BLE.setSupervisionTimeout(500); // 5 seconds
}

void BleManager::update() {
    BLE.poll();
}

void BleManager::advertise() {
    BLE.advertise();
}