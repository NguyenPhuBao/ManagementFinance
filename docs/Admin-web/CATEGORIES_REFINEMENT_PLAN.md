# 📋 KẾ HOẠCH CHI TIẾT TINH CHỈNH & SỬA LỖI TRANG QUẢN LÝ DANH MỤC (ADMIN-WEB)
> **Dự án:** Personal Finance Management — Module `src/Admin-web` & `src/Backend`  
> **Tài liệu nguồn sự thật kế hoạch:** `docs/Admin-web/CATEGORIES_REFINEMENT_PLAN.md`  
> **Người lập:** Lead BA + Lead FullStack cao cấp + Lead Tester  
> **Trạng thái:** ĐÃ TRIỂN KHAI VÀ NGHIỆM THU HOÀN TẤT 100% (39/39 test suites pass, 0 build errors)  
> **Ngày lập:** 2026-10-21  

---

## 🎯 I. TỔNG QUAN YÊU CẦU & KẾT QUẢ KHẢO SÁT HIỆN TRẠNG

Dựa trên khảo sát thực tế tại URL `https://management-finance-gamma.vercel.app/categories`, ảnh chụp màn hình do PO cung cấp và mã nguồn tại `src/Admin-web/src/pages/categories/CategoryPage.jsx`, các vấn đề được xác định nguyên nhân và giải pháp kỹ thuật cụ thể:

| STT | Vị trí / Thành phần | Hiện trạng thực tế | Yêu cầu từ PO | Giải pháp kỹ thuật |
|---|---|---|---|---|
| **1** | **Header trang Danh mục** | - Icon `category` nằm trong khung `w-12 h-12`<br>- Badge `NLP Keywords Ready`<br>- Subtitle dài: *"Quản lý các danh mục tài chính mặc định, chuẩn hóa bộ từ khóa nhận diện giao dịch tự động"* | - Bỏ icon `category`<br>- Bỏ badge `NLP Keywords Ready`<br>- Bỏ dòng ghi chú subtitle dài | Loại bỏ 3 thành phần trên trong `CategoryPage.jsx` (dòng 406-424). Giữ lại tiêu đề trang `Quản lý danh mục hệ thống` và 2 nút `Làm mới`, `Thêm danh mục mới` tinh gọn. |
| **2** | **Modal Thêm & Chỉnh sửa danh mục** | Dòng ghi chú dưới ô Keyword: *"Nhập các từ khóa phân cách bởi dấu phẩy (,). Giúp bộ máy AI tự động nhận diện danh mục khi phân loại giao dịch."* | Lược bỏ vế sau, chỉ giữ lại hướng dẫn phân tách dấu phẩy | Cập nhật `categories.modal.keywordHint` trong `vi.js` thành: *"Nhập các từ khóa phân cách bởi dấu phẩy (,)."* và trong `en.js` thành: *"Enter comma-separated keywords (,)."* |
| **3** | **Modal Xác nhận xóa danh mục** | Modal hiện tại hiển thị câu hỏi kèm 1 khung box xám cảnh báo Xóa Mềm (Soft Delete) với 3 gạch đầu dòng giải thích chi tiết chiếm diện tích | Chỉ hiển thị popup với đúng 1 dòng: `Bạn chắc chắn muốn xóa danh mục "<Tên danh mục>" ?` và 2 nút `Hủy`, `Xác nhận xóa`. Bỏ hoàn toàn phần ghi chú giải thích. | Xóa bỏ khung ghi chú Soft Delete (dòng 975-989) trong `CategoryPage.jsx`. Giữ lại đúng câu hỏi xác nhận và 2 action buttons `Hủy` / `Xác nhận xóa`. |
| **4** | **Cơ chế BẢN NHÁP (Draft Mode) cho Thêm/Sửa/Xóa** | Hiện tại mỗi khi Admin thêm, sửa, xóa danh mục trên modal thì gọi API lưu CSDL ngay lập tức | Thêm/Sửa/Xóa xong hệ thống ghi nhận vào **bản nháp** trên giao diện, **không vội lưu CSDL** | Tạo state quản lý bản nháp (`draftChanges` / `stagedCategories`). Thao tác Thêm/Sửa/Xóa cập nhật danh sách hiển thị tức thời (kèm badge nhận diện nháp) nhưng chưa bắn API về Database. |
| **5** | **Nút "Đặt lại mặc định"** | Chưa có nút này trên giao diện | Thêm nút *"Đặt lại mặc định"* bên trái nút *"Đồng bộ danh mục"*. Khi bấm hiển thị popup xác nhận đặt lại (quay lại dữ liệu khớp với CSDL) với 2 nút `Hủy` và `Xác nhận đặt lại`. | - Thêm nút "Đặt lại mặc định" vào footer bảng.<br>- Tạo popup xác nhận đặt lại: khi xác nhận, khôi phục `categories` về dữ liệu gốc từ CSDL (`originalCategories`), hủy bỏ toàn bộ bản nháp. |
| **6** | **Nút "Đồng bộ danh mục" & Xác thực mã PIN** | Hiện tại bấm Đồng bộ chỉ hiển thị banner alert xanh xác nhận rồi gọi lại `fetchCategories` | Bỏ banner alert cũ. Hiển thị Popup xác nhận mã PIN với 2 nút `Hủy` và `Xác nhận đồng bộ`. Nhập đúng mã PIN -> Tiến hành cập nhật CSDL và phát socket đồng bộ về client-app. | - Bỏ banner `modals.syncAlert` cũ.<br>- Tạo popup PIN chuyên dụng (hoặc tích hợp SecurityConfirmModal): nhập mã PIN 6 số quản trị viên -> gọi `adminApi.verifySecurityAction({ pin, action: 'SYNC_CATEGORIES' })`.<br>- Khi PIN đúng: Thực thi batch cập nhật các thay đổi nháp vào CSDL qua API backend, phát socket real-time, tải lại dữ liệu mới nhất và xóa trạng thái nháp. |

---

## 🏛️ II. PHÂN TÍCH TÁC ĐỘNG THEO 2 CHIỀU (DUAL-AXIS REASONING)

### 1. Suy luận theo chiều ngang (Horizontal Reasoning)
- **Module Frontend `src/Admin-web`:**
  - `src/Admin-web/src/pages/categories/CategoryPage.jsx`:
    + Tinh chỉnh Header, tinh gọn Modal Thêm/Sửa và Modal Xóa.
    + Thêm state `originalCategories` (dữ liệu CSDL) và `stagedChanges` (bản nháp).
    + Thêm nút `Đặt lại mặc định` và Modal xác nhận Đặt lại.
    + Cải tiến nút `Đồng bộ danh mục` gắn với Modal xác thực mã PIN bảo mật.
  - `src/Admin-web/src/locales/vi.js` & `en.js`:
    + Cập nhật `categories.modal.keywordHint`.
    + Bổ sung translation keys cho `resetBtn`, `resetModal`, `syncModal`, `pinVerification`.
- **Module Backend `src/Backend`:**
  - Endpoint `/admin/verify-security-action` đã sẵn sàng và hoạt động ổn định với kiểm tra băm `account.pin_hash`.
  - Các endpoint `/admin/addcategory`, `/admin/updatecategory/:id`, `/admin/deletecategory/:id` đã có sẵn logic bảo vệ danh mục người dùng, audit log, và phát socket realtime `admin.category_updated`.
  - Không cần sửa đổi cấu trúc CSDL hay phá vỡ API hiện hữu.
- **Module Mobile `src/Client-app`:**
  - Client-app và toàn hệ thống tiếp tục nhận cập nhật đồng bộ real-time thông qua socket và API `/sync/default-categories` sau khi quá trình đồng bộ hoàn tất.

### 2. Suy luận theo chiều sâu (Vertical / Deep-Impact Reasoning)
- **Bảo toàn CSDL & DB Guard (Rule 10):**
  - Không chạy migration, không thay đổi cấu trúc bảng `category` trên Supabase Cloud.
  - Mọi thao tác lưu danh mục vẫn giữ nguyên cơ chế Soft-delete (`delete_at = now()`) và khôi phục khi trùng tên.
- **Trải nghiệm vận hành & An ninh phân quyền (Data Security Rule 9):**
  - Cơ chế bản nháp (Draft/Staging Mode) giúp Admin có thể rà soát toàn bộ cấu hình danh mục trước khi chính thức áp dụng vào hệ thống sản xuất (Production), tránh tình trạng chỉnh sửa lỡ tay gây biến động số liệu người dùng.
  - Cơ chế Re-authentication qua mã PIN bảo mật đảm bảo chỉ người có thẩm quyền cao nhất mới có thể đồng bộ thay đổi danh mục ra toàn bộ hệ thống.
  - Thao tác "Đặt lại mặc định" đóng vai trò là "nút thoát hiểm" (Safety Fallback) giúp Admin nhanh chóng quay về trạng thái an toàn ban đầu nếu bản nháp chưa như ý.

---

## 📋 III. KẾ HOẠCH TRIỂN KHAI CHI TIẾT TỪNG BƯỚC

### 🔹 Giai đoạn 1: Chuẩn hóa Ngôn ngữ & Dịch thuật (i18n)
- [x] **Bước 1.1:** Cập nhật `src/Admin-web/src/locales/vi.js`:
  - Rút gọn `categories.modal.keywordHint`: `"Nhập các từ khóa phân cách bởi dấu phẩy (,)."`
  - Thêm keys cho nút và popup Đặt lại mặc định (`resetBtn`, `resetModal`, `syncModal`, `draftAlerts`).
- [x] **Bước 1.2:** Cập nhật `src/Admin-web/src/locales/en.js`:
  - Rút gọn `categories.modal.keywordHint`: `"Enter comma-separated keywords (,)."`
  - Bổ sung các keys tiếng Anh tương ứng cho `resetBtn`, `resetModal`, `syncModal`, `draftAlerts`.

### 🔹 Giai đoạn 2: Tinh chỉnh Giao diện Header & Các Modals
- [x] **Bước 2.1:** Chỉnh sửa Header trong `CategoryPage.jsx`:
  - Xóa bỏ icon `category`, badge `NLP Keywords Ready`, và dòng subtitle dài.
- [x] **Bước 2.2:** Rút gọn Modal Xác nhận Xóa danh mục:
  - Loại bỏ hoàn toàn khối ghi chú thông tin Soft Delete (khối màu xám).
  - Chỉ giữ lại đúng 1 dòng: `Bạn chắc chắn muốn xóa danh mục "<Tên danh mục>" ?` cùng 2 nút `Hủy` và `Xác nhận xóa`.
- [x] **Bước 2.3:** Bỏ khối banner alert `modals.syncAlert` và delete banner cũ.

### 🔹 Giai đoạn 3: Hiện thực hóa Chế độ Bản Nháp (Draft Mode) & Đặt Lại Mặc Định
- [x] **Bước 3.1:** Quản lý State Bản Nháp trong `CategoryPage.jsx`:
  - `originalCategories`: Danh sách danh mục thuần từ CSDL (snapshot gốc sau khi fetch).
  - `stagedChanges`: Lưu trữ các thao tác nháp `{ added: [], updated: [], deleted: [] }`.
  - Khi Thêm mới: Tạo danh mục mang ID nháp (`draft_${Date.now()}`), thêm vào danh sách hiển thị, ghi vào `stagedChanges.added`.
  - Khi Chỉnh sửa: Cập nhật thông tin trên danh mục trong danh sách hiển thị, ghi vào `stagedChanges.updated`.
  - Khi Xóa: Đánh dấu `status: 'deleted'` trong danh sách hiển thị, ghi vào `stagedChanges.deleted`.
- [x] **Bước 3.2:** Thêm nút "Đặt lại mặc định" và Popup Xác nhận:
  - Đặt cạnh trái nút "Đồng bộ danh mục" ở thanh điều hướng dưới bảng.
  - Khi bấm: Mở popup xác nhận đặt lại với 2 nút `Hủy` và `Xác nhận đặt lại`.
  - Khi bấm `Xác nhận đặt lại`: Revert `categories` về `originalCategories`, reset `stagedChanges` về rỗng.

### 🔹 Giai đoạn 4: Popup Xác nhận Mã PIN & Thực thi Đồng bộ vào CSDL
- [x] **Bước 4.1:** Xây dựng Popup Xác nhận Mã PIN:
  - Khi bấm "Đồng bộ danh mục": Mở popup nhập mã PIN 6 số với 2 nút `Hủy` và `Xác nhận đồng bộ`.
- [x] **Bước 4.2:** Xử lý logic Xác thực & Commit CSDL:
  - Kiểm tra mã PIN qua API `adminApi.verifySecurityAction({ pin, action: 'SYNC_CATEGORIES' })`.
  - Nếu PIN sai: Hiển thị thông báo lỗi trực tiếp trên popup.
  - Nếu PIN đúng:
    + Thực thi commit lần lượt các bản ghi trong `stagedChanges` (gọi `adminApi.createCategory`, `updateCategory`, `deleteCategory`).
    + Gọi `fetchCategories()` tải lại dữ liệu mới nhất từ CSDL làm snapshot gốc mới.
    + Reset `stagedChanges`.
    + Đóng popup mã PIN và hiển thị Toast thành công.

### 🔹 Giai đoạn 5: Kiểm thử 2 Tầng (2-Tier Testing Architecture - Rule 11) & Build Verification
- [x] **Bước 5.1:** Viết test suite 2 tầng `src/Admin-web/src/tests/categories.refinement.2tier.test.jsx`:
  - **Tầng 1 (UI Rendering & Interaction):**
    + Header sạch sẽ (không còn icon `category`, không còn badge `NLP Keywords Ready`, không còn subtitle).
    + Modal Thêm/Sửa: Dòng gợi ý keyword đã được rút gọn đúng yêu cầu.
    + Modal Xóa: Chỉ hiển thị 1 câu hỏi và 2 nút bấm, không còn khối ghi chú Soft Delete.
    + Footer: Nút "Đặt lại mặc định" nằm bên trái nút "Đồng bộ danh mục".
  - **Tầng 2 (Real System Impact & Behavioral Verification):**
    + Thêm danh mục mới: Danh mục xuất hiện trên bảng nhưng `adminApi.createCategory` CHƯA ĐƯỢC GỌI (lưu nháp).
    + Bấm "Đặt lại mặc định" -> Xác nhận: Danh mục nháp biến mất, dữ liệu khôi phục đúng CSDL gốc.
    + Thao tác Thêm/Sửa/Xóa trong bản nháp -> Bấm "Đồng bộ danh mục" -> Nhập sai mã PIN -> Bị chặn, không gọi API CSDL.
    + Nhập đúng mã PIN -> Bấm "Xác nhận đồng bộ" -> `adminApi.verifySecurityAction` được gọi -> Các API lưu CSDL (`createCategory`, `updateCategory`, `deleteCategory`) được thực thi chính xác -> Danh sách CSDL được đồng bộ.
- [x] **Bước 5.2:** Cập nhật lại `src/Admin-web/src/tests/categories.page.test.jsx` tương thích với luồng bản nháp mới (6/6 tests pass).
- [x] **Bước 5.3:** Chạy toàn bộ test suites (`rtk npm test` - 39/39 files pass, 287/287 tests pass).
- [x] **Bước 5.4:** Kiểm tra production build (`rtk npm run build` - 0 lỗi, 3.19s).
- [x] **Bước 5.5:** Cập nhật `Project.md` và rebuild CodeGraph (`rtk npx codegraph build`) theo Rule 8.

---

## 🧪 IV. TIÊU CHÍ NGHIỆM THU 2 TẦNG (2-TIER ACCEPTANCE CRITERIA)

### 🧱 TẦNG 1: HIỂN THỊ & THAO TÁC GIAO DIỆN (UI Rendering)
1. **Header:** Không còn icon `category`, không còn badge `NLP Keywords Ready`, không còn subtitle dài.
2. **Modal Thêm/Sửa:** Dòng ghi chú keyword hiển thị: *"Nhập các từ khóa phân cách bởi dấu phẩy (,)."* (không còn vế giải thích AI).
3. **Modal Xóa:** Giao diện tối giản, chỉ có 1 dòng xác nhận *"Bạn chắc chắn muốn xóa danh mục "<Tên danh mục>" ?"* và 2 nút `Hủy`, `Xác nhận xóa`.
4. **Vị trí nút:** Nút *"Đặt lại mặc định"* nằm bên trái nút *"Đồng bộ danh mục"*.
5. **Popup Đặt lại & Popup Đồng bộ:** Hiển thị đúng 2 nút theo yêu cầu của PO.

### ⚡ TẦNG 2: TÁC ĐỘNG HỆ THỐNG THỰC TẾ (System Impact & Behavioral Verification)
1. **Lưu Nháp (Draft Mode):** Khi thêm, sửa, xóa danh mục trên giao diện, dữ liệu chưa được ghi vào CSDL (chưa gọi API backend).
2. **Hủy Nháp (Reset):** Khi xác nhận "Đặt lại mặc định", toàn bộ dữ liệu trên bảng khôi phục 100% khớp với CSDL hiện tại.
3. **Bảo Mật Mã PIN (Re-authentication):** Bắt buộc nhập mã PIN 6 số mới được phép đồng bộ. Nhập sai PIN hệ thống chặn đứng, không lưu CSDL.
4. **Đồng Bộ Hoàn Toàn (Database & Realtime):** Nhập đúng mã PIN và xác nhận, hệ thống lưu toàn bộ thay đổi vào CSDL và phát socket đồng bộ tới client-app, sau đó cập nhật lại snapshot dữ liệu mới.
5. **Zero Regressions:** Các chức năng tìm kiếm, phân trang, lọc theo loại Thu/Chi/Vay nợ vẫn hoạt động trơn tru 100%.

---

> ⚠️ **Cam kết:** Kế hoạch tuân thủ tuyệt đối Quy tắc Tối cao 1 (Chờ PO duyệt trước khi code), Quy tắc Tối cao 2 (Suy luận ngang - sâu), DB Guard Rule 10, Data Security Rule 9 và Kiểm thử 2 Tầng Rule 11.
