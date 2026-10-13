# Tách bốn trang lớn còn lại của Client-app — G88 gạch 2

**Ngày:** 2026-10-13 · **Nhánh:** `TranQuangDat` · **Trạng thái:** người dùng duyệt (ba phần trong chat, rồi bản viết).
Kế hoạch 11 task: `docs/superpowers/plans/2026-10-13-tach-bon-trang-lon.md` (gitignore).

> 🔧 **Chỗ kế hoạch KHÁC bản viết** (soát với mã lúc lập kế hoạch, 2026-10-13 — kết quả cuối không đổi):
> 1. **Phiếu Nạp / Rút dời TRƯỚC lưới ô tiền** (mục 4 và 8 ghi lưới ô tiền là commit đầu). `goal_detail_page.dart` đang ở trần
>    riêng 1.480 của quét 23 (chỉ được giảm); thêm trần vào trang trước khi dời là +2–3 dòng → quét 23 đỏ. Nên dời phiếu trước,
>    rồi sửa lưới và thêm trần **trong tệp phiếu** — vẫn trước khi ô tiền của Thêm mục tiêu dời.
> 2. **`_dongQuyenBienDong` / `_dongQuyenPhien` ở lại trang** (mục 5.3 xếp chúng vào tệp widget): chúng đọc kênh nền tảng
>    `_kenh` / `_kenhPhien`, quy tắc 3.3 cấm widget đọc dịch vụ. Trang dựng sẵn `DongQuyen(...)` / `DongTreNen(...)` rồi truyền vào.
> 3. **Phiếu nhận getter `layMucTieu: () => _goal!`** thay vì giá trị `goal` (mục 5.2): thân phiếu đọc `_goal!` sống ở mỗi lần
>    `StatefulBuilder` dựng lại và lúc bấm xác nhận — truyền giá trị chụp là đổi hành vi khi đồng bộ kéo về giữa chừng.
> 4. Hàm / lớp phụ chỉ một tệp mới dùng giữ **riêng tư** trong tệp ấy (mục 3.2 ghi "lớp công khai" — áp cho khối trang gọi).
> 5. **`dart format` chỉ chạy trên tệp MỚI** (mục 3.8 ghi cả tệp trang): format tệp trang kéo theo đổi dòng không thuộc phần dời.
> 6. **`_buildHistorySection` ở lại trang dạng vỏ** (mục 5.2 xếp vào tệp mới): nó gọi `_goalRepository` (quy tắc 3.3). Trang
>    giữ vỏ, truyền dữ liệu vào `KhoiLichSuMucTieu`; `_danhSachLichSu` sang tệp mới.
> 7. **Ba hằng chuỗi dùng chung của hai trang đồng ý** (`kNhacThuHoiQuyen`, `kTenNhacSauNganHang`, `kNhacThuHoiQuyenSuDung`)
>    dời nguyên văn sang `notification/domain/cau_chu_dong_y.dart` (áp mục 3.4 câu hai); hai trang đồng ý `export … show` lại
>    để hai test giữ import.
> 8. **Hai widget nhận thêm tham số so với bản viết:** `DaiDuDoanMucTieu` + `depositAmountController` + `frequency` (getter
>    `_frequencyLabel` dời theo, riêng tư); `DauBaoCao` + `baoCao` + `lapNgay` (`lapNgay` lấy từ trường của trang, **không**
>    `DateTime.now()`).
> 9. **13 lớp công khai thiếu hậu tố theo luật đặt tên** (đếm 2026-10-13 bằng `grep -hE "^(abstract )?(class|enum|mixin) [A-Z]"`
>    trên hai thư mục): `cai_dat_thong_bao/` **11** — `HangCongTac` · `HangBam` · `HangGioImLang` · `DongGoiY` · `HangSoNgay` ·
>    `HangNguongSoDu` · `HangNguongChiLon` · `DongQuyen` · `DongTreNen` · `TheBienDong` · `KhoiNhacSauNganHang` (thiếu
>    `…CaiDat` / `…ThongBao`); `them_muc_tieu/` **2** — `TheLapLai` · `TheTrichTuDong` (thiếu `…MucTieu`). Giữ tên như phần
>    Interfaces của kế hoạch đặt đích danh (grep `-w` không trùng tên nào); đổi tên là lệch Interfaces và kéo các task sau.
> 10. Các dòng `Ruling:` khác ở sổ `.superpowers/sdd/2026-10-13-tach-bon-trang-lon/progress.md` (gitignore) phần lớn là lời dặn
>     thi công; **riêng một dòng bỏ bớt cặp nghiệm thu**: Task 10 **không chụp được** ba trạng thái mục 8 liệt kê — Cài đặt thông
>     báo khi D1 bật, khối nhắc sau ngân hàng bật (cần cấp quyền hệ điều hành trên máy ảo) và dòng gợi ý giờ (máy không có) —
>     được thay bằng `dong_y_bien_dong_test` + `nhac_sau_ngan_hang_cai_dat_test` (35 ca: 21 + 14, đếm 2026-10-13, dựng trang
>     thật ở các trạng thái bật / quyền / pin) và bản soát thứ tự token của Task 7. Nghiệm thu máy thật lần sau bật D1 sẽ bắt được.

> ✅ **Số đo sau thi công (2026-10-13, đếm bằng `wc -l` / `ls | wc -l`):** bốn trang **1.570 / 1.480 / 1.615 / 1.270 →
> 791 / 664 / 866 / 243** dòng (`goal_add_page` · `goal_detail_page` · `notification_settings_page` · `report_preview_page`);
> 30 tệp widget mới (`them_muc_tieu/` 7 · `chi_tiet_muc_tieu/` 7 · `cai_dat_thong_bao/` 6 · `xem_truoc_bao_cao/` 10) + 2 tệp
> `domain/` (`chu_ky_muc_tieu`, `cau_chu_dong_y`); 9 commit mã `ecd01990` → `c4ea8437`; `mienTru` của quét 23 **rỗng**;
> `flutter test` 7.037 → **7.039** (+9 skip), `flutter analyze` **20**. Máy ảo: 32 cặp ảnh trước / sau **0 px khác**, vàng thuần 0 — **trừ ba trạng thái không chụp được** (D1 bật, khối nhắc sau ngân hàng bật, dòng gợi ý giờ; xem mục 10 của khối 🔧
> trên), thay bằng 35 ca widget test.

Đợt này đóng **G88 gạch 2** (`docs/CLIENT_APP_KNOWN_GAPS.md`): bốn tệp còn trong danh sách miễn trừ của test quét 23
(`test/core/ui/tep_presentation_khong_qua_dai_test.dart`, trần 1.200 dòng). Cùng loại việc với đợt tách trang Phân tích
(spec `2026-10-10-bit-diem-ro-kien-truc-client-design.md` mục 5): **tách widget theo khối, trạng thái ở lại trang, dời
nguyên văn**. Người dùng app **không thấy gì đổi**, trừ đúng một chỗ ở mục 4.

## 1. Quyết định đã chốt

| # | Câu hỏi | Chốt | Nguồn |
|---|---|---|---|
| 1 | Cách tách | Widget theo khối, trạng thái và mọi `sl<…>` ở lại trang (không Cubit mới) | G88 gạch 2, ghi chú 2026-10-11 |
| 2 | Thứ tự trong đợt | Thêm + Chi tiết mục tiêu → Cài đặt thông báo → Xem trước báo cáo | G88 gạch 2, người dùng chốt 2026-10-11 |
| 3 | Độ sâu | **Tách hết khối giao diện** — trang chỉ còn trạng thái, hàm xử lý và khung; không chỉ đủ dưới 1.200 | Người dùng chọn 2026-10-13 |
| 4 | Hai ô số tiền của phiếu Nạp / Rút (Chi tiết mục tiêu) chưa có trần | **Thêm trần 13 chữ số** — commit riêng, trước khi dời | Người dùng chọn 2026-10-13 |
| 5 | Lối thi công | Hỏi sau khi có kế hoạch (inline · agent con · inline dừng theo mốc) | Bộ nhớ *thực thi kế hoạch* |

## 2. Hiện trạng đo được (2026-10-13, HEAD `eb8c6bb7`)

Số dòng đếm như test quét 23 (`readAsLinesSync().length`):

| Trang | Dòng | Hình dạng | Phần nặng |
|---|---|---|---|
| `goal/presentation/pages/goal_add_page.dart` | 1.570 | `StatefulWidget`, trạng thái form (16 `setState`) | `build` 608 dòng (5 thẻ + ~35 dòng logic chọn ví ở đầu), `_showWalletPickerBottomSheet` 200, `_submitForm` 131, năm hàm dựng ô ~175 |
| `goal/presentation/pages/goal_detail_page.dart` | 1.480 | `StatefulWidget`, nghe luồng dữ liệu | `_showDepositDialog` 280 + `_showWithdrawDialog` 192 (bottom sheet + `StatefulBuilder`), bảy hàm khối ~530 |
| `notification/presentation/pages/notification_settings_page.dart` | 1.615 | `StatefulWidget` + `WidgetsBindingObserver`, ~25 hàm `_doi…`/`_chon…`/`_ghi` | `build` 272 (tám thẻ dựng từ hàm `_hang…`), `_theBienDong` 91, `_dongQuyen` 111, 13 `static const Key` |
| `analytics/presentation/pages/report_preview_page.dart` | 1.270 | `StatelessWidget` vẽ từ `BaoCao` | 25 hàm khối |

Mốc test: 580 ca của bốn trang + các test quét (22–25, `wallet_picker_sources`, `o_nhap_tien_co_tran`,
`icon_button_co_tooltip`, `khong_co_nut_chet`) xanh; toàn bộ `flutter test` **7037 pass / 9 skip**; `flutter analyze`
**20**. Tệp test dựng bốn trang: Thêm mục tiêu 2 (`goal_add_dien_san_test`, `goal_add_name_limit_test`), Chi tiết mục tiêu 1
(`goal_detail_live_test`), Cài đặt thông báo 4 (`notification_settings_page_test`, `notification_settings_de_xuat_test`,
`dong_y_bien_dong_test`, `nhac_sau_ngan_hang_cai_dat_test`), Xem trước báo cáo 2 (`report_preview_page_test`,
`export_report_page_test`).

## 3. Quy tắc dời mã

Giữ nguyên mục 5.3 của spec bịt điểm rò, cộng các chỗ riêng của đợt này:

1. **Dời nguyên văn** thân widget; chỉ đổi tham chiếu `_truong` thành tham số. Giữ mọi `Key(...)`, chuỗi hiển thị, thứ tự con
   trong `Column`/`Row`. **Không sửa tiện tay** bố cục hay chữ, kể cả chỗ trông như lỗi (ví dụ `hintText: 'e.g. 1.000.000'`
   của phiếu Nạp, nhãn tiếng Anh) — ghi vào mục 9 nếu đáng sửa sau.
2. Khối thành **lớp `StatelessWidget` công khai** (như `widgets/phan_tich/`), constructor nhận `super.key`, `const` khi được.
   Hàm mở sheet / hộp thoại thành **hàm cấp tệp** nhận `BuildContext` (luật mục 8: *hộp thoại, hành động giao diện*).
3. **Widget mới không import `core/di`** và không đọc repository; dữ liệu và hành động đi qua tham số / callback. Chỗ đang
   `context.read<…Cubit>()` thì giữ — Cubit đến từ cây widget.
4. **Widget không import tệp trang** (ngược chiều). Thứ trang và widget cùng cần thì dời ra chỗ đúng luật mục 8 (mục 5 bên dưới
   liệt kê từng thứ).
5. Mỗi tệp mới có docstring một đoạn: nó là khối nào của trang nào.
6. Tên lớp công khai mới mang hậu tố theo trang (`…MucTieu`, `…BaoCao`, `…CaiDat`) để không trùng `widgets/phan_tich/`.
   Đã kiểm 2026-10-13: không lớp / định danh nào trong `lib/` đang mang các tên ở mục 5.
7. **0 kỳ vọng test đổi**, trừ đúng hai chỗ: phép nhận diện của test quét ô tiền (mục 4) và `mienTru` của quét 23 (mục 6).
   Phải đổi một kỳ vọng khác là dấu hiệu hành vi đã đổi — dừng và soát.
8. `dart format` các tệp mới và tệp trang; đo số dòng **sau** format.

## 4. Lưới ô tiền — thay đổi hành vi duy nhất của đợt

**Vì sao phải đụng.** `test/core/utils/o_nhap_tien_co_tran_test.dart` (test quét thứ tám) nhận diện một ô tiền bằng chuỗi
**`controller: _tenController,`** trong tệp, rồi đòi chính tệp ấy chứa `GioiHanSoChuSo`. Khi thẻ thông tin và thẻ trích tự động
của trang Thêm mục tiêu dời sang widget, controller đi vào làm **tham số** (`controller: targetAmountController,` — tham số Dart
không có gạch dưới), nên lưới **mù im lặng**: test vẫn xanh trong khi không còn canh ô nào.

**Sửa phép nhận diện** để nhận cả hai dạng: `controller: _?<tên không gạch dưới>,`. Đo 2026-10-13: trong `lib/` chỉ có **hai**
chỗ khớp dạng không gạch dưới — `goal_detail_page.dart:406` và `:624`, ô số tiền của phiếu Rút và phiếu Nạp (biến cục bộ
`amountController`). Hai ô ấy **chưa có trần**; hôm nay chúng chỉ bị chặn gián tiếp — Nạp bởi *"Số dư ví … không đủ"*, Rút bởi
*"Mục tiêu chỉ đang giữ …"* — nên chữ số thứ 14 không bao giờ tới CSDL. Theo quyết định 4: **thêm
`inputFormatters: const [GioiHanSoChuSo(kSoChuSoToiDaSoTien)]`** vào hai ô.

Người dùng thấy: gõ chữ số thứ 14 vào phiếu Nạp / Rút thì không vào — giống mọi ô tiền khác của app. Thực tế không ai chạm tới
(số dư ví không lớn tới vậy).

**Thứ tự TDD (commit đầu tiên của đợt, trước mọi lần dời):**
1. Sửa phép nhận diện → chạy test quét ô tiền, thấy **đỏ** đúng ở `goal_detail_page.dart`.
2. Viết hai ca widget: mở phiếu Nạp / phiếu Rút, gõ 14 chữ số → ô giữ 13. Chạy thấy **đỏ**.
3. Thêm `GioiHanSoChuSo` vào hai ô → cả ba xanh.
4. Thử bản sai: gỡ trần ở một phiếu → ca widget và test quét cùng đỏ.

## 5. Chia tệp

### 5.1 Thêm / Sửa mục tiêu — 1.570 → ước ~600 · `goal/presentation/widgets/them_muc_tieu/`

| Tệp mới | Lấy từ |
|---|---|
| `anh_dau_muc_tieu.dart` | khối ảnh đầu trang (`// Header Image`, dòng 815–852) |
| `the_thong_tin_muc_tieu.dart` | thẻ thông tin (`// Goal Information Card`, 852–1004): tên, số tiền mục tiêu, hạn, biểu tượng & màu, ví tích luỹ, ghi chú |
| `the_trich_tu_dong.dart` | thẻ trích tự động (`// Auto-Deposit Schedule Card`, 1004–1162) |
| `the_lap_lai.dart` | thẻ lặp lại (1162–1244) |
| `dai_du_doan_muc_tieu.dart` | dải dự đoán ngày hoàn thành (`// AI Prediction Insight Banner`, 1244–1284) |
| `bang_chon_vi_muc_tieu.dart` | `_showWalletPickerBottomSheet` (511–711) → hàm `moBangChonViMucTieu(...)`. **Không** gộp với `transaction/presentation/widgets/them_giao_dich/bang_chon_vi.dart` dù trông giống — gộp là sửa tiện tay |
| `o_nhap_muc_tieu.dart` | `_buildLabel` · `_buildTextField` · `_buildDropdownButton` · `_buildIconPicker` · `_buildColourPicker` |

Kiểu dùng chung: `enum DepositFrequency` và `kChuKyLapLai` (Dart thuần, khai ở `goal_add_page.dart:67,75`, chỉ trang này dùng —
đo 2026-10-13) → **`goal/domain/chu_ky_muc_tieu.dart`** (hàng *Hàm thuần* mục 8).

Ở lại trang: lớp `GoalAddPage` (dựng provider qua `sl<GoalCubit>` / `sl<WalletCubit>`), trạng thái form, `initState` /
`_napGoalDeSua` (`sl<GoalRepository>`), ba hàm lắng nghe ô, `_selectDate`, `_submitForm`, `_calculateEstimatedCompletionDate`,
`_chonGioTrich` / `_chonNgayTrich`, ~35 dòng logic chọn ví đầu `build`, nút Lưu (`// Submit Button`).

**Lưới ô tiền:** `the_thong_tin_muc_tieu.dart` và `the_trich_tu_dong.dart` sẽ chứa `controller: targetAmountController,` /
`controller: depositAmountController,` **cùng tệp** với `GioiHanSoChuSo` (ở điểm gọi `ONhap…` như hôm nay) — test quét ô tiền
(sau mục 4) thấy và canh hai tệp ấy.

### 5.2 Chi tiết mục tiêu — 1.480 → ước ~560 · `goal/presentation/widgets/chi_tiet_muc_tieu/`

| Tệp mới | Lấy từ |
|---|---|
| `phieu_nap_tien.dart` | thân phiếu Nạp trong `_showDepositDialog` (từ `showModalBottomSheet`) → `moPhieuNapTien(...)` |
| `phieu_rut_tien.dart` | thân phiếu Rút trong `_showWithdrawDialog` → `moPhieuRutTien(...)` |
| `khoi_so_tien_muc_tieu.dart` | `_buildAmountInfo` |
| `ghi_chu_muc_tieu.dart` | `_buildGhiChu` · `_buildCanhBaoVi` |
| `khoi_nhan_dinh_muc_tieu.dart` | `_buildInsightBox` |
| `khoi_lich_su_muc_tieu.dart` | `_buildHistorySection` · `_danhSachLichSu` |
| `nut_duoi_muc_tieu.dart` | `_buildBottomButtons` |

**Ranh giới hai phiếu** (chỗ dễ sai nhất của đợt):
- Ở lại trang: ba dòng **`sl<WalletRepository>().getActiveRows(`** (238, 333, 525) — **trên một dòng**, vì
  `wallet_picker_sources_test` xếp `goal_detail_page.dart` (đường dẫn tệp) vào *bộ chọn ví* và nhận diện theo chuỗi; tệp widget
  mới **không** đọc ví. Cũng ở lại: mọi điều kiện chặn **trước** khi mở phiếu (chưa đăng nhập, chưa có ví, thiếu ví nhận, không
  còn ví nguồn) cùng toast của chúng.
- Vào phiếu: tiêu đề, ô số tiền (kèm trần mục 4), bảng chọn ví, câu cảnh báo nạp vượt, và phép kiểm **giao diện** khi bấm xác
  nhận (số tiền ≤ 0; vượt số dư ví nguồn ở phiếu Nạp; vượt tiến độ ở phiếu Rút) cùng toast của chúng — giữ y thứ tự.
- Phần **sau** phép kiểm — gọi `_goalRepository.depositToGoal` / `withdrawFromGoal` (phiếu Rút có `try/catch` hiện lỗi và **giữ
  phiếu mở**), `if (ctx.mounted) Navigator.pop(ctx)`, `if (!mounted) return`, toast thành công, `_loadGoal()` — là **một**
  callback của trang nhận `(ctx, soTien, vi)`. Lý do: hàm cấp tệp không có `mounted` của trang, và tách phần này ra hai nửa là
  dễ đảo thứ tự pop / toast / nạp lại.
- Chú thích dài trong nhánh thành công của phiếu Nạp (vì sao **không** gọi `WalletCubit.loadWallets()`) đi theo callback ở trang.

Ở lại trang: nạp mục tiêu + đăng ký luồng (`_loadGoal`, `_dangKyDongDuLieu`, `_doiSangKhoan`), `_moBangLichSu`, `_tenCacVi`,
`_tinhCanhBaoVi`, `_xacNhanDoiViNhan`, `_xacNhanXoaMucTieu`, `_xacNhanVongMoi`, `build`.

### 5.3 Cài đặt thông báo — 1.615 → ước ~750 · `notification/presentation/widgets/cai_dat_thong_bao/`

| Tệp mới | Lấy từ |
|---|---|
| `khung_cai_dat.dart` | `_the` · `_khung` · `_hangCongTac` · `_hangBam` · `_hangGioImLang` · lớp `_GhiChu` · lớp `_ChuaDangNhap` |
| `hang_nguong.dart` | `_hangSoNgay` · `_hangNguongSoDu` · `_hangNguongChiLon` |
| `the_bien_dong.dart` | `_theBienDong` · `_dongQuyen` · `_dongQuyenBienDong` · `_dongTreNen` + ba hằng `kTieuDeTreNen`, `kTieuDeTreNenNhac`, `kMoTaTreNen` |
| `khoi_nhac_sau_ngan_hang.dart` | `_khoiNhacSauNganHang` · `_dongQuyenPhien` |
| `dong_goi_y.dart` | lớp `_DongGoiY` |
| `ten_nhom_thong_bao.dart` | `_tenNhom` · `_moTaNhom` · `_iconNhom` · `_tenThu` · `_tenThuThuong` (cấp tệp, trang và widget cùng dùng → công khai) |

- **13 `static const Key`** (`NotificationSettingsPage.khoaCongTacOs`, `khoaCongTacNhom(...)`…) **ở lại lớp trang** — test gọi
  chúng qua tên lớp. Widget nhận khoá qua tham số và đặt nó **đúng chỗ** hôm nay (thường là trên công tắc / ô bấm, không phải trên
  hàng) — ca test tìm theo khoá là thứ canh việc này.
- Ba hằng `kTieuDe…` / `kMoTaTreNen` dời sang `the_bien_dong.dart`; trang thêm
  `export '../widgets/cai_dat_thong_bao/the_bien_dong.dart' show kTieuDeTreNen, kTieuDeTreNenNhac, kMoTaTreNen;` vì
  `dong_y_bien_dong_test` và `nhac_sau_ngan_hang_cai_dat_test` đọc chúng qua `import …/notification_settings_page.dart`.
- Hàm `_dongGoiY(LoaiDeXuat, [NotificationGroup?])` đọc trạng thái gợi ý của trang và gọi `_apDung` / `_boQua` → **ở lại**,
  trả `DongGoiY(...)`.

Ở lại trang: lớp `NotificationSettingsPage` (tham số tiêm, 13 khoá), mọi `sl<…>` (`NotificationPrefsStore`, `OsNotifier`,
`KenhBienDong`, `KenhPhienNganHang`, `MocPhienStore`, `DeXuatThongBaoNguon`, `ReminderScheduler`), vòng đời app
(`didChangeAppLifecycleState`, đọc quyền), ~25 hàm `_doi…` / `_chon…` / `_ghi` / `_nap`, `build` dựng tám thẻ từ widget trên.

### 5.4 Xem trước báo cáo — 1.270 → ước ~250 · `analytics/presentation/widgets/xem_truoc_bao_cao/`

| Tệp mới | Lấy từ |
|---|---|
| `the_bao_cao.dart` | `_the` · `_nhanMuc` · `_coDau` · `_phanTram` (dùng chung mọi khối) |
| `dau_bao_cao.dart` | `_dauBaoCao` · `_chip` |
| `khoi_tong_quan_bao_cao.dart` | `_baThe` · `_theTong` · `_khiRong` |
| `khoi_dong_tien_bao_cao.dart` | `_khoiDongTien` · `_oSoDu` |
| `bieu_do_bao_cao.dart` | `_bieuDo` · `_duong` · lớp `_ChuGiai` |
| `khoi_so_lieu_nhanh_bao_cao.dart` | `_soLieuNhanh` · `_oSoLieu` |
| `khoi_danh_muc_bao_cao.dart` | `_bangDanhMuc` · `_dongDanhMuc` · `_khoiNganSach` |
| `khoi_theo_vi_bao_cao.dart` | `_khoiTheoVi` |
| `khoi_top_chi_bao_cao.dart` | `_khoiTopChi` |
| `danh_sach_giao_dich_bao_cao.dart` | `_danhSachGiaoDich` (giữ `KeyedSubtree(key: const Key('khoiGiaoDich'))`) · `_dongGiaoDich` |

`_coDau` chỉ bọc `CurrencyFormatter.formatCoDau`, `_phanTram` chỉ ghép chuỗi — không dựng `NumberFormat`, nên test quét
`currency_formatter_test` không đổi. Ở lại trang: `build`, `_thanhDuoi`, lớp `_NutTaiXuong` (gọi `sl<XuatTepService>()`).

## 6. Test quét 23

Tệp nào xuống ≤ 1.200 dòng thì **rút tên khỏi `mienTru` trong cùng commit** — không rút là test đỏ (*"đã xuống … — rút khỏi
mienTru"*). Xong bốn trang, `mienTru` **rỗng**: giữ nguyên khai báo `const mienTru = <String, int>{};` cùng vòng lặp kiểm — cơ
chế vẫn đúng cho tệp dài sau này. Ghi một dòng chú thích ngay trên khai báo để người sau không tưởng test hỏng.

## 7. Đối chiếu lộ trình G88

| Gạch | Ảnh hưởng | Khớp? |
|---|---|---|
| 2 — bốn tệp miễn trừ quét 23 | Đợt này đóng | ✅ |
| 3 — UI cầm hàng Drift, thống nhất Entity | Hưởng lợi: đợt Entity sửa tệp nhỏ. Hai phiếu Nạp / Rút cầm `Wallet` (hàng Drift) như trang đang cầm — số tệp cầm `Wallet` tăng 2; đợt Entity đo lại lúc bắt đầu | ✅ |
| 4 + 5 — `core` import `features/`, dời `core/notification` | Widget `cai_dat_thong_bao/` import `core/notification/*` — chiều `presentation → core` hợp lệ; đợt dời sửa đường import bằng script như mọi tệp | ✅ |
| 6 — đổi tên `data/services/` | Không chạm | ✅ |

Luật mục 8 `KIEN_TRUC_CLIENT_APP.md`: mọi tệp mới nằm ở `presentation/widgets/<tên trang>/` (widget một trang) hoặc
`domain/` (kiểu thuần) — test quét 25 nhận cả hai.

## 8. Kiểm thử và nghiệm thu

**Thứ tự commit**
1. Lưới ô tiền (mục 4).
2. Thêm mục tiêu → Chi tiết mục tiêu → Cài đặt thông báo → Xem trước báo cáo; **mỗi trang ít nhất một commit**. Sau mỗi commit
   chạy test của mảng, bốn test quét 22–25, `wallet_picker_sources_test`, `o_nhap_tien_co_tran_test`,
   `icon_button_co_tooltip_test`, `khong_co_nut_chet_test`.
3. Cuối đợt: toàn bộ `flutter test` (7037 + ca mới của mục 4, 9 skip) và `flutter analyze` = **20**.

**Nghiệm thu chạy app — so ảnh trước / sau.** Dựng APK ở commit trước đợt (`eb8c6bb7` hoặc commit spec) và ở commit cuối; cùng
tài khoản, cùng dữ liệu; máy thật nếu đang cắm (`adb devices`), không thì máy ảo. Bỏ thanh trạng thái khi so. Trạng thái phải
chụp:
- **Thêm mục tiêu:** tạo mới, cuộn hết · bật trích tự động · bật lặp lại · bảng chọn ví · chế độ Sửa một mục tiêu có trích tự động.
- **Chi tiết mục tiêu:** trang cuộn hết · phiếu Nạp · phiếu Rút · bảng lịch sử · hộp xác nhận xoá.
- **Cài đặt thông báo:** cuộn hết khi D1 tắt và khi bật · khối nhắc sau ngân hàng · dòng gợi ý (nếu tài khoản có đề xuất).
- **Xem trước báo cáo:** kỳ có dữ liệu, cuộn hết · kỳ rỗng.

Đạt khi **0 px khác** ở mọi cặp và **0 sọc vàng** (vàng thuần `#FFFF00`). Không có giao diện mới → **không có bước Stitch**.

## 9. Ngoài phạm vi — quan sát, không sửa

- Phiếu Nạp: `hintText: 'e.g. 1.000.000'` tiếng Anh; nhãn *"(VNĐ)"* — giữ nguyên (quy tắc 3.1).
- Bảng chọn ví của Thêm mục tiêu và của Thêm giao dịch là hai bản gần giống nhau — gộp là việc riêng, không thuộc đợt dời.
- Đặt tên `_build…` / `_show…` tiếng Anh lẫn tiếng Việt trong các trang — giữ.
- Lỗi có sẵn, phát hiện ở Task 1 (2026-10-13), **không sửa** vì dời nguyên văn: `TextEditingController` của hai phiếu Nạp / Rút
  (`phieu_nap_tien.dart`, `phieu_rut_tien.dart`) không được `dispose`.

## 10. Tài liệu cập nhật khi xong

- `docs/CLIENT_APP_KNOWN_GAPS.md` — G88 gạch 2 đóng (số dòng sau đợt, số tệp mới, commit), dòng cập nhật đầu tệp.
- `docs/KIEN_TRUC_CLIENT_APP.md` — quét 23 `mienTru` rỗng; ví dụ thư mục `widgets/<tên trang>/` nếu bảng có liệt kê.
- `CLAUDE.md` — hàng *Đụng vào presentation* (câu `mienTru` bốn tệp), mốc `flutter test`.
- `docs/PROJECT_CONTEXT.md` mục 14 — khối của đợt.
- `docs/GOAL_FEATURE.md`, `docs/NOTIFICATION_FEATURE.md`, `docs/ANALYTICS_FEATURE.md` — chỗ nào trỏ hàm / số dòng của bốn trang
  (`grep` tên hàm cũ `_showDepositDialog`, `_theBienDong`, `_khoiDongTien`…).
- Tệp bàn giao phiên.
