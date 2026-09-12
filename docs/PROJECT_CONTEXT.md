# FlowMoney — Tài liệu dự án (Project Context)

> **Mục đích**: Tài liệu này giúp AI assistant (Claude, v.v.) hiểu toàn bộ dự án, kiến trúc, trạng thái hiện tại và các vấn đề đã xử lý. Đọc kỹ trước khi bắt đầu làm việc.

---

## 1. Tổng quan dự án

| Thông tin | Giá trị |
|-----------|---------|
| **Tên dự án** | FlowMoney (Quản lý tài chính cá nhân) |
| **Loại** | Đồ án tốt nghiệp (KLTN) |
| **Repo path** | `d:\test_kltn\ManagementFinance` |
| **Tên app** | FlowMoney |
| **Tên backend API** | WealthCommand API |

### Mô tả
Ứng dụng quản lý tài chính cá nhân với:
- Theo dõi thu/chi, ngân sách, hóa đơn, mục tiêu tiết kiệm
- Đồng bộ dữ liệu giữa client (SQLite local) ↔ backend (PostgreSQL)
- Hỗ trợ offline-first: dùng được khi không có mạng, sync khi online
- Tích hợp AI chat, kết nối ngân hàng (SePay — backend thay Casso từ 2026-09-07; tên cột `Id_casso_account`/`Id_bank_casso` còn giữ)

---

## 2. Cấu trúc thư mục

```
ManagementFinance/
├── src/
│   ├── Backend/          ← Node.js + Express + Prisma + PostgreSQL
│   └── Client-app/       ← Flutter (Web/Mobile, Dart)
├── docs/
│   ├── Rule_Project/
│   │   ├── New_Database.md   ← Schema chuẩn PostgreSQL (nguồn sự thật)
│   │   ├── Data_Security.md  ← Nguyên tắc bảo mật & phân loại dữ liệu
│   │   └── Rule_project.md   ← Quy tắc toàn dự án
│   └── superpowers/
│       └── plans/
│           └── PROGRESS-BACKEND.md
└── Project.md            ← Tài liệu gốc của dự án
```

---

## 3. Tech Stack

### Backend (`src/Backend/`)
| Thành phần | Công nghệ |
|-----------|-----------|
| Runtime | Node.js |
| Framework | Express.js |
| ORM | Prisma (v6.x) |
| Database | PostgreSQL (`PersonFinance` DB) |
| Auth | JWT (access token + refresh token) |
| Rate limiting | express-rate-limit |
| Logging | morgan + custom logger |
| Deploy | localhost:3000 (dev) |

**Khởi động Backend:**
```bash
cd src/Backend
npm run dev   # nodemon, hot-reload
```

**Prisma:**
```bash
npx prisma studio          # GUI xem DB (port 5555)
npx prisma migrate status  # kiểm tra migration
npx prisma migrate dev     # tạo migration mới (CHỈ KHI schema.prisma thay đổi)
npx prisma generate        # tái sinh Prisma Client
```

### Client App (`src/Client-app/`)
| Thành phần | Công nghệ |
|-----------|-----------|
| Framework | Flutter (Dart) |
| State management | BLoC + Cubit (flutter_bloc) |
| Local DB | Drift (SQLite, code-gen) |
| HTTP | Dio |
| DI | get_it |
| Navigation | go_router |
| Auth storage | flutter_secure_storage |

**Khởi động Client:**
```bash
cd src/Client-app
flutter run -d chrome --web-port 9090   # web
flutter run -d <device>                  # mobile
```

**Drift (SQLite code-gen):**
```bash
dart run build_runner build --delete-conflicting-outputs
# Hoặc watch:
dart run build_runner watch --delete-conflicting-outputs
```

---

## 4. Database Schema (PostgreSQL)

> Schema chuẩn xem tại: `docs/Rule_Project/New_Database.md`
> Prisma schema: `src/Backend/prisma/schema.prisma`

### Bảng chính

| Bảng | Mô tả | PK type |
|------|-------|---------|
| `role` | Vai trò (Admin/User) | INT autoincrement |
| `account` | Tài khoản đăng nhập | INT autoincrement |
| `user` | Thông tin cá nhân | INT autoincrement |
| `category` | Danh mục thu/chi | String UUID (VarChar 36) |
| `wallet` | Ví tiền | String UUID |
| `transaction` | Giao dịch | String UUID |
| `budget` | Ngân sách | String UUID |
| `bill` | Hóa đơn định kỳ | String UUID |
| `goal` | Mục tiêu tiết kiệm | String UUID |
| `bank_account` | Tài khoản ngân hàng (SePay — cột vẫn tên `Id_casso_account`) | String UUID |
| `refreshtoken` | JWT refresh tokens | INT autoincrement |
| `otp_code` | Mã OTP | INT autoincrement |
| `auditlog` | Nhật ký request | INT autoincrement |

### FK quan trọng
- `transaction.Idcategory` → `category.Idcategory` (NULLABLE, `fk_transaction_category`)
- `transaction.Idwallet` → `wallet.Idwallet` (NOT NULL, CASCADE)
- `category.Create_by` → `account.Idaccount` (NOT NULL)
  - Default categories: `Create_by = 1` (admin account)
  - User categories: `Create_by = idaccount` của user
- `budget.Idcategory` → `category.Idcategory` (NULLABLE, ON DELETE SET NULL)
- `bill.Idcategory` → `category.Idcategory` (NOT NULL, RESTRICT)

### Category: 2 loại
1. **Default/Admin categories** (`is_default = true`, `create_by = 1`): Danh mục hệ thống do admin tạo (Ăn uống, Di chuyển, v.v.)
   - **Backend PostgreSQL**: `create_by = 1` (idaccount của tài khoản admin là **1**)
   - **Client SQLite**: lưu với `idaccount = 0` (quy ước nội bộ = "global, không thuộc user nào")
2. **User categories** (`is_default = false`, `create_by = idaccount`): Danh mục tự tạo của người dùng

### Quy tắc trùng tên danh mục

> **Lý do** buộc phải thay đổi, bằng chứng đo được và các phương án đã cân nhắc rồi loại bỏ: `docs/CATEGORY_RATIONALE.md`. Đọc file đó trước khi định "dọn dẹp" vùng này.

**Quy tắc nghiệp vụ (chốt 2026-09-03).** Trong phạm vi **một tài khoản**, tên danh mục là **duy nhất**:

| Yếu tố | Có nằm trong khoá không |
|---|---|
| Chủ sở hữu (`Create_by` / `idaccount`) | **có** — hai tài khoản khác nhau được trùng tên |
| Tên danh mục (đã chuẩn hoá) | **có** |
| `Classify` | **không** — một tài khoản không được có "Ăn uống" cả Thu lẫn Chi |
| Nhóm cha (`Idgroup` / `parentId`) | **không** — hai nhóm không phải hai không gian tên riêng |
| `Is_group` | **không** — nhóm và danh mục con dùng chung không gian tên |

Thêm hai điều:

- **Danh mục mặc định dùng chung không gian tên với danh mục người dùng.** Vì nó là hàng dùng chung, tên của nó chiếm chỗ với **mọi** tài khoản.
  - ⚠️ **Từ 2026-09-07 chúng không còn HIỂN THỊ nữa** (mỗi tài khoản có bản sao riêng), nhưng vẫn **chiếm chỗ tên**: `getNamesInUse` cố ý còn đếm chúng, và hai unique index của PostgreSQL vẫn tính chúng. Ẩn khỏi danh sách **không phải** là ra khỏi quy tắc trùng tên — nhầm hai điều này là cho người dùng tạo một danh mục mà đẩy lên sẽ hỏng.
- **Hàng đã xoá mềm không giữ chỗ.** Phép so tên đi qua **bốn bước, theo đúng thứ tự**: gộp Unicode về dạng NFC → chữ thường → cắt khoảng trắng hai đầu → gom khoảng trắng ở giữa. Định nghĩa **duy nhất** nằm ở `lib/core/category/category_name.dart` (`normalizeCategoryName`); mọi nơi so tên đều phải gọi hàm đó.
  - Bước NFC không phải tuỳ chọn: "Cà phê" gõ từ hai bàn phím khác nhau có thể ra hai chuỗi khác byte (6 và 8 ký tự) mà mắt thường không phân biệt được.
  - Vì sao chốt đủ bốn bước ngay: **nới lỏng về sau là miễn phí, siết chặt về sau thì phải dọn dữ liệu** — bỏ bớt một bước bây giờ nghĩa là mai kia thêm lại sẽ có sẵn dữ liệu vi phạm và `CREATE UNIQUE INDEX` phía PostgreSQL sẽ thất bại.

**Nơi thi hành — chỉ có client:**

`CategoryManagementRepositoryImpl._hasDuplicateName()` quét qua `CategoryDao.getNamesInUse(accountId)`. Cố ý **không** dùng `getCategoryRows`: hàm đó lọc sẵn theo `classify` và còn khử trùng lặp theo tên trước khi trả về, tức chính những hàng cần đối chiếu lại bị nó loại đi.

Phép kiểm tra **chỉ chạy khi tên thật sự đổi**. Bản client trước 2026-09-03 loại danh mục mặc định khỏi phép kiểm tra, nên máy người dùng có thể đang giữ một danh mục riêng trùng tên với danh mục mặc định; chặn tuyệt đối sẽ khiến họ không sửa nổi danh mục đó nữa, kể cả chỉ đổi icon.

> ✅ **CSDL nay thi hành ĐÚNG quy tắc này — từ 2026-09-07.** PostgreSQL giữ:
>
> ```sql
> UNIQUE (Create_by, lower(NFC(NameCategory)))  WHERE Is_default = FALSE AND Delete_at IS NULL
>                                               -- uq_category_owner_name
> UNIQUE (lower(NFC(NameCategory)))             WHERE Is_default = TRUE  AND Delete_at IS NULL
>                                               -- uq_category_default_name
> ```
>
> Khớp cả ba điểm từng lệch: bỏ `Classify` khỏi khoá, so tên đã chuẩn hoá NFC và
> không phân biệt hoa/thường, và **hàng đã xoá mềm không còn giữ chỗ tên**. Vế
> "chặt hơn" — xoá một danh mục rồi tạo lại cùng tên bị CSDL từ chối trong khi
> client cho qua — vì thế đã hết. Trigger kiểm chéo "người dùng không được trùng
> tên với mặc định" cũng đã DROP, đúng như mô hình bản sao cần.
>
> Đo thẳng trên `localhost:5432/PersonFinance` ngày 2026-09-07, không đọc tài liệu.
>
> ⚠️ **Lớp cầm máu phía client giữ nguyên, đừng gỡ.** `_classifyFailure` vẫn xếp
> vi phạm UNIQUE vào `permanent`: 23505 còn xảy ra được vì những lý do khác, và
> không có nó thì bản ghi hỏng quay lại bị đẩy ở mọi chu kỳ. Từ cùng ngày, phép
> phân loại đi theo `code` của backend (`UNIQUE_VIOLATION`,
> `CATEGORY_NAME_DUPLICATE`) chứ không dò chuỗi nữa.
>
> Hồ sơ của chặng cũ: `docs/superpowers/backend/DA-XONG/CATEGORY_NAME_UNIQUENESS.md`
> và **G16** trong `docs/CLIENT_APP_KNOWN_GAPS.md`.

---

## 5. Backend API Routes

Base URL: `http://localhost:3000/api`

| Route | Mô tả |
|-------|-------|
| `GET /health` | Health check |
| `POST /api/auth/register` | Đăng ký |
| `POST /api/auth/login` | Đăng nhập → access token + refresh token |
| `POST /api/auth/refresh` | Làm mới access token |
| `POST /api/auth/logout` | Đăng xuất |
| `POST /api/sync/push` | Client push dữ liệu lên backend |
| `GET /api/sync/pull` | Client pull dữ liệu từ backend |
| `GET /api/admin/*` | Các route admin |
| `POST /api/ai/*` | AI chat |
| `GET/POST /api/bank/*` | Tích hợp ngân hàng SePay (thay Casso từ 2026-09-07) |

### Sync API — quan trọng nhất

**POST `/api/sync/push`**
```json
{
  "clientId": "flutter-client-app",
  "pushedAt": "ISO timestamp",
  "operations": [
    {
      "localId": "uuid hoặc local-id",
      "entity": "category|wallet|transaction|budget|bill|goal",
      "operation": "create|update|delete",
      "payload": { ...fields }
    }
  ]
}
```

Response:
```json
{
  "results": [
    { "localId": "...", "status": "synced|failed|conflict", "reason": "..." }
  ]
}
```

**GET `/api/sync/pull?since=ISO_DATE&idaccount=N`**
- Trả về tất cả entities được cập nhật sau `since`
- Nếu không có `since` → full pull

---

## 6. Sync Engine (Client-side)

**File chính**: `src/Client-app/lib/core/sync/sync_engine.dart`
**Phụ trợ**: `sync_models.dart`, `sync_checkpoint_store.dart`, `sync_payload_normalizer.dart`

> Phần này đã được kiểm chứng lại bằng cách đọc mã nguồn ngày 2026-09-02. Việc còn dang dở: xem `docs/CLIENT_APP_KNOWN_GAPS.md`.

### Nguồn kích hoạt đồng bộ (4 nguồn)

| Nguồn | Nơi cài đặt |
|---|---|
| Ngay khi `start()` được gọi | `sync_engine.dart:112` — `await syncNow()` |
| Mạng phục hồi | listener `onConnectivityChanged` (`:96-102`) |
| Định kỳ **15 phút** | `Timer.periodic` (`:106-109`), hằng số `_periodicSyncMinutes = 15` |
| Sau mỗi lần ghi dữ liệu | `scheduleSync()` — debounce **2 giây**, được gọi từ **19 vị trí** trong tầng feature |

`start()` luôn huỷ listener/timer cũ trước khi cài mới nên gọi nhiều lần không nhân đôi trigger.
`start(idaccount:)` được gọi từ 3 nơi: `AuthBloc` lúc khôi phục phiên, `AuthBloc` sau đăng nhập, và `HomePage.build()` *(chỗ cuối là điểm cần dọn — xem gaps)*.

### Kiến trúc

```
SyncEngine._runSync()
├── Chốt vào: _disposed? / _currentIdaccount null hoặc <= 0 → BỎ QUA
│   (danh tính CHỈ đến từ phiên đăng nhập — không bao giờ suy ra từ SQLite)
├── PUSH
│   ├── _collectPendingOps(accountId)
│   │   ├── 1.  Categories pending — getSyncableCategories() (loại isLocalOnly)
│   │   │       sắp NHÓM trước CON vì backend có FK fk_category_parent
│   │   ├── 2.  Wallets pending
│   │   ├── 1b. Categories được pending transaction tham chiếu (lazy push)
│   │   ├── 3.  Transactions (_resolveCategoryId trước → defer nếu null)
│   │   └── 4-6. Budgets → Bills → Goals
│   └── _sendBatch(ops) → SyncResult
│       ├── SyncPayloadNormalizer chuẩn hoá tên trường
│       └── Phân loại từng thất bại: transient | permanent | sessionInvalid
├── Nếu có sessionInvalid → phát sessionInvalidStream, DỪNG (không pull, không retry)
├── PULL  (since = mốc đã lưu; SQLite rỗng thì ép full pull)
│   ├── Upsert: Wallets → Transactions → Categories → Budgets → Bills → Goals
│   │   (mọi DAO dùng insertAllOnConflictUpdate — chỉ ghi cột có trong companion)
│   ├── repairPendingTransactionsCategoryId()  ← PHẢI chạy TRƯỚC dedup
│   ├── removeDuplicateLocalSeedCategories()   ← xoá cat_food khi đã có bản UUID
│   └── Lưu mốc mới = update_at LỚN NHẤT nhận được (không dùng giờ client)
└── Retry MỘT lần — chỉ khi có thất bại loại transient
```

### Phân loại lỗi đẩy dữ liệu

| Loại | Nhận diện | Xử lý |
|---|---|---|
| `sessionInvalid` | `results[i].code == 'ACCOUNT_NOT_FOUND'` (**ưu tiên**), hoặc HTTP **401** cho cả batch; dự phòng: khớp `fk_*_account` trong thông báo Prisma | Phát `sessionInvalidStream` → AuthBloc hỏi lại server → đăng xuất nếu server phủ nhận. Không thử lại. |
| `transient` | khoá ngoại khác, lỗi chưa rõ, hoặc cả batch không tới nơi (`transportFailed`) | Thử lại 1 lần sau khi Pull — trừ khi `transportFailed`, khi đó để giãn cách luỹ tiến lo |
| `permanent` | `Ownership mismatch` | Không thử lại, **không** đăng xuất (đó là dữ liệu rác của tài khoản khác). Bản ghi bị chặn theo thời gian qua `syncBlockedUntil` |

Từ 2026-09-03 backend gắn mã lỗi ổn định `ACCOUNT_NOT_FOUND` vào từng phần tử `results[]` và trả **HTTP 401** khi *toàn bộ* thao tác trong batch hỏng vì lý do đó. Client ưu tiên hai tín hiệu này; nhánh khớp chuỗi tên constraint chỉ còn là **dự phòng** cho backend chưa cập nhật (nó vỡ khi đổi tên constraint hoặc nâng version Prisma, mà không báo lỗi gì).

Dù nhận diện bằng cách nào, đó cũng chỉ là **tín hiệu**; quyết định đăng xuất do server đưa ra qua `verifySession()`.

### Mốc đồng bộ (checkpoint)

Lưu bền vững qua `flutter_secure_storage`, khoá theo từng `idaccount` (`sync_checkpoint_store.dart`). Mốc mới lấy theo `update_at` lớn nhất trong dữ liệu nhận được — **không** dùng `DateTime.now()` của client, vì backend lọc `update_at > since` bằng đồng hồ của nó.

### `_resolveCategoryId(categoryId)` — logic quan trọng
```
- Category NON-DEFAULT → chỉ cần UUID format hợp lệ
- Category DEFAULT với UUID hợp lệ → trả về luôn (KHÔNG tìm UUID khác)
- Category DEFAULT với ID dạng 'cat_food' → tìm UUID cùng tên trong DB
- Nếu không tìm được → null → transaction bị defer
```

### Entity priority (backend sort)
Backend sort operations theo ENTITY_PRIORITY trước khi process:
```
category = 10, wallet = 20, transaction = 40, budget = 50, bill = 60, goal = 70
```

### LWW (Last Write Wins)
- Backend so sánh `update_at` của payload với `update_at` của record hiện có
- Nếu payload mới hơn → update; nếu cũ hơn → bỏ qua (không error)

### Ownership check
- Backend kiểm tra `payload.idaccount === token.idaccount`
- Default categories (`idaccount=0`) → KHÔNG push lên backend (backend đã có sẵn)
- Chỉ push USER categories (idaccount == currentAccount)

---

## 7. Client-side Database (Drift/SQLite)

**File**: `src/Client-app/lib/core/database/app_database.dart`

### Tables (DAOs)
| Table | DAO file | Mô tả |
|-------|----------|-------|
| `categories` | `category_dao.dart` | Danh mục (local seed + UUID từ backend) |
| `wallets` | `wallet_dao.dart` | Ví tiền |
| `transactions` | `transaction_dao.dart` | Giao dịch |
| `budgets` | `other_daos.dart` | Ngân sách |
| `bills` | `other_daos.dart` | Hóa đơn |
| `goals` | `other_daos.dart` | Mục tiêu |

### syncStatus field
Mỗi entity trong SQLite có `syncStatus`:
- `'pending'` → chờ push lên backend
- `'synced'` → đã sync thành công
- `'failed'` → push thất bại

### Default categories (local seed)
Khi app khởi động lần đầu, DB được seed các category mặc định:
```
ID dạng 'cat_food', 'cat_transport', ... (NON-UUID)
idaccount = 0  ← quy ước nội bộ client: "global, không thuộc user nào"
               ← (khác với backend: admin có create_by = 1)
isDefault = true
syncStatus = 'synced' (không cần push)
```

> ⚠️ **Quan trọng**: `idaccount = 0` chỉ tồn tại trong SQLite client. Trên backend PostgreSQL, admin categories có `create_by = 1`. Khi pull categories từ backend, client lưu chúng với `idaccount = 0` (vì `create_by = 1` ≠ idaccount của user hiện tại). Đây là mapping có chủ đích.

Sau khi pull từ backend → UUID categories thay thế → `removeDuplicateLocalSeedCategories()` xóa các local seed đã có UUID tương ứng.

**Bộ seed khớp đúng 13 danh mục mặc định của backend** (từ 2026-09-03). Trước đó client seed 18 mục còn backend có 13, và **chỉ 10 mục khớp tên** — mà danh mục mặc định lại được ánh xạ sang UUID backend **bằng cách so tên**, nên 8 mục lệch kia không tìm được bản nào, `_resolveCategoryId` trả `null`, và mọi giao dịch dùng chúng bị hoãn đẩy **vĩnh viễn** mà không có lỗi nào báo ra.

Tám mục lệch được xử lý làm hai nhóm khác nhau:

| Nhóm | Mục | Cách xử lý |
|---|---|---|
| Chỉ khác **nhãn** | `Sức khoẻ`→`Y tế`, `Nhà ở`→`Nhà cửa`, `Hoá đơn & Dịch vụ`→`Hóa đơn` | Đổi tên seed cho khớp backend. Migration v9→v10 đổi tên cho máy đã cài. **Không xoá hàng** — xoá hàng seed trước khi giao dịch được repoint chính là lỗi 11.6. |
| Backend **không có** | `Chi khác`, `Thu khác`, `Làm thêm`, `Trả nợ`, `Thu nợ` | Chuyển thành **danh mục riêng của tài khoản** (`PersonalDefaultCategories.ensureForAccount()`, chạy lúc đăng nhập **và** khi khôi phục phiên). Danh mục người dùng thì đồng bộ được, nên chúng đẩy lên bình thường — backend không phải thêm gì. |

> ⚠️ Năm mục cá nhân đó phải mang **id UUID**, không phải id dạng `cat_*`: `_resolveCategoryId` chỉ chấp nhận danh mục người dùng có UUID hợp lệ, id dạng slug sẽ bị trả `null` và giao dịch lại kẹt y như cũ.
>
> Dữ liệu cũ trỏ vào hàng `cat_*` được **repoint trước, xoá mềm sau** — ở cả ba bảng có `categoryId` (transactions, budgets, bills).

### Category dedup logic (trong watchCategoryRows / getCategoryRows)
- Nếu có 2 category cùng tên: ưu tiên UUID version (từ backend) thay vì `cat_food` version
- Kết quả: user luôn thấy UUID version khi chọn danh mục

---

## 8. Field Mapping: Client ↔ Backend

### SyncPayloadNormalizer (`sync_payload_normalizer.dart`)
Chuẩn hóa field names trước khi gửi:

| Client (SQLite) | → | Payload (gửi lên) | Backend mapper | DB column |
|-----------------|---|-------------------|----------------|-----------|
| `t.id` | → | `id` | `idtran` | `Idtran` |
| `t.walletId` | → | `walletId` | `idwallet` | `Idwallet` |
| `t.categoryId` (resolved; `null` với khoản chuyển) | → | `categoryId` | `idcategory` | `Idcategory` |
| `t.type` (`chi`/`thu`/`transfer`) | → | `type` (`Transaction`/`Transfer`) + **dấu** của `amount` | `type` | `Type` |
| `t.walletTransfer` (ví đích, chỉ khoản chuyển) | → | `idwallet_transfer` | `idwallet_transfer` | `Idwallet_transfer` |
| `t.updatedAt` | → | `update_at` | `update_at` | `Update_at` |
| `cat.id` | → | `id` | `idcategory` | `Idcategory` |
| `cat.idaccount` | → | `idaccount` | `create_by` | `Create_by` |

### mapEntityFields (sync.repository.js)
Backend `mapEntityFields()` chuyển từ camelCase payload → DB field names:
- `categoryId` → `idcategory`
- `walletId` → `idwallet`
- `idaccount` → (giữ nguyên cho wallet/transaction) hoặc `create_by` (cho category)

---

## 9. Flutter App Structure

### Features
```
features/
├── auth/           ← Đăng nhập / đăng ký
├── home/           ← Dashboard (tổng quan tài chính)
├── transaction/    ← Thêm/sửa/xóa giao dịch
├── wallet/         ← Quản lý ví
├── budget/         ← Ngân sách
├── bill/           ← Hóa đơn định kỳ
├── goal/           ← Mục tiêu tiết kiệm
├── category/       ← Quản lý danh mục
├── analytics/      ← Báo cáo & thống kê
├── ai_chat/        ← Chat với AI
└── profile/        ← Hồ sơ người dùng
```

### DI (GetIt)
File: `core/di/injection_container.dart`

Các singleton quan trọng:
- `AppDatabase` — Drift SQLite instance
- `DioClient` — HTTP client với auto-refresh token
- `SyncEngine` — Offline-first sync engine

### Auth flow
1. Login → nhận `accessToken` + `refreshToken` → lưu vào `FlutterSecureStorage`
2. `DioClient` tự động đính kèm `Authorization: Bearer <token>` vào mọi request
3. Khi token hết hạn → auto-refresh qua `/api/auth/refresh` (⚠️ 2026-09-11: theo mã backend sau gộp `main` @ `cc65f4f`, endpoint này từ chối mọi tài khoản nên người dùng bị đăng xuất khi access token hết hạn — CAN-LAM 17 A)
4. `AuthBloc` quản lý trạng thái đăng nhập

---

## 10. Backend Module Structure

```
src/Backend/
├── api/              ← Route definitions
│   ├── auth.routes.js
│   ├── sync.routes.js
│   ├── admin.routes.js
│   ├── ai.routes.js
│   └── bank.routes.js
├── modules/
│   ├── auth/         ← Auth controller + service
│   ├── sync/
│   │   ├── sync.controller.js   ← Xử lý /sync/push và /sync/pull
│   │   ├── sync.service.js      ← Business logic sync (ENTITY_PRIORITY, processPush)
│   │   └── sync.repository.js   ← Prisma queries
│   ├── admin/
│   ├── ai/
│   └── bank/         ← SePay integration (`sepay/`; thay Casso từ 2026-09-07)
├── middleware/
│   ├── auth.middleware.js    ← JWT verify
│   ├── rate-limiter.js
│   ├── audit-log.middleware.js
│   └── error-handler.js
├── config/
│   └── db.js         ← Prisma client + pg pool
└── prisma/
    ├── schema.prisma ← DB schema (nguồn sự thật Prisma)
    └── migrations/   ← SQL migration history
```

---

## 11. Các vấn đề đã giải quyết (ghi nhớ để tránh lặp lại)

### 11.1 FK violation `fk_transaction_category`
**Nguyên nhân**: Transaction bị push lên backend trước khi category của nó tồn tại trên backend.

**Giải pháp**:
1. **Batch ordering**: Categories → Wallets → Transactions (ENTITY_PRIORITY đã đúng phía backend)
2. **Step 1b**: Proactively thêm USER categories mà pending transactions tham chiếu vào batch
3. **`_resolveCategoryId`**: Nếu category chưa có UUID matching → defer transaction (không push)

### 11.2 Ownership mismatch: `payload.idaccount does not match token`
**Nguyên nhân**: Default/global categories (`idaccount=0`) bị push lên backend với `idaccount` sai.

**Giải pháp**: Step 1b chỉ thêm category có `idaccount == currentAccount`. BỎ QUA hoàn toàn `idaccount != currentAccount`.

### 11.3 Category UUID lookup trả về sai UUID
**Nguyên nhân**: `_resolveCategoryId` cho DEFAULT category đã có UUID hợp lệ vẫn tìm UUID khác theo tên.

**Giải pháp**: Short-circuit: nếu `categoryId` đã là UUID format hợp lệ VÀ category là default → trả về luôn.

### 11.4 Transactions bị defer mãi (categoryId = 'cat_food' sau khi cat_food bị xóa)
**Nguyên nhân**: `removeDuplicateLocalSeedCategories()` xóa `cat_food`, transaction vẫn lưu `categoryId='cat_food'`.

**Giải pháp**: `repairPendingTransactionsCategoryId()` — sau khi pull, scan pending transactions có non-UUID categoryId → resolve sang UUID → update trong SQLite.

### 11.5 Category trùng lặp trong UI
**Giải pháp**:
1. `watchCategoryRows` dedup theo tên, ưu tiên UUID version
2. `removeDuplicateLocalSeedCategories()` xóa seed versions sau khi UUID được pull về

### 11.6 Giao dịch kẹt vĩnh viễn vì `cat_food` bị xoá TRƯỚC khi được sửa
**Nguyên nhân**: trong `_pullFromBackend`, `removeDuplicateLocalSeedCategories()` chạy **trước** `repairPendingTransactionsCategoryId()`. Hàm repair cần đọc hàng `cat_food` (để lấy tên rồi tìm UUID cùng tên), nhưng hàng đó vừa bị xoá → `getById('cat_food')` trả `null` → repair luôn thất bại.

**Giải pháp**: đảo thứ tự — repair TRƯỚC, dedup SAU. **Đừng đảo lại.**

### 11.7 Nhóm danh mục không bao giờ lên backend
**Nguyên nhân**: payload push danh mục không gửi `isGroup` và `parentId`. Backend vốn đã hỗ trợ đầy đủ (`Is_group`/`Idgroup` trong schema, `mapEntityFields` nhận đúng hai key camelCase này, `upsertCategory` ghi cả hai, `getCategoriesByAccount` select cả hai) — chỉ client là không gửi.

**Giải pháp**: gửi `isGroup` + `parentId` khi push, đọc `is_group` + `idgroup` khi pull, và sắp nhóm đứng trước danh mục con trong batch vì backend có FK `fk_category_parent`.

### 11.8 Pull xoá sạch dữ liệu chỉ có ở client
**Nguyên nhân**: cả 6 DAO dùng `InsertMode.insertOrReplace` — chế độ này thay **cả hàng**, nên mọi cột không được gán trong companion đều bị đưa về giá trị mặc định. Mỗi lần pull là `parentId`, `isGroup`, `syncStatus`, `walletTransfer`, `bankTranId`, `status`, `provider`… bị xoá.

**Giải pháp**: dùng `insertAllOnConflictUpdate` (INSERT … ON CONFLICT DO UPDATE) — chỉ ghi cột có mặt trong companion. **Đừng đổi ngược lại.**

### 11.9 Phiên đăng nhập trỏ tới tài khoản đã bị xoá
**Nguyên nhân**: CSDL bị reset, tài khoản đăng ký lại nhận id mới, nhưng thiết bị vẫn giữ JWT của tài khoản cũ. Backend chỉ `jwt.verify` chữ ký + hạn, không kiểm tài khoản còn tồn tại, nên request đi lọt tới tận CSDL rồi vỡ khoá ngoại `fk_*_account` — lặp vô hạn, không có thông báo nào.

**Giải pháp**: `verifySession()` lúc mở app + tín hiệu `sessionInvalidStream` khi đang chạy. Chi tiết ở mục 14.

### 11.10 Tạo danh mục mới luôn thất bại khi không chọn nhóm cha
**Nguyên nhân**: guard `if (draft.parentId == draft.id)` — khi tạo mới, cả hai đều `null` nên `null == null` là `true`, chặn nhầm với thông báo vô nghĩa "Danh mục không thể là nhóm của chính nó".

**Giải pháp**: chỉ áp dụng guard khi đang SỬA (`draft.id != null`).

### 11.11 Tab Chuyển khoản của màn thêm giao dịch chưa bao giờ đồng bộ được
**Nguyên nhân** (phát hiện 2026-09-05, khi chuyển sang mô hình hai loại giao dịch): `AddTransactionPage` gán `categoryId = 'cat_transfer'` — một id **chưa từng được seed** — cho mọi khoản chuyển. `_resolveCategoryId` trả `null`, `_collectPendingOps` hoãn "chờ danh mục về" **vĩnh viễn**, không báo lỗi, trong khi số dư hai ví vẫn lên server. Cùng lúc `TransactionEntity` không có trường `walletTransfer` nên ví đích không xuống SQLite, và đường xoá không hoàn tiền ví đích. Dữ liệu thật xác nhận: 13 hàng `Transfer` trên server đều đến từ Goal, tab này chưa từng tạo được hàng nào.

**Giải pháp**: khoản chuyển có `categoryId = null` + `walletTransfer` = ví đích (cùng quy ước với Goal); `_collectPendingOps` **không** hoãn khoản chuyển vì danh mục (giải kẹt cả hàng cũ mang `'cat_transfer'`); `TransactionRepositoryImpl` đọc ví đích từ entity ở cả thêm lẫn xoá. Test canh: `test/features/transaction/presentation/add_transaction_page_test.dart`, `test/transaction_repository_test.dart`, và ca "transfer mang categoryId không phân giải được vẫn được đẩy" trong `sync_payload_contract_test.dart`.

### 11.12 Mốc `Update_at` ở tương lai, và lỗi múi giờ do chính cách sửa tay
**Lỗi gốc** (phát hiện 2026-09-05, commit `a677c0f`): 15 hàng của tài khoản 10 trên PostgreSQL (2 ví, 10 giao dịch, 1 mục tiêu, 2 hoá đơn) mang `Update_at` ở **tương lai**, xa nhất 10/11/2026. `_newestUpdateAt()` lấy `update_at` **lớn nhất** trong payload làm mốc pull, mốc chỉ tiến không lùi, nên một hàng hỏng là đủ đẩy mốc vọt lên; backend lọc `update_at > since` trả rỗng → máy ấy **không nhận dữ liệu mới nào trong hai tháng, hoàn toàn im lặng**. Đã chữa ở client **hai đầu** với ngữ nghĩa khác nhau có chủ ý: đường **ghi** *kẹp* mốc về hiện tại (vừa nhận xong, không có khoảng nào bị bỏ lỡ), đường **đọc** *vứt* mốc tương lai và full pull (mốc hỏng che đúng khoảng đã bỏ lỡ, kẹp là mất). Gộp hai hàm là hỏng một trong hai. Test: `test/core/sync/sync_checkpoint_test.dart`.

**Lỗi thứ hai, do cách sửa dữ liệu**: 15 hàng ấy được kẹp về `NOW()` bằng SQL thô trong một phiên PostgreSQL có `TimeZone = Asia/Bangkok`. Cột `Update_at` là timestamp **không múi giờ**, nên nhận **giờ địa phương** (`22:23:04` ngày 05/09), trong khi Prisma ghi/đọc cột ấy như **UTC**. Hệ quả: 13 hàng "mới hơn" mọi thay đổi của client **~7 giờ**; backend LWW so `new Date(mapped.update_at) > existing.update_at` → từ chối mọi **cập nhật** ví/mục tiêu/hoá đơn/giao dịch của tài khoản 10 (conflict, G9 "server thắng"), lần pull kế tiếp ghi đè lại giá trị cũ lên máy, **phần chênh lệch mất luôn** (ví dụ số dư ví sau khi người dùng xoá giao dịch). Chỉ *cập nhật* bị ảnh hưởng; tạo mới và xoá mềm vẫn đi vì không so mốc. Người dùng chọn **chờ** tới khi UTC thật vượt `22:23:04Z` (05:23 sáng 06/09 giờ VN) thay vì chạy thêm một lệnh `UPDATE`.

**Đã kiểm 09:44 ngày 06/09** (Prisma, chỉ đọc): cả bốn bảng `wallet`, `transaction`, `goal`, `bill` trả **0 hàng** `"Idaccount" = 10 AND "Update_at" > (NOW() AT TIME ZONE 'UTC')` → lỗi đã tự hết. Số dư hai ví Tiết kiệm/Tiền mặt của tài khoản 10 vẫn là giá trị **trước** các lần xoá bị vứt (2.100.000 / 6.800.081), chưa chỉnh.

**Ba quy tắc rút ra khi đụng PostgreSQL bằng tay:**
- Sửa cột timestamp không múi giờ thì ghi `NOW() AT TIME ZONE 'UTC'`, **không** ghi `NOW()`.
- `WHERE "Update_at" > NOW()` trả **0 hàng** kể cả khi có hàng tương lai, vì PostgreSQL đổi cột không tz theo múi giờ **phiên** trước khi so — phải so với `NOW() AT TIME ZONE 'UTC'`.
- Trước khi tin bất kỳ phép so mốc nào: `SELECT current_setting('TimeZone'), NOW(), NOW() AT TIME ZONE 'UTC'`.

---

## 12. Quy tắc phát triển (bắt buộc tuân theo)

1. **KHÔNG dùng DELETE vật lý** với dữ liệu user — dùng soft delete (`delete_at`, `is_deleted`)
2. **Chỉ sửa Client-app** trừ khi user yêu cầu rõ ràng được phép sửa Backend
3. **Sau khi sửa Drift tables/DAOs** → chạy `dart run build_runner build` để tái sinh `.g.dart`
4. **Sau khi sửa schema.prisma** → chạy `npx prisma migrate dev` và `npx prisma generate`
5. **Category default** (`idaccount=0`) → KHÔNG push lên backend
6. **`idaccount` CHỈ đến từ phiên đăng nhập** — tuyệt đối không suy ra từ dữ liệu trong SQLite, và không bao giờ mặc định về `1` (đó là tài khoản admin thật)
7. **Pull dùng `insertAllOnConflictUpdate`, KHÔNG dùng `insertOrReplace`** — xem mục 11.8
8. **Thêm trường mới cho sync** → cập nhật `test/core/sync/sync_payload_contract_test.dart` cùng lúc. Tên trường đi qua ba nơi định nghĩa độc lập (client dựng tay → `SyncPayloadNormalizer` → `mapEntityFields` phía backend); một tên sai **không gây lỗi, chỉ lặng lẽ bị bỏ qua**
9. **Tên danh mục là duy nhất trong phạm vi tài khoản** — không tính `classify`, không tính nhóm cha, và tính CẢ danh mục mặc định. Xem mục 4. Hiện chỉ client thi hành; CSDL vẫn giữ ràng buộc cũ nên vi phạm lọt qua sẽ hỏng âm thầm ở bước đẩy dữ liệu.

---

## 13. File quan trọng cần đọc khi làm việc

| File | Mục đích |
|------|----------|
| `src/Client-app/lib/core/sync/sync_engine.dart` | Toàn bộ logic sync offline-first |
| `src/Client-app/lib/core/database/daos/category_dao.dart` | Dedup + repair categories |
| `src/Client-app/lib/core/database/daos/transaction_dao.dart` | Transaction queries + repair |
| `src/Client-app/lib/core/sync/sync_payload_normalizer.dart` | Field name mapping |
| `src/Client-app/lib/core/realtime/realtime_channel.dart` | Kênh thời gian thực: bắt tay JWT, backoff nối lại, nghe cả `onConnectivityChanged` |
| `src/Client-app/lib/core/realtime/realtime_event.dart` | Ba sự kiện backend phát, và **lý do client không đọc payload** |
| `src/Backend/modules/sync/sync.repository.js` | Prisma queries cho sync |
| `src/Backend/modules/sync/sync.service.js` | Business logic sync |
| `src/Backend/prisma/schema.prisma` | DB schema (Prisma) |
| `docs/Rule_Project/New_Database.md` | DB schema chuẩn (nguồn sự thật) |

---

## 14. Trạng thái hiện tại (cập nhật cuối 2026-09-11)

### 🔐 Xác thực phiên đăng nhập

`checkAuthStatus()` **chỉ** kiểm tra chuỗi token có rỗng hay không — không gọi mạng, không giải mã JWT, không kiểm hạn. Vì vậy có thêm một bước xác minh thật:

- **`AuthRepository.verifySession()`** gọi `GET /auth/profile` — endpoint **duy nhất** thật sự truy vấn CSDL. Cố ý **không** dùng `/auth/me` vì endpoint đó chỉ echo lại payload JWT nên vẫn trả 200 cho tài khoản đã bị xoá.
- Trả về `SessionStatus { valid, invalid, unknown }`. Chỉ **401/404** mới là `invalid`; mọi mã khác kể cả 5xx và mất mạng đều là `unknown` → **không** đăng xuất, giữ cam kết offline-first.
- Việc phân loại lỗi nằm ở **repository**, không phải bloc, vì dự án có **hai class `NetworkException` trùng tên** ở hai file khác nhau — bắt lỗi theo kiểu ở tầng trên rất dễ import nhầm.
- Hai đường phát hiện phiên chết: **lúc mở app** (`_onAuthCheckRequested`) và **đang chạy** (tín hiệu `sessionInvalidStream` từ SyncEngine khi đẩy dữ liệu vỡ khoá ngoại `fk_*_account`).
- `purgeDataForOtherAccounts(idAcc)` xoá dữ liệu cục bộ của tài khoản khác (giữ nguyên danh mục mặc định `idaccount = 0`). Chạy ở **cả hai** đường vào: đăng nhập (`auth_bloc.dart:106`) và khôi phục phiên lúc mở app (`auth_bloc.dart:134`).
- **Không còn fallback `?? 1` ở bất kỳ đâu** *(⚠️ sai tới 2026-09-11 — còn ba chỗ ở màn quản lý danh mục; gỡ nốt cùng ngày, G35, kèm test quét `lib/`)* — `idaccount = 1` là tài khoản admin THẬT, không phải giá trị "chưa biết". Đã gỡ khỏi AuthBloc, `sync_engine.dart` (6 chỗ, G8) và 4 trang UI của bill/goal (G4, nay dùng `core/auth/current_account.dart` trả `int?`).

### ✅ Đã hoàn thành
- Schema PostgreSQL aligned với New_Database.md (migration đã apply)
- SQLite schema (Drift) aligned với backend schema — `schemaVersion` nay là **20** (dòng này từng đứng ở 12 rất lâu; con số đúng luôn nằm ở `AppDatabase.schemaVersion`, đừng chép từ đây)
- Sync engine: thứ tự batch đúng, nhóm danh mục đẩy trước danh mục con
- FK violation fix: `_resolveCategoryId` + step 1b
- Category dedup trong UI
- Ownership mismatch fix
- `repairPendingTransactionsCategoryId` (cat_food → UUID) — **chạy TRƯỚC** dedup
- **Đồng bộ nhóm danh mục hai chiều** (`isGroup` / `idgroup`)
- **Pull không còn ghi đè nguyên hàng**: cả 6 DAO dùng `insertAllOnConflictUpdate`
- **Checkpoint đồng bộ bền vững** giữa các lần mở app, lấy theo `update_at` lớn nhất
- **Đồng bộ định kỳ 15 phút**
- **Phân loại lỗi đẩy dữ liệu** + phát hiện phiên chết
- **Dọn dữ liệu tài khoản khác chạy cả khi khôi phục phiên** *(G6)*
- **Pull đọc cờ xoá của danh mục**, không còn hồi sinh danh mục đã xoá *(G7)*
- **Trạng thái kết thúc phản ánh kết quả thật**: thêm `SyncStatus.authExpired`; chu kỳ còn thao tác hỏng kết thúc ở `error` *(G1)*
- **Giãn cách luỹ tiến** 30s → 1p → 5p → 15p → 60p sau các chu kỳ hỏng liên tiếp *(G2)*
- **Trạng thái thất bại theo từng bản ghi**: `syncRetryCount` / `syncError` / `syncBlockedUntil` trên cả 6 bảng; lỗi vĩnh viễn bị chặn theo THỜI GIAN chứ không loại vĩnh viễn *(G3)*
- **Không còn `?? 1` ở bất kỳ đâu** *(⚠️ sai tới 2026-09-11 — còn ba chỗ ở màn quản lý danh mục; gỡ nốt cùng ngày, G35, kèm test quét `lib/`)*: `_collectPendingOps` dùng thẳng tham số `idaccount` *(G8)*, và 4 trang UI đổi sang `core/auth/current_account.dart` trả `int?` *(G4)*
- **Bỏ mọi nhánh đọc không lọc tài khoản ở tầng UI** và `isLocalDbEmpty` tính theo tài khoản hiện tại *(G4/G5)*
- **`conflict` được giải quyết**: LWW đã phân xử, server thắng → đánh dấu đã đồng bộ thay vì đẩy lại vô hạn *(G9)*
- **Migration `isLocalOnly`** (v7→v8): nhóm danh mục tạo trước 2026-09-02 quay lại được hàng đợi đẩy *(G11)*
- **`AuthInterceptor` không còn xoá token trong im lặng**: phát `sessionExpiredStream`, AuthBloc nghe song song với SyncEngine *(G12)*
- **Hẹn lại chu kỳ đồng bộ bị giãn cách từ chối** *(G13)* — trước đây nhánh chặn chỉ `return`, thay đổi ghi trong lúc giãn cách phải chờ tới lần mở app sau
- **Danh mục cá nhân không còn sinh trùng trên máy mới** *(G14)* — tạo sau lần pull đầu tiên thay vì trước, kèm bước khử trùng lặp dọn hậu quả trên máy đã lỡ tạo
- **Ngân sách hai tab, thang bốn màu, chu kỳ chọn được và "Ngày cụ thể"** (2026-09-04) — migration v11→v12; chi tiết ở mục "💰 Ngân sách" bên dưới
- **Thoát hai vòng lặp đẩy dữ liệu vô hạn** (2026-09-04, commit `71ffc08`)
- **Từ khoá phân loại của backend nay xuống tới client** (2026-09-04) — pull đọc cột `keyword`, tách CSV, gieo vào `CategoryKeywords`; **chỉ gieo khi trống** để không hồi sinh từ khoá người dùng đã xoá
- **Bộ gợi ý danh mục so khớp được tiếng Việt không dấu** (2026-09-04) — NFC + vòng dự phòng bỏ dấu, khớp còn dấu luôn thắng
- **Vi phạm ràng buộc UNIQUE (23505) là lỗi vĩnh viễn** (2026-09-04) *(G16)* — trước đây rơi vào `transient` và đẩy lại ở mọi chu kỳ
- **Ô ghi chú có debounce 300ms và đọc từ khoá bằng một truy vấn gộp** (2026-09-04) — trước đây mỗi ký tự gõ sinh 1+N truy vấn SQLite
- **Hai loại giao dịch (Giao dịch / Chuyển khoản) + tab Vay/nợ ở bảng chọn danh mục** (2026-09-05) — chiều tiền suy từ `classify` của danh mục thay vì từ segment; danh mục vay/nợ có hàng "Chiều tiền" trên form, gợi sẵn theo tên (`suggestDebtDirection`). SQLite **vẫn** lưu `type = chi/thu/transfer` nên hợp đồng đồng bộ, DAO và thống kê không đổi; vay/nợ tính vào tổng thu/chi như thu/chi thường (quyết định có chủ ý, tách ra để dành cho Analytics). Danh sách classify gom về `core/category/category_classify.dart` thay cho 5 bản chép tay. Kèm sửa 11.11
- **Sổ giao dịch chặn vuốt xoá khoản của mục tiêu và hoá đơn** (2026-09-06) — nguyên tắc: chỉ xoá được ở sổ khi giao dịch là nguồn sự thật duy nhất của hệ quả nó gây ra; khoản nạp/rút mục tiêu còn `current_amount`, khoản trả hoá đơn còn cờ Payed + kỳ kế tiếp, xoá rời chỉ hoàn ví (đã thấy tiến độ MuaXe đứng nguyên sau khi xoá hai khoản nạp). Nhận diện ở `features/transaction/domain/transaction_owner.dart` (`goalId` cục bộ, hoặc tiền tố ghi chú vì hàng kéo từ server không có `goalId`; kể cả dạng cũ "Tích lũy nhận từ …"); hàng tách thành `TransactionListRow` với `confirmDismiss` + SnackBar chỉ đường. Hoá đơn chưa có luồng hoàn tác thanh toán — muốn cho xoá thì phải làm luồng ấy trước
- **Sổ giao dịch hiện danh mục + tên ví** (2026-09-06) — theo bố cục Stitch màn Home: tiêu đề = ghi chú (không có thì tên danh mục), dòng phụ "Danh mục • Ví" hoặc "Ví nguồn → Ví đích" với khoản chuyển, icon/màu của danh mục. Trước đó dòng phụ in thẳng UUID ví và không có danh mục ở đâu. Nội dung dòng tính ở hàm thuần `buildTransactionRowContent()` (`transaction_row_content.dart`), tên tra qua `TransactionLookup` dựng từ `walletDao.watchAll` + `categoryDao.watchAll`. **Phát hiện kèm:** seed backend lưu tên icon ngữ nghĩa (`food`, `bill`, `lend`…) còn ba mapper client chỉ hiểu tên Material → danh mục mặc định kéo về toàn rơi về icon mặc định; nay gom về **một** mapper `core/category/category_visuals.dart` hiểu cả hai bộ tên, `budget_visuals` và `category_page` uỷ quyền về đó (`category_add_page` còn bản riêng cho bộ chọn icon, chưa gộp)
- **Sổ giao dịch: chi tiết + sửa + lọc/tìm** (2026-09-06). Bấm dòng → `TransactionDetailSheet` (đọc đủ; Sửa/Xoá chỉ với giao dịch thường, khoản mục tiêu/hoá đơn chỉ đọc theo cùng quy tắc `transactionOwnerOf`). Sửa dùng lại `AddTransactionPage` với `initial: EditTransactionArgs` qua `extra` của route `/add` (cùng `id`, `UpdateTransactionEvent`); `TransactionRepositoryImpl.updateTransaction` = hoàn trọn hệ quả cũ rồi áp trọn hệ quả mới lên ví (một đường `_applyBalances(sign)` dùng chung cho thêm/xoá/sửa), ghi đè hàng và đặt lại `pending` + `updatedAt` (LWW server). Lọc: `TransactionFilter` + `applyTransactionFilter` thuần Dart trên danh sách tháng của bloc (loại, ví — khoản chuyển khớp cả nguồn lẫn đích —, danh mục, tìm ghi chú bỏ dấu); `TransactionFilterBar` chỉ phát filter, trang giữ trạng thái; thẻ tổng tính trên tập đã lọc. Trang chủ "Giao dịch gần đây" dùng chung `buildTransactionRowContent`
- **Ngân sách: nhịp chi, trang chi tiết riêng, lịch sử sáu kỳ** (2026-09-06, `0467ffd`). Thẻ trong danh sách thêm dòng "Nên chi X/ngày · còn N ngày" (`domain/budget_pace.dart`: ngày còn lại làm tròn **lên**, tối thiểu 1 khi còn trong kỳ; nhịp chi so với thời gian đã trôi, biên ±5 điểm phần trăm; mọi mốc lấy từ `currentPeriod` nên tháng ngắn và năm nhuận đúng theo). Trang **`/budget/detail/:id`** thay bottom sheet cũ: nhịp chi, sáu cột lịch sử (`domain/budget_history.dart` — `recentPeriods` đi lại đúng phép cắt của `currentPeriod`, kỳ cuối trùng kỳ hiện tại, các kỳ liền nhau không hở), và các khoản chi của kỳ dùng lại `buildTransactionRowContent` + `TransactionDetailSheet` của sổ (Sửa/Xoá đi qua `TransactionBloc`, **không** có đường xoá thứ hai). Đường dẫn là `/budget/detail/` chứ không phải `/budget/:id` vì `/budget/rules` sẽ bị tham số nuốt; đặt **ngoài** shell như trang cấu hình. Kèm sửa lỗi biên: `getExpenses` cắt `date < to` (biên **mở**) dù DAO lấy `<= to`, vì bộ chọn ngày trả 00:00 và khoản ghi ngày đầu kỳ sau từng bị đếm vào cả kỳ trước — đừng "tối ưu" bằng cách gọi DAO trực tiếp
- **Thẻ ngân sách trang chủ đọc dữ liệu thật** (2026-09-06, `13bbd9f`) — trước là placeholder cứng "Ăn uống · Chưa thiết lập". Theo Stitch màn Home: **một** ngân sách, đã dùng / hạn mức, phần trăm, thanh bốn màu, dòng nên chi/ngày. `pickHomeBudget` (hàm thuần, test riêng) chọn ngân sách **đang chạy** có **tỉ lệ** đã chi cao nhất — so tỉ lệ chứ không so số tiền, và bỏ qua ngân sách hết hạn. Bấm thẻ `go('/budget')` vì cùng shell. `home_budget_card_test.dart` là test **đầu tiên** của feature `home`, dựng ở 411dp và bắt tràn bằng `takeException`
- **Lựa chọn "Chặn" (`OverSpending = Stop`) có tác dụng thật** (2026-09-06, `91bde24`) — tồn tại trên form từ 03/09 nhưng không nơi nào đọc. Người dùng chốt: "Chặn" = **hỏi xác nhận** trước khi ghi khoản làm vượt, **không bao giờ từ chối ghi** (tiền đã tiêu thật, không ghi thì ví lệch); "Cảnh báo" = ghi luôn rồi báo. `domain/budget_impact.dart` là nơi **duy nhất** đọc `OverSpending`; ở chế độ sửa trừ số cũ ra trước, không thì báo vượt oan; khoản ngoài kỳ hiện tại không tính. `_saveTransaction` của form thêm giao dịch nay **async** (tra `budgetLookup` tiêm được, DI chưa có hoặc tra hỏng thì vẫn ghi) — widget test phải `pumpAndSettle`. Hộp thoại xác nhận nêu số vượt; snackbar sau lưu **không có con số** (banner tối giản)
- **Gợi ý hạn mức từ ba tháng trước** (2026-09-06, `f746a32`) — form hiện "3 tháng gần nhất bạn chi trung bình X" dưới ô hạn mức sau khi chọn danh mục, nút "Dùng số này" điền số thô. `BudgetRepository.suggestAmount`: trung bình ba tháng dương lịch **trước** tháng hiện tại, làm tròn lên bội 10.000, `null` khi không có khoản chi nào — và `null` thì **không hiện gì** vì "trung bình 0 ₫" tệ hơn không gợi ý. Form nhận `suggestFor` là callback (form không đọc cubit), có số thứ tự `_generation` chống hai lần tra chồng nhau; `BudgetCubit.suggestAmount` không đổi state để lỗi nhỏ không thay cả trang bằng `BudgetError`
- **Hai giới hạn có chủ ý của đợt ngân sách 06/09:** (1) **Lịch sử kỳ dùng hạn mức HIỆN TẠI cho cả kỳ cũ** (`BudgetPeriodSummary.amount`) — không có nơi nào lưu hạn mức cũ, muốn đúng phải có bảng lịch sử hạn mức ở backend; đổi hạn mức là các cột cũ đổi vạch theo. (2) **Stitch chưa có** màn chi tiết ngân sách, và màn Home lẫn màn danh sách cũng chưa vẽ dòng "nên chi/ngày" — người dùng chọn làm theo design system trước, vẽ Stitch sau; không tạo màn Stitch bằng MCP
- **Hoá đơn: gỡ lời hứa suông, bốn nhãn trạng thái đúng nghĩa, hai tab** (2026-09-06). Form Thêm có công tắc "Tự động tạo giao dịch — Thanh toán khi đến hạn" **bật sẵn** gắn vào một biến không lưu ở đâu: không cột, không bộ chạy nền — đã gỡ hẳn (làm thật là quyết định sản phẩm, không phải việc dọn lỗi). Danh sách sai bốn chỗ cùng lúc: hoá đơn **đã quá hạn** mang nhãn "SẮP ĐẾN HẠN" với vạch màu **xanh lá của khoản thu**, hoá đơn thật sự sắp đến hạn không có nhãn nào, thanh tiến độ là hằng số `0.66`, và tổng tiền gộp cả kỳ tháng sau (máy thật hiện 183.000 đ trong khi tháng này chỉ nợ 60.000 đ). Nay bốn trạng thái suy ở `domain/bill_status.dart`, ngưỡng "sắp đến hạn" **dùng lại `billLeadDays`** của bộ luật thông báo. Thêm hai tab (mỗi kỳ là một hàng mới nên lịch sử đã trả trôi lẫn vào giữa hoá đơn đang chờ), dòng "Danh mục • Ví" kèm icon danh mục, và ví của hoá đơn được gợi sẵn khi trả
- **Hoá đơn: `payStatus = 'Overdue'` gỡ được** (2026-09-06). `markOverdue` chỉ có chiều Pending → Overdue; form Sửa đẩy hạn ra tương lai thì cờ ở lại vĩnh viễn, và cột này **có đi đồng bộ** nên Admin-web đọc sai — dữ liệu thật 06/09 có hai hoá đơn mang 'Overdue' với hạn ở tương lai. Nay đi cả hai chiều, mỗi chiều vẫn có điều kiện trạng thái để không tạo vòng lặp đẩy
- **Hoá đơn: trả theo số tiền thật của kỳ, và hoàn tác được** (2026-09-06, **schema v16**). Bảng thanh toán hỏi số tiền (điền sẵn số của hoá đơn) rồi mới chọn ví; giao dịch, ví và bản ghi hoá đơn cùng nhận số đó, kỳ kế tiếp kế thừa nó. `undoPayment` hoàn trọn ba hệ quả trong một transaction: trả tiền về **đúng ví đã trừ với đúng số đã trừ** (đọc từ giao dịch, không từ hoá đơn), xoá mềm khoản chi, gỡ kỳ kế tiếp. Hai cột **cục bộ** mới `transactions.billId` và `bills.generatedFromBillId` là hai đầu của sợi dây ấy — không suy dữ liệu cũ từ tiền tố ghi chú, vì đoán trượt nghĩa là hoàn tiền bằng một khoản chi **khác** của người dùng; khoản trả ghi bằng bản cũ bị từ chối kèm lý do rõ
- **Ba trang hoá đơn có widget test lần đầu** (2026-09-06). Tầng dưới có chín tệp test còn ba trang thì không có gì — đó là lý do công tắc giả và bốn nhãn sai sống lâu như vậy. Dựng ở 411dp làm lộ ngay **sáu chỗ tràn bố cục** chưa ai từng thấy (bốn ở form Thêm, hai ở danh sách), vì bộ test và skill `chay-app` đều chạy Chrome 1280px
- **Một thanh chọn chu kỳ dùng chung** (2026-09-06, `4127f39` + `3564948`). `SegmentedChoice<T>` ở `shared/widgets/segmented_choice.dart` thay ba bộ chọn viết tay: form Thêm **và** form Sửa hoá đơn (form Sửa bỏ `DropdownButtonFormField`), form ngân sách (từng là `Wrap` hai ô mỗi hàng; nay năm ô một hàng, "Ngày cụ thể" = `null` có key `budget-cycle-null`), hai thanh của form mục tiêu (giữ màu thu). Hình dạng theo Stitch "Thêm Mục Tiêu Tiết Kiệm"; Stitch ngân sách vẽ ô viền rời và Stitch "Chỉnh sửa Hóa đơn" vẽ chip tròn — cả hai được thay bằng thanh phân đoạn để đồng nhất, **có chủ ý**. Lỗi "`Container` có `alignment` mà không có kích thước thì giãn hết ràng buộc" nay chỉ còn một chỗ để tái phát, có test canh ở widget. Đã xem cả bốn form ở 411dp trên máy ảo
- **Dữ liệu: hai hoá đơn tài khoản 10 trỏ danh mục đã xoá mềm** — đã sửa 2026-09-06 **qua form Sửa trên máy ảo** (trỏ lại "Chi khác" mặc định) để đi đúng đường đồng bộ, không UPDATE thẳng PostgreSQL; truy vấn đọc xác nhận cả hai trỏ vào hàng còn sống
- **Hoá đơn: tự động thanh toán** (2026-09-06 chiều, **schema v17**). Người dùng chọn bản đầy đủ thay vì nút "Trả ngay"; ba lựa chọn đã chốt: trừ từ **ví thanh toán của hoá đơn** (một cột cục bộ `bills.autoPayEnabled`, không cần cột ví hay "lần chạy cuối" — mỗi kỳ là một hàng, cờ đã trả là chốt chống trả hai lần), mở app muộn thì **trả bù trần 3 kỳ/hoá đơn/lượt**, trả **bất kỳ lúc nào trong ngày đến hạn**. `BillAutoPayRunner` chạy trong `NotificationScanner.scan()` sau `markOverdue` và trước khi nạp hoá đơn, đi qua `payBill` hiện có với `occurredAt = dueDate` (khoản bù mang ngày của kỳ) nên hoàn tác vẫn chạy. Hai loại thông báo `billAutoPaid`/`billAutoPayFailed` nhóm `bill`, khoá theo kỳ, `createdAt` = lúc quét. Công tắc **tắt sẵn** trên cả hai form kèm dòng phụ "chỉ nên bật trên một thiết bị" — cột cục bộ nên hai máy cùng bật, cùng offline là **hai** khoản chi; đóng hẳn cần việc D phía backend (⚠️ 2026-09-11: server đã có cột `bill.Auto_pay`, nhưng cột phía client vẫn cục bộ và chốt chống trả hai lần của backend đặt sai chỗ — CAN-LAM 17 B). Đã kiểm trên máy ảo: hoá đơn hạn hôm nay được trả ngay ở lượt quét sau khi lưu, thông báo và PostgreSQL khớp. Spec: `docs/superpowers/specs/2026-09-06-bill-auto-pay-design.md` (thư mục bị gitignore, đã `git add -f`)
- **Hoá đơn: ngày trả, ghi chú lần trả, trang chi tiết** (2026-09-06 tối, `77a70bc`…). Năm việc chốt sau khi so với Money Lover/Wallet, làm theo thứ tự: (1) tab "Đã thanh toán" ghi "Trả dd/MM/yyyy" từ khoản chi (`BillLoaded.payments`, không đoán khi thiếu) và chạm mở `TransactionDetailSheet`; (2) bảng thanh toán hỏi **ngày trả** (chặn tương lai) → `payBill(occurredAt:)`; (3) **trang chi tiết `/bills/:id`** với "Lịch sử các kỳ" theo `generatedFromBillId` (`chuoiKyCua`), nút trả/hoàn tác/sửa/xoá, mở từ dòng chưa trả; (4) "bỏ qua kỳ này" **chưa làm**, viết việc E xin backend nhận `Pay_status = 'Skipped'` (✅ 2026-09-11: backend đã nhận `'Skipped'`; tính năng phía client vẫn chưa làm); (5) ghi chú riêng mỗi lần trả nối SAU tiền tố `kGhiChuTraHoaDon`. Nhãn/màu trạng thái và ba luồng thao tác tách ra `widgets/bill_status_visuals.dart`, `widgets/bill_actions.dart`. **Bẫy đắt nhất:** `watchBills().asyncMap(...)` dưới FakeAsync nuốt `done` → `bloc.close()` treo → widget test đứng 10 phút/test; đã thay bằng `emit.onEach` + đọc riêng (mục 6.6 `BILL_DOCUMENTATION.md`)
- **Bảng thanh toán hoá đơn bố cục lại theo ý người dùng** (2026-09-06 tối): khối thông tin hoá đơn ở trên, dưới cùng một nút "Thanh toán bằng <ví của hoá đơn>" kèm "Chọn ví khác" (ví mặc định = ví của hoá đơn → ví có cờ mặc định → ví đầu danh sách), thay cho danh sách ví phải chọn; khối thông tin sau đó mở rộng đủ như trang chi tiết (trạng thái, còn/quá hạn N ngày, kỳ, chu kỳ, danh mục, ví, nhắc trước, tự trả, ghi chú) vì người dùng thấy bản đầu "khá ít". Đã xem trên máy ảo 411dp
- **Thông báo: sáu việc sửa sau một lần kiểm toàn diện** (2026-09-06 tối muộn). Bản kiểm so hệ thống hiện có với Money Lover, MISA, YNAB, Rocket Money và Monarch; sáu chỗ hỏng được sửa, xếp theo mức nghiêm trọng:
  1. **Vòng quét bị buộc vào một sự kiện MẠNG trong một app offline-first** (`6b8194b`). `NotificationScanner` chỉ quét khi `SyncEngine` phát trạng thái `isTerminal`, nhưng khi mất mạng `_runSync()` thoát sớm ở `SyncStatus.pending` — **không** phải trạng thái kết thúc. Cả một phiên offline vì thế không sinh thông báo nào, `markOverdue` không chạy, và vì hai bộ tự chuyển tiền nằm **bên trong** `scan()` nên **hoá đơn bật tự trả cũng không được trả**. Nay có ba mốc, hai trong ba không cần mạng: `start()` quét ngay, `AppLifecycleState.resumed`, và mốc đồng bộ cũ. Nguồn vòng đời là `core/notification/app_lifecycle_watcher.dart` — file duy nhất trong vùng này chạm `WidgetsBinding`
  2. **Chạm thông báo hệ điều hành không đi đâu cả** (`72c86ef`) — `onDidReceiveNotificationResponse` là callback **rỗng**. Nay `deeplinkTuDedupeKey()` suy route từ chuỗi khoá (bản sao có chủ ý của cột `deeplink`, vì ở **cold start** hàng chưa tồn tại trong SQLite), `NotificationTapRouter` là nơi duy nhất điều hướng, chặn trùng đúng một lần khi Android đẩy cùng cú chạm bằng cả hai đường, và **giữ lại** cú chạm nếu chưa đăng nhập. `FlowMoneyApp` thành `StatefulWidget` — tiện thể sửa một lỗi sẵn có: `createRouter()` bị gọi trong `build()` nên mỗi lần dựng lại là một `GoRouter` mới
  3. **Tắt nhóm làm im luôn cảnh báo tiền rời ví** (`dfb8721`). Bốn loại `billAutoPaid`/`billAutoPayFailed`/`goalAutoDeposited`/`goalAutoDepositFailed` nay đi qua `luonBao()` bất kể công tắc nhóm — "đừng nhắc tôi hoá đơn sắp tới hạn" và "đừng cho tôi biết app vừa rút tiền của tôi" là hai câu khác nhau. Lối thoát vẫn là công tắc tổng
  4. **Giờ im lặng, gộp thông báo Android, hoàn tác vuốt xoá** (`8c91c32`, schema không đổi). Giờ im lặng **tắt sẵn**, lưu bằng số phút từ nửa đêm nên khoảng vắt qua nửa đêm đúng; chỉ chặn bước bắn ra ngoài. Gộp: `khoaNhom` + bản tóm tắt id **âm** (`osScheduledId` luôn trả 0..2³¹−1), **chỉ Android**. `NotificationDao.khoiPhuc()` + SnackBar hoàn tác — cần thiết vì hàng đã xoá vẫn giữ chỗ chống trùng nên vuốt nhầm là mất vĩnh viễn
  5. **Công tắc quyền nói dối** (`0a4d3c2`). Quyền bị thu hồi trong Cài đặt máy thì công tắc vẫn sáng. `OsNotifier.daCoQuyen()` là câu **hỏi**, khác câu **xin**; hiển thị là `osBat && _coQuyenOs` nhưng `osBat` trong kho **giữ nguyên**, nên cấp lại quyền là chạy lại ngay
  6. **Một dòng nhật ký cho mỗi lượt quét** (`63a043e`) — trước đó vòng quét im lặng hoàn toàn, không phân biệt được "đã quét, không có gì" với "không quét lần nào"
  > Đã kiểm trên `emulator-5554`: quét chạy trong chế độ máy bay, chạm thông báo mở đúng màn cho cả route trong shell (`go`) lẫn ngoài shell (`push`), hoàn tác đưa hàng trở lại, công tắc quyền đúng cả hai chiều. **Việc còn lại phần lớn là thuần client** — bảng `AppNotifications` cục bộ và không nằm trong `SyncEntityType`, nên chỉ có cảnh báo giao dịch ngân hàng/OCR và thông báo bảo mật là thật sự chờ backend. ⚠️ Câu trong ngoặc ở bản trước — "kênh Socket.io chưa xác thực" — **đã lạc hậu**: backend sửa 2026-09-07, client nối 2026-09-09
- **Thông báo: ba việc treo cuối cùng nay đã nhìn tận mắt** (2026-09-07, chỉ kiểm và cập nhật tài liệu, không đổi mã). (1) **`khoaNhom`** — bằng chứng quyết định là bảng nhóm→tóm tắt của hệ điều hành trỏ vào bản tóm tắt **id −1 của app**, tức nhóm do app cầm chứ không phải `AUTOGROUP_SUMMARY` của Android 16; `mSoundNotificationKey` trỏ về thông báo thật nên `GroupAlertBehavior.children` chạy đúng. (2) **Nổ khi app đóng hoàn toàn** — tiến trình bị `am kill`, `pidof` rỗng, rồi `ActivityManager: Start proc … for broadcast {…ScheduledNotificationReceiver}` với **0 dòng `I/flutter`**. (3) **Giờ im lặng** có đối chứng: cùng luật `walletNegative`, bật thì 2 hàng vào app / **0** thông báo hệ điều hành, tắt thì 1 hàng / **1** thông báo. Ba cái bẫy mới ghi vào `NOTIFICATION_FEATURE.md` mục 8: lịch dùng `inexactAllowWhileIdle` có **cửa sổ trễ 1 giờ** nên nhảy đồng hồ tới đúng giờ hẹn thì **không nổ**; `am force-stop` huỷ sạch lịch nên phải dùng `am kill`; và trước khi nhảy đồng hồ phải đối chiếu mốc ấy với hạn hoá đơn + kỳ trích mục tiêu, vì `scan()` chạy ngay khi app quay lại tiền cảnh (tổng số dư trước/sau đều 8.890.081đ)
- **Thông báo: cảnh báo số dư ví thấp, và ví nợ ra khỏi cảnh báo ví** (2026-09-07, `80fa0cb` + `2a88dc6`, **schema không đổi**). ⚠️ **Vế "ví nợ ra khỏi cảnh báo" đã bị GỠ ngày 2026-09-09** cùng lúc với việc thu loại ví về ba — loại `debt` không còn thì chốt ấy không còn chỗ bám; xem mục ngay dưới và bẫy ở `NOTIFICATION_FEATURE.md`. Trước bản này app chỉ báo khi ví đã **âm** — tức là đã muộn. Loại thứ 14 `walletLowBalance`, nhóm `system`, khoá theo ngày như `walletNeg`. Ngưỡng là `NotificationPrefs.nguongSoDuThap` (đơn vị đồng, **cục bộ**, không đồng bộ), và **`0` vừa là ngưỡng vừa là công tắc**: một cặp công tắc-cộng-số biểu diễn được trạng thái vô nghĩa "bật nhưng ngưỡng bằng 0", còn một con số thì không. Mặc định `0` để mọi bản ghi có sẵn — vốn đều thiếu trường này — rơi về **tắt**, cùng lý lẽ với giờ im lặng. Giao diện là **danh sách chọn sẵn** (Tắt · 50k · 100k · 200k · 500k · 1tr · 2tr) chứ không phải ô nhập tiền, theo đúng lý lẽ đã ghi sẵn ở `_hangSoNgay`: gõ tay mở đường cho những giá trị mà `NotificationPrefs` lặng lẽ quy về `0`, và người dùng chỉ thấy con số của mình biến mất. **Đổi hành vi có chủ ý:** ví loại `debt` nay không sinh cảnh báo ví nào cả, kể cả `walletNegative` — ví nợ mang số dư âm là đúng bản chất của nó, trước đây nó bị nhắc lại mỗi ngày cho tới khi trả hết nợ. Thứ tự loại trừ trong `_walletCandidates` là thứ giữ cho mỗi ví ra **một** thông báo: số dư âm cũng thoả điều kiện "dưới ngưỡng". Đã xem trên `emulator-5554` ở 411dp
- **Kiểm lại danh sách việc thông báo còn lại** (2026-09-07). Một mục hoá ra **đã xong từ trước**: "ngưỡng cảnh báo ngân sách chỉnh được" — giao diện có sẵn ở `budget_form.dart:320-346`, nạp/lưu/kiểm hợp lệ đủ, vào được từ `/budget/rules` cả khi tạo lẫn khi sửa, và có `budget_form_threshold_zero_test.dart`. Con số "cứng 70/90%" mà danh sách nhắc tới là **thang màu** `_cautionAt`/`_criticalAt` ở `budget_visuals.dart`, do người dùng chốt 2026-09-04 và cố ý toàn cục — hai việc khác nhau bị gộp nhầm. ⚠️ **Đính chính 2026-09-07 (chiều):** bản trước của dòng này viết rằng khoá chống trùng dùng `budgetHealthOf().name` là "một chỗ hỏng chưa ai ghi" — **sai cả hai vế**. Việc leo lên một bậc mới sinh thêm thông báo là **thiết kế có chủ ý** và có test canh (`notification_rules_test.dart`, ca *"ĐỔI khi leo lên một bậc mới"*), với lý lẽ *"mỗi bậc được nhắc đúng một lần trong kỳ; không phân biệt bậc thì người dùng chỉ được báo ở mốc 70% rồi im lặng cho tới lúc vượt hẳn"*. Vế "không test nào phủ ngưỡng dưới 70%" cũng sai: chính ca test ấy dùng `nguongPhanTram: 60` (dòng 131–134). Bài học: mã sản phẩm cho biết code **làm gì**, chỉ test mới cho biết nó **định làm gì** — đọc mã test trước khi kết luận là lỗi
- **Danh mục mặc định thành bản sao riêng của từng tài khoản** (2026-09-07, `2c1055e`…`5120b16`, **schema không đổi**). Trước đây mọi tài khoản dùng chung 18 hàng mặc định của backend; chúng không đồng bộ và không thuộc về ai, nên người dùng **không sửa, không đổi tên, không xoá** được. Nay `DefaultCategorySeeder` chạy **sau mỗi lần pull** và tạo bản sao cho từng danh mục mặc định mà tài khoản **chưa từng** có bản cùng (tên chuẩn hoá, `classify`) — **tính cả hàng đã xoá mềm**. Ba chữ ấy là khác biệt **duy nhất** với `ensureMissing()` cũ, thứ đã sinh ra G16; bỏ chúng đi là danh mục vừa xoá mọc lại ở mỗi lần mở app. Bản sao mang `isDefault = false`, UUID mới, giữ icon/màu, **chép cả từ khoá**, và **không** kế thừa nhóm. Dữ liệu cũ trỏ vào bản mặc định được **dời trước**, ẩn sau (lỗi 11.6). Năm truy vấn hiển thị bỏ nhánh `idaccount = 0`; **`getNamesInUse` vẫn đếm** hàng mặc định (quy tắc trùng tên) và **`purgeDataForOtherAccounts` vẫn giữ** chúng (đó là cái khuôn). `foldIntoBackendDefaults()` bị gỡ vì chạy ngược chiều. Từ khoá nay **đẩy được lên backend** — cột `Keyword` và `/sync/push` đã sẵn từ trước, thiếu đúng payload phía client. **G10 đóng theo** mà backend không phải làm gì. Đã kiểm trên `emulator-5554`: tạo 13 bản sao, đẩy `36/36 succeeded`, server có 15 danh mục riêng kèm từ khoá, bộ mặc định vẫn nguyên 18. ⚠️ Máy ảo bắt được một lỗi mà bộ test không thấy: sau khi seed **không ai hẹn đồng bộ**, hàng nằm `pending` tới lần khởi động nguội sau — đã sửa (`5120b16`). ⚠️ Hai giới hạn còn: bản sao chỉ đầy đủ khi **bộ mặc định cục bộ** đầy đủ (pull tăng dần — server 18, máy kiểm tạo 13), và **màu không có cột trên server** (`CATEGORY_COLOUR_COLUMN.md`) — ⚠️ 2026-09-11: server nay có cột `category.Color`, nhưng màu vẫn không đi qua đồng bộ vì client gửi và đọc khoá `colour` còn server dùng `color` (G24) — ✅ sửa cùng ngày, khối "Sửa khoá màu danh mục" mục 14
- **Trung tâm thông báo: lọc, phân trang, đánh dấu chưa đọc** (2026-09-07 tối, **schema không đổi**, chỉ hai file mã). Trước bản này trang `/notifications` đọc thẳng `watchFeed(idaccount)` với mặc định 50 hàng và không có bộ lọc nào — thông báo thứ 51 không xem lại được trong khi bảng giữ dữ liệu 90 ngày. Nay `watchFeed` nhận thêm `kinds` và `chiChuaDoc`, trang có dải sáu chip (Tất cả · Chưa đọc · Hoá đơn · Ngân sách · Mục tiêu · Hệ thống) cuộn ngang, tải 20 hàng một lần kèm nút "Tải thêm", và **nhấn giữ** một mục để đảo cờ đã đọc — đường quay lại cho nút "Đọc tất cả", vốn đọc hộ cả những mục người dùng chưa kịp xem. Lý do của từng quyết định (vì sao DAO nhận `List<String>` chứ không phải `NotificationGroup`, vì sao `null` khác danh sách rỗng, vì sao không dùng truy vấn `COUNT`) ở **mục 4.6 `docs/NOTIFICATION_FEATURE.md`**. Đã xem trên `emulator-5554` ở 411dp: dải chip không tràn và cuộn tới được cả sáu, lọc "Hoá đơn" thu 6 mục xuống 2, nhấn giữ đảo đúng cả hai chiều. ⚠️ **Phân trang chưa nhìn tận mắt** — tài khoản kiểm thử chỉ có 6 thông báo còn trang đầu tải 20, nên nút "Tải thêm" không có cớ xuất hiện; nó chỉ được phủ bằng widget test. ⚠️ Bẫy mới, đã ghi vào **7.10 mục 4**: `longPress` kích hoạt luôn `onTap` khi widget chưa có `onLongPress`, nên một test nhấn giữ chỉ kiểm trạng thái CSDL có thể **xanh giả**
- **Thông báo: nhắc ghi chép hằng ngày** (2026-09-07 tối, **schema không đổi**). Loại nhắc duy nhất trong app suy từ việc **không có** dữ liệu — và cố ý **không phải** một `NotificationKind` nào cả. (Lúc viết dòng này bảng có 14 loại; nay là **16** — `goalMilestone` thêm 2026-09-08, `weeklySummary` thêm 2026-09-09. Con số đổi, lý lẽ dưới đây thì không.) Lý do: mười bốn loại kia là *bản ghi* một việc đã xảy ra và người dùng đọc lại chúng trong trung tâm thông báo, còn lời nhắc này chỉ có nghĩa khi họ **đang không mở app**; lúc mở ra xem thì nó đã hết lý do tồn tại. Nên nó **không sinh hàng nào** trong `AppNotifications` và sống hoàn toàn trong `ReminderScheduler` — nguồn ứng viên **thứ ba** bên cạnh hoá đơn và mục tiêu. Mỗi lượt `resync()` đặt **ba lịch rời** (hôm nay + hai ngày kế) vào giờ người dùng chọn, **bỏ qua hôm nay nếu đã có giao dịch**. Ba lịch rời chứ không phải một lịch lặp `DateTimeComponents.time`: lịch lặp chỉ tốn một suất nhưng **không bỏ qua được ngày nào**, nên nó nhắc cả những hôm người dùng đã ghi rồi. Ba ngày vì trần 50 tính trên **tổng mọi** nguồn (ba lúc ấy; **bốn** từ 2026-09-09, khi Tổng kết tuần thêm vào) và phép cắt sắp theo thời gian — lịch hằng ngày luôn gần nhất nên nó *thắng* nhắc hoá đơn, mà hoá đơn là tiền còn nhắc ghi chép là thói quen. Đầu vào mới: `TransactionDao.getLastTransactionDate()`; `null` = chưa từng ghi = **vẫn nhắc**. Ba trường mới trong `NotificationPrefs` (**cục bộ**, không đồng bộ), **mặc định TẮT**, giờ **riêng** mặc định **20:00** — không dùng chung `gioNhac` (08:00, của hoá đơn), và giờ im lặng **không chặn** nó. Chạm vào mở thẳng **`/add`**. Lý do đầy đủ ở **mục 4.7 `docs/NOTIFICATION_FEATURE.md`**. 28 test mới. **Đã đo trên `emulator-5554`** (đồng hồ máy ảo 21:34): bật → đúng hai lịch 20:00 cho 08/09 và 09/09, lịch hôm nay bị bỏ vì đã trôi qua; tắt → cả hai biến mất; bật lại → cả hai trở về; bốn lịch hoá đơn 08:00 nguyên vẹn suốt ba lượt. ⚠️ **Đổi tuỳ chọn không đặt lại lịch ngay** — lịch chỉ theo kịp ở lượt quét sau; đây là hành vi **có sẵn**, đúng vậy với `gioNhac` từ trước, nhưng trên máy thật nó trông hệt một lỗi
- **Thông báo: nút hành động trên thông báo hệ điều hành** (2026-09-07 tối, **schema không đổi**). Hai nút trên nhắc hoá đơn: **"Trả ngay"** mở thẳng trang chi tiết hoá đơn ấy, **"Hoãn 1 ngày"** dời lịch 24 giờ **hoàn toàn trong isolate nền**, không mở app. ⚠️ **Cố ý KHÔNG có nút "Đã trả"**: `payBill` chuyển tiền thật (tạo giao dịch, trừ ví), và chạy nó trong isolate nền là chuyển tiền ở nơi không có giao diện, không xác nhận ví, không chỗ báo lỗi — đi ngược đúng nguyên tắc đã chốt cho hai chỗ tự chuyển tiền còn lại. Ai muốn một chạm là trả thì đã có `autoPayEnabled`. Mọi phép quyết định nằm ở `notification_actions.dart` (file thuần, không import plugin — bẫy 7.7 cộng với việc `flutter test` không dựng được isolate nền). Lý do đầy đủ ở **mục 4.8 `docs/NOTIFICATION_FEATURE.md`**. 23 test mới.
  > **Ba lỗi chỉ máy thật mới thấy, cả ba đều im lặng** — đây là ví dụ mạnh nhất từ trước tới nay cho quy tắc "đụng giao diện/điều hướng thì phải chạy máy ảo":
  > 1. **Thiếu `ActionBroadcastReceiver` trong `AndroidManifest.xml`.** Nút hiện đúng, `dumpsys notification` báo `actions=2` với `PendingIntent` đúng kiểu, nhưng không tiến trình nào nhận. Plugin **không tự khai báo** receiver này. Nay có `android_manifest_receivers_test.dart` canh **cả ba** receiver — vùng mà `flutter test`, `flutter analyze` và `flutter build apk` đều không nhìn thấy. Xem bẫy **7.11**.
  > 2. **`resync()` huỷ mất lịch vừa hoãn.** Lý lẽ "cùng khoá nên sống sót" **sai**: nhánh bỏ qua ấy chỉ chạy cho lịch resync *muốn*, mà hoá đơn chỉ được muốn khi mốc nhắc còn ở tương lai — trong khi chỉ hoãn được **sau khi** thông báo đã nổ. Sửa bằng tập `khongHuy` trong `resync()`.
  > 3. **"Trả ngay" ở cold start mở nhầm danh sách.** Một cú bấm có **hai** đường vào; `payloadKhoiDong()` đọc `payload` mà bỏ qua `actionId`. Nay cả hai gọi chung `khoaSauChamNut()`.
- **Thông báo: badge số trên icon app** (2026-09-08, **schema không đổi**). `BadgeUpdater` nghe `watchUnreadCount` rồi đẩy sang `OsNotifier.datBadge()`; `NotificationScanner` **sở hữu** vòng đời của nó (`auth_bloc` đã có bốn chỗ start/stop, một lối song song là bốn chỗ nữa phải nhớ). Hai method mới trên interface: `activeIds()` và `datBadge()`. ⚠️ **Huỷ CHỌN LỌC, tuyệt đối không dọn sạch khay**: chỉ huỷ id suy từ `dedupeKey` của hàng đã đọc/đã xoá mềm, vì lịch hoá đơn nổ lúc app đóng và nhắc ghi chép hằng ngày **nằm trên khay mà bảng không biết** — số chưa đọc bằng 0 KHÔNG có nghĩa là khay phải trống. Và **không bao giờ `cancelAll()`**: nó cuốn theo cả lịch đang chờ trong AlarmManager. Lý do đầy đủ ở **mục 4.9 `docs/NOTIFICATION_FEATURE.md`**. 11 test mới.
  > ⚠️ **Đo trên máy thật đã sửa lại chính lời hứa ban đầu:** con số **gần như không bao giờ hiện trên Android** — nó nằm trên bản tóm tắt nhóm, mà Android **tự gỡ bản tóm tắt khi nhóm chỉ còn một thông báo con**, và một là số lượng thường gặp nhất. Khay trống thì `datBadge(6)` chạy trót lọt mà không hiện gì cả. Nên trên Android badge thực chất là **chấm**, suy từ *thông báo đang trên khay* chứ không từ số chưa đọc; con số chỉ có nghĩa cho iOS và cho launcher nào vẽ được. Phần người dùng thấy vẫn đúng: **đọc hết trong app thì chấm tắt**.
  > **Bằng chứng** (`emulator-5554`, Pixel Launcher): tạo hoá đơn tuần hạn 10/09 → `[BadgeUpdater] badge=7, khay=2, đã huỷ=0` và **icon có chấm**; bấm "Đọc tất cả" → `badge=0, khay=1, đã huỷ=1`, `dumpsys notification` còn **0** record của app, **chấm tắt**.
  > Bài học kèm theo: `catch` **câm** ở `dongBo()` suýt dẫn tới kết luận sai rằng code không chạy — mất một vòng dựng lại APK. Nay nó ghi `debugPrint`, và chính dòng log ấy phân định được "không chạy" với "chạy đúng nhưng Android không vẽ".
- **Mục tiêu: lịch sử tích luỹ cắt 5 dòng, phần còn lại vào bảng có bộ lọc** (2026-09-08, **schema không đổi**). Người dùng hỏi phần lịch sử có quá dài không. Đo: 11 khoản cuộn hết trong **2 cú vuốt** — chưa dài, nhưng danh sách **không có trần** (`itemCount: txs.length`), và một mục tiêu trích hàng ngày chạy hai năm là **730 dòng**. Nửa kỹ thuật không nhìn màn hình mà thấy được: `shrinkWrap` + `NeverScrollableScrollPhysics` trong `SingleChildScrollView` của cả trang tức **dựng mọi dòng cùng lúc, không ảo hoá** — trên một trang mà từ hôm nay vẽ lại mỗi lượt đồng bộ. Nay trang giữ **5 dòng**, phần còn lại vào một **bottom sheet** có vùng cuộn riêng, kèm **hai bộ lọc giao nhau**: chiều tiền và khoảng thời gian. 18 test mới.
  > Nút **"Xem tất cả"** từng bị gỡ ngày 2026-09-06 vì nó có `onPressed: () {}`. Lý lẽ ấy nói về một nút **rỗng**, không nói rằng danh sách phải hiện hết mãi mãi — nay nút quay lại và **làm thật**. Đây là ca đúng mẫu bài học đã lưu: một quyết định có chủ ý chỉ chứng minh ai đó đã cân nhắc MỘT tình huống.
  > ⚠️ **Không có bộ lọc "tay / tự động"**, và đó là giới hạn của **dữ liệu**: `GoalAutoDepositRunner` gọi đúng `depositToGoal` với đúng tiền tố ghi chú của khoản nạp tay nên hai loại giống hệt nhau trên mọi cột. Sự giống nhau ấy **có chủ ý** (mục 3.12) — nhờ nó `laKhoanRutKhoiMucTieu` đọc đúng chiều cho cả hai. Muốn phân biệt phải thêm **cột mới**; **đổi tiền tố ghi chú là cách sai**, nó đâm thẳng vào bẫy 4.2.
  > ⚠️ Bảng là **bottom sheet chứ không phải trang mới**: mọi route mới đều phải trả lời câu hỏi *có nằm trong `StatefulShellRoute` không* (bẫy 7.8), còn bottom sheet không đụng router.
  > **Một test xanh oan đã bị bắt.** Ca "biên tính theo ngày" viết lần đầu **không thật sự canh điều nó nói** — chỉ lộ ra khi dựng bản sai có chủ ý, và bản sai ấy chạy qua nó trót lọt. Đã viết lại để test đúng ca *khoản lúc rạng sáng ngày biên*. Đây là lần thứ hai trong ngày kỹ thuật này lộ ra test vô dụng.
  > **Đã kiểm trên `emulator-5554`**: trang chi tiết còn đúng 5 dòng kèm nút "Xem tất cả"; bảng mở ra hiện **"11 khoản · đã gửi 2.201.000 đ"**, hai dải chip, 0 pixel vàng; chọn "Đã rút" ra rỗng kèm câu giải thích (MuaXe thật sự không có khoản rút nào), và "Đã rút" + "30 ngày" giao nhau đúng.
- **Mục tiêu: hộp dự báo hết ngoại suy, và khối "Cấu hình" trên trang chi tiết** (2026-09-08, **schema không đổi**). Người dùng báo trang chi tiết **thiếu nội dung**. Đo lại thì phát hiện **một lỗi thật** nằm ngay trên màn hình ấy: mục tiêu `MuaXe` tạo 05/09, xem 08/09, đã tích 1.101.000 đ, chu kỳ tháng → hộp dự báo hiện *"đang tích **11.010.000 đ** mỗi tháng"* — gấp mười lần tổng đã tích được cả đời mục tiêu — kèm dự báo hoàn thành ngay tháng ấy cho một mục tiêu hạn 2028. Số học đúng (`1.101.000 / 3 ngày × 30`), cái sai là **ngoại suy**: phép chặn cũ chỉ có `soNgayDaQua <= 0`, tức chỉ đỡ phép chia cho 0 chứ không đỡ việc bịa ra một nhịp. `_duCuaSo` nay đòi **ít nhất nửa chu kỳ**, và ngưỡng tính **theo chu kỳ** chứ không phải một số ngày cứng. 20 test mới.
  > Còn lại thì trang **không thiếu dữ liệu — nó thiếu chỗ hiển thị**. Bốn thứ của khối `GoalConfigCard` đều nằm sẵn trên `GoalEntity`: hạn chót + `daysLeft` (**không nơi nào gọi** trước đó), `isBehindSchedule` (chỉ dùng cho thông báo), tên ví tích luỹ (chỉ dùng cho hộp thoại), và **trích tự động** (không hiện ở đâu).
  > ⚠️ **Dòng trích tự động là chỗ nghiêm trọng nhất:** app tự chuyển tiền mỗi kỳ mà trang chính của mục tiêu không nói gì, phải mở trang Sửa mới biết. Với một tính năng chuyển tiền lúc người dùng vắng mặt thì đó là chỗ im lặng không chấp nhận được.
  > **Đã kiểm trên `emulator-5554`**: hộp dự báo nay hiện *"CHƯA ĐỦ DỮ LIỆU ĐỂ DỰ BÁO"* kèm lý do đúng (thiếu **thời gian**, không phải thiếu số lần nạp — câu cũ nói sai hướng); khối Cấu hình hiện `27/04/2028 · Còn 597 ngày`, `Đang đúng nhịp`, `Tiết kiệm`, và **`100.000 đ mỗi tháng từ test`** — tức mục tiêu ấy vẫn đang tự trừ tiền, thứ trước bản này màn hình không hề nói. 0 pixel vàng ở khổ 411dp.
- **Trang chủ: bỏ khối thông báo, thêm khối mục tiêu** (2026-09-08, **schema không đổi**). Hai thay đổi đi cùng nhau vì cái sau lấy đúng chỗ cái trước để lại. **Gỡ `NotificationPanel`** theo yêu cầu người dùng: thông báo chỉ xem khi bấm vào chức năng đó, tức cái chuông ở thanh tiêu đề. **Thêm `HomeGoalCard`**: trước đó mục tiêu chỉ vào được qua **một dòng trong drawer**, trong khi ngân sách đã có hẳn một khối — một tính năng có trích tự động, dự báo và cột mốc mà bị chôn ba lớp. Phép chọn `chonMucTieuTrangChu` **gọi `chiaMucTieu`** chứ không tự lọc và tự sắp: thứ tự mục tiêu có đúng MỘT định nghĩa, và viết lại ở đây là bản sao thứ hai chờ ngày lệch (bài học mục 3.6 và 3.18). 12 test mới.
  > ⚠️ **Cả hai thay đổi đều đi LỆCH thiết kế Stitch màn Home**, nơi khối thông báo nằm ngay đầu trang và **không có** phần mục tiêu nào. Lệch có chủ ý theo yêu cầu người dùng; ghi ở cả hai chỗ trong mã để lần sau đối chiếu Stitch thì biết đây không phải bỏ sót.
  > `NotificationPanel` **vẫn còn** trong mã nguồn dù nay không nơi nào dựng nó: hai trang thông báo trích dẫn nó làm **mẫu** cho lối *"trang không tự đi hỏi `AuthBloc`"*, và test 97 dòng của nó canh đúng lối ấy. Gỡ luôn là làm hỏng hai chú thích và mất một phép canh, đổi lấy đúng 157 dòng.
  > ⚠️ Chạm thẻ đi `/goals` bằng **`push`**, không phải `go`: `/goals` nằm NGOÀI `StatefulShellRoute` (bẫy 7.8 `NOTIFICATION_FEATURE.md`). `_buildBudgetSection` ngay bên cạnh thì dùng `go` vì `/budget` ngược lại, nó **thuộc** shell — hai dòng cạnh nhau, hai cách gọi khác nhau, và cả hai đều đúng.
  > **Đã kiểm trên `emulator-5554`**: trang chủ không còn khối thông báo, chuông vẫn ở thanh tiêu đề; thẻ mục tiêu hiện **MuaXe** — cái có `priority` 100 — dù MuaDT hạn gần hơn (05/09/2027 so với 27/04/2028), tức ưu tiên đã thắng hạn định trên máy thật; chạm vào mở `/goals` kèm nút quay lại. Cụm pixel vàng duy nhất trên ảnh là **bóng đèn thẻ Insight AI** (34×50 px), không phải sọc tràn.
- **Mục tiêu: trang chi tiết nghe dòng dữ liệu** (2026-09-08, **bẫy 4.5 đóng**). `GoalDetailPage` vốn gọi `getGoalById` đúng một lần trong `initState` rồi tự giữ `_goal` trong `State`, nên đồng bộ kéo về một thay đổi của mục tiêu **đang mở** thì màn hình vẫn hiện số cũ — không lỗi, không log, chỉ phát hiện khi thoát ra vào lại. Bán kính vừa rộng thêm vì `priority` nay cũng đi qua đường đồng bộ. Nay trang đăng ký `watchGoals` và huỷ ở `dispose()`. 3 test mới.
  > Ba quyết định: nghe **cả tài khoản** chứ không riêng mục tiêu này (vì `_canhBaoVi` cộng dồn mọi mục tiêu trỏ vào cùng ví, nên một mục tiêu *khác* nạp tiền cũng làm câu cảnh báo đổi); lấy mã tài khoản từ **chính mục tiêu vừa đọc** chứ không từ `AuthBloc` (hàm chạy sau một `await` nên `context` có thể đã tháo — đọc phiên ở đó là mở lại đúng cửa G17 vừa đóng); và **không đụng `_isLoading`** ở đường stream (đây là cập nhật nền, bật cờ tải làm cả trang nháy về vòng quay mỗi lần đồng bộ xong).
  > ⚠️ Hàng có thể **biến mất** khỏi danh sách vì vừa bị xoá mềm ở máy khác; khi ấy giữ nguyên những gì đang hiện. `firstWhere(orElse: () => throw)` ở đó là màn đỏ ngay giữa một lượt đồng bộ nền — có test canh riêng ca này.
- **Mục tiêu: thông báo cột mốc 25/50/75%** (2026-09-08, **schema không đổi**). Trước bản này app chỉ lên tiếng về một mục tiêu ở **hai** thời điểm — đạt 100% (`goalCompleted`) và chậm tiến độ (`goalBehind`) — nên người dùng đi ba phần tư chặng đường mà không được ghi nhận gì. `goalMilestone` là `NotificationKind` **thứ mười lăm**. Ba quyết định: vượt nhiều mốc cùng lúc thì chỉ báo **mốc cao nhất** (nạp một phát từ 10% lên 80% vượt cả ba; ba tin cho một thao tác là ồn); khoá chống trùng theo khuôn `goalCycle:` **chứ không** khuôn `goalDone:` vì mục tiêu **lặp lại** phải được báo lại mỗi vòng; và luật phải đứng **TRƯỚC** phép kiểm `isBehindSchedule`, nếu không chỉ mục tiêu đang trễ mới được ghi nhận quãng đã đi. Lý do đầy đủ ở **mục 3.21 `docs/GOAL_FEATURE.md`**. 10 test mới.
  > Dựng **bản sai có chủ ý** để kiểm cái bẫy thứ ba (dời luật xuống sau `isBehindSchedule`): **3 test đỏ**. Test xanh sẵn không chứng minh gì — đây là lần thứ năm kỹ thuật này đáng công trong dự án.
  > ⚠️ Hai test cũ phải sửa, và **cả hai đều là lưới an toàn hoạt động đúng**: phép canh *"phủ đủ cả 14 loại"* của `notification_deeplink_test` đỏ vì nay có 15 (và phải dựng thêm một mục tiêu 50% — hàng 20% cũ không sinh cột mốc); còn *"đi đúng nhịp thì im lặng"* dùng `expect(ra, isEmpty)` cho một mục tiêu **70%**, tức một phép canh **rộng hơn** điều nó muốn nói. Thu hẹp về đúng `goalBehind` thay vì nới luật.
  > **Đã kiểm trên `emulator-5554`**: `dumpsys notification --noredact` cho `android.title=(Đã đi được 50% chặng đường)` trên mục tiêu `MuaXe` 1.101.000/2.000.000 = 55%.
- **Mục tiêu: thứ tự ưu tiên kéo thả** (2026-09-08, **schema v19**). Danh sách vốn sắp cứng theo hạn gần nhất nên người dùng không nói được *"quỹ khẩn cấp quan trọng hơn cái laptop"*. Cột `Priority Int?` phía backend có từ 2026-09-07 — đây là việc **duy nhất** mà backend đã làm xong phần của họ mà client chưa nhận. Quy ước giá trị lấy **nguyên** từ `DA-XONG/2026-09-05-backend-goal-priority.md` mục 4, không phát minh lại: số **cách nhau 100**, `NULL` xếp **cuối**, trùng số rơi về `targetDate`. `uuTienSauKhiKeo` có **hai chế độ** — còn khe thì ghi **một** hàng, hết khe hoặc còn hàng `null` thì đánh số lại cả danh sách; lần kéo đầu luôn rơi vào chế độ hai và đó là *một* lần trong đời danh sách. Chỉ tab "Đang theo đuổi" dùng ưu tiên. Payload mục tiêu nay **22 trường** (đếm lại 2026-09-08; dòng này từng ghi "18 → 19" vì cộng dồn mà quên ba cột `auto_deposit_*`). Lý do đầy đủ ở **mục 3.22 `docs/GOAL_FEATURE.md`**. 24 test mới.
  > ⚠️ **`ReorderableListView.onReorder` trả `newIndex` tính trên danh sách CÒN NGUYÊN phần tử đang kéo**, nên kéo *xuống* thì con số ấy lớn hơn vị trí cuối cùng đúng một đơn vị. `viTriThaThucTe` là chỗ duy nhất sửa việc đó, và nó có test riêng — dùng thẳng `newIndex` là mục tiêu rơi lệch một ô, im lặng.
  > ⚠️ Migration v19 **cố ý không suy giá trị** cho hàng cũ, khác hẳn `anchorDay` của v18: ở đó ngày đến hạn là ý định người dùng đã đưa ra và chỉ cần đọc lại, còn ở đây mọi thứ tự bịa ra đều sai với người đã sắp tay. Cùng lập luận đã dùng cho v15 và v17.
  > ⚠️ Hai test migration hoá đơn (v17, v18) đỏ vì bản dựng thử của chúng chỉ có bảng `bills`, mà v19 `ALTER TABLE goals`. Sửa ở phía **bản dựng thử** — một CSDL v17 thật luôn có bảng ấy — chứ không bọc `try/catch` quanh migration.
  > **Đã kiểm trọn vòng trên `emulator-5554`**: kéo `MuaXe` (hạn 27/04/2028) lên trên `MuaDT` (hạn 05/09/2027) → đổi ngay, **sống qua khởi động nguội**, và truy vấn thẳng PostgreSQL thấy `Priority` **100 / 200** — tức lần kéo đầu đánh số lại cả danh sách và cả hai hàng đã lên tới server. 0 pixel vàng ở khổ 411dp.
- **Hoá đơn: ngày gốc thay cho quy tắc đoán cuối tháng** (2026-09-08, **schema v18**). Người dùng báo: đăng ký hoá đơn định kỳ vào 28/02 thì ô "Ngày đến hạn" (chỉ đọc) hiện **31/03** thay vì 28/03. Nguyên nhân: `nextBillDueDate` áp quy tắc *"mốc rơi đúng ngày cuối tháng thì kỳ sau cũng rơi vào ngày cuối tháng"* — một phép **đoán ý định từ dữ liệu**, đúng cho chuỗi bắt đầu 31/01 nhưng sai cho người chọn 28/02. Nay cột cục bộ `Bills.anchorDay` lưu **ngày người dùng thật sự chọn** và được chép sang từng kỳ, nên hai chuỗi cùng đi qua 28/02 vẫn tách được nhau: gốc 31 → 28/02 → **31/03** → 30/04; gốc 28 → 28/02 → **28/03** → 28/04. Đây đúng mô hình `advancePeriodFrom(anchor, steps)` mà ngân sách dùng từ đầu, nên ba vùng ngày tháng nay nhất quán. Lý do đầy đủ ở **mục "Ngày gốc" `docs/bill/BILL_DOCUMENTATION.md`**; xin cột đồng bộ ở `docs/superpowers/backend/DA-XONG/BILL_ANCHOR_DAY.md` (✅ 2026-09-11: server đã có cột `bill.Anchor_day`; phía client cột vẫn cục bộ). 22 test mới.
  > ⚠️ **Ba chốt chặn, cả ba đều hỏng âm thầm nếu sai:** (1) migration suy ngày gốc từ **ngày đến hạn**, không phải ngày bắt đầu — hoá đơn `bắt đầu 28/02, hạn 31/03` phải ra gốc **31**, lấy ngày bắt đầu là hạ nó xuống 28 vĩnh viễn mà người dùng không bấm gì; (2) `BillSchedule.fromBill` **không** suy lại ngày gốc từ ngày bắt đầu, nếu không mở form Sửa rồi lưu là đổi hạn của kỳ giữa chuỗi; (3) đổi ngày bắt đầu trên form thì ngày gốc **đi theo** — giữ gốc cũ là hoá đơn vừa đổi sang ngày 15 vẫn đến hạn ngày 31.
  > **Đã kiểm trên `emulator-5554`**: form Thêm hoá đơn định kỳ, chọn 28/02/2026 → ô hạn hiện **28/03/2026**. Migration v17→v18 chạy êm trên CSDL thật đang có dữ liệu.
  > Đã cân nhắc và **loại RRULE (RFC 5545)**: đặc tả bỏ qua occurrence rơi vào ngày không tồn tại, nên `FREQ=MONTHLY;BYMONTHDAY=31` **không sinh kỳ nào cho tháng Hai** — hoá đơn biến mất. Lý lẽ đầy đủ ở mục 5 tài liệu xin backend.
  > Bài học quá trình: lần đầu điều tra tôi tìm thấy quy tắc ấy được ghi là "đánh đổi có chủ ý, quyết định 2026-09-04" mô tả **đúng** ca người dùng gặp, nên kết luận đây không phải lỗi. Sai. Lý lẽ biện minh cho nó (*"chuỗi mất mốc gốc để neo"*) **không thành lập ở kỳ đầu tiên**, nơi mốc gốc chính là ngày người dùng vừa chọn. Một quyết định có chủ ý chỉ chứng minh ai đó đã cân nhắc **một** tình huống, không chứng minh nó đúng ở **mọi đường dẫn** tới đoạn mã ấy.
- **Mục tiêu: nhịp trích tự động neo vào mốc gốc, không còn trôi** (2026-09-08, **schema không đổi**). Cùng bệnh với hoá đơn, phát hiện khi rà soát: `cacKyDenHan` và `kyKeTiep` bước **từng kỳ một** từ mốc trước đó, nên mốc "ngày 31" bị kẹp về 28/02 rồi bước tiếp *từ 28* — nhịp tụt xuống 28 vĩnh viễn, im lặng. Nay mọi mốc tính từ mốc gốc qua `mocThuN(goc, chuKy, n)`: `31/01 → 28/02 → 31/03 → 30/04`. Mốc gốc là `timeCycleTakeMoney`; mục tiêu bật trước khi có ô chọn ấy thì gốc rơi về `autoDepositLastRun`, giữ nguyên hành vi cũ. Lý do ở **mục 3.12 `docs/GOAL_FEATURE.md`**. 7 test mới.
  > Chú thích cũ ở cột `Goals.timeCycleTakeMoney` ghi *"client chưa bao giờ ghi"* — **sai từ lâu**: `GoalRepositoryImpl` ghi nó ở cả đường tạo lẫn đường sửa khi bật trích tự động. Đã sửa lại chú thích; nó từng là lý do tin rằng mốc neo không dùng được làm gốc.
  > Mức nghiêm trọng thấp hơn hoá đơn có chủ ý được ghi lại: trích tự động chỉ chuyển tiền giữa hai ví **của chính người dùng**, sớm vài ngày không lỡ cam kết với ai. Hoá đơn thì "ngày trả tiền nhà" là ngày với người khác.
- **Phân tích: lát 2c‑1 — trang Xuất báo cáo đọc số thật, thêm màn Xem trước** (2026-09-09, **schema không đổi**). Trang này là chỗ số cứng cuối cùng của mảng Phân tích: chip ví ghi "Techcombank"/"Tiền mặt" bịa ra, khối "Lịch sử xuất gần đây" ghi hai tên tệp bịa, nút xuất chỉ hiện snackbar. Nay ví/danh mục/thời gian lấy từ CSDL qua `BaoCaoRepository`, và nút mở màn **Xem trước báo cáo** dựng theo màn Stitch sinh cùng ngày. Tầng thuần mới `bao_cao_xuat.dart` **mượn nguyên** `tongThuChi`/`chiTheoDanhMuc` của `thong_ke_thang.dart` nên hai trang không thể nói hai con số khác nhau về cùng một tháng. Ba khối bịa đã bỏ hẳn, cùng ô `.xlsx`. Người dùng chốt hướng "xem trước rồi mới tải xuống", nên nút **Tải xuống để `onPressed: null`** cho tới lát 2c‑2 — có test canh đúng chỗ ấy. Lý do đầy đủ ở **mục 3.13 và 3.14 `docs/ANALYTICS_FEATURE.md`**. 46 test mới (4 tệp).
  > Hai **bản sai có chủ ý** ở tầng thuần, mỗi bản đúng một test đỏ: lấy thẳng ngày cuối người dùng chọn làm biên `to` (mất trọn ngày cuối), và sắp nhóm ngày tăng dần. Một bản nữa ở repository: tra tên danh mục bằng `categoryDao.getAll` (lọc hàng đã xoá mềm) → dòng báo cáo mất tên thật.
  > ⚠️ **Bẫy mới, mức trắng-cả-trang:** theme của app đặt `minimumSize: Size(double.infinity, 52)` cho mọi `ElevatedButton`. Nút đặt trần trong một `Row` đòi bề ngang vô hạn, Flutter bỏ layout **cả khung hình** — trang chỉ còn AppBar trên nền trơn, **không màn đỏ và không một dòng nào trong `adb logcat`**. Bộ test không thấy vì nó dựng bằng `MaterialApp` **trần**. Cách sửa: widget test phải dựng bằng `AppTheme.lightTheme`; làm vậy là test đỏ ngay, rồi mới bọc `Expanded`. Ghi ở bẫy **4.11 `ANALYTICS_FEATURE.md`**.
  > Màn Xem trước **không có trong Stitch cũ**, nên đã **sinh vào chính dự án Stitch** (`f0a0d1457401478596753a48531bc097`, design system "Kinetic Finance") rồi mới dựng Flutter theo nó. ⚠️ `generate_screen_from_text` **báo timeout hai lần nhưng cả hai đều thành công**, và `list_screens` cập nhật chậm hơn `get_project` nhiều phút — đừng dùng `list_screens` để kết luận "sinh hỏng". Hậu quả: dự án có một màn trùng phải xoá tay, MCP không có lệnh xoá màn.
  > **Đã kiểm trên `emulator-5554`** (tài khoản 10): chip ví hiện đúng ba ví thật (Tiết kiệm / Tiền mặt / test); báo cáo tháng 9 ra 14.625.000 − 1.045.000 = 13.580.000, **khớp từng đồng với trang Phân tích**; "Tháng trước" ra `01/08/2026 – 31/08/2026` với trạng thái rỗng; 0 pixel vàng ở khổ 411dp.
- **Phân tích: lát 2c‑1b — báo cáo chi tiết theo chuẩn app thị trường** (2026-09-09, **schema không đổi**). Người dùng xem bản 2c‑1 rồi nói *"chỉ có các thông tin cơ bản, hãy tham khảo các app quản lý tài chính cá nhân tương tự"*. Khảo sát Money Lover, MISA MoneyKeeper, Copilot, PocketSmith → tờ báo cáo từ **bốn khối lên mười**: dòng tiền (số dư đầu/cuối kỳ, kiểu Money Lover), phần trăm **so với kỳ liền trước** (Copilot), **thu theo danh mục** đối xứng với chi (PocketSmith, lối bảng lãi–lỗ cá nhân), biểu đồ thu chi trong kỳ, số liệu nhanh, **ngân sách kỳ này** (chỗ FlowMoney mạnh hơn Money Lover), phân bổ theo ví, top 5 khoản chi. `chiTheoDanhMuc` nhận thêm tham số `loai` để dựng cả hai chiều — **một định nghĩa**, không viết bản sao. Lý do đầy đủ ở **mục 3.15 và 3.16 `docs/ANALYTICS_FEATURE.md`**. 38 test mới.
  > **Dòng tiền là số suy ngược** từ số dư ví hiện tại, và có hai giới hạn đã ghi thẳng lên màn hình: **biến mất khi lọc theo một ví** (chiều tiền của `transfer` không suy được từ vị trí ví — bẫy mục 3.2 `GOAL_FEATURE.md`), và **lệch khi có ví tạo giữa kỳ** (số dư ban đầu của ví không phải một giao dịch — đã kiểm mã `lib/features/wallet`).
  > `khoangKyTruoc` lùi **theo tháng** khi khoảng trùng khít tháng dương lịch, không trừ số ngày: tháng 9 dài 30 ngày nên trừ 30 ngày ra `02/08–01/09`, lệch một ngày và phần trăm sai mà không ai thấy. Ba **bản sai có chủ ý** đã chứng minh test bắt được: bỏ nhánh lùi theo tháng (**3 test đỏ**), bỏ bước trừ phần sau kỳ của dòng tiền, và sắp nhóm ngày tăng dần.
  > ⚠️ Trang dài ra làm hỏng lối viết test cũ: `ListView` **không dựng** hàng ngoài khung nhìn, và một con số nay xuất hiện ở nhiều khối. Test phải `scrollUntilVisible` rồi tìm **trong phạm vi** một khối bằng `Key` — bẫy **4.12**.
  > **Đã kiểm trên `emulator-5554`** (tài khoản 10): ngân sách hiện *"Di chuyển 285.000/50.000 — Vượt 235.000 đ"* và *"Giáo dục 45.000/50.000 — Còn 5.000 đ"*; phân bổ ba ví thật; số dư đầu kỳ ra **âm** và đó là số thật (thu tháng 9 nhiều hơn tổng số dư hiện có). 0 pixel vàng ở khổ 411dp trên bốn ảnh chụp.
- **Phân tích: lát 2c‑2 — nút "Tải xuống" sinh tệp PDF/CSV thật** (2026-09-09, **schema không đổi**). Giao diện đã bày hai ô định dạng nên làm **cả hai**; bày một ô rồi không làm là đúng cái kiểu "lời hứa suông" mà 2c‑1 vừa dọn. Thêm hai phụ thuộc: `pdf` dựng tài liệu, `share_plus` đưa tệp ra sheet chia sẻ/lưu của hệ điều hành (**nay chỉ còn là đường lùi** — xem mục ngay dưới). CSV tự viết chuỗi, không cần thư viện. Lý do đầy đủ ở **mục 3.17 và 3.18 `docs/ANALYTICS_FEATURE.md`**. 19 test mới.
  > ⚠️ **Quyết định về NƠI LƯU của mục này đã bị mục ngay dưới thay thế trong cùng ngày** — đọc tiếp trước khi tin. Bản đầu ghi tệp vào thư mục tạm rồi mở sheet chia sẻ, vì ghi vào bộ nhớ chung cần `WRITE_EXTERNAL_STORAGE` (Android ≤ 9) hoặc `MediaStore` qua kênh nền tảng (Android 10+); nay chính `MediaStore` ấy đã được làm, và sheet chia sẻ chỉ còn là đường lùi.
  > ⚠️ **Font PDF phải nhúng.** Font mặc định của gói `pdf` là Helvetica — không có glyph tiếng Việt và **mất dấu im lặng** (tệp vẫn mở được, chỉ là "Ăn uống" thành ô trống). Nay nhúng `Roboto` (Apache 2.0) ở `assets/fonts/`, **thư mục assets đầu tiên của dự án**. Test canh bằng cách cấm chuỗi "Helvetica" xuất hiện trong tệp sinh ra.
  > ⚠️ **CSV cho Excel tiếng Việt có ba luật, cả ba hỏng im lặng:** BOM UTF-8, dòng `sep=;` (Excel dùng dấu phân cách theo locale máy), và số tiền là **số nguyên thô mang dấu** (Excel vi-VN đọc `1.045.000` thành một phẩy không bốn năm). PDF thì ngược lại — là tài liệu để đọc nên có phân cách nghìn và ký hiệu `₫`.
  > Một test **suýt không canh gì cả**: phép kiểm "chi mang dấu âm" tìm `;-50000` trong cả tệp, nhưng con số ấy cũng nằm ở dòng "Tổng chi" và bảng danh mục nên bản sai có chủ ý **đi lọt**. Đã siết lại thành khẳng định trên trọn dòng — bẫy **4.15**.
  > **Đã kiểm trên `emulator-5554`** (ở bản đầu, khi tệp còn đi qua sheet chia sẻ): bấm Tải xuống mở đúng sheet với tên `BaoCao_01-09-2026_30-09-2026.pdf`; kéo tệp về bằng `adb exec-out` (⚠️ `adb shell cat` chèn `
` làm hỏng tệp nhị phân — bẫy 4.16) rồi trích chữ: **2 trang, đủ dấu tiếng Việt và ký hiệu tiền, có cả biểu đồ** (lần kiểm ấy thấy `₫`; từ 2026-09-09 app in `đ`). Tệp CSV cũng đúng: BOM, `sep=;`, CRLF, `Tổng chi;-1045000`.
- **Phân tích: tệp báo cáo lưu THẲNG vào thư mục Tải về** (2026-09-09, **schema không đổi**). Người dùng xem bản 2c‑2 rồi nói *"tôi muốn nó sẽ tải xuống lưu vào máy"* — sheet chia sẻ là một bước thừa. Nay tệp đi qua `MediaStore` và nằm luôn ở `/sdcard/Download`. Kênh `flowmoney/luu_tep` với **mã Kotlin trong `MainActivity`** — đây là **chỗ mã gốc đầu tiên do dự án tự viết** (trước đó mọi thứ gốc đều đến từ plugin). 6 test mới.
  > **Vì sao phải có mã gốc:** đặt một tệp vào bộ nhớ chung mà không xin quyền chỉ làm được qua `MediaStore` (Android 10+). `WRITE_EXTERNAL_STORAGE` đã bị thu hồi tác dụng từ chính bản ấy, còn hộp thoại chọn thư mục (SAF) thì bắt người dùng bấm thêm. `IS_PENDING` bật trong lúc ghi rồi mới tắt, để ứng dụng khác không đọc phải tệp dở; MediaStore tự đổi tên khi trùng (`BaoCao (1).pdf` — đã thấy trên máy ảo).
  > **Android ≤ 9 lùi về sheet chia sẻ** (minSdk của app là 24). Đường lùi ấy **không kiểm được ở đây** vì máy ảo là API 36, nên cố ý giữ nguyên đường cũ đã chạy thật thay vì viết thêm luồng xin quyền chưa ai chạy bao giờ.
  > ⚠️ Hai đường trả về hai thứ khác nhau và giao diện phải nói đúng: `xuat()` trả đường dẫn khi lưu thật, trả `null` khi chỉ mở sheet. Nói "Đã lưu" cho cả hai ca là đẩy người dùng đi tìm một tệp không tồn tại — có test canh.
  > **Đã kiểm trên `emulator-5554`**: sau khi bấm Tải xuống, `ls /sdcard/Download` cho `BaoCao_01-09-2026_30-09-2026.pdf` (24.101 byte) và `.csv` (2.270 byte, còn nguyên BOM); banner hiện *"Đã lưu vào Tải về/BaoCao_01-09-2026_30-09-2026.pdf"*.
- **Mục tiêu: biểu đồ tiến độ theo thời gian** (2026-09-09, **schema không đổi**). Khối "TIẾN ĐỘ THEO THỜI GIAN" trên trang chi tiết: đường **thực tế** (tích luỹ) và đường **kế hoạch** (nét đứt, tuyến tính từ `startDate` tới `targetDate`), cộng một dòng chú thích nói chậm / bám sát / vượt kèm **số tiền**. Lý do từng quyết định ở mục **3.26** `docs/GOAL_FEATURE.md`. Thiết kế sinh vào **chính màn Stitch** *"Chi tiết mục tiêu - FlowMoney"* trước khi dựng Flutter. 32 test mới.
  > **Chỗ neo là quyết định lớn nhất:** chuỗi dựng **đi lùi** từ `currentAmount` chứ không cộng xuôi từ 0, vì lịch sử **không** bảo đảm cộng lại bằng số tiền đang giữ (mục 3.4 — tiến độ cố ý không tự hoà giải). Đo thật: "MuaXe" của tài khoản 10 có **11 khoản, tổng 2.201.000 đ**, trong khi mục tiêu giữ **1.101.000 đ**. Cộng xuôi là điểm cuối biểu đồ cãi nhau với vòng phần trăm ngay phía trên. Điểm gốc âm sinh ra từ phép đi lùi bị **kẹp ở 0** khi đem vẽ.
  > **Một dòng dữ liệu nuôi cả biểu đồ lẫn danh sách:** `StreamBuilder` của `watchGoalTransactions` được dời lên bọc cả hai khối. Dòng thứ hai là chạy cùng câu truy vấn hai lần và mở cửa cho hai bản dữ liệu lệch nhau trên một màn hình.
  > **Đã kiểm trên `emulator-5554`, và máy thật bắt được HAI lỗi bộ test không thấy** — cả hai nay là bẫy **4.17** và **4.18** `ANALYTICS_FEATURE.md`: (1) `fl_chart` mặc định **không cắt** vùng vẽ (`clipData` là `FlClipData.none()`) nên điểm âm kéo đường xanh tràn khỏi thẻ, đè lên trang — không exception, không log, `takeException()` vẫn xanh; (2) fl_chart vẽ nhãn trục ở **cả hai biên** cộng thêm mốc theo `interval`, nên "08/27" in đè "09/27". Kiểm lại sau khi sửa: hai mục tiêu, **0 pixel vàng** (sọc cảnh báo tràn).
- **Mục tiêu: ba con số tổng hợp và chuỗi kỳ liên tiếp** (2026-09-09, **schema không đổi**). Thẻ ba ô ngay dưới biểu đồ: số lần nạp, trung bình mỗi lần, và chuỗi kỳ nạp liên tiếp kèm biểu tượng ngọn lửa. Đếm từ lịch sử đã có — không cột mới, không truy vấn mới. Lý do ở mục **3.27** `docs/GOAL_FEATURE.md`. 20 test mới.
  > **Kỳ cắt bằng `mocThuN` neo vào `startDate`** — chính phép bước kỳ mà bộ trích tự động dùng, cùng khuôn với `advancePeriodFrom` bên ngân sách và `anchorDay` bên hoá đơn. Bản thứ tư của cùng một luật là bản duy nhất không có test năm nhuận. **Kỳ hiện tại chưa nạp không phá chuỗi** (nó đang dở); kỳ rỗng ở giữa thì cắt thật. Khoản rút bị loại khỏi cả ba con số và không phá chuỗi.
  > ⚠️ **Bài học kiểm thử đắt hơn tính năng:** hai test "năm nhuận" và "tháng ngắn" viết lần đầu **không canh gì cả** — thay `mocThuN` bằng phép cộng tháng thô vẫn xanh, vì bộ ngày tôi chọn cho ra cùng một chuỗi ở cả hai cách cắt. Chỉ **bản sai có chủ ý** mới lộ ra. Cùng loại với bẫy 4.15 `ANALYTICS_FEATURE.md`; chi tiết ở cuối mục 3.27 `GOAL_FEATURE.md`.
  > **Đã kiểm trên `emulator-5554`**: "MuaXe" hiện *11 lần nạp · 200.091 đ · 1 tháng liên tiếp* (khớp 2.201.000 / 11 đo được ở bảng lịch sử), "MuaDT" hiện *1 · 700.000 đ · 1*; **0 pixel vàng** ở cả hai màn.
- **Thông báo: Tổng kết tuần** (2026-09-09, **schema không đổi**). Loại thông báo **thứ 16**, nhóm **mới** `summary`, và là loại thứ hai đi qua `ReminderScheduler` (nổ được khi app đã đóng). Bàn giao ở mục **5d** `docs/NOTIFICATION_FEATURE.md`; spec kèm lý do bốn quyết định ở `docs/superpowers/specs/2026-09-07-weekly-summary-notification-design.md`. **39** test mới (đếm bằng máy: 1760 → 1785 ở lát 1-2, → 1799 ở lát 3-4).
  > **Giờ do người dùng chọn**, không phải mốc cố định — người dùng chốt phương án tốn hơn vì lịch đặt trước không đi qua giờ im lặng. Công tắc **mặc định TẮT**, cùng lý lẽ với `nhacGhiChepBat`; chính nó giữ cho 30 test cũ của `ReminderScheduler` không phải sửa kỳ vọng.
  > **Số tuần ISO tự viết** — Dart không có sẵn, và năm ISO khác năm dương lịch ở cả hai chiều (31/12/2025 là 2026-W01, 01/01/2021 là 2020-W53).
  > **Đã kiểm trên `emulator-5554`**: thẻ "TỔNG KẾT TUẦN" mặc định tắt, bật lên hiện đúng hai hàng *Ngày trong tuần: Thứ Hai* và *Giờ nhắc: 08:00*, bộ chọn thứ đủ bảy dòng; **0 pixel vàng**.
- **Soát tài liệu sau ba hạng mục 2026-09-09** — bắt **chín** chỗ lạc hậu (đếm loại thông báo 14/15 → 16, "bốn nhóm" → năm, "tổng ba nguồn" của trần lịch → bốn, số tệp test notification 20 → 22, và bảng ở mục 3 `NOTIFICATION_FEATURE` **thiếu hẳn hàng `weeklySummary`**), một **mâu thuẫn nội bộ** (`PROJECT_CONTEXT` vừa nói Tổng kết tuần đã xong vừa nói nó là việc kế tiếp), và **một khuyết tật thật**: trung tâm thông báo có năm nhóm nhưng dải chip chỉ có bốn. Hai bẫy mới: **7.12** (lưới canh `nhomCua` không canh chip) và **7.13** (thiếu `dongTrang()` là **treo cả tệp test**, không phải một test đỏ).
- **Test: 1876/1876 pass** (~200 giây) — đều đã `git add -f` (đếm lại 2026-09-09 sau loại ví + định dạng tiền; 1843 là mức nền sau Socket.io, 1801 trước đó)

- **Loại ví thu về ba, và một lỗi kẹt hàng đợi im lặng được đóng** (2026-09-09, **schema v20**). Giao diện cũ cho chọn `ewallet` và `debt` — hai giá trị mà `chk_wallet_type` của PostgreSQL **không nhận** — nên ví tạo bằng chúng vỡ CHECK ở mọi lần đẩy và nằm lại trong hàng đợi vĩnh viễn, không một dòng nào báo ra. Nay `lib/features/wallet/domain/wallet_type.dart` là **nguồn duy nhất**, thay cho bốn danh sách không khớp nhau. `banking` đọc được nhưng không tạo được. ⚠️ Hệ quả người dùng thấy: chốt "ví loại NỢ đang âm thì không nhắc" (2026-09-07) mất chỗ bám vì `debt` không còn — ai theo dõi thẻ tín dụng sẽ bị nhắc "ví âm" mỗi ngày; chữa được thì phải thêm khái niệm "ví được phép âm", xem G26.

- **Định dạng tiền gộp về một chỗ** (2026-09-09). `CurrencyFormatter` đã tồn tại từ lâu nhưng **21 tệp vẫn tự dựng `NumberFormat`, sáu kiểu, 45 chỗ** — hậu quả là app hiện **hai ký hiệu tiền** cùng lúc (`đ` ở 18 chỗ, `₫` ở phần còn lại). Nay `lib/` không còn chỗ nào dựng `NumberFormat` ngoài chính tệp ấy, và có test quét cả `lib/` để canh. Quy tắc: chấm ngăn nghìn, phẩy cho thập phân, ký hiệu `đ`; `format()` **làm tròn về đồng chẵn** (bản đầu hiện phần lẻ và bộ test lộ ra ngay: mọi số tính ra đều thành `7.927.272,73 đ`), `formatCoLe()` mới hiện phần lẻ.

- **Sáu lỗi vùng quản lý ví, tìm ra bằng một lượt khảo sát đối chiếu app thị trường** (2026-09-09, **schema không đổi**). Lượt khảo sát đi bốn trục — mô hình dữ liệu, luồng quản lý, số liệu, tính năng sản phẩm — và đối chiếu Money Lover, Sổ Thu Chi MISA, Wallet by BudgetBakers, Spendee. Nó tách được **lỗi đang chạy** khỏi **thiếu tính năng**; đây là phần lỗi, làm trước theo yêu cầu người dùng.
  > 1. **`include_in_total` đẩy lên nhưng không kéo về.** Cờ nằm trong hợp đồng đẩy (12 trường) và `upsertWallet` phía backend ghi nó đầy đủ, nhưng mapper pull không đọc — máy thứ hai giữ mặc định `true` của Drift và **không bao giờ** biết ví nào bị loại khỏi tổng. Phép đọc có chốt khoá-vắng-mặt, mượn nguyên bài học `idgoal`: `doiSangBool(null)` trả `false` nên đọc thẳng sẽ *tắt* cờ chứ không *giữ* nó.
  > 2. **Hai ví cùng làm mặc định, và câu đọc nổ khi gặp trạng thái ấy.** Chỉ đường THÊM giữ bất biến, đường SỬA ghi thẳng; mà `getDefault` dùng `getSingleOrNull()` — ném `StateError` khi có hơn một hàng (`Bad state: Too many elements`, đo được bằng test đỏ). Không unique index nào chặn ở SQLite (⚠️ câu cũ ở đây ghi "cả hai đầu" — sai; server có `uq_wallet_default_active`, đo lại `pg_indexes` 2026-09-10 — xem mục "Hai ràng buộc ví của server" bên dưới). Chốt chuyển xuống `WalletLocalDataSourceImpl` (chỗ **cả hai** đường đi qua) dựa trên `WalletDao.clearDefaultExcept`; vế đọc thêm thứ tự xác định + `limit(1)`, vì hai hàng mặc định **đến được từ server** qua `upsertAll`.
  > 3. **Cờ "Ví mặc định" không có tác dụng nào.** Trang thêm giao dịch lấy `_wallets.first`, mà `getAll` sắp theo `updatedAt` giảm dần → ví chọn sẵn là ví *vừa bị đổi gần nhất*. Ngoài vùng ví, `getDefault` không được gọi ở đâu trong `lib/`. Luật tách ra `transaction/domain/vi_chon_san.dart` (hàm thuần). **Ví đích phải đổi cùng lúc**: luật cũ lấy chỉ số 1 cứng, nên chỉ sửa ví nguồn là khoản chuyển có nguồn trùng đích khi ví mặc định nằm giữa danh sách.
  > 4. **Thứ tự danh sách ví xáo lại mỗi lần ghi chép**, vì mọi giao dịch đều bump `updatedAt` của ví. Nay: ví mặc định trước, rồi `lower(name)` — `lower()` để tên viết hoa không dồn thành khối riêng (phép so nhị phân của SQLite đặt `'Z'` trước `'v'`); nó chỉ chuẩn hoá ASCII nên dấu tiếng Việt vẫn xếp sau, chấp nhận được vì thứ cần sửa là tính **ổn định**. Bảng `wallets` **không có `createdAt`**, nên tên là mốc ổn định duy nhất hiện có. ⚠️ `walletDao.getAll` được gọi từ **14 chỗ**, nên đây là đổi thứ tự **mọi** bộ chọn ví trong app — có chủ ý.
  > 5. **Tổng tài sản sai một nhịp sau khi thêm ví**: `WalletCubit` tự `fold` mọi ví, không lọc `includeInTotal` — một bản thứ hai của luật "tổng tài sản", và bản này thiếu đúng phép lọc (1.050.000đ thay vì 150.000đ khi có ví 900.000đ bị loại). Bỏ hẳn bản thứ hai, hỏi `getTotalBalance`.
  > 6. **Hai điều khiển chết trên màn Quản lý ví.** Nút "SẮP XẾP" có `onTap` thân rỗng; công tắc trên hàng ví **nhận thao tác rồi bỏ đi** (`_walletSwitches` chỉ là `Map` trong `State`). Công tắc còn kéo theo một khuyết tật chưa từng ghi: nó hiện **thay chỗ** `PopupMenuButton` khi `type == 'bank'`, nên ví ngân hàng không có "Chỉnh sửa" lẫn "Xóa ví" nào. Cả hai đều là tính năng **thật** trong thiết kế Stitch — màn "Quản lý ví" có nút sắp xếp, và đoạn JS của nó log `'Wallet activated'`/`'Wallet deactivated'` cho công tắc, tức cột `status`. Gỡ để màn hình không còn hứa suông; chúng quay lại cùng hai tính năng ấy, và khi ấy công tắc nằm **cạnh** menu chứ không thay chỗ.
  > **Bản sai có chủ ý lại lộ ra một test rỗng nghĩa** — lần thứ tư của dự án theo đúng khuôn mục 5.1 bàn giao. Ca "lưu ví không mặc định thì không đụng ví khác" tuyên bố canh câu `WHERE` của `clearDefaultExcept`, nhưng luồng ấy **thoát sớm** ở `_giuMotViMacDinh` nên không bao giờ chạy tới câu `WHERE`; gỡ `isDefault.equals(true)` đi lọt. Đã tách thành hai ca cho hai luật.
  > **20 test mới**, nền `flutter test` **1876 → 1896**, `flutter analyze` giữ nguyên **25 issue / 0 error**. **Đã kiểm trên `emulator-5554`** ở 411dp: nút SẮP XẾP biến mất, cả ba hàng ví đều có menu ba chấm mở đủ "Chỉnh sửa"/"Xóa ví", ví mặc định *Tiết kiệm* lên đầu kèm nhãn MẶC ĐỊNH, trang thêm giao dịch chọn sẵn đúng *Tiết kiệm*, tab Chuyển khoản có ví nguồn **khác** ví đích (*Tiết kiệm* → *test*), **0 pixel vàng** ở mọi màn.
  > ⚠️ **Phần "thiếu tính năng" của lượt khảo sát chưa làm**, xếp theo giá trị: ~~**lưu trữ ví (archive)**~~ — ✅ **làm xong 2026-09-10**, xem mục ngay dưới. ⚠️ Câu *"không cần một dòng backend nào"* viết ở đây đã **bị bác bỏ**: `upsertWallet` xử lý `status` thật, nhưng cột `wallet."Status"` là `varchar(7)` còn `'Inactive'` dài 8 ký tự, nên nó **chặn ở backend** (G28 — CSDL dev đã nới cột tối 2026-09-10, client chưa mở lại); **điều chỉnh số dư** (Money Lover sinh một giao dịch bù và loại nó khỏi thống kê); **sắp xếp ví**; **xem giao dịch của một ví** (`TransactionFilter.walletId` đã có, thiếu đường vào); **hạn mức thấu chi** (bản có nguyên tắc của G27, theo khuôn BudgetBakers); **đa tiền tệ** (`chk_wallet_currency` cho `VND | USD`, entity và repository đã mang `currency`, nhưng `WalletCubit.addWallet` bỏ tham số và không màn nào cho chọn).

- **Lưu trữ ví (archive)** (2026-09-10, **schema không đổi** — cột `status` đã có sẵn trong SQLite từ trước, mặc định `'active'`). Tính năng đầu tiên của đợt "thêm phần mới" sau khi đóng sáu lỗi vùng ví. Lưu trữ là **đóng băng**, không phải xoá: ví lưu trữ biến khỏi mọi bộ chọn ví, thôi cộng vào tổng tài sản, và hai bộ chạy tự động bỏ qua nó — nhưng lịch sử giao dịch cũ không đụng tới, và **mọi con số cũ quay lại nguyên vẹn** khi bỏ lưu trữ, vì phép loại khỏi tổng là *suy ra* chứ không ghi đè `includeInTotal`. Đây là lối thoát cho ba ràng buộc xoá ví (còn số dư / đã có giao dịch / đang gắn mục tiêu) khiến ví dùng thật gần như không bao giờ xoá được.
  > **Hai tệp thuần mới.** `wallet_status.dart` giữ ba phép ánh xạ phải khớp nhau (khoá cục bộ chữ thường, khoá gửi lên chữ hoa, phép đọc ngược), cùng khuôn với `wallet_type.dart`. `vi_tinh_vao_tong.dart` là **định nghĩa duy nhất** của "ví nào được cộng vào tổng tài sản" — luật ấy vốn có **bốn** bản chép tay không khớp nhau, và **ba** trong số đó quên hẳn phép lọc `includeInTotal`: trang chủ và "số dư cuối kỳ" của báo cáo đều cộng `fold` trần trên mọi ví (bản thứ tư, `WalletCubit.addWallet`, đã đóng ở `6fd2ce9`). Cả ba nay đi qua một hàm; đó là lỗi có sẵn, sửa kèm vì nó nằm đúng trên dòng phải đụng.
  > **Hai phép đọc danh sách ví, không còn một.** `getActive`/`watchActive` cho **bộ chọn ví**; `getAll`/`watchAll` giữ nguyên nghĩa cũ cho những chỗ phải thấy ví lưu trữ (màn Quản lý ví, bảng tra tên ví của sổ giao dịch và báo cáo, đường đồng bộ). Chọn nhầm **không gây lỗi nào**: bộ chọn gọi `getAll` thì ví lưu trữ hiện lại như chưa cất đi, còn bảng tra tên gọi `getActive` thì dòng giao dịch cũ hiện "Ví đã xoá". `wallet_picker_sources_test.dart` quét cả `lib/` và bắt mọi chỗ gọi phải được phân loại **tay** kèm lý do — chính nó bắt được ba tệp đổi nhầm ở lượt đầu (`bill_page`, `bill_detail_page`, `budget_local_data_source` dựng `TransactionLookup` chứ không phải bộ chọn).
  > **Hai chốt chặn, khác hẳn ba ràng buộc của xoá:** không lưu trữ ví **mặc định** (nó được chọn sẵn mỗi lần ghi giao dịch), và không lưu trữ **ví hoạt động cuối cùng**. Hai chốt **độc lập** nhau — một tài khoản có thể không có ví nào mang cờ mặc định, vì trạng thái ấy đến được từ server. Cả hai chỉ canh chiều lưu trữ. Ví còn số dư, đã có giao dịch, hay đang gắn mục tiêu thì **vẫn lưu trữ được**; hộp thoại xác nhận nói thẳng rằng trả hoá đơn và nạp mục tiêu tự động sẽ dừng.
  > ⚠️ **`status` là cột CỤC BỘ, không đi theo chiều nào của đồng bộ** — cùng diện với `bills.autoPayEnabled` và `bills.anchorDay`. Lý do là một con số đo thẳng trên PostgreSQL ngày 2026-09-10: cột `wallet."Status"` là **`varchar(7)`** còn giá trị cần gửi là `'Inactive'` — **8 ký tự**. Bản đầu có đẩy lên, và trên máy ảo nó **kẹt hàng đợi đẩy**, thử lại ở mọi chu kỳ. Nhánh **kéo về** phải im lặng cùng lúc: client không đẩy cột này nên server giữ `'Active'` cho mọi ví của tài khoản còn dùng (chỉ ví của tài khoản đã bị xoá hẳn mới bị `scheduler.service.js` đặt `'Inactive'`), nên một bản chỉ gỡ nhánh đẩy sẽ khiến ví vừa lưu trữ tự bỏ lưu trữ sau đúng một chu kỳ. Tài liệu xin backend nới cột: `docs/superpowers/backend/DA-XONG/WALLET_STATUS_COLUMN_WIDTH.md`. Hệ quả trong lúc chờ: lưu trữ chỉ có hiệu lực trên **máy đã bấm**. ✅ CSDL dev **đã nới** lên `varchar(20)` tối 2026-09-10 (áp tệp 7); client chưa mở lại — người dùng chốt để sau.
  > ⚠️ **Lược đồ PostgreSQL tự mâu thuẫn ở đúng cột này.** `chk_wallet_status` cho phép `ARRAY['Active','Inactive']`, nhưng kiểu cột là `varchar(7)` còn `'Inactive'` dài **8 ký tự** — CHECK tuyên bố hợp lệ một giá trị mà cột không chứa nổi, nên trên thực tế cột này là **một hằng số** chứ không phải một trạng thái. **Hai** cột còn lại của bảng có CHECK kèm chuỗi thì không vướng: `Type` là `varchar(7)` và chuỗi dài nhất CHECK cho phép là `'Banking'` — vừa khít; `Currency` là `varchar(3)` với `VND`/`USD`. Vì thế **"lưu trữ ví không cần một dòng backend nào" (bàn giao 2026-09-09) là kết luận sai**: nó đọc `upsertWallet` — đúng, hàm ấy xử lý `status` ở cả hai nhánh — mà không đo độ rộng cột. ⚠️ **Cập nhật cùng ngày, sau khi gộp `main`:** câu "lược đồ tự mâu thuẫn" nay chỉ đúng với **CSDL dev**, không còn đúng với **mã nguồn** backend — `schema.prisma` đã `VarChar(20)` và tệp `database/7_…sql` có sẵn bước nới cột từ 2026-09-09, và **đã áp lên CSDL dev tối 2026-09-10** — nay câu ấy không còn đúng trên máy này. Xem mục "Đo đầu-cuối rủi ro từ đợt gộp `main`" ngay dưới.
  > **Thiết kế Stitch.** Công tắc bật/tắt ví đã nằm trong thiết kế từ đầu ở cả ba màn ví; nhưng **mục "Đã lưu trữ" là khối mới**, nên nó được thiết kế trên Stitch trước — màn `2c950ea26ebf4a4590a26d0742d2a7dd` (*"Quản lý ví - có mục Đã lưu trữ"*), tạo **mới** chứ không sửa màn đã duyệt. Design system của vùng ví là **`Zenith Wallet`** (`assets/75bae118…`), **không** phải `Kinetic Finance` của dự án — khớp bằng chính màu trong HTML của màn ví hiện có. Màn **Thêm ví** cố ý không có công tắc, dù Stitch vẽ: tạo một ví rồi lưu trữ nó ngay trong cùng một biểu mẫu không có nghĩa gì.
  > **52 test mới**, nền `flutter test` **1896 → 1948**, `flutter analyze` giữ nguyên **25 issue / 0 error**, schema Drift **không đổi** (v20). **Đã kiểm trên `emulator-5554`** ở 411dp, đủ vòng: lưu trữ ví *test* (−10.000đ) → tổng nhảy 8.890.081 → **8.900.081**, hiện dòng "Không gồm 1 ví đã lưu trữ" và mục "ĐÃ LƯU TRỮ (1)" → **khởi động lại app** → **một chu kỳ đồng bộ đầy đủ** (đẩy 1/1, "Đã đồng bộ xong") → trạng thái vẫn còn → bỏ lưu trữ đưa ví về đúng chỗ cũ và tổng về đúng số cũ. Chính máy ảo là nơi bắt được lỗi `varchar(7)`; `flutter test` xanh suốt vì hợp đồng đồng bộ được canh bằng adapter giả, không bằng CSDL thật.
  > **Hai lỗi bắt được trong lúc làm:** `_buildSwitchTile` của màn Sửa ví có `Text` trần trong `Row` nên nhãn dài là **tràn bố cục ở 411dp** (bọc `Expanded`; bắt được vì widget test mới dựng ở khổ 411dp thay vì 800×600); và `ctx.pop` trong hộp thoại ném *"No GoRouter found in context"* — hộp thoại nằm ngoài cây route, phải dùng `Navigator.pop`.
  > **Một test rỗng nghĩa, lần thứ năm của dự án.** Ca "ghi entity trở lại không làm mất trạng thái" đi theo chiều `inactive → inactive`, mà `update_` chỉ ghi những cột companion **có mang** nên cột vắng mặt được giữ nguyên — bản thiếu hẳn dòng `status` vẫn xanh. Đã đổi sang chiều `active → inactive`, chiều duy nhất phân biệt được hai cách cài đặt.
  > ⚠️ **Một phép đo sai trong chính phiên này, ghi lại để không lặp.** Lượt đo `pg_constraint` đầu tiên kết luận bảng `wallet` "không có CHECK constraint nào" và bốn `chk_wallet_*` đã bị sửa nhầm ở `CLAUDE.md` lẫn mục này. Câu truy vấn đúng, nhưng tôi lọc output qua `tail -25` nên **bốn dòng CHECK nằm ở đầu danh sách bị cắt mất**. Đo lại đầy đủ: bảng có **18** ràng buộc, đủ cả bốn CHECK — tài liệu cũ vẫn đúng. Bài học: **đừng lọc output của một phép đo qua `head`/`tail` khi chưa biết nó dài bao nhiêu**; lọc bằng `grep` theo dấu hiệu từng dòng, hoặc in ra tệp rồi đọc. Đây là lần thứ hai của dự án bị output cắt làm sai kết luận (lần trước: `grep` qua rtk, bàn giao 2026-09-09 mục 5.5).

- **Điều chỉnh số dư ví (đối soát)** (2026-09-10, **schema không đổi**). Người dùng đếm ví ngoài đời rồi nhập **số dư thực tế**; app sinh một khoản bù để lịch sử giao dịch khớp lại với số ấy, và khoản bù **nằm ngoài thống kê** — nó là phép *sửa sổ*, không phải thu nhập hay chi tiêu. Khuôn của Money Lover.
  > **Lỗ nó bịt là một lỗ đang chảy.** Ô số dư ở màn Sửa ví vốn **ghi thẳng** vào cột `balance` qua `updateWallet`: cộng hết giao dịch của ví ra một số, ví hiện một số khác, và không màn nào nói vì sao. Đó cũng là thứ khiến "số dư cuối kỳ" của báo cáo — vốn **suy ngược** từ số dư hiện tại (mục 3.16 `ANALYTICS_FEATURE.md`) — không đối chiếu được với gì cả. Nay ô ấy là đường **đối soát**, và có một dòng chú thích ngay dưới nói rõ nó sẽ tạo một khoản trong sổ.
  > **Khoản bù là `thu`/`chi`, KHÔNG phải `transfer`** — dù `transfer` vốn đã bị loại khỏi thống kê nên thoạt nhìn tiện hơn. Lý do: `TransactionRepository._applyBalances` **cố ý không động vào ví nào** khi khoản chuyển thiếu ví đích ("đừng trừ một nửa"), nên khoản bù kiểu ấy sẽ không đổi số dư và **xoá cũng không hoàn lại**. Đi qua `addTransaction` với `thu`/`chi` thì cả phép cộng trừ lẫn phép hoàn lại khi xoá đều có sẵn và đúng cả hai chiều — có test canh đúng ca xoá.
  > **Nhận dạng bằng CẶP điều kiện, cả hai đều đồng bộ được.** Chân ghi chú (tiền tố `Điều chỉnh số dư`) **sửa được** — `TRANSACTION_NOTE_ENCODING.md` nói thẳng đánh đổi ấy — nên có chân thứ hai mang tính cấu trúc: khoản bù **không mang danh mục**, thứ giao diện thêm giao dịch không tạo ra được vì nó **bắt buộc chọn danh mục** (`add_transaction_page.dart:496`). ⚠️ Riêng chân danh mục thì **không đủ**: giao dịch kéo về từ server có thể trống danh mục — **17 hàng** như thế đã có trên CSDL, đo 2026-09-10 — nên loại theo mỗi cột ấy là giấu mất chi tiêu thật.
  > **Gom một trùng lặp đã có, không mở rộng phạm vi.** Luật "`transfer` không phải thu/chi" bị chép tay ở **năm** chỗ (bốn trong `bao_cao_xuat.dart`, một trong `thong_ke_thang.dart`). Cả năm nay đi qua `analytics/domain/khoan_vao_thong_ke.dart`, và vế loại khoản điều chỉnh chỉ thêm vào **một** chỗ. Hai kiểu thuần `DongGiaoDich` và `KhoanThuChi` nhận thêm trường `ghiChu` **không bắt buộc** — để `null` là "nơi gọi chưa điền", và khi ấy hàng được **TÍNH**: mặc định an toàn, vì giấu nhầm một khoản chi thật tệ hơn đếm nhầm một khoản bù.
  > **Ba chốt chặn.** Chênh lệch **bằng 0** thì không ghi gì — `chk_transaction_nonzero_amount` của PostgreSQL bắt `Amount <> 0` (đo 2026-09-10), nên một khoản 0đ là bản ghi vỡ ở tầng CSDL rồi kẹt hàng đợi đẩy. Có **ngưỡng nửa đồng**: số dư là `double` nên mọi phép cộng dồn để lại đuôi lẻ, và không có ngưỡng thì một ví "đúng" vẫn đẻ ra khoản bù `0,0000001đ` — thứ CHECK kia cho đi qua vì nó khác 0 thật. Và **ví lưu trữ thì từ chối**: đóng băng nghĩa là không ghi giao dịch mới.
  > **Đồng bộ: không đổi gì.** Payload giao dịch vẫn **12 trường**. Đo thẳng trên PostgreSQL trước khi làm: `Idcategory` **nullable** thật, `Note` là `text` không giới hạn, `chk_transaction_type` nhận `Transaction | Transfer` nên `thu`/`chi` vẫn ánh xạ đúng.

- **Đo đầu-cuối rủi ro từ đợt gộp `main` 2026-09-10** (**không đổi mã client**, schema không đổi). Bàn giao phiên trước để lại ba rủi ro "chưa ai kiểm đầu-cuối"; đo xong thì cả ba đều thật, và thêm một điều không ai ngờ về G28. Hai tài liệu xin backend mới.
  > **Ghi chú bị server viết lại rồi đè lên máy — G29.** `/sync/push` nay chạy mọi `note` qua `filterSensitiveNote()` trước khi mã hoá. Thêm một khoản qua giao diện trên máy ảo với ghi chú `… STK 1903 4567 8901 23 mat khau wifi`: server lưu `… STK [THÔNG TIN THẺ ĐÃ ĐƯỢC LƯỢC BỎ] Mật khẩu: [ĐÃ LƯỢC BỎ]`, và **cùng giây** lượt kéo về đè lên SQLite (`synced`, không lỗi). Mắt xích đè là **chủ ý** của backend (`Client-app.md` 13.9), nên chỗ sửa là **độ chính xác** của hai biểu thức — số thẻ cộng gộp các số rời nhau và không kiểm Luhn; từ khoá mật khẩu không đòi dấu `:` nên nuốt từ đứng sau, kể cả `(tự` của hậu tố `(tự động)`. Phác thảo sửa kèm theo đã chạy đúng 15/15 ca. Chưa hỏng dữ liệu thật (26 ghi chú đang có, chỉ khoản thử bị viết lại). Tài liệu: `DA-XONG/SYNC_NOTE_FILTER_REWRITE.md`. ✅ 2026-09-11: bộ lọc mới của `main` @ `cc65f4f` (kiểm Luhn, từ khoá mật khẩu đòi `:`/`=`) chạy đúng 15/15 ca theo mã — **G29 đóng**; còn khoá mã hoá viết cứng (CAN-LAM 18 §2.6).
  > ~~**CSDL dev chưa áp `database/7`–`11`.**~~ ✅ **Đã áp cả năm tệp tối 2026-09-10** theo yêu cầu đích danh của người dùng: 7–10 bằng `pg`, mỗi tệp một giao tác; 11 bằng `scripts/apply_migration_11.js` với **khoá mặc định** (người dùng chọn — 1 số điện thoại được mã hoá); rồi tắt cả cây `npm run dev`, `prisma generate`, chạy lại. Đo lại đủ mọi dấu hiệu mục 5 của tài liệu; `getAccountValidity(10)` trả hàng thật, không `WARN`; socket trên máy ảo nối lại. Còn lại cho backend: mục 4.2 và 4.3 (⚠️ 2026-09-11: 4.3 xong ở HTTP — lỗi lược đồ ở `authenticate` nay trả 503; 4.2 một phần, tệp `)2` còn xoá cứng — CAN-LAM 18 §2.4). Ảnh chụp trước khi áp: 5 và 6 đã áp; 7–11 không bước nào có mặt. Backend vẫn chạy chỉ vì Prisma Client trong `node_modules` cũng cũ (sinh 2026-09-07) — nên `middleware/auth.js` vỡ ở mọi request vì chọn trường `reason_inactive` và **cho qua** (tài khoản bị khoá vẫn dùng được API), còn đường xoá / huỷ xoá tài khoản client gọi thì hỏng. ⚠️ `prisma generate` trước khi áp 8–9 sẽ tắt đăng nhập — cột `Reason_Inactive`/`Countdown` đo ra `42703`. Tài liệu: `DA-XONG/DEV_DB_MIGRATIONS_7_11.md`.
  > **G28 dời chỗ chặn từ mã sang CSDL.** Tệp 7 (`7523c8c`, 2026-09-09) có sẵn bước nới `wallet."Status"` lên `varchar(20)` và `schema.prisma` đã khai `VarChar(20)` — backend làm xong phần mã **một ngày trước** khi `WALLET_STATUS_COLUMN_WIDTH.md` được viết, chỉ là trên `main` chưa gộp về (đo bằng `git show 53a370f:` và `bef37d3:`). Mục 4b của tài liệu ấy (tạo migration `varchar(16)`) nay đã bị thay, vì nó sẽ đè lên `varchar(20)`. Người dùng vẫn chốt việc phía client **để sau**. ✅ Tệp 7 đã áp lên CSDL dev tối 2026-09-10 — chỗ chặn phía server của G28 đã hết trên máy này.
  > **Ba điểm cùng gốc, không chặn client:** khoá mã hoá đang là chuỗi mặc định viết trong mã (`.env` không có `DATA_ENCRYPTION_KEY`), và `decrypt()` hỏng thì trả nguyên `enc:…`; `dedup.repository.js` so khớp trên ghi chú đã mã hoá; `bank.worker.js` ghi ghi chú dạng rõ. ⚠️ 2026-09-11: hai điểm sau đã sửa, khoá mã hoá viết cứng vẫn còn (CAN-LAM 18 §2.6).
  > **Hai sai lầm trong chính phiên đo, ghi lại để không lặp.** (1) Tạo một tệp script đo **bên trong `src/Backend`** — vi phạm quy tắc 1 dù chỉ để đọc, và nodemon theo dõi mọi `.js` ở đó; xoá ngay, chuyển sang `node -e`. Script đo đặt ở thư mục tạm hoặc chạy nội tuyến. (2) Kết luận vội rằng lỗi `prisma.account` là do **CSDL** thiếu cột, trong khi thông báo `Unknown field … for select statement` là lỗi **kiểm tra của Prisma Client** — truy vấn trần không `select` vẫn chạy. Phân biệt được hai loại là thứ quyết định cảnh báo "đừng `generate` trước".

- **Hai ràng buộc ví của server — client chặn trước** (2026-09-10, **schema không đổi**). Lượt rà soát CSDL sau khi gộp `main` đo `pg_indexes` (không phải `pg_constraint`) và thấy bảng `wallet` có **bốn** partial unique index từ migration 2026-09-01 — trong khi ba tài liệu client (`CLAUDE.md`, mục 14 ở trên, `Rule_project.md` 2.1) và một test ghi *"không unique index nào chặn ở cả hai đầu"*. Sai vì partial index không hiện ở `pg_constraint`. Hai trong bốn index là thứ client đang **vi phạm được**: `uq_wallet_account_name_active` (tên ví duy nhất trong tài khoản — client không kiểm trùng tên) và `uq_wallet_saving_active` (**một ví Tiết kiệm mỗi tài khoản** — client tạo sẵn "Tiết kiệm" cho tài khoản mới rồi vẫn cho chọn lại loại ấy). Vi phạm là 23505 → `UNIQUE_VIOLATION` → ví xếp vĩnh viễn, giao dịch trong ví vỡ FK và thử lại mãi — im lặng, cùng lớp với `ewallet`/`debt`.
  > **Một định nghĩa, ba tầng.** `wallet/domain/rang_buoc_vi.dart` (thuần) giữ cả hai luật, so tên bằng `normalizeCategoryName` — **siết hơn** server (server so chính xác), có chủ ý để dự án chỉ có một phép "hai tên là một". Chốt ở `WalletLocalDataSourceImpl._kiemRangBuocServer`, gọi **trước** khi ghi ở cả `insert` lẫn `update` (cùng chỗ với chốt ví mặc định). Màn Thêm ví khoá ô "Tiết kiệm" kèm một dòng giải thích và báo trùng tên ngay lúc bấm Lưu. Ba điều cả hai luật cùng theo, vì index theo đúng thế: ví đã xoá mềm không giữ chỗ; ví **lưu trữ vẫn giữ** (index không nhìn `Status`); chỉ trong một tài khoản.
  > **Luật "một ví Tiết kiệm" là TẠM.** Nó chỉ có ở SQL (bản 2026-08-26), không có trong `Rule_project.md`, và app thị trường cho nhiều ví tiết kiệm. Người dùng chốt: xin backend bỏ index **và** chặn tạm trong lúc chờ. Tài liệu xin: `DA-XONG/WALLET_SAVING_INDEX.md` (kèm xin mã lỗi `WALLET_NAME_DUPLICATE`/`WALLET_DEFAULT_DUPLICATE`). Khi backend xác nhận, gỡ `viTietKiemDaCo` và hai chỗ gọi; luật trùng tên ở lại. ✅ 2026-09-11: `database/12` đã bỏ index (CSDL dev đã áp) và hai mã `WALLET_*_DUPLICATE` đã có; chốt tạm phía client gỡ cùng ngày (G30 đóng — khối "Gỡ chốt một ví Tiết kiệm" dưới).
  > **Bịt luôn một lỗ có sẵn ở màn Thêm ví:** trang dựng `WalletCubit` **riêng** qua `BlocProvider`, không ai nghe `WalletError` của nó — mọi lỗi datasource khi thêm ví (kể cả ba ràng buộc xoá, nếu có ngày chúng áp cho đường thêm) đều **im lặng**: trang pop, ví không có. Nay trang đọc lại state sau `addWallet`; lỗi thì hiện và ở lại.
  > **Test:** 11 ca thuần (`domain/rang_buoc_vi_test`), 9 ca datasource (`wallet_unique_constraints_test`), 4 widget test ở 411dp qua `GoRouter` thật (`wallet_add_guard_ui_test`). Đã **gỡ chốt rồi chạy lại** để chắc test đỏ: 7 ca đỏ. Lượt đỏ đầu tiên đỏ vì lý do sai — test gõ tên vào `TextField` **đầu tiên**, mà ô đầu là ô số dư — nên phải tìm ô tên theo `hintText`.

- **Rà soát CSDL mới sau khi gộp `main` — bốn tài liệu xin backend** (2026-09-10, **không đổi mã client**, schema không đổi). Đọc toàn bộ `docs/Rule_Project/`, `schema.prisma`, `database/*.sql`, module đồng bộ và xác thực của backend, rồi đo lại trên CSDL dev. Thêm mục **13–16** vào `CAN-LAM/README.md`, nâng tổng lên **mười lăm** (⚠️ 2026-09-11: sau khi gộp `main` @ `cc65f4f` và viết mục 19, `CAN-LAM/` còn **3** tài liệu — mục 17, 18 và 19; bốn tài liệu của khối này đã sang `DA-XONG/`).
  > **Body 401 không mang `code` / `reason_inactive`.** `ResponseHandler.unauthorized` nhận hai tham số, nên đối số thứ ba từ `middleware/auth.js:89` rơi mất — đo bằng cách chạy nó với một `res` giả. JSON mẫu ở `Rule_project.md` 11.3 và `docs/progress/Client-app.md` 10.3/11.3 chưa từng được sinh ra, và handshake socket còn gắn `ACCOUNT_DELETED` cho cả tài khoản bị khoá. Hệ quả: nhánh HTTP của cưỡng chế đăng xuất chưa có gì để đọc; nhánh socket thì client làm được ngay. `DA-XONG/AUTH_401_BODY_CODE.md`. ⚠️ 2026-09-11: body 401 HTTP nay mang `code`, `idaccount`, `reason_inactive`; nhưng bắt tay socket và `/auth/refresh` từ chối mọi tài khoản (CAN-LAM 17 A), và lời từ chối ở socket không mang mã (CAN-LAM 18 §2.1).
  > **`goal.Priority`: `null` thành `0` — tái hiện đầu-cuối.** `mapEntityFields('goal')` gọi `Number(m.priority)`, mà `Number(null) === 0`. Tạo mục tiêu "ThuUuTien" trên `emulator-5554` cạnh hai mục tiêu đã sắp: một giây sau khi lưu nó đứng **cuối**; 16 giây sau, qua một chu kỳ đẩy rồi kéo, nó đứng **đầu** và server mang `Priority = 0`. Client không bao giờ tự sinh giá trị ≤ 0 (`goal_priority.dart:101-104`). Mở **G32**; `DA-XONG/GOAL_PRIORITY_NULL_TO_ZERO.md`. Câu dọn dữ liệu trong tài liệu ấy cố ý **không** đổi `Update_at`: đổi thì sửa đổi ngoại tuyến của người dùng thua luật ghi-sau-thắng và mất. ✅ 2026-09-11: push giữ `null`, nhánh tạo mặc định `null`, tệp 12 đưa hàng `<= 0` trên CSDL dev về `NULL` — **G32 đóng**.
  > **Ánh xạ lỗi `/sync/push`.** Prisma 6.19.3 dịch `22001` thành `P2000` và không nhánh nào bắt, nên tên mục tiêu/hoá đơn dài hơn 100 ký tự hoặc tên danh mục dài hơn 200 thành `DB_ERROR` → client xếp tạm thời → gửi lại mãi. Bốn form ví, mục tiêu, hoá đơn, danh mục **không có `maxLength` nào** (đo trước bản vá — phía client đóng ở khối ngay dưới). Thêm nữa, `sync.validation.js` trả 400 **cả lô** khi một giá trị sai, và client coi 400 cả lô là lỗi đường truyền nên giữ lại **mọi** thao tác. Mở **G31**; `DA-XONG/SYNC_PUSH_ERROR_MAPPING.md`. ✅ 2026-09-11: `22001`/`P2000` và `23502` nay thành `CONSTRAINT_VIOLATION` (client xếp vĩnh viễn), lỗi từng thao tác vào `results[i]` thay vì 400 cả lô — **G31 đóng**.
  > **Tài liệu backend nói ngược mã và CSDL.** Bản đo chiều ghi 31 chỗ chia bốn nhóm; ✅ tối cùng ngày đo lại sau khi áp CSDL và viết lại `RULE_PROJECT_DOC_DRIFT.md` thành hướng dẫn sửa theo dòng — **56 chỗ** ở bốn tệp (25 mục cũ nhóm A/C cộng 13 chỗ mới), ba việc sửa mã (thêm `Provider` `'ORC'`/`'OCR'` tự mâu thuẫn), và danh sách các dòng client từng viết thẳng vào tài liệu backend. Nội dung đo buổi chiều: Đáng chú ý: `New_Database.md` thiếu năm cột client đang đồng bộ và ghi sai unique index của `category`, `wallet`, `transaction`; `Rule_project.md` tự mâu thuẫn hai lần (thứ tự đồng bộ còn nhắc hai bảng nhóm đã DROP; câu "dùng trigger chặn trùng tên với danh mục mặc định" nằm cùng tệp với câu "trigger ấy đã gỡ"); `docs/progress/Backend.md` mục 9 không nhắc mục CAN-LAM nào, và năm script test "100% PASS" ở mục 10 không có trong repo vì `.gitignore` bỏ qua `Test/` có chủ ý. `DA-XONG/RULE_PROJECT_DOC_DRIFT.md`. ⚠️ 2026-09-11: sau `7675b35` mới 11/56 chỗ sửa đúng; `'ORC'` phần lớn đã về `'OCR'`, còn sót ở `sync.repository.js:308` (CAN-LAM 18 §2.8 và §3).
  > **Ba bẫy đo trong phiên, ghi lại để không lặp.** (1) `grep` qua rtk trả **rỗng, không báo lỗi** cho một mẫu có dấu `(` dù tệp có khớp — đo lại bằng script Python ở thư mục tạm. Đây là lần thứ ba của dự án output công cụ làm sai một phép đo. (2) Một lệnh `cd` làm thư mục làm việc của **các lệnh chạy song song sau đó** trôi theo, nên đường dẫn tương đối cho ra "không có kết quả" thay vì báo lỗi — dùng đường dẫn tuyệt đối. (3) Script đếm mục của README đếm ra 16 thay vì 15 vì cụm "không đếm riêng nữa" bị **ngắt dòng** giữa chừng; phải gom khoảng trắng trước khi so chuỗi.

- **Giới hạn độ dài tên ở client — đóng G31 phía client** (2026-09-10, **schema không đổi**). Bảy ô tên — Thêm ví, Sửa ví, Thêm/Sửa mục tiêu, Thêm hoá đơn, Sửa hoá đơn, Thêm/Sửa danh mục, Nhóm danh mục — đi qua bộ lọc mới `GioiHanDoRong` ở `lib/core/utils/gioi_han_do_dai.dart`. `DoRongCot` ở cùng tệp giữ độ rộng cột đo trên PostgreSQL: 100 cho tên ví, mục tiêu, hoá đơn; 200 cho tên danh mục.
  > **Vì sao không dùng `maxLength`.** PostgreSQL đếm `varchar(n)` theo **code point**, còn `maxLength` đếm theo **cụm grapheme** — chữ gõ ở dạng tách dấu (một chữ "ề" là 3 code point) và emoji (emoji gia đình là 5) lọt qua rồi vẫn vỡ `P2000`. `maxLength` còn vẽ bộ đếm "0/100" mà thiết kế Stitch của cả bảy ô đều không có (dò HTML bảy màn). Bộ lọc cắt theo trọn cụm grapheme, và theo đúng chính sách của Flutter về việc cắt lúc bộ gõ đang ghép chữ: Android cắt ngay — nên bấm Lưu khi chữ cuối chưa chốt vẫn không lọt — còn iOS và web chờ ghép xong.
  > **Test:** 12 ca thuần (`core/utils/gioi_han_do_dai_test.dart`) và 7 widget test, mỗi ô một ca: sáu ca gắn vào tệp test sẵn có của từng màn, một tệp mới cho màn Thêm/Sửa mục tiêu (`goal_add_name_limit_test.dart` — màn này trước đó chưa có widget test nào). Lượt đỏ có 15 ca đỏ, đều vì thiếu tính năng. Nền `flutter test` **2000 → 2019**, `flutter analyze` giữ **25 issue / 0 error**.
  > **Kiểm trên `emulator-5554` ở 411dp:** gõ 120 ký tự vào ô tên mục tiêu, ô dừng ở **100**. Cuộn hết form Thêm mục tiêu từ đầu tới nút tạo: **0** pixel vàng trên mọi ảnh chụp.
  > **Hai bẫy khi dựng test màn Thêm mục tiêu, ghi lại để không lặp.** (1) Ảnh đầu trang là `NetworkImage`, mà `flutter test` trả 400 cho mọi request nên ảnh ném `NetworkImageLoadException` và làm đỏ test. Móc có sẵn `debugNetworkImageHttpClientProvider` nhận một `HttpClient` giả trả PNG trong suốt — và phải **đặt lại null ngay trong thân test**, vì bộ test kiểm biến debug của painting trước cả `tearDown`. (2) Ở 411dp bộ test báo tràn 35px và 157px ở hai hàng chữ, trong khi máy ảo cùng bề rộng **không** tràn: font của bộ test rộng hơn ngoài đời (bẫy 4.4 `docs/ANALYTICS_FEATURE.md`). Test ô tên vì thế dựng khổ rộng; đừng đọc hai con số ấy như lỗi bố cục thật.
  > **Fixture Unicode phải viết bằng escape.** Chuỗi tách dấu gõ thẳng vào tệp test không chắc còn ở dạng tách sau khi qua công cụ ghi tệp, nên hai fixture của tệp test thuần được ghi lại bằng escape Unicode của Dart và in code point ra kiểm trước lượt đỏ — đúng bài học ở mục 7 `CATEGORY_RATIONALE.md`.

- **Đọc `priority <= 0` là chưa sắp — đóng G32 phía client** (2026-09-10, **schema không đổi**). Backend ép `null` thành `0` (`Number(null)` ở `mapEntityFields('goal')`; ✅ 2026-09-11: backend đã sửa — giữ `null` — nên phép đọc dưới đây nay là lớp phòng thủ cho dữ liệu cũ và bản client cũ), và lượt tái hiện ở khối "Rà soát CSDL mới" bên trên cho thấy mục tiêu chưa sắp nhảy lên đầu sau 16 giây. Client không bao giờ tự sinh `priority <= 0`, nên đọc mọi giá trị ấy như `null` là không đoán nhầm.
  > **Một định nghĩa, ba ranh giới.** `goal/domain/uu_tien_hop_le.dart` (thuần Dart, không import gì) áp ở `GoalEntity.fromDrift` — mọi đường đọc mục tiêu, nên hàng `0` đã nằm sẵn trong SQLite cũng về đúng chỗ — ở nhánh kéo về của `SyncEngine` (lưu `NULL`), và ở payload đẩy lên (gửi `null`, để hàng tự lành khi backend sửa). **Không** chỉ vá chỗ sắp xếp: `_mocChenDuoc` coi `0` là một số thật, nên kéo một mục tiêu xuống sau hàng mang `0` sẽ tính ra `0 + 100` và nó không về cuối — danh sách và phép kéo thả thấy hai giá trị khác nhau.
  > **Test:** 4 ca thuần (`goal/uu_tien_hop_le_test.dart`), 1 ca repository (hàng mang `0` đọc ra `null` ở cả hai đường đọc), 1 ca payload đẩy trong `sync_payload_contract_test.dart`, và tệp mới `sync_pull_goal_priority_test.dart`. Lượt đỏ có 5 ca đỏ, đều vì `0` chưa được đổi. Nền `flutter test` **2019 → 2026**, `flutter analyze` giữ **25 issue / 0 error**.
  > **Kiểm trên `emulator-5554`:** cài bản vá, mục tiêu thử "ThuUuTien" — kéo về từ trước bản vá và đang đứng đầu — về **cuối** danh sách ngay khi mở trang, không cần đồng bộ lại. Sau đó xoá mềm nó qua giao diện.
  > **Bẫy khi chèn test vào tệp có sẵn:** neo chèn bằng một chuỗi tiếng Việt không khớp dù nhìn giống hệt — dạng Unicode của chữ có dấu trong tệp khác với chuỗi tự gõ. Neo bằng chuỗi ASCII (tên hàm, dấu `}` cuối tệp) thì khớp.

- **Cưỡng chế đăng xuất và tài khoản chờ xoá — spec chờ duyệt; áp CSDL mới** (tối 2026-09-10, **chưa đổi mã client**, schema không đổi; ✅ spec duyệt 2026-09-11 — khối "Duyệt spec cưỡng chế đăng xuất" cuối mục này). Mở hạng mục 5 của lượt rà soát (`docs/progress/Client-app.md` mục 10–12). Spec `docs/superpowers/specs/2026-09-10-cuong-che-dang-xuat-va-cho-xoa-design.md` (`645d1f2`) ghi năm quyết định đã chốt với người dùng — dùng tiếp 30 ngày kèm thẻ nhắc đóng được; bị khoá thì giữ SQLite, bị xoá thì dọn; lý do hiện bằng hộp thoại "Đã hiểu"; một cửa vào `AuthBloc` — cùng ba màn Stitch mới: `657d29a8…` (Trang chủ có thẻ nhắc), `13a6c1f6…` (Cài đặt đang chờ xoá), `97dd48e7…` (hộp thoại bị vô hiệu hoá).
  > **Tìm ra một lỗi đang chạy — G33.** Trang Xoá tài khoản hứa *"đăng nhập lại là tự khôi phục"* theo đặc tả 2026-08-17, trong khi backend chạy theo đặc tả mục 12 (`pendingDeleteCancelled` luôn `false`). Người tin lời hứa sẽ mất tài khoản sau 30 ngày mà không được báo. Hai tài liệu thiết kế cũ ở `docs/superpowers/auth/` đã được gắn dòng "bị thay một phần". ✅ Sửa cùng ngày (2026-09-11) — khối "Sửa G33 — tài khoản chờ xoá dùng tiếp 30 ngày" dưới (G33 đóng).
  > **Áp `database/7`–`11` lên CSDL dev** theo yêu cầu đích danh của người dùng — chi tiết ở khối "Đo đầu-cuối rủi ro từ đợt gộp `main`" bên trên và banner đầu `DA-XONG/DEV_DB_MIGRATIONS_7_11.md`. Sau khi áp, mọi tình huống của spec dựng được trên backend thật, **trừ** body 401 có mã (CAN-LAM 13; ⚠️ 2026-09-11: sau gộp `main` và áp tệp 12, body 401 HTTP đã có mã, nhưng bắt tay socket và `/auth/refresh` từ chối mọi tài khoản — CAN-LAM 17 A, spec §7.3).
  > **Ba bẫy Stitch trong phiên.** (1) `edit_screens` và `generate_screen_from_text` **hết thời gian chờ** ở mô hình mặc định nhưng chạy xong ngay với `modelId: GEMINI_3_8_FLASH`. (2) Màn sinh ra từ hai lệnh ấy **không hiện** trong `list_screens` lẫn `get_project` trong nhiều phút sau (màn `13a6c1f6…` có thật, mở được bằng `get_screen`) — nên không dò được màn do lần hết giờ sinh ra, và canvas có thể có **bản trùng**. (3) Stitch tự áp design system khác ("Kinetic Clarity") cho màn sửa, và dựng hộp thoại ở khung **máy tính** dù yêu cầu mobile — spec ghi rõ lấy màu và cỡ chữ theo Kinetic Finance.

- **Soát `7675b35` trên `main` — CAN-LAM 17** (2026-09-11, **không đổi mã client**, schema không đổi). Đầu phiên, `origin/main` đã có thêm `7675b35 fix backend 3` (NPBao, 23:15 ngày 10/09), gộp **sau** khi nhánh này vào `main` ở PR #71 — một commit tự nhận làm xong mọi tài liệu CAN-LAM, kèm `database/12`. Nó sửa đúng những tệp spec cưỡng chế đăng xuất dựa vào, nên spec được soát lại theo `main` cùng ngày trước khi trình duyệt lại — §3.3 đổi cách interceptor xoá token (server thu hồi refresh token trước khi trả 401 có mã), và thêm §3.6b *không dọn SQLite khi `daXoa` đến từ nhánh làm mới* (đề xuất mới; ✅ duyệt 2026-09-11). Lúc soát, nhánh này **chưa gộp** commit ấy (✅ gộp cùng ngày — khối "Gộp `main` @ `cc65f4f`" ngay dưới); lúc ấy CSDL dev **chưa áp** tệp 12 (đo chỉ đọc: không cột nào của tệp 12, `uq_wallet_saving_active` còn, `chk_bill_pay_status` chưa có `'Skipped'`; ✅ áp cùng ngày — khối "Áp `database/12`" dưới). `CAN-LAM/FIX_BACKEND_3_REGRESSIONS.md`.
  > **Hồi quy A — `accountRejection` không bao giờ trả `null`.** Đo bằng cách lấy hàm ra từ `git show origin/main:…` rồi chạy với `{valid: true, status: 'Active'}`: vẫn trả lý do từ chối "tài khoản đã bị xoá". Bắt tay socket và `/auth/refresh` gọi nó không điều kiện, nên kênh thời gian thực không nối được, người dùng bị đăng xuất khi token 7 ngày hết hạn, admin sau mỗi 15 phút (`axios-client.js` của Admin-web làm mới hỏng là về `/login`). Hàm ấy chép gần nguyên văn đề xuất của **chính client** ở `AUTH_401_BODY_CODE.md` 4.2 — bản đề xuất cũng không trả `null`. Kèm một ca phải đi riêng: lỗi lược đồ (`errorType: 'SCHEMA_ERROR'`) mà lọt vào hàm ấy là thành `ACCOUNT_DELETED`, tức lý do để client **dọn dữ liệu trên máy**.
  > **Hồi quy B — chốt trả hai lần đặt nhầm chỗ.** `upsertBill` từ chối mọi lần đổi `'Payed'` sang trạng thái khác, nên hoàn tác thanh toán (`undoPayment` gửi `'Pending'`) kẹt hàng đợi đẩy, trong khi hai khoản chi của hai máy vẫn lọt. Kèm bẫy thứ tự: trong một lô, `getOperationWeight` xử lý **xoá** giao dịch (60) **sau** **ghi** giao dịch (40), và client đẩy giao dịch đã xoá mềm bằng thao tác `delete` — nên cả chốt đặt đúng chỗ cũng từ chối nhầm ca "hoàn tác rồi trả lại trước khi đồng bộ", nếu không loại trừ giao dịch đang bị xoá trong lô.
  > **C — mã lỗi.** Ba mã mới (`BILL_ALREADY_PAID`, `WALLET_NAME_DUPLICATE`, `WALLET_DEFAULT_DUPLICATE`) lúc soát chưa nằm trong `_permanentCodes`, nên gộp `main` là chúng rơi xuống `transient`; tài liệu backend lại ghi chúng "ánh xạ thành `CONSTRAINT_VIOLATION`". ⚠️ Hai mã `WALLET_*` là **client xin** (`WALLET_SAVING_INDEX.md` 4.2). ✅ Client đã thêm cả ba mã vào `_permanentCodes` cùng ngày — khối ngay dưới.
  > **Bẫy trong phiên: quy lỗi cho đội khác trước khi soát yêu cầu của chính mình.** Lượt báo đầu tiên xếp "lệch mã lỗi" vào lỗi của `7675b35`; chỉ khi đọc lại tài liệu CAN-LAM của client mới thấy cả `BILL_ALREADY_PAID` lẫn hai mã `WALLET_*` đều là tên client đề xuất, và hàm ở hồi quy A là hàm client viết. Trước khi quy một chỗ lệch cho backend, `grep` tên ấy trong `docs/superpowers/backend/` trước.

- **Ba mã lỗi mới của `7675b35` vào `_permanentCodes`** (2026-09-11, **schema không đổi**). `WALLET_NAME_DUPLICATE`, `WALLET_DEFAULT_DUPLICATE` (client tự xin ở `WALLET_SAVING_INDEX.md` 4.2) và `BILL_ALREADY_PAID` đã có trên `main`. Tập mã vĩnh viễn là **danh sách trắng**, nên thiếu chúng thì ngày gộp `main` bản ghi dính các mã ấy bị gửi lại ở mọi chu kỳ, và giãn cách luỹ tiến kéo chậm cả hàng đợi. Nay chúng bị chặn theo thời gian (`sync_engine.dart:1631-1648`). Làm trước khi gộp, vì việc này không phụ thuộc backend.
  > **Không sửa được hoàn tác hoá đơn.** Xếp `BILL_ALREADY_PAID` vĩnh viễn chỉ ngăn việc gửi lại vô ích; chốt ở `upsertBill` của `main` vẫn từ chối hoàn tác (hồi quy B, CAN-LAM 17) — việc ấy của backend.
  > **Test:** 3 ca mới ở `core/sync/sync_failure_handling_test.dart`, cùng khuôn các ca mã sẵn có — `SyncEngine` thật, chỉ giả tầng HTTP, kiểm `syncBlockedUntil`. Lượt đỏ đúng 3 ca đỏ, cả ba `Expected: DateTime:<2026-09-03 08:00:30.000>`, `Actual: <null>`. Nền `flutter test` **2026 → 2029** (155 giây), `flutter analyze` giữ **25 issue** — đọc thẳng log: 20 info, 5 warning, 0 error.
  > **Bẫy đo trong phiên:** dòng `warning` của `flutter analyze` in sát lề, không thụt đầu dòng như `info`, nên đếm theo mẫu `^\s+warning - ` ra **0** dù có 5 — chỉ lộ ra vì tổng theo mức (20) lệch dòng tổng kết (25). Đếm theo mức thì đối chiếu lại với dòng tổng kết.

- **Gộp `main` @ `cc65f4f` về nhánh này** (2026-09-11, theo yêu cầu người dùng; **không đổi mã client**, schema Drift không đổi). Mang về `7675b35` (mã backend, `database/12_Can_Lam_Align_Schema_Fixes.sql`, `scripts/apply_migration_12.js`), `f8ab027` (chuyển 15 tài liệu `CAN-LAM/` → `DA-XONG/`, viết lại đầu `CAN-LAM/README.md` thành "15/15 mục đã hoàn tất", thêm mục 11.36 vào `Project.md`) và `f9d13c9` (chỉ `docs/Rule_Project/Data_Security.md`). Một xung đột, ở `CAN-LAM/README.md`: giữ nguyên văn tiêu đề và khối 🎉 của backend, thay banner cũ bằng banner "đã gộp, client chưa soát từng mục", trỏ 17 liên kết của mục 1–2 sang `../DA-XONG/`. Sửa thêm 7 liên kết hỏng vì chuyển tệp ở `DA-XONG/` và `TRANSACTION_NOTE_ENCODING.md`, và các câu "chưa gộp" ở `CLAUDE.md`, `CLIENT_APP_KNOWN_GAPS.md`, `FIX_BACKEND_3_REGRESSIONS.md`, spec cưỡng chế đăng xuất và khối ngay trên. Sau gộp, `git diff origin/main -- src/Backend` rỗng và `src/Client-app` không đổi so với `9f57342`.
  > **Lúc gộp, máy này chưa theo kịp mã đã gộp:** CSDL dev chưa áp `database/12` và Prisma Client chưa sinh lại, nên chạy backend từ nhánh này là đồng bộ vỡ (mã đọc/ghi `category.Color`, bốn cột mới của `bill`, `transaction.Idbill`) — ✅ cả hai xong cùng ngày, khối kế tiếp. Dù áp xong, bắt tay socket cùng `/auth/refresh` vẫn từ chối mọi tài khoản cho tới khi backend sửa CAN-LAM 17 mục A — nên nhánh socket của spec cưỡng chế đăng xuất **không còn kiểm đầu-cuối được** trên máy này (spec §7.3).
  > **Chưa làm (việc riêng, chờ người dùng):** đối chiếu 15 mục backend tự nhận xong với mã và CSDL; viết lại mục 1–2 của `CAN-LAM/README.md`; và **59** chỗ ở **19** tệp (đếm bằng máy 2026-09-11, trừ tài liệu backend) còn ghi đường dẫn `CAN-LAM/<tệp đã chuyển>` dạng chữ — không phải liên kết nên không hỏng khi bấm, nhưng chỉ sai chỗ. ✅ Cả ba làm cùng ngày: mục 1–2 của `CAN-LAM/README.md` viết lại theo phép đối chiếu (chi tiết ở mục 18 `VERIFY_7675B35_REMAINING.md`), và đường dẫn chữ đã đổi sang `DA-XONG/` trong tài liệu và mã client (còn sót ở `docs/Rule_Project/` — chỉ đọc — và `plans/`, gitignore).

- **Áp `database/12` lên CSDL dev + `prisma generate`** (2026-09-11, **không đổi mã client** — chỉ chú thích, schema Drift không đổi). Người dùng yêu cầu đích danh *"hãy chạy để cập nhật database mới nhất"*. Đọc tệp trước khi chạy: không xoá cứng, chỉ `ADD COLUMN IF NOT EXISTS`, đổi hai CHECK, thêm hai FK và hai index, `DROP INDEX uq_wallet_saving_active`, một `UPDATE goal`. Đích đo trước là `localhost:5432/PersonFinance`. Áp bằng gói `pg` từ `src/Backend`, bọc `BEGIN`/`COMMIT` tường minh: 18 câu, `UPDATE` đổi 1 hàng, `COMMIT`. Backend tắt sẵn, 14 tiến trình `node` đều là MCP server nên `generate` không vướng khoá engine.
  > **Đo trước/sau (chỉ đọc):** đủ bảy cột mới — `category.Color` varchar(9), `transaction.Idbill` varchar(36), `bill.Previous_bill_id`, `Period_end`, `Auto_pay` (NOT NULL DEFAULT false), `Anchor_day`; `fk_transaction_bill` và `fk_bill_previous_bill` là SET NULL; `chk_bill_anchor_day` 1..31; `chk_bill_pay_status` nhận thêm `'Skipped'`; `uq_wallet_saving_active` mất. `goal.Priority`: 1 hàng `<= 0` trước, 0 sau (hàng ấy nay `NULL`). Số hàng bảy bảng không đổi (account 3, wallet 5, category 58, transaction 44, bill 14, goal 3, budget 6). Prisma Client sinh lại đọc được cả bảy cột.
  > **Lệch còn lại** (`prisma migrate diff --from-schema-datasource … --to-schema-datamodel …`, chỉ đọc — trước 11 câu, sau 6): `budget.Threshold_Warning_Percent` **vẫn mặc định `0`** trong CSDL — `Project.md` 11.36 ghi đợt này bỏ mặc định ấy nhưng tệp 12 không có bước nào cho `budget`, nên phía CSDL của việc (D) chưa xong; `idx_bill_previous_bill` / `idx_transaction_bill` tạo dạng partial (`WHERE … IS NOT NULL`) mà Prisma vẫn báo thiếu — vô hại; `account_Email_key`, `user_Email_key`, `idx_transaction_goal` đã lệch từ **trước** tệp 12.
  > **Chưa làm:** chạy lại backend để kiểm đầu-cuối; gỡ chốt tạm "một ví Tiết kiệm" phía client (G30 — ✅ làm cùng ngày). Chú thích ở `rang_buoc_vi.dart`, `wallet_add_page.dart` và `rang_buoc_vi_test.dart` đã sửa theo.

- **Soát toàn bộ tài liệu sau khi gộp `main` và áp `database/12`** (2026-09-11, **không đổi hành vi mã client** — chỉ chú thích và chuỗi `reason:`, schema Drift không đổi). Người dùng yêu cầu *"kiểm tra toàn bộ các tài liệu đã được cập nhật chưa"* rồi *"hãy làm đi"*. Backend tự báo "15/15 mục đã hoàn tất" (`f8ab027`), nên lượt này đối chiếu **từng tài liệu** với mã HEAD `src/Backend` và CSDL dev thay vì tin báo cáo — bốn agent kiểm chứng chỉ đọc (chạy hàm thuần bằng `node -e`, truy vấn chỉ đọc, `prisma migrate diff`), một agent kiểm kê câu mô tả trong tài liệu client, rồi năm agent sửa theo nhóm tệp tách rời, dùng chung một bảng sự thật; phiên chính tự đo lại những kết luận nặng nhất trước khi ghi.
  > **Kết quả phía backend:** sáu tài liệu xong trọn, bảy còn một phần, hai chưa — bảng ở mục 2 `CAN-LAM/README.md`, việc còn lại gom vào tài liệu mới `CAN-LAM/VERIFY_7675B35_REMAINING.md` (**mục 18**; spec cưỡng chế đăng xuất đổi `AUTH_PROFILE_COUNTDOWN.md` thành mục 19). Ngoài ba hồi quy đã biết (mục 17), đo thêm được: bắt tay socket đọc `rejection.code` thay vì `rejection.data.code`; `bank_transaction.incoming` nay **phát hai lần** mỗi giao dịch; giao dịch SePay ghi `type` `'Chi'`/`'Thu'` vỡ `chk_transaction_type` (suy từ mã, có từ trước); khoá mã hoá rơi về chuỗi viết cứng; tệp `database/)2_can_lam_all_migrations.sql` còn `DELETE FROM "category"`; `budget.Threshold_Warning_Percent` vẫn `DEFAULT 0` trên CSDL; và tài liệu backend còn **45/56** chỗ chưa đúng.
  > **Kết quả phía client:** **G29, G31, G32 đóng** (backend sửa trong `7675b35`; lớp phòng thủ phía client — bộ lọc ô nhập, đọc `priority <= 0` — vẫn giữ). **G24 đổi bản chất**: server đã có cột `category.Color` với khoá `color`, nhưng client gửi và đọc `colour` cho danh mục (`categoryForPush` không đổi khoá như `walletForPush`), nên màu danh mục vẫn không đi — nay là lỗi client, sửa được, **chưa sửa, chờ duyệt** (✅ sửa cùng ngày — khối "Sửa khoá màu danh mục" dưới). **G34 mới**: backend đã phát `sync.completed` nhưng `realtime_event.dart` chỉ khai ba sự kiện.
  > **Đã sửa:** `98fb5d8` (tài liệu backend: README, mục 18, banner ở chín tài liệu `DA-XONG/`), `2f81b04` (56 đường dẫn chữ `CAN-LAM/<tệp đã chuyển>` → `DA-XONG/`), và commit này (31 tệp): `CLAUDE.md`, `CLIENT_APP_KNOWN_GAPS.md`, khối này và dòng tóm tắt các G, tài liệu tính năng (mục tiêu, danh mục, hoá đơn), ba spec, ghi chú backend của client, chú thích ở 16 tệp mã và `app_database.g.dart`. Kèm các câu **sai từ trước đợt gộp** tìm ra trong lúc quét: `goalId` bị gọi là cột cục bộ ở bốn chỗ (đồng bộ từ 2026-09-07), Casso là nhà cung cấp hiện hành (SePay), `2026-08-10-backend-sync-spec.md` "CHƯA IMPLEMENT", số test ở mục 3 `CLIENT_APP_KNOWN_GAPS.md` (1529 → 2029).
  > **Bẫy trong phiên — kết luận của agent phải đo lại trước khi ghi.** Agent kiểm lược đồ báo `walletForPush`/`categoryForPush` đều không đổi khoá màu; đọc lại thì `sync_payload_normalizer.dart:82-83` **có** đổi, nhưng chỉ cho ví — kết luận về danh mục vẫn đúng, còn nếu tin nguyên câu thì đã viết sai về ví. Cùng lượt, một grep không trúng dòng nào trên `bank.worker.js` suýt thành kết luận "không phát hai lần"; đọc thẳng tệp mới thấy `:231-243`.
  > **Chưa làm (chờ người dùng):** sửa khoá màu danh mục (G24 — ✅ làm cùng ngày); nghe `sync.completed` (G34); gỡ chốt tạm ví Tiết kiệm (G30 — ✅ làm cùng ngày); mở đồng bộ các cột hoá đơn và `wallet.status` (G28); chạy lại backend để kiểm đầu-cuối. Việc backend nằm ở mục 17 và 18.

- **Kiểm đầu-cuối sau khi gộp `main` và áp `database/12`** (2026-09-11, **không đổi mã**, schema không đổi). Việc 1 trong thứ tự người dùng duyệt. Backend của nhánh chạy nền với log chuyển hướng ra tệp (morgan in từng request), máy ảo `FlowMoney_16G` giữ sẵn phiên tài khoản 10, APK debug build lại lúc 12:40 rồi `adb install -r`.
  > **Chạy đúng:** `GET /api/auth/profile` 200; `GET /api/sync/pull` 200 — kéo về 2 ví, 2 giao dịch, 1 mục tiêu, không lỗi lược đồ nào dù mã backend đọc các cột mới của tệp 12. Đẩy một khoản chi thử 5đ (ví Tiền mặt, ghi chú `E2E 2026-09-11 password manager`): `POST /api/sync/push` 200; hàng server `Amount = -5`, `Type = Transaction`, `Note` lưu dạng `enc:…` và giải mã ra đúng chuỗi gốc — bộ lọc mới giữ nguyên ca "password manager"; số dư ví trừ đúng. Xoá khoản ấy qua giao diện: đẩy 200, `Deleted_at` có giá trị, số dư hoàn đúng 6.799.081. Backend publish `sync.completed` sau mỗi lần đẩy (log `[Notification Module] Received sync.completed`). Số hàng các bảng của tài khoản 10 chỉ thêm đúng một giao dịch đã xoá mềm.
  > **Hỏng đúng như đo trên mã:** bắt tay Socket.io từ chối tài khoản 10 đang `Active` với `Authentication error: Account no longer exists or has been deleted`, `data` không có `code` (CAN-LAM 17 A, 18 §2.1); kênh thử nối lại theo giãn cách 2s → 5s → 15s. G24 thấy tận mắt: SQLite `colour = '#FF5722'`, server `Color = NULL`.
  > **Phát hiện kèm:** (1) bước 1b của `_collectPendingOps` (`sync_engine.dart:1078`) cố ý đẩy kèm danh mục người dùng mà giao dịch chờ trỏ tới, nên mỗi lần đẩy một giao dịch có danh mục thì server trả một xung đột "bản server mới hơn" — vô hại; và bước ấy cũng gửi `colour` (`:1109`), nên sửa G24 phải chạm cả chỗ này. (2) Bộ chọn ví ở màn Thêm giao dịch hiện **khoá thô** `saving`/`cash` dưới tên ví (`add_transaction_page.dart:392` in thẳng `wallet.type`) thay vì nhãn của `WalletType` — lỗi hiển thị nhỏ, **chưa sửa** (✅ sửa cùng ngày — khối "Nhãn loại ví ở bảng chọn ví" dưới). (3) Bàn phím số nằm trong vùng cuộn (`add_transaction_page.dart:679-691`), nên ở 411dp hàng `1 2 3` và `. 0 000 ✓` chỉ hiện sau khi vuốt — chủ ý, không tràn.
  > **Không kiểm:** hoàn tác hoá đơn (vỡ `BILL_ALREADY_PAID` theo 17 B và để máy lệch server), đẩy ngân sách/mục tiêu/hoá đơn, đăng nhập tài khoản khác (sẽ dọn dữ liệu cục bộ của tài khoản 10 trên máy ảo).

- **Sửa khoá màu danh mục — đóng G24** (2026-09-11, **schema không đổi**). Việc 2 trong thứ tự người dùng duyệt. TDD: ba ca đỏ đúng lý do trước khi sửa — normalizer (`color` là `null`), tập khoá danh mục trong contract test (thiếu `'color'`), kéo về (`#ABCDEF` của server bị thay bằng màu dựng sẵn `#FF5722`) — cộng một ca xanh sẵn canh "server chưa có màu thì màu cục bộ còn nguyên". Mã: `categoryForPush` đổi `colour` → `color` (một chỗ phủ cả bước 1b, vì mọi thao tác danh mục đi qua normalizer ở bước POST), nhánh kéo về đọc `c['color']`. `flutter test` 2031/2031, `flutter analyze` 25 issue — khớp mức nền.
  > **Kiểm trên máy ảo:** APK build lại, mở "Ăn uống" ở Quản lý danh mục, lưu lại không đổi gì → `POST /api/sync/push` `1/1`, không xung đột → `category.Color` từ `NULL` thành `#FF5722`, kéo về vẫn `#FF5722`, không bảng nào còn hàng chờ.
  > ⚠️ **Danh mục đã `synced` từ trước chỉ lên màu khi được lưu lại** — đẩy cùng mốc `update_at` thì server trả xung đột và giữ bản của nó, nên bước 1b không tự bổ sung màu. Chưa bổ sung hàng loạt: đổi `updatedAt` của mọi danh mục để đẩy lại là thay đổi dữ liệu, chờ người dùng quyết.
  > **Tìm ra kèm — G35:** đọc `category_add_page.dart` để biết màn sửa có giữ màu cũ không thì thấy getter `_accountId` rơi về `1`; quét `lib/` bằng regex nhiều dòng ra ba chỗ, cả ba ở màn quản lý danh mục. Hai dòng "Không còn `?? 1` ở bất kỳ đâu" ở mục trên và mục 3 của `CLIENT_APP_KNOWN_GAPS.md` sai — đã gắn dấu. ✅ Sửa cùng ngày — khối "Gỡ `?? 1` ở ba màn danh mục" ngay dưới.
  > **Nhận xét giao diện (không sửa):** bảng màu của màn sửa danh mục chỉ có sáu màu, không có màu dựng sẵn của danh mục mặc định (ví dụ `#FF5722`), nên mở sửa thì không chấm nào được đánh dấu; lưu lại vẫn giữ đúng màu cũ.

- **Gỡ `?? 1` ở ba màn danh mục — đóng G35** (2026-09-11, **schema không đổi**). Người dùng chọn sửa G35 trước G30. TDD: `test/core/auth/khong_du_phong_admin_test.dart` quét `lib/` bằng regex nhiều dòng, đỏ đúng ba vị trí (`category_page.dart:42`, `category_group_page.dart:57`, `category_add_page.dart:85`); `category_no_session_test.dart` dựng ba màn dưới `AuthInitial` — đỏ vì màn Danh mục đọc cây của tài khoản 1 và hai màn còn lại ghi `savedChild`/`savedGroup`. `FakeCategoryRepository` thêm `accountIdsDoc` ghi mã tài khoản của mọi lời gọi đọc. Mã: getter thành `widget.accountId ?? currentAccountIdOrNull(context)`; chưa có phiên thì `CategoryPage` không mở luồng đọc và hiện câu báo, hai màn kia dừng lượt nạp, lưu/xoá chặn kèm SnackBar. Đường đọc không dùng `?? 0` như trang ví, vì `idaccount = 0` là bộ khuôn danh mục mặc định toàn cục. `flutter test` 2035/2035, `flutter analyze` 25 issue — khớp mức nền; test nay 192 tệp.
  > **Kiểm trên máy ảo:** có phiên thì màn Quản lý danh mục vẫn hiện đủ nhóm và danh mục. Ca chưa có phiên không dựng được trên máy thật mà không đăng xuất (sẽ dọn dữ liệu cục bộ) — chỉ kiểm bằng widget test.
  > **Bẫy khi kiểm trên máy ảo:** chạm ngay sau `am start` rơi vào lúc app còn nạp — ảnh chụp hiện tổng số dư 0đ và thao tác không tới được màn nào, trông như mất dữ liệu. `logcat` cho thấy app cần ~11 giây từ lúc máy ảo Dart khởi động tới khi có dữ liệu; SQLite vẫn đủ hàng. Chờ dòng `[SQLite DB Log] Wallets count` khác 0 rồi hãy chạm.

- **Gỡ chốt "một ví Tiết kiệm" — đóng G30** (2026-09-11, **schema không đổi**). Việc 3 trong thứ tự người dùng duyệt, làm sau G35. TDD: `wallet_unique_constraints_test.dart` thay nhóm "một ví Tiết kiệm" bằng "nhiều ví Tiết kiệm — G30" — thêm ví saving thứ hai và đổi loại sang saving đỏ đúng lý do (`CacheException` "Mỗi tài khoản chỉ có một ví Tiết kiệm" từ `_kiemRangBuocServer`), cộng một ca xanh sẵn canh luật trùng tên vẫn chặn hai ví saving cùng tên; `wallet_add_guard_ui_test.dart` đỏ vì dòng giải thích còn hiện. Mã: gỡ `viTietKiemDaCo`, `thongBaoMotViTietKiem`, khối chặn ở datasource, khoá ô và dòng giải thích ở màn Thêm ví (bỏ lớp `Opacity`); nhóm test của hàm đã xoá bỏ theo. `flutter test` 2028/2028 (bớt 7 ca), ví 19 tệp / 106 test, `flutter analyze` 25 issue; test nay 192 tệp.
  > **Kiểm trên máy ảo:** tài khoản 10 có ví Tiết kiệm mặc định; màn Thêm ví hiện ô "Tiết kiệm" đậm như các ô khác, chạm vào thì được chọn, không còn dòng giải thích — rời màn không lưu, không tạo dữ liệu thử.
  > ⚠️ **Máy chủ nào chưa áp `database/12` vẫn còn index** — ví Tiết kiệm thứ hai tạo trên app sẽ bị từ chối (`UNIQUE_VIOLATION`, vĩnh viễn) và kẹt hàng đợi đẩy. CSDL dev đã áp; môi trường khác tuỳ backend.
  > **Hai bẫy khi kiểm trên máy ảo:** (1) sau `adb install -r` rồi `am start`, launcher có thể nằm trên app — tiến trình app vẫn sống, bộ đệm crash trống — nên cú chạm rơi vào launcher; `dumpsys activity activities` (`topResumedActivity`) cho biết ai đang ở trên, `am start` lần nữa là xong. (2) Tiến trình `adb logcat` chạy nền ngừng ghi vào tệp sau khi cài lại APK; đọc log bằng `adb logcat -d` thay vì tin tệp ấy.

- **Duyệt spec cưỡng chế đăng xuất và tài khoản chờ xoá** (2026-09-11, **không đổi mã**, schema không đổi). Người dùng duyệt bốn điểm còn treo của `docs/superpowers/specs/2026-09-10-cuong-che-dang-xuat-va-cho-xoa-design.md`: **§3.3** (401 có mã, kể cả 401 của `/auth/refresh`, thì interceptor tự xoá token và không phát `sessionExpiredStream`); **§3.6b** (`daXoa` đến từ nhánh làm mới vẫn đăng xuất nhưng **không** dọn SQLite — `ThongBaoBuocDangXuat` thêm trường `nguon`); **ba màn Stitch** ở §5, dựng theo chữ và màu ghi trong spec; và đưa **hai lỗi làm mới token có sẵn** (mất mạng hoặc 5xx lúc làm mới cũng đăng xuất; hai 401 cùng lúc làm mới hai lần và vấp *Token Reuse Detection*) từ "Ngoài phạm vi" vào phạm vi — nay **§3.8** (✅ sửa cùng ngày — khối "Sửa hai lỗi làm mới token — spec §3.8" dưới), làm trước Phần 1 vì cùng `auth_interceptor.dart`. Tài khoản thử: **tài khoản 11**, người dùng cho dùng — thông tin đăng nhập **không** ghi vào repo; kiểm trên Chrome để không dọn dữ liệu tài khoản 10 trên máy ảo (⚠️ chiều cùng ngày máy ảo đã ở phiên tài khoản 11 — khối "Nhãn loại ví ở bảng chọn ví" ngay dưới).
  > **Đối chiếu trước khi trình (chỉ đọc):** `auth_interceptor.dart` vẫn kế thừa `Interceptor`, gặp 401 nào cũng làm mới và `_tryRefreshToken` nuốt mọi lỗi thành `null` (`:88-119`) (✅ 2026-09-11: `_lamMoi()` thay `_tryRefreshToken`, chỉ 400/401 là phiên chết — vẫn kế thừa `Interceptor`, có chủ ý); `auth.service.js` thu hồi refresh token trước khi ném 401 có mã (`:411`) và gặp token đã thu hồi thì thu hồi mọi token của tài khoản (`:380-389`); `auth.controller.js:77` đưa lỗi không mang `statusCode` về 500; `accountRejection` (`middleware/auth.js:60-74`) không bao giờ trả `null`, và đường làm mới không tách lỗi lược đồ như `authenticate` (`:105-108`). Spec còn khớp mã. Ba màn Stitch (`get_screen`) khớp §5; màn Trang chủ có thêm biểu tượng đồng hồ cạnh tiêu đề thẻ — ghi bổ sung vào §5.2.
  > **Sửa kèm trong spec:** §7.3 ghi tài khoản 10 "không có mật khẩu" — sai: đo bảng `account` (chỉ đọc) thì cả ba tài khoản (1 admin, 10, 11) đều `Active` và có mật khẩu. §8 bỏ hai mục vừa đưa vào phạm vi; §3.5 bước 3 và §7.2 bỏ chữ "nếu được duyệt"; §7.2 thêm các ca của §3.8.
  > **Chưa làm:** CAN-LAM **19** (`AUTH_PROFILE_COUNTDOWN.md`, nội dung ở §6 spec) viết khi bắt đầu G33 (✅ viết cùng ngày); kế hoạch thực thi đặt ở `docs/superpowers/plans/` (gitignore).

- **Nhãn loại ví ở bảng chọn ví màn Thêm giao dịch** (2026-09-11, **schema không đổi**). Lỗi hiển thị tìm ra ở lượt kiểm đầu-cuối cùng ngày: dòng dưới tên ví trong bảng "Chọn ví thanh toán" / "Chọn ví đích" in thẳng `wallet.type`, nên hiện khoá lưu `saving`/`cash`. Nay đi qua `WalletType.tuKhoa(wallet.type).nhan` (`add_transaction_page.dart`) — nhãn loại ví có một nguồn duy nhất ở `wallet/domain/wallet_type.dart`. Quét `presentation/` của `lib/`: không còn chỗ nào khác in `wallet.type` ra màn hình.
  > **TDD:** ca mới ở `test/features/transaction/presentation/add_transaction_page_test.dart` mở bảng chọn với ba ví `cash`/`bank`/`saving` — đỏ đúng lý do (tìm thấy chữ "cash"); chữ cần so lấy từ `WalletType.nhan` chứ không gõ tay, và neo bằng biểu tượng của hàng ví chứ không bằng chữ tiếng Việt. `flutter test` **2029/2029** (5 phút 24 giây, chạy song song với build APK), `flutter analyze` **25 issue** = 20 info + 5 warning + 0 error — khớp mức nền, không issue nào ở hai tệp vừa sửa. Test: 192 tệp `_test.dart` (193 tệp `.dart` kể cả `category_test_fakes.dart`) / 44.041 dòng.
  > **Kiểm trên `emulator-5554`:** bảng "Chọn ví thanh toán" hiện "Tiết kiệm" và "Tiền mặt" dưới tên ví, không sọc tràn; đóng bảng và rời màn không lưu. ⚠️ Máy ảo nay ở phiên **tài khoản 11** (log `[SyncEngine] Starting full sync (Push & Pull) for account 11`; Claude không đăng nhập), không còn tài khoản 10 như các khối trước ghi. Hai ví của tài khoản ấy đặt tên trùng nhãn loại, nên mỗi hàng hiện hai dòng giống nhau ("Tiết kiệm" / "Tiết kiệm") — bảng chọn ví chưa có thiết kế Stitch, **không sửa**.

- **Phần 1 cưỡng chế đăng xuất — §3.1–§3.7 và §5.1** (2026-09-12, **schema không đổi**). Bảy commit `693de3b` → `fc82a94` trên `TranQuangDat`, một task một commit, mỗi task viết test đỏ trước. Khi server nói "tài khoản này không dùng được nữa", app nay đăng xuất **có lý do** thay vì im lặng. Kiểu chung `ThongBaoBuocDangXuat` ở **`lib/core/auth/buoc_dang_xuat.dart`** (Dart thuần) gom **ba** nguồn — sự kiện socket `account.force_logout`, body 401 của một request thường, body 401 của `/auth/refresh` — về **một** event `TaiKhoanBiBuocDangXuat` của `AuthBloc` (Hướng A, spec mục 2 Q5). Bloc dừng ba thành phần của phiên qua `_dungMoiThuCuaPhien()` (chuỗi này đang được **chép ở hai handler**, đây là lần thứ ba nên gom về một chỗ), dọn SQLite **có điều kiện**, gọi `AuthRepository.xoaPhienTrenMay()` — đường mới, **không** gọi `/auth/logout` vì route ấy đi qua `authenticate` và sẽ 401 quay vòng — rồi phát `AuthUnauthenticated(thongBao: …)`. Màn Đăng nhập dựng hộp thoại theo màn Stitch `97dd48e7…`: vòng tròn 56px nền `#FFDAD6`, `block` / `delete_forever`, tiêu đề theo lý do, một nút **Đã hiểu**, bấm ra ngoài không đóng được.
  > **Năm chốt, tất cả đều hỏng IM LẶNG nếu phá.** (1) **Mọi giá trị lạ, thiếu, sai kiểu đều đọc thành `biKhoa`** — đọc nhầm "đã xoá" thành "bị khoá" chỉ giữ lại dữ liệu, đọc nhầm chiều ngược lại là **xoá mất** dữ liệu người dùng. (2) **Chỉ đọc `code` khi `statusCode == 401`** — `/auth/refresh` còn trả **400**, và body 400 của repo cũng mang `code` ở cấp gốc (`VALIDATION_ERROR`), nên đọc nó là hiện hộp thoại "Tài khoản đã bị vô hiệu hoá" cho một lỗi nhập liệu; 401 "Token expired" thật thì **không** có `code` (đo lại `middleware/auth.js:60-111` ngày 2026-09-12) nên vẫn đi đường làm mới token như cũ. (3) **Dọn SQLite chỉ khi `daXoa` VÀ nguồn khác `lamMoi`** (§3.6b): ở nhánh làm mới, lỗi lược đồ phía server còn đội lốt được `ACCOUNT_DELETED` (CAN-LAM 17 §2.5) — bỏ ngoại lệ khi backend sửa xong. (4) **Chặn thông báo thứ hai bằng CỜ chứ không bằng `state`** — state chỉ đổi ở bước cuối mà handler của Bloc chạy đồng thời, nên lần nhận thứ hai vẫn thấy `AuthSuccess`; cờ được **thả** ở `_onLoginSubmitted`, thiếu chỗ ấy thì lần bị đẩy ra thứ hai trong cùng một lần chạy app im lặng. (5) **Xoá token KHÔNG phát `sessionExpiredStream`** khi 401 mang mã — server thu hồi refresh token trước khi trả mã, và một lượt đăng xuất trơn chạy đua với hộp thoại thì người dùng chỉ thấy màn Đăng nhập trống.
  > **Hai thứ tìm ra khi làm, không có trong spec.** (a) **`BlocListener` ở màn Đăng nhập là không đủ**: `AppRouter` refresh theo `authBloc.stream` (`app_router.dart:89`), nên thứ tự thật là *emit → router chuyển về `/login` → trang mới được dựng* — lần đổi state mang `thongBao` đã trôi qua trước khi listener kịp đăng ký. Trang phải đọc **thêm** state sẵn có ở `initState` (sau khung hình đầu tiên), cộng một cờ chặn hiện hai lần. (b) **Hộp thoại tràn 158px ở 411dp** khi `loiNhan` dài — câu ấy do admin gõ (`admin.service.js:140` nối thẳng `reason_inactive` vào), client không kiểm được độ dài; tràn thì nút "Đã hiểu" ra ngoài màn hình mà `barrierDismissible` lại `false`, tức **không đóng nổi**. Phần thân nay cuộn được, nút nằm ngoài vùng cuộn. Bắt được nhờ ca test dựng trong `SizedBox(width: 411)` + `tester.takeException()`.
  > **Lệch spec một chỗ, người dùng duyệt trước khi làm:** `tuSuKienSocket` trả kiểu **không** nullable (§3.1 ghi nullable). Sự kiện ấy tự nó đã là lời đẩy người dùng ra; trả `null` cho payload dị dạng là bỏ qua nó và để người dùng ngồi lại trong app. `tuBody401` **giữ** nullable — ở đó `null` có nghĩa thật.
  > **Test:** **63** ca mới (đếm bằng máy 2026-09-12) — `buoc_dang_xuat_test` 19, `realtime_buoc_dang_xuat_test` 7, `auth_interceptor_buoc_dang_xuat_test` 9, `purge_data_for_account_test` 4, `xoa_phien_tren_may_test` 3, `auth_bloc_buoc_dang_xuat_test` 10, `hop_thoai_bi_day_ra_test` 11. `flutter test` **2168/2168** (1 phút 36 giây), `flutter analyze` **25** issue — mức nền, 0 error.
  > ⚠️ **Còn nợ: lượt kiểm trên máy ảo.** Nhánh **socket** và nhánh **làm mới** không dựng được đầu-cuối trên backend đã gộp — bắt tay và `/auth/refresh` từ chối **mọi** tài khoản (CAN-LAM 17 A). Ca *đã xoá* thì admin xoá mềm không hoàn tác được bằng giao diện. Chỉ **nhánh HTTP 401** (khoá tài khoản qua Admin-web) là kiểm được ngay. Chi tiết ở §7.3 của spec.

- **Sửa G33 — tài khoản chờ xoá dùng tiếp 30 ngày** (2026-09-11, **schema không đổi**). Theo mục 4–5 (Phần 2–3, trừ §5.1) của `docs/superpowers/specs/2026-09-10-cuong-che-dang-xuat-va-cho-xoa-design.md`: `UserModel` mang `status`/`countdown`/`countdownNhanLuc`/`dangChoXoa`, gỡ `pendingDeleteCancelled` (`48b01c5`); repository ghi `PendingDelete` mà **không** xoá token (`d1791dd`); `AuthBloc` đọc lại thông tin tài khoản qua sự kiện mới `ThongTinTaiKhoanThayDoi` (`361f898` + `eee607e`); thẻ nhắc ở Trang chủ — nút "Để sau"/"Huỷ xoá" (`292af8d`); thẻ "Vùng nguy hiểm" ở Cài đặt — hộp đếm N ngày, nút "Huỷ yêu cầu xoá" (`f7a02aa` + `ff54c6b`); trang Xoá tài khoản thôi đăng xuất, thôi hứa "đăng nhập lại là tự khôi phục" (`866b870`); hàm đếm ngày thuần ở `ca44dd8`. Việc cho backend — `GET /auth/profile` trả thêm `countdown`, gỡ `pendingDeleteCancelled` khỏi response đăng nhập — đã viết thành CAN-LAM **19** (khối "Duyệt spec cưỡng chế đăng xuất..." trên). **§3.8** ✅ sửa cùng ngày (khối "Sửa hai lỗi làm mới token — spec §3.8" dưới); **Phần 1** (§3.1–§3.7) và **§5.1** ✅ làm 2026-09-12 (khối "Phần 1 cưỡng chế đăng xuất" dưới).
  > **TDD:** cả bảy việc viết test trước; phần lớn đỏ đúng lý do ngay (thiếu tệp, hàm hay tham số — như `now` của `AuthRepositoryImpl` — hoặc câu chữ cũ "đăng nhập lại là khôi phục" / nút huỷ cũ còn hiện trên màn). Một việc gặp một lượt đỏ **sai** lý do trước khi tới lượt đỏ đúng: trang Xoá tài khoản (`GetIt` chưa nối `authRepository` truyền từ test) — lỗi hạ tầng test, phải nối xong rồi mới đỏ đúng vì thiếu hành vi.
  > **Test và `analyze`:** `flutter test` toàn bộ **2078/2078 pass** (3 phút 23 giây, đo ở `0591887` sau lượt sửa sau soát cuối cả nhánh; mức nền trước G33: 2029/2029) — 49 test mới ở 7 tệp, đếm bằng máy (`dem_nguoc_xoa_test` 13, `user_model_cho_xoa_test` 5, `auth_repository_cho_xoa_test` 11, `auth_bloc_cho_xoa_test` 5, `the_cho_xoa_trang_chu_test` 6, `vung_nguy_hiem_card_test` 5, `delete_account_page_test` 4). `flutter analyze` **25 issue = 20 info + 5 warning + 0 error** — khớp mức nền, cùng năm tệp như trước, không issue nào ở tệp G33. Tệp test nay **199** `_test.dart` (**200** `.dart` kể cả `category_test_fakes.dart`) / **45.147** dòng (đếm bằng máy 2026-09-11) — trước G33: 192 / 193 / 44.041; trước lượt sửa sau soát cuối: 2073/2073 · 44.905 dòng.
  > **Kiểm trên `emulator-5554` (tài khoản 11, APK từ `866b870`):** CSDL trước `Status = Active`, `Countdown = null`, `Delete_at = null`. Trang Xoá tài khoản hiện banner và dòng thời gian mới (biểu tượng đồng hồ cát), không còn nút huỷ cuối trang, hộp thoại xác nhận không còn câu "đăng nhập lại". Gửi yêu cầu → hộp thoại "Yêu cầu đã được ghi nhận / Bạn vẫn dùng app bình thường trong 30 ngày…" → **Đã hiểu** → về Trang chủ, **không** bị đăng xuất; thẻ "Tài khoản đang chờ xoá — Còn 30 ngày…" hiện ra. CSDL sau: `PendingDelete`, `Countdown = 30`, `Delete_at = 2026-10-11T11:05:01Z`. "Để sau" ẩn thẻ; force-stop rồi mở lại app thì thẻ hiện lại (cờ chỉ ở bộ nhớ, đúng thiết kế). Cài đặt khi chờ xoá: hộp đếm "30 ngày còn lại", dòng "…xoá vĩnh viễn vào 11/10/2026." khớp `Delete_at`, nút "Huỷ yêu cầu xoá". Huỷ → Cài đặt về `Active`, không SnackBar; CSDL sau huỷ: `Active`, `Countdown = null`, `Delete_at = null` — tài khoản thử về nguyên trạng. Trang chủ sau huỷ: không thẻ, không khoảng trống. Pixel vàng (sọc tràn bố cục): **0** trên **15** ảnh chụp.
  > **Hai lỗi bắt được ở lượt soát, không phải ở bộ test ban đầu.** (1) `flutter_bloc` 8 xử lý sự kiện song song: handler `ThongTinTaiKhoanThayDoi` chờ `getCurrentUser()` xong mới phát, nên nếu `LogoutRequested` chạy xen giữa thì nó phát lại `AuthSuccess` cũ **sau khi đã đăng xuất** — sửa bằng kiểm lại `state is! AuthSuccess` **sau** `await` (`eee607e`, test hồi quy dùng `Completer` + `LogoutRequested`). (2) Trang Xoá tài khoản không đặt lại `_isLoading = false` khi `deleteAccount` thành công — trước G33 không lộ vì trang đăng xuất ngay, nay trang ở lại và mở hộp thoại modal nên `pumpAndSettle` treo ở test; sửa trong `866b870`. Thêm: 2/4 widget test thẻ Vùng nguy hiểm thiếu `tester.takeException()`, bắt được ở lượt soát, sửa ở `ff54c6b`.
  > **Lượt sửa sau soát cuối cả nhánh** (2026-09-11; người soát cuối xếp *With fixes* — 0 Critical, 3 Important — cộng ba Minor controller chọn sửa). (1) Trang Xoá tài khoản và `huyYeuCauXoa` lấy `AuthBloc` trước `await` và phát `ThongTinTaiKhoanThayDoi` ngay khi repository trả về, kể cả khi trang/thẻ đã rời cây giữa lúc gửi/huỷ — trước đó bấm quay lại lúc đang gửi là server và bộ nhớ đệm đã `PendingDelete` mà `AuthSuccess` vẫn `Active` (`5436544`). (2) Khoảng 24dp phía trên thẻ Trang chủ chuyển vào trong `TheChoXoaTrangChu`: bấm "Để sau" không còn để lại khoảng trống (`bf34de2`). (3) Test trang Xoá tài khoản dựng bằng `AppTheme.lightTheme` ở 411dp, cuộn tới nút trước khi bấm, `takeException()` ở mọi ca; kiểm đột biến (tạm bọc nút hộp thoại trong `Row`) đỏ với "BoxConstraints forces an infinite width", trang không phải sửa (`2df748c`). (4) `deleteAccount`/`cancelDelete` giữ người dùng trước request và chỉ ghi bộ nhớ đệm khi vẫn là đúng tài khoản ấy; huỷ hỏng mà phiên đã đổi thì ném lỗi, không hỏi lại server cho phiên mới (`46ad023`). (5) Thẻ Trang chủ khớp HTML màn Stitch `657d29a8` — viền `error` 20%, bóng nhẹ, đồng hồ màu `error` trong vòng tròn trắng mờ, chữ 13/14px (`0591887`); chữ "Để sau" dùng token Stitch `#454743` (tương phản 7,27:1 trên `#FFDAD6`) thay bí danh `AppColors.onSurfaceVariant` `#767872` (3,46:1, dưới ngưỡng WCAG AA 4,5:1) (`260abc6`). (6) Tài liệu: ca thẻ không có số ngày mô tả đúng — đăng nhập máy khác hay cài lại app thì **có** số; mục 6 phía backend mới viết tài liệu xin, backend chưa làm (`8a1af21`).
  > **Kiểm trên `emulator-5554` sau lượt sửa (tài khoản 11, APK từ `0591887`):** Trang chủ lúc `Active` không có thẻ, tiêu đề hero ở y=315 px. Gửi yêu cầu → hộp thoại "Yêu cầu đã được ghi nhận" **vẫn mở** thêm 3 giây dù `AuthSuccess` đã phát lại → "Đã hiểu" → Trang chủ; CSDL `PendingDelete`, `Countdown = 30`, `Delete_at = 2026-10-11T13:50:18Z`. Thẻ khớp Stitch bằng mắt (viền đỏ nhạt, bóng, đồng hồ trong vòng tròn trắng, "30 ngày" đậm, "Huỷ xoá" nền đen canh phải); bấm "Để sau" → hero về đúng y=315, không còn khoảng trống. Hai nút hộp thoại xác nhận xếp dọc rộng hết hộp, không tràn. Cài đặt khi chờ xoá: "30 ngày còn lại", "…xoá vĩnh viễn vào 11/10/2026." khớp `Delete_at`. Huỷ → Cài đặt về `Active`, không SnackBar lỗi; CSDL `Active`, `Countdown = null`, `Delete_at = null` — tài khoản thử về nguyên trạng; Trang chủ không thẻ, hero y=315. Pixel vàng: **0** trên **13** ảnh chụp. Không dựng được trên máy: rời trang giữa lúc yêu cầu còn treo, và đổi tài khoản giữa lúc treo — request xong quá nhanh; hai đường ấy chỉ có test canh. Màu "Để sau" `#454743` (`260abc6`) đổi sau lượt máy ảo này, chưa nhìn lại trên máy.

- **Sửa hai lỗi làm mới token — spec §3.8** (2026-09-11, **schema không đổi**). Ba việc trên `AuthInterceptor`, năm commit: (1) kiểu `KetQuaLamMoi` phân loại kết quả `/auth/refresh` thành `LamMoiThanhCong`/`LamMoiPhienChet`/`LamMoiTamThoi` — chỉ 400/401 do server **trả lời** mới là phiên chết (`952058c`); (2) §3.8 điểm 1 — làm mới hỏng tạm thời (mất mạng, hết giờ, 5xx) giữ hai token và trả lỗi của chính lượt làm mới cho nơi gọi thay vì 401 gốc, sửa kèm **lỗi thứ ba** tìm được khi đọc mã: thử lại request gốc hỏng sau khi làm mới **đã thành công** trước đây vẫn xoá cả hai token, nay giữ (`4903c97`); (3) §3.8 điểm 2 — nhiều 401 cùng lúc chờ chung một future (`_lamMoiChung`/`_lamMoiDangChay`) nên `/auth/refresh` chỉ gọi đúng một lần, cộng chốt "token cũ" (401 mang `Authorization` khác token đang có trong kho thì chỉ thử lại, không làm mới lần nữa) (`1edeb49`). Hai vòng sửa sau soát: `3e84d49` thêm ca test còn thiếu cho nhánh `/auth/refresh` trả 200 nhưng không có `accessToken` (một trong bảy nhánh Global Constraints nêu tên, lọt qua ở bản đầu); `7cbd849` bọc toàn thân `_lamMoi()` và lượt đọc kho của chốt "token cũ" bằng `try/catch` thay vì để lỗi thoát ra ngoài — **chốt phòng thủ, không phải một lỗi đã có** (xem quyết định cuối dưới). ⚠️ Hai khối `catch` ấy **không** làm cùng một việc: chỉ `_lamMoi()` trả `LamMoiTamThoi` (giữ token, không tín hiệu); khối của chốt "token cũ" chỉ gán `tokenHienCo = null` — coi như *không có token cũ để so* — rồi **đi tiếp** `_lamMoiChung()`, nên kết quả cuối tuỳ lượt làm mới và hoàn toàn có thể là `LamMoiThanhCong` (câu ở đây trước 2026-09-12 gộp hai khối làm một, sai).
  > **TDD:** Task 1 đỏ vì thiếu file `ket_qua_lam_moi.dart` (lỗi biên dịch). Task 2 đỏ hai vòng — trước hết biên dịch (thiếu tham số `dioLamMoi` để tiêm Dio giả), rồi hành vi: 5/8 ca mới đỏ đúng lý do (lỗi kết nối/hết giờ/503/thử lại hỏng nhận 401 thay vì lỗi thật, vì `onError` cũ chưa phân biệt) sau khi mới thêm tham số mà chưa sửa `onError`. Task 3 đỏ đúng ba ca mới ("hai request cùng nhận 401", "lượt chung trả 401", "401 tới sau khi lượt đã xong") vì `refreshCalls` đo được **2** thay vì **1** — hai `onError` song song mỗi cái tự gọi `/auth/refresh`. Vòng sửa sau soát Task 2 (ca "200 không có `accessToken`") pass **ngay** với mã cũ — chốt canh, không phải TDD-đỏ — nên còn chứng minh bắt được hồi quy bằng cách tạm sửa `_lamMoi()` về hành vi cũ rồi xem ca đỏ đúng lý do. Vòng sửa sau soát Task 3 (ca "kho token ném lỗi") cũng pass **ngay cả khi chưa sửa** — phát hiện quan trọng: `dio 5.11.0` tự bắt lỗi thoát khỏi `onError` async và trả `DioException(type: unknown)` riêng cho từng request (`assureDioException`, `dio_mixin.dart`), nên "treo N request" không tái hiện được trên phiên bản này; vẫn triển khai đúng phán quyết vì mã sau khi sửa không còn phụ thuộc chi tiết cài đặt nội bộ ấy.
  > **Test và `analyze`:** `flutter test` toàn bộ **2105/2105 pass** (1 phút 7 giây, đo 2026-09-12 sau lượt sửa sau soát cuối cả nhánh — mức nền trước kế hoạch **2078** → **+27**). `flutter analyze` **25 issue = 20 info + 5 warning + 0 error** — khớp mức nền, cùng năm tệp như trước (`sync_engine.dart` 5, `connection/web.dart` 1, `category_tree.dart` 1, `change_password_page.dart` 2, `test/e2e_sqlite_to_backend_sync_test.dart` 16); không issue nào ở `core/api/`. Test mới: **27** = `ket_qua_lam_moi_test.dart` **13** + `auth_interceptor_test.dart` **+14** (3 cũ → **17**: 8 ca §3.8 điểm 1, 1 ca "200 không có `accessToken`", 1 ca "kho token hỏng lúc xoá", 3 ca §3.8 điểm 2, 1 ca "kho token ném lỗi"). `core/api/`: **2** tệp / **30** test. Tệp test nay **200** `_test.dart` (**201** `.dart` kể cả `category_test_fakes.dart`) / **45.599** dòng — trước kế hoạch: 199 / 200 / 45.147 (đếm bằng máy 2026-09-12). Mốc **2104/2104** · 2 phút 1 giây · 45.557 dòng · 26 test mới là của `7cbd849` (2026-09-11), **trước** lượt sửa sau soát cuối.
  > **Quyết định:** lỗi trả ra khi làm mới hỏng tạm thời là lỗi của chính lượt làm mới (dựng lại trên `RequestOptions` gốc), không phải 401 gốc — vì `verifySession` coi 401 là phiên chết; lỗi thứ ba — thử lại hỏng sau khi làm mới **đã thành công** — nay giữ token thay vì xoá cả hai; xoá token + phát `sessionExpiredStream` chỉ nằm trong `_lamMoi()`, một lần cho một lượt (không để N request chờ tự xoá và dội tín hiệu N lần); chốt "token cũ" đứng trước lượt gọi chung; `LamMoiPhienChet.loi` giữ nguyên `DioException` để §3.3 (Phần 1) đọc body 401; giữ `extends Interceptor` — không đổi sang `QueuedInterceptor` — vì lớp con trong `session_validation_test.dart` kế thừa `AuthInterceptor`, và `QueuedInterceptor` xếp hàng cả `onRequest`; bẫy mới ghi vào spec §9 (`_clearTokens` phải chạy trong lượt chung, không thì N request đan xen đọc/xoá phát tín hiệu N lần); và **`7cbd849` là chốt phòng thủ, không phải một lỗi đã có** — lo ngại lỗi thoát khỏi future dùng chung sẽ treo mọi request chờ không tái hiện được trên `dio 5.11.0` (xem TDD trên), nhưng vẫn giữ chỗ sửa để không phụ thuộc hành vi bọc ngầm ấy ở phiên bản Dio sau, và để lỗi mang thông điệp rõ. Chi tiết đầy đủ ở spec §3.8.
  > **Không kiểm trên máy ảo:** không đổi giao diện; không ép được token truy cập hết hạn; và CAN-LAM 17 mục A làm `/auth/refresh` trả 401 cho mọi tài khoản, nên nhánh làm mới không dựng được đầu-cuối trên backend đã gộp. ⚠️ **Rủi ro còn lại, nói thành lời:** toàn bộ lời hứa §3.8 hiện **chỉ được canh bằng máy chủ giả** — chính hành vi "mất mạng thì giữ token" chưa một lần nào chạy trên máy thật. **Việc còn nợ:** khi backend đóng CAN-LAM 17 mục A thì kiểm một lượt trên máy ảo — đăng nhập, bật chế độ máy bay (hoặc hạ `JWT_USER_ACCESS_EXPIRES` trên backend dev để ép 401), xác nhận **không** bị đăng xuất và hai token còn nguyên trong kho.
  > **Lượt sửa sau soát cuối cả nhánh** (2026-09-12; người soát xếp *With fixes* — 0 Critical, 0 Important, 8 Minor; controller chọn làm **cả tám** trong một lượt, hai commit). Mã và test (`fe5a9fc`): (1) `catch (Object)` của `_lamMoi()` không còn hạ cấp một phiên **đã xác định** là chết — `_clearTokens()` phát tín hiệu trong `finally`, và `_lamMoi()` giữ phán quyết ở biến `phanQuyet` đặt trước lời gọi ấy; trước đó kho token hỏng đúng lúc xoá làm nơi gọi nhận `LamMoiTamThoi` và **không** có tín hiệu nào — đúng hình dạng G12 (ca mới đỏ trước, xanh sau). (2) Nhánh "200 không có `accessToken`" thôi gắn `response` của `/auth/refresh` vào lỗi trả cho request gốc: `SyncEngine` in `e.response?.data` bằng `debugPrint`, thứ **không** bị lược ở bản release, nên backend đổi tên khoá là body còn refreshToken ra thẳng logcat qua lỗi của một request khác. (3) Ba ca đồng thời thêm chốt canh (`bearerDaThay`) để không xanh vì lý do khác. (4) Chú thích giới hạn của `_retryRequest`. (5) `_loiTamThoiChoRequest` chép `stackTrace`. Tài liệu (commit ngay sau `fe5a9fc`): hai câu tả sai khối `catch` của chốt "token cũ" (spec + dòng trên), phạm vi gạch `LamMoiPhienChet.loi` và điểm vướng cho Phần 1, `FIX_BACKEND_3_REGRESSIONS.md` (`onError` gọi `_lamMoiChung()` → `_lamMoi()`), việc kiểm máy ảo còn nợ, và số đo mới.

### 🔄 Việc còn dang dở

Xem đầy đủ tại **`docs/CLIENT_APP_KNOWN_GAPS.md`**. Phiên 2026-09-03 đã đóng 9/10 mục còn mở; **G10 đóng ngày 2026-09-07**, và cùng ngày mở thêm **G23** (bản sao danh mục chỉ đầy đủ khi bộ mặc định *cục bộ* đầy đủ — tự khỏi ở lượt pull sau) và **G24** (màu danh mục không có cột trên server, chặn ở backend — ⚠️ 2026-09-11: thành lỗi phía client rồi đóng cùng ngày, xem dưới). **G15 đóng 2026-09-07** (dòng này từng còn liệt kê nó — soát lại 2026-09-09 từ chính `CLIENT_APP_KNOWN_GAPS.md`). Đếm lại từ chính `CLIENT_APP_KNOWN_GAPS.md` ngày 2026-09-10, cập nhật 2026-09-11 sau khi gộp `main` @ `cc65f4f` và áp `database/12` — dòng cũ ở đây chỉ liệt kê ba mục và đã bỏ sót bốn: mục **chưa đóng** nay là **G18** (⏸️ thu hẹp dần), **G23** (⏸️ chấp nhận được), **G26** (✅ cố ý — chờ màn duyệt giao dịch ngân hàng), **G27** (⏸️ hoãn có chủ ý — "ví được phép âm"), **G28** (⏸️ hết chặn phía server, chờ client mở lại — lưu trữ ví chỉ sống trên máy đã bấm, mở 2026-09-10; tệp `database/7` đã áp lên CSDL dev tối cùng ngày, cột nay `varchar(20)`; người dùng chốt mở lại **để sau**) và **G34** (⏸️ chưa làm, việc client — backend đã phát `sync.completed` ra socket sau mỗi `/sync/push`, nhưng client chưa nghe sự kiện ấy (`realtime_event.dart` chỉ khai ba sự kiện), và hôm nay nó cũng chưa tới được client vì bắt tay socket từ chối mọi tài khoản — CAN-LAM 17 A; mở 2026-09-11) — đếm lại bằng script 2026-09-11 sau khi đóng G33: **6** mục (loại ba mục *không phải lỗi*). **Đóng 2026-09-11**: **G24** (client đổi khoá màu danh mục sang `color`; kiểm trên máy ảo), **G35** (ba màn quản lý danh mục lấy tài khoản với dự phòng `?? 1` — mở và gỡ cùng ngày theo khuôn G4, kèm test quét `lib/`), **G30** (client gỡ chốt một ví Tiết kiệm sau khi `database/12` bỏ index; kiểm trên máy ảo), **G33** (trang Xoá tài khoản thôi hứa "đăng nhập lại là tự khôi phục", tài khoản chờ xoá dùng tiếp 30 ngày với thẻ nhắc đóng được ở Trang chủ và nút huỷ ở Cài đặt — chín commit `ca44dd8` → `866b870` (đếm bằng máy 2026-09-11), kiểm trên máy ảo với tài khoản 11 — khối "Sửa G33 — tài khoản chờ xoá dùng tiếp 30 ngày" trên), và theo mã backend sau gộp (chưa chạy đầu-cuối): **G29** (bộ lọc ghi chú mới chạy đúng 15/15 ca), **G31** (`22001`/`23502` thành `CONSTRAINT_VIOLATION`; bộ lọc bảy ô tên phía client vẫn giữ để bản ghi không kẹt vĩnh viễn) và **G32** (backend giữ `null`, tệp 12 dọn `<= 0` trên CSDL dev; client vẫn đọc `<= 0` là chưa sắp làm lớp phòng thủ). **G19**, **G22** và **G25** ghi *không phải lỗi*, giữ lại để người sau không "sửa" nhầm:

- **G15 — Bản ghi vừa hết hạn vừa hỏng đồng bộ thì không sửa được.** ⏸️ **Hoãn có chủ ý** (2026-09-04): tab "Đã hết hạn" khoá sửa/xoá, nên một ngân sách vừa quá hạn vừa bị backend từ chối vĩnh viễn sẽ nằm lại mãi — hàng đợi đồng bộ vẫn thông vì `SyncEngine` chặn nó theo thời gian, nhưng người dùng không chữa được. Giữ nguyên vì tab đó là nền cho phần thống kê/báo cáo sẽ làm sau. Bán kính rủi ro hẹp: nguồn gây lỗi chính (form tạo ra `end ≤ start`) đã bịt cùng ngày.
- ~~**G10 — `CategoryGroupMemberships` không bao giờ được đồng bộ.**~~ ✅ **Đóng 2026-09-07, và không phải bằng cách xin backend thêm entity.** Bảng phụ ấy tồn tại chỉ vì danh mục mặc định là hàng toàn cục nên không ghi `Idgroup` riêng cho từng tài khoản được. Nay mỗi tài khoản có **bản sao riêng** của bộ mặc định, nên việc gán nhóm nằm gọn trong `Idgroup` của chính hàng họ sở hữu — cột đã có sẵn và đã đồng bộ.

> ⚠️ **`.gitignore` vẫn có `test/`** (dòng 78, đo 2026-09-10 — từng ghi 77)**.** Luật này đã cắn **lần thứ ba** (phiên 2026-09-04). Mọi file test tạo **mới** vẫn sẽ bị bỏ qua trong im lặng — nhớ `git add -f`.
>
> Hệ quả ít ai biết: **công cụ Grep tôn trọng `.gitignore` nên không nhìn thấy thư mục `test/`**. Muốn dò xem còn ai gọi một hàm sắp xoá thì phải dùng `grep` qua shell, nếu không sẽ thấy thiếu file và xoá nhầm.

Vấn đề thuộc backend. Thư mục `docs/superpowers/backend/` được **chia ba** ngày
2026-09-07: **`CAN-LAM/`** giữ đúng phần **còn việc** — nay **3** tài liệu (đếm bằng máy 2026-09-11, sau khi gộp `main` @ `cc65f4f`, áp `database/12` và viết mục 19): mục **17** `FIX_BACKEND_3_REGRESSIONS.md` (ba hồi quy của `7675b35` — bắt tay socket và `/auth/refresh` từ chối mọi tài khoản, chốt trả hai lần chặn hoàn tác hoá đơn, tài liệu backend ghi sai ba mã lỗi), mục **18** `VERIFY_7675B35_REMAINING.md` (chín việc mã/CSDL còn dang dở của mười lăm tài liệu backend báo xong, cộng 45 chỗ sửa tài liệu backend) và mục **19** `AUTH_PROFILE_COUNTDOWN.md` (`GET /auth/profile` trả thêm `countdown`, gỡ `pendingDeleteCancelled` luôn `false` khỏi response đăng nhập). Trước khi gộp, thư mục có **mười sáu** mục — dòng này từng ghi "bốn", "sáu", "tám", "mười", "mười một", "mười lăm" rồi "mười sáu". README
trong đó là **cửa vào duy nhất** (mục 1: việc còn lại; mục 2: trạng thái mười lăm tài liệu vừa chuyển đi); **`DA-XONG/`** giữ 31 tài liệu **đã đóng** (đếm bằng máy 2026-09-11 sau khi gộp; trước đó 16 — chín trong mười lăm tài liệu mới chuyển còn phần dang dở, gom vào mục 18 chứ không chuyển ngược lại), mở khi
cần biết *vì sao* lược đồ có hình dạng hôm nay chứ không phải khi tìm việc; thư mục
cha chỉ còn mục lục và **ba** tệp bối cảnh (`2026-08-10-backend-sync-spec.md`,
`PROGRESS-BACKEND.md`, `TRANSACTION_NOTE_ENCODING.md`) — đếm lại bằng máy
2026-09-10. ⚠️ **`New_Database.md` đã rời thư mục ấy**: nhánh `main` chuyển nó
sang `docs/Rule_Project/` cùng ngày, nên mọi liên kết tương đối cũ đều hỏng.
Dòng này từng ghi "ba" rồi "bốn" rồi lại "ba" — đếm bằng máy mỗi lần chạm vào.

Bảng dưới giữ **cả** mục đã đóng lẫn mục còn việc, vì nó là nơi duy nhất đọc được
toàn cảnh một lượt. Muốn biết *phải làm gì tiếp* thì đọc `docs/superpowers/backend/CAN-LAM/README.md` —
mục 1 của nó là việc còn lại, mục 2 là trạng thái đo 2026-09-11 của từng tài liệu (bản
chia việc theo *client đã có tính năng này chưa* nay chỉ còn trong lịch sử git).

Bảng dưới **kiểm lại ngày 2026-09-07** sau khi gộp `origin/main` `193b6d5`
(đợt backend lớn: Socket.io, `/sync/push`, danh mục Template & Cloned, và một
đợt migration) và sau khi **áp dụng migration ấy vào PostgreSQL**. Mỗi ô ✅ ở
đây đều được đối chiếu bằng **mã nguồn hoặc truy vấn đọc trên CSDL thật**, không
phải chép từ bảng trạng thái của backend. **Thứ tự là thứ tự thi công đề nghị**,
không phải thứ tự chữ cái.

> ⚠️ **Migration của đợt ấy không chạy được ở bản gốc.**
> `)2_can_lam_all_migrations.sql` xoá **cứng** 5 danh mục mặc định ngoài bộ 13
> stable UUID; `fk_bill_category` là RESTRICT và có 6 hoá đơn trỏ tới, nên câu
> ấy ném 23503 và **cả tệp roll back**. Client đã đổi thành xoá mềm trên nhánh
> **`patch2`** (commit `ea3611a`), chạy thử trong giao dịch rồi `ROLLBACK` để
> kiểm, sau đó áp dụng thật. Bộ mặc định trên server nay còn **13 hàng sống +
> 5 hàng xoá mềm**; 7 giao dịch và 6 hoá đơn giữ nguyên danh mục.

| # | Tài liệu | Trạng thái |
|---|---|---|
| 1 | `CATEGORY_KEYWORD_SYNC.md` | ✅ **Xong 2026-09-07** — `appendCategoryKeyword()` nhận `idaccount`, ném 403 khi danh mục là `is_default` hoặc khác `create_by`; `classify.service.js:196` có truyền xuống. Chiều **lên** hoá ra không cần backend: `/sync/push` vốn đã nhận `keyword`, client nối xong cùng ngày và có test hợp đồng |
| 2 | `2026-09-04-backend-idempotent-delete.md` | ⚠️ **Ba trong bốn.** **(A)** ✅ xoá luỹ đẳng — trả `synced` + `'Already absent'`. **(B)** ✅ mã lỗi có cấu trúc (`code` + `constraint` + thông báo tiếng Việt). **(C)** ✅ `time_recurrence` giữ được `null` → ngân sách "Ngày cụ thể" thông. **(D)** ⛔ **CÒN** — `sync.repository.js:327` vẫn `?? 0` và schema vẫn `@default(0)`. ⚠️ Bản vá (B) làm hỏng phép phân loại lỗi phía client (regex `23505`/`23514` hết khớp vì `message` đổi) — client đã tự vá bằng `_permanentCodes`, backend không phải làm gì. ⚠️ 2026-09-11: (D) mã đã xong (nhánh tạo giữ `null`, `schema.prisma` bỏ `@default(0)`), CSDL dev vẫn `DEFAULT 0` — CAN-LAM 18 §2.2 |
| 3 | `2026-09-04-ocr-classify-review.md` | ⚠️ **Phần nguy hiểm đã xong.** **(1)** ✅ Socket.io: JWT ở handshake, `join_account` gỡ hẳn, `grep 'io.emit('` toàn backend → **0 kết quả**, cả bốn sự kiện vào room; `Admin-web/useSocket.js` gửi `auth: { token }`. **(6)** ✅ `uq_transaction_external` nay `UNIQUE ("Idaccount", "Provider", "Bank_tran_id")` — **điều kiện chặn client gửi `provider`/`bank_tran_id` đã gỡ**. Còn **(2)–(5)**: `classifyBatch` sai kiểu tham số, `.env` không có `GEMINI_API_KEY`, dedup Quy tắc 3, cửa hậu `_mock*` — không gấp, client chưa có màn quét hoá đơn nào. ⚠️ Backend đổi **Casso → SePay** trong cùng đợt. ⚠️ 2026-09-11: `classifyBatch` và dedup Quy tắc 3 đã xong; cửa hậu `_mock*` chỉ đóng ở `production`, `.env` dev vẫn thiếu `GEMINI_API_KEY` — CAN-LAM 18 §2.8 |
| 4 | `CATEGORY_NAME_UNIQUENESS.md` | ✅ **Xong 2026-09-07** — hai partial unique index `uq_category_owner_name` `(Create_by, tên chuẩn hoá NFC)` và `uq_category_default_name`, **cả hai có `WHERE "Delete_at" IS NULL`** và **không** có `Classify`. Trigger chéo đã DROP nên bản sao được trùng tên với khuôn. Đây là lần đầu client và PostgreSQL thi hành **cùng một** quy tắc trùng tên |
| 5 | `CATEGORY_STABLE_IDS.md` | ✅ **Xong 2026-09-07** — `seed.js` đóng băng 13 UUID cố định, hết `crypto.randomUUID()` cho danh mục. Kèm API mới `GET /api/sync/default-categories`. ⚠️ Bộ mặc định thu từ 18 về 13: `Chi khác`, `Thu khác`, `Làm thêm`, `Trả nợ`, `Thu nợ` đã bị **xoá mềm** — tài khoản mới không còn được nhân bản chúng |
| ~~6~~ | `CATEGORY_GROUP_MEMBERSHIP_SYNC.md` | ✅ **Đóng 2026-09-07** — không cần backend làm gì |
| 7 | `CATEGORY_CLASSIFY_ALIGNMENT.md` | ✅ **Xong 2026-09-07** — `validClassify` (`sync.validation.js:110`) nay đúng `['Thu', 'Chi', 'Vay/no']` |
| 8 | `2026-09-05-backend-transaction-goal-id.md` | ✅ **Xong 2026-09-07** — cột `transaction.Idgoal` đã có trong CSDL, kèm `fk_transaction_goal` (ON DELETE SET NULL) và `idx_transaction_goal`; `mapEntityFields` nhận cả `goalId` lẫn `goal_id`. Client có thể bỏ nhánh so **tên** khi tới lượt |
| 10 | `2026-09-05-backend-goal-priority.md` | ✅ **Cột đã có 2026-09-07** — `goal.Priority` (`Int?`) trong CSDL và trong `mapEntityFields`. Client **chưa làm** ưu tiên mục tiêu; nay không còn gì chặn, chỉ là chưa tới lượt. Lối "xin cột trước khi viết mã" đã chứng minh rẻ hơn hai lần "làm trước xin sau". ✅ Client làm xong ưu tiên mục tiêu 2026-09-08 (schema v19); backend giữ `null` từ 2026-09-11 (G32 đóng) |
| 9 | `2026-09-05-backend-goal-auto-deposit.md` | ✅ **Xong 2026-09-07** — cả **ba** cột `auto_deposit_amount` / `auto_deposit_wallet_id` / `auto_deposit_last_run` lên **cùng một lúc** đúng như cảnh báo, và `mapEntityFields` đã ánh xạ |
| 11 | `2026-09-06-bill-chuoi-ky-va-an-han.md` | ⛔ **Chưa có cột nào.** Đo 2026-09-07: bảng `bill` có 18 cột, **không** có `Previous_bill_id` lẫn `Auto_pay`; `transaction` **không** có `Idbill`. **(A+B) Mở khoá:** hai cột nullable — hoàn tác thanh toán hiện chỉ chạy trên đúng máy đã trả; cột B còn mở **lịch sử theo hoá đơn**. **(C) Mở đường:** `bill.Period_end` để tách kỳ tính tiền khỏi hạn trả. **(D) Mở khoá:** `bill.Auto_pay` + **chốt chặn trả hai lần** ở `/sync/push` — hai máy cùng bật, cùng offline là hai khoản chi. **(E) Mở đường:** nhận `Pay_status = 'Skipped'` (VarChar(7) vừa khít, không cần migration). ⚠️ Bảng `bill` **đã có** cột `Color` trong khi `category` thì không — lý lẽ sẵn cho mục màu danh mục. ⚠️ 2026-09-11: server nay đủ cột (cả `Period_end`, `Anchor_day`) và nhận `'Skipped'`, `category.Color` cũng đã có; nhưng chốt trả hai lần đặt sai chỗ (CAN-LAM 17 B), và phía client các cột hoá đơn vẫn cục bộ |
| — | `SESSION_VALIDITY_FINDINGS.md` | ✅ Xong |

### 💰 Ngân sách (2026-09-03)

Trước phiên này, `budget` là feature **duy nhất bị đứt đoạn ở giữa**: bảng Drift, DAO và cả hai chiều đồng bộ đã hoàn chỉnh, nhưng UI là dữ liệu giả cứng — `budgetDao` không có một lời gọi nào từ mã sản xuất ngoài `SyncEngine`, và nút "Lưu" ở trang cấu hình là `onPressed: () {}`.

Nay đã có đủ tầng như `goal`/`bill`: `data/models` → `datasources` → `repositories` → `presentation/bloc` → hai trang.

Ba điểm cần biết khi đụng vào vùng này:

- **Số "đã chi" được tính lại ở client từ bảng `transactions`, không đọc cột `Spent`.** Cột đó tồn tại ở cả hai phía nhưng **không bên nào cập nhật**: backend không có tác vụ nền, còn giao dịch thì người dùng ghi được khi offline. `BudgetRepositoryImpl` ghi kết quả xuống cột bằng `cacheSpent()` để lần đẩy sau gửi đúng số — hàm đó cố ý **không** đụng `syncStatus` lẫn `updatedAt`, nếu không mỗi lần mở trang lại sinh một thao tác đẩy và LWW cho client thắng oan.
- **Ba phần trong bản dựng hình bị bỏ vì không có chỗ lưu:** "Tên ngân sách" (backend không có cột tên), "Danh mục áp dụng" nhiều danh mục (`Idcategory` chỉ giữ được một), và "Quy tắc phân bổ 50/30/20" (không có bảng nào lưu, và nó nói về chia *thu nhập* chứ không phải hạn mức). Giữ lại chúng dưới dạng giao diện không lưu được gì sẽ tái lập đúng vấn đề cũ: người dùng bấm Lưu và tưởng đã lưu.
- **Lược đồ `budgets` đã khớp backend (v11, 2026-09-03).** Thêm `threshold_warning_percent` (backend có từ DB v2, client thì chưa — ngưỡng cảnh báo theo phần trăm vì thế không bao giờ sang được máy khác) và bỏ ba cột backend không có: `remaining`, `percent_spent` (chỉ là `amount - spent` và `spent / amount`, nay tính ở `BudgetEntity`) và `period` (đã bị `time_recurrence` thay thế từ DB v2).
  - Migration dùng `TableMigration` chứ không phải `ALTER TABLE ... DROP COLUMN`: cú pháp đó chỉ có từ SQLite 3.35, mà phiên bản đi kèm khác nhau giữa Android, iOS và web.
  - Ngưỡng phần trăm lưu **0–100** để khớp `Decimal(15,2)` của backend; quy về tỉ lệ đúng một chỗ ở `BudgetEntity.warningRatio`. Thứ tự ưu tiên khi cảnh báo: ngưỡng theo số tiền → ngưỡng theo phần trăm → mốc mặc định 90%.
  - Việc này làm lộ một lỗi **fixture** trong `category_dao_test.dart`: bảng `budgets` giả luôn ở hình dạng trước v5 kể cả khi test khai `user_version = 7`/`9` — một trạng thái không tồn tại trên máy thật, vì migration là cộng dồn. Nay `_createLegacyNonCategoryTables` nhận tham số `atVersion`.

### 🔴 Đồng bộ đang bị kéo chậm bởi 5 danh mục hỏng (đo trên app thật 2026-09-03)

Chạy app thật với một tài khoản đã có dữ liệu, trên một máy **chưa từng chạy
app**, cho thấy một hậu quả mà không tài liệu nào ghi trước đó:

1. Backend đã có 5 danh mục cá nhân của tài khoản; máy mới sinh lại đúng 5 danh
   mục đó với **UUID khác**.
2. Đẩy lên vi phạm quy tắc trùng tên → `/sync/push` trả `failed` **kèm message
   rỗng**.
3. `reason` rỗng nên `_classifyFailure` xếp vào `transient` → thử lại vĩnh viễn.
4. Mọi chu kỳ đồng bộ kết thúc ở trạng thái hỏng → giãn cách luỹ tiến
   30s → 1p → 5p → 15p → 60p.
5. **Mọi thay đổi khác** (ví, giao dịch, ngân sách) bị đẩy chậm theo. Đã đo: một
   thao tác xoá ngân sách hợp lệ không lên tới backend cho tới lần mở app sau.

**Nguyên nhân bước 1 nằm ở client — ✅ đã sửa 2026-09-03.**
`PersonalDefaultCategories` **có** kiểm trùng theo tên chuẩn hoá, nhưng chạy
**trước** `SyncEngine.start()`, nên trên máy mới thì CSDL cục bộ còn rỗng và
phép kiểm không thấy gì. Đây **không** phải hệ quả của `CATEGORY_STABLE_IDS.md`
như bản ghi đầu tiên (`25915ec`) quy nhầm.

Nay tách làm hai giai đoạn: `convertLegacyRows()` chạy trước đồng bộ và chỉ đụng
máy còn hàng seed `cat_*`; `ensureMissing()` chạy **sau** khi pull xong, và chỉ
khi `SyncEngine.hasCompletedPull` — pull hỏng thì hoãn tới lần mở app sau chứ
không tạo mù. Chi tiết ở **G14** trong `docs/CLIENT_APP_KNOWN_GAPS.md`.

Máy đã lỡ tạo bản trùng thì `CategoryDao.mergeDuplicatePersonalCategories()`
dọn nốt sau mỗi lần pull: gom theo tên chuẩn hoá, giữ bản `synced`, repoint mọi
tham chiếu rồi **xoá vật lý** bản `pending` — ngoại lệ có chủ ý của quy tắc 5, vì
hàng đó chưa từng tồn tại trên server. Chi tiết ở cuối G14.

Phần backend (mã lỗi ổn định, vai trò lớp phòng thủ thứ hai) ở khung đỏ đầu
`CATEGORY_NAME_UNIQUENESS.md`. Phần độ trễ giảm bớt ở **G13**.

### 🚀 Bắt đầu từ đâu ở phiên sau

Viết lại ngày **2026-09-07 (cuối phiên)**, sau khi gộp đợt backend lớn và đóng
G15, G17, G21. Bản trước của mục này ghi ngày 04/09 và **sai bốn trong sáu
điểm** — giữ nguyên là chỉ đường cho người sau đi vào việc đã xong.

> ⚠️ **2026-09-11 — câu in đậm ngay dưới không còn đúng.** Lượt rà soát CSDL mới
> (2026-09-10) tìm ra **G33** (✅ đóng 2026-09-11 — khối "Sửa G33 — tài khoản chờ
> xoá dùng tiếp 30 ngày" ở trên) và **hai lỗi làm mới token có sẵn** (spec cưỡng chế
> đăng xuất §3.8 — ✅ **đã sửa 2026-09-11**, khối "Sửa hai lỗi làm mới token — spec
> §3.8" ở trên). Thứ tự người dùng duyệt 2026-09-11, đã qua **sáu** bước đầu (gửi
> CAN-LAM 17/18, duyệt spec, push, nhãn loại ví ở bảng chọn ví, G33, **6** §3.8 hai
> lỗi làm mới token); và **7** Phần 1 cưỡng chế đăng xuất
> (spec mục 3 và §5.1, ✅ **xong 2026-09-12**); còn lại từ **8** client gửi/đọc bốn cột hoá đơn server đã có (`Idbill`,
> `Previous_bill_id`, `Period_end`, `Anchor_day`) → **9** "Bỏ qua kỳ"
> (`Pay_status = 'Skipped'`; dựng màn Stitch và đối chiếu app thị trường trước) →
> *sau khi backend sửa CAN-LAM 17:* **10** gộp `main` (chỉ khi người dùng cho phép
> đích danh) → **11** nghe `sync.completed` (G34; người dùng chốt toast hay im lặng)
> → **12** đồng bộ `Auto_pay` chỉ sau 17 B → **13** G28 (người dùng chốt để sau).

**Không còn lỗi client nào sửa được mà không phải chờ ai** (đúng tới 2026-09-10,
xem ghi chú trên)**.** Việc tiếp theo là
một lựa chọn, không phải một hàng đợi.

**Thứ tự đã duyệt tối 2026-09-08 — NAY ĐÃ XONG HẾT** (mục cuối, Socket.io,
đóng ngày 2026-09-09). Danh sách giữ lại để người sau thấy đường đã đi, đừng
bàn lại từ đầu:
✅ bộ lọc tay/tự động của lịch sử mục tiêu →
✅ **2a** Phân tích số thật → ✅ **2b** biểu đồ theo thời gian (**thư viện đã
chọn: `fl_chart`, ghim `1.2.0`** — mục 3.11 `ANALYTICS_FEATURE.md`) →
✅ **2c** trang Xuất báo cáo → ✅ biểu đồ tiến độ mục tiêu theo thời gian (mục
**3.26** `GOAL_FEATURE.md`) → ✅ Tổng kết tuần (2026-09-09; bốn câu hỏi mở của
spec đã chốt với người dùng, bàn giao ở mục **5d** `NOTIFICATION_FEATURE.md`)
→ ✅ số liệu tổng hợp mục tiêu (mục **3.27** `GOAL_FEATURE.md`) →
✅ **nối Socket.io phía client** (2026-09-09; xem khối ngay dưới).

> ### ✅ Socket.io phía client — xong 2026-09-09
>
> `lib/core/realtime/` giữ **một** kết nối tới backend, xác thực JWT ngay ở bắt
> tay, tự nối lại theo giãn cách **2 → 5 → 15 → 30 → 60 giây**, và **nối lại
> ngay** khi có mạng trở lại. Vòng đời bám đúng `NotificationScanner`: bốn chỗ
> trong `AuthBloc`, hai vào hai ra.
>
> **Ba điều dễ vấp nhất**, đọc trước khi đụng vào:
>
> 1. **Payload là hộp đen — client không đọc trường nào.** Chỉ dùng *tên sự
>    kiện*. Vì `bank_transaction.incoming` được backend phát từ hai chỗ với hai
>    hình dạng khác nhau, và trường `type` mang hai nghĩa. Có test cấm chữ số
>    xuất hiện trong lời nhắn để canh chừng ai đó bắt đầu đọc payload.
>    ⚠️ **Một ngoại lệ, từ 2026-09-12:** `account.force_logout` **có** đọc
>    payload (`idaccount`, `reason`, `message`) — nó chỉ được phát từ **một**
>    hàm, `core/socket.js:175-191`, nên hình dạng là duy nhất. Chính vì thế nó
>    đi **luồng riêng** `RealtimeChannel.buocDangXuat`, tách hẳn `events`: cam
>    kết trên còn nguyên cho ba sự kiện kia. Xem khối "Phần 1 cưỡng chế đăng
>    xuất" ở trên.
> 2. **`io.io()` cache `Manager` theo `scheme://host:port` và dùng lại options
>    của lần dựng đầu** — nên phải `enableForceNew()`, nếu không token mới bị bỏ
>    qua **im lặng**. Cùng lý do ấy, cơ chế nối lại của thư viện bị **tắt**:
>    mỗi lần thử phải đọc lại token từ kho.
> 3. **`AppConstants.baseUrl` có hậu tố `/api`, socket thì không** — dùng
>    `socketBaseUrlFrom()`, đừng cắt chuỗi tại chỗ.
>
> **Phạm vi thật hẹp hơn tài liệu kế hoạch mô tả:** chỉ có kênh + đánh thức
> đồng bộ + toast. Không có màn "Giao dịch chờ duyệt" (G26
> `CLIENT_APP_KNOWN_GAPS.md`), không badge đếm. Ba sự kiện backend đang phát
> đều thuộc tính năng client chưa có, nên **giá trị thật của kênh nằm ở việc
> backend bắc `sync.completed` ra socket** — mục 7 cũ của
> `docs/superpowers/backend/CAN-LAM/README.md`, nay `DA-XONG/SOCKET_SYNC_COMPLETED.md`.
> ⚠️ **2026-09-11:** backend **đã bắc** — `sync.service.js:223` phát sau mỗi
> `/sync/push` tới phòng `account_<id>` — nhưng giá trị ấy vẫn chưa tới: bắt tay
> socket từ chối mọi tài khoản (CAN-LAM 17 A), và client **chưa nghe** sự kiện
> này — `realtime_event.dart` chỉ khai ba sự kiện (**G34**).
>
> Cùng đợt, dải báo kín ngang đổi thành **toast nổi ở đáy**
> (`shared/widgets/app_toast.dart`, thay `connection_banner.dart`), theo màn
> Stitch *"Thông báo nổi (toast) - FlowMoney"*. Thứ tự ưu tiên nay là **đồng bộ
> > realtime > kết nối**, và **một nguồn luôn được cập nhật chính nó** — vế
> cuối là thứ giữ cho "Đã kết nối lại" thay thế được "Không có kết nối".
>
> Thiết kế đầy đủ:
> `docs/superpowers/specs/2026-09-09-socket-io-realtime-channel-design.md`.

> ⚠️ Mục 5 của spec Tổng kết tuần có **ba** câu hỏi, không phải năm — đếm bằng
> máy 2026-09-09. Con số "5" từng đi qua ba tài liệu tóm tắt vì đếm theo trí
> nhớ. Câu thứ tư (chỗ đến của deeplink) là câu **mới**, phát hiện khi rà mã. **Round-up cố ý để ngoài** — chỗ
thứ ba app tự chuyển tiền trong khi chỗ thứ hai (tự động thanh toán hoá đơn) còn
thiếu chốt chống trả hai lần đúng chỗ — server đã có cột `bill.Auto_pay` nhưng cột
phía client vẫn cục bộ, và chốt ở `upsertBill` đặt sai chỗ (CAN-LAM 17 B; đo
2026-09-11). Lý do từng bước: mục 10.5 `docs/GOAL_FEATURE.md` và mục 7
`docs/ANALYTICS_FEATURE.md`.

1. **Người dùng đã chọn mảng thông báo** (2026-09-07 tối), hoãn mảng Phân tích
   *"vì còn nhiều cái liên quan chưa triển khai"*. Thứ tự đã duyệt:
   **#7 lọc/phân trang ✅ → #2 nhắc ghi chép ✅ → #5 nút hành động ✅ →
   #6 badge ✅** (2026-09-08). Thứ tự #5 và #6 được **đảo** giữa chừng theo đề
   nghị của tôi và người dùng đồng ý.

   **Mảng thông báo nay chỉ còn hai mục, cả hai đều bị chặn bởi việc khác:**
   - **#1 Tổng kết tuần** — chờ một **màn dữ liệu thật phạm vi đúng một
     tuần** để thông báo trỏ tới. Từ 2026-09-08 tầng tổng hợp **đã có**
     (`thong_ke_thang.dart` nhận biên `[from, to)` bất kỳ, tuần hay tháng đều
     là một lời gọi), nên chỗ chặn thu hẹp còn *màn hình tuần* — trang Phân
     tích hiện theo **tháng**. Spec đã viết xong:
     `docs/superpowers/specs/2026-09-07-weekly-summary-notification-design.md`.
   - **#8 Thông báo trên web** — ưu tiên thấp có chủ ý; cần Service Worker và
     luồng xin quyền riêng của trình duyệt, mà web chỉ dùng để trình bày.

   Ngoài ra hai việc **chờ backend**: cảnh báo giao dịch ngân hàng/OCR và
   thông báo bảo mật. ⚠️ **Lý do đã đổi, đừng chép câu cũ:** kênh Socket.io
   nay **đã xác thực** (backend sửa 2026-09-07) và client **đã nối**
   (2026-09-09) — ba sự kiện ấy tới nơi và hiện thành toast (⚠️ 2026-09-11: theo mã
   backend sau gộp `main`, bắt tay socket từ chối mọi tài khoản nên hôm nay không
   sự kiện nào tới — CAN-LAM 17 A). Chỗ còn thiếu là
   tính năng phía client để *làm gì đó* với chúng (G26), chứ không phải kênh
   truyền.

   ⚠️ Danh sách đầy đủ kèm ghi chú kỹ thuật nằm ở
   `docs/superpowers/plans/2026-09-06-thong-bao-viec-con-lai.md` — thư mục ấy
   **bị `.gitignore` chặn**, nên file chỉ có trên máy đã dựng nó, và công cụ
   Grep lẫn `git status` đều không thấy: mở bằng `cat` hoặc Read. (Bản trước
   của mục này trỏ tới "mục 9b `docs/NOTIFICATION_FEATURE.md`" — **mục ấy
   không tồn tại**; con trỏ chết đã hai phiên.)

   Mảng **Phân tích** — **lát 2a và 2b xong 2026-09-08**: `AnalyticsPage` nay
   đọc số thật qua `AnalyticsCubit` → `AnalyticsRepository` (Drift + mượn
   `BudgetRepository` cho "% ngân sách"), và mang khối **"Xu hướng 6 tháng"**
   vẽ bằng `fl_chart`. Trước đó nó là giao diện tĩnh, **0** tham chiếu
   Bloc/Repository/Dao, và hiện *"T6 2026"* cứng khi đang là tháng 9.
   **Lát 2c‑1 xong 2026-09-09**: `ExportReportPage` không còn tĩnh — ví, danh
   mục và phạm vi thời gian lấy từ CSDL, và nút mở màn **Xem trước báo cáo**
   (`ReportPreviewPage`, dựng theo màn Stitch sinh cùng ngày). Ba khối bịa của
   bản Stitch cũ đã bỏ (lịch sử xuất, mật khẩu PDF, "Đích đến"). **Lát 2c‑1b**
   cùng ngày mở tờ báo cáo từ bốn khối lên **mười**, lấy chuẩn từ Money Lover /
   MISA / Copilot / PocketSmith: dòng tiền (số dư đầu và cuối kỳ), so với kỳ
   trước, biểu đồ thu chi, số liệu nhanh, thu theo danh mục, ngân sách kỳ này,
   phân bổ theo ví, top 5 khoản chi. **Lát 2c‑2 xong cùng ngày**: nút "Tải xuống"
   sinh tệp **PDF hoặc CSV** thật và **lưu thẳng vào thư mục Tải về** của máy
   qua `MediaStore` — **mảng Phân tích đến đây là xong**. Tầng tổng hợp mà
   "Tổng kết tuần" chờ nay đã có. Lý do và bẫy: `docs/ANALYTICS_FEATURE.md`.

   ⚠️ **`fl_chart` là thư viện vẽ duy nhất cho biểu đồ TRÊN MÀN HÌNH**, ghim
   cứng `1.2.0`. Trước 2026-09-08 `lib/` không có một `CustomPainter` nào;
   donut là `SweepGradient` và **vẫn giữ nguyên như thế**. Mọi biểu đồ trên
   màn hình về sau dùng chung `fl_chart` — đừng chọn lại lần thứ hai.
   Từ 2026-09-09 có **một chỗ vẽ thứ hai**: biểu đồ trong tệp PDF dùng
   `pw.Chart` của chính gói `pdf`, vì `fl_chart` vẽ ra widget chứ không ra
   trang giấy. Hai chỗ ấy **cố ý tách**, không phải quên gộp.
2. **Việc còn lại của backend: ba tài liệu** ở `docs/superpowers/backend/CAN-LAM/`
   (đếm bằng máy 2026-09-11, sau khi viết mục 19 — dòng này từng ghi "năm",
   "sáu" rồi "hai"). Mục **17** — ba hồi quy của `7675b35`:
   **A** bắt tay socket và `/auth/refresh` từ chối mọi tài khoản (kênh thời gian
   thực không nối được, người dùng bị đăng xuất khi token hết hạn), **B** chốt trả
   hai lần ở `upsertBill` chặn hoàn tác thanh toán hoá đơn đã đồng bộ, **C** tài
   liệu backend ghi sai ba mã lỗi. Mục **18** — chín việc mã/CSDL nhỏ còn lại của
   mười lăm tài liệu backend báo xong (giao dịch SePay vỡ `chk_transaction_type`
   theo mã, `bank_transaction.incoming` phát hai lần, khoá mã hoá viết cứng,
   `DEFAULT 0` của ngân sách trên CSDL, …) cộng 45 chỗ sửa tài liệu backend. Mục
   **19** — `GET /auth/profile` trả thêm `countdown` (máy đã giữ phiên từ trước khi máy khác gửi yêu cầu xoá, bộ nhớ đệm do bản client cũ ghi, và máy còn giữ số ngày của một lần chờ xoá trước
   mới biết đúng số ngày còn lại — đăng nhập máy khác hay cài lại app thì đã có số, vì response đăng nhập mang `countdown`) và gỡ `pendingDeleteCancelled` luôn `false` khỏi
   response đăng nhập.
   Việc **phía client** phát sinh từ lượt đối chiếu, chờ người dùng quyết:
   mở đồng bộ các cột hoá
   đơn đang cục bộ, nghe `sync.completed` (G34), và tính năng "bỏ qua kỳ này".
   ⚠️ Con số đúng lấy theo **mục 1 của README trong thư mục ấy** — đó là cửa vào
   duy nhất, và nó luôn là bản đếm có thẩm quyền. Thư mục `DA-XONG/` bên cạnh giữ
   **31** tài liệu đã đóng (đếm bằng máy 2026-09-11).
3. **Bản vá migration ở nhánh `patch2` — đã bàn giao cho backend (2026-09-08).**
   `)2_can_lam_all_migrations.sql` trên `main` có một câu `DELETE FROM "category"`
   xoá cứng 5 danh mục mặc định; `fk_bill_category` là RESTRICT nên nó ném 23503
   và **cả tệp roll back**. Nhánh `patch2` (commit `ea3611a`) đổi thành xoá mềm.
   CSDL trên máy này đã ở trạng thái đúng — đo 2026-09-08: **13 hàng mặc định
   sống, 5 hàng đã xoá mềm** — nhưng **tệp trong repo vẫn là bản xoá cứng**, nên
   môi trường khác chạy nó vẫn hỏng y như vậy. Đo lại 2026-09-11 sau gộp `main`: vẫn vậy — CAN-LAM 18 §2.4.
   ✅ **Người dùng đã thông báo cho người phụ trách backend ngày 2026-09-08.**
   Việc sửa tệp thuộc về họ; nhánh `patch2` giữ nguyên tại chỗ làm bản tham
   chiếu. **Đừng nêu lại đây như việc treo của phía client** — nó đã lặp qua ba
   phiên bàn giao trước khi được chuyển đi đúng người.
4. **Kịch bản nâng cấp CSDL v7 → v17 chưa từng chạy thật** (chỉ có test). Người
   dùng đã quyết định không chạy. Ghi lại vì: nếu sau này có báo cáo **mất danh
   mục** hoặc **giao dịch không đồng bộ sau khi cập nhật app**, đây là chỗ nghi
   đầu tiên. Cách kiểm: dựng worktree ở `ea0941b`, chạy bản cũ để sinh CSDL v7,
   rồi mở bản mới **cùng origin**. Số bước migration nay nhiều hơn hẳn phiên
   trước nên rủi ro cũng nhỉnh hơn.

> ⚠️ **Ba điều bản cũ của mục này nói sai — đừng chép lại từ đâu đó:**
> - *"`_classifyFailure` không có nhánh nào cho vi phạm UNIQUE (23505)"* — sai từ
>   2026-09-04 (`_uniqueConstraintPattern`), và từ 2026-09-07 phép phân loại đi
>   theo **`code`** của backend (`_permanentCodes`) chứ không dò chuỗi nữa.
> - *"Tính năng 'Ngày cụ thể' chưa đồng bộ được"* — việc (C) đã xong, backend giữ
>   được `time_recurrence = null`.
> - *"G15 là hoãn có chủ ý, đừng tự ý sửa"* — G15 **đã đóng** 2026-09-07 sau khi
>   người dùng đổi quyết định.

Muốn xác minh thay đổi ngoài bộ test thì dùng skill **`chay-app`** (Chrome
headless + truy vấn PostgreSQL). ⚠️ Skill đó nằm trong `.claude/` nên **không
được push** — chỉ có trên máy đã dựng nó. Với thay đổi **giao diện** thì Chrome
1280px không đủ: phải chạy máy ảo Android ở 411dp, xem mục ⚠️ trong `CLAUDE.md`.

### 🎯 Mục tiêu tiết kiệm (2026-09-05) — **hoạt động đầy đủ trên client**

**Đọc `docs/GOAL_FEATURE.md` trước khi làm tiếp** — nhất là mục 4 (bảy cái bẫy,
4.6 đã đóng) và mục **10**, đối chiếu với app thị trường.
Tóm tắt:

- **Ví nhận bắt buộc lúc tạo, và KHOÁ sau khoản nạp đầu tiên.** Tiền đã tích
  nằm thật trong ví ấy; đổi ví mà không chuyển tiền theo là phân mảnh không lần
  lại được. Hệ quả chấp nhận được: ví đang giữ tiền mục tiêu thì không xoá được.
- **Một lần nạp = MỘT giao dịch `type='transfer'`** mang cả `walletId` (nguồn)
  lẫn `walletTransfer` (đích), thay cho cặp `chi`/`thu` rời trước đây vốn làm
  thống kê đếm khoản chuyển ví thành chi tiêu thật.
- **Có luồng rút tiền**, kiểm **hai trần**: không quá tiến độ, và không quá số
  dư THẬT của ví. Rút xuống dưới mục tiêu thì **gỡ** `is_completed`.
- **Tiến độ KHÔNG tự hoà giải với số dư ví.** Tiêu tiền từ ví tích luỹ bằng giao
  dịch thường không hạ tiến độ — app chỉ **cảnh báo** lệch, vì một ví có thể
  phục vụ nhiều mục tiêu và cũng chứa tiền không thuộc mục tiêu nào.
- **Chiều nạp/rút đọc từ tiền tố ghi chú**, không từ vị trí ví. So ví là diễn
  giải hàng cũ bằng cấu hình hiện tại — đổi ví một lần là lịch sử đọc sai hết.
- **Dự báo hoàn thành tính từ nhịp thật**, không từ chu kỳ đã cài lúc tạo.
  `cycleTakeMoney` nay được lưu, nhưng **không có bộ lập lịch nào** đọc nó.
- Cột **cục bộ** `transactions.goalId` (schema **v14**) nối giao dịch với mục
  tiêu bằng ID thay vì bằng tên. Không đi qua đồng bộ — xem mục 8 bảng trên.
- Tỉ lệ tiến độ có **đúng một** định nghĩa (`GoalEntity.progress`); widget nhận
  thẳng `GoalEntity` nên nơi gọi không tính lại được.
- **Trang sửa mục tiêu** (`/goals/:id/edit`) dùng CHUNG biểu mẫu với trang tạo —
  `GoalAddPage` nhận thêm `goalId` tuỳ chọn. Nó **không** đụng ví tích luỹ (ô
  chỉ đọc, trỏ về nút đổi ví ở trang chi tiết) lẫn tiến độ, và **tính lại** cờ
  hoàn thành. `null` mang hai nghĩa khác nhau ở `updateGoal`: `cycleTakeMoney`
  là **xoá**, còn `icon`/`colour` là **giữ nguyên** — mục 3.9 `GOAL_FEATURE.md`.
- **Lời nhắc kỳ trích nổ cả khi app đóng.** `BillReminderScheduler` đổi tên
  thành **`ReminderScheduler`** và nay đặt lịch cho cả hoá đơn lẫn kỳ trích.
  Gộp chung là **bắt buộc**: `resync()` huỷ mọi lịch chờ không nằm trong tập nó
  muốn, nên hai bộ đặt lịch riêng sẽ xoá sạch lịch của nhau ở mỗi lượt — im
  lặng. Lời nhắc chỉ báo tin; tiền vẫn chỉ chuyển khi mở app.
- **Biểu tượng và màu riêng từng mục tiêu** đã nối dữ liệu. Bảng tra cố ý không
  chứa `'flag'` (giá trị dự phòng), nên mục tiêu cũ mang `'flag'` được **chèn
  vào đầu** bảng chọn thay vì bị bỏ qua — mục 3.10.
- **Trích tiền tự động ĐÃ CHẠY THẬT** (schema **v15**, ba cột `auto_deposit_*`
  — ⚠️ dòng cũ ở đây ghi chúng là **cục bộ**, sai từ 2026-09-07: backend đã
  thêm cả ba và client đẩy/kéo đủ, **G21 đóng**). Trước đây khối "Tự động trích tiền định kỳ" thu ba thông
  tin và lưu đúng một, còn nút bấm thì hứa "Bật Lập Lịch Tự Động" — một lời hứa
  về chức năng không tồn tại. Bộ chạy nằm trong `NotificationScanner.scan()`,
  **không phải WorkManager**: kỳ bỏ lỡ được trích bù khi app mở lại, đổi lại
  việc chuyển tiền luôn ở tiến trình chính. Hai loại thông báo mới
  (`goalAutoDeposited`, `goalAutoDepositFailed`). Sáu quyết định về việc *dừng
  đúng lúc* ở mục 3.12 `GOAL_FEATURE.md` — đọc trước khi đụng vào.
- **Nội dung giả trên trang danh sách đã dọn**: huy hiệu PREMIUM, câu "tăng
  12%", nút "Xem báo cáo", "Xem tất cả", dấu ba chấm trên thẻ — mục 3.11.
- **Khoản trích BÙ mang mốc của kỳ** (G20 đã đóng). `depositToGoal` nhận
  `occurredAt`, chặn **hai đầu** — không ở tương lai, không trước `startDate`.
  Nơi gọi duy nhất là `GoalAutoDepositRunner`; `GoalCubit` cố ý không phơi tham
  số ra. Chỉ cột `date` lùi lại, `updatedAt` vẫn là "bây giờ" vì nó là sổ sách
  đồng bộ — mục 3.14 `GOAL_FEATURE.md`.
- **Tên mục tiêu là DUY NHẤT trong phạm vi một tài khoản**, cùng ba lựa chọn với
  danh mục: so bằng `normalizeCategoryName()`, hàng xoá mềm **không** giữ chỗ,
  và chỉ kiểm khi tên thật sự đổi. Lý do không phải thẩm mỹ: `watchByGoal` còn
  nhánh dự phòng tra lịch sử bằng `LIKE` trên tên, nên hai mục tiêu trùng tên
  cùng nhận vơ những hàng cũ không mang `goalId`. Thi hành ở **client**;
  `/sync/push` và PostgreSQL chưa kiểm gì — mục 3.15.
- **`depositToGoal` kiểm số tiền ở tầng repository**: `> 0` và `≤ số dư ví
  nguồn`, đối xứng với `withdrawFromGoal`. Trước đó cả hai chỉ có ở ô nhập, tức
  nằm NGOÀI khối nguyên tử. Kèm theo `GoalCubit.addGoal` nay trả `String?` —
  trang tạo trước đây nuốt lỗi rồi vẫn báo "thành công" và đóng trang — mục 3.16.
- **Lặp lại mục tiêu sau khi hoàn thành**: app **chỉ nhắc**
  (`NotificationKind.goalCycleReady`), người dùng bấm "Bắt đầu vòng mới".
  `batDauVongMoi` đặt tiến độ về 0, gỡ cờ, dời hạn bằng `hanVongMoi` và đặt lại
  `startDate` — **không đụng một đồng nào**. Lời nhắc là loại thông báo RIÊNG vì
  khoá `goalDone:<id>` cố ý không có mốc thời gian; gộp chung thì từ vòng thứ
  hai trở đi không bao giờ hiện. Hai cột `recurrence`/`time_recurrence` vốn đã
  đồng bộ hai chiều, chết chỉ vì `GoalEntity` không mang chúng — mục 3.17.
- **Hai tab "Đang theo đuổi" / "Đã hoàn thành"** ở danh sách, cùng lối với Ngân
  sách. Thêm `GoalEntity.daHoanThanh` làm **định nghĩa duy nhất** của "đã xong",
  luật thông báo đổi sang gọi nó. `chiaMucTieu` cũng vá luôn chỗ
  `goalDao.watchAll` **không có `orderBy` nào** — mục 3.18.
- **Cột mốc tiến độ 25/50/75%** (2026-09-08). `NotificationKind` thứ **mười
  lăm**. Trước nó app chỉ lên tiếng ở 100% và khi chậm tiến độ. Báo **mốc cao
  nhất** đã vượt, một tin; khoá chống trùng theo khuôn `goalCycle:` chứ không
  `goalDone:` vì mục tiêu **lặp lại** phải được báo lại mỗi vòng; và luật phải
  đứng **TRƯỚC** phép kiểm `isBehindSchedule` — mục 3.21.
- **Thứ tự ưu tiên kéo thả** (2026-09-08, schema **v19**, cột `priority`). Số
  cách nhau **100**, `NULL` xếp **cuối**, trùng số rơi về `targetDate`. Chỉ tab
  "Đang theo đuổi" dùng nó. Payload mục tiêu nay **22 trường** (đếm lại 2026-09-08). Lần kéo đầu
  đánh số lại cả danh sách (mọi hàng đang `null`), từ lần sau chỉ ghi **một**
  hàng. ⚠️ `ReorderableListView` trả `newIndex` **lệch một ô** khi kéo xuống —
  `viTriThaThucTe` là chỗ duy nhất sửa. Khoảng trống chấp nhận được: **G25** —
  mục 3.22.
- **Ô ghi chú** cho mục tiêu. `null` là giữ nguyên, **chuỗi rỗng mới là xoá** —
  khác `cycleTakeMoney` (null = xoá) và giống `icon`/`colour` ở nửa đầu. Cột
  `note` đã đồng bộ sẵn, chỉ thiếu chỗ nhập — mục 3.19.
- **`doiSangBool()` ở nhánh kéo về** — dùng ở **cả bảy** chỗ đọc cờ đúng/sai:
  `goals.status_complete` (chuỗi `"True"`), `goals.recurrence`,
  `wallets.is_default`, `categories.is_default`, `categories.is_group`,
  `budgets.recurrence`, `bills.recurrence`.

  Backend không nhất quán ngay trong CÙNG một bảng: `Status_complete` là
  `VarChar(20)` còn `Recurrence` là `Boolean` thật. So khớp cứng từng kiểu thì
  chỉ cần một bên đổi cách tuần tự hoá là cờ lặng lẽ về `false` — không
  exception, không log. Hoá đơn nặng nhất: cột chuỗi cũ `recurrence` được **suy
  ra** từ cờ ấy, nên đọc sai một chỗ hỏng luôn cột thứ hai.

  ⚠️ Chỉ nới ở chỗ **ĐỌC**. Payload đẩy vẫn gửi đúng một dạng — nới cả hai đầu
  là mất luôn khả năng phát hiện khi hai phía lệch nhau.

- **Nhãn "(tự động)" trên dòng lịch sử tích luỹ** (2026-09-08, **schema không
  đổi, backend không phải làm gì**). Khoản do bộ chạy nền trích và khoản người
  dùng tự bấm vốn **giống hệt nhau trên mọi cột** — sự giống nhau ấy có chủ ý,
  vì nhờ nó mà phép đọc chiều tiền dùng chung được một tiền tố. Cách phân biệt
  là một **hậu tố** ghi chú `' (tự động)'`, đọc lại bằng `laKhoanTuDong` đòi đủ
  **cặp** tiền tố + hậu tố. Khoản cũ không có hậu tố nên đọc là "tay" và
  **không đoán ngược** — nhãn tự lành từ kỳ trích kế tiếp. Lý lẽ và ba phương
  án đã loại ở mục **3.25 `docs/GOAL_FEATURE.md`**; 16 test mới. Cuối ngày
  thêm **bộ lọc nguồn "Tay / Tự động"** cho bảng lịch sử (`LocNguon`, dải chip
  thứ ba, chỉ hiện khi có khoản tự động; khoản rút thuộc "Tay") — mục 3.24,
  9 test mới.
  > Kết luận trước đó — *"muốn phân biệt thì phải thêm cột mới"* — đã được ghi
  > vào tài liệu mà **chưa mở mã đọc**, và nó sai: có tới hai đường không cần
  > cột nào. Chỉ lộ ra khi người dùng hỏi lại.

⚠️ Ba lỗi ở vùng này **chỉ máy ảo Android mới lộ ra**: `ProviderNotFoundError`
trên route không có `WalletCubit`, màn đỏ do `DropdownButton` có `value` ngoài
`items`, và dấu hiển thị sai của khoản rút. Bộ test xanh cả ba lần.

### 📊 Trang Phân tích (2026-09-08) — **lát 2a và 2b xong**

**Đọc `docs/ANALYTICS_FEATURE.md` trước khi làm tiếp.** Tóm tắt:

- Trước 2026-09-08 trang này hiện **số giả** ở một tab điều hướng chính, kể cả
  tháng ("T6 2026" khi đang là tháng 9). Nay bố cục giữ nguyên theo Stitch, mọi
  con số đi qua `domain/thong_ke_thang.dart` (thuần, test bằng danh sách) →
  `AnalyticsRepositoryImpl` (gộp ba stream theo khuôn `watchBudgets`) →
  `AnalyticsCubit` (tháng lấy từ `clock`, `idaccount` từ phiên, không đoán).
- **`'transfer'` không phải thu, không phải chi**; biên tháng `[from, to)` mượn
  ngân sách; "% ngân sách" mượn `watchBudgets(now: mốc)` và **phải lọc**
  `isExpired`; danh mục không có ngân sách thì nhãn đổi thành "% tổng chi".
- "Số dư còn lại" = thu − chi của tháng, âm hiện âm; tháng trước bằng 0 → "Không
  có dữ liệu", không "tăng ∞%"; donut top‑4 + "Khác"; tháng rỗng nói rỗng.
- **Lát 2b (2026-09-08):** khối **"Xu hướng 6 tháng"** — hai đường thu/chi vẽ
  bằng **`fl_chart` ghim `1.2.0`**, đặt giữa khối tổng và donut. Chuỗi do
  `chuoiTheoThang()` dựng ở tầng thuần, **cũ nhất trước**, tháng rỗng giữ chỗ
  với số 0. Donut **vẫn** là `SweepGradient`, không viết lại. Khối này **lệch
  bản Stitch có chủ ý** — không màn nào trong 35 màn có biểu đồ đường/cột.
- 4 tệp test, **61 test**; **sáu** bản sai có chủ ý (biên đóng, bỏ lọc hết hạn,
  bỏ huỷ đăng ký, `watchAll` thay truy vấn kể cả xoá mềm, đảo thứ tự chuỗi,
  nhãn trục không lấy từ dữ liệu) mỗi cái làm đúng một test đỏ. Test 411dp bắt
  được tên danh mục tràn **521px** ở bản Stitch chép sang.
- ⚠️ Tầng vẽ của biểu đồ **không test được** — tooltip từng tràn khỏi màn hình
  và chỉ ảnh chụp máy ảo mới thấy (bẫy 4.9 `ANALYTICS_FEATURE.md`).

### 🔔 Hệ thống thông báo (2026-09-04) — **cả bảy lát xong**

**Đọc `docs/NOTIFICATION_FEATURE.md` trước khi làm tiếp.** Tóm tắt:

- Bảng `AppNotifications` (schema **v13**) — **CỤC BỘ, không đồng bộ**: không
  có trong `SyncEntityType`, không chạm `sync_payload_contract_test.dart`.
  Tên có tiền tố `App` vì `Notification` đụng lớp trong `flutter/widgets` —
  cùng loại va chạm với `Category`.
- Chống trùng nằm ở **tầng SQLite**: `UNIQUE(idaccount, dedupeKey)` +
  `insertOrIgnore`. Vuốt xoá là **xoá mềm** (`dismissedAt`) vì hàng chính là
  bản ghi khoá trùng.
- Bộ luật là hàm thuần, **GỌI** `BudgetEntity.isNearLimit` và
  `budgetHealthOf()` chứ không cài lại mốc 70/90.
- `NotificationScanner` nghe `SyncEngine.statusStream` (người tiêu thụ đầu
  tiên của stream này), **không** dùng `Timer.periodic`, và **không** được gắn
  ở `home_page.dart` vì chỗ đó gọi `start()` trong `build()`.
- **Đủ tám loại thông báo**: ngân sách (chạm ngưỡng / vượt hạn mức), hoá đơn
  (sắp đến hạn / quá hạn), mục tiêu (hoàn thành / trễ tiến độ), hệ thống
  (đồng bộ hỏng / ví âm).
- **Thông báo cấp hệ điều hành** chạy thật trên Android: kênh `flowmoney_alerts`,
  quyền xin **có ngữ cảnh** ở `/settings/notifications`, lịch nhắc hoá đơn đặt
  trước bằng `zonedSchedule`.
- **Trang cài đặt** `/settings/notifications`: công tắc tổng + bốn công tắc
  nhóm + giờ nhắc + số ngày nhắc, lưu trong `FlutterSecureStorage` theo từng
  `idaccount`.
- **Toast nổi ở đáy** (`AppToast`, trước là `ConnectionBanner`) bọc ngoài
  router qua `MaterialApp.builder`: mất mạng, có mạng lại, kết quả đồng bộ, và
  **sự kiện thời gian thực** (thêm 2026-09-09). Thứ tự ưu tiên: **đồng bộ >
  realtime > kết nối**, và **một nguồn luôn được cập nhật chính nó**.

⚠️ `NotificationScanner.stop()` gọi `cancelAll()`. Lịch nằm trong
AlarmManager/UNUserNotificationCenter chứ không trong SQLite, nên
`purgeDataForOtherAccounts` không cứu được — nhắc hoá đơn của người đăng nhập
trước sẽ nổ trên màn hình khoá của người sau.

⚠️ **`flutter test` xanh KHÔNG đủ cho vùng này.** Bốn lỗi dưới đây chỉ lộ ra
khi chạy trên máy ảo Android, và cả bốn đều để bộ test xanh:

| Lỗi | Vì sao test không thấy |
|---|---|
| Bấm thông báo ngân sách → **app chết màn đỏ** | `/budget` nằm trong `StatefulShellRoute` còn `/notifications` ở ngoài; `push` dựng shell thứ hai → trùng page key. Cần cây route thật mới nổ |
| Ba chỗ **tràn bố cục** (21px, 3,9px, 0,315px) | Bộ test chạy Chrome ở 1280px, rộng gấp ba lần chỗ bắt đầu tràn |
| Dải báo kết nối **đè lên tiêu đề và chuông** | Chỉ thấy khi có `Scaffold` thật bên dưới |
| Dải "đã đồng bộ" **bị ghi đè** | Cả hai stream đều đúng; chỉ **thứ tự thực tế** mới lộ (đồng bộ xong sau 0,4 giây, dải kết nối báo ở giây thứ 3) |

Chạy máy ảo: `flutter build apk --debug` → `adb install -r` →
`adb shell am start -n com.flowmoney.flowmoney/.MainActivity`. `adb` không nằm
trong PATH, đường dẫn đầy đủ ở
`%LOCALAPPDATA%/Android/Sdk/platform-tools/adb.exe`.

### 🧾 Hoá đơn (2026-09-04) — đã vá bảy lỗi chặn

Hoá đơn tạo từ app trước đây **không bao giờ lên tới backend** (`Idwallet` và
`Idcategory` NOT NULL nhưng form không ghi). Xem `docs/bill/BILL_DOCUMENTATION.md`
(thư mục bị `.gitignore` chặn, chỉ có trên máy). Điểm cần nhớ:

- Đường **sửa** hoá đơn dùng `BillDao.updateFields`, **không** đi qua `insert`
  (`insertOrReplace` thay cả hàng — từng biến hoá đơn đã trả thành chưa trả).
- Nguồn sự thật của chu kỳ là `isRecurrence` + `timeRecurrence`; cột chuỗi cũ
  `recurrence` chỉ được suy ra từ chúng.
- `nextBillDueDate` neo vào **ngày gốc** (`Bills.anchorDay`, v18) và kẹp khi
  tháng đích ngắn hơn. Quy tắc "đoán cuối tháng" đã BỎ ngày 2026-09-08 — xem
  mục "Ngày gốc" tài liệu bill.
- `BillDao.markOverdue` ghi có điều kiện `payStatus = 'Pending'`; bỏ điều kiện
  đó là tạo vòng lặp đẩy vô tận.

### ❌ Chưa làm / Tiếp theo
- Analytics: lát **2a và 2b xong 2026-09-08** (số thật, rồi biểu đồ xu hướng 6 tháng bằng `fl_chart`), **2c‑1, 2c‑1b và 2c‑2 xong 2026-09-09** (trang Xuất báo cáo đọc số thật; màn Xem trước mười khối theo chuẩn app thị trường; nút Tải xuống sinh tệp PDF/CSV thật và lưu vào thư mục Tải về; 10 tệp test, **170** test) — mảng Phân tích **đã xong**, `docs/ANALYTICS_FEATURE.md` mục 7
- AI chat integration hoàn chỉnh
- Tích hợp ngân hàng phía client (backend dùng SePay thay Casso từ 2026-09-07; màn duyệt giao dịch ngân hàng chưa có — G26)
- Build production / deploy

---

## 15. Cách chạy dự án (Local Development)

```bash
# Terminal 1 — Backend
cd d:\test_kltn\ManagementFinance\src\Backend
npm run dev
# → http://localhost:3000

# Terminal 2 — Prisma Studio (optional, xem DB)
cd d:\test_kltn\ManagementFinance\src\Backend
npx prisma studio
# → http://localhost:5555

# Terminal 3 — Flutter Web
cd d:\test_kltn\ManagementFinance\src\Client-app
flutter run -d chrome --web-port 9090
# → http://localhost:9090
```

**Environment**: `.env` file tại `src/Backend/.env` chứa `DATABASE_URL` và `DIRECT_URL` trỏ tới PostgreSQL local (`PersonFinance` database, port 5432).
