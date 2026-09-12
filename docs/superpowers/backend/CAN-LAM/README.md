# Backend — TOÀN BỘ 15 MỤC ĐÃ HOÀN TẤT 100%

**Cập nhật:** 2026-09-11 tối muộn (thêm mục **19** `AUTH_PROFILE_COUNTDOWN.md` cùng lúc client sửa G33 — dòng bảng mục 1, banner ⚠️ và số "3 tài liệu còn việc" ghi theo; sau lượt soát cuối G33, bảng §1 và §2.4 của mục 19 viết lại cho đúng ca "máy không có số ngày". Trước đó cùng tối: soát từng tài liệu `7675b35` với mã HEAD và CSDL dev — thêm mục 18 `VERIFY_7675B35_REMAINING.md`; viết lại banner ⚠️, mục 1 và mục 2 theo kết quả đo. Bảng phân nhóm và danh sách mười sáu mục trước khi gộp nay chỉ còn trong lịch sử git. Trước đó cùng ngày: áp `database/12` lên CSDL dev — sửa gạch thứ ba của banner "đã gộp". Trước đó cùng ngày: gộp `main` @ `cc65f4f` về nhánh `TranQuangDat`: giữ **nguyên văn** tiêu đề và khối 🎉 của backend (`f8ab027`), thay banner "`main` đã đi trước nhánh client" bằng banner "đã gộp" ngay dưới khối ấy, và trỏ liên kết của mục 1–2 sang `../DA-XONG/` theo chỗ tệp nằm hôm nay. Trước đó cùng ngày: thêm mục 17 `FIX_BACKEND_3_REGRESSIONS.md` — ba hồi quy của `7675b35` trên `main`). Trước đó: 2026-09-10 tối (mục 16 viết lại thành hướng dẫn sửa theo dòng — 56 chỗ tài liệu, ba việc mã; mục 11: phần **áp** `database/7`–`11` đã xong trên CSDL dev — còn lại ghi quy trình và tách nhánh cho qua. Trước đó cùng ngày: thêm mục 13–16 sau lượt rà soát CSDL mới — `AUTH_401_BODY_CODE.md`, `GOAL_PRIORITY_NULL_TO_ZERO.md`, `SYNC_PUSH_ERROR_MAPPING.md`, `RULE_PROJECT_DOC_DRIFT.md`. Trước đó cùng ngày: mục 10 `SYNC_NOTE_FILTER_REWRITE.md`, mục 11 `DEV_DB_MIGRATIONS_7_11.md` sau khi gộp `main`, và mục 12 `WALLET_SAVING_INDEX.md` sau lượt rà soát ví; mục 9 gộp vào mục 11. Lần trước: 2026-09-09, thêm mục 7 và 8 — hai tệp `SOCKET_*`. Banner đợt 2026-09-07 bên dưới giữ nguyên vì nó nói về đợt ấy)

> 🎉 **CẬP NHẬT 2026-09-12 — TOÀN BỘ 19/19 MỤC ĐÃ HOÀN TẤT 100%:**
> Toàn bộ các hạng mục kỹ thuật từ 1 đến 19 (bao gồm mục 17 `FIX_BACKEND_3_REGRESSIONS.md`, mục 18 `VERIFY_7675B35_REMAINING.md`, mục 19 `AUTH_PROFILE_COUNTDOWN.md`, và toàn bộ các điểm lệch tài liệu ND01–ND39) đã được Backend giải quyết trọn vẹn:
> - Đã sửa lỗi socket handshake & refresh token (`accountRejection`).
> - Đã cho phép hoàn tác hóa đơn ở `upsertBill`.
> - Đã chuẩn hóa payload và kênh phát `bank_transaction.pending` qua EventBus, số tiền chi âm, type `Transaction`.
> - Đã bổ sung biến môi trường bắt buộc `DATA_ENCRYPTION_KEY` ở production.
> - Đã vá xóa mềm danh mục trong `database/)2_can_lam_all_migrations.sql`.
> - Đã áp dụng `database/13_drop_budget_threshold_default.sql` lên PostgreSQL dev (bỏ DEFAULT 0 và thêm 2 partial unique index ví).
> - Đã gia cố bắt lỗi `WALLET_NAME_DUPLICATE` trong `sync.service.js`.
> - Đã đồng bộ 100% tài liệu `New_Database.md`, `Rule_project.md`, `Data_Security.md`, `Backend.md`, `Project.md`.
> - Toàn bộ 19 tài liệu kỹ thuật đã được kiểm chứng và lưu trữ tại [`docs/superpowers/backend/DA-XONG/`](../DA-XONG/).
> Thư mục `CAN-LAM/` hiện **không còn mục nào tồn đọng**.

> ## ⚠️ 2026-09-12 — client đã soát 19/19 bằng mã, CSDL và máy ảo: 17 A ✅, 17 B **một nửa**, 19 ✅, 18 còn **năm** việc mã và **tám** chỗ tài liệu
>
> Khối 🎉 ngay trên là **báo cáo của backend** (`8487fce`), giữ nguyên văn. Nhánh `TranQuangDat`
> gộp `main` @ `cbbeeb4` lúc 15:02 cùng ngày (`3bdac75`); backend dev trên máy client chạy
> nodemon nên nạp mã mới ngay. Cách đo: đọc diff `16bd5b3..cbbeeb4` của `src/Backend` (14 tệp);
> chạy `accountRejection` thật bằng `node -e` (4 ca); truy vấn **chỉ đọc** PostgreSQL
> (`pg_constraint`, `pg_indexes`, `information_schema`); và **đầu-cuối trên máy ảo
> `emulator-5554`**, tài khoản 11, đọc `adb logcat`. Chỗ nào chưa đo đầu-cuối thì ghi rõ.
>
> | Mục | Kết luận | Bằng chứng / còn gì |
> |---|---|---|
> | **17 A** | ✅ xong, **đã chạy thật** | Hàm trả `null` khi `valid` (4 ca `node -e`, ca `Active` → `truthy=false`); `socket.js` và `auth.service.js` xử lý `SCHEMA_ERROR` **trước** rồi đọc `rejection.data`. Máy ảo: sau **51** lần `Nối hỏng: … Account no longer exists` liên tiếp, `[RealtimeChannel] Đã nối (idaccount=11)` lúc **15:01:46** — đúng lúc nodemon nạp mã gộp; mạng về thì nối lại sau 2 giây. Nhánh `/auth/refresh`: mã đúng như 2.6, **chưa** đo đầu-cuối (cần mật khẩu tài khoản thử) |
> | **17 B** | ⚠️ **một nửa** | Bước 1 (bỏ chốt ở `upsertBill`) ✅ — **đã chạy thật**: hoá đơn `3c90acfa…` kẹt 7 lần đẩy từ sáng đã lên server `Payed → Pending` lúc **15:10:21** (`1/1 synced`). Bước 2 (chốt ở `upsertTransaction`, mục 3.6) **❌ không làm**: không chỗ nào ném `BILL_ALREADY_PAID` nữa — `grep` chỉ còn nhánh ánh xạ **chết** ở `sync.service.js:171`. Hai máy cùng bật tự thanh toán vẫn là hai khoản chi (bill doc 6.2). ⚠️ `Rule_project.md:430` và `Backend.md:511` nay mô tả một chốt **không tồn tại** |
> | **17 C** | ✅ ba câu sửa đúng như xin | `Rule_project.md:333`, `:430`; `Backend.md:511`. Nhưng câu về `BILL_ALREADY_PAID` viết theo giả định bước 2 của B đã làm — xem hàng trên |
> | **18 §2.1** | ✅ | `socket.js:44` đọc `rejection.data` |
> | **18 §2.2** | ✅ mã · ⚪ CSDL máy client | `database/13` có `DROP DEFAULT` (+ hai index ví `IF NOT EXISTS`, đã có sẵn từ 2026-09-01). CSDL dev **trên máy client chưa áp**: `column_default = 0` (đo 15:05) |
> | **18 §2.4** | ⚠️ một nửa | Tệp `)2` ✅ đổi `DELETE` → `UPDATE … SET "Delete_at"`. **Sổ ghi migration ❌**: `Rule_project.md:69` còn "đến migration 12", không có bảng N → nội dung → câu kiểm; ghi chú partial index / `prisma migrate diff` ❌ không có (`grep` 0 dòng) |
> | **18 §2.5** | ✅ | `bank.worker.js` bỏ emit trực tiếp, chỉ còn **một** chỗ phát (`notification.service.js:23`, `type: 'BankTransactionPending'`). `admin.bank_transaction_created` bị bỏ hẳn — trước đó cũng chưa từng phát vì `emitToAdmin` không tồn tại |
> | **18 §2.6** | ⚠️ một nửa | `DATA_ENCRYPTION_KEY` ✅ từ chối khởi động ở `production`, có trong `.env.example`. **`BLIND_INDEX_SECRET` ❌ không có chốt** — vẫn rơi về chuỗi cứng im lặng (`crypto.util.js:26`) |
> | **18 §2.7** | ✅ mã · ⚪ chưa thử | Regex nhận thêm `uq_wallet_account_name` và `err.meta.target` (`sync.service.js:180-186`). Ca thử "đẩy hai ví trùng tên" **chưa** ai chạy |
> | **18 §2.8** | ❌ nguyên | `_mock*` vẫn chỉ chặn khi `NODE_ENV === 'production'` (`ocr.controller.js:22`, `classify.controller.js:108`). `'ORC'` còn `sync.repository.js:308` và bốn chú thích (`ocr.service.js:8,25`, `dedup.service.js:14`, `vision.extractor.js:56`) — `Backend.md:514` "thay thế triệt để" vẫn sai |
> | **18 §2.9** | ✅ | `bank.worker.js:193-195`: `type: 'Transaction'`, khoản chi **âm**. Không đường ghi giao dịch ngân hàng nào còn `'Chi'`/`'Thu'` (`grep` `modules/bank`, `workers`) |
> | **18 §3** | ✅ phần lớn · **8** chỗ còn | Đã đúng: Email partial unique, Username không unique, `Reason_Inactive`/`Countdown`, "Check in" chỉ còn ở cột **có** CHECK thật (đối chiếu 18 `pg_constraint`), Note đã mã hoá, `Day` bỏ, index của category/wallet/transaction khớp `pg_indexes` từng chữ, **171 cột** = 179 − 8 cột `_prisma_migrations`, DS01, BK01. Còn sai — xem danh sách dưới |
> | **19** | ✅ cả hai | `auth.repository.js:227` select `countdown`; `auth.service.js:567` trả `countdown ?? null`; `pendingDeleteCancelled` **0** chỗ (`grep`). **Chưa** đo đầu-cuối (cần token) |
>
> **Tám chỗ tài liệu backend còn sai sau lượt sửa** (số dòng HEAD `3bdac75`):
> 1. `New_Database.md:172` và `:374` — "**Không** có CHECK cho `Status`" của **ví**: sai, `chk_wallet_status` có (`Active`/`Inactive`). Lỗi **mới** sinh trong lượt sửa ND09.
> 2. `New_Database.md:396` — FK `auto_deposit_wallet_id → Wallet`: sai, `goal` chỉ có `fk_goal_account`, `fk_goal_wallet` (đo `pg_constraint`); mâu thuẫn với chính dòng 397 ngay dưới.
> 3. `Rule_project.md:430` + `Backend.md:511` — chốt `BILL_ALREADY_PAID` ở giao dịch **chưa có** (17 B bước 2).
> 4. `Rule_project.md:69` — "đến migration 12"; đã có `database/13`. Vẫn thiếu sổ ghi (18 §2.4).
> 5. `Backend.md:13`, `:157` — còn `ORC`; `:514` "thay thế triệt để" sai (18 §2.8).
> 6. `Backend.md:495` — `sync.completed` "khi background worker xử lý xong": chỉ phát sau `/sync/push` (`sync.service.js:232`); `bank.worker.js` không publish.
> 7. `Backend.md:475` — "16 tài liệu"; README này ghi 19.
> 8. `Backend.md:186-193`, `Project.md:2646-2650` — "PASS 100%" cho các script `Test/` **không có trong repo** (BK02, nguyên).
>
> `Backend.md:483`, `Project.md:2639` "đã áp Migration 13" đúng với CSDL của backend, **chưa** đúng với CSDL dev trên máy client.
>
> **Ngoài phạm vi xin, thấy khi đọc diff:** `admin.service.js:336-342` — `deleteCategory` ném lỗi ở **mọi** nhánh (403 nếu không mặc định, 400 nếu mặc định), endpoint xoá danh mục của Admin-web không còn đường nào chạy tới `adminRepository.deleteCategory`. Không ảnh hưởng client.
>
> **Việc còn lại phía backend, gom lại:** 17 B bước 2; 18 §2.4 (sổ ghi + ghi chú partial index); §2.6 (`BLIND_INDEX_SECRET`); §2.7 (một ca thử); §2.8 (`_mock*`, `'ORC'`); và tám chỗ tài liệu trên. Chưa viết thành tài liệu mục 20 — chờ người dùng quyết.
>
> **Hệ quả cho client** (chưa sửa tài liệu client — `CLAUDE.md`, `PROJECT_CONTEXT.md`, `CLIENT_APP_KNOWN_GAPS.md` và 12 tệp khác còn **76** dòng nói 17 A/B, 19 chưa xong, đếm bằng `grep` 15:08): kênh thời gian thực **đã nối được** — mở khoá G34 (`sync.completed`), kiểm máy ảo nhánh socket và nhánh làm mới của cưỡng chế đăng xuất; hoàn tác thanh toán hoá đơn **đã lên server**; đồng bộ `Auto_pay` vẫn nên chờ 17 B bước 2 vì chốt chống trả hai lần **chưa có ở đâu cả**.

---

## 1. Trạng thái các mục đã xử lý

| # | Tài liệu gốc | Nội dung & Kết quả xử lý | Trạng thái |
|---|---|---|---|
| **17** | [FIX_BACKEND_3_REGRESSIONS.md](../DA-XONG/FIX_BACKEND_3_REGRESSIONS.md) | **A:** Sửa `accountRejection` trả null khi tài khoản hợp lệ, socket bóc đúng `rejection.data`.<br>**B:** Bỏ chốt `BILL_ALREADY_PAID` tại `sync.repository.js:450` để cho phép hoàn tác.<br>**C:** Sửa 3 mã lỗi lệch trong tài liệu. | ✅ Đã xong 100% |
| **18** | [VERIFY_7675B35_REMAINING.md](../DA-XONG/VERIFY_7675B35_REMAINING.md) | Xử lý 9 điểm kỹ thuật (§2) và 39 điểm lệch tài liệu (§3 ND01–ND39), gồm sửa `bank.worker.js`, áp dụng migration 13, bắt `WALLET_NAME_DUPLICATE`, và đồng bộ `New_Database.md`. | ✅ Đã xong 100% |
| **19** | [AUTH_PROFILE_COUNTDOWN.md](../DA-XONG/AUTH_PROFILE_COUNTDOWN.md) | `GET /auth/profile` đã select và trả `countdown`; gỡ bỏ `pendingDeleteCancelled` khỏi response đăng nhập. | ✅ Đã xong 100% |

---

## 2. Trạng thái toàn bộ tài liệu kỹ thuật (Đã lưu trữ tại `DA-XONG/`)

Toàn bộ 19 tài liệu đã được chuyển sang [`docs/superpowers/backend/DA-XONG/`](../DA-XONG/README.md) và được kiểm chứng qua bộ kiểm thử tự động `Test/test_can_lam_fixes.js`.

---

## 3. Ranh giới trách nhiệm

Client-app **không sửa `src/Backend`**. Mọi việc cần backend đều được viết
thành tài liệu ở đây thay vì sửa thẳng. Nếu một mục nào đó đọc thấy vô lý hoặc
tốn hơn dự kiến, hãy ghi lại lý do vào chính tài liệu ấy — client sẽ đọc và tìm
đường vòng ở phía mình.

---

## 4. Ba tệp bối cảnh ở thư mục cha, cộng lược đồ chuẩn nay nằm chỗ khác

Không phải việc cần làm, nhưng cần để hiểu phần trên:

- [`New_Database.md`](../../../Rule_Project/New_Database.md) — lược đồ chuẩn của PostgreSQL (đã chuyển vào `docs/Rule_Project/`).
  Đây là **nguồn sự thật** cho schema.
- [`../2026-08-10-backend-sync-spec.md`](../2026-08-10-backend-sync-spec.md) —
  hợp đồng `/sync/push` và `/sync/pull`.
- [`../PROGRESS-BACKEND.md`](../PROGRESS-BACKEND.md) — checklist B1→B7.
- [`../TRANSACTION_NOTE_ENCODING.md`](../TRANSACTION_NOTE_ENCODING.md)
  (2026-09-08) — **không xin gì**, chỉ báo rằng client mã hoá ý nghĩa vào
  `transaction.Note`.

⚠️ `New_Database.md` **không còn ở thư mục cha**: nhánh `main` chuyển nó sang
`docs/Rule_Project/` ngày 2026-09-10. Tiêu đề mục này từng ghi "Ba", rồi "Bốn",
nay lại là ba — **đếm bằng máy mỗi lần chạm vào, đừng chép con số cũ**.

⚠️ **Backend lệch tên cột giữa các bảng**, ít nhất ba kiểu: `category` dùng
`Delete_at`, `transaction` dùng `Deleted_at`, và cột ngày của giao dịch là
`DateTransaction` (không gạch dưới). Đừng suy tên từ bảng này sang bảng kia —
mở `schema.prisma` ra đọc. Sai tên cột ở PostgreSQL thì báo lỗi ngay, nhưng sai
trong payload đồng bộ thì **im lặng**.
