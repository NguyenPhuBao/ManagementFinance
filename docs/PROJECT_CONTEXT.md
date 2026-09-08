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
- Tích hợp AI chat, kết nối ngân hàng (Casso)

---

## 2. Cấu trúc thư mục

```
ManagementFinance/
├── src/
│   ├── Backend/          ← Node.js + Express + Prisma + PostgreSQL
│   └── Client-app/       ← Flutter (Web/Mobile, Dart)
├── docs/
│   └── superpowers/
│       ├── backend/
│       │   └── New_Database.md   ← Schema chuẩn PostgreSQL (nguồn sự thật)
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

> Schema chuẩn xem tại: `docs/superpowers/backend/New_Database.md`
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
| `bank_account` | Tài khoản ngân hàng (Casso) | String UUID |
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
| `GET/POST /api/bank/*` | Tích hợp Casso |

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
3. Khi token hết hạn → auto-refresh qua `/api/auth/refresh`
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
│   └── bank/         ← Casso integration
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
| `src/Backend/modules/sync/sync.repository.js` | Prisma queries cho sync |
| `src/Backend/modules/sync/sync.service.js` | Business logic sync |
| `src/Backend/prisma/schema.prisma` | DB schema (Prisma) |
| `docs/superpowers/backend/New_Database.md` | DB schema chuẩn (nguồn sự thật) |

---

## 14. Trạng thái hiện tại (cập nhật cuối 2026-09-07)

### 🔐 Xác thực phiên đăng nhập

`checkAuthStatus()` **chỉ** kiểm tra chuỗi token có rỗng hay không — không gọi mạng, không giải mã JWT, không kiểm hạn. Vì vậy có thêm một bước xác minh thật:

- **`AuthRepository.verifySession()`** gọi `GET /auth/profile` — endpoint **duy nhất** thật sự truy vấn CSDL. Cố ý **không** dùng `/auth/me` vì endpoint đó chỉ echo lại payload JWT nên vẫn trả 200 cho tài khoản đã bị xoá.
- Trả về `SessionStatus { valid, invalid, unknown }`. Chỉ **401/404** mới là `invalid`; mọi mã khác kể cả 5xx và mất mạng đều là `unknown` → **không** đăng xuất, giữ cam kết offline-first.
- Việc phân loại lỗi nằm ở **repository**, không phải bloc, vì dự án có **hai class `NetworkException` trùng tên** ở hai file khác nhau — bắt lỗi theo kiểu ở tầng trên rất dễ import nhầm.
- Hai đường phát hiện phiên chết: **lúc mở app** (`_onAuthCheckRequested`) và **đang chạy** (tín hiệu `sessionInvalidStream` từ SyncEngine khi đẩy dữ liệu vỡ khoá ngoại `fk_*_account`).
- `purgeDataForOtherAccounts(idAcc)` xoá dữ liệu cục bộ của tài khoản khác (giữ nguyên danh mục mặc định `idaccount = 0`). Chạy ở **cả hai** đường vào: đăng nhập (`auth_bloc.dart:106`) và khôi phục phiên lúc mở app (`auth_bloc.dart:134`).
- **Không còn fallback `?? 1` ở bất kỳ đâu** — `idaccount = 1` là tài khoản admin THẬT, không phải giá trị "chưa biết". Đã gỡ khỏi AuthBloc, `sync_engine.dart` (6 chỗ, G8) và 4 trang UI của bill/goal (G4, nay dùng `core/auth/current_account.dart` trả `int?`).

### ✅ Đã hoàn thành
- Schema PostgreSQL aligned với New_Database.md (migration đã apply)
- SQLite schema (Drift) aligned với backend schema — `schemaVersion = 12`
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
- **Không còn `?? 1` ở bất kỳ đâu**: `_collectPendingOps` dùng thẳng tham số `idaccount` *(G8)*, và 4 trang UI đổi sang `core/auth/current_account.dart` trả `int?` *(G4)*
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
- **Hoá đơn: tự động thanh toán** (2026-09-06 chiều, **schema v17**). Người dùng chọn bản đầy đủ thay vì nút "Trả ngay"; ba lựa chọn đã chốt: trừ từ **ví thanh toán của hoá đơn** (một cột cục bộ `bills.autoPayEnabled`, không cần cột ví hay "lần chạy cuối" — mỗi kỳ là một hàng, cờ đã trả là chốt chống trả hai lần), mở app muộn thì **trả bù trần 3 kỳ/hoá đơn/lượt**, trả **bất kỳ lúc nào trong ngày đến hạn**. `BillAutoPayRunner` chạy trong `NotificationScanner.scan()` sau `markOverdue` và trước khi nạp hoá đơn, đi qua `payBill` hiện có với `occurredAt = dueDate` (khoản bù mang ngày của kỳ) nên hoàn tác vẫn chạy. Hai loại thông báo `billAutoPaid`/`billAutoPayFailed` nhóm `bill`, khoá theo kỳ, `createdAt` = lúc quét. Công tắc **tắt sẵn** trên cả hai form kèm dòng phụ "chỉ nên bật trên một thiết bị" — cột cục bộ nên hai máy cùng bật, cùng offline là **hai** khoản chi; đóng hẳn cần việc D phía backend. Đã kiểm trên máy ảo: hoá đơn hạn hôm nay được trả ngay ở lượt quét sau khi lưu, thông báo và PostgreSQL khớp. Spec: `docs/superpowers/specs/2026-09-06-bill-auto-pay-design.md` (thư mục bị gitignore, đã `git add -f`)
- **Hoá đơn: ngày trả, ghi chú lần trả, trang chi tiết** (2026-09-06 tối, `77a70bc`…). Năm việc chốt sau khi so với Money Lover/Wallet, làm theo thứ tự: (1) tab "Đã thanh toán" ghi "Trả dd/MM/yyyy" từ khoản chi (`BillLoaded.payments`, không đoán khi thiếu) và chạm mở `TransactionDetailSheet`; (2) bảng thanh toán hỏi **ngày trả** (chặn tương lai) → `payBill(occurredAt:)`; (3) **trang chi tiết `/bills/:id`** với "Lịch sử các kỳ" theo `generatedFromBillId` (`chuoiKyCua`), nút trả/hoàn tác/sửa/xoá, mở từ dòng chưa trả; (4) "bỏ qua kỳ này" **chưa làm**, viết việc E xin backend nhận `Pay_status = 'Skipped'`; (5) ghi chú riêng mỗi lần trả nối SAU tiền tố `kGhiChuTraHoaDon`. Nhãn/màu trạng thái và ba luồng thao tác tách ra `widgets/bill_status_visuals.dart`, `widgets/bill_actions.dart`. **Bẫy đắt nhất:** `watchBills().asyncMap(...)` dưới FakeAsync nuốt `done` → `bloc.close()` treo → widget test đứng 10 phút/test; đã thay bằng `emit.onEach` + đọc riêng (mục 6.6 `BILL_DOCUMENTATION.md`)
- **Bảng thanh toán hoá đơn bố cục lại theo ý người dùng** (2026-09-06 tối): khối thông tin hoá đơn ở trên, dưới cùng một nút "Thanh toán bằng <ví của hoá đơn>" kèm "Chọn ví khác" (ví mặc định = ví của hoá đơn → ví có cờ mặc định → ví đầu danh sách), thay cho danh sách ví phải chọn; khối thông tin sau đó mở rộng đủ như trang chi tiết (trạng thái, còn/quá hạn N ngày, kỳ, chu kỳ, danh mục, ví, nhắc trước, tự trả, ghi chú) vì người dùng thấy bản đầu "khá ít". Đã xem trên máy ảo 411dp
- **Thông báo: sáu việc sửa sau một lần kiểm toàn diện** (2026-09-06 tối muộn). Bản kiểm so hệ thống hiện có với Money Lover, MISA, YNAB, Rocket Money và Monarch; sáu chỗ hỏng được sửa, xếp theo mức nghiêm trọng:
  1. **Vòng quét bị buộc vào một sự kiện MẠNG trong một app offline-first** (`6b8194b`). `NotificationScanner` chỉ quét khi `SyncEngine` phát trạng thái `isTerminal`, nhưng khi mất mạng `_runSync()` thoát sớm ở `SyncStatus.pending` — **không** phải trạng thái kết thúc. Cả một phiên offline vì thế không sinh thông báo nào, `markOverdue` không chạy, và vì hai bộ tự chuyển tiền nằm **bên trong** `scan()` nên **hoá đơn bật tự trả cũng không được trả**. Nay có ba mốc, hai trong ba không cần mạng: `start()` quét ngay, `AppLifecycleState.resumed`, và mốc đồng bộ cũ. Nguồn vòng đời là `core/notification/app_lifecycle_watcher.dart` — file duy nhất trong vùng này chạm `WidgetsBinding`
  2. **Chạm thông báo hệ điều hành không đi đâu cả** (`72c86ef`) — `onDidReceiveNotificationResponse` là callback **rỗng**. Nay `deeplinkTuDedupeKey()` suy route từ chuỗi khoá (bản sao có chủ ý của cột `deeplink`, vì ở **cold start** hàng chưa tồn tại trong SQLite), `NotificationTapRouter` là nơi duy nhất điều hướng, chặn trùng đúng một lần khi Android đẩy cùng cú chạm bằng cả hai đường, và **giữ lại** cú chạm nếu chưa đăng nhập. `FlowMoneyApp` thành `StatefulWidget` — tiện thể sửa một lỗi sẵn có: `createRouter()` bị gọi trong `build()` nên mỗi lần dựng lại là một `GoRouter` mới
  3. **Tắt nhóm làm im luôn cảnh báo tiền rời ví** (`dfb8721`). Bốn loại `billAutoPaid`/`billAutoPayFailed`/`goalAutoDeposited`/`goalAutoDepositFailed` nay đi qua `luonBao()` bất kể công tắc nhóm — "đừng nhắc tôi hoá đơn sắp tới hạn" và "đừng cho tôi biết app vừa rút tiền của tôi" là hai câu khác nhau. Lối thoát vẫn là công tắc tổng
  4. **Giờ im lặng, gộp thông báo Android, hoàn tác vuốt xoá** (`8c91c32`, schema không đổi). Giờ im lặng **tắt sẵn**, lưu bằng số phút từ nửa đêm nên khoảng vắt qua nửa đêm đúng; chỉ chặn bước bắn ra ngoài. Gộp: `khoaNhom` + bản tóm tắt id **âm** (`osScheduledId` luôn trả 0..2³¹−1), **chỉ Android**. `NotificationDao.khoiPhuc()` + SnackBar hoàn tác — cần thiết vì hàng đã xoá vẫn giữ chỗ chống trùng nên vuốt nhầm là mất vĩnh viễn
  5. **Công tắc quyền nói dối** (`0a4d3c2`). Quyền bị thu hồi trong Cài đặt máy thì công tắc vẫn sáng. `OsNotifier.daCoQuyen()` là câu **hỏi**, khác câu **xin**; hiển thị là `osBat && _coQuyenOs` nhưng `osBat` trong kho **giữ nguyên**, nên cấp lại quyền là chạy lại ngay
  6. **Một dòng nhật ký cho mỗi lượt quét** (`63a043e`) — trước đó vòng quét im lặng hoàn toàn, không phân biệt được "đã quét, không có gì" với "không quét lần nào"
  > Đã kiểm trên `emulator-5554`: quét chạy trong chế độ máy bay, chạm thông báo mở đúng màn cho cả route trong shell (`go`) lẫn ngoài shell (`push`), hoàn tác đưa hàng trở lại, công tắc quyền đúng cả hai chiều. **Việc còn lại phần lớn là thuần client** — bảng `AppNotifications` cục bộ và không nằm trong `SyncEntityType`, nên chỉ có cảnh báo giao dịch ngân hàng/OCR (kênh Socket.io chưa xác thực) và thông báo bảo mật là thật sự chờ backend
- **Thông báo: ba việc treo cuối cùng nay đã nhìn tận mắt** (2026-09-07, chỉ kiểm và cập nhật tài liệu, không đổi mã). (1) **`khoaNhom`** — bằng chứng quyết định là bảng nhóm→tóm tắt của hệ điều hành trỏ vào bản tóm tắt **id −1 của app**, tức nhóm do app cầm chứ không phải `AUTOGROUP_SUMMARY` của Android 16; `mSoundNotificationKey` trỏ về thông báo thật nên `GroupAlertBehavior.children` chạy đúng. (2) **Nổ khi app đóng hoàn toàn** — tiến trình bị `am kill`, `pidof` rỗng, rồi `ActivityManager: Start proc … for broadcast {…ScheduledNotificationReceiver}` với **0 dòng `I/flutter`**. (3) **Giờ im lặng** có đối chứng: cùng luật `walletNegative`, bật thì 2 hàng vào app / **0** thông báo hệ điều hành, tắt thì 1 hàng / **1** thông báo. Ba cái bẫy mới ghi vào `NOTIFICATION_FEATURE.md` mục 8: lịch dùng `inexactAllowWhileIdle` có **cửa sổ trễ 1 giờ** nên nhảy đồng hồ tới đúng giờ hẹn thì **không nổ**; `am force-stop` huỷ sạch lịch nên phải dùng `am kill`; và trước khi nhảy đồng hồ phải đối chiếu mốc ấy với hạn hoá đơn + kỳ trích mục tiêu, vì `scan()` chạy ngay khi app quay lại tiền cảnh (tổng số dư trước/sau đều 8.890.081đ)
- **Thông báo: cảnh báo số dư ví thấp, và ví nợ ra khỏi cảnh báo ví** (2026-09-07, `80fa0cb` + `2a88dc6`, **schema không đổi**). Trước bản này app chỉ báo khi ví đã **âm** — tức là đã muộn. Loại thứ 14 `walletLowBalance`, nhóm `system`, khoá theo ngày như `walletNeg`. Ngưỡng là `NotificationPrefs.nguongSoDuThap` (đơn vị đồng, **cục bộ**, không đồng bộ), và **`0` vừa là ngưỡng vừa là công tắc**: một cặp công tắc-cộng-số biểu diễn được trạng thái vô nghĩa "bật nhưng ngưỡng bằng 0", còn một con số thì không. Mặc định `0` để mọi bản ghi có sẵn — vốn đều thiếu trường này — rơi về **tắt**, cùng lý lẽ với giờ im lặng. Giao diện là **danh sách chọn sẵn** (Tắt · 50k · 100k · 200k · 500k · 1tr · 2tr) chứ không phải ô nhập tiền, theo đúng lý lẽ đã ghi sẵn ở `_hangSoNgay`: gõ tay mở đường cho những giá trị mà `NotificationPrefs` lặng lẽ quy về `0`, và người dùng chỉ thấy con số của mình biến mất. **Đổi hành vi có chủ ý:** ví loại `debt` nay không sinh cảnh báo ví nào cả, kể cả `walletNegative` — ví nợ mang số dư âm là đúng bản chất của nó, trước đây nó bị nhắc lại mỗi ngày cho tới khi trả hết nợ. Thứ tự loại trừ trong `_walletCandidates` là thứ giữ cho mỗi ví ra **một** thông báo: số dư âm cũng thoả điều kiện "dưới ngưỡng". Đã xem trên `emulator-5554` ở 411dp
- **Kiểm lại danh sách việc thông báo còn lại** (2026-09-07). Một mục hoá ra **đã xong từ trước**: "ngưỡng cảnh báo ngân sách chỉnh được" — giao diện có sẵn ở `budget_form.dart:320-346`, nạp/lưu/kiểm hợp lệ đủ, vào được từ `/budget/rules` cả khi tạo lẫn khi sửa, và có `budget_form_threshold_zero_test.dart`. Con số "cứng 70/90%" mà danh sách nhắc tới là **thang màu** `_cautionAt`/`_criticalAt` ở `budget_visuals.dart`, do người dùng chốt 2026-09-04 và cố ý toàn cục — hai việc khác nhau bị gộp nhầm. ⚠️ **Đính chính 2026-09-07 (chiều):** bản trước của dòng này viết rằng khoá chống trùng dùng `budgetHealthOf().name` là "một chỗ hỏng chưa ai ghi" — **sai cả hai vế**. Việc leo lên một bậc mới sinh thêm thông báo là **thiết kế có chủ ý** và có test canh (`notification_rules_test.dart`, ca *"ĐỔI khi leo lên một bậc mới"*), với lý lẽ *"mỗi bậc được nhắc đúng một lần trong kỳ; không phân biệt bậc thì người dùng chỉ được báo ở mốc 70% rồi im lặng cho tới lúc vượt hẳn"*. Vế "không test nào phủ ngưỡng dưới 70%" cũng sai: chính ca test ấy dùng `nguongPhanTram: 60` (dòng 131–134). Bài học: mã sản phẩm cho biết code **làm gì**, chỉ test mới cho biết nó **định làm gì** — đọc mã test trước khi kết luận là lỗi
- **Danh mục mặc định thành bản sao riêng của từng tài khoản** (2026-09-07, `2c1055e`…`5120b16`, **schema không đổi**). Trước đây mọi tài khoản dùng chung 18 hàng mặc định của backend; chúng không đồng bộ và không thuộc về ai, nên người dùng **không sửa, không đổi tên, không xoá** được. Nay `DefaultCategorySeeder` chạy **sau mỗi lần pull** và tạo bản sao cho từng danh mục mặc định mà tài khoản **chưa từng** có bản cùng (tên chuẩn hoá, `classify`) — **tính cả hàng đã xoá mềm**. Ba chữ ấy là khác biệt **duy nhất** với `ensureMissing()` cũ, thứ đã sinh ra G16; bỏ chúng đi là danh mục vừa xoá mọc lại ở mỗi lần mở app. Bản sao mang `isDefault = false`, UUID mới, giữ icon/màu, **chép cả từ khoá**, và **không** kế thừa nhóm. Dữ liệu cũ trỏ vào bản mặc định được **dời trước**, ẩn sau (lỗi 11.6). Năm truy vấn hiển thị bỏ nhánh `idaccount = 0`; **`getNamesInUse` vẫn đếm** hàng mặc định (quy tắc trùng tên) và **`purgeDataForOtherAccounts` vẫn giữ** chúng (đó là cái khuôn). `foldIntoBackendDefaults()` bị gỡ vì chạy ngược chiều. Từ khoá nay **đẩy được lên backend** — cột `Keyword` và `/sync/push` đã sẵn từ trước, thiếu đúng payload phía client. **G10 đóng theo** mà backend không phải làm gì. Đã kiểm trên `emulator-5554`: tạo 13 bản sao, đẩy `36/36 succeeded`, server có 15 danh mục riêng kèm từ khoá, bộ mặc định vẫn nguyên 18. ⚠️ Máy ảo bắt được một lỗi mà bộ test không thấy: sau khi seed **không ai hẹn đồng bộ**, hàng nằm `pending` tới lần khởi động nguội sau — đã sửa (`5120b16`). ⚠️ Hai giới hạn còn: bản sao chỉ đầy đủ khi **bộ mặc định cục bộ** đầy đủ (pull tăng dần — server 18, máy kiểm tạo 13), và **màu không có cột trên server** (`CATEGORY_COLOUR_COLUMN.md`)
- **Trung tâm thông báo: lọc, phân trang, đánh dấu chưa đọc** (2026-09-07 tối, **schema không đổi**, chỉ hai file mã). Trước bản này trang `/notifications` đọc thẳng `watchFeed(idaccount)` với mặc định 50 hàng và không có bộ lọc nào — thông báo thứ 51 không xem lại được trong khi bảng giữ dữ liệu 90 ngày. Nay `watchFeed` nhận thêm `kinds` và `chiChuaDoc`, trang có dải sáu chip (Tất cả · Chưa đọc · Hoá đơn · Ngân sách · Mục tiêu · Hệ thống) cuộn ngang, tải 20 hàng một lần kèm nút "Tải thêm", và **nhấn giữ** một mục để đảo cờ đã đọc — đường quay lại cho nút "Đọc tất cả", vốn đọc hộ cả những mục người dùng chưa kịp xem. Lý do của từng quyết định (vì sao DAO nhận `List<String>` chứ không phải `NotificationGroup`, vì sao `null` khác danh sách rỗng, vì sao không dùng truy vấn `COUNT`) ở **mục 4.6 `docs/NOTIFICATION_FEATURE.md`**. Đã xem trên `emulator-5554` ở 411dp: dải chip không tràn và cuộn tới được cả sáu, lọc "Hoá đơn" thu 6 mục xuống 2, nhấn giữ đảo đúng cả hai chiều. ⚠️ **Phân trang chưa nhìn tận mắt** — tài khoản kiểm thử chỉ có 6 thông báo còn trang đầu tải 20, nên nút "Tải thêm" không có cớ xuất hiện; nó chỉ được phủ bằng widget test. ⚠️ Bẫy mới, đã ghi vào **7.10 mục 4**: `longPress` kích hoạt luôn `onTap` khi widget chưa có `onLongPress`, nên một test nhấn giữ chỉ kiểm trạng thái CSDL có thể **xanh giả**
- **Thông báo: nhắc ghi chép hằng ngày** (2026-09-07 tối, **schema không đổi**). Loại nhắc duy nhất trong app suy từ việc **không có** dữ liệu — và cố ý **không phải** một `NotificationKind` nào cả. (Lúc viết dòng này bảng có 14 loại; từ 2026-09-08 là **15** sau khi thêm `goalMilestone` — con số đổi, lý lẽ dưới đây thì không.) Lý do: mười bốn loại kia là *bản ghi* một việc đã xảy ra và người dùng đọc lại chúng trong trung tâm thông báo, còn lời nhắc này chỉ có nghĩa khi họ **đang không mở app**; lúc mở ra xem thì nó đã hết lý do tồn tại. Nên nó **không sinh hàng nào** trong `AppNotifications` và sống hoàn toàn trong `ReminderScheduler` — nguồn ứng viên **thứ ba** bên cạnh hoá đơn và mục tiêu. Mỗi lượt `resync()` đặt **ba lịch rời** (hôm nay + hai ngày kế) vào giờ người dùng chọn, **bỏ qua hôm nay nếu đã có giao dịch**. Ba lịch rời chứ không phải một lịch lặp `DateTimeComponents.time`: lịch lặp chỉ tốn một suất nhưng **không bỏ qua được ngày nào**, nên nó nhắc cả những hôm người dùng đã ghi rồi. Ba ngày vì trần 50 tính trên **tổng ba** nguồn và phép cắt sắp theo thời gian — lịch hằng ngày luôn gần nhất nên nó *thắng* nhắc hoá đơn, mà hoá đơn là tiền còn nhắc ghi chép là thói quen. Đầu vào mới: `TransactionDao.getLastTransactionDate()`; `null` = chưa từng ghi = **vẫn nhắc**. Ba trường mới trong `NotificationPrefs` (**cục bộ**, không đồng bộ), **mặc định TẮT**, giờ **riêng** mặc định **20:00** — không dùng chung `gioNhac` (08:00, của hoá đơn), và giờ im lặng **không chặn** nó. Chạm vào mở thẳng **`/add`**. Lý do đầy đủ ở **mục 4.7 `docs/NOTIFICATION_FEATURE.md`**. 28 test mới. **Đã đo trên `emulator-5554`** (đồng hồ máy ảo 21:34): bật → đúng hai lịch 20:00 cho 08/09 và 09/09, lịch hôm nay bị bỏ vì đã trôi qua; tắt → cả hai biến mất; bật lại → cả hai trở về; bốn lịch hoá đơn 08:00 nguyên vẹn suốt ba lượt. ⚠️ **Đổi tuỳ chọn không đặt lại lịch ngay** — lịch chỉ theo kịp ở lượt quét sau; đây là hành vi **có sẵn**, đúng vậy với `gioNhac` từ trước, nhưng trên máy thật nó trông hệt một lỗi
- **Thông báo: nút hành động trên thông báo hệ điều hành** (2026-09-07 tối, **schema không đổi**). Hai nút trên nhắc hoá đơn: **"Trả ngay"** mở thẳng trang chi tiết hoá đơn ấy, **"Hoãn 1 ngày"** dời lịch 24 giờ **hoàn toàn trong isolate nền**, không mở app. ⚠️ **Cố ý KHÔNG có nút "Đã trả"**: `payBill` chuyển tiền thật (tạo giao dịch, trừ ví), và chạy nó trong isolate nền là chuyển tiền ở nơi không có giao diện, không xác nhận ví, không chỗ báo lỗi — đi ngược đúng nguyên tắc đã chốt cho hai chỗ tự chuyển tiền còn lại. Ai muốn một chạm là trả thì đã có `autoPayEnabled`. Mọi phép quyết định nằm ở `notification_actions.dart` (file thuần, không import plugin — bẫy 7.7 cộng với việc `flutter test` không dựng được isolate nền). Lý do đầy đủ ở **mục 4.8 `docs/NOTIFICATION_FEATURE.md`**. 23 test mới.
  > **Ba lỗi chỉ máy thật mới thấy, cả ba đều im lặng** — đây là ví dụ mạnh nhất từ trước tới nay cho quy tắc "đụng giao diện/điều hướng thì phải chạy máy ảo":
  > 1. **Thiếu `ActionBroadcastReceiver` trong `AndroidManifest.xml`.** Nút hiện đúng, `dumpsys notification` báo `actions=2` với `PendingIntent` đúng kiểu, nhưng không tiến trình nào nhận. Plugin **không tự khai báo** receiver này. Nay có `android_manifest_receivers_test.dart` canh **cả ba** receiver — vùng mà `flutter test`, `flutter analyze` và `flutter build apk` đều không nhìn thấy. Xem bẫy **7.11**.
  > 2. **`resync()` huỷ mất lịch vừa hoãn.** Lý lẽ "cùng khoá nên sống sót" **sai**: nhánh bỏ qua ấy chỉ chạy cho lịch resync *muốn*, mà hoá đơn chỉ được muốn khi mốc nhắc còn ở tương lai — trong khi chỉ hoãn được **sau khi** thông báo đã nổ. Sửa bằng tập `khongHuy` trong `resync()`.
  > 3. **"Trả ngay" ở cold start mở nhầm danh sách.** Một cú bấm có **hai** đường vào; `payloadKhoiDong()` đọc `payload` mà bỏ qua `actionId`. Nay cả hai gọi chung `khoaSauChamNut()`.
- **Thông báo: badge số trên icon app** (2026-09-08, **schema không đổi**). `BadgeUpdater` nghe `watchUnreadCount` rồi đẩy sang `OsNotifier.datBadge()`; `NotificationScanner` **sở hữu** vòng đời của nó (`auth_bloc` đã có bốn chỗ start/stop, một lối song song là bốn chỗ nữa phải nhớ). Hai method mới trên interface: `activeIds()` và `datBadge()`. ⚠️ **Huỷ CHỌN LỌC, tuyệt đối không dọn sạch khay**: chỉ huỷ id suy từ `dedupeKey` của hàng đã đọc/đã xoá mềm, vì lịch hoá đơn nổ lúc app đóng và nhắc ghi chép hằng ngày **nằm trên khay mà bảng không biết** — số chưa đọc bằng 0 KHÔNG có nghĩa là khay phải trống. Và **không bao giờ `cancelAll()`**: nó cuốn theo cả lịch đang chờ trong AlarmManager. Lý do đầy đủ ở **mục 4.9 `docs/NOTIFICATION_FEATURE.md`**. 11 test mới.
  > ⚠️ **Đo trên máy thật đã sửa lại chính lời hứa ban đầu:** con số **gần như không bao giờ hiện trên Android** — nó nằm trên bản tóm tắt nhóm, mà Android **tự gỡ bản tóm tắt khi nhóm chỉ còn một thông báo con**, và một là số lượng thường gặp nhất. Khay trống thì `datBadge(6)` chạy trót lọt mà không hiện gì cả. Nên trên Android badge thực chất là **chấm**, suy từ *thông báo đang trên khay* chứ không từ số chưa đọc; con số chỉ có nghĩa cho iOS và cho launcher nào vẽ được. Phần người dùng thấy vẫn đúng: **đọc hết trong app thì chấm tắt**.
  > **Bằng chứng** (`emulator-5554`, Pixel Launcher): tạo hoá đơn tuần hạn 10/09 → `[BadgeUpdater] badge=7, khay=2, đã huỷ=0` và **icon có chấm**; bấm "Đọc tất cả" → `badge=0, khay=1, đã huỷ=1`, `dumpsys notification` còn **0** record của app, **chấm tắt**.
  > Bài học kèm theo: `catch` **câm** ở `dongBo()` suýt dẫn tới kết luận sai rằng code không chạy — mất một vòng dựng lại APK. Nay nó ghi `debugPrint`, và chính dòng log ấy phân định được "không chạy" với "chạy đúng nhưng Android không vẽ".
- **Mục tiêu: thông báo cột mốc 25/50/75%** (2026-09-08, **schema không đổi**). Trước bản này app chỉ lên tiếng về một mục tiêu ở **hai** thời điểm — đạt 100% (`goalCompleted`) và chậm tiến độ (`goalBehind`) — nên người dùng đi ba phần tư chặng đường mà không được ghi nhận gì. `goalMilestone` là `NotificationKind` **thứ mười lăm**. Ba quyết định: vượt nhiều mốc cùng lúc thì chỉ báo **mốc cao nhất** (nạp một phát từ 10% lên 80% vượt cả ba; ba tin cho một thao tác là ồn); khoá chống trùng theo khuôn `goalCycle:` **chứ không** khuôn `goalDone:` vì mục tiêu **lặp lại** phải được báo lại mỗi vòng; và luật phải đứng **TRƯỚC** phép kiểm `isBehindSchedule`, nếu không chỉ mục tiêu đang trễ mới được ghi nhận quãng đã đi. Lý do đầy đủ ở **mục 3.21 `docs/GOAL_FEATURE.md`**. 10 test mới.
  > Dựng **bản sai có chủ ý** để kiểm cái bẫy thứ ba (dời luật xuống sau `isBehindSchedule`): **3 test đỏ**. Test xanh sẵn không chứng minh gì — đây là lần thứ năm kỹ thuật này đáng công trong dự án.
  > ⚠️ Hai test cũ phải sửa, và **cả hai đều là lưới an toàn hoạt động đúng**: phép canh *"phủ đủ cả 14 loại"* của `notification_deeplink_test` đỏ vì nay có 15 (và phải dựng thêm một mục tiêu 50% — hàng 20% cũ không sinh cột mốc); còn *"đi đúng nhịp thì im lặng"* dùng `expect(ra, isEmpty)` cho một mục tiêu **70%**, tức một phép canh **rộng hơn** điều nó muốn nói. Thu hẹp về đúng `goalBehind` thay vì nới luật.
  > **Đã kiểm trên `emulator-5554`**: `dumpsys notification --noredact` cho `android.title=(Đã đi được 50% chặng đường)` trên mục tiêu `MuaXe` 1.101.000/2.000.000 = 55%.
- **Mục tiêu: thứ tự ưu tiên kéo thả** (2026-09-08, **schema v19**). Danh sách vốn sắp cứng theo hạn gần nhất nên người dùng không nói được *"quỹ khẩn cấp quan trọng hơn cái laptop"*. Cột `Priority Int?` phía backend có từ 2026-09-07 — đây là việc **duy nhất** mà backend đã làm xong phần của họ mà client chưa nhận. Quy ước giá trị lấy **nguyên** từ `DA-XONG/2026-09-05-backend-goal-priority.md` mục 4, không phát minh lại: số **cách nhau 100**, `NULL` xếp **cuối**, trùng số rơi về `targetDate`. `uuTienSauKhiKeo` có **hai chế độ** — còn khe thì ghi **một** hàng, hết khe hoặc còn hàng `null` thì đánh số lại cả danh sách; lần kéo đầu luôn rơi vào chế độ hai và đó là *một* lần trong đời danh sách. Chỉ tab "Đang theo đuổi" dùng ưu tiên. Payload mục tiêu 18 → **19 trường**. Lý do đầy đủ ở **mục 3.22 `docs/GOAL_FEATURE.md`**. 24 test mới.
  > ⚠️ **`ReorderableListView.onReorder` trả `newIndex` tính trên danh sách CÒN NGUYÊN phần tử đang kéo**, nên kéo *xuống* thì con số ấy lớn hơn vị trí cuối cùng đúng một đơn vị. `viTriThaThucTe` là chỗ duy nhất sửa việc đó, và nó có test riêng — dùng thẳng `newIndex` là mục tiêu rơi lệch một ô, im lặng.
  > ⚠️ Migration v19 **cố ý không suy giá trị** cho hàng cũ, khác hẳn `anchorDay` của v18: ở đó ngày đến hạn là ý định người dùng đã đưa ra và chỉ cần đọc lại, còn ở đây mọi thứ tự bịa ra đều sai với người đã sắp tay. Cùng lập luận đã dùng cho v15 và v17.
  > ⚠️ Hai test migration hoá đơn (v17, v18) đỏ vì bản dựng thử của chúng chỉ có bảng `bills`, mà v19 `ALTER TABLE goals`. Sửa ở phía **bản dựng thử** — một CSDL v17 thật luôn có bảng ấy — chứ không bọc `try/catch` quanh migration.
  > **Đã kiểm trọn vòng trên `emulator-5554`**: kéo `MuaXe` (hạn 27/04/2028) lên trên `MuaDT` (hạn 05/09/2027) → đổi ngay, **sống qua khởi động nguội**, và truy vấn thẳng PostgreSQL thấy `Priority` **100 / 200** — tức lần kéo đầu đánh số lại cả danh sách và cả hai hàng đã lên tới server. 0 pixel vàng ở khổ 411dp.
- **Hoá đơn: ngày gốc thay cho quy tắc đoán cuối tháng** (2026-09-08, **schema v18**). Người dùng báo: đăng ký hoá đơn định kỳ vào 28/02 thì ô "Ngày đến hạn" (chỉ đọc) hiện **31/03** thay vì 28/03. Nguyên nhân: `nextBillDueDate` áp quy tắc *"mốc rơi đúng ngày cuối tháng thì kỳ sau cũng rơi vào ngày cuối tháng"* — một phép **đoán ý định từ dữ liệu**, đúng cho chuỗi bắt đầu 31/01 nhưng sai cho người chọn 28/02. Nay cột cục bộ `Bills.anchorDay` lưu **ngày người dùng thật sự chọn** và được chép sang từng kỳ, nên hai chuỗi cùng đi qua 28/02 vẫn tách được nhau: gốc 31 → 28/02 → **31/03** → 30/04; gốc 28 → 28/02 → **28/03** → 28/04. Đây đúng mô hình `advancePeriodFrom(anchor, steps)` mà ngân sách dùng từ đầu, nên ba vùng ngày tháng nay nhất quán. Lý do đầy đủ ở **mục "Ngày gốc" `docs/bill/BILL_DOCUMENTATION.md`**; xin cột đồng bộ ở `docs/superpowers/backend/CAN-LAM/BILL_ANCHOR_DAY.md`. 22 test mới.
  > ⚠️ **Ba chốt chặn, cả ba đều hỏng âm thầm nếu sai:** (1) migration suy ngày gốc từ **ngày đến hạn**, không phải ngày bắt đầu — hoá đơn `bắt đầu 28/02, hạn 31/03` phải ra gốc **31**, lấy ngày bắt đầu là hạ nó xuống 28 vĩnh viễn mà người dùng không bấm gì; (2) `BillSchedule.fromBill` **không** suy lại ngày gốc từ ngày bắt đầu, nếu không mở form Sửa rồi lưu là đổi hạn của kỳ giữa chuỗi; (3) đổi ngày bắt đầu trên form thì ngày gốc **đi theo** — giữ gốc cũ là hoá đơn vừa đổi sang ngày 15 vẫn đến hạn ngày 31.
  > **Đã kiểm trên `emulator-5554`**: form Thêm hoá đơn định kỳ, chọn 28/02/2026 → ô hạn hiện **28/03/2026**. Migration v17→v18 chạy êm trên CSDL thật đang có dữ liệu.
  > Đã cân nhắc và **loại RRULE (RFC 5545)**: đặc tả bỏ qua occurrence rơi vào ngày không tồn tại, nên `FREQ=MONTHLY;BYMONTHDAY=31` **không sinh kỳ nào cho tháng Hai** — hoá đơn biến mất. Lý lẽ đầy đủ ở mục 5 tài liệu xin backend.
  > Bài học quá trình: lần đầu điều tra tôi tìm thấy quy tắc ấy được ghi là "đánh đổi có chủ ý, quyết định 2026-09-04" mô tả **đúng** ca người dùng gặp, nên kết luận đây không phải lỗi. Sai. Lý lẽ biện minh cho nó (*"chuỗi mất mốc gốc để neo"*) **không thành lập ở kỳ đầu tiên**, nơi mốc gốc chính là ngày người dùng vừa chọn. Một quyết định có chủ ý chỉ chứng minh ai đó đã cân nhắc **một** tình huống, không chứng minh nó đúng ở **mọi đường dẫn** tới đoạn mã ấy.
- **Mục tiêu: nhịp trích tự động neo vào mốc gốc, không còn trôi** (2026-09-08, **schema không đổi**). Cùng bệnh với hoá đơn, phát hiện khi rà soát: `cacKyDenHan` và `kyKeTiep` bước **từng kỳ một** từ mốc trước đó, nên mốc "ngày 31" bị kẹp về 28/02 rồi bước tiếp *từ 28* — nhịp tụt xuống 28 vĩnh viễn, im lặng. Nay mọi mốc tính từ mốc gốc qua `mocThuN(goc, chuKy, n)`: `31/01 → 28/02 → 31/03 → 30/04`. Mốc gốc là `timeCycleTakeMoney`; mục tiêu bật trước khi có ô chọn ấy thì gốc rơi về `autoDepositLastRun`, giữ nguyên hành vi cũ. Lý do ở **mục 3.12 `docs/GOAL_FEATURE.md`**. 7 test mới.
  > Chú thích cũ ở cột `Goals.timeCycleTakeMoney` ghi *"client chưa bao giờ ghi"* — **sai từ lâu**: `GoalRepositoryImpl` ghi nó ở cả đường tạo lẫn đường sửa khi bật trích tự động. Đã sửa lại chú thích; nó từng là lý do tin rằng mốc neo không dùng được làm gốc.
  > Mức nghiêm trọng thấp hơn hoá đơn có chủ ý được ghi lại: trích tự động chỉ chuyển tiền giữa hai ví **của chính người dùng**, sớm vài ngày không lỡ cam kết với ai. Hoá đơn thì "ngày trả tiền nhà" là ngày với người khác.
- **Test: 1466/1466 pass** (~80 giây) — đều đã `git add -f` (kiểm 2026-09-08)

### 🔄 Việc còn dang dở

Xem đầy đủ tại **`docs/CLIENT_APP_KNOWN_GAPS.md`**. Phiên 2026-09-03 đã đóng 9/10 mục còn mở; **G10 đóng ngày 2026-09-07**, và cùng ngày mở thêm **G23** (bản sao danh mục chỉ đầy đủ khi bộ mặc định *cục bộ* đầy đủ — tự khỏi ở lượt pull sau) và **G24** (màu danh mục không có cột trên server, chặn ở backend). Nay còn **G15**, **G23**, **G24**:

- **G15 — Bản ghi vừa hết hạn vừa hỏng đồng bộ thì không sửa được.** ⏸️ **Hoãn có chủ ý** (2026-09-04): tab "Đã hết hạn" khoá sửa/xoá, nên một ngân sách vừa quá hạn vừa bị backend từ chối vĩnh viễn sẽ nằm lại mãi — hàng đợi đồng bộ vẫn thông vì `SyncEngine` chặn nó theo thời gian, nhưng người dùng không chữa được. Giữ nguyên vì tab đó là nền cho phần thống kê/báo cáo sẽ làm sau. Bán kính rủi ro hẹp: nguồn gây lỗi chính (form tạo ra `end ≤ start`) đã bịt cùng ngày.
- ~~**G10 — `CategoryGroupMemberships` không bao giờ được đồng bộ.**~~ ✅ **Đóng 2026-09-07, và không phải bằng cách xin backend thêm entity.** Bảng phụ ấy tồn tại chỉ vì danh mục mặc định là hàng toàn cục nên không ghi `Idgroup` riêng cho từng tài khoản được. Nay mỗi tài khoản có **bản sao riêng** của bộ mặc định, nên việc gán nhóm nằm gọn trong `Idgroup` của chính hàng họ sở hữu — cột đã có sẵn và đã đồng bộ.

> ⚠️ **`.gitignore` dòng 77 vẫn có `test/`.** Luật này đã cắn **lần thứ ba** (phiên 2026-09-04). Mọi file test tạo **mới** vẫn sẽ bị bỏ qua trong im lặng — nhớ `git add -f`.
>
> Hệ quả ít ai biết: **công cụ Grep tôn trọng `.gitignore` nên không nhìn thấy thư mục `test/`**. Muốn dò xem còn ai gọi một hàm sắp xoá thì phải dùng `grep` qua shell, nếu không sẽ thấy thiếu file và xoá nhầm.

Vấn đề thuộc backend. Thư mục `docs/superpowers/backend/` được **chia ba** ngày
2026-09-07: **`CAN-LAM/`** giữ đúng phần **còn việc** (nay chỉ bốn mục) và README
trong đó là **cửa vào duy nhất**; **`DA-XONG/`** giữ 16 tài liệu **đã đóng**, mở khi
cần biết *vì sao* lược đồ có hình dạng hôm nay chứ không phải khi tìm việc; thư mục
cha chỉ còn mục lục và ba tệp bối cảnh (`New_Database.md`,
`2026-08-10-backend-sync-spec.md`, `PROGRESS-BACKEND.md`).

Bảng dưới giữ **cả** mục đã đóng lẫn mục còn việc, vì nó là nơi duy nhất đọc được
toàn cảnh một lượt. Muốn biết *phải làm gì tiếp* thì đọc `docs/superpowers/backend/CAN-LAM/README.md` —
nó chia việc theo *client đã có tính năng này chưa*, ranh giới không suy ra được
từ bảng này.

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
| 2 | `2026-09-04-backend-idempotent-delete.md` | ⚠️ **Ba trong bốn.** **(A)** ✅ xoá luỹ đẳng — trả `synced` + `'Already absent'`. **(B)** ✅ mã lỗi có cấu trúc (`code` + `constraint` + thông báo tiếng Việt). **(C)** ✅ `time_recurrence` giữ được `null` → ngân sách "Ngày cụ thể" thông. **(D)** ⛔ **CÒN** — `sync.repository.js:327` vẫn `?? 0` và schema vẫn `@default(0)`. ⚠️ Bản vá (B) làm hỏng phép phân loại lỗi phía client (regex `23505`/`23514` hết khớp vì `message` đổi) — client đã tự vá bằng `_permanentCodes`, backend không phải làm gì |
| 3 | `2026-09-04-ocr-classify-review.md` | ⚠️ **Phần nguy hiểm đã xong.** **(1)** ✅ Socket.io: JWT ở handshake, `join_account` gỡ hẳn, `grep 'io.emit('` toàn backend → **0 kết quả**, cả bốn sự kiện vào room; `Admin-web/useSocket.js` gửi `auth: { token }`. **(6)** ✅ `uq_transaction_external` nay `UNIQUE ("Idaccount", "Provider", "Bank_tran_id")` — **điều kiện chặn client gửi `provider`/`bank_tran_id` đã gỡ**. Còn **(2)–(5)**: `classifyBatch` sai kiểu tham số, `.env` không có `GEMINI_API_KEY`, dedup Quy tắc 3, cửa hậu `_mock*` — không gấp, client chưa có màn quét hoá đơn nào. ⚠️ Backend đổi **Casso → SePay** trong cùng đợt |
| 4 | `CATEGORY_NAME_UNIQUENESS.md` | ✅ **Xong 2026-09-07** — hai partial unique index `uq_category_owner_name` `(Create_by, tên chuẩn hoá NFC)` và `uq_category_default_name`, **cả hai có `WHERE "Delete_at" IS NULL`** và **không** có `Classify`. Trigger chéo đã DROP nên bản sao được trùng tên với khuôn. Đây là lần đầu client và PostgreSQL thi hành **cùng một** quy tắc trùng tên |
| 5 | `CATEGORY_STABLE_IDS.md` | ✅ **Xong 2026-09-07** — `seed.js` đóng băng 13 UUID cố định, hết `crypto.randomUUID()` cho danh mục. Kèm API mới `GET /api/sync/default-categories`. ⚠️ Bộ mặc định thu từ 18 về 13: `Chi khác`, `Thu khác`, `Làm thêm`, `Trả nợ`, `Thu nợ` đã bị **xoá mềm** — tài khoản mới không còn được nhân bản chúng |
| ~~6~~ | `CATEGORY_GROUP_MEMBERSHIP_SYNC.md` | ✅ **Đóng 2026-09-07** — không cần backend làm gì |
| 7 | `CATEGORY_CLASSIFY_ALIGNMENT.md` | ✅ **Xong 2026-09-07** — `validClassify` (`sync.validation.js:110`) nay đúng `['Thu', 'Chi', 'Vay/no']` |
| 8 | `2026-09-05-backend-transaction-goal-id.md` | ✅ **Xong 2026-09-07** — cột `transaction.Idgoal` đã có trong CSDL, kèm `fk_transaction_goal` (ON DELETE SET NULL) và `idx_transaction_goal`; `mapEntityFields` nhận cả `goalId` lẫn `goal_id`. Client có thể bỏ nhánh so **tên** khi tới lượt |
| 10 | `2026-09-05-backend-goal-priority.md` | ✅ **Cột đã có 2026-09-07** — `goal.Priority` (`Int?`) trong CSDL và trong `mapEntityFields`. Client **chưa làm** ưu tiên mục tiêu; nay không còn gì chặn, chỉ là chưa tới lượt. Lối "xin cột trước khi viết mã" đã chứng minh rẻ hơn hai lần "làm trước xin sau" |
| 9 | `2026-09-05-backend-goal-auto-deposit.md` | ✅ **Xong 2026-09-07** — cả **ba** cột `auto_deposit_amount` / `auto_deposit_wallet_id` / `auto_deposit_last_run` lên **cùng một lúc** đúng như cảnh báo, và `mapEntityFields` đã ánh xạ |
| 11 | `2026-09-06-bill-chuoi-ky-va-an-han.md` | ⛔ **Chưa có cột nào.** Đo 2026-09-07: bảng `bill` có 18 cột, **không** có `Previous_bill_id` lẫn `Auto_pay`; `transaction` **không** có `Idbill`. **(A+B) Mở khoá:** hai cột nullable — hoàn tác thanh toán hiện chỉ chạy trên đúng máy đã trả; cột B còn mở **lịch sử theo hoá đơn**. **(C) Mở đường:** `bill.Period_end` để tách kỳ tính tiền khỏi hạn trả. **(D) Mở khoá:** `bill.Auto_pay` + **chốt chặn trả hai lần** ở `/sync/push` — hai máy cùng bật, cùng offline là hai khoản chi. **(E) Mở đường:** nhận `Pay_status = 'Skipped'` (VarChar(7) vừa khít, không cần migration). ⚠️ Bảng `bill` **đã có** cột `Color` trong khi `category` thì không — lý lẽ sẵn cho mục màu danh mục |
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

**Không còn lỗi client nào sửa được mà không phải chờ ai.** Việc tiếp theo là
một lựa chọn, không phải một hàng đợi.

1. **Người dùng đã chọn mảng thông báo** (2026-09-07 tối), hoãn mảng Phân tích
   *"vì còn nhiều cái liên quan chưa triển khai"*. Thứ tự đã duyệt:
   **#7 lọc/phân trang ✅ → #2 nhắc ghi chép ✅ → #5 nút hành động ✅ →
   #6 badge ✅** (2026-09-08). Thứ tự #5 và #6 được **đảo** giữa chừng theo đề
   nghị của tôi và người dùng đồng ý.

   **Mảng thông báo nay chỉ còn hai mục, cả hai đều bị chặn bởi việc khác:**
   - **#1 Tổng kết tuần** — chờ mảng Phân tích có một màn dữ liệu thật phạm vi
     đúng một tuần. Spec đã viết xong:
     `docs/superpowers/specs/2026-09-07-weekly-summary-notification-design.md`.
   - **#8 Thông báo trên web** — ưu tiên thấp có chủ ý; cần Service Worker và
     luồng xin quyền riêng của trình duyệt, mà web chỉ dùng để trình bày.

   Ngoài ra hai việc **chờ backend**: cảnh báo giao dịch ngân hàng/OCR (kênh
   Socket.io chưa xác thực, `io.emit` toàn cục) và thông báo bảo mật.

   ⚠️ Danh sách đầy đủ kèm ghi chú kỹ thuật nằm ở
   `docs/superpowers/plans/2026-09-06-thong-bao-viec-con-lai.md` — thư mục ấy
   **bị `.gitignore` chặn**, nên file chỉ có trên máy đã dựng nó, và công cụ
   Grep lẫn `git status` đều không thấy: mở bằng `cat` hoặc Read. (Bản trước
   của mục này trỏ tới "mục 9b `docs/NOTIFICATION_FEATURE.md`" — **mục ấy
   không tồn tại**; con trỏ chết đã hai phiên.)

   Mảng **Phân tích** vẫn là khoảng trống lớn nhất khi quay lại: `AnalyticsPage`
   và `ExportReportPage` đều là giao diện tĩnh, **0** tham chiếu
   Bloc/Repository/Dao, mọi con số viết cứng — và nó đang **chặn** việc "Tổng
   kết tuần" của mảng thông báo.
2. **Năm việc còn lại của backend**, ở `docs/superpowers/backend/CAN-LAM/`:
   lỗ **(D)** `threshold_warning_percent` bị ép về `0`; **cột màu danh mục**
   (tài liệu xin nay đã lên origin); **hai mục hoá đơn** — `transaction.Idbill`
   + `bill.Previous_bill_id`, rồi `bill.Auto_pay` + chốt chặn trả hai lần; và
   **`Pay_status = 'Skipped'`**, mục duy nhất không cần migration — client chỉ
   chờ **một câu xác nhận** rồi mới mở tính năng "bỏ qua kỳ này".
   ⚠️ Bản trước của dòng này (và của `CLAUDE.md`) ghi **bốn**, bỏ sót mục cuối.
   Con số đúng lấy theo **mục 2 của README trong thư mục ấy** — đó là cửa vào
   duy nhất, và nó luôn là bản đếm có thẩm quyền.
   README trong thư mục ấy là cửa vào duy nhất; thư mục `DA-XONG/` bên cạnh giữ
   16 tài liệu đã đóng.
3. **Bản vá migration ở nhánh `patch2` — đã bàn giao cho backend (2026-09-08).**
   `)2_can_lam_all_migrations.sql` trên `main` có một câu `DELETE FROM "category"`
   xoá cứng 5 danh mục mặc định; `fk_bill_category` là RESTRICT nên nó ném 23503
   và **cả tệp roll back**. Nhánh `patch2` (commit `ea3611a`) đổi thành xoá mềm.
   CSDL trên máy này đã ở trạng thái đúng — đo 2026-09-08: **13 hàng mặc định
   sống, 5 hàng đã xoá mềm** — nhưng **tệp trong repo vẫn là bản xoá cứng**, nên
   môi trường khác chạy nó vẫn hỏng y như vậy.
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
  "Đang theo đuổi" dùng nó. Payload mục tiêu 18 → **19 trường**. Lần kéo đầu
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

⚠️ Ba lỗi ở vùng này **chỉ máy ảo Android mới lộ ra**: `ProviderNotFoundError`
trên route không có `WalletCubit`, màn đỏ do `DropdownButton` có `value` ngoài
`items`, và dấu hiển thị sai của khoản rút. Bộ test xanh cả ba lần.

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
- **Dải báo kết nối** (`ConnectionBanner`) bọc ngoài router qua
  `MaterialApp.builder`: mất mạng, có mạng lại, và kết quả đồng bộ.

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
- Analytics (báo cáo chi tiết)
- AI chat integration hoàn chỉnh
- Casso bank integration
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
