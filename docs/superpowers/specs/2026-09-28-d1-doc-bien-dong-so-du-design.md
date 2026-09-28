# D1 — Đọc biến động số dư trên máy để điền sẵn giao dịch — thiết kế (Phần 2)

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
  Google) phải **đo trên máy** ở Task 1, không đoán.
- **Bộ lọc thô** (không trích số): bỏ tin chứa *OTP* / *mã xác thực* / *ma xac thuc* (không phân biệt hoa thường); giữ
  tin có `[+-]\s?\d[\d.,]*`. Đây là bộ **lọc**; mọi phép **đọc** ở Dart, nên chỉ có một định nghĩa của *"số tiền trong
  tin"*.
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
  điền của C2 (`_dienTuKetQua`). Số tiền, chiều, ngày (giữ giờ trong tin), ghi chú = nội dung.
- **Ví chọn sẵn:** bảng cục bộ *"nguồn + đuôi tài khoản → walletId"* lưu bằng `flutter_secure_storage`, khoá theo tài
  khoản (`bien_dong_vi:<idaccount>`), cùng khuôn `SecureStorageNotificationPrefsStore`. Ghi ở lần **Lưu** đầu tiên của mỗi
  cặp; lần sau chọn sẵn. Ví đã lưu trữ / đã xoá thì bỏ qua (dùng `getActive`).
- **Danh mục:** bộ đoán của B1 trên ghi chú (qua C2).
- **Nhắc trùng:** sổ đã có khoản cùng số tiền, cùng chiều, cùng ngày → dòng *"Có thể bạn đã ghi khoản này"*. Người dùng
  tự quyết, không chặn.
- **Lưu** → giao dịch đi đường nhập tay (`provider = 'Manual'`, payload 13 trường), rồi xoá hàng loại 20 tương ứng.
  **Bỏ qua** (nút trên form khi mở từ loại 20, hoặc vuốt ở trung tâm thông báo) → cũng xoá hàng ấy.
  ⚠️ Xoá **cứng** hàng loại 20 là ngoại lệ có chủ ý của nếp *"dismiss mềm để giữ khoá trùng"*: tin đã xử lý thì không còn
  lý do giữ nội dung ngân hàng (Nghị định 13, tối thiểu hoá). Chống trùng về sau dựa vào bước 3 của 3.2 trong cửa sổ 5
  phút, đủ vì nguồn chỉ bắn lại ngay lập tức.
- **30 ngày:** lượt dọn của scanner xoá hàng loại 20 cũ hơn 30 ngày (khác mốc 90 ngày của thông báo thường).

### 3.4 Nhóm thông báo và công tắc

- Loại 20 thuộc một **nhóm mới** `bienDong` (chip lọc mới ở trung tâm thông báo; test *"mỗi nhóm có đúng một chip"* sẽ đòi
  điều ấy). Công tắc nhóm **chính là** công tắc tính năng: tắt thì Kotlin thôi đọc (qua kênh).
- **Màn xin đồng ý** (bắt buộc): bật công tắc lần đầu → màn nêu (1) mục đích, (2) **danh sách trắng đủ bảy nguồn**, (3) lọc
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
- **Nhập hàng chờ:** gộp trùng theo mã; theo số tiền + chiều trong 5 phút; cách 6 phút → hai dòng; tệp hỏng một dòng →
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
