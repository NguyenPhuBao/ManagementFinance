# Phạm vi thời gian cho trang Phân tích — thiết kế

> ⚠️ **Đọc kèm, 2026-09-18 — spec này cố ý để trang Xuất báo cáo ngoài phạm vi,
> và ranh giới ấy nay đã bỏ.** Mục "Không làm" bên dưới ghi rằng bốn phạm vi
> riêng của trang Xuất báo cáo (`thangNay` / `thangTruoc` / `quyNay` /
> `tuyChinh`) là **bố cục khác**, nên giữ nguyên. Ngày 2026-09-18 trang ấy
> chuyển hẳn sang `Ky` và dùng chung `moChonPhamVi`; **`PhamViThoiGian` và
> `khoangCuaPhamVi` đã bỏ khỏi mã**. Mọi câu dưới đây nhắc hai tên ấy như thứ
> đang tồn tại là ảnh chụp của ngày 2026-09-15. Xem mục **3.33**
> `docs/ANALYTICS_FEATURE.md`.
>
> Cùng lượt ấy, `nhanOChon` có thêm một hàm anh em là **`nhanRong`** cho những
> chỗ không chật — spec này chỉ mô tả `nhanOChon` vì khi ấy chỉ có ô header hẹp
> cần nó.

> ⚠️ **Đọc kèm, 2026-09-16 — bản thi công của spec này mang một lỗi, nay đã
> đóng.** Chip **Tuỳ chọn** mở `showDateRangePicker` với khoảng khởi tạo là **kỳ
> đang xem**, trong khi `lastDate` là **hôm nay** — nên từ *Tuần này · Tháng này
> · Quý này · Năm nay*, tức **trạng thái mặc định** của trang, nó ném assertion.
> Và vì đó là exception trong một hàm `async` **không ai bắt**, nút chỉ đơn giản
> **không làm gì**: không toast, không màn đỏ, chỉ một dòng logcat. Nó sống qua
> cả lượt nghiệm thu máy ảo ngày 2026-09-15 vì không ai chạm vào nút ấy — và bộ
> test **10** ca của bộ chọn cũng không ca nào chạm. Phép kẹp nay là hàm thuần
> `khoangKhoiTaoBoChonNgay`; bốn ca widget mới chạm **thật** và đòi
> `DateRangePickerDialog` hiện ra. Chi tiết: **G43**
> `docs/CLIENT_APP_KNOWN_GAPS.md`, bẫy **4.22** `docs/ANALYTICS_FEATURE.md`.

> Ngày 2026-09-15. Trạng thái: ✅ **ĐÃ THI CÔNG XONG** cùng ngày — 6 commit,
> nghiệm thu máy ảo bảy điểm. Việc **P1** của
> `docs/superpowers/plans/2026-09-15-ke-hoach.md`; bàn giao ở mục **3.20**
> `docs/ANALYTICS_FEATURE.md`, kế hoạch thi công ở
> `plans/2026-09-15-p1-pham-vi-thoi-gian-phan-tich.md`.
>
> ✅ **HẾT HIỆU LỰC 2026-09-21** — luật `docs/superpowers/specs/` đã bỏ khỏi
> `.gitignore` và tệp này nay đi theo repo. ⚠️ Câu cũ ở đây còn dặn *"đừng
> `git add -f` để sửa điều đó"* — hoá ra chính quy ước ấy mới là chỗ sai:
> **13/24 spec đã phải `add -f`**, và hai spec mà `CLAUDE.md` gọi là "đã duyệt"
> thì chỉ tồn tại trên một máy. Một luật mà người ta phải phá đều đặn là một
> luật sai.

---

## 1. Vấn đề

Trang Phân tích chỉ xem được **theo tháng**. Bộ chọn ở header dựng từ
`cacThangGanNhat(now)` — 12 tháng gần nhất — và toàn bộ tầng dưới khoá cứng theo
cặp `(nam, thang)`: `ThongKeThang`, `AnalyticsRepository.watchThang`,
`AnalyticsLoading(nam, thang)`, `AnalyticsCubit.chonThang`.

Ba hệ quả đo được:

1. **Người dùng không xem được tuần, quý, năm hay một khoảng tuỳ ý**, dù trang
   Xuất báo cáo — cùng dữ liệu, cùng tầng domain — đã làm được từ 2026-09-09.
   Money Lover, MISA và Copilot đều cho đổi phạm vi ngay trên màn thống kê.
2. ~~**Thông báo Tổng kết tuần bị chặn.**~~ ⚠️ **SAI, rút lại 2026-09-15.** Bản
   đầu của spec này đọc dòng 89–93 của
   `2026-09-07-weekly-summary-notification-design.md` rồi kết luận P1 gỡ chặn
   cho nó. Thực ra thông báo ấy **làm xong từ 2026-09-09** (mục 5d
   `NOTIFICATION_FEATURE.md`); dòng 89–93 là ghi chú **2026-09-08**, và khối
   "✅ Đã đủ — cập nhật 2026-09-09" nằm ngay dưới nó, ghi rằng điều kiện đóng
   bằng phạm vi tuỳ chỉnh của trang Xuất báo cáo. Giữ mục này để không ai đi lại
   đường ấy.
3. Mọi khối thống kê thêm về sau đều thừa hưởng giới hạn này.

Điều **không** phải vấn đề: phép tính. `tongThuChi(ds, from:, to:)` đã nhận biên
bất kỳ từ đầu, và `bao_cao_xuat.dart` đã có `khoangCuaPhamVi` (quý, khoảng tuỳ
chọn) lẫn `khoangKyTruoc` (kỳ liền trước của một khoảng bất kỳ). Việc của P1 là
**mở đường cho giao diện dùng những phép ấy**, không phải viết phép mới.

---

## 2. Ba quyết định của người dùng

Hỏi và chốt ngày 2026-09-15, trước khi viết dòng mã đầu tiên:

| | Chọn | Vì sao |
|---|---|---|
| Bộ chọn đặt ở đâu | **Bottom sheet hai tầng** | Header đã chật: chú thích ở `analytics_page.dart:159` ghi nó từng tràn 53px ở 411dp và phải chỉnh tỉ lệ flex 2:3 mới vừa. Thêm hàng chip vào hàng ấy là vỡ lại |
| Khối Xu hướng khi đổi đơn vị | **Đi theo đơn vị** — 6 tuần / 6 tháng / 6 quý / 6 năm | Xem một tuần mà biểu đồ vẫn vẽ nửa năm thì hai khối trên cùng trang nói về hai kỳ khác nhau |
| Giao diện mới lên Stitch | **Tạo màn mới trên Stitch trước khi code** | Nếp dự án. Xem mục 10.4 về cách nghiệm thu. ✅ Màn ấy là **`83993fc9f5de4c5f8fba6940480c164a`** *"Thống kê - Chọn phạm vi thời gian"*, người dùng xác nhận 2026-09-15 — dù lượt gọi trả về `timeout` và hơn một tiếng sau mới hiện |

Phương án bị loại: giữ `(nam, thang)` bên trong rồi bọc một lớp `Ky` bên ngoài —
không chạy được, vì repository buộc phải nhận biên bất kỳ; lớp bọc chỉ giấu việc
chứ không làm được việc.

---

## 3. Mô hình `Ky` — `analytics/domain/pham_vi_ky.dart`

Tệp mới, **định nghĩa duy nhất** của khái niệm "kỳ" ở tầng Phân tích.

```dart
enum DonViKy { tuan, thang, quy, nam, tuyChon }

class Ky {
  final DonViKy donVi;
  final DateTime from;  // đóng
  final DateTime to;    // MỞ — cùng quy ước với tongThuChi, getExpenses, tuanTruoc

  Ky.tuan(DateTime ngayTrongTuan);
  Ky.thang(int nam, int thang);
  Ky.quy(int nam, int quy);      // quy ∈ [1, 4]
  Ky.nam(int nam);
  Ky.tuyChon({required DateTime from, required DateTime to});

  // ⚠️ Nhãn quý ĐÃ ĐỔI sau khi thi công: "Q3 2026", không phải "Quý 3 2026".
  // Dạng đầy đủ làm nhãn ô header "Quý này (Quý 3 2026)" dài hơn
  // "Tháng này (T9 2026)" đúng một ký tự, và máy ảo cắt nó thành
  // "Quý này (Quý 3 20…" — mất cả năm (sửa 2026-09-15, xem mục 3.20
  // `ANALYTICS_FEATURE.md`). Nhãn trục vẫn "Q3/26" như dòng dưới ghi.
  String get nhan;      // "Tuần 38 (15/09 – 21/09)" · "T9 2026" · "Q3 2026" · "2026" · "15/09 – 30/09"
  String get nhanTruc;  // nhãn trục biểu đồ: "15/09" · "T9" · "Q3" · "2026"
  bool chua(DateTime d);
}

List<Ky> cacKyGanNhat(DateTime now, DonViKy donVi);
Ky lui(Ky ky, int soKy);
```

**Biên `to` mở, không có ngoại lệ nào.** Đây là quy ước của cả app; một `Ky` lấy
biên đóng sẽ đếm khoản 00:00 ngày đầu kỳ sau vào kỳ này, và lệch ấy **im lặng**.

**Nhãn `nhan` của kỳ tuỳ chọn hiện `to - 1 ngày`**, cùng lý lẽ với
`report_preview_page.dart:160` — hiện thẳng `to` là tự nhận có dữ liệu của một
ngày mà kỳ ấy không hề đếm.

**Số kỳ trong bộ chọn — một chỗ định nghĩa:** tuần **12**, tháng **12**, quý
**8**, năm **5**. Đặt trong `cacKyGanNhat` chứ không rải ở widget.

### 3.1 Biên tuần: dùng lại `tuan_iso.dart`, không viết bản thứ hai

`lib/core/notification/tuan_iso.dart` đã có `tuanISO()` (năm + số tuần ISO) và
`tuanTruoc(now)` (biên tuần đã khép lại). P1 cần thêm một phép: **biên của tuần
chứa một ngày**.

Thêm `bienTuan(DateTime)` vào **chính tệp ấy** và cho `tuanTruoc` gọi lại nó —
hiện `tuanTruoc` tự tính `thuHaiTuanNay` bên trong. Viết một bản thứ hai trong
`pham_vi_ky.dart` là đúng thứ dự án đã trả giá nhiều lần (xem `normalizeCategoryName`).

Tuần bắt đầu **thứ Hai** theo ISO. Số tuần lấy từ `tuanISO`, nên nhãn tự đúng ở
ca khó: `31/12/2025` thuộc `2026-W01`, `01/01/2021` thuộc `2020-W53`.

### 3.2 `khoangKyTruoc` chuyển chỗ

Hàm này đang nằm ở `bao_cao_xuat.dart` và phục vụ "so với kỳ trước" của trang
Báo cáo. Nó **đã đúng cho cả năm đơn vị** mà không cần sửa:

| Đơn vị | Đường nó đi | Kết quả |
|---|---|---|
| Tuần | không trọn tháng → lùi đúng độ dài | 7 ngày trước đó |
| Tháng | trọn tháng, `soThang = 1` | tháng liền trước, không phải "trừ 30 ngày" |
| Quý | trọn tháng, `soThang = 3` | quý liền trước |
| Năm | trọn tháng, `soThang = 12` | năm liền trước |
| Tuỳ chọn | lùi đúng độ dài | khoảng liền trước, dài bằng |

**Chuyển** nó sang `pham_vi_ky.dart` rồi `export … show khoangKyTruoc;` ngược
lại từ `bao_cao_xuat.dart` — cùng khuôn với dòng `export 'thong_ke_thang.dart'
show TongThuChi, rutGon;` đã có. Hai trang dùng chung một định nghĩa; mọi chỗ
gọi cũ và test của chúng không phải đổi.

---

## 4. Chuỗi xu hướng đi theo đơn vị

`chuoiTheoThang(ds, nam:, thang:, soThang: 6)` → **`chuoiTheoKy(ds, ky:, soKy: 6)`**,
lùi bằng `lui(ky, i)` thay vì `DateTime(nam, thang - i, 1)`.

`DiemThoiGian` đổi `{nam, thang, tong}` thành **`{Ky ky, TongThuChi tong}`**;
nhãn trục lấy `diem.ky.nhanTruc` thay cho `'T${chuoi[i].thang}'` đang viết thẳng
ở `analytics_page.dart:644`.

`chuoiTheoDanhMuc` đi cùng luật, cùng `soKy`.

**Kỳ tuỳ chọn rơi về 6 tháng** tính lùi từ `to`: khoảng tuỳ ý không có đơn vị tự
nhiên để lùi, và "6 khoảng 17 ngày" không phải thứ ai đọc được.

Tiêu đề khối đổi theo đơn vị: "XU HƯỚNG 6 TUẦN / 6 THÁNG / 6 QUÝ / 6 NĂM". Số 6
giữ nguyên cho mọi đơn vị — người dùng đã loại phương án số điểm đổi theo đơn vị,
vì nó thêm một bảng hằng số phải nhớ mà không đổi được gì đáng kể.

⚠️ Nhãn trục của đơn vị **tuần** là ngày thứ Hai dạng `15/09`, **không** phải
`T38`: `T` đang là tiền tố của tháng ở khắp app, và hai nghĩa cùng một chữ trên
cùng một trục là lỗi đọc nhầm chứ không phải lỗi mã. Bẫy **4.18** (nhãn chồng
nhau, G39 hôm 2026-09-14) vẫn áp dụng: nhãn dài hơn thì càng dễ đè.

---

## 5. Repository, cubit, state

| Cũ | Mới |
|---|---|
| `ThongKeThang { nam, thang, … }` | **`ThongKeKy { Ky ky, … }`** |
| `watchThang(id, {nam, thang, now})` | **`watchKy(id, {required Ky ky, DateTime? now})`** |
| `AnalyticsLoading(nam, thang)` | `AnalyticsLoading(Ky ky)` |
| `AnalyticsLoaded.cacThang` | **bỏ**, thay bằng `moc` (số đọc của `clock`) |
| `AnalyticsCubit.chonThang(nam, thang)` | `chonKy(Ky ky)` |

Giữ tên `ThongKeThang` cho một lớp chứa khoảng bất kỳ là để tài liệu nói dối —
đổi tên là phần việc, không phải phần tuỳ chọn.

**Vì sao `cacThang` biến thành `moc`:** bottom sheet phải lướt được danh sách của
**đơn vị người dùng đang xem** trước khi họ chọn kỳ nào. Bắt cubit giữ danh sách
ấy nghĩa là mỗi lần chạm một chip là một vòng cubit → state → rebuild cả trang,
cho một thao tác chưa đổi dữ liệu. Thay vào đó state mang `moc` (đọc từ `clock`
để test không phụ thuộc đồng hồ máy) và sheet tự gọi `cacKyGanNhat(moc, donVi)`.
Luật "12 kỳ" vẫn có đúng một định nghĩa ở domain và vẫn được test ở đó — lý lẽ
"tính ở cubit chứ không ở widget" trong chú thích cũ được giữ nguyên ở chỗ nó
thật sự quan trọng.

`xem(idaccount)` vẫn mở **tháng hiện tại** — không đổi hành vi mặc định.

Hai lựa chọn đang giữ ngoài state (`_phanLoaiDangXem`, `_danhMucXuHuong`) theo
đúng luật cũ khi đổi kỳ: phân loại **về `chi`**, danh mục xu hướng **giữ**. Chú
thích hiện tại nói "chuỗi của nó nhìn xa sáu tháng nên vẫn có nghĩa ở tháng
khác" — nay là "sáu kỳ", sửa chú thích theo.

---

## 6. Bộ chọn — bottom sheet

`_ChonThang` → `_ChonPhamVi`, mở `showModalBottomSheet`:

```
╭──────────────────────────────────╮
│            ▁▁▁▁                  │  thanh kéo
│  CHỌN PHẠM VI                    │  label-md in hoa
│  (Tuần)(Tháng•)(Quý)(Năm)(Tuỳ…) │  chip cuộn ngang, 1 chip đang bật
│ ──────────────────────────────── │
│  Tháng này (T9 2026)          ✓ │
│  T8 2026                         │
│  T7 2026                         │
│  …                               │
╰──────────────────────────────────╯
```

- Chip **Tuỳ chọn** mở `showDateRangePicker`; thoát ra mà không chọn thì **giữ
  nguyên kỳ đang xem**, không rơi về tháng này (khác `khoangCuaPhamVi`, nơi
  `null` phải có một chỗ rơi vì nó là hàm thuần).
- Nhãn ô ở header giữ nếp cũ: hiện "Tháng này (T9 2026)" **chỉ khi kỳ chứa hôm
  nay** (`ky.chua(moc)`), ngược lại hiện tên kỳ trần. Tổng quát cho năm đơn vị:
  "Tuần này", "Tháng này", "Quý này", "Năm nay"; kỳ tuỳ chọn **không** có dạng
  "… này".
- Chọn xong thì đóng sheet rồi mới `chonKy` — đóng sau là hộp thoại nháy một
  khung dữ liệu mới trước khi biến mất.

Ô ở header **không đổi kích thước**, nên không đụng lại bài toán tràn 53px.

---

## 7. ⚠️ Ngân sách chỉ hiện khi đơn vị là Tháng

Thanh "% ngân sách" ở danh sách danh mục đọc `spent` của `BudgetView` — số đã chi
theo **kỳ của chính ngân sách ấy**, không theo kỳ đang xem. Hôm nay hai thứ đó
xấp xỉ trùng vì trang chỉ xem theo tháng.

Mở phạm vi ra mà giữ nguyên thanh ấy là hỏng **im lặng**: xem một tuần, thanh vẽ
mức chi cả tháng; xem cả năm, thanh vẫn vẽ mức chi một kỳ ngân sách. Không
exception, không log, và con số trông rất hợp lý.

**Quyết định:** khi `ky.donVi != DonViKy.thang` thì **không gắn**
`nganSachHanMuc` / `nganSachDaChi`. Dòng danh mục tự đổi sang nhãn "% tổng chi" —
đường rơi về ấy đã có sẵn cho ca danh mục không có ngân sách, không phải viết mới.

Mốc tra ngân sách tổng quát hoá từ `laThangHienTai`:

```dart
final mocNganSach = ky.chua(at) ? at : ky.to.subtract(const Duration(seconds: 1));
```

Giữ nguyên lý lẽ cũ: kỳ đang diễn ra thì lấy đúng "bây giờ" để số đã chi khớp
trang Ngân sách; kỳ đã qua thì lấy giây cuối kỳ để ngân sách nào còn sống tới
cuối kỳ vẫn được tính. Phép lọc `isExpired` **giữ nguyên** — bỏ nó là một ngân
sách chết từ tháng 6 vẫn ra "10% ngân sách" ở tháng 9.

---

## 8. Hai bước thi công

Không đổi 12 tệp trong một lát. Hai bước, mỗi bước tự nghiệm thu được:

### Bước 1 — tổng quát hoá tầng dưới, hành vi **không đổi**

Domain → repository → cubit → state → trang, tất cả nói bằng `Ky`; nhưng bộ chọn
vẫn **chỉ dựng `Ky.thang`** như hôm nay. Bộ test cũ chuyển sang API mới và
**phải xanh với đúng những con số cũ**. App chạy y hệt chính là bằng chứng mô
hình mới đúng.

Tệp chạm: `pham_vi_ky.dart` (mới), `thong_ke_thang.dart`,
`bao_cao_xuat.dart` (chỉ dòng export), `core/notification/tuan_iso.dart`,
`analytics_repository.dart`, `analytics_repository_impl.dart`,
`analytics_cubit.dart`, `analytics_state.dart`, `analytics_page.dart`.

### Bước 2 — mở bộ chọn và chuỗi xu hướng

Bottom sheet 5 đơn vị, chuỗi xu hướng theo đơn vị, tiêu đề khối đổi theo, nhãn
trục theo `nhanTruc`, chốt ngân sách ở mục 7, nghiệm thu máy ảo.

Tệp chạm: `presentation/widgets/chon_pham_vi_sheet.dart` (mới),
`analytics_page.dart`, cộng test.

---

## 9. Test

TDD, đỏ trước, đỏ **đúng lý do**. Ca nào xanh ngay từ đầu thì làm **bản sai có
chủ ý** để chứng minh nó canh thật — cách này đã dùng 5 lần ở lát A8 hôm
2026-09-14 và được việc.

**Domain (`pham_vi_ky_test.dart` — tệp mới):**
- Biên `[from, to)` của cả năm đơn vị.
- ⚠️ **Tháng ngắn và năm nhuận**: `Ky.thang(2024, 2)` phải hết ngày 29/02;
  `Ky.quy(2026, 1)` phải trọn ba tháng; lùi từ 31/03 không được rơi vào 03/03.
- ⚠️ **Tuần vắt qua năm**: `Ky.tuan(31/12/2025)` mang nhãn tuần **2026-W01**.
- `cacKyGanNhat` đúng số lượng và đúng thứ tự (mới nhất trước) cho từng đơn vị.
- `lui` lùi đúng đơn vị, kể cả qua mốc năm.
- `khoangKyTruoc` cho cả năm đơn vị (bảng ở mục 3.2).
- `bienTuan` khớp với `tuanTruoc` hiện có — ca canh việc chúng dùng chung một
  phép.

**Domain (`thong_ke_thang_test.dart` — sửa):** `chuoiTheoKy` đúng số điểm, đúng
thứ tự cũ-trước, và mỗi điểm mang đúng `Ky`.

**Cubit:** đổi đơn vị thì `_phanLoaiDangXem` về `chi`, `_danhMucXuHuong` giữ;
`chonKy` huỷ đăng ký cũ **trước** (luật cũ, có bản sai có chủ ý canh sẵn).

**Widget:** sheet ở **411dp** — chip không tràn, danh sách cuộn được; nhãn header
đúng cho từng đơn vị; và **ca canh mục 7**: đơn vị ≠ tháng thì không dòng nào có
thanh ngân sách. Dựng bằng `AppTheme.lightTheme` (bẫy 4.11), nhớ font của bộ test
rộng gấp đôi ngoài đời (bẫy 4.4).

**Máy ảo** (bẫy 4.9 — tầng vẽ không test được): mở đủ năm đơn vị, xem nhãn trục
có chồng nhau không ở đơn vị tuần (nhãn `15/09` dài hơn `T9`), và xem donut +
danh sách danh mục có cùng nói một con số không.

Mức nền phải giữ: **2409/2409** test, **25 issue / 0 error**.

---

## 10. Bẫy đã biết

1. **`FlClipData.all()`** cho biểu đồ (bẫy 4.17) — mặc định là `none()` nên điểm
   ngoài dải vẫn được vẽ và tràn khỏi thẻ.
2. **Nhãn trục hai biên** (bẫy 4.18, G39): fl_chart vẽ nhãn ở cả hai biên cộng
   thêm mốc theo `interval`, nên hai nhãn cuối chồng nhau.
3. **`'transfer'` không phải thu cũng không phải chi**, và luật loại khỏi thống
   kê có một định nghĩa duy nhất ở `analytics/domain/khoan_vao_thong_ke.dart`.
   `Ky` không đụng gì tới luật ấy — đừng nhân tiện "dọn" nó.
4. **Stitch không nghiệm thu được bằng API.** `edit_screens` từng trả về thành
   công kèm `dom_operations` chi tiết mà **không đổi gì**; và một màn mới xuất
   hiện **không** chứng minh lời gọi của mình tạo ra nó — người dùng thao tác
   song song trên Stitch. Chỉ ghi cái **đo được**, và hỏi người dùng nhìn giúp.
5. **Stream phát lại sau mỗi chu kỳ đồng bộ.** Quên chép lựa chọn sang state mới
   thì donut nhảy về nhóm Chi giữa lúc người dùng đang xem — không exception,
   không log. Kỳ đang xem nay cũng là một lựa chọn như thế.

---

## 11. Ngoài phạm vi

- **Deep link từ thông báo Tổng kết tuần** vào đúng tuần ấy. Mô hình `Ky` mở
  đường (một `Ky.tuan(ngay)` là đủ để mô tả đích đến), nhưng đường điều hướng và
  chỗ nhận tham số là việc riêng — và bản thân thông báo Tổng kết tuần chưa dựng.
- **P2** (đưa số liệu nhanh, phân bổ theo ví, top 5, dòng tiền từ Báo cáo sang
  Phân tích) và **P3** (biểu đồ thác nước) — ✅ **cả hai đã xong 2026-09-15**,
  mục **3.21** và **3.23** `ANALYTICS_FEATURE.md`. ⚠️ P3 còn đi một đường vòng:
  người dùng chốt "không làm" rồi **đổi ý cùng ngày** và xin thêm một đường
  trung bình.
- Trang **Xuất báo cáo** không đổi gì ngoài một dòng `export`. `PhamViThoiGian`
  của nó (thangNay / thangTruoc / quyNay / tuyChinh) là **bốn nút của màn Stitch
  báo cáo**, phục vụ một câu hỏi khác với bộ chọn kỳ của trang Phân tích — gộp
  hai enum làm một là ép hai màn khác nhau dùng chung một danh sách mà cả hai đều
  không muốn.
