# Premium qua PayOS — phía client

**Trạng thái (2026-10-06):** mã **xong** 15/17 task của kế hoạch `docs/superpowers/plans/2026-10-06-premium-payos-client.md`
(gitignore) — còn **Task 16 nghiệm thu máy thật** (sandbox PayOS, cần người dùng dán khoá + cho phép áp `database/19`)
và phần tài liệu này. Spec: `docs/superpowers/specs/2026-10-06-premium-payos-client-design.md` (người dùng duyệt).
Đơn backend: `docs/superpowers/backend/CAN-LAM/CLIENT_PREMIUM_PAYOS.md` (38, không chặn client).

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

**Không** khác theo gói (người dùng chốt): đồng bộ (cả 5 nguồn kích hoạt, kể cả socket `sync.completed`), khối Nhận
xét, gợi ý danh mục, xuất báo cáo, OCR biên lai, đọc biến động số dư, thông báo. Màn Nâng cấp **không** hứa *đồng bộ
tức thì*. Người bị hạ cấp **giữ nguyên** mọi thứ đang có, chỉ không tạo thêm.

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

## 5. Màn Stitch (lượt gọi 2026-10-06 — năm lượt trả `timeout` nhưng màn vẫn được tạo; **chờ người dùng xác nhận**)

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
`src/Backend/.env`; áp `database/19` + `prisma generate` (**cần cho phép đích danh**; ⚠️ không `npm install` —
`postinstall` tự `generate`); webhook qua ngrok hoặc tự ký HMAC POST `localhost:3000/api/payment/webhook`. Mười bước ở
spec mục 13; ghi kết quả vào đây khi đo.

## 7. Giới hạn cố ý

Lùi giờ máy khi offline · kho thắng `type` · hết hạn giữa phiên không hẹn giờ · app bị giết khi đang chờ trả thì không
lưu đơn (lần mở kế `lamMoi()` thấy Premium) · tài khoản mới có 2 ví seed → Basic tạo thêm 1 · hai máy Basic cùng offline
tạo ví thứ 3 → 4 ví, vẫn dùng, không tạo thêm · return URL sang web Admin (đơn 38 mục 4 xin trang trung lập, tuỳ chọn).
