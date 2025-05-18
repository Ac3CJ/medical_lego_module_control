#include <Arduino.h>
#include <ArduinoBLE.h>

#include "ble/BleManager.h"
#include "ble/TherapyService.h"
#include "ble/ModuleInfoService.h"

#include "controller/TherapyController.h"

TherapyService therapyService;
ModuleInfoService moduleInfoService;
TherapyController therapyController;
BleManager bleManager(therapyService, moduleInfoService, therapyController);

void linkCallbackAndController() {
  // BLE writes -> Controller callbacks
  therapyService.setTargetTimeCallback([](unsigned int targetTime) {
      therapyController.onTargetTimeUpdated(targetTime);
  });
  therapyService.setIntensityCallback([](byte intensity) {
      therapyController.onIntensityUpdated(intensity);
  });
  therapyService.setTimeStampCallback([](const String& timeStamp) {
      therapyController.onTimeStampUpdated(timeStamp);
  });
  therapyService.setUserIdCallback([](const String& userId) {
      therapyController.onUserIdUpdated(userId);
  });

  // Controller -> Service feedback
  therapyController.setTherapyService(&therapyService);
  therapyController.setModuleInfoService(&moduleInfoService);
}

void setup() {
  // put your setup code here, to run once:
  Serial.begin(9600);
  pinMode(LED_BUILTIN, OUTPUT);

  if (!bleManager.begin()) {
    Serial.println("BLE initialization failed!");
    while (1);
  }

  bleManager.advertise();
  Serial.println("BLE Therapy Device Ready");

  linkCallbackAndController();
}

void loop() {
  bleManager.update();
  therapyController.update();
  //moduleInfoService.update();

  if (therapyController.getIsTherapyActive()) digitalWrite(LED_BUILTIN, HIGH);
  else digitalWrite(LED_BUILTIN, LOW);
  
}