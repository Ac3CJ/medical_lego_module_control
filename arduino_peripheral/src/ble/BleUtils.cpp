#include "BleUtils.h"
#include <Arduino.h>

void BleUtils::uintToUtf8Bytes(unsigned int value, byte* byteArray, size_t& length) {
    String strValue = String(value);
    length = strValue.length();
    memcpy(byteArray, strValue.c_str(), length);
}

unsigned int BleUtils::utf8BytesToUint(const byte* byteArray, size_t length) {
    char strValue[length + 1];
    memcpy(strValue, byteArray, length);
    strValue[length] = '\0';
    return atoi(strValue);
}

BLECharacteristic BleUtils::createUtf8UintCharacteristic(const char* uuid, unsigned int properties, const char* description) {
    BLECharacteristic characteristic(uuid, properties, 6); // Max 6 bytes
    BLEDescriptor desc(DESCRIPTION_UUID, description);
    characteristic.addDescriptor(desc);
    return characteristic;
}