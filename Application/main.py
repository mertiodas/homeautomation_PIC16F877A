import sys
from PyQt5.QtWidgets import QMainWindow, QApplication
from PyQt5.QtCore import QTimer, Qt
from gui import Ui_MainWindow
from AC import AirConditionerSystemConnection
from curtain import CurtainControlSystemConnection
import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)



class MainWindowLogic(QMainWindow, Ui_MainWindow):
    def __init__(self):
        super().__init__()
        self.setupUi(self)
        self.api_ac = AirConditionerSystemConnection(port=5, ui = self)
        self.api_curtain = CurtainControlSystemConnection(port=6, ui = self)
        self.acApply.clicked.connect(self.api_ac.setDesiredTemp)
        self.curtainApply.clicked.connect(self.api_curtain.setCurtainStatus)
        self.update.clicked.connect(self.handle_global_update)

    def handle_global_update(self):
        """
        Refreshes data from both boards.
        Triggers dynamic GUI updates for ports, baudrates, and sensor values.
        """
        print("--- Master Update Triggered ---")
        ac_success = False
        curtain_success = False

        # 1. Update Air Conditioner (Board 1 - COM5)
        try:
            # This now updates acPort, acBaudrate, ambientTemp, and fanSpeed
            self.api_ac.update()
            ac_success = True
            print("AC System: Update Successful")
        except Exception as e:
            print(f"AC Update Error: {e}")
            # This will catch if acPort or acBaudrate objects are missing in GUI
            self.statusBar().showMessage(f"AC Board Error: {str(e)}", 3000)

        # 2. Update Curtain & Environment (Board 2 - COM6)
        try:
            # This now updates curtainPort, curtainBaudrate, outdoorTemp, pressure, and light
            self.api_curtain.update()
            curtain_success = True
            print("Curtain System: Update Successful")
        except Exception as e:
            print(f"Curtain Update Error: {e}")
            self.statusBar().showMessage(f"Curtain Board Error: {str(e)}", 3000)

        # 3. Final Multi-Status Feedback
        if ac_success and curtain_success:
            self.statusBar().showMessage("All systems updated successfully.", 4000)
        elif ac_success:
            self.statusBar().showMessage("AC Updated, but Curtain Board failed.", 4000)
        elif curtain_success:
            self.statusBar().showMessage("Curtain Updated, but AC Board failed.", 4000)
        else:
            self.statusBar().showMessage("Critical: All communication lines down!", 5000)



# --- Application Entry Point ---
if __name__ == '__main__':
    app = QApplication(sys.argv)
    window = MainWindowLogic()
    window.show()
    sys.exit(app.exec_())