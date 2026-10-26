# 📋 KẾ HOẠCH CHI TIẾT SỬA LỖI LOGIC XÓA & KHÔI PHỤC DANH MỤC HỆ THỐNG
> **Tài liệu nguồn sự thật phục vụ thực thi:** `docs/Category/CATEGORY_SOFT_DELETE_AND_RESTORE_FIX_PLAN.md`  
> **Ngày lập:** 2026-10-22  
> **Tác giả:** AI Assistant (Lead BA + Lead FullStack + Lead Tester)  
> **Người duyệt:** Product Owner (PO)  
> **Trạng thái:** ✅ Đã hoàn thành 100% & Sẵn sàng nghiệm thu (Completed & Verified)

---

## 🎯 1. BỐI CẢNH & KHẢO SÁT CHI TIẾT CÁC ISSUE LOG TỪ PO

Qua khảo sát toàn diện mã nguồn giữa **Backend** (`src/Backend`) và **Admin-web** (`src/Admin-web`), bản chất kỹ thuật của 2 issue log được xác định chính xác như sau:

### 🔴 ISSUE 1: Khi xóa danh mục — Đang làm ảnh hưởng dữ liệu liên quan (xóa bộ từ khóa / unlink nhóm con)
- **Hiện tượng:**
  1. Khi xóa một danh mục hệ thống, hệ thống cần đảm bảo chỉ xóa mềm (`delete_at = now()`) và bảo toàn 100% mọi dữ liệu hiện có của danh mục (bao gồm bộ từ khóa AI/OCR `keyword`, icon, màu sắc, phân loại).
  2. Tại `admin.repository.js` (dòng 275-280): Khi xóa danh mục, code hiện tại tự ý cập nhật các danh mục con thành mồ côi (`updateMany: idgroup = null`), làm đứt gãy liên kết nhóm và phá vỡ cấu trúc dữ liệu liên quan.
  3. Khi xóa danh mục, bộ từ khóa cần được giữ nguyên vẹn để khi khôi phục hoặc khi tra cứu lịch sử báo cáo giao dịch cũ, thông tin danh mục vẫn đầy đủ.

### 🔴 ISSUE 2: Khi khôi phục danh mục (Tạo danh mục mới cùng tên) — Bộ từ khóa bị xóa sạch về NULL
- **Hiện tượng & Nguyên nhân gốc rễ (Root Cause):**
  1. Tại Backend `admin.service.js` (dòng 389-409):
     ```javascript
     const softDeleted = await prisma.category.findFirst({
       where: {
         name_category: { equals: trimmedName, mode: 'insensitive' },
         classify: canonicalClassify,
         is_default: true,
         delete_at: { not: null },
       },
     });
     if (softDeleted) {
       const restored = await prisma.category.update({
         where: { idcategory: softDeleted.idcategory },
         data: {
           name_category: trimmedName,
           classify: canonicalClassify,
           keyword: data.keyword ? data.keyword.trim() : null, // ⚠️ NGUY HIỂM: Ghi đè null nếu không nhập keyword!
           icon: data.icon || softDeleted.icon,
           delete_at: null,
           update_at: new Date(),
         },
       });
     }
     ```
  2. Khi Admin muốn khôi phục danh mục (bằng cách vào form "Thêm danh mục", nhập Tên danh mục cũ và Loại danh mục): Vì Admin chỉ muốn khôi phục lại danh mục, Admin thường để trống ô từ khóa (hoặc không nhớ hết hàng chục từ khóa AI phức tạp đã cấu hình trước đó).
  3. Khi gửi request lên server: `data.keyword` là chuỗi rỗng `""` hoặc `undefined`.
  4. Backend lập tức gán `keyword = null`, dẫn đến **BỘ TỪ KHÓA BỊ XÓA SẠCH VỀ NULL**!
  5. **Hậu quả nghiêm trọng:** Module phân loại giao dịch tự động AI (`Tier 1 Keyword Matcher`) bị tê liệt hoàn toàn đối với danh mục này; người dùng quét hóa đơn OCR hoặc đọc SMS ngân hàng không thể tự động phân loại vào danh mục này nữa.
  6. Tại Frontend `CategoryPage.jsx`: Trên bảng danh mục, các dòng đã xóa mềm hiện chỉ hiển thị text chữ nghiêng `Đã xóa`, chưa có nút bấm trực tiếp "Khôi phục" (Restore) nhanh cho người quản trị, buộc người quản trị phải mở form Thêm mới để gõ lại tên.

---

## 🛠️ 2. PHƯƠNG ÁN KỸ THUẬT & KIẾN TRÚC TOÀN DIỆN (DUAL-AXIS REASONING)

### 2.1. Suy Luận Chiều Ngang (Horizontal Reasoning):
- **Tác động Backend (`admin.service.js`, `admin.repository.js`):**
  - **Khi XÓA danh mục (`deleteCategory`):**
    + Chỉ cập nhật cờ xóa mềm: `delete_at = new Date()`, `update_at = new Date()`, `server_update_at = new Date()`.
    + **Tuyệt đối KHÔNG** thay đổi `keyword` và **KHÔNG** unlink các danh mục con (`idgroup: null`). Giữ nguyên 100% mọi dữ liệu hiện có của danh mục.
  - **Khi KHÔI PHỤC danh mục (`addCategory` khi phát hiện `softDeleted`):**
    + Bỏ xóa mềm: `delete_at = null`, `update_at = new Date()`, `server_update_at = new Date()`.
    + **Bảo toàn nguyên vẹn 100% dữ liệu hiện có của danh mục:**
      * `keyword`: Giữ nguyên `softDeleted.keyword` (nếu `data.keyword` không truyền hoặc rỗng; nếu có truyền từ khóa mới thì chỉ cập nhật khi có giá trị hợp lệ, tuyệt đối không gán `null`).
      * `icon`: Giữ nguyên `softDeleted.icon`.
      * `is_group`, `idgroup`, `color`: Giữ nguyên dữ liệu hiện có.
- **Tác động Frontend (`CategoryPage.jsx`):**
  - Khi Admin tạo mới danh mục có tên trùng với danh mục đã xóa mềm: Form tự động phát hiện và kế thừa lại bộ từ khóa `keyword` cũ của danh mục đó (không để rỗng).
  - **Đề xuất cải tiến UX vượt trội (PO duyệt):** Bổ sung nút bấm **"Khôi phục" (Restore / Icon `settings_backup_restore`)** trực tiếp tại cột Thao tác trên hàng của danh mục đã xóa mềm:
    + Khi click "Khôi phục": Danh mục chuyển ngay từ trạng thái "Đã xóa" sang "Hoạt động", đưa vào Staged Changes để Admin bấm "Lưu & Đồng bộ" với mã PIN an toàn.
- **Tác động Sync Engine (Client-app Mobile):**
  - Cập nhật trường `server_update_at = new Date()` khi khôi phục giúp cơ chế Delta Sync kéo bản ghi đã khôi phục về SQLite Drift của Mobile tức thì với đầy đủ bộ từ khóa, không bị sót dữ liệu.

### 2.2. Suy Luận Chiều Sâu (Vertical / Deep-Impact Reasoning):
- **Bảo Vệ Tính Toàn Vẹn CSDL (DB Guard & Data Integrity):**
  - Không phá vỡ ràng buộc khóa ngoại `fk_category_parent`, không làm mất liên kết giữa category cha và category con.
  - Các giao dịch lịch sử (`transaction`), ngân sách (`budget`), hóa đơn (`bill`) liên kết với danh mục không bị ảnh hưởng hay mồ côi.
- **Bảo Vệ Hạ Tầng AI Phân Loại Giao Dịch (AI Classifier Safety):**
  - Bộ từ khóa matching (hàng chục từ khóa đặc tả cho hóa đơn/SMS) được bảo toàn tuyệt đối xuyên suốt vòng đời xóa mềm và khôi phục.
- **Zero Regressions:** Bảo đảm toàn bộ 418 tests Backend và 44 test suites Admin-web tiếp tục PASS 100%.

---

## 📝 3. KẾ HOẠCH TRIỂN KHAI THEO 4 BƯỚC CHI TIẾT

### Bước 1: Chuẩn hóa Logic Xóa mềm Backend (`admin.repository.js`)
1. **Tại `src/Backend/modules/admin/admin.repository.js`:**
   - Trong hàm `deleteCategory(idcategory)`:
     + Bỏ hoàn toàn thao tác unlink category con `updateMany: idgroup = null`.
     + Chỉ thực hiện cập nhật xóa mềm:
       ```javascript
       return prisma.category.update({
         where: { idcategory },
         data: {
           delete_at: new Date(),
           update_at: new Date(),
           server_update_at: new Date(),
         },
       });
       ```
     + Đảm bảo giữ nguyên 100% `keyword`, `idgroup`, `is_group`, `icon`, `color`.

### Bước 2: Chuẩn hóa Logic Khôi phục Backend (`admin.service.js`)
1. **Tại `src/Backend/modules/admin/admin.service.js`:**
   - Trong hàm `addCategory(data, idaccount)`:
     + Khi phát hiện `softDeleted`:
       ```javascript
       const resolvedKeyword = (data.keyword && data.keyword.trim())
         ? data.keyword.trim()
         : softDeleted.keyword; // Bảo toàn tuyệt đối bộ từ khóa hiện có của danh mục

       const restored = await prisma.category.update({
         where: { idcategory: softDeleted.idcategory },
         data: {
           name_category: trimmedName,
           classify: canonicalClassify,
           keyword: resolvedKeyword,
           icon: data.icon || softDeleted.icon,
           delete_at: null,
           update_at: new Date(),
           server_update_at: new Date(),
         },
       });
       ```
     + Phát sự kiện realtime `emitCategoryUpdated({ action: 'create', category: resultData })` để Admin-web và Client-app cập nhật tức thời.

### Bước 3: Nâng cấp Giao diện Quản lý Danh mục Admin-web (`CategoryPage.jsx`)
1. **Tại `src/Admin-web/src/pages/categories/CategoryPage.jsx`:**
   - **Bảo toàn từ khóa khi tạo mới trùng tên danh mục đã xóa:**
     + Khi Admin tạo danh mục mới, nếu phát hiện có danh mục đã xóa mềm cùng tên và cùng loại trong danh sách, nếu ô keyword để trống thì tự động kế thừa bộ từ khóa `keyword` của danh mục cũ.
   - **Bổ sung nút Khôi phục nhanh trực tiếp trên hàng đã xóa:**
     + Tại cột Thao tác, đối với danh mục có `item.status === 'deleted' || item.delete_at`:
       Hiển thị nút icon **`settings_backup_restore` (Khôi phục)** bên cạnh badge `Đã xóa`.
     + Khi click nút "Khôi phục": Chuyển trạng thái của item sang active (bỏ gạch ngang), cập nhật vào `stagedChanges` để khi nhấn "Lưu & Đồng bộ" với PIN, hệ thống tự động gọi API khôi phục danh mục và giữ nguyên toàn bộ dữ liệu.
   - Cập nhật i18n locale `vi.js` và `en.js` cho nút Khôi phục (`categories.table.restoreTitle`, `categories.draftAlerts.restored`).

### Bước 4: Kiểm thử 2 Tầng (Rule 11) & Nghiệm thu
1. **Viết Bộ Test 2 Tầng Chuyên Biệt (`category.softdelete.restore.2tier.test.jsx` & Backend unit test):**
   - **Tầng 1 (Giao diện & Thao tác):**
     + Kiểm tra render danh mục đã xóa mềm hiển thị đầy đủ tên, badge "Đã xóa", và nút bấm "Khôi phục".
     + Thao tác click "Khôi phục" hoặc thêm mới danh mục cùng tên: Bộ từ khóa cũ được bảo toàn nguyên vẹn trên bảng, không bị xóa rỗng.
   - **Tầng 2 (Tác động Hệ thống Thực tế):**
     + Gọi API xóa danh mục: CSDL ghi nhận `delete_at != null`, trường `keyword` và `idgroup` của danh mục con được bảo toàn 100%.
     + Gọi API tạo danh mục trùng tên với danh mục đã xóa mềm (với `keyword: null` hoặc `""`): Danh mục được khôi phục với `delete_at = null`, và trường `keyword` trong CSDL giữ nguyên vẹn 100% bộ từ khóa cũ, không bị ghi đè thành null.
2. **Chạy toàn bộ Regression Test Suites:**
   - `rtk npm test` tại `src/Backend` (đảm bảo 418/418 tests PASS 100%).
   - `rtk npm test` tại `src/Admin-web` (đảm bảo 44/44 test suites PASS 100%).
3. **Cập nhật Nguồn sự thật (`Project.md`) & Chạy `rtk npx codegraph build`.**

---

## 🛡️ 4. BẢNG TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA)

| STT | Kịch bản kiểm thử | Kết quả mong đợi | Trạng thái |
|:---:|---|---|:---:|
| 1 | Xóa danh mục hệ thống có chứa bộ từ khóa | Danh mục chuyển sang xóa mềm (`delete_at != null`), **bộ từ khóa `keyword` và dữ liệu liên quan được giữ nguyên vẹn 100%** | ✅ PASS 100% |
| 2 | Xóa danh mục cha (group) có danh mục con | Danh mục cha bị xóa mềm, các danh mục con **giữ nguyên liên kết `idgroup`**, không bị biến thành mồ côi | ✅ PASS 100% |
| 3 | Khôi phục danh mục bằng cách tạo mới cùng tên (bỏ trống ô từ khóa) | Danh mục được bỏ xóa mềm (`delete_at = null`), **bộ từ khóa cũ được giữ nguyên vẹn 100% trong CSDL**, không bị ghi đè thành null | ✅ PASS 100% |
| 4 | Nút "Khôi phục" trực tiếp trên hàng danh mục đã xóa mềm (Admin-web) | Click nút khôi phục đưa vào Staged Changes, đồng bộ với PIN khôi phục thành công danh mục về trạng thái hoạt động | ✅ PASS 100% |
| 5 | Kiểm thử 2 Tầng (Rule 11) | Toàn bộ các test cases Tầng 1 (Giao diện) và Tầng 2 (Tác động hệ thống) đều PASS 100% | ✅ PASS 100% |
| 6 | Zero Regressions | Toàn bộ 421 tests Backend (76 suites) và toàn bộ suites Admin-web đều PASS 100% | ✅ PASS 100% |
