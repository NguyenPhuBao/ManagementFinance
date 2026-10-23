# Mục 49 — Soát sau khi client gộp `main` @ `ee6a65e5` (PR #153–#158) — tài liệu lệch mã, migration trùng số, thứ tự áp

> **Client đặt 2026-10-23.** Người nhận: backend (NPBao). Mức chung: **vừa** — không có chỗ nào làm hỏng app đang chạy trên
> backend đã áp đủ migration; các chỗ dưới đây là **tài liệu sai** (ai làm theo sẽ gây hỏng thật), **migration trùng số**, và
> **một bẫy thứ tự** trên máy dev.
>
> Client đã soát bằng **mã của cả hai phía** (đọc tệp, `grep`), chưa chạy backend sau lượt gộp. Mỗi mục có câu lệnh để kiểm
> lại. Client **không** đổi mã vì đơn này.
>
> **Đã đạt, không xin gì:** `/sync/push` và `/sync/pull` vẫn khớp hợp đồng của client
> (`src/Client-app/test/core/sync/sync_payload_contract_test.dart`) — các nhánh ánh xạ mới trong `mapEntityFields` đều là tên
> client không gửi; thứ tự xử lý mới (goal 30 < bill 31 < budget 32 < transaction 40) vẫn giữ goal và bill trước giao dịch;
> body 401 (`code`, `idaccount`, `reason_inactive` ở gốc), `/auth/refresh`, lời từ chối bắt tay socket không đổi; 503
> `MAINTENANCE_MODE` vẫn có `code` + `Retry-After` (`maintenance.middleware.js:36,42`); header `x-device-name` là tuỳ chọn
> (thiếu thì lấy `user-agent`). Mục 45 (`time_notification`) **vẫn mở** — số dòng nay là `sync.repository.js:117, 527, 553`.

---

## A (vừa) — Tài liệu của client bị viết lại: `docs/superpowers/sync/SYNC_DOCUMENTATION.md`

Commit `6cbd248e` thay toàn bộ tệp (75 dòng, client tạo 2026-09-14, `7b205ce5`) bằng bản *"Hợp đồng v3.0"* 223 dòng. Khi gộp,
client **giữ bản của client** (người dùng chốt 2026-10-23) và thêm một đoạn đầu tệp trỏ về đơn này.

**Xin:** đừng sửa thẳng tài liệu do client tạo (quy ước của repo: tài liệu bên nào tạo thì bên ấy sửa; thấy sai thì báo bằng
đơn, như client làm với `docs/` của backend). Bảng trường của backend đã có chỗ riêng: `docs/Admin-web/Sync-To-ClientApp.md`
(`2375e5db`) — xin soát tệp ấy theo bảng dưới, vì nó mang **cùng** các tên cột sai (ví dụ `NameWallet` dòng 82,
`Total_amount` dòng 199).

**Vì sao bản v3.0 không dùng được:** nó tự xưng là hợp đồng và có mục *"Checklist sửa đổi dành cho dev client-app"* với ô chưa
tick, nhưng sai so với mã ở các chỗ sau. Làm theo những chỗ đánh ⚠️ là hỏng thật.

| Bản v3.0 nói | Đúng (theo mã) | Bằng chứng |
|---|---|---|
| ⚠️ Loại ví `cash, bank, e-wallet, other`, `VARCHAR(20)` | `Cash` · `Bank` · `Saving` · `Banking`, `VarChar(7)`; giá trị lạ vỡ `chk_wallet_type` → ví **kẹt hàng đợi đẩy vĩnh viễn** (đã xảy ra thật 2026-09-09) | client `lib/features/wallet/domain/wallet_type.dart`; `schema.prisma` bảng `wallet` |
| ⚠️ Danh mục `idaccount` = *"`1` nếu hệ thống"* | Client **không bao giờ** đẩy danh mục mặc định; kéo về, `is_default` → idaccount **0**. Tài khoản 1 là **admin thật** | client `lib/core/sync/thu_gom_day.dart`, `anh_xa_keo_ve.dart` |
| ⚠️ Mục 4: `maxSince = max(since, pulledAt − 2 phút)`; client lưu `lastPullTime = pulledAt` | Client lưu `mocTuMaxSince(maxSince, pulledAt)`: lấy **lớn nhất** `maxSince` giữa các bảng, kẹp **xuống** `pulledAt − 2′` khi dữ liệu còn nóng, +1 ms khi nguội; không dùng `since` | client `lib/core/sync/moc_keo_ve.dart`, `ap_du_lieu_keo_ve.dart` (G67, nghiệm thu hai máy 2026-10-08) |
| ⚠️ Thứ tự đẩy client *"BẮT BUỘC"* … → budgets → transactions | Client đẩy categories → wallets → (danh mục giao dịch tham chiếu) → goals → bills → transactions → **budgets**; server tự sắp lại theo `ENTITY_PRIORITY`. Ràng buộc thật chỉ là goal và bill **trước** giao dịch (có ca test) | `thu_gom_day.dart`; `sync.service.js:48-56` |
| Tên cột ví `NameWallet`, `Include_in_total`, `Color VARCHAR(9)` | `Name`, `IncludeInTotal`, `VarChar(20)` | `schema.prisma` bảng `wallet` |
| Tên cột ngân sách `Total_amount`, `Threshold_warning_*`, `Over_spending`, `Over_amount` | `TotalAmount`, `Threshold_Warning_Amount/Percent`, `OverSpending`, `OverAmount` | `schema.prisma` bảng `budget` |
| `threshold_warning_percent` là INT (checklist 8) | `Decimal(15,2)`, client gửi số thực trong 0–100 | `schema.prisma`; client `thu_gom_day.dart` |
| `over_spending` = `'Over'` / `'Normal'`, *"trạng thái vượt"* | `'Over'` (chỉ cảnh báo) hoặc `'Stop'` (hỏi xác nhận) — là **chính sách**, không phải trạng thái | client `budget_entity.dart`; ca test hợp đồng |
| `classify` *"hoặc income / expense / debt"* | Chỉ `Thu` · `Chi` · `Vay/no` | `sync_payload_normalizer.dart`; CHECK của `category` |
| Danh mục *"12 trường"* có `keyword` | 12 khoá gồm cả `name` lẫn `namecategory`, **không** gồm `keyword`; `keyword` chỉ gửi khi khác rỗng (chuỗi rỗng là xoá từ khoá server đã học) | ca test hợp đồng; `thu_gom_day.dart` |
| Hoá đơn `time_recurrence` có `Day`; `Time_notification VARCHAR(20)` | `Week`/`Month`/`Quarter`/`Year`; `VarChar(7)` | client `bill_recurrence.dart`; `schema.prisma` |
| Mục tiêu `cycle_take_money` Day/Week/Month/Year | Thêm `Quarter` | client `other_tables.dart` |
| `type` giao dịch chỉ nói chi / thu → `Transaction` | Thêm `transfer` → `Transfer` kèm `categoryId = null` (cả khoản nạp mục tiêu) | `sync_payload_normalizer.dart` |
| Xoá mềm nhờ `is_deleted = true` | Server xoá mềm nhờ `operation: 'delete'`; `mapEntityFields` không ánh xạ khoá `is_deleted` | `sync.service.js`; `sync.repository.js` |
| Checklist 2–7 *"cần làm"* | Client làm xong cả, có ca test canh | ca test hợp đồng |

Bản v3.0 cũng bỏ mất ghi chú G67 / G85 / G34 và câu *"bảng này không phải hợp đồng — hợp đồng là tệp test"* — lý do client giữ
bản cũ.

**Kiểm lại:** `git diff ee6a65e5 <commit gộp của client> -- docs/superpowers/sync/SYNC_DOCUMENTATION.md` (bản client + đoạn đầu);
với `Sync-To-ClientApp.md`: `grep -n "NameWallet\|Total_amount\|e-wallet" docs/Admin-web/Sync-To-ClientApp.md` → 0 dòng.

---

## B (vừa) — `docs/Admin-web/Event-Notification-to-ClientApp.md` bảo client xoá SQLite khi `ACCOUNT_DELETED`

Dòng **52, 107, 131, 622** viết client phải *"dọn sạch / xoá trắng SQLite (`purgeAccountData`)"* khi nhận `ACCOUNT_DELETED`.
Client **cố ý không làm vậy** ở mọi nguồn (401, socket, refresh) — người dùng chốt 2026-10-20 (G89, đơn 43): SQLite là bản duy
nhất trên máy, xoá là mất phần chưa đồng bộ; dữ liệu của tài khoản cũ vẫn được dọn khi tài khoản khác đăng nhập. Hàm
`purgeAccountData` không tồn tại trong client.

**Xin:** sửa bốn chỗ thành *"client đăng xuất + hiện hộp thoại lý do, không xoá SQLite"*. (12 chỗ lệch của vế D đơn 43 vẫn mở.)

**Kiểm lại:** `grep -n "purgeAccountData\|Xóa sạch SQLite\|Xóa trắng" docs/Admin-web/Event-Notification-to-ClientApp.md` → 0 dòng.

---

## C (vừa) — Migration trùng số 27 (lần hai, sau mục 44 A)

`database/27_add_qr_url_to_payment_order.sql` (`d385d341`, 2026-10-16) và `database/27_create_aiops_metric_snapshot_table.sql`
(`6cbd248e`, 2026-10-23). Sổ ghi tệp đã áp (`Rule_project.md` §3.2) không phân biệt được hai tệp cùng số.

**Xin:** đánh số lại tệp mới thành số kế tiếp chưa dùng (37). Bảng `aiops_metric_snapshot` tự tạo lúc khởi động
(`aiops.repository.js` `initTable`), nên đổi tên tệp không đụng CSDL nào. Cùng lượt, xem lại tệp tên lạ
`database/)2_can_lam_all_migrations.sql` (có từ 2026-09-07, `87d7f0c9`) — ký tự `)` đầu tên dễ là lỗi gõ.

**Kiểm lại:** `ls src/Backend/database | cut -d_ -f1 | sort | uniq -d` → rỗng.

---

## D (vừa) — Bẫy thứ tự trên máy dev: `npm install` trước khi áp 33 / 34 làm **đăng nhập lỗi 500**

`schema.prisma` nay có `account.pin_hash`, `is_first_login`, `created_by_admin_id` (dòng 28, 34, 35) cùng cột mới của `auditlog`,
`feature`, `account_type_permission` và model `account_device_history`. `package.json` có `"postinstall": "prisma generate"`. Các
truy vấn ở `modules/auth/auth.repository.js` dùng `include` không `select` (dòng 28, 39, 50, 64) nên Prisma đọc **mọi** cột của
`account` → trên CSDL chưa áp 33 / 34, mọi lần đăng nhập / đăng ký / đặt lại mật khẩu vỡ `P2022` (đọc mã, chưa chạy).
Client đã vấp đúng kiểu này với migration 19 (2026-10-06).

**Xin:** ghi thứ tự *"áp 30–36 rồi mới `npm install`"* vào chỗ backend hướng dẫn dựng máy dev (hoặc cho `auth.repository.js`
`select` tường minh như `middleware/auth.js:22`).

**Kiểm lại:** trên CSDL chưa áp 33, `npm install` rồi đăng nhập → phải không còn 500.

---

## E (thấp) — `docs/Admin-web/IP-Device-ClientApp.md`

1. Dòng 325 và 372 mô tả `GET /api/admin/accounts/:idaccount/devices` và `GET /api/admin/devices/recent-access`, nhưng mã
   backend **không có** hai route ấy: `grep -rln "devices" src/Backend --include=*.js` (bỏ `node_modules`) → 0 tệp.
2. CORS `app.js:32` `allowedHeaders` chưa có `x-device-name`. Bản Flutter **web** gửi header ấy là preflight hỏng → mọi request
   bị chặn. Android / iOS không bị.

Client **chưa** làm tính năng gửi `x-device-name` (chưa quyết định); đơn chỉ ghi để backend sửa hai chỗ trên trước.

**Kiểm lại:** `grep -n "x-device-name" src/Backend/app.js` → 1 dòng; hai route có trong `admin.routes.js` hoặc gỡ khỏi tài liệu.

---

## F (thấp) — Migration 33 xoá **cứng** tài khoản dưới `session_replication_role = 'replica'`

Tệp 33 dòng 13–38 xoá `refreshtoken`, `otp_code`, `audit_log`, `user`, `account` của các tài khoản khớp `user_ret_%` /
`%anonymized.local%` / `%retention_%@example.com` với trigger + khoá ngoại tắt. Các bảng con khác (`wallet`, `transaction`,
`category`, `bill`, `goal`, `budget`, `payment_order`…) của những tài khoản ấy, nếu có, thành **mồ côi** — khoá ngoại không còn
chặn. Quy ước của repo là xoá mềm (`Delete_at`) — xoá cứng hàng từng đồng bộ làm client đẩy lại mãi `Record not found`.

**Xin:** đổi sang xoá mềm (`Status = 'Deleted'`, `Delete_at`), hoặc xoá kèm mọi bảng con trong cùng khối và không tắt khoá ngoại.

**Kiểm lại** (sau khi áp 33): `SELECT count(*) FROM wallet w LEFT JOIN account a ON a."Idaccount" = w."Idaccount" WHERE a."Idaccount" IS NULL;` → 0.
