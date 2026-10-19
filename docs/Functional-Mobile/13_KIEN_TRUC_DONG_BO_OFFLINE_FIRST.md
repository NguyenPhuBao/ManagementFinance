# 🔄 PHÂN HỆ 13: KIẾN TRÚC ĐỒNG BỘ NGOẠI TUYẾN (OFFLINE-FIRST SYNC ENGINE)

> **Mã phân hệ:** `SYNC_OFFLINE`  
> **Thư mục mã nguồn:** [`src/Client-app/lib/core/sync`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/core/sync) & [`src/Client-app/lib/core/database`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/core/database)  
> **Bộ máy cốt lõi:** `SyncEngine` ([`sync_engine.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/core/sync/sync_engine.dart) ~ 2.164 dòng code)  
> **CSDL Cục bộ (Local Database):** SQLite / Drift ORM ([`app_database.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/core/database/app_database.dart))  
> **Cơ chế Checkpoint:** `SecureStorageSyncCheckpointStore` (`sync_last_pull_v2_$idaccount`)

---

## 1. TỔNG QUAN KIẾN TRÚC OFFLINE-FIRST (OFFLINE-FIRST ARCHITECTURE)

Ứng dụng FlowMoney Client-app tuân thủ triệt để mô hình **Offline-First**. Người dùng có thể thực hiện 100% các nghiệp vụ tài chính (tạo giao dịch, sửa ví, quản lý ngân sách, thiết lập mục tiêu, thanh toán hóa đơn) ngay cả khi không có kết nối internet hoặc mạng chập chờn.

```
┌────────────────────────────────────────────────────────┐
│             GIAO DIỆN NGƯỜI DÙNG (UI SCREENS)          │
└──────────────────────────┬─────────────────────────────┘
                           │ 1. Đọc/Ghi cục bộ tức thời (0ms Latency)
                           ▼
┌────────────────────────────────────────────────────────┐
│          CSDL CỤC BỘ SQLITE (DRIFT DATABASE)           │
│  - Trạng thái bản ghi: pending | synced | blocked      │
└──────────────────────────┬─────────────────────────────┘
                           │ 2. Kích hoạt debounced sync (2s)
                           ▼
┌────────────────────────────────────────────────────────┐
│                   SYNC ENGINE TRUNG TÂM                │
│  ┌──────────────────────┐    ┌──────────────────────┐  │
│  │     PUSH ENGINE      │    │     PULL ENGINE      │  │
│  │ (Đẩy batch thay đổi) │    │ (Kéo delta từ server)│  │
│  └──────────┬───────────┘    └──────────▲───────────┘  │
└─────────────┼───────────────────────────┼──────────────┘
              │ 3. POST /sync/push        │ 4. GET /sync/pull?since=...
              ▼                           │
┌────────────────────────────────────────────────────────┐
│             HỆ THỐNG MÁY CHỦ BACKEND API               │
│         PostgreSQL Database (Server_update_at)         │
└────────────────────────────────────────────────────────┘
```

---

## 2. 6 THỰC THỂ DỮ LIỆU ĐỒNG BỘ CỐT LÕI (SYNC ENTITIES)

Hệ thống quản lý đồng bộ 2 chiều cho 6 thực thể chính (`SyncEntityType` trong [`sync_models.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/core/sync/sync_models.dart)):

| Thực thể (`SyncEntityType`) | Bảng SQLite Local | DAO quản lý | Đặc tả xử lý đồng bộ & Ràng buộc toàn vẹn |
|:---|:---|:---|:---|
| `wallet` | `wallets` | `WalletDao` | Xử lý ví trùng tên cục bộ (`ViBiGiuDongBo`), tính toán cân đối số dư tự động sau mỗi chu kỳ Pull (`CongSoDuVi`). |
| `transaction` | `transactions` | `TransactionDao` | Chuẩn hóa kiểu boolean (`is_report_excluded`), định dạng ngày không giờ (`Period_end`) theo chuẩn UTC nửa đêm. |
| `category` | `categories` | `CategoryDao` | Duy trì cây danh mục cha-con, mapping icon qua `CategoryIconRegistry`, chống nhân bản danh mục mặc định (`PersonalDefaultCategories`). |
| `budget` | `budgets` | `BudgetDao` | Đồng bộ hạn mức chi tiêu theo danh mục, tính toán chi tiêu tích lũy theo thời gian thực. |
| `bill` | `bills` | `BillDao` | Quản lý chu kỳ lặp lại (`BillRecurrence`), trạng thái thanh toán (`BillPayStatus`), tự động sinh giao dịch khi thanh toán. |
| `goal` | `goals` | `GoalDao` | Quản lý mục tiêu tài chính, tiến độ nạp tiền và thứ tự ưu tiên (`UuTienHopLe`). |

---

## 3. CƠ CHẾ ĐẨY DỮ LIỆU (PUSH ENGINE - CLIENT TO SERVER)

1. **Ghi nhận thay đổi cục bộ (Local Change Queueing):**
   - Mọi thao tác thêm/sửa/xóa trên giao diện ghi trực tiếp vào SQLite.
   - Cột `sync_status` được gán giá trị `'pending'` và `updated_at` được gán bằng `DateTime.now().toUtc()`.
   - UI phản hồi lập tức mà không cần chờ mạng (Zero-latency UI).

2. **Gom cụm & Giảm tải yêu cầu (Debounce & Batching):**
   - Mỗi lần có thay đổi, `scheduleSync()` được kích hoạt.
   - Thay vì gửi API ngay lập tức, `SyncEngine` thiết lập bộ đếm trễ **2 giây (`_debounceSeconds = 2`)**.
   - Toàn bộ các thao tác ghi phát sinh trong 2 giây được gom thành 1 danh sách batch duy nhất và gửi lên `POST /sync/push`.

3. **Chuẩn hóa Payload (`SyncPayloadNormalizer`):**
   - Chuyển đổi dữ liệu Dart thành JSON tương thích chuẩn PostgreSQL.
   - Chuẩn hóa các giá trị boolean theo quy ước backend (`BackendBool`).
   - Xử lý các khóa ngoại liên bảng đảm bảo không vi phạm ràng buộc toàn vẹn CSDL.

4. **Phân loại xử lý lỗi đẩy (`SyncOpFailure` & `SyncFailureKind`):**
   - `SyncFailureKind.transient`: Lỗi tạm thời (5xx, mất sóng, sai thứ tự phụ thuộc). Engine giữ nguyên trạng thái `pending` để tự động thử lại ở chu kỳ tiếp theo sau khi đã hoàn tất Pull.
   - `SyncFailureKind.permanent`: Lỗi dữ liệu không hợp lệ vĩnh viễn. Đánh dấu chặn tạm thời (`_markBlockedById`) có thời hạn, tránh spam request làm tê liệt hệ thống.
   - `SyncFailureKind.sessionInvalid`: Phiên làm việc trỏ tới tài khoản không còn tồn tại trên server (vỡ khóa ngoại `fk_*_account`). Engine phát sự kiện ra `sessionInvalidStream` để kích hoạt đăng xuất bảo vệ an toàn.

---

## 4. CƠ CHẾ KÉO DỮ LIỆU GIA TĂNG (PULL DELTA ENGINE - SERVER TO CLIENT)

1. **Điểm kiểm tra mốc thời gian bền vững (Persistent Checkpointing):**
   - Mốc thời gian lần kéo thành công gần nhất được lưu trữ an toàn trong `FlutterSecureStorage` thông qua khóa `sync_last_pull_v2_$idaccount` ([`sync_checkpoint_store.dart`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Client-app/lib/core/sync/sync_checkpoint_store.dart)).
   - Tránh việc mỗi lần mở app phải tải lại toàn bộ CSDL từ năm 1970, tiết kiệm 95% băng thông và bộ nhớ.

2. **Cơ chế mốc kéo an toàn chống bỏ sót dữ liệu (Chuẩn G67 - `moc_keo_ve.dart`):**
   - Lọc và sắp xếp dữ liệu tại backend dựa trên cột thời gian ghi nhận của máy chủ `Server_update_at`.
   - Server trả về `maxSince` cho từng bảng và thời điểm phản hồi `pulledAt`.
   - **Khoảng lùi an toàn (`kLuiAnToanKeoVe = 2 phút`):** Kẹp mốc kéo về tối đa bằng `pulledAt - 2 phút` để bao trọn độ trễ commit giao dịch phân tán và lệch đồng hồ giữa các node máy chủ.
   - **Gia số vi sai (`+ 1 millisecond`):** Khi dữ liệu đã nguội, mốc được cộng thêm 1ms nhằm chống việc kéo lặp lại các bản ghi cũ ở mỗi chu kỳ.

3. **Chiến lược giải quyết xung đột (Conflict Resolution - Last-Write-Wins):**
   - So sánh thời điểm cập nhật `updated_at` của bản ghi trên server với bản ghi cục bộ:
     - **Nếu Server mới hơn hoặc bằng (`server.updated_at >= local.updated_at`):** Ghi đè dữ liệu server vào SQLite local và đánh dấu `sync_status = 'synced'`.
     - **Nếu Local mới hơn và đang chờ đẩy (`local.sync_status == 'pending'`):** Giữ nguyên dữ liệu local, ưu tiên thay đổi mới nhất của người dùng trên thiết bị hiện tại để đẩy lên server ở chu kỳ Push tiếp theo.

4. **Tái cân đối số dư ví sau Pull (`CongSoDuVi`):**
   - Sau khi cập nhật toàn bộ các giao dịch mới kéo về vào SQLite, `SyncEngine` tự động gọi dịch vụ tính toán lại số dư `_soDuVi.canBangLaiSoDu()` để đảm bảo số dư hiển thị trên tất cả các ví khớp 100% với biến động giao dịch thực tế.

---

## 5. CƠ CHẾ TỰ ĐỘNG HÓA NỀN & KHÔI PHỤC KẾT NỐI (BACKGROUND RESILIENCE)

| Cơ chế | Cấu hình kỹ thuật | Mục đích nghiệp vụ |
|:---|:---|:---|
| **Giám sát kết nối mạng** | `Connectivity().onConnectivityChanged` | Tự động phát hiện khi thiết bị kết nối lại Wifi / 4G / 5G để kích hoạt đồng bộ ngay lập tức. |
| **Chu kỳ đồng bộ nền** | Định kỳ mỗi **15 phút** (`_periodicSyncMinutes = 15`) | Kéo các biến động tài chính mới nhất từ các thiết bị khác hoặc giao dịch hệ thống về máy. |
| **Thuật toán lùi số mũ (Backoff)** | `[30s, 1m, 5m, 15m, 60m]` (`_backoffSteps`) | Giảm tần suất gửi request khi server gặp sự cố hoặc mất mạng kéo dài, tránh cạn pin thiết bị. |
| **Hẹn giờ bù đắp (Backoff Retry)** | `_scheduleBackoffRetry(until)` | Đảm bảo các thay đổi người dùng ghi chép trong giai đoạn đang bị giãn cách được gửi đi ngay khi hết thời gian chờ, không bị bỏ quên. |
