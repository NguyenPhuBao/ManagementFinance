# 🔄 HỢP ĐỒNG ĐỒNG BỘ DỮ LIỆU SQLITE (CLIENT-APP) ➔ POSTGRESQL (BACKEND)
### (Data Synchronization Contract & Specification: SQLite Drift ➔ PostgreSQL)

> **Dự án:** ManagementFinance  
> **Kiến trúc:** Offline-First (CSDL SQLite local Drift trên Client-app + PostgreSQL Supabase Backend REST API)  
> **Cơ chế:** Full 2-Way Sync (Push & Pull với giải quyết xung đột Last-Write-Wins LWW và Delta Pull theo `server_update_at` UTC)  
> **Phiên bản tài liệu:** `v4.0` (Cập nhật ngày 24/10/2026 sau đợt chuẩn hóa CSDL & DB Guard)  
> **Tệp kiểm thử hợp đồng chuẩn:** `src/Client-app/test/core/sync/sync_payload_contract_test.dart`  
> **Module Backend phụ trách:** `src/Backend/modules/sync/` (`sync.repository.js`, `sync.service.js`, `sync.controller.js`, `sync.validation.js`)  

---

## 📌 MỤC LỤC
1. [Nguyên Tắc Cốt Lõi Của Sync Engine](#1-nguyên-tắc-cốt-lõi-của-sync-engine)
2. [Thứ Tự Đẩy Dữ Liệu Bắt Buộc (Push Dependency Order)](#2-thứ-tự-đẩy-dữ-liệu-bắt-buộc-push-dependency-order)
3. [Chi Tiết Hợp Đồng 6 Mô-Đun Dữ Liệu Đồng Bộ](#3-chi-tiết-hợp-đồng-6-mô-đun-dữ-liệu-đồng-bộ)
   - [3.1. Ví tài chính (Wallets — 16 trường)](#31-ví-tài-chính-wallets--16-trường)
   - [3.2. Danh mục chi tiêu (Categories — 14 trường + NLP Keyword)](#32-danh-mục-chi-tiêu-categories--14-trường--nlp-keyword)
   - [3.3. Mục tiêu tiết kiệm (Goals — 24 trường)](#33-mục-tiêu-tiết-kiệm-goals--24-trường)
   - [3.4. Hóa đơn định kỳ (Bills — 24 trường)](#34-hóa-đơn-định-kỳ-bills--24-trường)
   - [3.5. Ngân sách chi tiêu (Budgets — 19 trường)](#35-ngân-sách-chi-tiêu-budgets--19-trường)
   - [3.6. Giao dịch thu/chi (Transactions — 18 trường)](#36-giao-dịch-thuchi-transactions--18-trường)
4. [Cơ Chế Kéo Delta Pull Theo Giờ Server (server_update_at UTC)](#4-cơ-chế-kéo-delta-pull-theo-giờ-server-server_update_at-utc)
5. [Cơ Chế Giải Quyết Xung Đột & Phòng Chống Lỗi Kẹt Sync](#5-cơ-chế-giải-quyết-xung-đột--phòng-chống-lỗi-kẹt-sync)
6. [Checklist Sửa Đổi Bổ Sung Dành Cho Dev Client-App](#6-checklist-sửa-đổi-bổ-sung-dành-cho-dev-client-app)

---

## 1. NGUYÊN TẮC CỐT LÕI CỦA SYNC ENGINE

1. **Contract-First & Zero-Guesswork:**  
   Payload đẩy lên (`/api/sync/push`) và kéo về (`/api/sync/pull`) được ánh xạ chặt chẽ giữa tên trường `camelCase` phía Dart và `snake_case` phía Backend PostgreSQL. Mọi tên trường sai lệch sẽ làm payload bị bỏ qua hoặc bị lỗi xác thực.
2. **Offline-First & Local Identity (UUID v4):**  
   Mọi bản ghi (`idwallet`, `idtran`, `idcategory`, `idbudget`, `idbill`, `idgoal`) đều dùng chuỗi UUID 36 ký tự chuẩn `uuid.v4()`, khởi tạo trực tiếp trên thiết bị di động lúc offline và bảo toàn vĩnh viễn trên máy chủ.
3. **Phân Định Trạng Thái Bản Ghi (Sync Status):**  
   - Thêm mới/sửa cục bộ trên máy: `syncStatus = 'pending'`.
   - Đã đồng bộ thành công với Backend: `syncStatus = 'synced'`.
4. **Bảo Vệ Xóa Mềm (Soft-Delete Preservation):**  
   Khi người dùng xóa bản ghi trên thiết bị, tuyệt đối không chạy lệnh `DELETE` vật lý tại SQLite mà cập nhật `is_deleted = true` và `update_at = now()`. Khi đẩy lên server, Backend cập nhật `delete_at = now()` (riêng bảng transaction là `deleted_at = now()`).
5. **Cô Lập Người Dùng (Account Isolation):**  
   Mọi truy vấn và đồng bộ bắt buộc gắn liền với `idaccount` từ JWT token đã xác thực.

---

## 2. THỨ TỰ ĐẨY DỮ LIỆU BẮT BUỘC (PUSH DEPENDENCY ORDER)

Do CSDL PostgreSQL áp dụng các ràng buộc Khóa Ngoại (Foreign Keys) nghiêm ngặt, Client-app **BẮT BUỘC** phải sắp xếp mảng `operations` trong payload đẩy lên theo đúng thứ tự phụ thuộc sau:

$$\text{categories} \longrightarrow \text{wallets} \longrightarrow \text{goals} \longrightarrow \text{bills} \longrightarrow \text{budgets} \longrightarrow \text{transactions}$$

> ⚠️ **CẢNH BÁO SỐNG CÒN:**  
> - Bảng `transaction` mang khóa ngoại `idgoal` (trỏ tới `goal`) và `idbill` (trỏ tới `bill`).
> - Nếu người dùng tạo Mục tiêu hoặc Hóa đơn rồi nạp tiền / thanh toán ngay lúc Offline, cả hai bản ghi cùng nằm trong hàng đợi đẩy. **Nếu `transaction` được đẩy trước `goal` hoặc `bill`, server sẽ ném lỗi 400 Foreign Key Violation và giao dịch bị kẹt vĩnh viễn trên máy!** Do đó, `goals` và `bills` bắt buộc phải đứng trước `transactions`.
> - Khi xóa (delete operations), thứ tự đảo ngược: $\text{transactions} \longrightarrow \text{budgets} \longrightarrow \text{bills} \longrightarrow \text{goals} \longrightarrow \text{wallets} \longrightarrow \text{categories}$.

---

## 3. CHI TIẾT HỢP ĐỒNG 6 MÔ-ĐUN DỮ LIỆU ĐỒNG BỘ

### 3.1. Ví tài chính (`Wallets` — 16 trường)

| STT | Tên trường Dart (Client) | Tên cột PostgreSQL | Kiểu dữ liệu | Chiều đồng bộ | Ghi chú kỹ thuật & Ràng buộc |
|:---:|---|---|---|:---:|---|
| 1 | `id` / `idwallet` | `idwallet` | `VARCHAR(36)` | 2 chiều | UUID v4 khóa chính |
| 2 | `idaccount` | `idaccount` | `INT` | 2 chiều | Khóa ngoại tài khoản sở hữu (Server tự lấy từ JWT) |
| 3 | `name` | `name` | `VARCHAR(100)` | 2 chiều | Tên ví hiển thị (tối đa 100 ký tự) |
| 4 | `type` | `type` | `VARCHAR(20)` | 2 chiều | Loại ví: `Cash`, `Bank`, `EWallet`, `Credit`, `Savings`, `Other` |
| 5 | `balance` | `balance` | `DECIMAL(15,2)` | **1 chiều (Push)** | ⚠️ **HỢP ĐỒNG 1 CHIỀU:** Client đẩy lên để server thống kê, nhưng **nhánh kéo về (Pull) BỎ QUA (`Value.absent()`)**. Số dư ví là cache của tổng sổ giao dịch; kéo về sẽ ghi đè tính toán cục bộ chưa kịp đẩy. |
| 6 | `currency` | `currency` | `VARCHAR(3)` | 2 chiều | Đơn vị tiền tệ, mặc định `VND` |
| 7 | `status` | `status` | `VARCHAR(20)` | 2 chiều | Trạng thái lưu trữ ví: **Bắt buộc chữ hoa đầu: `'Active'` hoặc `'Inactive'`** (CHECK `chk_wallet_status`). Gửi chữ thường `'inactive'` sẽ bị CSDL từ chối! |
| 8 | `include_in_total` | `include_in_total` | `BOOLEAN` | 2 chiều | Cờ tính vào tổng tài sản ròng |
| 9 | `is_default` | `is_default` | `BOOLEAN` | 2 chiều | Đánh dấu ví mặc định |
| 10 | `id_bank_casso` | `id_bank_casso` | `INT` | 2 chiều | ID tài khoản ngân hàng liên kết đối soát Casso (`null` nếu ví thủ công) |
| 11 | `icon` | `icon` | `VARCHAR(255)` | 2 chiều | Tên icon nhận diện (hoặc icon asset) |
| 12 | `color` | `color` | `VARCHAR(50)` | 2 chiều | Mã màu Hex `#RRGGBB` (chuẩn hóa `color`, không dùng `colour`) |
| 13 | `create_at` | `create_at` | `TIMESTAMP(6)` | Kéo về (Pull) | Thời điểm tạo ví tại hệ thống |
| 14 | `update_at` | `update_at` | `TIMESTAMP(6)` | 2 chiều | Mốc thời gian LWW UTC ISO 8601 |
| 15 | `is_deleted` | `delete_at` | `BOOLEAN` / `TIMESTAMP` | 2 chiều | Push: `is_deleted = true` $\to$ Server: `delete_at = NOW()` |
| 16 | `server_update_at` | `server_update_at` | `TIMESTAMP(6)` | Kéo về (Pull) | Giờ server cập nhật bản ghi UTC, dùng làm mốc Delta Pull |

---

### 3.2. Danh mục chi tiêu (`Categories` — 14 trường + NLP Keyword)

| STT | Tên trường Dart (Client) | Tên cột PostgreSQL | Kiểu dữ liệu | Chiều đồng bộ | Ghi chú kỹ thuật & Ràng buộc |
|:---:|---|---|---|:---:|---|
| 1 | `id` / `idcategory` | `idcategory` | `VARCHAR(36)` / `INT` | 2 chiều | ID khóa chính danh mục |
| 2 | `idaccount` | `create_by` | `INT` | 2 chiều | ID tài khoản tạo danh mục cá nhân (hoặc `1` nếu danh mục hệ thống) |
| 3 | `name` / `name_category` | `name_category` | `VARCHAR(100)` | 2 chiều | Tên danh mục (ví dụ: Ăn uống, Tiền lương, Di chuyển) |
| 4 | `classify` | `classify` | `VARCHAR(7)` | 2 chiều | Chuẩn hóa 3 nhóm: `'Thu'`, `'Chi'`, `'Vay/no'` (Lưu ý: dấu gạch chéo không dấu `'Vay/no'`) |
| 5 | `is_default` | `is_default` | `BOOLEAN` | 2 chiều | `true`: Danh mục mặc định hệ thống (Client không được sửa/xóa); `false`: Cá nhân |
| 6 | `is_group` / `isGroup` | `is_group` | `BOOLEAN` | 2 chiều | `true` nếu là danh mục cha chứa các danh mục con |
| 7 | `idgroup` / `parentId` | `idgroup` | `VARCHAR(36)` / `INT` | 2 chiều | ID trỏ tới danh mục cha (bảo toàn cấu trúc cây nhóm) |
| 8 | `keyword` | `keyword` | `VARCHAR(50)` | 2 chiều | **Từ khóa AI NLP học máy** phân cách dấu phẩy, dùng cho On-Device Edge AI phân loại giao dịch tự động. |
| 9 | `icon` | `icon` | `VARCHAR(255)` | 2 chiều | Tên icon |
| 10 | `color` | `color` | `VARCHAR(50)` | 2 chiều | Mã màu Hex |
| 11 | `create_at` | `create_at` | `TIMESTAMP(6)` | Kéo về (Pull) | **Ngày tạo danh mục** (đã được bổ sung vào select của Sync Engine) |
| 12 | `is_deleted` | `delete_at` | `BOOLEAN` / `TIMESTAMP` | 2 chiều | Trạng thái xóa mềm (hỗ trợ khôi phục danh mục) |
| 13 | `update_at` | `update_at` | `TIMESTAMP(6)` | 2 chiều | Mốc thời gian cập nhật LWW |
| 14 | `server_update_at` | `server_update_at` | `TIMESTAMP(6)` | Kéo về (Pull) | Giờ server cập nhật bản ghi UTC, mốc Delta Pull |

---

### 3.3. Mục tiêu tiết kiệm (`Goals` — 24 trường)

| STT | Tên trường Dart (Client) | Tên cột PostgreSQL | Kiểu dữ liệu | Chiều đồng bộ | Ghi chú kỹ thuật & Ràng buộc |
|:---:|---|---|---|:---:|---|
| 1 | `id` / `idgoal` | `idgoal` | `VARCHAR(36)` | 2 chiều | UUID v4 khóa chính |
| 2 | `idaccount` | `idaccount` | `INT` | 2 chiều | Tài khoản sở hữu |
| 3 | `idwallet` / `walletId` | `idwallet` | `VARCHAR(36)` | 2 chiều | Ví liên kết gom tiền (tùy chọn, `null` nếu tích lũy độc lập) |
| 4 | `name` | `name` | `VARCHAR(100)` | 2 chiều | Tên mục tiêu (Mua xe, Mua nhà, Du lịch...) |
| 5 | `target_amount` | `target_amount` | `DECIMAL(15,2)` | 2 chiều | Số tiền mục tiêu cần tích lũy |
| 6 | `current_amount` | `current_amount` | `DECIMAL(15,2)` | 2 chiều | Số tiền hiện tích lũy được |
| 7 | `start_date` | `start_date` | `TIMESTAMP(6)` | 2 chiều | Ngày bắt đầu mục tiêu |
| 8 | `target_date` | `target_date` | `TIMESTAMP(6)` | 2 chiều | Ngày dự kiến hoàn thành mục tiêu |
| 9 | `cycle_take_money` | `cycle_take_money` | `VARCHAR(7)` | 2 chiều | Chu kỳ gom tiền (`Day`, `Week`, `Month`, `Year`) |
| 10 | `time_cycle_take_money` | `time_cycle_take_money` | `TIMESTAMP(6)` | 2 chiều | Thời điểm tiếp theo trong chu kỳ gom tiền |
| 11 | `auto_deposit_amount` | `auto_deposit_amount` | `DECIMAL(18,2)` | 2 chiều | Số tiền trích tự động mỗi kỳ |
| 12 | `auto_deposit_wallet_id` | `auto_deposit_wallet_id` | `VARCHAR(36)` | 2 chiều | Ví nguồn dùng để tự động trích tiền |
| 13 | `auto_deposit_last_run` | `auto_deposit_last_run` | `TIMESTAMP(6)` | 2 chiều | Thời điểm trích tự động gần nhất (tránh trích trùng lặp) |
| 14 | `priority` | `priority` | `INT` | 2 chiều | Thứ tự ưu tiên người dùng sắp xếp kéo thả (số nhỏ đứng trước, `null` nếu chưa sắp) |
| 15 | `status_complete` | `status_complete` | `VARCHAR(20)` | 2 chiều | `'True'` (đã đạt mục tiêu) hoặc `'False'` (chưa đạt) |
| 16 | `recurrence` | `recurrence` | `BOOLEAN` | 2 chiều | Cờ lặp lại mục tiêu sau khi hoàn thành |
| 17 | `time_recurrence` | `time_recurrence` | `VARCHAR(7)` | 2 chiều | Chu kỳ lặp lại (`Day`, `Week`, `Month`, `Year`) |
| 18 | `icon` | `icon` | `VARCHAR(255)` | 2 chiều | Icon đại diện |
| 19 | `color` | `color` | `VARCHAR(50)` | 2 chiều | Màu sắc Hex |
| 20 | `note` | `note` | `TEXT` | 2 chiều | Ghi chú mục tiêu (mã hóa an toàn) |
| 21 | `create_at` | `create_at` | `TIMESTAMP(6)` | Kéo về (Pull) | Thời điểm tạo mục tiêu |
| 22 | `is_deleted` | `delete_at` | `BOOLEAN` / `TIMESTAMP` | 2 chiều | Trạng thái xóa mềm |
| 23 | `update_at` | `update_at` | `TIMESTAMP(6)` | 2 chiều | Mốc cập nhật LWW |
| 24 | `server_update_at` | `server_update_at` | `TIMESTAMP(6)` | Kéo về (Pull) | Giờ server cập nhật bản ghi UTC, mốc Delta Pull |

---

### 3.4. Hóa đơn định kỳ (`Bills` — 24 trường)

| STT | Tên trường Dart (Client) | Tên cột PostgreSQL | Kiểu dữ liệu | Chiều đồng bộ | Ghi chú kỹ thuật & Ràng buộc |
|:---:|---|---|---|:---:|---|
| 1 | `id` / `idbill` | `idbill` | `VARCHAR(36)` | 2 chiều | UUID v4 khóa chính |
| 2 | `idaccount` | `idaccount` | `INT` | 2 chiều | Tài khoản sở hữu |
| 3 | `idwallet` / `walletId` | `idwallet` | `VARCHAR(36)` | 2 chiều | Ví chi trả mặc định |
| 4 | `idcategory` / `categoryId` | `idcategory` | `VARCHAR(36)` / `INT` | 2 chiều | Danh mục hóa đơn |
| 5 | `name` | `name` | `VARCHAR(100)` | 2 chiều | Tên hóa đơn (Tiền điện, Nước, Internet...) |
| 6 | `amount` | `amount` | `DECIMAL(15,2)` | 2 chiều | Số tiền hóa đơn |
| 7 | `start_date` | `start_date` | `TIMESTAMP(6)` | 2 chiều | Ngày bắt đầu hiệu lực |
| 8 | `due_date` | `due_date` | `TIMESTAMP(6)` | 2 chiều | Hạn chót thanh toán kỳ này |
| 9 | `pay_status` | `pay_status` | `VARCHAR(7)` | 2 chiều | Nhận đúng 4 giá trị chuẩn (`chk_bill_pay_status`): `'Pending'`, `'Payed'`, `'Skipped'` (Bỏ qua kỳ), `'Overdue'` |
| 10 | `recurrence` | `recurrence` | `BOOLEAN` | 2 chiều | Lặp lại định kỳ (`true`) hay hóa đơn 1 lần (`false`) |
| 11 | `time_recurrence` | `time_recurrence` | `VARCHAR(7)` | 2 chiều | Chu kỳ lặp (`Day`, `Week`, `Month`, `Quarter`, `Year`) |
| 12 | `time_notification` | `time_notification` | `VARCHAR(20)` | 2 chiều | Số ngày nhắc trước hạn thanh toán (ví dụ: `'3'`) |
| 13 | `icon` | `icon` | `VARCHAR(255)` | 2 chiều | Icon đại diện |
| 14 | `color` | `color` | `VARCHAR(50)` | 2 chiều | Màu sắc Hex |
| 15 | `note` | `note` | `TEXT` | 2 chiều | Ghi chú (mã hóa an toàn) |
| 16 | `previous_bill_id` | `previous_bill_id` | `VARCHAR(36)` | 2 chiều | UUID kỳ trước của chuỗi hóa đơn lặp (giữ liền mạch chuỗi kỳ) |
| 17 | `period_end` | `period_end` | `DATE` | 2 chiều | **Ân hạn hóa đơn:** Ngày kết thúc kỳ thực tế tách biệt hạn trả. Gửi lúc 00:00 UTC của ngày cục bộ. |
| 18 | `auto_pay` | `auto_pay` | `BOOLEAN` | 2 chiều | **Công tắc tự động thanh toán:** `true`/`false` kiểu boolean thật. |
| 19 | `anchor_day` | `anchor_day` | `SMALLINT` | 2 chiều | Ngày gốc trong tháng (vd: 28, 30, 31) để chống trôi ngày đến hạn khi rơi vào tháng 2 |
| 20 | `create_at` | `create_at` | `TIMESTAMP(6)` | Kéo về (Pull) | Thời điểm tạo hóa đơn |
| 21 | `is_deleted` | `delete_at` | `BOOLEAN` / `TIMESTAMP` | 2 chiều | Trạng thái xóa mềm |
| 22 | `update_at` | `update_at` | `TIMESTAMP(6)` | 2 chiều | Mốc cập nhật LWW |
| 23 | `server_update_at` | `server_update_at` | `TIMESTAMP(6)` | Kéo về (Pull) | Giờ server cập nhật bản ghi UTC, mốc Delta Pull |

---

### 3.5. Ngân sách chi tiêu (`Budgets` — 19 trường)

| STT | Tên trường Dart (Client) | Tên cột PostgreSQL | Kiểu dữ liệu | Chiều đồng bộ | Ghi chú kỹ thuật & Ràng buộc |
|:---:|---|---|---|:---:|---|
| 1 | `id` / `idbudget` | `idbudget` | `VARCHAR(36)` | 2 chiều | UUID v4 khóa chính |
| 2 | `idaccount` | `idaccount` | `INT` | 2 chiều | Tài khoản sở hữu |
| 3 | `idcategory` | `idcategory` | `VARCHAR(36)` / `INT` | 2 chiều | Danh mục áp dụng (`null` nếu áp dụng cho toàn bộ chi tiêu) |
| 4 | `total_amount` | `total_amount` | `DECIMAL(15,2)` | 2 chiều | Hạn mức ngân sách tối đa |
| 5 | `spent` | `spent` | `DECIMAL(15,2)` | 2 chiều | Số tiền đã chi tiêu trong kỳ ngân sách |
| 6 | `threshold_warning_amount` | `threshold_warning_amount` | `DECIMAL(15,2)` | 2 chiều | Số tiền chạm ngưỡng sẽ cảnh báo (tùy chọn) |
| 7 | `threshold_warning_percent` | `threshold_warning_percent` | `INT` | 2 chiều | **Tỷ lệ phần trăm cảnh báo (vd: 80%):** Lưu kiểu số nguyên (0-100) |
| 8 | `over_spending` | `over_spending` | `VARCHAR(7)` | 2 chiều | Trạng thái vượt hạn mức: `'Over'` hoặc `'Stop'` |
| 9 | `over_amount` | `over_amount` | `DECIMAL(15,2)` | 2 chiều | Số tiền bội chi vượt hạn mức |
| 10 | `start` | `start` | `TIMESTAMP(6)` | 2 chiều | Ngày bắt đầu kỳ ngân sách |
| 11 | `end` | `end` | `TIMESTAMP(6)` | 2 chiều | Ngày kết thúc kỳ ngân sách |
| 12 | `recurrence` | `recurrence` | `BOOLEAN` | 2 chiều | Có tự động gia hạn sang kỳ kế tiếp không |
| 13 | `time_recurrence` | `time_recurrence` | `VARCHAR(7)` | 2 chiều | Chu kỳ ngân sách (`Week`, `Month`, `Quarter`, `Year`) |
| 14 | `nexttime_recurrence` | `nexttime_recurrence` | `TIMESTAMP(6)` | 2 chiều | Thời điểm chu kỳ kế tiếp bắt đầu |
| 15 | `note` | `note` | `TEXT` | 2 chiều | Ghi chú ngân sách (mã hóa an toàn) |
| 16 | `create_at` | `create_at` | `TIMESTAMP(6)` | Kéo về (Pull) | Thời điểm tạo ngân sách |
| 17 | `is_deleted` | `delete_at` | `BOOLEAN` / `TIMESTAMP` | 2 chiều | Trạng thái xóa mềm |
| 18 | `update_at` | `update_at` | `TIMESTAMP(6)` | 2 chiều | Mốc cập nhật LWW |
| 19 | `server_update_at` | `server_update_at` | `TIMESTAMP(6)` | Kéo về (Pull) | Giờ server cập nhật bản ghi UTC, mốc Delta Pull |

---

### 3.6. Giao dịch thu/chi (`Transactions` — 18 trường)

| STT | Tên trường Dart (Client) | Tên cột PostgreSQL | Kiểu dữ liệu | Chiều đồng bộ | Ghi chú kỹ thuật & Ràng buộc |
|:---:|---|---|---|:---:|---|
| 1 | `id` / `idtran` | `idtran` | `VARCHAR(36)` | 2 chiều | UUID v4 khóa chính |
| 2 | `idaccount` | `idaccount` | `INT` | 2 chiều | Tài khoản sở hữu |
| 3 | `walletId` / `idwallet` | `idwallet` | `VARCHAR(36)` | 2 chiều | Ví phát sinh giao dịch |
| 4 | `categoryId` / `idcategory` | `idcategory` | `VARCHAR(36)` / `INT` | 2 chiều | Danh mục giao dịch (`null` nếu là chuyển tiền ví) |
| 5 | `idwallet_transfer` | `idwallet_transfer` | `VARCHAR(36)` | 2 chiều | Ví đích (khi chuyển khoản giữa 2 ví, `null` nếu giao dịch thường) |
| 6 | `idgoal` | `idgoal` | `VARCHAR(36)` | 2 chiều | Khóa ngoại nối tới Mục tiêu tiết kiệm (khoản nạp mục tiêu) |
| 7 | `idbill` | `idbill` | `VARCHAR(36)` | 2 chiều | Khóa ngoại nối tới Hóa đơn (khoản thanh toán hóa đơn) |
| 8 | `bank_tran_id` | `bank_tran_id` | `VARCHAR(255)` | 2 chiều | Mã giao dịch phía Ngân hàng liên kết đối soát (`null` nếu nhập tay) |
| 9 | `amount` | `amount` | `DECIMAL(15,2)` | 2 chiều | **Dấu quy ước:** Dấu Âm (`< 0`) là Chi tiêu; Dấu Dương (`> 0`) là Thu nhập |
| 10 | `type` | `type` | `VARCHAR(20)` | 2 chiều | **CHECK `chk_transaction_type`:** Chỉ nhận đúng 2 giá trị trên server: `'Transaction'` hoặc `'Transfer'`. Client đổi `chi`/`thu` thành `Transaction`! |
| 11 | `status` | `status` | `VARCHAR(20)` | 2 chiều | Trạng thái xác thực giao dịch: `'Pending'`, `'Confirmed'`, `'Rejected'`, `'Fail'` |
| 12 | `provider` | `provider` | `VARCHAR(20)` | 2 chiều | Nguồn tạo: `'Manual'`, `'BankSync'`, `'Casso'`, `'SMS'`, `'OCR'`, `'Bill'` |
| 13 | `note` | `note` | `TEXT` | 2 chiều | Nội dung ghi chú giao dịch (Backend tự mã hóa AES-256-GCM) |
| 14 | `images` | `images` | `VARCHAR(500)` | 2 chiều | Storage key / URL ảnh chứng từ đính kèm (Pull về được presign URL) |
| 15 | `dateTransaction` / `date_transaction` | `date_transaction` | `TIMESTAMP(6)` | 2 chiều | Thời điểm giao dịch thực tế diễn ra |
| 16 | `is_deleted` | `deleted_at` | `BOOLEAN` / `TIMESTAMP` | 2 chiều | ⚠️ Cột trong DB là `deleted_at` (có chữ `d` ở cuối) |
| 17 | `update_at` | `update_at` | `TIMESTAMP(6)` | 2 chiều | Mốc thời gian LWW |
| 18 | `server_update_at` | `server_update_at` | `TIMESTAMP(6)` | Kéo về (Pull) | Giờ server cập nhật bản ghi UTC, mốc Delta Pull |

---

## 4. CƠ CHẾ KÉO DELTA PULL THEO GIỜ SERVER (`server_update_at` UTC)

Nhằm giải quyết triệt để rủi ro lệch đồng hồ phần cứng giữa điện thoại và máy chủ (Clock Drift):
1. **Toàn vẹn CSDL:** CSDL PostgreSQL đã tích hợp cột `server_update_at TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC')` cho cả 6 bảng đồng bộ, đi kèm Trigger Function tự động cập nhật mỗi khi có thao tác INSERT hoặc UPDATE.
2. **Nguyên tắc Kéo Delta (`/api/sync/pull?since=...`):**
   - Phía Client-app lưu `lastPullTime` theo giá trị `pulledAt` do Backend trả về trong phản hồi kỳ trước.
   - Khi gọi pull, Backend lọc: `WHERE server_update_at > :since`.
   - Client-app kẹp dải thời gian an toàn `maxSince = max(since, pulledAt - 2 phút)` để bù đắp các giao dịch đang nằm trong transaction chưa kịp commit, đảm bảo không bỏ sót bất kỳ dữ liệu nào.

---

## 5. CƠ CHẾ GIẢI QUYẾT XUNG ĐỘT & PHÒNG CHỐNG LỖI KẸT SYNC

1. **Last-Write-Wins (LWW):**  
   - Backend so sánh trường `update_at` gửi lên từ Client với `update_at` hiện có trong CSDL.
   - Nếu `client.update_at > server.update_at`: Chấp nhận cập nhật, gán `server_update_at = now()`.
   - Nếu `client.update_at <= server.update_at`: Từ chối ghi đè, trả về mã trạng thái `conflict` kèm dữ liệu mới nhất của máy chủ để Client cập nhật lại SQLite cục bộ.
2. **Chống Thanh Toán Trùng Hóa Đơn (`BILL_ALREADY_PAID`):**  
   - Sync Engine kiểm tra nếu giao dịch thanh toán hóa đơn đã tồn tại trong CSDL cho `idbill` đó thì sẽ trả lỗi `BILL_ALREADY_PAID` thay vì ném lỗi máy chủ.
   - Tương tự, nếu cùng kỳ hóa đơn anh em đã được thanh toán, Backend bảo vệ chống thanh toán trùng 2 lần.

---

## 6. CHECKLIST SỬA ĐỔI BỔ SUNG DÀNH CHO DEV CLIENT-APP

Để đạt mức tương thích 100% với hệ thống Backend và vượt qua bài test hợp đồng `sync_payload_contract_test.dart`:

- [ ] **1. Thứ tự mảng operations khi Push:** Bắt buộc sắp xếp: `categories` $\to$ `wallets` $\to$ `goals` $\to$ `bills` $\to$ `budgets` $\to$ `transactions`.
- [ ] **2. Khóa ngoại `idgoal` và `idbill` trong giao dịch:** Gửi đúng tên khóa `idgoal` (không gửi `goal_id`) và `idbill` (không gửi `bill_id`).
- [ ] **3. Giá trị `type` và dấu của `amount` trong giao dịch:**
  - Khoản Chi: `type = 'Transaction'`, `amount < 0`.
  - Khoản Thu: `type = 'Transaction'`, `amount > 0`.
  - Khoản Chuyển ví: `type = 'Transfer'`, giữ `idwallet_transfer`, gán `idcategory = null`.
- [ ] **4. Các trường mới của Transaction:** Bổ sung `status` (`Pending`, `Confirmed`, `Rejected`, `Fail`), `provider` (`Manual`, `BankSync`, `Casso`, `SMS`, `OCR`, `Bill`), `images`, `bank_tran_id`.
- [ ] **5. Trạng thái ví (`status`):** Gửi nguyên văn `'Active'` hoặc `'Inactive'` (chữ hoa đầu) theo ràng buộc `chk_wallet_status`. Bổ sung `id_bank_casso`.
- [ ] **6. Nhánh Kéo Ví về (Pull):** Không đọc đè cột `balance` từ server (`Value.absent()`), để bảo toàn số dư tính toán cục bộ.
- [ ] **7. Hóa đơn `pay_status` và `auto_pay`:** Gửi đúng 4 chuỗi: `'Pending'`, `'Payed'`, `'Skipped'`, `'Overdue'`; `auto_pay` kiểu boolean thật. Bổ sung `period_end`, `anchor_day`, `previous_bill_id`.
- [ ] **8. Mục tiêu `priority`:** Gửi số nguyên dương (vd: 100, 200) hoặc `null` (nếu chưa xếp thứ tự); không gửi `0`. Bổ sung `auto_deposit_amount`, `auto_deposit_wallet_id`, `auto_deposit_last_run`.
- [ ] **9. Ngân sách `threshold_warning_percent`:** Gửi đúng kiểu số nguyên (0-100). Bổ sung `spent`, `over_spending` (`Stop`/`Over`), `over_amount`.
- [ ] **10. Danh mục:** Đọc trường `create_at` mới được trả về từ Server để sắp xếp hoặc lọc theo thời gian tạo.
