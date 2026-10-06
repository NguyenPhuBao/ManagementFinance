# Premium qua PayOS — phía client — thiết kế

**Ngày:** 2026-10-06. **Trạng thái:** thiết kế người dùng duyệt trong chat (tám câu hỏi · hướng kiến trúc · năm phần,
mười bốn lượt AskUserQuestion qua hai phiên — bàn giao `flowmoney-handoff-2026-10-06-payos-brainstorm.md` §3 ghi hai câu
đầu); bản viết **chờ người dùng duyệt**; **chưa có kế hoạch, chưa có mã**. Kế hoạch sẽ ở
`docs/superpowers/plans/2026-10-06-premium-payos-client.md` (gitignore).

Backend (NPBao) dựng module thanh toán PayOS, gộp `main` @ `872462f` ngày 2026-10-06 (commit gộp `f088b2a`); hướng dẫn
cho client ở `docs/Payment/CLIENT_INTEGRATION_GUIDE.md` (= `docs/superpowers/backend/CAN-LAM/CLIENT_INTEGRATION_GUIDE.md`).
Bản này là phần **client** của tính năng ấy, và nó **không** chép hướng dẫn: ở năm chỗ hướng dẫn lệch mã backend (mục 1.2),
bản này theo **mã**.

> **Chỗ thêm lúc viết, chưa nói trong chat — đọc kỹ khi duyệt:**
> 1. **Tài khoản mới được seed sẵn HAI ví** (`Tiết kiệm` + `Tiền mặt`, yêu cầu sản phẩm chốt 2026-09-05,
>    `DefaultAccountDataInitializer`). Với trần **3 ví**, người dùng Basic mới chỉ tạo thêm được **một** ví rồi chạm trần.
>    Bản này **giữ 3** như đã chốt ở câu 2; nếu muốn khác, đổi **một** hằng `TranGoi.macDinh` (mục 5.2) — không đổi gì khác.
> 2. **`GET /payment/subscription-info` trả `accountType`, hướng dẫn ghi `type`** (`payment.service.js:235`). Client đọc
>    `accountType ?? type`; chỗ lệch thứ **năm** thêm vào đơn CAN-LAM (mục 14).
> 3. **Hết hạn giữa phiên không có hẹn giờ**: trạng thái đổi ở **lần đọc kế** (mở màn, `resumed`, bấm Tạo, gửi câu hỏi).
>    Một người Premium để app mở liên tục đúng lúc hết hạn vẫn thấy Premium tới khi chạm vào thứ gì — chấp nhận, ghi ở mục 15.
> 4. **`GoiCubit` nghe phiên đăng nhập qua `main.dart`**, không sửa `AuthBloc` — đúng khuôn `NhatKyThongBao.datNguonPhien`
>    (`AuthBloc` là factory, `sl<AuthBloc>()` là một bloc mới chưa đăng nhập).
> 5. **`url_launcher` không gọi `canLaunchUrl`** → không cần `<queries>` trong `AndroidManifest.xml` (vùng mù của
>    `flutter test`, bẫy 7.11). `launchUrl` trả `false` / ném → màn hiện **link chép được** thay vì báo lỗi.
> 6. **Khoá ô Nhập nhanh chỉ ở giao diện**: `DocCauBangAi`, `docCauGiaoDich` không đổi một dòng. Điền sẵn từ biến động /
>    biên lai (D1) đi `dienSanBienDongTuQuery`, không qua ô ấy, nên Basic vẫn dùng D1 bình thường.

---

## 1. Vì sao, và điều đo được

### 1.1 Backend đã có gì

- 5 route `api/payment.routes.js`: `POST /create-order` · `GET /order-status/:orderCode` · `GET /subscription-info` ·
  `GET /history` · `POST /webhook`. Giá **49.000 đ / 30 ngày**; mua khi còn hạn thì **cộng dồn** 30 ngày
  (`payment.service.js:111-117`). Đơn hết hạn sau **30 phút** (`:16`).
- Scheduler 0h: cảnh báo trước 3 ngày và hạ về Basic khi hết hạn — **chỉ đi EventBus** (`payment.expiring_soon`,
  `payment.expired`), app không nhận gì.
- `/auth/login`, `/auth/profile` và JWT **đã trả `type`** (`Basic` | `Premium`) — không kèm hạn. Hạn chỉ có ở
  `/subscription-info`: `{accountType, premiumExpiresAt, daysRemaining, isExpired}`.
- **Backend không chặn chức năng nào theo gói.** Mọi đặc quyền là việc của client.

### 1.2 Hướng dẫn lệch mã (năm chỗ — bản này theo mã)

| # | Hướng dẫn nói | Mã thật |
|---|---|---|
| 1 | Nghe socket `payment.success` | Sự kiện tới app là **`account.upgraded`** `{type, premiumExpiresAt}` (`payment.service.js:167-171`); `payment.success` chỉ đi EventBus, không ai nghe |
| 2 | Trả xong về app | `PAYOS_RETURN_URL` / `CANCEL_URL` trỏ **web Admin** (`managementfinance-admin.vercel.app/payment/…`), không có deep link |
| 3 | Base URL `localhost:10000` | Dev chạy **3000** |
| 4 | `http` + `url_launcher` | Dự án dùng **Dio** (`sl<Dio>()` có `AuthInterceptor`); `url_launcher` **chưa có** trong `pubspec` |
| 5 | `/subscription-info` trả `type` | Trả **`accountType`** |

### 1.3 Client hiện có gì để tựa vào

- Khuôn lưu theo tài khoản bằng secure storage (`SecureStorageNotificationPrefsStore`), và `UserModel` được cache đã mang
  `status · countdown · countdownNhanLuc` (`AuthRepositoryImpl._ghiNguoiDung`).
- Kênh realtime: `RealtimeEvent` ba giá trị, tên lạ → `null`, `events` **không đọc payload** (hộp đen); ngoại lệ duy nhất
  `account.force_logout` đi cửa riêng.
- Màn Trợ lý AI đã có **băng khoá có nút** (`cauKhoaHoiDap` + *Cài đặt AI*, `ai_chat_page.dart:86`).
- Ba route tạo: `/wallets/add` · `/budget/rules` (không `?id` = tạo mới) · `/goals/add` — đều ngoài shell.
- Vòng đời app là một stream (`AppLifecycleWatcher`, singleton DI); dòng nhắc có ✕ trong bộ nhớ (`AnNhacViTrungTen`).
- Đồng bộ có **năm** nguồn kích hoạt: 2 s sau ghi · 15 phút · đổi mạng · mở app · socket `sync.completed`.

---

## 2. Quyết định người dùng đã chốt

| # | Câu hỏi | Chốt |
|---|---|---|
| 1 | Premium khác Basic ở đâu | *Theo đúng đặc quyền backend ghi* — rồi đo từng đặc quyền ở câu 3–4 |
| 2 | Trần Basic | **3 ví · 3 ngân sách đang hoạt động**; người đã vượt **giữ nguyên**, chỉ **không tạo thêm**; đủ trần thì nút Tạo dẫn sang màn Nâng cấp |
| 3 | "Báo cáo tài chính AI chuyên sâu" là gì | **Màn Trợ lý AI** (kể cả lệnh tạo C3 — cùng ô nhập) **và ô Nhập nhanh** của màn Thêm giao dịch (khoá cả ô). Khối Nhận xét (luật + mẫu câu), gợi ý danh mục, xuất báo cáo, OCR biên lai, D1 **giữ cho mọi người** |
| 4 | "Đồng bộ đa thiết bị tức thì" | **Không tách gì** — đồng bộ giữ nguyên cho mọi tài khoản; màn Nâng cấp **không quảng cáo** đặc quyền này; xin backend sửa chữ |
| 4b | Số đặc quyền | **Bốn**: thêm **mục tiêu tiết kiệm Basic ≤ 3 đang hoạt động**, cùng khuôn ví / ngân sách |
| 5 | Premium khi offline | **Cache hạn theo tài khoản, so giờ máy**; làm mới khi đăng nhập · mở app · socket · sau khi trả; `/payment/*` hỏng thì rơi về `type` của phiên. Lùi giờ máy khi offline kéo dài được Premium — **chấp nhận** |
| 6 | Ai thi hành trần | **Client thi hành, server quyết CON SỐ**: xin `limits {wallets, budgets, goals}` trong `/subscription-info`, thiếu thì **3/3/3** |
| 7 | Màn thanh toán | **Mở `checkoutUrl` ngoài app** (`url_launcher`, trình duyệt ngoài) + màn *Đang chờ thanh toán* trong app. Không WebView, không vẽ QR |
| 8 | Cách thử | **Sandbox PayOS trên dev** (người dùng tạo kênh Thử nghiệm + dán khoá vào `.env`; áp `database/19` cần cho phép đích danh; webhook qua ngrok hoặc tự ký) |
| — | Kiến trúc | **A** — mô-đun `features/premium/` riêng, **một** định nghĩa `conTaoDuoc`, **một** cửa chặn ở `redirect` của router |

---

## 3. Phạm vi

**Làm:** mô-đun `premium` (mô hình, cache, API, cubit) · cửa chặn ba route tạo · khoá Trợ lý AI + Nhập nhanh cho Basic ·
màn Nâng cấp · màn Đang chờ thanh toán (chờ / thành công / hết hạn) · màn Lịch sử mua · thẻ Gói ở tab Cá nhân · dòng nhắc
≤ 3 ngày ở Trang chủ · `RealtimeEvent.taiKhoanNangCap` · `UserModel.loaiTaiKhoan` · gói `url_launcher` · đơn CAN-LAM ·
tài liệu.

**Không làm (cố ý, ghi để khỏi tìm lại):** chặn ở server · chặn ở repository lúc lưu · WebView / QR trong app · lưu đơn
chờ để mở lại sau khi app bị giết · thông báo cục bộ "sắp hết hạn" (dòng nhắc Trang chủ đủ) · huy hiệu Premium cạnh tên
ở drawer / Trang chủ · mục drawer riêng · khoá xuất báo cáo, OCR, D1, khối Nhận xét · đổi đồng bộ theo gói · hẹn giờ hạ
cấp giữa phiên · đổi schema Drift · trường đồng bộ mới.

---

## 4. Kiến trúc và cây tệp

```
lib/features/premium/
  domain/
    trang_thai_goi.dart      LoaiGoi {basic, premium} · TrangThaiGoi · trangThaiTuJson · laPremium(now) · soNgayConLai(now)
    tran_goi.dart            TranGoi (macDinh 3/3/3) · LoaiTran {vi, nganSach, mucTieu} · KetQuaTran · conTaoDuoc(...)
    chuyen_huong_theo_goi.dart  chuyenHuongTheoGoi(uri, ketQua) → String?   (phần thuần của redirect)
    don_thanh_toan.dart      DonThanhToan · TrangThaiDon {pending, paid, cancelled, expired} · parse
    cau_loi_thanh_toan.dart  cauLoiThanhToan(Object e) → câu ngắn (không URL, không stack)
  data/
    goi_store.dart           GoiStore (abstract) · SecureStorageGoiStore · InMemoryGoiStore
    payment_api.dart         PaymentApi(Dio): taoDon · trangThaiDon · thongTinGoi · lichSu
    dem_dang_hoat_dong.dart  DemDangHoatDong: Future<int> dem(LoaiTran)   (đọc DAO/repository sẵn có)
    goi_repository.dart      GoiRepository: hienTai · theoDoi · lamMoi() · datTaiKhoan · xoaPhien
    mo_lien_ket.dart         moLienKetNgoai(Uri) → bool   ← tệp DUY NHẤT import url_launcher
  presentation/
    cubit/goi_cubit.dart     GoiCubit(GoiRepository) — state = TrangThaiGoi
    an_nhac_het_han.dart     ValueNotifier<DateTime?> (ngày đã ✕) — khuôn AnNhacViTrungTen
    pages/nang_cap_page.dart            /premium
    pages/cho_thanh_toan_page.dart      /premium/cho-thanh-toan
    pages/lich_su_mua_page.dart         /premium/lich-su
    widgets/the_goi_tai_khoan.dart      thẻ ở tab Cá nhân
    widgets/dong_nhac_het_han.dart      dòng nhắc Trang chủ
    widgets/nut_nang_cap.dart           nút dùng chung cho hai băng khoá AI
```

Sửa ở nơi khác: `realtime_event.dart` (+1 giá trị) · `user_model.dart` + `auth_repository_impl.dart` (`loaiTaiKhoan`) ·
`app_router.dart` (3 `redirect` + 3 route) · `ai_chat_page.dart` (lý do khoá thứ ba) · `add_transaction_page.dart`
(khoá ô `nhap-nhanh-o`) · `profile_page.dart` (thẻ) · `home_page.dart` (dòng nhắc) · `injection_container.dart` ·
`main.dart` (nối phiên, vòng đời, socket) · `pubspec.yaml` (`url_launcher`).

**Luồng dữ liệu:** `PaymentApi.thongTinGoi` → `trangThaiTuJson` → `GoiStore.ghi` → `GoiRepository.theoDoi` → `GoiCubit`
→ (màn Cá nhân, Trang chủ, Trợ lý AI, Thêm giao dịch, Nâng cấp). Router `redirect` → `DemDangHoatDong.dem` +
`GoiRepository.hienTai` → `conTaoDuoc` → `chuyenHuongTheoGoi`.

Lớp AI **không** chạm: `conTaoDuoc` không ở `ai_edge/`; không tool nào đọc trạng thái gói.

---

## 5. Mô hình thuần (`premium/domain/`)

### 5.1 `TrangThaiGoi`

```dart
enum LoaiGoi { basic, premium }
class TrangThaiGoi {
  final LoaiGoi loai;
  final DateTime? hetHan;     // null = CHƯA BIẾT hạn (type Premium mà /payment/* chưa trả), không phải "vô hạn"
  final TranGoi tran;
  final DateTime nhanLuc;
  bool laPremium(DateTime now) => loai == LoaiGoi.premium && (hetHan == null || hetHan!.isAfter(now));
  int? soNgayConLai(DateTime now);   // null khi không Premium hoặc chưa biết hạn; 0 = hết hạn hôm nay
  static const basicMacDinh = ...;   // Basic, tran = TranGoi.macDinh
}
```

- `trangThaiTuJson(Map json, {required DateTime nhanLuc})` đọc `accountType ?? type` (so không phân biệt hoa thường),
  `premiumExpiresAt` (ISO; rác → `null`), `limits` (thiếu / rác → `TranGoi.macDinh`), tuỳ chọn `price`, `packageDays`
  (mục 9.1). **Không ném** với bất kỳ JSON nào.
- `trangThaiTuLoaiPhien(String? type)` — nhánh rơi về: `'Premium'` → premium, `hetHan: null`; còn lại → Basic.
- `soNgayConLai` dùng **ngày lịch** (`DateUtils.dateOnly`-tương-đương, tự viết để thuần Dart): hết hạn 23:00 hôm nay
  là *còn 0 ngày*, không phải *−1*.

### 5.2 `TranGoi` và `conTaoDuoc`

```dart
class TranGoi { final int vi, nganSach, mucTieu; static const macDinh = TranGoi(vi: 3, nganSach: 3, mucTieu: 3); }
enum LoaiTran { vi, nganSach, mucTieu }
sealed class KetQuaTran { Duoc(); Vuot(LoaiTran loai, int tran, int dangCo); }
KetQuaTran conTaoDuoc({required LoaiTran loai, required int dangCo, required TrangThaiGoi goi, required DateTime now});
```

- Premium (`laPremium(now)`) → `Duoc` luôn, không nhìn `dangCo`.
- Basic → `dangCo >= tran.<loai>` ⇒ `Vuot`. **Bằng** trần là vượt (3/3 thì không tạo cái thứ tư).
- `dangCo` đếm **đang hoạt động** (mục 7.1). Hàm **không** biết đếm — nó nhận số.

### 5.3 `chuyenHuongTheoGoi(Uri uri, KetQuaTran ket)` → `String?`

`Vuot` → `'/premium?tran=<vi|ngan_sach|muc_tieu>'`; `Duoc` → `null` (đi tiếp). Hàm nhận `uri` để **từ chối chặn**
`/budget/rules?id=…` (sửa) — nghĩa là người gọi có thể truyền `ket` bất kỳ cho route sửa mà kết quả vẫn `null`; ca test
canh đúng vế ấy.

### 5.4 `DonThanhToan`

`{orderCode (int), checkoutUrl (Uri), soTien, hetHanLuc}` từ `data` của `create-order`; `TrangThaiDon` từ chuỗi
`status` của `order-status` (`PAID` → `paid`, lạ → `pending` — không coi chuỗi lạ là đã trả).

### 5.5 `cauLoiThanhToan(Object e)`

`DioException` mạng → *"Không có kết nối. Thử lại khi có mạng."*; 401 → *"Phiên hết hạn, đăng nhập lại."*; 5xx / khác →
*"Máy chủ chưa phản hồi. Thử lại sau."*. **Không** in URL, mã, stack (bài học `cauLoiTai`).

---

## 6. Nguồn, cache, làm mới (`premium/data/`)

### 6.1 `GoiStore`

Secure storage, khoá **`goi_tai_khoan_<idaccount>`**, giá trị JSON `{loai, hetHan, tran, nhanLuc}`. `doc(idaccount)` trả
`null` khi chưa có / rác (không ném). **Không xoá khi đăng xuất** (tài khoản khác dùng khoá khác; cùng tài khoản đăng
nhập lại thì có sẵn trạng thái cho tới lượt làm mới). `InMemoryGoiStore` cho test.

### 6.2 `PaymentApi`

Bốn hàm trên `sl<Dio>()` (token do `AuthInterceptor` gắn). Bóc `data` theo bao `{success, message, data}` của backend.
`taoDon()` gửi `{packageType: 'PREMIUM_1_MONTH'}`.

### 6.3 `GoiRepository`

```dart
TrangThaiGoi get hienTai;             // đồng bộ, đọc RAM
Stream<TrangThaiGoi> get theoDoi;     // broadcast, phát mỗi khi đổi
Future<void> datTaiKhoan(int idaccount, {String? loaiPhien});  // mở phiên: nạp store; trống → trangThaiTuLoaiPhien
Future<void> lamMoi();                // gọi thongTinGoi → ghi store → phát; KHÔNG BAO GIỜ ném
void xoaPhien();                      // đăng xuất: về basicMacDinh trong RAM, store giữ
```

- `lamMoi()` hỏng (mạng, 401, 5xx, `P2022` thời dev chưa áp migration 19) → **giữ nguyên** trạng thái đang có +
  `debugPrint('[Premium] lamMoi hỏng: …')`. Hai lượt `lamMoi()` chồng nhau → lượt sau chờ lượt trước (một `Future` chung).
- **Store thắng `type` của phiên** khi cả hai có; `type` chỉ dùng khi store trống. Hệ quả ghi ở mục 15.
- `nhanLuc` của lượt làm mới gần nhất dùng cho **giãn 5 phút** ở `resumed`.

### 6.4 Khi nào làm mới — nối ở `main.dart` / DI, không sửa `AuthBloc`

| Mốc | Cách nối | Giãn |
|---|---|---|
| Phiên vào `AuthSuccess` lần đầu (đăng nhập, kiểm phiên lúc mở app) | `GoiCubit.theoPhien(authBloc.stream)` — khuôn `datNguonPhien` | không |
| `AuthUnauthenticated` | `xoaPhien()` | — |
| App `resumed` | `sl<AppLifecycleWatcher>().stream` | ≥ 5 phút kể từ `nhanLuc` |
| Socket `account.upgraded` | `RealtimeChannel.events` → `RealtimeEvent.taiKhoanNangCap` | không — tín hiệu, gọi ngay |
| Đơn `PAID` (mục 9.3) | màn Đang chờ gọi `lamMoi()` | không |

### 6.5 `RealtimeEvent.taiKhoanNangCap`

Giá trị thứ **tư**, dịch từ `'account.upgraded'`. `canDongBoLai = false` (không có dữ liệu đồng bộ mới), `loiNhan = null`
(im — máy vừa trả đã có màn Thành công; máy khác đổi thẻ ở Cá nhân là đủ). **Không đọc payload** — đúng cam kết hộp đen
của `events`; trạng thái thật lấy bằng `lamMoi()`.

### 6.6 `UserModel.loaiTaiKhoan`

Trường mới, `String`, đọc `user.type` của `/auth/login` và `type` của `/auth/profile` (`_dongBoTrangThai` ghi lại khi
đổi), mặc định `'Basic'` khi thiếu. Chỉ phục vụ nhánh rơi về 6.3; không màn nào đọc trực tiếp.

### 6.7 `DemDangHoatDong`

| Loại | Đếm | Nguồn sẵn có |
|---|---|---|
| Ví | chưa xoá **và** không lưu trữ | `WalletDao.getActive` |
| Ngân sách | chưa xoá **và** `!isExpired(now)` | `BudgetRepository` / DAO + `BudgetEntity.isExpired` |
| Mục tiêu | chưa xoá **và** `!daHoanThanh` | `GoalEntity.daHoanThanh` |

Lưu trữ một ví / hoàn thành một mục tiêu là **nhả một chỗ** — cố ý, cùng luật với bộ chọn ví.

---

## 7. Cầu chì trần — `redirect` của router

### 7.1 Ba route, một cửa

```dart
GoRoute(path: '/wallets/add', redirect: (_, s) => _chanTheoGoi(s.uri, LoaiTran.vi), ...)
GoRoute(path: '/budget/rules', redirect: (_, s) => _chanTheoGoi(s.uri, LoaiTran.nganSach), ...)  // ?id → không chặn
GoRoute(path: '/goals/add',   redirect: (_, s) => _chanTheoGoi(s.uri, LoaiTran.mucTieu), ...)
```

`_chanTheoGoi` (async, trong `app_router.dart`, mỏng): `hienTai` của `sl<GoiRepository>()` → Premium thì trả `null`
**không đếm** (rẻ) → Basic thì `DemDangHoatDong.dem(loai)` → `conTaoDuoc` → `chuyenHuongTheoGoi`. Đếm hỏng (ném) →
`null`, cho qua — một lỗi đọc CSDL không được biến thành một màn Nâng cấp sai chỗ.

Mọi lối vào form đi qua cửa này: nút + trên ba trang danh sách, thẻ *Chưa đặt ngân sách* (`/budget/rules?category=…`),
thẻ *Có vẻ là khoản lặp* (`/bills/add` — **hoá đơn không có trần**, không chặn), lệnh tạo C3 (mở `/budget/rules`,
`/goals/add`), deeplink thông báo. Route **sửa** (`/wallets/:id/edit`, `/budget/rules?id=`, `/goals/:id/edit`) không chặn.

### 7.2 Hạ cấp

Không xoá, không ẩn, không đổi cờ gì: người có 5 ví vẫn thấy và dùng cả 5; lưu trữ, sửa, xoá bình thường; chỉ nút tạo
dẫn sang Nâng cấp cho tới khi số đang hoạt động < trần. Không có bước "chọn ví giữ lại".

---

## 8. Khoá AI cho Basic

### 8.1 Màn Trợ lý AI

- Màn **vẫn mở**: xem lịch sử phiên, bánh răng → Cài đặt AI vẫn vào được.
- Ô nhập `enabled: false`, bốn chip không bấm (`onPressed: null`), **kể cả lệnh tạo C3** (cùng ô nhập — chốt câu 3).
- Băng khoá: `cauKhoaHoiDap({required bool coTep})` đổi thành `LyDoKhoaHoiDap? lyDoKhoa({required bool laPremium,
  required bool coTep, required bool congTacBat})` với enum `{goiBasic, chuaCoMoHinh, congTacTat}` — **thứ tự xét:
  `goiBasic` TRƯỚC** (không mời người không dùng được tải 2,41 GB), rồi `chuaCoMoHinh`, rồi `congTacTat`. Mỗi lý do một
  câu + một nút: *Nâng cấp* → `push('/premium')` / *Cài đặt AI* như cũ. Hai câu cũ `kChuaCoMoHinh`, `kCongTacDangTat`
  giữ nguyên chữ.
- Khe tiêm `AiChatPage.laPremium` (`bool?`, `null` = đọc `GoiCubit`) để widget test không chạm DI — cùng khuôn `coMoHinh`.
- Hết hạn giữa phiên: lượt `_hoi` kế kiểm `laPremium(now)` → băng hiện, ô khoá; câu đang sinh **không bị cắt**.
- Premium lên giữa phiên (socket → cubit) → băng biến mất, ô mở, không cần rời màn (`BlocBuilder`).

### 8.2 Ô Nhập nhanh (màn Thêm giao dịch)

- Basic: `TextField` `nhap-nhanh-o` `enabled: false`, chữ gợi ý *"Tính năng Premium"*; dưới ô một dòng *"Nâng cấp để
  đọc câu bằng AI"* có nút → `push('/premium')`. Nút *Điền* không hiện.
- Phần còn lại của form (bàn phím số, danh mục, ví, ghi chú, thẻ gợi ý B1 / theo số tiền, đề xuất từ khoá) **không đổi**.
- Điền sẵn từ D1 / biên lai / thẻ hoá đơn / C3 **không** qua ô này → không ảnh hưởng.
- Khe tiêm `laPremium` như 8.1.

---

## 9. Luồng thanh toán

### 9.1 Màn Nâng cấp — `/premium` (ngoài shell, `push` từ mọi nơi)

- Đọc `GoiCubit`. **Basic:** thẻ *"Gói hiện tại: Basic"*; nếu có `?tran=` thì câu đầu *"Bạn đã dùng 3/3 ví của gói
  Basic"* (số từ `TranGoi` hiện tại, loại từ query); bốn đặc quyền: *Không giới hạn ví* · *Không giới hạn ngân sách* ·
  *Không giới hạn mục tiêu tiết kiệm* · *Trợ lý AI & Nhập nhanh bằng AI*; giá *49.000 đ / 30 ngày*; nút **Thanh toán**.
- **Premium:** thẻ *"Premium — còn N ngày (đến dd/MM/yyyy)"* (chưa biết hạn → chỉ *"Premium"*); nút **Gia hạn thêm 30
  ngày** (cùng đường tạo đơn — backend cộng dồn); liên kết **Lịch sử mua**.
- Giá / số ngày: hằng client `49000` / `30`; `price`, `packageDays` của `/subscription-info` **đè** khi có (xin ở CAN-LAM).
  Tiền in qua `CurrencyFormatter.format`.
- **Không** nhắc *đồng bộ tức thì* (câu 4).

### 9.2 Bấm Thanh toán

`PaymentApi.taoDon()` → `DonThanhToan` → `push('/premium/cho-thanh-toan', extra: don)` → màn ấy gọi
`moLienKetNgoai(don.checkoutUrl)` ở `initState` (sau khung đầu). Tạo đơn hỏng → SnackBar `cauLoiThanhToan(e)` + nút thử
lại, **không rời màn**; nút Thanh toán khoá trong lúc chờ (chống bấm đôi → hai đơn).

### 9.3 Màn Đang chờ thanh toán — `/premium/cho-thanh-toan`

- Vào mà thiếu `extra` (deeplink tay, dựng lại sau khi app bị giết) → `redirect` về `/premium`.
- Hiện: số tiền · mã đơn · đếm ngược tới `hetHanLuc` · dòng *"Đang chờ xác nhận từ ngân hàng…"*.
- **Hỏi `order-status` mỗi 3 s khi màn đang hiện** — ba vế như `TheoDoiXem`: route hiện tại (`ModalRoute.isCurrent`),
  `TickerMode`, vòng đời `resumed`. Hỏi **ngay** khi: app `resumed`; socket `taiKhoanNangCap`; bấm **Tôi đã chuyển
  khoản**. Hỏi hỏng → im, lượt sau thử (không giãn cách — màn này sống tối đa 30 phút).
- Nút **Mở lại trang thanh toán** (gọi lại `moLienKetNgoai`); mở hỏng → hiện `checkoutUrl` dạng `SelectableText` + nút
  Chép. Nút **Huỷ** chỉ `pop` (backend không có API huỷ; đơn tự hết hạn).
- `paid` → dừng hỏi → `lamMoi()` → trạng thái **Thành công** trong cùng màn: *"Nâng cấp Premium thành công"*, hạn mới
  (từ `GoiCubit`, không từ `order-status`), nút **Xong** → `pop` **hai** lớp (về màn trước Nâng cấp). Đến từ cửa chặn thì
  người dùng tự bấm + lần nữa; **không** tự mở form.
- `expired` / `cancelled`, hoặc đếm ngược về 0 → dừng hỏi → câu tương ứng + nút **Tạo đơn mới** (`pop` về Nâng cấp).
- Rời màn (Back) → dừng hỏi. Socket `account.upgraded` vẫn làm `lamMoi()` ở tầng repository nên trả xong sau khi đã rời
  màn thì thẻ Cá nhân vẫn đổi.

### 9.4 Lịch sử mua — `/premium/lich-su`

`PaymentApi.lichSu()` (trang 1, 20 dòng — không phân trang vô hạn, YAGNI); mỗi dòng: ngày tạo · số tiền · trạng thái
(chữ tiếng Việt do client chọn: *Đã thanh toán / Chờ thanh toán / Đã huỷ / Hết hạn*). Rỗng → câu rỗng; lỗi →
`cauLoiThanhToan` + Thử lại.

### 9.5 Nhắc hết hạn — Trang chủ

`DongNhacHetHan` dưới thẻ tổng: hiện khi `soNgayConLai(now) ∈ [0, 3]` — *"Premium còn N ngày"* / *"Premium hết hạn hôm
nay"*, nút **Gia hạn** → `push('/premium')`, ✕ → `AnNhacHetHan` ghi **ngày** đã ẩn (bộ nhớ; qua ngày mới hiện lại; đăng
nhập lại đặt lại). Hết hạn rồi (`laPremium == false`) → **không** nhắc; thẻ Cá nhân nói Basic. Chưa biết hạn → không nhắc.

---

## 10. Màn hình và điểm vào

- **Điểm vào có chủ ý duy nhất:** tab **Cá nhân** — `TheGoiTaiKhoan` ngay dưới đầu trang: huy hiệu *Basic* / *Premium*,
  hạn (hoặc câu mời), nút *Nâng cấp* / *Gia hạn* → `/premium`. **Drawer không thêm mục** (nhóm D: không đích nào ở hai
  chỗ; Cá nhân đã ở thanh dưới) — ca test `kMucDrawer` không đổi.
- Trang chủ chỉ có dòng nhắc 9.5. Ba cửa chặn + hai băng khoá AI dẫn tới `/premium`. Không rải huy hiệu nơi khác.
- **Lên Stitch trước khi dựng** (memory *dua-man-moi-len-stitch*; người dùng xác nhận là phép đo duy nhất, công cụ có
  độ trễ dài): (1) Nâng cấp — Basic · Premium · biến thể có câu trần; (2) Đang chờ thanh toán — chờ · thành công · hết
  hạn/huỷ; (3) Lịch sử mua; và bốn **khối trên màn cũ**: thẻ Gói ở Cá nhân · dòng nhắc Trang chủ · băng khoá Premium ở
  Trợ lý AI · ô Nhập nhanh khoá.
- Bố cục: hàng nút / huy hiệu là `Wrap` (bẫy 360 dp của G63); mọi `IconButton` có `tooltip` (test quét 12); tiền qua
  `CurrencyFormatter.format` (test quét 2–3); mỗi màn mới một ca **360 × 640**.

---

## 11. Xử lý lỗi — tóm

| Chỗ | Hành vi |
|---|---|
| `lamMoi()` hỏng | giữ cache, `debugPrint`, không ném, không toast |
| JSON thiếu / rác | mặc định (`basicMacDinh`, `TranGoi.macDinh`, `pending`), không ném |
| Tạo đơn hỏng | SnackBar `cauLoiThanhToan` + thử lại, ở lại màn |
| Mở trình duyệt hỏng | link chép được |
| Hỏi trạng thái hỏng | im, lượt sau |
| Đếm hỏng ở `redirect` | cho qua (`null`) |
| 401 trên `/payment/*` | `AuthInterceptor` xử lý như mọi request; màn hiện câu 401 của `cauLoiThanhToan` |

---

## 12. Kiểm thử

Thứ tự TDD; ca nào **xanh ngay** phải thử bằng bản sai có chủ ý (bài học G43).

**Thuần (`test/features/premium/domain/`):** `TrangThaiGoi` — hạn tương lai / quá khứ / `null` / hết hạn hôm nay (0
ngày) / so giờ máy truyền vào; `trangThaiTuJson` — `accountType` **và** `type`, `limits` thiếu / rác / đủ, `premiumExpiresAt`
rác, JSON rỗng; `conTaoDuoc` — 3 loại × (dưới / bằng / trên trần) × (Basic / Premium), trần server đè; `chuyenHuongTheoGoi`
— ba route, `/budget/rules?id=` không chặn **dù** `ket` là `Vuot`; `DonThanhToan` parse + `status` lạ → `pending`;
`cauLoiThanhToan` — không chứa `http`.

**Data:** `GoiRepository` với `PaymentApi` giả — hỏng giữ cache; store trống rơi về `type`; store thắng `type`; hai
`lamMoi()` chồng; `SecureStorageGoiStore` theo tài khoản (hai tài khoản không đè nhau), rác → `null`;
`DemDangHoatDong` trên CSDL Drift trong RAM — ví lưu trữ / ngân sách hết hạn / mục tiêu đã đạt **không đếm**.

**Cubit:** `theoPhien` — `AuthSuccess` → `datTaiKhoan` + `lamMoi`; `AuthUnauthenticated` → về Basic; `resumed` giãn 5
phút; `taiKhoanNangCap` → `lamMoi` ngay.

**Widget (mỗi màn có ca 360 × 640):** Nâng cấp — Basic / Premium / `?tran=` / chưa biết hạn / bấm đôi chỉ một đơn;
Đang chờ — poller giả: `paid` → Thành công + `lamMoi` được gọi, `expired`, đếm ngược về 0, `resumed` hỏi ngay, rời màn
dừng hỏi, mở link hỏng → link chép; Lịch sử — rỗng / có / lỗi; thẻ Cá nhân — hai trạng thái; dòng nhắc — 3 · 0 · 4 ngày ·
hết hạn · ✕ rồi dựng lại cùng ngày không hiện; Trợ lý AI — ba lý do khoá, **Basic xét trước** khi cả ba đúng, Premium lên
giữa phiên mở ô; Thêm giao dịch — ô Nhập nhanh khoá / mở, phần còn lại của form vẫn dùng (ca lưu giao dịch tay khi Basic).

**Router:** `GoRouter` thật với `DemDangHoatDong` giả — ba route tạo chặn / không chặn, `?id=` qua, Premium không đếm
(bộ đếm giả ném mà vẫn qua), đếm ném ở Basic → qua.

**Quét:** test quét `lib/` thứ **18** — chỉ `premium/data/mo_lien_ket.dart` import `url_launcher` (khuôn
`realtime_socket.dart`, có vế tiền đề). `realtime_event_test` thêm giá trị thứ tư (`canDongBoLai false`, `loiNhan null`);
`notification_deeplink_test` không đổi (không thêm loại thông báo). Test quét 14 (`ai_edge/` không so chiều tiền) không bị
chạm; test quét 15 không đổi (không bảng mới).

**`pubspec`:** thêm `url_launcher` — **người dùng duyệt lúc thi công**. ⚠️ Gói có mã Android gốc → **dựng thử
`--release` ngay** (bài học R8 của ML Kit).

Mức nền sau lượt: `flutter test` toàn xanh (số ca ghi lại bằng máy), `flutter analyze` 21.

---

## 13. Nghiệm thu máy thật (sandbox PayOS)

Điều kiện: Realme hoặc OnePlus cắm; backend dev chạy; **người dùng** tạo kênh *Thử nghiệm* ở `my.payos.vn` và tự dán
`PAYOS_CLIENT_ID / API_KEY / CHECKSUM_KEY` vào `src/Backend/.env`; tôi **xin phép đích danh** áp
`database/19_create_payment_subscription_tables.sql` + `prisma generate` (quy tắc 1 `CLAUDE.md`; ⚠️ đừng chạy lại
`npm install` — `postinstall` tự `generate`). Webhook: ngrok nếu máy có, không thì **tự ký** payload bằng checksum key
(HMAC-SHA256 theo `payosClient`) và `POST /api/payment/webhook` vào localhost.

| # | Bước | Đạt khi |
|---|---|---|
| 1 | Tài khoản Basic có 3 ví, bấm + ở Quản lý ví | Màn Nâng cấp mở, câu *"3/3 ví"* |
| 2 | Thanh toán | Trình duyệt mở trang PayOS sandbox; app sang màn Đang chờ |
| 3 | Giả lập trả (sandbox hoặc webhook tự ký) | logcat `account.upgraded` tới; màn Đang chờ sang Thành công ≤ 3 s |
| 4 | Xong → + ở Quản lý ví | Form tạo ví mở; tạo ví thứ 4 đồng bộ lên PostgreSQL |
| 5 | Trợ lý AI · Nhập nhanh | Ô mở, hỏi được / đọc câu được |
| 6 | Tab Cá nhân · máy thứ hai (nếu có) | Thẻ *Premium — còn 30 ngày*; máy hai đổi thẻ sau socket mà không mở lại app |
| 7 | Gia hạn | Đơn mới, trả → hạn **cộng 30** ngày |
| 8 | Hạ cấp: lùi giờ máy qua hạn (không sửa CSDL) | Thẻ Basic; + bị chặn khi ≥ 3; ví thứ 4 **vẫn còn**; AI khoá; dòng nhắc không hiện |
| 9 | Cắt mạng khi đang Premium | Trợ lý AI vẫn hỏi được (cache) |
| 10 | Lịch sử mua | Thấy các đơn vừa tạo đúng trạng thái |

Bẫy đo đã biết: Realme chặn `adb install` bằng màn quét; `input text` chỉ ASCII; bàn phím Telex; `debugPrint` bị tiết
lưu — số đọc trên màn mới đủ.

---

## 14. Đơn `CAN-LAM/` và tài liệu

**Một đơn** `CAN-LAM/CLIENT_PREMIUM_PAYOS.md` (thông báo + xin nhẹ, **không chặn client**):
1. Client thi hành đặc quyền (3 trần + khoá AI) ở client; backend không cần chặn.
2. Xin thêm vào `GET /payment/subscription-info`: `limits {wallets, budgets, goals}`, `price`, `packageDays` — client có
   mặc định 3/3/3 · 49000 · 30, **không chờ**.
3. Năm chỗ hướng dẫn lệch mã (mục 1.2) — xin sửa chữ; riêng return URL: **xin một trang trung lập "quay lại ứng dụng"**
   hoặc deep link (tuỳ chọn, client không phụ thuộc).
4. Đặc quyền *đồng bộ đa thiết bị tức thì* **không thi hành** — xin bỏ khỏi chữ.
5. `README.md` mục 0 cập nhật (client được sửa, chốt 2026-10-05).

**Tài liệu client:** `docs/PREMIUM_FEATURE.md` mới (quyết định kèm lý do, bẫy, bảng nghiệm thu); hàng *Đụng vào
**Premium / thanh toán*** ở `CLAUDE.md`; khối ở mục 14 `PROJECT_CONTEXT.md`; dòng mức nền test. Spec này thêm banner
khi thi công xong, ghi *chỗ bản thi công khác bản viết*.

---

## 15. Giới hạn đã biết (cố ý)

1. **Lùi giờ máy khi offline** kéo dài Premium tới lần online kế; server vẫn hạ cấp đúng.
2. **Store thắng `type`**: nếu admin hạ cấp tay trên CSDL mà `/payment/*` đang hỏng, máy giữ Premium theo cache tới khi
   `/subscription-info` trả lời được.
3. **Hết hạn giữa phiên** đổi ở lần đọc kế, không có hẹn giờ.
4. **App bị giết trong lúc chờ trả**: đơn không lưu; `lamMoi()` ở lần mở kế thấy Premium nếu đã trả; màn Đang chờ không
   dựng lại được.
5. **Tài khoản mới có sẵn 2 ví** → Basic tạo thêm được 1 (khối đầu tệp, điểm 1).
6. **Hai máy Basic cùng offline** mỗi máy tạo ví thứ 3 → sau đồng bộ có 4 ví; cả hai vẫn dùng, chỉ không tạo thêm — đúng
   luật 7.2, không phải lỗi.
7. **Return URL sang web Admin**: người dùng tự quay lại app; màn Đang chờ bắt được nhờ `resumed` + socket.

---

## 16. Thứ tự thi công gợi ý (cho `writing-plans`)

1. Mô hình thuần (5.1–5.5) · 2. `GoiStore` + `PaymentApi` + `GoiRepository` + `DemDangHoatDong` (6.1–6.3, 6.7) ·
3. `RealtimeEvent` + `UserModel.loaiTaiKhoan` (6.5, 6.6) · 4. `GoiCubit` + nối `main.dart` / DI (6.4) ·
5. `redirect` ba route (7) · 6. Khoá Trợ lý AI + Nhập nhanh (8) · 7. Stitch ba màn + bốn khối (10) ·
8. `url_launcher` (duyệt) + `mo_lien_ket` + test quét 18 · 9. Màn Nâng cấp (9.1–9.2) · 10. Màn Đang chờ (9.3) ·
11. Lịch sử (9.4) · 12. Thẻ Cá nhân + dòng nhắc (9.5, 10) · 13. Dựng `--release`, nghiệm thu (13) · 14. Đơn CAN-LAM +
tài liệu (14).
