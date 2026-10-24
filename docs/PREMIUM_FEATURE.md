# Premium qua PayOS — phía client

**Trạng thái (2026-10-06):** mã **xong** 15/17 task của kế hoạch `docs/superpowers/plans/2026-10-06-premium-payos-client.md`
(gitignore) — còn **Task 16 nghiệm thu máy thật** (sandbox PayOS, chờ người dùng dán khoá; `database/19` ✅ đã áp tối 2026-10-06)
và phần tài liệu này. Spec: `docs/superpowers/specs/2026-10-06-premium-payos-client-design.md` (người dùng duyệt).
Đơn backend: `docs/superpowers/backend/CAN-LAM/CLIENT_PREMIUM_PAYOS.md` (38, không chặn client).

**Phân quyền tính năng theo gói (2026-10-08):** ✅ mã xong + nghiệm thu OnePlus đạt (mục 8.7) — trọn 10 task của kế hoạch `…/plans/2026-10-08-phan-quyen-tinh-nang-client.md`
(gitignore), spec `docs/superpowers/specs/2026-10-08-phan-quyen-tinh-nang-client-design.md` (người dùng duyệt) — **mục 8**
dưới đây. Từ lượt ấy bảng ở mục 1 chỉ là **mặc định khi server không trả khoá**; con số và công tắc thật do admin đặt ở
Admin-web `/permissions`.

**⚠️ Đối soát chuyển thừa / thiếu (2026-10-16, gộp `main` @ `d72ccd45`; soát lại 2026-10-18 sau gộp `e7570e16`) — G94
MÃ XONG 2026-10-18 tối, chờ nghiệm thu máy thật:** backend thêm ba trạng thái đơn `WAITING_CONFIRMATION` · `REFUND_PENDING` · `REFUNDED`,
`POST /payment/confirm-upgrade` và ba sự kiện `payment.*`, và rút hạn đơn còn **10 phút**
(`docs/Payment/PAYMENT_WORKFLOW_SPEC.md` v2.0.0).
- **Phía backend:** đơn 44 đạt A, C, D, E, F khi client soát 2026-10-18. Mục B còn hai vế (đơn đang chờ xác nhận / chờ
  hoàn tiền vẫn bị webhook xử lý lại; chưa khử trùng theo `reference`) — banner đầu `CAN-LAM/SOAT_SAU_GOP_D72CCD45.md`.
- **Phía client:** gộp `e7570e16` mang mã backend viết thẳng vào mảng này — ba trạng thái đơn, hai nút xác nhận chuyển
  thừa ở màn Chờ thanh toán, nhãn lịch sử, hạn 10 phút. ✅ **2026-10-18 tối** (đợt sửa hai lỗi mở đầu lượt G89 + G94):
  đồng hồ trên máy chỉ còn để hiện số giây — màn sang *"Đơn đã hết hạn"* duy nhất khi `order-status` trả `EXPIRED` (server
  tự trả `EXPIRED` cho đơn `PENDING` quá hạn), nên người chuyển thừa quay lại sau hạn thấy hộp xác nhận; quá hạn theo máy
  mà server chưa trả lời thì màn đứng ở *"Còn 00:00"* và vẫn hỏi. Lỗi khi bấm xác nhận nay báo bằng `baoNhanh`.
- ✅ **Lát 1 (dọn kiến trúc) + lát 2 (tính năng) — mã xong 2026-10-18 tối** — spec
  `docs/superpowers/specs/2026-10-18-g94-don-thanh-toan-premium-design.md`. Màn Chờ thanh toán **không tự mở** trang PayOS:
  ảnh VietQR to + *Lưu mã QR* (lưu vào Thư viện ảnh rồi *Quét từ ảnh* trong app ngân hàng), khối thông tin chuyển khoản
  có nút chép, ba bước, nút phụ *Mở trang thanh toán PayOS*. Server trả trạng thái đối soát → màn được **thay** bằng **Chi
  tiết đơn** `/premium/don/:orderCode` — một màn cho mọi trạng thái, nơi duy nhất gọi `confirm-upgrade` (*Yêu cầu hoàn
  tiền* hỏi lại một lần). Mọi dòng Lịch sử mua bấm được; màn Nâng cấp có thẻ đơn chờ xác nhận (**khoá** *Thanh toán*) và
  thẻ đơn chờ hoàn tiền (không khoá). Sáu sự kiện `payment.*` là một tín hiệu im lặng `donThanhToanDoi`. 🚧 **Chưa nghiệm
  thu máy thật** (cần khoá PayOS sandbox + phép `npm install` backend — mục 6).

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
   > 🔧 **Đảo 2026-10-18 (G94, người dùng chốt):** màn Chờ **không tự mở** trang PayOS và **giữ ảnh QR** + nút *Lưu mã
   > QR* — lưu (hoặc chụp màn hình) rồi *Quét từ ảnh* trong app ngân hàng, số tiền + nội dung điền sẵn; trang PayOS còn
   > là nút phụ. Spec G94 mục 2 câu 4–6.
7. **Nghiệm thu bằng Sandbox PayOS** — không tốn tiền thật, lặp được.
8. **Kiến trúc A**: mô-đun `features/premium/`, một định nghĩa `conTaoDuoc`, **một cửa chặn** ở `redirect` của ba route
   tạo (mọi lối vào form đều qua: nút +, thẻ *Chưa đặt ngân sách*, lệnh tạo C3, deeplink).

## 3. Kiến trúc & tệp (`lib/features/premium/`)

Cây sau **G94 lát 1 + lát 2** (2026-10-18, spec `specs/2026-10-18-g94-don-thanh-toan-premium-design.md` mục 4–5 —
khớp `KIEN_TRUC_CLIENT_APP.md` mục 4 · 5 · 8):

```
domain/  hang_goi.dart (kGiaPremium · kSoNgayGoi · LoaiGoi · LoaiTran — không import gì)
         tran_goi.dart (conTaoDuoc · KetQuaTran · maTran · tenTran · tomTatTran)
         chuyen_huong_theo_goi.dart (?id = sửa → qua · chuyenHuongChiTietDon: mã không phải số → /premium/lich-su)
         trang_thai_don.dart (TrangThaiDon · trangThaiDonTuChuoi, chuỗi lạ = pending · chuTrangThaiDon)
         don_can_xu_ly.dart (donChoXacNhan · donChoHoanTien · soTienLech · lyDoHoanTien thiếu / đã từ chối / không rõ)
         cau_loi_thanh_toan.dart (LoaiLoiThanhToan · LoiThanhToan · loaiLoiCua · câu theo loại, không URL — Dart thuần)
         quyen_tinh_nang.dart (duocDung) · nhac_het_han.dart (0..3 ngày)
data/    models/trang_thai_goi.dart (TrangThaiGoi · laPremium(now) · soNgayConLai · trangThaiTuJson accountType??type · kho)
         models/tran_goi.dart (TranGoi.macDinh 3/3/3)
         models/don_thanh_toan.dart (DonThanhToan · donTuJson: qrUrl của server, KHÔNG tự dựng · số TK · chủ TK · nội dung;
                                    checkoutUrl / qrUrl chỉ nhận https — 2026-10-24)
         models/dong_lich_su.dart (DongLichSu · dongLichSuTu: tạo / trả / đã chuyển / đã hoàn / ngày hoàn)
         datasources/payment_api.dart (Dio, bocData · loaiLoiThanhToanTu: DioException → loại)
         repositories/goi_repository.dart (kho thắng type · lamMoi không ném · resumed giãn 5' · socket hỏi ngay)
         repositories/don_thanh_toan_repository.dart (+ _impl: taoDon · trangThaiDon · lichSu · timDon · xacNhan; lỗi → LoiThanhToan)
         goi_store.dart (secure storage `goi_tai_khoan_<id>`) · dem_dang_hoat_dong.dart (NguonDemDangHoatDong) ·
         datasources/mo_lien_ket.dart (tệp DUY NHẤT import url_launcher — test quét 18) ·
         datasources/luu_anh_qr.dart (LuuAnhQr: chỉ kênh flowmoney/luu_anh → MediaStore.Images; bộ tải ảnh tiêm qua taiAnh) ·
         datasources/tai_anh_dio_tran.dart (Dio TRẦN tải ảnh VietQR — chỉ DI gọi) · co_quyen_nen.dart
presentation/ bloc/goi_cubit.dart (singleton, gốc cây) · bloc/phien_goi_tu_auth.dart · bloc/co_quyen.dart ·
         bloc/chan_theo_goi.dart (redirectTaoTheoGoi · chanTheoGoi · chanTheoQuyen) ·
         bloc/chi_tiet_don_cubit.dart (nap · dongY · tuChoi · canBao) ·
         state/an_nhac_het_han.dart · state/bo_hoi_trang_thai_don.dart (3 s) ·
         pages/nang_cap_page · cho_thanh_toan_page · lich_su_mua_page · chi_tiet_don_page (qua DonThanhToanRepository) ·
         widgets/nut_nang_cap · the_goi_tai_khoan · dong_nhac_het_han · nhan_trang_thai_don (nhãn + màu, một định nghĩa) ·
         widgets/cho_thanh_toan/ (khoi_ma_qr · khoi_thong_tin_chuyen_khoan) ·
         widgets/chi_tiet_don/ (the_dau_don · khoi_doi_soat · the_ket_qua_don)
```

Sửa nơi khác: `RealtimeEvent.taiKhoanNangCap` (`account.upgraded`, `canDongBoLai false`, `loiNhan null`) ·
`RealtimeEvent.taiKhoanHaCap` (`account.downgraded` — tín hiệu im như `taiKhoanNangCap`, làm mới gói; G89 2026-10-20) · hook `khiBiTatQuyen` của `MayChuInterceptor` (403 `FEATURE_DISABLED` → làm mới gói, giãn 30 s; G89) ·
`RealtimeEvent.donThanhToanDoi` (sáu tên `payment.*`, cùng khuôn tín hiệu im; `GoiRepository` **không** nghe nó) ·
`MainActivity.kt` (kênh `flowmoney/luu_anh`, phương thức `luuAnh` → `luuAnhVaoThuVien`, cạnh `luuVaoTaiVe`) ·
`UserModel.loaiTaiKhoan` (`type` của `/auth/*`) · `app_router.dart` (3 `redirect` + 4 route `/premium*`) ·
`ai_chat_page.dart` (`lyDoKhoa`, Basic xét trước) · `add_transaction_page.dart` (ô Nhập nhanh) · `profile_page.dart`
(thẻ Gói) · `home_page.dart` (dòng nhắc) · `main.dart` (nối ba nguồn, `BlocProvider<GoiCubit>`) · DI · `pubspec`
(`url_launcher ^6.3.3`). **Không đổi schema Drift, không trường đồng bộ mới.**

Luồng: `/payment/subscription-info` → `trangThaiTuJson` → `GoiStore` → `GoiRepository.theoDoi` → `GoiCubit` → màn.
Router: `redirect` → Premium? qua : `NguonDemDangHoatDong.dem` → `conTaoDuoc` → `chuyenHuongTheoGoi`.

Luồng thanh toán (G94, 2026-10-18): Nâng cấp → *Thanh toán* (khoá khi còn đơn chờ xác nhận) → `taoDon` → màn Chờ (QR +
Lưu mã + thông tin chuyển khoản; hỏi `order-status` 3 s khi đang hiện, hỏi ngay khi `resumed` / *Tôi đã chuyển khoản* /
`taiKhoanNangCap` / `donThanhToanDoi`) → `PAID`: Thành công · `EXPIRED` / `CANCELLED`: câu + *Tạo đơn mới* ·
`WAITING_CONFIRMATION` / `REFUND_PENDING` / `REFUNDED`: `pushReplacement('/premium/don/:orderCode')` → Chi tiết đơn
(`ChiTietDonCubit` → `timDon` trong lịch sử trang 1; *Đồng ý* → `confirm-upgrade` + `GoiRepository.lamMoi` → *Đã kích hoạt
Premium* + *Xong*; *Yêu cầu hoàn tiền* → hộp hỏi lại → `confirm-upgrade(accept: false)`). Lối vào Chi tiết đơn khi đã rời
màn Chờ: dòng Lịch sử mua và thẻ đầu màn Nâng cấp.

## 4. Bẫy — phá là hỏng im lặng (và những thứ đã vấp khi thi công)

1. **Basic xét TRƯỚC** ở `lyDoKhoa` — không mời người không dùng được đi tải 2,41 GB.
2. **Bằng trần là vượt** (`dangCo >= tran`); Premium → `Duoc` không nhìn số.
3. **`/subscription-info` trả `accountType`**, hướng dẫn ghi `type` — đọc cả hai.
4. **`/budget/rules?id=` là sửa**, `chuyenHuongTheoGoi` tự cho qua dù `Vuot`; `?category=` là tạo → chặn.
5. **Socket `account.upgraded` (và `account.downgraded` = `taiKhoanHaCap`) là tín hiệu** — không đọc payload (hộp đen của `events`), gọi lại API.
6. **Kho thắng `type` của phiên** — admin hạ cấp tay khi `/payment/*` hỏng thì máy giữ Premium theo cache tới lần
   `/subscription-info` trả lời được (giới hạn 15.2 spec).
7. **`context.read<GoiCubit>()`, không `BlocProvider.of`** khi muốn bắt `ProviderNotFoundException` — `BlocProvider.of`
   bọc thành `FlutterError`, 37 ca cũ đỏ cùng lúc. `laPremium == null` + không provider = **không khoá** (chỉ test cũ gặp).
8. **Không `pumpAndSettle` khi vòng xoay còn quay** (màn Đang chờ) — không lắng + làm timer poll nổ thêm; dùng `pump()`.
   Ca *Back sau `pushReplacement`* cũng vậy: bản sai (`push`) đưa Back về màn Chờ → `pumpAndSettle` **treo** thay vì đỏ;
   ca dùng `pump(400 ms)` rồi đòi màn Nâng cấp.
9. **Xoá mềm là `deletedAt`**, không phải cờ `isDeleted` (DAO lọc `deletedAt.isNull()`); ngân sách **không lặp** hết hạn ở
   **cuối kỳ đầu** (`expiresAt = min(mocKy(0), endDate)`) — hai fixture của kế hoạch sai, mã đúng.
10. **`launchUrl` không kèm `canLaunchUrl`** → không cần `<queries>` manifest; hỏng → link chép được.
11. Hàng chữ cạnh vòng xoay / khối chữ cạnh nút phải **`Flexible` / `Expanded`** — tràn 155 px và 47 px ở 360 dp khi để
    trần hay dùng `Wrap` (con của Wrap không có biên ngang).
12. **Nút Thanh toán khoá trong lúc tạo đơn** — bấm đôi là hai đơn; test bấm lần hai theo **key** vì chữ đã thành vòng xoay.
13. Hết hạn giữa phiên **không có hẹn giờ** — đổi ở lần đọc kế (`laPremium(now)` mỗi lần hỏi).
14. **`DateTime ==` đòi cùng múi giờ** — kho ghi UTC; so khoảnh khắc bằng `isAtSameMomentAs`.
15. **Màn Chờ KHÔNG tự mở trang PayOS** (G94, người dùng chốt) — ca đầu của `cho_thanh_toan_page_test` đòi `daMo` rỗng
    sau khi vào màn; đừng thêm lại `addPostFrameCallback((_) => _mo())`.
16. **Ảnh QR dựng MỘT lần ở `initState`** (`_anhQr`) — dựng trong `build` là mỗi nhịp đồng hồ một `ImageProvider` mới;
    `NetworkImage` so bằng URL nên không tải lại, nhưng nguồn tiêm không so bằng giá trị thì tải lại mỗi giây. `flutter
    test` trả 400 cho mọi ảnh mạng → khe tiêm `nguonAnhQr`; nút *Lưu mã QR* hiện khi có `qrUrl`, chỉ ẩn khi ảnh báo hỏng.
17. **Trạng thái đối soát → `pushReplacement`, không `push`** — `push` để lại màn Chờ dưới Chi tiết đơn, Back quay về một
    màn đã dừng hỏi. Cờ `_daSangChiTiet` chặn câu trả lời về muộn gọi `pushReplacement` lần hai.
18. **Chỉ Chi tiết đơn gọi `confirm-upgrade`** — một chỗ cho ba lối vào (màn Chờ, Lịch sử mua, thẻ Nâng cấp). `4xx` = đơn
    đã đổi ở nơi khác → báo + **nạp lại** (thân đi theo server); mất mạng / 5xx → báo, nút mở, **không** nạp lại.
19. **`Text` số tiền dài ngắt / cắt im lặng** — `takeException` mù; số tiền đi `FittedBox(scaleDown)` + `maxLines: 1`, ca
    320 dp đo `RenderParagraph.didExceedMaxLines` và chiều cao (khuôn bẫy *ô nhập TIỀN* của `CLAUDE.md`).
20. **Viền trái 4 px + bo góc** (thẻ chờ xác nhận ở Nâng cấp): `BoxDecoration` không nhận viền không đều cùng
    `borderRadius` (assertion) → thanh màu là ô con trong `Material` bo góc + `IntrinsicHeight`.
21. **Thẻ ở Nâng cấp: đọc hỏng thì không chặn mua** — chưa đọc được lịch sử → không thẻ, nút mở; đã đọc được thì lượt hỏng
    sau giữ kết quả cũ (không mở khoá vì mạng chập chờn).
22. ⚠️ **Đừng `await context.push('/premium/cho-thanh-toan')` để biết lúc người dùng quay về Nâng cấp** — màn Chờ THAY
    chính nó bằng Chi tiết đơn (`pushReplacement`), và future của lượt `push` ấy **không về** khi Chi tiết đơn pop (đo bằng
    test, `go_router` 14.6). Bản đầu của Task 9 làm thế: quay về là nút *Thanh toán* **quay mãi** và thẻ *chuyển thừa* đứng
    sau khi đã *Đồng ý*. Nâng cấp nghe `TickerMode` (cùng khuôn màn Chờ): màn hiện lại → mở nút + đọc lại; nghe thêm
    `taiKhoanNangCap` vì *Đồng ý* chỉ làm server phát `account.upgraded`. Ca canh: hai ca *đường chính* ở
    `nang_cap_page_test` (route Chờ giả `pushReplacement` ngay) — dùng `pump(400 ms)`, không `pumpAndSettle` (bản lỗi treo).

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

**G94 (lượt gọi 2026-10-18 tối — cả năm trả `timeout`, màn hiện sau ~1 giờ; màn 2 tạo lại một lần; ✅ người dùng xác nhận
bằng mắt cả năm — màn 2 ở phiên sau, cùng tối):**

| Màn / khối | id |
|---|---|
| Thanh toán Premium — Đang chờ (mã QR + Lưu mã) — thay `b05060e3…` | `95b2774f085747fa8777aea3505bb6ee` |
| Chi tiết đơn — Chờ xác nhận chuyển thừa + Hộp hỏi lại | `408de0af0d8a4fb796d3997580120d7a` |
| Chi tiết đơn — Bốn trạng thái (chờ hoàn tiền thiếu / đã chọn hoàn · đã hoàn · đã kích hoạt) | `d3b59018c7624f1a902eba125243130f` |
| Lịch sử mua — Dòng bấm được — thay `e7d66095…` | `04c4aa7dda504cc4922290ea79ef3e63` (dòng chân *"Giao dịch thanh toán bảo mật"* — trang trí, **không chép**) |
| Nâng cấp — Có đơn cần xử lý (khoá Thanh toán) | `5c629d0af67e4c6fbda1c85de896fa8d` (dòng *"Tự động gia hạn · Hủy bất cứ lúc nào"* — gói không tự gia hạn, **không chép**; thẻ gói hiện tại giữ như cũ) |

Lệch có chủ ý ở Chi tiết đơn: thẻ đầu theo bố cục `d3b59018…` cho **mọi** trạng thái (dòng phụ *mã đơn · giờ tạo* xuống
hàng riêng — bố cục `408de0af…` để dòng ấy cạnh viên trạng thái, ở 320 dp cột chỉ còn ~120 dp); giá gói nằm ở thân, không
ở thẻ đầu (spec mục 5.5 nói *đầu màn luôn có giá gói* — Stitch người dùng duyệt không vẽ), ba thân một dòng (`pending` ·
`expired` · `cancelled`) có dòng *Giá gói X*.

## 6. Nghiệm thu máy thật — 🚧 CHƯA LÀM (Task 16)

Điều kiện: người dùng tạo kênh PayOS *Thử nghiệm* và dán `PAYOS_CLIENT_ID / API_KEY / CHECKSUM_KEY` vào
`src/Backend/.env`; áp `database/19` + `prisma generate` (⚠️ không `npm install` — `postinstall` tự `generate`); webhook
qua ngrok hoặc tự ký HMAC POST `localhost:3000/api/payment/webhook`. Mười bước ở spec mục 13; ghi kết quả vào đây khi đo.

- ✅ **`database/19` đã áp lên CSDL dev tối 2026-10-06** theo cho phép đích danh của người dùng — một giao tác `pg`, tệp
  không có BOM. Đo trước/sau: `account` vẫn 19 hàng, thêm cột `premium_expires_at`, hai bảng `payment_order` /
  `payment_transaction`, sáu chỉ mục. Rồi `npx prisma generate` theo `schema.prisma` hiện tại (backend tắt sẵn);
  `account.findFirst` chạy (hết `P2022`), `payment_order.count()` = 0. Bản client Prisma sinh từ `3ef5db7` thôi cần.
- ⏳ Khoá PayOS: `grep -c '^PAYOS_' src/Backend/.env` = **0** lúc áp — chờ người dùng dán.
- 🚧 **G94 (mã xong 2026-10-18 tối) — chưa đo.** Điều kiện thêm: phép **đích danh** chạy `npm install` ở `src/Backend` (gói
  `resend` của gộp `e7570e16`; tự `prisma generate` — CSDL dev đã khớp schema, đo 2026-10-18). Tám bước ở spec G94 mục 10:
  ảnh QR hiện + *Lưu mã QR* → ảnh ở `Pictures/FlowMoney`; MB Bank *Quét từ ảnh* điền đúng số tiền + nội dung; đơn sandbox
  có `bin` / `accountNumber` của PayOS hay rơi về giá trị ghi cứng phía server (`payment.service.js:29–31`); chuyển xong
  quay lại → *Thành công*; chuyển thừa / thiếu → Chi tiết đơn đúng thân, *Đồng ý* / *Từ chối*; thẻ Nâng cấp + dòng Lịch
  sử + khoá *Thanh toán*; bản `--release` lưu ảnh được; 360 dp (Realme) không tràn.

## 7. Giới hạn cố ý

Lùi giờ máy khi offline · kho thắng `type` · hết hạn giữa phiên không hẹn giờ · app bị giết khi đang chờ trả thì không
lưu đơn (lần mở kế `lamMoi()` thấy Premium) · tài khoản mới có 2 ví seed → Basic tạo thêm 1 · hai máy Basic cùng offline
tạo ví thứ 3 → 4 ví, vẫn dùng, không tạo thêm · return URL sang web Admin (đơn 38 mục 4 xin trang trung lập, tuỳ chọn).

## 8. Phân quyền tính năng theo gói (2026-10-08)

Bước 5 của đơn 39 (`DA-XONG/PHAN_QUYEN_THEO_GOI_KHAO_SAT.md` — client soát và chuyển 2026-10-09). Backend (gộp `main` @ `0eb4a05f`) thêm bảng `feature` +
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
  ở `premium/presentation/bloc/co_quyen.dart` — không provider thì **không khoá** (test cũ). Widget ở
  `premium/presentation/widgets/the_khoa_quyen.dart`: `TheKhoaQuyen` (thẻ 🔒 + `NutNangCap(quyen:)`), `KhoaTheoQuyen`
  (bọc con), `DongKhoaQuyen` (dòng khoá trong khối Nhận xét), `DongKhoaCongTac` (*"Cần Premium"* / *"Tạm dừng — cần
  Premium"* khi giá trị đang lưu là bật). Màu của thẻ / dòng / băng khoá ở `AppColors` (nhóm `khoa*` + `vienNutNangCap`, giá trị Stitch 2026-10-08; widget không ghi cứng `Color(0x…)` — ca canh ở `the_khoa_quyen_test.dart`, 2026-10-19).
- **Ngoài cây widget:** `coQuyenNen(MaQuyen)` (`premium/data/co_quyen_nen.dart`) đọc `GoiRepository.hienTai`; chưa có
  phiên → `true`. DI bọc `runAutoPays` · `runAutoDeposits` · `loadKeHoach` · `NhapBienDong.batBienDong` ·
  `NhapBienLai.coQuyen`. Không quyền → bỏ lượt, **không ghi gì, không đổi mốc**. ⚠️ Vế *"chưa có phiên → `true`"* buộc
  **mọi** lượt quét phải đặt gói trước: đường nền qua `datGoi` của `LuotNen`; đường trong app qua hook `datGoi` của
  `PhienDieuPhoiThat.moPhienCucBo` (**G93**, 2026-10-14 — từ G86 lượt quét đầu mỗi phiên chạy **trước** `AuthSuccess`, và
  trước khi có hook thì Basic bị tự trả / tự trích ở lượt ấy). Vì tài khoản đã đặt sẵn, `noiPhien` so với **phiên đã nối
  của nó** chứ không với `idaccount` — không thì mất `lamMoi` và `loaiPhien` ở `AuthSuccess`.
- **Route:** `redirectTaoTheoGoi(LoaiTran)` (trần) và `redirectTheoQuyen(MaQuyen)` (bật/tắt) ở `premium/presentation/bloc/chan_theo_goi.dart` (trước 2026-10-18: `data/`);
  màn Nâng cấp nhận `?tran=` hoặc `?quyen=<maServer>` (`duongNangCap`), mã lạ → như không có tham số. Cả hai **chờ kho gói
  nạp xong** (`GoiRepository.choNapKho()`) rồi mới đọc `idaccount` + `hienTai` (G92, 2026-10-14): router chạy lại `redirect`
  lúc `AuthSuccess`, đúng khi `noiPhien` vừa gán tài khoản mà secure storage chưa trả lời — đọc ngay là Basic mặc định.
  Chỉ chờ **kho**, không chờ `lamMoi` (mạng). Hai chiều hỏng: cửa trần chặn nhầm Premium; cửa quyền thả Basic bị tắt quyền
  (Basic mặc định không mang khoá → `macDinhKhiThieu` = mở).

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
   `quyen_tinh_nang.dart` (và kho ở `data/models/trang_thai_goi.dart`); chuỗi mã quyền server chỉ nằm ở `MaQuyen`.
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

### 8.7 Nghiệm thu máy thật — ✅ đạt (OnePlus 13R, 2026-10-08 khuya, bản debug trỏ `127.0.0.1` + `adb reverse`)

Tài khoản Basic **mới** `thuquyen1` (idaccount 28, tạo qua `POST /api/auth/register`); `/subscription-info` trả trần
3/3/3/3/5 và bảng quyền Basic của CSDL dev (tắt: hai AI, `ai_edge_model`, `export_reports`, `cashflow_forecast`,
`anomaly_spending_insights`, `smart_budget_rebalancing`, `bill_auto_pay`, `goal_auto_deposit`).

| Kịch bản | Kết quả |
|---|---|
| Hoá đơn thứ 4 (sau 3 hoá đơn mở) | ✅ màn Nâng cấp *"Bạn đã dùng 3/3 hóa đơn định kỳ của gói Basic."* |
| Danh mục riêng thứ 6 (sau 5 danh mục tự tạo; 13 bản sao mặc định **không** bị đếm) | ✅ *"Bạn đã dùng 5/5 danh mục riêng của gói Basic."* |
| Khối Dự báo 30 ngày tới (kỳ rỗng và kỳ có dữ liệu) | ✅ thẻ khoá; *Nâng cấp* → *"Dự báo 30 ngày tới là tính năng Premium."* |
| Xuất báo cáo — drawer **và** nút tải trang Phân tích | ❌ → ✅ nút tải mở được trang: route thứ hai `/analytics/export` thiếu cửa (sửa `7b180f8d`); đo lại → *"Xuất báo cáo là tính năng Premium."* |
| Thẻ Đề xuất cân đối (ngân sách Ăn uống 100.000 đ vượt 300 %, Mua sắm 2.000.000 đ làm nguồn) | ✅ thẻ khoá, câu Nhận xét không mời xem kế hoạch; trung tâm thông báo chỉ có *"Đã vượt ngân sách"*, **không** có thông báo cân đối |
| Công tắc Tự trả (form Thêm hoá đơn) | ✅ chạm không đổi (ảnh trước / sau trùng byte), dòng *"Cần Premium"* + Nâng cấp |
| Công tắc Trích tự động (mục tiêu **mới**) | ✅ tắt sẵn, khoá, *"Cần Premium"* |
| Cài đặt AI | ✅ chỉ thẻ khoá *AI trên máy*; ❌ → ✅ thẻ giãn hết chiều cao màn (`Column` `max`, sửa `154f3963`) |
| Trợ lý AI · Nhập nhanh | ✅ khoá |
| Nút Quét · công tắc Đọc biến động số dư (Basic **có** hai quyền này) | ✅ mở bình thường — sheet Chụp / Chọn ảnh; công tắc D1 không có dòng khoá |
| Admin bật `cashflow_forecast` cho Basic qua `PUT /api/admin/permissions` | ✅ khối Dự báo **tự mở trong ≤ 2 s** trên máy đang để ở trang Phân tích, không chạm máy (socket → `lamMoi`) |
| Gạt lại `false` | ✅ khoá lại trong ≤ 3 s; ma trận Basic về đúng như trước lượt đo |

Chưa đo trên máy: dòng khoá **chi bất thường** (cần ≥ 4 tháng dữ liệu đã đóng mới có bất thường để khoá — widget test
canh). Hai chỗ chữ lượt đo ghi nhận — ✅ **sửa cùng đêm, người dùng chọn**, đo lại OnePlus đạt: danh sách *Đặc quyền
Premium* ở màn Nâng cấp nay là **`dacQuyenPremium(goi)`** (`quyen_tinh_nang.dart`) — đúng những thứ Basic đang thiếu theo
bảng server (mỗi trần có số + mỗi quyền tắt; bảng là của Premium thì mặc định 3 trần + 3 AI), Basic dev nay thấy 14 dòng,
không có Quét / Đọc biến động; thẻ Gói tab Cá nhân nay **`tomTatTran`** (`tran_goi.dart`) — mọi trần có số, `null` bỏ
(trước đó Basic có trần `null` sẽ in *"null ví"*), trong mỗi mục là dấu cách không ngắt nên chỉ xuống dòng ở `·`.
`kDacQuyen` (danh sách cố định) **bỏ**. ⚠️ Danh sách dài ra so với màn Stitch `c999da97…` (4 dòng) — chưa đưa lên Stitch.
