import sys
from PyQt5.QtWidgets import QMainWindow, QApplication
from PyQt5.QtCore import QTimer, Qt
from .ui_main_window import Ui_MainWindow  # Imports the structure from the generated UI file

# --- Import API Classes ---
from .AC import AirConditionerSystemConnection
from .curtain import CurtainControlSystemConnection


class MainWindowLogic(QMainWindow, Ui_MainWindow):
    """
    This class combines the GUI structure (Ui_MainWindow) with the application logic.
    """

    def __init__(self):
        super().__init__()

        # 1. Setup the UI Layout
        self.setupUi(self)

        ## 2. Instantiate API Connections ##
        # These are instances of the subclasses which inherit from HomeAutomationSystemConnection
        self.api_ac = AirConditionerSystemConnection(port=5)
        self.api_curtain = CurtainControlSystemConnection(port=6)

        ## 3. Establish Periodic Data Update (QTimer) ##
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_all_systems)
        self.timer.start(1000)  # Update every 1 second

        # 4. Connect Buttons (e.g., self.btn_ac.clicked.connect(self.show_ac_menu))

    def update_all_systems(self):
        """
        Calls update for both independent PICs and refreshes the GUI labels.
        """
        # Call the update routine for Board 1 (Member 3's task)
        self.api_ac.update()
        # Call the update routine for Board 2 (Member 5's task)
        self.api_curtain.update()

        self.refresh_gui_labels()

    def refresh_gui_labels(self):
        """Fetches data from API instances and updates QLabels."""
        ambient_temp = self.api_ac.getAmbientTemp()
        self.ambient_temp_label.setText(f"Ambient Temp: {ambient_temp:.1f} °C")
        # ... (update all other labels here) ...
        pass


# --- Application Entry Point ---
if __name__ == '__main__':
    app = QApplication(sys.argv)
    window = MainWindowLogic()
    window.show()
    sys.exit(app.exec_())