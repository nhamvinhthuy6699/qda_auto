# Hướng dẫn cài đặt

## 1. Yêu cầu trên máy quản trị

- Windows 10/11.
- PowerShell 5.1+.
- Quyền Administrator.
- PsExec.
- Nmap.
- Kết nối LAN tới các client.

Cấu trúc tối thiểu:

```text
qda_auto/
├── PsExec.exe
├── clients.txt
├── rooms.txt
├── Nmap/
│   └── nmap.exe
└── INSTALLERS/
```

## 2. Chuẩn bị tài khoản client

Các script hiện sử dụng tài khoản local:

```text
admintest
```

Mật khẩu được khai báo trong các controller PowerShell. Hãy thay bằng tài khoản thực tế của môi trường và không commit mật khẩu thật lên repository public.

Client cần cho phép:

- File and Printer Sharing.
- Administrative share `C$`.
- TCP 445.
- Remote Service Management/PsExec.
- Tài khoản thuộc nhóm Administrators.

Kiểm tra từ server:

```bat
ping 192.168.11.168
powershell Test-NetConnection 192.168.11.168 -Port 445
net use \\192.168.11.168\C$ /user:admintest
dir \\192.168.11.168\C$\
```

## 3. Chuẩn bị `rooms.txt`

```text
201A=192.168.11.0/24
201B=192.168.12.0/24
```

## 4. Quét client

Chạy Administrator:

```text
run_scan_rooms.bat
```

Kết quả:

```text
clients.txt
scan_rooms_log.txt
scan_rooms_success.txt
scan_rooms_failed.txt
```

## 5. Chuẩn bị source cài đặt

Ví dụ:

```text
INSTALLERS/
├── SafeExamBrowser2.4.1.exe
├── QDA2026_BQP.seb
├── UniKeyNT.exe
├── winrar-x64-722.exe
├── OFFICE2016/
├── ODT/
├── VEYON/
└── QDA_CLEANUP_SERVICE/
```

## 6. Cài phần mềm

Chạy:

```text
install.bat
```

Các mục được định nghĩa trong `apps_menu.txt`.

Thứ tự mẫu:

```text
1,2,3,9,10,11,12
```

Office 2016:

```text
4,6
```

Gỡ Microsoft 365 trước khi cài Office 2016:

```text
7,8,4,6
```

QDA Cleanup Service:

```text
14,15
```

## 7. Xác minh

Chạy:

```text
run_check_all_clients.bat
```

Kiểm tra:

```text
status/inventory_summary.json
install_success.txt
install_failed.txt
```

## 8. Nâng cấp Cleanup Service

Chạy lại:

```text
14,15
```

Installer sẽ:

1. Stop service cũ.
2. Copy PowerShell mới.
3. Xóa EXE cũ.
4. Compile lại C# bằng `csc.exe`.
5. Update hoặc create service.
6. Start và verify service.

## 9. Gỡ Cleanup Service

Chọn mục:

```text
16
```

Sau đó kiểm tra:

```bat
sc query QDACleanupService
```
