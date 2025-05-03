#ifndef BLE_UTILS_H
#define BLE_UTILS_H

#include <ArduinoBLE.h>

#include "BleConfig.h"

class BleUtils {
public:
    // Convert unsigned int to UTF-8 byte array
    static void uintToUtf8(unsigned int value, byte* byteArray, size_t& length);
    
    // Convert UTF-8 byte array to unsigned int
    static unsigned int utf8ToUint(const byte* byteArray, size_t length);

    static void byteToUtf8(byte value, byte* utf8Bytes, size_t& length);

    static byte utf8ToByte(const byte* utf8Bytes, size_t length);
    
    static void boolToUtf8(bool value, byte* utf8Bytes, size_t& length);

    static bool utf8ToBool(const byte* utf8Bytes, size_t length);
    // Create a BLE characteristic with UTF-8 encoded unsigned int
    static BLECharacteristic createUtf8UintCharacteristic(const char* uuid, unsigned int properties, const char* description);
};

#endif