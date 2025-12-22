from connection import HomeAutomationSystemConnection

class CurtainControlSystemConnection(HomeAutomationSystemConnection):
    def __init__(self, port: int, ui):
        super().__init__(port, ui, "curtain")
        self._curtainStatus: float = 0.0
        self._outdoorTemperature: float = 0.0
        self._outdoorPressure: float = 0.0
        self._lightIntensity: float = 0.0
        self.ui = ui
        temp = self.getOutdoorTemp()
        pressure = self.getOutdoorPress()
        light = self.getLightIntensity()
        curtain = self.getCurtainStatus()

        # Update UI with the fixed units
        self.ui.outdoorTemp.setText(f"{temp:.1f} °C")
        self.ui.outdoorPressure.setText(f"{pressure:.1f} hPa")
        self.ui.lightIntensity.setText(f"{light:.0f} lx")
        self.ui.curtainStatus.setText(f"{curtain:.0f} %")

    def getOutdoorTemp(self) -> float:
        """Requests Outdoor Temp from Board 2 (High: 0x04, Low: 0x03)."""
        if self._serial and self._serial.is_open:
            try:
                self._serial.write(bytes([0x04]))  # Request High (Integral)
                high = ord(self._serial.read(1))
                self._serial.write(bytes([0x03]))  # Request Low (Fractional)
                low = ord(self._serial.read(1))

                self._outdoorTemperature = high + (low / 100.0)
            except Exception as e:
                print(f"Error reading Outdoor Temp: {e}")
        return self._outdoorTemperature

    def getOutdoorPress(self) -> float:
        """Requests Outdoor Pressure from Board 2 (High: 0x06, Low: 0x05)."""
        if self._serial and self._serial.is_open:
            try:
                self._serial.write(bytes([0x06]))  # Request High
                high = ord(self._serial.read(1))
                self._serial.write(bytes([0x05]))  # Request Low
                low = ord(self._serial.read(1))

                self._outdoorPressure = high + (low / 100.0)
            except Exception as e:
                print(f"Error reading Pressure: {e}")
        return self._outdoorPressure

    def getLightIntensity(self) -> float:
        """Requests Light Intensity from Board 2 (High: 0x08, Low: 0x07)."""
        if self._serial and self._serial.is_open:
            try:
                self._serial.write(bytes([0x08]))  # Request High (Command corrected from typo)
                high = ord(self._serial.read(1))
                self._serial.write(bytes([0x07]))  # Request Low
                low = ord(self._serial.read(1))

                self._lightIntensity = high + (low / 100.0)
            except Exception as e:
                print(f"Error reading Light: {e}")
        return self._lightIntensity

    def getCurtainStatus(self) -> float:
        """Requests Current Curtain Status from Board 2 (High: 0x02, Low: 0x01)."""
        if self._serial and self._serial.is_open:
            try:
                self._serial.write(bytes([0x02]))  # Request High
                high = ord(self._serial.read(1))
                self._serial.write(bytes([0x01]))  # Request Low
                low = ord(self._serial.read(1))

                self._curtainStatus = high + (low / 100.0)
            except Exception as e:
                print(f"Error reading Curtain Status: {e}")
        return self._curtainStatus

    def update(self):
        """
        Refreshes Board 2 data. Triggers binary GET requests for
        Temp, Pressure, Light, and Curtain status per [R2.2.6-1].
        """
        # 1. Update Port/Baudrate labels via Base Class
        super().update()

        # 2. Connection Safety Check
        if not self._serial or not self._serial.is_open:
            print(f"Board 2 (COM{self._comPort}) is not connected.")
            return

        # 3. Request and Update GUI Objects
        if self.ui:
            # Each 'get' call sends a specific binary byte (0x01 - 0x08) to the PIC
            temp = self.getOutdoorTemp()
            pressure = self.getOutdoorPress()
            light = self.getLightIntensity()
            curtain = self.getCurtainStatus()

            # Update UI with the fixed units and formatting
            # Using :.1f for precision where needed
            self.ui.outdoorTemp.setText(f"{temp:.1f} °C")
            self.ui.outdoorPressure.setText(f"{pressure:.1f} hPa")
            self.ui.lightIntensity.setText(f"{light:.1f} hPa")
            self.ui.lightIntensity.setText(f"{light:.0f} lx")
            self.ui.curtainStatus.setText(f"{curtain:.1f} %")

            print(f"Board 2 Sync: {temp}C, {pressure}hPa, {light}lx, {curtain}%")

    def setCurtainStatus(self) -> bool:
        """
        Sends curtain status to PIC16F877A Board 2 using bit-level commands.
        Requirement: Integral (11xxxxxx), Fractional (10xxxxxx).
        """
        try:
            # 1. Read the input from the QLineEdit
            raw_value = self.ui.curtainInput.text()
            status_val = float(raw_value)

            # 2. Validate the range (0.0 - 100.0)
            if 0.0 <= status_val <= 100.0:

                # 3. Prepare Binary Data (6-bit format)
                integral_val = int(status_val)
                # Rounding to 2 decimal places then taking as integer (e.g., 0.55 -> 55)
                fractional_val = int(round((status_val - integral_val) * 100))

                # 4. Apply Bit Masks [R2.2.6-1]
                # Integral: 11 (0xC0) ORed with data (masked to 6 bits 0x3F)
                high_command = 0xC0 | (integral_val & 0x3F)

                # Fractional: 10 (0x80) ORed with data (masked to 6 bits 0x3F)
                low_command = 0x80 | (fractional_val & 0x3F)

                # 5. Send to PIC via Serial
                if self._serial and self._serial.is_open:
                    # Send high byte then low byte
                    self._serial.write(bytes([high_command]))
                    self._serial.write(bytes([low_command]))

                    # Update internal state and UI
                    self._curtainStatus = status_val
                    if self.ui:
                        self.ui.curtainStatus.setText(f"{status_val:.1f} %")
                        self.ui.curtainInput.clear()

                    print(f"PIC Board 2: Sent Int {bin(high_command)} and Frac {bin(low_command)}")
                    return True
                else:
                    print("Board 2 Error: Serial port not open.")
                    return False

            else:
                print("Validation failed: Value must be 0-100")
                return False

        except ValueError:
            print("Validation failed: Non-numeric input")
            return False
