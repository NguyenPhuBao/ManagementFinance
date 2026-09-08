# Trang Phân tích — thiết kế, lý do, và những cái bẫy

**Cập nhật:** 2026-09-08
**Trạng thái:** lát **2a** xong — mọi con số trên trang là số thật từ SQLite.
Còn **2b** (biểu đồ theo thời gian) và **2c** (trang Xuất báo cáo, vẫn là số
cứng). Xem mục 7.

> Cùng mục đích với `GOAL_FEATURE.md`: giữ lại **vì sao**. Cái gì thì đọc mã và
> test là ra.

---

## 1. Đọc gì trước khi đụng vào

| Việc | Đọc |
|---|---|
| Bất cứ việc gì | Mục 3 (quyết định) và mục 4 (bẫy) |
| Sửa phép tính | `domain/thong_ke_thang.dart` và test của nó — **không** có CSDL, kiểm bằng danh sách |
| Sửa cách gộp dữ liệu | Mục 3.3 (mốc tra ngân sách) trước, rồi `data/analytics_repository_impl.dart` |
| Đụng giao diện | Màn Stitch **"FlowMoney Analytics Dashboard"** — bố cục lấy nguyên từ đó; và mục 4.4 về font của bộ test |
| Làm tiếp 2b / 2c | Mục 7 |

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

Donut hiện có là `SweepGradient` tự vẽ, nên **không cần thư viện biểu đồ** cho
lát này. Quyết định chọn thư viện lùi sang 2b, khi cần biểu đồ theo thời gian —
và **chọn một lần** cho cả biểu đồ tiến độ mục tiêu (mục 10.5
`GOAL_FEATURE.md`).

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

---

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
cho donut), và cùng danh sách ấy đã tra tên/biểu tượng/màu/ngân sách (cho bảng).
Widget **không cộng gì cả**.

---

## 6. Kiểm thử

| Tệp | Canh gì |
|---|---|
| `thong_ke_thang_test.dart` | Biên tháng (tháng 12, **năm nhuận**, tháng 2 thường), biên `to` mở, loại `transfer`, % với tháng trước = 0, gom danh mục và sắp ổn định khi hoà, top‑4 + Khác (kể cả đúng 5), `rutGon` (làm tròn, bỏ `.0`), 12 tháng gần nhất cuộn qua năm trước |
| `analytics_repository_impl_test.dart` | Đổi hàng Drift → thuần, cách ly `idaccount`, ba chữ cho ba ca danh mục **kể cả xoá mềm giữ tên thật**, "% ngân sách" bám ngân sách đang chạy và **bỏ ngân sách hết hạn**, stream phát lại khi ghi thêm |
| `analytics_cubit_test.dart` | `null` không đoán tài khoản; tháng lấy từ `clock` và `now` đi xuống repository; đổi tháng huỷ đăng ký cũ; lỗi stream không nổ |
| `analytics_page_test.dart` | Tháng từ đồng hồ (không còn "T6 2026"), ba thẻ, "% ngân sách"/"% tổng chi", donut + Khác + tâm rút gọn, rỗng, chọn tháng, "Xem tất cả", và **411dp với tên dài** |

Bốn bản sai có chủ ý đã dùng, mỗi cái làm đúng một test đỏ: biên đóng, bỏ lọc
hết hạn, bỏ huỷ đăng ký, và `categoryDao.watchAll` thay cho truy vấn kể cả xoá
mềm. Thêm một test tự cãi với lời giải thích của nó (thứ tự
khi hoà) — phát hiện nhờ chạy chứ không nhờ đọc.

---

## 7. Còn lại

- **2b — biểu đồ theo thời gian.** Chỗ chọn thư viện; chọn một lần cho cả biểu
  đồ tiến độ mục tiêu.
- **2c — trang Xuất báo cáo** (`export_report_page.dart`): vẫn số cứng — ví
  "Techcombank"/"Tiền mặt" và lịch sử xuất `BaoCao_Thang6.pdf` đều bịa; nút xuất
  chỉ hiện snackbar. Nay đã có `ThongKeThang` để đổ vào.
- **Tổng kết tuần** — spec `2026-09-07-weekly-summary-notification-design.md`
  đang chờ đúng tầng tổng hợp này.
- Tiêu đề trang là "Thống kê", tab dưới là "Phân tích" — hai tên cho một chỗ,
  lấy từ Stitch. Chưa đổi vì chưa ai nói tên nào đúng.
