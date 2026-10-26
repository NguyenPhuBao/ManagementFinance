# Soát sau gộp `main` @ `cd2ee572`: AIOps khoá tài khoản làm client xoá dữ liệu; webhook PayOS nâng nhầm tài khoản; đăng nhập lúc bảo trì mất `code`; đính chính hợp đồng sự kiện (mục 43)

> 🔎 **Client soát lượt báo xong 2026-10-26** (`49eafef6` · `bc4e4f7f` · `2b926d92`, gộp `3636110d`; đọc mã HEAD, CSDL Supabase của `.env` chỉ `SELECT`): **chưa xong — chuyển lại `CAN-LAM/`.** Lượt sửa chỉ chạm `aiops.controller.js` (2 dòng); `core/`, `middleware/`,
> `aiops.quarantine.js`, `feature.collector.js` không đổi từ `36f1ea43`.
> - **A1 — đạt về giá trị:** `aiops.controller.js:249`, `:305` nay ghi `'Inactive'` (grep `'Locked'` trong `modules/` → 0). Nhưng hai khối
>   `updateMany` vẫn chạy **sau** hàm quarantine và ghi đè `reason_inactive` bằng câu của controller — đơn xin bỏ hẳn; giữ lại là phá dấu
>   nguồn khi làm A3.
> - **A3 — chưa:** mở khoá tự động `aiops.quarantine.js:141`, `:153`, `:983` → `_syncAccountStatusToDatabase` (`:657-673`) không xét ai khoá;
>   `quarantinePair` (`:398`) ghi đè cả `PendingDelete`; chỗ thứ ba cùng khuôn: `unblockAccount` (`aiops.controller.js:210-216`).
> - **A4 — chưa:** `feature.collector.js:231` `require('../../database/prisma')` (tệp không tồn tại), `:235` `'TemporarilyLocked'`.
> - **A5 — chưa:** không tệp `database/N` mới; CSDL bảng `account` **0** CHECK, `"Status"` chỉ `Active` (8) / `Deleted` (4) — áp thẳng được.
> - **A6 (tuỳ chọn) — chưa.** **D — chưa:** vẫn 3 / 12 đạt, 1 một phần, 8 còn sai trên bản HEAD — §5.5 `:498-499` · §4.7 `:281` · §4.4
>   `:217-218` · §4.5 `:236-243` · §4.9 `:319` + bảng `:86` · §4.2 `:172` · §5.2 `:439` + bảng `:102` · §1 (sự kiện tới hai lần qua Redis);
>   một phần: OCR `:302` `metadata`.
> - A2, B, C vẫn đạt. Câu *"438 test pass"* không chứa test nào cho các vế còn mở (`49eafef6` không sửa tệp nào dưới `src/Backend/tests`).

> 🔎 **Client soát lại 2026-10-26** (mã `main` @ `5bb258ff`, backend mới nhất `36f1ea43` — PR #159, 2026-10-24; truy vấn
> chỉ đọc trên CSDL Supabase của `.env`): **không vế còn mở nào được làm thêm.** A2 · B · C vẫn đạt.
> - **A1:** `aiops.controller.js:249`, `:305` còn `status: 'Locked'`.
> - **A3:** `_syncAccountStatusToDatabase` (`aiops.quarantine.js:663-673`) vẫn mở khoá theo id / tên, không xét ai khoá — thêm hệ
>   quả: tài khoản `PendingDelete` bị cách ly rồi hết hạn sẽ về `Active`, mất trạng thái chờ xoá.
> - **A4:** `feature.collector.js:231`, `:235` còn. **A6:** AIOps vẫn không phát `force_logout`.
> - **A5:** chưa có tệp `database/N`; CSDL: bảng `account` **0** ràng buộc CHECK, `"Status"` hiện chỉ có `Active` (8) / `Deleted` (4).
> - **D chấm lại trên bản v4.0** (`36f1ea43` viết lại `Event-Notification-to-ClientApp.md`): **3 / 12** chỗ đã sửa (đếm ngược chỉ
>   phát lúc 00:00 · bỏ câu *"Refresh Token đã bị hủy"* · bỏ ba route sai, nhưng chưa ghi route đúng); **1** sửa một phần (OCR §4.8
>   `:297-312` ghi `metadata`, mã gửi `data` + `createdAt` — `notification.service.js:98-104`); **8** còn sai: §5.5 `:499-503` `code`
>   lồng trong `data` (mã phẳng — `response-handler.js:47-53`) · §4.7 `:282` `created/updated/deleted` (mã
>   `total/synced/conflicts/errors` — `sync.service.js:243`) · §4.4 `:218` `idaccount_type/idfeature` (mã `account_type/feature_id` —
>   `admin.service.js:743`) · §4.5 `:238-243` chỉ một hình dạng (mã gửi `{type, premiumExpiresAt}` — `payment.service.js:342` — và
>   `{reason: 'PERMISSIONS_MATRIX_UPDATED', updates}` tới **mọi** client — `socket.js:383-386`) · §4.9 tả `user.notification` như sự
>   kiện sống (`notifyUser` không còn chỗ gọi) · §4.2 `:170-174` `reason: null` khi tắt bảo trì (mã có thêm `scheduled` /
>   `scheduledList` — `maintenance.manager.js:665-676` — và tắt không xoá `reason`) · §5.2 `:440` + bảng `:102` ngưỡng 100 ms (mã
>   250 ms — `event-loop-monitor.js:9`) · §1 chưa ghi sự kiện có thể tới hai lần qua Redis (`event-bus.js:25`).
>
> 🟡 **Client soát 2026-10-18 (sau gộp `main` @ `e7570e16`; backend ghi *"✅ Đã xong 100%"* ở `3a5d320c`): đạt phần
> chính, còn sáu việc.** Đo bằng đọc mã ở `e7570e16`, truy vấn chỉ đọc trên CSDL dev, và `grep` từng hàng bảng mục D trên
> `docs/Admin-web/Event-Notification-to-ClientApp.md`. Thân đơn bên dưới giữ nguyên: mục *Xin làm* và *Kiểm lại bằng* của
> từng vế vẫn áp dụng; dòng *Kiểm lại* dưới mỗi việc còn mở là phép đo rút gọn.
>
> **Đạt:**
> - **A2** — `accountRejection` (`middleware/auth.js:60`) mặc định `ACCOUNT_INACTIVE`. Chỉ không còn trạng thái, `Deleted`,
>   hoặc `delete_at` đã qua mới thành `ACCOUNT_DELETED`. Đây là vế chặn được việc client xoá SQLite: `'Locked'` hay
>   trạng thái lạ nào cũng đọc là *bị khoá*.
> - **A1 phần quarantine** — `quarantinePair` (`aiops.quarantine.js:398`) và hai lối khoá của admin (`:753`, `:839`) ghi
>   `'Inactive'` + `Reason_inactive`.
> - **B** — webhook không thấy đơn (`payment.service.js:130`) ghi log và trả 2xx, không tạo đơn, không nâng gói.
>   `findOrCreateOrderByCode` vẫn được export nhưng không còn chỗ nào gọi.
> - **C** — `auth.controller.js:61` trả 503 có `code: 'MAINTENANCE_MODE'` và header `Retry-After: 60`.
>
> **Còn mở:**
> 1. **A1 phần controller** — `aiops.controller.js:249` và `:305` vẫn ghi `status: 'Locked'` **ngay sau** khi
>    `permanentBanAccount` / `temporaryBlockAccount` đã ghi `'Inactive'`, nên lệnh sau đè lệnh trước. Nhờ A2, client vẫn
>    giữ dữ liệu, nhưng `'Locked'` là giá trị ngoài tập bốn trạng thái. Xin bỏ hẳn hai khối `updateMany` ấy: hàm quarantine
>    đã ghi đúng `'Inactive'` + lý do.
>    *Kiểm lại:* `git grep -n "'Locked'\|TemporarilyLocked" -- src/Backend/modules` → 0 dòng.
> 2. **A3** — mở khoá tự động (`aiops.quarantine.js:141`, `:153`, `:983`) gọi `_syncAccountStatusToDatabase(…, 'Active')`.
>    Hàm ấy (`:657`) `updateMany` theo `idaccount` / `username` mà không xét ai đã khoá. Tài khoản admin đặt `Inactive` vì
>    lý do khác vẫn bị mở. Xin thêm điều kiện vào `where` của nhánh `'Active'`: chỉ mở hàng đang `Inactive` **và** mang
>    đúng lý do do AIOps ghi (hoặc một dấu nguồn tương đương do backend chọn).
>    *Kiểm lại:* ca test — admin khoá tài khoản X với lý do riêng trong lúc X đang bị AIOps cách ly; hết hạn cách ly → X
>    vẫn `Inactive`, `Reason_inactive` vẫn là lý do của admin.
> 3. **A4** — `feature.collector.js:231` vẫn `require('../../database/prisma')` (không tồn tại) và ghi `'TemporarilyLocked'`.
>    Lệnh ném và bị nuốt nên hôm nay vô hại; `quarantinePair` ngay trên đã khoá đúng. Xin xoá khối ấy.
>    *Kiểm lại:* `git grep -n "database/prisma" -- src/Backend/modules` → 0 dòng.
> 4. **A5** — chưa có tệp `database/N` nào áp `ck_account_status`. CSDL dev đo 2026-10-18: bảng `account` có **0** CHECK.
>    Trạng thái đang có: `Active` 6 hàng, `Deleted` 14 hàng — áp thẳng được. Làm **sau** việc 1: còn lệnh ghi `'Locked'`
>    thì mỗi lần admin khoá qua AIOps Sentinel sẽ vỡ CHECK và ghi một dòng WARN (không hại dữ liệu, vì `'Inactive'` đã
>    ghi trước).
>    *Kiểm lại:* hai câu SQL ở mục *Kiểm lại bằng* của vế A.
> 5. **A6** (tuỳ chọn) — AIOps khoá tài khoản chưa phát `account.force_logout`.
> 6. **D — chưa sửa hàng nào (0 / 12).** Ở `3a5d320c`, `Event-Notification-to-ClientApp.md` thêm khoảng 106 dòng, nhưng đó là
>    phần thanh toán của đơn 44 mục F. Đo từng hàng ngày 2026-10-18:
>    - §4.5 vẫn lồng `code` trong `data` và có `statusCode` (`:531`–`:535`).
>    - §3.8 vẫn `summary: { created, updated, deleted }` (`:264`).
>    - §3.4 vẫn route `PUT /api/admin/permissions/matrix` và khoá `idaccount_type` / `idfeature` (`:168`, `:175`).
>    - §3.5 vẫn một hình dạng payload; không có `PERMISSIONS_MATRIX_UPDATED`.
>    - §3.11 vẫn tả `user.notification` là sự kiện sống (`:67`, `:326`).
>    - §3.7 vẫn ghi phát khi người dùng gửi yêu cầu xoá.
>    - §3.9 · §3.10 vẫn `predicted_category_id`, `confidence` và `DUPLICATE_RECEIPT_HASH` (`:293`, `:316`).
>    - §3.2 vẫn `"reason": null` khi tắt, không có `scheduled`.
>    - §4.2 vẫn ngưỡng 100 ms (`:463`), bảng §2 hàng 17 cũng vậy (`:73`).
>    - §3.1 · §3.3 vẫn route `PATCH /api/admin/users/:id/status` và `POST /api/admin/system/broadcast` (`:88`, `:141`).
>    - §4.6 vẫn *"Refresh Token đã bị hủy trên server"* (`:560`).
>    - §1 chưa ghi việc sự kiện có thể tới hai lần qua Redis.
>
>    Bảng §5 *hiện trạng client* cũng chưa đính chính theo danh sách cuối vế D, ví dụ `user.notification` vẫn ghi *"BỎ SÓT"*
>    (`:617`).
>    *Kiểm lại:* chạy lại đúng các `grep` theo số dòng trên; mỗi hàng phải ra câu mới ở cột *Mã thật* của bảng vế D.

**Ngày:** 2026-10-15 · **Phía gửi:** Client-app · **Nhánh:** `TranQuangDat` (commit gộp `12104082`)
**Loại:** đơn xin — **hai lỗi mã mức cao** (A, B), **một lỗi mức vừa** (C), **sửa tài liệu** (D). Không đổi lược đồ
đồng bộ, không đổi payload `/sync/*`. Mọi khẳng định dưới đây đo bằng **đọc mã** ở `cd2ee572` và **truy vấn chỉ đọc**
trên CSDL dev ngày 2026-10-15 — không chạy backend, không sửa `src/Backend`.

**Vì sao client gửi đơn này:** backend vừa thêm `docs/Admin-web/Event-Notification-to-ClientApp.md` (19 sự kiện / tín
hiệu client phải xử lý, *"PO đã phê duyệt"*). Client đối chiếu từng mục với mã của **cả hai phía** và gặp A–C trên đường
đối chiếu. Phần client sẽ làm theo hợp đồng ấy (mục 5 cuối đơn) chờ backend đóng đơn này — người dùng chốt 2026-10-15.

---

## A. (CAO) AIOps khoá tài khoản bằng `Status = 'Locked'` → backend trả `ACCOUNT_DELETED` → client XOÁ dữ liệu trên máy

### Hiện tượng (chuỗi đầy đủ)

1. `modules/aiops/feature.collector.js` ~:209–227 — một IP đăng nhập sai (401) **≥ 15 lần** nhắm một `username` →
   `defaultAIOpsQuarantine.quarantinePair({ ip, username, … })`. **Bất kỳ ai** gõ sai mật khẩu 15 lần cho tên đăng nhập
   của người khác đều kích hoạt được.
2. `modules/aiops/aiops.quarantine.js:398` (trong `quarantinePair`) → `_syncAccountStatusToDatabase(…, 'Locked', …)`
   → `prisma.account.updateMany({ data: { status: 'Locked', … } })` qua `require('../../config/db')` (đường này **chạy
   được**). Cùng giá trị `'Locked'` còn ghi ở `aiops.quarantine.js:755`, `:841` và `aiops.controller.js:249`, `:305`.
   (`feature.collector.js:231` ghi thêm `'TemporarilyLocked'` nhưng `require('../../database/prisma')` **không tồn tại**
   → lệnh ấy ném, bị nuốt — hôm nay vô hại, nhưng là mã chết sai.)
3. `'Locked'` / `'TemporarilyLocked'` **nằm ngoài** tập trạng thái của lược đồ: `database/New_Database.sql:40`
   `CONSTRAINT "ck_account_status" CHECK ("Status" IN ('Active', 'Inactive', 'PendingDelete', 'Deleted'))`.
   **Nhưng CSDL dev không có ràng buộc ấy** — đo 2026-10-15: bảng `account` có 11 ràng buộc (9 NOT NULL, khoá chính,
   `fk_account_role`), **0 CHECK**. Nên lệnh ghi `'Locked'` **thành công**.
4. `middleware/auth.js` ~:31–34: `valid` chỉ khi `status` là `active` (chưa `delete_at`) hoặc `pendingdelete` còn hạn.
   `accountRejection` (:59–77): mọi trạng thái **không phải** `inactive` → `code: 'ACCOUNT_DELETED'`,
   `message: 'Account no longer exists or has been deleted'`. Tức `'Locked'` → **`ACCOUNT_DELETED`**.
5. Phía client (`src/Client-app`, đúng hợp đồng 401 đã chốt — CAN-LAM 13 / 19): `ACCOUNT_DELETED` → `lyDo = daXoa`
   (`lib/core/auth/buoc_dang_xuat.dart:152-153`) → AuthBloc **xoá toàn bộ SQLite của tài khoản** khi 401 đến từ request
   thường (`lib/features/auth/presentation/bloc/auth_bloc.dart:130-138`) — kể cả **giao dịch chưa kịp đồng bộ** — và hiện
   hộp thoại *"tài khoản đã bị xoá"*. 15 phút sau AIOps mở khoá (`'Active'`), người dùng đăng nhập lại kéo về phần đã
   đồng bộ; **phần chưa đồng bộ mất vĩnh viễn**.

Hiện CSDL dev **chưa có hàng nào** mang `'Locked'` (đo 2026-10-15: `SELECT DISTINCT "Status" FROM account` → chỉ
`Active`, `Deleted`) — **không cần sửa dữ liệu**, chỉ cần sửa mã và áp ràng buộc trước khi ca này xảy ra thật.

### Xin làm

1. AIOps khoá tài khoản thì ghi **`'Inactive'`** + `Reason_inactive` (giá trị đã có trong tập, client hiểu đúng là
   *bị khoá* và **giữ** dữ liệu). Không thêm giá trị trạng thái mới.
2. `accountRejection`: **mặc định an toàn là `ACCOUNT_INACTIVE`**; chỉ `Deleted`, `delete_at` đã qua, hoặc không còn
   hàng → `ACCOUNT_DELETED`. Một trạng thái lạ trong tương lai sẽ khoá người dùng chứ không làm máy họ xoá dữ liệu.
3. Mở khoá tự động (hết hạn cách ly — `aiops.quarantine.js` ~:141, :153) chỉ trả `'Active'` cho tài khoản **do chính
   AIOps khoá** — đừng mở một tài khoản admin đã đặt `Inactive` vì lý do khác.
4. Vá hoặc bỏ nhánh `feature.collector.js:231-238` (`require('../../database/prisma')` không tồn tại, giá trị
   `'TemporarilyLocked'` ngoài tập).
5. Áp lại `ck_account_status` lên CSDL bằng một tệp `database/N_*.sql` (quy ước `docs/Rule_Project/Rule_project.md`
   §3.2 — sổ ghi tệp đã áp). CSDL dev hôm nay không có hàng vi phạm nên áp thẳng được.
6. (Tuỳ chọn) Khi AIOps khoá một tài khoản, phát `account.force_logout` với `reason: 'ACCOUNT_INACTIVE'` như luồng
   admin khoá (`admin.service.js:186`) — client hiện hộp thoại ngay thay vì chờ request kế.

### Kiểm lại bằng

```sql
SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint
WHERE conrelid = '"account"'::regclass AND contype = 'c';          -- có ck_account_status
SELECT DISTINCT "Status" FROM account;                              -- chỉ trong 4 giá trị
```

Ca test: 15 lần `POST /api/auth/login` sai mật khẩu cho một `username` từ cùng IP → hàng `account` mang `Inactive`;
request có token của tài khoản ấy nhận **401 `ACCOUNT_INACTIVE`** (không phải `ACCOUNT_DELETED`).

---

## B. (CAO) Webhook PayOS gặp `orderCode` lạ → tạo đơn cho tài khoản `idaccount` nhỏ nhất → nâng Premium nhầm người

### Hiện tượng

`modules/payment/payment.service.js:86-94`: không thấy đơn → `paymentRepository.findOrCreateOrderByCode(orderCode,
amount)`. `modules/payment/payment.repository.js:80-85`:

```js
const targetAccount = await prisma.account.findFirst({ where: { delete_at: null }, orderBy: { idaccount: 'asc' } });
const accountId = targetAccount ? targetAccount.idaccount : 1;
```

Rồi luồng đi tiếp tới `activatePremiumSubscription({ idaccount: order.idaccount, … })` (`payment.service.js` ~:135) và
phát `account.upgraded` tới phòng của tài khoản ấy (~:171–175). Chữ ký webhook **đã được xác thực** (:70–78), nên đây
không phải giả mạo — tình huống thật là **một kênh PayOS phục vụ hai CSDL** (máy dev local và Render dùng chung khoá,
đơn tạo ở nơi này, webhook về nơi kia) hoặc webhook thử từ dashboard PayOS mang `orderCode` thật. Khi ấy tài khoản
`idaccount` nhỏ nhất còn sống (thường là tài khoản quản trị) được nâng Premium, còn người trả tiền thật thì không.

### Xin làm

- **Mặc định:** `orderCode` không có trong CSDL → ghi log + trả **2xx** (PayOS cần 2xx để thôi gửi lại), **không** tạo
  đơn, **không** nâng gói.
- Phương án hai (nếu muốn đối soát): lưu một bản ghi *"chưa khớp"* **không gắn `idaccount`** để trang lịch sử thanh toán
  admin vừa thêm (`/api/admin/payments/*`) hiện cho người đối soát tay.

### Kiểm lại bằng

Ca test webhook có chữ ký hợp lệ với `orderCode` không tồn tại → không hàng `payment_order` mới gắn tài khoản, không
`account.type` nào đổi, không `account.upgraded` nào phát.

---

## C. (VỪA) Đăng nhập lúc bảo trì trả 503 nhưng body **mất `code`**

`modules/auth/auth.service.js:370-386` ném lỗi `{ statusCode: 503, code: 'MAINTENANCE_MODE', isEmergency,
activatedAt }` cho tài khoản thường. Nhưng `modules/auth/auth.controller.js:59-67` chỉ chuyển `extra` (`code`,
`reason_inactive`) khi `statusCode === 403`; nhánh còn lại `ResponseHandler.error(res, message, 503)` → body chỉ
`{ success, message, errors, timestamp }`: **không `code`, không `isEmergency`, không `Retry-After`** — khác hẳn 503 của
`maintenance.middleware.js` (body có `code` + header `Retry-After: 60`).

**Xin làm:** cho nhánh 503 mang cùng `extra` (`code: 'MAINTENANCE_MODE'`, `isEmergency`, `activatedAt`) và header
`Retry-After: 60` như middleware. Client sẽ đọc đúng `code` này ở lượt làm dải bảo trì (mục 5) — thiếu `code` thì màn
Đăng nhập không phân biệt được bảo trì với lỗi máy chủ khác.

**Kiểm lại bằng:** bật bảo trì, `POST /api/auth/login` bằng tài khoản thường → 503, body có `code: "MAINTENANCE_MODE"`,
header `Retry-After`.

---

## D. (THẤP) Đính chính `docs/Admin-web/Event-Notification-to-ClientApp.md`

Tài liệu do backend tạo — client **không** sửa (quy tắc vùng chỉ đọc). Các chỗ lệch với mã `cd2ee572`:

| § | Tài liệu ghi | Mã thật |
|---|---|---|
| 4.5, 6 bước 3 (#4) | Body `FEATURE_DISABLED` lồng trong `data` (`data.code`), có `statusCode` | Body **phẳng**: `{ success, message, code, featureId, accountType, errors, timestamp }` (`middleware/feature-permission.middleware.js:46-55` → `core/response-handler.js:44-53`). Đoạn Dart `data['data']['code']` ở bước 3 **không bao giờ khớp**. |
| 3.8 | `summary: { created, updated, deleted }` | `summary: { total, synced, conflicts, errors }` (`modules/sync/sync.service.js:240`) |
| 3.4 | Phần tử `updates`: `{ idaccount_type, idfeature, … }`; route `PUT /api/admin/permissions/matrix` | Hàng Prisma `account_type_permission` (`account_type`, `feature_id`, `is_enabled`, `limit_value`, …); route `PUT /api/admin/permissions` (`api/admin.routes.js:62`) |
| 3.5 | Một hình dạng payload | Hai: theo phòng `{ type, premiumExpiresAt }` (webhook) và **toàn cục** `{ reason: 'PERMISSIONS_MATRIX_UPDATED', updates }` (`core/socket.js:383-386`, gửi cả tài khoản Basic) |
| 3.11 | `user.notification` là sự kiện sống | **Không bao giờ phát**: `sendDirectNotification` chỉ được `notifyUser` gọi, `notifyUser` không có chỗ gọi (`notification.service.js:233`, `:268`; ngoài ra chỉ test) |
| 3.7 | Phát khi người dùng gửi yêu cầu xoá | Chỉ phát lúc 00:00 từ bộ hẹn giờ (`core/scheduler.service.js` ~:164–192); yêu cầu xoá chỉ phát `admin.user_status_changed` |
| 3.9 · 3.10 | `data.predicted_category_id`, `confidence`; `reason: "DUPLICATE_RECEIPT_HASH"` | Không có hai trường đầu (`ocr.service.js:133-149`); `reason` ∈ `duplicate_bank_tran_id` · `fuzzy_invoice_matched` · `transfer_sms_matched` |
| 3.2 | Tắt bảo trì thì `reason: null` | Thêm trường `scheduled`; `reason` không về `null` khi tắt (`maintenance.manager.js` `getStatus`) |
| 4.2 | Ngưỡng cắt tải 100 ms | **250 ms** (`core/resilience/event-loop-monitor.js:9`) |
| 3.1, 3.3 | Route `PATCH /api/admin/users/:id/status`; `POST /api/admin/system/broadcast` | `PATCH /api/admin/updatestatus/:id`, `DELETE /api/admin/deleteuser/:id` (`api/admin.routes.js:50-52`); `POST /api/notifications/broadcast` (`api/notification.routes.js:42`) |
| 4.6 | "Refresh Token đã bị huỷ trên server" khi admin khoá | Khoá **không** thu hồi refresh token (chỉ xoá mềm mới thu hồi — `admin.repository.js:177`); `/auth/refresh` vẫn trả 401 `ACCOUNT_INACTIVE` nên kết quả phía client giống nhau |
| 1 (thêm) | — | Sự kiện có thể tới **hai lần**: `core/event-bus.js` phát cục bộ (:25) rồi phát lại qua Redis khi Redis sẵn sàng. Client chịu được (đồng bộ luỹ đẳng) — chỉ cần ghi vào tài liệu. |

**Đính chính bảng §5 (hiện trạng client) — để lần đối chiếu sau không gắn cờ lại:**

- 503 `MAINTENANCE_MODE` không gây *"lỗi mạng chung chung"*: đồng bộ thất bại **im lặng** rồi giãn cách 30 s → 1' → 5' →
  15' → 60'; màn Đăng nhập hiện đúng `message` của server.
- 503 `SERVER_OVERLOADED` / 429 `RETRY_LIMIT_EXCEEDED`: giãn cách ≥ 30 s của client đã dài hơn 5–10 s backend yêu cầu;
  client **không gửi** `x-retry-count` nên vế *"reset bộ đếm"* không áp dụng. *(2026-10-26: client nay nhận ra 503
  `SERVER_OVERLOADED` / `DB_POOL_OVERLOADED` ở lượt đẩy và không tính là chu kỳ hỏng — tối đa 3 chu kỳ liên tiếp; 429 vẫn
  không có nhánh riêng: `retry-guard` chỉ chặn POST trùng **y body** > 3 lần / 10 s, mà body `/sync/push` mang `pushedAt`
  theo mili giây, `/sync/pull` và `order-status` là GET.)*
- 403 `FEATURE_DISABLED`: hiện **không chạm được** — client không gọi `/api/ai/*` (Trợ lý AI, quét ảnh chạy trên máy;
  quyền chặn trước ở client theo `/subscription-info`).
- `account.countdown`: số ngày lấy từ `/auth/profile` mỗi lần mở app rồi **tự trừ theo ngày** ở máy.
- `account.downgraded`: hết hạn thì app **tự về Basic theo giờ máy** (`premiumExpiresAt`); thứ thiếu chỉ là phản ứng tức
  thì khi admin hạ gói trước hạn — client làm ở mục 5.
- `user.notification`: mã chết phía backend (xem bảng trên) — client không làm gì.

---

## 5. Client sẽ làm gì sau khi backend đóng đơn này

Người dùng chốt 2026-10-15: client làm **một lượt** khi backend xong A–C:

1. Xét lại cách xử lý `ACCOUNT_DELETED` từ request thường (phòng thủ cho ca A) — nếu A sửa đúng thì có thể không cần.
2. Socket bị từ chối lúc bắt tay (`connect_error` có `data.code` `ACCOUNT_INACTIVE` / `ACCOUNT_DELETED`) → dừng nối lại
   và đăng xuất kèm lý do (hôm nay client nối lại mỗi 60 s mãi mãi).
3. `account.downgraded` → làm mới gói ngay (cùng khuôn `account.upgraded`: tín hiệu, gọi `/subscription-info`).
4. Dải *"Hệ thống đang bảo trì"* / *"Thiết bị tạm bị phong toả"* — đọc **mã HTTP + `code`** của 503 `MAINTENANCE_MODE`
   và 403 `AIOPS_QUARANTINED` (cần mục C để màn Đăng nhập nhận ra bảo trì).

Backend **không phải làm gì thêm** cho bốn việc ấy ngoài A–C.
