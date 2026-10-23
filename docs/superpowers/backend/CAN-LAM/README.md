# Backend & Client — DANH SÁCH CẦN LÀM (7 mục chờ backend — mục 43, 44, 45, 46, 47, 48, 49)

> ✉️ **Client gộp `main` @ `ee6a65e5` (PR #153–#158) và đặt mục 49, 2026-10-23:**
> [`SOAT_SAU_GOP_EE6A65E5.md`](./SOAT_SAU_GOP_EE6A65E5.md), mức **vừa**. Lượt gộp không đụng `src/Client-app` hay `CAN-LAM/`;
> đồng bộ, 401, socket, 503 bảo trì vẫn khớp client. Đơn gồm: **A** commit `6cbd248e` viết lại tài liệu của client
> `docs/superpowers/sync/SYNC_DOCUMENTATION.md` thành *"Hợp đồng v3.0"* sai mã ~15 chỗ — client giữ bản cũ + đoạn đầu
> trỏ đơn (người dùng chốt), xin đừng sửa thẳng tài liệu client và soát `Sync-To-ClientApp.md` cùng lỗi; **B**
> `Event-Notification-to-ClientApp.md` bảo client xoá SQLite khi `ACCOUNT_DELETED` (dòng 52, 107, 131, 622 — ngược G89);
> **C** migration trùng số **27** lần hai; **D** `npm install` trước khi áp 33 / 34 làm đăng nhập lỗi 500 (`P2022`);
> **E (thấp)** `IP-Device-ClientApp.md` nêu hai route admin không có, CORS thiếu `x-device-name`; **F (thấp)** migration 33
> xoá cứng tài khoản test khi tắt khoá ngoại. Mục 45 vẫn mở — số dòng nay `sync.repository.js:117, 527, 553`.
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

## 0. Còn phải làm (Hiện tại: **7** mục — đếm bằng `ls` 2026-10-23: 43 và 44 backend báo xong, client soát còn phần dư; 45 và 46 backend chưa trả lời; client đặt 47 ngày 2026-10-17 (cập nhật số đo 2026-10-18), 48 ngày 2026-10-20 và 49 ngày 2026-10-23. Mục 41 và 42 đã chuyển sang `DA-XONG/`)

| # | Tài liệu | Trách nhiệm | Nội dung & Tiến độ | Trạng thái |
|---|---|---|---|---|
| **43** | [SOAT_SAU_GOP_CD2EE572.md](./SOAT_SAU_GOP_CD2EE572.md) | Backend | **A (cao)** AIOps khoá tài khoản ghi `'Inactive'` thay `'Locked'`; `accountRejection` mặc định `ACCOUNT_INACTIVE`, chỉ `Deleted` mới `ACCOUNT_DELETED`; áp lại `ck_account_status`. **B (cao)** webhook `orderCode` lạ → 2xx, không tạo đơn / không nâng gói cho Admin. **C (vừa)** 503 lúc đăng nhập bảo trì mang `code` + `Retry-After: 60`. **D (thấp)** Đã cập nhật `Event-Notification-to-ClientApp.md`. Đã kiểm thử 2-Tier PASS 100%. | 🟡 Backend ghi ✅ Đã xong 100% · client soát 2026-10-18: đạt A2, B, C; còn A1 (controller), A3, A4, A5, A6 (tuỳ chọn), D (0 / 12) — banner tệp · **phần client (bốn việc) xong 2026-10-20 — G89**, phần dư backend giữ nguyên |
| **44** | [SOAT_SAU_GOP_D72CCD45.md](./SOAT_SAU_GOP_D72CCD45.md) | Backend | **A (cao)** Đánh số lại hai tệp migration thanh toán (thành 28 và 29, tránh trùng 20, 24); trả `apply_migration_20.js` về `Server_update_at`. **B (vừa)** Webhook Idempotency không ghi đè đơn `REFUNDED`/`CANCELLED`. **C (vừa)** Tra mã nhận diện theo token cuối của nội dung. **D (vừa)** Nới `payment_order.status` lên VARCHAR(25). **E (thấp)** `accept` bắt buộc boolean. **F (thấp)** Đã cập nhật `Event-Notification-to-ClientApp.md`. Đã kiểm thử 2-Tier PASS 100%. | 🟡 Backend ghi ✅ Đã xong 100% · client soát 2026-10-18: đạt A, C, D, E, F; B còn hai vế — banner tệp |
| **45** | [TAT_NHAC_HOA_DON_QUA_DONG_BO.md](./TAT_NHAC_HOA_DON_QUA_DONG_BO.md) | Backend | `sync.repository.js`: hoá đơn `time_notification` — tạo ~:471 `\|\| '3'` và cập nhật ~:497 `?? existing` nuốt NULL (= tắt nhắc ở client); ~:98 `String(null)` thành `"null"` (số dòng sau gộp `ee6a65e5`, 2026-10-23: **:527**, **:553**, **:117**). Đổi sang `!== undefined ? … : …`. Đo dev: 37 hoá đơn sống, 0 NULL (hệ quả của phép ép). Client đã làm phần mình (`d657b065`, tắt là tắt thật); tới khi sửa, tắt nhắc bị đảo sau một vòng đồng bộ. | ⏳ Chờ backend |
| **46** | [NOTIFICATION_CLIENT_APP_LECH_MA.md](./NOTIFICATION_CLIENT_APP_LECH_MA.md) | Backend (chữ) | Sửa `docs/Notification/Notification_Client-app.md` theo bảng của đơn (~30 chỗ, bốn nhóm: đường dẫn · hàm / route · con số · hành vi; nhãn [cũ] / [mới]); phần phía backend ghi riêng, ngắn. Kiểm lại bằng một câu `grep` ra 0 dòng. Không đổi mã; không chặn client. | ⏳ Chờ |
| **47** | [CLIENT_TRO_LY_ONLINE.md](./CLIENT_TRO_LY_ONLINE.md) | Backend | Thông báo client đã tích hợp `chat/stream` (hỗn hợp, tự rơi về AI trên máy); **nghiệm thu OnePlus trên backend dev 2026-10-18 đạt** — đơn cập nhật số đo. **(thấp)** ghi tên `GEMINI_MODEL` đã kiểm (`gemini-3.8-flash` trả lời thật trên dev 2026-10-18) vào `ChatbotAI.md` và đặt trên cloud; giữ `history.slice(-6)`; cân nhắc bỏ tin đầu không phải `user` trước `startChat` (SDK ném → breaker dùng chung mở cho mọi tài khoản); tả `done {error}` trong `ChatbotAI_Moblie.md` §2.1 và sửa bốn chỗ `ChatbotAI.md` — `:286`, `:420` khẳng định Dừng ngắt được Gemini; `:296`, `:443` chỉ nêu tên hook `req.on('close')`. **(vừa) việc 5** Dừng không tới server — **đo 2026-10-18**: client đóng socket thật (ESTABLISHED tới :3000 4 → 2 trong 1 s) nhưng không dòng `[SSE Controller] … đã ngắt kết nối`, service *"Hoàn tất 14590ms"* 12 s sau → `req.on('close')` không nổ (Node 22); xin: khi client ngắt kết nối thì thôi ghi `delta`, không gọi thêm tool / Gemini, huỷ lời gọi Gemini đang chạy hoặc bỏ lời gọi kế (service ghi log ngay tại lời gọi Gemini), không đếm breaker / không fallback; tiêu chí đo bằng log ở ba thời điểm. **(vừa) việc 6** keep-alive SSE `: ping` ≤ 15 s khi chờ Gemini — server im > 45 s (49,9 s; curl 91 s) nên client `receiveTimeout` rơi về máy trong khi server vẫn chạy (client giữ 45 s). **(vừa) việc 7** `maxOutputTokens: 1024` gồm token suy nghĩ → câu dài cụt ở điểm ngẫu nhiên (172 ↔ 1.851 ký tự); cân nhắc gửi `finishReason` trong `done`. Không đổi lược đồ / payload; không chặn client. | ⏳ Chờ backend |
| **48** | [DU_LIEU_TEST_TRONG_TAI_KHOAN_THAT.md](./DU_LIEU_TEST_TRONG_TAI_KHOAN_THAT.md) | Backend (dữ liệu + script test) | **Việc 1 (vừa)** xoá mềm trên CSDL dev, ba bước. Bước 1: ví `test-wallet-1789014227658` + 2 giao dịch `test-tran-note-*` còn sống của tài khoản 18 (`Server_update_at` tự cập nhật qua trigger). Bước 2 là hệ quả biết trước: máy đang kẹt đẩy lại id giả và tạo ví "ma" `00000000-0000-4000-8000-4534d71cc54d`. Bước 3: xoá mềm ví ma, hoặc người dùng xoá trong app. **Việc 2 (vừa)** sửa ca 11 `Test/test_data_security_encryption_and_masking.js`: tài khoản test riêng thay `findFirst` không `orderBy`, `crypto.randomUUID()`, dọn trong `finally`. **Việc 3 (thấp)** `test_sync_new_schema.js:21`, `test_can_lam_fixes.js:44` cùng khuôn (UUID, có dọn). Phép kiểm: ba câu `SELECT` ở cuối đơn. Không đổi mã / lược đồ / payload; client không đổi mã (G98). | ⏳ Chờ backend |
| **49** | [SOAT_SAU_GOP_EE6A65E5.md](./SOAT_SAU_GOP_EE6A65E5.md) | Backend (chữ + migration) | Soát sau gộp `ee6a65e5`. **A (vừa)** `6cbd248e` viết lại `SYNC_DOCUMENTATION.md` của client thành *"Hợp đồng v3.0"* sai mã ~15 chỗ (bảng đối chiếu trong đơn) — client giữ bản cũ; xin đừng sửa thẳng tài liệu client, soát `Sync-To-ClientApp.md` (cùng tên cột sai). **B (vừa)** `Event-Notification-to-ClientApp.md` dòng 52 · 107 · 131 · 622 bảo xoá SQLite khi `ACCOUNT_DELETED` — ngược G89. **C (vừa)** trùng số migration 27 (`27_add_qr_url…` và `27_create_aiops_metric_snapshot…`) + tệp `)2_can_lam_all_migrations.sql`. **D (vừa)** áp 30–36 **trước** `npm install` — `auth.repository.js` `include` không `select` → đăng nhập `P2022`. **E (thấp)** `IP-Device-ClientApp.md`: hai route admin không có trong mã; CORS `app.js:32` thiếu `x-device-name`. **F (thấp)** migration 33 xoá cứng tài khoản test khi tắt khoá ngoại → bảng con mồ côi. Mỗi vế có câu kiểm lại. Client không đổi mã. | ⏳ Chờ backend |

---

## 1. Trạng thái các mục Backend đã xử lý (Gần nhất)

| # | Tài liệu gốc | Nội dung & Kết quả xử lý | Trạng thái |
|---|---|---|---|
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
