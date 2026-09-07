# 📜 TỔNG HỢP NGUYÊN TẮC & QUY TẮC DỰ ÁN — MANAGEMENTFINANCE
> **Source of Truth** về các nguyên tắc kiến trúc, quy trình vận hành phát triển phần mềm, cùng toàn bộ các quy tắc kỹ thuật và nghiệp vụ cụ thể của hệ thống **ManagementFinance**.
>
> *Ngày cập nhật:* 2026-09-07  
> *Phạm vi áp dụng:* Toàn bộ dự án (`src/Backend`, `src/Admin-web`, `src/Client-app`).

---

# 🏛️ PHẦN I: NGUYÊN TẮC XÂY DỰNG & VẬN HÀNH DỰ ÁN

## ⚡ 1. KHẨU HIỆU & QUY TẮC CỐT LÕI (TL;DR)

```
RTK | CODEGRAPH | PROJECT.MD | SKILL→PHASE | KARPATHY | SELF-CHECK
```

* **RTK mọi lệnh CLI:** Mọi lệnh terminal bắt buộc có tiền tố `rtk` (ví dụ: `rtk npm test`, `rtk git status`).
* **CodeGraph kiểm tra tác động:** Dùng `brief`, `deps`, `context`, `impact` trước khi sửa mã nguồn.
* **Project.md nắm ngữ cảnh:** Đọc `Project.md` để nắm kiến trúc, tech stack và quy ước trước khi bắt đầu.
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
3. **Migration:** Thực thi qua lệnh chuẩn hóa của Prisma để cập nhật lược đồ CSDL.
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
    `Account` $\rightarrow$ `Wallet` $\rightarrow$ `Category` $\rightarrow$ `CategoryGroup` $\rightarrow$ `CategoryGroupMembership` $\rightarrow$ `Goal` $\rightarrow$ `Bill` $\rightarrow$ `Budget` $\rightarrow$ `Transaction`.
* **UUID Danh mục Mặc định Ổn Định (Stable UUIDs):**
  * Các danh mục hệ thống mặc định phải dùng tập UUID cố định đóng băng (trong `seed.js`), không được sinh UUID ngẫu nhiên mỗi lần seed lại để tránh lệch dữ liệu với SQLite client.
* **Toàn vẹn tên danh mục:**
  * Chống trùng tên danh mục giữa các bản ghi đang hoạt động (Partial Unique Index lọc `Delete_at IS NULL`).
  * Sử dụng Database Trigger để ngăn người dùng tạo danh mục cá nhân trùng tên với danh mục mặc định của hệ thống.

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

## 🛡️ 6. NGUYÊN TẮC AN NINH & BẢO MẬT HỆ THỐNG

1. **Socket.io Security:**
   * Bắt buộc xác thực token JWT ngay từ bước kết nối (handshake).
   * Phân lập phòng (Room) theo từng tài khoản (`account_${idaccount}`). Tuyệt đối không phát sự kiện chứa thông tin người dùng (`audit_activity`, notification) ra phòng ẩn danh toàn cục.
2. **Bảo mật phản hồi lỗi (Error Obfuscation):**
   * Che giấu toàn bộ thông tin nội bộ của CSDL, stack trace Prisma trước khi trả về client.
   * Ánh xạ thành mã lỗi chuẩn hóa (`CONSTRAINT_VIOLATION`, `FOREIGN_KEY_VIOLATION`, `UNIQUE_VIOLATION`).
3. **Môi trường Production Guard:**
   * Chặn hoàn toàn các tham số giả lập (`_mock*`, mock headers) khi chạy trên môi trường Production.
4. **Bảo vệ mật khẩu & Mã xác thực:**
   * Mã OTP (email reset password, change email) bắt buộc lưu trữ dưới dạng băm (SHA-256 hash).
   * Mật khẩu tài khoản băm bằng thuật toán an toàn với salt (bcrypt).

---

## 📋 7. QUY ĐỊNH KẾT THÚC NHIỆM VỤ (RULE 8)

Khi kết thúc một nhiệm vụ kỹ thuật, AI **bắt buộc** phải hoàn thành 2 công việc cuối cùng trước khi báo cáo hoàn tất cho PO:

1. **Cập nhật Nguồn Sự Thật (Documentation Update):**
   * Đọc và cập nhật lại file [`Project.md`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/Project.md) và các tài liệu liên quan để phản ánh đúng hiện trạng sau thay đổi.
2. **Cập nhật CodeGraph:**
   * Chạy lệnh cập nhật đồ thị mã nguồn dự án:  
     ```bash
     rtk npx codegraph build
     ```
> [!WARNING]  
> Nếu thiếu 2 bước này, nhiệm vụ kỹ thuật **CHƯA ĐƯỢC TÍNH LÀ HOÀN TẤT**.

---

## ✅ 8. BẢNG TỰ KIỂM TRA TRƯỚC KHI BÁO "DONE" (SELF-CHECKLIST)

Trước khi gửi câu trả lời hoàn thành tới PO, hãy tự kiểm tra 6 câu hỏi sau:

- [ ] **RTK?** Mọi lệnh CLI đã chạy có tiền tố `rtk` chưa?
- [ ] **CodeGraph?** Đã dùng `context`/`deps`/`brief`/`impact` để phân tích tác động chưa?
- [ ] **Project.md?** Đã đọc và nắm vững ngữ cảnh dự án chưa?
- [ ] **Skill & Phase?** Đã tuân thủ quy trình 4-Phase và dùng đúng skill chưa?
- [ ] **Test?** Toàn bộ bài kiểm thử đã chạy và đạt 100% PASS chưa?
- [ ] **Tài liệu & CodeGraph?** Đã cập nhật `Project.md` và chạy `rtk npx codegraph build` chưa?

---
---

# ⚙️ PHẦN II: CÁC QUY TẮC KỸ THUẬT & NGHIỆP VỤ CỤ THỂ

Phần này đặc tả chi tiết toàn bộ các quy tắc ràng buộc, chốt chặn CSDL, thuật toán xử lý và quy chuẩn dữ liệu áp dụng cho từng thực thể và module trong hệ thống.

---

## 🏷️ 1. QUY TẮC VỀ DANH MỤC (CATEGORY RULES)

### 1.1. Ràng buộc duy nhất tên danh mục (Name Uniqueness)
* **Quy tắc sở hữu cá nhân (`uq_category_owner_name`):**
  * **Cột ràng buộc:** `UNIQUE (Create_by, Name)`
  * **Điều kiện lọc:** `WHERE "Delete_at" IS NULL`
  * **Ý nghĩa:** Một người dùng không được phép tạo 2 danh mục trùng tên nhau trong danh sách danh mục đang hoạt động của mình. Nếu một danh mục cũ đã bị xóa mềm (`Delete_at IS NOT NULL`), người dùng được phép tạo lại tên đó.
* **Quy tắc danh mục hệ thống mặc định (`uq_category_default_name`):**
  * **Cột ràng buộc:** `UNIQUE (Name)`
  * **Điều kiện lọc:** `WHERE "Create_by" = 1 AND "Delete_at" IS NULL`
  * **Ý nghĩa:** Đảm bảo toàn bộ danh mục mặc định của hệ thống không bao giờ bị trùng tên lẫn nhau.
* **Chống trùng tên chéo qua Trigger CSDL (`trg_category_name_cross_default`):**
  * **Cơ chế:** PostgreSQL Trigger chạy trước khi `INSERT` hoặc `UPDATE` vào bảng `category`.
  * **Hành vi:** Ngăn người dùng tạo danh mục cá nhân có tên trùng với bất kỳ danh mục mặc định nào đang hoạt động của hệ thống.
  * **Chuẩn hóa đối soát:** So sánh chuỗi không phân biệt hoa thường (`LOWER`), loại bỏ dấu tiếng Việt (`unaccent`), và cắt tỉa khoảng trắng (`TRIM`).
  * *Ví dụ:* Nếu hệ thống đã có *"Ăn uống"*, người dùng tạo *"an uong"* hay *"ĂN UỐNG"* sẽ bị CSDL chặn ngay lập tức.

### 1.2. Bộ định danh UUID ổn định (Stable UUIDs)
* 13 danh mục mặc định gốc của hệ thống được gán cứng 13 Stable UUIDs cố định trong [`seed.js`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/prisma/seed.js).
* Tuyệt đối không sinh `crypto.randomUUID()` ngẫu nhiên khi chạy seed CSDL để tránh làm lệch ID với CSDL SQLite trên Client-app.

### 1.3. Bộ giá trị phân loại (`Classify` Enum)
* Giá trị của cột `classify` bắt buộc phải thuộc tập 3 giá trị chuẩn:
  * `'Thu'` (Khoản thu nhập)
  * `'Chi'` (Khoản chi tiêu)
  * `'Vay/no'` (Các khoản vay, nợ)
* Validator ở Sync Engine (`sync.validation.js`) chỉ chấp nhận đúng 3 giá trị này.

### 1.4. Phân quyền học từ khóa AI (Keyword Learning Permission)
* Khi gọi `POST /api/ai/classify/feedback` để huấn luyện từ khóa danh mục:
  * Người dùng chỉ được phép bổ sung từ khóa vào danh mục do chính họ tạo ra (`Create_by = idaccount`).
  * Cấm tuyệt đối việc ghi đè từ khóa vào danh mục mặc định của hệ thống (`Create_by = 1`) hoặc danh mục của người dùng khác $\rightarrow$ Hệ thống lập tức từ chối với mã **HTTP 403 Forbidden**.

### 1.5. Nhóm danh mục (`category_group` & `category_group_membership`)
* Bảng quan hệ `category_group_membership` gắn kết Danh mục với Nhóm danh mục.
* Thứ tự ưu tiên đồng bộ (`ENTITY_PRIORITY`):
  * `Category`: 10
  * `CategoryGroup`: 12
  * `CategoryGroupMembership`: 15 (đảm bảo cả Category và Group đều đã tồn tại trước khi tạo quan hệ).

---

## 💰 2. QUY TẮC VỀ VÍ TIỀN (WALLET RULES)

### 2.1. Quy tắc Ví mặc định (`is_default`)
* Mỗi tài khoản (`idaccount`) chỉ có **duy nhất 1 ví mặc định** (`is_default = true`) tại một thời điểm.
* Khi người dùng chỉ định một ví mới làm ví mặc định, hệ thống tự động gỡ cờ mặc định (`is_default = false`) của tất cả các ví còn lại thuộc tài khoản đó.

### 2.2. Tính toán tổng tài sản (`include_in_total`)
* Cờ boolean xác định số dư của ví có được tính vào Tổng tài sản (Net Worth) hiển thị trên màn hình tổng quan hay không:
  * `true`: Cộng số dư vào tổng tài sản (ví tiền mặt, thẻ ngân hàng chi tiêu chính).
  * `false`: Tách biệt khỏi tổng tài sản (ví tiết kiệm mục tiêu riêng biệt, tài khoản quỹ nhóm...).

### 2.3. Loại ví (`Type` Enum)
* Hệ thống hỗ trợ 4 phân loại ví cơ bản:
  * `'Cash'`: Tiền mặt trong ví/két.
  * `'Bank'`: Tài khoản ngân hàng (có thể liên kết qua `id_bank_casso` / SePay).
  * `'E-wallet'`: Ví điện tử (MoMo, ZaloPay, ViettelPay...).
  * `'Credit'`: Thẻ tín dụng (theo dõi hạn mức và dư nợ âm).

### 2.4. Xóa ví (Soft Delete)
* Xóa ví là xóa mềm qua trường `delete_at`.
* Các giao dịch thuộc ví bị xóa vẫn được bảo toàn lịch sử thu chi để không làm sai lệch báo cáo tài chính quá khứ.

---

## 💳 3. QUY TẮC VỀ GIAO DỊCH (TRANSACTION RULES)

### 3.1. Ràng buộc duy nhất giao dịch từ bên ngoài (Dedup Constraint)
* **Khóa duy nhất CSDL (`uq_transaction_external`):**
  * **Cột ràng buộc:** `UNIQUE (Idaccount, Provider, Bank_tran_id)`
  * **Ý nghĩa:** Đảm bảo mỗi mã giao dịch (`bank_tran_id`) từ một nguồn bên ngoài (`Provider`) chỉ xuất hiện 1 lần duy nhất trên mỗi tài khoản người dùng (`Idaccount`).
  * **Multi-tenant Safe:** Hai người dùng khác nhau có thể có mã giao dịch ngân hàng trùng nhau mà không gây xung đột hệ thống.

### 3.2. Cơ chế tác động số dư ví (Balance Mutation)
Mỗi loại giao dịch (`Type`) kích hoạt một logic toán học chính xác trên số dư ví:
* **Chi tiêu (`Expense` / `Chi`):**
  * Trừ số dư ví: `wallet.balance = wallet.balance - amount`
* **Thu nhập (`Income` / `Thu`):**
  * Cộng số dư ví: `wallet.balance = wallet.balance + amount`
* **Chuyển khoản nội bộ (`Transfer` / `ChuyenKhoan`):**
  * Bắt buộc có đủ cả hai ID ví: `Idwallet` (ví nguồn) và `Idwallet_transfer` (ví đích).
  * Trừ ví nguồn: `source_wallet.balance = source_wallet.balance - amount`
  * Cộng ví đích: `target_wallet.balance = target_wallet.balance + amount`
* **Vay / Nợ (`Debt` / `Loan`):**
  * Theo dõi công nợ, phân định rõ số tiền đã thu hồi / đã hoàn trả.

### 3.3. Liên kết mục tiêu tiết kiệm (`Idgoal`)
* Cột `Idgoal` (UUID, nullable) lưu dấu vết khoản giao dịch được trích cho mục tiêu nào.
* **Khóa ngoại an toàn (`fk_transaction_goal`):** Cài đặt `ON DELETE SET NULL`. Khi người dùng xóa mục tiêu, toàn bộ giao dịch liên quan KHÔNG bị xóa mà chỉ đưa `Idgoal` về `NULL`, bảo vệ 100% số dư ví và báo cáo dòng tiền.

### 3.4. Nhà cung cấp giao dịch (`Provider`)
* `'Manual'`: Người dùng tự tạo bằng tay trên ứng dụng.
* `'BankSync'`: Giao dịch tự động ghi nhận từ Webhook ngân hàng (SePay / Casso).
* `'SMS'`: Giao dịch trích xuất tự động từ tin nhắn ngân hàng (xử lý offline trên client).
* `'OCR'`: Giao dịch trích xuất từ hóa đơn bằng AI OCR.

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
* Sử dụng đánh số thứ tự thưa (10, 20, 30...) để người dùng có thể dễ dàng chèn một mục tiêu mới vào giữa danh sách mà không cần cập nhật lại toàn bộ các bản ghi khác.

---

## 📑 6. QUY TẮC VỀ HÓA ĐƠN ĐỊNH KỲ (BILL RULES)

### 6.1. Ràng buộc bắt buộc
* Hóa đơn bắt buộc phải liên kết với một Ví thanh toán dự kiến (`idwallet`) và một Danh mục chi phí (`idcategory`).

### 6.2. Trạng thái thanh toán (`pay_status` Enum)
* `'Pending'`: Chờ đến hạn thanh toán.
* `'Paid'`: Đã thanh toán (đã sinh ra khoản chi tương ứng).
* `'Overdue'`: Đã quá hạn thanh toán (`current_date > due_date` và chưa thanh toán).
* `'Skipped'`: Người dùng chủ động bỏ qua kỳ hóa đơn này (không thanh toán và không tính nợ).

### 6.3. Chuỗi kỳ hóa đơn & Lịch sử
* `start_date` và `due_date`: Mốc bắt đầu kỳ và hạn chót thanh toán của kỳ hóa đơn đó.
* `previous_bill_id`: Cột liên kết ID tới hóa đơn của kỳ liền trước. Dùng để:
  * Truy vết lịch sử biến động chi phí qua các kỳ (ví dụ: tiền điện 6 tháng qua).
  * Hỗ trợ hoàn tác (undo) thanh toán hóa đơn về trạng thái chưa trả.

### 6.4. Chốt chặn thanh toán hai lần (Double-Payment Guard)
* Khi tiếp nhận yêu cầu thanh toán hóa đơn hoặc đẩy giao dịch có gắn `Idbill`, Sync Engine kiểm tra hóa đơn tương ứng trong kỳ đó đã ở trạng thái `'Paid'` hay chưa, ngăn chặn việc 2 thiết bị cùng thanh toán 1 hóa đơn khi chuyển từ trạng thái offline sang online.

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
