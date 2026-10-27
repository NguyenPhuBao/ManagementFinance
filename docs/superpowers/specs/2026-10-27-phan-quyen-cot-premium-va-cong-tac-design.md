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
| `wallet_exclude_total` | Loại ví khỏi tổng tài sản | công tắc *Không tính vào tổng* (Thêm / Sửa ví) | công tắc khoá; ví đã loại vẫn loại |
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
| `tamNgung` | *"Đang tạm ngừng"*, **không** nút, chạm không làm gì | *"Tạm ngừng"* | `/premium?quyen=…` → *"X hiện đang tạm ngừng."* |

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
