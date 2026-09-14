# TÀI LIỆU TỔNG KẾT BÁO CÁO ĐỒNG BỘ DỮ LIỆU (SYNC ENGINE DOCUMENTATION)

> **Dự án:** ManagementFinance  
> **Kiến trúc:** Offline-First (CSDL SQLite local Drift + PostgreSQL Backend REST API)  
> **Cơ chế:** Full 2-Way Sync (Push & Pull với Last-Write-Wins LWW Conflict Resolution)  
> **Soát lại:** 2026-09-14 (ví **12 → 13 trường** sau khi `status` — lưu trữ ví — đi qua đồng bộ, **G28**; tệp thôi bị `.gitignore` chặn) · trước đó 2026-09-12 (mục III.2, G34) · 2026-09-08 (thêm ghi chú ⚠️ 2026-09-11 ở dòng 3, dòng 5 và mục III.2, sau khi gộp `main` @ `cc65f4f`)

> ⚠️ **Danh sách thuộc tính ở mục I dưới đây KHÔNG phải hợp đồng.** Nơi duy
> nhất ghi tên trường giữa hai phía là
> `src/Client-app/test/core/sync/sync_payload_contract_test.dart` — đọc nó như
> tài liệu (quy tắc 4 `CLAUDE.md`). Bảng dưới từng liệt kê theo trí nhớ và đã
> sai ở nhiều chỗ: thiếu `idgoal`/`priority`/ba cột `auto_deposit_*`, còn ghi
> `period` của ngân sách (cột ấy đã bị `time_recurrence` thay từ DB v2), và ghi
> `type` của giao dịch chỉ có `'thu'/'chi'` trong khi khoản nạp mục tiêu là
> `'transfer'`. Cột **số trường** trong bảng được đếm **bằng máy** từ chính tệp
> hợp đồng ngày 2026-09-08.

> ✅ **Tệp này nay ĐƯỢC git theo dõi** (2026-09-14, theo yêu cầu của người dùng).
> Trước đó `docs/superpowers/sync/` bị `.gitignore` chặn nên nó chỉ có trên máy
> đã dựng; `.gitignore` nay chặn thư mục ấy nhưng **trừ** tệp này.

---

## 🟢 I. DANH SÁCH CÁC CHỨC NĂNG ĐÃ HOÀN THÀNH SYNC 100%

Tất cả 6 mô-đun dữ liệu cốt lõi dưới đây đã được hoàn thiện đầy đủ cả **Push** (đẩy dữ liệu local lên CSDL PostgreSQL server) lẫn **Pull** (kéo dữ liệu mới từ server về CSDL SQLite local) và đã qua kiểm thử thực tế.

| STT | Mô-đun Chức năng | Trạng thái Sync | Chi tiết thuộc tính được đồng bộ | Ghi chú kỹ thuật |
| :--- | :--- | :---: | :--- | :--- |
| **1** | **Ví tài chính**<br>`(Wallets)` | ✅ **Hoàn thành 100%** | **13 trường** (đếm lại 2026-09-14 sau khi `status` — lưu trữ ví — đi qua đồng bộ, G28; mốc **12** đúng tới trước ngày ấy) — gồm cả `include_in_total` mà bảng cũ ở đây bỏ sót | Hỗ trợ thêm mới, sửa, xóa mềm (`is_deleted`) và tính tổng số dư tự động. ⚠️ **"100%" chỉ đúng từ 2026-09-09**: `include_in_total` có trong payload đẩy lên từ lâu nhưng nhánh **kéo về không đọc nó** — hỏng im lặng đúng kiểu quy tắc 4, một chiều đủ không có nghĩa là tròn vòng. ⚠️ **`balance` nay là hợp đồng MỘT CHIỀU, cố ý** (2026-09-13, G37): nhánh đẩy vẫn gửi nó, nhánh **kéo về thôi đọc** (`Value.absent()`). Số dư ví là **cache của tổng sổ giao dịch** — con số server chỉ là ảnh chụp cũ, và đọc nó về là nuốt mọi thay đổi cục bộ chưa kịp đẩy. Vẫn đẩy để truy vấn PostgreSQL còn đo được, và vì hai máy tính ra cùng kết quả nên LWW giữa hai số bằng nhau là vô hại. Payload vẫn **12 trường**. |
| **2** | **Giao dịch Thu/Chi**<br>`(Transactions)` | ✅ **Hoàn thành 100%** | **13 trường** (đếm lại 2026-09-12 sau khi `idbill` vào; mốc 12 là của 2026-09-07 khi `idgoal` vào). `type` có **ba** giá trị chứ không hai: `'thu'`, `'chi'`, `'transfer'` (chuyển ví và nạp mục tiêu). Có `idgoal` (2026-09-07), `idbill` (2026-09-12 — ⚠️ cột này có khoá ngoại nên **hoá đơn phải đẩy TRƯỚC giao dịch**) và `idwallet_transfer`; tên gửi lên là `walletId`/`categoryId`/`dateTransaction` chứ không phải `wallet_id`/`category_id`/`date` | Xử lý an toàn Ràng buộc khóa ngoại (`category_id` = null nếu chưa linked). Tự động khớp `localId`. |
| **3** | **Danh mục Chi tiêu**<br>`(Categories)` | ✅ **Hoàn thành 100%** | **12 trường**, gồm `isGroup`/`parentId` để backend dựng lại cây nhóm — thiếu hai cái này là cấu trúc nhóm mất sau mỗi lần pull | Đồng bộ danh mục tùy chỉnh do người dùng tự tạo; bảo vệ danh mục mặc định hệ thống. ✅ **2026-09-11:** normalizer đổi `colour` → `color` khi đẩy, kéo về đọc `color` — màu danh mục đi qua đồng bộ (**G24** đóng; danh mục cũ lên màu khi được lưu lại). |
| **4** | **Ngân sách Chi tiêu**<br>`(Budgets)` | ✅ **Hoàn thành 100%** | **17 trường**. **Không có `period`** — cột ấy đã bị `time_recurrence` thay từ DB v2; cũng không có `amount` mà là `total_amount` | Đồng bộ giới hạn ngân sách theo từng tháng/chu kỳ. |
| **5** | **Hóa đơn & Dịch vụ**<br>`(Bills)` | ✅ **Hoàn thành 100%** | **21 trường** (đếm lại 2026-09-13 sau `auto_pay`; mốc 20 là 2026-09-12 tối sau `period_end` — ân hạn hoá đơn, schema v21, gửi nửa đêm UTC của ngày cục bộ vì cột là `@db.Date`; mốc 19 là cùng ngày sau `previous_bill_id` và `anchor_day`; mốc 17 trước đó). Trạng thái trả là `pay_status` (chuỗi), **không** phải `is_paid` — và từ 2026-09-12 client **ghi cả giá trị thứ tư `'Skipped'`** (bỏ qua kỳ): nó đi nguyên văn cả hai chiều, có ca test khoá trong `sync_payload_contract_test.dart`; nhánh kéo về suy `isPaid = false` cho nó. ✅ Từ 2026-09-12 client gửi/đọc `previous_bill_id` và `anchor_day` (cùng `idbill` của giao dịch) — đo trên backend thật. ✅ Từ **2026-09-13** client gửi/đọc `auto_pay` (bước 12) — **21 trường**; đi kèm nó là `BillPaymentConflictResolver`, thứ nghe `pushResultStream` để gỡ khoản trả bị `BILL_ALREADY_PAID` từ chối (mục **6.8** `BILL_DOCUMENTATION.md`) | Đồng bộ hóa đơn định kỳ, ngày đến hạn và trạng thái đã thanh toán. |
| **6** | **Mục tiêu Tiết kiệm**<br>`(Goals)` | ✅ **Hoàn thành 100%** | **22 trường** — nhiều nhất trong sáu mô-đun. Gồm ba cột `auto_deposit_*` (2026-09-07, phải đi **cùng nhau**) và `priority` (2026-09-08) | Đồng bộ tiến độ tích lũy và số tiền mục tiêu tiết kiệm. |

---

## ⚡ II. CÁC TÍNH NĂNG ĐỒNG BỘ NÂNG CAO ĐÃ TÍCH HỢP

1. **Đồng bộ Lập tức khi Đăng nhập (Immediate Sync on Login):**
   * Ngay khi đăng nhập thành công hoặc mở ứng dụng (`AuthSuccess` / `HomePage` mount), `SyncEngine` sẽ khởi động và thực hiện kéo toàn bộ dữ liệu mới nhất từ CSDL PostgreSQL Backend về SQLite local mà không cần chờ thao tác của người dùng.
2. **Chuẩn hóa Gói tin 2 Chiều (Payload Normalization & Unpacking):**
   * Bóc tách tầng dữ liệu lồng nhau `topData['data']['results']` và `topData['data']['data']` của `ResponseHandler` phía Backend.
   * Chuyển đổi linh hoạt giữa chuỗi `camelCase` phía Dart và `snake_case` phía Backend PostgreSQL.
   * Tự động chuẩn hóa chuỗi UUID 36 ký tự và mốc thời gian chuẩn UTC ISO 8601.
3. **Cô lập Dữ liệu Người dùng (Account Data Isolation):**
   * Tất cả câu lệnh truy vấn SQLite local (`WalletDao`, `TransactionDao`) được cô lập nghiêm ngặt theo `idaccount`.
   * Reset mốc thời gian checkpoint `_lastPullTime = null` khi Đăng xuất (`LogoutRequested`), đảm bảo chuyển đổi tài khoản an toàn 100%.
   * **Bổ sung 2026-09-08:** mốc pull nay còn được **lưu bền vững theo từng tài khoản** qua `SyncCheckpointStore` (`sync_engine.dart:253`), nên mở lại app không kéo lại từ đầu. Câu ở trên chỉ mô tả nhánh đăng xuất.

---

## 🔴 III. CÁC HẠNG MỤC / CHỨC NĂNG CHƯA TRIỂN KHAI SYNC

Dưới đây là các hạng mục nâng cao chưa hỗ trợ đồng bộ (hoặc chưa yêu cầu tích hợp trong phạm vi hiện tại):

| STT | Hạng mục chưa Sync | Mô tả chi tiết | Hướng nâng cấp trong tương lai (nếu cần) |
| :--- | :--- | :--- | :--- |
| **1** | **Tệp ảnh đính kèm Giao dịch**<br>`(Transaction Images)` | Cột `images` trong bảng giao dịch hiện lưu dưới dạng mảng chuỗi local. Chưa đồng bộ tệp nhị phân ảnh thật lên server. | Tích hợp dịch vụ lưu trữ tệp Cloud Storage (như Amazon S3, Cloudinary hoặc Firebase Storage) để upload & lưu URL ảnh. |
| **2** | **Đồng bộ Thông báo đẩy Realtime**<br>`(WebSocket / Push Notification)` | Việc đồng bộ hiện tại chạy qua REST API (Polling & Immediate Trigger). Chưa tự cập nhật giữa 2 thiết bị nếu cùng đăng nhập 1 tài khoản mà không reload. | ⚠️ **Backend ĐÃ CÓ Socket.io** (`socket.io ^4.8.3`, `src/Backend/core/socket.js` 171 dòng, nối ở `index.js:8`) nhưng chỉ phát `audit_activity`, `bank_transaction` và các sự kiện OCR — **không** có sự kiện kích hoạt sync. Phía client thì **chưa có gói socket nào cả** (`pubspec.yaml` không có `socket_io_client`). Việc còn lại vì thế là *nối client vào* + thêm một sự kiện sync ở server, không phải "tích hợp Socket.io" từ đầu. Đo 2026-09-08. ⚠️ **2026-09-11:** client có kênh Socket.io từ 2026-09-09 (`lib/core/realtime/`), và backend phát `sync.completed` sau mỗi `/sync/push` (`sync.service.js:223`) — nhưng client chưa nghe sự kiện ấy (**G34**); bắt tay socket từng từ chối mọi tài khoản (CAN-LAM 17 A) — ✅ hết 2026-09-12 sau gộp `cbbeeb4`, kênh nối được trên máy ảo. ✅ **2026-09-12 tối:** client nghe `sync.completed` (G34 đóng) — `RealtimeEvent.dongBoXong` → `syncNow()`, không toast; đo máy ảo hai máy cùng tài khoản, máy kia kéo về **cùng giây**. Dòng "chưa tự cập nhật giữa 2 thiết bị" ở cột trái **không còn đúng** khi cả hai máy đang nối socket. |
| **3** | **Chia sẻ Ví nhóm / Phân quyền**<br>`(Shared Wallets)` | Mỗi Ví hiện tại gắn cố định với 1 `idaccount` sở hữu duy nhất. Chưa hỗ trợ chia sẻ ví giữa nhiều tài khoản người dùng khác nhau. | Mở rộng schema backend bảng `wallet_member` để phân quyền xem/chỉnh sửa ví cho nhiều người dùng. |
| **4** | **Lịch sử Nhật ký Thay đổi Chi tiết**<br>`(Detailed Audit Logs Sync)` | Nhật ký thao tác người dùng (`auditlog`) hiện được ghi nhận tại server Backend. Chưa đồng bộ bảng audit log về SQLite local client. | Đã có sẵn trên CSDL PostgreSQL Backend, client chỉ truy vấn khi cần xem báo cáo bảo mật. |

---

## 🛠️ IV. NGUYÊN TẮC BẢO TRÌ VÀ PHÁT TRIỂN TIẾP THEO

1. **Tuân thủ phân định Client - Backend:**
   * Mọi điều chỉnh logic, chuẩn hóa định dạng và bóc tách gói tin phải được thực hiện hoàn toàn ở phía **Client-app** (`src/Client-app/lib/core/sync/sync_engine.dart`), tuyệt đối không can thiệp CSDL hoặc mã nguồn Backend.
2. **Trạng thái bản ghi (Sync Status):**
   * Các bản ghi tạo mới/chỉnh sửa tại SQLite local luôn bắt đầu với `syncStatus = 'pending'`.
   * Sau khi PUSH thành công tới Backend hoặc PULL từ Backend về, `syncStatus` bắt buộc được chuyển thành `'synced'`.
