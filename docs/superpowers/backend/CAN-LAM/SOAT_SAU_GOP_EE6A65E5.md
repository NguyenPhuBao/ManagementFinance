# Mục 49 — Soát sau khi client gộp `main` @ `ee6a65e5` (PR #153–#158) — tài liệu lệch mã, migration trùng số, thứ tự áp, lỗi kích hoạt Premium

> **Client đặt 2026-10-23.** Người nhận: backend (NPBao). Mức chung: **vừa**, riêng **vế G mức CAO** (lỗi mã thật: đơn đã
> trả tiền mà tài khoản không lên Premium — bổ sung cùng ngày sau lượt soát bốn tài liệu `docs/Admin-web/`). Ngoài vế G, không
> có chỗ nào làm hỏng app đang chạy trên backend đã áp đủ migration; các chỗ còn lại là **tài liệu sai** (ai làm theo sẽ gây hỏng
> thật), **migration trùng số**, và **một bẫy thứ tự** trên máy dev. Vế H (bổ sung cùng ngày) là bảng chỗ sai của bốn tài liệu
> `DEVICE_TRACKING_AND_SYNC_PLAN.md`, `Event-Notification-to-ClientApp.md`, `IP-Device-ClientApp.md`, `Sync-To-ClientApp.md`.
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

### Tái phát 2026-10-25 — `36f1ea43` (*"sync module contract v4"*, PR #159) viết đè lần hai

Client gộp `main` @ `0ab9cbd4` và **lại giữ bản của client** (người dùng chốt), thêm đoạn đầu tệp thứ hai. Xin như trên: **đừng sửa
thẳng tệp này**; muốn client đổi gì thì ghi đơn. Bản v4.0 (255 dòng) sửa được vài chỗ của v3.0 (`over_spending` nay là `Stop`/`Over`)
nhưng còn sai:

| Bản v4.0 nói | Đúng (theo mã) | Bằng chứng |
|---|---|---|
| Số trường: ví 16 · danh mục 14 · mục tiêu 24 · hoá đơn 24 · ngân sách 19 · giao dịch 18 | Payload đẩy thật: ví **13**, mục tiêu **22**, hoá đơn **21**, giao dịch **13** (đếm bằng máy từ tệp test) | `src/Client-app/test/core/sync/sync_payload_contract_test.dart` |
| ⚠️ Checklist 4: thêm `status` · `provider` · `images` · `bank_tran_id` vào giao dịch | **Không làm** — nhóm đã bỏ liên kết ngân hàng; bốn cột ấy cố ý không đi chiều nào (quy tắc 4 `CLAUDE.md`, tệp test khoá 13 trường). Thêm `provider` / `bank_tran_id` khi `uq_transaction_external` còn là ràng buộc toàn cục từng là đường tới vòng đẩy vô hạn | `CLAUDE.md` quy tắc 4; tệp test (0 lần nhắc `provider`, `bank_tran_id`, `images`) |
| Checklist 5: bổ sung `id_bank_casso` cho ví | **Không làm** — cùng lý do (liên kết ngân hàng đã bỏ); client chỉ *đọc* được `banking` cho hàng cũ | `lib/features/wallet/domain/wallet_type.dart` |
| Checklist 9: `threshold_warning_percent` *"kiểu số nguyên"* | Cột `Decimal(15,2)`, client gửi số trong 0–100 (như vế A dòng *INT* ở bảng trên) | `schema.prisma`; tệp test |
| Checklist 1: thứ tự mảng *bắt buộc* … `budgets → transactions` | Như bảng trên: server tự sắp theo `ENTITY_PRIORITY`; ràng buộc thật chỉ là goal / bill trước giao dịch | `sync.service.js`; `thu_gom_day.dart` |
| Checklist 2, 3, 5 (`'Active'`/`'Inactive'`), 6, 7, 8 *"cần làm"* | **Đã làm từ trước**, có ca test canh — kể cả 3: `amount` mang dấu do `SyncPayloadNormalizer` đổi lúc đẩy (`chi` → `Transaction` + số âm, `transfer` → `Transfer`), SQLite vẫn lưu dương | `lib/core/sync/sync_payload_normalizer.dart:59-75`; tệp test |
| Checklist 10: client đọc `create_at` của danh mục | Không cần — client không sắp / lọc danh mục theo giờ tạo; trường mới trong `/sync/pull` vô hại (nhánh kéo về bỏ qua khoá lạ) | `lib/core/sync/ap_du_lieu_keo_ve.dart` |

**Kiểm lại:** `git show 36f1ea43:docs/superpowers/sync/SYNC_DOCUMENTATION.md | grep -n "16 trường\|18 trường"` (bản v4) so với
`grep -c "provider\|bank_tran_id" src/Client-app/test/core/sync/sync_payload_contract_test.dart` → 0.

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

---

## G (CAO) — Đồng bộ JIT với PayOS ghi đơn `PAID` nhưng **không nâng Premium**

`modules/payment/payment.service.js` hàm `syncOrderWithPayOS` (nhánh *"Bù trừ Webhook"*, dòng 661–704 — chạy khi
`order-status` / lịch sử đọc một đơn mà PayOS báo `PAID` nhưng webhook chưa tới):

```js
await paymentRepository.updateOrderPaymentStatus({ orderId: order.id, status: 'PAID', amountReceived, paidAt });   // :666
await paymentRepository.activatePremiumSubscription(order.idaccount, {                                              // :673
  packageType: order.package_type || 'Premium',
  orderId: order.id,
});
```

Còn `payment.repository.js:349` khai `async function activatePremiumSubscription({ idaccount, orderId, paidAt, newExpiresAt, transactionData })`
— **một** tham số object. Gọi với một số → `idaccount`, `orderId` đều `undefined` → `tx.payment_order.update({ where: { id: undefined } })`
ném → lỗi bị `catch` ngoài cùng (dòng 706) nuốt thành `logger.warn('… Graceful degradation')`. Kết quả: đơn **đã là `PAID`** trong
CSDL (bước :666 đã ghi), tài khoản **vẫn Basic**, không có `account.upgraded` (nhánh này chỉ phát `payment.success`). Lần đọc sau
đơn đã `PAID` nên JIT không chạy lại → **kẹt vĩnh viễn**. Client hiện màn *"Thành công"* (đọc `PAID`), gọi lại
`/subscription-info` và vẫn nhận Basic. Hai chỗ gọi đúng chữ ký ở cùng tệp: `:313` (webhook) và `:411` (`confirmUpgrade`).

Lỗi có từ `c13873ef8` (2026-10-16; `d1c2284ab` 2026-10-21 chỉ thêm `packageType`). Gặp được trên dev mỗi khi webhook không tới
(không ngrok) — đúng đường nghiệm thu PayOS sandbox của client (G94) đang chờ.

**Xin:** gọi đúng chữ ký như `:313` (tính `newExpiresAt` theo gói như webhook), đặt **cùng giao tác** với bước ghi `PAID` (để không
còn trạng thái *PAID mà chưa nâng*), và phát `account.upgraded` tới phòng tài khoản như webhook. Cân nhắc một câu dọn các đơn đã
kẹt: đơn `PAID` mà `account.premium_expires_at` không được kéo dài sau `paid_at`.

**Kiểm lại:** một test đơn vị gọi `syncOrderWithPayOS` với PayOS giả trả `PAID` → `activatePremiumSubscription` nhận object có
`idaccount` + `orderId`; trên dev: tạo đơn, trả tiền sandbox **không** webhook, mở *Lịch sử mua* → tài khoản lên Premium.

---

## H (vừa) — Bốn tài liệu `docs/Admin-web/` lệch mã (soát 2026-10-23, đọc mã cả hai phía)

Mỗi tài liệu được đối chiếu từng khẳng định với mã client + backend; dưới đây chỉ chỗ **sai / lỗi thời**, mức cao trước. Phần
tả backend nhìn chung đúng; sai tập trung ở chỗ nói về **client** và chỗ tả tính năng **chưa có** như đã có. Client không đổi mã.

**H1 — `Event-Notification-to-ClientApp.md`** (≈ 45 khẳng định đúng)

| Dòng | Tài liệu nói | Thực tế | Mức |
|---|---|---|---|
| 52, 131, 523, 600, 622 (+107) | `ACCOUNT_DELETED` → client xoá SQLite (`purgeAccountData`) | Không xoá ở mọi nguồn (G89, người dùng chốt 2026-10-20 — vế B); hàm ấy không có | **cao** |
| 496–503, 515–521 | Body 401 `{ statusCode, data: { code, idaccount, reason_inactive } }` | `code`, `idaccount`, `reason_inactive` ở **cấp gốc**, không `statusCode` (`response-handler.js` `unauthorized` trải `...extra`; `middleware/auth.js:113-116`). Client đọc cấp gốc — viết theo tài liệu là mất hộp thoại cưỡng chế đăng xuất | **cao** |
| 476–484 | 403 `FEATURE_DISABLED` mã nằm trong `data` | Cấp gốc (`feature-permission.middleware.js:47-55`) | cao |
| 582, 594, 597–598, 614–620 | Client *"bỏ sót"* `account.downgraded`, 503 bảo trì, 403 AIOps, 403 quyền; cần màn bảo trì | Client xử lý cả bốn từ G89 (2026-10-20): làm mới gói, dòng nhắc + hẹn thử theo `Retry-After` / `quarantineExpiresAt` | vừa (lỗi thời) |
| 579, 612 | `system.maintenance_changed` bỏ sót | Client **cố ý** không nghe (payload hộp đen, 2026-09-30) | vừa |
| 154, 165–167 | Hết bảo trì `reason: null`; `active=false` thì `syncNow()` | `reason` không về null; sự kiện còn phát khi tạo / huỷ lịch với `active=false` (`maintenance.manager.js`) → làm theo là đồng bộ thừa | vừa |
| 327, 89/354, 88/328 | `payment.success` do webhook; `order_expired` do worker; người dùng huỷ đơn → `order_cancelled` | Webhook phát `account.upgraded`; tới phòng tài khoản, ba sự kiện này chỉ từ JIT-sync; worker chỉ phát `admin_room`; không có route huỷ đơn | vừa |
| 51 | Socket *"tuyệt đối không"* gửi số tài khoản ngân hàng | `ocr.completed` chuyển nguyên `data` có `transfer_details.source_account` / `destination_account` | vừa (bảo mật) |
| 108, 527–538 | HTTP 400 `PENDING_DELETE_PROTECTED` | Không có trong `src/Backend` (`grep` 0) | vừa |
| 76, 115 · 84, 262, 272 · 102 · 109 · 19 | `force_logout` trơn; `sync.completed` chỉ khi máy khác đẩy, client gọi `processPull()`; ngưỡng lag 100 ms; socket lỗi thì làm mới JWT; đường dẫn `core/api/interceptors/buoc_dang_xuat.dart` | Chỉ `account.force_logout`; phát sau **mọi** push, client gọi `syncNow()`; 250 ms (`event-loop-monitor.js:9`); có `data.code` → đăng xuất, không thì giãn cách + đọc lại token; `core/auth/buoc_dang_xuat.dart` | thấp |
| 4.3–4.13 | Tên trường payload (`expiresAt`, `receivedAmount`…), *"Zero-Guesswork"* (dòng 49) | Lệch nhiều tên; client **không đọc payload** (trừ `account.force_logout`) — nguyên tắc ấy ngược hợp đồng thật | thấp |

**H2 — `Sync-To-ClientApp.md`** (≈ 115 khẳng định đúng — đa số hàng trường, số trường 13/12/22/21/17/13 khớp tệp test hợp đồng)

| Dòng | Tài liệu nói | Thực tế | Mức |
|---|---|---|---|
| 176 | Hoá đơn `time_recurrence` có `'Day'` | `chk_bill_time_recurrence` chỉ `Week / Month / Quarter / Year` (migration `20260901090000…:136-138`) → làm theo là **kẹt hàng đợi đẩy** | **cao** |
| 42, 89, 119, 155, 185, 211, 233 | Gửi `is_deleted: true` → server ghi `Delete_at` | `mapEntityFields` chỉ đọc `isDeleted` (camelCase, `sync.repository.js:31,60,89,129,163,179`); xoá chạy nhờ `operation: 'delete'` → `softDelete()`. Gửi `update` kèm `is_deleted` là **không xoá, không báo** | **cao** |
| 317–321 | Client lưu `lastPullTime = pulledAt`; `maxSince = max(since, pulledAt − 2′)` | Client lưu `mocTuMaxSince(maxSince, pulledAt)`: lớn nhất `maxSince` của các bảng, kẹp **xuống** `pulledAt − 2′` (`moc_keo_ve.dart`, G67). Lưu `pulledAt` thô là bỏ sót hàng commit muộn | **cao** |
| 249–270, 288–296, 302–306, §4 | Client có `user_profile` (12 trường), `permissions_cache`; thông báo từ Socket / FCM, cột `type`, `isRead`; *"4 bảng cục bộ"* | Không có hai bảng đầu; `AppNotifications` do client tự suy từ ngân sách / hoá đơn / mục tiêu (cột `kind`, `dedupeKey`, `readAt`…); schema v31 có **11** bảng chỉ cục bộ | vừa |
| 277–278, 345 | Client dùng `device_info_plus`, gắn `x-device-name` | Chưa có (vế E) | vừa |
| 82, 90, 199–204, 83, 87, 177, 202, 344 | `NameWallet`, `Include_in_total`, `Total_amount`, `Threshold_warning_*`, `Over_spending`, `Over_amount`, `chk_budget_over_spending`; ví `Type` VARCHAR(20), `Color` VARCHAR(9); `Time_notification` VARCHAR(20); ngưỡng % INT | `Name`, `IncludeInTotal`, `TotalAmount`, `Threshold_Warning_*`, `OverSpending`, `OverAmount`, `ck_budget_overspending`; `VarChar(7)`, `VarChar(20)`, `VarChar(7)`, `Decimal(15,2)` | thấp (vừa với ai viết SQL thô) |
| 50–52, 329 · 66 · 315 | Client BẮT BUỘC đẩy cat→wallet→goal→bill→budget→tx; lỗi FK trả 400, kẹt vĩnh viễn; trigger chạy cả INSERT | Server tự sắp (`ENTITY_PRIORITY`), client đẩy budget sau tx; lỗi FK là HTTP 200 với `results[i].code = 'FOREIGN_KEY_VIOLATION'`; trigger chỉ `BEFORE UPDATE` | thấp |

**H3 — `IP-Device-ClientApp.md`** (17 khẳng định đúng — phần backend ghi vết, che IP trước khi lưu, throttle 60 s, DDL 35)

| Dòng | Tài liệu nói | Thực tế | Mức |
|---|---|---|---|
| 42–44, 325, 372, 346, 384 | Admin có tab thiết bị, màn `/admin/security/device-history`, hai route `devices`, huy hiệu *"đang hoạt động"* | Không có route, không có màn (`src/Admin-web/src/router/routes.jsx`); `getDeviceHistory` chỉ test gọi; `id` BigInt chưa có `toJSON` → viết endpoint sẽ ném | vừa |
| 383–392 | Mọi test `[x]` | Test 1.1–1.3 (Admin, client gửi header) chưa có gì để chạy; *"tầng CSDL thực"* dùng Prisma giả | vừa |
| 194, 259 · 285–299 · 281 | Đặt tệp `lib/core/services/`; `dio.post('/api/auth/login')` trong `AuthRepository`; `dio.interceptors.add(...)` | `services` ngoài 15 chủ đề `core` của client → test quét 25 đỏ; `baseUrl` client đã có `/api` → `/api/api/…` 404, đăng nhập ở `AuthRemoteDataSource`; làm mới token đi qua `_refreshDio` riêng → không mang header | vừa |
| 222–231 | Lấy tên máy bằng `iosInfo.name`, `computerName` | Đó là tên **người dùng đặt** (dữ liệu cá nhân) — trái chính §2.3 của tài liệu | vừa |
| 89 · 152 · 82 · 54, 135 · 163–165 | IPv6 giữ 3 nhóm; dự phòng *"Unknown Mobile Device"*; chỉ đăng nhập bỏ throttle; `first_seen_at` là lần đầu thấy thiết bị + IP; đoạn lấy IP | Giữ 2 nhóm (`masking.util.js:198-200`); `'Unknown Device'`; đăng ký, verify-otp, refresh cũng bỏ; chỉ so dòng mới nhất (hai máy xen kẽ → thêm dòng mỗi 60 s); đọc thẳng `X-Forwarded-For[0]` → giả được IP, lệch `auth.service` (`req.ip` trước) | thấp |
| — | (không nhắc) | CORS `app.js:32` thiếu `x-device-name` (vế E); header tên máy có dấu hỏng trên trình duyệt (ngoài Latin-1) | thiếu |

**H4 — `DEVICE_TRACKING_AND_SYNC_PLAN.md`**

| Dòng | Tài liệu nói | Thực tế | Mức |
|---|---|---|---|
| 5 | *"ĐÃ TRIỂN KHAI HOÀN TẤT 100%"* | Client chưa có dòng mã nào (`x-device-name`, `device_info_plus`: 0 kết quả); Admin không route, không màn; CORS chưa mở | vừa |
| 165–175 | *"Pass 8/8 test 2 tầng"*, kiểm CSDL thật | `tests/unit/device.tracking.2tier.test.js` mock Prisma trong bộ nhớ; ca 5 (unique / FK) không có test | vừa |
| 90 | `400 PENDING_DELETE_PROTECTED` | Không có (đã lan sang H1) | vừa |
| 125, 126, 30 / 186 | Dự phòng *"Thiết bị không xác định"*; lấy `req.ip` trước; gắn ở `authenticateToken` | `'Unknown Device'` sau user-agent; `X-Forwarded-For[0]` trước; tên đúng `authenticate`, gắn cả đăng ký / OTP / refresh | thấp |
| 69–81 | 15 sự kiện socket (commit ghi 18) | Hai con số lệch nhau; client không bắt `system.maintenance_changed` (cố ý), `system.broadcast`, `account.countdown`, `user.notification` (hàm phát không có chỗ gọi ngoài test) | thấp |

Phần đúng của H4: DDL 35, `maskIp`, danh sách trường đồng bộ và số trường, `balance` một chiều, `Server_update_at`.

**Xin:** sửa các chỗ mức **cao** và **vừa** ở bốn tệp trên (chúng là tài liệu của backend — client không sửa); với chỗ nói về
client, đối chiếu tệp test hợp đồng `src/Client-app/test/core/sync/sync_payload_contract_test.dart` và mã `src/Client-app/lib/core/`
thay vì suy luận; tính năng chưa có thì ghi *"kế hoạch"*, đừng đánh `[x]` / *"100%"*.

**Kiểm lại:**
`grep -n "purgeAccountData\|PENDING_DELETE_PROTECTED\|NameWallet\|Total_amount\|pulledAt - 2\|HOÀN TẤT 100%" docs/Admin-web/*.md` → 0 dòng;
hàng `time_recurrence` của **hoá đơn** trong `Sync-To-ClientApp.md` không còn `'Day'` (mục tiêu thì `Day` hợp lệ — đừng `grep` chung).
