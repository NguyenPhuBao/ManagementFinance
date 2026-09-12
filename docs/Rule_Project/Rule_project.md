# 📜 TỔNG HỢP NGUYÊN TẮC & QUY TẮC DỰ ÁN — MANAGEMENTFINANCE
> **Source of Truth** về các nguyên tắc kiến trúc, quy trình vận hành phát triển phần mềm, cùng toàn bộ các quy tắc kỹ thuật và nghiệp vụ cụ thể của hệ thống **ManagementFinance**.
>
> *Ngày cập nhật:* 2026-09-10  
> *Phạm vi áp dụng:* Toàn bộ dự án (`src/Backend`, `src/Admin-web`, `src/Client-app`).

---

# 🏛️ PHẦN I: NGUYÊN TẮC XÂY DỰNG & VẬN HÀNH DỰ ÁN

## ⚡ 1. KHẨU HIỆU & QUY TẮC CỐT LÕI (TL;DR)

```
RTK | CODEGRAPH | PROJECT.MD | DATA_SECURITY | SKILL→PHASE | KARPATHY | SELF-CHECK
```

* **RTK mọi lệnh CLI:** Mọi lệnh terminal bắt buộc có tiền tố `rtk` (ví dụ: `rtk npm test`, `rtk git status`).
* **CodeGraph kiểm tra tác động:** Dùng `brief`, `deps`, `context`, `impact` trước khi sửa mã nguồn.
* **Project.md nắm ngữ cảnh:** Đọc `Project.md` để nắm kiến trúc, tech stack và quy ước trước khi bắt đầu.
* **Data_Security.md tuân thủ pháp luật:** Bắt buộc tuân thủ 100% nguyên tắc bảo vệ dữ liệu nhạy cảm theo `docs/Rule_Project/Data_Security.md` (Nghị định 13/2023/NĐ-CP, PCI-DSS, OWASP).
* **Đúng Skill $\rightarrow$ Đúng Phase:** Tuân thủ 4 Phase tuần tự (Scope $\rightarrow$ TDD $\rightarrow$ Systematic Debug $\rightarrow$ Verify & Ship).
* **Karpathy Guidelines:** Think before coding, Simplicity first, Plan then execute, Test everything.
* **Self-Check trước khi "Done":** Chỉ bàn giao khi kiểm thử 100% PASS, tài liệu và CodeGraph đã cập nhật.

---

## 👥 2. ĐỊNH VI VAI TRÒ & THẨM QUYỀN TRONG DỰ ÁN

| Thực thể | Vai trò | Trách nhiệm & Quyền hạn |
|---|---|---|
| **Người Dùng (PO)** | **Product Owner** | • Đưa ra yêu cầu, phạm vi và mục tiêu nghiệp vụ.<br>• Phê duyệt các phương án kiến trúc, kế hoạch thực thi (Implementation Plan) trước khi viết code.<br>• Thẩm định chất lượng bàn giao cuối cùng. |
| **AI Assistant** | **Senior BA** | • Lắng nghe, phân tích và làm rõ đặc tả chức năng.<br>• Dùng phương pháp Socratic / hỏi ngược khi yêu cầu mơ hồ.<br>• Đưa ra các phân tích đánh đổi (trade-offs) thay vì tự ý suy đoán. |
| **AI Assistant** | **Senior Fullstack** | • Hiện thực hóa giải pháp ở cả 3 module (Backend, Admin-web, Client-app).<br>• Viết mã sạch (Clean Code), bám sát nguyên tắc SOLID, KISS, YAGNI.<br>• Mapping chuẩn xác giao tiếp giữa Client, Admin và Backend. |
| **AI Assistant** | **Senior Tester** | • Thực thi kiểm thử song hành (TDD: Red $\rightarrow$ Green $\rightarrow$ Refactor).<br>• Viết test ngay khi hoàn thành từng đơn vị chức năng, không chờ đến cuối mới kiểm thử. |

> [!IMPORTANT]
> **Quy định bất di bất dịch về yêu cầu:**  
> 1. AI chỉ làm đúng yêu cầu mà PO đưa ra, tuyệt đối không làm lan man, phỏng đoán hay vượt quá yêu cầu.  
> 2. Nếu phát hiện hướng đi mới, rủi ro tiềm ẩn hoặc yêu cầu tiếp theo cần thiết, AI phải lập đề xuất và chờ PO phê duyệt mới được triển khai.

---

## 🏗️ 3. NGUYÊN TẮC THIẾT KẾ & KIẾN TRÚC HỆ THỐNG

### 3.1. Bốn Trụ Cột Thiết Kế (Architectural Pillars)

1. **Modularity (Tính module hóa):**
   * Hệ thống chia thành các module rõ ràng.
   * Backend đảm nhận các module trực tuyến/kết nối internet: **Auth, Admin, Sync Engine, Bank Integration, AI Processing, Notification**.
   * Client-app đảm nhận các module nghiệp vụ cá nhân: **Transaction, Wallet, Budget, Goal, Bill, Report**.
2. **Event-Driven (Kiến trúc hướng sự kiện):**
   * Các module kết nối lỏng lẻo (loose coupling) qua Event Bus (Redis Pub/Sub + BullMQ).
   * Các tác vụ tốn tài nguyên (AI phân loại, OCR hóa đơn, Webhook biến động số dư ngân hàng, gửi thông báo) được đẩy vào hàng đợi bất đồng bộ, giải phóng API phản hồi tức thì.
3. **Offline-First (Ưu tiên ngoại tuyến):**
   * Client-app (Flutter + SQLite) hoạt động độc lập 100% ngay cả khi mất kết nối mạng.
   * Toàn bộ thao tác CRUD được thực thi trên local database. Khi có kết nối internet, Sync Engine sẽ tự động đồng bộ 2 chiều (Push/Pull) lên Backend với cơ chế giải quyết xung đột (Conflict Resolution).
4. **Separation of Concerns (Phân tách trách nhiệm):**
   * Backend là trung tâm dữ liệu tập trung (Single Source of Truth), quản lý xác thực, cấp quyền, audit log và đồng bộ.
   * Client-app tự xử lý tính toán số dư tạm thời, validation giao diện, không đè nặng logic xử lý giao diện lên backend.

---

### 3.2. Quy Tắc Cơ Sở Dữ Liệu & Thay Đổi Lược Đồ (Database Rules)

Khi có bất kỳ thay đổi nào về CSDL PostgreSQL:

1. **Bản tường minh SQL:** Bắt buộc tạo file script `.sql` trong thư mục `database/` để làm bản sao lưu và phục vụ khôi phục thảm họa.
2. **Khai báo Prisma:** Cập nhật chính xác `src/Backend/prisma/schema.prisma`.
3. **Migration:** CSDL được quản lý đồng bộ qua tệp script `database/N_*.sql` (đến migration 12) kết hợp cập nhật `schema.prisma` và lệnh `prisma generate` để đồng bộ Client ORM.
4. **BẮT BUỘC ĐỒNG BỘ MODULE SYNC:**  
   Mọi thay đổi cột, bảng hoặc quan hệ trong CSDL đều **bắt buộc phải cập nhật Module Sync** (`sync.service.js`, `sync.repository.js`, `sync.validation.js`) theo đúng khuôn mẫu hiện tại để đảm bảo Client-app có thể đẩy/kéo các trường mới.
5. **An toàn dữ liệu (Data Safety):**
   * Các cột mới bổ sung phải luôn có giá trị mặc định (`DEFAULT`) hoặc chấp nhận `NULL` để không làm đứt gãy dữ liệu lịch sử.
   * Ràng buộc xóa đối với dữ liệu liên kết giao dịch phải dùng `ON DELETE SET NULL` hoặc `RESTRICT` có kiểm soát, tuyệt đối không xóa dây chuyền làm mất giao dịch tài chính của người dùng.

---

### 3.3. Quy Tắc Đồng Bộ Dữ Liệu (Sync Engine Standards)

* **Xóa lũy kế / An toàn (Idempotent Delete):**
  * Yêu cầu xóa một bản ghi không tồn tại trên server (hoặc đã được xóa trước đó) phải được xem là thành công (`synced`, message `Already absent`). Tuyệt đối không trả mã lỗi `400/500` làm kẹt vòng lặp đẩy lại vĩnh viễn trên thiết bị di động.
* **Thứ tự ưu tiên thực thể (`ENTITY_PRIORITY`):**
  * Đồng bộ phải tuân theo thứ tự phụ thuộc dữ liệu:  
    `category` (10) $\rightarrow$ `wallet` (20) $\rightarrow$ `budget`, `bill`, `goal` (30) $\rightarrow$ `transaction` (40). Thao tác **xoá** chạy ngược lại: `transaction` (60) $\rightarrow$ `budget`/`bill`/`goal` (70) $\rightarrow$ `wallet` (80) $\rightarrow$ `category` (90) — `sync.service.js:46-63`.
* **UUID Danh mục Mặc định Ổn Định (Stable UUIDs):**
  * Các danh mục hệ thống mặc định phải dùng tập UUID cố định đóng băng (trong `seed.js`), không được sinh UUID ngẫu nhiên mỗi lần seed lại để tránh lệch dữ liệu với SQLite client.
* **Toàn vẹn tên danh mục:**
  * Chống trùng tên danh mục giữa các bản ghi đang hoạt động (Partial Unique Index lọc `Delete_at IS NULL`).
  * Người dùng **được phép** tạo danh mục cá nhân trùng tên với danh mục mẫu hệ thống (mô hình Template & Cloned Model) — trigger chéo cũ đã gỡ (database/5), xem mục 1.2.

---

## 🔄 4. QUY TRÌNH CHUYỂN GIAO 4-PHASE (AI DELIVERY WORKFLOW)

Mọi yêu cầu kỹ thuật phải đi qua 4 Phase tuần tự:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│     PHASE 1     │────▶│     PHASE 2     │────▶│     PHASE 3     │────▶│     PHASE 4     │
│  Scope & Plan   │     │ TDD & Execution │     │Systematic Debug │     │  Verify & Ship  │
└─────────────────┘     └─────────────────┘     └─────────────────┘     └─────────────────┘
```

### Phase 1: Phạm Vi & Kế Hoạch (Scope & Plan)
* **Skill bắt buộc:** `brainstorming` $\rightarrow$ `writing-plans`.
* **Quy trình:**
  1. Xác định rõ vấn đề, ranh giới In-scope và Out-of-scope.
  2. Xác định các ràng buộc kỹ thuật và đánh đổi kiến trúc.
  3. Lập Kế hoạch Triển khai (Implementation Plan) chi tiết từng bước kèm Acceptance Criteria đo lường được.
* **Tiêu chí thoát Phase (Exit Criteria):** Kế hoạch được trình bày rõ ràng và **ĐƯỢC PO DUYỆT**.

### Phase 2: Phát Triển Hướng Kiểm Thử (TDD & Execution)
* **Skill bắt buộc:** `test-driven-development` $\rightarrow$ `executing-plans`.
* **Vòng lặp TDD:**
  1. **Red:** Viết bài kiểm thử (test case) thất bại phản ánh đúng yêu cầu/lỗi cần sửa.
  2. **Green:** Viết lượng code tối thiểu vừa đủ để test chuyển sang trạng thái Pass.
  3. **Refactor:** Tối ưu, làm sạch code mà không làm thay đổi hành vi hoặc hỏng test.
* **Tiêu chí thoát Phase (Exit Criteria):** 100% test mới và test hồi quy đều xanh (Pass).

### Phase 3: Điều Tra Lỗi Có Hệ Thống (Systematic Debug)
* **Skill bắt buộc:** `systematic-debugging`.
* **Nguyên tắc:** **Tuyệt đối không đoán mò (No guessing).**
  1. Tái hiện lỗi ổn định (Reproduce).
  2. Đặt giả thuyết dựa trên chứng cứ log/code.
  3. Thiết kế phép thử loại trừ.
  4. Xác định nguyên nhân gốc rễ (Root Cause) đã được chứng minh.
  5. Vá lỗi với phạm vi nhỏ nhất có thể và bổ sung Regression Test.
* **Tiêu chí thoát Phase (Exit Criteria):** Nguyên nhân gốc rễ được làm sáng tỏ và chứng minh bằng bài test thực tế.

### Phase 4: Kiểm Chứng Toàn Diện & Chuyển Giao (Verify & Ship)
* **Skill bắt buộc:** `verification-before-completion` $\rightarrow$ `requesting-code-review`.
* **Quy trình kiểm chứng:**
  * Chạy toàn bộ test suite liên quan (`rtk npm test`).
  * Kiểm tra cú pháp, kiểu dữ liệu (`rtk tsc --noEmit` hoặc linter).
  * Lập báo cáo kết quả (Walkthrough / PR Summary) minh bạch với các bằng chứng test.
* **Tiêu chí thoát Phase (Exit Criteria):** Mọi tiêu chí nghiệm thu hoàn thành 100%, không còn cảnh báo hay lỗi tiềm ẩn.

---

## 🧠 5. NGUYÊN TẮC HÀNH VI KARPATHY (BEHAVIORAL GUIDELINES)

1. **Think Before Coding (Nghĩ kỹ trước khi viết mã):**
   * Không tự ý ngầm định — nêu rõ các giả định, đặt câu hỏi khi chưa chắc chắn.
   * Nếu có nhiều cách giải quyết, trình bày các phương án và điểm đánh đổi (trade-offs) để PO quyết định.
2. **Simplicity First (Tối giản là trên hết):**
   * Viết lượng mã tối thiểu để giải quyết triệt để vấn đề. Không suy đoán tính năng tương lai.
   * Không tạo các lớp trừu tượng (abstraction) cho đoạn code chỉ dùng một lần.
   * Không cấu hình hóa những thứ không được yêu cầu. Nếu 200 dòng có thể viết gọn thành 50 dòng rõ ràng, hãy tái cấu trúc ngay.
3. **Plan Then Execute (Kế hoạch rồi mới thực thi):**
   * Luôn hình dung toàn bộ con đường trước khi gõ dòng lệnh đầu tiên.
   * Chia nhỏ bài toán thành các bước độc lập, đo lường được.
4. **Test Everything (Có kiểm thử mới tính là hoạt động):**
   * Tính năng không có test là tính năng chưa hoàn thành.
   * Bug fix phải có test hồi quy chạy trượt trước khi áp dụng bản vá.
5. **Iterate in Small Steps (Tiến từng bước nhỏ vững chắc):**
   * Thực hiện các thay đổi nhỏ, gọn gàng, tự đứng độc lập được.
   * Tránh sửa đổi ồ ạt trên quá nhiều file cùng một lúc gây mất kiểm soát tác động.
6. **Own Your Mistakes (Thẳng thắn nhận lỗi và khắc phục):**
   * Khi phát hiện lỗi hoặc sai sót, thông báo ngay lập tức, không che giấu.
   * Tìm hiểu nguyên nhân gốc rễ và thiết lập chốt chặn để không tái phạm.

---

## 🛡️ 6. NGUYÊN TẮC AN NINH, BẢO MẬT HỆ THỐNG & DỮ LIỆU (DATA_SECURITY.MD)

Toàn bộ quy trình xử lý, lưu trữ, truyền tải dữ liệu bắt buộc tuân thủ chặt chẽ tài liệu nguồn sự thật [`docs/Rule_Project/Data_Security.md`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/docs/Rule_Project/Data_Security.md) nhằm đảm bảo tuân thủ pháp luật (Nghị định 13/2023/NĐ-CP, PCI-DSS, OWASP):

1. **Nguyên tắc Tối thiểu hóa dữ liệu (Data Minimization):**
   * Chỉ thu thập dữ liệu phục vụ trực tiếp cho tính năng tài chính cốt lõi khi có sự đồng ý của người dùng.
   * **Nghiêm cấm thu thập:** Mật khẩu/Tên đăng nhập Internet Banking, số thẻ tín dụng kèm CVV/CVC, GPS liên tục, danh bạ điện thoại, SMS cá nhân ngoài biến động số dư. Sinh trắc học (vân tay, khuôn mặt) chỉ xử lý cục bộ trên máy qua Biometrics API, tuyệt đối không đẩy lên server.
2. **User-scoped Isolation (Cách ly dữ liệu người dùng tuyệt đối):**
   * Mọi câu query đọc/ghi vào CSDL bắt buộc phải có điều kiện lọc theo `userId` hoặc `idaccount` từ JWT token đã xác thực; cấm truy vấn dữ liệu không kèm ràng buộc người sở hữu.
3. **Socket.io Security & Phân lập phòng:**
   * Bắt buộc xác thực token JWT ngay từ bước kết nối (handshake).
   * Phân lập phòng (Room) theo từng tài khoản (`account_${idaccount}`). Tuyệt đối không phát sự kiện chứa thông tin người dùng (`audit_activity`, notification) ra phòng ẩn danh toàn cục.
4. **Bảo mật phản hồi lỗi (Error Obfuscation):**
   * Che giấu toàn bộ thông tin nội bộ của CSDL, stack trace Prisma trước khi trả về client.
   * Ánh xạ thành mã lỗi chuẩn hóa (`CONSTRAINT_VIOLATION`, `FOREIGN_KEY_VIOLATION`, `UNIQUE_VIOLATION`).
5. **Môi trường Production Guard:**
   * Chặn hoàn toàn các tham số giả lập (`_mock*`, mock headers) khi chạy trên môi trường Production.
6. **Bảo vệ mật khẩu, Mã xác thực & Dữ liệu nhạy cảm:**
   * Mật khẩu băm bằng thuật toán an toàn (`bcrypt` / `Argon2id`).
   * Mã OTP và Refresh Token lưu trữ dưới dạng băm (SHA-256 hash), không lưu plaintext, không in ra file log/console.
   * Dữ liệu tài chính, số dư, lịch sử giao dịch mã hóa at-rest (AES-256) và in-transit (TLS 1.3 / HTTPS).
7. **Cấm để lộ PII qua Public Endpoints:**
   * Các endpoint công khai chỉ trả về cấu hình hệ thống hoặc dữ liệu thống kê tổng hợp đã ẩn danh hoàn toàn (không thể tái nhận dạng cá nhân).

---

## 📋 7. QUY ĐỊNH KẾT THÚC NHIỆM VỤ (RULE 8)

Khi kết thúc một nhiệm vụ kỹ thuật, AI **bắt buộc** phải hoàn thành 2 công việc cuối cùng trước khi báo cáo hoàn tất cho PO:

1. **Cập nhật Nguồn Sự Thật (Documentation Update):**
   * Đọc và cập nhật lại file [`Project.md`](../../Project.md) và các tài liệu liên quan để phản ánh đúng hiện trạng sau thay đổi.
2. **Cập nhật CodeGraph:**
   * Chạy lệnh cập nhật đồ thị mã nguồn dự án:  
     ```bash
     rtk npx codegraph build
     ```
> [!WARNING]  
> Nếu thiếu 2 bước này, nhiệm vụ kỹ thuật **CHƯA ĐƯỢC TÍNH LÀ HOÀN TẤT**.

---

## ✅ 8. BẢNG TỰ KIỂM TRA TRƯỚC KHI BÁO "DONE" (SELF-CHECKLIST)

Trước khi gửi câu trả lời hoàn thành tới PO, hãy tự kiểm tra 7 câu hỏi sau:

- [ ] **RTK?** Mọi lệnh CLI đã chạy có tiền tố `rtk` chưa?
- [ ] **CodeGraph?** Đã dùng `context`/`deps`/`brief`/`impact` để phân tích tác động chưa?
- [ ] **Project.md?** Đã đọc và nắm vững ngữ cảnh dự án chưa?
- [ ] **Data Security?** Đã tuân thủ nguyên tắc bảo mật dữ liệu & pháp luật trong `Data_Security.md` chưa?
- [ ] **Skill & Phase?** Đã tuân thủ quy trình 4-Phase và dùng đúng skill chưa?
- [ ] **Test?** Toàn bộ bài kiểm thử đã chạy và đạt 100% PASS chưa?
- [ ] **Tài liệu & CodeGraph?** Đã cập nhật `Project.md` và chạy `rtk npx codegraph build` chưa?

---
---

# ⚙️ PHẦN II: CÁC QUY TẮC KỸ THUẬT & NGHIỆP VỤ CỤ THỂ

Phần này đặc tả chi tiết toàn bộ các quy tắc ràng buộc, chốt chặn CSDL, thuật toán xử lý và quy chuẩn dữ liệu áp dụng cho từng thực thể và module trong hệ thống.

---

## 🏷️ 1. QUY TẮC VỀ DANH MỤC (CATEGORY RULES)

### 1.1. Mô hình Danh mục Mẫu & Nhân bản Độc lập (Template & Cloned Model)
* **Bản chất danh mục hệ thống:** Toàn bộ danh mục mặc định hệ thống (`Is_default = true`) đóng vai trò là **Bộ khung mẫu (Template)** chuẩn do Quản trị viên (Admin) thiết lập và duy trì.
* **Quy trình cấp phát danh mục cho người dùng mới:**
  * Khi người dùng đăng ký tài khoản thành công:
    * Tại **Client-app**, ứng dụng gọi API `GET /api/sync/default-categories` để truy vấn danh sách các danh mục mẫu hệ thống đang hoạt động.
    * Client-app tạo mới 1 bộ danh mục cá nhân tương tự với `create_by = idaccount`, `is_default = false`, và sinh UUID riêng biệt cho từng danh mục.
    * Bộ danh mục cá nhân này được lưu vào SQLite cục bộ (Client-app không lưu danh mục hệ thống vào bảng danh mục hoạt động của người dùng).
    * Sau đó, Client-app đẩy bộ danh mục cá nhân này lên Backend qua cơ chế Sync Push thông thường.
  * **Phân định trách nhiệm:** Backend **không** xử lý tự động nhân bản danh mục trong quy trình đăng ký tài khoản, việc khởi tạo bộ danh mục ban đầu do Client-app chủ động quản lý.
  * Một khi đã khởi tạo, bộ danh mục thuộc quyền sở hữu độc lập của người dùng và hoàn toàn tách biệt khỏi danh mục mẫu hệ thống.

### 1.2. Ràng buộc duy nhất tên danh mục (Category Uniqueness Rules)
* Tên danh mục được so sánh không phân biệt hoa thường (`LOWER`), chuẩn hóa NFC, cắt khoảng trắng đầu cuối (`TRIM`) và thu gọn khoảng trắng thừa giữa các từ (`\s+ -> ' '`). Ví dụ: `"Ăn  UốNg"` tương đương `"ăn uống"`.
* Ràng buộc duy nhất được chia thành **2 không gian tên (namespaces) độc lập**:
  * **Danh mục người dùng (`uq_category_owner_name`):**
    * **Cột ràng buộc:** `UNIQUE ("Create_by", lower(regexp_replace(btrim(normalize("NameCategory", NFC)), '\s+', ' ', 'g')))`
    * **Điều kiện lọc:** `WHERE "Is_default" = FALSE AND "Delete_at" IS NULL`
    * **Quy tắc:** Mỗi tài khoản không được phép tạo trùng tên danh mục cá nhân đang hoạt động.
  * **Danh mục mẫu hệ thống (`uq_category_default_name`):**
    * **Cột ràng buộc:** `UNIQUE (lower(regexp_replace(btrim(normalize("NameCategory", NFC)), '\s+', ' ', 'g')))`
    * **Điều kiện lọc:** `WHERE "Is_default" = TRUE AND "Delete_at" IS NULL`
    * **Quy tắc:** Toàn bộ danh mục mẫu hệ thống không được trùng tên nhau.
* **Xóa mềm không giữ chỗ (Soft-delete Re-creation):**
  * Khi một danh mục đã bị xóa mềm (`Delete_at IS NOT NULL`), người tạo (`Create_by` / `Idaccount`) hoàn toàn **được phép tạo mới một danh mục khác có cùng tên** (kể cả cùng hay khác loại thu/chi/nhóm).
  * Do các Partial Unique Index đều có điều kiện `WHERE "Delete_at" IS NULL`, các bản ghi đã xóa mềm không giữ chỗ và không gây xung đột khi tạo lại.
* **Cho phép trùng tên giữa người dùng và hệ thống:**
  * Người dùng **được phép** sở hữu danh mục cá nhân trùng tên với danh mục mẫu hệ thống (đây là điều kiện cốt lõi để mô hình nhân bản Template hoạt động).
  * Trigger kiểm tra trùng chéo cũ (`trg_category_name_cross_default`) đã chính thức được gỡ bỏ khỏi CSDL.
  * Admin cũng được phép tạo mới danh mục hệ thống trùng tên với danh mục người dùng đã tồn tại từ trước.

### 1.3. Bảo vệ & Ràng buộc quản trị Danh mục Hệ thống (System Category Protection)
* **Quyền tạo danh mục hệ thống:** Chỉ duy nhất tài khoản có vai trò Admin (`idrole = 1`) mới có quyền tạo danh mục hệ thống (`is_default = true`).
* **Cấm chuyển đổi (No Conversion):** Tuyệt đối không cho phép chuyển đổi danh mục người dùng (`is_default = false`) thành danh mục hệ thống (`is_default = true`), kể cả khi thực hiện bởi Admin. Nếu cần thêm danh mục hệ thống, Admin phải tạo mới một bản ghi danh mục hệ thống riêng biệt.
* **Bảo vệ chống xóa (Delete Protection):** Danh mục hệ thống **không thể bị xóa**.
  * Trên giao diện Admin-web: Nút Xóa danh mục bị vô hiệu hóa với danh mục hệ thống kèm chú thích rõ ràng.
  * Trên Backend API: `admin.service.deleteCategory` kiểm tra và từ chối ngay lập tức với mã lỗi HTTP 400 Bad Request nếu danh mục có `is_default === true`.

### 1.4. Bộ giá trị phân loại (`Classify` Enum)
* Giá trị của cột `classify` bắt buộc phải thuộc tập 3 giá trị chuẩn:
  * `'Thu'` (Khoản thu nhập)
  * `'Chi'` (Khoản chi tiêu)
  * `'Vay/no'` (Các khoản vay, nợ)
* Validator ở Sync Engine (`sync.validation.js`) chỉ chấp nhận đúng 3 giá trị này.

### 1.5. Phân quyền học từ khóa AI (Keyword Learning Permission)
* Khi gọi `POST /api/ai/classify/feedback` để huấn luyện từ khóa danh mục:
  * Người dùng chỉ được phép bổ sung từ khóa vào danh mục do chính họ sở hữu (`Create_by = idaccount` và `Is_default = false`).
  * Cấm tuyệt đối việc ghi đè từ khóa vào danh mục mặc định của hệ thống (`Is_default = true`) hoặc danh mục của người dùng khác $\rightarrow$ Hệ thống lập tức từ chối với mã **HTTP 403 Forbidden**.

### 1.6. Cấu trúc Nhóm danh mục (Category Hierarchy)
* Nhóm danh mục được gom trực tiếp thông qua quan hệ **tự tham chiếu** (Self-referencing) trong bảng `category`:
  * Cột `is_group = true`: Xác định bản ghi là Nhóm danh mục cha.
  * Cột `idgroup`: Chứa ID của danh mục/nhóm cha (`idcategory`). Nếu là danh mục gốc thì `idgroup = null`.
* **Không sử dụng bảng trung gian**: Hệ thống **không** có bảng `category_group` hay `category_group_membership` (đã loại bỏ hoàn toàn). Mọi quan hệ cha - con đều được biểu diễn trọn vẹn trong duy nhất bảng `category`.
* Thứ tự ưu tiên đồng bộ (`ENTITY_PRIORITY`):
  * `category`: 10 (đồng bộ toàn bộ danh mục và nhóm cha-con).

---

## 💰 2. QUY TẮC VỀ VÍ TIỀN (WALLET RULES)

### 2.1. Quy tắc Ví mặc định (`is_default`)
* Mỗi tài khoản (`idaccount`) chỉ có **duy nhất 1 ví mặc định** (`is_default = true`) tại một thời điểm.
* Khi người dùng chỉ định một ví mới làm ví mặc định, hệ thống tự động gỡ cờ mặc định (`is_default = false`) của tất cả các ví còn lại thuộc tài khoản đó.

> ⚠️ **Luật này chỉ được thi hành đầy đủ từ 2026-09-09.** Trước đó chỉ đường **thêm** ví gỡ cờ của ví cũ; đường **sửa** ghi thẳng, nên sửa một ví thứ hai thành mặc định là có hai hàng cùng cờ. SQLite không có unique index nào chặn, nên phía client luật chỉ do mã giữ. ⚠️ Câu cũ ở đây ghi "cả hai đầu" là **sai**: phép đo 2026-09-09 dùng `pg_constraint`, nơi partial unique index không hiện; đo `pg_indexes` 2026-09-10 thì PostgreSQL **có** `uq_wallet_default_active` — cùng `uq_wallet_account_name_active` (tên ví duy nhất trong tài khoản) và `uq_wallet_saving_active` (một ví Tiết kiệm mỗi tài khoản), cả ba từ migration 2026-09-01. Client thi hành hai luật sau ở `wallet/domain/rang_buoc_vi.dart` từ 2026-09-10; luật "một ví Tiết kiệm" không có trong mục 2 này và đã được xin bỏ (`docs/superpowers/backend/CAN-LAM/WALLET_SAVING_INDEX.md`). Nay chốt nằm ở `WalletLocalDataSourceImpl` — chỗ cả hai đường đều đi qua — dựa trên `WalletDao.clearDefaultExcept`. Vế đọc cũng phải chịu được trạng thái hai hàng, vì nó **đến được từ server** qua `upsertAll`.

### 2.2. Tính toán tổng tài sản (`include_in_total`)
* Cờ boolean xác định số dư của ví có được tính vào Tổng tài sản (Net Worth) hiển thị trên màn hình tổng quan hay không:
  * `true`: Cộng số dư vào tổng tài sản (ví tiền mặt, thẻ ngân hàng chi tiêu chính).
  * `false`: Tách biệt khỏi tổng tài sản (ví tiết kiệm mục tiêu riêng biệt, tài khoản quỹ nhóm...).

### 2.3. Loại ví (`Type` Enum)

> ⚠️ **Sửa 2026-09-09 — bốn loại ở bản trước KHÔNG khớp CSDL.** `'E-wallet'` và
> `'Credit'` chưa bao giờ hợp lệ: ràng buộc `chk_wallet_type` của PostgreSQL chỉ
> nhận `Cash | Bank | Saving | Banking`, nên ví tạo bằng hai loại ấy vỡ CHECK ở
> mỗi lần đẩy và kẹt hàng đợi đồng bộ vĩnh viễn, im lặng.

* Người dùng chọn được **ba** loại:
  * `'Cash'`: Tiền mặt trong ví/két.
  * `'Bank'`: Tài khoản ngân hàng.
  * `'Saving'`: Tài khoản/sổ tiết kiệm.
* Loại thứ tư, `'Banking'`, **do hệ thống tạo** qua luồng liên kết ngân hàng
  (SePay) và không nằm trong ô chọn: ràng buộc `chk_wallet_banking_link` đòi nó
  đi kèm `Id_bank_casso`.
* Định nghĩa duy nhất phía client: `lib/features/wallet/domain/wallet_type.dart`.
* Ví điện tử (MoMo, ZaloPay…) nay khai bằng `'Bank'`; thẻ tín dụng chưa có loại
  riêng — xem **G27** `docs/CLIENT_APP_KNOWN_GAPS.md`.

### 2.4. Xóa ví (Soft Delete)
* Xóa ví là xóa mềm qua trường `delete_at`.
* Các giao dịch thuộc ví bị xóa vẫn được bảo toàn lịch sử thu chi để không làm sai lệch báo cáo tài chính quá khứ.

### 2.5. Tên ví duy nhất trong một tài khoản
* Hai ví **đang hoạt động** (`Delete_at IS NULL`) của cùng một tài khoản không được trùng `Name` — thi hành bằng partial unique index `uq_wallet_account_name_active ("Idaccount", "Name")`. So khớp **chính xác** (phân biệt hoa thường).
* Ví đã xoá mềm không giữ chỗ tên.
* Vi phạm trả SQLSTATE `23505`; `/sync/push` trả `code: 'WALLET_NAME_DUPLICATE'` (không phải `CONSTRAINT_VIOLATION`).
* Quy tắc "một ví Tiết kiệm mỗi tài khoản" (`uq_wallet_saving_active`) **đã được loại bỏ** trong Migration 12 để cho phép người dùng mở nhiều sổ tiết kiệm linh hoạt.

---

## 💳 3. QUY TẮC VỀ GIAO DỊCH (TRANSACTION RULES)

### 3.1. Ràng buộc duy nhất giao dịch từ bên ngoài (Dedup Constraint)
* **Khóa duy nhất CSDL (`uq_transaction_external`):**
  * **Cột ràng buộc:** `UNIQUE (Idaccount, Provider, Bank_tran_id)`
  * **Ý nghĩa:** Đảm bảo mỗi mã giao dịch (`bank_tran_id`) từ một nguồn bên ngoài (`Provider`) chỉ xuất hiện 1 lần duy nhất trên mỗi tài khoản người dùng (`Idaccount`).
  * **Multi-tenant Safe:** Hai người dùng khác nhau có thể có mã giao dịch ngân hàng trùng nhau mà không gây xung đột hệ thống.

### 3.2. Loại giao dịch và số dư ví
Cột `Type` chỉ nhận **hai** giá trị (`chk_transaction_type`):
* **`Transaction`** — thu hoặc chi, phân biệt bằng **dấu của `Amount`**: dương là thu, âm là chi (`chk_transaction_nonzero_amount` cấm `0`).
* **`Transfer`** — chuyển giữa hai ví: bắt buộc có `Idwallet` (ví nguồn) và `Idwallet_transfer` (ví đích).
* Không có loại riêng cho vay/nợ trong CSDL.

Số dư ví **không** do `/sync/push` cộng trừ: client tính số dư và đẩy lên qua `wallet.balance` như một trường thường (`sync.repository.js:224, 242`).
Lưu ý: Nếu client gửi `Expense`, `Income`, `Debt`, `Loan`, Sync Engine sẽ chuẩn hóa về `Transaction` trước khi kiểm tra và ghi nhận vào CSDL.

### 3.3. Liên kết mục tiêu tiết kiệm (`Idgoal`)
* Cột `Idgoal` (UUID, nullable) lưu dấu vết khoản giao dịch được trích cho mục tiêu nào.
* **Khóa ngoại an toàn (`fk_transaction_goal`):** Cài đặt `ON DELETE SET NULL`. Khi người dùng xóa mục tiêu, toàn bộ giao dịch liên quan KHÔNG bị xóa mà chỉ đưa `Idgoal` về `NULL`, bảo vệ 100% số dư ví và báo cáo dòng tiền.

### 3.4. Nhà cung cấp giao dịch (`Provider`)
* `'Manual'`: Người dùng tự tạo trên ứng dụng — mặc định khi không gửi `provider` (`sync.repository.js:285`).
* `'BankSync'`: Webhook ngân hàng (SePay / Casso) — `workers/bank.worker.js:192`.
* `'OCR'`: Trích từ hoá đơn bằng AI OCR — `modules/ai/features/classify/classify.service.js` (đã thống nhất `'OCR'`, loại bỏ `'ORC'`).
* `'SMS'`, `'Casso'`, `'Bill'`: Lớp kiểm tra `sync.validation.js:125` nhận để tương thích mở rộng.
* Cột **không** có CHECK trong CSDL.

---

## 📊 4. QUY TẮC VỀ NGÂN SÁCH (BUDGET RULES)

### 4.1. Phạm vi áp dụng ngân sách
* **Ngân sách theo danh mục:** Có gán `idcategory` (ví dụ: Ngân sách cho danh mục *"Ăn uống"* tối đa 3,000,000 VND).
* **Ngân sách tổng thể:** Cột `idcategory = NULL` (áp dụng cho toàn bộ chi tiêu trong kỳ).

### 4.2. Ngân sách định kỳ vs Ngân sách ngày cụ thể
* **Ngân sách ngày cụ thể (`recurrence = false`):**
  * Áp dụng từ ngày `start` đến ngày `end`.
  * **BẮT BUỘC:** Giữ nguyên `time_recurrence = NULL`. Tuyệt đối không được gán mặc định thành `'Month'`.
* **Ngân sách định kỳ lặp lại (`recurrence = true`):**
  * Cột `time_recurrence` nhận giá trị chu kỳ: `'Week'`, `'Month'`, `'Year'`.
  * Hệ thống tự động tính mốc `nexttime_recurrence` khi hết kỳ hiện tại.

### 4.3. Ngưỡng cảnh báo chi tiêu (`Threshold Warning`)
* `threshold_warning_percent`: Ngưỡng phần trăm chi tiêu kích hoạt cảnh báo (ví dụ: 80%).
* Nếu người dùng không cài đặt ngưỡng cảnh báo, hệ thống giữ nguyên `NULL` hoặc `0`, không được tự ý ghi đè dữ liệu sai lệch khi đồng bộ.
* Khi `spent >= (total_amount * threshold_warning_percent / 100)`, hệ thống đánh dấu trạng thái cảnh báo vượt hạn mức (`over_spending`).

---

## 🎯 5. QUY TẮC VỀ MỤC TIÊU TIẾT KIỆM (GOAL RULES)

### 5.1. Số tiền mục tiêu & Hoàn thành
* `target_amount`: Số tiền mục tiêu cần tích lũy.
* `current_amount`: Số tiền đã tích lũy lũy kế (được cập nhật qua các giao dịch tích lũy hoặc trích tiền tự động).
* Trạng thái hoàn thành: Đánh dấu `status_complete = 'True'` khi `current_amount >= target_amount`.

### 5.2. Bộ ba trích tiền tự động định kỳ (Auto-Deposit Triad)
Để kích hoạt tính năng trích tiền tự động cho mục tiêu, CSDL bắt buộc phải có đầy đủ bộ 3 trường:
1. `auto_deposit_amount`: Số tiền trích cho mỗi kỳ (DECIMAL).
2. `auto_deposit_wallet_id`: ID ví nguồn sẽ bị trừ tiền định kỳ.
3. `auto_deposit_last_run`: Mốc thời gian lần trích tiền thành công gần nhất.
* **Chống chạy trùng giữa nhiều thiết bị:** Khi một thiết bị chuẩn bị thực hiện trích tiền, nó phải kiểm tra `auto_deposit_last_run` đã được đồng bộ lên máy chủ để đảm bảo chưa có thiết bị nào khác thực hiện trích tiền trong kỳ đó.

### 5.3. Thứ tự ưu tiên thưa (`Priority`)
* Cột `Priority` (INT, nullable) lưu giá trị số nguyên xác định độ ưu tiên của mục tiêu.
* Đánh số thưa **cách nhau 100** (100, 200, 300…): chèn giữa hai mục tiêu chỉ ghi một hàng (150). **NULL = chưa sắp, xếp cuối.** Trùng số được phép — không đặt UNIQUE. Server phải giữ nguyên NULL khi đồng bộ (`CAN-LAM/GOAL_PRIORITY_NULL_TO_ZERO.md`).

---

## 📑 6. QUY TẮC VỀ HÓA ĐƠN ĐỊNH KỲ (BILL RULES)

### 6.1. Ràng buộc bắt buộc
* Hóa đơn bắt buộc phải liên kết với một Ví thanh toán dự kiến (`idwallet`) và một Danh mục chi phí (`idcategory`).

### 6.2. Trạng thái thanh toán (`pay_status` Enum)
* `'Pending'`: Chờ đến hạn thanh toán.
* `'Payed'`: Đã thanh toán (đã sinh ra khoản chi tương ứng).
* `'Overdue'`: Đã quá hạn thanh toán (`current_date > due_date` và chưa thanh toán).
* `'Skipped'`: Người dùng chủ động bỏ qua kỳ hóa đơn này (không thanh toán và không tính nợ). Đã được hỗ trợ tại CSDL và Sync Engine từ Migration 12.

### 6.3. Chuỗi kỳ hóa đơn & Lịch sử
* `start_date` và `due_date`: Mốc bắt đầu kỳ và hạn chót thanh toán của kỳ hóa đơn đó.
* `previous_bill_id`: Cột liên kết ID tới hóa đơn của kỳ liền trước (đã bổ sung từ Migration 12). Dùng để:
  * Truy vết lịch sử biến động chi phí qua các kỳ (ví dụ: tiền điện 6 tháng qua).
  * Hỗ trợ hoàn tác (undo) thanh toán hóa đơn về trạng thái chưa trả.
* `period_end`: Mốc kết thúc kỳ tính cước hóa đơn.
* `auto_pay`: Cờ tự động thanh toán hóa đơn khi đến hạn.
* `anchor_day`: Ngày neo chu kỳ thanh toán hàng tháng (1..31).

### 6.4. Chốt chặn thanh toán hai lần (Double-Payment Guard)
* `/sync/push` từ chối giao dịch thứ hai có cùng `Idbill` chưa xóa mềm với `code: 'BILL_ALREADY_PAID'`. Hoàn tác về `Pending` (thay đổi `Pay_status` của hóa đơn) không bị chặn. Mã này không ánh xạ thành `CONSTRAINT_VIOLATION` — client hắt nó vĩnh viễn.

---

## 🤖 7. QUY TẮC VỀ AI DEDUPLICATION (CHỐNG TRÙNG LẶP 3 CẤP ĐỘ)

Bộ máy chống trùng lặp giao dịch (Deduplication Engine) vận hành theo 3 cấp độ chặt chẽ:

### Cấp độ 1: Khóa ngoài định danh tuyệt đối (Exact External Match)
* So khớp chính xác bộ ba: `(idaccount, provider, bank_tran_id)` qua `uq_transaction_external`.
* Tìm kiếm với chế độ không phân biệt chữ hoa/thường (`mode: 'insensitive'`) và loại bỏ hoàn toàn khoảng trắng thừa (`trim()`).

### Cấp độ 2: Khớp thông minh theo cửa sổ thời gian (Smart Window Matching)
* Áp dụng khi người dùng chụp quét hóa đơn (OCR) hoặc nhận tin nhắn SMS sau khi ngân hàng đã biến động số dư.
* Tiêu chí khớp:
  * Cùng số tiền (`amount`).
  * Cùng ví liên kết (`idwallet`).
  * Nằm trong cửa sổ thời gian cho phép: $\pm 30$ phút đối với giao dịch chuyển khoản trực tuyến, hoặc trong cùng ngày đối với hóa đơn mua sắm.

### Cấp độ 3: Đối soát mờ nội dung chuyển khoản (Fuzzy Match for Transfers)
* Chỉ áp dụng đối soát với các giao dịch có nguồn gốc từ `'BankSync'` và `'SMS'`.
* So khớp số tài khoản đối ứng (`counterpartAccount`) và từ khóa ghi chú (`note`).
* Luôn sắp xếp theo thứ tự thời gian giao dịch mới nhất (`orderBy: { date_transaction: 'desc' }`).

> [!NOTE]
> **Nguyên tắc an toàn quét lại (Re-scan Safety):**  
> Nếu lần chụp quét hóa đơn trước đó bị gián đoạn mạng và chưa từng được ghi thành công vào CSDL (cả Cloud lẫn SQLite local), khi người dùng chụp quét lại bức ảnh đó, AI Deduplication Engine kiểm tra trong CSDL thấy chưa tồn tại $\rightarrow$ **tuyệt đối không được chặn nhầm**.

---

## 🏦 8. QUY TẮC TÍCH HỢP NGÂN HÀNG (BANK INTEGRATION - SEPAY)

### 8.1. Mô hình SePay Tài Khoản Cá Nhân
* Hệ thống sử dụng SePay gói **Cá nhân** (Personal Account), không dùng mô hình Bank Hub Doanh nghiệp.
* **Xác thực Webhook:** Kiểm tra tính hợp lệ của Webhook qua API Key được cấu hình trong cấu hình hệ thống (`SEPAY_API_KEY`), truyền qua HTTP Header `Authorization: Apikey <token>` hoặc Query Parameter.

### 8.2. Xử lý biến động số dư tự động
* Khi nhận Webhook từ SePay:
  * Tạo một giao dịch mới với `Provider = 'BankSync'`.
  * Gán `bank_tran_id` từ mã giao dịch ngân hàng do SePay gửi về.
  * Tự động cộng số dư (nếu tiền vào `transferType = 'in'`) hoặc trừ số dư (nếu tiền ra `transferType = 'out'`).
* **Bảo vệ quyền riêng tư & Tuân thủ pháp lý:**
  * Hệ thống tuyệt đối KHÔNG thu thập, không lưu trữ thông tin đăng nhập Internet Banking, mã PIN hay số CCCD của người dùng trên máy chủ Backend.

---

## 🔄 9. QUY TẮC ĐỒNG BỘ ENGINE (SYNC PROTOCOL STANDARDS)

### 9.1. Giao thức Sync 2 Chiều
* **Push (`POST /api/sync/push`):** Client gửi mảng thay đổi cục bộ lên server.
* **Pull (`GET /api/sync/pull` hoặc `POST /api/sync/pull`):** Client lấy các bản ghi có `update_at > last_sync_time`.

### 9.2. Quy tắc giải quyết xung đột (Conflict Resolution)
* Áp dụng nguyên tắc **"Last Write Wins" (LWW)** dựa trên mốc thời gian cập nhật `update_at`.
* Nếu có xung đột giữa bản ghi cục bộ và server, bản ghi có mốc `update_at` mới hơn sẽ được ưu tiên làm chuẩn.

### 9.3. Xóa mềm toàn hệ thống (Soft Delete Standard)
* Toàn bộ thao tác xóa thực thể trong hệ thống đồng bộ bắt buộc phải là xóa mềm:
  * Gán `delete_at = now()` (hoặc `deleted_at = now()`).
  * Khi client thực hiện Pull, server trả về cả các bản ghi có `delete_at IS NOT NULL` để client tương ứng cập nhật xóa bản ghi trong CSDL SQLite cục bộ.

### 9.4. Giao dịch toàn vẹn trong Batch Push
* Toàn bộ các thực thể trong một gói Push phải được bọc trong một Database Transaction (`prisma.$transaction`).
* Nếu xảy ra lỗi vi phạm ràng buộc không thể phục hồi, toàn bộ batch sẽ bị rollback để ngăn ngừa tình trạng dữ liệu mồ côi (orphaned records).

---

## 🔐 10. QUY TẮC XÁC THỰC & PHÂN QUYỀN (AUTH & SECURITY)

### 10.1. Cơ chế Token Kép (Access & Refresh Token)
* **Access Token:**
  * Ký bằng JWT Secret, thời gian sống ngắn (15 - 60 phút).
  * Chứa thông tin nhận diện cơ bản: `{ idaccount, idrole, email }`.
* **Refresh Token:**
  * Ký bằng Refresh Secret riêng biệt, thời gian sống dài (7 - 30 ngày).
  * Mã băm (`token_hash`) được lưu trong bảng CSDL `refreshtoken`.
* **Thu hồi phiên (Session Revocation):**
  * Khi người dùng đăng xuất, đổi mật khẩu hoặc bị khóa tài khoản, toàn bộ Refresh Token của tài khoản đó trong bảng `refreshtoken` sẽ bị xóa ngay lập tức.

### 10.2. Quy tắc Mã xác thực OTP (Bảng `otp_code`)
* Bắt buộc lưu trữ OTP dưới dạng mã băm SHA-256 (`code_hash`). Không lưu OTP dạng chuỗi rõ (plaintext).
* Trường `purpose` phải ghi rõ mục đích sử dụng: `'reset_password'` hoặc `'change_email'`.
* Thời gian hết hạn tối đa: 5 đến 10 phút.
* Hủy mã ngay lập tức sau lần xác thực thành công đầu tiên (Single-Use).

### 10.3. Phân quyền vai trò (Role-Based Access Control)
* `idrole = 1` (**Admin**): Quản trị người dùng, danh mục mặc định toàn hệ thống, xem audit logs, cấu hình hệ thống.
* `idrole = 2` (**User**): Chỉ có quyền truy cập, đồng bộ và thao tác trên dữ liệu thuộc quyền sở hữu của chính tài khoản đó (`idaccount`).

---

## 👤 11. QUY TẮC QUẢN LÝ TÀI KHOẢN, NGƯỜI DÙNG & XÓA MỀM (ACCOUNT & USER MANAGEMENT RULES)

### 11.1. Điều kiện hiển thị nút Xóa trên Giao diện Quản trị (Admin-web)
* Trên bảng quản lý người dùng (`UserListPage.jsx`):
  * Người dùng đang ở trạng thái **Hoạt động (`active`)**: Cột Hành động chỉ hiển thị nút **"Vô hiệu hóa"** và icon xem chi tiết.
  * Người dùng đang ở trạng thái **Vô hiệu hóa (`inactive` / "Ngừng hoạt động")**: Cột Hành động hiển thị thêm nút **"Xóa"** (màu đỏ) cạnh nút **"Kích hoạt"**.
  * Khi bấm "Xóa": Mở modal cảnh báo rõ ràng các tác động (xóa mềm tài khoản, ngừng hoạt động toàn bộ ví, ngắt kết nối ngân hàng, thu hồi phiên làm việc) trước khi thực hiện.

### 11.2. Quy trình Xóa mềm 5 bước trong Transaction (Backend Soft-Delete Standard)
Khi xóa một người dùng (`DELETE /api/admin/deleteuser/:id` hoặc `DELETE /api/admin/users/:id`), toàn bộ thao tác được bọc trong một Database Transaction (`prisma.$transaction`) tuân thủ nghiêm ngặt 5 bước:
1. **Xóa mềm bảng `account`**: Cập nhật `status = 'Inactive'`, `delete_at = now()`, `update_at = now()`.
2. **Xóa mềm bảng `user`**: Cập nhật `delete_at = now()`, `update_at = now()`.
3. **Ngừng hoạt động toàn bộ Ví liên quan**: Toàn bộ ví của tài khoản chuyển sang `status = 'Inactive'`, `update_at = now()`. Tuyệt đối không xóa bản ghi ví để bảo toàn tính toàn vẹn của lịch sử giao dịch.
4. **Ngắt kết nối tài khoản Ngân hàng**: Dữ liệu tài khoản ngân hàng liên kết **không bị xóa**, chỉ cập nhật trạng thái liên kết sang `connect_status = 'Disconnected'`, `update_at = now()`. Nếu sau này người dùng liên kết lại thì có thể kích hoạt kết nối lại bình thường.
5. **Thu hồi toàn bộ Token ngay lập tức**:
   * Cập nhật toàn bộ Refresh Token trong bảng `refreshtoken`: `status = true` (đã thu hồi), `update_at = now()`.
   * Xóa bộ nhớ cache xác thực tức thì qua `invalidateAccountCache(idaccount)`.

### 11.3. Cơ chế Cưỡng chế Đăng xuất & Hàng đợi 24/24 (Force Logout & Offline Parity)
* **Kênh Real-time (Khi người dùng đang Online)**:
  * Backend phát ngay sự kiện `account.force_logout` qua Socket.IO tới phòng cá nhân `account_${idaccount}` với payload: `{ idaccount, reason: 'ACCOUNT_DELETED', message: 'Tài khoản của bạn đã bị ngừng hoạt động hoặc xóa bởi quản trị viên.' }`.
  * Máy chủ ngắt kết nối socket của client ngay lập tức (`io.in(room).disconnectSockets(true)`).
* **Hàng đợi 24/24 (Khi người dùng mất mạng / Offline)**:
  * Trạng thái xóa mềm được lưu cố định và vĩnh viễn (24/24) tại CSDL (`account.delete_at IS NOT NULL`).
  * Nhận diện khi Client-app có kết nối internet trở lại (thông qua `ConnectionMonitor` / `Connectivity` trên Client-app kích hoạt kết nối lại):
    * **Qua Socket.io Handshake**: Middleware bắt tay từ chối kết nối kèm mã lỗi `ACCOUNT_DELETED` hoặc `ACCOUNT_INACTIVE` (kèm `reason_inactive`).
    * **Qua HTTP API (`authenticate` middleware)**: Mọi yêu cầu HTTP (như sync, lấy thông tin tài khoản) đều bị từ chối với mã HTTP 401 Unauthorized kèm body chuẩn hóa:
      ```json
      {
        "success": false,
        "message": "Account no longer exists or has been deleted",
        "code": "ACCOUNT_DELETED",
        "idaccount": 10,
        "reason_inactive": null,
        "errors": null,
        "timestamp": "2026-09-10T15:58:09.000Z"
      }
      ```
  * **Trách nhiệm của Client-app**:
    * Khi nhận được sự kiện Socket hoặc mã lỗi `ACCOUNT_DELETED`:
      1. So khớp chính xác `targetIdAccount == currentUserIdAccount` (tránh đăng xuất nhầm nhóm người dùng khác).
      2. Xóa sạch toàn bộ token trong `FlutterSecureStorage`.
      3. Cưỡng chế điều hướng về màn hình Đăng nhập (`LoginScreen`) qua `AuthBloc`.
      4. Hiển thị thông báo lý do tài khoản đã bị ngừng hoạt động hoặc xóa.
      5. Ngăn chặn người dùng đăng nhập lại (API Login sẽ từ chối tài khoản có `delete_at !== null` với mã HTTP 403).

### 11.4. Quy tắc Ràng buộc Duy nhất khi Đăng ký mới (Registration Uniqueness Rules)
* **Cho phép dùng lại Email & Số điện thoại của tài khoản đã xóa mềm**:
  * Các chỉ mục duy nhất trên Email (`account_Email_key` và `user_Email_key`) được chuyển đổi thành **Partial Unique Index** lọc:  
    `WHERE ("Delete_at" IS NULL)`
  * Khi tài khoản cũ đã bị xóa mềm (`Delete_at IS NOT NULL`), email và số điện thoại đó hoàn toàn được phép tái sử dụng để tạo một tài khoản mới.
* **Quy tắc cặp `(Username + Password)`**:
  * Cấm trùng đồng thời cả **Tên đăng nhập (Username)** và **Mật khẩu (Password)** với bất kỳ tài khoản nào trong hệ thống (kể cả tài khoản cũ).
  * **Được phép trùng 1 trong 2**:
    * Trùng `Username` nhưng khác `Password` $\rightarrow$ **Hợp lệ, cho phép tạo!**
    * Trùng `Password` nhưng khác `Username` $\rightarrow$ **Hợp lệ, cho phép tạo!**
  * **Cơ chế hiện thực**: Vì mật khẩu trong CSDL được băm bằng thuật toán `bcrypt` có salt ngẫu nhiên, chỉ mục tĩnh của CSDL không thể so sánh. Ràng buộc `(Username + Password)` được kiểm soát tại tầng ứng dụng (`auth.service.validateUsernamePasswordPair`) bằng `bcrypt.compare()` đối chiếu với tất cả các tài khoản có username trùng khớp.
* **Đăng nhập đa tài khoản cùng Username**:
  * Khi đăng nhập bằng `(username, password)`: Backend tìm kiếm danh sách các tài khoản có cùng username, dùng `bcrypt.compare` để tìm tài khoản khớp đúng mật khẩu của người dùng.
  * Nếu tài khoản khớp đó đang bị xóa mềm hoặc vô hiệu hóa $\rightarrow$ Từ chối đăng nhập với mã HTTP 403.
  * Nếu tài khoản khớp đang hoạt động (`Active`) hoặc đang trong thời hạn chờ xóa (`PendingDelete` còn hạn) $\rightarrow$ Đăng nhập thành công và cấp phát token.

### 11.5. Quy tắc Vô hiệu hóa có Lý do & Chuẩn hóa 4 Trạng Thái Tài Khoản
* **Chuẩn hóa 4 trạng thái tài khoản & Màu sắc đại diện:**
  * 🟢 **`Active`** (Đang hoạt động): Xanh lá (`#22c55e`). Cho phép truy cập đầy đủ tính năng. Nút thao tác trên Admin-web: "Vô hiệu hóa".
  * 🔘 **`Inactive`** (Vô hiệu hóa): Xám xanh (`#64748b`). Tài khoản bị khóa tạm thời bởi Admin. Bị chặn đăng nhập và từ chối mọi request với mã HTTP 401/403 kèm lý do. Nút thao tác trên Admin-web: "Kích hoạt" và "Xóa".
  * 🟡 **`PendingDelete`** (Chờ xóa): Vàng (`#eab308`). Tài khoản do người dùng client yêu cầu xóa, đang trong thời gian ân hạn 30 ngày. Trên Admin-web: **Hoàn toàn không thể thao tác**, chỉ hiển thị nhãn "Chỉ xem" và nút xem chi tiết tương tự trạng thái Deleted.
  * 🔴 **`Deleted`** (Đã xóa mềm): Đỏ (`#ef4444`). Tài khoản đã xóa mềm, ví ngừng hoạt động, ngân hàng ngắt kết nối. Trên Admin-web: Không có nút thao tác, chỉ xem chi tiết.
* **Quy tắc Vô hiệu hóa tài khoản (`Reason_Inactive`):**
  * Bảng `account` có cột `"Reason_Inactive" TEXT NULL`.
  * Khi Admin chuyển tài khoản sang `Inactive`: Bắt buộc cung cấp lý do vô hiệu hóa (HTTP 400 nếu rỗng).
  * Backend lưu `Reason_Inactive`, xóa cache xác thực và phát sự kiện Socket `account.force_logout` với `code = 'ACCOUNT_INACTIVE'` kèm lý do.
  * Khi kích hoạt lại `Active`: Hệ thống tự động xóa sạch `Reason_Inactive = null`.

### 11.6. Quy tắc Cơ Chế Chờ Xóa Tài Khoản (PendingDelete) & Countdown 30 Ngày
* **Cột đếm ngược `"Countdown"` (INT, NULL DEFAULT NULL) trong bảng `account`:**
  * Khi tài khoản chuyển từ trạng thái khác sang `PendingDelete`: **Bắt buộc** thiết lập `Countdown = 30` và `Delete_at = now() + 30 days`.
* **Cơ chế Lập lịch cập nhật vào 00:00:00 Múi giờ Việt Nam (UTC+7 / Asia/Ho_Chi_Minh):**
  * Backend chạy `scheduler.service.js` tự động lúc 00:00:00 UTC+7 mỗi ngày.
  * Quét toàn bộ tài khoản `PendingDelete` có `Countdown > 0`.
  * Mỗi ngày giảm `Countdown = Countdown - 1`.
* **Quyền sử dụng & Hủy xóa trong 30 ngày:**
  * Trong suốt 30 ngày đếm ngược (`Countdown > 0`), người dùng **vẫn có thể lựa chọn tiếp tục sử dụng tài khoản**.
  * Middleware Auth cho phép tài khoản `PendingDelete` còn hạn truy cập bình thường (`valid = true`).
  * Khi đăng nhập (`POST /api/auth/login`), server trả về `status: 'PendingDelete'` kèm `countdown` số ngày còn lại để Client-app hiển thị banner cảnh báo.
  * **Kích hoạt lại / Hủy xóa**: Nếu người dùng đổi ý và chọn "Kích hoạt lại tài khoản" tại Client-app:
    * Client-app gọi API `POST /api/auth/cancel-delete`.
    * Backend chuyển `status = 'Active'`, xóa `Countdown = null`, xóa `Delete_at = null`.
* **Kích hoạt xóa mềm khi Countdown về 0:**
  * Khi `Countdown` chạm `0` (vào lúc 0h00 hoặc khi Client-app phát hiện countdown về 0 và đồng bộ về Backend):
    * Hệ thống tự động chuyển tài khoản sang trạng thái `Deleted`, `Countdown = 0`, `Delete_at = now()`.
    * Xóa mềm bảng `user` (`Delete_at = now()`).
    * Toàn bộ ví liên quan ngừng hoạt động (`status = 'Inactive'`).
    * Toàn bộ liên kết ngân hàng bị ngắt kết nối (`connect_status = 'Disconnected'`).
    * Toàn bộ token bị thu hồi ngay lập tức (`refreshtoken.status = true`).
    * Phát sự kiện Socket `account.force_logout` với mã `ACCOUNT_DELETED` để cưỡng chế client out về màn hình đăng nhập.
* **Bảo vệ trên Admin-web:**
  * Đối với tài khoản `PendingDelete`, Admin-web hoàn toàn không thể thao tác (không có nút Kích hoạt, Vô hiệu hóa hay Xóa).
  * API Backend `PATCH /api/admin/updatestatus/:id` và `DELETE /api/admin/deleteuser/:id` sẽ từ chối với mã lỗi HTTP 400 nếu Admin cố ý can thiệp vào tài khoản đang trong quá trình `PendingDelete`.

---

## 🔒 12. QUY TẮC BẢO MẬT DỮ LIỆU, PHÂN LOẠI DỮ LIỆU NHẠY CẢM & TUÂN THỦ PHÁP LUẬT (DATA_SECURITY.MD)

Tất cả các thành phần hệ thống (`src/Backend`, `src/Admin-web`, `src/Client-app`) khi tiếp nhận, lưu trữ, xử lý, truyền tải hoặc hiển thị dữ liệu **BẮT BUỘC TUÂN THỦ 100% NGUYÊN TẮC** trong [`docs/Rule_Project/Data_Security.md`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/docs/Rule_Project/Data_Security.md) và cấu trúc lược đồ bảo mật dữ liệu tại [`docs/Rule_Project/New_Database.md`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/docs/Rule_Project/New_Database.md) nhằm đảm bảo tuân thủ đúng pháp luật (Nghị định 13/2023/NĐ-CP về bảo vệ dữ liệu cá nhân, Nghị định 53/2022/NĐ-CP về an ninh mạng, Luật Kế toán 2015, chuẩn PCI-DSS, khuyến nghị OWASP).

### 12.1. Phân loại 23 nhóm dữ liệu & Cấp độ bảo vệ bắt buộc
* **Mức độ Rất cao (Critical / Highly Sensitive):**
  * *Thông tin xác thực & bí mật:* Mật khẩu (băm an toàn bằng `bcrypt` / `Argon2id`), mã PIN, mã OTP 6 số (hash SHA-256 `code_hash`, hết hạn 5-10 phút, không lưu lâu dài, cấm in ra console/file log), token đăng nhập (`token_hash` lưu DB, xoay vòng token, thu hồi khi logout/đổi pass).
  * *Thông tin định danh mức cao:* Số CMND/CCCD, hộ chiếu, mã số thuế $\rightarrow$ Mã hóa at-rest, ghi nhận audit log mọi truy cập.
  * *Dữ liệu tài chính ngân hàng:* Số tài khoản, số thẻ (token hóa, tuân thủ PCI-DSS, tuyệt đối không lưu mã CVV/CVC), số dư ví/tài khoản, hạn mức, khoản nợ, lịch sử giao dịch $\rightarrow$ Mã hóa at-rest (AES-256) & in-transit (TLS 1.3 / HTTPS), phân quyền nghiêm ngặt theo `userId`/`idaccount`, không log chi tiết số dư/nội dung giao dịch vào log file.
  * *Dữ liệu sinh trắc học:* Vân tay, nhận diện khuôn mặt $\rightarrow$ Ưu tiên xử lý cục bộ 100% trên thiết bị người dùng qua Local Authentication / Biometrics API; **tuyệt đối không truyền tải hoặc lưu trữ trên server backend**.
* **Mức độ Cao (High):**
  * Họ tên, ngày sinh, địa chỉ, số điện thoại, email $\rightarrow$ Che một phần (masking) khi hiển thị trên giao diện công cộng, mã hóa khi lưu trữ, yêu cầu sự đồng ý rõ ràng khi xử lý.
  * Hóa đơn, biên lai, danh mục chi tiêu, mục tiêu tiết kiệm, ngân sách $\rightarrow$ Lưu trữ an toàn, gắn quyền sở hữu cá nhân.
* **Mức độ Trung bình (Medium):**
  * Dữ liệu thiết bị & phiên (IP, device name, user-agent) $\rightarrow$ Chỉ thu thập khi cần cho bảo vệ tài khoản và chống gian lận, có thời hạn lưu trữ.
  * Audit log $\rightarrow$ Dùng cho kiểm toán, bảo đảm tính toàn vẹn bất biến (Append-only), không tiết lộ cho người dùng khác.

### 12.2. Nguyên tắc vàng — Tối thiểu hóa dữ liệu (Data Minimization)
* Chỉ thu thập dữ liệu thực sự cần thiết cho tính năng tài chính cốt lõi khi có sự đồng ý của người dùng. Nếu không có dữ liệu đó mà hệ thống vẫn chạy bình thường $\rightarrow$ **tuyệt đối không thu thập**.
* **Danh mục TUYỆT ĐỐI KHÔNG thu thập / không lưu trữ:**
  1. Tên đăng nhập (username) và mật khẩu (password) Internet Banking của người dùng (Module Bank dùng mô hình SePay Cá Nhân an toàn, người dùng chỉ khai báo STK và tên ngân hàng, không lưu credentials).
  2. Số thẻ tín dụng đầy đủ kèm mã bảo mật CVV/CVC.
  3. Dữ liệu vị trí GPS liên tục.
  4. Danh bạ điện thoại, tin nhắn SMS cá nhân ngoài các tin nhắn biến động số dư ngân hàng được người dùng cấp quyền đọc cục bộ.
  5. Dữ liệu sinh trắc học đưa lên máy chủ.

### 12.3. Ranh giới dữ liệu công khai vs dữ liệu cá nhân
* **Dữ liệu công khai hợp lệ:** Cấu hình hệ thống mặc định (tiền tệ VND, ngôn ngữ), danh mục chi tiêu/thu nhập mẫu hệ thống (`is_default = true`), tỷ giá/lãi suất tham khảo công khai, dữ liệu thống kê tổng hợp đã ẩn danh hoàn toàn (khi không thể tái nhận dạng cá nhân).
* **Ranh giới bảo mật:** Bất kỳ dữ liệu nào khi kết hợp có thể nhận dạng một cá nhân cụ thể (kể cả số tài khoản, email, số điện thoại) đều **KHÔNG ĐƯỢC COI LÀ CÔNG KHAI**. Tuyệt đối không để lộ qua các endpoint công khai (Public Endpoints).

### 12.4. Sáu chốt chặn kỹ thuật bắt buộc khi lập trình & xử lý dữ liệu
1. **User-scoped Isolation:** Mọi query đọc/ghi vào CSDL bắt buộc có điều kiện lọc theo `idaccount` / `userId` từ JWT token đã xác thực; cấm truy vấn dữ liệu không kèm ràng buộc người sở hữu.
2. **Không ghi log dữ liệu nhạy cảm (Zero Sensitive Logging):** Cấm tuyệt đối lệnh `console.log`, `logger.info`, `logger.error` in ra mật khẩu, OTP plaintext, token plaintext, CVV hoặc nội dung giao dịch chi tiết. Winston Logger tích hợp format tự động che giấu các trường nhạy cảm (`balance`, `password`, `token`, `otp`, `code_hash`, `cvv`, `refreshtoken`).
3. **Mã hóa đa tầng:** Mã hóa in-transit (TLS 1.3 / HTTPS) cho toàn bộ kết nối và mã hóa at-rest (AES-256-GCM) cho dữ liệu nhạy cảm.
4. **Xác thực & Thu hồi phiên:** Token rotation, reuse detection. Thu hồi toàn bộ token khi đổi mật khẩu, đặt lại mật khẩu, đăng xuất, và khi tài khoản bị xoá hẳn (hết 30 ngày chờ xoá). Gửi yêu cầu xoá **không** thu hồi token — người dùng dùng tiếp trong 30 ngày (mục 11.6).
5. **Rate Limiting & Chống Brute-force:** Áp dụng rate limiter nghiêm ngặt trên các route nhạy cảm (login, otp, register, forgot-password).
6. **Socket.io Privacy:** Mọi sự kiện thời gian thực chỉ được gửi vào room riêng `account_${idaccount}`, cấm broadcast toàn cục các sự kiện chứa PII hoặc dữ liệu tài chính.

### 12.5. Quy định Thời hạn lưu trữ dữ liệu (Data Retention Policy theo Luật)
Tuân thủ **Nghị định 13/2023/NĐ-CP**, **Nghị định 53/2022/NĐ-CP**, **Luật Kế toán 2015 (Điều 41)** và **PCI-DSS v4.0**, toàn bộ dữ liệu trong hệ thống được phân định thời hạn lưu trữ và chu trình xử lý nghiêm ngặt:

| Nhóm dữ liệu | Bảng CSDL | Thời hạn quy định | Cơ chế xử lý & Chốt chặn kỹ thuật | Căn cứ pháp lý |
|---|---|---|---|---|
| **Mã OTP tạm thời** | `otp_code` | Tối đa **24 giờ** | • Hiệu lực mã 10 phút, hash SHA-256.<br>• **Scheduler Auto-Purge**: Chạy tự động mỗi đêm lúc 00:00 UTC+7 xóa vật lý các bản ghi `created_at < now - 24h`. | OWASP & NĐ 13/2023 |
| **Token phiên đăng nhập** | `refreshtoken` | Tối đa **30 ngày** sau hết hạn/thu hồi | • Hash SHA-256.<br>• **Scheduler Auto-Purge**: Chạy tự động lúc 00:00 UTC+7 xóa vật lý các bản ghi có `(Expired < now OR Status = true) AND Update_at < now - 30d`. | OWASP Session Management & NĐ 53/2022 |
| **Nhật ký kiểm toán** | `audit_log` | Tối thiểu **12 tháng** (365 ngày) | • Bất biến **Append-only**.<br>• **Trigger `trg_protect_auditlog`**: Khóa chặn tuyệt đối lệnh `UPDATE` và chặn lệnh `DELETE` nếu log chưa đủ 12 tháng. | Nghị định 53/2022/NĐ-CP (Điều 26) |
| **Giao dịch tài chính cốt lõi** | `transaction` | Tối thiểu **5 năm** | • Bắt buộc dùng Soft Delete qua `Deleted_at`.<br>• **Trigger `trg_protect_transaction`**: Khóa chặn tuyệt đối lệnh `DELETE` vật lý đối với mọi giao dịch phát sinh dưới 5 năm. | Luật Kế toán 2015 (Điều 41) & NĐ 174/2016 |
| **Tài khoản ngân hàng & Ví** | `bank_account`, `wallet` | Tối thiểu **5 năm** sau xóa mềm | • Chỉ xóa mềm (`Delete_at = now()`), ngắt kết nối ngân hàng.<br>• Giữ bản ghi tham chiếu để bảo toàn tính toàn vẹn của sổ cái và lịch sử giao dịch. | Luật Kế toán 2015 |
| **Kế hoạch & Định mức** | `budget`, `bill`, `goal` | Tối thiểu **3 - 5 năm** | • Xóa mềm qua `Delete_at`, lưu trữ phục vụ báo cáo đối soát. | Best Practice Tài chính |
| **Tài khoản & Định danh** | `account`, `user` | **30 ngày ân hạn** (`PendingDelete`) | • Trong 30 ngày: Người dùng được quyền dùng tiếp hoặc hủy xóa (`POST /api/auth/cancel-delete`).<br>• Hết 30 ngày: Tự động chuyển `Deleted` và thực thi **Quy trình Ẩn danh hóa triệt để (PII Anonymization)**: Họ tên $\rightarrow$ `"Người dùng đã xóa"`, SĐT/Địa chỉ $\rightarrow$ `null`, Email $\rightarrow$ `deleted_<id>_<hash>@anonymized.local`, Ghi chú & Ảnh chứng từ $\rightarrow$ `null`. Giữ nguyên số tiền và ngày giao dịch để duy trì sổ cái. | Nghị định 13/2023/NĐ-CP (Điều 9) |

### 12.6. Cơ chế Bảo vệ 2 Đầu (Two-layer Defense Architecture)
Hệ thống thiết lập cơ chế bảo mật 2 đầu: **Đầu 1 (Tầng Ứng dụng Backend / Client)** và **Đầu 2 (Tầng CSDL PostgreSQL Engine Triggers)**:

1. **Bảo vệ Số điện thoại (`User.Phone`):**
   - **Tầng CSDL:** Cột `Phone` kiểu `VARCHAR(256)`. **Trigger `trg_check_phone_encrypted`** ném ngoại lệ SQL chặn đứng lập tức nếu phát hiện chuỗi SĐT dạng số rõ (8 - 15 chữ số).
   - **Tầng Ứng dụng:** Mã hóa At-Rest chuẩn **AES-256-GCM** trước khi ghi vào CSDL; Giải mã trong suốt khi trả về cho chính chủ; Che mờ (Masking) `098****321` khi hiển thị danh sách quản trị hoặc xuất báo cáo.
2. **Bảo vệ Số tài khoản ngân hàng (`bank_account.Account_number`):**
   - **Tầng CSDL:** Cột `Account_number` kiểu `VARCHAR(256)`. **Trigger `trg_check_bank_account_encrypted`** ném ngoại lệ SQL chặn đứng lập tức nếu phát hiện STK dạng số rõ (6 - 25 chữ số).
   - **Tầng Ứng dụng:** Mã hóa At-Rest chuẩn **AES-256-GCM**; Masking `**** **** **** 1234` khi hiển thị trên giao diện Client và Admin.
3. **Mã hóa Địa chỉ nhà (`User.Address`):**
   - Mã hóa At-Rest AES-256-GCM trong CSDL; Masking trên giao diện quản trị Admin-web.
4. **Kiểm soát Lý do khóa tài khoản (`Reason_Inactive`):**
   - Tiện ích `validateReasonInactive` tự động quét phát hiện SĐT, Email, CCCD, Thẻ ngân hàng, hoặc từ ngữ thô tục/xúc phạm. Nếu phát hiện vi phạm, hệ thống từ chối lưu và trả về mã lỗi `400 Bad Request`.
5. **Lọc dữ liệu nhạy cảm & Mã hóa At-Rest cho `Note`:**
   - Trường ghi chú của Giao dịch, Ngân sách, Hóa đơn, Mục tiêu được quét qua `filterSensitiveNote` để tự động loại bỏ số thẻ tín dụng, CVV, mật khẩu, sau đó được mã hóa At-Rest AES-256-GCM trước khi lưu.

### 12.7. Tra soát Ngân hàng Tức thời O(1) Qua Blind Indexing
* Nhằm giải quyết bài toán mã hóa At-Rest số tài khoản ngân hàng mà vẫn duy trì hiệu năng xử lý tức thời cho Webhook SePay/Casso:
  * Bảng `bank_account` bổ sung cột `Account_number_hash` `VARCHAR(64)` có chỉ mục B-Tree Index.
  * Sinh mã hash một chiều bằng thuật toán `HMAC-SHA256` với khóa bí mật `BLIND_INDEX_SECRET` qua hàm `hashBlindIndex(accountNumber)`.
  * SePay/Casso Worker tính hash từ STK nhận được và truy vấn $O(1)$ theo `Account_number_hash`, loại bỏ hoàn toàn việc phải quét toàn bộ bảng (Table Scan) hay giải mã tuần tự.

### 12.8. Bảo mật Tệp Ảnh Chứng Từ Bằng Pre-Signed URL
* Toàn bộ ảnh hóa đơn, biên lai chuyển tiền (`transaction.images`) được lưu trong **Private Bucket**, cấm public URL trực tiếp ra ngoài Internet.
* Khi Client hoặc Admin cần hiển thị ảnh chứng từ:
  * Backend sử dụng tiện ích `storage.util.js` sinh **Pre-Signed URL** có chữ ký bảo mật HMAC kèm thời hạn ngắn (15 - 30 phút).
  * URL sau khi hết thời hạn (TTL) sẽ tự động vô hiệu hóa, bảo vệ tuyệt đối chứng từ tài chính khỏi việc bị sao chép hoặc rò rỉ công khai.



