from connection import HomeAutomationSystemConnection


class CurtainControlSystemConnection(HomeAutomationSystemConnection):
    def __init__(self, port: int, ui):
        # 1. Define ALL variables first with default simulation values
        self._curtainStatus: float = 50.0
        self._outdoorTemperature: float = 25.0
        self._outdoorPressure: float = 1013.2
        self._lightIntensity: float = 500.0

        # 2. Setup the UI reference
        self.ui = ui

        # 3. Call the parent class (which handles the serial port setup)
        super().__init__(port, ui, "curtain")

        # 4. Now it is safe to update the labels
        self.update_gui_labels()

    def getOutdoorTemp(self) -> float:
        """Requests Outdoor Temp or returns simulation value."""
        if self._serial and self._serial.is_open:
            try:
                self._serial.write(bytes([0x04]))
                high = ord(self._serial.read(1))
                self._serial.write(bytes([0x03]))
                low = ord(self._serial.read(1))
                self._outdoorTemperature = high + (low / 100.0)
            except Exception as e:
                print(f"Error reading Outdoor Temp: {e}")
        return self._outdoorTemperature

    def getOutdoorPress(self) -> float:
        """Requests Outdoor Pressure or returns simulation value."""
        if self._serial and self._serial.is_open:
            try:
                self._serial.write(bytes([0x06]))
                high = ord(self._serial.read(1))
                self._serial.write(bytes([0x05]))
                low = ord(self._serial.read(1))
                self._outdoorPressure = high + (low / 100.0)
            except Exception as e:
                print(f"Error reading Pressure: {e}")
        return self._outdoorPressure

    def getLightIntensity(self) -> float:
        """Requests Light Intensity or returns simulation value."""
        if self._serial and self._serial.is_open:
            try:
                self._serial.write(bytes([0x08]))
                high = ord(self._serial.read(1))
                self._serial.write(bytes([0x07]))
                low = ord(self._serial.read(1))
                self._lightIntensity = high + (low / 100.0)
            except Exception as e:
                print(f"Error reading Light: {e}")
        return self._lightIntensity

    def getCurtainStatus(self) -> float:
        """Requests Current Curtain Status or returns simulation value."""
        if self._serial and self._serial.is_open:
            try:
                self._serial.write(bytes([0x02]))
                high = ord(self._serial.read(1))
                self._serial.write(bytes([0x01]))
                low = ord(self._serial.read(1))
                self._curtainStatus = high + (low / 100.0)
            except Exception as e:
                print(f"Error reading Curtain Status: {e}")
        return self._curtainStatus

    def update_gui_labels(self):
        """Refreshes the GUI text fields using current variables."""
        # Get latest values (from serial or internal memory)
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
        """Triggers dynamic GUI updates for sensor values."""
        super().update()
        self.update_gui_labels()

        if self._serial and self._serial.is_open:
            print(f"Curtain Control Board Sync Successful on COM{self._comPort}")
        else:
            print(f"Curtain Control Board Simulation: Using mock data for COM{self._comPort}")

    def setCurtainStatus(self) -> bool:
        """Sends curtain status to PIC if connected; otherwise simulates."""
        try:
            raw_value = self.ui.curtainInput.text()
            status_val = float(raw_value)

            if 0.0 <= status_val <= 100.0:
                integral_val = int(status_val)
                fractional_val = int(round((status_val - integral_val) * 100))

                high_command = 0xC0 | (integral_val & 0x3F)
                low_command = 0x80 | (fractional_val & 0x3F)

                if self._serial and self._serial.is_open:
                    self._serial.write(bytes([high_command]))
                    self._serial.write(bytes([low_command]))
                    print(f"PIC Board 2: Sent commands {bin(high_command)} {bin(low_command)}")
                else:
                    print(f"Send commands for {status_val}%")

                self._curtainStatus = status_val
                self.update_gui_labels()  # Update UI instantly
                self.ui.curtainInput.clear()
                return True
            return False
        except ValueError:
            return False