# 📋 KẾ HOẠCH CHI TIẾT TINH CHỈNH TRANG PHÂN QUYỀN DỊCH VỤ (SERVICE PERMISSIONS)
> **Tài liệu nguồn sự thật phục vụ thực thi:** `docs/Permissions/SERVICE_PERMISSIONS_REFINEMENT_PLAN.md`  
> **Ngày lập:** 2026-10-22  
> **Tác giả:** AI Assistant (Lead BA + Lead FullStack + Lead Tester)  
> **Người duyệt:** Product Owner (PO)  
> **Trạng thái:** ✅ ĐÃ ĐƯỢC PO PHÊ DUYỆT & TRIỂN KHAI HOÀN TẤT 100% (All 2-Tier Tests Passed & Verified)

---

## 🎯 1. BỐI CẢNH & KHẢO SÁT CHI TIẾT CÁC ISSUE LOG TỪ PO

Qua khảo sát toàn diện mã nguồn tại module **Admin-web** (`src/Admin-web`), bản chất kỹ thuật của các issue log tại trang Phân quyền được xác định chính xác như sau:

### 🔴 ISSUE 1: Menu Điều Hướng (Sidebar Navigation)
- **Hiện trạng:** Tại [`src/Admin-web/src/locales/vi.js`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Admin-web/src/locales/vi.js) dòng 73: `nav.permissions` đang hiển thị nhãn `"Phân quyền gói cước"`.
- **Yêu cầu PO:** Đổi tên menu từ `"Phân Quyền Gói Cước"` thành `"Phân quyền dịch vụ"`.
- **Tác động kỹ thuật:** Cập nhật `nav.permissions` trong `vi.js` thành `'Phân quyền dịch vụ'` và trong `en.js` thành `'Service Permissions'`. [`Sidebar.jsx`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Admin-web/src/components/layout/Sidebar.jsx) tự động phản ánh tên mới.

### 🔴 ISSUE 2: Header Trang Phân Quyền
- **Hiện trạng:**
  1. Đang có icon wrapper `<span className="material-symbols-outlined text-[18px]">admin_panel_settings</span>`.
  2. Tiêu đề đang là: `"Phân Quyền Gói Cước — Ma Trận Phân Quyền Động & Real-Time"`.
  3. Có dòng mô tả phụ dài: `"Thiết lập hạn mức tài nguyên (LIMIT) và bật/tắt chức năng (TOGGLE) theo gói tài khoản. Đồng bộ tức thì tới Client-app qua Socket.IO."`.
  4. Nút tab đầu tiên trong bộ lọc chế độ xem gói cước đang hiển thị `"Đối Chiếu 2 Gói"`.
  5. Có nút `"Làm mới"` (`data-testid="btn-refresh"`).
- **Yêu cầu PO:**
  1. **Bỏ icon `"admin_panel_settings"`:** Xóa bỏ icon wrapper tại đầu header.
  2. **Thay tiêu đề:** Đổi thành `"Phân quyền dịch vụ"` (Tiếng Anh: `"Service Permissions"`).
  3. **Bỏ dòng mô tả:** Loại bỏ hoàn toàn dòng subtitle mô tả dài dòng bên dưới tiêu đề để giao diện gọn gàng.
  4. **Đổi tên nút bộ lọc gói:** Đổi `"Đối Chiếu 2 Gói"` thành `"Tất cả"` (Tiếng Anh: `"All Tiers"`).
  5. **Bỏ nút `"Làm mới"`:** Xóa bỏ nút này khỏi thanh công cụ (dữ liệu đã được tự động nạp khi vào trang và cập nhật tức thì qua Socket.IO `account.permissions_updated`).

### 🔴 ISSUE 3: Các Tab Tính Năng & Chức Năng (Bảng Ma Trận Phân Quyền)
- **Hiện trạng:**
  - Tại [`PermissionMatrixTable.jsx`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Admin-web/src/pages/system/components/PermissionMatrixTable.jsx): Ở cả chế độ xem đối chiếu (`viewMode === 'ALL'`) và chế độ đơn gói (`viewMode === 'Basic' | 'Premium'`), bên dưới Tên tính năng (`f.name`) và badge loại chức năng (`LIMIT` / `TOGGLE`) đang in ra:
    + Thẻ `<code>{f.id}</code>` (ví dụ: `anomaly_spending_insights`).
    + Dòng thẻ `<span>{f.description}</span>` (ví dụ: `Phát hiện và cảnh báo các khoản chi tiêu đột biến bất thường so với lịch sử`).
- **Yêu cầu PO:**
  - **Bỏ các dòng ghi chú phía dưới tên và loại chức năng:** Loại bỏ hoàn toàn `f.id` và `f.description` ở cột 1. Cột này sẽ chỉ hiển thị: Tên tính năng (`f.name`) và badge loại chức năng (`LIMIT` / `TOGGLE`).
  - Giao diện bảng ma trận sẽ trở nên cực kỳ thoáng đãng, mật độ dữ liệu tinh giản đúng chuẩn Linear/Stripe.

---

## 🛠️ 2. PHÂN TÍCH 2 CHIỀU (DUAL-AXIS REASONING)

### 2.1. Suy Luận Chiều Ngang (Horizontal Reasoning):
- **Giao diện & Trải nghiệm (UI/UX):**
  - Đồng bộ nhận diện thuật ngữ toàn hệ thống: Chuyển từ khái niệm "Gói cước" thuần túy sang **"Phân quyền dịch vụ"** bao quát hơn.
  - Header và bảng dữ liệu trở nên thanh thoát, không còn các chi tiết thừa thãi (icon trùng lặp, mô tả rườm rà, mã code kĩ thuật lộ ra ngoài bảng danh sách).
- **Tính tương thích hệ thống & Socket Realtime:**
  - Logic phân quyền 4 Trụ Cột (`Access`, `Quota`, `Scope`, `Downgrade Policy`) bên trong CSDL PostgreSQL (`account_type_permission`, `feature`) và API Backend (`PUT /admin/permissions`, `GET /admin/permissions`) **hoàn toàn giữ nguyên 100% tính toàn vẹn**, không bị ảnh hưởng.
  - Bộ lọc tìm kiếm (`search`) vẫn hỗ trợ tìm kiếm linh hoạt theo cả tên tính năng và mã định danh ngầm (`f.id.toLowerCase().includes(term)`), đảm bảo Admin gõ `anomaly` vẫn tìm ra tính năng tương ứng dù UI không in mã ra màn hình.
- **Tương thích Đa Ngôn Ngữ (i18n):**
  - Cập nhật đồng bộ cả 2 bộ từ điển Tiếng Việt (`vi.js`) và Tiếng Anh (`en.js`) cho Menu, Header và Toolbar.

### 2.2. Suy Luận Chiều Sâu (Vertical / Deep-Impact Reasoning):
- **Toàn vẹn Dữ liệu & Triggers:** Không can thiệp vào schema hay triggers CSDL, không vi phạm DB Guard (Rule 10).
- **Hệ thống Kiểm thử (Regression Tests):**
  - Rà soát các bộ test hiện tại:
    + [`permission.4pillars.page.test.jsx`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Admin-web/src/tests/permission.4pillars.page.test.jsx)
    + [`permission.page.test.jsx`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Admin-web/src/tests/permission.page.test.jsx)
    + [`language.system.test.jsx`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Admin-web/src/tests/language.system.test.jsx)
  - Cập nhật các assertions cũ (đổi text mong đợi từ `"Phân Quyền Gói Cước"` sang `"Phân quyền dịch vụ"`, `"Đối Chiếu 2 Gói"` sang `"Tất cả"`, kiểm tra `btn-refresh` không còn hiện diện).
  - Viết bộ test 2 tầng chuyên biệt mới [`permission.refinement.service.2tier.test.jsx`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Admin-web/src/tests/permission.refinement.service.2tier.test.jsx) bảo đảm Zero Regressions.

---

## 📝 3. KẾ HOẠCH TRIỂN KHAI CHI TIẾT (4 BƯỚC)

### Bước 1: Cập Nhật Ngôn Ngữ & Từ Điển Nguồn Sự Thật (`vi.js` & `en.js`)
1. **Tại `src/Admin-web/src/locales/vi.js`:**
   - `nav.permissions`: đổi thành `'Phân quyền dịch vụ'`.
   - `permissions.title`: đổi thành `'Phân quyền dịch vụ'`.
   - `permissions.subtitle`: để rỗng `''` hoặc bỏ.
   - `permissions.toolbar.viewAll`: đổi thành `'Tất cả'`.
   - `permissions.feedback.saveSuccessTitle`: đổi thành `'Phân quyền dịch vụ'`.
2. **Tại `src/Admin-web/src/locales/en.js`:**
   - `nav.permissions`: đổi thành `'Service Permissions'`.
   - `permissions.title`: đổi thành `'Service Permissions'`.
   - `permissions.subtitle`: để rỗng `''` hoặc bỏ.
   - `permissions.toolbar.viewAll`: đổi thành `'All Tiers'`.
   - `permissions.feedback.saveSuccessTitle`: đổi thành `'Service Permissions'`.

### Bước 2: Tinh Chỉnh Giao Diện Header & Toolbar (`PermissionFilterToolbar.jsx`)
1. **Bỏ icon `"admin_panel_settings"`:** Xóa wrapper icon tại đầu Header.
2. **Tiêu đề trang:** Hiển thị `{t('permissions.title', 'Phân quyền dịch vụ')}`.
3. **Bỏ subtitle:** Xóa thẻ `<p className="text-[11px] text-slate-500 ...">` hiển thị mô tả.
4. **Đổi tên nút bộ lọc gói:** Tab `ALL` hiển thị `{t('permissions.toolbar.viewAll', 'Tất cả')}`.
5. **Bỏ nút `"Làm mới"`:** Xóa nút `<button data-testid="btn-refresh" ...>` khỏi thanh công cụ.

### Bước 3: Tinh Chỉnh Bảng Ma Trận Tính Năng (`PermissionMatrixTable.jsx`)
1. **Tại chế độ đơn gói (`!isSubRow`, dòng 87-107):**
   - Giữ lại: `f.name` và badge `isLimitType ? 'LIMIT' : 'TOGGLE'`.
   - Xóa bỏ: `<code className="text-[10px] ...">{f.id}</code>` và `{f.description && <span ...>{f.description}</span>}`.
2. **Tại chế độ đối chiếu cả 2 gói (`viewMode === 'ALL'`, dòng 309-332):**
   - Giữ lại: `f.name` và badge `isLimitType ? 'LIMIT' : 'TOGGLE'`.
   - Xóa bỏ: `<code className="text-[10px] ...">{f.id}</code>` và `{f.description && <span ...>{f.description}</span>}`.

### Bước 4: Kiểm Thử 2 Tầng (Rule 11) & Cập Nhật Nguồn Sự Thật
1. Tạo file test 2 tầng mới [`src/Admin-web/src/tests/permission.refinement.service.2tier.test.jsx`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Admin-web/src/tests/permission.refinement.service.2tier.test.jsx):
   - **Tầng 1 (Giao diện & Hiển thị):**
     + Kiểm tra Menu hiển thị `"Phân quyền dịch vụ"`.
     + Kiểm tra Header không còn icon `"admin_panel_settings"`.
     + Kiểm tra Header chỉ hiển thị `"Phân quyền dịch vụ"`, không còn dòng subtitle mô tả.
     + Kiểm tra nút lọc gói hiển thị `"Tất cả"` (hoặc `"All Tiers"` khi EN).
     + Kiểm tra không còn nút `"Làm mới"` trên toolbar.
     + Kiểm tra cột Tính năng chỉ hiển thị Tên và Badge loại chức năng, không còn mã định danh (`f.id`) hay mô tả (`f.description`).
   - **Tầng 2 (Tác động Hệ thống Thực tế):**
     + Tìm kiếm ngầm qua mã định danh vẫn hoạt động trơn tru.
     + Thao tác chuyển tab `"Tất cả"`, `"Gói Basic"`, `"Gói Premium"` hoạt động chính xác.
     + Thao tác chỉnh sửa 4 trụ cột và Lưu Thay Đổi vẫn gửi payload đầy đủ tới API `PUT /admin/permissions`.
2. Cập nhật các bài test hồi quy liên quan và chạy toàn bộ test suite.
3. Cập nhật `Project.md` và chạy `rtk npx codegraph build`.

---

## 🛡️ 4. BẢNG TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA)

| STT | Hạng mục kiểm thử | Tiêu chuẩn nghiệm thu chi tiết | Trạng thái |
|:---:|---|---|:---:|
| 1 | **Menu Sidebar** | Đổi thành công nhãn menu thành **"Phân quyền dịch vụ"** (Tiếng Anh: **"Service Permissions"**) | ⏳ Chờ PO duyệt |
| 2 | **Icon Header** | **Loại bỏ hoàn toàn icon `"admin_panel_settings"`** ở đầu tiêu đề trang | ⏳ Chờ PO duyệt |
| 3 | **Tiêu đề Header** | Thay `"Phân Quyền Gói Cước — Ma Trận Phân Quyền Động & Real-Time"` thành **"Phân quyền dịch vụ"** | ⏳ Chờ PO duyệt |
| 4 | **Subtitle Header** | **Loại bỏ hoàn toàn dòng mô tả phụ** dưới tiêu đề | ⏳ Chờ PO duyệt |
| 5 | **Bộ lọc gói cước** | Đổi tên nút tab `"Đối Chiếu 2 Gói"` thành **"Tất cả"** (Tiếng Anh: **"All Tiers"**) | ⏳ Chờ PO duyệt |
| 6 | **Nút Làm mới** | **Loại bỏ hoàn toàn nút "Làm mới"** khỏi thanh công cụ | ⏳ Chờ PO duyệt |
| 7 | **Cột Tính năng bảng ma trận** | **Loại bỏ hoàn toàn mã định danh (vd: `anomaly_spending_insights`) và dòng mô tả** phía dưới tên tính năng và badge chức năng | ⏳ Chờ PO duyệt |
| 8 | **Kiểm thử 2 Tầng (Rule 11)** | Test suites Tầng 1 (UI) & Tầng 2 (System Impact) **PASS 100% - Zero Regressions** | ⏳ Chờ PO duyệt |

---

> ⚠️ **Kính trình Product Owner (PO) xem xét và phê duyệt bản kế hoạch trên để tiến hành triển khai ngay lập tức.**
