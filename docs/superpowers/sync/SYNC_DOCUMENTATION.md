# TÀI LIỆU TỔNG KẾT BÁO CÁO ĐỒNG BỘ DỮ LIỆU (SYNC ENGINE DOCUMENTATION)

> 🔀 **2026-10-26 — Cập nhật đồng bộ sau đợt chuẩn hóa CSDL & Thống nhất Hợp đồng 6 bảng:**
> - Backend Module SYNC (`src/Backend/modules/sync/sync.repository.js`) đã được bổ sung hỗ trợ toàn diện bí danh xóa mềm `is_deleted` (snake_case) bên cạnh `isDeleted` (camelCase) và `delete_at`/`deletedAt` cho cả 6 thực thể (`wallet`, `category`, `goal`, `bill`, `budget`, `transaction`).
> - Xác nhận 100% khớp nối với bài kiểm thử hợp đồng chuẩn `src/Client-app/test/core/sync/sync_payload_contract_test.dart`.
> - Bổ sung hướng dẫn chi tiết các hạng mục phía Client-App cần thực hiện tại **Mục V**.

> 🔀 **2026-10-25 — gộp `main` @ `0ab9cbd4` (tái phát):** commit backend `36f1ea43` lại viết đè tệp này thành *"Hợp đồng v4.0"*
> (255 dòng). Client **giữ bản này** lần nữa (người dùng chốt): v4.0 ghi số trường sai so với hợp đồng thật (ví 16 / giao dịch 18
> / mục tiêu 24 / hoá đơn 24 — thật là 13 / 13 / 22 / 21), và mục 6 *"Checklist cho Dev Client-App"* có một việc trái quy tắc đã
> chốt (việc 4: thêm `provider` · `bank_tran_id` · `status` · `images` vào payload giao dịch — quy tắc 4 `CLAUDE.md`); các việc
> còn lại client đã làm từ trước (kể cả `amount` mang dấu: `sync_payload_normalizer.dart` đổi `chi` → `Transaction` + số âm lúc
> đẩy). Chi tiết: phần *Tái phát 2026-10-25* đơn **49**. Bản v4.0: `git show 36f1ea43:docs/superpowers/sync/SYNC_DOCUMENTATION.md`.

> 🔀 **2026-10-23 — gộp `main` @ `ee6a65e5`:** commit backend `6cbd248e` đã viết lại tệp này thành bản *"Hợp đồng v3.0"*
> (223 dòng). Client **giữ bản này** (người dùng chốt): bản v3.0 sai so với mã ở khoảng 15 chỗ — loại ví, `idaccount` của
> danh mục hệ thống, công thức mốc kéo về, thứ tự đẩy, nhiều tên cột — và bỏ mất các ghi chú G67 / G85 / G34 bên dưới. Danh
> sách đối chiếu và lời xin backend: mục **49** `docs/superpowers/backend/CAN-LAM/SOAT_SAU_GOP_EE6A65E5.md` (vế A). Bản v3.0
> vẫn đọc được bằng `git show 6cbd248e:docs/superpowers/sync/SYNC_DOCUMENTATION.md`; bảng trường phía backend nằm ở
> `docs/Admin-web/Sync-To-ClientApp.md` (cũng chưa soát, xem đơn).

> **Dự án:** ManagementFinance  
> **Kiến trúc:** Offline-First (CSDL SQLite local Drift + PostgreSQL Backend REST API)  
> **Cơ chế:** Full 2-Way Sync (Push & Pull với Last-Write-Wins LWW Conflict Resolution)  
> **Soát lại:** 2026-10-26 (Chuẩn hóa Hợp đồng 6 bảng, bảo toàn G28/G34/G37/G67/G85, bổ sung Mục V việc Client-App cần làm)

---

## 🟢 I. DANH SÁCH CÁC CHỨC NĂNG ĐÃ HOÀN THÀNH SYNC 100%

Tất cả 6 mô-đun dữ liệu cốt lõi dưới đây đã được hoàn thiện đầy đủ cả **Push** (đẩy dữ liệu local lên CSDL PostgreSQL server) lẫn **Pull** (kéo dữ liệu mới từ server về CSDL SQLite local) và đã qua kiểm thử thực tế.

| STT | Mô-đun Chức năng | Trạng thái Sync | Chi tiết thuộc tính được đồng bộ | Ghi chú kỹ thuật |
| :--- | :--- | :---: | :--- | :--- |
| **1** | **Ví tài chính**<br>`(Wallets)` | ✅ **Hoàn thành 100%** | **13 trường**: `id`, `idaccount`, `name`, `type`, `balance` (hợp đồng 1 chiều Push), `currency`, `icon`, `color`, `is_default`, `is_deleted`, `include_in_total`, `status` (`'Active'`/`'Inactive'`), `update_at`. | Hỗ trợ thêm mới, sửa, xóa mềm (`is_deleted`) và tính tổng số dư tự động. ⚠️ **"100%" chỉ đúng từ 2026-09-09**: `include_in_total` có trong payload đẩy lên từ lâu nhưng nhánh **kéo về không đọc nó** — hỏng im lặng đúng kiểu quy tắc 4, một chiều đủ không có nghĩa là tròn vòng. ⚠️ **`balance` nay là hợp đồng MỘT CHIỀU, cố ý** (2026-09-13, G37): nhánh đẩy vẫn gửi nó, nhánh **kéo về thôi đọc** (`Value.absent()`). Số dư ví là **cache của tổng sổ giao dịch** — con số server chỉ là ảnh chụp cũ, và đọc nó về là nuốt mọi thay đổi cục bộ chưa kịp đẩy. Vẫn đẩy để truy vấn PostgreSQL còn đo được, và vì hai máy tính ra cùng kết quả nên LWW giữa hai số bằng nhau là vô hại. Payload vẫn **13 trường**. |
| **2** | **Giao dịch Thu/Chi**<br>`(Transactions)` | ✅ **Hoàn thành 100%** | **13 trường**: `id`, `idaccount`, `walletId`/`idwallet`, `categoryId`/`idcategory`, `idwallet_transfer`, `amount` (âm là Chi, dương là Thu), `type` (`'Transaction'`/`'Transfer'`), `note` (mã hóa At-Rest), `dateTransaction`/`date_transaction`, `idgoal`, `idbill`, `is_deleted`, `update_at`. | Xử lý an toàn Ràng buộc khóa ngoại (`idcategory` = null nếu chưa linked). Tự động khớp `localId`. `type` có **ba** giá trị phía client: `'thu'`, `'chi'`, `'transfer'` (chuyển ví và nạp mục tiêu); normalizer chuẩn hóa thành `'Transaction'`/`'Transfer'` khi gửi lên server. Có `idgoal`, `idbill` (⚠️ cột này có khoá ngoại nên **hoá đơn phải đẩy TRƯỚC giao dịch**). |
| **3** | **Danh mục Chi tiêu**<br>`(Categories)` | ✅ **Hoàn thành 100%** | **12 trường**: `id`, `create_by`/`idaccount`, `name_category`/`name`, `classify` (`'Thu'`/`'Chi'`/`'Vay/no'`), `is_default`, `is_group`/`isGroup`, `idgroup`/`parentId`, `icon`, `color`, `keyword`, `is_deleted`, `update_at`. | Đồng bộ danh mục tùy chỉnh do người dùng tự tạo; bảo vệ danh mục mặc định hệ thống. Đảm bảo cấu trúc cây phân cấp danh mục (`isGroup`/`parentId`). Normalizer đồng nhất màu sắc `color` khi đẩy và kéo về. |
| **4** | **Ngân sách Chi tiêu**<br>`(Budgets)` | ✅ **Hoàn thành 100%** | **17 trường**: `id`, `idaccount`, `idcategory`, `total_amount`, `spent`, `threshold_warning_amount`, `threshold_warning_percent`, `over_spending` (`'Stop'`/`'Over'`), `over_amount`, `start`, `end`, `recurrence`, `time_recurrence`, `nexttime_recurrence`, `note`, `is_deleted`, `update_at`. | **Không có `period`** — cột ấy đã bị `time_recurrence` thay từ DB v2; cũng không có `amount` mà là `total_amount`. Đồng bộ giới hạn ngân sách theo từng tháng/chu kỳ. |
| **5** | **Hóa đơn & Dịch vụ**<br>`(Bills)` | ✅ **Hoàn thành 100%** | **21 trường**: `id`, `idaccount`, `idwallet`, `idcategory`, `name`, `amount`, `start_date`, `due_date`, `pay_status` (`'Pending'`/`'Payed'`/`'Overdue'`/`'Skipped'`), `recurrence`, `time_recurrence`, `time_notification` (cho phép `null` để tắt nhắc), `icon`, `color`, `note`, `previous_bill_id`, `period_end`, `auto_pay`, `anchor_day`, `is_deleted`, `update_at`. | Trạng thái thanh toán là `pay_status` (chuỗi), **không** phải `is_paid`. Hỗ trợ 4 trạng thái: `'Pending'`, `'Payed'`, `'Overdue'`, `'Skipped'`. Cho phép `time_notification: null` để tắt nhắc nhở. Tích hợp `BillPaymentConflictResolver` gỡ xung đột `BILL_ALREADY_PAID`. |
| **6** | **Mục tiêu Tiết kiệm**<br>`(Goals)` | ✅ **Hoàn thành 100%** | **22 trường**: `id`, `idaccount`, `idwallet`, `name`, `target_amount`, `current_amount`, `start_date`, `target_date`, `cycle_take_money`, `time_cycle_take_money`, `status_complete` (`'True'`/`'False'`), `recurrence`, `time_recurrence`, `icon`, `color`, `note`, `auto_deposit_amount`, `auto_deposit_wallet_id`, `auto_deposit_last_run`, `priority`, `is_deleted`, `update_at`. | Đồng bộ tiến độ tích lũy và số tiền mục tiêu tiết kiệm. Ba cột `auto_deposit_*` đi cùng nhau để xử lý trích tiền tự động. Cột `priority` hỗ trợ sắp xếp thứ tự ưu tiên. |

---

## ⚡ II. CÁC TÍNH NĂNG ĐỒNG BỘ NÂNG CAO ĐÃ TÍCH HỢP

1. **Đồng bộ Lập tức khi Đăng nhập (Immediate Sync on Login):**
   * Ngay khi đăng nhập thành công hoặc mở ứng dụng (`AuthSuccess` / `HomePage` mount), `SyncEngine` sẽ khởi động và thực hiện kéo toàn bộ dữ liệu mới nhất từ CSDL PostgreSQL Backend về SQLite local mà không cần chờ thao tác của người dùng.
2. **Chuẩn hóa Gói tin 2 Chiều (Payload Normalization & Unpacking):**
   * Bóc tách tầng dữ liệu lồng nhau `topData['data']['results']` và `topData['data']['data']` của `ResponseHandler` phía Backend.
   * Chuyển đổi linh hoạt giữa chuỗi `camelCase` phía Dart và `snake_case` phía Backend PostgreSQL.
   * Hỗ trợ alias xóa mềm đa dạng: `is_deleted` (snake_case), `isDeleted` (camelCase), `delete_at`, `deletedAt`.
   * Tự động chuẩn hóa chuỗi UUID 36 ký tự và mốc thời gian chuẩn UTC ISO 8601.
3. **Cô lập Dữ liệu Người dùng (Account Data Isolation):**
   * Tất cả câu lệnh truy vấn SQLite local (`WalletDao`, `TransactionDao`) được cô lập nghiêm ngặt theo `idaccount`.
   * Reset mốc thời gian checkpoint `_lastPullTime = null` khi Đăng xuất (`LogoutRequested`), đảm bảo chuyển đổi tài khoản an toàn 100%.
   * **Bổ sung 2026-09-08:** mốc pull nay còn được **lưu bền vững theo từng tài khoản** qua `SyncCheckpointStore` (nay do `ApDuLieuKeoVe` cầm, `core/sync/ap_du_lieu_keo_ve.dart`), nên mở lại app không kéo lại từ đầu. Câu ở trên chỉ mô tả nhánh đăng xuất.
   * **Đổi 2026-10-08 (G67):** mốc thôi lấy theo `update_at` (giờ ghi của máy) mà theo **giờ-server** — `mocTuMaxSince` (`core/sync/moc_keo_ve.dart`) đọc `maxSince` từng bảng + `pulledAt` của phản hồi `/sync/pull` (migration 20 + 21): lớn nhất giữa các bảng, kẹp `pulledAt − 2 phút` khi còn nóng, +1 ms khi nguội. Khoá lưu đổi sang `sync_last_pull_v2_<id>` để mỗi máy kéo lại toàn bộ một lần. Mục G67 `CLIENT_APP_KNOWN_GAPS.md`.
   * **G85 (2026-10-08):** lượt kéo về vá neo (khoản mở sổ) cho ví đã có trên máy **trước** khi ghi giao dịch vừa kéo vào sổ — vá sau là neo nuốt giao dịch của máy kia. Ví đích của khoản chuyển vừa về cũng được tính lại.
4. **Sự kiện Realtime Socket.io Trigger Sync:**
   * Backend phát `sync.completed` qua kênh Socket.io sau mỗi lần hoàn tất `/sync/push`. Client-app lắng nghe `RealtimeEvent.dongBoXong` để gọi `syncNow()`, giúp các thiết bị cùng tài khoản đồng bộ dữ liệu gần như tức thì trong cùng một giây (Zero Lag Multi-Device Sync).

---

## 🔴 III. CÁC HẠNG MỤC / CHỨC NĂNG CHƯA TRIỂN KHAI SYNC

Dưới đây là các hạng mục nâng cao chưa hỗ trợ đồng bộ (hoặc chưa yêu cầu tích hợp trong phạm vi hiện tại):

| STT | Hạng mục chưa Sync | Mô tả chi tiết | Hướng nâng cấp trong tương lai (nếu cần) |
| :--- | :--- | :--- | :--- |
| **1** | **Tệp ảnh đính kèm Giao dịch**<br>`(Transaction Images)` | Cột `images` trong bảng giao dịch hiện lưu dưới dạng storage key hoặc URL presigned. Chưa đồng bộ toàn bộ file nhị phân trực tiếp trong payload sync. | Đã tích hợp upload ảnh qua MinIO / Cloud Storage, trường `images` chỉ đồng bộ URL/Key. |
| **2** | **Chia sẻ Ví nhóm / Phân quyền**<br>`(Shared Wallets)` | Mỗi Ví hiện tại gắn cố định với 1 `idaccount` sở hữu duy nhất. Chưa hỗ trợ chia sẻ ví giữa nhiều tài khoản người dùng khác nhau. | Mở rộng schema backend bảng `wallet_member` để phân quyền xem/chỉnh sửa ví cho nhiều người dùng. |
| **3** | **Lịch sử Nhật ký Thay đổi Chi tiết**<br>`(Detailed Audit Logs Sync)` | Nhật ký thao tác người dùng (`auditlog`) hiện được ghi nhận tại server Backend. Chưa đồng bộ bảng audit log về SQLite local client. | Đã có sẵn trên CSDL PostgreSQL Backend, client chỉ truy vấn khi cần xem báo cáo bảo mật. |

---

## 🛠️ IV. NGUYÊN TẮC BẢO TRÌ VÀ PHÁT TRIỂN TIẾP THEO

1. **Tuân thủ phân định Client - Backend:**
   * Mọi điều chỉnh logic, chuẩn hóa định dạng và bóc tách gói tin phải được thực hiện hoàn toàn ở phía **Client-app** (`src/Client-app/lib/core/sync/` — `sync_engine.dart` điều phối; `thu_gom_day.dart` gom thao tác chờ, `gui_lo_dong_bo.dart` đẩy lô + phân loại lỗi, `ap_du_lieu_keo_ve.dart` kéo về + mốc, `sync_payload_normalizer.dart` chuẩn hoá tên trường), tuyệt đối không can thiệp CSDL hoặc mã nguồn Backend.
2. **Trạng thái bản ghi (Sync Status):**
   * Các bản ghi tạo mới/chỉnh sửa tại SQLite local luôn bắt đầu với `syncStatus = 'pending'`.
   * Sau khi PUSH thành công tới Backend hoặc PULL từ Backend về, `syncStatus` bắt buộc được chuyển thành `'synced'`.
3. **Thứ tự ràng buộc khóa ngoại khi Đẩy (Push Ordering):**
   * Khi tạo/sửa: Category (10) $\to$ Wallet (20) $\to$ Budget (30) $\to$ Goal (35) $\to$ Bill (38) $\to$ Transaction (40).
   * Khi xóa: Transaction (60) $\to$ Bill (62) $\to$ Goal (65) $\to$ Budget (70) $\to$ Wallet (80) $\to$ Category (90).

---

## 📋 V. CÔNG VIỆC PHÍA CLIENT-APP CẦN LÀM & ĐIỀU CHỈNH ĐỒNG BỘ

Để đảm bảo Client-app đồng bộ mượt mà 100% với Backend sau các đợt cập nhật CSDL và API mới nhất, nhóm phát triển Client-app cần kiểm tra và triển khai các hạng mục sau:

### 1. Đồng bộ thuộc tính Xóa Mềm (`is_deleted`)
- **Hiện trạng:** Backend Module SYNC hiện đã chấp nhận cả `is_deleted` (snake_case) lẫn `isDeleted` (camelCase) và `delete_at`/`deletedAt` cho cả 6 entity.
- **Yêu cầu Client-app:** Đảm bảo `sync_payload_normalizer.dart` xuất trường `is_deleted: true` khi người dùng xóa mềm bản ghi trên SQLite Drift. Nhánh kéo về (`ap_du_lieu_keo_ve.dart`) khi thấy `delete_at != null` hoặc `deleted_at != null` thì cập nhật trạng thái `isDeleted = true` tương ứng trong SQLite.

### 2. Tắt nhắc nhở Hóa đơn (`time_notification: null`)
- **Hiện trạng:** CSDL PostgreSQL Backend đã chuẩn hóa cột `time_notification` của bảng `bill` cho phép nhận giá trị `null` (để biểu thị người dùng tắt chuông/tắt nhắc hóa đơn).
- **Yêu cầu Client-app:** Khi người dùng tắt nhắc nhở hóa đơn, Client-app gửi `time_notification: null` (hoặc `Value(null)` trong Drift) thay vì gửi chuỗi rỗng `""` hoặc cố định `"3"`. Nhánh kéo về xử lý an toàn nếu giá trị là `null`.

### 3. Trạng thái Hóa đơn Bỏ qua kỳ (`pay_status: 'Skipped'`)
- **Hiện trạng:** CSDL hỗ trợ 4 trạng thái hóa đơn: `'Pending'`, `'Payed'`, `'Overdue'`, `'Skipped'`.
- **Yêu cầu Client-app:** Kiểm tra `BillDao` và UI hóa đơn hỗ trợ đầy đủ enum/giá trị `'Skipped'`. Khi kéo về, bản ghi `'Skipped'` được coi là chưa thanh toán tiền (`isPaid = false`) nhưng không tính vào danh sách nợ quá hạn khẩn cấp.

### 4. Trạng thái Lưu trữ Ví (`status: 'Active'` / `'Inactive'`)
- **Hiện trạng:** Bảng ví `wallet` có trường `status` gồm `'Active'` và `'Inactive'`.
- **Yêu cầu Client-app:** Đảm bảo SQLite `WalletsCompanion` duy trì trường `status` (13 trường tổng cộng). Khi người dùng thực hiện tính năng "Lưu trữ ví" (Archive Wallet), gửi `status: 'Inactive'`.

### 5. Cơ chế Giải mã trường Ghi chú (`note`) tự động
- **Hiện trạng:** Backend tự động mã hóa AES-256 At-Rest trường `note` của Giao dịch, Ngân sách, Hóa đơn và Mục tiêu trước khi lưu vào PostgreSQL.
- **Yêu cầu Client-app:** Khi gọi `GET /api/sync/pull`, Backend **đã tự động giải mã plaintext** trường `note` trả về qua kết nối bảo mật HTTPS TLS 1.3. Phía Client-app **KHÔNG** cần tự giải mã AES thủ công, chỉ cần đọc trực tiếp trường `note` và lưu vào SQLite Drift.

### 6. Gửi Header Thiết bị (`x-device-name`) qua Dio Interceptor
- **Hiện trạng:** Backend triển khai tính năng giám sát lịch sử truy cập và phát hiện đăng nhập lạ (`account_device_history`).
- **Yêu cầu Client-app:** Bổ sung vào Dio Interceptor (tại `src/Client-app/lib/core/network/` hoặc `api_client.dart`):
  - Header: `x-device-name: "<Tên nền tảng> <Tên thiết bị>"` (Ví dụ: `Platform.operatingSystem + " " + deviceInfo.model`, ví dụ: `"Android Samsung Galaxy S23"` hoặc `"iOS iPhone 15 Pro"`).
  - Backend sẽ tự động lấy địa chỉ IP của request, áp dụng che bớt IP (`113.161.xx.xx`) theo Nghị định 13/2023/NĐ-CP và tự động ghi nhận vào bảng `account_device_history`. Client-app tuyệt đối **không** cần tự gọi API bên thứ ba để tìm IP công khai.
