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


if __name__ == "__main__":
    main()