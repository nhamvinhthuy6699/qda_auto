import sys
import sqlite3
from pathlib import Path
from datetime import datetime


# =========================
# QDA SQLITE DATABASE
# =========================
# Database nam tai:
#   <APP_ROOT>\qda_auto\qda.db
#
# Dev mode:
#   C:\mywork\qda_desktop\database\qda_db.py
#   => APP_ROOT = C:\mywork
#
# EXE mode:
#   C:\mywork\QDA.exe
#   => APP_ROOT = C:\mywork
# =========================


def get_app_root():
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent

    # qda_db.py nam trong:
    # C:\mywork\qda_desktop\database\qda_db.py
    # parents[0] = database
    # parents[1] = qda_desktop
    # parents[2] = mywork
    return Path(__file__).resolve().parents[2]


APP_ROOT = get_app_root()
QDA_BASE = APP_ROOT / "qda_auto"
DB_PATH = QDA_BASE / "qda.db"


def get_conn():
    QDA_BASE.mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row

    return conn


def init_db():
    conn = get_conn()
    cur = conn.cursor()

    cur.execute("""
        CREATE TABLE IF NOT EXISTS config_snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            snapshot_name TEXT NOT NULL,
            file_name TEXT NOT NULL,
            file_path TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at TEXT NOT NULL
        )
    """)

    conn.commit()
    conn.close()


def save_config_snapshot(snapshot_name, file_path):
    path = Path(file_path)

    if not path.exists():
        raise FileNotFoundError(f"File not found: {path}")

    content = path.read_text(encoding="utf-8", errors="ignore")
    created_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    conn = get_conn()
    cur = conn.cursor()

    cur.execute(
        """
        INSERT INTO config_snapshots (
            snapshot_name,
            file_name,
            file_path,
            content,
            created_at
        )
        VALUES (?, ?, ?, ?, ?)
        """,
        (
            snapshot_name,
            path.name,
            str(path),
            content,
            created_at,
        )
    )

    conn.commit()
    snapshot_id = cur.lastrowid
    conn.close()

    return snapshot_id


def list_config_snapshots(file_name=None, limit=100):
    conn = get_conn()
    cur = conn.cursor()

    if file_name:
        cur.execute(
            """
            SELECT
                id,
                snapshot_name,
                file_name,
                file_path,
                created_at
            FROM config_snapshots
            WHERE file_name = ?
            ORDER BY id DESC
            LIMIT ?
            """,
            (file_name, limit)
        )
    else:
        cur.execute(
            """
            SELECT
                id,
                snapshot_name,
                file_name,
                file_path,
                created_at
            FROM config_snapshots
            ORDER BY id DESC
            LIMIT ?
            """,
            (limit,)
        )

    rows = [dict(row) for row in cur.fetchall()]
    conn.close()

    return rows


def get_snapshot(snapshot_id):
    conn = get_conn()
    cur = conn.cursor()

    cur.execute(
        """
        SELECT
            id,
            snapshot_name,
            file_name,
            file_path,
            content,
            created_at
        FROM config_snapshots
        WHERE id = ?
        """,
        (snapshot_id,)
    )

    row = cur.fetchone()
    conn.close()

    if not row:
        return None

    return dict(row)


def restore_config_snapshot(snapshot_id):
    snapshot = get_snapshot(snapshot_id)

    if not snapshot:
        raise ValueError(f"Snapshot not found: {snapshot_id}")

    path = Path(snapshot["file_path"])
    path.parent.mkdir(parents=True, exist_ok=True)

    path.write_text(snapshot["content"], encoding="utf-8")

    return path


def delete_config_snapshot(snapshot_id):
    conn = get_conn()
    cur = conn.cursor()

    cur.execute(
        """
        DELETE FROM config_snapshots
        WHERE id = ?
        """,
        (snapshot_id,)
    )

    conn.commit()
    deleted = cur.rowcount
    conn.close()

    return deleted


def print_database_info():
    print("APP_ROOT =", APP_ROOT)
    print("QDA_BASE =", QDA_BASE)
    print("DB_PATH  =", DB_PATH)