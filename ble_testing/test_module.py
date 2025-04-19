#!/usr/bin/python3

"""Copyright (c) 2019, Douglas Otwell

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
Found From: https://github.com/Douglas6/cputemp/blob/master/cputemp.py
"""

""" Service & Characteristic Hierarchy
- Module Information Service
    - Module ID
    - Module Status
    - Module Location
    - Module Battery Life
    - Module Firmware Version

- Therapy Service
    - Therapy time
    - Therapy Intensity

"""

# Bluetooth Related
import dbus
from advertisement import Advertisement
from service import Application, Service, Characteristic, Descriptor

# Functionality 
import time
import threading

GATT_CHRC_IFACE = "org.bluez.GattCharacteristic1"
NOTIFY_TIMEOUT = 5000

class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

# ===============================================================================================================
# =============================================== ADVERTISEMENT =================================================
# ===============================================================================================================

class TherapyAdvertisement(Advertisement):
    def __init__(self, index):
        Advertisement.__init__(self, index, "peripheral")
        self.add_local_name("LMTherapy-Module")
        self.include_tx_power = True

# ===============================================================================================================
# =============================================== INFO SERVICE ==================================================
# ===============================================================================================================

class InfoService(Service):
    THERAPY_SVC_UUID = "00000011-710e-4a5b-8d75-3e5b444bc3cf"

    def __init__(self, index):
        self.intensity = 0
        self.timeElapsed = 0
        self.targetTime = 0
        self.isTherapyActive = False

        Service.__init__(self, index, self.THERAPY_SVC_UUID, True)
        self.add_characteristic(DeviceIdCharacteristic(self))
        self.add_characteristic(LocationIdCharacteristic(self))

    # Setters

    # Getters

# =============================================== CHARACTERISTICS ===============================================


class DeviceIdCharacteristic(Characteristic):
    DEVICE_ID_CHARACTERISTIC_UUID = "00000012-710e-4a5b-8d75-3e5b444bc3cf"
    DEVICE_ID_CHARACTERISTIC_VALUE = "TMP-001"

    def __init__(self, service):
        Characteristic.__init__(
                self, self.DEVICE_ID_CHARACTERISTIC_UUID,
                ["read"],
                service)

    def ReadValue(self, options):
        value = []
        desc = self.DEVICE_ID_CHARACTERISTIC_VALUE

        for c in desc:
            value.append(dbus.Byte(c.encode()))

        return value

class LocationIdCharacteristic(Characteristic):
    LOCATION_ID_CHARACTERISTIC_UUID = "00000013-710e-4a5b-8d75-3e5b444bc3cf"
    LOCATION_ID_CHARACTERISTIC_VALUE = "01"

    def __init__(self, service):
        Characteristic.__init__(
                self, self.LOCATION_ID_CHARACTERISTIC_UUID,
                ["read"],
                service)

    def ReadValue(self, options):
        value = []
        desc = self.LOCATION_ID_CHARACTERISTIC_VALUE

        for c in desc:
            value.append(dbus.Byte(c.encode()))

        return value

# ===============================================================================================================
# =============================================== THERAPY SERVICE ===============================================
# ===============================================================================================================

class TherapyService(Service):
    THERAPY_SVC_UUID = "00000001-710e-4a5b-8d75-3e5b444bc3cf"

    def __init__(self, index):
        self.intensity = 0
        self.timeElapsed = 0
        self.targetTime = 0
        self.isTherapyActive = False

        Service.__init__(self, index, self.THERAPY_SVC_UUID, True)

        # Initialise Characteristics
        self.add_characteristic(TimeCharacteristic(self))
        self.add_characteristic(IntensityCharacteristic(self))
        self.add_characteristic(TargetTimeCharacteristic(self))
        self.add_characteristic(StatusCharacteristic(self))

    # Setters
    def setTimeElapsed(self, timeElapsed):
        self.timeElapsed = timeElapsed
        
    def setIntensity(self, intensity):
        self.intensity = intensity

    def setTargetTime(self, targetTime):
        self.targetTime = targetTime

    def setIsTherapyActive(self, isTherapyActive):
        self.isTherapyActive = isTherapyActive

    # Getters
    def getTimeElapsed(self):
        return self.timeElapsed

    def getIntensity(self):
        return self.intensity
    
    def getTargetTime(self):
        return self.targetTime
    
    def getIsTherapyActive(self):
        return self.isTherapyActive

# =============================================== TIME TRACKING CHARACTERISTIC ===============================================

class TimeCharacteristic(Characteristic):
    TIME_CHARACTERISTIC_UUID = "00000002-710e-4a5b-8d75-3e5b444bc3cf"

    def __init__(self, service):
        self.notifying = False
        self.startTime = time.time()
        self.moduleTime = 0

        Characteristic.__init__(
                self, self.TIME_CHARACTERISTIC_UUID,
                ["notify", "read"], service)
        self.add_descriptor(TimeDescriptor(self))

        # Start the background reset thread
        self.reset_thread = threading.Thread(target=self.reset_loop, daemon=True)
        self.reset_thread.start()

    def reset_loop(self):
        while True:
            time.sleep(1)
            if ((time.time() - self.startTime) >= self.service.getTargetTime()) and (self.service.getIsTherapyActive()):
                print(f"{bcolors.HEADER}[INFO] Resetting intensity and timeElapsed after {self.service.getTargetTime()}s of inactivity.{bcolors.ENDC}")

                # Reset Other Characteristics
                self.service.setIntensity(0)
                self.service.setTargetTime(0)
                self.service.setIsTherapyActive(False)

                # Reset Local Vars
                self.timeElapsed = 0
                self.targetTime = 0
                self.startTime = time.time()

    def getTimeElapsed(self):
        value = []
        unit = "Seconds"
        currentTime = time.time()

        moduleTime = round(currentTime - self.startTime)

        if (not self.service.getIsTherapyActive()):
            moduleTime = 0
            self.startTime = time.time()

        self.service.setTimeElapsed(moduleTime)

        # Convert to Byte String
        strModuleTime = str(moduleTime) + " " + unit
        for c in strModuleTime:
            value.append(dbus.Byte(c.encode()))
        return value

    def setTimeElapsedCallback(self):
        if self.notifying:
            value = self.getTimeElapsed()
            self.PropertiesChanged(GATT_CHRC_IFACE, {"Value": value}, [])
        return self.notifying

    def StartNotify(self):
        if self.notifying:
            return

        self.notifying = True

        value = self.getTimeElapsed()
        self.PropertiesChanged(GATT_CHRC_IFACE, {"Value": value}, [])
        self.add_timeout(NOTIFY_TIMEOUT, self.setTimeElapsedCallback)

    def StopNotify(self):
        self.notifying = False

    def ReadValue(self, options):
        value = self.getTimeElapsed()
        return value

class TimeDescriptor(Descriptor):
    TIME_DESCRIPTOR_UUID = "2901"
    TIME_DESCRIPTOR_VALUE = "Time Elapsed"

    def __init__(self, characteristic):
        Descriptor.__init__(
                self, self.TIME_DESCRIPTOR_UUID,
                ["read"],
                characteristic)

    def ReadValue(self, options):
        value = []
        desc = self.TIME_DESCRIPTOR_VALUE

        for c in desc:
            value.append(dbus.Byte(c.encode()))

        return value

# =============================================== INTENSITY CHARACTERISTIC ===============================================

class IntensityCharacteristic(Characteristic):
    UNIT_CHARACTERISTIC_UUID = "00000003-710e-4a5b-8d75-3e5b444bc3cf"

    def __init__(self, service):
        self.notifying = False
        self.intensity = 0

        Characteristic.__init__(
                self, self.UNIT_CHARACTERISTIC_UUID,
                ["notify", "read", "write"], service)
        self.add_descriptor(IntensityDescriptor(self))

    def getIntensity(self):
        value = []
        strValue = str(self.intensity) + "%"
        for c in strValue:
            value.append(dbus.Byte(c.encode()))
        return value

    def setIntensityCallback(self):
        if self.notifying:
            self.intensity = self.service.getIntensity()

            value = self.getIntensity()
            self.PropertiesChanged(GATT_CHRC_IFACE, {"Value": value}, [])

        return self.notifying

    def StartNotify(self):
        if self.notifying:
            return

        self.notifying = True

        self.intensity = self.service.getIntensity()

        value = self.getIntensity()
        self.PropertiesChanged(GATT_CHRC_IFACE, {"Value": value}, [])
        self.add_timeout(NOTIFY_TIMEOUT, self.setIntensityCallback)

    def StopNotify(self):
        self.notifying = False

    def ReadValue(self, options):
        value = self.getIntensity()
        return value
    
    def WriteValue(self, value, options):
        try:
            strValue = ''.join([chr(byte) for byte in value])
            newIntensity = int(strValue)

            self.intensity = newIntensity
            self.service.setIntensity(newIntensity)  # Update in parent service

            # Check to make sure Therapy doesn't start prematurely
            if (self.service.getTargetTime() > 0):
                self.service.setIsTherapyActive(True)
                print(f"{bcolors.OKGREEN}[INFO] Therapy Started{bcolors.ENDC}")
            else:
                print(f"{bcolors.WARNING}[INFO] Awaiting Therapy Target Time{bcolors.ENDC}")

            self.PropertiesChanged(GATT_CHRC_IFACE, {"Value": self.ReadValue({})}, [])

            print(f"[INFO] Intensity updated to: {self.intensity}")

        except Exception as e:
            print(f"[ERROR] Failed to write Intensity value: {e}")

class IntensityDescriptor(Descriptor):
    INTENSITY_DESCRIPTOR_UUID = "2901"
    INTENSITY_DESCRIPTOR_VALUE = "Intensity"

    def __init__(self, characteristic):
        Descriptor.__init__(
                self, self.INTENSITY_DESCRIPTOR_UUID,
                ["read"],
                characteristic)

    def ReadValue(self, options):
        value = []
        desc = self.INTENSITY_DESCRIPTOR_VALUE

        for c in desc:
            value.append(dbus.Byte(c.encode()))

        return value

# =============================================== TARGET TIME CHARACTERISTIC ===============================================

class TargetTimeCharacteristic(Characteristic):
    UNIT_CHARACTERISTIC_UUID = "00000004-710e-4a5b-8d75-3e5b444bc3cf"

    def __init__(self, service):
        self.notifying = False
        self.targetTime = 0

        Characteristic.__init__(
                self, self.UNIT_CHARACTERISTIC_UUID,
                ["notify", "read", "write"], service)
        self.add_descriptor(TargetTimeDescriptor(self))

    def getTargetTime(self):
        value = []
        strValue = str(self.targetTime) + " Seconds"
        for c in strValue:
            value.append(dbus.Byte(c.encode()))
        return value

    def setTargetTimeCallback(self):
        if self.notifying:
            self.targetTime = self.service.getTargetTime()

            value = self.getTargetTime()
            self.PropertiesChanged(GATT_CHRC_IFACE, {"Value": value}, [])

        return self.notifying

    def StartNotify(self):
        if self.notifying:
            return

        self.notifying = True

        self.targetTime = self.service.getTargetTime()

        value = self.getTargetTime()
        self.PropertiesChanged(GATT_CHRC_IFACE, {"Value": value}, [])
        self.add_timeout(NOTIFY_TIMEOUT, self.setTargetTimeCallback)

    def StopNotify(self):
        self.notifying = False

    def ReadValue(self, options):
        value = self.getTargetTime()
        return value
    
    def WriteValue(self, value, options):
        try:
            strValue = ''.join([chr(byte) for byte in value])
            newTargetTime = int(strValue)

            self.targetTime = newTargetTime
            self.service.setTargetTime(newTargetTime)  # Update in parent service

            # Check to make sure Therapy doesn't start prematurely
            if (self.service.getIntensity() > 0):
                self.service.setIsTherapyActive(True)
                print(f"{bcolors.OKGREEN}[INFO] Therapy Started{bcolors.ENDC}")
            else:
                print(f"{bcolors.WARNING}[INFO] Awaiting Therapy Intensity{bcolors.ENDC}")

            self.PropertiesChanged(GATT_CHRC_IFACE, {"Value": self.ReadValue({})}, [])

            print(f"[INFO] Target Time updated to: {self.targetTime}")

        except Exception as e:
            print(f"[ERROR] Failed to write Target Time value: {e}")

class TargetTimeDescriptor(Descriptor):
    TARGET_TIME_DESCRIPTOR_UUID = "2901"
    TARGET_TIME_DESCRIPTOR_VALUE = "Target Time"

    def __init__(self, characteristic):
        Descriptor.__init__(
                self, self.TARGET_TIME_DESCRIPTOR_UUID,
                ["read"],
                characteristic)

    def ReadValue(self, options):
        value = []
        desc = self.TARGET_TIME_DESCRIPTOR_VALUE

        for c in desc:
            value.append(dbus.Byte(c.encode()))

        return value
    
# =============================================== STATUS CHARACTERISTIC ===============================================

class StatusCharacteristic(Characteristic):
    UNIT_CHARACTERISTIC_UUID = "00000005-710e-4a5b-8d75-3e5b444bc3cf"

    def __init__(self, service):
        self.notifying = False
        self.status = ""

        Characteristic.__init__(
                self, self.UNIT_CHARACTERISTIC_UUID,
                ["notify", "read"], service)
        self.add_descriptor(TargetTimeDescriptor(self))

    def getStatus(self):
        value = []
        
        self.status = "Inactive"
        if (self.service.getIsTherapyActive()):
            self.status = "Active"

        strValue = self.status
        for c in strValue:
            value.append(dbus.Byte(c.encode()))
        return value

    def setTargetTimeCallback(self):
        if self.notifying:

            value = self.getStatus()
            self.PropertiesChanged(GATT_CHRC_IFACE, {"Value": value}, [])

        return self.notifying

    def StartNotify(self):
        if self.notifying:
            return

        self.notifying = True

        value = self.getStatus()
        self.PropertiesChanged(GATT_CHRC_IFACE, {"Value": value}, [])
        self.add_timeout(NOTIFY_TIMEOUT, self.setTargetTimeCallback)

    def StopNotify(self):
        self.notifying = False

    def ReadValue(self, options):
        value = self.getStatus()
        return value
    

# =============================================== MAIN CODE ===============================================

app = Application()
app.add_service(TherapyService(0))
app.add_service(InfoService(1))
app.register()

adv = TherapyAdvertisement(0)
adv.register()

try:
    app.run()
except KeyboardInterrupt:
    app.quit()
