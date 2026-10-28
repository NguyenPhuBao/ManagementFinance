# Phân quyền theo gói — cột Premium và 22 công tắc (B1) — thiết kế

> **Ngày:** 2026-10-27 (phiên 16, Opus 5.5) · **Trạng thái:** bốn phần thiết kế người dùng duyệt từng phần; ✅ **bản viết duyệt
> 2026-10-27 phiên 17** (ba điểm cuối — mục 1 hàng 10–12)
> **Phạm vi:** chỉ `src/Client-app` (quy tắc 1) + đơn backend **CAN-LAM 55** (mục 7). Không đổi schema Drift (vẫn v31).
> **Liên quan:** `2026-10-08-phan-quyen-tinh-nang-client-design.md` (spec gốc — spec này thay luật *"Premium còn hạn = mở hết"*
> của nó), `docs/PREMIUM_FEATURE.md` mục 8, commit `3ec874aa` (trần 0 = không tạo thêm — việc (a) cùng phiên).
> **Thi công:** chỉ bắt đầu khi kế hoạch *danh mục theo Admin-web* (2026-10-27) xong — hai luồng agent không commit chồng nhau.

## 0. Bối cảnh — đo bằng mã 2026-10-27 (khảo sát chỉ đọc ba phía)

- Admin-web `/permissions` có ma trận **36 mã × 2 gói** (31 công tắc + 5 trần) và hai trụ phụ (`scope_config`, `downgrade_policy`)
  — bảng `feature` + `account_type_permission` (`database/22`, `30`, `31`, `32`).
- App nhận quyền ở **một** endpoint: `GET /payment/subscription-info` (`payment.service.js:798-833`) trả `accountType` (gói GỐC),
  `premiumExpiresAt`, `limits` (5 mã LIMIT, `int|null`), `features` (31 mã TOGGLE, `bool`), `scopes`, `policies` — **chỉ bảng
  của gói ĐANG hiệu lực** (`effectiveType`). Người Basic không bao giờ thấy cột Premium.
- Client trước spec này: đọc **11** công tắc + **5** trần; `duocDung` (`premium/domain/quyen_tinh_nang.dart:51`) và `conTaoDuoc`
  (`premium/domain/tran_goi.dart:27`) **bỏ qua bảng khi Premium còn hạn** → admin tắt một tính năng ở cột Premium thì app người
  Premium vẫn mở (riêng trợ lý online thì server 403 `FEATURE_DISABLED`, app hiện nút mà bấm thì rơi về AI trên máy).
- Backend **không** thi hành trần nào; công tắc chỉ chặn ở 3 mã (`requireFeature`: `ai_assistant`, `ocr_receipt`,
  `financial_health_fhs`). Mọi khoá khác chỉ do client giữ.
- Trụ 1 (bật / tắt) của 5 mã LIMIT **mất trên đường đi**: hàng LIMIT chỉ vào `limits` (`permission.repository.js:127-128`).
- ⚠️ Lỗi có sẵn lộ khi thiết kế: Premium hết hạn **lúc offline** → `conTaoDuoc` đọc `goi.tran` — trần đã lưu là của **Premium**
  (toàn `null`) → người đã về Basic tạo ví / ngân sách / mục tiêu **không giới hạn** tới lượt `lamMoi` kế. Luật mục 2 sửa luôn.

## 1. Quyết định người dùng chốt (2026-10-27, câu hỏi chọn được)

| # | Câu hỏi | Chốt |
|---|---|---|
| 1 | Admin-web đặt trần 0 nghĩa là gì | **Không tạo thêm** (đã thi công `3ec874aa`) |
| 2 | Hướng (b) quá lớn — chia | B1 cột Premium + công tắc (**spec này**) · B2 chính sách hạ cấp · B3 `scope_config` · B4 chống lùi đồng hồ |
| 3 | Admin tắt tính năng ở cột PREMIUM — người Premium thấy gì | **Khoá, câu *"Đang tạm ngừng"*, không nút Nâng cấp**; trần Premium cũng áp |
| 4 | Basic không biết cột Premium (tắt cả hai cột → mua rồi vẫn khoá) | **Đơn backend gửi cột Premium cho Basic + dự phòng** (chưa gửi thì như nay) |
| 5 | Đọc thêm nhóm công tắc nào | **Cả bốn nhóm — 11 mã** (mục 3) |
| 6 | Premium chạm trần Premium | **Màn Nâng cấp, câu trần Premium** (cửa chặn cũ, không màn mới) |
| 7 | Lối tiếp cận | `trangThaiQuyen` ba trạng thái; `duocDung` giữ `bool` cho ~30 chỗ gọi |
| 8 | Khoá `category_keywords_matching` | Khoá sửa từ khoá + đề xuất thêm từ khoá; **từ khoá đã có vẫn dùng để gợi ý** |
| 9 | Đơn backend | **Một đơn 55** gộp hợp đồng (vế A) + đính chính `4_TRU_COT.md` (vế B, việc (c)) |
| 10 | Đặc quyền Premium khi trần Premium là một số | ***"Tới 10 ví"*** — chỉ kể khi lớn hơn trần Basic (phiên 17) |
| 11 | Tên hiển thị 11 mã mới | **Giữ bảng mục 3** (phiên 17) |
| 12 | Nghiệm thu máy thật | **Thêm hai bước**: hết hạn lúc offline (G109) · nhắc trước hạn hoá đơn bị khoá (mục 10 bước 5–6, phiên 17) |

## 2. Luật đọc bảng — domain `premium/`

Một trạng thái mới, MỘT định nghĩa:

```dart
enum TrangThaiQuyen { mo, canPremium, tamNgung }

/// Bảng đã lưu là của gói ĐANG hiệu lực: lúc nhận (nhanLuc) và bây giờ cùng là Premium còn hạn, hoặc cùng không.
bool bangDungDuoc(TrangThaiGoi goi, DateTime now) => goi.laPremium(goi.nhanLuc) == goi.laPremium(now);

TrangThaiQuyen trangThaiQuyen(MaQuyen ma, TrangThaiGoi goi, DateTime now) {
  final premium = goi.laPremium(now);
  final bang = bangDungDuoc(goi, now);
  final v = bang ? goi.quyenTinhNang[ma.maServer] : null;
  if (premium) return v == false ? TrangThaiQuyen.tamNgung : TrangThaiQuyen.mo; // vắng → mở (như nay)
  if (v ?? ma.macDinhKhiThieu) return TrangThaiQuyen.mo;
  final cotPremium = bang ? goi.quyenPremium[ma.maServer] : null; // chỉ có khi server gửi premiumFeatures (đơn 55 A1)
  return cotPremium == false ? TrangThaiQuyen.tamNgung : TrangThaiQuyen.canPremium;
}

bool duocDung(MaQuyen ma, TrangThaiGoi goi, DateTime now) => trangThaiQuyen(ma, goi, now) == TrangThaiQuyen.mo;
```

- Thay luật cũ *"bảng chỉ tin khi là của Basic"* (`!laPremium(nhanLuc)`) bằng *"bảng là của gói đang hiệu lực"*. Premium hết
  hạn lúc offline → bảng lưu là của Premium → Basic dùng `macDinhKhiThieu` (như nay).
- **Trần** — `conTaoDuoc` bỏ dòng *"Premium luôn được"*:
  - bảng dùng được → `goi.tran.cua(loai)` (Basic hay Premium đều theo bảng; `null` = không giới hạn);
  - bảng KHÔNG dùng được: Premium → không giới hạn (như nay); Basic → `TranGoi.macDinh.cua(loai)` (đóng lỗi offline mục 0).
  - `Vuot` mang thêm `laPremium` để câu mở đầu chọn đúng gói.
- `redirectTaoTheoGoi` (`chan_theo_goi.dart`) bỏ lối tắt *"Premium → không chặn"* — `conTaoDuoc` quyết.
- `dacQuyenPremium` (màn Nâng cấp): có `tranPremium` / `quyenPremium` (Basic, server đã gửi) → kể trần Premium (`null` →
  *"Không giới hạn ví"*, số → *"Tới 10 ví"* khi lớn hơn trần Basic) và quyền Premium mở mà Basic tắt; mục Premium cũng tắt
  thì KHÔNG kể. Chưa có → như nay.
- Test quét 21 giữ: chuỗi mã quyền chỉ nằm ở `MaQuyen`, `quyenTinhNang` / `quyenPremium` chỉ đọc ở `quyen_tinh_nang.dart`
  (+ model / kho).

## 3. 22 công tắc client đọc, 9 không bao giờ khoá

`MaQuyen` thêm 11 mã, tất cả `macDinhKhiThieu = true` (vắng = mở, chốt 2026-10-08):

| Mã server | `ten` (thẻ khoá, câu mở đầu) | Chỗ khoá trên app | Khi khoá |
|---|---|---|---|
| `net_worth_overview` | Tổng tài sản | khối Tổng tài sản Trang chủ (`home_page.dart:451`); khối *"Tổng tài sản … gần đây"* Phân tích (`khoi_tong_tai_san.dart`) | thẻ khoá thay khối |
| `quick_action_shortcuts` | Nút ghi nhanh | hàng năm nút Trang chủ (`hang_nut_nhanh.dart`) | một dòng khoá mỏng thay hàng |
| `daily_recording_reminder` | Nhắc ghi chép hằng ngày | công tắc ở Cài đặt thông báo (`notification_settings_page.dart:740`) + lịch HĐH | công tắc khoá, giữ giá trị; lịch bị huỷ |
| `bill_reminder_notifications` | Nhắc trước hạn hóa đơn | loại `billDueSoon` + lịch HĐH nhắc trước hạn; chip *Nhắc trước* ở form hoá đơn và ở Cài đặt | thôi nhắc trước hạn; **quá hạn vẫn báo** |
| `budget_overspend_alert` | Cảnh báo vượt ngân sách | loại `budgetNearLimit` / `budgetOverspent`; dòng *"Nên chi X/ngày"* (`budget_pace_text.dart`) | bộ quét bỏ hai loại; dòng nhịp chi → dòng khoá |
| `wallet_balance_adjustment` | Điều chỉnh số dư ví | ô số dư ở Sửa ví (đối soát → khoản bù) | ô chỉ đọc + dòng khoá |
| `wallet_exclude_total` | Loại ví khỏi tổng tài sản | công tắc *Tính vào tổng tài sản* (Sửa ví) / *Tính vào tổng số dư tài sản* (Thêm ví) | chỉ chặn **loại mới**: ví đã lưu "tính" → công tắc khoá; ví đã loại vẫn loại, **bật lại được** (mục 13 (20)) |
| `goal_deposit_withdraw` | Nạp / rút mục tiêu | nút Nạp / Rút ở Chi tiết mục tiêu | nút tắt + dòng khoá (tự trích theo `goal_auto_deposit`) |
| `quick_category_assignment` | Gắn danh mục hàng loạt | thẻ *"Có N giao dịch chưa có danh mục"* (Sổ giao dịch) + route `/transactions/gan-danh-muc` | thẻ khoá; route qua `redirectTheoQuyen` |
| `category_keywords_matching` | Từ khoá nhận diện danh mục | khối *Từ khoá nhận diện* (`category_add_page.dart`) + đề xuất *"Thêm 'x' làm từ khoá…"* (5f) | không sửa / không đề xuất; từ khoá đã có **vẫn** gợi ý |
| `in_app_calculator` | Phép tính trên bàn phím số | phím **+ / −** bàn phím số màn Thêm giao dịch | hai phím mờ, chỉ gõ số |

11 mã cũ giữ nguyên chỗ khoá (bảng 8.2 `PREMIUM_FEATURE.md`).

**Không bao giờ khoá (9)** — không vào `MaQuyen`, client bỏ qua giá trị: `transaction_management` · `offline_first_sync` (lõi —
*"đồng bộ không tách theo gói"*) · `vietqr_payment` (khoá là Basic không nâng cấp được) · `account_deletion` (quyền của người
dùng) · `biometric_auth` (trên app là khoá ứng dụng — chốt miễn phí mọi gói) · `payment_history` (Lịch sử mua là lối vào Chi
tiết đơn — chỗ duy nhất xác nhận / hoàn tiền) · `ai_model_management` (khoá là không xoá được mô hình 2,4 GB) · `offline_login`,
`financial_health_fhs` (app không có tính năng). Danh sách này ghi vào `quyen_tinh_nang.dart` (chú thích) và mục 8 tài liệu.

## 4. Giao diện khoá và câu chữ

Mọi thành phần khoá (`premium/presentation/widgets/the_khoa_quyen.dart`: `TheKhoaQuyen`, `KhoaTheoQuyen`, `DongKhoaQuyen`,
`DongKhoaCongTac`; cửa route `redirectTheoQuyen`; câu mở đầu màn Nâng cấp) đọc `trangThaiQuyen` qua `GoiCubit` /
`context` (thêm `trangThaiQuyen(ma)` cạnh `coQuyen` ở `co_quyen.dart`):

| Trạng thái | Thẻ khoá | Dòng khoá công tắc | Cửa route |
|---|---|---|---|
| `canPremium` | *"Dành cho Premium"* + nút **Nâng cấp** (như nay) | *"Tạm dừng — cần Premium"* / *"Cần Premium"* (như nay) | `/premium?quyen=…` → *"X là tính năng Premium."* |
| `tamNgung` | *"Đang tạm ngừng"*, **không** nút, chạm không làm gì | *"Tạm ngừng"* | `/premium?quyen=…` → *"X hiện đang tạm ngừng."*, **không giá, không nút mua** (mục 13 (19)) |

- Trần Premium: `/premium?tran=…` với người Premium → *"Gói Premium hiện cho tạo tối đa 10 ví."*; trần 0 → *"Gói Premium hiện
  không cho tạo thêm ví."* (Basic giữ câu của `3ec874aa`).
- Thẻ Gói (tab Cá nhân): người Premium có trần có số → thêm dòng `tomTatTran` như Basic.
- Mọi câu ở MỘT chỗ (cạnh `cauMoDau` / `cauMoDauQuyen`), test từng ký tự.
- **Stitch:** biến thể *"Đang tạm ngừng"* của thẻ khoá và của dòng khoá chưa có — kế hoạch có một task dựng trên Stitch, người
  dùng kiểm trên Stitch (công cụ có độ trễ, kết quả trả về không chứng minh gì) trước khi viết UI.

## 5. Bộ chạy nền

Ba bộ mới hỏi `coQuyenNen` (khuôn tự trả / tự trích; không phiên → `true`; không quyền → bỏ lượt, không ghi gì, giữ công tắc):

- **Nhắc ghi chép hằng ngày** và **nhắc trước hạn hoá đơn**: `ReminderScheduler` không đặt lịch khi không quyền; lịch đã đặt bị
  huỷ ở lượt `resync` kế (dùng đường `resync(datLai: true)` khi quyền đổi — bẫy G59 / 7.14 `NOTIFICATION_FEATURE.md`).
- **Cảnh báo ngân sách**: `NotificationScanner` bỏ loại `budgetNearLimit` / `budgetOverspent` khi không quyền.
- Quyền đổi (lượt `lamMoi` sau socket `account.permissions_updated`) → GoiRepository phát trạng thái mới → hook gọi `resync`.
- DI nối vị từ quyền vào bộ quét / bộ đặt lịch (không để `notification/` import `premium/data/` trực tiếp ngoài đường DI sẵn có).

## 6. Model và kho

- `TrangThaiGoi` thêm `quyenPremium` (`Map<String, bool>`, mặc định `{}`) và `tranPremium` (`TranGoi?`, `null` = server chưa
  gửi). `trangThaiTuJson` đọc `premiumFeatures` / `premiumLimits` (vắng / rác → mặc định); kho `goi_tai_khoan_<id>` ghi / đọc
  thêm hai trường (secure storage — không đổi schema Drift).
- `TranGoi.tuJson` dùng chung cho `premiumLimits` (số ≤ 0 → 0, `null` → không giới hạn).

## 7. Đơn backend CAN-LAM 55 — `PHAN_QUYEN_THEO_GOI_HOP_DONG_VA_TAI_LIEU.md`

**Vế A — hợp đồng `/payment/subscription-info`:**
1. Tài khoản hiệu lực **Basic** → thêm `premiumFeatures` (31 khoá TOGGLE, `bool`) + `premiumLimits` (5 khoá LIMIT,
   `int|null`) từ cột Premium. Đang Premium thì không cần. Thiếu khoá → client như nay.
2. Trụ 1 của 5 mã LIMIT: `is_enabled = false` → `limits[mã] = 0` (và `premiumLimits[mã] = 0`). Client đọc 0 = không tạo thêm
   từ `3ec874aa`.
3. Premium không có `premium_expires_at`: service → Basic, `requireFeature` → Premium, client → Premium còn hạn. Xin chốt một
   nghĩa và ghi vào hợp đồng (client đổi ở B4).

**Vế B — đính chính `docs/Functional-Mobile/4_TRU_COT.md`** (tài liệu backend — chỉ đọc với client): bảng 27 khẳng định sai về
client + 4 về backend (`requireFeature` không phủ CRUD; `FEATURE_LOCKED` / `FEATURE_PERMISSION_DENIED` không tồn tại — mã thật
`FEATURE_DISABLED` + `featureId`; `downgrade_policy` không ai thi hành; …), mỗi dòng `tệp:dòng`; seed `scope_config` lệch miền
giá trị app (`allowed_types` EWallet / Credit / Investment, `supported_banks` VCB / TCB / ACB, `models` whisper / finance-slm,
`formats` EXCEL). Nguồn: bảng đối chiếu 67 dòng (khảo sát 2026-10-27).

## 8. Giới hạn biết trước

- App chỉ thấy bảng của gói đang hiệu lực: Premium hết hạn lúc offline → mặc định Basic (`macDinhKhiThieu`, `TranGoi.macDinh`)
  chứ không phải bảng Basic thật, tới lượt `lamMoi`.
- Premium không có ngày hết hạn → coi là còn hạn (B4). Lùi đồng hồ máy khi offline làm Premium hết hạn sống lại (B4).
- Backend chỉ chặn 3 mã → mọi khoá khác là khoá giao diện; bỏ qua app là qua mặt (vế B).
- Trụ 1 của mã LIMIT chờ đơn 55 A2.
- Khoá giữa chừng một tính năng đang bật: dừng chạy, giữ công tắc; mở lại → chạy tiếp (lịch nhắc đặt lại ở `resync`).
- Khoá `category_keywords_matching`: từ khoá đã có vẫn gợi ý (chốt 8) — người dùng không thêm được từ khoá mới.
- (Thêm khi thi công, 2026-10-28) Gói số bậc 1 của Trợ lý AI (`ai_edge/data/nguon_goi_so.dart:125-131`) và gói Ví (`ai_edge/domain/goi_so_vi.dart:147`)
  vẫn mang tổng tài sản khi `net_worth_overview` khoá — ngoài chốt 6 (che chip *Tổng số dư* ở Nhận xét Trang chủ).
- (P-N5) `noiKhiQuyenDoi` có thể kích `resync` ở lượt `_phat` đầu từ kho lúc mở app, song song lượt khôi phục của scanner — hai dòng `dat_lich`
  cùng khoá trong nhật ký B5a; `resync` không có khoá loại trừ: quyền tắt đúng lúc lượt khác đã đọc vị từ có thể đặt lại lịch vừa huỷ (tự sửa ở
  lượt quét kế).
- (Cuộc đua lúc đăng xuất, review toàn nhánh M1, 2026-10-28 — **không** sửa bằng mã) `PhienDieuPhoi.dongPhien` dừng bộ quét (`stop` → `cancelAll`)
  trong khi `GoiRepository.idaccount` còn tới lượt `noiPhien(null)`; một lượt `lamMoi` về đúng khe ấy mà lật quyền nhắc thì closure
  `noiKhiQuyenDoi` ở `main.dart` gọi `ReminderScheduler.resync` cho tài khoản vừa đăng xuất → lịch nhắc của nó có thể được đặt lại sau
  `cancelAll`. `NotificationScanner` / `ReminderScheduler` không có cờ công khai "đang chạy" (`_idaccount` riêng tư; `chayNen` là chế độ
  engine nền) nên đợt sửa cuối KHÔNG thêm API mới; khe rất hẹp (cần đúng một lượt `lamMoi` lật quyền giữa hai bước đăng xuất) — xử lý cùng
  họ P-N5 nếu có lượt sau.
- Trần của kho chỉ đáng tin sau lượt `lamMoi` đầu kể từ bản B1 (preflight N4): kho Premium cũ đã toàn `null` vì server luôn gửi đủ 5 khoá
  `limits`; chỉ khi CSDL đang chạy thiếu một hàng LIMIT của cột Premium thì ô ấy giữ mặc định cũ (`3`) tới lượt `lamMoi` kế — mục 10 bước 0 kiểm.

## 13. Chỗ mã khác bản viết

Mỗi mục: *người dùng / người điều phối chốt* — (1)–(12) 2026-10-27 phiên 17 (kế hoạch, mục *Đã chốt*, preflight); (13)–(18)
2026-10-28 phiên 18 (soát từng task, review toàn nhánh, đợt sửa cuối); (19)–(20) 2026-10-28 phiên 19 (người dùng trả lời I2 / I3).

1. **`bangDungDuoc` thêm vế Premium-không-hạn** (`goi.loai == premium && goi.hetHan == null` → `false`). Thân spec mục 2 chỉ so
   `laPremium(nhanLuc) == laPremium(now)`; Premium không hạn mà server gửi bảng Basic thì mọi thứ Basic tắt hiện *"Đang tạm ngừng"* với
   người Premium. Giữ hành vi cũ tới B4 (người dùng chốt).
2. **`resync` thường thay `datLai`** khi quyền nhắc đổi (`main.dart`, `noiKhiQuyenDoi`): quyền tắt là lịch rời tập muốn (bị huỷ), quyền
   bật là lịch chưa chờ (được đặt); `datLai` chỉ cho đổi giờ (G59). Mục 5 thân spec ghi `resync(datLai: true)`.
3. **`Vuot.laPremium` không thêm** (mục 2 dòng "`Vuot` mang thêm `laPremium`"): câu mở đầu chọn gói bằng `tranHieuLuc(…)` / trạng thái gói
   nơi gọi, không cần mang cờ trong kết quả.
4. **`TrangThaiGoi.tran` mặc định theo gói** (Premium không giới hạn, Basic `TranGoi.macDinh`) và **`TranGoi.tuJson(khiThieu:)`** — thân
   spec mục 6 chỉ nói "mặc định".
5. **`tranHieuLuc(goi, now)` là cửa đọc trần duy nhất** (spec không đặt tên): `conTaoDuoc`, `redirectTaoTheoGoi`, câu màn Nâng cấp, thẻ Gói,
   và từ đợt sửa cuối `dacQuyenPremium` (18) đều gọi nó — đọc `goi.tran` thô là G109.
6. **Hai băng khoá AI** (Task 11): màn Trợ lý AI và ô Nhập nhanh có biến thể tạm ngừng riêng (`lyDoKhoa(tamNgung:)`, `DongKhoa(tamNgung)`).
7. **Công tắc nhắc đẩy của form hoá đơn không khoá** (kết luận 9 kế hoạch): chỉ chip *Nhắc trước* khoá; công tắc ấy vẫn mở (ca canh Task 9).
8. **`account.permissions_updated` đã nối sẵn** (kết luận 1): không thêm sự kiện — `RealtimeEvent.taiKhoanNangCap` → `lamMoi` đã có từ 2026-10-08.
9. **Nhận xét Trang chủ che chip *Tổng số dư* khi `net_worth_overview` khoá** (chốt 6, Task 8b; `GoiSoTrangChu.tu(boTongSoDu:)`).
10. **`premiumLimits` không phải Map (rác) → `tranPremium = null`** (P-N12, `trang_thai_goi.dart` `_docTranPremium`): thân spec mục 6 nói
    "vắng / rác → mặc định"; mã coi rác như "server chưa gửi" (khác `TranGoi.khongGioiHan`), vì đưa rác vào `TranGoi.tuJson` biến "chưa gửi"
    thành "đã gửi, không giới hạn". Map có ô thiếu / lạ vẫn → `khiThieu: khongGioiHan`.
11. **`chanTheoGoi` tắt sớm theo `tranHieuLuc(...).cua(loai) == null`** (`chan_theo_goi.dart`) thay vì "`conTaoDuoc` quyết" (mục 2): trần không giới hạn
    → qua, không trả một lượt đếm CSDL cho kết quả chắc chắn.
12. **`KhoaTheoQuyen` / `chanTheoQuyen` vẫn đọc vế `bool`** (`duocDung`); chỉ `TheKhoaQuyen` / `DongKhoa*` / màn Nâng cấp đọc ba trạng thái.
13. **Hai chuỗi *"Không giới hạn <tenTran>"* / *"Tới N <tenTran>"* của `dacQuyenPremium` ở `quyen_tinh_nang.dart`**, không ở `cau_quyen.dart`
    (bảng *Câu chữ chốt* ghi "một chỗ"): `dacQuyenPremium` vốn sống ở đó từ trước B1, chuỗi là phần tử danh sách của hàm domain.
14. **Đính chính kết luận 10 của kế hoạch** (sau phép đo Task 9): `DropdownButton` khoá vẫn vẽ mục đang chọn khi giá trị nằm trong `items`;
    `disabledHint` giữ cho giá trị ngoài danh sách (hàng kéo về mang số nhắc lạ).
15. **Dòng khoá Trang chủ có khung** (`khoaCanNen` / `khoaCanVien`) **+ trang Chi tiết ngân sách giữ card *NHỊP CHI*** — theo Stitch khối 4,
    ngoài chữ spec mục 3 "dòng nhịp chi → dòng khoá".
16. **Ô nhập Trợ lý AI / Nhập nhanh khi tạm ngừng** có hint *"Đang tạm ngừng"* (`kTheKhoaTamNgung`) thay *"Tính năng Premium"* / *"Chỉ Premium"*;
    băng Trợ lý AI tạm ngừng dùng icon `smart_toy_outlined` theo Stitch khối 6 (soát Task 11). Kèm lệch Stitch có chủ ý ở `PREMIUM_FEATURE.md` 8.6.
17. **API 0 chỗ gọi — giải quyết ở đợt sửa cuối** (review toàn nhánh đảo phán quyết "ghi, không gỡ" của Task 12, luật *"không ship API 0 chỗ
    gọi"*): `trangThaiQuyenDoc` (`co_quyen.dart`) nay **có** chỗ gọi — hai getter tạm ngừng `_tamNgungAi` (`ai_chat_page.dart`) và
    `_tamNgungNhapNhanh` (`add_transaction_page.dart`) thôi chép `try` / `catch`; tham số `cauTamNgung` của `DongKhoaQuyen` **đã gỡ** cùng ca
    canh (tạm ngừng luôn `cauDongKhoaTamNgung` — đúng Stitch `02c0d881…` khối 2). Câu dòng khoá chi bất thường (*"Có khoản chi bất thường kỳ
    này — dành cho Premium"*) dời từ `khoi_tong.dart` vào `cau_quyen.dart` (hằng `kDongKhoaChiBatThuong`, ca từng ký tự) — mục 4 *"mọi câu ở
    MỘT chỗ"*. `kCongTacCanPremium` **có** chỗ gọi (`the_khoa_quyen.dart`).
18. **`dacQuyenPremium(goi, now)` đọc bảng của gói đang hiệu lực** (review toàn nhánh I1): thân mục 2 chỉ tả danh sách cho Basic (cột Premium
    server gửi). Bản trước tách theo luật cũ *"bảng chỉ tin khi là của Basic"* (`!laPremium(nhanLuc)`), nên người xem **Premium còn hạn** luôn
    thấy danh sách mặc định — màn mở đầu *"Gói Premium hiện cho tạo tối đa 10 ví."* mà danh sách ✓ ngay dưới nói *"Không giới hạn ví"*, và
    Trợ lý AI đang tạm ngừng vẫn được kể là đặc quyền. Nay: Premium còn hạn ∧ `bangDungDuoc` → bảng đã lưu CHÍNH LÀ cột Premium (trần qua
    `tranHieuLuc` so với `TranGoi.macDinh` → *"Tới 10 ví"*; quyền `false` không kể); Basic bảng dùng được → như cũ (cột Premium server gửi);
    bảng không dùng được (Premium hết hạn lúc offline, Premium không hạn) → mặc định. Hàm không còn đọc `goi.tran` thô — mọi chỗ đọc trần đi
    qua `tranHieuLuc` (mục 13 (5)).
19. **Màn Nâng cấp ẩn giá + nút mua khi đến từ quyền tạm ngừng** (I2, *người dùng chốt*): thân spec tự mâu thuẫn — bảng mục 4 cho cửa
    tạm ngừng đi `/premium?quyen=…`, mục 10 bước 1 đòi *"không nút mua"*, còn bản B1 đầu vẫn vẽ giá + *Gia hạn thêm 30 ngày* / *Thanh
    toán* (mua cũng không mở tính năng admin đang tắt). Nay `nang_cap_page.dart` (`anNutMua`) ẩn giá, nút và dòng *"Xác nhận đơn chuyển
    thừa…"*; giữ thẻ gói, câu *"X hiện đang tạm ngừng."*, danh sách đặc quyền, *Lịch sử mua*, thẻ đơn cần xử lý. Neo vào **câu đang
    hiện**: có `?tran=` thì câu trần thắng (mục 4) và mua là nới trần → nút ở lại. Một chỗ phủ mọi lối vào (cửa route Xuất báo cáo / Gắn
    danh mục, nút Quét / Nói Trang chủ, deeplink thông báo Tổng kết tuần). Phương án đã loại: báo nhanh tại chỗ, không mở màn (~5 lối vào
    phải sửa, deeplink vẫn cần chỗ rơi). Lệch có chủ ý với Stitch `c999da97…` (luôn vẽ nút).
20. **Công tắc *"Tính vào tổng tài sản"* chỉ chặn loại mới** (I3, *người dùng chốt*; thân mục 3 + kế hoạch ghi *"khoá cả hai chiều"*):
    khoá hai chiều làm ví người bị hạ cấp đã loại khỏi tổng kẹt ngoài tổng tới khi mua lại Premium — trái luật *"hạ cấp giữ dữ liệu, chỉ
    chặn tạo / bật mới"*. Một định nghĩa `doiDuocTinhVaoTong(coQuyen:, daLuuTinhVaoTong:)` (`wallet/domain/cong_tac_tinh_vao_tong.dart`),
    hai màn gọi. Neo vào giá trị **ĐÃ LƯU** (người soát chỉ ra): ví đã lưu "không tính" → công tắc mở **cả hai chiều tới khi Lưu** (tắt
    lại trước Lưu chỉ là về giá trị cũ); Lưu "tính" rồi thì lần mở sau khoá. Neo vào giá trị đang chọn thì bật lại xong là khoá ngay, chạm
    nhầm không gỡ được. Màn Thêm truyền `daLuuTinhVaoTong: true` (ví mới — mọi "không tính" là loại mới) → hành vi như cũ. Băng *"Cần
    Premium"* vẫn hiện dưới công tắc mở (nói loại khỏi tổng là Premium — Lưu "tính" thì không loại lại được).

## 9. Kiểm thử (TDD — mọi ca canh thử bằng bản sai có chủ ý và thấy đỏ)

| Lớp | Ca chính |
|---|---|
| `trangThaiQuyen` | Premium + `false` → `tamNgung` · Premium + vắng → `mo` · Basic + `false` + cột Premium `false` → `tamNgung` · Basic + `false` + cột Premium vắng → `canPremium` · Premium hết hạn offline (bảng của Premium) → `macDinhKhiThieu` · `duocDung` ⇔ `mo` |
| `conTaoDuoc` | Premium + trần 10 → `Vuot(laPremium: true)` · Premium + bảng không dùng được → được · Basic + bảng của Premium (hết hạn offline) → `TranGoi.macDinh` (ca đỏ với mã cũ) |
| Model / kho | `premiumFeatures` / `premiumLimits` đọc · vắng · rác · khứ hồi kho |
| 11 chỗ khoá | mỗi mã: khoá → thấy thẻ / dòng khoá, không thấy thao tác; mở → như cũ; `tamNgung` → không nút Nâng cấp |
| Bộ chạy nền | không quyền → không đặt lịch / bỏ loại thông báo; quyền đổi → `resync` |
| Câu chữ | `cauMoDauQuyen` hai trạng thái · câu trần Premium · `dacQuyenPremium` với cột Premium |
| Test quét 21 | chuỗi 11 mã mới chỉ ở `MaQuyen` |

## 10. Nghiệm thu máy thật

Backend + Admin-web trỏ **`PersonFinance` cục bộ** (⚠️ không Supabase dùng chung — ma trận quyền áp cho MỌI tài khoản). Kiểm
danh tính CSDL trước (*Ghi chú vận hành* `CLAUDE.md`).
0. **Bước 0 — go / no-go trước phát hành (chỉ đọc, trước mọi bước; kế hoạch câu chốt 7 + preflight N4)** — trên `PersonFinance` **và**
   Supabase dùng chung (CSDL người dùng thật chạm), qua Prisma từ `src/Backend` (tên cột đối chiếu `database/31` trước khi chạy):
   (a) `account_type_permission` cột `Premium` có ô `is_enabled = false` nào thuộc 22 mã `MaQuyen` không — phát hành bản B1 là MỌI người
   Premium thấy mã ấy *"Đang tạm ngừng"* ngay lượt `lamMoi` đầu; Supabase trả hàng nào → **dừng, hỏi người dùng**; (b) đủ 5 hàng LIMIT của
   cột Premium (`wallets` · `budgets` · `goals` · `bills` · `custom_categories`) — thiếu một hàng thì kho Premium giữ trần cũ cho ô ấy tới
   lượt `lamMoi` kế. Không sửa ma trận Supabase.
1. Tài khoản Premium: admin tắt *Xuất báo cáo* ở cột Premium → sau tín hiệu socket, Phân tích → Xuất báo cáo hiện *"đang tạm
   ngừng"*, không nút mua.
2. Đặt trần Premium ví = số đang có → tạo ví → màn Nâng cấp *"Gói Premium hiện cho tạo tối đa N ví."*
3. Tài khoản Basic: tắt lần lượt một mã mỗi nhóm (Trang chủ · nhắc · ví / mục tiêu · nhập liệu) → thấy khoá đúng chỗ; mở lại
   → như cũ.
4. Nhắc ghi chép đang bật → admin tắt → lịch huỷ (`dumpsys alarm`); bật lại → lịch về.
5. **Nhắc trước hạn hoá đơn** — có một hoá đơn trong khoảng nhắc và một hoá đơn quá hạn: admin tắt `bill_reminder_notifications`
   ở cột của gói → sau tín hiệu, lịch nhắc trước hạn huỷ (`dumpsys alarm`), chip *Nhắc trước* ở form hoá đơn và ở Cài đặt khoá;
   hoá đơn quá hạn **vẫn** báo; bật lại → lịch về.
6. **Hết hạn lúc offline (G109)** — tài khoản Premium có hạn vài phút tới (đặt `premium_expires_at` trên `PersonFinance` — câu
   `UPDATE` xin phép đích danh lúc đo), mở app cho nhận bảng, tắt mạng (`svc wifi disable` **và** `svc data disable`), chờ quá
   hạn → tạo ví vượt trần Basic mặc định → bị chặn, màn Nâng cấp câu trần Basic (mã cũ: tạo không giới hạn). Bật lại mạng cuối
   bước.
7. Trả ma trận về mặc định (*Khôi phục mặc định* ở Admin-web).

## 11. Tài liệu phải sửa cùng lượt

`docs/PREMIUM_FEATURE.md` mục 8 (8.1 luật bảng + *tạm ngừng*; 8.2 thêm 11 hàng + danh sách 9 mã không khoá; bẫy mới) ·
banner đầu spec `2026-10-08-phan-quyen-tinh-nang-client-design.md` trỏ về spec này · hàng *Premium* trong `CLAUDE.md` ·
`PROJECT_CONTEXT.md` mục 14 · `CLIENT_APP_KNOWN_GAPS.md` mục G mới cho lỗi *"Basic sau khi Premium hết hạn offline dùng trần
Premium"* (đóng cùng lượt) · đơn 55 vào `CAN-LAM/README.md` mục 0.

## 12. Ngoài phạm vi

- **B2** chính sách hạ cấp (`downgrade_policy`: ân hạn 3 ngày cho tự trả / tự trích, *chỉ xem* cho dự báo…).
- **B3** `scope_config` (từ khoá 5 / 25, gắn hàng loạt 20 / 100, mức nhắc hoá đơn, chu kỳ cho Basic, giây nghe…).
- **B4** chống lùi đồng hồ + nghĩa Premium không hạn.
- Backend thi hành quyền / trần ở server (vế B chỉ báo, không xin làm).
