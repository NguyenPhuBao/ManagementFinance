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

- **Danh mục mặc định dùng chung không gian tên với danh mục người dùng.** Người dùng nhìn thấy cả hai trong cùng một danh sách chọn nên hai mục trùng tên là không phân biệt được. Vì danh mục mặc định là hàng dùng chung, tên của nó chiếm chỗ với **mọi** tài khoản.
- **Hàng đã xoá mềm không giữ chỗ.** Phép so tên đi qua **bốn bước, theo đúng thứ tự**: gộp Unicode về dạng NFC → chữ thường → cắt khoảng trắng hai đầu → gom khoảng trắng ở giữa. Định nghĩa **duy nhất** nằm ở `lib/core/category/category_name.dart` (`normalizeCategoryName`); mọi nơi so tên đều phải gọi hàm đó.
  - Bước NFC không phải tuỳ chọn: "Cà phê" gõ từ hai bàn phím khác nhau có thể ra hai chuỗi khác byte (6 và 8 ký tự) mà mắt thường không phân biệt được.
  - Vì sao chốt đủ bốn bước ngay: **nới lỏng về sau là miễn phí, siết chặt về sau thì phải dọn dữ liệu** — bỏ bớt một bước bây giờ nghĩa là mai kia thêm lại sẽ có sẵn dữ liệu vi phạm và `CREATE UNIQUE INDEX` phía PostgreSQL sẽ thất bại.

**Nơi thi hành — chỉ có client:**

`CategoryManagementRepositoryImpl._hasDuplicateName()` quét qua `CategoryDao.getNamesInUse(accountId)`. Cố ý **không** dùng `getCategoryRows`: hàm đó lọc sẵn theo `classify` và còn khử trùng lặp theo tên trước khi trả về, tức chính những hàng cần đối chiếu lại bị nó loại đi.

Phép kiểm tra **chỉ chạy khi tên thật sự đổi**. Bản client trước 2026-09-03 loại danh mục mặc định khỏi phép kiểm tra, nên máy người dùng có thể đang giữ một danh mục riêng trùng tên với danh mục mặc định; chặn tuyệt đối sẽ khiến họ không sửa nổi danh mục đó nữa, kể cả chỉ đổi icon.

> ⚠️ **CSDL CHƯA thi hành quy tắc này.** PostgreSQL vẫn đang giữ:
>
> ```sql
> UNIQUE (Create_by, NameCategory, Classify)                        -- uq_category_owner_name_classify
> UNIQUE (NameCategory, Classify) WHERE Is_default = TRUE           -- uq_category_default_name_classify
> ```
>
> Hai ràng buộc này lệch quy tắc theo **cả hai chiều**: lỏng hơn ở `Classify`, ở việc tách khoá riêng cho danh mục mặc định và ở so tên phân biệt hoa/thường; nhưng **chặt hơn** ở chỗ hàng đã xoá mềm vẫn giữ chỗ — nên xoá một danh mục rồi tạo lại cùng tên sẽ được client cho qua mà CSDL từ chối, và `/sync/push` chỉ đánh dấu thao tác đó `failed` nên **hỏng âm thầm**.
>
> Việc cần backend làm, kèm SQL và cách kiểm chứng: `docs/superpowers/backend/CATEGORY_NAME_UNIQUENESS.md`.

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
| `t.categoryId` (resolved) | → | `categoryId` | `idcategory` | `Idcategory` |
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

## 14. Trạng thái hiện tại (cập nhật cuối 2026-09-03)

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
- SQLite schema (Drift) aligned với backend schema — `schemaVersion = 11`
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
- **Test: 237/237 pass** (~15 giây), 31 file — cả 31 file đều đã được git theo dõi

### 🔄 Việc còn dang dở

Xem đầy đủ tại **`docs/CLIENT_APP_KNOWN_GAPS.md`**. Phiên 2026-09-03 đã đóng 9/10 mục còn mở; **chỉ còn G10**:

- **G10 — `CategoryGroupMemberships` không bao giờ được đồng bộ.** ⛔ **Không sửa được ở client**: backend không có bảng membership và cũng không có `SyncEntityType` tương ứng (`UPSERT_MAP`/`ENTITY_PRIORITY` chỉ có 6 entity), nên thêm entity mới ở client sẽ chỉ nhận `Unknown entity` và kẹt vĩnh viễn. Việc gán danh mục **mặc định** vào nhóm vì thế chỉ tồn tại trên một máy. Đề xuất chi tiết: `docs/superpowers/backend/CATEGORY_GROUP_MEMBERSHIP_SYNC.md`.

> ⚠️ **`.gitignore` dòng 77 vẫn có `test/`.** Luật này đã cắn lần thứ hai: hai file test tạo ngày 2026-09-03 cũng bị chặn âm thầm và phải `git add -f`. Mọi file test tạo **mới** vẫn sẽ bị bỏ qua trong im lặng.

Vấn đề thuộc backend (trong `docs/superpowers/backend/`), kiểm lại ngày **2026-09-04** sau khi gộp `main` tới `0e8f0b2`:

| Tài liệu | Trạng thái |
|---|---|
| `SESSION_VALIDITY_FINDINGS.md` | ✅ Xong |
| `CATEGORY_CLASSIFY_ALIGNMENT.md` | ⚠️ Gần xong — còn bước thu hẹp `validClassify` trong `sync.validation.js` |
| `CATEGORY_NAME_UNIQUENESS.md` | ⚠️ **Một phần** — Admin-web đã thi hành quy tắc, nhưng còn 4 khoảng hở: không gom khoảng trắng, không chuẩn hoá NFC, thiếu vế chéo "người dùng với mặc định", và đường `/sync/push` cùng CSDL vẫn trống |
| `CATEGORY_KEYWORD_SYNC.md` | ⛔ Chưa — **lỗ hổng phân quyền còn nguyên** (đợt sửa vừa rồi chỉ đổi ký tự tách từ khoá) |
| `CATEGORY_STABLE_IDS.md` | ⛔ Chưa — `seed.js` vẫn `crypto.randomUUID()` |
| `CATEGORY_GROUP_MEMBERSHIP_SYNC.md` | ⛔ Chưa — thứ duy nhất còn chặn G10 |

### 💰 Ngân sách (2026-09-04)

Trước phiên này, `budget` là feature **duy nhất bị đứt đoạn ở giữa**: bảng Drift, DAO và cả hai chiều đồng bộ đã hoàn chỉnh, nhưng UI là dữ liệu giả cứng — `budgetDao` không có một lời gọi nào từ mã sản xuất ngoài `SyncEngine`, và nút "Lưu" ở trang cấu hình là `onPressed: () {}`.

Nay đã có đủ tầng như `goal`/`bill`: `data/models` → `datasources` → `repositories` → `presentation/bloc` → hai trang.

Ba điểm cần biết khi đụng vào vùng này:

- **Số "đã chi" được tính lại ở client từ bảng `transactions`, không đọc cột `Spent`.** Cột đó tồn tại ở cả hai phía nhưng **không bên nào cập nhật**: backend không có tác vụ nền, còn giao dịch thì người dùng ghi được khi offline. `BudgetRepositoryImpl` ghi kết quả xuống cột bằng `cacheSpent()` để lần đẩy sau gửi đúng số — hàm đó cố ý **không** đụng `syncStatus` lẫn `updatedAt`, nếu không mỗi lần mở trang lại sinh một thao tác đẩy và LWW cho client thắng oan.
- **Ba phần trong bản dựng hình bị bỏ vì không có chỗ lưu:** "Tên ngân sách" (backend không có cột tên), "Danh mục áp dụng" nhiều danh mục (`Idcategory` chỉ giữ được một), và "Quy tắc phân bổ 50/30/20" (không có bảng nào lưu, và nó nói về chia *thu nhập* chứ không phải hạn mức). Giữ lại chúng dưới dạng giao diện không lưu được gì sẽ tái lập đúng vấn đề cũ: người dùng bấm Lưu và tưởng đã lưu.
- **Lược đồ `budgets` đã khớp backend (v11, 2026-09-04).** Thêm `threshold_warning_percent` (backend có từ DB v2, client thì chưa — ngưỡng cảnh báo theo phần trăm vì thế không bao giờ sang được máy khác) và bỏ ba cột backend không có: `remaining`, `percent_spent` (chỉ là `amount - spent` và `spent / amount`, nay tính ở `BudgetEntity`) và `period` (đã bị `time_recurrence` thay thế từ DB v2).
  - Migration dùng `TableMigration` chứ không phải `ALTER TABLE ... DROP COLUMN`: cú pháp đó chỉ có từ SQLite 3.35, mà phiên bản đi kèm khác nhau giữa Android, iOS và web.
  - Ngưỡng phần trăm lưu **0–100** để khớp `Decimal(15,2)` của backend; quy về tỉ lệ đúng một chỗ ở `BudgetEntity.warningRatio`. Thứ tự ưu tiên khi cảnh báo: ngưỡng theo số tiền → ngưỡng theo phần trăm → mốc mặc định 90%.
  - Việc này làm lộ một lỗi **fixture** trong `category_dao_test.dart`: bảng `budgets` giả luôn ở hình dạng trước v5 kể cả khi test khai `user_version = 7`/`9` — một trạng thái không tồn tại trên máy thật, vì migration là cộng dồn. Nay `_createLegacyNonCategoryTables` nhận tham số `atVersion`.

### 🔴 Đồng bộ đang bị kéo chậm bởi 5 danh mục hỏng (đo trên app thật 2026-09-04)

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

**Nguyên nhân bước 1 nằm ở client — ✅ đã sửa 2026-09-04.**
`PersonalDefaultCategories` **có** kiểm trùng theo tên chuẩn hoá, nhưng chạy
**trước** `SyncEngine.start()`, nên trên máy mới thì CSDL cục bộ còn rỗng và
phép kiểm không thấy gì. Đây **không** phải hệ quả của `CATEGORY_STABLE_IDS.md`
như bản ghi đầu tiên (`25915ec`) quy nhầm.

Nay tách làm hai giai đoạn: `convertLegacyRows()` chạy trước đồng bộ và chỉ đụng
máy còn hàng seed `cat_*`; `ensureMissing()` chạy **sau** khi pull xong, và chỉ
khi `SyncEngine.hasCompletedPull` — pull hỏng thì hoãn tới lần mở app sau chứ
không tạo mù. Chi tiết ở **G14** trong `docs/CLIENT_APP_KNOWN_GAPS.md`.

> ⚠️ Bản vá ngăn phát sinh mới, **không dọn** bản trùng đã có trên máy đã lỡ tạo.
> Cách dọn ghi ở cuối G14.

Phần backend (mã lỗi ổn định, vai trò lớp phòng thủ thứ hai) ở khung đỏ đầu
`CATEGORY_NAME_UNIQUENESS.md`. Phần độ trễ giảm bớt ở **G13**.

### 🚀 Bắt đầu từ đâu ở phiên sau

Ghi ngày 2026-09-03, cập nhật 2026-09-04 sau khi đo trên app thật. Thứ tự đề
nghị, việc rẻ nhất trước:

1. **Nếu backend đã trả mã lỗi ổn định cho vi phạm trùng tên** → client cần đúng
   **một dòng**: thêm `if (code == 'CATEGORY_NAME_DUPLICATE') return
   SyncFailureKind.permanent;` vào `_classifyFailure`
   (`lib/core/sync/sync_engine.dart`). Không có nó, vi phạm trùng tên rơi vào
   nhánh `return SyncFailureKind.transient` ở cuối hàm và bị **đẩy lại mãi** —
   đây chính là thứ đang kéo chậm đồng bộ, xem mục trên. Nhớ viết test tái hiện
   trước.
2. **Bốn tài liệu chờ backend** trong `docs/superpowers/backend/`, thứ tự:
   `CATEGORY_KEYWORD_SYNC` (có **lỗ hổng phân quyền**, bản vá chỉ vài dòng và
   độc lập với phần thiết kế bảng mới) → `CATEGORY_NAME_UNIQUENESS` →
   `CATEGORY_STABLE_IDS` → `CATEGORY_GROUP_MEMBERSHIP_SYNC`. Trạng thái từng cái
   ở bảng ngay trên.
3. **G10** là mục dang dở duy nhất còn lại ở client, bị chặn ở mục 2 dòng cuối.
4. **Kịch bản nâng cấp CSDL v7 → v10 chưa từng chạy thật** (chỉ có test). Người
   dùng đã quyết định không chạy. Ghi lại vì: nếu sau này có báo cáo **mất danh
   mục** hoặc **giao dịch không đồng bộ sau khi cập nhật app**, đây là chỗ nghi
   đầu tiên. Cách kiểm: dựng worktree ở `ea0941b`, chạy bản cũ để sinh CSDL v7,
   rồi mở bản mới **cùng origin**.

Muốn xác minh thay đổi ngoài bộ test thì dùng skill **`chay-app`** (Chrome
headless + truy vấn PostgreSQL). ⚠️ Skill đó nằm trong `.claude/` nên **không
được push** — chỉ có trên máy đã dựng nó.

### ❌ Chưa làm / Tiếp theo
- Analytics (báo cáo chi tiết)
- AI chat integration hoàn chỉnh
- Casso bank integration
- Push notifications
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
