import qda_db


def print_snapshots(snapshots):
    print("===== DANH SACH SNAPSHOT =====")

    if not snapshots:
        print("Chua co snapshot nao.")
        return

    for s in snapshots:
        print(
            f"#{s['id']} | {s['snapshot_name']} | "
            f"{s['file_name']} | {s['created_at']}"
        )


def parse_delete_input(user_input, snapshots):
    user_input = user_input.strip()

    if not user_input:
        return []

    if user_input.upper() == "ALL":
        return [s["id"] for s in snapshots]

    result = []

    parts = user_input.split(",")

    for part in parts:
        item = part.strip()

        if not item.isdigit():
            continue

        result.append(int(item))

    return result


def main():
    qda_db.init_db()

    snapshots = qda_db.list_config_snapshots()

    print_snapshots(snapshots)

    if not snapshots:
        return

    valid_ids = [s["id"] for s in snapshots]

    print()
    print("Cach xoa:")
    print("  Nhap 1       de xoa snapshot ID 1")
    print("  Nhap 3       de xoa snapshot ID 3")
    print("  Nhap 1,2,3   de xoa nhieu snapshot")
    print("  Nhap ALL     de xoa tat ca snapshot")
    print()

    user_input = input("Nhap ID can xoa hoac ALL: ").strip()

    ids_to_delete = parse_delete_input(user_input, snapshots)

    ids_to_delete = [x for x in ids_to_delete if x in valid_ids]
    ids_to_delete = sorted(set(ids_to_delete))

    if not ids_to_delete:
        print("[LOI] Khong co ID hop le de xoa.")
        return

    print()
    print("===== BAN SAP XOA =====")

    selected_snapshots = []

    for s in snapshots:
        if s["id"] in ids_to_delete:
            selected_snapshots.append(s)
            print(
                f"#{s['id']} | {s['snapshot_name']} | "
                f"{s['file_name']} | {s['created_at']}"
            )

    print()

    if user_input.upper() == "ALL":
        confirm_text = "DELETE ALL"
        confirm = input("Nhap DELETE ALL de xac nhan xoa tat ca: ").strip()

        if confirm != confirm_text:
            print("[HUY] Khong xoa.")
            return
    else:
        confirm = input("Nhap Y de xac nhan xoa: ").strip().upper()

        if confirm != "Y":
            print("[HUY] Khong xoa.")
            return

    total_deleted = 0

    for snapshot_id in ids_to_delete:
        deleted = qda_db.delete_config_snapshot(snapshot_id)
        total_deleted += deleted

    print()
    print("[OK] Da xoa snapshot.")
    print("So snapshot da xoa:", total_deleted)

    print()
    print("===== DANH SACH CON LAI =====")

    remaining = qda_db.list_config_snapshots()
    print_snapshots(remaining)


if __name__ == "__main__":
    main()