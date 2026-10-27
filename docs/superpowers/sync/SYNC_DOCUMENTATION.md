# Đồng bộ dữ liệu FlowMoney — hợp đồng Client-app (SQLite / Drift) ↔ Backend (PostgreSQL)

> **Tệp DUY NHẤT về đồng bộ** (gộp 2026-10-26 theo yêu cầu người dùng). Thay cho hai tệp từng song song: bản cũ của chính tệp này và
> `docs/Admin-web/Sync-To-ClientApp.md` v3.2 (backend viết 2026-10-23) — tệp kia nay chỉ còn vài dòng trỏ về đây.
>
> **Người đọc:** client, backend, Admin-web. **Người giữ:** client (tệp do client tạo 2026-09-14). Backend muốn đổi nội dung thì ghi vào mục
> **14 *Trao đổi*** cuối tệp hoặc đặt đơn `docs/superpowers/backend/CAN-LAM/` — **đừng viết đè cả tệp** (đã xảy ra ba lần: `6cbd248e`,
> `36f1ea43`, `bc4e4f7f`; lần nào cũng mất ghi chú và thêm chỗ sai — đơn 49 vế A).
>
> **Soát:** 2026-10-26 — đọc mã client HEAD (`106a2135`) và backend `2b926d92` (gộp `3636110d`). Bảng trường mục 4 dựng **bằng máy** từ ba
> nguồn: tập khoá trong `src/Client-app/test/core/sync/sync_payload_contract_test.dart`, `src/Backend/prisma/schema.prisma`, và các khoá mà
> `src/Client-app/lib/core/sync/anh_xa_keo_ve.dart` đọc.
>
> ⚠️ **Nguồn sự thật về TÊN TRƯỜNG là tệp test hợp đồng**, không phải tệp này (quy tắc 4 `CLAUDE.md`). Payload đi qua ba nơi định nghĩa độc lập
> — client dựng tay → `SyncPayloadNormalizer` → `mapEntityFields` của backend — và **tên sai thì bị bỏ qua im lặng**, không lỗi nào báo ra. Thêm
> trường mới cho đồng bộ là phải sửa tệp test cùng lúc. Tệp này lệch tệp test thì tệp test thắng.

---

## 1. Tổng quan

- **Offline-first.** Mọi ghi chép vào SQLite (Drift, schema **v31**) trước; `SyncEngine` (`src/Client-app/lib/core/sync/`) đồng bộ nền sau. Đồng
  bộ có **sáu thực thể**: `wallet`, `transaction`, `category`, `budget`, `bill`, `goal` (`enum SyncEntityType`). Mọi bảng khác của client là
  cục bộ (mục 6).
- **Khoá chính** là UUID v4 (36 ký tự) do **client** sinh khi ghi, kể cả offline; server giữ nguyên. Id cũ không đúng dạng UUID được đổi qua
  `toValidUuid` khi đẩy.
- **Xung đột: ghi-sau-thắng (LWW) theo `update_at`** — giờ ghi của máy, gửi trong payload. Server so với `Update_at` của hàng đang có; payload cũ
  hơn ⇒ kết quả `conflict`, server giữ bản của nó.
- **Xoá mềm** ở cả hai đầu (quy tắc 5): client đặt `isDeleted` / `deletedAt`, server đặt `Delete_at` (giao dịch: `Deleted_at`). Không xoá cứng
  hàng đã từng đồng bộ — client còn bản sao sẽ đẩy lên và nhận `Record not found` mãi.
- **Tài khoản:** client lấy `idaccount` **chỉ** từ phiên đăng nhập (quy tắc 2 — không suy từ dữ liệu, không mặc định `1`, tài khoản admin thật);
  server lấy từ JWT.
- **Một chu kỳ:** gom thao tác chờ (`thu_gom_day.dart`) → `POST /api/sync/push` (`gui_lo_dong_bo.dart`) → phát `pushResultStream` **trước** bước
  kéo → `GET /api/sync/pull` (`ap_du_lieu_keo_ve.dart`, `anh_xa_keo_ve.dart`) → tính lại số dư ví.

## 2. Đẩy lên — `POST /api/sync/push`

### 2.1 Thân request

```json
{ "clientId": "flutter-client-app", "pushedAt": "2026-10-26T08:00:00.123Z",
  "operations": [ { "localId": "…", "entity": "transaction", "operation": "update", "payload": { … }, "createdAt": "…" } ] }
```

- `operation`: client chỉ gửi **`update`** (cả tạo lẫn sửa — server upsert) hoặc **`delete`** (khi hàng mang `isDeleted`). `create` có trong enum
  nhưng không dùng.
- `delete` ⇒ server gọi `softDelete` theo khoá chính (không qua `mapEntityFields`).
- Payload mang `update_at` (normalizer đổi `updated_at` → `update_at`) và `is_deleted` ở cả sáu thực thể — xem cảnh báo mục 9.1.

### 2.2 Thứ tự

Server sắp lại mảng theo `ENTITY_PRIORITY` (`src/Backend/modules/sync/sync.service.js:48-63`): **tạo / sửa** theo trọng số tăng dần, **xoá**
theo `100 − trọng số`.

| Thực thể | Tạo / sửa | Xoá | Vì sao |
|---|:-:|:-:|---|
| `category` | 10 | 90 | cha của mọi thứ |
| `wallet` | 20 | 80 | nguồn tiền |
| `goal` | 30 | 70 | `transaction.Idgoal` có khoá ngoại |
| `bill` | 31 | 69 | `transaction.Idbill` có khoá ngoại (`fk_transaction_bill`) |
| `budget` | 32 | 68 | |
| `transaction` | 40 | 60 | trỏ ví, danh mục, mục tiêu, hoá đơn |

Client **cũng** gom theo đúng thứ tự ấy (mục tiêu và hoá đơn trước giao dịch — hai ca canh trong tệp test), để lô vẫn đúng nếu server thôi sắp.

### 2.3 Kết quả

HTTP **200** cho cả lô; `data.results[i] = { localId, status, code?, message? }`, `data.summary = { total, synced, conflicts, errors }`.

| `status` | Client làm gì |
|---|---|
| `synced` | đánh dấu `synced` |
| `conflict` | **cũng** đánh dấu `synced` (server thắng; bản thắng về máy ở bước kéo ngay sau, cùng chu kỳ) |
| `error` + thao tác `delete` + thông điệp *Record not found* | coi như xong (đích của lệnh xoá đã đạt) |
| `error` khác | phân loại theo `code` (2.4) |

### 2.4 Lỗi vĩnh viễn — danh sách TRẮNG

`_permanentCodes` (`src/Client-app/lib/core/sync/gui_lo_dong_bo.dart`, đếm 2026-10-27: **15** mã): `UNIQUE_VIOLATION` · `CATEGORY_NAME_DUPLICATE` ·
`CONSTRAINT_VIOLATION` · `FORBIDDEN_SYSTEM_DEFAULT` · `WALLET_NAME_DUPLICATE` · `WALLET_DEFAULT_DUPLICATE` · `BILL_ALREADY_PAID` ·
`BILL_PERIOD_ALREADY_PAID` · `NOT_OWNER` · `HOUSEHOLD_NOT_MEMBER` · `HOUSEHOLD_READ_ONLY` · `HOUSEHOLD_CLOSED` · `HOUSEHOLD_SCOPE_MISMATCH` ·
`HOUSEHOLD_ROLE_FORBIDDEN` · `HOUSEHOLD_WALLET_LIMIT`
(bảy mã cuối thêm sẵn cho chức năng gia đình — `docs/Family/`; năm mã đầu của đơn 50 thêm 2026-10-26, hai mã cuối do `docs/Family/`
đề xuất thêm 2026-10-27 khi backend **chưa** chấp nhận tên — backend đổi tên thì client sửa theo).

- Mã vĩnh viễn ⇒ hàng không bị gửi lại; có bộ nghe gỡ hậu quả (mục 2.6).
- **Mọi mã khác — kể cả `DB_ERROR` và mã chưa có tên — là lỗi TẠM**: hàng ở lại `pending`, giãn cách luỹ tiến (`syncRetryCount`,
  `syncBlockedUntil`), **gửi lại ở các chu kỳ sau**. Backend thêm một từ chối dữ liệu mới thì phải ném lỗi có `code` riêng và báo client thêm
  vào danh sách **trước** khi bật — nếu không là vòng gửi lại vô hạn, im lặng (lớp lỗi G14 / G31).

### 2.5 Lỗi cấp HTTP (cả lô)

| Phản hồi | Client |
|---|---|
| 401 | `AuthInterceptor` làm mới token một lần; phiên chết thật ⇒ đăng xuất kèm lý do, **không xoá SQLite** (G89) |
| 503 `MAINTENANCE_MODE` · 403 `AIOPS_QUARANTINED` | `MayChuInterceptor` ⇒ dòng nhắc trạng thái máy chủ; đồng bộ chờ |
| 503 `SERVER_OVERLOADED` (event loop > 250 ms, có `Retry-After`) · 503 `DB_POOL_OVERLOADED` (không header) | **không** tính lượt hỏng, hẹn lại theo `Retry-After` (sàn 30 s), tối đa 3 chu kỳ liên tiếp rồi mới coi như lỗi thường (`SyncEngine.soLanQuaTaiKhongTinh`) |
| 429 `RETRY_LIMIT_EXCEEDED` | lỗi tạm. Cơ chế thật (`retry-guard.middleware.js`): > 3 request **ghi trùng y hệt** (IP, method, URL, body) trong 10 s, hoặc header `x-retry-count` > 3. Mỗi lô của client mang `pushedAt` khác nên không chạm; client **không** gửi `x-retry-count` |
| 5xx khác, lỗi mạng | lỗi tạm |

### 2.6 `pushResultStream`

`SyncEngine` phát kết quả đẩy **trước** bước kéo (`sync_push_result_truoc_pull_test.dart` canh): người nghe thường phải bù một thay đổi máy này
vừa ghi, và kéo về ở giữa sẽ thay đúng hàng ấy. Hai bộ nghe hiện có: `BillPaymentConflictResolver` (gỡ khoản trả bị `BILL_ALREADY_PAID` /
`BILL_PERIOD_ALREADY_PAID`) và `ViTrungTenResolver` (ví bị `WALLET_NAME_DUPLICATE`). Kết quả của lần **thử lại** phát ở cuối chu kỳ ⇒ người
nghe phải chịu được **hai** lượt phát cho cùng một thất bại.

## 3. Kéo về — `GET /api/sync/pull?since=<ISO 8601 UTC>`

### 3.1 Phản hồi

```json
{ "data": { "pulledAt": "2026-10-26T08:00:01.000Z", "hasMore": false,
            "maxSince": { "wallet": "…", "transaction": "…" },
            "data": { "wallets": [ … ], "transactions": [ … ], "budgets": [ … ], "bills": [ … ], "goals": [ … ], "categories": [ … ] } } }
```

- Server trả hàng của tài khoản (`Idaccount`; danh mục: `Create_by`) **cộng** danh mục mặc định (`Is_default = true`), lọc `Server_update_at >
  since` (cột giờ server + trigger — migration 20, 21), **gồm cả hàng đã xoá mềm** để máy khác nhận cờ xoá.
- `maxSince[entity]` = `Server_update_at` của hàng cuối mỗi bảng; `hasMore` = ước lượng (≥ 500 hàng).

### 3.2 Mốc kéo về (G67)

- `mocTuMaxSince` (`core/sync/moc_keo_ve.dart`): **lớn nhất** giữa các bảng trong `maxSince`, kẹp về `pulledAt − 2 phút` khi còn nóng (hàng ghi
  xen giữa các truy vấn tuần tự), +1 ms khi nguội (µs → ms). ⚠️ Đừng đổi sang **nhỏ nhất**: đo trên máy ảo, mốc neo vào bảng lâu không đổi và mỗi
  lượt kéo lại gần hết. Phản hồi không có `maxSince` ⇒ rơi về `update_at`.
- Lưu bền theo tài khoản: khoá **`sync_last_pull_v2_<idaccount>`** (`SyncCheckpointStore`). SQLite trống hoặc chưa có mốc ⇒ `since =
  1970-01-01`. Đăng xuất ⇒ mốc trong RAM về `null`.

### 3.3 Áp vào SQLite

- **`insertAllOnConflictUpdate`, không `insertOrReplace`** (quy tắc 3): thay cả hàng là đưa mọi cột không gán về mặc định.
- **Khoá vắng ⇒ `Value.absent()`** (giữ giá trị cục bộ) cho các cột nối / cột thêm sau: `include_in_total`, `status` của ví, `idgoal`, `idbill`,
  ba cột nối của hoá đơn, `color` của danh mục…
- **`balance` của ví KHÔNG đọc** (G37): số dư là cache của tổng sổ giao dịch, tính lại sau mỗi lượt kéo (`SoDuViService` — nơi duy nhất ghi
  `balance`). Ví vừa kéo về mang `balance = 0` nghĩa là *chưa biết*.
- **G85:** vá neo *Số dư ban đầu* cho ví đã có trên máy **trước** khi ghi giao dịch vừa kéo về; ví đích của khoản chuyển vừa về cũng tính lại.
- **Danh mục mặc định** (`is_default = true`) lưu cục bộ với `idaccount = 0` (server: `Create_by` mặc định **1** — đừng lẫn); sau mỗi lượt kéo
  `DefaultCategorySeeder` sao bộ mặc định thành bản riêng của tài khoản (quy tắc 8); từ khoá server gieo vào bảng từ khoá cục bộ chỉ khi bảng ấy
  trống (`gieoTuKhoaKhiTrong`).
- Có ví mặc định kéo về ⇒ máy chỉ còn một ví mặc định (G63).

### 3.4 Lỗi khi kéo

Client nuốt lỗi kéo (`ap_du_lieu_keo_ve.dart`): mốc không tiến, lượt sau thử lại; dữ liệu cục bộ không bị đụng. ⚠️ Xem mục 9.2 — một hàng giải mã
hỏng làm **mọi** lượt kéo của tài khoản trả 500.

## 4. Sáu thực thể — bảng trường

Cột *Đẩy* = khoá trong payload `/sync/push` (tệp test). Cột *Kéo* = khoá `anh_xa_keo_ve.dart` đọc từ `/sync/pull` (khoá trong ngoặc = dạng thay
thế cũng nhận). Cột PostgreSQL = `@map` + kiểu trong `schema.prisma`.

### 4.1 Ví — `wallet` (đẩy **13** khoá)

| Đẩy | PostgreSQL | Kéo | Ghi chú |
|---|---|---|---|
| `id` | `Idwallet` varchar(36) | `idwallet` (`id`) | |
| `idaccount` | `Idaccount` int | `idaccount` | |
| `name` | `Name` varchar(100) | `name` | ô nhập cắt theo code point (`GioiHanDoRong`); duy nhất trong tài khoản (`WALLET_NAME_DUPLICATE`) |
| `type` | `Type` varchar(7) | `type` | `cash`/`bank`/`saving`/`banking` ↔ `Cash`/`Bank`/`Saving`/`Banking` (`chk_wallet_type`); giá trị lạ gửi `Cash` |
| `balance` | `Balance` decimal(15,2) | — | **một chiều**: đẩy để PostgreSQL đo được, kéo về không đọc (G37) |
| `currency` | `Currency` varchar(3) | `currency` | `VND` / `USD` (`chk_wallet_currency`); lạ ⇒ `VND` |
| `icon` | `Icon` varchar(20) | `icon` | |
| `color` | `Color` varchar(20) | `color` (`colour`) | SQLite cột `colour`, normalizer đổi tên |
| `is_default` | `Is_default` bool | `is_default` | một ví mặc định mỗi tài khoản (`uq_wallet_default_active`) |
| `is_deleted` | `Delete_at` timestamp | `delete_at` | |
| `include_in_total` | `IncludeInTotal` bool | `include_in_total` | vắng ⇒ giữ cục bộ |
| `status` | `Status` varchar(20) | `status` | `active`/`inactive` ↔ `Active`/`Inactive` (`chk_wallet_status`, G28; máy chủ chưa áp `database/7` từ chối `Inactive`) |
| `update_at` | `Update_at` timestamp | `update_at` | LWW |

Không đi chiều nào: `Id_bank_casso` (nhóm bỏ liên kết ngân hàng 2026-09-18).

### 4.2 Giao dịch — `transaction` (đẩy **13** khoá)

| Đẩy | PostgreSQL | Kéo | Ghi chú |
|---|---|---|---|
| `id` | `Idtran` varchar(36) | `idtran` (`id`) | |
| `idaccount` | `Idaccount` int | `idaccount` | |
| `walletId` | `Idwallet` varchar(36) | `idwallet` (`wallet_id`) | SQLite `wallet_id` |
| `categoryId` | `Idcategory` varchar(36)? | `idcategory` (`category_id`) | khoản chuyển gửi `null` |
| `idwallet_transfer` | `Idwallet_transfer` varchar(36)? | `idwallet_transfer` (`wallet_transfer`) | ví đích của khoản chuyển; SQLite không khai khoá ngoại |
| `amount` | `Amount` decimal(15,2) | `amount` | **SQLite luôn dương**, chiều ở `type`. Đẩy: chi ⇒ **âm**, thu ⇒ dương, chuyển ⇒ dương |
| `type` | `Type` varchar(20) | `type` | `thu`/`chi` ⇒ `Transaction`, `transfer` ⇒ `Transfer` (`chk_txn_type`). Kéo: `Transfer` ⇒ `transfer`, còn lại theo dấu `amount` |
| `note` | `Note` text | `note` | server mã hoá at-rest, trả bản rõ khi kéo |
| `dateTransaction` | `DateTransaction` timestamp | `date_transaction` (`date`) | |
| `idgoal` | `Idgoal` varchar(36)? | `idgoal` (`goal_id`) | **không** gửi `goal_id` (tên cột cục bộ, nằm trong danh sách cấm rò); vắng ⇒ giữ |
| `idbill` | `Idbill` varchar(36)? | `idbill` (`bill_id`) | hoá đơn phải lên trước (2.2) |
| `is_deleted` | `Deleted_at` (có **d**) | `deleted_at` | |
| `update_at` | `Update_at` timestamp | `update_at` | |

Không đi chiều nào, **cố ý** (quy tắc 4): `Provider`, `Bank_tran_id`, `Status`, `Images` — đừng thêm vào payload.

### 4.3 Danh mục — `category` (đẩy **12** khoá, **13** khi có từ khoá)

| Đẩy | PostgreSQL | Kéo | Ghi chú |
|---|---|---|---|
| `id` | `Idcategory` varchar(36) | `idcategory` | |
| `idaccount` | `Create_by` int (mặc định server: 1) | `create_by` (`created_by`, `idaccount`) | hàng mặc định ⇒ client lưu `idaccount = 0` (3.3) |
| `name`, `namecategory` | `NameCategory` varchar(200) | `name_category` (`namecategory`, `name`) | client gửi **cả hai** khoá; backend đọc `name` |
| `classify` | `Classify` varchar(7) | `classify` | `chi`/`thu`/`vay_no` ↔ `Chi`/`Thu`/`Vay/no` (`ck_category_classify`); trống ⇒ `Chi` |
| `icon` | `Icon` varchar(20) | `icon` | |
| `color` | `Color` varchar(9) | `color` | vắng / `null` ⇒ giữ màu cục bộ (G24) |
| `is_default` | `Is_default` bool | `is_default` | |
| `isGroup` | `Is_group` bool | `is_group` | thiếu là mất cấu trúc nhóm sau mỗi lượt kéo |
| `parentId` | `Idgroup` varchar(36)? | `idgroup` (`parent_id`) | |
| `keyword` | `Keyword` text | `keyword` (gieo khi trống) | **chỉ gửi khi có từ khoá** — chuỗi rỗng là lệnh xoá ở server |
| `is_deleted` | `Delete_at` timestamp | `delete_at` | |
| `update_at` | `Update_at` timestamp | `update_at` | |

Tên duy nhất trong tài khoản, tính cả danh mục mặc định, so bằng `normalizeCategoryName` (quy tắc 7) — server: `uq_category_owner_name`,
`uq_category_default_name` ⇒ `CATEGORY_NAME_DUPLICATE`.

### 4.4 Ngân sách — `budget` (đẩy **17** khoá)

| Đẩy | PostgreSQL | Kéo | Ghi chú |
|---|---|---|---|
| `id` | `Idbudget` varchar(36) | `idbudget` (`id`) | |
| `idaccount` | `Idaccount` int | `idaccount` | |
| `idcategory` | `Idcategory` varchar(36)? | `idcategory` (`category_id`) | `null` = ngân sách tổng |
| `total_amount` | `TotalAmount` decimal(15,2) | `total_amount` (`amount`) | SQLite cột `amount`; **không** có cột `period` |
| `spent` | `Spent` decimal(15,2) | `spent` | |
| `threshold_warning_amount` | `Threshold_Warning_Amount` decimal(15,2)? | như trên | |
| `threshold_warning_percent` | `Threshold_Warning_Percent` decimal(15,2)? | như trên | 0–100 |
| `over_spending` | `OverSpending` varchar(7) | `over_spending` | `Stop` / `Over` |
| `over_amount` | `OverAmount` decimal(15,2)? | `over_amount` | |
| `start` | `Start` timestamp | `start` (`start_date`) | mốc gốc của chu kỳ (kỳ tính bằng số học, không sinh hàng mới) |
| `end` | `End` timestamp? | `end` (`end_date`) | |
| `recurrence` | `Recurrence` bool | `recurrence` | |
| `time_recurrence` | `Time_recurrence` varchar(7)? | `time_recurrence` | |
| `nexttime_recurrence` | `Nexttime_recurrence` timestamp? | `nexttime_recurrence` | client không tự sinh, nhưng **đẩy lại nguyên vẹn** giá trị đã có |
| `note` | `Note` text | `note` | |
| `is_deleted` | `Delete_at` timestamp | `delete_at` | |
| `update_at` | `Update_at` timestamp | `update_at` (`updated_at`) | |

### 4.5 Hoá đơn — `bill` (đẩy **21** khoá)

| Đẩy | PostgreSQL | Kéo | Ghi chú |
|---|---|---|---|
| `id` | `Idbill` varchar(36) | `idbill` (`id`) | mỗi **kỳ** là một hàng |
| `idaccount` | `Idaccount` int | `idaccount` | |
| `idwallet` | `Idwallet` varchar(36) | `idwallet` (`wallet_id`) | `fk_bill_wallet` RESTRICT — không xoá được ví gắn hoá đơn |
| `idcategory` | `Idcategory` varchar(36) (NOT NULL) | `idcategory` (`category_id`) | |
| `name` | `Name` varchar(100) | `name` | |
| `amount` | `Amount` decimal(15,2) | `amount` | |
| `start_date` | `Start_date` timestamp | `start_date` | |
| `due_date` | `Due_date` timestamp | `due_date` | |
| `pay_status` | `Pay_status` varchar(7) | `pay_status` | `Pending` · `Payed` · `Overdue` · `Skipped` — đi **nguyên văn**; định nghĩa trạng thái trả ở `bill_pay_status.dart` |
| `recurrence` | `Recurrence` bool | `recurrence` | |
| `time_recurrence` | `Time_recurrence` varchar(7)? | `time_recurrence` | |
| `time_notification` | `Time_notification` varchar(7)? (mặc định `'3'`) | `time_notification` | **`null` = tắt nhắc**, đi nguyên văn cả hai chiều (đơn 45 — backend sửa ở `49eafef6`, client soát đạt 2026-10-26) |
| `icon` | `Icon` varchar(20) | `icon` | |
| `color` | `Color` varchar(20) | `color` | |
| `note` | `Note` text | `note` | |
| `previous_bill_id` | `Previous_bill_id` varchar(36)? | `previous_bill_id` | SQLite `generatedFromBillId`; vắng ⇒ giữ (đọc thẳng là cắt chuỗi kỳ) |
| `anchor_day` | `Anchor_day` smallint? | `anchor_day` | ngày gốc 1–31; vắng ⇒ giữ |
| `period_end` | `Period_end` **date** | `period_end` | gửi **nửa đêm UTC của ngày cục bộ** (gửi `toUtc()` thô là lùi một ngày ở múi +07) |
| `auto_pay` | `Auto_pay` bool | `auto_pay` | **bool thật**, không chuỗi |
| `is_deleted` | `Delete_at` timestamp | `delete_at` | |
| `update_at` | `Update_at` timestamp | `update_at` (`updated_at`) | |

### 4.6 Mục tiêu — `goal` (đẩy **22** khoá)

| Đẩy | PostgreSQL | Kéo | Ghi chú |
|---|---|---|---|
| `id` | `Idgoal` varchar(36) | `idgoal` (`id`) | |
| `idaccount` | `Idaccount` int | `idaccount` | |
| `idwallet` | `Idwallet` varchar(36)? | `idwallet` (`wallet_id`) | ví **nhận** (tích luỹ) |
| `name` | `Name` varchar(100) | `name` | |
| `target_amount` | `Target_amount` decimal(15,2) | `target_amount` | |
| `current_amount` | `Current_amount` decimal(15,2) | `current_amount` | cột cộng dồn, LWW |
| `start_date` | `Start_date` timestamp | `start_date` | |
| `target_date` | `Target_date` timestamp | `target_date` | |
| `cycle_take_money` | `Cycle_take_money` varchar(7)? | `cycle_take_money` | |
| `time_cycle_take_money` | `Time_cycle_take_money` timestamp? | `time_cycle_take_money` | mốc neo nhịp trích |
| `status_complete` | `Status_complete` varchar(20) | `status_complete` | chuỗi `'True'` / `'False'`; kéo về nhận mọi dạng đúng / sai |
| `recurrence` | `Recurrence` bool | `recurrence` | |
| `time_recurrence` | `Time_recurrence` varchar(7)? | `time_recurrence` | |
| `icon` | `Icon` varchar(20) | `icon` | |
| `color` | `Color` varchar(20) | `color` | |
| `note` | `Note` text | `note` | |
| `auto_deposit_amount` | `auto_deposit_amount` decimal(18,2)? | như trên | ⚠️ **ba cột trích tự động phải đi CÙNG NHAU** — thiếu `last_run` là hai máy cùng trích |
| `auto_deposit_wallet_id` | `auto_deposit_wallet_id` varchar(36)? | như trên | ví **nguồn** |
| `auto_deposit_last_run` | `auto_deposit_last_run` timestamp? | như trên | mốc kỳ gần nhất đã trích |
| `priority` | `Priority` int? | `priority` | kéo thả, khe 100; `null` = chưa sắp (xếp cuối); `0` cũ gửi lên thành `null` (G32) |
| `is_deleted` | `Delete_at` timestamp | `delete_at` | |
| `update_at` | `Update_at` timestamp | `update_at` (`updated_at`) | |

## 5. Phép đổi giá trị (tóm tắt — `sync_payload_normalizer.dart`)

| Trường | SQLite / client | Gửi lên | Kéo về |
|---|---|---|---|
| giao dịch `type` + `amount` | `chi` / `thu` / `transfer`, số dương | `Transaction` + âm / `Transaction` + dương / `Transfer` + dương, `categoryId: null` | `Transfer` ⇒ `transfer`; còn lại âm ⇒ `chi`, dương ⇒ `thu` |
| ví `type` | `cash` `bank` `saving` `banking` | chữ hoa đầu; lạ ⇒ `Cash` | chữ thường |
| ví `status` | `active` / `inactive` | `Active` / `Inactive`; lạ ⇒ `Active` | chữ thường |
| ví `currency` | | `VND` / `USD`; lạ ⇒ `VND` | |
| danh mục `classify` | `chi` `thu` `vay_no` | `Chi` `Thu` `Vay/no` | về dạng so sánh được (chấp nhận cả `Vay/nợ`) |
| màu ví / danh mục | cột `colour` | khoá `color` | đọc `color` |
| mục tiêu `priority` | `null` / bội 100 | `≤ 0` ⇒ `null` | `≤ 0` đọc là `null` |
| hoá đơn `period_end` | ngày cục bộ | `YYYY-MM-DDT00:00:00.000Z` của ngày cục bộ | |
| thời gian | `DateTime` | ISO 8601 UTC | |

## 6. Chỉ có ở client — KHÔNG đồng bộ

**Bảng cục bộ** (Drift v31): `CategoryKeywords`, `CategoryGroupMemberships` (cấu trúc nhóm cục bộ — server dựng từ `isGroup` / `parentId`),
`AppNotifications`, `AppNotificationEvents` (thông báo suy lại được trên từng máy — quy tắc 9), `AiRebalancingFeedbacks`, `GoiYDanhMucPhanHois`,
`GoiYHoaDonPhanHois`, `PhanTichGiayXems`, `PhanTichThuTuPhanHois`, `KhoaTuChuyenTiens` (khoá thuê bộ chạy nền), `DanhMucAiDoans`. Thêm chúng vào
`SyncEntityType` là sai (test quét 15 canh các bảng v24–v31).

**Cột cục bộ trên bảng đồng bộ:** `wallets.allow_negative` (quét 7), `wallets.bi_tu_choi_trung_ten` (G63), `wallets.bank_casso_id` (hàng cũ),
`categories.ai_co_dinh`, `transactions.status` / `provider` / `images` / `bank_tran_id`, và nhóm cột theo dõi đẩy `syncStatus` · `syncRetryCount`
· `syncError` · `syncBlockedUntil` (cấm rò lên server — ca *KHÔNG được rò rỉ trường thuần client* của tệp test).

**Client KHÔNG có** bảng `user_profile`, `device_tracking`, `permissions_cache` (bản `Sync-To-ClientApp.md` cũ mục 4 tả như bắt buộc): người dùng
+ token ở `FlutterSecureStorage`; gói + quyền tính năng lấy từ `GET /payment/subscription-info` (`features` / `limits`), nhớ theo tài khoản ở
secure storage (`GoiRepository`); tên máy không lưu (mục 8).

## 7. Thời gian thực

Backend phát **`sync.completed`** (`sync.service.js:245` → event bus → phòng `account_<id>`) sau mỗi `/sync/push`. Client nghe tên sự kiện
(`RealtimeEvent.dongBoXong`) ⇒ `syncNow()`, **im lặng** (máy vừa đẩy cũng nhận lại sự kiện của chính mình). Payload là hộp đen — client chỉ đọc
tên sự kiện (cam kết của kênh thời gian thực; ngoại lệ duy nhất `account.force_logout`).

## 8. Header thiết bị

Client gửi **`x-device-name`** (vd. `Realme RMX2205 (Android 13)`) trên **Android** ở Dio chung và Dio `/auth/refresh`, lấy qua kênh Kotlin
`flowmoney/thiet_bi` (`core/api/ten_thiet_bi.dart`; không `device_info_plus`), đọc một lần lúc khởi động. Web / iOS chưa gửi. Client **không**
gửi `x-platform` (backend không đọc ở đâu) và **không** tự gọi dịch vụ ngoài để lấy IP — backend lấy IP của request và che bớt khi lưu
`account_device_history`.

## 9. Vấn đề backend đang mở ảnh hưởng đồng bộ (soát 2026-10-26)

### 9.1 ⚠️ `is_deleted: false` xoá cờ xoá mềm ở server (`bc4e4f7f`)

`mapEntityFields` nay ánh xạ `is_deleted` → `delete_at` cho cả sáu thực thể (`sync.repository.js:32, 62, 92, 133, 168, 185`). Client gửi
`is_deleted` trong **mọi** payload, nên mỗi lượt **cập nhật** mang `false` ⇒ nhánh sửa đặt `delete_at = null` (trước commit này khoá bị bỏ qua
và nhánh sửa giữ `existing.delete_at`). Hệ quả: máy B sửa một hàng (kể cả ghi tự động như đánh dấu hoá đơn quá hạn) sau khi máy A / admin đã xoá
nó mà B chưa kéo cờ xoá về ⇒ nếu bản của B thắng LWW, **hàng đã xoá sống lại** trên mọi máy (giao dịch sống lại thì số dư tính lại theo nó). Vế
`true` không bao giờ chạy với client (xoá đi bằng `operation: delete`). **Xin backend:** chỉ áp `is_deleted` khi giá trị là `true`; `false` thì
không đụng `delete_at`. Client không cần đổi gì. Chưa đo trên hai máy.

### 9.2 ⚠️ `/sync/pull` trả 500 `DECRYPT_FAILED` cho cả lượt (đơn 52)

Từ `49eafef6`, `decrypt()` ném lỗi; một hàng giải mã hỏng ⇒ `/sync/pull` trả HTTP 500 `{ code: 'DECRYPT_FAILED' }`, không trả phần nào. Client
nuốt lỗi kéo ⇒ kéo về đứng cho cả tài khoản cho tới khi hàng ấy được sửa (đẩy lên vẫn chạy; máy đăng nhập mới không có dữ liệu). Đi
kèm một lỗ mức cao: `encrypt()` vẫn giữ nguyên mọi chuỗi dạng `enc:a:b:c` ⇒ người dùng gõ ghi chú `enc:1:2:3` là tự khoá lượt kéo của mình vĩnh
viễn. Chi tiết và lời xin: đơn 52, đơn 53 vế C.

✅ **Client hết im lặng (2026-10-26, phiên 13):** lượt kéo bị máy chủ **trả lời** bằng lỗi — mọi mã ≥ 400 trừ 401 · 403 · 429 · 503 (luật
`keoVeBiMayChuTuChoi`, `ap_du_lieu_keo_ve.dart`) — bật `SyncEngine.keoVeBiTuChoi` ⇒ Trang chủ hiện dòng nhắc *"Chưa nhận được dữ liệu mới"*
(`DongNhacKeoVe`, ngay sau dòng nhắc máy chủ). Lỗi vẫn nuốt: chu kỳ **không** thành `error` (không thông báo *"Đồng bộ hỏng"*), **không** giãn
cách; cờ tắt ở lượt kéo thành công kế tiếp và ở `stop()`, mất mạng giữ nguyên. Ca canh `test/core/sync/sync_keo_ve_bi_tu_choi_test.dart`.
Client vẫn không đọc riêng `code` (chỉ ghi log) — câu chữ đúng cho mọi lỗi máy chủ. Nghiệm thu Realme cùng ngày (proxy tiêm 500
`DECRYPT_FAILED`): dòng nhắc hiện, tự ẩn ở lượt kéo thành công kế, không sinh thông báo *"Đồng bộ chưa thành công"*.

### 9.3 Nhỏ

Kết quả `conflict` mang `serverRecord` với `note` là **bản mã thô** (`getXById` không giải mã) — client không đọc `serverRecord` nên vô hại hôm nay.

## 10. Các việc từng đề nghị client — trạng thái (2026-10-26)

Gom từ Mục V của bản backend viết đè (`bc4e4f7f`), checklist §6 của `Sync-To-ClientApp.md` v3.2 và `docs/superpowers/client-app/CAN-LAM/README.md`.

| Đề nghị | Trạng thái |
|---|---|
| Đẩy `is_deleted`, kéo về đọc `delete_at` / `deleted_at` | ✅ có từ trước (`thu_gom_day.dart`, `anh_xa_keo_ve.dart`) |
| `time_notification: null` khi tắt nhắc | ✅ có từ 2026-10-16 (`d657b065`) |
| `pay_status: 'Skipped'` | ✅ có từ 2026-09-12 |
| Ví `status` `Active` / `Inactive` | ✅ có từ 2026-09-14 (G28) |
| Đọc `note` bản rõ, không tự giải mã | ✅ đúng như vậy |
| `x-device-name` | ✅ Android từ 2026-10-26 (`bbf8c851`); cách lấy khác đề nghị (kênh Kotlin, không `device_info_plus`) |
| Quy đổi `type` / dấu `amount`, `idgoal` / `idbill`, `status` chữ hoa đầu, không đọc `balance`, `pay_status` / `auto_pay` / `period_end`, `priority` ≠ 0, ba cột trích tự động, `threshold_warning_percent` | ✅ có, mỗi thứ một ca trong tệp test |
| `x-platform` | ✗ không làm — backend không đọc |
| Bảng `user_profile` / `device_tracking` / `permissions_cache` | ✗ không làm — mục 6 |
| Thêm `provider` / `bank_tran_id` / `status` / `images` (giao dịch), `id_bank_casso` (ví) | ✗ không làm — quy tắc 4, nhóm bỏ liên kết ngân hàng |
| Xoá SQLite khi `ACCOUNT_DELETED` | ✗ không làm — G89 |

## 11. Không đồng bộ / ngoài phạm vi

Ảnh đính kèm giao dịch (`Images`) · liên kết ngân hàng (SePay / Casso — bỏ 2026-09-18) · nhật ký kiểm toán (`auditlog`) · thông báo (cục bộ).
**Gia đình** (`docs/Family/`, chưa có mã): sẽ thêm `idhousehold` cho ví, giao dịch, mục tiêu, ngân sách, danh mục (phạm vi kéo về *của tôi ∨ của nhà
tôi*) và `idfund_pair` cho giao dịch — khi thi công, sửa tệp test và tệp này cùng lượt.

## 12. Bẫy đã gặp (đọc trước khi sửa vùng tương ứng)

- **G24** màu danh mục: client từng gửi `colour`, backend chỉ đọc `color` — bỏ qua im lặng.
- **G28** ví lưu trữ: `Status` từng là `varchar(7)`, `'Inactive'` dài 8 ⇒ kẹt hàng đợi; mở một chiều thôi là hỏng im lặng.
- **G37** số dư ví: kéo `balance` về là nuốt thay đổi cục bộ chưa đẩy.
- **G67** mốc theo giờ server; **G85** thứ tự vá neo khi kéo về.
- **G63** ví trùng tên giữa hai máy: bộ nghe thứ hai trên `pushResultStream`, thu gom bỏ bản ghi bị giữ ở **mọi** bước (kể cả 1b — quên là vòng
  đồng bộ nóng).
- **Quy tắc 3** `insertOrReplace` từng xoá cấu trúc nhóm danh mục sau mỗi lần kéo.
- **Hai lượt phát** `pushResultStream` cho một thất bại (2.6); kết quả đẩy phát **trước** bước kéo (vấp: ví phình đúng một lần trả hoá đơn).

## 13. Lịch sử tệp

- 2026-08-10 — spec đồng bộ gốc: `docs/superpowers/backend/2026-08-10-backend-sync-spec.md` (lịch sử).
- 2026-09-14 — client đưa tệp này vào repo (bỏ chặn `.gitignore`).
- 2026-10-23 · 2026-10-25 · 2026-10-26 — backend viết đè (`6cbd248e` *"v3.0"*, `36f1ea43` *"v4.0"*, `bc4e4f7f`); hai lần đầu client giữ bản của
  mình, lần ba lọt qua lượt gộp `3636110d`. Đọc lại: `git show <commit>:docs/superpowers/sync/SYNC_DOCUMENTATION.md`.
- 2026-10-23 — backend tạo `docs/Admin-web/Sync-To-ClientApp.md` v3.2 (bảng cột PostgreSQL theo từng thực thể; đơn 49 vế H ghi các chỗ lệch).
- **2026-10-26 — gộp hai tệp thành tệp này** (người dùng yêu cầu; cho phép thay `Sync-To-ClientApp.md` bằng vài dòng trỏ). Lấy từ bản backend: bảng
  cột PostgreSQL, thứ tự `ENTITY_PRIORITY`, bảng quy đổi giao dịch; từ bản client: ghi chú G24 / G28 / G37 / G63 / G67 / G85, cảnh báo *tệp test là
  hợp đồng*. Sửa theo mã: thứ tự đẩy, thành phần payload danh mục, bảng cục bộ, `Create_by` của danh mục mặc định, cơ chế 429, header thiết bị.

## 14. Trao đổi

*(Backend / Admin-web ghi câu hỏi hoặc đề nghị sửa ở đây, kèm ngày và tên; client trả lời ngay dưới. Đừng sửa thân tệp.)*
