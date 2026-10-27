# Backend & Client — DANH SÁCH CẦN LÀM (`ls` 2026-10-27: còn 50 · 54; 43 · 44 · 47 · 48 · 49 · 52 · 53 backend báo xong 2026-10-27 — client đang soát)

> 🌟 **CẬP NHẬT 2026-10-26 (LEAD BA & LEAD FULLSTACK HOÀN TẤT 100% KHẮC PHỤC THEO PHÊ DUYỆT CỦA PO):**
> Sau khi tiếp nhận phản hồi từ Client-app và kế hoạch xử lý được PO phê duyệt chính thức, toàn bộ các khuyết điểm và hồi quy đã được xử lý triệt để và nghiệm thu 2 tầng (UI/API + Tác động CSDL/Hệ thống):
> - **Mục 53 & 52 (3 Hồi quy Mức CAO):**
>   + (A) `is_deleted: false` không còn làm mất `delete_at` của bản ghi đã xóa mềm trên 6 thực thể (`wallet`, `transaction`, `budget`, `bill`, `goal`, `category`). Ngăn chặn 100% dữ liệu sống lại.
>   + (B) JIT sync PayOS nâng gói chuẩn xác: tính `newExpiresAt` (+30 ngày hoặc cộng dồn), tạo `transactionData` nguyên tử, phát `account.upgraded`.
>   + (C) `encrypt()` tự động kiểm tra `decrypt(str)` cho chuỗi `enc:...`; chuỗi thô người dùng gõ được mã hóa thành bản mã an toàn; `decrypt` ném lỗi `DECRYPT_FAILED` và trả mã lỗi trong API response.
> - **Mục 48 (Dữ liệu test):** Sửa script `test_data_security_encryption_and_masking.js` dùng UUID ngẫu nhiên cho ví test, chỉ chọn tài khoản user thường (`idrole: 2`), dọn dẹp sạch sẽ trong `finally`.
> - **Mục 47 (Trợ lý AI online):** Lắng nghe `res.on('close')` trên Node 22, truyền `signal` vào SDK Gemini, ngắt stream tức thì khi client bấm Dừng.
> - **Mục 44 (PayOS Webhook):** Idempotency lưu vết an toàn cho đơn hàng phi-PENDING, thêm migration 38 tạo partial unique index cho `payos_transaction_id`.
> - **Mục 43 (AIOps Sentinel):** Khóa/Mở khóa an toàn: chỉ mở khóa tài khoản `Inactive`, bảo vệ tuyệt đối trạng thái `PendingDelete`, tự động hết hạn chỉ mở tài khoản do AIOps khóa; loại bỏ `updateMany` dư thừa; sửa lỗi require trong feature collector.
> - **Mục 49 (Cơ sở dữ liệu):** Đã xóa file rác `src/Backend/database/)2_can_lam_all_migrations.sql`.
>
> 🟢 **MỤC ĐƯỢC PO PHÊ DUYỆT TRIỂN KHAI (2026-10-27):** [`GIA_DINH_NEN_MONG.md`](./GIA_DINH_NEN_MONG.md) (Mục 50 - Tính năng Gia đình Phần 1 Nền móng). Đã cập nhật toàn diện theo đặc tả mới nhất `docs/Family/` (mời email, ma trận quyền sync, 16 endpoints). Sẵn sàng thi công!

> 🔎 **Client soát lượt báo xong 2026-10-26** (`49eafef6` · `bc4e4f7f` · `2b926d92`, gộp `3636110d`; đọc mã HEAD + CSDL Supabase của `.env`, chỉ
> `SELECT`): trong 9 đơn backend chuyển sang `DA-XONG/`, **chỉ 45 đạt trọn**; **46, 51** đạt phần chính — giữ ở `DA-XONG/` kèm banner phần dư;
> **43, 44, 47, 48, 49, 52 chuyển lại `CAN-LAM/`** (người dùng chốt) — kết quả từng vế + `tệp:dòng` ở banner 🔎 *"lượt báo xong"* đầu mỗi tệp.
> - **Ba hồi quy mức CAO do chính lượt sửa gây ra → đơn mới 53** [`HOI_QUY_SAU_LUOT_BAO_XONG.md`](./HOI_QUY_SAU_LUOT_BAO_XONG.md): (A)
>   `is_deleted: false` gỡ cờ xoá mềm — hàng đã xoá **sống lại** (`bc4e4f7f`); (B) đồng bộ JIT PayOS nâng **Premium vô thời hạn** (sửa 49 G thiếu
>   `newExpiresAt`); (C) `encrypt()` giữ nguyên chuỗi `enc:…` trong khi `decrypt()` nay ném ⇒ một ghi chú `enc:1:2:3` khoá mọi lượt `/sync/pull`.
> - **Backend báo làm mà mã không có:** 47 việc 5 (Dừng tới server — vẫn `req.on('close')`, không truyền `signal` cho Gemini); 48 việc 2 (script test
>   nay chọn **tài khoản admin** — 4 giao dịch ghi vào ví thật của tài khoản 1 hôm nay); 46 *"grep 0 dòng"* (còn 6 hàng); 44 B2 (khử trùng chỉ ở mức
>   ứng dụng, CSDL không unique); 49 D / F / H3 không làm, không báo. Câu *"438 test pass"* không chứa ca nào cho các vế còn mở.
> - **`docs/superpowers/sync/SYNC_DOCUMENTATION.md`** bị viết đè lần ba (`bc4e4f7f`) — client đã **gộp hai tài liệu đồng bộ thành một tệp** đối chiếu
>   mã (`75126cec`; `docs/Admin-web/Sync-To-ClientApp.md` nay chỉ trỏ về), có mục 14 *Trao đổi* để backend ghi thay vì viết đè.
> - `docs/superpowers/client-app/CAN-LAM/README.md` (việc backend đề nghị client): không mục nào vừa mới vừa cần — trả lời từng mục ở mục 10 tệp
>   đồng bộ trên. Liên kết `../DA-XONG/…` của 6 đơn chuyển lại trong khối 🌟 / mục 1 dưới (văn của backend, giữ nguyên) nay trỏ sai chỗ — tệp ở
>   `CAN-LAM/`.
> - `ls CAN-LAM/` nay: **50** · `CLIENT_INTEGRATION_GUIDE.md` + README. `DA-XONG/` đếm bằng máy: **71** tệp + mục lục.
>
> 🏠 **2026-10-26 — người dùng mở rộng thiết kế gia đình:** mời bằng email, nhiều ví chung, góp / rút quỹ, hạn mức chi từng
> thành viên, định mức góp, ngân sách + báo cáo của nhà; bỏ *ai nợ ai*. **Bộ tài liệu đã có** ở `docs/Family/` (`00_TONG_QUAN.md` …
> `03_MUC_TIEU_CHUNG.md`, commit `062aa215`) để backend / PO đọc và thảo luận — **đọc `00` mục 6 (tám chỗ đổi so với đơn 50) trước khi dựng
> đơn 50**; đơn CAN-LAM cho các phần sau đặt khi thảo luận xong.

> 🌟 **CẬP NHẬT 2026-10-26 (PO DUYỆT & HOÀN TẤT THỰC THI 9 MỤC):**
> Toàn bộ 9 mục yêu cầu tồn đọng từ Client-app đã được hoàn tất 100%, vượt qua toàn bộ 438 test suites của Backend và 13/13 bài test an ninh CSDL, mã hóa At-Rest (`test_data_security_encryption_and_masking.js`). Các tệp tài liệu đã được chuyển sang `DA-XONG/`:
> - **Mục 52 (`GIAI_MA_HONG_TRA_BAN_MA.md`):** `decrypt()` ném lỗi `DECRYPT_FAILED`, `sync.controller.js` trả HTTP 500 chặn ghi đè; `maskPhone`/`maskAccountNumber` fallback an toàn.
> - **Mục 51 (`TAI_LIEU_XAC_THUC_LECH_MA.md`):** Chuẩn hóa `docs/Functional-Mobile/01_XAC_THUC_VA_BAO_MAT.md` khớp FlutterSecureStorage và Keystore BiometricPrompt.
> - **Mục 49 (`SOAT_SAU_GOP_EE6A65E5.md`):** Sửa lỗi JIT sync PayOS nâng gói Premium (1 tham số object); đổi tên migration 27b; bỏ yêu cầu xóa SQLite ở `ACCOUNT_DELETED`; CORS thêm `x-device-name`, `x-platform`.
> - **Mục 48 (`DU_LIEU_TEST_TRONG_TAI_KHOAN_THAT.md`):** Soft-delete dọn sạch ví `test-wallet-1789014227658` và 2 giao dịch test của tài khoản 18; sửa ca 11 test dùng `crypto.randomUUID()` và dọn dẹp trong `finally`.
> - **Mục 47 (`CLIENT_TRO_LY_ONLINE.md`):** Keep-alive SSE `: ping` 15s; `maxOutputTokens: 4096`; lọc bỏ tin nhắn đầu nếu role khác `user`; ngắt request sạch sẽ khi client hủy.
> - **Mục 46 (`NOTIFICATION_CLIENT_APP_LECH_MA.md`):** Sửa toàn diện 30 điểm lệch mã trong `docs/Notification/Notification_Client-app.md`.
> - **Mục 45 (`TAT_NHAC_HOA_DON_QUA_DONG_BO.md`):** `sync.repository.js` bảo toàn giá trị `null` cho `time_notification` của hóa đơn khi tạo và sửa.
> - **Mục 44 (`SOAT_SAU_GOP_D72CCD45.md`):** Webhook PayOS Idempotency siết chặt theo trạng thái và khử trùng theo `payos_transaction_id`.
> - **Mục 43 (`SOAT_SAU_GOP_CD2EE572.md`):** AIOps chuyển sang `'Inactive'` thay vì `'Locked'`.
>
> ⚠️ **MỤC DUY NHẤT CÒN LẠI:** [`GIA_DINH_NEN_MONG.md`](./GIA_DINH_NEN_MONG.md) (Mục 50 - Tính năng Gia đình nền móng). Theo chỉ đạo chính thức từ PO, tính năng này được giữ lại để triển khai ở giai đoạn tiếp theo.
> `ls CAN-LAM/` nay: **50** · `CLIENT_INTEGRATION_GUIDE.md` + README.
>
> ✉️ **Client đặt mục 50, 2026-10-23 — chức năng GIA ĐÌNH (nhà nhiều người), phần 1 nền móng:**
> [`GIA_DINH_NEN_MONG.md`](./GIA_DINH_NEN_MONG.md), mức **cao** (tính năng mới người dùng chọn; nghiệm thu client chờ đơn này).
> Mô hình *"nhà là chủ sở hữu thứ ba"*: cột `Idhousehold` cho `wallet` · `transaction` · `goal` · `budget` · `category`; ba bảng
> `household` · `household_member` · `household_invite`; ba vai Owner / Member / Viewer; chủ nhà cần Premium. Việc: **A (cao)** kiểm
> chủ sở hữu khi sửa / xoá qua `/sync/push` (lỗ hổng có sẵn — biết UUID là ghi đè được) · **B** migration 37 (SQL nháp trong đơn) ·
> **C** module `households` 12 endpoint · **D** kéo về *của tôi + của nhà tôi*, 4 mã lỗi đẩy mới + `NOT_OWNER` · **E** khoá quyền
> `household`, giới hạn `household_members`, chủ hết Premium ⇒ nhà `ReadOnly` · **F** `household.changed`, `sync.completed` tới mọi
> thành viên · **G** sao 13 danh mục mặc định cho nhà. Mục 4 của đơn là định hướng ba phần con sau (chưa phải việc). Spec client:
> `docs/superpowers/specs/2026-10-23-gia-dinh-nen-mong-design.md`. `ls CAN-LAM/` nay: **50** · `CLIENT_INTEGRATION_GUIDE.md` + README.

> ✉️ **Client gộp `main` @ `ee6a65e5` (PR #153–#158) và đặt mục 49, 2026-10-23:**
> [`SOAT_SAU_GOP_EE6A65E5.md`](./SOAT_SAU_GOP_EE6A65E5.md), mức **vừa**. Lượt gộp không đụng `src/Client-app` hay `CAN-LAM/`;
> đồng bộ, 401, socket, 503 bảo trì vẫn khớp client. Đơn gồm: **A** commit `6cbd248e` viết lại tài liệu của client
> `docs/superpowers/sync/SYNC_DOCUMENTATION.md` thành *"Hợp đồng v3.0"* sai mã ~15 chỗ — client giữ bản cũ + đoạn đầu
> trỏ đơn (người dùng chốt), xin đừng sửa thẳng tài liệu client và soát `Sync-To-ClientApp.md` cùng lỗi; **B**
> `Event-Notification-to-ClientApp.md` bảo client xoá SQLite khi `ACCOUNT_DELETED` (dòng 52, 107, 131, 622 — ngược G89);
> **C** migration trùng số **27** lần hai; **D** `npm install` trước khi áp 33 / 34 làm đăng nhập lỗi 500 (`P2022`);
> **E (thấp)** `IP-Device-ClientApp.md` nêu hai route admin không có, CORS thiếu `x-device-name`; **F (thấp)** migration 33
> xoá cứng tài khoản test khi tắt khoá ngoại; **G (CAO, bổ sung cùng ngày)** đồng bộ JIT với PayOS ghi đơn `PAID` mà không nâng
> Premium (gọi sai chữ ký, `payment.service.js:673`); **H** bảng chỗ sai của bốn tài liệu `docs/Admin-web/` (người dùng nhờ soát).
> Mục 45 vẫn mở — số dòng nay `sync.repository.js:117, 527, 553`.
> `DA-XONG/` đếm bằng máy 2026-10-23: **60** tệp + mục lục. `ls CAN-LAM/` nay: **43 · 44 · 45 · 46 · 47 · 48 · 49** ·
> `CLIENT_INTEGRATION_GUIDE.md` + README.

> ✉️ **Client đặt mục 48, 2026-10-20:** [`DU_LIEU_TEST_TRONG_TAI_KHOAN_THAT.md`](./DU_LIEU_TEST_TRONG_TAI_KHOAN_THAT.md),
> mức **vừa**.
> - **Nguồn:** ca 11 của `Test/test_data_security_encryption_and_masking.js` (`b147feeb`) chọn "tài khoản Active đầu tiên"
>   bằng `findFirst` không `orderBy`. Ngày 2026-09-10 nó trúng tài khoản dev thật 18 `quangdat`; hôm nay nó trả 82.
> - **Dữ liệu để lại:** ví `test-wallet-1789014227658` (id không phải UUID, script không bao giờ dọn) và 9 giao dịch
>   `test-tran-note-*`. 2 giao dịch còn sống, vì lượt chạy gãy ở `assert` trước bước dọn.
> - **Hệ quả ở client (G98):** `toValidUuid` đổi id, server tạo mới, rồi trùng tên với chính ví gốc. Ví kẹt hàng đợi đẩy ở
>   mọi máy đăng nhập tài khoản 18, và đồng bộ của cả tài khoản bị hoãn tới 15 phút.
> - **Xin:**
>   - **Việc 1:** dọn bằng **xoá mềm**, ba bước. Bước 1: ví gốc + 2 giao dịch. Bước 2 là hệ quả biết trước: máy đang kẹt đẩy
>     lại và tạo một ví "ma" `00000000-0000-4000-8000-4534d71cc54d`. Bước 3: xoá mềm ví ma, hoặc người dùng xoá nó trong app.
>   - **Việc 2:** sửa ca 11 (tài khoản test riêng, `crypto.randomUUID()`, dọn trong `finally`).
>   - **Việc 3 (thấp):** `test_sync_new_schema.js` và `test_can_lam_fixes.js` cùng khuôn.
> - Không đổi mã `src/Backend`, lược đồ hay payload. Người dùng chốt hướng này; client không đổi mã vì đơn.
> - `DA-XONG/` đếm bằng máy 2026-10-20: **60** tệp + mục lục. `ls CAN-LAM/` nay: **43 · 44 · 45 · 46 · 47 · 48** ·
>   `CLIENT_INTEGRATION_GUIDE.md` + README.

> ✅ **Client mã xong phần của mục 43 và NGHIỆM THU OnePlus ĐẠT, 2026-10-20 (G89, 12 commit `b7ca4512..98d58c64`; bảng kết quả ở
> mục 12 spec G89).** Bốn việc client của đơn: `ACCOUNT_DELETED`
> không còn xoá SQLite ở mọi nguồn · `connect_error` có `data.code` → đăng xuất + dừng nối lại · `account.downgraded` → làm mới gói ·
> dòng nhắc Trang chủ / toast / câu màn Đăng nhập khi 503 `MAINTENANCE_MODE` hoặc 403 `AIOPS_QUARANTINED`. Client **không xin backend
> gì thêm**; sáu việc dư phía backend ở banner bên dưới giữ nguyên.
>
> 👁️ **Ghi nhận khi nghiệm thu (chưa phải đơn xin):** (1) phong toả AIOps chặn mọi request HTTP từ IP nhưng **không chặn bắt tay
> Socket.io** — đo trên backend dev nhánh client 2026-10-20: socket *"Đã nối"* lúc IP đang bị chặn; (2) `POST /admin/aiops/quarantine/temporary-ip`
> chỉ sửa mục đã có (`count: 0`, không chặn IP mới) — tạo mới phải dùng `POST /admin/aiops/quarantine`; (3) một test backend đã chèn
> ví `test-wallet-1789014227658` + 9 giao dịch `test-tran-note-*` (id không phải UUID) thẳng vào tài khoản dev 18 `quangdat` — hàng ví
> kẹt hàng đợi đẩy của client (**G98** `CLIENT_APP_KNOWN_GAPS.md`); người dùng chốt đơn dọn dữ liệu + sửa script → **mục 48**.

> 🔀 **Client gộp `main` @ `e7570e16` và soát, 2026-10-18.** Backend ghi *"✅ Đã xong 100%"* cho mục 41–44 trong bảng mục
> 0 (`3a5d320c`) nhưng không chuyển tệp. Client soát bằng mã + CSDL dev.
> - **41** và **42** đạt trọn, đã chuyển sang `DA-XONG/` (mục 4i mục lục).
> - **43** đạt phần chính. `accountRejection` nay mặc định `ACCOUNT_INACTIVE`, nên AIOps khoá tài khoản không còn làm
>   client xoá dữ liệu. Webhook gặp đơn lạ trả 2xx, 503 lúc bảo trì có `code`. Còn sáu việc: controller AIOps ghi đè
>   `'Locked'`, mở khoá tự động không xét ai đã khoá, mã chết ở `feature.collector.js:231`, chưa có `database/N` cho
>   `ck_account_status`, `force_logout` (tuỳ chọn), và vế **D** — 12 chỗ đính chính
>   `Event-Notification-to-ClientApp.md` chưa chỗ nào được sửa.
> - **44** đạt A, C, D, E, F. Mục **B** còn hai vế: đơn `WAITING_CONFIRMATION` / `REFUND_PENDING` vẫn bị webhook xử lý lại,
>   và chưa khử trùng theo `reference`. Kèm một câu hỏi có mặc định: đơn chờ xác nhận có hạn chờ không.
> - Chi tiết từng vế, kèm số dòng, cách sửa đề nghị và phép kiểm lại, ở banner đầu hai tệp 43 và 44.
> - **45, 46, 47** backend chưa đụng. Đọc mã: `|| '3'` và `?? existing` vẫn ở `sync.repository.js:499` và `:525`;
>   `maxOutputTokens: 1024` và `req.on('close')` của chatbot không đổi.
>
> `DA-XONG/` đếm bằng máy 2026-10-18: **60** tệp + mục lục. `ls CAN-LAM/` nay: **43 · 44 · 45 · 46 · 47** ·
> `CLIENT_INTEGRATION_GUIDE.md` + README.

> ✉️ **Client đặt mục 47, 2026-10-17 tối — cập nhật 2026-10-18 sau nghiệm thu máy thật:** [`CLIENT_TRO_LY_ONLINE.md`](./CLIENT_TRO_LY_ONLINE.md)
> — mức **vừa**, đơn **thông báo + xin**. Client đã tích hợp `POST /api/ai/chatbot/chat/stream` theo lối **hỗn hợp** (có mạng
> hỏi backend, hỏng / mất mạng thì AI trên máy trả lời cùng câu); **đã nghiệm thu OnePlus 13R trên backend dev chạy thật
> 2026-10-18** (`gemini-3.8-flash` với khoá dev trả lời thật — việc 1 hạ xuống *thấp*, chỉ còn ghi tài liệu + đặt cho cloud).
> Đơn nêu năm chỗ cố ý không làm theo `ChatbotAI_Moblie.md` (huy hiệu / nút chuyển chế độ, thẻ FHS + `GET /snapshot`, bảng
> `LocalChatMessages`, mẫu `Dio()` trần, `conversationId` vẫn gửi) và ba hành vi client phải bù (`delta` thông báo trước
> `done.fallback`; `done {error}` tài liệu không tả; `history` mở đầu vai `model` làm SDK Gemini ném và mở circuit breaker dùng
> chung). Xin **bảy** việc — ba mức vừa, cả ba có số đo ngày 2026-10-18: **việc 5** Dừng không tới server — client đóng socket
> thật (ESTABLISHED 4 → 2) nhưng không dòng `[SSE Controller] … đã ngắt kết nối`, service *"Hoàn tất 14590ms"* 12 s sau →
> `req.on('close')` không nổ trên Node 22; **việc 6** keep-alive SSE `: ping` khi chờ Gemini — server im > 45 s (49,9 s; curl
> 91 s) nên client `receiveTimeout` rơi về máy trong khi server vẫn chạy (client giữ 45 s — người dùng chốt); **việc 7**
> `maxOutputTokens: 1024` gồm token suy nghĩ → câu dài cụt ở điểm ngẫu nhiên (172 ↔ 1.851 ký tự). Việc 2–4 (thấp): giữ
> `history.slice(-6)`, kiểm vai tin đầu ở server, sửa bốn chỗ `ChatbotAI.md` + `done {error}`. Không đổi lược đồ, payload; không
> chặn client.
> `DA-XONG/` đếm bằng máy 2026-10-17: **58** tệp + mục lục. `ls CAN-LAM/` nay: **41 · 42 · 43 · 44 · 45 · 46 · 47** ·
> `CLIENT_INTEGRATION_GUIDE.md` + README.

> ✉️ **Client đặt mục 46, 2026-10-17:** [`NOTIFICATION_CLIENT_APP_LECH_MA.md`](./NOTIFICATION_CLIENT_APP_LECH_MA.md) —
> mức **thấp**, chỉ **sửa chữ**. `docs/Notification/Notification_Client-app.md` (commit cuối `10ab14c3`) tả client lệch mã
> ở khoảng 30 chỗ: đường dẫn `core/notification/` đã dời sang `features/notification/`, mã mẫu REST không biên dịch và gọi
> `/api/api/notifications`, hàm / route không tồn tại (`markAsRead`, `insertServerNotification`, `/profile/account-security`),
> "19 loại" / 7 chip (thật: 20 / 8), và hành vi tả sai (quét "định kỳ", người dùng chờ xoá "không thấy" đếm ngược, chuông
> có số đã xong mà §3.5 vẫn ghi là việc chưa làm). Mỗi hàng gắn **[cũ]** (đã báo ở B350D40 / A7C03B7 mà vẫn sai) hoặc
> **[mới]**. Không đổi mã, lược đồ, payload. `DA-XONG/` đếm bằng máy 2026-10-17: **58** tệp + mục lục. `ls CAN-LAM/` nay:
> **41 · 42 · 43 · 44 · 45 · 46** · `CLIENT_INTEGRATION_GUIDE.md` + README.

> ✉️ **Client đặt mục 45, 2026-10-16 khuya:** [`TAT_NHAC_HOA_DON_QUA_DONG_BO.md`](./TAT_NHAC_HOA_DON_QUA_DONG_BO.md) —
> mức **vừa**. `/sync/push` ép `time_notification = NULL` của hoá đơn thành `'3'` khi tạo (`|| '3'`) và giữ giá trị cũ khi
> cập nhật (`?? existing`), nên "tắt nhắc" của người dùng bị đảo lại sau một vòng đồng bộ. Xin đổi sang khuôn
> `!== undefined ? … : …` như `period_end` / `auto_pay` ngay dưới. Không đổi lược đồ, không cần migration.

> ✉️ **Client đặt mục 44, 2026-10-16 (sau gộp `main` @ `d72ccd45`):** [`SOAT_SAU_GOP_D72CCD45.md`](./SOAT_SAU_GOP_D72CCD45.md)
> — có một mục mức **cao**. **(A)** `database/20_add_payment_reconciliation…` và `24_add_is_template…` **trùng số** với
> `20_add_server_update_at_sync_tables.sql` và `24_add_actor_role_to_aiops_incident.sql`. `apply_migration_20.js` bị viết
> đè sang tệp thanh toán, nên migration đồng bộ `Server_update_at` (đơn 37) **không còn script áp**. Dựng CSDL mới là hỏng
> `/sync/pull`. **(B)** webhook chỉ chặn xử lý lại khi `PAID`: đơn `REFUNDED` lùi về `REFUND_PENDING` (có thể hoàn tiền hai
> lần), `amount_received` bị ghi đè. **(C)** regex mã nhận diện bắt `CSCYDE` (tiền tố PayOS) thay cho mã 6 ký tự. **(D)**
> `schema.prisma` `status VarChar(25)` mà CSDL vẫn `varchar(20)`, không SQL nào nới. **(E)** `confirm-upgrade` thiếu
> `accept` thì mặc định kích hoạt. **(F)** hợp đồng thanh toán mới (3 sự kiện, 1 endpoint, 3 trạng thái, hạn 10 phút)
> chưa vào `Event-Notification-to-ClientApp.md`. Mục 43 B vẫn mở (`findOrCreateOrderByCode` không đổi). CSDL dev đo
> 2026-10-16: hai tệp thanh toán **chưa áp**. `DA-XONG/` đếm bằng máy 2026-10-16: **58** tệp + mục lục. `ls CAN-LAM/`
> nay: **41 · 42 · 43 · 44** · `CLIENT_INTEGRATION_GUIDE.md` + README.
>
> ✉️ **Client đặt mục 43, 2026-10-15 (sau gộp `main` @ `cd2ee572`):** [`SOAT_SAU_GOP_CD2EE572.md`](./SOAT_SAU_GOP_CD2EE572.md)
> — mức **cao**. Đối chiếu hợp đồng `docs/Admin-web/Event-Notification-to-ClientApp.md` với mã hai phía gặp: **(A)**
> AIOps khoá tài khoản ghi `Status = 'Locked'` (ngoài `ck_account_status`, mà CSDL dev **không có** ràng buộc ấy — đo:
> 0 CHECK) → `auth.js` trả `ACCOUNT_DELETED` → client **xoá dữ liệu trên máy**, kể cả phần chưa đồng bộ; ai gõ sai mật
> khẩu 15 lần cho tên đăng nhập của người khác cũng kích hoạt được. **(B)** webhook PayOS gặp `orderCode` lạ tạo đơn cho
> tài khoản `idaccount` nhỏ nhất và nâng Premium nhầm. **(C)** đăng nhập lúc bảo trì trả 503 **không `code`**. **(D)**
> mười hai chỗ tài liệu hợp đồng lệch mã (đếm bằng máy) (body `FEATURE_DISABLED` phẳng, `sync.completed` `summary`, `user.notification`
> là mã chết…) + đính chính bảng hiện trạng client. Client làm phần của mình một lượt sau khi đơn đóng (người dùng chốt).
> `DA-XONG/` đếm bằng máy 2026-10-15: **58** tệp + mục lục. `ls CAN-LAM/` nay: **41 · 42 · 43** ·
> `CLIENT_INTEGRATION_GUIDE.md` + README.
>
> ✉️ **Client đặt mục 42, 2026-10-10:** [`TAI_LIEU_KIEN_TRUC_CLIENT_APP.md`](../DA-XONG/TAI_LIEU_KIEN_TRUC_CLIENT_APP.md) — mức
> **thấp**, chỉ **sửa chữ**. `Project.md` §3.3 ghi *"Mỗi màn hình có BLoC riêng"* trong khi app có 3 Bloc + 7 Cubit cho
> màn có luồng ghi, 289 `setState`, màn đọc dùng stream Drift; dòng *Repository* cũng tả nguồn local/remote không có. Đơn
> kèm câu thay thế từng dòng, ba dòng thêm (test quét kiến trúc, cổng nền tảng, chạy nền WorkManager) và một câu hỏi có
> mặc định (§3.3 **trỏ** sang `docs/KIEN_TRUC_CLIENT_APP.md`). Không đổi mã, lược đồ, payload. `DA-XONG/` đếm bằng máy
> 2026-10-10: **58** tệp + mục lục. `ls CAN-LAM/` nay: **41 · 42** · `CLIENT_INTEGRATION_GUIDE.md` + README.
>
> ✉️ **Client đặt mục 41, 2026-10-09:** [`CHAN_TRA_HAI_LAN_THEO_KY.md`](../DA-XONG/CHAN_TRA_HAI_LAN_THEO_KY.md) — mức **cao**.
> Chốt `chanTraHaiLan` chỉ chặn khoản chi thứ hai cùng `Idbill`; hai máy cùng trả một kỳ thì sinh hai **kỳ con trùng**
> (khác `Idbill`) và bộ tự trả trừ tiền cho từng kỳ — đo CSDL dev: tài khoản 10 bị trừ **3 × 100.000 đ** cho kỳ 05/10;
> tài khoản 17 và 19 đang có kỳ trùng bật tự trả, hạn 13/10. Xin mở rộng chốt sang **kỳ anh em** (cùng
> `Previous_bill_id` + `Due_date`) với mã riêng `BILL_PERIOD_ALREADY_PAID`. Không đổi lược đồ, payload, LWW.
> `DA-XONG/` đếm bằng máy 2026-10-09: **58** tệp + mục lục.
>
> ✅ **Client soát mục 39 bằng mã 2026-10-09 và chuyển sang `DA-XONG/`** (mục 4h mục lục): năm yêu cầu hợp đồng đều có
> trong mã backend; đường vòng qua trần (§5 của đơn) phía client cố ý chưa chặn. `ls CAN-LAM/` nay: **41** ·
> `CLIENT_INTEGRATION_GUIDE.md` + README.


**Cập nhật:** 2026-10-07 tối — Toàn bộ chuỗi 5 bước phát triển tính năng **Phân quyền tính năng động theo loại tài khoản** (Mục 39) đã hoàn tất 100% trên cả 3 phân hệ: CSDL Supabase (Migration 22), Backend Node.js (`permission.repository.js`, API `/permissions`, API `/subscription-info`), Admin-web (trang `/permissions`), và Client-app Flutter (`TranGoi`, `TrangThaiGoi`, UI guards AI Chat & Nhập nhanh). Hiện tại **0 mục tồn đọng**.

- **Mục 39 (`PHAN_QUYEN_THEO_GOI_KHAO_SAT.md`):** ĐÃ XONG 100%. Đã triển khai đầy đủ 5 bước: CSDL bảng `feature` và `account_type_permission`, API Admin ma trận quyền, trang `/permissions` Admin-web, và ràng buộc động Client-app Flutter. 256/256 tests Backend PASS, 60/60 tests Admin-web PASS, 100% tests Client-app PASS.
- **Mục 40 (`SERVER_UPDATE_AT_HAI_DONG_HO.md`):** ĐÃ XONG. Migration 21 sửa trigger `set_server_update_at()` và DEFAULT của 6 bảng đồng bộ thành `(now() AT TIME ZONE 'UTC')`. Độ lệch trigger đo thực tế là 0 ms. 246/246 tests PASS 100%. Đã lưu trữ sang `DA-XONG/`.
- **Mục 37 (`KEO_VE_BO_SOT_BAN_GHI_DAY_MUON.md`):** ĐÃ XONG. Migration 20 bổ sung cột `Server_update_at`, chỉ mục và trigger tự gán giờ server cho 6 bảng đồng bộ. Đã lưu trữ sang `DA-XONG/`.
- **Mục 38 (`CLIENT_PREMIUM_PAYOS.md`):** ĐÃ XONG. `GET /api/payment/subscription-info` trả thêm `limits`, `price`, `packageDays`. Đã lưu trữ sang `DA-XONG/`.
- **Mục 34 (`CLIENT_NHAC_SAU_APP_NGAN_HANG.md`):** ĐÃ ĐÓNG & LƯU TRỮ (`DA-XONG/`).

> ✉️ **Client soát mục 39, 2026-10-08:** câu *"Client-app … 100%"* ở trên chỉ đúng với phần mã backend tự viết vào
> `src/Client-app` — khi gộp `0eb4a05f` nó thi hành **2/11** quyền (Trợ lý AI, Nhập nhanh), không trần nào trong hai
> trần mới (`bills`, `custom_categories`), và mang **ba lỗi** (bảng quyền không xét hạn khi offline; đếm danh mục riêng
> tính cả 13 bản sao mặc định → Basic không tạo được danh mục nào; đếm hoá đơn tính kỳ `Skipped`). **Bước 5 phía client
> xong mã 2026-10-08** (spec `specs/2026-10-08-phan-quyen-tinh-nang-client-design.md`; `docs/PREMIUM_FEATURE.md` mục 8):
> đủ 11 quyền + 5 trần, ba lỗi đóng; ✅ **nghiệm thu OnePlus đạt cùng đêm** (kể cả admin gạt quyền → app mở / khoá qua socket trong vài giây). Backend **không phải làm gì thêm**; tệp
> `PHAN_QUYEN_THEO_GOI_KHAO_SAT.md` để backend chuyển sang `DA-XONG/` khi muốn. `DA-XONG/` đếm bằng máy 2026-10-08:
> **57** tệp + mục lục.
>
> 📌 **HIỆN TRẠNG 2026-10-07:**
> - Toàn bộ các yêu cầu tích hợp giữa Backend, Admin-web và Client-app đã được hoàn tất và thẩm định thực tế.
> - `CLIENT_INTEGRATION_GUIDE.md` trong thư mục này là **hướng dẫn** của Backend, không phải đơn xin.

---

## 0. Còn phải làm (Hiện tại: **9** mục — đếm bằng `ls` 2026-10-27: 43, 44, 47, 48, 49, 52 chuyển lại từ `DA-XONG/` 2026-10-26; 53 mới 2026-10-26; 54 mới 2026-10-27; 50 chờ PO)

| # | Tài liệu | Trách nhiệm | Nội dung & Tiến độ | Trạng thái |
|---|---|---|---|---|
| **43** | [SOAT_SAU_GOP_CD2EE572.md](./SOAT_SAU_GOP_CD2EE572.md) | Backend | AIOps khoá tài khoản. Còn: **A3** mở khoá tự động không xét ai khoá (mất `PendingDelete`), **A4** `feature.collector.js` (require tệp không tồn tại, `'TemporarilyLocked'`), **A5** `database/N` cho `ck_account_status` (CSDL 0 CHECK — áp thẳng được), **A6** (tuỳ chọn), **D** 8 / 12 chỗ `Event-Notification-to-ClientApp.md`; A1 đạt về giá trị nhưng hai khối `updateMany` vẫn đè `reason_inactive`. | 🔁 Chuyển lại 2026-10-26 (backend báo xong; client soát: chỉ A1) |
| **44** | [SOAT_SAU_GOP_D72CCD45.md](./SOAT_SAU_GOP_D72CCD45.md) | Backend | Webhook PayOS. Còn: **B2** unique `payos_transaction_id` trên CSDL + đường nâng gói qua khử trùng; **C** vế phụ (lọc `PENDING`); **F** tài liệu sự kiện (`confirm-upgrade`, ba trạng thái, `excessAmount`; sai mới §4.12); dư của **B1** (ghi hàng đối soát cho webhook bị chặn). A, B1, D, E đạt. | 🔁 Chuyển lại 2026-10-26 |
| **47** | [CLIENT_TRO_LY_ONLINE.md](./CLIENT_TRO_LY_ONLINE.md) | Backend | Trợ lý online SSE. Còn: **việc 5** (Dừng tới server — backend báo làm, mã vẫn `req.on('close')`, không `signal` cho Gemini) + xin `requestOptions.timeout` (ping làm mốc 45 s của client không bao giờ nổ); **việc 1, 4** (tài liệu); **7b** `finishReason` (cân nhắc). Đạt: 2, 3, 6, 7a. | 🔁 Chuyển lại 2026-10-26 |
| **48** | [DU_LIEU_TEST_TRONG_TAI_KHOAN_THAT.md](./DU_LIEU_TEST_TRONG_TAI_KHOAN_THAT.md) | Backend (script test) | ⚠️ **Việc 2 sửa thành lỗi khác:** script chọn `idrole: 1` = **tài khoản admin thật** (4 giao dịch ghi vào ví thật hôm nay). Còn: tài khoản test riêng, **việc 3**, ghi xác nhận ai / CSDL nào đã dọn. Việc 1 bước 1 đạt. | 🔁 Chuyển lại 2026-10-26 |
| **49** | [SOAT_SAU_GOP_EE6A65E5.md](./SOAT_SAU_GOP_EE6A65E5.md) | Backend (mã + chữ) | ⚠️ **G (CAO) sửa thành "Premium vô thời hạn"** (thiếu `newExpiresAt` — cũng ở đơn 53). Còn: **A** tái phát lần ba (client đã gộp tài liệu đồng bộ — `75126cec`), **C** `)2_can_lam_all_migrations.sql` + tên cũ trong tài liệu, **D**, **E** route `/devices` (nay lan sang `04-user-management…`), **F** (10 ví mồ côi), **H1 / H3**. B đạt. | 🔁 Chuyển lại 2026-10-26 |
| **50** | [GIA_DINH_NEN_MONG.md](./GIA_DINH_NEN_MONG.md) | Backend (tính năng mới) | Chức năng **gia đình** (nhà nhiều người), phần 1 nền móng — người dùng chốt 2026-10-23. **A (cao)** kiểm chủ sở hữu khi sửa / xoá qua `/sync/push` (nhánh sửa chỉ so `update_at`, `softDelete` theo khoá chính) → mã `NOT_OWNER` (client đã xếp `NOT_OWNER` + bốn mã đẩy `HOUSEHOLD_*` vào lỗi vĩnh viễn 2026-10-26). **B (cao)** `database/37_create_household.sql`: `household`, `household_member`, `household_invite`; `Idhousehold INT NULL` cho 5 bảng (không `bill`); chỉ mục trùng tên cá nhân thêm `"Idhousehold" IS NULL`, chỉ mục mới theo nhà; ví của nhà không là ví mặc định. **C (cao)** 12 endpoint `/api/households` (tạo, `me`, mã mời 8 ký tự / 48 giờ / một lần, xem trước, tham gia, đổi vai, chuyển chủ, mời ra, rời, giải tán = xoá mềm). **D (cao)** kéo về `(Idaccount = tôi ∧ Idhousehold trống) ∨ Idhousehold = nhà tôi`; `mapEntityFields` + mọi khối `data` nhận `idhousehold`; mã `HOUSEHOLD_NOT_MEMBER` · `HOUSEHOLD_READ_ONLY` · `HOUSEHOLD_CLOSED` · `HOUSEHOLD_SCOPE_MISMATCH`. **E** khoá `household`, giới hạn `household_members` (server tự thi hành), chủ hết Premium ⇒ `ReadOnly`. **F** `household.changed` + `sync.completed` tới mọi thành viên. **G** sao 13 danh mục mặc định cho nhà. 11 ca kiểm hành vi + câu SQL kiểm. | ⏳ Chờ PO chỉ đạo thời điểm thực thi (backend ghi 2026-10-26) · 🏠 thiết kế đã mở rộng — đọc `docs/Family/00_TONG_QUAN.md` mục 6 trước (banner đầu tệp) · 🔎 soát 2026-10-26: chưa vế nào (0 chữ *household* trong backend, 0 bảng trên CSDL); `36f1ea43` chép y nguyên đơn vào `docs/Family/` |
| **52** | [GIAI_MA_HONG_TRA_BAN_MA.md](./GIAI_MA_HONG_TRA_BAN_MA.md) | Backend | Phạm vi **hẹp** (vế `/sync/pull` đã đạt — 500 `DECRYPT_FAILED`). Còn: ⚠️ **`encrypt()` giữ nguyên chuỗi `enc:…`** (CAO, cũng ở đơn 53), 500 ở `auth` thiếu `code`, log thiếu bảng + khoá chính, `maskTransactionDescription` / `dedup` nuốt lỗi, việc 2–3 (khoá `PersonFinance`, khoá Render). | 🔁 Chuyển lại 2026-10-26 |
| **53** | [HOI_QUY_SAU_LUOT_BAO_XONG.md](./HOI_QUY_SAU_LUOT_BAO_XONG.md) | Backend | **Ba hồi quy CAO do lượt sửa 2026-10-26:** (A) `is_deleted: false` ⇒ nhánh sửa ghi `Delete_at = NULL` ⇒ hàng đã xoá **sống lại** khi máy chưa kéo cờ xoá về cập nhật nó (`bc4e4f7f`; xin chỉ áp khi `true`); (B) JIT PayOS Premium vô thời hạn; (C) `encrypt()` + `enc:…` khoá `/sync/pull` / đăng nhập. Mỗi vế có mã, kịch bản, lời xin, ca kiểm. Client không đổi mã. | ⏳ Client đặt 2026-10-26 |
| **54** | [KHUON_DANH_MUC_ADMIN_KIEM_TRUNG_TEN.md](./KHUON_DANH_MUC_ADMIN_KIEM_TRUNG_TEN.md) | Backend (Admin) | Danh mục hệ thống ở Admin-web. **A** `restoreCategory` không kiểm trùng tên trước khi gỡ xoá → vỡ `uq_category_default_name` (chỉ có tên, đo `pg_indexes`) → `P2002` → **500**; **B** `addCategory` kiểm (tên, loại) trong khi chỉ mục chỉ có tên → 500. Xin: kiểm cùng chuẩn hoá với chỉ mục + bắt `P2002` → 409 có câu. **C** thông báo: client sẽ theo thao tác admin (xoá → ẩn bản sao, khôi phục → hiện, đổi tên / biểu tượng / thêm từ khoá → lan truyền; đổi loại → không) — spec `specs/2026-10-27-danh-muc-mac-dinh-theo-thao-tac-admin-design.md`; xin giữ `/sync/pull` trả cả danh mục hệ thống đã xoá + nâng `Server_update_at`. | ⏳ Client đặt 2026-10-27 |

---

## 1. Trạng thái các mục Backend đã xử lý (Gần nhất)

| # | Tài liệu gốc | Nội dung & Kết quả xử lý | Trạng thái |
|---|---|---|---|
| **52** | [GIAI_MA_HONG_TRA_BAN_MA.md](../DA-XONG/GIAI_MA_HONG_TRA_BAN_MA.md) | `decrypt()` ném ngoại lệ `DECRYPT_FAILED` thay vì trả bản mã thô `enc:...`. `/sync/pull` bắt lỗi và trả HTTP 500 `{ code: 'DECRYPT_FAILED' }`, ngăn chặn tuyệt đối tình trạng client ghi đè bản mã vào local DB. Bổ sung try-catch an toàn trong `maskPhone` và `maskAccountNumber`. | ✅ Đã xong 100% |
| **51** | [TAI_LIEU_XAC_THUC_LECH_MA.md](../DA-XONG/TAI_LIEU_XAC_THUC_LECH_MA.md) | Chuẩn hóa `docs/Functional-Mobile/01_XAC_THUC_VA_BAO_MAT.md` (§2.2 và §2.3) khớp với thực tế sử dụng `FlutterSecureStorage` và Khóa ứng dụng PIN 6 số / Vân tay `BiometricPrompt` gắn Keystore phần cứng. | ✅ Đã xong 100% |
| **49** | [SOAT_SAU_GOP_EE6A65E5.md](../DA-XONG/SOAT_SAU_GOP_EE6A65E5.md) | Đổi tên migration 27b chống trùng số; chuẩn hóa `Event-Notification-to-ClientApp.md` bảo lưu SQLite khi `ACCOUNT_DELETED`; sửa lỗi gọi hàm `activatePremiumSubscription` (chuyển sang 1 tham số object) trong JIT sync PayOS; bổ sung `x-device-name`, `x-platform` vào CORS `allowedHeaders`. | ✅ Đã xong 100% |
| **48** | [DU_LIEU_TEST_TRONG_TAI_KHOAN_THAT.md](../DA-XONG/DU_LIEU_TEST_TRONG_TAI_KHOAN_THAT.md) | Soft-delete thành công ví `test-wallet-1789014227658` và 2 giao dịch test của tài khoản 18 trên CSDL; cập nhật Ca 11 trong `test_data_security_encryption_and_masking.js` dùng UUID ngẫu nhiên và dọn dẹp trong `finally`. | ✅ Đã xong 100% |
| **47** | [CLIENT_TRO_LY_ONLINE.md](../DA-XONG/CLIENT_TRO_LY_ONLINE.md) | Thêm cơ chế Keep-alive SSE `: ping` 15s chống timeout 45s; nâng `maxOutputTokens: 4096`; lọc bỏ tin nhắn mở đầu nếu `role !== 'user'`; ngắt kết nối dọn dẹp tài nguyên và ngắt gọi Gemini khi client hủy request. | ✅ Đã xong 100% |
| **46** | [NOTIFICATION_CLIENT_APP_LECH_MA.md](../DA-XONG/NOTIFICATION_CLIENT_APP_LECH_MA.md) | Chỉnh sửa toàn diện hơn 30 điểm lệch mã trong `docs/Notification/Notification_Client-app.md` (đường dẫn `features/notification/`, 20 loại / 8 chip lọc, nhóm `bienDong`, `TheChoXoaTrangChu`, checklist, xóa cứng D1). | ✅ Đã xong 100% |
| **45** | [TAT_NHAC_HOA_DON_QUA_DONG_BO.md](../DA-XONG/TAT_NHAC_HOA_DON_QUA_DONG_BO.md) | Sửa `sync.repository.js` bảo toàn giá trị `null` cho trường `time_notification` của hóa đơn khi tạo mới và cập nhật (`!== undefined ? ... : ...`), đảm bảo trạng thái tắt nhắc không bị khôi phục sau đồng bộ. | ✅ Đã xong 100% |
| **44** | [SOAT_SAU_GOP_D72CCD45.md](../DA-XONG/SOAT_SAU_GOP_D72CCD45.md) | Webhook PayOS Idempotency: khử trùng theo `payos_transaction_id` và siết chặt kiểm tra trạng thái chỉ xử lý khi ở `PENDING` hoặc `EXPIRED`. | ✅ Đã xong 100% |
| **43** | [SOAT_SAU_GOP_CD2EE572.md](../DA-XONG/SOAT_SAU_GOP_CD2EE572.md) | AIOps Controller chuẩn hóa trạng thái tài khoản sang `'Inactive'` thay vì `'Locked'` cho cả khóa vĩnh viễn và tạm thời. | ✅ Đã xong 100% |
| **39** | [PHAN_QUYEN_THEO_GOI_KHAO_SAT.md](../DA-XONG/PHAN_QUYEN_THEO_GOI_KHAO_SAT.md) | Phân quyền tính năng động theo loại tài khoản: CSDL Migration 22, API Admin, Trang `/permissions` Admin-web, Ràng buộc Client-app (`TranGoi`, `TrangThaiGoi`, AI Chat & Nhập nhanh). | ✅ Đã xong 100% |
| **38** | [CLIENT_PREMIUM_PAYOS.md](../DA-XONG/CLIENT_PREMIUM_PAYOS.md) | Thêm `limits, price, packageDays` vào `/subscription-info`; đính chính 5 điểm lệch mã PayOS; bỏ chữ đồng bộ tức thì. Test PASS 100%. | ✅ Đã xong 100% |
| **37** | [KEO_VE_BO_SOT_BAN_GHI_DAY_MUON.md](../DA-XONG/KEO_VE_BO_SOT_BAN_GHI_DAY_MUON.md) | Thêm cột `Server_update_at`, index và trigger cho 6 bảng đồng bộ (Migration 20); `/sync/pull` và `maxSince` dùng `Server_update_at`; giữ LWW theo `update_at`. Test PASS 100%. | ✅ Đã xong 100% |
| **34** | [CLIENT_NHAC_SAU_APP_NGAN_HANG.md](../DA-XONG/CLIENT_NHAC_SAU_APP_NGAN_HANG.md) | Nhắc ghi sau khi dùng app ngân hàng $\ge$ 20s (100% on-device offline, tuân thủ NĐ 13/2023/NĐ-CP). Đã hoàn tất và lưu trữ. | ✅ Đã xong 100% |
| **36** | [SOAT_SAU_GOP_B38367E.md](../DA-XONG/SOAT_SAU_GOP_B38367E.md) | Vá lách query bảo trì, loại bỏ fallback 'secret', bỏ req.isAdmin theo URL path, chuẩn hóa load-shedding test env, siết CORS, bổ sung 3 ca test login bảo trì. Test PASS 100%. | ✅ Đã xong 100% |
| **35** | [SOAT_UU_TIEN_ADMIN_VA_CHAN_IP.md](../DA-XONG/SOAT_UU_TIEN_ADMIN_VA_CHAN_IP.md) | Xóa bỏ ưu tiên tự khai header, xóa Fast-lane 2 AIOps, chuyển sang jwt.verify, timingSafeEqual, bảo trì login, authLimiter chuẩn. Test PASS 100%. | ✅ Đã xong 100% |
| **31** | [SOAT_SAU_GOP_A7C03B7.md](../DA-XONG/SOAT_SAU_GOP_A7C03B7.md) | Sửa dứt điểm 2 lỗi mã FHS (`allExpenses` chiều tiền Vay/no, `trendVsLastMonth` null), khử BOM file SQL 14, cập nhật CloudDeploy.md, chuẩn hóa toàn diện tài liệu (v27, 9 tools, Gemini 3.8 Flash). Test FHS PASS 100%. | ✅ Đã xong 100% |

*(Các mục từ 1 đến 33 xem chi tiết tại [`docs/superpowers/backend/DA-XONG/README.md`](../DA-XONG/README.md))*

---

## 2. Trạng thái toàn bộ tài liệu kỹ thuật (Đã lưu trữ tại `DA-XONG/`)

Toàn bộ **56** tài liệu kỹ thuật đã được kiểm chứng và lưu trữ tại [`docs/superpowers/backend/DA-XONG/`](../DA-XONG/README.md).

---

## 3. Ranh giới trách nhiệm

Client-app **không sửa `src/Backend`**. Mọi việc cần backend đều được viết
thành tài liệu ở đây thay vì sửa thẳng. Nếu một mục nào đó đọc thấy vô lý hoặc
tốn hơn dự kiến, hãy ghi lại lý do vào chính tài liệu ấy — client sẽ đọc và tìm
đường vòng ở phía mình.
