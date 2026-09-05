# Mục tiêu tiết kiệm — thiết kế, lý do, và những cái bẫy

**Cập nhật:** 2026-09-05
**Trạng thái:** hoạt động đầy đủ trên client. Một việc chờ backend (mục 8).

> **Mục đích của tài liệu này** giống `CATEGORY_RATIONALE.md`: giữ lại **vì sao**,
> không phải **cái gì**. Cái gì thì đọc mã và test là ra; vì sao thì mất theo
> phiên làm việc. Mọi quyết định dưới đây đều có một phương án khác nghe hợp lý
> hơn lúc đầu, và mục 3 ghi lý do loại nó.

---

## 1. Đọc gì trước khi đụng vào

| Việc | Đọc |
|---|---|
| Bất cứ việc gì | Mục 3 (quyết định + lý do) và mục 4 (**bảy cái bẫy**) |
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

Trang chi tiết **không nghe dòng dữ liệu** (bẫy 4.5) nên phải tự `_loadGoal()`
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

Nay ba mảnh ấy đều được lưu (ba cột **cục bộ**, mục 5), và
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
là *"thời điểm cụ thể trích tiền trong chu kỳ"*, nó đã nằm sẵn trong 18 khoá của
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

⚠️ **Nhịp bước từng kỳ một từ mốc neo**, nên mốc rơi vào ngày 31 sẽ bị kẹp về
28/02 rồi bước tiếp **từ đó** — tức nhịp trôi dần chứ không quay lại ngày 31.
Bảng chọn ngày báo trước điều này.

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

**Ba cột kia vẫn là cục bộ**, nên cấu hình trích tự động **không theo người dùng
sang máy khác**. Chu kỳ thì có (nó vốn đã đồng bộ), nên trên máy mới mục tiêu vẫn hiện
đúng nhịp kế hoạch, chỉ là không tự trích. Thà vậy còn hơn hai máy cùng trích
một kỳ — đó cũng là lý do KHÔNG mượn cột `time_cycle_take_money` đang có sẵn:
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

---

## 4. Bảy cái bẫy

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

Yêu cầu backend: `docs/superpowers/backend/CAN-LAM/2026-09-05-backend-transaction-goal-id.md`.

### 4.5 `GoalDetailPage` **bỏ qua** cubit và không nghe dòng dữ liệu

Nó lấy `sl<GoalRepository>()` trong `initState` và tự giữ `_goal` trong `State`,
tự gọi `_loadGoal()` sau mỗi thao tác. Đồng bộ kéo về một thay đổi của mục tiêu
đang mở thì màn hình vẫn hiện số cũ. Trang danh sách thì ngược lại — nó nghe
`watchGoals` nên tự cập nhật.

### 4.6 Danh sách rỗng ở lần vào **đầu tiên** sau khi khởi động nguội

Tái hiện được nhiều lần. Trang dựng trước khi `AuthBloc` khôi phục xong phiên,
`currentAccountIdOrNull` trả `null`, rồi `?? 0` biến nó thành tài khoản 0 — và
`watchGoals(0)` đương nhiên rỗng. Thoát ra vào lại là thấy.

`?? 0` đúng ở chỗ nó **không** ghi nhầm vào tài khoản admin (bài học G4), nhưng
nó cũng không đợi phiên. Cần một trạng thái "đang chờ phiên" thay vì đọc luôn với
id 0.

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

Payload mục tiêu có **18 trường**. Hợp đồng đầy đủ ở
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
| Cấu hình trích tự động **không sang máy khác** | Ba cột `auto_deposit_*` là cục bộ. Chu kỳ và mốc neo thì có đồng bộ, nên máy mới hiện đúng nhịp kế hoạch mà không tự trích — càng dễ hiểu nhầm. **G21**, chặn ở backend |
| Không có bộ **lập lịch nền** | Giờ trong mốc trích chỉ giữ được chiều "không sớm hơn". Có lời nhắc AlarmManager nổ đúng giờ kể cả khi app đóng, nhưng nó chỉ báo tin. **G22** — cố ý, đừng "sửa" |
| Quy tắc trùng tên chỉ có ở **client** | `/sync/push` và PostgreSQL chưa kiểm gì — cùng tình trạng với danh mục. Xem mục 3.15 |
| **Ưu tiên mục tiêu** chưa có | Bảng `goal` phía backend không có cột nào cho việc này. Làm cột cục bộ thì mắc đúng bệnh G21 — thứ tự đặt trên máy này không sang máy khác |
| Ví nguồn trích tự động **mặc định trùng ví tích luỹ** | Biểu mẫu chọn sẵn ví tích luỹ làm ví nguồn, nên lần lưu đầu luôn bị `goal_deposit_wallets` từ chối. Không sai dữ liệu, chỉ là một bước thừa bắt người dùng tự sửa |

**Đã đóng ngày 2026-09-05** (giữ lại đây để không ai mở lại nhầm):

| Việc | Đóng bằng gì |
|---|---|
| ~~Không kiểm trùng tên mục tiêu~~ | Mục **3.15** — `_trungTen()` ở cả `addGoal` lẫn `updateGoal`, dùng chung `normalizeCategoryName()` |
| ~~Phép kiểm **số tiền** khi nạp chỉ ở giao diện~~ | Mục **3.16** — hai trần (`> 0` và `≤ số dư ví nguồn`) nằm trong khối nguyên tử |
| ~~Dải cảnh báo lệch chưa xem trên máy thật~~ | Mục **3.4** — đã dựng đúng ca và xem trên máy ảo Android |
| ~~Giao dịch trích **bù** mang dấu thời gian lúc bù~~ | Mục **3.14** — tham số `occurredAt` chặn hai đầu; **G20** đã đóng |

---

## 8. Việc phía backend

Đúng một tài liệu:
`docs/superpowers/backend/CAN-LAM/2026-09-05-backend-transaction-goal-id.md` — xin cột
nullable `transaction.Idgoal`. **Không chặn gì hôm nay**, nhưng chặn hướng bỏ bộ
đếm `current_amount` để suy tiến độ từ chính giao dịch.

> ⚠️ Tài liệu cũ `2026-08-23-backend-goal-wallet-id.md` xin cột `wallet_id` cho
> bảng `goal`. **Việc đó đã xong** — backend có `Idwallet` (tên khác với tên tài
> liệu xin). Tài liệu ấy không còn việc gì.

---

## 9. Kiểm thử

Khoảng **222 test** riêng cho mục tiêu, trên tổng 893 của dự án.

| Tệp | Canh gì |
|---|---|
| `goal_entity_progress_test.dart` | `progress`, `daysLeft`, `isBehindSchedule` — biên dung sai, chia 0, quá hạn |
| `goal_forecast_test.dart` | Ba hàm dự báo, kể cả các nhánh "không đủ căn cứ" |
| `goal_deposit_warning_test.dart` | `remainingAmount`, cảnh báo nạp vượt |
| `goal_deposit_default_wallets_test.dart` | Bất biến ví nguồn ≠ ví nhận |
| `goal_history_direction_test.dart` | **Bẫy 4.2** — đổi ví không làm khoản nạp cũ đọc thành rút |
| `goal_wallet_shortfall_test.dart` | Cảnh báo lệch, cộng dồn nhiều mục tiêu |
| `data/repositories/goal_repository_impl_test.dart` | Nạp, rút, đổi ví, nguyên tử, lịch sử |
| `presentation/widgets/goal_progress_test.dart` | Một định nghĩa duy nhất của tỉ lệ |
| `presentation/widgets/goal_appearance_test.dart` | Bảng tra biểu tượng/màu, dữ liệu rác, và **giá trị ngoài bảng chọn** |
| `goal_edit_form_test.dart` | `showDatePicker` với mục tiêu **quá hạn** — xem mục 3.9 |
| `goal_auto_deposit_test.dart` | Bước kỳ (tháng ngắn, **năm nhuận**), **mốc neo**, trần số kỳ, quyết định trích |
| `goal_auto_deposit_runner_test.dart` | Trích bù nhiều kỳ, ví cạn giữa chừng, cấu hình hỏng, cách ly tài khoản |
| `core/notification/reminder_scheduler_test.dart` | Lịch nhắc kỳ trích: đúng mốc kỳ, trùng khoá thông báo, và **không huỷ lịch hoá đơn** |
| `core/notification/notification_rules_goal_wallet_test.dart` | Hai luật thông báo |

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
