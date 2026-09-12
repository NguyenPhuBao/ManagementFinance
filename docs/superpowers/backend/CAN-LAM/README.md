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

> ## ⚠️ 2026-09-12 — nhánh `TranQuangDat` đã gộp `main` @ `cbbeeb4`; client CHƯA soát từng mục
>
> Khối 🎉 ngay trên là **báo cáo của backend** (`8487fce`), giữ nguyên văn. Bảng "client đã
> soát từng mục" đo ngày 2026-09-11 (trước đây là mục 2 của README này) đã bị bản này thay,
> và **chưa được đo lại** trên mã mới. Cho tới khi có lượt soát bằng mã và CSDL, các tài liệu
> client (`CLAUDE.md`, `docs/PROJECT_CONTEXT.md` mục 14, `docs/CLIENT_APP_KNOWN_GAPS.md`)
> vẫn mô tả trạng thái **trước** lần gộp này — CAN-LAM 17 A/B và 19 ghi là chưa xong.
> Tệp `database/13` backend báo đã áp trên CSDL của họ; **CSDL dev trên máy client chưa áp**.

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
