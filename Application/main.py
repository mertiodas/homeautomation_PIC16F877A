import sys
from PyQt5.QtWidgets import QMainWindow, QApplication
from PyQt5.QtCore import QTimer, Qt
from gui import Ui_MainWindow
from AC import AirConditionerSystemConnection
from curtain import CurtainControlSystemConnection
import warnings

warnings.filterwarnings("ignore", category=DeprecationWarning)
import csv
from datetime import datetime


class MainWindowLogic(QMainWindow, Ui_MainWindow):
    def __init__(self):
        super().__init__()
        self.setupUi(self)

        # Initialize with None first so the attribute exists
        self.api_ac = None
        self.api_curtain = None

        try:
            self.api_ac = AirConditionerSystemConnection(port=10, ui=self)
            self.api_curtain = CurtainControlSystemConnection(port=5, ui=self)
        except Exception as e:
            print(f"Connection Initialization Warning: {e}")

        # Only connect buttons if the API objects were created successfully
        if self.api_ac:
            self.acApply.clicked.connect(self.api_ac.setDesiredTemp)

        if self.api_curtain:
            self.curtainApply.clicked.connect(self.api_curtain.setCurtainStatus)

        self.update.clicked.connect(self.handle_global_update)
        self.actionSave.triggered.connect(self.handle_save)


        # This refreshes the GUI every 2 seconds without having to click 'Update'
        self.refresh_timer = QTimer()
        self.refresh_timer.timeout.connect(self.handle_global_update)
        self.refresh_timer.start(10000)

        self.statusBar().showMessage("System Initialized in Simulation Mode", 3000)

    def handle_save(self):
        """Saves current sensor and system data to a CSV file."""
        try:
            data_row = {
                "Timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                "Ambient_Temp": self.api_ac.getAmbientTemp(),
                "Desired_Temp": self.api_ac.getDesiredTemp(),
                "Fan_Speed": self.api_ac.getFanSpeed(),
                "Outdoor_Temp": self.api_curtain.getOutdoorTemp(),
                "Pressure": self.api_curtain.getOutdoorPress(),
                "Light": self.api_curtain.getLightIntensity(),
                "Curtain_Status": self.api_curtain._curtainStatus
            }

            filename = "automation_data.csv"

            # Simplified file check
            import os
            file_exists = os.path.isfile(filename)

            with open(filename, mode='a', newline='') as file:
                writer = csv.DictWriter(file, fieldnames=data_row.keys())
                if not file_exists:
                    writer.writeheader()
                writer.writerow(data_row)

            self.statusBar().showMessage(f"Data saved to {filename}", 2000)
            print(f"Log updated at {data_row['Timestamp']}")

        except Exception as e:
            print(f"Save Error: {e}")

    def handle_global_update(self):
        """Refreshes data from both boards safely."""
        print("--- Master Update Triggered ---")

        # 1. Update AC Board (Check if it exists first)
        if self.api_ac is not None:
            try:
                self.api_ac.update()
            except Exception as e:
                print(f"AC Sync Error: {e}")
        else:
            print("AC API not initialized - Skipping update")

        # 2. Update Curtain Board (Check if it exists first)
        if self.api_curtain is not None:
            try:
                self.api_curtain.update()
            except Exception as e:
                print(f"Curtain Sync Error: {e}")
        else:
            print("Curtain API not initialized - Skipping update")


if __name__ == '__main__':
    app = QApplication(sys.argv)
    window = MainWindowLogic()
    window.show()
    sys.exit(app.exec_())