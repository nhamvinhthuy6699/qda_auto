# QDA Auto

> Hệ thống chuẩn bị cho phòng thi và quản lý hàng loạt máy tính Windows trong phòng máy.

## Giới thiệu

`QDA Auto` cho phép một máy quản trị thực hiện các tác vụ trên nhiều máy client thông qua mạng LAN:

- Quét các phòng máy và tạo danh sách client.
- Triển khai phần mềm, file và thư mục.
- Cài Safe Exam Browser, Office 2016, WinRAR và Veyon.
- Dọn Desktop, Downloads và thư mục bài thi.
- Cấu hình BIOS tự bật máy HP và Dell.
- Kiểm kê phần mềm và trạng thái từng client.
- Dọn dữ liệu tự động khi Windows shutdown/restart bằng Windows Service.

Hệ thống hướng tới các phòng máy Windows được kết nối trong LAN.

## Kiến trúc

```text
Máy quản trị
    │
    ├── clients.txt / rooms.txt
    ├── PowerShell Controller
    ├── PsExec
    └── Source cài đặt
            │
            │ SMB \\CLIENT\C$
            ▼
      Máy Windows client
            │
            ├── Script được chép tạm
            ├── Chạy bằng LocalSystem
            ├── Cài đặt / cấu hình / cleanup
            └── Ghi result và log
```

Phần lớn chức năng được tổ chức thành ba tầng:

1. **Launcher `.bat`**: giao diện mở chức năng.
2. **Controller `.ps1`**: đọc client, chạy đồng thời và điều phối từ server.
3. **Worker cục bộ**: thực thi thay đổi thật trên client.

## Chức năng chính

### Triển khai ứng dụng

`install.bat` mở menu từ `apps_menu.txt`, sau đó `install.ps1`:

1. Đọc lựa chọn của quản trị viên.
2. Đọc IP từ `clients.txt`.
3. Kết nối `\\IP\C$`.
4. Chép source vào `C:\APP_DEPLOY\INSTALL`.
5. Tự sinh `install_local.bat`.
6. Dùng PsExec chạy bằng `SYSTEM`.
7. Thu result và log về server.

Các loại tác vụ được hỗ trợ:

```text
EXE, EXE_SILENT, MSI, COPY, FOLDER, BAT, PS1,
ZIP, WINGET, APPX, MSIX, APPXBUNDLE, MSIXBUNDLE
```

### Chế độ thi

- Ẩn ổ C trong File Explorer.
- Bật hoặc tắt Wi-Fi.
- Restart client.
- Dọn dữ liệu thi trước khi tắt chế độ.
- Ghi danh sách máy thành công và thất bại.

### Cleanup khi shutdown

Phiên bản mới có `QDACleanupService`:

- Windows Service chạy bằng `LocalSystem`.
- Nhận sự kiện `PRESHUTDOWN` và `SHUTDOWN`.
- Chạy PowerShell để dọn dữ liệu trước khi máy tắt.
- Tạo `recycle_pending.flag`.
- Sau lần khởi động tiếp theo, đợi user đăng nhập và `explorer.exe` hoạt động.
- Chạy dọn Recycle Bin trong đúng user session.

### BIOS Power-On

- **HP**: dùng HP BIOS Configuration Utility.
- **Dell**: dùng Dell Command Configure/CCTK.
- Chọn ngày trong tuần và giờ tự bật.
- Có thể tạo Startup chung để tự mở QDA/SEB sau khi đăng nhập.

### Kiểm kê client

`check_client_status.ps1` tạo:

```text
status/<IP>.json
status/inventory_summary.json
```

Thông tin bao gồm:

- Trạng thái online và quyền truy cập `C$`.
- Hệ điều hành và dung lượng ổ C.
- SEB, Veyon, Office 2016 và Microsoft 365.
- HP BCU và Dell CCTK.
- File QDA `.seb`.
- Trạng thái Wi-Fi.
- Trạng thái ẩn/chặn ổ C.
- Kết quả kiểm tra theo từng mục trong `apps_menu.txt`.

## Cấu trúc repository

```text
qda_auto/
├── INSTALLERS/
│   ├── QDA_CLEANUP_SERVICE/
│   │   ├── QDACleanupService.cs
│   │   └── cleanup_exam_remote_client.ps1
│   ├── install_qda_cleanup_service.bat
│   ├── uninstall_qda_cleanup_service.bat
│   ├── install_office2016.bat
│   ├── uninstall_office2016.bat
│   ├── remove_m365_odt.bat
│   ├── install_veyon_client.bat
│   └── ...
├── install.bat
├── install.ps1
├── apps_menu.txt
├── run_scan_rooms.bat
├── scan_rooms_to_clients.ps1
├── scan_rooms_to_veyon.ps1
├── run_exam_mode.bat
├── deploy_exam_mode.ps1
├── exam_mode_local.bat
├── cleanup_exam_all_silent.ps1
├── cleanup_exam_remote_client.ps1
├── run_shutdown_tasks.bat
├── deploy_shutdown_tasks.ps1
├── shutdown_tasks_local.bat
├── deploy_hp_poweron_tasks.ps1
├── hp_poweron_tasks_local.bat
├── deploy_dell_poweron_tasks.ps1
├── check_client_status.ps1
├── client_status_local.ps1
└── set_ntp_server_windows.bat
```

Một số file lớn và dữ liệu vận hành có thể không được lưu trong Git:

```text
clients.txt
rooms.txt
PsExec.exe
Nmap/
HP_BCU/
DELL_CMD/
OFFICE2016/
ODT/
VEYON/
```

## Bắt đầu nhanh

### 1. Chuẩn bị máy quản trị

- Windows 10 hoặc Windows 11.
- Chạy các launcher bằng Administrator.
- Đặt `PsExec.exe` trong thư mục `qda_auto`.
- Đặt Nmap portable trong `qda_auto\Nmap` hoặc cài Nmap vào PATH.

### 2. Chuẩn bị client

Client cần:

- Có tài khoản Administrator cục bộ dùng chung.
- SMB và administrative share `C$` hoạt động.
- TCP 445 đi được từ máy quản trị.
- Firewall cho phép File and Printer Sharing.
- PsExec có thể tạo và chạy service từ xa.
- Máy đang bật và kết nối LAN.

### 3. Tạo `rooms.txt`

```text
201A=192.168.11.0/24
201B=192.168.12.0/24
301A=192.168.18.0/24
```

### 4. Quét client

```text
run_scan_rooms.bat
```

Scanner chỉ đưa vào `clients.txt` các máy có TCP 445 mở.

### 5. Kiểm tra trạng thái

```text
run_check_all_clients.bat
```

### 6. Triển khai ứng dụng

```text
install.bat
```

Có thể nhập:

```text
1
1,2,3
ALL
```

### 7. Cài QDA Cleanup Service

Trong menu cài đặt:

```text
14 = Copy QDA Cleanup Service Source
15 = Install QDA Cleanup Service
16 = Uninstall QDA Cleanup Service
```

Để cài mới, chọn:

```text
14,15
```

## Tài liệu

- [Hướng dẫn cài đặt](docs/INSTALL.md)
- [Kiến trúc hệ thống](docs/ARCHITECTURE.md)
- [Quy trình triển khai](docs/DEPLOYMENT.md)
- [Chế độ thi](docs/EXAM_MODE.md)
- [QDA Cleanup Service](docs/CLEANUP_SERVICE.md)
- [HP/Dell BIOS Power-On](docs/BIOS.md)
- [Kiểm kê client](docs/CLIENT_STATUS.md)


## Phạm vi sử dụng

Dự án phù hợp với:

- Phòng máy trường học và đại học.
- Phòng thi tin học.
- Trung tâm đào tạo.
- Mạng LAN Windows.
- Quy mô từ vài chục đến hàng trăm máy.

## Trạng thái dự án

Dự án đang được phát triển và kiểm thử trong môi trường phòng máy thực tế. 

## Tác giả

**Nhâm Vĩnh Thủy**

Repository: `nhamvinhthuy6699/qda_auto`
