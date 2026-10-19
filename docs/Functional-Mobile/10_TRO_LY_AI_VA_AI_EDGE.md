# 🤖 PHÂN HỆ 10: TRỢ LÝ AI GEMINI & EDGE AI ON-DEVICE (AI ASSISTANT & EDGE INFERENCE)

> **Mã phân hệ:** `AI`  
> **Thư mục mã nguồn:** [`src/Client-app/lib/features/ai_chat`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/ai_chat), [`src/Client-app/lib/features/ai_edge`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/ai_edge) & [`src/Client-app/lib/core/ocr`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/core/ocr)  
> **Mô hình AI Cloud:** Google Gemini Pro / Flash (Streaming SSE qua Backend API)  
> **Mô hình AI On-Device:** Google MLKit Text Recognition (OCR) & Whisper On-Device (Voice Input)

---

## 1. DANH SÁCH MÀN HÌNH & GIAO DIỆN (UI SCREENS)

| Route | Tên file Dart | Chức năng nghiệp vụ | Thành phần giao diện chính |
|:---|:---|:---|:---|
| `/ai-chat` | [`ai_chat_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/ai_chat/presentation/pages/ai_chat_page.dart) | Trợ lý Chatbot AI Tài chính | Khung chat streaming; Chip gợi ý câu hỏi; Nút hành động deep-link C3; Nút Cài đặt AI |
| `/ai-settings` | [`cai_dat_ai_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/ai_edge/presentation/pages/cai_dat_ai_page.dart) | Quản lý mô hình AI trên máy | Danh sách mô hình AI offline; Nút Tải/Xóa mô hình; Công tắc Ưu tiên suy luận cục bộ |
| — | [`ke_hoach_tai_phan_bo_sheet.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/ai_edge/presentation/pages/ke_hoach_tai_phan_bo_sheet.dart) | Đề xuất tái phân bổ ngân sách | Bottom sheet hiển thị phương án chuyển dịch hạn mức giữa các danh mục do AI đề xuất |
| `/quet` | [`quet_anh_page.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/features/transaction/presentation/pages/quet_anh_page.dart) | Quét hóa đơn OCR tự động | Khung camera xem trước ảnh; Quét MLKit On-Device; Trích xuất số tiền & Ngày hóa đơn |

---

## 2. TRỢ LÝ AI TÀI CHÍNH CLOUD (GEMINI CHATBOT)

### 2.1. Phản hồi Thời gian thực (Streaming SSE)
- Khác với chatbot thông thường phải đợi nhiều giây để sinh toàn bộ câu trả lời, Trợ lý AI FlowMoney sử dụng cơ chế **Server-Sent Events (SSE) Streaming**:
- Từng chữ cái và câu từ tuôn chảy mượt mà ngay khi mô hình sinh ra, đem lại cảm giác tương tác tự nhiên và phản hồi tức thì.

### 2.2. Nạp Tự động Ảnh chụp Tài chính (Financial Snapshot Injection)
Khi người dùng đặt câu hỏi, Client-app tự động đính kèm một bản chụp dữ liệu tài chính ẩn (đã được làm sạch và ẩn danh hóa) gửi kèm prompt lên Gemini:
```json
{
  "totalNetWorth": 45000000,
  "monthlyIncome": 25000000,
  "monthlyExpense": 18500000,
  "topExpenseCategory": "Ăn uống (7.200.000 ₫)",
  "warningBudget": "Ăn uống đã dùng 90% hạn mức",
  "activeGoals": ["Mua xe máy (đạt 65%)"]
}
```
- Nhờ đó, người dùng không cần phải kể lể số liệu:
  - Khi hỏi: *"Tháng này tôi chi tiêu thế nào?"* $\rightarrow$ AI lập tức trả lời chính xác số tiền, khen ngợi việc tiết kiệm được 6.5 triệu và nhắc nhở danh mục Ăn uống đang sắp chạm trần!

### 2.3. Lệnh Hành động Sâu Điều hướng 1 Chạm (Actionable Deep Links - C3)
Khi AI đưa ra lời khuyên, nó tự động nhúng các nút hành động điều hướng trực tiếp:
- **Tư vấn:** *"Bạn nên đặt hạn mức 5 triệu cho danh mục Mua sắm tháng tới để tránh thâm hụt."*
  - $\rightarrow$ Nút: **[Thiết lập ngân sách Mua sắm 5.000.000 ₫]** (Chạm vào mở thẳng `/budget/rules?category=mua_sam&amount=5000000`).
- **Tư vấn:** *"Để mua iPhone sau 6 tháng, bạn nên lập kế hoạch tiết kiệm ngay từ bây giờ."*
  - $\rightarrow$ Nút: **[Tạo mục tiêu tiết kiệm iPhone]** (Chạm vào mở thẳng `/goals/add?name=iPhone&target=25000000&deadline=2027-04-17`).

---

## 3. TRÍ TUỆ NHÂN TẠO CỤC BỘ (EDGE AI ON-DEVICE)

Điểm đột phá của FlowMoney là khả năng chạy AI trực tiếp trên phần cứng điện thoại mà **không cần gửi hình ảnh hay giọng nói lên máy chủ**, đảm bảo quyền riêng tư tuyệt đối (Privacy-First) và hoạt động ngay cả khi không có mạng:

### 3.1. Quét Hóa đơn OCR Cục bộ (Google MLKit OCR)
- Chụp ảnh biên lai hoặc chọn từ thư viện ảnh $\rightarrow$ Mô hình MLKit xử lý trực tiếp trên GPU/NPU của điện thoại.
- **Thuật toán bóc tách thông minh ([`core/ocr`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/core/ocr)):**
  - Quét từng dòng văn bản và lọc các cụm từ: `Tổng tiền`, `Total`, `Payment Amount`, `Cộng tiền hàng`.
  - Bỏ qua các dòng tiền khách đưa (Cash) hoặc tiền thối (Change).
  - Tự động nhận dạng dấu chấm/phẩy tiền tệ Việt Nam (`150.000` hoặc `150,000`).
  - Tự động nhận diện ngày in trên biên lai.

### 3.2. Nhập Giao dịch bằng Giọng nói Tiếng Việt (Voice-to-Transaction Whisper)
- Bấm icon Micro $\rightarrow$ Nói câu khẩu lệnh tiếng Việt tự nhiên:
  - *"Đổ xăng xe máy năm mươi nghìn ví MoMo"*
- Mô hình nhận diện giọng nói cục bộ trích xuất ngay:
  - Số tiền: `50,000 ₫`
  - Danh mục: `Xăng xe / Di chuyển`
  - Ví thanh toán: `MoMo`
  - Tự động mở form giao dịch đã điền sẵn số liệu, người dùng chỉ cần nhấn "Lưu".

### 3.3. Màn hình Quản lý Mô hình AI (`/ai-settings`)
- Cho phép người dùng kiểm soát hoàn toàn dung lượng bộ nhớ:
  - Xem kích thước từng mô hình (ví dụ: Mô hình giọng nói 45MB, mô hình OCR 20MB).
  - Tải về để sử dụng ngoại tuyến hoặc xóa đi để tiết kiệm dung lượng điện thoại.
  - Công tắc *"Ưu tiên xử lý trên thiết bị (Edge Inference)"*: Khi bật, toàn bộ tác vụ AI chạy offline trên máy, không truyền dữ liệu ra ngoài internet.
