# G94 — Đơn thanh toán Premium: dọn kiến trúc mảng + chuyển thừa / thiếu — phía client — thiết kế

**Ngày:** 2026-10-18. **Trạng thái:** thiết kế người dùng duyệt trong chat (ba phần, cùng các câu hỏi về lối xác nhận,
cấu trúc màn, thẻ Nâng cấp, ảnh QR, màn Chờ, trang PayOS, phạm vi dọn kiến trúc); bản viết **người dùng duyệt cùng
ngày** — câu hỏi mở mục 12 giữ mặc định (đơn `PENDING` chỉ một dòng trạng thái). Màn Stitch: mục 9.

> ✅ **Lát 1 XONG 2026-10-18 tối** — năm commit mã `a99dd4b2` → `a0f3e3c2` (kế hoạch
> `plans/2026-10-18-g94-lat-1-don-kien-truc-premium.md`, gitignore), mỗi commit `flutter test` toàn phần xanh; cuối lát
> 7.406 / 10 skip, analyze 20. Thi công đúng mục 4, một chỗ chi tiết hơn bản viết: thêm `loaiLoiCua(Object)` ở
> `domain/cau_loi_thanh_toan.dart` để ba trang lấy loại lỗi từ `LoiThanhToan` mà không lặp phép `is`. Lát 2: kế hoạch
> viết sau khi người dùng xác nhận năm màn Stitch.
>
> 🚧 **Lát 2 đang làm (dừng 2026-10-18 tối theo lời người dùng, viết bàn giao):** kế hoạch
> `plans/2026-10-18-g94-lat-2-tinh-nang-don-thanh-toan.md` (gitignore, 10 task). **Xong Task 1–5:** `073920e6` dòng lịch
> sử đủ số liệu + `don_can_xu_ly` + nhãn *Chờ hoàn tiền* · `ed190dde` `timDon` · `af7351fe` `RealtimeEvent.donThanhToanDoi` ·
> `072d7d9b` cổng `LuuAnhQr` + kênh Kotlin `flowmoney/luu_anh` (bản `--release` dựng đạt) · `026e221a` `ChiTietDonCubit` +
> `NhanTrangThaiDon`. `flutter test` 7.424 / 10 skip, analyze 20. **Còn Task 6–10:** trang Chi tiết đơn + route, màn Chờ
> + model `DonThanhToan`, Lịch sử mua, Nâng cấp, tài liệu + release.
Mở lượt **G89 + G94** — đợt đầu của lượt (sửa hai lỗi đang chạy, `a52f9181`) đã xong trước bản này. G89 (bảo trì /
phong toả AIOps) là phân hệ độc lập, **spec riêng**, làm sau.

> **Chỗ thêm lúc viết, chưa nói trong chat — đọc kỹ khi duyệt:**
> 1. **Lưu ảnh QR qua một kênh Kotlin mới `flowmoney/luu_anh`, không thêm gói `gal`** như tôi nói trong chat. App đã có
>    kênh `flowmoney/luu_tep` (`analytics/data/luu_tep_platform.dart` ↔ `MainActivity.kt` `luuVaoTaiVe`) lưu tệp qua
>    MediaStore, không xin quyền trên Android 10+. Lưu ảnh chỉ cần một hàm anh em ghi vào `MediaStore.Images`. Lợi: không
>    thêm gói bên thứ ba, không rủi ro R8 từ plugin lạ, không quyền ghi bộ nhớ. Giá: Android 9 trở xuống không lưu được →
>    viên *"Hãy chụp màn hình"* (máy của người dùng và máy đo đều Android 13+). Mục 5.3.
> 2. **Đơn đang chờ thanh toán (`PENDING`) mở từ Lịch sử chỉ thấy một dòng trạng thái** — chưa có lối *"Tiếp tục thanh
>    toán"*. Phần 1 duyệt không có lối ấy. Câu hỏi còn mở ở mục 12, kèm giá.
> 3. **Lát 1 hứa không đổi hành vi**, nên giữ nguyên cả câu lỗi sai đang có: Lịch sử mua nạp hỏng vì 4xx vẫn hiện
>    *"Không tạo được đơn thanh toán"*. Lát 2 sửa câu ấy.
> 4. **Nút *Lưu mã QR* hiện khi có `qrUrl`**, không chờ ảnh tải xong; chỉ ẩn khi ảnh báo hỏng. Ảnh dựng qua một khe tiêm
>    (`nguonAnhQr`, mặc định `NetworkImage`), vì `flutter test` trả 400 cho mọi `Image.network` — không có khe ấy thì không
>    viết được ca *"ảnh hiện + nút Lưu"*.
> 5. **Lý do hoàn tiền có ba nhánh**, không hai: đã chuyển < giá gói → *thiếu*; > giá gói → *đã từ chối*; bằng hoặc thiếu số
>    → câu chung. Mục 5.1.

---

## 1. Vì sao, và điều đo được

### 1.1 Server hôm nay — đọc mã `src/Backend` ở `e7570e16`, chỉ đọc

| API / sự kiện | Trả / phát gì | Nguồn |
|---|---|---|
| `POST /payment/create-order` | `orderCode`, `amount`, `recognitionCode`, `transferContent` (= `description`), `checkoutUrl`, `qrUrl` (ảnh `img.vietqr.io` **server dựng**, nhúng `amount` + `addInfo`), `qrCode` (chuỗi VietQR của PayOS), `bin` · `accountNumber` · `accountName` (của PayOS, có thể `null`), `expiredAt` | `payment.service.js:20–90` |
| `GET /payment/order-status/:code` | `status`, `amount`, `amountReceived`, `recognitionCode`, `transferContent`, `paidAt`, `expiredAt`, `qrUrl`, `checkoutUrl` — **không** có số đã hoàn, ngày hoàn, ngày tạo, `fee`. Đơn `PENDING` quá hạn được trả `EXPIRED` ngay lúc đọc | `payment.service.js:734–760`, `:713`; `payment.repository.js:30`, `:106` |
| `GET /payment/history` | Nguyên hàng `payment_order` (đã chuẩn hoá số): `order_code`, `amount`, `amount_received`, `fee`, `status`, `created_at`, `paid_at`, `refunded_at`, `refunded_amount`, `refund_reason`; `checkout_url` / `qr_url` là `null` khi đơn không còn `PENDING` | `payment.repository.js:192–214`, `:10–39` |
| `POST /payment/confirm-upgrade` | **400** khi đơn không ở `WAITING_CONFIRMATION` (hoặc thiếu trường); **404** khi không thấy / không phải chủ | `payment.controller.js:200–217`, `payment.service.js:377–395` |
| Socket tới phòng `account_<id>` | `payment.overpaid_confirmation` (`:223`), `payment.underpaid_warning` (`:266`), `payment.refunded` (`:502`), `payment.success` · `payment.order_expired` · `payment.order_cancelled` (nhánh đối soát tức thời, `:600–660`), `account.upgraded` | `payment.service.js` |

- `fee` luôn là **0**: tạo đơn ghi `fee: 0` (`payment.service.js:42`), không chỗ nào đặt khác. Số tiền hoàn do admin nhập
  lúc hoàn (`processOrderRefund`, `:489`). → Client **không hứa trước** số tiền hoàn.
- ⚠️ **Rủi ro phía server, client không sửa được:** khi PayOS không trả `bin` / `accountNumber` / `accountName`, server
  dựng `qrUrl` từ giá trị **ghi cứng** (`payment.service.js:29–31`). Mã QR dựng từ giá trị ấy có thể không được PayOS nhận
  ra → không có webhook. Đây là một phép kiểm lúc nghiệm thu (mục 10), không phải việc của client.

### 1.2 Client hôm nay — HEAD `e8be4b1b`

- Màn Nâng cấp → *Thanh toán* → `create-order` → màn Chờ, và ở khung hình đầu **tự mở trang PayOS** trong trình duyệt.
  Màn Chờ có ảnh QR (cao 160 px), ô *"Mã nhận diện"* chép 6 ký tự, đếm ngược, hỏi `order-status` mỗi 3 s khi đang hiện.
  `a52f9181` đã sửa hai lỗi (đồng hồ trên máy thôi tự kết luận hết hạn; lỗi xác nhận có câu báo).
- Phần backend viết thẳng vào client (`c545ffb7`): ba thân chuyển thừa / chờ hoàn tiền / đã hoàn tiền **trong** màn Chờ,
  bốn màu ghi cứng, bộ tự dựng URL QR với tên chủ tài khoản ghi cứng ở `domain/`.
- Lịch sử mua chỉ đọc. **Rời màn Chờ là mất lối tới đơn** — kể cả đơn đang chờ người dùng xác nhận chuyển thừa.
- Khi `PaymentApi` có thêm một hàm, **18 tệp test** phải thêm hàm giả (đo 2026-10-18, gộp `e7570e16`).
- `git blame` 27 tệp `lib/features/premium/` (2.662 dòng): client 2.351, backend 311 (2026-10-18).

### 1.3 Mảng Premium lệch kiến trúc ở chín chỗ

Soát 2026-10-18 theo `docs/KIEN_TRUC_CLIENT_APP.md` mục 4 (tầng + chiều import), mục 5 (luồng), mục 8 (vị trí tệp), đối
chiếu tiền lệ các mảng khác.

| # | Tệp | Lệch | Luật |
|---|---|---|---|
| 1 | `domain/cau_loi_thanh_toan.dart` | `domain/` import `package:dio` | Mục 4: `domain/` chỉ Dart thuần |
| 2–5 | `domain/don_thanh_toan.dart`, `dong_lich_su.dart`, `trang_thai_goi.dart`, `tran_goi.dart` | Model + bộ đọc JSON nằm ở `domain/` | Mục 8: Entity, model → `data/models/` |
| 6 | `data/payment_api.dart` | Bọc API từ xa ở `data/` gốc | Mục 8: datasource bọc API → `data/datasources/` (tiền lệ `ai_chat`, `auth`) |
| 7 | `data/bo_hoi_trang_thai_don.dart` | Bộ hỏi bật / tắt theo *màn đang hiện* nằm ở `data/` | Việc của giao diện (tiền lệ `TheoDoiXem` ở `analytics/presentation/widgets/`) |
| 8 | `data/chan_theo_goi.dart` | `data/` import `flutter/widgets` + `go_router` | Mục 4: `data/` không widget |
| 9 | `nang_cap_page`, `lich_su_mua_page`, `cho_thanh_toan_page` | Gọi thẳng `sl<PaymentApi>()` (datasource) | Mục 5: trang → Cubit / repository; chữ ký 1: một phép đọc một chỗ |

Cộng một dòng nhỏ: `data/repositories/goi_repository.dart` import `flutter/widgets` chỉ để lấy `AppLifecycleState`.

**Không lệch** (tiền lệ toàn app — store / nguồn / cổng nền tảng ở `data/` gốc: `category/data/*_store.dart`,
`budget/data/tai_phan_bo_nguon.dart`, `analytics/data/luu_tep_platform.dart`): `goi_store.dart`,
`dem_dang_hoat_dong.dart`, `mo_lien_ket.dart`, `co_quyen_nen.dart`.

## 2. Quyết định người dùng (2026-10-18)

1. **Lối xác nhận khi đã rời màn Chờ:** dòng ở Lịch sử mua + thẻ đầu màn Nâng cấp. Không viên thông báo khi socket tới,
   không thẻ ở tab Cá nhân.
2. **Một màn Chi tiết đơn** cho mọi trạng thái — không bảng trượt, không nút đặt thẳng trên dòng.
3. **Thẻ ở màn Nâng cấp:** đơn chờ xác nhận → thẻ nổi bật + **khoá** *Thanh toán* (tránh trả lần hai); đơn chờ hoàn tiền →
   thẻ nhỏ, **không** khoá (người chuyển thiếu vẫn mua lại được); đã hoàn tiền → không thẻ.
4. **Đảo câu 7 của spec Premium 2026-10-06** (*"không vẽ QR"*): màn Chờ **giữ ảnh QR** và thêm nút **Lưu mã QR**, để người
   dùng lưu hoặc chụp màn hình rồi *Quét từ ảnh* trong app ngân hàng — số tiền điền sẵn, không tự nhập.
5. **Đảo mục 9.3 của spec ấy** (*mở `checkoutUrl` ngay khi vào màn*): **không tự mở** trang PayOS; giữ một nút phụ *"Mở
   trang thanh toán PayOS"*.
6. **Màn Chờ đủ thông tin:** QR to, *Lưu mã QR*, số tài khoản [Chép], chủ tài khoản, số tiền, **nội dung đầy đủ** [Chép],
   ba bước hướng dẫn; quay lại màn thì tự kiểm tra (đã có).
7. **Từ chối:** nút *Yêu cầu hoàn tiền* hỏi lại một lần (chọn rồi không đổi được). **Mọi dòng** Lịch sử bấm được.
8. **Socket:** một tín hiệu im lặng cho sáu tên `payment.*`; giữ cam kết hộp đen (không đọc payload).
9. **Phạm vi kiến trúc:** dọn **cả mảng Premium** làm lát 1, không đổi hành vi, rồi mới làm tính năng (lát 2). Mảng khác:
   chạm tới đâu sửa tới đó. Sau lượt: soát kiến trúc toàn client-app (mục 13).
10. **Luật thường trực:** từ nay mọi phần — mới hay cũ — phải khớp kiến trúc client-app (bộ nhớ
    `soat-luat-kien-truc-truoc-khi-trinh-thiet-ke`).

## 3. Phạm vi

**Làm:** lát 1 (mục 4) → lát 2 (mục 5).

**Không làm (cố ý, ghi để khỏi tìm lại):**
- viên thông báo khi socket `payment.*` tới; thẻ ở tab Cá nhân; bảng trượt;
- hiện minh chứng hoàn tiền (`refund_proof` — đường ảnh của Admin-web);
- đọc payload socket;
- đặt hạn chờ cho `WAITING_CONFIRMATION` — giữ mặc định ở đơn 44 (không hạn; lối xác nhận ở Lịch sử mua);
- sửa backend (mọi việc phía server đi đơn `CAN-LAM/`);
- G89 (spec riêng);
- dời hay tách tệp ở `core/` (vào đợt soát toàn app, mục 13).

## 4. Lát 1 — dọn kiến trúc mảng Premium, không đổi hành vi

### 4.1 Dời và tách

| Hiện tại | Sau |
|---|---|
| `data/payment_api.dart` | `data/datasources/payment_api.dart` — thêm `loaiLoiThanhToanTu(Object e)`: đọc `DioException` → `LoaiLoiThanhToan` |
| `domain/cau_loi_thanh_toan.dart` (import `dio`) | Chỉ còn `enum LoaiLoiThanhToan { phienHetHan, mayChu, matMang, biTuChoi, khac }`, `class LoiThanhToan` (mang `loai`) và `cauLoiThanhToan(LoaiLoiThanhToan, {cauTuChoi})` — câu chữ **không đổi một chữ** |
| `domain/don_thanh_toan.dart` | `DonThanhToan` + `donTuJson` → `data/models/don_thanh_toan.dart`; `enum TrangThaiDon` + `trangThaiDonTuChuoi` → `domain/trang_thai_don.dart` |
| `domain/dong_lich_su.dart` | `DongLichSu` + `dongLichSuTu` → `data/models/dong_lich_su.dart`; `chuTrangThaiDon` → `domain/trang_thai_don.dart` |
| `domain/trang_thai_goi.dart` | `TrangThaiGoi` + bộ đọc JSON / kho → `data/models/trang_thai_goi.dart`; hằng + enum (`kGiaPremium`, `kSoNgayGoi`, `LoaiGoi`) → `domain/hang_goi.dart` |
| `domain/tran_goi.dart` | `TranGoi` + JSON → `data/models/tran_goi.dart`; `LoaiTran` → `domain/hang_goi.dart`; luật + câu chữ (`KetQuaTran`, `conTaoDuoc`, `maTran`, `loaiTranTuMa`, `tenTran`, `tomTatTran`) ở lại `domain/tran_goi.dart` |
| `data/bo_hoi_trang_thai_don.dart` | `presentation/state/bo_hoi_trang_thai_don.dart` (màn Chờ không còn luồng ghi sau lát 2 — không cần Cubit) |
| `data/chan_theo_goi.dart` | `presentation/bloc/chan_theo_goi.dart` (router là điểm ghép, import `presentation/` được; `core/router/` không nhận thêm tệp vì quét 25 định nghĩa điểm ghép bằng danh sách tệp) |
| `goi_repository.dart`: `import 'package:flutter/widgets.dart' show AppLifecycleState` | `import 'dart:ui' show AppLifecycleState` |

**Vòng import cần gỡ:** hôm nay `trang_thai_goi.dart` ↔ `tran_goi.dart` import lẫn nhau. Sau tách, chiều là một hướng:
`domain/hang_goi.dart` (không import gì) ← `data/models/tran_goi.dart` ← `data/models/trang_thai_goi.dart` ←
`domain/tran_goi.dart`, `quyen_tinh_nang.dart`, `nhac_het_han.dart`, `chuyen_huong_theo_goi.dart` (`domain/` import
`data/models/` hợp lệ — quét 28). Kế hoạch đo lại ký hiệu nào tệp nào dùng trước khi tách.

### 4.2 `DonThanhToanRepository` (interface + `_impl`, `data/repositories/`)

Lát 1 chỉ bọc bốn thao tác có sẵn — đúng hành vi hôm nay:

| Hàm | Trả | Lỗi |
|---|---|---|
| `taoDon()` | `DonThanhToan` | `LoiThanhToan` (đơn thiếu `orderCode` / `checkoutUrl` → `khac`, như `StateError` hôm nay) |
| `trangThaiDon(int orderCode)` | `TrangThaiDon` | `LoiThanhToan` |
| `lichSu()` | `List<DongLichSu>` (trang 1, 20 dòng) | `LoiThanhToan` |
| `xacNhan({orderCode, accept})` | — | `LoiThanhToan` |

- Bản thi hành bắt `DioException` → `LoiThanhToan(loaiLoiThanhToanTu(e))`. Trang bắt `LoiThanhToan` → `cauLoiThanhToan(e.loai)`.
  Giao diện không còn nhìn thấy Dio.
- `GoiRepository` vẫn dùng `PaymentApi.thongTinGoi` trực tiếp (repository → datasource, đúng chiều).
- Ba trang (Nâng cấp, Lịch sử mua, màn Chờ) nhận `DonThanhToanRepository?` thay `PaymentApi?` (`null` → `sl<…>()`). Bản giả trong test chỉ cài
  bốn hàm này; các test chỉ cần `GoiRepository` vẫn dùng bản giả `PaymentApi` như hôm nay.

### 4.3 Thứ tự và nghiệm thu lát 1

Nhiều commit, **mỗi commit `flutter test` toàn phần xanh**:
1. model → `data/models/` + gỡ vòng `trang_thai_goi` ↔ `tran_goi`;
2. `payment_api` → `datasources/` + tách `cau_loi_thanh_toan`;
3. `DonThanhToanRepository` + ba trang đi qua nó;
4. `bo_hoi_trang_thai_don` → `presentation/state/`, `chan_theo_goi` → `presentation/bloc/`, `dart:ui` ở `goi_repository`.

Test dời theo cây (soi gương thư mục — quét 25). Nghiệm thu: mọi ca cũ xanh nguyên (chỉ đổi import / vị trí tệp), thêm
ca cho `DonThanhToanRepositoryImpl` (dịch lỗi), `flutter analyze` 20, quét 22–29 xanh. Không cần máy — giao diện không
đổi.

## 5. Lát 2 — tính năng G94

### 5.1 Model và domain

- `data/models/don_thanh_toan.dart`: thêm `soTaiKhoan` (`accountNumber`), `chuTaiKhoan` (`accountName`), `noiDung`
  (`transferContent ?? description`). Bỏ `amountReceived`, `fee` (không ai đọc sau lát 2). **Bỏ bộ tự dựng URL QR** với
  tên ghi cứng — server luôn gửi `qrUrl` (`payment.service.js:32`, `:81`); thiếu thì `qrUrl == null`.
- `data/models/dong_lich_su.dart`: thêm `soDaChuyen` (`amount_received`), `soDaHoan` (`refunded_amount`), `hoanLuc`
  (`refunded_at`), `taoLuc` (`created_at`), `traLuc` (`paid_at`); giữ `luc` (= `traLuc ?? taoLuc`) cho dòng Lịch sử.
- `domain/trang_thai_don.dart`: nhãn `refundPending` *"Cần hoàn tiền"* → **"Chờ hoàn tiền"**.
- `domain/don_can_xu_ly.dart` (mới, hàm thuần):
  - `donChoXacNhan(List<DongLichSu>)` → các đơn `waitingConfirmation`, mới nhất trước;
  - `donChoHoanTien(List<DongLichSu>)` → các đơn `refundPending`;
  - `lyDoHoanTien(DongLichSu)` → `chuyenThieu` khi `soDaChuyen < soTien`, `daTuChoi` khi `soDaChuyen > soTien`,
    `khongRo` khi bằng hoặc thiếu số;
  - `soTienLech(DongLichSu)` → `soDaChuyen − soTien`, `null` khi thiếu số.

### 5.2 Repository — thêm

- `timDon(int orderCode)` → `DongLichSu?`: đọc `lichSu()` (trang 1) rồi tìm theo mã. Mọi lối vào đều chạm đơn trong trang
  1: Lịch sử chỉ hiện trang 1; thẻ Nâng cấp tính trên trang 1; màn Chờ chuyển sang đơn mới nhất.
- `xacNhan` giữ chữ ký; `LoaiLoiThanhToan.biTuChoi` (4xx khác 401) là tín hiệu *đơn đã đổi trạng thái*.

### 5.3 Cổng lưu ảnh QR — `data/luu_anh_qr.dart` (mới)

- Cổng nền tảng cùng khuôn `mo_lien_ket.dart` / `luu_tep_platform.dart`: một lớp Dart, tiêm vào màn Chờ, bản giả trong test.
- Bản thật: tải byte ảnh từ `qrUrl` bằng một **`Dio()` trần** — không dùng `sl<DioClient>().dio`, vì `AuthInterceptor` gắn
  token cho mọi host — rồi gọi kênh **`flowmoney/luu_anh`**, hàm `luuAnh {ten, bytes}`.
- Phía Kotlin (`MainActivity.kt`, cạnh `luuVaoTaiVe`): ghi `MediaStore.Images` với `RELATIVE_PATH = Pictures/FlowMoney`,
  `IS_PENDING` → trả `true`. Android < 10 trả `false` (không lưu được — không phải lỗi).
- Trả về ba kết quả: **đã lưu** · **không hỗ trợ** (Android < 10; web / máy khác không có kênh — `MissingPluginException`) ·
  **hỏng** (tải ảnh hỏng, ghi hỏng). Hai kết quả sau đều hiện viên *"Không lưu được mã QR. Hãy chụp màn hình."*.
- Test nối dây đọc `MainActivity.kt` để so tên kênh / tên hàm (khuôn các `*_noi_day_test`).
- **Phương án đã loại:** gói `gal` (plugin native bên thứ ba: rủi ro R8, quyền ghi ở API ≤ 28, thêm phụ thuộc);
  `share_plus` (Android không có lựa chọn *"Lưu vào thư viện"* ổn định trong bảng chia sẻ); tự vẽ QR từ `qrCode` (người dùng
  chọn giữ ảnh như đang chạy).

### 5.4 Màn Chờ thanh toán

- **Không gọi `_mo()` ở khung đầu.** Nút phụ *"Mở trang thanh toán PayOS"* giữ hành vi mở-hỏng-thì-hiện-link-chép.
- Bố cục (màn Stitch mục 9): đếm ngược + mã đơn · số tiền · **ảnh QR to** · *Lưu mã QR* · khối thông tin (số tài khoản
  [Chép], chủ tài khoản, số tiền, nội dung đầy đủ [Chép]) · trạng thái chờ · ba bước hướng dẫn · *Tôi đã chuyển khoản* ·
  nút phụ PayOS · *Huỷ*.
- Ảnh dựng qua khe tiêm `nguonAnhQr` (`ImageProvider Function(Uri)`, mặc định `NetworkImage`). Ảnh báo hỏng → câu ngắn
  *"Không tải được mã QR — dùng thông tin bên dưới hoặc mở trang PayOS"*, nút Lưu ẩn.
- Dòng nào thiếu dữ liệu (vd. `soTaiKhoan == null`) thì không dựng dòng ấy.
- Giữ nguyên: bộ hỏi 3 s theo ba vế *đang hiện*, hỏi ngay khi `resumed` / *Tôi đã chuyển khoản* / tín hiệu socket, đồng hồ
  chỉ để hiện (`a52f9181`), thân *Thành công* (*Xong* lùi hai lớp), thân *Hết hạn* / *Đã huỷ*.
- Server trả `waitingConfirmation` / `refundPending` / `refunded` → dừng hỏi →
  `context.pushReplacement('/premium/don/$orderCode')`. Back từ Chi tiết đơn về màn Nâng cấp.
- Bỏ ba thân backend viết và hàm xác nhận trong màn Chờ (chuyển sang Chi tiết đơn). Màu theo `AppColors`.
- Khôi phục docstring đầu lớp: mã màn Stitch, lý lẽ ba vế *đang hiện*, chú thích `Flexible` (hàng cạnh vòng xoay tràn
  155 px ở 360 dp khi để trần), chú thích nút *Xong* lùi hai lớp. Sửa chữ *"10-30 phút"* còn sót.
- Widget của màn đặt ở `presentation/widgets/cho_thanh_toan/` (khối QR, khối thông tin) để trang không phình.

### 5.5 Màn Chi tiết đơn — `/premium/don/:orderCode` (mới)

- Route ngoài shell, như mọi route Premium (push được từ mọi nơi). `orderCode` không phải số → redirect `/premium/lich-su`.
- `ChiTietDonCubit` (`presentation/bloc/`, không import UI Flutter): nhận `DonThanhToanRepository`, `GoiRepository`.
  - Trạng thái: `dangNap` · `loi(cau)` · `khongThay` · `co(DongLichSu, dangGui: bool)`; một sự kiện một-lần `canBao(cau)`
    cho trang gọi `baoNhanh`.
  - `nap()`: `timDon` → `co` / `khongThay`; `LoiThanhToan` → `loi(cauLoiThanhToan(...))`. Đang nạp thì lệnh nạp mới bỏ qua.
  - `dongY()` / `tuChoi()`: `dangGui = true` → `xacNhan(accept)`. Thành công: đồng ý → `GoiRepository.lamMoi()` rồi `nap()`;
    từ chối → `nap()`. Lỗi `biTuChoi` → `canBao` + `nap()` (màn tự sang trạng thái thật). Lỗi khác → `canBao`, `dangGui =
    false`. Cubit đã đóng thì bỏ kết quả về muộn.
- Đầu màn luôn có: mã đơn, ngày tạo, giá gói, nhãn trạng thái (`nhan_trang_thai_don.dart`).

| Trạng thái | Thân |
|---|---|
| `waitingConfirmation` | *"Bạn đã chuyển X, nhiều hơn giá gói Y (thừa Z)."* — **Đồng ý kích hoạt gói** / **Yêu cầu hoàn tiền** (hỏi lại: *"Bạn sẽ không dùng khoản này để kích hoạt gói; quản trị viên sẽ hoàn lại. Không đổi lại được."*) |
| `refundPending` | `chuyenThieu`: *"Bạn đã chuyển X, thiếu Z so với giá gói."* · `daTuChoi`: *"Bạn đã chọn hoàn tiền."* · `khongRo`: câu chung. Rồi *"Quản trị viên sẽ hoàn lại khoản đã chuyển."* — không nêu số tiền hoàn |
| `refunded` | *"Đã hoàn X ngày dd/MM/yyyy."* (thiếu số / ngày thì bỏ vế ấy) |
| `paid` | Ngày trả, số tiền; vừa *Đồng ý* xong thì thân *"Đã kích hoạt Premium"* + hạn mới (từ `GoiCubit`) + *Xong* → `pop` |
| `expired` · `cancelled` · `pending` | Một dòng trạng thái (xem câu hỏi mở mục 12 cho `pending`) |

Mọi số tiền qua `CurrencyFormatter`; dấu qua `formatCoDau` nếu cần (quét 1, 11, 14).

### 5.6 Lịch sử mua

- Mọi dòng bấm được (mũi tên ›) → `push('/premium/don/$orderCode')`; quay về thì nạp lại.
- Nhãn + màu qua widget dùng chung `presentation/widgets/nhan_trang_thai_don.dart` (bỏ ba màu ghi cứng).
- Lỗi nạp: câu từ `cauLoiThanhToan(loai, cauTuChoi: 'Không tải được lịch sử mua. Thử lại sau.')` — sửa câu sai của lát 1.
- Tín hiệu `donThanhToanDoi` → nạp lại.

### 5.7 Màn Nâng cấp

- Mở màn, quay về từ màn khác, và khi có tín hiệu `donThanhToanDoi` → `lichSu()` → `donChoXacNhan` / `donChoHoanTien`.
- Có đơn chờ xác nhận → thẻ nổi bật đầu màn *"Bạn đã chuyển thừa cho đơn #… — xác nhận để kích hoạt"* (N > 1: *"Bạn có N
  đơn chuyển thừa chờ xác nhận"*). Chạm: 1 đơn → Chi tiết đơn; nhiều đơn → Lịch sử mua. Nút *Thanh toán* / *Gia hạn* **khoá**,
  kèm một dòng lý do.
- Có đơn chờ hoàn tiền → thẻ nhỏ *"Đơn #… đang chờ hoàn tiền"* (N > 1: *"N đơn…"*), **không** khoá.
- Đọc lịch sử hỏng hoặc đang nạp → không thẻ, nút mở (không chặn mua vì mạng — mục 7 *Lỗi* của KIEN_TRUC).

### 5.8 `RealtimeEvent.donThanhToanDoi`

- `realtimeEventFromName`: sáu tên `payment.overpaid_confirmation` · `payment.underpaid_warning` · `payment.refunded` ·
  `payment.success` · `payment.order_expired` · `payment.order_cancelled` → `donThanhToanDoi`.
- `loiNhan` → `null` (im lặng); `canDongBoLai` → `false` (trạng thái đơn không phải dữ liệu đồng bộ). Docstring *"Bốn sự
  kiện"* → *"Năm"*.
- **`GoiRepository.noiSuKien` KHÔNG nghe nó** — gói chỉ làm mới theo `account.upgraded` như hôm nay.
- Người nghe: màn Chờ (hỏi ngay), Chi tiết đơn (`nap()`), Lịch sử mua, màn Nâng cấp. Không ai đọc payload.

### 5.9 Điểm ghép

- `app_router.dart`: route `/premium/don/:orderCode`.
- `injection_container.dart`: `DonThanhToanRepository` (lazy singleton), `LuuAnhQr`.

## 6. Ca lỗi và biên

| Chỗ | Ca | Hành vi |
|---|---|---|
| Màn Chờ | không có `qrUrl` | Không ảnh, không nút Lưu; khối thông tin vẫn hiện |
| | ảnh tải hỏng | Câu ngắn chỉ sang thông tin / trang PayOS; nút Lưu ẩn |
| | lưu không hỗ trợ / hỏng | Viên *"Không lưu được mã QR. Hãy chụp màn hình."* (loại lỗi) |
| | lưu xong | Viên *"Đã lưu mã QR vào Thư viện ảnh"* (loại xong) |
| | quá hạn, chưa hỏi được server | Đứng ở *"Còn 00:00"*, vẫn hỏi theo nhịp (`a52f9181`) |
| Chi tiết đơn | không thấy đơn | *"Không tìm thấy đơn này"* + *Thử lại* |
| | nạp hỏng | Câu lỗi + *Thử lại* |
| | đang gửi | Hai nút khoá, nút vừa bấm hiện vòng xoay |
| | mất mạng / 5xx / 401 | Viên lỗi (`cauLoiThanhToan`), nút mở lại |
| | 4xx khác 401 | Viên *"Không xác nhận được đơn này. Thử lại sau."* + nạp lại → thân theo trạng thái thật |
| | Back giữa lúc gửi | Bỏ kết quả về muộn |
| Nâng cấp | lịch sử hỏng / đang nạp | Không thẻ, nút mở |
| | nhiều đơn chờ xác nhận | Thẻ *"N đơn…"* → Lịch sử mua |
| Socket | tín hiệu dồn dập | Bộ hỏi không chồng (cờ `_dangHoi` có sẵn); Cubit bỏ lệnh nạp khi đang nạp |
| Route | `/premium/don/abc` | Về `/premium/lich-su` |

## 7. Đối chiếu kiến trúc (sau hai lát)

| Luật | Thiết kế |
|---|---|
| Mục 8 — vị trí | Model → `data/models/`; datasource API → `data/datasources/`; repository interface + `_impl` → `data/repositories/`; cổng nền tảng (`luu_anh_qr`, `mo_lien_ket`) và store / nguồn ở `data/` gốc theo tiền lệ; hàm thuần → `domain/`; Cubit + cửa chặn route → `presentation/bloc/`; bộ hỏi → `presentation/state/`; widget một trang → `widgets/cho_thanh_toan/`, `widgets/chi_tiet_don/`; widget dùng chung trong mảng → `widgets/` |
| Mục 4 — chiều import | `domain/` chỉ Dart thuần + `data/models/` (hết `dio`); `data/` không widget (hết `flutter/widgets`, `go_router`); giao diện không nhìn thấy Dio |
| Mục 5 — luồng | Trang / Cubit → `DonThanhToanRepository` → `PaymentApi` |
| Chữ ký 1 — một định nghĩa | Một phép đọc lịch sử (repository); một luật *đơn cần xử lý* (`don_can_xu_ly`); một nhãn + màu trạng thái (`nhan_trang_thai_don`); một bảng câu lỗi (`cauLoiThanhToan`) |
| Chữ ký 2 — test quét | Quét 22–29 xanh; tệp mới không cần quét mới (không gói mới) |
| Chữ ký 3 — cổng + bộ chuyển | `LuuAnhQr` (kênh `flowmoney/luu_anh`), `MoLienKet` |
| Quét 23 | Mọi tệp `presentation/` ≤ 1.200 dòng — màn Chờ tách khối ra `widgets/cho_thanh_toan/` |
| Mục 6 — hộp đen socket | Chỉ đọc tên sự kiện |

## 8. Test

Hành vi mới: ca đỏ trước, đỏ đúng lý do; mỗi ca canh thử bằng bản sai có chủ ý.

- **Lát 1:** test cũ dời theo cây, xanh nguyên. Thêm ca `DonThanhToanRepositoryImpl`: dịch đủ năm loại lỗi; `taoDon` thiếu
  trường → `khac` (chuyển ca `cau_loi_thanh_toan_test` cho phần đọc Dio sang `data/datasources/`).
- **Lát 2:**
  - model: trường mới, ca canh **không còn tên ghi cứng / không còn URL tự dựng**;
  - domain: `don_can_xu_ly` (ba nhánh lý do, lệch, lọc / thứ tự), nhãn mới;
  - repository: `timDon` thấy / không thấy;
  - Cubit: nạp, không thấy, đồng ý → `lamMoi` + nạp lại, từ chối, lỗi mạng, `biTuChoi` → nạp lại, đóng giữa chừng;
  - màn Chờ: **không tự mở PayOS** (`daMo` rỗng sau khi vào), nút phụ mở được; ảnh + nút Lưu (qua `nguonAnhQr` =
    `MemoryImage`); ảnh hỏng → câu, nút ẩn; Lưu đã lưu / không hỗ trợ / hỏng → ba viên; chép số tài khoản / nội dung;
    `waitingConfirmation` → sang Chi tiết đơn; viết lại các ca cũ dựa vào việc tự mở link;
  - Chi tiết đơn: mỗi thân, hộp hỏi lại (Huỷ không gửi), *Xong*;
  - Lịch sử: bấm dòng → Chi tiết; quay về nạp lại;
  - Nâng cấp: thẻ chờ xác nhận + khoá; thẻ hoàn tiền không khoá; lịch sử hỏng → nút mở; nhiều đơn → Lịch sử;
  - `realtime_event`: sáu tên → `donThanhToanDoi`, im lặng, không kéo đồng bộ; `GoiRepository` không làm mới vì nó;
  - route `/premium/don/abc`;
  - nối dây kênh `flowmoney/luu_anh` (Dart ↔ `MainActivity.kt`);
  - bố cục: màn Chờ, Chi tiết đơn, Nâng cấp ở 360 × 640 và 320 dp không tràn (`takeException`), số tiền 13 chữ số.
- `flutter build apk --release` sau khi thêm hàm Kotlin (bẫy R8 vốn do plugin; đây không thêm plugin, vẫn dựng thử).

## 9. Stitch

Theo thứ tự người dùng chốt (spec → Stitch → màn mới), trước khi viết kế hoạch; mỗi màn nhờ người dùng xác nhận bằng mắt
(công cụ hay trả `timeout` và trễ):
1. Màn Chờ thanh toán mới (QR to, *Lưu mã QR*, khối thông tin, ba bước, nút phụ PayOS).
2. Chi tiết đơn — năm thân (chờ xác nhận · chờ hoàn tiền do thiếu · chờ hoàn tiền do đã từ chối · đã hoàn tiền · đã kích
   hoạt) + hộp hỏi lại khi từ chối.
3. Lịch sử mua — dòng có mũi tên, nhãn mới.
4. Nâng cấp — thẻ chờ xác nhận + nút khoá, thẻ chờ hoàn tiền.

Mã màn ghi vào bảng mục 5 `PREMIUM_FEATURE.md`.

> **Lượt gọi 2026-10-18 tối** (dự án `5106367939423432838`, design system *Kinetic Finance* `assets/7a3b24ea…`, mô hình
> `GEMINI_3_8_FLASH`, khung điện thoại): mục 2 tách thành hai màn, nên **năm** lượt `generate_screen_from_text`. Cả năm
> trả `timeout`; theo tiền lệ, timeout không phải thất bại, nên không gọi lại. Ngay sau đó `list_screens` chưa thấy màn
> nào mới (132 màn). Tên năm màn, dùng để dò:
> 1. *"Thanh toán Premium - Đang chờ (mã QR + Lưu mã) - FlowMoney"*
> 2. *"Chi tiết đơn - Chờ xác nhận chuyển thừa + Hộp hỏi lại - FlowMoney"*
> 3. *"Chi tiết đơn - Bốn trạng thái (chờ hoàn tiền / đã hoàn tiền / đã kích hoạt) - FlowMoney"*
> 4. *"Lịch sử mua Premium - Dòng bấm được (có Chờ xác nhận) - FlowMoney"*
> 5. *"Nâng cấp Premium - Có đơn cần xử lý (khoá Thanh toán) - FlowMoney"*
>
> Mã màn và xác nhận bằng mắt của người dùng: điền khi có.
>
> **Cập nhật 2026-10-18 tối** (người dùng báo *"đã có màn trên stitch"*): `list_screens` thấy **4 / 5** màn (136 màn) —
> nội dung đối chiếu HTML khớp spec từng dòng chữ:
> | Màn | Mã | Ghi chú |
> |---|---|---|
> | 1. Màn Chờ (QR + Lưu mã) | `95b2774f085747fa8777aea3505bb6ee` | đủ khối; Stitch xếp khung DESKTOP 2560 px (một khung điện thoại bên trong) |
> | 3. Chi tiết đơn — bốn trạng thái | `d3b59018c7624f1a902eba125243130f` | đủ bốn thân |
> | 4. Lịch sử mua — dòng bấm được | `04c4aa7dda504cc4922290ea79ef3e63` | thêm dòng chân *"Giao dịch thanh toán bảo mật FlowMoney"* — trang trí, không chép |
> | 5. Nâng cấp — có đơn cần xử lý | `5c629d0af67e4c6fbda1c85de896fa8d` | đủ hai thẻ + nút khoá |
>
> Màn 2 (*Chi tiết đơn - Chờ xác nhận chuyển thừa + Hộp hỏi lại*) chưa thấy trong API — người dùng không thấy trên
> canvas, chọn tạo lại (một lượt, cũng `timeout`); sau đó hiện: **`408de0af0d8a4fb796d3997580120d7a`**, nội dung khớp mục
> 5.5 từng dòng chữ (thẻ đầu · *BẠN ĐÃ CHUYỂN THỪA* 60.000 / 49.000 / thừa 11.000 · hai nút · dòng phụ · hộp *Yêu cầu
> hoàn tiền?* với Huỷ / Yêu cầu hoàn tiền). Người dùng **đã xác nhận bằng mắt bốn màn 1, 3, 4, 5**; màn 2 **chưa**.

## 10. Nghiệm thu máy thật (OnePlus 13R)

**Điều kiện** (người dùng): khoá PayOS sandbox dán vào `src/Backend/.env`; cho phép **đích danh** chạy `npm install` ở
`src/Backend` (gói `resend`; tự `prisma generate` — CSDL dev đã khớp schema, đo 2026-10-18). Thiếu điều kiện thì lát 2 dừng
ở *test xanh + Stitch xác nhận + máy ảo với repository giả*, ghi 🚧 như Premium ngày 2026-10-06.

**Đo:**
1. Ảnh QR hiện; *Lưu mã QR* → ảnh có trong Thư viện (`Pictures/FlowMoney`).
2. MB Bank → *Quét từ ảnh* → chọn ảnh vừa lưu → **số tiền và nội dung điền sẵn đúng** (không cần chuyển thật).
3. Kiểm rủi ro mục 1.1: đơn sandbox có `bin` / `accountNumber` của PayOS hay rơi về giá trị ghi cứng.
4. Chuyển xong quay lại → màn tự kiểm tra → *Thành công*.
5. Chuyển thừa / thiếu (sandbox; hoặc đường mô phỏng của Admin-web nếu có — spec thanh toán mục 5.2 nhắc tới, client
   chưa kiểm) → Chi tiết đơn đúng thân; *Đồng ý* / *Từ chối*.
6. Thẻ ở Nâng cấp, dòng ở Lịch sử mua; khoá *Thanh toán* khi còn đơn chờ xác nhận.
7. Bản `--release` lưu ảnh được.
8. Màn 360 dp (Realme) không tràn.

## 11. Tài liệu phải sửa theo hai lát

- `docs/KIEN_TRUC_CLIENT_APP.md` mục 3 — số tệp mảng Premium (data · domain · presentation, đếm lại bằng máy); mục 6 chữ ký
  3 — thêm kênh `flowmoney/luu_anh` (bảy kênh).
- `docs/PREMIUM_FEATURE.md` — đoạn G94, bảng Stitch (mục 5), bẫy 8 (màn Chờ), cây tệp mục 3, luồng thanh toán.
- `docs/CLIENT_APP_KNOWN_GAPS.md` — thân G94 (việc 2, 4–10), bảng tóm tắt; đóng G94 khi nghiệm thu đạt.
- `CLAUDE.md` — hàng Premium (hôm nay còn ghi *mở `checkoutUrl`*, *hỏi 3 s*, các tệp ở chỗ cũ).
- Spec `2026-10-06-premium-payos-client-design.md` — khối 🔧 ở câu 7 (QR) và mục 9.3 (không tự mở trang PayOS), trỏ sang
  bản này; không sửa thân.
- `docs/superpowers/backend/CAN-LAM/SOAT_SAU_GOP_D72CCD45.md` — ghi chú: client đã có lối xác nhận ở Lịch sử mua (mặc định
  của câu hỏi *không hạn chờ* nay thành hiện thực).
- `docs/PROJECT_CONTEXT.md` mục 14 — khối của lượt.

## 12. Câu hỏi còn mở

**Đơn `PENDING` mở từ Lịch sử mua — có lối *"Tiếp tục thanh toán"* không?** Phần 1 duyệt không có lối này, nên mặc định của
bản này là *chỉ một dòng trạng thái*. Nếu thêm: dòng lịch sử của đơn `PENDING` còn `checkout_url`, `qr_url`,
`recognition_code`, `expired_at` (server xoá hai URL khi đơn rời `PENDING`), nên Chi tiết đơn dựng được một `DonThanhToan`
rồi `push` màn Chờ — khoảng một hàm đọc ở model, một nút, hai ca test. Lịch sử hiện không trả `bin` / `accountNumber` /
`accountName`, nên khối thông tin chuyển khoản của màn Chờ sẽ thiếu số tài khoản và tên — chỉ còn ảnh QR, số tiền, nội dung.

## 13. Sau lượt này

1. **Soát kiến trúc toàn client-app** (người dùng chốt 2026-10-18): quét máy chỉ đọc theo các mẫu lệch đã gặp ở Premium
   (`data/` import widget / `go_router`; `domain/` import `dio` · `drift` · `flutter` · `get_it` · `go_router` ·
   `flutter_bloc`; model + bộ đọc JSON ở `domain/`; bọc API / DAO ngoài `data/datasources/`; trang import datasource; logic
   giao diện ở `data/`) + đọc từng mảng theo mục 4 · 5 · 6 · 8 + quét 22–29; báo cáo theo mảng (chỗ lệch · luật · cách sửa ·
   số tệp import); người dùng chọn lát sửa; mẫu nào máy canh được thì thêm test quét (từ số 30).
   - Đã biết trước: **5 trang** ở `ai_chat`, `notification`, `transaction` import thẳng `data/datasources/` (đếm
     2026-10-18); `core/ui/bao_che_day_toast.dart` là widget → `shared/widgets/`; `core/database/daos/other_daos.dart` chứa ba
     DAO → tách.
2. **`SyncEngine`** (`core/sync/sync_engine.dart`, 2.164 dòng): lượt riêng, có lưới test kỹ — người dùng quyết sau báo cáo
   soát.
3. **G89** — spec riêng.
