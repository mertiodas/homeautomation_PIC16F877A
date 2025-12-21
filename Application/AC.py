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
        # will communicate with PIC
        return self._ambientTemperature

    def getFanSpeed(self) -> int:
        # will communicate with PIC
        return self._fanSpeed

    def getDesiredTemp(self) -> float:
        # will communicate with PIC
        return self._desiredTemperature
    def update(self):
        super().update()
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
            # Get values via Getters
            ambient = self.getAmbientTemp()
            fan = self.getFanSpeed()
            desired = self.getDesiredTemp()

            # Display variables in the QLabel objects
            self.ui.ambientTemp.setText(f"{ambient:.1f} °C")
            self.ui.fanSpeed.setText(f"{fan} RPS")
            self.ui.desiredTemp.setText(f"{desired:.1f} °C")

    # AC.py

    def setDesiredTemp(self) -> bool:
        """
        Reads from acInput, validates 10-50 range, and updates UI.
        Returns True if successful, False otherwise.
        """
        try:
            # 1. Read from the UI using the reference
            input_text = self.ui.acInput.text()
            target_temp = float(input_text)

            # 2. Validation
            if 10.0 <= target_temp <= 50.0:
                self._desiredTemperature = target_temp

                # 3. Update Display
                if self.ui:
                    self.ui.desiredTemp.setText(f"{target_temp:.1f} °C")
                    self.ui.acInput.clear()

                # 4. (Future Hardware Step)
                # self.send(f"D{int(target_temp):02d}\n")

                print(f"AC logic success: {target_temp} °C")
                return True  # Success!

            else:
                print("Value out of range (10-50)")
                return False  # Failed validation

        except ValueError:
            print("Please enter a valid number")
            return False  # Failed parsing




