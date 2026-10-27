# Mục 55 — Phân quyền theo gói: hợp đồng `/subscription-info` cho cột Premium + đính chính `4_TRU_COT.md`

> **Client đặt 2026-10-27** (phiên 16). Người nhận: backend (NPBao). Mức: **TRUNG BÌNH** — không hỏng dữ liệu; vế A làm ma trận
> Admin-web `/permissions` có tác dụng đúng trên app, vế B sửa một tài liệu đang tả app làm những việc app không làm.
>
> Client soát bằng **đọc mã** HEAD `bfbd5e5b` (khảo sát chỉ đọc ba phía 2026-10-27; không truy vấn CSDL — giá trị mặc định lấy
> từ seed `database/32_seed_permissions_4_pillars_data.sql`). Mỗi vế có cách kiểm lại.
>
> - **A** — xin đổi hợp đồng `GET /payment/subscription-info` (3 việc). Client đã thiết kế phần của mình: spec
>   `docs/superpowers/specs/2026-10-27-phan-quyen-cot-premium-va-cong-tac-design.md` (đọc mục 2–4).
> - **B** — xin sửa chữ `docs/Functional-Mobile/4_TRU_COT.md` (tài liệu backend — client chỉ đọc, quy tắc 1). Không đòi sửa mã.

---

## Bối cảnh — app nhận quyền thế nào (mã HEAD)

`payment.service.js:805-832` (`getSubscriptionInfo`): tính `effectiveType` (Premium còn hạn → `'Premium'`, còn lại `'Basic'`) rồi
trả **chỉ bảng của gói ấy**:

```js
const { limits, features, scopes, policies } = await permissionRepository.getPermissionsByAccountType(effectiveType);
return { accountType: account.type, premiumExpiresAt, daysRemaining, isExpired, limits, features, scopes, policies, price, packageDays };
```

`permission.repository.js:124-134`: hàng `LIMIT` chỉ vào `limits[mã] = row.limit_value`; hàng `TOGGLE` vào `features[mã] =
Boolean(row.is_enabled)`. `/auth/login` và `/auth/profile` chỉ trả `type`.

Client (từ bản sắp thi công theo spec trên): đọc **22** trong 31 công tắc + 5 trần, cho **cả** gói Premium (trước đây Premium
còn hạn = mở hết). Chín mã client **không bao giờ khoá** dù admin tắt: `transaction_management`, `offline_first_sync`,
`vietqr_payment`, `account_deletion`, `biometric_auth`, `payment_history`, `ai_model_management`, `offline_login`,
`financial_health_fhs` (lý do ở spec mục 3).

## A — Hợp đồng `/payment/subscription-info`

### A1. Gửi thêm cột Premium cho tài khoản đang Basic

**Vì sao.** Người Basic chỉ thấy bảng Basic. Admin tắt *"Xuất báo cáo"* ở **cả hai** cột → app vẫn mời *"Cần Premium — Nâng
cấp"*, người dùng trả 49.000 đ rồi vẫn bị khoá. Danh sách *"Đặc quyền Premium"* ở màn Nâng cấp cũng phải đoán (dùng mặc định
của client) thay vì đọc đúng cột Premium.

**Xin làm.** Khi `effectiveType === 'Basic'`, thêm hai khoá vào `data`:

```json
"premiumFeatures": { "ai_assistant": true, "export_reports": true, "...": true },   // 31 mã TOGGLE của cột Premium
"premiumLimits":   { "wallets": null, "budgets": null, "goals": null, "bills": null, "custom_categories": null }
```

Cùng cách dựng với `features` / `limits` (gọi `getPermissionsByAccountType('Premium')`). Đang Premium thì **không** cần hai
khoá ấy. Client đọc nếu có; vắng → giữ hành vi cũ (coi như Premium mở).

### A2. Trụ 1 (bật / tắt) của 5 mã LIMIT đang mất trên đường đi

**Mã.** Admin-web cho bật / tắt Trụ 1 ở **mọi** hàng, kể cả 5 hàng LIMIT (`PermissionMatrixTable.jsx` — ô Trụ 1 dựng cho cả ba
khối bảng). Nhưng `permission.repository.js:127-128` đưa hàng LIMIT **chỉ** vào `limits` với `limit_value` → `is_enabled =
false` của `wallets` / `budgets` / `goals` / `bills` / `custom_categories` **không tới app**, và `requireFeature` chỉ đọc
`features` nên server cũng không thi hành. Admin bấm *"Khoá"* ví mà không có gì xảy ra ở đâu cả.

**Xin làm.** Hàng LIMIT có `is_enabled = false` → trả `limits[mã] = 0` (và `premiumLimits[mã] = 0` ở A1). Client đọc **0 = không
tạo thêm** từ commit `3ec874aa` (2026-10-27, người dùng chốt) — không phải đổi gì thêm. Ghi vào hợp đồng / tài liệu để Admin-web
và app cùng một nghĩa.

### A3. Premium không có `premium_expires_at` — ba chỗ ba nghĩa

| Chỗ | Đọc thế nào | Mã |
|---|---|---|
| `getSubscriptionInfo` | **Basic** (`isExpired = !isPremium \|\| !hasExpiry \|\| …`) → trả bảng Basic | `payment.service.js:809`, `:817` |
| `requireFeature` | **Premium** (chỉ hạ khi `premium_expires_at && < now`) | `feature-permission.middleware.js:32-35` |
| Client | **Premium còn hạn** (`hetHan == null` → `laPremium` đúng) | `trang_thai_goi.dart:39-40` |

**Xin làm.** Chốt một nghĩa (đề nghị: Premium không hạn **không tồn tại** — mọi đường nâng Premium đều ghi `premium_expires_at`;
hàng như thế là dữ liệu hỏng → coi là Basic ở cả hai chỗ server) và ghi vào hợp đồng. Client sẽ đổi theo ở một lượt sau (B4
trong spec client), không đổi trước khi có câu trả lời.

**Kiểm lại A.** Đăng nhập tài khoản Basic → `GET /api/payment/subscription-info` có `premiumFeatures` (31 khoá) và
`premiumLimits` (5 khoá); Admin-web tắt Trụ 1 `wallets` cột Basic → `limits.wallets === 0`; tài khoản Premium → không có hai khoá
mới.

## B — Đính chính `docs/Functional-Mobile/4_TRU_COT.md`

Đối chiếu từng khẳng định về **app** với mã `src/Client-app/lib` (2026-10-27): **67** khẳng định — 18 đúng, 16 đúng một phần,
**31 sai** (27 về client, 4 về backend), 2 không kiểm được. Gốc chung: client chỉ đọc `accountType`, `premiumExpiresAt`,
`features` (11 mã — 22 sau lượt thi công tới) và `limits` (5 trần); **không** đọc `scopes` / `scope_config` lẫn `policies` /
`downgrade_policy` — Trụ 3 và Trụ 4 hiện không có hiệu lực ở app. Xin sửa các dòng dưới (số dòng của `4_TRU_COT.md` HEAD).

### B1. Sai về app — xếp theo mức hại (PO / backend tưởng app bảo vệ thứ nó không bảo vệ)

| Dòng tài liệu | Tài liệu nói | Mã thật (`src/Client-app/lib/…`) |
|---|---|---|
| 598 | App chống tua lùi giờ bằng đối soát `max(date_transaction)` | **Không có.** Hết hạn so `DateTime.now()` với `hetHan` lưu trên máy (`premium/data/models/trang_thai_goi.dart:39-40`) — lùi giờ máy lúc offline là Premium hết hạn mở lại tới lượt hỏi `/subscription-info` kế |
| 65-67 | `GRACE_PERIOD_3D`: tự trả hoá đơn / tự trích mục tiêu chạy thêm 3 ngày sau hạn + thông báo khẩn | Hết hạn là **dừng ngay**, giữ công tắc (`premium/data/co_quyen_nen.dart:12-16`; băng *"Tạm dừng — cần Premium"*); nhắc gia hạn chỉ là dòng Trang chủ **trước** hạn 0–3 ngày (`premium/domain/nhac_het_han.dart:9-14`) |
| 62-64 | `READ_ONLY`: vẫn xem dự báo cũ, chỉ khoá nút *"Chạy phân tích lại"* | Basic: cả khối *Dự báo 30 ngày tới* thay bằng thẻ khoá (`analytics/presentation/pages/analytics_page.dart:180-186, 247-252`); dự báo tính tại chỗ, không lưu kết quả cũ, không có nút chạy lại |
| 44, 45, 68-70, 535 | Trụ 3 `scope_config` và Trụ 4 `downgrade_policy` (FALLBACK_DEFAULT đưa đồng bộ 2 s → 10 s, ảnh 5 → 1…) do app thi hành | App **không đọc** `scopes` / `policies` (grep = 0). Đồng bộ cố định 2 s mọi gói (`core/sync/sync_engine.dart:91`); không giới hạn ảnh theo gói |
| 191-193 (#9) | 1 ảnh / giao dịch Basic, 5 Premium; tìm kiếm 90 ngày | Không lối nào đính ảnh vào giao dịch; Sổ giao dịch xem mọi kỳ, không cắt 90 ngày |
| 201-203, 195-204 (#10) | `daily_voice_quota`, `max_seconds: 30`; ghi giọng nói bằng **Whisper** | Không hạn mức lượt; thời gian nghe là hằng client (`transaction/domain/do_im_lang.dart` `kNgheToiDa`); giọng nói = `speech_to_text` Android, dự phòng Gemma — không Whisper |
| 206-215 (#11) | OCR Basic 15 lượt / tháng, `max_file_mb`, `auto_crop` | ML Kit đúng; không bộ đếm lượt, không cắt tự động |
| 217-226 (#12) | Gắn danh mục hàng loạt tối đa 20 / 100 | Không trần (`transaction/domain/gan_hang_loat.dart`) |
| 250-252 (#14) | `max_depth` 2 / 3, `custom_icons`, `custom_colors` theo gói | Không xét gói |
| 255-264 (#15) | 5 / 25 từ khoá mỗi danh mục | Không trần số từ khoá |
| 271-280 (#16), 309-318 (#19) | Chu kỳ ngân sách / hoá đơn Basic chỉ `MONTHLY` | Mọi gói chọn `Week / Month / Quarter / Year` (`budget/data/models/budget_entity.dart:5-12`, `bill/domain/bill_recurrence.dart:10-16`) |
| 293-302 (#18) | `alert_threshold` 0,8, `daily_burn_rate` chỉ Premium | Ngưỡng theo từng ngân sách do người dùng đặt; *"Nên chi X/ngày"* mọi gói |
| 326-328 (#20) | `retry_on_fail: 3` | Không thử lại 3 lần; có *"trả bù trần 3 kỳ"* (khái niệm khác) |
| 331-340 (#21) | Basic nhắc [1] ngày, Premium [1, 3, 7]; giờ tuỳ chọn chỉ Premium | Mọi gói chọn 1 · 3 · 5 · 7 (`bill/domain/bill_nhac_truoc.dart:47`) và đổi được giờ nhắc |
| 347-356 (#22) | Cột mốc con, sắp xếp ưu tiên chỉ Premium | Cột mốc 25 / 50 / 75 % và kéo thả ưu tiên có cho mọi gói |
| 391-393 (#25) | Xuất PDF / **EXCEL** / CSV, watermark cho Basic | Chỉ PDF + CSV; Basic bị chặn hẳn (không *"xuất có watermark"*) |
| 396-405 (#26) | Màn sức khoẻ tài chính (FHS) | App **không có** màn FHS |
| 92-101 (#2) | Đăng nhập ngoại tuyến, `cache_token_days: 30` | Không có đăng nhập ngoại tuyến bằng thông tin xác thực; mở lạnh dùng phiên đã lưu rồi `verifySession()` |
| 119-128 (#4), 130-139 (#5) | Tổng tài sản 30 ngày / toàn thời gian; 4 / 8 phím tắt tuỳ biến | Không giới hạn theo gói; hàng nút nhanh cố định |
| 152-154 (#6) | Loại ví Basic Cash / Bank / **EWallet**, Premium thêm **Credit / Investment** | App chỉ `cash · bank · saving` cho mọi gói (`wallet/domain/wallet_type.dart`); CSDL `chk_wallet_type` chỉ nhận Cash / Bank / Saving / Banking |
| 445-454 (#30) | Mô hình `whisper-tiny`, `finance-slm` | Gemma 4 E2B `.litertlm` |
| 456-465 (#31) | `max_storage_mb` 500 / 2000 | Không trần dung lượng; mô hình ~2,4 GB |
| 472-481 (#32) | Ngân hàng Basic VCB / MB / TCB / ACB, Premium ALL | Danh sách trắng đã đo trên máy thật: **MB Bank · MoMo · ZaloPay**, không theo gói |
| 483-492 (#33) | Basic 1 khung giờ nhắc ghi chép, Premium 3; tin nhắn tuỳ biến | Một giờ nhắc, mặc định tắt (`notification/domain/notification_prefs.dart:167-168`) |
| 499-508 (#34) | Đếm ngược **15** phút | **10** phút (client `premium/data/models/don_thanh_toan.dart`; backend `payment.repository.js` cũng 10) |
| 510-519 (#35) | Tải hoá đơn (Premium) | Không có; chỉ *"Lưu mã QR"* |
| 526-535 (#36) | Debounce 10 s / 2 s, `cloud_photo_backup`, `realtime_priority` | 2 s mọi gói; không sao lưu ảnh; Socket.IO nối cho mọi tài khoản |
| 588 | Route chặn `/ai-assistant` | Không có route ấy; màn là `/ai-chat`, khoá nằm trong trang |
| 590-591 | Nút độc quyền mở **Modal BottomSheet** giới thiệu Premium | Thẻ khoá điều hướng sang trang `/premium?quyen=…` (`premium/presentation/widgets/nut_nang_cap.dart:34-38`) |

### B2. Sai về backend (gặp khi đối chiếu — xin soát lại phần của mình)

| Dòng tài liệu | Tài liệu nói | Mã thật (`src/Backend/…`) |
|---|---|---|
| 42, 610-619 | 403 `Feature_Forbidden` / `{error: "FEATURE_PERMISSION_DENIED", code: "FEATURE_LOCKED", feature_id}` | `{ code: 'FEATURE_DISABLED', featureId, accountType }` (`middleware/feature-permission.middleware.js:44-53`); client chỉ bắt `FEATURE_DISABLED` |
| 607-608 | `requireFeature` **bắt buộc cho mọi endpoint CRUD** | Chỉ gắn ở `chatbot.routes.js` (`ai_assistant`, `financial_health_fhs`) và `ocr.routes.js` (`ocr_receipt`); không CRUD ví / ngân sách / …; lỗi bất kỳ → `next()` (cho qua). Trần 3 / 3 / 3 / 3 / 5 **chỉ** client thi hành |
| 42, 45, 66 | `downgrade_policy` được áp khi hạ cấp | Chỉ lưu / đọc / trả (`admin.service.js`, `permission.repository.js:134`); job hạ cấp `scheduler.service.js` không xét |
| (seed `database/32`) | `scope_config` mang giá trị ngoài miền của app | `allowed_types` có EWallet / Credit / Investment; `supported_banks` VCB / TCB / ACB; `models` whisper / finance-slm; `formats` EXCEL — app không có, CSDL `chk_wallet_type` từ chối loại ví ấy |

### B3. Gợi ý cách viết lại

Tách mỗi tính năng thành hai phần: **"Server lưu / trả"** (đúng như mã backend) và **"App thi hành hiện nay"** — chỉ ghi điều mã
client làm (bảng B1 cột phải); các Trụ 3 / 4 chưa thi hành thì ghi *"chưa có hiệu lực ở app"* thay vì mô tả như đã chạy. Client
sẵn sàng soát bản viết lại.

**Kiểm lại B.** `grep -n "FEATURE_LOCKED\|max(date_transaction)\|GRACE_PERIOD_3D\|Whisper\|VCB" docs/Functional-Mobile/4_TRU_COT.md`
→ không còn câu nào tả app làm những việc ấy (giữ được nếu ghi rõ là *"chưa thi hành"*).
