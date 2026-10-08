# Phân quyền tính năng theo gói — phần Client-app (bước 5 của đơn 39)

**Ngày:** 2026-10-08 · **Trạng thái:** thiết kế đã duyệt trong chat (ba phần), chờ người dùng đọc lại bản viết.
**Đầu vào:** đơn `CAN-LAM/PHAN_QUYEN_THEO_GOI_KHAO_SAT.md` (mục 39, client viết 2026-10-07); backend làm bước 3–4 ở
`main` @ `0eb4a05f` (migration 22–23, `permission.repository.js`, trang `/permissions` Admin-web); CSDL dev đã áp 21–23
ngày 2026-10-08. Tài liệu tính năng: `docs/PREMIUM_FEATURE.md`.

---

## 1. Bối cảnh

`GET /payment/subscription-info` nay trả, cho **gói đang hiệu lực** của tài khoản (`effectiveType` — Premium hết hạn
thì là Basic):

```json
{ "accountType": "Basic", "premiumExpiresAt": null, "daysRemaining": 0, "isExpired": true,
  "limits":   { "wallets": 3, "budgets": 3, "goals": 3, "bills": 3, "custom_categories": 5 },
  "features": { "ai_assistant": false, "ai_quick_input": false, "ocr_receipt": true, "ai_edge_model": false,
                "smart_budget_rebalancing": false, "financial_health_fhs": true, "export_reports": false,
                "cashflow_forecast": false, "anomaly_spending_insights": false, "bill_auto_pay": false,
                "goal_auto_deposit": false, "bank_notification_parser": true } }
```

Premium: mọi trần `null` (không giới hạn), mọi quyền `true`. Admin đổi được từng ô ở Admin-web `/permissions`; đổi
xong backend phát socket `account.permissions_updated`, client đã nối nó sang `RealtimeEvent.taiKhoanNangCap` →
`GoiRepository.lamMoi()`.

Client (trước lượt này) mới thi hành **3 trần** (ví · ngân sách · mục tiêu, cửa `redirectTaoTheoGoi`) và **2 quyền**
(Trợ lý AI, Nhập nhanh). Backend đã tự sửa 7 tệp client (`TranGoi` thêm `hoaDon` · `danhMucRieng`, `TrangThaiGoi.
quyenTinhNang`, getter `GoiCubit.duoc…`) nhưng **chỉ hai getter có chỗ gọi**, và mang **ba lỗi**:

1. `TrangThaiGoi.duocDung` đọc bảng quyền đã lưu **không xét hạn**: Premium hết hạn lúc offline giữ bảng Premium →
   mọi tính năng vẫn mở.
2. `DemDangHoatDong` đếm danh mục riêng = `!isDefault && idaccount == id` — **tính luôn 13 bản sao danh mục mặc định**
   mà `DefaultCategorySeeder` tạo cho mỗi tài khoản (`isDefault: false`). Với trần 5, mọi tài khoản Basic không tạo
   được danh mục nào.
3. `DemDangHoatDong` đếm hoá đơn = `!isPaid && payStatus != 'Payed'` — tính cả kỳ **`Skipped`** (bỏ qua kỳ) là hoá đơn
   đang mở.

## 2. Quyết định của người dùng (2026-10-08)

| # | Câu hỏi | Chốt |
|---|---|---|
| 1 | Nghe bảng quyền server hay giữ chốt 06/10 *"tiện ích rẻ mở cho mọi gói"*? | **Theo server (admin quyết); thiếu khoá thì MỞ** — trừ ba quyền AI giữ mặc định 06/10 là khoá với Basic |
| 2 | Tính năng bị tắt hiện thế nào với Basic? | **Hiện khoá + nút Nâng cấp** (giữ chỗ tính năng) |
| 3 | Đã bật tự trả / tự trích rồi về Basic? | **Dừng chạy, giữ công tắc** — không sửa dữ liệu; lên lại Premium chạy tiếp |
| 4 | Bảng quyền ↔ chỗ trong app (mục 3) | Duyệt nguyên bảng |
| 5 | Kiến trúc (mục 4), kiểm thử · giao diện · rủi ro (mục 6–8) | Duyệt |

## 3. Bảng quyền ↔ chỗ trong app

| Mã server | Kiểu | Chỗ thi hành | Thiếu khoá thì |
|---|---|---|---|
| `wallets` · `budgets` · `goals` | Trần | Đã có — `redirectTaoTheoGoi` ở `/wallets/add`, `/budget/rules` (không `?id`), `/goals/add` | 3 (như cũ) |
| `bills` | Trần | `redirectTaoTheoGoi(LoaiTran.hoaDon)` ở `/bills/add` — phủ cả thẻ *Có vẻ là khoản lặp* (B2), lệnh tạo C3, deeplink | **Không giới hạn** |
| `custom_categories` | Trần | `redirectTaoTheoGoi(LoaiTran.danhMucRieng)` ở `/categories/add`, `/categories/child/new`, `/categories/group/new` | **Không giới hạn** |
| `export_reports` | Bật/tắt | Cửa route mới `redirectTheoQuyen` ở `/export-report` | Mở |
| `cashflow_forecast` | Bật/tắt | Khối *Dự báo 30 ngày tới* (`analytics_page.dart`) → thẻ khoá | Mở |
| `anomaly_spending_insights` | Bật/tắt | Câu *chi bất thường* ở khối Nhận xét trang Phân tích → **chỉ khi thật có bất thường**, thay bằng một dòng 🔒 *"Có khoản chi bất thường kỳ này — dành cho Premium"* | Mở |
| `smart_budget_rebalancing` | Bật/tắt | Thẻ *Đề xuất cân đối* (`budget_tabs_view.dart`, `TheKeHoach`) → thẻ khoá; thông báo `budgetRebalance` thôi sinh | Mở |
| `bill_auto_pay` | Bật/tắt | Công tắc *Tự trả* (form thêm / sửa hoá đơn) → công tắc khoá; `BillAutoPayRunner` bỏ lượt | Mở |
| `goal_auto_deposit` | Bật/tắt | Công tắc *Trích tự động* (form mục tiêu, `goal_config_card.dart`) → công tắc khoá; `GoalAutoDepositRunner` bỏ lượt | Mở |
| `ai_edge_model` | Bật/tắt | Màn *Cài đặt AI* `/ai-settings` (tải mô hình, công tắc AI trên máy) → khoá; phần Gemma của `/quet` | **Khoá với Basic** |
| `ocr_receipt` | Bật/tắt | Nút *Quét* (Trang chủ, `moQuet`) + đường *Chia sẻ → Ghi vào FlowMoney* (`NhapBienLai`) | Mở |
| `bank_notification_parser` | Bật/tắt | Công tắc *Đọc biến động số dư* (D1) + `NhapBienDong` | Mở |
| `ai_assistant` · `ai_quick_input` | Bật/tắt | Đã có (`lyDoKhoa` màn Trợ lý AI; ô Nhập nhanh) — đổi sang đọc qua `duocDung` | **Khoá với Basic** |
| `financial_health_fhs` | — | **Bỏ qua**: app không có màn FHS (đó là chatbot trực tuyến của backend, client chưa nhận) | — |

*Nhắc ghi sau khi dùng app ngân hàng* **không** thuộc quyền nào — để mở.

Ba chốt chung:

- **Premium còn hạn → mở hết**, bỏ qua mọi giá trị trong bảng đã lưu; không xét trần.
- **Hết hạn lúc offline → mặc định Basic** (cột *"Thiếu khoá thì"*), không dùng bảng Premium đã lưu — đóng lỗi 1.
- **Quyền chỉ chặn việc TẠO / BẬT mới.** Dữ liệu đang có giữ nguyên (luật *hạ cấp không mất dữ liệu* của đơn 39 §3.3).

## 4. Kiến trúc

Ba hướng đã cân nhắc: (A, chọn) một định nghĩa quyền + một widget khoá + cửa route sẵn có; (B) mỗi màn tự gọi getter
`GoiCubit.duoc…` — rải luật ra ~10 chỗ, và lỗi 1 nằm đúng ở getter ấy; (C) chỉ chặn ở route — không đủ, khối Dự báo,
công tắc, thẻ cân đối nằm trong trang.

### 4.1 Domain thuần — `premium/domain/quyen_tinh_nang.dart`

- `enum MaQuyen` — 11 quyền bật/tắt ở mục 3 (bỏ `financial_health_fhs`), mỗi giá trị mang `maServer` và
  `macDinhKhiThieu` (`bool`).
- `bool duocDung(MaQuyen ma, TrangThaiGoi goi, DateTime now)` — **định nghĩa duy nhất**:
  1. `goi.laPremium(now)` → `true`.
  2. Bảng đã lưu là **của Basic** — tức tài khoản **không** phải Premium còn hạn **tại lúc nhận** bảng:
     `!goi.laPremium(goi.nhanLuc)` — và có khoá `ma.maServer` → giá trị ấy. ⚠️ **Không** xét bằng `goi.loai`: server
     trả `accountType` là gói **gốc** (`'Premium'` cả khi đã hết hạn, `payment.service.js:238`) còn `features` là bảng
     của gói **hiệu lực** (`effectiveType`, dòng 235) — Premium hết hạn ở server thì `loai` vẫn premium mà bảng là của
     Basic.
  3. Còn lại (Basic thiếu khoá; Premium **hết hạn sau lúc nhận**, bảng lưu là của Premium) → `ma.macDinhKhiThieu`.
- `TrangThaiGoi.duocDung(String, …)` của backend **bỏ**; mọi chỗ đọc `quyenTinhNang` đi qua hàm trên (test quét
  `lib/` canh — mục 6).
- `TranGoi`: `macDinh` đổi `hoaDon` · `danhMucRieng` → `null` (thiếu khoá = không giới hạn, chốt 1); `conTaoDuoc`
  giữ luật Premium luôn được, `tran == null` → được (đã có).

### 4.2 Đếm — `premium/data/dem_dang_hoat_dong.dart`

- **Hoá đơn:** số hàng chưa xoá mềm mà **còn phải trả** theo vị từ của `bill/domain/bill_pay_status.dart` (một chuỗi
  hoá đơn lặp có đúng một kỳ đang mở; kỳ `Skipped` / `Payed` không tính) — đóng lỗi 3. Không viết lại vế so chuỗi.
- **Danh mục riêng:** hàng của tài khoản, chưa xoá mềm, `isDefault == false`, và **tên chuẩn hoá không trùng tên nào
  của bộ khuôn mặc định** (`categoryDao.getBackendDefaults()`, so bằng `normalizeCategoryName` — cùng phép seeder dùng
  để nhận bản sao) — đóng lỗi 2. Nhóm do người dùng tạo tính là danh mục riêng.

### 4.3 Ba kiểu thi hành

1. **Route.**
   - `redirectTaoTheoGoi(LoaiTran.hoaDon)` gắn vào `/bills/add`; `redirectTaoTheoGoi(LoaiTran.danhMucRieng)` vào ba
     route tạo danh mục. Route sửa (`/bills/:id/edit`, `/categories/child/:id/edit`, …) không chặn.
   - Cửa mới `redirectTheoQuyen(MaQuyen)` (cạnh `chan_theo_goi.dart`, cùng khuôn đọc `sl` lúc chạy) cho
     `/export-report` → `/premium?quyen=export_reports`.
2. **Trong trang — widget `KhoaTheoQuyen`** (`premium/presentation/widgets/`):
   - `KhoaTheoQuyen(ma:, child:)` đọc `GoiCubit` (`context.watch`, không provider → **không khoá**, như quy ước hiện
     có cho test cũ). Không có quyền → **thẻ khoá**: biểu tượng 🔒, tên tính năng (`MaQuyen.ten`), *"dành cho Premium"*,
     `NutNangCap(quyen: ma)`.
   - Biến thể công tắc `CongTacTheoQuyen`: không có quyền → công tắc mờ (không đổi giá trị), chạm → `/premium?quyen=…`;
     nếu giá trị đang lưu là **bật** thì kèm dòng *"Tạm dừng — cần Premium"* (chốt 3), ngược lại *"Cần Premium"*.
3. **Bộ chạy nền.** `BillAutoPayRunner`, `GoalAutoDepositRunner` và luật thông báo `budgetRebalance` nhận một hàm
   `bool Function(MaQuyen) coQuyen` (DI nối sang `duocDung(…, GoiRepository.hienTai, now)`); không có quyền → bỏ lượt,
   **không ghi gì**, không đổi mốc chạy. Có quyền lại → lượt kế chạy như cũ (luật trả bù sẵn có, tối đa 3 kỳ).
   `NhapBienDong` / `NhapBienLai` cũng hỏi `coQuyen` trước khi nhập.

### 4.4 Màn Nâng cấp

`/premium` nhận thêm `?quyen=<maServer>` (cạnh `?tran=`): câu mở đầu *"<Tên tính năng> là tính năng Premium."*. Mã lạ →
màn như không có tham số. `NutNangCap` nhận `quyen:` cạnh `tran:`.

### 4.5 Dọn mã backend viết

Hai chỗ AI (`ai_chat_page.dart`, `add_transaction_page.dart`) đổi từ `GoiCubit.duocDungAi…` sang
`duocDung(MaQuyen.…)`. Mọi getter `duoc…` của `GoiCubit` **bỏ** — chỉ còn một cửa. Thêm `GoiCubit.coQuyen(MaQuyen)`
mỏng gọi `duocDung(…, state, _now())`.

## 5. Dữ liệu và đồng bộ

Không đổi schema, không đổi payload, không thêm bảng. `TrangThaiGoi` đã lưu `quyenTinhNang`, `hetHan` và `nhanLuc` trong
kho bảo mật theo tài khoản — đủ cho phép xét ở 4.1 bước 2.

## 6. Kiểm thử (TDD — ca đỏ trước)

- `duocDung` — bảng ca: Premium còn hạn + bảng ghi `false` → mở · Premium **hết hạn offline**, bảng Premium → mặc định
  Basic (ca đóng lỗi 1) · Basic có khoá → theo khoá · Basic thiếu khoá → `macDinhKhiThieu` (AI khoá, còn lại mở) ·
  **Premium hết hạn ở server** (`accountType` Premium, `hetHan` đã qua lúc nhận, bảng Basic) → theo bảng · mỗi
  `MaQuyen` có `maServer` khác nhau và khớp danh sách 11 mã server.
- `DemDangHoatDong`: 13 bản sao mặc định + 2 danh mục tự tạo → **2** (ca đóng lỗi 2); kỳ `Skipped` không tính (ca đóng
  lỗi 3); chuỗi hoá đơn lặp đã trả kỳ cũ, kỳ mới mở → **1**.
- Cửa route: Basic đủ 3 hoá đơn mở → `/bills/add` chuyển `/premium?tran=hoa_don`; `/bills/:id/edit` qua; Premium qua;
  `/export-report` bị tắt → `/premium?quyen=export_reports`.
- Bộ chạy: không quyền → 0 giao dịch, cờ `autoPay` / trích giữ nguyên, mốc không đổi; có quyền lại → chạy.
- Thông báo `budgetRebalance`: không quyền → không ứng viên.
- Widget: `KhoaTheoQuyen` / `CongTacTheoQuyen` hiện / ẩn đúng; đo ở **360 dp và 320 dp bằng font thật** (helper
  `test/helpers/font_that.dart`, khuôn G74–G78) không cắt chữ; dựng bằng `AppTheme.lightTheme` (bẫy 4.11).
- **Test quét `lib/` thứ 21:** `quyenTinhNang` chỉ được đọc ở `premium/domain/quyen_tinh_nang.dart` (và nơi đọc/ghi
  kho, `trang_thai_goi.dart`); chuỗi mã quyền server (`'export_reports'`, …) chỉ nằm ở `MaQuyen`.

## 7. Giao diện — Stitch trước khi dựng

Ba mẫu, người dùng xác nhận rồi mới viết widget: (1) thẻ 🔒 trong trang, mẫu là khối Dự báo 30 ngày; (2) công tắc khoá
ở form hoá đơn với dòng *"Tạm dừng — cần Premium"*; (3) màn Nâng cấp mở đầu bằng câu theo quyền. Lượt gọi `timeout`
không gọi lại (quy ước dự án).

## 8. Nghiệm thu

Máy thật **OnePlus**, tài khoản thử **Basic mới** tạo qua `POST /api/auth/register` (đăng nhập tài khoản khác dọn SQLite
tài khoản 10 trên máy — người dùng xác nhận tài khoản 10 là tài khoản test). Kịch bản: tạo hoá đơn thứ 4 · danh mục riêng
thứ 6 (sau 13 bản sao) → màn Nâng cấp; khối Dự báo / thẻ cân đối / Xuất báo cáo / công tắc tự trả hiện khoá; admin gạt
`cashflow_forecast` bật cho Basic ở Admin-web → app mở khối sau làm mới (socket `account.permissions_updated`).

## 9. Ngoài phạm vi, rủi ro chấp nhận

- Server **không** chặn gì; client là nơi thi hành duy nhất (đơn 39 §3.3 — không chặn ở `/sync/push`).
- Hai máy Basic cùng offline tạo vượt trần — chấp nhận (đơn 39 §3.3).
- Đường vòng qua trần (bỏ lưu trữ ví, gia hạn ngân sách đã hết hạn, nâng đích mục tiêu đã đạt — đơn 39 §5) — không làm.
- Tool AI dự báo / cân đối của Trợ lý: Trợ lý vốn khoá với Basic, không thêm chốt.
- `financial_health_fhs` không có bề mặt ở client.
