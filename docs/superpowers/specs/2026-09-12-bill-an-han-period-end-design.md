# Hoá đơn: ân hạn — tách kỳ tính tiền khỏi hạn trả (`Period_end`)

**Ngày:** 2026-09-12 · **Trạng thái:** đã duyệt thiết kế trong chat (bảy phần), chờ người dùng soát tệp này
· **Bước:** 4 trong thứ tự người dùng duyệt chiều 2026-09-12 (sau G34) · **Schema:** v20 → **v21**

Tài liệu liên quan, đọc trước khi sửa: `docs/bill/BILL_DOCUMENTATION.md` (mục 2b "Lịch hoá đơn", mục 5
"Ngày gốc", mục 6 "Luồng thanh toán"), `docs/superpowers/backend/DA-XONG/2026-09-06-bill-chuoi-ky-va-an-han.md`
việc **C** (§4.1–4.4 — lý do xin cột và cái bẫy nếu làm nửa vời), và bộ test-như-tài-liệu của hoá đơn liệt kê ở
hàng "Đụng vào hoá đơn" của `CLAUDE.md`.

---

## 1. Vấn đề

Bảng `Bills` của client chỉ có hai mốc, `startDate` và `dueDate`, và cả app hiểu chúng là **hai đầu của cùng
một kỳ**: kỳ kế tiếp bắt đầu đúng tại `dueDate` của kỳ trước (`BillRepositoryImpl._nextPeriodOf`,
`startDate: Value(current.dueDate)`). Hệ quả: **tiền phải trả đúng ngày kỳ kết thúc**. Hoá đơn điện nước
thật không như vậy — kỳ tính tiền 01/09–30/09, hạn trả 15/10. Người dùng hôm nay chỉ có một cách: đặt hạn trả
làm mốc kết thúc kỳ, và con số "kỳ này" lệch so với hoá đơn giấy.

Server đã có cột `bill.Period_end` (`DateTime? @db.Date`, từ `database/12`, 2026-09-11); `/sync/push` nhận
khoá `period_end`, `/sync/pull` trả nó (`sync.repository.js:101-102, 443, 467`). Client **cố ý chưa làm** cho
tới khi có cột (cùng lối với `goal.Priority`), và người dùng chốt 2026-09-12 rằng đây là **tính năng**, không
phải một trường đồng bộ lẻ — vì phải đổi cả phép tính kỳ kế tiếp và giao diện.

### Cái bẫy nếu làm nửa vời (§4.4 tài liệu xin)

Thêm cột mà **không** đổi cách tính kỳ kế tiếp thì hoá đơn "kỳ 01–30/09, hạn 15/10" sinh kỳ sau bắt đầu
15/10 — hở nửa tháng, mỗi kỳ trôi thêm. Hai việc phải đi cùng nhau trong **một** đợt.

### Đối chiếu app thị trường (tra 2026-09-12)

Money Lover, TimelyBills, Copilot, Bills Reminder: hoá đơn chỉ có **một** mốc "ngày đến hạn" cộng nhắc trước.
PocketSmith có *grace period* nhưng theo nghĩa khác — vài ngày **sau** hạn vẫn hiện "sắp tới" thay vì "quá
hạn". Không app quản lý tài chính cá nhân nào tách kỳ tính tiền khỏi hạn trả. Hai hệ quả cho thiết kế:
đây là điểm FlowMoney đi trước, và ô nhập phải **mặc định = như cũ** để người không cần thì không phải nghĩ.

---

## 2. Quyết định đã chốt với người dùng

| # | Câu hỏi | Chốt |
|---|---|---|
| 1 | Người dùng nhập ân hạn thế nào? | **Số ngày sau khi kết thúc kỳ**: thanh chọn `0 · 7 · 15 · 30` + "Khác…" mở ô nhập số. Mặc định **0**. Ngày kết thúc kỳ và hạn thanh toán đều **tự tính, chỉ đọc**. Hai lựa chọn bị loại: chọn thẳng ngày hạn trả (phải kiểm thứ tự ngày và chép số ngày lệch sang kỳ sau), và "ngày cố định trong tháng" (chỉ có nghĩa với Tháng/Quý/Năm, cần luật kẹp cuối tháng thứ hai) |
| 2 | Mô hình dữ liệu | **Cột `periodEnd` (ngày), đồng bộ lên `bill.Period_end`.** Số ngày ân hạn không lưu, suy ra `dueDate − periodEnd`. Loại: cột `graceDays` cục bộ (máy khác kéo về sinh kỳ hở — bẫy §4.4 chuyển sang biên giới hai máy) và "cả hai cột" (hai nguồn sự thật) |
| 3 | Bảy phần thiết kế dưới đây | Duyệt nguyên văn ("ok duyệt") |

---

## 3. Mô hình dữ liệu — schema v21

```dart
/// Ngày KẾT THÚC KỲ TÍNH TIỀN. Hạn trả [dueDate] có thể muộn hơn (ân hạn).
///
/// NULL = hàng cũ, chưa biết — đọc là "kết thúc kỳ trùng hạn trả" (hành vi
/// trước v21). Hàng ghi MỚI luôn có giá trị, kể cả khi ân hạn 0 (khi ấy bằng
/// dueDate), để NULL chỉ còn một nghĩa. Đi qua đồng bộ: khoá `period_end`.
DateTimeColumn get periodEnd => dateTime().nullable()();
```

- **Migration v21:** `addColumn(bills, bills.periodEnd)`, **không đổi dữ liệu**. Hàng cũ giữ `NULL`.
- **Quy ước "NULL chỉ một nghĩa":** mọi đường ghi mới (`BillDraft.toCompanion`, `_nextPeriodOf`) ghi
  `periodEnd` **luôn luôn**, cả khi ân hạn 0. Nhờ đó nhánh kéo về dùng `Value.absent()` khi server trả `null`
  (như `anchor_day`, `previous_bill_id`) mà **không** nuốt mất lần người dùng hạ ân hạn về 0 trên máy khác —
  máy ấy đẩy `period_end = due_date`, không phải `null`.
- **Bất biến trên một hàng** (kiểm ở tầng domain, không phải CHECK SQLite): `startDate < periodEnd ≤ dueDate`,
  và `dueDate <` kết thúc kỳ **kế tiếp** (xem §4). Server ràng buộc gì thêm thì đo lại khi làm — tài liệu xin
  §4.3 chỉ đề nghị `Start_date < Period_end ≤ Due_date`.

---

## 4. Tầng domain — một định nghĩa duy nhất

### 4.1. `bill/domain/bill_an_han.dart` (mới, Dart thuần)

```dart
/// Số ngày ân hạn của một hàng: dueDate − periodEnd, tính theo NGÀY (bỏ giờ).
/// periodEnd NULL → 0. Đây là chỗ DUY NHẤT suy con số này từ hai cột.
int anHanCua(Bill b);

/// Hạn trả từ ngày kết thúc kỳ và số ngày ân hạn. Cộng NGÀY, không cộng
/// Duration(days:) qua mốc đổi giờ — dùng DateTime(y, m, d + n) trên đầu ngày.
DateTime hanTraTu(DateTime ketThucKy, int anHanNgay);

/// Lý do từ chối, hoặc null khi hợp lệ.
String? loiAnHan({required int anHanNgay, required DateTime ketThucKy,
    required DateTime ketThucKyKeTiep});
```

Ba luật của `loiAnHan`: (a) `anHanNgay < 0` → "Số ngày ân hạn không được âm"; (b) `anHanNgay > 365` → "Ân hạn
tối đa 365 ngày" (chặn gõ nhầm; ô nhập lọc 3 chữ số); (c) `hanTraTu(ketThucKy, anHanNgay)` **không** trước
`ketThucKyKeTiep` → "Hạn trả phải trước ngày kết thúc kỳ kế tiếp (dd/MM)". Luật (c) là chốt chống **hai kỳ
cùng mở**: ân hạn 45 ngày cho chu kỳ tháng nghĩa là kỳ 2 đã bắt đầu và kết thúc khi kỳ 1 còn chưa tới hạn — bộ
tự động thanh toán và thẻ tổng sẽ đếm hai khoản cùng lúc. Với chu kỳ **tuần**, luật (c) giới hạn ân hạn ở
6 ngày; đúng ý, không phải lỗi.

### 4.2. `BillSchedule` (form Thêm/Sửa)

Thêm trường `anHanNgay` (mặc định 0) và getter mới `ketThucKy`:

```
ketThucKy = nextBillDueDate(startDate, timeRecurrence, anchorDay: anchorDayHieuLuc)   // = dueDate hôm nay
dueDate   = hanTraTu(ketThucKy, anHanNgay)
```

- `dateError` gộp thêm `loiAnHan(anHanNgay, ketThucKy, nextBillDueDate(ketThucKy, …))`.
- `canhBaoHanCu` so hạn đã lưu với `dueDate` **đã cộng ân hạn**. `fromBill` đọc `anHanNgay = anHanCua(bill)`,
  nên hoá đơn cũ (`periodEnd` NULL) mở form Sửa ra là ân hạn 0 và hạn tính ra **y hệt** hôm nay — không đổi
  hạn của ai. Hàng có ân hạn 15 mở ra là 15, hạn khớp, không cảnh báo.
- `copyWith(anHanNgay:)` — đổi số ngày **không** đụng ngày gốc (`anchorDay` chỉ đi theo `startDate`).

### 4.3. `BillDraft`

Thêm `periodEnd` (bắt buộc, không nullable — form luôn biết). `toCompanion`/`toUpdateCompanion` ghi
`periodEnd: Value(periodEnd)` **mọi lần** (§3). `dateError` của draft gọi cùng `loiAnHan`.

### 4.4. Sinh kỳ kế tiếp — `BillRepositoryImpl._nextPeriodOf`

Dùng chung cho **trả** (`payBill`) và **bỏ qua kỳ** (`skipBill`), nên sửa một chỗ phủ cả hai:

```
anHan        = anHanCua(current)                                  // 0 với hàng cũ
batDauSau    = current.periodEnd ?? current.dueDate               // hàng cũ: như hôm nay
ketThucSau   = nextBillDueDate(batDauSau, chu kỳ, anchorDay: current.anchorDay ?? batDauSau.day)
startDate    = batDauSau
periodEnd    = ketThucSau                                         // LUÔN ghi
dueDate      = hanTraTu(ketThucSau, anHan)
```

Với hàng cũ (`periodEnd` NULL, ân hạn 0) ba dòng cuối cho **đúng** giá trị của mã hôm nay — phải có test
canh điều này bằng ca "ân hạn 0 ⇒ giống trước v21". `undoPayment` và `undoSkip` **không đổi**: chúng xoá
hàng đã sinh theo `generatedFromBillId`, không tính lại ngày.

### 4.5. Cố ý KHÔNG đổi

Mọi phép so ngày dưới đây vẫn neo **`dueDate`** — đó là ngày tiền phải ra khỏi ví, và ân hạn không đổi nghĩa
của nó: quá hạn (`markOverdue`, `billDisplayStatusOf`), nhắc trước hạn (`notification_rules.dart:317`), tự
động thanh toán (`bill_auto_pay.dart:61`, `occurredAt: bill.dueDate`), khoá chống trả hai lần
(`khoaKyTuTra(billId, dueDate)`), sắp xếp hai tab, số liệu thẻ tổng, nhãn "Kỳ dd/MM" trong lịch sử các kỳ ở
trang chi tiết (`bill_detail_page.dart:400`). Trang Phân tích không đọc kỳ hoá đơn.

---

## 5. Đồng bộ

- **Đẩy:** payload hoá đơn thêm `'period_end': bill.periodEnd?.toUtc().toIso8601String()` → **20 trường**
  (đếm bằng script 2026-09-12 trên `sync_engine.dart`: 19 trước khi thêm — `id, idwallet, idcategory, name,
  amount, start_date, due_date, pay_status, recurrence, time_recurrence, time_notification, icon, color, note,
  previous_bill_id, anchor_day, is_deleted, updated_at, idaccount`). Đếm lại khi làm; con số ở đây là mốc.
- **Kéo về:** `periodEnd: bill['period_end'] != null ? Value(DateTime.tryParse(…)) : const Value.absent()`,
  đặt cạnh `anchor_day` với cùng chú thích "server im lặng = chưa biết".
- **Cột server là `@db.Date`** (không giờ): gửi lên mốc UTC nửa đêm của **ngày cục bộ** để không bị lùi một
  ngày khi múi giờ +07 chuyển sang UTC — cùng cách `due_date` đang đi. Kiểm bằng cách đẩy một hoá đơn thật và
  đọc lại `bill."Period_end"` trên PostgreSQL (chỉ đọc).
- `test/core/sync/sync_payload_contract_test.dart`: thêm `'period_end'` vào tập khoá của `bill` **cùng commit**
  (quy tắc 4 `CLAUDE.md`).

---

## 6. Giao diện — Stitch trước, Flutter sau

Dự án Stitch `FlowMoney` (`projects/5106367939423432838`), design system **`assets/e8b7d56e…`** (bản đúng theme
`#1a1a19`; dự án có hai bản trùng tên "Kinetic Finance" — bản kia lệch màu). Sửa bằng `edit_screens` trên các
màn **có sẵn**, không tạo màn mới:

| Màn Stitch | Id | Sửa gì |
|---|---|---|
| Thêm Hóa Đơn Định Kỳ (Không Navigation) | `9d1e6a25dde44249a033fb2718a35cd6` | Khối ngày thành: NGÀY BẮT ĐẦU KỲ → NGÀY KẾT THÚC KỲ 🔒 → **HẠN TRẢ SAU KHI KẾT THÚC KỲ** (thanh phân đoạn `0 · 7 · 15 · 30 · Khác`, khi "Khác" thì thêm ô số "ngày") → HẠN THANH TOÁN 🔒 |
| Chỉnh sửa Hóa đơn | `3157fd8bd4cf47f5a4a7ea7ebb29c477` | Cùng khối |
| Chi tiết hóa đơn - Mobile | `b4aaff9bc9b047fa8f8592b18506183f` | Thêm dòng "Kỳ dd/MM → dd/MM" **trên** dòng "Đến hạn" |

Trong Flutter:

- **Form Thêm/Sửa** (`bill_add_page.dart`, `bill_edit_page.dart`): ô "NGÀY ĐẾN HẠN THANH TOÁN" hiện có đổi
  nhãn thành **"NGÀY KẾT THÚC KỲ"** (vẫn khoá, giá trị = `ketThucKy`); thêm thanh chọn ân hạn dùng
  `SegmentedChoice` ở `shared/widgets` (cùng widget với chu kỳ, key `bill-grace-<n>`; "Khác" là ô số dùng bộ lọc
  3 chữ số) và ô **"HẠN THANH TOÁN"** khoá bên dưới. Ân hạn 0 vẫn hiện đủ ba ô — đúng bản xem trước đã chọn; hai
  ô khoá khi ấy cùng giá trị, chấp nhận để bố cục không nhảy khi đổi số.
- **Trang chi tiết** (`bill_detail_page.dart:332`): thêm `_dong('Kỳ', 'dd/MM/yyyy → dd/MM/yyyy')` trên "Đến
  hạn"; kỳ kết thúc = `periodEnd ?? dueDate`.
- **Sheet thanh toán** (`bill_payment_sheet.dart:327-331`): dòng "Kỳ" đổi mốc phải sang `periodEnd ?? dueDate`.
- **Dòng danh sách** (`bill_page.dart`) và tab Lịch sử: **không đổi** — vẫn "Hạn dd/MM".
- Câu báo lỗi của `loiAnHan` hiện dưới thanh chọn, đỏ, đúng chỗ đang hiện `dateError`.

Bố cục kiểm trên máy ảo **411dp** (bẫy loại 1 của `CLAUDE.md`); widget test dựng trong `SizedBox` hẹp và bắt
`tester.takeException()`.

---

## 7. Kiểm thử — TDD, test đỏ trước

| Lớp | Tệp | Ca bắt buộc |
|---|---|---|
| Domain | `test/features/bill/domain/bill_an_han_test.dart` (mới) | `anHanCua` NULL → 0; 15 ngày; lệch giờ trong ngày vẫn ra số nguyên; `hanTraTu` qua cuối tháng, qua 31/12, năm nhuận 29/02 + n; `loiAnHan` ba luật, biên đúng bằng kỳ kế tiếp bị từ chối, tuần tối đa 6 |
| Domain | `test/features/bill/domain/bill_schedule_test.dart`, `bill_draft_test.dart` (có sẵn, thêm ca) | ân hạn 0 ⇒ `dueDate` **y hệt** bản trước; ân hạn 15 với gốc 31 qua tháng Hai (28/02 + 15 = 15/03; năm nhuận 29/02 + 15 = 15/03); `fromBill` hàng cũ ra 0 không cảnh báo; `toCompanion` ghi `periodEnd` kể cả khi 0 |
| CSDL | `test/core/database/bill_schema_v21_test.dart` (mới) | nâng từ v20 giữ nguyên số hàng, `periodEnd` NULL |
| Repository | `test/features/bill/data/repositories/bill_payment_test.dart`, `bill_skip_test.dart`, `bill_anchor_day_test.dart` (có sẵn, thêm ca) | trả kỳ có ân hạn 15 → kỳ sau `startDate = periodEnd cũ`, `periodEnd` mới = +1 chu kỳ, `dueDate` = +15; chuỗi **ba** kỳ giữ nguyên 15; hàng cũ NULL → kết quả bằng mã trước v21; bỏ qua kỳ cùng luật; hoàn tác không đụng ngày |
| Đồng bộ | `sync_payload_contract_test.dart` | khoá `period_end` có mặt, đếm lại số trường |
| Widget | `test/features/bill/presentation/pages/bill_add_page_test.dart`, `bill_edit_page_test.dart`, `bill_detail_page_test.dart`, `widgets/bill_payment_sheet_test.dart` (đều có sẵn, thêm ca) | chọn 15 → hai ô khoá đổi đúng; "Khác" nhận 20, từ chối 400 và 45-cho-tuần kèm câu báo; hẹp 360dp không tràn; chi tiết có dòng "Kỳ" |
| Máy ảo | — | tạo hoá đơn tháng, ân hạn 15, trả → kỳ sau đúng ba mốc; đẩy lên và đọc `bill."Period_end"` trên PostgreSQL; kéo về máy khác (tài khoản 13 đang có sẵn trên máy ảo) không xoá `periodEnd` |

Ba loại lỗi `flutter test` không bắt được (tràn bố cục, điều hướng shell, thứ tự luồng) — chỉ loại 1 áp dụng
ở đây; **phải** chụp màn hình 411dp trước khi báo xong.

---

## 8. Rủi ro và điều biết trước

| Rủi ro | Xử lý |
|---|---|
| Hàng cũ trên server mang `Period_end = NULL` mãi cho tới khi được sửa lại (client chỉ đẩy hàng `pending`) | Chấp nhận, cùng diện `anchor_day`; NULL đọc là ân hạn 0 = đúng hành vi cũ, không ai mất gì |
| Ân hạn dài chồng kỳ | Luật (c) §4.1 từ chối ngay trên form; kỳ sinh tự động thừa kế ân hạn hợp lệ nên không tự vi phạm |
| `@db.Date` lùi một ngày khi đổi múi giờ | Gửi nửa đêm UTC của ngày cục bộ như `due_date`; đo thật trên PostgreSQL |
| Người dùng đổi chu kỳ trên form Sửa của hoá đơn đã có ân hạn | `ketThucKy` tính lại theo chu kỳ mới, `dueDate` = kết thúc mới + ân hạn cũ; `canhBaoHanCu` báo nếu khác hạn đã lưu — hành vi đã có, chỉ cộng thêm ân hạn |
| Backend chưa có chốt chống trả hai lần (CAN-LAM 17 B bước 2) | Không liên quan tới đợt này; ghi để người sau không tưởng ân hạn làm tệ hơn — hai máy cùng trả vẫn hai khoản như trước |

---

## 9. Ngoài phạm vi

- `bill.Auto_pay` qua đồng bộ (bước 12, chờ backend CAN-LAM 20 §2.1).
- "Ngày cố định trong tháng" và "ngày 31 hay cuối tháng" (mục "Điều ngày gốc KHÔNG giải quyết" của
  `BILL_DOCUMENTATION.md`) — không đụng.
- Đổi cách hiển thị dòng danh sách hoá đơn.
- Không xin gì thêm ở backend: cột, khoá đẩy/kéo đã có.

---

## 10. Tài liệu phải cập nhật cùng đợt

`docs/bill/BILL_DOCUMENTATION.md` (mục 2b bỏ đoạn "Không có ân hạn", mục 5/6 thêm luật kỳ kế tiếp, mục 8 đóng
hàng "Ân hạn"), `CLAUDE.md` (hàng "Đụng vào hoá đơn": schema v21, `Period_end` không còn là "chưa có cột lẫn
khái niệm"; dòng lệnh `build_runner` ghi v21; số test), `docs/PROJECT_CONTEXT.md` (mục 14 khối mới; "🚀 Bắt
đầu từ đâu" bước 14), `docs/CLIENT_APP_KNOWN_GAPS.md` nếu có mục nào nhắc `Period_end`, và
`test/core/sync/sync_payload_contract_test.dart` (tài liệu sống của hợp đồng).
