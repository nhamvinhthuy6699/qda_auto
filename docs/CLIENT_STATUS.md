# Kiểm kê trạng thái client

## Chạy một máy

```text
run_check_one_client.bat
```

## Chạy toàn bộ

```text
run_check_all_clients.bat
```

## Luồng

`check_client_status.ps1`:

1. Ping client.
2. Mở C$.
3. Copy client_status_local.ps1.
4. Chạy PowerShell bằng SYSTEM.
5. Chờ JSON.
6. Copy JSON về server.
7. Tạo inventory summary.

## Dữ liệu JSON

Ví dụ:

```json
{
  "ip": "192.168.11.168",
  "computer_name": "LAB-PC01",
  "online": true,
  "os_caption": "Microsoft Windows 11 Pro",
  "c_drive_free_gb": 120.5,
  "veyon_installed": true,
  "seb_installed": true,
  "office2016_installed": true,
  "microsoft365_installed": false,
  "wifi": "Wi-Fi:Up",
  "c_drive_hidden": false,
  "c_drive_blocked": false
}
```

## Kiểm tra theo menu

apps_menu_checks kiểm tra theo ID trong apps_menu.txt.

## Dữ liệu cũ

inventory_summary.json có thể đọc các JSON còn tồn tại từ lần trước. Trước một đợt kiểm tra chính thức nên:

- Lưu snapshot cũ.
- Xóa JSON IP cũ.
- Chạy full inventory lại.
