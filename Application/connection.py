import serial


class HomeAutomationSystemConnection:
    def __init__(self, port: int, ui, name_prefix: str, baud_rate: int = 9600):
        self._comPort = port
        self._baudRate = baud_rate
        self.ui = ui
        self.prefix = name_prefix  # "ac" or "curtain"

        # 1. Start with _serial as None.
        # Do NOT open the port in __init__ to prevent GUI freezing.
        self._serial = None

        # 2. Initial GUI Sync (fills labels with COMx and baudrate)
        self.update()

    def open(self) -> bool:
        """ Initiates UART connection (8N1). """
        try:
            # Avoid opening if already open
            if self._serial and self._serial.is_open:
                return True

            self._serial = serial.Serial(
                port=f"COM{self._comPort}",
                baudrate=self._baudRate,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                timeout=0.1  # Short timeout keeps GUI responsive
            )

            if self._serial.is_open:
                print(f"Connected to {self.prefix} on COM{self._comPort}")
                return True
            return False

        except Exception as e:
            # In simulation mode, we just print the error and keep self._serial as None
            print(f"Connection Failed for {self.prefix} on COM{self._comPort}: {e}")
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