# ĐẶC TẢ TEMPLATE DATA TỪ CASSO OPEN BANKING API (TemplateData.md)
> **Tài liệu nguồn sự thật về cấu trúc dữ liệu biến động số dư ngân hàng qua Casso API v2**  
> *Được PO phê duyệt ngày 2026-09-02.*

---

## 1. TỔNG QUAN VỀ DỮ LIỆU TỪ CASSO

Casso Open Banking là cổng trung gian kết nối và đồng bộ biến động số dư tự động từ các ngân hàng tại Việt Nam (MBBank, Vietcombank, Techcombank, ACB, BIDV, VPBank, TPBank...).

Khi có giao dịch phát sinh, Casso gửi dữ liệu về Backend qua Webhook HTTP POST (hoặc khi gọi API `GET /v2/transactions`) dưới dạng mảng các giao dịch có cấu trúc JSON.

---

## 2. BẢNG ĐẶC TẢ CHI TIẾT TỪNG TRƯỜNG DỮ LIỆU TỪ CASSO

| Tên Trường (Casso) | Kiểu Dữ Liệu | Ràng Buộc | Ý Nghĩa Kỹ Thuật | Ánh Xạ Vào CSDL & Module AI |
|---|---|---|---|---|
| **`id`** | `Integer` | **Bắt buộc** | Mã định danh bản ghi giao dịch phía hệ thống Casso. | Ghi log & tracking. |
| **`tid`** | `String` | **Bắt buộc** | Mã giao dịch phía ngân hàng (FT code / Mã tham chiếu). | Lưu vào `Transaction.Bank_tran_id` để **chống trùng lặp tuyệt đối**. |
| **`description`** | `String` | **Bắt buộc** | Chuỗi diễn giải / nội dung chuyển tiền từ sao kê ngân hàng. | **Đầu vào cốt lõi nhất cho bộ AI Classify** bóc tách từ khóa đối soát danh mục. |
| **`amount`** | `Number` | **Bắt buộc** | Số tiền giao dịch biến động ($>0$). | Gán vào `Transaction.Amount`. |
| **`cusum_balance`** | `Number` | *Nullable* | Số dư khả dụng tích lũy (Cumulative Balance) sau giao dịch. | Cập nhật số dư `Wallet.Balance` và `Bank_account.Balance`. |
| **`when`** | `Datetime` | **Bắt buộc** | Thời điểm giao dịch phát sinh (`YYYY-MM-DD HH:mm:ss`). | Gán vào `Transaction.DateTransaction`. |
| **`bank_sub_acc_id`** / **`subAccId`** | `String` | **Bắt buộc** | Số tài khoản ngân hàng của người dùng nhận biến động. | Map với `Bank_account.Account_number` để tìm đúng `Idaccount` & `Idwallet`. |
| **`bankName`** / **`bankAbbreviation`** | `String` | *Nullable* | Tên ngân hàng / Mã viết tắt (`MB`, `VCB`, `BIDV`, `TCB`...). | Nhận diện nguồn thẻ / ví. |
| **`corresponsiveName`** | `String` | *Nullable* | Tên tài khoản đối ứng (Người gửi / Người nhận). | Bổ trợ cho AI nhận diện giao dịch cá nhân hay tổ chức. |
| **`corresponsiveAccount`** | `String` | *Nullable* | Số tài khoản đối ứng. | Hỗ trợ phát hiện luồng chuyển tiền nội bộ cùng chủ tài khoản. |
| **`corresponsiveBankName`** | `String` | *Nullable* | Tên ngân hàng của tài khoản đối ứng. | Hỗ trợ phân loại chuyển khoản liên ngân hàng. |
| **`virtualAccount`** / **`virtualAccountName`** | `String` | *Nullable* | Thông tin tài khoản ảo (nếu có). | Nhận diện kênh thanh toán định danh. |

---

## 3. CẤU TRÚC JSON WEBHOOK PAYLOAD CHUẨN

```json
{
  "error": 0,
  "messages": "Success",
  "data": [
    {
      "id": 982341,
      "tid": "FT26245981273910",
      "description": "MBVCB.12938471.HIGHLANDS COFFEE.Thanh toan cafe",
      "amount": 65000,
      "cusum_balance": 5200000,
      "when": "2026-09-02 14:30:00",
      "bank_sub_acc_id": "5111012066",
      "subAccId": "5111012066",
      "bankName": "Ngân hàng TMCP Đầu tư và Phát triển Việt Nam",
      "bankAbbreviation": "BIDV",
      "virtualAccount": null,
      "virtualAccountName": null,
      "corresponsiveName": "CONG TY CP DICH VU CA PHE CAO NGUYEN",
      "corresponsiveAccount": "0123456789",
      "corresponsiveBankId": "970436",
      "corresponsiveBankName": "Vietcombank"
    }
  ]
}
```

---

## 4. CÁC MẪU DỮ LIỆU THỰC TẾ ĐIỂN HÌNH & ĐỐI SOÁT AI CLASSIFY

### Mẫu 1: Chi tiêu ăn uống / Cafe (`HIGHLANDS COFFEE`)
```json
{
  "id": 1001,
  "tid": "FT26245981273910",
  "description": "MBVCB.12938471.HIGHLANDS COFFEE.Thanh toan cafe",
  "amount": 65000,
  "cusum_balance": 5200000,
  "when": "2026-09-02 14:30:00",
  "subAccId": "5111012066",
  "bankAbbreviation": "BIDV",
  "corresponsiveName": "CONG TY CP DICH VU CA PHE CAO NGUYEN",
  "corresponsiveAccount": "0123456789"
}
```
* **AI Đối soát Từ Khóa:** Phát hiện `"HIGHLANDS COFFEE"` / `"CA PHE"` $\rightarrow$ Khớp `Category.Keyword: "highlands; cafe; ca phe; tra sua; an uong"` $\rightarrow$ Gợi ý danh mục: **`Ăn uống / Cafe`** (`Idcategory: 61cbe81b-...`).

---

### Mẫu 2: Thanh toán Hóa đơn Tiền Điện (`EVN`)
```json
{
  "id": 1002,
  "tid": "FT26245981273922",
  "description": "THANH TOAN TIEN DIEN EVN HANOI PE01000234918",
  "amount": 854000,
  "cusum_balance": 4346000,
  "when": "2026-09-02 09:15:00",
  "subAccId": "5111012066",
  "bankAbbreviation": "BIDV",
  "corresponsiveName": "TONG CONG TY DIEN LUC TP HA NOI",
  "corresponsiveAccount": "9876543210"
}
```
* **AI Đối soát Từ Khóa:** Phát hiện `"TIEN DIEN"` / `"EVN"` $\rightarrow$ Khớp `Category.Keyword: "tien dien; evn; dien luc; hoa don"` $\rightarrow$ Gợi ý danh mục: **`Hóa đơn & Tiện ích / Tiền điện`** (`Idcategory: 72ace92c-...`).

---

### Mẫu 3: Nhận tiền lương hàng tháng (`CONG TY TRA LUONG`)
```json
{
  "id": 1003,
  "tid": "FT26245981273935",
  "description": "CTY TNHH CONG NGHE ABC TRA LUONG THANG 08/2026 CHO NGUYEN PHU BAO",
  "amount": 25000000,
  "cusum_balance": 29346000,
  "when": "2026-09-02 16:45:00",
  "subAccId": "5111012066",
  "bankAbbreviation": "BIDV",
  "corresponsiveName": "CONG TY TNHH CONG NGHE ABC",
  "corresponsiveAccount": "1122334455"
}
```
* **AI Đối soát Từ Khóa:** Phát hiện `"TRA LUONG"` / `"LUONG THANG"` $\rightarrow$ Khớp `Category.Keyword: "luong; salary; tra luong; thu nhap"` $\rightarrow$ Gợi ý danh mục: **`Thu nhập / Lương`** (`Idcategory: 83bdf03d-...`).
