import time
from connection import HomeAutomationSystemConnection


class CurtainControlSystemConnection(HomeAutomationSystemConnection):
    def __init__(self, port: int, ui):
        # Strictly Typed Variables
        self._curtainStatus: float = 0.0
        self._outdoorTemperature: float = 0.0
        self._outdoorPressure: float = 0.0
        self._lightIntensity: float = 0.0  # Logic: double precision

        self._last_update_time = 0
        self._update_interval = 2.0

        super().__init__(port, ui, "curtain")
        self.ui = ui
        self.open()
        self.update_gui_labels()

    # --- GETTERS ---
    def getOutdoorTemp(self) -> float:
        return float(self._outdoorTemperature)

    def getOutdoorPress(self) -> float:
        return float(self._outdoorPressure)

    def getLightIntensity(self) -> float:
        return float(self._lightIntensity)

    def getCurtainStatus(self) -> float:
        return float(self._curtainStatus)

    # --- HARDWARE COMMUNICATION ---
    def read_pic_value(self, high_cmd: int, low_cmd: int) -> float:
        if not self._serial or not self._serial.is_open:
            return 0.0
        try:
            # CLEAR BUFFER: This fixes the "wrong numbers" (like the 52.0)
            self._serial.reset_input_buffer()

            self._serial.write(bytes([high_cmd]))
            time.sleep(0.1)
            high = self._serial.read(1)

            self._serial.write(bytes([low_cmd]))
            time.sleep(0.1)
            low = self._serial.read(1)

            if high and low:
                return float(ord(high) + (ord(low) / 100.0))
        except:
            pass
        return 0.0

    def update_gui_labels(self):
        if not self.ui: return

        # Sync variables from PIC
        self._outdoorTemperature = self.read_pic_value(0x04, 0x03)
        self._outdoorPressure = self.read_pic_value(0x06, 0x05)
        self._lightIntensity = self.read_pic_value(0x08, 0x07)
        self._curtainStatus = self.read_pic_value(0x02, 0x01)

        # Update UI text
        self.ui.outdoorTemp.setText(f"{self._outdoorTemperature:.1f} °C")
        self.ui.outdoorPressure.setText(f"{self._outdoorPressure:.1f} hPa")
        self.ui.lightIntensity.setText(f"{self._lightIntensity:.0f} lx")
        self.ui.curtainStatus.setText(f"{self._curtainStatus:.0f} %")

        print(
            f"[DEBUG] T:{self._outdoorTemperature} P:{self._outdoorPressure} L:{self._lightIntensity} C:{self._curtainStatus}")

    # --- REQUIRED METHODS ---
    def update(self) -> None:
        super().update()
        current_time = time.time()
        if current_time - self._last_update_time > self._update_interval:
            self.update_gui_labels()
            self._last_update_time = current_time

    def setCurtainStatus(self, val=None) -> bool:
        """
        Takes a float. If 'val' is a boolean from a UI button,
        it pulls the correct float from the input field instead.
        """
        try:
            # FIX: Check if 'val' is a float/int, NOT a boolean from a button click
            if val is None or isinstance(val, bool):
                if not self.ui or not self.ui.curtainInput.text():
                    return False
                val = float(self.ui.curtainInput.text())

            if 0 <= val <= 100:
                integral = int(val)
                fractional = int(round((val - integral) * 100))

                # Protocol: 11xxxxxx (High) | 10xxxxxx (Low)
                high_cmd = 0xC0 | (integral & 0x3F)
                low_cmd = 0x80 | (fractional & 0x3F)

                if self._serial and self._serial.is_open:
                    self._serial.write(bytes([high_cmd, low_cmd]))
                    # Allow PIC time to process before we ask for the status back
                    time.sleep(0.05)

                print(f"[ACTION] Curtain set to {val}%")
                self._curtainStatus = val

                if self.ui:
                    self.ui.curtainInput.clear()
                    # Immediate refresh so you don't have to wait 2 seconds to see the change
                    self.update_gui_labels()
                return True

            return False
        except Exception as e:
            print(f"[ERROR] setCurtainStatus failed: {e}")
            return False