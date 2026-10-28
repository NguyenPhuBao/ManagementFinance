# 🏛️ ĐẶC TẢ CHI TIẾT DỮ LIỆU 4 TRỤ CỘT PHÂN QUYỀN HỆ THỐNG
# (4-PILLARS FEATURE PERMISSION SPECIFICATION)

> **Tài liệu nguồn sự thật (Single Source of Truth - SSOT)**  
> **Áp dụng cho toàn bộ dự án:** `src/Backend` (NodeJS Express), `src/Admin-web` (ReactJS SPA), `src/Client-app` (Flutter Mobile).  
> **Phiên bản:** 2.0 — Chuẩn hóa 36 tính năng bám sát 13 Phân hệ chức năng & 48 Màn hình Client-app.  
> **Cập nhật ngày:** 2026-10-17.

---

## 📑 MỤC LỤC
1. [Tổng Quan Kiến Trúc 4 Trụ Cột (4 Pillars Architecture)](#1-tổng-quan-kiến-trúc-4-trụ-cột)
2. [Quy Chuẩn 5 Chính Sách Hạ Cấp (Trụ 4: Downgrade Policies)](#2-quy-chuẩn-5-chính-sách-hạ-cấp)
3. [Đặc Tả Chi Tiết 36 Tính Năng Qua 13 Phân Hệ](#3-đặc-tả-chi-tiết-36-tính-năng-qua-13-phân-hệ)
   - [Phân hệ 01: Xác thực & Bảo mật (AUTH)](#phân-hệ-01-xác-thực--bảo-mật-auth)
   - [Phân hệ 02: Trang chủ & Điều hướng (HOME)](#phân-hệ-02-trang-chủ--điều-hướng-home)
   - [Phân hệ 03: Quản lý Ví tiền & Tài sản (WALLET)](#phân-hệ-03-quản-lý-ví-tiền--tài-sản-wallet)
   - [Phân hệ 04: Sổ Giao dịch Thu Chi (TX)](#phân-hệ-04-sổ-giao-dịch-thu-chi-tx)
   - [Phân hệ 05: Hệ thống Danh mục (CAT)](#phân-hệ-05-hệ-thống-danh-mục-cat)
   - [Phân hệ 06: Ngân sách Chi tiêu (BUDGET)](#phân-hệ-06-ngân-sách-chi-tiêu-budget)
   - [Phân hệ 07: Hóa đơn Định kỳ (BILL)](#phân-hệ-07-hóa-đơn-định-kỳ-bill)
   - [Phân hệ 08: Mục tiêu Tích lũy (GOAL)](#phân-hệ-08-mục-tiêu-tích-lũy-goal)
   - [Phân hệ 09: Báo cáo & Phân tích (ANALYTICS)](#phân-hệ-09-báo-cáo--phân-tích-analytics)
   - [Phân hệ 10: Trí tuệ Nhân tạo & Edge AI (AI)](#phân-hệ-10-trí-tuệ-nhân-tạo--edge-ai-ai)
   - [Phân hệ 11: Thông báo & Giám sát (NOTIF)](#phân-hệ-11-thông-báo--giám-sát-notif)
   - [Phân hệ 12: Gói cước & Thanh toán (PREMIUM)](#phân-hệ-12-gói-cước--thanh-toán-premium)
   - [Phân hệ 13: Đồng bộ Ngoại tuyến (SYNC)](#phân-hệ-13-đồng-bộ-ngoại-tuyến-sync)
4. [Bảng Ma Trận So Sánh Quyền Lợi Toàn Hệ Thống](#4-bảng-ma-trận-so-sánh-quyền-lợi-toàn-hệ-thống)
5. [Cơ Chế Thực Thi Đa Tầng (Enforcement Architecture)](#5-cơ-chế-thực-thi-đa-tầng)
   - [Kiến trúc 5 Tầng Phòng Thủ tại Client-app (Flutter)](#kiến-trúc-5-tầng-phòng-thủ-tại-client-app-flutter)
   - [Lá Chắn An Ninh Cấp Độ API tại Backend (NodeJS)](#lá-chắn-an-ninh-cấp-độ-api-tại-backend-nodejs)
   - [Giao Diện Điều Hành Quản Trị tại Admin-web (ReactJS)](#giao-diện-điều-hành-quản-trị-tại-admin-web-reactjs)

---

## 1. TỔNG QUAN KIẾN TRÚC 4 TRỤ CỘT

Hệ thống phân quyền được thiết kế độc lập, chặt chẽ và nhất quán qua 4 trụ cột nghiệp vụ:

| Trụ Cột | Tên Cột CSDL | Kiểu Dữ Liệu | Bảng Lưu Trữ | Định Nghĩa Nghiệp Vụ |
|:---|:---|:---:|:---:|:---|
| **Trụ 1: Access Control (Quyền truy cập)** | `is_enabled` | `BOOLEAN` | `account_type_permission` | Kiểm soát bật (`true`) hoặc khóa (`false`) tính năng đối với gói cước. Khi `false`, UI hiển thị huy hiệu khóa 🔒 hoặc điều hướng sang trang giới thiệu nâng cấp; Backend trả lỗi `403 FEATURE_DISABLED`. |
| **Trụ 2: Quota Limiting (Hạn mức số lượng)** | `limit_value` | `INTEGER` (hoặc `NULL`) | `account_type_permission` | Hạn mức số lượng tối đa của thực thể tài nguyên (`3`, `5`...). Giá trị `NULL` đại diện cho **Không giới hạn (Unlimited)** của gói Premium. |
| **Trụ 3: Scope Config (Phạm vi & Quyền năng con)** | `scope_schema`<br/>`scope_config` | `JSONB` | `feature` (schema)<br/>`account_type_permission` (config) | Cấu hình chi tiết các thuộc tính con, định dạng file, hạn mức tần suất bên trong tính năng. *(Hiện trạng: Server lưu trữ và trả về, chưa có hiệu lực ở Client-app)*. |
| **Trụ 4: Downgrade Policy (Chính sách khi hạ cấp)** | `default_downgrade_policy`<br/>`downgrade_policy` | `VARCHAR(50)` | `feature` (default)<br/>`account_type_permission` (áp dụng) | Quy tắc xử lý khi tài khoản Premium hết hạn trở về gói Basic. *(Hiện trạng: Server lưu trữ; Client-app khi hết hạn gói sẽ dừng ngay quyền lợi Premium)*. |

---

## 2. QUY CHUẨN CÁC CHÍNH SÁCH HẠ CẤP (TRỤ 4)

> ⚠️ **Lưu ý hiện trạng:** Trụ 3 (`scope_config`) và Trụ 4 (`downgrade_policy`) hiện tại do Server lưu trữ và trả về; Client-app hiện tại chỉ đọc `accountType`, `premiumExpiresAt`, 22 cờ `features` và 5 trần `limits`. Khi hết hạn gói Premium, Client-app dừng ngay các quyền lợi Premium.

Hệ thống định nghĩa các chính sách chuẩn hóa để xử lý tự động khi tài khoản hết hạn:

1. **`BLOCK_CREATE` (Bảo toàn dữ liệu — Chặn tạo mới vượt trần):**
   - **Mục đích:** Bảo vệ quyền sở hữu dữ liệu của người dùng, tôn trọng nguyên tắc bảo toàn tài sản.
   - **Hành vi:** Nếu người dùng đang sở hữu số lượng thực thể vượt trần Basic (ví dụ: đang có 5 ví > trần Basic 3 ví):
     - Toàn bộ 5 ví cũ **vẫn hiển thị 100% đầy đủ** trên giao diện Mobile.
     - Người dùng **vẫn ghi chép thu/chi, chuyển tiền và xem lịch sử** trên cả 5 ví bình thường.
     - Hệ thống **chỉ chặn bấm nút "+ Tạo ví mới"**; khi bấm vào sẽ hiển thị dialog giải thích và mời gia hạn.
2. **`LOCK_FEATURE` (Khóa quyền truy cập tính năng):**
   - **Mục đích:** Khóa các tính năng đặc quyền cao cấp (Copilot AI, Ghi chép giọng nói On-Device, Báo cáo nâng cao).
   - **Hành vi:** Tính năng bị vô hiệu hóa, hiển thị icon ổ khóa 🔒; khi click sẽ mở trang nâng cấp `/premium?quyen=...`.
3. **`READ_ONLY` (Chỉ xem dữ liệu lịch sử):**
   - **Mục đích:** Áp dụng cho các tính năng phân tích xu hướng hoặc dự báo (Dự báo dòng tiền 30 ngày).
   - **Hành vi:** Cho phép xem lại các biểu đồ/dữ liệu đã sinh ra trong thời gian còn Premium, nhưng khóa nút "Chạy phân tích lại kỳ này".
4. **Ân hạn 3 ngày (Server lưu/trả, chưa có hiệu lực ở app):**
   - **Mục đích:** Áp dụng cho các tiến trình tự động hóa nền (Tự động thanh toán hóa đơn `bill_auto_pay`, tự động trích quỹ mục tiêu `goal_auto_deposit`).
   - **Hành vi:** Quy định ân hạn trên server; ở Client-app khi hết hạn Premium thì dừng ngay các quyền lợi tự động.
5. **`FALLBACK_DEFAULT` (Tự động rơi về cấu hình mặc định Basic):**
   - **Mục đích:** Áp dụng cho các thông số vận hành (Tần số đồng bộ, số lượt quét OCR, số ảnh đính kèm).
   - **Hành vi:** Tự động điều chỉnh các giá trị trong `scope_config` về ngưỡng an toàn của gói Basic (ví dụ: chu kỳ đồng bộ từ 2s chuyển về 10s; số ảnh đính kèm từ 5 giảm về 1).

---

## 3. ĐẶC TẢ CHI TIẾT 36 TÍNH NĂNG QUA 13 PHÂN HỆ

---

### PHÂN HỆ 01: XÁC THỰC & BẢO MẬT (AUTH)
*Mục tiêu: Đảm bảo an toàn tài khoản và tuân thủ quyền riêng tư theo Nghị định 13/2023/NĐ-CP.*

#### 1. `biometric_auth` — Xác thực sinh trắc học
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Xác thực & Bảo mật`
- **Mô tả:** Đăng nhập an toàn bằng vân tay hoặc nhận diện khuôn mặt Face ID trên thiết bị di động.
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"methods": {"type": "array", "items": "string"}, "auto_prompt": {"type": "boolean"}}`
  - `scope_config` (Basic): `{"methods": ["fingerprint", "face_id"], "auto_prompt": true}`
  - `scope_config` (Premium): `{"methods": ["fingerprint", "face_id"], "auto_prompt": true}`
- **Trụ 4 (Downgrade Policy):** `LOCK_FEATURE`

#### 2. `offline_login` — Đăng nhập ngoại tuyến
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Xác thực & Bảo mật`
- **Mô tả:** Cho phép mở app và truy cập dữ liệu cục bộ an toàn khi không có kết nối internet.
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"cache_token_days": {"type": "integer"}, "allow_pin_fallback": {"type": "boolean"}}`
  - `scope_config` (Basic): `{"cache_token_days": 30, "allow_pin_fallback": true}`
  - `scope_config` (Premium): `{"cache_token_days": 30, "allow_pin_fallback": true}`
- **Trụ 4 (Downgrade Policy):** `FALLBACK_DEFAULT`

#### 3. `account_deletion` — Quyền xóa tài khoản & Ân hạn
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Xác thực & Bảo mật`
- **Mô tả:** Yêu cầu xóa tài khoản với thời gian ân hạn 30 ngày bảo vệ người dùng và tuân thủ GDPR/NĐ 13.
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"grace_period_days": {"type": "integer"}, "allow_undo": {"type": "boolean"}}`
  - `scope_config` (Basic): `{"grace_period_days": 30, "allow_undo": true}`
  - `scope_config` (Premium): `{"grace_period_days": 30, "allow_undo": true}`
- **Trụ 4 (Downgrade Policy):** `BLOCK_CREATE`

---

### PHÂN HỆ 02: TRANG CHỦ & ĐIỀU HƯỚNG (HOME)
*Mục tiêu: Bảng điều khiển tài chính tổng quan và phím tắt thao tác nhanh.*

#### 4. `net_worth_overview` — Tổng quan tài sản ròng
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Trang chủ & Điều hướng`
- **Mô tả:** Theo dõi biến động tổng tài sản ròng và cơ cấu tiền mặt, ngân hàng, ví điện tử.
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"chart_history_days": {"type": "integer", "nullable": true}, "allow_trend_breakdown": {"type": "boolean"}}`
  - `scope_config` (Basic): `{"chart_history_days": 30, "allow_trend_breakdown": false}`
  - `scope_config` (Premium): `{"chart_history_days": null, "allow_trend_breakdown": true}`
- **Trụ 4 (Downgrade Policy):** `FALLBACK_DEFAULT` (Giới hạn biểu đồ về 30 ngày gần nhất).

#### 5. `quick_action_shortcuts` — Phím tắt ghi chép nhanh
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Trang chủ & Điều hướng`
- **Mô tả:** Bộ phím tắt tạo nhanh thu chi, chuyển tiền giữa các ví, quét hóa đơn và khẩu lệnh.
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"custom_slots": {"type": "integer"}, "allow_voice_shortcut": {"type": "boolean"}}`
  - `scope_config` (Basic): `{"custom_slots": 4, "allow_voice_shortcut": false}`
  - `scope_config` (Premium): `{"custom_slots": 8, "allow_voice_shortcut": true}`
- **Trụ 4 (Downgrade Policy):** `FALLBACK_DEFAULT` (Thu hẹp về 4 phím tắt cơ bản).

---

### PHÂN HỆ 03: QUẢN LÝ VÍ TIỀN & TÀI SẢN (WALLET)
*Mục tiêu: Quản lý ví tiền mặt, tài khoản ngân hàng, thẻ tín dụng và nguồn tiền.*

#### 6. `wallets` — Quản lý ví tiền
- **Loại tính năng:** `LIMIT` | **Nhóm:** `Quản lý Ví & Tài sản`
- **Mô tả:** Tạo và quản lý các ví tiền mặt, ngân hàng, thẻ tín dụng, ví điện tử.
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `3` (Tối đa 3 ví) | Premium: `NULL` (Không giới hạn)
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"allowed_types": {"type": "array", "items": "string"}, "custom_color": {"type": "boolean"}}`
  - `scope_config` (Basic): `{"allowed_types": ["Cash", "Bank", "EWallet"], "custom_color": false}`
  - `scope_config` (Premium): `{"allowed_types": ["Cash", "Bank", "EWallet", "Credit", "Investment"], "custom_color": true}`
- **Trụ 4 (Downgrade Policy):** `BLOCK_CREATE` (Bảo toàn 100% dữ liệu các ví cũ, chỉ chặn tạo thêm ví thứ 4).

#### 7. `wallet_balance_adjustment` — Điều chỉnh số dư ví
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Quản lý Ví & Tài sản`
- **Mô tả:** Kiểm kê thực tế và tự động tạo giao dịch bù trừ để cân đối số dư ví chính xác.
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"auto_generate_diff_tx": {"type": "boolean"}}`
  - `scope_config` (Basic): `{"auto_generate_diff_tx": true}`
  - `scope_config` (Premium): `{"auto_generate_diff_tx": true}`
- **Trụ 4 (Downgrade Policy):** `BLOCK_CREATE`

#### 8. `wallet_exclude_total` — Loại trừ ví khỏi tổng tài sản
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Quản lý Ví & Tài sản`
- **Mô tả:** Cho phép đánh dấu không cộng số dư của ví phụ vào tổng tài sản ròng.
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"max_excluded_wallets": {"type": "integer", "nullable": true}}`
  - `scope_config` (Basic): `{"max_excluded_wallets": null}`
  - `scope_config` (Premium): `{"max_excluded_wallets": null}`
- **Trụ 4 (Downgrade Policy):** `FALLBACK_DEFAULT`

---

### PHÂN HỆ 04: SỔ GIAO DỊCH THU CHI (TX)
*Mục tiêu: Ghi chép nhật ký thu chi hàng ngày, hỗ trợ đa phương thức nhập liệu tự động.*

#### 9. `transaction_management` — Sổ giao dịch thu chi
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Sổ giao dịch Thu Chi`
- **Mô tả:** Quản lý toàn diện sổ thu chi, phân loại chi tiết, đính kèm ảnh và tìm kiếm đa chiều.
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"max_photos_per_tx": {"type": "integer"}, "search_history_days": {"type": "integer", "nullable": true}}`
  - `scope_config` (Basic): `{"max_photos_per_tx": 1, "search_history_days": 90}`
  - `scope_config` (Premium): `{"max_photos_per_tx": 5, "search_history_days": null}`
- **Trụ 4 (Downgrade Policy):** `FALLBACK_DEFAULT`

#### 10. `ai_quick_input` — Ghi chép bằng giọng nói (Voice Input)
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Sổ giao dịch Thu Chi`
- **Mô tả:** Bóc tách câu nói tiếng Việt thành giao dịch tự động (App thi hành qua `speech_to_text` Android, dự phòng Gemma; Server lưu cấu hình).
- **Trụ 1 (Access Control):** Basic: 🔒 `false` (Khóa) | Premium: ✅ `true` (Mở)
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"daily_voice_quota": {"type": "integer", "nullable": true}, "max_seconds": {"type": "integer"}}`
  - `scope_config` (Basic): `{"daily_voice_quota": 0, "max_seconds": 0}`
  - `scope_config` (Premium): `{"daily_voice_quota": null, "max_seconds": 30}`
- **Trụ 4 (Downgrade Policy):** `LOCK_FEATURE` (Khóa nút micro trên bàn phím ghi chép).

#### 11. `ocr_receipt` — Quét hóa đơn / Biên lai (OCR)
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Sổ giao dịch Thu Chi`
- **Mô tả:** Tự động bóc tách ảnh chụp hóa đơn, biên lai thành giao dịch qua camera bằng MLKit.
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"monthly_scans": {"type": "integer", "nullable": true}, "max_file_mb": {"type": "integer"}, "auto_crop": {"type": "boolean"}}`
  - `scope_config` (Basic): `{"monthly_scans": 15, "max_file_mb": 5, "auto_crop": false}`
  - `scope_config` (Premium): `{"monthly_scans": null, "max_file_mb": 20, "auto_crop": true}`
- **Trụ 4 (Downgrade Policy):** `FALLBACK_DEFAULT` (Giới hạn tối đa 15 lượt quét/tháng).

#### 12. `quick_category_assignment` — Gán danh mục nhanh (C1)
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Sổ giao dịch Thu Chi`
- **Mô tả:** Hỗ trợ phân loại nhanh hàng loạt giao dịch chưa có danh mục hoặc biến động số dư.
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"batch_assign_max": {"type": "integer"}}`
  - `scope_config` (Basic): `{"batch_assign_max": 20}`
  - `scope_config` (Premium): `{"batch_assign_max": 100}`
- **Trụ 4 (Downgrade Policy):** `FALLBACK_DEFAULT`

#### 13. `in_app_calculator` — Bàn phím máy tính tích hợp
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Sổ giao dịch Thu Chi`
- **Mô tả:** Máy tính mini tích hợp tính toán số tiền trực tiếp trên bàn phím khi ghi chép.
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"allow_history_tape": {"type": "boolean"}}`
  - `scope_config` (Basic): `{"allow_history_tape": true}`
  - `scope_config` (Premium): `{"allow_history_tape": true}`
- **Trụ 4 (Downgrade Policy):** `LOCK_FEATURE`

---

### PHÂN HỆ 05: HỆ THỐNG DANH MỤC (CAT)
*Mục tiêu: Quản lý danh mục thu chi đa cấp và bộ từ khóa tự động gán nhãn.*

#### 14. `custom_categories` — Quản lý danh mục tùy chỉnh
- **Loại tính năng:** `LIMIT` | **Nhóm:** `Hệ thống Danh mục`
- **Mô tả:** Tạo danh mục thu chi riêng đa cấp (nhóm danh mục cha và các danh mục con).
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `5` (Tối đa 5 danh mục) | Premium: `NULL` (Không giới hạn)
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"max_depth": {"type": "integer"}, "custom_icons": {"type": "boolean"}, "custom_colors": {"type": "boolean"}}`
  - `scope_config` (Basic): `{"max_depth": 2, "custom_icons": false, "custom_colors": false}`
  - `scope_config` (Premium): `{"max_depth": 3, "custom_icons": true, "custom_colors": true}`
- **Trụ 4 (Downgrade Policy):** `BLOCK_CREATE` (Bảo toàn các danh mục riêng đã tạo, chặn tạo thêm nếu > 5).

#### 15. `category_keywords_matching` — Từ khóa nhận diện danh mục
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Hệ thống Danh mục`
- **Mô tả:** Thiết lập danh sách từ khóa nhận diện tự động cho OCR, giọng nói và thông báo ngân hàng.
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"max_keywords_per_cat": {"type": "integer"}}`
  - `scope_config` (Basic): `{"max_keywords_per_cat": 5}`
  - `scope_config` (Premium): `{"max_keywords_per_cat": 25}`
- **Trụ 4 (Downgrade Policy):** `FALLBACK_DEFAULT`

---

### PHÂN HỆ 06: NGÂN SÁCH CHI TIÊU (BUDGET)
*Mục tiêu: Thiết lập kỷ luật chi tiêu theo hạn mức định kỳ.*

#### 16. `budgets` — Quản lý ngân sách chi tiêu
- **Loại tính năng:** `LIMIT` | **Nhóm:** `Ngân sách Chi tiêu`
- **Mô tả:** Thiết lập hạn mức chi tiêu định kỳ hàng tháng theo từng danh mục.
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `3` (Tối đa 3 ngân sách) | Premium: `NULL` (Không giới hạn)
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"recurrence_cycles": {"type": "array", "items": "string"}}`
  - `scope_config` (Basic): `{"recurrence_cycles": ["MONTHLY"]}`
  - `scope_config` (Premium): `{"recurrence_cycles": ["WEEKLY", "MONTHLY", "CUSTOM"]}`
- **Trụ 4 (Downgrade Policy):** `BLOCK_CREATE` (Bảo toàn các ngân sách đang hoạt động, chặn tạo ngân sách thứ 4).

#### 17. `smart_budget_rebalancing` — Tái phân bổ ngân sách AI
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Ngân sách Chi tiêu`
- **Mô tả:** Gợi ý tự động điều chuyển hạn mức giữa các ngân sách khi sắp vượt ngưỡng chi.
- **Trụ 1 (Access Control):** Basic: 🔒 `false` (Khóa) | Premium: ✅ `true` (Mở)
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"auto_suggest_shift": {"type": "boolean"}, "apply_one_click": {"type": "boolean"}}`
  - `scope_config` (Basic): `{"auto_suggest_shift": false, "apply_one_click": false}`
  - `scope_config` (Premium): `{"auto_suggest_shift": true, "apply_one_click": true}`
- **Trụ 4 (Downgrade Policy):** `LOCK_FEATURE`

#### 18. `budget_overspend_alert` — Dự báo vỡ hạn mức chi tiêu
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Ngân sách Chi tiêu`
- **Mô tả:** Cảnh báo chi tiêu chạm ngưỡng và tính toán định mức chi an toàn mỗi ngày còn lại.
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"alert_threshold": {"type": "number"}, "daily_burn_rate": {"type": "boolean"}}`
  - `scope_config` (Basic): `{"alert_threshold": 0.8, "daily_burn_rate": false}`
  - `scope_config` (Premium): `{"alert_threshold": 0.8, "daily_burn_rate": true}`
- **Trụ 4 (Downgrade Policy):** `FALLBACK_DEFAULT`

---

### PHÂN HỆ 07: HÓA ĐƠN ĐỊNH KỲ (BILL)
*Mục tiêu: Theo dõi và xử lý các khoản chi phí lặp lại theo chu kỳ.*

#### 19. `bills` — Quản lý hóa đơn định kỳ
- **Loại tính năng:** `LIMIT` | **Nhóm:** `Hóa đơn định kỳ`
- **Mô tả:** Theo dõi hóa đơn lặp lại (Điện, Nước, Internet, Thuê nhà...) và chu kỳ.
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `3` (Tối đa 3 hóa đơn) | Premium: `NULL` (Không giới hạn)
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"cycles": {"type": "array", "items": "string"}}`
  - `scope_config` (Basic): `{"cycles": ["MONTHLY"]}`
  - `scope_config` (Premium): `{"cycles": ["WEEKLY", "MONTHLY", "QUARTERLY", "YEARLY"]}`
- **Trụ 4 (Downgrade Policy):** `BLOCK_CREATE`

#### 20. `bill_auto_pay` — Tự động thanh toán hóa đơn
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Hóa đơn định kỳ`
- **Mô tả:** Tự động tạo giao dịch thanh toán trừ tiền ví khi hóa đơn đến hạn.
- **Trụ 1 (Access Control):** Basic: 🔒 `false` (Khóa) | Premium: ✅ `true` (Mở)
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"auto_deduct_wallet": {"type": "boolean"}, "retry_on_fail": {"type": "integer"}}`
  - `scope_config` (Basic): `{"auto_deduct_wallet": false, "retry_on_fail": 0}`
  - `scope_config` (Premium): `{"auto_deduct_wallet": true, "retry_on_fail": 3}`
- **Trụ 4 (Downgrade Policy):** Ân hạn 3 ngày (Server lưu/trả; ở app khi hết hạn Premium thì dừng ngay tính năng, chưa có hiệu lực ân hạn ở app).

#### 21. `bill_reminder_notifications` — Nhắc hẹn hóa đơn đa tầng
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Hóa đơn định kỳ`
- **Mô tả:** Nhắc nhở thanh toán hóa đơn trước ngày đến hạn qua Push Notification.
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"remind_days_before": {"type": "array", "items": "integer"}, "custom_hour": {"type": "boolean"}}`
  - `scope_config` (Basic): `{"remind_days_before": [1], "custom_hour": false}`
  - `scope_config` (Premium): `{"remind_days_before": [1, 3, 7], "custom_hour": true}`
- **Trụ 4 (Downgrade Policy):** `FALLBACK_DEFAULT`

---

### PHÂN HỆ 08: MỤC TIÊU TÍCH LŨY (GOAL)
*Mục tiêu: Lập kế hoạch tích lũy tài chính cho các mục đích tương lai.*

#### 22. `goals` — Mục tiêu tích lũy tiết kiệm
- **Loại tính năng:** `LIMIT` | **Nhóm:** `Mục tiêu Tích lũy`
- **Mô tả:** Lập kế hoạch tích lũy tài chính (mua xe, du lịch, mua nhà, quỹ khẩn cấp...).
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `3` (Tối đa 3 mục tiêu) | Premium: `NULL` (Không giới hạn)
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"allow_sub_milestones": {"type": "boolean"}, "priority_sorting": {"type": "boolean"}}`
  - `scope_config` (Basic): `{"allow_sub_milestones": false, "priority_sorting": false}`
  - `scope_config` (Premium): `{"allow_sub_milestones": true, "priority_sorting": true}`
- **Trụ 4 (Downgrade Policy):** `BLOCK_CREATE`

#### 23. `goal_auto_deposit` — Tự động trích tiền mục tiêu
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Mục tiêu Tích lũy`
- **Mô tả:** Tự động trích tiền định kỳ từ ví vào hũ mục tiêu tiết kiệm.
- **Trụ 1 (Access Control):** Basic: 🔒 `false` (Khóa) | Premium: ✅ `true` (Mở)
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"frequency": {"type": "array", "items": "string"}, "auto_pause_on_low_balance": {"type": "boolean"}}`
  - `scope_config` (Basic): `{"frequency": [], "auto_pause_on_low_balance": false}`
  - `scope_config` (Premium): `{"frequency": ["DAILY", "WEEKLY", "MONTHLY"], "auto_pause_on_low_balance": true}`
- **Trụ 4 (Downgrade Policy):** Ân hạn 3 ngày (Server lưu/trả; chưa có hiệu lực ở app).

#### 24. `goal_deposit_withdraw` — Nạp & Rút tiền mục tiêu
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Mục tiêu Tích lũy`
- **Mô tả:** Thao tác nạp thêm tiền vào mục tiêu hoặc rút tiền mục tiêu về ví linh hoạt.
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"require_linked_wallet": {"type": "boolean"}}`
  - `scope_config` (Basic): `{"require_linked_wallet": true}`
  - `scope_config` (Premium): `{"require_linked_wallet": true}`
- **Trụ 4 (Downgrade Policy):** `BLOCK_CREATE`

---

### PHÂN HỆ 09: BÁO CÁO & PHÂN TÍCH (ANALYTICS)
*Mục tiêu: Đánh giá sức khỏe tài chính, phân tích xu hướng và xuất dữ liệu chuyên nghiệp.*

#### 25. `export_reports` — Xuất báo cáo PDF / Excel
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Báo cáo & Phân tích`
- **Mô tả:** Xuất dữ liệu sao kê thu chi chuyên nghiệp ra file PDF in ấn hoặc bảng tính Excel.
- **Trụ 1 (Access Control):** Basic: 🔒 `false` (Độc quyền Premium) | Premium: ✅ `true` (Mở)
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"formats": {"type": "array", "items": "string"}, "max_range_years": {"type": "integer", "nullable": true}, "watermark": {"type": "boolean"}}`
  - `scope_config` (Basic): `{"formats": [], "max_range_years": 0, "watermark": true}`
  - `scope_config` (Premium): `{"formats": ["PDF", "EXCEL", "CSV"], "max_range_years": null, "watermark": false}`
- **Trụ 4 (Downgrade Policy):** `LOCK_FEATURE` (Khóa nút bấm xuất báo cáo).

#### 26. `financial_health_fhs` — Chỉ số sức khỏe tài chính
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Báo cáo & Phân tích`
- **Mô tả:** Đánh giá thang điểm sức khỏe tài chính và phân tích cơ cấu chi tiêu 50/30/20.
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"score_only": {"type": "boolean"}, "ai_deep_insights": {"type": "boolean"}}`
  - `scope_config` (Basic): `{"score_only": true, "ai_deep_insights": false}`
  - `scope_config` (Premium): `{"score_only": false, "ai_deep_insights": true}`
- **Trụ 4 (Downgrade Policy):** `FALLBACK_DEFAULT`

#### 27. `cashflow_forecast` — Dự báo dòng tiền 30 ngày
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Báo cáo & Phân tích`
- **Mô tả:** Dự báo xu hướng số dư và dòng tiền tự do trong 30 ngày tiếp theo.
- **Trụ 1 (Access Control):** Basic: 🔒 `false` (Khóa) | Premium: ✅ `true` (Mở)
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"forecast_days": {"type": "integer"}, "scenario_model": {"type": "boolean"}}`
  - `scope_config` (Basic): `{"forecast_days": 0, "scenario_model": false}`
  - `scope_config` (Premium): `{"forecast_days": 30, "scenario_model": true}`
- **Trụ 4 (Downgrade Policy):** `READ_ONLY` (Vẫn xem lại được kết quả dự báo của 30 ngày cũ, không chạy phân tích mới).

#### 28. `anomaly_spending_insights` — Cảnh báo chi tiêu bất thường
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Báo cáo & Phân tích`
- **Mô tả:** Phát hiện và cảnh báo các khoản chi tiêu đột biến bất thường so với lịch sử.
- **Trụ 1 (Access Control):** Basic: 🔒 `false` (Khóa) | Premium: ✅ `true` (Mở)
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"deviation_percent_threshold": {"type": "number"}, "auto_notify": {"type": "boolean"}}`
  - `scope_config` (Basic): `{"deviation_percent_threshold": 50, "auto_notify": false}`
  - `scope_config` (Premium): `{"deviation_percent_threshold": 30, "auto_notify": true}`
- **Trụ 4 (Downgrade Policy):** `LOCK_FEATURE`

---

### PHÂN HỆ 10: TRÍ TUỆ NHÂN TẠO & EDGE AI (AI)
*Mục tiêu: Trợ lý tài chính thông minh Copilot AI Gemini và mô hình Offline On-Device.*

#### 29. `ai_assistant` — Trợ lý tài chính Copilot AI Gemini
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Trí tuệ nhân tạo & Edge AI`
- **Mô tả:** Hỏi đáp, tư vấn tài chính, tự động tạo giao dịch/ngân sách qua ngôn ngữ tự nhiên.
- **Trụ 1 (Access Control):** Basic: 🔒 `false` (Khóa) | Premium: ✅ `true` (Mở)
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"daily_prompts": {"type": "integer", "nullable": true}, "context_window_days": {"type": "integer"}, "model": {"type": "string"}}`
  - `scope_config` (Basic): `{"daily_prompts": 0, "context_window_days": 0, "model": "none"}`
  - `scope_config` (Premium): `{"daily_prompts": null, "context_window_days": 90, "model": "gemini-3.8-flash"}`
- **Trụ 4 (Downgrade Policy):** `LOCK_FEATURE` (Khóa tab Chatbot AI Copilot).

#### 30. `ai_edge_model` — Mô hình AI Offline trên máy
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Trí tuệ nhân tạo & Edge AI`
- **Mô tả:** Tải và chạy mô hình ngôn ngữ trực tiếp trên chip điện thoại không cần internet.
- **Trụ 1 (Access Control):** Basic: 🔒 `false` (Khóa) | Premium: ✅ `true` (Mở)
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"allow_offline_inference": {"type": "boolean"}, "models": {"type": "array", "items": "string"}}`
  - `scope_config` (Basic): `{"allow_offline_inference": false, "models": []}`
  - `scope_config` (Premium - Server lưu; App thực tế dùng Gemma 4 E2B `.litertlm`): `{"allow_offline_inference": true, "models": ["gemma-4-e2b", "finance-slm"]}`
- **Trụ 4 (Downgrade Policy):** `LOCK_FEATURE`

#### 31. `ai_model_management` — Quản lý bộ nhớ mô hình AI
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Trí tuệ nhân tạo & Edge AI`
- **Mô tả:** Quản lý tải về, xóa giải phóng bộ nhớ mô hình AI On-Device trên thiết bị.
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"allow_purge_cache": {"type": "boolean"}, "max_storage_mb": {"type": "integer"}}`
  - `scope_config` (Basic): `{"allow_purge_cache": true, "max_storage_mb": 500}`
  - `scope_config` (Premium): `{"allow_purge_cache": true, "max_storage_mb": 2000}`
- **Trụ 4 (Downgrade Policy):** `FALLBACK_DEFAULT`

---

### PHÂN HỆ 11: THÔNG BÁO & GIÁM SÁT (NOTIF)
*Mục tiêu: Đọc biến động số dư ngân hàng và duy trì thói quen ghi chép tài chính.*

#### 32. `bank_notification_parser` — Đọc biến động số dư ngân hàng
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Thông báo & Giám sát`
- **Mô tả:** Tự động nhận diện thông báo biến động số dư từ app ngân hàng trên máy để nhắc ghi chép.
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"supported_banks": {"type": "array", "items": "string"}, "auto_fill_category": {"type": "boolean"}}`
  - `scope_config` (Basic - Server lưu; App thực tế hỗ trợ MB Bank, MoMo, ZaloPay không theo gói): `{"supported_banks": ["MB", "MOMO", "ZALOPAY"], "auto_fill_category": false}`
  - `scope_config` (Premium): `{"supported_banks": ["ALL"], "auto_fill_category": true}`
- **Trụ 4 (Downgrade Policy):** `FALLBACK_DEFAULT`

#### 33. `daily_recording_reminder` — Nhắc nhở ghi chép hàng ngày
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Thông báo & Giám sát`
- **Mô tả:** Tự động phát thông báo nhắc nhở ghi chép thu chi vào các khung giờ cấu hình.
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"reminder_slots": {"type": "array", "items": "string"}, "custom_message": {"type": "boolean"}}`
  - `scope_config` (Basic): `{"reminder_slots": ["20:00"], "custom_message": false}`
  - `scope_config` (Premium): `{"reminder_slots": ["12:00", "18:00", "21:00"], "custom_message": true}`
- **Trụ 4 (Downgrade Policy):** `FALLBACK_DEFAULT`

---

### PHÂN HỆ 12: GÓI CƯỚC & THANH TOÁN (PREMIUM)
*Mục tiêu: Mua và gia hạn gói cước tự động qua Napas 247 VietQR và đối soát PayOS.*

#### 34. `vietqr_payment` — Thanh toán tự động VietQR
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Gói cước & Thanh toán`
- **Mô tả:** Tạo mã VietQR Napas 247 động, đếm ngược và đối soát tự động qua PayOS Gateway.
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"gateway": {"type": "string"}, "countdown_minutes": {"type": "integer"}, "support_jit_sync": {"type": "boolean"}}`
  - `scope_config` (Basic): `{"gateway": "PayOS", "countdown_minutes": 15, "support_jit_sync": true}`
  - `scope_config` (Premium): `{"gateway": "PayOS", "countdown_minutes": 15, "support_jit_sync": true}`
- **Trụ 4 (Downgrade Policy):** `BLOCK_CREATE`

#### 35. `payment_history` — Lịch sử thanh toán gói cước
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Gói cước & Thanh toán`
- **Mô tả:** Tra cứu lịch sử giao dịch mua gói cước, biên lai thanh toán (lọc sạch đơn mẫu).
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"exclude_template_orders": {"type": "boolean"}, "allow_download_invoice": {"type": "boolean"}}`
  - `scope_config` (Basic): `{"exclude_template_orders": true, "allow_download_invoice": false}`
  - `scope_config` (Premium): `{"exclude_template_orders": true, "allow_download_invoice": true}`
- **Trụ 4 (Downgrade Policy):** `BLOCK_CREATE`

---

### PHÂN HỆ 13: ĐỒNG BỘ NGOẠI TUYẾN (SYNC)
*Mục tiêu: Đảm bảo dữ liệu an toàn, ghi chép không phụ thuộc mạng và đồng bộ 2 chiều.*

#### 36. `offline_first_sync` — Đồng bộ 2 chiều Offline-First
- **Loại tính năng:** `TOGGLE` | **Nhóm:** `Đồng bộ Ngoại tuyến`
- **Mô tả:** Ghi chép ngoại tuyến trên SQLite 0ms độ trễ và tự động đồng bộ 2 chiều khi có mạng.
- **Trụ 1 (Access Control):** Basic: ✅ `true` | Premium: ✅ `true`
- **Trụ 2 (Quota Limit):** Basic: `NULL` | Premium: `NULL`
- **Trụ 3 (Scope Schema & Config):**
  - `scope_schema`: `{"debounce_seconds": {"type": "integer"}, "cloud_photo_backup": {"type": "boolean"}, "realtime_priority": {"type": "boolean"}}`
  - `scope_config` (Basic): `{"debounce_seconds": 10, "cloud_photo_backup": false, "realtime_priority": false}`
  - `scope_config` (Premium): `{"debounce_seconds": 2, "cloud_photo_backup": true, "realtime_priority": true}`
- **Trụ 4 (Downgrade Policy):** `FALLBACK_DEFAULT` (Chuyển chu kỳ đồng bộ về 10s, ngắt tải ảnh hóa đơn mới lên đám mây).

---

## 4. BẢNG MA TRẬN SO SÁNH QUYỀN LỢI TOÀN HỆ THỐNG

| STT | Mã Tính Năng | Tên Tính Năng | Loại | Gói Basic | Gói Premium | Trụ 4: Downgrade Policy |
|:---:|:---|:---|:---:|:---:|:---:|:---:|
| 1 | `biometric_auth` | Xác thực sinh trắc học | `TOGGLE` | ✅ Mở | ✅ Mở | `LOCK_FEATURE` |
| 2 | `offline_login` | Đăng nhập ngoại tuyến | `TOGGLE` | ✅ Mở | ✅ Mở | `FALLBACK_DEFAULT` |
| 3 | `account_deletion` | Quyền xóa tài khoản & Ân hạn | `TOGGLE` | ✅ Mở | ✅ Mở | `BLOCK_CREATE` |
| 4 | `net_worth_overview` | Tổng quan tài sản ròng | `TOGGLE` | ✅ Mở (30 ngày) | ✅ Mở (Toàn thời gian) | `FALLBACK_DEFAULT` |
| 5 | `quick_action_shortcuts` | Phím tắt ghi chép nhanh | `TOGGLE` | ✅ Mở (4 slots) | ✅ Mở (8 slots + Voice) | `FALLBACK_DEFAULT` |
| 6 | `wallets` | Quản lý ví tiền | `LIMIT` | **Trần: 3 ví** | **Không giới hạn** | `BLOCK_CREATE` |
| 7 | `wallet_balance_adjustment` | Điều chỉnh số dư ví | `TOGGLE` | ✅ Mở | ✅ Mở | `BLOCK_CREATE` |
| 8 | `wallet_exclude_total` | Loại trừ ví khỏi tổng tài sản | `TOGGLE` | ✅ Mở | ✅ Mở | `FALLBACK_DEFAULT` |
| 9 | `transaction_management` | Sổ giao dịch thu chi | `TOGGLE` | ✅ Mở (1 ảnh/tx) | ✅ Mở (5 ảnh/tx) | `FALLBACK_DEFAULT` |
| 10 | `ai_quick_input` | Ghi chép giọng nói (Voice Input) | `TOGGLE` | 🔒 **Khóa** | 🔓 **Mở toàn diện** | `LOCK_FEATURE` |
| 11 | `ocr_receipt` | Quét hóa đơn / Biên lai (OCR) | `TOGGLE` | ✅ Mở (15 lượt/tháng) | 🔓 **Không giới hạn** | `FALLBACK_DEFAULT` |
| 12 | `quick_category_assignment` | Gán danh mục nhanh (C1) | `TOGGLE` | ✅ Mở (20 tx/lần) | ✅ Mở (100 tx/lần) | `FALLBACK_DEFAULT` |
| 13 | `in_app_calculator` | Bàn phím máy tính tích hợp | `TOGGLE` | ✅ Mở | ✅ Mở | `LOCK_FEATURE` |
| 14 | `custom_categories` | Quản lý danh mục tùy chỉnh | `LIMIT` | **Trần: 5 danh mục** | **Không giới hạn** | `BLOCK_CREATE` |
| 15 | `category_keywords_matching`| Từ khóa nhận diện danh mục | `TOGGLE` | ✅ Mở (5 từ/cat) | ✅ Mở (25 từ/cat) | `FALLBACK_DEFAULT` |
| 16 | `budgets` | Quản lý ngân sách chi tiêu | `LIMIT` | **Trần: 3 ngân sách** | **Không giới hạn** | `BLOCK_CREATE` |
| 17 | `smart_budget_rebalancing` | Tái phân bổ ngân sách AI | `TOGGLE` | 🔒 **Khóa** | 🔓 **Mở toàn diện** | `LOCK_FEATURE` |
| 18 | `budget_overspend_alert` | Dự báo vỡ hạn mức chi tiêu | `TOGGLE` | ✅ Mở | ✅ Mở (+ Burn-rate) | `FALLBACK_DEFAULT` |
| 19 | `bills` | Quản lý hóa đơn định kỳ | `LIMIT` | **Trần: 3 hóa đơn** | **Không giới hạn** | `BLOCK_CREATE` |
| 20 | `bill_auto_pay` | Tự động thanh toán hóa đơn | `TOGGLE` | 🔒 **Khóa** | 🔓 **Mở toàn diện** | Ân hạn 3 ngày (Server lưu, chưa hiệu lực ở app) |
| 21 | `bill_reminder_notifications`| Nhắc hẹn hóa đơn đa tầng | `TOGGLE` | ✅ Mở (1 ngày) | ✅ Mở (1, 3, 7 ngày) | `FALLBACK_DEFAULT` |
| 22 | `goals` | Mục tiêu tích lũy tiết kiệm | `LIMIT` | **Trần: 3 mục tiêu** | **Không giới hạn** | `BLOCK_CREATE` |
| 23 | `goal_auto_deposit` | Tự động trích tiền mục tiêu | `TOGGLE` | 🔒 **Khóa** | 🔓 **Mở toàn diện** | Ân hạn 3 ngày (Server lưu, chưa hiệu lực ở app) |
| 24 | `goal_deposit_withdraw` | Nạp & Rút tiền mục tiêu | `TOGGLE` | ✅ Mở | ✅ Mở | `BLOCK_CREATE` |
| 25 | `export_reports` | Xuất báo cáo PDF / Excel | `TOGGLE` | 🔒 **Khóa** | 🔓 **Mở toàn diện** | `LOCK_FEATURE` |
| 26 | `financial_health_fhs` | Chỉ số sức khỏe tài chính | `TOGGLE` | ✅ Mở (Điểm cơ bản) | ✅ Mở (AI Deep Insights) | `FALLBACK_DEFAULT` |
| 27 | `cashflow_forecast` | Dự báo dòng tiền 30 ngày | `TOGGLE` | 🔒 **Khóa** | 🔓 **Mở toàn diện** | `READ_ONLY` |
| 28 | `anomaly_spending_insights` | Cảnh báo chi tiêu bất thường | `TOGGLE` | 🔒 **Khóa** | 🔓 **Mở toàn diện** | `LOCK_FEATURE` |
| 29 | `ai_assistant` | Trợ lý Copilot AI Gemini | `TOGGLE` | 🔒 **Khóa** | 🔓 **Mở toàn diện** | `LOCK_FEATURE` |
| 30 | `ai_edge_model` | Mô hình AI Offline trên máy | `TOGGLE` | 🔒 **Khóa** | 🔓 **Mở toàn diện** | `LOCK_FEATURE` |
| 31 | `ai_model_management` | Quản lý bộ nhớ mô hình AI | `TOGGLE` | ✅ Mở (500 MB) | ✅ Mở (2000 MB) | `FALLBACK_DEFAULT` |
| 32 | `bank_notification_parser` | Đọc biến động số dư ngân hàng| `TOGGLE` | ✅ Mở (4 banks) | ✅ Mở (Tất cả banks) | `FALLBACK_DEFAULT` |
| 33 | `daily_recording_reminder` | Nhắc nhở ghi chép hàng ngày | `TOGGLE` | ✅ Mở (1 khung giờ)| ✅ Mở (3 khung giờ) | `FALLBACK_DEFAULT` |
| 34 | `vietqr_payment` | Thanh toán tự động VietQR | `TOGGLE` | ✅ Mở | ✅ Mở | `BLOCK_CREATE` |
| 35 | `payment_history` | Lịch sử thanh toán gói cước | `TOGGLE` | ✅ Mở | ✅ Mở (+ Tải hóa đơn) | `BLOCK_CREATE` |
| 36 | `offline_first_sync` | Đồng bộ 2 chiều Offline-First | `TOGGLE` | ✅ Mở (Debounce 10s)| ⚡ **Mở (Realtime 2s)** | `FALLBACK_DEFAULT` |

---

## 5. CƠ CHẾ THỰC THI ĐA TẦNG (ENFORCEMENT ARCHITECTURE)

### KIẾN TRÚC 5 TẦNG PHÒNG THỦ TẠI CLIENT-APP (FLUTTER)

1. **Tầng 1: Cửa chặn Router Guards (`chan_theo_goi.dart` & `GoRouter`):**
   - Đặt chặn trực tiếp tại `redirect` của các route thêm mới (`/wallets/add`, `/budget/rules`, `/goals/add`) và route chức năng cao cấp (`/export-report`, `/ai-assistant`).
   - Nếu chạm trần số lượng (`dangCo >= limit_value`) hoặc không có quyền (`is_enabled == false`), tự động chuyển hướng sang màn hình `/premium?tran=...` hoặc `/premium?quyen=...`.
2. **Tầng 2: Kiểm soát Trạng thái UI (`GoiCubit` & `quyen_tinh_nang.dart`):**
   - Mọi Widget trên màn hình kiểm tra qua `duocDung(MaQuyen ma, TrangThaiGoi goi, DateTime now)`.
   - Các nút chức năng độc quyền bị ẩn hoặc gắn icon ổ khóa 🔒; khi bấm vào sẽ hiển thị Modal BottomSheet giới thiệu quyền lợi gói Premium thay vì ném ngoại lệ.
3. **Tầng 3: Bộ đếm Hạn mức Nội bộ SQLite (`dem_dang_hoat_dong.dart`):**
   - Đếm số lượng thực tế trực tiếp từ SQLite cục bộ (Drift ORM) với độ trễ 0ms.
   - Hoạt động trơn tru ngay cả khi tắt toàn bộ kết nối mạng (Airplane mode).
4. **Tầng 4: Bộ máy Giải mã Thời hạn Tự động (Autonomous Expiry Clock):**
   - So sánh thời gian thực của máy (`DateTime.now()`) với mốc `hetHan` lưu trong máy.
   - Ngay khi hết hạn lúc offline, Client tự động hạ cấp về gói Basic mà không cần đợi Backend kích hoạt.
   - Client đối soát thời hạn gói bằng so sánh `DateTime.now()` với hạn lưu trên máy; Backend kiểm tra đối chiếu thời hạn chính xác theo giờ UTC của máy chủ.
5. **Tầng 5: Bộ đệm & Kênh Đồng bộ Thời gian thực (Realtime Sync & Cache):**
   - Đồng bộ bảng quyền và hạn mức mới nhất mỗi khi mở app hoặc resume từ background qua API `GET /payment/subscription-info`.
   - Lắng nghe sự kiện Socket.IO `account.permissions_updated` từ Admin-web để cập nhật tức thì toàn bộ giao diện trong < 1 giây.

---

### LÁ CHẮN AN NINH CẤP ĐỘ API TẠI BACKEND (NODEJS)

1. **Middleware Kiểm soát Phân quyền (`feature-permission.middleware.js`):**
   - Bắt buộc kiểm tra quyền cho các endpoint có cấu hình (ví dụ chatbot, OCR).
   - Kiểm tra `account.premium_expires_at`: Nếu đã hết hạn so với thời gian máy chủ UTC (`NOW() AT TIME ZONE 'UTC'`), tự động coi là gói `Basic`.
   - Nếu vi phạm quyền truy cập: Trả về mã lỗi HTTP `403 Forbidden` kèm cấu trúc mã lỗi chuẩn:
     ```json
     {
       "success": false,
       "code": "FEATURE_DISABLED",
       "featureId": "export_reports",
       "accountType": "Basic",
       "message": "Tính năng này chỉ dành riêng cho tài khoản gói Premium."
     }
     ```
2. **Bộ Nhớ Đệm Hiệu Năng Cao (Redis Cache):**
   - Lưu trữ ma trận phân quyền theo gói (`permissions:Basic`, `permissions:Premium`) trong Redis với TTL 1 giờ.
   - Tự động xóa cache (Invalidate) khi Admin cập nhật trên Admin-web.

---

### GIAO DIỆN ĐIỀU HÀNH QUẢN TRỊ TẠI ADMIN-WEB (REACTJS)

1. **Bảng Điều Khiển Ma Trận Phân Quyền (`/permissions`):**
   - Hiển thị đầy đủ 36 tính năng phân theo 13 nhóm tương ứng với Client-app.
   - Cho phép Admin linh hoạt:
     - Bật/Tắt công tắc `is_enabled` cho từng gói.
     - Thiết lập giá trị `limit_value` (nhập số hoặc tích chọn "Không giới hạn").
     - Chỉnh sửa `scope_config` qua bộ soạn thảo JSON hoặc Drawer trực quan.
     - Thiết lập chính sách hạ cấp `downgrade_policy`.
2. **Kích Hoạt Socket Realtime:**
   - Ngay khi Admin nhấn "Lưu thay đổi", hệ thống lưu CSDL Supabase, xóa cache Redis và phát sóng Socket `account.permissions_updated` đến toàn bộ Client đang kết nối.
