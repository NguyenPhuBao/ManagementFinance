# 🔄 HỢP ĐỒNG ĐỒNG BỘ DỮ LIỆU SQLITE (CLIENT-APP) ➔ POSTGRESQL (BACKEND)
### (Data Synchronization Contract & Specification: SQLite Drift ➔ PostgreSQL)

> **Dự án:** ManagementFinance  
> **Kiến trúc:** Offline-First (CSDL SQLite local Drift trên Client-app + PostgreSQL Supabase Backend REST API)  
> **Cơ chế:** Full 2-Way Sync (Push & Pull với giải quyết xung đột Last-Write-Wins LWW và Delta Pull theo `Server_update_at`)  
> **Phiên bản tài liệu:** `v3.0` (Cập nhật ngày 23/10/2026)  
> **Tệp kiểm thử hợp đồng chuẩn:** `src/Client-app/test/core/sync/sync_payload_contract_test.dart`  
> **Module Backend phụ trách:** `src/Backend/modules/sync/` (`sync.repository.js`, `sync.service.js`, `sync.controller.js`)  

---

## 📌 MỤC LỤC
1. [Nguyên Tắc Cốt Lõi Của Sync Engine](#1-nguyên-tắc-cốt-lõi-của-sync-engine)
2. [Thứ Tự Đẩy Dữ Liệu Bắt Buộc (Push Dependency Order)](#2-thứ-tự-đẩy-dữ-liệu-bắt-buộc-push-dependency-order)
3. [Chi Tiết Hợp Đồng 6 Mô-Đun Dữ Liệu Đồng Bộ](#3-chi-tiết-hợp-đồng-6-mô-đun-dữ-liệu-đồng-bộ)
   - [3.1. Ví tài chính (Wallets - 13 trường)](#31-ví-tài-chính-wallets---13-trường)
   - [3.2. Danh mục chi tiêu (Categories - 12 trường + NLP keyword)](#32-danh-mục-chi-tiêu-categories---12-trường--nlp-keyword)
   - [3.3. Mục tiêu tiết kiệm (Goals - 22 trường)](#33-mục-tiêu-tiết-kiệm-goals---22-trường)
   - [3.4. Hóa đơn định kỳ (Bills - 21 trường)](#34-hóa-đơn-định-kỳ-bills---21-trường)
   - [3.5. Ngân sách chi tiêu (Budgets - 17 trường)](#35-ngân-sách-chi-tiêu-budgets---17-trường)
   - [3.6. Giao dịch thu/chi (Transactions - 13 trường)](#36-giao-dịch-thuchi-transactions---13-trường)
4. [Cơ Chế Kéo Delta Pull Theo Giờ Server (Server_update_at UTC)](#4-cơ-chế-kéo-delta-pull-theo-giờ-server-server_update_at-utc)
5. [Checklist Sửa Đổi Bổ Sung Dành Cho Dev Client-App](#5-checklist-sửa-đổi-bổ-sung-dành-cho-dev-client-app)

---

## 1. NGUYÊN TẮC CỐT LÕI CỦA SYNC ENGINE

1. **Contract-First & Zero-Guesswork:**  
   Payload đẩy lên (`/api/sync/push`) và kéo về (`/api/sync/pull`) được ánh xạ chặt chẽ giữa tên trường `camelCase` phía Dart và `snake_case` phía Backend PostgreSQL. Mọi tên trường sai lệch sẽ làm payload bị bỏ qua trong im lặng.
2. **Offline-First & Local Identity (UUID v4):**  
   Mọi bản ghi (`idwallet`, `idtran`, `idcategory`, `idbudget`, `idbill`, `idgoal`) đều dùng chuỗi UUID 36 ký tự chuẩn `uuid.v4()`, khởi tạo trực tiếp trên thiết bị di động lúc offline và bảo toàn vĩnh viễn trên máy chủ.
3. **Phân Định Trạng Thái Bản Ghi (Sync Status):**  
   - Thêm mới/sửa cục bộ trên máy: `syncStatus = 'pending'`.
   - Đã đồng bộ thành công với Backend: `syncStatus = 'synced'`.
4. **Bảo Vệ Xóa Mềm (Soft-Delete Preservation):**  
   Khi người dùng xóa bản ghi trên thiết bị, tuyệt đối không chạy lệnh `DELETE` vật lý tại SQLite mà cập nhật `is_deleted = true` và `update_at = now()`. Khi đẩy lên server, Backend cập nhật `delete_at = now()` (hoặc `deleted_at = now()`).
5. **Cô Lập Người Dùng (Account Isolation):**  
   Mọi truy vấn và đồng bộ bắt buộc gắn liền với `idaccount` từ JWT token đã xác thực.

---

## 2. THỨ TỰ ĐẨY DỮ LIỆU BẮT BUỘC (PUSH DEPENDENCY ORDER)

Do CSDL PostgreSQL áp dụng các ràng buộc Khóa Ngoại (Foreign Keys) nghiêm ngặt, Client-app **BẮT BUỘC** phải sắp xếp mảng `operations` trong payload đẩy lên theo đúng thứ tự phụ thuộc sau:

$$\text{categories} \longrightarrow \text{wallets} \longrightarrow \text{goals} \longrightarrow \text{bills} \longrightarrow \text{budgets} \longrightarrow \text{transactions}$$

> ⚠️ **CẢNH BÁO SỐNG CÒN:**  
> - Bảng `transaction` mang khóa ngoại `idgoal` (trỏ tới `goal`) và `idbill` (trỏ tới `bill`).
> - Nếu người dùng tạo Mục tiêu hoặc Hóa đơn rồi nạp tiền / trả tiền ngay lúc Offline, cả hai bản ghi cùng nằm trong hàng đợi đẩy. **Nếu `transaction` được đẩy trước `goal` hoặc `bill`, server sẽ ném lỗi 400 Foreign Key Violation và giao dịch bị kẹt vĩnh viễn trên máy!** Do đó, `goals` và `bills` bắt buộc phải đứng trước `transactions`.

---

## 3. CHI TIẾT HỢP ĐỒNG 6 MÔ-ĐUN DỮ LIỆU ĐỒNG BỘ

### 3.1. Ví tài chính (`Wallets` — 13 trường)

| STT | Tên trường Dart (Client) | Tên cột PostgreSQL | Kiểu dữ liệu | Chiều đồng bộ | Ghi chú kỹ thuật & Ràng buộc |
|:---:|---|---|---|:---:|---|
| 1 | `id` | `Idwallet` | `VARCHAR(36)` | 2 chiều | UUID v4 khóa chính |
| 2 | `idaccount` | `Idaccount` | `INT` | 2 chiều | Khóa ngoại tài khoản sở hữu |
| 3 | `name` | `NameWallet` | `VARCHAR(100)` | 2 chiều | Tên ví hiển thị |
| 4 | `type` | `Type` | `VARCHAR(20)` | 2 chiều | Loại ví: `cash`, `bank`, `e-wallet`, `other` |
| 5 | `balance` | `Balance` | `DECIMAL(15,2)` | **1 chiều (Push)** | ⚠️ **HỢP ĐỒNG 1 CHIỀU:** Client đẩy lên để server thống kê, nhưng **nhánh kéo về (Pull) BỎ QUA (`Value.absent()`)**. Số dư ví là cache của tổng sổ giao dịch; kéo về sẽ ghi đè tính toán cục bộ chưa kịp đẩy. |
| 6 | `currency` | `Currency` | `VARCHAR(3)` | 2 chiều | Mặc định `VND` |
| 7 | `icon` | `Icon` | `VARCHAR(20)` | 2 chiều | Tên icon nhận diện |
| 8 | `color` | `Color` | `VARCHAR(9)` | 2 chiều | Mã màu Hex `#RRGGBB` (chuẩn hóa `color`, không dùng `colour`) |
| 9 | `is_default` | `Is_default` | `BOOLEAN` | 2 chiều | Đánh dấu ví mặc định |
| 10 | `is_deleted` | `Delete_at` | `BOOLEAN` / `TIMESTAMP` | 2 chiều | Push: `is_deleted = true` $\to$ Server: `Delete_at = NOW()` |
| 11 | `include_in_total` | `Include_in_total` | `BOOLEAN` | 2 chiều | Cờ tính vào tổng tài sản |
| 12 | `status` | `Status` | `VARCHAR(20)` | 2 chiều | Trạng thái lưu trữ ví: **Bắt buộc chữ hoa đầu: `'Active'` hoặc `'Inactive'`** (CHECK `chk_wallet_status`). Gửi chữ thường `'inactive'` sẽ bị CSDL từ chối! |
| 13 | `update_at` | `Update_at` | `TIMESTAMP(6)` | 2 chiều | Mốc thời gian LWW UTC ISO 8601 |

---

### 3.2. Danh mục chi tiêu (`Categories` — 12 trường + NLP Keyword)

| STT | Tên trường Dart (Client) | Tên cột PostgreSQL | Kiểu dữ liệu | Chiều đồng bộ | Ghi chú kỹ thuật & Ràng buộc |
|:---:|---|---|---|:---:|---|
| 1 | `id` | `Idcategory` | `VARCHAR(36)` | 2 chiều | UUID v4 khóa chính |
| 2 | `idaccount` | `Create_by` | `INT` | 2 chiều | ID tài khoản tạo danh mục cá nhân (hoặc `1` nếu hệ thống) |
| 3 | `name` / `namecategory` | `NameCategory` | `VARCHAR(200)` | 2 chiều | Tên danh mục |
| 4 | `classify` | `Classify` | `VARCHAR(7)` | 2 chiều | Chuẩn hóa 3 nhóm: `'Thu'`, `'Chi'`, `'Vay/no'` (hoặc `'income'`, `'expense'`, `'debt'`) |
| 5 | `is_default` | `Is_default` | `BOOLEAN` | 2 chiều | `true`: Danh mục hệ thống; `false`: Danh mục riêng tư người dùng |
| 6 | `isGroup` | `Is_group` | `BOOLEAN` | 2 chiều | `true` nếu là danh mục cha chứa các danh mục con |
| 7 | `parentId` | `Idgroup` | `VARCHAR(36)` | 2 chiều | UUID trỏ tới danh mục cha (bảo toàn cấu trúc cây nhóm) |
| 8 | `icon` | `Icon` | `VARCHAR(20)` | 2 chiều | Tên icon |
| 9 | `color` | `Color` | `VARCHAR(9)` | 2 chiều | Mã màu Hex |
| 10 | `keyword` | `Keyword` | `TEXT` | 2 chiều | **Từ khóa AI NLP học máy** phân cách dấu phẩy, dùng cho On-Device Edge AI phân loại giao dịch tự động. |
| 11 | `is_deleted` | `Delete_at` | `BOOLEAN` / `TIMESTAMP` | 2 chiều | Trạng thái xóa mềm |
| 12 | `update_at` | `Update_at` | `TIMESTAMP(6)` | 2 chiều | Mốc thời gian cập nhật LWW |

---

### 3.3. Mục tiêu tiết kiệm (`Goals` — 22 trường)

| STT | Tên trường Dart (Client) | Tên cột PostgreSQL | Kiểu dữ liệu | Chiều đồng bộ | Ghi chú kỹ thuật & Ràng buộc |
|:---:|---|---|---|:---:|---|
| 1 | `id` | `Idgoal` | `VARCHAR(36)` | 2 chiều | UUID v4 khóa chính |
| 2 | `idaccount` | `Idaccount` | `INT` | 2 chiều | Tài khoản sở hữu |
| 3 | `idwallet` | `Idwallet` | `VARCHAR(36)` | 2 chiều | Ví liên kết (tùy chọn) |
| 4 | `name` | `Name` | `VARCHAR(100)` | 2 chiều | Tên mục tiêu |
| 5 | `target_amount` | `Target_amount` | `DECIMAL(15,2)` | 2 chiều | Số tiền mục tiêu cần tích lũy |
| 6 | `current_amount` | `Current_amount` | `DECIMAL(15,2)` | 2 chiều | Số tiền hiện tích lũy được |
| 7 | `start_date` | `Start_date` | `TIMESTAMP(6)` | 2 chiều | Ngày bắt đầu |
| 8 | `target_date` | `Target_date` | `TIMESTAMP(6)` | 2 chiều | Ngày dự kiến hoàn thành |
| 9 | `cycle_take_money` | `Cycle_take_money` | `VARCHAR(7)` | 2 chiều | Chu kỳ gom tiền (`Day`, `Week`, `Month`, `Year`) |
| 10 | `time_cycle_take_money` | `Time_cycle_take_money` | `TIMESTAMP(6)` | 2 chiều | Thời điểm tiếp theo trong chu kỳ gom |
| 11 | `status_complete` | `Status_complete` | `VARCHAR(20)` | 2 chiều | `'True'` (đã đạt mục tiêu) hoặc `'False'` |
| 12 | `recurrence` | `Recurrence` | `BOOLEAN` | 2 chiều | Cờ lặp lại mục tiêu |
| 13 | `time_recurrence` | `Time_recurrence` | `VARCHAR(7)` | 2 chiều | Chu kỳ lặp lại |
| 14 | `icon` | `Icon` | `VARCHAR(20)` | 2 chiều | Icon đại diện |
| 15 | `color` | `Color` | `VARCHAR(20)` | 2 chiều | Màu sắc Hex |
| 16 | `note` | `Note` | `TEXT` | 2 chiều | Ghi chú mục tiêu (mã hóa an toàn) |
| 17 | `auto_deposit_amount` | `auto_deposit_amount` | `DECIMAL(18,2)` | 2 chiều | Số tiền trích tự động mỗi kỳ |
| 18 | `auto_deposit_wallet_id` | `auto_deposit_wallet_id` | `VARCHAR(36)` | 2 chiều | Ví nguồn dùng để tự động trích tiền |
| 19 | `auto_deposit_last_run` | `auto_deposit_last_run` | `TIMESTAMP(6)` | 2 chiều | Thời điểm trích tự động gần nhất (tránh trích 2 lần) |
| 20 | `priority` | `Priority` | `INT` | 2 chiều | Thứ tự ưu tiên người dùng sắp xếp kéo thả (số nhỏ đứng trước, cách nhau 100, `null` nếu chưa sắp) |
| 21 | `is_deleted` | `Delete_at` | `BOOLEAN` / `TIMESTAMP` | 2 chiều | Trạng thái xóa mềm |
| 22 | `update_at` | `Update_at` | `TIMESTAMP(6)` | 2 chiều | Mốc cập nhật LWW |

---

### 3.4. Hóa đơn định kỳ (`Bills` — 21 trường)

| STT | Tên trường Dart (Client) | Tên cột PostgreSQL | Kiểu dữ liệu | Chiều đồng bộ | Ghi chú kỹ thuật & Ràng buộc |
|:---:|---|---|---|:---:|---|
| 1 | `id` | `Idbill` | `VARCHAR(36)` | 2 chiều | UUID v4 khóa chính |
| 2 | `idaccount` | `Idaccount` | `INT` | 2 chiều | Tài khoản sở hữu |
| 3 | `idwallet` | `Idwallet` | `VARCHAR(36)` | 2 chiều | Ví chi trả mặc định |
| 4 | `idcategory` | `Idcategory` | `VARCHAR(36)` | 2 chiều | Danh mục hóa đơn |
| 5 | `name` | `Name` | `VARCHAR(100)` | 2 chiều | Tên hóa đơn (Tiền điện, Nước, Internet...) |
| 6 | `amount` | `Amount` | `DECIMAL(15,2)` | 2 chiều | Số tiền hóa đơn |
| 7 | `start_date` | `Start_date` | `TIMESTAMP(6)` | 2 chiều | Ngày bắt đầu hiệu lực |
| 8 | `due_date` | `Due_date` | `TIMESTAMP(6)` | 2 chiều | Hạn chót thanh toán kỳ này |
| 9 | `pay_status` | `Pay_status` | `VARCHAR(7)` | 2 chiều | Nhận đúng 4 giá trị chuẩn (`chk_bill_pay_status`): `'Pending'`, `'Payed'`, `'Skipped'` (Bỏ qua kỳ), `'Overdue'` |
| 10 | `recurrence` | `Recurrence` | `BOOLEAN` | 2 chiều | Lặp lại định kỳ hay hóa đơn 1 lần |
| 11 | `time_recurrence` | `Time_recurrence` | `VARCHAR(7)` | 2 chiều | Chu kỳ lặp (`Day`, `Week`, `Month`, `Quarter`, `Year`) |
| 12 | `time_notification` | `Time_notification` | `VARCHAR(20)` | 2 chiều | Số ngày nhắc trước hạn thanh toán |
| 13 | `icon` | `Icon` | `VARCHAR(20)` | 2 chiều | Icon đại diện |
| 14 | `color` | `Color` | `VARCHAR(20)` | 2 chiều | Màu sắc Hex |
| 15 | `note` | `Note` | `TEXT` | 2 chiều | Ghi chú (mã hóa an toàn) |
| 16 | `previous_bill_id` | `Previous_bill_id` | `VARCHAR(36)` | 2 chiều | UUID kỳ trước của chuỗi hóa đơn lặp (giữ liền mạch chuỗi kỳ) |
| 17 | `period_end` | `Period_end` | `DATE` | 2 chiều | **Ân hạn hóa đơn:** Ngày kết thúc kỳ thực tế tách biệt hạn trả. Gửi lúc 00:00 UTC của ngày cục bộ. |
| 18 | `auto_pay` | `Auto_pay` | `BOOLEAN` | 2 chiều | **Công tắc tự động thanh toán hóa đơn:** `true`/`false` kiểu boolean thật. |
| 19 | `anchor_day` | `Anchor_day` | `SMALLINT` | 2 chiều | Ngày gốc trong tháng (vd: 28, 30, 31) để chống trôi ngày đến hạn khi rơi vào tháng 2 |
| 20 | `is_deleted` | `Delete_at` | `BOOLEAN` / `TIMESTAMP` | 2 chiều | Trạng thái xóa mềm |
| 21 | `update_at` | `Update_at` | `TIMESTAMP(6)` | 2 chiều | Mốc cập nhật LWW |

---

### 3.5. Ngân sách chi tiêu (`Budgets` — 17 trường)

| STT | Tên trường Dart (Client) | Tên cột PostgreSQL | Kiểu dữ liệu | Chiều đồng bộ | Ghi chú kỹ thuật & Ràng buộc |
|:---:|---|---|---|:---:|---|
| 1 | `id` | `Idbudget` | `VARCHAR(36)` | 2 chiều | UUID v4 khóa chính |
| 2 | `idaccount` | `Idaccount` | `INT` | 2 chiều | Tài khoản sở hữu |
| 3 | `idcategory` | `Idcategory` | `VARCHAR(36)` | 2 chiều | Danh mục áp dụng (null nếu áp dụng cho toàn bộ chi tiêu) |
| 4 | `total_amount` | `Total_amount` | `DECIMAL(15,2)` | 2 chiều | Hạn mức ngân sách tối đa |
| 5 | `spent` | `Spent` | `DECIMAL(15,2)` | 2 chiều | Số tiền đã chi tiêu trong kỳ ngân sách |
| 6 | `threshold_warning_amount` | `Threshold_warning_amount` | `DECIMAL(15,2)` | 2 chiều | Số tiền chạm ngưỡng sẽ cảnh báo (tùy chọn) |
| 7 | `threshold_warning_percent` | `Threshold_warning_percent` | `INT` | 2 chiều | **Tỷ lệ phần trăm cảnh báo (vd: 80%):** Lưu kiểu số nguyên (0-100) |
| 8 | `over_spending` | `Over_spending` | `VARCHAR(7)` | 2 chiều | Trạng thái vượt hạn mức: `'Over'` hoặc `'Normal'` |
| 9 | `over_amount` | `Over_amount` | `DECIMAL(15,2)` | 2 chiều | Số tiền bội chi vượt hạn mức |
| 10 | `start` | `Start` | `TIMESTAMP(6)` | 2 chiều | Ngày bắt đầu kỳ ngân sách |
| 11 | `end` | `End` | `TIMESTAMP(6)` | 2 chiều | Ngày kết thúc kỳ ngân sách |
| 12 | `recurrence` | `Recurrence` | `BOOLEAN` | 2 chiều | Có tự động gia hạn sang kỳ kế tiếp không |
| 13 | `time_recurrence` | `Time_recurrence` | `VARCHAR(7)` | 2 chiều | Chu kỳ ngân sách (`Week`, `Month`, `Quarter`, `Year`) |
| 14 | `nexttime_recurrence` | `Nexttime_recurrence` | `TIMESTAMP(6)` | 2 chiều | Thời điểm chu kỳ kế tiếp bắt đầu |
| 15 | `note` | `Note` | `TEXT` | 2 chiều | Ghi chú ngân sách (mã hóa) |
| 16 | `is_deleted` | `Delete_at` | `BOOLEAN` / `TIMESTAMP` | 2 chiều | Trạng thái xóa mềm |
| 17 | `update_at` | `Update_at` | `TIMESTAMP(6)` | 2 chiều | Mốc cập nhật LWW |

---

### 3.6. Giao dịch thu/chi (`Transactions` — 13 trường)

| STT | Tên trường Dart (Client) | Tên cột PostgreSQL | Kiểu dữ liệu | Chiều đồng bộ | Ghi chú kỹ thuật & Ràng buộc |
|:---:|---|---|---|:---:|---|
| 1 | `id` | `Idtran` | `VARCHAR(36)` | 2 chiều | UUID v4 khóa chính |
| 2 | `idaccount` | `Idaccount` | `INT` | 2 chiều | Tài khoản sở hữu |
| 3 | `walletId` | `Idwallet` | `VARCHAR(36)` | 2 chiều | Ví phát sinh giao dịch |
| 4 | `categoryId` | `Idcategory` | `VARCHAR(36)` | 2 chiều | Danh mục giao dịch (null nếu là chuyển tiền ví) |
| 5 | `idwallet_transfer` | `Idwallet_transfer` | `VARCHAR(36)` | 2 chiều | Ví đích (khi chuyển khoản giữa 2 ví) |
| 6 | `idgoal` | `Idgoal` | `VARCHAR(36)` | 2 chiều | Khóa ngoại nối tới Mục tiêu tiết kiệm (khoản nạp mục tiêu) |
| 7 | `idbill` | `Idbill` | `VARCHAR(36)` | 2 chiều | Khóa ngoại nối tới Hóa đơn (khoản thanh toán hóa đơn) |
| 8 | `amount` | `Amount` | `DECIMAL(15,2)` | 2 chiều | **Dấu quy ước:** Dấu Âm (`< 0`) là Chi tiêu; Dấu Dương (`> 0`) là Thu nhập |
| 9 | `type` | `Type` | `VARCHAR(20)` | 2 chiều | **CHECK `chk_transaction_type`:** Chỉ nhận đúng 2 giá trị trên server: `'Transaction'` hoặc `'Transfer'`. Client đổi `chi`/`thu` thành `Transaction`! |
| 10 | `note` | `Note` | `TEXT` | 2 chiều | Nội dung ghi chú giao dịch (Backend tự mã hóa AES-256-GCM) |
| 11 | `dateTransaction` | `DateTransaction` | `TIMESTAMP(6)` | 2 chiều | Thời điểm giao dịch thực tế diễn ra |
| 12 | `is_deleted` | `Deleted_at` | `BOOLEAN` / `TIMESTAMP` | 2 chiều | Cột trong DB là `Deleted_at` (có chữ `d`) |
| 13 | `update_at` | `Update_at` | `TIMESTAMP(6)` | 2 chiều | Mốc thời gian LWW |

---

## 4. CƠ CHẾ KÉO DELTA PULL THEO GIỜ SERVER (`Server_update_at` UTC)

Nhằm giải quyết triệt để rủi ro lệch đồng hồ phần cứng giữa điện thoại và máy chủ (Clock Drift):
1. **Migration 20 + 21:** CSDL PostgreSQL đã bổ sung cột `Server_update_at TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC')` cho cả 6 bảng đồng bộ, đi kèm Trigger Function `set_server_update_at()` tự động cập nhật mỗi khi có thao tác INSERT hoặc UPDATE.
2. **Nguyên tắc Kéo Delta (`/api/sync/pull?since=...`):**
   - Phía Client-app lưu `lastPullTime` theo giá trị `pulledAt` do Backend trả về trong phản hồi kỳ trước.
   - Khi gọi pull, Backend lọc: `WHERE "Server_update_at" > :since`.
   - Client-app kẹp dải thời gian an toàn `maxSince = max(since, pulledAt - 2 phút)` để bù đắp các giao dịch đang nằm trong transaction chưa kịp commit, đảm bảo không bỏ sót bất kỳ dữ liệu nào.

---

## 5. CHECKLIST SỬA ĐỔI BỔ SUNG DÀNH CHO DEV CLIENT-APP

Để đạt mức tương thích 100% với hệ thống Backend và vượt qua bài test hợp đồng `sync_payload_contract_test.dart`:

- [ ] **1. Thứ tự mảng operations khi Push:** Bắt buộc sắp xếp: `categories` $\to$ `wallets` $\to$ `goals` $\to$ `bills` $\to$ `budgets` $\to$ `transactions`.
- [ ] **2. Khóa ngoại `idgoal` và `idbill` trong giao dịch:** Gửi đúng tên khóa `idgoal` (không gửi `goal_id`) và `idbill` (không gửi `bill_id`).
- [ ] **3. Giá trị `type` và dấu của `amount` trong giao dịch:**
  - Khoản Chi: `type = 'Transaction'`, `amount < 0`.
  - Khoản Thu: `type = 'Transaction'`, `amount > 0`.
  - Khoản Chuyển ví: `type = 'Transfer'`, giữ `idwallet_transfer`, gán `categoryId = null`.
- [ ] **4. Trạng thái ví (`status`):** Gửi nguyên văn `'Active'` hoặc `'Inactive'` (chữ hoa đầu) theo ràng buộc `chk_wallet_status`.
- [ ] **5. Nhánh Kéo Ví về (Pull):** Không đọc đè cột `balance` từ server (`Value.absent()`), để bảo toàn số dư tính toán cục bộ.
- [ ] **6. Hóa đơn `pay_status` và `auto_pay`:** Gửi đúng 4 chuỗi: `'Pending'`, `'Payed'`, `'Skipped'`, `'Overdue'`; `auto_pay` kiểu boolean thật.
- [ ] **7. Mục tiêu `priority`:** Gửi số nguyên dương (vd: 100, 200) hoặc `null` (nếu chưa xếp thứ tự); không gửi `0`.
- [ ] **8. Ngân sách `threshold_warning_percent`:** Gửi đúng kiểu số nguyên (0-100).
