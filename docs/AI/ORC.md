# ĐẶC TẢ KỸ THUẬT & NGHIỆP VỤ CHỨC NĂNG RECEIPT OCR (ORC.md)
> **Nguồn sự thật cho chức năng Bóc Tách Hóa Đơn (Receipt OCR)**  
> *Được PO phê duyệt ngày 2026-09-02.*

---

## 1. MÔ TẢ CHỨC NĂNG (FEATURE OVERVIEW)

Chức năng **Receipt OCR** trong Module AI cho phép người dùng tự động chuyển đổi hình ảnh hóa đơn giấy, hóa đơn điện tử chụp từ camera hoặc tải từ thư viện ảnh thành dữ liệu có cấu trúc (Tên cửa hàng, ngày giờ, danh sách mặt hàng, tổng tiền, phương thức thanh toán).

Hệ thống hoạt động theo mô hình **Stateless Processing Service**: Backend bóc tách và phân loại $\rightarrow$ trả dữ liệu về Client $\rightarrow$ Client lưu CSDL SQLite cục bộ $\rightarrow$ Sync Engine đồng bộ về Supabase PostgreSQL.

---

## 2. QUY CHUẨN BÓC TÁCH DỮ LIỆU (EXTRACTION SCHEMA)

Dữ liệu trích xuất từ hình ảnh hóa đơn được chuẩn hóa theo định dạng JSON:

```json
{
  "merchant_name": "ĐỒNG MART",
  "merchant_address": "326 Lê Văn Khương, Thới An, Quận 12, TP.HCM",
  "invoice_no": "121023427",
  "transaction_date": "2026-08-30T21:33:37.000Z",
  "total_amount": 57000,
  "vat_amount": 3217,
  "payment_method": "VNPAYQR",
  "items": [
    {
      "name": "Bột giặt Robot 800g",
      "quantity": 1,
      "unit_price": 19000,
      "total_price": 19000
    },
    {
      "name": "KTYT FAMAPRO UV",
      "quantity": 3,
      "unit_price": 6333,
      "total_price": 19000
    },
    {
      "name": "Loạt đồ chơi bong bóng 5 0",
      "quantity": 1,
      "unit_price": 19000,
      "total_price": 19000
    }
  ],
  "raw_text": "..."
}
```

---

## 3. XỬ LÝ NGHIỆP VỤ (BUSINESS PROCESSING LOGIC)

### 3.1. Bóc Tách 2 Tầng: Từng Món Hàng & Giao Dịch Tổng
* **Tầng 1 (Items Level):** Bóc tách chi tiết từng dòng mặt hàng (`name`, `quantity`, `unit_price`, `total_price`).
* **Tầng 2 (Invoice Level):** Bóc tách thông tin toàn bộ hóa đơn (`merchant_name`, `transaction_date`, `total_amount`, `invoice_no`).

### 3.2. Thuật Toán Tự Phục Hồi Dữ Liệu (Self-Healing Logic)
1. **Thiếu dòng Tổng tiền (`total_amount`):** Tự động tính $\text{total\_amount} = \sum (\text{items.total\_price})$.
2. **Không tách được danh sách món hàng:** Hệ thống vẫn trích xuất thành công `total_amount` và tạo `option_single` với `Note = "[Tên cửa hàng] (Hóa đơn không rõ chi tiết món)"`.
3. **Thiếu Ngày giờ in trên hóa đơn (`transaction_date`):** Gán mặc định thời điểm hiện tại `new Date()`.

### 3.3. Xử Lý Ngoại Lệ & Ảnh Không Đọc Được (Error Handling)
* **Kịch bản:** Ảnh chụp bị mờ 100%, lóa sáng, chụp sai đối tượng (không phải hóa đơn) dẫn tới không xác định được số tiền hợp lệ.
* **Quy tắc:** Tuyệt đối không sinh bản ghi rác.
* **Phản hồi:** Backend trả về mã lỗi HTTP **`422 Unprocessable Entity`**:
  ```json
  {
    "success": false,
    "error_code": "OCR_PARSE_FAILED",
    "message": "Không thể nhận diện thông tin hóa đơn. Ảnh có thể bị mờ hoặc thiếu thông tin.",
    "raw_text": "..."
  }
  ```

---

## 4. KỸ THUẬT XÂY DỰNG (TECHNICAL ARCHITECTURE)

```
src/Backend/modules/ai/features/ocr/
├── ocr.engine.js         # Vision AI Adapter (Google Gemini Flash / Multimodal LLM / Local Fallback)
├── ocr.service.js        # Điều phối nghiệp vụ OCR + gọi Classify Service + tạo DTO
├── ocr.controller.js     # Controller xử lý upload ảnh (multipart/form-data hoặc base64)
├── ocr.validation.js     # Validate định dạng file ảnh, kích thước ảnh (max 10MB)
└── ocr.routes.js         # Định tuyến API POST /api/ai/ocr/parse
```

### Công nghệ & Mô hình:
* **Online (Backend):** Sử dụng Multimodal Vision LLM (Google Gemini Flash 2.0 / Vision API) với System Prompt trích xuất tiếng Việt có cấu trúc nghiêm ngặt.
* **Offline (Client-app):** Sử dụng Google ML Kit Text Recognition on-device kết hợp Regex Rule Parser tiếng Việt.

---

## 5. ĐẶC TẢ API ENDPOINTS

### 5.1. `POST /api/ai/ocr/parse`
* **Mô tả:** Nhận ảnh hóa đơn $\rightarrow$ OCR bóc tách $\rightarrow$ Gọi AI phân loại danh mục $\rightarrow$ Trả về DTO 2 lựa chọn.
* **Headers:** `Authorization: Bearer <token>`, `Content-Type: multipart/form-data`
* **Body:** `image` (File ảnh `.jpg`, `.png`, `.webp`, `.heic`) hoặc `image_base64` (Chuỗi Base64)

#### Response Success (HTTP 200):
```json
{
  "success": true,
  "message": "Bóc tách và phân loại hóa đơn thành công",
  "data": {
    "invoice_info": {
      "merchant_name": "ĐỒNG MART",
      "merchant_address": "326 Lê Văn Khương, Q.12, TP.HCM",
      "invoice_no": "121023427",
      "transaction_date": "2026-08-30T21:33:37.000Z",
      "total_amount": 57000,
      "vat_amount": 3217,
      "payment_method": "VNPAYQR",
      "image_url": "/uploads/receipts/20260901_abc123.jpg"
    },
    "option_single": {
      "title": "Ghi nhận 1 giao dịch tổng",
      "amount": 57000,
      "suggested_category_id": "61cbe81b-4545-4b8a-8b9d-da88a88035a3",
      "suggested_category_name": "Mua sắm / Siêu thị",
      "suggested_category_icon": "shopping-cart",
      "note": "Đồng Mart: Bột giặt Robot 800g, KTYT FAMAPRO UV, Loạt đồ chơi bong bóng"
    },
    "option_grouped": {
      "title": "Ghi nhận chi tiết theo từng danh mục",
      "total_amount": 57000,
      "groups": [
        {
          "category_id": "61cbe81b-4545-4b8a-8b9d-da88a88035a3",
          "category_name": "Gia dụng",
          "category_icon": "home",
          "group_total": 19000,
          "note": "Đồng Mart: Bột giặt Robot 800g",
          "items": [
            {
              "name": "Bột giặt Robot 800g",
              "quantity": 1,
              "unit_price": 19000,
              "total_price": 19000
            }
          ]
        },
        {
          "category_id": "72ace92c-5656-4c9b-9c0e-eb99b99146b4",
          "category_name": "Y tế & Sức khỏe",
          "category_icon": "medical",
          "group_total": 19000,
          "note": "Đồng Mart: KTYT FAMAPRO UV",
          "items": [
            {
              "name": "KTYT FAMAPRO UV",
              "quantity": 3,
              "unit_price": 6333,
              "total_price": 19000
            }
          ]
        },
        {
          "category_id": "83bdf03d-6767-4d0c-ad1f-fc00ca0257c5",
          "category_name": "Giải trí",
          "category_icon": "game",
          "group_total": 19000,
          "note": "Đồng Mart: Loạt đồ chơi bong bóng 5 0",
          "items": [
            {
              "name": "Loạt đồ chơi bong bóng 5 0",
              "quantity": 1,
              "unit_price": 19000,
              "total_price": 19000
            }
          ]
        }
      ]
    }
  }
}
```

---

## 6. QUY CHUẨN LƯU TRỮ CSDL KHI ĐỒNG BỘ VỀ BACKEND

Khi Client lưu SQLite và Sync Engine đẩy lên bảng `Transaction` của Backend:
* `Idtran`: UUID v4 do Client sinh.
* `Idaccount`: ID tài khoản người dùng.
* `Idwallet`: ID ví thanh toán được chọn.
* `Idcategory`: ID danh mục tương ứng (của nhóm chi tiết hoặc của giao dịch tổng).
* `Amount`: Số tiền thực tế.
* `Type`: `'Transaction'`.
* `Provider`: `'ORC'`.
* `Status`: `'Confirmed'` (do người dùng đã xem và duyệt trên màn hình).
* `DateTransaction`: Ngày giờ trên hóa đơn.
* `Images`: Đường dẫn ảnh hóa đơn đã upload.
