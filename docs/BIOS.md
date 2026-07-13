# HP và Dell BIOS Power-On

## HP

File:

```text
run_hp_poweron_tasks.bat
deploy_hp_poweron_tasks.ps1
hp_poweron_tasks_local.bat
HP_BCU/BiosConfigUtility64.exe
```

Chức năng:

- Copy HP BCU.
- Chọn ngày.
- Đặt giờ/phút BIOS Power-On.
- Tạo Startup tự mở QDA/SEB.

Client runtime:

```text
C:\Windows\Temp\NTP_LAB
```

HP BCU nhận file:

```text
BIOSConfig 1.0
Monday
    *Enable
BIOS Power-On Hour
    6
BIOS Power-On Minute
    30
```

## Dell

File:

```text
run_dell_poweron_tasks.bat
deploy_dell_poweron_tasks.ps1
dell_poweron_tasks_local.bat
DELL_CMD/cctk.exe
```

Client runtime:

```text
C:\Windows\Temp\DELL_AUTOON
```

Dell Command Configure dùng các setting như:

```text
--autoon
--autoonhr
--autoonmn
```

Tên và khả năng setting phụ thuộc model BIOS.

## Startup QDA/SEB

Script tìm file `.seb` hoặc shortcut QDA/BQP trong:

- Desktop.
- Documents.
- Downloads.
- Public Desktop.

Sau đó tạo:

```text
C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\open_qda_startup.bat
```

## Lưu ý

- Kiểm tra ngày/giờ nhập phải hợp lệ.
- Máy cần cắm nguồn.
- BIOS có thể yêu cầu password.
- Công cụ HP không dùng cho Dell và ngược lại.


