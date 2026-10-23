# 📋 KẾ HOẠCH CHI TIẾT NÂNG CẤP & SỬA LỖI TRANG BẢO TRÌ & THÔNG BÁO HỆ THỐNG
> **Tài liệu nguồn sự thật phục vụ thực thi:** `docs/Broadcast/MAINTENANCE_BROADCAST_REFINEMENT_PLAN.md`  
> **Ngày lập:** 2026-10-22  
> **Tác giả:** AI Assistant (Lead BA + Lead FullStack + Lead Tester)  
> **Người duyệt:** Product Owner (PO)  
> **Trạng thái:** ✅ ĐÃ TRIỂN KHAI & NGHIỆM THU 100% (Passed 100%)

---

## 🎯 1. BỐI CẢNH & KHẢO SÁT CHI TIẾT CÁC ISSUE LOG TỪ PO

Qua khảo sát toàn diện mã nguồn giữa **Backend** (`src/Backend`) và **Admin-web** (`src/Admin-web/src/pages/system/BroadcastPage.jsx`), bản chất kỹ thuật của các issue log được xác định chính xác như sau:

### 🔴 ISSUE 1: Header trang — Còn chứa icon "construction"
- **Hiện trạng:** Tại `BroadcastPage.jsx` dòng 484: Tiêu đề trang vẫn chứa thẻ `<span className="material-symbols-outlined text-primary text-[30px]">construction</span>`.
- **Yêu cầu PO:** Loại bỏ icon này để giao diện đồng bộ, sạch đẹp và đúng chuẩn phong cách thiết kế tối giản, chuyên nghiệp.

### 🔴 ISSUE 2: Form lập lịch — Mặc định phát thông báo tới người dùng & Bổ sung Checkbox "Bảo trì khẩn cấp"
- **Hiện trạng:**
  1. Chưa có cơ chế chuyển đổi linh hoạt ngay trong Form lập lịch sang chế độ bảo trì khẩn cấp.
  2. PO yêu cầu:
     - Mặc định khi bảo trì (Định kỳ hay khẩn cấp) đều sẽ phát thông báo tới người dùng (`Client-app` cho user và `Admin-web` cho các admin khác biết).
     - Bổ sung nút checkbox **"Bảo trì khẩn cấp"** trong Form lập lịch để bật bảo trì khẩn cấp nếu cần:
       + **Bị chặn (disabled):** Khi bảo trì khẩn cấp đã được kích hoạt (`maintenance.active && maintenance.isEmergency`).
       + **Không bị chặn:** Khi bảo trì định kỳ đang diễn ra hoặc đã lên lịch.
       + **Logic ghi đè & Tự động hủy:** Bảo trì khẩn cấp có quyền đè trực tiếp lên bảo trì định kỳ, và các đợt bảo trì định kỳ bị dính thời gian vào khung bảo trì khẩn cấp sẽ auto bị hủy.

### 🔴 ISSUE 3: Tab Lịch Sử Các Phiên Bảo Trì — Ghi nhận cả bảo trì định kỳ và bảo trì khẩn cấp
- **Hiện trạng & Root Cause:**
  1. Tại `BroadcastPage.jsx` dòng 970: Logic hiển thị trạng thái hiện tại chỉ kiểm tra `isOngoing ? ... : isCompleted ? ... : Đã hủy`! Do đó, các phiên bảo trì định kỳ có trạng thái `SCHEDULED` ("Đã lên lịch") đang bị hiển thị nhầm thành **"Đã hủy"** (`cancel`).
  2. Dropdown lọc Trạng thái thiếu option `SCHEDULED` ("Đã lên lịch").
  3. Cần đảm bảo tab Lịch sử hiển thị và phân biệt rõ ràng:
     - **Loại phiên:** "Khẩn cấp" (`EMERGENCY`) vs "Định kỳ" (`SCHEDULED` / `ROUTINE`).
     - **Trạng thái:** "Đang diễn ra" (`ONGOING`), "Đã hoàn thành" (`COMPLETED`), "Đã lên lịch" (`SCHEDULED`), "Đã hủy" (`CANCELLED`).

---

## 🛠️ 2. PHƯƠNG ÁN KỸ THUẬT & KIẾN TRÚC TOÀN DIỆN (DUAL-AXIS REASONING)

### 2.1. Suy Luận Chiều Ngang (Horizontal Reasoning):
- **Tác động Backend (`maintenance.manager.js`, `maintenance.repository.js`, `admin.controller.js`):**
  - **Phát thông báo mặc định:** Khi kích hoạt bảo trì khẩn cấp hoặc khi tới giờ kích hoạt bảo trì định kỳ:
    + Tự động phát WebSocket / SSE tới `Client-app` và `admin_room` (`emitMaintenanceChanged`).
    + Gọi `notificationService.broadcast` với cấp độ phù hợp (`CRITICAL` cho khẩn cấp, `WARNING` cho định kỳ, `INFO` khi hoàn tất khôi phục).
  - **Tự động hủy các lịch bảo trì định kỳ dính thời gian khi kích hoạt khẩn cấp:**
    + Khi kích hoạt bảo trì khẩn cấp, quét toàn bộ danh sách `scheduledList`: Các lịch bảo trì định kỳ nằm trong khung thời gian bảo trì khẩn cấp (hoặc tất cả các lịch trong tương lai gần bị gián đoạn) sẽ được tự động chuyển sang trạng thái `CANCELLED` trong CSDL qua `defaultMaintenanceRepository.cancelScheduledRecord` với lý do *"Tự động hủy do trùng khung thời gian bảo trì khẩn cấp"*.
- **Tác động Frontend Admin-web (`BroadcastPage.jsx`):**
  - **Header:** Bỏ icon `construction` ở thẻ `<h1>`.
  - **Checkbox "Bảo trì khẩn cấp" trong Form lập lịch:**
    + Quản lý state `isEmergencySchedule` (mặc định: `false`).
    + Nếu `maintenance.active && maintenance.isEmergency`: Checkbox bị `disabled={true}`, hiển thị badge chú thích *"Hệ thống đang trong chế độ bảo trì khẩn cấp"*.
    + Nếu tick chọn `isEmergencySchedule === true`:
      * Ô thời gian bắt đầu chuyển thành *"Ngay lập tức"* (disabled hoặc ẩn).
      * Nút submit chuyển thành: *"Kích hoạt bảo trì khẩn cấp"* (nền đỏ rose, icon `crisis_alert`).
      * Khi submit: Mở modal xác nhận khẩn cấp an toàn (`showEmergencyConfirmModal`), sau khi Admin xác nhận sẽ gọi API kích hoạt khẩn cấp tức thì.
  - **Tab Lịch Sử Bảo Trì:**
    + Bổ sung badge hiển thị trạng thái `SCHEDULED`: nhãn *"Đã lên lịch"* (nền xanh dương nhạt, icon `calendar_clock`).
    + Dropdown lọc trạng thái: Bổ sung option `<option value="SCHEDULED">Đã lên lịch</option>`.
    + Đảm bảo phân biệt rành mạch loại bảo trì: *"Khẩn cấp"* (`EMERGENCY`) vs *"Định kỳ"* (`SCHEDULED`).

### 2.2. Suy Luận Chiều Sâu (Vertical / Deep-Impact Reasoning):
- **Bảo Vệ Người Dùng & Toàn Vẹn Hệ Thống (User Experience & System Guard):**
  - Khi bảo trì khẩn cấp đè lên bảo trì định kỳ, người dùng Client-app nhận được cảnh báo đỏ tức thời, chặn các giao dịch dở dang để bảo vệ số dư và dữ liệu tài chính.
  - Các lịch bảo trì định kỳ bị hủy tự động được ghi nhận rõ ràng trong CSDL PostgreSQL (`status: 'CANCELLED'`, lý do rõ ràng), phục vụ audit log và đối soát minh bạch.
- **Zero Regressions:** Bảo đảm toàn bộ 421 tests Backend và các test suites Admin-web tiếp tục PASS 100%.

---

## 📝 3. KẾ HOẠCH TRIỂN KHAI THEO 4 BƯỚC CHI TIẾT

### Bước 1: Nâng Cấp Backend Logic Hủy Lịch Khi Kích Hoạt Khẩn Cấp (`maintenance.manager.js`)
1. **Tại `src/Backend/core/resilience/maintenance.manager.js`:**
   - Trong `setMaintenance`: Khi `isEmergency === true` được kích hoạt (cả trường hợp bật mới hoặc đè lên phiên bảo trì định kỳ):
     + Quét danh sách `this.scheduledList`.
     + Với các lịch hẹn định kỳ bị dính khung thời gian (hoặc lịch hẹn sắp diễn ra trong khi đang khẩn cấp):
       Tự động gọi `defaultMaintenanceRepository.cancelScheduledRecord` chuyển trạng thái sang `CANCELLED` với lý do *"Tự động hủy do trùng vào khung bảo trì khẩn cấp"*.
     + Xóa timer của các lịch này và dọn khỏi `scheduledList`.

### Bước 2: Nâng Cấp Giao Diện Header & Form Lập Lịch (`BroadcastPage.jsx`)
1. **Header:** Bỏ icon `construction` ở dòng 484.
2. **Form lập lịch bảo trì định kỳ:**
   - Bổ sung checkbox **"Bảo trì khẩn cấp"**:
     + `disabled = maintenance.active && maintenance.isEmergency`
     + Khi tick: chuyển form sang kích hoạt khẩn cấp tức thì (ô thời gian ẩn/disabled, nút submit đổi sang màu đỏ "Kích hoạt bảo trì khẩn cấp").
     + Mặc định hiển thị thông báo: *"Mặc định hệ thống sẽ tự động phát thông báo tới Client-app người dùng và Quản trị viên."*

### Bước 3: Chuẩn Hóa Hiển Thị Tab Lịch Sử Bảo Trì (`BroadcastPage.jsx` & Locales)
1. **Tại `src/Admin-web/src/pages/system/BroadcastPage.jsx`:**
   - Xử lý trạng thái `row.status === 'SCHEDULED'`: hiển thị badge xanh dương "Đã lên lịch" với icon `calendar_clock`.
   - Cập nhật dropdown lọc trạng thái: bổ sung option `SCHEDULED`.
   - Cập nhật nhãn loại bảo trì: "Khẩn cấp" (`EMERGENCY`) vs "Định kỳ" (`SCHEDULED`).
2. **Tại `src/Admin-web/src/locales/vi.js` và `en.js`:**
   - Cập nhật các key: `broadcast.history.statusScheduled`, `broadcast.schedule.emergencyCheckbox`, `broadcast.schedule.emergencyBlockedHint`, `broadcast.schedule.defaultNotifyNote`.

### Bước 4: Kiểm Thử 2 Tầng (Rule 11) & Nghiệm Thu
1. **Viết Bộ Test 2 Tầng Chuyên Biệt (`broadcast.emergency.checkbox.history.2tier.test.jsx` & Backend tests):**
   - **Tầng 1 (Giao diện & Thao tác):**
     + Kiểm tra Header không còn icon `construction`.
     + Kiểm tra checkbox "Bảo trì khẩn cấp" hiển thị trong Form lập lịch.
     + Kiểm tra checkbox bị disabled khi hệ thống đang trong bảo trì khẩn cấp (`maintenance.active && maintenance.isEmergency`).
     + Kiểm tra checkbox KHÔNG bị disabled khi bảo trì định kỳ đang diễn ra hoặc đã lên lịch.
     + Kiểm tra tab Lịch sử hiển thị bản ghi `SCHEDULED` với nhãn "Đã lên lịch" (không bị nhầm thành "Đã hủy").
   - **Tầng 2 (Tác động Hệ thống Thực tế):**
     + Khi kích hoạt bảo trì khẩn cấp: API được gọi, các lịch bảo trì định kỳ bị dính thời gian tự động bị hủy và ghi nhận vào CSDL.
     + Thông báo tự động được phát tới toàn bộ Client-app và Admin-web.
2. **Chạy toàn bộ Regression Test Suites:**
   - `rtk npm test` Backend (421+ tests PASS 100%).
   - `rtk npm test` Admin-web (tất cả các suites broadcast PASS 100%).
3. **Cập nhật Nguồn sự thật (`Project.md`) & Chạy `rtk npx codegraph build`.**

---

## 🛡️ 4. BẢNG TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA)

| STT | Kịch bản kiểm thử | Kết quả mong đợi | Trạng thái |
|:---:|---|---|:---:|
| 1 | Header trang Bảo trì & Thông báo | **Loại bỏ hoàn toàn icon `construction`**, tiêu đề hiển thị trang nhã, đúng thiết kế | ✅ PASS 100% |
| 2 | Mặc định phát thông báo tới người dùng | Cả bảo trì định kỳ và khẩn cấp đều tự động phát thông báo tới Client-app và Admin-web | ✅ PASS 100% |
| 3 | Checkbox "Bảo trì khẩn cấp" trong Form lập lịch | Hiển thị rõ ràng trong form; **bị chặn khi đang có bảo trì khẩn cấp hoạt động**, **không bị chặn khi bảo trì định kỳ** | ✅ PASS 100% |
| 4 | Bảo trì khẩn cấp đè bảo trì định kỳ & tự động hủy lịch dính thời gian | Kích hoạt khẩn cấp đè lên định kỳ; các lịch định kỳ dính khung thời gian **tự động chuyển sang `CANCELLED` trong CSDL** | ✅ PASS 100% |
| 5 | Tab Lịch Sử Các Phiên Bảo Trì Hệ Thống | Ghi nhận và hiển thị đầy đủ cả **bảo trì định kỳ** và **bảo trì khẩn cấp**; trạng thái `SCHEDULED` hiển thị đúng "Đã lên lịch" (không bị nhầm "Đã hủy") | ✅ PASS 100% |
| 6 | Kiểm thử 2 Tầng (Rule 11) & Zero Regressions | Toàn bộ test cases Tầng 1 & Tầng 2 đều PASS 100%; không phát sinh lỗi hồi quy | ✅ PASS 100% |
