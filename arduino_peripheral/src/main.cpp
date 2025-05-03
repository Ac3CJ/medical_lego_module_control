#include <Arduino.h>
#include <ArduinoBLE.h>

#include "ble/BleManager.h"
#include "ble/TherapyService.h"
#include "ble/ModuleInfoService.h"

TherapyService therapyService;
ModuleInfoService moduleInfoService;
BleManager bleManager(therapyService, moduleInfoService);

void setup() {
  // put your setup code here, to run once:
  Serial.begin(9600);

  if (!bleManager.begin()) {
    Serial.println("BLE initialization failed!");
    while (1);
  }

  bleManager.advertise();
  Serial.println("BLE Therapy Device Ready");
}

void loop() {
  bleManager.update();
  therapyService.update();
  moduleInfoService.update();
  //Serial.println("TEST2");
}