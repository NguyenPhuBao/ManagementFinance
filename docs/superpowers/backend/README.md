# Backend — mục lục

**Cập nhật 2026-09-08.** Tệp này chỉ nói *cái gì nằm ở đâu*. Trạng thái và thứ
tự thi công nằm trong README của từng thư mục con — **cố ý không lặp lại ở đây**,
vì trước đó cùng một bảng trạng thái tồn tại ở hai nơi và chúng lệch nhau.

---

## Đi đâu

| Bạn cần gì | Mở cái này |
|---|---|
| **Việc backend còn phải làm** | 👉 [`CAN-LAM/README.md`](./CAN-LAM/README.md) — **cửa vào duy nhất**. Đếm theo **mục 2** của chính tệp ấy, đừng đếm ở đây: bảng này từng ghi "bốn" trong khi mục 2 đã có sáu |
| Lý lẽ đằng sau một quyết định đã đi vào lược đồ | [`DA-XONG/README.md`](./DA-XONG/README.md) — **38** tài liệu đã đóng (đếm bằng máy 2026-09-22, sau khi hai tệp Edge AI đóng ở `b147fee`; mốc **31** là của 2026-09-11 và dòng này từng ghi "16" trước khi backend chuyển mười lăm tệp sang — **đừng cộng dồn, hãy đếm lại**), kèm ghi chú *đóng bằng cách nào* |
| Client-app còn nợ gì | `docs/CLIENT_APP_KNOWN_GAPS.md` |
| Bức tranh toàn cục | Mục 14 `docs/PROJECT_CONTEXT.md` |

---

## Năm tệp bối cảnh, nằm ngay thư mục này

Không phải việc cần làm, nhưng cần để hiểu hai thư mục con. *(Đếm lại bằng máy
2026-09-22: đúng **năm** tệp `.md` nằm ngay thư mục này ngoài mục lục. ⚠️ Bảng
dưới đây từng liệt kê năm dòng mà **thành phần sai** — nó kể cả
`New_Database.md`, thứ đã chuyển sang `docs/Rule_Project/` từ 2026-09-10, và
**bỏ sót** `AI_EDGE_SLM_DANH_GIA_AP_DUNG.md` thêm ngày 2026-09-18. Con số đúng
không có nghĩa là danh sách đúng.)*

| Tệp | Nội dung |
|---|---|
| [New_Database.md](../../Rule_Project/New_Database.md) | Lược đồ chuẩn của PostgreSQL (đã chuyển vào `docs/Rule_Project/` ở nhánh `main`, 2026-09-10). Đây là **nguồn sự thật** cho schema |
| [2026-08-10-backend-sync-spec.md](./2026-08-10-backend-sync-spec.md) | Hợp đồng `/sync/push` và `/sync/pull` |
| [PROGRESS-BACKEND.md](./PROGRESS-BACKEND.md) | Checklist B1→B7 và tiến độ backend |
| [TRANSACTION_NOTE_ENCODING.md](./TRANSACTION_NOTE_ENCODING.md) | Client mã hoá chiều tiền và nguồn gốc của khoản tích luỹ vào `transaction.Note`. **Không xin gì** — chỉ để backend biết mà đừng vô tình phá |
| [AI_ARCHITECTURE_REVIEW.md](./AI_ARCHITECTURE_REVIEW.md) | Đối chiếu sơ đồ "Kiến trúc AI phân tầng hybrid" với mã thật (2026-09-17): cái gì đã chạy, cái gì chưa, sáu chỗ sơ đồ nói ngược mã, so sánh ưu/nhược hai lối, hai phương án đi tiếp và ba quyết định cần chốt. **Không xin gì** — tài liệu để hai phía thảo luận. ⚠️ Bảng "Khối 2" của nó là kế hoạch ngày 2026-09-17 và đã lệch hiện trạng ở bốn chỗ — có banner đính chính tại chỗ |
| [AI_EDGE_SLM_DANH_GIA_AP_DUNG.md](./AI_EDGE_SLM_DANH_GIA_AP_DUNG.md) | Đánh giá áp dụng đặc tả `docs/AI/AI_Edge-SLM.md/Client-app.md` vào Client-app (2026-09-18): 39 luật A–H cái nào dùng được, cái nào phải sửa, và vì sao ba bảng SQLite đặc tả đòi chỉ cần **một**. **Không xin gì** — chỗ xin nằm ở `CAN-LAM/`. Backend đã sửa đặc tả theo đúng kết luận ấy ở `b147fee` (2026-09-22) |

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
