# Trang Phân tích — thiết kế, lý do, và những cái bẫy

**Cập nhật:** **2026-09-18** (mục **3.33** — **trang Xuất báo cáo dùng chung bộ chọn kỳ với trang Phân tích**: nay xuất được theo **tuần** và **năm**, thứ bốn chip cứng cũ không làm được; `PhamViThoiGian` và `khoangCuaPhamVi` **bỏ hẳn**. Người dùng chốt **không** đưa khối nào của trang Phân tích vào tệp, sau khảo sát bảy app thị trường: **0/7** app xuất cả màn phân tích ra tệp, và **6/7** chỉ xuất CSV thuần dữ liệu. ⚠️ Kèm **`nhanRong`** — hàm nhãn **thứ hai** cho chỗ không chật, sinh ra từ một lỗi **chỉ máy ảo thấy**: nút hiện "Tuần 37" trần trong khi dòng vừa chạm nói "Tuần 37 (07/09 – 13/09)". Nó cũng thay một bản chép tay trong `ChonPhamViSheet`; mục **3.32** — **kỳ rỗng thì tệp xuất thôi in khối Ngân sách**, đóng **G44**: người dùng chốt chiều *"tệp theo màn"*, và luật nay là vị từ thuần `inKhoiTheoKy` mà **ba** chỗ cùng đọc — CSV, PDF, màn Xem trước. ⚠️ Lượt sửa **đính chính** điều lượt nghiệm thu 3.31 tưởng là đúng: màn Xem trước **không** giấu "mọi khối" khi kỳ rỗng, nó vẫn hiện đầu báo cáo, khối Dòng tiền và ba thẻ tổng — hai bên lệch **đúng một khối**. ⚠️ Và ca test cho nhánh **PDF** phải so **độ dài tệp** chứ không tìm chuỗi, vì PDF **nén** luồng nội dung; một ca `contains(...)` sẽ xanh trên cả bản sai) · **2026-09-17** (mục **3.31** — **ba khối cuối vào tệp xuất**: so với kỳ trước, số liệu nhanh, top 5 khoản chi; kèm ⚠️ một lỗi glyph **có từ 2026-09-09** mà lượt này mới bắt được — Roboto nhúng không có `→` `▲` `▼`, gói `pdf` bỏ chúng đi **im lặng**, nên mọi tệp PDF app từng xuất đều mất mũi tên ở dòng dòng tiền; nay có ca test quét glyph canh, và mục **3.17** đã được đính chính; bảng khảo sát lần hai ở mục **3.25** nay **ĐÓNG** — mục cuối là **#7 cảnh báo bất thường**, làm xong cùng ngày nhưng nằm ở `NOTIFICATION_FEATURE.md` mục **5f** chứ không ở trang này; mục **3.30** — **tổng tài sản theo thời gian**, mục #5 của khảo sát lần hai, và **đổi tên** khỏi "tài sản ròng" vì app không có mô hình công nợ; kèm vế **thứ ba** của bẫy **4.21** — `daiTrucDuBao` quá rộng với dải bắt đầu từ 0) · 2026-09-15 (mục **3.20** — **P1: phạm vi thời gian**; mục **3.21** — **P2**: bốn khối mượn từ trang Xuất báo cáo; mục **3.22** — **A8 #4 và #5**: hai biểu đồ cột vay/nợ; **G40 đóng** — trang Xem trước báo cáo lệch cột số tiền ở **sáu** chỗ, đo được 93px, xem bẫy **4.19**; **nhãn quý rút thành `Q3 2026`** để ô header thôi cụt, xem mục **3.20**; mục **3.23** — **A8 #10**: thác nước "Tiền đi đâu", kèm vạch trung bình trên từng cột chi; mục **3.24** — **A8 #8**: dòng tiền tự do, và bẫy **4.20** — `rutGon` từng in `-0` ở nhãn trục; mục **3.25** — **khảo sát app thị trường lần hai**, chốt làm tỷ lệ tiết kiệm và dự báo dòng tiền, bỏ hai mục thiếu trường đối tác; mục **3.26** — **tỉ lệ tiết kiệm**) · **2026-09-16** (mục **3.27** — **dự báo dòng tiền 30 ngày tới**, mục #4 của khảo sát; kèm bẫy **4.21** — khi nào trục từ 0, khi nào co, và vì sao bước phải tròn) · bản trước 2026-09-14 (mục **3.19** — A8 #3, #7: cơ cấu theo danh mục với ba chip nhóm, và xu hướng tới 5 danh mục cùng lúc; bản thi công **lần hai**, #2 đã bỏ)
**Trạng thái:** **mảng Phân tích đã xong cả 2a, 2b, 2c** (2026-09-09). Lát **2a** xong — mọi con số trên trang là số thật từ SQLite —
lát **2b** xong (khối "Xu hướng 6 tháng" vẽ bằng `fl_chart`), lát **2c‑1** xong
(trang Xuất báo cáo đọc ví/danh mục/thời gian thật rồi mở màn **Xem trước báo
cáo**), và lát **2c‑1b** xong cùng ngày: báo cáo nay có **mười khối** thay vì
bốn — dòng tiền, so với kỳ trước, biểu đồ, số liệu nhanh, thu theo danh mục,
ngân sách, phân bổ theo ví, top 5 khoản chi. Lát **2c‑2** xong: nút "Tải xuống" sinh tệp **PDF hoặc CSV** thật và **lưu
thẳng vào thư mục Tải về** của máy. Xem mục 7.

> Cùng mục đích với `GOAL_FEATURE.md`: giữ lại **vì sao**. Cái gì thì đọc mã và
> test là ra.

---

## 1. Đọc gì trước khi đụng vào

| Việc | Đọc |
|---|---|
| Bất cứ việc gì | Mục 3 (quyết định) và mục 4 (bẫy) |
| Sửa phép tính | `domain/thong_ke_thang.dart` và test của nó — **không** có CSDL, kiểm bằng danh sách |
| Sửa cách gộp dữ liệu | Mục 3.3 (mốc tra ngân sách) trước, rồi `data/analytics_repository_impl.dart` |
| Đụng giao diện | **Chín** màn Stitch còn dùng được (đếm lại 2026-09-17, sau khi thêm **`b0a3344924d246f9b6322fb75a3309e4`** *"Thống kê - Tổng tài sản 6 tháng gần đây"* cho mục **3.30** — lượt gọi ấy cũng **trả về `timeout`** mà màn vẫn được tạo, **lần thứ ba** xác nhận; mốc **Tám** là của 2026-09-16, sau khi thêm **`9020ff8b5c5d49c4914442dcd02fa540`** *"Thống kê - Lịch chi tiêu Heatmap"* cho mục **3.29** — lượt gọi ấy **trả về `timeout`** mà màn vẫn được tạo, và ⚠️ nó vẽ lưới **xanh lá** trong khi bản thi công dùng **đỏ**; và trước đó **`6333b8e24aab4f92bd73b1282c56b17c`** *"Thống kê - Mốc so sánh kỳ"* cho hàng chip của mục **3.28** — ⚠️ màn ấy cũng mang `deviceType: DESKTOP` dù lượt gọi truyền `MOBILE`, và lượt gọi **không** timeout; mốc "Sáu" là của 2026-09-15, đừng cộng dồn mà hãy đếm lại): `c8567243…` *"Thống kê - Cơ cấu danh mục & Xu hướng 6 tháng"* (2026-09-14) cho thân trang, **`83993fc9f5de4c5f8fba6940480c164a`** *"Thống kê - Chọn phạm vi thời gian"* (2026-09-15) cho bộ chọn phạm vi, **`6e9007f7653749a893c88e3de535afa5`** *"Thống kê - Biểu đồ Cho vay & Đi vay"* (đo được 2026-09-15) cho hai biểu đồ vay/nợ, và **`afe1c3fdee43464c90ddadc508eaa599`** *"Thống kê - 4 Thẻ Dòng Tiền & Kế Toán"* (đo được 2026-09-15) cho bốn khối của P2, **`52450ac549df42aea9f31d5ee1347ceb`** *"Thống kê - Biểu đồ thác nước Tiền đi đâu"* (đo được 2026-09-15) cho khối A8 #10, và **`212befc8f9a24d25ab027c7302e2e122`** *"Thống kê - Biểu đồ Dòng tiền tự do"* (đo được 2026-09-15) cho khối A8 #8 — ⚠️ màn thứ tư mang `deviceType: DESKTOP` dù lượt gọi truyền `MOBILE`, xem mục **3.21** — ⚠️ màn thứ ba vẽ thêm **hai thẻ tổng** mà bản thi công **cố ý không có**, xem mục 3.22 — ⚠️ **hai** màn cũ đã lỗi thời và vẫn còn trong dự án: `c2a2b615…` (tả A8 #2 đã bỏ: mức gốc ba lát + dropdown) và `a228fa69…` "FlowMoney Analytics Dashboard"; và mục 4.4 về font của bộ test |
| Đụng biểu đồ | Mục **3.11** (vì sao `fl_chart`, vì sao ghim phiên bản), **3.12** (khối xu hướng từng lệch Stitch, nay hết), **3.19** (đường một danh mục), **3.30** (trục co theo dữ liệu — và vì sao `daiTrucDuBao` phải kiểm điều kiện thật thay vì trừ hao), bẫy **4.21** (khi nào trục từ 0, khi nào co, và bước phải tròn), và bẫy **4.9** (tooltip tràn — thứ duy nhất phải kiểm bằng mắt) |
| Sinh tệp PDF/CSV | Mục **3.17** (vì sao nhúng font, vì sao `MediaStore` chứ không phải quyền ghi bộ nhớ), **3.18** (ba luật của CSV cho Excel tiếng Việt), **3.31** (ba khối cuối vào tệp — và ⚠️ **Roboto nhúng không có mũi tên lẫn hình học**, nên `→ ▲ ▼` bị bỏ đi im lặng), **3.32** (⚠️ kỳ rỗng chở gì — `inKhoiTheoKy` là định nghĩa duy nhất, và ca test cho PDF phải so **độ dài tệp** vì PDF nén luồng nội dung), bẫy **4.15**–**4.16** |
| Đụng trang Xuất báo cáo / màn Xem trước | Mục **3.13** (vì sao xem trước rồi mới tải), **3.14** (ảnh chụp, không phải luồng sống; và màn Stitch mới), **3.15** (mười khối lấy chuẩn từ app thị trường), **3.16** (dòng tiền là số suy ngược, hai giới hạn), **3.32** (⚠️ **kỳ rỗng**: màn và tệp phải nói giống nhau, và `inKhoiTheoKy` là nơi duy nhất ghi luật ấy — ngân sách là khối **duy nhất** không tự rỗng theo kỳ rỗng), **3.33** (⚠️ trang này nay dùng **chung** bộ chọn kỳ với trang Phân tích; `PhamViThoiGian` đã bỏ, và `Ky.tuyChon` **không** tự cộng một ngày như `khoangCuaPhamVi` cũ — cộng thêm phép khảo sát vì sao tệp **không** chở khối nào của trang Phân tích), bẫy **4.11**–**4.14** |
| Làm tiếp 2c‑2 (sinh tệp) | Mục 7 |

---

## 2. Hiện trạng trước 2026-09-08 — vì sao phải làm

`analytics_page.dart` dài 1055 dòng nhưng chỉ import `app_colors` và
`go_router`: **không chạm CSDL, không DAO, không repository**. Mọi con số là
hằng số — kể cả tháng đang hiện: `'Tháng này (T6 2026)'` khi hôm ấy là
**08/09/2026**. Một tab trong thanh điều hướng chính nói dối về tiền của người
dùng, và sai cả tháng ngay trên màn hình.

Tài liệu bàn giao trước đó ghi vùng này là "chỉ có `presentation/pages`, không
domain/data/bloc". Đúng, nhưng chưa đủ: nó không nói trang **hiện số giả**.

---

## 3. Các quyết định, và phương án đã loại

### 3.1 Không vẽ lại — bố cục Stitch khớp từng khối

Màn Stitch "Analytics Dashboard" có đúng những khối trang cũ đã chép sang:
chọn tháng → Tổng thu / Tổng chi (kèm % so tháng trước) → "Số dư còn lại" →
donut "Chi tiêu theo hạng mục" với **bốn** ô chú giải → "Chi tiết danh mục" với
"% ngân sách". Việc của 2a là **thay số**, không phải thay hình.

> ⓘ Đoạn trên mô tả bố cục **năm 2026-09-08**. Khối donut nay tên *"Cơ cấu dòng
> tiền"* và có hai mức — mục **3.19**; tên cũ giữ ở đây vì nó là lịch sử của
> quyết định, không phải mô tả hiện trạng.

Donut hiện có là `SweepGradient` tự vẽ, nên 2a **không cần thư viện biểu đồ**;
quyết định chọn thư viện lùi sang 2b và đã chốt ở đó — `fl_chart`, xem mục
**3.11**. Donut vẫn giữ nguyên `SweepGradient`, **không** viết lại bằng
`fl_chart`: nó đang đúng và đang có test, đổi sang thư viện chỉ để "cho đồng
bộ" là rủi ro thuần.

### 3.2 Tầng thuần tách khỏi Drift

`domain/thong_ke_thang.dart` nhận `KhoanThuChi` (ngày, số tiền, loại, danh
mục) — bốn thứ, không phải cả hàng Drift. Vì lớp lỗi ở đây hỏng **im lặng**:
một khoản đếm hai lần ở biên tháng, một khoản chuyển ví bị coi là chi, tháng 2
năm nhuận mất ngày 29 — không exception nào, chỉ con số khác đi. Kiểm được
bằng danh sách thì mới có test đủ nhiều để đáng tin.

Ba luật mượn nguyên từ ngân sách, **đừng viết lại**:

- **Biên `[from, to)`**, `to` **mở** — bộ chọn ngày trả về 00:00, nên khoản
  ghi ngày đầu tháng sau nằm đúng mốc `to` của tháng trước; đóng biên là đếm
  nó ở cả hai tháng. Bản sai có chủ ý dùng `!isAfter(to)` đã làm đúng test này
  đỏ.
- **`'transfer'` không phải thu, không phải chi.** Nạp mục tiêu và chuyển giữa
  hai ví là tiền đổi chỗ. Đếm nó là mỗi kỳ trích tự động vào mục tiêu làm
  "Tổng chi" tăng — đúng lỗi mục 3.2 `GOAL_FEATURE.md` đã sửa ở thống kê cũ.

  ⚠️ Luật ấy nay có **một định nghĩa duy nhất** ở
  `analytics/domain/khoan_vao_thong_ke.dart`, và nó loại **ba** thứ vì **ba** lý
  do khác nhau — trước đó câu `!= 'transfer'` bị chép tay ở **năm** chỗ:

  | Bị loại | Vì sao |
  |---|---|
  | `'transfer'` | tiền **đổi chỗ**, không rời tài sản người dùng |
  | khoản **điều chỉnh số dư** (2026-09-10) | phép **sửa sổ**; đếm nó là tháng nào đối soát ví cũng thấy thu nhập tăng vọt |
  | khoản **mở sổ** — `Số dư ban đầu` (2026-09-13) | **điểm neo** để số dư ví suy được từ sổ; đếm nó là mỗi ví người dùng tạo ra lại làm thu nhập tháng ấy tăng đúng bằng số dư ban đầu |

  Hai loại sau nhận dạng bằng **cặp** điều kiện (không danh mục **và** tiền tố
  ghi chú), không chỉ ghi chú: `transaction.Note` sửa được, và mất dấu hiệu là
  chúng lặng lẽ thành thu nhập thật — sai một **con số**, không chỉ một nhãn.
- **Nghe stream rồi tính lại**, không cache: trang chủ nhúc nhích ngay khi ghi
  một khoản, trang này cũng phải vậy.

### 3.3 Mốc tra ngân sách cho tháng đã qua

Cột "% ngân sách" mượn `BudgetRepository.watchBudgets(idaccount, now:)` — tham
số `now` có sẵn, nên không tính lại số đã chi lần thứ hai. Nhưng **kỳ ngân sách
không trùng tháng dương lịch**, nên phải chọn một điểm trong tháng để hỏi:

- Tháng hiện tại → đúng "bây giờ", để số khớp trang Ngân sách.
- Tháng đã qua → **giây cuối của tháng ấy**, để ngân sách nào còn sống tới cuối
  tháng vẫn được tính.

Đây là **xấp xỉ có chủ ý**: một ngân sách bắt đầu ngày 15 thì "% ngân sách" của
tháng ấy đo theo kỳ chứa ngày cuối tháng. Chấp nhận được vì nhãn nói "% ngân
sách" chứ không nói "% ngân sách của tháng này".

`watchBudgets` trả **cả** ngân sách đã hết hạn (trang Ngân sách tự chia tab), nên
repository **phải lọc** `isExpired(mốc)`. Bản sai có chủ ý bỏ dòng ấy: một ngân
sách chết từ tháng 6 vẫn ra "10% ngân sách" ở tháng 9 — test bắt được.

### 3.4 Không bịa ngân sách: đổi nhãn thay vì hiện "0%"

Danh mục có ngân sách đang chạy → *"x% ngân sách"* (`spent / amount`). Không có
→ *"x% tổng chi"*. Hai nhãn khác nhau cho hai câu hỏi khác nhau; "0% ngân sách"
cho một hạn mức không tồn tại là số bịa.

### 3.5 "Số dư còn lại" = thu − chi của tháng đang xem

Không phải tổng số dư ví — cái đó đã ở trang chủ, lặp lại là vô nghĩa. Thanh =
còn lại / thu (thu bằng 0 thì thanh 0). Chi vượt thu → **số âm hiện là số âm**,
màu đỏ nhạt, thanh 0. Kẹp về 0 là giấu đi việc tháng này đã âm — người dùng mở
trang này chính là để biết điều đó.

### 3.6 So với tháng trước: `null` chứ không phải ∞

Tháng trước bằng 0 → *"Không có dữ liệu T8"*. "Tăng ∞%" hay "tăng 100%" đều là
số bịa; người dùng đọc "tăng 100%" sẽ tưởng tháng trước có một nửa.

### 3.7 Donut: top 4 + "Khác"

Chú giải của thiết kế có đúng bốn ô. Lát thứ năm — dù chỉ có một — gom thành
"Khác" chứ không hiện tên thật, nếu không chú giải thiếu ô. Thiếu lát "Khác"
thì vòng donut hở một khoảng trông như lỗi vẽ. Bảng "Chi tiết danh mục" thì
liệt kê **đủ**, hoà thì sắp ổn định theo id để hai lần vẽ không đảo chỗ.

### 3.8 Ba chữ cho ba ca danh mục — và tra cả hàng đã xoá mềm

*"Ăn uống"* (có hàng, **kể cả đã xoá mềm**), *"Chưa phân loại"* (`categoryId`
null), *"Danh mục đã xoá"* (id có nhưng **không còn hàng nào** — chưa từng đồng
bộ về). Gộp hai ca sau làm một là người dùng không biết mình cần phân loại hay
đã lỡ xoá danh mục. Khoản chưa phân loại **vẫn được gom** — bỏ rơi nó là tổng
các lát nhỏ hơn tổng chi trên thẻ, hai con số cãi nhau trên cùng màn hình.

Repository **không** dùng `categoryDao.watchAll` (lọc `deletedAt`) mà tự truy
vấn bảng, vì tên của danh mục đã xoá mềm vẫn nằm trong hàng. Máy thật dạy điều
này: 5 danh mục mặc định bị xoá mềm hôm 2026-09-07 làm cả một lát donut mang
tên *"Danh mục đã xoá"* trong khi tên thật *"Chi khác"* còn nguyên. Bản sai có
chủ ý đổi lại `watchAll` đã làm đúng test ấy đỏ.

Ba ca không có màu thật phải ra **ba màu khác nhau** (`_mauCua`): trên máy
thật, "Chưa phân loại" và "Danh mục đã xoá" từng cùng xanh dự phòng nên hai lát
donut không phân biệt được — test không bắt vì test không nhìn màu.

### 3.9 Tháng rỗng nói rỗng

Không vẽ toàn số 0: donut của một tháng rỗng là một vòng tròn xám với chữ "0"
ở giữa — trông như lỗi tải dữ liệu. Cùng bài học với *"0 khoản · đã gửi 0 đ"*
ở lịch sử mục tiêu.

### 3.10 "Xem tất cả" là bottom sheet, và trang chỉ dựng 5 dòng

Cùng lý do với lịch sử mục tiêu (mục 3.24 `GOAL_FEATURE.md`): danh sách trên
trang không ảo hoá, và route mới phải trả lời "nằm trong `StatefulShellRoute`
không" — đặt nhầm là màn đỏ (bẫy 7.8 `NOTIFICATION_FEATURE.md`).

### 3.11 `fl_chart`, không tự vẽ Canvas — và ghim phiên bản

Lát 2b là chỗ **chọn thư viện biểu đồ một lần** cho cả biểu đồ tiến độ mục
tiêu về sau (hạng 1, mục 10.5 `GOAL_FEATURE.md`). Đo được ngày 2026-09-08
trước khi chọn: `pubspec.yaml` **không có thư viện biểu đồ nào**, và `lib/`
**không có một `CustomPainter` nào cả** — donut chỉ là `SweepGradient` trên
một `Container` tròn. Nghĩa là "dự án có tiền lệ tự vẽ" **không đúng**: chưa
chỗ nào từng chạm Canvas API.

Phương án đã loại và lý do:

- **Widget thuần** (mỗi cột một `Container` trong `Row`). Ưu điểm thật là test
  được đúng chiều cao tỉ lệ, còn thư viện thì vẽ vào canvas nên widget test
  chỉ khẳng định được widget tồn tại. Loại vì **hình thức quan trọng hơn** ở
  đây, và vì cái được kia lấy lại được bằng cách khác — xem đoạn cuối mục này.
- **`CustomPainter` tự vẽ.** Loại vì đường cong, trục, nhãn, tooltip và
  animation đều phải viết tay để ra kết quả xấu hơn, rồi phải nuôi mãi.

Ba điều **không** phải lý do chọn, ghi ra để không ai viện dẫn nhầm về sau:
hiệu năng (`fl_chart` bên trong cũng là `CustomPainter`, nhưng với sáu điểm dữ
liệu thì chênh lệch không đo được), kích thước app (thêm phụ thuộc chỉ làm nó
lớn hơn), và "thư viện thì chuẩn hơn". Lý do thật chỉ có một: **công sức cho
các biểu đồ tiếp theo**.

Phiên bản **ghim chính xác `1.2.0`**, không `^`, lệch quy ước của mọi phụ thuộc
khác trong `pubspec.yaml`. Cố ý: `fl_chart` đổi API giữa các bản, và biểu đồ
hỏng thì **hỏng lặng lẽ** — vẽ ra hình khác chứ không ném lỗi, nên một bản nâng
âm thầm sẽ không có gì bắt được. Nới ra thì phải xem lại biểu đồ trên máy thật.

Phần test không mất gì: **phép tính nằm trọn ở `chuoiTheoKy()` tầng domain**
và được kiểm bằng danh sách ở đó. Lỗi âm thầm nằm trong con số chứ không trong
nét vẽ. Widget test chỉ còn canh ba thứ mà nó canh được thật: khối có mặt,
**nhãn trục lấy từ dữ liệu** (bản sai có chủ ý đổi nhãn thành `T${i + 1}` đã
làm đúng test ấy đỏ), và 411dp không tràn.

### 3.12 Khối xu hướng từng **lệch Stitch có chủ ý** — nay đã hết

Đã tra cả 35 màn Stitch ngày 2026-09-08: màn "Analytics Dashboard" chỉ có
`conic-gradient` (donut) và màn "Chi tiết mục tiêu" chỉ có một `<svg>` vòng
tiến độ. **Không màn nào có biểu đồ đường hay cột.** Nghĩa là bản thiết kế trả
lời được *tiền đi đâu* nhưng không chỗ nào trả lời *đang tăng hay đang giảm*.

Khối nằm **giữa** khối tổng và donut, theo thứ tự câu hỏi: bao nhiêu → xu hướng
ra sao → đi vào đâu.

✅ **Lý do lệch đã hết hiệu lực từ 2026-09-14** (mục **3.19**): khối này nay
**có** trên Stitch — màn `c8567243df704268ac766aa60ffa5036`, *"Thống kê - Cơ cấu
danh mục & Xu hướng 6 tháng"*. Ghi chú ở `_KhoiXuHuong` đã được cập nhật
chứ không xoá, vì nó ghi lại *vì sao* khối từng đứng ngoài thiết kế.

Sáu tháng chứ không mười hai: ở 411dp, mười hai mốc trục là nhãn chồng lên
nhau. Chuỗi vẫn nhận `soThang` bất kỳ nên đổi được, nhưng phải xem lại trục.

Hai đường có **chú giải chữ** ("Thu" / "Chi") chứ không chỉ dựa vào màu:
xanh/đỏ là quy ước chứ không hiển nhiên, và người mù màu đọc không ra.

---

### 3.13 2c — **xem trước trong app**, tải xuống là bước sau

Câu hỏi thật của trang Xuất báo cáo là *nút "Xuất" làm gì*. Hai hướng đã trình:
sinh tệp thật ngay (PDF/CSV — thêm thư viện, thêm quyền, phần ghi tệp không
test tự động được), hay chỉ mở một màn xem trước. Người dùng chọn hướng thứ hai
**kèm một nút tải xuống trên chính màn xem trước** (2026-09-09).

Hệ quả chia việc: **2c‑1** (lát này) là bộ lọc thật + tầng thuần + màn Xem
trước, **không thêm phụ thuộc nào**; **2c‑2** là nút Tải xuống sinh tệp thật.
Giữa hai lát, nút "Tải xuống" để `onPressed: null` — **tắt hẳn**, có test canh.
Một nút bấm được mà không ra tệp chính là kiểu "nút xuất chỉ hiện snackbar" mà
lát này đang đi dọn. *(2c‑2 đã xong cùng ngày, nên nút nay **chạy thật** — đoạn
này giữ lại vì nó là lý do của cách làm, không phải mô tả hiện trạng.)*

Ba khối của bản Stitch đã **bỏ** vì không có gì đỡ phía sau: "Lịch sử xuất gần
đây" (bịa hoàn toàn — muốn thật thì cần một bảng cục bộ), ô "Đặt mật khẩu bảo
vệ file PDF", và dòng "Đích đến: Lưu vào Tải về". Ô `.xlsx` cũng bỏ: nó cần
thêm một thư viện nữa mà `.csv` đã phục vụ đúng nhu cầu "phù hợp tính toán".

### 3.14 Màn Xem trước là **ảnh chụp**, không phải luồng sống

`BaoCaoRepository.layBaoCao` trả `Future`, không `Stream` — ngược với
`AnalyticsRepository.watchKy` (tên cũ `watchThang` tới 2026-09-15). Tờ báo cáo là của một khoảng đã chốt; để nó
tự đổi dưới tay người dùng khi đồng bộ kéo về một giao dịch mới là thứ không ai
muốn ở một thứ sắp mang đi nộp. Trang Xem trước vì thế **không đọc CSDL**:
trang Xuất dựng xong rồi đẩy `BaoCao` sang, nên nó kiểm được bằng widget test
thuần.

Màn này **không có trong Stitch cũ** — 32 màn không màn nào là báo cáo/kết quả.
Nó được **sinh vào chính dự án Stitch** ngày 2026-09-09 (màn "Xem trước báo cáo
- FlowMoney", id `f0a0d1457401478596753a48531bc097`, design system "Kinetic
Finance" `assets/e8b7d56ef9284443bfacb7474e52c74a`) rồi mới dựng bằng Flutter
theo nó. ⚠️ Lần sinh ấy **báo timeout hai lần nhưng cả hai đều thành công** —
`list_screens` cập nhật chậm hơn `get_project` nhiều phút, nên đừng tin
`list_screens` để kết luận "sinh hỏng"; hậu quả là dự án có một màn trùng phải
xoá tay (MCP không có lệnh xoá màn).


### 3.15 Báo cáo chi tiết — lấy chuẩn từ app thị trường

**Khảo sát 2026-09-09**, sau khi người dùng nói bản 2c‑1 *"chỉ có các thông tin
cơ bản"*. App đã xem: **Money Lover**, **MISA MoneyKeeper** (phía Việt Nam),
**Copilot**, **PocketSmith** (quốc tế). Ba điều rút ra, và cả ba đều thành khối
trên màn Xem trước:

- **Money Lover** có hẳn một mục trợ giúp riêng cho *"Số dư đầu kỳ – Số dư cuối
  kỳ"*: báo cáo của họ kể **một câu chuyện dòng tiền**, không phải một đống số
  rời. → khối "Dòng tiền trong kỳ".
- **Copilot** có tab Cash Flow kèm **so sánh với kỳ liền trước**. → phần trăm
  ▲/▼ dưới mỗi thẻ tổng, và `khoangKyTruoc`.
- **PocketSmith** dựng báo cáo như một **bảng lãi–lỗ cá nhân**: thu theo danh
  mục *và* chi theo danh mục. → bảng "Thu theo danh mục", đối xứng với bảng chi.

Bốn khối còn lại là thứ FlowMoney có sẵn dữ liệu mà báo cáo chưa dùng: **ngân
sách kỳ này** (chỗ FlowMoney mạnh hơn Money Lover — app kia không gắn ngân sách
vào báo cáo), **phân bổ theo ví**, **top 5 khoản chi**, và **số liệu nhanh**
(chi mỗi ngày, số giao dịch, ngày chi nhiều nhất, khoản chi lớn nhất) theo lối
MISA/Money Lover.

`chiTheoDanhMuc` của `thong_ke_thang.dart` nay nhận thêm `loai` (mặc định
`'chi'`) để dựng cả bảng thu — **một định nghĩa cho hai chiều**, không viết bản
sao thứ hai. Tên hàm giữ nguyên vì trang Phân tích chỉ dùng chiều chi.

### 3.16 Dòng tiền là số **suy ngược**, và nó có hai giới hạn đã biết

App không lưu lịch sử số dư. Số dư cuối kỳ = tổng số dư ví hiện tại **trừ** phần
phát sinh sau kỳ; số dư đầu kỳ = cuối kỳ trừ thu và cộng chi trong kỳ. Phép cân
`đầu kỳ + thu − chi = cuối kỳ` vì thế luôn đúng theo cách dựng.

Hai giới hạn, cả hai đều ghi thẳng lên màn hình bằng dòng *"Suy ngược từ số dư
hiện tại của các ví"*:

1. **Lọc theo một ví thì không có khối này.** Với một ví riêng, khoản
   `transfer` ảnh hưởng thật tới số dư nhưng **chiều tiền không suy được** từ vị
   trí ví — đúng cái bẫy đã ghi ở mục 3.2 `GOAL_FEATURE.md` (đổi ví tích luỹ một
   lần là mọi khoản nạp cũ đọc thành khoản rút). Thà không hiện còn hơn hiện một
   con số có thể sai.
2. **Ví tạo giữa kỳ làm số dư đầu kỳ lệch.** ⚠️ Giới hạn này **vẫn còn**, nhưng
   **lý do của nó đã đổi từ 2026-09-13** (G37, số dư ví suy từ sổ giao dịch):
   trước đó số dư ban đầu của một ví *không phải là giao dịch* nào cả; nay ví
   mới **có** sinh một khoản "Số dư ban đầu" thật
   (`wallet/domain/so_du_mo_so.dart`, id suy tất định từ `walletId`). Nhưng
   khoản ấy bị `khoanVaoThongKe()` **cố ý loại** — nó là **điểm neo**, không
   phải thu nhập; đếm nó là mỗi ví người dùng tạo ra lại làm thu nhập tháng ấy
   tăng vọt đúng bằng số dư ban đầu. Nên với báo cáo, số dư ban đầu vẫn bị quy
   hết về "trước kỳ" như cũ. Money Lover tránh việc này bằng cách **đếm** khoản
   mở sổ như một giao dịch thường — đổi được, nhưng đó là đánh đổi với đúng cái
   méo vừa nói, chứ không phải sửa báo cáo.

⚠️ Trên tài khoản thử (id 10), số dư đầu kỳ ra **âm**. Đó là số thật của dữ liệu
ấy, không phải lỗi: tháng 9 thu nhiều hơn chi 13,58 triệu trong khi tổng số dư
hiện tại chỉ 8,89 triệu.


### 3.17 Sinh tệp: PDF **và** CSV, lưu thẳng vào thư mục Tải về

Giao diện đã bày hai ô định dạng nên phải làm **cả hai** — bày một ô rồi không
làm là đúng cái kiểu "lời hứa suông" mà lát 2c‑1 vừa dọn. Ba quyết định:

**Thư viện.** `pdf` dựng tài liệu; `share_plus` chỉ còn dùng cho **đường lùi**
(xem dưới). CSV thì tự viết chuỗi, không cần thư viện nào.

**Nơi lưu: thẳng vào thư mục Tải về của máy**, qua `MediaStore` (kênh
`flowmoney/luu_tep`, mã Kotlin trong `MainActivity`). Người dùng nói rõ *"tôi
muốn nó sẽ tải xuống lưu vào máy"*, và `MediaStore` là cách **duy nhất** đặt
được tệp vào bộ nhớ chung mà **không xin quyền nào** trên Android 10+ (API 29):
`WRITE_EXTERNAL_STORAGE` đã bị thu hồi tác dụng từ chính bản ấy, còn hộp thoại
chọn thư mục (SAF) thì bắt người dùng bấm thêm.

Máy dưới API 29 — và mọi nền tảng khác — **lùi về sheet chia sẻ**: ghi tệp vào
thư mục tạm rồi để người dùng tự chọn nơi lưu. Đường lùi ấy không test được ở
đây (máy ảo là API 36) nên **cố ý giữ nguyên đường cũ đã chạy thật** thay vì
viết thêm luồng xin quyền chưa ai chạy bao giờ.

⚠️ Hai đường trả về hai thứ khác nhau, và giao diện **phải nói đúng cái đã xảy
ra**: `xuat()` trả đường dẫn (`Tải về/…`) khi lưu thật, trả `null` khi chỉ mở
sheet. Nói "Đã lưu" cho cả hai ca là đẩy người dùng đi tìm một tệp không tồn
tại. Có test canh đúng chỗ ấy.

**Font PDF phải NHÚNG.** Font mặc định của gói `pdf` là Helvetica —
**không có glyph tiếng Việt** và mất dấu **im lặng**: tệp vẫn mở được, chỉ là
"Ăn uống" thành ô trống. Nhúng `Roboto` (Apache 2.0, đã kiểm cmap có đủ dấu và
cả `₫` lẫn `đ`) vào `assets/fonts/`. **Không** dùng `PdfGoogleFonts` của gói `printing`:
hàm ấy tải font qua mạng lúc chạy, mà app này offline-first.

Có một test canh đúng chỗ ấy: tệp sinh ra **không được chứa chuỗi "Helvetica"**
và **phải chứa "Roboto"**. Đó là cách duy nhất bắt được lỗi mất dấu bằng máy.

⚠️ **Câu "đã kiểm cmap có đủ dấu" ở trên đúng nhưng CHƯA ĐỦ** — thêm
2026-09-17. Bản Roboto nhúng **không có** khối Mũi tên (U+2190…) lẫn khối Hình
học (U+25A0…), nên `→` `↑` `↓` `▲` `▼` bị gói `pdf` **bỏ đi im lặng**. Lỗi ấy
đã nằm trong mã từ chính lát 2c‑2 này: dòng dòng tiền dùng `→`. Xem mục
**3.31** — ở đó có phép canh bằng máy, và danh sách ký tự dùng được.

### 3.18 CSV cho Excel tiếng Việt — ba thứ nhỏ, cả ba đều hỏng im lặng

- **BOM UTF-8** ở đầu tệp. Không có nó, Excel đoán bảng mã và "Ăn uống" thành
  "Ăn uống" — tệp vẫn mở được, đó mới là chỗ nguy.
- **Dòng `sep=;`** trước mọi thứ khác. Excel dùng dấu phân cách theo *locale*
  máy: vi‑VN là chấm phẩy, en‑US là phẩy. Không khai báo thì một trong hai bên
  mở ra thấy mọi cột dồn vào một.
- **Số tiền là số nguyên thô**, không phân cách nghìn, không ký hiệu tiền. Cột phải cộng
  được, và Excel tiếng Việt còn đọc `1.045.000` thành *một phẩy không bốn năm*.
  Khoản chi mang **dấu âm** — cùng một cột mà không có dấu thì tổng cột ra
  "thu cộng chi", một con số không có nghĩa gì.

Ngược lại, **PDF là tài liệu để ĐỌC** nên số ở đó có phân cách nghìn và ký hiệu
tiền. Hai định dạng cố ý khác nhau ở điểm này.


### 3.19 Cơ cấu theo danh mục và xu hướng nhiều danh mục — A8 #3, #7

**Xong 2026-09-14** — đây là **bản thi công lần hai**. Spec
`docs/superpowers/specs/2026-09-14-thong-ke-phan-loai-va-xu-huong-danh-muc-design.md`
(đọc kèm banner đầu tệp: bản đầu khác bản đang chạy ở hai chỗ),
kế hoạch `docs/superpowers/plans/2026-09-14-thong-ke-phan-loai-va-xu-huong-danh-muc.md`.

⚠️ **Bản đầu đóng ba mục (#2, #3, #7) và đã bị revert cùng ngày** — người dùng
xem xong rồi chốt lại phạm vi: **bỏ #2**, giữ #3 và #7, và đổi hình dạng cả
hai. Lát này lấy lại phần còn dùng được từ commit đã revert. Vì thế những câu
nói về "mức gốc ba lát", "drill-down", "dropdown chọn một danh mục" trong các
tài liệu cũ hơn bản này đều **tả bản đầu**, không phải app đang chạy.

Bảng **A8** của `Project.md` (dòng 1028–1041) có 11 mục; lát này đóng **hai**
mục mà client tự làm được với dữ liệu đang có. Mục **#2** (tròn theo *phân
loại*) làm được nhưng **không giữ**: nó bắt thêm một cú chạm mới tới được thứ
người dùng thật sự tìm — danh mục nào tốn nhiều nhất. Bốn mục còn lại — **#4**
Cho vay + Thu nợ, **#5** Đi vay + Trả nợ, **#8** dòng tiền tự do, **#9** biến
động khoản vay — bị chặn bởi **mô hình dữ liệu**, không phải bởi biểu đồ: đếm
bằng máy 2026-09-14 thì client có 9 bảng Drift và backend có 13 model Prisma,
**không đầu nào có bảng khoản vay**. Không có dư nợ gốc, lãi suất, kỳ hạn, hay
liên kết giữa một khoản vay với các lần trả nợ của nó. Hai mục **#10** (thác
nước) và **#11** (Sankey) làm được với thu/chi nhưng để đợt sau.

> ⚠️ **Đính chính 2026-09-15:** đoạn trên là kết luận của ngày 2026-09-14 và nay
> **chỉ còn đúng với #9**. **#4 và #5** chỉ vẽ *dòng tiền*, không cần dư nợ gốc
> hay lãi suất, và đã làm xong (mục **3.22**). **#8** (dòng tiền tự do) cũng
> **không bị chặn**, và nay **đã làm xong** cùng ngày — mục **3.24**. ⚠️ Công
> thức thì **không** phải `Σ thu − Σ traNo` như dòng này từng ghi: `tong.thu` đã
> gồm cả tiền **đi vay** và **thu nợ**, hai thứ không phải thu nhập. Chỉ **#9**
> chặn thật, vì nó cần **dư nợ còn lại** — 🛑 **nhưng từ 2026-09-16 nó không
> còn là việc**: người dùng chốt bỏ hẳn **#9** và **#11**, xem banner mục 7.1.
> ✅ **#10 (thác nước) đã làm xong**
> cùng ngày — mục **3.23**; người dùng chốt "không làm" rồi **đổi ý** trong
> ngày, nên câu ấy ở các tài liệu cũ hơn là ảnh chụp của quyết định đầu.
>
> Bài học: một mục bị xếp "chặn bởi mô hình dữ liệu" thì phải hỏi **chặn vì
> thiếu con số nào**, chứ đừng gộp cả nhóm theo cái tên "vay/nợ" — câu gộp ấy đã
> giữ #4 và #5 nằm ngoài phạm vi suốt một ngày, và suýt giữ cả #8.

⚠️ **`suggestDebtDirection()` không thay được mô hình ấy.** Nó đoán chiều tiền
bằng cách so tên danh mục với bốn chuỗi (`đi vay`, `thu nợ`, `cho vay`,
`trả nợ`) — một **gợi ý lúc nhập liệu**, nơi đoán sai chỉ tốn một cú chạm để
sửa. Dựng thống kê trên phép đoán theo tên là báo cáo sai mà không ai biết.

#### Luật phân loại — một định nghĩa duy nhất

App có **hai** thứ dễ nhầm là một: `transaction.type` (`thu`/`chi`/`transfer` —
**chiều tiền**) và `category.classify` (`thu`/`chi`/`vay_no` — **phân loại danh
mục**). Một khoản *Trả nợ* mang `type = 'chi'` nhưng `classify = 'vay_no'`; ba
chip của khối hỏi theo **classify**.

`phanLoaiCua()` ở `domain/phan_loai_dong_tien.dart` là chỗ duy nhất định nghĩa:
lấy `classify` của danh mục, **rơi về `type`** khi không tra được. Nhánh rơi về
là bắt buộc — đo trên CSDL 2026-09-10 có 17 hàng giao dịch trống danh mục thật.

`theoPhanLoai()` **giữ lại** dù vòng tròn ba lát đã bỏ: nó là nguồn **duy
nhất** cho biết nhóm nào có phát sinh trong tháng, tức khối hiện chip nào.

⚠️ **`chiTheoDanhMuc()` giữ nguyên, không đụng.** Nó gom theo *chiều tiền* để
phục vụ hai bảng "Thu/Chi theo danh mục" của trang Xuất báo cáo, dùng ở **10**
chỗ `lib/` và **7** chỗ `test/` (đếm 2026-09-14). Hàm mới gom theo *phân loại
danh mục*. Hai câu hỏi khác nhau; gộp lại "cho gọn" sẽ làm bảng của báo cáo đổi
nghĩa mà không test nào ở đó đỏ.

#### Hệ quả cố ý: nhóm "Chi" ≠ "Tổng chi"

Ba nhóm phải **rời nhau** thì tỷ trọng mới có nghĩa, nên nhóm *Chi* của vòng
tròn không bằng con số *Tổng chi* ở thẻ đầu trang — nó thiếu đúng phần chi gắn
danh mục vay/nợ. Ba thẻ tổng **giữ nguyên** định nghĩa theo `type` vì chúng trả
lời câu hỏi khác. Với tài khoản không dùng danh mục vay/nợ thì hai số bằng nhau.

#### Hình dạng

Khối **"Cơ cấu theo danh mục"** thay khối "Chi tiêu theo hạng mục" cũ: **ba
chip** *Chi · Thu · Vay-nợ* chọn nhóm, vòng tròn vẽ các danh mục **bên trong**
nhóm ấy (vẫn `topVaKhac` — top 4 + "Khác"). Vào trang là **nhóm Chi mở sẵn**,
không tốn cú chạm nào. Chip chỉ hiện cho nhóm **có phát sinh**: chip của nhóm
rỗng dẫn tới một vòng tròn trống, không lỗi nào nhưng là một ngõ cụt. Thứ tự
chip cố định theo `kCategoryClassifies`, **không** theo số tiền — chip đổi chỗ
khi số đổi là người dùng bấm nhầm nhóm. **Danh sách danh mục cuối trang đi theo
cùng chip**, nên hai khối luôn nói cùng một con số. Nhãn mẫu số đổi theo nhóm
(`nhanTongCua`), và thanh ngân sách chỉ còn ở nhóm chi — `BudgetRepository`
không có khái niệm ngân sách thu.

Khối "Xu hướng …" nhận một **hàng chip cuộn ngang, chọn nhiều**: tập rỗng
là hai đường Thu/Chi như trước, bật một hay nhiều danh mục thì mỗi cái một
đường mang màu và tên của nó. Trần **`kToiDaDuongXuHuong` = 5 đường** — đủ trần
thì chip chưa bật bị **khoá nhìn thấy được** (`onSelected` null) chứ không phải
bấm mà không có gì xảy ra; chip đang bật thì luôn tắt được. Chốt thật nằm ở
cubit, khoá ở widget chỉ để nhìn thấy. Hàng chip **chỉ liệt kê danh mục có phát
sinh trong sáu tháng** đang vẽ, và ở tại chỗ chứ không màn mới — trang nằm
trong `StatefulShellRoute` (bẫy 7.8 `NOTIFICATION_FEATURE.md`). Một dòng chữ
dưới hàng chip là chỗ **duy nhất** nói "bỏ chọn hết để xem Thu/Chi": hàng chip,
khác dropdown, không có mục nào tự nói lên trạng thái rỗng.

#### Bốn cái bẫy im lặng, cả bốn đều có test canh

1. **Stream phát lại làm mất lựa chọn.** `watchKy` phát lại mỗi khi giao
   dịch, danh mục **hoặc** ngân sách đổi — kể cả khi đồng bộ nền kéo về. Quên
   chép hai lựa chọn sang state mới thì cứ mỗi chu kỳ đồng bộ là donut tự nhảy
   về nhóm Chi và mọi đường xu hướng biến mất **trong khi người dùng đang
   xem**. Chốt ở `AnalyticsCubit._dungLoaded`.
2. **Nhóm biến mất.** Tháng không có khoản vay/nợ nào thì nhóm ấy không tồn
   tại; giữ lựa chọn trỏ vào nó là vẽ một vòng tròn trống dưới một chip đã biến
   mất. Rơi về Chi; Chi cũng rỗng thì rơi về nhóm đầu còn phát sinh.
3. **Danh mục biến mất.** Đổi tháng hay danh mục bị xoá thì khoá không còn —
   đọc `chuoiDanhMuc[id]!` khi ấy là nổ. Loại **đúng khoá ấy** khỏi tập, không
   xoá cả tập: xoá cả tập là người dùng mất luôn những đường còn hợp lệ.
4. **`FlClipData` mặc định là `none()`** (bẫy **4.17**) — nhiều đường cùng lúc
   có dải hẹp hơn bản hai đường nên dễ tràn khỏi thẻ hơn. Đã đặt
   `FlClipData.all()`.

#### Một lượt duyệt cho `chuoiTheoDanhMuc`

Gọi `chuoiTheoKy` một lần cho mỗi danh mục là `số danh mục × soKy` lượt
quét toàn bộ giao dịch — với 30 danh mục và 5.000 giao dịch là 900.000 phép so
ngày **mỗi lần stream phát**. Hàm mới duyệt một lần, phân thẳng vào ô
`(categoryId, tháng)`, và có test đối chiếu thẳng với bản lọc tay: nó chỉ được
nhanh hơn, không được khác.

#### Nghiệm thu

`flutter test` **2409/2409** · `flutter analyze` **25 issue, 0
error** — đếm bằng máy 2026-09-14. Analytics có **12** tệp test / **229** test
(đếm bằng chính `flutter test test/features/analytics` cùng ngày; mốc 10 tệp /
170 test là của 2026-09-09, mốc 11 tệp / 180 test là của 2026-09-13).

**Năm bản sai có chủ ý** đã chứng minh từng chốt thật sự có ca canh. Cần chúng
vì mã trang được ghép **trước** khi tệp test được viết lại (phiên trước dừng
giữa lượt), nên không ai xem được "đỏ tự nhiên" cho phần widget:

| Phá cái gì | Ca đỏ |
|---|---|
| `_dungLoaded` không chép hai lựa chọn sang state mới | 4 |
| Bỏ phép kiểm trần ở `batTatDanhMucXuHuong` | 1 |
| Chip chưa bật không bao giờ bị khoá | 1 |
| Danh sách cuối trang đọc `danhMuc` thay vì nhóm đang chọn | 3 |
| Tâm donut lấy tổng chi toàn tháng làm mẫu số | 1 |

**Nghiệm thu máy ảo** `emulator-5554` (1080×2400, tức 411dp), tài khoản có dữ
liệu thật, 2026-09-14 — đủ bảy điểm:

1. Vào trang là **nhóm Chi mở sẵn**, tâm "TỔNG CHI 1M", chú giải top 4 + "Khác".
2. Chỉ **hai** chip *Chi · Thu* — tài khoản này không có phát sinh vay/nợ, nên
   chip thứ ba không hiện. Đúng luật.
3. Chạm chip *Thu*: donut đổi sang danh mục thu, tâm "TỔNG THU 14.6M", danh sách
   cuối trang đổi theo, mẫu số đổi thành "% tổng thu". Cộng bốn dòng
   (14.050.000 + 500.000 + 50.000 + 25.000) ra **đúng** 14.625.000 của tâm.
4. Hàng chip xu hướng **cuộn ngang được** — hai chip đầu tên dài ("Danh mục đã
   xoá") che mất phần còn lại ở lần nhìn đầu, vuốt ra thấy đủ.
5. Bật một chip: chú giải đổi từ *Thu/Chi* thành tên danh mục, đường đổi màu, và
   **trục tung tự co** từ dải 16.8M xuống 51.7K.
6. Bật ba chip: ba đường, chú giải ba mục, thứ tự khớp.
7. **Đủ trần 5**: chú giải năm mục, và ba chip chưa bật ("Lương", "Mua sắm",
   "Thưởng") chuyển sang trạng thái **mờ** thấy rõ so với chính chúng lúc chưa
   đủ trần — tức `onSelected == null` có hình dạng nhìn thấy được, đúng ý đồ.

✅ Lượt nghiệm thu ấy **tìm ra một lỗi, và nó đã được sửa cùng ngày** — **G39**
`CLIENT_APP_KNOWN_GAPS.md`: nhãn trục tung in đè lên nhau ở một số dải giá trị.
Lỗi **không** do lát này (khối "Xu hướng 6 tháng" mang sẵn hình dạng ấy từ lát
2b, 2026-09-08); lát này chỉ làm dễ gặp hơn vì mỗi tổ hợp chip là một dải `maxY`
khác. Sửa bằng `maxY = buoc * 3` — xem bẫy **4.18**.

✅ **Stitch đã có màn khớp bản lần hai:** `c8567243df704268ac766aa60ffa5036` —
*"Thống kê - Cơ cấu danh mục & Xu hướng 6 tháng"*. **Người dùng tạo nó** bằng cách
gõ vào khung chat của Stitch rằng chưa thấy thay đổi, ngày 2026-09-14.

⚠️ **Đừng nghiệm thu `edit_screens` bằng API — không làm được.** Lượt gọi lúc
21:35 cùng ngày **trả về thành công** kèm `dom_operations` khẳng định nó
`replace_element` **tại chỗ** trên màn `c2a2b615…`, với đủ `selector` và
`verified_html_context`. Thực tế nó **không đổi gì**: màn ấy giữ nguyên qua năm
lượt `get_screen`, và người dùng mở Stitch xem tận mắt cũng thấy y nguyên. Tôi
còn sai thêm một lần nữa theo chiều ngược lại — thấy màn mới xuất hiện thì kết
luận lượt gọi đã tạo ra nó, trong khi người tạo là người dùng.

Rút lại thành hai điều, cả hai đều đã phải sửa tài liệu để trả giá: kết quả trả
về **không** chứng minh công cụ đã làm gì, và một màn mới xuất hiện **không**
chứng minh lời gọi của mình tạo ra nó — người dùng thao tác song song trên Stitch
mà mình không thấy. Phép đo duy nhất đáng tin là **hỏi người dùng**.

### 3.20 Phạm vi thời gian — tuần · tháng · quý · năm · khoảng tuỳ chọn (P1)

**2026-09-15.** Trước hôm nay trang chỉ xem được **theo tháng**: bộ chọn dựng từ
`cacThangGanNhat(now)` và cả năm tầng khoá cứng theo cặp `(nam, thang)`. Trang
Xuất báo cáo — cùng dữ liệu, cùng tầng domain — đã làm được quý và khoảng tuỳ ý
từ 2026-09-09; trang Phân tích thì không.

Spec: `docs/superpowers/specs/2026-09-15-pham-vi-thoi-gian-trang-phan-tich-design.md`
(gitignore). Kế hoạch thi công: `docs/superpowers/plans/2026-09-15-p1-pham-vi-thoi-gian-phan-tich.md`.

**`Ky` là định nghĩa duy nhất** (`analytics/domain/pham_vi_ky.dart`): một
`DonViKy` cộng biên `[from, to)`. Nó thay `(nam, thang)` ở `ThongKeKy`,
`watchKy`, `AnalyticsLoading`, `chonKy`, và ở mọi nhãn trên trang.

**Ba dạng nhãn cho ba chỗ**, không phải thừa: `nhan` cho danh sách trong bộ chọn
(có chỗ, nên tuần hiện cả khoảng ngày), `nhanNgan` cho ô trên header (hàng ấy đã
tràn 53px một lần), `nhanTruc` cho trục biểu đồ (vài ký tự). Cộng hai hàm nhãn:
`nhanOChon` (nếp "Tháng này (T9 2026)" chỉ khi kỳ **chứa hôm nay**) và
`nhanKyTruoc` (câu "so với …" ở thẻ tổng — bỏ năm khi cùng năm, giữ năm khi kỳ
trước rơi sang năm khác).

⚠️ **Nhãn quý là `Q3 2026`, không phải `Quý 3 2026`** (sửa 2026-09-15 sau khi
người dùng báo). Dạng đầy đủ làm nhãn ô header — `"Quý này (Quý 3 2026)"` —
dài hơn `"Tháng này (T9 2026)"` **đúng một ký tự**, và máy ảo cắt nó thành
`"Quý này (Quý 3 20…"`, mất cả con số năm. Nhãn tháng là chuỗi dài nhất từng
được chứng minh là vừa trên máy thật, nên **không nhãn nào được dài hơn nó**;
`pham_vi_ky_test.dart` canh đúng bất đẳng thức ấy.

Hai điều đi kèm. **`Q3` không phải quy ước thứ hai** — trục biểu đồ đã dùng
`Q3/26` từ đầu. Và phép canh phải đặt ở **tầng thuần**, không phải widget test
đo bề rộng: font "Ahem" rộng gấp đôi ngoài đời (bẫy 4.4) nên ở 411dp chuỗi nào
cũng cụt, và một ca đo bề rộng sẽ đỏ cả với nhãn tháng vốn không sao. So **độ
dài chuỗi với nhãn tháng** là phép canh không phụ thuộc font.

**Bộ chọn là bottom sheet hai tầng**, không phải chip trên header: header đã
chật. Chip chọn *đơn vị*, danh sách chọn *kỳ* — và **đổi chip chưa phải một lựa
chọn**, vì người dùng còn phải nói rõ kỳ nào. Danh sách dựng tại chỗ bằng
`cacKyGanNhat(moc, donVi)`; `AnalyticsLoaded` mang `moc` thay cho `cacThang` để
lướt qua bốn đơn vị không phải đi một vòng cubit.

**Sáu cái bẫy, cả sáu đều hỏng im lặng** (cái thứ sáu thêm 2026-09-16, sau khi
đóng **G43** — nó là một lỗi **của chính lát P1 này**):

1. ⚠️ **Ngân sách chỉ gắn khi đơn vị là Tháng.** `BudgetView.spent` đếm theo kỳ
   của **chính ngân sách ấy**, không theo kỳ đang xem. Vẽ thanh "% ngân sách"
   cạnh số liệu một tuần là đặt hai kỳ khác nhau lên cùng một tỉ lệ, và con số
   trông rất hợp lý. Chốt ở `_dung()`; dòng tự rơi về nhãn "% tổng chi".
2. ⚠️ **Nhãn trục của sáu kỳ liên tiếp phải đôi một khác nhau.** Sáu quý trải
   qua **một năm rưỡi**, nên `Q3` một mình xuất hiện hai lần — hai cột khác nhau
   mang đúng một nhãn. Nhãn quý là `Q3/26`. Sáu tháng, sáu tuần, sáu năm thì
   không lặp. Có một ca quét cả bốn đơn vị canh việc này; cùng họ với **G39**.
3. ⚠️ **Nhãn trục tuần là ngày thứ Hai, không phải `T38`.** `T` đang là tiền tố
   của tháng ở khắp app; hai nghĩa cùng một chữ trên cùng một trục là lỗi đọc
   nhầm chứ không phải lỗi mã.
4. ⚠️ **Thoát bộ chọn ngày thì giữ nguyên kỳ đang xem.** Rơi về tháng này là tự
   đổi thứ người dùng đang xem chỉ vì họ bấm nhầm rồi thoát ra. Khác
   `khoangCuaPhamVi` của trang Báo cáo, nơi `null` buộc phải có một chỗ rơi vì
   nó là hàm thuần. *(Câu so sánh ấy nay chỉ còn là lịch sử:
   `khoangCuaPhamVi` **đã bỏ** ngày 2026-09-18 — mục **3.33** — và trang Báo
   cáo dùng chính bộ chọn này, nên luật "thoát thì giữ nguyên" áp cho **cả
   hai** trang.)*
5. ⚠️ **Lùi kỳ theo đơn vị lịch, không trừ số ngày.** `lui` là chỗ duy nhất làm
   việc ấy; bản sai có chủ ý dùng `subtract(Duration(days: 30))` cho ra
   `2026-01-01` thay vì `2026-02-01`.
6. ⚠️ **Khoảng khởi tạo của `showDateRangePicker` phải KẸP vào
   `[firstDate, lastDate]`** — **G43**, tìm được 2026-09-16. Bản đầu truyền
   thẳng kỳ đang xem, trong khi `lastDate` là **hôm nay**; nên bất cứ khi nào kỳ
   chứa hôm nay — *Tuần này · Tháng này · Quý này · Năm nay*, tức **trạng thái
   mặc định** — mốc cuối nằm ở tương lai và assertion nổ. Và vì nó là exception
   trong một hàm `async` **không ai bắt**, nút "Tuỳ chọn" chỉ đơn giản là
   **không làm gì**: không toast, không màn đỏ, chỉ một dòng logcat. Phép kẹp
   nay là hàm thuần `khoangKhoiTaoBoChonNgay`, trả `null` khi kỳ không giao với
   dải. Xem thêm bẫy **4.22**.

**Biên tuần dùng chung với thông báo Tổng kết tuần**: `bienTuan` tách khỏi thân
`tuanTruoc` ở `core/notification/tuan_iso.dart`, và có một ca canh hai hàm không
trôi khỏi nhau. Nhờ đó số tuần đúng ở ca tuần vắt qua giao thừa (31/12/2025
thuộc `2026-W01`).

**Không đổi schema, không thêm trường đồng bộ.** Trang Xuất báo cáo không đổi gì
ngoài một dòng `export`: `khoangKyTruoc` chuyển sang `pham_vi_ky.dart` để hai
trang dùng chung một định nghĩa, và 25 ca của nó vẫn xanh mà không sửa dòng nào.

**Màn Stitch: `83993fc9f5de4c5f8fba6940480c164a`** — *"Thống kê - Chọn phạm vi
thời gian"*, MOBILE. Người dùng xác nhận ngày 2026-09-15 rằng màn ấy do lượt gọi
`generate_screen_from_text` của phiên này tạo ra. Nó vẽ đúng hình dạng đã dựng:
nhãn `CHỌN PHẠM VI`, năm chip theo thứ tự *Tuần · Tháng · Quý · Năm · Tuỳ chọn*
với "Tháng" đang bật, và danh sách kỳ có dấu tích ở *"Tháng này (T9 2026)"*.

⚠️ **Lượt gọi ấy trả về `timeout`, và `list_screens` ngay sau đó không thấy màn
nào mới** — hơn một tiếng sau nó mới hiện. Tức **timeout không phải thất bại**;
đừng gọi lại (tài liệu công cụ dặn *"DO NOT RETRY"*), gọi lại sớm thì dự án lãnh
thêm một màn trùng. Xem mục ghi chú vận hành `CLAUDE.md`.

### 3.21 Bốn khối mượn từ trang Xuất báo cáo (P2)

**2026-09-15.** Trang Phân tích nghèo hơn trang Báo cáo một cách vô lý: cùng dữ
liệu, cùng tầng domain, mà không có **dòng tiền**, **số liệu nhanh**, **phân bổ
theo ví** hay **top 5 khoản chi**. Nay có đủ bốn.

**Thứ tự khối chép đúng trang Báo cáo**, để hai trang kể cùng một câu chuyện
theo cùng một trình tự — và thứ tự câu hỏi vẫn đọc ra được:

```
Dòng tiền ▸ 3 thẻ tổng ▸ Xu hướng ▸ Số liệu nhanh ▸ Cơ cấu donut ▸ Chi tiết danh mục ▸ Phân bổ theo ví ▸ Top 5
tiền ở đâu    bao nhiêu   ra sao      tiêu thế nào     đi vào đâu        chi tiết          từ ví nào    khoản nào
```

**Một định nghĩa, hai nơi dùng.** Bốn phép tính vốn nằm **inline** trong
`dungBaoCao`; nay là hàm thuần ở `bao_cao_xuat.dart`: `soLieuNhanhCua`,
`phanBoTheoVi`, `topKhoanChi`, `dongTienCua`.

⚠️ **Đừng gọi `dungBaoCao` từ trang Phân tích.** Nó tính thêm cả chuỗi biểu đồ,
bảng danh mục và phép gom theo ngày — thứ trang này đã có hoặc không cần — và
stream của trang phát lại sau **mọi** chu kỳ đồng bộ nền. Cùng lý lẽ với "một
lượt duyệt" của `chuoiTheoDanhMuc`.

**Repository nhận nguồn thứ tư: ví.** (⚠️ Con số ấy đúng **tại 2026-09-15**; từ 2026-09-16 `watchKy` gộp **bảy** nguồn — xem mục 3.27.) Ba trong bốn khối cần nó — "phân bổ theo
ví" cần **tên** ví, "dòng tiền" cần **tổng số dư hiện tại**. Tổng ấy đi qua
`viTinhVaoTong`, cùng luật với trang chủ, màn Quản lý ví và trang Báo cáo; `fold`
trần trên mọi ví là bản chép tay đã sai **ba lần** (mục 3.16 và
`vi_tinh_vao_tong.dart`). Ví lấy **kể cả hàng đã xoá mềm**, cùng luật với danh
mục: giao dịch cũ vẫn trỏ vào ví đã xoá và tên thật vẫn nằm trong hàng.

**Bốn chỗ dễ vấp:**

1. ⚠️ **Khối dòng tiền LUÔN kèm câu "Suy ngược từ số dư hiện tại của các ví".**
   App không lưu lịch sử số dư; bê mỗi con số là để người đọc tưởng đây là số
   đo. Có ca test canh đúng câu ấy. Xem mục **3.16** cho cả danh sách chỗ nó
   lệch.
2. ⚠️ **`dongTienCua` nhận TOÀN BỘ giao dịch, không phải phần đã cắt theo kỳ.**
   Phép suy đi ngược từ hôm nay về cuối kỳ nên nó cần biết phần phát sinh **sau**
   kỳ. Đưa danh sách đã cắt vào thì đầu kỳ và cuối kỳ bằng nhau — **im lặng**.
3. ⚠️ **Số 0 không mang dấu.** `-0 đ` ở ví chỉ có thu (và `+0 đ` ở ví chỉ có chi)
   đọc như một con số âm bằng không. Luật ấy vốn nằm riêng ở
   `report_preview_page._coDau`, nay là **`CurrencyFormatter.formatCoDau`** dùng
   chung — đúng nếp mọi luật hiển thị tiền ở một chỗ. Máy ảo bắt được.
4. ⚠️ **Test của trang phải gọi `initializeDateFormatting`.** Khối Top 5 in ngày
   qua `DateFormatter`; thiếu dữ liệu locale thì widget ném `LocaleDataException`
   và **cả cây dừng dựng** — mọi ca trong tệp đỏ với dáng vẻ "khối không hiện",
   không ai nghĩ tới ngày tháng. App thì không sao (`main.dart:30`).

**Khối rỗng thì không vẽ.** `theoVi` và `topChi` rỗng là ẩn cả thẻ, không vẽ một
thẻ trắng có mỗi tiêu đề.

⚠️ **Cột số tiền của hai khối bảng phải là `Expanded`, không phải `Flexible`** —
bẫy **4.19**. Người dùng bắt được ngay sau khi hạng mục này lên máy ảo.

#### Nghiệm thu

`flutter test` **2488/2488** · `flutter analyze` **25 issue, 0 error** — đếm
bằng máy 2026-09-15. Analytics có **14** tệp test / **301** test (đếm bằng chính
`flutter test test/features/analytics` cùng ngày).

Trên máy ảo, số khớp từng vế: `14.125.000 + 500.000` = Tổng thu, `935.000 +
110.000` = Tổng chi, và `14.625.000 − 1.045.000` = "Thay đổi trong kỳ" của khối
dòng tiền.

#### Màn Stitch — sinh sau, ngày 2026-09-15

**`afe1c3fdee43464c90ddadc508eaa599`** — *"Thống kê - 4 Thẻ Dòng Tiền & Kế
Toán"*. Bốn khối này thi công bằng cách **dùng lại khuôn màn Xuất báo cáo** nên
lúc làm chưa có thiết kế riêng; màn được sinh sau để tài liệu thiết kế khớp app.
Tải HTML về đọc thì cả bốn thẻ, từng nhãn và từng con số đều khớp bản thi công,
và cột tiền canh phải như sau khi đóng G40.

⚠️ **`deviceType: MOBILE` truyền vào KHÔNG có hiệu lực** — màn trả về mang
`deviceType: DESKTOP`, khung 2560×2258, trong khi dự án FlowMoney là MOBILE và
ba màn Thống kê trước đều 390px. Nhưng đó chỉ là **khung canvas**: thân trang
dựng trong `max-w-[430px]` căn giữa, tức bố cục vẫn là một cột điện thoại. Đọc
màn này thì nhìn phần 430px ấy, đừng suy ra rằng thiết kế đã đổi sang desktop.

⚠️ Và lượt gọi **trả về `timeout`**, `list_screens` ngay sau đó không thấy gì,
phải tới lượt kiểm thứ ba (chừng mười lăm phút sau) màn mới hiện — đúng như lần
sinh màn bộ chọn phạm vi. Timeout **không phải** thất bại; đừng gọi lại.

### 3.22 Hai biểu đồ cột vay/nợ — A8 #4 và #5

**2026-09-15.** "Cho vay & Thu nợ" và "Đi vay & Trả nợ", mỗi kỳ một **cặp cột
chồng nhau**: cột sau rộng và mờ, cột trước hẹp và đậm vẽ đè lên chính giữa.
Sáu kỳ, đi theo bộ chọn phạm vi của mục 3.20 nhờ mượn `lui(ky, i)`.

#### ⚠️ Hai mục này KHÔNG bị chặn bởi mô hình dữ liệu

Tài liệu (kể cả `CLAUDE.md`) ghi A8 #4, #5, #8, #9 "bị chặn bởi mô hình dữ liệu:
không đầu nào có bảng khoản vay". Đo lại ngày 2026-09-15 thì câu ấy **quá chặt
cho #4 và #5**: đúng là không có bảng khoản vay (client 9 bảng Drift, server 14
bảng), nhưng hai biểu đồ này chỉ vẽ **dòng tiền** — không cần dư nợ gốc, lãi
suất hay kỳ hạn. Thứ thật sự thiếu là chỗ lưu **vai**, và vai suy ra được.

**#9** (biến động khoản vay) thì vẫn chặn thật: nó cần dư nợ còn lại.

#### Tên là QUAN HỆ, chiều tiền là VAI

Đây là chỗ bản đầu **hiểu ngược**, và chỉ chạy thật trên máy ảo mới thấy.

Màn Thêm giao dịch, khi danh mục thuộc nhóm Vay/nợ, hiện thêm ô **"Chiều tiền"**
(Tiền ra / Tiền vào) — `suggestDebtDirection` chỉ **chọn sẵn** một bên, người
dùng đổi được. Nên tên danh mục nói **quan hệ nợ nào**, còn `type` nói **lần này
tiền chạy chiều nào**:

| Danh mục | Tiền ra | Tiền vào |
|---|---|---|
| `Cho vay` | cho vay | **thu nợ** |
| `Đi vay` | **trả nợ** | đi vay |

Bản đầu coi "Cho vay + tiền vào" là **tên nói dối** và xếp vào `khac`. Hậu quả:
hai cột *Thu nợ* và *Trả nợ* **không bao giờ có số** — im lặng, vì biểu đồ vẫn
vẽ ra và vẫn có cột đỏ. Không exception, không log.

Điều ấy còn nặng hơn vì tài khoản thật chỉ có **hai** danh mục Vay/nợ: `Cho vay`
và `Đi vay` — `Trả nợ`/`Thu nợ` đã bị **xoá mềm** trên server khi backend thu bộ
khuôn về 13 UUID (đo bằng máy 2026-09-15: 13 bản `Cho vay`, 13 bản `Đi vay` còn
sống; 3 bản `Thu nợ` và 3 bản `Trả nợ` đã xoá). Với luật đúng, hai danh mục ấy
**đủ ghi cả bốn vai**.

#### Bốn chốt

1. **`vaiVayNoCua` là định nghĩa duy nhất** (`domain/vai_vay_no.dart`). Tên chứa
   `cho vay` *hoặc* `thu nợ` → quan hệ cho vay; chứa `đi vay` *hoặc* `trả nợ` →
   quan hệ đi vay. Thứ tự tra **cố định**, để hai lần đọc cùng một hàng không ra
   hai kết quả.
2. ⚠️ **Không bỏ dấu khi so tên.** `removeVietnameseTones` là phép so mất thông
   tin, chỉ dành cho gợi ý nơi đoán sai tốn một cú chạm để sửa (quy tắc 7
   `CLAUDE.md`). Ở đây đoán sai đẩy tiền sang **nhầm biểu đồ**, và người dùng
   không biết là có gì để sửa.
3. **"Thuộc nhóm Vay/nợ" mượn `phanLoaiCua`** — cùng hàm mà vòng tròn "Cơ cấu
   theo danh mục" dùng, nên hai khối không thể nói hai con số cho một tháng.
4. ⚠️ **Màu theo CHIỀU TIỀN, không theo vị trí.** Xanh luôn là tiền vào, đỏ luôn
   là tiền ra — nên khối 1 có cột sau **đỏ** còn khối 2 có cột sau **xanh**. Đảo
   lại cho "hai khối trông giống nhau" là dạy người đọc một quy ước thứ hai.

#### Khoản không đoán được vai có khối riêng

Danh mục người dùng tự đặt tên ("Nợ Bảo") chỉ biết chiều tiền. Xếp nó vào một
trong hai khối là **chọn bừa** — một khoản tiền ra không rõ tên có thể là *cho
vay* hoặc *trả nợ*; xếp vào cả hai là **đếm hai lần**. Khối thứ ba "Vay/nợ chưa
xếp được vai" chỉ hiện khi có, và với hai danh mục mặc định thì không bao giờ
hiện. Giấu hẳn đi là im lặng đánh rơi tiền của người dùng.

#### Vẽ

`BarChartGroupData.barsSpace` **âm** là thứ làm hai cột chồng nhau;
`-(rộng1 + rộng2) / 2` đặt tâm hai cột trùng khít — lệch đi là cột trước trồi ra
một bên, trông như lỗi vẽ. **Thứ tự trong `barRods` là thứ tự vẽ**, nên cột sau
phải đứng trước để cột trước đè lên nó. Trần trục tính `buoc` trước rồi
`maxY = buoc * 3`, cùng cách chống nhãn in đè của G39 (bẫy 4.18).

#### Màn Stitch — và hai thẻ tổng **cố ý không chép sang**

**`6e9007f7653749a893c88e3de535afa5`** — *"Thống kê - Biểu đồ Cho vay & Đi vay"*.
Đo được ngày 2026-09-15; **không ghi ai tạo ra nó**, vì một màn mới xuất hiện
không chứng minh lượt gọi nào sinh ra nó (mục 3.19, đoạn về `edit_screens`).

Phần khớp bản thi công: hai khối *"Cho vay & Thu nợ"* và *"Đi vay & Trả nợ"*,
mỗi khối một dải chú giải hai màu, trục sáu kỳ, và bộ chọn phạm vi của mục 3.20
ở đầu trang.

⚠️ Phần **không** chép sang: Stitch vẽ thêm **hai thẻ tổng** ở đầu — *"Tổng cho
vay … 6 kỳ hạn • Còn 4 kỳ"* và *"Tổng đi vay … Tiến độ 65%"*. Ba con số ấy —
**số kỳ hạn**, **số kỳ còn lại**, **phần trăm tiến độ** — đều đòi **dư nợ gốc và
kỳ hạn**, đúng thứ mà mô hình dữ liệu không có (xem đoạn "#9 thì vẫn chặn thật"
bên trên). Vẽ chúng bằng số suy đoán là bịa ra một con số mà người dùng sẽ tin,
nên hai thẻ ấy bị bỏ. Khối thứ ba *"Vay/nợ chưa xếp được vai"* thì ngược lại:
Stitch **không** có, bản thi công thêm vào, vì giấu nó đi là im lặng đánh rơi
tiền.

#### Nghiệm thu

Nhập thật trên máy ảo: `Cho vay` 500.000 (tiền ra) và `Cho vay` 200.000 (tiền
vào) → khối "Cho vay & Thu nợ" hiện một cột đỏ nhạt rộng với một cột xanh hẹp đè
lên chính giữa; nhãn trục `0 / 191.7K / 383.3K / 575K` không chồng nhau; hai
khối còn lại vắng mặt. `flutter test` **2511/2511**, `flutter analyze` **25
issue, 0 error**.

### 3.23 Thác nước "Tiền đi đâu" — A8 #10

**2026-09-15.** Số dư đầu kỳ → cộng thu → trừ dần từng nhóm chi → số dư cuối kỳ.
Mỗi nhóm chi là một khối **nổi**: đáy khối này là đỉnh khối trước, nên cả biểu
đồ đọc được như một bậc thang. Chín cột: hai cột mốc, một cột thu, sáu nhóm chi.

⚠️ **Mục này người dùng từng chốt KHÔNG LÀM** (ngày 2026-09-15, *"không cần làm
P3 đâu"*) rồi **đổi ý cùng ngày** và xin thêm một đường trung bình. Mọi câu
"🛑 #10 không làm" trong tài liệu cũ hơn mục này là ảnh chụp của quyết định đầu.

#### Phép cân là thứ đắt nhất

`đầu kỳ + thu − Σ nhóm chi` phải ra **đúng** `cuối kỳ`. Lệch thì bậc thang hở
một khe ngay giữa biểu đồ — không exception, không log, chỉ là một hình vẽ sai
mà người đọc tưởng là thật. Ca test canh đúng điều kiện ấy.

Vì thế `thacNuocCua()` **không tự tính** `cuoiKy`: nó nhận con số mà khối "Dòng
tiền trong kỳ" đang hiện. Hai khối cùng trang nói hai con số khác nhau cho cùng
một kỳ là điều dự án cấm, và tự cộng lấy là cách chắc chắn nhất để rơi vào đó
khi một bên đổi luật lọc. Cùng lý do, nhóm chi mượn **`topVaKhac`** — hàm mà
vòng tròn cơ cấu đang dùng.

#### ⚠️ Đường trung bình KHÔNG phải một đường ngang

Yêu cầu ban đầu là "một đường trung bình thu chi ở giữa". Dựng tới tầng vẽ mới
lộ ra rằng đường ngang **không so được gì**: các khối chi nổi ở vùng cao (14,6
triệu xuống 13,6 triệu) còn mức trung bình là 174 nghìn, một giá trị tuyệt đối
nằm tít dưới đáy trục — nó không cắt cột nào. Mắt so **độ cao** khối, mà đường
ngang thì so **vị trí**.

Nên mức trung bình vẽ thành một **vạch trên từng cột chi**: phần nằm trong mức
trung bình tô nhạt, phần vượt tô đậm, ranh giới ở `tu − tb` (`ranhVuotTrungBinh`
). Cột nào có phần đậm là nhóm ngốn hơn mức bình thường. Người dùng chốt cách
này sau khi thấy vấn đề.

Ngưỡng **nửa đồng** khi so "có vượt không": `giaTri` là hiệu của hai số thực nên
một nhóm bằng đúng mức trung bình vẫn có thể ra lớn hơn chừng `1e-10`, và khi ấy
cột mọc thêm một vạch đậm cao không tới một phần triệu pixel — người dùng thấy
một vạch không giải thích được. Cùng ngưỡng mà `dieu_chinh_so_du_service.dart`
dùng cho đuôi lẻ của `double`.

#### Ba điều đã chốt, đừng "sửa"

1. **`dongTien == null` thì ẩn cả khối** — cùng điều kiện với khối Dòng tiền:
   lọc theo một ví thì số dư hai đầu không suy ngược được (mục 3.16), và thác
   nước mất luôn hai cột mốc. Chốt đặt ở **hai lớp** (chỗ gắn trong trang và
   đầu `build` của khối); bản sai có chủ ý phải phá **cả hai** mới làm ca test
   đỏ — đó là bằng chứng ca ấy canh đúng thứ cần canh.
2. **Trục bắt đầu từ 0, giữ đúng tỷ lệ thật.** Với dữ liệu tài khoản thử (thu
   14,6 triệu dồn một ngày, chi 1 triệu) thì sáu nhóm chi chỉ chiếm ~7% chiều
   cao và vạch hai sắc độ gần như vô hình. Người dùng xem ảnh máy ảo rồi chốt
   **giữ nguyên**: chi thật sự chỉ bằng 7% số thu trong kỳ ấy, bóp méo trục cho
   chúng trông to hơn là vẽ sai sự thật. Hai phương án đã loại: phóng to vùng
   chi (mất cột "Đầu kỳ", cắt cụt cột Thu và Cuối kỳ) và thêm một dải phóng to
   riêng (trang vốn đã dài).
3. **`BarChartData` KHÔNG có `clipData`** — bẫy 4.17 nói về `LineChartData`.
   Ở đây chống tràn bằng cách khác: `minY`/`maxY` quét cả `tu` lẫn `den` của mọi
   bậc nên không cột nào rơi ra ngoài dải để mà tràn.

#### Nhãn trục hoành: chín cột là kịch khổ 411dp

Vùng vẽ ngang còn chừng 325dp sau khi trừ trục tung và đệm thẻ, tức mỗi cột được
~36dp. Bản đầu đặt ô nhãn rộng **46dp** và trên máy ảo chín nhãn dính thành một
chuỗi không đọc được: *"ChưaDi chuyểnMua sắDanh mụcĂn uống Khác"*. Nay 32dp,
cỡ chữ 8, hai dòng, ellipsis. ⚠️ `flutter test` **không bắt được** lỗi này vì
`find.text` so `data` chứ không so thứ vẽ ra (bẫy 4.4) — cùng họ G39, và lại
một lần nữa chỉ máy ảo mới nói được.

#### Màn Stitch

**`52450ac549df42aea9f31d5ee1347ceb`** *"Thống kê - Biểu đồ thác nước Tiền đi
đâu"* (đo được 2026-09-15). Lượt `generate_screen_from_text` cho khối này trả về
**`timeout`** và bốn lượt `list_screens` sau đó vẫn **54 màn**; màn hiện ở lượt
kiểm của phiên sau. Đó là lần thứ ba liên tiếp **timeout không phải thất bại** —
đừng gọi lại. Chỉ ghi cái đo được: một màn mới xuất hiện không tự nó chứng minh
lượt gọi nào tạo ra nó.

#### Nghiệm thu

Trên `emulator-5554`, kỳ T9 2026: cột "Đầu kỳ" 10.000 sát đáy, cột "+Thu" xanh
cao, sáu khối đỏ nối tiếp nhau đi xuống, cột "Cuối kỳ" đen dừng đúng ở
13.590.000 — bậc thang khép kín. Dòng chú thích hiện *"Phần đậm là chỗ vượt mức
trung bình 174.167 đ/nhóm"*. `flutter test` **2540/2540**, `flutter analyze`
**25 issue, 0 error**, schema giữ **v22**, không thêm trường đồng bộ.

### 3.24 Dòng tiền tự do — A8 #8

**2026-09-15.** Một đường, sáu kỳ, trả lời tiếp đúng câu hỏi mà khối "Xu hướng"
vừa đặt: *thu về bấy nhiêu thì thực sự còn lại bao nhiêu*. Nguyên văn mục 8 của
bảng A8 (`Project.md` dòng 1036) là *"Xu hướng của dòng tiền tự do (thu nhập
sau khi trả nợ)"* — nên dạng biểu đồ đã có sẵn trong đề bài, và khối này mượn
nguyên khuôn `_KhoiXuHuong`.

#### ⚠️ Hai chữ "thu nhập" KHÔNG phải `tong.thu`

Đây là chỗ đắt nhất của hạng mục, và nó chỉ lộ ra khi hỏi trước lúc gõ.

`TongThuChi.thu` là **mọi** khoản `type = 'thu'`, nên nó **đã gồm cả tiền đi vay
và tiền thu nợ**. Cả hai đều không phải thu nhập: một là tiền mượn, một là vốn
cũ quay về. Lấy nguyên `tong.thu − traNo` thì tháng nào người dùng vay tiền,
đường này lại **vọt lên** — đúng tháng tình hình tài chính của họ xấu đi. Không
exception, không log.

Luật thật là:

> **thu nhập = tổng thu − mọi khoản tiền VÀO thuộc nhóm Vay/nợ**
> — tức trừ `diVay`, `thuNo`, **và** `khacVao`.

Ô thứ ba dễ bị bỏ sót vì nó là khoản *không đoán được vai*. Nhưng một khoản
vay/nợ tiền vào chỉ có thể là **đi vay** hoặc **thu nợ** — không đường nào biến
nó thành thu nhập. Liệt kê hai vai đọc được tên rồi quên ô thứ ba là chừa đúng
một lối cho tiền vay lọt vào.

Chiều ngược lại thì **không** đụng tới: `choVay` và `khacRa` là tiền đi ra,
chúng nằm ở `tong.chi` và không liên quan gì tới vế thu.

Đo trên máy ảo, kỳ T9 2026: thêm một khoản `Đi vay` **+5.000.000** (tiền vào)
thì con số của khối **vẫn là 14.625.000đ**, không nhảy lên 19.625.000đ. Đó là
bằng chứng duy nhất cho luật này — hai ca widget test canh đúng cặp số ấy.

#### Ghép hai chuỗi, không dựng chuỗi thứ ba

`dongTienTuDo()` ở `analytics/domain/dong_tien_tu_do.dart` nhận `ThongKeKy.chuoi`
và `ThongKeKy.chuoiVayNo` rồi ghép **theo chỉ số**. Cả hai đã đi qua
`khoanVaoThongKe` và đều lùi kỳ bằng `lui`, nên chúng cùng sáu kỳ, cùng thứ tự
cũ nhất trước. Dựng chuỗi thứ ba từ giao dịch thô là cách chắc chắn nhất để hai
khối trên cùng một trang nói hai con số cho cùng một tháng.

⚠️ Hàm **ném `ArgumentError`** khi hai chuỗi lệch độ dài **hoặc** lệch `ky` ở bất
kỳ vị trí nào. Ghép theo chỉ số mà hai nguồn lệch một kỳ là gán số trả nợ của
tháng này cho thu nhập của tháng khác — biểu đồ vẫn vẽ ra một đường trông hợp
lý, và không ai biết.

Chốt ấy kéo theo một thay đổi ở **test**: helper `_tk` của
`analytics_page_test.dart` trước đây để `chuoiVayNo` mặc định **rỗng** trong khi
`chuoi` mặc định có sáu điểm — một `ThongKeKy` **không tồn tại trong đời thực**,
vì repository luôn dựng cả hai chuỗi từ cùng một `ky`. Nay mặc định của nó là
sáu `DiemVayNo` rỗng đúng theo `chuoi`. Cho widget nuốt `ArgumentError` thay vì
sửa dữ liệu test là biến một lỗi lập trình thành một khối biến mất **im lặng**.

#### Khối luôn hiện, và đường được phép âm

Người dùng chốt **luôn hiện** khi kỳ có giao dịch — kể cả khi không ai nợ ai,
lúc đó đường này trùng khít đường "Thu" của khối trên. (`thongKe.rong` vẫn chặn
trang không có giao dịch.)

Đường **được phép xuống dưới 0**, và không kẹp: kẹp về 0 là giấu đúng kỳ người
dùng cần thấy nhất. Bốn thứ đi kèm để kỳ âm đọc được ngay:

- `minY` nhận số âm — thang đo dựng từ `san = day * 1.15`, trần `san + 3 * buoc`
  (đúng khuôn chống G39: trần phải là **đúng** ba lần bước, không phải con số đã
  đem chia);
- **vạch 0 nét đứt** qua `extraLinesData`, chỉ vẽ khi dải có phần âm — khi mọi
  kỳ đều dương thì `san` đã bằng 0 và vạch trùng mép dưới;
- **chấm của kỳ âm đổi sang màu chi** — đổi màu theo từng *điểm* thì chính xác;
  đổi màu cả đoạn đường phải dựa vào hộp bao của đường, thứ **không** trùng với
  dải của biểu đồ, nên bản ấy sai ở đúng những ca khó thấy nhất;
- `belowBarData` và `aboveBarData` đều đặt `applyCutOffY: true, cutOffY: 0`, nên
  vùng tô xanh chỉ là phần dương và vùng tô đỏ chỉ là phần âm. Thiếu vế thứ hai
  thì vùng tô đổ suốt xuống đáy và kỳ âm trông y hệt kỳ dương.

Dòng giải nghĩa dưới tiêu đề — *"Thu nhập sau khi trả nợ; không tính tiền đi vay
và thu hồi nợ"* — là **bắt buộc**, cùng lý do khối Dòng tiền luôn kèm câu "Suy
ngược từ số dư hiện tại": con số này không tự giải thích, và nó **khác** con số
"Tổng thu" ở đầu trang. Hai khối kề nhau nói hai con số mà không nói vì sao là
cách chắc chắn để người đọc tưởng một trong hai bị sai. Có ca test canh đúng câu
ấy.

Tiêu đề đổi theo đơn vị kỳ (`tieuDeDongTienTuDo`, cùng khuôn `tieuDeXuHuong`):
6 tuần · 6 tháng · 6 quý · 6 năm; kỳ tuỳ chọn rơi về "tháng" vì chuỗi của nó
cũng lùi theo tháng.

#### Lỗi mà máy ảo bắt được: nhãn trục in `-0`

Biểu đồ có phần âm nên biên trên tính bằng `san + 3 * buoc`, và sai số dấu phẩy
động cho ra một số cỡ `-1e-16` ngay tại vị trí lẽ ra là 0. `rutGon` dán dấu trừ
vào con số làm tròn thành 0, nên nhãn trục tung trên cùng in **`-0`** — một con
số không tồn tại. `flutter test` mù hẳn: nhãn trục vẽ trong canvas của fl_chart.

Sửa tại **`rutGon`** chứ không tại khối này: `-0` không bao giờ là nhãn đúng ở
đâu cả, và đây đúng là luật mà `CurrencyFormatter.formatCoDau` đã có — **số 0
không mang dấu**. Số âm thật vẫn giữ dấu (`-1` → `-1`, `-950000` → `-950K`); chỉ
khi phần nguyên làm tròn ra 0 thì bỏ dấu. Bẫy **4.20**.

#### Không đổi gì ở tầng dưới

Không đổi schema (vẫn **v22**), không thêm trường đồng bộ, **không đụng
repository** — cả hai chuỗi đã có sẵn trong `ThongKeKy` từ lát #4/#5.

#### Màn Stitch

**`212befc8f9a24d25ab027c7302e2e122`** *"Thống kê - Biểu đồ Dòng tiền tự do"*
(đo được 2026-09-15). ⚠️ Lượt `generate_screen_from_text` trả về **`timeout`**,
và lượt `list_screens` ngay sau đó vẫn 55 màn; màn hiện ở lượt kiểm sau, đúng
bài học đã trả giá ba lần — **timeout không phải thất bại, đừng gọi lại**. Chỉ
ghi cái đo được: một màn mới xuất hiện không tự nó chứng minh lượt gọi nào tạo
ra nó.

#### Nghiệm thu

Trên `emulator-5554`, kỳ T9 2026, ba trạng thái đều chạy thật:

1. **Không vay nợ nào** — khối vẫn hiện, con số `14.625.000đ` khớp tổng thu,
   đường phẳng ở 0 suốt T4–T8 rồi vọt lên ở T9.
2. **Thêm `Đi vay` +5.000.000 (tiền vào)** — con số **không đổi**, vẫn
   `14.625.000đ`. Đây là ca lật thiết kế.
3. **Thêm trả nợ 20.000.000 (`Đi vay` + tiền ra)** — con số thành
   **`-5.375.000đ`** màu đỏ, vạch 0 nét đứt hiện, vùng đỏ nằm giữa mốc 0 và
   đường, chấm cuối đỏ. Nhãn trục tung `0 · -2.1M · -4.1M · -6.2M`, sáu nhãn
   trục hoành `T4…T9` không dính nhau.

Hai giao dịch thử đã xoá qua giao diện; truy vấn PostgreSQL xác nhận cả hai mang
`Deleted_at`.

### 3.25 Khảo sát app thị trường lần hai — và vì sao chọn hai mục

**2026-09-15.** Lượt khảo sát ở mục 3.15 (2026-09-09) chỉ phục vụ **màn Xem
trước báo cáo** và chỉ xem bốn app. Lượt này soát cả **trang Thống kê**, và mở
rộng sang **Monarch Money**, **YNAB**, **Rocket Money** bên cạnh Money Lover,
MISA MoneyKeeper, Copilot, PocketSmith.

#### FlowMoney đang ở đâu

Đo bằng mã cùng ngày: trang Thống kê **12 khối** (⚠️ **13 từ 2026-09-16**, khi khối *Dự báo 30 ngày tới* vào — mục 3.27), màn Xem trước **10 khối** cộng
xuất PDF/CSV lưu thẳng vào máy. Ba khối đang **hơn** mặt bằng app Việt — thác
nước "Tiền đi đâu", dòng tiền tự do, và hai biểu đồ vay/nợ; Money Lover và MISA
đều không có. Gắn ngân sách vào báo cáo cũng vẫn là chỗ mạnh hơn Money Lover
(mục 3.15).

#### Chín mục thị trường có mà mình chưa có

| # | Tính năng | Ai có | Dữ liệu FlowMoney | Chốt |
|---|---|---|---|---|
| 1 | **Tỷ lệ tiết kiệm** | Monarch (ngay trên Cash Flow) | ✅ có sẵn; `dongTienTuDo()` đã trả `thuNhap` đúng nghĩa | ✅ **làm** |
| 2 | So cùng kỳ năm trước | Monarch, Copilot | ✅ `lui()` đã lùi theo đơn vị lịch | ✅ **XONG 2026-09-16**, mục **3.28** |
| 3 | Sankey (A8 #11) | Monarch — *"fan favorite"*, chia sẻ được, ẩn được số tiền | ✅ đủ | 🛑 **bỏ** 2026-09-16 |
| 4 | **Dự báo dòng tiền** | PocketSmith — chiếu số dư tới từng ngày, 30–60 năm | ✅ nguyên liệu hiếm: hoá đơn lặp có `anchorDay`+`recurrence`+`autoPay`, ngân sách có kỳ, mục tiêu có trích tự động | ✅ **XONG 2026-09-16**, mục **3.27** |
| 5 | Tài sản ròng theo thời gian | Monarch, PocketSmith | ⚠️ làm được nhưng lệch có điều kiện — xem dưới | ✅ **XONG 2026-09-17**, mục **3.30** — và đổi tên thành **"Tổng tài sản"**: app không có mô hình công nợ |
| 6 | Lịch chi tiêu (heatmap) | PocketSmith, Money Lover | ✅ đủ | ✅ **XONG 2026-09-16**, mục **3.29** |
| 7 | Cảnh báo bất thường | Rocket Money | ✅ đủ, đã có hạ tầng thông báo | ✅ **XONG 2026-09-17** — loại thông báo **thứ 17**, mục **5f** `NOTIFICATION_FEATURE.md`. "Bất thường" là **ngưỡng người dùng đặt**, không phải thống kê theo danh mục |
| 8 | Phát hiện chi định kỳ tự động | Rocket Money | ⚠️ thiếu trường đối tác → phải đoán | 🛑 **bỏ** |
| 9 | Chi theo đối tác (merchant) | Monarch, Copilot | ⛔ chặn thật — không có cột `payee` | 🛑 **bỏ** |

Người dùng chốt **#1 rồi #4** — cả hai **đã xong**: #1 ở mục 3.26 (2026-09-15), #4 ở mục **3.27** (2026-09-16). Và **bỏ hẳn #8, #9**: #9 cần một cột mà cả hai đầu
đều không có, còn #8 mà không có đối tác thì phải đoán bằng danh mục + số tiền,
và đoán sai thì **hỏng im lặng** — không đáng cho đồ án.

🛑 **Thêm ngày 2026-09-16: #3 (Sankey) cũng bỏ hẳn** — cùng lượt người dùng đóng
A8 #9 và #11, nguyên văn *"bỏ biến động khoản vay với Sankey đi không cần thiết
nữa"*.

*(Ảnh chụp sáng 2026-09-16, nay đã lỗi thời: "Bốn mục còn **chưa** — #2, #5, #6,
#7". Cùng ngày **#2 xong** (mục 3.28) và **#6 xong** (mục 3.29); **#5 xong** ngày
2026-09-17 (mục 3.30). Còn **#7**.)* *(Ảnh chụp 2026-09-16, nay đã lỗi thời: "Còn lại **hai** ô trống thật … **#5**
tài sản ròng theo thời gian và **#7** cảnh báo bất thường." **#5 xong
2026-09-17** — mục **3.30**.)* *(Ảnh chụp 2026-09-17 sáng, nay đã lỗi thời: "Còn lại **một** ô trống thật … **#7** cảnh báo bất
thường." **#7 xong** chiều cùng ngày.)* Bảng khảo sát lần hai nay **ĐÓNG**: **sáu** mục đã
làm (#1, #2, #4, #5, #6, #7) và **ba** mục bỏ hẳn (#3, #8, #9) — vừa đủ chín. ⚠️ **#7 không nằm ở trang Phân
tích** — nó là loại thông báo thứ **18**, đụng `docs/NOTIFICATION_FEATURE.md` và
mười ba cái bẫy của tệp ấy.

#### ⚠️ Mục 5 lật một giả định, và cũng tự đặt ra giới hạn của nó

> **Đính chính 2026-09-17, sau khi làm xong mục 5 (mục 3.30).** Khối dưới đây
> đúng ở vế "không bị chặn bởi mô hình dữ liệu", nhưng **sai ở vế cái chặn**:
> vách do khoản neo ghi ngày vá **đo được là không tồn tại** trên dữ liệu thật
> (bốn ví đều có `Balance` khớp đúng tổng sổ, không khoản neo nào). Giới hạn
> thật — lớn hơn và phổ biến hơn — là mọi mốc **trước giao dịch đầu tiên** đều
> cho một con số vô nghĩa, và nó bao trùm luôn ca khoản neo. Xem mục **3.30**.

Nếu chỉ đọc mục 3.16 thì sẽ kết luận "không lưu lịch sử số dư → chịu". Nhưng từ
**G37** (2026-09-13) `wallets.balance` là **cache của một công thức** trên sổ
giao dịch, nên số dư tại **mọi thời điểm** suy lại được — mục 5 **không** bị
chặn bởi mô hình dữ liệu.

Cái chặn nó là chỗ khác, và nhỏ hơn: khoản neo "Số dư ban đầu" được ghi với
`date: now` (`so_du_vi_service.dart:119`) — tức **ngày vá**, không phải ngày tạo
ví. Nên đường **tổng tài sản** *(tên chốt khi làm mục 3.30; khối này viết trước đó
nên còn gọi là "tài sản ròng")* **đúng từ 2026-09-13 trở đi**, còn trước mốc
ấy thì thiếu số dư khởi điểm của những ví có trước G37. Cùng họ giới hạn với mục 3.16,
và nếu làm thì **phải nói ra trên giao diện** chứ không giấu.

Đây là lần thứ ba bài học ấy trả tiền: **một mục bị xếp "chặn bởi mô hình dữ
liệu" thì phải hỏi *chặn vì thiếu con số nào*.** Hai lần trước là A8 #4/#5 và
A8 #8.

### 3.26 Tỉ lệ tiết kiệm — mục #1 của khảo sát lần hai

**2026-09-15.** Một dòng nhỏ trong thẻ "Số dư còn lại": *"Để dành 93% thu
nhập"*. Monarch đặt con số này ngay trên trang Cash Flow; FlowMoney đặt nó ngay
dưới con số mà nó diễn giải.

#### Mẫu số là THU NHẬP, không phải `tong.thu`

Cùng cái bẫy của A8 #8, và lần này nó còn dễ vấp hơn vì công thức sách vở là
`(thu − chi) / thu`. Nếu lấy `tong.thu` thì tháng nào người dùng vay tiền, tỉ lệ
tiết kiệm lại **đẹp lên** — mẫu số phình ra vì tiền mượn.

Để hai chỗ không thể lệch nhau, phép tính *thu nhập* được **tách thành hàm
riêng** `thuNhapCua()` trong `dong_tien_tu_do.dart`, và `dongTienTuDo()` nay gọi
chính nó. Có ca test canh `thuNhapCua` trả **đúng** con số mà `dongTienTuDo`
dùng — hai phép tính song song cho cùng một khái niệm là cách chắc chắn nhất để
chúng trôi khỏi nhau ở lần sửa đầu tiên.

#### Trả nợ tính là TIÊU — người dùng chốt

`tyLeTietKiem({thuNhap, chi})` với `chi` là **tổng chi**, tức đã gồm cả trả nợ.

Tính trả nợ là *để dành* thì đúng hơn về kế toán — trả nợ gốc làm tăng tài sản
ròng — nhưng khi ấy con số này sẽ **khác** "Số dư còn lại" hiện ngay trên nó,
và hai con số cạnh nhau nói hai chuyện khác nhau thì người đọc chỉ kết luận
được một điều: một trong hai sai. Người dùng chốt phương án khớp.

#### Ba chốt, cả ba đều hỏng im lặng nếu phá

1. **`null` khi thu nhập không dương** → giao diện **ẩn hẳn dòng**. "Tiết kiệm
   bao nhiêu phần trăm của số không" là câu không có nghĩa, và chia cho mẫu số
   **âm** cho ra tỉ lệ **đảo dấu** — đọc ngược hẳn ý nghĩa mà không lỗi nào báo.
   ⚠️ Thu nhập âm xảy ra được thật: một kỳ chỉ có tiền đi vay thì `tong.thu` trừ
   `diVay` ra số âm. In `0%` ở đó là bịa một con số. Ca test này **xanh ngay từ
   đầu** — phải thử bản sai (`tyLe ?? 0`) mới biết nó canh thật.
2. **Tỉ lệ được phép âm**, không kẹp về 0 — cùng lý lẽ với đường dòng tiền tự
   do: kẹp là giấu đúng kỳ người dùng cần thấy nhất.
3. **Chuỗi vay/nợ rỗng thì bỏ qua** thay vì coi như không có vay/nợ: không có gì
   để suy ra phần vay/nợ của kỳ, và đoán bừa là bịa.

#### Nghiệm thu

`emulator-5554`, kỳ T9 2026: thu 14.625.000, chi 1.045.000, không có khoản
vay/nợ nào → dòng hiện **"Để dành 93% thu nhập"**, khớp
`13.580.000 / 14.625.000 = 92,85%`. Không tràn ở 411dp. `flutter test`
**2571/2571**, `flutter analyze` **25 issue, 0 error**, schema giữ **v22**,
không thêm trường đồng bộ, không đụng repository.

### 3.27 Dự báo dòng tiền 30 ngày tới — mục #4 của khảo sát lần hai

**2026-09-16.** Spec: `docs/superpowers/specs/2026-09-16-du-bao-dong-tien-design.md`.
Khối đứng **ngay sau thẻ tổng**, và cũng hiện ở nhánh kỳ rỗng — nó không nói về
kỳ đang xem. Màn Stitch: **`732587777370466098aa98d17bd0cbd4`** *"Thống kê - Dự
báo 30 ngày tới"*.

#### Trả lời câu gì — và cố ý KHÔNG trả lời câu gì

*"Còn tiêu được bao nhiêu sau khi trừ những thứ **chắc chắn** phải trả trong 30
ngày tới?"* Ba con số: số dư hiện tại → **còn tiêu được** → *nếu tiêu đúng ngân
sách*; cộng cảnh báo ví thiếu, biểu đồ bậc thang 31 điểm, và danh sách cam kết.

⚠️ **Không có thu nhập trong dự báo.** App không lưu thu nhập ở đâu cả — không
hoá đơn "thu", không lương định kỳ, và cột `payee` không có nên không tự phát
hiện lương từ lịch sử được (đúng lý do mục #8 của bảng khảo sát bị bỏ). Ba lối
đã cân nhắc, người dùng chốt lối thứ ba:

| Lối | Chốt | Vì sao |
|---|---|---|
| Đường số dư tương lai, thu nhập **suy từ trung bình** các kỳ gần đây | ✗ | Một con số **đoán** ngồi cạnh những con số thật; tháng nào vay tiền thì trung bình vọt lên, im lặng — đúng bẫy `tong.thu` của mục 3.24 |
| Đường số dư tương lai, người dùng **tự khai** thu nhập định kỳ | ✗ | Cần bảng mới và một màn nhập; phạm vi lớn hơn hẳn |
| **Cam kết đã biết chắc + còn tiêu được** | ✅ | Chỉ chiếu thứ đã có luật chạy thật; không đoán; không đổi schema |

Hệ quả cố ý: mọi con số **được phép âm** và không kẹp — kẹp về 0 là giấu đúng
cảnh báo người dùng cần thấy.

#### Hai tầng, và vì sao tách

Tầng 1 **chắc chắn**: hoá đơn `conPhaiTra` tới hạn trong 30 ngày (kể cả kỳ
tương lai chiếu từ hoá đơn lặp) + các kỳ trích tự động vào mục tiêu. Tầng 2
**nếu tiêu đúng kế hoạch**: phần *còn lại* của ngân sách kỳ hiện tại. Gộp một
con số là trộn "phải trả" với "định tiêu" — hai thứ khác hẳn nhau về mức chắc
chắn.

#### Luật, và chỗ đặt

Toàn bộ phép tính ở **`analytics/domain/du_bao_dong_tien.dart`** (hàm thuần
`duBaoCua`); repository chỉ nối nguồn, widget chỉ vẽ.

- **Kỳ tương lai của hoá đơn** mượn **`kyKeTiepCua(Bill)`** — hàm thuần **mới**
  ở `features/bill/domain/bill_ky_ke_tiep.dart`, tách nguyên văn phép tính ngày
  khỏi `BillRepositoryImpl._nextPeriodOf`, và `_nextPeriodOf` **gọi lại** nó.
  Một định nghĩa, nên hàng thật sinh ra khi trả tiền không bao giờ lệch với kỳ
  đã dự báo (có ca test canh hai bên).
- **Kỳ trích tự động** mượn `mocThuN` + `quyetDinhTrich` của
  `goal_auto_deposit.dart`, kèm **ba chốt bỏ qua** của `GoalAutoDepositRunner`.
- **Tầng 2** mượn `budgetPaceOf`: đóng góp `suggestedPerDay × min(daysLeft, 30)`
  — ngân sách quý còn 60 ngày chỉ tính nửa phần còn lại.
- **Số dư** đọc `wallets.balance` qua `viTinhVaoTong`, cùng luật Trang chủ.

**Luật chuyển ví**: hoá đơn trừ ví trả; trích tự động trừ ví nguồn và **cộng**
ví đích — nên tác động lên *tổng* thường bằng 0, trừ khi ví đích không tính vào
tổng (ví Tiết kiệm bị loại, hoặc mục tiêu chưa gán ví). Theo **từng ví** thì
tiền rời ví là thật dù tổng không đổi — đó là thứ `ViThieu` đo.

#### Mười một bẫy, tất cả hỏng im lặng

Đủ ở §6 spec. Bốn cái đáng nhớ nhất:

1. ⚠️ **Nguồn ngân sách phải tra tại `now`, không phải tại mốc kỳ đang xem.**
   `watchKy` nay có **bảy** nguồn, và nguồn thứ bảy là `watchBudgets(now: at)`
   **riêng** cho dự báo. Mốc cũ (`mocNganSach`) lùi về giây cuối kỳ khi người
   dùng xem kỳ đã qua, nên dùng chung thì dự báo **đúng khi xem tháng này và
   sai khi xem tháng khác**. Bản sai cho ra đúng 2.200.000 thay vì 1.200.000.
2. ⚠️ **Đếm đôi ngân sách × hoá đơn.** Tiền điện 800k nằm ở tầng 1 **và** trong
   "còn lại" của ngân sách Điện nước; tầng 2 phải trừ hoá đơn cùng danh mục
   (ngân sách tổng trừ mọi hoá đơn), kẹp ≥ 0.
3. ⚠️ **Ví đích của trích tự động không tính vào tổng.** Quên nhánh này là mọi
   khoản trích ra 0 ròng, và người tích vào ví Tiết kiệm đã loại khỏi tổng thấy
   "còn tiêu được" cao hơn thật đúng bằng số trích.
4. ⚠️ **Lệch một ô ở điểm 0.** Cam kết quá hạn dồn về hôm nay phải nằm ở **điểm
   đầu** chuỗi — `!isAfter`, không phải `isBefore`.

#### ⚠️ Giới hạn đã biết, cố ý không vá

Kỳ chiếu khử trùng bằng `generatedFromBillId`, tức **chỉ chiếu từ hàng cuối
chuỗi**. Hàng người dùng **tự tạo tay** cho kỳ sau không có cột ấy → đếm đôi.
Vá bằng so tên + ngày là đi lại đúng lối so bằng tên mà cột `goalId` sinh ra để
thay thế, và hỏng theo chiều tệ hơn: một hoá đơn **thật** biến mất khỏi dự báo.

#### Nghiệm thu máy ảo — nó lật hai thứ 2633 ca test đều mù

`emulator-5554`, 16/09/2026, dữ liệu thật: số dư 13.590.000, 11 cam kết trong
30 ngày (hoá đơn tuần `Kiem` 45.000 chiếu 18/09 → 25/09 → 02/10 → 09/10, hoá
đơn `di h0c` 10.000, và một khoản trích `MuaXe` 100.000 ngày 06/10). Ba con số
đúng phép cộng tay; cảnh báo *"Ví test thiếu 240.000đ để trả cam kết ngày
23/09"*; "Xem thêm (6)" mở đủ 11 dòng; 0 pixel vàng.

**Hai lỗi chỉ máy thật thấy, cả hai đều về trục biểu đồ** — xem bẫy **4.21**.
Sau khi sửa: nhãn trục **13M · 13.2M · 13.4M · 13.6M**, bậc thang rơi đúng ngày
cam kết.

`flutter test` **2643/2643** (gồm 3 ca của G42), `flutter analyze` **25 issue,
0 error**, schema giữ **v22**, **không thêm trường đồng bộ**.

#### Phát hiện bên lề → ✅ **G42, đóng cùng ngày**

Lượt soát tài liệu của chính mục này lộ ra một lỗi **có sẵn**:
`analytics_repository_impl.dart` đăng ký ví bằng `db.select(db.wallets)` **không
lọc `deletedAt`** (cố ý — bảng tra tên cần hàng đã xoá), rồi cộng `balance` qua
`viTinhVaoTong`, hàm khi ấy chỉ hỏi hai vế. Nên **"số dư cuối kỳ" của khối Dòng
tiền và thác nước cộng cả ví người dùng đã xoá** — ca tái hiện đo 17.000.000 thay
vì 10.000.000.

⚠️ **Hẹp hơn lần báo đầu:** `bao_cao_repository_impl.dart:84` và
`wallet_repository_impl.dart:115` **không sai** — cả hai đi qua
`walletDao.getAll`, và hàm ấy **có** lọc `deletedAt`. Chỉ một chỗ hỏng.

Sửa bằng cách đưa vế `isDeleted` **vào chính `viTinhVaoTong`** (mặc định
`false`) chứ không vá ở chỗ gọi — `vi_tinh_vao_tong_test.dart` vốn sinh ra để
chặn "bản chép tay thứ năm" của luật này, và đây đúng là bản thứ năm. Chi tiết:
**G42** `docs/CLIENT_APP_KNOWN_GAPS.md`.

### 3.28 So cùng kỳ năm trước — mục #2 của khảo sát lần hai

**2026-09-16.** Hai thẻ tổng vốn chỉ so với **kỳ liền trước**. Nay có một hàng
**hai chip** ngay trên chúng — *"So với kỳ trước"* · *"Cùng kỳ năm trước"* — và
dòng "so với …" đang có đổi theo chip. Monarch và Copilot đều đặt con số này
ngay cạnh số của kỳ.

Chip trái bật sẵn, tức **người dùng cũ mở trang lên không thấy gì đổi**.

#### Không có nguồn dữ liệu thứ tám

`watchKy` đã nạp **toàn bộ** giao dịch của tài khoản (`transactionDao.watchAll`)
chứ không phải phần đã cắt theo kỳ — chuỗi xu hướng nhìn xa sáu kỳ nên nó buộc
phải thế. Vì vậy kỳ năm trước chỉ là **một lời gọi `tongThuChi` nữa** trên đúng
danh sách ấy: không stream mới, không truy vấn mới, không schema, không trường
đồng bộ.

#### ⚠️ Tuần lùi 52 kỳ — phép đo lật ngược trực giác

Đây là chỗ đắt nhất của lát này, và **bản thiết kế đã duyệt ghi sai**. Thiết kế
nói "tuần neo vào **ngày dương lịch** năm trước, **không** lùi 52 tuần vì 52
tuần là 364 ngày nên nó trôi một ngày mỗi năm". Cài xong thì một ca test đỏ, và
thay vì sửa test cho xanh thì đo:

| Lối | Lệch `lui(ky, 52)` | Số ngày **chồng lấp ít nhất** với 7 ngày cùng lịch năm trước |
|---|---|---|
| Neo vào thứ Hai (thiết kế đề xuất) | 3131/3131 | **1** |
| Neo vào **thứ Năm** — ngày định danh tuần ISO | **0**/3131 | **5** |

Đếm bằng máy 2026-09-16 trên **3131 tuần của 60 năm** (2000–2060). Lý do: `from`
của một tuần luôn là **thứ Hai**, mà thứ Hai ấy năm ngoái thường rơi vào **Chủ
nhật**, tức thuộc tuần *trước đó* — nên kỳ so sánh gần như không chồng lấp kỳ
cần so. Cái "trôi một ngày" mà thiết kế chê lại chính là thứ giữ cho phép lùi
bám đúng tuần.

Kết luận: `DonViKy.tuan => lui(ky, 52)`. Bài học chung — **một ca test đỏ có thể
đang tố cáo bản thiết kế chứ không phải bản thi công**; đo trước, đừng sửa bên
nào cho xanh.

⚠️ Cũng **không** dùng "cùng số tuần ISO": tuần 53 chỉ tồn tại ở một số năm, nên
lối ấy có lúc trỏ vào một kỳ không có thật.

#### Ba chốt còn lại, cả ba hỏng im lặng

1. **Khoảng tuỳ chọn giữ NGUYÊN độ dài** — `to' = from' + (to − from)`. Dời riêng
   từng mốc thì kỳ bắt đầu 29/2 (Dart chuẩn hoá thành 1/3) dài hơn hoặc ngắn hơn
   một ngày, và phần trăm so hai kỳ **lệch độ dài** trông vẫn rất hợp lý. Ngược
   lại, tháng/quý/năm thì độ dài **được phép** khác nhau (2/2028 có 29 ngày,
   2/2027 có 28) — một tháng là một tháng.
2. **Nhãn tuần lấy năm ISO, không lấy `from.year`.** Tuần bắt đầu 30/12/2024 là
   tuần **1 của 2025**; in "Tuần 1 2024" là sai hẳn một năm. Ca ấy xảy ra thật
   với tuần cuối tháng 12 — bản sai có chủ ý in đúng "Tuần 1 2024".
3. **Cặp *số* và *nhãn* phải lấy cùng một chỗ.** `nenSoSanh` ở
   `domain/moc_so_sanh.dart` trả cả hai cùng lúc. Lấy số của năm trước mà in
   nhãn kỳ trước — hoặc ngược lại — cho ra một câu **hoàn toàn hợp lý và hoàn
   toàn sai**; bản sai có chủ ý chứng minh ca test bắt được đúng chỗ đó.

Và cái bẫy cũ của mục 3.19 lặp lại nguyên vẹn: **stream phát lại sau mỗi chu kỳ
đồng bộ**, nên cubit phải chép `_mocSoSanh` sang **mọi** state mới. Quên là chip
nhảy về "kỳ trước" giữa lúc người dùng đang đọc con số năm ngoái, và hai thẻ đổi
nghĩa mà không báo gì. Khác `phanLoaiDangXem`, mốc so sánh **được giữ khi đổi
kỳ**: nó là một cách *nhìn*, không phải câu hỏi của riêng một kỳ.

#### ⚠️ Nền bằng 0 là ca THƯỜNG, không phải ca hiếm

Mọi tài khoản chưa đủ một năm tuổi đều không có nền năm trước ở **mọi** kỳ — kể
cả tài khoản thử đang dùng để nghiệm thu. `phanTramSoVoi` trả `null`, và thẻ nói
*"Không có dữ liệu T9 2025"* thay vì bịa "tăng 100%". Người dùng chốt lối này
(thay vì khoá chip hoặc giấu cả hàng) để tính năng vẫn nhìn thấy được khi bảo vệ
đồ án.

#### Nghiệm thu máy ảo

Chạm chip đổi được cả nhãn lẫn số; nhãn theo đúng đơn vị (`T9 2025`, `Q3 2025`);
lựa chọn **giữ nguyên khi đổi kỳ**; không tràn ở 411dp. Màn Stitch:
**`6333b8e24aab4f92bd73b1282c56b17c`** *"Thống kê - Mốc so sánh kỳ"* — lượt gọi
này **không** timeout, trả về ngay; ⚠️ nó vẫn mang `deviceType: DESKTOP` dù
truyền `MOBILE`, đúng hiện tượng đã ghi cho `afe1c3fd…`.

⚠️ Lượt nghiệm thu này còn lộ ra một lỗi **có sẵn, không thuộc lát này**: nút
**"Tuỳ chọn"** của bộ chọn phạm vi ném assertion và không làm gì, hoàn toàn im
lặng — **G43** `docs/CLIENT_APP_KNOWN_GAPS.md`.


### 3.29 Lịch chi tiêu — mục #6 của khảo sát lần hai

**2026-09-16.** Một lưới lịch tháng, ô đậm nhạt theo **tổng chi của ngày**; chạm
một ô thì thẻ tóm tắt hiện ngay dưới lưới. Khối **chỉ hiện khi đơn vị đang xem
là Tháng**.

#### Lịch tháng, không phải dải kiểu GitHub

PocketSmith và Money Lover đều vẽ thứ này dưới dạng **lịch**. Một dải 7×N cho
mọi đơn vị thì gọn hơn về mã, nhưng ô ngày mất chỗ in số — người dùng phải chạm
mới biết đó là ngày nào. Kỳ khác tháng thì **ẩn hẳn khối** (một lưới 91 ô ở
411dp không đọc được), cùng lối với thanh ngân sách ở bẫy #1 mục 3.20.

Chốt ấy đặt ở **hai lớp** — `if` trong `_than()` và guard đầu `build`. Đo bằng
bản sai: phá **lớp 1** thì ca test vẫn xanh (lớp 2 đỡ); phá **cả hai** mới đỏ.

#### Không nguồn dữ liệu mới — và một phép gom được gộp lại

`soLieuNhanhCua` **đã dựng sẵn** một map `chiTheoNgay` bên trong nhưng không lộ
ra. Nên việc chính không phải viết phép gom mới mà là **tách nó thành hàm dùng
chung**: `lichChiTieuCua` ở `analytics/domain/lich_chi_tieu.dart`, và
`soLieuNhanhCua` gọi lại nó. Cùng khuôn `thuNhapCua` / `dongTienTuDo`.

Lợi ích cụ thể, có ca test canh: **"ngày chi nhiều nhất" của khối Số liệu nhanh
và ô đậm nhất của lịch không thể nói hai ngày khác nhau.** Hai vòng lặp song
song cho cùng một khái niệm là cách chắc chắn nhất để chúng trôi khỏi nhau ở lần
sửa đầu tiên.

Repository chỉ thêm **một dòng** — `trongKy` đã có sẵn trong `_dung` cho ba khối
mượn từ trang Báo cáo. Không schema, không trường đồng bộ.

#### ⚠️ Thang màu neo vào TRUNG BÌNH, không vào ngày lớn nhất

Đây là chốt dễ hỏng **im lặng** nhất của khối. Neo vào max thì **một ngày mua
sắm lớn làm phẳng cả tháng**: 29 ngày còn lại rơi hết về bậc nhạt nhất và lưới
trông như tháng không tiêu gì. Trung bình thì chịu được một điểm ngoại lai — ca
test dựng đúng hình ấy (ba mức chi quanh trung bình cộng một ngày gấp 30 lần) và
đòi bốn mức khác nhau ra **bốn bậc khác nhau**.

Mượn `soLieu.chiMoiNgay` đã có — nó chia cho **số ngày của kỳ**, không phải số
ngày có giao dịch. Bậc: `0` không chi · `1` ≤ 0,5× · `2` ≤ 1× · `3` ≤ 2× ·
`4` > 2×. `trungBinh` bằng 0 thì phép chia ra `Infinity`, vẫn so sánh được, và
mọi ngày *có* chi rơi về bậc cao nhất — đúng nghĩa.

#### Ba chốt còn lại

1. **Ngày không chi có bậc 0 RIÊNG.** Một đồng vẫn là có tiêu; gộp vào bậc 0 là
   để "tháng không tiêu gì" trông y hệt "tháng tiêu ít".
2. **Lưới bắt đầu thứ Hai** (quy ước VN), số ô trống là `weekday - 1`. Chủ nhật
   đứng cuối và cho **sáu** ô trống. Lệch một ô là **cả tháng lệch một cột**, mà
   lưới nhìn vẫn rất hợp lý — máy ảo xác nhận 01/09/2026 rơi đúng cột T3.
3. **`nhanNgayLich` tự viết tên thứ** thay vì `DateFormat('EEEE', 'vi')`: hàm
   thuần thì widget test nào quên `initializeDateFormatting` cũng không làm *cả
   cây dừng dựng* (đã vấp ở khối Top 5). ⚠️ Chủ nhật **không** phải "Thứ Tám" —
   `DateTime.sunday == 7`, nên công thức `'Thứ ${weekday + 1}'` đúng sáu ngày
   rồi sai ngày thứ bảy.

#### Hai thứ chỉ máy ảo và bản sai mới lộ ra

- ⚠️ **`_tieuDeKhoi` là `SizedBox(width: double.infinity)`** — nó dành cho
  `Column`. Đặt trần vào `Row` để thêm nhãn kỳ bên phải là ép bề rộng vô hạn và
  **cả cây dừng dựng**: **66/74** ca test của trang đỏ cùng lúc, kể cả những ca
  không liên quan gì tới lịch. Bọc `Expanded` là xong.
- ⚠️ **Ca "chưa chạm thì chưa có thẻ tóm tắt" ban đầu KHÔNG canh được gì.** Nó
  chỉ cấm chữ *"khoản"*; bản sai hiện sẵn thẻ cho ngày đầu tháng — ngày ấy không
  có chi nên thẻ nói *"Không chi"* — và ca vẫn xanh. Nay nó cấm **cả ba** mặt
  của thẻ. Cùng bài học với G43: **ca test cho một nút phải đòi kết quả, không
  chỉ đòi "không có thứ tôi nghĩ tới".**

#### Nghiệm thu máy ảo

Lưới 30 ô, ngày 1 ở cột T3; chạm ngày 5 → *"Thứ Bảy 05/09 · 1 khoản ·
-500.000đ"*, khớp khít *"NGÀY CHI NHIỀU NHẤT 05/09/2026"* của khối trên; chạm
ngày 10 → *"Không chi"*; đổi sang kỳ Quý → khối **biến mất**; `logcat` **0**
dòng `Unhandled Exception`.

⚠️ Máy ảo còn bắt một chỗ nhỏ: trong **cùng một thẻ** có hai định dạng tiền —
`-500.000đ` (`_dong`) và `500.000 đ` (`CurrencyFormatter.format`), khác nhau ở
khoảng trắng trước chữ `đ`. Dòng "Lớn nhất" nay dùng `_dong`. Ngoài thẻ ấy thì
cả hai vẫn cùng tồn tại trên trang, đúng như trước.

Màn Stitch: **`9020ff8b5c5d49c4914442dcd02fa540`** *"Thống kê - Lịch chi tiêu
Heatmap"*. ⚠️ Lượt gọi **trả về `timeout`** và màn vẫn được tạo — lần thứ hai
xác nhận *timeout không phải thất bại, đừng gọi lại*. ⚠️ Màn ấy vẽ lưới màu
**xanh lá** vì prompt viết thế; bản thi công dùng **đỏ** (`AppColors.expense`)
— cả app dùng đỏ cho khoản chi, và một lưới xanh cho "tiêu nhiều" đọc như một
lời khen.


### 3.30 Tổng tài sản theo thời gian — mục #5 của khảo sát lần hai

**2026-09-17.** Đường thứ **ba** của bộ sáu kỳ, đứng ngay sau *Xu hướng* và
*Dòng tiền tự do*: cùng dạng biểu đồ, cùng trục hoành, cùng số kỳ. Một con số
lớn (tổng tài sản hiện tại), một đường sáu điểm, và — khi cần — một câu nói
thẳng rằng đoạn đầu đường chưa có gì để dựa vào.

#### ⚠️ Vì sao KHÔNG gọi là "tài sản ròng"

Bảng khảo sát ở mục 3.25 mượn tên *net worth* của Monarch và PocketSmith, nhưng
FlowMoney **không có mô hình công nợ** — không dư nợ gốc, không lãi suất, không
kỳ hạn; đó đúng là lý do A8 #9 bị bỏ hẳn. Tiền **đi vay** nằm trong ví như mọi
đồng khác, nên một con số gọi là "tài sản ròng" sẽ **tăng lên đúng lúc người
dùng mắc nợ thêm** — sai theo chiều nguy hiểm, và sai im lặng. Người dùng chốt
lấy tên đo đúng thứ tính được: **tổng số dư các ví được tính vào tổng**, tại
từng mốc thời gian.

#### Vì sao suy ngược được, dù không lưu lịch sử số dư

Mục 3.16 kết luận "không lưu lịch sử số dư → chịu". Đó là ảnh chụp **trước
G37**. Từ 2026-09-13 `wallets.balance` thôi là dữ liệu gốc — nó là **cache của
một công thức** trên sổ giao dịch — nên số dư tại mọi thời điểm `T` suy lại
được: `soDu(T) = soDuHienTai − Σ biến động sau T`.

Đây là lần thứ **tư** bài học ấy trả tiền: *một mục bị xếp "chặn bởi mô hình dữ
liệu" thì phải hỏi chặn vì thiếu **con số** nào.* Ba lần trước là A8 #4, #5 và
#8.

#### ⚠️ Ba chỗ KHÁC `dongTienCua`, phá cái nào cũng hỏng im lặng

Khối *Dòng tiền* cũng suy ngược, nhưng **không** được chép sang:

1. **Không đi qua `khoanVaoThongKe`.** Hàm ấy loại khoản chuyển, khoản điều
   chỉnh số dư và khoản mở sổ — mà cả ba **đều làm đổi số dư ví thật**. Loại
   chúng là đường lệch đúng bằng tổng của chúng. Chốt nằm ở **kiểu dữ liệu**:
   `BienDongVi` cố ý **không mang** `categoryId` lẫn `ghiChu`, nên không ai lọc
   theo hai luật ấy được kể cả khi muốn — chắc hơn một câu chú thích.
2. **Tính theo TỪNG ví rồi mới lọc**, không lọc ví rồi cộng. Khoản chuyển giữa
   hai ví cùng tính vào tổng thì triệt tiêu, nhưng chuyển sang ví **bị loại
   khỏi tổng** thì có làm tài sản giảm. Gộp trước là mất nửa kia.
3. **Cửa sổ biến động đóng ở CẢ HAI đầu: `[moc, now]`.** Vế đầu kẹp mốc về
   `min(ky.to, now)` vì `ky.to` của kỳ đang xem nằm ở tương lai. Vế sau bỏ hàng
   ghi **ngày tương lai** khỏi phép trừ — và đây là chỗ bản đầu làm sai.

#### ⚠️ Vế thứ hai ấy: hàng ghi ngày tương lai

Lý do không phải kế toán mà là **tính nhất quán**. `wallets.balance` là tổng
**mọi** hàng còn sống *bất kể ngày*, nên một khoản hẹn ngày 10/10 đã nằm trong
số dư Trang chủ ngay hôm nay. Trừ nó ra là đường nói một con số còn Trang chủ
nói con số khác — người dùng đọc thành "biểu đồ hỏng". Giữ nó ở **mọi** điểm
thì cả đường kể đúng câu chuyện phần còn lại của app đang kể.

Dữ liệu thật có sẵn hai hàng như thế (đo 2026-09-16 trên tài khoản 10:
`2026-10-10` và `2026-11-10`, đều là khoản trích mục tiêu). **Kẹp mốc một mình
không cứu được**: hàng 10/10 vẫn nằm sau mốc `now` nên vẫn bị trừ. Ca test
"giao dịch ghi ngày TƯƠNG LAI" đỏ đúng ở bản chỉ có vế đầu.

#### Giới hạn, và cách nói ra

Suy ngược cho mốc **trước giao dịch đầu tiên** luôn ra một con số vô nghĩa
(thường là 0). Người dùng có 10 triệu từ tháng 8 mà mới ghi sổ từ 02/09 thì
đường nói họ trắng tay hồi tháng 8. Đó là số 0 **"chưa biết"**, không phải 0
"không có gì".

Nên khối làm hai việc: `mocThieuDuLieu` cho một câu dưới biểu đồ — *"Trước
02/09/2026 chưa có giao dịch nào để suy ra số dư."* — và `thayDoiTaiSan` trả
**`null`** thay vì in ra một khoản tăng bịa. Đừng thay `null` ấy bằng `?? 0`
hay một hiệu tính tay: điểm đầu khi ấy là số 0 "chưa biết", và hiệu với nó in
ra **nguyên cả tài sản** như thể người dùng vừa kiếm được ngần ấy trong sáu kỳ.

⚠️ **Phép đo lật giả định của mục 3.25.** Mục ấy lo rằng khoản neo *"Số dư ban
đầu"* ghi ngày vá (`so_du_vi_service.dart`, `date: now`) sẽ tạo một vách ngay
2026-09-13. Đo trên dữ liệu thật ngày 2026-09-17: cả bốn ví của tài khoản thử
có `Balance` khớp **đúng** tổng sổ (lệch `0`) và **không** khoản neo nào tồn
tại — số dư của họ vốn được dựng bằng giao dịch thật. Ca ấy nằm **gọn trong**
giới hạn ở trên và dùng chung một câu cảnh báo; không cần cơ chế riêng.

🔑 **Một phát hiện để dành, cố ý KHÔNG thi công:** server **có**
`wallet.Create_at` (`schema.prisma`, `@default(now())`) và đường pull **đã trả
nó về rồi** — `getWalletsByAccount` là `findMany` **không `select`**. Client chỉ
là chưa đọc. Đọc nó (schema v23) sẽ cho biết ngày tạo ví thật, nhưng thứ nó vá
là một vách **đo được là không tồn tại**, nên đây là phức tạp mua về mà không
sửa gì. Ghi lại để khỏi phải tìm lại.

⚠️ Ví `banking` do server tự ghi số dư từ SePay (`tinhLaiSoDu` cố ý bỏ qua
chúng), nên các điểm **quá khứ** của ví ấy là xấp xỉ; điểm cuối vẫn đúng vì nó
đọc thẳng `balance`. *(Từ 2026-09-18 nhóm đã bỏ liên kết ngân hàng nên client
không tạo được ví loại ấy nữa; đoạn này chỉ còn áp cho hàng cũ kéo về từ một
tài khoản từng liên kết.)*

#### Ba mốc để tin cả đường

Điểm cuối phải bằng **đúng** số dư Trang chủ. Nghiệm thu máy ảo 2026-09-17: ba
chỗ cùng nói `13.590.000 đ` — thẻ *Tổng số dư ví* ở Trang chủ, ô *Số dư cuối
kỳ* của khối Dòng tiền, và con số lớn của khối này. Vì thế con số lớn là
`ds.last.tong`, **không** phải một phép cộng ví riêng: cộng lại ở tầng vẽ là
bản chép tay thứ **sáu** của `viTinhVaoTong` (G42 là bản thứ năm).

#### Không nguồn stream mới

`watchKy` vốn đã phát **toàn bộ** giao dịch của tài khoản và **toàn bộ** ví (kể
cả hàng đã xoá mềm — bảng tra tên cần chúng), nên khối này chỉ là một lời gọi
nữa trên đúng hai danh sách ấy — cùng lý lẽ với mục 3.28. Repository truyền
`txs` **nguyên vẹn**, không phải `trongKy`; bản sai dùng `trongKy` làm hai ca
test đỏ.

#### Trục: mượn `daiTrucDuBao`, và siết nó lại

Bẫy **4.21** đã chốt "đường số dư thì co theo dữ liệu, bước phải tròn", nên
khối này **mượn nguyên** hàm ấy chứ không đẻ luật trục thứ hai. Nghiệm thu máy
ảo lộ ra rằng hàm ấy **quá rộng** với dải bắt đầu từ 0: nó đặt
`buoc = _buocTron(dải/2)` — trừ hao trọn một bước cho phép làm tròn sàn, kể cả
khi sàn đã đúng bội — nên dải `13.590.000` nhận trần **30.000.000** và đường bị
ép xuống 45% dưới của khung.

Sửa tại **chính định nghĩa**: bước khởi điểm là `dải/3` (ba khoảng giữa bốn
nhãn), rồi nới **chỉ khi** `san + 3×buoc` thật sự chưa phủ đỉnh. Dải hẹp quanh
một số lớn — đúng ca khối Dự báo sinh ra hàm này — cho **cùng một bước** ở cả
hai công thức, nên đây là siết lại chứ không đổi hành vi khối ấy. Đo lại trên
máy ảo: trục thành `0 / 5M / 10M / 15M`.

⚠️ **Không test nào đỏ khi lỗi ấy còn đó** — mọi tính chất (bước tròn, sàn ≤
đáy, trần ≥ đỉnh, bốn nhãn khác nhau) đều vẫn đúng, chỉ mắt mới thấy. Ca test
mới đòi thêm `trần < 1,5 × đỉnh`.

#### Khối ẩn khi kỳ rỗng

Khác khối *Dự báo*, khối này nằm trong nhánh thường nên kỳ không có giao dịch
nào thì nó ẩn cùng mọi khối khác. Kiểm trên máy ảo bằng một kỳ tuỳ chọn hai
ngày: trang hiện *"Chưa có giao dịch nào trong 16/09 – 17/09"* và chỉ còn khối
Dự báo — đúng thiết kế sẵn có, không phải lỗi.

Hệ quả khi nghiệm thu: trên một tài khoản mới có **15 ngày** lịch sử, dòng thay
đổi **không thể** xuất hiện ở bất kỳ đơn vị nào (sáu kỳ luôn trùm qua quãng
chưa có dữ liệu), còn kỳ đủ ngắn để tránh quãng ấy thì lại rỗng giao dịch.
Nhánh ấy do widget test canh, và bản sai có chủ ý đã chứng minh nó bắt thật.

#### Chốt hai lớp

`if (thongKe.taiSan.isNotEmpty)` ở `_NoiDung` và `if (ds.isEmpty)` đầu `build`.
Đo bằng bản sai: phá lớp nào một mình thì ca vẫn xanh, phá **cả hai** mới đỏ.
⚠️ Lần đo đầu **bản sai vá nhầm widget khác** — `if (ds.isEmpty) return ...`
xuất hiện ở nhiều khối, và bản sai rơi vào khối *Dòng tiền tự do*, nên ca xanh
và trông y như test không canh gì. Neo bản sai bằng **cả dòng chú thích** mới
đúng chỗ.

#### Màn Stitch

**`b0a3344924d246f9b6322fb75a3309e4`** *"Thống kê - Tổng tài sản 6 tháng gần
đây"*. ⚠️ Lượt gọi **trả về `timeout`** và màn vẫn được tạo — **lần thứ ba** xác
nhận *timeout không phải thất bại, đừng gọi lại*. ⚠️ Vẫn mang
`deviceType: DESKTOP` dù lượt gọi truyền `MOBILE`.

**Màu thì khớp** — khác hai lần trước: prompt nói rõ đường dùng màu trung tính
`#1a1a19` và màu xanh lá chỉ dành cho con số thay đổi, nên không lặp lại chỗ
lệch màu của mục 3.27 và 3.29.

⚠️ **Nhưng bố cục thì lệch một chỗ, và nó là lỗi của chính prompt:** màn vẽ
**đồng thời** dòng thay đổi *"+2.350.000 đ trong 6 tháng"* **và** câu cảnh báo
*"Trước 02/09/2026 chưa có giao dịch nào…"*. Bản thi công **không bao giờ**
dựng ra trạng thái ấy: hai thứ loại trừ nhau theo đúng thiết kế, vì
`thayDoiTaiSan` trả `null` chính xác khi `mocThieuDuLieu` có giá trị. Màn còn
tự mâu thuẫn theo một cách thứ hai đi kèm: đường của nó lên đều suốt sáu tháng
(11,24M → 13,59M), tức có đủ lịch sử — trong khi câu ngay dưới nói trước
02/09 không có giao dịch nào.

Prompt liệt kê cả hai phần tử mà **không nói chúng loại trừ nhau**, nên Stitch
vẽ cả hai; không phải công cụ hiểu sai. Bài học cho lần sau: *mô tả một khối
cho Stitch thì phải nói rõ phần tử nào không thể cùng xuất hiện* — nếu không,
màn thiết kế sẽ mô tả một trạng thái không tồn tại và người đọc nó sau này sẽ
tưởng bản thi công thiếu mất một dòng.

⚠️ Và một bài học về **cách nghiệm thu**: lượt kiểm đầu chỉ đọc **văn bản HTML**
cùng bảng màu rồi kết luận "khớp bản thi công". Chỗ lệch này chỉ lộ ra khi
**xem ảnh render** — trong dòng chữ thì hai câu ấy chỉ là hai chuỗi nằm cạnh
nhau, không có gì nói rằng chúng đang hiện cùng lúc.

#### Nghiệm thu

`flutter test` **2743/2743** · `flutter analyze` **25 issue, 0 error** — đếm
bằng máy 2026-09-17. Analytics có **21** tệp / **548** test (đếm bằng chính
`flutter test test/features/analytics`). ⚠️ Mốc **2742** đo cùng ngày là ảnh
chụp **trước** lượt siết `daiTrucDuBao` — đừng dùng. ⚠️ Và cả hai con số ở đoạn
này là **ảnh chụp trước mục 3.31**, thứ cũng mang ngày 2026-09-17: mốc đang
đúng là **2810** và **564**, ở khối Nghiệm thu của mục ấy. ⚠️ Và **cả câu vừa
rồi cũng đã là ảnh chụp**: G44 đóng ngày 2026-09-18 đưa nó lên 2815/569, rồi
mục 3.33 cùng ngày lên nữa. **Đừng chép con số từ đây** — mốc đang đúng luôn
nằm ở khối *Nghiệm thu* của **mục 3 cuối cùng** — nhưng ⚠️ **chỉ khi lượt gần
nhất thuộc mảng Phân tích**. Từ 2026-09-18 điều ấy thôi đúng: G45 và G46 cùng
ngày đụng ví, giao dịch, hoá đơn, mục tiêu và ngân sách, nên mốc toàn cục
(**2854**) nằm ở mục 14 `PROJECT_CONTEXT.md` chứ không ở đây. Cách chắc chắn
nhất vẫn là
`flutter test` rồi đếm lại.

Máy ảo `emulator-5554`, tài khoản thật: ba chỗ cùng nói `13.590.000 đ`; câu
cảnh báo đúng ngày `02/09/2026`; đổi sang đơn vị **Quý** thì tiêu đề thành
*"Tổng tài sản 6 quý gần đây"* và sáu nhãn `Q2/25 … Q3/26` đôi một khác nhau,
không nhãn nào chồng; trục sau khi siết là `0 / 5M / 10M / 15M`.

**Bản sai có chủ ý: chín lượt** (11 lần chạy bộ test) — bốn ở tầng thuần (kẹp
mốc, lọc `viTinhVaoTong`, khoản chuyển thiếu ví đích, guard `null` của
`thayDoiTaiSan`), một ở chỗ nối repository (dùng `trongKy` thay `txs` → **2**
ca đỏ), ba ở widget (dòng thay đổi, câu cảnh báo, và chốt hai lớp — riêng chốt
hai lớp là **3** lần chạy), và một ở `daiTrucDuBao` (trả về luật `dải/2` → **2**
ca đỏ).

⚠️ Con số này **đếm lại ngày 2026-09-17 trong lượt soát tài liệu**; commit
`0622b8c` và bản đầu của mục này ghi **tám** vì quên chính lượt `daiTrucDuBao`.
Đúng bài học đã ghi nhiều lần: *đếm bằng máy, kể cả con số vừa viết.*

**Không đổi schema** (vẫn v22), **không thêm trường đồng bộ**, không nguồn
stream mới.


### 3.31 Ba khối cuối vào tệp xuất — và một lỗi glyph có từ 2026-09-09

**Xong 2026-09-17.** Đường **bounded** (brainstorming → thiết kế trong chat →
duyệt → thi công), **không có tệp spec** — đừng đi tìm.

Màn Xem trước có mười khối; tệp thiếu đúng **ba** trong số đó — **so với kỳ
trước**, **số liệu nhanh** và **top 5 khoản chi**. (Số khối *còn lại* của hai
định dạng không bằng nhau: CSV không có biểu đồ, PDF có.) Cả ba đã nằm sẵn
trong `BaoCao` —
`dungBaoCao` vốn dựng đủ từ lát 2c‑1b — nên việc chỉ là `xuat_tep.dart` chịu
đọc chúng. **Không đụng repository, không đổi schema, không thêm trường đồng
bộ.** Thứ tự khối trong tệp chép đúng màn Xem trước; CSV khuyết biểu đồ nên
"Số liệu nhanh" của nó đứng ngay sau "Tổng quan".

**Hai định dạng cố ý khác nhau, đúng chỗ mục 3.18 đã đặt ra.** CSV nhận **số
thô của kỳ trước** — ba dòng thu/chi/còn lại — cộng hai ô phần trăm, vì người
mở bảng tính phải tự kiểm lại được con số. PDF chỉ mang một dòng phần trăm dưới
hai ô tổng, giống hệt màn Xem trước.

⚠️ **`_tiLe` và `_phanTramCsv` KHÔNG thay nhau được.** `phanTramSoVoi` trả sẵn
thang 0–100 còn `_tiLe` nhận `[0,1]` rồi nhân 100 — dùng lại `_tiLe` ở đây là
in `1250.0` cho một mức tăng 12,5%, và **không exception nào báo**.

⚠️ **Ô phần trăm để RỖNG, không phải `—`.** Kỳ trước bằng 0 thì `phanTramSoVoi`
trả `null`; đây là cột **số** mà Excel sắp cộng, nên nhét một chuỗi chữ vào là
hỏng cột, còn ghi `0` là bịa ra "không đổi". PDF thì ngược lại — nó là tài liệu
để đọc nên `—` mới đúng.

**Số liệu nhanh trong tệp chỉ có BA chỉ số, không phải bốn.** Ô "Số giao dịch"
của màn Xem trước đã nằm ở khối "Tổng quan" của tệp, và hai bản của cùng một
con số là hai thứ phải khớp nhau mãi mãi.

**Hai khối mới bỏ hẳn khi không có gì để nói** — số liệu nhanh khi kỳ rỗng, top
5 khi kỳ không có khoản chi nào. ⚠️ Hai ca test cho chuyện ấy **xanh ngay từ
đầu** (khối chưa tồn tại thì tất nhiên là vắng mặt), nên chúng chỉ đáng tin sau
khi bản sai có chủ ý làm chúng đỏ — làm rồi, cả hai đỏ đúng chỗ.

#### ⚠️ Roboto nhúng không có mũi tên — lỗi có từ chính lát 2c‑2

Bản thiết kế đầu của mục này định dùng `▲`/`▼` cho dòng phần trăm của PDF, y
như màn Xem trước. **Ca test quét glyph lật nó**: Roboto nhúng không có khối
Hình học, nên tệp sẽ in `" 12,5%"` **cụt đầu** — mũi tên biến mất, tệp vẫn mở
được. Nay là `+12,5%` / `-3,0%`, còn **màu** vẫn nói tốt/xấu như cũ.

Cùng lượt ấy lộ ra một lỗi **đã có từ 2026-09-09**: dòng dòng tiền của PDF dùng
`→`, nên **mọi tệp PDF app từng xuất** đều mất mũi tên ở đó mà không ai hay.
Nay là `»`.

Gói `pdf` **bỏ ký tự thiếu glyph đi** và chỉ in một dòng
`Unable to find a font to draw …` ra console — cùng họ với lỗi "rơi về
Helvetica" của mục 3.17, chỉ khác là bản Roboto **đúng** vẫn dính.

**Phép canh bằng máy:** `xuat_tep_test.dart` quét **chuỗi hằng của chính
`xuat_tep.dart`** (bỏ dòng chú thích, vì chú thích mang `⚠️` và những ký tự chỉ
con người đọc) rồi đòi mọi ký tự ngoài ASCII phải có trong
`charToGlyphIndexMap` của **cả hai** tệp Roboto. `TtfParser` là API công khai
của gói `pdf` nên phép kiểm chạy ở tầng thuần, không cần dựng tài liệu. Giới
hạn **cố ý**: chữ của *người dùng* — tên ví, ghi chú — thì không chặn trước
được.

Đo bằng máy 2026-09-17: Roboto **có** `»` `›` `•` `±` `−` `·` `—`; **không có**
`→` `↑` `↓` `▲` `▼` `▴` `▾`.

⚠️ **Ca quét glyph KHÔNG phải một "test quét `lib/`"** — nó chỉ đọc **một** tệp,
còn những ca kia quét toàn bộ `lib/`; đừng cộng nhầm.

> Câu này nguyên văn là *"Con số ấy vẫn là **bảy**"* và đúng tới 2026-09-17.
> Nay là **tám**: `o_nhap_tien_co_tran_test.dart` thêm ngày 2026-09-18 cùng
> **G46**, canh mọi ô nhập tiền đều có trần số chữ số. Ca quét glyph vẫn không
> nằm trong số ấy.

#### Nghiệm thu

`flutter test` **2810/2810** · `flutter analyze` **25 issue, 0 error** — đếm
bằng máy 2026-09-17. **16** ca mới, tất cả ở `xuat_tep_test.dart`, **không**
thêm tệp; analytics có **21** tệp / **564** test (đếm bằng chính
`flutter test test/features/analytics`).

**Bản sai có chủ ý: tám lượt, tất cả bị bắt** — bỏ chốt `!bc.rong`, bỏ chốt
`topChi.isNotEmpty`, dùng lại `_tiLe`, bỏ dấu âm ở cột tiền của top 5, ghi `—`
thay ô rỗng, lặp lại dòng "Số giao dịch", trả `→` về dòng dòng tiền, và đổi
`+`/`-` thành `▲`/`▼`. Hai lượt đầu chính là hai ca **xanh ngay từ đầu**.

**Máy ảo** (2026-09-17, tài khoản 10, dữ liệu thật): xuất CSV và PDF
tháng 9 rồi kéo tệp về đọc — ba khối mới đúng vị trí, ô phần trăm rỗng khi kỳ
trước bằng 0, `»` hiện ra trong PDF. Xuất thêm một khoảng **rỗng** có kỳ trước
**không** rỗng (08–17/09) để bắt cả hai nhánh: PDF ca ấy in `-100,0%` và bỏ hẳn
hai khối mới. ⚠️ **Phần bố cục PDF chỉ kiểm được qua thứ tự văn bản**, không
qua ảnh — máy này không có poppler/ghostscript để dựng ảnh raster.

⚠️ **Một chỗ lệch có sẵn, KHÔNG phải do mục này**: kỳ rỗng thì màn Xem trước
giấu mọi khối và chỉ hiện thẻ "không có giao dịch", còn tệp vẫn in khối **Ngân
sách kỳ này** (ngân sách tồn tại độc lập với giao dịch). Chưa sửa, và không rõ
bên nào mới đúng.

> ✅ **Đã sửa 2026-09-18 — mục 3.32 ngay dưới.** Và câu "màn Xem trước giấu
> **mọi** khối" ở đoạn trên là **sai**: đo lại khi sửa thì màn vẫn hiện đầu báo
> cáo, khối Dòng tiền và ba thẻ tổng. Giữ nguyên câu cũ vì nó ghi lại điều
> lượt nghiệm thu 3.31 *tưởng* là đúng.

**Không đổi schema** (vẫn v23), **không thêm trường đồng bộ**, không nguồn
stream mới.

---

### 3.32 Kỳ rỗng thì tệp xuất thôi in khối Ngân sách — G44 đóng

**Lỗi**, không phải tính năng: lượt nghiệm thu máy ảo của mục 3.31 tìm ra tệp
PDF của một khoảng **rỗng** vẫn in bảng *Ngân sách kỳ này* với dòng
`Giáo dục 45.000đ / 50.000đ / 5.000đ`, trong khi màn Xem trước giấu nó. Khi ấy
ghi lại thành **G44** và hoãn, vì chọn sai chiều thì không ai phát hiện được.

**Chiều đã chốt (người dùng, 2026-09-18): tệp theo màn.** Kỳ rỗng thì tệp bỏ
hẳn khối ấy. Lý lẽ: "đã chi" của một ngân sách đếm theo kỳ của **chính nó**, nên
bảng ấy trong tệp báo cáo của một kỳ rỗng nói về một khoảng thời gian khác —
và người cầm tờ PDF không có chỗ hỏi lại, khác người đang đứng trước màn hình.

**Luật có một chỗ.** Vị từ thuần `inKhoiTheoKy(BaoCao)` ở `domain/bao_cao_xuat.dart`,
cạnh `rong`; **ba** chỗ cùng đọc: `csvBaoCao`, `pdfBaoCao`, và nhánh rỗng của
`report_preview_page.dart`. Cùng khuôn `khoanVaoThongKe` / `viTinhVaoTong` /
`billPayStatus` — mỗi hàm ấy sinh ra để dập một luật từng bị chép tay nhiều bản.

Khối *Số liệu nhanh* vốn đã gác bằng `!bc.rong` kèm chú thích *"cùng luật với
màn Xem trước"*; nay chú thích ấy **thành mã**, nên hai khối không thể trôi xa
nhau nữa.

**Ba chỗ dễ vấp:**

1. ⚠️ **Ngân sách là khối duy nhất cần vế ấy.** Mọi khối khác tự rỗng theo một
   kỳ rỗng nên `isNotEmpty` của chúng đã trùng khớp với màn. Vế `inKhoiTheoKy`
   đứng **cạnh** `isNotEmpty` chứ không thay nó — thay là đổi hành vi của ca
   thường, thứ mục này cố ý không đụng.
2. ⚠️ **Ở nhánh PDF chặn tại NGUỒN HÀNG, không bọc quanh `_pdfBang`.** Hàm ấy tự
   bỏ cả bảng khi danh sách hàng rỗng, nên một `if` trong collection literal là
   đủ; bọc ngoài là sinh nhánh thứ hai phải giữ đồng bộ với nhánh CSV.
3. ⚠️ **Đính chính tiêu đề cũ của G44.** Màn Xem trước **không** giấu "mọi
   khối" khi kỳ rỗng — đầu báo cáo, khối **Dòng tiền** và **ba thẻ tổng** vẫn
   hiện, và tệp cũng in đúng ba thứ ấy. Hai bên lệch **đúng một khối**. Chỗ này
   quyết định chiều sửa: nếu màn thật sự giấu mọi thứ thì "tệp theo màn" sẽ cắt
   cả số dư đầu/cuối kỳ, một thông tin có nghĩa ngay cả với kỳ rỗng.

#### Nghiệm thu

`flutter test` **2815/2815** · `flutter analyze` **25 issue, 0 error** — đếm
bằng máy 2026-09-18. **Năm** ca mới ở **hai** tệp (`bao_cao_xuat_test.dart` hai
ca cho vị từ, `xuat_tep_test.dart` hai ca CSV và một ca PDF), **không** thêm
tệp. **Không đổi schema** (vẫn v23), **không thêm trường đồng bộ**, không đụng
repository.

⚠️ **Ca cho nhánh PDF phải so ĐỘ DÀI tệp, không tìm chuỗi.** PDF nén luồng nội
dung nên `String.fromCharCodes(bytes).contains('NGÂN SÁCH KỲ NÀY')` không bao
giờ khớp — một ca viết như thế sẽ **xanh trên cả bản sai**, đúng cái bẫy mà ca
quét glyph né được nhờ chỉ đọc bảng font (thứ **không** nén). Phép đo dùng được:
hai tệp của cùng một kỳ rỗng, một bản có ngân sách một bản không, độ dài phải
bằng nhau.

**Bản sai có chủ ý: một lượt, bị bắt.** Bỏ vế `inKhoiTheoKy` ở nguồn hàng của
`pdfBaoCao` → ca PDF đỏ với `Expected: <10403> / Actual: <13250>`, chênh **2 847
byte**. Ca CSV thì đã đỏ sẵn trước khi sửa, với đúng dòng
`Giáo dục;45000;50000;5000` mà máy ảo từng thấy trong PDF.

---

### 3.33 Trang Xuất báo cáo dùng chung bộ chọn kỳ với trang Phân tích

**Không phải tính năng mới, mà là gộp hai bộ luật làm một.** Từ P1 (mục 3.20)
app có `Ky` với năm đơn vị, nhưng trang Xuất báo cáo vẫn giữ bộ chọn **riêng**
của nó: `enum PhamViThoiGian` bốn giá trị cứng — *Tháng này · Tháng trước · Quý
này · Tùy chỉnh* — lấy đúng bốn nút của màn Stitch cũ.

Cái giá không phải một lỗi mà là **thứ không làm được**: trang ấy không xuất nổi
báo cáo theo **tuần** hay theo **năm**, dù `tongThuChi` và `getExpenses` bên
dưới vốn nhận khoảng bất kỳ. Nay nút chọn kỳ mở thẳng `moChonPhamVi` — cùng
bottom sheet của trang Phân tích — và `PhamViThoiGian` cùng `khoangCuaPhamVi`
**bỏ hẳn**.

#### Vì sao chỉ đến đây, không xa hơn

Người dùng chốt sau một lượt khảo sát bảy app thị trường (2026-09-18): **không
đưa khối nào của trang Phân tích vào tệp xuất.** Kết quả khảo sát:

| | |
|---|---|
| Xuất CSV thuần dữ liệu | **6/7** app — YNAB, Monarch, Copilot, Rocket Money, Money Lover, PocketSmith |
| Xuất cả màn phân tích ra một tệp | **0/7**. Không ngoại lệ |
| Có PDF native | Chỉ MISA, và không tài liệu công khai nào nói tệp ấy chứa gì |

Bốn chỗ gần nhất đều **cố ý nhỏ hơn màn hình**: PocketSmith ghi thẳng là họ
không làm nút in trong app (và riêng trang **Calendar** của họ được ghi chú *in
ra không đọc được* — đúng khối Lịch chi tiêu của mục 3.29); Monarch tải **PNG
một biểu đồ** một lần; Copilot chia sẻ **từng slide**. Luật chung: khi app muốn
cho mang hình đi, họ cho **một** biểu đồ, không gói cả trang — vì màn hình là
nơi *tương tác*, còn tệp là nơi *chốt số*.

⚠️ Cộng một lý do kỹ thuật: gói `pdf` **không dùng lại được `fl_chart`**, nên
mỗi biểu đồ đưa vào PDF là một **bản thi công thứ hai** của cùng phép vẽ, phải
giữ đồng bộ vĩnh viễn với bản trên màn hình.

#### Bốn chỗ dễ vấp

1. ⚠️ **`Ky.tuyChon` không tự cộng một ngày vào biên phải, `khoangCuaPhamVi`
   thì có.** `denNgay` của route là ngày **cuối cùng được tính vào**, nên thiếu
   vế `+ 1` là báo cáo hụt đúng ngày ấy — không exception, không dòng log. Đường
   vào của thông báo **Tổng kết tuần** đi qua đúng chỗ này; ca test canh nó nằm
   ở `export_report_page_test.dart` chứ không còn ở `bao_cao_xuat_test.dart`.
2. ⚠️ **Nhãn nút phải đi qua `nhanRong`, không phải `nhanOChon`** — xem mục con
   ngay dưới. Đây là lỗi **chỉ máy ảo thấy**.
3. **Mất khả năng xuất kỳ chứa ngày tương lai.** Bộ chọn cũ cho tới cuối năm
   sau; sheet dùng chung chặn ở **hôm nay** (luật của G43). Chấp nhận có chủ ý
   để hai trang nói cùng một luật. Giao dịch ghi ngày tương lai vẫn vào báo cáo
   bình thường khi kỳ đang xem chứa chúng.
4. **"Tháng trước" và "Quý này" không mất đi** dù enum bỏ: bộ chọn liệt kê 12
   tháng và 8 quý gần nhất (`soKyTrongBoChon`).

#### `nhanRong` — một hàm nữa, và vì sao không sửa `nhanOChon`

Nghiệm thu máy ảo bắt được: sau khi chạm dòng *"Tuần 37 (07/09 – 13/09)"* trong
bộ chọn, **nút hiện "Tuần 37" trần** — mất khoảng ngày, tức không cho biết đó là
khoảng nào, ngay trước lúc người dùng xuất một tờ báo cáo theo đúng khoảng ấy.

Gốc rễ: `nhanOChon` rơi về `nhanNgan` khi kỳ **không chứa hôm nay**, vì nó sinh
ra cho **ô header hẹp** của trang Phân tích — chỗ đã tràn 53px một lần.

Hai chỗ có bề ngang khác hẳn nhau và **cả hai lựa chọn đều đúng ở chỗ của nó**,
nên câu trả lời là một hàm **thứ hai** chứ không phải sửa hàm cũ:
`nhanRong(ky, moc)` = `ky.chua(moc) ? nhanOChon(...) : ky.nhan`. Nó **thay một
bản chép tay**: `ChonPhamViSheet._dong` vốn tự viết lại đúng biểu thức ấy, nên
nay dòng vừa chạm và nút sau đó không thể trôi xa nhau.

⚠️ Bộ test mù trước lỗi này vì **cả hai chuỗi đều hợp lý**. Và ca tái hiện phải
dùng **tuần 36**, không phải 37: đồng hồ của tệp test đứng ở 08/09/2026 nên tuần
37 chính là tuần hiện tại, tức nhánh "… này" vốn đã đúng từ trước.

#### Nghiệm thu

`flutter test` **2817/2817** · `flutter analyze` **25 issue, 0 error** — đếm
bằng máy 2026-09-18. Analytics có **21** tệp / **571** test. Bảy ca của
`khoangCuaPhamVi` bỏ theo hàm; **chín** ca mới (4 widget cho bộ chọn, 1 widget
cho nhãn nút, 1 widget cho `nhanRong`, 3 ca thuần cho `nhanRong`). **Không đổi
schema** (vẫn v23), **không thêm trường đồng bộ**, không đụng repository.

**Máy ảo** `emulator-5554`, tài khoản thật: nút hiện *"Tháng này (T9 2026)"*;
mở sheet thấy đủ năm chip; chọn Tuần 37 thì nút đổi thành *"Tuần 37 (07/09 –
13/09)"* và màn Xem trước ghi kỳ **07/09/2026 – 13/09/2026** — ngày cuối nằm
trong báo cáo, tức bẫy `+ 1` không tái diễn.

**Màn Stitch `4a12791ff0eb49abb627be187eb6ba85`** *"Xuất báo cáo - FlowMoney"*
(2026-09-18, lượt gọi **không** timeout). Nó khớp bản thi công ở mọi điểm —
nút full-width nền `#F4F4F0` bo 12px, icon lịch trái, `expand_more` phải — và
chính nó chỉ ra nhãn phải là *"Tháng này (T9 2026)"* chứ không *"T9 2026"*,
tức khớp header trang Phân tích.

⚠️ **`bienThang` nay 0 chỗ gọi trong `lib`** (đếm bằng máy): chỗ gọi cuối cùng
là `khoangCuaPhamVi`. `Ky.thang` làm đúng việc ấy. Giữ lại vì ngoài phạm vi
lượt này và vẫn có bốn ca test riêng — ứng viên dọn cho lần sau.


## 4. Bẫy

**4.1 Tài khoản.** `AnalyticsPage` phải `context.watch<AuthBloc>()` + `ValueKey(idaccount)`
trên `BlocProvider` — cùng G17: `currentAccountIdOrNull` dùng `context.read`
(không đăng ký), và `BlocProvider.create` chỉ chạy một lần. Phiên tới muộn thì
cubit nhận `null` rồi không bao giờ hỏi lại. Cubit nhận `null` thì **báo lỗi,
không đoán** (quy tắc 2 `CLAUDE.md`).

**4.2 Đổi tháng phải huỷ đăng ký cũ.** Không huỷ là hai stream cùng phát và cái
tới sau thắng — không có gì bảo đảm đó là tháng người dùng vừa chọn. Bản sai có
chủ ý bỏ `_sub?.cancel()` đã làm đúng test ấy đỏ.

**4.3 Dải chú giải và tên danh mục phải co được.** Bản Stitch chép sang đặt tên
trong một `Row` không giới hạn bề rộng — tên dài tràn **521px** qua cột số tiền.
Test 411dp bắt được; nay `Expanded` + ellipsis.

**4.3b Đầu trang thiếu vài chục px ở 411dp thật — flex không cứu được.**
Bản đầu đặt tiêu đề `Expanded` và ô tháng `Flexible` cùng hệ số 1: ô tháng bị
cắt thành *"Tháng này (…"* trên máy thật trong khi test 411dp xanh (font khác —
xem 4.4). Đổi tỉ lệ 1:2 thì **cắt cả hai** ("Thống…" và "T9 202…"): tiêu đề
24px + `IconButton` 48px + nhãn tháng đầy đủ đơn giản là không đủ chỗ, và flex
chỉ quyết định *ai* bị cắt. Cách đúng là **bớt chỗ chiếm cố định**: nút xuất
gọn 40px (`visualDensity.compact`, `padding: zero`), nhãn tháng 13px với đệm
10, rồi mới chia 2:3 làm lưới an toàn. Hai lần chụp máy thật cho hai lần sửa —
test không thay được bước này.

**4.4 Font của bộ test rộng gấp đôi ngoài đời.** `flutter test` vẽ bằng font
"Ahem": mỗi ký tự là một ô vuông rộng bằng cỡ chữ. *"Tháng này (T9 2026)"* 14px
thành 266px, *"Chi tiêu theo hạng mục"* 18px thành 396px (tiêu đề ấy nay là
*"Cơ cấu dòng tiền"*, ngắn hơn — nhưng phép đo vẫn minh hoạ đúng vấn đề). Hai chỗ ấy tràn 30px
và 71px **chỉ trong test** — nhưng vẫn phải sửa cho co được, vì đó là thứ duy
nhất bảo đảm tên tiếng Việt dài hay máy đặt cỡ chữ lớn không tràn thật. Hệ quả
cho người viết test: assertion về chữ vẫn đúng khi Text bị ellipsis (`find.text`
so `data`, không so thứ vẽ ra).

**4.5 `pumpAndSettle` treo với vòng quay.** Sau khi chọn tháng, state `Loading`
vẽ `CircularProgressIndicator` quay mãi, nên `pumpAndSettle` không bao giờ
"lắng" và test treo tới timeout. Dùng `pump(Duration)`.

**4.6 `ListView` trong bottom sheet không dựng hàng ngoài khung nhìn.**
`find.text('Danh mục 6')` trả rỗng dù dữ liệu có — phải `scrollUntilVisible`.
Tìm thẳng là xanh oan khi hàng ấy thật sự không tồn tại.

**4.7 FAB của `MainShell` đè lên dòng cuối.** Trang cuộn phải đệm đáy ~96
chứ không 8 — chú giải "Khác" và dòng danh mục cuối nằm dưới nút cộng trên máy
thật. Không test nào thấy vì FAB không thuộc trang.

**4.8 Biểu tượng `menu` ở đầu trang không làm gì.** Stitch vẽ nó; drawer thuộc
`HomePage`, tab này nằm trong `MainShell` không có drawer. Giữ để khớp thiết
kế, ghi lại để không ai tưởng là lỗi mới.

**4.9 Tooltip của `fl_chart` tràn khỏi màn hình nếu không chặn.** Mặc định thư
viện đặt hộp tooltip ngay cạnh điểm chạm và **để nó lòi ra ngoài**. Điểm cuối
của chuỗi là tháng đang xem — nằm sát mép phải — nên đó lại đúng là điểm người
dùng chạm nhiều nhất, và hộp bị cắt mất chữ. Phải bật **`fitInsideHorizontally`
và `fitInsideVertically`**.

Thấy được nhờ chụp máy ảo 411dp rồi **nhìn ảnh**; đây là loại lỗi mà bộ test
không thể bắt, vì tooltip do thư viện vẽ vào canvas chứ không phải widget. Đó
là cái giá đã biết trước của quyết định 3.11 — biểu đồ phải kiểm bằng mắt trên
máy thật, mỗi lần nâng phiên bản `fl_chart` cũng vậy.

**4.10 Tháng rỗng vẫn thấy biểu đồ — trừ khi tháng đang xem rỗng.** Trang giữ
nguyên hành vi 3.9: `tk.rong` thì cả thân trang thay bằng lời nhắn rỗng, nên
mở một tháng chưa ghi gì sẽ **không** thấy xu hướng năm tháng trước đó. Biết mà
chấp nhận, không phải bỏ sót; đổi thì phải bàn lại 3.9 chứ đừng sửa lặng lẽ.

**4.11 Theme của app bắt mọi `ElevatedButton` rộng vô hạn — nút trần trong
`Row` làm TRẮNG cả trang.** `AppTheme.lightTheme` đặt
`minimumSize: Size(double.infinity, 52)`. Thanh dưới của màn Xem trước có
`Row(Text, ElevatedButton)`; nút không bọc `Expanded` đòi bề ngang vô hạn, và
Flutter **bỏ layout cả khung hình**: trang chỉ còn AppBar trên nền trơn, không
màn đỏ, **không một dòng nào trong `adb logcat`** — phải `flutter run` mới thấy
`RenderBox was not laid out`.

Bộ test không bắt được vì nó dựng bằng `MaterialApp` **trần**, không có theme
của app. Cách sửa đúng là **dựng widget test bằng `AppTheme.lightTheme`**; làm
vậy xong thì test đỏ ngay đúng lỗi ấy, rồi mới bọc `Expanded`. Bất kỳ trang mới
nào cũng nên theo: `MaterialApp(theme: AppTheme.lightTheme, ...)` trong test,
nếu không mọi ràng buộc do theme sinh ra đều vô hình.

**4.12 Trang báo cáo dài hơn một màn hình — `find.text` không còn đủ.**
`ListView` **không dựng** hàng ngoài khung nhìn, nên mọi khối từ "Thu chi trong
kỳ" trở xuống trả rỗng nếu test không cuộn tới (cùng bẫy 4.6 của bottom sheet).
Và vì nội dung nay phong phú, **một con số xuất hiện ở nhiều khối**: cùng một
ngày nằm ở "Số liệu nhanh", "Top 5 khoản chi" và tiêu đề nhóm ngày; cùng một số
tiền nằm ở bảng danh mục lẫn top 5. Test phải `scrollUntilVisible` rồi tìm
**trong phạm vi** một khối (`find.descendant` với `Key('khoiGiaoDich')`), nếu
không hoặc là xanh oan, hoặc là đỏ vì "tìm được hai".

**4.13 Số 0 vẫn mang dấu.** `CurrencyFormatter.formatIncome(0)` trả `"+0 đ"`
(ký hiệu đổi từ `₫` sang `đ` ngày 2026-09-09 khi gộp định dạng tiền về một chỗ).
Một ví không phát sinh khoản thu nào hiện ra như lỗi định dạng — thấy trên máy
ảo. Bảng "Phân bổ theo ví" bỏ dấu khi số bằng 0.

**4.14 Khoản nạp mục tiêu kiểu CŨ được đếm là thu và chi thật.** Trên tài khoản
thử có một cặp hàng `Type = 'Transaction'` ±500.000 mang ghi chú *"Tích lũy mục
tiêu"* — cách ghi trước khi mục tiêu chuyển sang `transfer`. Báo cáo (và trang
Phân tích) đếm chúng là thu/chi thật, nên "Khoản chi lớn nhất" của tháng 9 là
một lần nạp mục tiêu. **Hai trang khớp nhau**, nên đây không phải lỗi của báo
cáo; sửa nó là đi diễn giải lại lịch sử — việc mà mục 3.16 và `GOAL_FEATURE.md`
đều khuyên đừng làm.

**4.15 Test "có dấu âm" suýt không canh gì cả.** Phép kiểm đầu tiên chỉ tìm
`';-50000'` trong cả tệp — nhưng con số ấy cũng nằm ở dòng "Tổng chi" và ở bảng
danh mục, nên **bản sai có chủ ý (bỏ dấu ở dòng giao dịch) đi lọt**. Phải cho
danh mục ấy *hai* khoản để tổng khác số của từng dòng, rồi khẳng định trên
**trọn dòng** `Ăn trưa;Ăn uống;Tiền mặt;-50000`. Bài học chung: khi một con số
xuất hiện ở nhiều khối, `contains` trên cả tệp là phép canh rỗng.

**4.16 `adb shell cat` làm hỏng tệp nhị phân.** Kéo tệp PDF ra bằng
`adb shell run-as … cat` trên Windows thì bị chèn `
`, và pypdf báo *"Cannot
find Root object"* — trông y như lỗi sinh tệp. Dùng **`adb exec-out`**.

**4.17 `fl_chart` mặc định KHÔNG cắt vùng vẽ.** `LineChartData.clipData` mặc
định là `FlClipData.none()`: điểm nằm ngoài `minY`/`maxY` vẫn được **vẽ**, chứ
không bị cắt — nó tràn khỏi khung, khỏi thẻ, và đè lên phần trang bên dưới.
Thấy trên máy ảo ngày 2026-09-09 ở biểu đồ tiến độ mục tiêu: một điểm âm kéo
đường xanh chạy dài qua dòng chú thích và ra ngoài thẻ. **Không exception,
không log**, và không widget test nào bắt được vì mọi thứ vẽ trong canvas của
thư viện — kể cả test đã hỏi `takeException()` vẫn xanh.

Đặt `clipData: const FlClipData.all()` cho **mọi** biểu đồ. Nó là lớp phòng thủ
thứ hai chứ không thay được việc kẹp dữ liệu ở tầng thuần: cắt hình chỉ giấu
điểm sai đi, còn tầng thuần mới quyết định điểm ấy **đáng lẽ là bao nhiêu**.

**4.18 `fl_chart` vẽ nhãn trục ở CẢ hai biên, cộng thêm các mốc theo
`interval`.** Nên một mốc rơi gần biên sẽ in **đè** lên nhãn biên. Thấy cùng
ngày ở mục tiêu "MuaDT": "08/27" và "09/27" chồng nhau thành một mớ không đọc
được. Đặt `interval` bằng `(max - min) / 3` **không** cho ra đúng bốn nhãn như
tưởng. Luật lọc nằm ở `hienNhanTruc` (`goal_progress_series.dart`) và có test
riêng — bỏ mốc cách biên dưới 12% dải, giữ nguyên hai nhãn biên.

⚠️ **Cùng cái bẫy ấy có dạng thứ hai, và `hienNhanTruc` KHÔNG cứu được** — G39,
thấy trên máy ảo 2026-09-14 ở khối "Xu hướng 6 tháng". Ở đây hai nhãn không
*gần* nhau mà ở **đúng cùng một vị trí**: mốc cuối của `interval` và biên trên.
Luật lọc giữ cả hai, vì cả hai đều là biên. Sai lầm nằm ở **chuỗi**, không ở vị
trí: `3 * (maxY / 3)` lệch `maxY` chừng `1e-14`, và khi giá trị rơi đúng ranh
giới làm tròn của `rutGon` thì hai số ấy cho ra "49.4K" và "49.5K", in đè khít
lên nhau. Cách sửa là làm cho chúng **bằng nhau**: tính `buoc` trước, rồi đặt
`maxY = buoc * 3` — đừng chia một con số rồi dùng lại chính nó làm trần. Quét
bằng máy 2026-09-14 trên dải đỉnh 1.000–300.000 (bước 500): **tám** giá trị rơi
vào bẫy, tức hiếm nhưng không hề không xảy ra. Ca `nhãn trục tung không in HAI
chuỗi khác nhau ở cùng một mốc` canh chỗ này, và nó tái hiện được **ngay trong
widget test** — đây là một trong ít lần bẫy đồ hoạ bắt được mà không cần máy
thật.

**4.19 `Flexible` không canh phải được — phải là `Expanded`.** Cột số tiền của
"Phân bổ theo ví" và "Top 5 khoản chi" **lệch nhau tới 26,5px**; người dùng bắt
được trên máy ảo 2026-09-15.

`Flexible` và `Expanded` đều mang `flex: 1` nên **chia đôi chỗ trống như nhau** —
khác biệt nằm ở chỗ `Flexible` để con giữ **bề rộng tự nhiên**, rồi
`MainAxisAlignment.start` đẩy phần thừa về **cuối hàng**. Hàng có số ngắn thừa
nhiều, hàng có số dài thừa ít, nên `alignment: Alignment.centerRight` của
`FittedBox` đang canh phải bên trong một cái hộp đang trôi.

```dart
// SAI — hộp hẹp hơn suất của nó, phần thừa rơi về cuối hàng
Row(children: [Expanded(child: ten), Flexible(child: FittedBox(…))])

// ĐÚNG — con chiếm trọn suất, centerRight mới có mốc. Cột trái KHÔNG mất chỗ:
// tỉ lệ chia vẫn 1:1, chỉ khác ai giữ phần thừa.
Row(children: [Expanded(child: ten), Expanded(child: FittedBox(…))])
```

⚠️ Lỗi này **không ném exception, không in log, và không phải lỗi tràn** — không
có sọc vàng, nên mẹo đếm pixel vàng ở `CLAUDE.md` cũng không thấy. Thứ bắt được
nó bằng máy là so `tester.getRect(...).right` giữa các dòng; đã có ca test làm
đúng thế.

✅ **`report_preview_page.dart` cũng đã sửa, cùng ngày** (G40 đóng). Trang ấy
mang **sáu** chỗ cùng khuôn chứ không phải hai như tên hai khối gợi ra: thêm
ngân sách, thu/chi theo danh mục, danh sách giao dịch, và hàng "Thay đổi trong
kỳ" của khối dòng tiền. Đo trên máy ảo trước khi sửa: khối "Chi theo danh mục"
lệch **93px** — gấp ba chỗ này; sau khi sửa: **0px**.

⚠️ **Ca test cho lỗi này KHÔNG viết được ở khổ 411dp.** Lỗi chỉ xuất hiện khi
chữ **ngắn hơn** suất được chia — khi ấy `Flexible` mới co hộp lại. Nhưng font
"Ahem" của bộ test rộng gấp đôi ngoài đời (bẫy 4.4), nên ở 411dp mọi chuỗi đều
**tràn** suất, `FittedBox` thu nhỏ chúng cho vừa, và hộp nào cũng lấp đầy suất —
đúng thứ mà `Expanded` lẽ ra mới làm được. Ba trong sáu ca đầu tiên **xanh ngay
từ đầu** vì thế, trong khi máy ảo đo được lệch 93px. Cho khung rộng **gấp đôi**
(822dp) là cách trả lại đúng tỷ lệ chữ trên suất của điện thoại thật.

⚠️ Và phép đo phải bám **hộp**, không bám chuỗi: mép phải của một `Text` số tiền
không nói lên gì ở khối danh mục (sau nó còn ô phần trăm), còn cùng một chuỗi số
tiền thì xuất hiện ở nhiều khối nên `find.text` không khoanh được vùng. Lấy
thẳng `RenderBox` của các `FittedBox` canh phải trong một khối
(`find.byWidgetPredicate`) mới là đo đúng thứ quyết định chỗ chữ rơi xuống.

**4.20 `rutGon` từng in `-0` ở nhãn trục.** Biểu đồ nào có phần âm thì biên trên
tính bằng `san + 3 * buoc`, và sai số dấu phẩy động cho ra chừng `-1e-16` ngay
tại vị trí lẽ ra là 0. `rutGon` dán dấu trừ vào con số làm tròn thành 0, nên
nhãn trục tung trên cùng in **`-0`** — một con số không tồn tại. Thấy trên máy
ảo 2026-09-15 ở khối "Dòng tiền tự do" (mục 3.24); `flutter test` mù hẳn vì nhãn
trục vẽ trong canvas của fl_chart.

Đã sửa **tại `rutGon`**, không phải tại khối gọi nó: `-0` không bao giờ là nhãn
đúng ở đâu cả, và đây đúng là luật `CurrencyFormatter.formatCoDau` đã có — **số
0 không mang dấu**. ⚠️ Chỉ bỏ dấu khi phần nguyên làm tròn ra 0; số âm thật vẫn
giữ dấu (`-1` → `-1`, `-950000` → `-950K`). Nuốt cả những số ấy là một lỗi khác,
nặng hơn.

**4.21 Trục biểu đồ: khi nào từ 0, khi nào co — và bước phải TRÒN.** Hai lỗi
liền nhau, cả hai chỉ máy ảo thấy (2633 ca test đều xanh), đo 2026-09-16 ở khối
Dự báo 30 ngày — cộng một lỗi **thứ ba** của chính phép sửa ấy, đo 2026-09-17 ở
khối Tổng tài sản (mục 3.30).

*Thứ nhất — trục từ 0 làm đường phẳng.* Cam kết 30 ngày chỉ bằng **2,8%** số dư
(388.000 trên 13.590.000), nên trục 0 → 14,9M cho ra một đường nằm ngang sát
đỉnh: không thấy bậc nào. Người dùng chốt **co trục theo dữ liệu** cho khối này.
⚠️ Điều ấy **không** mâu thuẫn với quyết định ngày 2026-09-15 ở thác nước
("trục từ 0, bóp méo trục là vẽ sai sự thật"): ở đó mắt **so độ cao giữa các
cột** nên trục phải từ 0; đường số dư thì không so độ cao, nó cho thấy **hình
dạng thay đổi** — bậc rơi vào ngày nào và sâu bao nhiêu. Nhãn trục vẫn in số
thật nên không ai đọc nhầm thành "về 0". Ranh giới để nhớ: **cột → từ 0; đường
số dư → co**.

*Thứ hai — bước lẻ làm hai nhãn in đè.* Co trục xong, bước ra `168.333` và đỉnh
trục hiện **"13.6M" hai lần chồng lên nhau**. Đây là bẫy **4.18** ở một dạng
khác: fl_chart vẽ nhãn ở cả hai biên cộng mốc theo `interval`, và với bước lẻ
thì biên trên lệch mốc cuối vài phần tỉ — đủ để thành hai lần vẽ ở hai vị trí
sát nhau. Đặt `maxY = san + 3 × buoc` (cách đã dùng ở khối Dòng tiền tự do)
**không đủ** khi `san` là số lẻ lớn.

Sửa tại **`daiTrucDuBao`** (tầng thuần, có test): bước lấy trong họ
**1 · 2 · 2,5 · 5 × 10^k** và sàn là **bội của bước**, nên mọi mốc rơi tròn và
phép cộng không sinh sai số — `13M · 13.2M · 13.4M · 13.6M`. Hàm còn **nới dải
cho tới khi bốn nhãn đôi một khác nhau**, vì `rutGon` chỉ giữ một chữ số lẻ:
cam kết 50.000 trên nền 13.590.000 cho cả bốn nhãn là "13.6M" (bản sai bỏ vòng
nới chỉ ra **2** nhãn khác nhau trên 4).

*Thứ ba — cùng hàm ấy lại quá RỘNG với dải bắt đầu từ 0* (2026-09-17, khối
Tổng tài sản). Bản đầu đặt `buoc = _buocTron(dải/2)` kèm lý lẽ *"sàn bị kéo
xuống bội gần nhất nên khoảng phải phủ được dải + bước"*. Đó là phép **trừ
hao**, và nó trừ trọn một bước kể cả khi sàn đã đúng bội và chẳng mất gì: dải
`0 → 13.590.000` nhận bước `10M`, trần `30M`, và đường thật bị ép xuống 45%
dưới của khung. Thay bằng phép **kiểm đúng**: bước khởi điểm `dải/3` (ba khoảng
giữa bốn nhãn), rồi nới **chỉ khi** `san + 3×buoc` thật sự chưa phủ đỉnh. Dải
hẹp quanh một số lớn — ca sinh ra hàm này — cho **cùng một bước** ở cả hai công
thức, nên khối Dự báo không đổi gì. ⚠️ **Không tính chất nào bị vi phạm khi lỗi
còn đó** (bước vẫn tròn, sàn ≤ đáy, trần ≥ đỉnh, bốn nhãn vẫn khác nhau) — chỉ
mắt mới thấy; ca test mới phải đòi thêm `trần < 1,5 × đỉnh`. Bài học: *một hằng
số an toàn đặt cho một ca sẽ là một hằng số sai cho ca kia — hãy kiểm điều kiện
thật thay vì trừ hao.*

Đi kèm: `belowBarData` thôi cắt ở mốc 0
khi 0 **nằm ngoài** dải, nếu không nó tô đặc cả biểu đồ.

**4.22 Exception trong hàm `async` của một `onTap` không nổi lên đâu cả.**
`showDateRangePicker` ném assertion khi `initialDateRange` thò ra ngoài
`[firstDate, lastDate]`, và vì không ai `await` kèm `catch`, Flutter chỉ in ra
console. Người dùng thấy một **nút chết**: không toast, không màn đỏ, không gì
cả. G43 sống được qua cả một lượt nghiệm thu máy ảo vì nó chỉ nổ ở đúng trạng
thái mặc định (*Tháng này* kết thúc sau hôm nay), và bộ test có **10** ca cho bộ
chọn phạm vi mà **không ca nào chạm vào chip ấy** — lỗi nằm sau một cú chạm không ai
thực hiện.

Hai luật rút ra:

1. **Mọi mốc truyền vào một bộ chọn ngày phải kẹp vào dải cho phép trước**, và
   phép kẹp nên là hàm thuần có test riêng. `khoangKhoiTaoBoChonNgay` trả `null`
   khi kỳ không giao với dải — trả một khoảng đảo đầu-cuối chỉ đổi sang một
   assertion khác.
2. **Ca test cho một nút phải đòi kết quả, không chỉ đòi "không ném".**
   `expect(tester.takeException(), isNull)` một mình vẫn **xanh** với một nút
   chết; phải kèm `expect(find.byType(DateRangePickerDialog), findsOneWidget)`.

⚠️ Và khi một hàng nút chỉ có **một** nút hỏng thì rất dễ đổ cho toạ độ chạm
của chính mình. Cách rẻ để phân biệt: bấm một nút **khác trong cùng hàng** —
ăn thì toạ độ đúng, và vấn đề nằm trong mã.

---

## 5. Luồng dữ liệu

```
AnalyticsPage ──watch AuthBloc──▶ idaccount
   └─ BlocProvider(key: ValueKey(idaccount)) ─▶ AnalyticsCubit.xem(idaccount)
         └─ AnalyticsRepository.watchKy(idaccount, ky, now)   ← BẢY nguồn
               ├─ transactionDao.watchAll ────────────┐
               ├─ categoryDao.watchBangTraTen ────────┤
               ├─ BudgetRepository.watchBudgets(now: mocNganSach) ─┤
               ├─ select(wallets) (kể cả xoá mềm — tra tên) ───────┼─▶ _dung() ─▶ ThongKeKy
               ├─ billDao.watchAll ───────────────────┤
               ├─ goalDao.watchAll ───────────────────┤
               └─ BudgetRepository.watchBudgets(now: at) ──────────┘
                     ⚠️ nguồn ngân sách THỨ HAI, tra tại `now` — RIÊNG cho
                     `duBao`; dùng chung nguồn trên là dự báo sai khi người
                     dùng xem kỳ đã qua (bẫy 1 của mục 3.27)
```

`ThongKeKy` mang: tổng kỳ này, tổng kỳ trước, chi theo danh mục (thô,
cho donut), cùng danh sách ấy đã tra tên/biểu tượng/màu/ngân sách (cho bảng),
**`chuoi`** — sáu điểm `DiemThoiGian` cho biểu đồ xu hướng, và **`taiSan`** —
sáu điểm `DiemTaiSan` cho đường tổng tài sản, kèm `giaoDichDauTien` để khối ấy
biết đoạn đầu đường có đứng vững không. Widget **không cộng gì cả**: con số
lớn của khối tổng tài sản là `taiSan.last.tong`, không phải một phép cộng ví
riêng — cộng lại ở tầng vẽ là bản chép tay thứ **sáu** của `viTinhVaoTong`.

Trang **Xuất báo cáo** đi đường riêng, không qua cubit nào:

```
ExportReportPage ──watch AuthBloc──▶ idaccount
   ├─ BaoCaoRepository.watchVi / watchDanhMuc ─▶ chip ví, sheet danh mục
   └─ [Xem trước báo cáo] ─▶ Ky đang chọn (moChonPhamVi, chung trang Phân tích)
         └─ BaoCaoRepository.layBaoCao(idaccount, loc)   (Future, một ảnh chụp)
               ├─ transactionDao.getAll ─┐   (TOÀN BỘ, không lọc kỳ)
               ├─ wallets (KỂ CẢ đã xoá) ┤
               ├─ categories (KỂ CẢ xoá) ┼─▶ dungBaoCao() ─▶ BaoCao
               ├─ tổng số dư ví CÒN SỐNG ┤
               └─ budgetRepository ──────┘
                     └─▶ ReportPreviewPage(baoCao: …)  — không đọc CSDL
```

`dungBaoCao` mượn nguyên luật đếm của `thong_ke_thang.dart` (`tongThuChi`,
`chiTheoDanhMuc`), nên hai trang không thể nói hai con số khác nhau về cùng một
tháng. Ví và danh mục tra tên **kể cả hàng đã xoá mềm** — cùng lý do mục 3.8.

⚠️ Repository truyền **toàn bộ** giao dịch của tài khoản chứ không lọc sẵn theo
kỳ: kỳ trước (mục 3.15) và dòng tiền (mục 3.16) đều nhìn ra ngoài khoảng đang
xem. Ai "tối ưu" bằng cách lọc trước khi gọi sẽ làm hai khối ấy sai mà không lỗi
nào báo — cùng bẫy với `chuoi` của `ThongKeKy`. Riêng **tổng số dư** thì lấy
từ ví **còn sống** (`walletDao.getAll`), để khớp con số trang chủ hiện.

⚠️ `chuoi` nhìn **xa hơn** `tongTruoc` nhiều, nên nó phải được dựng từ **toàn
bộ** giao dịch của tài khoản. `transactionDao.watchAll` đã trả về tất cả nên
không cần truy vấn mới — nhưng ai đó "tối ưu" bằng cách lọc `txs` theo tháng
đang xem trước khi vào `_dung()` sẽ làm biểu đồ phẳng lì mà không lỗi nào báo.
Test `sáu điểm, cũ nhất trước, mang số thật của cả tháng ở xa` canh đúng chỗ ấy.

---

## 6. Kiểm thử

| Tệp | Canh gì |
|---|---|
| `thong_ke_thang_test.dart` | Biên tháng (tháng 12, **năm nhuận**, tháng 2 thường), biên `to` mở, loại `transfer`, % với tháng trước = 0, gom danh mục và sắp ổn định khi hoà, top‑4 + Khác (kể cả đúng 5), `rutGon` (làm tròn, bỏ `.0`, và từ 2026-09-15 — **số làm tròn ra 0 thì không mang dấu**, bẫy 4.20; số âm thật vẫn giữ dấu) — luật "12 kỳ gần nhất" chuyển sang `pham_vi_ky_test.dart` ngày 2026-09-15 |
| `analytics_repository_impl_test.dart` | Đổi hàng Drift → thuần, cách ly `idaccount`, ba chữ cho ba ca danh mục **kể cả xoá mềm giữ tên thật** và **kể cả hàng mặc định toàn cục `idaccount = 0`** (G41), "% ngân sách" bám ngân sách đang chạy và **bỏ ngân sách hết hạn**, stream phát lại khi ghi thêm; và từ 2026-09-16 — **bảy** nguồn, `duBao` nối đúng hoá đơn/mục tiêu/ví, `null` khi không ví, và ⚠️ **xem tháng cũ thì dự báo vẫn tính từ hôm nay** (bẫy 1 mục 3.27) |
| `tong_tai_san_test.dart` (2026-09-17) | Tầng thuần của **tổng tài sản theo thời gian** (mục 3.30): sáu điểm cũ nhất trước; điểm cuối **bằng đúng tổng ví tính vào tổng**; ⚠️ hàng ghi **ngày tương lai** đứng yên ở *mọi* điểm (kẹp mốc một mình không cứu được); suy ngược thu/chi, **được phép âm**, biên tại mốc là *sau* mốc; khoản chuyển giữa hai ví trong tổng triệt tiêu còn chuyển ra ví ngoài tổng **có** giảm, thiếu ví đích thì bỏ qua; ví loại khỏi tổng / lưu trữ / đã xoá đều không cộng; lùi sáu kỳ qua mốc năm, **tháng 2 năm nhuận**, sáu nhãn quý khác nhau; `thayDoiTaiSan` và `mocThieuDuLieu` trả `null` đúng lúc; `cumSoKy` là nguồn chung của tiêu đề và câu "trong …" |
| `du_bao_dong_tien_test.dart` (2026-09-16) | Tầng thuần của **dự báo 30 ngày** (mục 3.27): `null` khi không ví; số dư qua `viTinhVaoTong` **bỏ cả ví đã xoá mềm**; hoá đơn `conPhaiTra` → cam kết, quá hạn **dồn về hôm nay và nằm ở điểm 0**, kỳ chiếu nối từ `periodEnd` giữ ân hạn và `anchorDay` (năm nhuận), chỉ chiếu từ **hàng cuối chuỗi**, chu kỳ lạ thì dừng; trích tự động kẹp ở phần còn thiếu và **luật chuyển ví** ba nhánh; ngân sách tổng đè danh mục, **khử đếm đôi** với hoá đơn cùng danh mục, quý còn 60 ngày tính nửa; ví thiếu theo từng ví với ngưỡng **nửa đồng**, bỏ ví lưu trữ; chuỗi **đúng 31 điểm**; và `daiTrucDuBao` — bước **tròn**, sàn bội của bước, nới dải cho tới khi **bốn nhãn khác nhau** (bẫy 4.21) |
| `bill_ky_ke_tiep_test.dart` + `bill_ky_ke_tiep_goi_lai_test.dart` (2026-09-16) | `kyKeTiepCua` là **định nghĩa duy nhất** của kỳ kế tiếp: nối từ `periodEnd` chứ không hạn trả (ân hạn 15 ngày), `anchorDay` 31 qua tháng Hai **năm nhuận**, hàng cũ `periodEnd` NULL ra y hệt trước v21, chu kỳ tuần; và một ca chứng minh `_nextPeriodOf` **gọi lại** nó chứ không giữ bản chép |
| `analytics_cubit_test.dart` | `null` không đoán tài khoản; tháng lấy từ `clock` và `now` đi xuống repository; đổi tháng huỷ đăng ký cũ; lỗi stream không nổ |
| `bao_cao_xuat_test.dart` | Tầng thuần của lát 2c: bốn phạm vi thời gian (**tháng 1 lùi sang năm trước**, quý IV, tuỳ chỉnh cộng một ngày, năm nhuận), lọc theo ví/danh mục, `'transfer'` bị loại khỏi **cả** tổng lẫn danh sách, gom danh mục, nhóm theo ngày mới-nhất-trước, báo cáo rỗng. Lát 2c‑1b thêm: `khoangKyTruoc` (**tháng lùi theo tháng, không trừ N ngày**; quý; tuỳ chỉnh), dòng tiền (trừ phần sau kỳ, `transfer` không làm lệch, lọc ví thì `null`), thu theo danh mục, phân bổ theo ví, số liệu nhanh (**chia cho số ngày CỦA KỲ**), top 5, và độ chia của biểu đồ đổi theo độ dài kỳ |
| `bao_cao_repository_impl_test.dart` | Tra tên ví/danh mục **kể cả hàng đã xoá mềm** và **kể cả hàng mặc định toàn cục** (G41 — trang này mang bản chép tay thứ hai của cùng truy vấn), ba chữ cho ba ca danh mục, tiêu đề lấy ghi chú rồi mới tới tên danh mục, cách ly `idaccount`, giao dịch đã xoá mềm không vào báo cáo, danh sách cho bộ lọc chỉ lấy hàng còn sống; **dòng tiền dùng tổng số dư ví còn sống**, và ngân sách hết hạn không lên báo cáo |
| `luu_tep_platform_test.dart` | **Hợp đồng gọi** xuống Kotlin: đúng tên phương thức và đủ ba tham số (`ten`, `mime`, `bytes`); `khong_ho_tro` và `MissingPluginException` trả `null` để bên gọi lùi phương án; còn lỗi ghi **thật** thì ném lên chứ không nuốt |
| `xuat_tep_test.dart` | Nội dung tệp: CSV có **BOM**, dòng `sep=;`, CRLF, số nguyên thô mang dấu, thoát ngoặc kép và dấu phân cách, không có `transfer`, không bịa dòng tiền; PDF hợp lệ, **không rơi về Helvetica**, và báo cáo rỗng vẫn ra tệp. Tên tệp không mang ký tự cấm. Từ 2026-09-17 (mục **3.31**) canh thêm ba khối mới — số thô của kỳ trước, phần trăm **đúng thang** (chống bẫy `_tiLe`), ô rỗng khi nền bằng 0, ba chỉ số của Số liệu nhanh, top 5 mang dấu âm, và **hai khối biến mất khi không có gì để nói** — cộng một ca quét **glyph**: mọi ký tự hằng của `xuat_tep.dart` phải có trong cmap của cả hai tệp Roboto |
| `report_preview_page_test.dart` | Ba thẻ tổng, **khoảng hiện ngày cuối thật** (biên `to` mở), nhãn bộ lọc, bảng danh mục có %, nhóm ngày kèm tên ví, dấu +/−, trạng thái rỗng, **nút Tải xuống phải TẮT**, 411dp; và tám khối của 2c‑1b: dòng tiền (kèm dòng "suy ngược", và **biến mất khi lọc ví**), `▲ %` so kỳ trước, thu theo danh mục, ngân sách có nhãn "Vượt", phân bổ theo ví (**số 0 không mang dấu**), top 5, số liệu nhanh, và có `LineChart` |
| `export_report_page_test.dart` | Ví lấy từ CSDL (không còn "Techcombank"), không còn lịch sử xuất bịa, bộ lọc đi **nguyên vẹn** xuống repository (khoảng theo đồng hồ, id ví, id danh mục), mở đúng màn Xem trước, 411dp |
| `khoan_vao_thong_ke_test.dart` | **Luật loại khoản** dùng chung cho mọi phép đếm tiền (G37, 2026-09-13): khoản **chuyển ví**, khoản **điều chỉnh số dư** và khoản **mở sổ** đều không vào thống kê — nhưng khoản *chưa phân loại thật* và khoản thu thật thì vẫn vào, và ghi chú trùng khuôn mà **có** danh mục cũng vẫn vào (nhận dạng bằng **cặp** điều kiện, không phải một) |
| `pham_vi_ky_test.dart` | **P1 (mục 3.20).** Biên `[from, to)` của cả năm đơn vị, ba dạng nhãn (⚠️ kèm ca canh **không nhãn nào dài hơn nhãn tháng** — ở tầng thuần, vì font test rộng gấp đôi), `cacKyGanNhat`, `lui` **theo đơn vị lịch**, `khoangKyTruoc`, `nhanOChon`, `nhanKyTruoc`, `tieuDeXuHuong`, và phép bằng nhau của `Ky` |
| `chon_pham_vi_sheet_test.dart` | **P1.** Bottom sheet hai tầng: mở đúng đơn vị đang xem, dấu tích, đổi chip **chưa** chọn kỳ nào, trả đúng `Ky` (kể cả đơn vị tuần), năm chip đúng thứ tự cố định, ⚠️ **chiều cao KHÔNG đổi khi đổi đơn vị** (ca này sinh ra từ máy ảo: sheet co theo số dòng thì hàng chip trượt xuống dưới ngón tay), và 411dp với danh sách dài nhất |
| `phan_loai_dong_tien_test.dart` | **A8 #3/#7 (mục 3.19).** `phanLoaiCua` lấy `classify` của danh mục và **rơi về `type`** khi không tra được hoặc `classify` lạ; `theoPhanLoai` cho ba nhóm **rời nhau**, tổng tỉ lệ bằng 1, ⚠️ **khoản chi gắn danh mục vay/nợ KHÔNG nằm ở lát chi** (hệ quả cố ý), lát rỗng bị bỏ, khoản chuyển ví và khoản mở sổ không lọt vào lát nào |
| `vai_vay_no_test.dart` | **A8 #4/#5 (mục 3.22).** ⚠️ **Cùng danh mục, đổi chiều tiền là đổi vai** — ca lật cả thiết kế; tên không đoán được thì là `khac` chứ **không dồn về một vai**; **bỏ dấu KHÔNG được coi là khớp** (quy tắc 7); và `chuoiVayNo` sáu kỳ cũ-nhất-trước, **chỉ đếm** khoản thuộc nhóm Vay/nợ, kỳ rỗng vẫn giữ chỗ, đi theo đơn vị của kỳ |
| `thac_nuoc_test.dart` | **A8 #10 (mục 3.23).** Các bậc và **phép cân** `đầu kỳ + thu − Σ nhóm chi == cuối kỳ`, ca biên, `ranhVuotTrungBinh` (vạch TB trên từng cột chi, ngưỡng **nửa đồng** cho đuôi lẻ `double`), `trungBinhNhomChi` |
| `dong_tien_tu_do_test.dart` | **A8 #8 (mục 3.24) và tỉ lệ tiết kiệm (mục 3.26).** ⚠️ **Thu nhập không phải `tong.thu`** — ba ca riêng cho *đi vay*, *thu nợ* và `khacVao` đều bị trừ, còn `choVay`/`khacRa` thì **không** đụng tới; tự do **âm** không kẹp về 0; thứ tự cũ-nhất-trước; và hai chốt chặn ghép nhầm kỳ (**lệch độ dài** hoặc **lệch `ky`** đều phải nổ). Cộng `tieuDeDongTienTuDo` đổi theo đơn vị. Từ mục 3.26 thêm `thuNhapCua` (⚠️ có ca canh nó trả **đúng** con số mà `dongTienTuDo` dùng — ca giữ hai khối trên cùng trang không lệch) và `tyLeTietKiem` (**`null`** khi thu nhập không dương, kể cả **âm**; tỉ lệ được phép âm) |
| `analytics_page_test.dart` | Tháng từ đồng hồ (không còn "T6 2026"), ba thẻ, "% ngân sách"/"% tổng chi", donut + Khác + tâm rút gọn, rỗng, chọn tháng, "Xem tất cả", **411dp với tên dài**, và khối xu hướng: sáu nhãn tháng lấy từ dữ liệu, chú giải Thu/Chi, chuỗi rỗng không nổ, 411dp với số hàng trăm triệu. Từ 2026-09-14/15 thêm **sáu nhóm ca ở tầng vẽ**: cơ cấu theo danh mục, chip danh mục của khối Xu hướng, bốn khối mượn từ trang Báo cáo, hai biểu đồ vay/nợ, khối thác nước, và **Dòng tiền tự do** (⚠️ nhóm cuối canh đúng cặp số `12.000.000đ` phải có / `17.000.000đ` phải không — đó là ranh giới giữa luật đúng và công thức sai). Từ 2026-09-16 thêm nhóm **khối dự báo 30 ngày**: ba con số, dòng ví thiếu, "Xem thêm (n)" mở hết, câu rỗng, **kỳ đang xem rỗng vẫn hiện khối**, 411dp, và ⚠️ ca **ẩn cả khối** chỉ đỏ khi phá **cả hai** lớp chốt |

Lát 2b thêm vào `thong_ke_thang_test.dart` sáu ca cho `chuoiTheoKy` (khi ấy còn tên `chuoiTheoThang`): thứ tự
**cũ nhất trước**, cuộn qua năm trước, **năm nhuận**, tháng rỗng giữ chỗ,
`transfer` bị bỏ, và tổng các điểm bằng đúng số đã ghi (các khoảng không chồng
nhau).

Sáu bản sai có chủ ý đã dùng, mỗi cái làm đúng một test đỏ: biên đóng, bỏ lọc
hết hạn, bỏ huỷ đăng ký, `categoryDao.watchAll` thay cho truy vấn kể cả xoá
mềm, **đảo thứ tự chuỗi thành mới-nhất-trước**, và **nhãn trục đếm `T${i + 1}`
thay vì lấy từ dữ liệu**. Thêm một test tự cãi với lời giải thích của nó (thứ
tự khi hoà) — phát hiện nhờ chạy chứ không nhờ đọc.

⚠️ **Ba thứ của biểu đồ mà bộ test không với tới:** vị trí tooltip (bẫy 4.9),
màu và độ dày nét, và việc đường cong có vọt xuống dưới 0 giữa hai điểm hay
không (`preventCurveOverShooting`). Cả ba chỉ kiểm được bằng mắt trên máy thật.

---

## 7. Còn lại

### 7.1 Bảng A8 — trạng thái từng mục (đếm lại 2026-09-15)

Bảng gốc ở `Project.md` dòng 1028–1041, **11 mục**. Dựng bảng này vì trước đó
phải ghép từ bốn chỗ mới trả lời được câu "mảng Phân tích xong chưa".

| # | Chức năng | Trạng thái |
|---|---|---|
| 1 | Tổng hợp kết quả thu chi | ✅ |
| 2 | Tròn theo **Phân loại** (thu · chi · vay/nợ) | ⚠️ làm rồi **bỏ** — người dùng chốt 2026-09-14, xem mục 3.19 |
| 3 | Tròn theo **Loại danh mục** | ✅ 2026-09-14, mục 3.19 |
| 4 | Cho vay + Thu nợ — cột | ✅ 2026-09-15, mục 3.22 |
| 5 | Đi vay + Trả nợ — cột | ✅ 2026-09-15, mục 3.22 |
| 6 | Xu hướng theo Phân loại — 2 đường | ✅ 2026-09-08 |
| 7 | Xu hướng theo loại danh mục | ✅ 2026-09-14 (tới 5 đường), mục 3.19 |
| 8 | **Dòng tiền tự do** (thu sau khi trả nợ) | ✅ 2026-09-15, mục **3.24** |
| 9 | Biến động Khoản vay | 🛑 **bỏ hẳn** — người dùng chốt 2026-09-16 |
| 10 | Thác nước | ✅ 2026-09-15, mục 3.23 |
| 11 | Sankey | 🛑 **bỏ hẳn** — người dùng chốt 2026-09-16 |

**#8 đã xong 2026-09-15** (mục **3.24**). ⚠️ Nhưng công thức **không** phải
`Σ thu − Σ traNo` như dòng này từng ghi: `tong.thu` đã gồm cả tiền **đi vay** và
tiền **thu nợ**, và cả hai đều không phải thu nhập. Luật đúng là
`(tổng thu − mọi khoản tiền VÀO thuộc nhóm Vay/nợ) − traNo` — xem mục 3.24.
Câu "#4, #5, #8, #9 bị chặn bởi mô hình dữ liệu" viết ngày 2026-09-14 nay
**chỉ còn đúng với #9**.

> 🛑 **Bảng A8 ĐÓNG từ 2026-09-16.** Người dùng chốt **bỏ hẳn** hai ô cuối —
> nguyên văn: *"bỏ biến động khoản vay với Sankey đi không cần thiết nữa"*. Đây
> là quyết định về **phạm vi sản phẩm**, không phải hoãn lại: đừng lên kế hoạch
> cho hai mục ấy nữa, và **đừng mở lại hàng đợi
> `docs/superpowers/backend/CAN-LAM/`** (đang rỗng) để xin dư nợ gốc / lãi suất
> / kỳ hạn — mục duy nhất cần những cột ấy đã bị bỏ. Lý lẽ kỹ thuật của hai ô
> vẫn ghi lại bên dưới vì nó giải thích *vì sao bỏ là hợp lý*, không phải vì
> còn việc.
>
> Bài học chung: **một ô trống trong bảng theo dõi không đồng nghĩa với một
> việc phải làm.** Khi chỉ còn những mục khó hoặc bị chặn bởi mô hình dữ liệu,
> hỏi người dùng có còn cần không trước khi lên kế hoạch, thay vì mặc định phải
> lấp cho đầy bảng.

**#9 chặn thật** — nó cần dư nợ còn lại, mà không đầu nào lưu dư nợ gốc, lãi
suất hay kỳ hạn. **#11 (Sankey) làm được nhưng nặng hơn hẳn:** `fl_chart` không
có Sankey, phải tự vẽ bằng `CustomPainter`, và vùng vẽ không test tự động được
(bẫy 4.9).

**Mảng Báo cáo thì xong hẳn** — trang Xuất báo cáo đọc số thật, màn Xem trước
mười khối, nút Tải xuống sinh PDF/CSV và lưu thẳng vào thư mục Tải về.


- ✅ ~~**2b — biểu đồ theo thời gian.**~~ **Xong 2026-09-08.** `fl_chart` ghim
  `1.2.0`, khối "Xu hướng 6 tháng" — mục **3.11** và **3.12**. Thư viện nay đã
  chọn, nên **biểu đồ tiến độ mục tiêu** (hạng 1 mục 10.5 `GOAL_FEATURE.md`)
  chỉ còn là việc đổ dữ liệu khác vào cùng một khuôn.
- ✅ ~~**2c‑1 — trang Xuất báo cáo đọc số thật + màn Xem trước.**~~ **Xong
  2026-09-09.** Ví/danh mục/thời gian lấy từ CSDL, tầng thuần `bao_cao_xuat.dart`,
  màn `report_preview_page.dart` theo màn Stitch mới. Ba khối bịa đã bỏ (mục
  3.13).
- ✅ ~~**2c‑1b — báo cáo chi tiết theo chuẩn app thị trường.**~~ **Xong
  2026-09-09.** Tám khối mới, lý do và nguồn khảo sát ở mục **3.15**; dòng tiền
  và hai giới hạn của nó ở mục **3.16**.
- ✅ ~~**2c‑2 — nút "Tải xuống" sinh tệp thật.**~~ **Xong 2026-09-09.** PDF và
  CSV, **lưu thẳng vào thư mục Tải về** qua `MediaStore` (sheet chia sẻ chỉ còn
  là đường lùi cho Android ≤ 9) — mục **3.17** và **3.18**. Biểu
  đồ trong PDF vẽ bằng `pw.Chart` của chính gói `pdf` chứ **không** chụp widget:
  chụp đòi widget đang nằm trong khung nhìn, mà `ListView` thì tháo widget ngoài
  màn hình. ⚠️ **Tệp khi ấy vẫn thiếu ba khối** mà màn Xem trước đang hiện —
  đóng nốt 2026-09-17, mục **3.31**.
- ✅ ~~**A8 #3, #7 — cơ cấu theo danh mục và xu hướng nhiều danh mục.**~~ **Xong
  2026-09-14**, mục **3.19**. Mục **#2** (tròn theo phân loại) làm xong rồi **bỏ**
  cùng ngày: nó bắt thêm một cú chạm mới tới được thứ người dùng thật sự tìm. Bốn
  mục A8 còn lại (#4, #5, #8, #9) bị chặn bởi mô hình dữ liệu vay/nợ mà cả hai
  đầu đều không có; **#10** (thác nước) và **#11** (Sankey) làm được với thu/chi
  nhưng để đợt sau. ⚠️ **Đính chính 2026-09-15:** #4 và #5 **không** bị chặn —
  xem mục **3.22**; **#8** cũng không — và nó **đã làm xong** 2026-09-15 (mục
  **3.24**); chỉ **#9** chặn thật; **#10 đã làm xong** 2026-09-15 (mục 3.23).
  🛑 **Đính chính 2026-09-16:** **#9 và #11 bỏ hẳn** — người dùng chốt; bảng A8
  không còn ô nào là việc.
- ⚠️ Câu *"Mảng Phân tích đến đây là xong"* đứng ở đây từ 2026-09-09 **đã bị gỡ
  ngày 2026-09-15**: người dùng chốt làm tiếp mảng Phân tích và Báo cáo. ✅ **P1
  (mục 3.20), P2 (mục 3.21) và A8 #4/#5 (mục 3.22) xong cùng ngày.** 🛑 **P3**
  (thác nước, A8 #10) từng bị chốt **không làm**, nhưng người dùng **đổi ý**
  cùng ngày và nó **đã xong** — mục **3.23**. ✅ **#8 (dòng tiền tự do) cũng
  xong 2026-09-15** — mục **3.24**. 🛑 **Hai ô còn lại — #9 (biến động khoản
  vay) và #11 (Sankey) — người dùng chốt BỎ HẲN ngày 2026-09-16**, nên bảng A8
  nay không còn việc nào; xem banner ở mục **7.1**. Kế hoạch ở
  `docs/superpowers/plans/2026-09-15-ke-hoach.md` (gitignore).
- **Tổng kết tuần KHÔNG phải việc còn lại** — nó đã làm xong **2026-09-09**
  (mục **5d** `NOTIFICATION_FEATURE.md`). Điều kiện "một màn hình có phạm vi
  đúng một tuần" của spec `2026-09-07-weekly-summary-notification-design.md`
  đóng bằng **phạm vi tuỳ chỉnh của trang Xuất báo cáo**, không phải bằng P1.
  Ghi chú 2026-09-08 trong spec ấy nói "còn thiếu màn phạm vi tuần" là **ảnh
  chụp của một ngày trước đó**; đọc tiếp xuống là thấy khối "✅ Đã đủ". P1 vẫn
  có giá trị riêng — nó cho **chính trang Phân tích** một phạm vi tuần — nhưng
  đừng ghi nó là thứ gỡ chặn cho Tổng kết tuần.
- Tiêu đề trang là "Thống kê", tab dưới là "Phân tích" — hai tên cho một chỗ,
  lấy từ Stitch. Chưa đổi vì chưa ai nói tên nào đúng.
