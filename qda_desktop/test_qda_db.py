from database import qda_db


def main():
    qda_db.init_db()
    qda_db.print_database_info()

    clients_file = qda_db.QDA_BASE / "clients.txt"

    if not clients_file.exists():
        clients_file.parent.mkdir(parents=True, exist_ok=True)
        clients_file.write_text(
            "192.168.24.101\n192.168.24.102\n192.168.24.103\n",
            encoding="utf-8"
        )
        print("[OK] Da tao file test:", clients_file)

    snapshot_id = qda_db.save_config_snapshot(
        "FULL IP NETWORK TEST",
        clients_file
    )

    print("[OK] Da luu snapshot ID:", snapshot_id)

    print()
    print("===== DANH SACH SNAPSHOT =====")

    snapshots = qda_db.list_config_snapshots(file_name="clients.txt")

    for s in snapshots:
        print(
            f"#{s['id']} | {s['snapshot_name']} | "
            f"{s['file_name']} | {s['created_at']}"
        )


if __name__ == "__main__":
    main()