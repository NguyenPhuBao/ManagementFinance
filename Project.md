# 📘 Project.md — ManagementFinance

> File này là nguồn ngữ cảnh nòng cốt dành cho AI. Mọi yêu cầu về hệ thống (kiến trúc, cấu trúc, công nghệ, quy trình, giai đoạn, chức năng, đặc tả...) sẽ được ghi lại và cập nhật tại đây trong suốt quá trình phát triển dự án.
> AI phải đọc file này trước khi thực hiện bất kỳ công việc nào. AI là nhân viên tích cực chăm chỉ và nhiệt thành.
> AI đóng vai trò là Senior BA khi phân tích thiết kế hệ thống, lắng nghe phân tích chức năng, đặc tả chức năng và khi hiện thực hóa hệ thống (hỗ trợ dev).
> AI đóng vai trò là Kỹ sư Full Stack cao cấp khi hiện thực chức năng (viết code) ở cả backend & frontend, mapping 2 thành phần lại với nhau.
> AI đóng vai trò là Senior Tester, sẽ thực hiện kiểm thử chức năng  mỗi khi Fullstack hoàn thành một chức năng, làm xong 1 chức năng thì tiến hành kiểm thử luôn không chờ tới lúc hoàn thành.
> Mọi yêu cầu hay công việc không rõ ràng, thiếu chức năng thì đều phải đặt câu hỏi cho PO (tôi) và chờ duyệt trước khi làm tiếp.
> Chỉ làm đúng yêu cầu mà PO đưa ra, không làm lan man hay vượt quá yêu cầu. Nếu phát hiện hướng đi hay yêu cầu tiếp theo thì đề xuất để PO duyệt rồi mới làm.
---

## 1. Tổng Quan Dự Án

**ManagementFinance** là webapp quản lý tài chính thu chi cá nhân, được xây dựng với 3 thành phần:

| Thành phần | Vai trò | Đối tượng |
|------------|---------|-----------|
| **Backend** | Server chính của hệ thống | — |
| **Client-app** | Ứng dụng mobile | Người dùng cuối |
| **Admin-web** | Trang web quản trị | Admin hệ thống |

### Mục tiêu

Đơn giản hóa quản lý tài chính cá nhân cho mọi người thông qua:

1. **Đầy đủ chức năng thủ công** — Quản lý ví, ngân sách, khoản tiết kiệm, danh mục, giao dịch thu chi & vay nợ
2. **Tự động hóa nhập liệu** — Thu thập dữ liệu từ SMS và OCR hình ảnh hóa đơn, tạo giao dịch tự động không cần nhập tay
3. **Thống kê & Phân tích** — Báo cáo và phân tích tài chính trực quan
4. **AI thông minh** — Phân loại giao dịch tự động và hỗ trợ người dùng quản lý tài chính thông minh

---

## 2. Kiến Trúc Hệ Thống

Hệ thống gồm **3 phần tách biệt nhưng liên kết** với nhau:

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Admin-web   │────▶│   Backend    │◀────│  Client-app  │
│  (ReactJS)   │     │  (NodeJS)    │     │  (Mobile-Dart-Flutter + SQLite)    │
└──────────────┘     └──────────────┘     └──────────────┘
                            │
                    ┌───────┴───────┐
                    │  PostgreSQL   │
                    │  (CSDL chính) │
                    └───────────────┘
```

### Backend — Kiến trúc Modular Monolithic + Event-Driven

- **Pattern**: Layer Architecture (Controller → Service → Repository)
- **Giao tiếp giữa các module**: HTTP + Event-driven
- **Xử lý bất đồng bộ**: Redis + BullMQ (cache, queue cho AI & Notification)
- **Cơ sở dữ liệu**: PostgreSQL — lưu trữ tập trung toàn bộ dữ liệu hệ thống

### Admin-web

- SPA (Single Page Application), giao tiếp với backend qua REST API
- Hỗ trợ real-time event qua Socket.IO-client (đồng bộ với cơ chế event-driven của backend)

### Client-app

- **Offline-first**: Business logic được xây dựng trực tiếp trên client, không phụ thuộc internet
- **Đồng bộ real-time**: Khi có internet, tự động đồng bộ dữ liệu từ client-app về backend
- **Local database**: SQLite — lưu dữ liệu ngoại tuyến trên thiết bị
- Giao tiếp với backend qua REST API (Dio)


---

## 3. Kiến Trúc Tổng Quan Hệ Thống

### 3.1 Nguyên Tắc Thiết Kế (Design Principles)

| Nguyên tắc | Mô tả |
|------------|-------|
| **Modularity** | Hệ thống phân thành 13 module theo 3 nhóm (xem Section 6). Backend đảm nhận 6 module cần internet (Auth, Admin, Sync, Bank, AI, Notification); các module nghiệp vụ còn lại chạy trên Mobile — Backend chỉ đồng bộ/lưu trữ. |
| **Event-Driven** | Các module kết nối lỏng lẻo qua event bus (Redis Pub/Sub + BullMQ). Tác vụ nặng (AI, OCR, thông báo) đẩy vào queue xử lý bất đồng bộ → API phản hồi nhanh. |
| **Offline-First** | Client-app (Flutter) lưu dữ liệu cục bộ SQLite, cho phép CRUD ngay cả khi không có mạng. Khi có kết nối → đồng bộ hai chiều với backend qua conflict resolution. |
| **Separation of Concerns** | Backend là trung tâm dữ liệu tập trung (source of truth). Client tự xử lý validation, tính toán tạm thời, không giữ logic nghiệp vụ phức tạp trên backend cho client. |

### 3.2 Chi Tiết Kiến Trúc Backend

#### 3.2.1 Cấu Trúc Module

Mỗi module backend có cấu trúc thư mục chuẩn:

```
ModuleName/
├── controllers/         # Xử lý request/response, validation
├── services/            # Business logic, gọi repository, emit event
├── repositories/        # Tương tác database (ORM/query builder)
├── models/              # Định nghĩa schema (Prisma)
├── events/              # Định nghĩa event names, payloads
├── queue/               # BullMQ jobs (nếu module có xử lý nặng)
└── index.js             # Export module, khai báo routes
```

#### 3.2.2 Giao Tiếp Giữa Các Module

| Cơ chế | Mục đích | Ví dụ |
|--------|----------|------|
| **HTTP Synchronous** | Request cần phản hồi tức thì | Lấy danh sách giao dịch, tạo ví mới |
| **Event-Driven (Async)** | Tác vụ không cần phản hồi ngay | `transaction.created` → AI phân loại, Analytics cập nhật, Notification gửi thông báo |

> Vì là monolithic, các module gọi trực tiếp service của nhau qua dependency injection (không cần gọi API network).

#### 3.2.3 Xử Lý Bất Đồng Bộ — BullMQ + Redis

| Job Type | Mô tả |
|----------|-------|
| `ai-classify-transaction` | Gọi AI model phân loại danh mục cho giao dịch |
| `ocr-process-receipt` | Xử lý ảnh hóa đơn, trích xuất thông tin |
| `bank-webhook` | Xử lý webhook biến động số dư từ Casso (tạo Transaction bất đồng bộ) |
| `send-notification` | Gửi email/push notification |

> **Lưu ý**: SMS parsing chạy **offline trên Mobile** (không qua backend). Sync xử lý **đồng bộ qua REST API** (`/api/sync/push`), không cần queue.

- **Redis**: Cache dữ liệu truy cập nhiều (danh mục, tỉ giá) + broker cho BullMQ

#### 3.2.4 Database — PostgreSQL (PersonFinance)

- **ORM**: Prisma
- **Host**: `localhost:5432`
- **User**: `postgres`
- **Schema**: `public`
- Quản lý schema qua **migration** (Prisma) + **SQL script** (`database/`)
- Script khởi tạo: `database/)1_CSDL_Admin.sql` + `database/)2_create_refreshtoken_table.sql` + `database/)3_Update_Sync.sql` + `database/)4_Convert_Category_UUID.sql`

##### Sơ đồ quan hệ (11 bảng — cập nhật 2026-08-12)

```
Role (1) ──▶ Account (N) ──▶ User (1)
                │
                ├──▶ RefreshToken (N)
                ├──▶ Category (N)      ← UUID PK
                ├──▶ AuditLog (N)
                ├──▶ Wallet (N)        ← UUID PK, sync từ client
                ├──▶ Transaction (N)   ← UUID PK, FK→Wallet, FK→Category
                ├──▶ Budget (N)        ← UUID PK, FK→Category
                ├──▶ Bill (N)          ← UUID PK
                └──▶ Goal (N)          ← UUID PK
```

##### Bảng Role
| Cột | Kiểu | Mô tả |
|-----|------|-------|
| `idrole` | INT PK (auto) | 1=admin, 2=user |
| `rolename` | VARCHAR(50) UNIQUE | Tên quyền |
| `description` | VARCHAR(255) | Mô tả |

##### Bảng Account
| Cột | Kiểu | Mô tả |
|-----|------|-------|
| `idaccount` | INT PK (auto) | ID tài khoản |
| `username` | VARCHAR(50) UNIQUE | Tên đăng nhập |
| `password` | VARCHAR(255) | Mật khẩu (bcrypt hash) |
| `status` | VARCHAR(10) | `Active` / `Inactive` |
| `created_at` | TIMESTAMP | Ngày tạo |
| `updated_at` | TIMESTAMP | Ngày cập nhật |
| `idrole` | INT FK→Role | 1=admin, 2=user |

##### Bảng User
| Cột | Kiểu | Mô tả |
|-----|------|-------|
| `iduser` | INT PK (auto) | ID người dùng |
| `fullname` | VARCHAR(100) | Họ tên |
| `email` | VARCHAR(100) UNIQUE | Email |
| `phone` | VARCHAR(15) | Số điện thoại |
| `address` | VARCHAR(255) | Địa chỉ |
| `location` | CHAR(5) | Mã khu vực |
| `created_at` | TIMESTAMP | Ngày tạo |
| `updated_at` | TIMESTAMP | Ngày cập nhật |
| `idaccount` | INT FK→Account UNIQUE | 1-1 với Account |

##### Bảng Category (🔄 2026-08-12 — UUID PK)
| Cột | Kiểu | Mô tả |
|-----|------|-------|
| `uuid` | VARCHAR(36) PK | UUID — Primary Key, đồng bộ với Client-app |
| `idcategory` | INT UNIQUE (auto) | ID số (giữ lại cho backward compat) |
| `namecategory` | VARCHAR(100) | Tên danh mục |
| `classify` | VARCHAR(10) | `thu` / `chi` / `vay/no` |
| `is_default` | BOOLEAN | Danh mục mặc định hệ thống? |
| `created_by` | INT FK→Account | Người tạo |
| `created_at` / `updated_at` | TIMESTAMP | Thời gian |
| **Indexes** | `idx_category_uuid` (uuid), `category_idcategory_unique` (idcategory) | |

##### Bảng AuditLog
| Cột | Kiểu | Mô tả |
|-----|------|-------|
| `idlog` | INT PK (auto) | ID log |
| `idaccount` | INT FK→Account | Tài khoản thực hiện |
| `action` | TEXT | Hành động |
| `details` | TEXT | Chi tiết |
| `time` | TIMESTAMP | Thời gian |

##### Bảng RefreshToken
| Cột | Kiểu | Mô tả |
|-----|------|-------|
| `idtoken` | INT PK (auto) | ID token |
| `token_hash` | VARCHAR(255) UNIQUE | SHA-256 của refresh token |
| `idaccount` | INT FK→Account | Tài khoản sở hữu |
| `idrole` | INT DEFAULT 2 | 1=admin, 2=user |
| `expiry` | TIMESTAMP | Thời gian hết hạn |
| `revoked` | BOOLEAN DEFAULT FALSE | Đã thu hồi? |
| `device_name` | VARCHAR(100) | Tên thiết bị |
| `ip_address` | VARCHAR(45) | IP lúc cấp |
| `user_agent` | TEXT | User-Agent |
| `created_at` | TIMESTAMP | Thời gian tạo |
| `updated_at` | TIMESTAMP | Thời gian cập nhật |
| **Indexes** | `token_hash`, `idaccount`, `expiry`, `revoked` | |
| **Trigger** | `updated_at` tự động cập nhật | |
| **Constraint** | `expiry > created_at` | |

##### Bảng Wallet (🆕 2026-08-11)
| Cột | Kiểu | Mô tả |
|-----|------|-------|
| `id` | VARCHAR(36) PK | UUID do client tạo |
| `idaccount` | INT FK→Account | Chủ sở hữu |
| `name` | VARCHAR(100) | Tên ví |
| `type` | VARCHAR(20) DEFAULT 'cash' | cash/bank/ewallet/investment/debt |
| `balance` | DECIMAL(15,2) | Số dư |
| `currency` | VARCHAR(10) DEFAULT 'VND' | Tiền tệ |
| `icon` | VARCHAR(50) | Icon |
| `colour` | VARCHAR(10) | Màu sắc |
| `is_default` | BOOLEAN | Ví mặc định? |
| `is_deleted` | BOOLEAN DEFAULT FALSE | Soft delete |
| `updated_at` | TIMESTAMP NOT NULL | Dùng cho LWW conflict |
| `created_at` | TIMESTAMP | |
| **Indexes** | `idaccount`, `updated_at` | |

##### Bảng Transaction (🆕 2026-08-11)
| Cột | Kiểu | Mô tả |
|-----|------|-------|
| `id` | VARCHAR(36) PK | UUID do client tạo |
| `idaccount` | INT FK→Account | Chủ sở hữu |
| `wallet_id` | VARCHAR(36) FK→Wallet | Ví chứa giao dịch |
| `category_id` | VARCHAR(36) NULL FK→Category | UUID của category (null cho transfer) |
| `amount` | DECIMAL(15,2) | Số tiền |
| `type` | VARCHAR(20) | thu/chi/transfer/adjustment |
| `note` | TEXT | Ghi chú |
| `date` | TIMESTAMP | Ngày giao dịch |
| `images` | TEXT DEFAULT '[]' | JSON array ảnh hóa đơn |
| `is_deleted` | BOOLEAN DEFAULT FALSE | Soft delete |
| `updated_at` | TIMESTAMP NOT NULL | Dùng cho LWW conflict |
| `created_at` | TIMESTAMP | |
| **Indexes** | `idaccount`, `wallet_id`, `date`, `updated_at` | |

##### Bảng Budget (🆕 2026-08-11)
| Cột | Kiểu | Mô tả |
|-----|------|-------|
| `id` | VARCHAR(36) PK | UUID do client tạo |
| `idaccount` | INT FK→Account | Chủ sở hữu |
| `category_id` | VARCHAR(36) NULL FK→Category | UUID danh mục |
| `amount` | DECIMAL(15,2) | Hạn mức |
| `period` | VARCHAR(20) DEFAULT 'monthly' | weekly/monthly/yearly |
| `start_date` / `end_date` | TIMESTAMP | Thời gian áp dụng |
| `is_deleted` | BOOLEAN DEFAULT FALSE | Soft delete |
| `updated_at` | TIMESTAMP NOT NULL | |
| **Indexes** | `idaccount` | |

##### Bảng Bill (🆕 2026-08-11)
| Cột | Kiểu | Mô tả |
|-----|------|-------|
| `id` | VARCHAR(36) PK | UUID do client tạo |
| `idaccount` | INT FK→Account | Chủ sở hữu |
| `name` | VARCHAR(100) | Tên hóa đơn |
| `amount` | DECIMAL(15,2) | Số tiền |
| `due_date` | TIMESTAMP | Ngày đến hạn |
| `is_paid` | BOOLEAN | Đã thanh toán? |
| `recurrence` | VARCHAR(20) DEFAULT 'monthly' | once/weekly/monthly/yearly |
| `is_deleted` | BOOLEAN DEFAULT FALSE | Soft delete |
| `updated_at` | TIMESTAMP NOT NULL | |
| **Indexes** | `idaccount` | |

##### Bảng Goal (🆕 2026-08-11)
| Cột | Kiểu | Mô tả |
|-----|------|-------|
| `id` | VARCHAR(36) PK | UUID do client tạo |
| `idaccount` | INT FK→Account | Chủ sở hữu |
| `name` | VARCHAR(100) | Tên mục tiêu |
| `target_amount` | DECIMAL(15,2) | Số tiền mục tiêu |
| `current_amount` | DECIMAL(15,2) DEFAULT 0 | Đã tiết kiệm |
| `target_date` | TIMESTAMP | Ngày đích |
| `is_completed` | BOOLEAN DEFAULT FALSE | Đã hoàn thành? |
| `is_deleted` | BOOLEAN DEFAULT FALSE | Soft delete |
| `updated_at` | TIMESTAMP NOT NULL | |
| **Indexes** | `idaccount` | |

#### 3.2.5 Xác Thực & Phân Quyền

- **JWT**: Access token + Refresh token
  - Admin: Access 15 phút, Refresh 7 ngày
  - User/Mobile: Access 7 ngày, Refresh 90 ngày
- **Token Rotation**: Mỗi lần refresh → revoke token cũ, cấp token mới
- **Reuse Detection**: Dùng token đã revoked → revoke toàn bộ token của user
- **RefreshToken lưu trong DB**: Bảng `RefreshToken`, hash SHA-256, không lưu plaintext
- **Middleware**: `authenticate` (bắt buộc), `authenticateOptional` (không bắt buộc), `authorize('admin'|'user')`
- **RBAC**: `idrole=1` (admin), `idrole=2` (user)
- **API Auth**:
  - `POST /api/auth/login` — Đăng nhập (public, dùng chung admin & user)
  - `POST /api/auth/refresh` — Làm mới token (public)
  - `GET /api/auth/me` — Lấy thông tin từ token (cần Bearer token)
  - `POST /api/auth/logout` — Đăng xuất, revoke tất cả token (cần Bearer token)

### 3.3 Kiến Trúc Client-app (Offline-first, Flutter)

| Tầng | Công nghệ / Pattern | Mô tả |
|------|---------------------|-------|
| **Local DB** | SQLite (sqflite/drift) | Mirror schema backend + `sync_status` (pending/synced/conflict) + `updated_at` |
| **Repository** | Repository Pattern | Abstract nguồn dữ liệu (local/remote), ưu tiên đọc local |
| **Sync Engine** | `POST /api/sync/push` + `GET /api/sync/pull` | Push mảng operations lên server (LWW) & pull data về |
| **Conflict Resolution** | Backend = source of truth | Ưu tiên theo timestamp, báo conflict nếu cần |
| **Real-time** | Socket.IO | Backend push sự kiện → client cập nhật local DB + UI |
| **State Management** | BLoC | Mỗi màn hình có BLoC riêng (loading/loaded/error) |

- **Trigger sync**: App vào foreground, sau mỗi thay đổi (debounce), chu kỳ 15 phút
- **Business logic**: Tính số dư ví, kiểm tra ngân sách, phân loại tạm thời → xử lý trên client

### 3.4 Kiến Trúc Admin-web (ReactJS + Vite)

| Đặc điểm | Công nghệ |
|----------|-----------|
| **SPA Routing** | React Router DOM v6 |
| **API calls** | Axios → REST endpoints của backend |
| **Real-time** | Socket.IO-client → lắng nghe sự kiện (user mới, job thất bại) |
| **UI Components** | Tailwind CSS v4 (Sử dụng native HTML elements, hoàn toàn không dùng UI Framework như Ant Design) |
| **Authentication** | JWT, lưu token trong localStorage và React Context |

#### 3.4.1 Cấu trúc & Nguyên tắc thiết kế Frontend
- **Tối ưu hóa UI/UX**: Loại bỏ hoàn toàn `antd` và các thư viện UI component framework. Giao diện được xây dựng bằng pure HTML tags kết hợp Tailwind CSS utility classes để tối ưu performance, rút gọn bundle size và đạt tính tùy biến cao nhất.
- **Tailwind CSS v4**: Tích hợp thông qua `@tailwindcss/postcss`. File cấu hình `tailwind.config.js` được giữ lại qua `@config` directive trong `index.css` để định nghĩa custom design tokens (mã màu, spacing, typography).
- **Responsive & Layout**: Sử dụng CSS Grid/Flexbox kết hợp các class tiện ích của Tailwind. Bố cục chính gồm `AppLayout` bao bọc `Sidebar` (menu điều hướng) và `Header` (hiển thị thông tin auth/actions).
- **State Management**: Sử dụng React Context (`AuthContext`) cho global state (thông tin user, trạng thái đăng nhập) và local state (`useState`, `useEffect`) cho các logic UI nội bộ tại từng trang (chẳng hạn: Filter Modal, Table Search, Data Fetching).

### 3.5 Luồng Dữ Liệu Điển Hình

#### 3.5.1 Người Dùng Tạo Giao Dịch (Offline)

```
Client: Tạo transaction (sync_status=pending) → SQLite → UI hiển thị ngay
  ↓ (khi có mạng)
Client: POST /api/sync/push (batch operations)
  ↓
Backend: Upsert transaction (LWW) → emit transaction.created
  ↓
AI Worker: Phân loại category (bất đồng bộ)
Notification Worker: Gửi thông báo (bất đồng bộ)
  ↓
Backend → Client: Thành công → sync_status=synced
  ↓
Client: GET /api/sync/pull → cập nhật từ thiết bị khác
```

#### 3.5.2 Tự Động Hóa Từ SMS (offline — Mobile)

```
SMS ngân hàng → Mobile đọc & parse (offline, không cần internet)
  ↓
Regex/NLP trích xuất (số tiền, nội dung, ngày)
  ↓
Tạo transaction tạm (sync_status=pending) → UI hiển thị ngay
  ↓ (khi có mạng)
SyncEngine: POST /api/sync/push → Backend upsert
```

#### 3.5.3 Đồng Bộ Hàng Loạt (Sync)

```
Client: POST /api/sync/push { operations: [{entity, operation, payload}] }
  ↓
Backend: Xử lý batch → LWW conflict → 200 OK { results: [...], summary: {...} }
  ↓
Backend → Client: Danh sách kết quả + conflicts → Client cập nhật local DB
  ↓
Client: GET /api/sync/pull?since=<timestamp> → kéo data từ thiết bị khác
```

### 3.6 Bảo Mật & Hiệu Suất

| Hạng mục | Giải pháp |
|----------|-----------|
| **Kết nối** | HTTPS toàn bộ |
| **Rate Limiting** | API nhạy cảm |
| **Input Validation** | Joi / Zod |
| **Logging** | Winston / Pino (request, lỗi, queue job) |
| **Monitoring** | Sentry (lỗi), Prometheus/Grafana (CPU, memory, queue size) |

### 3.7 Triển Khai (Deployment)

- **Containerization**: Docker + Docker Compose (local dev), Docker Swarm (production)
- **Services**: Backend, Redis, PostgreSQL, Admin-web (static files), BullMQ worker (cùng process Node.js với `worker_threads`)
- **Environment variables**: Quản lý cấu hình theo môi trường (dev, staging, prod)

### 3.8 Mở Rộng Tương Lai

Nếu traffic tăng → tách module thành microservices riêng, giao tiếp qua message broker (RabbitMQ/Kafka) để giảm coupling.

### 3.9 Chiến Lược Cắt Giảm Chi Phí

| Dịch vụ | Giải pháp miễn phí |
|----------|-------------------|
| **Redis** | Redis Cloud free tier (30MB) / Upstash Redis free / Oracle Cloud Always Free |
| **AI Phân loại** | Hugging Face API free / OpenAI credit free / tự train model nhỏ |
| **OCR** | Tesseract.js (miễn phí) / Google Cloud Vision (1000 ảnh/tháng free) |
| **Bank Integration** | Casso gói SPONSOR (free: 12 tài khoản + 100 giao dịch/tháng) |
| **SMS Parsing** | Regex trên client → giảm tải server |
| **Hosting** | Oracle Cloud Always Free (4 ARM core, 24GB RAM) / Google Cloud e2-micro |
| **Admin-web** | Serve từ Express static middleware hoặc Vercel/Netlify (miễn phí) |
| **Client-app** | Chỉ build APK, không tốn phí server |

---

## 4. Cấu Trúc Thư Mục Dự Án

### 4.1 Backend — 6 Module (Offline-first, Modular Monolithic)

> Backend chỉ đảm nhận các chức năng cần internet: xác thực, đồng bộ, ngân hàng, AI, thông báo, quản trị. Logic nghiệp vụ cốt lõi (ví, ngân sách, giao dịch, nợ, tiết kiệm…) nằm trên Client-app.

```
ManagementFinance/
└── src/
    └── Backend/
        ├── api/
        │   ├── index.js                   # Load & gắn tất cả router
        │   ├── auth.routes.js             # /auth/*
        │   ├── sync.routes.js             # /sync
        │   ├── bank.routes.js             # /bank/*
        │   ├── ai.routes.js               # /ai/*
        │   ├── notification.routes.js     # /notification/*
        │   └── admin.routes.js            # /admin/*
        │
        ├── config/
        │   ├── index.js                   # Tổng hợp cấu hình từ .env
        │   ├── db.js                      # Kết nối PostgreSQL (Prisma)
        │   └── redis.js                   # Kết nối Redis (ioredis)
        │
        ├── core/
        │   ├── event-bus.js               # Redis Pub/Sub event bus
        │   ├── queue.js                   # BullMQ (Queue, Worker) – singleton
        │   ├── logger.js                  # Winston logger
        │   └── response-handler.js        # Chuẩn hoá API response (success/error)
        │
        ├── middleware/
        │   ├── auth.js                    # Xác thực JWT, gán req.user
        │   ├── authorize.js               # Phân quyền (rolename)
        │   ├── rate-limiter.js            # Rate limiting
        │   ├── validator.js               # Validate request input
        │   └── error-handler.js           # Global error handler
        │
        ├── modules/
        │   ├── auth/   (controller, service, repository, validation)
        │   ├── admin/  (controller, service, repository, validation)
        │   ├── sync/   (controller, service, repository, validation, events)
        │   ├── bank/   (controller, service, repository, validation, jobs)
        │   ├── ai/     (controller, service, validation, jobs)
        │   └── notification/ (controller, service, validation, jobs)
        │
        ├── workers/                       # Process worker tách biệt (nếu muốn scale)
        │   ├── ai.worker.js
        │   ├── bank.worker.js
        │   └── notification.worker.js
        │
        ├── app.js                         # Express app: middleware, routes
        ├── index.js                       # Entrypoint: DB, Redis, start server
        .env
        package.json
        prisma/                            # Prisma schema + migrations
        └── Dockerfile
```

#### 📌 4.1.1. 6 Module Backend — Vai trò

> Backend đảm nhận 6 module cần internet. Các module nghiệp vụ còn lại (Category, Wallet, Transaction, Budget, Bill, Goal, Analytics) chạy trên Mobile — Backend chỉ đồng bộ/lưu trữ dữ liệu.

| Module | Chức năng chính |
|--------|-----------------|
| **auth** | Đăng ký, đăng nhập, cấp JWT, refresh token |
| **admin** | Quản lý user, quản lý danh mục mặc định, dashboard thống kê |
| **sync** | Nhận batch operations từ client, conflict resolution |
| **bank** | Liên kết ngân hàng (Casso), số dư, lịch sử giao dịch, webhook biến động số dư |
| **ai** | Phân loại GD, OCR, phân tích hành vi, dự báo, lời khuyên, chatbot |
| **notification** | Push notification (FCM/APNs), email |

### 4.2 Admin-web — React SPA (Vite + Tailwind CSS)

```
src/
└── Admin-web/
    ├── src/
    │   ├── api/                          # Axios client + API modules
    │   │   ├── axios-client.js
    │   │   ├── auth.api.js
    │   │   ├── admin.api.js
    │   │   └── sync.api.js
    │   ├── components/
    │   │   ├── layout/  (AppLayout, Sidebar, Header)
    │   │   └── common/  (Loading, EmptyState, ConfirmModal)
    │   ├── hooks/       (useAuth, useSocket, usePagination)
    │   ├── pages/
    │   │   ├── auth/       (LoginPage, ForgotPasswordPage)
    │   │   ├── dashboard/  (DashboardPage)
    │   │   ├── users/      (UserListPage, UserDetailPage)
    │   │   ├── categories/ (CategoryPage)
    │   │   └── system/     (ConfigPage, QueuePage)
    │   ├── router/      (index, ProtectedRoute, routes)
    │   ├── store/       (auth.context)
    │   ├── styles/      (theme.css)
    │   ├── utils/       (constants, format)
    │   ├── App.jsx
    │   ├── main.jsx
    │   └── index.css
    ├── index.html
    ├── vite.config.js
    └── package.json
```

### 4.3 Client-app (Flutter + SQLite)

<!-- TODO: Thành viên khác đảm nhiệm -->
## 5. Công Nghệ Sử Dụng (Tech Stack)

### 5.1. Mô tả chung
| Module | Framework / Language | Database / Tools | Notes |
|---|---|---|---|
| **Backend** | NodeJS + ExpressJS | PostgreSQL (CSDL chính), Redis + BullMQ (cache & queue) | Modular Monolithic, Event-Driven, Layer Pattern |
| **Admin-web** | ReactJS + Vite | Tailwind CSS, React Router DOM v6, Axios, Socket.IO-client | SPA, real-time event |
| **Client-app** | Dart + Flutter | SQLite (local DB), Dio (HTTP client), BloC (state management) | Offline-first, tự động đồng bộ real-time khi có internet |

### 5.2. Chi tiết công nghệ áp dụng Backend

#### 5.2.1. Các khái niệm

##### BullMQ

**BullMQ** là thư viện hàng đợi (queue) dành cho Node.js, xây dựng trên nền tảng Redis. Là phiên bản kế thừa hiện đại của thư viện Bull, được viết lại bằng TypeScript.

BullMQ giúp quản lý và xử lý các **tác vụ nền (background jobs)** như: gửi email hàng loạt, xử lý ảnh, xuất báo cáo dữ liệu, gọi AI phân loại, OCR hóa đơn, xử lý webhook ngân hàng.

**Đặc điểm:**
- **Tiết kiệm CPU**: Dùng Redis Stream pub/sub để Redis **chủ động thông báo** cho worker khi có job mới (không polling)
- **Hỗ trợ phân tán**: Nhiều worker trên nhiều server khác nhau, cùng truy cập Redis trung tâm để lấy job
- **Nhiều tính năng**: FIFO/LIFO, ưu tiên (priority), job trì hoãn (delayed), job lặp (repeatable cron), retry với backoff

**Trong dự án**: Backend sử dụng 4 queue (định nghĩa tại `core/queue.js`):
| Queue | Mục đích |
|-------|----------|
| `ai-classify-transaction` | Gọi AI phân loại danh mục cho giao dịch |
| `ocr-process-receipt` | Xử lý ảnh hóa đơn, trích xuất thông tin |
| `bank-webhook` | Xử lý webhook biến động số dư từ Casso |
| `send-notification` | Gửi email/push notification đến user |

> SMS parsing chạy **offline trên Mobile**; Sync xử lý **đồng bộ qua REST API** — không dùng queue.

##### Queue (Hàng đợi)

**Queue** là cấu trúc dữ liệu hoạt động theo nguyên tắc **FIFO (First In, First Out)**. Trong BullMQ, hàng đợi được **lưu trữ và quản lý tập trung trong Redis**. Worker kết nối đến Redis để lấy job về xử lý.

Khác với cấu trúc dữ liệu trong bộ nhớ:
- **BullMQ Queue**: Job được lưu trong Redis (bền vững, không mất khi restart server). Một job chỉ được **một** worker nhận và xử lý.
- Có retry, backoff, job progress tracking.

##### Event Bus (Redis Pub/Sub)

**Event Bus** là mô hình trung gian cho phép các module giao tiếp mà không cần biết trực tiếp về nhau. Dùng **Redis Pub/Sub** để thực hiện:

1. **Publisher**: Module emit event đến một channel (vd: `transaction.created`)
2. **Subscriber**: Worker/Module đăng ký lắng nghe channel đó
3. **Broadcast**: Redis phát tin nhắn đến **tất cả** subscriber đang lắng nghe

**Khác biệt cốt lõi với Queue:**
| Queue (BullMQ) | Event Bus (Pub/Sub) |
|----------------|---------------------|
| 1 job → 1 worker xử lý | 1 message → tất cả subscriber nhận |
| Job lưu trong Redis (bền vững) | Message tạm thời, nếu không có subscriber → mất |

**Trong dự án**: Event Bus được triển khai tại `core/event-bus.js`. Module emit event → Notification Worker subscribe → đẩy qua Socket.IO đến admin-web.

##### Socket.IO

**Socket.IO** là thư viện JavaScript cho phép giao tiếp **real-time, hai chiều, dựa trên sự kiện** giữa client và server.

**Đặc điểm:**
- **Real-time**: Chat trực tuyến, thông báo live, dashboard cập nhật dữ liệu real-time
- **Tự động nâng cấp kết nối**: Dùng WebSocket làm giao thức chính (độ trễ thấp). Nếu không hỗ trợ → tự động fallback sang long-polling
- **Kiến trúc hướng sự kiện**: Client và Server gửi/nhận sự kiện linh hoạt (`'new notification'`, `'user.created'`, `'job.failed'`)

**Trong dự án**: Socket.IO Server tích hợp trong backend → đẩy thông báo, audit log real-time, hiệu năng hệ thống, lượng request real-time lên admin-web. Admin-web dùng `socket.io-client` để lắng nghe.

##### Webhook + Jobs

**Webhook** là cơ chế để hệ thống bên ngoài (ngân hàng, dịch vụ thanh toán, SMS gateway...) chủ động gửi dữ liệu về backend thông qua HTTP callback. Thay vì backend phải liên tục kiểm tra (polling), webhook cho phép nhận dữ liệu ngay khi có sự kiện xảy ra.

**Luồng hoạt động:**
```
Ngân hàng (bên ngoài) → POST /api/bank/webhook (có sự kiện mới)
  ↓
Backend nhận webhook → validate payload → 200 OK (xác nhận đã nhận)
  ↓ (bất đồng bộ)
Enqueue job vào BullMQ (vd: bank-webhook, ai-classify-transaction)
  ↓
Worker pick job → xử lý → lưu DB → emit event qua Event Bus
```

**+ Jobs**: Kết hợp BullMQ để xử lý webhook bất đồng bộ, đảm bảo:
- Webhook response nhanh (200 OK trong vài ms), không block
- Job có retry nếu xử lý thất bại
- Có thể theo dõi trạng thái job (completed/failed)

**Trong dự án**: Module `bank` xử lý webhook biến động số dư từ Casso → tạo Transaction. Module `ai` xử lý OCR hóa đơn. Cả hai đều đẩy job vào BullMQ để worker xử lý bất đồng bộ.

##### REST API + Emit Event

Đây là pattern kết hợp **xử lý đồng bộ (REST)** và **phát sự kiện bất đồng bộ (Event Bus)** trong cùng một luồng nghiệp vụ.

**Luồng hoạt động:**
```
Client → POST /api/sync/push (gửi batch operations)
  ↓
Controller → Service: xử lý nghiệp vụ chính (lưu DB, validate)
  ↓
Trả về 200 OK cho client ngay                     ← REST (đồng bộ)
  ↓ (song song, không block response)
EventBus.publish('transaction.created', payload)  ← Emit Event (bất đồng bộ)
  ↓
Các subscriber lắng nghe:
  ├── AI Worker: phân loại danh mục giao dịch
  └── Notification Worker: gửi thông báo qua Socket.IO
```

**Nguyên tắc:**
- **REST API**: Xử lý core business, trả response ngay cho client
- **Emit Event**: Bắn sự kiện sau khi core business hoàn tất, để module khác phản ứng (không ảnh hưởng đến response time của API)

**Trong dự án**: Pattern này được áp dụng cho tất cả module có tác động liên module. Ví dụ: `sync` module nhận batch operations → lưu DB → emit `sync.completed` → Notification module gửi thông báo real-time.

#### 5.2.2. Cách áp dụng + luồng nghiệp vụ xử lý

##### 5.2.2.1. Tổng quan — Công nghệ nào dùng ở đâu

| Công nghệ | Module áp dụng | Vai trò cụ thể |
|-----------|---------------|----------------|
| **Express + REST API** | Tất cả 6 module | Nhận request từ admin-web & client-app |
| **BullMQ** | bank, ai, notification | Xử lý job nặng bất đồng bộ (OCR, AI, email, webhook) |
| **Event Bus (Redis Pub/Sub)** | Tất cả module | Phát sự kiện liên module (transaction.created, user.registered...) |
| **Socket.IO** | notification | Push real-time: thông báo, audit log, hiệu năng hệ thống |
| **Workers** | bank, ai, notification | Process độc lập lắng nghe BullMQ queue + Event Bus |

##### 5.2.2.2. Sơ đồ liên kết các công nghệ

```
┌─────────────────────────────────────────────────────────────┐
│                       REQUEST ĐẾN                           │
│  Admin-web (REST)          Client-app (REST)    Bank (Webhook)│
└────────┬──────────────────────┬──────────────────────┬──────┘
         │                      │                      │
         ▼                      ▼                      ▼
┌─────────────────────────────────────────────────────────────┐
│                   EXPRESS ROUTER                            │
│  /auth/*  /admin/*  /sync  /bank/*  /ai/*  /notification/* │
└────────┬────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│              CONTROLLER → SERVICE → REPOSITORY              │
│  Xử lý nghiệp vụ chính (đồng bộ, trả response ngay)       │
└────────┬──────────────────────────────────────┬─────────────┘
         │                                      │
         │ (job nặng)                           │ (sự kiện nhẹ)
         ▼                                      ▼
┌─────────────────────┐              ┌─────────────────────────┐
│      BULLMQ         │              │     EVENT BUS           │
│  (Redis Queue)      │              │  (Redis Pub/Sub)        │
│                     │              │                         │
│  ai-classify        │              │  transaction.created    │
│  ocr-process        │              │  user.registered        │
│  bank-webhook       │              │  sync.completed         │
│  send-notification  │              │  transaction.classified │
│                     │              │  bank.webhook.received  │
└────────┬────────────┘              └────────┬────────────────┘
         │                                    │
         ▼                                    ▼
┌─────────────────────┐              ┌─────────────────────────┐
│     WORKERS         │              │  NOTIFICATION WORKER    │
│  (xử lý job)        │              │  (subscribe event)      │
│                     │              │          │              │
│  ai.worker.js       │              │          ▼              │
│  bank.worker.js     │              │    SOCKET.IO SERVER     │
│  notification.w.js  │              │          │              │
└────────┬────────────┘              │          ▼              │
         │                           │    ADMIN-WEB            │
         │ (job xong → emit event)   │    (real-time UI)       │
         └───────────────────────────┘                         │
                                                               │
┌──────────────────────────────────────────────────────────────┘
```

##### 5.2.2.3. Luồng nghiệp vụ theo từng module

**Module Auth** — Xác thực (REST API thuần)

```
Client → POST /api/auth/login
  → validator (kiểm tra input)
  → authController.login()
  → authService.login()
    → authRepository.findAccountByUsername() [DB: Account + Role + User]
    → bcrypt.compare(password, hash)
    → jwt.sign() → {accessToken, refreshToken}
    → hash(refreshToken) → lưu RefreshToken table
    → 200 OK {accessToken, refreshToken, user}
```

> Auth module **không** dùng BullMQ hay Event Bus — hoàn toàn đồng bộ.

**Module Admin** — Quản trị (REST API + CRUD)

```
Admin-web → GET /api/admin/getuser
  → authenticate + authorize('admin')
  → adminController.getUsers()
  → adminService.getUsers()
  → adminRepository.getAllUsers() [DB: User JOIN Account WHERE idrole=2]
  → 200 OK [{id, fullname, email, status...}]

Admin-web → PATCH /api/admin/updatestatus/:id
  → authenticate + authorize('admin')
  → adminController.updateStatus()
  → adminService.updateStatus(id)
    → getUserById() → kiểm tra tồn tại + current status
    → updateAccountStatus(id, newStatus) [DB: UPDATE account SET status]
    → 200 OK {previousStatus, newStatus}
```

> Admin module hiện tại chưa emit event. Sau này có thể emit `user.status.changed` → Notification Worker → Socket.IO → admin-web.

**Module Sync** — Đồng bộ (REST API + Emit Event)

```
Client-app → POST /api/sync/push {operations: [{entity, operation, payload}...]}
  → authenticate (user)
  → syncController.push()
  → syncService.processPush()
    → Xử lý tuần tự từng operation (LWW conflict resolution)
    → Lưu kết quả (synced/conflict/error)
    → 200 OK {results: [...], summary: {...}}
    → EventBus.publish('sync.completed', {idaccount, summary})
       ↓
       Notification Worker subscribe → Socket.IO → admin-web

Client-app → GET /api/sync/pull?since=<timestamp>
  → syncController.pull() → syncService.processPull()
    → 200 OK {data: {wallets, transactions, ...}}
```

**Module Bank** — Ngân hàng (Casso + Webhook + BullMQ Jobs)

```
Casso → POST /api/bank/webhook (biến động số dư: transaction_id, amount, transfer_type...)
  → bankController.receiveWebhook()
  → verify signature → 200 OK (xác nhận đã nhận, không xử lý ngay)
  → Enqueue job vào BullMQ: bank-webhook
     ↓
     bank.worker.js pick job
     → Chống trùng (UNIQUE provider + transaction_id)
     → Tạo Transaction (dedupe) + EventBus.publish('transaction.created')
        ↓
        Notification Worker → Socket.IO → admin-web
```

**Module AI** — Trí tuệ nhân tạo (REST API + BullMQ Jobs)

```
Client-app → POST /api/ai/classify {transactionId, description}
  → aiController.requestClassify()
  → 202 Accepted (xếp hàng, chưa có kết quả)
  → Enqueue job vào BullMQ: ai-classify-transaction
     ↓
     ai.worker.js pick job
     → Gọi AI model (OpenAI/Hugging Face) phân loại danh mục
     → Cập nhật category cho transaction trong DB
     → EventBus.publish('transaction.classified', {transactionId, category})
        ↓
        Notification Worker → Socket.IO → admin-web
```

**Module Notification** — Thông báo (Event Bus + Socket.IO)

```
Worker lắng nghe Event Bus:
  ├── 'user.registered'    → gửi email welcome
  ├── 'transaction.created'→ push notification (FCM/APNs)
  ├── 'sync.completed'     → Socket.IO → admin-web
  ├── 'job.failed'         → Socket.IO → admin-web (cảnh báo)
  └── 'bank.webhook.received' → Socket.IO → admin-web

Notification Worker:
  EventBus.subscribe('sync.completed', (data) => {
    // Gửi qua Socket.IO
    io.to('admin-room').emit('notification', {
      type: 'sync',
      message: `Đồng bộ hoàn tất: ${data.stats.total} operations`,
      data
    });
  });
```

##### 5.2.2.4. Tương tác giữa các module qua Event Bus

| Event Name | Phát từ module | Nhận bởi | Hành động |
|------------|---------------|----------|-----------|
| `user.registered` | auth | notification | Gửi email welcome |
| `transaction.created` | sync / bank | ai, notification | AI phân loại, push thông báo |
| `transaction.classified` | ai | notification | Socket.IO → admin-web |
| `sync.completed` | sync | notification | Socket.IO → admin-web |
| `job.failed` | workers | notification | Socket.IO → admin-web (cảnh báo) |
| `bank.webhook.received` | bank | notification | Socket.IO → admin-web (audit log) |
| `user.status.changed` | admin | notification | Socket.IO → admin-web |


### 5.3. Chi tiết công nghệ áp dụng Admin-Web

#### 5.3.1. Các khái niệm

#### 5.3.2. Cách áp dụng + luồng nghiệp vụ xử lý

### 5.4. Chi tiết công nghệ áp dụng Client-App

#### 5.4.1. Các khái niệm

#### 5.4.2. Cách áp dụng + luồng nghiệp vụ xử lý

---

## 6. Chức Năng Chính (Features)

> Các chức năng được xây dựng tại **Backend**, **Mobile**, hoặc **Backend + Mobile** tùy theo nhu cầu người dùng. Phân loại thành **3 nhóm chính với 13 module**.

### Nhóm A — Domain Modules (Nghiệp vụ cốt lõi)

#### A1. User Management
| STT | Chức năng | Location | Actor |
|-----|-----------|----------|-------|
| 1 | Đăng ký | Backend | User |
| 2 | Đăng nhập | Backend + Mobile | Admin + User |
| 3 | Đăng xuất | Backend + Mobile | Admin + User |
| 4 | Đổi mật khẩu | Backend + Mobile | Admin + User |
| 5 | Quên mật khẩu | Mobile | User |
| 6 | Yêu cầu xóa tài khoản | Mobile | User |
| 7 | Quản lý Profile cá nhân | Mobile | User |

#### A2. Category Management
| STT | Chức năng | Location | Actor |
|-----|-----------|----------|-------|
| 1 | Quản lý danh mục cá nhân | Mobile | User |
| 2 | Phân loại danh mục (thu / chi / vay-nợ) | Mobile | User |
| 3 | Gom nhóm danh mục | Mobile | User |
| 4 | Thiết lập từ khóa nhận diện danh mục (dùng cho cả AI & NoAI) | Mobile | User |
| 5 | Phân loại danh mục | Mobile | User |

#### A3. Wallet Management
| STT | Chức năng | Location | Actor |
|-----|-----------|----------|-------|
| 1 | Quản lý ví ảo (Thêm, xóa, sửa) | Mobile | User |
| 2 | Thiết lập ví ảo mặc định | Mobile | User |
| 3 | Kích hoạt / vô hiệu hóa ví | Mobile | User |
| 4 | Liên kết ngân hàng | Backend + Mobile | User |

#### A4. Transaction Management
| STT | Chức năng | Location | Actor |
|-----|-----------|----------|-------|
| 1 | Quản lý giao dịch thủ công (Thêm, xóa, sửa) | Mobile | User |
| 2 | Xem danh sách giao dịch | Mobile | User |
| 3 | Chuyển tiền nội bộ | Mobile | User |
| 4 | Tạo giao dịch từ SMS | Mobile | User |
| 5 | Tạo giao dịch từ OCR (offline) | Mobile | User |
| 6 | Tạo giao dịch từ biến động số dư NH (webhook) | Backend | User |
| 7 | Khử trùng lặp dữ liệu | Backend + Mobile | User |

#### A5. Budget Management
| STT | Chức năng | Location | Actor |
|-----|-----------|----------|-------|
| 1 | Quản lý ngân sách (Thêm, xóa, sửa) | Mobile | User |
| 2 | Thiết lập ngưỡng cảnh báo | Mobile | User |
| 3 | Thiết lập quy tắc phân bổ ngân sách | Mobile | User |
| 4 | Xem lịch sử giao dịch ngân sách | Mobile | User |

#### A6. Bill & Subscription Management
| STT | Chức năng | Location | Actor |
|-----|-----------|----------|-------|
| 1 | Quản lý hóa đơn | Mobile | User |
| 2 | Liên kết tài khoản thanh toán | Mobile | User |
| 3 | Thiết lập thanh toán định kỳ | Mobile | User |
| 4 | Xem lịch sử thanh toán | Mobile | User |

#### A7. Goal Management
| STT | Chức năng | Location | Actor |
|-----|-----------|----------|-------|
| 1 | Quản lý mục tiêu tài chính (Thêm, xóa, sửa) | Mobile | User |
| 2 | Tự động tạo giao dịch tiết kiệm (Schedule) | Mobile | User |
| 3 | Dự đoán thời gian hoàn thành | Mobile | User |

#### A8. Analytics & Reporting
| STT | Chức năng | Location | Actor |
|-----|-----------|----------|-------|
| 1 | Tổng hợp kết quả thu chi | Mobile | User |
| 2 | So sánh tỷ trọng Phân loại danh mục — biểu đồ tròn (thu, chi, vay/nợ) | Mobile | User |
| 3 | So sánh tỷ trọng Loại danh mục — biểu đồ tròn | Mobile | User |
| 4 | So sánh tỷ lệ Cho vay + thu nợ — Biểu đồ cột | Mobile | User |
| 5 | So sánh tỷ lệ Đi vay + Trả nợ — Biểu đồ cột | Mobile | User |
| 6 | Xu hướng dòng tiền theo Phân loại danh mục (thu chi) — Biểu đồ đường (2 đường thu chi) | Mobile | User |
| 7 | Xu hướng dòng tiền theo loại danh mục — Biểu đồ đường (1 đường) | Mobile | User |
| 8 | Xu hướng của dòng tiền tự do (thu nhập sau khi trả nợ) | Mobile | User |
| 9 | Biến động của Khoản vay qua các kỳ (Đi vay + Lãi vay) | Mobile | User |
| 10 | Image1.png | Mobile | User |
| 11 | Image2.png | Mobile | User |

### Nhóm B — Capability Modules (Năng lực hỗ trợ xuyên suốt)

#### B9. AI
| STT | Chức năng | Location | Actor |
|-----|-----------|----------|-------|
| 1 | Chatbot AI | Backend | User |
| 2 | OCR AI | Backend | User |
| 3 | AI phân loại giao dịch | Backend | User |
| 4 | AI phân tích hành vi chi tiêu | Backend | User |
| 5 | AI dự báo chi tiêu | Backend | User |
| 6 | AI đưa ra lời khuyên tài chính | Backend | User |
| 7 | AI đề xuất quy tắc phân bổ dòng tiền (Budget + Goal) | Backend | User |

#### B10. Notification
> Phát sinh dần trong quá trình làm & ghi nhận sau.

| STT | Chức năng | Location | Actor |
|-----|-----------|----------|-------|
| … | … | Backend + Mobile | User + Admin |

#### B11. Sync
| STT | Chức năng | Location | Actor |
|-----|-----------|----------|-------|
| 1 | Đồng bộ dữ liệu Mobile → Backend (push, LWW) | Backend + Mobile | User |
| 2 | Đồng bộ dữ liệu Backend → Mobile (pull — xóa app tải lại) | Backend + Mobile | User |

#### B12. Bank
| STT | Chức năng | Location | Actor |
|-----|-----------|----------|-------|
| 1 | Liên kết ngân hàng (OAuth Casso) | Backend + Mobile | User |
| 2 | Quản lý liên kết ngân hàng (xem/hủy) | Backend + Mobile | User + Admin |
| 3 | Lấy danh sách Ngân hàng + số dư | Backend | User |
| 4 | Lấy lịch sử giao dịch | Backend | User |
| 5 | Nhận giao dịch realtime (webhook) | Backend | User |

### Nhóm C — Platform (Quản trị hệ thống)

#### C13. Admin
| STT | Chức năng | Location | Actor |
|-----|-----------|----------|-------|
| 1 | Quản lý người dùng (xem/khóa/mở khóa) | Backend | Admin |
| 2 | Quản lý danh mục mặc định (Thêm, xóa, sửa, đồng bộ) | Backend | Admin |
| 3 | Dashboard thống kê | Backend | Admin |

> Một vài chức năng khác như backup/restore v.v… sẽ bổ sung sau.

---

## 7. Đặc Tả & Yêu Cầu Nghiệp Vụ & API

> Định danh theo **Module + Chức năng** (bỏ mã F). Module chưa triển khai chỉ tạo khung — bổ sung đặc tả chi tiết khi bắt đầu build.

### 7.1 A1 — User Management

#### 7.1.1 Đăng nhập — Thông tin chung

| Thuộc tính | Giá trị |
|------------|---------|
| **Mã chức năng** | A1 — Đăng nhập |
| **Tên chức năng** | Đăng nhập hệ thống |
| **Actor chính** | Admin, User |
| **Actor phụ** | Hệ thống (Backend, CSDL) |
| **Mức độ ưu tiên** | Cao (bắt buộc) |
| **Trạng thái** | ✅ Đã hoàn thành |
| **Phiên bản** | v1.0 — 2026-08-01 |

#### 7.1.2 Tiền điều kiện (Pre-conditions)

| # | Điều kiện |
|---|-----------|
| P1 | Tài khoản đã tồn tại trong bảng `Account` với `status = 'Active'` |
| P2 | CSDL PostgreSQL đang hoạt động |
| P3 | Frontend (Admin-web) đã được build và chạy trên trình duyệt |
| P4 | Người dùng chưa đăng nhập (chưa có token hợp lệ trong localStorage) |

#### 7.1.3 Hậu điều kiện (Post-conditions)

| # | Kết quả |
|---|--------|
| H1 | Access Token (JWT) được cấp và lưu vào localStorage của Admin-web |
| H2 | Refresh Token (JWT) được cấp, hash SHA-256 và lưu vào bảng `RefreshToken` |
| H3 | Người dùng được chuyển hướng đến trang Dashboard (`/dashboard`) |
| H4 | Các request tiếp theo tự động gắn `Authorization: Bearer <accessToken>` |
| H5 | Admin-web kiểm tra `rolename === 'admin'` — nếu không phải admin, từ chối vào |

#### 7.1.4 Luồng nghiệp vụ chính (Happy Path)

```
Bước 1: Người dùng truy cập URL http://localhost:5173/login
        → Admin-web hiển thị form đăng nhập (username, password)

Bước 2: Người dùng nhập username + password, nhấn nút "Đăng nhập"
        → LoginPage.handleSubmit() được gọi

Bước 3: Frontend gọi POST /api/auth/login
        Body: { "username": "admin", "password": "123456" }

Bước 4: Backend nhận request → auth.validation.js kiểm tra:
        - username: required, string, 1-50 ký tự
        - password: required, string, 6-100 ký tự
        → Nếu không hợp lệ → 400 Bad Request

Bước 5: auth.controller.js → auth.service.login()
        a) auth.repository.findAccountByUsername() → query bảng Account + JOIN Role + User
        b) Kiểm tra account tồn tại → nếu không → 401 "Sai tài khoản hoặc mật khẩu"
        c) Kiểm tra status === 'Active' → nếu không → 403 "Tài khoản đã bị vô hiệu hóa"
        d) bcrypt.compare(password, account.password) → nếu sai → 401
        e) Tạo JWT payload: { idaccount, username, idrole, rolename }
        f) generateTokens(payload, idrole):
           - idrole=1 (admin): Access 15 phút, Refresh 7 ngày
           - idrole=2 (user):  Access 7 ngày, Refresh 90 ngày
        g) saveRefreshToken(refreshToken, payload, req):
           - Hash SHA-256 token → token_hash
           - Insert vào bảng RefreshToken (kèm IP, User-Agent, device_name)
        h) Trả về { accessToken, refreshToken, user }

Bước 6: Frontend nhận response 200 OK
        a) Lưu accessToken, refreshToken, user vào localStorage
        b) Cập nhật AuthContext: setUser(user), setIsAuthenticated(true)
        c) Nếu rolename !== 'admin' → từ chối, hiển thị lỗi
        d) navigate('/dashboard') → ProtectedRoute kiểm tra token → cho qua

Bước 7: Người dùng thấy giao diện Dashboard
```

#### 7.1.5 Luồng nghiệp vụ phụ (Alternative Flows)

**AF1 — Sai mật khẩu**
```
Bước 5d: bcrypt.compare() trả về false
→ Backend: 401 "Sai tài khoản hoặc mật khẩu"
→ Frontend: Hiển thị thông báo lỗi đỏ dưới form
→ Người dùng nhập lại
```

**AF2 — Tài khoản không tồn tại**
```
Bước 5b: findAccountByUsername() → null
→ Backend: 401 "Sai tài khoản hoặc mật khẩu"
→ Frontend: Hiển thị lỗi (không tiết lộ username có tồn tại hay không)
```

**AF3 — Tài khoản bị vô hiệu hóa**
```
Bước 5c: account.status !== 'Active'
→ Backend: 403 "Tài khoản đã bị vô hiệu hóa"
→ Frontend: Hiển thị lỗi, không cho đăng nhập
```

**AF4 — Tài khoản user cố vào Admin-web**
```
Bước 6c: Frontend kiểm tra user.rolename !== 'admin'
→ Hiển thị lỗi "Tài khoản không có quyền truy cập quản trị"
→ Xóa token, không chuyển hướng
```

**AF5 — Token hết hạn**
```
Khi Access Token hết hạn (admin: 15 phút, user: 7 ngày):
→ Frontend gọi POST /api/auth/refresh với Refresh Token
→ Backend: token rotation → revoke token cũ → cấp token mới
→ Frontend: cập nhật token mới vào localStorage
→ Nếu Refresh Token cũng hết hạn → redirect /login
```

**AF6 — Reuse Detection (phát hiện tấn công)**
```
Kẻ tấn công dùng Refresh Token đã bị revoked:
→ Backend phát hiện token_hash đã revoked = TRUE
→ Tự động revoke TOÀN BỘ token của idaccount đó
→ 401 "Refresh token không hợp lệ"
→ Người dùng thật phải đăng nhập lại
```

#### 7.1.6 API Endpoints liên quan

| Endpoint | Method | Auth | Mô tả |
|----------|--------|------|-------|
| `/api/auth/login` | POST | Public | Đăng nhập → cấp token |
| `/api/auth/refresh` | POST | Public | Làm mới token (rotation) |
| `/api/auth/me` | GET | Bearer | Kiểm tra token hợp lệ |
| `/api/auth/logout` | POST | Bearer | Revoke tất cả token |

#### 7.1.7 Files liên quan

| Tầng | File |
|------|------|
| **Frontend** | `pages/auth/LoginPage.jsx` |
| | `pages/auth/ForgotPasswordPage.jsx` |
| | `store/auth.context.jsx` |
| | `api/auth.api.js` |
| | `api/axios-client.js` |
| | `router/ProtectedRoute.jsx` |
| | `components/layout/Sidebar.jsx` |
| **Backend** | `modules/auth/auth.controller.js` |
| | `modules/auth/auth.service.js` |
| | `modules/auth/auth.repository.js` |
| | `modules/auth/auth.validation.js` |
| | `api/auth.routes.js` |
| | `middleware/auth.js` |
| | `middleware/authorize.js` |
| **CSDL** | `database/)1_CSDL_Admin.sql` (Role, Account, User) |
| | `database/)2_create_refreshtoken_table.sql` (RefreshToken) |

### 7.2 A2 — Category Management

⏳ Chưa đặc tả — bổ sung khi triển khai.

### 7.3 A3 — Wallet Management

⏳ Chưa đặc tả — bổ sung khi triển khai.

### 7.4 A4 — Transaction Management

⏳ Chưa đặc tả — bổ sung khi triển khai.

### 7.5 A5 — Budget Management

⏳ Chưa đặc tả — bổ sung khi triển khai.

### 7.6 A6 — Bill & Subscription Management

⏳ Chưa đặc tả — bổ sung khi triển khai.

### 7.7 A7 — Goal Management

⏳ Chưa đặc tả — bổ sung khi triển khai.

### 7.8 A8 — Analytics & Reporting

⏳ Chưa đặc tả — bổ sung khi triển khai.

### 7.9 B9 — AI

⏳ Chưa đặc tả — chi tiết build xem Section 8.5.

### 7.10 B10 — Notification

⏳ Chưa đặc tả — phát sinh dần trong quá trình làm & ghi nhận sau.

### 7.11 B11 — Sync (✅ MVP)

#### 7.11.1 Thông tin chung

| Thuộc tính | Giá trị |
|------------|---------|
| **Mã chức năng** | B11 — Đồng bộ dữ liệu |
| **Tên chức năng** | Đồng bộ dữ liệu Client-Server |
| **Actor chính** | User (Mobile-app) |
| **Mức độ ưu tiên** | Cao |
| **Trạng thái** | ✅ Đã hoàn thành (MVP) |
| **Phiên bản** | v1.0 — 2026-08-12 |

#### 7.11.2 Mô tả

- **Push**: Client gửi batch operations (create/update/delete) lên server. Backend xử lý LWW conflict resolution, trả kết quả từng operation.
- **Pull**: Client kéo data mới từ server theo `since` timestamp, có thể filter theo entity.
- **Status**: Client kiểm tra trạng thái sync (số lượng record mỗi entity).

**Nguyên tắc**:
- Client tự tạo UUID cho mọi record (Backend không sinh ID)
- LWW (Last-Write-Wins): so sánh `updated_at`, bản mới hơn thắng
- Soft delete: set `is_deleted=true`, không DELETE thật
- Ownership: `payload.idaccount` phải khớp JWT token
- Category: system default (is_default=true) không được sửa/xóa từ client
- Idempotent: push cùng record nhiều lần không lỗi
- Batch limit: tối đa 1000 operations/push

#### 7.11.3 API Endpoints

| Endpoint | Method | Auth | Mô tả |
|----------|--------|------|-------|
| `/api/sync/push` | POST | Bearer (user) | Nhận batch operations, upsert với LWW |
| `/api/sync/pull?since=&entities=` | GET | Bearer (user) | Trả data mới cho client |
| `/api/sync/status` | GET | Bearer (user) | Trạng thái sync (entity counts) |

#### 7.11.4 Request/Response

**POST /api/sync/push**:
```json
// Request
{
  "clientId": "device-uuid",
  "pushedAt": "2026-08-12T10:30:00.000Z",
  "operations": [{
    "localId": "op-001",
    "entity": "wallet|transaction|budget|bill|goal|category",
    "operation": "create|update|delete",
    "payload": { "id": "uuid", "idaccount": 1, "updated_at": "...", ... }
  }]
}

// Response
{
  "success": true,
  "data": {
    "clientId": "device-uuid",
    "results": [
      { "localId": "op-001", "status": "synced|conflict|error", "serverRecord?": {...} }
    ],
    "summary": { "total": 3, "synced": 2, "conflicts": 1, "errors": 0 },
    "serverTime": "2026-08-12T10:30:01.000Z"
  }
}
```

**GET /api/sync/pull?since=ISO&entities=wallet,transaction**:
```json
{
  "success": true,
  "data": {
    "pulledAt": "2026-08-12T10:30:05.000Z",
    "hasMore": false,
    "maxSince": { "wallet": "2026-08-12T09:00:00.000Z" },
    "data": { "wallets": [...], "transactions": [...], ... }
  }
}
```

**GET /api/sync/status**:
```json
{
  "success": true,
  "data": {
    "idaccount": 1,
    "lastSyncAt": "2026-08-12T10:30:01.000Z",
    "entities": {
      "wallets": { "count": 2 },
      "transactions": { "count": 150 },
      "budgets": { "count": 3 },
      "bills": { "count": 5 },
      "goals": { "count": 1 },
      "categories": { "count": 28 }
    }
  }
}
```

#### 7.11.5 Conflict Resolution Logic

```
Nếu record chưa tồn tại → INSERT → status: 'synced'
Nếu record tồn tại:
  - clientTime > serverTime → UPSERT → status: 'synced'
  - clientTime ≤ serverTime → giữ server → status: 'conflict' + serverRecord
  - operation='delete':
    - 5 entity (wallet/txn/budget/bill/goal) → UPDATE is_deleted=true
    - category → DELETE (hard, chỉ user-created, cấm system default)
```

#### 7.11.6 Files liên quan

| Tầng | File |
|------|------|
| **Backend** | `api/sync.routes.js` |
| | `modules/sync/sync.controller.js` |
| | `modules/sync/sync.service.js` |
| | `modules/sync/sync.repository.js` |
| | `modules/sync/sync.validation.js` |
| | `modules/sync/sync.events.js` (placeholder) |

### 7.12 B12 — Bank

⏳ Chưa đặc tả — chi tiết build xem Section 8.4.

### 7.13 C13 — Admin

#### 7.13.1 Dashboard — Thống kê hệ thống (🚧)

| Thuộc tính | Giá trị |
|------------|---------|
| **Mã chức năng** | C13 — Dashboard |
| **Trạng thái** | 🚧 Đang phát triển |

**Nguyên tắc chung**:
- 3 lựa chọn thống kê: **Hôm nay**, **7 ngày**, **30 ngày**; mặc định **Hôm nay**
- Các API tổng (không phụ thuộc thời gian) chỉ gọi 1 lần khi mount
- Tất cả API dashboard yêu cầu `authenticate` + `authorize('admin')`
- Chỉ tính user (`idrole = 2`), không tính admin (`idrole = 1`)

| Endpoint | Method | Mô tả |
|----------|--------|-------|
| `/api/admin/totaluser` | GET | Tổng số người dùng |
| `/api/admin/totalcategories` | GET | Tổng số danh mục |
| `/api/admin/getusertotime?period=` | GET | Người dùng mới + tăng trưởng theo kỳ (today/7days/30days) |

#### 7.13.2 Quản lý người dùng (✅)

| Endpoint | Method | Mô tả |
|----------|--------|-------|
| `/api/admin/getuser` | GET | Danh sách người dùng (idrole=2) |
| `/api/admin/getuser/:id` | GET | Chi tiết người dùng theo iduser |
| `/api/admin/updatestatus/:id` | PATCH | Toggle trạng thái Active↔Inactive |

#### 7.13.3 Quản lý danh mục mặc định (✅)

| Endpoint | Method | Mô tả |
|----------|--------|-------|
| `/api/admin/getcategory` | GET | Danh sách danh mục |
| `/api/admin/addcategory` | POST | Thêm danh mục |
| `/api/admin/updatecategory/:id` | PUT | Sửa danh mục |
| `/api/admin/deletecategory/:id` | DELETE | Xóa danh mục |

**Mapping classify ↔ type**: `income`↔`thu`, `expense`↔`chi`, `debt`↔`vay/no`

#### 7.13.4 Files liên quan

| Tầng | File |
|------|------|
| **Backend** | `modules/admin/admin.controller.js`, `admin.service.js`, `admin.repository.js`, `api/admin.routes.js` |
| **Frontend** | `pages/dashboard/DashboardPage.jsx`, `pages/users/UserListPage.jsx`, `pages/categories/CategoryPage.jsx`, `api/admin.api.js` |


## 8. Build Module Backend

> Backend gồm 6 module: Auth, Admin, Sync, Bank, AI, Notification. Đặc tả nghiệp vụ chi tiết xem Section 7.

### 8.1. Module Auth — ✅ Done

Module xác thực & quản lý người dùng (phần backend). Đặc tả chi tiết: **Section 7.1 A1**.

| Endpoint | Method | Trạng thái |
|----------|--------|-----------|
| `/api/auth/login` | POST | ✅ |
| `/api/auth/register` | POST | ✅ |
| `/api/auth/refresh` | POST | ✅ |
| `/api/auth/me` | GET | ✅ |
| `/api/auth/logout` | POST | ✅ |

**Files**: `modules/auth/auth.controller.js`, `auth.service.js`, `auth.repository.js`, `auth.validation.js`, `api/auth.routes.js`

### 8.2. Module Admin — ✅ Done

Module quản trị (dashboard, user, danh mục mặc định). Đặc tả chi tiết: **Section 7.13 C13**.

| Nhóm | Endpoints |
|------|-----------|
| Dashboard | `/api/admin/totaluser`, `/api/admin/totalcategories`, `/api/admin/getusertotime` |
| User | `/api/admin/getuser`, `/api/admin/getuser/:id`, `/api/admin/updatestatus/:id` |
| Category | `/api/admin/getcategory`, `/api/admin/addcategory`, `/api/admin/updatecategory/:id`, `/api/admin/deletecategory/:id` |

**Files**: `modules/admin/admin.controller.js`, `admin.service.js`, `admin.repository.js`, `api/admin.routes.js`

### 8.3. Module Sync — ✅ Done (MVP — 2026-08-12)

#### 8.3.1. Tổng quan

| Chức năng | Endpoint | Trạng thái |
|----------|----------|-----------|
| Nhận batch operations từ client | `POST /api/sync/push` | ✅ Done |
| Trả data mới cho client | `GET /api/sync/pull` | ✅ Done |
| Trạng thái sync | `GET /api/sync/status` | ✅ Done |

**Mô hình**: Client-Led Sync (Offline-First), Client tự tạo UUID, Backend là source of truth.

**6 entity được sync**: wallet, transaction, budget, bill, goal, category — tất cả dùng UUID PK, thống nhất LWW conflict resolution.

**Files đã implement (2026-08-12):**

| File | Vai trò |
|------|---------|
| `api/sync.routes.js` | `POST /push`, `GET /pull`, `GET /status` + `authenticate` |
| `modules/sync/sync.controller.js` | Xử lý request/response, gọi service |
| `modules/sync/sync.service.js` | Core: processPush (LWW), processPull (filter), getStatus |
| `modules/sync/sync.repository.js` | CRUD 6 entity: upsert, pull, softDelete, count |
| `modules/sync/sync.validation.js` | Validate push/pull payload, UUID format, entity types |

#### 8.3.2. Nguyên tắc thiết kế

| Nguyên tắc | Cách làm |
|------------|----------|
| **Client tự tạo UUID** | Backend không sinh ID, chỉ validate UUID format |
| **Last-Write-Wins (LWW)** | So sánh `updated_at` — bản mới hơn thắng |
| **Soft delete** | Không DELETE, chỉ set `is_deleted = true` |
| **Idempotent** | Push cùng record nhiều lần không lỗi |
| **Ownership check** | `payload.idaccount` phải khớp với JWT token |

#### 8.3.3. Conflict Resolution Logic

```
Nếu record chưa tồn tại → INSERT → status: 'synced'
Nếu record tồn tại:
  - clientTime > serverTime → UPSERT → status: 'synced'
  - clientTime ≤ serverTime → giữ server → status: 'conflict' + serverRecord
  - operation='delete' → UPDATE is_deleted=true (soft delete)
```

#### 8.3.4. Thứ tự triển khai

| Giai đoạn | API | Mô tả | Trạng thái |
|-----------|-----|-------|-----------|
| **S1** | — | Nền móng: routes + controller + validation | ✅ Done |
| **S2** | `POST /push` | Batch upsert với LWW conflict resolution | ✅ Done |
| **S3** | `GET /pull` | Query data theo since + entities filter | ✅ Done |
| **S4** | Security | Ownership check + input validation | ✅ Done |
| **S5** | `GET /status` | Trạng thái sync | ✅ Done |

> ✅ **Sync Module MVP hoàn thành — 2026-08-12**: 10/10 test cases pass. 6 entity dùng chung pattern LWW. Tạm dừng ở mức MVP — sẵn sàng cho Client-app tích hợp.

#### 8.3.5. Giai đoạn 2 — Enhancements (đề xuất, chưa làm)

| Mã | Enhancement | Mô tả | Ưu tiên |
|----|-------------|-------|---------|
| **E1** | Real-time push | Socket.IO báo client khi có data mới từ thiết bị khác | 🔴 Cao |
| **E2** | Pagination cho pull | `limit` + `cursor` tránh quá tải | 🟡 Trung bình |
| **E3** | Delta sync | Chỉ gửi fields thay đổi | 🟢 Thấp |
| **E4** | Sync analytics | Audit log mỗi lần sync | 🟢 Thấp |
| **E5** | Retry queue | BullMQ retry push thất bại | 🟢 Thấp |

#### 8.3.6. Lưu ý: Thêm entity mới cần cập nhật code (không tự động)

> ⚠️ Sync module dùng hardcoded registry — KHÔNG tự động nhận diện bảng mới. Thêm entity mới cần sửa 3 file: `sync.validation.js` (VALID_ENTITIES), `sync.service.js` (UPSERT_MAP/PULL_MAP/ENTITY_KEYS), `sync.repository.js` (4 methods).

### 8.4. Module Bank — 🚧 Đã lên kế hoạch (Casso — 2026-08-13)

#### 8.4.1. Tổng quan & Quyết định nhà cung cấp

| Chức năng | Endpoint | Trạng thái |
|----------|----------|-----------|
| Liên kết ngân hàng (OAuth) | `POST /api/bank/oauth-url` + `POST /api/bank/callback` | ⬜ Chưa làm |
| Danh sách NH + số dư | `GET /api/bank/accounts` | ⬜ Chưa làm |
| Lịch sử giao dịch | `GET /api/bank/transactions` | ⬜ Chưa làm |
| Nhận giao dịch realtime | `POST /api/bank/webhook` | ⬜ Chưa làm |

**Nhà cung cấp: Casso** (thay thế SePay Bank Hub)

| Lý do chọn Casso | Chi tiết |
|------------------|----------|
| Không cần pháp nhân công ty | Cá nhân/sinh viên đăng ký được (qua Google Form) |
| Giá rẻ, có gói free | SPONSOR: 12 tài khoản + 100 giao dịch/tháng |
| Đủ API | Số dư (`balance`), giao dịch, webhook, OAuth 2.0 multi-user |
| Multi-user qua OAuth 2.0 | Mỗi user cấp quyền → access token riêng |

**So sánh nhanh Casso vs SePay:**

| Tiêu chí | Casso (đã chọn) | SePay Bank Hub (bỏ) |
|----------|-----------------|---------------------|
| Rào cản đăng ký | ✅ Cá nhân OK | ❌ Cần pháp nhân |
| Endpoint số dư | ✅ `balance` | ✅ `accumulated` |
| Liên kết | OAuth redirect | Hosted Link WebView |
| Free tier | 2 req/phút | B2B thương lượng |

#### 8.4.2. Vai trò Casso trong hệ thống

Casso là **Bank Integration Provider** — hệ thống không phụ thuộc trực tiếp từng ngân hàng:

```
┌──────────────────────────────────────────────┐
│          PERSONAL FINANCE SYSTEM             │
│  User → Financial Account (wallet) → Bank Connection
│  Transaction / Budget / Goal / AI ...        │
└──────────────────────┬───────────────────────┘
                       │  OAuth 2.0 + REST API
                       ↓
┌──────────────────────────────────────────────┐
│                   CASSO                       │
└──────────────────────┬───────────────────────┘
              ┌────────┼────────┐
              ↓        ↓        ↓
             MB       VCB      BIDV
```

#### 8.4.3. Mô hình dữ liệu — tách 2 khái niệm

- **Financial Account** = bảng `wallet` hiện có (type=BANK/CASH/SAVINGS)
- **Casso Bank Account** = bảng `bank_account` mới (accountNumber, balance...)
- Quan hệ: `wallet` (1) ─ (0..1) `bank_account`

```
User (idaccount)
  ├── casso_access_token (mã hóa)      ← lưu trong bảng mới hoặc cột User
  ├── casso_refresh_token (mã hóa)     ← refresh không hết hạn
  │
  ├── wallet (Financial Account, type=BANK)   ← BẢNG ĐÃ CÓ
  │     └── bank_account (Casso link)          ← BẢNG MỚI
  │           ├── casso_account_id
  │           ├── account_number, account_name
  │           ├── bank_name, bank_code_name
  │           ├── balance
  │           └── connect_status
  │
  └── transaction  ← thêm: provider='casso', external_transaction_id (tid)
                     UNIQUE(provider, external_transaction_id) chống trùng
```

#### 8.4.4. Luồng liên kết ngân hàng (OAuth 2.0 Authorization Code)

```
1. User bấm "Liên kết ngân hàng" → Client gọi POST /api/bank/oauth-url
2. Backend tạo authorization URL (oauth.casso.vn/auth/authorize) → trả client
3. Client mở WebView/browser → user đăng nhập Casso + cấp quyền
4. Casso redirect về redirect_uri?code=... (callback của backend)
5. Backend đổi code → access_token + refresh_token (POST oauth.casso.vn/auth/token)
6. Backend lưu token (mã hóa) → gọi GET /v2/accounts lấy NH + balance
7. Backend gọi GET /v2/transactions → sync lịch sử giao dịch
8. Từ nay: Casso webhook → giao dịch mới → Backend tạo Transaction
```

> **Lưu ý quan trọng**: User phải **có tài khoản Casso + đã liên kết NH trong Casso** (my.casso.vn) trước. OAuth chỉ cấp quyền cho app đọc dữ liệu — KHÔNG phải là bước link NH.

#### 8.4.5. API Endpoints (Backend → Client)

| Endpoint | Method | Auth | Mô tả |
|----------|--------|------|-------|
| `/api/bank/oauth-url` | POST | Bearer (user) | Trả authorization URL để mở WebView |
| `/api/bank/callback` | GET | Public (code) | Nhận code → đổi token → lưu |
| `/api/bank/accounts` | GET | Bearer (user) | Danh sách NH + số dư (proxy `/v2/accounts`) |
| `/api/bank/balance/:id` | GET | Bearer (user) | Số dư 1 tài khoản |
| `/api/bank/transactions?since=` | GET | Bearer (user) | Lịch sử giao dịch (proxy `/v2/transactions`) |
| `/api/bank/webhook` | POST | Public (verify) | Nhận giao dịch mới từ Casso |

#### 8.4.6. Cấu trúc Module Bank

```
modules/bank/
├── bank.controller.js      # HTTP handlers
├── bank.service.js         # Business logic + orchestration
├── bank.repository.js      # DB: bank_account + transaction + user token
├── bank.validation.js      # Validate input
├── bank.jobs.js            # Enqueue helpers
├── casso/                  # 🆕 Adapter tách biệt provider
│   ├── casso.client.js     # Gọi Casso API (token refresh tự động)
│   └── casso.webhook.js    # Verify + parse webhook payload
└── bank.worker.js          # Xử lý webhook bất đồng bộ
```

#### 8.4.7. Webhook Casso

- 1 webhook endpoint nhận giao dịch mới (khác SePay có 2 kênh Events + IPN)
- Payload giao dịch có `tid` (dedupe), `amount`, `runningBalance`, `description`
- Response nhanh: validate → lưu → publish event (BullMQ) → 200
- Chống trùng: `UNIQUE(provider='casso', external_transaction_id=tid)`

#### 8.4.8. Quy tắc nghiệp vụ (bắt buộc)

1. **Webhook trả 200 nhanh** — không làm AI/report inline, đẩy qua BullMQ
2. **Chuyển khoản nội bộ** (MB→VCB) = INTERNAL_TRANSFER, không tính expense
3. **Unlink giữ lịch sử** — chỉ set connection inactive
4. **Reconciliation** — webhook + định kỳ pull `/v2/transactions` + đối chiếu `balance`
5. **Historical sync** khi link + realtime webhook sau đó
6. **Token an toàn** — access_token/refresh_token mã hóa, refresh tự động (TTL 6h)

#### 8.4.9. Thứ tự triển khai

| GĐ | Nội dung | Ước lượng |
|----|----------|-----------|
| **GĐ1** | DB: bảng `bank_account` + cột provider/external_transaction_id + Prisma | 0.5 ngày |
| **GĐ2** | `casso.client.js` (getToken/refresh + accounts + transactions) | 1 ngày |
| **GĐ3** | OAuth flow: oauth-url + callback + lưu token | 0.5-1 ngày |
| **GĐ4** | Routes + Controller + Service + Repository (accounts/balance/transactions) | 1 ngày |
| **GĐ5** | Webhook handler + worker → tạo Transaction (chống trùng) | 0.5-1 ngày |
| **GĐ6** | Test sandbox + tài khoản demo Casso | 0.5 ngày |

> ⚠️ **Điều kiện tiên quyết**: Cần đăng ký developer app Casso (Google Form) để nhận `client_id` + `client_secret`. Khi chưa có → dùng mock trong `casso.client.js` (giống pattern AI module).

### 8.5. Module AI

#### 8.5.1. Tổng quan

| Chức năng | Phương án AI | Trạng thái |
|----------|-------------|-----------|
| OCR hóa đơn | Tesseract.js (self-hosted) | ⬜ Chưa làm |
| AI phân loại giao dịch | Self-train model (fastText/BERT-tiny) | ⬜ Chưa làm |
| AI Phân tích hành vi chi tiêu | Algorithmic + Self-train | ⬜ Chưa làm |
| AI Dự báo chi tiêu | Self-train model (time-series) | ⬜ Chưa làm |
| AI Đưa lời khuyên tài chính | LLM API (OpenAI/HuggingFace) | ⬜ Chưa làm |
| AI Đề xuất phân bổ dòng tiền | Algorithmic + LLM API giải thích | ⬜ Chưa làm |
| Chatbot AI | LLM API (OpenAI/HuggingFace) | ⬜ Chưa làm (sau cùng) |

#### 8.5.2. Chiến lược AI: Self-train Model vs LLM API

```
Self-train model (fastText/LSTM/Prophet):  Phân loại GD, Phân tích hành vi, Dự báo, Budget math
LLM API (OpenAI/HuggingFace):              Lời khuyên, Giải thích Budget, Chatbot
Tesseract.js:                              OCR
```

| Phương án | Dùng cho | Lý do |
|-----------|----------|-------|
| **Self-train model** | Phân loại giao dịch, Phân tích hành vi, Dự báo chi tiêu, Budget math | Output cố định / dữ liệu có cấu trúc / không cần sinh ngôn ngữ |
| **LLM API** | Chatbot, Lời khuyên tài chính, Giải thích Budget | Cần NLU + NLG (sinh ngôn ngữ tự nhiên), cá nhân hóa |

#### 8.5.3. Kiến trúc AI (3 lớp)

```
┌─────────────────────────────────────────────────────────┐
│                    AI/ML LAYER                           │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────┐ │
│  │ Transaction  │ │ Behavior     │ │ Expense          │ │
│  │ Classifier   │ │ Analyzer     │ │ Forecaster       │ │
│  │ (fastText)   │ │ (Clustering) │ │ (Prophet/LSTM)   │ │
│  └──────────────┘ └──────────────┘ └──────────────────┘ │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────┐ │
│  │ Budget       │ │ Financial    │ │ Chatbot          │ │
│  │ Allocator    │ │ Advisor      │ │ Assistant        │ │
│  │ (Algorithm)  │ │ (LLM API)    │ │ (LLM API)        │ │
│  └──────────────┘ └──────────────┘ └──────────────────┘ │
├─────────────────────────────────────────────────────────┤
│                   ML PLATFORM                            │
│  ┌──────────┐  ┌──────────┐  ┌────────────────────────┐ │
│  │ Training │  │ Model    │  │ Feature Store          │ │
│  │ Pipeline │  │ Serving  │  │ (category, amount,     │ │
│  │ (scripts)│  │ (Worker) │  │  date, frequency...)   │ │
│  └──────────┘  └──────────┘  └────────────────────────┘ │
├─────────────────────────────────────────────────────────┤
│                  DATA SOURCES                            │
│  ┌──────────┐  ┌──────────────┐  ┌────────────────────┐ │
│  │ Category │  │ Transaction  │  │ Budget / Goal      │ │
│  │ (29 cats)│  │ (UUID, amt,  │  │ (target, deadline, │ │
│  │ classify │  │  description │  │  strategy rules)   │ │
│  │ thu/chi  │  │  categoryId) │  │                    │ │
│  └──────────┘  └──────────────┘  └────────────────────┘ │
│                  ↑ Sync từ Client-app qua                │
│                  POST /api/sync/push (LWW conflict)       │
└─────────────────────────────────────────────────────────┘
```

#### 8.5.4. OCR hóa đơn

**Công nghệ**: Tesseract.js (self-hosted, miễn phí)

**Mô tả**: Dual-mode:
- **Offline (mobile)**: Google ML Kit / Tesseract on-device → trích xuất số tiền, cửa hàng, ngày → tạo giao dịch tạm → sync về backend.
- **Online (backend)**: Gửi ảnh hóa đơn → `POST /api/ai/ocr` → enqueue job `ocr-process-receipt` → Tesseract.js parse text → tạo transaction + emit event.

#### 8.5.5. AI phân loại giao dịch

**Công nghệ**: Self-train model (fastText hoặc BERT-tiny), chạy trên Node.js

**Dữ liệu huấn luyện**: CSV/JSON gồm cặp `{description, category}` từ danh mục hệ thống + dữ liệu mẫu (~500-1000 mẫu).

**Luồng**:
```
Mobile → tạo giao dịch → lưu Drift SQLite (sync_status=pending)
  → SyncEngine push batch → POST /api/sync/push
  → Backend lưu Transaction (UUID, description, amount, categoryId=null)
  → emit transaction.created
  → AI Worker pick job ai-classify-transaction
  → load model → predict category từ description
  → cập nhật categoryId cho transaction
  → emit transaction.classified
```

> **Lưu ý**: Client có thể phân loại offline trước (dùng model Flutter), backend AI classify là bước bổ sung để tăng độ chính xác.

#### 8.5.6. AI Phân tích hành vi chi tiêu

**Công nghệ**: Algorithmic (pattern recognition) + Self-train model

**Mô tả**: Phân tích lịch sử giao dịch để phát hiện:
- Nhóm chi tiêu theo danh mục (ăn uống chiếm X%, di chuyển Y%...)
- Thói quen chi tiêu theo thời gian (cuối tuần, đầu tháng, lễ Tết...)
- Phát hiện bất thường (transaction vượt ngưỡng, category mới xuất hiện đột ngột)
- So sánh với tháng trước / cùng kỳ năm trước

#### 8.5.7. AI Dự báo chi tiêu

**Công nghệ**: Self-train time-series model (Prophet, ARIMA, hoặc LSTM nhẹ)

**Mô tả**: Dựa trên lịch sử giao dịch 3-6 tháng gần nhất: dự báo tổng chi tiêu tháng tới, theo danh mục, gợi ý ngân sách.

#### 8.5.8. AI Đưa lời khuyên tài chính

**Công nghệ**: LLM API (OpenAI GPT-4o-mini / HuggingFace free inference)

**Rate Limit**: 1 lần/giờ/user | **Cache TTL**: 1 giờ | **Max Tokens**: 300

**Mô tả**: Kết hợp F013 (phân tích) + F014 (dự báo) → prompt LLM sinh lời khuyên cá nhân hóa.

**Prompt Template** (`modules/ai/prompts/financial-advice.txt`):
```text
[SYSTEM]
Bạn là cố vấn tài chính cá nhân chuyên nghiệp, tên là WealthWise.
Nguyên tắc: Chỉ đưa lời khuyên dựa trên dữ liệu thực tế, không phỏng đoán. Dùng tiếng Việt, thân thiện. Mỗi lời khuyên không quá 2 câu.

[CONTEXT]
Người dùng: {{fullname}} - Tháng: {{month}}/{{year}}
Thu nhập: {{income}} VNĐ | Tổng chi: {{totalExpense}} VNĐ ({{expensePercent}}%)
Top 5 danh mục chi: {{topCategories}}
So với tháng trước: {{expenseChange}}%
Cảnh báo: {{warnings}}

[QUESTION] Đưa ra 2-3 lời khuyên cụ thể để cải thiện tài chính tháng này.

[FORMAT] JSON: {"advice": [{"priority":"high|medium|low","category":"...","message":"..."}], "summary":"..."}
```

#### 8.5.9. AI Đề xuất phân bổ dòng tiền

**Công nghệ**: Algorithmic (core: 50/30/20, zero-based...) + LLM API (giải thích)

**Rate Limit (LLM)**: 2 lần/giờ/user | **Cache TTL**: 1 giờ | **Max Tokens**: 300

#### 8.5.10. Chatbot AI

**Công nghệ**: LLM API (OpenAI GPT-4o-mini) với multi-provider fallback (HuggingFace → Groq)

**Rate Limit**: 10 lần/phút/user | **Cache TTL**: 5 phút | **Max Tokens**: 500

#### 8.5.11. Thứ tự triển khai

| Giai đoạn | Nội dung | Ước lượng |
|-----------|----------|-----------|
| **1** | ai.service.js + ai.controller.js + ai.routes.js (nền móng) | 1-2 ngày |
| **2** | Phân loại GD — Chuẩn bị dữ liệu + train model | 2-3 ngày |
| **3** | Phân loại GD — BullMQ worker: predict → update DB → emit event | 1 ngày |
| **4** | OCR backend: Tesseract.js + endpoint + worker | 2-3 ngày |
| **5** | Phân tích hành vi chi tiêu (algorithmic) | 2-3 ngày |
| **6** | Dự báo chi tiêu (time-series model) | 2-3 ngày |
| **7** | Lời khuyên tài chính (LLM API) | 1-2 ngày |
| **8** | Đề xuất phân bổ dòng tiền (algorithmic + LLM) | 2-3 ngày |
| **9** | Chatbot AI (LLM API) | 2-3 ngày |

#### 8.5.12. Quy trình chuẩn xây dựng Self-train Models

```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│ DATA     │ → │ PREP &   │ → │ TRAIN &  │ → │ EXPORT   │ → │ SERVE    │
│ COLLECT  │   │ CLEAN    │   │ EVALUATE │   │ MODEL    │   │ (Worker) │
└──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘
```

| Bước | Công cụ | Output |
|------|---------|--------|
| 1. Data Collect | SQL query từ PostgreSQL qua Prisma | CSV/JSON raw |
| 2. Prep & Clean | Node.js script (lodash, csv-parser) | Train/test split (80/20) |
| 3. Train & Evaluate | Python script (scikit-learn/fastText/Prophet) | Model file + metrics |
| 4. Export Model | fastText `.bin` / ONNX `.onnx` / Prophet `.json` | File model nhẹ (~1-10MB) |
| 5. Serve | Node.js load model trong ai.worker.js | Inference qua BullMQ |

**Cấu trúc thư mục models:**
```
models/
├── transaction-classifier/  (train.py, training-data.csv, model.bin, labels.json, metrics.json)
├── behavior-analyzer/        (train.py, centroids.json, rules.json)
├── expense-forecaster/       (train.py, prophet-model.json, metrics.json)
└── budget-allocator/         (strategies.json)
```

**Training script convention** — mỗi model 1 file `train.py`:
```python
import sys, json
def train(data_path, output_path):
    # 1. Load 2. Preprocess 3. Train 4. Evaluate 5. Export
    return metrics
if __name__ == "__main__":
    metrics = train(sys.argv[1], sys.argv[2])
    print(json.dumps(metrics))
```

#### 8.5.13. Kiến trúc LLM API (lời khuyên, giải thích budget, chatbot)

**Multi-provider với fallback** — `modules/ai/llm/llmClient.js`:

| Provider | Model | Giới hạn free |
|----------|-------|---------------|
| **OpenAI** | GPT-4o-mini | $5 credit |
| **HuggingFace** | mistral-7b / zephyr-7b | Free (rate limit) |
| **Groq** | llama-3.1-8b | Free (~30 req/min) |

**Rate Limiter** (`llm/rate-limiter.js`) + **LLM Cache** (`llm/cache.js`, Redis-backed).

**Thư mục prompts:** `modules/ai/prompts/` — financial-advice.txt, budget-explanation.txt, chatbot-system.txt

#### 8.5.14. Kiến trúc Worker: Chạy chung vs Chạy riêng

- **GĐ1 (hiện tại)**: Chạy chung — model fastText nhẹ (~5MB) không ảnh hưởng event loop.
- **GĐ2 (production)**: Tách worker riêng khi cần scale hoặc model nặng hơn.

#### 8.5.15. Cấu trúc thư mục Module AI (Feature-based)

```
modules/ai/
├── ai.controller.js              # Router chung
├── ai.validation.js              # Validation chung
├── ai.jobs.js                    # Enqueue helpers
├── config.js                     # Model paths, thresholds
├── features/
│   ├── classify/                 # AI Phân loại giao dịch
│   │   ├── classify.controller.js / service.js / repository.js
│   │   ├── classify.preprocess.js / inference.js / config.json
│   │   ├── __tests__/
│   │   └── pipeline/ (train.py, evaluate.py, export.py, training-data.csv, model.bin, labels.json, metrics.json)
│   ├── ocr/                      # OCR hóa đơn
│   ├── behavior/                 # Phân tích hành vi
│   ├── forecast/                 # Dự báo chi tiêu
│   ├── advice/                   # Lời khuyên tài chính
│   ├── budget/                   # Phân bổ dòng tiền
│   └── chatbot/                  # Chatbot AI
├── llm/                          # Dùng chung cho advice/budget/chatbot
│   ├── llmClient.js / openaiProvider.js / huggingfaceProvider.js
│   ├── groqProvider.js / rate-limiter.js / cache.js
└── prompts/                      # Prompt templates
```

#### 8.5.16. Build nền móng AI (vỏ) ✅ Done — 2026-08-11

**API**: `POST /api/ai/classify` — pipeline HTTP → BullMQ → Worker (chưa có model thật).

| Method | Auth | Body | Success | Error |
|--------|------|------|---------|-------|
| POST | Bearer (user) | `{ transactionId: string }` | 202 `{ transactionId, jobId, status: "queued" }` | 400/401/404 |

**Files đã implement**: `api/ai.routes.js`, `modules/ai/ai.controller.js`, `ai.validation.js`, `ai.jobs.js`, `features/classify/*`, `workers/ai.worker.js`, `index.js`.

**Kết quả test**: 202 (hợp lệ), 400 (thiếu transactionId), 401 (không token) — all PASS.

> **Ghi chú**: Repository trả mock data vì bảng Transaction chưa có trong schema lúc build. Khi schema cập nhật, xóa `if (!prisma.transaction)` guard là code tự hoạt động.

### 8.6. Module Notification

> ⏳ Chưa triển khai — phát sinh dần trong quá trình làm & ghi nhận sau.

## 9. Client-app

### 9.1 Tích Hợp Authentication (Client-app ↔ Backend)

> Hoàn thành: 2026-08-09

#### 9.1.1 Kết nối thực tế Client-app với Backend

| Thành phần | Mô tả |
|---|---|
| `AppConstants.baseUrl` | `http://localhost:3000/api` |
| `AuthRemoteDataSourceImpl` | Gọi API thực tế qua Dio: `POST /auth/login`, `POST /auth/register` |
| `AuthRepositoryImpl` | Lưu `accessToken` + `refreshToken` vào SecureStorage |
| `UserModel` | Mapping từ response backend: `idaccount`, `username`, `fullname`, `rolename` |

#### 9.1.2 AuthBloc — Scope

`AuthBloc` khởi tạo **một lần duy nhất** tại `main.dart` trong `MultiBlocProvider`. Tất cả các trang dùng chung instance này qua `context.read<AuthBloc>()`.

- **`LoginPage`**: `BlocListener<AuthBloc>` → `LoginSubmitted(email: username, password: password)`
- **`RegisterPage`**: `BlocListener<AuthBloc>` → `RegisterSubmitted(name, fullname, email, password)`
- **`ProfilePage`**: Nút Đăng xuất → dialog xác nhận → `LogoutRequested()` → `context.go('/login')`

#### 9.1.3 Offline Access

```
Lần đầu đăng nhập (bắt buộc online)
    → accessToken lưu SecureStorage
    → userJson cache SecureStorage (key: offline_user_data)

App khởi động:
    main.dart đọc accessToken
    → Có token  → initialLocation = '/home'  (offline OK)
    → Không có  → initialLocation = '/login' (phải online)

Đăng xuất:
    → Xóa token + xóa offline cache
    → Phải đăng nhập online lần sau
```

**Package bổ sung:** `crypto: ^3.0.6` (SHA-256 hash mật khẩu)

#### 9.1.4 CORS & Port cố định

| Service | Port |
|---|---|
| Backend (Node.js) | `3000` — `npm run dev` |
| Client-app (Flutter Web) | `9090` — `flutter run -d chrome --web-port 9090` |
| `CORS_ORIGIN` trong `.env` | `http://localhost:9090` |

#### 9.1.5 Files đã thay đổi

| File | Thay đổi |
|---|---|
| `core/constants/app_constants.dart` | baseUrl + offline cache keys |
| `auth/data/datasources/auth_remote_data_source.dart` | Dio API thực, `NetworkException` |
| `auth/data/repositories/auth_repository_impl.dart` | Online login, offline cache, logout xóa cache |
| `auth/presentation/bloc/auth_event.dart` | `RegisterSubmitted` thêm `fullname` |
| `auth/presentation/pages/login_page.dart` | BlocListener root, field username |
| `auth/presentation/pages/register_page.dart` | BlocListener root, thêm username/fullname |
| `profile/presentation/pages/profile_page.dart` | Nút Đăng xuất + dialog xác nhận |
| `core/constants/app_router.dart` | `createRouter(initialRoute)` factory |
| `main.dart` | Check token trước start → set initialLocation |
| `src/Backend/.env` | `CORS_ORIGIN=http://localhost:9090` |
| `pubspec.yaml` | `crypto: ^3.0.6` |

---

### 9.2. Tiến Độ Phát Triển & Kiến Trúc Core Offline-First (Cập nhật 2026-08-10)

#### 9.2.1 Cấu Trúc Core Infrastructure (Client-app)

Dự án Flutter Client-app đã triển khai hoàn thiện tầng Core hạ tầng Offline-first:

- **Database Engine**: Drift ORM (SQLite) hỗ trợ WAL Mode, Foreign Keys, MigrationStrategy và seed dữ liệu danh mục mặc định.
- **Data Access Objects (DAOs)**: Triển khai 6 DAOs tương ứng với 6 bảng cốt lõi (`Wallet`, `Transaction`, `Category`, `Budget`, `Bill`, `Goal`).
- **SyncEngine**: Triển khai cơ chế đồng bộ nền `SyncEngine` hỗ trợ debounce, lắng nghe kết nối mạng (Connectivity Listener) và quản lý hàng chờ Pending Queue.
- **Dependency Injection**: Cấu hình GetIt DI (`injection_container.dart`) đăng ký singleton cho `AppDatabase`, `SyncEngine`, `WalletLocalDataSource`, `WalletRepository`, `WalletCubit`.
- **Formatting & Exceptions**: Bổ sung `CurrencyFormatter` (locale `vi_VN`) và phân cấp ngoại lệ `AppExceptions` (`NetworkException`, `ServerException`, `CacheException`, `AuthException`, `ValidationException`).

#### 9.2.2 Chức Năng Quản Lý Ví (Wallet Feature - Plan 4)

- **Data Layer**:
  - `WalletEntity` (model domain)
  - `WalletLocalDataSourceImpl` (thao tác trực tiếp Drift DB)
  - `WalletRepositoryImpl` (quản lý UUID, tự động xử lý xung đột ví mặc định, trigger SyncEngine)
- **State Management**: `WalletCubit` xử lý 6 sealed states (`WalletInitial`, `WalletLoading`, `WalletLoaded`, `WalletError`, `WalletActionSuccess`, `WalletActionFailure`) hỗ trợ Optimistic UI.
- **Presentation Layer**:
  - `WalletListPage`: Hiển thị danh sách ví, số dư tổng, dialog xóa ví và xử lý state real-time.
  - `WalletAddPage`: Form tạo ví mới với validation, tích hợp `WalletCubit`.

#### 9.2.3 Quy Chuẩn Đặc Tả Đồng Bộ Backend (Backend Sync Spec)

Tài liệu đặc tả đồng bộ dữ liệu hai chiều giữa Client (Drift SQLite) và Backend (PostgreSQL NestJS) đã được khởi tạo tại [`2026-08-10-backend-sync-spec.md`](./docs/superpowers/plans/2026-08-10-backend-sync-spec.md):

- **Database Models Backend**: Định nghĩa 5 Prisma models tương ứng (`Wallet`, `Transaction`, `Budget`, `Bill`, `Goal`) sử dụng UUID Primary Key (`VARCHAR(36)`).
- **API Push & Pull**:
  - `POST /api/sync/push`: Client gửi mảng batch các thao tác (`create`, `update`, `delete`) kèm client timestamp.
  - `GET /api/sync/pull?since=<timestamp>`: Client kéo các thay đổi mới nhất từ server.
- **Conflict Resolution**: Áp dụng chiến lược **Last-Write-Wins (LWW)** dựa trên mốc thời gian `updatedAt`.
