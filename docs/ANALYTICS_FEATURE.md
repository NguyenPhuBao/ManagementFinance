# Trang Phân tích — thiết kế, lý do, và những cái bẫy

**Cập nhật:** 2026-09-09
**Trạng thái:** lát **2a** xong — mọi con số trên trang là số thật từ SQLite —
lát **2b** xong (khối "Xu hướng 6 tháng" vẽ bằng `fl_chart`), và lát **2c‑1**
xong 2026-09-09: trang Xuất báo cáo đọc ví/danh mục/thời gian thật rồi mở màn
**Xem trước báo cáo**. Còn **2c‑2**: nút "Tải xuống" sinh tệp thật — hiện đang
**tắt** có chủ ý. Xem mục 7.

> Cùng mục đích với `GOAL_FEATURE.md`: giữ lại **vì sao**. Cái gì thì đọc mã và
> test là ra.

---

## 1. Đọc gì trước khi đụng vào

| Việc | Đọc |
|---|---|
| Bất cứ việc gì | Mục 3 (quyết định) và mục 4 (bẫy) |
| Sửa phép tính | `domain/thong_ke_thang.dart` và test của nó — **không** có CSDL, kiểm bằng danh sách |
| Sửa cách gộp dữ liệu | Mục 3.3 (mốc tra ngân sách) trước, rồi `data/analytics_repository_impl.dart` |
| Đụng giao diện | Màn Stitch **"FlowMoney Analytics Dashboard"** — bố cục lấy nguyên từ đó **trừ khối xu hướng**, xem **3.12**; và mục 4.4 về font của bộ test |
| Đụng biểu đồ | Mục **3.11** (vì sao `fl_chart`, vì sao ghim phiên bản), **3.12** (vì sao lệch Stitch), và bẫy **4.9** (tooltip tràn — thứ duy nhất phải kiểm bằng mắt) |
| Đụng trang Xuất báo cáo / màn Xem trước | Mục **3.13** (vì sao xem trước rồi mới tải), **3.14** (ảnh chụp, không phải luồng sống; và màn Stitch mới), bẫy **4.11** |
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

Phần test không mất gì: **phép tính nằm trọn ở `chuoiTheoThang()` tầng domain**
và được kiểm bằng danh sách ở đó. Lỗi âm thầm nằm trong con số chứ không trong
nét vẽ. Widget test chỉ còn canh ba thứ mà nó canh được thật: khối có mặt,
**nhãn trục lấy từ dữ liệu** (bản sai có chủ ý đổi nhãn thành `T${i + 1}` đã
làm đúng test ấy đỏ), và 411dp không tràn.

### 3.12 Khối xu hướng **lệch Stitch có chủ ý**

Đã tra cả 35 màn Stitch ngày 2026-09-08: màn "Analytics Dashboard" chỉ có
`conic-gradient` (donut) và màn "Chi tiết mục tiêu" chỉ có một `<svg>` vòng
tiến độ. **Không màn nào có biểu đồ đường hay cột.** Nghĩa là bản thiết kế trả
lời được *tiền đi đâu* nhưng không chỗ nào trả lời *đang tăng hay đang giảm*.

Khối nằm **giữa** khối tổng và donut, theo thứ tự câu hỏi: bao nhiêu → xu hướng
ra sao → đi vào đâu. Đây là chỗ đi lệch thiết kế, đã ghi tại chỗ trong
`_KhoiXuHuong` — **đừng "sửa lại cho khớp Stitch"**.

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
lát này đang đi dọn.

Ba khối của bản Stitch đã **bỏ** vì không có gì đỡ phía sau: "Lịch sử xuất gần
đây" (bịa hoàn toàn — muốn thật thì cần một bảng cục bộ), ô "Đặt mật khẩu bảo
vệ file PDF", và dòng "Đích đến: Lưu vào Tải về". Ô `.xlsx` cũng bỏ: nó cần
thêm một thư viện nữa mà `.csv` đã phục vụ đúng nhu cầu "phù hợp tính toán".

### 3.14 Màn Xem trước là **ảnh chụp**, không phải luồng sống

`BaoCaoRepository.layBaoCao` trả `Future`, không `Stream` — ngược với
`AnalyticsRepository.watchThang`. Tờ báo cáo là của một khoảng đã chốt; để nó
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
thành 266px, *"Chi tiêu theo hạng mục"* 18px thành 396px. Hai chỗ ấy tràn 30px
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

---

## 5. Luồng dữ liệu

```
AnalyticsPage ──watch AuthBloc──▶ idaccount
   └─ BlocProvider(key: ValueKey(idaccount)) ─▶ AnalyticsCubit.xem(idaccount)
         └─ AnalyticsRepository.watchThang(idaccount, nam, thang, now)
               ├─ transactionDao.watchAll ─┐
               ├─ categoryDao.watchAll ────┼─▶ _dung() ─▶ ThongKeThang
               └─ BudgetRepository.watchBudgets(now: mốc) ┘
                     (đã có spent theo kỳ; lọc isExpired ở đây)
```

`ThongKeThang` mang: tổng tháng này, tổng tháng trước, chi theo danh mục (thô,
cho donut), cùng danh sách ấy đã tra tên/biểu tượng/màu/ngân sách (cho bảng),
và **`chuoi`** — sáu điểm `DiemThoiGian` cho biểu đồ xu hướng. Widget **không
cộng gì cả**.

Trang **Xuất báo cáo** đi đường riêng, không qua cubit nào:

```
ExportReportPage ──watch AuthBloc──▶ idaccount
   ├─ BaoCaoRepository.watchVi / watchDanhMuc ─▶ chip ví, sheet danh mục
   └─ [Xem trước báo cáo] ─▶ khoangCuaPhamVi(phạm vi, now, tuỳ chọn)
         └─ BaoCaoRepository.layBaoCao(idaccount, loc)   (Future, một ảnh chụp)
               ├─ transactionDao.getAll ─┐
               ├─ wallets (KỂ CẢ đã xoá) ┼─▶ dungBaoCao() ─▶ BaoCao
               └─ categories (KỂ CẢ xoá) ┘
                     └─▶ ReportPreviewPage(baoCao: …)  — không đọc CSDL
```

`dungBaoCao` mượn nguyên luật đếm của `thong_ke_thang.dart` (`tongThuChi`,
`chiTheoDanhMuc`), nên hai trang không thể nói hai con số khác nhau về cùng một
tháng. Ví và danh mục tra tên **kể cả hàng đã xoá mềm** — cùng lý do mục 3.8.

⚠️ `chuoi` nhìn **xa hơn** `tongTruoc` nhiều, nên nó phải được dựng từ **toàn
bộ** giao dịch của tài khoản. `transactionDao.watchAll` đã trả về tất cả nên
không cần truy vấn mới — nhưng ai đó "tối ưu" bằng cách lọc `txs` theo tháng
đang xem trước khi vào `_dung()` sẽ làm biểu đồ phẳng lì mà không lỗi nào báo.
Test `sáu điểm, cũ nhất trước, mang số thật của cả tháng ở xa` canh đúng chỗ ấy.

---

## 6. Kiểm thử

| Tệp | Canh gì |
|---|---|
| `thong_ke_thang_test.dart` | Biên tháng (tháng 12, **năm nhuận**, tháng 2 thường), biên `to` mở, loại `transfer`, % với tháng trước = 0, gom danh mục và sắp ổn định khi hoà, top‑4 + Khác (kể cả đúng 5), `rutGon` (làm tròn, bỏ `.0`), 12 tháng gần nhất cuộn qua năm trước |
| `analytics_repository_impl_test.dart` | Đổi hàng Drift → thuần, cách ly `idaccount`, ba chữ cho ba ca danh mục **kể cả xoá mềm giữ tên thật**, "% ngân sách" bám ngân sách đang chạy và **bỏ ngân sách hết hạn**, stream phát lại khi ghi thêm |
| `analytics_cubit_test.dart` | `null` không đoán tài khoản; tháng lấy từ `clock` và `now` đi xuống repository; đổi tháng huỷ đăng ký cũ; lỗi stream không nổ |
| `bao_cao_xuat_test.dart` | Tầng thuần của lát 2c: bốn phạm vi thời gian (**tháng 1 lùi sang năm trước**, quý IV, tuỳ chỉnh cộng một ngày, năm nhuận), lọc theo ví/danh mục, `'transfer'` bị loại khỏi **cả** tổng lẫn danh sách, gom danh mục, nhóm theo ngày mới-nhất-trước, báo cáo rỗng |
| `bao_cao_repository_impl_test.dart` | Tra tên ví/danh mục **kể cả hàng đã xoá mềm**, ba chữ cho ba ca danh mục, tiêu đề lấy ghi chú rồi mới tới tên danh mục, cách ly `idaccount`, giao dịch đã xoá mềm không vào báo cáo, danh sách cho bộ lọc chỉ lấy hàng còn sống |
| `report_preview_page_test.dart` | Ba thẻ tổng, **khoảng hiện ngày cuối thật** (biên `to` mở), nhãn bộ lọc, bảng danh mục có %, nhóm ngày kèm tên ví, dấu +/−, trạng thái rỗng, **nút Tải xuống phải TẮT**, 411dp |
| `export_report_page_test.dart` | Ví lấy từ CSDL (không còn "Techcombank"), không còn lịch sử xuất bịa, bộ lọc đi **nguyên vẹn** xuống repository (khoảng theo đồng hồ, id ví, id danh mục), mở đúng màn Xem trước, 411dp |
| `analytics_page_test.dart` | Tháng từ đồng hồ (không còn "T6 2026"), ba thẻ, "% ngân sách"/"% tổng chi", donut + Khác + tâm rút gọn, rỗng, chọn tháng, "Xem tất cả", **411dp với tên dài**, và khối xu hướng: sáu nhãn tháng lấy từ dữ liệu, chú giải Thu/Chi, chuỗi rỗng không nổ, 411dp với số hàng trăm triệu |

Lát 2b thêm vào `thong_ke_thang_test.dart` sáu ca cho `chuoiTheoThang`: thứ tự
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
- **2c‑2 — nút "Tải xuống" sinh tệp thật.** Hiện đang **tắt** có chủ ý. Định
  dạng chốt sau: CSV rẻ (tự viết chuỗi, chỉ cần một thư viện chia sẻ tệp), PDF
  cần `pdf` + một font có dấu tiếng Việt — font mặc định của thư viện **mất
  dấu im lặng**. Giao diện đã có ô chọn PDF/CSV và màn Xem trước đã mang đủ số
  liệu, nên lát này chỉ còn phần sinh tệp và nơi lưu.
- **Tổng kết tuần** — spec `2026-09-07-weekly-summary-notification-design.md`
  chờ một **màn phạm vi tuần**. Tầng tổng hợp đã có (`tongThuChi` nhận biên bất
  kỳ); còn thiếu giao diện — có thể là một chế độ "tuần" của chính trang này.
- Tiêu đề trang là "Thống kê", tab dưới là "Phân tích" — hai tên cho một chỗ,
  lấy từ Stitch. Chưa đổi vì chưa ai nói tên nào đúng.
