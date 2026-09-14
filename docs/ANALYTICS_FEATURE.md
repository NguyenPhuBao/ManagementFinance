# Trang Phân tích — thiết kế, lý do, và những cái bẫy

**Cập nhật:** 2026-09-14 (mục **3.19** — A8 #3, #7: cơ cấu theo danh mục với ba chip nhóm, và xu hướng tới 5 danh mục cùng lúc; bản thi công **lần hai**, #2 đã bỏ) · bản trước 2026-09-13
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
| Đụng giao diện | Màn Stitch **`c8567243…`** *"Thống kê - Cơ cấu danh mục & Xu hướng 6 tháng"* (2026-09-14, bản lần hai) — ⚠️ **hai** màn cũ đã lỗi thời và vẫn còn trong dự án: `c2a2b615…` (tả A8 #2 đã bỏ: mức gốc ba lát + dropdown) và `a228fa69…` "FlowMoney Analytics Dashboard"; và mục 4.4 về font của bộ test |
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

Phần test không mất gì: **phép tính nằm trọn ở `chuoiTheoThang()` tầng domain**
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

Khối "Xu hướng 6 tháng" nhận một **hàng chip cuộn ngang, chọn nhiều**: tập rỗng
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

1. **Stream phát lại làm mất lựa chọn.** `watchThang` phát lại mỗi khi giao
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

Gọi `chuoiTheoThang` một lần cho mỗi danh mục là `số danh mục × soThang` lượt
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
*"Thống kê - Cơ cấu danh mục & Xu hướng 6 tháng"*, sinh ra từ lượt `edit_screens`
lúc 21:35 ngày 2026-09-14.

⚠️ **Lượt ấy suýt bị kết luận là thất bại, và câu chuyện đáng đọc trước khi bạn
gọi `edit_screens` lần sau.** Công cụ trả về thành công kèm `dom_operations`
khẳng định nó `replace_element` **tại chỗ** trên màn `c2a2b615…`; tôi nghiệm thu
bằng `get_screen` đúng màn ấy **năm lần** rải suốt phiên, lần nào cũng ra bản cũ,
rồi kết luận là lượt gọi "không có hiệu lực". Sai: nó đã **tạo một màn mới**.
`screen_id` trong kết quả trả về **không phải** nơi thay đổi đáp xuống, và
`get_screen` trên màn được chọn **không bao giờ** là phép nghiệm thu đủ — màn đó
thật sự không bị đụng tới. Phép đúng là **so `list_screens` trước và sau** khi
gọi; đây đã là **lần thứ hai** công cụ hành xử như vậy.

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
nào báo — cùng bẫy với `chuoi` của `ThongKeThang`. Riêng **tổng số dư** thì lấy
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
| `thong_ke_thang_test.dart` | Biên tháng (tháng 12, **năm nhuận**, tháng 2 thường), biên `to` mở, loại `transfer`, % với tháng trước = 0, gom danh mục và sắp ổn định khi hoà, top‑4 + Khác (kể cả đúng 5), `rutGon` (làm tròn, bỏ `.0`), 12 tháng gần nhất cuộn qua năm trước |
| `analytics_repository_impl_test.dart` | Đổi hàng Drift → thuần, cách ly `idaccount`, ba chữ cho ba ca danh mục **kể cả xoá mềm giữ tên thật**, "% ngân sách" bám ngân sách đang chạy và **bỏ ngân sách hết hạn**, stream phát lại khi ghi thêm |
| `analytics_cubit_test.dart` | `null` không đoán tài khoản; tháng lấy từ `clock` và `now` đi xuống repository; đổi tháng huỷ đăng ký cũ; lỗi stream không nổ |
| `bao_cao_xuat_test.dart` | Tầng thuần của lát 2c: bốn phạm vi thời gian (**tháng 1 lùi sang năm trước**, quý IV, tuỳ chỉnh cộng một ngày, năm nhuận), lọc theo ví/danh mục, `'transfer'` bị loại khỏi **cả** tổng lẫn danh sách, gom danh mục, nhóm theo ngày mới-nhất-trước, báo cáo rỗng. Lát 2c‑1b thêm: `khoangKyTruoc` (**tháng lùi theo tháng, không trừ N ngày**; quý; tuỳ chỉnh), dòng tiền (trừ phần sau kỳ, `transfer` không làm lệch, lọc ví thì `null`), thu theo danh mục, phân bổ theo ví, số liệu nhanh (**chia cho số ngày CỦA KỲ**), top 5, và độ chia của biểu đồ đổi theo độ dài kỳ |
| `bao_cao_repository_impl_test.dart` | Tra tên ví/danh mục **kể cả hàng đã xoá mềm**, ba chữ cho ba ca danh mục, tiêu đề lấy ghi chú rồi mới tới tên danh mục, cách ly `idaccount`, giao dịch đã xoá mềm không vào báo cáo, danh sách cho bộ lọc chỉ lấy hàng còn sống; **dòng tiền dùng tổng số dư ví còn sống**, và ngân sách hết hạn không lên báo cáo |
| `luu_tep_platform_test.dart` | **Hợp đồng gọi** xuống Kotlin: đúng tên phương thức và đủ ba tham số (`ten`, `mime`, `bytes`); `khong_ho_tro` và `MissingPluginException` trả `null` để bên gọi lùi phương án; còn lỗi ghi **thật** thì ném lên chứ không nuốt |
| `xuat_tep_test.dart` | Nội dung tệp: CSV có **BOM**, dòng `sep=;`, CRLF, số nguyên thô mang dấu, thoát ngoặc kép và dấu phân cách, không có `transfer`, không bịa dòng tiền; PDF hợp lệ, **không rơi về Helvetica**, và báo cáo rỗng vẫn ra tệp. Tên tệp không mang ký tự cấm |
| `report_preview_page_test.dart` | Ba thẻ tổng, **khoảng hiện ngày cuối thật** (biên `to` mở), nhãn bộ lọc, bảng danh mục có %, nhóm ngày kèm tên ví, dấu +/−, trạng thái rỗng, **nút Tải xuống phải TẮT**, 411dp; và tám khối của 2c‑1b: dòng tiền (kèm dòng "suy ngược", và **biến mất khi lọc ví**), `▲ %` so kỳ trước, thu theo danh mục, ngân sách có nhãn "Vượt", phân bổ theo ví (**số 0 không mang dấu**), top 5, số liệu nhanh, và có `LineChart` |
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
  nhưng để đợt sau.
- **Mảng Phân tích đến đây là xong.** Việc tiếp theo trong thứ tự đã duyệt là
  **biểu đồ tiến độ mục tiêu** (hạng 1 mục 10.5 `GOAL_FEATURE.md`), nay rẻ hẳn
  vì khuôn biểu đồ đã có ở cả màn hình lẫn PDF.
- **Tổng kết tuần** — spec `2026-09-07-weekly-summary-notification-design.md`
  chờ một **màn phạm vi tuần**. Tầng tổng hợp đã có (`tongThuChi` nhận biên bất
  kỳ); còn thiếu giao diện — có thể là một chế độ "tuần" của chính trang này.
- Tiêu đề trang là "Thống kê", tab dưới là "Phân tích" — hai tên cho một chỗ,
  lấy từ Stitch. Chưa đổi vì chưa ai nói tên nào đúng.
