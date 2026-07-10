import sys
import csv
import json
import subprocess
from pathlib import Path
from datetime import datetime

from PySide6.QtCore import Qt, QTimer, QProcess
from PySide6.QtGui import QFont, QIcon
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
    QComboBox,
    QListWidget,
    QTableWidget,
    QTableWidgetItem,
    QHeaderView,
)


# =========================
# CONFIG - FIXED PATH
# =========================

APP_ROOT = Path(r"C:\mywork")
QDA_BASE = Path(r"C:\mywork\qda_auto")

ASSETS_DIR = APP_ROOT / "assets"
APP_ICON = ASSETS_DIR / "qda.ico"

VEYON_MASTER = Path(r"C:\Program Files\Veyon\veyon-master.exe")
VEYON_CONFIG = Path(r"C:\Program Files\Veyon\veyon-configurator.exe")


class QDAApp(QMainWindow):
    def __init__(self):
        super().__init__()

        self.setWindowTitle("QDA Control System")

        if APP_ICON.exists():
            self.setWindowIcon(QIcon(str(APP_ICON)))

        self.resize(1320, 800)

        self.current_config_file = None
        self.inventory_data = {}
        self.inventory_signature = ""
        self.selected_client_ip = ""

        self.check_process = None
        self.check_anim_step = 0
        self.check_current_ip = ""
        self.check_mode = ""

        self.runner_windows = []

        self.setStyleSheet("""
            QMainWindow {
                background-color: #f3f4f6;
            }

            QLabel {
                color: #111827;
            }

            QComboBox {
                background-color: white;
                border: 1px solid #d1d5db;
                border-radius: 10px;
                padding: 8px 10px;
                font-size: 13px;
                color: #111827;
            }

            QListWidget {
                background-color: white;
                border: 1px solid #e5e7eb;
                border-radius: 14px;
                padding: 8px;
                font-size: 14px;
                color: #111827;
            }

            QListWidget::item {
                padding: 10px;
                border-radius: 8px;
            }

            QListWidget::item:selected {
                background-color: #2563eb;
                color: white;
            }

            QTableWidget {
                background-color: white;
                border: 1px solid #e5e7eb;
                border-radius: 14px;
                gridline-color: #e5e7eb;
                font-size: 13px;
                color: #111827;
            }

            QTableWidget::item {
                padding: 6px;
                color: #111827;
            }

            QHeaderView::section {
                background-color: #f9fafb;
                color: #374151;
                padding: 8px;
                border: none;
                font-weight: 700;
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

        self.content.currentChanged.connect(self.on_page_changed)

        self.inventory_timer = QTimer(self)
        self.inventory_timer.timeout.connect(self.auto_refresh_inventory_if_needed)
        self.inventory_timer.start(2000)

        self.clock_timer = QTimer(self)
        self.clock_timer.timeout.connect(self.update_clock)
        self.clock_timer.start(1000)

        self.refresh_timer = QTimer(self)
        self.refresh_timer.timeout.connect(self.refresh_dashboard_data)
        self.refresh_timer.start(3000)

        self.check_anim_timer = QTimer(self)
        self.check_anim_timer.timeout.connect(self.animate_check_status)

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
        self.sidebar_layout.addWidget(self.sidebar_button("Files / Config", 4))
        self.sidebar_layout.addWidget(self.sidebar_button("Rooms / Clients", 5))
        self.sidebar_layout.addWidget(self.sidebar_button("Logs", 6))

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
    # BASE UI
    # =========================

    def build_pages(self):
        self.content.addWidget(self.page_dashboard())
        self.content.addWidget(self.page_veyon())
        self.content.addWidget(self.page_tasks())
        self.content.addWidget(self.page_power())
        self.content.addWidget(self.page_files_config())
        self.content.addWidget(self.page_rooms_clients())
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

        w.title_label = title_label
        w.value_label = value_label
        w.desc_label = desc_label

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

    def small_button(self, text, callback, gray=False):
        btn = QPushButton(text)
        btn.setCursor(Qt.PointingHandCursor)
        btn.setFixedHeight(38)
        btn.setMinimumWidth(110)

        if gray:
            bg = "#e5e7eb"
            hover = "#d1d5db"
            color = "#111827"
        else:
            bg = "#2563eb"
            hover = "#1d4ed8"
            color = "white"

        btn.setStyleSheet(f"""
            QPushButton {{
                background-color: {bg};
                color: {color};
                border: none;
                border-radius: 10px;
                padding: 8px 14px;
                font-size: 13px;
                font-weight: 700;
            }}

            QPushButton:hover {{
                background-color: {hover};
            }}
        """)

        btn.clicked.connect(callback)
        return btn

    # =========================
    # DASHBOARD
    # =========================

    def page_dashboard(self):
        page = QWidget()

        layout = QVBoxLayout(page)
        layout.setContentsMargins(28, 26, 28, 26)
        layout.setSpacing(18)

        info_grid = QGridLayout()
        info_grid.setSpacing(18)

        self.clients_count_card = self.info_card(
            "Số máy trong clients.txt",
            str(self.count_clients()),
            f"Dựa trên {QDA_BASE / 'clients.txt'}"
        )
        info_grid.addWidget(self.clients_count_card, 0, 0)

        self.qda_base_card = self.info_card(
            "QDA Base",
            str(QDA_BASE),
            "Thư mục nguồn đang dùng"
        )
        info_grid.addWidget(self.qda_base_card, 0, 1)

        self.time_card = self.info_card(
            "Cập nhật hệ thống",
            datetime.now().strftime("%d/%m/%Y %H:%M:%S"),
            "Thời gian update hiện tại"
        )
        info_grid.addWidget(self.time_card, 0, 2)

        layout.addLayout(info_grid)

        refresh_btn = self.small_button("Refresh", self.refresh_dashboard_data)
        layout.addWidget(refresh_btn, alignment=Qt.AlignRight)

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
                "Menu Shutdown",
                "Shutdown, kill SEB/QDA.",
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
                "Exam Mode",
                "Enable/disable exam mode: hide/show C drive, disable/enable Wi-Fi, keep LAN/Ethernet, then restart.",
                lambda: self.run_bat("run_exam_mode.bat")
            ),
            1,
            0
        )

        quick.addWidget(
            self.action_button(
                "Dell Power-On",
                "Configure Dell BIOS auto power-on.",
                lambda: self.run_bat("run_dell_poweron_tasks.bat")
            ),
            1,
            1
        )

        quick.addWidget(
            self.action_button(
                "Scan rooms to clients.txt",
                "Scan room IP range from rooms.txt and update clients.txt.",
                lambda: self.run_bat("run_scan_rooms.bat")
            ),
            2,
            0
        )

        quick.addWidget(
            self.action_button(
                "Open QDA install menu",
                "Install Veyon, Office, SEB, copy files, run tasks from apps_menu.txt.",
                lambda: self.run_bat("install.bat")
            ),
            2,
            1
        )

        quick.addWidget(
            self.action_button(
                "Files / Config",
                "View and edit rooms.txt, clients.txt, apps_menu.txt inside the app.",
                lambda: self.content.setCurrentIndex(4),
                button_text="Open Files"
            ),
            3,
            0
        )

        quick.addWidget(
            self.action_button(
                "Rooms / Clients",
                "View scanned rooms and client inventory inside the app.",
                lambda: self.content.setCurrentIndex(5),
                button_text="Open Rooms"
            ),
            3,
            1
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
                "Files / Config",
                "Edit rooms.txt and clients.txt inside QDA.",
                lambda: self.content.setCurrentIndex(4),
                button_text="Open Files"
            ),
            1,
            1
        )

        grid.addWidget(
            self.action_button(
                "Rooms / Clients",
                "View rooms and scanned clients.",
                lambda: self.content.setCurrentIndex(5),
                button_text="Open Rooms"
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
                "Edit apps_menu.txt",
                "Edit QDA installation task list inside the app.",
                lambda: self.open_config_file("apps_menu.txt"),
                button_text="Edit apps_menu.txt"
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
                "Shutdown",
                "Room control menu: shutdown, kill SEB/QDA.",
                lambda: self.run_bat("run_shutdown_tasks.bat")
            ),
            0,
            0
        )

        grid.addWidget(
            self.action_button(
                "Exam Mode",
                "Enable/disable exam mode: hide/show C, disable/enable Wi-Fi, keep LAN/Ethernet, restart.",
                lambda: self.run_bat("run_exam_mode.bat")
            ),
            0,
            1
        )

        grid.addWidget(
            self.action_button(
                "HP Power-On",
                "Set HP BIOS power-on schedule.",
                lambda: self.run_bat("run_hp_poweron_tasks.bat")
            ),
            0,
            2
        )

        grid.addWidget(
            self.action_button(
                "Dell Power-On",
                "Set Dell BIOS power-on schedule.",
                lambda: self.run_bat("run_dell_poweron_tasks.bat")
            ),
            1,
            0
        )

        grid.addWidget(
            self.action_button(
                "Open shutdown success",
                "Open successful shutdown task list.",
                lambda: self.open_path(QDA_BASE / "shutdown_tasks_success.txt"),
                button_text="Open success"
            ),
            1,
            1
        )

        grid.addWidget(
            self.action_button(
                "Open shutdown failed",
                "Open failed shutdown task list.",
                lambda: self.open_path(QDA_BASE / "shutdown_tasks_failed.txt"),
                button_text="Open failed"
            ),
            1,
            2
        )

        layout.addLayout(grid)
        layout.addStretch()

        return page

    # =========================
    # FILES / CONFIG
    # =========================

    def get_config_file_names(self):
        files = []

        if not QDA_BASE.exists():
            return [
                "rooms.txt",
                "clients.txt",
                "apps_menu.txt",
                "veyon_import.csv",
                "veyon_clients.csv",
            ]

        allowed_ext = [
            ".txt",
            ".csv",
        ]

        excluded_keywords = [
            "success",
            "failed",
            "fail",
        ]

        for path in QDA_BASE.iterdir():
            if not path.is_file():
                continue

            name = path.name
            lower_name = name.lower()

            if path.suffix.lower() not in allowed_ext:
                continue

            skip = False

            for keyword in excluded_keywords:
                if keyword in lower_name:
                    skip = True
                    break

            if skip:
                continue

            files.append(name)

        priority = [
            "rooms.txt",
            "clients.txt",
            "apps_menu.txt",
            "veyon_import.csv",
            "veyon_clients.csv",
        ]

        final = []

        for item in priority:
            if item in files:
                final.append(item)

        for item in sorted(files):
            if item not in final:
                final.append(item)

        if not final:
            final = [
                "rooms.txt",
                "clients.txt",
                "apps_menu.txt",
                "veyon_import.csv",
                "veyon_clients.csv",
            ]

        return final

    def page_files_config(self):
        page, layout = self.page_base(
            "Files / Config",
            "View and edit QDA config files inside the app."
        )

        top = QWidget()
        top.setStyleSheet("""
            QWidget {
                background-color: white;
                border-radius: 16px;
            }
        """)

        top_layout = QHBoxLayout(top)
        top_layout.setContentsMargins(16, 14, 16, 14)
        top_layout.setSpacing(10)

        file_label = QLabel("File:")
        file_label.setStyleSheet("""
            color: #111827;
            font-size: 14px;
            font-weight: 700;
            background: transparent;
        """)

        self.config_combo = QComboBox()

        for filename in self.get_config_file_names():
            self.config_combo.addItem(filename)

        self.config_combo.currentTextChanged.connect(self.load_selected_config)

        load_btn = self.small_button("Load", self.load_selected_config)
        save_btn = self.small_button("Save", self.save_current_config)
        reload_btn = self.small_button("Reload", self.load_selected_config, gray=True)
        refresh_files_btn = self.small_button("Refresh Files", self.refresh_config_files, gray=True)
        open_folder_btn = self.small_button(
            "Open QDA Folder",
            lambda: self.open_path(QDA_BASE),
            gray=True
        )

        top_layout.addWidget(file_label)
        top_layout.addWidget(self.config_combo, stretch=1)
        top_layout.addWidget(load_btn)
        top_layout.addWidget(save_btn)
        top_layout.addWidget(reload_btn)
        top_layout.addWidget(refresh_files_btn)
        top_layout.addWidget(open_folder_btn)

        self.config_path_label = QLabel("No file loaded.")
        self.config_path_label.setStyleSheet("""
            color: #374151;
            font-size: 13px;
            font-weight: 600;
            padding-left: 4px;
        """)

        editor_panel = QWidget()
        editor_panel.setStyleSheet("""
            QWidget {
                background-color: white;
                border-radius: 18px;
            }
        """)

        editor_layout = QVBoxLayout(editor_panel)
        editor_layout.setContentsMargins(16, 16, 16, 16)
        editor_layout.setSpacing(10)

        editor_title = QLabel("Editor")
        editor_title.setStyleSheet("""
            color: #111827;
            font-size: 15px;
            font-weight: 800;
            background: transparent;
        """)

        self.config_editor = QTextEdit()
        self.config_editor.setPlaceholderText("Select a file and click Load...")
        self.config_editor.setAcceptRichText(False)
        self.config_editor.setLineWrapMode(QTextEdit.NoWrap)
        self.config_editor.setFont(QFont("Consolas", 13))
        self.config_editor.setStyleSheet("""
            QTextEdit {
                background-color: #ffffff;
                color: #111827;
                border: 1px solid #d1d5db;
                border-radius: 14px;
                padding: 12px;
                selection-background-color: #2563eb;
                selection-color: #ffffff;
            }
        """)

        editor_layout.addWidget(editor_title)
        editor_layout.addWidget(self.config_path_label)
        editor_layout.addWidget(self.config_editor, stretch=1)

        layout.addWidget(top)
        layout.addWidget(editor_panel, stretch=1)

        self.load_selected_config()

        return page

    def refresh_config_files(self):
        if not hasattr(self, "config_combo"):
            return

        current = self.config_combo.currentText()

        self.config_combo.blockSignals(True)
        self.config_combo.clear()

        for filename in self.get_config_file_names():
            self.config_combo.addItem(filename)

        index = self.config_combo.findText(current)

        if index >= 0:
            self.config_combo.setCurrentIndex(index)
        else:
            self.config_combo.setCurrentIndex(0)

        self.config_combo.blockSignals(False)

        self.load_selected_config()

    def open_config_file(self, filename):
        self.content.setCurrentIndex(4)

        if hasattr(self, "config_combo"):
            self.refresh_config_files()

            index = self.config_combo.findText(filename)

            if index >= 0:
                self.config_combo.setCurrentIndex(index)
                self.load_selected_config()

    def load_selected_config(self, *_):
        if not hasattr(self, "config_combo"):
            return

        filename = self.config_combo.currentText()
        path = QDA_BASE / filename

        self.current_config_file = path
        self.config_path_label.setText(str(path))

        if not path.exists():
            self.config_editor.setPlainText(f"[MISSING] {path}")
            return

        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
            self.config_editor.setPlainText(text)
        except Exception as e:
            self.config_editor.setPlainText(f"[ERROR] Cannot read {path}: {e}")

    def save_current_config(self):
        if not self.current_config_file:
            QMessageBox.warning(self, "Warning", "No config file loaded.")
            return

        try:
            self.current_config_file.write_text(
                self.config_editor.toPlainText(),
                encoding="utf-8"
            )
            QMessageBox.information(self, "Saved", f"Saved:\n{self.current_config_file}")

            if self.current_config_file.name.lower() in [
                "clients.txt",
                "rooms.txt",
                "veyon_import.csv",
                "veyon_clients.csv",
            ]:
                self.load_inventory()
                self.refresh_dashboard_data()

        except Exception as e:
            QMessageBox.critical(self, "Error", f"Cannot save file:\n{e}")

    # =========================
    # ROOMS / CLIENTS
    # =========================

    def page_rooms_clients(self):
        page, layout = self.page_base(
            "Rooms / Clients",
            "View rooms, clients, and QDA deployment status."
        )

        btn_row = QHBoxLayout()
        btn_row.setSpacing(10)

        refresh_btn = self.small_button("Refresh Inventory", self.load_inventory)
        scan_btn = self.small_button("Scan rooms", lambda: self.run_bat("run_scan_rooms.bat"))
        scan_veyon_btn = self.small_button("Scan Veyon", lambda: self.run_bat("scan_room_to_veyon.bat"))

        self.check_selected_btn = self.small_button("Check Selected", self.check_selected_client)
        self.check_all_btn = self.small_button("Check All", self.check_all_clients)
        self.refresh_status_btn = self.small_button("Refresh Status", self.refresh_selected_status, gray=True)

        edit_csv_btn = self.small_button(
            "Edit veyon_import.csv",
            lambda: self.open_config_file("veyon_import.csv"),
            gray=True
        )

        btn_row.addWidget(refresh_btn)
        btn_row.addWidget(scan_btn)
        btn_row.addWidget(scan_veyon_btn)
        btn_row.addWidget(self.check_selected_btn)
        btn_row.addWidget(self.check_all_btn)
        btn_row.addWidget(self.refresh_status_btn)
        btn_row.addWidget(edit_csv_btn)
        btn_row.addStretch()

        layout.addLayout(btn_row)

        body = QHBoxLayout()
        body.setSpacing(16)

        left_panel = QWidget()
        left_layout = QVBoxLayout(left_panel)
        left_layout.setContentsMargins(0, 0, 0, 0)
        left_layout.setSpacing(8)

        room_title = QLabel("Locations")
        room_title.setFont(QFont("Segoe UI", 14, QFont.Bold))

        self.rooms_list = QListWidget()
        self.rooms_list.currentItemChanged.connect(self.on_room_selected)

        left_layout.addWidget(room_title)
        left_layout.addWidget(self.rooms_list, stretch=1)

        right_panel = QWidget()
        right_layout = QVBoxLayout(right_panel)
        right_layout.setContentsMargins(0, 0, 0, 0)
        right_layout.setSpacing(10)

        self.room_info_label = QLabel("Select a location.")
        self.room_info_label.setFont(QFont("Segoe UI", 14, QFont.Bold))
        self.room_info_label.setStyleSheet("color: #111827;")

        self.clients_table = QTableWidget()
        self.clients_table.setColumnCount(4)
        self.clients_table.setHorizontalHeaderLabels(["Name", "Host address/IP", "MAC address", "Source"])
        self.clients_table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.clients_table.setSelectionBehavior(QTableWidget.SelectRows)
        self.clients_table.setEditTriggers(QTableWidget.NoEditTriggers)
        self.clients_table.itemSelectionChanged.connect(self.on_client_selected)

        self.client_detail_label = QLabel("Client Detail")
        self.client_detail_label.setFont(QFont("Segoe UI", 14, QFont.Bold))
        self.client_detail_label.setStyleSheet("color: #111827;")

        self.client_detail_box = QTextEdit()
        self.client_detail_box.setReadOnly(True)
        self.client_detail_box.setFont(QFont("Consolas", 11))
        self.client_detail_box.setMinimumHeight(170)
        self.client_detail_box.setStyleSheet("""
            QTextEdit {
                background-color: #111827;
                color: #e5e7eb;
                border: 1px solid #1f2937;
                border-radius: 14px;
                padding: 12px;
                selection-background-color: #2563eb;
                selection-color: white;
            }
        """)

        self.apps_checks_label = QLabel("QDA App Menu Checks")
        self.apps_checks_label.setFont(QFont("Segoe UI", 14, QFont.Bold))
        self.apps_checks_label.setStyleSheet("color: #111827;")

        self.apps_checks_table = QTableWidget()
        self.apps_checks_table.setColumnCount(5)
        self.apps_checks_table.setHorizontalHeaderLabels(["ID", "Name", "Type", "Status", "Note"])
        self.apps_checks_table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.apps_checks_table.setSelectionBehavior(QTableWidget.SelectRows)
        self.apps_checks_table.setEditTriggers(QTableWidget.NoEditTriggers)
        self.apps_checks_table.setMinimumHeight(220)

        right_layout.addWidget(self.room_info_label)
        right_layout.addWidget(self.clients_table, stretch=2)
        right_layout.addWidget(self.client_detail_label)
        right_layout.addWidget(self.client_detail_box)
        right_layout.addWidget(self.apps_checks_label)
        right_layout.addWidget(self.apps_checks_table, stretch=1)

        body.addWidget(left_panel, stretch=1)
        body.addWidget(right_panel, stretch=4)

        layout.addLayout(body, stretch=1)

        self.load_inventory()

        return page

    def get_inventory_signature(self):
        files = [
            QDA_BASE / "veyon_import.csv",
            QDA_BASE / "clients.txt",
            QDA_BASE / "rooms.txt",
        ]

        parts = []

        for path in files:
            if path.exists():
                try:
                    stat = path.stat()
                    parts.append(f"{path.name}:{stat.st_mtime}:{stat.st_size}")
                except Exception:
                    parts.append(f"{path.name}:error")
            else:
                parts.append(f"{path.name}:missing")

        return "|".join(parts)

    def auto_refresh_inventory_if_needed(self):
        if not hasattr(self, "content"):
            return

        if self.content.currentIndex() != 5:
            return

        new_signature = self.get_inventory_signature()

        if new_signature != self.inventory_signature:
            self.load_inventory(auto=True)

    def on_page_changed(self, index):
        if index == 5:
            self.load_inventory(auto=True)

    def load_inventory(self, auto=False):
        self.inventory_signature = self.get_inventory_signature()
        self.inventory_data = self.parse_inventory()

        if not hasattr(self, "rooms_list"):
            return

        current_room = ""

        current_item = self.rooms_list.currentItem()
        if current_item:
            current_text = current_item.text()
            if current_text != "No data":
                current_room = current_text.rsplit(" (", 1)[0]

        self.rooms_list.clear()
        self.clients_table.setRowCount(0)

        if hasattr(self, "client_detail_box"):
            self.client_detail_box.clear()

        if hasattr(self, "apps_checks_table"):
            self.apps_checks_table.setRowCount(0)

        rooms = sorted(self.inventory_data.keys())

        if not rooms:
            self.rooms_list.addItem("No data")
            self.room_info_label.setText("No inventory data. Scan rooms first.")
            return

        selected_index = 0

        for i, room in enumerate(rooms):
            count = len(self.inventory_data.get(room, []))
            self.rooms_list.addItem(f"{room} ({count})")

            if current_room and room == current_room:
                selected_index = i

        self.rooms_list.setCurrentRow(selected_index)

    def on_room_selected(self, current, previous):
        if current is None:
            return

        text = current.text()

        if text == "No data":
            self.clients_table.setRowCount(0)
            return

        room_name = text.rsplit(" (", 1)[0]
        clients = self.inventory_data.get(room_name, [])

        self.room_info_label.setText(f"{room_name} - {len(clients)} computers")
        self.clients_table.setRowCount(len(clients))

        for row, client in enumerate(clients):
            name = client.get("name", "")
            ip = client.get("ip", "")
            mac = client.get("mac", "")
            source = client.get("source", "")

            self.clients_table.setItem(row, 0, QTableWidgetItem(name))
            self.clients_table.setItem(row, 1, QTableWidgetItem(ip))
            self.clients_table.setItem(row, 2, QTableWidgetItem(mac))
            self.clients_table.setItem(row, 3, QTableWidgetItem(source))

        if len(clients) > 0:
            self.clients_table.selectRow(0)

    def on_client_selected(self):
        ip = self.get_selected_client_ip()

        if not ip:
            return

        self.selected_client_ip = ip

        if not self.check_process or self.check_process.state() == QProcess.ProcessState.NotRunning:
            self.load_client_status_to_ui(ip)

    def get_selected_client_ip(self):
        if not hasattr(self, "clients_table"):
            return ""

        selected = self.clients_table.selectedItems()

        if not selected:
            return ""

        row = selected[0].row()
        item = self.clients_table.item(row, 1)

        if item is None:
            return ""

        return item.text().strip()

    def status_json_path(self, ip):
        return QDA_BASE / "status" / f"{ip}.json"

    def load_client_status_json(self, ip):
        path = self.status_json_path(ip)

        if not path.exists():
            return {
                "__error__": "missing",
                "__path__": str(path),
                "__message__": f"Status JSON not found: {path}"
            }

        try:
            raw = path.read_text(encoding="utf-8-sig", errors="ignore")
            raw = raw.strip()

            if not raw:
                return {
                    "__error__": "empty",
                    "__path__": str(path),
                    "__message__": f"Status JSON is empty: {path}"
                }

            return json.loads(raw)

        except Exception as e:
            return {
                "__error__": "parse",
                "__path__": str(path),
                "__message__": f"Cannot parse JSON: {e}"
            }

    def yes_no(self, value):
        if value is True:
            return "OK"
        if value is False:
            return "MISSING"
        return "UNKNOWN"

    def load_client_status_to_ui(self, ip):
        data = self.load_client_status_json(ip)

        if data is None or data.get("__error__"):
            self.client_detail_label.setText(f"Client Detail - {ip}")
            self.client_detail_box.setPlainText(
                f"Khong doc duoc status JSON cho {ip}\n\n"
                f"Ly do: {data.get('__message__', 'Unknown error') if data else 'Unknown error'}\n\n"
                f"Duong dan app dang tim:\n"
                f"{data.get('__path__', str(self.status_json_path(ip))) if data else str(self.status_json_path(ip))}\n\n"
                f"Kiem tra file co ton tai dung ten khong:\n"
                f"{self.status_json_path(ip)}"
            )
            self.apps_checks_table.setRowCount(0)
            return

        self.client_detail_label.setText(f"Client Detail - {ip}")

        lines = []
        lines.append(f"IP              : {data.get('ip', ip)}")
        lines.append(f"Computer Name   : {data.get('computer_name', '')}")
        lines.append(f"User            : {data.get('user', '')}")
        lines.append(f"Last Check      : {data.get('last_check', '')}")
        lines.append("")
        lines.append("NETWORK")
        lines.append(f"Online          : {self.yes_no(data.get('online'))}")
        lines.append("")
        lines.append("SYSTEM")
        lines.append(f"OS              : {data.get('os_caption', '')}")
        lines.append(f"OS Version      : {data.get('os_version', '')}")
        lines.append(f"C Free / Size   : {data.get('c_drive_free_gb', '')} GB / {data.get('c_drive_size_gb', '')} GB")
        lines.append("")
        lines.append("CORE SOFTWARE")
        lines.append(f"Veyon           : {self.yes_no(data.get('veyon_installed'))}")
        lines.append(f"SEB             : {self.yes_no(data.get('seb_installed'))}")
        lines.append(f"Office 2016     : {self.yes_no(data.get('office2016_installed'))}")
        lines.append(f"HP_BCU          : {self.yes_no(data.get('hp_bcu_available'))}")
        lines.append(f"Dell CCTK       : {self.yes_no(data.get('dell_cctk_available'))}")
        lines.append("")
        lines.append("MICROSOFT 365")
        lines.append(f"M365 Installed  : {self.yes_no(data.get('microsoft365_installed'))}")
        lines.append(f"M365 Removed    : {self.yes_no(data.get('microsoft365_removed'))}")
        lines.append(f"M365 Evidence   : {data.get('microsoft365_evidence', '')}")
        lines.append("")
        lines.append("EXAM MODE")
        lines.append(f"Wi-Fi           : {data.get('wifi', '')}")
        lines.append(f"C Hidden        : {self.yes_no(data.get('c_drive_hidden'))}")
        lines.append(f"C Blocked       : {self.yes_no(data.get('c_drive_blocked'))}")
        lines.append("")
        lines.append("PATHS")
        lines.append(f"Veyon Path      : {data.get('veyon_path', '')}")
        lines.append(f"SEB Path        : {data.get('seb_path', '')}")
        lines.append(f"Office Path     : {data.get('office2016_path', '')}")
        lines.append(f"HP_BCU Path     : {data.get('hp_bcu_path', '')}")
        lines.append(f"Dell CCTK Path  : {data.get('dell_cctk_path', '')}")

        self.client_detail_box.setPlainText("\n".join(lines))

        checks = data.get("apps_menu_checks", [])
        self.apps_checks_table.setRowCount(len(checks))

        for row, check in enumerate(checks):
            installed = check.get("installed", None)

            if installed is True:
                status = "OK"
            elif installed is False:
                status = "MISSING"
            else:
                status = "UNKNOWN"

            self.apps_checks_table.setItem(row, 0, QTableWidgetItem(str(check.get("id", ""))))
            self.apps_checks_table.setItem(row, 1, QTableWidgetItem(str(check.get("name", ""))))
            self.apps_checks_table.setItem(row, 2, QTableWidgetItem(str(check.get("type", ""))))
            self.apps_checks_table.setItem(row, 3, QTableWidgetItem(status))
            self.apps_checks_table.setItem(row, 4, QTableWidgetItem(str(check.get("note", ""))))

    # =========================
    # CHECK PROCESS - LIVE IN APP
    # =========================

    def append_client_log(self, text):
        if not hasattr(self, "client_detail_box"):
            return

        text = str(text).rstrip()

        if not text:
            return

        current = self.client_detail_box.toPlainText()

        if current.strip():
            self.client_detail_box.append(text)
        else:
            self.client_detail_box.setPlainText(text)

        self.client_detail_box.ensureCursorVisible()

    def set_check_buttons_enabled(self, enabled):
        if hasattr(self, "check_selected_btn"):
            self.check_selected_btn.setEnabled(enabled)
        if hasattr(self, "check_all_btn"):
            self.check_all_btn.setEnabled(enabled)
        if hasattr(self, "refresh_status_btn"):
            self.refresh_status_btn.setEnabled(enabled)

    def start_check_animation(self, ip="", mode="single"):
        self.check_current_ip = ip
        self.check_mode = mode
        self.check_anim_step = 0
        self.check_anim_timer.start(500)

    def stop_check_animation(self):
        self.check_anim_timer.stop()
        self.check_anim_step = 0

    def animate_check_status(self):
        dots = "." * ((self.check_anim_step % 3) + 1)
        self.check_anim_step += 1

        if self.check_mode == "single" and self.check_current_ip:
            self.client_detail_label.setText(
                f"Client Detail - {self.check_current_ip} | dang kiem tra{dots}"
            )
        else:
            self.client_detail_label.setText(
                f"Client Detail | dang kiem tra{dots}"
            )

    def start_status_check_process(self, args, mode="single", ip=""):
        if self.check_process and self.check_process.state() != QProcess.ProcessState.NotRunning:
            QMessageBox.warning(self, "QDA", "Dang co mot tac vu kiem tra khac dang chay.")
            return

        self.check_process = QProcess(self)
        self.check_process.setProgram(args[0])
        self.check_process.setArguments(args[1:])
        self.check_process.setWorkingDirectory(str(QDA_BASE))

        self.check_process.readyReadStandardOutput.connect(self.on_check_process_stdout)
        self.check_process.readyReadStandardError.connect(self.on_check_process_stderr)
        self.check_process.finished.connect(self.on_check_process_finished)

        self.check_mode = mode
        self.check_current_ip = ip

        self.client_detail_box.clear()
        self.apps_checks_table.setRowCount(0)

        now = datetime.now().strftime("%H:%M:%S")

        if mode == "single":
            self.client_detail_label.setText(f"Client Detail - {ip} | dang kiem tra...")
            self.client_detail_box.setPlainText(
                f"[{now}] Dang kiem tra {ip} ...\n"
                f"----------------------------------------"
            )
        else:
            self.client_detail_label.setText("Client Detail | dang kiem tra tat ca...")
            self.client_detail_box.setPlainText(
                f"[{now}] Dang kiem tra tat ca client ...\n"
                f"----------------------------------------"
            )

        self.set_check_buttons_enabled(False)
        self.start_check_animation(ip=ip, mode=mode)
        self.check_process.start()

    def on_check_process_stdout(self):
        if not self.check_process:
            return

        data = bytes(self.check_process.readAllStandardOutput()).decode("utf-8", errors="ignore")
        lines = data.splitlines()

        for line in lines:
            line = line.strip()
            if line:
                self.append_client_log(line)

    def on_check_process_stderr(self):
        if not self.check_process:
            return

        data = bytes(self.check_process.readAllStandardError()).decode("utf-8", errors="ignore")
        lines = data.splitlines()

        for line in lines:
            line = line.strip()
            if line:
                self.append_client_log(f"[ERR] {line}")

    def on_check_process_finished(self, exitCode, exitStatus):
        now = datetime.now().strftime("%H:%M:%S")

        self.stop_check_animation()
        self.set_check_buttons_enabled(True)

        self.append_client_log("----------------------------------------")
        self.append_client_log(f"[{now}] Kiem tra hoan tat. ExitCode={exitCode}")

        if self.check_mode == "single" and self.check_current_ip:
            self.client_detail_label.setText(
                f"Client Detail - {self.check_current_ip} | da check xong"
            )

            self.append_client_log("")
            self.append_client_log(
                "Da tao/cap nhat file status JSON. Bam 'Refresh Status' de xem ket qua moi."
            )

        else:
            self.client_detail_label.setText("Client Detail | da check all xong")

            self.append_client_log("")
            self.append_client_log(
                "Da check all xong. Bam 'Refresh Status' tren tung may de xem ket qua moi."
            )

        self.check_process = None

    def check_selected_client(self):
        ip = self.get_selected_client_ip()

        if not ip:
            QMessageBox.warning(self, "Warning", "Please select a client first.")
            return

        ps1 = QDA_BASE / "check_client_status.ps1"

        if not ps1.exists():
            QMessageBox.critical(self, "Error", f"File not found:\n{ps1}")
            return

        self.start_status_check_process(
            [
                "powershell.exe",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(ps1),
                "-IP",
                ip,
                "-NoConfirm"
            ],
            mode="single",
            ip=ip
        )

    def check_all_clients(self):
        ps1 = QDA_BASE / "check_client_status.ps1"

        if not ps1.exists():
            QMessageBox.critical(self, "Error", f"File not found:\n{ps1}")
            return

        self.start_status_check_process(
            [
                "powershell.exe",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(ps1),
                "-All",
                "-NoConfirm"
            ],
            mode="all",
            ip=""
        )

    def refresh_selected_status(self):
        ip = self.get_selected_client_ip()

        if not ip:
            if hasattr(self, "selected_client_ip"):
                ip = self.selected_client_ip

        if not ip:
            QMessageBox.warning(self, "Warning", "Please select a client first.")
            return

        self.load_client_status_to_ui(ip)

    # =========================
    # INVENTORY PARSER
    # =========================

    def parse_inventory(self):
        inventory = {}

        csv_path = QDA_BASE / "veyon_import.csv"

        if csv_path.exists():
            csv_inventory = self.parse_veyon_csv(csv_path)
            if csv_inventory:
                return csv_inventory

        clients_path = QDA_BASE / "clients.txt"

        if clients_path.exists():
            clients = self.parse_clients_txt(clients_path)
            if clients:
                inventory["clients.txt"] = clients

        return inventory

    def parse_clients_txt(self, path):
        clients = []

        try:
            lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
        except Exception:
            return clients

        index = 1

        for line in lines:
            raw = line.strip()

            if not raw or raw.startswith("#"):
                continue

            parts = [p.strip() for p in raw.replace("|", ",").split(",")]

            if len(parts) == 1:
                name = f"CLIENT-{index:03d}"
                ip = parts[0]
                mac = ""
            elif len(parts) >= 2:
                name = parts[0]
                ip = parts[1]
                mac = parts[2] if len(parts) >= 3 else ""
            else:
                continue

            clients.append({
                "room": "clients.txt",
                "name": name,
                "ip": ip,
                "mac": mac,
                "source": "clients.txt",
                "status": "Scanned"
            })

            index += 1

        return clients

    def parse_veyon_csv(self, path):
        inventory = {}

        try:
            text = path.read_text(encoding="utf-8-sig", errors="ignore")
        except Exception:
            return inventory

        if not text.strip():
            return inventory

        lines = [line for line in text.splitlines() if line.strip()]
        if not lines:
            return inventory

        try:
            sample = "\n".join(lines[:10])
            dialect = csv.Sniffer().sniff(sample, delimiters=",;|\t")
        except Exception:
            dialect = csv.excel

        rows = []

        try:
            reader = csv.DictReader(lines, dialect=dialect)
            if reader.fieldnames:
                for row in reader:
                    rows.append(row)
        except Exception:
            rows = []

        if rows:
            fieldnames = list(rows[0].keys())

            def find_field(candidates):
                for field in fieldnames:
                    f = str(field).lower().strip()
                    for c in candidates:
                        if c in f:
                            return field
                return None

            room_field = find_field(["location", "locations", "room", "phong", "parent"])
            name_field = find_field(["name", "computer", "computers", "client", "display", "may"])
            ip_field = find_field(["host address/ip", "hostaddress", "host address", "ip", "address"])
            mac_field = find_field(["mac address", "macaddress", "mac"])

            index = 1

            for row in rows:
                room = self.clean_csv_value(row.get(room_field, "")) if room_field else ""
                name = self.clean_csv_value(row.get(name_field, "")) if name_field else ""
                ip = self.clean_csv_value(row.get(ip_field, "")) if ip_field else ""
                mac = self.clean_csv_value(row.get(mac_field, "")) if mac_field else ""

                if not room:
                    room = "Default"

                if not ip:
                    continue

                if not name:
                    name = f"{room}-MAY{index:03d}"

                if room not in inventory:
                    inventory[room] = []

                inventory[room].append({
                    "room": room,
                    "name": name,
                    "ip": ip,
                    "mac": mac,
                    "source": "veyon_import.csv",
                    "status": "Scanned"
                })

                index += 1

            if inventory:
                return inventory

        try:
            reader = csv.reader(lines, dialect=dialect)
            raw_rows = list(reader)
        except Exception:
            return inventory

        if not raw_rows:
            return inventory

        start_index = 0
        first_line = ",".join(raw_rows[0]).lower()

        if "location" in first_line or "name" in first_line or "host" in first_line or "mac" in first_line:
            start_index = 1

        index = 1

        for row in raw_rows[start_index:]:
            if len(row) < 2:
                continue

            room = self.clean_csv_value(row[0]) if len(row) >= 1 else "Default"
            name = self.clean_csv_value(row[1]) if len(row) >= 2 else ""
            ip = self.clean_csv_value(row[2]) if len(row) >= 3 else ""
            mac = self.clean_csv_value(row[3]) if len(row) >= 4 else ""

            if not room:
                room = "Default"

            if not ip:
                continue

            if not name:
                name = f"{room}-MAY{index:03d}"

            if room not in inventory:
                inventory[room] = []

            inventory[room].append({
                "room": room,
                "name": name,
                "ip": ip,
                "mac": mac,
                "source": "veyon_import.csv",
                "status": "Scanned"
            })

            index += 1

        return inventory

    def clean_csv_value(self, value):
        if value is None:
            return ""

        value = str(value).strip()
        value = value.strip('"').strip("'").strip()
        return value

    # =========================
    # LOGS
    # =========================

    def page_logs(self):
        page, layout = self.page_base(
            "Logs",
            "View QDA result files."
        )

        btn_row = QHBoxLayout()
        btn_row.setSpacing(10)

        refresh_btn = self.small_button("Refresh Logs", self.load_logs)
        open_qda_btn = self.small_button(
            "Open QDA folder",
            lambda: self.open_path(QDA_BASE),
            gray=True
        )

        btn_row.addWidget(refresh_btn)
        btn_row.addWidget(open_qda_btn)
        btn_row.addStretch()

        self.log_box = QTextEdit()
        self.log_box.setReadOnly(True)
        self.log_box.setFont(QFont("Consolas", 11))
        self.log_box.setStyleSheet("""
            QTextEdit {
                background-color: #111827;
                color: #e5e7eb;
                border: 1px solid #1f2937;
                border-radius: 14px;
                padding: 12px;
                selection-background-color: #2563eb;
                selection-color: white;
            }
        """)

        layout.addLayout(btn_row)
        layout.addWidget(self.log_box, stretch=1)

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
                [
                    "cmd.exe",
                    "/c",
                    "start",
                    "",
                    str(path)
                ],
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

    def update_clock(self):
        try:
            if hasattr(self, "time_card"):
                self.time_card.value_label.setText(
                    datetime.now().strftime("%d/%m/%Y %H:%M:%S")
                )
                self.time_card.title_label.setText("Cập nhật hệ thống")
                self.time_card.desc_label.setText("Thời gian update hiện tại")
        except Exception:
            pass

    def refresh_dashboard_data(self):
        try:
            if hasattr(self, "clients_count_card"):
                self.clients_count_card.value_label.setText(str(self.count_clients()))
                self.clients_count_card.desc_label.setText(f"Dựa trên {QDA_BASE / 'clients.txt'}")

            if hasattr(self, "qda_base_card"):
                self.qda_base_card.value_label.setText(str(QDA_BASE))
                self.qda_base_card.desc_label.setText("Thư mục nguồn đang dùng")
        except Exception:
            pass

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
            "exam_mode_success.txt",
            "exam_mode_failed.txt",
            "hp_poweron_tasks_success.txt",
            "hp_poweron_tasks_failed.txt",
            "dell_poweron_tasks_success.txt",
            "dell_poweron_tasks_failed.txt",
            "check_status_success.txt",
            "check_status_failed.txt",
            "install_success.txt",
            "install_failed.txt",
            "scan_rooms_success.txt",
            "scan_rooms_failed.txt",
            "scan_rooms_log.txt",
            "veyon_import_success.txt",
            "veyon_import_failed.txt",
            "veyon_import_log.txt",
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

    if APP_ICON.exists():
        app.setWindowIcon(QIcon(str(APP_ICON)))

    window = QDAApp()
    window.show()
    sys.exit(app.exec())    