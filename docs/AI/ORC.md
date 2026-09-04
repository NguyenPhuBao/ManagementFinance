# ĐẶC TẢ KỸ THUẬT & NGHIỆP VỤ CHỨC NĂNG RECEIPT & BANK TRANSFER OCR (ORC.md)
> **Nguồn sự thật cho chức năng Bóc Tách Hóa Đơn & Biên Lai Chuyển Tiền (Receipt, Bank Transfer & SMS OCR)**  
> *Cập nhật chuẩn hóa phân tách trách nhiệm theo chỉ đạo PO ngày 2026-09-03.*

---

## 1. MÔ TẢ CHỨC NĂNG & PHÂN TÁCH TRÁCH NHIỆM (FEATURE SCOPE & SRP)

Chức năng **Receipt OCR (F013)** trong Module AI đóng vai trò là **Tầng Trích Xuất Thị Giác Máy Tính (Vision & Extraction Layer)**. Hệ thống nhận diện hình ảnh hóa đơn giấy, biên lai chuyển khoản ngân hàng hoặc ảnh chụp màn hình SMS Banking $\rightarrow$ chuyển đổi thành dữ liệu tài chính có cấu trúc.

### 1.1. Phân Tách Trách Nhiệm Rõ Ràng Giữa OCR, Khử Trùng & Classify (Separation of Concerns)

```
[Ảnh người dùng tải lên] 
          │
          ▼
┌────────────────────────────────────────────────────────┐
│  MODULE RECEIPT OCR (Tầng Thị Giác Máy Tính)           │
│  1. Nhận diện hình ảnh & trích xuất văn bản có cấu trúc│
│  2. Gán nhãn Provider: 'ORC' | 'BankSync' | 'SMS'      │
│  3. Trích xuất mã giao dịch Bank_tran_id chống trùng   │
│  4. Tự phục hồi dữ liệu thị giác (Self-Healing)        │
│  5. Bắt lỗi HTTP 422 khi ảnh mờ không đọc được         │
└─────────────────────────┬──────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────────┐
│  BỘ KHỬ TRÙNG LẶP DỮ LIỆU (AI DEDUPLICATION ENGINE)    │
│  - Đối soát CSDL Transaction (Mã GD, STK, Tiền, Ngày)   │
│  - NẾU TRÙNG LẶP:                                      │
│    • Chặn đứng xử lý ngay lập tức!                     │
│    • Bắn thông báo HTTP 409 Conflict lên Client        │
│    • KHÔNG chuyển qua Classify AI (Tiết kiệm 100% token│
│  - NẾU CHƯA CÓ TRONG CSDL:                             │
│    • Cho phép đi tiếp sang Module AI Classify          │
└─────────────────────────┬──────────────────────────────┘
                          │ Đẩy dữ liệu bóc tách sang khi hợp lệ
                          ▼
┌────────────────────────────────────────────────────────┐
│  MODULE AI CLASSIFY (Bộ Não Phân Loại Nghiệp Vụ)       │
│  • Tầng 1: Phân loại 'Transfer' vs 'Transaction'       │
│            dựa trên 3 Cơ sở dữ liệu đối soát CSDL      │
│  • Tầng 2: Phân loại danh mục Idcategory               │
│            - Nếu Transfer: BỎ QUA phân loại danh mục   │
│            - Nếu Transaction: Chạy 3 Tier (Keyword/NLP)│
└─────────────────────────┬──────────────────────────────┘
                          │ Trả dữ liệu đã phân loại về
                          ▼
┌────────────────────────────────────────────────────────┐
│  MODULE RECEIPT OCR (Đóng Gói & Thông Báo)             │
│  1. Đóng gói DTO hoàn chỉnh (Option Single / Grouped)  │
│  2. Gọi sự kiện thông báo (Notification Event)         │
│  3. Đẩy dữ liệu lên Client-app để người dùng xác nhận  │
└────────────────────────────────────────────────────────┘
```

* **Trách nhiệm của Module OCR (`ORC.md`):**
  1. **Thị giác máy tính (Computer Vision):** Nhận diện hình ảnh và trích xuất dữ liệu thô / có cấu trúc.
  2. **Phân loại nguồn tài liệu & Gán Provider:** Nhận biết ảnh là hóa đơn (`RECEIPT` $\rightarrow$ `Provider = 'ORC'`), biên lai ngân hàng (`BANK_TRANSFER` $\rightarrow$ `Provider = 'BankSync'`), hay tin nhắn SMS (`SMS_BANKING` $\rightarrow$ `Provider = 'SMS'`).
  3. **Trích xuất `Bank_tran_id` chống trùng:** Lấy mã giao dịch (FT..., mã GD ngân hàng, số hóa đơn).
  4. **Tự phục hồi dữ liệu thị giác (Self-Healing):** Bóc tách danh sách món, tự cộng dồn tổng tiền khi thiếu, fallback thời gian, bắt lỗi 422 khi ảnh mờ không đọc được.
  5. **Khử trùng lặp dữ liệu trước khi phân loại (Pre-Classification Deduplication):** Kích hoạt bộ đối soát khử trùng lặp CSDL. Nếu giao dịch đã tồn tại $\rightarrow$ chặn đứng, báo lỗi `409 Conflict` kèm thông tin giao dịch cũ, không gọi Classify AI.
  6. **Chuyển giao dữ liệu sang Module AI Classify:** Nếu chưa trùng lặp, đẩy dữ liệu sang `classifyService` để phân loại nghiệp vụ 2 cấp độ.
  7. **Đóng gói & Phát sự kiện:** Nhận lại dữ liệu từ Classify $\rightarrow$ đóng gói DTO phản hồi $\rightarrow$ gọi sự kiện thông báo $\rightarrow$ đẩy dữ liệu về Client-app để người dùng tự xác nhận.

* **Trách nhiệm của Module AI Phân Loại Giao Dịch (`Classify.md`):**
  - **Tầng 1 (Loại giao dịch):** Quyết định đây là `Transfer` (Chuyển tiền nội bộ giữa các ví) hay `Transaction` (Thu/Chi mua bán) dựa trên 3 cơ sở đối soát CSDL.
  - **Tầng 2 (Danh mục):** Khi là `Transaction`, phân loại danh mục thu/chi (`Idcategory`). Khi là `Transfer`, **bỏ qua hoàn toàn phân loại danh mục** (`Idcategory = NULL`).


---

## 2. QUY CHUẨN BÓC TÁCH DỮ LIỆU TỪ HÌNH ẢNH (EXTRACTION SCHEMAS)

### 2.1. Trường Hợp Hóa Đơn Mua Bán Hàng Hóa (`document_type = 'RECEIPT'`)
```json
{
  "document_type": "RECEIPT",
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

### 2.2. Trường Hợp Biên Lai Chuyển Khoản / SMS (`document_type = 'BANK_TRANSFER' | 'SMS_BANKING'`)
```json
{
  "document_type": "BANK_TRANSFER",
  "source_bank": "Vietcombank",
  "source_account": "1012345678",
  "destination_bank": "Techcombank",
  "destination_account": "1903456789",
  "destination_name": "NGUYEN PHU BAO",
  "amount": 5000000,
  "transaction_date": "2026-09-03T10:15:00.000Z",
  "transaction_code": "FT26245981273910",
  "note": "Chuyen tien sang Techcombank chi tieu",
  "raw_text": "..."
}
```

---

## 3. XỬ LÝ THỊ GIÁC & TỰ PHỤC HỒI DỮ LIỆU (VISION PROCESSING & SELF-HEALING)

### 3.1. Bóc Tách 2 Tầng Cho Hóa Đơn: Từng Món Hàng & Giao Dịch Tổng
* **Tầng 1 (Items Level):** Bóc tách chi tiết từng dòng mặt hàng (`name`, `quantity`, `unit_price`, `total_price`).
* **Tầng 2 (Invoice Level):** Bóc tách thông tin toàn bộ hóa đơn (`merchant_name`, `transaction_date`, `total_amount`, `invoice_no`).

### 3.2. Thuật Toán Tự Phục Hồi Dữ Liệu Thị Giác (Self-Healing Logic)
1. **Thiếu dòng Tổng tiền (`total_amount`):** Tự động tính $\text{total\_amount} = \sum (\text{items.total\_price})$.
2. **Không tách được danh sách món hàng:** Hệ thống vẫn trích xuất thành công `total_amount` và tạo bản ghi tổng với `Note = "[Tên cửa hàng] (Hóa đơn không rõ chi tiết món)"`.
3. **Thiếu Ngày giờ in trên hóa đơn (`transaction_date`):** Gán mặc định thời điểm hiện tại `new Date()`.

### 3.3. Xử Lý Ngoại Lệ & Ảnh Không Đọc Được (Error Handling)
* **Kịch bản:** Ảnh chụp bị mờ 100%, lóa sáng, chụp sai đối tượng (không phải hóa đơn/biên lai) dẫn tới không xác định được số tiền hợp lệ.
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

### 3.4. Bộ Quy Tắc Khử Trùng Lặp Dữ Liệu Tại Module AI (AI Deduplication Engine)

Trước khi dữ liệu bóc tách được chuyển giao sang Module AI Classify, Module AI bắt buộc kích hoạt bộ kiểm tra khử trùng lặp dữ liệu đối soát trực tiếp CSDL `transaction`:

* **Quy Tắc 1: Strict Unique Code Matching (Khẳng định 100%)**:
  - Áp dụng khi ảnh bóc tách được mã giao dịch duy nhất `bank_tran_id` (`invoice_no` hoặc mã `transaction_code` ngân hàng/SMS).
  - Đối soát CSDL `transaction`: Tìm bản ghi có `(idaccount, provider, bank_tran_id, deleted_at IS NULL)` hoặc `(provider, bank_tran_id, deleted_at IS NULL)`.
  - Nếu đã tồn tại $\rightarrow$ Khẳng định 100% là giao dịch đã được ghi nhận trước đó.

* **Quy Tắc 2: Fuzzy Invoice Matching (Khi Hóa Đơn Không Có Mã Hóa Đơn)**:
  - Nhiều hóa đơn bán lẻ giấy không in mã số hóa đơn (`invoice_no = null`).
  - Đối soát bộ 4 tiêu chí cùng lúc trong CSDL:
    1. Cùng tài khoản người dùng (`Idaccount`).
    2. Trùng tên đơn vị bán (`merchant_name`, so sánh chữ thường không dấu).
    3. Trùng số tiền thực tế (`amount` chính xác đến từng đồng).
    4. Cùng ngày giao dịch (`date_transaction` trong cùng ngày phát sinh).
  - Nếu thỏa mãn cả 4 điều kiện $\rightarrow$ Xác định trùng lặp hóa đơn.

* **Quy Tắc 3: Transfer / SMS Matching (Khi Biên Lai Không Rõ Mã FT)**:
  - Đối soát: Cùng `Idaccount` + Cùng số tiền `amount` + Cùng ngày `date_transaction` + Trùng số tài khoản nguồn/đích.

* **Hành Động Khi Phát Hiện Trùng Lặp:**
  1. **Chặn Đứng Xử Lý Ngay Lập Tức:** Dừng quy trình, **tuyệt đối không chuyển sang Classify AI**, không chạy Keyword, NLP hay Gemini LLM $\rightarrow$ tiết kiệm 100% token, tài nguyên server và thời gian response.
  2. **Phản Hồi Lỗi Chuẩn HTTP `409 Conflict`:** Trả về mã lỗi `TRANSACTION_ALREADY_EXISTS` kèm toàn bộ thông tin chi tiết của giao dịch cũ đã tồn tại (`existing_transaction`).
  3. **Phát Sự Kiện Realtime:** Gửi thông báo đến Client-app báo giao dịch đã tồn tại để người dùng xem lại.

---

## 4. TÍCH HỢP VỚI MODULE AI PHÂN LOẠI GIAO DỊCH & THÔNG BÁO CLIENT

Quy trình xử lý tuần tự chuẩn hóa:
1. **OCR Engine:** Bóc tách dữ liệu từ ảnh (nhận diện `document_type`, `items`, thông tin tiền tệ, STK).
2. **Gán Provider & Bank_tran_id:**
   - `RECEIPT` $\rightarrow$ `Provider = 'ORC'`.
   - `BANK_TRANSFER` $\rightarrow$ `Provider = 'BankSync'`, `bank_tran_id = extraction.transaction_code`.
   - `SMS_BANKING` $\rightarrow$ `Provider = 'SMS'`, `bank_tran_id = extraction.transaction_code`.
3. **Bộ Khử Trùng Lặp CSDL (AI Deduplication Engine):**
   - Đối soát trong bảng `transaction` của CSDL theo 3 Quy tắc khử trùng.
   - **NẾU TRÙNG:** Chặn đứng xử lý, trả về HTTP `409 Conflict` kèm thông tin giao dịch cũ, phát thông báo và **DỪNG LẠI (không gọi Classify AI)**.
   - **NẾU CHƯA CÓ:** Cho phép đi tiếp bước 4.
4. **Đẩy sang Classify Module (`classifyService.classifyExtractedReceipt`):**
   - Classify Module đối soát CSDL tài khoản/ví người dùng $\rightarrow$ Quyết định `Transfer` vs `Transaction` $\rightarrow$ Phân loại danh mục nếu là `Transaction` (hoặc bỏ qua danh mục nếu là `Transfer`).
5. **Tiếp nhận & Đóng gói DTO:** OCR Service nhận kết quả phân loại từ Classify, đóng gói thành cấu trúc DTO 2 lựa chọn trực quan cho Client.
6. **Kích hoạt sự kiện Thông báo (Notification Event):** Gửi thông báo đến Client-app (qua Socket.IO / EventBus) báo bóc tách hoàn tất.
7. **Người dùng tự xác nhận trên UI:** Client hiển thị dữ liệu để người dùng duyệt lần cuối trước khi lưu vào CSDL.


---

## 5. ĐẶC TẢ API ENDPOINTS & DTO PHẢN HỒI

### 5.1. `POST /api/ai/ocr/parse`
* **Mô tả:** Nhận ảnh hóa đơn / biên lai $\rightarrow$ OCR bóc tách $\rightarrow$ Gọi AI Classify định tuyến $\rightarrow$ Trả về DTO tương ứng.
* **Headers:** `Authorization: Bearer <token>`, `Content-Type: application/json`
* **Body:**
  ```json
  {
    "image_base64": "data:image/jpeg;base64,/9j/4AAQSkZJRgABA...",
    "mimetype": "image/jpeg"
  }
  ```

---

### 5.2. Cấu Trúc DTO Phản Hồi Thành Công (HTTP 200)

#### OUTPUT 1: Khi Là Hóa Đơn Mua Sắm (`document_type: "RECEIPT"`)
*(Classify định tuyến là `Type: "Transaction"`, có AI phân loại danh mục)*
```json
{
  "success": true,
  "message": "Bóc tách và phân loại hóa đơn thành công",
  "data": {
    "document_type": "RECEIPT",
    "detected_type": "Transaction",
    "provider": "ORC",
    "bank_tran_id": null,
    "invoice_info": {
      "merchant_name": "ĐỒNG MART",
      "merchant_address": "326 Lê Văn Khương, Q.12, TP.HCM",
      "invoice_no": "121023427",
      "transaction_date": "2026-08-30T21:33:37.000Z",
      "total_amount": 57000,
      "vat_amount": 3217,
      "payment_method": "VNPAYQR"
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
          "category_name": "Gia dụng & Đồ dùng",
          "category_icon": "home",
          "group_total": 19000,
          "note": "Đồng Mart: Bột giặt Robot 800g",
          "items": [
            {
              "name": "Bột giặt Robot 800g",
              "quantity": 1,
              "unit_price": 19000,
              "total_price": 19000,
              "category_id": "61cbe81b-4545-4b8a-8b9d-da88a88035a3",
              "category_name": "Gia dụng & Đồ dùng",
              "category_icon": "home",
              "note": "Bột giặt Robot 800g"
            }
          ]
        },
        {
          "category_id": "72ace92c-5656-4c9b-9c0e-eb99b99146b4",
          "category_name": "Y tế & Sức khỏe",
          "category_icon": "medical_services",
          "group_total": 19000,
          "note": "Đồng Mart: KTYT FAMAPRO UV",
          "items": [
            {
              "name": "KTYT FAMAPRO UV",
              "quantity": 3,
              "unit_price": 6333,
              "total_price": 19000,
              "category_id": "72ace92c-5656-4c9b-9c0e-eb99b99146b4",
              "category_name": "Y tế & Sức khỏe",
              "category_icon": "medical_services",
              "note": "KTYT FAMAPRO UV"
            }
          ]
        }
      ]
    }
  }
}
```

#### OUTPUT 2: Khi Là Chuyển Tiền Nội Bộ (`detected_type: "Transfer"`)
*(Classify định tuyến là `Transfer` $\rightarrow$ **KHÔNG phân loại danh mục**, `category_id = null`, có `bank_tran_id` chống trùng)*
```json
{
  "success": true,
  "message": "Bóc tách biên lai chuyển tiền nội bộ thành công",
  "data": {
    "document_type": "BANK_TRANSFER",
    "detected_type": "Transfer",
    "provider": "BankSync",
    "bank_tran_id": "FT26245981273910",
    "transfer_details": {
      "amount": 5000000,
      "transaction_date": "2026-09-03T10:15:00.000Z",
      "bank_tran_id": "FT26245981273910",
      "source_bank": "Vietcombank",
      "source_account": "1012345678",
      "source_wallet_id": "wallet-vcb-uuid",
      "source_wallet_name": "Vietcombank - 1012345678",
      "destination_bank": "Techcombank",
      "destination_account": "1903456789",
      "destination_name": "NGUYEN PHU BAO",
      "destination_wallet_id": "wallet-tcb-uuid",
      "destination_wallet_name": "Techcombank - 1903456789",
      "note": "Chuyển tiền sang Techcombank chi tiêu"
    },
    "options": [
      {
        "type": "Transfer",
        "title": "Xác nhận Chuyển tiền nội bộ (Khuyên dùng)",
        "description": "Dịch chuyển tiền giữa 2 tài khoản của bạn — KHÔNG tính vào chi phí",
        "provider": "BankSync",
        "bank_tran_id": "FT26245981273910",
        "from_wallet_id": "wallet-vcb-uuid",
        "to_wallet_id": "wallet-tcb-uuid",
        "category_id": null,
        "amount": 5000000,
        "note": "Chuyển tiền sang Techcombank chi tiêu"
      },
      {
        "type": "Transaction",
        "title": "Chuyển thành Giao dịch Chi tiêu",
        "description": "Nếu đây thực chất là chi phí chuyển cho người khác",
        "provider": "BankSync",
        "bank_tran_id": "FT26245981273910",
        "wallet_id": "wallet-vcb-uuid",
        "category_id": "cat-khac-uuid",
        "category_name": "Chi tiêu khác",
        "amount": 5000000,
        "note": "Chuyển tiền sang Techcombank chi tiêu"
      }
    ]
  }
}
```

#### OUTPUT 3: Khi Là Chuyển Tiền Thanh Toán Cho Bên Thứ 3 (`detected_type: "Transaction"`)
*(Classify định tuyến là `Transaction` $\rightarrow$ Có AI phân loại danh mục, có `bank_tran_id` chống trùng)*
```json
{
  "success": true,
  "message": "Bóc tách biên lai thanh toán thành công",
  "data": {
    "document_type": "BANK_TRANSFER",
    "detected_type": "Transaction",
    "provider": "BankSync",
    "bank_tran_id": "FT26245981273910",
    "transaction_info": {
      "amount": 350000,
      "transaction_date": "2026-09-03T11:20:00.000Z",
      "bank_tran_id": "FT26245981273910",
      "source_bank": "Vietcombank",
      "source_wallet_id": "wallet-vcb-uuid",
      "counterpart_name": "CONG TY TNHH SHOPEE",
      "counterpart_account": "987654321",
      "note": "Thanh toan don hang Shopee 2611"
    },
    "option_single": {
      "title": "Ghi nhận Chi tiêu",
      "provider": "BankSync",
      "bank_tran_id": "FT26245981273910",
      "amount": 350000,
      "wallet_id": "wallet-vcb-uuid",
      "suggested_category_id": "cat-shopee-uuid",
      "suggested_category_name": "Mua sắm online",
      "suggested_category_icon": "shopping_cart",
      "note": "Shopee: Thanh toan don hang Shopee 2611"
    }
  }
}
```

---

### 5.3. Cấu Trúc DTO Phản Hồi Khi Giao Dịch Bị Trùng Lặp (HTTP 409 Conflict)
*(Khi Bộ Khử Trùng Lặp phát hiện hóa đơn / biên lai này đã được ghi nhận trong CSDL trước đó)*

```json
{
  "success": false,
  "error_code": "TRANSACTION_ALREADY_EXISTS",
  "message": "Giao dịch này đã được ghi nhận trên hệ thống trước đó.",
  "data": {
    "is_duplicate": true,
    "reason": "duplicate_bank_tran_id",
    "provider": "ORC",
    "bank_tran_id": "INV-121023427",
    "existing_transaction": {
      "idtran": "tx-uuid-12345",
      "amount": 57000,
      "date_transaction": "2026-08-30T21:33:37.000Z",
      "type": "Transaction",
      "provider": "ORC",
      "bank_tran_id": "INV-121023427",
      "note": "ĐỒNG MART: Bột giặt Robot 800g"
    }
  }
}
```

---

## 6. QUY CHUẨN LƯU TRỮ CSDL KHI ĐỒNG BỘ VỀ BACKEND


Bảng `Transaction` trong CSDL PostgreSQL (Supabase) lưu trữ các trường tương ứng:

| Trường CSDL | Kiểu dữ liệu | Ràng buộc & Ý nghĩa | Khi `Type = 'Transaction'` | Khi `Type = 'Transfer'` |
|---|---|---|---|---|
| **`Idtran`** | `varchar(36)` | PK — UUID v4 do Client sinh | UUID v4 | UUID v4 |
| **`Idaccount`** | `int` | FK Account(Idaccount) | ID tài khoản người dùng | ID tài khoản người dùng |
| **`Idwallet`** | `varchar(36)` | FK Wallet(Idwallet) | Ví thanh toán / Ví chi tiêu | **Ví nguồn** (tiền chuyển đi) |
| **`Idcategory`** | `varchar(36)` | **`NULL`**, FK Category(Idcategory) | **Bắt buộc có ID danh mục** | **`NULL`** *(Transfer không thuộc danh mục nào)* |
| **`Idwallet_transfer`** | `varchar(36)` | **`NULL`**, FK Wallet(Idwallet) | `NULL` | **Ví đích** (tiền chuyển đến) |
| **`Bank_tran_id`** | `varchar(100)` | **`NULL`** — Mã giao dịch chống trùng | `invoice_no` hoặc mã GD (nếu có) | **Mã chuyển khoản (FT...) để chống trùng** |
| **`Amount`** | `decimal(15,2)` | Số tiền thực tế | Số tiền thu/chi | Số tiền chuyển |
| **`Type`** | `varchar(20)` | `'Transaction'` hoặc `'Transfer'` | `'Transaction'` | `'Transfer'` |
| **`Provider`** | `varchar(40)` | `'ORC'`, `'BankSync'`, `'SMS'` | `'ORC'` (Hóa đơn) / `'BankSync'` / `'SMS'` | `'BankSync'` (Biên lai NH) / `'SMS'` |
| **`Status`** | `varchar(10)` | Check in `('Pending', 'Confirmed', 'Rejected', 'Fail')` | `'Confirmed'` | `'Confirmed'` |
| **`DateTransaction`** | `timestamp` | Thời điểm giao dịch thực tế | Ngày trên hóa đơn / biên lai | Ngày trên hóa đơn / biên lai |
| **`Images`** | `text` | Đường dẫn ảnh upload | URL / Tên file ảnh | URL / Tên file ảnh |

> [!NOTE]
> **Cơ chế chống trùng lặp (Idempotency):**  
> Bảng `Transaction` có ràng buộc duy nhất: `@@unique([provider, bank_tran_id])`.  
> Khi `bank_tran_id` được trích xuất từ biên lai hoặc SMS, nếu người dùng vô tình tải lại cùng một hình ảnh, hệ thống sẽ phát hiện và chặn tạo giao dịch trùng lặp, bảo vệ số dư tài khoản an toàn tuyệt đối.

---

## 7. QUY TRÌNH TOÀN DIỆN: ONLINE VS. OFFLINE & VÒNG ĐỜI DỮ LIỆU

### 7.1. Luồng 1: Có Kết Nối Internet (Online Pipeline — Backend Xử Lý)
1. **Client-app:** Người dùng chụp ảnh hóa đơn/biên lai $\rightarrow$ Chuyển Base64 $\rightarrow$ Gửi lên Backend qua `POST /api/ai/ocr/parse`.
2. **Backend Vision & Extraction:** Gemini 2.0 Flash Multimodal Vision đọc ảnh, bóc tách cấu trúc 2 tầng: Từng món hàng con (`items`) và Giao dịch tổng hóa đơn (`total_amount`). Kích hoạt thuật toán Self-healing nếu thiếu tiền/ngày.
3. **Backend Deduplication (Khử trùng CSDL):** Kiểm tra đối soát trực tiếp trên CSDL qua 3 cấp độ (Strict mã đơn/tiền tố `_grp_`, Fuzzy Invoice, Transfer/SMS).
   - *Nếu trùng:* Ném HTTP **`409 Conflict`**, phát sự kiện `ocr.duplicate` và **ngừng ngay lập tức, bỏ qua hoàn toàn Classify AI**.
   - *Nếu chưa trùng:* Cho phép chuyển tiếp sang Classify AI.
4. **Backend AI Classify (Phân loại 2 cấp độ):**
   - *Cấp 1:* Phân loại `Transfer` (chuyển tiền ví) hay `Transaction` (thu/chi). Nếu `Transfer` $\rightarrow$ bỏ qua danh mục (`category_id = null`).
   - *Cấp 2:* Nếu `Transaction` $\rightarrow$ phân loại danh mục cho từng món và giao dịch tổng; gom nhóm các món cùng danh mục thành `option_grouped` (gán sẵn `bank_tran_id = ${base}_grp_${idx+1}` để chống đụng ràng buộc Unique).
5. **Đóng gói & Phản hồi:** Backend trả về DTO hoàn chỉnh (HTTP 200) và phát sự kiện realtime `ocr.completed`.
6. **Client-app Review:** Hiển thị màn hình xác nhận: người dùng chọn ghi nhận theo 1 giao dịch tổng (`option_single`) hoặc nhiều giao dịch con gom nhóm (`option_grouped`).
7. **Lưu SQLite & Đồng bộ:** Người dùng bấm xác nhận $\rightarrow$ Client-app sinh `UUID v4`, gán `status = 'Confirmed'`, tính toán và cập nhật lại số dư ví trong bảng `wallet` SQLite $\rightarrow$ Đưa vào `SyncQueue` đồng bộ về Backend qua `POST /api/sync/batch`.

---

### 7.2. Luồng 2: Không Có Kết Nối Internet (Offline Pipeline — Client Xử Lý Cục Bộ)
1. **Client-app:** Người dùng chụp ảnh hóa đơn/biên lai khi thiết bị đang ở chế độ Ngoại tuyến (Offline).
2. **On-Device OCR:** Client-app kích hoạt engine OCR cục bộ trên máy (Google ML Kit Text Recognition / Tesseract) để trích xuất văn bản từ hình ảnh.
3. **Local Deduplication:** Client-app truy vấn SQLite kiểm tra nhanh xem hóa đơn/mã giao dịch này đã có trong máy hay chưa để cảnh báo người dùng nếu quét trùng.
4. **Offline Keyword Matcher:** Sử dụng bộ so khớp từ khóa cục bộ (đọc cột `Category.Keyword` của các danh mục trong SQLite) để phân loại từng món hàng và giao dịch tổng.
5. **Gom nhóm danh mục:** Gom các món hàng có cùng danh mục lại với nhau tương tự như logic Backend.
6. **Client-app Review:** Hiển thị màn hình xác nhận giao dịch để người dùng kiểm tra, chỉnh sửa thông tin.
7. **Lưu SQLite & Chờ Sync:** Người dùng xác nhận $\rightarrow$ Client sinh `UUID v4`, gán `status = 'Confirmed'`, cập nhật số dư ví trong SQLite $\rightarrow$ Đưa vào hàng đợi `SyncQueue` để tự động đẩy lên Backend khi có kết nối Internet trở lại.

> [!TIP]
> **Khác biệt cốt lõi giữa Online và Offline:**
> - **Online (Backend):** Sử dụng Multimodal LLM (Gemini 2.0 Flash) có trí tuệ nhân tạo sâu, hiểu ngữ cảnh phức tạp, tự sửa lỗi hóa đơn (Self-healing), độ chính xác rất cao.
> - **Offline (Client):** Sử dụng OCR ký tự trên máy + Keyword Matcher đơn giản, do đó kết quả bóc tách có thể thô hơn. Giao diện Client cần hỗ trợ người dùng chỉnh sửa tay linh hoạt trước khi lưu.

---

### 7.3. Xử Lý Các Kịch Bản Chuyển Đổi Trạng Thái Mạng Đột Ngột
* **Trường hợp 1: Đang chạy luồng Offline mà có mạng bất ngờ:**
  - *Quy tắc:* **Vẫn tiếp tục hoàn thành theo luồng Offline**.
  - *Lý do:* Đảm bảo tính nhất quán trạng thái (State Consistency) của ứng dụng, không làm gián đoạn màn hình nhập liệu và trải nghiệm người dùng giữa chừng.
* **Trường hợp 2: Đang chạy luồng Online mà bị mất mạng đột ngột:**
  - *Tại Client-app:* Khi chưa nhận được dữ liệu phản hồi từ Backend (bị Timeout / SocketException), Client-app bắt lỗi mạng, hiển thị thông báo gián đoạn và dừng quy trình tạo giao dịch. Tuyệt đối không ghi nhận dữ liệu dở dang vào SQLite, số dư ví không bị biến động.
  - *Tại Backend:* Request vẫn được xử lý xong trong tiến trình, nhưng khi gửi phản hồi thấy socket đã ngắt kết nối thì tự động kết thúc quy trình mà không hề ảnh hưởng đến hệ thống.

---

### 7.4. Vòng Đời Dữ Liệu & Giải Đáp Thắc Mắc Kỹ Thuật (Data Lifecycle in Stateless Architecture)

> [!IMPORTANT]
> **Thắc mắc của PO:** *"Vì Backend tuyệt đối không ghi nhận dữ liệu ORC trước khi có sự xác nhận của người dùng, vậy khi client-app mất internet, dữ liệu giao dịch ORC đó đi đâu?"*

**1. Về phía Backend (Server):**
* **Kiến trúc Stateless & In-Memory:** Toàn bộ dữ liệu của quá trình xử lý OCR (ảnh Base64, kết quả bóc tách, DTO phân loại) **chỉ tồn tại trong bộ nhớ RAM (`In-Memory`)** của tiến trình Node.js xử lý request đó.
* Backend **KHÔNG ghi bất kỳ bản ghi nào vào CSDL Supabase PostgreSQL** tại bước này.
* Khi Client rớt mạng:
  * Phản hồi HTTP không gửi được do đường truyền đứt.
  * Khi hàm controller kết thúc, **Bộ gom rác tự động của Node.js (Garbage Collector)** sẽ tự động dọn dẹp và thu hồi toàn bộ vùng nhớ RAM chứa các object/DTO này.
  * Dữ liệu bóc tách đó **hoàn toàn biến mất khỏi hệ thống**. CSDL Cloud sạch sẽ 100%, không phát sinh "bản ghi rác" hay "giao dịch ma".

**2. Về phía Client-App (Thiết bị):**
* Client-app bắt ngoại lệ mất mạng, thông báo cho người dùng và dừng tiến trình.
* Do **chưa từng nhận được DTO phản hồi**, Client-app không mở màn hình Review và **không có bất kỳ dòng dữ liệu nào được ghi vào SQLite**.
* Số dư ví (`balance`) của người dùng an toàn nguyên vẹn 100%.

**3. Lợi thế tối thượng khi người dùng quét lại:**
* Do lần quét trước chưa từng được ghi vào CSDL (cả Cloud lẫn SQLite), nên khi người dùng có mạng trở lại và chụp quét lại bức ảnh đó:
  * Bộ **AI Deduplication Engine** của Backend kiểm tra trong DB thấy chưa tồn tại $\rightarrow$ **không bị chặn nhầm**.
  * Hóa đơn tiếp tục được bóc tách và phân loại thành công như một giao dịch mới bình thường!

