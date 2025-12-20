from connection import HomeAutomationSystemConnection


class AirConditionerSystemConnection(HomeAutomationSystemConnection):
    def __init__(self, port: int = 5):
        super().__init__(port)
        self._desiredTemperature: float = 0.0
        self._ambientTemperature: float = 0.0
        self._fanSpeed: int = 0

    # --------------------------------------------------
    # Periodic update (called by GUI / main loop)
    # --------------------------------------------------
    def update(self):
        if not self.isConnected():
            return

        self.send("G\n")

        while self.hasData():
            line = self.readLine().strip()
            if len(line) < 2:
                continue

            cmd = line[0]
            value = line[1:]

            if not value.isdigit():
                continue

            value = int(value)

            if cmd == 'A':
                self._ambientTemperature = float(value)
            elif cmd == 'F':
                self._fanSpeed = value

    # --------------------------------------------------
    # Set desired temperature (PC -> PIC)
    # --------------------------------------------------
    def setDesiredTemp(self, temp: float) -> bool:
        if not self.isConnected():
            return False

        temp_int = int(temp)
        if temp_int < 0 or temp_int > 99:
            return False

        self._desiredTemperature = float(temp_int)
        self.send(f"D{temp_int:02d}\n")
        return True

    # --------------------------------------------------
    # Getters (GUI reads these)
    # --------------------------------------------------
    def getAmbientTemp(self) -> float:
        return self._ambientTemperature

    def getFanSpeed(self) -> int:
        return self._fanSpeed

    def getDesiredTemp(self) -> float:
        return self._desiredTemperature
