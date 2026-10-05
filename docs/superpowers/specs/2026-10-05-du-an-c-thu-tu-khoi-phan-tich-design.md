# Dự án C, việc thứ ba — thứ tự khối trang Phân tích theo thói quen xem (mức *học*) — thiết kế

**Ngày:** 2026-10-05. **Trạng thái:** thiết kế người dùng duyệt trong chat (bốn lượt AskUserQuestion: cách áp dụng điều
học được, phần 1 — thứ người dùng thấy, phần 2 — luật học, phần 3 — cấu trúc và nghiệm thu); bản viết người dùng duyệt cùng
ngày (*"ok duyệt"*); **kế hoạch 9 task** `docs/superpowers/plans/2026-10-05-du-an-c-thu-tu-khoi-phan-tich.md` (gitignore,
khối 🔧 *"làm rõ lúc lập kế hoạch"* thắng chỗ tương ứng ở đây) — **chưa có mã**.

Dự án C (mục 10.3 `docs/AI_EDGE_FEATURE.md`): *app học trên máy của từng người*. Việc đầu (gợi ý danh mục theo số tiền)
xong 2026-10-02, việc hai (nhịp chi ngân sách) xong 2026-10-04. Đây là việc thứ ba; việc còn lại sau nó là *thông báo
theo phản ứng* (phần lớn đã có ở B5b).

Nguồn ý tưởng: mục **11.5 (4)** `AI_EDGE_FEATURE.md` — *"Trang có 10 khối mang tiêu đề, thứ tự giống nhau với mọi
người"*, hai mức **rẻ** (khối rỗng tự ẩn — ✅ xong 2026-09-21, mục 3.34 `ANALYTICS_FEATURE.md`) và **học** (việc này).

## 1. Vì sao, và vì sao hình dạng này

### 1.1 Hiện trạng (đọc mã 2026-10-05)

`analytics_page.dart` — `_NoiDung._than()` trả **một danh sách cứng**: Dòng tiền → Thác nước → Thẻ tổng → Dự báo →
Xu hướng → Dòng tiền tự do → Tổng tài sản → Số liệu nhanh → Lịch → Donut → Danh sách danh mục → Theo ví → Top chi →
ba khối Vay/nợ. Thân trang là `SingleChildScrollView` + `Column`, không ảo hoá, không `ScrollController`.

Nhiều khối **cố ý đứng cạnh nhau** (chú thích ngay trong `_than()`): thác nước kể chi tiết hai con số của khối dòng
tiền; ba biểu đồ đường cùng trục hoành; lịch kể chi tiết "ngày chi nhiều nhất" của Số liệu nhanh; danh sách danh mục
đi theo chip của donut. Nên **đơn vị đổi chỗ là CỤM, không phải khối lẻ**.

### 1.2 Thị trường (khảo sát 2026-10-05)

| App | Thứ tự khối trên màn tổng quan / phân tích |
|---|---|
| Monarch | Người dùng **tự** kéo thả và ẩn/hiện thẻ (nút *Customize*; web và mobile giữ thứ tự riêng) |
| PocketSmith | Người dùng **tự** dựng dashboard từ widget |
| Sổ thu chi MISA | Người dùng **tự** chọn báo cáo nhanh và sắp thứ tự ở màn Tổng quan |
| Copilot | Chỉ xếp lại **tab**, không xếp khối trong dashboard |

Không tìm thấy app nào **tự động** xếp lại theo thói quen. Nielsen Norman Group (*Spatial Memory*): giao diện tự xếp
lại phần lớn thất bại vì phá trí nhớ vị trí; cách không phá là vùng riêng cho thứ hay dùng, hoặc chỉ đổi khi người
dùng đồng ý.

Nguồn: help.monarch.com *Customizing Your Dashboard* · learn.pocketsmith.com *Dashboards: How to* ·
help.copilot.money *Dashboard Tab Overview* · helpamis.misa.vn *Thiết lập màn hình Tổng quan* ·
nngroup.com/articles/spatial-memory.

### 1.3 Quyết định của người dùng

**Học rồi đề xuất** — app học cụm hay xem, hiện **một** thẻ đề xuất; người dùng bấm thì thứ tự mới đổi và **giữ
nguyên** từ đó. Vị trí khối không bao giờ tự nhảy. Cùng lối với B5b (*học giờ thông báo — chỉ đề xuất*) và tinh thần
bất biến ④ (*AI điền sẵn, người dùng bấm*).

Đã loại lúc brainstorm: tự động xếp lại mỗi lần mở (phá trí nhớ vị trí) · hàng chip "Hay xem" cuộn tới khối (không
khối nào đổi chỗ — người dùng không chọn) · thêm màn *Tuỳ chỉnh* kéo thả (không làm trong lát này — mục 8).

## 2. Người dùng thấy gì

### 2.1 Chín cụm

Thứ tự mặc định = thứ tự hôm nay. Bên trong cụm, thứ tự khối và mọi chốt ẩn/hiện **giữ nguyên từng dòng**.

| # | Mã lưu | Tên hiển thị | Khối bên trong |
|---|---|---|---|
| 1 | `dong_tien` | Dòng tiền | Dòng tiền trong kỳ · Tiền đi đâu |
| 2 | `tong` | Tổng thu chi | `_KhoiTong` (chip mốc so sánh · thẻ Thu/Chi/Số dư · khối Nhận xét) |
| 3 | `du_bao` | Dự báo 30 ngày | `_KhoiDuBao` |
| 4 | `xu_huong` | Xu hướng | Xu hướng · Dòng tiền tự do · Tổng tài sản |
| 5 | `chi_theo_ngay` | Chi theo ngày | Số liệu nhanh · Lịch chi tiêu |
| 6 | `co_cau` | Cơ cấu danh mục | Donut · Danh sách danh mục |
| 7 | `theo_vi` | Phân bổ theo ví | `_KhoiTheoVi` |
| 8 | `top_chi` | Top khoản chi | `_KhoiTopChi` |
| 9 | `vay_no` | Vay nợ | Cho vay & Thu nợ · Đi vay & Trả nợ · Vay/nợ chưa xếp được vai |

Mã lưu là chuỗi cố định (không lưu `index` của enum — thêm cụm về sau không được làm lệch hàng cũ). Mã lạ đọc từ
CSDL thì **bỏ qua**, không ném.

### 2.2 Thẻ đề xuất

- Chỗ: ngay dưới `_Header` (bộ chọn kỳ), trên cụm đầu tiên. Chỉ ở trạng thái `AnalyticsLoaded` **không rỗng**.
- Chữ: *"Bạn hay xem **‹tên cụm›** — đưa lên đầu trang?"*; nút **Đưa lên** và nút chữ **Bỏ qua**. Hàng nút là `Wrap`
  (bài học thẻ gợi ý 360 dp).
- Nhiều nhất **một** thẻ. Đề xuất chỉ tính lúc trang **vừa hiện ra** (mở tab / quay lại tab) — không bật ra giữa lúc
  đang đọc.
- **Đưa lên:** cụm lên vị trí đầu thân trang ngay; các cụm khác dồn xuống, giữ thứ tự tương đối; thẻ biến mất. Không
  toast (memory *thông báo tối giản*).
- **Bỏ qua:** thẻ biến mất; luật mở lại ở mục 3.4.

### 2.3 Dòng "Về mặc định"

Khi thứ tự hiện tại **khác** mặc định: sau cụm cuối có một dòng chữ nhỏ *"Thứ tự khối đang theo thói quen xem của bạn
· **Về mặc định**"*. Bấm → thứ tự về mặc định ngay, và mọi đề xuất cũ coi như vừa bị bỏ qua (mục 3.4).

### 2.4 Không đổi

- Trang Xuất báo cáo, màn Xem trước, tệp PDF/CSV: giữ thứ tự mặc định. Chú thích ở `_than()` (*"Thứ tự khối chép
  đúng trang Xuất báo cáo"*) sửa thành *thứ tự **mặc định** chép đúng…*.
- Nhánh kỳ rỗng (`thongKe.rong`), nhánh lỗi, nhánh đang nạp: không thẻ, không dòng, không đo.
- Thứ tự nhớ theo **tài khoản trên máy này**; không đồng bộ.

### 2.5 Stitch

Hai thứ mới (thẻ đề xuất, dòng "Về mặc định") đưa lên Stitch **trước khi dựng** (`generate_screen_from_text`, màn
*"Thống kê - Đề xuất thứ tự khối"*), người dùng xác nhận. Timeout không phải thất bại; không gọi lại.

## 3. Luật học

### 3.1 Đo — giây xem theo (ngày, cụm)

Đồng hồ **1 giây**. Mỗi nhịp, cộng 1 giây cho *cụm đang xem* khi đủ **cả bốn**:

1. Trang đang hiện thật: nhánh shell đang chọn **và** không bị route khác đè (`TickerMode` bật) **và** app ở
   `AppLifecycleState.resumed`.
2. Trạng thái là `AnalyticsLoaded` không rỗng, và có `idaccount` từ phiên.
3. Màn **đứng yên**: vị trí cuộn bằng đúng vị trí ở nhịp trước. Nhịp đầu sau khi trang hiện lại không cộng.
4. Lần tương tác gần nhất (chạm xuống bất kỳ đâu trong thân trang, hoặc vị trí cuộn đổi, hoặc trang vừa hiện) cách
   không quá **60 giây**.

*Cụm đang xem* = cụm có phần giao với khung nhìn **cao nhất** (px); hoà → cụm đứng trên; không cụm nào giao → không
cộng. Thẻ đề xuất và `_Header` không phải cụm.

Ngày của một giây là ngày **giờ máy** lúc nhịp nổ, lưu `yyyy-MM-dd`.

Giây gom trong bộ nhớ; ghi xuống CSDL (cộng dồn vào hàng `(idaccount, ngay, cum)`) khi: trang thôi hiện · app rời
`resumed` · widget bị gỡ · mỗi **15 giây** nếu có giây chưa ghi. Mỗi lần ghi dọn hàng cũ hơn **90 ngày**.

### 3.2 Ngày được tính, cụm thắng

- Chỉ xét ngày **đã qua** (`ngay < hôm nay`) trong **30 ngày** gần nhất. Hôm nay không tính — cụm thắng của ngày đang
  dở còn đổi được. Hệ quả: thẻ sớm nhất hiện ở **ngày thứ sáu** có mở trang.
- *Ngày được tính*: tổng giây mọi cụm của ngày ≥ **10**.
- *Cụm thắng của ngày*: cụm nhiều giây nhất; hoà → cụm đứng **trước** theo thứ tự hiện tại (lợi thế cho hiện trạng).

### 3.3 Khi nào đề xuất

Cụm X được đề xuất khi, trên tập ngày được tính của **riêng X** (mục 3.4 thu hẹp tập ấy):

1. số ngày được tính ≥ **5**;
2. X thắng ≥ **60 %** số ngày ấy (chạm là đủ: 3/5);
3. X **chưa** đứng trên mọi cụm có xem: tồn tại cụm đứng trước X trong thứ tự hiện tại có tổng giây > 0 trên tập
   ngày ấy. (Cụm đứng trước mà luôn ẩn — ví dụ Dòng tiền khi lọc — không tính là "đứng trên".)

Nhiều cụm cùng đạt (chỉ xảy ra khi tập ngày của chúng khác nhau) → cụm có tỉ lệ thắng cao nhất; hoà → cụm đứng trước.
Không cụm nào đạt → `null`, **im hẳn**. `null` có một nghĩa: *chưa đủ để nói*.

### 3.4 Bỏ qua và Về mặc định — bằng chứng mới thắng lời từ chối cũ

- Sau **Bỏ qua** X: tập ngày của X chỉ gồm ngày **sau** ngày bấm. Phải có lại ≥ 5 ngày được tính mà X vẫn thắng
  ≥ 60 % thì mới đề xuất lại.
- **Về mặc định** = Bỏ qua cho **mọi** cụm tại ngày bấm (không thì thẻ cũ bật lại ngay lần mở kế).
- **Đưa lên** không đổi tập ngày của cụm nào: X đã đứng đầu nên điều kiện 3 tự chặn X.

Cùng luật với B1 (`tatCapTu`) và B2 (`chonDeXuatHoaDon`).

### 3.5 Thứ tự hiện tại — suy từ nhật ký phản hồi

`thuTuTu(phanHoi)`: bắt đầu từ mặc định, phát lại theo `createdAt` tăng dần — `dua_len(X)` đưa X về vị trí 0;
`ve_mac_dinh` đặt lại mặc định; `bo_qua` không đổi thứ tự. **Không** có cột/khoá nào lưu thứ tự riêng — một nguồn.

## 4. Cấu trúc

### 4.1 Luật thuần — `analytics/domain/thu_tu_khoi.dart` (mới)

- `enum CumKhoi` (`ma`, `ten`), `kThuTuCumMacDinh`, `CumKhoi? cumTuMa(String)`.
- `CumKhoi? cumDangXem(List<KhungCum> cum, double dinh, double day)` — `KhungCum(cum, dinh, day)` cùng hệ toạ độ.
- `List<CumKhoi> thuTuTu(List<PhanHoiThuTu>)`.
- `CumKhoi? deXuatDuaLen({giayXem, phanHoi, thuTu, now})` — mục 3.2–3.4.
- Hằng: `kGiayToiThieuNgay = 10`, `kNgayToiThieuDeXuat = 5`, `kTiLeThangDeXuat = 0.6`, `kCuaSoNgayDeXuat = 30`,
  `kGiayImToiDa = 60`, `kNgayGiuGiayXem = 90`; mã phản hồi `kThuTuDuaLen` / `kThuTuBoQua` / `kThuTuVeMacDinh`.

Dart thuần, không import Flutter / Drift.

### 4.2 Lưu trữ — schema **v29**, hai bảng **cục bộ**

| Bảng | Cột | Khoá |
|---|---|---|
| `PhanTichGiayXems` | `idaccount` · `ngay` (text `yyyy-MM-dd`) · `cum` (text) · `giay` (int) | `(idaccount, ngay, cum)` |
| `PhanTichThuTuPhanHois` | `id` (text) · `idaccount` · `cum` (text, rỗng với `ve_mac_dinh`) · `ketQua` · `createdAt` | `id` |

- Không `syncStatus` / `updatedAt` / `isDeleted` — cùng lý lẽ quy tắc 9 `CLAUDE.md`. Thêm tên bảng / DAO vào **test
  quét 15** (`ai_edge_cuc_bo_khong_dong_bo_test.dart`).
- Xoá theo tài khoản ở `purgeDataForOtherAccounts` **và** `purgeDataForAccount`.
- Migration `from < 29`: chỉ `createTable` hai bảng. Test `schema_v29_test`; các test khoá số phiên bản đổi theo.
- `ThuTuKhoiDao`: `congGiay(idaccount, ngay, {cum: giay})` (cộng dồn, một giao tác, kèm dọn > 90 ngày) ·
  `giayXemTu(idaccount, tuNgay)` · `phanHoi(idaccount)` · `ghiPhanHoi(...)`. Mọi truy vấn đọc lọc `idaccount`.
- `ThuTuKhoiNguon` (data): ghép DAO với luật thuần → `Future<(List<CumKhoi> thuTu, CumKhoi? deXuat)> doc(idaccount,
  now)`; phần phụ — hỏng thì trả `(mặc định, null)` và `debugPrint`, không làm hỏng trang.

### 4.3 Giao diện

- **`ThuTuKhoiCubit`** (riêng, **không** nhét vào `AnalyticsCubit` — stream của cubit ấy phát lại sau mỗi chu kỳ đồng
  bộ, bẫy 3.19): state `(thuTu, deXuat)`; `nap(idaccount)` · `duaLen(cum)` · `boQua(cum)` · `veMacDinh()`. Ba thao
  tác ghi phản hồi rồi `nap` lại. Cấp cùng chỗ với `AnalyticsCubit` (cùng `ValueKey(idaccount)`).
- **`_than()`** tách làm hai: `_cacCum(...)` trả `Map<CumKhoi, List<Widget>>` (đúng các widget và chốt hôm nay, cụm
  không có khối nào thì vắng khỏi map) và phần xuất theo `thuTu`, mỗi cụm bọc trong một widget mang `GlobalKey` (để
  đo) — khoảng cách 24 giữa các khối giữ như hôm nay.
- **`_TheoDoiXem`** (StatefulWidget, `WidgetsBindingObserver`): giữ `ScrollController`, đồng hồ, bộ gom giây; nghe
  `TickerMode.getNotifier(context)`; gọi `ThuTuKhoiCubit.nap` khi trang **vừa hiện lại**. Nguồn giờ và hàm ghi tiêm
  được cho test.
- **`TheDeXuatThuTu`** và **`DongVeMacDinh`**: widget công khai nhỏ ở `analytics/presentation/widgets/`, test riêng.

## 5. Thứ hỏng im lặng — chốt trước

1. **Đồng hồ chạy khi trang khuất.** Tab Phân tích là `StatefulShellBranch`: sang tab khác State **vẫn sống**. Thiếu
   vế `TickerMode` là giây cứ cộng cho cụm đang nằm trên màn lúc rời đi — và nó sẽ thắng mọi ngày. `flutter test` gần
   như mù (cần `GoRouter` + `MainShell` thật) → có ca widget với `TickerMode(enabled: false)` bọc ngoài **và** nghiệm
   thu máy thật (mục 7).
2. **Hai nguồn cho thứ tự.** Thứ tự chỉ suy từ `thuTuTu`; widget không giữ bản sao sống lâu hơn một lượt `nap`.
3. **Ghi giây theo `index` enum** — cấm; mã chuỗi (mục 2.1).
4. **Hôm nay lọt vào phép đếm** → thẻ bật ra ngay trong buổi đang đọc và cụm thắng đổi qua lại. Ca test canh.
5. **Về mặc định mà không coi là Bỏ qua** → thẻ cũ bật lại ở lần mở kế. Ca test canh.
6. **Thẻ ở đầu trang đẩy mọi thứ xuống** → các ca cuộn / `tap` cuối trang của `analytics_page_test` có thể **trượt**
   (tap trượt chỉ cảnh báo). Fixture mặc định của bộ test không có đề xuất; soát lại sau khi nối.
7. **Ghi mỗi giây một lần** → mòn pin / tranh khoá SQLite với đồng bộ. Gom trong bộ nhớ, ghi theo mục 3.1.

## 6. Kiểm thử

- `thu_tu_khoi_test` (thuần): `cumDangXem` (giao lớn nhất, hoà, không giao) · `thuTuTu` (đưa lên hai lần, về mặc
  định, mã lạ) · `deXuatDuaLen` — 4 ngày → im; 3/5 → đề xuất; 2/5 → im; ngày < 10 giây không tính; hôm nay không
  tính; ngoài 30 ngày không tính; cụm đã đứng đầu → im; cụm trước luôn ẩn → im; hoà giây → cụm trước thắng; sau Bỏ
  qua cần 5 ngày **mới**; sau Về mặc định im; hai cụm cùng đạt → tỉ lệ cao hơn.
- `schema_v29_test`, `thu_tu_khoi_dao_test` (cộng dồn, lọc tài khoản, dọn 90 ngày, purge), test quét 15.
- `thu_tu_khoi_nguon_test` (DAO ném → mặc định + `null`).
- `thu_tu_khoi_cubit_test`.
- Widget: thẻ đề xuất ở 360 dp với tên dài nhất (không tràn, dựng bằng `AppTheme.lightTheme`); `analytics_page`
  — thứ tự mặc định y hôm nay khi không có phản hồi (ca canh **không đổi gì cho người chưa bấm**); đưa lên → cụm ấy
  đứng đầu; dòng "Về mặc định" chỉ hiện khi thứ tự khác mặc định; kỳ rỗng không thẻ; `_TheoDoiXem` — đứng yên cộng
  giây, cuộn không cộng, `TickerMode` tắt không cộng, quá 60 giây không tương tác thôi cộng, rời trang thì ghi.
- Mỗi ca "im" / "không cộng" kiểm bằng **bản sai có chủ ý** (ca xanh ngay là ca không canh gì).

## 7. Nghiệm thu

- `flutter test` so mốc **5826** (+ ca mới), `flutter analyze` **26**.
- **Máy thật** (máy đang cắm; Realme là máy dùng hằng ngày — hỏi trước khi điều khiển), bản **debug**:
  1. Đồng hồ thật: dừng ở một cụm ~20 giây → hàng của hôm nay tăng ~20; sang tab khác 30 giây rồi quay lại → **không
     tăng**; tắt màn hình → không tăng.
  2. Bơm 5 ngày giây xem (công cụ chạy tay `test/tool/…`, `skip`, ghi vào bản CSDL chép ra rồi đẩy lại — không thêm
     đường nào vào bản release) → mở trang: thẻ hiện đúng cụm → **Đưa lên** → cụm đứng đầu, còn nguyên sau khi tắt mở
     app → dòng cuối trang → **Về mặc định** → thứ tự cũ, thẻ im → bơm lại → **Bỏ qua** → im.
  3. 360 dp: cụm *Xu hướng* (cao nhất) ở đầu trang không tràn, không sọc vàng.

## 8. Ngoài phạm vi

- Màn *Tuỳ chỉnh* kéo thả / ẩn cụm (lối Monarch / MISA).
- Tính lượt chạm vào khối.
- Thứ tự theo đơn vị kỳ (tuần / tháng…) — một thứ tự cho mọi kỳ.
- Trợ lý AI nhắc tới thói quen xem; gói số không đổi.
- Trang Xuất báo cáo / tệp xuất.

## 9. Tài liệu phải cập nhật khi thi công

`ANALYTICS_FEATURE.md` (mục mới + bảng thị trường 1.2) · `AI_EDGE_FEATURE.md` 11.5 (4) và dòng trạng thái dự án C ·
`PROJECT_CONTEXT.md` mục 14 · `CLAUDE.md` (hàng *Đụng vào trang Phân tích*, schema v29, mốc test) · chú thích
`_than()`.
