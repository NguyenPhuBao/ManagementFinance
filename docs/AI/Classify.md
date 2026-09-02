# ĐẶC TẢ KỸ THUẬT & NGHIỆP VỤ CHỨC NĂNG AI PHÂN LOẠI GIAO DỊCH (Classify.md)
> **Nguồn sự thật cho chức năng Phân Loại Giao Dịch Bằng Trí Tuệ Nhân Tạo (AI Transaction Classification)**  
> *Được PO phê duyệt ngày 2026-09-02.*

---

## 1. MÔ TẢ CHỨC NĂNG (FEATURE OVERVIEW)

Chức năng **AI Phân Loại Giao Dịch (AI Transaction Classification)** trong Module AI đóng vai trò là "bộ não định tuyến tài chính", tự động phân tích nội dung, tên đơn vị thụ hưởng, tên mặt hàng và số tiền để dự đoán danh mục thu/chi (`Category.Idcategory`) phù hợp nhất cho người dùng.

### 1.1. Phạm vi áp dụng đa kênh:
1. **Receipt OCR**: Phân loại từng món hàng bóc tách từ hóa đơn và phân loại danh mục tổng.
2. **BankSync (Casso)**: Phân loại giao dịch biến động số dư từ ngân hàng (chuỗi chuyển khoản không dấu).
3. **SMS Banking**: Phân loại tin nhắn biến động số dư từ SMS.
4. **Nhập tay (Manual Entry)**: Gợi ý tức thì danh mục khi người dùng gõ vào ô ghi chú.

### 1.2. So sánh: Máy Học Cục Bộ (Local ML) vs Gọi API Key AI (Cloud LLM)
Để giải quyết bài toán phân loại, có 2 trường phái công nghệ chính:

| Tiêu Chí So Sánh | Máy Học Cục Bộ (Local ML Model) | Gọi API Key AI (Cloud LLM - Gemini/OpenAI) |
|---|---|---|
| **Bản chất** | Mô hình phân loại văn bản (NLP / TF-IDF / Naive Bayes / PhoBERT) nhúng và chạy trực tiếp trên Server/Device. | Gọi API sang cụm máy chủ đám mây của Google (Gemini 1.5/2.0 Flash) hoặc OpenAI (GPT-4o mini). |
| **Chi phí vận hành** | **0 VNĐ (Hoàn toàn miễn phí)**, không tốn chi phí mua token / API quota. | Tốn phí theo lượt gọi (hoặc bị giới hạn hạn ngạch Free Tier). |
| **Tốc độ phản hồi** | **Cực nhanh (5 - 15ms)**, phản hồi tức thì khi người dùng gõ phím. | Trung bình ($200 - 500ms$) do độ trễ truyền dữ liệu qua Internet. |
| **Khả năng hiểu từ ngữ** | Phụ thuộc vào tập dữ liệu huấn luyện. Khó đoán từ mới lạ nếu chưa có trong dataset. | **Cực kỳ thông minh**, hiểu được tiếng lóng, tên viết tắt, tiếng Việt không dấu và ngữ cảnh phức tạp. |
| **Tính độc lập & Ổn định** | Chạy 100% trên hạ tầng nội bộ, không phụ thuộc bên thứ 3, không lo hết hạn API Key. | Phụ thuộc vào trạng thái server ngoài và kết nối mạng. |

### 1.3. Lựa chọn thiết kế hệ thống: Mô Hình Lai (Hybrid 3 Tầng)
Dự án áp dụng **Mô hình Lai (Hybrid Architecture)** để tối ưu hóa đồng thời cả 3 yếu tố: **Tốc độ**, **Chi phí (0đ cho phần lớn giao dịch)** và **Độ chính xác cao**:
* **Tại Client-app (Chế độ Offline):** Chạy thuật toán **Keyword & Rule Matcher cục bộ trên SQLite** $\rightarrow$ Hoạt động 100% không cần mạng, không cần API Key, tốc độ $< 5ms$.
* **Tại Backend (Chế độ Online):**
  * **Tầng 1 (Keyword Matcher)** & **Tầng 2 (Local Machine Learning Model)**: Nhúng trực tiếp trong mã nguồn Node.js để giải quyết $80\%$ các giao dịch quen thuộc một cách tức thì ($5 - 15ms$) mà không tiêu tốn hạn ngạch API.
  * **Tầng 3 (Cloud LLM API Key - Google Gemini Flash)**: Chỉ kích hoạt khi Tầng 1 và Tầng 2 không đạt độ tin cậy ($\text{Confidence} < 0.60$) hoặc gặp các hóa đơn viết tắt, tiếng lóng phức tạp.

---

## 2. NGUỒN DỮ LIỆU ĐẦU VÀO CỦA AI PHÂN LOẠI GIAO DỊCH (INPUT DATA SOURCES)

Để đưa ra dự đoán chính xác và mang tính cá nhân hóa cao nhất, bộ phân loại AI tiếp nhận **2 nguồn dữ liệu kết hợp**:

```
 ┌────────────────────────────────────────┐       ┌────────────────────────────────────────┐
 │   NGUỒN 1: DỮ LIỆU GIAO DỊCH ĐẦU VÀO   │       │   NGUỒN 2: DỮ LIỆU CSDL CỦA USER       │
 │   • OCR Hóa đơn (Tên món, Cửa hàng)    │   +   │   • Bảng Category của User trong DB    │
 │   • BankSync (Nội dung chuyển khoản)   │       │   • Bộ từ khóa Category.Keyword        │
 │   • SMS Banking / Nhập tay             │       │   • Danh mục mặc định + Tự tạo         │
 └───────────────────┬────────────────────┘       └───────────────────┬────────────────────┘
                     │                                                │
                     └───────────────────────┬────────────────────────┘
                                             ▼
                              【BỘ PHÂN LOẠI AI ĐỐI SOÁT】
                                             │
                                             ▼
                             【XÁC ĐỊNH IDCATEGORY CHUẨN XÁC】
```

### 2.1. Nguồn 1: Dữ liệu giao dịch phát sinh
* **Từ Receipt OCR:** Tên sản phẩm/dịch vụ (`name`), đơn giá, tên đơn vị bán hàng (`merchant_name`).
* **Từ BankSync (Casso):** Chuỗi diễn giải chuyển khoản (`description`), số tiền, tài khoản đối ứng.
* **Từ SMS Banking:** Nội dung tin nhắn biến động số dư (đã qua regex bóc tách).
* **Từ Nhập tay:** Nội dung văn bản người dùng gõ vào ô Ghi chú (`Note`).

### 2.2. Nguồn 2: Dữ liệu đối soát từ CSDL Category của người dùng
AI không phân loại một cách chung chung mà **bắt buộc phải lấy dữ liệu từ bảng `Category` của chính tài khoản (`idaccount`)** để làm căn cứ đối soát:
* `Idcategory`: Khóa chính UUID của danh mục để gán vào giao dịch.
* `NameCategory`: Tên hiển thị của danh mục *(Ví dụ: "Ăn uống", "Gia dụng", "Trà sữa")*.
* `Classify`: Loại danh mục (`Thu`, `Chi`, `Vay/nợ`).
* `Keyword`: **Bộ từ khóa nhận diện danh mục** (chuỗi từ khóa phân cách bởi dấu `;`, ví dụ: `"bot giat; nuoc xa; com trua; grab"`).
* `Is_default` & `Idgroup`: Cấu trúc phân cấp cha/con của danh mục.

---

## 3. MẪU DỮ LIỆU ĐẦU VÀO TỪ RECEIPT OCR (OCR INPUT SAMPLES)

Dưới đây là mẫu dữ liệu bóc tách từ hóa đơn thực tế (ví dụ Hóa đơn Siêu thị Đồng Mart - 57,000đ) được đưa vào làm đầu vào cho Module AI Phân loại:

### 3.1. Dữ liệu đầu vào cho Giao Dịch Tổng Hóa Đơn:
```json
{
  "type": "summary_invoice",
  "text": "ĐỒNG MART - 326 Lê Văn Khương. Bột giặt Robot 800g, KTYT FAMAPRO UV, Loạt đồ chơi bong bóng",
  "merchant_name": "ĐỒNG MART",
  "total_amount": 57000
}
```
* **Kết quả đối soát:** AI phân tích tên siêu thị "ĐỒNG MART" $\rightarrow$ Khớp danh mục **`Mua sắm / Siêu thị`** (`Idcategory`: `61cbe81b-...`).

### 3.2. Dữ liệu đầu vào cho Từng Món Hàng Riêng Lẻ:
```json
{
  "type": "item_batch",
  "merchant_name": "ĐỒNG MART",
  "items": [
    {
      "item_id": "item_1",
      "text": "Bột giặt Robot 800g",
      "amount": 19000
    },
    {
      "item_id": "item_2",
      "text": "KTYT FAMAPRO UV",
      "amount": 19000
    },
    {
      "item_id": "item_3",
      "text": "Loạt đồ chơi bong bóng 5 0",
      "amount": 19000
    }
  ]
}
```

### 3.3. Đối soát với Bộ Từ Khóa (`Category.Keyword`) trong CSDL:
| Mặt Hàng Đầu Vào | Từ Khóa Khớp Trong CSDL (`Category.Keyword`) | Danh Mục Trúng Khớp | `Idcategory` Trả Về |
|---|---|---|---|
| `"Bột giặt Robot 800g"` | `bot giat; robot; gia dung; xà phòng; nuoc tay` | **Gia dụng** | `61cbe81b-4545-4b8a-8b9d-da88a88035a3` |
| `"KTYT FAMAPRO UV"` | `ktyt; famapro; khau trang; y te; thuoc` | **Y tế & Sức khỏe** | `72ace92c-5656-4c9b-9c0e-eb99b99146b4` |
| `"Loạt đồ chơi bong bóng 5 0"` | `do choi; bong bong; giai tri; game` | **Giải trí** | `83bdf03d-6767-4d0c-ad1f-fc00ca0257c5` |

---

## 4. MẪU DỮ LIỆU ĐẦU VÀO TỪ SMS BANKING & BỘ TEMPLATE CHUẨN HÓA (SMS BANKING NORMALIZED SCHEMA)

Dựa trên việc khảo sát và bóc tách thực tế các mẫu thông báo biến động số dư từ các ngân hàng (BIDV, MBBank, Techcombank), hệ thống thiết lập một **bộ Template Data chuẩn hóa duy nhất** dùng chung cho tất cả các ngân hàng tại Việt Nam.

### 4.1. Bảng Phân Tích & Đối Soát Đặc Trưng Biến Động Số Dư Các Ngân Hàng:

| Trường Thông Tin | BIDV (`SmartBanking`) | MB Bank (`MB Bank`) | Techcombank (`Techcombank`) | Thuộc Tính Chuẩn Hóa | Ràng Buộc |
|---|---|---|---|---|---|
| **Tên Ngân Hàng** | `SmartBanking` / `BIDV` | `MB Bank` | `Techcombank` | `bank_name` (String) | **Bắt buộc** |
| **Số Tài Khoản** | `5111012066` | `25xxx999` (dạng mask) | `5555047777777` | `account_number` (String) | **Bắt buộc** |
| **Số Tiền Giao Dịch** | `-1,199,000 VND` | `+1,200,000VND` / `-1,200,000VND` | `+ VND 208,080` | `amount` (Number, giữ dấu $\pm$) | **Bắt buộc** |
| **Loại Biến Động** | Trừ tiền (dấu `-`) | Nhận tiền (`+`) / Trừ tiền (`-`) | Cộng tiền (`+`) | `transaction_type` (`INCOME`/`EXPENSE`) | **Bắt buộc** |
| **Thời Gian GD** | `10:52 02/09/2026` | `02/09/26 15:33` | `02/09/2026 10:57:56` | `transaction_date` (ISO Datetime) | **Bắt buộc** |
| **Số Dư Sau GD** | `110 VND` | `1,200,007VND` / `7VND` | `VND 218,042` | `balance_after` (Number) | *Nullable* |
| **Đối Tác GD (Gửi/Nhận)** | Không tách (gộp trong ND) | `TU: NGUYEN PHU BAO` / `DEN: NGUYEN PHU BAO` | Không tách (gộp trong chuỗi) | `counterpart_name` / `counterpart_account` | *Nullable* |
| **Nội Dung Diễn Giải** | `CASHINMOMO_0355281276_...` | `NGUYEN PHU BAO Chuyen tien...` / `Bien dong so du...` | `RUT VI MOMO 040204008977...` | `description` (String) | **Bắt buộc** (Input chính cho AI) |
| **Mã Giao Dịch / Ref** | `055104Tm-8BoOcczKT` | `ACSP/ 9l191181` | `144879146167` | `bank_tran_id` (String) | *Nullable* (dùng chống trùng) |
| **Văn Bản Thô** | Toàn bộ nội dung thông báo | Toàn bộ nội dung thông báo | Toàn bộ nội dung thông báo | `raw_text` (String) | **Bắt buộc** |

---

### 4.2. Bộ Template Data Chuẩn Hóa (Standard Normalized Schema):
```json
{
  "bank_name": "MBBank",
  "account_number": "25xxx999",
  "amount": -1200000,
  "currency": "VND",
  "transaction_type": "EXPENSE",
  "transaction_date": "2026-09-02T15:29:00.000Z",
  "balance_after": 7,
  "counterpart_name": "NGUYEN PHU BAO",
  "counterpart_account": "51110001012066",
  "description": "Bien dong so du mbbank bidv",
  "bank_tran_id": "ACSP/ 9l191181",
  "raw_text": "MB Bank 03:29 PM Thông báo biến động số dư TK 25xxx999|GD: -1,200,000VND 02/09/26 15:29 |SD: 7VND|DEN: NGUYEN PHU BAO - 51110001012066|ND: Bien dong so du mbbank bidv"
}
```

---

### 4.3. Các Mẫu Dữ Liệu Thực Tế Từ 5 Trường Hợp SMS Banking & Đối Soát AI:

#### Mẫu 1: BIDV — Nạp tiền Ví MoMo (`BIDV(1).jpg`)
```json
{
  "bank_name": "BIDV",
  "account_number": "5111012066",
  "amount": -1199000,
  "transaction_type": "EXPENSE",
  "transaction_date": "2026-09-02T10:52:00.000Z",
  "balance_after": 110,
  "counterpart_name": null,
  "counterpart_account": null,
  "description": "CASHINMOMO_0355281276_144878879528",
  "bank_tran_id": "055104Tm-8BoOcczKT",
  "raw_text": "SmartBanking 10:53 AM Thông báo BIDV Thời gian giao dịch: 10:52 02/09/2026 Tài khoản thanh toán: 5111012066 Số tiền GD: -1,199,000 VND Số dư cuối: 110 VND Nội dung giao dịch: CASHINMOMO_0355281276_144878879528 Mã giao dịch: 055104Tm-8BoOcczKT"
}
```
* **AI Đối soát Từ Khóa:** Phát hiện từ khóa `"CASHINMOMO"` / `"MOMO"` $\rightarrow$ Khớp `Category.Keyword: "momo; nap vi; chuyen vi; cashin"` $\rightarrow$ Gợi ý danh mục: **`Chuyển tiền Ví điện tử`** (hoặc Giao dịch chuyển tiền nội bộ).

#### Mẫu 2: MB Bank — Nhận tiền từ tài khoản khác (`MBBank_NhanTien(1).jpg`)
```json
{
  "bank_name": "MBBank",
  "account_number": "25xxx999",
  "amount": 1200000,
  "transaction_type": "INCOME",
  "transaction_date": "2026-09-02T15:33:00.000Z",
  "balance_after": 1200007,
  "counterpart_name": "NGUYEN PHU BAO",
  "counterpart_account": "5111012066",
  "description": "NGUYEN PHU BAO Chuyen tien- Ma GD ACSP/ 9l191181",
  "bank_tran_id": "ACSP/ 9l191181",
  "raw_text": "MB Bank 03:33 PM Thông báo biến động số dư TK 25xxx999|GD: +1,200,000VND 02/09/26 15:33 |SD: 1,200,007VND|TU: NGUYEN PHU BAO - 5111012066|ND: NGUYEN PHU BAO Chuyen tien- Ma GD ACSP/ 9l191181"
}
```
* **AI Đối soát Từ Khóa:** Phát hiện `transaction_type = INCOME`, `counterpart_name = "NGUYEN PHU BAO"` (cùng tên chủ tài khoản) $\rightarrow$ Khớp quy tắc chuyển tiền giữa các tài khoản của cùng một người $\rightarrow$ Gợi ý danh mục: **`Chuyển khoản nội bộ`** hoặc **`Thu nhập khác`**.

#### Mẫu 3: MB Bank — Trừ tiền chuyển khoản (`MBBank_TruTien(1).jpg`)
```json
{
  "bank_name": "MBBank",
  "account_number": "25xxx999",
  "amount": -1200000,
  "transaction_type": "EXPENSE",
  "transaction_date": "2026-09-02T15:29:00.000Z",
  "balance_after": 7,
  "counterpart_name": "NGUYEN PHU BAO",
  "counterpart_account": "51110001012066",
  "description": "Bien dong so du mbbank bidv",
  "bank_tran_id": null,
  "raw_text": "MB Bank 03:29 PM Thông báo biến động số dư TK 25xxx999|GD: -1,200,000VND 02/09/26 15:29 |SD: 7VND|DEN: NGUYEN PHU BAO - 51110001012066|ND: Bien dong so du mbbank bidv"
}
```
* **AI Đối soát Từ Khóa:** Phát hiện `"mbbank bidv"` $\rightarrow$ Gợi ý: **`Chuyển tiền giữa các ngân hàng`**.

#### Mẫu 4: MB Bank — Rút tiền từ MoMo về tài khoản (`MBBank_momo(1).jpg`)
```json
{
  "bank_name": "MBBank",
  "account_number": "25xxx999",
  "amount": 1000000,
  "transaction_type": "INCOME",
  "transaction_date": "2026-09-02T11:02:00.000Z",
  "balance_after": 1200007,
  "counterpart_name": null,
  "counterpart_account": null,
  "description": "MOMO-CASHOUT-0355281276-OQCOeloMiFpw-144880413722",
  "bank_tran_id": "144880413722",
  "raw_text": "MB Bank 11:02 AM Thông báo biến động số dư TK 25xxx999|GD: +1,000,000VND 02/09/26 11:02 |SD: 1,200,007VND|ND: MOMO-CASHOUT-0355281276-OQCOeloMiFpw-144880413722"
}
```
* **AI Đối soát Từ Khóa:** Phát hiện `"MOMO-CASHOUT"` $\rightarrow$ Khớp `Category.Keyword: "momo; cashout; rut vi"` $\rightarrow$ Gợi ý danh mục: **`Rút tiền Ví điện tử`**.

#### Mẫu 5: Techcombank — Rút tiền Ví MoMo (`Techcombank(1).jpg`)
```json
{
  "bank_name": "Techcombank",
  "account_number": "5555047777777",
  "amount": 208080,
  "transaction_type": "INCOME",
  "transaction_date": "2026-09-02T10:57:56.000Z",
  "balance_after": 218042,
  "counterpart_name": null,
  "counterpart_account": null,
  "description": "RUT VI MOMO 040204008977 208080 VND 02/09/2026 10:57:56 144879146167",
  "bank_tran_id": "144879146167",
  "raw_text": "Techcombank 10:58 AM + VND 208,080 Tài khoản: 5555047777777 Số dư: VND 218,042 RUT VI MOMO 040204008977 208080 VND 02/09/2026 10:57:56 144879146167"
}
```
* **AI Đối soát Từ Khóa:** Phát hiện `"RUT VI MOMO"` $\rightarrow$ Khớp `Category.Keyword: "momo; rut vi"` $\rightarrow$ Gợi ý danh mục: **`Rút tiền Ví điện tử`**.

---

## 5. MẪU DỮ LIỆU ĐẦU VÀO TỪ CASSO BANKSYNC (CASSO OPEN BANKING INPUT SAMPLES)

Đối với các giao dịch tự động đồng bộ từ ngân hàng qua cổng **Casso Open Banking API v2**, dữ liệu đầu vào đưa vào Module AI Phân loại có định dạng JSON chuẩn:

### 5.1. Bảng Đối Soát Dữ Liệu Casso Đầu Vào:
* `tid`: Mã giao dịch ngân hàng (FT Code) $\rightarrow$ Lưu vào `Transaction.Bank_tran_id` chống trùng.
* `description`: Diễn giải giao dịch $\rightarrow$ **Input chính để AI bóc tách từ khóa**.
* `amount`: Số tiền biến động.
* `corresponsiveName` & `corresponsiveAccount`: Thông tin đối tác chuyển tiền (hỗ trợ phân biệt cá nhân vs doanh nghiệp / chuyển khoản nội bộ).

### 5.2. Các Mẫu Dữ Liệu Casso Thực Tế & Đối Soát AI:

#### Mẫu 1: Chi tiêu ăn uống / Cafe (`HIGHLANDS COFFEE`)
```json
{
  "source": "casso_banksync",
  "tid": "FT26245981273910",
  "description": "MBVCB.12938471.HIGHLANDS COFFEE.Thanh toan cafe",
  "amount": 65000,
  "corresponsiveName": "CONG TY CP DICH VU CA PHE CAO NGUYEN",
  "corresponsiveAccount": "0123456789"
}
```
* **AI Đối soát Từ Khóa:** Bóc tách `"HIGHLANDS COFFEE"` $\rightarrow$ Khớp `Category.Keyword: "highlands; cafe; ca phe; tra sua; an uong"` $\rightarrow$ Gợi ý danh mục: **`Ăn uống / Cafe`** (`Idcategory: 61cbe81b-...`).

#### Mẫu 2: Thanh toán Hóa đơn Tiền Điện (`EVN HANOI`)
```json
{
  "source": "casso_banksync",
  "tid": "FT26245981273922",
  "description": "THANH TOAN TIEN DIEN EVN HANOI PE01000234918",
  "amount": 854000,
  "corresponsiveName": "TONG CONG TY DIEN LUC TP HA NOI",
  "corresponsiveAccount": "9876543210"
}
```
* **AI Đối soát Từ Khóa:** Bóc tách `"TIEN DIEN"` / `"EVN"` $\rightarrow$ Khớp `Category.Keyword: "tien dien; evn; dien luc; hoa don"` $\rightarrow$ Gợi ý danh mục: **`Hóa đơn & Tiện ích / Tiền điện`** (`Idcategory: 72ace92c-...`).

#### Mẫu 3: Nhận tiền Lương hàng tháng (`CONG TY TRA LUONG`)
```json
{
  "source": "casso_banksync",
  "tid": "FT26245981273935",
  "description": "CTY TNHH CONG NGHE ABC TRA LUONG THANG 08/2026 CHO NGUYEN PHU BAO",
  "amount": 25000000,
  "corresponsiveName": "CONG TY TNHH CONG NGHE ABC",
  "corresponsiveAccount": "1122334455"
}
```
* **AI Đối soát Từ Khóa:** Bóc tách `"TRA LUONG"` / `"LUONG THANG"` $\rightarrow$ Khớp `Category.Keyword: "luong; salary; tra luong; thu nhap"` $\rightarrow$ Gợi ý danh mục: **`Thu nhập / Lương`** (`Idcategory: 83bdf03d-...`).

---

## 6. CẤU TRÚC DỮ LIỆU ĐẦU RA THEO TỪNG KỊCH BẢN (OUTPUT SPECIFICATION & DTO SCHEMA)

Đầu ra của chức năng AI Phân Loại Giao Dịch được chuẩn hóa thành Data Transfer Object (DTO) phục vụ trực tiếp cho việc hiển thị trên Client-app và ghi nhận vào CSDL.

### 6.1. Bảng Chi Tiết Các Trường Dữ Liệu Đầu Ra (Core Output Schema):

| Tên Trường (Field) | Kiểu Dữ Liệu | Ý Nghĩa Kỹ Thuật & Nghiệp Vụ |
|---|---|---|
| **`category_id`** | `UUID (String)` | Khóa chính của danh mục dự đoán trong CSDL (`Category.Idcategory`) để gán trực tiếp vào giao dịch. |
| **`category_name`** | `String` | Tên hiển thị của danh mục *(Ví dụ: "Ăn uống", "Gia dụng", "Y tế & Sức khỏe", "Tiền điện")*. |
| **`category_icon`** | `String` | Tên icon đại diện của danh mục để Client-app render giao diện *(Ví dụ: "restaurant", "shopping_cart", "bolt")*. |
| **`classify`** | `Enum (String)` | Phân loại thu chi của danh mục: `'Chi'`, `'Thu'` hoặc `'Vay/nợ'`. |
| **`confidence`** | `Number (0.0 - 1.0)` | **Chỉ số tin cậy** của AI đối với dự đoán này *(Ví dụ: `0.95` là rất chắc chắn, `0.45` là mơ hồ)*. |
| **`tier_used`** | `String` | Tầng AI đã đưa ra kết quả: `'tier1_keyword'`, `'tier2_nlp'` hoặc `'tier3_llm'`. |
| **`suggested_categories`** *(Optional)* | `Array[Object]` | Danh sách **Top 3 danh mục gợi ý phụ** (khi `confidence` ở mức trung bình $0.50 - 0.80$) để người dùng chạm đổi nhanh trên giao diện. |

---

### 6.2. Cấu Trúc Đầu Ra Theo Từng Kịch Bản Sử Dụng:

#### Kịch Bản A: Phân Loại Giao Dịch Đơn Lẻ (`POST /api/ai/classify/single`)
*Áp dụng cho: Giao dịch từ Casso BankSync, SMS Banking, Nhập tay, hoặc giao dịch tổng hóa đơn.*

```json
{
  "success": true,
  "data": {
    "category_id": "61cbe81b-4545-4b8a-8b9d-da88a88035a3",
    "category_name": "Gia dụng",
    "category_icon": "home",
    "classify": "Chi",
    "confidence": 0.95,
    "tier_used": "tier1_keyword",
    "suggested_categories": [
      { "id": "61cbe81b-4545-4b8a-8b9d-da88a88035a3", "name": "Gia dụng", "icon": "home" },
      { "id": "92fba12a-5656-4c9b-9c0e-eb99b99146b4", "name": "Mua sắm", "icon": "shopping_cart" },
      { "id": "83bdf03d-6767-4d0c-ad1f-fc00ca0257c5", "name": "Khác", "icon": "category" }
    ]
  }
}
```

#### Kịch Bản B: Phân Loại Hàng Loạt Mặt Hàng (`POST /api/ai/classify/batch`)
*Áp dụng cho: Chức năng Receipt OCR bóc tách nhiều món con trong 1 hóa đơn.*

```json
{
  "success": true,
  "data": [
    {
      "item_id": "item_1",
      "text": "Bột giặt Robot 800g",
      "category_id": "61cbe81b-4545-4b8a-8b9d-da88a88035a3",
      "category_name": "Gia dụng",
      "category_icon": "home",
      "classify": "Chi",
      "confidence": 0.95,
      "tier_used": "tier1_keyword"
    },
    {
      "item_id": "item_2",
      "text": "KTYT FAMAPRO UV",
      "category_id": "72ace92c-5656-4c9b-9c0e-eb99b99146b4",
      "category_name": "Y tế & Sức khỏe",
      "category_icon": "medical_services",
      "classify": "Chi",
      "confidence": 0.92,
      "tier_used": "tier1_keyword"
    },
    {
      "item_id": "item_3",
      "text": "Loạt đồ chơi bong bóng 5 0",
      "category_id": "83bdf03d-6767-4d0c-ad1f-fc00ca0257c5",
      "category_name": "Giải trí",
      "category_icon": "sports_esports",
      "classify": "Chi",
      "confidence": 0.88,
      "tier_used": "tier2_nlp"
    }
  ]
}
```

---

## 7. KIẾN TRÚC MÔ HÌNH PHÂN LOẠI 3 TẦNG (3-TIER HYBRID ARCHITECTURE)

Để đạt được sự cân bằng hoàn hảo giữa **Tốc độ (< 50ms)**, **Chi phí tính toán tối thiểu** và **Độ chính xác cao (> 95%)**, hệ thống triển khai kiến trúc 3 tầng:

```
                      【DỮ LIỆU ĐẦU VÀO】
                    (Tên món / Note / Merchant)
                                │
                                ▼
         ┌─────────────────────────────────────────────┐
         │  TẦNG 1: KEYWORD & RULE-BASED MATCHER       │
         │  • Tra cứu từ khóa trong Category.Keyword   │
         │  • Tốc độ: 0 - 5ms | Độ tin cậy: 100%       │
         │  • Chạy được cả trên SQLite (Offline)       │
         └──────────────────────┬──────────────────────┘
                                │ (Nếu không khớp từ khóa)
                                ▼
         ┌─────────────────────────────────────────────┐
         │  TẦNG 2: MÔ HÌNH NHẸ (NLP / PhoBERT / TF-IDF)│
         │  • Huấn luyện trên tập dữ liệu tiếng Việt   │
         │  • Tốc độ: 15 - 30ms | Nhận diện ngữ cảnh   │
         │  • Chạy trên Backend Server                 │
         └──────────────────────┬──────────────────────┘
                                │ (Nếu Confidence < Ngưỡng 0.6)
                                ▼
         ┌─────────────────────────────────────────────┐
         │  TẦNG 3: LLM / FEW-SHOT REASONING (Gemini)  │
         │  • Phân tích ngữ cảnh phức tạp / mơ hồ      │
         │  • Tốc độ: 200 - 500ms                      │
         │  • Trả về Danh mục + Độ tự tin (Confidence) │
         └─────────────────────────────────────────────┘
```

---

## 8. ĐỐI SOÁT ONLINE VS OFFLINE PARITY

| Tiêu Chí So Sánh | Phân Loại Khi Có Mạng (Online) | Phân Loại Khi Mất Mạng (Offline) |
|---|---|---|
| **Nơi Thực Thi** | Backend Server (Module AI). | Client-app (Flutter Mobile Engine). |
| **Công Nghệ Sử Dụng** | Đầy đủ 3 Tầng: Keyword Matcher + NLP Model + LLM Few-Shot Reasoning. | Tầng 1: Offline Keyword Matcher tra cứu bộ từ khóa trên SQLite + Fuzzy Text Matching. |
| **Thời Gian Xử Lý** | 30ms - 200ms. | < 5ms (tức thì, không tốn tài nguyên mạng). |
| **Nguồn Dữ Liệu Đối Soát** | Toàn bộ danh mục & từ khóa trong PostgreSQL Supabase. | Toàn bộ danh mục & từ khóa trong SQLite cục bộ. |
| **Độ Phủ & Khả Năng Xử Lý** | Hiểu được từ lóng, tên viết tắt lạ, ngữ cảnh phức tạp, mã giao dịch khó. | Phân loại chuẩn xác 100% các từ khóa đã có trong SQLite; với từ mới sẽ đưa vào gợi ý "Khác / Chưa phân loại". |
| **Khả Năng Tự Học** | Cập nhật ngay lập tức vào database trung tâm. | Cập nhật vào SQLite cục bộ và đồng bộ lên Backend khi có mạng. |

---

## 9. CHỈ SỐ TIN CẬY & NGƯỠNG TỰ TIN (CONFIDENCE THRESHOLDS)

Mỗi kết quả dự đoán trả về kèm chỉ số `confidence` ($0.0 \rightarrow 1.0$):

| Mức Độ Tin Cậy | Ngưỡng Confidence | Hành Vi Trên Giao Diện (UI/UX) |
|---|---|---|
| **Rất Tự Tin (High)** | $\text{Confidence} \ge 0.80$ | Tự động chọn sẵn danh mục này. Người dùng chỉ cần lướt qua và bấm Duyệt 1 chạm. |
| **Trung Bình (Medium)** | $0.50 \le \text{Confidence} < 0.80$ | Điền danh mục top 1, kèm theo **Top 3 gợi ý** để người dùng chạm đổi nhanh. |
| **Không Chắc Chắn (Low)** | $\text{Confidence} < 0.50$ | Gán `Idcategory = NULL` (hoặc danh mục *"Khác"*), hiển thị viền vàng để người dùng chọn. |

---

## 10. CƠ CHẾ TỰ HỌC & CÁ NHÂN HÓA (SELF-LEARNING FEEDBACK LOOP)

Mỗi người dùng có thói quen phân loại tài chính riêng:
* Khi người dùng thay đổi danh mục do AI gợi ý (ví dụ: đổi từ *Ăn uống* sang *Tiếp khách*):
  1. Client gửi sự kiện phản hồi lên `POST /api/ai/classify/feedback`.
  2. Backend tự động trích xuất từ khóa của giao dịch đó và nối thêm vào trường `Category.Keyword` (phân cách bởi dấu `;`).
  3. Ở các lần giao dịch tiếp theo có chứa từ khóa này, **Tầng 1 (Keyword Matcher)** sẽ khớp ngay lập tức với độ chính xác 100% theo đúng thói quen của người dùng!

---

## 11. KỸ THUẬT XÂY DỰNG MODULE BACKEND (`src/Backend/modules/ai/features/classify/`)

```
src/Backend/modules/ai/features/classify/
├── classify.service.js       # Điều phối phân loại 3 tầng (Keyword -> Model -> LLM)
├── classify.controller.js    # Tiếp nhận request phân loại single/batch/feedback
├── classify.routes.js        # Định tuyến API (/single, /batch, /feedback)
└── pipeline/
    ├── keyword.matcher.js    # Thuật toán so khớp từ khóa (Tier 1)
    ├── nlp.matcher.js        # Thuật toán NLP / TF-IDF Similarity (Tier 2)
    └── llm.classifier.js     # Bộ phân loại Few-shot LLM Gemini Flash (Tier 3)
```

---

## 12. ĐẶC TẢ API ENDPOINTS

### 12.1. Phân Loại Giao Dịch Đơn Lẻ (`POST /api/ai/classify/single`)
* **Headers:** `Authorization: Bearer <token>`, `Content-Type: application/json`
* **Request Body:**
  ```json
  {
    "text": "Bột giặt Robot 800g",
    "amount": 19000
  }
  ```
* **Response Success (HTTP 200):**
  ```json
  {
    "success": true,
    "data": {
      "category_id": "61cbe81b-4545-4b8a-8b9d-da88a88035a3",
      "category_name": "Gia dụng",
      "category_icon": "home",
      "classify": "Chi",
      "confidence": 0.95,
      "tier_used": "tier1_keyword",
      "suggested_categories": [
        { "id": "61cbe81b-4545-4b8a-8b9d-da88a88035a3", "name": "Gia dụng", "icon": "home" },
        { "id": "92fba12a-5656-4c9b-9c0e-eb99b99146b4", "name": "Mua sắm", "icon": "shopping_cart" }
      ]
    }
  }
  ```

---

### 12.2. Phân Loại Hàng Loạt Mặt Hàng (`POST /api/ai/classify/batch`)
* **Mô tả:** Phục vụ cho OCR bóc tách nhiều món trong cùng 1 hóa đơn.
* **Request Body:**
  ```json
  {
    "items": [
      { "item_id": "item_1", "text": "Bột giặt Robot 800g", "amount": 19000 },
      { "item_id": "item_2", "text": "KTYT FAMAPRO UV", "amount": 19000 },
      { "item_id": "item_3", "text": "Loạt đồ chơi bong bóng 5 0", "amount": 19000 }
    ]
  }
  ```
* **Response Success (HTTP 200):**
  ```json
  {
    "success": true,
    "data": [
      {
        "item_id": "item_1",
        "category_id": "61cbe81b-4545-4b8a-8b9d-da88a88035a3",
        "category_name": "Gia dụng",
        "category_icon": "home",
        "classify": "Chi",
        "confidence": 0.95,
        "tier_used": "tier1_keyword"
      },
      {
        "item_id": "item_2",
        "category_id": "72ace92c-5656-4c9b-9c0e-eb99b99146b4",
        "category_name": "Y tế & Sức khỏe",
        "category_icon": "medical_services",
        "classify": "Chi",
        "confidence": 0.92,
        "tier_used": "tier1_keyword"
      },
      {
        "item_id": "item_3",
        "category_id": "83bdf03d-6767-4d0c-ad1f-fc00ca0257c5",
        "category_name": "Giải trí",
        "category_icon": "sports_esports",
        "classify": "Chi",
        "confidence": 0.88,
        "tier_used": "tier2_nlp"
      }
    ]
  }
  ```

---

### 12.3. Ghi Nhận Phản Hồi Tự Học (`POST /api/ai/classify/feedback`)
* **Request Body:**
  ```json
  {
    "keyword": "Bột giặt Robot",
    "selected_category_id": "61cbe81b-4545-4b8a-8b9d-da88a88035a3"
  }
  ```
* **Response Success (HTTP 200):**
  ```json
  {
    "success": true,
    "message": "Đã cập nhật thói quen phân loại cho danh mục"
  }
  ```
## 13. Phương Án Tối Ưu Sau Xây Dựng (Đề Xuất Hành Động Cho PO)

Dựa trên khảo sát thực tế về dữ liệu đầu vào và kiến trúc đã xây dựng, sau đây là 2 phương án tối ưu hóa mô hình phân loại giao dịch để PO và đội ngũ phát triển lựa chọn theo từng giai đoạn:

---

### 🌟 Phương Án 1: Tối Ưu Hóa Bộ Từ Khóa Hạt Giống & Vòng Lặp Tự Học (Khuyến Nghị Ưu Tiên Giai Đoạn Hiện Tại)

> **Mục tiêu:** Đưa hệ thống vào vận hành ngay lập tức với chi phí $0$đ, tốc độ $< 15ms$, độ chính xác cao và không phụ thuộc vào hạ tầng huấn luyện Machine Learning phức tạp.

* **Cơ chế triển khai:**
  1. **Nạp Từ Khóa Hạt Giống (Seed Keywords):** Mở rộng danh mục từ khóa phổ biến trong file Seed CSDL (`prisma/seed.js`) hoặc bảng `Category` cho các danh mục mặc định (`is_default = true`).
     * *Ví dụ:*
       * **Ăn uống:** `highlands; starbucks; phuc long; kfc; lotteria; bun bo; pho; com tam; tra sua; gong cha; koi the; winmart food; baemin; shopeefood; grabfood`
       * **Di chuyển:** `grab; be; gojek; xanh sm; mai linh; vinasun; do xang; petrolimex; pv oil; ve xe; ve tau; ve may bay; vietjet; vietnam airlines`
       * **Hóa đơn & Tiện ích:** `evn; tien dien; nuoc sach; cap nuoc; viettel; vinaphone; mobifone; fpt telecom; vnpt; truyen hinh`
       * **Mua sắm & Gia dụng:** `shopee; lazada; tiki; tiktok shop; bách hóa xanh; winmart; coopmart; lotte mart; emart; uniqlo; zara`
  2. **Kích hoạt Vòng lặp Tự học (Feedback Loop):** Khi người dùng duyệt giao dịch ngân hàng hoặc sửa danh mục trên app, gọi `POST /api/ai/classify/feedback` để hệ thống tự động nối từ khóa vào `Category.Keyword`. Các lần giao dịch sau sẽ khớp ngay ở **Tầng 1 (Keyword Matcher)** với độ tin cậy $100\%$.
* **Ưu điểm:**
  * Khởi chạy ngay, không cần thời gian thu thập hàng nghìn mẫu sao kê nhạy cảm.
  * Tốc độ cực nhanh ($0 - 5ms$ Tầng 1, $5 - 15ms$ Tầng 2), không tốn RAM server cho Python runtime.
  * Hoạt động đồng bộ cả Online (Backend) và Offline (SQLite trên điện thoại).

---

### 🚀 Phương Án 2: Xây Dựng Dataset Lớn & Huấn Luyện Mô Hình Máy Học Riêng (Mở Rộng Trong Tương Lai)

> **Mục tiêu:** Tự động hóa phân loại hoàn toàn bằng mô hình Machine Learning Supervised độc lập (`fastText` / `Naive Bayes`) khi hệ thống đã tích lũy đủ dữ liệu người dùng thực tế.

* **Cơ chế triển khai:**
  1. **Thu thập & Chuẩn hóa Dataset:** Tích lũy tập dữ liệu `training-data.csv` tối thiểu **1.500 – 3.000 dòng** giao dịch thực tế từ SMS Banking, Casso Webhook và Hóa đơn OCR (đảm bảo mỗi nhãn danh mục có tối thiểu $50 - 100$ mẫu đa dạng).
  2. **Đồng bộ Nhãn Danh mục:** Chuẩn hóa cột `category` trong CSV khớp chính xác với `idcategory` / `name_category` của CSDL hệ thống.
  3. **Huấn luyện Mô hình:** Chạy script huấn luyện `python train.py data.csv ./pipeline` để trích xuất file nhị phân `model.v1.bin`, `labels.json` và `metrics.json` (đạt F1-score $\ge 0.85$).
  4. **Tích hợp Model Bin:** Nạp file `model.v1.bin` vào Node.js Backend thông qua native binding hoặc microservice Python nhỏ để phục vụ dự đoán.
* **Ưu điểm:**
  * Có khả năng khái quát hóa (generalization) tốt hơn đối với các câu giao dịch dài, phức tạp mà không cần chứa chính xác từ khóa trong từ điển.
* **Hạn chế:**
  * Cần chi phí và thời gian gắn nhãn dữ liệu lớn ban đầu.
  * Cần bảo trì quy trình huấn luyện lại (re-training pipeline) định kỳ khi có danh mục mới.
