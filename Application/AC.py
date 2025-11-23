from connection import HomeAutomationSystemConnection

class AirConditionerSystemConnection(HomeAutomationSystemConnection):
    def __init__(self, port: int = 5):
        super().__init__(port)
        self._desiredTemperature: float = 0.0
        self._ambientTemperature: float = 0.0
        self._fanSpeed: int = 0

    def update(self):
        pass

    def setDesiredTemp(self, temp: float) -> bool:
        pass

    def getAmbientTemp(self) -> float:
        pass

    def getFanSpeed(self) -> int:
        pass

    def getDesiredTemp(self) -> float:
        pass