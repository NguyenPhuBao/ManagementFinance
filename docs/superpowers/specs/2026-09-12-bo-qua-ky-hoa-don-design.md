# Bỏ qua kỳ hoá đơn (`Pay_status = 'Skipped'`) — thiết kế

**Ngày:** 2026-09-12 · **Phạm vi:** `src/Client-app` · **Trạng thái:** ✅ **đã
duyệt và đã làm xong 2026-09-12**

> **Đã thực hiện:** tám hạng mục, chín commit từ `1e87876` trên `TranQuangDat`,
> cộng một lượt soát tài liệu rộng ngay sau. `flutter test` **2211/2211**, `flutter analyze` **25 issue /
> 0 error** (mức nền). Kế hoạch thực thi:
> `docs/superpowers/plans/2026-09-12-bo-qua-ky-hoa-don.md`; bàn giao chi tiết ở
> mục **6.7** `docs/bill/BILL_DOCUMENTATION.md`.
>
> ⚠️ **Một chỗ spec này KHÔNG lường trước**, chỉ máy ảo lộ ra: mục 5 chỉ nói tới
> trang chi tiết, nên **dòng trên tab Lịch sử của trang danh sách** vẫn suy *hai*
> trạng thái và bày nút "Thanh toán" cho kỳ `Skipped` — bấm vào là bị repository
> từ chối. Vá ở `e2d7fd0` bằng nhánh thứ ba `daBoQua`. Bài học: "nút chỉ đặt ở
> trang chi tiết" **không** kéo theo "trang danh sách không phải đổi gì".

Bước **9** trong thứ tự người dùng đã duyệt (mục "🚀 Bắt đầu từ đâu ở phiên
sau", `docs/PROJECT_CONTEXT.md`). Backend **đã xong phần của mình** từ
2026-09-11; đây thuần tuý là việc phía client.

---

## 1. Vấn đề

Hoá đơn lặp có những kỳ **không phải trả**: đi vắng cả tháng nên không có tiền
điện, chủ nhà miễn một tháng, gói dịch vụ tặng kỳ. Client hôm nay chỉ có ba giá
trị `Pending` / `Payed` / `Overdue`, nên người dùng đứng trước hai lựa chọn đều
sai:

- **Trả giả** — bấm Thanh toán với số tiền nhỏ. Sổ giao dịch có một khoản chi
  không có thật, thống kê theo danh mục lệch, ngân sách bị trừ oan. Mà thực ra
  cũng không làm được: `payBill` từ chối số tiền `<= 0`
  (`BillInvalidAmountException`).
- **Xoá kỳ** — mất mắt xích `generatedFromBillId`. Kỳ kế tiếp **không được sinh
  ra**, vì chỉ `payBill` mới sinh kỳ sau. Người dùng phải tạo lại hoá đơn từ
  đầu, và mất luôn lịch sử chuỗi.

Nói cách khác: app hiện **không có cách nào** để nói "kỳ này bỏ, chuỗi vẫn
chạy".

## 2. Đối chiếu app thị trường

Khảo sát ngày 2026-09-12. **Kết quả mỏng hơn mong đợi, ghi lại đúng như đo
được** để người sau không phải tìm lại:

| App | Có "bỏ qua một kỳ"? | Nguồn |
|---|---|---|
| **Bill Panda** | **Có, gọi đích danh** — "mark bills as paid, add notes, **skip bills**, change amounts" | Trang App Store của app |
| **YNAB** | **Không có khái niệm ấy.** Giao dịch định kỳ chỉ ghi vào sổ rồi nhảy sang kỳ sau | Tài liệu YNAB |
| **Money Lover** | **Chưa xác nhận được.** Tài liệu chính thức (`note.moneylover.me`, Zendesk) mô tả hoá đơn và giao dịch định kỳ nhưng **không nhắc** nút bỏ qua | Tài liệu Money Lover |
| **Wallet (BudgetBakers)** | **Chưa xác nhận được** — như trên | — |

⚠️ Tài liệu backend `DA-XONG/2026-09-06-bill-chuoi-ky-va-an-han.md` mục 7.1 viết
"Money Lover và Wallet đều có *Skip this one*". **Lượt khảo sát này không xác
nhận được câu ấy bằng nguồn ngoài.** Đừng chép lại nó như sự thật đã kiểm.

**Kết luận dùng được:** mô hình *bỏ qua một lần xuất hiện, chuỗi không đứt* là
chuẩn mực có thật (Bill Panda; và rộng hơn là "skip occurrence" của mọi ứng dụng
lịch), nhưng **không có app nào đủ phổ biến để bắt chước nguyên xi phần hiển
thị** — phần đó dự án tự quyết, và đã quyết ở mục 3.

## 3. Quyết định đã chốt với người dùng

| Câu hỏi | Chốt | Ghi chú |
|---|---|---|
| Kỳ bỏ qua hiện ở đâu? | Tab thứ hai, và **tab đổi tên thành "Lịch sử"** | Tên cũ "Đã thanh toán" nói sai về một kỳ chưa hề được trả |
| Nút đặt ở đâu? | **Chỉ trang chi tiết `/bills/:id`** | Không thêm menu trên dòng danh sách, không thêm vào bảng thanh toán |
| Stitch? | **Dựng cả màn chi tiết lên Stitch**, ba màn | Trang chi tiết vốn chưa bao giờ có màn Stitch (dựng thẳng 2026-09-06) |
| Có sinh kỳ kế tiếp không? | **Có** | Đó chính là lý do tính năng tồn tại (mục 1) |

## 4. Miền: một định nghĩa duy nhất

### 4.1. Vì sao phải tách

Hôm nay toàn app hỏi *"đã trả chưa?"* bằng đúng một biểu thức
`isPaid || payStatus == 'Payed'` (và các biến thể SQL của nó), **chép tay ở 10
chỗ thuộc 7 tệp** — đếm bằng script ngày 2026-09-12:

| # | Chỗ | Dạng | `Skipped` làm gì nếu không sửa |
|---|---|---|---|
| 1 | `features/bill/domain/bill_status.dart:26` `_daTra` | Dart | Kỳ bỏ qua nằm tab "Cần thanh toán", cộng vào tổng nợ |
| 2 | `core/database/daos/other_daos.dart:149` `getUpcoming` | SQL | Bộ quét thông báo vẫn lôi nó ra |
| 3 | `core/database/daos/other_daos.dart:221` `markOverdue` chiều đi | SQL | **An toàn sẵn** — lọc đúng `'Pending'` |
| 4 | `core/database/daos/other_daos.dart:234` `markOverdue` chiều về | SQL | **An toàn sẵn** — lọc đúng `'Overdue'` |
| 5 | `core/notification/notification_rules.dart:312` | Dart | Nhắc trả một kỳ người dùng đã chủ động bỏ |
| 6 | `core/notification/reminder_scheduler.dart:128` | Dart | Đặt lịch thông báo cấp hệ điều hành cho kỳ ấy |
| 7 | `core/sync/sync_engine.dart:832` nhánh pull | Dart | **Đúng sẵn** — `'Skipped'` cho `isPaid = false` |
| 8 | `features/bill/data/repositories/bill_repository_impl.dart:71` chốt của `payBill` | Dart | **Trả được kỳ đã bỏ qua → sinh kỳ trùng.** Xem 4.5 |
| 9 | `.../bill_repository_impl.dart:158` chốt của `undoPayment` | Dart | Từ chối đúng (kỳ bỏ qua không có gì để hoàn) |
| 10 | `features/bill/domain/bill_auto_pay.dart:58` `denLuotTuTra` | Dart | **Tự động trừ tiền ví** cho kỳ người dùng đã bỏ |

Ba chỗ (3, 4, 7) đã đúng sẵn **do may**, không do thiết kế. Chép tay một biểu
thức ra 10 nơi rồi trông vào may mắn là đúng loại hỏng im lặng mà `CLAUDE.md`
quy tắc 4 nói tới.

Vì thế chỗ 3 và 4 **vẫn được sửa** dù hành vi không đổi: chúng chuyển sang dùng
hằng của 4.3 thay cho chuỗi viết thẳng, để lần sau có ai thêm giá trị thứ năm
thì `grep` một tên hằng là ra hết, không phải đoán. Chỗ 7 giữ nguyên — nó so với
`kBillPayed` theo đúng nghĩa "đã trả", chỉ thay chuỗi bằng hằng.

### 4.2. Hai câu hỏi, không còn là một

Với `Skipped`, câu "đã trả chưa" **tách làm hai** và chúng không trùng nhau nữa:

| | `Pending` | `Payed` | `Overdue` | `Skipped` |
|---|---|---|---|---|
| **Còn phải trả?** — nhắc, tự trả, tổng nợ, `markOverdue`, `getUpcoming` | có | không | có | **không** |
| **Đã có khoản chi?** — hoàn tác, dòng "Trả dd/MM", tra `transactions.billId` | không | có | không | **không** |

### 4.3. Tệp mới `lib/features/bill/domain/bill_pay_status.dart`

Cùng khuôn với `wallet/domain/wallet_type.dart` và
`analytics/domain/khoan_vao_thong_ke.dart` — Dart thuần, không phụ thuộc
Flutter, để `core/` import được:

- **Bốn hằng chuỗi** `kBillPending`, `kBillPayed`, `kBillOverdue`,
  `kBillSkipped`. Hằng là **bắt buộc**, không phải trang trí: `getUpcoming` và
  `markOverdue` là **truy vấn SQL**, không gọi được vị từ Dart — chúng chỉ dùng
  được hằng.
- **Ba vị từ** — `daCoKhoanChi(Bill)` (đọc **cả hai** cột `isPaid`/`payStatus`,
  vì hàng do bản client cũ ghi hoặc kéo về từ backend có thể lệch hai cột),
  `daBoQua(Bill)`, và `conPhaiTra(Bill)` = `!daCoKhoanChi && !daBoQua`.
  > Bản đầu của mục này ghi "**hai** vị từ" và bỏ sót `daBoQua`. Mã đã viết có
  > **ba** — `daBoQua` cần đứng riêng vì `billDisplayStatusOf` và `undoSkip` hỏi
  > đúng câu ấy, không hỏi "còn phải trả không".

Giá trị lạ (không thuộc bốn) đọc là **còn phải trả** — an toàn hơn im lặng bỏ
qua một khoản nợ thật.

### 4.4. Trạng thái hiển thị thứ năm

`BillDisplayStatus` thêm `skipped`. Trong `billDisplayStatusOf`, nhánh này phải
đứng **trước mọi phép so ngày**, ngay cạnh nhánh `paid` — nếu không, một kỳ bỏ
qua đã quá ngày đến hạn sẽ đọc ra `overdue`.

### 4.5. Hai thao tác mới ở repository

**`skipBill({required String billId})`**

1. Đọc lại hàng từ CSDL (không tin ảnh chụp UI — cùng lý do với `payBill`).
2. Từ chối nếu đã `Payed` (`BillAlreadyPaidException`) hoặc đã `Skipped`
   (`BillAlreadySkippedException`, mới).
3. Trong **một** transaction: đặt `payStatus = 'Skipped'`, `isPaid = false`,
   `syncStatus = 'pending'`, `updatedAt = now`; rồi **nếu `isRecurrence`** thì
   sinh kỳ kế tiếp bằng chính `_nextPeriodOf` — dùng lại hàm sẵn có, không viết
   bản thứ hai của luật tính ngày.
4. **Không** sinh giao dịch, **không** đụng số dư ví.
5. `syncEngine?.scheduleSync()`.

Số tiền truyền vào `_nextPeriodOf` là `current.amount` (số ghi trên hoá đơn),
không phải "số vừa trả" — vì không có lần trả nào.

**`undoSkip({required String billId})`**

1. Từ chối nếu không phải `Skipped` (`BillNotSkippedException`, mới).
2. Trong một transaction: xoá mềm kỳ kế tiếp đã sinh (`getGeneratedFrom`), rồi
   đưa hàng về `Pending`. Không có bước hoàn tiền — chưa từng trừ tiền.

Đưa về `Pending` chứ không `Overdue`: `markOverdue` chạy sau mỗi lần đồng bộ và
tự gắn lại cờ nếu kỳ đã trễ. Tự đoán ở đây là dựng bản thứ hai của luật ấy.

**Chốt chặn phải thêm vào `payBill`** — bỏ là mất tiền thật. Một kỳ `Skipped`
**đã sinh kỳ kế tiếp rồi**. Để `payBill` chạy tiếp trên nó là sinh **kỳ thứ hai
trùng**, và người dùng có hai hoá đơn cùng hạn mà không hiểu vì sao. Nên
`payBill` từ chối `Skipped` bằng ngoại lệ riêng, thông báo nói rõ: hoàn tác bỏ
qua trước đã.

**Hoá đơn không lặp** vẫn bỏ qua được, và không cần luật riêng: lời gọi
`_nextPeriodOf` vốn đã nằm sau `if (current.isRecurrence)`. Bỏ qua một hoá đơn
một lần nghĩa là "khoản này được miễn" — khác xoá ở chỗ nó vẫn nằm trong lịch
sử.

### 4.6. Thẻ tổng đầu trang

`summarizeBills` **không tính kỳ `Skipped` vào cả hai vế**. Cộng nó vào
`paidAmount` sẽ thổi phồng thanh tiến độ bằng số tiền chưa bao giờ chi ra — đúng
loại lỗi mà thanh hằng số `0.66` ngày trước đã gây ra, chỉ tinh vi hơn.

## 5. Giao diện

### 5.1. Trang danh sách `bill_page.dart`

- Tab 2: `Đã thanh toán (n)` → **`Lịch sử (n)`**.
- Câu khi tab 2 rỗng: `Chưa có hoá đơn nào được thanh toán.` → `Chưa có kỳ nào
  đã đóng.`
- `splitBills` đẩy kỳ `Skipped` vào nhóm thứ hai, xếp theo hạn mới nhất lên đầu
  như hiện nay. Phép chia đổi từ `_daTra(b)` sang `!conPhaiTra(b)`.
- **Đổi tên trường `BillSections.paid` → `daDong`, `unpaid` → `chuaDong`.**
  Cùng lý do với việc đổi tên tab: nhóm ấy không còn chỉ chứa kỳ đã trả, nên cái
  tên nói sai. Chỉ có **một** nơi đọc hai trường này (`bill_page.dart:150`), nên
  đây là phép đổi tên rẻ — để nguyên mới là nợ.
  > Bản đầu của mục này đề nghị `unpaid` → `conPhaiTra`; **không dùng** vì tên ấy
  > trùng với vị từ cấp thư viện `conPhaiTra(Bill)` và che nó trong thân lớp.
  > Mã đã viết dùng `chuaDong`.

### 5.2. Nhãn trạng thái `bill_status_visuals.dart`

Bốn hàm `switch` thêm nhánh thứ năm, nhãn **`BỎ QUA`**, tông **xám trung
tính** — nó không phải thắng lợi như "đã trả", cũng không phải cảnh báo như
"quá hạn". Trong tab "Lịch sử" nó luôn đứng cạnh nhãn xanh nên xám là đủ phân
biệt. **Tông chính xác do màn Stitch chốt** (mục 6).

### 5.3. Trang chi tiết `bill_detail_page.dart`

`_nutThaoTac` từ hai nhánh thành ba:

| Trạng thái kỳ | Nút |
|---|---|
| `paid` | `Hoàn tác thanh toán` — viền, như hiện nay |
| **`skipped`** | **`Hoàn tác bỏ qua`** — viền |
| còn lại | `Thanh toán` (nền đậm) **+ `Bỏ qua kỳ này`** (viền, xám, **xếp dưới**) |

⚠️ Hai nút **xếp dọc trong `Column`, tuyệt đối không đặt trong `Row`** — bẫy
**4.11** của `docs/ANALYTICS_FEATURE.md`: theme của app ép mọi `ElevatedButton`
rộng vô hạn, nút trần trong `Row` làm **trắng cả trang** mà không một dòng log
nào.

Khối "LỊCH SỬ CÁC KỲ": dòng phụ của kỳ bỏ qua ghi `Bỏ qua`, chấm tròn xám.

Khoá widget mới: `bill-detail-skip`, `bill-detail-undo-skip`.

### 5.4. Hai hộp thoại trong `bill_actions.dart`

Cùng khuôn với `hoiHoanTacHoaDon` đang có — "bỏ qua" cũng có nhiều hệ quả nên
phải nói rõ **trước**:

- `hoiBoQuaKyHoaDon` — nêu ba điều: **không trừ tiền ví**, **không ghi khoản chi
  nào**, và (chỉ khi `isRecurrence`) **kỳ kế tiếp vẫn được tạo**.
- `hoiHoanTacBoQua` — nêu: kỳ này quay lại trạng thái chưa thanh toán, và (chỉ
  khi `isRecurrence`) kỳ kế tiếp đã tạo sẽ bị gỡ.

Câu chữ phải đúng theo `isRecurrence`, không nói "và gỡ kỳ kế tiếp" cho một hoá
đơn không lặp — `hoiHoanTacHoaDon` đã làm đúng như vậy, theo nó.

## 6. Stitch

Dự án `FlowMoney` (`projects/5106367939423432838`), design system **"Kinetic
Finance"**, thiết bị MOBILE 390dp. Ba màn:

1. **`Chi tiết hoá đơn`** — vẽ đúng trang đang chạy: thẻ đầu (icon danh mục, tên,
   `Hạn dd/MM/yyyy`, số tiền cỡ lớn, nhãn trạng thái), thẻ `THÔNG TIN` bảy dòng
   (Đến hạn, Chu kỳ, Ví trả, Danh mục, Nhắc trước, Tự động trả, Ghi chú), thẻ
   `LỊCH SỬ CÁC KỲ`, rồi **hai nút xếp dọc**. Đây cũng là vá lỗ hổng thiết kế có
   từ 2026-09-06 — trang này chưa bao giờ lên Stitch.
2. **`Chi tiết hoá đơn — kỳ đã bỏ qua`** — cùng trang, sau khi bỏ qua: nhãn
   `BỎ QUA`, một nút `Hoàn tác bỏ qua`. Màn này là nơi chốt **tông xám** của
   nhãn.
3. **`Xác nhận bỏ qua kỳ`** — hộp thoại, cùng kiểu với màn `Xác nhận xóa hóa
   đơn` đã có sẵn trong dự án.

Màu lấy trong `bill_status_visuals.dart` sau khi Stitch chốt, **không** tự chế
màu ngoài bảng của design system.

## 7. Đồng bộ — không thêm trường nào

`pay_status` **đã** nằm trong payload đẩy (`sync_engine.dart:1241`) và đã bị
khoá trong `sync_payload_contract_test.dart`. `SyncPayloadNormalizer` không đụng
tới nó. Nhánh kéo về đã đúng sẵn: `isPaid: Value(payStatus == 'Payed')` cho
`Skipped` ra `false`. **Payload hoá đơn vẫn 19 trường** (đếm 2026-09-12; tối cùng ngày lên **20** với `period_end` — ân hạn).

**Đo thật hai đầu ngày 2026-09-12** (chỉ đọc, không ghi):

- `chk_bill_pay_status` trên PostgreSQL:
  `CHECK (Pay_status = ANY (ARRAY['Pending','Payed','Overdue','Skipped']))` —
  **nhận**.
- Cột `bill."Pay_status"` là `character varying(7)`; `'Skipped'` đúng **7** ký
  tự, vừa khít. Không cần migration.
- `sync.validation.js:169` có `['Pending', 'Payed', 'Overdue', 'Skipped']` —
  **nhận**.
- Phân bố hiện tại trên CSDL dev: 12 `Pending`, 4 `Payed`, 0 `Skipped`.

Giá trị mới thì chưa test nào canh, nên vẫn thêm hai ca vào bộ hợp đồng: đẩy
`'Skipped'` đi **nguyên văn**, và kéo về `'Skipped'` cho `isPaid = false`.

**Không** đổi schema Drift — `payStatus` đã là `TextColumn`. Schema giữ **v20**.

## 8. Kiểm thử

Test đỏ trước, theo `superpowers:test-driven-development`. Mỗi assertion ghi rõ
trong `reason:` nó canh chừng điều gì.

| Tệp | Canh chừng |
|---|---|
| `test/features/bill/domain/bill_pay_status_test.dart` *(mới)* | **Ba** vị từ trên cả bốn giá trị; hàng lệch cột (`Payed` mà `isPaid` false, và ngược lại); giá trị lạ đọc là còn phải trả **và không** đọc là bỏ qua. **7** ca (bản đầu của mục này đoán 8) |
| `test/features/bill/domain/bill_status_test.dart` | Trạng thái thứ năm; kỳ `Skipped` **đã quá ngày hạn** vẫn đọc ra `skipped`; `splitBills` đẩy vào nhóm thứ hai; `summarizeBills` không tính vào **cả hai** vế |
| `test/features/bill/data/repositories/bill_skip_test.dart` *(mới)* | `skipBill` sinh kỳ sau, **không** đụng số dư ví, **không** sinh giao dịch nào; `undoSkip` xoá mềm kỳ sau và đưa về `Pending`; `payBill` từ chối kỳ `Skipped`; `skipBill` từ chối kỳ `Payed` và kỳ `Skipped`; hoá đơn **không lặp** thì không sinh kỳ nào |
| `test/core/database/bill_overdue_test.dart` | `markOverdue` **không đụng** `Skipped` ở **cả hai** chiều; chạy hai lần không đổi gì (chống vòng lặp đẩy) |
| `test/core/database/bill_upcoming_test.dart` | `getUpcoming` loại `Skipped` |
| `test/core/notification/` (2 tệp) | Luật không sinh nhắc cho kỳ `Skipped`; `ReminderScheduler` không đặt lịch cấp hệ điều hành cho nó |
| `test/features/bill/domain/bill_auto_pay_test.dart` | `denLuotTuTra` trả `false` cho `Skipped` kể cả khi công tắc đang bật và đã tới ngày |
| `test/features/bill/presentation/pages/bill_detail_page_test.dart` | Ba nhánh nút; dựng ở **411dp** và bắt tràn bằng `tester.takeException()` |
| `test/features/bill/presentation/pages/bill_page_test.dart` | Tab đổi tên; kỳ `Skipped` nằm tab 2, không nằm tab 1; không cộng vào tổng nợ |
| `test/core/sync/sync_payload_contract_test.dart` | Hai ca ở mục 7 |

⚠️ `.gitignore` chặn `test/` (dòng 78) — mọi tệp test mới phải `git add -f`
**từng đường dẫn một**; `git add src/Client-app/test` thất bại toàn lệnh.

## 9. Ba rủi ro, và cách đóng từng cái

1. **Trả hai lần một kỳ → sinh kỳ trùng.** Đóng bằng chốt chặn trong `payBill`
   (4.5) và bằng việc trang chi tiết không bày nút Thanh toán cho kỳ `Skipped`.
   Có test cả hai lớp.
2. **Kẹt hàng đợi đẩy vĩnh viễn, im lặng.** Đã đo hai đầu ở mục 7. Vẫn kiểm lại
   đầu-cuối trên máy ảo kèm truy vấn PostgreSQL **đọc**, đúng cách bước 8 đã
   làm.
3. **Bộ test xanh mà tính năng hỏng.** Bài học đắt nhất của phiên 2026-09-12:
   Phần 1 cưỡng chế đăng xuất có 63 ca xanh mà hộp thoại vẫn không hiện trên máy
   thật, phải ba lượt kiểm mới đóng được. Ở đây nút thứ hai làm thẻ cao thêm ở
   **411dp** trong khi `flutter test` chạy 1280px. **Kiểm trên máy ảo là bắt
   buộc trước khi báo xong.**

## 10. Ngoài phạm vi, cố ý

- **`Period_end`** (ân hạn, kỳ tính tiền tách khỏi hạn trả) — bước **14** riêng,
  cần schema **v21**. ✅ Xong tối 2026-09-12: spec `2026-09-12-bill-an-han-period-end-design.md`.
- **`Auto_pay` qua đồng bộ** — bước **12**, chờ backend đặt chốt chống trả hai lần ở
  `upsertTransaction` (CAN-LAM 17 B bước 2; bước 1 — bỏ chốt sai chỗ — xong 2026-09-12).
- **Menu bỏ qua ngay trên dòng danh sách** — người dùng chốt chỉ trang chi tiết.
- **Đếm số kỳ đã bỏ qua** ở đâu đó trong Phân tích — chưa ai xin, không tự thêm.

## 11. Tài liệu phải cập nhật khi xong

- `docs/bill/BILL_DOCUMENTATION.md` — mục 6.6 việc 4, và dòng "Bỏ qua kỳ này
  (`Skipped`)" ở bảng "còn mở".
- `docs/PROJECT_CONTEXT.md` — mục 14 (khối mới) và mục "🚀 Bắt đầu từ đâu ở phiên
  sau" (bước 9 xong).
- `CLAUDE.md` — hàng "Đụng vào hoá đơn": trạng thái thứ năm và định nghĩa duy
  nhất ở `bill_pay_status.dart`.
- Lượt soát **rộng**: `grep` toàn `docs/` theo cụm "bốn trạng thái", "Đã thanh
  toán", "ba giá trị" — các con số ấy đều vừa đổi.
