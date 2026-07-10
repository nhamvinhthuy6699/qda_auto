import qda_db


def main():
    qda_db.init_db()

    print("===== SAVE CONFIG SNAPSHOT =====")
    print("1) clients.txt")
    print("2) rooms.txt")
    print("3) apps_menu.txt")
    print("4) veyon_import.csv")
    print("5) veyon_clients.csv")

    choice = input("Nhap lua chon, vi du 1: ").strip()

    file_map = {
        "1": "clients.txt",
        "2": "rooms.txt",
        "3": "apps_menu.txt",
        "4": "veyon_import.csv",
        "5": "veyon_clients.csv",
    }

    file_name = file_map.get(choice)

    if not file_name:
        print("[LOI] Lua chon khong hop le.")
        return

    file_path = qda_db.QDA_BASE / file_name

    if not file_path.exists():
        print("[LOI] Khong thay file:")
        print(file_path)
        return

    print()
    print("File can snapshot:")
    print(file_path)

    snapshot_name = input("Nhap ten commit/snapshot, vi du FULL IP NETWORK: ").strip()

    if not snapshot_name:
        print("[LOI] Ten snapshot khong duoc rong.")
        return

    snapshot_id = qda_db.save_config_snapshot(
        snapshot_name,
        file_path
    )

    print()
    print("[OK] Da luu snapshot.")
    print("ID   :", snapshot_id)
    print("Name :", snapshot_name)
    print("File :", file_name)

    print()
    print("===== SNAPSHOT CUA FILE NAY =====")

    snapshots = qda_db.list_config_snapshots(file_name=file_name)

    for s in snapshots:
        print(
            f"#{s['id']} | {s['snapshot_name']} | "
            f"{s['file_name']} | {s['created_at']}"
        )


if __name__ == "__main__":
    main()