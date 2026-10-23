# 🔄 TÀI LIỆU HỢP ĐỒNG ĐỒNG BỘ CƠ SỞ DỮ LIỆU: SQLITE (CLIENT-APP) ➔ POSTGRESQL (BACKEND)
### (Database Synchronization Specification & Schema Alignment for SQLite Drift)

> **Mã tài liệu:** `DOC-SYNC-SQLITE-BACKEND-v3.2`  
> **Áp dụng cho:** Client-app (Flutter / Drift SQLite) & Backend (NodeJS Express / PostgreSQL Supabase)  
> **Phiên bản:** `3.2` (Cập nhật sau đợt chuẩn hóa CSDL & Fix Issue toàn diện ngày 23/10/2026)  
> **Tệp kiểm thử hợp đồng chuẩn (Client):** `src/Client-app/test/core/sync/sync_payload_contract_test.dart`  
> **Mã nguồn xử lý Backend:** `src/Backend/modules/sync/` (`sync.repository.js`, `sync.service.js`, `sync.controller.js`, `sync.validation.js`)  
> **Nguyên tắc bảo vệ:** Tuyệt đối không suy diễn, khớp 100% từng tên trường, kiểu dữ liệu và ràng buộc CSDL.

---

## 📌 MỤC LỤC HỆ THỐNG
1. [Nguyên Tắc Cốt Lõi Của Sync Engine (Offline-First 2-Way Sync)](#1-nguyên-tắc-cốt-lõi-của-sync-engine)
2. [Thứ Tự Đẩy Dữ Liệu Bắt Buộc (Push Dependency Order)](#2-thứ-tự-đẩy-dữ-liệu-bắt-buộc-push-dependency-order)
3. [Đặc Tả Chi Tiết 6 Bảng Đồng Bộ Nghiệp Vụ Tài Chính (2-Way Sync)](#3-đặc-tả-chi-tiết-6-bảng-đồng-bộ-nghiệp-vụ-tài-chính-2-way-sync)
   - [3.1. Bảng Ví tài chính (`Wallets` — 13 trường)](#31-bảng-ví-tài-chính-wallets--13-trường-đồng-bộ)
   - [3.2. Bảng Danh mục chi tiêu (`Categories` — 12 trường + Từ khóa AI)](#32-bảng-danh-mục-chi-tiêu-categories--12-trường-đồng-bộ--từ-khóa-ai)
   - [3.3. Bảng Mục tiêu tiết kiệm (`Goals` — 22 trường)](#33-bảng-mục-tiêu-tiết-kiệm-goals--22-trường-đồng-bộ)
   - [3.4. Bảng Hóa đơn & Dịch vụ định kỳ (`Bills` — 21 trường)](#34-bảng-hóa-đơn--dịch-vụ-định-kỳ-bills--21-trường-đồng-bộ)
   - [3.5. Bảng Ngân sách chi tiêu (`Budgets` — 17 trường)](#35-bảng-ngân-sách-chi-tiêu-budgets--17-trường-đồng-bộ)
   - [3.6. Bảng Giao dịch thu/chi & chuyển ví (`Transactions` — 13 trường)](#36-bảng-giao-dịch-thuchi--chuyển-ví-transactions--13-trường-đồng-bộ)
4. [Các Bảng Lưu Trữ Cục Bộ & Thông Tin Cấu Hình Cần Có Tại SQLite](#4-các-bảng-lưu-trữ-cục-bộ--thông-tin-cấu-hình-cần-có-tại-sqlite)
   - [4.1. Thông tin Người dùng & Trạng thái Tài khoản (`user_profile`)](#41-thông-tin-người-dùng--trạng-thái-tài-khoản-user_profile)
   - [4.2. Nhận diện Thiết bị & Theo dõi Lịch sử Truy cập (`device_tracking`)](#42-nhận-diện-thiết-bị--theo-dõi-lịch-sử-truy-cập-device_tracking)
   - [4.3. Bộ đệm Phân quyền 4 Trụ cột Đa tầng (`permissions_cache`)](#43-bộ-đệm-phân-quyền-4-trụ-cột-đa-tầng-permissions_cache)
   - [4.4. Hộp thư Thông báo Cá nhân & Sự kiện Hệ thống (`notifications`)](#44-hộp-thư-thông-báo-cá-nhân--sự-kiện-hệ-thống-notifications)
5. [Cơ Chế Kéo Dữ Liệu Delta Pull Theo Giờ Server (`Server_update_at` UTC)](#5-cơ-chế-kéo-dữ-liệu-delta-pull-theo-giờ-server-server_update_at-utc)
6. [Checklist Sống Còn Dành Cho Kỹ Sư Phát Triển Phía Client-App](#6-checklist-sống-còn-dành-cho-kỹ-sư-phát-triển-phía-client-app)

---

## 1. NGUYÊN TẮC CỐT LÕI CỦA SYNC ENGINE

1. **Kiến Trúc Offline-First Tuyệt Đối:**  
   Người dùng có quyền Thêm, Sửa, Xóa (CRUD) toàn bộ dữ liệu trên thiết bị di động ngay cả khi ngắt kết nối mạng Internet. SQLite Drift là nơi lưu trữ sự thật cục bộ tức thời.
2. **Khóa Chính Định Danh Bản Ghi Toàn Cầu (UUID v4):**  
   Mọi bản ghi dữ liệu thuộc 6 mô-đun nghiệp vụ đều sử dụng chuỗi UUID v4 chuẩn (36 ký tự, ví dụ: `11111111-1111-4111-8111-111111111111`), được tạo trực tiếp trên điện thoại lúc offline và bảo toàn nguyên vẹn khi đồng bộ lên PostgreSQL Backend. Tuyệt đối không dùng số nguyên tự tăng (`autoincrement`) cho các thực thể đồng bộ 2 chiều.
3. **Giải Quyết Xung Đột Theo Nguyên Tắc Last-Write-Wins (LWW):**  
   Khi có xung đột giữa 2 thiết bị, bản ghi nào có dấu thời gian `update_at` (chuẩn UTC ISO 8601) lớn hơn sẽ chiến thắng và ghi đè bản ghi cũ hơn.
4. **Bảo Tồn Xóa Mềm (Soft-Delete Preservation):**  
   Khi người dùng xóa bản ghi trên app, tuyệt đối **KHÔNG chạy lệnh `DELETE` vật lý** trong SQLite mà cập nhật cờ `isDeleted = true` và `updatedAt = DateTime.now().toUtc()`. Khi đẩy lên máy chủ, Backend ghi nhận vào cột `Delete_at = now()` (hoặc `Deleted_at`).
5. **Cách Ly Dữ Liệu Theo Tài Khoản (User-Scoped Isolation):**  
   Mọi bảng trong SQLite và mọi truy vấn Backend bắt buộc ràng buộc chặt chẽ theo `idaccount` lấy từ JWT Access Token.

---

## 2. THỨ TỰ ĐẨY DỮ LIỆU BẮT BUỘC (PUSH DEPENDENCY ORDER)

Do CSDL PostgreSQL áp dụng các ràng buộc Khóa Ngoại (Foreign Keys) nghiêm ngặt để đảm bảo toàn vẹn dữ liệu, Client-app **BẮT BUỘC PHẢI SẮP XẾP MẢNG `operations` TRONG PAYLOAD ĐẨY LÊN (`/api/sync/push`)** theo đúng thứ tự phụ thuộc xác định sau:

$$\mathbf{categories} \longrightarrow \mathbf{wallets} \longrightarrow \mathbf{goals} \longrightarrow \mathbf{bills} \longrightarrow \mathbf{budgets} \longrightarrow \mathbf{transactions}$$

### Bảng Trọng Số Điều Phối Phía Backend (`ENTITY_PRIORITY`):
| Thực thể (`entity`) | Trọng số Tạo/Sửa (`operation = create/update`) | Trọng số Xóa (`operation = delete`) | Lý do ràng buộc kỹ thuật |
|---|:---:|:---:|---|
| `category` | **10** | **90** | Độc lập, là danh mục cha cho các thực thể khác. |
| `wallet` | **20** | **80** | Độc lập, là nguồn tiền chi trả cho bills, goals, transactions. |
| `goal` | **30** | **70** | Phụ thuộc vào `wallet` (ví đích). |
| `bill` | **31** | **69** | Phụ thuộc vào `wallet` và `category`. |
| `budget` | **32** | **68** | Phụ thuộc vào `category`. |
| `transaction` | **40** | **60** | **Phụ thuộc vào cả 5 thực thể trên:** mang khóa ngoại `idwallet`, `idcategory`, `idwallet_transfer`, `idgoal`, `idbill`. |

> ⚠️ **CẢNH BÁO NGUY HIỂM SỐNG CÒN:**  
> Bảng `transaction` mang khóa ngoại `idgoal` (trỏ tới `goal`) và `idbill` (trỏ tới `bill`). Khi người dùng tạo một Mục tiêu mới hoặc Hóa đơn mới rồi thực hiện nạp tiền / thanh toán ngay lúc đang Offline, cả 2 bản ghi đều nằm chung trong hàng đợi đẩy `pending`.  
> **NẾU ĐẨY `transaction` TRƯỚC `goal` HOẶC `bill`, POSTGRESQL SẼ NÉM LỖI 400 FOREIGN KEY VIOLATION VÀ GIAO DỊCH BỊ KẸT VĨNH VIỄN TRÊN MÁY!**

---

## 3. ĐẶC TẢ CHI TIẾT 6 BẢNG ĐỒNG BỘ NGHIỆP VỤ TÀI CHÍNH (2-WAY SYNC)

---

### 3.1. Bảng Ví tài chính (`Wallets` — 13 trường đồng bộ)

Cấu trúc lớp Drift SQLite: `Wallets extends Table` trong `wallets_table.dart`.

| STT | Tên trường Dart (Client) | Tên cột PostgreSQL | Kiểu dữ liệu SQLite | Kiểu dữ liệu PostgreSQL | Chiều đồng bộ | Ràng buộc & Quy tắc nghiệp vụ bắt buộc |
|:---:|---|---|---|---|:---:|---|
| 1 | `id` | `Idwallet` | `TEXT` | `VARCHAR(36)` | 2 chiều | **Khóa chính (PK):** Chuỗi UUID v4 (36 ký tự). |
| 2 | `idaccount` | `Idaccount` | `INTEGER` | `INT` | 2 chiều | **Khóa ngoại (FK):** ID tài khoản sở hữu. |
| 3 | `name` | `NameWallet` | `TEXT` | `VARCHAR(100)` | 2 chiều | Tên ví hiển thị (tối đa 100 ký tự). |
| 4 | `type` | `Type` | `TEXT` | `VARCHAR(20)` | 2 chiều | **CHECK `chk_wallet_type`:** Client dùng `'cash'`, `'bank'`, `'saving'`, `'banking'`. Khi đẩy lên Backend chuẩn hóa viết hoa. |
| 5 | `balance` | `Balance` | `REAL` | `DECIMAL(15,2)` | **1 CHIỀU (Push)** | ⚠️ **HỢP ĐỒNG 1 CHIỀU:** Client đẩy lên để Server ghi nhận thống kê. **Khi Kéo về (Pull) BẮT BUỘC BỎ QUA (`Value.absent()`)**, tuyệt đối không ghi đè số dư ví từ server vì số dư ví là cache tổng sổ của giao dịch cục bộ! |
| 6 | `currency` | `Currency` | `TEXT` | `VARCHAR(3)` | 2 chiều | Mặc định `'VND'`. |
| 7 | `icon` | `Icon` | `TEXT` | `VARCHAR(20)` | 2 chiều | Tên icon nhận diện giao diện. |
| 8 | `color` | `Color` | `TEXT` | `VARCHAR(9)` | 2 chiều | Mã màu Hex `#RRGGBB`. Client gửi `color` (Normalizer đổi `colour` $\to$ `color`). |
| 9 | `is_default` | `Is_default` | `BOOLEAN` | `BOOLEAN` | 2 chiều | Đánh dấu ví mặc định khi tạo giao dịch mới. |
| 10 | `is_deleted` | `Delete_at` | `BOOLEAN` | `TIMESTAMP(6)` | 2 chiều | Xóa mềm: Push gửi `is_deleted = true` $\to$ Server ghi `Delete_at = now()`. |
| 11 | `include_in_total`| `Include_in_total`| `BOOLEAN` | `BOOLEAN` | 2 chiều | `true`: số dư ví được tính vào tổng tài sản trên Dashboard. |
| 12 | `status` | `Status` | `TEXT` | `VARCHAR(20)` | 2 chiều | **CHECK `chk_wallet_status`:** **BẮT BUỘC CHỮ HOA ĐẦU:** `'Active'` hoặc `'Inactive'`. Gửi chữ thường `'inactive'` sẽ bị CSDL từ chối! |
| 13 | `update_at` | `Update_at` | `DATETIME` | `TIMESTAMP(6)` | 2 chiều | Mốc thời gian cập nhật Last-Write-Wins (UTC ISO 8601). |

#### Các cột CỤC BỘ đặc thù tại SQLite Drift của Bảng `Wallets` (KHÔNG đồng bộ):
- `allow_negative` (`allow_negative`): Ví cho phép mang số dư âm (thẻ tín dụng). Cột cục bộ, không gửi lên server.
- `bi_tu_choi_trung_ten`: Cờ đánh dấu ví bị từ chối do trùng tên khi đẩy lên server.
- `bank_casso_id`: ID liên kết ngân hàng Casso (nếu có).
- `syncStatus`: `'pending'` (chờ đẩy) hoặc `'synced'` (đã khớp).
- `syncRetryCount`, `syncError`, `syncBlockedUntil`: Quản lý thử lại khi mạng chập chờn.

---

### 3.2. Bảng Danh mục chi tiêu (`Categories` — 12 trường đồng bộ + Từ khóa AI)

Cấu trúc lớp Drift SQLite: `Categories extends Table` trong `categories_table.dart`.

| STT | Tên trường Dart (Client) | Tên cột PostgreSQL | Kiểu dữ liệu SQLite | Kiểu dữ liệu PostgreSQL | Chiều đồng bộ | Ràng buộc & Quy tắc nghiệp vụ bắt buộc |
|:---:|---|---|---|---|:---:|---|
| 1 | `id` | `Idcategory` | `TEXT` | `VARCHAR(36)` | 2 chiều | **Khóa chính (PK):** Chuỗi UUID v4. |
| 2 | `idaccount` | `Create_by` | `INTEGER` | `INT` | 2 chiều | ID tài khoản tạo danh mục cá nhân (hoặc `1` nếu là danh mục mặc định của hệ thống). |
| 3 | `name` / `namecategory` | `NameCategory` | `TEXT` | `VARCHAR(200)` | 2 chiều | Tên danh mục hiển thị (tối đa 200 ký tự). |
| 4 | `classify` | `Classify` | `TEXT` | `VARCHAR(7)` | 2 chiều | **CHECK `chk_category_classify`:** Chỉ nhận 3 giá trị: `'Thu'`, `'Chi'`, `'Vay/no'`. |
| 5 | `is_default` | `Is_default` | `BOOLEAN` | `BOOLEAN` | 2 chiều | `true`: Danh mục hệ thống; `false`: Danh mục riêng của người dùng. |
| 6 | `isGroup` | `Is_group` | `BOOLEAN` | `BOOLEAN` | 2 chiều | `true`: Danh mục cha (nhóm mẹ); `false`: Danh mục con bình thường. |
| 7 | `parentId` | `Idgroup` | `TEXT` | `VARCHAR(36)` | 2 chiều | UUID trỏ tới `idcategory` của danh mục cha (bảo toàn cấu trúc cây nhóm). |
| 8 | `icon` | `Icon` | `TEXT` | `VARCHAR(20)` | 2 chiều | Icon nhận diện danh mục. |
| 9 | `color` | `Color` | `TEXT` | `VARCHAR(9)` | 2 chiều | Mã màu Hex `#RRGGBB`. |
| 10 | `keyword` | `Keyword` | `TEXT` | `TEXT` | 2 chiều | **Từ khóa AI NLP học máy:** Chuỗi từ khóa phân cách dấu phẩy phục vụ AI phân loại giao dịch tự động. |
| 11 | `is_deleted` | `Delete_at` | `BOOLEAN` | `TIMESTAMP(6)` | 2 chiều | Xóa mềm danh mục. |
| 12 | `update_at` | `Update_at` | `DATETIME` | `TIMESTAMP(6)` | 2 chiều | Mốc thời gian LWW UTC ISO 8601. |

#### Các bảng Drift SQLite bổ trợ cho Danh mục:
- `CategoryKeywords`: Quản lý bộ từ khóa chuẩn hóa trên thiết bị để tăng tốc thuật toán tìm kiếm On-Device.
- `CategoryGroupMemberships`: Quản lý quan hệ danh mục - nhóm trên local SQLite.
- Cột cục bộ `ai_co_dinh`: Cờ cố định không cho phép thuật toán AI đề xuất cắt giảm ngân sách.

---

### 3.3. Bảng Mục tiêu tiết kiệm (`Goals` — 22 trường đồng bộ)

Cấu trúc lớp Drift SQLite: `Goals extends Table` trong `other_tables.dart`.

| STT | Tên trường Dart (Client) | Tên cột PostgreSQL | Kiểu dữ liệu SQLite | Kiểu dữ liệu PostgreSQL | Chiều đồng bộ | Ràng buộc & Quy tắc nghiệp vụ bắt buộc |
|:---:|---|---|---|---|:---:|---|
| 1 | `id` | `Idgoal` | `TEXT` | `VARCHAR(36)` | 2 chiều | **Khóa chính (PK):** Chuỗi UUID v4. |
| 2 | `idaccount` | `Idaccount` | `INTEGER` | `INT` | 2 chiều | Tài khoản sở hữu mục tiêu. |
| 3 | `idwallet` | `Idwallet` | `TEXT` | `VARCHAR(36)` | 2 chiều | **Ví đích:** Ví chứa tiền tiết kiệm của mục tiêu này (nullable). |
| 4 | `name` | `Name` | `TEXT` | `VARCHAR(100)` | 2 chiều | Tên mục tiêu tích lũy (ví dụ: "Mua xe máy", "Quỹ khẩn cấp"). |
| 5 | `target_amount` | `Target_amount` | `REAL` | `DECIMAL(15,2)` | 2 chiều | Số tiền mục tiêu cần tích lũy. |
| 6 | `current_amount`| `Current_amount`| `REAL` | `DECIMAL(15,2)` | 2 chiều | Số tiền hiện đã tích lũy được. |
| 7 | `start_date` | `Start_date` | `DATETIME` | `TIMESTAMP(6)` | 2 chiều | Ngày bắt đầu tích lũy. |
| 8 | `target_date` | `Target_date` | `DATETIME` | `TIMESTAMP(6)` | 2 chiều | Ngày dự kiến hoàn thành mục tiêu. |
| 9 | `cycle_take_money`| `Cycle_take_money`| `TEXT`| `VARCHAR(7)` | 2 chiều | Chu kỳ trích tiền: `'Day'`, `'Week'`, `'Month'`, `'Quarter'`, `'Year'`. |
| 10 | `time_cycle_take_money`| `Time_cycle_take_money`| `DATETIME`| `TIMESTAMP(6)` | 2 chiều | Mốc thời điểm neo chu kỳ trích tiền trong tháng/tuần. |
| 11 | `status_complete`| `Status_complete`| `TEXT` | `VARCHAR(20)` | 2 chiều | `'True'` (đã hoàn thành mục tiêu) hoặc `'False'` (đang thực hiện). |
| 12 | `recurrence` | `Recurrence` | `BOOLEAN` | `BOOLEAN` | 2 chiều | Cờ tự động gia hạn lặp lại mục tiêu sau khi hoàn tất. |
| 13 | `time_recurrence`| `Time_recurrence`| `TEXT` | `VARCHAR(7)` | 2 chiều | Chu kỳ lặp lại mục tiêu. |
| 14 | `icon` | `Icon` | `TEXT` | `VARCHAR(20)` | 2 chiều | Icon hiển thị. |
| 15 | `color` | `Color` | `TEXT` | `VARCHAR(20)` | 2 chiều | Màu sắc hiển thị. |
| 16 | `note` | `Note` | `TEXT` | `TEXT` | 2 chiều | Ghi chú (được mã hóa bảo vệ an toàn). |
| 17 | `auto_deposit_amount`| `auto_deposit_amount`| `REAL` | `DECIMAL(18,2)` | 2 chiều | **Trích tự động 1:** Số tiền trích mỗi kỳ (`null` nếu tắt). |
| 18 | `auto_deposit_wallet_id`| `auto_deposit_wallet_id`| `TEXT` | `VARCHAR(36)` | 2 chiều | **Trích tự động 2:** Ví NGUỒN trích tiền (khác với `idwallet` là ví đích). |
| 19 | `auto_deposit_last_run`| `auto_deposit_last_run`| `DATETIME` | `TIMESTAMP(6)` | 2 chiều | **Trích tự động 3 (Chống trích 2 lần):** Mốc thời gian kỳ gần nhất đã trích xong. **3 cột trích tự động BẮT BUỘC phải đi cùng nhau trong payload!** |
| 20 | `priority` | `Priority` | `INTEGER` | `INT` | 2 chiều | **Thứ tự kéo thả ưu tiên:** Số nhỏ đứng trước, cách nhau 100 (100, 200, 300...). Gửi `null` nếu chưa sắp, **tuyệt đối KHÔNG gửi `0`**! |
| 21 | `is_deleted` | `Delete_at` | `BOOLEAN` | `TIMESTAMP(6)` | 2 chiều | Xóa mềm mục tiêu. |
| 22 | `update_at` | `Update_at` | `DATETIME` | `TIMESTAMP(6)` | 2 chiều | Mốc cập nhật LWW UTC ISO 8601. |

---

### 3.4. Bảng Hóa đơn & Dịch vụ định kỳ (`Bills` — 21 trường đồng bộ)

Cấu trúc lớp Drift SQLite: `Bills extends Table` trong `other_tables.dart`.

| STT | Tên trường Dart (Client) | Tên cột PostgreSQL | Kiểu dữ liệu SQLite | Kiểu dữ liệu PostgreSQL | Chiều đồng bộ | Ràng buộc & Quy tắc nghiệp vụ bắt buộc |
|:---:|---|---|---|---|:---:|---|
| 1 | `id` | `Idbill` | `TEXT` | `VARCHAR(36)` | 2 chiều | **Khóa chính (PK):** Chuỗi UUID v4. |
| 2 | `idaccount` | `Idaccount` | `INTEGER` | `INT` | 2 chiều | Tài khoản sở hữu hóa đơn. |
| 3 | `idwallet` | `Idwallet` | `TEXT` | `VARCHAR(36)` | 2 chiều | **Khóa ngoại (FK):** Ví thanh toán mặc định. |
| 4 | `idcategory` | `Idcategory` | `TEXT` | `VARCHAR(36)` | 2 chiều | **Khóa ngoại (FK):** Danh mục phân loại hóa đơn (Tiền điện, nước, mạng...). |
| 5 | `name` | `Name` | `TEXT` | `VARCHAR(100)` | 2 chiều | Tên hóa đơn. |
| 6 | `amount` | `Amount` | `REAL` | `DECIMAL(15,2)` | 2 chiều | Số tiền hóa đơn cần chi trả. |
| 7 | `start_date` | `Start_date` | `DATETIME` | `TIMESTAMP(6)` | 2 chiều | Ngày bắt đầu hiệu lực hóa đơn. |
| 8 | `due_date` | `Due_date` | `DATETIME` | `TIMESTAMP(6)` | 2 chiều | Hạn chót thanh toán kỳ hiện tại. |
| 9 | `pay_status` | `Pay_status` | `TEXT` | `VARCHAR(7)` | 2 chiều | **CHECK `chk_bill_pay_status`:** Nhận đúng 4 chuỗi: `'Pending'`, `'Payed'`, `'Skipped'` (bỏ qua kỳ), `'Overdue'`. |
| 10 | `recurrence` | `Recurrence` | `BOOLEAN` | `BOOLEAN` | 2 chiều | Có lặp lại định kỳ không (`true`/`false`). |
| 11 | `time_recurrence`| `Time_recurrence`| `TEXT` | `VARCHAR(7)` | 2 chiều | Chu kỳ lặp: `'Day'`, `'Week'`, `'Month'`, `'Quarter'`, `'Year'`. |
| 12 | `time_notification`| `Time_notification`| `TEXT` | `VARCHAR(20)` | 2 chiều | Số ngày thông báo nhắc trước khi đến hạn (ví dụ: `'3'`). |
| 13 | `icon` | `Icon` | `TEXT` | `VARCHAR(20)` | 2 chiều | Icon đại diện. |
| 14 | `color` | `Color` | `TEXT` | `VARCHAR(20)` | 2 chiều | Màu sắc Hex. |
| 15 | `note` | `Note` | `TEXT` | `TEXT` | 2 chiều | Ghi chú hóa đơn (được mã hóa an toàn). |
| 16 | `previous_bill_id`| `Previous_bill_id`| `TEXT`| `VARCHAR(36)` | 2 chiều | **Khóa nối chuỗi kỳ:** UUID của hóa đơn kỳ TRƯỚC (để phục vụ hoàn tác thanh toán mà không sinh kỳ trùng). |
| 17 | `period_end` | `Period_end` | `DATETIME` | `DATE` | 2 chiều | **Ân hạn hóa đơn:** Ngày kết thúc kỳ thực tế tách biệt hạn trả. **Quy định gửi:** lúc `00:00:00.000Z` UTC của ngày cục bộ. |
| 18 | `auto_pay` | `Auto_pay` | `BOOLEAN` | `BOOLEAN` | 2 chiều | **Công tắc tự động trả:** `true`/`false` kiểu boolean thật. Khi đến hạn, hệ thống tự động sinh khoản chi trả từ `idwallet`. |
| 19 | `anchor_day` | `Anchor_day` | `INTEGER` | `SMALLINT` | 2 chiều | **Ngày neo gốc trong tháng:** 1 đến 31 (chống trôi ngày thanh toán khi gặp tháng 2). |
| 20 | `is_deleted` | `Delete_at` | `BOOLEAN` | `TIMESTAMP(6)` | 2 chiều | Xóa mềm hóa đơn. |
| 21 | `update_at` | `Update_at` | `DATETIME` | `TIMESTAMP(6)` | 2 chiều | Mốc cập nhật LWW UTC ISO 8601. |

---

### 3.5. Bảng Ngân sách chi tiêu (`Budgets` — 17 trường đồng bộ)

Cấu trúc lớp Drift SQLite: `Budgets extends Table` trong `other_tables.dart`.

| STT | Tên trường Dart (Client) | Tên cột PostgreSQL | Kiểu dữ liệu SQLite | Kiểu dữ liệu PostgreSQL | Chiều đồng bộ | Ràng buộc & Quy tắc nghiệp vụ bắt buộc |
|:---:|---|---|---|---|:---:|---|
| 1 | `id` | `Idbudget` | `TEXT` | `VARCHAR(36)` | 2 chiều | **Khóa chính (PK):** Chuỗi UUID v4. |
| 2 | `idaccount` | `Idaccount` | `INTEGER` | `INT` | 2 chiều | Tài khoản sở hữu ngân sách. |
| 3 | `idcategory` | `Idcategory` | `TEXT` | `VARCHAR(36)` | 2 chiều | Danh mục áp dụng ngân sách (`null` = ngân sách tổng cho toàn bộ chi tiêu). |
| 4 | `total_amount` | `Total_amount` | `REAL` | `DECIMAL(15,2)` | 2 chiều | Tổng hạn mức ngân sách được chi trong kỳ. |
| 5 | `spent` | `Spent` | `REAL` | `DECIMAL(15,2)` | 2 chiều | Số tiền đã chi tiêu (Client tự tính toán tổng sổ từ transactions). |
| 6 | `threshold_warning_amount`| `Threshold_warning_amount`| `REAL`| `DECIMAL(15,2)`| 2 chiều| Số tiền chạm ngưỡng sẽ phát cảnh báo (tùy chọn). |
| 7 | `threshold_warning_percent`| `Threshold_warning_percent`| `REAL`/`INTEGER`| `INT`| 2 chiều| **Tỷ lệ phần trăm cảnh báo (vd: 80%):** Lưu kiểu số nguyên từ `0` đến `100`. |
| 8 | `over_spending` | `Over_spending` | `TEXT` | `VARCHAR(7)` | 2 chiều | **CHECK `chk_budget_over_spending`:** Chỉ nhận `'Stop'` (chặn chi) hoặc `'Over'` (cho phép vượt). |
| 9 | `over_amount` | `Over_amount` | `REAL` | `DECIMAL(15,2)` | 2 chiều | Số tiền đã chi vượt hạn mức ngân sách. |
| 10 | `start` | `Start` | `DATETIME` | `TIMESTAMP(6)` | 2 chiều | Ngày bắt đầu chu kỳ ngân sách. |
| 11 | `end` | `End` | `DATETIME` | `TIMESTAMP(6)` | 2 chiều | Ngày kết thúc chu kỳ ngân sách. |
| 12 | `recurrence` | `Recurrence` | `BOOLEAN` | `BOOLEAN` | 2 chiều | Có tự động gia hạn sang kỳ kế tiếp không (`true`/`false`). |
| 13 | `time_recurrence`| `Time_recurrence`| `TEXT` | `VARCHAR(7)` | 2 chiều | Chu kỳ ngân sách: `'Week'`, `'Month'`, `'Quarter'`, `'Year'`, hoặc `null` nếu là ngày cụ thể. |
| 14 | `nexttime_recurrence`| `Nexttime_recurrence`| `DATETIME`| `TIMESTAMP(6)`| 2 chiều| Mốc bắt đầu chu kỳ ngân sách kế tiếp (phải đẩy lại nguyên vẹn khi có). |
| 15 | `note` | `Note` | `TEXT` | `TEXT` | 2 chiều | Ghi chú ngân sách (mã hóa an toàn). |
| 16 | `is_deleted` | `Delete_at` | `BOOLEAN` | `TIMESTAMP(6)` | 2 chiều | Xóa mềm ngân sách. |
| 17 | `update_at` | `Update_at` | `DATETIME` | `TIMESTAMP(6)` | 2 chiều | Mốc cập nhật LWW UTC ISO 8601. |

---

### 3.6. Bảng Giao dịch thu/chi & chuyển ví (`Transactions` — 13 trường đồng bộ)

Cấu trúc lớp Drift SQLite: `Transactions extends Table` trong `transactions_table.dart`.

| STT | Tên trường Dart (Client) | Tên cột PostgreSQL | Kiểu dữ liệu SQLite | Kiểu dữ liệu PostgreSQL | Chiều đồng bộ | Ràng buộc & Quy tắc nghiệp vụ bắt buộc |
|:---:|---|---|---|---|:---:|---|
| 1 | `id` | `Idtran` | `TEXT` | `VARCHAR(36)` | 2 chiều | **Khóa chính (PK):** Chuỗi UUID v4. |
| 2 | `idaccount` | `Idaccount` | `INTEGER` | `INT` | 2 chiều | Tài khoản sở hữu giao dịch. |
| 3 | `walletId` | `Idwallet` | `TEXT` | `VARCHAR(36)` | 2 chiều | **Khóa ngoại (FK):** Ví phát sinh giao dịch nguồn. |
| 4 | `categoryId` | `Idcategory` | `TEXT` | `VARCHAR(36)` | 2 chiều | **Khóa ngoại (FK):** Danh mục chi tiêu/thu nhập (`null` nếu là chuyển tiền ví). |
| 5 | `idwallet_transfer`| `Idwallet_transfer`| `TEXT`| `VARCHAR(36)` | 2 chiều | **Ví đích:** Chỉ có khi chuyển tiền giữa 2 ví nội bộ (`type = 'Transfer'`). |
| 6 | `idgoal` | `Idgoal` | `TEXT` | `VARCHAR(36)` | 2 chiều | **Khóa ngoại (FK):** Trỏ tới Mục tiêu tiết kiệm (khoản nạp tiền vào mục tiêu). Tên payload là `idgoal`, cấm gửi `goal_id`. |
| 7 | `idbill` | `Idbill` | `TEXT` | `VARCHAR(36)` | 2 chiều | **Khóa ngoại (FK):** Trỏ tới Hóa đơn (khoản thanh toán hóa đơn). Tên payload là `idbill`, cấm gửi `bill_id`. |
| 8 | `amount` | `Amount` | `REAL` | `DECIMAL(15,2)` | 2 chiều | ⚠️ **QUY ƯỚC DẤU VÀ TYPE SỐNG CÒN:** Xem chi tiết bảng quy đổi bên dưới! |
| 9 | `type` | `Type` | `TEXT` | `VARCHAR(20)` | 2 chiều | **CHECK `chk_transaction_type`:** Máy chủ chỉ nhận 2 chuỗi: `'Transaction'` hoặc `'Transfer'`. |
| 10 | `note` | `Note` | `TEXT` | `TEXT` | 2 chiều | Nội dung ghi chú (Backend tự động mã hóa AES-256-GCM At-Rest; khi Pull về tự động giải mã). |
| 11 | `dateTransaction`| `DateTransaction`| `DATETIME` | `TIMESTAMP(6)` | 2 chiều | Thời điểm phát sinh giao dịch thực tế. |
| 12 | `is_deleted` | `Deleted_at` | `BOOLEAN` | `TIMESTAMP(6)` | 2 chiều | Cột PostgreSQL mang tên `Deleted_at` (có chữ `d`). |
| 13 | `update_at` | `Update_at` | `DATETIME` | `TIMESTAMP(6)` | 2 chiều | Mốc cập nhật LWW UTC ISO 8601. |

#### ⚠️ QUY ƯỚC BẮT BUỘC: PHÉP QUY ĐỔI GIỮA SQLITE VÀ POSTGRESQL CHO GIAO DỊCH
| Hành vi người dùng | SQLite Drift cục bộ | Payload gửi lên Server (`/sync/push`) | Cột `Type` PostgreSQL | Cột `Amount` PostgreSQL |
|---|---|---|:---:|:---:|
| **Ghi Khoản Chi (Expense)** | `amount > 0` (luôn dương), `type = 'chi'` | `amount: -Math.abs(amount)`, `type: 'Transaction'` | `'Transaction'` | **Số Âm (`< 0`)** |
| **Ghi Khoản Thu (Income)** | `amount > 0` (luôn dương), `type = 'thu'` | `amount: Math.abs(amount)`, `type: 'Transaction'` | `'Transaction'` | **Số Dương (`> 0`)** |
| **Chuyển ví nội bộ (Transfer)**| `amount > 0`, `type = 'transfer'`, `walletTransfer = targetWalletId` | `amount: Math.abs(amount)`, `type: 'Transfer'`, `idwallet_transfer: targetWalletId`, `categoryId: null` | `'Transfer'` | **Số Dương (`> 0`)** |

> ⚠️ **TUYỆT ĐỐI KHÔNG GỬI GIÁ TRỊ NỘI BỘ:** Không được gửi `'chi'`, `'thu'`, `'expense'`, `'income'` lên server vì sẽ bị vi phạm ràng buộc CHECK `chk_transaction_type` ngay lập tức!

---

## 4. CÁC BẢNG LƯU TRỮ CỤC BỘ & THÔNG TIN CẤU HÌNH CẦN CÓ TẠI SQLITE

Ngoài 6 thực thể đồng bộ 2 chiều ở trên, sau các đợt cập nhật CSDL và Fix Issue gần đây, Client-app **bắt buộc phải có các cấu trúc lưu trữ cục bộ** sau để đảm bảo ứng dụng vận hành mượt mà khi ngoại tuyến:

---

### 4.1. Thông tin Người dùng & Trạng thái Tài khoản (`user_profile`)

Nhận từ phản hồi của API Đăng nhập (`POST /api/auth/login`) hoặc Lấy thông tin cá nhân (`GET /api/user/profile`):

| Trường dữ liệu | Kiểu dữ liệu | Ý nghĩa nghiệp vụ & Ràng buộc sau đợt Fix Issue |
|---|---|---|
| `idaccount` | `int` | Khóa chính tài khoản. |
| `username` | `string` | Tên đăng nhập. |
| `email` | `string` | Địa chỉ email (đã xác thực). |
| `fullname` | `string` | **Họ và tên đầy đủ của người dùng** (Bổ sung theo Issue Cấp tài khoản). |
| `phone` | `string` | **Số điện thoại** (Backend tự giải mã từ AES-256 trả về plain-text). |
| `address` | `string` | **Địa chỉ liên hệ** (Bổ sung theo Issue Cấp tài khoản). |
| `country_code` | `string` | **Mã quốc gia/vùng** (Ví dụ: `+84`, `VN`). |
| `type` | `string` | Gói cước tài khoản: `'Basic'` hoặc `'Premium'`. |
| `status` | `string` | Trạng thái tài khoản: `'Active'`, `'PendingDelete'` (đang trong 30 ngày chờ xóa), `'Inactive'`. |
| `countdown` | `int?` | Số ngày đếm ngược còn lại của tài khoản chờ xóa 30 ngày (nullable). |
| `is_first_login` | `bool` | Đánh dấu đăng nhập lần đầu tiên (nếu `true` yêu cầu đổi mật khẩu/PIN). |
| `premium_expires_at`| `DateTime?`| Thời điểm hết hạn gói cước Premium. |

---

### 4.2. Nhận diện Thiết bị & Theo dõi Lịch sử Truy cập (`device_tracking`)

Tuân thủ **Quy tắc Diff Check chuẩn PO (Migration 35)**:
- **Tên Thiết bị:** Client-app sử dụng package `device_info_plus` trích xuất tên thiết bị (Ví dụ: `"Samsung Galaxy S24 (Android 14)"` hoặc `"iPhone 15 Pro (iOS 17.5)"`).
- **Gắn Custom Header:** Gắn header `x-device-name` vào mọi request gửi lên Backend qua Interceptor của `DioClient`.
- **Cơ chế Diff Check trên Máy chủ:**
  + Khi người dùng truy cập app tiếp tục sử dụng nhưng **IP và Thiết bị KHÔNG thay đổi** $\rightarrow$ Server `UPDATE` `last_active_at = now()` (không sinh dòng rác trùng lặp trong CSDL).
  + Khi **IP hoặc Thiết bị có sự thay đổi** (ví dụ chuyển từ Wi-Fi sang 4G, hoặc đổi sang điện thoại khác) $\rightarrow$ Server `INSERT` dòng mới vào bảng `account_device_history` (Append-only, tuyệt đối không ghi đè, bảo toàn 100% lịch sử vết truy cập).
  + Địa chỉ IP được Server tự động che mờ (`113.161.xx.xx`) theo Nghị định 13/2023/NĐ-CP trước khi lưu trữ.

---

### 4.3. Bộ đệm Phân quyền 4 Trụ cột Đa tầng (`permissions_cache`)

Để kiểm soát giới hạn tài nguyên và tính năng khi người dùng đang Offline (không có kết nối mạng), Client-app cần cache lại bảng phân quyền từ sự kiện Socket.io `account.permissions_updated`:

| Cột dữ liệu | Kiểu dữ liệu | Ý nghĩa trong Ma trận 4 Trụ cột |
|---|---|---|
| `feature_code` | `string` (PK) | Mã định danh 36 tính năng chuẩn (vd: `WALLET_LIMIT`, `EXPORT_EXCEL`, `AI_OCR`). |
| `access` | `bool` | **Trụ 1 (Truy Cập):** `true` (cho phép dùng) / `false` (bị khóa). |
| `quota_limit` | `int?` | **Trụ 2 (Định Mức):** Trần số lượng (vd: tối đa 3 ví cho Basic; `null` = vô hạn ∞). |
| `scope_config` | `string?` (JSON) | **Trụ 3 (Phạm Vi):** Tham số cấu hình chi tiết (`format: ['PDF', 'Excel']`...). |
| `downgrade_policy`| `string` | **Trụ 4 (Chính Sách Hạ Cấp):** Xử lý khi hết hạn Premium: `BLOCK_CREATE`, `LOCK_FEATURE`, `READ_ONLY`, `GRACE_PERIOD_3D`, `FALLBACK_DEFAULT`. |

---

### 4.4. Hộp thư Thông báo Cá nhân & Sự kiện Hệ thống (`notifications`)

Bảng SQLite cục bộ `AppNotifications` và `AppNotificationEvents` để lưu trữ tin nhắn hộp thư cá nhân, kết quả quét hóa đơn OCR, và cảnh báo bảo trì nhận từ Socket.IO / FCM:
- `id`: UUID v4.
- `title`, `body`, `type`: Loại thông báo (`TRANSACTION`, `MAINTENANCE`, `UPGRADE`, `SYSTEM`).
- `isRead`: Đã đọc hay chưa.
- `createdAt`: Thời điểm phát.

---

## 5. CƠ CHẾ KÉO DỮ LIỆU DELTA PULL THEO GIỜ SERVER (`Server_update_at` UTC)

Nhằm triệt tiêu 100% rủi ro lệch đồng hồ phần cứng giữa điện thoại di động và máy chủ đám mây (Hardware Clock Drift):

1. **Khóa Kéo Giờ Server (Migration 20 + 21):**  
   Cả 6 bảng đồng bộ trên PostgreSQL đều có cột `Server_update_at TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC')` và Trigger tự động cập nhật mỗi khi có thao tác INSERT hoặc UPDATE.
2. **Quy Trình Kéo Dữ Liệu (`GET /api/sync/pull?since=...`):**
   - Phía Client-app lưu biến `lastPullTime` theo giá trị `pulledAt` nhận được trong phản hồi kỳ trước của Backend.
   - Khi gọi API Pull, gửi tham số `since = lastPullTime`.
   - **Kẹp Dải Thời Gian An Toàn (Safety Margin):** Phía Client-app kẹp dải thời gian:  
     $$\mathbf{maxSince} = \max(\text{since}, \text{pulledAt} - 2\text{ phút})$$  
     Điều này giúp bù đắp cho các giao dịch của người dùng khác đang nằm trong transaction chưa kịp commit tại thời điểm pull trước đó, đảm bảo **không bao giờ bỏ sót bất kỳ dữ liệu nào giữa các thiết bị**.

---

## 6. CHECKLIST SỐNG CÒN DÀNH CHO KỸ SƯ PHÁT TRIỂN PHÍA CLIENT-APP

Trước khi build bản phát hành hoặc chạy kiểm thử tích hợp, kiểm tra toàn bộ 10 điều sau:

- [ ] **1. Thứ tự mảng `operations` khi Push:** Bắt buộc: `categories` $\to$ `wallets` $\to$ `goals` $\to$ `bills` $\to$ `budgets` $\to$ `transactions`.
- [ ] **2. Tên khóa ngoại `idgoal` và `idbill` trong giao dịch:** Gửi đúng tên `idgoal` (cấm gửi `goal_id`) và `idbill` (cấm gửi `bill_id`).
- [ ] **3. Quy ước Dấu và Type của giao dịch:**
  - Khoản Chi: gửi `type = 'Transaction'` và `amount < 0` (số âm).
  - Khoản Thu: gửi `type = 'Transaction'` và `amount > 0` (số dương).
  - Chuyển ví: gửi `type = 'Transfer'`, giữ `idwallet_transfer`, gán `categoryId = null`.
- [ ] **4. Trạng thái ví (`status`):** Gửi nguyên văn `'Active'` hoặc `'Inactive'` (chữ hoa đầu) theo ràng buộc `chk_wallet_status`.
- [ ] **5. Nhánh Kéo Ví về (Pull):** Tuyệt đối KHÔNG đọc đè cột `balance` từ server xuống SQLite (`Value.absent()`).
- [ ] **6. Hóa đơn `pay_status`, `auto_pay` và `period_end`:**
  - `pay_status` nhận đúng 4 chuỗi: `'Pending'`, `'Payed'`, `'Skipped'`, `'Overdue'`.
  - `auto_pay` kiểu boolean thật (`true`/`false`).
  - `period_end` gửi lúc `00:00:00.000Z` UTC của ngày cục bộ.
- [ ] **7. Mục tiêu `priority` và 3 cột trích tự động:**
  - `priority`: số nguyên dương (100, 200, 300...) hoặc `null`; tuyệt đối không gửi `0`.
  - 3 cột trích tự động (`auto_deposit_amount`, `auto_deposit_wallet_id`, `auto_deposit_last_run`) phải đi cùng nhau trong payload.
- [ ] **8. Ngân sách `threshold_warning_percent`:** Gửi đúng kiểu số nguyên từ `0` đến `100`.
- [ ] **9. Header Tên Thiết Bị:** Mọi request đều gửi kèm header `x-device-name` lấy từ `device_info_plus`.
- [ ] **10. Khóa Cấm Rò Rỉ:** Không được rò rỉ các trường thuần client lên server: `syncStatus`, `isLocalOnly`, `keywords`, `goal_id`, `updatedAt` (phải đổi thành `update_at`).
