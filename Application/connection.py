import serial


class HomeAutomationSystemConnection:
    def __init__(self, port: int, ui, name_prefix: str, baud_rate: int = 9600):
        self._comPort = port
        self._baudRate = baud_rate
        self.ui = ui
        self.prefix = name_prefix  # "ac" or "curtain"
        self._serial = None

    def open(self) -> bool:
        """ Initiates UART connection (8N1) with port cleanup. """
        try:
            # Prevent re-opening if already active
            if self._serial and self._serial.is_open:
                return True

            self._serial = serial.Serial(
                port=f"COM{self._comPort}",
                baudrate=self._baudRate,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                timeout=0.1,
                write_timeout=0.1
            )

            if self._serial.is_open:
                # Flush buffers to remove startup noise from PICSimLab
                self._serial.reset_input_buffer()
                self._serial.reset_output_buffer()

                print(f"Connected: {self.prefix} on COM{self._comPort}")
                return True

            return False

        except serial.SerialException as e:
            # Specifically handles "Access Denied" if port is in use
            print(f"Port Error: {self.prefix} cannot access COM{self._comPort} ({e})")
            self._serial = None
            return False
        except Exception as e:
            # Handles general failures
            print(f"Simulation Mode: {self.prefix} offline ({e})")
            self._serial = None
            return False

    def close(self) -> bool:
        """ Safely closes the connection. """
        try:
            if self._serial and self._serial.is_open:
                self._serial.close()
                print(f"COM{self._comPort} closed successfully.")

            self._serial = None
            return True
        except Exception as e:
            print(f"Error while closing COM{self._comPort}: {e}")
            return False

    def update(self):
        """ Updates the GUI labels dynamically. """
        if self.ui:
            try:
                # Use getattr safely to update UI labels
                port_label = getattr(self.ui, f"{self.prefix}Port", None)
                baud_label = getattr(self.ui, f"{self.prefix}Baudrate", None)

                if port_label:
                    port_label.setText(f"COM{self._comPort}")
                if baud_label:
                    baud_label.setText(str(self._baudRate))
            except Exception as e:
                print(f"GUI Sync Error: {e}")

    def setComPort(self, port: int):
        if isinstance(port, int) and port > 0:
            self._comPort = port
            self.update()  # Update the label immediately

    def setBaudRate(self, rate: int):
        self._baudRate = rate
        self.update()  # Update the label immediately