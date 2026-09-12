# Yêu cầu Backend: hoá đơn — chuỗi kỳ, sợi dây tới khoản chi, ân hạn, và tự động thanh toán

**Ngày:** 2026-09-06
**Phạm vi:** Backend (`prisma/schema.prisma`, `modules/sync/*`)
**Từ:** Frontend Team

| # | Việc | Ưu tiên | Trạng thái |
|---|---|---|---|
| **A** (mục 2) | Cột nullable `transaction.Idbill` | 🟡 Mở khoá — client đã làm xong (schema v16), cột đang là **cục bộ** | ⛔ Chưa |
| **B** (mục 3) | Cột nullable `bill.Previous_bill_id` | 🟡 Mở khoá — cùng đợt với A, hai cột là hai đầu của một sợi dây | ⛔ Chưa |
| **C** (mục 4) | Tách **kỳ tính tiền** khỏi **hạn trả** (ân hạn) | ⚪ Mở đường — client **chưa làm**, cố ý chờ cột | ⛔ Chưa |
| **D** (mục 6) | Cột `bill.Auto_pay` + chốt chặn trả hai lần ở `/sync/push` | 🟡 Mở khoá — client đã làm xong (schema v17), cột đang là **cục bộ**; chốt chặn phụ thuộc việc A | ⚠️ Nửa (2026-09-12): chốt sai chỗ ở `upsertBill` đã bỏ; chốt ở giao dịch chưa có |

**A và B nên đi cùng nhau.** Chúng phục vụ đúng một tính năng (hoàn tác thanh
toán) và cùng là cột nullable, không đụng dữ liệu cũ. Gộp vào đợt migration
chung đã mô tả ở mục 2 của `README.md`.

**D có hai nửa:** cột `Auto_pay` đi cùng đợt migration với A và B; **chốt
chặn** ở `/sync/push` làm sau, vì nó đọc cột `transaction.Idbill` của việc A.

**C độc lập** và tốn hơn hẳn — đọc mục 4 trước khi ước lượng.

---

## 1. Bối cảnh: hoá đơn ở client đã đi tới đâu

Ngày 2026-09-06 client làm xong hai việc trên đường thanh toán hoá đơn:

1. **Trả theo số tiền thật của kỳ.** Hoá đơn điện nước mỗi kỳ một số khác
   nhau. Bảng thanh toán nay hỏi số tiền rồi mới chọn ví; giao dịch, số dư ví
   và bản ghi hoá đơn cùng nhận số đó, và kỳ kế tiếp kế thừa nó.
   **Việc này không cần backend** — cột `TotalAmount` đã có sẵn.

2. **Hoàn tác thanh toán.** Trước đó trả nhầm là kẹt hẳn: khoản chi sinh ra bị
   chặn xoá ở sổ giao dịch, hoá đơn không có đường quay về `Pending`, và kỳ kế
   tiếp thì đã được sinh ra rồi. `undoPayment` nay hoàn trọn ba hệ quả trong
   một transaction.

Việc 2 cần lần được **từ hoá đơn về hai thứ nó đã tạo ra**: khoản chi, và kỳ
kế tiếp. Client đã thêm hai cột cho việc đó ở **schema v16**, nhưng cả hai là
**cục bộ** — không nằm trong payload đẩy, không có cột tương ứng phía backend.

---

## 2. Việc A: cột nullable `transaction.Idbill`

### 2.1. Hiện trạng

Bảng `transaction` phía backend **không có** cột nào nối tới hoá đơn. Ở client,
khoản trả hoá đơn trước 06/09 chỉ nhận ra được bằng **tiền tố ghi chú**:

```dart
note: 'Thanh toán hóa đơn: <tên hoá đơn>'   // kGhiChuTraHoaDon
```

Hai khuyết điểm của cách ấy, cả hai đều đã ghi trong `BILL_DOCUMENTATION.md`:

- Người dùng gõ trùng tiền tố thì bị **chặn xoá oan** ở sổ giao dịch.
- Không có đường đi **ngược** từ hoá đơn về đúng khoản chi nó sinh ra — thứ mà
  hoàn tác bắt buộc phải có để hoàn **đúng số tiền** vào **đúng ví**.

Điểm thứ hai mới là điểm chặn: đoán theo "tiền tố + số tiền + ngày" mà trượt
nghĩa là **hoàn tiền vào ví bằng một khoản chi khác của chính người dùng**.

### 2.2. Client đã làm gì

Schema v16 thêm cột **cục bộ** `transactions.bill_id` (nullable) cùng một chỉ
mục `(idaccount, bill_id)`. Đây đúng khuôn với `transactions.goal_id` của
schema v14 — xem `2026-09-05-backend-transaction-goal-id.md`, việc số 8 trong
`README.md`.

### 2.3. Vì sao vẫn cần backend

Cột cục bộ nên **hàng kéo về từ server luôn để trống nó**. Hệ quả:

| Tình huống | Kết quả hôm nay |
|---|---|
| Trả hoá đơn trên điện thoại, hoàn tác ngay trên điện thoại | ✅ Chạy đúng |
| Trả hoá đơn trên điện thoại, đăng nhập máy khác rồi muốn hoàn tác | ❌ Máy kia không có sợi dây → từ chối, kèm thông báo giải thích |
| Cài lại app rồi pull về | ❌ Mất sợi dây của mọi khoản trả cũ |

Client **không** đoán ở những trường hợp đó: `BillUndoUnavailableException` nói
rõ "khoản chi này được ghi bằng bản ứng dụng cũ" và chỉ người dùng sang sổ giao
dịch. Thà từ chối còn hơn hoàn nhầm tiền.

### 2.4. Đề xuất

```prisma
model transaction {
  // ...
  idbill  String?  @db.VarChar(36) @map("Idbill")
  bill    bill?    @relation(fields: [idbill], references: [idbill], onDelete: SetNull)
}
```

- **Nullable**, không mặc định. Mọi giao dịch thường để trống.
- `onDelete: SetNull` chứ không `Restrict`: xoá hoá đơn không được kéo theo
  khoản chi đã ghi — tiền đã tiêu thật rồi.
- Thêm `idbill` vào `mapEntityFields` của `transaction` ở cả hai chiều, và
  vào bộ trường mà `/sync/push` chấp nhận.

⚠️ Client **chưa** gửi trường này trong payload đẩy và sẽ chỉ bắt đầu gửi sau
khi backend xong — quy tắc 4 trong `CLAUDE.md`. Khi thêm, client cập nhật
`sync_payload_contract_test.dart` cùng lúc.

### 2.5. Cách kiểm chứng

Đẩy một giao dịch có `idbill` trỏ tới một hoá đơn có thật, rồi pull về ở máy
thứ hai và đọc lại cột ấy.

**Mong đợi:** giá trị đi tròn cả hai chiều.
**Hiện tại:** trường bị bỏ qua (không có cột).

---

## 3. Việc B: cột nullable `bill.Previous_bill_id`

### 3.1. Vì sao cần

Hoá đơn **lặp** không phải một hàng sống lâu — mỗi kỳ là **một hàng mới với
UUID riêng**, sinh ra lúc trả kỳ trước. Hệ quả là chuỗi kỳ của cùng một hoá đơn
không có gì nối lại với nhau ở CSDL.

Hai thứ hỏng vì thiếu sợi dây ấy:

1. **Hoàn tác phải gỡ kỳ kế tiếp.** Để lại thì người dùng có hai kỳ cùng mở, và
   trả lại lần nữa sẽ đẻ thêm một kỳ trùng.
2. **Không có lịch sử theo hoá đơn.** Không trả lời được "sáu tháng qua tiền
   điện hết bao nhiêu" — câu hỏi mà mọi app cùng loại đều trả lời được. Tab
   "Đã thanh toán" của client hiện chỉ là một danh sách phẳng theo hạn.

Điểm 2 là lý do đáng làm hơn: nó **mở** một tính năng, không chỉ vá một luồng.

### 3.2. Client đã làm gì

Schema v16 thêm cột **cục bộ** `bills.generated_from_bill_id` (nullable), ghi
lúc sinh kỳ mới. Cùng ràng buộc như việc A: hàng kéo về từ server để trống nó,
nên chuỗi kỳ không theo người dùng sang máy khác.

### 3.3. Đề xuất

```prisma
model bill {
  // ...
  previous_bill_id  String?  @db.VarChar(36) @map("Previous_bill_id")
  previous_bill     bill?    @relation("BillChain", fields: [previous_bill_id], references: [idbill], onDelete: SetNull)
  next_bills        bill[]   @relation("BillChain")
}
```

Đặt tên `Previous_bill_id` (trỏ **lùi**) chứ không `Next_bill_id`: kỳ sau được
tạo **sau**, nên lúc tạo nó đã biết kỳ trước là ai; chiều ngược lại đòi ghi lại
hàng cũ trong cùng giao dịch.

**Không tự sinh chuỗi cho dữ liệu cũ.** Suy ngược từ tên + ngày là đúng phép so
bằng tên mà cột này sinh ra để thay thế, và tên hoá đơn **không duy nhất**.
Chuỗi bắt đầu từ những kỳ tạo sau khi có cột.

### 3.4. Cái đáng có sau đó

Với `Previous_bill_id`, một endpoint đọc lịch sử theo chuỗi trở nên rẻ:

```
GET /api/bills/:id/history   → các kỳ cùng chuỗi, kèm số tiền và ngày trả
```

Client chưa gọi endpoint này và sẽ không gọi cho tới khi nó tồn tại — đây chỉ
là ghi lại để đợt thiết kế sau không phải nghĩ lại.

---

## 4. Việc C: tách kỳ tính tiền khỏi hạn trả (ân hạn)

### 4.1. Hiện trạng: không diễn đạt được hoá đơn điện nước thật

Bảng `bill` chỉ có hai mốc: `Start_date` và `Due_date`. Client hiểu chúng là
**hai đầu của cùng một kỳ**, và kỳ kế tiếp bắt đầu đúng tại ngày đến hạn của kỳ
trước, nên các kỳ nối đuôi nhau không hở.

Hệ quả: **tiền phải trả đúng ngày kỳ kết thúc.** Hoá đơn điện thật thì không
như vậy:

| | Thực tế | Diễn đạt được không? |
|---|---|---|
| Kỳ tính tiền | 01/09 – 30/09 | ✅ `Start_date` … |
| Hạn phải trả | 15/10 | ❌ …nhưng `Due_date` đang **là** mốc kết thúc kỳ |

Đặt `Due_date = 15/10` thì kỳ hoá đơn dài tới 15/10, và kỳ kế tiếp bắt đầu từ
15/10 — sai cả hai đầu. Không có cách nào nói "kỳ hết ngày 30/09 nhưng còn 15
ngày để trả".

### 4.2. Vì sao chưa gấp

Client **chưa làm** phần này và cố ý chưa làm cho tới khi có cột — đi theo lối
của `2026-09-05-backend-goal-priority.md` (xin cột **trước** khi viết mã) thay
vì làm cột cục bộ rồi xin sau như hai lần trước.

Người dùng hôm nay vẫn dùng được: đặt hạn trả là mốc kết thúc kỳ. Chỉ là con số
"kỳ này" trong báo cáo lệch so với hoá đơn giấy.

### 4.3. Đề xuất

```prisma
model bill {
  // ...
  /// Ngày kết thúc KỲ TÍNH TIỀN. NULL = kỳ kết thúc đúng ngày đến hạn
  /// (hành vi hiện tại của mọi hàng đã có).
  period_end  DateTime?  @db.Date @map("Period_end")
}
```

**Nullable với nghĩa "như cũ"** là mấu chốt: không có bước chuyển dữ liệu, và
client cũ đọc hàng mới vẫn đúng — nó chỉ bỏ qua cột nó không biết.

Khi có cột, client sẽ:

- Cho nhập ngày kết thúc kỳ **và** hạn trả riêng, với ràng buộc
  `Start_date < Period_end ≤ Due_date`.
- Tính kỳ kế tiếp từ `Period_end` (chứ không từ `Due_date` như hiện nay), nên
  các kỳ vẫn nối đuôi nhau không hở.
- Xếp trạng thái "quá hạn" theo `Due_date` như hiện tại — không đổi.

### 4.4. Cái bẫy nếu làm nửa vời

Thêm cột mà **không** đổi cách tính kỳ kế tiếp thì hoá đơn "kỳ 01–30/09, hạn
15/10" sẽ sinh kỳ sau bắt đầu 15/10 — hở mất nửa tháng, mỗi kỳ trôi thêm. Hai
việc phải đi cùng nhau, và cả hai đều nằm ở client; backend chỉ cần cột.

---

## 5. Tóm tắt cho người ước lượng

| Việc | Đụng gì | Rủi ro với dữ liệu cũ |
|---|---|---|
| A | 1 cột nullable + quan hệ + `mapEntityFields` | Không — mọi hàng cũ để trống |
| B | 1 cột nullable + quan hệ tự trỏ + `mapEntityFields` | Không — chuỗi bắt đầu từ kỳ mới |
| C | 1 cột nullable | Không — `NULL` mang đúng nghĩa hành vi hiện tại |
| D | 1 cột bool mặc định false + một phép kiểm ở `/sync/push` | Không — hàng cũ `false` |
| E | **Không thêm cột** — chấp nhận thêm giá trị `'Skipped'` cho `bill.Pay_status` (VarChar(7), vừa khít) ở mọi chỗ kiểm/đọc | Không — hàng cũ không mang giá trị này |

Cả năm đều **không** cần chuyển dữ liệu và **không** đổi hành vi của client
đang chạy. Client chỉ bắt đầu gửi các trường mới sau khi backend xong, và cập
nhật `sync_payload_contract_test.dart` cùng lúc.

---

## 6. Việc D: cột `bill.Auto_pay` và chốt chặn trả hai lần

### 6.1. Client đã làm gì (2026-09-06, schema v17)

Người dùng bật "Tự động thanh toán" trên một hoá đơn thì khi mở app vào ngày
đến hạn, app trả hoá đơn ấy từ chính ví thanh toán của nó — đi qua đúng đường
`payBill` của thao tác trả tay, nên sinh một `transaction` loại chi và một kỳ
kế tiếp như thường. Cấu hình lưu ở cột **cục bộ** `bills.auto_pay_enabled`
(bool, mặc định false); kỳ kế tiếp kế thừa cờ.

Thiết kế đầy đủ: `docs/superpowers/specs/2026-09-06-bill-auto-pay-design.md`.

### 6.2. Vì sao cần backend

Hai chuyện, một nhỏ một lớn:

1. **Cấu hình không theo người dùng sang máy khác.** Cài lại app là mất cờ.
   Nhỏ, và giống ba cột trích tự động của mục tiêu.
2. ⚠️ **Hai máy cùng bật, cùng offline, cùng mở app vào ngày đến hạn thì mỗi
   máy trả một lần**: hai `transaction`, hai lần trừ ví, hai kỳ kế tiếp. Cờ
   đã trả (`Pay_status`) đồng bộ theo LWW nên không chặn được — máy nào đẩy
   sau thắng, nhưng khoản chi của cả hai đều đã được đẩy lên. Client chỉ có
   thể nhắc "chỉ nên bật trên một thiết bị" (đã ghi ngay dưới công tắc).

Điểm 2 chỉ đóng được ở server, vì server là nơi duy nhất nhìn thấy cả hai máy.

### 6.3. Đề xuất

```prisma
model bill {
  // ...
  auto_pay  Boolean  @default(false) @map("Auto_pay")
}
```

- Thêm `auto_pay` vào `mapEntityFields` của `bill` ở cả hai chiều và vào bộ
  trường `/sync/push` chấp nhận. Khi có, client gửi nó lên và cấu hình theo
  người dùng sang máy khác — nhưng **client sẽ vẫn chỉ tự trả khi người dùng
  bật lại trên máy ấy** (cột kéo về được đọc để hiển thị, không để chạy), trừ
  khi có chốt chặn dưới đây.
- **Chốt chặn** (phụ thuộc việc A, cột `transaction.Idbill`): ở `/sync/push`,
  một `transaction` mang `Idbill` trỏ tới hoá đơn **đã có** một `transaction`
  khác cùng `Idbill` chưa xoá mềm thì **từ chối** với mã lỗi riêng (đề xuất
  `BILL_ALREADY_PAID`). Client nhận mã ấy sẽ hoàn tác khoản trả cục bộ
  (`undoPayment` đã có) thay vì thử lại vô hạn.

  Không dùng unique index cho việc này: hoàn tác rồi trả lại là hợp lệ và
  sinh hai hàng cùng `Idbill`, một đã xoá mềm. Kiểm ở tầng ứng dụng với điều
  kiện `Deleted_at IS NULL` mới đúng nghĩa.

> ⚠️ **2026-09-11 — `main` @ `7675b35` đặt chốt này ở chỗ khác:** `upsertBill` từ
> chối mọi lần đổi `Pay_status` từ `'Payed'` sang giá trị khác. Như thế **chặn hoàn
> tác** (hoàn tác gửi `'Pending'`) mà **không** chặn được hai khoản chi (máy đẩy sau
> gửi `'Payed'` lên hàng đã `'Payed'`). Xin dời về `upsertTransaction` đúng như đoạn
> trên — kèm một bẫy thứ tự trong lô, và một chỗ sửa cho câu "không dùng unique
> index": [`FIX_BACKEND_3_REGRESSIONS.md`](../CAN-LAM/FIX_BACKEND_3_REGRESSIONS.md) mục 3. Các
> cột `Idbill`, `Previous_bill_id`, `Auto_pay`, `Anchor_day` đã có trong
> `database/12` trên `main` — gộp về nhánh client và áp lên CSDL dev của client cùng
> ngày 2026-09-11.

### 6.4. Cách kiểm chứng

Hai client cùng tài khoản, cùng hoá đơn bật tự trả, cùng offline qua ngày đến
hạn, rồi lần lượt online. **Mong đợi:** một khoản chi trên server, máy đẩy sau
nhận `BILL_ALREADY_PAID` và tự hoàn tác. **Hiện tại:** hai khoản chi.

---

## 7. Việc E: giá trị `Pay_status = 'Skipped'` — bỏ qua một kỳ

### 7.1. Vì sao cần

Hoá đơn lặp có những kỳ **không phải trả**: đi vắng cả tháng nên không có
tiền điện, chủ nhà miễn một tháng, gói dịch vụ tặng kỳ. Client hiện chỉ có ba
giá trị `Pending` / `Payed` / `Overdue`, nên người dùng đứng trước hai lựa
chọn đều sai:

- **Trả giả** (bấm Thanh toán với số tiền 0 hoặc số nhỏ) → sổ giao dịch có một
  khoản chi không có thật, thống kê theo danh mục lệch, và `payBill` từ chối
  số tiền ≤ 0 nên thực ra cũng không làm được.
- **Xoá kỳ** → mất mắt xích của chuỗi (`generatedFromBillId`), kỳ kế tiếp
  **không được sinh ra** vì chỉ `payBill` mới sinh kỳ sau; người dùng phải tạo
  lại hoá đơn từ đầu.

Money Lover và Wallet đều có "Skip this one" cho đúng tình huống này.

### 7.2. Client sẽ làm gì (sau khi backend nhận giá trị)

Trên trang chi tiết hoá đơn (`/bills/:id`, có từ 2026-09-06) thêm nút **"Bỏ
qua kỳ này"** cho kỳ chưa trả:

1. Đặt `payStatus = 'Skipped'`, `isPaid = false`. **Không** sinh khoản chi,
   **không** trừ ví.
2. Sinh kỳ kế tiếp y như `payBill` (cùng `_nextPeriodOf`), để chuỗi không đứt.
3. Hoàn tác được: đưa về `Pending`, xoá mềm kỳ kế tiếp đã sinh — cùng đường
   với `undoPayment` nhưng không có bước hoàn tiền.
4. Tab "Đã thanh toán" hiện kỳ bị bỏ qua với nhãn riêng ("BỎ QUA"), thẻ tổng
   **không** tính nó là nợ, bộ quét thông báo **không** nhắc và **không** tự
   trả nó (`_autoPayCandidates` và `markOverdue` chỉ nhìn `Pending`).

Client **cố ý chưa làm** cho tới khi backend xác nhận: hàng `Skipped` đẩy lên
`/sync/push` mà backend từ chối (hoặc âm thầm ép về `Pending`) thì hoá đơn
kẹt vĩnh viễn trong hàng đợi đẩy — đúng vòng lặp đã gặp ngày 2026-09-04.

> ✅ **Đã xong cả hai đầu.** Backend nhận `'Skipped'` từ 2026-09-11
> (`chk_bill_pay_status` + `sync.validation.js:169`). **Client làm ngày
> 2026-09-12** và đã kiểm đầu-cuối trên máy ảo kèm truy vấn PostgreSQL: hàng
> `Skipped` lên server đúng nguyên văn, kỳ kế tiếp mang `Previous_bill_id` trỏ
> về nó, hoàn tác thì server về `Pending` và kỳ kế tiếp được đặt `Delete_at`.
> Bàn giao: mục **6.7** `docs/bill/BILL_DOCUMENTATION.md`; spec:
> `docs/superpowers/specs/2026-09-12-bo-qua-ky-hoa-don-design.md`.
>
> ⚠️ Mô tả ở 7.2 trên **lệch một chi tiết** so với bản đã làm: nó viết
> "`_autoPayCandidates` và `markOverdue` chỉ nhìn `Pending`" như thể không phải
> đụng gì. Thực tế `denLuotTuTra` đọc `isPaid || payStatus == 'Payed'` chứ
> không đọc `Pending`, nên **nó vẫn tự trừ tiền ví** cho kỳ bỏ qua cho tới khi
> được sửa. `markOverdue` thì đúng là an toàn sẵn — nhưng do may, không do
> thiết kế.

### 7.3. Đề xuất

- `Pay_status` là `VarChar(7)`, `'Skipped'` đúng 7 ký tự — **không cần
  migration**. Chỉ cần rà mọi chỗ đọc/kiểm giá trị này:
  - Bất kỳ whitelist/validator nào của `pay_status` ở `/sync/push` và ở
    `mapEntityFields`: thêm `'Skipped'`.
  - Chỗ nào tính "hoá đơn quá hạn" / "sắp đến hạn" / tổng nợ phía server hoặc
    Admin-web: `Skipped` xử lý **như `Payed`** (không phải nợ), nhưng **không**
    có khoản chi đi kèm — đừng tìm `transaction.Idbill` cho nó.
  - Việc D (chốt chặn trả hai lần): không liên quan — kỳ `Skipped` không có
    giao dịch nên không có gì để chặn.
- Trả lời cho client biết **có** validator hay không. Nếu không có gì kiểm và
  server lưu nguyên chuỗi, chỉ cần một dòng xác nhận là client bắt đầu làm.

### 7.4. Cách kiểm chứng

Đẩy một hàng `bill` với `pay_status: 'Skipped'` qua `/sync/push`, rồi kéo về
bằng `/sync/pull`. **Mong đợi:** hàng lưu và trả về nguyên `'Skipped'`.
**Sai:** bị từ chối, hoặc về `'Pending'`.
