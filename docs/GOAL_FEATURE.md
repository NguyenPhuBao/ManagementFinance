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

Yêu cầu backend: `docs/superpowers/backend/2026-09-05-backend-transaction-goal-id.md`.

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
| Không có bộ **lập lịch** trích tiền | Khối "Tự động trích tiền định kỳ" nay lưu lại làm *kế hoạch*, nhưng công tắc vẫn không kích hoạt gì |
| Không kiểm trùng tên mục tiêu | Khác hẳn danh mục (có quy tắc rất chặt). Chưa rõ chủ ý hay bỏ sót |
| Phép kiểm **số tiền** khi nạp chỉ ở giao diện | Repository nhận bất kỳ giá trị nào. Các phép kiểm về **ví** thì đã có ở cả hai tầng |
| Thông báo dẫn về `/goals` | Không phải `/goals/<id>`, nên phải tự tìm lại mục tiêu |
| Dải cảnh báo lệch chưa xem trên máy thật | Hàm có 6 test; phần vẽ chưa gặp ca dữ liệu để hiện |

---

## 8. Việc phía backend

Đúng một tài liệu:
`docs/superpowers/backend/2026-09-05-backend-transaction-goal-id.md` — xin cột
nullable `transaction.Idgoal`. **Không chặn gì hôm nay**, nhưng chặn hướng bỏ bộ
đếm `current_amount` để suy tiến độ từ chính giao dịch.

> ⚠️ Tài liệu cũ `2026-08-23-backend-goal-wallet-id.md` xin cột `wallet_id` cho
> bảng `goal`. **Việc đó đã xong** — backend có `Idwallet` (tên khác với tên tài
> liệu xin). Tài liệu ấy không còn việc gì.

---

## 9. Kiểm thử

Khoảng **121 test** riêng cho mục tiêu, trên tổng 755 của dự án.

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
