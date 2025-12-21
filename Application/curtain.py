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
        # will get the value from PIC
        return self._outdoorTemperature

    def getOutdoorPress(self) -> float:
        # will get the value from PIC
        return self._outdoorPressure

    def getLightIntensity(self) -> float:
        # will get the value from PIC
        return self._lightIntensity

    def getCurtainStatus(self) -> float:
        # will get the value from PIC
        return self._curtainStatus

    def update(self):
        super().update()
        # check if connection is ready
        """
        if not self._serial or not self._serial.is_open:
            print(f"COM{self._comPort} is not open!")
            return
        """
        """
                    Called when the 'update' button is clicked.
                    Synchronizes the GUI labels with the internal variables.
                    """
        # 1. will call self.send("G") to talk to PIC

        # 2. update the GUI Objects using getters
        if self.ui:
            # Get values
            temp = self.getOutdoorTemp()
            pressure = self.getOutdoorPress()
            light = self.getLightIntensity()
            curtain = self.getCurtainStatus()

            # Update UI with the fixed units
            self.ui.outdoorTemp.setText(f"{temp:.1f} °C")
            self.ui.outdoorPressure.setText(f"{pressure:.1f} hPa")
            self.ui.lightIntensity.setText(f"{light:.0f} lx")
            self.ui.curtainStatus.setText(f"{curtain:.0f} %")

    def setCurtainStatus(self) -> bool:
        """
        Reads from curtainInput, updates curtainStatus label.
        Returns True if successful, False if input is invalid.
        """
        try:
            # 1. Read the input from the QLineEdit
            raw_value = self.ui.curtainInput.text()
            status_val = float(raw_value)

            # 2. Validate the range (0.0 - 100.0)
            if 0.0 <= status_val <= 100.0:
                # Update the internal variable
                self._curtainStatus = status_val

                # 3. Update the QLabel in the UI
                if self.ui:
                    self.ui.curtainStatus.setText(f"{status_val:.1f} %")
                    self.ui.curtainInput.clear()  # Clear box after success

                print(f"Curtain logic success: {status_val}%")
                return True  # Everything worked

            else:
                print("Validation failed: Value must be between 0 and 100")
                return False  # Value out of range

        except ValueError:
            print("Validation failed: Input is not a valid number")
            return False  # Not a number
