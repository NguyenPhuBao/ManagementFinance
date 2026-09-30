# D1 — Đọc biến động số dư trên máy để điền sẵn giao dịch — thiết kế (Phần 2)

> ✅ **THI CÔNG XONG + NGHIỆM THU MÁY THẬT 2026-09-30** (OnePlus 13R, debug rồi release) — tài liệu bàn giao
> `docs/BIEN_DONG_SO_DU_FEATURE.md`. Lệch với thiết kế dưới đây, đều do người dùng chốt lúc thi công: danh sách trắng chỉ
> gồm gói **đã đo** (MB Bank, MoMo, ZaloPay — VCB / TCB / BIDV / SMS chưa có mẫu); màn đồng ý liệt kê **nguồn đang đọc**,
> không đủ bảy (§3.4 đã sửa); bộ lọc thô nhận cả `số + đ/₫/VND` (tin ví điện tử không có dấu ±); lần đầu một cặp nguồn +
> đuôi TK thì ví **trống**; route thật là **`/add`**; chế độ thu mẫu bản debug chỉ log hình dạng đã che.

**Ngày:** 2026-09-28 (tối). **Phần 1** (kiến trúc) đã trình backend qua đơn
`docs/superpowers/backend/DA-XONG/CLIENT_DOC_BIEN_DONG_SO_DU_TREN_MAY.md`, và backend **duyệt toàn diện** 2026-09-26 kèm
một điều **bắt buộc**: màn giải thích + xin đồng ý trước khi dẫn tới Cài đặt quyền truy cập thông báo (Nghị định 13/2023).
**Phần 2** (tệp này), người dùng duyệt trong chat 2026-09-28, với các lựa chọn:

- **App đóng:** Kotlin bắn **một thông báo chung, không số tiền**.
- **Danh sách trắng:** **MB Bank, Vietcombank, Techcombank, BIDV, app Tin nhắn (SMS), MoMo, ZaloPay**. Hai ví điện tử
  **vượt** bản backend đã duyệt, nên có đơn báo
  `docs/superpowers/backend/CAN-LAM/CLIENT_DOC_BIEN_DONG_THEM_VI_DIEN_TU.md`.
- **Tin chưa ghi hiện ở:** **trung tâm thông báo + thẻ ở Sổ giao dịch**.
- **Tin thô:** **xoá ngay khi nhập**; phần đã đọc xoá khi **Lưu / Bỏ qua**, tối đa **30 ngày**.

Bất biến ④ nhóm C: *"không tool nào ghi thẳng"*. Tính năng này **không tự tạo giao dịch nào**. Thứ tự: C1 → C2 → **D1** →
C3 → C4. **Phụ thuộc C2** (đường điền sẵn form). **Chỉ Android.** Không đổi schema, không trường đồng bộ mới, `provider`
giữ `'Manual'`.

> ⚠️ **Soát với mã C2 đã thi công (2026-09-30, phiên soát tài liệu — spec này viết 28/09, trước C2).** Đường điền của C2
> tên thật là **`_apDungKetQua(cau, chonDuoc, tuKhoa, {KetQuaAi? ai})`** ở `AddTransactionPage` — **không có**
> `_dienTuKetQua`. Hàm ấy nhận **câu** rồi tự gọi `docCauGiaoDich`, **không** nhận một `KetQuaDocCau` dựng sẵn; nên §3.3
> (*"truyền `KetQuaDocCau` vào `AddTransactionPage`"*) đòi **tách** phần áp của nó (từ `kq` trở đi: `_chonHuong`, gõ số
> tiền qua `themPhimSoTien`, ngày giữ giờ, ví + `_nguoiDungDaChonVi`, `_chonDanhMuc`, ghi chú, `_choPhanXu`, dòng tóm tắt)
> thành một hàm nhận `KetQuaDocCau` — việc của D1, không phải của C2. Danh mục của C2 nay là **tên → B1 khi chắc → từ khoá
> → AI** (không chỉ B1), và C2 còn một quyết định **chưa thi công** (*luật trước, AI là lớp cuối cho mọi ô* — banner "ĐỔI
> LẦN HAI" spec C2) — soát lại đường điền khi mở D1.

## 1. Luồng tổng

```
App ngân hàng / Tin nhắn / ví điện tử hiện thông báo
  → [Kotlin] BienDongListenerService.onNotificationPosted
      danh sách trắng? → bỏ OTP → có mẫu "± chữ số"?
      → nối 1 dòng JSON vào files/bien_dong_cho.jsonl
      → cập nhật MỘT thông báo tóm tắt (id cố định): "Có N biến động số dư mới — chạm để ghi"
  → người dùng mở app (chạm tóm tắt, hoặc mở bình thường)
  → [Dart] NhapBienDong: đọc + đổi tên tệp → bộ đọc tin → gộp trùng → AppNotifications loại 20 → XOÁ tệp
  → trung tâm thông báo / thẻ Sổ giao dịch → chạm một dòng
  → /transactions/add?<các ô điền sẵn> → người dùng xem lại → Lưu (hoặc Bỏ qua)
  → dòng loại 20 bị xoá
```

## 2. Phía Android (Kotlin)

- `android/app/src/main/kotlin/.../BienDongListenerService.kt`, khai báo trong `AndroidManifest.xml` với
  `android.permission.BIND_NOTIFICATION_LISTENER_SERVICE` và intent-filter
  `android.service.notification.NotificationListenerService`. ⚠️ Manifest là **vùng mù** của `flutter test`,
  `flutter analyze` **và** `flutter build apk` (bẫy 7.11 `NOTIFICATION_FEATURE.md`), nên nghiệm thu trên máy thật là bắt
  buộc.
- **Danh sách trắng** là một hằng tên gói. Gói thật của từng app (kể cả app Tin nhắn của Realme / OnePlus / Samsung /
  Google) phải **đo trên máy** ở Task 1, không đoán. ✅ Đo trên **OnePlus 13R** 2026-09-30 bằng tin biến động thật:
  `com.mbmobile` (MB Bank), `com.mservice.momotransfer` (MoMo), `vn.com.vng.zalopay` (ZaloPay). Vietcombank,
  Techcombank, BIDV (máy không cài) và Tin nhắn (chưa có tin) **chưa vào**.
- **Bộ lọc thô** (không trích số): bỏ tin chứa *OTP* / *mã xác thực* / *ma xac thuc* (không phân biệt hoa thường); giữ
  tin có **số tiền**: `[+-]\s?(vnd\s?)?\d[\d.,]*` **hoặc** `\d[\d.,]*\s?(đ|₫|vnd)`. Đây là bộ **lọc**; mọi phép **đọc** ở
  Dart, nên chỉ có một định nghĩa của *"số tiền trong tin"*. ⚠️ **Đổi 2026-09-30, người dùng chốt:** bản đầu chỉ giữ
  `[+-]\s?\d…` — nhưng tin **MoMo / ZaloPay không có dấu ±** (*"Nhận 15.000đ qua chuyển khoản"*, *"Số tiền 20.000 ₫ …"*;
  chiều nằm ở động từ *"Nhận"*), nên cả hai ví bị bỏ trước khi ghi đĩa; và **Techcombank** viết `+ VND 208,080` (chữ
  `VND` chen giữa dấu và số) nên cũng bị bỏ — ca test nối dây bắt được.
- **Cất:** mỗi tin một dòng `{"goi","tieuDe","noiDung","luc","khoa"}` (`khoa` = `StatusBarNotification.key`) nối vào
  `context.filesDir/bien_dong_cho.jsonl`. Dart đọc qua `getApplicationSupportDirectory()` (Android trả đúng `files/`).
  Kiểm cặp đường dẫn này ở Task 1.
- **Báo:** kênh riêng `flowmoney_bien_dong`, **một** thông báo id cố định, nội dung *"Có {N} biến động số dư mới — chạm để
  ghi"* (N = số dòng đang chờ trong tệp). Không số tiền, không tên người gửi. `PendingIntent` mở `MainActivity` kèm extra
  `bien_dong=1`.
- **Kênh `flowmoney/bien_dong`** (MethodChannel, cùng khuôn `flowmoney/ly_do_thoat`):
  `coQuyen()` (tra `NotificationManagerCompat.getEnabledListenerPackages`), `moCaiDat()` (Intent
  `ACTION_NOTIFICATION_LISTENER_SETTINGS`), `moTuThongBao()` (lần khởi động này có đến từ thông báo tóm tắt không), và
  `huyTomTat()`.
- Người dùng **tắt** tính năng trong app → Kotlin **không** đọc nữa (cờ trong `SharedPreferences` của Kotlin, Dart ghi qua
  kênh), dù quyền hệ thống vẫn bật. App không tự thu hồi quyền được, nên màn Cài đặt nhắc người dùng tự tắt nếu muốn.

## 3. Phía Dart

### 3.1 Bộ đọc tin — `lib/features/transaction/domain/doc_tin_bien_dong.dart`

`TinBienDong? docTinBienDong({required String goi, required String tieuDe, required String noiDung, required DateTime luc})`
→ `TinBienDong { double soTien; String chieu /* 'thu' | 'chi' */; DateTime thoiGian; String noiDung; String nguon /* tên hiển thị: "MB Bank"… */; String? duoiTaiKhoan; String? maGiaoDich; }`.

- Một khuôn cho mỗi nguồn. Khuôn ngân hàng dựa trên `docs/AI/Classify.md` §4.1–4.3 (BIDV, MB Bank, Techcombank; tên trường
  theo §4.2). Vietcombank, MoMo, ZaloPay và tin SMS từ **mẫu thật thu ở Task 1**.
- Số tiền theo **dấu** trong tin: `+` → thu, `-` → chi. Dấu chấm / phẩy nghìn theo khuôn từng nguồn.
- Không khớp khuôn nào → `null` (tin bị bỏ, không có dòng thông báo).
- `thoiGian`: thời điểm trong tin nếu có, không thì `luc` của thông báo.

### 3.2 Nhập hàng chờ — `NhapBienDong`

Chạy ở `NotificationScanner.start(idaccount)` (cùng chỗ B5a nhập tệp hàng chờ của nó) **và** khi app quay lại
(`resumed`). Theo thứ tự:

1. Đổi tên tệp sang `.dang_nhap`, đọc từng dòng; dòng hỏng thì bỏ.
2. Đọc từng dòng bằng `docTinBienDong`.
3. **Gộp trùng** với nhau và với các dòng loại 20 **đang có**: cùng `maGiaoDich`, **hoặc** cùng `soTien` + cùng `chieu` và
   cách nhau ≤ 5 phút. Đây là *chức năng 3 (Deduplication) phía client* mà backend đã xác nhận.
4. Mỗi tin còn lại thành một hàng `AppNotifications` **loại thứ 20** (`NotificationKind.bienDongSoDu`, nhóm mới hay nhóm
   có sẵn: xem 3.4):
   - `dedupeKey = 'bienDong:<maGiaoDich hoặc băm(nguon, soTien, chieu, thoiGian phút)>'`;
   - `title` = *"{+/−}{số tiền} · {nguồn}"*;
   - `body` = nội dung đã rút gọn;
   - `deeplink` = `/transactions/add?` với `amount`, `huong`, `date`, `note`, `nguon`, `duoi`.
5. **Xoá** tệp `.dang_nhap`. Tin thô **không** còn ở đâu nữa.
6. Gọi `huyTomTat()`.

⚠️ Thêm một giá trị vào `NotificationKind` là phải sửa **hai `switch` không `default`** ở `notification_prefs.dart` và dựng
thêm đầu vào cho `tatCaUngVien()` ở `notification_deeplink_test.dart` (đúng thiết kế, đừng thêm `default`).

### 3.3 Form điền sẵn

- `/transactions/add` đọc query và truyền `KetQuaDocCau` (kiểu của C2) vào `AddTransactionPage`, rồi đi **đúng** đường
  điền của C2 (tên viết lúc thiết kế là `_dienTuKetQua`; mã C2 là `_apDungKetQua`, nhận câu — phải tách, banner đầu
  spec). Số tiền, chiều, ngày (giữ giờ trong tin), ghi chú = nội dung.
- **Ví chọn sẵn:** bảng cục bộ *"nguồn + đuôi tài khoản → walletId"* lưu bằng `flutter_secure_storage`, khoá theo tài
  khoản (`bien_dong_vi:<idaccount>`), cùng khuôn `SecureStorageNotificationPrefsStore`. Ghi ở lần **Lưu** đầu tiên của mỗi
  cặp; lần sau chọn sẵn. Ví đã lưu trữ / đã xoá thì bỏ qua (dùng `getActive`).
- **Danh mục:** bộ đoán của B1 trên ghi chú (qua C2 — mã C2 nay đi tên → B1 → từ khoá → AI, banner đầu spec).
- **Nhắc trùng:** sổ đã có khoản cùng số tiền, cùng chiều, cùng ngày → dòng *"Có thể bạn đã ghi khoản này"*. Người dùng
  tự quyết, không chặn.
- **Lưu** → giao dịch đi đường nhập tay (`provider = 'Manual'`, payload 13 trường), rồi xoá hàng loại 20 tương ứng.
  **Bỏ qua** (nút trên form khi mở từ loại 20, hoặc vuốt ở trung tâm thông báo) → cũng xoá hàng ấy.
  ⚠️ Xoá **cứng** hàng loại 20 là ngoại lệ có chủ ý của nếp *"dismiss mềm để giữ khoá trùng"*: tin đã xử lý thì không còn
  lý do giữ nội dung ngân hàng (Nghị định 13, tối thiểu hoá). Chống trùng về sau dựa vào bước 3 của 3.2 trong cửa sổ 5
  phút, đủ vì nguồn chỉ bắn lại ngay lập tức.
- **30 ngày:** lượt dọn của scanner xoá hàng loại 20 cũ hơn 30 ngày (khác mốc 90 ngày của thông báo thường).

### 3.4 Nhóm thông báo và công tắc

> **Stitch (người dùng xác nhận 2026-09-30):** màn đồng ý `bed4d292bff6449cb2847af7eb95faf1` · Cài đặt thông báo
> `d42ce71266ca485c883ca7f9ed855f29` (thẻ *Tự động hoá giao dịch · Mới*) · Sổ giao dịch `e59155ff5c0d4fd399e6fb8109b939d8` ·
> Thêm giao dịch điền sẵn `52d9d2ef0a67456f9c1317bbf33cd994`. Bốn lượt gửi đều trả timeout; màn hiện ra sau đó.

- Loại 20 thuộc một **nhóm mới** `bienDong` (chip lọc mới ở trung tâm thông báo; test *"mỗi nhóm có đúng một chip"* sẽ đòi
  điều ấy). Công tắc nhóm **chính là** công tắc tính năng: tắt thì Kotlin thôi đọc (qua kênh).
- **Màn xin đồng ý** (bắt buộc): bật công tắc lần đầu → màn nêu (1) mục đích, (2) **danh sách trắng** — ⚠️ *(sửa 2026-09-30, người dùng chốt)*: đúng các nguồn
  dịch vụ **đang đọc** (`nguonDangDoc`, suy từ `kNguonTheoGoi`), không phải cả bảy: lúc thi công mới đo được 3 gói (MB Bank,
  MoMo, ZaloPay) và hứa đọc nguồn chưa đo là lời hứa sai; đo thêm gói nào thì màn tự thêm, (3) lọc
  bỏ OTP trước khi lưu, (4) chỉ lưu trên máy, xoá khi xử lý xong hoặc sau 30 ngày, (5) không gửi ra ngoài, không liên kết
  ngân hàng → nút **Đồng ý và mở Cài đặt** (`moCaiDat()`) / **Không, cảm ơn**. Quay lại app thì đọc `coQuyen()` để hiện
  trạng thái đúng.
- **Thẻ ở Sổ giao dịch:** *"Có {N} biến động chưa ghi"* → mở trung tâm thông báo đã lọc nhóm `bienDong`. Đứng cạnh thẻ C1.
  Hai thẻ cùng có thì đứng liền nhau.

## 4. Không làm

Không tự tạo giao dịch. Không gửi tin ra ngoài máy. Không `READ_SMS` / `RECEIVE_SMS`. Không iOS. Không mở `provider` /
`bank_tran_id` qua đồng bộ. Không dùng mô hình để đọc tin.

## 5. Giới hạn nói trước

- Chỉ đọc được thông báo **hiện ra**: app ngân hàng tắt thông báo, hoặc máy tắt dịch vụ nền (Realme force-stop khi vuốt
  Recents), thì mất tin.
- Khuôn tin ngân hàng đổi theo phiên bản app, nên bộ đọc phải cập nhật. Tin không khớp khuôn thì im (không báo sai).
- Tầng Kotlin không test được trong `flutter test`.

## 6. Kiểm thử

- **Task 1 (thu mẫu, trên máy thật, cùng người dùng):** bật dịch vụ bản debug ghi nguyên văn ra logcat **chỉ trên máy
  của người dùng**; người dùng tự chép mẫu, **che số tài khoản, tên, mã giao dịch** rồi mới đưa vào test. Không commit
  dữ liệu thật.
- **`docTinBienDong`:** mỗi nguồn ≥ 2 mẫu (một thu, một chi); mẫu `Classify.md` §4; tin OTP → không bao giờ tới đây (đã lọc
  ở Kotlin) nhưng hàm vẫn trả `null` nếu gặp; tin quảng cáo có số → `null`.
- **Nhập hàng chờ:** gộp trùng theo mã; theo số tiền + chiều trong 5 phút *(⚠️ 2026-09-30: trừ khi hai tin mang số dư sau GD khác nhau — đo Realme, hai lần chuyển thật cách 4 phút từng bị gộp; `BIEN_DONG_SO_DU_FEATURE.md` mục 3)*; cách 6 phút → hai dòng; tệp hỏng một dòng →
  các dòng khác vẫn nhập; tệp bị xoá sau khi nhập; tài khoản khác đăng nhập (hàng chờ gắn máy, không gắn tài khoản) →
  nhập vào tài khoản **đang đăng nhập** (tin hiện trên máy của người đang cầm máy).
- **`NotificationKind` / nhóm:** hai `switch`, `tatCaUngVien()`, chip lọc.
- **Form:** query đủ → ô đúng; ví theo nguồn ở lần hai; nhắc trùng; Lưu / Bỏ qua xoá hàng loại 20.
- **Màn đồng ý + Cài đặt:** công tắc lần đầu → màn đồng ý; *Không, cảm ơn* → công tắc tắt; quyền đã có → không hỏi lại.
- **Máy thật (Realme):** cài bản debug, bật quyền, nhận một tin thật (chuyển 1.000 đ giữa hai tài khoản của người dùng) →
  tóm tắt hiện → chạm → form điền đúng → Lưu → dòng biến mất; logcat không in nội dung tin ở bản release.

## 7. Tài liệu đi kèm

Tài liệu tính năng mới (`docs/BIEN_DONG_SO_DU_FEATURE.md`): luồng §1, danh sách trắng + gói thật, khuôn từng nguồn,
giới hạn. `NOTIFICATION_FEATURE.md`: loại 20, nhóm mới, ngoại lệ xoá cứng. `CLAUDE.md` hàng *Đụng vào thông báo* và một
hàng mới *Đụng vào đọc biến động số dư*. Khi xong: báo backend để đổi ô chức năng 3 (đơn cũ mục 5 câu 5).
