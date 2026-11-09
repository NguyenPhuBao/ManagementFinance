# Kế hoạch làm sạch CSDL Supabase (lập 2026-11-08, ĐÃ THỰC HIỆN 2026-11-08)

Mục tiêu: xoá dữ liệu người dùng và dữ liệu rác để có một CSDL sạch làm việc từ đầu, giữ nguyên dữ liệu hệ thống. Số liệu ở mục 1–2 đếm chỉ đọc ngày 2026-11-08, trước khi chạy.

## 0. Kết quả thực hiện (2026-11-08)

PO duyệt cả 4 điểm ở mục 3: xoá dữ liệu tài chính của admin; xoá phiên đăng nhập của admin; xoá luôn `maintenance_history` và thông báo; chấp nhận xoá vật lý vì toàn bộ dữ liệu là của đội phát triển, chưa có người dùng thật.

- **Sao lưu:** `D:\FlowMoney-saoluu\supabase_truoc_khi_don_2026-11-07T23-57-20.dump` (pg_dump 18 ở `C:\Program Files\PostgreSQL\18\bin`, schema `public`, định dạng custom). Đã kiểm bằng `pg_restore --list`: dữ liệu 30 bảng, 10 trigger, 5 hàm. Khôi phục: `pg_restore --clean --if-exists -d <DIRECT_URL> <tệp>`.
- **Sửa so với bản nháp:** danh mục hệ thống thật là 16 dòng `Is_default = true` của tài khoản 1 (Admin-web chỉ quản lý nhóm này, `admin.repository.js`), không phải 61 dòng. 45 dòng còn lại là danh mục cá nhân và danh mục theo hộ của hai admin, nên bị xoá theo điểm 1. Danh mục phải xoá trước `household`: nếu xoá sau, khoá ngoại SET NULL làm danh mục theo hộ trùng tên với danh mục cá nhân (`uq_category_owner_name`).
- **Bỏ bước bật bảo trì:** bật bảo trì sẽ sinh thêm dòng `maintenance_history` và `audit_log`. Thay vào đó, toàn bộ thao tác chạy trong một giao tác, có chạy thử với ROLLBACK trước.
- **Đã xoá:** transaction 90, bill 4, budget 1, goal 3, wallet 50, household 2 (+ 4 thành viên, 3 lời mời), category 153, payment_order 25, payment_transaction 7, refreshtoken 378, account_device_history 347, broadcast_notification 938, maintenance_history 2, aiops_* (2.180 + 178 + 16 + 93 + 4.541), user 10, account 12, audit_log 5.465 (phần còn lại đã xoá dây chuyền theo tài khoản).
- **Còn lại:** account 5 và user 5 (admin), category 16 (mặc định), role 2, feature 40, account_type_permission 80, aiops_setting 3, _prisma_migrations 1. Mọi bảng khác là 0. Riêng `aiops_metric_snapshot` có dòng mới do backend đang chạy ghi theo chu kỳ.
- **Redis:** xoá `notifications:account:*` (1 danh sách, 15 mục) và `notifications:admin` (76 mục). Không còn khoá `ai:*`, `cache:snapshot:*`, `ratelimit:*` (đã hết hạn). Giữ `bull:*` (siêu dữ liệu hàng đợi).
- **Kiểm sau khi chạy:** `npm run db:verify-indexes` đạt; 4 trigger bảo vệ đang bật.
- **Hệ quả:** mọi thiết bị đã đăng nhập bị đăng xuất. Tài khoản người dùng cũ không đăng nhập được nữa. Admin nào dùng app thì xoá dữ liệu ứng dụng hoặc cài lại trước khi đăng nhập, để bản sao ngoại tuyến cũ không đẩy dữ liệu đã xoá lên lại.

## 1. Giữ lại

| Bảng | Số dòng | Lý do |
|---|---|---|
| `role` | 2 | Vai trò hệ thống |
| `feature`, `account_type_permission` | 40, 80 | Gói dịch vụ và ma trận quyền (đã gồm migration 47) |
| `aiops_setting` | 3 | Cấu hình AIOps |
| `_prisma_migrations` | 1 | Lịch sử migration của Prisma |
| `account` + `user` của **5 tài khoản admin** | 5 + 5 | Tài khoản quản trị |
| `category` của admin | 61 | Bộ danh mục mặc định: không có danh mục nào vô chủ, mọi danh mục hệ thống đều do admin tạo |
| `maintenance_history` | 2 | Nhật ký vận hành hệ thống (xem điểm cần quyết 3) |

## 2. Xoá

| Bảng | Số dòng | Ghi chú |
|---|---|---|
| `account` (vai trò user, 8 Active + 4 Deleted) và `user` của họ | 12 + ~10 | Xoá kéo theo phần dữ liệu còn lại của họ |
| `transaction` | 90 | Có trigger `trg_protect_transaction` chặn xoá vật lý |
| `bill` | 4 | Phải xoá TRƯỚC `category` và `wallet` (khoá ngoại RESTRICT) |
| `budget`, `goal`, `wallet`, `bank_account` | 1, 3, 50, 0 | |
| `category` không thuộc admin | 108 | |
| `household`, `household_member`, `household_invite` | 2, 4, 3 | |
| `payment_order`, `payment_transaction` | 25, 7 | Thanh toán của người dùng |
| `refreshtoken`, `account_device_history`, `otp_code` | 378, 347, 0 | Phiên đăng nhập, thiết bị |
| `audit_log` | 6.203 | PO yêu cầu xoá cả audit log; có trigger `trg_protect_auditlog` chặn xoá |
| `broadcast_notification` | 938 | Phần lớn là rác test từ 2026-10-21 |
| `aiops_incident`, `aiops_ip_quarantine`, `aiops_account_quarantine`, `aiops_quarantine_incident_link`, `aiops_metric_snapshot` | 93, 178, 16, 2.180, 4.504 | Dữ liệu vận hành, phần lớn sinh từ test |

Redis Railway: xoá theo tiền tố của ứng dụng (`ai:budget:*`, `ai:quota:*`, `cache:snapshot:*` và các khoá giới hạn tần suất), không dùng `FLUSHALL`.

## 3. Điểm cần PO quyết trước khi chạy

1. **Dữ liệu tài chính riêng của 5 tài khoản admin** (giao dịch, ví, hóa đơn… nếu admin từng dùng app để thử): đề xuất XOÁ, chỉ giữ tài khoản và 61 danh mục mặc định.
2. **Phiên đăng nhập của admin** (`refreshtoken`): đề xuất xoá luôn; admin đăng nhập lại.
3. **`maintenance_history`**: đề xuất giữ, riêng dòng `SCHEDULED` từ 2026-10-25 chưa kết thúc thì chuyển sang `CANCELLED` để không bị hiểu là có lịch bảo trì đang chờ.
4. **Xoá vật lý ngược với quy tắc soft-delete của dự án.** Quy tắc tồn tại vì ứng dụng ngoại tuyến giữ bản sao và xoá cứng làm client kẹt vòng đồng bộ. Lần này chấp nhận được vì tài khoản người dùng bị xoá hẳn (đăng nhập thất bại, không còn đồng bộ). Với admin dùng app: xoá dữ liệu ứng dụng hoặc cài lại trước khi đăng nhập lại, và báo thành viên client.

## 4. Các bước (khi PO ra lệnh)

0. Sao lưu: `pg_dump` toàn bộ Supabase về `D:\FlowMoney-saoluu\` (PostgreSQL 18 ở `D:\Program Files\PostgreSQL\18\bin`) và kiểm tra tệp sao lưu mở được.
1. Bật chế độ bảo trì (Admin-web) để không có thiết bị nào đồng bộ trong lúc xoá.
2. Một giao tác duy nhất (bản nháp SQL ở mục 5): tắt hai trigger chặn xoá; xoá theo thứ tự con trước cha; bật lại trigger; đếm kiểm; chỉ `COMMIT` khi số đếm đúng.
3. Xoá khoá Redis theo tiền tố.
4. `npm run db:verify-indexes` (trigger và chỉ mục còn nguyên), rồi đếm lại toàn bộ bảng.
5. Tắt bảo trì, báo thành viên client.

## 5. Bản nháp SQL (chưa chạy, cần rà lại khi duyệt)

```sql
BEGIN;
ALTER TABLE "audit_log"   DISABLE TRIGGER trg_protect_auditlog;
ALTER TABLE "transaction" DISABLE TRIGGER trg_protect_transaction;

CREATE TEMP TABLE keep_acc AS
  SELECT a."Idaccount" FROM account a JOIN role r ON r."Idrole" = a."Idrole" WHERE r."Rolename" = 'admin';

DELETE FROM "transaction";
DELETE FROM bill;
DELETE FROM budget;
DELETE FROM goal;
DELETE FROM wallet;
DELETE FROM bank_account;
DELETE FROM household_invite;
DELETE FROM household_member;
DELETE FROM household;
DELETE FROM category WHERE "Create_by" NOT IN (SELECT "Idaccount" FROM keep_acc);
DELETE FROM payment_transaction;
DELETE FROM payment_order;
DELETE FROM refreshtoken;
DELETE FROM account_device_history;
DELETE FROM otp_code;
DELETE FROM audit_log;
DELETE FROM broadcast_notification;
DELETE FROM aiops_quarantine_incident_link;
DELETE FROM aiops_ip_quarantine;
DELETE FROM aiops_account_quarantine;
DELETE FROM aiops_incident;
DELETE FROM aiops_metric_snapshot;
DELETE FROM "user"  WHERE "Idaccount" NOT IN (SELECT "Idaccount" FROM keep_acc);
DELETE FROM account WHERE "Idaccount" NOT IN (SELECT "Idaccount" FROM keep_acc);
UPDATE maintenance_history SET status = 'CANCELLED' WHERE status = 'SCHEDULED' AND ended_at IS NULL;

ALTER TABLE "transaction" ENABLE TRIGGER trg_protect_transaction;
ALTER TABLE "audit_log"   ENABLE TRIGGER trg_protect_auditlog;
-- Kiểm: account = 5, category = 61, transaction = 0, audit_log = 0 (dòng ghi sau thời điểm này là của chính lần xoá).
COMMIT;
```

Câu lệnh trên giả định điểm quyết 1, 2 theo đề xuất. Cần kiểm: tài khoản admin có trỏ `created_by_admin_id` tới tài khoản user không (khoá ngoại SET NULL nên không chặn), và quyền `ALTER TABLE ... DISABLE TRIGGER` của tài khoản CSDL đang dùng.
