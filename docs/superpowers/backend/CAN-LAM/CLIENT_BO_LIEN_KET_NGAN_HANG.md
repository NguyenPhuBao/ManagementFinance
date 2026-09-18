# Client đã bỏ liên kết ngân hàng — bốn tài liệu của backend nay mô tả sai phía client

**Ngày:** 2026-09-18 · **Người viết:** phía Client-app · **Nhánh:** `TranQuangDat`
**Loại:** báo tài liệu lệch. **Không xin đổi mã backend.**

---

## 0. Tóm tắt trong ba câu

Nhóm chốt **bỏ tính năng liên kết ngân hàng** khỏi sản phẩm ngày 2026-09-18, và
phía Client-app đã gỡ toàn bộ phần của mình cùng ngày. Mã backend **không phải
đổi gì** — module `bank/`, tích hợp SePay, các endpoint và cả sự kiện
`bank_transaction.incoming` cứ giữ nguyên, client chỉ thôi dùng chúng. Nhưng
**bốn tài liệu do backend quản đang mô tả phía client là có tính năng ấy**, nên
người đọc sau sẽ tưởng app còn màn liên kết và còn nhận giao dịch ngân hàng.

---

## 1. Client đã gỡ những gì

| Gỡ | Ở đâu |
|---|---|
| Màn liên kết ngân hàng (448 dòng) | `lib/features/wallet/presentation/pages/bank_link_page.dart` — **đã xoá** |
| Widget tiêu đề của màn ấy (114 dòng) | `lib/features/wallet/presentation/widgets/bank_header_row.dart` — **đã xoá** |
| Hai route `/wallets/bank-link` và `/bank-link` | `lib/core/constants/app_router.dart` |
| Thẻ "LIÊN KẾT NGÂN HÀNG" ở màn Quản lý ví | `lib/features/wallet/presentation/pages/wallet_list_page.dart` |
| `RealtimeEvent.giaoDichNganHang` và nhánh dịch `'bank_transaction.incoming'` | `lib/core/realtime/realtime_event.dart` |

Màn bị xoá **chưa bao giờ gọi một endpoint nào**: số điện thoại `0912345678` và
sáu ô OTP điền sẵn được ghi cứng trong `initState`, nút "Xác nhận" không gửi gì
đi. Nó là một mockup nối nhầm vào router, nên việc gỡ không làm mất một luồng
đang chạy nào.

**Ba thứ client GIỮ NGUYÊN, cố ý:** giá trị `'Banking'` trong enum loại ví (để
đọc hàng cũ mà server trả về), ba cột SQLite `provider` / `bank_tran_id` /
`bank_casso_id`, và phép loại ví `banking` ra khỏi việc tính lại số dư. Cả ba
bảo vệ **hàng cũ kéo về từ một tài khoản từng liên kết**, không bảo vệ một tính
năng đang sống.

**Không đổi lược đồ, không đổi hợp đồng payload đồng bộ.** Hai cột `provider` và
`bank_tran_id` vẫn **ngoài** hợp đồng như trước, và nay chúng không còn lý do
nào để được đưa vào — client sẽ không xin việc ấy nữa.

---

## 2. Backend có phải làm gì về mã không

**Không.** Client bỏ qua `bank_transaction.incoming` bằng đúng nhánh `null` sẵn
có cho mọi tên sự kiện không dịch được, nên máy chủ cứ phát như cũ cũng không
gây lỗi gì ở client. Ba endpoint `pending-transactions` / `confirm-transaction`
/ `reject-transaction` cứ để nguyên — chúng không còn người gọi từ app, chỉ vậy.

Nếu backend muốn tự gỡ module `bank/` cho gọn thì đó là quyết định của backend,
không phải yêu cầu từ client.

---

## 3. Bốn chỗ tài liệu cần sửa

Bốn tệp dưới đây do backend quản, nên client **không sửa thẳng** một dòng nào.
Chỗ cần sửa là **những câu mô tả phía client**, không phải những câu mô tả
backend — câu nào nói backend có gì thì vẫn đúng và nên giữ.

### 3.1. `docs/progress/Client-app.md` — nặng nhất

Cả tệp này đặc tả một tính năng client **không còn có**. Sáu chỗ đo được:

| Dòng | Nội dung hiện tại | Vấn đề |
|---|---|---|
| 41 | `wallet.id_bank_casso` — "Ví tạo từ liên kết ngân hàng" | Client không tạo ví loại ấy nữa; cột chỉ còn để đọc hàng cũ |
| 42 | `transaction.status` và `provider` liệt kê như dữ liệu client dùng | Hai cột ấy **chưa bao giờ** nằm trong hợp đồng đồng bộ, và nay sẽ không vào |
| 72 | "Hiển thị danh sách các giao dịch biến động số dư từ Casso đang ở trạng thái `Pending`" | Màn ấy chưa bao giờ được dựng, và nay sẽ không dựng |
| 101 | "Lắng nghe sự kiện `bank_transaction.incoming`" | Client **thôi dịch** sự kiện này từ 2026-09-18 |
| 282 | Bảng payload của `bank_transaction.incoming` kèm "tăng Badge đếm" | Không còn người nghe, không có badge nào |
| 303 | `GET /api/bank/accounts` trong bảng API client gọi | Client không gọi endpoint nào của module `bank/` |

**Đề nghị:** thêm một banner ở đầu tệp ghi rằng tính năng đã bỏ ngày 2026-09-18,
và đánh dấu sáu chỗ trên là ảnh chụp lịch sử. Giữ nguyên phần mô tả backend.

### 3.2. `docs/Rule_Project/Rule_project.md` — mục 8 và ba chỗ lẻ

| Dòng | Nội dung | Ghi chú |
|---|---|---|
| 342–344 | `'Banking'` do hệ thống tạo qua luồng liên kết ngân hàng | **Vẫn đúng với backend.** Chỉ cần thêm một câu rằng client không còn luồng ấy nhưng vẫn đọc được giá trị |
| 483–492 | Mục 8 "Quy tắc tích hợp ngân hàng (SePay)" | Mô tả backend, **giữ nguyên**; nên ghi thêm rằng app không còn giao diện cho nó |
| 666 | "Module Bank dùng mô hình SePay Cá Nhân an toàn, người dùng chỉ khai báo STK" | Câu này nói về **trải nghiệm người dùng trong app**, nay không còn màn nào để khai báo |

### 3.3. `docs/progress/Backend.md` — một chỗ

Dòng 75: *"Backend tự động bắn sự kiện realtime `bank_transaction.incoming` và
`notification.new` trực tiếp xuống điện thoại ngay khi…"* — phần backend phát
thì vẫn đúng; vế **"xuống điện thoại"** thì không, vì client đã thôi dịch tên
ấy. Phần còn lại của tệp mô tả backend và không cần đổi.

### 3.4. `docs/Bank/Client-app.md` — cả tệp

Tệp này là đặc tả *"Khai Báo Tài Khoản Ngân Hàng & Nhận Giao Dịch Realtime"*
dành riêng cho Flutter. Không còn hạng mục nào trong đó được thi công. Đề nghị
thêm banner "tính năng đã bỏ 2026-09-18" ở đầu tệp thay vì xoá, để lịch sử
quyết định còn đọc được. Hai tệp cùng thư mục — `docs/Bank/Backend.md` và
`docs/Bank/SePay.md` — mô tả backend nên **không cần đổi**.

---

## 4. Cách kiểm lại sau khi sửa

Chạy từ gốc repo. Kết quả mong đợi: mỗi tệp còn lại chỉ những dòng mô tả
**backend**, và mỗi tệp có một banner nói tính năng đã bỏ.

```bash
grep -niE "liên kết ngân hàng|sepay|casso|bank_transaction" \
  docs/progress/Client-app.md \
  docs/Rule_Project/Rule_project.md \
  docs/progress/Backend.md \
  docs/Bank/Client-app.md
```

Kiểm phía client đã gỡ sạch (chạy từ `src/Client-app`, phải ra **0** dòng):

```bash
grep -rn "bank-link\|BankLinkPage\|BankHeaderRow\|giaoDichNganHang" lib
```

Và bộ test của client có một ca quét `lib/` canh đúng điều đó:
`test/features/wallet/lien_ket_ngan_hang_da_bo_test.dart`.

---

## 5. Bối cảnh phía client, nếu cần đọc thêm

- Khối **"🏦 Gỡ phần client của liên kết ngân hàng"**, mục 14
  `docs/PROJECT_CONTEXT.md` — lý do, cái gì gỡ, cái gì giữ.
- Mục **G26** `docs/CLIENT_APP_KNOWN_GAPS.md` — lỗ hổng "chưa có màn duyệt giao
  dịch ngân hàng" nay đóng bằng quyết định sản phẩm, không phải bằng mã.
