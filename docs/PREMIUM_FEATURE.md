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
  hoàn tiền vẫn bị webhook xử lý lại; chưa khử trùng theo `reference`) — banner đầu `CAN-LAM/LICH-SU/SOAT_SAU_GOP_D72CCD45.md`.
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
         quyen_tinh_nang.dart (trangThaiQuyen · duocDung · dacQuyenPremium) · tran_goi.dart (tranHieuLuc · bangDungDuoc) · cau_quyen.dart · nhac_het_han.dart (0..3 ngày)
data/    models/trang_thai_goi.dart (TrangThaiGoi · laPremium(now) · soNgayConLai · trangThaiTuJson accountType??type · kho ·
                                   B1: quyenPremium · tranPremium — cột Premium, đơn 55 A1)
         models/tran_goi.dart (TranGoi.macDinh 3/3/3 · khongGioiHan · tuJson(khiThieu:))
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
Router: `redirect` → trần hiệu lực (`tranHieuLuc`) không giới hạn? qua : `NguonDemDangHoatDong.dem` → `conTaoDuoc` →
`chuyenHuongTheoGoi` (B1: trần cột Premium cũng áp — trước B1 là *"Premium? qua"*).

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
`features` (12 quyền lúc ấy; nay 31 mã TOGGLE, client đọc 22 — B1, 8.1 chốt 6) **của gói đang hiệu lực**; admin đổi xong backend phát socket `account.permissions_updated`, client
nối nó sang `RealtimeEvent.taiKhoanNangCap` → `GoiRepository.lamMoi()`.

### 8.1 Quyết định người dùng

1. **Theo bảng của server; thiếu khoá thì MỞ** — trừ `ai_assistant` · `ai_quick_input` · `ai_edge_model`, khoá với Basic
   (giữ chốt 2026-10-06). ~~Premium còn hạn → mở hết, bỏ qua bảng.~~ **Thay bởi chốt 6 (B1, 2026-10-27): Premium cũng theo bảng.**
2. Tính năng bị tắt **hiện khoá + Nâng cấp**, không ẩn.
3. Đã bật tự trả / tự trích rồi về Basic → **dừng chạy, giữ công tắc** (không sửa dữ liệu; lên lại Premium chạy tiếp).
4. Quyền chỉ chặn việc **tạo / bật mới** — dữ liệu đang có giữ nguyên.
5. **Trần 0 = không tạo thêm** (người dùng chốt 2026-10-27). Admin-web bỏ tick *∞* là ô về **0** ngay (xoá trắng ô số mới
   là `null` = vô hạn) và tự kẹp số âm về 0. `TranGoi.tuJson` đọc số ≤ 0 thành 0 (chuỗi / kiểu lạ vẫn về mặc định của ô);
   `conTaoDuoc` chặn ngay lần tạo đầu, thứ đang có giữ nguyên; màn Nâng cấp mở đầu *"Gói Basic hiện không cho tạo thêm
   ví."* (`cauMoDau`). Bản trước đọc 0 là rác: ví / ngân sách / mục tiêu về 3, hoá đơn / danh mục riêng thành **không giới
   hạn**. Backend không thi hành trần nào (đo mã 2026-10-27) — chỉ client chặn.
6. **B1 — Premium cũng theo bảng; *tạm ngừng*; cột Premium cho Basic** (người dùng chốt 2026-10-27, câu hỏi chọn được; spec
   `specs/2026-10-27-phan-quyen-cot-premium-va-cong-tac-design.md`). Admin tắt một tính năng ở cột **Premium** → người Premium thấy
   khoá *"Đang tạm ngừng"*, **không** nút Nâng cấp (mua không mở được) — lối vào nào vẫn tới màn Nâng cấp (`?quyen=` tạm ngừng: cửa
   route, nút Quét / Nói, deeplink) thì màn **ẩn giá + nút Thanh toán / Gia hạn** (I2, người dùng chốt 2026-10-28; spec mục 13 (19));
   trần Premium cũng áp (*"Gói Premium hiện cho tạo tối đa N
   ví."* ở màn Nâng cấp, trần 0 → *"…không cho tạo thêm ví."*). Server chỉ gửi bảng của gói đang hiệu lực, nên người Basic không
   thấy cột Premium: đơn **CAN-LAM 55 A1** xin `premiumFeatures` + `premiumLimits` cho Basic; client đã đọc sẵn (`TrangThaiGoi.
   quyenPremium` / `tranPremium`), **chưa có thì như trước B1** (khoá = *cần Premium*). Số công tắc client đọc: **11 → 22**
   (`MaQuyen` thêm 11 mã, mục 8.2).
7. **Premium không có `premium_expires_at` giữ hành vi cũ tới B4** (người dùng chốt phiên 17): `bangDungDuoc` có vế
   Premium-không-hạn → `false`, nên Premium không hạn **mở hết, trần không giới hạn** như trước B1 (server coi tài khoản ấy là
   Basic và gửi bảng Basic — đọc bảng ấy là mọi thứ Basic tắt hiện *"Đang tạm ngừng"* với người Premium). Chống lùi đồng hồ và
   nghĩa Premium không hạn là **B4**.

### 8.2 Bảng quyền ↔ chỗ trong app

| Mã server | Chỗ thi hành | Thiếu khoá thì |
|---|---|---|
| `wallets` · `budgets` · `goals` (trần) | `redirectTaoTheoGoi` ở `/wallets/add`, `/budget/rules` (không `?id`), `/goals/add` | 3 |
| `bills` (trần) | `redirectTaoTheoGoi(LoaiTran.hoaDon)` ở `/bills/add` — phủ cả thẻ *Có vẻ là khoản lặp* (B2), lệnh tạo C3, deeplink | không giới hạn |
| `custom_categories` (trần) | `redirectTaoTheoGoi(LoaiTran.danhMucRieng)` ở `/categories/child/new`, `/categories/group/new` | không giới hạn |
| `export_reports` | cửa route `redirectTheoQuyen` ở `/export-report` | mở |
| `cashflow_forecast` | khối *Dự báo 30 ngày tới* (hai chỗ dựng `_KhoiDuBao`) → thẻ khoá | mở |
| `anomaly_spending_insights` | câu *chi bất thường* ở khối Nhận xét Phân tích: `GoiSoPhanTich.tu(boChiBatThuong:)` bỏ câu, `KhoiNhanXet.chanDuoi` = dòng 🔒 **chỉ khi thật có bất thường** (câu `kDongKhoaChiBatThuong` ở `cau_quyen.dart`; tạm ngừng → câu mặc định) | mở |
| `smart_budget_rebalancing` | thẻ *Đề xuất cân đối* (trang Ngân sách) → thẻ khoá, câu Nhận xét bỏ kế hoạch; thông báo `budgetRebalance` thôi sinh (`loadKeHoach` trả `null`) | mở |
| `bill_auto_pay` | công tắc *Tự trả* (form thêm / sửa hoá đơn) → công tắc khoá; `runAutoPays` bỏ lượt | mở |
| `goal_auto_deposit` | công tắc *Trích tự động* → khoá; mục tiêu **mới** không quyền thì tắt sẵn; `runAutoDeposits` bỏ lượt | mở |
| `ai_edge_model` | màn *Cài đặt AI* → chỉ thẻ khoá (không nút tải, không công tắc); phần Gemma của `/quet` | **khoá với Basic** |
| `ocr_receipt` | nút *Quét* Trang chủ → `/premium?quyen=ocr_receipt`; `NhapBienLai` bỏ lượt (**hàng chờ + ảnh giữ nguyên**) | mở |
| `bank_notification_parser` | công tắc *Đọc biến động số dư* (D1) → khoá; `NhapBienDong` không bật đọc | mở |
| `ai_assistant` · `ai_quick_input` | `lyDoKhoa` màn Trợ lý AI; ô Nhập nhanh — đọc qua `coQuyen` | **khoá với Basic** |
| `net_worth_overview` (B1) | thẻ *Tổng số dư* Trang chủ (`the_tong_so_du`) và khối *Tổng tài sản … gần đây* Phân tích (`khoi_tong_tai_san`) → thẻ khoá; khối Nhận xét Trang chủ **bỏ chip *Tổng số dư*** (`GoiSoTrangChu.tu(boTongSoDu:)`, Task 8b — chip, tập cho phép của `kiemSo` và phần vào prompt cùng mất) | mở |
| `quick_action_shortcuts` (B1) | `hang_nut_nhanh.dart`: hàng năm nút Trang chủ → MỘT dòng khoá (`DongKhoaQuyen` trong khung `khoaCanNen` / `khoaCanVien`) | mở |
| `daily_recording_reminder` (B1) | công tắc *Nhắc ghi chép hằng ngày* (Cài đặt thông báo) → băng khoá, **giữ giá trị**; `ReminderScheduler` không đặt lịch (`nhacGhiChepDuocPhep`, `NOTIFICATION_FEATURE.md` 5m) | mở |
| `bill_reminder_notifications` (B1) | loại `billDueSoon` của `NotificationScanner` + lịch HĐH nhắc trước hạn (`nhacTruocHanDuocPhep`); chip *Nhắc trước* ở form hoá đơn và ở Cài đặt (`hang_nguong`) khoá; **quá hạn vẫn báo**; công tắc nhắc đẩy của form **không** khoá | mở |
| `budget_overspend_alert` (B1) | loại `budgetNearLimit` / `budgetOverspent` (`canhBaoNganSachDuocPhep`); dòng *"Nên chi X/ngày"* (`budget_pace_text`) → dòng khoá ở thẻ ngân sách Trang chủ (`home_budget_card`), tab Ngân sách (`budget_tabs_view`) và card *NHỊP CHI* trang Chi tiết (`budget_detail_view` — card giữ, dòng khoá thay nội dung) | mở |
| `wallet_balance_adjustment` (B1) | ô số dư màn Sửa ví → chỉ đọc + dòng khoá; còn chặn ở lúc lưu (`wallet_edit_page.dart`, `coQuyenDoc` — không sinh khoản bù khi không quyền) | mở |
| `wallet_exclude_total` (B1) | công tắc *Tính vào tổng tài sản* (Sửa ví, `wallet_edit_page`) / *Tính vào tổng số dư tài sản* (Thêm ví, `wallet_add_page`) → băng khoá; chỉ chặn **loại mới** (`doiDuocTinhVaoTong`, `wallet/domain/cong_tac_tinh_vao_tong.dart`, neo giá trị **đã lưu**): ví đã lưu "tính" → công tắc khoá; ví đã loại vẫn loại, **bật lại được** (I3, người dùng chốt 2026-10-28; spec mục 13 (20)) | mở |
| `goal_deposit_withdraw` (B1) | nút *Nạp* / *Rút* ở Chi tiết mục tiêu (`nut_duoi_muc_tieu`) → tắt + dòng khoá (tự trích theo `goal_auto_deposit`); hộp *"Bắt đầu vòng mới?"* (`goal_detail_page`) bỏ vế khuyên bấm *"Rút khỏi mục tiêu"* (đợt sửa cuối) | mở |
| `quick_category_assignment` (B1) | thẻ *"Có N giao dịch chưa có danh mục"* (Sổ giao dịch) → thẻ khoá; route `/transactions/gan-danh-muc` qua `redirectTheoQuyen` | mở |
| `category_keywords_matching` (B1) | khối *Từ khoá nhận diện* (form danh mục + trang `keywordOnly`) → khoá, nút *Lưu từ khóa* tắt; thẻ *"Thêm ‘x’ làm từ khoá…"* ở màn Thêm giao dịch không dựng (`DongDeXuatTuKhoa` — phản hồi chỉ ghi khi người dùng bấm nút). **Từ khoá đã có vẫn dùng để gợi ý** (chốt 8) | mở |
| `in_app_calculator` (B1) | phím **+ / −** của bàn phím số màn Thêm giao dịch (`BanPhimSo.choPhepTinh`) → mờ, chỉ gõ số; biểu thức đang dở khi quyền đổi vẫn tính được (chặn tạo mới) | mở |
| `financial_health_fhs` | **bỏ qua** — app không có màn FHS | — |

*Nhắc ghi sau khi dùng app ngân hàng* không thuộc quyền nào — để mở.

**Chín mã server KHÔNG BAO GIỜ khoá** (spec B1 mục 3 — không vào `MaQuyen`, client bỏ qua giá trị; chép từ chú thích
`quyen_tinh_nang.dart`): `transaction_management` · `offline_first_sync` (lõi; *"đồng bộ không tách theo gói"*) · `vietqr_payment`
(khoá là Basic không nâng cấp được) · `account_deletion` (quyền của người dùng) · `biometric_auth` (trên app là khoá ứng dụng —
miễn phí mọi gói) · `payment_history` (Lịch sử mua là lối vào Chi tiết đơn — chỗ duy nhất xác nhận / hoàn tiền) ·
`ai_model_management` (khoá là không xoá được mô hình 2,4 GB) · `offline_login` · `financial_health_fhs` (app không có tính năng).

### 8.3 Một định nghĩa, bốn cửa

- **`trangThaiQuyen(MaQuyen, TrangThaiGoi, now)`** (`premium/domain/quyen_tinh_nang.dart`) là định nghĩa duy nhất, ba trạng thái
  `TrangThaiQuyen { mo, canPremium, tamNgung }` (B1, 2026-10-27): bảng đã lưu chỉ được tin khi là **của gói đang hiệu lực**
  (`bangDungDuoc`, `tran_goi.dart` — nhận lúc Premium còn hạn ⇔ bây giờ Premium còn hạn). Premium còn hạn: khoá `false` →
  `tamNgung`, còn lại `mo`. Không Premium: có khoá → theo khoá, thiếu → `MaQuyen.macDinhKhiThieu`; khoá thì cột Premium
  (`quyenPremium`, chỉ khi server gửi) `false` → `tamNgung`, không → `canPremium`. **`duocDung`** là vế `bool` (`== mo`) cho mọi chỗ
  chỉ cần "được dùng không" (`KhoaTheoQuyen`, `chanTheoQuyen`, bộ chạy nền) — đếm `grep -rhoF` trên `lib/` 2026-10-28 (kể cả định nghĩa):
  `.coQuyen(` 52 · `coQuyenDoc(` 6 · `coQuyenNen(` 14 · `duocDung(` 5; ba trạng thái chỉ ở `TheKhoaQuyen` / `DongKhoa*` (`context.
  trangThaiQuyen`), hai getter tạm ngừng của Trợ lý AI / Nhập nhanh (`context.trangThaiQuyenDoc`) và màn Nâng cấp. **`tranHieuLuc(goi,
  now)`** là cửa đọc trần duy nhất (bảng dùng được → `goi.tran`; không → Premium không giới hạn, Basic `TranGoi.macDinh`) — G109.
  **`dacQuyenPremium(goi, now)`** (danh sách ✓ màn Nâng cấp) theo bảng của gói đang hiệu lực: Basic → thứ Basic thiếu, so với cột Premium
  server gửi; người xem Premium còn hạn → bảng đã lưu chính là cột Premium (*"Tới 10 ví"*, quyền tạm ngừng không kể); bảng không dùng được
  → mặc định (spec B1 mục 13 (18)). `enum MaQuyen` mang `maServer`, `ten` (chữ trên thẻ khoá và màn Nâng cấp), `macDinhKhiThieu`.
  **`noiKhiQuyenDoi`** (`premium/data/co_quyen_nen.dart`, nối ở `main.dart`) gọi `ReminderScheduler.resync` khi quyền nhắc đổi.
  Ba vị từ nền của thông báo là closure DI qua `coQuyenNen` (`injection_container.dart`): `nhacTruocHanDuocPhep` (scanner + scheduler),
  `nhacGhiChepDuocPhep` (scheduler), `canhBaoNganSachDuocPhep` (scanner) — `notification/` không import `premium/` (`NOTIFICATION_FEATURE.md` 5m).
- **Trong cây widget:** `GoiCubit.coQuyen(MaQuyen)` / `trangThaiCua(MaQuyen)`, extension `context.coQuyen` (watch) /
  `context.coQuyenDoc` (read) và ba trạng thái `context.trangThaiQuyen` (watch) / `context.trangThaiQuyenDoc` (read) ở
  `premium/presentation/bloc/co_quyen.dart` — không provider thì **không khoá** (test cũ). Widget ở
  `premium/presentation/widgets/the_khoa_quyen.dart`: `TheKhoaQuyen` (thẻ 🔒 + `NutNangCap(quyen:)`), `KhoaTheoQuyen`
  (bọc con), `DongKhoaQuyen` (dòng khoá trong khối Nhận xét), `DongKhoaCongTac` (*"Cần Premium"* / *"Tạm dừng — cần
  Premium"* khi giá trị đang lưu là bật), `CongTacTheoQuyen` (chính công tắc: `biKhoa` → mờ 50 % + ổ khoá trong núm, Stitch
  `68593384…` — G111, 2026-10-28; mọi công tắc khoá theo quyền đi qua nó, test quét 41). Biến thể **tạm ngừng** (B1, Stitch `02c0d881…`): thẻ *"Đang tạm ngừng"*, dòng
  `cauDongKhoaTamNgung` (*"<tên> đang tạm ngừng"*), băng *"Tạm ngừng"* xám (`khoaNgung*`) — cả ba **không** nút Nâng cấp; mọi câu ở
  `premium/domain/cau_quyen.dart`. Màu của thẻ / dòng / băng khoá ở `AppColors` (nhóm `khoa*` + `vienNutNangCap`, giá trị Stitch 2026-10-08; widget không ghi cứng `Color(0x…)` — ca canh ở `the_khoa_quyen_test.dart`, 2026-10-19).
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
2. **Test quét `lib/` thứ 21** — `test/features/premium/quyen_tinh_nang_mot_noi_test.dart`: `quyenTinhNang` / `quyenPremium` /
   `tranPremium` (B1) chỉ được đọc ở `quyen_tinh_nang.dart` (và kho ở `data/models/trang_thai_goi.dart`); chuỗi mã quyền server chỉ nằm ở
   `MaQuyen`. Phép so là chuỗi con, đọc cả dòng mã (bỏ dòng `//`) — tên biến chứa ba chữ ấy ngoài hai tệp là đỏ.
3. `redirectTaoTheoGoi` đọc `sl<GoiRepository>()` **và** `sl<NguonDemDangHoatDong>()` lúc chạy — test dựng `AppRouter`
   thật rồi đi qua route tạo (nay thêm `/bills/add`, `/categories/*/new`) phải đăng ký cả hai.
4. `context.watch<GoiCubit>()` — một `emit` cần **hai** nhịp `pump` mới tới widget trong test.
5. Mục tiêu **mới** không quyền trích: tắt sẵn đặt ở `didChangeDependencies` lần đầu (cờ `_daXetQuyenTrich` — xét đúng
   một lần, xét lại ở mỗi lần dựng là đè lựa chọn người dùng vừa gạt). Mục tiêu đang sửa giữ giá trị đã lưu.
6. Nút Quét Trang chủ **chưa có widget test** (khung test Trang chủ nặng) — nghiệm thu máy thay.
7. ⚠️ **`bangDungDuoc` có vế Premium-không-hạn** (B1): Premium với `hetHan == null` → `false`, giữ hành vi cũ (mở hết, trần không
   giới hạn) tới B4. Bỏ vế ấy là người Premium không hạn (server gửi bảng Basic) thấy mọi thứ Basic tắt hiện *"Đang tạm ngừng"*.
8. ⚠️ **Đọc trần thô `goi.tran` là G109** — mọi chỗ đọc trần đi qua `tranHieuLuc`. `grep -rn "goi\.tran\b" lib` (bỏ `goi.tranPremium`)
   chỉ được còn ở `tranHieuLuc` và model. Lệnh đo 2026-10-28 sau đợt sửa cuối: đúng một dòng mã (`tran_goi.dart:26`) + hai dòng chú thích —
   `dacQuyenPremium` nay đọc trần qua `tranHieuLuc` (spec B1 mục 13 (18); bản trước đọc `goi.tran` có gác `bangCuaBasic`).
9. `TrangThaiGoi.tran` mặc định theo gói (initializer `tran ?? _tranKhiThieu(loai, hetHan, nhanLuc)`): **không giới hạn** chỉ khi Premium
   còn hạn tại `nhanLuc`, còn lại `TranGoi.macDinh`. `premiumLimits` (`_docTranPremium`, `trang_thai_goi.dart`): rác (không phải Map) →
   `tranPremium = null` = **chưa gửi** (spec mục 13 (10) — không đưa rác vào `TranGoi.tuJson`, hàm ấy trả `khiThieu` cho rác và "chưa gửi"
   thành "đã gửi"); Map thiếu / lạ một ô → ô ấy không giới hạn (`TranGoi.tuJson(khiThieu: TranGoi.khongGioiHan)`).
10. ⚠️ **`ReminderScheduler`: chặn quyền ở điều kiện NHÁNH đặt lịch, không trong vòng `khongHuy`** (lịch cũ thuộc `khongHuy` sống
    tiếp sau khi mất quyền). Hệ quả cố ý: lịch đã *Hoãn* của hoá đơn cũng bị huỷ khi mất quyền. Chi tiết `NOTIFICATION_FEATURE.md` 5m.
11. ⚠️ **`DropdownButton` khoá VẪN vẽ mục đang chọn** khi giá trị nằm trong `items`; `disabledHint` / `hint` chỉ hiện khi giá trị
    **ngoài** `items` (hàng kéo về mang số nhắc lạ — bản release). **Đính chính kết luận 10 của kế hoạch** (nói "vẽ `disabledHint
    ?? hint`") sau phép đo Task 9: bốn câu chữ chú thích đã viết lại theo cơ chế đo được.
12. Ô số dư màn Sửa ví khoá còn **chặn ở lúc lưu** (`coQuyenDoc` trong `_saveWallet`): chỉ khoá giao diện thì đường lưu vẫn sinh khoản bù.
13. Trần của kho chỉ đáng tin **sau lượt `lamMoi` đầu kể từ bản B1** (preflight N4): kho Premium ghi trước B1 đã toàn `null` (server luôn gửi
    đủ 5 khoá `limits`, hạt giống Premium đều `NULL`; `toJson` ghi đủ 5 ô nên `khiThieu` không bao giờ áp cho kho) — chỉ khi CSDL đang chạy
    **thiếu một hàng LIMIT** của cột Premium thì ô ấy giữ mặc định cũ (`3` với ví / ngân sách / mục tiêu) tới lượt `lamMoi` kế. Không liên
    quan `premiumLimits`. Task 13
    Bước 0 kiểm đủ 5 hàng (spec mục 10).
14. **Màn Nâng cấp ẩn nút mua theo CÂU ĐANG HIỆN** (`anNutMua = cauTran == null && tamNgung`, I2): có cả `?tran=` lẫn `?quyen=`
    tạm ngừng thì câu trần thắng và mua là nới trần → nút ở lại (ca đối chứng ở `nang_cap_page_test.dart`, thử bằng bản sai bỏ vế
    `cauTran == null`). Ẩn theo riêng `ttQuyen` là mất nút trên màn đang nói về trần.
15. **Công tắc *"Tính vào tổng"* neo vào giá trị ĐÃ LƯU** (`_wallet?.includeInTotal`, I3), không vào `_includeInTotal` của form: neo vào
    giá trị đang chọn thì người bị hạ cấp bật lại xong là khoá ngay, chạm nhầm không gỡ được trước khi Lưu (ca canh thử bằng đúng bản
    sai ấy). Màn Thêm truyền `daLuuTinhVaoTong: true`.
16. ⚠️ **Đừng khoá công tắc bằng `Switch(onChanged: null)` trần** (G111, 2026-10-28): màu đặt cứng (`activeTrackColor`,
    `inactiveTrackColor`) thắng màu khoá mặc định của Material 3 — công tắc bị khoá vẽ y hệt công tắc mở (đo bằng `paints..rrect`).
    Đi qua `CongTacTheoQuyen(onChanged: f, biKhoa: !context.coQuyen(…))`; `HangCongTac` nhận `biKhoa`. Test quét 41
    (`test/features/premium/cong_tac_khoa_mot_noi_test.dart`) cấm `Switch(` / `HangCongTac(` hỏi `coQuyen(` trong đối số mà không
    qua `biKhoa:`.

### 8.6 Màn Stitch (người dùng xác nhận 2026-10-08; cả ba lượt gọi `timeout`, màn hiện sau ~10 phút)

| Màn / khối | id |
|---|---|
| Thẻ khoá trong trang + dòng khoá chi bất thường | `595529bf…` |
| Băng khoá công tắc (form hoá đơn) | `68593384…` |
| Nâng cấp mở từ tính năng bị khoá | `9db35f88…` |
| **B1** — *Khoá theo gói - Biến thể Đang tạm ngừng - FlowMoney* (sáu khối: thẻ khoá, dòng khoá, băng công tắc, dòng khoá nút ghi nhanh, dải trần Premium, băng Trợ lý AI) | `02c0d88174b641faa14f931174d40b99` (người dùng xác nhận đủ sáu khối và duyệt nguyên bảng *Câu chữ chốt* 2026-10-27) |

**Lệch Stitch có chủ ý (B1)** — đối chiếu bằng mắt ở Task 13: khối 1 thẻ tạm ngừng viền **liền** (Stitch viền đứt nét — Flutter không có
viền đứt dựng sẵn, phải tự vẽ `CustomPainter`); khối 3 băng tạm ngừng **xám** theo Stitch (token `AppColors.khoaNgung{Nen,Vien,Chu,Icon}`,
không tô vàng như *"Cần Premium"*); khối 4 khung dòng *Nút ghi nhanh* dùng `khoaCanNen` / `khoaCanVien` (gần `#fbf9f2` / `#eedca8`);
khối 5 dải trần Premium giữ `info_outline` (Stitch `account_balance_wallet`); ổ khoá `lock_outline` (Stitch glyph `lock` đặc);
khối 6 băng Trợ lý AI tạm ngừng dùng `smart_toy_outlined` theo Stitch. **Đối chiếu khối 2 / 4 (2026-10-28 phiên 21, tải HTML Stitch):**
khối 2 dòng khoá **tạm ngừng** Stitch vẫn tô **vàng** (nền `#fef9ee`, ổ khoá `#b37700`), chỉ bỏ nút — app khớp (`DongKhoaQuyen` giữ
`khoaVang` / `khoaNenVang`); bất đối xứng *dòng vàng / băng xám* là của chính Stitch (khối 2 vàng, khối 3 xám). Khối 4 (Trang chủ, nút
ghi nhanh) Stitch **chỉ vẽ** bản *"dành cho Premium"*; bản tạm ngừng của app (khung vàng, *"Nút ghi nhanh đang tạm ngừng"*, không nút)
theo luật khối 2 — người dùng chốt **giữ** 2026-10-28. Màn Nâng cấp `c999da97…` / `9db35f88…` luôn vẽ giá + nút; app
**ẩn** chúng khi đến từ quyền tạm ngừng (I2, 2026-10-28 — mục 8.5 (14)), không dựng màn Stitch riêng cho biến thể này.

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
Premium* ở màn Nâng cấp nay là **`dacQuyenPremium(goi)`** (`quyen_tinh_nang.dart`; từ đợt sửa cuối B1 `dacQuyenPremium(goi, now)`,
người xem Premium còn hạn thấy cột Premium — 8.3) — đúng những thứ Basic đang thiếu theo
bảng server (mỗi trần có số + mỗi quyền tắt; bảng là của Premium thì mặc định 3 trần + 3 AI), Basic dev nay thấy 14 dòng,
không có Quét / Đọc biến động; thẻ Gói tab Cá nhân nay **`tomTatTran`** (`tran_goi.dart`) — mọi trần có số, `null` bỏ
(trước đó Basic có trần `null` sẽ in *"null ví"*), trong mỗi mục là dấu cách không ngắt nên chỉ xuống dòng ở `·`.
`kDacQuyen` (danh sách cố định) **bỏ**. ⚠️ Danh sách dài ra so với màn Stitch `c999da97…` (4 dòng) — chưa đưa lên Stitch.

### 8.8 B1 — trạng thái và giới hạn (2026-10-28)

✅ **Mã xong Task 1–11** (`e5251822..6cbff979`, 18 commit kể cả vòng sửa và Task 8b) + tài liệu Task 12 (`8772a902`) + **đợt sửa cuối sau review
toàn nhánh** (`457381c6`: `dacQuyenPremium(goi, now)` theo bảng gói hiệu lực — spec mục 13 (18); `trangThaiQuyenDoc` có chỗ gọi, `cauTamNgung` gỡ,
`kDongKhoaChiBatThuong` vào `cau_quyen.dart` — 13 (17); hộp *"Bắt đầu vòng mới?"* bỏ vế khuyên Rút khi `goal_deposit_withdraw` khoá; khối Nhận xét
Trang chủ đọc quyền trong `Builder` riêng); `flutter test` **8354 pass / 10 skip**, `flutter analyze` **20** (đo 2026-10-28 sau đợt sửa cuối).
✅ **Nghiệm thu máy thật đạt** (Task 13, 2026-10-28 phiên 19 — mục **8.9**: Bước 0 go trên cả hai CSDL; bước 1–7 + I2 / I3 đạt trên Realme
(Premium) và máy ảo (Basic); còn vài chỗ chưa nhìn, liệt kê cuối 8.9). ⚠️ **Trước phát hành: Task 13 Bước 0** (✅ đo 2026-10-28 — go; đo lại nếu ma trận đổi) (spec mục 10 bước 0, go / no-go, chỉ đọc) — cột Premium trên ma trận đang chạy (cả Supabase dùng chung) có ô `false` nào
trong 22 mã (có → mọi người Premium thấy mã ấy *"Đang tạm ngừng"* — dừng, hỏi người dùng) và đủ 5 hàng LIMIT (bẫy 13).
Phần dự phòng cột Premium cho Basic chờ đơn **CAN-LAM 55 A1 / A2 / A3**; chưa có thì Basic thấy khoá *"cần Premium"* như trước B1.

Giới hạn biết trước (spec mục 8, bản đã thêm): app chỉ thấy bảng của gói đang hiệu lực · Premium không hạn / lùi đồng hồ là B4 · backend chỉ chặn
3 mã (`requireFeature`) nên mọi khoá khác là khoá giao diện · Trụ 1 của mã LIMIT chờ A2 · khoá giữa chừng một tính năng đang bật: dừng, giữ công tắc ·
**gói số bậc 1 của Trợ lý AI (`nguon_goi_so.dart:125-131`) và gói Ví (`goi_so_vi.dart:147`) vẫn mang tổng tài sản khi `net_worth_overview` khoá**
(ngoài chốt 6) · (P-N5) `noiKhiQuyenDoi` có thể kích `resync` ở lượt `_phat` đầu từ kho lúc mở app, song song lượt khôi phục của scanner — hai dòng
`dat_lich` cùng khoá trong nhật ký B5a; `resync` không có khoá loại trừ, quyền tắt đúng lúc lượt khác đã đọc vị từ có thể đặt lại lịch vừa huỷ (tự sửa
ở lượt quét kế) · cuộc đua lúc đăng xuất (review M1): bộ quét đã `cancelAll` mà `GoiRepository` còn tài khoản — một lượt `lamMoi` lật quyền nhắc đúng
khe ấy làm `noiKhiQuyenDoi` `resync` lịch của tài khoản vừa đăng xuất; không có cờ "đang chạy" công khai nên không sửa bằng mã (spec mục 8).

### 8.9 B1 Task 13 — nghiệm thu máy thật (Realme RMX2205 + máy ảo, 2026-10-28 phiên 19) — ✅ đạt mọi bước

Bản debug `a3d3820d…` (sau I2 / I3, mã `eb1f7380`), `API_BASE_URL=http://127.0.0.1:3000/api` + `adb reverse`; backend dev trỏ `PersonFinance`
(log `PostgreSQL connected {"database":"PersonFinance"}`), tài khoản **10 — Premium tới 05/11/2026**; ma trận đổi qua `PUT /api/admin/permissions`
(gửi đủ `is_enabled` + `limit_value` — backend ghi `limit_value = null` khi vắng); CSDL máy sao lưu trước ở
`D:\FlowMoney-saoluu\realme-2026-10-28-phien19-truoc-task13\`. Mở lạnh không hỏi PIN: cấu hình khoá ứng dụng **vắng** trên máy (kho bảo mật
không có khoá `khoa_app_10`, công tắc *Khoá FlowMoney* tắt — kiểm sau lượt đo); bàn giao phiên 18 ghi *"khoá bật"*; **người dùng xác nhận tự
tắt** — không phải lỗi.
Công tắc bị khoá vẽ **giống hệt** công tắc mở (xanh đậm) — chỉ băng bên dưới báo khoá (có từ B1, chưa sửa).

| Bước | Kịch bản | Kết quả |
|---|---|---|
| 0 | Ma trận cột Premium, chỉ đọc — Supabase dùng chung **và** `PersonFinance` | ✅ go: 0 ô `false` trong 22 mã, đủ 5 hàng LIMIT (`null`); cột Basic tắt 9 mã, trần 3/3/3/3/5 — hai CSDL trùng nhau |
| 1 | Tắt `export_reports` cột Premium → drawer *Xuất báo cáo* và nút tải trang Phân tích (`/analytics/export`) | ✅ màn Nâng cấp *"Xuất báo cáo hiện đang tạm ngừng."*, **không giá, không nút mua** (I2) |
| I2 | Tắt `ocr_receipt` → nút *Quét* Trang chủ | ✅ *"Quét hóa đơn, biên lai hiện đang tạm ngừng."*, không giá / nút; thẻ gói, đặc quyền, *Lịch sử mua* còn |
| I3 | Ví *test* đã lưu "không tính" (loại khi còn quyền) → tắt `wallet_exclude_total` → Sửa ví | ✅ băng xám *"Tạm ngừng"*; công tắc **mở**: bật → tắt lại → bật (trước Lưu); Lưu "tính" → mở lại: công tắc **khoá ở BẬT**; ví về trạng thái ban đầu (tổng -3.518.000 đ, 6 ví) |
| — | Tạm ngừng các khối khác (tín hiệu socket ≤ 3 s, không chạm máy) | ✅ thẻ *Dự báo 30 ngày tới — Đang tạm ngừng* (viền liền); băng Trợ lý AI icon robot + ô nhập *"Đang tạm ngừng"*; băng *Tự động thanh toán* form hoá đơn xám; Trang chủ: thẻ *Tổng tài sản — Đang tạm ngừng* + dòng *"Nút ghi nhanh đang tạm ngừng"* có khung; phím **+ / −** mờ; ô số dư Sửa ví chỉ đọc + *"Điều chỉnh số dư ví đang tạm ngừng"*; công tắc *Nhắc ghi chép hằng ngày* giữ BẬT + băng *"Tạm ngừng"* |
| 2 | Trần ví cột Premium = 6 (= số ví đang hoạt động) → *Thêm ví mới* | ✅ *"Gói Premium hiện cho tạo tối đa 6 ví."*, đặc quyền *"Tới 6 ví"*; giá + *Gia hạn* ở lại (màn nói trần, không phải tạm ngừng) |
| 4 | Tắt `daily_recording_reminder` → `dumpsys alarm`; bật lại | ✅ 3 lịch 20:00 (28 · 29 · 30/10) huỷ trong ≤ 6 s, *Tổng kết tuần* còn; bật lại → 3 lịch về |
| 6 | **G109** (người dùng cho phép đích danh `UPDATE premium_expires_at`): hạn tài khoản 10 = bây giờ + 4 phút → PUT ma trận giữ nguyên để app nhận hạn (*"Còn 0 ngày · đến 28/10/2026"*) → gỡ `adb reverse` (app không với tới máy chủ) → quá hạn → *Thêm ví mới* (ví thứ 7) | ✅ *"Gói hiện tại: Basic"*, *"Bạn đã dùng 3/3 ví của gói Basic."*, bị chặn (mã cũ: không giới hạn); trả hạn `2026-11-05 14:54:58.037` + nối lại → máy về *Premium — Còn 8 ngày*; `Type`, `Update_at`, `payment_order` (0 hàng) không đổi |
| 3 | Máy ảo `FlowMoney_16G`, tài khoản **Basic mới** `thub1t13` (idaccount **29**, `POST /api/auth/register` trên `PersonFinance`; CSDL máy ảo của tài khoản 10 sao lưu trước ở `D:\FlowMoney-saoluu\mayao-2026-10-28-phien19-truoc-dangnhap-29\`); tắt ở **cột Basic** `quick_action_shortcuts` · `net_worth_overview` · `wallet_exclude_total` · `in_app_calculator` · `bill_reminder_notifications` | ✅ Trang chủ: *Tổng tài sản — Dành cho Premium* + **Nâng cấp**; *"Nút ghi nhanh — dành cho Premium"* + **Nâng cấp** → màn Nâng cấp *"Nút ghi nhanh là tính năng Premium."* **có** giá + *Thanh toán* (đối chứng I2), đặc quyền kể đủ 5 mã vừa tắt |
| 5 | Hoá đơn *Internet* hàng tuần hạn 04/11 (nhắc trước 3 ngày) trên tài khoản 29 → tắt `bill_reminder_notifications` cột Basic → bật lại | ✅ lịch `01/11 08:00` có → **huỷ** trong ≤ 7 s → **về**; *quá hạn vẫn báo* chưa đo (không có hoá đơn quá hạn) |
| 7 | Trả ma trận | ✅ qua API (không dùng *Khôi phục mặc định* — nạp lại cả ma trận từ tệp seed); chạy lại script Bước 0 sau mỗi đợt (Premium rồi Basic): **khớp từng dòng** mốc trước đo |

**Chưa đo trên máy:** *quá hạn vẫn báo* khi tắt nhắc trước hạn; chip *Nhắc trước* khoá (form hoá đơn / Cài đặt); dòng khoá *nhịp chi* ngân sách / nạp rút
mục tiêu / gắn danh mục / từ khoá (cùng widget đã thấy, có widget test). Tài khoản 29 (`thub1t13`) và hoá đơn *Internet* của nó **để lại** trên
`PersonFinance` dev (dùng cho lần đo sau); máy ảo đang đăng nhập tài khoản 29.
**Đối chiếu Stitch `02c0d881…` — xong 2026-10-28 phiên 21, khớp** (mục 8.6, đoạn *Lệch Stitch có chủ ý*): dòng khoá tạm ngừng (*"Điều chỉnh số dư
ví đang tạm ngừng"*, *"Nút ghi nhanh đang tạm ngừng"*) vàng theo Stitch khối 2, băng công tắc tạm ngừng xám theo khối 3. Ghi nhận
*"công tắc bị khoá vẽ giống công tắc mở"* là lỗi thật — **G111**, sửa cùng ngày (mục 8.5 (16)).
