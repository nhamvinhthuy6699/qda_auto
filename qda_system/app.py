from flask import Flask, redirect, url_for, render_template_string, flash
from pathlib import Path
import subprocess
import datetime
import sys
import webbrowser
import threading
import time


app = Flask(__name__)
app.secret_key = "qda-control-system-local"


# =========================
# CONFIG - PORTABLE
# =========================

def get_app_root():
    """
    Portable path resolver.

    Case 1: Run by Python:
        python app.py

        It will search current folder and parent folders
        until it finds qda_auto.

    Case 2: Build to QDA_Web.exe:
        It will use the folder containing QDA_Web.exe.

    Example:
        D:\\datn\\QDA_Web.exe
        D:\\datn\\qda_auto

        => QDA_BASE = D:\\datn\\qda_auto
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


# =========================
# ACTIONS
# =========================

MAIN_ACTIONS = {
    "shutdown_menu": {
        "title": "Menu Shutdown / Restart / Ẩn ổ C",
        "file": "run_shutdown_tasks.bat",
        "desc": "Shutdown, restart, bật/tắt ẩn ổ C, kill SEB/QDA."
    },
    "hp_poweron": {
        "title": "HP Power-On",
        "file": "run_hp_poweron_tasks.bat",
        "desc": "Cấu hình BIOS HP tự bật máy và startup QDA/SEB."
    },
    "dell_poweron": {
        "title": "Dell Power-On",
        "file": "run_dell_poweron_tasks.bat",
        "desc": "Cấu hình BIOS Dell tự bật máy."
    },
    "scan_clients": {
        "title": "Scan phòng ra clients.txt",
        "file": "run_scan_rooms.bat",
        "desc": "Quét IP phòng theo rooms.txt và tạo/cập nhật clients.txt."
    },
    "install_menu": {
        "title": "Mở menu cài đặt QDA",
        "file": "install.bat",
        "desc": "Cài Veyon, Office, SEB, copy file, chạy task theo apps_menu.txt."
    }
}

VEYON_ACTIONS = {
    "scan_veyon": {
        "title": "Scan phòng ra Veyon",
        "file": "scan_room_to_veyon.bat",
        "desc": "Quét IP/MAC theo rooms.txt và tạo file import Veyon."
    },
    "import_veyon": {
        "title": "Import Veyon CSV",
        "file": "import_veyon_csv.bat",
        "desc": "Import danh sách máy vào Veyon Configurator."
    }
}

ALL_ACTIONS = {}
ALL_ACTIONS.update(MAIN_ACTIONS)
ALL_ACTIONS.update(VEYON_ACTIONS)


# =========================
# HELPER FUNCTIONS
# =========================

def run_bat(file_name: str):
    path = QDA_BASE / file_name

    if not path.exists():
        return False, f"Không tìm thấy file: {path}"

    try:
        subprocess.Popen(
            ["cmd.exe", "/c", "start", "", str(path)],
            cwd=str(QDA_BASE),
            shell=False
        )
        return True, f"Đã chạy: {file_name}"
    except Exception as e:
        return False, f"Lỗi chạy {file_name}: {e}"


def launch_exe(path: Path, run_as_admin=False):
    if not path.exists():
        return False, f"Không tìm thấy: {path}"

    try:
        if run_as_admin:
            subprocess.Popen(
                [
                    "powershell.exe",
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-Command",
                    f"Start-Process -FilePath '{str(path)}' -Verb RunAs"
                ],
                shell=False
            )
        else:
            subprocess.Popen(
                [str(path)],
                cwd=str(path.parent),
                shell=False
            )

        return True, f"Đã mở: {path}"
    except Exception as e:
        return False, f"Lỗi mở {path}: {e}"


def open_path(path: Path):
    if not path.exists():
        return False, f"Không tìm thấy: {path}"

    try:
        if path.is_file():
            suffix = path.suffix.lower()

            if suffix == ".exe":
                return launch_exe(path)

            if suffix in [".txt", ".log", ".csv", ".bat", ".ps1"]:
                subprocess.Popen(["notepad.exe", str(path)], shell=False)
                return True, f"Đã mở: {path}"

        subprocess.Popen(
            ["explorer.exe", str(path)],
            shell=False
        )
        return True, f"Đã mở: {path}"

    except Exception as e:
        return False, f"Lỗi mở {path}: {e}"


def read_file(path: Path, max_chars=20000):
    if not path.exists():
        return f"Không tìm thấy file: {path}"

    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
        if len(text) > max_chars:
            return text[-max_chars:]
        return text
    except Exception as e:
        return f"Lỗi đọc file: {e}"


def count_clients():
    clients = QDA_BASE / "clients.txt"
    if not clients.exists():
        return 0

    lines = clients.read_text(encoding="utf-8", errors="ignore").splitlines()
    return len([x for x in lines if x.strip() and not x.strip().startswith("#")])


def get_recent_logs():
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

    result = []

    for name in files:
        p = QDA_BASE / name
        result.append({
            "name": name,
            "exists": p.exists(),
            "content": read_file(p, 6000) if p.exists() else "Chưa có file log."
        })

    return result


# =========================
# HTML
# =========================

HTML = """
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <title>QDA Control System</title>

    <style>
        * {
            box-sizing: border-box;
        }

        body {
            margin: 0;
            font-family: "Segoe UI", Arial, sans-serif;
            background: #f3f4f6;
            color: #111827;
        }

        .layout {
            display: flex;
            min-height: 100vh;
        }

        .sidebar {
            width: 260px;
            background: #111827;
            color: white;
            padding: 24px;
            position: fixed;
            left: 0;
            top: 0;
            bottom: 0;
        }

        .brand {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 32px;
        }

        .logo {
            width: 48px;
            height: 48px;
            background: #2563eb;
            border-radius: 14px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 26px;
            font-weight: 800;
        }

        .brand-title {
            font-size: 21px;
            font-weight: 800;
        }

        .brand-sub {
            color: #9ca3af;
            font-size: 13px;
        }

        .nav a {
            display: block;
            padding: 13px 14px;
            margin-bottom: 8px;
            color: #d1d5db;
            text-decoration: none;
            border-radius: 12px;
        }

        .nav a:hover {
            background: #1f2937;
            color: white;
        }

        .main {
            flex: 1;
            padding: 28px;
            margin-left: 260px;
        }

        .top {
            background: white;
            border-radius: 20px;
            padding: 24px;
            margin-bottom: 22px;
            box-shadow: 0 8px 22px rgba(0,0,0,0.06);
        }

        .top h1 {
            margin: 0;
            font-size: 30px;
        }

        .top p {
            margin: 8px 0 0 0;
            color: #6b7280;
        }

        .cards {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 18px;
            margin-bottom: 22px;
        }

        .card {
            background: white;
            border-radius: 18px;
            padding: 22px;
            box-shadow: 0 8px 22px rgba(0,0,0,0.06);
        }

        .card-title {
            color: #6b7280;
            font-weight: 700;
        }

        .card-num {
            font-size: 34px;
            font-weight: 800;
            margin-top: 8px;
        }

        .panel {
            background: white;
            border-radius: 18px;
            padding: 24px;
            margin-bottom: 22px;
            box-shadow: 0 8px 22px rgba(0,0,0,0.06);
        }

        .panel h2 {
            margin-top: 0;
        }

        .grid {
            display: grid;
            grid-template-columns: repeat(2, minmax(280px, 1fr));
            gap: 14px;
        }

        .action {
            border: 1px solid #e5e7eb;
            border-radius: 16px;
            padding: 16px;
            background: #f9fafb;
        }

        .action h3 {
            margin: 0 0 8px 0;
            font-size: 18px;
        }

        .action p {
            margin: 0 0 14px 0;
            color: #6b7280;
            font-size: 14px;
        }

        button, .btn {
            border: 0;
            padding: 12px 16px;
            border-radius: 12px;
            font-weight: 800;
            cursor: pointer;
            background: #e5e7eb;
            color: #111827;
            text-decoration: none;
            display: inline-block;
            font-size: 14px;
        }

        button.primary, .btn.primary {
            background: #2563eb;
            color: white;
        }

        button.danger, .btn.danger {
            background: #dc2626;
            color: white;
        }

        button:hover, .btn:hover {
            opacity: 0.9;
        }

        .messages {
            margin-bottom: 18px;
        }

        .msg {
            padding: 13px 16px;
            border-radius: 12px;
            margin-bottom: 8px;
            font-weight: 700;
        }

        .msg.success {
            background: #dcfce7;
            color: #166534;
        }

        .msg.error {
            background: #fee2e2;
            color: #991b1b;
        }

        pre {
            background: #111827;
            color: #d1d5db;
            padding: 16px;
            border-radius: 14px;
            max-height: 360px;
            overflow: auto;
            white-space: pre-wrap;
        }

        .small {
            color: #6b7280;
            font-size: 13px;
        }

        .footer {
            color: #6b7280;
            margin-top: 20px;
            font-size: 13px;
        }
    </style>
</head>

<body>
<div class="layout">
    <aside class="sidebar">
        <div class="brand">
            <div class="logo">Q</div>
            <div>
                <div class="brand-title">QDA</div>
                <div class="brand-sub">Control System</div>
            </div>
        </div>

        <div class="nav">
            <a href="/">Dashboard</a>
            <a href="/logs">Logs</a>
            <a href="/open/qda_folder">Mở thư mục QDA</a>
            <a href="/open/installers">Mở INSTALLERS</a>
            <a href="/open/rooms">Mở rooms.txt</a>
            <a href="/open/clients">Mở clients.txt</a>
            <a href="/open/apps_menu">Mở apps_menu.txt</a>
            <a href="/open/veyon_master">Mở Veyon Master</a>
            <a href="/open/veyon_config">Mở Veyon Configurator</a>
        </div>
    </aside>

    <main class="main">
        <div class="top">
            <h1>QDA Control System</h1>
            <p>Giao diện điều khiển phòng máy: shutdown, power-on, scan, cài đặt, Veyon và log.</p>
        </div>

        {% with messages = get_flashed_messages(with_categories=true) %}
            {% if messages %}
                <div class="messages">
                {% for category, message in messages %}
                    <div class="msg {{ category }}">{{ message }}</div>
                {% endfor %}
                </div>
            {% endif %}
        {% endwith %}

        {% if page == "dashboard" %}
            <div class="cards">
                <div class="card">
                    <div class="card-title">Số máy trong clients.txt</div>
                    <div class="card-num">{{ clients_count }}</div>
                    <div class="small">Dựa trên {{ clients_path }}</div>
                </div>

                <div class="card">
                    <div class="card-title">QDA Base</div>
                    <div style="margin-top: 12px; font-weight: 700; word-break: break-all;">{{ qda_base }}</div>
                </div>

                <div class="card">
                    <div class="card-title">Thời gian</div>
                    <div style="margin-top: 12px; font-weight: 700;">{{ now }}</div>
                </div>
            </div>

            <div class="panel">
                <h2>Thao tác chính</h2>

                <div class="grid">
                    {% for key, item in main_actions.items() %}
                    <div class="action">
                        <h3>{{ item.title }}</h3>
                        <p>{{ item.desc }}</p>
                        <form method="post" action="/run/{{ key }}">
                            <button class="primary" type="submit">Chạy</button>
                        </form>
                    </div>
                    {% endfor %}

                    <div class="action">
                        <h3>Mở rooms.txt</h3>
                        <p>File khai báo dải mạng/phòng để scan.</p>
                        <a class="btn" href="/open/rooms">Mở rooms.txt</a>
                    </div>

                    <div class="action">
                        <h3>Mở clients.txt</h3>
                        <p>Danh sách máy client hiện tại.</p>
                        <a class="btn" href="/open/clients">Mở clients.txt</a>
                    </div>
                </div>
            </div>

            <div class="panel">
                <h2>Veyon</h2>

                <div class="grid">
                    {% for key, item in veyon_actions.items() %}
                    <div class="action">
                        <h3>{{ item.title }}</h3>
                        <p>{{ item.desc }}</p>
                        <form method="post" action="/run/{{ key }}">
                            <button class="primary" type="submit">Chạy</button>
                        </form>
                    </div>
                    {% endfor %}

                    <div class="action">
                        <h3>Mở Veyon Master</h3>
                        <p>Quan sát, điều khiển, log off, restart, collect file.</p>
                        <a class="btn primary" href="/open/veyon_master">Mở Veyon Master</a>
                    </div>

                    <div class="action">
                        <h3>Mở Veyon Configurator</h3>
                        <p>Chỉnh Locations, Computers, Applications, Keys.</p>
                        <a class="btn" href="/open/veyon_config">Mở Configurator</a>
                    </div>
                </div>
            </div>
        {% endif %}

        {% if page == "logs" %}
            <div class="panel">
                <h2>Logs</h2>
                <p class="small">Hiển thị nhanh các file log chính trong thư mục QDA.</p>
            </div>

            {% for log in logs %}
            <div class="panel">
                <h2>{{ log.name }}</h2>
                <pre>{{ log.content }}</pre>
            </div>
            {% endfor %}
        {% endif %}

        <div class="footer">
            QDA Control System v1 - chạy nội bộ trên máy giáo viên/server.
        </div>
    </main>
</div>
</body>
</html>
"""


# =========================
# ROUTES
# =========================

@app.route("/")
def dashboard():
    return render_template_string(
        HTML,
        page="dashboard",
        main_actions=MAIN_ACTIONS,
        veyon_actions=VEYON_ACTIONS,
        clients_count=count_clients(),
        qda_base=str(QDA_BASE),
        clients_path=str(QDA_BASE / "clients.txt"),
        now=datetime.datetime.now().strftime("%d/%m/%Y %H:%M:%S")
    )


@app.route("/logs")
def logs():
    return render_template_string(
        HTML,
        page="logs",
        logs=get_recent_logs(),
        main_actions=MAIN_ACTIONS,
        veyon_actions=VEYON_ACTIONS,
        clients_count=count_clients(),
        qda_base=str(QDA_BASE),
        clients_path=str(QDA_BASE / "clients.txt"),
        now=datetime.datetime.now().strftime("%d/%m/%Y %H:%M:%S")
    )


@app.route("/run/<action>", methods=["POST"])
def run_action(action):
    if action not in ALL_ACTIONS:
        flash("Lệnh không hợp lệ.", "error")
        return redirect(url_for("dashboard"))

    ok, msg = run_bat(ALL_ACTIONS[action]["file"])
    flash(msg, "success" if ok else "error")
    return redirect(url_for("dashboard"))


@app.route("/open/<target>")
def open_target(target):
    if target == "veyon_master":
        ok, msg = run_bat("open_veyon_master.bat")
        flash(msg, "success" if ok else "error")
        return redirect(url_for("dashboard"))

    if target == "veyon_config":
        ok, msg = launch_exe(VEYON_CONFIG, run_as_admin=True)
        flash(msg, "success" if ok else "error")
        return redirect(url_for("dashboard"))

    targets = {
        "qda_folder": QDA_BASE,
        "installers": QDA_BASE / "INSTALLERS",
        "clients": QDA_BASE / "clients.txt",
        "rooms": QDA_BASE / "rooms.txt",
        "apps_menu": QDA_BASE / "apps_menu.txt",
        "success_log": QDA_BASE / "install_success.txt",
        "failed_log": QDA_BASE / "install_failed.txt",
    }

    if target not in targets:
        flash("Mục không hợp lệ.", "error")
        return redirect(url_for("dashboard"))

    ok, msg = open_path(targets[target])
    flash(msg, "success" if ok else "error")
    return redirect(url_for("dashboard"))


if __name__ == "__main__":
    def open_browser():
        time.sleep(1.5)
        webbrowser.open("http://127.0.0.1:8088")

    threading.Thread(target=open_browser, daemon=True).start()
    app.run(host="0.0.0.0", port=8088, debug=False)