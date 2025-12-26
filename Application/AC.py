from connection import HomeAutomationSystemConnection


class AirConditionerSystemConnection(HomeAutomationSystemConnection):
    def __init__(self, port: int, ui):
        # 1. Initialize variables FIRST
        self._desiredTemperature: float = 24.0
        self._ambientTemperature: float = 22.5
        self._fanSpeed: int = 15

        # 2. Call super (which handles port/baudrate)
        super().__init__(port, ui, "ac")
        self.ui = ui

        # 3. NOW update labels
        self.update_gui_labels()

    def getAmbientTemp(self) -> float:
        """Gets ambient temp or returns simulation data if offline."""
        if self._serial and self._serial.is_open:
            try:
                # 1. Request Integral Part (0x04)
                self._serial.write(bytes([0x04]))
                high_byte = self._serial.read(1)

                # 2. Request Fractional Part (0x03)
                self._serial.write(bytes([0x03]))
                low_byte = self._serial.read(1)

                if high_byte and low_byte:
                    integral = ord(high_byte)
                    fractional = ord(low_byte)
                    self._ambientTemperature = integral + (fractional / 100.0)
            except Exception as e:
                print(f"Error reading Ambient Temp: {e}")

        return self._ambientTemperature

    def getFanSpeed(self) -> int:
        """Gets fan speed or returns simulation data if offline."""
        if self._serial and self._serial.is_open:
            try:
                self._serial.write(bytes([0x05]))
                response = self._serial.read(1)
                if response:
                    self._fanSpeed = ord(response)
            except Exception as e:
                print(f"Error reading Fan Speed: {e}")

        return self._fanSpeed

    def getDesiredTemp(self) -> float:
        """Gets the desired temp or returns simulation data if offline."""
        if self._serial and self._serial.is_open:
            try:
                self._serial.write(bytes([0x02]))
                high = ord(self._serial.read(1))
                self._serial.write(bytes([0x01]))
                low = ord(self._serial.read(1))
                self._desiredTemperature = high + (low / 100.0)
            except:
                pass

        return self._desiredTemperature

    def update_gui_labels(self):
        """Refreshes the GUI text fields using current variables."""
        # We fetch the values (which either come from Serial or from internal memory)
        ambient = self.getAmbientTemp()
        fan = self.getFanSpeed()
        desired = self.getDesiredTemp()

        if self.ui:
            self.ui.ambientTemp.setText(f"{ambient:.1f} °C")
            self.ui.fanSpeed.setText(f"{fan} RPS")
            self.ui.desiredTemp.setText(f"{desired:.1f} °C")

    def update(self):
        """Master update call triggered by GUI timer or button."""
        # 1. Update Port/Baudrate labels via Base Class
        super().update()

        # 2. Push current data to UI labels
        self.update_gui_labels()

        if self._serial and self._serial.is_open:
            print(f"AC Control Board (COM{self._comPort}) Sync Successful")
        else:
            # We don't 'return' here so that simulation data still shows up
            print(f"AC Control Board Simulation: Using mock data for COM{self._comPort}")

    def setDesiredTemp(self) -> bool:
        """Parses UI input and sends to hardware IF connected."""
        try:
            input_text = self.ui.acInput.text()
            target_temp = float(input_text)

            if 10.0 <= target_temp <= 50.0:
                # Prepare Binary Data (Same logic as required)
                integral_val = int(target_temp)
                fractional_val = int(round((target_temp - integral_val) * 100))

                high_command = 0xC0 | (integral_val & 0x3F)
                low_command = 0x80 | (fractional_val & 0x3F)

                # Send to Hardware only if port is open
                if self._serial and self._serial.is_open:
                    self._serial.write(bytes([high_command]))
                    self._serial.write(bytes([low_command]))
                    print(f"Hardware Command Sent: {target_temp}")
                else:
                    print(f"Send {bin(high_command)} and {bin(low_command)}")

                # Update internal state and UI even in simulation
                self._desiredTemperature = target_temp
                self.update_gui_labels()
                if self.ui:
                    self.ui.acInput.clear()
                return True

            return False
        except ValueError:
            return False