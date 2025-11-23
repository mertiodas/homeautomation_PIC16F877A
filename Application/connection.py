import serial

class HomeAutomationSystemConnection:
    def __init__(self, port: int, baud_rate: int = 9600):
        self._comPort = port  # COM5 and COM6
        self._baudRate = baud_rate  #9600
    def open(self) -> bool:
        pass
    def close(self) -> bool:
        pass
    def update(self):
        pass
    def setComPort(self, port: int):
        pass
    def setBaudRate(self, rate: int):
        pass