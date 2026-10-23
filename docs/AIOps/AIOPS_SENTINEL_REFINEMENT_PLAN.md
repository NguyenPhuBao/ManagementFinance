# 📋 KẾ HOẠCH CHI TIẾT TINH CHỈNH & CHUẨN HÓA TRANG AIOPS SENTINEL

> **Tài liệu nguồn sự thật phục vụ thực thi:** `docs/AIOps/AIOPS_SENTINEL_REFINEMENT_PLAN.md`  
> **Ngày lập:** 2026-10-23  
> **Tác giả:** AI Assistant (Lead BA + Lead FullStack + Lead Tester)  
> **Trạng thái:** ✅ ĐÃ HOÀN THÀNH 100% (COMPLETED & VERIFIED)  
> **Kiểm thử:** 100% Pass (Backend 88/88 tests, Frontend 53/53 tests, Build Production thành công)

---

## 🎯 1. BỐI CẢNH & KHẢO SÁT CHI TIẾT CÁC ISSUE LOG TỪ PO

Toàn bộ các issue log tại trang **AIOps Sentinel** (`src/Admin-web/src/pages/system/AIOpsPage.jsx` và module backend `src/Backend/modules/aiops/`) đã được khảo sát kỹ lưỡng và xác nhận:

| STT | Vị trí / Thành phần | Yêu cầu từ PO | Giải pháp kỹ thuật chuẩn hóa |
| :---: | :--- | :--- | :--- |
| **1** | **Header** | - Bỏ icon `"security"`<br>- Bỏ cụm từ `"Máy Học"` trong tiêu đề<br>- Bỏ nút `"Làm mới"` (real-time auto update)<br>- Nút `"Tái Hiệu Chuẩn Baseline"`: Căn cứ tình trạng server + kiến trúc thực tế, cho phép cấu hình ngưỡng an toàn 4 Vector | - Gỡ bỏ icon `security` tại đầu `<h1>`.<br>- Tiêu đề rút gọn thành `"AIOps Sentinel — Giám Sát & Phòng Vệ Tự Động"`.<br>- Gỡ bỏ nút `"Làm Mới"` (`handleManualRefresh`).<br>- **Modal Tái Hiệu Chuẩn:** Hiển thị thông số phần cứng thực tế (CPU cores, RAM) + gợi ý tự động, bổ sung form cho phép Admin tùy chỉnh trực tiếp ngưỡng an toàn mong muốn (Custom Thresholds) cho 4 Vector và lưu cứng vào CSDL `aiops_setting`. |
| **2** | **Thông báo dưới header** | Bỏ dòng thông báo dưới header `"verified Hiệu chuẩn thành công"` hay các dòng tương tự | Gỡ bỏ khối banner `{feedback && (<div className=...>...</div>)}` dưới Header. Toàn bộ thông báo đã được điều hướng tự động qua Global Floating Toast (`alert.success` / `alert.error`). |
| **3** | **Box Tình Trạng Hệ Thống** | Bỏ box Tình trạng hệ thống | Xóa bỏ toàn bộ khối `THẺ TÌNH TRẠNG HỆ THỐNG` (lines 1429–1514) để tối ưu diện tích màn hình. Thông tin bảo trì đã được quản lý chuyên biệt tại trang "Bảo trì & Thông báo". |
| **4** | **Box Quy Mô Người Dùng & Chịu Tải** | - Bỏ icon `"group"`<br>- Bỏ `"Công thức: 500 × 10 RPM"`<br>- Bỏ `"Trần an toàn 3× Baseline (Chưa kích hoạt DoS)"`<br>- Bỏ `"20 + 50×log10(N) (Tự động cách ly IP càn quét)"` | - Gỡ bỏ icon `group` tại tiêu đề box.<br>- Giữ lại các thẻ số liệu thống kê (Số người dùng, Baseline RPM, Safe Peak, Ngưỡng chặn IP) nhưng gỡ bỏ các dòng chữ công thức kỹ thuật thô, làm gọn gàng thẻ thống kê. |
| **5** | **Box 4 Vectơ Rủi Ro** | - Bỏ icon `"hub"`<br>- Bỏ `"Độc Lập & Cá Nhân Hóa Phòng Vệ (Multi-Vector Risk Architecture)"`<br>- Bỏ `"Chế độ chỉ đo lường — "` (giữ nguyên chức năng) | - Gỡ bỏ icon `hub`.<br>- Tiêu đề box đổi thành: `"4 Vectơ Rủi Ro"`.<br>- Thông báo khi tắt Vector chuyển từ `"Chế độ chỉ đo lường — Bỏ qua khỏi Threat Score"` thành `"Bỏ qua khỏi Threat Score"`. Logic toggle và đo lường ngầm bảo toàn 100%. |
| **6** | **Box Biểu Đồ Xu Hướng 4 Vector** | - Bỏ icon `"show_chart"`, `"schedule"`<br>- Chuẩn hóa các bộ chọn thời gian: 10 phút, 1 giờ, 24 giờ, 7 ngày, 1 tháng<br>- Cơ chế nhận diện, phân bổ và trình bày dữ liệu theo khung thời gian | - Gỡ bỏ các icon thừa trong header và bộ chọn.<br>- **Chuẩn hóa Trục X & Bước nhảy:**<br>  + **10 phút:** Nhãn phút `[-10p, -8p, -6p, -4p, -2p, 0p]`.<br>  + **1 giờ:** Nhãn phút `[-60p, -45p, -30p, -15p, 0p]`.<br>  + **24 giờ:** Nhãn giờ trong ngày `[00:00, 04:00, 08:00, 12:00, 16:00, 20:00, 24:00]`.<br>  + **7 ngày:** Nhãn ngày/tháng `[D-6, D-5, D-4, D-3, D-2, D-1, Hôm nay]`.<br>  + **1 tháng:** Nhãn mốc tuần `[Tuần 1, Tuần 2, Tuần 3, Tuần 4, Hiện tại]`.<br>- **Backend Persistence (Phương án A đã duyệt):** Lưu snapshot định kỳ (mỗi 5 phút) vào bảng CSDL `aiops_metric_snapshot` để lưu trữ dữ liệu thực tế cho 24h, 7 ngày, 30 ngày (không sinh dữ liệu ảo). |
| **7** | **Box Tổng Quan Nguyên Nhân Bất Thường** | - Bỏ icon `"troubleshoot"`<br>- Sửa toàn bộ icon box theo bộ icon của Box 4 Vector<br>- Cột Đối tượng: Vector lưu lượng là do Hệ thống; các Vector khác ghi nhận `"TK: {username}"` và dòng dưới `"IP: {ip_hien_tai}"` | - Gỡ bỏ icon `troubleshoot` ở tiêu đề box.<br>- Đồng bộ icon chuẩn: Auth $\rightarrow$ `badge`, Traffic $\rightarrow$ `waves`, Exploit $\rightarrow$ `bug_report`, Resource $\rightarrow$ `memory` (cả ở thanh lọc pills và cột Vector trong bảng).<br>- Cột Đối tượng:<br>  + Traffic: hiển thị `"Hệ thống"` (TK) và `"Lưu lượng mạng"` (IP).<br>  + Auth / Exploit / Resource: hiển thị chính xác `"TK: {username}"` và dòng dưới `"IP: {ip_hien_tai}"`. Khi user đổi thiết bị/IP, hệ thống cập nhật IP mới nhất đang sử dụng của username đó. |
| **8** | **Box Nguồn Theo Dõi Đặc Biệt** | - Bỏ icon `"shield_with_heart"`<br>- Bỏ `"Danh sách IP & Tài khoản bị phong tỏa hoặc cách ly giám sát"`<br>- Bỏ `"Hiển thị 53 / 53 đối tượng"` | - Gỡ bỏ icon `shield_with_heart` tại tiêu đề box.<br>- Gỡ bỏ dòng subtitle mô tả phụ.<br>- Gỡ bỏ text đếm tổng số đối tượng `"Hiển thị 53 / 53 đối tượng"` phía trên bảng. |

---

## 🛠️ 2. PHÂN TÍCH 2 CHIỀU (DUAL-AXIS REASONING)

### 2.1. Suy Luận Chiều Ngang (Horizontal Reasoning):
- **Giao diện Admin-web (`src/Admin-web`):**
  - Tối ưu hóa không gian hiển thị, loại bỏ hoàn toàn các box/dòng chữ thừa thãi, nâng cao tính chuyên nghiệp chuẩn SOC/AIOps Dashboard doanh nghiệp.
  - Bộ icon được chuẩn hóa đồng bộ 100% giữa Box 4 Vector, Biểu đồ xu hướng và Bảng phân tích nguyên nhân gốc (RCA).
  - Trục X của biểu đồ hiển thị đúng định dạng thời gian của từng khung (phút, giờ, ngày, tuần).
- **Giao tiếp Backend & API (`src/Backend`):**
  - Tạo bảng CSDL `aiops_metric_snapshot` và worker lưu snapshot định kỳ 5 phút/lần (chỉ 288 dòng/ngày, cực kỳ nhẹ và tối ưu).
  - API `GET /api/v1/aiops/history` bổ sung xử lý lấy dữ liệu thực tế từ CSDL khi query khoảng thời gian lớn (`24h`, `7d`, `30d`), fallback về RAM buffer cho `10m` và `1h`.
  - API `POST /api/v1/aiops/calibrate` hỗ trợ nhận tham số tùy chỉnh ngưỡng an toàn 4 Vector từ Admin (`customThresholds`), lưu cứng vào `aiops_setting` và nạp tự động khi khởi động.
  - `feature.collector.js` và `aiops.repository.js` đồng bộ liên kết username $\leftrightarrow$ IP thiết bị mới nhất.
- **Tương thích Đa ngôn ngữ (i18n):**
  - Cập nhật cả `vi.js` và `en.js` cho tiêu đề trang, nhãn thời gian trục X, và thông báo.

### 2.2. Suy Luận Chiều Sâu (Vertical / Deep-Impact Reasoning):
- **Bảo vệ CSDL & DB Guard (Rule 10):**
  - Việc tạo bảng `aiops_metric_snapshot` được viết dưới dạng file script migration an toàn: `database/27_create_aiops_metric_snapshot_table.sql` và bọc qua `initTable()` của repository, tuyệt đối KHÔNG chạy `prisma migrate dev` hoặc `prisma db push` trên Supabase.
- **Không sinh lỗi hồi quy (Zero Regressions):**
  - Các chức năng bảo vệ cốt lõi (Active Quarantine, Rate Limiting, Threat Score calculation, Socket Realtime) hoàn toàn giữ nguyên logic 100%.
  - Cập nhật các bộ test hiện tại (`aiops.page.test.jsx`, `aiops.trend.chart.and.rca.fixes.test.jsx`, `aiops.object.and.ip.masking.test.jsx`).

---

## 📅 3. KẾ HOẠCH TRIỂN KHAI THEO 4 GIAI ĐOẠN

### Giai Đoạn 1: Backend Snapshot Engine & Custom Baseline API
1. Viết script DDL `src/Backend/database/27_create_aiops_metric_snapshot_table.sql` tạo bảng `aiops_metric_snapshot`.
2. Bổ sung `initSnapshotTable()`, `saveSnapshot()`, `getHistoricalSnapshots(startTime, endTime, bucketMs)` trong `aiops.repository.js`.
3. Trong `aiops.service.js`:
   - Thiết lập interval 5 phút tự động lưu 1 snapshot gồm: `threatScore`, `vectorScores` (4 vector), `requestsPerMin`, `cpuPercent`, `ramPercent`, `eventLoopLagMs`.
   - Cập nhật `getHistory({ range, from, to })`: Nếu range là `24h`, `7d`, `30d` hoặc khoảng `from`/`to` dài, truy vấn trực tiếp từ bảng `aiops_metric_snapshot`.
   - Cập nhật `calibrate()`: Nhận `customThresholds` (nếu Admin nhập tùy chỉnh trong Modal) và lưu vào `aiops_setting`.
4. Chuẩn hóa `feature.collector.js`: Khi phát sinh bất thường, ghi nhận chính xác username và IP của thiết bị đang gửi request; đối với vector traffic thì đánh dấu là "Hệ thống" / "Lưu lượng mạng".

### Giai Đoạn 2: Tinh Chỉnh Giao Diện Admin-web (`AIOpsPage.jsx`)
1. **Header & Thông Báo:**
   - Bỏ icon `security`, đổi tiêu đề thành `"AIOps Sentinel — Giám Sát & Phòng Vệ Tự Động"`.
   - Bỏ nút `"Làm Mới"`.
   - Bỏ khối banner `{feedback && ...}` dưới header.
   - Nâng cấp Modal Tái Hiệu Chuẩn: Cho phép Admin xem phần cứng máy chủ và nhập tùy chỉnh ngưỡng an toàn 4 Vector nếu muốn.
2. **Loại Bỏ Box Tình Trạng Hệ Thống:**
   - Xóa bỏ toàn bộ box `THẺ TÌNH TRẠNG HỆ THỐNG`.
3. **Box Quy Mô Người Dùng Mục Tiêu:**
   - Bỏ icon `group`.
   - Bỏ các dòng chữ công thức kỹ thuật thô (`Công thức: 500 × 10 RPM`, `Trần an toàn 3× Baseline...`, `20 + 50×log10(N)...`).
4. **Box 4 Vectơ Rủi Ro:**
   - Bỏ icon `hub`.
   - Tiêu đề rút gọn thành `"4 Vectơ Rủi Ro"`.
   - Bỏ cụm từ `"Chế độ chỉ đo lường — "` trong thông báo khi tắt vector.
5. **Box Biểu Đồ Xu Hướng 4 Vector & Bộ Chọn Thời Gian:**
   - Bỏ icon `show_chart`, `schedule`.
   - Chuẩn hóa nhãn trục X và bước nhảy theo từng khung thời gian (10 phút, 1 giờ, 24 giờ, 7 ngày, 1 tháng).
6. **Box Tổng Quan Nguyên Nhân Bất Thường:**
   - Bỏ icon `troubleshoot`.
   - Sửa lại toàn bộ icon theo bộ icon chuẩn của 4 Vector (`badge`, `waves`, `bug_report`, `memory`).
   - Cột Đối tượng: Traffic hiển thị `"Hệ thống"` / `"Lưu lượng mạng"`; các vector khác hiển thị `"TK: {username}"` và dòng dưới `"IP: {ip_hien_tai}"`.
7. **Box Nguồn Theo Dõi Đặc Biệt:**
   - Bỏ icon `shield_with_heart`.
   - Bỏ dòng mô tả phụ subtitle.
   - Bỏ dòng text đếm `"Hiển thị 53 / 53 đối tượng"`.

### Giai Đoạn 3: Cập Nhật Ngôn Ngữ & Kiểm Thử 2 Tầng (Rule 11)
1. **i18n Locales (`vi.js` & `en.js`):** Đồng bộ các key tương ứng cho tiêu đề, nhãn trục X, bộ chọn thời gian.
2. **Viết Bộ Test 2 Tầng Mới:** `src/Admin-web/src/tests/aiops.refinement.service.2tier.test.jsx`:
   - *Tầng 1 (Giao diện & Thao tác):* Kiểm tra render sạch sẽ (không còn icon security, troubleshoot, hub, group, shield_with_heart; không còn box Tình trạng hệ thống; không còn các dòng công thức và subtitle thừa; Cột Đối tượng hiển thị đúng chuẩn TK/IP; Trục X hiển thị đúng nhãn thời gian).
   - *Tầng 2 (Tác động hệ thống thực tế):* Thẩm định Modal hiệu chuẩn cho phép tùy chỉnh ngưỡng; chuyển bộ chọn thời gian tải dữ liệu chuẩn tương ứng; lưu vết bất thường ghi nhận đúng username và IP thiết bị.
3. **Cập nhật & Chạy Hồi Quy:** Chạy kiểm thử toàn bộ test suites liên quan trong Admin-web và Backend.

### Giai Đoạn 4: Cập Nhật Tài Liệu & CodeGraph (Rule 8)
1. Cập nhật `Project.md` (mục 4.22).
2. Cập nhật trạng thái `AIOPS_SENTINEL_REFINEMENT_PLAN.md` sang PASSED 100%.
3. Chạy `rtk npx codegraph build`.

---

## 🛡️ 4. TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA)
- [x] Header không còn icon `security`, không còn chữ "Máy Học", không còn nút "Làm mới".
- [x] Không còn dòng thông báo banner `feedback` dưới header.
- [x] Box "Tình trạng hệ thống" đã được xóa bỏ hoàn toàn.
- [x] Box "Quy mô người dùng" không còn icon `group` và không còn 3 dòng công thức thô.
- [x] Box "4 Vectơ Rủi Ro" không còn icon `hub`, tiêu đề là "4 Vectơ Rủi Ro", không còn chữ "Chế độ chỉ đo lường — ".
- [x] Biểu đồ xu hướng không còn icon `show_chart`/`schedule`; trục X và bộ chọn thời gian hiển thị đúng mốc thời gian của 10m, 1h, 24h, 7d, 30d.
- [x] Box "Tổng quan nguyên nhân bất thường" không còn icon `troubleshoot`; icon các vector đồng bộ chuẩn (`badge`, `waves`, `bug_report`, `memory`); Cột Đối tượng hiển thị đúng `"Hệ thống"` cho Traffic, và `"TK: username"` + `"IP: ip_hien_tai"` cho các vector khác.
- [x] Box "Nguồn theo dõi đặc biệt" không còn icon `shield_with_heart`, không còn subtitle và không còn dòng `"Hiển thị ... đối tượng"`.
- [x] Modal Tái Hiệu Chuẩn Baseline hỗ trợ xem phần cứng và tùy chỉnh ngưỡng an toàn 4 Vector.
- [x] 100% test suites pass (`rtk npm test`), không có hồi quy, build production thành công.
