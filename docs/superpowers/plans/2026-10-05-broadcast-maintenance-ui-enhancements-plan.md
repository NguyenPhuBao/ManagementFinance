# Kế Hoạch Triển Khai: Tinh Chỉnh Giao Diện & Hành Vi Tính Năng Lên Lịch Bảo Trì (Admin-web Broadcast)

> **Mục tiêu:** 
> 1. Chuẩn hóa checkbox ở cột "Lên Lịch Thời Điểm Bảo Trì": Loại bỏ nhãn "Khẩn cấp" (vì đã có ở cột bảo trì tức thì), chuyển thành tùy chọn phát thông báo cho Client & Admin khi tới giờ hẹn.
> 2. Loại bỏ hoàn toàn dòng thông tin kỹ thuật không cần thiết: `Cổng kiểm tra bảo trì: /health/admin`.
> 3. Khắc phục nút "Làm mới trạng thái": Thực hiện xóa toàn bộ các giá trị đang nhập tại các ô input của form lên lịch (Reset Form) đồng thời fetch lại trạng thái mới nhất từ server kèm hiệu ứng phản hồi thị giác (loading/spin).
>
> **Phạm vi tác động:** 
> - UI Component: [`src/Admin-web/src/pages/system/BroadcastPage.jsx`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Admin-web/src/pages/system/BroadcastPage.jsx)
> - Unit/Integration Test: [`src/Admin-web/src/tests/broadcast.page.test.jsx`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Admin-web/src/tests/broadcast.page.test.jsx)

---

## 1. PHÂN TÍCH HIỆN TRẠNG & NGUYÊN NHÂN GỐC RỄ

### 1.1. Vấn đề 1: Checkbox "Kèm chế độ khẩn cấp" gây nhầm lẫn nghiệp vụ
- **Hiện trạng:** Form lên lịch đang hiển thị checkbox:  
  `[ ] Kèm chế độ khẩn cấp (Tự động phát thông báo khi tới giờ hẹn)`
- **Bất cập:**
  - Cột bên trái đã là **"Kích Hoạt Bảo Trì Tức Thì"** dành riêng cho xử lý sự cố khẩn cấp.
  - Cột bên phải là **"Lên Lịch Thời Điểm Bảo Trì"** (Scheduled / Planned Maintenance) dành cho kế hoạch định kỳ trong tương lai. Bản chất lên lịch hẹn trước không phải là tình huống "Khẩn cấp" (Emergency).
  - Tác dụng thực tế của checkbox này chỉ đơn thuần là: **Có phát sóng thông báo (Broadcast) cảnh báo cho Client-app và Admin-web khi bắt đầu bảo trì hay không** (nếu không tích thì bảo trì kỹ thuật im lặng).
- **Giải pháp:**
  - Bỏ nhãn "Khẩn cấp".
  - Đổi tên state từ `scheduleEmergency` sang `scheduleNotify` (mặc định `false`).
  - Đổi nhãn giao diện thành:  
    `Tự động phát thông báo cho Client & Admin khi tới giờ hẹn`  
    *(Mô tả phụ: Khi tới giờ hẹn, hệ thống sẽ phát sóng thông báo realtime qua Socket.IO tới toàn bộ người dùng và quản trị viên).*

---

### 1.2. Vấn đề 2: Dòng thông tin kỹ thuật thừa `Cổng kiểm tra bảo trì: /health/admin`
- **Hiện trạng:** Dưới chân card Lên lịch bảo trì có hiển thị dòng chữ:  
  `Cổng kiểm tra bảo trì: /health/admin`
- **Bất cập:**
  - Đây là endpoint kỹ thuật nội bộ (Internal health-check), người dùng quản trị (Admin) không tương tác trực tiếp với đường dẫn này.
  - Gây rối mắt và làm giảm tính tinh gọn của bảng điều khiển.
- **Giải pháp:**
  - Xóa bỏ hoàn toàn thẻ `<span>Cổng kiểm tra bảo trì: <code>/health/admin</code></span>`.
  - Căn chỉnh thanh footer của card gọn gàng, đặt nút làm mới sang vị trí góc phải (`justify-end`).

---

### 1.3. Vấn đề 3: Nút "Làm mới trạng thái" không xóa giá trị input và thiếu phản hồi thị giác
- **Hiện trạng:**
  ```jsx
  <button type="button" onClick={fetchMaintenance} ...>
    <span className="material-symbols-outlined text-[14px]">refresh</span>
    Làm mới trạng thái
  </button>
  ```
- **Bất cập:**
  - Hàm `fetchMaintenance()` chỉ gọi API `GET /api/admin/maintenance` để cập nhật trạng thái chung từ server.
  - **Hoàn toàn không can thiệp vào các state của form lên lịch** (`scheduleDatetime`, `scheduleEndDatetime`, `scheduleReason`, `scheduleEmergency`). Khi người dùng đang nhập dở dữ liệu vào các ô input và bấm "Làm mới trạng thái" để xóa sạch nhập lại, các ô input vẫn giữ nguyên giá trị!
  - Không có hiệu ứng xoay icon (spin) hay thông báo nào, dẫn đến người dùng cảm thấy "bấm vào nút nhưng không có tác dụng".
- **Giải pháp:**
  - Xây dựng hàm chuyên biệt `handleResetScheduleFormAndRefresh`:
    1. Đặt lại toàn bộ state của form về giá trị rỗng/mặc định:
       ```javascript
       setScheduleDatetime('');
       setScheduleEndDatetime('');
       setScheduleReason('');
       setScheduleNotify(false);
       setMaintenanceFeedback(null);
       ```
    2. Bật cờ `isRefreshing = true` để kích hoạt hiệu ứng xoay icon `animate-spin` trên nút refresh.
    3. Gọi `await fetchMaintenance()` để nạp lại trạng thái mới nhất từ Backend.
    4. Tắt cờ `isRefreshing = false` và hiển thị thông báo phản hồi nhẹ: *"Đã làm mới trạng thái và xóa trắng biểu mẫu!"*.

---

## 2. KẾ HOẠCH TRIỂN KHAI CHI TIẾT (TỪNG BƯỚC)

### Bước 1: Cập nhật component `BroadcastPage.jsx`
1. **Refactor State:**
   - Thay `const [scheduleEmergency, setScheduleEmergency] = useState(false)` bằng `const [scheduleNotify, setScheduleNotify] = useState(false)`.
   - Bổ sung state `isRefreshing`: `const [isRefreshing, setIsRefreshing] = useState(false)`.
2. **Viết hàm `handleResetScheduleFormAndRefresh`:**
   ```javascript
   const handleResetScheduleFormAndRefresh = async () => {
     try {
       setIsRefreshing(true);
       setScheduleDatetime('');
       setScheduleEndDatetime('');
       setScheduleReason('');
       setScheduleNotify(false);
       setMaintenanceFeedback({
         ok: true,
         msg: 'Đã làm mới trạng thái và đặt lại biểu mẫu lên lịch thành công.',
       });
       await fetchMaintenance();
     } catch (err) {
       console.error('[BroadcastPage] Lỗi làm mới form lên lịch', err);
     } finally {
       setTimeout(() => setIsRefreshing(false), 500);
     }
   };
   ```
3. **Cập nhật hàm `handleSaveSchedule`:**
   - Payload gửi lên backend: `isEmergency: Boolean(scheduleNotify)`.
   - Sau khi lưu thành công: Reset `scheduleNotify` về `false`.
4. **Cập nhật JSX:**
   - Thay checkbox nhãn cũ thành:
     ```jsx
     <label className="flex items-start gap-2.5 cursor-pointer text-xs text-on-surface">
       <input
         type="checkbox"
         checked={scheduleNotify}
         onChange={(e) => setScheduleNotify(e.target.checked)}
         className="w-4 h-4 mt-0.5 text-primary rounded border-gray-300 focus:ring-primary cursor-pointer"
       />
       <div>
         <span className="font-medium">Tự động phát thông báo cho Client & Admin khi tới giờ hẹn</span>
         <p className="text-[11px] text-on-surface-variant mt-0.5">
           Khi tới giờ hẹn, hệ thống sẽ phát sóng thông báo realtime qua Socket.IO tới toàn bộ người dùng và quản trị viên thay vì bảo trì im lặng.
         </p>
       </div>
     </label>
     ```
   - Xóa bỏ dòng `Cổng kiểm tra bảo trì: /health/admin`.
   - Cập nhật footer card:
     ```jsx
     <div className="flex items-center justify-end border-t border-outline-variant/60 pt-3">
       <button
         type="button"
         onClick={handleResetScheduleFormAndRefresh}
         disabled={isRefreshing}
         className="text-primary hover:underline flex items-center gap-1.5 cursor-pointer font-medium text-xs disabled:opacity-50"
         title="Xóa trắng biểu mẫu đang nhập và làm mới trạng thái từ hệ thống"
       >
         <span className={`material-symbols-outlined text-[16px] ${isRefreshing ? 'animate-spin' : ''}`}>
           refresh
         </span>
         <span>{isRefreshing ? 'Đang làm mới...' : 'Làm mới & Đặt lại biểu mẫu'}</span>
       </button>
     </div>
     ```

---

### Bước 2: Cập nhật & Bổ sung Unit Test (`broadcast.page.test.jsx`)
1. **Kiểm tra loại bỏ `/health/admin`:**
   - Assert rằng `/health/admin` không xuất hiện trên màn hình.
2. **Kiểm tra nút "Làm mới & Đặt lại biểu mẫu":**
   - Giả lập người dùng nhập dữ liệu vào `scheduleDatetime`, `scheduleEndDatetime`, `scheduleReason`, tích chọn `scheduleNotify`.
   - Click nút "Làm mới & Đặt lại biểu mẫu".
   - Assert rằng:
     - Tất cả các ô input đều được xóa trắng (`value === ''` và `checked === false`).
     - Hàm `adminApi.getMaintenanceStatus` được gọi lại.
     - Hiển thị thông báo phản hồi thành công.
3. **Kiểm tra lưu lịch với tùy chọn phát thông báo:**
   - Đảm bảo form submit gửi `isEmergency: true/false` tương ứng với checkbox phát thông báo.
   - Sửa ca test 6.7 để form submit hợp lệ với thời gian tương lai (`Date.now() + 1 hour`).

---

### Bước 3: Xác minh & Nghiệm thu
- Chạy `rtk npm test` trong thư mục `src/Admin-web` đảm bảo 100% tests PASS.
- Build kiểm tra TypeScript / Vite bundle (`rtk npm run build` trong `src/Admin-web`).
- Cập nhật tài liệu dự án `Project.md` và chạy `rtk npx codegraph build`.

---

## 3. TIÊU CHUẨN NGHIỆM THU (ACCEPTANCE CRITERIA)
- [ ] Không còn checkbox nhãn "Kèm chế độ khẩn cấp" ở cột lên lịch; thay bằng checkbox phát thông báo rõ nghĩa.
- [ ] Không còn dòng text `Cổng kiểm tra bảo trì: /health/admin`.
- [ ] Nút làm mới trạng thái xóa trắng toàn bộ dữ liệu đang nhập dở tại form lên lịch, có hiệu ứng xoay icon và nạp lại trạng thái mới nhất từ server.
- [ ] Toàn bộ bộ test của Admin-web chạy thành công 100% không có lỗi.
