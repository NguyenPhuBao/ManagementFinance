# D1 — Đọc biến động số dư trên máy: client ĐÃ XONG, xin cập nhật ô chức năng 3 và bốn chỗ tài liệu

**Ngày:** 2026-09-30 · **Phía gửi:** Client-app · **Loại:** đơn soát (báo kết quả), **không xin đổi mã backend**.

Đơn này thực hiện lời hứa ở mục 4 của `CAN-LAM/CLIENT_DOC_BIEN_DONG_THEM_VI_DIEN_TU.md` (*"khi D1 xong, client báo lại
trong một đơn soát"*) và câu 5 của phản hồi backend ở `DA-XONG/CLIENT_DOC_BIEN_DONG_SO_DU_TREN_MAY.md` (*"Khi Client hoàn
thành và nghiệm thu, Backend sẽ cập nhật ngay trạng thái Chức năng 3"*).

## 1. Client đã làm gì

Tài liệu chi tiết: `docs/BIEN_DONG_SO_DU_FEATURE.md`. Tóm tắt:

- `NotificationListenerService` đọc thông báo **đã hiện trên máy** của danh sách trắng; lọc OTP và chỉ giữ tin có số tiền
  **trước khi** ghi đĩa; không API, không liên kết tài khoản, không `READ_SMS`.
- **Màn xin đồng ý bắt buộc** (câu 4 phản hồi backend) có: mục đích · danh sách trắng · bốn cam kết (bỏ OTP, chỉ lưu trên
  máy, xoá khi ghi / bỏ qua tối đa 30 ngày, không gửi ra ngoài). Chỉ khi người dùng bấm *Đồng ý* dịch vụ mới bật.
- **Khử trùng lặp (chức năng 3):** gộp tin trùng trong hàng chờ và với tin đã có (cùng mã GD, hoặc cùng số tiền + chiều
  cách ≤ 5 phút); trên form, **nhắc** *"Có thể bạn đã ghi khoản này"* khi sổ có khoản cùng số tiền + chiều + ngày (chỉ
  nhắc, không chặn).
- Không tự tạo giao dịch: người dùng bấm *Lưu* trên form điền sẵn; giao dịch đi đồng bộ như nhập tay,
  `provider = 'Manual'`, payload 13 trường — đúng câu 2 phản hồi backend.
- Nghiệm thu trên máy thật (OnePlus 13R, 2026-09-30), cả bản debug lẫn bản release — bảng ở mục 5 tài liệu trên.

⚠️ **Danh sách trắng thực tế HẸP HƠN bảy nguồn đã báo**: chỉ gồm gói **đã đo trên máy thật** — **MB Bank**
(`com.mbmobile`), **MoMo** (`com.mservice.momotransfer`), **ZaloPay** (`vn.com.vng.zalopay`). Vietcombank, Techcombank,
BIDV và **app Tin nhắn (SMS)** chưa có mẫu thật nên **chưa đọc**; sẽ thêm khi đo được. Màn xin đồng ý liệt kê đúng ba
nguồn ấy (đơn ví điện tử mục 2 đã sửa theo).

## 2. Xin backend cập nhật (tài liệu do backend quản — client không sửa)

| # | Chỗ | Hiện ghi | Đề nghị |
|---|---|---|---|
| 1 | `Project.md` bảng 10 chức năng, hàng **3** (dòng ~1611) và mục tóm tắt (dòng ~2723); `docs/AI/LogicBusinessAI.md` hàng **3** (dòng 32) và dòng 77 | ⬜ *"Chưa làm tại Client (Đang thiết kế tính năng đọc biến động số dư trên máy)"* | 🟢 *Đã hoàn thành (Client-app)* — backend tự quyết cách ghi, kèm câu hỏi 2 của đơn ví điện tử (*"gồm ví điện tử"*) |
| 2 | Cùng bốn chỗ trên | *"… SMS và thông báo app ngân hàng qua `NotificationListenerService` …"* | Nguồn đang đọc: thông báo app **MB Bank, MoMo, ZaloPay**; **SMS chưa đọc** (chưa có mẫu thật). Không đọc SMS qua `READ_SMS` ở bất kỳ lúc nào |
| 3 | `docs/progress/Client-app.md` §5.2 *"Khi Đọc Tin Nhắn SMS Banking"* | client gọi `POST /api/ai/classify/single` rồi *"hiển thị dialog xác nhận"* | Client **đoán danh mục trên máy** (tên danh mục → mô hình học từ ghi chú B1 → từ khoá của người dùng), **không gọi API**, và mở **form Thêm giao dịch điền sẵn** chứ không dialog — lý do: tính năng phải chạy khi không có mạng |
| 4 | `docs/progress/Client-app.md` §13.5 *"Quyền Đọc Tin Nhắn (SMS Banking Reader)"* | client quét SMS từ danh sách Brandname (VCB, VietinBank, BIDV, MBBank, Techcombank, ACB, VPBank…) | Client đọc **thông báo app** (không đọc SMS) của danh sách trắng theo **tên gói Android đã đo** — hiện MB Bank, MoMo, ZaloPay |

## 3. Client đã tự sửa để khớp quy tắc của backend

- `docs/progress/Client-app.md` **§13.6** (*không ghi log dữ liệu nhạy cảm, kể cả lúc phát triển*): chế độ thu mẫu của bản
  **debug** (dùng để lấy tên gói và hình dạng tin khi thêm nguồn mới) từng in nguyên nội dung thông báo ra Logcat. Nay chỉ
  in **hình dạng đã che** (mọi chữ số → `9`, mọi từ ngoài nhãn cấu trúc GD / SD / ND / VND … → `…`). Bản release không log
  gì — đo trên máy: 0 byte ở tag `BienDongThu`.

## 4. Kiểm lại

```bash
# Danh sách trắng Kotlin (phải ra đúng ba gói)
grep -n '" to "' src/Client-app/android/app/src/main/kotlin/com/flowmoney/flowmoney/BienDongListenerService.kt
# Test nối dây (so danh sách trắng Dart ↔ Kotlin, canh dòng log đã che) + màn đồng ý liệt kê đúng nguồn đang đọc
cd src/Client-app && flutter test test/core/notification/bien_dong_noi_day_test.dart test/features/notification/dong_y_bien_dong_test.dart
```
