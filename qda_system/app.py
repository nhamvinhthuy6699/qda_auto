import os
import csv
import subprocess
from pathlib import Path
from datetime import datetime

from flask import Flask, render_template_string, redirect, url_for, flash, jsonify


# =========================
# CONFIG
# =========================

APP = Flask(__name__)
APP.secret_key = "qda-control-system"

QDA_BASE = Path(r"C:\mywork\qda_auto")

VEYON_MASTER = Path(r"C:\Program Files\Veyon\veyon-master.exe")
VEYON_CONFIG = Path(r"C:\Program Files\Veyon\veyon-configurator.exe")


# =========================
# ACTIONS
# =========================

MAIN_ACTIONS = {
    "shutdown_menu": {
        "title": "Menu Shutdown",
        "file": "run_shutdown_tasks.bat",
        "desc": "Shutdown, kill SEB/QDA."
    },
    "exam_mode": {
        "title": "Exam Mode",
        "file": "run_exam_mode.bat",
        "desc": "Bật/tắt chế độ thi."
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
        "title": "Scan rooms to Veyon",
        "file": "scan_room_to_veyon.bat",
        "desc": "Quét IP/MAC theo rooms.txt và tạo file import Veyon."
    },
    "import_veyon": {
        "title": "Import Veyon CSV",
        "file": "import_veyon_csv.bat",
        "desc": "Import danh sách máy vào Veyon Configurator."
    }
}


TASK_ACTIONS = {
    "install_menu": {
        "title": "Open QDA install menu",
        "file": "install.bat",
        "desc": "Chạy menu cài đặt theo apps_menu.txt."
    }
}


POWER_ACTIONS = {
    "shutdown": {
        "title": "Shutdown",
        "file": "run_shutdown_tasks.bat",
        "desc": "Menu shutdown/cleanup phòng máy."
    },
    "exam_mode": {
        "title": "Exam Mode",
        "file": "run_exam_mode.bat",
        "desc": "Bật/tắt chế độ thi."
    },
    "hp_poweron": {
        "title": "HP Power-On",
        "file": "run_hp_poweron_tasks.bat",
        "desc": "Set BIOS HP tự bật máy."
    },
    "dell_poweron": {
        "title": "Dell Power-On",
        "file": "run_dell_poweron_tasks.bat",
        "desc": "Set BIOS Dell tự bật máy."
    }
}


# =========================
# HELPERS
# =========================

def count_clients():
    clients_file = QDA_BASE / "clients.txt"

    if not clients_file.exists():
        return 0

    try:
        lines = clients_file.read_text(encoding="utf-8", errors="ignore").splitlines()
        return len([
            line for line in lines
            if line.strip() and not line.strip().startswith("#")
        ])
    except Exception:
        return 0


def read_file(path, max_chars=8000):
    path = Path(path)

    if not path.exists():
        return f"[MISSING] {path}"

    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
        if len(text) > max_chars:
            return text[-max_chars:]
        return text
    except Exception as e:
        return f"[ERROR] {path}: {e}"


def run_bat_file(filename):
    path = QDA_BASE / filename

    if not path.exists():
        flash(f"Không tìm thấy file: {path}", "error")
        return

    try:
        subprocess.Popen(
            ["cmd.exe", "/c", "start", "", str(path)],
            cwd=str(QDA_BASE),
            shell=False
        )
        flash(f"Đã mở: {path}", "success")
    except Exception as e:
        flash(f"Lỗi chạy file: {e}", "error")


def open_file_or_folder(path):
    path = Path(path)

    if not path.exists():
        flash(f"Không tìm thấy: {path}", "error")
        return

    try:
        subprocess.Popen(
            ["cmd.exe", "/c", "start", "", str(path)],
            cwd=str(path.parent if path.is_file() else path),
            shell=False
        )
        flash(f"Đã mở: {path}", "success")
    except Exception as e:
        flash(f"Lỗi mở file/thư mục: {e}", "error")


def load_logs():
    files = [
        "shutdown_tasks_success.txt",
        "shutdown_tasks_failed.txt",
        "exam_mode_success.txt",
        "exam_mode_failed.txt",
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

    for filename in files:
        path = QDA_BASE / filename
        output.append(f"===== {filename} =====")
        output.append(read_file(path))
        output.append("")

    return "\n".join(output)


# =========================
# TEMPLATE
# =========================

BASE_TEMPLATE = r"""
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
            background: #f3f4f6;
            color: #111827;
            font-family: "Segoe UI", Arial, sans-serif;
        }

        .layout {
            display: flex;
            min-height: 100vh;
        }

        .sidebar {
            width: 240px;
            background: #111827;
            color: white;
            padding: 28px 22px;
            position: fixed;
            top: 0;
            bottom: 0;
            left: 0;
        }

        .logo {
            width: 48px;
            height: 48px;
            border-radius: 12px;
            background: #2563eb;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: 900;
            font-size: 26px;
            margin-bottom: 14px;
        }

        .brand {
            font-size: 20px;
            font-weight: 800;
            line-height: 1.25;
            margin-bottom: 32px;
        }

        .nav a {
            display: block;
            color: #d1d5db;
            text-decoration: none;
            padding: 12px 12px;
            border-radius: 10px;
            margin-bottom: 8px;
            font-size: 15px;
            font-weight: 600;
        }

        .nav a:hover {
            background: #1f2937;
            color: white;
        }

        .sidebar-footer {
            position: absolute;
            bottom: 24px;
            left: 22px;
            right: 22px;
            color: #9ca3af;
            font-size: 12px;
            word-break: break-all;
        }

        .content {
            margin-left: 240px;
            padding: 26px 28px;
            width: calc(100% - 240px);
        }

        .hero {
            background: white;
            border-radius: 22px;
            padding: 28px 30px;
            box-shadow: 0 12px 35px rgba(0,0,0,0.04);
            margin-bottom: 28px;
        }

        .hero h1 {
            margin: 0;
            font-size: 34px;
            font-weight: 850;
        }

        .hero p {
            margin: 10px 0 0;
            color: #6b7280;
            font-size: 17px;
        }

        .cards {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 22px;
            margin-bottom: 28px;
        }

        .card {
            background: white;
            border-radius: 20px;
            padding: 24px 26px;
            min-height: 128px;
            box-shadow: 0 12px 35px rgba(0,0,0,0.04);
        }

        .card-title {
            color: #6b7280;
            font-size: 16px;
            font-weight: 750;
            margin-bottom: 14px;
        }

        .card-num {
            font-size: 34px;
            font-weight: 850;
            line-height: 1;
        }

        .card-value {
            font-size: 26px;
            font-weight: 850;
            line-height: 1.2;
            word-break: break-all;
        }

        .small {
            margin-top: 10px;
            color: #6b7280;
            font-size: 14px;
        }

        .panel {
            background: white;
            border-radius: 22px;
            padding: 28px 30px;
            box-shadow: 0 12px 35px rgba(0,0,0,0.04);
        }

        .panel h2 {
            margin: 0 0 24px;
            font-size: 28px;
            font-weight: 850;
        }

        .actions-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 18px;
        }

        .action-card {
            background: #f9fafb;
            border: 1px solid #e5e7eb;
            border-radius: 18px;
            padding: 22px;
            min-height: 155px;
        }

        .action-card h3 {
            margin: 0 0 10px;
            font-size: 21px;
            font-weight: 850;
        }

        .action-card p {
            margin: 0 0 18px;
            color: #6b7280;
            font-size: 15px;
            line-height: 1.45;
        }

        .btn {
            display: inline-block;
            border: none;
            background: #2563eb;
            color: white;
            padding: 12px 22px;
            border-radius: 12px;
            font-size: 15px;
            font-weight: 800;
            text-decoration: none;
            cursor: pointer;
        }

        .btn:hover {
            background: #1d4ed8;
        }

        .btn-gray {
            background: #e5e7eb;
            color: #111827;
        }

        .btn-gray:hover {
            background: #d1d5db;
        }

        .alert {
            border-radius: 12px;
            padding: 12px 16px;
            margin-bottom: 18px;
            font-weight: 700;
        }

        .alert.success {
            background: #dcfce7;
            color: #166534;
        }

        .alert.error {
            background: #fee2e2;
            color: #991b1b;
        }

        pre {
            background: #111827;
            color: #d1d5db;
            border-radius: 16px;
            padding: 18px;
            overflow: auto;
            font-family: Consolas, monospace;
            font-size: 13px;
            line-height: 1.45;
            min-height: 420px;
        }

        .top-actions {
            display: flex;
            gap: 12px;
            margin-bottom: 18px;
            flex-wrap: wrap;
        }
    </style>
</head>

<body>
<div class="layout">
    <aside class="sidebar">
        <div class="logo">Q</div>
        <div class="brand">QDA<br>Control System</div>

        <nav class="nav">
            <a href="{{ url_for('dashboard') }}">Dashboard</a>
            <a href="{{ url_for('veyon') }}">Veyon</a>
            <a href="{{ url_for('tasks') }}">QDA Tasks</a>
            <a href="{{ url_for('power') }}">Power / BIOS</a>
            <a href="{{ url_for('logs') }}">Logs</a>
        </nav>

        <div class="sidebar-footer">
            Base:<br>{{ qda_base }}
        </div>
    </aside>

    <main class="content">
        {% with messages = get_flashed_messages(with_categories=true) %}
            {% if messages %}
                {% for category, message in messages %}
                    <div class="alert {{ category }}">{{ message }}</div>
                {% endfor %}
            {% endif %}
        {% endwith %}

        {% block content %}{% endblock %}
    </main>
</div>

<script>
    function pad2(n) {
        return String(n).padStart(2, "0");
    }

    function formatClock(date) {
        const day = pad2(date.getDate());
        const month = pad2(date.getMonth() + 1);
        const year = date.getFullYear();

        const hour = pad2(date.getHours());
        const minute = pad2(date.getMinutes());
        const second = pad2(date.getSeconds());

        return `${day}/${month}/${year} ${hour}:${minute}:${second}`;
    }

    function updateClock() {
        const systemTime = document.getElementById("system-time");

        if (systemTime) {
            systemTime.textContent = formatClock(new Date());
        }
    }

    async function refreshDashboardData() {
        try {
            const res = await fetch("/api/status", {
                cache: "no-store"
            });

            if (!res.ok) {
                return;
            }

            const data = await res.json();

            const clientsCount = document.getElementById("clients-count");
            const clientsDesc = document.getElementById("clients-desc");
            const qdaBase = document.getElementById("qda-base");

            if (clientsCount) {
                clientsCount.textContent = data.clients_count;
            }

            if (clientsDesc) {
                clientsDesc.textContent = "Dựa trên " + data.qda_base + "\\clients.txt";
            }

            if (qdaBase) {
                qdaBase.textContent = data.qda_base;
            }
        } catch (e) {
            console.log("Dashboard refresh error:", e);
        }
    }

    updateClock();
    refreshDashboardData();

    setInterval(updateClock, 1000);
    setInterval(refreshDashboardData, 3000);
</script>

</body>
</html>
"""


DASHBOARD_TEMPLATE = r"""
{% extends "base" %}

{% block content %}
<div class="hero">
    <h1>QDA Control System</h1>
    <p>Giao diện điều khiển phòng máy: shutdown, power-on, scan, cài đặt, Veyon và log.</p>
</div>

<div class="cards">
    <div class="card">
        <div class="card-title">Số máy trong clients.txt</div>
        <div class="card-num" id="clients-count">{{ clients_count }}</div>
        <div class="small" id="clients-desc">Dựa trên {{ qda_base }}\clients.txt</div>
    </div>

    <div class="card">
        <div class="card-title">QDA Base</div>
        <div class="card-value" id="qda-base">{{ qda_base }}</div>
        <div class="small">Thư mục nguồn đang dùng</div>
    </div>

    <div class="card">
        <div class="card-title">Cập nhật hệ thống</div>
        <div class="card-value" id="system-time">{{ now }}</div>
        <div class="small">Thời gian update hiện tại</div>
    </div>
</div>

<div class="panel">
    <h2>Thao tác chính</h2>

    <div class="actions-grid">
        {% for key, item in actions.items() %}
        <div class="action-card">
            <h3>{{ item.title }}</h3>
            <p>{{ item.desc }}</p>
            <a class="btn" href="{{ url_for('run_action', group='main', key=key) }}">Chạy</a>
        </div>
        {% endfor %}

        <div class="action-card">
            <h3>Mở rooms.txt</h3>
            <p>File khai báo dải mạng/phòng để scan.</p>
            <a class="btn" href="{{ url_for('open_path_route', target='rooms') }}">Mở rooms.txt</a>
        </div>

        <div class="action-card">
            <h3>Mở clients.txt</h3>
            <p>Danh sách máy client hiện tại.</p>
            <a class="btn" href="{{ url_for('open_path_route', target='clients') }}">Mở clients.txt</a>
        </div>
    </div>
</div>
{% endblock %}
"""


VEYON_TEMPLATE = r"""
{% extends "base" %}

{% block content %}
<div class="hero">
    <h1>Veyon</h1>
    <p>Scan, import, mở Veyon Master và Configurator.</p>
</div>

<div class="panel">
    <h2>Veyon Actions</h2>

    <div class="actions-grid">
        {% for key, item in actions.items() %}
        <div class="action-card">
            <h3>{{ item.title }}</h3>
            <p>{{ item.desc }}</p>
            <a class="btn" href="{{ url_for('run_action', group='veyon', key=key) }}">Chạy</a>
        </div>
        {% endfor %}

        <div class="action-card">
            <h3>Mở Veyon Master</h3>
            <p>Quan sát, điều khiển, collect file.</p>
            <a class="btn" href="{{ url_for('open_path_route', target='veyon_master') }}">Mở</a>
        </div>

        <div class="action-card">
            <h3>Mở Veyon Configurator</h3>
            <p>Cấu hình location, computer, authentication.</p>
            <a class="btn" href="{{ url_for('open_path_route', target='veyon_config') }}">Mở</a>
        </div>

        <div class="action-card">
            <h3>Mở rooms.txt</h3>
            <p>File khai báo phòng/dải mạng.</p>
            <a class="btn" href="{{ url_for('open_path_route', target='rooms') }}">Mở rooms.txt</a>
        </div>

        <div class="action-card">
            <h3>Mở clients.txt</h3>
            <p>Danh sách IP client hiện tại.</p>
            <a class="btn" href="{{ url_for('open_path_route', target='clients') }}">Mở clients.txt</a>
        </div>
    </div>
</div>
{% endblock %}
"""


TASKS_TEMPLATE = r"""
{% extends "base" %}

{% block content %}
<div class="hero">
    <h1>QDA Tasks</h1>
    <p>Cài đặt phần mềm, mở file cấu hình và thư mục nguồn.</p>
</div>

<div class="panel">
    <h2>QDA Tasks</h2>

    <div class="actions-grid">
        {% for key, item in actions.items() %}
        <div class="action-card">
            <h3>{{ item.title }}</h3>
            <p>{{ item.desc }}</p>
            <a class="btn" href="{{ url_for('run_action', group='tasks', key=key) }}">Chạy</a>
        </div>
        {% endfor %}

        <div class="action-card">
            <h3>Mở apps_menu.txt</h3>
            <p>Chỉnh danh sách task cài đặt.</p>
            <a class="btn" href="{{ url_for('open_path_route', target='apps_menu') }}">Mở apps_menu.txt</a>
        </div>

        <div class="action-card">
            <h3>Mở INSTALLERS</h3>
            <p>Thư mục chứa source phần mềm.</p>
            <a class="btn" href="{{ url_for('open_path_route', target='installers') }}">Mở INSTALLERS</a>
        </div>

        <div class="action-card">
            <h3>Mở QDA folder</h3>
            <p>Mở toàn bộ thư mục qda_auto.</p>
            <a class="btn" href="{{ url_for('open_path_route', target='qda_base') }}">Mở folder</a>
        </div>
    </div>
</div>
{% endblock %}
"""


POWER_TEMPLATE = r"""
{% extends "base" %}

{% block content %}
<div class="hero">
    <h1>Power / BIOS</h1>
    <p>Shutdown, Exam Mode, HP/Dell BIOS Power-On.</p>
</div>

<div class="panel">
    <h2>Power / BIOS Actions</h2>

    <div class="actions-grid">
        {% for key, item in actions.items() %}
        <div class="action-card">
            <h3>{{ item.title }}</h3>
            <p>{{ item.desc }}</p>
            <a class="btn" href="{{ url_for('run_action', group='power', key=key) }}">Chạy</a>
        </div>
        {% endfor %}

        <div class="action-card">
            <h3>Mở shutdown success</h3>
            <p>Danh sách máy chạy shutdown thành công.</p>
            <a class="btn" href="{{ url_for('open_path_route', target='shutdown_success') }}">Mở success</a>
        </div>

        <div class="action-card">
            <h3>Mở shutdown failed</h3>
            <p>Danh sách máy shutdown lỗi.</p>
            <a class="btn" href="{{ url_for('open_path_route', target='shutdown_failed') }}">Mở failed</a>
        </div>
    </div>
</div>
{% endblock %}
"""


LOGS_TEMPLATE = r"""
{% extends "base" %}

{% block content %}
<div class="hero">
    <h1>Logs</h1>
    <p>Xem các file kết quả của QDA.</p>
</div>

<div class="top-actions">
    <a class="btn" href="{{ url_for('logs') }}">Refresh Logs</a>
    <a class="btn" href="{{ url_for('open_path_route', target='qda_base') }}">Open QDA folder</a>
</div>

<pre>{{ logs }}</pre>
{% endblock %}
"""


# =========================
# TEMPLATE LOADER
# =========================

from jinja2 import DictLoader

APP.jinja_loader = DictLoader({
    "base": BASE_TEMPLATE,
    "dashboard": DASHBOARD_TEMPLATE,
    "veyon": VEYON_TEMPLATE,
    "tasks": TASKS_TEMPLATE,
    "power": POWER_TEMPLATE,
    "logs": LOGS_TEMPLATE,
})


# =========================
# ROUTES
# =========================

@APP.route("/api/status")
def api_status():
    return jsonify({
        "clients_count": count_clients(),
        "qda_base": str(QDA_BASE),
    })


@APP.route("/")
def dashboard():
    return render_template_string(
        DASHBOARD_TEMPLATE,
        qda_base=str(QDA_BASE),
        clients_count=count_clients(),
        now=datetime.now().strftime("%d/%m/%Y %H:%M:%S"),
        actions=MAIN_ACTIONS,
    )


@APP.route("/veyon")
def veyon():
    return render_template_string(
        VEYON_TEMPLATE,
        qda_base=str(QDA_BASE),
        actions=VEYON_ACTIONS,
    )


@APP.route("/tasks")
def tasks():
    return render_template_string(
        TASKS_TEMPLATE,
        qda_base=str(QDA_BASE),
        actions=TASK_ACTIONS,
    )


@APP.route("/power")
def power():
    return render_template_string(
        POWER_TEMPLATE,
        qda_base=str(QDA_BASE),
        actions=POWER_ACTIONS,
    )


@APP.route("/logs")
def logs():
    return render_template_string(
        LOGS_TEMPLATE,
        qda_base=str(QDA_BASE),
        logs=load_logs(),
    )


@APP.route("/run/<group>/<key>")
def run_action(group, key):
    groups = {
        "main": MAIN_ACTIONS,
        "veyon": VEYON_ACTIONS,
        "tasks": TASK_ACTIONS,
        "power": POWER_ACTIONS,
    }

    if group not in groups:
        flash(f"Nhóm action không hợp lệ: {group}", "error")
        return redirect(url_for("dashboard"))

    actions = groups[group]

    if key not in actions:
        flash(f"Action không hợp lệ: {key}", "error")
        return redirect(url_for("dashboard"))

    filename = actions[key]["file"]
    run_bat_file(filename)

    return redirect(url_for("dashboard"))


@APP.route("/open/<target>")
def open_path_route(target):
    mapping = {
        "rooms": QDA_BASE / "rooms.txt",
        "clients": QDA_BASE / "clients.txt",
        "apps_menu": QDA_BASE / "apps_menu.txt",
        "installers": QDA_BASE / "INSTALLERS",
        "qda_base": QDA_BASE,

        "veyon_master": VEYON_MASTER,
        "veyon_config": VEYON_CONFIG,

        "shutdown_success": QDA_BASE / "shutdown_tasks_success.txt",
        "shutdown_failed": QDA_BASE / "shutdown_tasks_failed.txt",
    }

    if target not in mapping:
        flash(f"Target không hợp lệ: {target}", "error")
        return redirect(url_for("dashboard"))

    open_file_or_folder(mapping[target])

    return redirect(url_for("dashboard"))


# =========================
# MAIN
# =========================

if __name__ == "__main__":
    APP.run(host="0.0.0.0", port=8088, debug=False)