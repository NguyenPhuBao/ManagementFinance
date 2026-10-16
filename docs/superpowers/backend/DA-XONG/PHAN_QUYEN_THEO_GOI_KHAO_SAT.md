# Mục 39 — Phân quyền chức năng theo loại tài khoản: khảo sát chức năng và bảng phân quyền

> ✅ **ĐÓNG — client soát bằng mã 2026-10-09, client chuyển sang `DA-XONG/`.** Năm bước đều xong: bước 3–4 backend
> (`main` @ `0eb4a05f`, gộp 2026-10-08; `database/22–23` đã áp CSDL dev), bước 5 client (2026-10-08, nghiệm thu OnePlus
> đạt — `docs/PREMIUM_FEATURE.md` mục 8). Đối chiếu mục 4 với mã backend:
>
> | Yêu cầu mục 4 | Mã backend | |
> |---|---|---|
> | 1. Mã quyền ổn định | `feature.id` (khoá chính) — đủ `wallets · budgets · goals · bills · custom_categories` + 12 quyền bật/tắt; admin đổi `account_type_permission.is_enabled` / `limit_value`, không đổi khoá | ✅ |
> | 2. Giá trị đã áp cho chính tài khoản | `payment.service.js` `getSubscriptionInfo`: `effectiveType` = Premium chỉ khi còn hạn, rồi `getPermissionsByAccountType(effectiveType)` | ✅ |
> | 3. Thiếu trường = mặc định client | CSDL không có hàng nào → `DEFAULT_PERMISSIONS` của `permission.repository.js`; client vẫn rơi về mặc định khi thiếu khoá | ✅ |
> | 4. "Không giới hạn" viết rõ | `null` (Premium mặc định `null` cả năm trần); client đọc `int?` | ✅ |
> | 5. Tín hiệu khi admin đổi cấu hình | `core/socket.js:378` phát `account.permissions_updated` **và** `account.upgraded` tới mọi client đang nối | ✅ |
>
> Mục 3.3 quy tắc 3 giữ đúng: `requireFeature` chỉ gắn ở route chatbot trực tuyến và OCR server, **không** ở `/sync/push`.
> Câu hỏi mục 6 — backend chọn: hai gói (bảng quyền nhận `account_type` tới 20 ký tự nhưng `account.Type` vẫn
> `varchar(7)`); quyền theo **gói**, không ghi đè theo tài khoản; trả ở `/payment/subscription-info`; Premium **có thể** bị
> admin đặt trần (client đã theo — trần `int?`); **chốt** `bills` (Basic 3) và `custom_categories` (Basic 5). Mục 5 (đường
> vòng qua trần) là việc client và **cố ý chưa chặn** — spec `specs/2026-10-08-phan-quyen-tinh-nang-client-design.md`
> dòng 176 xếp nó vào *không làm*; ba đường vẫn mở như mục 5 tả (soát mã 2026-10-09). Câu *"chưa có trong mã"* ở mục 3.1 và *"chưa trả `limits`"* ở mục
> 0 / 1.1 là ảnh chụp 2026-10-07.

**Người viết:** Client-app · **Ngày:** 2026-10-07 · **Mức:** thông tin đầu vào — **không chặn client**.

**Gửi Backend + Admin-web:** tài liệu này trả lời bước 1 và bước 2 của việc *phân quyền chức năng động theo loại tài
khoản*. Bước 3 (CSDL) và bước 4 (màn cấu hình ở Admin-web) là việc của Backend và Admin-web; bước 5 (ràng buộc ở
Client-app) là việc của client, làm sau khi bước 3 có hợp đồng API.

| Bước | Nội dung | Ai làm | Trạng thái |
|---|---|---|---|
| 1 | Khảo sát đặc trưng các chức năng | Client-app | ✅ mục 2 dưới đây |
| 2 | Chức năng nào **khoá**, chức năng nào **giới hạn**, bảng phân quyền | Client-app | ✅ mục 3 dưới đây |
| 3 | Kế hoạch + CSDL khớp với bảng phân quyền | Backend | ⏳ chờ |
| 4 | Kế hoạch + tính năng phân quyền động ở Admin-web | Backend / Admin-web | ⏳ chờ |
| 5 | Ràng buộc từng tính năng ở Client-app theo bảng | Client-app | Một phần đã có (mục 1.2); phần còn lại chờ bước 3 |

> Mọi chỗ dẫn mã dưới đây đã đọc lại ngày 2026-10-07. Tài liệu là ảnh chụp — đối chiếu mã trước khi kết luận.

---

## 0. Tóm tắt (30 giây)

- App có **bốn loại chức năng**: lõi (không phân quyền) · tài nguyên đếm được (**giới hạn số lượng**) · AI dùng mô hình
  Gemma (**khoá / mở**) · tiện ích rẻ chạy cục bộ (người dùng đã chốt **mở cho mọi gói**).
- Bảng phân quyền **đã chạy trong client** (chốt 2026-10-06): Basic tối đa **3 ví · 3 ngân sách · 3 mục tiêu** đang
  hoạt động; **Trợ lý AI** và **Nhập nhanh bằng câu** khoá với Basic. Premium không giới hạn, mở hết.
- Hiện **Backend không chặn chức năng nào theo gói**, và `/payment/subscription-info` **chưa trả `limits`** — client
  dùng hằng 3/3/3. Muốn phân quyền **động** thì cần một nguồn cấu hình ở server mà client đọc được (mục 4).
- Ba việc cần biết trước khi thiết kế bước 3: hai quyền AI **chưa có mã quyền**; có **đường vòng qua trần** (mục 5); và
  **không được chặn ở `/sync/push`** (mục 3.3).

---

## 1. Hiện trạng (đo bằng đọc mã)

### 1.1 Phía Backend

- `account.Type` là `varchar(7)`, mặc định `'Basic'`, giá trị `'Basic' | 'Premium'`; hạn ở `account.premium_expires_at`
  (`prisma/schema.prisma`, dòng 29 và 32).
- `GET /payment/subscription-info` trả đúng bốn trường (`modules/payment/payment.service.js:234-239`):
  ```json
  { "accountType": "Premium", "premiumExpiresAt": "...", "daysRemaining": 29, "isExpired": false }
  ```
  **Không** có `limits`, `price`, `packageDays` (đã xin ở mục 38 `CLIENT_PREMIUM_PAYOS.md`, có mặc định, không chặn).
- Không middleware hay service nào chặn chức năng theo gói.

### 1.2 Phía Client-app (đã chạy)

| Thứ | Ở đâu |
|---|---|
| Trần 3/3/3 và luật *"được tạo thêm không"* (`conTaoDuoc`) | `lib/features/premium/domain/tran_goi.dart` |
| Đọc `limits` từ server nếu có (`{wallets, budgets, goals}`, ô thiếu / không dương → 3) | `TranGoi.tuJson`, `trang_thai_goi.dart:103` |
| Phép đếm *"đang hoạt động"* | `lib/features/premium/data/dem_dang_hoat_dong.dart` |
| Cửa chặn duy nhất cho ba loại tài nguyên: `redirect` ở ba route tạo | `app_router.dart:256` (`/wallets/add`), `:281` (`/budget/rules`), `:404` (`/goals/add`) |
| Khoá Trợ lý AI (xét gói **trước** mọi lý do khác) | `ai_chat_page.dart:102-106` (`lyDoKhoa`) |
| Khoá Nhập nhanh bằng câu | `add_transaction_page.dart:138` |
| Cache gói theo tài khoản, so giờ máy (Premium offline vẫn dùng được) | `lib/features/premium/data/goi_repository.dart` |

---

## 2. Bước 1 — Khảo sát đặc trưng các chức năng

### 2.1 Tiêu chí khảo sát

| Tiêu chí | Câu hỏi | Vì sao quan trọng cho phân quyền |
|---|---|---|
| (a) Đếm được | Có số bản ghi để đặt trần không? | Đếm được → **giới hạn** được |
| (b) Vai trò | Lõi hay giá trị gia tăng? Chặn thì app còn dùng được không, dữ liệu có lệch không? | Lõi → **không phân quyền** |
| (c) Chạy ở đâu, tốn gì | Trên máy hay server? Cần mô hình nặng không? | Tốn nhiều → ứng viên **khoá** |
| (d) Đồng bộ | Bản ghi có đi qua `/sync/push` không? | Có → server chỉ thấy **sau khi** đã tạo, không chặn được ở đó |
| (e) Vòng đời | Bản ghi có lúc hết *"đang hoạt động"* không? | Quyết định **phép đếm** của trần |

### 2.2 Bảng khảo sát

| Nhóm | Chức năng | (a) Đếm | (b) Vai trò | (c) Chạy ở | (d) Đồng bộ | (e) Vòng đời |
|---|---|---|---|---|---|---|
| **Lõi** | Đăng ký / đăng nhập / OTP / xoá tài khoản | — | Lõi | Server | — | — |
| | Ghi giao dịch thu · chi · chuyển, sổ giao dịch, lọc | Có, nhưng là thao tác hằng ngày | Lõi | Máy | Có | Xoá mềm |
| | Đồng bộ hai chiều + socket | — | Lõi (offline-first) | Máy ↔ server | — | — |
| | Danh mục (bản sao mặc định + tự tạo + từ khoá) | Có | Nền của giao dịch | Máy | Có | Xoá mềm |
| **Tài nguyên đếm được** | Ví (tiền mặt / ngân hàng / tiết kiệm) | Có | Nền của giao dịch | Máy | Có | Lưu trữ → nhả chỗ |
| | Ngân sách | Có | Giá trị gia tăng | Máy | Có | Hết hạn → nhả chỗ |
| | Mục tiêu tiết kiệm (+ trích tự động) | Có | Giá trị gia tăng | Máy | Có | Đạt mục tiêu → nhả chỗ |
| | Hoá đơn (lặp, tự trả, ân hạn) | Có — ⚠️ **mỗi kỳ là một hàng** | Giá trị gia tăng | Máy | Có | Trả / bỏ qua kỳ → sinh hàng kỳ sau |
| **Xem / phân tích** | Trang chủ, Phân tích (biểu đồ, dự báo 30 ngày, lịch chi, chi bất thường), khối Nhận xét | — | Giá trị gia tăng | Máy, tính từ dữ liệu sẵn có | — | — |
| | Xuất báo cáo PDF / CSV | Đếm lượt được | Giá trị gia tăng | Máy | — | — |
| **Thông báo** | Nhắc hoá đơn / ngân sách / mục tiêu, tổng kết tuần, khoản chi lớn | — | Giá trị gia tăng | Máy (bảng cục bộ) | Không | — |
| | Đọc biến động số dư, chia sẻ biên lai (đọc chữ trên ảnh), nhắc sau khi dùng app ngân hàng | — | Giá trị gia tăng | Máy, cần quyền hệ điều hành + màn đồng ý | Không | — |
| **Gợi ý thống kê nhẹ** | Gợi ý danh mục (theo ghi chú, theo số tiền), gắn danh mục hàng loạt, gợi ý hoá đơn từ khoản lặp, đề xuất từ khoá, ví chọn sẵn, đề xuất cân đối ngân sách | — | Giá trị gia tăng | Máy, luật / Naive Bayes, rất rẻ | Không | — |
| **AI dùng mô hình** | Trợ lý AI hỏi đáp + lệnh tạo hoá đơn / mục tiêu / ngân sách | — | Giá trị gia tăng | Máy, Gemma 2,41 GB | Không | — |
| | Nhập nhanh bằng câu (màn Thêm giao dịch) | — | Giá trị gia tăng | Máy, luật trước, Gemma lấp ô thiếu | Không | — |
| **Gói** | Mua Premium (PayOS), lịch sử mua | — | — | Server | — | — |

### 2.3 Bốn loại rút ra

1. **Lõi** — ghi giao dịch, đồng bộ, tài khoản, danh mục, mua gói. Chặn thì app mất ý nghĩa hoặc dữ liệu hai máy lệch.
   **Không đưa vào bảng phân quyền.**
2. **Tài nguyên đếm được, có vòng đời** — ví, ngân sách, mục tiêu (hoá đơn là ứng viên). → **Giới hạn số lượng đang
   hoạt động**.
3. **Năng lực tốn tài nguyên** — chỉ AI dùng Gemma. → **Khoá / mở**.
4. **Tiện ích rẻ, chạy cục bộ** — phân tích, thông báo, gợi ý, xuất báo cáo. Khoá được về kỹ thuật, nhưng người dùng
   (PO) đã chốt ngày 2026-10-06 **mở cho mọi gói**.

---

## 3. Bước 2 — Bảng phân quyền chức năng

### 3.1 Phần đã chạy trong client (chốt 2026-10-06)

| Mã quyền (đề xuất) | Chức năng | Kiểu | Basic | Premium | Phép đếm *"đang hoạt động"* | Chỗ chặn ở client | Khi hạ cấp |
|---|---|---|---|---|---|---|---|
| `wallets` | Tạo ví | Giới hạn số lượng | 3 | Không giới hạn | Chưa xoá mềm **và** chưa lưu trữ | Route `/wallets/add` | Giữ nguyên, chỉ không tạo thêm |
| `budgets` | Tạo ngân sách | Giới hạn số lượng | 3 | Không giới hạn | Chưa xoá mềm **và** chưa hết hạn | Route `/budget/rules` không kèm `?id` (có `?id` là sửa → cho qua) | Như trên |
| `goals` | Tạo mục tiêu | Giới hạn số lượng | 3 | Không giới hạn | Chưa xoá mềm **và** chưa đạt (`daHoanThanh`) | Route `/goals/add` | Như trên |
| `ai_assistant` *(chưa có trong mã)* | Trợ lý AI + lệnh tạo | Khoá / mở | Khoá ô nhập + chip, nút Nâng cấp | Mở | — | `lyDoKhoa` màn Trợ lý AI | Khoá lại ở lần đọc gói kế tiếp |
| `ai_quick_input` *(chưa có trong mã)* | Nhập nhanh bằng câu | Khoá / mở | Ô mờ, nút Điền → Nâng cấp | Mở | — | Màn Thêm giao dịch | Như trên |

Ba khoá `wallets` · `budgets` · `goals` **đã là tên client đọc** trong `limits` (`TranGoi.tuJson`). Hai khoá AI là đề
xuất — client hiện chỉ đọc *"có phải Premium không"*, nên admin chưa cấu hình riêng hai quyền này được.

### 3.2 Không phân quyền (PO đã chốt)

| Chức năng | Lý do |
|---|---|
| Đồng bộ (cả năm nguồn kích hoạt, kể cả socket `sync.completed`) | Lõi offline-first; tách theo gói làm dữ liệu hai máy của Basic lệch nhau |
| Ghi giao dịch, danh mục, tài khoản, mua gói | Lõi |
| Khối Nhận xét, gợi ý danh mục, gợi ý hoá đơn, đề xuất cân đối | Luật / thống kê nhẹ trên máy, gần như không tốn gì |
| Xuất báo cáo PDF / CSV | Như trên |
| Đọc chữ biên lai, đọc biến động số dư, mọi thông báo | Chạy cục bộ, đã có màn đồng ý riêng |

### 3.3 Bốn quy tắc chung (đã nằm trong mã client — xin giữ khi thiết kế bước 3–4)

1. **Bằng trần là vượt:** có 3/3 thì không tạo được cái thứ tư (`dangCo >= tran`).
2. **Client thi hành, server quyết con số.** Server chỉ cần trả cấu hình; client đọc và chặn.
3. **Không chặn ở `/sync/push`.** Server chỉ thấy bản ghi **sau khi** người dùng đã tạo trên máy (offline-first). Từ
   chối ở đó thì bản ghi kẹt hàng đợi đẩy vĩnh viễn và mọi giao dịch trỏ vào nó vỡ khoá ngoại theo (cùng họ lỗi G31 đã gặp
   với tên quá dài). Hai máy Basic cùng offline tạo ví thứ ba → có 4 ví: **chấp nhận**, vẫn dùng được, chỉ không tạo thêm.
4. **Hạ cấp không mất dữ liệu.** Người có 5 ví khi hết Premium vẫn dùng đủ 5 ví.

### 3.4 Ứng viên nếu muốn mở rộng (chưa chốt — mặc định **Mở**)

| Mã quyền (đề xuất) | Chức năng | Kiểu | Lưu ý cho thiết kế |
|---|---|---|---|
| `bills` | Tạo hoá đơn | Giới hạn số lượng | ⚠️ Phải đếm **chuỗi hoá đơn còn mở**, không đếm hàng — mỗi kỳ của hoá đơn lặp là một hàng mới (`bill.Previous_bill_id` nối các kỳ) |
| `custom_categories` | Tạo danh mục riêng | Giới hạn số lượng | Chỉ đếm danh mục người dùng tự tạo; **bản sao danh mục mặc định** (seed theo tài khoản) không tính |

---

## 4. Điều client cần từ bước 3–4 (đề xuất hợp đồng — Backend quyết hình dạng cuối)

Client cần **một** chỗ đọc toàn bộ quyền của tài khoản đang đăng nhập. Lối ít đổi nhất là mở rộng
`/payment/subscription-info` (client đã gọi nó khi đăng nhập, khi app trở lại sau 5 phút, khi nhận socket
`account.upgraded`, và sau đơn PAID):

```json
{
  "accountType": "Basic",
  "premiumExpiresAt": null,
  "daysRemaining": 0,
  "isExpired": true,
  "limits":   { "wallets": 3, "budgets": 3, "goals": 3 },
  "features": { "ai_assistant": false, "ai_quick_input": false }
}
```

Yêu cầu, theo thứ tự quan trọng:

1. **Mã quyền ổn định** — `wallets`, `budgets`, `goals`, `ai_assistant`, `ai_quick_input` (thêm `bills`,
   `custom_categories` nếu chốt mục 3.4). Admin đổi **giá trị**, không đổi **tên khoá**.
2. **Trả giá trị đã áp cho chính tài khoản ấy** (đã xét gói và còn hạn hay không), không bắt client tự ghép bảng gói ×
   quyền.
3. **Thiếu trường = dùng mặc định của client** (3/3/3, AI khoá với Basic). Client đang làm đúng vậy với `limits`; bản
   backend cũ không trả trường mới vẫn chạy.
4. **"Không giới hạn" cần một cách viết rõ** — đề xuất `null` hoặc bỏ khoá. ⚠️ Hiện `TranGoi.tuJson` coi ô thiếu /
   không dương là **3**, và Premium **luôn** được tạo bất kể con số. Nếu bước 4 cho phép admin đặt trần cho cả Premium,
   client phải đổi luật ấy ở bước 5 — xin ghi rõ trong hợp đồng.
5. **Khi admin đổi cấu hình**, phát một tín hiệu socket tới các tài khoản bị ảnh hưởng (có thể dùng lại
   `account.upgraded`, client coi nó là **tín hiệu** và gọi lại API, không đọc payload). Không có tín hiệu thì client
   nhận cấu hình mới ở lần làm mới kế tiếp (tối đa vài phút khi app đang mở).

---

## 5. Đường vòng qua trần (thông tin cho bước 5 — client sẽ làm)

Hiện chỉ **ba route tạo** có chặn (`grep` ngày 2026-10-07: ngoài `lib/features/premium/`, chỉ `app_router.dart` gọi
`redirectTaoTheoGoi`). Đọc mã thấy ba đường làm một bản ghi **trở lại** *"đang hoạt động"* mà không qua route tạo
(**chưa chạy thử**):

| Đường | Vì sao vòng được |
|---|---|
| Bỏ lưu trữ ví khi đã có 3 ví đang hoạt động | `WalletLocalDataSource.setArchived(luuTru: false)` không xét gói |
| Sửa mục tiêu đã đạt, nâng số tiền đích | `daHoanThanh = isCompleted \|\| progress >= 1.0` — nếu `isCompleted` chưa bật thì nâng đích là mục tiêu hoạt động lại |
| Sửa ngân sách đã hết hạn, gia hạn ngày kết thúc | `/budget/rules?id=` là đường sửa nên cố ý cho qua |

Không cần Backend làm gì cho mục này — ghi ra để bảng phân quyền ở bước 3 định nghĩa *"đang hoạt động"* đúng như client
đếm (mục 3.1), tránh hai đầu đếm khác nhau.

---

## 6. Câu hỏi cho Backend (client có mặc định — không trả lời thì client làm theo mặc định)

| # | Câu hỏi | Mặc định của client |
|---|---|---|
| 1 | Giữ hai gói cố định (`Basic` / `Premium`) hay cho admin tạo thêm gói? | Hai gói. ⚠️ `account.Type` là `varchar(7)` — tên gói dài hơn 7 ký tự sẽ không vừa |
| 2 | Quyền gắn theo **gói** hay cho phép **ghi đè theo từng tài khoản**? | Theo gói |
| 3 | Trả quyền ở `/payment/subscription-info` hay endpoint riêng? | `/payment/subscription-info` (mục 4) |
| 4 | Có cần đặt trần cho Premium không? | Không — Premium không giới hạn, mở hết |
| 5 | Có chốt `bills` / `custom_categories` (mục 3.4) không? | Không — giữ Mở |

---

## 7. Đối chiếu lại

- Bảng mục 3.1 khớp mã client: đọc `tran_goi.dart` (`TranGoi.macDinh`), `dem_dang_hoat_dong.dart` (ba phép đếm),
  `app_router.dart:256,281,404` (ba `redirect`), `ai_chat_page.dart:102-106`.
- Hiện trạng Backend mục 1.1: `payment.service.js:234-239` (bốn trường trả về), `schema.prisma:29,32`.
- Quyết định gốc của người dùng (8 câu, 2026-10-06): `docs/PREMIUM_FEATURE.md` mục 1–2 (phía client).
