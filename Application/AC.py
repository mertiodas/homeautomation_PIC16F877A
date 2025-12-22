from connection import HomeAutomationSystemConnection

class AirConditionerSystemConnection(HomeAutomationSystemConnection):
    def __init__(self, port: int , ui):
        super().__init__(port, ui, "ac")
        self.ui = ui
        self._desiredTemperature: float = 0.0
        self._ambientTemperature: float = 0.0
        self._fanSpeed: int = 0
        # uses com5 & serial to communicate.
        ambient = self.getAmbientTemp()
        fan = self.getFanSpeed()
        desired = self.getDesiredTemp()

        # Display variables in the QLabel objects
        self.ui.ambientTemp.setText(f"{ambient:.1f} °C")
        self.ui.fanSpeed.setText(f"{fan} RPS")
        self.ui.desiredTemp.setText(f"{desired:.1f} °C")

    def getAmbientTemp(self) -> float:
        """Gets ambient temp by requesting High (Integral) and Low (Fractional) bytes."""
        if self._serial and self._serial.is_open:
            try:
                # 1. Request Integral Part (Command 00000100B = 0x04)
                self._serial.write(bytes([0x04]))
                high_byte = self._serial.read(1)

                # 2. Request Fractional Part (Command 00000011B = 0x03)
                self._serial.write(bytes([0x03]))
                low_byte = self._serial.read(1)

                if high_byte and low_byte:
                    # Convert raw bytes to integers
                    integral = ord(high_byte)
                    fractional = ord(low_byte)
                    # Combine them (e.g., 24 + 0.5)
                    self._ambientTemperature = integral + (fractional / 100.0)
            except Exception as e:
                print(f"Error reading Ambient Temp: {e}")

        return self._ambientTemperature

    def getFanSpeed(self) -> int:
        """Gets fan speed (Command 00000101B = 0x05)."""
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
        """Gets the desired temp currently stored on the PIC (Commands 0x02 and 0x01)."""
        if self._serial and self._serial.is_open:
            try:
                # High byte (0x02)
                self._serial.write(bytes([0x02]))
                high = ord(self._serial.read(1))

                # Low byte (0x01)
                self._serial.write(bytes([0x01]))
                low = ord(self._serial.read(1))

                self._desiredTemperature = high + (low / 100.0)
            except:
                pass

        return self._desiredTemperature

    def update(self):
        """
        Synchronizes the GUI labels with the PIC16F877A hardware
        by triggering binary requests via getters.
        """
        # 1. Call base class to update Port/Baudrate labels
        super().update()

        # 2. Safety Check: If serial isn't open, don't try to communicate
        if not self._serial or not self._serial.is_open:
            print(f"Update failed: COM{self._comPort} is not open.")
            return

        # 3. Update the GUI Objects using Getters
        # Note: In your specific protocol, we don't send "G".
        # The individual getters send the specific binary command bytes (0x01-0x05).
        if self.ui:
            # These calls now trigger the Serial read/write sequence
            ambient = self.getAmbientTemp()
            fan = self.getFanSpeed()
            desired = self.getDesiredTemp()

            # Display variables in the QLabel objects
            self.ui.ambientTemp.setText(f"{ambient:.1f} °C")
            self.ui.fanSpeed.setText(f"{fan} RPS")
            self.ui.desiredTemp.setText(f"{desired:.1f} °C")

            print(f"Successfully refreshed AC Board data from COM{self._comPort}")

    # AC.py

    def setDesiredTemp(self) -> bool:
        """
        Parses input to 6-bit binary format for Integral and Fractional parts.
        Sends bit-masked commands to PIC16F877A per requirements [R2.1.4-1].
        """
        try:
            # 1. Read from the UI
            input_text = self.ui.acInput.text()
            target_temp = float(input_text)

            # 2. Validation
            if 10.0 <= target_temp <= 50.0:
                # 3. Prepare Binary Data
                # Integral part (e.g., 24 from 24.5)
                integral_val = int(target_temp)
                # Fractional part (e.g., 50 from 24.5)
                # Note: Requirements say fractional part is also 6-bit binary
                fractional_val = int(round((target_temp - integral_val) * 100))

                # 4. Construct Command Bytes
                # Set High Byte (Integral): Format 11 t5 t4 t3 t2 t1 t0
                # 0xC0 is 11000000 in binary
                high_command = 0xC0 | (integral_val & 0x3F)

                # Set Low Byte (Fractional): Format 10 t5 t4 t3 t2 t1 t0
                # 0x80 is 10000000 in binary
                low_command = 0x80 | (fractional_val & 0x3F)

                # 5. Send to Hardware
                if self._serial and self._serial.is_open:
                    # Send high byte (Integral)
                    self._serial.write(bytes([high_command]))
                    # Send low byte (Fractional)
                    self._serial.write(bytes([low_command]))

                    # Update internal variable and UI
                    self._desiredTemperature = target_temp
                    if self.ui:
                        self.ui.desiredTemp.setText(f"{target_temp:.1f} °C")
                        self.ui.acInput.clear()

                    print(f"PIC Command Sent: Integral={bin(high_command)}, Frac={bin(low_command)}")
                    return True
                else:
                    print("Serial port not open.")
                    return False

            else:
                print("Value out of range (10-50)")
                return False

        except ValueError:
            print("Please enter a valid number")
            return False




