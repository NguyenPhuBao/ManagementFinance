# Thông báo: danh sách trắng của tính năng "đọc biến động số dư trên máy" thêm MoMo và ZaloPay

**Ngày:** 2026-09-28 · **Người viết:** phía Client-app · **Nhánh:** `TranQuangDat`
**Loại:** **thông báo**, kèm một câu hỏi có mặc định. **Không xin đổi mã backend, không migration, không trường đồng bộ
mới.** Backend không trả lời thì client làm theo mặc định ở mục 3.

---

## Tệp cần đọc

| Tệp | Vì sao |
|---|---|
| `docs/superpowers/backend/DA-XONG/CLIENT_DOC_BIEN_DONG_SO_DU_TREN_MAY.md` | đơn gốc (2026-09-25) và phản hồi **duyệt toàn diện** của backend (2026-09-26, mục 5) |
| `docs/superpowers/specs/2026-09-28-d1-doc-bien-dong-so-du-design.md` | thiết kế Phần 2 phía client, người dùng duyệt 2026-09-28; mục 2 (Kotlin) và 3.4 (màn xin đồng ý) |
| `docs/Rule_Project/Data_Security.md` | Nghị định 13/2023, căn cứ của yêu cầu màn xin đồng ý |

---

## 1. Thay đổi so với bản backend đã duyệt

Đơn gốc mục 2 ghi danh sách trắng là **4 app ngân hàng** (MB Bank, Vietcombank, Techcombank, BIDV) **và các app Tin
nhắn**. Khi thiết kế Phần 2, người dùng (PO phía client) chọn thêm **hai ví điện tử: MoMo và ZaloPay**, vì phần lớn
giao dịch hằng ngày của họ đi qua hai ví này.

Danh sách trắng vòng đầu nay là **bảy nguồn**: MB Bank · Vietcombank · Techcombank · BIDV · app Tin nhắn (SMS) · MoMo ·
ZaloPay.

## 2. Những gì KHÔNG đổi

Mọi cam kết backend đã duyệt ở đơn gốc giữ nguyên cho cả hai nguồn mới:

- Cùng **một** cơ chế: `NotificationListenerService` đọc thông báo **đã hiện trên máy**. Không API, không liên kết tài
  khoản ví, không đăng nhập ví.
- Lọc bỏ tin OTP / mã xác thực **trước khi** ghi đĩa; chỉ giữ tin có mẫu **số tiền**. ⚠️ *Cập nhật 2026-09-30:* câu gốc
  ghi *"số tiền kèm dấu ±"*, nhưng đo trên máy thật thì tin MoMo / ZaloPay **không có dấu ±** (*"Nhận 15.000đ qua chuyển
  khoản"*, *"Số tiền 20.000 ₫ …"* — chiều nằm ở chữ *"Nhận"*), và Techcombank viết `+ VND 208,080`. Bộ lọc nay giữ tin
  có số kèm dấu ± **hoặc** số kèm đơn vị đ / ₫ / VND. Vẫn chỉ là bộ **lọc** (không trích gì), vẫn bỏ OTP trước — không
  đổi cam kết nào khác. Tên gói đã đo trên OnePlus 13R: `com.mservice.momotransfer`, `vn.com.vng.zalopay`.
- Tin thô **xoá ngay** khi app đọc xong; phần đã đọc (số tiền, chiều, thời gian, nội dung) xoá khi người dùng *Lưu* /
  *Bỏ qua*, tối đa 30 ngày. Không gửi đi đâu.
- **Không tự tạo giao dịch.** Người dùng bấm *Lưu* trên form; giao dịch đi đồng bộ như nhập tay, `provider = 'Manual'`,
  payload 13 trường.
- **Màn xin đồng ý** (backend bắt buộc, mục 5 câu 4 đơn gốc) liệt kê danh sách trắng trước khi dẫn người dùng tới Cài đặt
  quyền truy cập thông báo (spec Phần 2 mục 3.4). ⚠️ *Cập nhật 2026-09-30:* câu gốc ghi *"đủ bảy nguồn"*; PO phía client
  chốt màn chỉ liệt kê những nguồn app **đang thật sự đọc** — danh sách trắng chỉ gồm gói đã đo trên máy thật (lúc viết:
  MB Bank, MoMo, ZaloPay; Vietcombank, Techcombank, BIDV, Tin nhắn chưa có mẫu). Hứa đọc một nguồn chưa đọc được là sai với
  chính yêu cầu *"nêu rõ danh sách trắng"* của câu 4. Đo thêm gói nào thì màn tự thêm nguồn ấy.

## 3. Câu hỏi cho backend

| # | Câu hỏi | Mặc định của client |
|---|---|---|
| 1 | Phản hồi *"không áp lệnh cấm"* của câu 1 đơn gốc (lý do dừng Module Bank là API trung gian, không phải đọc thông báo trên máy) có áp cho **thông báo của ví điện tử** MoMo / ZaloPay không? | **có áp**: cùng bản chất, không API, không liên kết, dữ liệu không rời máy |
| 2 | Chức năng 3 (Deduplication) trong `LogicBusinessAI.md`: backend có muốn ghi thêm *"gồm ví điện tử"* khi cập nhật ô trạng thái sau khi client làm xong không? | client báo lại khi xong, backend tự quyết cách ghi |

## 4. Kiểm lại phía client

Khi D1 xong, client sẽ: (a) `grep -n "MoMo\|ZaloPay" src/Client-app/android/app/src/main/kotlin -r` ra đúng hằng danh sách
trắng; (b) màn xin đồng ý liệt kê đúng danh sách trắng đang đọc (widget test
`dong_y_bien_dong_test.dart`); (c) báo lại trong một đơn soát như các lần trước.
