from connection import HomeAutomationSystemConnection

class CurtainControlSystemConnection(HomeAutomationSystemConnection):
    def __init__(self, port: int = 6):
        super().__init__(port)
        self._curtainStatus: float = 0.0
        self._outdoorTemperature: float = 0.0
        self._outdoorPressure: float = 0.0
        self._lightIntensity: float = 0.0
    def update(self):
        pass
    def setCurtainStatus(self, std: float) -> bool:
        pass
    def getOutdoorTemp(self) -> float:
        pass
    def getOutdoorPress(self) -> float:
        pass
    def getLightIntensity(self) -> float:
        pass