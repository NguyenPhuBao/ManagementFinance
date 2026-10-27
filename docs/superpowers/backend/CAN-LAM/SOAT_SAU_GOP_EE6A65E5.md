# Mục 49 — Soát sau khi client gộp `main` @ `ee6a65e5` (PR #153–#158) — tài liệu lệch mã, migration trùng số, thứ tự áp, lỗi kích hoạt Premium

> 🔎 **Client soát lượt báo xong 2026-10-27** (`850fe23b`, client gộp `bc0b28ce`; đọc mã HEAD, CSDL Supabase của `.env` chỉ `SELECT`): **chưa xong — chuyển lại `CAN-LAM/`.**
> - **G — đạt qua đơn 53 B:** JIT tính `newExpiresAt` (`payment.service.js:682`) + phát `account.upgraded` (`:722`).
> - **C — đạt phần tệp:** `database/)2_can_lam_all_migrations.sql` đã xoá; tên cũ trong tài liệu chưa soát.
> - **A, D, E, F, H1, H3 — không có lời trả lời:** ô *"Trả lời đơn"* cuối tệp chép nội dung **đơn 43** (A1 / A3 / A4 AIOps);
>   `850fe23b` không đổi gì ở các vế ấy.

> 🔎 **Client soát lượt báo xong 2026-10-26** (`49eafef6` · `bc4e4f7f` · `2b926d92`, gộp `3636110d`; đọc mã HEAD, CSDL Supabase của `.env` chỉ `SELECT`): **chưa xong — chuyển lại `CAN-LAM/`; vế G sửa thành một lỗi CAO khác.**
> - **G (CAO) — nay thành "Premium vô thời hạn":** `payment.service.js:674-678` gọi `activatePremiumSubscription({ idaccount, orderId, paidAt })`
>   — đúng chữ ký nhưng **không** `newExpiresAt`, không `transactionData`; `payment.repository.js:394` ghi `premium_expires_at: newExpiresAt` =
>   `undefined` ⇒ Prisma bỏ qua, cột giữ nguyên. Tài khoản Basic (hạn `NULL`) trả tiền qua đường JIT thành **Premium không hết hạn** — client
>   (`trang_thai_goi.dart:40`) coi `null` là Premium, hạ cấp định kỳ (`downgradeExpiredPremiumAccounts`, `lte: now`) và
>   `feature-permission.middleware.js:33` không bắt `null`; tài khoản Premium gia hạn qua đường này **không được cộng hạn**. Không ghi hàng
>   `payment_transaction`; vẫn chỉ phát `payment.success` (không `account.upgraded`); bước ghi `PAID` (`:667`) vẫn tách khỏi giao tác nâng gói;
>   không ca test nào đi nhánh PAID. CSDL hôm nay: 0 đơn kẹt, 0 tài khoản Premium hạn `NULL` — **chưa xảy ra, không phải không thể**. Xin: tính
>   `newExpiresAt` như nhánh webhook (`:299-311`), một giao tác, có ca test. Gom cùng đơn 53.
> - **A — tái phát lần ba:** `bc4e4f7f` sửa thẳng `SYNC_DOCUMENTATION.md` (lọt qua lượt gộp `3636110d`) — sai thứ tự đẩy (budget 30 / goal 35 /
>   bill 38), sai thành phần payload danh mục, ghi `images` "đồng bộ URL", Mục V sáu việc client đã làm, xoá đoạn *"tệp test là hợp đồng"*.
>   Client đã **gộp hai tài liệu đồng bộ thành một tệp đối chiếu mã** (`75126cec`; `docs/Admin-web/Sync-To-ClientApp.md` nay chỉ trỏ về) và mở
>   mục 14 *Trao đổi* để backend ghi thay vì viết đè. Đi kèm thay đổi mã không ai xin: `is_deleted` → `delete_at` — **đơn 53**.
> - **B — đạt** (0 chỗ bảo xoá SQLite; 6 chỗ "bảo lưu SQLite").
> - **C — một phần:** `27b_…` (`uniq -d` rỗng); còn `)2_can_lam_all_migrations.sql`; tên cũ còn ở
>   `docs/Admin-web/09-aiops-sentinel-and-quarantine.md:8`, `docs/AIOps/AIOPS_SENTINEL_REFINEMENT_PLAN.md:45, 55`.
> - **D — chưa** (`auth.repository.js:28, 39, 50, 64` vẫn `include` không `select`). **F — chưa:** migration 33 không đổi; câu kiểm của đơn ra
>   **10 ví, 13 giao dịch, 1 danh mục mồ côi** (tài khoản 2, 42–46, 53, 61, 68; `Create_at` 2026-09-10).
> - **E — một phần:** CORS đạt (`app.js:32`); hai route `/devices` vẫn không có trong mã, `IP-Device-ClientApp.md:325, 372` không đổi; **mới:**
>   `04-user-management-and-lifecycle.md:125, :156` ghi route ấy và "Tab Lịch sử thiết bị & IP" mà Admin-web không có.
> - **H — một phần:** H1 body 401 / 403 vẫn lồng `"data"` (`:498`, `:517`, `:536`); các dòng "BỎ SÓT" / "BÁN PHẦN" cho thứ client đã làm
>   (`:583`, `:587`, `:599`, `:600`, `:602`–`:604`); `MaintenanceScreen` (`:101`, `:434`, `:584`, `:599`, `:622`). H2 — gộp vào tài liệu đồng bộ
>   của client (trên). H3 `IP-Device-ClientApp.md` — chưa. H4 — phần chính đạt.

> 🔎 **Client soát lại 2026-10-26** (`main` @ `5bb258ff`; đơn này chỉ lên `main` qua PR #160 tối 2026-10-25, **sau** commit
> backend mới nhất `36f1ea43`): **chưa vế nào được làm.**
> - **A:** `SYNC_DOCUMENTATION.md` không bị viết đè lần ba (giữ bản client); lỗi mới của bản v4.0 bổ sung ở cuối vế A.
> - **B:** còn nguyên (`Event-Notification-to-ClientApp.md` v4.0 dòng 52, 131, 544, 621, 643; câu kiểm của vế B ra thêm 107).
> - **C:** vẫn trùng số 27, vẫn còn `)2_can_lam_all_migrations.sql`. **D:** `auth.repository.js:28, 39, 50, 64` vẫn `include` không
>   `select`. **F:** migration 33 không đổi.
> - **E:** CORS `app.js:32` vẫn thiếu `x-device-name`; `IP-Device-ClientApp.md:325, 372` còn hai route không có trong mã.
> - **G (CAO) chưa:** `payment.service.js:673` vẫn gọi `activatePremiumSubscription(order.idaccount, {…})`, trong khi hàm khai
>   `({ idaccount, orderId, paidAt, newExpiresAt, transactionData })` (`payment.repository.js:349`).
> - **H:** còn nguyên; số dòng trên bản v4.0 + chỗ sai mới bổ sung ở cuối vế H.
>
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

### Soát 2026-10-26 — chỗ sai của bản v4.0 chưa có trong bảng trên

Đọc `git show 36f1ea43:docs/superpowers/sync/SYNC_DOCUMENTATION.md`, đối chiếu `src/Backend/prisma/schema.prisma` và tệp test hợp đồng:

| Bản v4.0 nói | Đúng (theo mã) | Bằng chứng |
|---|---|---|
| :67 loại ví `Cash`, `Bank`, `EWallet`, `Credit`, `Savings`, `Other`, `VARCHAR(20)` | `Cash` · `Bank` · `Saving` · `Banking`, `VarChar(7)` — ai làm theo mà gửi giá trị khác là vỡ `chk_wallet_type`, ví kẹt hàng đợi đẩy vĩnh viễn | `schema.prisma` model `wallet`; `prisma/migrations/20260901090000_align_new_database/migration.sql`; `src/Client-app/lib/features/wallet/domain/wallet_type.dart` |
| :74–75 ví `icon VARCHAR(255)`, `color VARCHAR(50)` | `VarChar(20)` cả hai | `schema.prisma` model `wallet` |
| :89, :94–96 danh mục `name_category VARCHAR(100)`, `keyword VARCHAR(50)`, `icon VARCHAR(255)`, `color VARCHAR(50)` | `VarChar(200)` · `Text` · `VarChar(20)` · `VarChar(9)` | `schema.prisma` model `category` |
| Số trường danh mục **14**, ngân sách **19** | Payload đẩy: danh mục **12** (13 khi có `keyword`), ngân sách **17** — bản v4 cộng cả `create_at`, `server_update_at` (hai cột chỉ kéo về) | tệp test hợp đồng |
| Hoá đơn *"24 trường"* | Bảng của chính mục 3.4 chỉ có **23** hàng; payload đẩy thật **21** | bản v4 mục 3.4 |

(Câu :88 *"`1` nếu danh mục hệ thống"* **đúng** với server — đo 2026-10-26 trên CSDL Supabase: 16 hàng `Is_default` đều `Create_by = 1`; client tự quy về 0 khi kéo về.)

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

> ✅ **2026-10-26 — client đã gửi `x-device-name`** (người dùng chọn): **chỉ bản Android**, giá trị dạng `Realme RMX2205 (Android 13)`
> (hãng + `Build.MODEL` + phiên bản Android, ASCII in được, ≤ 150 ký tự) qua kênh Kotlin `flowmoney/thiet_bi` — **không** dùng
> `device_info_plus`. Gắn ở cả Dio chung lẫn Dio của `/auth/refresh`, ở cả engine app lẫn engine nền WorkManager, để **một máy
> luôn gửi một tên** (luật *"tên / IP đổi → INSERT dòng mới"* của `device-history.service.js` sẽ phình bảng nếu hai đường gửi hai
> tên). Bản web / iOS **không** gửi — nên điểm 2 (CORS) hôm nay không làm hỏng gì, nhưng vẫn nên sửa trước khi có bản web gửi
> header. Thứ còn thiếu phía backend: **không có chỗ nào đọc** bảng `account_device_history` (`getDeviceHistory` 0 chỗ gọi ngoài
> test, Admin-web không có màn thiết bị) — header hiện chỉ được ghi.

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
| 277–278, 345 | Client dùng `device_info_plus`, gắn `x-device-name` | Chưa có (vế E) — ✅ 2026-10-26 client gắn header (Android, kênh Kotlin, **không** `device_info_plus`) | vừa |
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

### Soát 2026-10-26 — số dòng trên bản v4.0 (`36f1ea43`) và chỗ sai mới

`Event-Notification-to-ClientApp.md` v4.0 (643 dòng) giữ nguyên các chỗ mức cao của H1. Số dòng mới:

- xoá SQLite khi `ACCOUNT_DELETED`: **52, 131, 544, 621, 643**;
- body 401 / 403 lồng `"data": {`: **499, 518, 537**;
- `PENDING_DELETE_PROTECTED`: **108, 548, 555**;
- *"BỎ SÓT"* cho thứ client đã có: **603** `account.downgraded` · **615** 503 `MAINTENANCE_MODE` · **618** 403 `AIOPS_QUARANTINED` ·
  **619** 403 `FEATURE_DISABLED` (client: `realtime_event.dart`, `trang_thai_may_chu.dart`, `may_chu_interceptor.dart`).

**Mới ở v4.0:** đòi client mở `MaintenanceScreen` và dừng đồng bộ nền khi bảo trì — **101, 435, 600, 615, 638**. Client cố ý dùng
dòng nhắc + hẹn thử theo `Retry-After`, không màn chặn, và cố ý không nghe `system.maintenance_changed`. Các chỗ lệch của phần sự kiện
§4.2–§4.13 chấm lại ở banner đầu mục 43 (vế D) và mục 44 (vế F).

Ba tệp còn lại không đổi từ 2026-10-23: `DEVICE_TRACKING_AND_SYNC_PLAN.md:5` vẫn *"HOÀN TẤT 100%"*; `Sync-To-ClientApp.md` còn
`NameWallet` (:82), `Total_amount` (:199), `Time_notification VARCHAR(20)` (:177 — thật `VarChar(7)`), và dạng LaTeX
`\text{pulledAt} - 2\text{ phút}` (:317–320) mà câu kiểm lại ở trên bỏ sót.

---

## Trả lời đơn

**Lead BA & Lead FullStack đã hoàn tất 100% xử lý và kiểm thử (Mục 43):**
- **Về A1 (Thừa `updateMany` trong `aiops.controller.js`):** Đã loại bỏ hoàn toàn các khối `prisma.account.updateMany` thủ công dư thừa trong `permanentBanAccount` và `temporaryBlockAccount`. Mọi thao tác đồng bộ CSDL và RAM ma trận hiện đã được chuẩn hóa duy nhất qua `defaultAIOpsQuarantine`.
- **Về A3 (AIOps Auto-unlock ghi đè trạng thái tài khoản):**
  + Đã sửa `_syncAccountStatusToDatabase` trong `src/Backend/modules/aiops/aiops.quarantine.js`.
  + Ràng buộc tuyệt đối: Khi mở khóa (`status: 'Active'`), chỉ áp dụng cho tài khoản đang có `status: 'Inactive'`; cấm chạm vào `PendingDelete` hoặc các trạng thái khác.
  + Với lượt quét tự động hết hạn (`sweepExpiredQuarantines`), truyền `{ onlyAIOpsLocked: true }` để chỉ mở khóa các tài khoản do AIOps/Sentinel/Cách ly phong tỏa, không can thiệp vào tài khoản do Admin khóa thủ công vì lý do nghiệp vụ khác.
  + Khi khóa tài khoản (`status: 'Inactive'`), cũng bảo vệ không hạ trạng thái `PendingDelete`.
- **Về A4 (Broken import & Status trong `feature.collector.js`):** Đã loại bỏ đoạn thừa gọi sai đường dẫn require và set sai enum `TemporarilyLocked` tại xử lý Heuristic Brute-force.
- **Ca test 2 tầng:** `tests/unit/aiops.sync_account_protection.test.js` pass 100% (4/4 assertions).

