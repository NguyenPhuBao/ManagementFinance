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
- Tích hợp AI chat
- ⚠️ **Kết nối ngân hàng đã BỎ khỏi sản phẩm ngày 2026-09-18** (quyết định của nhóm). Backend vẫn còn module `bank/` cùng tích hợp SePay (thay Casso từ 2026-09-07) và CSDL vẫn còn các cột `Id_casso_account`/`Id_bank_casso`, nhưng **client đã gỡ toàn bộ phần của mình** — xem khối "🏦 Gỡ phần client của liên kết ngân hàng" ở mục 14

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
| `GET/POST /api/bank/*` | Tích hợp ngân hàng SePay (thay Casso từ 2026-09-07). ⚠️ **Client không gọi route nào trong nhóm này** — nhóm bỏ liên kết ngân hàng ngày 2026-09-18 |

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
`start(idaccount:)` được gọi từ **2** nơi, đều trong `AuthBloc`: lúc khôi phục phiên và sau đăng nhập. Chỗ thứ ba — `HomePage.build()` — **gỡ 2026-09-12**: nó chạy lại ở mỗi rebuild và mỗi lần xoá giãn cách lùi + thêm một chu kỳ đồng bộ; `test/core/sync/sync_engine_start_owner_test.dart` quét `lib/` để không ai gắn lại.

### Kiến trúc

```
SyncEngine._runSync()
├── Chốt vào: _disposed? / _currentIdaccount null hoặc <= 0 → BỎ QUA
│   (danh tính CHỈ đến từ phiên đăng nhập — không bao giờ suy ra từ SQLite)
├── Đang có chu kỳ chạy? → GHI NỢ (_noMotLanChay = true) rồi return
│   (không chạy chồng, nhưng KHÔNG nuốt yêu cầu — xem `finally` ở cuối)
├── Trong giãn cách sau các chu kỳ hỏng? → _scheduleBackoffRetry + return
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
├── Retry MỘT lần — chỉ khi có thất bại loại transient
└── finally: nếu đang nợ một lần chạy → chạy bù NGAY (dù chu kỳ này hỏng)
```

⚠️ **Hai chốt "không chạy bây giờ" đều phải HẸN LẠI, không được chỉ `return`.**
Nhánh giãn cách vốn đã đúng; nhánh "đang chạy" thì **chỉ `return`** cho tới
2026-09-13 — yêu cầu đến giữa chu kỳ **biến mất**, và thay đổi vừa ghi nằm chờ
timer 15 phút, đổi mạng, hoặc lần mở app sau. Cửa sổ ấy không hiếm: hai nguồn
dày nhất (`scheduleSync()` sau mỗi lần ghi, và `sync.completed` của socket đánh
thức `syncNow()`) đều hay rơi đúng vào lúc một chu kỳ đang chạy. Hỏng **im
lặng** — không lỗi, không log. Nay ghi nợ bằng `_noMotLanChay` và trả nợ trong
`finally`; là `bool` chứ không phải bộ đếm vì `_collectPendingOps` gom toàn bộ
bản ghi `pending`, nên nhiều yêu cầu dồn lại vẫn chỉ đáng **một** lần chạy bù.
Có test canh cả hai vế: `test/core/sync/sync_yeu_cau_giua_chu_ky_test.dart`.

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
3. Khi token hết hạn → auto-refresh qua `/api/auth/refresh` (⚠️ 2026-09-11: theo mã backend sau gộp `main` @ `cc65f4f`, endpoint này từ chối mọi tài khoản nên người dùng bị đăng xuất khi access token hết hạn — CAN-LAM 17 A; ✅ backend sửa, gộp `cbbeeb4` 2026-09-12 — đo đầu-cuối chiều cùng ngày: 200 kèm token mới; sau khi khoá tài khoản thử → 401 + `code: ACCOUNT_INACTIVE` ở cấp gốc)
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
| `src/Client-app/lib/core/realtime/realtime_event.dart` | **Ba** sự kiện client dịch — `ocr.completed`, `ocr.duplicate`, `sync.completed` (từ 2026-09-12, im lặng, `loiNhan == null`) — và **lý do client không đọc payload**. ⚠️ `bank_transaction.incoming` **cố ý không nằm ở đây** từ 2026-09-18: backend vẫn phát, client bỏ qua như mọi tên lạ |
| `src/Backend/modules/sync/sync.repository.js` | Prisma queries cho sync |
| `src/Backend/modules/sync/sync.service.js` | Business logic sync |
| `src/Backend/prisma/schema.prisma` | DB schema (Prisma) |
| `docs/Rule_Project/New_Database.md` | DB schema chuẩn (nguồn sự thật) |

---

## 14. Trạng thái hiện tại (cập nhật cuối 2026-09-23)

### 📋 Thứ tự làm việc mới sau cổng C (người dùng duyệt 2026-09-23 tối)

Lộ trình kiến trúc Edge AI đã đi hết phía client (chặng 1–4 xong, cổng A · B · C đạt, chặng 5
bỏ, chặng 6 là việc backend), nên người dùng duyệt một thứ tự mới, theo hai nếp đã chốt — *sửa lỗi
trước, thêm tính năng sau* và *ưu tiên giá trị người dùng*: **1a** ✅ số thu/chi Trang chủ ·
**1b** canary cho phiên có tool · **2** hai tool đọc còn lại của đơn đặt hàng cổng B + tool tìm
giao dịch + phép đo 20 câu lệnh · **3** nhập giao dịch bằng câu · **4** tạo hoá đơn · mục tiêu ·
ngân sách bằng lệnh · **5** gắn danh mục hàng loạt · **6** giọng nói, chụp hoá đơn. Bảng đầy đủ
kèm lý do ở **đầu** `superpowers/plans/2026-09-21-ai-viec-tiep-theo.md` (gitignore). ⚠️ Bước 3–4
là **chiều ghi** và **đổi bất biến ④** của `AI_AGENT_ARCHITECTURE.md` (*"không tool nào ghi"* →
*"không tool nào ghi thẳng — chỉ trả đề xuất để người dùng duyệt"*): cần brainstorm, spec, màn
Stitch và người dùng duyệt trước khi viết mã.

### ✅ Bước 1a — Trang chủ, trang Phân tích và trợ lý AI nói CÙNG một con số thu/chi (2026-09-23 tối)

Thẻ thu/chi tháng ở Trang chủ từng **cộng thô theo `type`**, nên đếm cả khoản điều chỉnh số dư lẫn
khoản "Số dư ban đầu" — hai thứ `khoanVaoThongKe` cố ý loại khỏi mọi thống kê. Trên tài khoản 10:
Trang chủ *Thu nhập 15.145.000* còn trang Phân tích *Tổng thu 15.135.000*. Chỗ lệch ấy có từ
2026-09-19 (mục 7.1 `AI_EDGE_FEATURE.md`) nhưng **nặng thêm từ lát 4b**: trợ lý AI trả lời bằng
tool `chi_tieu_theo_ky`, vốn đọc `tongThuChi`, nên nó nói một số còn thẻ ngay trên Trang chủ nói số
kia — đúng điều mảng AI cam kết không xảy ra. Người dùng chốt con số của **Phân tích** là con số
đúng: tạo một ví có sẵn tiền, hay đối soát số dư, không phải có thêm thu nhập.

**Sửa một chỗ:** `home/domain/thu_chi_thang.dart` — `thuChiThangCua` nay **đi qua `tongThuChi`**
của trang Phân tích và cắt tháng bằng `Ky.thang` (biên `[from, to)`), thay vì tự cộng. Thẻ số liệu
tháng và khối Nhận xét Trang chủ cùng đọc hàm ấy nên cả hai đổi theo; không đụng widget, không đụng
gói số. ⚠️ Đừng viết lại vòng cộng trong tệp ấy — một vòng thứ hai là một định nghĩa thứ hai.

**Test:** tệp mới `test/features/home/thu_chi_thang_test.dart`, **7** ca — 4 đỏ trên mã cũ (khoản
điều chỉnh chiều thu · khoản số dư ban đầu · khoản điều chỉnh chiều chi · Trang chủ khớp
`tongThuChi` trên cùng dữ liệu); 3 ca canh xanh ngay (khoản **chưa phân loại thật** vẫn được tính ·
biên **tháng 12** sang năm mới · **29/02** năm nhuận) nên đã thử bằng **ba** bản sai có chủ ý (loại
mọi khoản trống danh mục; lùi biên cuối một ngày; nới biên cuối một ngày) — mỗi bản làm đúng các ca
ấy đỏ. Trọn bộ **3561/3561** (3 skip, 2 phút 48 giây), analyze **26**. Schema, payload, `pubspec`
không đổi.

**Nghiệm thu máy ảo** (`emulator-5554`, AVD `FlowMoney_16G`, tài khoản 10, không backend): thẻ
Trang chủ *Thu nhập 15.135.000 đ · Chi tiêu 2.141.000 đ · Thu net +12.994.000 đ*; trang Phân tích
tháng 9/2026 *Tổng thu 15.135.000 đ · Tổng chi 2.141.000 đ*; khối Nhận xét Trang chủ *"Tháng này thu
15.135.000 đ, chi 2.141.000 đ, còn lại 12.994.000 đ…"*. Tổng số dư ví vẫn **13.004.000 đ** — chênh
10.000 với "còn lại" là **đúng nghĩa**: khoản điều chỉnh đổi số dư thật nhưng không phải thu nhập.

⚠️ **Còn một chỗ lệch nhỏ, chưa vá, không thuộc bước này:** thẻ "Số dư còn lại" ở trang Phân tích in
*"Để dành 86%"* (làm tròn nguyên) cạnh khối Nhận xét in *"85,7%"* (luật G2) — mục 7.1
`AI_EDGE_FEATURE.md`, chỗ lệch 2.

### ✅ Edge AI — lát 4b XONG 9/9 task, CỔNG C ĐẠT trên cả hai máy (2026-09-23 chiều)

Màn **Trợ lý AI** nay đi **bậc tool**: mô hình chọn một trong bốn tool **chỉ đọc**
(`danh_sach_ngan_sach` · `danh_sach_hoa_don` · `danh_sach_vi` · `chi_tieu_theo_ky`), app chạy hàm
domain có sẵn và trả về **hàng có tên**, câu trả lời kiểm trên chính những hàng ấy. Chưa tool nào
chạy thì màn rơi về bậc 1 **im lặng** (L1). Commit: `4cb0b3b` (Task 5b–5d: `hangVi` ·
`hangNganSach` · `hangChiTieu`, `viDangAm` mở công khai) · `af11ce0` (Task 6: bốn adapter +
`BoCongCu` + DI, tách `viChoGoiSoTu` / `nganSachDangChay`) · `af31c7f` (Task 7: vòng lặp
`hoiBangCongCu`, trần 3 lời gọi, thang lùi L1–L4) · `863c4cd` (Task 8: nối màn, dòng chỉ báo
*"Đang tra cứu hoá đơn…"*, `onHoiBac1`; nghiệm thu máy ảo 411dp, 0 pixel `#FFFF00`) · `ace9a53`
(ba bản sửa từ lượt đo).

**Cổng C** — tám câu, APK release, tài khoản 10 (bảng ở mục **9.14** `AI_EDGE_FEATURE.md`): nhóm A
*"cái nào"* trả lời **bằng tên** Realme **4/4**, OnePlus **3/4**; câu 2 và 9 đúng; **0 câu bịa
số**; **0 lần sập**; mô hình chọn đúng tool + tham số ở 8/8 câu mỗi máy. Tổng một câu (sau khi nạp)
10–15 s Realme CPU, 4,5–8,6 s OnePlus GPU.

⚠️ **Ba lỗi thật lượt đo bắt được, 3543 ca test đều mù, cả ba chỉ OnePlus lộ ra** — người dùng chọn
sửa ngay (`ace9a53`): **4.34** thẻ số liệu gán nhầm đối tượng khi hai hàng cùng giá trị ở hai câu
khác nhau (nay xét từng câu) · **4.35** mẫu câu L3 sau ba lời gọi lặp hàng và mất nhãn kỳ (nay
theo lượt gọi, kèm chữ kỳ) · **4.36** câu trả lời dạng markdown lộ `*` (nay gỡ lúc hiện). Kiểm lại
trên Realme sau khi sửa: không hồi quy.

⚠️ **Kế hoạch sai ba chỗ nữa, sửa ở test khi thi công:** hang_chi_tieu có **6** ca chứ không 7 (Task 5
là +26 chứ không +27); fixture ngân sách "Cũ" của Task 6 dựng `recurrence: true` — ngân sách lặp lại
không đặt ngày kết thúc **không bao giờ hết hạn**, nên ca "chỉ ngân sách đang chạy" đỏ trên mã đúng;
hai ca huỷ của Task 7 đưa câu sai ở token **cuối** mà đòi `soLanHuy == 1`, trong khi `gacTheoCau`
chỉ huỷ khi câu trượt **giữa** luồng. Mỗi chỗ có bản sai có chủ ý chứng minh ca đã sửa canh thật.

Test **3554/3554** (3 skip), analyze **26**; `ai_edge` + `ai_chat` **44** tệp / **424** ca. Schema,
payload, `pubspec` không đổi so với `af2aa81`. **Còn mở, chờ người dùng quyết:** canary cho phiên có
tool (bẫy 4.33) · câu chào trên Realme mất ~23 s (giá của L1) · ĐC1 không bao giờ nói "không có dữ
liệu" · chênh 10.000 đ tổng thu (Trang chủ vs gói số). *(Tối cùng ngày: chênh 10.000 đ ✅ **đã vá**
ở bước 1a, và canary được duyệt làm ở bước 1b — hai khối ở đầu mục này.)*

### Edge AI — lát 4b, nửa đầu: Task 1–4 + 5a; gói cũ sập native khi phiên mang tool → nâng gói, cổng Task 4 ĐẠT (2026-09-23 trưa — ảnh chụp, khối trên là hiện trạng)

Thi công inline theo kế hoạch `superpowers/plans/2026-09-23-chang-4b-tool-calling-vong-lap.md`.
Bốn commit mã (`0c9ca1e` · `3bbc2c6` · `cd14b75` · `87ef4f3`): `HangSoLieu` + `KetQuaCongCu` (một
hàng đầy đủ), `GoiSoTraCuu extends GoiSo` (gói tích luỹ, ba lớp chắn dùng nguyên, mẫu câu thật
cho L2/L3), `CongCu` / `KhaiBaoCongCu` / bốn tên tool / `kTranGoiCongCu`, `PhienCongCu` thuần +
`PhienCongCuGia`, `DangTraCuu` / `KhongTraCuu` trong `SuKienGac`, `kPromptHeThongCongCu`, và
`SlmRuntime.moPhien` (bản thật `_PhienThat` trong `slm_runtime.dart`, test quét 16 giữ nguyên).
Lúc ấy **chưa nối vào màn nào** (nối ở Task 8, khối trên). Test **3496/3496** (3 skip), analyze
**26**; schema, payload không đổi — ⚠️ **`pubspec` CÓ đổi** (xem dưới).

🛑 **Spike Task 4 với gói cũ: engine SẬP NATIVE khi phiên mang tool, trên CẢ HAI máy** — Realme RMX2205 (CPU,
Android 13) **3/3** `SIGSEGV`, OnePlus 13R (GPU, Android 16, máy demo) **2/2** `SIGBUS`, cùng một
đường: `ConstrainedDecoder::ProcessLogits` → `CompositeLogitMask::Apply` → con trỏ hàm rác vào
`libGemmaModelConstraintProvider.so`, ngay lượt giải mã đầu, **kể cả câu "Xin chao"** không cần
tool. Phép đối chứng: đường bậc 1 (không tool) trên **cùng APK, cùng máy** trả lời đúng. Gốc nằm ở
gói: `flutter_gemma_litertlm` 1.7.0 **gắn cứng** `enable_constrained_decoding = true` hễ phiên có
tool (`litert_lm_client.dart:1080–1086`), không tham số nào tắt. Thi công dừng; người dùng chọn đo
thêm OnePlus (cũng sập) rồi chọn **nâng gói lên bản mới nhất**.

✅ **Nâng `flutter_gemma` 1.8.3 → 1.9.0, `flutter_gemma_litertlm` ^1.7.0 → 1.8.0** (`af2aa81`,
người dùng **duyệt đích danh** việc đổi `pubspec`, phá chốt "không đổi pubspec" của spec 4b và chốt
ghim 1.8.3 từ P0; gói engine nay ghim **cứng**; changelog litertlm 1.7.1: *"tool calls no longer
crash the app"*). Đo lại cùng móc spike: **6/6 không sập** trên hai máy; E2B gọi đúng `danh_sach_vi`
ở 4/4 câu cần tool, lượt gọi **0 ký tự chữ**, câu trả lời nêu đúng tên + số trong JSON; 2/2 câu chào
không gọi tool (→ L1). Câu cần tool ~9 s OnePlus / ~12 s Realme; đường bậc 1 trên cả hai máy không
đổi. Bảng đo ở mục **9.13**, bẫy **4.33** `AI_EDGE_FEATURE.md`.

✅ **Task 5a xong** (`21389ea`): `hangHoaDon` — hàng theo tên cho tool `danh_sach_hoa_don`, 8 ca, bản
sai bỏ phép chặn cuối tháng làm đúng ca "kỳ SAU bị loại" đỏ. Test **3504/3504** (3 skip), analyze
**26**. Phiên ấy dừng ở đây theo yêu cầu người dùng; 5b–5d và Task 6–9 làm xong chiều cùng ngày
(khối trên).

⚠️ **Hai chỗ spec/kế hoạch sai, lộ ra khi thi công:** (1) ca test của kế hoạch so thẳng danh sách
**record chứa `Map`** (`ketQuaDaNhan`) — đỏ trên cả mã đúng, vì record so `==` từng trường, `Map`
so bằng danh tính, matcher `equals` không so sâu vào record; Task 3 đã trải cặp thành danh sách,
Task 7 sửa ca còn lại cùng khuôn. (2) spec 3.7 bảo đo `chat.currentTokens` cho bẫy 4.29 — thuộc tính
ấy chỉ cộng token của **câu trả lời**, không đo được thứ bẫy ấy cần.

### ✅ Edge AI — dọn trước lát 4b: bảng tra nhãn một định nghĩa, và màn Cài đặt AI thôi đè lỗi cũ (2026-09-23)

Hai việc nhỏ kẹp đầu phiên, **trước** khi mở lát 4b — người dùng chốt thứ tự *sửa lỗi trước, tính
năng sau*. Mỗi việc một commit.

**`chuoiTheoNhan` — bảng tra nhãn của mẫu câu, nay một định nghĩa** (`ai_edge/domain/goi_so.dart`).
Sáu gói số từng tự dựng mỗi gói một bảng tra nhãn → chuỗi cho mẫu câu. Chỉ gói ngân sách có
`putIfAbsent` (mục **đầu** thắng — cách chữa bẫy **4.30** ở chặng 4a); năm gói kia vẫn map literal
`{for … x.nhan: x.chuoi}`, tức mục **cuối** thắng. Chưa câu nào hỏng, vì các mục danh sách chặng 4a
thêm vào cố ý mang nhãn khác nhãn tổng hợp (`Đang âm` / `Ví đang âm`, `Đã quá hạn` / `Quá hạn`) —
nhưng chú thích *"đặt CUỐI để các mục tổng hợp ở trên gặp trước"* ở gói ví và gói hoá đơn là lý lẽ
của mục-đầu-thắng, tức **nói ngược mã**. Nay cả sáu gói gọi `chuoiTheoNhan`.

⚠️ Qua API công khai của gói **không dựng được** nhãn trùng, nên ca canh nằm ở chính
`chuoiTheoNhan` (`goi_so_test.dart`; bản mục-cuối-thắng đỏ đúng `'45.000 đ' instead of '1'`). Một
gói tự viết lại map literal thì **không ca nào đỏ** — lát này không thêm test quét.

**Màn Cài đặt AI thôi đè lượt hỏng của lần trước thành "Chưa tải"** (bẫy **4.32**
`AI_EDGE_FEATURE.md`). Lúc mở màn, `_doTrangThai()` (chờ `daCo()`) và `khoiPhuc()` (chờ
`luotDangSong()`) chạy song song, và phép về **sau** thắng. Tệp dở của một lượt hỏng chưa đủ cỡ nên
`daCo()` = `false`; về sau tin khôi phục thì nó đè "Tải không xong" thành "Chưa tải" — mất nút
**Thử lại** (nối từ chỗ đứt khi nối được), còn nút **Tải**. Nay phép dò không đè `loi`, cùng ba
trạng thái nó vốn đã chừa. Cùng lượt sửa **chú thích tự mâu thuẫn** ở `_khoiLoi()`: một câu còn tả
bản cũ hứa *"phần đã tải được giữ lại"*, câu ngay dưới tả bản hiện hành không hứa. ⚠️ Mới kiểm bằng
**bộ giả**: bản thật `luotDangSong()` luôn trả `loi: null` (màn hiện câu dự phòng), và lượt hỏng có
được `taskForId` của `background_downloader` trả về hay không thì **chưa đo** — tức chưa biết máy
thật có đi tới đường này không.

Test **3470/3470** (3 skip), analyze **26**; schema, payload, `pubspec` không đổi.

📝 **Lát 4b — spec đã duyệt và kế hoạch đã viết cùng ngày** *(ảnh chụp lúc ấy: "CHƯA thi công";
nay đã thi công Task 1–4 và dừng ở cổng Task 4 — khối trên cùng mục này)*. Spec `superpowers/specs/2026-09-23-chang-4b-tool-calling-vong-lap-design.md` — ba quyết định
của người dùng trong lượt brainstorm: đích = tầng tool + **bốn** tool *"danh sách có tên"*
(`danh_sach_ngan_sach` · `danh_sach_hoa_don` · `danh_sach_vi` · `chi_tieu_theo_ky`); chấp nhận hai
lượt sinh trên cả Realme CPU lẫn OnePlus, đo thật; **hướng A — tool THAY gói số trong prompt** (B tái
hiện lỗi 4a, C không phải agent). Hình dạng: `HangSoLieu` tích luỹ vào `GoiSoTraCuu extends GoiSo`
(ba lớp chắn dùng nguyên), `PhienCongCu` thuần (bản thật chỉ trong `slm_runtime.dart`), vòng lặp tự
viết trần 3 lời gọi + thang lùi L1–L4 — **L1** (chưa tool nào chạy thì không hiện câu, rơi về bậc 1)
là chốt chặn câu bịa **không số** mà `kiemSo` mù. Mục 2 của spec ghi những điều đọc được từ mã gói
`flutter_gemma` 1.8.3 kèm dòng. Kế hoạch **9 task** ở
`superpowers/plans/2026-09-23-chang-4b-tool-calling-vong-lap.md` (thư mục gitignore): Task 4 là
**spike trên Realme** — chưa thấy `FunctionCallResponse` thì chưa dựng tầng. M3 (luật ngủ đông) không
chặn lát này: không tool nào chạm `tai_phan_bo.dart`.

### 🛑 Edge AI — chặng 4a: tên đối tượng trong gói số — CỔNG CHƯA ĐẠT (2026-09-23)

Spec `superpowers/specs/2026-09-22-chang-4a-ten-doi-tuong-goi-so-design.md`, chín task, thi công
inline. **3468/3468** pass · analyze **26** issue, 0 error · schema **không đổi** (v24) · payload
**không đổi**. Bảng đo lại ở mục **5.6** `docs/AI_AGENT_ARCHITECTURE.md`; tường thuật ở mục
**9.12** `docs/AI_EDGE_FEATURE.md`.

**Làm gì:** `SoLieu` thêm **một** trường `ten` (`String?`) — tên đối tượng, tách khỏi `nhan` vốn
là tên chỉ số. Bốn gói (ngân sách · ví · hoá đơn · phân tích) nhồi **danh sách** thay vì một mục,
trần `kToiDaMucMoiGoi = 4`. `kiemNhan` và `theCuaCau` đọc `ten`; prompt nêu tên; few-shot thêm ví
dụ dạng *"cái nào"*.

**Kết quả đo trên Realme: nhóm A 1/4** — câu *"ngân sách nào sắp hết"* nay đáp **"…là Giáo dục
với tỉ lệ 90,0%"** kèm thẻ *"Giáo dục · Tỉ lệ 90,0%"*, thay vì một con số trần. Ba câu còn lại
(danh mục nào · hoá đơn nào · ví nào) vẫn hỏng. Điều kiện 3 của cổng (SAI = 0) **đạt** sau khi
đóng một hồi quy; điều kiện 1 (≥ 3/4) **trượt**.

⭐ **Bài học trung tâm: danh sách có tên là CẦN nhưng CHƯA ĐỦ.** Một lượt log gói số thật chứng
minh cả bốn gói mang tên **đúng thiết kế**. Nhưng gói nói `Quá hạn: 1` ở một dòng và `Kiem · Phải
trả: 45.000 đ` ở dòng khác — **không chỗ nào nói Kiem LÀ cái quá hạn**. Mô hình phải **nối hai
mục rời bằng suy luận**, và E2B không làm được: nó trả lời bằng con số tổng. Ví y hệt. 🛑 Vậy ba
câu còn hỏng **không** chữa được bằng cách làm gói giàu thêm — thứ cần là **tool trả một hàng đầy
đủ** (tên + số + trạng thái trong cùng kết quả), tức việc của lát **4b**. Đừng tinh chỉnh gói số
thêm nữa.

⚠️ **Bốn lỗi thật lượt đo bắt được, 3462 ca test đều mù** — chi tiết ở bẫy **4.29–4.31** và vế
thứ ba của **8.6** trong `AI_EDGE_FEATURE.md`:

1. **Prompt vượt trần token là lỗi CỨNG, không phải chậm** — câu trả lời **rỗng**, không phải
   chậm đi như kế hoạch lường. `maxTokens` là hằng của *client* và là trần cho **tổng** input +
   output; nới 1024 → 2048. Prompt đi từ 1.704 lên ~2.280 ký tự, token đầu 4,6 s → 8,4–11,1 s.
2. **Mẫu câu ngân sách in tỉ lệ của ngân sách KHÁC** — `{x.nhan: x.chuoi}` lấy giá trị cuối, nên
   câu về Giáo dục in *"(7,1%)"* của Mua sắm. Sai **im lặng**, và ca `contains('Giáo dục')` viết
   cùng lát **xanh suốt** — cùng bài học G43. *(✅ Từ 2026-09-23 cả sáu gói tra nhãn qua
   `chuoiTheoNhan` — xem khối đầu mục này.)*
3. **Nhãn giàu hơn làm một câu SAI lọt qua `kiemNhan`**: *"Số ví đang âm: −100.000 đ"* (số ví là
   1) lọt, trong khi bản **trước** chặng 4a chặn được. Luật siết ra từ đây: mục **có tên** đòi câu
   nêu **tên**; mục không tên giữ luật cũ.
4. `debugPrint` **bị tiết lưu** nên sáu dòng log gói số bị nuốt sạch — phải `print` và mỗi mục một
   dòng ngắn. Nó đã chặn phép chẩn đoán mất trọn một lượt build.

**Việc tiếp theo:** lát **4b** — tool-calling + vòng lặp, kế hoạch viết dựa trên đơn đặt hàng sáu
tool ở mục 5.6, với hình dạng nay đã rõ hơn: **một hàng đầy đủ**, không phải nhiều mục rời.

### ✅ Edge AI — chặng 3 của lộ trình: đo bậc 1 hỏng ở đâu — CỔNG B QUA (2026-09-22 tối muộn)

**Không phải task mã** — một buổi đo có biểu mẫu. Bảng 20 hàng đầy đủ ở mục **5.6**
`docs/AI_AGENT_ARCHITECTURE.md`; đây chỉ là bản tóm.

**Đo trên Realme RMX2205** (Dimensity 1100, CPU — canary đã ghi dấu GPU sập), APK **release**,
tài khoản 10 với dữ liệu thật. Nạp mô hình **9.196 ms**, sinh câu **4,8–8,9 s**. Backend **không
cần chạy** — mọi thứ đọc từ SQLite cục bộ.

**Kết quả: ✅ 5 · rơi mẫu 3 · SAI 0 · LỆCH CÂU HỎI 12.**

⭐ **Bậc 1 không bịa — nó lệch.** Ba lớp chắn (`kiemSo`, `kiemNhan`, `kiemGiong`) giữ đúng bất
biến: **không một con số sai nào lọt ra** trong 20 câu. Nhưng hơn **một nửa** câu trả lời đúng
số, đúng nhãn, mà **không trả lời điều được hỏi**. Nếu chấm bằng hai ô *trả lời được / rơi mẫu*
như bản kế hoạch đầu, bảng này đọc thành *"8/20 hỏng"* và **bốn tool quan trọng nhất sẽ không
được đặt hàng** — cột thứ tư là thứ giữ lại kết luận đúng.

⭐ **Thứ thiếu nhất không phải con số, mà là CÁI TÊN.** Bốn câu hỏi *"cái nào"* — ngân sách nào
sắp hết · danh mục nào chi nhiều nhất · hoá đơn nào quá hạn · ví nào đang âm — hỏng theo **cùng
một kiểu**: gói số mang **giá trị** mà không mang **định danh**. Hỏi *"ngân sách nào sắp hết"*
thì nhận *"Ngân sách căng nhất là 90,0%"* thay vì *"Giáo dục"*. Và nó **rẻ để chữa**: hàm domain
vốn trả entity có tên sẵn, chỉ là `NguonGoiSo` rút lấy con số rồi bỏ tên lại.

**Đơn đặt hàng: sáu tool** (mục 5.1 đoán **mười**, trong đó **ba cái không câu nào cần tới**) —
`danhSachNganSach` · `danhSachHoaDon` · `danhSachVi` · `chiTieuTheoKy` · `duBaoMucTieu` ·
`goiYHanMuc`. Bốn cái đầu đều hình dạng *"trả về danh sách **có tên**"*, thứ mục 5.1 không dự
đoán vì nó nghĩ theo hướng "mỗi hàm domain một tool". Đây đúng là lý do lộ trình bắt **đo trước
khi dựng**.

⚠️ **Ba câu hỏng mà KHÔNG cần tool nào** (12, 14, 20): con số cần trả lời **đã nằm sẵn trong
gói**, mô hình vẫn chọn nhầm. Chữa bằng tool là chữa nhầm bệnh — thứ cần sửa là **nhãn trong
prompt** và cách chọn gói, và nên làm **trước** khi dựng tool. Nguy hiểm nhất là câu 14: hỏi tiền
trong ví (**13.004.000 đ**), nhận *"Còn lại là 12.994.000 đ"* (= thu − chi của kỳ) — hai số khác
nghĩa mà **chênh đúng 10.000 đ**, người dùng không có cách nào nhận ra.

⚠️ **Hai câu đòi vòng lặp chứ không đòi tool** (16, 17): *"có đủ trả hoá đơn không"* và *"trả hết
thì còn bao nhiêu"* cần **so sánh** và **trừ** giữa hai gói. Đúng bất biến đã khoá — **lớp AI
không tính** — nên chúng chỉ giải được ở vòng 3 bằng cách gọi hai tool rồi để **hàm domain** làm
phép tính.

⚠️ **Hai lỗi thật lượt đo bắt được, ngoài phạm vi chặng 3** — cái đầu ✅ **đã sửa ở chặng 4a**, cái
sau ✅ **đã sửa ở bước 1a** (2026-09-23 tối) *(dòng này từng ghi "chưa sửa" cho cả hai, rồi "cái sau
vẫn mở" — mỗi câu đúng tới lúc lỗi tương ứng được sửa)*:

1. ✅ **Thẻ số liệu gán nhãn của một gói khác khi hai nhãn trùng GIÁ TRỊ** — sửa ở chặng 4a Task 3
   (`20bbc05`). Câu 15 trả lời *"Ví đang âm: 1"* nhưng thẻ bên dưới hiện **"Quá hạn 1"** — nhãn của
   *hoá đơn quá hạn*. Cả hai cùng bằng **1** và `theCuaCau` khớp theo **giá trị**. Cùng họ bẫy
   **4.19** nhưng nguyên nhân khác hẳn: trùng giá trị, không phải chuỗi con. Thẻ nay ưu tiên mục mà
   câu nhắc tới — bẫy **4.27** `AI_EDGE_FEATURE.md`.
2. ✅ **Tổng thu lệch 10.000 đ giữa Trang chủ và gói số** — Trang chủ *Thu nhập 15.145.000*, gói
   phân tích *Tổng thu 15.135.000*, đo cùng lúc cùng tài khoản. Chênh ấy lan sang mọi câu trả lời
   dùng tổng thu. Dòng này từng dặn *đừng sửa bên nào trước khi chốt con số nào mới đúng*; người
   dùng chốt con số của Phân tích ngày 2026-09-23 và bước **1a** vá thẻ Trang chủ — khối ở đầu
   mục 14.

⚠️ **Một bẫy đo sẽ tái phát:** `adb shell input text` **làm hỏng chữ hoa giữa từ** — gõ `MuaXe`
ra **`Mũae`** trên màn hình. Câu hỏi chứa tên riêng phải **chụp màn kiểm lại chữ đã vào** trước
khi tin kết quả.

**Việc tiếp theo: chặng 4** — tool-calling + vòng lặp; kế hoạch viết tại cổng B, tức bây giờ.

### ✅ Edge AI — việc số 2 của lộ trình: tải mô hình chạy nền + resume (2026-09-22 tối muộn)

Kế hoạch `docs/superpowers/plans/2026-09-22-tai-mo-hinh-nen-resume.md` (7 task), spec cùng ngày; chi
tiết đo ở mục **9.10** `AI_EDGE_FEATURE.md`. `MoHinhTaiVe` thôi cầm một `Future` sống trong tiến
trình mà đứng trên **`NguonTaiNen`** — lượt tải có danh tính do hệ thống giữ (`background_downloader`,
taskId cố định), nên thoát app thì lượt vẫn chạy và mở lại thì `khoiPhuc()` hỏi được. `daCo()` kiểm
**kích thước** vì tệp dở nay được giữ; sáu trạng thái, Tạm dừng/Tiếp tục/Huỷ, hộp thoại 4G. Không
đổi schema (v24), không đổi payload; `pubspec` thêm `background_downloader` (vốn transitive), manifest
thêm `FOREGROUND_SERVICE_DATA_SYNC`. Test **3424/3424**, 3 skip, analyze 26.

⚠️ **Nghiệm thu trên máy MỚI — Realme RMX2205 (Dimensity 1100, Mali-G77, Android 13)**, người dùng
đổi máy giữa chừng. Sáu lỗi thật lộ ra, 3411 ca test mù; nặng nhất: **nạp mô hình bằng GPU sập
native** — `try/catch` quanh `getActiveModel` không bắt được gì, mỗi lần hỏi là một lần văng app.
Chữa bằng **canary** (`domain/canary_gpu.dart`): dấu ghi trước khi thử GPU, xoá trong `finally`,
mở lại thấy dấu → CPU vĩnh viễn (nạp 27 s, 7–10 s/câu trên máy ấy). Năm lỗi kia: tiến độ **âm**
của gói là mã trạng thái (màn in −400 %); `canceled` của WorkManager khi mất Wi-Fi không phải huỷ;
cleartext bị chặn ở worker native (chỉ chuyện đo qua server cục bộ); `waitingToRetry` ≠ chờ Wi-Fi;
câu "phần đã tải được giữ lại" sai ở khối chờ Wi-Fi. ⚠️ **Hai giới hạn nói ra, không vá:** Realme
UI **force-stop** app khi vuốt Recents (giết cả service nền — OEM), và sau force-stop hay dừng vì
ràng buộc thì gói **tải lại từ 0** — chỉ Tạm dừng/Tiếp tục mới giữ byte (đo: `Range: bytes=1895276544-`).
**Bước tiếp theo thứ tự đã duyệt: chặng 3 của lộ trình kiến trúc** — đo bậc 1 hỏng ở đâu (một buổi,
máy thật, 20 câu; không phải task mã).

### ✅ Edge AI — việc số 1 của lộ trình: chất lượng câu trả lời + CỔNG A QUA (2026-09-22 tối)

Thứ tự việc ở đầu `docs/superpowers/plans/2026-09-21-ai-viec-tiep-theo.md`; chi tiết ở mục **9.8**
`docs/AI_EDGE_FEATURE.md`. Sáu thay đổi, **không đổi schema** (v24), **không đổi payload**, không
thêm gói: màn Trợ lý AI **hiện chữ dần theo CÂU** (`SlmRuntime.sinhDan`/`huy` + `gacTheoCau` —
đủ câu thì kiểm rồi mới hiện, trượt thì `stopGeneration()` và không hiện; đã hiện ≥ 1 câu rồi mới
trượt thì **giữ** các câu ấy); **`kiemNhan`** lớp chắn thứ ba (số thật gán **tên** sai — chính câu
*"Tỉ lệ phân bổ là 85,4%"* đo trên máy thật là ca test); **`kiemCauTraLoi`** định nghĩa duy nhất
của "một câu được hiện" = số + nhãn + giọng, và đây là chỗ **nối `kiemGiong` vào hỏi đáp** (trước
đó chưa nối — bảng cổng A ghi "chưa đo" là sai chữ); `NguonGoiSo` gom **sáu** gói (thêm hoá đơn,
ví); bốn chip **chỉ hỏi thứ một gói có**; `promptHoiDap` có few-shot riêng, một ví dụ *không có số
liệu → không chữ số*. Test **3392/3392** (+44, bốn tệp mới) sau phần mã, **3399/3399** sau đo máy thật, analyze 26.

⚠️ Người dùng hỏi *"vậy là chỉ hỏi được thứ có sẵn thôi à"* — **đúng**: bậc này mô hình chỉ thấy gói
số (~30 con số của sáu màn). Thứ gỡ giới hạn là **function calling** (việc số 3); người dùng chốt
**giữ thứ tự** (việc này → đo chặng 3 → function calling), vì ba lớp chắn dùng lại nguyên vẹn cho
bậc sau và đo chặng 3 trên một bậc còn bịa nhãn là đo vô nghĩa.

✅ **Đo trên OnePlus 13R tối cùng ngày — CỔNG A QUA** (mục **9.9** `AI_EDGE_FEATURE.md`): câu tổng
hợp 4 câu / 429 ký tự hiện dần 1 → 3 → 4 câu; hỏi "dự báo tiết kiệm" → ba số thật đúng nhãn,
không bịa (nhưng mô hình chọn số liên quan thay vì nói "không có dữ liệu"); hỏi "có đang ổn không"
khi ngân sách 90 % → không trấn an. ⚠️ **Lượt đo bắt hai lỗi thật mà 3392 ca test mù**: câu đầu
tiên trên máy bị chặn vì token cắt con số **ngay sau dấu chấm** (`…là 2.` + `141.000`) và regex
kết câu coi cuối bộ đệm là kết câu (bẫy 4.18); thẻ số liệu so **chuỗi con** in *Số cam kết 15* cho
câu chỉ nhắc *15.135.000 đ* (bẫy 4.19, có từ P3 Task 8). Cả hai sửa + test + đo lại cùng tối.
*(Việc số 2 đã xong tối cùng ngày — khối ngay trên.)*


### ✅ Edge AI chặng 2 — P3 cắm SLM, XONG TRỌN 10 TASK (2026-09-22)

Kế hoạch `docs/superpowers/plans/2026-09-20-ai-edge-p3-cam-slm.md`. Tám tệp mã, và từ Task 9
thì **mô hình đã chạy thật trong app trên máy thật** — bảng đo ở **mục 9** `AI_EDGE_FEATURE.md`.

⭐ **Con số đáng nhớ nhất của cả mảng:** cắt sạch mạng (Wi-Fi tắt, dữ liệu di động tắt, cầu USB
gỡ; `curl` ra ngoài trả HTTP 000) rồi hỏi lại — mô hình trả lời sau **1.898 ms**, câu y hệt lượt
online, **0 dòng** log mạng. Đó đúng là lý do người dùng chọn AI trên máy.

⚠️ **Lượt nghiệm thu ấy bắt được BỐN lỗi thật mà 3.348 ca test đều mù**, và **ba trong bốn không
phải lỗi của mã P3** — chúng nằm sẵn trong dự án từ trước (mục **9.7**):

1. ⭐ **APK release không có quyền `INTERNET`** — quyền ấy chỉ khai ở `debug/AndroidManifest.xml`
   (Flutter tạo sẵn cho hot reload), nên **mọi lượt nghiệm thu máy ảo của dự án từ trước tới nay**
   dùng bản debug và che mất thiếu sót. Bản release đầu tiên không gọi được backend nào, chỉ hiện
   *"Không có kết nối mạng"* — đúng câu dùng cho lúc rớt sóng. Nay có ca test đọc thẳng manifest.
2. Thông báo lỗi tải in **nguyên URL ký hàng nghìn ký tự** → hàm thuần `cauLoiTai`.
3. ⭐ Câu *"Mô hình trên máy không chạy được"* hiện ra **khi mô hình hoàn toàn bình thường** —
   nguyên nhân thật là `AuthBloc` chưa vào `AuthSuccess` (vì `verifySession()` là lời gọi mạng,
   phải đợi hết timeout 30 s). Trớ trêu: nó rơi đúng vào ca **mất mạng**. Nay có câu riêng
   `kChuaSanSangPhien` và `debugPrint` ở cả hai nhánh — trước đó `catch` nuốt lỗi **không log gì**.
4. Tải 2,41 GB **không resume, không chạy nền** — hạng mục riêng, người dùng chốt làm sau P3.

**Bài học chung:** thứ bắt được chúng không phải một ca test nào, mà là **lần đầu chạy một bản
`--release` trên một máy thật**. Cả hai vế đều cần — bản debug che lỗi 1, máy ảo che lỗi 3 (ở đó
`10.0.2.2` luôn tới được).

| Task | Tệp | Việc |
|---|---|---|
| 1 | `domain/slm_prompt.dart` | Dựng prompt từ gói số. Bơm `SoLieu.chuoi` chứ **không** `soTho`, để câu và thẻ số liệu nói cùng con số. Mang **dòng MỨC** của hệ luật xuống prompt |
| 2 | `domain/chu_de_chan.dart` | Chặn đầu tư / chứng khoán / tiền mã hoá / vay ngân hàng / thuế. So **có dấu** (quy tắc 7) |
| 3 | `data/slm_cache.dart` | Cache theo dấu vân gói, LRU **200** mục, hai tầng bộ nhớ + JSON. Tệp hỏng thì nạp thành rỗng, không ném |
| 4 | `data/slm_runtime.dart` | Tệp **duy nhất** chạm `flutter_gemma`; **test quét thứ 16** canh |
| 5 | `data/mo_hinh_tai_ve.dart` | Bốn trạng thái, tiến độ, huỷ, xoá. Gọi `tai()` hai lần chồng nhau chỉ chạy **một** lượt |
| 6 | `data/slm_dien_giai.dart` | Bản `BoDienGiai` **thứ hai**, **sáu** nhánh lùi về mẫu câu; nạp lười, đúng một lần mỗi phiên |
| 7 | `presentation/pages/cai_dat_ai_page.dart` · `data/cong_tac_ai.dart` | Màn Cài đặt AI + route `/ai-settings` + nối DI. Bốn đăng ký **lazy** (`SlmRuntime`/`MoHinhTaiVe`/`SlmCache`/`CongTacAi`), **cố ý không đăng ký `BoDienGiai`** — lối B |
| 8 | `ai_chat/…/ai_chat_page.dart` · `ai_edge/data/nguon_goi_so.dart` · `kiemSoNhieuGoi` | Màn Trợ lý AI chạy thật, **đóng A11** |

**Task 8 — màn Trợ lý AI.** Bản cũ là **mockup tĩnh**: in *"Bạn đã chi 3.200.000đ"* và *"Ăn uống
tăng 35% (chủ yếu là Cafe & ShopeeFood)"* — những con số không đến từ dữ liệu nào — cộng **năm**
nút không có handler. Đúng loại lỗi mà thẻ "Insight AI" (A6) đã phải gỡ.

Nay bốn chip là **câu hỏi thật**, gửi đi y như khi người dùng tự gõ (một đường, không bốn nhánh
mã); hỏi tự do đi qua `chuDeBiChan` **trước** khi gọi mô hình; câu trả lời hiện **kèm thẻ số liệu**
(điều kiện 12), và thẻ chỉ gồm những con số câu ấy **thật sự nhắc tới** — không phải mọi số của cả
mọi gói (bốn lúc Task 8, **sáu** từ việc số 1 tối cùng ngày), kẻo thẻ thành tiếng ồn thay vì nguồn kiểm chứng. Ô nhập **và chip** khoá theo cùng một
điều kiện; khoá ô mà để chip hỏi được là mở một đường vòng quanh chính cái khoá ấy.

Hai thứ mới ở tầng dưới. **`ai_edge/data/nguon_goi_so.dart`** là chỗ **duy nhất** dựng gói số mà
không đứng trên state của một trang — sáu khối Nhận xét đều lấy từ trang của chúng, còn màn Trợ lý
AI không thuộc trang nào. *(Đúng tới 2026-09-23: từ lát 4b bốn adapter tool cũng tự đọc
repository; lớp này nay chỉ dựng sáu gói cho bậc 1 — nhánh lùi L1.)* ⚠️ Nó đọc **`.first`** chứ không nghe lâu dài: một câu trả lời là *ảnh
chụp tại lúc hỏi*; nghe tiếp thì câu đã hiện nói một đằng còn số liệu sau lưng nó đổi một nẻo, mà
người dùng không có cách nào biết. Và **`kiemSoNhieuGoi`** — ⚠️ **không phải `goi.any(kiemSo)`**:
viết thế là đòi cả câu nằm gọn trong **một** gói, nên một câu hoàn toàn đúng kiểu *"tháng này chi
X, mục tiêu còn thiếu Y"* bị chặn, im lặng. *(Từ tối 2026-09-22 nó là vế đầu của `kiemCauTraLoi`, cùng `kiemNhan` và `kiemGiong`.)*

⚠️ **Ba nhãn nói dối, cả ba chỉ máy ảo thấy** (sửa cùng ngày, `66b6a09`) — cùng một họ: một câu chữ
khẳng định điều không đúng với trạng thái thật, và `flutter test` mù vì mỗi ca chỉ dựng một nhánh.

1. **Băng nhắc gộp hai lý do làm một.** Ô nhập khoá vì *chưa tải mô hình* **hoặc** vì *công tắc
   đang tắt*, mà câu chỉ có một — người đã tải xong 2,41 GB rồi tự tắt công tắc sẽ đọc *"chưa có
   mô hình trên máy"* và đi tải lại thứ đang nằm sẵn trong máy. Nay là hàm thuần
   `cauKhoaHoiDap(coTep:)`.
2. **Quay lại từ Cài đặt AI thì màn Trợ lý không đọc lại trạng thái** — `initState` chỉ chạy một
   lần, `pop` không dựng lại State, nên tắt công tắc ở màn kia rồi quay về vẫn thấy chip xanh và ô
   nhập mở; bấm vào mới biết là không. **Cùng họ G48.** Nay `_moCaiDatAi()` `await` lời `push` rồi
   đọc lại; ca test phải dựng **`GoRouter` thật** vì `push`/`pop` chính là thứ cần tái hiện.
3. **Chip "Hoạt động" ở màn Cài đặt AI** vẫn xanh khi công tắc đã tắt — một lời khẳng định đặt
   ngay trên chính cái công tắc đang nói ngược lại, và người dùng tin cái chip.

⭐ **Mẹo nghiệm thu đáng giữ:** dựng trạng thái *"đã có mô hình"* bằng một **tệp giả**
(`adb shell run-as com.flowmoney.flowmoney cp <tệp bất kỳ> files/gemma-4-E2B-it.litertlm`, **xoá
sau khi đo**). Nhờ nó đo được cả những nhánh mà không tải 2,41 GB thì không bao giờ tới — và gói
`flutter_gemma` tự từ chối tệp ấy (*"too small: 354 bytes (minimum: 1048576)"*) nên **nhánh lỗi
cũng chạy thật**: chip → gói số nạp được → nạp mô hình hỏng → câu lỗi, **không màn đỏ**.

⚠️ **`pubspec` thêm HAI gói, không phải một**: `flutter_gemma: 1.8.3` (ghim **cứng** như `fl_chart`)
và `flutter_gemma_litertlm: ^1.7.0` *(nâng lên **1.9.0** / **1.8.0** ngày 2026-09-23 — bản cũ sập
native ở mọi phiên có tool; khối lát 4b đầu mục này)*. Core **không kèm engine nào** — thiếu gói thứ hai thì
`getActiveModel()` ném *"add the engine package"*, điều P1 đã đo (mục 8.5 `AI_EDGE_FEATURE.md`).

⚠️ **Ba lỗi của kế hoạch, cả ba bắt được bằng bản sai có chủ ý** — ghi lại vì chúng cùng một họ
*"ca test xanh mà không canh gì"*:

1. Bản vá `_dongMuc` (viết ở chặng 1) thiếu `import 'nhan_xet.dart'` → không biên dịch được.
2. Ca few-shot cắt khối bằng `indexOf('Số liệu:
Ngân sách')`, mà chuỗi ấy nằm **trong chính ví dụ
   1** → khối cắt ra chỉ còn cái nhãn `"Ví dụ 1."`. Nay dùng `lastIndexOf` và bỏ dòng nhãn.
3. Ca canh luật *"không bỏ dấu khi so"* dùng câu thử *"Tuần đầu tháng"* — bỏ dấu ra `tuan dau thang`,
   **không** chứa `dau tu`, nên ca **xanh cả trên bản bỏ dấu**. Chính chú thích của ca nêu ví dụ
   đúng là *"đầu tuần"* (`dau tuan` **có** chứa `dau tu`). Đã sửa, và bản sai nay làm nó đỏ.

✅ **Hai chốt quan trọng nhất đã chứng minh canh thật**: tắt `kiemSo` thì ca *"câu BỊA SỐ"* đỏ; tắt
`kiemGiong` thì ca *"câu ĐỦ SỐ nhưng SAI GIỌNG"* đỏ. Bộ kiểm giọng dựng ở chặng 1 nay có chỗ dùng.

**Màn Stitch Cài đặt AI:** `1da347e753964e15a91b10c473975923` (2026-09-22), ✅ **người dùng đã xem
và xác nhận cùng ngày**, Task 7 dựng theo nó. ⚠️ API lại ghi `DESKTOP` dù truyền `MOBILE` (lần thứ
ba), và ba trạng thái xếp dọc trong màn là để **so sánh khi thiết kế**, không phải bố cục thật —
bản Flutter dựng **một** trạng thái tại một thời điểm.

⚠️ **Ba chỗ kế hoạch P3 lệch mã thật, lộ ra khi thi công Task 7** — hai chỗ đầu sẽ tái phát ở
Task 8, nên đọc trước khi làm tiếp:

1. Kế hoạch lưu công tắc bằng `SharedPreferences`; **dự án không có gói ấy** (`pubspec.yaml`, đo
   2026-09-22). Nơi lưu tuỳ chọn của dự án là `flutter_secure_storage` — `CongTacAi` theo đúng
   khuôn `SecureStorageNotificationPrefsStore`, giữ nguyên tên khoá `ai_tren_may_bat`, **một khoá
   cho cả máy** (thứ nó gác là tệp mô hình, tài sản của *máy* chứ không của *tài khoản*).
2. Kế hoạch tải mô hình bằng `sl<Dio>()`. `AuthInterceptor.onRequest` gắn `Authorization: Bearer`
   vào **mọi** request và **không lọc host**, mà đích là `huggingface.co` — dùng chung Dio của dự
   án là **gửi access token của người dùng cho một bên thứ ba, im lặng**. Bản thi công dùng
   `Dio()` trần: tải một tệp công khai không cần thứ gì của phiên đăng nhập.
3. Ca test thứ ba của kế hoạch (`find.textContaining('không')`) **đỏ trên cả bản đúng** —
   `textContaining` phân biệt hoa thường, còn câu hứa bắt đầu bằng *"Không"*. Ca nay đòi thẳng
   câu hứa và đòi ở **cả hai** trạng thái.

**Dọn cache SLM khi đổi tài khoản** (Step 5b) nằm ở `AuthBloc._donDuLieuTaiKhoanKhac`, dùng chung
cho **cả hai** chỗ gọi `purgeDataForOtherAccounts`. ⚠️ Điều kiện là **chính số hàng hàm ấy vừa
xoá** (`removed > 0`), không phải một phép so `idaccount` thứ hai — hệ quả **cố ý**: đăng xuất rồi
đăng nhập lại **cùng** tài khoản thì cache được **giữ**, vì vứt nó là vứt tới 200 câu mà mỗi câu
đã trả 2,3 giây chạy mô hình để có. Hai ca canh hai chiều, và **cả hai đã thử bằng bản sai**: bỏ
phép dọn → ca "đổi tài khoản" đỏ; dọn vô điều kiện → ca "cùng tài khoản" đỏ.

✅ **Nghiệm thu máy ảo 411dp ngày 2026-09-22**: màn dựng đúng Stitch, **0 sọc tràn**; công tắc tắt
→ thoát trang → vào lại **vẫn tắt** (đo đầu-cuối `CongTacAi` trên kho thật). ⚠️ Lối vào lúc nghiệm
thu là **nối tạm** nút bánh răng của màn Trợ lý AI, **không commit** — nút ấy là việc của Task 8,
nên tới khi ấy `/ai-settings` mới có lối vào thật.

*(⚠️ Đoạn dưới là lịch sử của bản Dio — **đã thay** bằng `NguonTaiNen` / `background_downloader` tối 2026-09-22 (lát tải nền + resume): `DauHuy`, `taiTep` và `tai_tep_dio.dart` **không còn**; huỷ nay là `nguon.huy()` và tệp dở được **giữ** cho lượt sau. Giữ đoạn vì nó giải thích vì sao phép huỷ phải là lệnh tới engine chứ không phải một cờ.)*

✅ **Nút "Huỷ" cắt thật lượt tải — sửa cùng ngày, sau Task 7** (`f51e2d6`). Lỗi: `huy()` chỉ đặt
một cờ `bool`, còn `taiTep` vẫn được `await` tới khi tải xong **trọn 2,41 GB** rồi mới ném và xoá
tệp — người dùng bấm Huỷ thì màn quay về *"Chưa tải"* trong khi máy vẫn tải hết ở nền. Cờ chỉ trả
lời được khi **có ai hỏi**, mà `Dio.download` không hỏi: nó cần được **báo**. Nay là `DauHuy` — một
`Completer` **cho mỗi lượt tải** — và `CancelToken` ở đầu Dio. Huỷ về trạng thái `chuaTai` chứ
không `loi`: người dùng vừa chủ ý bấm nút. Phép tải thật tách sang `data/tai_tep_dio.dart` **để đo
được** — bản đầu viết inline trong `injection_container.dart`, và đó đúng là lý do không ca test
nào với tới nó suốt hai task.

⚠️ **Bài học của lượt đo ấy, dùng được cho mọi phép đo mạng: `HttpResponse.flush()` của `dart:io`
về TRƠN TRU trên cả một kết nối đã chết.** Server dựng bằng `HttpServer` để đếm *"còn gửi thêm bao
nhiêu byte sau khi huỷ"* báo **vẫn đang chảy** — 194 gói ≈ 13 MB trong 2,4 giây — và suýt nữa làm
kết luận ngược hẳn: rằng phép huỷ hỏng. Dựng lại bằng **`ServerSocket` thô**, nơi `onDone` của
luồng đọc báo đúng lúc đầu kia gửi FIN, thì con số thật là **thêm 0 gói**. Ba mức đo, hai mức đầu
nói sai. Cũng nhờ nó mà `dio.close(force: true)` bị **loại**: đo được nó chỉ bớt đúng một gói đang
bay (64 KB trên 2,41 GB).

**Mức nền:** `flutter test` **3341/3341, 2 skip**; `flutter analyze` **26**; schema **v24** không
đổi; payload không đổi; bộ `ai_edge` **25** tệp / **199** test, bộ `ai_chat` **1** tệp / **14** test.

### ✅ Edge AI chặng 1 — chặn lỗi và tài liệu trước P3 (2026-09-22) — XONG TRỌN 6 TASK

Chặng 1 của lộ trình `docs/superpowers/plans/2026-09-21-lo-trinh-edge-ai-agent-rag.md`.

**Task 1 — `kiemGiong`, bộ kiểm GIỌNG đứng cạnh `kiemSo`.** `kiemSo` chỉ hỏi *"mọi con số
trong câu có trong gói không?"*, **không** hỏi *"câu có diễn giải đúng những con số ấy
không?"*. Câu *"Bạn đang kiểm soát tốt — mới dùng 45.000 đ trên hạn mức 50.000 đ (90,0%),
còn 11 ngày"* qua được bộ kiểm số dù 90 % trong 11 ngày là **sắp vượt**. Hệ luật **đã biết**
mức (`MucNhanXet`), chỉ là chưa ai đối chiếu câu với mức. Hàm thuần ở
`ai_edge/domain/kiem_giong.dart`, 8 ca test. ⚠️ **Blocklist theo CỤM, không theo từ**, kèm
kiểm phủ định trong **ba từ** trước cụm: *"chưa kiểm soát tốt"* là cảnh báo, không phải trấn
an — blocklist theo từ đơn sẽ vứt nhầm câu đúng ấy. Bản sai (cửa sổ phủ định = cả câu) làm
đúng một ca đỏ. Bẫy **4.3b** `AI_EDGE_FEATURE.md`.

⚠️ Lỗ hổng này **chưa cắn** khi viết (P3 chưa chạy), nên phần nối khi ấy nằm ở **kế hoạch P3**
chứ không ở mã — ✅ **và đã nối thật vào mã ngày 2026-09-22**, P3 Task 6: `SlmDienGiai` gọi
`kiemGiong` ngay sau `kiemSo`, có ca canh và bản sai chứng minh. Phần dưới giữ nguyên làm hồ sơ
của quyết định: Task 1 của nó nay có `_dongMuc` (prompt chở dòng **MỨC** xuống, để mô hình thôi tự "đánh
giá" từ số), Task 6 gọi `kiemGiong` ngay sau `kiemSo`. **Sửa kế hoạch rẻ hơn sửa mã.**
⚠️ Hai lớp giả của kế hoạch ấy (`_GoiGia`, `_Goi`) cố định `MucNhanXet.binhThuong` nên phải
nhận thêm tham số `muc` — không có nó thì ca "sai giọng" **không dựng được**.

**Task 2 — giao diện NÓI RA "cần thêm N ngày dữ liệu" thay vì im.** `cuaSoNhinLai` trả `null`
dưới 14 ngày — đúng luật — nhưng giao diện gộp *"không có gì để gợi ý"* và *"chưa đủ dữ liệu
để gợi ý"* thành cùng **một sự im lặng**, và chính sự im lặng ấy đã che `suggestAmount` chết
suốt hai tuần. Hàm thuần `soNgayConThieu` + `BudgetRepository.soNgayCoDuLieu` + thẻ
`TheChuaDuDuLieu` trên trang danh sách + nhãn form. **Ngoại lệ có chủ ý** với luật *"khối rỗng
thì ẩn hẳn"* (mục 3.34 `ANALYTICS_FEATURE.md`): *"cần thêm 6 ngày"* **là** tin.

⚠️ **Bốn chỗ dễ vấp.** (1) Cubit chỉ hỏi tuổi dữ liệu khi **không** có đề xuất — bản sai
`if (true)` làm đúng một ca đỏ, và một phép đọc thừa ở mỗi lần phát lại stream là giá thật.
(2) Trường mới phải đi vào **cả hai** đường phát của `_phat` — đúng bẫy *"`_phat` thoát sớm"*.
(3) Kế hoạch viết `if (state.deXuat == null && state.soNgayConThieu case final thieu?)` —
**không biên dịch được**, `case` không kết hợp với `&&` như thế; dạng đúng là
`if (state.soNgayConThieu case final thieu? when state.deXuat == null)`. (4) Ca *"có đề xuất
thì thẻ đề xuất thắng"* dựng `thieu: null` nên **không canh** được vế `when` ấy — bỏ vế đi mà
ca vẫn xanh; nay có ca thứ tư dựng **cả hai** khác `null` (trạng thái cubit không bao giờ tạo
ra, nhưng đó chính là lớp phòng thủ thứ hai), và bản sai làm nó đỏ.

⚠️ Kế hoạch đoán **bảy** lớp giả `implements BudgetRepository` cần thêm phương thức; thực tế
**một** — sáu tệp kia dùng `noSuchMethod`. Đo bằng `flutter analyze`, đừng sửa mù theo danh
sách trong kế hoạch.

**✅ Nghiệm thu máy ảo 411dp (2026-09-22, `emulator-5554`, tài khoản 10).** Trạng thái "tài
khoản trẻ" **không tồn tại** trên máy ảo (tài khoản 10 có 19 ngày dữ liệu), nên nó được dựng
bằng cách **tạm nâng `kSoNgayToiThieu` lên 25** rồi build — không tạo tài khoản rác, không
sửa dữ liệu người dùng, và đo đúng thứ `flutter test` mù. Kết quả: thẻ nói *"Cần thêm 6 ngày
dữ liệu để gợi ý ngân sách."* đứng **dưới** thẻ "Đề xuất cân đối" và **trên** tiêu đề "Danh
mục chi tiêu"; nhãn form nói *"Cần thêm 6 ngày dữ liệu để gợi ý hạn mức."* và **không** có
nút "Dùng số này" (không có số nào để dùng); `RenderFlex overflowed` = **0** suốt phiên. Hằng
đã trả về 14 và máy ảo đã cài lại bản thật.

**Task 3 — phép kiểm chạy trên CSDL THẬT.** Bộ test **mù** với đầu vào chết: nó dựng sẵn dữ
liệu. `test/tool/kiem_csdl_that_test.dart` là một `flutter test` `skip: true` (chạy tay bằng
`--run-skipped`, cùng nếp `tao_icon_app_test.dart`) đọc một tệp SQLite **chép từ máy**, in
bảng đo rồi **thất bại có tên** khi một gói số đáng ra phải nuôi được lại rỗng.

⚠️ Đường tệp thật là **`app_flutter/flowmoney.db`** (không phải `.sqlite`), và phải chép cả
`-wal` lẫn `-shm`: đo 2026-09-22 thấy tệp chính mốc **19/09** còn WAL mốc **21/09**, tức mọi
giao dịch gần đây nằm trong WAL — chép mỗi tệp chính là phép đo báo *"thiếu dữ liệu"* **sai**
(bẫy 4.9). Lệnh đầy đủ ở mục "Lệnh hay dùng" `CLAUDE.md`.

**Phép đo đầu tiên, tài khoản 10:** tuổi dữ liệu **19** ngày · cửa sổ **19** ngày · **5/11**
danh mục chi gợi ý được (Di chuyển 570k · Giáo dục 80k · Giải trí 50k · Mua sắm 100k · Ăn
uống 80k). ⭐ Trước lát *"cửa sổ nhìn lại"* con số ấy là **0/11** trên **mọi** tài khoản, im
lặng — nên đây là **bằng chứng lát hôm qua sống thật trên dữ liệu thật**, không chỉ trong
fixture.

**Task 4 — thuật ngữ Edge AI.** Đổi ở **văn bản**, giữ tên thư mục mã `lib/features/ai_edge/`
(đổi là sửa 36 tệp import + 3 test quét để không ai ngoài nhóm thấy khác biệt). Banner đầu
`AI_EDGE_FEATURE.md`, mục 10.1 viết lại, mục **1.2** mới ở `AI_AGENT_ARCHITECTURE.md`. Câu
*"công nghệ thập niên 1980"* đã bỏ: nó đúng về kỹ thuật nhưng mời gọi cách đọc sai về cả mảng,
và người dùng đã vấp thật. ⚠️ **`grep` BỎ SÓT một dòng tiếng Việt** trong lượt soát (cụm *"hệ
chuyên gia"*), Python đọc tệp thì bắt đúng — đây là lần thứ ba công cụ lọc dòng làm sai một
kết luận trong dự án này.

**Task 5 — tài liệu cho backend.** `EDGE_AI_THUAT_NGU_VA_HAI_MAU_THUAN.md` (đặt vào `CAN-LAM/`
ngày ấy; **nay ở `DA-XONG/`** — backend đóng ở `b147fee` 2026-09-22): tên gọi,
mâu thuẫn ① (F1 *"không rời thiết bị"* vs `Standard_RAG.md:169` *"toàn bộ dữ liệu tài chính của
User"*), mâu thuẫn ② (tầng 3 classifier gửi mô tả giao dịch sang Gemini trong khi backend mã hoá
`Note` at-rest). ⚠️ Đo hôm nay **chặt hơn** bản đo 2026-09-21: `.env` **không khai** hai khoá API
ấy (16 biến), nên tầng 3 **chưa từng chạy một lần nào** — đó là lý do nó là *quyết định*, không
phải *sự cố*. ⚠️ `CAN-LAM/` khi ấy có **ba** tệp xin, đừng tin mục 0 của README. *(Cập nhật
2026-09-22 tối muộn: backend đóng **cả hai** tệp AI ở `b147fee` — tệp này và
`AI_EDGE_SLM_SUA_TAI_LIEU.md` — client kiểm lại bằng máy rồi chuyển sang `DA-XONG/`. Hai việc của
tệp này đo được là xong thật: `grep "AI Edge"` trong `docs/AI/` ra **0** dòng, và `Standard_RAG.md`
§6 đã chốt lối ① — số liệu cá nhân đi bằng function-calling, không index lên vector DB server. Nay
`CAN-LAM/` có **hai** tệp: `CLIENT_BO_LIEN_KET_NGAN_HANG.md` và đơn vòng **hai**
`AI_EDGE_SLM_SOAT_SAU_B147FEE.md` — **`ls` lại, đừng chép con số này**.)*

**Task 6 — spike RAG on-device, đo trên máy thật.** Bảng đo đầy đủ ở mục **5.5**
`AI_AGENT_ARCHITECTURE.md`. Ẩn số 1 **đạt**: `flutter_gemma_rag_sqlite` **1.3.2** tương thích
`flutter_gemma` 1.8.3, và KNN chạy **trong SQLite** qua `sqlite-vec` chứ không brute-force Dart.
Ẩn số 2 **chặn**, và đó là câu trả lời:

🛑 **M4 = KHÔNG làm RAG phía client.** Kiến thức chung chuyển sang **backend RAG** (chặng 6);
client gọi một endpoint, và câu *"có áp dụng RAG"* vẫn đúng, chỉ là đúng ở phía server. Ba con số
quyết định: mô hình embedding **tải tự do duy nhất là Gecko 110M English-only** → top-3 đúng
**3/5** trên câu hỏi tiếng Việt; **mọi** bản EmbeddingGemma đa ngữ trả **401** (gated), kể cả
`litert-community/embeddinggemma-300m`; truy vấn **251 ms** và index **253 ms/đoạn**, trên ngưỡng
200 ms đặt trước. RAM đỉnh 533 MB PSS, chiều vector 768, tổng tải nếu ship ~2,52 GB.

⚠️ **Ba lỗi đáng nhớ nếu ai đó mở lại hướng này.** URL Gecko trong `embedding_models.dart` của gói
trả **404** (tệp thật tên `Gecko_<seqlen>_{quant,f32}.tflite`); bảng cùng tệp khai
`needsAuth: true` cho **cả năm** mục, đúng với EmbeddingGemma nhưng **sai với Gecko**; và chữ ký
API thật khác kế hoạch spike ở ba chỗ (`RetrievalResult` mang `id`/`similarity` chứ không
`document`/`score`, entry point là `FlutterGemmaPlugin.instance`, và `install()` **đã** tự đặt
active embedder). Build app spike còn vấp `Could not close incremental caches` mà **`flutter
clean` không cứu được** — chỉ khỏi khi đặt `kotlin.incremental=false`.

**Mức nền sau trọn chặng:** `flutter test` **3268/3268, 2 skip**; `flutter analyze` **26**;
schema **v24** không đổi; payload không đổi. Máy thật **OnePlus 13R `CPH2691` đã nối `adb`**
(kiểm 2026-09-22) — điều kiện vào chặng 2 (P3) đã thoả, bẫy driver `DeviceInterfaceGUIDs`
không tái phát. ✅ **Chặng 2 đã bắt đầu cùng ngày và xong Task 1–7/10** — xem khối *"Edge AI chặng 2"* ở đầu mục 14.

### ✅ Cửa sổ nhìn lại, và thẻ "Chưa đặt ngân sách" (2026-09-21)

Spec: `docs/superpowers/specs/2026-09-21-cua-so-nhin-lai-va-de-xuat-tao-ngan-sach-design.md`
Kế hoạch: `docs/superpowers/plans/2026-09-21-cua-so-nhin-lai-va-de-xuat-tao-ngan-sach.md`

**Trọn sáu Task xong ngày 2026-09-21.** Task 1–5 là cái nền cộng hai phép
sửa cho thứ đang chạy; Task 6 là thứ người dùng nhìn thấy — thẻ *"Chưa
đặt ngân sách"*.

#### Vì sao việc này tồn tại: một giả định bị phép đo lật

Mục ④ của danh sách việc ghi *"`suggestAmount` đã có số"*. **Sai.** Đo trên CSDL
dev: **79** giao dịch sống, giao dịch **sớm nhất 02/09/2026**, **0** hàng trước
tháng 9. `suggestAmount` cộng **ba tháng lịch đã đóng**, nên nó trả `null` cho
mọi danh mục, mọi tài khoản — và sẽ còn thế tới 01/10/2026.

Hai hệ quả, cái thứ hai là **lỗi đang chạy chứ không phải việc mới**:

1. Dựng thẻ trên nền hàm ấy thì thẻ **không bao giờ hiện**, im lặng.
2. **Gợi ý hạn mức trong form tạo ngân sách chết sẵn từ 2026-09-06** — nó vẫn
   gọi `suggestAmount` ở mỗi lần chọn danh mục và vẫn luôn nhận `null`.

Lượt soát bán kính tìm ra **thành viên thứ hai** của cùng một họ:
`_thuNhap3Thang` cũng cắt ba tháng lịch liền trước → trả **0** → phép neo ngưỡng
theo thu nhập (chặng 1.1, làm **cùng ngày**) luôn rơi về sàn. **Mã đúng, đầu vào
chết.** Quét `lib/features/` cho thấy **đúng hai** thành viên, không hơn.

#### Đã làm

| Task | Commit | Nội dung |
|---|---|---|
| 1 | `f9bb768` | `cuaSoNhinLai` — hàm thuần, định nghĩa duy nhất (5 ca) |
| 2 | `6b6090d` | `getFirstTransactionDate` + `mocGiaoDichDauTien` (4 ca) |
| 3 | `5aad143` | `suggestAmount` đổi sang cửa sổ cuộn (7 ca, viết lại cả nhóm) |
| — | `8569efe` | Nhãn gợi ý thôi nói dối về cửa sổ (1 ca) |
| 4 | `238eb29` | `_thuNhapMoiThang` đổi cửa sổ + đổi tên lan sang DI, mảng AI, tài liệu |
| 5 | `05ea6c4` | `chonDeXuat` + trường state + nối cubit (10 ca) |
| 6 | — | Thẻ trên trang Ngân sách, form điền sẵn, nhãn nêu số ngày (13 ca) |

**Luật:** cửa sổ `[from, now)` với `from = max(now − 90 ngày, giao dịch đầu
tiên)`; dưới **14** ngày thì trả `null` và người gọi **im hẳn**; quy về mức tháng
bằng `tổng / số ngày × 30`. Dùng chung **cửa sổ**, **không** dùng chung phép
cộng — hai chỗ gọi cộng hai thứ khác nhau, và gộp cả phép cộng sẽ làm mờ luật
*"thu nhập không gồm tiền đi vay"* (bẫy A8 #8).

#### Bốn cái bẫy, mỗi cái một ca test

1. ⚠️ **Mẫu số là tuổi dữ liệu của TÀI KHOẢN, không phải của danh mục.** Lấy
   theo danh mục thì một danh mục phát sinh **hôm qua** có mẫu số 1 ngày và mức
   tháng phồng **hàng chục lần** — con số trông hoàn toàn hợp lý.
2. ⚠️ **Cửa sổ đóng ở đầu sau** (`to = now`). CSDL thật có giao dịch ghi **ngày
   tương lai** (khoản trích mục tiêu 10/10, 10/11); cửa sổ hở sẽ nuốt tiền
   **chưa tiêu** vào một con số nói về quá khứ.
3. ⚠️ **`_phat` của `BudgetCubit` THOÁT SỚM** khi `taiPhanBoNguon == null`. Đề
   xuất phải tính **trước** phép rẽ ấy và đi vào **cả hai** đường phát; đặt sau
   là để thẻ không bao giờ hiện ở mọi chỗ không nối nguồn Tầng 2 — và một thẻ
   không hiện trông y hệt một thẻ không có gì để nói.
4. ⚠️ **Mốc đầu tiên phải bỏ hàng đã xoá mềm**, kẻo mẫu số dài ra bằng dữ liệu
   người dùng đã bỏ đi và mọi mức tháng nhỏ đi.

#### Đã chứng minh trên máy thật

Nghiệm thu sau Task 3: danh mục **Giải trí** hiện **"50.000 đ"** kèm nút *Dùng số
này* — `30.000` chi trong cửa sổ 20 ngày → `30.000 / 20 × 30 = 45.000` → làm
tròn lên. **Lần đầu con số ấy hiện ra trên dữ liệu thật kể từ 2026-09-06.**

⚠️ Cùng ảnh chụp lộ một chỗ kế hoạch bỏ sót: nhãn vẫn nói *"3 tháng gần nhất"*.
Câu ấy **đúng trước** Task 3 và thành lời nói dối ngay sau — và không ca test nào
canh nó. Đã sửa (`8569efe`).

#### Task 6 — thẻ "Chưa đặt ngân sách"

Thẻ đứng **dưới** khối Nhận xét / thẻ kế hoạch và **trên** tiêu đề *"Danh mục chi
tiêu"*: tối đa **3** dòng (biểu tượng danh mục · tên · *"khoảng X mỗi tháng"* ·
nút **Tạo**), một chip *"N nhóm"*, và dòng phụ *"Suy từ N ngày gần nhất"* **chỉ**
khi cửa sổ ngắn hơn 90 ngày. Màn Stitch `eb872aa9a0ba44ca8bf1c92d8d53186c`.

Nút **Tạo** mở `/budget/rules?category=<id>&amount=<số>` — form tạo mới đã điền
sẵn danh mục và số tiền. **Người dùng chốt cùng ngày**: nhãn gợi ý của form cũng
**nói ra số ngày** — *"Bạn chi trung bình 50.000 đ mỗi tháng, suy từ 19 ngày gần
nhất"* — vì thẻ đã hứa như thế thì form mở ra từ nó không được lùi về một lời hứa
mơ hồ hơn. Độ dài cửa sổ đi qua `BudgetEditorReady.soNgayCuaSo`.

⚠️ **Bốn chỗ dễ vấp:**

1. **Widget không quyết định ẩn hay hiện.** `chonDeXuat` trả `null` khi không có
   gì để gợi ý, và `BudgetTabsView` không dựng thẻ. Cho widget tự nhận một danh
   sách rỗng rồi tự trả `SizedBox.shrink()` là chép luật ẩn ra chỗ thứ hai.
2. **Giá trị điền sẵn chỉ có hiệu lực ở đường TẠO MỚI.** `editing != null` thì
   ngân sách đang sửa thắng — đè lên nó là lặng lẽ đổi hạn mức đã đặt.
3. **`null` của `soNgayCuaSo` là *chưa biết*, không phải một con số để đoán** —
   nhãn im vế ấy. Phép đo độ dài cửa sổ hỏng thì form **vẫn mở**, không thành
   `BudgetError`: nó là phần phụ của một nhãn.
4. `_openEditor` dựng đường dẫn bằng **`Uri(queryParameters:)`**, không nối chuỗi
   tay — một ký tự cần thoát lọt vào thì form mở ra trống trơn, không lỗi nào.

#### Nghiệm thu máy ảo 411dp — và một phép đếm sai của chính kế hoạch

Đạt đủ năm điểm: thẻ **hiện thật**; dòng phụ nói *"Suy từ 19 ngày gần nhất"*; bấm
**Tạo** mở form đã điền *Giải trí* + `50000` kèm nhãn có số ngày; lưu xong thì
danh mục **rời khỏi thẻ** — và vì nó là ứng viên duy nhất, cả thẻ **ẩn hẳn**, đúng
luật ở mục 3.34 `ANALYTICS_FEATURE.md`; **0** sọc tràn (logcat không một dòng
`RenderFlex overflowed`). Xoá ngân sách thử thì danh mục **quay lại thẻ** — dữ
liệu thật đã trả nguyên trạng (xoá mềm, quy tắc 5; bản ghi mang `Delete_at` trên
server).

🛑 **Kế hoạch đoán thẻ sẽ có HAI dòng — sai, và một dòng mới là đúng.** *Chi khác*
đã bị **xoá mềm** từ 05/09/2026 (cả bản sao của tài khoản lẫn hàng mặc định toàn
cục), nên `getExpenseCategories` loại nó — **đúng**, không ai đặt được ngân sách
cho một danh mục đã xoá. Phép đếm của kế hoạch cộng tiền theo danh mục mà **không
hỏi danh mục ấy còn sống không**. Bài học cũ: một kỳ vọng không khớp thì phải **đo
bằng đường thứ hai** trước khi kể tên một lỗi.

`flutter test` **3249/3249, 1 skip**; analyze **26 issue, 0 error**; bộ `budget`
**28 tệp / 234 test**. **Schema không đổi**, vẫn v24; **payload không đổi**.

### ✅ Soát "khối Phân tích nào chưa tự ẩn khi rỗng" (2026-09-21)

Mục **3.34** `docs/ANALYTICS_FEATURE.md`. Đây là **bản rẻ tiền của "AI chọn khối
đáng xem"** (bảng mục 11 `AI_EDGE_FEATURE.md`): trước khi xếp hạng khối nào đáng
đọc, các khối phải tự biết im khi chẳng có gì để nói đã.

**Kết quả: 15 loại khối (16 chỗ dựng — `_KhoiVayNo` dùng hai lần; đếm bằng máy 2026-09-21), đúng MỘT khối không có chốt nào** — `_KhoiSoLieuNhanh`. Mọi
khối khác đều tự ẩn, bằng chốt ngoài ở `_than()` hoặc chốt trong chính widget.
Cả **ba** chỉ số của khối ấy đều nói về **chi**, nên một kỳ không có khoản chi
nào cho ra một thẻ gồm `0 đ` và **hai dấu `—`**.

⚠️ **Ca ấy đạt tới được và KHÔNG rơi vào nhánh `thongKe.rong`** — nhánh ấy đòi
`thu == 0` **và** `chi == 0`, nên một kỳ chỉ có thu đi thẳng vào thân trang.

**Nghiệm thu máy ảo dựng đúng trạng thái ấy**: thêm một khoản `Lương` hôm nay,
xem kỳ `21/09 – 21/09`, rồi **xoá khoản ấy qua giao diện** để cờ xoá đi đúng
đường đồng bộ (toast *"Đã đồng bộ xong"*, số liệu trở về đúng mức trước khi
thử). Thấy tận mắt: khối biến mất, và donut tự rơi về nhóm **Thu** vì nhóm Chi
rỗng.

**Và dựng được trạng thái ấy thì lỗi thứ hai cùng hiện ra**: thẻ *Tổng chi* của
trang nối dấu **bằng tay** nên in `-0 đ` — chỗ **thứ ba** của bẫy **4.13**, sau
bảng "Phân bổ theo ví" (2026-09-15) và thẻ tổng trang Sổ giao dịch (sáng cùng
ngày). Cả ba đều do **máy ảo** bắt, không phải bộ test.

**Rồi phép quét mà tài liệu vừa khuyên, khi chạy thật, ra BỐN chỗ nữa** — cùng
đúng một khuôn `cond ? formatIncome(x) : formatExpense(x)`, vốn là nghĩa đen của
`formatCoDau(x, thu: cond)` trừ ca 0. Nên luật nay **đóng bằng máy**:
`test/core/utils/dau_tien_mot_noi_test.dart`, **test quét `lib/` thứ mười bốn**,
cấm mọi lời gọi hai hàm ấy ngoài `currency_formatter.dart`. ⚠️ Nó **khác** test
quét thứ mười một: cái kia canh **ký hiệu** `đ`, cái này canh **dấu**.

`flutter test` **3210/3210, 1 skip**; analyze **26 issue, 0 error**; bộ
`analytics` **21 tệp / 579 test**. **Schema không đổi**, vẫn v24; **payload
không đổi**; **không đụng repository**.

### ✅ Nghiệm thu máy ảo 411dp cho lát sổ giao dịch (2026-09-21)

**Task 5 Step 1** của `docs/superpowers/plans/2026-09-21-so-giao-dich-pham-vi-ky-va-loc-tien.md`
— việc dở dang cuối cùng của kế hoạch ấy, nay đóng. Lát vừa rồi đụng **cả ba**
vùng mù của `flutter test` (tràn bố cục · điều hướng qua `StatefulShellRoute` ·
thứ tự giữa hai luồng bất đồng bộ), nên 3200 ca xanh không nói gì về nó.

Máy đo được `1080×2400 / density 420` = đúng **411dp**. Sáu việc phải thấy tận
mắt: lùi/tiến kỳ bằng ‹ › ✅ · nhãn **Quý** (`Quý này (Q3 2026)`) và **Năm**
(`Năm nay (2026)`) không cụt ✅ · khoảng tuỳ chọn `10/09 – 12/09` bấm ‹ ra
`07/09 – 09/09`, **đúng độ dài 3 ngày** ✅ · lọc tiền cả ba dạng
(`500.000 – 1.000.000 đ` · `Từ 500.000 đ` · `Đến 100.000 đ`) với thẻ tổng đổi
theo ✅ · gõ ngược hai ô thì nút Áp dụng **xám** kèm câu lỗi ✅ · đường tắt "Xem
giao dịch" ⚠️ (xem G48). Sheet chọn phạm vi giữ **chiều cao cố định** khi đổi
đơn vị — đúng bất biến đã chốt. Không một sọc tràn vàng nào trên hơn hai mươi
ảnh chụp.

**Một xác nhận ngoài danh sách: G43 đóng thật trên máy.** Kỳ đang xem là *Năm
nay (2026)*, tức **vượt quá hôm nay** — đúng trạng thái từng làm nút "Tuỳ chọn"
chết im lặng — và bộ chọn mở được với khoảng khởi tạo **bị kẹp** thành
`1 thg 7 – 21 thg 9`, ngày 22 trở đi vô hiệu.

**Ba chỗ lệch, chỉ hai là của lát này.** Cả hai nằm ở **kỳ rỗng**, một trạng
thái hiếm gặp khi trang còn khoá theo tháng nhưng thành ca **thường** ngay khi
trang xem được năm đơn vị:

1. Câu trạng thái rỗng vẫn nói *"Chưa có giao dịch nào trong tháng này"* — chữ
   sót lại từ thời khoá theo tháng. Người xem một quý rỗng đọc được một câu nói
   về **một khoảng thời gian khác** thứ header đang chỉ. Nay là *"trong kỳ này"*;
   không nhắc lại tên kỳ vì header ngay trên đã nói.
2. Thẻ tổng in `+0 đ` và `-0 đ`, trong khi cột *Thu net* ngay cạnh vốn đã dùng
   `CurrencyFormatter.formatCoDau` nên hiện `0 đ` trần — tức **một thẻ đang hiện
   hai quy ước**. Luật *số 0 không mang dấu* ra đời 2026-09-15 từ một lỗi y hệt ở
   bảng "Phân bổ theo ví", cũng do máy ảo bắt. Phép sửa là cho hai cột kia đi qua
   cùng hàm ấy.

Chỗ thứ ba là **G48** — đường tắt *"Xem giao dịch"* thôi lọc sẵn ví nếu tab Giao
dịch đã mở trước đó trong phiên. ⚠️ **Không phải hồi quy của lát này**: nó có từ
khi `/transactions` vào shell (nhóm D, 2026-09-19). Đo được hai đường trên cùng
một máy, cùng một ví — app mới khởi động thì **đúng**, ghé tab trước thì **sai và
im lặng**. ✅ **Đã đóng cùng ngày** — xem khối ngay dưới.

### ✅ G48 — đường tắt "Xem giao dịch" lọc sẵn ví kể cả khi trang đã sống (2026-09-21)

`/transactions` nằm trong một `StatefulShellBranch`, và Navigator của nhánh
**giữ State sống**. Lần `go('/transactions?wallet=…')` thứ hai dựng một
`TransactionPage` mới cùng kiểu ở cùng vị trí, nên Flutter **cập nhật** State cũ
thay vì tạo State mới: `initState` không chạy lại và ví mới bị bỏ qua.

**Sửa:** `didUpdateWidget`, áp ví mới khi nó **thật sự khác** lần trước. Ba lối
từng cân nhắc khác nhau ở chỗ *ai làm chủ bộ lọc*; lối đã chọn **cố ý không trả
lời** câu rộng ấy mà chỉ chốt một điều hẹp và rõ: **một lệnh điều hướng có nêu
đích danh ví thì thắng bộ lọc đang có**. Câu *"bộ lọc có nên sống sót qua một
lần ghé tab"* vẫn để ngỏ, và lối "chuyển bộ lọc lên bloc" vẫn là đường đi nếu
ngày nào cần trả lời nó.

⚠️ **Hai chốt, hỏng im lặng theo hai chiều ngược nhau:** chỉ đổi khi ví **khác
lần trước** (áp lại ở mọi lần dựng lại là người dùng bỏ lọc ra rồi nó tự giành
lại — đúng cái bẫy mà chú thích `_filter` cảnh báo từ đầu, nên **không** gán
trong `build`); và `null` **không** có nghĩa *"hãy xem mọi ví"* (coi vậy thì bộ
lọc tự bay mất mỗi lần cây widget dựng lại).

**Test:** `so_giao_dich_loc_vi_ban_dau_test.dart`, **3** ca. Ca giữa **tái hiện
cơ chế của shell mà không cần cây route thật**: dựng trang với
`initialWalletId = null` rồi dựng lại **cùng vị trí** với một ví — `pumpWidget`
giữ State vì runtimeType và key không đổi. ⚠️ Cả ba **đỏ với dáng vẻ sai** ở lần
chạy đầu (*"không tìm thấy chuỗi nào"*) vì tệp thiếu `initializeDateFormatting('vi')`:
danh sách nhóm theo ngày dựng tiêu đề bằng `DateFormat` locale `vi`, thiếu nó
thì `LocaleDataException` làm **cả cây dừng dựng** — một triệu chứng chẳng liên
quan gì tới nguyên nhân. `so_giao_dich_chon_ky_test.dart` không vấp chỉ vì danh
sách của nó rỗng.

**Nghiệm thu máy ảo** (bắt buộc — widget test tái hiện *cơ chế*, không phải
router thật): chạy đúng kịch bản từng hỏng, chip ví bật và danh sách chỉ còn ví
ấy. Cùng ảnh chụp ấy xác nhận luôn thẻ Chi tiêu nay hiện `0 đ` chứ không `-0 đ`.

`flutter test` **3205/3205, 1 skip**; analyze **26 issue, 0 error**. **Schema
không đổi**, vẫn v24; **payload không đổi**.

**Test:** `test/features/transaction/presentation/so_giao_dich_ky_rong_test.dart`
— **2** ca cho hai lỗi đã sửa. Ca thứ hai **đòi kết quả chứ không chỉ đòi vắng
mặt** (`findsNWidgets(3)` cho `0 đ`): thiếu vế ấy thì một bản sai xoá hẳn thẻ
tổng cũng làm hai kỳ vọng kia xanh — cùng bài học G43. Toàn bộ: **3202/3202
pass, 1 skip**; `flutter analyze` **26 issue, 0 error**. **Schema không đổi**,
vẫn v24; **payload không đổi**.

### ✅ Sổ giao dịch — phạm vi kỳ và lọc theo số tiền (2026-09-21)

Nửa đầu việc **2.1** của `docs/superpowers/plans/2026-09-21-ai-viec-tiep-theo.md`.
Spec: `docs/superpowers/specs/2026-09-21-so-giao-dich-pham-vi-ky-va-loc-tien-design.md`.

Trang Sổ giao dịch thôi khoá theo tháng: nó xem được **tuần · tháng · quý · năm ·
khoảng tuỳ chọn** bằng chính `Ky` và `ChonPhamViSheet` mà trang Phân tích và Xuất
báo cáo đã dùng — **ba** trang nay chung một bộ chọn. Header là ba phần: ‹ lùi một
kỳ · nhãn giữa bấm được để mở sheet · › tiến một kỳ. Cộng một chip **"Số tiền"**
trên thanh lọc, mở sheet hai ô *từ … đến …*.

⚠️ **Kế hoạch gộp "lọc theo tiền" và "lọc theo ngày" làm một việc — khảo sát lật
điều đó.** Trang nạp dữ liệu **theo từng tháng**, nên khoảng tiền có nghĩa trọn vẹn
còn khoảng ngày thì không: thêm nó vào bộ lọc mà giữ bộ chọn tháng là đặt **hai bộ
điều khiển thời gian triệt tiêu nhau** trên cùng một trang (đặt khoảng 01/08–15/08
trong khi đang xem tháng 9 cho danh sách rỗng mà không nói vì sao). Người dùng chốt
lối B: khoảng ngày **thay luôn** phép buộc-theo-tháng.

**Năm thứ dễ vấp, cả năm hỏng im lặng:**

1. **Biên đổi từ đóng sang nửa mở.** `watchByMonth` cũ dùng `[ngày 1 00:00, ngày
   cuối 23:59:59]`; `watchKhoang` dùng `[from, to)` — đúng quy ước đã ghi trong
   **chính tệp DAO ấy** cho `tuanTruoc`/`tongThuChi`. Thay hẳn chứ không thêm hàm:
   giữ cả hai là để hai quy ước biên sống chung trong một DAO, và khi ấy khoản ghi
   đúng mốc giao giữa hai kỳ bị đếm vào **cả hai**.
2. **Bỏ phép lọc lần hai trong bloc.** `_emitLoadedState` từng lọc lại theo
   `(year, month)` — thừa, vì DAO đã trả đúng kỳ. State nay còn **một** danh sách
   `giaoDich` (đo trước khi gộp: không nơi nào đọc `state.transactions`).
3. **Ngưỡng nửa đồng khi so tiền.** `amount` là `double` và khoản điều chỉnh số dư
   mang đuôi lẻ có thật, nên một khoản đúng `500.000` mà máy giữ là
   `499999.99999994` sẽ rơi khỏi bộ lọc "từ 500.000" — không exception, không log.
4. **Sheet trả BA nghĩa khác nhau**: `null` = đóng không chọn (giữ nguyên bộ lọc) ·
   `KhoangTien()` rỗng = bấm Xoá (bỏ điều kiện) · có giá trị = bấm Áp dụng. Gộp hai
   cái đầu là bấm ra ngoài sheet cũng xoá mất bộ lọc đang có.
5. **Ô tiền phải vào lưới quét bằng TÊN CONTROLLER.** Test quét thứ tám nhận diện ô
   tiền theo tên, nên đặt tên lạ thì nó **im lặng không canh gì** — hai tên mới vào
   danh sách **trước** khi dựng widget.

`KhoangTien` (`transaction/domain/khoang_tien.dart`) mang **cả phép so**, nên
`applyTransactionFilter` chỉ gọi `kt.chua(t.amount)`. Hai vế đều được phép trống:
để trống vế trên là *lớn hơn*, vế dưới là *nhỏ hơn*, cả hai là *khoảng giữa* — ba
dạng ấy phủ trọn bốn toán tử mà Monarch Money bày thành dropdown riêng. **Không**
chip gợi ý nhanh: ba mức ấy là hằng cứng cho mọi mức thu nhập.

31 ca mới ở 3 tệp mới; `flutter test` **3200/3200, 1 skip**; analyze **26/0**.
**Schema không đổi** (v24), **payload không đổi**, không đụng đồng bộ.

✅ **Đã nghiệm thu máy ảo 411dp ngày 2026-09-21** — Task 5 Step 1, xong muộn hơn
một phiên; xem khối đầu mục 14. Lát này đụng cả ba vùng mù của `flutter test`, và
lượt nghiệm thu chứng minh điều đó: nó bắt được **hai** lỗi của chính lát này mà
3200 ca đều xanh — cả hai ở **kỳ rỗng**, cả hai **im lặng** — cộng một lỗi cũ hơn
(**G48**) không thuộc lát này.

### ✅ AI Edge-SLM — chặng 0 và trọn chặng 1 (2026-09-21)

Theo `docs/superpowers/plans/2026-09-21-ai-viec-tiep-theo.md`.

**Chặng 0 — hai phép đo trên máy thật.** **NPU KHÔNG dùng**: chậm hơn GPU 3,6 lần
và tốn RAM gấp 3,4 lần, tức tệ hơn **cả CPU** — bậc thang mục 8.5 **giữ nguyên**
(hàng thứ năm ở mục **8.1**). **Ảnh và âm thanh đều chạy được** (mục **8.7**): ba
lượt ảnh đều đọc đúng tổng tiền hoá đơn, âm thanh đi thẳng qua `supportAudio`
không cần mô hình STT thứ hai. ⚠️ Cả hai đo bằng dữ liệu **dựng bằng máy**, tức
**cận trên** — chưa phải ảnh chụp thật và giọng người thật. 🛑 Không phép đo nào
mở một hạng mục.

**Chặng 1 — năm việc:**

| Việc | Kết quả |
|---|---|
| 1.1 neo ba ngưỡng tái phân bổ theo thu nhập | ✅ mục **11.5 (1)**; cả ba xoay quanh mốc **5 triệu/tháng** |
| 1.2 ví chọn sẵn theo danh mục | ✅ `transaction/domain/vi_hay_dung.dart`, mục **11.5 (2)** |
| 1.3 gói số hoá đơn + khối Nhận xét | ✅ mục **12** |
| 1.4 gói số mục tiêu mở rộng | ⚠️ **một phần** — mục **13** |
| 1.5 gói số ví + khối Nhận xét | ✅ mục **14** |

⚠️ **1.4 dừng ở một phần vì kế hoạch gộp sai ba dòng thành một việc.** Chỉ
`duBaoHoanThanh` chạy được bằng dữ liệu trang danh sách đang có; `thongKeMucTieu`
và `canhBaoViKhongDu` đòi mở thêm nguồn dữ liệu cho trang — **và cả ba đã là tính
năng sống trên trang Chi tiết mục tiêu**, nên đưa chúng sang trang danh sách là
quyết định về **trùng lặp**, không phải về năng lực.

⚠️ **Khối Nhận xét nay ở SÁU màn**, không phải bốn.

**Bước tiếp:** chặng 2, **2.1 tìm kiếm bằng câu** — ✅ **nửa đầu xong 2026-09-21**
(xem khối ngay trên đầu mục 14): `TransactionFilter` nay lọc được theo **khoảng
tiền**, và khoảng ngày thành **nguồn dữ liệu** của trang chứ không phải một trường
của bộ lọc. Còn lại nửa sau — bộ hàm cho function calling và phép đo tỉ lệ chọn
đúng hàm trên 20 câu mẫu, thứ quyết định có mở 2.2/2.3 hay không.


### 📏 AI Edge-SLM — P1 spike trên máy thật (2026-09-20)

**P1 XONG.** Người dùng cắm **OnePlus 13R** (`CPH2691`, SoC **SM8650 = Snapdragon
8 Gen 3**, arm64-v8a, RAM 10,95 GB, Android 16). Bảng đo đầy đủ — bốn tổ hợp
mô hình × backend, 52 câu sinh ra, RAM đỉnh, nhiệt — ở **mục 8**
`docs/AI_EDGE_FEATURE.md`. Mã spike nằm **ngoài repo** (`D:/flowmoney-spike`),
không commit, đúng như spec yêu cầu.

**Kết quả lật bản thiết kế, và người dùng đã chốt:** dùng **Gemma 4 E2B cho MỌI
máy**, bỏ hẳn E4B. Bậc thang mới: arm64 + GPU → E2B/GPU · GPU hỏng → E2B/CPU ·
còn lại → mẫu câu.

Con số đứng sau quyết định ấy:

| | E4B/GPU | E4B/CPU | **E2B/GPU** | E2B/CPU |
|---|---|---|---|---|
| Sinh một câu (TB 10 lượt) | 4.668 ms | 12.675 ms | **2.329 ms** | 3.313 ms |
| RAM đỉnh | 0,97 GB | 3,27 GB | **0,96 GB** | 1,73 GB |
| Cỡ tệp | 3,41 GB | — | **2,41 GB** | — |

Tức **trên GPU hai mô hình tốn RAM bằng nhau** — nên ngưỡng "RAM thiết bị ≥ 8 GB"
của spec không phân biệt được gì, trong khi E2B nhanh gấp đôi và nhẹ hơn 1 GB.
Chất lượng tiếng Việt của E2B **không thua** (câu còn đọc trôi hơn), vì việc của
mô hình ở kiến trúc này chỉ là *diễn giải một gói số đã tính sẵn*.

⚠️ **Spec mục 4.1 vẫn ghi bậc thang cũ** — nay có banner 🛑 ở đầu. Chính spec ấy
nói *"P1 có thể đổi con số ngưỡng"*, và P1 đã đổi.

**Ba thứ nữa P1 lật, đều ảnh hưởng thẳng tới P3:**

1. `flutter_gemma` core **không kèm engine nào** — `.litertlm` đòi thêm
   **`flutter_gemma_litertlm`**.
2. **Chỉ dùng tệp `‹model›.litertlm` chuẩn.** Biến thể `-gpu.litertlm` nhẹ hơn
   0,6 GB nhưng **không nạp được** trên engine FFI Android, dù tệp nguyên vẹn
   từng byte — và lỗi nó ném (*"Model may be invalid"*) dẫn người đọc đi kiểm tra
   tải hỏng, sai hướng hoàn toàn.
3. Máy không chạy được thì bắt bằng **`try/catch` quanh `getActiveModel`**, không
   cần tự đọc ABI: gói tự nêu *"require an arm64-v8a Android device (got
   android_x64)"*. Lỗi ném ở bước **nạp**, sau khi `install()` đã thành công.

**Nhiệt không thành vấn đề:** 13 câu liên tiếp đưa CPU từ 35,2 °C lên 37,1 °C, và
ba trong bốn tổ hợp có câu thứ 10 nhanh **bằng hoặc hơn** câu đầu.

⚠️ **Bốn cái bẫy khi đưa mô hình lên máy** (mục 8.6) — đắt nhất là cái thứ hai:
`adb push` vào `/sdcard/Android/data/‹pkg›/files/` in *"1 file pushed, 0 skipped"*
kèm tốc độ và **exit 0**, mà thư mục vẫn **rỗng**. Scoped storage nuốt sạch, không
một dòng lỗi. Đường đi được là push vào `/sdcard/Download` rồi
`cat … | run-as ‹pkg› sh -c 'cat > files/…'` — 2 GB mất 12 giây.

**Bước tiếp:** ✅ **kế hoạch P3 đã viết cùng ngày** —
`docs/superpowers/plans/2026-09-20-ai-edge-p3-cam-slm.md`, 10 task. *(Ảnh chụp 2026-09-20; thi công bắt đầu **2026-09-22**, xong Task 1–7 — xem đầu mục 14. Câu "chưa thi công" ngay sau đây là của ngày viết kế hoạch.)*

⭐ **Cùng ngày còn một lượt trao đổi dài về bản chất và tương lai của mảng AI,
kết quả ghi ở mục 10 và 11 `docs/AI_EDGE_FEATURE.md`** — đọc trước khi lên kế
hoạch bất cứ việc AI nào:

- **Mục 10** gọi đúng tên mảng này: mô-đun `ai_edge` là **hệ luật + thống kê mô tả**
  (không phải học máy), SLM là **bộ sinh câu**. Kèm lý lẽ vì sao **không huấn
  luyện mô hình để cá nhân hoá** (trọng số không phải nơi chứa hiểu biết về
  người dùng; gói **không có API huấn luyện**), **mười tiêu chí cho AI chạy
  trên client** (hiện đạt 9/10), và **bốn tầng hậu quả của chiều ghi** — tầng 4
  (`auto_pay`, trích tự động) thì **AI không chạm**.
- **Mục 11** là **bản đồ khảo sát toàn hệ thống**, đếm bằng máy: 13 mảng · 43
  route · 10 bảng Drift · **66 hàm domain thuần mà AI mới dùng 4 gói số** *(con số của
  2026-09-20; từ 2026-09-21 là **6** — thêm `goi_so_hoa_don` và `goi_so_vi`)*. Tức
  phần lớn việc phía trước là **gói lại thứ đã tính**, không phải thêm năng lực
  mới. ⚠️ Hai vế cuối của câu ấy — *"`bill` 27 tệp AI chưa chạm gì, `goal` 14 hàm
  domain mới dùng 1"* — **đã lỗi thời từ 2026-09-21**: `bill` có gói số (mục 12
  `AI_EDGE_FEATURE.md`) và `goal` dùng 2 hàm (mục 13).
- **Mục 11.4** ghi bốn việc **người dùng đã chốt làm** (học mức thiết yếu từ
  phản hồi · tự đề xuất cờ Cố định · nhịp chi theo ngày · bất thường theo danh
  mục), kèm luật chung: **mỗi luật có ngưỡng mẫu tối thiểu, dưới ngưỡng thì
  im**.

### 🤖 AI Edge-SLM — P2 tầng Edge tất định + mẫu câu (2026-09-19 → 2026-09-20)

**P2 XONG.** Spec đã duyệt `docs/superpowers/specs/2026-09-19-ai-edge-slm-design.md`,
kế hoạch `docs/superpowers/plans/2026-09-19-ai-edge-p2-tang-edge-mau-cau.md`
(17 task). Tài liệu tính năng đầy đủ — quyết định kèm lý do, bẫy, bảng test,
nghiệm thu — ở **`docs/AI_EDGE_FEATURE.md`**; đây chỉ là bản tóm tắt để người
đọc mục 14 biết chuyện gì đã xảy ra.

Đo bằng máy 2026-09-20: **20 commit** kể từ P0 (`03fe03a`), **45** tệp `lib/`
đổi (+3615 / −106 dòng), `lib/features/ai_edge/` có **16** tệp,
`test/features/ai_edge/` có **14** tệp / **94** ca. Trọn bộ **3106/3106 pass,
1 skip**; `flutter analyze` **26 issue, 0 error** (mức nền).

**Một câu:** *máy tính số, mô hình kể chuyện về số.* P2 làm xong nửa đầu — tầng
tất định; P3 (mô hình trên máy) chờ P1 spike.

**Cái gì người dùng thấy:**

- **Khối "Nhận xét"** ở **sáu** màn — Ngân sách, Phân tích, Mục tiêu, Trang chủ (P2 Task 14,
  2026-09-19), **Hoá đơn và Quản lý ví** (2026-09-21, mục 12 và 14 `AI_EDGE_FEATURE.md`):
  một câu mẫu dựng từ gói số typed, cộng dải thẻ số liệu. Đóng **A6** của lượt
  UX (thẻ "Insight AI" chữ tĩnh, hứa một tính năng không tồn tại).
- **Thẻ "Đề xuất cân đối"** trên trang Ngân sách + **sheet kế hoạch chờ duyệt**:
  phát hiện ngân sách dự kiến vượt, tìm nguồn bù từ ngân sách khác, người dùng
  tick từng dòng rồi Áp dụng. Hạn mức mới đi đúng đường đồng bộ như mọi lần sửa
  tay — nghiệm thu đo tới tận PostgreSQL.
- **Công tắc "Cố định"** ở màn Thêm/Sửa danh mục: danh mục đánh dấu thì AI không
  bao giờ đề xuất cắt.
- **Thông báo `budgetRebalance`** (2026-09-20) — loại thứ **19** của enum, mục
  **5g** `NOTIFICATION_FEATURE.md`.

**Bốn luật cốt lõi, phá cái nào cũng hỏng im lặng:**

1. **Lớp `ai_edge` KHÔNG tính.** Mọi con số đến từ hàm domain đã có
   (`budgetPaceOf`, `thuNhapCua`, `tyLeTietKiem`, `phanTramSoVoi`, `duBaoCua`,
   `topKhoanChi`, `pickHomeBudget`). **Test quét `lib/` thứ 14** cấm `ai_edge/`
   chứa `'thu'`/`'chi'`/`'transfer'`/`walletId`/`transactionDao`/`.type ==`.
   Lý do: một bản định nghĩa thứ hai của "thu nhập" chính là thứ đã sinh bẫy
   A8 #8 (thu nhập gồm cả tiền đi vay — tháng nào vay tiền, con số vọt lên,
   không exception nào báo).
2. **Hai thứ của schema v24 là CỤC BỘ** — cột `categories.ai_co_dinh` và bảng
   `AiRebalancingFeedbacks`. **Không** vào `SyncEntityType`, **test quét thứ
   15** canh. Payload đồng bộ **không đổi** suốt P2.
3. **Nguồn dữ liệu Tầng 2 đặt ở `budget/data/`, không ở `ai_edge/`** — nó đọc
   bảng giao dịch để tính thu nhập 3 tháng, mà test quét 14 cấm `ai_edge/` chạm
   bảng ấy. Lớp AI chỉ nhận `DuLieuTaiPhanBo` đã dựng xong.
4. **Một kế hoạch, một định nghĩa.** Thẻ trên trang và thông báo cùng gọi
   `TaiPhanBoNguon` + `taiPhanBoCua`; bộ luật thông báo **nhận** kế hoạch chứ
   không tự tính. Hai phép tính là hai ngân sách khác nhau trên cùng màn hình.

**Mấy cái bẫy đắt nhất của P2** (đầy đủ ở mục 4 `AI_EDGE_FEATURE.md`):

- **Câu mẫu không được chứa chữ số ngoài gói số** — nhãn kỳ `T9 2026`, tiêu đề
  khoản chi, hằng "30 ngày" đều bị bộ kiểm số chặn. Ở P2 câu mẫu vẫn hiện bình
  thường nên **không ai thấy**, cho tới khi P3 rơi về nó và bị chặn.
- **Sheet có ba lối ra ba nghĩa**: Áp dụng và Bỏ qua ghi phản hồi, vuốt tắt
  **không ghi gì** — "chưa quyết" không phải "từ chối".
- **Đọc SQLite máy ảo phải chép cả `-wal` và `-shm`**, nếu không mọi hàng mới
  (kể cả bảng v24) vô hình và trông như migration chưa chạy.
- **Thông báo `budgetRebalance` khoá theo TUẦN**, không theo ngân sách: dự phóng
  đổi sau mỗi giao dịch, nên khoá bám vào số nào đó là mỗi lượt quét một thông
  báo mới — mà quét nổ vài lần mỗi ngày.
- ⚠️ **Thêm một giá trị vào `NotificationKind` làm hai `switch` không `default`
  ở `notification_prefs.dart` thành lỗi biên dịch, và làm ca quét "đủ mọi loại"
  của `notification_deeplink_test.dart` đỏ.** Cả hai **đúng thiết kế** — đừng
  thêm `default` để làm chúng im.

**Hai chỗ lệch có từ trước, cố ý chưa vá** (mục 7.1 `AI_EDGE_FEATURE.md`): Trang
chủ nói thu **15.145.000** còn Phân tích **15.135.000** (thẻ Trang chủ cộng thô
theo `type`, Phân tích qua `khoanVaoThongKe`) — khối Nhận xét mỗi trang cố ý
chép đúng số của trang ấy; và "để dành **86%**" trên thẻ cạnh "**85,7%**" trong
khối (làm tròn nguyên vs luật G2). Muốn khớp thì đổi `thuChiThangCua` — **hỏi
người dùng trước**. *(✅ Chỗ lệch đầu **đã vá 2026-09-23** — người dùng chốt số của
Phân tích, bước 1a ở đầu mục 14. Chỗ lệch sau — 86% vs 85,7% — vẫn mở.)*

**Bước tiếp:** ✅ cả hai đã xong trong ngày — **P1 spike** (khối 📏 ở trên) và
**kế hoạch P3** (`docs/superpowers/plans/2026-09-20-ai-edge-p3-cam-slm.md`, 10
task). ⚠️ Câu *"bậc thang E4B ≥ 8 GB → E2B 4–8 GB"* từng đứng ở đây là **ảnh
chụp trước khi đo**: P1 lật nó, và người dùng chốt **E2B cho mọi máy**. Vế
`.litertlm` chỉ arm64 thì vẫn đúng — **máy ảo luôn đi nhánh mẫu câu**.
**A11** của lượt UX (năm handler rỗng của `ai_chat_page`) đóng ở P3, Task 8.



### ⬆️ Nâng Flutter 3.41.5 → 3.47.5 — P0 của AI Edge-SLM (2026-09-19)

Người dùng gỡ lệnh hoãn mảng Edge-SLM ngày 2026-09-19 và chốt **nâng Flutter** để
dùng `flutter_gemma` 1.8.3 (đòi Flutter ≥ 3.44, Dart ≥ 3.12; bản 0.13.6 hợp 3.41
thì thiếu API mới và Gemma 4). Thiết kế đã duyệt:
`docs/superpowers/specs/2026-09-19-ai-edge-slm-design.md`; kế hoạch
`docs/superpowers/plans/2026-09-19-ai-edge-p0-nang-flutter.md` (P0) và
`…-p2-tang-edge-mau-cau.md` (P2); bản đánh giá 18/09 có banner đính chính (gói
không chạy Gemma 3 4B — bậc thang mới là Gemma 4 E4B/E2B).

P0 là **một commit, không mã tính năng**. Kết quả đo sau nâng: Flutter `3.47.5`,
Dart `3.13.4`, SDK git `6a19cca564`; `pubspec.lock` đổi **5** gói gián tiếp
(`intl` 0.20.2→0.20.3, `matcher`, `meta` 1.17→1.19, `test_api`, `vector_math`
2.2→2.4.3 — không gói nào nhảy major, `fl_chart` vẫn 1.2.0, `pubspec.yaml` không
đổi); tool tự thêm khối `analyzer: exclude` vào `analysis_options.yaml` và hai cờ
`android.builtInKotlin=false` / `android.newDsl=false` vào `android/gradle.properties`
(Flutter migrator, giữ nguyên); `android/.kotlin/` mới sinh → vào `.gitignore`; mã
Drift sinh lại **không đổi**; `flutter analyze` **26 issue, 0 error** (+1 so mức
nền: `onReorder` của `ReorderableListView` deprecated từ 3.47, `goal_page.dart:233`
— cố ý chưa sửa); `flutter build apk --debug` xanh sau 727 s, không phải nâng
Gradle/AGP/Kotlin (log có một stack trace Kotlin incremental-cache nhưng build
thành công); máy ảo `FlowMoney_16G` mở Trang chủ, Phân tích, Giao dịch, Ngân sách
(nút Back về Trang chủ), Hoá đơn, Sửa hoá đơn — **0 pixel vàng**, logcat 0
exception.

⚠️ **Một hành vi framework đổi, lượt test đầu đỏ 10 ca ở 3 tệp** —
`bill_edit_page_test` (8), `bill_auto_pay_ui_test` (1), `bill_payment_sheet_test`
(1): Flutter 3.47 thêm assertion *"ListTile background color or ink splashes may
be invisible"* khi `ListTile` nằm trong `Container` có màu mà không có `Material`
riêng ở giữa; nó báo qua `FlutterError.reportError` nên `takeException()` bắt
được, và một ca "No GoRouter found" chỉ là hệ quả dây chuyền. Sửa **tối thiểu**:
bọc cột chứa tile trong `Material(type: MaterialType.transparency)` ở
`bill_edit_page.dart` (Container trắng bo 16, ba `ListTile` ngày) và
`bill_payment_sheet.dart` (`_danhSachVi`). Không đổi gì nhìn thấy được; máy ảo
mở màn Sửa hoá đơn xác nhận. `dart format` bẻ lại vài dòng dài và tách một
`if` một dòng thành hai — phải thêm ngoặc nhọn kẻo analyze lên 27. Lượt test thứ
hai: **2960/2960 pass, 1 skip, 3 phút 2 giây**. Quét thô `lib/` bằng script không
thấy chỗ nào khác cùng khuôn trong cửa sổ 25 dòng; nhưng cửa sổ ấy hụt với
Container bao cả form (chính ca này), nên **mọi màn có `ListTile` trong thẻ màu
đều phải nghiệm thu máy ảo và đọc logcat** khi đụng tới.

Bước tiếp: **P1 spike** khi người dùng cắm máy Snapdragon 8 Gen 3; **P2** (tầng
Edge + mẫu câu) không chờ P1.

### 🎨 Lượt sửa UX/UI theo đánh giá 2026-09-19

Ngày 2026-09-19 người dùng hỏi đánh giá UX/UI. Lượt đánh giá đo trên **máy ảo
411dp với dữ liệu thật** (khoảng 30 ảnh chụp) cộng quét mã, ra **42 việc** trong
bảy nhóm — danh sách đầy đủ kèm bằng chứng ở
`docs/superpowers/plans/2026-09-19-ux-ui-danh-sach-viec.md` (gitignore, chỉ có
trên máy đã dựng). Người dùng chốt **làm theo thứ tự đề nghị**: nút chết trước,
rồi bản địa hoá và số tiền, rồi luồng nhập liệu và menu (hai nhóm sau cần Stitch
trước). Từng hạng mục ghi ở đây khi xong.

**A1 · A2 · A7 — nút chết (xong 2026-09-19).** Ba chỗ vẽ như nút sống mà bấm
không làm gì: hamburger ở tab Cá nhân (`onPressed: () {}`), icon menu ở header
Phân tích (một `Icon` trần, không bọc nút — trông hệt hamburger mở drawer của
Trang chủ), và hai mục "Bảo mật 2 yếu tố (MFA)" / "Đồng bộ dữ liệu Cloud" ở Cài
đặt với công tắc luôn bật và dấu tick luôn xanh — hứa hai tính năng không tồn
tại. Cả ba **gỡ**; cùng trang Cài đặt gỡ luôn nút "hỗ trợ" `support_agent` cũng
rỗng. **Test quét `lib/` thứ MƯỜI** — `test/core/ui/khong_co_nut_chet_test.dart`
— cấm mọi handler rỗng (`onPressed/onTap/onChanged…: () {}`, kể cả `(val) {}` và
`async {}` trải nhiều dòng; bỏ dòng chú thích vì hai tệp mục tiêu nhắc tới khuôn
ấy trong lời giải thích). Chỗ còn giữ phải **liệt kê tay kèm số chỗ và lý do**,
và mỗi mục là một quyết định **chờ chốt** chứ không phải ngoại lệ vĩnh viễn:
`ai_chat_page` 5 (D9), `login_page` 2 (Google/Apple, chưa có OAuth),
`forgot_password_page` 1 ("Liên hệ hỗ trợ"), `add_transaction_page` 1 (menu ⋮),
`profile_page` 1 (công tắc Giao diện, A3). ⚠️ Test quét lộ thêm **một nút chết
không có trong danh sách 42 việc**: "Gửi lại mã OTP" ở màn OTP quên mật khẩu là
`onPressed: () { // Resend OTP logic }` — người lỡ mất mã không có lối nào ngoài
quay lại nhập email. Nay gọi lại chính `forgotPassword(email)`, xoá sáu ô, và
hiện "Đã gửi lại mã tới …" (3 ca ở `otp_gui_lai_ma_test.dart`). Hai widget test
canh icon menu ở Cá nhân và Phân tích không quay lại. **Schema không đổi, payload
không đổi.**

**A4 · A9 — drawer Trang chủ (xong 2026-09-19).** Drawer tách thành widget riêng
`home/presentation/widgets/drawer_trang_chu.dart` nhận dữ liệu và callback,
không đọc bloc, để test dựng được một mình; `HomePage._buildDrawer` chỉ còn đọc
tên/email và nối callback. Ba lỗi máy ảo đo được, cả ba ở đây: (1) mục "Xuất
báo cáo" trỏ `/reports` — **route không tồn tại** — rồi che bằng SnackBar "đang
phát triển" dù trang ấy có từ 2026-09-09 ở `/export-report`; nay danh sách mục
là hằng công khai `kMucDrawer` và có ca test **đối chiếu từng đường với router
thật** (`router.configuration.findMatch(...).isError`), cùng họ với test quét
`bank-link`: route và lời gọi là hai chuỗi rời nhau nên `flutter analyze` im
lặng. (2) Avatar là **vòng đen trống**: chữ cái đầu tô `AppColors.primary` trên
nền `AppColors.primaryContainer` mà hai hằng ấy cùng là `#1A1A19` — nay
`onPrimaryContainer`, có ca test đòi màu chữ **khác** màu nền. (3) Thiếu "Đăng
xuất" ở đáy dù màn Stitch *"Home with Side Menu Drawer"* có — nay có, đi qua
**`xacNhanDangXuat`** (`auth/presentation/xac_nhan_dang_xuat.dart`), hộp thoại
xác nhận tách từ tab Cá nhân để hai chỗ dùng chung một định nghĩa. 5 ca ở
`drawer_trang_chu_test.dart`. **Schema không đổi, payload không đổi.**

**A8 (xong 2026-09-19).** Xoá `shared/widgets/bottom_nav_bar.dart` — bản thanh
điều hướng song song **0 chỗ gọi**, mang nhãn "Thống kê"/"Hồ sơ" khác bản đang
chạy trong `main_shell.dart` ("Phân tích"/"Cá nhân").

**B1 — bản địa hoá Flutter (xong 2026-09-19).** Máy ảo đo được hộp chọn ngày ở
màn Thêm giao dịch hiện *"Select date · Sat, Sep 19 · Cancel / OK"*, tuần bắt
đầu Chủ nhật, giữa giao diện tiếng Việt: `MaterialApp` không khai
`localizationsDelegates`/`locale` nên mọi chữ **do Flutter vẽ** (date/time
picker, nút hộp thoại, tooltip của back/menu) rơi về `en_US`. Nay có
`core/constants/app_localization.dart` — ba hằng `kNgonNguApp` (`vi`, **ghim**
chứ không theo máy vì app chỉ có một ngôn ngữ), `kSupportedLocales`,
`kLocalizationsDelegates` — và `main.dart` nối đủ cả ba (test đọc `main.dart`
canh: thiếu một là "Select date" trở lại, im lặng). Kéo theo
`flutter_localizations` (SDK) và **`intl` lên `^0.20.2`** vì gói ấy ghim
`intl 0.20.2`; 0 chỗ trong `lib/` dựng `NumberFormat`/`DateFormat` ngoài
`CurrencyFormatter` và các `DateFormat` đã có nên bộ test không đổi kết quả.
⚠️ Chuỗi tiếng Việt của Flutter viết **"Huỷ"** (dấu hỏi trên *y*), trùng cách
app đang viết ở hộp thoại đăng xuất — ca test đầu đoán "Hủy" và đỏ vì thế.
3 ca ở `app_localization_test.dart`. **Schema không đổi, payload không đổi.**

**B2 — ba thẻ Thu nhập / Chi tiêu / Thu net ở Trang chủ (xong 2026-09-19).**
Máy ảo 411dp với dữ liệu thật hiện *"14.635.0…"*, *"1.045.00…"*, *"+13.590…"*:
`TextOverflow.ellipsis` cắt con số chính của trang ngay từ 8 chữ số, và không
test nào bắt được vì `find.text` so `data` chứ không so thứ vẽ ra (bẫy 4.4).
Ba thẻ tách thành `home/presentation/widgets/the_so_lieu_thang.dart`; con số
nằm trong `FittedBox(scaleDown)` bọc bởi `SizedBox(width: infinity)` — co chữ
cho vừa ô thay vì cắt; ca test đo **`RenderParagraph.didExceedMaxLines`**, tức
thứ thật sự bị cắt, và bản giữ `ellipsis` đã làm nó đỏ đúng chỗ. Cùng lượt con
số đi qua `CurrencyFormatter.format`/`formatCoDau` ("14.635.000 đ", số 0 không
mang dấu) thay vì nối `'đ'` tay.

⚠️ **Lỗi thứ năm, tìm được khi soát lại sau báo cáo của người dùng:** nút bút
chì trên avatar tab Cá nhân là `Container` + `Icon` **trần** — không `InkWell`,
không `GestureDetector`, **không handler nào cả**. Nó vẽ như nút mà chưa bao
giờ bấm được, và trang Cài đặt cũ thì đúng nút ấy có nối vào
`/settings/edit-profile`. ⚠️ **Test quét `khong_co_nut_chet_test.dart` KHÔNG
bắt được kiểu này**: lưới của nó tìm *handler rỗng* (`onPressed: () {}`), còn
đây là nút **không có handler** — hai hình dạng khác nhau, và hình dạng thứ hai
khó thấy hơn vì mã trông hoàn toàn bình thường.

⚠️ **Lỗi thứ sáu, lộ ra ngay khi nút bút chì ấy mở được trang Thông tin cá
nhân:** avatar ở trang đó là một **vòng đen trống**. `AppColors.primaryContainer`
**chính là** `AppColors.primary` (cùng `#1A1A19`, `app_colors.dart:50`), nên
viết chữ `primary` lên nền `primaryContainer` là chữ đen trên nền đen. A9 đã
sửa đúng lỗi này ở **drawer** sáng cùng ngày nhưng **bỏ sót hai chỗ khác**:
`edit_profile_page.dart` và `settings_page.dart`. Nay có
`profile/avatar_chu_khac_mau_nen_test.dart` quét `lib/` bằng **cửa sổ 20 dòng**
sau mỗi khai báo nền `primaryContainer` — nó bắt đúng hai chỗ ấy và không dương
tính giả. **Bài học: sửa một lỗi màu thì grep cả cặp hằng, đừng sửa mỗi chỗ vừa
nhìn thấy** — và một ca quét rẻ hơn hẳn việc nhớ. *(Câu "Trang chủ từng là chỗ duy nhất viết
không cách" ghi ở đây lúc đầu là **sai** — B3 cùng ngày đếm được 20 chỗ ở 7
tệp, xem đoạn B3/B4 dưới.)* Có ca thử với **13 chữ số** (trần G45/G46) để bố cục
được thử với giá trị lớn nhất. 3 ca ở `the_so_lieu_thang_test.dart`. **Schema
không đổi, payload không đổi.**

**B3 · B4 — một quy ước cho ký hiệu `đ` (xong 2026-09-19).** Máy ảo cho thấy
**hai** quy ước sống chung: Trang chủ, Sổ giao dịch, Thêm giao dịch và Phân tích
viết *"13.590.000đ"* (gọi `formatSoThoi()` rồi nối `'đ'` tay), còn Ví, Ngân
sách, Mục tiêu, Hoá đơn và tệp xuất viết *"13.590.000 đ"* (`format()`). Test
quét cũ chỉ cấm dựng `NumberFormat`, nên lối "số thô + `đ` tay" đi vòng được.
Nay **test quét `lib/` thứ MƯỜI MỘT** — `core/utils/ky_hieu_tien_mot_noi_test.dart`
— cấm `đ` đứng ngay sau chữ số, sau `}` nội suy, hoặc sau nội suy trần `$ten`
(Dart chỉ nhận ASCII trong định danh nên `'$moneyđ'` là `$money` rồi `đ` — và
`transaction_row_content.dart` viết đúng thế, lọt mọi `grep` `}đ`). Bản đầu đỏ ở
**20 chỗ / 7 tệp**: `analytics_page` (`_dong`), `home_page`, `transaction_page`
(4), `transaction_row_content` (2), `add_transaction_page` (7), `bill_add_page`
(2, kể cả `placeholder: '0đ'`), `goal_add_page` (3, hai `hint` mẫu và câu tóm tắt
trích). Tất cả về `CurrencyFormatter.format` / `formatIncome` / `formatExpense`
/ `formatCoDau`; nhánh chuỗi có dấu chấm ở bàn phím tự vẽ nối bằng hằng
`CurrencyFormatter.kyHieu`. Hai chuỗi cố định của màn mockup (`ai_chat_page`
"3.200.000đ", `bill_delete_page` "260.000đ") nằm ở danh sách chờ chốt của test,
kèm số chỗ. **25 khẳng định** ở 6 tệp test đổi theo ("…000đ" → "…000 đ"); một
ca đo mép phải của Phân tích phải đổi finder sang `.last` vì thẻ "Tổng thu" và
dòng ví nay đọc **cùng một chuỗi** — trước đó chúng khác nhau chỉ vì thẻ tổng
nối tay. ⚠️ **Chọn quy ước có cách ("13.590.000 đ")** vì đó là thứ `format()`
đã in ở 2/3 app và trong PDF; màn Stitch Home vẽ *không* cách ("-55.000đ") —
nay mọi chỗ đi qua một hàm nên đổi ý là **sửa một dòng** ở `format()`, đó chính
là lý do gom về một chỗ. **Schema không đổi, payload không đổi.**

> ⚠️ Lộ ra ngoài phạm vi khi làm B3 — ✅ **đã sửa 2026-09-19**, xem khối
> **"A12"** bên dưới. (Ảnh chụp lúc phát hiện: bàn phím tự vẽ của màn Thêm giao
> dịch có phím `.` sinh dấu thập phân, màn hiện *"12.5 đ"*, nhưng
> `_saveTransaction` lưu bằng
> `double.tryParse(_amountString.replaceAll('.', ''))` — tức **12.5 thành 125**,
> im lặng.)

**C1–C5 — màn Thêm giao dịch theo Stitch (xong 2026-09-19).** Máy ảo 411dp:
màn đầu chỉ thấy hai hàng phím 7-8-9 / 4-5-6, phải cuộn mới tới 1-2-3, 0, 000,
✓, và cuộn tới thì con số đang gõ trôi khỏi màn. Lượt đối chiếu Stitch lộ ra
**hai chỗ bản Flutter đi lệch thiết kế** chứ không phải thiếu thiết kế: màn gốc
`20700200…` vẽ thanh **"Chi tiêu · Thu nhập · Chuyển khoản"** (bản chạy chỉ có
"Giao dịch / Chuyển khoản" từ 2026-09-05), và màn "Chọn danh mục" `acab2a45…`
vẽ **hàng lá trần** (bản chạy có chevron ">" và icon tag xanh chung). Chỉ bố cục
bàn phím là chưa có, nên đưa lên Stitch trước: `edit_screens` trả về **màn
mới** `acf6f17e65b84132ae6b18bba16a606a` *"Thêm giao dịch - Bàn phím neo đáy"*
(tạo màn mới thay vì sửa tại chỗ; ảnh trả về đúng yêu cầu — thanh chọn, số tiền
cố định, thẻ form cuộn ở giữa, 16 phím neo đáy, ✓ là nút lưu, không còn nút
"Lưu giao dịch"). Bản Flutter: (1) `body` là `Column` — thanh chọn + số tiền
**cố định**, `Expanded(SingleChildScrollView(thẻ form))`, bàn phím **neo đáy**
với `mainAxisExtent: 50` (không `childAspectRatio`: ở khung test 800dp tỉ lệ
cho phím cao gấp đôi, nuốt hết chỗ thẻ form); (2) phím ✓ gọi `_saveTransaction`
— **từng là phím chết**, `themPhimSoTien` trả nguyên chuỗi với `'done'`; nút
"Lưu giao dịch" bỏ; (3) `_selectedSegment` (0/1) thành **`_huong`**
`'chi'|'thu'|'transfer'`, key `transaction-type-<huong>`, màu đoạn theo Stitch
(đỏ/xanh/đen). ⚠️ **Luật 2026-09-05 giữ nguyên**: `type` vẫn suy từ danh mục;
đoạn Chi/Thu chỉ là **lối vào** — đặt tab bảng danh mục mở, bỏ danh mục đang
chọn nếu thuộc chiều kia, và **nhảy theo** khi chọn danh mục; với vay/nợ đoạn
chính là công tắc "Chiều tiền" (hai chỗ luôn cùng giá trị). Phép kiểm "quyết
định có chủ ý" đã làm: lý lẽ 2026-09-05 là *sự thật nằm ở danh mục* — thanh
mới không đụng vào đó. (4) `AddTransactionPage.huongBanDau` + route `/add`
nhận `extra` là `String` → ba nút tắt Trang chủ đặt sẵn `'thu'|'chi'|'transfer'`
(trước đó cả ba đều `push('/add')` trần). (5) `_buildChildTile` của bảng chọn
bỏ chevron và icon. Test: tệp mới `add_transaction_bo_cuc_test.dart` (7 ca, đo
ở **411×914**: mọi phím và con số nằm trong màn, ✓ lưu thật, ba đoạn, đoạn
nhảy theo danh mục, `huongBanDau`, hàng lá trần); 4 tệp cũ đổi theo — `luu()`
tap `Icons.check`, key `transaction-type-transfer`, và **`ensureVisible`
trước khi chạm "Danh mục"** vì thẻ form nay nằm trong vùng cuộn hẹp ở khung
test 600dp. **Schema không đổi, payload không đổi.**

**E5 · E7 · E8 — ba việc nhỏ (xong 2026-09-19).** (E5) Thẻ tổng của tab Ngân
sách tô thanh **xanh** ở mức đã dùng 90% trong khi thẻ danh mục ngay dưới tô
**đỏ** cùng con số: thẻ tổng chỉ biết hai màu vượt / chưa vượt, thẻ danh mục đi
qua `budgetHealthOf`. Nay thang bốn màu tách thành **`budgetHealthOfRatio`**
(`budget_visuals.dart`) cho một tỉ lệ bất kỳ, `budgetHealthOf` gọi lại nó, và
thẻ tổng dùng **tỉ lệ thô** `totalSpent / totalAmount` chứ không `percentSpent`
(đã cắt trần 1.0). 3 ca ở `budget_overview_card_test.dart`. (E7) Trang Danh
mục in "Danh mục" ở thanh trên rồi "Quản lý danh mục" ngay dưới — màn Stitch
`583f8232…` chỉ có tiêu đề ở thanh; bỏ dòng lặp. ⚠️ FAB "+" **vẫn** đè lên nút
⋯ của hàng cuối khi danh sách vừa chớm dài hơn khung — Stitch cũng đặt FAB
nổi, và `padding` đáy 96 chỉ có tác dụng khi cuộn tới cuối; **để nguyên**, ghi
lại là giới hạn của khuôn FAB nổi. (E8) **Lỗi thật, cùng họ G41 → G47, mở và
đóng cùng ngày**: 2/3 thẻ hoá đơn hiện "Danh mục đã xoá" vì `BillPage`,
`BillDetailPage` và `BudgetLocalDataSourceImpl.getAllCategories` (nuôi
`lookupFor` của ngân sách) dựng bảng tra tên từ `categoryDao.getAll` — hàm lọc
`idaccount = accountId` và `deletedAt IS NULL`, nên hàng mặc định toàn cục
(`idaccount = 0`) và hàng đã xoá mềm đều mất tên. Cả ba về
**`getBangTraTen`**, định nghĩa duy nhất từ G41. Test mới
`bill_page_ten_danh_muc_mac_dinh_test.dart` (2 ca, CSDL trong bộ nhớ: một danh
mục `idaccount = 0` + `isDefault`, một danh mục xoá mềm; thẻ phải hiện tên cả
hai, và `getAllCategories` phải trả cả hai). ⚠️ Ca đầu viết với tên "Hóa đơn"
**xanh oan** vì `textContaining` bắt trúng **tiêu đề trang** — đổi tên mẫu sang
"Nhà cửa" và đòi cả thẻ "Tiền điện" dựng được (họ G43). **Schema không đổi,
payload không đổi.**

**G1 — tooltip cho nút chỉ có icon (xong 2026-09-19).** Đếm được **45**
`IconButton` không có `tooltip` (28 nút Quay lại, 7 mắt ẩn mật khẩu, 2 Đóng,
⋮, lịch tháng trước/sau, Sửa, Xoá, Gửi, Ghi âm, Cài đặt…) — không nhãn nào cho
TalkBack/VoiceOver và không nhãn nào hiện khi nhấn giữ. `tooltip` của
`IconButton` cho cả hai thứ cùng lúc, nên đây là phần rẻ nhất của G. **Test
quét `lib/` thứ MƯỜI HAI** — `test/core/ui/icon_button_co_tooltip_test.dart` —
đòi `tooltip:` trong 8 dòng sau mỗi `IconButton(`; chèn bằng script Perl theo
tên icon. ⚠️ Bản chèn đầu **hỏng mã hoá** ("Quay láº¡i"): script Perl đọc
nguồn không `use utf8` rồi ghi qua lớp `:encoding(UTF-8)` → mã hoá hai lần;
sửa bằng `decode(encode(latin1))` trên đúng các dòng vừa chèn. Nút dựng qua
widget khác (`NotificationBell`, `GestureDetector` của thanh dưới) **không**
nằm trong phép quét — G2 (cỡ chữ lớn) cũng chưa làm. **Schema không đổi,
payload không đổi.**

**E3 — Back không thoát app ngay (xong 2026-09-19).** Máy ảo: Back ở tab Trang
chủ đưa thẳng ra launcher, không cảnh báo — app không có `PopScope` nào (trong
lượt đánh giá tôi cũng mất app hai lần vì thế). Nay `MainShell` bọc thân bằng
**`ThoatHaiLan`** (`shared/widgets/thoat_hai_lan.dart`): Back ở tab khác thì
**về Trang chủ**; ở Trang chủ thì toast *"Nhấn lần nữa để thoát"*, nhấn lại
trong **2 giây** mới `SystemNavigator.pop()`. Luật là lớp thuần
`LuatThoatHaiLan` (test bằng đồng hồ giả; về tab đầu **không mồi** cho lần
thoát kế); widget test giả kênh `SystemChannels.platform` để bắt lời gọi thoát.
Chỉ can thiệp khi route của shell ở trên cùng — trang đẩy lên root navigator
(Thêm giao dịch, Sổ giao dịch…) Back vẫn pop như thường. Câu báo đi qua
**`ThongBaoNhanh`** (`core/ui/thong_bao_nhanh.dart`, đăng ký ở
`injection_container`): kênh chữ tự do một dòng, và `AppToast` nhận nó làm
**nguồn thứ tư** (`thongBaoNhanh`, mặc định rỗng nên ba tệp test cũ không đổi;
bậc thấp nhất, nguồn riêng). Lý do không dùng `SnackBar`: nếp đã chốt là
thông báo tạm thời phải là **viên nhỏ** chứ không phải dải kín ngang màn — app
đã có đúng viên ấy, chỉ thiếu lối đẩy chữ tự do vào; kênh này cũng là nền cho
E4 (thay 176 `SnackBar`) về sau. 7 ca ở `thoat_hai_lan_test.dart` (1 ca đọc
`main_shell.dart` canh việc bọc), 1 ca ở `app_toast_thong_bao_nhanh_test.dart`.
**Schema không đổi, payload không đổi.**

> ⚠️ **Nghiệm thu máy ảo lật một lỗi mà 8 ca trên đều mù** (cùng ngày): Back
> ở tab **Phân tích thoát app ra launcher** thay vì về Trang chủ. Cơ chế, đọc từ
> `navigator.dart`/`app.dart`: máy ảo Android 16, app `targetSdk 36` nên
> **predictive back bật mặc định**; khi bật, Android chỉ giao Back cho Flutter
> nếu lời gọi `SystemNavigator.setFrameworkHandlesBack` **cuối cùng** là
> `true`. `Navigator` gốc phát đúng (`navigatorCanPop || routeBlocksPop`, có
> tính `PopScope`), nhưng **navigator của nhánh** `StatefulShellRoute` mới dựng
> phát `canHandlePop: false`, và listener của navigator gốc chỉ hỏi `canPop()`
> — không hỏi `PopScope` — nên **cho qua nguyên vẹn** → `WidgetsApp` gọi
> `setFrameworkHandlesBack(false)` → logcat `setTopOnBackInvokedCallback: null`
> đúng lúc chuyển tab → lần Back kế Android tự đóng activity. Test bằng
> `MaterialApp` trần không thấy vì nó đi đường `Navigator.maybePop`.
> **Sửa:** `android:enableOnBackInvokedCallback="false"` trong
> `AndroidManifest.xml` — Back đi đường `KEYCODE_BACK → popRoute →
> GoRouterDelegate.popRoute → root.maybePop → PopScope`, đúng đường mà test
> mới `shared/widgets/main_shell_back_test.dart` (6 ca) canh: dựng **`MainShell`
> trong một `GoRouter` thật** với `StatefulShellRoute` hai nhánh và một trang
> đẩy lên root, giả `SystemChannels.platform` để bắt `SystemNavigator.pop`;
> một ca đọc thẳng manifest (vùng mù 7.11). Bản tái hiện đầu (ghi lời gọi
> `setFrameworkHandlesBack`, phải đặt app `resumed` vì `WidgetsApp` bỏ
> notification khi chưa gắn) đỏ đúng chỗ máy ảo đỏ, rồi thay bằng ca manifest
> khi chốt lối sửa. Đây là ví dụ **thứ hai** của *loại lỗi thứ hai* mà
> `flutter test` không bắt được.

**F1 · F2 · F3 — nhận diện app (xong 2026-09-19).** Máy ảo: nhãn dưới icon và
trong khay thông báo là *"flowmoney"* chữ thường, icon là logo Flutter mặc
định, splash là nền trắng với logo Flutter — thứ đầu tiên người chấm nhìn thấy,
và không lệnh nào của Flutter nói gì về nó. Nay: nhãn **"FlowMoney"** ở
`AndroidManifest.xml` và `Info.plist` (cả `CFBundleName`); icon là **ô đen
#1A1A19 bo góc với glyph ví trắng** — dáng `Icons.account_balance_wallet` mà màn
Đăng nhập dùng làm nhãn hiệu — sinh bằng `flutter_launcher_icons` (kèm adaptive
icon `mipmap-anydpi-v26`, iOS bỏ alpha); splash **nền ấm #EDEDE9 với ô icon ở
giữa** sinh bằng `flutter_native_splash` (Android ≤ 11, Android 12+, iOS
storyboard, và cả `web/index.html`). Ảnh nguồn ở `assets/icon/` (**không** đưa
vào `flutter.assets`, chỉ để sinh lại) do **`test/tool/tao_icon_app_test.dart`**
vẽ ra — một widget test `skip: true`, chạy tay với `--run-skipped` — vì máy
không có Python/ImageMagick còn `flutter test` thì có Skia. ⚠️ **Glyph phải vẽ
bằng `CustomPainter`**: `flutter test` không nạp font MaterialIcons (và chữ là
font Ahem), nên bản đầu dùng `Icon(Icons.account_balance_wallet)` sinh ra một
**ô vuông rỗng**, chỉ lộ khi mở ảnh ra xem. `test/core/nhan_dien_app_test.dart`
(4 ca) đọc thẳng tệp Android: nhãn, MD5 của `ic_launcher.png` khác bản
`flutter create`, có `mipmap-anydpi-v26`, `launch_background.xml` trỏ
`@drawable/splash`, ba ảnh nguồn tồn tại. Hai gói vào `dev_dependencies`.
**Schema không đổi, payload không đổi.**

**A12 — số tiền có phần lẻ bị nhân mười (xong 2026-09-19).** Lỗi lộ ra khi làm
B3, sửa ở lượt sau. `_amountString` là chuỗi **thô** đang gõ — phép ngăn nghìn
chỉ áp ở `_getFormattedAmount` — nhưng `_saveTransaction` đọc nó bằng
`double.tryParse(_amountString.replaceAll('.', ''))`, tức **coi dấu chấm là dấu
ngăn nghìn** theo thói quen Việt Nam. Một chuỗi có dấu thập phân mất dấu chấm
rồi đọc tiếp: `12.5` lưu xuống thành **125**, không exception, không log.

⚠️ **Lỗi này có HAI cửa, và quyết định "bỏ phím `.`" chỉ đóng một.** Cửa thứ
hai là **chế độ sửa**: `initState` điền `_amountString` bằng
`editing.amount.toString()` khi số tiền không tròn đồng, nên chuỗi có dấu chấm
vào được **dù bàn phím đã hết phím `.`** — và số lẻ có thật, `transaction."Amount"`
là `numeric(15,2)` còn `dieu_chinh_so_du_service` sinh khoản bù với ngưỡng nửa
đồng. Cửa ấy **nặng hơn** vì nó nhân mười một khoản **đã có trong sổ**: người
dùng mở một giao dịch cũ ra xem rồi bấm lưu là số tiền tự đổi. Nên chốt nằm ở
**`_saveTransaction`** (`double.tryParse(_amountString)`, thôi strip), còn bỏ
phím là lớp thứ hai.

Ba chỗ đổi: (1) `themPhimSoTien` giữ nhánh **vô hiệu** cho `'.'` cùng họ với
`'done'`/`'+'`/`'-'` — phím có quay lại lưới cũng không phá được; (2) lưới 4×4
thay `'.'` bằng **`'00'`** chứ không để trống, vì thiếu một ô thì hàng cuối còn
ba ô và cả bàn phím lệch cột — nhánh cụm số 0 nay nhận cả `'00'` lẫn `'000'` và
**kẹp theo `conCho`**, thiếu phép kẹp thì `'00'` đẩy chữ số thứ 14 qua trần và
giao dịch kẹt hàng đợi đẩy vĩnh viễn (cùng vòng lặp G31/G14/G46); (3)
`_getFormattedAmount` thôi in chuỗi thô cho số lẻ mà đi qua
**`CurrencyFormatter.formatCoLe`** — nửa *hiển thị* của cùng một lỗi, vì "12.5 đ"
đọc theo quy ước Việt Nam là một con số khác hẳn, ngay cạnh nút lưu.

Người dùng chốt **bỏ phím** (2026-09-19) thay vì đọc đúng thập phân: app làm
tròn về đồng chẵn ở mọi chỗ hiển thị (`CurrencyFormatter.format`), nên phím ấy
không có việc gì để làm. Lệch màn Stitch đúng một phím — cả hai màn Thêm giao
dịch đều vẽ `.`. Bốn ca ở tệp mới
`test/features/transaction/presentation/so_tien_thap_phan_test.dart` (⚠️ phải
dựng trong `GoRouter` **thật** vì lưu xong trang gọi `context.pop()`) cộng bốn
ca `'00'` ở `ban_phim_so_tien_test.dart`. **Schema không đổi, payload không
đổi.**

### 🧭 Nhóm D — cấu trúc menu theo lối B (xong 2026-09-19)

Spec: `docs/superpowers/specs/2026-09-19-nhom-d-cau-truc-menu-design.md`. Kế
hoạch thi công: `docs/superpowers/plans/2026-09-19-nhom-d-cau-truc-menu.md`.

App có **hai hệ điều hướng chồng nhau** — drawer mở từ Trang chủ và thanh tab ở
đáy — với bốn trên chín mục drawer lặp lại đúng thứ thanh tab đã có, và tab Cá
nhân chứa thêm một nhóm module lặp drawer lần nữa. Người dùng chốt **lối B**
(giữ drawer làm menu) vì màn drawer đã có sẵn trên Stitch. Nguyên tắc:
**thanh dưới = việc hằng ngày, drawer = mọi thứ còn lại, không đích nào xuất
hiện ở cả hai chỗ.**

Kết quả: thanh dưới thành **Trang chủ · Phân tích · [+] · Giao dịch · Cá nhân**;
`/budget` rời shell về drawer; drawer còn **bảy** mục; tab Cá nhân gộp trang
Cài đặt; Trang chủ bỏ slogan, nút hero và "Xem báo cáo" (còn **bốn** lối vào
màn Thêm giao dịch thay vì năm). **D4, D8, D9 tự tan** theo — không còn hai tên
cho một đích, không còn glyph heo đất mang hai nghĩa, và "Trợ lý AI chỉ vào từ
drawer" đúng là thiết kế mong muốn khi drawer *là* menu.

⚠️ **Hai quả mìn tìm được trong lúc THIẾT KẾ, cả hai `flutter test` mù:**

1. `/transactions` thành nhánh shell làm hai lời gọi `push` sẵn có ở
   `wallet_list_page` — một trang **ngoài** shell — chết màn đỏ
   (`!keyReservation.contains(key)`). Chốt: một route duy nhất, bốn chỗ gọi đổi
   động từ. Đánh đổi đã chấp nhận: Back từ sổ đã lọc theo ví về **Trang chủ**
   chứ không về màn Ví (luật E3).
2. Hằng **`nhanhThanhTab`** giữ đồng bộ **tay** với router và đang liệt kê
   `/budget`. Quên đổi thì thông báo *khoản chi lớn* (deeplink `/transactions`)
   **chết màn đỏ**, còn thông báo ngân sách `go` tới một route ngoài shell làm
   **thanh tab biến mất**. Sửa một dòng là cả hai tự đúng.

⚠️ **Và nghiệm thu máy ảo bắt được BA lỗi hồi quy nữa, cả ba do chính lượt này
sinh ra, cả ba đi lọt qua toàn bộ bộ test:**

1. **Hai nút `+` chồng nhau** ở trang Sổ giao dịch — trang có FAB riêng, mà
   shell cũng có FAB tròn ở giữa; trước đây trang nằm ngoài shell nên không
   đụng. Gỡ FAB của trang an toàn vì danh sách là **stream**.
2. **Trang Ngân sách thành ngõ cụt.** `automaticallyImplyLeading: false` **đúng**
   hồi nó là một tab (tab không có gì để pop) và sai ngay khi nó thành route
   chồng. Tệ hơn: `_EmptyScaffold` và `_ErrorScaffold` **không có `AppBar` nào
   cả** — tài khoản chưa có ngân sách nào rơi vào một màn trắng không lối ra, và
   đó đúng là màn người dùng mới gặp trước tiên.
3. **"Vùng nguy hiểm" rơi vào giữa** trang Cá nhân vì `NoiDungCaiDat` gói sẵn
   nó — nút xoá tài khoản nằm ngay trên một dòng cài đặt vô hại. Nay widget ấy
   có khe `giua` để mỗi trang tự xếp thứ tự.

**Bài học chung của cả ba:** một cờ hay một widget có thể **đúng ở vai này và
sai ở vai kia**, và đổi vai của một route là đổi ngữ cảnh của mọi thứ nó mang
theo. `flutter test` không dựng cây route thật nên ở đó cả ba đều vô hại.

⚠️ **Lỗi thứ tư, và người dùng là người tìm ra — trang Quản lý danh mục mất
hẳn lối vào.** Bỏ nhóm "QUẢN LÝ TÀI KHOẢN" khỏi tab Cá nhân đưa ba trong bốn
mục về drawer, nhưng **"Danh mục tùy chỉnh" thì chưa bao giờ có ở drawer**: nó
sống ở tab Cá nhân nên drawer cũ không cần, và danh sách sáu mục của spec —
dựng bằng cách lấy drawer cũ trừ ba mục trùng thanh dưới — **thừa hưởng đúng
chỗ thiếu ấy**. Lối vào duy nhất còn lại là một nút chôn trong bảng chọn danh
mục của màn Thêm giao dịch, tức phải mở màn thêm giao dịch mới quản lý được
danh mục. Drawer nay **bảy** mục. **Bài học: chuyển một nhóm menu đi thì phải
soát TỪNG MỤC xem đích đến đã có cửa nào chưa**, đừng suy từ việc danh sách
nhận "đã có sẵn phần lớn"; và `flutter analyze` im lặng vì route vẫn tồn tại,
chỉ là không ai trỏ tới. Ca test `MỌI trang tính năng đều vào được từ menu` nay
canh bằng **luật** (`kMucDrawer ∪ nhanhThanhTab`) chứ không bằng danh sách chép
tay.

⚠️ **Phép canh chia ba lớp** sau khi bản đầu thất bại: dựng router thật kéo theo
cả `GetIt` (`AppDatabase`, `WalletCubit`, `AnalyticsCubit`…), và một ca test
phải dựng nửa cái app là ca giòn. Theo khuôn `main_shell_back_test.dart`:
**cấu hình** (`nhanhThanhTab` khớp router, đọc thẳng tệp nguồn) + **chỗ gọi**
(quét động từ điều hướng) + **thanh dưới** (`MainShell` thật trong một shell
cùng hình dạng, trang giả). Lớp thứ tư là máy ảo. ⚠️ Bẫy **4.4** lại vấp một
lần nữa: ca đo `size.height` của nhãn đỏ ngay ở **"Trang chủ"** — nhãn đang chạy
tốt trên máy thật — vì font Ahem của bộ test rộng gấp đôi nên **mọi** nhãn ngắt
hai dòng; đổi sang bất đẳng thức ở **tầng thuần**, cùng lối nhãn quý `Q3 2026`.

⚠️ **Nhãn tab là "Giao dịch" (9 ký tự), không phải "Sổ giao dịch" (12):** ô nhãn
rộng **cố định 72dp** và mọi nhãn đang chạy được đều ≤ 9 ký tự. Icon
`list_alt_outlined` chứ không `receipt_long` — `receipt_long` đã là "Hóa đơn &
Dịch vụ" ở drawer, và một glyph hai nghĩa đúng là lỗi D8 vừa gỡ cùng ngày.

Stitch (gửi **trước** khi chạm mã): drawer `250229e651a74a83a85c6e9e7091f321`,
Cá nhân `580ee88c6e81472297b523618137ba6a`, Trang chủ
`93501c8554934d15a773bd456a0160ba`. ⚠️ Lượt gọi màn thứ ba trả về **`timeout`**
và `list_screens` ngay sau đó không thấy màn nào mới — rồi chừng một tiếng sau
**cả ba đều có**. Timeout **không phải thất bại**; gọi lại là lãnh thêm một màn
trùng.

**Schema không đổi (v23), payload không đổi.**

**A11 phím `+` `−` — bàn phím làm phép tính thật (xong 2026-09-19).** Hai phím
ấy có trên **cả hai** màn Stitch và vẽ như phím sống, nhưng `themPhimSoTien`
trả nguyên chuỗi cho cả hai — nút chết, đúng như `done` từng bị trước nhóm C.
⚠️ **Test quét `khong_co_nut_chet_test.dart` KHÔNG thấy chúng**: `onTap` trỏ
tới `_onKeyPress`, một hàm thật; chỉ đọc hàm thuần mới lộ ra. Bài học: **một
nút có thể chết ở tầng dưới nút**, và test quét chỉ bắt được cái chết ở đúng
tầng nó quét. Người dùng chốt làm phép tính thật (Money Lover và MISA đều có).

**Văn phạm cố ý hẹp**: chuỗi giữ nhiều nhất **một** phép toán đang chờ —
`"50000"`, `"50000+"`, `"50000+30000"`. Bấm toán tử khi đã đủ hai vế thì **rút
gọn trước** rồi mới nối toán tử mới (nếp máy tính bỏ túi). Nhờ vậy không cần bộ
phân tích biểu thức và không có thứ tự ưu tiên toán tử để hiểu sai. Bốn hàm
thuần mới ở `domain/ban_phim_so_tien.dart`: `ketQuaBieuThuc`, `coToanTu`,
`coPhepToanDangCho`, `nhanBieuThuc`.

⚠️ **Năm chỗ hỏng im lặng:** (1) **trần số chữ số đếm theo TỪNG VẾ** — đếm cả
chuỗi thì vế trước đã ăn hết suất và vế sau bị chặn sớm hơn thật tới 12 chữ số;
(2) **kết quả cũng phải kẹp trần** — hai vế 13 chữ số cộng lại ra **14**, vượt
`numeric(15,2)`, đúng vòng lặp G31/G14/G46; trần suy thẳng từ
`kSoChuSoToiDaSoTien` chứ không ghi cứng; (3) **hiệu được phép ÂM**, không kẹp
về 0 — `_saveTransaction` đã có chốt `amount <= 0` báo ra màn hình, kẹp ở đây
thì lời nhắn ấy chẳng ăn nhập với thứ người dùng vừa gõ (phía âm **không** cần
kẹp: hai vế đều không âm nên hiệu nhỏ nhất đúng bằng âm trần — ghi lại để đừng
ai thêm phép kẹp thứ hai chẳng chặn được gì); (4) `_saveTransaction` phải **rút
gọn**, vì `double.tryParse("50000+30000")` trả `null` rồi rơi về 0 và chốt
`amount <= 0` từ chối một con số vừa gõ đúng; (5) **`coToanTu` và
`coPhepToanDangCho` không thay nhau được** — với `"50000+"` thì cái đầu đúng,
cái sau sai: một cái quyết định dòng số hiện dạng biểu thức hay dạng số tiền,
cái kia quyết định có hiện dòng kết quả không.

⚠️ **Lưới Stitch không có phím `=`**, nên ✓ vừa rút gọn vừa lưu trong một nhịp.
Để người dùng không bấm lưu một con số chưa từng nhìn thấy, dòng dưới con số
đổi từ nhãn `VNĐ - VIỆT NAM ĐỒNG` sang **`= 80.000 đ`** khi có phép toán đủ hai
vế — đây là chỗ duy nhất tổng hiện ra được trước khi ghi. Dòng số chính hiện
**biểu thức, không kèm ký hiệu tiền** (một biểu thức chưa phải một số tiền), và
phép trừ hiện bằng **dấu trừ thật `−` (U+2212)** ở cả lưới lẫn dòng số — gạch
nối ASCII đứng ngay trước một con số đọc như dấu âm. Giá trị nội bộ vẫn là
`'-'`. Nghiệm thu máy ảo: `50.000 +` giữ nhãn tiền tệ, `50.000 + 30.000` cho
`= 80.000 đ`, bấm `−` rút gọn thành `80.000 − 5.000` → `= 75.000 đ`.

Một ca cũ ở `ban_phim_so_tien_test.dart` phải sửa: *"phím điều khiển không đổi
gì"* từng liệt kê cả `'+'` và `'-'` — chính nó là bằng chứng hai phím ấy là nút
chết. Nay ca ấy chỉ còn `'done'` và `'.'`. 26 ca mới ở hai tệp mới. **Schema
không đổi, payload không đổi.**

**A3 — gỡ công tắc sáng/tối (xong 2026-09-19).** Mục "Giao diện" ở tab Cá nhân
vẽ một công tắc hai ô trông như đang chọn được, nhưng `onTap` rỗng và
`AppTheme` chỉ có `lightTheme` — không có `darkTheme` nào để chuyển sang. Người
dùng chốt **gỡ** thay vì làm dark mode (việc cỡ L). Mục này rút khỏi danh sách
chờ chốt của `khong_co_nut_chet_test.dart` — test quét ấy **hai chiều**, nên để
lại mục thừa cũng đỏ. ⚠️ Gỡ xong thì `_ProfileItem.trailing` không còn ai dùng
và `flutter analyze` lên **26** issue (`unused_element_parameter`) — mức nền là
**25**, nên tham số ấy gỡ theo; đây đúng nếp "quét API có 0 chỗ gọi trước khi
commit". 2 ca ở `profile_page_menu_test.dart`. **Schema không đổi, payload không
đổi.**

### 🏦 Gỡ phần client của liên kết ngân hàng (2026-09-18)

**Nhóm chốt bỏ tính năng liên kết ngân hàng.** Đây là quyết định sản phẩm, không
phải hoãn: đừng lên kế hoạch lại cho nó, và đừng coi các cột phục vụ nó là điều
kiện tiên quyết của việc khác.

Phần client của nó **chưa bao giờ chạy thật**. `bank_link_page.dart` là một màn
mockup tĩnh: số điện thoại `0912345678` và sáu ô OTP điền sẵn **ghi cứng trong
`initState`**, nút "Xác nhận" không gọi một endpoint nào. Nhưng nó vẫn nối vào
router và vẫn có một thẻ "LIÊN KẾT NGÂN HÀNG" dẫn tới nó ở màn Quản lý ví, nên
người dùng chạm vào là gặp một biểu mẫu giả vờ đăng nhập ngân hàng.

**Đã gỡ:** hai tệp (`bank_link_page.dart` 448 dòng, `bank_header_row.dart` 114
dòng), hai route `/wallets/bank-link` và `/bank-link` cùng import, khối
`_buildBankIntegrationSection` ở màn Quản lý ví, và
`RealtimeEvent.giaoDichNganHang` cùng nhánh `'bank_transaction.incoming'` của
`realtimeEventFromName`. Backend **vẫn phát** sự kiện ấy (SePay webhook →
`bank.worker.js`), nhưng tên không dịch được đã trả `null` từ trước nên client
chỉ bỏ qua nó êm thấm — nay nó rơi vào đúng nhánh ấy như mọi tên lạ.

⚠️ **Ba thứ GIỮ NGUYÊN, cố ý:** enum `WalletType.banking` (server có thể trả về
nó cho tài khoản từng liên kết, và `tuKhoa` phải đọc được), ba cột SQLite
`provider`/`bank_tran_id`/`bank_casso_id`, và phép loại ví `banking` khỏi
`tinhLaiSoDu`. Cả ba bảo vệ **hàng cũ kéo về**, không phải tính năng. **Schema
không đổi** (vẫn v23), **hợp đồng payload đồng bộ không đổi**.

⚠️ **Chú thích "hộp đen" phải viết lại, ở hai tệp.** Lý lẽ cũ của nó dựa vào
việc `bank_transaction.incoming` được phát từ hai chỗ với hai hình dạng — ví dụ
ấy nay không còn. Cam kết thì **giữ nguyên**: một tên sự kiện đi qua EventBus
vẫn không bảo đảm một hình dạng payload. Mất ví dụ không phải mất lý lẽ.

**Test:** tệp mới `lien_ket_ngan_hang_da_bo_test.dart`, ba ca. Ca đáng giá nhất
là ca **quét `lib/`** cấm mọi tham chiếu tới đường `bank-link`: route và lời
`context.push` là **hai chuỗi rời nhau**, gỡ một bên mà quên bên kia thì
`flutter analyze` không nói gì và lỗi chỉ hiện ra khi người dùng chạm đúng nút.
Ca thứ hai đòi trang **còn dựng được**, vì ca thứ nhất chỉ đòi vắng mặt một
chuỗi nên nó cũng xanh khi cả trang chết — cùng bài học **G43**. Bản sai có chủ
ý đã làm ca `bank_transaction.incoming` đỏ đúng chỗ.

Nhóm test `BankHeaderRow` của `no_overflow_test.dart` **mất theo widget** — đó
là chỗ tràn nặng nhất từng đo được trên máy thật (21px), nên tệp ấy nay canh hai
hàng chứ không ba.

⚠️ **Màn Stitch của Quản lý ví vẫn vẽ thẻ liên kết** — bản thi công nay lệch
Stitch đúng một thẻ, và đó là lệch **có chủ ý**.

**Nghiệm thu máy ảo 411dp:** màn Quản lý ví dựng sạch, danh sách ví kết thúc ở
nút "Thêm ví mới", không còn thẻ liên kết, không sọc tràn.

**Mức nền:** `flutter test` **2853/2853**, `flutter analyze` **25 issue / 0
error**.

### 🔢 Trần số chữ số thiếu ở bốn mảng còn lại — G46 (2026-09-18)

Lượt soát nối tiếp G45, lần này quét **cả app**. Kết quả: lỗ hổng vừa vá ở ô số
dư ví **không phải chuyện riêng của ví**. Đo trên CSDL cùng ngày, **tám** cột
tiền đều là `numeric(15,2)`, và **bốn mảng còn lại** đều không giới hạn số chữ
số: giao dịch, hoá đơn, mục tiêu, ngân sách. Bàn giao ở **G46**
`docs/CLIENT_APP_KNOWN_GAPS.md`.

**Nặng nhất là màn Thêm giao dịch**: người dùng ghi giao dịch **hàng ngày**, bàn
phím ở đó là **tự vẽ** chứ không phải `TextField` nên `inputFormatters` không
với tới, và nó có phím **`000`** — ba chữ số vào một lúc. Nay phép gõ tách thành
hàm thuần **`themPhimSoTien`**, và ⚠️ phím `000` **cắt bớt cho vừa trần** thay
vì bỏ cả cụm: bỏ cả cụm thì người dùng bấm mà không thấy gì xảy ra.

**Thêm test quét `lib/` thứ tám** (`o_nhap_tien_co_tran_test.dart`). Lý do cần
nó: thiếu trần **không gây lỗi nào** lúc gõ — ô vẫn nhận, màn vẫn lưu, SQLite
vẫn ghi. Chỉ hàng đợi đẩy là hỏng, và nó hỏng ở nơi không ai nhìn.

⚠️ **Lần thứ BA trong cùng một ngày** một trần số chữ số biến giá trị lớn nhất
thành **hợp lệ đạt tới được** rồi lộ ra một bố cục chưa từng được thử với giá
trị ấy. Ở cỡ chữ 48 trên 411dp, `9.999.999.999.999đ` **ngắt thành hai dòng**,
chữ "đ" rơi xuống dòng dưới và đẩy cả màn xuống. Đây **không phải tràn**: không
sọc vàng, không `FlutterError`, `takeException()` trả `null` — `Text` chỉ lặng
lẽ ngắt dòng. Nên ca test phải đo **chiều cao thật**; bản sai cho 207px so với
ngưỡng 80. Sửa bằng widget `SoTienLon`.

⚠️ **`FittedBox` dùng được ở đây mà không dùng được ở ô số dư ví**: nó đo con ở
ràng buộc **vô hạn** rồi mới thu nhỏ, mà `Text` có bề rộng tự nhiên xác định
dưới ràng buộc ấy còn `TextField` thì không. Đó là lý do `OSoDuVi` phải đi đường
khác (`Flexible` + bậc thang cỡ chữ).

**Mọi ràng buộc khác đã kiểm và an toàn, không phải sửa gì**: số tiền phải dương
ở bốn mảng; ngưỡng phần trăm 1–100; ngày kết thúc sau ngày bắt đầu; tiến độ mục
tiêu không âm được; loại giao dịch và phân loại danh mục đều được normalizer
dịch; bảy ô nhập tên đều có giới hạn độ dài.

**Nghiệm thu máy ảo:** bấm phím số 20 lần ở màn Thêm giao dịch thì dừng đúng 13
chữ số, hiện **một dòng**, cỡ chữ đã co.

**16 ca test mới**, `flutter test` **2854/2854**, `flutter analyze` 25 issue / 0
error. **Không đổi schema** (vẫn v23), **không thêm trường đồng bộ**.

### 👛 Sáu lỗ hổng của mảng ví — G45, mở và đóng cùng ngày (2026-09-18)

Không đến từ báo lỗi nào. Người dùng hỏi mảng ví *đã đầy đủ chưa, có lỗ hổng gì,
có ràng buộc nào cần bổ sung*, và lượt soát đối chiếu **từng ràng buộc
PostgreSQL với chốt tương ứng phía client**. Sáu chỗ hở, tất cả hỏng **im
lặng**. Bảng đầy đủ ở **G45** `docs/CLIENT_APP_KNOWN_GAPS.md`.

**Nặng nhất là số dư không giới hạn chữ số.** `wallet."Balance"` là
`numeric(15,2)`, tức 13 chữ số phần nguyên. Tràn cho SQLSTATE **`22003`**, mà
`sync.service.js` **không có nhánh nào** cho mã ấy nên nó rơi về `DB_ERROR`; và
`_permanentCodes` của `SyncEngine` là **danh sách trắng**, `DB_ERROR` không nằm
trong đó. Kết quả: ví bị **gửi lại ở mọi chu kỳ đồng bộ**, không lỗi, không log,
chỉ một hàng đợi càng lúc càng chậm. Đúng vòng lặp mà G31 và G14 sinh ra để
chặn, chỉ khác cột.

**Năm cái còn lại:** `softDelete` không chặn ví đang gắn **hoá đơn** (server để
`fk_bill_wallet` là `ON DELETE RESTRICT`, và đo trên dữ liệu thật thấy **một ví
xoá được ngay lúc ấy** trong 26 hoá đơn đang gắn ví); phép đếm giao dịch bỏ sót
**khoản chuyển đến** vì `getByWallet` chỉ lọc cột `walletId`; thông báo "điều
chuyển số dư về 0đ trước khi xóa" **dẫn tới ngõ cụt** từ sau G37; `currency` là
cột CHECK **duy nhất** chưa được `walletForPush` che; và thiếu chốt cấm đặt ví
**đã lưu trữ** làm ví mặc định.

⚠️ **Hai lỗi NỮA do chính lượt vá sinh ra, cả hai chỉ máy ảo thấy.** Giới hạn 13
chữ số biến một trạng thái vốn vô nghĩa thành **hợp lệ đạt tới được**, và ở cỡ
chữ 40 trên 411dp thì `9.999.999.999.999` tràn bố cục **70px**. Sửa bằng widget
mới `OSoDuVi` — rồi widget ấy lộ lỗi thứ hai: nó là `StatelessWidget` đọc
`controller.text` **một lần** lúc dựng, nên cỡ chữ không co khi người dùng gõ và
số dài bị **cuộn khuất mất chữ số đầu**. Bố cục vẫn lành nhờ `Flexible` nên
**không có sọc vàng nào để nhìn thấy**.

⚠️ **Một bản sai lật kết luận, đáng nhớ nhất của lượt này.** Thứ chặn tràn là
**`Flexible`** bọc `IntrinsicWidth`, **không phải** bậc thang cỡ chữ: ép cỡ chữ
về 40 cố định mà hai ca bố cục **vẫn xanh**. Hai thứ làm hai việc — `Flexible`
giữ bố cục không vỡ, `coChuSoDu` giữ con số đọc được hết — nên ca test của bậc
thang đo **thẳng giá trị trả về**, không đo bề rộng. Cùng họ bài học G43: một ca
xanh chỉ đáng tin sau khi bản sai làm nó đỏ.

**Nghiệm thu máy ảo:** gõ 18 chữ số chỉ nhận `9.999.999.999.999`, hiện trọn vẹn,
cỡ chữ đã co; xoá ví "test" hiện đúng thông báo mới và ví không bị xoá.

**21 ca test mới**, `flutter test` **2838/2838**, `flutter analyze` 25 issue / 0
error. **Không đổi schema** (vẫn v23), **không thêm trường đồng bộ** (payload ví
vẫn 13 trường), **không xin backend gì**.

**Ba chỗ cố ý không làm:** không thêm nút "đưa số dư về 0 rồi lưu trữ" (tính
năng mới); không ép màn Sửa ví dùng `OSoDuVi` (bố cục riêng, `Expanded` nên vốn
không tràn — nhưng khối `onChanged` chèn dấu chấm vẫn còn **hai bản**); không
xoá `bienThang` dù nó đã 0 chỗ gọi.

### 🗓️ Trang Xuất báo cáo dùng chung bộ chọn kỳ với trang Phân tích (2026-09-18)

Trang Xuất báo cáo nay xuất được theo **tuần** và **năm** — thứ bốn chip cứng cũ
(*Tháng này · Tháng trước · Quý này · Tùy chỉnh*) không làm được, dù
`tongThuChi` và `getExpenses` bên dưới vốn nhận khoảng bất kỳ. Nút chọn kỳ mở
thẳng `moChonPhamVi`, cùng bottom sheet của trang Phân tích. `PhamViThoiGian`
và `khoangCuaPhamVi` **bỏ hẳn**. Bàn giao ở mục **3.33**
`docs/ANALYTICS_FEATURE.md`.

**Người dùng chốt KHÔNG đưa khối nào của trang Phân tích vào tệp xuất**, sau một
lượt khảo sát bảy app thị trường: **0/7** app xuất cả màn phân tích ra một tệp,
**6/7** chỉ xuất CSV thuần dữ liệu. PocketSmith ghi thẳng là họ không làm nút in
trong app, và riêng trang Calendar của họ in ra không đọc được — đúng khối Lịch
chi tiêu của mục 3.29. Khi app muốn cho mang hình đi, họ cho **một** biểu đồ
(Monarch: PNG; Copilot: slide), không gói cả trang.

⚠️ Cộng một lý do kỹ thuật: gói `pdf` **không dùng lại được `fl_chart`**, nên
mỗi biểu đồ đưa vào PDF là bản thi công **thứ hai** của cùng phép vẽ.

**Bốn chỗ dễ vấp:** (1) `Ky.tuyChon` **không** tự cộng một ngày vào biên phải
còn `khoangCuaPhamVi` thì có — thiếu vế ấy là báo cáo hụt đúng ngày cuối cùng
người dùng chọn, im lặng, và đường vào của thông báo **Tổng kết tuần** đi qua
đúng chỗ này; (2) nhãn nút phải đi qua **`nhanRong`** chứ không `nhanOChon`;
(3) **mất khả năng xuất kỳ chứa ngày tương lai** — sheet chặn ở hôm nay theo
luật G43, chấp nhận có chủ ý để hai trang nói cùng một luật; (4) "Tháng trước"
và "Quý này" **không** mất đi vì bộ chọn liệt kê 12 tháng và 8 quý gần nhất.

⚠️ **`nhanRong` là hàm nhãn THỨ HAI, và nó sinh ra từ một lỗi chỉ máy ảo thấy.**
Sau khi chạm dòng *"Tuần 37 (07/09 – 13/09)"*, nút hiện **"Tuần 37" trần** —
mất khoảng ngày, ngay trước lúc người dùng xuất báo cáo theo đúng khoảng ấy.
`nhanOChon` rơi về nhãn ngắn khi kỳ không chứa hôm nay, vì nó sinh ra cho **ô
header hẹp** của trang Phân tích (chỗ đã tràn 53px một lần). Hai chỗ có bề ngang
khác hẳn nhau và **cả hai lựa chọn đều đúng ở chỗ của nó**, nên câu trả lời là
một hàm thứ hai chứ không phải sửa hàm cũ. Nó cũng **thay một bản chép tay**:
`ChonPhamViSheet._dong` vốn tự viết lại đúng biểu thức ấy. Bộ test mù trước lỗi
này vì **cả hai chuỗi đều hợp lý**.

**Chín ca test mới**, bảy ca của `khoangCuaPhamVi` bỏ theo hàm. `flutter test`
**2817/2817**, `flutter analyze` 25 issue / 0 error. Không đổi schema (vẫn v23),
không thêm trường đồng bộ, không đụng repository.

Màn Stitch **`4a12791ff0eb49abb627be187eb6ba85`** *"Xuất báo cáo - FlowMoney"*
(lượt gọi **không** timeout) — nó khớp bản thi công ở mọi điểm, và chính nó chỉ
ra nhãn phải là *"Tháng này (T9 2026)"* chứ không *"T9 2026"*.

⚠️ **`bienThang` nay 0 chỗ gọi trong `lib`** — chỗ gọi cuối cùng là
`khoangCuaPhamVi`. `Ky.thang` làm đúng việc ấy. Giữ lại vì ngoài phạm vi lượt
này và vẫn có bốn ca test riêng; ứng viên dọn cho lần sau.

### 🧾 Kỳ rỗng thì tệp xuất thôi in khối Ngân sách — G44 đóng (2026-09-18)

Lỗ hổng cuối cùng còn mở mà **không** phải "hoãn có chủ ý" — nay chỉ còn G18 và
G23, cả hai đều là quyết định chứ không phải việc. Bàn giao đầy đủ ở **G44**
`docs/CLIENT_APP_KNOWN_GAPS.md`.

**Chiều đã chốt (người dùng): tệp theo màn.** Kỳ không có giao dịch nào thì tệp
PDF/CSV bỏ hẳn bảng *Ngân sách kỳ này*, đúng như màn Xem trước vẫn làm. Lý lẽ:
"đã chi" của một ngân sách đếm theo kỳ của **chính nó**, nên đặt bảng ấy trong
tệp báo cáo của một kỳ rỗng là chở một con số thuộc khoảng thời gian khác — và
người cầm tờ PDF không có chỗ hỏi lại.

**Luật nay có một chỗ:** vị từ thuần `inKhoiTheoKy(BaoCao)` ở
`analytics/domain/bao_cao_xuat.dart`, **ba** chỗ cùng đọc — `csvBaoCao`,
`pdfBaoCao`, và nhánh rỗng của `report_preview_page.dart`. Khối *Số liệu nhanh*
vốn gác bằng `!bc.rong` kèm chú thích *"cùng luật với màn Xem trước"*; nay chú
thích ấy thành mã. Cùng khuôn `khoanVaoThongKe` / `viTinhVaoTong` /
`billPayStatus`. **Không đổi schema** (vẫn v23), **không thêm trường đồng bộ**,
không đụng repository.

⚠️ **Ngân sách là khối duy nhất cần vế ấy** — mọi khối khác tự rỗng theo một kỳ
rỗng, nên `isNotEmpty` của chúng đã trùng khớp sẵn với màn. Vế `inKhoiTheoKy`
đứng **cạnh** `isNotEmpty` chứ không thay nó.

⚠️ **Ở nhánh PDF phải chặn tại nguồn hàng**, không bọc quanh `_pdfBang`: hàm ấy
tự bỏ cả bảng khi danh sách hàng rỗng, nên truyền danh sách rỗng là đủ và tránh
một nhánh `if` thứ hai phải giữ đồng bộ.

⚠️ **Lượt sửa đính chính chính tiêu đề cũ của G44.** Câu *"màn Xem trước giấu
**mọi** khối"* sai: kỳ rỗng thì màn vẫn hiện đầu báo cáo, khối **Dòng tiền** và
**ba thẻ tổng** — và tệp cũng in đúng ba thứ ấy, nên hai bên lệch **đúng một
khối**. Chỗ này đáng nhớ vì nó quyết định chiều sửa: nếu màn thật sự giấu mọi
thứ thì "tệp theo màn" sẽ cắt cả số dư đầu/cuối kỳ, một thông tin có nghĩa
ngay cả với kỳ rỗng.

⚠️ **Ca test cho nhánh PDF phải so ĐỘ DÀI tệp, không tìm chuỗi** — PDF nén luồng
nội dung nên `String.fromCharCodes(bytes).contains('NGÂN SÁCH KỲ NÀY')` không
bao giờ khớp, và một ca như thế sẽ **xanh trên cả bản sai**. Phép đo dùng được:
hai tệp của cùng một kỳ rỗng, một bản có ngân sách một bản không, độ dài phải
bằng nhau. Bản sai có chủ ý làm nó đỏ với chênh lệch **2 847 byte**.

**Năm ca test mới**, `flutter test` **2815/2815**, `flutter analyze` 25 issue /
0 error.

> ⚠️ **Ngoài phạm vi G44, nhưng cùng lượt:** ba ca của
> `test/core/notification/os/os_notifier_native_test.dart` ghi **cứng** mốc
> `DateTime(2026, 9, 17, 21, 30)` (hai ca) và `DateTime(2026, 9, 20, 8)` (một
> ca). `flutter_local_notifications` gọi `validateDateIsInTheFuture` và **ném**
> với mốc đã qua, nên hai ca đầu **đỏ từ sáng 18/09** — một quả mìn hẹn giờ ở
> vùng chẳng ai vừa đụng vào, và nó làm cả bộ test đỏ trong khi lỗi chẳng liên
> quan gì tới thứ vừa sửa. Nay cả ba dùng mốc **tương đối** (`DateTime.now()`
> cộng một/hai ngày). Giờ **21:30 giữ nguyên**: đó là thứ ca đầu dùng để bắt
> lỗi neo `TZDateTime` vào UTC — lệch 7 tiếng ở Việt Nam, không lỗi nào báo ra
> (bẫy 7.3) — nên một mốc tròn giờ sẽ làm ca ấy yếu đi.

### 📄 Ba khối cuối vào tệp xuất báo cáo — và một lỗi glyph có từ 2026-09-09 (2026-09-17)

Tệp PDF/CSV nay mang **so với kỳ trước**, **số liệu nhanh** và **top 5 khoản
chi** — ba khối mà màn Xem trước đã hiện từ 2026-09-09 còn tệp thì không. Cả ba
đã nằm sẵn trong `BaoCao`, nên cả hạng mục gói trong **một** tệp `lib`:
`features/analytics/domain/xuat_tep.dart`. **Schema không đổi** (vẫn v23),
**không thêm trường đồng bộ**, không đụng repository. Lý do đầy đủ ở mục
**3.31 `docs/ANALYTICS_FEATURE.md`**. 16 test mới, tất cả ở `xuat_tep_test.dart`
(**không** thêm tệp). `flutter test` **2810/2810** · `flutter analyze`
**25 issue, 0 error**.

> ⚠️ **Lượt này bắt được một lỗi đã chạy trong app từ 2026-09-09.** Bản Roboto
> nhúng cho PDF **không có** khối Mũi tên (U+2190…) lẫn khối Hình học
> (U+25A0…), và gói `pdf` **bỏ ký tự thiếu glyph đi** rồi chỉ in một dòng ra
> console. Nên dòng dòng tiền của **mọi tệp PDF app từng xuất** đều mất dấu
> `→`, im lặng — đúng họ với lỗi "rơi về Helvetica" mà mục 3.17 đã dựng hàng
> rào, chỉ khác là bản font **đúng** vẫn dính. Nay là `»`.
> Nó lộ ra vì bản thiết kế đầu định dùng `▲`/`▼` cho dòng phần trăm của PDF —
> hai ký tự ấy **cũng** thiếu. Phần trăm nay là `+12,5%` / `-3,0%`, màu vẫn nói
> tốt/xấu.
> Phép canh là một ca test quét **chuỗi hằng của chính `xuat_tep.dart`** rồi
> đòi mọi ký tự ngoài ASCII có mặt trong `charToGlyphIndexMap` của cả hai tệp
> Roboto (`TtfParser` là API công khai của gói `pdf`). Chữ của *người dùng* thì
> không chặn trước được — giới hạn cố ý.
> ⚠️ Hai bẫy im lặng nữa, đều có ca test riêng: `_tiLe` nhân 100 còn
> `phanTramSoVoi` đã nhân rồi (dùng nhầm là in `1250.0`), và ô phần trăm của
> CSV phải **rỗng** chứ không `—` vì đó là cột số Excel sắp cộng.
> **Đã kiểm trên `emulator-5554`** (tài khoản 10, dữ liệu thật): xuất CSV và
> PDF tháng 9, cộng một khoảng **rỗng** có kỳ trước **không** rỗng (08–17/09)
> để chạm cả hai nhánh phần trăm; kéo tệp về đọc bằng `adb pull` + `pypdf`.
> ⚠️ Bố cục PDF chỉ kiểm được qua **thứ tự văn bản** — máy này không có
> poppler/ghostscript để dựng ảnh raster.
> ⚠️ Một chỗ lệch **có sẵn**, không phải do hạng mục này: kỳ rỗng thì màn Xem
> trước giấu mọi khối, còn tệp vẫn in khối **Ngân sách kỳ này** (ngân sách tồn
> tại độc lập với giao dịch). Chưa rõ bên nào đúng — mở thành **G44**
> `docs/CLIENT_APP_KNOWN_GAPS.md`, hoãn có chủ ý.
> ✅ **G44 đã đóng 2026-09-18** theo chiều *"tệp theo màn"* — xem khối 🧾 ở đầu
> mục 14. ⚠️ Và câu "màn Xem trước giấu **mọi** khối" ngay trên là **sai**, đo
> lại khi sửa: màn vẫn hiện đầu báo cáo, khối Dòng tiền và ba thẻ tổng.

### 💳 Ví được phép âm — G27 đóng (2026-09-17)

Lỗ hổng cuối cùng còn mở mà **không** phải "hoãn có chủ ý". Ví đánh dấu cho
phép âm — thẻ tín dụng, ví theo dõi nợ — thôi bị nhắc "ví âm" mỗi ngày, và màn
Quản lý ví thôi tô đỏ nó. Bàn giao ở **G27** `docs/CLIENT_APP_KNOWN_GAPS.md`.

Chỗ bám là một **cờ** (`Wallets.allowNegative`, **schema v23**) chứ không phải
một loại ví: chuỗi `'debt'` chết ngày 2026-09-09 vì nó vỡ `chk_wallet_type` của
PostgreSQL và làm ví kẹt hàng đợi đẩy vĩnh viễn — khôi phục nó là tái hiện đúng
sự cố ấy. Migration chỉ `addColumn`; mặc định `false` **chính là** hành vi trước
bản này, nên không bản cài nào đổi hành vi lặng lẽ.

⚠️ **Cột CỤC BỘ** — payload ví vẫn **13 trường**, và có **test quét `lib/` thứ
bảy** canh cờ không lọt vào đường đồng bộ. Đó là bài học ngược chiều của G28:
khi `wallet.status` còn cục bộ, **ba** chú thích ở ba tệp khác vẫn nói nó đi ra
máy khác. Chữ thì trôi, test quét thì không.

**Hai bẫy chỉ bản sai và máy ảo mới lộ, và cả hai là lỗ hổng trong chính bộ
test vừa viết:** ca "cờ cũng tắt cảnh báo sắp cạn" dựng ví số dư **âm**, mà
nhánh ấy chỉ chạy khi `balance >= 0` — nó **không canh gì** (họ G43); và ca
datasource đặt **sai tiền đề** — quên cột trong `_toCompanion` không làm cờ tự
tắt mà làm cờ **không đổi được**, vì `write(companion)` chỉ ghi cột có mặt.

Máy ảo còn bắt được một chỗ **nửa việc**: bản đầu chỉ đổi màu biểu tượng, con
số `-100.000 đ` vẫn đỏ chói — mà đó mới là thứ mắt đọc trước.

Nghiệm thu: migration v23 chạy sạch trên CSDL đang có (33 giao dịch nguyên
vẹn), cờ sống sót qua `force-stop` + khởi động lại. `flutter test` **2794/2794**,
`flutter analyze` **25 issue, 0 error**.

### 🔔 Khoản chi lớn — loại thông báo thứ 18 (2026-09-17)

Mục **#7** của khảo sát app thị trường lần hai, và là mục **cuối cùng** của bảng
ấy — khảo sát nay **đóng**. Bàn giao đầy đủ ở mục **5f**
`docs/NOTIFICATION_FEATURE.md`.

⚠️ **"Bất thường" ở đây là NGƯỠNG người dùng đặt, không phải thống kê theo danh
mục** như Rocket Money. Phép đo quyết định lối này: tài khoản thật có **8 ngày**
dữ liệu và danh mục đông nhất chỉ **5** giao dịch (đo 2026-09-17), nên một luật
thống kê sẽ im hàng tháng rồi bắt đầu nổ bừa ngay khi vừa đủ mẫu. Một con số do
người dùng đặt thì chạy từ ngày đầu và **không thể báo động giả** — điều đáng
giữ nhất, vì ai tắt thông báo vì phiền sẽ mất luôn 17 loại kia.

`nguongChiLon` mặc định **0 = tắt**, bản sao đúng khuôn `nguongSoDuThap`. Xếp
vào **nhóm Ngân sách** nên không thêm chip, không đụng ca canh
`NotificationGroup.values.length + 2`.

**Ba chốt hỏng im lặng:** "chi" đi qua `khoanVaoThongKe` (loại khoản chuyển,
điều chỉnh số dư và **mở sổ**); khoá `bigSpend:<idGiaoDich>` **không chở
`walletId`** — chở nó thì đổi ví của một khoản chi đẻ thông báo thứ hai, nên
deeplink là `/transactions` trần; và `createdAt` là **ngày giao dịch**, nếu
không thì `silenceBefore` mất tác dụng ở lần bật đầu tiên.

Nghiệm thu máy ảo: đặt 500.000 → **một** hàng đúng ngày giao dịch, lượt quét thứ
hai **0 hàng mới**, chạm mở Sổ giao dịch, đặt lại Tắt thì im. Không đổi schema
(vẫn **v22**), không thêm trường đồng bộ. `flutter test` **2774/2774**,
`flutter analyze` **25 issue, 0 error**.

### 💰 Tổng tài sản theo thời gian (2026-09-17)

Mục **#5** của khảo sát app thị trường lần hai — đường thứ **ba** của bộ sáu kỳ
trên trang Phân tích, đứng ngay sau *Dòng tiền tự do*: một con số lớn (tổng tài
sản hiện tại), một đường sáu điểm, và khi cần thì một câu nói thẳng rằng đoạn
đầu đường chưa có gì để dựa vào. Bàn giao ở mục **3.30**
`docs/ANALYTICS_FEATURE.md`; màn Stitch `b0a3344924d246f9b6322fb75a3309e4`.

⚠️ **Tên đổi khỏi "tài sản ròng"** mà bảng khảo sát mượn của Monarch: app không
có mô hình công nợ (A8 #9 đã bỏ hẳn), nên tiền **đi vay** nằm trong ví sẽ làm
"tài sản ròng" **tăng lên** đúng lúc người dùng mắc nợ thêm. Người dùng chốt đo
đúng thứ tính được — tổng số dư các ví được tính vào tổng.

**Suy ngược được là nhờ G37**: từ 2026-09-13 `wallets.balance` là **cache của
một công thức** trên sổ giao dịch, nên số dư tại mọi thời điểm suy lại được.
Mục 3.16 nói "không lưu lịch sử số dư → chịu" là ảnh chụp trước G37. Đây là lần
thứ **tư** bài học *"chặn vì thiếu con số nào?"* trả tiền, sau A8 #4, #5 và #8.

⚠️ **Phép đo lật giả định của mục 3.25**: vách do khoản neo *"Số dư ban đầu"*
ghi ngày vá **không tồn tại** trên dữ liệu thật (đo 2026-09-17: cả bốn ví có
`Balance` khớp đúng tổng sổ, không khoản neo nào). Giới hạn thật — lớn hơn — là
mọi mốc **trước giao dịch đầu tiên** cho một con số vô nghĩa; khối nói ra điều
ấy bằng một câu dưới biểu đồ, và **ẩn** dòng thay đổi thay vì in một khoản tăng
bịa.

🔑 **Một phát hiện để dành, cố ý không thi công**: server có
`wallet.Create_at` (`schema.prisma`, `@default(now())`) và đường pull **đã trả
nó về rồi** — `getWalletsByAccount` là `findMany` **không `select`**. Client chỉ
là chưa đọc. Nó cho biết ngày tạo ví thật, nhưng thứ nó vá là một vách đo được
là không tồn tại.

Cùng lượt, **`daiTrucDuBao` bị siết lại**: `dải/2` là một phép **trừ hao** làm
trần rộng gấp đôi mức cần với dải bắt đầu từ 0 (13,59M → trần 30M, đường dí sát
đáy máy ảo), nay là `dải/3` cộng phép kiểm đúng. Khối Dự báo **không đổi** —
dải hẹp quanh số lớn cho cùng một bước ở cả hai công thức. Vế **thứ ba** của
bẫy **4.21**.

Không đổi schema (vẫn **v22**), không thêm trường đồng bộ, không nguồn stream
mới. `flutter test` **2743/2743**, `flutter analyze` **25 issue, 0 error**.

### 📅 Lịch chi tiêu (2026-09-16)

Mục **#6** của khảo sát app thị trường lần hai. Lưới **lịch tháng** trên trang
Phân tích, ô đậm nhạt theo tổng chi của ngày; chạm một ô thì thẻ tóm tắt hiện
ngay dưới lưới (ngày, số khoản, tổng chi, khoản lớn nhất). Khối **chỉ hiện khi
đơn vị đang xem là Tháng** — chốt đặt ở **hai lớp**. Bàn giao ở mục **3.29**
`docs/ANALYTICS_FEATURE.md`; màn Stitch `9020ff8b5c5d49c4914442dcd02fa540`.

**Không đổi schema** (v22), **không thêm trường đồng bộ**, **không có nguồn
stream mới**: `soLieuNhanhCua` đã dựng sẵn một map theo ngày bên trong nhưng
không lộ ra, nên việc chính là **tách nó thành hàm dùng chung** `lichChiTieuCua`
và cho hàm cũ gọi lại. `flutter test` **2702/2702** · `flutter analyze` **25
issue, 0 error** (đếm bằng máy).

⚠️ **Thang màu neo vào TRUNG BÌNH, không vào ngày lớn nhất** — neo vào max thì
một ngày mua sắm lớn làm phẳng cả tháng và lưới trông như tháng không tiêu gì.

⚠️ **Hai thứ bộ test không thấy được nếu không thử bản sai:** `_tieuDeKhoi` là
`SizedBox(width: double.infinity)` nên đặt trần vào `Row` làm **66/74** ca của
trang đỏ cùng lúc; và ca "chưa chạm thì chưa có thẻ tóm tắt" **ban đầu không
canh được gì** — nó chỉ cấm chữ "khoản", trong khi bản sai hiện thẻ cho một ngày
không chi nên thẻ nói "Không chi". Cùng bài học với G43: ca test phải đòi **kết
quả**, không chỉ đòi vắng mặt thứ mình nghĩ tới.

### 🛠️ G43 — nút "Tuỳ chọn" chết im lặng (2026-09-16)

Lỗi **có sẵn từ P1** (2026-09-15), tìm được khi nghiệm thu máy ảo cho mục #2.
Chạm "Tuỳ chọn" trong bộ chọn phạm vi thì **không có gì xảy ra**:
`showDateRangePicker` ném assertion vì `initialDateRange` thò ra ngoài
`[firstDate, lastDate]` — kỳ "Tháng này" kết thúc 30/09 trong khi `lastDate` là
hôm nay 16/09. Đó là exception **bất đồng bộ không ai bắt**, nên không toast,
không màn đỏ, chỉ một dòng logcat người dùng không bao giờ thấy. Nó nổ ở đúng
**trạng thái mặc định** của trang (Tuần này · Tháng này · Quý này · Năm nay).

Phép kẹp nay là hàm thuần `khoangKhoiTaoBoChonNgay` (`analytics/domain/
pham_vi_ky.dart`), trả `null` khi kỳ không giao với dải cho phép. Bốn ca widget
mới chạm **thật** vào nút và đòi `DateRangePickerDialog` hiện ra — "không ném"
một mình vẫn xanh với một nút chết. Chi tiết: **G43**
`docs/CLIENT_APP_KNOWN_GAPS.md`.

⚠️ **Vì sao bộ test mù suốt một ngày:** `chon_pham_vi_sheet_test.dart` có **10** ca
nhưng **không ca nào chạm vào chip ấy**. Lỗi nằm sau một cú chạm không ai thực
hiện — cùng họ với bài học "test xanh không chứng minh đường đi được chạy".

`flutter test` **2679/2679** · `flutter analyze` **25 issue, 0 error**.

### 🔁 So cùng kỳ năm trước (2026-09-16)

Mục **#2** của khảo sát app thị trường lần hai. Hai thẻ tổng trang Phân tích nay
có **hàng hai chip** — *"So với kỳ trước"* · *"Cùng kỳ năm trước"* — và dòng
"so với …" đổi theo chip. Chip trái bật sẵn nên người dùng cũ không thấy gì đổi.
Bàn giao ở mục **3.28** `docs/ANALYTICS_FEATURE.md`; màn Stitch
`6333b8e24aab4f92bd73b1282c56b17c`.

**Không đổi schema** (v22 giữ nguyên), **không thêm trường đồng bộ**, **không có
nguồn stream thứ tám** — `watchKy` vốn nạp toàn bộ giao dịch của tài khoản nên
kỳ năm trước chỉ là một lời gọi `tongThuChi` nữa. `flutter test` **2670/2670** ·
`flutter analyze` **25 issue, 0 error** (đếm bằng máy 2026-09-16).

⚠️ **Phép đo lật ngược bản thiết kế đã duyệt.** Thiết kế nói tuần phải neo vào
*ngày dương lịch* năm trước chứ đừng lùi 52 kỳ. Đo trên **3131 tuần của 60 năm**:
lối neo thứ Hai cho kỳ so sánh chồng lấp ít nhất **1 ngày**, còn `lui(ky, 52)`
cho **5 ngày** và trùng khít lối neo vào **thứ Năm** (ngày định danh tuần ISO) ở
**cả 3131 tuần**. Bài học: một ca test đỏ có thể đang tố cáo **bản thiết kế**
chứ không phải bản thi công — đo trước, đừng sửa bên nào cho xanh.

⚠️ Lượt nghiệm thu máy ảo của lát này lộ ra **G43** — một lỗi **có sẵn**, không
thuộc lát này: nút "Tuỳ chọn" của bộ chọn phạm vi ném assertion và không làm gì,
hoàn toàn im lặng.

### 🛑 Bảng A8 ĐÓNG — bỏ hẳn #9 và #11 (2026-09-16)

Người dùng chốt **bỏ hẳn** hai ô cuối của bảng A8 (mục **7.1**
`docs/ANALYTICS_FEATURE.md`): **#9** (biến động khoản vay) và **#11** (Sankey).
Nguyên văn: *"bỏ biến động khoản vay với Sankey đi không cần thiết nữa"*. Cùng
lượt, mục **#3** của bảng khảo sát thị trường lần hai (mục 3.25 — chính là
Sankey) cũng bỏ.

Đây là quyết định về **phạm vi sản phẩm**, không phải hoãn. Hệ quả cần nhớ:

- **Đừng lên kế hoạch cho hai mục ấy nữa**, kể cả khi thấy bảng A8 còn ô trống.
- **Đừng mở lại hàng đợi `docs/superpowers/backend/CAN-LAM/`** để xin dư nợ gốc
  / lãi suất / kỳ hạn — mục duy nhất cần những cột ấy đã bị bỏ. *(Chữ "đang
  rỗng" đứng ở đây tới 2026-09-22 là ảnh chụp của 2026-09-16 và đã sai từ
  2026-09-18; thư mục ấy nay có **hai** tệp xin. Lời dặn thì vẫn nguyên: đừng
  mở lại hàng đợi **cho việc này**.)*
- Kế hoạch `docs/superpowers/plans/2026-09-15-con-lai-mang-phan-tich.md` và
  `2026-09-15-ke-hoach.md` (cả hai gitignore) nay **không còn hạng mục nào**.

Bài học chung: **một ô trống trong bảng theo dõi không đồng nghĩa với một việc
phải làm.** Khi chỉ còn những mục khó hoặc bị chặn bởi mô hình dữ liệu, hỏi
người dùng có còn cần không trước khi lên kế hoạch, thay vì mặc định phải lấp
cho đầy bảng.

⚠️ Mảng Phân tích đóng không có nghĩa **mảng Báo cáo** cũng vậy: đo ngày
2026-09-16, **tệp PDF/CSV tải về thiếu ba khối** mà chính màn Xem trước ngay
trên nút "Tải xuống" đang hiện — % so với kỳ trước (`tongTruoc`), số liệu nhanh
(`soLieu`), và top 5 khoản chi (`topChi`). Cả ba trường **đã nằm sẵn** trong
`BaoCao` nhưng `analytics/domain/xuat_tep.dart` không đọc (grep ba tên trường
trong tệp ấy: **0** kết quả). ✅ **Khoảng lệch thứ nhất đã đóng ngày
2026-09-17** — mục **3.31 `docs/ANALYTICS_FEATURE.md`**, và lượt ấy còn lôi ra
một lỗi glyph đã chạy từ 2026-09-09 (khối 📄 ở đầu mục 14). **Khoảng lệch thứ
hai vẫn còn.** Và **16 khối** của trang Phân tích *(đếm lại bằng máy 2026-09-17, sau khi thêm Tổng tài sản theo thời gian; mốc **15** là của cuối ngày 2026-09-16, sau khi thêm Lịch chi tiêu; con số **14** viết sáng cùng ngày là ảnh chụp trước đó — `_KhoiDuBao` xuất hiện hai lần trong mã nhưng là **một** khối người dùng thấy, còn `_KhoiVayNo` hai lần là **hai** khối thật)* thì không có
đường xuất tệp nào — `pdfBaoCao`/`csvBaoCao` chỉ có **một** chỗ gọi, ở
`report_preview_page.dart`. Chưa ai chốt làm gì với khoảng lệch **thứ hai** ấy.

> ✅ **Đã chốt 2026-09-18: KHÔNG lấp khoảng lệch ấy** — người dùng quyết định
> sau một lượt khảo sát bảy app thị trường (**0/7** app xuất cả màn phân tích ra
> một tệp; **6/7** chỉ xuất CSV thuần dữ liệu). Tệp cố ý gọn hơn màn hình: màn
> là nơi *tương tác*, tệp là nơi *chốt số*. Thay vào đó, trang Xuất báo cáo nhận
> **kỳ linh hoạt** dùng chung với trang Phân tích — xem khối 🗓️ đầu mục 14 và
> mục **3.33** `ANALYTICS_FEATURE.md`.
>
> ⚠️ Con số **16 khối** ở trên **đếm sai**. Đếm lại bằng máy 2026-09-18 từ chính
> `analytics_page.dart`: **14 tên khối**, trong đó `_KhoiDuBao` dựng hai lần mà
> chỉ **một** khối hiện, còn `_KhoiVayNo` dựng hai lần và hiện **cả hai** — tức
> **15** khối người dùng thấy. Cách đếm ấy đúng như chú thích trong ngoặc mô tả,
> nên chỗ sai nằm ở phép cộng chứ không ở luật đếm.

### 🔮 Dự báo dòng tiền 30 ngày tới (2026-09-16)

Mục **#4** của khảo sát app thị trường lần hai, người dùng chốt làm trước
Sankey. Khối mới trên trang Phân tích, **ngay sau thẻ tổng**: ba con số (số dư
hiện tại → **còn tiêu được** → *nếu tiêu đúng ngân sách*), cảnh báo ví thiếu,
biểu đồ **bậc thang** 31 điểm, danh sách cam kết thu gọn 5 dòng. Spec
`docs/superpowers/specs/2026-09-16-du-bao-dong-tien-design.md`, bàn giao ở mục
**3.27** `docs/ANALYTICS_FEATURE.md`, màn Stitch
`732587777370466098aa98d17bd0cbd4`.

⚠️ **Cố ý không có thu nhập trong dự báo** — app không lưu nó ở đâu cả, và suy
từ lịch sử là một con số **đoán** ngồi cạnh những con số thật. Chỉ chiếu thứ đã
có luật chạy thật: hoá đơn lặp, trích tự động, ngân sách.

Đi kèm một lượt **tách hàm thuần**: phép tính ngày của kỳ kế tiếp hoá đơn rời
`BillRepositoryImpl._nextPeriodOf` thành **`kyKeTiepCua(Bill)`** ở
`bill/domain/bill_ky_ke_tiep.dart`, và `_nextPeriodOf` gọi lại nó — dự báo chiếu
kỳ tương lai bằng đúng luật trả tiền. `watchKy` nay gộp **bảy** nguồn.

**Nghiệm thu máy ảo lật hai thứ mà 2633 ca test đều mù**, cả hai về trục biểu
đồ: trục từ 0 làm đường nằm phẳng (cam kết chỉ bằng 2,8% số dư), và bước lẻ làm
hai nhãn "13.6M" in đè nhau. Sửa bằng trục **co theo dữ liệu** + bước **tròn**
(bẫy **4.21**). `flutter test` **2643/2643**, `flutter analyze` **25 issue, 0
error**, schema giữ **v22**, **không thêm trường đồng bộ**.

### 🧹 Ví đã xoá mềm phình "số dư cuối kỳ" — G42 (2026-09-16, mở và đóng cùng ngày)

Lượt soát tài liệu của hạng mục trên lộ ra một lỗi **có sẵn**:
`analytics_repository_impl.dart` đọc ví bằng truy vấn thẳng **không lọc
`deletedAt`** — cố ý, vì bảng tra tên ví cần hàng đã xoá — rồi cộng `balance`
qua `viTinhVaoTong`, hàm khi ấy chỉ hỏi `includeInTotal` và trạng thái lưu trữ.
Nên **"số dư cuối kỳ" của khối Dòng tiền và thác nước cộng cả ví người dùng đã
xoá**; ca tái hiện đo **17.000.000 thay vì 10.000.000**.

⚠️ Hẹp hơn lần báo đầu: `bao_cao_repository_impl.dart:84` và
`wallet_repository_impl.dart:115` **không sai** — cả hai đi qua
`walletDao.getAll`, hàm ấy có lọc. Sửa bằng cách đưa vế `isDeleted` **vào chính
`viTinhVaoTong`** (mặc định `false`) chứ không vá ở chỗ gọi: tệp test của hàm ấy
mở đầu bằng *"tồn tại để không có bản thứ năm"*, và đây đúng là bản thứ năm.
`flutter test` **2643/2643**.

### 🏷️ Danh mục mặc định toàn cục mất tên — G41 (2026-09-15)

Máy ảo lộ ra khi nghiệm thu hạng mục khác: khối "Xu hướng 6 tháng" hiện **hai
chip cùng mang tên "Danh mục đã xoá"**. Truy vấn PostgreSQL cho ra **đúng hai**
danh mục bất thường ở tài khoản ấy — `Chi khác` và `Làm thêm`, cả hai
`Create_by = 1`, `is_default = true`, bị backend xoá mềm hôm 2026-09-07.

⚠️ **Gốc rễ:** `sync_engine` quy `is_default = true` thành **`idaccount = 0`**
(`sync_engine.dart:733`), nên hàng mặc định toàn cục **không mang mã tài khoản
nào** — nhưng cả hai repository tra danh mục đều lọc
`t.idaccount.equals(idaccount)`. Hai bản chép tay của cùng một truy vấn, cả hai
cùng thiếu vế `isDefault`.

Ảnh hưởng **rộng hơn cái chip**: cùng bảng tra ấy nuôi donut, cột thác nước và
danh sách danh mục cuối trang. Chip chỉ tình cờ là chỗ **hai** cái trùng nhau
nằm cạnh nhau nên mắt bắt được.

Nay có **một** định nghĩa `CategoryDao.getBangTraTen` / `watchBangTraTen` lọc
theo **cờ** `isDefault` — cùng khuôn `getNamesInUse` vốn đã đúng từ trước. Chi
tiết ở **G41** `docs/CLIENT_APP_KNOWN_GAPS.md`.

**Bài học:** hai bản chép tay của một truy vấn là chỗ lỗi sống lâu nhất — sửa
một bên thì bên kia vẫn sai, và chú thích đúng ở cả hai chỗ khiến không ai nghi.
Khi một luật có hai nơi thi hành, đưa nó về DAO **trước** rồi mới sửa.

### 💰 Tỉ lệ tiết kiệm (2026-09-15)

Một dòng trong thẻ "Số dư còn lại": *"Để dành 93% thu nhập"*. Mục **#1** của
lượt khảo sát app thị trường lần hai (mục **3.25** `ANALYTICS_FEATURE.md`);
người dùng chốt làm nó rồi tới **dự báo dòng tiền**, và **bỏ** hai mục thiếu
trường đối tác.

⚠️ **Mẫu số là THU NHẬP, không phải `tong.thu`** — cùng bẫy A8 #8 nhưng dễ vấp
hơn vì công thức sách vở là `(thu − chi)/thu`; lấy `tong.thu` thì tháng nào
người dùng vay tiền, tỉ lệ tiết kiệm lại **đẹp lên**. Phép tính thu nhập nay
tách thành **`thuNhapCua()`** và `dongTienTuDo()` gọi chính nó — một định nghĩa
duy nhất, có ca test canh hai chỗ trả cùng một con số.

**Trả nợ tính là TIÊU** (người dùng chốt) để con số khớp "Số dư còn lại" ngay
trên nó. Tính là *để dành* thì đúng hơn về kế toán, nhưng hai con số cạnh nhau
nói hai chuyện khác nhau thì người đọc chỉ kết luận được là một trong hai sai.

`null` khi thu nhập **không dương** thì **ẩn hẳn dòng** — chia cho mẫu số âm ra
tỉ lệ **đảo dấu**, và thu nhập âm xảy ra thật khi kỳ chỉ có tiền đi vay. Mục
**3.26** `ANALYTICS_FEATURE.md`.

**Không đụng schema** (v22 giữ nguyên), **không đụng đường đồng bộ**.
`flutter test` **2573/2573** · `flutter analyze` **25 issue, 0 error**.

### 💵 Dòng tiền tự do — A8 #8 (2026-09-15)

Một đường, sáu kỳ, đứng ngay sau khối "Xu hướng" và trả lời tiếp đúng câu hỏi
khối trên vừa đặt: *thu về bấy nhiêu thì thực sự còn lại bao nhiêu*. Chi tiết ở
mục **3.24** `docs/ANALYTICS_FEATURE.md`.

⚠️ **Hai chữ "thu nhập" KHÔNG phải `tong.thu`** — đây là chỗ đắt nhất, và nó chỉ
lộ ra khi hỏi trước lúc gõ. `TongThuChi.thu` là **mọi** khoản `type = 'thu'`,
nên nó đã gồm cả tiền **đi vay** và tiền **thu nợ**; cả hai đều không phải thu
nhập (một là tiền mượn, một là vốn cũ quay về). Lấy nguyên `tong.thu − traNo`
thì tháng nào người dùng vay tiền, đường này lại **vọt lên** — đúng tháng tình
hình của họ xấu đi, và không có exception nào báo. Luật đúng:

> **thu nhập = tổng thu − mọi khoản tiền VÀO thuộc nhóm Vay/nợ**
> (`diVay`, `thuNo`, **và** `khacVao`), rồi mới trừ `traNo`.

Đo trên máy ảo: thêm một khoản `Đi vay` **+5.000.000** (tiền vào) thì con số của
khối **không đổi** — vẫn `14.625.000đ`, không nhảy lên 19.625.000đ.

Phép tính nằm trọn ở hàm thuần `dongTienTuDo()` (`analytics/domain/dong_tien_tu_do.dart`),
ghép `chuoi` và `chuoiVayNo` **theo chỉ số** và **ném `ArgumentError`** khi hai
chuỗi lệch độ dài hoặc lệch kỳ. Không đụng repository — cả hai chuỗi đã có sẵn
trong `ThongKeKy` từ lát #4/#5.

⚠️ **Máy ảo bắt được một lỗi `flutter test` mù hẳn:** biểu đồ có phần âm nên
biên trên tính bằng `san + 3 * buoc`, sai số dấu phẩy động cho ra chừng `-1e-16`
ngay tại vị trí lẽ ra là 0, và `rutGon` in nhãn trục thành **`-0`**. Đã sửa tại
`rutGon` chứ không tại khối gọi nó — `-0` không bao giờ là nhãn đúng, và đây
đúng là luật `CurrencyFormatter.formatCoDau` đã có: **số 0 không mang dấu**. Bẫy
**4.20** `ANALYTICS_FEATURE.md`.

**Không đụng schema** (v22 giữ nguyên), **không đụng đường đồng bộ**.
`flutter test` **2559/2559** · `flutter analyze` **25 issue, 0 error**.

Với hạng mục này, bảng A8 còn đúng **một** ô trống — **#9** (biến động khoản
vay), và nó **không phải việc client**: nó cần dư nợ còn lại, thứ không bảng nào
ở hai đầu lưu. *(🛑 Ảnh chụp 2026-09-15: ô ấy **không còn là việc** — người dùng
chốt bỏ hẳn #9 và #11 ngày 2026-09-16, xem khối đầu mục 14.)*

### 🪜 Thác nước "Tiền đi đâu" — A8 #10 (2026-09-15)

Số dư đầu kỳ → cộng thu → trừ dần từng nhóm chi → số dư cuối kỳ. Chín cột, mỗi
nhóm chi là một khối **nổi** nối tiếp nhau như bậc thang. Chi tiết ở mục **3.23**
`docs/ANALYTICS_FEATURE.md`.

⚠️ **Người dùng từng chốt KHÔNG LÀM mục này rồi đổi ý cùng ngày**, và xin thêm
một đường trung bình. Mọi câu "🛑 P3 không làm" ở tài liệu cũ hơn — kể cả kế
hoạch `2026-09-15-ke-hoach.md` — là ảnh chụp của quyết định đầu.

**Phép cân là thứ đắt nhất:** `đầu kỳ + thu − Σ nhóm chi` phải ra đúng `cuối kỳ`,
lệch thì bậc thang hở một khe im lặng. Nên hàm thuần **không tự tính** `cuoiKy`
mà nhận con số khối "Dòng tiền trong kỳ" đang hiện, và nhóm chi mượn `topVaKhac`
— cùng hàm mà vòng tròn cơ cấu dùng.

⚠️ **Đường trung bình không thể là một đường ngang.** Dựng tới tầng vẽ mới lộ ra:
các khối chi nổi ở vùng 13,6–14,6 triệu còn mức trung bình là 174 nghìn, nên
đường ngang ở đó không cắt cột nào. Mắt so **độ cao** khối, đường ngang so **vị
trí**. Nay nó là một **vạch trên từng cột chi** — phần trong mức nhạt, phần vượt
đậm. Người dùng chốt cách này sau khi thấy vấn đề.

**Hai lỗi máy ảo bắt được:** chín nhãn trục hoành dính thành một chuỗi không đọc
được (ô nhãn 46dp rộng hơn 36dp mỗi cột — nay 32dp), và các khối chi chỉ chiếm
~7% chiều cao nên vạch hai sắc độ gần như vô hình. Lỗi thứ hai người dùng xem
ảnh rồi chốt **giữ nguyên**: chi thật sự chỉ bằng 7% số thu trong kỳ ấy, bóp méo
trục là vẽ sai sự thật.

Không đổi schema (vẫn **v22**), không thêm trường đồng bộ. Mức nền:
**2540/2540** test, analyze **25 issue / 0 error**.

### 💸 Hai biểu đồ cột vay/nợ — A8 #4 và #5 (2026-09-15)

"Cho vay & Thu nợ" và "Đi vay & Trả nợ", mỗi kỳ một **cặp cột chồng nhau**: cột
sau rộng và mờ, cột trước hẹp và đậm vẽ đè lên chính giữa. Chi tiết ở mục
**3.22** `docs/ANALYTICS_FEATURE.md`.

⚠️ **Câu "A8 #4/#5 bị chặn bởi mô hình dữ liệu" là quá chặt.** Đúng là không đầu
nào có bảng khoản vay, nhưng hai biểu đồ này chỉ vẽ **dòng tiền** — không cần dư
nợ gốc, lãi suất hay kỳ hạn. Riêng **#9** (biến động khoản vay) thì vẫn chặn
thật vì nó cần dư nợ còn lại.

⚠️ **Bài học đắt nhất của hạng mục: tên danh mục là QUAN HỆ nợ, chiều tiền mới
là VAI.** Màn Thêm giao dịch hiện ô "Chiều tiền" cho danh mục Vay/nợ, nên
`Cho vay` + tiền vào chính là *thu nợ*. Bản đầu coi đó là "tên nói dối" và xếp
vào `khac` — hậu quả là hai cột *Thu nợ* và *Trả nợ* **không bao giờ có số**,
im lặng, vì biểu đồ vẫn vẽ ra và vẫn có cột đỏ. **Chỉ chạy thật trên máy ảo mới
thấy** — `flutter test` không bắt được loại lỗi "hiểu sai mô hình dữ liệu của
chính app".

Điều ấy còn nặng hơn vì đo trên CSDL dev thì tài khoản thật **chỉ có hai** danh
mục Vay/nợ: `Cho vay` và `Đi vay` (13 bản mỗi tên); `Trả nợ` và `Thu nợ` đã bị
xoá mềm khi backend thu bộ khuôn về 13 UUID. Với luật đúng thì hai danh mục ấy
đủ ghi cả bốn vai.

**Màn Stitch:** `6e9007f7653749a893c88e3de535afa5` *"Thống kê - Biểu đồ Cho vay
& Đi vay"* — đo được ngày 2026-09-15; **không ghi ai tạo ra nó**, vì một màn mới
xuất hiện không chứng minh lượt gọi nào sinh ra nó. Hai khối và trục sáu kỳ khớp
bản thi công. ⚠️ Stitch vẽ thêm **hai thẻ tổng** (*số kỳ hạn*, *số kỳ còn lại*,
*% tiến độ*) mà bản thi công **cố ý bỏ**: cả ba đòi dư nợ gốc và kỳ hạn — đúng
thứ không có — nên vẽ chúng là bịa một con số người dùng sẽ tin. Ngược lại, khối
thứ ba *"Vay/nợ chưa xếp được vai"* thì Stitch không có mà bản thi công thêm
vào, vì giấu nó đi là im lặng đánh rơi tiền.

Không đổi schema (vẫn **v22**), không thêm trường đồng bộ. Mức nền:
**2511/2511** test, analyze **25 issue / 0 error**.

### 📈 Bốn khối mượn từ trang Báo cáo — P2 (2026-09-15)

Trang Phân tích nay có **dòng tiền · số liệu nhanh · phân bổ theo ví · top 5
khoản chi**, thứ tự khối chép đúng trang Xuất báo cáo. Chi tiết ở mục **3.21**
`docs/ANALYTICS_FEATURE.md`.

**Một định nghĩa, hai nơi dùng:** bốn phép tính vốn nằm inline trong
`dungBaoCao`, nay là hàm thuần ở `bao_cao_xuat.dart`. 44 ca test của trang Báo
cáo vẫn xanh **không sửa dòng nào** — bằng chứng lượt tách không đổi hành vi.
Repository Phân tích nhận **nguồn thứ tư là ví** (⚠️ đúng tại 2026-09-15; từ 2026-09-16 là **bảy** nguồn — xem khối dự báo dòng tiền ở đầu mục này).

⚠️ Hai điều đáng nhớ: khối dòng tiền **luôn** kèm câu "Suy ngược từ số dư hiện
tại của các ví" (app không lưu lịch sử số dư — mục 3.16), và `dongTienCua` phải
nhận **toàn bộ** giao dịch chứ không phải phần đã cắt theo kỳ, nếu không đầu kỳ
bằng cuối kỳ một cách im lặng.

Máy ảo bắt **ba** lỗi: `-0 đ` ở ví chỉ có thu (luật "số 0 không mang dấu" nay là
`CurrencyFormatter.formatCoDau` dùng chung); test của trang thiếu
`initializeDateFormatting` nên khối Top 5 làm **cả cây dừng dựng**; và ⚠️ **cột
số tiền không thẳng mép phải** — người dùng bắt được, đo trong widget test thấy
lệch **26,5px**. Gốc rễ: `Flexible` mang `flex: 1` mặc định nên được chia một
nửa chỗ trống như `Expanded`, nhưng để con giữ bề rộng tự nhiên, và
`MainAxisAlignment.start` đẩy phần thừa về **cuối hàng** — mỗi hàng thừa một
kiểu. Bẫy **4.19** `ANALYTICS_FEATURE.md`.

**Màn Stitch sinh sau:** `afe1c3fdee43464c90ddadc508eaa599` — *"Thống kê - 4 Thẻ
Dòng Tiền & Kế Toán"*. Bốn khối này thi công bằng cách dùng lại khuôn màn Xuất
báo cáo nên lúc làm chưa có thiết kế riêng; màn sinh sau để tài liệu thiết kế
khớp app. Nội dung khớp từng nhãn và từng con số. ⚠️ Nó mang `deviceType:
DESKTOP` dù lượt gọi truyền `MOBILE` — nhưng thân trang dựng trong
`max-w-[430px]` căn giữa, nên bố cục vẫn là một cột điện thoại; đừng suy ra
thiết kế đã đổi sang desktop. Lượt gọi cũng **trả về timeout** và mãi lượt kiểm
thứ ba mới thấy màn, đúng như lần sinh màn bộ chọn phạm vi.

Mức nền: **2488/2488** test, analyze **25 issue / 0 error**.

### 📐 Cột số tiền của trang Xem trước báo cáo — G40 (2026-09-15)

Trang **Xem trước báo cáo** mang đúng khuôn `Flexible` vừa gây lỗi ở trang Phân
tích. G40 mở ra để ghi mối nghi ấy mà **chưa sửa**, vì chưa nhìn tận mắt. Mở
trên máy ảo cùng ngày thì lỗi có thật, và **nặng hơn**: khối "Chi theo danh mục"
lệch **93px**, "Phân bổ theo ví" lệch 56px — trong khi trang Phân tích chỉ
26,5px.

⚠️ **Và không phải hai khối mà sáu.** G40 đoán theo tên hai khối người dùng báo;
đếm bằng máy thì tệp ấy có **sáu** chỗ cùng khuôn — thêm ngân sách, thu/chi theo
danh mục, danh sách giao dịch, và hàng "Thay đổi trong kỳ" của khối dòng tiền.
Khi một lỗ hổng mô tả lỗi bằng *tên khối*, hãy `grep` khuôn mã trước khi tin con
số nó ghi.

Sáu `Flexible` → `Expanded`. Đo lại trên máy ảo: **0px** lệch ở mọi khối.

⚠️ **Sáu ca test mới suýt vô dụng**: viết ở khổ 411dp thì ba ca xanh ngay từ đầu
dù máy ảo đo được 93px — font "Ahem" rộng gấp đôi nên mọi chuỗi đều tràn suất và
`FittedBox` co chúng lại lấp đầy, che đúng thứ cần đo. Phải chạy ở khổ **gấp
đôi** (822dp). Chi tiết ở bẫy **4.19** `ANALYTICS_FEATURE.md`.

Mức nền: **2517/2517** test, analyze **25 issue / 0 error**.

### 🗓️ Phạm vi thời gian cho trang Phân tích — P1 (2026-09-15)

Trang Phân tích thôi khoá cứng theo tháng: nay xem được theo **tuần · tháng ·
quý · năm · khoảng tuỳ chọn**. Spec
`docs/superpowers/specs/2026-09-15-pham-vi-thoi-gian-trang-phan-tich-design.md`
(gitignore), chi tiết ở mục **3.20** `docs/ANALYTICS_FEATURE.md`.

**`Ky` là định nghĩa duy nhất** của một kỳ (`analytics/domain/pham_vi_ky.dart`):
một `DonViKy` cộng biên `[from, to)`. Nó thay `(nam, thang)` ở `ThongKeKy`,
`watchKy`, `AnalyticsLoading`, `chonKy`. Làm **hai bước**: bước 1 đổi mô hình mà
hành vi không đổi (bộ chọn vẫn chỉ dựng `Ky.thang`) — app chạy y hệt là bằng
chứng mô hình đúng; bước 2 mở bộ chọn và cho chuỗi xu hướng đi theo đơn vị.

⚠️ **Một kết luận sai đã phải rút lại ngay trong ngày:** kế hoạch và bản đầu
của các tài liệu này ghi rằng P1 "gỡ chặn cho thông báo Tổng kết tuần". **Sai**
— thông báo ấy làm xong từ **2026-09-09** (mục 5d `NOTIFICATION_FEATURE.md`), và
điều kiện của nó đóng bằng phạm vi tuỳ chỉnh của trang Xuất báo cáo. Nguồn của
nhầm lẫn: ghi chú 2026-09-08 trong spec Tổng kết tuần nói "còn thiếu màn phạm vi
tuần" — đúng **vào ngày ấy**, và khối "✅ Đã đủ" nằm ngay dưới nó. Bài học cũ,
vấp lại: `grep` một cụm chữ rồi kết luận, thay vì đọc trọn mục.

⚠️ **Nhãn quý sửa lại cùng ngày, sau khi người dùng báo ô header cụt.** Bản đầu
để `nhanNgan` của quý là `Quý 3 2026`, làm nhãn ô header `"Quý này (Quý 3 2026)"`
dài hơn `"Tháng này (T9 2026)"` **đúng một ký tự** — và máy ảo cắt nó thành
`"Quý này (Quý 3 20…"`, mất cả con số năm. Nay là **`Q3 2026`**, trùng cách viết
mà trục biểu đồ đã dùng (`Q3/26`), nên không đẻ ra quy ước thứ hai.

Bất biến rút ra, nay có ca test canh: **không nhãn nào được dài hơn nhãn tháng**
— đó là chuỗi duy nhất đã được máy thật chứng minh là vừa. Phép canh đặt ở
**tầng thuần** (so độ dài chuỗi) chứ không phải widget test đo bề rộng: font
"Ahem" của bộ test rộng gấp đôi ngoài đời (bẫy 4.4 `ANALYTICS_FEATURE.md`) nên ở
411dp chuỗi nào cũng cụt, và một ca đo bề rộng sẽ đỏ cả với nhãn tháng vốn không
sao.

**Hệ quả thật của P1:** trang Phân tích tự nó có phạm vi tuần, và mọi khối thống
kê thêm về sau không còn thừa hưởng giới hạn "chỉ tháng". Và ⚠️ **ngân sách chỉ
gắn vào dòng danh mục khi đơn vị là Tháng**:
`BudgetView.spent` đếm theo kỳ của *chính ngân sách ấy*, nên vẽ thanh "% ngân
sách" cạnh số liệu một tuần là đặt hai kỳ khác nhau lên cùng một tỉ lệ — sai im
lặng, con số trông rất hợp lý.

**Hai lỗi bắt được trong lúc làm, cả hai đều thuộc họ đã biết:** widget test bắt
nhãn trục quý `Q3` xuất hiện **hai lần** trên cùng một trục (sáu quý trải qua
một năm rưỡi → nhãn thành `Q3/26`, cùng họ G39); và nghiệm thu máy ảo bắt sheet
**co theo số dòng** nên hàng chip trượt xuống dưới ngón tay khi đổi đơn vị, cú
chạm kế rơi vào lớp phủ (→ chiều cao cố định, có ca test canh).

Không đổi schema (vẫn **v22**), không thêm trường đồng bộ.

**Thiết kế Stitch của bộ chọn:** màn `83993fc9f5de4c5f8fba6940480c164a` —
*"Thống kê - Chọn phạm vi thời gian"*, do lượt gọi `generate_screen_from_text`
của phiên này tạo (người dùng xác nhận 2026-09-15). ⚠️ Lượt gọi ấy **trả về
timeout** và `list_screens` ngay sau đó không thấy gì; hơn một tiếng sau màn mới
hiện. Timeout **không phải** thất bại — đừng gọi lại.

### 📊 A8 #3, #7 — cơ cấu theo danh mục và xu hướng nhiều danh mục (2026-09-14)

Hai mục của bảng **A8. Analytics & Reporting** (`Project.md:1028-1041`) đã đóng.
Spec `docs/superpowers/specs/2026-09-14-thong-ke-phan-loai-va-xu-huong-danh-muc-design.md`
(đọc kèm banner đầu tệp), chi tiết ở mục **3.19** `docs/ANALYTICS_FEATURE.md`.

⚠️ Đây là **bản thi công lần hai**. Bản đầu đóng **ba** mục (#2, #3, #7) và đã
bị revert cùng ngày — người dùng xem xong rồi chốt lại phạm vi: **bỏ #2**, và
đổi hình dạng cả #3 lẫn #7. Tài liệu cũ hơn bản này nói về "mức gốc ba lát",
"drill-down", "dropdown chọn một danh mục" là tả **bản đầu**.

- **#3** — khối **"Cơ cấu theo danh mục"**: ba chip *Chi · Thu · Vay-nợ* chọn
  nhóm, vòng tròn vẽ danh mục **bên trong** nhóm ấy. Nhóm Chi **mở sẵn**. Chip
  chỉ hiện cho nhóm có phát sinh, thứ tự cố định theo `kCategoryClassifies`
  (không theo số tiền — chip đổi chỗ khi số đổi là người dùng bấm nhầm nhóm).
  Danh sách danh mục cuối trang **đi theo** cùng chip.
- **#7** — khối "Xu hướng …" có **hàng chip cuộn ngang, chọn nhiều**: tập
  rỗng là hai đường Thu/Chi, bật tới **5** danh mục thì mỗi cái một đường mang
  màu và tên của nó. Đủ trần thì chip chưa bật bị **khoá nhìn thấy được**; chốt
  thật ở cubit, khoá ở widget chỉ để nhìn thấy.

**Luật phân loại có một định nghĩa duy nhất** ở
`analytics/domain/phan_loai_dong_tien.dart`. ⚠️ App có **hai** thứ dễ nhầm là
một: `transaction.type` là **chiều tiền**, `category.classify` là **phân loại
danh mục** — khoản *Trả nợ* mang `type='chi'` nhưng `classify='vay_no'`. Luật
lấy `classify`, **rơi về `type`** khi không tra được danh mục (đo 2026-09-10:
server có 17 hàng giao dịch trống danh mục thật). `theoPhanLoai()` **giữ lại**
dù vòng tròn ba lát đã bỏ — nó là nguồn duy nhất cho biết nhóm nào có phát
sinh, tức khối hiện chip nào.

⚠️ **Hệ quả cố ý:** nhóm "Chi" **không bằng** "Tổng chi" ở thẻ đầu trang — ba
nhóm phải rời nhau thì tỷ trọng mới có nghĩa. Đừng "sửa" cho khớp.

> ⚠️ **Đính chính 2026-09-15:** đoạn dưới là kết luận của ngày 2026-09-14, và
> nay **chỉ còn đúng với #9**. **#4 và #5 KHÔNG bị chặn** — chúng chỉ vẽ *dòng
> tiền*, và đã làm xong (mục **3.22** `ANALYTICS_FEATURE.md`). **#8** (dòng tiền
> tự do) cũng **không bị chặn**, và nay **đã làm xong** — mục **3.24**, cùng
> ngày. ⚠️ Công thức thì **không** phải `Σ thu − Σ traNo` như dòng này từng
> ghi: `tong.thu` đã gồm cả tiền **đi vay** và tiền **thu nợ**, và cả hai đều
> không phải thu nhập — đọc mục 3.24 trước khi động vào. Chỉ **#9** chặn thật,
> vì nó cần **dư nợ còn lại** và không bảng nào ở hai đầu lưu con số ấy.
>
> Bài học: một mục bị xếp "chặn bởi mô hình dữ liệu" thì phải hỏi **chặn vì
> thiếu con số nào**, chứ đừng gộp cả nhóm theo cái tên "vay/nợ". Câu gộp ấy đã
> giữ #4, #5 nằm ngoài phạm vi suốt một ngày, và suýt giữ cả #8.

**Bốn mục A8 còn lại bị chặn bởi mô hình dữ liệu, không phải bởi biểu đồ.** Đếm
bằng máy 2026-09-14: client có **9** bảng Drift, backend có **13** model
Prisma, **không đầu nào có bảng khoản vay**. Không có dư nợ gốc, lãi suất, kỳ
hạn, hay liên kết giữa một khoản vay với các lần trả nợ. Mục **#4** (Cho vay +
Thu nợ), **#5** (Đi vay + Trả nợ), **#8** (dòng tiền tự do), **#9** (biến động
khoản vay + lãi vay) đều cần ít nhất một trong những thứ ấy → cần mô hình mới ở
**cả hai đầu**, tức phải xin backend. Mục **#10** (thác nước) và **#11**
(Sankey) làm được với thu/chi nhưng để đợt sau. *(Đính chính 2026-09-15: #4, #5
và #8 **không** cần mô hình mới — xem khối "Bốn mục A8 bị chặn" ở trên; và
**#10 và #8 đều đã làm xong** cùng ngày — mục 3.23 và 3.24. 🛑 **Đính chính
2026-09-16: #9 và #11 bỏ hẳn** — người dùng chốt; bảng A8 không còn ô nào là
việc, xem khối đầu mục 14.)*

**Không đụng schema** (v22 giữ nguyên), **không đụng đường đồng bộ**.
`flutter test` **2409/2409** · `flutter analyze` **25 issue, 0 error**.
**Đã nghiệm thu trên `emulator-5554`** (411dp) đủ bảy điểm — mục 3.19
`ANALYTICS_FEATURE.md` liệt kê từng điểm. ✅ Lượt ấy tìm ra **G39** — nhãn trục tung
của khối Xu hướng in đè lên nhau ở một số dải giá trị, lỗi **có sẵn từ lát 2b**
— và **đã sửa cùng ngày** (`maxY = buoc * 3`, có ca test tái hiện). ✅ **Stitch đã có màn khớp**: `c8567243…` (xem ngay dưới).

**Thiết kế Stitch:** màn `c8567243df704268ac766aa60ffa5036` — *"Thống kê - Cơ
cấu danh mục & Xu hướng 6 tháng"*, khớp bản lần hai đang chạy.

⚠️ **Hai** màn cũ vẫn còn trong dự án Stitch và đều đã lỗi thời:
`c2a2b615…` *"Thống kê - Xu hướng 6 tháng & Cơ cấu dòng tiền"* (tả A8 #2 đã bỏ —
mức gốc ba lát, drill-down, dropdown chọn một) và `a228fa69…` *"FlowMoney
Analytics Dashboard"*. ⚠️ **`edit_screens` không nghiệm thu được bằng API.** Lượt gọi ngày
2026-09-14 trả về thành công kèm `dom_operations` khẳng định đã sửa tại chỗ,
nhưng **không đổi gì cả**; màn khớp bản lần hai là do **người dùng** bảo Stitch
tạo. Nên: kết quả trả về không chứng minh công cụ đã làm gì, và một màn mới xuất
hiện cũng không chứng minh lời gọi của mình tạo ra nó. Hỏi người dùng.

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
- SQLite schema (Drift) aligned với backend schema — `schemaVersion` nay là **21** (2026-09-12 tối, cột `Bills.periodEnd` — ân hạn hoá đơn; dòng này từng đứng ở 12 rất lâu; con số đúng luôn nằm ở `AppDatabase.schemaVersion`, đừng chép từ đây)
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
- **Hai loại giao dịch (Giao dịch / Chuyển khoản) + tab Vay/nợ ở bảng chọn danh mục** (2026-09-05; ⚠️ thanh đầu màn trở lại **ba đoạn Chi tiêu · Thu nhập · Chuyển khoản** ngày 2026-09-19 theo Stitch — nhưng chỉ là lối vào, luật "chiều tiền suy từ danh mục" dưới đây **giữ nguyên**, xem mục C1–C5 đầu mục 14) — chiều tiền suy từ `classify` của danh mục thay vì từ segment; danh mục vay/nợ có hàng "Chiều tiền" trên form, gợi sẵn theo tên (`suggestDebtDirection`). SQLite **vẫn** lưu `type = chi/thu/transfer` nên hợp đồng đồng bộ, DAO và thống kê không đổi; vay/nợ tính vào tổng thu/chi như thu/chi thường (quyết định có chủ ý, tách ra để dành cho Analytics). Danh sách classify gom về `core/category/category_classify.dart` thay cho 5 bản chép tay. Kèm sửa 11.11
- **Sổ giao dịch chặn vuốt xoá khoản của mục tiêu và hoá đơn** (2026-09-06) — nguyên tắc: chỉ xoá được ở sổ khi giao dịch là nguồn sự thật duy nhất của hệ quả nó gây ra; khoản nạp/rút mục tiêu còn `current_amount`, khoản trả hoá đơn còn cờ Payed + kỳ kế tiếp, xoá rời chỉ hoàn ví (đã thấy tiến độ MuaXe đứng nguyên sau khi xoá hai khoản nạp). Nhận diện ở `features/transaction/domain/transaction_owner.dart` (`goalId` cục bộ, hoặc tiền tố ghi chú vì hàng kéo từ server không có `goalId`; kể cả dạng cũ "Tích lũy nhận từ …"); hàng tách thành `TransactionListRow` với `confirmDismiss` + SnackBar chỉ đường. Hoá đơn chưa có luồng hoàn tác thanh toán — muốn cho xoá thì phải làm luồng ấy trước
- **Sổ giao dịch hiện danh mục + tên ví** (2026-09-06) — theo bố cục Stitch màn Home: tiêu đề = ghi chú (không có thì tên danh mục), dòng phụ "Danh mục • Ví" hoặc "Ví nguồn → Ví đích" với khoản chuyển, icon/màu của danh mục. Trước đó dòng phụ in thẳng UUID ví và không có danh mục ở đâu. Nội dung dòng tính ở hàm thuần `buildTransactionRowContent()` (`transaction_row_content.dart`), tên tra qua `TransactionLookup` dựng từ `walletDao.watchAll` + `categoryDao.watchAll`. **Phát hiện kèm:** seed backend lưu tên icon ngữ nghĩa (`food`, `bill`, `lend`…) còn ba mapper client chỉ hiểu tên Material → danh mục mặc định kéo về toàn rơi về icon mặc định; nay gom về **một** mapper `core/category/category_visuals.dart` hiểu cả hai bộ tên, `budget_visuals` và `category_page` uỷ quyền về đó (`category_add_page` còn bản riêng cho bộ chọn icon, chưa gộp)
- **Sổ giao dịch: chi tiết + sửa + lọc/tìm** (2026-09-06). Bấm dòng → `TransactionDetailSheet` (đọc đủ; Sửa/Xoá chỉ với giao dịch thường, khoản mục tiêu/hoá đơn chỉ đọc theo cùng quy tắc `transactionOwnerOf`). Sửa dùng lại `AddTransactionPage` với `initial: EditTransactionArgs` qua `extra` của route `/add` (cùng `id`, `UpdateTransactionEvent`); `TransactionRepositoryImpl.updateTransaction` = hoàn trọn hệ quả cũ rồi áp trọn hệ quả mới lên ví (một đường `_applyBalances(sign)` dùng chung cho thêm/xoá/sửa), ghi đè hàng và đặt lại `pending` + `updatedAt` (LWW server). Lọc: `TransactionFilter` + `applyTransactionFilter` thuần Dart trên danh sách **của kỳ đang xem** (loại, ví — khoản chuyển khớp cả nguồn lẫn đích —, danh mục, tìm ghi chú bỏ dấu, và **khoảng số tiền** từ 2026-09-21); `TransactionFilterBar` chỉ phát filter, trang giữ trạng thái; thẻ tổng tính trên tập đã lọc. ⚠️ Câu này từng ghi *"danh sách tháng của bloc"* — đúng tới 2026-09-21, khi trang bỏ phép buộc-theo-tháng và nguồn dữ liệu thành `watchKhoang(from, to)` với biên `[from, to)`; xem khối đầu mục 14. Trang chủ "Giao dịch gần đây" dùng chung `buildTransactionRowContent`
- **Ngân sách: nhịp chi, trang chi tiết riêng, lịch sử sáu kỳ** (2026-09-06, `0467ffd`). Thẻ trong danh sách thêm dòng "Nên chi X/ngày · còn N ngày" (`domain/budget_pace.dart`: ngày còn lại làm tròn **lên**, tối thiểu 1 khi còn trong kỳ; nhịp chi so với thời gian đã trôi, biên ±5 điểm phần trăm; mọi mốc lấy từ `currentPeriod` nên tháng ngắn và năm nhuận đúng theo). Trang **`/budget/detail/:id`** thay bottom sheet cũ: nhịp chi, sáu cột lịch sử (`domain/budget_history.dart` — `recentPeriods` đi lại đúng phép cắt của `currentPeriod`, kỳ cuối trùng kỳ hiện tại, các kỳ liền nhau không hở), và các khoản chi của kỳ dùng lại `buildTransactionRowContent` + `TransactionDetailSheet` của sổ (Sửa/Xoá đi qua `TransactionBloc`, **không** có đường xoá thứ hai). Đường dẫn là `/budget/detail/` chứ không phải `/budget/:id` vì `/budget/rules` sẽ bị tham số nuốt; đặt **ngoài** shell như trang cấu hình. Kèm sửa lỗi biên: `getExpenses` cắt `date < to` (biên **mở**) dù DAO lấy `<= to`, vì bộ chọn ngày trả 00:00 và khoản ghi ngày đầu kỳ sau từng bị đếm vào cả kỳ trước — đừng "tối ưu" bằng cách gọi DAO trực tiếp
- **Thẻ ngân sách trang chủ đọc dữ liệu thật** (2026-09-06, `13bbd9f`) — trước là placeholder cứng "Ăn uống · Chưa thiết lập". Theo Stitch màn Home: **một** ngân sách, đã dùng / hạn mức, phần trăm, thanh bốn màu, dòng nên chi/ngày. `pickHomeBudget` (hàm thuần, test riêng) chọn ngân sách **đang chạy** có **tỉ lệ** đã chi cao nhất — so tỉ lệ chứ không so số tiền, và bỏ qua ngân sách hết hạn. Bấm thẻ `go('/budget')` vì cùng shell. `home_budget_card_test.dart` là test **đầu tiên** của feature `home`, dựng ở 411dp và bắt tràn bằng `takeException`
- **Lựa chọn "Chặn" (`OverSpending = Stop`) có tác dụng thật** (2026-09-06, `91bde24`) — tồn tại trên form từ 03/09 nhưng không nơi nào đọc. Người dùng chốt: "Chặn" = **hỏi xác nhận** trước khi ghi khoản làm vượt, **không bao giờ từ chối ghi** (tiền đã tiêu thật, không ghi thì ví lệch); "Cảnh báo" = ghi luôn rồi báo. `domain/budget_impact.dart` là nơi **duy nhất** đọc `OverSpending`; ở chế độ sửa trừ số cũ ra trước, không thì báo vượt oan; khoản ngoài kỳ hiện tại không tính. `_saveTransaction` của form thêm giao dịch nay **async** (tra `budgetLookup` tiêm được, DI chưa có hoặc tra hỏng thì vẫn ghi) — widget test phải `pumpAndSettle`. Hộp thoại xác nhận nêu số vượt; snackbar sau lưu **không có con số** (banner tối giản)
- **Gợi ý hạn mức** (2026-09-06, `f746a32`; **đổi cửa sổ 2026-09-21**) — form hiện "Bạn chi trung bình X mỗi tháng" dưới ô hạn mức sau khi chọn danh mục, nút "Dùng số này" điền số thô. `BudgetRepository.suggestAmount`: mức chi trung bình **mỗi tháng** của danh mục, suy từ `cuaSoNhinLai` (cửa sổ **cuộn** ≤ 90 ngày, ngắn lại theo tuổi dữ liệu), làm tròn lên bội 10.000; `null` khi cửa sổ không có khoản chi nào **hoặc** tài khoản trẻ hơn 14 ngày — và `null` thì **không hiện gì** vì "trung bình 0 đ" tệ hơn không gợi ý. 🛑 **Bản đầu cắt ba tháng dương lịch đã đóng, và nó CHƯA TỪNG hiện một con số nào trên dữ liệu thật**: giao dịch sớm nhất trong toàn bộ CSDL là 02/09/2026, nên cửa sổ ấy rỗng trên mọi tài khoản suốt từ 2026-09-06. ⚠️ Nhãn cũng đổi theo — nó từng nói *"3 tháng gần nhất"*, câu ấy **đúng trước** lượt sửa và thành lời nói dối ngay sau, và **không ca test nào canh** (chỉ có một ca canh vắng mặt); máy ảo bắt được trên một tài khoản 20 ngày tuổi. Nay nhãn không nêu cửa sổ cố định nào — và từ Task 6 nó còn **nói ra số ngày thật** khi cửa sổ ngắn hơn 90 ngày (*"…mỗi tháng, suy từ 19 ngày gần nhất"*), vì thẻ "Chưa đặt ngân sách" đã hứa đúng câu ấy; cả hai vế đều có ca canh. Form nhận `suggestFor` là callback (form không đọc cubit), có số thứ tự `_generation` chống hai lần tra chồng nhau; `BudgetCubit.suggestAmount` không đổi state để lỗi nhỏ không thay cả trang bằng `BudgetError`
- **Hai giới hạn có chủ ý của đợt ngân sách 06/09:** (1) **Lịch sử kỳ dùng hạn mức HIỆN TẠI cho cả kỳ cũ** (`BudgetPeriodSummary.amount`) — không có nơi nào lưu hạn mức cũ, muốn đúng phải có bảng lịch sử hạn mức ở backend; đổi hạn mức là các cột cũ đổi vạch theo. (2) **Stitch chưa có** màn chi tiết ngân sách, và màn Home lẫn màn danh sách cũng chưa vẽ dòng "nên chi/ngày" — người dùng chọn làm theo design system trước, vẽ Stitch sau; không tạo màn Stitch bằng MCP
- **Hoá đơn: gỡ lời hứa suông, bốn nhãn trạng thái đúng nghĩa, hai tab** (2026-09-06). Form Thêm có công tắc "Tự động tạo giao dịch — Thanh toán khi đến hạn" **bật sẵn** gắn vào một biến không lưu ở đâu: không cột, không bộ chạy nền — đã gỡ hẳn (làm thật là quyết định sản phẩm, không phải việc dọn lỗi). Danh sách sai bốn chỗ cùng lúc: hoá đơn **đã quá hạn** mang nhãn "SẮP ĐẾN HẠN" với vạch màu **xanh lá của khoản thu**, hoá đơn thật sự sắp đến hạn không có nhãn nào, thanh tiến độ là hằng số `0.66`, và tổng tiền gộp cả kỳ tháng sau (máy thật hiện 183.000 đ trong khi tháng này chỉ nợ 60.000 đ). Bốn trạng thái suy ở `domain/bill_status.dart`, ngưỡng "sắp đến hạn" **dùng lại `billLeadDays`** của bộ luật thông báo (⚠️ từ 2026-09-12 là **năm** — thêm `skipped`; xem khối "Bỏ qua kỳ hoá đơn" bên dưới). Thêm hai tab (mỗi kỳ là một hàng mới nên lịch sử đã trả trôi lẫn vào giữa hoá đơn đang chờ), dòng "Danh mục • Ví" kèm icon danh mục, và ví của hoá đơn được gợi sẵn khi trả
- **Hoá đơn: `payStatus = 'Overdue'` gỡ được** (2026-09-06). `markOverdue` chỉ có chiều Pending → Overdue; form Sửa đẩy hạn ra tương lai thì cờ ở lại vĩnh viễn, và cột này **có đi đồng bộ** nên Admin-web đọc sai — dữ liệu thật 06/09 có hai hoá đơn mang 'Overdue' với hạn ở tương lai. Nay đi cả hai chiều, mỗi chiều vẫn có điều kiện trạng thái để không tạo vòng lặp đẩy
- **Hoá đơn: trả theo số tiền thật của kỳ, và hoàn tác được** (2026-09-06, **schema v16**). Bảng thanh toán hỏi số tiền (điền sẵn số của hoá đơn) rồi mới chọn ví; giao dịch, ví và bản ghi hoá đơn cùng nhận số đó, kỳ kế tiếp kế thừa nó. `undoPayment` hoàn trọn ba hệ quả trong một transaction: trả tiền về **đúng ví đã trừ với đúng số đã trừ** (đọc từ giao dịch, không từ hoá đơn), xoá mềm khoản chi, gỡ kỳ kế tiếp. Hai cột **cục bộ** mới `transactions.billId` và `bills.generatedFromBillId` là hai đầu của sợi dây ấy — không suy dữ liệu cũ từ tiền tố ghi chú, vì đoán trượt nghĩa là hoàn tiền bằng một khoản chi **khác** của người dùng; khoản trả ghi bằng bản cũ bị từ chối kèm lý do rõ
- **Ba trang hoá đơn có widget test lần đầu** (2026-09-06). Tầng dưới có chín tệp test còn ba trang thì không có gì — đó là lý do công tắc giả và bốn nhãn sai sống lâu như vậy. Dựng ở 411dp làm lộ ngay **sáu chỗ tràn bố cục** chưa ai từng thấy (bốn ở form Thêm, hai ở danh sách), vì bộ test và skill `chay-app` đều chạy Chrome 1280px
- **Một thanh chọn chu kỳ dùng chung** (2026-09-06, `4127f39` + `3564948`). `SegmentedChoice<T>` ở `shared/widgets/segmented_choice.dart` thay ba bộ chọn viết tay: form Thêm **và** form Sửa hoá đơn (form Sửa bỏ `DropdownButtonFormField`), form ngân sách (từng là `Wrap` hai ô mỗi hàng; nay năm ô một hàng, "Ngày cụ thể" = `null` có key `budget-cycle-null`), hai thanh của form mục tiêu (giữ màu thu). Hình dạng theo Stitch "Thêm Mục Tiêu Tiết Kiệm"; Stitch ngân sách vẽ ô viền rời và Stitch "Chỉnh sửa Hóa đơn" vẽ chip tròn — cả hai được thay bằng thanh phân đoạn để đồng nhất, **có chủ ý**. Lỗi "`Container` có `alignment` mà không có kích thước thì giãn hết ràng buộc" nay chỉ còn một chỗ để tái phát, có test canh ở widget. Đã xem cả bốn form ở 411dp trên máy ảo
- **Dữ liệu: hai hoá đơn tài khoản 10 trỏ danh mục đã xoá mềm** — đã sửa 2026-09-06 **qua form Sửa trên máy ảo** (trỏ lại "Chi khác" mặc định) để đi đúng đường đồng bộ, không UPDATE thẳng PostgreSQL; truy vấn đọc xác nhận cả hai trỏ vào hàng còn sống
- **Hoá đơn: tự động thanh toán** (2026-09-06 chiều, **schema v17**). Người dùng chọn bản đầy đủ thay vì nút "Trả ngay"; ba lựa chọn đã chốt: trừ từ **ví thanh toán của hoá đơn** (một cột cục bộ `bills.autoPayEnabled`, không cần cột ví hay "lần chạy cuối" — mỗi kỳ là một hàng, cờ đã trả là chốt chống trả hai lần), mở app muộn thì **trả bù trần 3 kỳ/hoá đơn/lượt**, trả **bất kỳ lúc nào trong ngày đến hạn**. `BillAutoPayRunner` chạy trong `NotificationScanner.scan()` sau `markOverdue` và trước khi nạp hoá đơn, đi qua `payBill` hiện có với `occurredAt = dueDate` (khoản bù mang ngày của kỳ) nên hoàn tác vẫn chạy. Hai loại thông báo `billAutoPaid`/`billAutoPayFailed` nhóm `bill`, khoá theo kỳ, `createdAt` = lúc quét. Công tắc **tắt sẵn** trên cả hai form. ⚠️ Dòng phụ dưới nó từng là "chỉ nên bật trên một thiết bị", vì cột khi ấy **cục bộ** nên hai máy cùng bật, cùng offline là **hai** khoản chi. ✅ **Hết từ 2026-09-13 (bước 12):** `auto_pay` đi qua đồng bộ nên công tắc là thuộc tính của *hoá đơn*, và rủi ro hai khoản chi đóng bằng ba mảnh — `auto_pay` đồng bộ + `chanTraHaiLan` phía server + `BillPaymentConflictResolver` phía client; xem khối "Bước 12" cuối mục này. Đã kiểm trên máy ảo: hoá đơn hạn hôm nay được trả ngay ở lượt quét sau khi lưu, thông báo và PostgreSQL khớp. Spec: `docs/superpowers/specs/2026-09-06-bill-auto-pay-design.md` (thư mục bị gitignore, đã `git add -f`)
- **Hoá đơn: ngày trả, ghi chú lần trả, trang chi tiết** (2026-09-06 tối, `77a70bc`…). Năm việc chốt sau khi so với Money Lover/Wallet, làm theo thứ tự: (1) tab "Đã thanh toán" (⚠️ đổi tên thành **"Lịch sử"** ngày 2026-09-12) ghi "Trả dd/MM/yyyy" từ khoản chi (`BillLoaded.payments`, không đoán khi thiếu) và chạm mở `TransactionDetailSheet`; (2) bảng thanh toán hỏi **ngày trả** (chặn tương lai) → `payBill(occurredAt:)`; (3) **trang chi tiết `/bills/:id`** với "Lịch sử các kỳ" theo `generatedFromBillId` (`chuoiKyCua`), nút trả/hoàn tác/sửa/xoá, mở từ dòng chưa trả; (4) "bỏ qua kỳ này" **chưa làm** lúc ấy, viết việc E xin backend nhận `Pay_status = 'Skipped'` (✅ 2026-09-11 backend nhận; ✅ **client xong 2026-09-12** — khối "Bỏ qua kỳ hoá đơn" bên dưới); (5) ghi chú riêng mỗi lần trả nối SAU tiền tố `kGhiChuTraHoaDon`. Nhãn/màu trạng thái và ba luồng thao tác tách ra `widgets/bill_status_visuals.dart`, `widgets/bill_actions.dart`. **Bẫy đắt nhất:** `watchBills().asyncMap(...)` dưới FakeAsync nuốt `done` → `bloc.close()` treo → widget test đứng 10 phút/test; đã thay bằng `emit.onEach` + đọc riêng (mục 6.6 `BILL_DOCUMENTATION.md`)
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
  > ⚠️ **Font PDF phải nhúng.** Font mặc định của gói `pdf` là Helvetica — không có glyph tiếng Việt và **mất dấu im lặng** (tệp vẫn mở được, chỉ là "Ăn uống" thành ô trống). Nay nhúng `Roboto` (Apache 2.0) ở `assets/fonts/`, **thư mục assets đầu tiên của dự án**. Test canh bằng cách cấm chuỗi "Helvetica" xuất hiện trong tệp sinh ra. ⚠️ **Đính chính 2026-09-17:** nhúng đúng font vẫn **chưa đủ** — bản Roboto ấy không có khối Mũi tên lẫn khối Hình học, nên `→` ở chính dòng dòng tiền của mục này bị gói `pdf` bỏ đi **im lặng** suốt từ hôm ấy tới 2026-09-17. Nay là `»`, và có ca test quét glyph canh; xem mục **3.31 `docs/ANALYTICS_FEATURE.md`**.
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
  > *(⚠️ "ba ràng buộc của xoá" là ảnh chụp 2026-09-10. Nay là **bốn** — G45 thêm chốt cho hoá đơn ngày 2026-09-18. Và chốt "không lưu trữ ví mặc định" cùng ngày có thêm **chiều ngược lại**: không đặt ví đã lưu trữ làm mặc định.)*
  > **Hai chốt chặn, khác hẳn ba ràng buộc của xoá:** không lưu trữ ví **mặc định** (nó được chọn sẵn mỗi lần ghi giao dịch), và không lưu trữ **ví hoạt động cuối cùng**. Hai chốt **độc lập** nhau — một tài khoản có thể không có ví nào mang cờ mặc định, vì trạng thái ấy đến được từ server. Cả hai chỉ canh chiều lưu trữ. Ví còn số dư, đã có giao dịch, hay đang gắn mục tiêu thì **vẫn lưu trữ được**; hộp thoại xác nhận nói thẳng rằng trả hoá đơn và nạp mục tiêu tự động sẽ dừng.
  > ✅ **CẬP NHẬT 2026-09-14 — `status` nay ĐI QUA ĐỒNG BỘ hai chiều** (G28 đóng, schema **v22**, payload ví **13 trường**; khối "Lưu trữ ví qua đồng bộ" ở dưới). Hai dòng ⚠️ ngay sau đây ghi trạng thái **khi tính năng được làm**, giữ vì chúng giải thích vì sao mã có hình dạng hôm nay.
  >
  > ⚠️ **`status` là cột CỤC BỘ, không đi theo chiều nào của đồng bộ** — nay là cột cục bộ **duy nhất** còn lại của nhóm này — `bills.anchorDay` mở đường đồng bộ ngày 2026-09-12, `bills.autoPayEnabled` ngày 2026-09-13. Lý do là một con số đo thẳng trên PostgreSQL ngày 2026-09-10: cột `wallet."Status"` là **`varchar(7)`** còn giá trị cần gửi là `'Inactive'` — **8 ký tự**. Bản đầu có đẩy lên, và trên máy ảo nó **kẹt hàng đợi đẩy**, thử lại ở mọi chu kỳ. Nhánh **kéo về** phải im lặng cùng lúc: client không đẩy cột này nên server giữ `'Active'` cho mọi ví của tài khoản còn dùng (chỉ ví của tài khoản đã bị xoá hẳn mới bị `scheduler.service.js` đặt `'Inactive'`), nên một bản chỉ gỡ nhánh đẩy sẽ khiến ví vừa lưu trữ tự bỏ lưu trữ sau đúng một chu kỳ. Tài liệu xin backend nới cột: `docs/superpowers/backend/DA-XONG/WALLET_STATUS_COLUMN_WIDTH.md`. Hệ quả trong lúc chờ: lưu trữ chỉ có hiệu lực trên **máy đã bấm**. ✅ CSDL dev **đã nới** lên `varchar(20)` tối 2026-09-10 (áp tệp 7); client chưa mở lại — người dùng chốt để sau.
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
  > **Không sửa được hoàn tác hoá đơn.** Xếp `BILL_ALREADY_PAID` vĩnh viễn chỉ ngăn việc gửi lại vô ích; chốt ở `upsertBill` của `main` vẫn từ chối hoàn tác (hồi quy B, CAN-LAM 17) — việc ấy của backend. ✅ Backend bỏ chốt ấy (gộp `cbbeeb4` 2026-09-12), hoàn tác đã lên server — nhưng chốt mới ở `upsertTransaction` khi ấy chưa có (✅ có từ `7779999`, gộp tối muộn cùng ngày — khối "Gộp `main` @ `7779999`…" dưới).
  > **Test:** 3 ca mới ở `core/sync/sync_failure_handling_test.dart`, cùng khuôn các ca mã sẵn có — `SyncEngine` thật, chỉ giả tầng HTTP, kiểm `syncBlockedUntil`. Lượt đỏ đúng 3 ca đỏ, cả ba `Expected: DateTime:<2026-09-03 08:00:30.000>`, `Actual: <null>`. Nền `flutter test` **2026 → 2029** (155 giây), `flutter analyze` giữ **25 issue** — đọc thẳng log: 20 info, 5 warning, 0 error.
  > **Bẫy đo trong phiên:** dòng `warning` của `flutter analyze` in sát lề, không thụt đầu dòng như `info`, nên đếm theo mẫu `^\s+warning - ` ra **0** dù có 5 — chỉ lộ ra vì tổng theo mức (20) lệch dòng tổng kết (25). Đếm theo mức thì đối chiếu lại với dòng tổng kết.

- **Gộp `main` @ `cc65f4f` về nhánh này** (2026-09-11, theo yêu cầu người dùng; **không đổi mã client**, schema Drift không đổi). Mang về `7675b35` (mã backend, `database/12_Can_Lam_Align_Schema_Fixes.sql`, `scripts/apply_migration_12.js`), `f8ab027` (chuyển 15 tài liệu `CAN-LAM/` → `DA-XONG/`, viết lại đầu `CAN-LAM/README.md` thành "15/15 mục đã hoàn tất", thêm mục 11.36 vào `Project.md`) và `f9d13c9` (chỉ `docs/Rule_Project/Data_Security.md`). Một xung đột, ở `CAN-LAM/README.md`: giữ nguyên văn tiêu đề và khối 🎉 của backend, thay banner cũ bằng banner "đã gộp, client chưa soát từng mục", trỏ 17 liên kết của mục 1–2 sang `../DA-XONG/`. Sửa thêm 7 liên kết hỏng vì chuyển tệp ở `DA-XONG/` và `TRANSACTION_NOTE_ENCODING.md`, và các câu "chưa gộp" ở `CLAUDE.md`, `CLIENT_APP_KNOWN_GAPS.md`, `FIX_BACKEND_3_REGRESSIONS.md`, spec cưỡng chế đăng xuất và khối ngay trên. Sau gộp, `git diff origin/main -- src/Backend` rỗng và `src/Client-app` không đổi so với `9f57342`.
  > **Lúc gộp, máy này chưa theo kịp mã đã gộp:** CSDL dev chưa áp `database/12` và Prisma Client chưa sinh lại, nên chạy backend từ nhánh này là đồng bộ vỡ (mã đọc/ghi `category.Color`, bốn cột mới của `bill`, `transaction.Idbill`) — ✅ cả hai xong cùng ngày, khối kế tiếp. Dù áp xong, bắt tay socket cùng `/auth/refresh` vẫn từ chối mọi tài khoản cho tới khi backend sửa CAN-LAM 17 mục A — nên nhánh socket của spec cưỡng chế đăng xuất **không còn kiểm đầu-cuối được** trên máy này (spec §7.3). ✅ 2026-09-12: gộp `cbbeeb4`, bắt tay nối được — kiểm lại được.
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
  > **Hỏng đúng như đo trên mã:** bắt tay Socket.io từ chối tài khoản 10 đang `Active` với `Authentication error: Account no longer exists or has been deleted`, `data` không có `code` (CAN-LAM 17 A, 18 §2.1); kênh thử nối lại theo giãn cách 2s → 5s → 15s (✅ hết 2026-09-12: sau gộp `cbbeeb4`, cùng máy ảo nối được ngay). G24 thấy tận mắt: SQLite `colour = '#FF5722'`, server `Color = NULL`.
  > **Phát hiện kèm:** (1) bước 1b của `_collectPendingOps` (`sync_engine.dart:1078`) cố ý đẩy kèm danh mục người dùng mà giao dịch chờ trỏ tới, nên mỗi lần đẩy một giao dịch có danh mục thì server trả một xung đột "bản server mới hơn" — vô hại; và bước ấy cũng gửi `colour` (`:1109`), nên sửa G24 phải chạm cả chỗ này. (2) Bộ chọn ví ở màn Thêm giao dịch hiện **khoá thô** `saving`/`cash` dưới tên ví (`add_transaction_page.dart:392` in thẳng `wallet.type`) thay vì nhãn của `WalletType` — lỗi hiển thị nhỏ, **chưa sửa** (✅ sửa cùng ngày — khối "Nhãn loại ví ở bảng chọn ví" dưới). (3) Bàn phím số nằm trong vùng cuộn (`add_transaction_page.dart:679-691`), nên ở 411dp hàng `1 2 3` và `. 0 000 ✓` chỉ hiện sau khi vuốt — chủ ý, không tràn.
  > **Không kiểm:** hoàn tác hoá đơn (vỡ `BILL_ALREADY_PAID` theo 17 B và để máy lệch server — ✅ hết từ `cbbeeb4` 2026-09-12), đẩy ngân sách/mục tiêu/hoá đơn, đăng nhập tài khoản khác (sẽ dọn dữ liệu cục bộ của tài khoản 10 trên máy ảo).

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

- **Ba cột hoá đơn đi qua đồng bộ** (2026-09-12, **schema không đổi**). Ba cột client đã có cục bộ từ v16/v18 nhưng chưa gửi/đọc nay đi được cả hai chiều: `transactions.billId` → `transaction.Idbill` (khoá payload **`idbill`**), `bills.generatedFromBillId` → `bill.Previous_bill_id` (**`previous_bill_id`**), `bills.anchorDay` → `bill.Anchor_day` (**`anchor_day`**). Ba commit: `4d47ad0` (thứ tự đẩy), `906363d` (hoá đơn), `285b009` (giao dịch). Nhờ vậy chuỗi kỳ của hoá đơn lặp và đường lần từ hoá đơn về khoản chi không còn chết ở ranh giới một máy — tức **hoàn tác thanh toán** chạy được liên máy.
  > **Cái bẫy lớn nhất, phải làm TRƯỚC:** `transaction.Idbill` có khoá ngoại `fk_transaction_bill`, mà hoá đơn đang được đẩy **sau** giao dịch. Gửi khoá nối mà không đổi thứ tự thì khoản trả hoá đơn vỡ khoá ngoại rồi **kẹt hàng đợi đẩy, thử lại mãi** — im lặng, không log. Thứ tự nay là categories → wallets → goals → **bills** → transactions → budgets, cùng lý do đã khiến mục tiêu dời lên trước giao dịch hồi 2026-09-07. Có ca test canh, chép đúng khuôn ca canh thứ tự của mục tiêu.
  > **Nhánh kéo về dùng `Value.absent()` khi server im lặng** — cùng luật `idgoal`: hàng đã nằm sẵn trên server mang `NULL` cho tới khi client đẩy lại từng hàng, nên gán thẳng `Value(null)` là cắt đứt chuỗi kỳ và **xoá ngày gốc** ngay chu kỳ pull đầu tiên; mất ngày gốc thì ngày đến hạn quay về bị **đoán**, tái sinh quy tắc "đoán cuối tháng" đã bỏ ngày 2026-09-08.
  > **Tên khoá `idbill` đã đọc mã backend để chắc, không đoán:** nhánh giao dịch của `sync.repository.js` đổi tên `billId`/`bill_id` → `idbill` (dòng 39-40), rồi `create`/`update` **chọn trường tường minh** bằng `mapped.idbill` (dòng 304, 326) — nên gửi thẳng `idbill` cũng tới nơi vì nó đã đúng tên đích, và khớp khuôn `idgoal`.
  > **Đánh đổi nói thành lời:** hàng hoá đơn và giao dịch **đã có sẵn** trên server vẫn mang `NULL` ở ba cột này cho tới khi được sửa lại (client chỉ đẩy hàng `pending`), nên chuỗi kỳ cũ và khoản trả cũ **vẫn** không hoàn tác liên máy được. Cùng hình dạng với `idgoal` hồi 2026-09-07; cố ý **không** dựng đường "đẩy lại toàn bộ".
  > ✅ **Kiểm chứng đầu-cuối trên backend thật, 2026-09-12** (máy ảo `emulator-5554`, tài khoản 11): tạo hoá đơn lặp hàng tháng → **Thanh toán** → đo thẳng PostgreSQL. Kỳ 1 mang `Anchor_day = 12`; kỳ 2 vừa sinh mang `Previous_bill_id` = id kỳ 1 **và** `Anchor_day = 12`, hạn đúng 12/11; khoản chi mang `Idbill` = id kỳ 1. **Cả ba cột tới server đúng giá trị.**
  > ⚠️ **Lượt ấy còn tái hiện được CAN-LAM 17 B trên backend thật** — không phải lỗi của hạng mục này. Bấm **Hoàn tác**: kỳ kế tiếp bị gỡ và khoản chi bị xoá mềm ở **cả hai** nơi, nhưng hoá đơn gốc kẹt `Payed` trên server (`Push failed [permanent]: … Hóa đơn đã được thanh toán, không thể thay đổi trạng thái`) trong khi máy đã về `Pending` — **lệch vĩnh viễn**, vì client xếp đúng `BILL_ALREADY_PAID` là lỗi vĩnh viễn nên không thử lại. Bằng chứng đầy đủ đã ghi vào đầu mục 3 `CAN-LAM/FIX_BACKEND_3_REGRESSIONS.md` (nay `DA-XONG/`). ✅ **2026-09-12 chiều:** sau gộp `cbbeeb4`, đúng hàng ấy lên server `Pending` ở chu kỳ đẩy kế tiếp (15:10:21) — nửa đầu của hồi quy B đã đóng; chốt đúng chỗ thì chưa có.
  > **Hai thứ cố ý ĐỂ NGOÀI:** `bill.Auto_pay` chờ backend sửa CAN-LAM 17 B (chốt chống trả hai lần đặt nhầm ở `upsertBill` — ✅ chốt đúng chỗ có từ `7779999` tối muộn cùng ngày, hết chờ), và `bill.Period_end` **không phải trường đồng bộ mà là một tính năng** — client chưa có cột lẫn khái niệm, và dùng nó đòi cột cục bộ mới (v21), ô nhập trên một màn Stitch mới, ràng buộc `Start_date < Period_end ≤ Due_date`, cộng **đổi phép tính kỳ kế tiếp** sang neo vào `Period_end`. Làm nửa vời thì hoá đơn "kỳ 01–30/09, hạn 15/10" sinh kỳ sau bắt đầu 15/10 — hở nửa tháng, mỗi kỳ trôi thêm (`DA-XONG/2026-09-06-bill-chuoi-ky-va-an-han.md` mục 4.4). Người dùng chốt tách ra ngày 2026-09-12. ✅ **`Period_end` xong tối cùng ngày** — bước 14, khối "Ân hạn hoá đơn" ở trên, đúng cả hai việc đi cùng nhau.

- **Bỏ qua kỳ hoá đơn (`Pay_status = 'Skipped'`)** (2026-09-12, **schema không đổi, không thêm trường đồng bộ**). Bước **9** trong thứ tự đã duyệt. Sáu commit `be21525` → `e2d7fd0`, một hạng mục một commit, mỗi hạng mục viết test đỏ trước. Hoá đơn lặp có kỳ **không phải trả** (đi vắng cả tháng, chủ nhà miễn một tháng, gói dịch vụ tặng kỳ); trước đó người dùng chỉ có hai lối đều sai — *trả giả* (sổ có khoản chi không có thật, mà `payBill` từ chối số ≤ 0 nên cũng không làm được) hoặc *xoá kỳ* (đứt mắt xích `generatedFromBillId`, và vì chỉ `payBill` mới sinh kỳ sau nên chuỗi dừng hẳn). Spec: `docs/superpowers/specs/2026-09-12-bo-qua-ky-hoa-don-design.md`; chi tiết: mục **6.7** `docs/bill/BILL_DOCUMENTATION.md`.
  > **Điều đáng nhớ nhất: câu "đã trả chưa" TÁCH LÀM HAI.** *Còn phải trả?* (nhắc, tự trả, tổng nợ, `markOverdue`, `getUpcoming`) và *đã có khoản chi?* (hoàn tác, dòng "Trả dd/MM", tra `transactions.billId`) trùng nhau với ba giá trị cũ nhưng **khác nhau** với `Skipped`. Trước đợt này biểu thức ấy bị **chép tay ở 10 chỗ thuộc 7 tệp** (đếm bằng script) — và **ba** trong số đó tình cờ đúng với giá trị mới **do may, không do thiết kế**. Nay tất cả đi qua `lib/features/bill/domain/bill_pay_status.dart`: bốn hằng chuỗi (**bắt buộc**, vì `getUpcoming` và `markOverdue` là truy vấn SQL không gọi được vị từ Dart) cộng ba vị từ `daCoKhoanChi`/`daBoQua`/`conPhaiTra`; giá trị lạ đọc là *còn phải trả*. Đếm lại cùng ngày: **0** bản chép tay còn sót.
  > **Bốn chỗ thật sự vỡ nếu không sửa**, mỗi chỗ một kiểu hỏng im lặng: `getUpcoming` lôi kỳ bỏ qua ra cho bộ quét thông báo; `notification_rules` sinh nhắc; `reminder_scheduler` đặt lịch **AlarmManager** (nổ trên màn hình khoá, và lịch ấy không nằm trong SQLite nên dọn dữ liệu không cứu được); và `denLuotTuTra` **tự trừ tiền ví** — chỗ mất tiền thật.
  > **Ba chốt chặn, phá là hỏng im lặng:** (1) `payBill` **từ chối** kỳ `Skipped` — kỳ ấy đã sinh kỳ kế tiếp rồi, trả tiếp là sinh kỳ thứ hai trùng hạn; (2) `undoSkip` **từ chối** kỳ đã trả — hoàn tác lần trả phải đi qua `undoPayment`, thứ có bước hoàn tiền, đi nhầm đường là hoá đơn về `Pending` mà tiền vẫn ngoài ví; (3) nhánh `skipped` của `billDisplayStatusOf` phải đứng **TRƯỚC** mọi phép so ngày, nếu không kỳ bỏ qua đã trễ lại đeo nhãn đỏ "QUÁ HẠN". `undoSkip` **không** có bước hoàn tiền — chép nguyên `undoPayment` sang là **tặng tiền cho ví**, có test canh.
  > **Giao diện:** nút chỉ ở trang chi tiết (người dùng chốt); `_nutThaoTac` từ hai nhánh thành ba; hai nút **xếp dọc trong `Column`**, không đặt trong `Row` (bẫy 4.11 — theme ép mọi `ElevatedButton` rộng vô hạn). Tab thứ hai đổi tên **"Đã thanh toán" → "Lịch sử"** vì nó nay chứa cả kỳ chưa hề được trả đồng nào, và `BillSections` đổi `unpaid`/`paid` → `chuaDong`/`daDong` cùng lý do.
  > **Ba màn Stitch** dựng cùng ngày (design system "Kinetic Finance", `assets/e8b7d56e…` — ⚠️ dự án có **hai** design system trùng tên "Kinetic Finance", bản kia lệch màu (`overridePrimaryColor #2d3436` thay vì `#1a1a19`), đừng dùng nhầm): *Chi tiết hóa đơn - Mobile*, *Chi tiết hóa đơn* (trạng thái bỏ qua), *Chi tiết hóa đơn - Modal Bỏ qua kỳ này*. Trang chi tiết trước đó **chưa bao giờ có màn Stitch** — đợt này vá luôn lỗ hổng có từ 2026-09-06. Nhãn `BỎ QUA`: nền `#E8E8E4`, chữ `#5A5C56`.
  > ✅ **Kiểm đầu-cuối trên máy ảo `emulator-5554` + PostgreSQL (chỉ đọc), 2026-09-12.** Bỏ qua một hàng **sạch**: server nhận đúng `Pay_status = 'Skipped'`, kỳ kế tiếp mang `Previous_bill_id` trỏ về nó. Hoàn tác: server về `Pending`, kỳ kế tiếp được đặt `Delete_at`. **Không giao dịch nào** được sinh ở bất kỳ bước nào (`COUNT(*) = 0` cho tài khoản 11).
  > ⚠️ **Lượt kiểm ấy tìm ra một lỗi mà 2210 ca test đều bỏ sót** — đúng loại bàn giao phiên trước đã cảnh báo: trang chi tiết đã đúng từ đầu, nhưng **dòng trên tab Lịch sử** vẫn suy *hai* trạng thái (`isPaid` hay không) nên kỳ `Skipped` rơi vào nhánh "chưa trả" và **được bày nút Thanh toán** — bấm vào là mở bảng trả rồi bị repository từ chối. Vá ở `e2d7fd0` bằng nhánh thứ ba `daBoQua`, kèm ca test tái hiện.
  > ⚠️ **Hàng `3c90acfa…` của hoá đơn `Kiem` KHÔNG dùng để kiểm được**: nó đã lệch sẵn (server `Payed`, máy `Pending`) và mọi lần đẩy đều nhận *"Hóa đơn đã được thanh toán, không thể thay đổi trạng thái"* — bằng chứng **CAN-LAM 17 B**, không phải lỗi của hạng mục này. Sau lượt kiểm, hàng ấy đã được trả về đúng trạng thái bằng chứng cũ. ✅ Từ 15:10 ngày 2026-09-12 (sau gộp `cbbeeb4`) hàng ấy đã `synced`, server `Pending` — bằng chứng không còn, và hàng dùng lại để kiểm được.
  > **Mức nền sau hạng mục:** `flutter test` **2211/2211** (2 phút 39 giây; 37 ca mới so với mốc 2174), `flutter analyze` **25 issue = 0 error** — khớp mức nền. Cụm `test/features/bill/` có **219** ca (đếm bằng máy 2026-09-12).

- **Xem giao dịch của một ví — đường tắt từ màn Quản lý ví** (2026-09-14, **schema không đổi**, không đụng đồng bộ).
  > ⚠️ **Khảo sát đổi hai lần trước khi chốt, và cả hai lần vì tôi đọc sai mã.** (a) Kế hoạch buổi sau mô tả đây là tính năng còn thiếu; thật ra **bộ lọc theo ví vốn đã có** trên trang Sổ giao dịch (chíp "Ví" của `TransactionFilterBar`, kèm cả ca test canh nhãn chíp) — thứ thiếu chỉ là đường tắt. (b) Tôi báo "tap vào thẻ ví không mở gì cả"; thật ra nó **đã** mở màn Sửa ví — lượt `grep 'onTap'` chỉ thấy nút "Thêm ví mới" nên tôi kết luận nhầm.
  > **Vì thế đường vào là MỤC MENU, không phải cú tap.** "Xem giao dịch" đứng **đầu** menu ba chấm, trước "Chỉnh sửa"; xem là việc thường xuyên hơn sửa, và hành động không hoàn tác được ("Xóa ví") vẫn ở cuối. Đổi ý nghĩa của cú tap là lấy mất một thao tác người dùng đã quen.
  > **Mục này có ở CẢ ví lưu trữ** — đóng băng nói về việc ghi chép **mới**, không phải về quyền đọc lịch sử cũ. Giấu nó ở ví lưu trữ là khoá người dùng khỏi chính dữ liệu của họ.
  > **Ba mảnh nhỏ:** `_WalletItem` nhận `onXemGiaoDich`; route `/transactions` đọc `?wallet=<id>`; `TransactionPage` nhận `initialWalletId` và khởi tạo `_filter` từ nó. **Query param chứ không `extra`** vì `extra` mất khi GoRouter dựng lại route. Và `_filter` khởi tạo ở khai báo `late` chứ không gán trong `build`: gán trong `build` là mỗi lần dựng lại giật bộ lọc về ví ban đầu, nên người dùng **không bỏ lọc ra được**.
  > ⚠️ **Một widget test TREO 10 phút chứ không đỏ**, và nguyên nhân đáng nhớ: repo giả chỉ hiện thực `getAll`, trong khi `WalletCubit.loadWallets` gọi **cả** `getTotalBalance`. Thiếu hàm thứ hai thì cubit kẹt ở `WalletLoading`, trang hiện `CircularProgressIndicator` — animation **vô hạn** — và `pumpAndSettle` không bao giờ settle. Đây đúng loại treo mà `CLAUDE.md` cảnh báo; cách chữa là chạy kèm `--timeout 60s` để nó đỏ thay vì treo.
  > **Không cần Stitch:** mục menu là phần tử cùng kiểu với ba mục đã có, không phải khối giao diện mới.
  > ✅ **Nghiệm thu máy ảo** (tài khoản thử 25): menu ba chấm hiện đúng thứ tự **Xem giao dịch → Chỉnh sửa → Lưu trữ → Xóa ví**; bấm nó mở Sổ giao dịch với chíp ví **bật sẵn mang tên ví** ("Tiết kiệm") chứ không phải chữ "Ví" chung chung, danh sách lọc đúng. Ví **lưu trữ** cho ca đẹp nhất: menu của nó cũng có mục ấy (và vẫn không có "Xóa ví"), và vì ví ấy chưa có giao dịch nào nên màn hình nói thẳng *"Không có giao dịch nào khớp bộ lọc — Đổi điều kiện hoặc bấm 'Xoá lọc'"*. Đó đúng là chốt chặn đáng lo nhất của thiết kế: bộ lọc đặt sẵn **không âm thầm**, và người dùng biết ngay cách bỏ nó.
  > **Mức nền sau hạng mục:** `flutter test` **2359/2359** (3 ca mới), `flutter analyze` **25 issue / 0 error**.

- **Ba trang giao dịch thôi rơi về tài khoản admin — G38** (2026-09-14, **schema không đổi**). Tìm ra khi khảo sát cho một tính năng khác, và sửa trước theo nếp *sửa lỗi trước, tính năng sau*. Commit `054075b`.
  > **Cách nó sống sót đáng nhớ hơn bản thân lỗi.** Nó đi qua cả hai lượt đóng cùng chủ đề — **G4** (bốn trang bill/goal) và **G35** (ba màn quản lý danh mục) — vì viết khác: `const TransactionPage({super.key, this.idaccount = 1})` rồi `?? widget.idaccount`. Vế `??` trỏ tới một **biến**, không tới hằng `1`, nên mọi lượt `grep '?? 1'` đều sạch — kể cả lưới quét `khong_du_phong_admin_test.dart` dựng ra sau G35. Nhưng route dựng `const TransactionPage()` nên giá trị thật sự dùng vẫn là **1**.
  > **Ba chỗ, chỗ nặng nhất là đường GHI:** `transaction_page` mở stream ví + danh mục của admin; `choose_category_page` đọc danh mục của admin; `add_transaction_page` ghi **giao dịch** dưới danh nghĩa admin rồi đẩy lên và vỡ "Ownership mismatch" — đúng kịch bản docstring `current_account.dart` mô tả khi G4 được đóng, chỉ khác là nó nằm trên đường đi nhiều nhất của app.
  > ⚠️ **Lượt khảo sát tự nó suýt kết luận sai:** phép `grep -E` đầu tiên dùng `\s`, mà **POSIX ERE không có `\s`** — nó trả rỗng và suýt chốt "chỉ một chỗ", thật ra có **ba**. Đây là lần thứ tư trong dự án một phép `grep` làm sai kết luận. Dart `RegExp` thì **có** `\s`, nên lưới quét viết bằng Dart không dính lỗi này — nhưng nó dùng `[ 	]` chứ không `\s`, vì `\s` khớp cả xuống dòng và sẽ dính một tham số ở dòng này với một hằng `= 1` ở dòng sau.
  > **Bản sửa:** ba trang để tham số `int?` **không mặc định** (widget test vẫn tiêm được), suy tài khoản trả `null`, và tự xử lý `null` — đường đọc không mở stream, đường ghi chặn lưu kèm thông báo, cùng khuôn G35. Lưới quét thêm **ca thứ hai** bắt đúng hình dạng vừa lọt.
  > **Hai ca hành vi mới** ghi thẳng một điều bản đầu của chính chúng làm sai: trong luồng thường, thiếu phiên thì màn chọn danh mục **cũng rỗng** nên chốt "Vui lòng chọn danh mục" chặn trước — chốt tài khoản là **lớp phòng thủ thứ hai**, phải tiêm lệch mới dựng lại được trạng thái ấy. Bản đầu bỏ bước chọn danh mục nên **xanh vì lý do sai**. Đã kiểm bằng bản sai có chủ ý.
  > ✅ **Nghiệm thu máy ảo** (tài khoản thử 25, PostgreSQL chỉ đọc): mốc nền cả tài khoản 1 lẫn 25 đều **0 giao dịch**; thêm một khoản chi 55đ qua giao diện → `Idaccount = 25`, `Amount = -55`; tài khoản 1 vẫn **0 hàng**. Màn chọn danh mục và trang Sổ giao dịch vẫn mở đầy đủ.
  > **Mức nền sau hạng mục:** `flutter test` **2356/2356** (3 ca mới: 1 lưới quét, 2 hành vi), `flutter analyze` **25 issue / 0 error**.

- **Lưu trữ ví qua đồng bộ — đóng G28** (2026-09-14, **schema v21 → v22**, payload ví **12 → 13 trường**). Khoảng trống cuối cùng mà client tự đóng được: trước bản này, lưu trữ một ví chỉ có hiệu lực **trên chính máy đã bấm** — máy thứ hai của cùng tài khoản vẫn thấy ví ấy trong mọi bộ chọn, vẫn cộng vào tổng tài sản, và hai bộ chạy tự động vẫn dùng nó. Spec: `docs/superpowers/specs/2026-09-14-g28-luu-tru-vi-qua-dong-bo-design.md`; commit `268eb50`.
  > **Đo lại phía server trước khi làm, không chép tài liệu cũ.** `wallet."Status"` nay `varchar(20)`, `NOT NULL`, `DEFAULT 'Active'`, `chk_wallet_status` nhận `Active|Inactive` — chỗ chặn cũ (`varchar(7)` trong khi `'Inactive'` dài 8 ký tự) đã hết từ `database/7`. Và **đường đi vốn đã sẵn ở cả hai chiều**: `upsertWallet` ghi `status: mapped.status ?? existing.status`, còn `getWalletsByAccount` là `findMany` **không có `select`** nên payload pull **vốn đã mang `status`** — client chủ động bỏ qua nó. Không tầng validation nào chạm cột này (phép kiểm `status` ở `sync.validation.js` nằm gọn trong nhánh `entity === 'transaction'`).
  > **Ba mảnh mã, thiếu mảnh nào cũng vô hiệu cả ba:** payload mang `'status': w.status` (chuỗi thô của SQLite); `walletForPush` dịch sang từ vựng server qua `WalletStatus.tuKhoa(...).khoaGuiLen`; nhánh kéo về đọc ngược lại về **chữ thường**. Mở **một** chiều thôi là hỏng im lặng — chỉ đẩy thì server giữ `'Active'` rồi ví tự bỏ lưu trữ sau một chu kỳ pull; chỉ kéo về thì thao tác lưu trữ không bao giờ rời máy.
  > ⚠️ **Mảnh thứ tư — migration v22 — và vì sao KHÔNG tách commit được.** Ví đã lưu trữ *trước* bản này đang ở `synced` nên nhánh đẩy không gửi lại chúng, trong khi cột của server là `NOT NULL DEFAULT 'Active'`: lượt pull **đầu tiên** sau khi cập nhật app sẽ lặng lẽ bỏ lưu trữ chúng. v22 đánh `sync_status = 'pending'` cho ví `inactive` chưa xoá, và nó đủ vì **Push chạy trước Pull trong cùng chu kỳ**. Nhưng bước cứu ấy chỉ chạy **một lần trong đời** mỗi máy — nên phát hành migration trước nhánh đẩy là đánh dấu ví, đẩy lên **không kèm `status`**, rồi `synced` lại, và lượt mở đồng bộ sau không còn gì để đánh dấu. Bốn mảnh vào **một commit**.
  > **Một rủi ro đã loại trừ bằng phép đo:** server dùng chính cột ấy cho nghĩa thứ hai — *"ví thuộc tài khoản đã bị xoá"* (2 hàng thật trên CSDL dev, đều của tài khoản 12 đã `Deleted`). Chỉ hai chỗ ghi `Inactive` (`scheduler.service.js:76`, `admin.repository.js:163`), cả hai trên đường **xoá**; admin **khoá** tài khoản không đụng ví, đường người dùng tự yêu cầu xoá (còn dùng app 30 ngày — G33) cũng không, và **không có đường khôi phục tài khoản**. Tài khoản nào còn đăng nhập được thì ví của nó không bị server đặt `Inactive`. ⚠️ Giả định này phải kiểm lại nếu backend thêm chức năng khôi phục tài khoản.
  > **Hai thứ lượt thi công tìm ra mà kế hoạch không biết.** (a) Có một ca **thứ ba** canh chiều cũ, ở nhóm PULL của tệp hợp đồng (*"server KHÔNG bỏ được lưu trữ của ví"*) — đảo chiều, giữ lại vì nó canh **tên khoá**, đúng vai trò tệp hợp đồng. (b) **Ba tệp test dựng lược đồ tay** thiếu thứ v22 cần, mỗi tệp một nguyên nhân: `bill_schema_v21` không dựng `wallets` chút nào; `category_dao` và `notification_schema_v13` dựng `wallets` thiếu cột `status`. Ngoài đời cột ấy do migration `from < 6` thêm nên CSDL thật ở mọi phiên bản ≥ 6 đều có — thiếu ở phía **bản dựng thử**. `category_dao` nay khai nó theo `atVersion >= 6`, đúng khuôn có sẵn của chính tệp ấy.
  > ⚠️ **Thứ duy nhất còn có thể làm G28 hỏng, và client không chặn trước được:** máy chủ nào **chưa áp `database/7`** vẫn `varchar(7)` và sẽ từ chối `'Inactive'` — ví lưu trữ **kẹt hàng đợi đẩy vĩnh viễn, im lặng**. Đã đo CSDL dev; **chưa đo môi trường nào khác**.
  > **Hai ca phòng thủ xanh ngay từ đầu** (server im lặng / `null` tường minh) vì nhánh pull cũ không đọc gì, nên kiểm bằng **bản sai có chủ ý**: bỏ `Value.absent()` → đúng hai ca ấy đỏ, rồi khôi phục. Nếp này dự án đã dùng nhiều lần.
  > ⚠️ **Lượt NGHIỆM THU MÁY THẬT bắt được một lỗi mà spec, kế hoạch, 12 ca test và cả lượt tự soát spec đều bỏ sót** — và nó hỏng **im lặng**, ở đúng cơ chế sinh ra để chống hỏng im lặng. Bản migration đầu tiên chỉ đổi `sync_status`; đo trên máy ảo: `Sending batch 1 operations` → **`Push conflict (bản server mới hơn, lấy theo server)`** → `0/1 synced`. Migration chạy đúng và ví **được** đẩy đi, nhưng `upsertWallet` chỉ ghi khi `new Date(mapped.update_at) > new Date(existing.update_at)` — mà ví lưu trữ cũ **đã từng được đẩy lên** (chỉ thiếu cột `status`), nên mốc của nó **bằng đúng** mốc trên server. Không lớn hơn → server giữ bản của nó → client `markSynced` để thoát vòng lặp (luật G9) → **trạng thái lưu trữ không bao giờ rời khỏi máy**. Vì sao 12 ca test không thấy: ca hợp đồng dựng hàng với `DateTime.now()` nên luôn mới hơn, còn ca migration chỉ đọc cột `sync_status` chứ không đi qua `/sync/push` thật. Sửa ở `d3c5415`: migration đẩy cả `updated_at = CAST(strftime('%s','now') AS INTEGER)` — **giây** Unix, vì Drift lưu `DateTime` theo giây. Ca test thứ hai đi kèm quan trọng không kém: ví **không** được đánh dấu thì phải **giữ nguyên** mốc, vì đổi mốc của hàng không cần đẩy là tự tạo một cuộc đua LWW đè lên bản mới hơn của máy khác.
  > ✅ **Nghiệm thu hai máy ảo, đủ bốn ca, tài khoản thử 25** (`emulator-5554` + `emulator-5556`, PostgreSQL chỉ đọc sau mỗi bước): **(1) di trú** — lưu trữ ví "Tiền mặt" bằng APK **trước G28** (`Update_at` đổi 09:26:05 nhưng `Status` vẫn `Active`, đúng trạng thái G28 sinh ra để sửa) → cài đè APK mới **không gỡ app** → ví **vẫn** lưu trữ trên máy và server thành **`Inactive`** (09:27:01), trong khi ví "Tiết kiệm" **không bị đụng** (mốc vẫn 09:03:54); **(2) lưu trữ lan A → B** — máy B chưa từng thấy thao tác ấy vẫn hiện "ĐÃ LƯU TRỮ (1)" và "Không gồm 1 ví đã lưu trữ"; **(3) bỏ lưu trữ lan B → A** — server về `Active` (09:35:07), ví quay lại danh sách trên máy A; **(4) lưu trữ thường A → B** (không qua migration) — server `Inactive` (09:37:01), máy B nhận.
  > ⚠️ **Hai bẫy hạ tầng của lượt nghiệm thu, không phải lỗi mã:** hai emulator chạy song song với một lượt `flutter build apk` làm **SystemUI ANR rồi đóng băng cả pipeline đồ hoạ** — `screencap` trả mãi một frame cũ (đồng hồ đứng ở 4:11) trong khi `adb shell date` vẫn chạy và app vẫn nhận input. Dấu hiệu phân biệt: so `adb shell date` với giờ trên status bar của ảnh chụp. Chữa bằng khởi động lại emulator — nhưng dùng **`-gpu swangle`** chứ không `swiftshader_indirect` như dòng này từng ghi: đo ngày 2026-09-14, `swiftshader_indirect` để máy ảo chết ba lần với exit 139 khi người dùng thao tác trực tiếp trên cửa sổ, còn `swangle` thì hết hẳn (người dùng xác nhận). Chi tiết ở mục "Chạy máy ảo" `CLAUDE.md`. Và backend chạy nền qua công cụ Bash **không ghi log console ra tệp** (đo: 0 byte) nên không đọc được OTP; OTP lưu ở bảng `otp_code` dạng **`code_hash`** (băm, không đảo được) — cách chạy được là `node index.js > log 2>&1` thẳng, bỏ `npm → cmd → nodemon`.
  > **Mức nền sau hạng mục:** `flutter test` **2353/2353** (14 ca mới ở 4 tệp: 5 pull, 6 migration, 3 normalizer), `flutter analyze` **25 issue / 0 error**.

- **Dòng "Kỳ" cho bốn màn Stitch *Chi tiết hóa đơn*** (2026-09-13). Việc nhỏ thứ ba trong danh sách. **Đo trước khi sửa cho thấy bàn giao đếm thiếu: BỐN màn thiếu, không phải hai** — `0eecd62f…` và `e7f48af7…` (Desktop), `b4aaff9b…` (*Mobile*), `fe9ae28a…` (*Modal Bỏ qua kỳ này*); cả bốn mở khối `THÔNG TIN` thẳng bằng "Đến hạn". Giá trị đặt là `21/08/2026 → 20/09/2026` — **cố ý cho kỳ kết thúc TRÙNG hạn trả (ân hạn 0)**, vì lịch sử kỳ trên chính màn ấy cách đều một tháng (20/07, 20/08, 20/09); đặt ân hạn khác 0 là làm màn tự mâu thuẫn.
  > ⚠️ **Bẫy khi đọc màn Stitch:** chữ "Kỳ" **có** trong cả bốn màn — nhưng ở phần `LỊCH SỬ CÁC KỲ` ("Kỳ 20/09/2026 (đang xem)"), không phải dòng đang thiếu ở khối `THÔNG TIN`. `grep` một chữ rồi kết luận "đã có" là sai. Cách rẻ mà đúng: tải `htmlCode.downloadUrl` về, thay thẻ bằng `|`, rồi in đoạn ngay sau tên khối.
  > ⚠️ **`edit_screens` có ĐỘ TRỄ DÀI — và tôi đã kết luận sai vì nó.** Gọi xong, đo ngay thì mọi dấu hiệu đều nói "không ghi được": HTML giống bản gốc **từng byte**, `htmlCode.name` và `screenshot.name` đều y nguyên. Tôi kết luận công cụ hỏng, viết vào `CLAUDE.md`, mục này và tài liệu hoá đơn, rồi **commit** (`a090d3c`). Người dùng kiểm lại ít phút sau: màn **đã** sửa xong. Phải gỡ lại toàn bộ phần tài liệu ấy. Bài học: sau khi gọi thì **chờ, làm việc khác, kiểm lại sau**; "chưa đổi" nghĩa là **chưa biết**, không phải **thất bại**; và chỉ ghi kết luận vào tài liệu khi nó đã ổn định qua nhiều lượt đo cách nhau.
  > **Trạng thái đo được lúc 08:0x, sau ~25 phút và nhiều lượt gọi:** **Desktop 1 ✅** (7613 bytes, +198) và **Mobile ✅** (8837 bytes, +202) đã có dòng "Kỳ" đúng vị trí. **Desktop 2 và Modal thì KHÔNG** — `htmlCode.name` của hai màn ấy vẫn y nguyên ID gốc dạng hex (`3233e9a2…`, `98908c9a…`), trong khi hai màn nhận được thay đổi đều chuyển sang ID dạng số. Desktop 2 đã gọi **bốn** lượt, Modal **ba** lượt.
  > **Sửa thêm một chỗ lệch trạng thái, cùng đợt** (người dùng chốt "theo đề xuất của bạn"): ba màn Mobile/Desktop 2/Modal cùng lúc gắn nhãn **"ĐÃ THANH TOÁN"** ở đầu, kỳ đang xem ghi **"Bỏ qua"**, và bày nút **"Thanh toán"** — ba thứ không cùng tồn tại được: mã app cho kỳ `skipped` hiện nhãn **"BỎ QUA"** (`bill_status_visuals.dart:13`, chữ `#5A5C56` nền `#E8E8E4`) và **chỉ một** nút viền **"Hoàn tác bỏ qua"** (`bill_detail_page.dart:447-455` — *"Mời người dùng bấm vào chỗ chắc chắn báo lỗi là một giao diện nói dối"*). Desktop 1 vốn đã đúng, dùng làm chuẩn. ⚠️ Riêng **Modal thì sửa NGƯỢC chiều**: lớp modal đang *hỏi* "Bỏ qua kỳ này?" nên kỳ **chưa** bị bỏ qua — giữ hai nút, đổi nhãn đầu thành **"SẮP ĐẾN HẠN"** (`#FFE0B2` / `#8A5000`) và dòng phụ kỳ đang xem thành "Chưa trả". Áp nhãn "BỎ QUA" vào đó là làm chính câu hỏi của modal thành vô nghĩa.
  > **Người dùng chốt: coi như xong, chuyển việc khác** — không tốn thêm lượt đo. Nên **trạng thái hai màn Desktop 2 và Modal chưa được xác nhận bằng đo**; phiên sau đụng vào chúng thì kiểm lại trước, đừng tin dòng này là "đã xong". HTML chuẩn để dán tay lấy từ chính Desktop 1, ghi ở tài liệu hoá đơn.

- **Sửa lỗi: yêu cầu đồng bộ đến giữa chu kỳ đang chạy bị NUỐT** (2026-09-13, **schema không đổi**; 2 ca test mới). Việc nhỏ thứ ba trong danh sách. `_runSync` từ chối chạy chồng bằng `if (_status == SyncStatus.syncing) return;` — không chạy chồng là **đúng**, nhưng chỉ `return` thì yêu cầu ấy **mất hẳn**: thay đổi vừa ghi phải chờ một nguồn kích hoạt khác (timer 15 phút, đổi mạng, hoặc lần mở app sau). Hỏng **im lặng** — không lỗi, không log, không test đỏ.
  > **Vì sao đáng sửa chứ không phải "thiết kế có chủ ý":** nhánh **giãn cách** ngay bên dưới trong **cùng hàm** xử lý đúng tình huống song sinh và ghi rõ lý lẽ — *"Từ chối một yêu cầu đồng bộ nghĩa là NỢ người gọi một lần chạy. Chỉ `return` ở đây thì thay đổi vừa ghi nằm chờ một nguồn kích hoạt khác"* — rồi gọi `_scheduleBackoffRetry`. Hai chốt cùng nghĩa, hai cách xử lý khác nhau; nhánh `syncing` là nhánh bị bỏ quên.
  > **Cửa sổ này không hiếm:** hai nguồn kích hoạt **dày nhất** lại là hai nguồn hay rơi đúng lúc đang chạy — `scheduleSync()` sau mỗi lần ghi (debounce 2 giây, gọi từ 19 vị trí) và sự kiện `sync.completed` của socket (G34) đánh thức `syncNow()` khi **máy khác vừa đẩy xong**. Mất một lượt ở đây là hai máy lệch nhau tới tận chu kỳ sau.
  > **Sửa:** cờ `_noMotLanChay` đặt ở chốt, trả nợ trong `finally` của `_runSync`. Đặt trong `finally` để chu kỳ bù vẫn chạy khi chu kỳ hiện tại **kết thúc bằng lỗi** — yêu cầu bị từ chối không liên quan gì tới việc chu kỳ đang chạy thành hay bại. Là `bool` chứ không phải bộ đếm: `_collectPendingOps` gom **toàn bộ** bản ghi còn `pending` chứ không xử theo từng yêu cầu, nên nhiều yêu cầu dồn vào một cửa sổ vẫn chỉ đáng **một** lần chạy bù.
  > **TDD:** hai ca ở `test/core/sync/sync_yeu_cau_giua_chu_ky_test.dart` (adapter giữ lượt `/sync/pull` đầu treo bằng `Completer` để đứng hẳn bên trong cửa sổ). Đỏ trước với đúng câu *"Hết 5 giây chờ: chu kỳ thứ hai chạy bù"*. ⚠️ Lượt viết test đầu đỏ **sai lý do** — `await engine.start(...)` treo tới timeout 90 giây, vì `start()` kết thúc bằng `await syncNow()`; phải `unawaited` nó thì mới đứng được trong cửa sổ cần đo. Ca thứ hai canh vế ngược lại: ba `syncNow()` dồn vào một cửa sổ vẫn chỉ đẻ **một** chu kỳ bù.
  > **Mức nền sau hạng mục:** `flutter test` **2266/2266**, `flutter analyze` **25 issue = 0 error**.

- **Đóng G36 — đo đầu-cuối ba ca `/auth/refresh` qua API admin** (2026-09-13, **không đổi mã chạy**; schema không đổi; chỉ một chú thích sửa). Việc đầu tiên trong danh sách năm bước còn tồn. Backend dev chạy mã `7779999`, tài khoản thử **tự đăng ký** qua `/auth/register` (`kiemthu_g36_…`, idaccount 16 — nên không cần mật khẩu tài khoản thử cũ), PostgreSQL **chỉ đọc**, mọi thay đổi trạng thái đi qua API admin đúng đường người dùng thật. Mật khẩu admin do người dùng đưa lại trong phiên — **không ghi vào tài liệu hay commit**.
  > **Ba ca, cả ba đúng:** **A** `Active` → **200** *"Token đã được làm mới"*, không mã (đối chứng). **B** `Inactive` (`PATCH /admin/updatestatus/16`) → **401 + `code: ACCOUNT_INACTIVE`**, kèm `idaccount: 16` và `reason_inactive` ở **cấp gốc**, `message` mang nguyên câu lý do admin nhập. **C** `Deleted` (`DELETE /admin/deleteuser/16`, xoá **mềm**) → **401 + `code: ACCOUNT_DELETED`** kèm `idaccount: 16`, **dù cả 4/4 refresh token đã bị thu hồi** — đây chính là ca gốc của G36 và là thứ CAN-LAM 20 §2.7 sửa (nhánh token thu hồi gọi `getAccountValidity` trước khi ném).
  > **Một bẫy khi đo:** `PATCH /admin/updatestatus/:id` nhận **`iduser`**, không phải `idaccount`, và body **bắt buộc** có `reason_inactive` (hoặc `reason`) khi đặt `Inactive` — thiếu là 400 *"Vui lòng cung cấp lý do vô hiệu hóa tài khoản!"*, mà lỗi ấy **im lặng làm hỏng phép đo**: trạng thái vẫn `Active` nên `/auth/refresh` trả 200 và trông như backend sai. Lượt đo đầu tiên đã vấp đúng chỗ này.
  > **Client không đổi mã:** `tuBody401` đọc `code` ở cấp gốc, `message`, `idaccount` — đúng ba trường backend trả — và ca `lamMoi` + `ACCOUNT_DELETED` đã có test từ trước (`test/core/api/auth_interceptor_buoc_dang_xuat_test.dart:267-289`).
  > ⚠️ **Phép đo lật một kết luận cũ.** Chú thích ở `lib/core/auth/buoc_dang_xuat.dart` và ba chỗ trong spec khẳng định *"xoá qua admin thu hồi refresh token nên `/auth/refresh` trả 401 không mã — đường `lamMoi` không bao giờ mang `daXoa`"*. Câu ấy đúng tới `cbbeeb4` và **sai từ `7779999`**. Hệ quả: **ngoại lệ §3.6b không còn vô nghĩa** — nó nay chặn một ca thật (tài khoản bị xoá, máy biết tin qua nhánh làm mới) chứ không chỉ che ca lỗi lược đồ giả định; đồng thời điều kiện "bỏ ngoại lệ khi đo được nhánh làm mới chạy đúng" mà spec đặt ra **nay đã thoả**. ✅ **Người dùng chốt cùng ngày: GIỮ ngoại lệ** (bước 2 xong) — SQLite là bản duy nhất trên máy nên dọn nhầm là mất thật; nếu xoá là đúng thì `purgeDataForOtherAccounts` vẫn dọn khi tài khoản khác đăng nhập, tức chỉ **hoãn** chứ không bỏ. Không đổi mã — hành vi hiện tại đã đúng; chỉ hai chú thích Dart ghi lại quyết định.
  > **Chưa đo trên máy ảo, có lý do:** `JWT_USER_ACCESS_EXPIRES=7d` nên không ép được access token hết hạn mà không sửa `.env` của `src/Backend` — việc cần cho phép đích danh. Tiêu chí đóng G36 mà chính tài liệu đặt ra là *"đo ca ấy; client không đổi mã"*, và ca ấy đã đo ở mức API.
  > **Mức nền sau hạng mục:** `flutter test` **2264/2264**, `flutter analyze` **25 issue = 0 error**.

- **Gộp `main` @ `eb071bb` — tài liệu Edge SLM của backend viết về Client-app; client soát bằng mã, tìm ra 6 chỗ lệch + 4 chỗ tự mâu thuẫn → CAN-LAM 21** (2026-09-13, **schema Drift không đổi, không migration, không `build_runner`**; mã client chỉ đổi **hai chú thích**). Merge `04d1352` theo yêu cầu người dùng *"hãy pull từ mới nhất về và kiểm tra"*, không xung đột, **không đụng `src/` nào**: ba commit tài liệu của NPBao — `0e9389d` (`docs/Deploy/CloudDeploy.md`, CI/CD đa nền tảng) và `261be41` + `73e571f` (tệp **mới** `docs/AI/AI_Edge-SLM.md/Client-app.md`, 436 dòng, cộng mục 11.39 `Project.md`). Tệp mới đặc tả **AI điều phối ngân sách on-device** cho Client-app — 3 tầng (thống kê → rule-engine → SLM), **39** luật A–H, 3 bảng SQLite cục bộ — và tự xưng *"Nguồn sự thật"*, nên client soát nó bằng mã thay vì tin tài liệu (nếp từ phiên 5, 6).
  > **Sáu chỗ lệch mã client** (chi tiết + câu thay ở [`CAN-LAM/AI_EDGE_SLM_CLIENT_MISMATCH.md`](superpowers/backend/CAN-LAM/AI_EDGE_SLM_CLIENT_MISMATCH.md)): 🔴 **A3 dùng sai quy ước dấu tiền** — luật định nghĩa hoàn tiền là `amount < 0`, nhưng **SQLite của client lưu `amount` luôn dương**, chiều tiền nằm ở `type`; cả hai đường ghi giữ bất biến ấy (`transaction_repository.dart:106-116` trừ ví bằng `-amount`; `sync_engine.dart:555-561` ghi `.abs()` rồi suy `type`), dấu chỉ áp ở bước đẩy (`sync_payload_normalizer.dart:66-72`). Áp nguyên văn thì luật **không khớp hàng nào — im lặng, không lỗi**. Năm chỗ còn lại: ba cột `is_outlier`/`is_one_time`/`is_recurring_hint` (`grep` **0** chỗ); `saving_goal_ratio` (**0** chỗ — mục tiêu client là **số tiền đích**, nhiều mục tiêu song song); `income` không lưu ở đâu (chỉ cộng tại chỗ ở `home_page.dart:151-156`); mô hình ngân sách rộng hơn giả định (`budgets.categoryId` **nullable** → có ngân sách tổng; kỳ theo `startDate`/`endDate`, không bắt buộc theo tháng; có `isExpired`); và **F2** hứa client "giải mã cục bộ" ghi chú đã mã hoá AES-256 — client gửi/nhận `note` **thô** (`sync_engine.dart:1222`, `:562`), thứ nó thật sự làm là mã hoá **ý nghĩa** (`TRANSACTION_NOTE_ENCODING.md`).
  > **Bốn chỗ tài liệu tự mâu thuẫn** (đếm bằng script): dòng 285 nói *"7 nhóm (A-G)"* nhưng có **8** nhóm A–H (và nhóm H nằm giữa E và F); H4 nói *"2 bảng SQLite"* nhưng Phần IV khai **3** (`local_ai_alert_history` phục vụ B3/B6); `Project.md:2710-2711` thiếu **C7** và **D5**; và `Project.md:2710` **gán nhầm nhãn** — C5/C6 ở đó thực ra là C6/C7 của tài liệu gốc.
  > **Mã client đổi gì:** chỉ **hai chú thích** ở `lib/core/database/tables/transactions_table.dart` — docstring bảng và chú thích cột `amount` vẫn ghi *"Amount giữ dấu ±: dương = tiền vào, âm = tiền ra"*, tức mô tả cột **PostgreSQL** chứ không phải cột Drift. Đây nhiều khả năng chính là **nguồn gốc** của A3: ai đọc bảng Drift để viết luật sẽ viết đúng như tài liệu đang viết. Bằng chứng dấu: **204** ca test dựng giao dịch `amount` dương, **1** ca dùng số âm và ca đó là `budget_repository_test.dart:342` — test *từ chối* hạn mức ngân sách âm, không phải giao dịch.
  > **Không việc nào của 21 chặn client**, và 21 **không xin backend đổi mã** — chỉ sửa chữ. Tính năng Edge SLM chưa được lên lịch làm; nếu làm thì §6.2 của tài liệu 21 là ba câu hỏi phải chốt trước (ngân sách tổng, kỳ không phải tháng, ngân sách hết hạn).
  > **Mức nền sau hạng mục:** `flutter analyze` **25 issue = 0 error** (209 giây) — đúng mức nền.

- **Gộp `main` @ `fcc20b5`** (2026-09-13, **không đổi mã client**). Backend báo **21/21 hoàn tất 100%** và chuyển nốt mục 21 `AI_EDGE_SLM_CLIENT_MISMATCH.md` sang `DA-XONG/` — `CAN-LAM/` nay **chỉ còn `README.md`**, không còn việc nào xin backend. Gộp sạch, không xung đột.
  > ⚠️ Backend **viết lại toàn bộ** `CAN-LAM/README.md` (giảm 134 dòng), nên dòng client chèn vào đó sáng cùng ngày đã mất. Không khôi phục: tệp ấy do backend quản (quy tắc tài liệu chỉ đọc).
  > **Một thay đổi có chạm tới client — đã soát, KHÔNG phải sửa gì:** `admin.service.js` nay cho admin **xoá mềm danh mục hệ thống** (bỏ chốt "không được phép xoá danh mục mặc định"), và tạo lại cùng tên thì **khôi phục** hàng đã xoá thay vì tạo hàng mới. Phía client: `CategoryDao.getBackendDefaults` vốn lọc `isDeleted`/`deletedAt`, nên khuôn bị xoá mềm biến mất khỏi danh sách khuôn — tài khoản **mới** thôi nhận bản sao ấy, tài khoản **đã seed** giữ bản riêng của mình. Và vì luật `DefaultCategorySeeder` đếm **cả hàng đã xoá mềm** của tài khoản, một khuôn sống lại cũng không làm mọc lại bản sao mà người dùng đã xoá — tức **không tái hiện G16**.
  > **Mức nền sau gộp:** `flutter test` **2339/2339**, `flutter analyze` **25 issue / 0 error**.

- **Số dư ví suy từ sổ giao dịch — đóng G37** (2026-09-13, **schema không đổi**, không thêm trường đồng bộ, **không xin backend gì**). Spec: `docs/superpowers/specs/2026-09-13-so-du-vi-suy-tu-so-giao-dich-design.md`. Mười task, mỗi task một commit, test đỏ trước.
  > **Vì sao:** `wallets.balance` là một **giá trị tuyệt đối đồng bộ theo LWW**, và đó là đường **duy nhất** để máy B biết máy A vừa tiêu tiền — nhánh pull giao dịch không hề đụng số dư (đo: 0 dòng). Mất update là **tất yếu** với LWW trên giá trị tích luỹ. Nay nó là **cache của tổng sổ**; vì sổ đã đồng bộ đúng, hai máy cùng tập giao dịch ra cùng một số.
  > **Điểm neo là một GIAO DỊCH** ("Số dư ban đầu"), không phải một cột — vì giao dịch đã đồng bộ sẵn: ví kéo về từ máy khác nhận luôn cả neo, không cần thêm trường nào vào hợp đồng, không cần xin backend. `id` suy **tất định** từ `walletId` (UUID v5) nên hai máy cùng vá thì ra **một** hàng. Nó mang **cặp** dấu hiệu (không danh mục + tiền tố ghi chú) đúng khuôn `laKhoanDieuChinh`, và bị `khoanVaoThongKe()` loại — nó là phép *mở sổ*, không phải thu nhập.
  > **`SoDuViService` là nơi DUY NHẤT ghi `balance`**, thay cả 7 lời gọi `updateBalance` rải rác (bill 2, goal 4, transaction 1); test quét `lib/` thứ **sáu** canh điều đó. **50 chỗ đọc `.balance` không sửa dòng nào** — đó là lý do chọn "cache của một công thức" thay vì "cột tính động".
  > **Nhánh kéo về thôi đọc `balance`** (`Value.absent()`) và **tính lại sau mỗi lần pull**. Hai nửa phải đi cùng: thiếu nửa sau thì nửa đầu làm hỏng đúng thứ nó định sửa. Nhánh **đẩy giữ nguyên**, payload ví vẫn **12 trường** — hợp đồng một chiều, cố ý, để truy vấn PostgreSQL còn đo được.
  > ⚠️ **BA cái bẫy của cùng một sai lầm, cả ba chỉ lộ ra khi chạy thật** — neo tính bằng `balance − Σ sổ` nên **thời điểm** đặt nó quyết định đúng sai: (1) đặt SAU khi ghi sổ thì neo hấp thụ luôn giao dịch vừa ghi — **53 ca test đỏ**; (2) "lưới đỡ" tự đặt neo trong `tinhLaiSoDu` khiến ví số dư 0 nhận 1.000.000 sinh ra một khoản **chi** triệt tiêu đúng khoản ấy; (3) đặt neo cho ví **vừa kéo về** — nó mang `balance = 0` trong khi sổ đã đầy đủ, neo âm bằng cả tổng sổ, ví 2.000.000 hiện `0đ`. Chốt rút ra: **số dư 0 nghĩa là "chưa biết", không phải "ví rỗng"**.
  > **Hai phát hiện khác khi thi công:** ví đích của khoản chuyển phải được **ghi vào hàng** chứ không chỉ truyền qua `destinationWalletId` (bản cũ cộng dồn nên che được; nay thứ gì không nằm trong hàng thì không tồn tại); và `updateTransaction` phải **ghi sổ trước** rồi mới tính lại.
  > **Nghiệm thu hai máy ảo** (tài khoản thử sạch 24, cài mới hoàn toàn): máy A tự trả hoá đơn 2.000.000 → **1.650.000**; máy B nhận `BILL_ALREADY_PAID`, resolver gỡ → **1.650.000**. **Hai máy bằng nhau và bằng tổng sổ** — phép đếm quyết định của G37; trước đó máy thắng giữ 2.000.000 trong khi sổ nó có khoản chi 350.000. Server: hoá đơn `Payed`, đúng **một** khoản chi sống, **một** kỳ kế tiếp.
  > ⚠️ Ví loại **`banking` bị loại khỏi mọi phép tính lại**: server tự ghi số dư ví ngân hàng từ SePay (`workers/bank.worker.js:213`), và số dư ngân hàng thật có thể khác tổng sổ. Hiện 0 ví loại ấy, nhưng không chặn là để sẵn một hồi quy im lặng. *(Cập nhật 2026-09-18: nhóm đã bỏ liên kết ngân hàng, nên client không tạo được ví loại ấy nữa. Phép loại trừ **giữ nguyên** — nó bảo vệ hàng cũ kéo về từ một tài khoản từng liên kết.)*
  > **Mức nền:** `flutter test` **2339/2339**, `flutter analyze` **25 issue / 0 error**.

- **Bước 12 — `Auto_pay` qua đồng bộ, và bốn lỗi im lặng mà nghiệm thu hai máy ảo bắt được** (2026-09-13, **schema không đổi**). Bước cuối của chuỗi hoá đơn. Spec: `docs/superpowers/specs/2026-09-13-auto-pay-dong-bo-design.md`; chi tiết: mục **6.5** và **6.8** `docs/bill/BILL_DOCUMENTATION.md`. Payload hoá đơn **20 → 21 trường**; công tắc tự trả nay là thuộc tính của *hoá đơn* chứ không của *máy*, nên dòng phụ "chỉ nên bật trên một thiết bị" đã bỏ.
  > **Rủi ro đóng bằng BA mảnh khớp nhau, thiếu mảnh nào cũng vô hiệu cả ba:** `auto_pay` đi qua đồng bộ (client) + `chanTraHaiLan` ở `upsertTransaction` (backend, `7779999`) + `BillPaymentConflictResolver` (client) — máy thua một cuộc đua nhận `BILL_ALREADY_PAID` thì tự gỡ khoản trả của chính nó và hoàn tiền.
  > ⚠️ **Task 9 (nghiệm thu hai máy ảo) bắt được BỐN lỗi im lặng mà 2296 ca test đều không thấy** — đây là toàn bộ lý do task ấy tồn tại, và cả bốn đều thuộc loại "không lỗi, không log, chỉ dữ liệu sai":
  > 1. **Vòng lặp tự trả.** `undoPayment` kéo hoá đơn về `Pending` — đúng cho người dùng bấm tay, **sai ở đây**: `BILL_ALREADY_PAID` nghĩa là server ĐÃ có khoản chi. Bộ tự trả tin theo và trả lại ở chu kỳ sau → tạo → bị từ chối → gỡ → hoàn tiền → lặp. Đo **5 vòng trong 3 phút**, ví phình 350.000 mỗi vòng. Sửa: `BillDao.danhDauDaTra` (ghi **cả hai** cột `payStatus` + `isPaid`), gọi **trước** `markSynced`.
  > 2. **Gỡ nhầm khoản chi của máy thắng.** `undoPayment` tự tìm khoản chi bằng `getByBill`, một `LIMIT 1` **không `ORDER BY`** — mà trên máy thua thì *chắc chắn* có hai khoản chi sống cùng `billId` (của nó và của máy thắng, đã pull về từ 2026-09-12). Đo trên PostgreSQL: hoá đơn `d2332790` còn `Payed` nhưng khoản chi **duy nhất** của nó mang `Deleted_at`, và một kỳ kế tiếp bị xoá **17 ms** sau — dấu vân tay của một `db.transaction`. Sửa: `undoPayment` nhận thêm `transactionId`, resolver truyền `localId` server vừa từ chối.
  > 3. **Trạng thái "đã trả" không bao giờ tới server.** Spec §4.3b cho hoá đơn `markSynced` vì sợ máy thua giẫm lên trạng thái đúng, tin rằng "trạng thái thật sẽ đến từ nhánh kéo về". **Đo thật bác bỏ cả hai vế:** server không hề có trạng thái đúng để mà giẫm — bản `Payed` của *máy thắng* cũng bị LWW đánh bại, vì mỗi máy bị pull ghi đè về `Pending` rồi đẩy chính bản cũ hơn ấy lên. Hoá đơn ở lại `Pending` vĩnh viễn và server kết thúc với **ba** kỳ kế tiếp. Sửa: bỏ `markSynced` cho hoá đơn, và `undoPayment` chỉ đòi "đang đã trả" khi nơi gọi **không** truyền `transactionId`.
  > 4. **`SyncEngine` phát kết quả đẩy SAU bước Pull** — đúng **loại lỗi thứ ba** ở mục "Ba loại lỗi `flutter test` KHÔNG bắt được": thứ tự giữa hai luồng bất đồng bộ. Resolver bù lại một thay đổi cục bộ (hoàn tiền), mà Pull ở giữa đã thay số dư ví bằng bản của server → phép bù cộng vào con số **không chứa** lần trừ → ví **2.350.000** thay vì 2.000.000. Sửa: phát `pushResult` ngay sau khi đẩy, trước `_pullFromBackend`; kết quả lần **thử lại** vẫn ở cuối vì chính Pull làm nó đáng thử lại. Ca test quét thứ tự: `test/core/sync/sync_push_result_truoc_pull_test.dart`.
  > **Đo cuối cùng** (hai máy ảo `emulator-5554`/`5556`, tài khoản thử **sạch** mỗi lượt — 19, 20, rồi 21; không xoá cứng gì trên PostgreSQL): hoá đơn trên server **`Payed`**, khoản chi sống mang cùng `Idbill` **đúng một**, kỳ kế tiếp sống **một**, ví cả hai máy **1.650.000 → gỡ → 2.000.000**. Ba lượt đo đi kèm ba lượt sửa — lượt đầu cho `TỔNG 1 | CÒN SỐNG 0`, lượt hai cho hai kỳ trùng và ví 2.350.000.
  > ⚠️ **Còn G37**, không thuộc tầng hoá đơn: máy **thắng** giữ khoản chi hợp lệ mà ví lại là con số của server, vốn **không** trừ khoản chi ấy — `wallets.balance` là cột LWW thuần và server không tính lại từ giao dịch. Mọi thay đổi số dư cục bộ thua một lần xung đột đều biến mất như vậy. Người dùng chốt **ghi tài liệu, không sửa trong phiên này**; đối soát tạm bằng ô số dư ở màn Sửa ví.
  > **Mức nền:** `flutter test` **2305/2305**, `flutter analyze` **25 issue / 0 error**.

- **Gộp `main` @ `7779999` — backend đóng CAN-LAM 20; client soát bằng mã, log, CSDL và `/sync/push` thật** (2026-09-12 tối muộn, **schema Drift không đổi; `schema.prisma` không đổi; không tệp `database/` mới** → không `build_runner`, không `prisma generate`, không áp migration). Merge `e9b5aef` theo yêu cầu người dùng *"hãy lấy code mới nhất về"*, không xung đột; `main` đã gộp nhánh này tới `7af978f` nên chỉ **ba** commit mới, đều của NPBao: `e885b90` (mã backend + tài liệu backend), `bc31717` và `7779999` (`docs/Deploy/CloudDeploy.md`, `Project.md` — chỉ thị giữ development mode ở mọi môi trường). Backend dev trên máy chạy nodemon, nạp lại lúc 22:07:05.
  > **Kết luận soát mục 20** (bảng ở banner ✅ `CAN-LAM/README.md`): **2.1 ✅ đo thật** — `chanTraHaiLan` ở `sync.repository.js:296-312`, `dangXoaTrongLo` ở `sync.service.js:75-81`; script `scratchpad/do_canlam20.js` chạy từ `src/Backend`, tài khoản thử **14** `kiemthu_cl20_mtyj1fqh` (tạo qua `/auth/register` — route này **không cần OTP**), ví thử `75074718…`, hoá đơn `0f3cabeb…`: **C1** `Payed` rồi `Pending` cả hai `synced`, CSDL `Pending`; **C2** khoản chi `2aabe7c8…` `synced`, lô sau `f5f184a6…` → `error` `BILL_ALREADY_PAID` *"Hóa đơn đã được thanh toán bằng một giao dịch khác"*, đếm hàng sống = 1; **C3** xoá `2aabe7c8…` + tạo `1fe29699…` **cùng lô** → cả hai `synced`, đếm = 1; **C4** sửa `1fe29699…` → `synced`, đếm = 1. Dọn bằng thao tác `delete` qua `/sync/push` — xoá **mềm** (đếm = 0, `bill.Delete_at` có giá trị). **2.2 ✅ chạy thật ở dev**: log in `[SECURITY] BLIND_INDEX_SECRET chưa đặt — dùng secret mặc định CHỈ cho môi trường dev/test` (`.env` dev không có biến ấy, `NODE_ENV=development`). **2.3 ✅ mã**: `ocr.controller.js:22` và `classify.controller.js` đòi `ALLOW_MOCK_INPUT === 'true'`. **2.4 ✅**: `grep 'ORC'` trên `src/Backend` (trừ `node_modules`) = **0**. **2.5 ⚪ không kiểm được**: `Test/test_con_lai_fixes.js` bị `.gitignore:77` chặn, thư mục không có trên máy — chỉ có lời báo PASS 5/5. **2.6 ⚪** ngoài phạm vi. **2.7 ✅ mã · ⚠️ nửa đo**: `auth.service.js:383-395` gọi `getAccountValidity(storedToken.idaccount)` ở nhánh token thu hồi, bỏ qua `SCHEMA_ERROR`, ném 401 kèm `rejection.data`; đo với tài khoản 14 còn `Active`: `/auth/logout` rồi `/auth/refresh` bằng token cũ → 401 *"Refresh token khong hop le"* không mã — đúng; **ca `Inactive`/`Deleted` chưa đo** (cần API admin, mật khẩu admin không ghi ở đâu). **3 ✅**: sổ ghi migration 5–13 ở `Rule_project.md` §3.2 kèm cảnh báo partial index; kiểm 5 (không còn trigger trên `category`), 6 (`category_group_membership` 0 hàng), 13 (`budget.Threshold_Warning_Percent` default `NULL`) bằng chính câu kiểm của sổ. **4 ✅ 8/8**: `New_Database.md:172` nay ghi `chk_wallet_status`, `:258`/`:397` "không có FK"; `Rule_project.md` "đến migration **13**"; `Backend.md` hết `ORC`, `sync.completed` "sau mỗi `/sync/push`", "19 tài liệu", mục 10 nói rõ `Test/` không nằm trong repo.
  > **Hệ quả cho client:** **bước 12 (`Auto_pay` qua đồng bộ) không còn bị chặn** — việc phía client, gồm gửi/đọc `auto_pay` **và** hoàn tác khoản trả cục bộ khi nhận `BILL_ALREADY_PAID` (§5 tài liệu 20). ✅ **Làm xong 2026-09-13** — xem khối "Bước 12" ở trên. **G36** chuyển từ ⏸️ chờ backend sang ⚠️ chờ đo đầu-cuối ca khoá/xoá; client không đổi mã. Tài liệu khớp theo cùng lượt: CLAUDE.md (bốn hàng), `CLIENT_APP_KNOWN_GAPS.md`, `BILL_DOCUMENTATION.md`, `SYNC_DOCUMENTATION.md`, hai README backend, bốn spec, chú thích `sync_payload_contract_test.dart`.
  > **Ba bẫy khi đo bằng HTTP thẳng** (không phải lỗi, nhưng đo lại sẽ vấp): body `/sync/push` **bắt buộc** `clientId` và `pushedAt` (thiếu là 400 `Validation failed` — client thật gửi kèm); `/sync/pull` trả dữ liệu ở `data.data.{wallets,…}` chứ không `data.wallets`; và **server không seed ví** cho tài khoản mới — hai ví khởi tạo là của client, nên tài khoản thử tạo qua API phải đẩy ví trước hoá đơn. Một bẫy môi trường: `.env.example` nay `NODE_ENV=production`, mà production thiếu `BLIND_INDEX_SECRET` là **từ chối khởi động** — máy mới dựng từ tệp mẫu sẽ crash.
  > **Dữ liệu thử để lại trên server** (không xoá cứng — quy tắc 5): tài khoản 14 `Active`, một ví `Vi kiem thu CL20`, hoá đơn và khoản chi đã xoá mềm. Tài khoản 12 (`Deleted`) và 13 (`Active`, đang đăng nhập trên máy ảo) giữ nguyên.
  > **Mức nền:** chỉ sửa chú thích test và tài liệu — `flutter test` và `flutter analyze` chạy lại sau lượt sửa, ghi ở dòng lệnh CLAUDE.md nếu con số đổi.

- **Ân hạn hoá đơn — kỳ tính tiền tách khỏi hạn trả (`Period_end`)** (2026-09-12 tối, **schema v20 → v21**, lối 4 — bước cuối trong bốn lối người dùng duyệt chiều cùng ngày). Đi đủ đường brainstorming → spec (`docs/superpowers/specs/2026-09-12-bill-an-han-period-end-design.md`, duyệt "ok duyệt" hai lần) → kế hoạch 13 task (`plans/`, gitignore) → thực thi **inline** (người dùng chọn vì agent con quá lâu), mỗi task test đỏ trước, một commit: `18db941` schema v21, `592366b` `bill_an_han.dart`, `ce5032a` `BillSchedule`, `6aba90f` `BillDraft`, `72551da` `_nextPeriodOf`, `d9402b0` đồng bộ, `75cfdab` `BoChonAnHan`, `d878932` form Thêm, `3ee94c3` form Sửa, `aa2a6fc` chi tiết + sheet.
  > **Cách nhập người dùng chốt:** số ngày sau khi kết thúc kỳ (`0 · 7 · 15 · 30 · Khác`), mặc định 0; ngày kết thúc kỳ và hạn thanh toán đều tự tính, chỉ đọc. Đối chiếu thị trường: Money Lover/TimelyBills/Copilot chỉ có một mốc "đến hạn", PocketSmith có *grace period* theo nghĩa khác — FlowMoney đi trước ở chỗ này nên mặc định phải là "như cũ".
  > **Mô hình:** cột `Bills.periodEnd` nullable, đồng bộ khoá `period_end` (payload hoá đơn **20** trường lúc ấy — **21** từ 2026-09-13 sau `auto_pay`, đếm bằng script); ân hạn **không lưu**, suy `dueDate − periodEnd` theo ngày lịch ở đúng một chỗ `domain/bill_an_han.dart` (`anHanCua`, `hanTraTu`, `loiAnHan` — không âm, ≤ 365, hạn trả phải **trước** kết thúc kỳ kế tiếp để không có hai kỳ cùng mở; tuần vì thế tối đa 6). `BillSchedule.ketThucKy` là `dueDate` cũ; `dueDate = hanTraTu(ketThucKy, anHanNgay)`; ân hạn 0 **y hệt** trước v21 — có test canh riêng. `_nextPeriodOf` (chung cho trả và bỏ qua kỳ) nối kỳ sau từ `periodEnd ?? dueDate` và giữ nguyên ân hạn — chính là chỗ bẫy §4.4 tài liệu xin backend cảnh báo. **`NULL` chỉ một nghĩa** (hàng cũ, ân hạn 0): mọi đường ghi mới luôn ghi `periodEnd` kể cả khi bằng `dueDate`, nên nhánh kéo về dùng `Value.absent()` an toàn như `anchor_day`. Quá hạn, nhắc trước hạn, tự động thanh toán, khoá chống trả hai lần **vẫn neo `dueDate`** — không đổi.
  > **Giao diện:** Stitch sửa trước, cả ba màn đã áp (mỗi lượt `edit_screens` **một** màn — hai lượt gộp hai màn đều timeout và không áp): "Thêm Hóa Đơn Định Kỳ" `9d1e6a25…` đổi khối ngày thành bốn phần (bắt đầu → kết thúc kỳ 🔒 → thanh ân hạn 5 ô → hạn thanh toán 🔒 + chú thích; ⚠️ màn này trước đó **thiếu** ô ngày bắt đầu dù app có từ 06/09 — nay khớp); "Chỉnh sửa Hóa đơn" `3157fd8b…` cùng khối với ô "Khác" đang chọn và ô số "20"; "Chi tiết hóa đơn - Mobile" `b4aaff9b…` thêm dòng "Kỳ" trên "Đến hạn". Flutter: `BoChonAnHan` (`presentation/widgets/bill_grace_selector.dart`) dùng chung hai form, key `bill-grace-<n>`/`bill-grace-null`/`bill-grace-custom`/`bill-grace-error`; form Thêm đổi nhãn ô khoá cũ thành "NGÀY KẾT THÚC KỲ", thêm thanh và ô "HẠN THANH TOÁN" khoá (key `bill-period-end-text`, `bill-due-date-text`); form Sửa cùng khối; trang chi tiết thêm dòng "Kỳ dd/MM/yyyy → dd/MM/yyyy" trên "Đến hạn"; sheet thanh toán dòng "Kỳ" đổi mốc phải sang `periodEnd ?? dueDate`. Một ca cũ đổi: "đổi chu kỳ thì hạn tính lại" nay đếm **hai** ô ngày (trùng nhau khi ân hạn 0 — cố ý hiện đủ hai ô để bố cục không nhảy).
  > **Hai điều phát hiện khi làm:** (a) Drift ghi `DateTime` theo **giây** Unix — fixture migration chèn mili-giây đọc ra năm 58687; (b) fixture `wallet_schema_v20_test` chỉ có bảng `wallets` nên migration v21 `ALTER TABLE bills` làm nó vỡ — thêm bảng `bills` v19 vào fixture, cùng lý do các fixture cũ dựng `wallets`/`goals`. Một điểm khác spec: `BillDraft.periodEnd` là tham số **tuỳ chọn** với `periodEndHieuLuc` (test cũ khỏi đổi) nhưng giá trị ghi xuống **không bao giờ vắng** — spec §4.3 đã sửa theo.
  > **Kiểm đầu-cuối trên máy ảo + PostgreSQL (chỉ đọc), 21:38–21:48, tài khoản thử 13:** tạo `Anhan15` 5.000đ, chu kỳ tháng, chạm ô **15** → form ở 411dp hiện ba ô đúng, không sọc tràn, hạn tự tính 12/10 + 15 = **27/10**; đẩy 1/1; hàng server `Period_end = 2026-10-12`, `Due_date = 2026-10-27T14:38:52Z`, `Anchor_day = 12`. Sheet thanh toán "Kỳ 12/09 → 12/10, Đến hạn 27/10". **Trả** → kỳ sau trên server `Start_date 12/10`, `Period_end 12/11`, `Due_date 27/11` (giữ đúng 15 ngày), kỳ cũ `Payed`; trang chi tiết kỳ mới "Kỳ 12/10 → 12/11 · Đến hạn 27/11", lịch sử hai kỳ. **Kéo về máy khác** (xoá ba tệp `app_flutter/flowmoney.db*` — ⚠️ không phải `databases/`, rồi mở lại): full pull 2 hoá đơn; SQLite kéo về máy chủ và đọc bằng Python: cả hai hàng có `period_end` (12/10, 12/11) và hàng sau có `generated_from_bill_id`; form Sửa mở ra ô **15** đang chọn, không cảnh báo. **Một lỗi bắt được nhờ đo:** client gửi `period_end` là `toUtc()` thô của giờ tạo (`…T14:38:52Z`) trong khi cột là `@db.Date` — tạo trước **07:00** giờ +07 thì UTC là hôm trước và server lưu **lùi một ngày**, im lặng (spec §5 đã cảnh báo). Sửa `e4b168a`: gửi nửa đêm UTC của **ngày cục bộ** (`_ngayCucBoUtcIso`), test hợp đồng gieo 03:00 giờ máy; `Start_date`/`Due_date` là `@db.Timestamp` nên không bị. APK trên máy ảo đã cài bản có sửa. Ba ví thử và hai hoá đơn thử của tài khoản 13 để nguyên (quy tắc 5).

- **Nghe `sync.completed` — đóng G34** (2026-09-12 tối, **schema không đổi**, lối 3 trong bốn lối người dùng duyệt chiều cùng ngày). Backend phát sự kiện này tới phòng `account_<id>` sau mỗi `/sync/push` từ 2026-09-11, kênh nối được từ sáng 2026-09-12, nhưng `realtime_event.dart` chỉ dịch ba tên nên `RealtimeChannel._khiCoSuKien` bỏ qua — thay đổi từ máy khác chờ chu kỳ 15 phút. Nay `RealtimeEvent.dongBoXong` ↔ `sync.completed`, `canDongBoLai = true`, đi đúng đường cũ `noiRealtimeVaoDongBo` → `SyncEngine.syncNow()` (không đổi hai lớp ấy).
  > **Im lặng, không toast — và vì sao đó không phải chuyện thẩm mỹ:** máy vừa đẩy cũng nằm trong phòng ấy nên nhận lại chính sự kiện của mình, mà payload là hộp đen (spec socket §4) nên không phân biệt được máy gửi; toast "máy khác vừa đổi dữ liệu" sẽ hiện **sai** trên đúng máy vừa ghi, sau mỗi lần ghi. Kết quả đồng bộ đã có dải riêng ở bậc cao nhất (§6.3). Cơ chế: `loiNhan` đổi kiểu `String?`, **`null` là định nghĩa duy nhất của "sự kiện im lặng"**; `AppToast._khiCoRealtime` chỉ đọc getter ấy. Test canh cả hai chiều: `realtime_event_test` (bốn tên, `dongBoXong.loiNhan` là `null`, sự kiện có toast thì chữ không rỗng và không số), `realtime_channel_test` (payload thật `{summary, timestamp}` vẫn không được đọc), `realtime_wakeup_test` (đánh thức), `app_toast_test` (không icon = không toast). **2 ca mới**, toàn bộ **2218/2218**.
  > **Kiểm máy ảo hai máy cùng tài khoản** — tài khoản thử **13** `kiemthu_g34` (đăng ký qua OTP mock đọc từ log backend; mật khẩu không ghi vào tài liệu), máy A là máy ảo, máy B là `POST /api/sync/push` bằng token thật (script Python, payload ví 12 trường đúng hợp đồng). Ba lần đẩy một ví 12.345đ: cả ba lần log backend ghi `[Socket] Emitted sync.completed to room account_13` và audit `Tải dữ liệu đồng bộ (Pull)` của máy A **trong cùng giây** (20:20:03, 20:25:16, 20:25:50); logcat máy A `Starting full sync … Pulled & Saved 1 wallets`; Trang chủ đổi 24.690đ → 37.035đ mà không chạm màn hình; ảnh chụp 2 giây sau lần đẩy thứ ba **không có toast**. Máy ảo tự tắt một lần giữa chừng (sau lần đẩy đầu, không rõ vì sao) — khởi động lại, phiên tài khoản 13 còn nguyên, đo lại hai lần.
  > **Biết mà chưa xử lý** (có sẵn từ trước cho mọi sự kiện realtime, không mở G): sự kiện tới đúng lúc `_runSync` của máy nhận đang chạy dở thì `syncNow()` bị bỏ qua không log (`_status == syncing`); nếu lượt pull ấy đã đi qua trước khi máy kia ghi xong thì thay đổi chờ kích hoạt kế tiếp — cửa sổ vài trăm mili-giây. Máy vừa đẩy nhận lại sự kiện của mình thường rơi đúng cửa sổ đó nên bị bỏ qua miễn phí; không thì thêm một chu kỳ chỉ kéo về, không đẩy lại.

- **Kiểm hai nhánh còn nợ của cưỡng chế đăng xuất — socket và làm mới** (2026-09-12 chiều, **không đổi mã**, chỉ hai chú thích; lối 2 trong bốn lối người dùng duyệt). Điều kiện đã có từ trưa: 17 A đóng, kênh nối. Người dùng cho phép đích danh và đưa mật khẩu `quangdat` + `admin` trong chat (không ghi vào tệp nào; diff đã quét trước khi push). ⚠️ **Phát hiện khi chuẩn bị:** cách tôi đề xuất lúc đầu — `UPDATE account SET "Status"='Inactive'` thẳng vào CSDL như đã làm cho nhánh HTTP buổi sáng — **không kiểm được nhánh socket**, vì `account.force_logout` chỉ phát từ mã backend (`admin.service.js:139-140` khi khoá, `:198-199` khi xoá, `scheduler.service.js:115` khi hết hạn chờ xoá); phải đi qua `PATCH /api/admin/updatestatus/:iduser` (`Iduser` 11 = tài khoản 11) với token admin. **Kết quả** (chi tiết ở khối ✅ đầu §7.3 spec): socket — sự kiện tới máy ảo lúc 16:30:40.687, **trước** khi API khoá trả lời, hộp thoại đúng câu server, SQLite giữ nguyên, lần "nối lại sau 2s" không bao giờ chạy vì `stop()` huỷ hẹn trước; làm mới — `/auth/refresh` **200** kèm token mới khi hợp lệ, **401 + `code: ACCOUNT_INACTIVE` + `reason_inactive` ở cấp gốc** khi bị khoá (`/auth/profile` cùng hình dạng); CAN-LAM 19 — đăng nhập không còn `pendingDeleteCancelled`, `/auth/profile` có `countdown`. Tài khoản trả về `Active`, lý do `NULL`; máy ảo đăng nhập lại `quangdat` (đường đăng nhập cũng đúng một `Starting full sync`).
  > ✅ **Đo nốt chiều muộn** (người dùng cho phép đích danh hạ `JWT_USER_ACCESS_EXPIRES=1m` — trả lại `7d` ngay sau — và tạo tài khoản thử `kiemthu_xoa` = 12 qua OTP mock đọc từ log backend): **interceptor tự làm mới** chạy thật — token 1 phút hết hạn, kéo → `/auth/refresh` → server xoay token (bảng `refreshtoken`), app vẫn ở Trang chủ. **Ca đã xoá** cho kết quả bất ngờ: xoá qua admin **thu hồi cả 5 refresh token**, nên `/auth/refresh` trả 401 **không mã** (kiểm token trước tài khoản, `auth.service.js:375-387`) — đường `lamMoi` + `daXoa` **không xảy ra được**; app giữ token hết hạn mà không có socket sẽ đăng xuất trơn không hộp thoại → **G36**, xin backend CAN-LAM 20 §2.7. Trên máy ảo, đường **socket** `daXoa` chạy đúng: hộp thoại "Tài khoản đã bị xoá", SQLite dọn (`Wallets count: 0`). ⚠️ Bẫy môi trường: máy ảo có dữ liệu di động, `svc wifi disable` **không cắt mạng** — cần `svc data disable` cùng lúc. **Vẫn giữ ngoại lệ `lamMoi`** (vô hại; chỉ còn che ca lỗi lược đồ và xoá theo lịch, đều chưa đo); nửa sau §3.8 (*mất mạng giữa 401 và làm mới*) không dựng được trên máy ảo. Chi tiết: khối ✅ thứ hai đầu §7.3 spec.

- **Gỡ `SyncEngine.start()` khỏi `HomePage.build()`** (2026-09-12, **schema không đổi**, lối 1 trong bốn lối người dùng duyệt sau lượt gộp `main`). Lỗi có sẵn, ghi trong bàn giao từ phiên trước: `home_page.dart:36` gọi `start()` ngay trong `build()`, mà `start()` không luỹ đẳng — nó `_resetBackoff()`, huỷ rồi dựng lại bộ nghe kết nối và timer 15 phút, và chạy `syncNow()`. Mỗi lần Trang chủ dựng lại (mỗi `AuthSuccess` re-emit — ví dụ sau `/auth/profile` đổi trạng thái — và mỗi lần quay về tab) là một chu kỳ đồng bộ thừa và bản ghi kẹt lỗi vĩnh viễn được gửi lại ngay thay vì chờ hết giãn cách. **Nguyên nhân gốc:** bản trùng — `AuthBloc` đã `start()` đúng một lần ở cả hai đường vào phiên (`_onAuthCheckRequested`, đăng nhập), đối xứng với `stop()` ở `_dungMoiThuCuaPhien`; chú thích ở `auth_bloc.dart` còn cảnh báo đúng chỗ ấy từ trước, nhưng không có gì đỏ khi gọi thừa. **Sửa:** bỏ bốn dòng, giữ phép đọc `currentUserId`. **Test đỏ trước:** `test/core/sync/sync_engine_start_owner_test.dart` — test quét `lib/` thứ **tư** — chỉ `auth_bloc.dart` được gọi `.start(idaccount:)` (bắt theo tham số đặt tên, nên gom cả `RealtimeChannel`; bỏ qua dòng chú thích). Bẫy 7.6 `NOTIFICATION_FEATURE.md` đóng; câu cũ "SyncEngine chịu được vì start() gần như luỹ đẳng" ở đó là **sai** và đã sửa. **Kiểm trên máy ảo `emulator-5554`** (APK bản này, mở lạnh): đúng **một** dòng `[SyncEngine] Starting full sync` lúc 16:11:35, phát từ `AuthBloc` (sau `NotificationScanner`, trước `RealtimeChannel` — đúng thứ tự `_onAuthCheckRequested`); xoay màn hình hai chiều để ép Trang chủ dựng lại → **0** dòng mới, không màn đỏ. **Mức nền:** `flutter test` **2216/2216** (3 phút 36 giây song song build APK), `flutter analyze` **25 issue / 0 error**.

- **Gộp `main` @ `cbbeeb4`, soát lời báo 19/19 của backend, áp `database/13`, và client đọc `countdown` từ `/auth/profile`** (2026-09-12, **schema Drift không đổi**). Bốn commit: `3bdac75` (gộp — người dùng yêu cầu đích danh *"hãy pull từ nhánh main về"*; một xung đột ở `CAN-LAM/README.md`, giữ nguyên văn khối 🎉 của backend như lần `de91bde`), `defdec7` (soát), `ab3a750` (80 dòng spec dở từ phiên trước), và commit của hạng mục này. **Kết luận soát** (bảng đầy đủ ở banner `CAN-LAM/README.md`): **17 A ✅ đã chạy thật** — máy ảo `emulator-5554` sau **51** lần bị từ chối liên tiếp thì `[RealtimeChannel] Đã nối (idaccount=11)` lúc 15:01:46, đúng lúc nodemon nạp mã gộp; **17 B một nửa** — chốt nhầm ở `upsertBill` đã bỏ (hoá đơn `3c90acfa…` kẹt 7 lần đẩy lên server `Payed → Pending` lúc 15:10:21), nhưng chốt xin đặt ở `upsertTransaction` **chưa có** nên server nay **không chặn khoản chi thứ hai cùng `Idbill` ở đâu cả**; **19 ✅**; mục 18 còn năm việc mã và tám chỗ tài liệu (hai lỗi mới: `New_Database.md` nói ví không có CHECK `Status`, và `goal` có FK `auto_deposit_wallet_id`). Ngoài phạm vi: `admin.service.js` `deleteCategory` ném lỗi ở mọi nhánh.
  > **Áp `database/13`** theo yêu cầu đích danh *"hãy cập nhật csdl lên bảng mới nhất"*: một `ALTER … DROP DEFAULT` và hai `CREATE UNIQUE INDEX IF NOT EXISTS` (đã có sẵn từ 2026-09-01). Chạy bằng `pg` từ `src/Backend`, một giao tác: `budget."Threshold_Warning_Percent"` `column_default` `0 → null`, ba index ví nguyên, 6 hàng ngân sách không đổi. `schema.prisma` không đổi trong lần gộp nên **không** cần `prisma generate`.
  > **Mã client — một việc thật:** `AuthRepositoryImpl._dongBoTrangThai` nay nhận cả `profile` và, khi server báo `PendingDelete` kèm `countdown` là số, ghi lại **số và mốc nhận kể cả khi trạng thái khớp** — đúng việc client hứa ở CAN-LAM 19 §2.4 (máy giữ phiên từ trước khi máy khác gửi yêu cầu xoá; bộ nhớ đệm bản client cũ thiếu mốc; số cũ của một lần chờ xoá trước). Server không trả hoặc trả rác → hành vi cũ. **4** ca test mới (một ca cũ đổi tên) ở `auth_repository_cho_xoa_test.dart` — đỏ trước, 15/15 xanh sau. **Mức nền sau hạng mục:** `flutter test` **2215/2215** (4 phút 16 giây, chạy song song `analyze`), `flutter analyze` **25 issue / 0 error**. Sáu chú thích trong `lib/` nói 17 A/B chưa xong đã sửa; `build_runner` sinh lại `.g.dart` chỉ đổi chú thích.
  > **Cố ý giữ** ngoại lệ `lamMoi` ở §3.6b (không dọn SQLite khi `daXoa` đến từ nhánh làm mới): backend đã tách 503 ở `/auth/refresh` **trong mã**, và chiều cùng ngày nhánh ấy **đã đo** (200 hợp lệ; 401 + `ACCOUNT_INACTIVE` khi khoá); còn ca `daXoa` qua nhánh này và ca `SCHEMA_ERROR` chưa đo — gỡ ngoại lệ là quyết định của người dùng. `/auth/refresh` và `/auth/profile` với token thật cũng đã đo chiều cùng ngày — khối "Kiểm hai nhánh còn nợ của cưỡng chế đăng xuất" ở trên.
  > **Mở khoá:** bước 10 (gộp) xong; bước 11 (G34, nghe `sync.completed`) **làm được ngay** vì kênh đã nối (✅ xong tối cùng ngày — khối "Nghe `sync.completed`" dưới); hai nhánh còn nợ kiểm máy ảo của cưỡng chế đăng xuất (socket, làm mới) nay dựng được. **Vẫn chờ:** bước 12 `Auto_pay` — chốt chống trả hai lần chưa có ở đâu (17 B bước 2; ✅ có từ `7779999` tối muộn cùng ngày). Phần backend còn lại viết thành **CAN-LAM 20** `CON_LAI_SAU_CBBEEB4.md` cùng ngày (theo yêu cầu người dùng): một chốt, bốn việc mã nhỏ, sổ ghi migration 5–13, tám câu tài liệu kèm câu thay.

- **Phần 1 cưỡng chế đăng xuất — §3.1–§3.7 và §5.1** (2026-09-12, **schema không đổi**). Bảy commit `693de3b` → `fc82a94` trên `TranQuangDat`, một task một commit, mỗi task viết test đỏ trước. Khi server nói "tài khoản này không dùng được nữa", app nay đăng xuất **có lý do** thay vì im lặng. Kiểu chung `ThongBaoBuocDangXuat` ở **`lib/core/auth/buoc_dang_xuat.dart`** (Dart thuần) gom **ba** nguồn — sự kiện socket `account.force_logout`, body 401 của một request thường, body 401 của `/auth/refresh` — về **một** event `TaiKhoanBiBuocDangXuat` của `AuthBloc` (Hướng A, spec mục 2 Q5). Bloc dừng ba thành phần của phiên qua `_dungMoiThuCuaPhien()` (chuỗi này đang được **chép ở hai handler**, đây là lần thứ ba nên gom về một chỗ), dọn SQLite **có điều kiện**, gọi `AuthRepository.xoaPhienTrenMay()` — đường mới, **không** gọi `/auth/logout` vì route ấy đi qua `authenticate` và sẽ 401 quay vòng — rồi phát `AuthUnauthenticated(thongBao: …)`. Màn Đăng nhập dựng hộp thoại theo màn Stitch `97dd48e7…`: vòng tròn 56px nền `#FFDAD6`, `block` / `delete_forever`, tiêu đề theo lý do, một nút **Đã hiểu**, bấm ra ngoài không đóng được.
  > **Sáu chốt, tất cả đều hỏng IM LẶNG nếu phá.** (1) **Mọi giá trị lạ, thiếu, sai kiểu đều đọc thành `biKhoa`** — đọc nhầm "đã xoá" thành "bị khoá" chỉ giữ lại dữ liệu, đọc nhầm chiều ngược lại là **xoá mất** dữ liệu người dùng. (2) **Chỉ đọc `code` khi `statusCode == 401`** — `/auth/refresh` còn trả **400**, và body 400 của repo cũng mang `code` ở cấp gốc (`VALIDATION_ERROR`), nên đọc nó là hiện hộp thoại "Tài khoản đã bị vô hiệu hoá" cho một lỗi nhập liệu; 401 "Token expired" thật thì **không** có `code` (đo lại `middleware/auth.js:60-111` ngày 2026-09-12) nên vẫn đi đường làm mới token như cũ. (3) **Dọn SQLite chỉ khi `daXoa` VÀ nguồn khác `lamMoi`** (§3.6b): ở nhánh làm mới, lỗi lược đồ phía server còn đội lốt được `ACCOUNT_DELETED` (CAN-LAM 17 §2.5) — bỏ ngoại lệ khi backend sửa xong. (4) **Chặn thông báo thứ hai bằng CỜ chứ không bằng `state`** — state chỉ đổi ở bước cuối mà handler của Bloc chạy đồng thời, nên lần nhận thứ hai vẫn thấy `AuthSuccess`; cờ được **thả** ở `_onLoginSubmitted`, thiếu chỗ ấy thì lần bị đẩy ra thứ hai trong cùng một lần chạy app im lặng. (5) **Xoá token KHÔNG phát `sessionExpiredStream`** khi 401 mang mã — server thu hồi refresh token trước khi trả mã, và một lượt đăng xuất trơn chạy đua với hộp thoại thì người dùng chỉ thấy màn Đăng nhập trống. (6) ⚠️ **Hai chốt quanh cuộc đua với `_onAuthCheckRequested`** — chốt state ở đầu handler phải nhận cả `AuthUnauthenticated`, **và** mọi lượt phát `AuthUnauthenticated` của các đường *phiên chết* phải mang theo lý do đã nhớ. Thiếu một trong hai là mất hộp thoại; thêm 2026-09-12 sau khi kiểm máy ảo, xem gạch dưới.
  > **Ba thứ tìm ra khi làm, không có trong spec — cái thứ ba chỉ lộ ra trên máy thật.** (a) **`BlocListener` ở màn Đăng nhập là không đủ**: `AppRouter` refresh theo `authBloc.stream` (`app_router.dart:89`), nên thứ tự thật là *emit → router chuyển về `/login` → trang mới được dựng* — lần đổi state mang `thongBao` đã trôi qua trước khi listener kịp đăng ký. Trang phải đọc **thêm** state sẵn có ở `initState` (sau khung hình đầu tiên), cộng một cờ chặn hiện hai lần. (b) **Hộp thoại tràn 158px ở 411dp** khi `loiNhan` dài — câu ấy do admin gõ (`admin.service.js:140` nối thẳng `reason_inactive` vào), client không kiểm được độ dài; tràn thì nút "Đã hiểu" ra ngoài màn hình mà `barrierDismissible` lại `false`, tức **không đóng nổi**. Phần thân nay cuộn được, nút nằm ngoài vùng cuộn. Bắt được nhờ ca test dựng trong `SizedBox(width: 411)` + `tester.takeException()`. (c) ⚠️ **Lời từ chối tới SAU khi phiên đã chết thì bị nuốt mất** — đo trên `emulator-5554` ngày 2026-09-12 với tài khoản 11 bị khoá thật: app đăng xuất đúng nhưng **không có hộp thoại nào**, tức người dùng bị đá ra mà không biết vì sao, trong khi **cả 63 ca test đều xanh**. `verifySession()` xếp chính cái 401 mang mã ấy là phiên chết, nên `_onAuthCheckRequested` phát `AuthUnauthenticated()` **trơn** trước; lời từ chối của interceptor tới sau một nhịp và bị chốt `state is! AuthSuccess && state is! AuthChecking` chặn từ đầu. Hai handler chạy đồng thời nên thứ tự **không đoán được** — spec §3.5 đoán một chiều, máy thật rơi vào chiều kia. Chốt nay nhận cả `AuthUnauthenticated`, chỉ bỏ qua `AuthInitial`, `AuthLoading` (một lượt đăng nhập **mới** đang chạy), `AuthError` và luồng đăng ký; có test cho **cả hai** chiều (`ac08ed6`). ⚠️ **Bản sửa ấy một mình KHÔNG đủ** — kiểm lại trên máy vẫn không có hộp thoại. Nguyên nhân thứ hai nằm ở **đường ra**: `verifySession()` xếp chính cái 401 ấy là phiên chết nên `_onAuthCheckRequested` **cũng** đăng xuất, và vì nó gọi `logout()` qua **mạng** nên về **sau** handler (chỉ đụng bộ nhớ và kho token) — lượt phát trơn về sau đè mất lý do, mà màn Đăng nhập đọc state ở `initState`. Lý do nay nhớ ở `_thongBaoBuocDangXuat` (đặt trước mọi `await` của handler) và **năm** chỗ phát `AuthUnauthenticated` của các đường phiên chết đi qua `_phatChuaDangNhap(emit)`; chỗ thứ sáu — `_onLogoutRequested`, người dùng tự bấm Đăng xuất — giữ bản trơn vì ở đó không có gì để giải thích. Cờ và lý do cùng thả ở `_onLoginSubmitted` (`40a553d`). Đây đúng là **loại lỗi thứ ba** mà `flutter test` không bắt được, và nó **hai lần** đội lốt cùng một triệu chứng.
  > **Lệch spec một chỗ, người dùng duyệt trước khi làm:** `tuSuKienSocket` trả kiểu **không** nullable (§3.1 ghi nullable). Sự kiện ấy tự nó đã là lời đẩy người dùng ra; trả `null` cho payload dị dạng là bỏ qua nó và để người dùng ngồi lại trong app. `tuBody401` **giữ** nullable — ở đó `null` có nghĩa thật.
  > **Test:** **66** ca mới (đếm bằng máy 2026-09-12, sau **hai** lượt sửa ở gạch (c)) — `buoc_dang_xuat_test` 19, `realtime_buoc_dang_xuat_test` 7, `auth_interceptor_buoc_dang_xuat_test` 9, `purge_data_for_account_test` 4, `xoa_phien_tren_may_test` 3, `auth_bloc_buoc_dang_xuat_test` **13**, `hop_thoai_bi_day_ra_test` 11. `flutter test` **2171/2171**, `flutter analyze` **25** issue — mức nền, 0 error. Mốc 63 ca / 2168 là trước hai lượt sửa ấy.
  > ✅ **Kiểm trên máy ảo — xong 2026-09-12.** Nhánh **HTTP 401 chạy đầu-cuối** (khoá tài khoản 11 trên CSDL dev rồi trả lại `Active` ngay sau đó; người dùng yêu cầu đích danh việc khoá): hộp thoại hiện đúng tiêu đề, thân là **câu server gửi kèm lý do admin gõ**, nút "Đã hiểu", **không sọc tràn** ở 411dp; kéo `flowmoney.db` ra đếm thì SQLite **giữ nguyên 2 ví và 18 danh mục** của tài khoản 11 — đúng luật "bị khoá thì giữ". Chính lượt kiểm ấy tìm ra **hai** lỗi ở gạch (c). Đo thêm: body 401 của HTTP **đúng chuẩn** (`code: "ACCOUNT_INACTIVE"` ở cấp gốc), khác hẳn bắt tay socket. Nhánh **socket** và nhánh **làm mới** vẫn không dựng được đầu-cuối trên backend đã gộp — bắt tay và `/auth/refresh` từ chối **mọi** tài khoản (CAN-LAM 17 A). Ca *đã xoá* thì admin xoá mềm không hoàn tác được bằng giao diện. Chỉ **nhánh HTTP 401** (khoá tài khoản qua Admin-web) là kiểm được ngay. Chi tiết ở §7.3 của spec.

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
  > **Không kiểm trên máy ảo:** không đổi giao diện; không ép được token truy cập hết hạn; và CAN-LAM 17 mục A làm `/auth/refresh` trả 401 cho mọi tài khoản, nên nhánh làm mới không dựng được đầu-cuối trên backend đã gộp (✅ hết từ 2026-09-12 — gộp `cbbeeb4`; chiều cùng ngày đo bằng `curl`: 200 hợp lệ, 401 + `code` khi khoá — khối "Kiểm hai nhánh còn nợ của cưỡng chế đăng xuất" ở trên; **interceptor của app** ép 401 rồi tự làm mới cũng đã chạy thật chiều muộn với token 1 phút — khối "Kiểm hai nhánh còn nợ"; chỉ còn ca *mất mạng giữa 401 và làm mới* không dựng được). ⚠️ **Rủi ro còn lại, nói thành lời:** toàn bộ lời hứa §3.8 hiện **chỉ được canh bằng máy chủ giả** — chính hành vi "mất mạng thì giữ token" chưa một lần nào chạy trên máy thật. **Việc còn nợ:** khi backend đóng CAN-LAM 17 mục A thì kiểm một lượt trên máy ảo — đăng nhập, bật chế độ máy bay (hoặc hạ `JWT_USER_ACCESS_EXPIRES` trên backend dev để ép 401), xác nhận **không** bị đăng xuất và hai token còn nguyên trong kho.
  > **Lượt sửa sau soát cuối cả nhánh** (2026-09-12; người soát xếp *With fixes* — 0 Critical, 0 Important, 8 Minor; controller chọn làm **cả tám** trong một lượt, hai commit). Mã và test (`fe5a9fc`): (1) `catch (Object)` của `_lamMoi()` không còn hạ cấp một phiên **đã xác định** là chết — `_clearTokens()` phát tín hiệu trong `finally`, và `_lamMoi()` giữ phán quyết ở biến `phanQuyet` đặt trước lời gọi ấy; trước đó kho token hỏng đúng lúc xoá làm nơi gọi nhận `LamMoiTamThoi` và **không** có tín hiệu nào — đúng hình dạng G12 (ca mới đỏ trước, xanh sau). (2) Nhánh "200 không có `accessToken`" thôi gắn `response` của `/auth/refresh` vào lỗi trả cho request gốc: `SyncEngine` in `e.response?.data` bằng `debugPrint`, thứ **không** bị lược ở bản release, nên backend đổi tên khoá là body còn refreshToken ra thẳng logcat qua lỗi của một request khác. (3) Ba ca đồng thời thêm chốt canh (`bearerDaThay`) để không xanh vì lý do khác. (4) Chú thích giới hạn của `_retryRequest`. (5) `_loiTamThoiChoRequest` chép `stackTrace`. Tài liệu (commit ngay sau `fe5a9fc`): hai câu tả sai khối `catch` của chốt "token cũ" (spec + dòng trên), phạm vi gạch `LamMoiPhienChet.loi` và điểm vướng cho Phần 1, `FIX_BACKEND_3_REGRESSIONS.md` (`onError` gọi `_lamMoiChung()` → `_lamMoi()`), việc kiểm máy ảo còn nợ, và số đo mới.

### 🔄 Việc còn dang dở

Xem đầy đủ tại **`docs/CLIENT_APP_KNOWN_GAPS.md`**. Phiên 2026-09-03 đã đóng 9/10 mục còn mở; **G10 đóng ngày 2026-09-07**, và cùng ngày mở thêm **G23** (bản sao danh mục chỉ đầy đủ khi bộ mặc định *cục bộ* đầy đủ — tự khỏi ở lượt pull sau) và **G24** (màu danh mục không có cột trên server, chặn ở backend — ⚠️ 2026-09-11: thành lỗi phía client rồi đóng cùng ngày, xem dưới). **G15 đóng 2026-09-07** (dòng này từng còn liệt kê nó — soát lại 2026-09-09 từ chính `CLIENT_APP_KNOWN_GAPS.md`). Đếm lại từ chính `CLIENT_APP_KNOWN_GAPS.md` ngày 2026-09-10, cập nhật 2026-09-11 sau khi gộp `main` @ `cc65f4f` và áp `database/12` — dòng cũ ở đây chỉ liệt kê ba mục và đã bỏ sót bốn: mục **chưa đóng** nay là **G18** (⏸️ thu hẹp dần), **G23** (⏸️ chấp nhận được), **G26** (✅ cố ý — chờ màn duyệt giao dịch ngân hàng), **G27** (⏸️ hoãn có chủ ý — "ví được phép âm"), **G28** (⏸️ hết chặn phía server, chờ client mở lại — lưu trữ ví chỉ sống trên máy đã bấm, mở 2026-09-10; tệp `database/7` đã áp lên CSDL dev tối cùng ngày, cột nay `varchar(20)`; người dùng chốt mở lại **để sau**) và **G34** (⏸️ chưa làm, việc client — backend đã phát `sync.completed` ra socket sau mỗi `/sync/push`, nhưng client chưa nghe sự kiện ấy (`realtime_event.dart` chỉ khai ba sự kiện), và hôm nay nó cũng chưa tới được client vì bắt tay socket từ chối mọi tài khoản — CAN-LAM 17 A; mở 2026-09-11) — đếm lại bằng script 2026-09-11 sau khi đóng G33: **6** mục (loại ba mục *không phải lỗi*). **Đóng 2026-09-11**: **G24** (client đổi khoá màu danh mục sang `color`; kiểm trên máy ảo), **G35** (ba màn quản lý danh mục lấy tài khoản với dự phòng `?? 1` — mở và gỡ cùng ngày theo khuôn G4, kèm test quét `lib/`), **G30** (client gỡ chốt một ví Tiết kiệm sau khi `database/12` bỏ index; kiểm trên máy ảo), **G33** (trang Xoá tài khoản thôi hứa "đăng nhập lại là tự khôi phục", tài khoản chờ xoá dùng tiếp 30 ngày với thẻ nhắc đóng được ở Trang chủ và nút huỷ ở Cài đặt — chín commit `ca44dd8` → `866b870` (đếm bằng máy 2026-09-11), kiểm trên máy ảo với tài khoản 11 — khối "Sửa G33 — tài khoản chờ xoá dùng tiếp 30 ngày" trên), và theo mã backend sau gộp (chưa chạy đầu-cuối): **G29** (bộ lọc ghi chú mới chạy đúng 15/15 ca), **G31** (`22001`/`23502` thành `CONSTRAINT_VIOLATION`; bộ lọc bảy ô tên phía client vẫn giữ để bản ghi không kẹt vĩnh viễn) và **G32** (backend giữ `null`, tệp 12 dọn `<= 0` trên CSDL dev; client vẫn đọc `<= 0` là chưa sắp làm lớp phòng thủ). **G19**, **G22** và **G25** ghi *không phải lỗi*, giữ lại để người sau không "sửa" nhầm:

> ⚠️ **Đính chính 2026-09-17 — đoạn trên là ảnh chụp ngày 2026-09-11 và nay
> sai ở BA chỗ.** `G28` đóng 2026-09-14 (`wallet.status` đi qua đồng bộ hai
> chiều), `G34` đóng tối 2026-09-12 (client nghe `sync.completed`), và `G27`
> đóng 2026-09-17 (cờ `wallets.allow_negative`, schema v23 — khối "Ví được
> phép âm" đầu mục này).
>
> **Đếm lại bằng máy 2026-09-17 từ chính `CLIENT_APP_KNOWN_GAPS.md`: 44 mục
> G, 41 đã đóng, còn BA** — `G18` (⏸️ thu hẹp dần), `G23` (⏸️ chấp nhận được)
> và `G44` (⏸️ kỳ rỗng: màn Xem trước giấu mọi khối còn tệp vẫn in khối Ngân
> sách — mở cuối ngày, khi nghiệm thu mục 3.31). Cả ba đều là hoãn có chủ ý,
> không phải lỗi đang chờ sửa. ⚠️ Hai ảnh chụp cũ **cùng ngày** đừng dùng:
> **43 mục / còn HAI** là trước khi G44 mở, và **còn ba (G18, G23, G27)** là
> buổi sáng, trước khi G27 đóng — trùng con số "ba" nhưng **khác danh sách**.
>
> ⚠️ **Đoạn ngay trên là ảnh chụp ngày 2026-09-17.** Đếm lại bằng máy
> **2026-09-18**, sau khi G44, G45 **và** G46 đóng: **46 mục G, 44 đã đóng, còn
> HAI** — `G18` và `G23`, cả hai hoãn có chủ ý. Con số "còn HAI" nay **trùng**
> với ảnh chụp "43 mục / còn HAI" của hôm trước nhưng **tổng thì khác**, và
> trong cùng ngày 2026-09-18 nó đã qua **ba** mốc (44 sau G44, 45 sau G45, 46
> sau G46) — đúng cái bẫy mà chính đoạn này cảnh báo, nên đếm lại thay vì so
> con số lẻ.
>
> Giữ nguyên đoạn cũ thay vì viết lại: nó ghi lại *đường đã đi*, và mỗi lần
> sửa tại chỗ là mất dấu vết vì sao danh sách từng có hình dạng ấy.

- **G15 — Bản ghi vừa hết hạn vừa hỏng đồng bộ thì không sửa được.** ⏸️ **Hoãn có chủ ý** (2026-09-04): tab "Đã hết hạn" khoá sửa/xoá, nên một ngân sách vừa quá hạn vừa bị backend từ chối vĩnh viễn sẽ nằm lại mãi — hàng đợi đồng bộ vẫn thông vì `SyncEngine` chặn nó theo thời gian, nhưng người dùng không chữa được. Giữ nguyên vì tab đó là nền cho phần thống kê/báo cáo sẽ làm sau. Bán kính rủi ro hẹp: nguồn gây lỗi chính (form tạo ra `end ≤ start`) đã bịt cùng ngày.
- ~~**G10 — `CategoryGroupMemberships` không bao giờ được đồng bộ.**~~ ✅ **Đóng 2026-09-07, và không phải bằng cách xin backend thêm entity.** Bảng phụ ấy tồn tại chỉ vì danh mục mặc định là hàng toàn cục nên không ghi `Idgroup` riêng cho từng tài khoản được. Nay mỗi tài khoản có **bản sao riêng** của bộ mặc định, nên việc gán nhóm nằm gọn trong `Idgroup` của chính hàng họ sở hữu — cột đã có sẵn và đã đồng bộ.

> ⚠️ **`.gitignore` vẫn có `test/`** (dòng 78, đo 2026-09-10 — từng ghi 77)**.** Luật này đã cắn **lần thứ ba** (phiên 2026-09-04). Mọi file test tạo **mới** vẫn sẽ bị bỏ qua trong im lặng — nhớ `git add -f`. ✅ **HẾT HIỆU LỰC 2026-09-21** — luật `test/` đã bỏ khỏi `.gitignore` (quy tắc 6 `CLAUDE.md`); tệp test mới nay hiện bình thường, không cần `-f`.
>
> Hệ quả ít ai biết: **công cụ Grep tôn trọng `.gitignore` nên không nhìn thấy thư mục `test/`**. Muốn dò xem còn ai gọi một hàm sắp xoá thì phải dùng `grep` qua shell, nếu không sẽ thấy thiếu file và xoá nhầm. ✅ **HẾT HIỆU LỰC 2026-09-21** — luật `test/` đã bỏ, Grep nay nhìn thấy bộ test.

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
| 11 | `2026-09-06-bill-chuoi-ky-va-an-han.md` | ⛔ **Chưa có cột nào.** Đo 2026-09-07: bảng `bill` có 18 cột, **không** có `Previous_bill_id` lẫn `Auto_pay`; `transaction` **không** có `Idbill`. **(A+B) Mở khoá:** hai cột nullable — hoàn tác thanh toán hiện chỉ chạy trên đúng máy đã trả; cột B còn mở **lịch sử theo hoá đơn**. **(C) Mở đường:** `bill.Period_end` để tách kỳ tính tiền khỏi hạn trả. **(D) Mở khoá:** `bill.Auto_pay` + **chốt chặn trả hai lần** ở `/sync/push` — hai máy cùng bật, cùng offline là hai khoản chi. **(E) Mở đường:** nhận `Pay_status = 'Skipped'` (VarChar(7) vừa khít, không cần migration). ⚠️ Bảng `bill` **đã có** cột `Color` trong khi `category` thì không — lý lẽ sẵn cho mục màu danh mục. ⚠️ 2026-09-11: server nay đủ cột (cả `Period_end`, `Anchor_day`) và nhận `'Skipped'`, `category.Color` cũng đã có; nhưng chốt trả hai lần đặt sai chỗ (CAN-LAM 17 B), và phía client các cột hoá đơn vẫn cục bộ ✅ **C (ân hạn) client làm 2026-09-12 tối** — schema v21, đồng bộ `period_end`; khối "Ân hạn hoá đơn" mục 14 |
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
> (spec mục 3 và §5.1, ✅ **xong 2026-09-12**); và **8** client gửi/đọc các cột hoá
> đơn server đã có (✅ **xong 2026-09-12** — khối "Ba cột hoá đơn đi qua đồng bộ" ở
> trên). ⚠️ Bước 8 vốn ghi **bốn** cột; người dùng chốt cùng ngày rằng
> `Period_end` **không phải trường đồng bộ mà là một tính năng** và tách nó ra —
> nó cần cột cục bộ mới (v21), ô nhập trên màn Stitch mới, và đổi phép tính kỳ kế
> tiếp (✅ bước **14**, xong tối cùng ngày). Vậy bước 8 làm **ba** cột: `Idbill`, `Previous_bill_id`, `Anchor_day`.
> và **9** "Bỏ qua kỳ" (`Pay_status = 'Skipped'`; ✅ **xong 2026-09-12** — khối
> "Bỏ qua kỳ hoá đơn" ở trên; màn Stitch đã dựng, app thị trường đã đối chiếu và
> ghi vào mục 2 của spec).
> **10** gộp `main` ✅ **xong 2026-09-12** (`cbbeeb4` — khối "Gộp `main` @ `cbbeeb4`…" ở trên;
> 17 A đã chạy thật, kênh thời gian thực nối được; CSDL dev áp `database/13` cùng lượt).
> **11** nghe `sync.completed` ✅ **xong 2026-09-12 tối** (G34 đóng — **im lặng**, không toast, vì máy
> vừa đẩy cũng nhận lại sự kiện của mình; kiểm máy ảo hai máy, máy kia kéo về cùng giây — khối "Nghe
> `sync.completed`" ở trên). Còn lại: **12** đồng bộ `Auto_pay` — ✅ **hết bị chặn từ tối muộn 2026-09-12** (gộp `main` @
> `7779999`: backend đặt chốt ở `upsertTransaction`, client đo thật 4 ca — khối "Gộp `main` @
> `7779999`…" ở trên); nay là việc **phía client**, chưa làm → **13** G28 ✅ **xong 2026-09-14**
> (khối "Lưu trữ ví qua đồng bộ" ở trên) → *(mới, tách khỏi bước 8)* **14** `Period_end` — ân hạn ✅ **xong 2026-09-12 tối**
> (schema v21; khối "Ân hạn hoá đơn" ở trên).
>
> **2026-09-13:** **15** gộp `main` @ `eb071bb` + soát tài liệu Edge SLM ✅ (CAN-LAM 21 — khối
> "Gộp `main` @ `eb071bb`…" ở trên) → **16** đóng **G36** ✅ (đo đầu-cuối ba ca `/auth/refresh`
> qua API admin — khối "Đóng G36…" đầu mục này). Danh sách còn tồn nay **bốn** việc, không phải
> năm: **bước 2** — chốt ngoại lệ `lamMoi` §3.6b (⚠️ lý lẽ cũ đã bị phép đo G36 lật, xem khối
> "Đóng G36…"); **bước 12** — đồng bộ `Auto_pay` (lớn nhất, hết bị chặn); ~~**bước 13** — G28
> `wallet.status`~~ ✅ **xong 2026-09-14**; và ba việc nhỏ — ✅ **hai trong ba xong 2026-09-13**: `git add -f` spec socket
> (9 chỗ dẫn chiếu mà chưa có trong repo) và cửa sổ `syncNow()` bị nuốt khi `_runSync` đang
> chạy (khối "Sửa lỗi: yêu cầu đồng bộ…" đầu mục này). Việc thứ ba — dòng "Kỳ" trên màn Stitch
> *Chi tiết hóa đơn* — làm ở **bốn** màn chứ không phải hai (đếm lại bằng cách đọc khối
> `THÔNG TIN` của từng màn); `edit_screens` ghi được nhưng **trễ hàng chục phút**, nên trạng
> thái từng màn xem ở khối 'Dòng "Kỳ" cho bốn màn Stitch…' đầu mục này.

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
>    kiện*: một tên đi qua EventBus của backend không bảo đảm một hình dạng
>    payload, và client không biết bản backend đang chạy dựng nó bằng khoá gì.
>    Có test cấm chữ số xuất hiện trong lời nhắn để canh chừng ai đó bắt đầu
>    đọc payload. ⚠️ Lý lẽ **ban đầu** của cam kết này là
>    `bank_transaction.incoming` được phát từ hai chỗ với hai hình dạng và
>    trường `type` mang hai nghĩa. Sự kiện ấy **không còn được client dịch** từ
>    2026-09-18 (nhóm bỏ liên kết ngân hàng), nhưng cam kết **giữ nguyên** — ví
>    dụ mất đi không làm lý lẽ mất đi.
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
> `CLIENT_APP_KNOWN_GAPS.md` — ⚠️ mục ấy **đóng 2026-09-18** bằng quyết định bỏ
> hẳn liên kết ngân hàng, nên màn ấy không thiếu mà không còn trong sản phẩm),
> không badge đếm. Ba sự kiện backend đang phát
> đều thuộc tính năng client chưa có, nên **giá trị thật của kênh nằm ở việc
> backend bắc `sync.completed` ra socket** — mục 7 cũ của
> `docs/superpowers/backend/CAN-LAM/README.md`, nay `DA-XONG/SOCKET_SYNC_COMPLETED.md`.
> ⚠️ **2026-09-11:** backend **đã bắc** — `sync.service.js:223` phát sau mỗi
> `/sync/push` tới phòng `account_<id>` — nhưng giá trị ấy vẫn chưa tới: bắt tay
> socket từ chối mọi tài khoản (CAN-LAM 17 A — ✅ hết 2026-09-12 sau gộp `cbbeeb4`, kênh nối được), và client **chưa nghe** sự kiện
> này — `realtime_event.dart` chỉ khai ba sự kiện (**G34** — ✅ client nghe từ tối 2026-09-12, im lặng, kiểm máy ảo).
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
2026-09-11; ✅ 2026-09-12 backend bỏ chốt ấy nhưng chưa đặt chốt ở `upsertTransaction` — server không chặn trả hai lần ở đâu cả; ✅ tối muộn cùng ngày `7779999` đặt chốt đúng chỗ, rào cản này hết, còn lại là client mở `Auto_pay`). Lý do từng bước: mục 10.5 `docs/GOAL_FEATURE.md` và mục 7
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
   sự kiện nào tới — CAN-LAM 17 A; ✅ hết 2026-09-12 sau gộp `cbbeeb4`, kênh nối lại được). Chỗ còn thiếu là
   tính năng phía client để *làm gì đó* với chúng (G26), chứ không phải kênh
   truyền. ⚠️ **Cập nhật 2026-09-18:** vế "cảnh báo giao dịch ngân hàng" **bỏ
   hẳn** cùng tính năng liên kết ngân hàng — client thôi dịch
   `bank_transaction.incoming`, và G26 đóng bằng quyết định sản phẩm. Chỉ còn
   vế OCR.

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
   đơn đang cục bộ, nghe `sync.completed` (G34 — ✅ 2026-09-12 tối), và tính năng "bỏ qua kỳ này" (✅ 2026-09-12).
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
  `chuoiTheoKy()` — tên cũ `chuoiTheoThang` tới 2026-09-15 — dựng ở tầng thuần, **cũ nhất trước**, kỳ rỗng giữ chỗ
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
  ở `home_page.dart` vì chỗ đó (tới 2026-09-12) gọi `start()` trong `build()`.
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
- ~~Tích hợp ngân hàng phía client~~ — **BỎ ngày 2026-09-18** theo quyết định của nhóm. Phần client đã gỡ (G26 chuyển từ "hoãn" sang "bỏ"); backend vẫn giữ module `bank/` của mình
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
