# ĐẶC TẢ NGHIỆP VỤ & KIẾN TRÚC CHỨC NĂNG RECEIPT OCR (MODULE AI)
> **Nguồn sự thật (Single Source of Truth) — Được PO phê duyệt ngày 2026-09-01**

---

## 1. TỔNG QUAN NGHIỆP VỤ (BUSINESS OVERVIEW)

Chức năng **Receipt OCR** trong Module AI cho phép người dùng tự động tạo giao dịch tài chính từ hình ảnh hóa đơn/biên lai chụp từ camera hoặc thư viện ảnh (hóa đơn siêu thị, nhà hàng, tạp hóa, tiền điện/nước...).

### Luồng nghiệp vụ tổng quan:
```
                                  【NGƯỜI DÙNG CHỤP HÓA ĐƠN】
                                               │
                                               ▼
                                 【GỬI YÊU CẦU LÊN BACKEND】
                                 (POST /api/ai/ocr/process)
                                               │
                                               ▼
                              【BACKEND AI OCR BÓC TÁCH JSON】
                         (Merchant, Date, Total, Payment, Items)
                                               │
                                               ▼
                          【TẠO GIAO DỊCH NHÁP (PENDING) VÀO DB】
                       (Áp dụng Phương án C: Gom theo Danh Mục /
                                Idcategory = NULL ban đầu)
                                               │
                                               ▼
                       【KÍCH HOẠT PHÂN LOẠI DANH MỤC (CLASSIFY)】
                         • Có Internet  ──▶ Gọi AI Auto Classification
                         • Mất Internet ──▶ Offline Matcher tại Client
                                               │
                                               ▼
                                 【NGƯỜI DÙNG DUYỆT 1 CHẠM】
                             (POST /api/bank/confirm-transaction
                                ──▶ Status = 'Confirmed')
```

---

## 2. QUY CHUẨN DỮ LIỆU BÓC TÁCH (EXTRACTION SCHEMA)

Khi nhận hình ảnh hóa đơn, tầng AI OCR bóc tách dữ liệu có cấu trúc dạng JSON chuẩn:

```json
{
  "merchant_name": "ĐỒNG MART",
  "merchant_address": "326 Lê Văn Khương, Thới An, Quận 12, TP.HCM",
  "invoice_no": "121023427",
  "transaction_date": "2026-08-30T21:33:37.000Z",
  "total_amount": 57000,
  "vat_amount": 3217,
  "payment_method": "VNPAYQR",
  "raw_text": "...",
  "items": [
    {
      "name": "Bột giặt Robot 800g",
      "quantity": 1,
      "unit_price": 19000,
      "total_price": 19000,
      "category_hint": "Gia dụng"
    },
    {
      "name": "KTYT FAMAPRO UV",
      "quantity": 3,
      "unit_price": 6333,
      "total_price": 19000,
      "category_hint": "Y tế & Sức khỏe"
    },
    {
      "name": "Loạt đồ chơi bong bóng 5 0",
      "quantity": 1,
      "unit_price": 19000,
      "total_price": 19000,
      "category_hint": "Giải trí"
    }
  ]
}
```

---

## 3. ÁNH XẠ DỮ LIỆU VÀO BẢNG `TRANSACTION`

Dữ liệu bóc tách được lưu trữ vào bảng `Transaction` theo đúng cấu trúc CSDL chuẩn:

| Cột CSDL (`Transaction`) | Kiểu Dữ Liệu | Giá Trị & Quy Tắc Ánh Xạ Từ Hóa Đơn |
|---|---|---|
| **`Idtran`** | `VarChar(36)` | UUID v4 (`crypto.randomUUID()`). |
| **`Idaccount`** | `Int` | ID tài khoản người dùng thực hiện tải ảnh. |
| **`Idwallet`** | `VarChar(36)` | ID ví mặc định của người dùng (hoặc ví EWallet/Bank gợi ý dựa trên `payment_method`). |
| **`Idcategory`** | `VarChar(36)` | **`NULL`** khi vừa tạo nháp, chờ module Phân loại danh mục hoạt động & ghi nhận. |
| **`Idwallet_transfer`** | `VarChar(36)` | `NULL` (giao dịch mua hàng, không phải chuyển tiền giữa các ví). |
| **`Bank_tran_id`** | `VarChar(100)` | Mã hóa đơn / Số HĐ trên biên lai (hoặc `NULL`). |
| **`Amount`** | `Decimal(15,2)` | Số tiền chi tiêu thực tế (tương ứng từng nhóm phân loại hoặc tổng hóa đơn). |
| **`Type`** | `VarChar(20)` | Gán mặc định **`'Transaction'`**. |
| **`Provider`** | `VarChar(40)` | Gán mặc định **`'ORC'`** (nhận diện nguồn từ OCR hóa đơn). |
| **`Status`** | `VarChar(10)` | Gán mặc định **`'Pending'`** (chờ người dùng xác nhận). |
| **`Note`** | `Text` | Tên đơn vị bán hàng + Tóm tắt danh sách mặt hàng đã mua. |
| **`Images`** | `Text` | Đường dẫn / URL ảnh hóa đơn đã upload lên Server / Cloud Storage. |
| **`DateTransaction`** | `Timestamp` | Ngày giờ in trên hóa đơn (`transaction_date`). Nếu không có giờ, lấy ngày hiện tại. |
| **`Update_at`** | `Timestamp` | `new Date()`. |
| **`Deleted_at`** | `Timestamp` | `NULL`. |

---

## 4. CHIẾN LƯỢC GOM NHÓM GIAO DỊCH — PHƯƠNG ÁN C (ĐÃ ĐƯỢC DUYỆT)

Khi hóa đơn có nhiều mặt hàng, hệ thống áp dụng **Phương án C (Gom theo Danh Mục / Smart Grouping)**:

### 4.1. Quy tắc Gom nhóm:
1. **Trường hợp 1: Tất cả mặt hàng thuộc CÙNG 1 danh mục**
   * *Ví dụ Hóa đơn Bách Hóa Xanh (79,243đ):* 5 món đều là rau củ quả.
   * *Xử lý:* Tạo **1 giao dịch duy nhất** (`Amount = 79,243đ`, `Status = 'Pending'`, `Idcategory = NULL`).
2. **Trường hợp 2: Hóa đơn gồm NHIỀU mặt hàng thuộc CÁC danh mục khác nhau**
   * *Ví dụ Hóa đơn Đồng Mart (57,000đ):* Gồm Bột giặt (19k), Khẩu trang (19k), Đồ chơi (19k).
   * *Xử lý:* Gom các món cùng loại lại với nhau và tạo thành **3 giao dịch nháp**:
     * Giao dịch 1: `Amount = 19,000đ`, Note: *"Đồng Mart: Bột giặt Robot 800g"*.
     * Giao dịch 2: `Amount = 19,000đ`, Note: *"Đồng Mart: KTYT FAMAPRO UV"*.
     * Giao dịch 3: `Amount = 19,000đ`, Note: *"Đồng Mart: Loạt đồ chơi bong bóng 5 0"*.
   * *Đảm bảo:* Tổng số tiền các giao dịch con luôn khớp **chính xác 100%** với tổng hóa đơn (`19k + 19k + 19k = 57k`).

---

## 5. QUY TRÌNH PHÂN LOẠI DANH MỤC & DUYỆT GIAO DỊCH

1. **Giai đoạn 1 (Lưu nháp):**
   * Backend OCR hoàn tất $\rightarrow$ Lưu `Transaction` với `Status = 'Pending'`, `Idcategory = NULL`.
2. **Giai đoạn 2 (Gán danh mục):**
   * **Khi có kết nối Internet:** Backend tự động gọi Module `AI Auto Classification` để dự đoán `Idcategory` cho từng giao dịch nháp và cập nhật vào `Transaction`.
   * **Khi mất kết nối Internet:** Client-app sử dụng bộ `Offline Keyword Matcher` trên SQLite để tự động điền danh mục gợi ý lên giao diện.
3. **Giai đoạn 3 (Người dùng xác nhận):**
   * Client hiển thị màn hình Review hóa đơn. Người dùng nhấn **"Duyệt tất cả" (1 chạm)** $\rightarrow$ Gọi API xác nhận:
     * Chuyển `Status` từ `'Pending'` $\rightarrow$ `'Confirmed'`.
     * Cập nhật số dư Ví (`Wallet.Balance`).
     * Đưa vào báo cáo chi tiêu và tính toán ngân sách (`Budget`).

---

## 6. DANH SÁCH API ENDPOINTS LIÊN QUAN

| Method | Endpoint | Mô Tả Nghiệp Vụ |
|---|---|---|
| `POST` | `/api/ai/ocr/upload-and-parse` | Upload ảnh hóa đơn (multipart/form-data) $\rightarrow$ OCR bóc tách JSON $\rightarrow$ Tạo giao dịch nháp (`Pending`). |
| `GET` | `/api/ai/ocr/pending-receipts` | Lấy danh sách các giao dịch hóa đơn OCR đang chờ duyệt của tài khoản. |
| `POST` | `/api/bank/confirm-transaction` | Xác nhận duyệt giao dịch nháp (`Status = 'Confirmed'`). |
| `POST` | `/api/bank/reject-transaction` | Từ chối giao dịch nháp (`Status = 'Rejected'`). |

---

## 7. CƠ CHẾ XỬ LÝ NGOẠI LỆ, ẢNH MỜ & THIẾU DỮ LIỆU (EDGE CASES & FALLBACK)

Để đảm bảo tính toàn vẹn dữ liệu cho CSDL và trải nghiệm người dùng tối ưu, hệ thống thiết kế 2 tầng xử lý ngoại lệ:

### 7.1. Trường hợp 1: Nhận diện một phần dữ liệu (Partial Extraction - Ảnh mờ một số vùng)
* **Kịch bản:** Ảnh bị lóa hoặc mờ một số vùng (ví dụ: đọc được các món hàng nhưng mất dòng Tổng tiền, hoặc đọc được Tổng tiền nhưng mất ngày giờ).
* **Thuật toán tự phục hồi (Self-Healing Logic):**
  * *Thiếu Tổng tiền (`total_amount`):* Tự động tính $\text{Tổng tiền} = \sum (\text{Giá các món hàng})$.
  * *Thiếu Danh sách món:* Gán `Note = "[Tên cửa hàng] (Hóa đơn không rõ chi tiết món)"`, `Amount = total_amount`.
  * *Thiếu Ngày giờ (`transaction_date`):* Gán mặc định thời điểm hiện tại `new Date()`.
* **Cơ chế Cảnh báo trên UI:** Backend trả về danh sách `missing_fields: ["amount"]` hoặc `["date"]` $\rightarrow$ Client hiển thị viền đỏ/vàng trên các trường thiếu để người dùng kiểm tra và nhập bổ sung trước khi bấm Duyệt.

### 7.2. Trường hợp 2: Ảnh hoàn toàn không hợp lệ / Mờ 100% (OCR Parse Failed)
* **Kịch bản:** Người dùng chụp ảnh phong cảnh, chụp nhầm ảnh tối đen, hoặc hóa đơn bị vò nát hoàn toàn không thể xác định được số tiền (`Amount` không xác định).
* **Quy tắc CSDL:** **Tuyệt đối KHÔNG tạo bản ghi rác** vào bảng `Transaction`.
* **Quy trình phản hồi (Graceful Degradation):**
  * Backend trả về mã lỗi HTTP 422:
    ```json
    {
      "success": false,
      "error_code": "OCR_PARSE_FAILED",
      "message": "Không thể nhận diện thông tin hóa đơn. Ảnh có thể bị mờ, lóa sáng hoặc chụp thiếu góc.",
      "raw_text": "...",
      "data": null
    }
    ```
  * Client-app hiển thị Modal cứu cánh với 2 lựa chọn:
    1. **"Chụp lại ảnh"**: Bật camera kèm khung ngắm hướng dẫn căn chỉnh 4 góc hóa đơn và bật đèn flash.
    2. **"Nhập tay nhanh"**: Mở màn hình tạo giao dịch thủ công, tự động điền sẵn các từ ngữ bõng bõng đọc được vào ô Ghi chú để người dùng chỉ cần gõ thêm số tiền (tiết kiệm thời gian gõ lại từ đầu).

### 7.3. Trường hợp 3: OCR Bóc Tách Sai Sót Giá Trị & Cho Phép Người Dùng Chỉnh Sửa Trước Khi Xác Nhận
* **Kịch bản:** Do mực in bị nhòe hoặc số bị dính liền, OCR có thể đọc nhầm giá trị (ví dụ: `57.000đ` bị đọc thành `51.000đ`, `30/08` bị đọc thành `30/03`, hoặc gợi ý danh mục chưa đúng ý).
* **Nguyên tắc an toàn:** Giao dịch OCR tạo ra luôn ở trạng thái **`Status = 'Pending'`**, hoàn toàn **chưa trừ tiền vào số dư ví hay ngân sách** nên không gây sai lệch dữ liệu trước khi được người dùng kiểm duyệt.
* **Cơ chế Chỉnh sửa Tương tác trên UI (Interactive Editable Review):**
  * Client hiển thị màn hình đối chiếu trực quan (nửa trên hiển thị ảnh hóa đơn gốc có thể phóng to thu nhỏ, nửa dưới là form giao dịch nháp).
  * Người dùng có quyền chạm vào bất kỳ trường nào để chỉnh sửa trực tiếp trước khi duyệt:
    * Chỉnh sửa **Số tiền** (`Amount`).
    * Chỉnh sửa **Ngày giờ** (`DateTransaction`).
    * Chọn lại **Danh mục** (`Idcategory`) hoặc **Ví thanh toán** (`Idwallet`).
    * Sửa lại **Ghi chú** (`Note`).
* **Cập nhật Backend:**
  * Khi người dùng bấm **"Xác nhận"**, Client gửi payload chứa các giá trị đã chỉnh sửa lên API `POST /api/bank/confirm-transaction`:
    ```json
    {
      "idtran": "28ddb8f0-3463-40ac-8470-2b9aad630d41",
      "amount": 57000,
      "idcategory": "61cbe81b-4545-4b8a-8b9d-da88a88035a3",
      "idwallet": "90e6ba04-a690-4a86-b489-3974c2d4316d",
      "date_transaction": "2026-08-30T21:33:37.000Z",
      "note": "Đồng Mart: Bột giặt Robot, Khẩu trang, Đồ chơi"
    }
    ```
  * Backend cập nhật đè các giá trị chính xác do người dùng điều chỉnh, chuyển `Status` thành `'Confirmed'`, và cập nhật lại số dư ví `Wallet.Balance`.
