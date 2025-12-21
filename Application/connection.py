import serial
class HomeAutomationSystemConnection:
    def __init__(self, port: int, ui, name_prefix: str, baud_rate: int = 9600):
        self._comPort = port # COM5 and COM6
        self._baudRate = baud_rate
        self.ui = ui
        self.prefix = name_prefix  # "ac" or "curtain"
        self._serial = None
        # Dynamically finds self.ui.acPort or self.ui.curtainPort
        port_label = getattr(self.ui, f"{self.prefix}Port")
        # Dynamically finds self.ui.acBaudrate or self.ui.curtainBaudrate
        baud_label = getattr(self.ui, f"{self.prefix}Baudrate")

        port_label.setText(f"COM{self._comPort}")
        baud_label.setText(str(self._baudRate))
    def open(self) -> bool:
        """Initiates UART connection."""
        try:
            self._serial = serial.Serial(f"COM{self._comPort}", self._baudRate, timeout=1)
            return True
        except Exception as e:
            print(f"Connection Failed on COM{self._comPort}: {e}")
            return False

    def close(self) -> bool:
        """Closes UART connection."""
        if self._serial and self._serial.is_open:
            self._serial.close()
            return True
        return False
    def update(self):
        """Updates the common port and baudrate labels in the GUI."""
        if self.ui:
            # Dynamically finds self.ui.acPort or self.ui.curtainPort
            port_label = getattr(self.ui, f"{self.prefix}Port")
            # Dynamically finds self.ui.acBaudrate or self.ui.curtainBaudrate
            baud_label = getattr(self.ui, f"{self.prefix}Baudrate")

            port_label.setText(f"COM{self._comPort}")
            baud_label.setText(str(self._baudRate))
    def setComPort(self, port: int):
        # will send message to PIC
        self._comPort = port

    def setBaudRate(self, rate: int):
        # will send message to PIC
        self._baudRate = rate
