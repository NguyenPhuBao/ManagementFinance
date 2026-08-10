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
| **Modularity** | Backend tổ chức thành các module độc lập theo nghiệp vụ (User, Wallet, Category, Transaction, Budget, Saving, Debt, Automation, Analytics, Notification, AI). Mỗi module có controller, service, repository riêng, giao tiếp qua HTTP và sự kiện. |
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
| `sms-parse` | Phân tích SMS ngân hàng → tạo giao dịch |
| `send-notification` | Gửi email/push notification |
| `sync-data` | Xử lý đồng bộ batch từ client |

- **Redis**: Cache dữ liệu truy cập nhiều (danh mục, tỉ giá) + broker cho BullMQ

#### 3.2.4 Database — PostgreSQL (PersonFinance)

- **ORM**: Prisma
- **Host**: `localhost:5432`
- **User**: `postgres`
- **Schema**: `public`
- Quản lý schema qua **migration** (Prisma) + **SQL script** (`database/`)
- Script khởi tạo: `database/)1_CSDL_Admin.sql` + `database/)2_create_refreshtoken_table.sql`

##### Sơ đồ quan hệ (6 bảng)

```
Role (1) ──▶ Account (N) ──▶ User (1)
                │
                ├──▶ RefreshToken (N)
                ├──▶ Category (N)
                └──▶ AuditLog (N)
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

##### Bảng Category
| Cột | Kiểu | Mô tả |
|-----|------|-------|
| `idcategory` | INT PK (auto) | ID danh mục |
| `namecategory` | VARCHAR(100) | Tên danh mục |
| `classify` | VARCHAR(10) | `thu` / `chi` / `vay/no` |
| `is_default` | BOOLEAN | Danh mục mặc định hệ thống? |
| `created_by` | INT FK→Account | Người tạo |
| `created_at` / `updated_at` | TIMESTAMP | Thời gian |

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
| **Sync Engine** | `POST /sync` | Gửi mảng operations, backend xử lý & trả kết quả |
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
Client: POST /transactions
  ↓
Backend: Tạo transaction → emit transaction.created
  ↓
AI Service: Phân loại category
Analytics Service: Cập nhật báo cáo
Notification Service: Gửi thông báo
  ↓
Backend → Client: Thành công → sync_status=synced
```

#### 3.5.2 Tự Động Hóa Từ SMS

```
SMS → API /automation/sms → Backend → Queue sms-parse → 202 Accepted
  ↓
Worker: AI/NLP trích xuất (số tiền, nội dung, ngày, danh mục)
  ↓
Thành công → Tạo transaction + emit event
Thất bại → Đẩy thông báo client → người dùng nhập tay
```

#### 3.5.3 Đồng Bộ Hàng Loạt (Sync)

```
Client: POST /sync (mảng operations: create/update/delete)
  ↓
Backend: Xử lý tuần tự trong transaction → đảm bảo toàn vẹn
  ↓
Backend → Client: Danh sách kết quả + conflicts → Client cập nhật local DB
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

| Module | Chức năng chính |
|--------|-----------------|
| **auth** | Đăng ký, đăng nhập, cấp JWT, refresh token |
| **admin** | Quản lý user, dashboard thống kê, cấu hình hệ thống, queue status |
| **sync** | Nhận batch operations từ client, conflict resolution |
| **bank** | Webhook ngân hàng, SMS, tỷ giá, lãi suất |
| **ai** | Phân loại giao dịch, OCR, SMS parsing, chatbot |
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

BullMQ giúp quản lý và xử lý các **tác vụ nền (background jobs)** như: gửi email hàng loạt, xử lý ảnh, xuất báo cáo dữ liệu, gọi AI phân loại, OCR hóa đơn, SMS parsing.

**Đặc điểm:**
- **Tiết kiệm CPU**: Dùng Redis Stream pub/sub để Redis **chủ động thông báo** cho worker khi có job mới (không polling)
- **Hỗ trợ phân tán**: Nhiều worker trên nhiều server khác nhau, cùng truy cập Redis trung tâm để lấy job
- **Nhiều tính năng**: FIFO/LIFO, ưu tiên (priority), job trì hoãn (delayed), job lặp (repeatable cron), retry với backoff

**Trong dự án**: Backend sử dụng 5 queue (định nghĩa tại `core/queue.js`):
| Queue | Mục đích |
|-------|----------|
| `ai-classify-transaction` | Gọi AI phân loại danh mục cho giao dịch |
| `ocr-process-receipt` | Xử lý ảnh hóa đơn, trích xuất thông tin |
| `sms-parse` | Phân tích SMS ngân hàng → tạo giao dịch |
| `send-notification` | Gửi email/push notification đến user |
| `sync-data` | Xử lý đồng bộ batch từ client |

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
Enqueue job vào BullMQ (vd: sms-parse, ai-classify-transaction)
  ↓
Worker pick job → xử lý → lưu DB → emit event qua Event Bus
```

**+ Jobs**: Kết hợp BullMQ để xử lý webhook bất đồng bộ, đảm bảo:
- Webhook response nhanh (200 OK trong vài ms), không block
- Job có retry nếu xử lý thất bại
- Có thể theo dõi trạng thái job (completed/failed)

**Trong dự án**: Module `bank` xử lý webhook từ ngân hàng (SMS, tỷ giá). Module `ai` xử lý webhook OCR. Cả hai đều đẩy job vào BullMQ để worker xử lý bất đồng bộ.

##### REST API + Emit Event

Đây là pattern kết hợp **xử lý đồng bộ (REST)** và **phát sự kiện bất đồng bộ (Event Bus)** trong cùng một luồng nghiệp vụ.

**Luồng hoạt động:**
```
Client → POST /api/sync (gửi dữ liệu)
  ↓
Controller → Service: xử lý nghiệp vụ chính (lưu DB, validate)
  ↓
Trả về 200 OK cho client ngay                     ← REST (đồng bộ)
  ↓ (song song, không block response)
EventBus.publish('transaction.created', payload)  ← Emit Event (bất đồng bộ)
  ↓
Các subscriber lắng nghe:
  ├── AI Worker: phân loại danh mục giao dịch
  ├── Notification Worker: gửi thông báo qua Socket.IO
  └── Analytics: cập nhật báo cáo thống kê
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
| **BullMQ** | bank, ai, notification, sync | Xử lý job nặng bất đồng bộ (OCR, SMS, AI, email, sync batch) |
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
│  sms-parse          │              │  sync.completed         │
│  send-notification  │              │  category.updated       │
│  sync-data          │              │  bank.webhook.received  │
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
Client-app → POST /api/sync {operations: [{type, entity, data}...]}
  → authenticate (user)
  → syncController.processSync()
  → syncService.processBatch()
    → Xử lý tuần tự từng operation trong DB transaction
    → Lưu kết quả (thành công/thất bại/conflict)
    → 200 OK {results: [...], conflicts: [...]}
    → EventBus.publish('sync.completed', {userId, stats})
       ↓
       Notification Worker subscribe → Socket.IO → admin-web
```

**Module Bank** — Ngân hàng (Webhook + BullMQ Jobs)

```
Ngân hàng → POST /api/bank/webhook {type: 'sms', data: {...}}
  → bankController.receiveWebhook()
  → 200 OK (xác nhận đã nhận, không xử lý ngay)
  → Enqueue job vào BullMQ: sms-parse
     ↓
     bank.worker.js pick job
     → AI/NLP trích xuất (số tiền, nội dung, danh mục)
     → Thành công: tạo transaction + EventBus.publish('transaction.created')
     → Thất bại: EventBus.publish('sms.parse.failed', {error})
        ↓
        Notification Worker → Socket.IO → admin-web (cảnh báo)
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

### 6.1 Chức năng Đăng nhập & Đăng ký
| Mã | Chức năng | Đối tượng sử dụng | Module | Trạng thái |
|----|----------|-------------------|--------|-----------|
| **F001** | Đăng nhập hệ thống | Admin, User | auth | ✅ Done |
| **F002** | Đăng ký tài khoản | User (Mobile-app) | auth | ✅ Done |

### 6.2 Chức năng Quản lý người dùng (Admin)
| Mã | Chức năng | Đối tượng sử dụng | Module | Trạng thái |
|----|----------|-------------------|--------|-----------|
| **F004** | Xem danh sách người dùng | Admin | admin | ✅ Done |
| **F005** | Xem chi tiết người dùng | Admin | admin | ✅ Done |
| **F006** | Kích hoạt / Vô hiệu hóa tài khoản | Admin | admin | ✅ Done |

### 6.3 Chức năng Quản lý danh mục (Admin)
| Mã | Chức năng | Đối tượng sử dụng | Module | Trạng thái |
|----|----------|-------------------|--------|-----------|
| **F007** | Xem danh sách danh mục | Admin | admin | ✅ Done |
| **F008** | Thêm danh mục mới | Admin | admin | ✅ Done |
| **F009** | Sửa danh mục | Admin | admin | ✅ Done |
| **F010** | Xóa danh mục | Admin | admin | ✅ Done |

### 6.4 Chức năng Dashboard (Admin)
| Mã | Chức năng | Đối tượng sử dụng | Module | Trạng thái |
|----|----------|-------------------|--------|-----------|
| **F003** | Thống kê tổng quan | Admin | admin | 🚧 Đang phát triển |

---

## 7. Đặc Tả & Yêu Cầu Nghiệp Vụ & API

### 7.1 F001 — Đăng Nhập Hệ Thống

#### 7.1.1 Thông tin chung

| Thuộc tính | Giá trị |
|------------|---------|
| **Mã chức năng** | F001 |
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

### 7.2 F003 — Dashboard Admin (Thống kê)

#### 7.2.1 Thông tin chung

| Thuộc tính | Giá trị |
|------------|---------|
| **Mã chức năng** | F003 |
| **Tên chức năng** | Dashboard — Thống kê hệ thống |
| **Actor chính** | Admin |
| **Mức độ ưu tiên** | Cao |
| **Trạng thái** | 🚧 Đang phát triển |
| **Phiên bản** | v1.0 — 2026-08-06 |

#### 7.2.2 Nguyên tắc chung

Dashboard có 3 lựa chọn thống kê theo thời gian: **Hôm nay**, **7 ngày**, **30 ngày**.
- Mặc định khi truy cập dashboard: **Hôm nay**
- Khi người dùng chọn khoảng thời gian khác → tự động tải lại dữ liệu và gọi API tương ứng
- Các API tổng (không phụ thuộc thời gian) chỉ gọi 1 lần khi mount, không gọi lại khi đổi bộ lọc
- Tất cả API dashboard yêu cầu `authenticate` + `authorize('admin')`
- Khi truy vấn dữ liệu người dùng: chỉ tính user (`idrole = 2`), không tính admin (`idrole = 1`)

#### 7.2.3 API Endpoints

| Endpoint | Method | Auth | Mô tả |
|----------|--------|------|-------|
| `/api/admin/totaluser` | GET | Admin | Tổng số người dùng (toàn bộ, không filter thời gian) |
| `/api/admin/totalcategories` | GET | Admin | Tổng số danh mục (toàn bộ, không filter thời gian) |
| `/api/admin/getusertotime` | GET | Admin | Số lượng người dùng mới + tỷ lệ tăng trưởng theo khoảng thời gian |

#### 7.2.4 API Chi tiết

##### GET /api/admin/totaluser

**Query params**: Không

**Response**:
```json
{
  "success": true,
  "data": { "total": 2 }
}
```

##### GET /api/admin/totalcategories

**Query params**: Không

**Response**:
```json
{
  "success": true,
  "data": { "total": 0 }
}
```

##### GET /api/admin/getusertotime

**Query params**:

| Param | Kiểu | Required | Default | Mô tả |
|-------|------|----------|---------|-------|
| `period` | string | No | `today` | `today` / `7days` / `30days` |

**Luồng xử lý**:
1. Xác định 2 khoảng thời gian: Current (được chọn) và Previous (tương ứng trước đó)
   - `today`: Hôm nay vs Hôm qua
   - `7days`: 7 ngày gần nhất vs 7 ngày trước đó (day 8→14)
   - `30days`: 30 ngày gần nhất vs 30 ngày trước đó (day 31→60)
2. Đếm số user (`idrole = 2`) trong từng khoảng
3. Tính growth: `((current - previous) / previous) * 100`
   - Nếu `previous = 0` → growth = `100%`
   - Nếu dữ liệu không đủ ngày → vẫn tính bình thường

**Response**:
```json
{
  "success": true,
  "data": {
    "period": "today",
    "current": 2,
    "previous": 0,
    "growth": 100
  }
}
```

#### 7.2.5 Mapping Frontend

| Card trên Dashboard | API | Gọi khi |
|---------------------|-----|---------|
| Tổng người dùng | `GET /api/admin/totaluser` | Mount (1 lần) |
| Tổng danh mục | `GET /api/admin/totalcategories` | Mount (1 lần) |
| Người dùng mới (+ growth%) | `GET /api/admin/getusertotime?period=` | Mount + mỗi lần đổi time filter |

#### 7.2.6 Files liên quan

| Tầng | File |
|------|------|
| **Backend** | `modules/admin/admin.controller.js` |
| | `modules/admin/admin.service.js` |
| | `modules/admin/admin.repository.js` |
| | `api/admin.routes.js` |
| **Frontend** | `pages/dashboard/DashboardPage.jsx` |
| | `api/admin.api.js` |
| | `utils/constants.js` (TIME_FILTERS) |

### 7.3 F004-006 — Quản lý người dùng (Admin)

#### 7.3.1 Thông tin chung

| Thuộc tính | Giá trị |
|------------|---------|
| **Mã chức năng** | F004, F005, F006 |
| **Tên chức năng** | Quản lý người dùng |
| **Actor chính** | Admin |
| **Mức độ ưu tiên** | Cao |
| **Trạng thái** | ✅ Đã hoàn thành |
| **Phiên bản** | v1.0 — 2026-08-09 |

#### 7.3.2 Mô tả

- **F004 — Xem danh sách người dùng**: Hiển thị toàn bộ user (idrole=2) dạng bảng có phân trang, lọc theo trạng thái & khu vực. Mỗi dòng hiển thị: họ tên, email, số điện thoại, trạng thái, nút hành động.
- **F005 — Xem chi tiết người dùng**: Bấm nút xem chi tiết → mở modal hiển thị đầy đủ thông tin cá nhân + tài khoản, gọi API `GET /getuser/:id`.
- **F006 — Kích hoạt / Vô hiệu hóa**: Bấm nút "Vô hiệu hóa" / "Kích hoạt" → hiển thị alert xác nhận → gọi `PATCH /updatestatus/:id` → cập nhật trạng thái trong DB → render lại UI.

#### 7.3.3 API Endpoints

| Endpoint | Method | Auth | Mô tả |
|----------|--------|------|-------|
| `/api/admin/getuser` | GET | Admin | Lấy danh sách người dùng (idrole=2) |
| `/api/admin/getuser/:id` | GET | Admin | Lấy chi tiết người dùng theo iduser |
| `/api/admin/updatestatus/:id` | PATCH | Admin | Toggle trạng thái Active↔Inactive |

#### 7.3.4 Files liên quan

| Tầng | File |
|------|------|
| **Backend** | `modules/admin/admin.controller.js` |
| | `modules/admin/admin.service.js` |
| | `modules/admin/admin.repository.js` |
| | `api/admin.routes.js` |
| **Frontend** | `pages/users/UserListPage.jsx` |
| | `components/common/UserDetailModal.jsx` |
| | `api/admin.api.js` |

### 7.4 F007-010 — Quản lý danh mục (Admin)

#### 7.4.1 Thông tin chung

| Thuộc tính | Giá trị |
|------------|---------|
| **Mã chức năng** | F007, F008, F009, F010 |
| **Tên chức năng** | Quản lý danh mục |
| **Actor chính** | Admin |
| **Mức độ ưu tiên** | Cao |
| **Trạng thái** | ✅ Đã hoàn thành |
| **Phiên bản** | v1.0 — 2026-08-09 |

#### 7.4.2 Mô tả

- **F007 — Xem danh sách danh mục**: Hiển thị toàn bộ category dạng bảng có phân trang, lọc theo loại & mặc định. Mỗi dòng: tên danh mục, loại (thu/chi/vay-no), phân loại (hệ thống/tùy chỉnh), nút sửa/xóa.
- **F008 — Thêm danh mục**: Mở modal form (tên, loại, mặc định) → `POST /addcategory` → render lại.
- **F009 — Sửa danh mục**: Bấm nút sửa → mở modal với dữ liệu đã lưu từ lần load trước (không gọi lại API) → `PUT /updatecategory/:id` → render lại.
- **F010 — Xóa danh mục**: Bấm nút xóa → alert xác nhận → `DELETE /deletecategory/:id` → render lại.

#### 7.4.3 API Endpoints

| Endpoint | Method | Auth | Mô tả |
|----------|--------|------|-------|
| `/api/admin/getcategory` | GET | Admin | Lấy danh sách danh mục |
| `/api/admin/addcategory` | POST | Admin | Thêm danh mục mới |
| `/api/admin/updatecategory/:id` | PUT | Admin | Sửa danh mục |
| `/api/admin/deletecategory/:id` | DELETE | Admin | Xóa danh mục |

#### 7.4.4 Mapping classify ↔ type

| Frontend (form.type) | Backend (classify) | Hiển thị |
|----------------------|---------------------|----------|
| `income` | `thu` | Thu nhập |
| `expense` | `chi` | Chi phí |
| `debt` | `vay/no` | Vay/nợ |

#### 7.4.5 Files liên quan

| Tầng | File |
|------|------|
| **Backend** | `modules/admin/admin.controller.js` |
| | `modules/admin/admin.service.js` |
| | `modules/admin/admin.repository.js` |
| | `api/admin.routes.js` |
| **Frontend** | `pages/categories/CategoryPage.jsx` |
| | `api/admin.api.js` |


## 8. Build Module Backend (liên quan 1 phần Mobile)

### 8.1. Module AI

#### 8.1.1. Tổng quan

| Mã | Chức năng | Phương án AI | Trạng thái |
|----|----------|-------------|-----------|
| **F011** | OCR hóa đơn | Tesseract.js (self-hosted) | ⬜ Chưa làm |
| **F012** | AI phân loại giao dịch | Self-train model (fastText/BERT-tiny) | ⬜ Chưa làm |
| **F013** | AI Phân tích hành vi chi tiêu | Algorithmic + Self-train | ⬜ Chưa làm |
| **F014** | AI Dự báo chi tiêu | Self-train model (time-series) | ⬜ Chưa làm |
| **F015** | AI Đưa lời khuyên tài chính | LLM API (OpenAI/HuggingFace) | ⬜ Chưa làm |
| **F016** | AI Đề xuất phân bổ dòng tiền | Algorithmic + LLM API giải thích | ⬜ Chưa làm |
| **F017** | Chatbot AI | LLM API (OpenAI/HuggingFace) | ⬜ Chưa làm (sau cùng) |

#### 8.1.2. Chiến lược AI: Self-train Model vs LLM API

```
Self-train model (fastText/LSTM/Prophet):  F012, F013, F014, F016 (core)
LLM API (OpenAI/HuggingFace):              F015, F016 (explanation), F017
Tesseract.js:                              F011
```

| Phương án | Dùng cho | Lý do |
|-----------|----------|-------|
| **Self-train model** | Phân loại giao dịch, Phân tích hành vi, Dự báo chi tiêu, Budget math | Output cố định / dữ liệu có cấu trúc / không cần sinh ngôn ngữ |
| **LLM API** | Chatbot, Lời khuyên tài chính, Giải thích Budget | Cần NLU + NLG (sinh ngôn ngữ tự nhiên), cá nhân hóa |

#### 8.1.3. Kiến trúc AI (3 lớp)

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
│  │ Category │  │ Transaction  │  │ User Behavior      │ │
│  │ Data     │  │ History      │  │ (time, frequency,  │ │
│  │ (29 cats)│  │ (amount,     │  │  category patterns)│ │
│  │          │  │  description)│  │                    │ │
│  └──────────┘  └──────────────┘  └────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

#### 8.1.4. OCR hóa đơn (F011)

**Công nghệ**: Tesseract.js (self-hosted, miễn phí)

**Mô tả**: Dual-mode:
- **Offline (mobile)**: Google ML Kit / Tesseract on-device → trích xuất số tiền, cửa hàng, ngày → tạo giao dịch tạm → sync về backend.
- **Online (backend)**: Gửi ảnh hóa đơn → `POST /api/ai/ocr` → enqueue job `ocr-process-receipt` → Tesseract.js parse text → tạo transaction + emit event.

**Xây dựng**: Chi tiết cách xây dựng, giai đoạn tiến độ xây dựng được ghi chép lại ở đây

#### 8.1.5. AI phân loại giao dịch (F012)

**Công nghệ**: Self-train model (fastText hoặc BERT-tiny), chạy trên Node.js

**Dữ liệu huấn luyện**: CSV/JSON gồm cặp `{description, category}` từ danh mục hệ thống + dữ liệu mẫu (~500-1000 mẫu).

**Luồng**:
```
Mobile → tạo giao dịch → sync về backend
  → emit transaction.created
  → AI Worker pick job ai-classify-transaction
  → load model → predict category từ description
  → cập nhật category cho transaction
  → emit transaction.classified
```

> Phân loại giao dịch OFFLINE trên mobile do thành viên khác đảm nhiệm (dùng model nhúng trong Flutter).

#### 8.1.6. AI Phân tích hành vi chi tiêu (F013)

**Công nghệ**: Algorithmic (pattern recognition) + Self-train model

**Mô tả**: Phân tích lịch sử giao dịch để phát hiện:
- Nhóm chi tiêu theo danh mục (ăn uống chiếm X%, di chuyển Y%...)
- Thói quen chi tiêu theo thời gian (cuối tuần, đầu tháng, lễ Tết...)
- Phát hiện bất thường (transaction vượt ngưỡng, category mới xuất hiện đột ngột)
- So sánh với tháng trước / cùng kỳ năm trước

**Output**: JSON phân tích + insight text (có thể dùng LLM để paraphrase insight thành ngôn ngữ tự nhiên).

#### 8.1.7. AI Dự báo chi tiêu (F014)

**Công nghệ**: Self-train time-series model (Prophet, ARIMA, hoặc LSTM nhẹ)

**Mô tả**: Dựa trên lịch sử giao dịch 3-6 tháng gần nhất:
- Dự báo tổng chi tiêu tháng tới
- Dự báo chi tiêu theo từng danh mục
- Gợi ý ngân sách phù hợp

#### 8.1.8. AI Đưa lời khuyên tài chính (F015)

**Công nghệ**: LLM API (OpenAI GPT-4o-mini / HuggingFace free inference)

**Rate Limit**: 1 lần/giờ/user | **Cache TTL**: 1 giờ | **Max Tokens**: 300 

**Mô tả**: Kết hợp kết quả từ F013 (phân tích) + F014 (dự báo) → prompt LLM sinh lời khuyên cá nhân hóa. 

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
#### 8.1.9. AI Đề xuất phân bổ dòng tiền (F016)

**Công nghệ**: Algorithmic (core: 50/30/20, zero-based...) + LLM API (giải thích)

**Rate Limit (LLM)**: 2 lần/giờ/user | **Cache TTL**: 1 giờ | **Max Tokens**: 300 

**Mô tả**: 
- **Core**: Tính toán phân bổ ngân sách tự động từ thu nhập, lịch sử chi tiêu, mục tiêu 
- **LLM**: Cá nhân hóa giải thích 

**Prompt Template** (`modules/ai/prompts/budget-explanation.txt`): 
```text 
[SYSTEM] 
Bạn là chuyên gia lập ngân sách cá nhân. Nhiệm vụ: Giải thích lý do đề xuất phân bổ ngân sách. Dùng tiếng Việt, thân thiện, mỗi quy tắc không quá 3 câu. 

[CONTEXT] 
Người dùng: {{fullname}} | Thu nhập: {{income}} VNĐ | Quy tắc: {{strategyName}} 
Phân bổ đề xuất: {{allocations}} 
Lịch sử 3 tháng: {{historySummary}} 
Mục tiêu: {{goals}} 

[QUESTION] Giải thích lý do đề xuất và cách giúp đạt mục tiêu. 

[FORMAT] JSON: {"explanations":[{"category":"...","why":"...","tip":"..."}],"summary":"..."} 
``` 
#### 8.1.10. Chatbot AI (F017)

**Công nghệ**: LLM API (OpenAI GPT-4o-mini) với multi-provider fallback (HuggingFace → Groq) 

**Rate Limit**: 10 lần/phút/user | **Cache TTL**: 5 phút (context-based) | **Max Tokens**: 500 

**Mô tả**: User chat hỏi về tình hình tài chính. Phát triển **sau cùng**, khi F012-F016 đã hoàn thiện. 

**Prompt Template** (`modules/ai/prompts/chatbot-system.txt`): 
```text 
[SYSTEM] 
Bạn là WealthWise Assistant, trợ lý tài chính cá nhân thông minh, thân thiện. 
VAI TRÒ: Trả lời câu hỏi về tài chính cá nhân. Giải thích khái niệm đơn giản. Giúp hiểu thói quen chi tiêu. 
RÀNG BUỘC: CHỈ trả lời dựa trên dữ liệu được cung cấp. Ngoài phạm vi tài chính → từ chối lịch sự. Không đủ dữ liệu → thông báo trung thực. Dùng tiếng Việt, tự nhiên. Mỗi câu ≤ 4 câu. Không khuyên đầu tư. 

DỮ LIỆU NGƯỜI DÙNG: {{userContext}} 
LỊCH SỬ TRÒ CHUYỆN: {{chatHistory}} 
``` 

#### 8.1.11. Thứ tự triển khai

| Giai đoạn | Nội dung | Ước lượng |
|-----------|----------|-----------|
| **1** | ai.service.js + ai.controller.js + ai.routes.js (nền móng) | 1-2 ngày |
| **2** | F012 — Chuẩn bị dữ liệu + train model phân loại giao dịch | 2-3 ngày |
| **3** | F012 — BullMQ worker: predict → update DB → emit event | 1 ngày |
| **4** | F011 — OCR backend: Tesseract.js + endpoint + worker | 2-3 ngày |
| **5** | F013 — Phân tích hành vi chi tiêu (algorithmic) | 2-3 ngày |
| **6** | F014 — Dự báo chi tiêu (time-series model) | 2-3 ngày |
| **7** | F015 — Lời khuyên tài chính (LLM API) | 1-2 ngày |
| **8** | F016 — Đề xuất phân bổ dòng tiền (algorithmic + LLM) | 2-3 ngày |
| **9** | F017 — Chatbot AI (LLM API) | 2-3 ngày |

#### 8.1.12. Quy trình chuẩn xây dựng Self-train Models

Quy trình 5 bước áp dụng cho F012, F013, F014, F016 (core):

```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│ DATA     │ → │ PREP &   │ → │ TRAIN &  │ → │ EXPORT   │ → │ SERVE    │
│ COLLECT  │   │ CLEAN    │   │ EVALUATE │   │ MODEL    │   │ (Worker) │
└──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘
```

| Bước | Công cụ | Output |
|------|---------|--------|
| 1. Data Collect | SQL query từ PostgreSQL (qua Prisma) | CSV/JSON raw |
| 2. Prep & Clean | Node.js script (lodash, csv-parser) | Train/test split (80/20) |
| 3. Train & Evaluate | Python script (scikit-learn/fastText/Prophet) gọi từ Node.js qua `child_process` | Model file + metrics |
| 4. Export Model | fastText `.bin` / ONNX `.onnx` / Prophet `.json` | File model nhẹ (~1-10MB) |
| 5. Serve | Node.js load model trong ai.worker.js | Inference qua BullMQ |

**Bảng model chi tiết:**

| Model | Thuật toán | Library | Input | Output |
|-------|-----------|---------|-------|--------|
| **Transaction Classifier** (F012) | fastText (supervised) | `fasttext.js` / Python fastText | `description` (text) | `{categoryId, confidence}` |
| **Behavior Analyzer** (F013) | K-Means Clustering + Rule Engine | `ml-kmeans` (JS) hoặc scikit-learn | `{userId, transactions[]}` | `{clusters, insights, anomalies}` |
| **Expense Forecaster** (F014) | Prophet / ARIMA | Python `prophet` hoặc `statsmodels` | `{userId, monthlyTotals[]}` | `{nextMonth, byCategory[]}` |
| **Budget Allocator** (F016 core) | Rule Engine (50/30/20, zero-based) | Pure Node.js (không cần model) | `{income, history, goals}` | `{rules: [{category, amount, cap}]}` |

**Cấu trúc thư mục models:**

```
models/
├── transaction-classifier/
│   ├── train.py              # Python training script
│   ├── training-data.csv     # Sample data
│   ├── model.bin             # Exported fastText model
│   ├── labels.json           # Category mapping
│   └── metrics.json          # Accuracy, F1-score
├── behavior-analyzer/
│   ├── train.py
│   ├── centroids.json        # K-Means cluster centers
│   └── rules.json            # Business rules config
├── expense-forecaster/
│   ├── train.py
│   ├── prophet-model.json    # Serialized Prophet model
│   └── metrics.json
└── budget-allocator/
    └── strategies.json       # 50/30/20, zero-based configs
```

**Training script convention** — mỗi model 1 file `train.py` với interface thống nhất:

```python
import sys, json
def train(data_path, output_path):
    # 1. Load 2. Preprocess 3. Train 4. Evaluate 5. Export
    return metrics
if __name__ == "__main__":
    metrics = train(sys.argv[1], sys.argv[2])
    print(json.dumps(metrics))
```

Gọi từ Node.js: `const metrics = execSync(\`python models/transaction-classifier/train.py "${dataPath}" "${outputPath}"\`);`

#### 8.1.13. Kiến trúc LLM API (F015, F016 explanation, F017)

**Multi-provider với fallback** — `modules/ai/llm/llmClient.js` (singleton):

| Provider | Model | Dùng cho | Giới hạn free |
|----------|-------|----------|---------------|
| **OpenAI** | GPT-4o-mini | Primary (chatbot, advice) | $5 credit |
| **HuggingFace** | mistral-7b / zephyr-7b | Fallback #1 | Free (rate limit) |
| **Groq** | llama-3.1-8b | Fallback #2 | Free (~30 req/min) |

```js
// llmClient.js — thử từng provider đến khi thành công
const providers = [openaiProvider, huggingfaceProvider, groqProvider];
async function chat(messages, options) {
  for (const p of providers) {
    try { return await p.chat(messages, options); }
    catch { logger.warn(`Provider ${p.name} failed, trying next...`); }
  }
  throw new Error('All LLM providers failed');
}
```

**Rate Limiter** (`modules/ai/llm/rate-limiter.js`): In-memory sliding window per user. Trả về 429 nếu vượt giới hạn.

**LLM Cache** (`modules/ai/llm/cache.js`): Redis-backed, TTL theo từng chức năng (xem bảng dưới), key = `llm:cache:{functionName}:{userId}:{contextHash}`.

**Bảng cấu hình per function:**

| Function | Rate Limit | Cache TTL | Max Tokens | Priority |
|----------|-----------|-----------|------------|----------|
| F015 — Lời khuyên | 1/giờ/user | 1 giờ | 300 | Thấp |
| F016 — Giải thích Budget | 2/giờ/user | 1 giờ | 300 | Thấp |
| F017 — Chatbot | 10/phút/user | 5 phút | 500 | Cao |

**Thư mục prompts:**
```
modules/ai/prompts/
├── financial-advice.txt       # F015
├── budget-explanation.txt     # F016
└── chatbot-system.txt         # F017
```

#### 8.1.14. Kiến trúc Worker: Chạy chung vs Chạy riêng

| Tiêu chí | Chạy chung (cùng process Express) | Chạy riêng (process độc lập) |
|----------|-----------------------------------|------------------------------|
| **Khởi động** | 1 lệnh `node index.js` | Cần script riêng, PM2/Docker |
| **Memory** | Chia sẻ RAM với API | RAM riêng, không ảnh hưởng API |
| **CPU** | Cạnh tranh CPU, risk block event loop | CPU riêng, không block API |
| **Code sharing** | Import trực tiếp service/repository | Cần shared package |
| **Deploy** | 1 container | 2+ container |
| **Scale** | Cùng nhau (không linh hoạt) | Độc lập |
| **Debug** | 1 log stream | Log riêng |
| **Phù hợp** | Model nhẹ (<10MB), dev/local | Model nặng (>100MB), production |

**Đề xuất cho dự án:**

```
DEV (hiện tại):               PRODUCTION (tương lai):
┌─────────────────────┐        ┌──────────────┐   ┌──────────────┐
│  Express + Workers   │        │  Express API  │   │  AI Worker   │
│  (cùng process)      │   →    │  (container 1)│   │  (container 2)│
│  - fastText (<10MB)  │        │  - HTTP only  │   │  - fastText  │
│  - Tesseract.js       │        │  - Redis      │   │  - Tesseract │
│  - LLM calls         │        │  - BullMQ     │   │  - LLM calls │
└─────────────────────┘        └──────────────┘   └──────────────┘
```

- **GĐ1 (hiện tại)**: Chạy chung — đơn giản, model fastText nhẹ (~5MB) không ảnh hưởng event loop.
- **GĐ2 (production)**: Tách worker riêng khi cần scale hoặc model nặng hơn.

#### 8.1.15. Tổng kết công nghệ theo chức năng

| F# | Chức năng | Model/API | Thư viện | Interface |
|----|----------|-----------|----------|-----------|
| F011 | OCR | Tesseract.js | `tesseract.js` | Worker + BullMQ |
| F012 | Phân loại GD | fastText | Python fastText → `.bin` → `fasttext.js` | Worker + BullMQ |
| F013 | Phân tích hành vi | K-Means + Rules | `ml-kmeans` / scikit-learn | REST API |
| F014 | Dự báo chi tiêu | Prophet | Python prophet → `.json` | REST API |
| F015 | Lời khuyên TC | GPT-4o-mini | OpenAI SDK + multi-provider | REST API |
| F016 | Phân bổ dòng tiền | Rule Engine + GPT-4o-mini | Pure JS + OpenAI SDK | REST API |
| F017 | Chatbot AI | GPT-4o-mini + fallback | OpenAI SDK + multi-provider | REST API |

#### 8.1.16. Files dự kiến (đầy đủ)

| Tầng | File |
|------|------|
| **Backend** | `modules/ai/ai.controller.js` (mới) |
| | `modules/ai/ai.service.js` (mới) |
| | `modules/ai/ai.repository.js` (mới) |
| | `modules/ai/ai.validation.js` (mới) |
| | `modules/ai/ai.jobs.js` (mới — enqueue helpers) |
| | `modules/ai/llm/llmClient.js` (mới — multi-provider) |
| | `modules/ai/llm/openaiProvider.js` (mới) |
| | `modules/ai/llm/huggingfaceProvider.js` (mới) |
| | `modules/ai/llm/groqProvider.js` (mới) |
| | `modules/ai/llm/rate-limiter.js` (mới) |
| | `modules/ai/llm/cache.js` (mới — Redis-backed) |
| | `modules/ai/prompts/financial-advice.txt` (mới) |
| | `modules/ai/prompts/budget-explanation.txt` (mới) |
| | `modules/ai/prompts/chatbot-system.txt` (mới) |
| | `api/ai.routes.js` (cập nhật) |
| | `workers/ai.worker.js` (cập nhật — classify + OCR) |
| **Models** | `models/transaction-classifier/` (train.py + model.bin + data) |
| | `models/behavior-analyzer/` (train.py + centroids.json) |
| | `models/expense-forecaster/` (train.py + prophet-model.json) |
| | `models/budget-allocator/strategies.json` |

### 8.2. Module Notification

### 8.3. Module Bank

### 8.4. Module Sync


---

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

---

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



