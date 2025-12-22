import serial
class HomeAutomationSystemConnection:
    def __init__(self, port: int, ui, name_prefix: str, baud_rate: int = 9600):
        self._comPort = port # COM5 and COM6
        self._baudRate = baud_rate
        self.ui = ui
        self.prefix = name_prefix  # "ac" or "curtain"
        self._serial = serial.Serial(f"COM{self._comPort}", self._baudRate, timeout=0.1)
        # Dynamically finds self.ui.acPort or self.ui.curtainPort
        port_label = getattr(self.ui, f"{self.prefix}Port")
        # Dynamically finds self.ui.acBaudrate or self.ui.curtainBaudrate
        baud_label = getattr(self.ui, f"{self.prefix}Baudrate")

        port_label.setText(f"COM{self._comPort}")
        baud_label.setText(str(self._baudRate))

    def open(self) -> bool:
        """
        Initiates UART connection to the PIC16F877A.
        Configured for 8-bit data, no parity, 1 stop bit (8N1).
        """
        try:
            # Using a 0.1s timeout is better for a responsive GUI
            self._serial = serial.Serial(
                port=f"COM{self._comPort}",
                baudrate=self._baudRate,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                timeout=0.1  # PIC responds fast, no need to wait 1 second
            )

            if self._serial.is_open:
                print(f"Connected to Board on COM{self._comPort} at {self._baudRate} baud.")
                return True
            return False

        except Exception as e:
            print(f"Connection Failed on COM{self._comPort}: {e}")
            self._serial = None
            return False

    def close(self) -> bool:
        """
        Safely closes the UART connection to the PIC board.
        Returns True if successfully closed, False if it was already closed.
        """
        try:
            if self._serial and self._serial.is_open:
                self._serial.close()
                # Set to None so .is_open checks don't crash later
                self._serial = None
                print(f"Connection on COM{self._comPort} closed successfully.")
                return True

            print(f"Connection on COM{self._comPort} was already closed.")
            return False

        except Exception as e:
            print(f"Error while closing COM{self._comPort}: {e}")
            return False

    def update(self):
        """
        Updates the common port and baudrate labels in the GUI.
        Uses self.prefix ('ac' or 'curtain') to find the correct labels.
        """
        if self.ui:
            try:
                # Dynamically finds self.ui.acPort or self.ui.curtainPort
                port_label_name = f"{self.prefix}Port"
                # Dynamically finds self.ui.acBaudrate or self.ui.curtainBaudrate
                baud_label_name = f"{self.prefix}Baudrate"

                # Use getattr with a default of None to prevent crashing
                port_label = getattr(self.ui, port_label_name, None)
                baud_label = getattr(self.ui, baud_label_name, None)

                # Update Port Label
                if port_label:
                    port_label.setText(f"COM{self._comPort}")

                # Update Baudrate Label
                if baud_label:
                    baud_label.setText(str(self._baudRate))

            except Exception as e:
                print(f"GUI Sync Error for {self.prefix}: {e}")

    def setComPort(self, port: int):
        """Sets the COM port number (e.g., 6 for COM6)."""
        if isinstance(port, int) and port > 0:
            self._comPort = port
            print(f"Target port for {self.prefix} set to COM{port}")
        else:
            print(f"Invalid COM port: {port}")

    def setBaudRate(self, rate: int):
        """Sets the Baud Rate (e.g., 9600)."""
        # Standard UART baud rates check
        valid_rates = [1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200]
        if rate in valid_rates:
            self._baudRate = rate
            print(f"Baud rate for {self.prefix} set to {rate}")
        else:
            # We allow it anyway for flexibility, but give a warning
            self._baudRate = rate
            print(f"Warning: {rate} is a non-standard baud rate for PIC.")
