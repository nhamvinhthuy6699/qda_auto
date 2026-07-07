import sys
import subprocess
from pathlib import Path
from datetime import datetime

from PySide6.QtCore import Qt
from PySide6.QtGui import QFont
from PySide6.QtWidgets import (
    QApplication,
    QMainWindow,
    QWidget,
    QLabel,
    QPushButton,
    QVBoxLayout,
    QHBoxLayout,
    QGridLayout,
    QTextEdit,
    QStackedWidget,
    QMessageBox,
)


def get_app_root():
    """
    Khi chạy bằng python:
        root = thư mục chứa qda_app.py hoặc thư mục cha phù hợp.

    Khi build thành QDA.exe:
        root = thư mục chứa QDA.exe.
    """
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent

    current = Path(__file__).resolve().parent

    candidates = [
        current,
        current.parent,
        current.parent.parent,
    ]

    for folder in candidates:
        if (folder / "qda_auto").exists():
            return folder

    return current


APP_ROOT = get_app_root()
QDA_BASE = APP_ROOT / "qda_auto"

VEYON_MASTER = Path(r"C:\Program Files\Veyon\veyon-master.exe")
VEYON_CONFIG = Path(r"C:\Program Files\Veyon\veyon-configurator.exe")


class QDAApp(QMainWindow):
    def __init__(self):
        super().__init__()

        self.setWindowTitle("QDA Control System")
        self.resize(1250, 760)

        self.setStyleSheet("""
            QMainWindow {
                background-color: #f3f4f6;
            }

            QLabel {
                color: #111827;
            }

            QTextEdit {
                background-color: #111827;
                color: #d1d5db;
                border-radius: 12px;
                padding: 12px;
                font-family: Consolas;
                font-size: 12px;
            }
        """)

        self.main_widget = QWidget()
        self.setCentralWidget(self.main_widget)

        self.root_layout = QHBoxLayout(self.main_widget)
        self.root_layout.setContentsMargins(0, 0, 0, 0)
        self.root_layout.setSpacing(0)

        self.sidebar = QWidget()
        self.sidebar.setFixedWidth(260)
        self.sidebar.setStyleSheet("background-color: #111827;")

        self.sidebar_layout = QVBoxLayout(self.sidebar)
        self.sidebar_layout.setContentsMargins(22, 22, 22, 22)
        self.sidebar_layout.setSpacing(10)

        self.content = QStackedWidget()
        self.content.setStyleSheet("background-color: #f3f4f6;")

        self.root_layout.addWidget(self.sidebar)
        self.root_layout.addWidget(self.content)

        self.build_sidebar()
        self.build_pages()

    # =========================
    # SIDEBAR
    # =========================

    def build_sidebar(self):
        brand = QLabel("QDA\nControl System")
        brand.setStyleSheet("""
            color: white;
            font-size: 22px;
            font-weight: 800;
            line-height: 120%;
            margin-bottom: 18px;
        """)
        self.sidebar_layout.addWidget(brand)

        self.sidebar_layout.addWidget(self.sidebar_button("Dashboard", 0))
        self.sidebar_layout.addWidget(self.sidebar_button("Veyon", 1))
        self.sidebar_layout.addWidget(self.sidebar_button("QDA Tasks", 2))
        self.sidebar_layout.addWidget(self.sidebar_button("Power / BIOS", 3))
        self.sidebar_layout.addWidget(self.sidebar_button("Logs", 4))

        self.sidebar_layout.addStretch()

        footer = QLabel(f"Base:\n{QDA_BASE}")
        footer.setWordWrap(True)
        footer.setStyleSheet("color: #9ca3af; font-size: 12px;")
        self.sidebar_layout.addWidget(footer)

    def sidebar_button(self, text, index):
        btn = QPushButton(text)
        btn.setCursor(Qt.PointingHandCursor)
        btn.setStyleSheet("""
            QPushButton {
                background-color: transparent;
                color: #d1d5db;
                text-align: left;
                border: none;
                border-radius: 10px;
                padding: 12px;
                font-size: 14px;
                font-weight: 600;
            }

            QPushButton:hover {
                background-color: #1f2937;
                color: white;
            }
        """)
        btn.clicked.connect(lambda: self.content.setCurrentIndex(index))
        return btn

    # =========================
    # PAGES
    # =========================

    def build_pages(self):
        self.content.addWidget(self.page_dashboard())
        self.content.addWidget(self.page_veyon())
        self.content.addWidget(self.page_tasks())
        self.content.addWidget(self.page_power())
        self.content.addWidget(self.page_logs())

    def page_base(self, title, subtitle):
        page = QWidget()

        layout = QVBoxLayout(page)
        layout.setContentsMargins(28, 26, 28, 26)
        layout.setSpacing(18)

        header = QWidget()
        header.setStyleSheet("""
            QWidget {
                background-color: white;
                border-radius: 18px;
            }
        """)

        header_layout = QVBoxLayout(header)
        header_layout.setContentsMargins(22, 18, 22, 18)

        title_label = QLabel(title)
        title_label.setFont(QFont("Segoe UI", 24, QFont.Bold))
        title_label.setStyleSheet("background: transparent;")

        subtitle_label = QLabel(subtitle)
        subtitle_label.setStyleSheet("""
            color: #6b7280;
            font-size: 14px;
            background: transparent;
        """)

        header_layout.addWidget(title_label)
        header_layout.addWidget(subtitle_label)

        layout.addWidget(header)

        return page, layout

    def info_card(self, title, value, desc=""):
        w = QWidget()
        w.setMinimumHeight(125)
        w.setStyleSheet("""
            QWidget {
                background-color: white;
                border-radius: 16px;
            }
        """)

        l = QVBoxLayout(w)
        l.setContentsMargins(22, 18, 22, 18)
        l.setSpacing(8)

        title_label = QLabel(title)
        title_label.setStyleSheet("""
            color: #6b7280;
            font-size: 14px;
            font-weight: 700;
            background: transparent;
        """)

        value_label = QLabel(value)
        value_label.setFont(QFont("Segoe UI", 22, QFont.Bold))
        value_label.setStyleSheet("color: #111827; background: transparent;")
        value_label.setWordWrap(True)

        desc_label = QLabel(desc)
        desc_label.setWordWrap(True)
        desc_label.setStyleSheet("""
            color: #6b7280;
            font-size: 12px;
            background: transparent;
        """)

        l.addWidget(title_label)
        l.addWidget(value_label)
        l.addWidget(desc_label)

        return w

    def action_button(self, text, desc, callback, button_text="Run"):
        w = QWidget()
        w.setMinimumHeight(155)
        w.setStyleSheet("""
            QWidget {
                background-color: white;
                border-radius: 16px;
            }
        """)

        l = QVBoxLayout(w)
        l.setContentsMargins(20, 18, 20, 18)
        l.setSpacing(10)

        title = QLabel(text)
        title.setFont(QFont("Segoe UI", 13, QFont.Bold))
        title.setWordWrap(True)
        title.setStyleSheet("color: #111827; background: transparent;")

        description = QLabel(desc)
        description.setWordWrap(True)
        description.setStyleSheet("""
            color: #6b7280;
            font-size: 13px;
            background: transparent;
        """)

        btn = QPushButton(button_text)
        btn.setFixedHeight(42)
        btn.setMinimumWidth(86)
        btn.setMaximumWidth(180)
        btn.setCursor(Qt.PointingHandCursor)
        btn.setStyleSheet("""
            QPushButton {
                background-color: #2563eb;
                color: white;
                border: none;
                border-radius: 10px;
                padding: 10px 16px;
                font-size: 14px;
                font-weight: 700;
                text-align: center;
            }

            QPushButton:hover {
                background-color: #1d4ed8;
            }
        """)

        btn.clicked.connect(callback)

        l.addWidget(title)
        l.addWidget(description)
        l.addStretch()
        l.addWidget(btn, alignment=Qt.AlignLeft)

        return w

    # =========================
    # DASHBOARD
    # =========================

    def page_dashboard(self):
        page = QWidget()

        layout = QVBoxLayout(page)
        layout.setContentsMargins(28, 26, 28, 26)
        layout.setSpacing(18)

        # ===== INFO CARDS =====
        info_grid = QGridLayout()
        info_grid.setSpacing(18)

        info_grid.addWidget(
            self.info_card(
                "Số máy trong clients.txt",
                str(self.count_clients()),
                r"Dựa trên C:\mywork\qda_auto\clients.txt"
            ),
            0,
            0
        )

        info_grid.addWidget(
            self.info_card(
                "QDA Base",
                str(QDA_BASE),
                "Thư mục nguồn đang dùng"
            ),
            0,
            1
        )

        info_grid.addWidget(
            self.info_card(
                "Thời gian",
                datetime.now().strftime("%d/%m/%Y %H:%M:%S"),
                "Thời gian hiện tại"
            ),
            0,
            2
        )

        layout.addLayout(info_grid)

        # ===== MAIN ACTIONS PANEL =====
        panel = QWidget()
        panel.setStyleSheet("""
            QWidget {
                background-color: white;
                border-radius: 18px;
            }
        """)

        panel_layout = QVBoxLayout(panel)
        panel_layout.setContentsMargins(20, 20, 20, 24)
        panel_layout.setSpacing(18)

        section_title = QLabel("Thao tác chính")
        section_title.setFont(QFont("Segoe UI", 20, QFont.Bold))
        section_title.setStyleSheet("""
            color: #111827;
            background: transparent;
        """)
        panel_layout.addWidget(section_title)

        quick = QGridLayout()
        quick.setSpacing(18)

        quick.addWidget(
            self.action_button(
                "Menu Shutdown / Restart / Hide C",
                "Shutdown, restart, hide/show C drive, kill SEB/QDA.",
                lambda: self.run_bat("run_shutdown_tasks.bat")
            ),
            0,
            0
        )

        quick.addWidget(
            self.action_button(
                "HP Power-On",
                "Configure HP BIOS auto power-on and QDA/SEB startup.",
                lambda: self.run_bat("run_hp_poweron_tasks.bat")
            ),
            0,
            1
        )

        quick.addWidget(
            self.action_button(
                "Dell Power-On",
                "Configure Dell BIOS auto power-on.",
                lambda: self.run_bat("run_dell_poweron_tasks.bat")
            ),
            1,
            0
        )

        quick.addWidget(
            self.action_button(
                "Scan rooms to clients.txt",
                "Scan room IP range from rooms.txt and update clients.txt.",
                lambda: self.run_bat("run_scan_rooms.bat")
            ),
            1,
            1
        )

        quick.addWidget(
            self.action_button(
                "Open QDA install menu",
                "Install Veyon, Office, SEB, copy files, run tasks from apps_menu.txt.",
                lambda: self.run_bat("install.bat")
            ),
            2,
            0
        )

        quick.addWidget(
            self.action_button(
                "Open rooms.txt",
                "Room/network range file for scanning.",
                lambda: self.open_path(QDA_BASE / "rooms.txt"),
                button_text="Open rooms.txt"
            ),
            2,
            1
        )

        quick.addWidget(
            self.action_button(
                "Open clients.txt",
                "Current client computer list.",
                lambda: self.open_path(QDA_BASE / "clients.txt"),
                button_text="Open clients.txt"
            ),
            3,
            0
        )

        panel_layout.addLayout(quick)

        layout.addWidget(panel)
        layout.addStretch()

        return page

    # =========================
    # VEYON
    # =========================

    def page_veyon(self):
        page, layout = self.page_base(
            "Veyon",
            "Scan, import, open Veyon Master and Configurator."
        )

        grid = QGridLayout()
        grid.setSpacing(14)

        grid.addWidget(
            self.action_button(
                "Scan rooms to Veyon",
                "Scan IP/MAC from rooms.txt and create Veyon import file.",
                lambda: self.run_bat("scan_room_to_veyon.bat")
            ),
            0,
            0
        )

        grid.addWidget(
            self.action_button(
                "Import Veyon CSV",
                "Import computers into Veyon Configurator.",
                lambda: self.run_bat("import_veyon_csv.bat")
            ),
            0,
            1
        )

        grid.addWidget(
            self.action_button(
                "Open Veyon Master",
                "Monitor and control client computers.",
                lambda: self.open_path(VEYON_MASTER),
                button_text="Open"
            ),
            0,
            2
        )

        grid.addWidget(
            self.action_button(
                "Open Veyon Configurator",
                "Edit locations, computers and authentication keys.",
                lambda: self.open_path(VEYON_CONFIG),
                button_text="Open"
            ),
            1,
            0
        )

        grid.addWidget(
            self.action_button(
                "Open rooms.txt",
                "Room/network range file.",
                lambda: self.open_path(QDA_BASE / "rooms.txt"),
                button_text="Open rooms.txt"
            ),
            1,
            1
        )

        grid.addWidget(
            self.action_button(
                "Open clients.txt",
                "Current client list.",
                lambda: self.open_path(QDA_BASE / "clients.txt"),
                button_text="Open clients.txt"
            ),
            1,
            2
        )

        layout.addLayout(grid)
        layout.addStretch()

        return page

    # =========================
    # TASKS
    # =========================

    def page_tasks(self):
        page, layout = self.page_base(
            "QDA Tasks",
            "Install software and open configuration files."
        )

        grid = QGridLayout()
        grid.setSpacing(14)

        grid.addWidget(
            self.action_button(
                "Open QDA install menu",
                "Run install.bat to deploy software/files using apps_menu.txt.",
                lambda: self.run_bat("install.bat")
            ),
            0,
            0
        )

        grid.addWidget(
            self.action_button(
                "Open apps_menu.txt",
                "Edit QDA installation task list.",
                lambda: self.open_path(QDA_BASE / "apps_menu.txt"),
                button_text="Open apps_menu.txt"
            ),
            0,
            1
        )

        grid.addWidget(
            self.action_button(
                "Open INSTALLERS",
                "Open source software folder.",
                lambda: self.open_path(QDA_BASE / "INSTALLERS"),
                button_text="Open INSTALLERS"
            ),
            0,
            2
        )

        grid.addWidget(
            self.action_button(
                "Open QDA folder",
                "Open full QDA source folder.",
                lambda: self.open_path(QDA_BASE),
                button_text="Open folder"
            ),
            1,
            0
        )

        layout.addLayout(grid)
        layout.addStretch()

        return page

    # =========================
    # POWER
    # =========================

    def page_power(self):
        page, layout = self.page_base(
            "Power / BIOS",
            "Shutdown, Restart, HP/Dell BIOS Power-On."
        )

        grid = QGridLayout()
        grid.setSpacing(14)

        grid.addWidget(
            self.action_button(
                "Shutdown / Restart / Hide C",
                "Room control menu: shutdown, restart, hide/show C, kill SEB/QDA.",
                lambda: self.run_bat("run_shutdown_tasks.bat")
            ),
            0,
            0
        )

        grid.addWidget(
            self.action_button(
                "HP Power-On",
                "Set HP BIOS power-on schedule.",
                lambda: self.run_bat("run_hp_poweron_tasks.bat")
            ),
            0,
            1
        )

        grid.addWidget(
            self.action_button(
                "Dell Power-On",
                "Set Dell BIOS power-on schedule.",
                lambda: self.run_bat("run_dell_poweron_tasks.bat")
            ),
            0,
            2
        )

        grid.addWidget(
            self.action_button(
                "Open shutdown success",
                "Open successful shutdown task list.",
                lambda: self.open_path(QDA_BASE / "shutdown_tasks_success.txt"),
                button_text="Open success"
            ),
            1,
            0
        )

        grid.addWidget(
            self.action_button(
                "Open shutdown failed",
                "Open failed shutdown task list.",
                lambda: self.open_path(QDA_BASE / "shutdown_tasks_failed.txt"),
                button_text="Open failed"
            ),
            1,
            1
        )

        layout.addLayout(grid)
        layout.addStretch()

        return page

    # =========================
    # LOGS
    # =========================

    def page_logs(self):
        page, layout = self.page_base(
            "Logs",
            "View QDA result files."
        )

        self.log_box = QTextEdit()
        self.log_box.setReadOnly(True)

        refresh_btn = QPushButton("Refresh Logs")
        refresh_btn.setCursor(Qt.PointingHandCursor)
        refresh_btn.setStyleSheet("""
            QPushButton {
                background-color: #2563eb;
                color: white;
                border: none;
                border-radius: 10px;
                padding: 10px 16px;
                font-size: 14px;
                font-weight: 700;
            }

            QPushButton:hover {
                background-color: #1d4ed8;
            }
        """)
        refresh_btn.clicked.connect(self.load_logs)

        open_qda_btn = QPushButton("Open QDA folder")
        open_qda_btn.setCursor(Qt.PointingHandCursor)
        open_qda_btn.setStyleSheet("""
            QPushButton {
                background-color: #2563eb;
                color: white;
                border: none;
                border-radius: 10px;
                padding: 10px 16px;
                font-size: 14px;
                font-weight: 700;
            }

            QPushButton:hover {
                background-color: #1d4ed8;
            }
        """)
        open_qda_btn.clicked.connect(lambda: self.open_path(QDA_BASE))

        btn_row = QHBoxLayout()
        btn_row.addWidget(refresh_btn)
        btn_row.addWidget(open_qda_btn)
        btn_row.addStretch()

        layout.addLayout(btn_row)
        layout.addWidget(self.log_box)

        self.load_logs()

        return page

    # =========================
    # SYSTEM FUNCTIONS
    # =========================

    def run_bat(self, filename):
        path = QDA_BASE / filename

        if not path.exists():
            QMessageBox.critical(self, "Error", f"File not found:\n{path}")
            return

        try:
            subprocess.Popen(
                ["cmd.exe", "/c", "start", "", str(path)],
                cwd=str(QDA_BASE),
                shell=False
            )
        except Exception as e:
            QMessageBox.critical(self, "Error", str(e))

    def open_path(self, path):
        path = Path(path)

        if not path.exists():
            QMessageBox.critical(self, "Error", f"Path not found:\n{path}")
            return

        try:
            subprocess.Popen(
                ["cmd.exe", "/c", "start", "", str(path)],
                cwd=str(path.parent if path.is_file() else path),
                shell=False
            )
        except Exception as e:
            QMessageBox.critical(self, "Error", str(e))

    def count_clients(self):
        clients = QDA_BASE / "clients.txt"

        if not clients.exists():
            return 0

        lines = clients.read_text(encoding="utf-8", errors="ignore").splitlines()
        return len([x for x in lines if x.strip() and not x.strip().startswith("#")])

    def read_file(self, path, max_chars=5000):
        path = Path(path)

        if not path.exists():
            return f"[MISSING] {path}\n"

        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
            if len(text) > max_chars:
                return text[-max_chars:]
            return text
        except Exception as e:
            return f"[ERROR] {path}: {e}\n"

    def load_logs(self):
        files = [
            "shutdown_tasks_success.txt",
            "shutdown_tasks_failed.txt",
            "hp_poweron_tasks_success.txt",
            "hp_poweron_tasks_failed.txt",
            "dell_poweron_tasks_success.txt",
            "dell_poweron_tasks_failed.txt",
            "install_success.txt",
            "install_failed.txt",
        ]

        output = []
        output.append("===== QDA LOGS =====")
        output.append(datetime.now().strftime("Updated: %d/%m/%Y %H:%M:%S"))
        output.append("")

        for f in files:
            path = QDA_BASE / f
            output.append(f"===== {f} =====")
            output.append(self.read_file(path))
            output.append("")

        self.log_box.setPlainText("\n".join(output))


if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = QDAApp()
    window.show()
    sys.exit(app.exec())