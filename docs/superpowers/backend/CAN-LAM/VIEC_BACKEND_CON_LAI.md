# Việc backend còn phải làm — MỘT tệp (đơn 52 · 55 · 60 + việc nhỏ 48.1 + tài liệu T1, T3, T6)

> **Người nhận:** backend (NPBao). Tệp này **chỉ còn việc phải làm** — client soát PR #174 ngày **2026-10-31** (backend `8e3b4e48`).
> **Kết quả soát 23 việc PR #174 trả lời: 15 đạt · 7 một phần · 1 chưa.**
> - **Đạt, đã xoá khỏi tệp:** 57.1, 57.2, 57.3, 57.6, 57.7, 57.8, 58.3, 58.4, 58.5, 58.6, 59.1, 59.2, 59.3, 52.1, T2.
> - **Toàn bộ mã gia đình phần 1 đã đạt khi chạy thật:** `chay_kiem.js` **50 / 50** trên bản sao `8e3b4e48` + CSDL tạm (client tự chạy); `tests/unit` 486 / 488, hai dòng hỏng là ca 5 của `data_encryption_group4_audit` cần khoá `.env` và bộ test cha của nó. **Không còn việc nào chặn client làm lát 2.**
> - Bản có báo cáo của backend: `git show 8e3b4e48:docs/superpowers/backend/CAN-LAM/VIEC_BACKEND_CON_LAI.md`; bản đề bài có mã sửa từng việc: `git show 6180af17:…`. Bảng mã lỗi chốt (57.7) client đã chép sang `docs/Family/04_HOP_DONG_PHAN_1_NHU_MA.md` mục 2b.
> - Mỗi việc có **mã** giữ số đơn cũ. Tám tệp đơn gốc ở `LICH-SU/` là lịch sử, đừng ghi trả lời vào đó.
>
> **Lưu ý chung:**
> - Trước khi báo xong: `npm run verify:household` trên CSDL riêng phải vẫn `TỔNG: 50 đạt / 50 ca` (bạn đã chép kịch bản vào `src/Backend/scripts/verify_household_contract.js`).
> - **Ô trả lời chỉ ghi điều có trong diff.** Lượt này có chín câu không khớp mã (mục 11). Việc chưa làm thì ghi *"chưa"*, không sao.
> - Trả lời ghi vào bảng mục 10. Bảng mục 0, văn ở các mục khác và README mục 0 + banner là vùng client cập nhật.
>
> Số dòng đọc ở HEAD client `9a607156` (gộp `8e3b4e48`). Đơn mới thêm mục vào tệp này, số kế tiếp **61**.

---

## 0. Bảng việc

| Mã | Việc | Mức | Mục | Còn thiếu |
|---|---|---|---|---|
| 52.4 | Chưa xác nhận khoá **trên Render** | VỪA | 4 | So vân tay Render, `/sync/pull` 200 |
| T1 | `Event-Notification-to-ClientApp.md` — câu sai MỚI ở `:67`, 11 / 20 hàng chưa đạt | VỪA | 8.1 | Sửa tại dòng |
| T3 | `4_TRU_COT.md` — 13 / 15 hàng chưa đạt, xoá nhầm `/export-report` | VỪA | 8.3 | Sửa tại dòng |
| 52.3 | Câu chốt đã có; chưa chạy trên `PersonFinance` | VỪA | 4 | Một dòng tổng kết |
| 52.5 | Script đạt; thiếu khoá, thời điểm, hai vế đo | VỪA | 4 | Ghi mục 10 |
| 55.A3 | Mã + hợp đồng đạt; không có ca test Premium + NULL | VỪA | 5 | Một ca test |
| T6 | Tài liệu đạt; ca 2 PayOS không chạy nhánh nó nêu; mã thật mang nhánh của test | THẤP | 8.6 | Sửa ca, gỡ nhánh |
| 48.1 | Không có tên, công cụ | THẤP | 6 | Một câu ở mục 10 |
| 60.1 | Hai script `Test/` chặn `supabase\.com`, có thể lọt `*.supabase.co` | THẤP | 7 | Sửa regex |
| 60.2 | `kq_household_contract.txt` không bị ignore | THẤP | 7 | Thêm ignore hoặc đổi nơi ghi |
| 60.3 | Ca test nhãn `[Tier 2]` mock trúng hàm cần chứng minh | THẤP | 7 | Sửa nhãn hoặc ca |

---

## 4. Mã hoá dữ liệu (đơn 52)

Lịch sử: [`LICH-SU/GIAI_MA_HONG_TRA_BAN_MA.md`](./LICH-SU/GIAI_MA_HONG_TRA_BAN_MA.md). ⚠️ Hàng **còn sống** giải hỏng làm `/sync/pull` 500 cả lượt (`sync.controller.js:67-73`), nên 52.4 là việc quan trọng nhất tệp này.

### 52.4 (VỪA) — chưa làm

Ô trả lời chỉ có vân tay **máy dev** (`98e9e026`) và câu *"xác nhận tính nhất quán"*: chưa so với Render. **Rủi ro còn mở:** 25 + 3 hàng trên Supabase mang khoá `.env`; Render khác khoá thì mọi lượt kéo toàn bộ của tài khoản có hàng còn sống trả 500.

**Cách làm:** so vân tay, không in khoá. Thêm tạm vào `index.js` sau khi nạp `.env`, deploy, đọc log Render, rồi gỡ:

```js
logger.info('DATA_KEY_FP', { fp: require('crypto').createHash('sha256').update(process.env.DATA_ENCRYPTION_KEY || '').digest('hex').slice(0, 8) });
```

**Kiểm lại:** vân tay Render = `98e9e026`; `GET https://managementfinance.onrender.com/api/sync/pull` không `since` của một tài khoản có hàng đã di trú trả 200. Ghi cả hai vào mục 10.

### 52.3 (VỪA) — phần còn thiếu

Câu chốt đã có (`docs/progress/Backend.md` mục 25, `.env.example:95`). Ô chỉ ghi *"đạt kết quả an toàn"*. Chạy và dán **dòng tổng kết** vào mục 10:

```bash
DATABASE_URL=<PersonFinance> DIRECT_URL=<PersonFinance> DATA_ENCRYPTION_KEY=<khoá dev> npm run db:verify-encryption
```

### 52.5 (VỪA) — phần còn thiếu

Script và mã thoát đạt. Ghi vào mục 10: script đã chạy trên CSDL nào, khoá nào (vân tay), lúc nào. Hai vế còn lại đo theo 52.3 và 52.4.

---

## 5. Phân quyền theo gói (đơn 55)

### 55.A3 (VỪA) — phần còn thiếu

Mã (`utils/premium.util.js`, job `payment.repository.js:520-525`) và hai câu hợp đồng đạt. Ô trả lời viện `tests/unit/sync.service.test.js`: **tệp không tồn tại**. `isPremiumEffective` có 0 lần xuất hiện trong `tests/` và `scripts/`.

**Cách làm:** thêm một ca trên CSDL riêng: tài khoản `Premium` + `premium_expires_at` NULL ⇒ `chuConPremium`, `requireFeature`, `updateHouseholdStatusByOwner`, `/subscription-info` cùng ra Basic; chạy job xong `Type = 'Basic'`.

Phía client: app đang coi hàng ấy là còn Premium, client tự đổi theo câu hợp đồng, không cần backend làm gì thêm.

---

## 6. Script test ghi vào dữ liệu thật (đơn 48)

### 48.1 (THẤP) — phần còn thiếu

Hết `scripts/cleanup`, mốc giờ đúng `2026-10-26 03:58:21Z`. Ô ghi *"thao tác quản trị trực tiếp trên Supabase"*: không có tên người, không nói công cụ (`UPDATE` tay? Admin-web? script nào?). Không nhớ thì ghi *"không truy được"*: câu ấy cũng đóng việc.

---

## 7. Việc nhỏ phát hiện khi soát PR #174 (đơn 60)

### 60.1 (THẤP) — Khối chặn của hai script `Test/`

`Test/test_can_lam_fixes.js:15-23`, `Test/test_sync_new_schema.js:1-9` chặn URL khớp `supabase\.com`. Câu ấy do tệp việc của client đề nghị và **chưa kiểm** với URL thật (client không đọc `.env`). URL dạng `*.supabase.co` sẽ lọt. **Cách sửa:** đổi thành `/supabase\.(com|co)/i`. **Kiểm lại:** chạy thử với `DATABASE_URL` giả mỗi dạng, script phải dừng trước `require` CSDL.

### 60.2 (THẤP) — Tệp kết quả của `verify:household`

`scripts/verify_household_contract.js` mặc định ghi `src/Backend/kq_household_contract.txt`, không bị ignore: chạy xong có tệp lạ trong `git status`. **Cách sửa:** thêm vào `.gitignore` hoặc mặc định ghi `os.tmpdir()`.

### 60.3 (THẤP) — Nhãn ca test nói quá

Bằng chứng đường thật của 57.6, 58.3, 58.5 là kịch bản 50 / 50, không phải bộ unit. Chính khuôn của `household_group1` ca 1 từng xanh trên lỗi `delete_at`.

| Ca | Vì sao chưa canh được | Cách sửa |
|---|---|---|
| `household_group1_completion` ca 1 (57.6) | Giả `$transaction` + `updateMany`; Prisma không kiểm tên cột | Bỏ `[Tier 2]`, ghi *"ghim tham số"* |
| `household_group1_completion` ca 2 (58.3) | Giả `emitHouseholdChanged`, chính hàm cần chứng minh | Chỉ giả tầng socket |
| `household_and_aiops_v2` ca 3 (58.1) | `operation: 'create'`, khoá `to_idwallet`: app không gửi | Chép payload từ `sync_payload_contract_test.dart` |
| `household_and_aiops_v2` ca 4 (57.4 + 59.1) | Giả `enforceHouseholdPermission`; không kiểm *không ghi* | Giả ở tầng Prisma, kiểm số lần ghi |
| `household_and_aiops_v2` ca 5 (58.5) | Đi qua `isAccountQuarantined`, 0 chỗ gọi ngoài test | Gọi `sweepExpiredQuarantines`, `_reconcileAutoLocks` |
| `household_and_aiops_v2` ca 2 (57.2) | Gọi thật `findActiveMemberByAccount` với id cứng 104, có truy vấn CSDL theo `.env` | Giả hàm ấy |

---

## 8. Tài liệu backend cần sửa — gom theo tệp

Các tệp dưới là tài liệu **của backend** (client không sửa). Đường dẫn *Mã thật* dưới `src/Client-app/lib/` trừ khi ghi khác. **Cách làm:** mở từng dòng, sửa ngay tại dòng theo cột bên phải (hoặc ghi rõ *"Server lưu / chưa có hiệu lực ở app"*). Tính năng chưa có thì ghi *"kế hoạch"*, đừng đánh `[x]` / *"100%"*.

### 8.1 (T1) — `docs/Admin-web/Event-Notification-to-ClientApp.md`

9 / 20 hàng đã đạt, đã bỏ khỏi bảng. Số dòng là dòng hiện tại.

| Dòng | Đang nói | Xin sửa theo mã |
|---|---|---|
| **67** | **Câu MỚI của PR #174:** *"che thông tin số tài khoản (`transfer_details`)"* | **Sai: mã vẫn phát thô** (`ocr.service.js:146`, nguồn `classify.service.js:325, 328`; `notification.service.js:102` gửi nguyên `data`). Hai tệp ấy không có trong diff. **Chọn một:** che thật `source_account` / `destination_account` trước `eventBus.publish('ocr.completed')` (đọc `maskAccountNumber` trước vì nó gọi `decrypt` đầu vào; client không đọc payload này nên không phải đổi app), hoặc sửa câu cho đúng |
| 99, 288 | `sync.completed` *"từ thiết bị khác"* | Phát cho mọi máy của tài khoản, cả máy vừa đẩy (`:290` đã đúng) |
| 320-325 | Mẫu `ocr.duplicate` | Thiếu `data`, `createdAt`; `title` / `message` khác mã (`notification.service.js:116-117, 129-135`) |
| 102, 347-349 | `user.notification` lưu SQLite + badge | Tiêu đề `:333` đã ghi *"Chưa dùng"*; sửa theo hai chỗ này |
| 103, 354 | `payment.success` tới phòng tài khoản do webhook | `:356` đã đúng; sửa theo (`payment.service.js:343, 361, 738`) |
| 105 | *"Đóng popup VietQR"* | `payment.*` là tín hiệu, không popup |
| 624 | *"đếm ngược tự động thử lại"* | Không toast; chỉ `/sync/push` hẹn lại, sàn 30 s (`core/sync/gui_lo_dong_bo.dart:214`) |
| 498, 625 | 429: *"dừng lặp request (App không có nhánh riêng cho 429)"* tự mâu thuẫn; *"thông báo người dùng tạm nghỉ"* | App không có nhánh riêng cho 429 |
| 120 | *"Dialog phong tỏa + đếm ngược"* | Dòng nhắc Trang chủ + toast + câu Đăng nhập + hẹn thử (PR sửa `:121` kế bên, sót dòng này) |
| 88-109, 605-629 | Bảng 3.1 và ma trận không có `household.*`; ô trả lời nói đã thêm | Thêm `household.changed`, `household.invited` |
| 42, 113, 453 | *"9 tín hiệu"* | Bảng 3.2 có 8 hàng |

Cùng tệp còn nói ngược mã ngoài bảng cũ: `:94` (*In-App Banner*), `:98` + `:283-284` (*Banner cam* cho `account.countdown`, app không nghe), `:117` + `:623` (*Banner* bảo trì), `:119` (*exponential backoff*), `:118` + `:641`, `:193-199` (xử lý `system.maintenance_changed` trong khi `:608` ghi *cố ý bỏ qua*), `:265` (*Toast chúc mừng*: `loiNhan` của hai sự kiện gói là `null`, `realtime_event.dart`).

### 8.3 (T3) — `docs/Functional-Mobile/4_TRU_COT.md`

Diff PR chỉ 3 dòng; ô trả lời kể *"bổ sung… cho từng tính năng… OCR ML Kit… seed ngân hàng"*, không có trong diff. Gốc chung: app **không** đọc `scopes` / `scope_config` lẫn `policies` / `downgrade_policy`. Cách sửa gọn: dưới mỗi tính năng thêm một dòng *"App thi hành: …"*; dòng `scope_config` chưa dùng ghi *"Server lưu, chưa có hiệu lực ở app"*.

| Dòng | Đang nói | App thi hành |
|---|---|---|
| 599 | PR **xoá mất** `/export-report` | Trả lại: route vẫn có (`core/router/app_router.dart:229`), cùng `/analytics/export` |
| 74-76, 428 | `READ_ONLY` xem lại dự báo | Thẻ khoá thay cả khối; dự báo tính tại chỗ, không lưu (`features/analytics/presentation/pages/analytics_page.dart:179-185`) |
| 225-227, 565 | OCR 15 lượt | ML Kit, không đếm lượt |
| 203-204, 563 | 1 / 5 ảnh, 90 ngày | Không đính ảnh vào giao dịch; Sổ xem mọi kỳ |
| 236-237, 566 | 20 / 100 | Không trần |
| 274-275, 569 | 5 / 25 từ khoá | Không trần |
| 580 | FHS | App không có màn |
| 529-530, 589 | Tải hoá đơn | Không có; chỉ *Lưu mã QR* |
| 545-547, 590 | Sao lưu ảnh, về 10 s | 2 s mọi gói, không sao lưu ảnh |
| 110-112, 556 | `cache_token_days` | Không có; mở lạnh dùng phiên đã lưu rồi `verifySession()` |
| 491, 586 | MB / MOMO / ZALOPAY, *"4 banks"* | Seed `database/32:196, 260` vẫn VCB / MB / TCB / ACB. **Chọn một:** viết migration sửa seed, hoặc ghi đúng seed + *"Server lưu, không dùng"*. App: MB Bank · MoMo · ZaloPay, không theo gói |
| 518-519 | `countdown_minutes: 15` | **Chọn một:** migration đổi seed về 10 (`database/32:208, 262, 309`), hoặc ghi *"Server lưu, không dùng"* |
| 11 | *"lộ trình tương lai"* | Bỏ, trừ khi có quyết định PO |

### 8.6 (T6, THẤP) — phần còn thiếu

Hai tài liệu và `createMany` đạt.

| Chỗ | Cách sửa |
|---|---|
| `tests/unit/payos_group3_comprehensive_audit.test.js` ca 2 | Ca giả `recordTransaction` (`:72-81`), tự ném P2002 và tự đếm, nên nhánh `payment.repository.js:373-378` không chạy; ô trả lời *"để kích hoạt nhánh P2002"* không đúng. Gọi `recordTransaction` thật trên CSDL thử hai lần cùng `reference`, đếm một hàng |
| Cùng tệp `:122, 198, 271, 345, 395, 450, 516` | Bỏ nhãn `[Tier 2]` ở ca giả `paymentRepository` |
| `payment.repository.js:415-444` | Bỏ nhánh `typeof … === 'function'` chỉ để hợp bản giả (ô tự ghi *"fallback `create` cho mock unit test"*): mã chạy thật không nên mang nhánh của test. Sửa bản giả cho có `createMany` |

---

## 10. Trả lời (backend ghi vào đây)

Mỗi dòng một câu nói đúng việc của mã ấy — commit, tệp, ca test (đường thật). Báo cáo PR #174: `git show 8e3b4e48:docs/superpowers/backend/CAN-LAM/VIEC_BACKEND_CON_LAI.md` mục 10.

| Mã | Đã làm (tệp, commit) | Kiểm lại ra gì | Ghi chú |
|---|---|---|---|
| 52.4 | | | *(vân tay Render, `/sync/pull` 200)* |
| T1 | | | |
| T3 | | | |
| 52.3 | | | *(dòng tổng kết `db:verify-encryption`)* |
| 52.5 | | | *(CSDL, vân tay khoá, thời điểm)* |
| 55.A3 | | | |
| T6 | | | |
| 48.1 | | | |
| 60.1 | | | |
| 60.2 | | | |
| 60.3 | | | |

---

## 11. Ô trả lời PR #174 không khớp mã (để lần sau tránh)

| Ô | Câu | Thực tế |
|---|---|---|
| T1 | *"chuẩn hóa socket `transfer_details` che số tài khoản"* | Không có mã (`ocr.service.js:146`) |
| T1 | *"cập nhật bảng sự kiện có thêm `household.changed`…"* | Bảng 3.1 và ma trận không có |
| T1 | *"Đã sửa chính xác 100%"* | 9 / 20 hàng đạt |
| T3 | *"bổ sung… cho từng tính năng… OCR ML Kit… seed ngân hàng"* | Diff 3 dòng |
| T6 | *"để kích hoạt nhánh P2002"* | `recordTransaction` bị giả |
| 55.A3 | `tests/unit/sync.service.test.js` pass | Tệp không tồn tại |
| 57.7 | `src/Backend/middlewares/rate-limiter.js` | Tệp thật ở `middleware/` |
| 57.8 | `database/40_household_foundation.sql` | Tệp thật `40_create_household_foundation.sql` |
| 52.4 | *"Xác nhận tính nhất quán"* | Không có số đo Render |
