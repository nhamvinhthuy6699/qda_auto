import qda_db


def main():
    qda_db.init_db()

    snapshots = qda_db.list_config_snapshots()

    print("===== DANH SACH SNAPSHOT =====")

    if not snapshots:
        print("Chua co snapshot nao.")
        return

    for s in snapshots:
        print(
            f"#{s['id']} | {s['snapshot_name']} | "
            f"{s['file_name']} | {s['created_at']}"
        )

    print()
    snapshot_id = input("Nhap ID snapshot muon restore, vi du 1: ").strip()

    if not snapshot_id.isdigit():
        print("[LOI] ID khong hop le.")
        return

    snapshot_id = int(snapshot_id)

    snapshot = qda_db.get_snapshot(snapshot_id)

    if not snapshot:
        print("[LOI] Khong tim thay snapshot ID:", snapshot_id)
        return

    print()
    print("Ban sap restore snapshot:")
    print(f"ID      : {snapshot['id']}")
    print(f"Name    : {snapshot['snapshot_name']}")
    print(f"File    : {snapshot['file_name']}")
    print(f"Created : {snapshot['created_at']}")
    print(f"Restore : {snapshot['file_path']}")

    print()
    confirm = input("Nhap Y de xac nhan restore: ").strip().upper()

    if confirm != "Y":
        print("[HUY] Khong restore.")
        return

    restored_path = qda_db.restore_config_snapshot(snapshot_id)

    print()
    print("[OK] Da restore vao file:")
    print(restored_path)


if __name__ == "__main__":
    main()