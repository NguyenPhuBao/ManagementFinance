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

## 3. Năm chỗ tài liệu cần sửa

Năm tệp dưới đây do backend quản, nên client **không sửa thẳng** một dòng nào.
Chỗ cần sửa là **những câu mô tả phía client**, không phải những câu mô tả
backend — câu nào nói backend có gì thì vẫn đúng và nên giữ.

### 3.0. `Project.md` (gốc repo) — ba dòng giao việc cho Mobile

Tệp này có **59** dòng nhắc tới ngân hàng, và gần như tất cả mô tả backend nên
**giữ nguyên**. Chỗ sai là ba dòng trong hai bảng chức năng, vì chúng nói phần
việc ấy thuộc **Mobile**:

| Dòng | Bảng | Nội dung |
|---|---|---|
| 992 | A3 Wallet Management | `\| 4 \| Liên kết ngân hàng \| Backend + Mobile \| User \|` |
| 1072 | B12 Bank | `\| 1 \| Liên kết ngân hàng (OAuth Casso) \| Backend + Mobile \| User \|` |
| 1073 | B12 Bank | `\| 2 \| Quản lý liên kết ngân hàng (xem/hủy) \| Backend + Mobile \| User + Admin \|` |

Cả ba nên bỏ chữ `Mobile` (hoặc đánh dấu hạng mục đã huỷ). Ba dòng còn lại của
bảng B12 ghi `Backend` và **vẫn đúng**.

Hai chỗ nữa **thấp hơn về mức cấp bách** — chúng mô tả *nội dung của tài liệu
khác* chứ không giao việc, nên chỉ cần một câu ghi chú: dòng **2449** và
**2478** tóm tắt `docs/Bank/Client-app.md` là *"luồng liên kết ngân hàng qua
In-App WebView"* và *"màn hình `BankRegisterPage`"* — không màn nào trong đó
được thi công, và nay sẽ không.

### 3.1. `docs/progress/Client-app.md` — nặng nhất

Cả tệp này đặc tả một tính năng client **không còn có**. Đo bằng script ngày
2026-09-18: **19 dòng** — đếm theo mẫu rộng gồm cả `giao dịch ngân hàng`,
`api/bank`, `chờ duyệt` và `G26`, không chỉ bốn từ khoá của câu lệnh ở mục 4
(mẫu hẹp ấy chỉ ra **6** dòng, nên đừng lấy nó làm thước). Nặng nhất không phải
các dòng lẻ mà là **nguyên mục 3**.

**Mục 3 — "Module Bank & Quy Trình Duyệt Giao Dịch Ngân Hàng (Bank Inbox UI)",
dòng 62–77.** Nguyên mục này giao cho client dựng ba màn và gọi bốn endpoint:
danh sách thẻ ngân hàng (`GET /api/bank/accounts`), hộp thư giao dịch chờ duyệt
(`GET /api/bank/pending-transactions`), duyệt (`POST /api/bank/confirm-transaction`)
và từ chối (`POST /api/bank/reject-transaction`). **Không màn nào được dựng, và
nay sẽ không.** Đề nghị đánh dấu cả mục là đã huỷ thay vì sửa từng dòng.

Mười ba dòng còn lại:

| Dòng | Nội dung hiện tại | Vấn đề |
|---|---|---|
| 18, 20 | *"Phạm vi thật hẹp hơn tài liệu này mô tả — không có màn Giao dịch chờ duyệt"* | Blockquote client chèn năm 2026-09-09. Nay còn thiếu một vế: màn ấy **sẽ không bao giờ có** |
| 41 | `wallet.id_bank_casso` — "Ví tạo từ liên kết ngân hàng" | Client không tạo ví loại ấy nữa; cột chỉ còn để đọc hàng cũ |
| 42 | `transaction.status` và `provider` liệt kê như dữ liệu client dùng | Hai cột ấy **chưa bao giờ** nằm trong hợp đồng đồng bộ, và nay sẽ không vào |
| 91 | *"badge đếm giao dịch chờ duyệt (cần màn duyệt — G26)"* | G26 đóng bằng quyết định sản phẩm; badge ấy không còn là việc chờ |
| 101 | "Lắng nghe sự kiện `bank_transaction.incoming`" | Client **thôi dịch** sự kiện này từ 2026-09-18 |
| 282 | Bảng payload của `bank_transaction.incoming` kèm "tăng Badge đếm" | Không còn người nghe, không có badge nào |
| 303–306 | Bốn route `/api/bank/*` trong bảng "API client gọi" | Client **không gọi** endpoint nào của module `bank/` |
| 573, 574 | Bảng bảo mật: client gửi `Bearer` tới `/api/bank/*` | Không có lời gọi nào để bảo mật |

**Đề nghị:** thêm một banner ở đầu tệp ghi rằng tính năng đã bỏ ngày 2026-09-18,
đánh dấu **mục 3** là đã huỷ, và ghi chú mười ba dòng trên là ảnh chụp lịch sử.
Giữ nguyên phần mô tả backend.

### 3.2. `docs/Rule_Project/Rule_project.md` — mục 8 và ba chỗ lẻ

Tệp có 727 dòng; phần lớn mô tả **backend và CSDL** nên **giữ nguyên**. Ba chỗ
nói về trải nghiệm trong app:

| Dòng | Nội dung | Ghi chú |
|---|---|---|
| 342–344 | `'Banking'` do hệ thống tạo qua luồng liên kết ngân hàng, không nằm trong ô chọn | **Vẫn đúng với backend.** Chỉ cần thêm một câu rằng client không còn luồng ấy nhưng **vẫn đọc được** giá trị |
| 483–492 | Mục 8 "Quy tắc tích hợp ngân hàng (SePay)" | Mô tả backend, **giữ nguyên**; nên ghi thêm rằng app không còn giao diện cho nó |
| 666 | "Module Bank dùng mô hình SePay Cá Nhân an toàn, người dùng chỉ khai báo STK và tên ngân hàng" | Câu này nói về **trải nghiệm người dùng trong app**, nay không còn màn nào để khai báo |

Dòng 557 (ngắt kết nối tài khoản ngân hàng đặt `connect_status = 'Disconnected'`)
và 495 (không thu thập thông tin đăng nhập Internet Banking) là quy tắc backend
và **vẫn đúng**.

### 3.3. `docs/progress/Backend.md` — hai chỗ

| Dòng | Nội dung | Ghi chú |
|---|---|---|
| 60 | *"API dành riêng cho Client-app lấy danh sách toàn bộ giao dịch ngân hàng đang `Pending`"* | Endpoint vẫn chạy, nhưng **không còn Client-app nào gọi nó** |
| 75 | *"Backend tự động bắn sự kiện realtime `bank_transaction.incoming` … trực tiếp xuống điện thoại"* | Phần backend phát **vẫn đúng**; vế **"xuống điện thoại"** thì không — client đã thôi dịch tên ấy, nó rơi vào nhánh bỏ qua |

Dòng 497 (`sync.completed` kích hoạt client) **vẫn đúng** và không cần đổi.

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
grep -niE "liên kết ngân hàng|sepay|casso|bank_transaction|giao dịch ngân hàng|api/bank|chờ duyệt|G26" \
  Project.md \
  docs/progress/Client-app.md \
  docs/Rule_Project/Rule_project.md \
  docs/progress/Backend.md \
  docs/Bank/Client-app.md
```

⚠️ Dùng đúng mẫu rộng ở trên. Bỏ bốn từ khoá cuối thì `progress/Client-app.md`
chỉ ra **6** dòng thay vì **19**, và nguyên mục 3 — phần nặng nhất — không hiện
ra vì tiêu đề của nó không chứa chữ nào trong mẫu hẹp.

Riêng `Project.md`, câu kiểm gọn hơn là tìm chữ `Mobile` trong hai bảng chức
năng — phải ra **0** dòng có cả `Mobile` lẫn "ngân hàng":

```bash
grep -nE "ngân hàng.*Mobile|Mobile.*ngân hàng" Project.md
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
