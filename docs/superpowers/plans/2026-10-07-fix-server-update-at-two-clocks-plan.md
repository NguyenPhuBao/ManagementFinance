# Kế Hoạch Triển Khai: Khắc Phục Lệch Hai Đồng Hồ 7 Giờ Trong `Server_update_at` (Mục 40)

> **Dành cho Agentic Workers:** REQUIRED SUB-SKILL: Sử dụng `superpowers:subagent-driven-development` để triển khai kế hoạch này theo từng tác vụ. Các bước sử dụng cú pháp checkbox (`- [ ]`) để theo dõi tiến độ.

**Mục tiêu:** Đồng nhất 100% các luồng ghi vào cột `Server_update_at` trên 6 bảng đồng bộ (`category`, `wallet`, `budget`, `bill`, `goal`, `transaction`) về cùng một đồng hồ chuẩn UTC thông qua mệnh đề `(now() AT TIME ZONE 'UTC')`, loại bỏ triệt để hiện tượng lệch 7 giờ giữa trigger/default và Prisma ORM.

---

## 1. Phân Tích Kỹ Thuật & Nguyên Nhân Gốc Rễ

- **Kiểu dữ liệu:** 6 cột `Server_update_at` được tạo với kiểu `TIMESTAMP(6)` (tức `TIMESTAMP WITHOUT TIME ZONE`).
- **Cơ chế PostgreSQL:**
  - `CURRENT_TIMESTAMP` / `now()` trả về `TIMESTAMP WITH TIME ZONE`.
  - Khi gán vào cột `TIMESTAMP WITHOUT TIME ZONE` hoặc làm `DEFAULT CURRENT_TIMESTAMP`, PostgreSQL tự động chuyển đổi sang chuỗi thời gian của **múi giờ phiên** (`session TimeZone`, ví dụ `Asia/Bangkok` hoặc `Asia/Ho_Chi_Minh` = UTC+7) rồi cắt bỏ múi giờ. Kết quả: Bản ghi nhận giá trị giờ địa phương (e.g. `18:26:46`).
  - Trong khi đó, Prisma ORM và JavaScript `new Date()` luôn gửi thời gian dưới dạng chuỗi chuẩn UTC (e.g. `11:26:46Z`), được PostgreSQL ghi nguyên bản là `11:26:46`.
- **Hệ quả:**
  - Hàng INSERT qua Prisma có `Server_update_at` = UTC (`11:26:46`).
  - Hàng UPDATE qua Trigger (BEFORE UPDATE) bị trigger đè thành giờ địa phương (`18:26:46`), đi trước thời gian thực 7 tiếng.
  - Hàng sửa nằm "ở tương lai" 7 tiếng, khiến `/sync/pull` trả lặp lại liên tục, làm sai thứ tự `orderBy` và phá hỏng checkpoint `maxSince`.
- **Giải pháp tối ưu (Phương án a):**
  - Đổi Trigger `set_server_update_at()` thành: `NEW."Server_update_at" = (now() AT TIME ZONE 'UTC');`.
  - Đổi `DEFAULT` của cả 6 cột trên 6 bảng thành: `(now() AT TIME ZONE 'UTC')`.
  - Giữ nguyên cấu trúc `schema.prisma` và không ảnh hưởng đến bất kỳ hàm `now()` nào khác trong hệ thống.

---

## 2. Ràng Buộc Toàn Cục

- Tuân thủ **Rule 10 (DB Guard)**: CẤM chạy `prisma migrate dev` hay `prisma db push` trên Cloud Supabase. Mọi thay đổi DDL phải chạy qua file migration SQL độc lập và script kiểm soát kết nối an toàn.
- Tuân thủ **Rule 2 (RTK)**: Mọi lệnh terminal CLI bắt buộc dùng tiền tố `rtk`.
- Tuân thủ **Rule 9 (Data Security & Nghị định 13)**: Không làm mất bất kỳ partial index, foreign key, hay trigger bảo mật nào.

---

## 3. Danh Sách Tác Vụ Chi Tiết

### Tác Vụ 1: Viết File Migration DDL SQL 21 & Cập Nhật File 20
**Files:**
- Create: `src/Backend/database/21_fix_server_update_at_utc.sql`
- Modify: `src/Backend/database/20_add_server_update_at_sync_tables.sql`

- [ ] **Bước 1:** Viết file `database/21_fix_server_update_at_utc.sql`:
  - `CREATE OR REPLACE FUNCTION set_server_update_at()` trả về `(now() AT TIME ZONE 'UTC')`.
  - `ALTER TABLE ... ALTER COLUMN "Server_update_at" SET DEFAULT (now() AT TIME ZONE 'UTC')` cho 6 bảng.
  - Quét và sửa các bản ghi lệch tương lai (nếu có): `WHERE "Server_update_at" > (now() AT TIME ZONE 'UTC')`.
- [ ] **Bước 2:** Cập nhật file `database/20_add_server_update_at_sync_tables.sql` để các môi trường thiết lập từ đầu nhận ngay trigger và default UTC.

### Tác Vụ 2: Thực Thi Migration 21 Lên CSDL Cloud Supabase
**Files:**
- Create: `src/Backend/scripts/apply_migration_21.js`

- [ ] **Bước 1:** Viết script `apply_migration_21.js` kết nối `pg` Client an toàn, thực thi toàn bộ script trong 1 giao tác (`BEGIN ... COMMIT`).
- [ ] **Bước 2:** Chạy lệnh: `rtk node src/Backend/scripts/apply_migration_21.js`.
- [ ] **Bước 3:** Xác nhận kết quả thực thi exit code 0.

### Tác Vụ 3: Thẩm Tra Thực Tế Lệch Múi Giờ (Proof-of-Fix)
**Files:**
- Create: `src/Backend/scripts/verify_utc_clock.js`

- [ ] **Bước 1:** Giả lập phiên làm việc với `SET timezone = 'Asia/Bangkok'`.
- [ ] **Bước 2:** Thực hiện UPDATE trên bảng `wallet` trong transaction ROLLBACK, so sánh `Server_update_at` và `(now() AT TIME ZONE 'UTC')`.
  - Tiêu chí đạt: Độ lệch $\le 100$ mili-giây, không lệch 7 giờ.
- [ ] **Bước 3:** Thực hiện Prisma create và update, kiểm tra tính đồng nhất UTC.

### Tác Vụ 4: Bổ Sung Kiểm Thử Hồi Quy (Regression Test)
**Files:**
- Modify: `src/Backend/tests/v2/sync.engine.test.js`

- [ ] **Bước 1:** Bổ sung test suite xác thực tính toàn vẹn của `Server_update_at` và checkpoint `maxSince`.
- [ ] **Bước 2:** Chạy test suite: `rtk npm test`.
  - Tiêu chí đạt: 100% tests PASS.

### Tác Vụ 5: Lưu Trữ Tài Liệu, Cập Nhật Project.md & CodeGraph
**Files:**
- Move: `docs/superpowers/backend/CAN-LAM/SERVER_UPDATE_AT_HAI_DONG_HO.md` $\rightarrow$ `docs/superpowers/backend/DA-XONG/`
- Modify: `docs/superpowers/backend/CAN-LAM/README.md`
- Modify: `docs/superpowers/backend/DA-XONG/README.md`
- Modify: `Project.md`

- [ ] **Bước 1:** Di chuyển file và ghi chú giải pháp + trả lời câu hỏi mục 5 của Client-app (Client dùng 1 mốc `min(maxSince)` chung là an toàn và chuẩn xác).
- [ ] **Bước 2:** Cập nhật `CAN-LAM/README.md` và `DA-XONG/README.md`.
- [ ] **Bước 3:** Cập nhật `Project.md` mục 11.70.
- [ ] **Bước 4:** Chạy lệnh cập nhật chỉ mục CodeGraph: `rtk npx codegraph build`.
