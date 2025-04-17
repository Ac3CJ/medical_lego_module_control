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

import dbus

from advertisement import Advertisement
from service import Application, Service, Characteristic, Descriptor

GATT_CHRC_IFACE = "org.bluez.GattCharacteristic1"
NOTIFY_TIMEOUT = 5000

class TherapyAdvertisement(Advertisement):
    def __init__(self, index):
        Advertisement.__init__(self, index, "peripheral")
        self.add_local_name("Therapy Module")
        self.include_tx_power = True

class TherapyService(Service):
    THERAPY_SVC_UUID = "00000001-710e-4a5b-8d75-3e5b444bc3cf"

    def __init__(self, index):
        self.intensity = 0

        Service.__init__(self, index, self.THERAPY_SVC_UUID, True)
        self.add_characteristic(TimeCharacteristic(self))
        self.add_characteristic(IntensityCharacteristic(self))

    def set_intensity(self, intensity):
        self.intensity = intensity

class TimeCharacteristic(Characteristic):
    TIME_CHARACTERISTIC_UUID = "00000002-710e-4a5b-8d75-3e5b444bc3cf"

    def __init__(self, service):
        self.notifying = False

        Characteristic.__init__(
                self, self.TIME_CHARACTERISTIC_UUID,
                ["notify", "read"], service)
        self.add_descriptor(TimeDescriptor(self))

    def getTimeElapsed(self):
        value = []
        unit = "Seconds"

        moduleTime = 10


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

class IntensityCharacteristic(Characteristic):
    UNIT_CHARACTERISTIC_UUID = "00000003-710e-4a5b-8d75-3e5b444bc3cf"

    def __init__(self, service):
        Characteristic.__init__(
                self, self.UNIT_CHARACTERISTIC_UUID,
                ["read", "write"], service)
        self.add_descriptor(IntensityDescriptor(self))

    def WriteValue(self, value, options):
        self.service.set_intensity(value)

    def ReadValue(self, options):
        value = []

        val = 50
        value.append(dbus.Byte(val.encode()))

        return value

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

app = Application()
app.add_service(TherapyService(0))
app.register()

adv = TherapyAdvertisement(0)
adv.register()

try:
    app.run()
except KeyboardInterrupt:
    app.quit()
