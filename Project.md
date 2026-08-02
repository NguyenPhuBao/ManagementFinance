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
| **UI Components** | Ant Design |
| **Authentication** | JWT, lưu token trong memory/cookie (httponly) |

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

### 4.2 Admin-web — React SPA (Vite + Ant Design)

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

| Module | Framework / Language | Database / Tools | Notes |
|---|---|---|---|
| **Backend** | NodeJS + ExpressJS | PostgreSQL (CSDL chính), Redis + BullMQ (cache & queue) | Modular Monolithic, Event-Driven, Layer Pattern |
| **Admin-web** | ReactJS + Vite | Ant Design, React Router DOM v6, Axios, Socket.IO-client | SPA, real-time event |
| **Client-app** | Dart + Flutter | SQLite (local DB), Dio (HTTP client), BloC (state management) | Offline-first, tự động đồng bộ real-time khi có internet |

---

## 6. Chức Năng Chính (Features)

### 6.1 Chức năng Đăng nhập & Đăng ký
| Mã | Chức năng | Đối tượng sử dụng | Module | Trạng thái |
|----|----------|-------------------|--------|-----------|
| **F001** | Đăng nhập hệ thống | Admin, User | auth | ✅ Done |
| **F002** | Đăng ký tài khoản | User (Mobile-app) | auth | ✅ Done |

#### Mô tả chức năng

**Lựa chọn 1 (KHUYẾN NGHỊ CỰC MẠNH): "Vô hạn" nhờ Tự động Refresh ngầm**

Đây là cách các "ông lớn" như Google, Facebook, Spotify làm. **Token cục bộ chỉ có hiệu lực vài tháng, nhưng người dùng KHÔNG BAO GIỜ thấy màn hình đăng nhập lại.**

- **Cơ chế**:
  - Cấp `Access Token` thời hạn **60 ngày** (hoặc 180 ngày).
  - Cấp `Refresh Token` thời hạn **3 năm** (hoặc 10 năm), lưu trong Secure Storage.

- **Luồng hoạt động thực tế**:
  - Mỗi khi app mở (có Internet), Flutter tự động gọi API `/refresh` ở chế độ nền, đổi `Access Token` cũ lấy `Access Token` mới (thời hạn lại được reset về 60 ngày). Người dùng **hoàn toàn không hay biết**.
  - Chỉ khi nào **3 năm trôi qua** và `Refresh Token` hết hạn, app mới bắt buộc đăng nhập lại. Trong thực tế, 3 năm tương đương với vòng đời của một chiếc điện thoại.
  - **Với Offline**: Nếu mất Internet trong vài tháng, app vẫn dùng `Access Token` cũ để mở khóa SQLite. Khi có mạng trở lại, app tự refresh ngầm.

**Lý do an toàn**: Nếu token 60 ngày bị đánh cắp, thời gian khai thác chỉ còn 60 ngày. Nếu phát hiện bất thường, Server chỉ cần vô hiệu hóa `Refresh Token` trên DB, người dùng sẽ bị logout ngay lần có mạng tiếp theo (đáp ứng yêu cầu bắt buộc xác thực lại nếu cần).

### 6.2. Chức năng ...

---

## 7. Đặc Tả & Yêu Cầu Nghiệp Vụ

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



