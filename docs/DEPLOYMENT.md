# Quy trình triển khai

## Giai đoạn 1 — Chuẩn bị mạng

1. Đặt máy quản trị IP tĩnh.
2. Xác minh route giữa các subnet.
3. Kiểm tra TCP 445.
4. Kiểm tra tài khoản Administrator.
5. Chạy bootstrap trên client nếu cần.

## Giai đoạn 2 — Tạo danh sách

```text
run_scan_rooms.bat
```

Scanner dùng:

```text
nmap -Pn -n -p 445 --open -T4 <subnet>
```

Chỉ máy mở port 445 được đưa vào clients.txt.

## Giai đoạn 3 — Inventory trước triển khai

```text
run_check_all_clients.bat
```

Lưu lại inventory_summary.json làm baseline.

## Giai đoạn 4 — Cài phần mềm

```text
install.bat
```

Khuyến nghị chia thành nhóm nhỏ:

1. Copy source.
2. Gỡ phiên bản xung đột.
3. Cài ứng dụng.
4. Cấu hình.
5. Inventory lại.

Không nên chọn ALL nếu các mục có thứ tự phụ thuộc hoặc gồm cả install và uninstall.

## Giai đoạn 5 — Cấu hình BIOS

HP:

```text
run_hp_poweron_tasks.bat
```

Dell:

```text
run_dell_poweron_tasks.bat
```

Thử trên một model đại diện trước vì tên setting BIOS có thể khác theo model/firmware.

## Giai đoạn 6 — Chuẩn bị thi

1. Kiểm tra SEB/QDA.
2. Kiểm tra Veyon.
3. Dọn dữ liệu cũ.
4. Bật chế độ thi.
5. Restart.
6. Inventory lại một số máy mẫu.

## Giai đoạn 7 — Kết thúc thi

Lựa chọn:

- Tắt chế độ thi và restart.
- Cleanup hàng loạt.
- Kill SEB/QDA.
- Xóa startup.
- Xóa BIOS schedule.
- Shutdown.

## Quy mô triển khai

Nên chạy theo lô:

```text
10 máy thử nghiệm
→ 1 phòng
→ 1 tầng
→ toàn hệ thống
```

Lưu file success/failed sau từng đợt.
