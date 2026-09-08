# Backend — mục lục

**Cập nhật 2026-09-08.** Tệp này chỉ nói *cái gì nằm ở đâu*. Trạng thái và thứ
tự thi công nằm trong README của từng thư mục con — **cố ý không lặp lại ở đây**,
vì trước đó cùng một bảng trạng thái tồn tại ở hai nơi và chúng lệch nhau.

---

## Đi đâu

| Bạn cần gì | Mở cái này |
|---|---|
| **Việc backend còn phải làm** | 👉 [`CAN-LAM/README.md`](./CAN-LAM/README.md) — **cửa vào duy nhất**. Đếm theo **mục 2** của chính tệp ấy, đừng đếm ở đây: bảng này từng ghi "bốn" trong khi mục 2 đã có sáu |
| Lý lẽ đằng sau một quyết định đã đi vào lược đồ | [`DA-XONG/README.md`](./DA-XONG/README.md) — 16 tài liệu đã đóng, kèm ghi chú *đóng bằng cách nào* |
| Client-app còn nợ gì | `docs/CLIENT_APP_KNOWN_GAPS.md` |
| Bức tranh toàn cục | Mục 14 `docs/PROJECT_CONTEXT.md` |

---

## Bốn tệp bối cảnh, nằm ngay thư mục này

Không phải việc cần làm, nhưng cần để hiểu hai thư mục con:

| Tệp | Nội dung |
|---|---|
| [New_Database.md](./New_Database.md) | Lược đồ chuẩn của PostgreSQL. `CLAUDE.md` chỉ định đây là **nguồn sự thật** cho schema |
| [2026-08-10-backend-sync-spec.md](./2026-08-10-backend-sync-spec.md) | Hợp đồng `/sync/push` và `/sync/pull` |
| [PROGRESS-BACKEND.md](./PROGRESS-BACKEND.md) | Checklist B1→B7 và tiến độ backend |
| [TRANSACTION_NOTE_ENCODING.md](./TRANSACTION_NOTE_ENCODING.md) | Client mã hoá chiều tiền và nguồn gốc của khoản tích luỹ vào `transaction.Note`. **Không xin gì** — chỉ để backend biết mà đừng vô tình phá |

---

## Ba điều dễ vấp nhất khi đọc cả thư mục

1. **Tài liệu là ảnh chụp, không phải nguồn sự thật.** Trước khi dựa vào bất kỳ
   dòng nào, mở `src/Backend/prisma/schema.prisma` hoặc truy vấn thẳng
   PostgreSQL. Đợt 2026-09-07 cho thấy điều ngược lại cũng đúng: bảng trạng thái
   nói "chưa làm" trong khi backend đã làm xong bốn mục.

2. **Backend lệch tên cột giữa các bảng**, ít nhất ba kiểu: `category` dùng
   `Delete_at`, `transaction` dùng `Deleted_at`, và cột ngày của giao dịch là
   `DateTransaction` (không gạch dưới). Đừng suy tên từ bảng này sang bảng kia.
   Sai tên cột ở PostgreSQL thì báo lỗi ngay, nhưng sai trong payload đồng bộ thì
   **im lặng**.

3. **"Đã xong" ở đây luôn nói về phía backend.** Một cột có mặt trong CSDL không
   có nghĩa client đã dùng nó — `goal.Priority` và `transaction.Idgoal` là hai ví
   dụ đang mở.

---

## Ranh giới trách nhiệm

Client-app **không sửa `src/Backend`** (quy tắc 1 của `CLAUDE.md`). Mọi việc cần
backend đều được viết thành tài liệu ở đây thay vì sửa thẳng. Nếu một mục đọc
thấy vô lý hoặc tốn hơn dự kiến, hãy ghi lý do vào chính tài liệu ấy — client sẽ
đọc và tìm đường vòng ở phía mình.

Đọc mã trong `src/Backend` thì **được phép và rất nên**: hai lần trong tháng 9,
việc tưởng phải chờ backend hoá ra thuần client, và chỉ lộ ra khi mở mã ra đọc.
