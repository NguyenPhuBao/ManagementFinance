# Thống kê theo phân loại danh mục và xu hướng một danh mục — thiết kế

**Ngày:** 2026-09-14 · **Nhánh:** `TranQuangDat` · **Trạng thái:** chờ duyệt

Đóng ba mục của **A8. Analytics & Reporting** (`Project.md:1028-1041`) mà client
tự làm được với dữ liệu đang có: **#2** biểu đồ tròn theo *phân loại danh mục*,
**#3** biểu đồ tròn theo *loại danh mục* cho cả chiều thu, và **#7** biểu đồ
đường một danh mục.

---

## 1. Vì sao làm, và vì sao chỉ ba mục

Bảng A8 có 11 mục. Lượt soát bằng mã ngày 2026-09-14 cho kết quả:

| # | Yêu cầu A8 | Trước lát này | Ghi chú |
|---|---|---|---|
| 1 | Tổng hợp kết quả thu chi | ✅ đã có | `_KhoiTong`, `_TheConLai` |
| 2 | Tròn theo **Phân loại** (thu, chi, vay/nợ) | ❌ | **lát này** |
| 3 | Tròn theo **Loại danh mục** | ⚠️ chỉ chiều chi | **lát này** |
| 4 | Cho vay + Thu nợ — cột | ❌ | ngoài phạm vi, xem §1.1 |
| 5 | Đi vay + Trả nợ — cột | ❌ | ngoài phạm vi, xem §1.1 |
| 6 | Xu hướng theo Phân loại — 2 đường | ✅ đã có | "Xu hướng 6 tháng", 2026-09-08 |
| 7 | Xu hướng theo **loại danh mục** — 1 đường | ❌ | **lát này** |
| 8 | Dòng tiền tự do (thu sau khi trả nợ) | ❌ | ngoài phạm vi, xem §1.1 |
| 9 | Biến động Khoản vay (Đi vay + Lãi vay) | ❌ | ngoài phạm vi, xem §1.1 |
| 10 | Biểu đồ thác nước | ❌ | làm được, để đợt sau — §10 |
| 11 | Biểu đồ Sankey | ❌ | làm được, để đợt sau — §10 |

### 1.1 Bốn mục bị chặn bởi mô hình dữ liệu, không phải bởi biểu đồ

Đếm bằng máy ngày 2026-09-14: client có **9** bảng Drift, backend có **13**
model Prisma. **Không đầu nào có bảng khoản vay.** Vay/nợ chỉ tồn tại như một
giá trị của cột `Classify` trên bảng danh mục.

Nghĩa là hệ thống **không lưu** dư nợ gốc, lãi suất, kỳ hạn, đối tác vay, và
mối liên kết giữa một khoản vay với các lần trả nợ của nó. Mục 4, 5, 8, 9 đều
cần ít nhất một trong những thứ ấy — chúng cần một mô hình dữ liệu mới ở **cả
hai đầu**, tức phải xin backend. Đó là một lát riêng, không thuộc lát này.

⚠️ `suggestDebtDirection()` ở `core/category/category_classify.dart` **không
thay được** mô hình ấy: nó đoán chiều tiền bằng cách so tên danh mục với bốn
chuỗi (`đi vay`, `thu nợ`, `cho vay`, `trả nợ`). Đó là **gợi ý lúc nhập liệu**,
nơi đoán sai chỉ tốn một cú chạm để sửa. Dựng thống kê trên một phép đoán theo
tên là báo cáo sai mà không ai biết — cùng loại sai lầm với việc dùng
`removeVietnameseTones()` cho quy tắc trùng tên (quy tắc 7 `CLAUDE.md`).

---

## 2. Luật phân loại — định nghĩa duy nhất

App có **hai** thứ dễ nhầm là một:

| Thứ | Giá trị | Nghĩa |
|---|---|---|
| `transaction.type` | `thu` · `chi` · `transfer` | **chiều tiền** |
| `category.classify` | `thu` · `chi` · `vay_no` | **phân loại danh mục** |

Một khoản *Trả nợ* mang `type = 'chi'` nhưng `classify = 'vay_no'`. A8 #2 hỏi
theo **classify**, nên luật là:

> **Phân loại của một khoản** = `classify` của danh mục nó gắn. Không tra được
> danh mục — khoản chưa phân loại, hoặc `categoryId` trỏ vào hàng chưa đồng bộ
> về — thì rơi về `type` của chính giao dịch.

Nhánh rơi về là bắt buộc, không phải phòng hờ: đo trên CSDL ngày 2026-09-10 có
**17** hàng giao dịch trống danh mục thật trên server. Loại chúng khỏi thống kê
là giấu mất chi tiêu thật — cùng lý lẽ đã ghi ở `khoan_vao_thong_ke.dart`.

Khoản `transfer` không bao giờ tới được luật này: `khoanVaoThongKe()` đã loại nó
cùng khoản điều chỉnh số dư và khoản mở sổ, trước mọi phép gom.

### 2.1 Hệ quả: lát "Chi" ≠ "Tổng chi"

Ba lát phải **rời nhau** thì tỷ trọng mới có nghĩa. Nên lát *Chi* của vòng tròn
**không bằng** con số *Tổng chi* ở thẻ đầu trang — nó thiếu đúng phần chi gắn
danh mục vay/nợ (Cho vay, Trả nợ), vì phần ấy đã nằm ở lát *Vay/nợ*.

Với tài khoản không dùng danh mục vay/nợ thì hai số bằng nhau; có dùng thì lệch.
**Đây là hành vi đúng, không phải lỗi.** Ba thẻ tổng ở đầu trang **giữ nguyên**
định nghĩa cũ (theo `type`) vì chúng trả lời câu hỏi khác: *tháng này tiền vào
ra bao nhiêu*.

---

## 3. Hình dạng trên màn hình

Người dùng chốt ngày 2026-09-14, sau khi xem bốn phương án:

### 3.1 Một khối donut có drill-down (mục #2 + #3)

Khối `_KhoiDonut` hiện tại **được thay**, không phải thêm khối mới:

- **Mức gốc** — tiêu đề "Cơ cấu dòng tiền", vòng tròn **3 lát** theo phân loại,
  tâm ghi "Tổng dòng tiền" và số tiền rút gọn, chú giải 3 mục, cộng một dòng
  chữ nhỏ *"Chạm một lát để xem danh mục bên trong"*.
- **Mức danh mục** — chạm một lát thì vòng tròn đổi sang các danh mục **bên
  trong** lát ấy (vẫn `topVaKhac`, top 4 + "Khác"), tiêu đề đổi theo lát, và có
  nút quay lại mức gốc.

Chọn lối này thay vì hai khối rời hay bốn chip ngang vì nó biến hai mục A8 thành
một khối mạch lạc mà không kéo dài trang — trang Phân tích ở 411dp vốn đã phải
cuộn.

### 3.2 Danh sách danh mục cuối trang đi theo donut

`_DanhSachDanhMuc` nhận cùng lựa chọn: chọn lát nào thì nó liệt kê danh mục của
lát ấy. Hai khối **luôn nói cùng một con số** — không bao giờ có chuyện donut
nói 8.2M mà danh sách cộng ra 8.5M.

Thanh ngân sách chỉ hiện ở lát **Chi**: ngân sách trong app chỉ đặt cho chi tiêu
(`BudgetRepository` không có khái niệm ngân sách thu). Ở hai lát kia, dòng phụ
rơi về "% của lát" đúng như cách `DongDanhMuc` đã làm khi danh mục không có
ngân sách — **không bịa** một hạn mức.

### 3.3 Bộ chọn danh mục trên khối Xu hướng (mục #7)

Khối "Xu hướng 6 tháng" nhận thêm một dropdown chiếm hết chiều ngang:

- Mặc định **"Tất cả danh mục"** → giữ nguyên hai đường Thu/Chi như hôm nay.
- Chọn một danh mục → còn **một** đường, màu lấy từ chính danh mục ấy, chú giải
  đổi thành tên danh mục.

Không mở màn mới và không mở bottom sheet — cố ý. Trang Phân tích nằm trong
`StatefulShellRoute`, và `push` một route trong shell từ chỗ khác đã từng làm
app chết màn đỏ (bẫy 7.8 `NOTIFICATION_FEATURE.md`); một dropdown tại chỗ không
đụng gì tới điều hướng.

Dropdown chỉ liệt kê danh mục **có phát sinh trong 6 tháng** đang vẽ. Liệt kê
mọi danh mục là bắt người dùng cuộn qua hàng chục dòng để tìm ra một đường phẳng
bằng 0.

---

## 4. Kiến trúc mã

```
AnalyticsPage ── AnalyticsCubit ── AnalyticsRepository ── Drift (tx, cat, budget)
                       │                    │
                 hai lựa chọn         phan_loai_dong_tien.dart   ← MỚI
                 trong state          thong_ke_thang.dart        ← thêm 1 hàm
```

### 4.1 Tệp mới `analytics/domain/phan_loai_dong_tien.dart`

Ba thứ cùng một chủ đề, tầng thuần, không import Drift lẫn `material.dart`:

| Thứ | Vai trò |
|---|---|
| `phanLoaiCua()` | Luật ở §2 — **định nghĩa duy nhất** |
| `theoPhanLoai()` | Gom thành 3 lát rời nhau, kèm tỉ lệ |
| `danhMucTheoPhanLoai()` | Danh mục bên trong một lát |

⚠️ `chiTheoDanhMuc()` ở `thong_ke_thang.dart` **giữ nguyên, không đụng** — nó
gom theo *chiều tiền* (`type`) để phục vụ trang Xuất báo cáo, dùng ở **10** chỗ
trong `lib/` và **7** chỗ trong `test/` (đếm bằng máy 2026-09-14). Hàm mới gom
theo *phân loại danh mục* (`classify`). Hai câu hỏi khác nhau; ai gộp chúng "cho
gọn" sẽ làm bảng thu/chi của báo cáo đổi nghĩa mà không test nào ở đó đỏ.

### 4.2 `KhoanThuChi` thêm một trường

Thêm `final String? classify` — repository điền từ bảng `categories` (nó vốn đã
đọc **cả hàng đã xoá mềm**, chính là thứ giữ được tên và phân loại của danh mục
cũ). `null` nghĩa là "nơi gọi chưa điền", và khi ấy luật §2 rơi về `type`.

Cùng khuôn với `ghiChu` thêm hồi làm luật điều chỉnh số dư. `KhoanThuChi(` được
dựng ở **6** chỗ trong `lib/`, thuộc **3** tệp (đếm bằng máy 2026-09-14); trường
mới là tuỳ chọn nên `bao_cao_xuat.dart` không phải sửa gì.

### 4.3 `chuoiTheoDanhMuc()` — một lượt duyệt

Cho mục #7, thêm vào `thong_ke_thang.dart`:

```dart
Map<String?, List<DiemThoiGian>> chuoiTheoDanhMuc(
  List<KhoanThuChi> ds, {required int nam, required int thang, int soThang = 6});
```

Dựng bằng **một** lượt duyệt qua toàn bộ giao dịch, phân vào ô `(categoryId,
tháng)`. **Đừng** gọi `chuoiTheoThang` một lần cho mỗi danh mục: với 30 danh mục
và 5.000 giao dịch đó là 900.000 phép so ngày mỗi lần stream phát, mà stream này
phát lại sau **mọi** chu kỳ đồng bộ.

Mọi luật đếm mượn nguyên `tongThuChi` — biên `[from, to)`, `khoanVaoThongKe()` —
nên ở đây không có luật mới nào. Tháng rỗng vẫn là một điểm mang số 0; bỏ đi là
trục co lại và hai tháng cách nhau nửa năm hiện ra như liền kề (bài học của 2b).

### 4.4 `ThongKeThang` mang thêm ba thứ

Hai trường — `latPhanLoai` (3 lát) và `chuoiDanhMuc` (bản đồ ở §4.3) — cộng một
phép tra `danhMucCua(phanLoai)` trả về danh mục **đã tra tên/màu/biểu tượng và
ngân sách** của một lát, cùng kiểu `DongDanhMuc` mà `danhMuc` đang dùng. Cả ba
dựng ở `AnalyticsRepositoryImpl._dung()`, cùng chỗ với `chi`/`dong`/`chuoi` hôm
nay.

Trường `danhMuc` cũ **giữ lại**: `_DanhSachDanhMuc` đọc nó ở mức gốc, và
`dongCua()` vẫn là đường tra tên cho chú giải donut.

### 4.5 Hai lựa chọn nằm trong state, không nằm trong widget

`AnalyticsLoaded` thêm `phanLoaiDangXem` (`null` = mức gốc) và
`danhMucXuHuong` (`null` = hai đường). Cubit thêm `chonPhanLoai()` và
`chonDanhMucXuHuong()`.

Đặt ở state chứ không ở `StatefulWidget` vì **hai** khối phải đọc cùng một lựa
chọn (§3.2), và vì `bloc_test` kiểm được cái bẫy dưới đây.

---

## 5. Bốn cái bẫy, cả bốn đều hỏng im lặng

1. **Stream phát lại làm mất lựa chọn.** `watchThang` phát lại mỗi khi giao
   dịch, danh mục **hoặc** ngân sách đổi — kể cả khi đồng bộ nền kéo về. Nếu
   Cubit dựng `AnalyticsLoaded` mới mà quên chép hai lựa chọn sang, thì cứ mỗi
   chu kỳ đồng bộ là donut tự nhảy về mức gốc **trong khi người dùng đang xem**.
   Không exception, không log.

2. **Lát rỗng.** Tài khoản không dùng danh mục vay/nợ thì lát ấy bằng 0. Không
   vẽ lát 0 và không cho chạm vào nó; nếu lựa chọn đang trỏ vào một lát mà tháng
   vừa chọn không có, phải tự rơi về mức gốc thay vì hiện một vòng tròn trống.

3. **Danh mục đã chọn biến mất.** Đổi tháng, hoặc danh mục bị xoá, thì
   `chuoiDanhMuc` không còn khoá ấy. Phải rơi về "Tất cả danh mục", không được
   để `null!` nổ.

4. **`FlClipData` mặc định là `none()`** (bẫy 4.17 `ANALYTICS_FEATURE.md`) —
   điểm ngoài dải vẫn được vẽ và tràn khỏi thẻ. Mọi biểu đồ phải đặt
   `FlClipData.all()`. Với một đường duy nhất, dải giá trị hẹp hơn nên chuyện
   này dễ xảy ra hơn bản hai đường.

Thêm hai thứ chỉ lộ trên máy thật: nhãn trục vẽ ở **cả hai biên** cộng mốc theo
`interval` nên hai nhãn cuối chồng nhau (bẫy 4.18), và tên danh mục dài trong
dropdown phải `ellipsis` ở 411dp.

---

## 6. Thử nghiệm

Viết test **đỏ trước**, và phải thấy nó đỏ **đúng lý do**.

| Tệp | Canh gì |
|---|---|
| `test/features/analytics/phan_loai_dong_tien_test.dart` (mới) | Luật §2: rơi về `type` khi mất danh mục; ba lát **rời nhau**, tổng đúng 100%; khoản `transfer`/điều chỉnh/mở sổ không lọt vào lát nào |
| `thong_ke_thang_test.dart` (thêm ca) | `chuoiTheoDanhMuc` giữ tháng rỗng làm điểm 0; **tháng ngắn và năm nhuận**; một lượt duyệt cho cùng kết quả với phép tính từng danh mục |
| `analytics_cubit_test.dart` (thêm ca) | Bẫy 1: stream phát lại **không** làm mất lựa chọn. Bẫy 2 và 3: rơi về mặc định thay vì nổ |
| `analytics_repository_impl_test.dart` (thêm ca) | `classify` được điền từ danh mục **đã xoá mềm** |
| `analytics_page_test.dart` (thêm ca) | Ở 411dp dựng bằng `AppTheme.lightTheme` (bẫy 4.11): chạm lát đổi cả donut lẫn danh sách; tên danh mục dài không tràn |

**Bắt buộc nghiệm thu trên máy ảo** trước khi báo xong. Năm lỗi im lặng của
phiên 2026-09-13 đều lọt qua 2339 ca test xanh.

**Mức nền phải đối chiếu:** `flutter test` 2339/2339 · `flutter analyze` 25
issue, 0 error (đo 2026-09-13). Analytics hiện có **11** tệp test (đếm bằng máy
2026-09-14; `CLAUDE.md` còn ghi 10, số của 2026-09-09 — sẽ sửa trong lượt soát
tài liệu).

---

## 7. Không đụng tới

- **Schema Drift** — giữ v21. Không cột mới, không bảng mới.
- **Đường đồng bộ** — không trường payload mới, `sync_payload_contract_test.dart`
  không đổi.
- **`bao_cao_xuat.dart` và trang Xuất báo cáo** — A8 không nói rõ trang nào; để
  ngoài phạm vi lát này. Nếu sau này muốn đưa lát phân loại vào báo cáo thì
  `theoPhanLoai()` đã dùng lại được nguyên vẹn.
- **Ba thẻ tổng đầu trang** — giữ định nghĩa theo `type`, xem §2.1.
- **`chiTheoDanhMuc()`** — xem §4.1.

---

## 8. Thiết kế Stitch

Người dùng chốt: **cập nhật Stitch trước khi dựng Flutter**.

Màn **"FlowMoney Analytics Dashboard"** (`a228fa69a22442e9a577ac8f5d2d0cea`,
MOBILE) đã được gọi `edit_screens` ngày 2026-09-14 với hai thay đổi: thêm thẻ
"Xu hướng 6 tháng" có dropdown và biểu đồ đường, và đổi thẻ donut thành "Cơ cấu
dòng tiền" ba lát.

⚠️ Công cụ ghi **có độ trễ dài** — "chưa đổi" nghĩa là *chưa biết*, không phải
*thất bại*. Mốc trước khi sửa, để so lại: `htmlCode` =
`files/15981662859376236551`, `screenshot` = `files/8520192458163495776`.
Nghiệm thu bằng cách tải `htmlCode.downloadUrl` về đọc và so `screenshot.name`.

Khối "Xu hướng 6 tháng" vốn **lệch Stitch có chủ ý** từ 2026-09-08 (mục 3.12
`ANALYTICS_FEATURE.md`: tra cả 35 màn, không màn nào có biểu đồ đường hay cột).
Lát này đưa nó **về lại** Stitch, nên ghi chú "đừng sửa cho khớp Stitch" ở
`_KhoiXuHuong` phải được cập nhật chứ không xoá — lý do lệch đã hết hiệu lực.

---

## 9. Thứ tự thi công

1. Test đỏ cho `phan_loai_dong_tien.dart`, rồi tầng thuần.
2. `chuoiTheoDanhMuc()` + test, gồm tháng ngắn và năm nhuận.
3. `KhoanThuChi.classify` + repository điền nó + test.
4. `ThongKeThang` ba trường mới.
5. Cubit hai lựa chọn + test bẫy 1, 2, 3.
6. `_KhoiDonut` drill-down + `_DanhSachDanhMuc` đi theo.
7. Dropdown trên `_KhoiXuHuong`.
8. Nghiệm thu máy ảo 411dp; đối chiếu Stitch.
9. Soát tài liệu: `ANALYTICS_FEATURE.md`, `CLAUDE.md`, `PROJECT_CONTEXT.md`.

---

## 10. Để đợt sau

- **Mục 10 (thác nước)** — dựng được bằng `BarChart` với `fromY/toY` của
  `fl_chart 1.2.0`; số dư đầu kỳ → +thu → −chi → số dư cuối kỳ, hai đầu lấy từ
  `DongTien` đã có. Chưa có `BarChart` nào trong dự án nên đây là kỹ thuật mới.
- **Mục 11 (Sankey)** — `fl_chart` **không có**; phải tự vẽ `CustomPaint`, và
  vùng vẽ không test tự động được (bẫy 4.9).
- **Mục 4, 5, 8, 9** — cần mô hình vay/nợ ở cả hai đầu, xem §1.1.

---

## 11. Một chỗ tài liệu phải sửa cùng lát này

Mục **3.16** `ANALYTICS_FEATURE.md` viết: *"Số dư ban đầu của một ví không phải
là giao dịch (đã kiểm: `lib/features/wallet` không sinh giao dịch nào khi tạo
ví)"*. Câu ấy **đúng khi viết (2026-09-09) và sai từ 2026-09-13**: G37 làm ví
mới sinh khoản mở sổ thật (`8c9aea8`). Giới hạn "ví tạo giữa kỳ làm số dư đầu kỳ
lệch" **vẫn còn**, nhưng lý do đã đổi — nay là vì `khoanVaoThongKe()` cố ý loại
khoản mở sổ khỏi thống kê, chứ không phải vì khoản ấy không tồn tại.
