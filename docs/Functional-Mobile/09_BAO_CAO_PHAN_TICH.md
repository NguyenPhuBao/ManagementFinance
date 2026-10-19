# 📊 PHÂN HỆ 09: BÁO CÁO PHÂN TÍCH TÀI CHÍNH & XUẤT FILE (ANALYTICS & EXPORT)

> **Mã phân hệ:** `ANALYTICS`  
> **Thư mục mã nguồn:** [`src/Client-app/lib/features/analytics`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/analytics)  
> **Quản lý trạng thái:** `AnalyticsBloc` / `AnalyticsCubit`  
> **Quyền hạn truy cập xuất file:** Độc quyền gói Premium (`MaQuyen.exportReports`)

---

## 1. DANH SÁCH MÀN HÌNH & GIAO DIỆN (UI SCREENS)

| Route | Tên file Dart | Chức năng nghiệp vụ | Thành phần giao diện chính |
|:---|:---|:---|:---|
| `/analytics` | [`analytics_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/analytics/presentation/pages/analytics_page.dart) | Báo cáo phân tích thu chi | Bộ lọc thời gian (Tuần/Tháng/Năm); Biểu đồ tròn cơ cấu; Biểu đồ cột xu hướng; Top chi tiêu; Nút Xuất file |
| `/export-report` / `/analytics/export` | [`export_report_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/analytics/presentation/pages/export_report_page.dart) | Cấu hình xuất báo cáo | Chọn khoảng ngày; Chọn định dạng PDF / Excel; Chọn phạm vi ví & danh mục; Nút Xuất & Chia sẻ |
| — | [`report_preview_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/analytics/presentation/pages/report_preview_page.dart) | Xem trước bản in báo cáo | Bản xem trước PDF tương tác; Phóng to/thu nhỏ; Nút In trực tiếp / Lưu máy |

---

## 2. QUY TẮC PHÂN QUYỀN GÓI CƯỚC (FEATURE GATING)

- **Xem Phân tích Trực quan trên Màn hình (`/analytics`):**
  - Khả dụng cho **CẢ 2 GÓI (Basic & Premium)**: Mọi người dùng đều được xem biểu đồ tròn cơ cấu chi tiêu, biểu đồ cột xu hướng và các chỉ số dòng tiền trong kỳ.
- **Tính năng Xuất Báo cáo File PDF & Excel (`export_reports`):**
  - **ĐỘC QUYỀN GÓI PREMIUM**:
  ```dart
  GoRoute(
    path: '/export-report',
    redirect: redirectTheoQuyen(MaQuyen.exportReports),
    builder: (_, state) => ExportReportPage(...),
  )
  ```
  - Khi người dùng gói Basic bấm nút Tải xuống / Xuất báo cáo (từ Tab Phân tích, từ Drawer hoặc từ Thông báo Tổng kết tuần): Hệ thống tự động kích hoạt guard chặn và chuyển hướng sang `/premium?quyen=export_reports`.
  - Màn hình Nâng cấp gói hiển thị câu mời gọi rõ ràng: *"Xuất báo cáo PDF & Excel là tính năng nâng cao dành riêng cho tài khoản Premium. Nâng cấp ngay để xuất báo cáo tài chính chuyên nghiệp phục vụ lưu trữ và phân tích!"*.

---

## 3. CÁC TÍNH NĂNG PHÂN TÍCH TÀI CHÍNH CHUYÊN SÂU

### 3.1. Bộ Chỉ số Sức khỏe Dòng tiền (Cashflow Metrics)
- **Tổng Thu nhập (Total Income):** Toàn bộ các khoản tiền vào trong kỳ.
- **Tổng Chi tiêu (Total Expense):** Toàn bộ các khoản tiêu dùng trong kỳ.
- **Tiết kiệm Ròng (Net Savings):**
  $$\text{Net Savings} = \text{Tổng Thu} - \text{Tổng Chi}$$
  - Thể hiện lượng tiền thặng dư thực tế còn đọng lại sau chi tiêu.
- **Tỷ lệ Tiết kiệm (Savings Rate):**
  $$\text{Tỷ lệ tiết kiệm} = \frac{\text{Tiết kiệm Ròng}}{\text{Tổng Thu}} \times 100\%$$
  - Đánh giá khả năng quản lý tài chính của người dùng (Tỷ lệ lý tưởng từ 20% - 30% thu nhập).

### 3.2. Biểu đồ Cơ cấu Chi tiêu Đa chiều (Donut / Pie Chart)
- Thể hiện tỷ trọng chi tiêu của từng danh mục trong tổng quỹ chi:
  - Tự động gộp các danh mục nhỏ li ti (< 3%) vào mục "Khác" để biểu đồ không bị rối mắt.
  - Tương tác chạm (Interactive Touch): Bấm vào lát cắt "Ăn uống" $\rightarrow$ biểu đồ phóng to lát cắt, hiển thị số tiền chính xác và danh sách các giao dịch con thuộc nhóm đó.

### 3.3. Biểu đồ Cột Xu hướng Biến thiên (Bar Trend Chart)
- **Chế độ Tuần:** Biểu đồ 7 cột (Thứ 2 $\rightarrow$ Chủ nhật) giúp phát hiện thói quen tiêu tiền vào dịp cuối tuần.
- **Chế độ Tháng:** Biểu đồ cột theo từng ngày trong tháng, làm nổi bật những ngày có chi phí phát sinh đột biến (Spikes).
- **Chế độ Năm:** So sánh thu - chi giữa 12 tháng, thấy rõ tháng nào bội chi (Tết, mùa du lịch, sự kiện...).

---

## 4. XUẤT FILE BÁO CÁO CHUYÊN NGHIỆP (PDF & EXCEL ENGINE)

### 4.1. Định dạng File PDF (Bản in Báo cáo Tài chính)
- Bố cục trang bìa chuẩn: Tiêu đề báo cáo, Họ tên người dùng, Khoảng thời gian thống kê, Ngày xuất file.
- Biểu đồ tóm tắt thu chi và bảng phân bổ cơ cấu danh mục in màu sắc nét.
- Bảng kê chi tiết từng giao dịch kèm ngày giờ, ví thanh toán, danh mục và số tiền.
- Tự động phân trang thông minh (Pagination Guard), có chữ ký và footer bản quyền FlowMoney.

### 4.2. Định dạng File Excel (XLSX / CSV)
- Phù hợp cho người dùng muốn nhập liệu vào máy tính để tự chạy các hàm phân tích số liệu nâng cao hoặc lưu trữ kế toán:
  - Cột `Transaction_ID`, `Date_Time`, `Category_Group`, `Category_Name`, `Wallet_Name`, `Amount_VND`, `Type` (Thu/Chi), `Notes`.
- Hỗ trợ mã hóa font chữ tiếng Việt UTF-8 chuẩn xác, không bị lỗi font khi mở trên Microsoft Excel hoặc Google Sheets.

### 4.3. Tích hợp Chia sẻ Trực tiếp (Native Share Dialog)
- Tận dụng Native Share Sheet của Android / iOS:
- Sau khi xuất file, người dùng có thể gửi ngay file PDF/Excel qua **Zalo, Telegram, Email, Google Drive** hoặc lưu thẳng vào thư mục `Download` của điện thoại chỉ với 1 chạm.
