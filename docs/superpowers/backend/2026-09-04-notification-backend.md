# Thông báo — phần việc phía backend

> **Viết ngày 2026-09-04**, sau khi client hoàn tất lát 1–4 và lát 7 của hệ
> thống thông báo. Đối chiếu với mã nguồn thật trong `src/Backend`, không chép
> lại từ tài liệu cũ.
>
> Tài liệu client: `docs/NOTIFICATION_FEATURE.md`.

---

## 0. Kết luận trước, để khỏi đọc nhầm mức khẩn

**Backend KHÔNG cần làm gì để tính năng thông báo của client chạy.**

Người dùng đã chốt: thông báo là **cục bộ trên từng máy**, không FCM, không
đồng bộ giữa thiết bị. Bảng `AppNotifications` chỉ tồn tại trong SQLite của
client và **cố ý không nằm trong `SyncEntityType`** — thông báo suy lại được
từ ngân sách/hoá đơn/mục tiêu nên chép nó qua mạng là công vô ích. Vì thế
schema PostgreSQL **không có** bảng `notification` nào, và điều đó là **đúng
thiết kế**, không phải thiếu sót.

Cái backend đang thiếu, liệt kê ở mục 2, chỉ chặn những thứ **chưa ai hứa với
người dùng**. Đừng xếp chúng lên trước chín bước trong [README.md](./README.md)
mục 0.

Ngoại lệ duy nhất đáng làm sớm là mục 2.1 — và nó **đã là bước 1** của danh
sách ấy vì lý do khác, không phải vì thông báo.

---

## 1. Đính chính một nhận định sai đang lưu hành

Bản bàn giao trước ghi rằng *"`bill.time_notification` nay được client ghi
nhưng **không nằm trong payload đẩy**"*. **Nhận định này sai.** Kiểm lại mã
nguồn thật ngày 2026-09-04:

| Chặng | Vị trí | Trạng thái |
|---|---|---|
| Client dựng payload đẩy | `sync_engine.dart:1089` — `'time_notification': bill.timeNotification` | ✅ có |
| Hợp đồng tên trường | `sync_payload_contract_test.dart:251` — `time_notification` nằm trong tập khoá của `bill` | ✅ có, và có test canh |
| Backend chuẩn hoá tên | `sync.repository.js:71` — `timeNotification` → `time_notification` | ✅ có |
| Backend ghi khi tạo | `sync.repository.js:385` — mặc định `'3'` | ✅ có |
| Backend ghi khi cập nhật | `sync.repository.js:406` — giữ giá trị cũ nếu thiếu | ✅ có |
| Client đọc lại khi pull | `sync_engine.dart:741` | ✅ có |
| Cột trong PostgreSQL | `schema.prisma:228` — `Time_notification VARCHAR(7) DEFAULT '3'` | ✅ có |

Cả sáu chặng đều đủ, hai chiều. **Không có việc gì phải làm ở đây.**

Ghi lại đính chính này thay vì lặng lẽ xoá, vì nhận định sai kia đã đi qua ít
nhất hai bản tài liệu và người đọc sau sẽ gặp lại nó. Đây cũng là minh hoạ cho
cảnh báo ở đầu `CLAUDE.md`: **tài liệu là ảnh chụp, không phải nguồn sự thật** —
mở mã ra đọc trước khi kết luận.

---

## 2. Ba khoảng trống thật

### 2.1 Socket.io không xác thực — đã là bước 1, không phải việc mới

`core/socket.js:11-31`: máy chủ không kiểm token ở bất kỳ đâu, và
`join_account` cho socket vào phòng `account_<id>` **theo con số client tự
khai**. Nghĩa là bất kỳ ai mở được cổng cũng nghe được thông báo của bất kỳ
tài khoản nào, chỉ cần đoán một số nguyên.

Ba hàm phát thông báo trong `modules/notification/notification.service.js`
(`emitBankTransaction`, `emitOcrCompleted`, `emitOcrDuplicate`) đều đi qua
đường này.

**Đây đã là bước 1 trong chín bước** vì `emitAuditActivity` đang rò tên người
dùng và hành động ra **mọi** socket ẩn danh ngay lúc này. Chi tiết đầy đủ:
mục 7 của [2026-09-04-ocr-classify-review.md](./CAN-LAM/2026-09-04-ocr-classify-review.md).

Liên quan gì tới thông báo: **client chưa nối socket, và cố ý chưa nối.**
Không có `socket_io_client` trong `pubspec.yaml`. Ba loại thông báo mà backend
phát được (giao dịch ngân hàng Casso, OCR xong, OCR trùng) vì thế **không có
trong tám `NotificationKind`** của client. Nối luồng ấy trước khi siết xác
thực là kéo một kênh đang rò thẳng vào app người dùng.

> Nhớ sửa `Admin-web/src/hooks/useSocket.js` **cùng lúc** — consumer hiện kết
> nối không kèm token, siết một đầu là gãy đầu kia.

### 2.2 Không có scheduler dưới bất kỳ hình thức nào

Không `node-cron`, không `agenda`, không repeatable job của BullMQ. `package.json`
chỉ có `bullmq` cho hàng đợi theo sự kiện.

Hệ quả: backend **không thể tự phát hiện** "hoá đơn đến hạn ngày mai" hay
"ngân sách vừa vượt". Mọi thông báo hiện có đều là **phản ứng** với một sự
kiện vừa xảy ra trong cùng tiến trình.

Điều này **không chặn gì hôm nay**: client tự quét cục bộ sau mỗi lần đồng bộ
và tự đặt lịch với hệ điều hành, nên nhắc hoá đơn vẫn nổ đúng lúc kể cả khi
app đóng và kể cả khi máy chủ tắt.

Chỉ cần scheduler nếu sau này muốn: nhắc qua email/SMS, hoặc nhắc tới một máy
người dùng **không** mở app lần nào trong kỳ. Cả hai đều chưa ai hứa.

### 2.3 Hàng đợi `send-notification` khai báo rồi bỏ đó

Ba thứ cùng rỗng:

| Thứ | Vị trí | Tình trạng |
|---|---|---|
| Hàng đợi | `core/queue.js:14` | Đã khai báo `new Queue('send-notification')` |
| Người đẩy việc vào | — | **Không có.** `grep sendNotification` chỉ ra đúng dòng khai báo |
| Worker | `workers/notification.worker.js` | **0 byte** |

Và kể cả có viết worker thì nó cũng **không chạy**: `index.js` chỉ
`require('./workers/ai.worker')` và `require('./workers/bank.worker')` —
`notification.worker` không được nạp ở đâu cả.

Cùng loại rỗng: `modules/notification/notification.controller.js`,
`.jobs.js`, `.validation.js` đều 0 byte, và `api/notification.routes.js` chỉ
có `// TODO`, nhưng vẫn được mount vào `/api/notifications`
(`api/index.js:43`) — nghĩa là mọi đường dẫn dưới tiền tố đó trả 404. Client
không gọi cái nào, nên hiện vô hại.

**Đừng viết worker cho tới khi có việc thật để nó làm.** Một worker rỗng được
nạp vào sẽ mở kết nối Redis và chiếm một chỗ trong danh sách tiến trình mà
không đổi lấy gì. Việc thật đầu tiên gần như chắc chắn là 2.2.

---

## 3. Nếu sau này muốn thông báo do server phát

Ghi trước để khỏi phải nghĩ lại. Thứ tự bắt buộc:

1. **Siết xác thực Socket.io** (2.1) — trước tất cả. Kênh còn rò thì mọi thứ
   xây lên trên đều rò theo.
2. **Chọn scheduler.** BullMQ repeatable job là lựa chọn rẻ nhất vì hạ tầng đã
   có; không cần thêm phụ thuộc.
3. **Quyết định nơi khử trùng.** Client đã có `dedupeKey` với ràng buộc
   `UNIQUE(idaccount, dedupeKey)` ở SQLite. Nếu server cũng phát, hai bên sẽ
   sinh **hai** thông báo cho cùng một sự kiện trừ khi server dùng **đúng công
   thức khoá ấy** và client coi thông báo từ server như một ứng viên bình
   thường đi qua `insertOrIgnore`. Công thức khoá nằm ở mục 4.2
   `docs/NOTIFICATION_FEATURE.md` — **chép đúng, đừng phát minh lại**.
4. **Bảng lưu ở PostgreSQL** — chỉ khi đã quyết đồng bộ giữa thiết bị. Quyết
   định hiện tại là **không**, và việc thêm bảng sẽ kéo theo bảy bảng ánh xạ
   song song trong `mapEntityFields`.

---

## 4. Không phải việc của backend

Liệt kê để người đọc sau khỏi mở nhầm vé:

- **Quyền thông báo Android/iOS** — hoàn toàn phía client, xin trong trang
  `/settings/notifications`.
- **Giờ nhắc trong ngày, số ngày nhắc mặc định, bốn công tắc nhóm** — lưu
  trong `FlutterSecureStorage` **trên máy**, theo từng `idaccount`. Cố ý không
  đồng bộ: chúng là tuỳ chọn của **thiết bị** ("máy này đừng kêu"), không phải
  của tài khoản.
- **Lịch nhắc hoá đơn** — nằm trong AlarmManager / UNUserNotificationCenter,
  không phải trong CSDL nào.
