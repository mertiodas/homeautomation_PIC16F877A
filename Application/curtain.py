from connection import HomeAutomationSystemConnection
import time

class CurtainControlSystemConnection(HomeAutomationSystemConnection):
    def __init__(self, port: int, ui):
        # 1. Initialize variables FIRST
        self._curtainStatus: float = 50.0
        self._outdoorTemperature: float = 25.0
        self._outdoorPressure: float = 1013.2
        self._lightIntensity: float = 500.0

        # 2. Call super (handles serial port)
        super().__init__(port, ui, "curtain")
        self.ui = ui
        self.open()

        # 3. NOW update labels
        self.update_gui_labels()

    def getOutdoorTemp(self) -> float:
        if self._serial and self._serial.is_open:
            try:
                self._serial.write(bytes([0x04]))  # Integral
                time.sleep(0.15)
                high_byte = self._serial.read(1)

                self._serial.write(bytes([0x03]))  # Fraction
                time.sleep(0.15)
                low_byte = self._serial.read(1)

                if high_byte and low_byte:
                    integral = ord(high_byte)
                    fractional = ord(low_byte)
                    self._outdoorTemperature = integral + (fractional / 100.0)
                    print(f"PIC RESPONSE Outdoor Temp: Integral={integral}, Frac={fractional}")
            except Exception as e:
                print(f"Error reading Outdoor Temp: {e}")
        return self._outdoorTemperature

    def getOutdoorPress(self) -> float:
        if self._serial and self._serial.is_open:
            try:
                self._serial.write(bytes([0x06]))
                time.sleep(0.1)
                high_byte = self._serial.read(1)
                self._serial.write(bytes([0x05]))
                time.sleep(0.1)
                low_byte = self._serial.read(1)

                if high_byte and low_byte:
                    integral = ord(high_byte)
                    fractional = ord(low_byte)
                    self._outdoorPressure = integral + (fractional / 100.0)
                    print(f"PIC RESPONSE Pressure: Integral={integral}, Frac={fractional}")
            except Exception as e:
                print(f"Error reading Pressure: {e}")
        return self._outdoorPressure

    def getLightIntensity(self) -> float:
        if self._serial and self._serial.is_open:
            try:
                self._serial.write(bytes([0x08]))
                time.sleep(0.1)
                high_byte = self._serial.read(1)
                self._serial.write(bytes([0x07]))
                time.sleep(0.1)
                low_byte = self._serial.read(1)

                if high_byte and low_byte:
                    integral = ord(high_byte)
                    fractional = ord(low_byte)
                    self._lightIntensity = integral + (fractional / 100.0)
                    print(f"PIC RESPONSE Light: Integral={integral}, Frac={fractional}")
            except Exception as e:
                print(f"Error reading Light Intensity: {e}")
        return self._lightIntensity

    def getCurtainStatus(self) -> float:
        if self._serial and self._serial.is_open:
            try:
                self._serial.write(bytes([0x02]))
                time.sleep(0.1)
                high_byte = self._serial.read(1)
                self._serial.write(bytes([0x01]))
                time.sleep(0.1)
                low_byte = self._serial.read(1)

                if high_byte and low_byte:
                    integral = ord(high_byte)
                    fractional = ord(low_byte)
                    self._curtainStatus = integral + (fractional / 100.0)
                    print(f"PIC RESPONSE Curtain Status: Integral={integral}, Frac={fractional}")
            except Exception as e:
                print(f"Error reading Curtain Status: {e}")
        return self._curtainStatus

    def update_gui_labels(self):
        temp = self.getOutdoorTemp()
        pressure = self.getOutdoorPress()
        light = self.getLightIntensity()
        curtain = self.getCurtainStatus()

        if self.ui:
            self.ui.outdoorTemp.setText(f"{temp:.1f} °C")
            self.ui.outdoorPressure.setText(f"{pressure:.1f} hPa")
            self.ui.lightIntensity.setText(f"{light:.0f} lx")
            self.ui.curtainStatus.setText(f"{curtain:.0f} %")

    def update(self):
        super().update()
        self.update_gui_labels()
        if self._serial and self._serial.is_open:
            print(f"Curtain Control Board (COM{self._comPort}) Sync Successful")
        else:
            print(f"Curtain Control Board Simulation: COM{self._comPort} not active")

    def setCurtainStatus(self) -> bool:
        try:
            input_text = self.ui.curtainInput.text()
            target_status = float(input_text)

            if 0.0 <= target_status <= 100.0:
                integral_val = int(target_status)
                fractional_val = int(round((target_status - integral_val) * 100))

                high_command = 0xC0 | (integral_val & 0x3F)
                low_command = 0x80 | (fractional_val & 0x3F)

                if self._serial and self._serial.is_open:
                    self._serial.write(bytes([high_command]))
                    self._serial.write(bytes([low_command]))
                    print(f"Hardware Command Sent: Curtain {target_status}% -> High={bin(high_command)}, Low={bin(low_command)}")
                else:
                    print(f"Simulation: Curtain {target_status}% -> High={bin(high_command)}, Low={bin(low_command)}")

                self._curtainStatus = target_status
                self.update_gui_labels()
                if self.ui:
                    self.ui.curtainInput.clear()
                return True

            return False
        except ValueError:
            return False
