# TỔNG HỢP LUỒNG NGHIỆP VỤ MODULE AI (LOGIC BUSINESS AI)
> **Tài liệu nguồn sự thật tổng thể cho toàn bộ các chức năng thuộc Module AI**  
> *Quy tắc: Làm tới đâu cập nhật tới đó. Được PO phê duyệt ngày 2026-09-02.*

---

## 1. TỔNG QUAN HỆ SINH THÁI MODULE AI

Module AI trong hệ thống **WealthCommand (Personal Finance Management)** đóng vai trò là tầng trí tuệ nhân tạo hỗ trợ người dùng tự động hóa, thông minh hóa và tối ưu hóa việc quản lý tài chính cá nhân.

### Danh mục các chức năng của Module AI:
1. **Receipt OCR (Bóc tách hóa đơn)**: Tự động nhận diện và trích xuất thông tin từ ảnh chụp hóa đơn.
2. **Transaction Classification (Phân loại giao dịch)**: Tự động gán danh mục thu/chi cho các giao dịch từ OCR, Ngân hàng (Casso), SMS, và Nhập tay.
3. **Financial Advice (Tư vấn tài chính)** *(Lộ trình tiếp theo)*: Đưa ra lời khuyên cắt giảm chi tiêu, phân bổ thu nhập.
4. **Smart Budget (Ngân sách thông minh)** *(Lộ trình tiếp theo)*: Gợi ý hạn mức ngân sách tự động theo quy tắc 50/30/20 hoặc lịch sử chi tiêu.
5. **Financial Chatbot (Trợ lý ảo hỏi đáp)** *(Lộ trình tiếp theo)*: Tra cứu số dư, thống kê chi tiêu bằng ngôn ngữ tự nhiên.
6. **Cash Flow Forecast (Dự báo dòng tiền)** *(Lộ trình tiếp theo)*: Dự báo số dư ví trong 30 ngày tới.
7. **Spending Behavior (Phân tích hành vi chi tiêu)** *(Lộ trình tiếp theo)*: Phát hiện chi tiêu bất thường / lãng phí.

---

## 2. LUỒNG NGHIỆP VỤ: TẠO GIAO DỊCH TỪ ẢNH HÓA ĐƠN (OCR + PHÂN LOẠI DANH MỤC)

Hệ thống thiết kế theo kiến trúc **Offline-First**, phân định rõ ràng giữa 2 trạng thái mạng: **Có kết nối Internet (Online)** và **Không có kết nối Internet (Offline)**.

```
                                  【NGƯỜI DÙNG CHỤP ẢNH HÓA ĐƠN】
                                                │
                       ┌────────────────────────┴────────────────────────┐
                       ▼                                                 ▼
             【KHI CÓ INTERNET (ONLINE)】                     【KHI MẤT INTERNET (OFFLINE)】
                       │                                                 │
                       ▼                                                 ▼
         [Client gửi ảnh lên Backend]                      [Client gọi On-device OCR tại máy]
          (POST /api/ai/ocr/parse)                         (Đọc từng món & 1 giao dịch tổng)
                       │                                                 │
                       ▼                                                 ▼
         [Backend OCR đọc dữ liệu ảnh]                     [Client gọi Offline Matcher (SQLite)]
       (Đọc từng món & 1 giao dịch tổng)                   (Phân loại từng món & giao dịch tổng)
                       │                                                 │
                       ▼                                                 ▼
        [Backend gọi AI Phân loại danh mục]                [Client gom nhóm các món cùng danh mục]
      (Phân loại từng món & giao dịch tổng)                              │
                       │                                                 │
                       ▼                                                 │
      [Backend gom nhóm các món cùng danh mục]                           │
                       │                                                 │
                       ▼                                                 │
     [Backend trả DTO về cho Client-app]                                 │
                       │                                                 │
                       └────────────────────────┬────────────────────────┘
                                                │
                                                ▼
                             【MÀN HÌNH XÁC NHẬN TẠI CLIENT-APP】
                               Người dùng chọn CÁCH GHI NHẬN:
                             ┌───────────────────────────────────┐
                             │ • Tùy chọn A: 1 GIAO DỊCH TỔNG    │
                             │ • Tùy chọn B: NHIỀU GIAO DỊCH     │
                             │   (đã gom theo từng danh mục)     │
                             └───────────────────────────────────┘
                                                │
                                                ▼
                             【NGƯỜI DÙNG XÁC NHẬN & CHỈNH SỬA】
                             (Kiểm tra số tiền, ghi chú, danh mục)
                                                │
                                                ▼
                             【GHI NHẬN VÀO CSDL SQLITE CỤC BỘ】
                                                │
                                                ▼
                             【SYNC ENGINE ĐỒNG BỘ VỀ BACKEND】
                                (Đẩy lên Supabase PostgreSQL)
```

---

### 2.1. Chi Tiết Luồng 1: Có Kết Nối Internet (Online Flow)
1. **Client-app** gửi yêu cầu kèm hình ảnh hóa đơn lên Backend (`POST /api/ai/ocr/parse`).
2. **Backend OCR Engine** xử lý hình ảnh:
   * Trích xuất chi tiết **từng mặt hàng 1** (`items`: tên món, số lượng, đơn giá, thành tiền).
   * Trích xuất **1 giao dịch tổng** của hóa đơn (`total_amount`, ngày giờ, tên đơn vị bán hàng, mã hóa đơn).
3. **Backend AI Classifier** tiến hành phân loại danh mục:
   * Phân loại danh mục cho từng mặt hàng riêng lẻ.
   * Phân loại danh mục tổng thể cho toàn bộ hóa đơn.
4. **Backend gom nhóm**: Gom các mặt hàng đơn lẻ có cùng `Idcategory` lại với nhau.
5. **Backend trả kết quả về Client-app**: Gửi Payload DTO đầy đủ gồm 2 phương án: `option_single` (1 giao dịch tổng) và `option_grouped` (các nhóm giao dịch chi tiết).
6. **Tại Client-app:**
   * Hiển thị giao diện cho người dùng lựa chọn cách ghi nhận:
     * **Cách 1:** Ghi nhận theo 1 giao dịch tổng hóa đơn.
     * **Cách 2:** Ghi nhận chi tiết theo từng nhóm danh mục.
   * Người dùng kiểm tra, chỉnh sửa (nếu muốn) và bấm xác nhận.
   * Client-app lưu dữ liệu vào **CSDL SQLite cục bộ** (với `Idtran = UUID v4`, `Status = 'Confirmed'`, `Provider = 'ORC'`).
   * Hệ thống **Sync Engine** tự động đồng bộ giao dịch lên Supabase Backend.

---

### 2.2. Chi Tiết Luồng 2: Không Có Kết Nối Internet (Offline Flow)
1. **Client-app** phát hiện thiết bị đang ngoại tuyến $\rightarrow$ Chuyển sang chế độ xử lý On-device:
2. **On-device OCR** (Google ML Kit / Local OCR) đọc dữ liệu từ hình ảnh:
   * Đọc chi tiết từng mặt hàng.
   * Đọc 1 giao dịch tổng của hóa đơn.
3. **Offline Keyword Matcher** tại Client tra cứu từ khóa trong SQLite:
   * Gán danh mục cho từng mặt hàng.
   * Gán danh mục cho giao dịch tổng.
4. **Client-app gom nhóm** các mặt hàng có cùng danh mục.
5. **Hiển thị màn hình xác nhận**: Cho người dùng chọn ghi nhận theo 1 giao dịch tổng HOẶC nhiều giao dịch chi tiết.
6. **Người dùng xác nhận** $\rightarrow$ Ghi nhận vào **CSDL SQLite cục bộ** và cập nhật số dư ví offline.
7. Khi thiết bị có Internet trở lại, **Sync Engine** tự động đẩy dữ liệu lên Backend mà không cần người dùng thao tác lại.

---

### 2.3. Quy Tắc Xử Lý Khi Chuyển Đổi Trạng Thái Mạng Bất Ngờ (Network Transition)

| Tình Huống | Hành Vi Của Hệ Thống | Nguyên Tắc Đảm Bảo |
|---|---|---|
| **Đang chạy Offline $\rightarrow$ Có Internet bất ngờ** | **Vẫn tiếp tục thực thi trọn vẹn theo luồng Offline**: Tiếp tục chạy keyword matcher trên SQLite $\rightarrow$ Người dùng xác nhận $\rightarrow$ Lưu SQLite. Khi hoàn tất, Sync Engine ngầm sẽ tự động đồng bộ lên Backend sau. | Đảm bảo UI mượt mà, không bị giật/lag, không bị reset form hay gián đoạn trải nghiệm người dùng. |
| **Đang chạy Online $\rightarrow$ Mất Internet giữa chừng** | • **Phía Client-app:** Nếu quá thời gian chờ (timeout) hoặc mất kết nối trước khi nhận được response từ Backend $\rightarrow$ Báo lỗi kết nối mạng và dừng thao tác tạo giao dịch (gợi ý chuyển sang quét Offline hoặc nhập tay).<br>• **Phía Backend:** Nếu đã nhận request thành công $\rightarrow$ Backend vẫn tiếp tục xử lý bóc tách và hoàn tất phản hồi, giải phóng tài nguyên server bình thường, không bị treo socket. | Đảm bảo kiến trúc Stateless Decoupled, Backend an toàn và Client phản ứng linh hoạt. |

---

## 3. CÁC TÀI LIỆU ĐẶC TẢ CHI TIẾT TỪNG CHỨC NĂNG

* Đặc tả kỹ thuật & API **Receipt OCR**: Xem tại [docs/AI/ORC.md](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/docs/AI/ORC.md).
* Đặc tả kỹ thuật & API **AI Transaction Classification**: Xem tại [docs/AI/Classify.md](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/docs/AI/Classify.md).
