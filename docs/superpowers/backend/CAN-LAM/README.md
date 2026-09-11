# Backend — TOÀN BỘ 15 MỤC ĐÃ HOÀN TẤT 100%

**Cập nhật:** 2026-09-11 tối (soát từng tài liệu `7675b35` với mã HEAD và CSDL dev — thêm mục 18 `VERIFY_7675B35_REMAINING.md`; viết lại banner ⚠️, mục 1 và mục 2 theo kết quả đo. Bảng phân nhóm và danh sách mười sáu mục trước khi gộp nay chỉ còn trong lịch sử git. Trước đó cùng ngày: áp `database/12` lên CSDL dev — sửa gạch thứ ba của banner "đã gộp". Trước đó cùng ngày: gộp `main` @ `cc65f4f` về nhánh `TranQuangDat`: giữ **nguyên văn** tiêu đề và khối 🎉 của backend (`f8ab027`), thay banner "`main` đã đi trước nhánh client" bằng banner "đã gộp" ngay dưới khối ấy, và trỏ liên kết của mục 1–2 sang `../DA-XONG/` theo chỗ tệp nằm hôm nay. Trước đó cùng ngày: thêm mục 17 `FIX_BACKEND_3_REGRESSIONS.md` — ba hồi quy của `7675b35` trên `main`). Trước đó: 2026-09-10 tối (mục 16 viết lại thành hướng dẫn sửa theo dòng — 56 chỗ tài liệu, ba việc mã; mục 11: phần **áp** `database/7`–`11` đã xong trên CSDL dev — còn lại ghi quy trình và tách nhánh cho qua. Trước đó cùng ngày: thêm mục 13–16 sau lượt rà soát CSDL mới — `AUTH_401_BODY_CODE.md`, `GOAL_PRIORITY_NULL_TO_ZERO.md`, `SYNC_PUSH_ERROR_MAPPING.md`, `RULE_PROJECT_DOC_DRIFT.md`. Trước đó cùng ngày: mục 10 `SYNC_NOTE_FILTER_REWRITE.md`, mục 11 `DEV_DB_MIGRATIONS_7_11.md` sau khi gộp `main`, và mục 12 `WALLET_SAVING_INDEX.md` sau lượt rà soát ví; mục 9 gộp vào mục 11. Lần trước: 2026-09-09, thêm mục 7 và 8 — hai tệp `SOCKET_*`. Banner đợt 2026-09-07 bên dưới giữ nguyên vì nó nói về đợt ấy)

> 🎉 **CẬP NHẬT 2026-09-11:**
> Toàn bộ **15/15 mục kỹ thuật** trong thư mục này đã được Backend triển khai trọn vẹn, áp dụng Migration 12 thành công lên PostgreSQL Supabase, kiểm thử tự động đạt 100% PASS (`test_can_lam_fixes.js`, `test_sensitive_note_filter.js`, `test_category_unique_rules.js`, `test_data_security_encryption_and_masking.js`, `test_sync_new_schema.js`), và toàn bộ 15 tài liệu kỹ thuật đã được di chuyển sang thư mục [`docs/superpowers/backend/DA-XONG/`](../DA-XONG/).
> Hiện tại thư mục `CAN-LAM/` **không còn hạng mục nào tồn đọng**.

> ## ⚠️ 2026-09-11 — client đã soát từng mục: sáu xong trọn, bảy còn một phần, hai chưa
>
> Tiêu đề và khối 🎉 ngay trên là **báo cáo của backend** (`f8ab027`, NPBao), giữ
> nguyên văn. Nhánh `TranQuangDat` đã gộp `main` @ `cc65f4f` và CSDL dev đã áp
> `database/12` cùng ngày; client đối chiếu từng tài liệu với mã HEAD và CSDL — như đã
> làm với đợt 2026-09-07 ngay dưới — thay vì tin báo cáo. Trạng thái từng tài liệu ở
> **mục 2**, việc còn lại ở **mục 17 và 18** (cộng mục **19**, viết cùng ngày
> cho G33 — không thuộc lượt soát này). Ba điều đáng biết nhất:
>
> - Hồi quy **A** và **B** của mục 17 vẫn nguyên — bắt tay socket và `/auth/refresh` từ
>   chối mọi tài khoản, chốt trả hai lần chặn hoàn tác. Nên sửa **trước** khi triển khai
>   `main` ở bất cứ đâu có người dùng.
> - "Thống nhất payload `bank_transaction.incoming`" chưa đúng, và từ `7675b35` mỗi giao
>   dịch ngân hàng còn phát **hai lần** (mục 18 §2.5).
> - "Áp dụng Migration 12 thành công" nói về CSDL phía backend. Trên CSDL dev tệp 12 đã
>   áp, nhưng `budget.Threshold_Warning_Percent` vẫn `DEFAULT 0` vì tệp không có bước ấy
>   (mục 18 §2.2).

> ## ✅ Đợt backend 2026-09-07 — client đã kiểm chứng bằng mã, không tin báo cáo
>
> `main` mang về một đợt sửa lớn. Client đọc mã nguồn và truy vấn thẳng
> PostgreSQL để đối chiếu từng tuyên bố, thay vì đọc bảng trạng thái của
> backend. Kết quả: **mục 1, 3, 4, 5, 7 xong; mục 6 bãi bỏ; mục 8, 9 và cả
> `goal.Priority` lẫn `Idaccount` cho `uq_transaction_external` xong**.
> Còn lại trong nhóm 1: **(D)** của mục 2, và **7b** (cột màu).
>
> ⚠️ **Đợt migration ban đầu KHÔNG chạy được.** `)2_can_lam_all_migrations.sql`
> có một câu `DELETE FROM "category"` xoá cứng 5 danh mục mặc định ngoài bộ
> 13 stable UUID. Trên CSDL thật, `fk_bill_category` là **RESTRICT** và có 6
> hoá đơn trỏ tới, nên câu ấy ném 23503 và **toàn bộ tệp roll back** — đó là
> lý do CSDL chưa từng có cột nào của đợt này. Ngoài ra `fk_transaction_category`
> là **SET NULL**: nếu gỡ vướng cho DELETE chạy lọt thì 7 giao dịch mất danh
> mục mà không báo lỗi. Client đã đổi thành xoá mềm (`UPDATE ... SET
> "Delete_at" = NOW()`) trên nhánh `patch2`, chạy thử trong giao dịch rồi
> `ROLLBACK` để kiểm, sau đó áp dụng thật. **Xin nhận bản vá ấy trước khi
> chạy migration ở bất kỳ môi trường nào khác.**
>
> ✅ **Đã bàn giao 2026-09-08:** người dùng đã thông báo cho người phụ trách
> backend. Việc sửa tệp thuộc về phía backend; nhánh `patch2` giữ nguyên tại
> chỗ làm bản tham chiếu.
>
> ⚠️ Bản vá **(B)** tuy đúng thứ client xin nhưng làm hỏng một chỗ phía
> client mà không ai lường: `message` không còn mang mã SQLSTATE nên mọi
> regex phân loại lỗi mất khả năng khớp, và lỗi vĩnh viễn im lặng tụt xuống
> nhánh `transient`. Client đã tự vá (`_permanentCodes`) — **không cần
> backend làm gì**, ghi lại để lần sau đổi hợp đồng lỗi thì báo trước.

> Thư mục này nay giữ `README.md` và **3** tài liệu còn việc (mục 17, 18, 19 —
> đếm bằng máy 2026-09-11). Mười lăm tài liệu còn lại đã sang
> [`../DA-XONG/`](../DA-XONG/README.md) theo báo cáo của backend; **chín** trong số đó
> còn việc dang dở — ghi ở mục 2 và gom vào mục 18, thay vì chuyển ngược tệp lại đây.
> Thư mục cha có ba tệp bối cảnh (mục 4).

---

## 1. Còn phải làm

| # | Tài liệu | Nội dung | Mức |
|---|---|---|---|
| **17** | [FIX_BACKEND_3_REGRESSIONS.md](./FIX_BACKEND_3_REGRESSIONS.md) | Ba hồi quy của `7675b35`: **A** bắt tay socket và `/auth/refresh` từ chối mọi tài khoản; **B** chốt trả hai lần ở `upsertBill` chặn hoàn tác thanh toán; **C** tài liệu backend ghi sai ba mã lỗi | 🔴 A, B |
| **18** | [VERIFY_7675B35_REMAINING.md](./VERIFY_7675B35_REMAINING.md) | Chín việc mã/CSDL còn lại của mười lăm tài liệu đã sang `DA-XONG/` — giao dịch SePay vỡ `chk_transaction_type` (suy từ mã), sự kiện ngân hàng phát hai lần, khoá mã hoá mặc định, tệp `)2` còn xoá cứng, `DEFAULT 0` của ngân sách, … — cộng 45 chỗ sửa tài liệu backend. Thứ tự đề xuất ở §1 của tài liệu ấy | 🟠 → ⚪ |
| **19** | [AUTH_PROFILE_COUNTDOWN.md](./AUTH_PROFILE_COUNTDOWN.md) | `GET /auth/profile` trả thêm `countdown` (máy đã giữ phiên từ trước khi máy khác gửi yêu cầu xoá, bộ nhớ đệm do bản client cũ ghi, và máy còn giữ số ngày của một lần chờ xoá trước mới biết đúng số ngày còn lại — đăng nhập máy khác hay cài lại app thì response đăng nhập đã mang số); gỡ `pendingDeleteCancelled` luôn `false` khỏi response đăng nhập | 🟡 → ⚪ |

---

## 2. Trạng thái mười lăm tài liệu backend báo đã xong (đo 2026-09-11)

Cột **#** là số mục cũ của README này — tài liệu client khác dẫn "CAN-LAM 13", "mục 11"…
theo đúng số ấy. Đo trên mã HEAD `src/Backend` (trùng `main` @ `cc65f4f`) và CSDL dev đã áp
tệp 12; cách đo ở đầu mục 18.

| # | Tài liệu | Kết luận | Còn gì |
|---|---|---|---|
| 1 | [2026-09-04-backend-idempotent-delete.md](../DA-XONG/2026-09-04-backend-idempotent-delete.md) | ⚠️ (A)(B)(C) ✅; (D) mã ✅, CSDL còn `DEFAULT 0` | 18 §2.2 |
| 2 | [CATEGORY_COLOUR_COLUMN.md](../DA-XONG/CATEGORY_COLOUR_COLUMN.md) | ✅ phía backend — cột `Color`, push nhận và pull trả khoá `color` | ✅ client sửa khoá 2026-09-11 — 18 §2.3 |
| 3, 4, 5 | [2026-09-06-bill-chuoi-ky-va-an-han.md](../DA-XONG/2026-09-06-bill-chuoi-ky-va-an-han.md) | ⚠️ việc A, B, C, E ✅ (cột, push, pull, `'Skipped'`); việc D: cột `Auto_pay` ✅, chốt trả hai lần đặt sai chỗ | 17 B |
| 6 | [BILL_ANCHOR_DAY.md](../DA-XONG/BILL_ANCHOR_DAY.md) | ✅ cột, push, pull; không chỗ nào tự tính lại từ `Due_date` | — |
| 7 | [SOCKET_SYNC_COMPLETED.md](../DA-XONG/SOCKET_SYNC_COMPLETED.md) | ✅ phát sau `/sync/push` tới phòng tài khoản — nhưng chưa tới được client vì 17 A | — |
| 8 | [SOCKET_BANK_EVENT_PAYLOAD.md](../DA-XONG/SOCKET_BANK_EVENT_PAYLOAD.md) | ⛔ vẫn hai hình dạng, `type` hai nghĩa; nay phát hai lần | 18 §2.5 |
| 9 | [WALLET_STATUS_COLUMN_WIDTH.md](../DA-XONG/WALLET_STATUS_COLUMN_WIDTH.md) | ✅ `varchar(20)`, push ghi thẳng `status` | — |
| 10 | [SYNC_NOTE_FILTER_REWRITE.md](../DA-XONG/SYNC_NOTE_FILTER_REWRITE.md) | ⚠️ bảng 15 ca đúng 15/15, 8.2 và 8.3 ✅; 8.1 khoá mã hoá chưa | 18 §2.6 |
| 11 | [DEV_DB_MIGRATIONS_7_11.md](../DA-XONG/DEV_DB_MIGRATIONS_7_11.md) | ⚠️ 4.3 ✅ ở HTTP; 4.2 một phần; tệp `)2` còn xoá cứng | 18 §2.4 |
| 12 | [WALLET_SAVING_INDEX.md](../DA-XONG/WALLET_SAVING_INDEX.md) | ⚠️ index đã bỏ ✅; `WALLET_*_DUPLICATE` có trong mã, cần một phép thử khi chạy | 18 §2.7 |
| 13 | [AUTH_401_BODY_CODE.md](../DA-XONG/AUTH_401_BODY_CODE.md) | ⚠️ body 401 HTTP có `code` ✅; bắt tay socket và `/auth/refresh` hỏng | 17 A, 18 §2.1 |
| 14 | [GOAL_PRIORITY_NULL_TO_ZERO.md](../DA-XONG/GOAL_PRIORITY_NULL_TO_ZERO.md) | ✅ giữ `null` khi đẩy, nhánh tạo mặc định `null`, tệp 12 dọn `<= 0` | — |
| 15 | [SYNC_PUSH_ERROR_MAPPING.md](../DA-XONG/SYNC_PUSH_ERROR_MAPPING.md) | ✅ `22001`/`23502` → `CONSTRAINT_VIOLATION`; lớp kiểm tra không còn làm cả lô 400 | — |
| 16 | [RULE_PROJECT_DOC_DRIFT.md](../DA-XONG/RULE_PROJECT_DOC_DRIFT.md) | ⛔ 11/56 chỗ đã sửa đúng | 18 §3 |
| — | [2026-09-04-ocr-classify-review.md](../DA-XONG/2026-09-04-ocr-classify-review.md) | ⚠️ `classifyBatch`, dedup ✅; cửa hậu `_mock*` chỉ đóng ở `production`, `'ORC'` còn sót | 18 §2.8 |

Đếm: ✅ sáu (2, 6, 7, 9, 14, 15), ⚠️ bảy (1, 3–5, 10, 11, 12, 13, OCR), ⛔ hai (8, 16).

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
