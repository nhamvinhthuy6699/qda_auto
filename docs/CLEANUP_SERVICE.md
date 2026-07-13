# QDA Cleanup Service

## Mục tiêu

`QDACleanupService` giải quyết việc dọn dữ liệu đúng thời điểm Windows shutdown/restart.

Bộ service gồm:

```text
INSTALLERS/QDA_CLEANUP_SERVICE/QDACleanupService.cs
INSTALLERS/QDA_CLEANUP_SERVICE/cleanup_exam_remote_client.ps1
INSTALLERS/install_qda_cleanup_service.bat
INSTALLERS/uninstall_qda_cleanup_service.bat
```

## Cài đặt

Trong `apps_menu.txt`:

```text
14 = Copy source
15 = Install service
16 = Uninstall service
```

Cài mới:

```text
14,15
```

## Vị trí cài đặt

```text
C:\ProgramData\QDA\ShutdownCleanup
├── QDACleanupService.exe
├── cleanup_exam_remote_client.ps1
├── recycle_pending.flag
└── Logs/
    ├── service.log
    ├── cleanup_output.log
    └── last_result.txt
```

## Quá trình installer

`install_qda_cleanup_service.bat`:

1. Kiểm tra source C# và PowerShell.
2. Tìm C# compiler:
   - Framework64 `csc.exe`.
   - Framework 32-bit `csc.exe`.
3. Stop service cũ.
4. Tạo thư mục cài đặt/log.
5. Copy cleanup PowerShell.
6. Compile C# thành EXE.
7. Tạo hoặc update Windows Service.
8. Chạy dưới `LocalSystem`.
9. Start và verify trạng thái `RUNNING`.

## Luồng shutdown

```text
Windows gửi PRESHUTDOWN
        │
        ▼
Service khởi chạy cleanup worker một lần
        │
        ▼
PowerShell dọn Desktop/Downloads/ThiCNTT
        │
        ▼
Tạo recycle_pending.flag
        │
        ▼
Windows tiếp tục shutdown
```

## Luồng sau khởi động

```text
Service start
    │
    ├── thấy recycle_pending.flag?
    │        └── không: kết thúc worker
    │
    └── có:
         ├── chờ active user session
         ├── chờ explorer.exe
         ├── chờ thêm thời gian ổn định
         ├── lấy token user
         ├── CreateProcessAsUser
         └── Clear-RecycleBin trong user session
```

Recycle Bin được dọn trong phiên user thay vì phiên SYSTEM.

## Kiểm tra service

```bat
sc query QDACleanupService
sc qc QDACleanupService
```

Log:

```text
C:\ProgramData\QDA\ShutdownCleanup\Logs\service.log
```

## Cập nhật service

Chạy lại mục:

```text
14,15
```

Installer sẽ compile lại và update service.

## Gỡ service

Chạy mục `16`, sau đó xác minh:

```bat
sc query QDACleanupService
```

## Kiểm thử an toàn

1. Cài trên một máy test.
2. Tạo file mẫu trong Desktop/Downloads/ThiCNTT.
3. Shutdown bình thường.
4. Bật máy và đăng nhập.
5. Kiểm tra file, Recycle Bin và log.
6. Thử restart.
7. Thử khi không có user đăng nhập.
8. Thử khi cleanup PowerShell lỗi.
