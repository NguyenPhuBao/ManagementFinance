# Chức năng Hoá đơn & Dịch vụ (Bill)

> **Dự án:** FlowMoney (ManagementFinance)
> **Cập nhật:** 2026-09-13 (**bước 12** — `auto_pay` đi qua đồng bộ, và mục **6.8** mới: gỡ khoản trả bị `BILL_ALREADY_PAID` từ chối, kèm bốn chốt mà nghiệm thu hai máy ảo phát hiện; 6.3 nay là `undoPayment({billId, transactionId})`); 2026-09-12 tối muộn (gộp `main` @ `7779999` — backend đặt chốt trả hai lần ở `upsertTransaction`, ba chỗ ở 5, 6.5 và bảng "còn mở" ghi theo); 2026-09-12 (**bỏ qua kỳ** — mục 6.7 mới, và các chỗ đụng tới nó
> ở 6.6, bảng "còn mở", mục 9) · bản trước 2026-09-11 · schema Drift toàn
> dự án nay là **v21** — ân hạn hoá đơn 2026-09-12 tối thêm cột
> `Bills.periodEnd` (mục 2b); bỏ qua kỳ **không đổi schema**
> (v20 thu loại ví về ba, không đụng gì tới hoá đơn; cột `Bills.anchorDay` của
> hoá đơn vào ở **v18**; v19 là cột `priority` của
> mục tiêu, không đụng bảng `Bills`)
> **Phạm vi:** `src/Client-app/lib/features/bill` + phần bill của `core/sync`, `core/database`, `core/bill`

> ⚠️ **Thư mục `docs/bill/` bị `.gitignore:61` chặn.** Tài liệu này không nằm
> trong repo. Muốn nó theo repo thì phải `git add -f`.

> ⚠️ **Tài liệu là ảnh chụp, không phải nguồn sự thật.** Bản 1.0.0 (12/08/2026)
> của file này từng mô tả hai thứ **đã bị gỡ có chủ đích** như thể chúng là
> tính năng — xem mục 7. Bản 2026-09-04 thì mô tả công tắc "Tự động thanh toán"
> như một việc còn dở, trong khi nó là **lời hứa suông** và đã bị gỡ (mục 8).
> Lý do của từng quyết định ngày 06/09 nằm trong **tám commit message**
> `git log ac04a78..746c0c9` — dài, có chủ ý; đọc ở đó trước khi sửa.

---

## 1. Chức năng làm được gì

Quản lý các khoản chi định kỳ (điện, nước, internet, thuê nhà, dịch vụ đăng ký).

- Danh sách chia **hai tab**: *Cần thanh toán* (hạn gần nhất lên đầu, quá hạn
  nằm trên cùng) và *Đã thanh toán* (kỳ mới nhất lên đầu). Mỗi dòng có biểu
  tượng và màu **của danh mục**, dòng "Danh mục • Ví", và một trong **bốn nhãn
  trạng thái**: Đã thanh toán / Quá hạn / Sắp đến hạn / Chưa thanh toán.
- Thẻ tổng đầu trang đo **kỳ này**: tiền và số hoá đơn còn phải trả tới hết
  tháng (kể cả nợ cũ), thanh tiến độ là tỉ lệ tiền đã trả.
- Tạo / sửa / xoá mềm hoá đơn, có ngày bắt đầu và chu kỳ (ngày đến hạn suy
  ra), công tắc "Lặp lại theo chu kỳ", ví thanh toán, danh mục, nhắc trước hạn.
- **Thanh toán theo số tiền thật của kỳ** (bố cục tối 06/09): bảng thanh toán
  hiện **khối thông tin hoá đơn** đủ như trang chi tiết, ba ô *số tiền kỳ này*
  (điền sẵn), *ngày trả* (mặc định hôm nay, không cho tương lai), *ghi chú lần
  trả*, rồi một nút **"Thanh toán bằng <ví của hoá đơn>"** với "Chọn ví khác"
  → đánh dấu đã trả, sinh giao dịch chi mang ngày trả và ghi chú, trừ ví,
  sinh kỳ kế tiếp nếu là hoá đơn lặp.
- **Trang chi tiết `/bills/:id`** (chạm dòng chưa trả): thông tin đầy đủ,
  **lịch sử các kỳ** theo chuỗi `generatedFromBillId` kèm ngày trả, nút
  Thanh toán / Hoàn tác, Sửa / Xoá. Tab *Đã thanh toán* ghi "Trả dd/MM/yyyy"
  và chạm vào mở thẳng khoản chi.
- **Hoàn tác thanh toán**: trả tiền về đúng ví, xoá mềm khoản chi, gỡ kỳ kế
  tiếp, đưa hoá đơn về chưa trả — trong một transaction.
- Cờ quá hạn đi **hai chiều** (`Pending` ⇄ `Overdue`) theo hạn thật.
- Đồng bộ hai chiều với backend qua `SyncEngine`.

Những gì **chưa** làm được nằm ở mục 8 — đọc trước khi hứa với ai.

---

## 2. Cấu trúc mã nguồn

```
lib/core/bill/
└── bill_recurrence.dart        # Chu kỳ lặp: nextBillDueDate + quy đổi hai
                                # cách biểu diễn. Đặt ở core (không phải
                                # features) vì sync_engine cũng dùng — một
                                # định nghĩa duy nhất, giống
                                # core/category/category_name.dart

lib/features/bill/
├── domain/
│   ├── bill_draft.dart         # Giá trị form → BillsCompanion.
│   │                           # Tách khỏi widget để test được
│   ├── bill_schedule.dart      # Hai trục chu kỳ + hai mốc ngày; suy ngược
│   │                           # chế độ khi mở form Sửa
│   ├── bill_pay_status.dart    # (12/09) Bốn giá trị của payStatus + ba vị
│   │                           # từ — ĐỊNH NGHĨA DUY NHẤT của "còn phải
│   │                           # trả" và "đã có khoản chi"; Dart thuần để
│   │                           # core/ import được
│   ├── bill_status.dart        # (06/09) Năm trạng thái hiển thị (thứ năm
│   │                           # `skipped` từ 12/09), chia hai tab, số liệu
│   │                           # thẻ tổng — hàm thuần
│   ├── bill_auto_pay.dart      # (06/09, v17) Quyết định thuần của tự động
│   │                           # thanh toán: đến lượt?, trả bao nhiêu?, khoá kỳ
│   ├── bill_auto_pay_runner.dart # Bộ chạy, gọi từ NotificationScanner
│   ├── bill_chain.dart         # (06/09 tối) chuoiKyCua: chuỗi kỳ theo
│   │                           # generatedFromBillId, mới nhất đứng đầu
│   └── bill_note.dart          # kGhiChuTraHoaDon + ghiChuTraHoaDon(tên,
│                               # ghi chú lần trả) — tiền tố luôn đứng trước
├── data/
│   ├── datasources/
│   │   └── bill_local_datasource.dart
│   └── repositories/
│       ├── bill_repository.dart        # Interface + 4 ngoại lệ (mục 6)
│       └── bill_repository_impl.dart   # payBill, undoPayment, _nextPeriodOf
│   └── domain/bill_ky_ke_tiep.dart      # kyKeTiepCua — ĐỊNH NGHĨA DUY NHẤT của kỳ kế tiếp
└── presentation/
    ├── bloc/                   # BillBloc + event + state
    ├── pages/
    │   ├── bill_page.dart      # Hai tab + thẻ tổng; nạp tên ví/danh mục
    │   │                       # MỘT LẦN bằng getAll (mục 7c); dòng đã trả
    │   │                       # ghi ngày trả + mở khoản chi, dòng chưa trả
    │   │                       # push /bills/:id
    │   ├── bill_detail_page.dart   # (06/09 tối) chi tiết + lịch sử các kỳ
    │   │                           # + trả/hoàn tác/sửa/xoá (mục 6.6)
    │   ├── bill_add_page.dart  # Chu kỳ là thanh chọn phân đoạn ngang
    │   ├── bill_edit_page.dart # Cùng SegmentedChoice với form Thêm
    │   └── bill_delete_page.dart   # ⚠️ CHƯA nối vào router — code chết
    └── widgets/
        ├── bill_payment_sheet.dart   # (06/09 tối) khối thông tin hoá đơn +
        │                             # số tiền/ngày trả/ghi chú + nút
        │                             # "Thanh toán bằng <ví>" (mục 6.6)
        ├── bill_actions.dart         # Ba luồng trả/hoàn tác/xoá dùng chung
        │                             # cho trang danh sách và trang chi tiết
        ├── bill_status_visuals.dart  # Nhãn/màu chữ/màu nền/màu vạch của
        │                             # năm trạng thái — một định nghĩa
        └── bill_status_header.dart   # Hàng đầu thẻ: tên/hạn(2 dòng)/chip
```

Bảng và DAO: `core/database/tables/other_tables.dart` (`Bills`) và
`core/database/daos/other_daos.dart` (`BillDao`: `markPaid`, `markOverdue`,
`getUpcoming`, `getGeneratedFrom`, `updateFields`). Cột nối phía giao dịch:
`transaction_dao.dart` (`getByBill`, `getBillPayments` — bản đồ billId →
khoản chi cho cả trang).

Route: `/bills`, `/bills/add`, `/bills/:id/edit`, `/bills/:id` (đặt SAU hai
route trên, ngoài shell) trong `core/constants/app_router.dart`. `BillBloc` đăng ký `registerFactory` nên mỗi
route dựng một instance riêng.

---

## 2b. Lịch hoá đơn

`BillSchedule` (`domain/bill_schedule.dart`) giữ toàn bộ logic này, tách khỏi
widget để test được.

**Hoá đơn luôn có một chu kỳ.** Khác màn ngân sách — nơi còn lựa chọn "Ngày cụ
thể" để tự nhập ngày kết thúc — hoá đơn không có đường thoát đó (quyết định
2026-09-04). Hệ quả:

- Người dùng chỉ chọn **ngày bắt đầu** và **chu kỳ**.
- **Ngày đến hạn luôn suy ra**: `nextBillDueDate(ngày bắt đầu, chu kỳ)`. Ô trên
  form là chỉ đọc, có biểu tượng ổ khoá.
- Còn đúng một công tắc, **"Lặp lại theo chu kỳ"** (`isRecurrence`): thanh toán
  xong có sinh kỳ mới không. Tắt nó **không** làm mất cách tính ngày đến hạn —
  hoá đơn vẫn chạy đúng một kỳ dài bằng chu kỳ đã chọn.

✅ **Ân hạn — kỳ tính tiền tách khỏi hạn trả (2026-09-12, schema v21).** Hoá đơn
nay có **ba** mốc: `startDate` < `periodEnd` (ngày kết thúc kỳ) ≤ `dueDate` (hạn
trả). Người dùng không chọn ngày mà chọn **số ngày ân hạn** trên thanh
`0 · 7 · 15 · 30 · Khác` (`presentation/widgets/bill_grace_selector.dart` —
`BoChonAnHan`, dùng chung hai form); hai ô ngày đều khoá. Con số ấy **không
lưu**: `anHanCua(bill) = dueDate − periodEnd` theo ngày lịch, định nghĩa duy nhất
ở `domain/bill_an_han.dart`, cùng `hanTraTu` và ba luật `loiAnHan` (không âm,
≤ 365, và **hạn trả phải trước ngày kết thúc kỳ kế tiếp** — chặn hai kỳ cùng mở;
chu kỳ tuần vì thế tối đa 6 ngày). `BillSchedule.ketThucKy` là `dueDate` cũ,
`dueDate` = `hanTraTu(ketThucKy, anHanNgay)`; ân hạn 0 cho kết quả **y hệt**
trước v21 (test canh). Đối chiếu thị trường 2026-09-12: Money Lover, TimelyBills,
Copilot chỉ có một mốc "đến hạn"; PocketSmith có *grace period* theo nghĩa khác
(sau hạn vẫn chưa "quá hạn") — nên mặc định là **0** để ai không cần thì không
phải nghĩ.

⚠️ **Từ 2026-09-16 phép tính NGÀY của kỳ kế tiếp là `kyKeTiepCua(Bill)` ở
`features/bill/domain/bill_ky_ke_tiep.dart` — định nghĩa duy nhất.**
`_nextPeriodOf` **gọi lại** nó (và chỉ còn việc dựng `BillsCompanion`), còn khối
**Dự báo 30 ngày tới** của trang Phân tích chiếu kỳ tương lai bằng đúng hàm ấy —
nên hàng thật sinh ra khi trả tiền không bao giờ lệch với kỳ người dùng vừa thấy
trong dự báo. Có ca test canh hai bên cho cùng ba mốc
(`test/features/bill/data/repositories/bill_ky_ke_tiep_goi_lai_test.dart`).

Ba điều đi kèm, phá là hỏng im lặng: (1) **kỳ sau nối từ `periodEnd ?? dueDate`**,
không phải từ hạn trả — nối từ hạn trả là hở đúng số ngày ân hạn, mỗi kỳ trôi
thêm (bẫy §4.4 tài liệu xin); ân hạn đi theo chuỗi vì `kyKeTiepCua` suy nó từ
kỳ hiện tại, không cần cột riêng. (2) **`NULL` chỉ một nghĩa** — hàng cũ, đọc là
ân hạn 0; mọi đường ghi mới (`BillDraft`, `kyKeTiepCua`) **luôn** ghi
`periodEnd`, kể cả khi bằng `dueDate`, để nhánh kéo về dùng được `Value.absent()`
khi server im lặng như `anchor_day`. (3) Quá hạn, nhắc trước hạn, tự động thanh
toán, khoá chống trả hai lần **vẫn neo `dueDate`** — ân hạn không đổi nghĩa "ngày
tiền ra khỏi ví". Đi qua đồng bộ bằng khoá `period_end` (payload hoá đơn **20** trường lúc ấy —
đếm bằng script 2026-09-12; nay **21** sau `auto_pay` 2026-09-13). Spec:
`docs/superpowers/specs/2026-09-12-bill-an-han-period-end-design.md`; tài liệu
xin cột: việc **C** trong `DA-XONG/2026-09-06-bill-chuoi-ky-va-an-han.md`.

### Bộ chọn chu kỳ trên form Thêm (06/09)

Bốn chu kỳ nằm **một hàng ngang** dạng thanh chọn phân đoạn (`Row` +
`Expanded` trên rãnh xám, `IntrinsicHeight` + `stretch` để bốn ô cao bằng
nhau). Trước đó chúng xếp thành bốn hàng dọc — nguyên nhân **không** ở `Wrap`:
mỗi ô là `Container` có `alignment` mà không có kích thước, và thứ đó giãn hết
ràng buộc nhận được. Không dùng `Wrap` với ô co theo nội dung vì bốn nhãn
tiếng Việt cộng đệm vừa mấp mé 411dp, thỉnh thoảng rớt hàng. Form **Sửa** vẫn
dùng `DropdownButtonFormField` — chưa đồng nhất (mục 8).

### Hoá đơn cũ có hạn trả không khớp chu kỳ

Hoá đơn do bản client trước, hoặc do Admin-web, có thể mang cửa sổ trả bất kỳ —
ví dụ bắt đầu 04/09, hạn 11/09, chu kỳ tháng. Nay hạn luôn suy từ chu kỳ, nên
mở form ra rồi lưu lại **là đổi hạn trả của người dùng**.

`BillSchedule.fromBill` phát hiện việc đó (so hạn đang lưu với hạn tính ra) và
dựng sẵn `canhBaoHanCu`; form Sửa hiện lời cảnh báo ngay dưới ô ngày đến hạn,
nêu cả ngày cũ lẫn ngày sẽ thành. **Không đổi ngầm** — đổi mà không nói gì đúng
là lớp lỗi âm thầm mà dự án này đã dính nhiều lần. Người dùng chỉnh lại cho
khớp thì cảnh báo tự tắt.

---

## 3. Hai cặp cột dễ nhầm

Bảng `Bills` mang **hai cách biểu diễn cho cùng một chuyện**, là di sản của
lần đổi sang DB v2. Nhầm cặp nào là hỏng im lặng.

| Ý nghĩa | Cột chính thức | Cột chuỗi cũ |
|---|---|---|
| Đã thanh toán chưa | `payStatus` — `'Pending'` / `'Payed'` / `'Overdue'` | `isPaid` (bool) |
| Có lặp không, lặp thế nào | `isRecurrence` (bool) + `timeRecurrence` — `'Week'` / `'Month'` / `'Quarter'` / `'Year'` | `recurrence` — `'once'` / `'weekly'` / `'monthly'` / `'quarterly'` / `'yearly'` |

**Nhánh đẩy gửi đi cột chính thức** (`pay_status`, `recurrence` dạng bool +
`time_recurrence`), **không** gửi `isPaid` lẫn chuỗi cũ. Nên:

- Chỉ đặt `isPaid` mà quên `payStatus` ⇒ backend vĩnh viễn thấy `'Pending'`.
- Chỉ ghi chuỗi cũ mà quên `isRecurrence` ⇒ backend vĩnh viễn thấy không lặp.

**Nhánh kéo về** ghi cả hai và giữ chúng khớp nhau. Trước 2026-09-04 nó bỏ
trống cột chuỗi cũ, nên hàng kéo về mang **mặc định `'monthly'` của bảng** bất
kể người dùng đặt gì — hoá đơn một lần tự đẻ ra kỳ tiếp theo.

**Quy tắc ghi:** đọc và ghi theo cột chính thức. Cột chuỗi cũ chỉ được suy ra
từ nó, qua `legacyFromTimeRecurrence()`. Đừng đọc `recurrence` để quyết định gì.

**Quy tắc đọc trạng thái trả:** đọc **cả hai** cột. Hàng do bản client cũ ghi
có thể mang `payStatus = 'Payed'` với `isPaid` còn false; `getUpcoming` lọc cả
hai từ 04/09, danh sách thì tới 06/09 mới theo kịp — trước đó nó bày nút
"Thanh toán" cho hoá đơn đã trả và cộng luôn vào tổng nợ.

⚠️ **Từ 2026-09-12 câu hỏi ấy tách làm hai** và cả hai nằm ở
**`domain/bill_pay_status.dart`**, không còn ở `_daTra` của `bill_status.dart`
(hàm ấy đã xoá): `daCoKhoanChi(bill)` là *đã có khoản chi chưa* (hoàn tác, dòng
"Trả dd/MM", tra `transactions.billId`), `conPhaiTra(bill)` là *còn là nợ
không* (nhắc, tự trả, tổng nợ, `getUpcoming`). Với `Skipped` hai câu trả lời
**khác nhau**. Xem mục 6.7.

---

## 4. Ràng buộc bắt buộc từ backend

`schema.prisma` model `bill`:

```prisma
idwallet    String  @db.VarChar(36) @map("Idwallet")     // NOT NULL, Restrict
idcategory  String  @db.VarChar(36) @map("Idcategory")   // NOT NULL, Restrict
pay_status  String  @default("Pending") @db.VarChar(7)
recurrence  Boolean @default(false)
```

**Hoá đơn thiếu ví hoặc danh mục ghi được xuống SQLite nhưng `/sync/push` từ
chối, bản ghi bị `markSyncBlocked` rồi quay lại hàng đợi ở MỌI chu kỳ** — kẹt
vòng lặp thử lại, và người dùng không thấy thông báo nào.

Vì vậy cả hai form (Thêm và Sửa) **chặn lưu** khi chưa chọn đủ ví và danh mục.
Form Sửa có picker ví/danh mục chính là để vá những hoá đơn do bản client cũ
tạo ra (`walletId = null`) đang kẹt trong hàng đợi — đó là đường duy nhất
trong app.

Lưu ý thiết kế Stitch màn "Thêm Hóa Đơn Định Kỳ" **không** có ô chọn danh mục;
ô này được thêm vào theo quyết định ngày 2026-09-04 vì schema bắt buộc. Stitch
cũng **không có** màn danh sách hoá đơn nào — hai tab, bốn nhãn và bảng thanh
toán làm theo design system chứ không theo màn vẽ sẵn.

Danh mục lấy bằng `categoryDao.getCategoryRows(accountId, 'chi')` — hoá đơn
luôn là khoản chi. `classify` trong SQLite lưu **chữ thường** (`'chi'`); nhánh
pull chuẩn hoá `'Chi'` từ backend về dạng này.

### Ba trạng thái của ô danh mục trên dòng hoá đơn (06/09)

| `categoryId` | Bảng tra có hàng? | Nhãn |
|---|---|---|
| null | — | *Chưa có danh mục* |
| có | không (hàng đã xoá mềm) | *Danh mục đã xoá* |
| có | có | tên danh mục |

Trường hợp giữa là thứ người dùng **phải sửa**: khoản chi do hoá đơn sinh ra sẽ
mang `categoryId` trỏ vào hàng không còn, nên nằm ngoài mọi thống kê theo danh
mục và mọi ngân sách. Trên dữ liệu thật, hai hoá đơn của tài khoản 10 rơi vào
đây sau đợt gộp năm danh mục riêng vào bộ mặc định (05/09); việc trỏ chúng sang
bản mặc định còn sống là **thao tác dữ liệu**, xem mục 8. Cùng quy ước với
`TransactionLookup.tenViDaXoa` ("Ví đã xoá") của sổ giao dịch.

---

## 5. Chu kỳ lặp

`core/bill/bill_recurrence.dart` giữ **định nghĩa duy nhất**.

```dart
DateTime nextBillDueDate(DateTime current, String timeRecurrence)
```

Cộng tháng/quý/năm bằng `DateTime(y, m + n, d)` là **sai**: hàm dựng `DateTime`
cho phép ngày tràn, nên `31/01 + 1 tháng` cho ra `03/03` — hoá đơn nhảy qua
hẳn tháng 2 và người dùng mất một kỳ. Hàm này **kẹp** ngày vào ngày cuối cùng
của tháng đích:

| Mốc cũ | Chu kỳ | Kết quả |
|---|---|---|
| 31/01/2026 | Month | 28/02/2026 |
| 31/01/2028 | Month | 29/02/2028 (năm nhuận) |
| 31/03/2026 | Month | 30/04/2026 |
| 31/12/2026 | Month | 31/01/2027 |
| 30/11/2026 | Quarter | 28/02/2027 |
| 29/02/2028 | Year | 28/02/2029 |

Chu kỳ không nhận ra thì **trả nguyên mốc cũ**: backend có thể thêm giá trị
mới cho `Time_recurrence`, và đoán bừa một chu kỳ sai còn tệ hơn là để mốc
đứng yên.

### Ngày gốc (`anchorDay`) — thay cho quy tắc đoán cuối tháng (2026-09-08)

Kẹp ngày thôi thì chưa đủ. Vì chuỗi hoá đơn **nối đuôi nhau** (ngày bắt đầu kỳ
sau = ngày kết thúc kỳ trước — trước v21 là ngày đến hạn, xem mục 6), số ngày người dùng chọn ban đầu **biến
mất sau kỳ thứ hai**. Nhìn vào một mốc 28/02 đơn độc thì không biết nó thuộc
chuỗi nào trong hai chuỗi dưới đây — mà hai chuỗi ấy phải đi tiếp khác nhau:

| Chuỗi | Người dùng chọn | Kỳ kế tiếp |
|---|---|---|
| bắt đầu 31/01 → kẹp về 28/02 | ngày 31 | **31/03** |
| bắt đầu 28/02 | ngày 28 | **28/03** |

#### Bản trước đoán, và đoán sai một nửa số ca

Quy tắc cũ: *"mốc đang xét rơi đúng ngày cuối tháng thì kỳ sau cũng rơi vào ngày
cuối tháng"*. Không giữ trạng thái, không cần cột mới — nhưng nó **đoán ý định
từ dữ liệu**, và sai với người đăng ký lần đầu vào 28/02: họ muốn *ngày 28 hàng
tháng* và nhận về 31/03, 30/04…

Người dùng báo lỗi này ngày **2026-09-08**, ở đúng màn **Thêm hoá đơn định kỳ** —
nơi ô "Ngày đến hạn" là **chỉ đọc**, nên họ không có cách nào sửa lại.

Đáng chú ý: lý lẽ biện minh cho quy tắc ấy (*"chuỗi mất mốc gốc để neo"*) **không
thành lập ở kỳ đầu tiên** — lúc đó mốc gốc chính là ngày người dùng vừa chọn,
còn nguyên trong tay. Quy tắc được áp ở một nơi mà lý do tồn tại của nó không
đúng.

Nó còn phụ thuộc **năm nhuận**: 28/02/2026 bị đẩy lên 31/03, còn 28/02/2028 thì
không, vì năm nhuận 28/02 không phải cuối tháng. Cùng một ngày người dùng chọn,
hai kết quả khác nhau tuỳ năm.

#### Nay: lưu ngày gốc thay vì đoán lại

Cột `Bills.anchorDay` (DB v18) giữ **ngày trong tháng người dùng thật sự chọn**,
1–31, và được **chép sang từng kỳ** khi sinh hoá đơn kế tiếp. `nextBillDueDate`
nhận nó qua tham số `anchorDay`; bỏ trống thì neo vào ngày của mốc hiện tại.

```
gốc 31: 31/01 → 28/02 → 31/03 → 30/04 → 31/05   (quay lại được ngày 31)
gốc 28: 28/02 → 28/03 → 28/04 → 28/05           (không bị kéo lên cuối tháng)
```

Đây đúng là mô hình `advancePeriodFrom(anchor, steps)` mà **ngân sách** dùng từ
đầu, nên sau thay đổi này ba vùng ngày tháng của app (ngân sách, mục tiêu, hoá
đơn) nói cùng một thứ tiếng. Trước đó hoá đơn là vùng duy nhất hành xử khác.

#### Ba chốt chặn

**1. Migration suy ngày gốc từ NGÀY ĐẾN HẠN, không phải ngày bắt đầu.** Hoá đơn
cũ được tính bằng quy tắc nay đã bỏ; lấy ngày bắt đầu sẽ đổi hạn của chúng ngay
ở kỳ kế tiếp — người dùng không bấm gì mà ngày trả tiền nhà tự dịch. Với hàng
`bắt đầu 28/02, hạn 31/03` thì gốc phải là **31**. Canh ở
`test/core/database/bill_schema_v18_test.dart`.

**2. `BillSchedule.fromBill` KHÔNG suy lại ngày gốc từ ngày bắt đầu.** Kỳ giữa
chuỗi có ngày bắt đầu 28/02 nhưng gốc là 31; suy lại là mở form Sửa rồi lưu là
hạ hoá đơn xuống ngày 28 — đúng lớp lỗi âm thầm mà `canhBaoHanCu` sinh ra để
chặn.

**3. Đổi ngày bắt đầu trên form thì ngày gốc đi theo.** Người dùng vừa chọn ngày
khác nghĩa là vừa nói lại ý định. Giữ gốc cũ là hoá đơn vừa đổi sang ngày 15 vẫn
đến hạn vào ngày 31.

#### Cột này ĐI QUA ĐỒNG BỘ từ 2026-09-12

Trước ngày ấy nó là cột cục bộ: hàng kéo từ server luôn để trống, và khi trống thì
`nextBillDueDate` neo vào ngày của mốc hiện tại — tức chuỗi tạo trên máy khác tụt
dần. Tài liệu xin cột phía backend (đã đóng):
**`docs/superpowers/backend/DA-XONG/BILL_ANCHOR_DAY.md`**; server có
`bill.Anchor_day` từ 2026-09-11, và không chỗ nào phía server tự tính lại từ
`Due_date`.

✅ Client gửi khoá `anchor_day` và đọc nó ở nhánh kéo về. **Hai điều đi kèm:**
nhánh kéo về dùng `Value.absent()` khi server im lặng (hàng cũ trên server mang
`NULL` cho tới khi được đẩy lại — đọc thẳng là **xoá ngày gốc** ngay chu kỳ pull
đầu tiên); và ✅ `autoPayEnabled` **cũng đi qua đồng bộ từ 2026-09-13** (bước 12, khoá `auto_pay` — payload hoá đơn 21 trường), nên bảng `Bills` **không còn cột cục bộ nào**. Chốt `chanTraHaiLan` ở `upsertTransaction` phía server có từ `7779999` (tối muộn 2026-09-12, CAN-LAM 20 §2.1, đo thật 4 ca).

#### Điều ngày gốc KHÔNG giải quyết

Nó phân biệt được *"ngày 28"* với *"ngày 31"*, nhưng **không** phân biệt được
*"ngày 31"* với *"ngày cuối tháng"*. Thực tế hai ý định này gần trùng nhau — gốc
31 kẹp lại chính là ngày cuối tháng ở mọi tháng — nên khác biệt chỉ lộ ra với
người muốn "cuối tháng" mà lại đăng ký đúng vào tháng Hai.

Muốn chặt hơn thì **hỏi thẳng** bằng một công tắc trên form, đừng đoán lại lần
nữa. Đã cân nhắc và loại RRULE (RFC 5545): đặc tả **bỏ qua** occurrence rơi vào
ngày không tồn tại, nên `FREQ=MONTHLY;BYMONTHDAY=31` sẽ không sinh kỳ nào cho
tháng Hai — hoá đơn biến mất. Lý lẽ đầy đủ ở mục 5 tài liệu xin backend.

**Không áp cho chu kỳ tuần** — tuần không có khái niệm ngày trong tháng.
## 6. Luồng thanh toán và hoàn tác

### 6.1. Bốn ngoại lệ của `BillRepository`

| Ngoại lệ | Khi nào | Thông báo trên UI |
|---|---|---|
| `BillAlreadyPaidException` | `payBill` trên hoá đơn CSDL nói đã trả | "Hóa đơn này đã được thanh toán rồi." |
| `BillInvalidAmountException` | số tiền trả ≤ 0 | báo số tiền không hợp lệ |
| `BillNotPaidException` | `undoPayment` trên hoá đơn chưa trả | — |
| `BillUndoUnavailableException` | không lần được khoản chi (mục 6.4) | "khoản chi này được ghi bằng bản ứng dụng cũ…", chỉ sang sổ giao dịch |

### 6.2. `payBill({bill, walletId, idaccount, amount, occurredAt, note})`

1. **Đọc lại hoá đơn từ CSDL** theo id. UI truyền vào ảnh chụp `Bill` nó đang
   giữ; bấm nút hai lần thì lần thứ hai vẫn mang `isPaid = false`, nên không
   được tin tham số. CSDL nói đã trả (đọc cả hai cột) ⇒ `BillAlreadyPaidException`.
2. **Số tiền thật của kỳ** `soTien = amount ?? current.amount`, kiểm `> 0`
   **ở tầng repository** chứ không chỉ ở ô nhập — ô nhập nằm ngoài khối nguyên
   tử, cùng bài học với `depositToGoal` (mục 3.16 `GOAL_FEATURE.md`).
3. Trong **một `db.transaction`**:
   - `markPaid` — đặt cả `isPaid` lẫn `payStatus = 'Payed'`. Nếu `soTien` khác
     số đã lưu thì **ghi lại `amount` của hoá đơn** — tab "Lịch sử" là
     lịch sử, nó phải nói số đã trả thật.
   - Sinh `Transaction` loại `'chi'`, gắn `categoryId` của hoá đơn (không gắn
     thì khoản chi nằm ngoài mọi thống kê theo danh mục và mọi ngân sách),
     ghi chú `ghiChuTraHoaDon(tên, note)` = tiền tố `kGhiChuTraHoaDon` + tên,
     nối thêm ` — <ghi chú lần trả>` nếu người dùng gõ (tiền tố phải đứng
     TRƯỚC: `transactionOwnerOf` nhận diện bằng `startsWith`), `date =
     occurredAt ?? now` (mục 6.6), và **`billId = current.id`** (cột v16, đi
     qua đồng bộ từ 2026-09-12 — mục 6.4).
   - Ví **không** bị trừ ở đây nữa (đổi 2026-09-13, G37): số dư nay suy từ sổ,
     nên chính khoản chi vừa ghi ĐÃ LÀ phép trừ. Sau khối nguyên tử, `payBill`
     gọi `SoDuViService.tinhLaiSoDu(walletId)` — ngoài `db.transaction`, vì nó
     đọc lại chính bảng vừa ghi. Và trước khối, nó gọi `datNeoNhieuVi` để ví có
     điểm neo: đặt neo *sau* khi ghi sổ là neo hấp thụ luôn khoản vừa trả.
   - Nếu `isRecurrence` ⇒ `_nextPeriodOf(current, now, soTien)` (ba mốc ngày do `kyKeTiepCua` quyết): kỳ kế tiếp
     **kế thừa đủ** ví, danh mục, `timeNotification`, chu kỳ, icon, màu, ghi
     chú, mang **`generatedFromBillId = current.id`**, và **`amount` = số
     vừa trả** (một quy tắc duy nhất, không có "số mẫu" ẩn; số vừa trả là ước
     lượng sát hơn số cũ). `startDate` = **ngày kết thúc kỳ** trước
     (`periodEnd ?? dueDate` — hàng cũ thì là hạn trả), `periodEnd` = mốc kế
     tiếp theo chu kỳ, `dueDate` = `periodEnd` + ân hạn của kỳ trước (v21,
     mục 2b) — các kỳ nối đuôi nhau không hở, luôn giữ
     `startDate < periodEnd ≤ dueDate`.
4. `syncEngine.scheduleSync()`.

Cả khối phải nguyên tử: hỏng giữa chừng mà vẫn giữ phần đã ghi thì ví bị trừ
nhưng hoá đơn chưa đánh dấu, hoặc ngược lại.

**Vì sao hỏi số tiền ngay lúc trả:** hoá đơn điện nước mỗi kỳ một số khác
nhau, nhưng đổi qua form Sửa là đổi cho **mọi** kỳ sau chứ không riêng kỳ này.
`BillPaymentSheet` (thay `WalletSelectionBottomSheet`; đổi tên thật vì widget
nay làm việc khác) hỏi số tiền — điền sẵn số của hoá đơn, dạng số thô để
`CurrencyFormatter.parse` đọc như người dùng tự gõ — rồi mới bày ví. Ví của
hoá đơn được đưa lên đầu với nhãn "Ví của hoá đơn" vì `bill.Idwallet` bắt buộc
nhưng luồng trả cũ bày một danh sách không gợi ý gì. `isScrollControlled` để
bàn phím số không che ô nhập.

### 6.3. `undoPayment({billId, transactionId})`

Trước 06/09, trả nhầm là **kẹt hẳn**: khoản chi sinh ra bị chặn xoá ở sổ giao
dịch (`transactionOwnerOf`), hoá đơn không có đường về `Pending`, và kỳ kế
tiếp thì đã sinh ra rồi.

1. Đọc lại hoá đơn; chưa trả ⇒ `BillNotPaidException`. ⚠️ Chốt này **chỉ áp
   dụng khi nơi gọi không truyền `transactionId`** — xem mục 6.8.
2. Tìm khoản chi: có `transactionId` thì lấy **đích danh** hàng ấy (và chỉ khi
   nó còn sống); không có thì `transactionDao.getByBill(billId)`. Không thấy ⇒
   `BillUndoUnavailableException`, **dừng, không đoán**.

   ⚠️ **`transactionId` không phải tiện nghi cho gọn.** `getByBill` là `LIMIT 1`
   **không `ORDER BY`**, nên khi máy có hai khoản chi sống cùng `billId` — chuyện
   *chắc chắn xảy ra* trên máy thua một cuộc đua `BILL_ALREADY_PAID` — nó chọn
   không xác định. Ngày 2026-09-13 nó đã gỡ nhầm khoản của **máy thắng**, khoản
   server đã chấp nhận, rồi đẩy cờ xoá ấy lên (đo trên PostgreSQL: hoá đơn còn
   `Payed` mà khoản chi duy nhất của nó mang `Deleted_at`).
3. Trong **một `db.transaction`**:
   - Hoàn tiền vào **ví của giao dịch** với **số tiền của giao dịch** — đọc từ
     khoản chi, **không** từ hoá đơn: người dùng có thể đã trả bằng ví khác và
     số khác số ghi trên hoá đơn. Đọc nhầm nguồn là hoàn sai tiền vào sai ví.
   - Xoá mềm khoản chi (quy tắc 5 `CLAUDE.md`).
   - `billDao.getGeneratedFrom(billId)` ⇒ xoá mềm kỳ kế tiếp. Để lại thì người
     dùng có hai kỳ cùng mở, và trả lại lần nữa sẽ đẻ thêm một kỳ trùng.
   - Đặt lại **cả** `isPaid = false` **và** `payStatus = 'Pending'`.
4. `scheduleSync()`.

UI: nút "Hoàn tác" chỉ hiện trên dòng **đã trả**, và **hỏi xác nhận** nêu rõ
ba hệ quả trước khi gửi `UndoPaymentEvent`. Test `bill_payment_test.dart` có
ca "hoàn tác rồi trả lại được, và chỉ sinh đúng một kỳ mới".

⚠️ **2026-09-11 — hoàn tác một lần trả ĐÃ ĐỒNG BỘ không lên được server** (suy từ
mã, chưa tái hiện đầu-cuối). Từ `main` @ `cc65f4f`, nhánh cập nhật của
`upsertBill` từ chối mọi bản đẩy đưa hàng `'Payed'` về trạng thái khác, mã
`BILL_ALREADY_PAID`. Các thao tác khác trong lô vẫn lọt (khoản chi và kỳ kế tiếp
bị xoá mềm, ví được hoàn), chỉ hoá đơn trên server còn `'Payed'` — máy thứ hai
thấy hoá đơn đã trả mà không có khoản chi. Client xếp mã ấy **vĩnh viễn**
(`_permanentCodes`, 2026-09-11) nên không kéo chậm cả hàng đợi, nhưng hàng hoá đơn
không lên được server. Lỗi phía backend — CAN-LAM **17 B**
(`docs/superpowers/backend/DA-XONG/FIX_BACKEND_3_REGRESSIONS.md` mục 3; ✅ **backend bỏ chốt ấy, gộp `cbbeeb4` 2026-09-12** — đo thật: hàng kẹt 7 lần đẩy lên server `Pending`). Hoàn tác
một lần trả **chưa kịp đồng bộ** thì không dính.

### 6.4. Hai cột nối của schema v16 — ĐÃ đi qua đồng bộ từ 2026-09-12

| Cột | Ghi lúc | Đọc bởi |
|---|---|---|
| `transactions.billId` (nullable, index `(idaccount, billId)`) | `payBill` sinh khoản chi | `getByBill` — hoàn tác tìm khoản chi |
| `bills.generatedFromBillId` (nullable) | `_nextPeriodOf` | `getGeneratedFrom` — hoàn tác gỡ kỳ sau |

✅ **Từ 2026-09-12 cả hai đi qua đồng bộ** — khoá `idbill` (giao dịch) và
`previous_bill_id` (hoá đơn), cùng đợt với `anchor_day`. ⚠️ `transaction.Idbill`
có khoá ngoại `fk_transaction_bill`, nên **hoá đơn phải được đẩy TRƯỚC giao
dịch** — thứ tự ở `_collectPendingOps` đã đổi và có ca test canh; thiếu chốt ấy
thì khoản trả hoá đơn vỡ khoá ngoại rồi kẹt hàng đợi đẩy, im lặng. Nhánh kéo về
dùng `Value.absent()` khi server im lặng.

⚠️ **Đoạn dưới đây tả trạng thái TRƯỚC ngày ấy**, giữ lại vì nó giải thích vì sao
hoàn tác phải từ chối với hàng cũ — và điều đó **vẫn đúng** cho hàng ghi trước
2026-09-12, vốn còn `NULL` trên server cho tới khi được sửa lại.

Trước đó cả hai **không đi qua đồng bộ**: không trong payload đẩy, nhánh kéo về không
đọc. (Câu này từng kèm "backend không có cột" — từ 2026-09-11 thì **có**, xem
cuối mục.) `sync_payload_contract_test.dart` sẽ **đỏ** nếu chúng lọt vào payload
— đó là chủ ý, đừng "sửa" test; muốn mở thì sửa test **cùng lúc** với payload. Đúng khuôn với
`transactions.goalId` của v14.

Hệ quả chấp nhận có chủ ý:

| Tình huống | Kết quả |
|---|---|
| Trả trên máy này, hoàn tác trên máy này | ✅ |
| Trả trên máy A, hoàn tác trên máy B | ❌ từ chối kèm lý do |
| Cài lại app rồi pull về | ❌ mất sợi dây của mọi khoản trả cũ |
| Khoản trả ghi bằng bản trước v16 | ❌ từ chối kèm lý do |

**Không suy dữ liệu cũ từ tiền tố ghi chú + số tiền + ngày.** Đó chính là phép
so bằng tên mà hai cột này sinh ra để thay thế; đoán trượt nghĩa là hoàn tiền
vào ví bằng một khoản chi **khác** của người dùng. Thà từ chối.

Đã xin backend hai cột tương ứng (`transaction.Idbill`, `bill.Previous_bill_id`)
— việc **A** và **B** trong `2026-09-06-bill-chuoi-ky-va-an-han.md`. Khi backend
xong, client thêm chúng vào payload đẩy **và** cập nhật
`sync_payload_contract_test.dart` cùng lúc (quy tắc 4 `CLAUDE.md`). Cột B còn
mở luôn **lịch sử theo hoá đơn** ("sáu tháng qua tiền điện hết bao nhiêu").

✅ **2026-09-11: backend đã xong phần của mình.** Sau khi gộp `main` @ `cc65f4f`
và CSDL dev áp `database/12`: `transaction.Idbill` và `bill.Previous_bill_id` có ở
CSDL, `/sync/push` nhận khoá **`idbill`** (giao dịch) và **`previous_bill_id`**
(hoá đơn), `/sync/pull` trả cả hai.

✅ **2026-09-12: client đã mở.** Đo trên backend thật (máy ảo, tài khoản 11): trả
một hoá đơn lặp rồi truy vấn PostgreSQL — kỳ 1 mang `Anchor_day`, kỳ 2 vừa sinh
mang `Previous_bill_id` trỏ đúng kỳ 1 **và** `Anchor_day`, khoản chi mang `Idbill`.
Bảng "hệ quả chấp nhận" ở trên nay chỉ còn đúng với **hàng cũ** — hàng ghi trước
ngày ấy vẫn `NULL` trên server cho tới khi được sửa lại, vì client chỉ đẩy hàng
`pending`. Khi mở, lưu ý một bẫy
phía server (mục 4 `docs/superpowers/backend/CAN-LAM/VERIFY_7675B35_REMAINING.md`):
hai kỳ cùng chuỗi trong một lô có cùng trọng số sắp xếp, kỳ sau đứng trước thì vỡ
`fk_bill_previous_bill` và chỉ tự lành ở chu kỳ đẩy sau.

---

### 6.5. Tự động thanh toán (schema v17, 2026-09-06)

Chỗ **thứ hai** trong app tự chuyển tiền khi người dùng vắng mặt (chỗ đầu là
trích tiền mục tiêu, mục 3.12–3.14 `GOAL_FEATURE.md`). Thiết kế đầy đủ ở
`docs/superpowers/specs/2026-09-06-bill-auto-pay-design.md`; đây là bản tóm
tắt và các bẫy.

| Phần | Ở đâu |
|---|---|
| Cột `bills.autoPayEnabled` (bool, mặc định false) — ✅ **đồng bộ** từ 2026-09-13, khoá `auto_pay` | `other_tables.dart`, migration `from < 17` không bật cho hoá đơn cũ |
| Gỡ khoản trả bị server từ chối (`BILL_ALREADY_PAID`) | `data/services/bill_payment_conflict_resolver.dart` — mục **6.8** |
| Quyết định thuần: `denLuotTuTra`, `quyetDinhTuTra`, `khoaKyTuTra`, `tranKyTuTraMoiLuot = 3`, `kBillAutoPayHint` | `domain/bill_auto_pay.dart` |
| Bộ chạy `BillAutoPayRunner.chay(idaccount, now)` → `List<BillAutoPayEvent>` | `domain/bill_auto_pay_runner.dart`, gọi từ `NotificationScanner.scan()` qua closure `runAutoPays` (DI) |
| Hai loại thông báo `billAutoPaid` / `billAutoPayFailed`, nhóm `bill` | `notification_rules.dart`, `notification_prefs.dart` |
| Lịch nhắc hệ điều hành đổi thân câu ("Mở app để hoá đơn được tự trả"), **cùng khoá** | `reminder_scheduler.dart` |
| Công tắc **tắt sẵn** trên form Thêm và Sửa, dòng "Tự trả" trên danh sách | ba trang |

**Ba lựa chọn người dùng đã chốt:** trừ từ **ví thanh toán của hoá đơn**
(không có cột ví riêng); mở app muộn thì **trả bù, trần 3 kỳ mỗi hoá đơn mỗi
lượt**; trả **bất kỳ lúc nào trong ngày đến hạn** (so theo ngày).

**Đi qua `payBill`, không tự ghi.** Một lần trả là bốn việc trong một
transaction; bộ chạy truyền `amount: bill.amount` và **`occurredAt:
bill.dueDate`** — khoản trả bù mang ngày của kỳ, không phải lúc bù (cùng lý do
mục 3.14 `GOAL_FEATURE.md`); `updatedAt` vẫn là "bây giờ". Vì đi qua `payBill`
nên `billId` được ghi và **hoàn tác vẫn chạy** với khoản tự trả.

**Không có cột "lần chạy cuối".** Mỗi kỳ là một hàng riêng nên cờ đã trả
(`isPaid`/`payStatus`, đọc **cả hai**) chính là chốt chống trả hai lần. Trả bù
là: trả hàng này → `payBill` sinh kỳ sau (kế thừa cờ) → nếu kỳ sau cũng đã tới
hạn thì trả tiếp, tới trần hoặc tới khi ví không đủ.

**Dừng đúng lúc:** ví không đủ ⇒ `viKhongDu`, **không đổi gì**, kỳ vẫn mở nên
lượt sau tự thử lại; ví đã bị xoá / `payBill` ném ⇒ `khongChayDuoc`; thiếu ví
hoặc danh mục ⇒ không đến lượt (khoản chi sinh ra sẽ kẹt hàng đợi đẩy). Mỗi hoá
đơn độc lập; lỗi bị nuốt để không giết vòng quét.

**Thông báo** khoá theo **kỳ** (`billAuto:<id>:<yyyy-MM-dd>`), `createdAt` là
**lúc quét** (tiền rời ví lúc nào báo lúc đó; trần 3 kỳ đã chặn cơn lũ).

✅ **Rủi ro hai khoản chi ĐÃ ĐÓNG — 2026-09-13, bước 12.** Trước đó: hai máy
cùng bật, cùng offline, cùng mở app qua ngày đến hạn ⇒ **hai** khoản chi, và
cờ đã trả đồng bộ theo LWW không chặn được. Nay đủ cả ba mảnh:

1. **`auto_pay` đi qua đồng bộ** — payload hoá đơn **21 trường**; công tắc là
   thuộc tính của *hoá đơn*, không phải của *máy*, nên dòng phụ dưới nó đã đổi
   theo (không còn "chỉ nên bật trên một thiết bị").
2. **Server chặn khoản chi thứ hai** cùng `Idbill` bằng `BILL_ALREADY_PAID`
   (`chanTraHaiLan` ở `upsertTransaction`, có từ `7779999`).
3. **Client tự gỡ khoản trả bị từ chối** — `BillPaymentConflictResolver`, mục
   **6.8**.

Đo thật trên hai máy ảo cùng tài khoản: server còn **đúng một** khoản chi sống,
hoá đơn `Payed`, **một** kỳ kế tiếp, ví hai máy đều hoàn đúng.

⚠️ **Khi đụng vào khoá `auto_pay`, gửi `bool` thật, đừng gửi chuỗi:**
`Boolean("false")` ở `sync.repository.js:103-104` ra `true`.

*Lịch sử của chốt chặn phía server, giữ lại vì nó giải thích hình dạng hôm nay:*
bản `7675b35` đặt chốt **sai chỗ** — ở trạng thái hoá đơn thay vì ở giao dịch
mang cùng `Idbill` — nên hai khoản chi vẫn lọt, mà nó còn chặn cả hoàn tác (mục
6.3); `cbbeeb4` bỏ chốt sai ấy nhưng chưa đặt chốt đúng; `7779999` (tối muộn
2026-09-12) đặt `chanTraHaiLan` ở `upsertTransaction`, và client đo thật 4 ca qua
`/sync/push`: lô thứ hai cùng `Idbill` bị `BILL_ALREADY_PAID`, xoá + trả lại cùng
lô thì lọt, hàng sống luôn = 1.

Đã kiểm trên máy ảo 06/09: tạo hoá đơn tuần bắt đầu 30/08 (hạn 06/09 = hôm
nay) bật tự trả → lượt quét sau khi lưu trả ngay, kỳ 13/09 sinh ra mang "Tự
trả", thông báo "Đã trả TestAuto 10 nghìn từ ví test", PostgreSQL nhận khoản
chi với `DateTransaction` = ngày hạn.

---

### 6.6. Ngày trả, ghi chú lần trả, ngày trả trên tab, trang chi tiết (2026-09-06 tối)

Năm việc làm theo thứ tự đã chốt với người dùng sau khi so với Money Lover /
Wallet ("bấm vào hoá đơn thấy gì, bấm Thanh toán thì sao"):

1. **Tab "Đã thanh toán" ghi ngày trả** — `BillLoaded.payments` (bản đồ
   `billId → Transaction`, một truy vấn `TransactionDao.getBillPayments`) đọc
   lại mỗi lần danh sách đổi. Dòng ghi "Hạn … • Trả …"; hoá đơn không có mục
   (hàng kéo về từ server, trả bằng bản trước v16) chỉ ghi hạn — **không đoán**.
   Chạm dòng đã trả mở `TransactionDetailSheet` của khoản chi (Sửa được; Xoá
   tay bị từ chối, chỉ sang nút Hoàn tác).
2. **Bảng thanh toán hỏi ngày trả** (`bill-pay-date`, mặc định hôm nay, bộ
   chọn chặn tương lai) → `PayBillEvent.occurredAt` → `payBill(occurredAt:)`.
   Người dùng ghi lại sau (trả hôm qua, hôm nay mới mở app) thì thống kê theo
   ngày không lệch. Chỉ lấy phần ngày.
   **Bố cục bảng (người dùng chốt lại tối 06/09):** khối thông tin hoá đơn
   ở trên (`bill-pay-info`: tên, nhãn trạng thái, số tiền, rồi các hàng
   "Đến hạn dd/MM/yyyy (còn/quá hạn N ngày | hôm nay)" — so theo NGÀY,
   "Kỳ start → due" (bỏ nếu thiếu `startDate`), chu kỳ, danh mục, ví của hoá
   đơn, nhắc trước, tự động trả, ghi chú cố định của hoá đơn nếu có — người
   dùng thấy bản đầu "khá ít" nên mở rộng bằng trang chi tiết), ba ô nhập,
   hàng "Trả bằng ví" với "Chọn ví khác" (`bill-pay-other-wallet` mở danh
   sách `bill-pay-wallet-<id>`, chọn xong gập lại), và dưới cùng **một nút**
   `bill-pay-confirm` "Thanh toán bằng <tên ví>". Ví mặc định = ví của hoá
   đơn → ví có cờ mặc định → ví đầu danh sách. `BillPaymentSheet` nhận
   `bill` + `categoryName` thay cho `initialAmount`/`preferredWalletId`.
3. **Trang chi tiết `/bills/:id`** (`bill_detail_page.dart`, route ngoài shell,
   đặt SAU `/bills/:id/edit`): thẻ đầu (icon danh mục, tên, hạn, số tiền, nhãn
   trạng thái), thẻ THÔNG TIN (đến hạn, chu kỳ, ví, danh mục, nhắc trước, tự
   động trả, ghi chú), thẻ **LỊCH SỬ CÁC KỲ** theo chuỗi `generatedFromBillId`
   (`chuoiKyCua()` ở `domain/bill_chain.dart`: ngược về gốc rồi xuôi tới kỳ
   mới nhất, mới nhất đứng đầu, chịu vòng lặp dữ liệu hỏng) kèm ngày trả từ
   khoản chi; nút Thanh toán / Hoàn tác; Sửa / Xoá trên AppBar. Đọc CSDL trực
   tiếp như trang chi tiết mục tiêu, nạp lại sau mỗi `BillOperationSuccess`;
   xoá xong thì pop. Dòng **chưa trả** trên danh sách chạm vào là mở trang
   này (dòng đã trả vẫn mở khoản chi). Không có màn Stitch riêng — dựng theo
   design system "Kinetic Finance" và ngôn ngữ thẻ của trang danh sách.
   Nhãn/màu trạng thái tách ra `widgets/bill_status_visuals.dart`; ba luồng
   trả / hoàn tác / xoá tách ra `widgets/bill_actions.dart` để hai trang dùng
   chung.
4. **"Bỏ qua kỳ này"** — ✅ **xong 2026-09-12**, xem mục **6.7** ngay dưới.
5. **Ghi chú riêng của lần trả** (`bill-pay-note`, không bắt buộc) →
   `PayBillEvent.note` → `payBill(note:)` → nối SAU tiền tố (xem 6.2).

**Cái bẫy đắt nhất của đợt này** (mất gần hai giờ): bloc từng viết
`watchBills().asyncMap((bills) async => BillLoaded(... await paymentsOf()))`.
Dưới **FakeAsync** của widget test, `asyncMap` trên `Stream.value` (stub) **nuốt
sự kiện `done`** (kể cả map đồng bộ; `await for`, `listen` thường và stream
broadcast thì không) → `emit.forEach` không kết thúc → `bloc.close()` treo →
ba file widget test của trang đứng đủ **10 phút mỗi test**, và `--timeout` không
cắt được vì hang nằm ở teardown. Nay dùng `emit.onEach` + đọc bản đồ riêng, có
chốt bỏ kết quả cũ và `await` lần đọc cuối trước khi handler trả về. Thăm dò
nhanh khi nghi ngờ: một `test()` thường bọc `FakeAsync().run(...)` chạy đồng bộ,
không thể treo.

### 6.7. Bỏ qua kỳ (`Pay_status = 'Skipped'`) — 2026-09-12

Hoá đơn lặp có những kỳ **không phải trả**: đi vắng cả tháng nên không có tiền
điện, chủ nhà miễn một tháng, gói dịch vụ tặng kỳ. Trước tính năng này người
dùng chỉ có hai lối, **đều sai**: trả giả với số tiền nhỏ (sổ giao dịch có một
khoản chi không có thật; mà `payBill` từ chối số ≤ 0 nên thực ra cũng không làm
được), hoặc xoá kỳ (mất mắt xích `generatedFromBillId`, và vì chỉ `payBill` mới
sinh kỳ sau nên chuỗi dừng hẳn).

Thiết kế đầy đủ: `docs/superpowers/specs/2026-09-12-bo-qua-ky-hoa-don-design.md`.

**Không đổi schema, không thêm trường đồng bộ.** `pay_status` đã nằm trong
payload đẩy từ trước; payload hoá đơn khi ấy vẫn **19** trường (tối cùng ngày lên
**20** với `period_end` — ân hạn, mục 2b). Đo thật hai đầu ngày
2026-09-12 (chỉ đọc): `chk_bill_pay_status` nhận `'Skipped'`; cột
`bill."Pay_status"` là `varchar(7)`, `'Skipped'` đúng 7 ký tự; validator ở
`sync.validation.js:169` nhận.

**Điều quan trọng nhất của đợt này:** câu "đã trả chưa" **tách làm hai** và
chúng không còn trùng nhau.

| | `Pending` | `Payed` | `Overdue` | `Skipped` |
|---|---|---|---|---|
| **Còn phải trả?** — nhắc, tự trả, tổng nợ, `markOverdue`, `getUpcoming` | có | không | có | **không** |
| **Đã có khoản chi?** — hoàn tác, dòng "Trả dd/MM", tra `transactions.billId` | không | có | không | **không** |

Trước đó biểu thức ấy được **chép tay ở 10 chỗ thuộc 7 tệp** (đếm bằng script).
Ba trong số đó tình cờ đúng với giá trị mới — **do may, không do thiết kế**. Nay
tất cả đi qua **`lib/features/bill/domain/bill_pay_status.dart`**: bốn hằng
chuỗi (bắt buộc, vì `getUpcoming` và `markOverdue` là truy vấn SQL không gọi
được vị từ Dart) cộng ba vị từ `daCoKhoanChi` / `daBoQua` / `conPhaiTra`. Giá
trị lạ đọc là **còn phải trả** — thà giục nhầm còn hơn giấu mất một khoản nợ
thật. Đếm lại 2026-09-12: **0** bản chép tay còn sót.

**Hai thao tác ở repository.** `skipBill` đặt `Skipped`, **không** trừ ví và
**không** sinh giao dịch, nhưng vẫn gọi chính `_nextPeriodOf` của `payBill` để
chuỗi không đứt. `undoSkip` về `Pending` và xoá mềm kỳ kế tiếp đã sinh —
**không** có bước hoàn tiền; chép nguyên `undoPayment` sang là **tặng tiền cho
ví**, có test canh đúng chỗ đó.

**Ba cái bẫy, cả ba đều hỏng im lặng nếu phá:**

1. **`payBill` phải từ chối kỳ `Skipped`** (`BillSkippedCannotPayException`).
   Kỳ ấy **đã sinh kỳ kế tiếp rồi**; trả tiếp trên nó là sinh kỳ thứ hai trùng
   hạn và người dùng không hiểu hoá đơn thứ hai ở đâu ra.
2. **`undoSkip` phải từ chối kỳ đã TRẢ.** Hoàn tác một lần trả phải đi qua
   `undoPayment`, thứ có bước hoàn tiền. Đi nhầm đường này là hoá đơn về
   `Pending` mà tiền vẫn nằm ngoài ví và khoản chi vẫn còn trong sổ.
3. **Nhánh `skipped` của `billDisplayStatusOf` phải đứng TRƯỚC mọi phép so
   ngày.** Đặt sau là một kỳ người dùng đã chủ động bỏ lại đeo nhãn đỏ
   "QUÁ HẠN".

**Giao diện.** Nút chỉ ở **trang chi tiết** `/bills/:id` (người dùng chốt), và
`_nutThaoTac` từ hai nhánh thành ba: đã trả → *Hoàn tác thanh toán*; đã bỏ qua →
*Hoàn tác bỏ qua*; còn lại → *Thanh toán* **+** *Bỏ qua kỳ này*. ⚠️ Hai nút
**xếp dọc trong `Column`, không đặt trong `Row`** — theme ép mọi
`ElevatedButton` rộng vô hạn, nút trần trong `Row` làm trắng cả trang mà không
một dòng log nào (bẫy 4.11 `ANALYTICS_FEATURE.md`).

Tab thứ hai của trang danh sách đổi tên **"Đã thanh toán" → "Lịch sử"**, vì nó
nay chứa cả kỳ chưa hề được trả đồng nào; `BillSections` đổi hai trường
`unpaid`/`paid` thành `chuaDong`/`daDong` vì cùng lý do. Ba tệp test cũ chạm tab
bằng nhãn cũ đã sửa theo.

⚠️ **Một lỗi chỉ máy ảo lộ ra** (vá cùng ngày): dòng trên tab Lịch sử vẫn suy
**hai** trạng thái (`isPaid` hay không), nên kỳ `Skipped` rơi vào nhánh "chưa
trả" và **được bày nút Thanh toán** — bấm vào là mở bảng trả rồi bị repository
từ chối. Nay có nhánh thứ ba `daBoQua` hiện *Hoàn tác*. Bộ test xanh suốt trước
khi lỗi này bị bắt trên máy thật.

> ✅ **2026-09-13 — bốn màn "Chi tiết hóa đơn" trên Stitch được bổ sung dòng "Kỳ"** của khối
> `THÔNG TIN` (tức `startDate → periodEnd ?? dueDate`, tính năng ân hạn v21 mà app đã có từ
> 2026-09-12 ở `bill_detail_page.dart:336-339`). **Bốn** màn chứ không phải hai như bàn giao ghi:
> `0eecd62f…` và `e7f48af7…` (Desktop), `b4aaff9b…` (*Mobile*), `fe9ae28a…` (*Modal Bỏ qua kỳ
> này*). Giá trị `21/08/2026 → 20/09/2026` — **cố ý cho kỳ kết thúc TRÙNG hạn trả (ân hạn 0)**,
> vì lịch sử kỳ trên chính màn ấy cách đều một tháng (20/07, 20/08, 20/09).
>
> ⚠️ **Đo lúc 08:0x: chỉ Desktop 1 và Mobile nhận được thay đổi.** Desktop 2 (`e7f48af7…`, gọi
> **bốn** lượt) và Modal (`fe9ae28a…`, **ba** lượt) vẫn giữ nguyên `htmlCode.name` gốc dạng hex,
> trong khi hai màn thành công đã chuyển sang ID dạng số. Người dùng chốt **coi như xong và
> chuyển việc**, nên hai màn ấy **chưa được xác nhận bằng đo** — phiên sau đụng vào thì kiểm lại
> trước, đừng tin là đã có.
>
> **Cùng đợt còn sửa một chỗ lệch trạng thái** (người dùng duyệt): ba màn Mobile / Desktop 2 /
> Modal cùng lúc gắn nhãn "ĐÃ THANH TOÁN", kỳ đang xem ghi "Bỏ qua", và bày nút "Thanh toán" —
> ba thứ không cùng tồn tại được. Mã app: kỳ `skipped` → nhãn **"BỎ QUA"** (chữ `#5A5C56`, nền
> `#E8E8E4`) và **chỉ một** nút viền **"Hoàn tác bỏ qua"** kèm icon `undo`. Desktop 1 vốn đã
> đúng nên dùng làm chuẩn. ⚠️ **Modal sửa NGƯỢC chiều**: modal đang *hỏi* "Bỏ qua kỳ này?" nên kỳ
> **chưa** bị bỏ qua — giữ hai nút, nhãn đầu đổi thành **"SẮP ĐẾN HẠN"** (`#FFE0B2` / `#8A5000`),
> dòng phụ kỳ đang xem thành "Chưa trả".

> ⚠️ **Hai bẫy khi làm việc này, cả hai đều suýt dẫn tới kết luận sai:**
> 1. Chữ "Kỳ" **có** trong cả bốn màn từ trước — nhưng ở phần `LỊCH SỬ CÁC KỲ`, không phải dòng
>    đang thiếu. Phải tải HTML về và đọc đúng **khối** `THÔNG TIN`, đừng `grep` một từ.
> 2. `mcp__stitch__edit_screens` **không nghiệm thu được bằng API** (đo lại 2026-09-14).
>    Nó có lần trả về **thành công** kèm `dom_operations` khẳng định đã sửa tại chỗ mà
>    thực tế không đổi gì; và một màn mới xuất hiện cũng **không** chứng minh lời gọi
>    của mình tạo ra nó — người dùng thao tác song song trên Stitch mà mình không thấy.
>    Nó còn **ghi thật nhưng có độ trễ dài**. Phép đo đáng tin duy nhất là hỏi người dùng. Đo ngay sau khi gọi thì HTML
>    giống bản gốc từng byte và cả `htmlCode.name` lẫn `screenshot.name` đều y nguyên — tôi đã
>    dựa vào đó kết luận công cụ hỏng và commit tài liệu sai, trước khi người dùng kiểm lại và
>    thấy màn đã sửa xong. "Chưa đổi" nghĩa là **chưa biết**, không phải **thất bại**.

**Ba màn Stitch** dựng cùng ngày trong dự án `FlowMoney` (design system "Kinetic
Finance", `assets/e8b7d56e…` — bản trùng tên còn lại **lệch màu**, đừng dùng
nhầm): *Chi tiết hóa đơn - Mobile*, *Chi tiết hóa đơn* (trạng thái bỏ qua), và
*Chi tiết hóa đơn - Modal Bỏ qua kỳ này*. Trang chi tiết trước đó **chưa bao giờ
có màn Stitch** — đợt này vá luôn lỗ hổng ấy. Nhãn `BỎ QUA`: nền `#E8E8E4`, chữ
`#5A5C56`.

**Đã kiểm đầu-cuối trên máy ảo** `emulator-5554` kèm truy vấn PostgreSQL đọc
(2026-09-12): bỏ qua một hàng **sạch** thì server nhận đúng
`Pay_status = 'Skipped'` và kỳ kế tiếp mang `Previous_bill_id` trỏ về nó; hoàn
tác thì server về `Pending` và kỳ kế tiếp được đặt `Delete_at`; **không giao
dịch nào** được sinh ở bất kỳ bước nào.

⚠️ Hàng `3c90acfa…` của hoá đơn `Kiem` (tài khoản 11) **không dùng để kiểm được**
— nó đã lệch sẵn từ 2026-09-12 sáng (server `Payed`, máy `Pending`) và mọi lần
đẩy đều nhận *"Hóa đơn đã được thanh toán, không thể thay đổi trạng thái"*. Đó
là bằng chứng **CAN-LAM 17 B**, không phải lỗi của tính năng này. ✅ Từ 15:10 ngày 2026-09-12 (sau gộp `cbbeeb4`) hàng ấy đã lên server `Pending` — dùng lại để kiểm được.

---

### 6.8. Gỡ khoản trả bị server từ chối (`BILL_ALREADY_PAID`) — 2026-09-13

Mảnh thứ ba của bước 12, cùng với `auto_pay` qua đồng bộ (6.5) và chốt
`chanTraHaiLan` phía server. Mã: `bill/data/services/bill_payment_conflict_resolver.dart`.

Chốt của server cho **máy nào đẩy trước thì thắng**: khoản chi thứ hai mang cùng
`Idbill` bị từ chối. Không có lớp này, máy thua giữ một khoản chi mà server không
có, ví bị trừ một lần không ai hoàn, và sổ hai máy lệch nhau **im lặng**.

Lớp này nghe `SyncEngine.pushResultStream`, lọc
`entity == transaction && code == 'BILL_ALREADY_PAID'`, rồi với mỗi `localId`:
tra khoản chi → lấy `billId` → `undoPayment(billId:, transactionId: localId)` →
`billDao.danhDauDaTra(billId)` → `transactionDao.markSynced(localId)`, và ghi
**một** thông báo `billPaidOnOtherDevice` (khoá theo `billId`, không nêu số tiền).

**Bốn chốt, phá cái nào cũng hỏng im lặng** — cả bốn đều do nghiệm thu hai máy
ảo ngày 2026-09-13 phát hiện, trong khi 2296 ca test đều xanh:

1. **Truyền `transactionId`** — xem 6.3. Thiếu nó là gỡ nhầm khoản của máy thắng.
2. **`danhDauDaTra` phải chạy, và phải trước `markSynced`.** `undoPayment` kéo hoá
   đơn về `Pending`: đúng cho người dùng bấm tay, **sai ở đây**, vì
   `BILL_ALREADY_PAID` nghĩa là server ĐÃ có khoản chi — hoá đơn *đã được trả*, chỉ
   bởi máy khác. Để `Pending` thì bộ tự trả tin theo và trả lại ở chu kỳ sau: tạo
   khoản chi mới → bị từ chối → gỡ → hoàn tiền → lặp. Đo được **5 vòng trong 3
   phút**, ví phình 350.000 mỗi vòng.
3. **Hoá đơn KHÔNG được `markSynced`** — nó phải được đẩy lên. Bản đầu chặn nó
   khỏi hàng đợi, tin rằng trạng thái thật sẽ đến từ nhánh kéo về. Đo thật bác bỏ:
   bản `Payed` của **máy thắng** cũng bị LWW đánh bại — mỗi máy bị pull ghi đè về
   `Pending` rồi đẩy chính bản cũ hơn ấy lên — nên server giữ `Pending` vĩnh viễn,
   không máy nào dạy được nó sự thật. Khoản chi thì ngược lại, **phải** `markSynced`:
   nó chưa bao giờ lên được server, nên để nó mang cờ xoá vào hàng đợi là vòng lặp
   `Record not found` ở mọi chu kỳ.
4. **`SyncEngine` phát kết quả đẩy TRƯỚC bước Pull.** Lớp này bù lại một thay đổi
   cục bộ (hoàn tiền vào ví); Pull ở giữa đã thay số dư bằng bản của server, nên
   phép bù cộng vào con số **không chứa** lần trừ cần bù — ví phình thêm đúng một
   lần trả. Ca test canh: `test/core/sync/sync_push_result_truoc_pull_test.dart`.

**Kết quả đo cuối cùng** (hai máy ảo, tài khoản thử sạch, 2026-09-13): hoá đơn
trên server `Payed`, khoản chi sống mang cùng `Idbill` **đúng một**, kỳ kế tiếp
sống **một**, ví cả hai máy hoàn đúng.

⚠️ **Một khoảng trống còn lại, không thuộc tầng hoá đơn:** máy **thắng** giữ khoản
chi hợp lệ nhưng số dư ví lại là con số của server, vốn **không** trừ khoản chi ấy
— `wallet.Balance` là cột LWW thuần và server không tính lại từ giao dịch. Mọi
thay đổi số dư cục bộ thua một lần xung đột đều biến mất như vậy, không riêng hoá
đơn. Xem `docs/CLIENT_APP_KNOWN_GAPS.md`.

---

## 7. Hai thứ ĐỪNG khôi phục

Bản 1.0.0 của tài liệu này mô tả chúng như tính năng. Cả hai đã bị gỡ ở G4
(2026-09-03) vì gây hại thật:

1. **`_getAccountId()` với `?? 1` và `return 1`.** `idaccount = 1` là tài
   khoản **admin thật**, không phải giá trị "chưa biết". Fallback đó ghi hoá
   đơn của người dùng vào tài khoản admin. Nay dùng
   `currentAccountIdOrNull(context)` trả `int?`: đường ĐỌC hiển thị rỗng,
   đường GHI chặn hẳn kèm thông báo.
2. **Fallback `walletDao.getAllNonDeleted()` khi danh sách ví rỗng.** Hàm đó
   bỏ bộ lọc tài khoản, nên một tài khoản chưa có ví lại nhìn thấy ví của tài
   khoản khác từng đăng nhập trên cùng máy — và hoá đơn tạo ra trỏ vào ví
   không thuộc về mình.

Ngoài ra: **đường sửa không được đi qua `BillDao.insert`.** Hàm đó dùng
`InsertMode.insertOrReplace`, thay nguyên hàng nên mọi cột vắng mặt trong
companion bị đưa về mặc định — nó từng biến hoá đơn đã thanh toán thành chưa
thanh toán, xoá sạch `walletId`/`categoryId` và hạ cờ `isRecurrence`. Dùng
`BillDao.updateFields` (cùng lớp lỗi với quy tắc 3 trong `CLAUDE.md`).

**Thứ ba, gỡ ngày 06/09:** công tắc **"Tự động tạo giao dịch — Thanh toán khi
đến hạn"** trên form Thêm, **bật sẵn**, gắn vào `_autoPayEnabled` không được
lưu ở đâu: không cột, không bộ chạy nền, không gì đọc nó. Người dùng bật rồi
tin app sẽ tự trả, và hoá đơn quá hạn trong im lặng. Đừng thêm lại công tắc
nếu chưa có thứ đứng sau nó — làm thật là quyết định sản phẩm (mục 8).

---

## 7b. Nhắc trước hạn

`Bills.timeNotification` nhận `'1' | '3' | '5' | '7'` hoặc **NULL** (tắt nhắc).
Backend ràng buộc đúng bộ giá trị đó, nên tắt nhắc phải ghi **null** chứ không
phải chuỗi rỗng — chuỗi rỗng bị `/sync/push` từ chối.

⚠️ Đường **Sửa** phải ghi `Value(null)` chứ không bỏ trống companion:
`BillDao.updateFields` chỉ ghi những cột **có mặt**, nên vắng mặt nghĩa là
"giữ nguyên" và thao tác tắt nhắc nhở sẽ không có tác dụng gì. Có test canh.

Cột này **không nằm trong payload đẩy** hiện tại, nên cấu hình nhắc là **cục
bộ từng máy** — nhất quán với quyết định không đồng bộ thông báo, không phải
lỗi.

Trên form Thêm, bốn chip số ngày nằm trong `Wrap` — chip '7 ngày' thêm ngày
04/09 là giọt nước làm hàng cũ tràn 115px ở 411dp.

---

## 7c. Trạng thái hiển thị, hai tab, thẻ tổng (06/09)

Toàn bộ nằm ở `domain/bill_status.dart` — hàm thuần, **một định nghĩa duy
nhất**, thay cho việc `bill_page.dart` tính ngay trong `build` và sai bốn chỗ
cùng lúc.

**`billDisplayStatusOf(bill, now)`** trả một trong **năm**:

| Trạng thái | Điều kiện | Ghi chú |
|---|---|---|
| `paid` | `daCoKhoanChi` (đọc cả hai cột) | thắng mọi thứ, kể cả đã quá hạn |
| `skipped` | `daBoQua` — `payStatus == 'Skipped'` | ⚠️ phải xét **TRƯỚC** mọi phép so ngày, nếu không kỳ bỏ qua đã trễ lại đeo nhãn đỏ "QUÁ HẠN" (mục 6.7) |
| `overdue` | hạn **trước** hôm nay (so theo **ngày**) | đến hạn đúng hôm nay **chưa** quá hạn — cùng quy ước với `markOverdue` |
| `dueSoon` | hạn trong `billLeadDays(bill)` ngày tới | **dùng lại** ngưỡng của bộ luật thông báo — hai mốc riêng thì dải nhắc và nhãn nói hai chuyện khác nhau về cùng một hoá đơn |
| `pending` | còn lại | |

Trước đó hoá đơn **đã quá hạn** mang nhãn "SẮP ĐẾN HẠN" kèm vạch màu
`AppColors.income` — màu xanh lá của khoản **thu**. Stitch chỉ vẽ ba nhãn vì
lúc ấy chưa có `'Overdue'` ở đâu; nhãn thứ tư là để nói đúng cột đó.

**`splitBills(bills)`** → `BillSections(unpaid, paid)`. Mỗi kỳ của hoá đơn lặp
là **một hàng mới** với UUID riêng, nên danh sách phẳng xếp theo hạn có lịch
sử đã trả lẫn vào giữa hoá đơn đang chờ (máy thật: kỳ đã trả của "di h0c" nằm
giữa hai hoá đơn chưa trả; hoá đơn tuần sinh 52 hàng/năm). **Không sắp xếp tại
chỗ** — danh sách đến từ stream của bloc và nhiều nơi khác đọc chung.

**`summarizeBills(bills, now)`** → `BillSummary`: gộp mọi hoá đơn đến hạn
**tới hết tháng của `now`**, kể cả nợ cũ chưa trả từ tháng trước. Chặn ở cuối
tháng vì thẻ nói "Tổng tiền cần thanh toán" và gộp kỳ tháng sau làm con số to
vô cớ (máy thật: 183.000 đ trong khi tháng này chỉ nợ 60.000 đ). **Không**
chặn ở đầu tháng vì nợ cũ vẫn là tiền phải trả. `progress` = đã trả / (đã trả
+ còn phải trả), `0` khi không có gì (không chia 0). Trước đó thanh này là
hằng số `0.66`.

**Cờ `Overdue` hai chiều** (`BillDao.markOverdue`, gọi từ
`NotificationScanner`): `Pending → Overdue` khi hạn đã qua, **và**
`Overdue → Pending` khi hạn ≥ hôm nay. Chiều thứ hai cần vì form Sửa đổi được
ngày bắt đầu, hạn tính lại theo chu kỳ đẩy ra tương lai thì cờ ở lại vĩnh
viễn (`toUpdateCompanion` cố ý không đụng `payStatus`). Client không lộ vì
danh sách tính lại từ `dueDate`, nhưng cột này **có đi đồng bộ** nên Admin-web
đọc sai — dữ liệu thật 06/09 có hai hoá đơn như thế, và chúng tự về `Pending`
khi bản vá chạy trên máy ảo. **Mỗi chiều vẫn giữ điều kiện trạng thái** (chỉ
ghi khi khác) — bỏ điều kiện là vòng lặp đẩy vô tận; test "chạy hai lần liên
tiếp" canh đúng điều đó. Hoá đơn đã trả không bị lôi về `Pending`.

### Ba cái bẫy của `bill_page.dart`

1. **`BillError` và `BillOperationSuccess` là trạng thái THOÁNG QUA**, chỉ để
   bắn snackbar. `builder` dựng lại theo chúng là **trắng cả trang** (rơi
   xuống `SizedBox.shrink()`), và không gì dựng lại cho tới khi stream phát
   trạng thái mới — thứ **không** xảy ra khi thao tác thất bại vì CSDL không
   đổi. Nay `buildWhen` bỏ qua hai trạng thái ấy; snackbar chạy qua
   `listener`. Ba bloc khác trong dự án có cùng hình dạng state.
2. **Bảng tra tên ví/danh mục nạp MỘT LẦN** bằng `getAll` khi mở trang, không
   giữ stream như `TransactionPage._ensureLookupStreams`. Drift để lại `Timer`
   khi huỷ stream trong `dispose` → widget test báo "Pending timers" và treo
   cả tệp; bơm thêm khung không dứt được. Viết widget test cho
   `TransactionPage` là sẽ gặp lại đúng lỗi này.
3. **`categoryDao.getAll` KHỬ TRÙNG LẶP theo tên.** Nó vẫn gồm danh mục mặc
   định (`idaccount = 0`) nhưng bỏ bớt hàng trùng tên, nên không dùng được làm
   bảng tra id → hàng một cách tổng quát. Ở đây chấp nhận được vì hoá đơn trỏ
   vào hàng còn sống; muốn tra đầy đủ thì `getNamesInUse` mới không khử.

Thẻ hoá đơn có hai chỗ từng tràn ở 411dp trên hàng số tiền (`Flexible` +
ellipsis cho số tiền, `FittedBox` cho nút Thanh toán). `BillStatusHeader` tách
riêng để test được ở nhiều bề rộng: tên dài đặt cạnh chip bề rộng cố định thì
chip bị đẩy ra ngoài — Chrome 1280px không bao giờ thấy.

---

## 8. Còn thiếu (tính tới 2026-09-06; các hàng từng chờ backend đo lại 2026-09-11)

| Hạng mục | Trạng thái |
|---|---|
| **Nhắc nhở — phần trong app** | ✅ Xong 2026-09-04. Xem `docs/NOTIFICATION_FEATURE.md` |
| **Nhắc nhở — cấp hệ điều hành** | ⏳ Chưa. Là lát 4–5 trong `docs/NOTIFICATION_FEATURE.md` |
| **Bốn nhãn trạng thái, thẻ tổng, hai tab** | ✅ Xong 2026-09-06 (mục 7c) |
| **Trả theo số tiền thật, hoàn tác** | ✅ Xong 2026-09-06, schema v16 (mục 6) |
| **`BillBloc._subscription`** | ✅ Đã dọn 06/09 (khai báo và `cancel()` nhưng không bao giờ được gán) |
| **Tự động thanh toán** | ✅ **Xong 2026-09-06, schema v17** (mục 6.5), và ✅ **đóng nốt hai vế còn mở ngày 2026-09-13** (bước 12): cấu hình nay **theo người dùng sang máy khác** (`auto_pay` đi qua đồng bộ), và rủi ro **hai máy cùng trả** đóng bằng ba mảnh — `auto_pay` đồng bộ + chốt `chanTraHaiLan` phía server (`7779999`) + `BillPaymentConflictResolver` (mục **6.8**). Nghiệm thu hai máy ảo: server còn đúng một khoản chi sống, hoá đơn `Payed`, một kỳ kế tiếp. ⚠️ Còn **G37**, ngoài tầng hoá đơn: số dư ví trên máy *thắng* không trừ khoản chi của chính nó |
| **Ân hạn (kỳ tính tiền ≠ hạn trả)** | ✅ **Xong 2026-09-12 tối, schema v21** (mục 2b). Cột `periodEnd` đồng bộ lên `bill.Period_end`; nhập theo số ngày; kỳ sau nối từ `periodEnd`; `NULL` = hàng cũ, ân hạn 0. Kiểm máy ảo: xem khối mục 14 `PROJECT_CONTEXT.md` |
| **Hoàn tác trên máy khác / sau cài lại** | ✅ **Đường đồng bộ đã mở 2026-09-12** — client gửi/đọc `idbill`, `previous_bill_id`, `anchor_day`; đo trên backend thật thấy cả ba tới nơi đúng giá trị. ⚠️ Chỉ chạy với hàng ghi **từ ngày ấy trở đi**: hàng cũ trên server vẫn mang `NULL` cho tới khi được sửa lại, vì client chỉ đẩy hàng `pending`. ✅ Hoàn tác lần trả đã đồng bộ **lên được server** từ 2026-09-12 (backend bỏ chốt ở `upsertBill`, gộp `cbbeeb4`; đo thật với hàng `3c90acfa…`) — trước đó bị từ chối, CAN-LAM 17 B (mục 6.3) |
| **Form Sửa: chu kỳ còn là `DropdownButton`** | ✅ Xong 2026-09-06 — cả hai form dùng `SegmentedChoice` ở `shared/widgets` (chung với ngân sách và mục tiêu), giữ key `bill-cycle-<value>` |
| **Màn xác nhận xoá** | `bill_delete_page.dart` (293 dòng) chưa nối vào router. Stitch có màn "Xác nhận xóa hóa đơn" đúng cho nó; app đang dùng `AlertDialog` mặc định |
| **Lọc theo trạng thái trong tab** | Chưa có gì ngoài hai tab |
| **Lịch sử theo chuỗi hoá đơn** | ✅ Trang chi tiết có "Lịch sử các kỳ" theo `generatedFromBillId` (mục 6.6). Chỉ đủ trên máy đã trả; hàng kéo về từ server một mình một chuỗi cho tới khi client đồng bộ `previous_bill_id` (server có cột từ 2026-09-11) |
| **Ngày trả trên tab, ngày trả tuỳ chọn, ghi chú lần trả, trang chi tiết** | ✅ Xong 2026-09-06 tối (mục 6.6) |
| **Bỏ qua kỳ này (`Skipped`)** | ✅ **Xong 2026-09-12** (mục 6.7). Không đổi schema, không thêm trường đồng bộ. Đã kiểm đầu-cuối trên máy ảo + PostgreSQL |
| **Dữ liệu: 2 hoá đơn tài khoản 10 trỏ danh mục đã xoá mềm** | ✅ Đã sửa 2026-09-06 **qua form Sửa trên máy ảo** (chọn lại "Chi khác" mặc định `dd9d7e15…`), để thay đổi đi đúng đường đồng bộ thay vì UPDATE thẳng PostgreSQL. Đã kiểm lại bằng truy vấn đọc: cả hai trỏ vào hàng `Is_default = true`, `Delete_at IS NULL` |
| **Rủi ro chưa tái hiện** | Form `context.pop()` ngay sau `add(event)`; `BillBloc` là factory nên bị `close()` khi pop. Chưa dựng được kịch bản lỗi, nhưng là chỗ đáng nghi nếu có báo cáo "lưu xong mà không thấy gì" |

---

## 9. Kiểm thử

Tầng dưới có chín tệp từ trước; **ba trang có widget test lần đầu ngày 06/09**
— đó là lý do công tắc giả và bốn nhãn sai sống lâu như vậy. Dựng ở **411dp**
và bắt tràn bằng `tester.takeException()` (Flutter báo tràn qua
`FlutterError.reportError`, không ném ra chỗ gọi); làm thế lộ ngay sáu chỗ
tràn chưa ai từng thấy vì bộ test và skill `chay-app` đều chạy Chrome 1280px.

| Tệp | Canh chừng điều gì |
|---|---|
| `test/core/bill/bill_recurrence_test.dart` | Kẹp ngày cuối tháng, năm nhuận, chu kỳ quý, vắt qua năm, giữ giờ/phút, quy đổi hai cách biểu diễn |
| `test/core/database/bill_overdue_test.dart` | Cờ `Overdue` **hai chiều**; đến hạn hôm nay chưa quá hạn; gỡ cờ cũng đánh dấu `pending`; đã trả không bị lôi về; **chạy hai lần thì lần hai không đổi gì** (chống vòng lặp đẩy); không đụng tài khoản khác |
| `test/core/database/bill_upcoming_test.dart` | `getUpcoming` lọc cả hai cột trạng thái |
| `test/features/bill/domain/bill_schedule_test.dart` | Ngày đến hạn suy từ chu kỳ ở cả bốn chu kỳ; bất biến bắt đầu < đến hạn; công tắc lặp lại không đụng cách tính hạn; `fromBill` phát hiện hạn cũ lệch và cảnh báo |
| `test/features/bill/domain/bill_draft_test.dart` | Companion mang ví/danh mục; ghi chu kỳ khớp ở cả hai cột; companion SỬA không đụng `isPaid`/`payStatus`/`startDate`/cờ xoá |
| `test/features/bill/domain/bill_status_test.dart` | **Năm** trạng thái (quá hạn ≠ sắp đến hạn, hôm nay chưa quá hạn, `billLeadDays` riêng thắng chung, đã trả thắng quá hạn, đọc cả hai cột; **kỳ bỏ qua thắng quá hạn** và không phải "đã thanh toán"); `splitBills` sắp xếp đúng chiều, không đụng danh sách gốc, **đẩy kỳ bỏ qua sang nhóm `daDong`**; `summarizeBills` chặn cuối tháng, giữ nợ cũ, tiến độ không phải hằng số, không chia 0, tháng 12 không tràn năm, 29/02 năm nhuận, **kỳ bỏ qua không vào CẢ HAI vế** |
| `test/features/bill/data/repositories/bill_repository_impl_test.dart` | `payBill(note:)` nối ghi chú SAU tiền tố, rỗng thì như cũ; `editBill` không xoá cột vắng mặt và không hồi sinh hàng đã xoá; `payBill` đặt cả hai cột trạng thái, gắn danh mục vào giao dịch, kế thừa đủ thuộc tính cho kỳ sau, đọc chu kỳ từ `isRecurrence`, chặn thanh toán lần hai |
| `test/features/bill/data/repositories/bill_payment_test.dart` | Số tiền truyền vào thắng số đã lưu; hoá đơn ghi lại số thật; kỳ sau kế thừa số vừa trả; số ≤ 0 bị từ chối **không ghi gì**; hoàn tác: về chưa trả, hoàn đúng ví đúng số, xoá mềm khoản chi và kỳ sau, hoá đơn không lặp không có gì để gỡ, chưa trả bị từ chối, **khoản trả cũ không có `billId` thì từ chối KHÔNG đoán**, hoàn tác rồi trả lại chỉ sinh đúng một kỳ |
| `test/features/bill/domain/bill_pay_status_test.dart` | **Định nghĩa duy nhất** của trạng thái trả: ba vị từ trên cả bốn giá trị; hàng lệch hai cột theo **cả hai** chiều; giá trị lạ đọc là *còn phải trả* và **không** đọc là *bỏ qua* |
| `test/features/bill/data/repositories/bill_skip_test.dart` | `skipBill` không trừ ví và không sinh giao dịch nào; đặt `Skipped` giữ `isPaid` false và vào hàng đợi đẩy; sinh kỳ kế tiếp đúng ngày/số tiền/trạng thái; hoá đơn **không lặp** thì không sinh; từ chối kỳ đã trả và kỳ đã bỏ qua (**chống sinh kỳ trùng**); `payBill` từ chối kỳ `Skipped` **TRƯỚC khi trừ ví**; `undoSkip` về `Pending` + xoá mềm kỳ sau, **KHÔNG cộng tiền vào ví**, từ chối kỳ chưa bỏ qua và kỳ đã trả |
| `test/features/bill/presentation/pages/bill_detail_page_test.dart` | Ba nhánh nút ở 411dp (chưa trả có **cả** Thanh toán lẫn Bỏ qua kỳ này; kỳ bỏ qua **chỉ** có Hoàn tác bỏ qua; đã trả không có nút Bỏ qua); dòng lịch sử ghi "Bỏ qua"; hộp thoại nói đủ **ba** hệ quả |
| `test/features/bill/bill_push_payload_test.dart` | Đi hết đường **form → SQLite → payload đẩy**: `idwallet`/`idcategory` không null, `recurrence` là bool, `pay_status` đổi sang `'Payed'` sau khi trả |
| `test/core/sync/sync_pull_bill_recurrence_test.dart` | Pull ghi chu kỳ vào cả hai cột, khớp nhau |
| `test/core/sync/sync_payload_contract_test.dart` | **Hợp đồng tên trường** của payload đẩy. Đỏ nếu `billId`/`generatedFromBillId` lọt vào — chủ ý. Thêm trường mới cho bill thì phải cập nhật ở đây cùng lúc |
| `test/features/bill/presentation/bloc/bill_bloc_test.dart` | Tổng tiền chưa thanh toán; thông báo riêng khi hoá đơn đã trả |
| `test/features/bill/e2e_bill_flow_test.dart` | Vòng đời Tạo → Tải → Thanh toán → còn `pending` cho SyncEngine |
| `test/features/bill/presentation/pages/bill_add_page_test.dart` | Không còn công tắc tự động thanh toán; không tràn 411dp; **bốn chu kỳ trên một hàng** (mốc trên trùng, bề rộng bằng nhau, đúng thứ tự, không tràn mép); chạm chu kỳ đổi được ngày đến hạn; còn đủ các khối thật |
| `test/features/bill/presentation/pages/bill_edit_page_test.dart` | Không tràn 411dp; nạp sẵn giá trị; cảnh báo hạn lệch chu kỳ |
| `test/features/bill/presentation/pages/bill_page_test.dart` | "QUÁ HẠN" không phải "SẮP ĐẾN HẠN"; vạch quá hạn là màu lỗi; ba nhãn còn lại; đã trả theo `payStatus` cũng là đã trả; thẻ tổng chặn cuối tháng; tiến độ không phải 0,66; hai tab tách đúng; dòng có danh mục và ví; "đã xoá" ≠ "chưa có"; ví của hoá đơn lên đầu; bảng thanh toán điền sẵn và sửa được; chỉ đã trả mới có Hoàn tác; hoàn tác hỏi xác nhận nêu ba hệ quả; **báo lỗi không làm trắng trang**; không tràn 411dp; **tab thứ hai tên "Lịch sử", kỳ bỏ qua đếm vào đó và không cộng vào tổng nợ, dòng của nó KHÔNG bày nút Thanh toán** |
| `test/core/database/bill_schema_v18_test.dart` | Migration v17→v18: ngày gốc suy từ **ngày đến hạn** chứ không phải ngày bắt đầu (hàng `bắt đầu 28/02, hạn 31/03` phải ra gốc **31**); ngày một chữ số không bị đọc thành chuỗi; không đẩy hàng cũ vào hàng đợi đồng bộ |
| `test/features/bill/data/repositories/bill_anchor_day_test.dart` | Chuỗi ngày 31 **quay lại được** ngày 31 sau tháng Hai; chuỗi ngày 28 **không bị kéo lên** cuối tháng; hai chuỗi cùng đi qua 28/02 vẫn tách được nhau; hoá đơn chưa có ngày gốc thì neo vào ngày đến hạn hiện tại |
| `test/features/bill/domain/bill_an_han_test.dart` | **Định nghĩa duy nhất** của ân hạn (v21): `anHanCua` NULL → 0, tính theo ngày lịch không lệch vì giờ, âm → 0; `hanTraTu` giữ giờ với 0 ngày, qua cuối tháng/năm, năm nhuận; `loiAnHan` ba luật, biên đúng bằng kỳ kế tiếp bị từ chối, tuần tối đa 6 |
| `test/features/bill/data/repositories/bill_an_han_ky_sau_test.dart` | Kỳ sau nối từ **ngày kết thúc kỳ**, giữ ân hạn 15 qua chuỗi ba kỳ gốc 31; hàng cũ (NULL) cho kết quả **y hệt trước v21** và được ghi `periodEnd`; `skipBill` cùng luật |
| `test/core/database/bill_schema_v21_test.dart` | Migration v20→v21: có cột `period_end`, hàng cũ giữ NULL, hạn trả và ngày gốc nguyên vẹn |
| `test/core/sync/sync_pull_bill_period_end_test.dart` | Pull `period_end`: server có → ghi; thiếu khoá hoặc `null` → **giữ nguyên** (`Value.absent()`) |
| `test/features/bill/presentation/widgets/bill_grace_selector_test.dart` | Năm ô một hàng ở 411dp; "Khác" mở ô số 3 chữ số; giá trị lạ lúc mở → ô Khác điền sẵn; câu lỗi đỏ dưới thanh |
| `test/core/database/bill_schema_v17_test.dart` | Migration v16→v17: hoá đơn cũ **không** được bật tự trả, không bị đẩy vào hàng đợi |
| `test/features/bill/domain/bill_draft_auto_pay_test.dart` | Cờ mặc định tắt; companion TẠO và SỬA đều **có mặt** cờ (vắng mặt là "giữ nguyên" và tắt không có tác dụng) |
| `test/features/bill/data/repositories/bill_pay_occurred_at_test.dart` | Kỳ sau kế thừa cờ; `occurredAt` vào `date` không vào `updatedAt`; tương lai bị chặn |
| `test/features/bill/domain/bill_auto_pay_test.dart` | Đến lượt: đúng ngày, không sớm, đã trả (cả hai cột)/xoá/thiếu ví/danh mục bị loại; quyết định đủ/thiếu/0; khoá theo ngày; trần 3 |
| `test/features/bill/domain/bill_auto_pay_runner_test.dart` | Trả đúng kỳ, giao dịch mang ngày hạn, sinh kỳ sau kế thừa cờ; đúng ngày bất kỳ giờ; chưa tới thì không đụng; hai lượt không trả hai lần; **trả bù đúng trần 3**, lượt sau trả tiếp; dừng ngay khi ví thiếu; ví thiếu không đổi gì và lượt sau trả được; ví bị xoá; mỗi hoá đơn độc lập; không đụng tài khoản khác; hoàn tác vẫn được |
| `test/core/notification/notification_rules_bill_auto_pay_test.dart` | Hai loại, khoá theo kỳ, câu nêu tên/số tiền/ví, cửa sổ im lặng không nuốt, nhóm `bill` |
| `test/core/notification/notification_scanner_auto_pay_test.dart` | Sự kiện thành hàng thông báo; nhận đúng tài khoản/mốc; **chạy sau `markOverdue`, trước `loadBills`**; ném lỗi thì vòng quét vẫn sống |
| `test/core/notification/reminder_scheduler_auto_pay_test.dart` | Thân câu "mở app để được tự trả"; hoá đơn thường như cũ; **cùng khoá lịch** |
| `test/features/bill/presentation/bloc/bill_bloc_payments_test.dart` | Bản đồ khoản chi theo `billId` vào `BillLoaded`; hoàn tác gỡ mục; tính lại sau khi trả |
| `test/features/bill/presentation/pages/bill_page_payment_info_test.dart` | Dòng đã trả ghi "Trả dd/MM/yyyy" từ khoản chi; không có khoản chi thì chỉ ghi hạn; chạm dòng đã trả mở `TransactionDetailSheet`; chạm dòng chưa trả `push('/bills/:id', extra: bill)` (dựng `GoRouter` thật) |
| `test/features/bill/presentation/widgets/bill_payment_sheet_test.dart` | Khối thông tin đủ hàng (trạng thái, "(còn 2 ngày)"/"(quá hạn 3 ngày)"/"(hôm nay)" theo ngày, kỳ, chu kỳ, danh mục, ví, nhắc trước, tự trả, ghi chú chỉ khi có) + nút "Thanh toán bằng <ví của hoá đơn>", danh sách ví chỉ mở khi bấm "Chọn ví khác" rồi gập lại, ví của hoá đơn mất thì rơi về ví có cờ mặc định; số ≤ 0 không đóng bảng; ô ngày mặc định hôm nay, chặn tương lai, ngày chọn vào callback; ô ghi chú có gõ thì nhận, trống thì `null`; không tràn 411dp |
| `test/features/bill/presentation/bloc/bill_bloc_pay_date_test.dart` | `PayBillEvent.occurredAt`/`note` đi thẳng xuống `payBill`; không truyền thì `null` |
| `test/features/bill/domain/bill_chain_test.dart` | Chuỗi kỳ: ngược gốc + xuôi mới nhất, mới nhất đứng đầu; trùng tên không lẫn; id lạ → rỗng; vòng lặp không treo |
| `test/features/bill/presentation/pages/bill_detail_page_test.dart` | Đủ thông tin và không tràn 411dp; lịch sử theo chuỗi kèm ngày trả, hoá đơn trùng tên không lẫn; nút Thanh toán/Hoàn tác theo trạng thái; bấm Thanh toán mở bảng; trả xong trang nạp lại và kỳ mới vào lịch sử; id lạ → "Không tìm thấy" |
| `test/features/bill/presentation/pages/bill_auto_pay_ui_test.dart` | Công tắc tắt sẵn; form Sửa nạp và ghi được cờ tắt. Dòng phụ nay khẳng định **"mọi thiết bị"** và cấm chuỗi **"một thiết bị"** xuất hiện — lời khuyên cũ *"chỉ nên bật trên một thiết bị"* vừa sai vừa không làm theo được từ khi `auto_pay` đi qua đồng bộ (2026-09-13) |
| `test/features/bill/bill_payment_conflict_resolver_test.dart` | Resolver lọc đúng `entity` + `code`; hai bản ghi thoát hàng đợi (khoản chi `synced`, **hoá đơn thì KHÔNG**); hoá đơn phải ở trạng thái **đã trả**, không được về `Pending`; thông báo sinh đúng một lần và không nêu số tiền |
| `test/features/bill/bill_conflict_go_dung_khoan_chi_test.dart` | Dựng `BillRepositoryImpl` **thật** vì fake không thấy được lỗi: gỡ **đúng** khoản mang `localId` bị từ chối bất kể thứ tự hàng, không hoàn tiền hai lần khi phát lại, hoàn vào **đúng ví**, và vẫn gỡ được khi pull đã kéo hoá đơn về `Pending` |
| `test/features/bill/bill_conflict_resolver_wiring_test.dart` | Resolver được **bắt đầu nghe** chứ không chỉ được dựng; `pushResultStream` chịu được hai người nghe |
| `test/core/sync/sync_push_result_truoc_pull_test.dart` | *(ngoài thư mục bill)* `SyncEngine` phát kết quả đẩy **TRƯỚC** bước Pull — nếu không, phép hoàn tiền cộng vào số dư đã bị server đè lên |

⚠️ `.gitignore:77` có `test/` nên file test mới bị git bỏ qua **âm thầm** —
nhớ `git add -f` từng đường dẫn (thêm cả thư mục thì git từ chối nguyên lệnh).

⚠️ Chạy **hai tiến trình `flutter test` cùng lúc** — hoặc để lại
`flutter_tester.exe` mồ côi sau khi ngắt một lần chạy — làm công cụ Flutter
crash với `PathExistsException ... sqlite3.dll`, và tệp hỏng còn lại khiến
**mọi** lần chạy sau đều crash. Chữa: tắt hết `flutter_tester.exe` (Task
Manager; `dartvm.exe` của VS Code thì để yên), xoá `build/native_assets/windows`,
rồi chạy lại **một lần duy nhất**. Đừng ngắt `flutter test` giữa chừng; muốn
chặn treo thì chạy nền ghi log và dùng `--timeout 60s`.

**Ba lỗi máy ảo bắt được mà bộ test bỏ lọt** (06/09): trang trắng sau thông
báo lỗi, nhãn "Chưa có danh mục" sai cho danh mục đã xoá, và bốn chu kỳ xếp
dọc. Đụng giao diện hoá đơn thì phải xem ở 411dp trên máy ảo trước khi báo
xong — không phải Chrome.
