#include "BleUtils.h"
#include <Arduino.h>

// Convert Unsigned Int
void BleUtils::uintToUtf8(unsigned int value, byte* byteArray, size_t& length) {
    String strValue = String(value);
    length = strValue.length();
    memcpy(byteArray, strValue.c_str(), length);
}

unsigned int BleUtils::utf8ToUint(const byte* byteArray, size_t length) {
    char strValue[length + 1];
    memcpy(strValue, byteArray, length);
    strValue[length] = '\0';
    return atoi(strValue);
}

// Convert Bytes
void BleUtils::byteToUtf8(byte value, byte* utf8Bytes, size_t& length) {
    String strValue = String(value);
    length = strValue.length();
    memcpy(utf8Bytes, strValue.c_str(), length);
}

byte BleUtils::utf8ToByte(const byte* utf8Bytes, size_t length) {
    char strValue[length + 1];
    memcpy(strValue, utf8Bytes, length);
    strValue[length] = '\0';
    int value = atoi(strValue);
    return (byte)(value & 0xFF); // Ensure we return only a byte
}

// Convert Bool
void BleUtils::boolToUtf8(bool value, byte* utf8Bytes, size_t& length) {
    utf8Bytes[0] = value ? '1' : '0'; // 0x31 for true, 0x30 for false
    length = 1;
}

bool BleUtils::utf8ToBool(const byte* utf8Bytes, size_t length) {
    // Only check first byte, ignore any additional bytes
    return (utf8Bytes[0] == '1'); // true if first byte is '1' (0x31)
}

BLECharacteristic BleUtils::createUtf8UintCharacteristic(const char* uuid, unsigned int properties, const char* description) {
    BLECharacteristic characteristic(uuid, properties, 6); // Max 6 bytes
    BLEDescriptor desc(DESCRIPTION_UUID, description);
    characteristic.addDescriptor(desc);
    return characteristic;
}