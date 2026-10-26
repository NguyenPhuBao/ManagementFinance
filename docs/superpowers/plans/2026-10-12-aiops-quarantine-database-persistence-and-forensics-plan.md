# Kế Hoạch Triển Khai: Lưu Trữ Bền Vững Ma Trận Phong Tỏa AIOps & Truy Vết An Ninh Điều Tra (Phương Án 1: 3 Bảng Quan Hệ N-N)

> **Dành cho Agentic Workers:** YÊU CẦU SUB-SKILL: Dùng `superpowers:subagent-driven-development` để thực thi kế hoạch này từng task một theo quy trình TDD. Các bước dùng cú pháp checkbox (`- [ ]`) để theo dõi tiến độ.

**Mục tiêu (Goal):** Thiết kế và triển khai cơ chế lưu trữ bền vững trong CSDL PostgreSQL (Supabase) cho toàn bộ dữ liệu phong tỏa của AIOps Sentinel theo **Phương án 1 (3 Bảng quan hệ N-N)**: 1 bảng cho Địa chỉ IP, 1 bảng cho Tài khoản, và 1 bảng liên kết sự kiện vi phạm N-N; bảo toàn nguyên vẹn 100% dữ liệu cấm khi server khởi động lại (Zero-loss on restart) và cung cấp khả năng truy vết, điều tra an ninh chuyên sâu.

**Kiến trúc (Architecture):** 
Kiến trúc phối hợp **Hybrid Write-Through & Memory Hydration Cache**:
1. Lớp CSDL PostgreSQL lưu trữ vĩnh viễn 3 bảng: `aiops_ip_quarantine` (vòng đời IP), `aiops_account_quarantine` (vòng đời tài khoản), và `aiops_quarantine_incident_link` (nhật ký liên kết N-N).
2. Khi Server Node.js khởi động (boot/restart), `AIOpsQuarantineRepository` tự động truy vấn các bản ghi đang có hiệu lực (`TEMPORARY` chưa hết hạn hoặc `PERMANENT`) để nạp (hydrate) vào In-Memory Map.
3. Khi phát hiện tấn công mới hoặc Admin thao tác (Mở khóa / Khóa vĩnh viễn), hệ thống cập nhật tức thì In-Memory Cache (đảm bảo tốc độ chặn $O(1) < 1\text{ms}$) và ghi bất đồng bộ an toàn xuống CSDL PostgreSQL kèm lưu vết `banned_by`, `unblocked_by`, `banned_at`, `unblocked_at`.

**Sơ đồ Kiến trúc (Architecture Diagram):**

```mermaid
graph TD
    subgraph "Admin & Traffic Layer"
        Req[Incoming Request] --> Mw[AIOps Quarantine Middleware]
        Admin[Admin Web UI] --> API[Admin AIOps Endpoints]
    end

    subgraph "AIOps Quarantine Core (In-Memory Engine)"
        Mw -->|Kiểm tra O(1) < 1ms| MemMap[In-Memory Maps & Pairs]
        MemMap -->|Chặn kết nối| Block[HTTP 403 Forbidden]
        API -->|Thao tác Mở/Khóa| MemMap
    end

    subgraph "Persistence & Repository Layer"
        API --> Repo[AIOpsQuarantineRepository]
        MemMap -.->|Async Write-through| Repo
        Boot[Server Boot / Restart] -->|Hydrate Active Cache| Repo
    end

    subgraph "PostgreSQL Database Layer (Phương Án 1)"
        Repo --> B1[(aiops_ip_quarantine)]
        Repo --> B2[(aiops_account_quarantine)]
        Repo --> B3[(aiops_quarantine_incident_link)]
        B3 -.->|FK N-N| B1
        B3 -.->|FK N-N| B2
        Repo --> AccDB[(account.status = Locked/Active)]
    end
```

**Tech Stack:** Node.js, Express, PostgreSQL 15 (Supabase), pg Pool, Prisma Client, React, Vite, TailwindCSS, Vitest, Testing Library.

## Ràng Buộc Bắt Buộc (Global Constraints)
1. **Rule 10 (DB Guard):** Tuyệt đối KHÔNG chạy `prisma migrate dev` hoặc `prisma db push` trên Supabase Cloud. Mọi DDL phải viết thành script SQL an toàn `src/Backend/database/26_create_aiops_quarantine_tables.sql` với `CREATE TABLE IF NOT EXISTS` và `CREATE INDEX IF NOT EXISTS`.
2. **Rule 9 (Data Security & Nghị định 13/2023/NĐ-CP):** IP lưu trên hệ thống phải luôn có `ip_hash` (SHA-256) và `masked_ip` (`113.161.xx.xx`). Nhật ký sự cố lưu trữ tối thiểu 12 tháng theo Luật An ninh mạng & Nghị định 53/2022/NĐ-CP.
3. **Rule 11 (2-Tier Testing Architecture):** Mọi tính năng phải có đủ cả 2 tầng: Tầng 1 (UI Rendering & Interaction) và Tầng 2 (Tác động CSDL thực tế & System Impact).
4. **Hiệu năng Firewall:** Việc truy vấn chặn request ở middleware tuyệt đối không query DB trực tiếp trên từng request mà phải kiểm tra $O(1)$ qua RAM Cache đã được hydrate từ DB.

---

## Danh Sách Task Triển Khai (Bite-Sized Tasks)

### Task 1: Thiết Kế Script SQL DDL & Migration CSDL (3 Bảng Chuẩn Hóa N-N)

**Files:**
- Create: `src/Backend/database/26_create_aiops_quarantine_tables.sql`
- Modify: `src/Backend/prisma/schema.prisma`
- Test: `src/Backend/tests/unit/aiops.quarantine.ddl.test.js`

**Interfaces:**
- Produces: 3 bảng CSDL PostgreSQL: `aiops_ip_quarantine`, `aiops_account_quarantine`, `aiops_quarantine_incident_link`.

- [ ] **Step 1.1: Viết test kiểm tra cú pháp và cấu trúc bảng DDL SQL**
  - Viết test suite `tests/unit/aiops.quarantine.ddl.test.js` kiểm tra nội dung file SQL có đủ 3 bảng, các cột bắt buộc: `status`, `reason`, `banned_at`, `expires_at`, `unblocked_at`, `banned_by`, `unblocked_by`, `masked_ip`, `ip_hash`, `username`, các khóa ngoại FK và indexes.

- [ ] **Step 1.2: Chạy test để xác nhận test FAIL (Red Phase)**
  - Chạy `rtk npm test -- tests/unit/aiops.quarantine.ddl.test.js` trong `src/Backend`.

- [ ] **Step 1.3: Tạo file SQL DDL `26_create_aiops_quarantine_tables.sql`**
  - Bảng 1 `aiops_ip_quarantine`: `id` VARCHAR(64) PK, `ip_hash` VARCHAR(64) UNIQUE, `masked_ip` VARCHAR(45), `raw_ip` VARCHAR(45) NULL, `status` VARCHAR(20) DEFAULT 'TEMPORARY', `reason` TEXT, `violation_vector` VARCHAR(20), `threat_score_at_ban` INT, `hits` INT DEFAULT 1, `banned_at` TIMESTAMPTZ DEFAULT NOW(), `expires_at` TIMESTAMPTZ NULL, `unblocked_at` TIMESTAMPTZ NULL, `banned_by` VARCHAR(100), `unblocked_by` VARCHAR(100), `unblock_reason` TEXT, `created_at` TIMESTAMPTZ, `updated_at` TIMESTAMPTZ.
  - Bảng 2 `aiops_account_quarantine`: `id` VARCHAR(64) PK, `idaccount` INT NULL FK->account, `username` VARCHAR(255), `status` VARCHAR(20) DEFAULT 'TEMPORARY', `reason` TEXT, `violation_vector` VARCHAR(20), `hits` INT DEFAULT 1, `banned_at` TIMESTAMPTZ DEFAULT NOW(), `expires_at` TIMESTAMPTZ NULL, `unblocked_at` TIMESTAMPTZ NULL, `banned_by` VARCHAR(100), `unblocked_by` VARCHAR(100), `unblock_reason` TEXT, `created_at` TIMESTAMPTZ, `updated_at` TIMESTAMPTZ.
  - Bảng 3 `aiops_quarantine_incident_link`: `id` SERIAL PK, `ip_quarantine_id` VARCHAR(64) FK->aiops_ip_quarantine, `account_quarantine_id` VARCHAR(64) FK->aiops_account_quarantine, `ip_hash` VARCHAR(64), `username` VARCHAR(255), `reason` TEXT, `incident_code` VARCHAR(50), `detected_at` TIMESTAMPTZ DEFAULT NOW().
  - Thêm các indexes tối ưu truy vấn theo status, expires_at, ip_hash, username, detected_at.

- [ ] **Step 1.4: Cập nhật `src/Backend/prisma/schema.prisma`**
  - Thêm 3 models: `model aiops_ip_quarantine`, `model aiops_account_quarantine`, `model aiops_quarantine_incident_link`.
  - Chạy `rtk npm run prisma:generate` để tạo type definitions.

- [ ] **Step 1.5: Chạy test xác nhận PASS (Green Phase)**
  - Chạy `rtk npm test -- tests/unit/aiops.quarantine.ddl.test.js`.

---

### Task 2: Xây Dựng `AIOpsQuarantineRepository` Quản Lý Đọc/Ghi 3 Bảng

**Files:**
- Create: `src/Backend/modules/aiops/aiops.quarantine.repository.js`
- Test: `src/Backend/tests/unit/aiops.quarantine.repository.test.js`

**Interfaces:**
- Consumes: PostgreSQL connection `pool` từ `src/Backend/config/db.js`.
- Produces: Class `AIOpsQuarantineRepository` với các API:
  + `initTables()`: Khởi tạo bảng DDL an toàn
  + `recordQuarantinePair({ ip, maskedIp, ipHash, username, idaccount, reason, durationMs, banType, vector, threatScore, bannedBy })`
  + `loadActiveQuarantines()`: Trả về danh sách IP và tài khoản đang có hiệu lực để nạp vào RAM
  + `updateIpStatus({ ipHash, status, unblockedBy, unblockReason })`
  + `updateAccountStatus({ username, idaccount, status, unblockedBy, unblockReason })`
  + `getForensicInvestigationLogs({ ipHash, username, page, limit })`: Truy vấn dữ liệu điều tra liên kết N-N.

- [ ] **Step 2.1: Viết unit test cho `AIOpsQuarantineRepository`**
  - Viết test mô phỏng `recordQuarantinePair`: tạo mới IP và Tài khoản, liên kết N-N trong `aiops_quarantine_incident_link`.
  - Viết test cho `loadActiveQuarantines`: chỉ nạp các bản ghi `TEMPORARY` chưa hết hạn và `PERMANENT`.
  - Viết test cho `updateIpStatus` và `updateAccountStatus`: cập nhật trạng thái `UNLOCKED` kèm `unblocked_at`, `unblocked_by`.
  - Viết test cho `getForensicInvestigationLogs`: lấy danh sách các tài khoản bị tấn công bởi IP $X$ và danh sách các IP tấn công Tài khoản $Y$.

- [ ] **Step 2.2: Chạy test xác nhận FAIL (Red Phase)**
  - Chạy `rtk npm test -- tests/unit/aiops.quarantine.repository.test.js`.

- [ ] **Step 2.3: Triển khai mã nguồn `aiops.quarantine.repository.js`**
  - Viết các câu lệnh SQL parameterized chống SQL injection.
  - Cung cấp `_inMemoryFallback` an toàn cho môi trường test khi không có kết nối PostgreSQL thật.

- [ ] **Step 2.4: Chạy test xác nhận PASS (Green Phase)**
  - Chạy `rtk npm test -- tests/unit/aiops.quarantine.repository.test.js`.

---

### Task 3: Tích Hợp Persistence & Hydration Vào `AIOpsQuarantine` Engine

**Files:**
- Modify: `src/Backend/modules/aiops/aiops.quarantine.js`
- Modify: `src/Backend/app.js` (hoặc khởi tạo server)
- Test: `src/Backend/tests/unit/aiops.quarantine.persistence.test.js`

**Interfaces:**
- Consumes: `AIOpsQuarantineRepository` từ Task 2.
- Produces:
  + `quarantinePair()`: Cập nhật RAM tức thì + Async Write-through xuống DB.
  + `hydrateFromDatabase()`: Nạp lại trạng thái sau restart server.
  + `unblockIp()`, `permanentBanIp()`, `unblockAccount()`, `permanentBanAccount()`: Đồng bộ DB.

- [ ] **Step 3.1: Viết test kiểm thử cơ chế Hydration và Write-through**
  - Viết test mô phỏng kịch bản: Ghi nhận 1 IP bị cấm vĩnh viễn và 1 IP tạm khóa; tiến hành khởi tạo một instance `AIOpsQuarantine` hoàn toàn mới (mô phỏng restart); gọi `hydrateFromDatabase()` -> xác nhận instance mới chặn chính xác cả 2 IP ngay lập tức ($O(1)$).

- [ ] **Step 3.2: Chạy test xác nhận FAIL (Red Phase)**
  - Chạy `rtk npm test -- tests/unit/aiops.quarantine.persistence.test.js`.

- [ ] **Step 3.3: Tích hợp `repository` vào `aiops.quarantine.js`**
  - Thêm phương thức `hydrateFromDatabase()` trong `AIOpsQuarantine`.
  - Trong `quarantinePair`: gọi `repository.recordQuarantinePair()` bất đồng bộ an toàn.
  - Trong `unblockIp`, `permanentBanIp`: gọi `repository.updateIpStatus()`.
  - Trong `unblockAccount`, `permanentBanAccount`: gọi `repository.updateAccountStatus()`.
  - Tự động gọi `hydrateFromDatabase()` trong hàm bootstrap khởi động của backend.

- [ ] **Step 3.4: Chạy test xác nhận PASS (Green Phase)**
  - Chạy `rtk npm test -- tests/unit/aiops.quarantine.persistence.test.js`.

---

### Task 4: Cập Nhật Controllers, Routes & API Truy Vết An Ninh Điều Tra

**Files:**
- Modify: `src/Backend/modules/aiops/aiops.controller.js`
- Modify: `src/Backend/api/admin.routes.js`
- Test: `src/Backend/tests/unit/aiops.quarantine.controller.test.js`

**Interfaces:**
- Produces API Endpoints:
  + `GET /api/admin/system/aiops/quarantine`: Danh sách ma trận kèm thông tin liên kết N-N.
  + `GET /api/admin/system/aiops/quarantine/forensics`: API điều tra chuyên sâu (tra cứu chéo IP $\leftrightarrow$ Tài khoản).
  + `POST /api/admin/system/aiops/quarantine/unblock-ip`: Ghi nhận `unblocked_by = req.user.username`.
  + `POST /api/admin/system/aiops/quarantine/ban-ip`: Ghi nhận `banned_by = req.user.username`.
  + `POST /api/admin/system/aiops/quarantine/unblock-account`: Ghi nhận `unblocked_by = req.user.username`.
  + `POST /api/admin/system/aiops/quarantine/ban-account`: Ghi nhận `banned_by = req.user.username`.

- [ ] **Step 4.1: Viết test cho Controller và Endpoints mới**
  - Viết test kiểm tra gọi endpoint forensics trả về danh sách lịch sử vi phạm liên kết N-N.
  - Viết test xác nhận `unblocked_by` và `banned_by` được trích xuất từ JWT admin đang đăng nhập.

- [ ] **Step 4.2: Chạy test xác nhận FAIL (Red Phase)**
  - Chạy `rtk npm test -- tests/unit/aiops.quarantine.controller.test.js`.

- [ ] **Step 4.3: Triển khai mã nguồn Controller & Routes**
  - Cập nhật `aiops.controller.js` và đăng ký route trong `admin.routes.js`.

- [ ] **Step 4.4: Chạy test xác nhận PASS (Green Phase)**
  - Chạy `rtk npm test -- tests/unit/aiops.quarantine.controller.test.js`.

---

### Task 5: Nâng Cấp Giao Diện Admin-web Với Modal/Tab Điều Tra An Ninh Chuyên Sâu

**Files:**
- Modify: `src/Admin-web/src/api/aiops.api.js`
- Modify: `src/Admin-web/src/pages/system/AIOpsPage.jsx`
- Modify: `src/Admin-web/src/locales/vi.js` & `en.js`
- Test: `src/Admin-web/src/tests/aiops.quarantine.forensics.ui.test.jsx`

**Interfaces:**
- Giao diện người dùng:
  + Bảng ma trận phong tỏa hiển thị số lượng liên kết (ví dụ: `113.161.xx.xx` [3 tài khoản liên đới], click để mở Modal điều tra).
  + Modal "Hồ Sơ Điều Tra An Ninh AIOps": Xem chi tiết toàn bộ lịch sử vi phạm theo trục thời gian, ai đã khóa, ai đã mở khóa, lý do, vectơ tấn công.

- [ ] **Step 5.1: Viết kiểm thử Tầng 1 (UI Interaction & Rendering)**
  - Viết test `src/tests/aiops.quarantine.forensics.ui.test.jsx`: kiểm tra render huy hiệu liên kết, click mở Modal điều tra, hiển thị dữ liệu lịch sử từ API.

- [ ] **Step 5.2: Chạy test xác nhận FAIL (Red Phase)**
  - Chạy `rtk npx vitest run src/tests/aiops.quarantine.forensics.ui.test.jsx` trong `src/Admin-web`.

- [ ] **Step 5.3: Cập nhật API client, Locales và JSX**
  - Thêm `getForensics` vào `aiops.api.js`.
  - Cập nhật JSX trong `AIOpsPage.jsx` với modal chi tiết điều tra.
  - Bổ sung các bản dịch tiếng Việt và tiếng Anh.

- [ ] **Step 5.4: Chạy test xác nhận PASS (Green Phase)**
  - Chạy `rtk npx vitest run src/tests/aiops.quarantine.forensics.ui.test.jsx`.

---

### Task 6: Kiểm Thử Toàn Diện 2 Tầng, Cập Nhật Nguồn Sự Thật & CodeGraph

**Files:**
- Verify All Test Suites: Backend & Admin-web
- Modify: `Project.md`
- Run: `rtk npx codegraph build`

- [ ] **Step 6.1: Chạy toàn bộ test Backend**
  - Chạy `rtk npm test` trong `src/Backend` (bao gồm toàn bộ 34+ tests AIOps và các unit tests mới).
- [ ] **Step 6.2: Chạy toàn bộ test Admin-web**
  - Chạy `rtk npm test` trong `src/Admin-web`.
- [ ] **Step 6.3: Kiểm tra Build Production**
  - Chạy `rtk npm run build` trong `src/Admin-web`.
- [ ] **Step 6.4: Cập nhật tài liệu nguồn sự thật (Rule 8)**
  - Cập nhật `Project.md` ghi nhận kiến trúc 3 bảng CSDL `aiops_ip_quarantine`, `aiops_account_quarantine`, `aiops_quarantine_incident_link`.
- [ ] **Step 6.5: Tái xây dựng CodeGraph (Rule 8)**
  - Chạy `rtk npx codegraph build` tại root directory.
