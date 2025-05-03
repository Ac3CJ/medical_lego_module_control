#ifndef BLE_UTILS_H
#define BLE_UTILS_H

#include <ArduinoBLE.h>

#include "BleConfig.h"

class BleUtils {
public:
    // Convert unsigned int to UTF-8 byte array
    static void uintToUtf8Bytes(unsigned int value, byte* byteArray, size_t& length);
    
    // Convert UTF-8 byte array to unsigned int
    static unsigned int utf8BytesToUint(const byte* byteArray, size_t length);
    
    // Create a BLE characteristic with UTF-8 encoded unsigned int
    static BLECharacteristic createUtf8UintCharacteristic(const char* uuid, unsigned int properties, const char* description);
};

#endif