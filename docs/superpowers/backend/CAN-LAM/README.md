# Backend — TOÀN BỘ 21 MỤC ĐÃ HOÀN TẤT 100%

**Cập nhật:** 2026-09-13 (Backend hoàn tất 100% mục 21 `AI_EDGE_SLM_CLIENT_MISMATCH.md`, đồng bộ toàn bộ 6 điểm lệch mã client và 4 điểm tự mâu thuẫn trong tài liệu AI Edge-SLM và Project.md mục 11.39 theo đúng đề xuất của Client; chuyển sang `DA-XONG/`); 2026-09-12 tối muộn (banner ✅ mới ngay dưới banner ⚠️: client soát mục 20 sau gộp `main` @ `7779999`); 2026-09-11 tối muộn (thêm mục **19** `AUTH_PROFILE_COUNTDOWN.md` cùng lúc client sửa G33); 2026-09-10 (mục 13–16); 2026-09-09 (mục 7–8); 2026-09-07.

> 🎉 **CẬP NHẬT 2026-09-13 — TOÀN BỘ 21/21 MỤC ĐÃ HOÀN TẤT 100%:**
> Toàn bộ các hạng mục kỹ thuật từ 1 đến 21 (bao gồm mục 20 `CON_LAI_SAU_CBBEEB4.md` và mục 21 `AI_EDGE_SLM_CLIENT_MISMATCH.md`) đã được Backend giải quyết trọn vẹn:
> - **Đồng bộ tài liệu AI Edge-SLM với mã Client-app thực tế:**
>   - Sửa luật A3: quy ước hoàn tiền là `type = 'thu'`, không giả định `amount < 0`.
>   - Ghi rõ cảnh báo 3 cột `is_recurring_hint`, `is_outlier`, `is_one_time` chưa có trong Drift SQLite.
>   - Ghi rõ `saving_goal_ratio` và `income` chưa được lưu trong CSDL client; Tầng 1 tự tính thu nhập trượt 3 tháng từ `type = 'thu'`.
>   - Bổ sung lưu ý mô hình ngân sách client rộng hơn giả định (`budgets.categoryId` nullable, chu kỳ linh hoạt, hết hạn) và gợi ý tái sử dụng màn hình `ai_chat_page.dart` (436 dòng).
>   - Sửa luật F2: minh bạch ranh giới mã hóa at-rest phía server (ghi chú nằm dạng thô trên client và sync engine).
>   - Đồng bộ cấu trúc 8 nhóm A–H, chuẩn hóa H4 thành 3 bảng SQLite nội bộ (`local_category_features`, `local_rebalancing_feedback`, `local_ai_alert_history`) kèm lưu ý Drift (`schemaVersion` v21).
>   - Đồng bộ `Project.md` mục 11.39: bổ sung C7 (`insufficient_slack`), D5 (trần ngân sách), chuẩn hóa nhãn C4/C5/C6 và H4.
> - Toàn bộ 21 tài liệu kỹ thuật đã được kiểm chứng và lưu trữ tại [`docs/superpowers/backend/DA-XONG/`](../DA-XONG/).
> Thư mục `CAN-LAM/` hiện **không còn mục nào tồn đọng**.

---

## 0. Còn phải làm (Hiện tại: **0** mục — Toàn bộ 21/21 mục đã hoàn tất)

> 🎉 **Tất cả các tài liệu từ mục 1 đến 21 đều đã hoàn tất 100%**.  
> Không còn công việc tồn đọng trong thư mục `CAN-LAM/`. Tài liệu mục 21 đã được nghiệm thu và chuyển sang [`docs/superpowers/backend/DA-XONG/AI_EDGE_SLM_CLIENT_MISMATCH.md`](../DA-XONG/AI_EDGE_SLM_CLIENT_MISMATCH.md).

---

## 1. Trạng thái các mục đã xử lý

| # | Tài liệu gốc | Nội dung & Kết quả xử lý | Trạng thái |
|---|---|---|---|
| **17** | [FIX_BACKEND_3_REGRESSIONS.md](../DA-XONG/FIX_BACKEND_3_REGRESSIONS.md) | **A:** Sửa `accountRejection` trả null khi tài khoản hợp lệ, socket bóc đúng `rejection.data`.<br>**B:** Bỏ chốt `BILL_ALREADY_PAID` tại `sync.repository.js:450` để cho phép hoàn tác.<br>**C:** Sửa 3 mã lỗi lệch trong tài liệu. | ✅ Đã xong 100% |
| **18** | [VERIFY_7675B35_REMAINING.md](../DA-XONG/VERIFY_7675B35_REMAINING.md) | Xử lý 9 điểm kỹ thuật (§2) và 39 điểm lệch tài liệu (§3 ND01–ND39), gồm sửa `bank.worker.js`, áp dụng migration 13, bắt `WALLET_NAME_DUPLICATE`, và đồng bộ `New_Database.md`. | ✅ Đã xong 100% |
| **19** | [AUTH_PROFILE_COUNTDOWN.md](../DA-XONG/AUTH_PROFILE_COUNTDOWN.md) | `GET /auth/profile` đã select và trả `countdown`; gỡ bỏ `pendingDeleteCancelled` khỏi response đăng nhập. | ✅ Đã xong 100% |
| **20** | [CON_LAI_SAU_CBBEEB4.md](../DA-XONG/CON_LAI_SAU_CBBEEB4.md) | Triển khai chốt `chanTraHaiLan` ném `BILL_ALREADY_PAID` ở `upsertTransaction` (khử bẫy thứ tự `dangXoaTrongLo`); chốt khởi động `BLIND_INDEX_SECRET`; cờ `ALLOW_MOCK_INPUT`; loại bỏ triệt để 3 chỗ `'ORC'`; bổ sung ca thử `WALLET_NAME_DUPLICATE`; sửa `/auth/refresh` trả 401 kèm `ACCOUNT_DELETED`/`ACCOUNT_INACTIVE` khi token thu hồi (vá lỗi G36); thêm sổ ghi migration 5-13 và cảnh báo partial index vào `Rule_project.md`; sửa 8 điểm lệch tài liệu. | ✅ Đã xong 100% (Pass test suite `test_con_lai_fixes.js`) |
| **21** | [AI_EDGE_SLM_CLIENT_MISMATCH.md](../DA-XONG/AI_EDGE_SLM_CLIENT_MISMATCH.md) | Khắc phục 6 điểm lệch mã client (A3 hoàn tiền qua `type = 'thu'`, cảnh báo 3 cột thiếu, ghi rõ `saving_goal_ratio`/`income` không lưu, mô hình ngân sách rộng hơn, F2 ranh giới mã hóa server) và 4 điểm tự mâu thuẫn (8 nhóm A–H, H4 3 bảng SQLite, Drift v21, bổ sung C7 & D5 vào `Project.md`). | ✅ Đã xong 100% |

---

## 2. Trạng thái toàn bộ tài liệu kỹ thuật (Đã lưu trữ tại `DA-XONG/`)

Toàn bộ 21 tài liệu đã được chuyển sang [`docs/superpowers/backend/DA-XONG/`](../DA-XONG/README.md) và được kiểm chứng qua các bộ kiểm thử tự động và đối soát mã nguồn.

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
