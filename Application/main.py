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
        self.api_ac = AirConditionerSystemConnection(port=5)
        self.api_curtain = CurtainControlSystemConnection(port=6)
    def update_all_systems(self):
        pass

    def refresh_gui_labels(self):
        pass


# --- Application Entry Point ---
if __name__ == '__main__':
    app = QApplication(sys.argv)
    window = MainWindowLogic()
    window.show()
    sys.exit(app.exec_())