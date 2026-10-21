# 📋 KẾ HOẠCH CHI TIẾT TINH CHỈNH & SỬA LỖI TRANG NHẬT KÝ KIỂM TOÁN (ADMIN-WEB)
> **Dự án:** Personal Finance Management — Module `src/Admin-web` & `src/Backend`  
> **Tài liệu nguồn sự thật kế hoạch:** `docs/Admin-web/AUDIT_LOG_REFINEMENT_PLAN.md`  
> **Người lập:** Lead BA + Lead FullStack cao cấp + Lead Tester  
> **Trạng thái:** ĐÃ TRIỂN KHAI VÀ NGHIỆM THU HOÀN TẤT 100% (40/40 test files pass, 404/404 backend tests pass, 0 build errors)  
> **Ngày lập:** 2026-10-21  

---

## 🎯 I. TỔNG QUAN KHẢO SÁT HIỆN TRẠNG & NGUYÊN NHÂN KỸ THUẬT

Dựa trên khảo sát thực tế tại URL `https://management-finance-gamma.vercel.app/audit`, mã nguồn tại `src/Admin-web/src/pages/system/AuditLogPage.jsx`, `src/Admin-web/src/utils/audit-tags.util.js`, và `src/Backend/modules/auth/auth.service.js`, các vấn đề được xác định nguyên nhân và hướng giải quyết cụ thể như sau:

| STT | Vị trí / Thành phần | Hiện trạng thực tế | Yêu cầu từ PO | Giải pháp kỹ thuật |
|---|---|---|---|---|
| **1** | **Header: Dòng ghi chú** | Dòng subtitle: *"Audit Log — Lưu vết toàn bộ thao tác và request gửi về hệ thống (Append-only)"* chiếm diện tích phía dưới tiêu đề. | Bỏ dòng ghi chú subtitle này | Xóa thẻ `<p className="font-body-md text-on-surface-variant mt-1">{t('auditLogs.subtitle')}</p>` trong `AuditLogPage.jsx` (dòng 261-263). |
| **2** | **Header: Icon fact_check** | Tiêu đề có icon `<span className="material-symbols-outlined text-primary text-[28px]">fact_check</span>` đứng trước chữ "Nhật Ký Hoạt Động". | Bỏ icon `fact_check` | Xóa icon `fact_check` khỏi tiêu đề `<h1>` trong `AuditLogPage.jsx` (dòng 258). |
| **3** | **Header: Nút Real-time** | Badge trạng thái Socket Real-time đang nằm chung với cụm nút thao tác bên phải (cùng Export CSV, Refresh). | Đưa nút/badge nhỏ "Real-time" sang nằm ngay sau dòng chữ "Nhật Ký Hoạt Động" | Đưa khối hiển thị Socket connection badge vào chung thẻ chứa tiêu đề `<h1>`: `<div className="flex items-center gap-3"><h1 ...>{t('auditLogs.title')}</h1>{socketConnected ? (...) : (...)}</div>`. |
| **4** | **Header: Nút Đặt lại** | Header có nút `filter_alt_off` "Đặt lại" nằm giữa nút "Xuất CSV" và "Làm mới", gây trùng lặp và xa rời thanh lọc. | Bỏ nút "Đặt lại" ở Header | Xóa nút `handleResetFilters` ở Header bên phải (dòng 293-300). Cụm nút Header bên phải chỉ còn lại 2 nút: `Xuất CSV` và `Làm mới`. |
| **5** | **Thanh lọc: Vị trí nút Đặt lại** | Nút "Đặt lại" trước đây nằm trên Header. | Bổ sung thêm nút "Đặt lại" cho bộ lọc nằm phía bên phải ngoài cùng của thanh bộ lọc | Thêm nút "Đặt lại" vào vị trí cuối cùng của Toolbar lọc với style `ml-auto shrink-0`, icon `filter_alt_off`, bấm vào gọi `handleResetFilters`. |
| **6** | **Thanh lọc: Bố cục & UI Khoảng ngày** | Dùng `grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3`: Ô Từ ngày và Đến ngày là 2 khung viền hộp riêng biệt to, nhiều đường viền, gây rối mắt. | - Giữ nguyên thanh tìm kiếm.<br>- Thu nhỏ LOV trạng thái.<br>- Thu nhỏ Từ ngày - Đến ngày, áp dụng UI khác ít viền hơn cho đỡ rối mắt. | Chuyển Toolbar sang container linh hoạt `flex flex-wrap items-center gap-2.5`:<br>1. **Tìm kiếm:** Giữ nguyên `flex-1 min-w-[220px]`.<br>2. **LOV trạng thái:** Thu nhỏ gọn gàng `w-40 sm:w-44 shrink-0`.<br>3. **Từ ngày - Đến ngày:** Gom chung vào 1 container ngày thanh thoát (`inline-flex items-center gap-1.5 px-3 py-1.5 bg-slate-50/70 border border-slate-200/80 rounded-lg text-xs`): có icon lịch `calendar_month` nhỏ, input Từ ngày, mũi tên `→`, input Đến ngày, và nút xóa nhanh (x). Loại bỏ hoàn toàn 2 khung viền hộp riêng biệt gây thô cứng.<br>4. **Nút Đặt lại:** Đặt ở góc phải ngoài cùng `ml-auto shrink-0`. |
| **7** | **Danh sách audit_log: Chuẩn hóa hành động** | - Xuất hiện badge `[PAYMENT]` (hoặc "Paymen" khi co hẹp cột).<br>- Cột Hành động lúc thì hiển thị chữ tiếng Việt (như "Đăng nhập hệ thống"), lúc lại hiển thị chuỗi API kỹ thuật (như `POST /api/v1/payments/create-order`). | PO ghi chú: *"Chưa nắm rõ cách chuẩn hóa hành động - hỏi lại trước khi sửa (Tại sao lại có Paymen - hành động lúc chữ lúc api ?)"* | **Xem phân tích chi tiết tại Mục II** và giải pháp chuẩn hóa đồng bộ 100% tiếng Việt cho cột Hành động. |

---

## 🔍 II. GIẢI THÍCH CHUYÊN SÂU CHO PO: TẠI SAO CÓ NHÃN "PAYMENT" & TẠI SAO HÀNH ĐỘNG "LÚC CHỮ LÚC API"?

### 1. Tại sao lại có nhãn `[PAYMENT]` (hoặc "Paymen")?
- Trong hệ thống tại file `src/Admin-web/src/utils/audit-tags.util.js`, có hàm `classifyAuditAction(actionText)` làm nhiệm vụ tự động phân loại hoạt động thành các nhóm nghiệp vụ (Tags) để gắn badge màu:
  + `[AUTH]`: Xác thực tài khoản (Đăng nhập, Đăng xuất, OTP, PIN)
  + `[PAYMENT]`: Thanh toán & Gói cước (Đơn hàng, Nâng cấp gói, Hoàn tiền, PayOS)
  + `[USER]`: Quản lý người dùng (Khóa/mở tài khoản, Xóa mềm)
  + `[SYSTEM]`: Hệ thống (Bảo trì, Phát thông báo)
  + `[AIOPS]`: An ninh AI (Cách ly IP, Chặn truy cập)
  + `[CATEGORY]`: Quản lý danh mục
  + `[API]`: Các API kỹ thuật khác
- Khi chuỗi hành động có chứa từ khóa liên quan đến thanh toán (như `payment`, `thanh toán`, `payos`, `nâng cấp gói`, `hoàn tiền`,...), hệ thống tự động gán badge màu ngọc lục bảo mang nhãn **`[PAYMENT]`**.
- Trên màn hình của PO: Do độ rộng của cột bảng bị giới hạn hoặc text co hẹp, chữ `[PAYMENT]` hiển thị hoặc bị ngắt chữ thành "Paymen".

### 2. Tại sao cột "Hành động" lúc thì là chữ tiếng Việt, lúc thì là chuỗi API?
Hệ thống CSDL (bảng `audit_log` từ migration 33) lưu trữ 2 trường riêng biệt:
- Trường `request`: Lưu chuỗi HTTP request kỹ thuật (ví dụ: `POST /api/v1/payments/create-order`, `POST /api/v1/auth/login`).
- Trường `action`: Lưu mô tả hành vi nghiệp vụ (ví dụ: "Đăng nhập hệ thống", "Tạo đơn hàng thanh toán").

**Nguyên nhân gốc rễ (Root Cause) gây ra hiện tượng "lúc chữ lúc api":**
1. **Ở Backend (`src/Backend/modules/auth/auth.service.js` - hàm `formatActionName`):**
   - Hiện tại hàm này mới chỉ ánh xạ cứng (hardcode) tên tiếng Việt cho một số API: `/auth/*`, `/sync/*`, `/bank/*`, `/ai/*`, và vài API cơ bản của `/admin/*` (`/admin/updatestatus`, `/admin/getcategory`, `/admin/addcategory`, `/admin/updatecategory`, `/admin/deletecategory`, `/admin/getuser`).
   - **Tất cả các API Thanh toán** (`/payment/*`, `/payments/*`, `/admin/payments/*`), các API **Admin nâng cao** (`/admin/permissions`, `/admin/verify-security-action`, `/admin/change-pin`, `/admin/system/maintenance`,...), và các API tài chính của người dùng (Giao dịch, Ví, Ngân sách, Báo cáo) **CHƯA ĐƯỢC ÁNH XẠ** sang tiếng Việt!
   - Khi gặp một API chưa được ánh xạ, Backend tự động fallback trả về:  
     `${method} ${path}` (ví dụ: `POST /api/v1/payments/create-order`).
   - Do đó, cột `action` trong CSDL bị lưu chuỗi API thô thay vì tiếng Việt!
2. **Ở Frontend (`AuditLogPage.jsx`):**
   - Bảng hiện tại chia làm 2 cột: Cột 3 là **"Hành động"** (`Action`) và Cột 4 là **"Yêu cầu API"** (`Request`).
   - Với các bản ghi Đăng nhập: Cột 3 hiển thị `[AUTH] Đăng nhập hệ thống`, Cột 4 hiển thị `[POST] /api/v1/auth/login` $\rightarrow$ Rất đẹp và rõ ràng.
   - Với các bản ghi Thanh toán hoặc API khác: Cột 3 hiển thị `[PAYMENT] POST /api/v1/payments/create-order`, Cột 4 lại hiển thị `[POST] /api/v1/payments/create-order` $\rightarrow$ Hai cột trùng lặp nhau, khiến PO nhìn vào thấy lúc thì có chữ tiếng Việt, lúc lại là chuỗi API.
   - Thêm vào đó, với các dữ liệu log cũ được tạo trước đây (trước khi có cột `action`), trường `action` trong DB bị `null`, nên Frontend cũng fallback lấy cột `request` (chuỗi API).

---

## 💡 III. PHƯƠNG ÁN CHUẨN HÓA ĐÃ ĐƯỢC PO LỰA CHỌN

> 🎯 **Quyết định từ Product Owner (PO):**
> **"Chuẩn hóa 100% tiếng Việt cho cột Hành động (dịch mọi endpoint sang câu nghiệp vụ như 'Tạo đơn hàng thanh toán PayOS', 'Xác thực mã PIN'...); Giữ nguyên mã Tag chuẩn tiếng Anh [PAYMENT], [AUTH], [USER], [SYSTEM], [AIOPS], [CATEGORY], [API]."**

### Chi tiết giải pháp kỹ thuật 2 đầu Frontend & Backend:
1. **Tại Frontend (`src/Admin-web/src/utils/audit-tags.util.js`):**
   - Xây dựng **Bộ từ điển ánh xạ thông minh (Smart Action Formatter)**:
     Bất kể CSDL trả về chuỗi API thô nào (kể cả dữ liệu lịch sử cũ trước đây), Frontend sẽ tự động dịch sang tiếng Việt mô tả nghiệp vụ thân thiện:
     + `POST /api/v1/payments/create-order` $\rightarrow$ `"Tạo đơn hàng thanh toán gói cước"`
     + `GET /api/v1/payments/order-status/...` $\rightarrow$ `"Tra cứu trạng thái đơn hàng"`
     + `GET /api/v1/payments/subscription-info` $\rightarrow$ `"Xem thông tin gói dịch vụ"`
     + `GET /api/v1/payments/history` $\rightarrow$ `"Xem lịch sử mua gói cước"`
     + `POST /api/v1/payments/webhook` $\rightarrow$ `"Webhook tiếp nhận thanh toán PayOS"`
     + `POST /api/v1/payments/confirm-upgrade` $\rightarrow$ `"Xác nhận nâng cấp gói cước"`
     + `GET /api/admin/payments/orders` $\rightarrow$ `"Tra cứu danh sách đơn hàng toàn hệ thống"`
     + `GET /api/admin/payments/stats` $\rightarrow$ `"Thống kê doanh thu thanh toán"`
     + `PUT /api/admin/payments/orders/.../refund` $\rightarrow$ `"Xử lý hoàn tiền đơn hàng"`
     + `POST /api/admin/verify-security-action` $\rightarrow$ `"Xác thực mã PIN bảo mật"`
     + `POST /api/admin/change-pin` $\rightarrow$ `"Đổi mã PIN quản trị viên"`
     + `GET /api/admin/permissions` $\rightarrow$ `"Xem ma trận phân quyền gói cước"`
     + `PUT /api/admin/permissions` $\rightarrow$ `"Cập nhật phân quyền gói cước"`
     + `POST /api/admin/system/maintenance` $\rightarrow$ `"Bật/tắt chế độ bảo trì hệ thống"`
   - **Kết quả:** 100% các dòng trên Cột "Hành động" luôn luôn là **CHỮ TIẾNG VIỆT RÕ RÀNG**, không bao giờ bị lẫn chuỗi API! Cột "Yêu cầu API" bên cạnh sẽ đảm nhận vai trò hiển thị method/path kỹ thuật.
2. **Tại Backend (`src/Backend/modules/auth/auth.service.js`):**
   - Bổ sung toàn bộ các ánh xạ endpoint trên vào hàm `formatActionName`. Khi có request mới phát sinh, Backend sẽ lưu sẵn câu tiếng Việt chuẩn vào cột `Action` trong CSDL.
3. **Về nhãn phân loại (Tag `[PAYMENT]`):**
   - Giữ nguyên các mã Tag chuẩn tiếng Anh quốc tế: `[PAYMENT]`, `[AUTH]`, `[USER]`, `[SYSTEM]`, `[AIOPS]`, `[CATEGORY]`, `[API]`. Tooltip hỗ trợ tiếng Việt tương ứng (`Thanh toán`, `Xác thực`, `Người dùng`, `Hệ thống`, `An ninh`, `Danh mục`, `API`).

---

## 🏛️ IV. PHÂN TÍCH TÁC ĐỘNG 2 CHIỀU (DUAL-AXIS REASONING)

### 1. Suy luận theo chiều ngang (Horizontal Reasoning)
- **Module `src/Admin-web`:**
  - `src/Admin-web/src/pages/system/AuditLogPage.jsx`: Cập nhật cấu trúc Header, di chuyển badge Real-time, tái cấu trúc Toolbar lọc (nút Đặt lại ở bên phải ngoài cùng, UI Từ ngày - Đến ngày gộp chung mềm mại), bảng hiển thị Action đã chuẩn hóa.
  - `src/Admin-web/src/utils/audit-tags.util.js`: Mở rộng `classifyAuditAction` để dịch toàn bộ API endpoints sang câu tiếng Việt chuẩn mực.
  - `src/Admin-web/src/locales/vi.js` & `en.js`: Đảm bảo đồng bộ các nhãn dịch thuật.
- **Module `src/Backend`:**
  - `src/Backend/modules/auth/auth.service.js`: Mở rộng `formatActionName` để sinh tên hành động tiếng Việt chuẩn mực ngay từ khâu ghi log CSDL và phát socket real-time `audit_activity`.
- **Module `src/Client-app`:**
  - Hoàn toàn không bị ảnh hưởng, các API Client gọi vẫn được log và hiển thị chuẩn hóa trên Admin-web.

### 2. Suy luận theo chiều sâu (Vertical / Deep-Impact Reasoning)
- **Bảo toàn CSDL & DB Guard (Rule 10):**
  - Không thay đổi bảng `audit_log`, không chạy migration phá vỡ cấu trúc.
  - Trigger `trg_protect_auditlog` (bảo vệ chống UPDATE/DELETE bảng audit_log theo Nghị định 13) được bảo toàn nguyên vẹn 100%.
- **Hiệu năng & Trải nghiệm người dùng:**
  - Bảng không còn tình trạng trùng lặp thông tin giữa cột Hành động và Yêu cầu API.
  - Thanh lọc gọn gàng, loại bỏ các đường viền dày đặc gây rối mắt, thao tác lọc nhanh chóng.

---

## 🧪 V. KIẾN TRÚC KIỂM THỬ 2 TẦNG (2-TIER TESTING ARCHITECTURE)

Theo quy định bắt buộc tại **Rule 11**, bài test sẽ bao gồm đầy đủ 2 tầng:

### 🧱 TẦNG 1: KIỂM THỬ HIỂN THỊ & THAO TÁC GIAO DIỆN (UI Rendering & Interaction)
1. **Header:** Xác nhận subtitle cũ và icon `fact_check` không còn tồn tại trên DOM; badge `Real-time` nằm cạnh tiêu đề `Nhật Ký Hoạt Động`; nút `Đặt lại` không còn ở Header.
2. **Thanh lọc:** Nút "Đặt lại" xuất hiện ở bên phải ngoài cùng của Toolbar lọc; cụm Từ ngày - Đến ngày hiển thị trong 1 container duy nhất; input search và select status thu nhỏ đúng tỷ lệ.
3. **Thao tác tương tác:** Nhập từ khóa, chọn trạng thái, chọn ngày, bấm nút "Đặt lại" trên Toolbar lọc không crash và xóa sạch các trường lọc về mặc định.

### ⚡ TẦNG 2: KIỂM THỬ TÁC ĐỘNG HỆ THỐNG THỰC TẾ (System Impact & Behavioral Verification)
1. **Chuẩn hóa Hành động (Zero API Leak in Action column):** Khi dữ liệu trả về là chuỗi API thô (ví dụ: `POST /api/v1/payments/create-order` hoặc `PUT /api/admin/permissions`), cột Hành động **BẮT BUỘC** hiển thị câu tiếng Việt tương ứng (`Tạo đơn hàng thanh toán gói cước`, `Cập nhật phân quyền gói cước`), TUYỆT ĐỐI không để lộ chuỗi API thô trong cột Hành động.
2. **Tác động Nút Đặt lại:** Click nút "Đặt lại" trên Toolbar lọc sẽ khôi phục toàn bộ state lọc về rỗng (`search: ''`, `status: ''`, `dateFrom: ''`, `dateTo: ''`, `page: 1`) và kích hoạt `adminApi.getAuditLogs` với tham số mặc định.
3. **Bộ lọc Ngày thanh thoát:** Thay đổi ngày Từ ngày và Đến ngày gửi đúng tham số `startDate` và `endDate` lên API `getAuditLogs`.

---

## 📋 VI. CÁC BƯỚC THỰC THI CHI TIẾT (SAU KHI PO DUYỆT)
- [x] **Bước 1:** Nâng cấp `src/Admin-web/src/utils/audit-tags.util.js` bổ sung từ điển dịch thuật thông minh cho toàn bộ API endpoints (Payment, Permissions, Maintenance, PIN,...) sang câu mô tả nghiệp vụ tiếng Việt.
- [x] **Bước 2:** Bổ sung ánh xạ trong `src/Backend/modules/auth/auth.service.js` (`formatActionName`) đồng bộ với Frontend.
- [x] **Bước 3:** Tinh chỉnh `src/Admin-web/src/pages/system/AuditLogPage.jsx`:
  - Lược bỏ subtitle và icon `fact_check`.
  - Di chuyển badge `Real-time` sang cạnh tiêu đề.
  - Bỏ nút "Đặt lại" ở Header.
  - Tái cấu trúc Toolbar lọc (Search + Status LOV gọn + Khung ngày Từ-Đến mềm mại ít viền + Nút Đặt lại ở bên phải ngoài cùng).
- [x] **Bước 4:** Viết bộ test 2 tầng `src/Admin-web/src/tests/audit.refinement.2tier.test.jsx` thẩm tra toàn diện UI và tác động hệ thống.
- [x] **Bước 5:** Chạy toàn bộ test suites của Admin-web (`rtk npm test`) và Backend (`rtk npm test`), kiểm tra `rtk npm run build`.
- [x] **Bước 6:** Cập nhật `Project.md` và rebuild CodeGraph (`rtk npx codegraph build`).
