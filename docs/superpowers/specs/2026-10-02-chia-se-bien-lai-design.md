# Chia sẻ biên lai từ app ngân hàng vào FlowMoney — thiết kế

**Ngày:** 2026-10-02. **Trạng thái:** ✅ **xong trọn 11 task** — mã Task 1–10 (`86b7b91` → `ebfb9d98`), nghiệm thu Realme
với biên lai MB Bank thật cùng tối; Task 11 ngày 2026-10-03 (debug + **release** trên Realme, mục 7.7
`BIEN_DONG_SO_DU_FEATURE.md`; lượt ấy lộ bản release gãy ở R8 từ 01/10 → `android/app/proguard-rules.pro`). Ba màn
Stitch người dùng xác nhận (`805cd430…`, `c0597919…`, `55431838…`). ⏳ Còn mở: mẫu riêng MoMo / ZaloPay khi có biên lai
thật. **Mục 10 "đo dung lượng có / không có gói"**: đo thẳng phần gói trong APK release (11,06 MB thư viện arm64 + 1,49 MB
mô hình), không dựng bản không có gói. Thiết kế
duyệt trong chat (năm lượt AskUserQuestion + một lượt duyệt tổng), bản viết người dùng duyệt cùng ngày (*"Ok duyệt"*).
Kế hoạch 11 task: `docs/superpowers/plans/2026-10-02-chia-se-bien-lai.md` (gitignore, nhật ký thi công ở cuối). Hiện
trạng và bảng nghiệm thu: mục **7** `docs/BIEN_DONG_SO_DU_FEATURE.md`.

> **Bốn chỗ bản thi công KHÁC bản viết dưới đây** (bản thi công thắng):
> 1. **Mục 5 — mới có mẫu riêng cho MB Bank.** Bước thử chỉ thu được biên lai MB; người dùng chọn *làm tiếp, MoMo và
>    ZaloPay dùng luật chung*, mẫu riêng bổ sung khi có biên lai thật. Biên lai MB **không có nhãn** — mẫu đọc theo vị
>    trí; hàng chữ liền số là tài khoản người nhận (người dùng xác nhận), không phải mã giao dịch.
> 2. **Mục 6 — chia sẻ lặp nhận ra bằng giờ in trên biên lai (`blt`), không bằng cửa sổ 5 phút.** Cửa sổ 5 phút gộp
>    luôn hai lần chuyển cùng số tiền cách vài phút — mất khoản sau, im lặng. 5 phút chỉ còn dùng để ghép biên lai với
>    **tin ngân hàng** của cùng giao dịch.
> 3. **Mục 4.2 — hàng tin được gắn ảnh KHÔNG mang `doc`.** `doc` có mặt ⇔ số liệu của hàng đọc từ ảnh; hàng tin chỉ
>    thêm `anh` + `blt`, form vẫn nói *"Từ thông báo…"*.
> 4. **Mục 4 — thêm tệp `core/notification/ten_tep_bien_lai.dart`** (hằng + `tenTepBienLaiHopLe`, Dart thuần) để tầng
>    domain của form không kéo theo Drift.

Việc sau D1 số 3 (`docs/BIEN_DONG_SO_DU_FEATURE.md` mục 6), nay tách khỏi C4 và làm trước. Bản thiết kế thứ hai của
cùng lượt — *nhắc ghi sau khi rời app ngân hàng* — viết riêng, sau bản này (mục 11).

## 1. Vì sao

D1 chỉ đọc **thông báo đã hiện trên máy**. Người dùng báo 2026-10-02: chuyển khoản ngay trong app ngân hàng thì app
ấy **không đăng thông báo biến động**, nên FlowMoney không có gì để đọc — gặp ở MB Bank và MoMo / ZaloPay. Đã biết từ
30/09: MoMo / ZaloPay không bắn tin khi chuyển tiền đi; MB Bank lúc có lúc không (OnePlus 30/09 không có tin, Realme
30/09 có).

Android không cho một app nhìn vào màn hình hay dữ liệu của app khác. Hai lối tự động hoàn toàn đều bị loại: quyền
Trợ năng (đọc được cả số dư, OTP — và là thứ app ngân hàng dè chừng) và liên kết ngân hàng qua server (nhóm bỏ
2026-09-18). Còn lại là để **người dùng tự đưa biên lai** cho FlowMoney bằng nút *Chia sẻ* sẵn có trên màn *"Giao dịch
thành công"*.

## 2. Quyết định người dùng đã chốt

| # | Quyết định | Ghi chú |
|---|---|---|
| 1 | Chia sẻ qua FlowMoney thì **không nhảy sang FlowMoney** — nhận ở nền, hiện thông báo, người dùng chạm khi rảnh | để còn chuyển tiếp trong app ngân hàng |
| 2 | Thông báo **không nêu số tiền**, gộp chung với tóm tắt của D1: *"Có N biến động số dư mới — chạm để ghi"*; kèm dòng chữ thoáng qua *"FlowMoney đã nhận biên lai"* | cùng quy ước D1 |
| 3 | Ảnh **không đọc ra số tiền** vẫn giữ làm khoản chờ ghi: form mở với số tiền trống + ảnh để nhìn mà gõ | không khoản nào rơi |
| 4 | Ảnh **xoá sau khi Lưu hoặc Bỏ qua**; không đính kèm vào giao dịch | |
| 5 | App chưa có mẫu đo: **thử đọc theo luật chung**, form ghi *"Đọc từ ảnh — hãy kiểm lại"*, luôn kèm ảnh | MB Bank · MoMo · ZaloPay có mẫu riêng |
| 6 | Đọc chữ trên ảnh **khi FlowMoney mở**, không phải lúc chia sẻ | lúc chia sẻ hai lối cho ra thứ nhìn thấy y hệt |
| 7 | Gói `google_mlkit_text_recognition` thành **phụ thuộc chính thức** | ba gói spike C4 còn lại vẫn là gói tạm |

Bất biến ④ của nhóm C giữ nguyên: FlowMoney **điền sẵn**, người dùng bấm Lưu.

## 3. Người dùng thấy gì

1. Màn *"Giao dịch thành công"* của app ngân hàng / ví → *Chia sẻ* → mục **"Ghi vào FlowMoney"** trong bảng chia sẻ.
2. Vẫn đứng ở app ngân hàng. Dòng chữ thoáng qua *"FlowMoney đã nhận biên lai"*; thông báo tóm tắt *"Có N biến động số
   dư mới — chạm để ghi"* — N đếm cả tin ngân hàng D1 đang chờ lẫn biên lai đang chờ.
3. Chạm thông báo, hoặc thẻ *"Có N biến động chưa ghi"* ở Sổ giao dịch → trung tâm thông báo lọc sẵn nhóm *Biến động*.
4. Chạm một dòng → form Thêm giao dịch điền sẵn, đầu form có **dải nguồn kèm ảnh biên lai nhỏ** (*"Từ biên lai MB Bank ·
   02/10 18:45"*; chạm ảnh để xem to). Đọc theo luật chung thì thêm dòng *"Đọc từ ảnh — hãy kiểm lại"*.
5. **Lưu** hoặc **Bỏ qua** → dòng biến mất, ảnh bị xoá.
6. Ảnh không đọc ra số tiền → dòng *"Biên lai chưa đọc được · ‹nguồn›"*; form mở với số tiền trống, 16 phím số hiện sẵn,
   ảnh ở đầu form.

Các trạng thái khác:

| Tình huống | Thứ hiện ra |
|---|---|
| Máy chưa có tài khoản đăng nhập | dòng chữ *"Đăng nhập FlowMoney để ghi biên lai"*; không giữ ảnh |
| Thứ được chia sẻ không phải ảnh, hoặc không mở được | dòng chữ *"FlowMoney chỉ nhận ảnh biên lai"*; không giữ gì |
| Biên lai và tin ngân hàng của cùng một giao dịch | **một** dòng chờ ghi (mục 6) |
| Người dùng đã tự ghi khoản ấy trước đó | nhắc *"có thể bạn đã ghi khoản này"* sẵn có của D1 |

Không cần bật công tắc *Đọc biến động số dư* và không qua màn xin đồng ý của D1: việc chia sẻ do người dùng chủ động
làm cho từng ảnh.

## 4. Kiến trúc

```
App ngân hàng: Chia sẻ → "Ghi vào FlowMoney"
  → NhanBienLaiActivity (Kotlin, không giao diện)
      cờ SharedPreferences("bien_dong").co_phien ? → EXTRA_STREAM là ảnh mở được ?
      → chép vào files/bien_lai/<uuid>.<đuôi> → nối {tep, goi, luc} vào files/bien_lai_cho.jsonl
      → Toast → thông báo tóm tắt (ID 20260930, đếm cả hai hàng chờ) → finish()
  → NotificationScanner.start / resumed → NhapBienDong.nhap → NhapBienLai.nhap(idaccount)      (Dart)
      rename .dang_nhap → mỗi dòng: DocChuAnh.doc(tệp) → ghepDongTheoHang → docBienLai
      → gộp trùng với hàng loại 20 đã có và với nhau → AppNotifications loại 20 (deeplink /add?…&anh=…&doc=…)
      → dọn ảnh mồ côi → huyTomTat()
  → trung tâm thông báo → /add?… → dienSanBienDongTuQuery (thêm anh, doc) → form có dải nguồn + ảnh
      → Lưu / Bỏ qua → NotificationDao.xoaCung + xoá tệp ảnh
```

| Tệp | Vai |
|---|---|
| `android/…/NhanBienLaiActivity.kt` (mới) | nhận `ACTION_SEND` `image/*`, chép ảnh, ghi hàng chờ, Toast, tóm tắt; **không** đọc chữ, **không** mở `MainActivity` |
| `android/…/BienDongListenerService.kt` | tách `baoTomTat` + phép đếm ra chỗ dùng chung; đếm cả hai hàng chờ |
| `android/…/MainActivity.kt` | kênh `flowmoney/bien_dong` thêm `datCoPhien(bool)` |
| `AndroidManifest.xml` | khai `NhanBienLaiActivity` (mục 4.1) |
| `lib/core/ocr/dong_ocr.dart` (mới) | `DongOcr` + `ghepDongTheoHang` — **dời** từ `ai_chat/spike/spike_c4.dart`, spike import lại |
| `lib/core/ocr/doc_chu_anh.dart` (mới) | giao diện thuần `DocChuAnh.doc(duongDan) → List<DongOcr>`; bản thật `doc_chu_anh_mlkit.dart` là tệp DUY NHẤT ngoài spike được import gói ML Kit |
| `lib/features/transaction/domain/doc_bien_lai.dart` (mới) | hàm thuần: chữ trên biên lai → `BienLaiDoc` (mục 5) |
| `lib/core/notification/nhap_bien_lai.dart` (mới) | nhập hàng chờ biên lai, gộp trùng, dọn ảnh |
| `lib/core/notification/kho_bien_lai.dart` (mới) | thư mục ảnh: xoá một tệp, dọn mồ côi, dọn quá hạn, xoá hết |
| `lib/core/notification/nhap_bien_dong.dart` | `deeplinkBienDong` nhận thêm `anh`, `doc`; hàng không số tiền |
| `lib/features/transaction/domain/dien_san_bien_dong.dart` | `DienSanBienDong.anh`, `.cachDoc`; `dongNguonBienDong` nói *"Từ biên lai …"* |
| `lib/features/transaction/presentation/pages/add_transaction_page.dart` | dải nguồn có ảnh; Lưu / Bỏ qua xoá ảnh |
| `lib/features/transaction/presentation/widgets/xem_anh_bien_lai.dart` (mới) | xem ảnh to |

### 4.1. Phần Android gốc

- `NhanBienLaiActivity`: `android:label="Ghi vào FlowMoney"`, `exported="true"`, `excludeFromRecents="true"`,
  `noHistory="true"`, `taskAffinity=""`, theme không giao diện (`Theme.NoDisplay`; nếu bước thử mục 9 cho thấy ColorOS
  vẫn chớp màn thì đổi `Theme.Translucent.NoTitleBar`). Một `intent-filter`: `ACTION_SEND` + `category.DEFAULT` +
  `mimeType="image/*"`. Không `SEND_MULTIPLE`.
- Mọi việc làm **trong `onCreate` rồi `finish()` ngay**: quyền đọc `content://` của ảnh gắn với vòng đời activity nhận,
  nên phải chép xong trước khi đóng. Ảnh biên lai vài trăm KB — chép đồng bộ.
- Trần kích thước **12 MB** mỗi ảnh và **20** biên lai đang chờ; vượt thì Toast *"FlowMoney chỉ nhận ảnh biên lai"* /
  *"Còn nhiều biên lai chưa ghi — mở FlowMoney để ghi bớt"* và không giữ.
- `goi` = gói của app gửi, lấy từ `Activity.getReferrer()` (`android-app://<gói>`); không lấy được thì chuỗi rỗng.
- Cờ `co_phien` (cùng `SharedPreferences("bien_dong")` với cờ `bat` của D1): Dart ghi `true` ở
  `NotificationScanner.start`, `false` ở `stop`. Cờ gắn **máy** nên phải ghi lại ở mỗi lượt nhập, cùng nếp `datBat`.
- Thông báo tóm tắt: **cùng** ID, kênh, câu chữ với D1; N = số dòng của `bien_dong_cho.jsonl` + `bien_lai_cho.jsonl`.
  Phép đếm và hàm dựng thông báo có **một** định nghĩa dùng cho cả dịch vụ nghe thông báo lẫn activity này.
- ⚠️ `AndroidManifest.xml` là vùng mù của `flutter test` / `analyze` / `build` — một ca test đọc thẳng manifest canh
  activity, action, mimeType, `exported` (khuôn `bien_dong_noi_day_test`).

### 4.2. Hợp đồng dữ liệu

- Dòng hàng chờ: `{"tep":"<uuid>.<đuôi>","goi":"<gói | rỗng>","luc":<mili giây epoch>}`. Ảnh ở `files/bien_lai/`.
- Hàng `AppNotifications` loại 20 (`bienDongSoDu`) — **không loại mới**, để trung tâm thông báo, thẻ Sổ giao dịch, công
  tắc nhóm và đường xoá cứng dùng nguyên:
  - đọc ra số tiền: `dedupeKey` = `dedupeKeyBienDong(t)` (cùng hàm với tin ngân hàng — nhờ thế biên lai và tin của
    cùng giao dịch có mã GD trùng khoá ngay ở `insertAllIfAbsent`); tiêu đề `−150.000 đ · MB Bank`;
  - không đọc ra: `dedupeKey` = `bienDong:bienLai|<tep>`; tiêu đề `Biên lai chưa đọc được · ‹nguồn›`.
- `deeplink` = query của D1 + `anh=<tep>` + `doc=mau | chung | khong`. `amount` vắng khi không đọc ra.
- Nguồn hiển thị: gói thuộc `kNguonTheoGoi` → tên nguồn của D1 (nhớ ví theo nguồn dùng chung); gói khác hoặc rỗng →
  `kNguonBienLai = 'Biên lai'`.

## 5. Bộ đọc biên lai (`docBienLai`)

Hàm thuần: `docBienLai({required String vanBan, required String? nguon, required DateTime luc}) → BienLaiDoc` với
`soTien?`, `chieu`, `thoiGian`, `maGiaoDich?`, `noiDung`, `duoiTaiKhoan?`, `cachDoc`. `vanBan` là đầu ra của
`ghepDongTheoHang` (mỗi hàng của ảnh một dòng chữ — ML Kit trả theo cột, phải ghép theo khung).

- **Mẫu riêng** cho MB Bank, MoMo, ZaloPay — viết từ **biên lai thật** thu ở bước thử (mục 9), theo nếp *"không đoán"*
  của D1. `cachDoc = mau`.
- **Luật chung** cho mọi nguồn khác, và cho ba nguồn trên khi mẫu riêng không khớp. `cachDoc = chung`:
  - số tiền: số trên dòng mang nhãn *số tiền · amount · tổng tiền*; không có nhãn thì số có đơn vị `đ / ₫ / VND` lớn
    nhất; bỏ chuỗi trông như số tài khoản / mã (không ngăn nghìn, từ 9 chữ số; bắt đầu bằng 0) — dùng lại phép lọc của
    `spike_c4.dart`;
  - thời gian: `dd/MM/yyyy` kèm `HH:mm` trên ảnh; không có thì `luc` (lúc chia sẻ);
  - mã giao dịch: sau nhãn *mã giao dịch · mã GD · số tham chiếu · mã tham chiếu*;
  - nội dung: sau nhãn *nội dung · lời nhắn · diễn giải*; không có thì rỗng.
- **Chiều:** mặc định `chi` (biên lai của khoản người dùng vừa chuyển). `thu` chỉ khi mẫu riêng nhận ra biên lai nhận
  tiền.
- Không ra số tiền → `soTien = null`, `cachDoc = khong`; các trường khác vẫn điền nếu đọc được.
- Số tiền đi qua cùng trần 13 chữ số của form (`kSoChuSoToiDaSoTien`).

Danh mục, ví, gợi ý chuyển khoản **không** làm ở đây: form dùng lại `ketQuaTuBienDong`, `ViTheoNguonStore`,
`goi_y_chuyen_khoan.dart` của D1 trên chính `noiDung` và `nguon`.

## 6. Gộp trùng

Dùng **một** phép `trungBienDong` của D1: cùng mã GD; hoặc không đủ mã thì cùng số tiền + chiều trong 5 phút (vân tay
số dư không áp dụng — biên lai không mang số dư).

- Biên lai trùng một hàng loại 20 **đã có** (tin ngân hàng đến trước) → không ghi hàng mới; hàng đã có được **gắn thêm
  ảnh** (ghi lại `deeplink` có `anh=`), để form có ảnh đối chiếu.
- Hai biên lai của cùng một giao dịch (chia sẻ hai lần) → một hàng.
- Tin ngân hàng đến **sau** biên lai: `NhapBienDong._ghi` vốn đã so với mọi hàng loại 20 → tin bị bỏ, hàng biên lai giữ.
- Biên lai không đọc ra số tiền không gộp với gì cả.

## 7. Ảnh và riêng tư

- Ảnh nằm trong vùng riêng của app (`files/bien_lai/`), không vào thư viện ảnh, không đi đâu ra khỏi máy. Đọc chữ bằng
  ML Kit **trên máy**.
- **Một luật:** ảnh sống khi còn một hàng loại 20 hoặc một dòng hàng chờ trỏ tới nó. Xoá ngay ở Lưu / Bỏ qua; mỗi lượt
  nhập có một bước **dọn mồ côi** làm lưới an toàn (vuốt xoá hàng ở trung tâm thông báo, app chết giữa chừng).
- Ảnh chờ quá **30 ngày** → xoá cả ảnh lẫn hàng.
- **Đăng xuất** (`NotificationScanner.stop`): `datCoPhien(false)`, xoá hàng chờ biên lai, xoá mọi ảnh, xoá cứng các hàng
  loại 20 mang `anh=`. Lý do: hàng chờ gắn máy; người đăng nhập sau không được thấy biên lai của người trước.
- Chế độ thu mẫu chỉ ở bản **debug**, chỉ in **hình dạng đã che** của chữ trên biên lai (chữ số → `9`, từ ngoài danh
  sách cấu trúc → `…`), tag `BienLaiThu` — quy tắc §13.6 `progress/Client-app.md`. Bản release không in gì.
- Không thêm trường đồng bộ, không đổi schema. Phía backend: một **thông báo** trong
  `docs/superpowers/backend/CAN-LAM/CLIENT_CHIA_SE_BIEN_LAI.md` (không xin đổi mã), theo tiền lệ
  `DA-XONG/CLIENT_DOC_BIEN_DONG_THEM_VI_DIEN_TU.md`.

## 8. Giao diện

Chưa có trong Stitch — vẽ và chờ người dùng xác nhận trước khi dựng:

1. Form Thêm giao dịch mở từ biên lai: dải nguồn có ảnh nhỏ + dòng *"Đọc từ ảnh — hãy kiểm lại"*.
2. Cùng form ở trạng thái *chưa đọc được* (số tiền trống, 16 phím hiện).
3. Xem ảnh biên lai to.

Dòng trong trung tâm thông báo dùng nguyên ô của loại 20. Thử bố cục ở 360 dp với ảnh dọc dài (biên lai thường cao
gấp đôi rộng).

## 9. Thứ tự làm và cổng dừng

1. **Bước thử trên Realme — cổng dừng.** Bản debug có `NhanBienLaiActivity` tối thiểu + chế độ thu mẫu. Người dùng chia
   sẻ một biên lai thật từ MB Bank, MoMo, ZaloPay. Phải trả lời được:
   - mỗi app đưa ra thứ gì (`image/*`? kèm chữ? PDF?) và `getReferrer()` có ra tên gói không;
   - activity không giao diện có thật sự **không kéo FlowMoney lên** và Toast có hiện trên ColorOS không;
   - FlowMoney có xuất hiện trong bảng chia sẻ của từng app không (app tự vẽ bảng chia sẻ riêng thì không);
   - hình dạng đã che của chữ trên từng biên lai, đủ để viết mẫu.

   Một app không chia sẻ ra ảnh, hoặc không cho chọn FlowMoney → **dừng, báo người dùng** trước khi làm tiếp.
2. Vẽ ba màn ở mục 8 trên Stitch, người dùng xác nhận.
3. `core/ocr` (dời `DongOcr` / `ghepDongTheoHang`, giao diện `DocChuAnh`) → `docBienLai` → `KhoBienLai` →
   `NhapBienLai` → phần Android gốc đầy đủ → form → dọn khi đăng xuất.
4. Đo dung lượng APK release có / không có gói ML Kit, báo con số.
5. Nghiệm thu máy thật (mục 10), tài liệu, thông báo cho backend.

## 10. Kiểm thử

- Thuần (Dart): `docBienLai` (ba mẫu riêng từ chữ thật đã che → dựng lại, luật chung, không đọc ra, số tài khoản không
  thành số tiền, trần 13 chữ số) · `ghepDongTheoHang` (ca cũ dời theo) · `NhapBienLai` với `DocChuAnh` giả (gộp trùng
  ba chiều của mục 6, hàng không số tiền, dọn mồ côi, quá 30 ngày, không ném khi tệp hỏng) · `KhoBienLai` ·
  `dienSanBienDongTuQuery` với `anh` / `doc` · `dongNguonBienDong`.
- Widget: form có ảnh ở 360 × 800 và 360 × 640 (đo **vị trí**, không chỉ `find`), trạng thái chưa đọc được, Lưu / Bỏ
  qua xoá ảnh, xem ảnh to. Một ca dựng bằng `AppTheme.lightTheme`.
- Nối dây: ca đọc `AndroidManifest.xml` · ca quét `lib/` — chỉ `doc_chu_anh_mlkit.dart` (và màn spike C4, tới khi spike
  gỡ) import gói ML Kit · hằng tên tệp hàng chờ Dart ↔ Kotlin khớp (đọc tệp Kotlin, khuôn `bien_dong_noi_day_test`).
- Máy thật (Realme, bản debug rồi release): chia sẻ từ ba app → vẫn ở app ngân hàng → Toast → tóm tắt đếm đúng → mở
  FlowMoney → dòng đúng số tiền / giờ / nguồn → form có ảnh → Lưu → ảnh mất khỏi `files/bien_lai/` · ảnh không phải
  biên lai → *chưa đọc được* · chia sẻ hai lần → một dòng · chưa đăng nhập → từ chối · đăng xuất → thư mục rỗng ·
  app đang bị ColorOS đóng băng / đã bị vuốt khỏi Recents → vẫn nhận.

## 11. Không làm trong bản này

- **Nhắc ghi sau khi rời app ngân hàng** — bản thiết kế riêng: `2026-10-03-nhac-ghi-sau-app-ngan-hang-design.md`
  (duyệt 2026-10-03); cần thử trước quyền *Truy cập dữ liệu sử dụng*
  và việc ColorOS đóng băng app nền có cho nhắc đúng lúc không.
- Đính kèm ảnh vào giao dịch · PDF · nhiều ảnh một lần · chụp ảnh từ trong FlowMoney (C4) · iOS.
- Tự lưu không cần bấm (bất biến ④).
- Đọc tin nhắn SMS Banking, đo thêm nguồn thông báo (Vietcombank, Techcombank, BIDV) — việc sau D1 số 4, không đổi.

## 12. Rủi ro đã biết

- **App ngân hàng không chia sẻ ra ảnh, hoặc tự vẽ bảng chia sẻ chỉ có vài app** — khi ấy tính năng không dùng được
  với app đó. Bước thử mục 9 sinh ra để biết điều này trước khi viết phần còn lại.
- **Màn không giao diện trên ColorOS** có thể vẫn chớp hoặc kéo task FlowMoney lên — có phương án theme trong suốt;
  nếu cả hai đều kéo app lên thì quyết định 1 không giữ được, phải báo người dùng.
- **Luật chung đọc sai số tiền** (lấy phí, số dư, số tiền bằng chữ) — vì thế form luôn kèm ảnh và dòng *"hãy kiểm
  lại"*; ba nguồn dùng nhiều nhất có mẫu riêng.
- **Mẫu riêng vỡ khi app ngân hàng đổi giao diện biên lai** — rơi về luật chung, không rơi về "không đọc".
- **ML Kit đọc sai dấu tiếng Việt** ở nội dung chuyển khoản — nội dung chỉ dùng để đoán danh mục và làm ghi chú, người
  dùng sửa được trước khi Lưu.
- **Dung lượng APK tăng** vì gói ML Kit — đo và báo ở bước 4 mục 9.
