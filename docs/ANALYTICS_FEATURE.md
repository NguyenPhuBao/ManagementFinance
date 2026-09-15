# Trang Phân tích — thiết kế, lý do, và những cái bẫy

**Cập nhật:** 2026-09-15 (mục **3.20** — **P1: phạm vi thời gian**; mục **3.21** — **P2**: bốn khối mượn từ trang Xuất báo cáo; mục **3.22** — **A8 #4 và #5**: hai biểu đồ cột vay/nợ; **G40 đóng** — trang Xem trước báo cáo lệch cột số tiền ở **sáu** chỗ, đo được 93px, xem bẫy **4.19**; **nhãn quý rút thành `Q3 2026`** để ô header thôi cụt, xem mục **3.20**; mục **3.23** — **A8 #10**: thác nước "Tiền đi đâu", kèm vạch trung bình trên từng cột chi) · bản trước 2026-09-14 (mục **3.19** — A8 #3, #7: cơ cấu theo danh mục với ba chip nhóm, và xu hướng tới 5 danh mục cùng lúc; bản thi công **lần hai**, #2 đã bỏ)
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
| Đụng giao diện | **Bốn** màn Stitch còn dùng được: `c8567243…` *"Thống kê - Cơ cấu danh mục & Xu hướng 6 tháng"* (2026-09-14) cho thân trang, **`83993fc9f5de4c5f8fba6940480c164a`** *"Thống kê - Chọn phạm vi thời gian"* (2026-09-15) cho bộ chọn phạm vi, **`6e9007f7653749a893c88e3de535afa5`** *"Thống kê - Biểu đồ Cho vay & Đi vay"* (đo được 2026-09-15) cho hai biểu đồ vay/nợ, và **`afe1c3fdee43464c90ddadc508eaa599`** *"Thống kê - 4 Thẻ Dòng Tiền & Kế Toán"* (đo được 2026-09-15) cho bốn khối của P2 — ⚠️ màn thứ tư mang `deviceType: DESKTOP` dù lượt gọi truyền `MOBILE`, xem mục **3.21** — ⚠️ màn thứ ba vẽ thêm **hai thẻ tổng** mà bản thi công **cố ý không có**, xem mục 3.22 — ⚠️ **hai** màn cũ đã lỗi thời và vẫn còn trong dự án: `c2a2b615…` (tả A8 #2 đã bỏ: mức gốc ba lát + dropdown) và `a228fa69…` "FlowMoney Analytics Dashboard"; và mục 4.4 về font của bộ test |
| Đụng biểu đồ | Mục **3.11** (vì sao `fl_chart`, vì sao ghim phiên bản), **3.12** (khối xu hướng từng lệch Stitch, nay hết), **3.19** (đường một danh mục), và bẫy **4.9** (tooltip tràn — thứ duy nhất phải kiểm bằng mắt) |
| Sinh tệp PDF/CSV | Mục **3.17** (vì sao nhúng font, vì sao `MediaStore` chứ không phải quyền ghi bộ nhớ), **3.18** (ba luật của CSV cho Excel tiếng Việt), bẫy **4.15**–**4.16** |
| Đụng trang Xuất báo cáo / màn Xem trước | Mục **3.13** (vì sao xem trước rồi mới tải), **3.14** (ảnh chụp, không phải luồng sống; và màn Stitch mới), **3.15** (mười khối lấy chuẩn từ app thị trường), **3.16** (dòng tiền là số suy ngược, hai giới hạn), bẫy **4.11**–**4.14** |
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
> **không bị chặn**: nó là `Σ thu − Σ khoản mang vai traNo`, mà `VaiVayNo.traNo`
> có sẵn từ chính lát #4/#5 — **chưa làm**, không phải không làm được. Chỉ **#9**
> chặn thật, vì nó cần **dư nợ còn lại**. ✅ **#10 (thác nước) đã làm xong**
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

**Năm cái bẫy, cả năm đều hỏng im lặng:**

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
   nó là hàm thuần.
5. ⚠️ **Lùi kỳ theo đơn vị lịch, không trừ số ngày.** `lui` là chỗ duy nhất làm
   việc ấy; bản sai có chủ ý dùng `subtract(Duration(days: 30))` cho ra
   `2026-01-01` thay vì `2026-02-01`.

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

**Repository nhận nguồn thứ tư: ví.** Ba trong bốn khối cần nó — "phân bổ theo
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

#### Nghiệm thu

Trên `emulator-5554`, kỳ T9 2026: cột "Đầu kỳ" 10.000 sát đáy, cột "+Thu" xanh
cao, sáu khối đỏ nối tiếp nhau đi xuống, cột "Cuối kỳ" đen dừng đúng ở
13.590.000 — bậc thang khép kín. Dòng chú thích hiện *"Phần đậm là chỗ vượt mức
trung bình 174.167 đ/nhóm"*. `flutter test` **2540/2540**, `flutter analyze`
**25 issue, 0 error**, schema giữ **v22**, không thêm trường đồng bộ.

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

---

## 5. Luồng dữ liệu

```
AnalyticsPage ──watch AuthBloc──▶ idaccount
   └─ BlocProvider(key: ValueKey(idaccount)) ─▶ AnalyticsCubit.xem(idaccount)
         └─ AnalyticsRepository.watchKy(idaccount, ky, now)
               ├─ transactionDao.watchAll ─┐
               ├─ categoryDao.watchAll ────┼─▶ _dung() ─▶ ThongKeKy
               └─ BudgetRepository.watchBudgets(now: mốc) ┘
                     (đã có spent theo kỳ; lọc isExpired ở đây)
```

`ThongKeKy` mang: tổng kỳ này, tổng kỳ trước, chi theo danh mục (thô,
cho donut), cùng danh sách ấy đã tra tên/biểu tượng/màu/ngân sách (cho bảng),
và **`chuoi`** — sáu điểm `DiemThoiGian` cho biểu đồ xu hướng. Widget **không
cộng gì cả**.

Trang **Xuất báo cáo** đi đường riêng, không qua cubit nào:

```
ExportReportPage ──watch AuthBloc──▶ idaccount
   ├─ BaoCaoRepository.watchVi / watchDanhMuc ─▶ chip ví, sheet danh mục
   └─ [Xem trước báo cáo] ─▶ khoangCuaPhamVi(phạm vi, now, tuỳ chọn)
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
| `thong_ke_thang_test.dart` | Biên tháng (tháng 12, **năm nhuận**, tháng 2 thường), biên `to` mở, loại `transfer`, % với tháng trước = 0, gom danh mục và sắp ổn định khi hoà, top‑4 + Khác (kể cả đúng 5), `rutGon` (làm tròn, bỏ `.0`) — luật "12 kỳ gần nhất" chuyển sang `pham_vi_ky_test.dart` ngày 2026-09-15 |
| `analytics_repository_impl_test.dart` | Đổi hàng Drift → thuần, cách ly `idaccount`, ba chữ cho ba ca danh mục **kể cả xoá mềm giữ tên thật**, "% ngân sách" bám ngân sách đang chạy và **bỏ ngân sách hết hạn**, stream phát lại khi ghi thêm |
| `analytics_cubit_test.dart` | `null` không đoán tài khoản; tháng lấy từ `clock` và `now` đi xuống repository; đổi tháng huỷ đăng ký cũ; lỗi stream không nổ |
| `bao_cao_xuat_test.dart` | Tầng thuần của lát 2c: bốn phạm vi thời gian (**tháng 1 lùi sang năm trước**, quý IV, tuỳ chỉnh cộng một ngày, năm nhuận), lọc theo ví/danh mục, `'transfer'` bị loại khỏi **cả** tổng lẫn danh sách, gom danh mục, nhóm theo ngày mới-nhất-trước, báo cáo rỗng. Lát 2c‑1b thêm: `khoangKyTruoc` (**tháng lùi theo tháng, không trừ N ngày**; quý; tuỳ chỉnh), dòng tiền (trừ phần sau kỳ, `transfer` không làm lệch, lọc ví thì `null`), thu theo danh mục, phân bổ theo ví, số liệu nhanh (**chia cho số ngày CỦA KỲ**), top 5, và độ chia của biểu đồ đổi theo độ dài kỳ |
| `bao_cao_repository_impl_test.dart` | Tra tên ví/danh mục **kể cả hàng đã xoá mềm**, ba chữ cho ba ca danh mục, tiêu đề lấy ghi chú rồi mới tới tên danh mục, cách ly `idaccount`, giao dịch đã xoá mềm không vào báo cáo, danh sách cho bộ lọc chỉ lấy hàng còn sống; **dòng tiền dùng tổng số dư ví còn sống**, và ngân sách hết hạn không lên báo cáo |
| `luu_tep_platform_test.dart` | **Hợp đồng gọi** xuống Kotlin: đúng tên phương thức và đủ ba tham số (`ten`, `mime`, `bytes`); `khong_ho_tro` và `MissingPluginException` trả `null` để bên gọi lùi phương án; còn lỗi ghi **thật** thì ném lên chứ không nuốt |
| `xuat_tep_test.dart` | Nội dung tệp: CSV có **BOM**, dòng `sep=;`, CRLF, số nguyên thô mang dấu, thoát ngoặc kép và dấu phân cách, không có `transfer`, không bịa dòng tiền; PDF hợp lệ, **không rơi về Helvetica**, và báo cáo rỗng vẫn ra tệp. Tên tệp không mang ký tự cấm |
| `report_preview_page_test.dart` | Ba thẻ tổng, **khoảng hiện ngày cuối thật** (biên `to` mở), nhãn bộ lọc, bảng danh mục có %, nhóm ngày kèm tên ví, dấu +/−, trạng thái rỗng, **nút Tải xuống phải TẮT**, 411dp; và tám khối của 2c‑1b: dòng tiền (kèm dòng "suy ngược", và **biến mất khi lọc ví**), `▲ %` so kỳ trước, thu theo danh mục, ngân sách có nhãn "Vượt", phân bổ theo ví (**số 0 không mang dấu**), top 5, số liệu nhanh, và có `LineChart` |
| `export_report_page_test.dart` | Ví lấy từ CSDL (không còn "Techcombank"), không còn lịch sử xuất bịa, bộ lọc đi **nguyên vẹn** xuống repository (khoảng theo đồng hồ, id ví, id danh mục), mở đúng màn Xem trước, 411dp |
| `analytics_page_test.dart` | Tháng từ đồng hồ (không còn "T6 2026"), ba thẻ, "% ngân sách"/"% tổng chi", donut + Khác + tâm rút gọn, rỗng, chọn tháng, "Xem tất cả", **411dp với tên dài**, và khối xu hướng: sáu nhãn tháng lấy từ dữ liệu, chú giải Thu/Chi, chuỗi rỗng không nổ, 411dp với số hàng trăm triệu |

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
  màn hình.
- ✅ ~~**A8 #3, #7 — cơ cấu theo danh mục và xu hướng nhiều danh mục.**~~ **Xong
  2026-09-14**, mục **3.19**. Mục **#2** (tròn theo phân loại) làm xong rồi **bỏ**
  cùng ngày: nó bắt thêm một cú chạm mới tới được thứ người dùng thật sự tìm. Bốn
  mục A8 còn lại (#4, #5, #8, #9) bị chặn bởi mô hình dữ liệu vay/nợ mà cả hai
  đầu đều không có; **#10** (thác nước) và **#11** (Sankey) làm được với thu/chi
  nhưng để đợt sau. ⚠️ **Đính chính 2026-09-15:** #4 và #5 **không** bị chặn —
  xem mục **3.22**; **#8** cũng không (`Σ thu − Σ traNo`, vai đã có) — nó chỉ
  **chưa làm**; chỉ **#9** chặn thật; **#10 đã làm xong** 2026-09-15 (mục 3.23).
- ⚠️ Câu *"Mảng Phân tích đến đây là xong"* đứng ở đây từ 2026-09-09 **đã bị gỡ
  ngày 2026-09-15**: người dùng chốt làm tiếp mảng Phân tích và Báo cáo. ✅ **P1
  (mục 3.20), P2 (mục 3.21) và A8 #4/#5 (mục 3.22) xong cùng ngày.** 🛑 **P3**
  (thác nước, A8 #10) từng bị chốt **không làm**, nhưng người dùng **đổi ý**
  cùng ngày và nó **đã xong** — mục **3.23**. Còn **#11** Sankey và
  **#8** dòng tiền tự do; **#9** vẫn chặn thật vì cần dư nợ còn lại. Kế hoạch ở
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
