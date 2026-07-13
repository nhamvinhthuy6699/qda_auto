# Kiến trúc hệ thống

## 1. Các thành phần

### Máy quản trị

Chứa:

- Danh sách phòng và client.
- Source cài đặt.
- Controller PowerShell.
- PsExec và Nmap.
- File kết quả và inventory.

### Máy client

Nhận:

- Source hoặc script qua SMB.
- Lệnh chạy từ PsExec.
- Tác vụ chạy bằng LocalSystem.

## 2. Luồng điều khiển từ xa

```text
Controller PowerShell
        │
        ├── đọc clients.txt
        ├── tạo PowerShell Job
        ├── net use \\IP\C$
        ├── Copy-Item
        ├── PsExec -s -h
        └── đọc result/log
```

## 3. SMB và `C$`

Đường dẫn:

```text
\\192.168.11.168\C$\APP_DEPLOY
```

tương ứng với:

```text
C:\APP_DEPLOY
```

`C$` chỉ truy cập được bằng tài khoản Administrator và phụ thuộc firewall, SMB và Remote UAC.

## 4. PsExec

Các tùy chọn thường dùng:

```text
-s          chạy bằng LocalSystem
-h          elevated token
-d          gửi lệnh và không chờ
-accepteula tự chấp nhận EULA
-nobanner   ẩn banner
```

Khi dùng `-d`, controller chỉ xác nhận lệnh đã được gửi; không thể coi đó là bằng chứng tác vụ đã hoàn tất.

## 5. Throttle

Mỗi controller giữ mảng Job:

```powershell
$Jobs = @()
```

và không cho số Job đang chạy vượt `$Throttle`.

Điều này giảm tải:

- CPU/RAM máy quản trị.
- Băng thông LAN.
- Số kết nối SMB.
- Số tiến trình PsExec đồng thời.

## 6. Result và log

Mẫu:

```text
C:\exam_mode_result.txt
C:\exam_mode_log.txt
C:\shutdown_tasks_result.txt
C:\shutdown_tasks_log.txt
C:\qda_client_status.json
```

Controller đọc qua:

```text
\\IP\C$\...
```

## 7. QDA Cleanup Service

```text
Windows Service
    │
    ├── SERVICE_CONTROL_PRESHUTDOWN
    ├── SERVICE_CONTROL_SHUTDOWN
    ├── cleanup PowerShell dưới SYSTEM
    ├── recycle_pending.flag
    └── CreateProcessAsUser sau khi user login
```

Service dùng Windows API trực tiếp để:

- Đăng ký Service Control Handler.
- Nhận preshutdown.
- Cấu hình timeout.
- Lấy active console session.
- Lấy user token.
- Tạo process trong user session.

## 8. Thư mục runtime

```text
C:\APP_DEPLOY\INSTALL
C:\APP_DEPLOY\EXAM_MODE
C:\APP_DEPLOY\SHUTDOWN
C:\APP_DEPLOY\STATUS
C:\Windows\Temp\QDA_CLEANUP
C:\Windows\Temp\NTP_LAB
C:\Windows\Temp\DELL_AUTOON
C:\ProgramData\QDA\ShutdownCleanup
```
