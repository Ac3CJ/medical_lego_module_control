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
"""
#!/usr/bin/python3

# Bluetooth Related
import dbus
from advertisement import Advertisement
from service import Application, Service, Characteristic, Descriptor

# Functionality 
import time
import threading
import curses
from curses import wrapper


# Constants
GATT_CHRC_IFACE = "org.bluez.GattCharacteristic1"
NOTIFY_TIMEOUT = 5000

VIRTUAL_DEVICE_NAME = "LM Health Virtual"
VIRTUAL_DEVICE_ID = "TMP-VIR"
VIRTUAL_LOCATION = 2
VIRTUAL_FIRMWARE_VERSION = "1.0.0"

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

# Global variables for UI
ui_screen = None
battery_window = None
therapy_window = None

# =============================================== UI ===============================================
def init_ui():
    """Initialize the curses UI with multiple windows"""
    global ui_screen, battery_window, therapy_window, status_window, device_info_window
    
    # Initialize curses
    ui_screen = curses.initscr()
    curses.noecho()
    curses.cbreak()
    curses.curs_set(0)  # Hide cursor
    
    # Get screen dimensions
    height, width = ui_screen.getmaxyx()
    
    # Create windows with borders
    # 1. Advertising status (top)
    ui_screen.addstr(0, 2, f" Advertising as {VIRTUAL_DEVICE_NAME}... ")
    ui_screen.refresh()
    
    # 2. Battery window (row 1)
    battery_window = curses.newwin(3, width, 1, 0)
    battery_window.border()
    battery_window.addstr(0, 2, " Battery Life ")
    
    # 3. Therapy window (row 4)
    therapy_window = curses.newwin(3, width, 4, 0)
    therapy_window.border()
    therapy_window.addstr(0, 2, " Therapy Progress ")
    
    # 4. Status window (row 7) - Shows intensity, target time, user ID and timestamp
    status_window = curses.newwin(4, width, 7, 0)
    status_window.border()
    status_window.addstr(0, 2, " Therapy Status ")
    
    # 5. Device info window (bottom) - Shows device info
    device_info_window = curses.newwin(3, width, 11, 0)
    device_info_window.border()
    device_info_window.addstr(0, 2, " Device Information ")
    
    # Refresh all windows
    battery_window.refresh()
    therapy_window.refresh()
    status_window.refresh()
    device_info_window.refresh()

def close_ui():
    """Clean up the curses UI"""
    global ui_screen
    if ui_screen:
        curses.nocbreak()
        ui_screen.keypad(False)
        curses.echo()
        curses.endwin()

def update_battery_ui(percent):
    """Update the battery progress bar"""
    global battery_window
    if not battery_window:
        return
    
    width = int((battery_window.getmaxyx()[1] - 6) * 0.8)  # Leave space for borders and percentage
    filled = int(width * percent / 100)
    
    battery_window.clear()
    battery_window.border()
    battery_window.addstr(0, 2, " Battery Life ")
    
    # Create progress bar
    progress = '[' + '#' * filled + ' ' * (width - filled) + ']'
    battery_window.addstr(1, 2, progress)
    
    # Add percentage
    battery_window.addstr(1, width + 4, f"{percent}%")
    battery_window.refresh()

def update_therapy_ui(elapsed, target):
    """Update the therapy progress bar with rounded time values"""
    global therapy_window
    if not therapy_window:
        return
    
    # Use 70% of window width for progress bar, leave rest for numbers
    width = int((therapy_window.getmaxyx()[1] - 4) * 0.8)
    
    # Round elapsed time to whole number
    elapsed_rounded = round(elapsed)
    
    if target > 0:
        filled = int(width * min(elapsed_rounded, target) / target)
        time_str = f"{elapsed_rounded}s / {target}s"
    else:
        filled = 0
        time_str = "Inactive"
    
    therapy_window.clear()
    therapy_window.border()
    therapy_window.addstr(0, 2, " Therapy Progress ")
    
    # Create progress bar with limited width
    progress = '[' + '#' * filled + ' ' * (width - filled) + ']'
    therapy_window.addstr(1, 2, progress)
    
    # Add time display right after progress bar
    therapy_window.addstr(1, width + 4, time_str)
    therapy_window.refresh()


def update_status_ui(intensity, target_time, user_id, timestamp):
    """Update the status window with improved layout"""
    global status_window
    if not status_window:
        return
    
    status_window.clear()
    status_window.border()
    status_window.addstr(0, 2, " Therapy Status ")
    
    # Line 1: Intensity, Target Time, and Status
    status_window.addstr(1, 2, f"Intensity: {intensity}%")
    status_window.addstr(1, 25, f"Target Time: {target_time}s")

    status = "ACTIVE" if (intensity > 0 and target_time > 0) else "INACTIVE"
    status_window.addstr(1, 50, f"Status: {status}")
    
    # Line 2: User ID and Timestamp on same row
    user_display = user_id if user_id else "Not set"
    ts_display = timestamp if timestamp else "Not set"
    status_window.addstr(2, 2, f"User: {user_display}")
    status_window.addstr(2, 30, f"Timestamp: {ts_display}")
    
    status_window.refresh()

def update_device_info_ui():
    """Update the device information window with all device details"""
    global device_info_window
    if not device_info_window:
        return
    
    device_info_window.clear()
    device_info_window.border()
    device_info_window.addstr(0, 2, " Device Information ")
    
    # Line 1: Device ID, Location, and Firmware Version
    device_info_window.addstr(1, 2, f"ID: {VIRTUAL_DEVICE_ID}")
    device_info_window.addstr(1, 25, f"Location: 0x{VIRTUAL_LOCATION:02X}")
    device_info_window.addstr(1, 50, f"Firmware: {VIRTUAL_FIRMWARE_VERSION}")
    
    device_info_window.refresh()

def show_therapy_started(user_id, timestamp):
    """Display therapy started message"""
    global status_window
    if not status_window:
        return
    
    status_window.addstr(1, 50, "Status: ACTIVE")
    status_window.addstr(2, 2, f"User: {user_id}")
    status_window.addstr(3, 2, f"Timestamp: {timestamp}")
    status_window.refresh()

def show_therapy_completed(target_time):
    """Display therapy completed message"""
    global therapy_window
    if not therapy_window:
        return
    
    therapy_window.addstr(2, 2, f"Therapy completed after {target_time}s")
    therapy_window.refresh()

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
    INFO_SVC_UUID = "00000011-710e-4a5b-8d75-3e5b444bc3cf"

    def __init__(self, index):

        Service.__init__(self, index, self.INFO_SVC_UUID, True)
        self.add_characteristic(DeviceIdCharacteristic(self))
        self.add_characteristic(LocationIdCharacteristic(self))
        self.add_characteristic(BatteryLifeCharacteristic(self))
        self.add_characteristic(FirmwareVersionCharacteristic(self))

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
            
        update_device_info_ui()
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

        update_device_info_ui()
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

            # Update UI
            update_battery_ui(self.batteryLife)

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

class FirmwareVersionCharacteristic(Characteristic):
    FIRMWARE_VERSION_CHARACTERISTIC_UUID = "00000015-710e-4a5b-8d75-3e5b444bc3cf"
    FIRMWARE_VERSION_CHARACTERISTIC_VALUE = VIRTUAL_FIRMWARE_VERSION

    def __init__(self, service):
        Characteristic.__init__(
                self, self.FIRMWARE_VERSION_CHARACTERISTIC_UUID,
                ["read"],
                service)

    def ReadValue(self, options):
        value = []
        desc = self.FIRMWARE_VERSION_CHARACTERISTIC_VALUE

        for c in desc:
            value.append(dbus.Byte(c.encode()))

        update_device_info_ui()
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

        self.timeStamp = ''
        self.userId = ''

        Service.__init__(self, index, self.THERAPY_SVC_UUID, True)

        # Initialise Characteristics
        self.add_characteristic(TimeCharacteristic(self))
        self.add_characteristic(IntensityCharacteristic(self))
        self.add_characteristic(TargetTimeCharacteristic(self))
        self.add_characteristic(StatusCharacteristic(self))
        self.add_characteristic(TimeStampCharacteristic(self))
        self.add_characteristic(UserIdCharacteristic(self))

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

    def setTimeStamp(self, timeStamp):
        self.timeStamp = timeStamp
    
    def setUserId(self, userId):
        self.userId = userId

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
    
    def getTimeStamp(self):
        return self.timeStamp
    
    def getUserId(self):
        return self.userId

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
                    # Update therapy progress UI
                    update_therapy_ui(min(elapsedTime, targetTime), targetTime)
                    update_status_ui(
                        self.service.getIntensity(),
                        self.service.getTargetTime(),
                        self.service.getUserId(),
                        self.service.getTimeStamp()
                    )
                
                # Check if therapy time is complete
                if elapsedTime >= targetTime:
                    #print(f"\n{bcolors.HEADER}[INFO] Therapy session completed after {targetTime}s{bcolors.ENDC}")
                    show_therapy_completed(targetTime)

                    # Reset Other Characteristics
                    self.service.setIntensity(0)
                    self.service.setTargetTime(0)
                    self.service.setIsTherapyActive(False)

                    # Reset Local Vars
                    self.moduleTime = 0
                    self.startTime = time.time()
                    #print(f"\n{bcolors.HEADER}[INFO] New Intensity: {self.service.getIntensity()} | New Target Time: {self.service.getTargetTime()}{bcolors.ENDC}")

                    # Update UI to show inactive
                    update_status_ui(0, 0, 
                                     self.service.getUserId(),
                                     self.service.getTimeStamp())
                    update_therapy_ui(0, 0)

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
            update_status_ui(
                self.service.getIntensity(),
                self.service.getTargetTime(),
                self.service.getUserId(),
                self.service.getTimeStamp()
            )

            # Check to make sure Therapy doesn't start prematurely
            if (self.service.getTargetTime() > 0):
                self.service.setIsTherapyActive(True)
                self.service.setElapsedTime(0)
                self.service.setStartTime(time.time())

                # print(f"{bcolors.OKGREEN}[INFO] Therapy Started{bcolors.ENDC}")
                # print(f"User: {self.service.getUserId()}\tTime Stamp: {self.service.getTimeStamp()}")
                show_therapy_started()
                status_window.addstr(1, 50, "Status: ACTIVE")
                status_window.refresh()
            else:
                # print(f"{bcolors.WARNING}[INFO] Awaiting Therapy Target Time{bcolors.ENDC}")
                status_window.addstr(1, 50, "Status: WAITING")
                status_window.refresh()

            self.PropertiesChanged(GATT_CHRC_IFACE, {"Value": self.ReadValue({})}, [])

            # print(f"[INFO] Intensity updated to: {self.service.getIntensity()}")

        except Exception as e:
            status_window.addstr(3, 40, f"Error: {str(e)}")
            status_window.refresh()

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
            update_status_ui(
                self.service.getIntensity(),
                self.service.getTargetTime(),
                self.service.getUserId(),
                self.service.getTimeStamp()
            )

            # Check to make sure Therapy doesn't start prematurely
            if (self.service.getIntensity() > 0):
                self.service.setIsTherapyActive(True)
                self.service.setElapsedTime(0)
                self.service.setStartTime(time.time())

                show_therapy_started()
                status_window.addstr(1, 50, "Status: ACTIVE")
                status_window.refresh()
                # print(f"{bcolors.OKGREEN}[INFO] Therapy Started{bcolors.ENDC}")
                # print(f"User: {self.service.getUserId()}\tTime Stamp: {self.service.getTimeStamp()}")
            else:
                status_window.addstr(1, 50, "Status: WAITING")
                status_window.refresh()
                # print(f"{bcolors.WARNING}[INFO] Awaiting Therapy Intensity{bcolors.ENDC}")

            self.PropertiesChanged(GATT_CHRC_IFACE, {"Value": self.ReadValue({})}, [])

            #print(f"[INFO] Target Time updated to: {self.service.getTargetTime()}")

        except Exception as e:
            status_window.addstr(3, 40, f"Error: {str(e)}")
            status_window.refresh()
            #print(f"[ERROR] Failed to write Target Time value: {e}")

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
    
# =============================================== TIME STAMP CHARACTERISTIC ===============================================

class TimeStampCharacteristic(Characteristic):
    TIME_STAMP_CHARACTERISTIC_UUID = "00000006-710e-4a5b-8d75-3e5b444bc3cf"

    def __init__(self, service):
        self.timeStamp = ""
        Characteristic.__init__(
                self, self.TIME_STAMP_CHARACTERISTIC_UUID,
                ["write"], service)
        self.add_descriptor(TimeStampDescriptor(self))

    def WriteValue(self, value, options):
        try:
            self.timeStamp = ''.join([chr(byte) for byte in value])
            #print(f"{bcolors.OKGREEN}[TIMESTAMP] {self.timeStamp}{bcolors.ENDC}")

            self.service.setTimeStamp(self.timeStamp)
            update_status_ui(
                self.service.getIntensity(),
                self.service.getTargetTime(),
                self.service.getUserId(),
                self.service.getTimeStamp()
            )
        except Exception as e:
            # print(f"[ERROR] Failed to write Timestamp: {e}")
            status_window.addstr(3, 40, f"Error: {str(e)}")
            status_window.refresh()

    def ReadValue(self, options):
        value = []
        for c in self.timeStamp:
            value.append(dbus.Byte(c.encode()))
        return value

class TimeStampDescriptor(Descriptor):
    TIME_STAMP_DESCRIPTOR_UUID = "2901"
    TIME_STAMP_DESCRIPTOR_VALUE = "Timestamp (DD:MM:YYYYTHH:MM:SS)"

    def __init__(self, characteristic):
        Descriptor.__init__(
                self, self.TIME_STAMP_DESCRIPTOR_UUID,
                ["read"],
                characteristic)

    def ReadValue(self, options):
        value = []
        desc = self.TIME_STAMP_DESCRIPTOR_VALUE
        for c in desc:
            value.append(dbus.Byte(c.encode()))
        return value
    
# =============================================== USER ID CHARACTERISTIC ===============================================

class UserIdCharacteristic(Characteristic):
    USER_ID_CHARACTERISTIC_UUID = "00000007-710e-4a5b-8d75-3e5b444bc3cf"

    def __init__(self, service):
        self.userId = ""
        Characteristic.__init__(
                self, self.USER_ID_CHARACTERISTIC_UUID,
                ["write"], service)
        self.add_descriptor(UserIdDescriptor(self))

    def WriteValue(self, value, options):
        try:
            self.userId = ''.join([chr(byte) for byte in value])
            # print(f"{bcolors.OKGREEN}[USER ID] {self.userId}{bcolors.ENDC}")
            update_status_ui(
                self.service.getIntensity(),
                self.service.getTargetTime(),
                self.service.getUserId(),
                self.service.getTimeStamp()
            )

            self.service.setUserId(self.userId)
        except Exception as e:
            # print(f"[ERROR] Failed to write User ID: {e}")
            status_window.addstr(3, 40, f"Error: {str(e)}")
            status_window.refresh()

    def ReadValue(self, options):
        value = []
        for c in self.userId:
            value.append(dbus.Byte(c.encode()))
        return value

class UserIdDescriptor(Descriptor):
    USER_ID_DESCRIPTOR_UUID = "2901"
    USER_ID_DESCRIPTOR_VALUE = "User ID"

    def __init__(self, characteristic):
        Descriptor.__init__(
                self, self.USER_ID_DESCRIPTOR_UUID,
                ["read"],
                characteristic)

    def ReadValue(self, options):
        value = []
        desc = self.USER_ID_DESCRIPTOR_VALUE
        for c in desc:
            value.append(dbus.Byte(c.encode()))
        return value
    
# =============================================== MAIN CODE ===============================================
def main(stdscr):
    init_ui()
    
    app = Application()
    app.add_service(TherapyService(0))
    app.add_service(InfoService(1))
    app.register()

    adv = TherapyAdvertisement(0)
    adv.register()

    try:
        #print(f"{bcolors.OKBLUE}Advertising as {VIRTUAL_DEVICE_NAME}...{bcolors.ENDC}")
        app.run()
    except KeyboardInterrupt:
        app.quit()
        #print("Terminating Application")
    finally:
        close_ui()

if __name__ == "__main__":
    wrapper(main)