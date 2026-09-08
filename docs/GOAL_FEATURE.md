# Mục tiêu tiết kiệm — thiết kế, lý do, và những cái bẫy

**Cập nhật:** 2026-09-08
**Trạng thái:** hoạt động đầy đủ trên client. **Không còn việc nào chờ backend**
(cập nhật 2026-09-07 — xem mục 8).

Mục **10** là đối chiếu với app khác trên thị trường: cái gì FlowMoney đã mạnh
hơn (và không nên "sửa"), cái gì còn thiếu, xếp hạng kèm lý do.

> **Mục đích của tài liệu này** giống `CATEGORY_RATIONALE.md`: giữ lại **vì sao**,
> không phải **cái gì**. Cái gì thì đọc mã và test là ra; vì sao thì mất theo
> phiên làm việc. Mọi quyết định dưới đây đều có một phương án khác nghe hợp lý
> hơn lúc đầu, và mục 3 ghi lý do loại nó.

---

## 1. Đọc gì trước khi đụng vào

| Việc | Đọc |
|---|---|
| Bất cứ việc gì | Mục 3 (quyết định + lý do) và mục 4 (**bảy cái bẫy**, hai đã đóng — 4.5 và 4.6) |
| Đụng vào nạp/rút tiền | Mục 3.1 → 3.4, và `goal_repository_impl.dart` — mọi chú thích ở đó là bản rút gọn của tài liệu này |
| Đụng vào lịch sử tích luỹ | **Bẫy 4.2** trước đã. Suy chiều tiền từ vị trí ví là sai, đã vấp |
| Đụng vào đồng bộ | **Bẫy 4.3**, rồi `sync_payload_contract_test.dart` |
| Đụng vào tiến độ / phần trăm | Mục 3.6 — chỉ có **một** định nghĩa và nó nằm trên `GoalEntity` |

---

## 2. Luồng dữ liệu, gọn trong một bảng

| Thao tác | Ghi gì xuống SQLite | Giao dịch sinh ra |
|---|---|---|
| Tạo mục tiêu | hàng `goals`, `startDate = now`, `walletId` bắt buộc, `cycleTakeMoney` | — |
| Nạp tiền | `current_amount +=`, hai ví đổi số dư | **một** hàng `type='transfer'`, ví nguồn → ví tích luỹ |
| **Trích tự động** (mỗi kỳ tới hạn) | y hệt nạp tiền, cộng `auto_deposit_last_run` | **một** hàng cho **mỗi kỳ**, không gộp |
| Rút tiền | `current_amount -=`, `is_completed` tính lại, hai ví đổi số dư | **một** hàng `type='transfer'`, ví tích luỹ → ví đích |
| Sửa mục tiêu | `name`, `target_amount`, `target_date`, `cycle_take_money`, `icon`, `colour`; `is_completed` **tính lại** | — |
| Đổi ví nhận | `wallet_id` — **chỉ khi `current_amount == 0`** | — |
| Xoá mục tiêu | xoá mềm `is_deleted` + `deleted_at` | — |

Nạp và rút đều nằm trọn trong một `db.transaction`. Chỉ `scheduleSync()` nằm
ngoài — xếp hàng đồng bộ cho một khối chưa commit là vô nghĩa.

---

## 3. Các quyết định, và phương án đã loại

### 3.1 Ví nhận là **bắt buộc** lúc tạo, và **khoá** sau khoản nạp đầu tiên

Mục tiêu luôn phải có ví nhận, vì mỗi lần nạp tiền chuyển thẳng vào ví ấy —
không có nó thì phiếu nạp không biết đưa tiền đi đâu. Trang tạo chặn hẳn nếu
người dùng chưa chọn.

Sau khoản nạp đầu tiên thì **không đổi ví được nữa**.

**Vì sao khoá:** tiền đã tích được đang nằm THẬT trong ví ấy. Đổi ví mà không
chuyển tiền theo thì mục tiêu báo 2 triệu trong khi số ấy nằm rải ở ví khác —
càng đổi càng phân mảnh, và không có gì trong app lần lại được tiền của một mục
tiêu đang nằm ở những đâu.

**Phương án đã loại:** *đổi ví thì chuyển luôn số đã tích* (sinh một giao dịch
chuyển khoản thật). Nghe gọn hơn, nhưng nó vỡ đúng lúc cần nhất — khi ví cũ
không còn đủ tiền vì người dùng đã tiêu vào đó. Lúc ấy phải chọn giữa chặn (kẹt)
và chuyển một phần (lại phân mảnh).

**Ngoại lệ có chủ ý:** mục tiêu **chưa có ví nào** thì gắn được dù đã tích tiền.
Mục tiêu do bản app cũ tạo có thể vừa thiếu ví vừa có tiền; chặn cả ca ấy là
chúng kẹt vĩnh viễn — không nạp thêm được mà cũng không gắn được ví.

**Hệ quả phải chấp nhận:** ví đang giữ tiền của một mục tiêu thì không xoá được.
Điều đó **đúng** — tiền đang ở trong đó thật. Câu báo lỗi khi xoá ví chỉ đúng
chỗ thoát: mở mục tiêu, đổi sang ví khác (chỉ được khi chưa tích gì), rồi xoá.

### 3.2 Nạp tiền ghi **MỘT** giao dịch `'transfer'`, không phải cặp `chi`/`thu`

Một lần nạp là chuyển tiền giữa hai ví của **cùng một người dùng**. Ghi thành
`'chi'` làm phần thống kê đếm nó thành chi tiêu thật, trong khi tiền chỉ đổi chỗ.

Hàng mang cả `walletId` (nguồn) lẫn `walletTransfer` (đích).

> Tính năng giao dịch **thường** cũng dùng `type='transfer'` cho chuyển khoản,
> nhưng nó **không điền** `walletTransfer` — `TransactionEntity` không có trường
> tương ứng, ví đích chỉ dùng để cộng trừ số dư rồi bỏ. Goal làm **đầy đủ hơn**,
> không phải lệch đi.

### 3.3 Chiều nạp/rút đọc từ **tiền tố ghi chú**, không từ vị trí ví

Nạp và rút đều là `'transfer'` mang cùng `goal_id`, nên `type` không phân biệt
được. Cách hiển nhiên là so ví: nạp thì ví tích luỹ là ĐÍCH, rút thì nó là NGUỒN.

**Cách ấy sai**, và đã vấp trên máy ảo ngày 2026-09-05 — xem bẫy 4.2.

Thay vào đó, `goal_history_direction.dart` khai hai hằng số
(`kGhiChuNapMucTieu`, `kGhiChuRutMucTieu`) dùng chung cho **cả nơi ghi lẫn nơi
đọc**. Tiền tố nằm trong hàng, đi qua được đồng bộ, và không đổi khi cấu hình
mục tiêu đổi.

> Đây **khác** với việc so *tên mục tiêu* trong ghi chú — thứ mà cột `goal_id`
> sinh ra để thay thế. Tên là dữ liệu người dùng đặt và không duy nhất; hai tiền
> tố này là hằng số của mã nguồn.

Vị trí ví vẫn dùng làm **phương án dự phòng** cho hàng không mang tiền tố nào
nhận ra được.

### 3.4 Tiến độ **không** tự hoà giải với số dư ví — chỉ cảnh báo

Tiêu tiền từ ví tích luỹ bằng một giao dịch thường **không** hạ tiến độ mục
tiêu: giao dịch ấy không mang `goal_id`. Nên hai con số lệch nhau được.

App **không tự sửa**, vì không đủ căn cứ để sửa đúng:

- một ví có thể phục vụ **nhiều mục tiêu** — trừ vào cái nào?
- ví tích luỹ cũng chứa tiền không thuộc mục tiêu nào — khoản chi có thể ăn đúng
  vào phần dư ấy;
- tự hạ tiến độ là bất ngờ: mua ly cà phê từ ví tiết kiệm mà mục tiêu mua xe lùi
  lại một bậc, không ai hỏi han gì.

Đây là **mô hình phong bì**: phong bì nói ý định, tài khoản nói thực tế, lệch
nhau thì báo cho người dùng quyết. `canhBaoViKhongDu()` so số dư ví với **tổng
của mọi mục tiêu** trỏ vào ví đó — cộng dồn chứ không so lẻ, vì ba mục tiêu dùng
chung một ví thì từng cái đều thấy "đủ tiền" trong khi cộng lại thì thiếu.

✅ **Đã xem trên máy ảo Android 2026-09-05.** Hàm có 6 test từ lâu nhưng phần vẽ
chưa bao giờ gặp ca dữ liệu để hiện. Dựng đúng ca thật — một khoản **chi tiêu
thường** 1,5 triệu từ chính ví tích luỹ, đưa ví xuống 700.000 trong khi mục tiêu
ghi nhận 1.200.000 — thì dải hiện đủ ba dòng ở khổ 411dp, không tràn, hai con số
khớp CSDL. Đây là ca duy nhất sinh ra được nó: nạp và rút đều đi qua mục tiêu nên
chúng luôn khớp.

### 3.5 Rút tiền kiểm **hai** trần, và **gỡ** cờ hoàn thành

| Trần | Vi phạm thì sao |
|---|---|
| `amount ≤ current_amount` | tiến độ xuống âm, tiền lấy ra từ hư không |
| `amount ≤ số dư THẬT của ví tích luỹ` | ví về số dư âm |

Hai trần này khác nhau, và chính chỗ lệch giữa chúng là hiện tượng ở mục 3.4.
Bỏ trần thứ hai là tạo tiền từ hư không.

Rút xuống dưới mục tiêu thì **gỡ** `is_completed`. Giữ cờ thì `_goalCandidates`
bỏ qua mục tiêu này vĩnh viễn — rút gần hết mà nó không bao giờ nhắc "chậm tiến
độ" nữa, đúng loại hỏng lặng lẽ. Chúc mừng lần hai đã được khoá khử trùng
(`goalDone:<id>`) chặn trong 90 ngày.

### 3.6 Tỉ lệ tiến độ có **đúng một** định nghĩa

`GoalEntity.progress` là nguồn duy nhất. Widget `GoalProgressBar` /
`GoalProgressRing` và hàm `goalPercentLabel` nhận thẳng **`GoalEntity`** chứ
không nhận `double` — nơi gọi không còn chỗ nào để tính ra một con số khác.

**Vì sao gắt vậy:** trước đây trang danh sách và trang chi tiết mỗi nơi tự tính
`targetAmount > 0 ? current/target : 0.0`, lệch với entity đúng ở mục tiêu 0
đồng (entity trả `1.0`, hai trang trả `0.0`). Kết quả: thông báo chúc mừng "đã
hoàn thành" trong khi màn hình hiện 0%.

### 3.7 Dự báo tính từ **nhịp thật**, chu kỳ đã cài chỉ là kế hoạch

`targetDate` được tính MỘT LẦN lúc tạo từ chu kỳ người dùng nhập, rồi đóng băng
thành hạn chót. Nhưng **không có bộ lập lịch nào trích tiền** — người dùng nạp
tay, số bất kỳ, lúc bất kỳ.

`goal_forecast.dart` dựng lại nhịp thật từ số đã tích được:

```
tocDoThucTe    = current_amount / số ngày từ startDate → quy về mỗi chu kỳ
tocDoKeHoach   = phần CÒN THIẾU / số ngày còn lại → quy về mỗi chu kỳ
duBaoHoanThanh = hôm nay + (còn thiếu / tốc độ thật mỗi ngày)
```

`cycleTakeMoney` được **lưu** để hiển thị hai con số theo cùng một đơn vị ("cần
3 triệu mỗi tháng · đang tích 1,2 triệu mỗi tháng"). Trước đây lựa chọn ấy chỉ
dùng để tính ngược ra ngày hạn rồi bị vứt bỏ.

Mọi hàm trả `null` khi **không đủ căn cứ**, cùng nguyên tắc với
`isBehindSchedule`: im lặng đúng hơn là báo bừa.

⚠️ **"Không đủ căn cứ" gồm cả CỬA SỔ QUÁ NGẮN** (sửa 2026-09-08). Trước đó
phép chặn duy nhất là `soNgayDaQua <= 0`, tức nó chỉ đỡ được phép chia cho 0
chứ không đỡ được việc **bịa ra một nhịp**. Đo trên máy thật: mục tiêu tạo
05/09, xem 08/09, đã tích 1.101.000 đ, chu kỳ tháng → màn hình hiện *"đang tích
**11.010.000 đ** mỗi tháng"*, gấp mười lần tổng đã tích được cả đời mục tiêu,
kèm dự báo hoàn thành ngay tháng ấy cho một mục tiêu hạn 2028.

`_duCuaSo` nay đòi **ít nhất nửa chu kỳ**: `soNgayDaQua * 2 >= soNgayChuKy`.
Ngưỡng tính **theo chu kỳ**, không phải một số ngày cứng — chu kỳ *ngày* không
có ngoại suy nào để chặn (hệ số bằng 1) nên ngưỡng cứng sẽ bắt nó im lặng vô
cớ, còn chu kỳ *năm* thì hai tháng vẫn là hệ số 6. Nửa chu kỳ đưa hệ số phóng
đại tối đa về **2**; đợi trọn một chu kỳ thì mục tiêu hàng tháng câm suốt tháng
đầu, mà tháng đầu mới là lúc người dùng mở ra xem nhiều nhất.

Phép chặn phải áp cho **cả** `tocDoThucTe` lẫn `duBaoHoanThanh` — hai dòng cạnh
nhau trên màn hình đọc như một câu, chặn một chỗ mà để chỗ kia nói tiếp thì hộp
dự báo vẫn sai, chỉ sai gọn hơn. `tocDoKeHoach` **không** chịu phép chặn này:
nó chia phần còn thiếu cho số ngày còn lại, tức một *kế hoạch*, không phải một
ước lượng từ quá khứ.

### 3.8 Nạp vượt mục tiêu thì **nhắc**, không chặn

Tiết kiệm dư là chuyện bình thường — gửi tròn số, hoặc gộp luôn khoản tháng sau.
Chặn lại biến một thao tác hợp lệ thành lỗi. Nhưng im lặng cũng sai: nạp nhầm
một số 0 thì tiền đã rời ví và người dùng chỉ phát hiện khi xem lại số dư.

`canhBaoNapVuot()` hiện câu nhắc **sống động** ngay dưới ô nhập, và vẫn nạp đủ
số người dùng gõ.

---

### 3.9 Trang sửa dùng CHUNG biểu mẫu với trang tạo

`GoalAddPage` nhận thêm `goalId` tuỳ chọn; có nó là chế độ sửa. Cùng lối mà
thiết kế Stitch đặt cho danh mục ("Thêm / Chỉnh sửa danh mục con"). Tách thành
hai trang thì hai bản sao của cùng một biểu mẫu sẽ trôi xa nhau — sửa nhãn ở
một bên, quên bên kia.

Chế độ sửa **không** động tới ví tích luỹ: ô ấy chỉ đọc và trỏ về nút đổi ví ở
trang chi tiết, nơi đặt phép khoá của mục 3.1. Nhân đôi luật khoá sang biểu mẫu
là tự chuốc hai luật lệch nhau. `updateGoal` ở tầng dữ liệu cũng **không nhận**
`currentAmount` lẫn `walletId`, nên không có đường nào đi vòng qua.

Cờ hoàn thành **tính lại** theo mục tiêu mới, cùng luật với mục 3.5: hạ mục tiêu
xuống dưới số đã tích thì bật, nâng lên trên thì gỡ.

Ba chi tiết dễ hỏng lặng lẽ, mỗi cái có test canh:

- **Thứ tự điền sẵn.** `_targetDate` và `_frequency` phải đặt **trước** khi gán
  số tiền. Hai ô số tiền và hạn định nối nhau bằng cặp listener tính chéo — gán
  tiền trước thì listener tính ra một hạn mới từ hạn mặc định "một năm nữa" và
  ghi đè lên hạn thật, ngay trước mắt người dùng.
- **`showDatePicker` với mục tiêu quá hạn.** `initialDate` trước `firstDate` là
  **assertion**, tức màn đỏ ngay khi bấm vào ô hạn định — và nó rơi trúng đúng
  những mục tiêu cần sửa nhất. `ngayNhoNhatChoLich` lùi `firstDate` về ngày hạn
  cũ khi cần.
- **`null` mang hai nghĩa khác nhau.** `cycleTakeMoney: null` là **xoá** (tắt
  công tắc trích tiền định kỳ phải bỏ được kế hoạch cũ), còn `icon`/`colour`
  `null` là **giữ nguyên** — hai cột ấy không có trạng thái "không có", gán đại
  sẽ đưa mọi mục tiêu về lá cờ xanh sau một lần sửa tên.

### 3.10 Biểu tượng và màu: bảng tra không chứa giá trị dự phòng

`kBieuTuongMucTieu` **cố ý không có `'flag'`**, dù đó là mặc định của CSDL. Lá
cờ là giá trị dự phòng của `bieuTuongMucTieu`, nên nếu nó nằm trong bảng chọn
thì phép kiểm "mọi lựa chọn đều tra được" mất hết ý nghĩa: một tên gõ sai vẫn ra
lá cờ và trông như đúng.

Hệ quả: mục tiêu cũ mang `'flag'` có một giá trị ngoài bảng.
`danhSachBieuTuong()` **chèn nó vào đầu** thay vì bỏ qua (trang sửa mở ra không
ô nào được tô, người dùng tưởng chưa từng chọn) hay tự nhảy sang ô đầu (đổi biểu
tượng sau lưng người dùng chỉ vì họ vào sửa cái tên).

`mauMucTieu()` **không bao giờ ném** — nó chạy trong `build()`, nên một ngoại lệ
ở đó là màn đỏ kéo sập cả trang danh sách chứ không riêng thẻ có dữ liệu hỏng.

### 3.11 Trang danh sách chỉ nói những gì app biết chắc

Thẻ "Tốc độ tiết kiệm của bạn đã tăng 12% so với tháng trước" là một con số cố
định chép từ mockup, kèm nút "Xem báo cáo" có `onPressed: () {}`. Nay chỗ ấy là
tổng số mục tiêu, tổng đã tích và tổng đích — **lấy thẳng từ `GoalLoaded`**,
không tính lại, cùng nguyên tắc một-định-nghĩa với mục 3.6.

Cùng đợt: bỏ huy hiệu **PREMIUM** (app không có gói trả phí nào), dấu **ba
chấm** trên thẻ (không mở menu nào — mọi thao tác nằm ở trang chi tiết), và nút
**"Xem tất cả"** ở lịch sử tích luỹ (danh sách vốn đã hiện toàn bộ, nên nó vừa
không làm gì vừa ngụ ý sai rằng có phần bị giấu).

Trang chi tiết trước đây **không nghe dòng dữ liệu** (bẫy 4.5, đóng 2026-09-08)
nên phải tự `_loadGoal()`
sau khi trang sửa đóng. Việc đó dựng lại dòng lịch sử tích luỹ, và
`StreamBuilder` quay về trạng thái chưa có dữ liệu — trộn ca ấy với "rỗng thật"
làm lịch sử **nháy thành "Chưa có khoản tích lũy nào"** rồi hiện lại, trông y
như vừa mất dữ liệu. Đã phân biệt bằng `connectionState`.

### 3.12 Trích tiền tự động: chạy trong vòng quét, không phải bộ lập lịch nền

Trước bản này, khối "Tự động trích tiền định kỳ" thu **ba** thông tin và lưu
đúng **một**: chu kỳ vào `cycle_take_money`, còn số tiền mỗi kỳ chỉ dùng để tính
ngược ra hạn định rồi bị vứt, và ví nguồn thì không hề đi vào `addGoal`. Nút bấm
lại ghi "Tạo Mục Tiêu & **Bật Lập Lịch Tự Động**" — một lời hứa về chức năng
không tồn tại.

Nay ba mảnh ấy đều được lưu (ba cột, mục 5 — **đã đồng bộ từ 2026-09-07**), và
`GoalAutoDepositRunner` chạy các kỳ đã tới hạn.

**Nơi chạy là `NotificationScanner.scan()`**, tức mỗi khi một chu kỳ đồng bộ kết
thúc — không phải WorkManager. Các kỳ bỏ lỡ được **trích bù** theo đúng thứ tự
khi app mở lại, nên không kỳ nào mất; chúng chỉ xảy ra muộn hơn mốc lý thuyết.
Đổi lại, việc chuyển tiền luôn nằm trong tiến trình chính và dùng chung một kết
nối CSDL. Một isolate nền mở kết nối thứ hai vào cùng tệp SQLite **để chuyển
tiền** là loại rủi ro không đáng đánh đổi lấy vài giờ sớm hơn.

**Đi qua `depositToGoal`, không tự ghi.** Một lần trích phải làm đúng bốn việc
của một lần nạp trong một `db.transaction`. Viết lại chuỗi ấy là tạo bản sao thứ
hai của định nghĩa "nạp tiền là gì", và bản sao sẽ lệch đi ở lần sửa sau. Hệ quả
tốt: khoản trích tự động dùng **đúng tiền tố ghi chú** của khoản nạp tay, nên
`laKhoanRutKhoiMucTieu` vẫn đọc đúng chiều (bẫy 4.2).

**Sáu quyết định về việc dừng lại đúng lúc:**

| Tình huống | Xử lý | Vì sao |
|---|---|---|
| Vừa bật công tắc | Mốc chạy = **lúc bật** | Lấy ngày tạo mục tiêu là bật hôm nay rồi bị trích ngược lại từng ấy kỳ cùng lúc |
| Sửa tên / đổi số tiền | **Không** đặt lại mốc | Đặt lại ở mỗi lần lưu thì người sửa mục tiêu hàng tháng không bao giờ tới kỳ |
| Tắt công tắc | Xoá **cả ba** cột | Giữ mốc lại thì bật lần sau tính bù cả quãng đang tắt |
| Còn thiếu < số cài | Trích **đúng phần còn thiếu** | Nạp vượt bằng tay chỉ *cảnh báo* vì người dùng đang nhìn; ở đây họ vắng mặt |
| Ví nguồn không đủ | **Bỏ kỳ**, giữ mốc, báo cảnh báo | Trích một phần làm một kỳ ra hai con số; giữ mốc thì kỳ ấy tự thử lại khi có tiền |
| Bỏ app rất lâu | Trần **12 kỳ** mỗi lượt | Chu kỳ ngày, máy để lâu, là hàng nghìn kỳ — trích hết một lượt sẽ rút cạn ví ngay khi mở app. Phần dư không mất, nó ở lại lượt sau |

### 3.13 Mốc neo: người dùng chọn thời điểm cụ thể trong chu kỳ

Bản đầu neo nhịp vào **lúc bấm công tắc** — bật lúc 14 giờ ngày 5 thì mọi kỳ
sau rơi vào ngày 5 lúc 14 giờ. Nay người dùng chọn được "ngày 15 hàng tháng lúc
08:00", và lựa chọn ấy lưu ở **`timeCycleTakeMoney`**.

**Vì sao là cột đó chứ không phải một cột cục bộ thứ tư:** tên nó vốn có nghĩa
là *"thời điểm cụ thể trích tiền trong chu kỳ"*, nó đã nằm sẵn trong 18 khoá (nay là 19) của
payload mục tiêu, và client chưa bao giờ ghi. Đây là dùng đúng nghĩa gốc, khác
hẳn việc mượn nó làm mốc-đã-chạy (thứ đã bị loại ở mục 3.12). Phía backend chỉ
lưu và trả lại qua `sync.repository.js`, **không có cron nào đọc** — nên không
sinh nguy cơ trích hai lần.

Cách chia này cũng nhất quán: **kế hoạch** (chu kỳ + mốc neo) đồng bộ theo người
dùng sang máy khác, **trạng thái thi hành** (số tiền, ví nguồn, đã trích tới
đâu) ở lại máy này.

**Hai mốc, hai vai trò, và cần cả hai:**

| | Vai trò | Thiếu nó thì sao |
|---|---|---|
| `timeCycleTakeMoney` | **nhịp** — kỳ rơi vào lúc nào | Lựa chọn của người dùng không có tác dụng nào, im lặng |
| `autoDepositLastRun` | **sàn** — đã trích tới đâu | Chọn "ngày 1" vào ngày 5 sẽ trích bù ngay cho mùng 1 vừa qua |

⚠️ **Giờ chỉ giữ được MỘT chiều.** Bộ trích chạy khi app mở (mục 3.12), nên đặt
08:00 nghĩa là *không bao giờ sớm hơn 08:00* — nhưng nếu 21 giờ mới mở app thì
nó trích lúc 21 giờ. Biểu mẫu nói thẳng điều này ngay dưới ô chọn giờ thay vì để
người dùng tự phát hiện.

✅ **Nhịp neo vào mốc gốc, không trôi** (sửa 2026-09-08). Mốc rơi vào ngày 31 bị
kẹp về 28/02 ở tháng ngắn — đúng — nhưng kỳ sau **quay lại ngày 31**:

```
31/01 → 28/02 → 31/03 → 30/04 → 31/05
```

Bản trước bước **từng kỳ một** từ mốc trước đó, nên sau khi kẹp xuống 28 nó bước
tiếp *từ 28* và nhịp tụt vĩnh viễn, hoàn toàn im lặng. Nay mọi mốc tính từ mốc
gốc qua `mocThuN(goc, chuKy, n)` — cùng khuôn `advancePeriodFrom(anchor, steps)`
bên ngân sách và `anchorDay` bên hoá đơn, nên ba vùng ngày tháng của app nói
cùng một thứ tiếng.

Mốc gốc là `timeCycleTakeMoney` (lựa chọn của người dùng). Mục tiêu bật trước
khi có ô chọn ấy thì gốc rơi về `autoDepositLastRun`, tức giữ nguyên hành vi cũ.

⚠️ `kyKeTiep` — dùng để đặt lịch nhắc trước — phải dùng **đúng phép dựng mốc
này**. Hai bên trôi khác nhau là điện thoại nhắc một ngày còn tiền bị trừ vào
ngày khác.

### Lời nhắc khi app đóng

Bộ trích chỉ chạy khi app mở, nên tới đúng mốc kỳ mà app đang đóng thì **không
có đồng nào rời ví lúc đó** — kỳ ấy được trích bù ở lần mở kế tiếp.

`ReminderScheduler` thu hẹp khoảng cách ấy: nó đặt **trước** một thông báo vào
đúng mốc kỳ qua AlarmManager (Android) / UNUserNotificationCenter (iOS), thứ nổ
được cả khi tiến trình app đã chết. Người dùng chạm vào là app mở và khoản trích
chạy ngay tại đó. Không phải tự động hoàn toàn, nhưng **thời điểm thì đúng** và
không ai phải nhớ.

Nó dùng chung bộ đặt lịch với nhắc hoá đơn — bắt buộc, xem
`NOTIFICATION_FEATURE.md`. Chỉ đặt cho **kỳ sắp tới** (`kyKeTiep`), cố ý bỏ qua
những kỳ đã tới hạn mà chưa trích: đặt lịch vào quá khứ thì Android bắn ngay còn
iOS lặng lẽ bỏ, và những kỳ ấy dù sao cũng được trích bù ở lượt quét kế tiếp.

⚠️ **Mốc neo đi qua đường đồng bộ** nên có thể mang giá trị rác từ Admin-web.
`cacKyDenHan` có trần 1000 vòng khi dò từ mốc neo tới kỳ đầu còn hiệu lực: bước
từng ngày từ năm 1990 là hàng chục nghìn vòng lặp ngay trong vòng quét thông
báo — app treo. Vượt trần thì bỏ qua và im lặng.

**Ba cột kia nay đã đồng bộ** (2026-09-07, G21 đóng): backend đã có
`auto_deposit_amount` / `auto_deposit_wallet_id` / `auto_deposit_last_run`, và
client đẩy **cả ba cùng một lúc**. Bật trích ở máy này thì máy kia nhận đủ cấu
hình **lẫn mốc kỳ gần nhất**, nên nó không trích lại kỳ vừa xong.

⚠️ Đúng một khe hở còn lại: hai máy cùng mở, cùng tới kỳ, cùng chưa kịp kéo
`last_run` của nhau thì vẫn trích hai lần. Hẹp, vì trích chỉ chạy khi app mở và
`Current_amount` là giá trị tuyệt đối nên LWW hội tụ chứ không cộng dồn sai. Vá
triệt để cần khoá phía máy chủ trên `(Idgoal, kỳ trích)`.

Đây cũng là lý do KHÔNG mượn cột `time_cycle_take_money` đang có sẵn:
nó dùng chung với backend/Admin-web, và đổi ý nghĩa một cột dùng chung mà phía
kia chưa đồng ý là cách hỏng im lặng nhất.

⚠️ **Migration v15 cố ý không bật cho mục tiêu cũ.** Trang tạo của mọi bản trước
đều BẬT SẴN công tắc và luôn lưu chu kỳ, nên gần như mọi mục tiêu cũ đều mang
một `cycle_take_money`. Suy ra "đã đồng ý cho trích tự động" từ đó là bắt đầu
chuyển tiền dựa trên một lựa chọn người dùng chưa từng đưa ra.

---

### 3.14 Khoản trích **bù** mang mốc của kỳ, không phải lúc bù

Bỏ app ba kỳ thì ba kỳ được trích bù trong cùng một lượt quét. Bản trước ghi cả
ba hàng với `DateTime.now()`, nên thống kê **theo ngày** thấy một cột dựng đứng
ở ngày mở app — trong khi trung tâm thông báo, vốn lấy mốc kỳ làm `createdAt`,
hiện đúng ba ngày. Hai nơi nói hai chuyện khác nhau về cùng một sự việc.

`depositToGoal` nhận thêm `occurredAt`. Vì đây là **tầng ghi tiền**, một tham số
ngày để trống chính là cửa sau, nên nó bị chặn **hai đầu**:

| Chặn | Vì sao |
|---|---|
| Không ở **tương lai** | Một khoản nạp không thể mang dấu thời gian chưa tới |
| Không trước `startDate` của mục tiêu | Bịa về quá khứ cũng là bịa; khoản nạp sẽ rơi xuống đáy lịch sử ở chỗ mục tiêu còn chưa ra đời |

Bộ trích tự động không bao giờ chạm hai đầu ấy: `cacKyDenHan` sinh mốc nằm **sau**
`auto_deposit_last_run` (đặt lúc bật công tắc, tức sau `startDate`) và **không
sau** `now`. Đường nạp tay không truyền tham số, và `GoalCubit` **cố ý không phơi
nó ra** — nơi gọi duy nhất là `GoalAutoDepositRunner`.

⚠️ Chỉ cột `date` lùi lại. **`updatedAt` vẫn là "bây giờ"** vì nó là sổ sách đồng
bộ, không phải ngày của sự việc; lùi nó theo sẽ làm phép phân xử LWW coi bản ghi
cũ hơn thực tế và ghi đè mất chính khoản vừa trích.

**Hệ quả thấy được:** lịch sử tích luỹ (`orderBy: date desc`) **sắp xếp lại** —
khoản bù xen vào đúng ngày của nó thay vì dồn lên đầu. Đã kiểm trên máy ảo
2026-09-05: ba kỳ bù ghi lúc 17:30 mang `date` 06/07/08-09 lúc 08:00 và cùng một
`updated_at` 17:30, và danh sách hiện đúng thứ tự xen kẽ với các khoản nạp tay.

> ⚠️ **Bẫy khi viết test cho vùng này.** Runner nhận `now` tiêm vào, còn
> `depositToGoal` đọc `DateTime.now()` — ở production hai thứ ấy là **một** đồng
> hồ. Bộ test cũ giả lập kịch bản ở **tương lai** (`now: 2026-12-06`), một tiền
> đề không xảy ra được ngoài đời, và nó vỡ ngay khi phép chặn đầu trên ra đời.
> Nay cả `goal_auto_deposit_runner_test.dart` nằm trong **quá khứ**; ngày quá khứ
> thì mãi mãi vẫn là quá khứ nên cách này không hết hạn.

---

### 3.15 Tên mục tiêu là **duy nhất** trong phạm vi một tài khoản

Không phải để danh sách cho gọn. `TransactionDao.watchByGoal` nối lịch sử bằng
`goal_id` cho hàng mới, nhưng vẫn giữ **nhánh dự phòng** tra bằng `LIKE` trên ghi
chú `"Tích lũy mục tiêu: <tên>"` — nhánh duy nhất tìm lại được hàng do bản app cũ
tạo và **mọi hàng kéo về từ server** (`goal_id` là cột cục bộ, xem bẫy 4.4). Hai
mục tiêu trùng tên thì cả hai cùng nhận vơ đúng những hàng ấy.

Ba lựa chọn **giống hệt danh mục**, và giống vì cùng một lý do:

- **So tên bằng `normalizeCategoryName()`** ở `lib/core/category/category_name.dart`
  — định nghĩa so tên duy nhất của dự án. Đừng viết biến thể khác, và tuyệt đối
  đừng dùng `removeVietnameseTones()`: bỏ dấu là phép so *mất thông tin*.
- **Hàng đã xoá mềm KHÔNG giữ chỗ** (`goalDao.getAll` đã lọc `deleted_at`). Giữ
  chỗ thì người dùng xoá rồi không tạo lại được bằng chính cái tên ấy mà cũng
  không thấy gì đang chiếm chỗ.
- **Chỉ xét khi tên thật sự đổi.** Máy người dùng có thể đang giữ sẵn hai mục
  tiêu trùng tên do bản client trước tạo; chặn tuyệt đối là chúng kẹt vĩnh viễn,
  không sửa nổi cả số tiền lẫn biểu tượng.

Thi hành ở `GoalRepositoryImpl._trungTen()`, nối vào **cả `addGoal` lẫn
`updateGoal`** — chặn mỗi đường tạo thì tạo hai tên khác nhau rồi đổi một cái
thành cái kia là đi vòng qua trọn vẹn quy tắc.

**Phạm vi:** client. Đường `/sync/push` và CSDL PostgreSQL **chưa kiểm gì cả** —
cùng tình trạng với danh mục.

Câu lỗi đi qua `GoalValidationException` (mẫu của `CategoryValidationException`)
chứ không phải `ArgumentError`, vì nó ra thẳng snackbar qua `e.toString()`:
`ArgumentError` hiện thành `Invalid argument (name): <câu tiếng Việt>: "<giá trị>"`.

---

### 3.16 `depositToGoal` kiểm số tiền ở **tầng repository**, không chỉ ở form

Ô nhập của trang chi tiết đã chặn từ lâu, nhưng phép kiểm nằm một mình trên giao
diện thì mọi đường gọi khác đi vòng qua được — **và nó nằm NGOÀI khối nguyên tử**,
tức không phải chỗ giữ bất biến. Hai trần nay nằm trong `db.transaction`:

| Trần | Không có nó thì |
|---|---|
| `depositAmount > 0` | Nạp 0 đồng đẻ ra một hàng giao dịch rỗng; nạp **số âm** chạy trót lọt tới cuối — ví nguồn được **CỘNG** tiền trong khi tiến độ mục tiêu tụt xuống |
| `depositAmount ≤ số dư ví nguồn` | Repository trừ thẳng và ví nguồn xuống **âm**: mục tiêu tích được một số tiền chưa từng tồn tại |

Trần thứ hai là bản đối xứng của trần "tiền THẬT trong ví" mà `withdrawFromGoal`
đã có (mục 3.5). Trần là **vượt quá**, không phải **bằng** — dồn sạch một ví vào
mục tiêu là thao tác hợp lệ.

Kèm theo, `GoalCubit.addGoal` nay trả `String?` như `updateGoal`. Trang tạo gọi
`.then(...)` rồi đóng ngay, nó **không đọc trạng thái cubit**; bản trước chỉ phát
`GoalError` nên một mục tiêu bị từ chối vẫn hiện thông báo "thành công" rồi đóng
trang, và người dùng mất hết những gì vừa gõ.

---

### 3.17 Lặp lại mục tiêu: app **nhắc**, người dùng bấm

Hai cột `recurrence` và `time_recurrence` tồn tại ở Drift lẫn Prisma, nằm trong
payload đẩy và nhánh kéo về đã đọc cả hai từ lâu. Chúng chết vì một lý do đơn
giản hơn nhiều: **`GoalEntity` không hề mang chúng**, nên không tầng nào phía
trên nhìn thấy được.

**Phương án đã loại — tự động đặt lại khi hoàn thành.** Nó hỏng theo hai đường
khác nhau tuỳ cách hiểu "lặp lại":

| Cách hiểu | Vỡ ở đâu |
|---|---|
| Tạo mục tiêu **mới** | Va thẳng vào quy tắc trùng tên ở mục 3.15 |
| Đặt lại **chính nó** | Tiến độ về 0 trong khi sổ giao dịch vẫn ghi đủ các khoản nạp — sổ và số dư nói hai chuyện |

Nên: khi mục tiêu có bật lặp lại đạt đủ tiền, app **chỉ nhắc**. Đặt lại là xoá
tiến độ và không hoàn tác được, nên nó phải là một cú bấm có ý thức, kèm hộp
thoại xác nhận.

⚠️ **Lời nhắc là một loại thông báo RIÊNG (`goalCycleReady`), không gộp vào câu
chúc mừng.** Câu chúc mừng dùng khoá `goalDone:<id>` **cố ý không có mốc thời
gian** — chú thích ngay tại chỗ ghi "một mục tiêu chỉ hoàn thành một lần trong
đời". Mục tiêu lặp lại phá đúng giả định ấy: nhét lời nhắc vào chung thì từ vòng
thứ hai trở đi nó rơi vào khoá cũ và không bao giờ hiện nữa. Khoá mới gắn
`startDate`, và `batDauVongMoi` đặt lại cột ấy — nên mỗi vòng nhắc đúng một lần.

**`batDauVongMoi` KHÔNG đụng một đồng nào.** Tiền của vòng cũ nằm nguyên trong
ví tích luỹ. Người dùng mới chỉ bấm "bắt đầu vòng mới"; suy ra rằng họ cũng muốn
chuyển tiền đi là đúng kiểu tự tiện mà cả tính năng này tránh từ đầu. Hộp thoại
nói thẳng điều đó và trỏ sang "Rút khỏi mục tiêu".

Mốc bắt đầu **phải** đặt lại bằng "bây giờ": `tocDoThucTe` đo từ nó, nên giữ mốc
cũ thì vòng mới hiện tốc độ tiết kiệm của vòng trước.

`hanVongMoi()` luôn bước **ít nhất một kỳ**, vì cả hai đầu đều sai nếu giữ hạn
cũ: đạt sớm thì vòng mới thừa hưởng phần thời gian còn lại của vòng trước; đạt
muộn thì mục tiêu quá hạn ngay giây đầu tiên. Nó gọi lại `mocKeTiep` thay vì tự
cộng tháng — hàng rào cho `DateTime(2028, 2, 31)` (Dart tự chuẩn hoá thành
02/03, **không ném**) đã dựng sẵn ở đó kèm test năm nhuận.

Bảng chọn chu kỳ lặp cố ý **hẹp hơn** `mocKeTiep`: chỉ Tuần/Tháng/Năm, bỏ `Day`
và `Quarter`. Lặp lại một mục tiêu tiết kiệm mỗi ngày không có nghĩa gì. Giá trị
lạ từ Admin-web vẫn hiển thị được, rơi về hàng tháng.

✅ **Đã kiểm trọn luồng trên máy ảo 2026-09-05**: bật lặp lại → nạp cho đủ →
thông báo `goalCycleReady` sinh ra → nút hiện → hộp thoại → tiến độ về 0, hạn dời
27/04/2028 → 27/05/2028, `startDate` về "bây giờ", **số dư hai ví không đổi và
không sinh giao dịch nào**.

---

### 3.18 Hai tab, và **một** định nghĩa "đã xong"

Danh sách trước đây phẳng: mục tiêu đã đạt nằm lẫn với mục tiêu đang chạy và chỉ
dài thêm mãi. Nay chia hai tab theo đúng lối của Ngân sách, nhãn mang số đếm.

`GoalEntity.daHoanThanh` = `isCompleted || progress >= 1.0` là **định nghĩa duy
nhất**; luật thông báo `_goalCandidates` và bộ chia tab `chiaMucTieu` đều gọi nó.
Trước đây mỗi nơi tự viết lại cùng biểu thức — hai bản sao chờ ngày lệch.

Cần cả hai vế: cờ được ghi lúc nạp/rút, còn `progress >= 1.0` bắt ca cờ chưa kịp
ghi **và** bắt mục tiêu 0 đồng (nơi `progress` trả thẳng `1.0`).

⚠️ **`goalDao.watchAll` không có `orderBy` nào** — thứ tự trả về tuỳ SQLite, danh
sách xáo lại được giữa hai lần mở app. `chiaMucTieu` sắp lại: đang-theo-đuổi theo
hạn **gần nhất trước**, đã-hoàn-thành **ngược lại** (đã xong thì "gấp" không còn
nghĩa; thứ đáng lên đầu là cái vừa đạt được).

Phần chia tách là **hàm thuần** — phần khó không phải phần vẽ mà là hai quyết
định trên, và cả hai kiểm được bằng dữ liệu, không cần dựng widget.

---

### 3.19 Ghi chú: `null` là giữ nguyên, **chuỗi rỗng** mới là xoá

Quy ước này khác hai hàng xóm của nó trong `updateGoal`, và khác có chủ ý:

| Trường | `null` nghĩa là |
|---|---|
| `cycleTakeMoney` | **XOÁ** |
| `icon` / `colour` | **GIỮ NGUYÊN** (không có trạng thái "không có") |
| `note` | **GIỮ NGUYÊN**, nhưng **chuỗi rỗng = XOÁ** |

Vế cuối là thứ dễ làm sai nhất. Gộp chuỗi rỗng chung với `null` thì người dùng
không còn cách nào bỏ ghi chú đi; còn coi `null` là xoá thì một trang sửa chỉ đổi
tên sẽ lặng lẽ xoá sạch chữ họ đã viết.

Ô nhập đặt **cuối** thẻ mô tả, cùng lối với biểu mẫu thêm giao dịch: nó là trường
tuỳ chọn, đặt lên đầu sẽ đẩy số tiền và hạn định — hai thứ bắt buộc — xuống dưới
nếp gấp màn hình. Trang chi tiết hiện nó ngay dưới con số, **trước** hộp dự báo:
khi mở mục tiêu ra để cân nhắc có nên tiêu vào tiền tích luỹ không, câu tự mình
viết ra đáng đọc trước cả tốc độ tiết kiệm.

### 3.20 Ví nguồn trích: phép chọn sẵn phải **biết** ví tích luỹ là ví nào

Ô "ví nguồn trích tiền" vốn được chọn sẵn bằng ví **mặc định** của tài khoản, và
phép chọn ấy không đối chiếu với ví tích luỹ. Trên máy thật, ví mặc định là
`Tiết kiệm` — cũng chính là ví người dùng sẽ chọn làm ví tích luỹ cho một mục
tiêu tiết kiệm. Nên biểu mẫu mở ra đã ở trạng thái **không lưu được**, và người
dùng chỉ biết sau khi bấm Lưu và đọc lời từ chối. Không sai dữ liệu — phép kiểm
vẫn chặn đúng — nhưng nó bắt người dùng sửa một lỗi mà app tự tạo ra.

Đoạn chú thích ngay trên khối ấy còn nói ngược lại mã: nó viết "để trống cho tới
khi người dùng thật sự chọn". Chú thích ấy vốn thuộc về khối tự chọn **ví tích
luỹ** bị gỡ ở `0dd5333`; gỡ mã mà để chú thích ở lại thì nó lặng lẽ mô tả sai
dòng bên dưới. Nay đã dời về đúng chỗ.

**Ba thay đổi, cùng một nguyên tắc: lựa chọn sai thì đừng để người dùng nhìn thấy.**

| | Làm gì | Vì sao |
|---|---|---|
| Chọn sẵn | Qua `viNguonTrichMacDinh` — ví mặc định vẫn là phỏng đoán đầu tiên, chỉ bị bỏ khi trùng ví tích luỹ | Giữ được sự tiện lợi mà không tạo ra trạng thái hỏng |
| Bảng chọn | Ẩn hẳn ví tích luỹ khỏi danh sách ví nguồn | Cùng tinh thần đã ghi ở `goal_deposit_wallets.dart` cho phiếu nạp tay |
| Đổi ví tích luỹ | Ví vừa chọn mà đang là ví nguồn thì **nhả ô nguồn ra**, để nó tự điền lại | Đây là chỗ duy nhất app đổi lựa chọn người dùng đã đưa ra — và chỉ khi lựa chọn ấy vừa trở thành không hợp lệ |

`viNguonTrichMacDinh` là **lớp ưu tiên đặt lên trên** `viNguonMacDinh`, không phải
bản sao của nó: quy tắc "nguồn ≠ ví tích luỹ" vẫn nằm đúng một chỗ. Ví ưu tiên bị
bỏ qua khi nó **không còn** trong danh sách — ví mặc định có thể đã bị xoá mềm
trong lúc biểu mẫu đang mở, và trả về một id không có thật thì ô chọn hiện rỗng
trong khi biến trạng thái vẫn khác `null`, đủ để lọt qua phép kiểm lúc lưu rồi
ghi một khoá ngoại trỏ vào hư không.

⚠️ **Phép kiểm lúc lưu vẫn giữ nguyên.** Nó không còn là nơi người dùng gặp lỗi
trong luồng thường, nhưng nó là lưới chắn cho những đường vào khác — và cho
chính `depositToGoal`, nơi cặp sai vẫn ném `ArgumentError`.

⚠️ Tài khoản chỉ có **đúng một ví** và ví ấy là ví tích luỹ thì danh sách ví nguồn
cạn sạch. Bảng chọn nói ra lý do ("cần thêm một ví khác ví tích luỹ…") thay vì
câu "chưa có ví nào" — câu ấy sẽ là một lời nói dối khi tài khoản rõ ràng đang có
ví. Trạng thái này **chưa xem trên máy thật**: dựng nó đòi xoá bớt ví của dữ liệu
đang có.

### 3.21 Cột mốc tiến độ: báo **mốc cao nhất**, và khoá theo vòng

Trước 2026-09-08 app chỉ lên tiếng về một mục tiêu ở **hai** thời điểm: đạt
100% (`goalCompleted`) và khi chậm tiến độ (`goalBehind`). Người dùng đi ba
phần tư chặng đường mà không được ghi nhận gì — xem mục 10.4.

`goalMilestone` lấp chỗ ấy với ba mốc **25 / 50 / 75**.

**Không có mốc 100** trong `_mocTienDo`: `goalCompleted` đã lo mốc ấy, và mục
tiêu đạt đủ tiền còn không đi tới được đoạn mã này (nhánh `daHoanThanh` đã
`continue` phía trên). Thêm vào là hai lời chúc mừng cho cùng một việc.
**Không có mốc dưới 25** vì gần như mọi mục tiêu vượt ngay ở khoản nạp đầu
tiên, và một lời chúc mừng ai cũng nhận được thì không còn là lời chúc mừng.

**Vượt nhiều mốc cùng lúc thì chỉ báo mốc cao nhất.** Nạp một phát từ 10% lên
80% vượt cả ba; bắn ba tin cho MỘT thao tác là ồn, và chỉ mốc cao nhất mang
tin mới. Hằng số `_mocTienDo` vì thế **xếp giảm dần** — `_mocDaVuot` lấy phần
tử đầu tiên khớp, nên đảo thứ tự sẽ luôn trả 25 và hai mốc kia chết lặng.

**Khoá chống trùng theo khuôn `goalCycle:`, cố ý KHÁC khuôn `goalDone:`** —
`goalMilestone:<id>:<startDate>:<mốc>`. Đây đúng là cái bẫy đã ghi ở mục 3.17:
`goalDone:<id>` không mang mốc thời gian vì "một mục tiêu chỉ hoàn thành một
lần trong đời", và mục tiêu **lặp lại** phá đúng giả định ấy. Cột mốc thì mỗi
vòng phải báo lại, nên nó gắn `startDate` — cột mà `batDauVongMoi` đặt lại.
Đoạn `:<mốc>` ở cuối là thứ giữ cho ba mốc không nuốt nhau.

⚠️ **Luật phải đứng TRƯỚC phép kiểm `isBehindSchedule`** trong
`_goalCandidates`. Dòng ấy `continue` cho mọi mục tiêu đang đúng nhịp, nên đặt
cột mốc sau nó thì **chỉ mục tiêu đang TRỄ mới được ghi nhận quãng đã đi** —
đúng ngược ý định, và im lặng. Đã dựng bản sai có chủ ý để kiểm: **3 test đỏ**,
nên lưới này có thật.

Cột mốc **chịu công tắc nhóm** Mục tiêu (`luonBao` trả `false`): nó là lời ghi
nhận, không phải tin "tiền vừa rời ví". Nới `luonBao` ra cho nó là làm đúng
việc mà cảnh báo ở đầu hàm ấy cấm.

### 3.22 Ưu tiên mục tiêu: số thưa, `NULL` xếp cuối, và chỉ một tab dùng nó

Danh sách trước đây sắp cứng theo hạn gần nhất, nên người dùng không nói được
"quỹ khẩn cấp quan trọng hơn cái laptop". Cột `Priority Int?` phía backend có
từ 2026-09-07; client nhận nó ngày 2026-09-08 (**schema v19**).

**Quy ước giá trị lấy nguyên từ tài liệu backend** (`DA-XONG/2026-09-05-backend-goal-priority.md`
mục 4), không phát minh lại: số **cách nhau 100**, nhỏ hơn đứng trước, `NULL`
xếp **cuối**, trùng số thì sắp tiếp theo `targetDate`.

**Vì sao thưa chứ không phải 1, 2, 3:** chèn một mục tiêu vào giữa mà đánh số
liên tục thì phải ghi lại cả danh sách — một thao tác kéo thả sinh ra *n* bản
ghi `pending`. Với khe 100, chèn giữa hai hàng chỉ ghi **một** hàng.

`uuTienSauKhiKeo` vì thế có **hai chế độ**, và cần cả hai:

| Khi nào | Ghi mấy hàng |
|---|---|
| Mọi hàng đã có số **phân biệt** và chỗ thả còn khe | **một** |
| Còn hàng `null`, có số trùng nhau, hoặc hết khe | **cả danh sách** |

Lần kéo **đầu tiên** luôn rơi vào chế độ hai vì mọi hàng đang mang `null`. Đó
là *một* lần ghi *n* hàng trong đời danh sách, không phải mỗi lần kéo. Ép đại
một giá trị vào chỗ chật (giữa 100 và 101 không còn số nguyên nào) là hai hàng
trùng số, và khi ấy thứ tự rơi về `targetDate` — tức thao tác kéo thả **biến
mất ở lần mở app sau**, không lỗi, không dấu hiệu gì.

⚠️ **`priority` luôn DƯƠNG.** `0` và số âm đi qua đường đồng bộ thì không phân
biệt được với "chưa sắp", và một mục tiêu đã sắp mà bị đọc thành chưa sắp sẽ
nhảy xuống cuối. Kéo lên đầu khi hàng đầu đã là `1` thì đánh số lại cả danh
sách chứ không lùi xuống `0`.

⚠️ **`ReorderableListView.onReorder` trả `newIndex` tính trên danh sách CÒN
NGUYÊN phần tử đang kéo**, nên kéo **xuống** thì con số ấy lớn hơn vị trí cuối
cùng đúng một đơn vị. `viTriThaThucTe` là chỗ duy nhất sửa việc đó — dùng thẳng
`newIndex` là mục tiêu rơi lệch một ô, im lặng. Kéo **lên** thì không trừ gì.

**Chỉ tab "Đang theo đuổi" dùng ưu tiên.** Tab "Đã hoàn thành" giữ nguyên thứ
tự cũ (mới đạt lên đầu): đã xong rồi thì "quan trọng hơn" không còn nghĩa gì,
và áp ưu tiên ở đó sẽ đẩy mục tiêu vừa đạt được xuống đáy chỉ vì nó từng được
xếp thấp — cùng lập luận đã dùng để cho hai tab sắp ngược nhau (mục 3.18).

**Migration v19 cố ý KHÔNG suy giá trị cho hàng cũ**, khác hẳn `anchorDay` của
v18. Ở đó ngày đến hạn là một ý định người dùng đã đưa ra và chỉ cần đọc lại;
ở đây mọi thứ tự bịa ra đều sai với người đã sắp tay, và `NULL` có nghĩa riêng
rõ ràng. Đánh số theo `targetDate` để danh sách "trông đã được sắp" là biến thứ
tự mặc định thành một lựa chọn người dùng chưa từng đưa ra — cùng lập luận đã
dùng cho v15 và v17.

✅ **Đã kiểm trọn vòng trên máy ảo 2026-09-08:** kéo `MuaXe` (hạn 27/04/2028)
lên trên `MuaDT` (hạn 05/09/2027) → danh sách đổi ngay, thứ tự **sống qua khởi
động nguội**, và truy vấn thẳng PostgreSQL thấy `Priority` 100 / 200 — tức lần
kéo đầu đánh số lại cả danh sách và **cả hai hàng đã lên tới server**.

**Khe hở còn lại, chấp nhận được:** hai máy cùng sắp lại khi ngoại tuyến thì
LWW phân xử **theo từng hàng**, không theo cả danh sách, nên kết quả có thể là
một thứ tự trộn giữa hai lần sắp. Không hàng nào sai, nhưng tổng thể không
giống lần sắp nào. Vá triệt để cần khoá thứ tự kiểu phân số (`"a0"`, `"a0V"`) —
đắt hơn giá trị nó mang lại. Hậu quả tệ nhất là kéo lại vài mục tiêu: không mất
tiền, không mất bản ghi, không kẹt hàng đợi.

### 3.23 Khối "Cấu hình": chỗ thiếu là chỗ HIỂN THỊ, không phải dữ liệu

Người dùng báo trang chi tiết **thiếu nội dung** (2026-09-08). Đo lại thì trang
không thiếu dữ liệu — cả bốn thứ dưới đây đều nằm sẵn trên `GoalEntity` mà
không dòng nào trên trang nói tới:

| Dòng | Đã có sẵn ở | Trước đó dùng vào việc gì |
|---|---|---|
| Hạn chót + đếm ngược | `targetDate`, `daysLeft` | `targetDate` chỉ xuất hiện lẫn trong câu dự báo; `daysLeft` **không nơi nào gọi** |
| Đúng nhịp / chậm | `isBehindSchedule` | Chỉ dùng cho **thông báo**, không cho màn hình |
| Ví tích luỹ | `walletId` | Chỉ dùng cho hộp thoại đổi ví và phép tính cảnh báo — chưa bao giờ hiện **tên** |
| Trích tự động | `autoDepositEnabled` + ba cột | **Không hiện ở đâu** trên trang |

**Dòng cuối là chỗ nghiêm trọng nhất.** App tự chuyển tiền của người dùng mỗi
kỳ, mà trang chính của mục tiêu không nói gì — phải mở trang Sửa mới biết. Với
một tính năng chuyển tiền lúc người dùng vắng mặt thì đó là chỗ im lặng không
chấp nhận được. Đo trên máy thật 2026-09-08: mục tiêu `MuaXe` đang bật trích
**100.000 đ mỗi tháng từ ví `test`**, và trước bản này màn hình không hề nói.

**Ba quyết định nhỏ, mỗi cái có test:**

- `moTaHanChot` **không bao giờ hiện số ngày âm**. `daysLeft` trả số âm khi quá
  hạn — đúng số học, nhưng *"Còn -7 ngày"* đọc lên thì vô nghĩa, và đó lại là
  ca hay gặp nhất với mục tiêu cũ bỏ dở. Mục tiêu **đã đạt** thì thôi đếm
  ngược: hô "Quá hạn 7 ngày" cho việc người dùng đã làm xong là trách họ vì
  chính thành quả của họ.
- `moTaTrichTuDong` dùng chung `autoDepositEnabled` — định nghĩa duy nhất của
  "đang bật", vốn đòi **cả ba** mảnh. Tự viết lại phép kiểm ở đây là để màn
  hình nói đang bật trong khi bộ chạy không chạy.
- Ví không tra được tên thì vẫn nói phần biết chắc. `autoDepositWalletId`
  **không có khoá ngoại** (cùng lý do với `walletTransfer`, bẫy 4.1) nên ví có
  thể đã bị xoá mềm; trả chuỗi rỗng khi ấy là giấu luôn việc app đang trừ tiền.

Khối đặt **sau** hộp dự báo và cảnh báo ví: hai khối kia nói về *cần làm gì*,
khối này nói về *đang cài đặt thế nào* — thứ người dùng tra lại chứ không đọc
mỗi lần mở.

---

## 4. Bảy cái bẫy

> **Năm cái còn hiệu lực.** 4.6 đóng 2026-09-07 (G17), 4.5 đóng 2026-09-08.
> Cả hai được giữ lại: cái đầu vì bẫy bên dưới nó vẫn thật với mọi trang
> **khác** đọc theo tài khoản, cái sau vì lý lẽ của bản sửa là thứ đáng đọc
> trước khi ai đó viết một trang chi tiết mới.

### 4.1 `walletTransfer` **không có khoá ngoại**

Cột khai `text().nullable()()`, không `.references()`. Không có gì ở tầng CSDL
chặn việc chuyển tới một ví không tồn tại — tiền rời ví nguồn mà không ví nào
được cộng, và nó biến mất khỏi tổng tài sản **im lặng**.

`withdrawFromGoal` phải tự kiểm ví đích tồn tại. Đường nạp tiền thì may hơn: ví
nguồn nằm ở cột `walletId`, cột **có** khoá ngoại.

### 4.2 Suy chiều tiền từ **vị trí ví hiện tại** là diễn giải lại lịch sử

Đã vấp: một mục tiêu đổi ví tích luỹ xong thì khoản nạp **cũ** có ví nguồn trùng
ví tích luỹ **mới**, và bị đọc thành khoản rút. Trên màn hình: cả hai dòng lịch
sử đều hiện dấu trừ, kể cả dòng người dùng thật sự đã gửi vào.

Dùng tiền tố ghi chú (mục 3.3). Khoá đổi ví (mục 3.1) làm ca này khó xảy ra
nhưng **không** loại bỏ được — dữ liệu tạo trước khi có khoá vẫn còn.

### 4.3 `_collectPendingOps` dựng payload **thô**, normalizer chạy sau

Đọc `_collectPendingOps` rồi kết luận là **sai**: nó dựng
`{'type': 'chi', 'amount': 1000}` và dừng ở đó.
`SyncPayloadNormalizer.transactionForPush` mới là nơi quy đổi sang
`{'type': 'Transaction', 'amount': -1000}`, và nó chạy ở
`sync_engine.dart:1234`, **ngay trước `POST /sync/push`**.

PostgreSQL có `chk_transaction_type CHECK ("Type" IN ('Transaction','Transfer'))`
và mã hoá chiều tiền bằng **dấu của `Amount`**. Bỏ phép quy đổi là mọi giao dịch
bị từ chối.

> Phiên 2026-09-05 đã kết luận nhầm là chỗ này đang hỏng, chỉ vì đọc
> `_collectPendingOps` rồi dừng. Hợp đồng nay có **bốn phép kiểm giá trị** canh
> chừng, không chỉ tên khoá.

### 4.4 `goal_id` là cột **CỤC BỘ**

Hàng kéo về từ server không bao giờ mang nó, cũng như mọi hàng do bản app trước
v14 tạo. `TransactionDao.watchByGoal` vì thế giữ **hai nhánh**, và nhánh dự phòng
vẫn là `LIKE` trên **tên mục tiêu** — nên với dữ liệu cũ, mục tiêu tên `"Mua"`
vẫn nuốt lịch sử của `"Mua xe"`.

Điều kiện `goal_id IS NULL` ở nhánh dự phòng là thứ chặn không cho một hàng đã có
chủ bị mục tiêu khác nhận vơ. **Đừng bỏ nó.**

Yêu cầu backend: `docs/superpowers/backend/DA-XONG/2026-09-05-backend-transaction-goal-id.md`.

### 4.5 ~~`GoalDetailPage` **bỏ qua** cubit và không nghe dòng dữ liệu~~ — ✅ ĐÃ SỬA

> ✅ **Đóng 2026-09-08.** Trang nay đăng ký `watchGoals` trong `_loadGoal()` và
> huỷ đăng ký ở `dispose()`. Ba test canh ở
> `test/features/goal/presentation/pages/goal_detail_live_test.dart`.

Bản cũ lấy `sl<GoalRepository>()` trong `initState`, gọi `getGoalById` đúng
**một lần** rồi tự giữ `_goal` trong `State`. Đồng bộ kéo về một thay đổi của
mục tiêu đang mở thì màn hình vẫn hiện số cũ — không lỗi, không log, người dùng
chỉ phát hiện khi thoát ra vào lại. Bán kính rộng thêm khi `priority` đi qua
đường đồng bộ, và đó là lý do nó được sửa cùng đợt.

**Ba quyết định của bản sửa:**

| | Làm gì | Vì sao |
|---|---|---|
| Phạm vi nghe | `watchGoals` của **cả tài khoản**, không riêng mục tiêu này | `_canhBaoVi` cộng dồn **mọi** mục tiêu trỏ vào cùng ví, nên một mục tiêu *khác* nạp tiền cũng làm câu cảnh báo ở đây đổi |
| Nguồn mã tài khoản | Lấy từ **chính mục tiêu vừa đọc** | Hàm chạy sau một `await` nên `context` có thể đã tháo; đọc `AuthBloc` ở đó là mở lại đúng cửa mà G17 vừa đóng |
| `_isLoading` | **Không đụng** ở đường stream | Đây là cập nhật nền, không phải một lần tải do người dùng gây ra; bật cờ tải làm cả trang nháy về vòng quay mỗi lần đồng bộ xong |

⚠️ Hàng có thể **biến mất** khỏi danh sách vì vừa bị xoá mềm ở máy khác. Khi ấy
giữ nguyên những gì đang hiện — `firstWhere(orElse: () => throw)` là màn đỏ ngay
giữa một lượt đồng bộ nền.

### 4.6 ~~Danh sách rỗng ở lần vào **đầu tiên** sau khi khởi động nguội~~ — ✅ ĐÃ SỬA

> ✅ **Đóng bằng G17.** Mục này từng mô tả một lỗi còn tồn; nay không còn đúng.
> Giữ lại vì cái bẫy bên dưới vẫn là bẫy thật cho mọi trang **khác** đọc
> `currentAccountIdOrNull`.

Trang dựng trước khi `AuthBloc` khôi phục xong phiên, `currentAccountIdOrNull`
trả `null`, rồi `?? 0` biến nó thành tài khoản 0 — và `watchGoals(0)` đương
nhiên rỗng. Thoát ra vào lại là thấy.

`?? 0` đúng ở chỗ nó **không** ghi nhầm vào tài khoản admin (bài học G4), nhưng
nó cũng không đợi phiên.

`GoalPage` nay chặn ca ấy bằng **hai** thứ phải đi cùng nhau, và thiếu một trong
hai là lỗi quay lại:

| | Làm gì | Thiếu nó thì |
|---|---|---|
| `context.watch<AuthBloc>()` | Đăng ký với phiên, không chỉ đọc một phát | `read` không đăng ký gì, nên phiên tới nơi cũng không dựng lại |
| `key: ValueKey(idaccount)` | Ép `BlocProvider` dựng lại khi mã tài khoản đổi | `create` chỉ chạy MỘT lần, nên `watch` chỉ khiến build chạy lại còn cubit vẫn giữ đăng ký `watchGoals(0)` cũ |

Canh bằng `test/features/goal/presentation/pages/goal_page_cold_start_test.dart`.
`home_page` và `transaction_page` không mắc lỗi này vì chúng vốn đã `watch`.

### 4.7 `GoalDao.insert` dùng `insertOrReplace`

An toàn cho `addGoal` vì id là UUID mới. Nhưng gọi nó với id đã tồn tại sẽ **thay
cả hàng**, đưa mọi cột không gán về mặc định. Nhánh pull đúng ra dùng
`upsertAll` → `insertAllOnConflictUpdate` (quy tắc 3).

---

## 5. Bộ giá trị và tên cột hay nhầm

| Ý nghĩa | Client (Drift) | Payload đẩy | PostgreSQL |
|---|---|---|---|
| Khoá chính mục tiêu | `id` | `id` | `Idgoal` |
| Ví tích luỹ | `walletId` | `idwallet` | `Idwallet` |
| Đã hoàn thành | `isCompleted` (bool) | `status_complete` (`'True'`/`'False'`) | `Status_complete` |
| Xoá | `isDeleted` (bool) | `is_deleted` | `Delete_at` (dấu thời gian) |
| Sửa lần cuối | `updatedAt` | `update_at` | `Update_at` |
| Chu kỳ trích | `cycleTakeMoney` | `cycle_take_money` | `Cycle_take_money` |
| Mục tiêu của giao dịch | `goalId` | — **không đẩy** — | — chưa có — |
| Số tiền trích mỗi kỳ | `autoDepositAmount` | — **không đẩy** — | — chưa có — |
| Ví nguồn trích | `autoDepositWalletId` | — **không đẩy** — | — chưa có — |
| Mốc kỳ đã trích | `autoDepositLastRun` | — **không đẩy** — | — chưa có — |
| **Mốc neo** của nhịp trích | `timeCycleTakeMoney` | `time_cycle_take_money` | `Time_cycle_take_money` |
| **Thứ tự ưu tiên** | `priority` (v19) | `priority` | `Priority` |

Payload mục tiêu có **19 trường** (18 + `priority` từ 2026-09-08). Hợp đồng đầy đủ ở
`test/core/sync/sync_payload_contract_test.dart` — **nơi duy nhất** ghi tên
trường giữa hai phía.

---

## 6. Cột có mà không ai dùng

`recurrence` và `timeRecurrence` trên bảng `Goals` (lặp lại mục tiêu sau khi
hoàn thành) tồn tại ở cả hai đầu và đồng bộ đủ hai chiều, nhưng **client chưa
bao giờ ghi**. Chúng không phải rác — đọc/ghi qua đường đồng bộ vẫn giữ nguyên
giá trị từ Admin-web nếu có — nhưng đừng tưởng có tính năng đằng sau.

`cycleTakeMoney` thì **đã** được dùng (mục 3.7). `timeCycleTakeMoney` vẫn chưa.

---

## 7. Còn dang dở

| Việc | Ghi chú |
|---|---|
| ~~Cấu hình trích tự động **không sang máy khác**~~ | ✅ **Đóng 2026-09-07.** Backend đã có ba cột `auto_deposit_*`, client đẩy và kéo cả ba. Còn lại đúng một khe hở hẹp: hai máy cùng mở đúng lúc tới kỳ. **G21 đóng** |
| Không có bộ **lập lịch nền** | Giờ trong mốc trích chỉ giữ được chiều "không sớm hơn". Có lời nhắc AlarmManager nổ đúng giờ kể cả khi app đóng, nhưng nó chỉ báo tin. **G22** — cố ý, đừng "sửa" |
| Quy tắc trùng tên chỉ có ở **client** | `/sync/push` và PostgreSQL chưa kiểm gì — cùng tình trạng với danh mục. Xem mục 3.15 |
| ~~**Ưu tiên mục tiêu** chưa có~~ | ✅ **Xong 2026-09-08** — schema v19, kéo thả ở tab "Đang theo đuổi", đồng bộ đủ hai chiều. Mục **3.22** |

**Đã đóng ngày 2026-09-05** (giữ lại đây để không ai mở lại nhầm):

| Việc | Đóng bằng gì |
|---|---|
| ~~Không kiểm trùng tên mục tiêu~~ | Mục **3.15** — `_trungTen()` ở cả `addGoal` lẫn `updateGoal`, dùng chung `normalizeCategoryName()` |
| ~~Phép kiểm **số tiền** khi nạp chỉ ở giao diện~~ | Mục **3.16** — hai trần (`> 0` và `≤ số dư ví nguồn`) nằm trong khối nguyên tử |
| ~~Dải cảnh báo lệch chưa xem trên máy thật~~ | Mục **3.4** — đã dựng đúng ca và xem trên máy ảo Android |
| ~~Giao dịch trích **bù** mang dấu thời gian lúc bù~~ | Mục **3.14** — tham số `occurredAt` chặn hai đầu; **G20** đã đóng |
| ~~Ví nguồn trích mặc định trùng ví tích luỹ~~ | Mục **3.20** — `viNguonTrichMacDinh`, bảng chọn ẩn ví tích luỹ, và ô nguồn tự nhả khi ví tích luỹ đổi |

---

## 8. Việc phía backend

Ba tài liệu, **cả ba đã đóng ngày 2026-09-07** và nay nằm ở
`docs/superpowers/backend/DA-XONG/`. Cả ba chỉ xin **cột nullable** nên backend
gộp chung một đợt migration — đúng như đề nghị.

| Tài liệu | Xin gì | Trạng thái ở client |
|---|---|---|
| `2026-09-05-backend-transaction-goal-id.md` | `transaction.Idgoal` | ✅ **Xong 2026-09-07** — cột đã có, client đẩy `idgoal` và đọc lại. Nhánh so **tên** vẫn giữ cho hàng cũ trên server (đều `NULL`), teo dần — **G18** |
| `2026-09-05-backend-goal-auto-deposit.md` | Ba cột `auto_deposit_*` | ✅ **Xong 2026-09-07** — backend có cột, client đẩy và kéo cả ba. **G21 đóng** |
| `2026-09-05-backend-goal-priority.md` | `goal.Priority` | ✅ **Đóng trọn 2026-09-08.** Cột có từ 2026-09-07, client nhận ở schema v19 và đẩy/kéo `priority`. Quy ước giá trị ở mục 4 của tài liệu ấy vẫn là nguồn duy nhất — mục **3.22** chỉ nhắc lại |

Hai tài liệu đầu **không chặn gì hôm nay**; cái đầu chặn hướng bỏ bộ đếm
`current_amount` để suy tiến độ từ chính giao dịch.

Tài liệu thứ ba đi ngược lối của hai cái trên **có chủ ý**: xin cột **trước** khi
viết mã. Thứ tự ưu tiên là công sức người dùng bỏ ra bằng thao tác kéo thả, không
suy lại được, không có mặc định đúng, và nếu về sau nối phân bổ tự động thì nó
quyết định **tiền đi đâu** — ba lý do khiến nó không nên là cột cục bộ.

> ⚠️ Tài liệu cũ `2026-08-23-backend-goal-wallet-id.md` xin cột `wallet_id` cho
> bảng `goal`. **Việc đó đã xong** — backend có `Idwallet` (tên khác với tên tài
> liệu xin). Tài liệu ấy không còn việc gì.

---

## 9. Kiểm thử

**333 test** riêng cho mục tiêu, trên tổng **1495** của dự án (đếm lại
2026-09-08 sau khi thêm luật cột mốc và thứ tự ưu tiên, bằng cách chạy thật `flutter test
test/features/goal test/core/notification/notification_rules_goal_wallet_test.dart`;
con số ghi ở đây trước đó là 222/893 và đã lạc hậu — **đừng chép lại từ trí
nhớ**).

| Tệp | Canh gì |
|---|---|
| `goal_entity_progress_test.dart` | `progress`, `daysLeft`, `isBehindSchedule` — biên dung sai, chia 0, quá hạn |
| `goal_forecast_test.dart` | Ba hàm dự báo, kể cả các nhánh "không đủ căn cứ". Từ 2026-09-08 canh thêm **cửa sổ tối thiểu** (mục 3.7): ca thật ba ngày/chu kỳ tháng, nửa chu kỳ là ngưỡng, chu kỳ ngày đủ ngay, chu kỳ năm cần lâu hơn, và "chưa nạp đồng nào" vẫn trả `0.0` chứ không `null` |
| `presentation/widgets/goal_config_card_test.dart` | **Mục 3.23.** `moTaHanChot` (đếm ngược, quá hạn, đã đạt), `moTaTrichTuDong` (tắt/bật, thiếu mảnh, ví đã xoá), bốn dòng của khối, và khổ 411dp |
| `goal_deposit_warning_test.dart` | `remainingAmount`, cảnh báo nạp vượt |
| `goal_deposit_default_wallets_test.dart` | Bất biến ví nguồn ≠ ví nhận |
| `goal_history_direction_test.dart` | **Bẫy 4.2** — đổi ví không làm khoản nạp cũ đọc thành rút |
| `goal_wallet_shortfall_test.dart` | Cảnh báo lệch, cộng dồn nhiều mục tiêu |
| `data/repositories/goal_repository_impl_test.dart` | Nạp, rút, đổi ví, nguyên tử, lịch sử. Từ 2026-09-08 thêm `capNhatUuTien`: chỉ chạm hàng có tên trong map, đánh dấu `pending`, id lạ không ném |
| `presentation/widgets/goal_progress_test.dart` | Một định nghĩa duy nhất của tỉ lệ |
| `presentation/widgets/goal_appearance_test.dart` | Bảng tra biểu tượng/màu, dữ liệu rác, và **giá trị ngoài bảng chọn** |
| `goal_edit_form_test.dart` | `showDatePicker` với mục tiêu **quá hạn** — xem mục 3.9 |
| `goal_priority_test.dart` | **Mục 3.22.** Hai chế độ của `uuTienSauKhiKeo` (ghi một hàng / đánh số lại), giá trị luôn dương và không trùng, vị trí ngoài dải không ném, và `viTriThaThucTe` — chỗ duy nhất sửa cái lệch một ô của `ReorderableListView` |
| `goal_grouping_test.dart` | Hai tab, và từ 2026-09-08 canh **thứ tự ưu tiên**: ưu tiên thắng hạn định, `NULL` xếp cuối, trùng số rơi về hạn định, và tab đã hoàn thành **không** dùng ưu tiên |
| `goal_auto_deposit_test.dart` | Bước kỳ (tháng ngắn, **năm nhuận**), **mốc neo**, trần số kỳ, quyết định trích. Từ 2026-09-08 canh thêm: **nhịp neo vào mốc gốc, không trôi** — ngày 31 kẹp ở tháng ngắn rồi **quay lại** 31, ngày 30 không bị kéo lên cuối tháng, `kyKeTiep` dùng chung nhịp, và mục tiêu chưa có mốc neo vẫn chạy như trước |
| `goal_auto_deposit_runner_test.dart` | Trích bù nhiều kỳ, ví cạn giữa chừng, cấu hình hỏng, cách ly tài khoản |
| `core/notification/reminder_scheduler_test.dart` | Lịch nhắc kỳ trích: đúng mốc kỳ, trùng khoá thông báo, và **không huỷ lịch hoá đơn** |
| `core/notification/notification_rules_goal_wallet_test.dart` | Hai luật thông báo. Từ 2026-09-08 canh thêm **cột mốc** (mục 3.21): mốc cao nhất, ba khoá riêng, khoá gắn `startDate` cho mục tiêu lặp lại, và ca **vừa ở cột mốc vừa chậm tiến độ** — ca duy nhất bắt được việc đặt luật sai chỗ |

### ⚠️ Ba thứ bộ test **không** bắt được ở vùng này

Cả ba đều lộ ra trên máy ảo Android trong phiên 2026-09-05:

1. **`ProviderNotFoundError`** — `context.read<WalletCubit>()` trên route
   `/goals/:id` vốn không có provider ấy. Mã cũ đặt lệnh sau khoảng chờ nên sự
   cố chỉ nổ ở đường thành công.
2. **Màn đỏ do `DropdownButton`** — `value` không nằm trong `items` khi ví nguồn
   mặc định trùng ví nhận.
3. **Dấu hiển thị của khoản rút** — số tiền và tiến độ đúng, chỉ dấu và màu sai.

Đụng vào giao diện hoặc điều hướng thì **phải chạy máy ảo**. Xem `CLAUDE.md`,
mục "Ghi chú về kiểm thử".

---

## 10. Đối chiếu với app khác trên thị trường

**Khảo sát 2026-09-08.** Đây là lần khảo sát **thứ hai**; lần đầu (2026-09-05)
nằm trong `docs/superpowers/backend/DA-XONG/2026-09-05-backend-goal-priority.md`
mục 1 và chỉ rút ra hai việc (làm tròn số lẻ, ưu tiên mục tiêu). Lần này đi rộng
hơn và xếp hạng lại.

App đã xem: YNAB, Monarch Money, Copilot; Monzo, Revolut, Starling; Qapital,
Acorns; và phía Việt Nam là Money Lover, MISA MoneyKeeper, MoMo. Nguồn ở cuối
mục.

### 10.1 Chỗ FlowMoney đã mạnh — đừng "sửa" hai thứ này

**Tiền di chuyển thật.** Mỗi lần nạp ghi đúng một giao dịch `type='transfer'`
mang cả ví nguồn lẫn ví đích, trong một `db.transaction` nguyên tử (mục 3.2).
Money Lover, MISA MoneyKeeper và phần lớn app quản lý chi tiêu cùng loại chỉ coi
mục tiêu là **một con số đếm tiến độ**, không đụng tới số dư ví. Nhóm ngân hàng
số (Monzo Pots, Revolut Vaults, Starling Spaces) thì có chuyển tiền thật — và
FlowMoney đứng cùng nhóm đó, không đứng nhóm trên.

**Không tự hoà giải tiến độ với số dư ví** (mục 3.4). Monarch đi tới **cùng một
kết luận** sau ba đời tính năng: bản Goals 3.0 của họ gọi việc dời tiền là *fund
allocations* — người dùng tự dời, app chỉ đối chiếu và báo. Họ có thêm một lựa
chọn "khoán trọn một tài khoản cho một mục tiêu" (`fully allocating an account`)
để tự đồng bộ số dư, nhưng đó là **lựa chọn phụ**, không phải mặc định. Ai định
"dọn dẹp" mục 3.4 thành tự trừ tiến độ nên đọc dòng này trước.

### 10.2 Ba cơ chế tự động hoá chưa có

| Cơ chế | Ai làm | FlowMoney |
|---|---|---|
| **Làm tròn số lẻ** — mỗi khoản chi làm tròn lên, phần lẻ vào mục tiêu | Monzo Roundups, Revolut, Qapital, Acorns | ⛔ chưa |
| **Chia thu nhập** — lương về thì tách theo tỉ lệ vào từng mục tiêu | Monzo *Salary Sorter*, Qapital *Payday Divvy* | ⛔ chưa |
| **Quy tắc theo hành vi** — chi ở chỗ X thì trích thêm; tiêu dưới hạn mức thì phần dư vào tiết kiệm | Qapital *Guilty Pleasure*, *Spend Less* | ⛔ chưa |

⚠️ **Cả ba đều là "app chuyển tiền khi người dùng vắng mặt"**, tức cùng loại với
trích tự động (mục 3.12) và tự trả hoá đơn. Làm bất kỳ cái nào thì phần lớn
thiết kế là về việc **dừng đúng lúc**, không phải về việc chuyển: ví thiếu thì
bỏ qua chứ đừng chuyển một phần, phải có trần mỗi lượt, và phải hoàn tác được.
Đi qua `depositToGoal` chứ đừng tự ghi — cùng lý do đã ghi ở mục 3.12.

### 10.3 Quản lý nhiều mục tiêu

- **Ưu tiên và phân bổ theo thứ tự.** Monarch cho gán priority cho từng mục tiêu.
  FlowMoney sắp cứng theo hạn gần nhất (`chiaMucTieu`), nên người dùng không nói
  được "quỹ khẩn cấp quan trọng hơn cái laptop". Cột `Priority` phía backend
  **đã có từ 2026-09-07**; quy ước giá trị đã chốt sẵn ở tài liệu backend mục 4.
- **Chuyển tiền giữa hai mục tiêu.** Monarch *fund allocations* làm một thao tác.
  FlowMoney phải rút về ví rồi nạp sang — hai giao dịch cho một ý định.
- **Loại mục tiêu thứ hai: trả nợ.** Monarch Goals 3.0 tách *Save Up* và *Pay
  Down*, kèm hai chiến lược Avalanche (lãi cao trước) và Snowball (dư nợ nhỏ
  trước). FlowMoney chỉ có danh mục `Trả nợ`/`Thu nợ`, không có thực thể nợ.
  **Đây là cả một loại thực thể mới** — không nên gộp vào bảng `Goals`.

### 10.4 Động lực

- **Cột mốc.** Hầu hết app báo ở 25/50/75%. FlowMoney chỉ báo ở **100%**
  (`goalCompleted`) và khi **chậm tiến độ** (`goalBehind`) — người dùng đi ba
  phần tư chặng đường mà app im lặng. Rẻ nhất trong mọi việc ở mục này.
- **Khoá mục tiêu.** Monzo *locked pots*: khoá theo thời hạn, nạp vào được nhưng
  không rút ra. FlowMoney cho rút tự do (chỉ chặn bằng hai trần ở mục 3.5).
- **Nhiều kiểu mục tiêu.** YNAB có **ba** kiểu: góp đều mỗi kỳ (không có đích),
  đạt đích trước ngày X, và bù đầy tới một mức. FlowMoney chỉ có kiểu thứ hai —
  `targetAmount` và `targetDate` đều bắt buộc — nên "tháng nào cũng để dành 2
  triệu, không có đích" hiện **không diễn đạt được**.
- **Nhãn phân loại mục tiêu.** Thiết kế Stitch *có* nhãn trên mỗi thẻ ("THIẾT BỊ
  LÀM VIỆC", "AN TOÀN TÀI CHÍNH"); bản dựng chưa làm.

### 10.5 Xếp hạng, và lý do xếp như vậy

| Hạng | Việc | Vì sao ở đây |
|---|---|---|
| ✅ | ~~**Ưu tiên mục tiêu**~~ | **Xong 2026-09-08** — schema v19, mục **3.22**. Kiểm trọn vòng trên máy ảo, `Priority` 100/200 đã lên PostgreSQL |
| ✅ | ~~**Cột mốc 25/50/75%**~~ | **Xong 2026-09-08** — `goalMilestone`, mục **3.21** |
| ✅ | ~~**Đưa mục tiêu lên màn hình chính**~~ | **Xong 2026-09-08** — `HomeGoalCard`, chọn mục tiêu **ưu tiên nhất**. Cùng lượt **gỡ khối thông báo** khỏi trang chủ theo yêu cầu người dùng |
| ✅ | ~~**Trang chi tiết thiếu nội dung**~~ | **Xong 2026-09-08** — khối "Cấu hình" bốn dòng, và **sửa lỗi hộp dự báo** ngoại suy từ vài ngày. Mục **3.23** và **3.7** |
| 2 | **Làm tròn số lẻ** | Giá trị cao và hợp văn hoá "nuôi heo đất", nhưng là chỗ **thứ ba** app tự chuyển tiền — xem cảnh báo ở 10.2 |
| 2 | **Chuyển giữa hai mục tiêu** | Một hàm gọi `withdraw` + `deposit` trong cùng khối nguyên tử |
| 3 | **Chia thu nhập theo ưu tiên** | Cần ưu tiên xong trước |
| 3 | **Khoá mục tiêu**, **kiểu mục tiêu góp đều** | Đổi bất biến của `targetAmount`/`targetDate` — không còn là việc nhỏ |
| — | **Mục tiêu trả nợ** | Ngoài phạm vi đồ án |

**Nguồn:** [Monarch — Introducing Goals 3.0](https://help.monarch.com/hc/en-us/articles/44373110771860-Introducing-Goals-3-0) ·
[Monarch — Using Save Up Goals](https://help.monarch.com/hc/en-us/articles/44373182867476-Using-Save-Up-Goals) ·
[YNAB — Getting Started with Targets](https://support.ynab.com/en_us/getting-started-with-targets-ryAEP08xC) ·
[Monzo — Roundups on pots](https://monzo.com/ie/help/managing-money/help-roundups) ·
[Monzo — Locking Pots](https://monzo.com/help/budgeting-overdrafts-savings/what-are-locked-pots) ·
[Qapital — The Rules](https://www.qapital.com/blog/save-money-qapital-rules/) ·
[Trophy — How to Gamify a Savings App](https://trophy.so/blog/gamify-a-savings-app) ·
[NerdWallet — Best Budget Apps](https://www.nerdwallet.com/finance/learn/best-budget-apps) ·
[So sánh Sổ Thu Chi MISA và Money Lover](https://premiumvns.com/so-sanh-so-thu-chi-misa-va-money-lover/)
