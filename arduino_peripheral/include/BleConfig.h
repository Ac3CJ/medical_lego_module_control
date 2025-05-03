#ifndef CONFIG_H
#define CONFIG_H

// ========================================== Service UUIDs ==========================================
#define THERAPY_CONTROL_SERVICE_UUID "00000001-710e-4a5b-8d75-3e5b444bc3cf"
#define MODULE_INFO_SERVICE_UUID     "00000011-710e-4a5b-8d75-3e5b444bc3cf"

// ========================================== Characteristic UUIDs ==========================================
// Therapy Control Characteristics
#define TIME_ELAPSED_UUID    "00000002-710e-4a5b-8d75-3e5b444bc3cf"
#define INTENSITY_UUID       "00000003-710e-4a5b-8d75-3e5b444bc3cf"
#define TARGET_TIME_UUID     "00000004-710e-4a5b-8d75-3e5b444bc3cf"
#define STATUS_UUID          "00000005-710e-4a5b-8d75-3e5b444bc3cf"
#define TIME_STAMP_UUID      "00000006-710e-4a5b-8d75-3e5b444bc3cf"
#define USER_ID_UUID         "00000007-710e-4a5b-8d75-3e5b444bc3cf"

// Module Info Characteristics
#define DEVICE_ID_UUID        "00000012-710e-4a5b-8d75-3e5b444bc3cf"
#define LOCATION_ID_UUID      "00000013-710e-4a5b-8d75-3e5b444bc3cf"
#define BATTERY_LIFE_UUID     "00000014-710e-4a5b-8d75-3e5b444bc3cf"
#define FIRMWARE_VERSION_UUID "00000015-710e-4a5b-8d75-3e5b444bc3cf"

// Descriptor UUIDs
#define DESCRIPTION_UUID     "2901"
#define CLIENT_CONFIG_UUID   "2902"

// Device Configuration
#define DEVICE_NAME "LM Health Physical"
#define DEFAULT_INTENSITY 50
#define DEFAULT_TARGET_TIME 300 // 5 minutes

#endif