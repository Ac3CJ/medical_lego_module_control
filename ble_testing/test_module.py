#!/usr/bin/python3

# Bluetooth Related
import dbus
from advertisement import Advertisement
from service import Application, Service, Characteristic, Descriptor

# Functionality 
import time
import threading

GATT_CHRC_IFACE = "org.bluez.GattCharacteristic1"
NOTIFY_TIMEOUT = 5000

VIRTUAL_DEVICE_NAME = "LM Health Virtual"
VIRTUAL_DEVICE_ID = "TMP-VIR"
VIRTUAL_LOCATION = 1

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

# =============================================== HELPER FUNCTIONS ===============================================
def print_progress_bar(iteration, total, prefix='', suffix='', length=30, fill='█'):
    """
    Call in a loop to create terminal progress bar
    @params:
        iteration   - Required  : current iteration (Int)
        total       - Required  : total iterations (Int)
        prefix      - Optional  : prefix string (Str)
        suffix      - Optional  : suffix string (Str)
        length      - Optional  : character length of bar (Int)
        fill        - Optional  : bar fill character (Str)
    """
    percent = ("{0:.1f}").format(100 * (iteration / float(total)))
    filled_length = int(length * iteration // total)
    bar = fill * filled_length + '-' * (length - filled_length)
    print(f'\r{prefix} |{bar}| {percent}% {suffix}', end='\r')
    # Print New Line on Complete
    if iteration == total: 
        print()         

# ===============================================================================================================
# =============================================== ADVERTISEMENT =================================================
# ===============================================================================================================

class TherapyAdvertisement(Advertisement):
    def __init__(self, index):
        Advertisement.__init__(self, index, "peripheral")
        # self.add_local_name("LMTherapy-Module")
        self.add_local_name(VIRTUAL_DEVICE_NAME)
        self.include_tx_power = True

# ===============================================================================================================
# =============================================== INFO SERVICE ==================================================
# ===============================================================================================================

class InfoService(Service):
    THERAPY_SVC_UUID = "00000011-710e-4a5b-8d75-3e5b444bc3cf"

    def __init__(self, index):

        Service.__init__(self, index, self.THERAPY_SVC_UUID, True)
        self.add_characteristic(DeviceIdCharacteristic(self))
        self.add_characteristic(LocationIdCharacteristic(self))
        self.add_characteristic(BatteryLifeCharacteristic(self))
        

    # Setters

    # Getters

# =============================================== CHARACTERISTICS ===============================================


class DeviceIdCharacteristic(Characteristic):
    DEVICE_ID_CHARACTERISTIC_UUID = "00000012-710e-4a5b-8d75-3e5b444bc3cf"
    DEVICE_ID_CHARACTERISTIC_VALUE = VIRTUAL_DEVICE_ID

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
    LOCATION_ID_CHARACTERISTIC_VALUE = VIRTUAL_LOCATION

    def __init__(self, service):
        Characteristic.__init__(
                self, self.LOCATION_ID_CHARACTERISTIC_UUID,
                ["read"],
                service)

    def ReadValue(self, options):
        value = []
        desc = f"0x{self.LOCATION_ID_CHARACTERISTIC_VALUE:02X}"

        for c in desc:
            value.append(dbus.Byte(c.encode()))

        return value
    
class BatteryLifeCharacteristic(Characteristic):
    BATTERY_LIFE_CHARACTERISTIC_UUID = "00000014-710e-4a5b-8d75-3e5b444bc3cf"

    def __init__(self, service):
        self.batteryLife = 100
        Characteristic.__init__(
                self, self.BATTERY_LIFE_CHARACTERISTIC_UUID,
                ["notify", "read"],
                service)
        
        # Start the background battery drain thread
        self.batteryDrainThread = threading.Thread(target=self.batteryDrainLoop, daemon=True)
        self.batteryDrainThread.start()

    def batteryDrainLoop(self):
        while True:
            time.sleep(5)
            self.batteryLife -= 1

            if (self.batteryLife <= 0):
                self.batteryLife = 100

    def getBatteryLife(self):
        value = []
        strBatteryLife = str(self.batteryLife)

        for c in strBatteryLife:
            value.append(dbus.Byte(c.encode()))
        return value

    def setBatteryLifeCallback(self):
        if self.notifying:
            value = self.getBatteryLife()
            self.PropertiesChanged(GATT_CHRC_IFACE, {"Value": value}, [])
        return self.notifying

    def StartNotify(self):
        if self.notifying:
            return
        self.notifying = True

        value = self.getBatteryLife()
        self.PropertiesChanged(GATT_CHRC_IFACE, {"Value": value}, [])
        self.add_timeout(NOTIFY_TIMEOUT, self.setBatteryLifeCallback)

    def StopNotify(self):
        self.notifying = False

    def ReadValue(self, options):
        value = self.getBatteryLife()
        return value

# ===============================================================================================================
# =============================================== THERAPY SERVICE ===============================================
# ===============================================================================================================

class TherapyService(Service):
    THERAPY_SVC_UUID = "00000001-710e-4a5b-8d75-3e5b444bc3cf"

    def __init__(self, index):
        self.intensity = 0
        self.elapsedTime = 0
        self.startTime = 0
        self.targetTime = 0
        self.isTherapyActive = False

        Service.__init__(self, index, self.THERAPY_SVC_UUID, True)

        # Initialise Characteristics
        self.add_characteristic(TimeCharacteristic(self))
        self.add_characteristic(IntensityCharacteristic(self))
        self.add_characteristic(TargetTimeCharacteristic(self))
        self.add_characteristic(StatusCharacteristic(self))

    # Setters
    def setElapsedTime(self, elapsedTime):
        self.elapsedTime = elapsedTime

    def setStartTime(self, startTime):
        self.startTime = startTime
        
    def setIntensity(self, intensity):
        self.intensity = intensity

    def setTargetTime(self, targetTime):
        self.targetTime = targetTime

    def setIsTherapyActive(self, isTherapyActive):
        self.isTherapyActive = isTherapyActive

    # Getters
    def getElapsedTime(self):
        return self.elapsedTime
    
    def getStartTime(self):
        return self.startTime

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

            self.startTime = self.service.getStartTime()

            elapsedTime = time.time() - self.startTime
            targetTime = self.service.getTargetTime()

            if (self.service.getIsTherapyActive()):
                if targetTime > 0:
                    print_progress_bar(
                        min(elapsedTime, targetTime),
                        targetTime,
                        prefix='Therapy Progress:',
                        suffix=f'Elapsed: {int(elapsedTime)}s / Target: {targetTime}s',
                        length=40
                    )
                
                # Check if therapy time is complete
                if elapsedTime >= targetTime:
                    print(f"\n{bcolors.HEADER}[INFO] Therapy session completed after {targetTime}s{bcolors.ENDC}")

                    # Reset Other Characteristics
                    self.service.setIntensity(0)
                    self.service.setTargetTime(0)
                    self.service.setIsTherapyActive(False)

                    # Reset Local Vars
                    self.moduleTime = 0
                    self.startTime = time.time()
                    print(f"\n{bcolors.HEADER}[INFO] New Intensity: {self.service.getIntensity()} | New Target Time: {self.service.getTargetTime()}{bcolors.ENDC}")

    def getElapsedTime(self):
        value = []
        currentTime = time.time()

        moduleTime = round(currentTime - self.startTime)

        if (not self.service.getIsTherapyActive()):
            moduleTime = 0
            self.startTime = time.time()
            self.service.setStartTime(self.startTime)
            self.service.setElapsedTime(moduleTime)

        self.service.setStartTime(self.startTime)
        self.service.setElapsedTime(moduleTime)

        # Convert to Byte String
        strModuleTime = str(moduleTime)
        for c in strModuleTime:
            value.append(dbus.Byte(c.encode()))
        return value

    def setTimeElapsedCallback(self):
        if self.notifying:
            value = self.getElapsedTime()
            self.PropertiesChanged(GATT_CHRC_IFACE, {"Value": value}, [])
        return self.notifying

    def StartNotify(self):
        if self.notifying:
            return

        self.notifying = True

        value = self.getElapsedTime()
        self.PropertiesChanged(GATT_CHRC_IFACE, {"Value": value}, [])
        self.add_timeout(NOTIFY_TIMEOUT, self.setTimeElapsedCallback)

    def StopNotify(self):
        self.notifying = False

    def ReadValue(self, options):
        value = self.getElapsedTime()
        return value

class TimeDescriptor(Descriptor):
    TIME_DESCRIPTOR_UUID = "2901"
    TIME_DESCRIPTOR_VALUE = "Time Elapsed (Seconds)"

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

        Characteristic.__init__(
                self, self.UNIT_CHARACTERISTIC_UUID,
                ["notify", "read", "write"], service)
        self.add_descriptor(IntensityDescriptor(self))

    def getIntensity(self):
        value = []
        strValue = str(self.service.getIntensity())
        for c in strValue:
            value.append(dbus.Byte(c.encode()))
        return value

    def setIntensityCallback(self):
        if self.notifying:

            value = self.getIntensity()
            self.PropertiesChanged(GATT_CHRC_IFACE, {"Value": value}, [])

        return self.notifying

    def StartNotify(self):
        if self.notifying:
            return

        self.notifying = True

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

            self.service.setIntensity(newIntensity)  # Update in parent service

            # Check to make sure Therapy doesn't start prematurely
            if (self.service.getTargetTime() > 0):
                self.service.setIsTherapyActive(True)
                self.service.setElapsedTime(0)
                self.service.setStartTime(time.time())
                print(f"{bcolors.OKGREEN}[INFO] Therapy Started{bcolors.ENDC}")
            else:
                print(f"{bcolors.WARNING}[INFO] Awaiting Therapy Target Time{bcolors.ENDC}")

            self.PropertiesChanged(GATT_CHRC_IFACE, {"Value": self.ReadValue({})}, [])

            print(f"[INFO] Intensity updated to: {self.service.getIntensity()}")

        except Exception as e:
            print(f"[ERROR] Failed to write Intensity value: {e}")

class IntensityDescriptor(Descriptor):
    INTENSITY_DESCRIPTOR_UUID = "2901"
    INTENSITY_DESCRIPTOR_VALUE = "Intensity (%)"

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

        Characteristic.__init__(
                self, self.UNIT_CHARACTERISTIC_UUID,
                ["notify", "read", "write"], service)
        self.add_descriptor(TargetTimeDescriptor(self))

    def getTargetTime(self):
        value = []
        strValue = str(self.service.getTargetTime())
        for c in strValue:
            value.append(dbus.Byte(c.encode()))
        return value

    def setTargetTimeCallback(self):
        if self.notifying:

            value = self.getTargetTime()
            self.PropertiesChanged(GATT_CHRC_IFACE, {"Value": value}, [])

        return self.notifying

    def StartNotify(self):
        if self.notifying:
            return

        self.notifying = True

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

            self.service.setTargetTime(newTargetTime)  # Update in parent service

            # Check to make sure Therapy doesn't start prematurely
            if (self.service.getIntensity() > 0):
                self.service.setIsTherapyActive(True)
                self.service.setElapsedTime(0)
                self.service.setStartTime(time.time())
                print(f"{bcolors.OKGREEN}[INFO] Therapy Started{bcolors.ENDC}")
            else:
                print(f"{bcolors.WARNING}[INFO] Awaiting Therapy Intensity{bcolors.ENDC}")

            self.PropertiesChanged(GATT_CHRC_IFACE, {"Value": self.ReadValue({})}, [])

            print(f"[INFO] Target Time updated to: {self.service.getTargetTime()}")

        except Exception as e:
            print(f"[ERROR] Failed to write Target Time value: {e}")

class TargetTimeDescriptor(Descriptor):
    TARGET_TIME_DESCRIPTOR_UUID = "2901"
    TARGET_TIME_DESCRIPTOR_VALUE = "Target Time (Seconds)"

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
    print("Terminating Application")
