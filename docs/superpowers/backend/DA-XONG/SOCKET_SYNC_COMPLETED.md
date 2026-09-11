# `sync.completed` đã có trên EventBus nhưng chưa ai bắc ra socket

> **Xin thêm một listener.** Không đổi API, không đổi lược đồ, không đổi hợp
> đồng đồng bộ, không cần migration. Chi phí: một khối `eventBus.subscribe`
> theo đúng khuôn ba khối đang có, cộng một hàm `emit` bốn dòng.

**Ngày:** 2026-09-09 · **Người xin:** phía client · **Liên quan:** mục 4 và 8
`docs/progress/Client-app.md`, và spec
`docs/superpowers/specs/2026-09-09-socket-io-realtime-channel-design.md`

---

## 1. Triệu chứng

Người dùng sửa dữ liệu trên máy A. Máy B **không biết gì** cho tới khi một
trong ba việc xảy ra: hết chu kỳ đồng bộ nền **15 phút**, người dùng tự ghi
một thay đổi nào đó trên máy B, hoặc họ mở lại app.

Với một ứng dụng offline-first có đồng bộ hai chiều, mười lăm phút là quãng
thời gian đủ để hai máy nói hai câu khác nhau về cùng một số dư. Không có lỗi
nào báo ra — chỉ là dữ liệu cũ, và người dùng không có cách nào biết nó cũ.

Client **vừa nối Socket.io xong** (2026-09-09) nên hạ tầng để chữa việc này đã
sẵn sàng ở phía client: kênh giữ kết nối, xác thực JWT, tự nối lại, và mọi sự
kiện nhận được đều gọi `syncNow()` ngay. Nhưng **không có sự kiện nào để nghe**
cho trường hợp này.

## 2. Nguyên nhân, đo được ngày 2026-09-09

Backend **đã phát** sự kiện ấy — chỉ là phát vào EventBus nội bộ chứ không ra
socket.

`src/Backend/modules/sync/sync.service.js:194`:

```js
await eventBus.publish('sync.completed', { idaccount, summary, timestamp: new Date().toISOString() });
```

Còn `src/Backend/modules/notification/notification.service.js` đăng ký **ba**
listener — `bank_transaction.pending`, `ocr.completed`, `ocr.duplicate` — và
không có cái thứ tư cho `sync.completed`.

`src/Backend/core/socket.js` cũng chỉ lộ ba hàm phát tương ứng
(`emitBankTransaction`, `emitOcrCompleted`, `emitOcrDuplicate`) cộng
`emitAuditActivity` dành cho `admin_room`.

Nói cách khác: sự kiện có thật, room có sẵn (`account_<idaccount>`, đã do
middleware bắt tay tự cho vào), client đã nối. Chỉ thiếu một đoạn nối giữa hai
thứ đã tồn tại.

## 3. Việc xin backend làm

**Một hàm phát mới** trong `core/socket.js`, đúng khuôn `emitOcrCompleted`:

```js
function emitSyncCompleted(idaccount, data) {
  if (!io) {
    logger.warn('[Socket] Attempted to emit sync completed before Socket.io initialized');
    return;
  }
  try {
    io.to(`account_${idaccount}`).emit('sync.completed', data);
  } catch (error) {
    logger.error('[Socket] Failed to emit sync completed', { error: error.message });
  }
}
```

**Một listener** trong `notification.service.js`, đặt cạnh ba cái đang có:

```js
await eventBus.subscribe('sync.completed', async (data) => {
  emitSyncCompleted(data.idaccount, {
    type: 'SyncCompleted',
    createdAt: new Date().toISOString(),
  });
});
```

⚠️ **Một ràng buộc duy nhất, và nó quan trọng:** sự kiện phải tới **mọi** máy
trong room, kể cả chính máy vừa đẩy dữ liệu lên. Máy ấy tự bỏ qua được (nó vừa
đồng bộ xong nên `SyncEngine` sẽ không làm gì thêm), còn việc lọc ra thì backend
không làm nổi — nó không biết socket nào thuộc thiết bị nào.

## 4. Client sẽ dùng nó thế nào

**Không đọc trường nào trong payload.** Client chỉ dùng **tên sự kiện** rồi gọi
`syncNow()`. Đây là quyết định có chủ ý, ghi ở mục 4 của spec: sự kiện
`bank_transaction.incoming` hiện được phát từ hai chỗ với hai hình dạng payload
khác nhau, nên client chọn không phụ thuộc vào hình dạng payload nào cả.

Nghĩa là backend **được tự do** đặt payload thế nào cũng được — kể cả rỗng — mà
không làm vỡ client, và cũng không cần báo trước khi đổi.

Việc thêm ở phía client là **một dòng** trong bảng ánh xạ ở
`lib/core/realtime/realtime_event.dart`. Chúng tôi cố ý **chưa** viết sẵn dòng
ấy: một nhánh mã không bao giờ chạy tới thì không kiểm chứng được, và tệ hơn là
không có gì.

## 5. Vì sao đáng làm trước những mục còn lại

Đây là mục **duy nhất** trong `CAN-LAM/` biến một hạng mục đã xong về hạ tầng
thành một thứ người dùng cảm nhận được. Năm mục còn lại đều là cột hoặc hành vi
lẻ; mục này là chênh lệch giữa **15 phút** và **tức thì** cho mọi thay đổi trên
mọi thiết bị.
