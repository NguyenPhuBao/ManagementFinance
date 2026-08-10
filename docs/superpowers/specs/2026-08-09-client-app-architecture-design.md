# Client-app Architecture Design — FlowMoney

**Ngày tạo:** 2026-08-09  
**Tác giả:** Nguyễn Phú Bảo  
**Trạng thái:** Approved — chờ implementation plan  

---

## 1. Bối Cảnh

FlowMoney Client-app là ứng dụng mobile (Flutter) cho phép người dùng cuối quản lý tài chính cá nhân. Yêu cầu cốt lõi:

- **Offline-first bắt buộc**: App hoạt động đầy đủ khi không có internet, tự động đồng bộ khi có mạng.
- **23 màn hình** đã thiết kế trên Stitch (FlowMoney — mobile, design system Kinetic Finance).
- **1 developer** (người phụ trách), mới học Flutter, thời gian 3–4 tháng.
- Phối hợp với backend developer (NodeJS + PostgreSQL) qua API `/sync`.

---

## 2. Quyết Định Kiến Trúc

**Chọn: BLoC + Repository Pattern + Feature-first folder structure**

### Lý do

| Tiêu chí | Lý do chọn BLoC + Repository |
|---|---|
| Tách biệt UI & logic | BLoC/Cubit buộc tách ngay từ đầu, tránh nợ kỹ thuật |
| Offline-first | Repository pattern xử lý tự nhiên: đọc local, ghi local + sync sau |
| Người mới học | Cubit (simplified BLoC) dễ hơn Clean Architecture đầy đủ |
| Bảo trì | Feature-first → mỗi tính năng độc lập, dễ sửa không ảnh hưởng nhau |
| Nhất quán với Project.md | Đúng định hướng đã ghi (BLoC + Repository + SQLite) |

---

## 3. Cấu Trúc Thư Mục

```
lib/
├── core/                            # Dùng chung toàn app
│   ├── api/                         # Dio client, interceptors, token refresh
│   │   ├── dio_client.dart
│   │   └── interceptors/
│   │       ├── auth_interceptor.dart
│   │       └── retry_interceptor.dart
│   ├── database/                    # Drift database setup
│   │   ├── app_database.dart        # @DriftDatabase annotation
│   │   └── daos/                    # Data Access Objects
│   ├── sync/                        # Sync engine
│   │   ├── sync_engine.dart
│   │   └── sync_models.dart         # SyncOperation, SyncResult
│   ├── di/
│   │   └── injection.dart           # GetIt setup
│   ├── constants/
│   │   ├── app_router.dart          # GoRouter — tất cả routes
│   │   └── app_constants.dart
│   ├── errors/
│   │   └── app_exceptions.dart
│   └── utils/
│       ├── currency_formatter.dart
│       └── date_formatter.dart
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── auth_local_datasource.dart   # Lưu/đọc JWT (SecureStorage)
│   │   │   │   └── auth_remote_datasource.dart  # POST /auth/login, /register
│   │   │   ├── models/
│   │   │   │   └── auth_model.dart
│   │   │   └── repositories/
│   │   │       └── auth_repository.dart
│   │   └── presentation/
│   │       ├── bloc/
│   │       │   ├── auth_bloc.dart
│   │       │   └── auth_state.dart
│   │       ├── pages/
│   │       │   ├── login_page.dart
│   │       │   ├── register_page.dart
│   │       │   └── forgot_password_page.dart
│   │       └── widgets/
│   │
│   ├── transaction/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── transaction_local_datasource.dart
│   │   │   │   └── transaction_remote_datasource.dart
│   │   │   ├── models/
│   │   │   │   └── transaction_model.dart
│   │   │   └── repositories/
│   │   │       └── transaction_repository.dart
│   │   └── presentation/
│   │       ├── bloc/
│   │       │   ├── transaction_cubit.dart
│   │       │   └── transaction_state.dart
│   │       ├── pages/
│   │       │   └── add_transaction_page.dart
│   │       └── widgets/
│   │           └── transaction_card.dart
│   │
│   ├── wallet/          # Tương tự cấu trúc transaction/
│   ├── budget/
│   ├── category/
│   ├── bill/
│   ├── goal/
│   ├── analytics/
│   ├── ai_chat/
│   └── profile/
│
├── shared/
│   ├── widgets/
│   │   ├── bottom_nav_bar.dart      # Bottom Navigation 5 tabs
│   │   ├── loading_widget.dart
│   │   ├── error_widget.dart
│   │   ├── empty_state_widget.dart
│   │   └── confirm_dialog.dart
│   └── theme/
│       ├── app_theme.dart           # ThemeData
│       ├── app_colors.dart          # #EDEDE9, #4CAF50, #F25F5C...
│       └── app_text_styles.dart
│
└── main.dart
```

---

## 4. State Management — BLoC / Cubit

### Quy tắc sử dụng

| Dùng **Cubit** | Dùng **BLoC** |
|---|---|
| CRUD đơn giản: Wallet, Category, Bill, Goal, Budget | Auth (login/logout/refresh), Sync |
| 1 action → 1 state thay đổi | Nhiều loại Event, luồng phức tạp |

### Pattern State chuẩn (áp dụng mọi feature)

```dart
// 4 state cơ bản
abstract class FeatureState extends Equatable {}
class FeatureInitial extends FeatureState { ... }
class FeatureLoading extends FeatureState { ... }
class FeatureLoaded<T> extends FeatureState { final T data; ... }
class FeatureError extends FeatureState { final String message; ... }
```

### Quy tắc vàng

> **UI → Cubit/BLoC → Repository → LocalDataSource / RemoteDataSource**
>
> UI **không bao giờ** gọi trực tiếp vào database hoặc API.

---

## 5. Data Layer — Offline-first

### 5.1 SQLite với Drift

Mỗi bảng local có 3 cột bắt buộc để hỗ trợ sync:

```dart
// Áp dụng cho: wallets, transactions, budgets, goals, bills, categories
TextColumn get id        => text()();                           // UUID (client tự tạo)
TextColumn get syncStatus => text().withDefault(               // 'pending'/'synced'/'conflict'
    const Constant('pending'))();
DateTimeColumn get updatedAt => dateTime()();                  // Conflict resolution
```

**Lý do UUID:** Client tạo record offline cần ID ngay, không thể chờ server.

### 5.2 Repository Pattern

```
Repository.getAll()   → Luôn đọc từ SQLite
Repository.save()     → Ghi SQLite (syncStatus='pending'), SyncEngine lo phần còn lại
Repository.update()   → Ghi SQLite (syncStatus='pending')
Repository.delete()   → Soft delete: isDeleted=true, syncStatus='pending'
```

### 5.3 Sync Engine

**Trigger:** App vào foreground | Sau mỗi thay đổi (debounce 3s) | Mỗi 15 phút

**Giao thức:**
- Client gửi `POST /sync` với mảng `SyncOperation[]`
- Backend xử lý, trả về `SyncResult[]` (ok / conflict)
- Client cập nhật `syncStatus` theo kết quả

**Conflict resolution:** Server là source of truth → server data thắng.

### 5.4 Schema đồng bộ giữa Client và Backend

> ⚠️ **Action item cho nhóm:** Người làm Backend cần bổ sung các bảng sau vào PostgreSQL (hiện chỉ có admin schema):

| Entity | Client SQLite | Backend PostgreSQL |
|---|---|---|
| Wallet | ✅ Cần tạo | ❌ Chưa có |
| Transaction | ✅ Cần tạo | ❌ Chưa có |
| Budget | ✅ Cần tạo | ❌ Chưa có |
| Goal | ✅ Cần tạo | ❌ Chưa có |
| Bill | ✅ Cần tạo | ❌ Chưa có |
| Category (user) | ✅ Cần tạo | ⚠️ Có bảng Category admin |

---

## 6. Navigation — GoRouter

Toàn bộ routes khai báo tập trung tại `core/constants/app_router.dart`.

**Cấu trúc routes:**
- `/login`, `/register`, `/forgot-password` — public routes
- `ShellRoute` cho 5 tab chính (dùng chung Bottom Nav): `/home`, `/analytics`, `/add`, `/budget`, `/profile`
- Sub-routes: `/wallets`, `/wallets/add`, `/wallets/:id/edit`, `/categories`, `/bills`, `/bills/add`, v.v.
- `redirect` guard: kiểm tra auth tập trung, redirect `/login` nếu chưa đăng nhập

---

## 7. Dependency Injection — GetIt

Tất cả dependencies đăng ký tại `core/di/injection.dart`, gọi một lần trong `main.dart`.

**Thứ tự đăng ký:**
1. Infrastructure: `AppDatabase`, `DioClient`
2. DataSources: `*LocalDataSource`, `*RemoteDataSource`
3. Repositories: `*Repository`
4. Core services: `SyncEngine`
5. Cubits/BLoCs: đăng ký dạng `factory` (tạo mới mỗi lần)

---

## 8. Packages

```yaml
dependencies:
  # State management
  flutter_bloc: ^8.x
  equatable: ^2.x

  # Navigation
  go_router: ^14.x

  # DI
  get_it: ^7.x

  # Local database
  drift: ^2.x
  sqlite3_flutter_libs: ^0.x
  path_provider: ^2.x

  # HTTP
  dio: ^5.x

  # Offline & Sync
  connectivity_plus: ^6.x
  uuid: ^4.x

  # Security
  flutter_secure_storage: ^9.x

  # Utils
  intl: ^0.19.x

dev_dependencies:
  drift_dev: ^2.x
  build_runner: ^2.x
  flutter_lints: ^4.x
```

---

## 9. Thứ Tự Triển Khai Gợi Ý

1. **Setup dự án** — Tạo Flutter project, cài packages, cấu hình GoRouter + GetIt + Drift
2. **Theme & Shared widgets** — Colors, TextStyles, BottomNavBar, Loading/Error widgets
3. **Auth feature** — Login, Register, Forgot password + JWT storage
4. **Wallet feature** — CRUD ví (màn hình đơn giản, học pattern BLoC+Repository)
5. **Transaction feature** — Thêm giao dịch (quan trọng nhất)
6. **Sync Engine** — Sau khi có 2-3 feature chạy được, implement sync
7. **Budget, Category, Bill, Goal** — Áp dụng pattern đã học
8. **Analytics & AI Chat** — Tính năng nâng cao
9. **Profile & Settings** — Quản lý tài khoản

---

## 10. Sơ Đồ Kiến Trúc Tổng Thể

```
┌─────────────────────────────────────────────────┐
│                    UI Layer                      │
│   Pages ──▶ BlocBuilder ──▶ hiển thị state      │
│   Widgets ──▶ BlocProvider ──▶ inject Cubit      │
└──────────────────┬──────────────────────────────┘
                   │ gọi method
┌──────────────────▼──────────────────────────────┐
│              BLoC / Cubit Layer                  │
│   emit(Loading) → gọi Repository → emit(Loaded) │
└──────────────────┬──────────────────────────────┘
                   │ gọi
┌──────────────────▼──────────────────────────────┐
│              Repository Layer                    │
│   getAll()  → LocalDataSource (Drift/SQLite)     │
│   save()    → LocalDataSource → SyncEngine       │
└──────────┬──────────────────────────────────────┘
           │                      │
    ┌──────▼──────┐       ┌───────▼──────┐
    │  SQLite     │       │  REST API    │
    │  (Drift)    │       │  (Dio)       │
    └─────────────┘       └──────┬───────┘
                                 │ POST /sync
                         ┌───────▼──────┐
                         │   Backend    │
                         │  NodeJS +    │
                         │  PostgreSQL  │
                         └──────────────┘
```
