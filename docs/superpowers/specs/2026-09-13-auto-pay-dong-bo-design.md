# Đồng bộ `Auto_pay` và hoàn tác khi server báo hoá đơn đã trả

**Ngày:** 2026-09-13 · **Trạng thái:** ✅ **ĐÃ THI CÔNG VÀ NGHIỆM THU** (hai máy ảo, cùng ngày) ·
**Phạm vi:** chỉ `src/Client-app`; **không xin backend gì** — mọi thứ cần đã có trên server.

> ⚠️ **Đọc §4.3 trước khi tin phần còn lại.** Nghiệm thu trên hai máy ảo đã **bác bỏ hai giả định**
> của chính bản thiết kế này, và bản sửa theo số đo mới là thứ đang chạy. Những chỗ ấy được đánh
> dấu tại chỗ chứ không xoá đi — chúng ghi lại *vì sao* mã có hình dạng hôm nay. Trạng thái sau
> cùng, đã đo: `docs/bill/BILL_DOCUMENTATION.md` mục **6.8**.

> Đây là **bước 12** trong hàng đợi ở mục 14 `docs/PROJECT_CONTEXT.md`, việc lớn cuối cùng còn
> lại sau khi backend đóng CAN-LAM 20. Nó gồm hai nửa tách nhau được nhưng chỉ có nghĩa khi đi
> cùng: (A) cho cột `autoPayEnabled` đi qua đồng bộ, và (B) dạy client phản ứng khi server từ
> chối một khoản trả bằng `BILL_ALREADY_PAID`.

---

## 1. Vì sao cần

Hôm nay `bills.autoPayEnabled` là **cột cục bộ**: bật tự động trả trên máy A thì máy B không biết.
Server đã có sẵn `bill.Auto_pay` từ lâu, client chỉ chưa gửi và chưa đọc.

Chốt chống trả hai lần ở server **đã có từ `7779999`** (CAN-LAM 20 §2.1, client đo thật 4 ca ngày
2026-09-12): `chanTraHaiLan` ở `upsertTransaction` từ chối khoản chi thứ hai mang cùng `Idbill`
bằng mã `BILL_ALREADY_PAID`. Nhưng phía client, mã ấy hiện chỉ nằm trong `_permanentCodes`
(`sync_engine.dart:1735`) — tức client **ngừng gửi lại**, và dừng ở đó. Hệ quả: máy thua giữ một
khoản chi mà server không có, ví bị trừ một lần không ai hoàn, và sổ hai máy lệch nhau **im lặng**.

## 2. Ba quyết định của người dùng (2026-09-13)

| # | Câu hỏi | Chốt |
|---|---|---|
| 1 | Nhiều máy cùng bật thì chống trả trùng thế nào? | **Dựa vào server + tự hoàn tác.** Máy nào online trước thì thắng; máy thua tự gỡ khoản trả của mình. Không xin backend thêm cột nào, không thêm cơ chế "máy nào được chạy". |
| 2 | Máy thua hoàn tác thì có báo người dùng không? | **Có — thông báo trong app**, nhóm `bill`. Vì việc này xảy ra lúc đồng bộ nền, có thể khi app đóng, nên toast sẽ trôi mất; mà số dư ví thì vừa đổi hai lần. |
| 3 | Hoàn tác áp cho khoản trả nào? | **Cả tự trả lẫn trả tay.** Giữ lại khoản trả tay nghĩa là nó kẹt hàng đợi đẩy vĩnh viễn (server luôn từ chối) và máy này có hai khoản chi trong khi server có một. |

## 3. Phần A — `auto_pay` đi qua đồng bộ

### 3.1. Đẩy lên

`_collectPendingOps` mục 4 (hoá đơn) thêm một khoá vào payload:

```dart
'auto_pay': bill.autoPayEnabled,
```

Payload hoá đơn từ **20 trường lên 21** (đếm bằng máy 2026-09-13 từ chính `sync_engine.dart`: `id,
idwallet, idcategory, name, amount, start_date, due_date, pay_status, recurrence, time_recurrence,
time_notification, icon, color, note, previous_bill_id, anchor_day, period_end, is_deleted,
updated_at, idaccount`).

Kiểu là **`bool` thật**, không phải chuỗi — cùng khuôn `recurrence` đang dùng. `sync_payload_contract_test.dart`
**phải khoá khoá `'auto_pay'` trong cùng lượt sửa** (quy tắc 4 `CLAUDE.md`: tên trường sai thì im
lặng, không báo lỗi).

### 3.2. Kéo về

Nhánh pull hoá đơn đọc `bill['auto_pay']`, và — giống hệt `anchor_day`, `period_end`, `idgoal` —
dùng **`Value.absent()` khi server im lặng**, không ghi đè `false`:

```dart
autoPayEnabled: bill.containsKey('auto_pay') && bill['auto_pay'] != null
    ? Value(bill['auto_pay'] == true)
    : const Value.absent(),
```

Lý do đã vấp thật ba lần trong dự án: hàng cũ nằm sẵn trên server mang `NULL` cho tới khi từng hàng
được đẩy lại; đọc thẳng là **tắt tự động trả** của mọi hoá đơn ngay chu kỳ pull đầu tiên, im lặng.

### 3.3. Dòng chữ phải đổi

Form Thêm và Sửa hoá đơn hiện có dòng phụ dặn *"chỉ nên bật trên một thiết bị"*. Câu ấy sinh ra vì
công tắc là cục bộ và server chưa có chốt; **cả hai lý do nay đã hết**. Câu thay phải nói đúng cái
đang chạy: công tắc theo hoá đơn chứ không theo máy, và nếu hai máy cùng trả thì chỉ một khoản chi
được giữ. ⚠️ **Đổi chữ trên giao diện thì kiểm màn Stitch trước** (nếp dự án).

## 4. Phần B — hoàn tác khi nhận `BILL_ALREADY_PAID`

### 4.1. Đặt ở đâu — một lớp riêng, không nhét vào `SyncEngine`

`SyncEngine` đã phát sẵn `pushResultStream` mang `SyncResult.failures`, và mỗi `SyncOpFailure` đã
có `localId`, `entity`, `message`, `kind`. Thiếu đúng **một** thứ: `code`.

- **Đổi `SyncOpFailure`:** thêm trường `code` (`String?`), điền từ chính chỗ đang phân loại lỗi.
- **Lớp mới `BillPaymentConflictResolver`** (`lib/features/bill/data/services/`): nghe
  `pushResultStream`, lọc `entity == SyncEntityType.transaction && code == 'BILL_ALREADY_PAID'`,
  rồi với mỗi `localId`: tra khoản chi → lấy `billId` của nó → gọi `BillRepository.undoPayment`.
- **Thêm `TransactionDao.getById(String id)`** — hôm nay DAO chỉ có `getByBill(billId)`, tức tra
  **ngược chiều** với cái resolver cần (nó cầm id khoản chi, muốn tìm hoá đơn). Hàm mới phải đọc
  **cả hàng đã xoá mềm**: tới lúc resolver chạy, một chu kỳ trước đó có thể đã gỡ khoản chi rồi, và
  hàm lọc sẵn `isDeleted` sẽ trả `null` khiến resolver im lặng bỏ qua một ca cần xử.

Vì sao không nhét thẳng vào `SyncEngine` (phương án đã loại): tệp ấy đã ~1900 dòng, và cho nó biết
về tầng hoá đơn là phá đúng ranh giới nó giữ được tới giờ. Lớp riêng còn test được mà không phải
dựng cả engine.

`BILL_ALREADY_PAID` **vẫn nằm trong `_permanentCodes`** — việc xếp nó là lỗi vĩnh viễn không mâu
thuẫn gì với việc hoàn tác; hai chuyện độc lập.

### 4.2. Dùng lại `undoPayment`, không viết đường ghi thứ hai

> ⚠️ **ĐÚNG MỘT NỬA — sửa 2026-09-13 sau nghiệm thu.** Dùng lại `undoPayment` là đúng, nhưng để nó
> **tự đi tìm** khoản chi thì sai: `getByBill` là `LIMIT 1` **không `ORDER BY`**, mà trên máy thua
> thì *chắc chắn* có hai khoản chi sống cùng `billId` — của chính nó và của máy thắng, đã pull về
> từ 2026-09-12. Nó đã gỡ nhầm khoản của **máy thắng** rồi đẩy cờ xoá lên server (đo trên
> PostgreSQL: hoá đơn `d2332790` còn `Payed` mà khoản chi duy nhất của nó mang `Deleted_at`).
> `undoPayment` nay nhận thêm `transactionId`, và resolver **bắt buộc** truyền `localId`.
>
> Và ngoại lệ `BillNotPaidException` ở dưới **không** phải "không còn gì để gỡ": trong cùng một chu
> kỳ, pull kéo hoá đơn về `Pending` **trước** khi resolver chạy, nên chốt `daCoKhoanChi` bắn ra
> trong khi khoản chi thừa vẫn còn nguyên và ví chưa được hoàn. Chốt ấy nay chỉ áp dụng khi nơi gọi
> **không** truyền `transactionId`.

`BillRepositoryImpl.undoPayment` đã làm đúng ba việc cần, trong **một** `db.transaction`: hoàn tiền
vào **đúng ví đã bị trừ** (đọc từ khoản chi, không từ hoá đơn), xoá mềm khoản chi, kéo hoá đơn về
chưa trả. Viết một đường gỡ thứ hai song song với nó là tự tạo hai định nghĩa của cùng một việc.

Hai ngoại lệ nó ném ra đều **bình thường** ở đây, không phải lỗi:
- `BillNotPaidException` — hoá đơn đã được kéo về chưa trả bởi một chu kỳ pull trước;
- `BillUndoUnavailableException` — khoản chi không có `billId` (hàng do bản app cũ tạo).

Cả hai nghĩa là "không còn gì để gỡ" → ghi log rồi bỏ qua, **không** báo người dùng.

### 4.3. Hai chỗ hỏng im lặng phải chặn

Cả hai là hệ quả của việc `undoPayment` vốn được viết cho người dùng bấm tay, không cho tình huống
này.

**(a) Khoản chi vừa xoá mềm sẽ quay lại hàng đợi đẩy.** Xoá mềm là đúng quy tắc 5, nhưng bản ghi ấy
sẽ được đẩy lên với cờ xoá — trong khi server **chưa bao giờ có nó** (chính nó vừa bị từ chối). Xoá
một bản ghi không tồn tại là đúng vòng lặp `Record not found` mà dự án đã vấp ngày 2026-09-04.
→ Sau khi `undoPayment` xong, gọi `transactionDao.markSynced(localId)` cho khoản chi ấy để nó
thoát hàng đợi. Cơ chế đã có sẵn (`_markSyncedById`, `sync_engine.dart:1664`).

**(b) Hoá đơn bị kéo về `Pending` rồi đẩy lên đè trạng thái đúng.**

> ⚠️ **SAI — bác bỏ bằng số đo 2026-09-13.** Server **không hề có** trạng thái đúng để mà đè: bản
> `Payed` của *máy thắng* cũng bị LWW đánh bại, vì mỗi máy bị pull ghi đè về `Pending` rồi đẩy
> chính bản cũ hơn ấy lên. Hoá đơn ở lại `Pending` **vĩnh viễn** (đo: `d0f455fe`,
> `Update_at 11:21:18.938`), bộ tự trả trả lại sau mỗi lần pull, và server kết thúc với **ba** kỳ
> kế tiếp. `markSynced` cho hoá đơn chặn đúng con đường duy nhất dạy server sự thật — nay đã bỏ;
> `danhDauDaTra` ghi `Payed` **kèm `syncStatus = 'pending'`** để hàng ấy được đẩy lên. Lý lẽ cũ dựa
> trên việc máy thua đẩy `Pending`; sau bản sửa vòng lặp, máy thua giữ `Payed` — tức đúng sự thật —
> nên đẩy lên là **hội tụ**. Vế `markSynced` cho **khoản chi** thì vẫn đúng nguyên văn. `undoPayment` đặt hoá đơn về
chưa trả với `updatedAt = now`; hàng ấy mới hơn bản `Payed` mà máy thắng vừa ghi, nên LWW sẽ cho
**máy thua thắng** — nó xoá đúng kết quả vừa được chấp nhận.
→ Hoá đơn sau khi hoàn tác cũng phải `markSynced`, để trạng thái thật đến từ **nhánh kéo về** chứ
không bị đẩy ngược. Chu kỳ pull kế tiếp sẽ mang `Payed` của máy thắng xuống, và máy này khớp lại.

⚠️ Thứ tự bắt buộc: `undoPayment` → `markSynced` cho **cả hai** bản ghi. Thiếu một trong hai là một
trong hai lỗi trên, và cả hai đều **không có triệu chứng** ngoài dữ liệu sai.

### 4.4. Thông báo

Thêm **một** loại vào `notification_rules.dart`, nhóm `bill` (nhóm đã có, không thêm nhóm mới):

- Khoá chống trùng theo `billId` + kỳ, cùng khuôn các loại hiện có.
- Nội dung nói đúng việc đã xảy ra: hoá đơn này đã được trả trên thiết bị khác, nên khoản trả trên
  máy này đã được gỡ và tiền đã hoàn về ví. **Không nêu số tiền** — theo nếp thông báo tối giản của
  dự án.
- Bảng `AppNotifications` là **cục bộ**, không đụng `SyncEntityType` (quy tắc 9).

## 5. Kiểm thử

**Test đơn vị** (`test/features/bill/`), theo TDD, mỗi ca đỏ trước:

1. `SyncOpFailure` mang `code` khi backend trả mã.
2. Resolver gọi `undoPayment` đúng một lần cho khoản chi bị `BILL_ALREADY_PAID`.
3. Resolver **bỏ qua** thất bại mang mã khác, và bỏ qua `entity` khác `transaction`.
4. Sau hoàn tác, **cả** khoản chi **và** hoá đơn đều `synced` — hai ca riêng, vì thiếu cái nào cũng
   là một lỗi im lặng khác nhau (§4.3).
5. `BillNotPaidException` và `BillUndoUnavailableException` không làm vỡ chu kỳ đồng bộ và không
   sinh thông báo.
6. Payload hoá đơn có `'auto_pay'`, kiểu `bool` — trong `sync_payload_contract_test.dart`.
7. Nhánh kéo về: server im lặng về `auto_pay` thì **giữ nguyên** giá trị cục bộ (`Value.absent()`).

**Kiểm đầu-cuối trên hai máy ảo cùng tài khoản** trước khi báo xong — đây là tính năng đụng tiền
thật, và ba loại lỗi mà `flutter test` không bắt được đều có mặt ở đây (thứ tự giữa hai luồng bất
đồng bộ là loại thứ ba). Kịch bản: bật tự trả trên cả hai máy, cắt mạng cả hai (⚠️ máy ảo có dữ
liệu di động — phải `svc data disable` **cùng** `svc wifi disable`), để tới ngày đến hạn, cho từng
máy online lần lượt, rồi đọc PostgreSQL **chỉ đọc** đếm số khoản chi mang cùng `Idbill` — phải là
**một**.

## 6. Cái KHÔNG làm

- **Không** xin backend thêm gì. Chốt chống trả hai lần đã có; `bill.Auto_pay` đã có.
- **Không** thêm cơ chế "chỉ một máy được chạy bộ tự trả" (người dùng đã loại ở câu hỏi 1).
- **Không** đổi `_permanentCodes`. `BILL_ALREADY_PAID` vẫn là lỗi vĩnh viễn.
- **Không** viết đường gỡ thứ hai song song với `undoPayment`.
- **Không** đụng schema Drift — `autoPayEnabled` đã có từ v17.

## 7. Liên quan

- `docs/superpowers/specs/2026-09-06-bill-auto-pay-design.md` — thiết kế bộ tự trả.
- Mục **6.5** `docs/bill/BILL_DOCUMENTATION.md` — tóm tắt và các bẫy của tự động trả.
- `docs/superpowers/backend/DA-XONG/CON_LAI_SAU_CBBEEB4.md` §2.1 và §5 — chốt phía server và việc
  nó giao lại cho client.
- `sync_engine.dart:1719-1736` (`_permanentCodes`), `:1664` (`_markSyncedById`),
  `bill_repository_impl.dart:160` (`undoPayment`).
