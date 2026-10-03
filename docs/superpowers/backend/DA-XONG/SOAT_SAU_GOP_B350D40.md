# Soát sau gộp `main` @ `47c9bde` (commit gộp client `b350d40`): tài liệu thông báo mới, hai lỗi FHS, tài liệu AI tả client cũ

**Ngày:** 2026-09-30 · **Phía gửi:** Client-app · **Loại:** đơn xin (sửa tài liệu + **hai lỗi mã** ở snapshot chatbot).

Ba commit của NPBao gộp vào nhánh client ngày 2026-09-30, **không xung đột**, **không đụng `src/Client-app`**:

- `e2621da`: audit, làm mới hội thoại AI.
- `e497695`: chatbot. Đóng đơn `CHATBOT_AI_CON_LECH_SAU_8BBDD97.md`, đơn này nay ở `DA-XONG/`.
- `8c677ab`: chống quá tải, trung tâm thông báo, và tài liệu `docs/Notification/*`.

Client đã soát bằng mã, số dòng tính tại HEAD sau gộp. Đơn này **không** xin backend dựng tính năng mới cho client.

## 0. Kết luận nhanh

| # | Việc | Mức |
|---|---|---|
| 1 | `docs/Notification/Notification_Client-app.md`: hợp đồng payload của **cả ba** sự kiện socket lệch mã backend; một sự kiện **không có chỗ phát** | cao (tài liệu giao việc làm theo là hỏng) |
| 2 | Kéo bù `GET /api/notifications` trả cả thông báo **ngân hàng** kèm `accountNumber`, `amount` (tính năng đã bỏ 2026-09-18) | cao (dữ liệu nhạy cảm) |
| 3 | FHS: chỉ số nợ trên thu nhập **gần như luôn 0** vì lọc `classify === 'Chi'` | **lỗi mã** |
| 4 | FHS: `trendVsLastMonth` **luôn `'0%'`**, tài liệu hứa *"+15%"* | **lỗi mã** + tài liệu |
| 5 | Tài liệu tả client sai / cũ (SMS, v24, 7 tool, `Category.Keyword`, SyncQueue…) | thấp — chỉ sửa chữ |
| 6 | `CAN-LAM/README.md` mục 0 ghi *"hoàn toàn sạch"* trong khi thư mục có đơn | thấp |

Client đã chọn nhận **một** việc của tài liệu thông báo: **số đếm trên chuông** (thuần client). Phần socket / REST / kéo bù
**chưa nhận**, vì vướng mục 1–2 và vì hai quy ước đã chốt của client. Thứ nhất, bảng `AppNotifications` là **cục bộ**,
suy ra được trên từng máy, không đi đồng bộ. Thứ hai, payload socket là **hộp đen**: client chỉ đọc tên sự kiện, ngoại lệ
duy nhất là `account.force_logout`. Muốn client đổi hai quy ước ấy thì cần một đơn trao đổi riêng sau khi mục 1–2 xong.

## 1. `Notification_Client-app.md`: payload lệch mã backend

| Sự kiện | Tài liệu nói (dòng) | Mã phát thật |
|---|---|---|
| `account.countdown` | `daysLeft`, `expireAt`, `message` (:123, :136, :302-310) | `core/scheduler.service.js:184-190` publish `{idaccount, username, daysRemaining, title, message}`; `notification.service.js:202` phát nguyên gói, không có vỏ `{event, data}`. Không `daysLeft` / `expireAt`. Gói mang cả `username`. Chỉ phát khi bộ đếm giảm hằng ngày, không phát lúc gửi yêu cầu xoá |
| `system.broadcast` | `id, title, content, level (info\|warning\|critical), broadcastAt` (:137, :313-324) | `notification.service.js:217-238` + `store.js:231-241`: `{id, title, message, level, category:'BROADCAST', metadata, isRead, readAt, createdAt}` — là `message` chứ không `content`, là `createdAt` chứ không `broadcastAt`; `level` mặc định `'INFO'` **in hoa** và lưu nguyên (`validation.js:44`, `controller.js:157`) |
| `user.notification` | `id, title, message, type, createdAt`; ví dụ `severity`, `read`, `type:"securityAlert"` (:138, :327-340) | **Không có chỗ phát.** Chỉ `sendDirectNotification` phát (`notification.service.js:245-257`), gọi qua `notifyUser` (:280-281), mà `notifyUser` **0 chỗ gọi** ngoài test. Gói (nếu phát) không có `severity` / `read`. Câu *"Phát hiện đăng nhập mới từ thiết bị lạ"* không có mã sinh ra |

Đề nghị: sửa §4 tài liệu theo đúng khoá mã phát, **hoặc** sửa mã theo tài liệu, nhưng hai bên phải khớp. Hoặc ghi rõ
`user.notification` chưa có nguồn phát.

Lỗi phụ cùng vùng: khi Redis sẵn sàng, `EventBus.subscribe` gắn handler **hai** lần — một ở `localBus.on`, một ở
`sub.on('message')` (`core/event-bus.js:47`, `:54-58`) — trong khi `publish` đi cả hai đường. Nên mỗi sự kiện có thể
`addNotification` **hai lần** với hai `id` khác nhau (xin backend kiểm).

## 2. Kéo bù `GET /api/notifications`: không giữ đúng lời hứa, và kéo cả thông báo ngân hàng

- *"Luôn đầy đủ thông báo ngay cả khi … offline dài ngày"* (:264) không đúng với chính backend:
  - kho chỉ giữ **50 mục / tài khoản, TTL 30 ngày** (`notification.store.js:18-19`);
  - không có Redis thì kho nằm **trong bộ nhớ tiến trình** (`:21-23`, `:70-80`), restart là mất;
  - broadcast vào kho **admin** (`notification.service.js:228-229`), nên `GET /api/notifications` của người dùng
    **không bao giờ trả broadcast**.
- Kho người dùng còn chứa **`BankTransactionPending`**. `notification.service.js:73-78` lưu `metadata: data`, trong
  `data` có `accountNumber` và `amount` (:55-64). Kéo bù sẽ đưa thông báo **ngân hàng** — tính năng nhóm đã bỏ ngày
  2026-09-18 — xuống máy kèm số tài khoản. Điều này trái chính §6 điều 1 của tài liệu (:375, *"không lưu dữ liệu nhạy
  cảm"*). Đề nghị: không lưu `metadata` thô cho loại này, hoặc không đưa loại ngân hàng vào kho người dùng.

## 3. Lỗi mã: chỉ số nợ trên thu nhập gần như luôn 0

`financial.snapshot.service.js:298` lọc chi bằng `t.category?.classify === 'Chi'`, rồi đưa tập ấy vào
`calculateDebtToIncomeRatio` (:349). Nhưng danh mục *Đi vay / Cho vay* mang classify **`'Vay/no'`** — CHECK
`ck_category_classify IN ('Thu','Chi','Vay/no')` (`database/New_Database.sql:111`). Vì vậy khoản trả nợ **không bao
giờ** được đếm, và thành phần nợ của FHS gần như luôn được trọn điểm.

Bộ test không bắt được, vì hai lẽ:
- fixture gán classify `'Thu'` cho *"Đi vay" / "Thu nợ"* (`tests/unit/financial.snapshot.test.js:16-18`), khác CSDL thật;
- ca DTI (:104-121) gọi thẳng hàm tính, bỏ qua bộ lọc ở :298.

Chữ đi kèm cũng lệch:
- `ChatbotAI.md:361`, `:400` còn `"hasHighInterestDebt": false`;
- `Project.md:2828` nói *"lãi suất thực tế trong CSDL"*, nhưng CSDL không có cột lãi suất; mã chỉ so từ `'lãi'` trong tên
  danh mục;
- `:53` có vế `tx.type === 'Thu'` là **nhánh chết**, vì `type` chỉ nhận `Transaction` / `Transfer`.

**Kiểm lại:**
```bash
grep -n "classify === 'Chi'" src/Backend/modules/ai/features/chatbot/snapshot/financial.snapshot.service.js   # phải xét cả 'Vay/no'
grep -n "classify" src/Backend/tests/unit/financial.snapshot.test.js                                         # fixture phải dùng 'Vay/no'
```

## 4. Lỗi mã: `trendVsLastMonth` luôn `'0%'`

Hằng số nằm ở `financial.snapshot.service.js:330`. Trong khi đó `ChatbotAI.md:180-182`, `:198` và
`ChatbotAI_Moblie.md:98` hứa *"+15%"*, *"tăng 15%"*. Mô hình được đưa một con số giả nói *"chi tiêu không đổi"*. Đề
nghị tính thật (khoản chi lưu **âm** trên PostgreSQL — dùng `Math.abs` như `eceb6c9`), hoặc bỏ trường khỏi snapshot.

## 5. Câu tả Client-app sai / cũ (chỉ sửa chữ)

| Chỗ | Đang ghi | Sự thật phía client (2026-09-30) |
|---|---|---|
| `LogicBusinessAI.md:32`, `:77`; `ORC.md:73`; `Project.md` ~1611, ~2723 | client đọc **SMS** + thông báo app; chức năng 3 *"⬜ Chưa làm tại Client"* | D1 **xong 2026-09-30**: chỉ đọc **thông báo app** của MB Bank · MoMo · ZaloPay, **không** SMS — đơn `D1_DOC_BIEN_DONG_XONG_SOAT.md` |
| `LogicBusinessAI.md:30`, `:75`; `Classify.md:30` | *"Drift SQLite v24"* | `schemaVersion` **27** |
| `LogicBusinessAI.md:33`, `:39`, `:86`; `ChatbotAI_Moblie.md:13` | *"7 tool chỉ đọc"* | **9** tool (`bo_cong_cu.dart`); mô hình trên máy còn phục vụ ô *Nhập nhanh* của màn Thêm giao dịch |
| `LogicBusinessAI.md:47` | *"T1 + T2 tại Client … Confidence < 0.60 → gửi Backend"* | client **không** có ngưỡng nào gửi backend; **không** gọi `/api/ai/classify/*` (grep 0). Thứ tự đoán danh mục trên máy: tên → B1 (Naive Bayes cục bộ) → từ khoá → mô hình trên máy. Cùng tệp :20 và `Project.md:1660`, `:2764` xếp *"Tầng 2 NLP"* vào client — ngược chính câu *"Tầng 2 không đưa lên client"* ở :30 |
| `LogicBusinessAI.md:36` | *"Client-app chỉ gọi API hiển thị"* FHS | client **không** gọi API FHS |
| `ORC.md` §7.2 | *"Offline Keyword Matcher … cột `Category.Keyword`"* | từ khoá ở bảng riêng `CategoryKeywords` |
| `ORC.md` §6, §7.1–7.2 | lưu `Provider='ORC'`, `Bank_tran_id` `_grp_`, `Status`, `Images`; *"cập nhật lại số dư ví"*, *"SyncQueue"* | payload giao dịch **13 trường**, không có bốn trường ấy (chống trùng `_grp_` sẽ không tới server nếu chưa mở hợp đồng); số dư ví **suy từ sổ giao dịch**; không có bảng SyncQueue. OCR phía client chưa làm (C4) — cần chốt hợp đồng khi tới lượt |
| `Project.md` ~1085 (bảng B10) | *"`bank_transaction.pending` · Backend + Mobile"* | client **thôi dịch** sự kiện ngân hàng từ 2026-09-18 |
| `Notification_Client-app.md` | *"19 loại / 5 nhóm"* (:40-41); `dao.markAsRead` (:241), `insertServerNotification` (:257), `notification_visuals.dart` (:352), `pending_delete_banner.dart` (:280), route `/profile/account-security` (:291); mã mẫu `_dio.get('/api/notifications')` (:153-171); *"chấm đỏ tĩnh"* (:65) | **20 loại / 6 nhóm**; hàm thật `markRead`, hai hàm/tệp kia không tồn tại; banner chờ xoá **đã có** (`TheChoXoaTrangChu`, số ngày từ `/auth/profile`); route không tồn tại; `DioClient` chỉ lộ `.dio`, và `baseUrl` đã có `/api` nên đường dẫn thành `/api/api/…` (404), dữ liệu nằm trong `data`; chấm đỏ suy từ số chưa đọc và ẩn khi 0 |
| `Project.md` :121, :1644 (2.5); :1642, :2391, :2728, :2754 (2.0) | tên mô hình Gemini cũ | mã: `process.env.GEMINI_MODEL \|\| 'gemini-3.8-flash'` |
| `ChatbotAI_Moblie.md` §4 (:190-191) | mã mẫu `onDone()` không đọc payload | nói ngược §2.1 (`done.fallback`); nhánh `done:{error}` (service:234-235), `event: error` (controller:59) chưa được tả; `POST /chat` (controller:100-107) làm rơi cờ `fallback` |

## 6. `CAN-LAM/README.md`

Mục 0 ghi *"26/26 … hoàn toàn sạch sẽ"* (`e497695`). `ls` ngày 2026-09-30 cho **bốn** đơn của client ngoài README:
`CLIENT_DOC_BIEN_DONG_THEM_VI_DIEN_TU.md`, `SEED_TU_KHOA_GRAB.md`, `D1_DOC_BIEN_DONG_XONG_SOAT.md` và đơn này.

## 7. Không phải việc — ghi nhận

- Các middleware chống quá tải (`app.js:38-58`) **không** ảnh hưởng đồng bộ của client, đã đọc mã:
  - `/sync/pull` là GET không có `x-retry-count`, nên được miễn;
  - thân `/sync/push` mang `pushedAt` tới mili giây, nên chữ ký retry guard không bao giờ trùng;
  - 503 khi quá tải hoặc bảo trì chỉ làm lượt đẩy thử lại ở chu kỳ sau.
- Client chưa đọc `Retry-After` — không cần xin gì.
