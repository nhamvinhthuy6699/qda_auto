# Chế độ thi

## File liên quan

```text
run_exam_mode.bat
deploy_exam_mode.ps1
exam_mode_local.bat
cleanup_exam_all_silent.bat
cleanup_exam_all_silent.ps1
cleanup_exam_remote_client.ps1
```

## Bật chế độ thi

Controller:

1. Đọc clients.txt.
2. Copy exam_mode_local.bat.
3. Chạy bằng PsExec/SYSTEM.
4. Chờ result.
5. Tổng hợp success/failed.

Client:

1. Đặt policy ổ C.
2. Khởi chạy process nền.
3. Ghi result.
4. Tắt Wi-Fi.
5. Restart.

## Tắt chế độ thi

Trước khi tắt, controller chạy cleanup hàng loạt:

- Dọn ThiCNTT.
- Dọn Downloads.
- Dọn Desktop theo whitelist.
- Dọn Recycle Bin khi có thể.

Sau cleanup:

- Xóa policy ổ C.
- Bật Wi-Fi.
- Restart.

## Policy ổ C

Windows dùng bitmask:

```text
A=1, B=2, C=4, D=8...
```

Để ẩn C:

```text
NoDrives=4
```

Để chặn duyệt C trong Explorer:

```text
NoViewOnDrive=4
```

Cần kiểm tra cả hai bằng client_status_local.ps1.
