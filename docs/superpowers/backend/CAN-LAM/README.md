# Backend & Client — DANH SÁCH CẦN LÀM (7 mục chờ backend — mục 41, 42, 43, 44, 45, 46, 47)

> ✉️ **Client đặt mục 47, 2026-10-17 tối:** [`CLIENT_TRO_LY_ONLINE.md`](./CLIENT_TRO_LY_ONLINE.md) — mức **vừa**, đơn
> **thông báo + xin**. Client đã tích hợp `POST /api/ai/chatbot/chat/stream` theo lối **hỗn hợp** (có mạng hỏi backend, hỏng /
> mất mạng thì AI trên máy trả lời cùng câu; 22 commit `80d9dee8` → `fb92c16d`, chưa nghiệm thu đầu-cuối vì backend dev chưa
> khởi động được — đơn 44). Đơn nêu năm chỗ cố ý không làm theo `ChatbotAI_Moblie.md` (huy hiệu / nút chuyển chế độ, thẻ FHS +
> `GET /snapshot`, bảng `LocalChatMessages`, mẫu `Dio()` trần, `conversationId` vẫn gửi) và ba hành vi client phải bù (`delta`
> thông báo trước `done.fallback`; `done {error}` tài liệu không tả; `history` mở đầu vai `model` làm SDK Gemini ném và mở circuit
> breaker dùng chung). Xin: tên `GEMINI_MODEL` đã kiểm (dev nay có khoá, tên `gemini-3.8-flash` chưa ai chạy thật), giữ
> `history.slice(-6)`, cân nhắc kiểm vai tin đầu ở server, tả `done {error}`, và nghe `res.on('close')` thay vì chỉ
> `req.on('close')` — trên Node ≥ 16 listener ở `req` có thể không nổ nên nút Dừng không huỷ được lượt Gemini (dấu hiệu từ thử
> nhanh, **chưa đo trên backend thật**). Không đổi lược đồ, payload; không chặn client.
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
> ✉️ **Client đặt mục 42, 2026-10-10:** [`TAI_LIEU_KIEN_TRUC_CLIENT_APP.md`](./TAI_LIEU_KIEN_TRUC_CLIENT_APP.md) — mức
> **thấp**, chỉ **sửa chữ**. `Project.md` §3.3 ghi *"Mỗi màn hình có BLoC riêng"* trong khi app có 3 Bloc + 7 Cubit cho
> màn có luồng ghi, 289 `setState`, màn đọc dùng stream Drift; dòng *Repository* cũng tả nguồn local/remote không có. Đơn
> kèm câu thay thế từng dòng, ba dòng thêm (test quét kiến trúc, cổng nền tảng, chạy nền WorkManager) và một câu hỏi có
> mặc định (§3.3 **trỏ** sang `docs/KIEN_TRUC_CLIENT_APP.md`). Không đổi mã, lược đồ, payload. `DA-XONG/` đếm bằng máy
> 2026-10-10: **58** tệp + mục lục. `ls CAN-LAM/` nay: **41 · 42** · `CLIENT_INTEGRATION_GUIDE.md` + README.
>
> ✉️ **Client đặt mục 41, 2026-10-09:** [`CHAN_TRA_HAI_LAN_THEO_KY.md`](./CHAN_TRA_HAI_LAN_THEO_KY.md) — mức **cao**.
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

## 0. Còn phải làm (Hiện tại: **7** mục — đếm bằng `ls` 2026-10-17 tối: backend chưa trả lời mục 41, 42, 43, 44, 45, 46; client vừa đặt 47)

| # | Tài liệu | Trách nhiệm | Nội dung & Tiến độ | Trạng thái |
|---|---|---|---|---|
| **41** | [CHAN_TRA_HAI_LAN_THEO_KY.md](./CHAN_TRA_HAI_LAN_THEO_KY.md) | Backend | Mở rộng `chanTraHaiLan` (`upsertTransaction`) sang kỳ anh em cùng `Previous_bill_id` + `Due_date`; mã mới `BILL_PERIOD_ALREADY_PAID` qua phép ánh xạ lỗi của `sync.service.js`. Phía client **đã sẵn** (2026-10-09): mã nằm trong danh sách lỗi vĩnh viễn + bộ xử lý riêng — backend triển khai lúc nào cũng được. | ⏳ Chờ backend |
| **42** | [TAI_LIEU_KIEN_TRUC_CLIENT_APP.md](./TAI_LIEU_KIEN_TRUC_CLIENT_APP.md) | Backend (chữ) | Sửa bảng `Project.md` §3.3 *Kiến trúc Client-app* cho khớp mã: dòng *State Management* (3 Bloc + 7 Cubit, màn đọc dùng stream Drift, trạng thái màn trong widget), dòng *Repository* (interface ở tầng data, trả Entity hoặc hàng Drift), thêm *Test quét kiến trúc* · *Cổng nền tảng* · *Chạy nền WorkManager*. Mặc định: §3.3 trỏ sang `docs/KIEN_TRUC_CLIENT_APP.md`. Không đổi mã. | ⏳ Chờ |
| **43** | [SOAT_SAU_GOP_CD2EE572.md](./SOAT_SAU_GOP_CD2EE572.md) | Backend | **A (cao)** AIOps khoá tài khoản ghi `'Inactive'` thay `'Locked'`; `accountRejection` mặc định `ACCOUNT_INACTIVE`, chỉ `Deleted` mới `ACCOUNT_DELETED`; áp lại `ck_account_status` (`database/N`). **B (cao)** webhook `orderCode` lạ → 2xx, không tạo đơn / không nâng gói. **C (vừa)** 503 lúc đăng nhập bảo trì mang `code` + `Retry-After`. **D (thấp)** sửa `Event-Notification-to-ClientApp.md` theo bảng của đơn. Client làm phần mình (connect_error, `account.downgraded`, dải bảo trì / phong toả) **sau khi** đơn đóng. *(Soát ở `d72ccd45`: B vẫn mở — `findOrCreateOrderByCode` không đổi.)* | ⏳ Chờ backend |
| **44** | [SOAT_SAU_GOP_D72CCD45.md](./SOAT_SAU_GOP_D72CCD45.md) | Backend | **A (cao)** đánh số lại hai tệp migration thanh toán (trùng 20, 24); trả `apply_migration_20.js` về migration `Server_update_at`. **B (vừa)** webhook chỉ xử lý đơn còn `PENDING` (`EXPIRED` tuỳ chọn), khử trùng theo `reference`. **C (vừa)** tra mã nhận diện theo token cuối của nội dung. **D (vừa)** nới `payment_order.status` lên 25 bằng SQL, hoặc đưa `schema.prisma` về 20. **E (thấp)** `accept` bắt buộc boolean. **F (thấp)** thêm hợp đồng thanh toán mới vào `Event-Notification-to-ClientApp.md`. Không chặn client (G94). | ⏳ Chờ backend |
| **45** | [TAT_NHAC_HOA_DON_QUA_DONG_BO.md](./TAT_NHAC_HOA_DON_QUA_DONG_BO.md) | Backend | `sync.repository.js`: hoá đơn `time_notification` — tạo ~:471 `\|\| '3'` và cập nhật ~:497 `?? existing` nuốt NULL (= tắt nhắc ở client); ~:98 `String(null)` thành `"null"`. Đổi sang `!== undefined ? … : …`. Đo dev: 37 hoá đơn sống, 0 NULL (hệ quả của phép ép). Client đã làm phần mình (`d657b065`, tắt là tắt thật); tới khi sửa, tắt nhắc bị đảo sau một vòng đồng bộ. | ⏳ Chờ backend |
| **46** | [NOTIFICATION_CLIENT_APP_LECH_MA.md](./NOTIFICATION_CLIENT_APP_LECH_MA.md) | Backend (chữ) | Sửa `docs/Notification/Notification_Client-app.md` theo bảng của đơn (~30 chỗ, bốn nhóm: đường dẫn · hàm / route · con số · hành vi; nhãn [cũ] / [mới]); phần phía backend ghi riêng, ngắn. Kiểm lại bằng một câu `grep` ra 0 dòng. Không đổi mã; không chặn client. | ⏳ Chờ |
| **47** | [CLIENT_TRO_LY_ONLINE.md](./CLIENT_TRO_LY_ONLINE.md) | Backend | Thông báo client đã tích hợp `chat/stream` (hỗn hợp, tự rơi về AI trên máy). **(vừa)** chạy một lượt Gemini thật, ghi tên `GEMINI_MODEL` đã kiểm vào `ChatbotAI.md` và đặt trên cloud (`gemini-3.8-flash` chưa ai kiểm). **(thấp)** giữ `history.slice(-6)`; cân nhắc bỏ tin đầu không phải `user` trước `startChat` (SDK ném → breaker dùng chung mở cho mọi tài khoản); tả `done {error}` trong `ChatbotAI_Moblie.md` §2.1. **(vừa, kiểm trước)** `chatbot.controller.js:33` nghe `req.on('close')` — trên Node ≥ 16 có thể không nổ, Dừng không huỷ Gemini; xin `res.on('close')`. Không đổi lược đồ / payload; không chặn client (thiếu khoá thì client rơi về máy). | ⏳ Chờ backend |

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
