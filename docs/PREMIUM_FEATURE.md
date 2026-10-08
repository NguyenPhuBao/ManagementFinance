# Premium qua PayOS — phía client

**Trạng thái (2026-10-06):** mã **xong** 15/17 task của kế hoạch `docs/superpowers/plans/2026-10-06-premium-payos-client.md`
(gitignore) — còn **Task 16 nghiệm thu máy thật** (sandbox PayOS, chờ người dùng dán khoá; `database/19` ✅ đã áp tối 2026-10-06)
và phần tài liệu này. Spec: `docs/superpowers/specs/2026-10-06-premium-payos-client-design.md` (người dùng duyệt).
Đơn backend: `docs/superpowers/backend/CAN-LAM/CLIENT_PREMIUM_PAYOS.md` (38, không chặn client).

**Phân quyền tính năng theo gói (2026-10-08):** mã xong Task 1–8 của kế hoạch `…/plans/2026-10-08-phan-quyen-tinh-nang-client.md`
(gitignore), spec `docs/superpowers/specs/2026-10-08-phan-quyen-tinh-nang-client-design.md` (người dùng duyệt) — **mục 8**
dưới đây. Từ lượt ấy bảng ở mục 1 chỉ là **mặc định khi server không trả khoá**; con số và công tắc thật do admin đặt ở
Admin-web `/permissions`.

> Tài liệu là ảnh chụp — đối chiếu với mã trước khi kết luận. Mọi con số đếm bằng máy, kèm ngày.

---

## 1. Tính năng là gì

Tài khoản có hai gói: **Basic** (mặc định) và **Premium** (49.000 đ / 30 ngày, mua tiếp khi còn hạn thì **cộng dồn**
— backend `payment.service.js:111-117`). Backend **không chặn chức năng nào theo gói**; mọi đặc quyền do client thi hành.

| Đặc quyền Premium | Basic thấy gì |
|---|---|
| Không giới hạn ví | tối đa **3** ví đang hoạt động; đủ trần, bấm + → màn Nâng cấp mở đầu bằng *"Bạn đã dùng 3/3 ví của gói Basic."* |
| Không giới hạn ngân sách | tối đa **3** đang hoạt động (chưa xoá, chưa hết hạn) |
| Không giới hạn mục tiêu tiết kiệm | tối đa **3** đang hoạt động (chưa xoá, chưa đạt) |
| Trợ lý AI & Nhập nhanh bằng AI | màn Trợ lý AI mở nhưng ô nhập + chip khoá (kể cả lệnh tạo C3), băng *"Trợ lý AI là tính năng Premium…"* + nút Nâng cấp; ô Nhập nhanh ở màn Thêm giao dịch mờ, nút Điền thay bằng Nâng cấp |
| AI lấp ô thiếu khi **Quét** ảnh (A5, 2026-10-08) | nút Quét + phần luật (ML Kit) mở cho mọi người; Basic không gọi mô hình, màn *"Đang đọc ảnh…"* không có chữ "AI" (`quet_anh_page.dart`, `_laPremium` — từ 2026-10-08 đọc quyền `ai_edge_model`, nút Quét đọc `ocr_receipt`, mục 8) — `docs/QUET_ANH_FEATURE.md` |

**Không** khác theo gói (người dùng chốt): đồng bộ (cả 5 nguồn kích hoạt, kể cả socket `sync.completed`), khối Nhận
xét, gợi ý danh mục, thông báo. Màn Nâng cấp **không** hứa *đồng bộ tức thì*. Người bị hạ cấp **giữ nguyên** mọi thứ
đang có, chỉ không tạo thêm.

⚠️ *(Câu trên từng kể thêm "xuất báo cáo, OCR biên lai, đọc biến động số dư" — đúng tới 2026-10-08. Từ phân quyền tính
năng (mục 8) ba thứ ấy, cùng Dự báo, chi bất thường, cân đối ngân sách, tự trả, tự trích và AI trên máy, đi theo bảng
quyền của server; khi server không trả khoá thì chúng **mở**, nên tài khoản không cấu hình gì vẫn thấy như cũ.)*

## 2. Quyết định kèm lý do (8 câu người dùng chốt 2026-10-06)

1. **Đặc quyền theo đúng backend ghi**, đo lại từng cái → câu 3–4. "Báo cáo tài chính AI chuyên sâu" = **màn Trợ lý AI
   + ô Nhập nhanh** (hai chỗ duy nhất gọi Gemma; khối Nhận xét là luật nên giữ cho mọi người).
2. **Trần 3/3/3**, bằng trần là vượt. ⚠️ Tài khoản mới được seed **2 ví** nên Basic mới chỉ tạo thêm **một** ví — người
   dùng biết và **giữ 3**. Đổi trần: một hằng `TranGoi.macDinh`, hoặc server trả `limits`.
3. **Đồng bộ không tách** — đồng bộ là lõi offline-first; tách là làm Basic lệch dữ liệu hai máy.
4. **Cache hạn theo tài khoản, so giờ máy** — AI trên máy sinh ra để chạy offline, nên Premium offline vẫn phải hỏi
   được; lùi giờ máy khi offline kéo dài được Premium tới lần online kế (chấp nhận cho đồ án; server vẫn hạ cấp đúng).
5. **Client thi hành, server quyết CON SỐ** — server chỉ thấy bản ghi sau khi đã dùng (`/sync/push`), chặn ở đó là kẹt
   hàng đợi (họ G31); `limits` của `/subscription-info` đè hằng client (đơn 38).
6. **Mở `checkoutUrl` ngoài app** (`url_launcher`) — trang PayOS trên điện thoại có danh sách app ngân hàng mở thẳng kèm
   số tiền; QR trong app thì cùng máy không tự quét được. Không WebView (deep link sang app ngân hàng hay hỏng).
7. **Nghiệm thu bằng Sandbox PayOS** — không tốn tiền thật, lặp được.
8. **Kiến trúc A**: mô-đun `features/premium/`, một định nghĩa `conTaoDuoc`, **một cửa chặn** ở `redirect` của ba route
   tạo (mọi lối vào form đều qua: nút +, thẻ *Chưa đặt ngân sách*, lệnh tạo C3, deeplink).

## 3. Kiến trúc & tệp (`lib/features/premium/`)

```
domain/  trang_thai_goi.dart (TrangThaiGoi · laPremium(now) · soNgayConLai · trangThaiTuJson accountType??type)
         tran_goi.dart (TranGoi.macDinh 3/3/3 · conTaoDuoc · maTran) · chuyen_huong_theo_goi.dart (?id = sửa → qua)
         don_thanh_toan.dart (DonThanhToan · TrangThaiDon, chuỗi lạ = pending) · cau_loi_thanh_toan.dart (không URL)
         nhac_het_han.dart (0..3 ngày) · dong_lich_su.dart
data/    goi_store.dart (secure storage `goi_tai_khoan_<id>`) · payment_api.dart (Dio, bocData) · goi_repository.dart
         (kho thắng type · lamMoi không ném · resumed giãn 5' · socket hỏi ngay) · dem_dang_hoat_dong.dart
         (NguonDemDangHoatDong) · chan_theo_goi.dart (redirectTaoTheoGoi) · bo_hoi_trang_thai_don.dart (3 s) ·
         mo_lien_ket.dart (tệp DUY NHẤT import url_launcher — test quét 18)
presentation/ cubit/goi_cubit.dart (singleton, gốc cây) · phien_goi_tu_auth.dart · an_nhac_het_han.dart ·
         pages/nang_cap_page · cho_thanh_toan_page · lich_su_mua_page · widgets/nut_nang_cap · the_goi_tai_khoan ·
         dong_nhac_het_han
```

Sửa nơi khác: `RealtimeEvent.taiKhoanNangCap` (`account.upgraded`, `canDongBoLai false`, `loiNhan null`) ·
`UserModel.loaiTaiKhoan` (`type` của `/auth/*`) · `app_router.dart` (3 `redirect` + 3 route `/premium*`) ·
`ai_chat_page.dart` (`lyDoKhoa`, Basic xét trước) · `add_transaction_page.dart` (ô Nhập nhanh) · `profile_page.dart`
(thẻ Gói) · `home_page.dart` (dòng nhắc) · `main.dart` (nối ba nguồn, `BlocProvider<GoiCubit>`) · DI · `pubspec`
(`url_launcher ^6.3.3`). **Không đổi schema Drift, không trường đồng bộ mới.**

Luồng: `/payment/subscription-info` → `trangThaiTuJson` → `GoiStore` → `GoiRepository.theoDoi` → `GoiCubit` → màn.
Router: `redirect` → Premium? qua : `NguonDemDangHoatDong.dem` → `conTaoDuoc` → `chuyenHuongTheoGoi`.

## 4. Bẫy — phá là hỏng im lặng (và những thứ đã vấp khi thi công)

1. **Basic xét TRƯỚC** ở `lyDoKhoa` — không mời người không dùng được đi tải 2,41 GB.
2. **Bằng trần là vượt** (`dangCo >= tran`); Premium → `Duoc` không nhìn số.
3. **`/subscription-info` trả `accountType`**, hướng dẫn ghi `type` — đọc cả hai.
4. **`/budget/rules?id=` là sửa**, `chuyenHuongTheoGoi` tự cho qua dù `Vuot`; `?category=` là tạo → chặn.
5. **Socket `account.upgraded` là tín hiệu** — không đọc payload (hộp đen của `events`), gọi lại API.
6. **Kho thắng `type` của phiên** — admin hạ cấp tay khi `/payment/*` hỏng thì máy giữ Premium theo cache tới lần
   `/subscription-info` trả lời được (giới hạn 15.2 spec).
7. **`context.read<GoiCubit>()`, không `BlocProvider.of`** khi muốn bắt `ProviderNotFoundException` — `BlocProvider.of`
   bọc thành `FlutterError`, 37 ca cũ đỏ cùng lúc. `laPremium == null` + không provider = **không khoá** (chỉ test cũ gặp).
8. **Không `pumpAndSettle` khi vòng xoay còn quay** (màn Đang chờ) — không lắng + làm timer poll nổ thêm; dùng `pump()`.
9. **Xoá mềm là `deletedAt`**, không phải cờ `isDeleted` (DAO lọc `deletedAt.isNull()`); ngân sách **không lặp** hết hạn ở
   **cuối kỳ đầu** (`expiresAt = min(mocKy(0), endDate)`) — hai fixture của kế hoạch sai, mã đúng.
10. **`launchUrl` không kèm `canLaunchUrl`** → không cần `<queries>` manifest; hỏng → link chép được.
11. Hàng chữ cạnh vòng xoay / khối chữ cạnh nút phải **`Flexible` / `Expanded`** — tràn 155 px và 47 px ở 360 dp khi để
    trần hay dùng `Wrap` (con của Wrap không có biên ngang).
12. **Nút Thanh toán khoá trong lúc tạo đơn** — bấm đôi là hai đơn; test bấm lần hai theo **key** vì chữ đã thành vòng xoay.
13. Hết hạn giữa phiên **không có hẹn giờ** — đổi ở lần đọc kế (`laPremium(now)` mỗi lần hỏi).
14. **`DateTime ==` đòi cùng múi giờ** — kho ghi UTC; so khoảnh khắc bằng `isAtSameMomentAs`.

## 5. Màn Stitch (lượt gọi 2026-10-06 — năm lượt trả `timeout` nhưng màn vẫn được tạo; ✅ **người dùng xác nhận tối 2026-10-06**)

| Màn / khối | id |
|---|---|
| Nâng cấp Premium | `c999da970da94cb4ab4331fc44230884` |
| Đang chờ thanh toán (chờ) | `b05060e36f974798a12b475706b038bf` |
| Thanh toán — Thành công + biến thể hết hạn | `8586dc341bb34da4b6aebe76f1bca19a` (Stitch vẽ thêm danh sách đặc quyền ở màn thành công — **không chép**, lệch có chủ ý) |
| Lịch sử mua | `e7d6609536224c4fbd2e2a94f4623e36` |
| Cá nhân — thẻ Gói | `6798f5bed0344ca0a854247db40703c7` |
| Trang chủ — dòng nhắc sắp hết hạn | `f21e76fa25b14515bbda35def51b9313` |
| Trợ lý AI — khoá Premium | `2b3fa0f69486498584fdf3a243f30147` |
| Thêm giao dịch — Nhập nhanh khoá | `21790848a0dc4e98970c0a591b88f44e` |

## 6. Nghiệm thu máy thật — 🚧 CHƯA LÀM (Task 16)

Điều kiện: người dùng tạo kênh PayOS *Thử nghiệm* và dán `PAYOS_CLIENT_ID / API_KEY / CHECKSUM_KEY` vào
`src/Backend/.env`; áp `database/19` + `prisma generate` (⚠️ không `npm install` — `postinstall` tự `generate`); webhook
qua ngrok hoặc tự ký HMAC POST `localhost:3000/api/payment/webhook`. Mười bước ở spec mục 13; ghi kết quả vào đây khi đo.

- ✅ **`database/19` đã áp lên CSDL dev tối 2026-10-06** theo cho phép đích danh của người dùng — một giao tác `pg`, tệp
  không có BOM. Đo trước/sau: `account` vẫn 19 hàng, thêm cột `premium_expires_at`, hai bảng `payment_order` /
  `payment_transaction`, sáu chỉ mục. Rồi `npx prisma generate` theo `schema.prisma` hiện tại (backend tắt sẵn);
  `account.findFirst` chạy (hết `P2022`), `payment_order.count()` = 0. Bản client Prisma sinh từ `3ef5db7` thôi cần.
- ⏳ Khoá PayOS: `grep -c '^PAYOS_' src/Backend/.env` = **0** lúc áp — chờ người dùng dán.

## 7. Giới hạn cố ý

Lùi giờ máy khi offline · kho thắng `type` · hết hạn giữa phiên không hẹn giờ · app bị giết khi đang chờ trả thì không
lưu đơn (lần mở kế `lamMoi()` thấy Premium) · tài khoản mới có 2 ví seed → Basic tạo thêm 1 · hai máy Basic cùng offline
tạo ví thứ 3 → 4 ví, vẫn dùng, không tạo thêm · return URL sang web Admin (đơn 38 mục 4 xin trang trung lập, tuỳ chọn).

## 8. Phân quyền tính năng theo gói (2026-10-08)

Bước 5 của đơn 39 (`CAN-LAM/PHAN_QUYEN_THEO_GOI_KHAO_SAT.md`). Backend (gộp `main` @ `0eb4a05f`) thêm bảng `feature` +
`account_type_permission` và trang Admin-web `/permissions`; `/payment/subscription-info` trả `limits` (5 trần) và
`features` (12 quyền) **của gói đang hiệu lực**; admin đổi xong backend phát socket `account.permissions_updated`, client
nối nó sang `RealtimeEvent.taiKhoanNangCap` → `GoiRepository.lamMoi()`.

### 8.1 Quyết định người dùng

1. **Theo bảng của server; thiếu khoá thì MỞ** — trừ `ai_assistant` · `ai_quick_input` · `ai_edge_model`, khoá với Basic
   (giữ chốt 2026-10-06). Premium còn hạn → mở hết, bỏ qua bảng.
2. Tính năng bị tắt **hiện khoá + Nâng cấp**, không ẩn.
3. Đã bật tự trả / tự trích rồi về Basic → **dừng chạy, giữ công tắc** (không sửa dữ liệu; lên lại Premium chạy tiếp).
4. Quyền chỉ chặn việc **tạo / bật mới** — dữ liệu đang có giữ nguyên.

### 8.2 Bảng quyền ↔ chỗ trong app

| Mã server | Chỗ thi hành | Thiếu khoá thì |
|---|---|---|
| `wallets` · `budgets` · `goals` (trần) | `redirectTaoTheoGoi` ở `/wallets/add`, `/budget/rules` (không `?id`), `/goals/add` | 3 |
| `bills` (trần) | `redirectTaoTheoGoi(LoaiTran.hoaDon)` ở `/bills/add` — phủ cả thẻ *Có vẻ là khoản lặp* (B2), lệnh tạo C3, deeplink | không giới hạn |
| `custom_categories` (trần) | `redirectTaoTheoGoi(LoaiTran.danhMucRieng)` ở `/categories/child/new`, `/categories/group/new` | không giới hạn |
| `export_reports` | cửa route `redirectTheoQuyen` ở `/export-report` | mở |
| `cashflow_forecast` | khối *Dự báo 30 ngày tới* (hai chỗ dựng `_KhoiDuBao`) → thẻ khoá | mở |
| `anomaly_spending_insights` | câu *chi bất thường* ở khối Nhận xét Phân tích: `GoiSoPhanTich.tu(boChiBatThuong:)` bỏ câu, `KhoiNhanXet.chanDuoi` = dòng 🔒 **chỉ khi thật có bất thường** | mở |
| `smart_budget_rebalancing` | thẻ *Đề xuất cân đối* (trang Ngân sách) → thẻ khoá, câu Nhận xét bỏ kế hoạch; thông báo `budgetRebalance` thôi sinh (`loadKeHoach` trả `null`) | mở |
| `bill_auto_pay` | công tắc *Tự trả* (form thêm / sửa hoá đơn) → công tắc khoá; `runAutoPays` bỏ lượt | mở |
| `goal_auto_deposit` | công tắc *Trích tự động* → khoá; mục tiêu **mới** không quyền thì tắt sẵn; `runAutoDeposits` bỏ lượt | mở |
| `ai_edge_model` | màn *Cài đặt AI* → chỉ thẻ khoá (không nút tải, không công tắc); phần Gemma của `/quet` | **khoá với Basic** |
| `ocr_receipt` | nút *Quét* Trang chủ → `/premium?quyen=ocr_receipt`; `NhapBienLai` bỏ lượt (**hàng chờ + ảnh giữ nguyên**) | mở |
| `bank_notification_parser` | công tắc *Đọc biến động số dư* (D1) → khoá; `NhapBienDong` không bật đọc | mở |
| `ai_assistant` · `ai_quick_input` | `lyDoKhoa` màn Trợ lý AI; ô Nhập nhanh — đọc qua `coQuyen` | **khoá với Basic** |
| `financial_health_fhs` | **bỏ qua** — app không có màn FHS | — |

*Nhắc ghi sau khi dùng app ngân hàng* không thuộc quyền nào — để mở.

### 8.3 Một định nghĩa, bốn cửa

- **`duocDung(MaQuyen, TrangThaiGoi, now)`** (`premium/domain/quyen_tinh_nang.dart`) là định nghĩa duy nhất: Premium còn
  hạn → `true`; bảng đã lưu là **của Basic** (`!goi.laPremium(goi.nhanLuc)`) và có khoá → theo khoá; còn lại →
  `MaQuyen.macDinhKhiThieu`. `enum MaQuyen` mang `maServer`, `ten` (chữ trên thẻ khoá và màn Nâng cấp), `macDinhKhiThieu`.
- **Trong cây widget:** `GoiCubit.coQuyen(MaQuyen)`, extension `context.coQuyen` (watch) / `context.coQuyenDoc` (read)
  ở `premium/presentation/co_quyen.dart` — không provider thì **không khoá** (test cũ). Widget ở
  `premium/presentation/widgets/the_khoa_quyen.dart`: `TheKhoaQuyen` (thẻ 🔒 + `NutNangCap(quyen:)`), `KhoaTheoQuyen`
  (bọc con), `DongKhoaQuyen` (dòng khoá trong khối Nhận xét), `DongKhoaCongTac` (*"Cần Premium"* / *"Tạm dừng — cần
  Premium"* khi giá trị đang lưu là bật).
- **Ngoài cây widget:** `coQuyenNen(MaQuyen)` (`premium/data/co_quyen_nen.dart`) đọc `GoiRepository.hienTai`; chưa có
  phiên → `true`. DI bọc `runAutoPays` · `runAutoDeposits` · `loadKeHoach` · `NhapBienDong.batBienDong` ·
  `NhapBienLai.coQuyen`. Không quyền → bỏ lượt, **không ghi gì, không đổi mốc**.
- **Route:** `redirectTaoTheoGoi(LoaiTran)` (trần) và `redirectTheoQuyen(MaQuyen)` (bật/tắt) ở `premium/data/chan_theo_goi.dart`;
  màn Nâng cấp nhận `?tran=` hoặc `?quyen=<maServer>` (`duongNangCap`), mã lạ → như không có tham số.

### 8.4 Ba lỗi của mã backend viết sẵn — đã đóng

Backend tự sửa 7 tệp client (`TranGoi` thêm `hoaDon` · `danhMucRieng`, `TrangThaiGoi.quyenTinhNang`, tám getter
`GoiCubit.duoc…`) nhưng chỉ hai getter có chỗ gọi, và:

1. `TrangThaiGoi.duocDung` đọc bảng **không xét hạn** — Premium hết hạn lúc offline giữ bảng Premium, mở mọi tính năng.
   → `duocDung` xét `laPremium(now)` và `laPremium(nhanLuc)`; getter cũ **bỏ hết**.
2. Đếm danh mục riêng tính cả **13 bản sao mặc định** do seeder tạo (`isDefault: false`) — trần 5 thì Basic không tạo được
   danh mục nào. → `laBanSaoMacDinh` (`category/domain/ban_sao_mac_dinh.dart`), seeder dùng lại cùng hàm.
3. Đếm hoá đơn tính cả kỳ **`Skipped`**. → đếm qua `conPhaiTra` (`bill/domain/bill_pay_status.dart`).

### 8.5 Bẫy

1. ⚠️ **Đừng xét bảng bằng `goi.loai`.** Server trả `accountType` là gói **gốc** (`'Premium'` cả khi đã hết hạn) còn
   `features` / `limits` là của gói **hiệu lực** (`payment.service.js`, `effectiveType`).
2. **Test quét `lib/` thứ 21** — `test/features/premium/quyen_tinh_nang_mot_noi_test.dart`: `quyenTinhNang` chỉ được đọc ở
   `quyen_tinh_nang.dart` (và kho ở `trang_thai_goi.dart`); chuỗi mã quyền server chỉ nằm ở `MaQuyen`.
3. `redirectTaoTheoGoi` đọc `sl<GoiRepository>()` **và** `sl<NguonDemDangHoatDong>()` lúc chạy — test dựng `AppRouter`
   thật rồi đi qua route tạo (nay thêm `/bills/add`, `/categories/*/new`) phải đăng ký cả hai.
4. `context.watch<GoiCubit>()` — một `emit` cần **hai** nhịp `pump` mới tới widget trong test.
5. Mục tiêu **mới** không quyền trích: tắt sẵn đặt ở `didChangeDependencies` lần đầu (cờ `_daXetQuyenTrich` — xét đúng
   một lần, xét lại ở mỗi lần dựng là đè lựa chọn người dùng vừa gạt). Mục tiêu đang sửa giữ giá trị đã lưu.
6. Nút Quét Trang chủ **chưa có widget test** (khung test Trang chủ nặng) — nghiệm thu máy thay.

### 8.6 Màn Stitch (người dùng xác nhận 2026-10-08; cả ba lượt gọi `timeout`, màn hiện sau ~10 phút)

| Màn / khối | id |
|---|---|
| Thẻ khoá trong trang + dòng khoá chi bất thường | `595529bf…` |
| Băng khoá công tắc (form hoá đơn) | `68593384…` |
| Nâng cấp mở từ tính năng bị khoá | `9db35f88…` |

### 8.7 Nghiệm thu máy thật — 🚧 chưa làm (Task 10)

OnePlus, tài khoản Basic mới (`POST /api/auth/register`). Kịch bản ở spec mục 8; kết quả ghi vào đây.
