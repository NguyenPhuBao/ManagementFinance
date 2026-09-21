# Trang Sổ giao dịch — phạm vi kỳ và bộ lọc theo số tiền

**Viết:** 2026-09-21 · **Trạng thái:** ✅ **đã thi công 2026-09-21** — Task 1–4 xong
(4 commit, 31 ca mới, `flutter test` **3200/3200, 1 skip**, analyze **26/0**);
✅ **Task 5 cũng xong** — nghiệm thu máy ảo 411dp
cùng ngày, muộn hơn một phiên: **năm trong sáu** việc phải thấy tận mắt là đạt,
việc thứ sáu lộ ra **G48** (một lỗi **không thuộc lát này**, có từ nhóm D). Lượt
ấy bắt thêm **hai** lỗi của chính lát này, cả hai ở **kỳ rỗng** và cả hai đã sửa
— nên mốc test cuối cùng của lát là **3202/3202, 1 skip**. Tường thuật: mục **14**
`docs/PROJECT_CONTEXT.md`, khối đầu.
**Thuộc:** nửa đầu của việc **2.1** trong `docs/superpowers/plans/2026-09-21-ai-viec-tiep-theo.md`

---

## 1. Vì sao có tài liệu này

Kế hoạch 2.1 xếp *"mở rộng `TransactionFilter` để lọc theo khoảng tiền và khoảng
ngày"* thành **một** việc làm được ngay, và ghi rằng nó là tính năng thật *"đáng làm
kể cả khi bỏ hẳn AI"*. Lượt khảo sát ngày 2026-09-21 cho thấy vế **khoảng ngày** không
làm được như thế, và lý do đáng ghi lại.

Trang Sổ giao dịch **nạp dữ liệu theo từng tháng**:

- `TransactionBloc._subscribeMonth` (dòng 38–45) đăng ký `watchTransactionsByMonth`;
- `TransactionDao.watchByMonth` (dòng 162–173) kẹp cứng `[ngày 1, ngày cuối tháng]`;
- trang lọc trên chính tập ấy — `applyTransactionFilter(state.monthlyTransactions, _filter)`
  (`transaction_page.dart:170`).

Nên nếu chỉ thêm hai trường ngày vào `TransactionFilter`, **khoảng ngày bị kẹp trong
tháng đang xem**. Hệ quả có hai mặt, mặt thứ hai nặng hơn:

1. Câu lệnh mẫu mà 2.1 nhắm tới — *"tháng trước tôi tiêu gì trên 500k"* — **không chạy
   được**, vì "tháng trước" nằm ngoài tập dữ liệu.
2. Trang sẽ có **hai bộ điều khiển thời gian chồng nhau**. Người dùng đặt khoảng
   `01/08–15/08` trong khi bộ chọn tháng đang ở tháng 9 sẽ thấy danh sách **rỗng** mà
   không một dòng nào nói vì sao — hai bộ lọc triệt tiêu nhau, **im lặng**.

Vì thế khoảng ngày được làm đúng chỗ của nó: **thay luôn phép buộc-theo-tháng**.

---

## 2. Bốn quyết định người dùng đã chốt (2026-09-21)

| # | Câu hỏi | Chốt |
|---|---|---|
| 1 | Phạm vi của "lọc theo khoảng ngày" | **Lối B** — khoảng ngày thành **nguồn dữ liệu**, thay bộ chọn tháng bằng bộ chọn kỳ dùng chung |
| 2 | Hai mũi tên ‹ › lật tháng | **Giữ**, cộng nút giữa mở sheet |
| 3 | Cách nhập khoảng tiền | **Hai ô "từ … đến …"**, mỗi ô được phép để trống. Không chip nhanh, không dropdown toán tử |
| 4 | Chỗ đặt `Ky` | **Để nguyên** `features/analytics/domain/`, import chéo |

### 2.1 Vì sao hai ô là đủ

Đối chiếu app thị trường trước khi chốt (nếp của dự án):

- **Monarch Money** lọc số tiền bằng bốn toán tử — *bằng · lớn hơn · nhỏ hơn · khoảng giữa*.
- **YNAB** chỉ tìm theo văn bản (payee, memo, category); **không** có lọc theo tiền.

Hai ô mà mỗi ô được phép để trống **phủ trọn cả bốn** toán tử của Monarch: để trống ô
"đến" chính là *lớn hơn*, để trống ô "từ" là *nhỏ hơn*, điền cả hai là *khoảng giữa*.
Nên không cần dropdown toán tử — thêm nó là dạy người dùng một khái niệm mà hình dạng
của ô đã nói rồi.

### 2.2 Vì sao KHÔNG có chip nhanh

Đã cân nhắc hàng chip *"trên 100k · trên 500k · trên 1 triệu"*. Bỏ vì ba con số ấy là
**hằng cứng** — đúng thứ mục **11.5** `AI_EDGE_FEATURE.md` vừa đi sửa ở chỗ khác: người
thu nhập 5 triệu và người 50 triệu không có cùng ngưỡng "khoản lớn". Bản neo theo
`thuNhap3Thang` thì đúng, nhưng giá là mở thêm một nguồn dữ liệu cho trang **chỉ để vẽ
ba cái chip**. Để dành; hai ô đã dùng được.

### 2.3 Vì sao `Ky` không chuyển lên `core/`

Sau lát này **ba trang** dùng `Ky` (Phân tích, Xuất báo cáo, Sổ giao dịch), nên tên thư
mục `features/analytics/` nói sai phạm vi. Vẫn để nguyên, vì:

- chuyển là **~25 tệp** phải sửa (19 chỗ gọi `DonViKy`, cộng test và tài liệu dẫn đường
  dẫn cũ) mà **không thêm giá trị nào** cho người dùng;
- repo đã có **41** chỗ import chéo giữa các feature — đây là nếp có sẵn, không phải
  ngoại lệ;
- `pham_vi_ky.dart` chỉ import `core/notification/tuan_iso.dart`, tức nó vốn đã gần
  thuần và không kéo theo gì của analytics.

**Bù lại:** thêm một dòng ở đầu `pham_vi_ky.dart` liệt kê ba trang đang dùng, để người
sau không phải `grep` mới biết nó không còn là của riêng Phân tích. Chuyển thư mục, nếu
muốn, là việc độc lập làm một lượt riêng.

---

## 3. Luồng dữ liệu — năm tệp

```
transaction_dao.dart                watchByMonth(id, year, month)      → watchKhoang(id, from, to)
transaction_local_data_source.dart  watchTransactionsByMonth(id, y, m) → watchKhoang(id, from, to)   [abstract + impl]
transaction_repository.dart         watchTransactionsByMonth(id, y, m) → watchKhoang(id, from, to)   [abstract + impl]
transaction_bloc.dart               _subscribeMonth(id, y, m)          → _subscribeKy(id, ky)
                                    FilterMonthEvent(year, month)      → ChonKyEvent(ky)
                                    TransactionsUpdatedEvent(list,y,m) → TransactionsUpdatedEvent(list, ky)
                                    selectedYear + selectedMonth       → ky
                                    transactions + monthlyTransactions → giaoDich          (một danh sách)
transaction_page.dart               _selectedMonthDate                 → _ky
                                    _changeMonth(dY, dM, ctx)          → _doiKy(int buoc)
                                    _buildMonthSelector                → header ba phần
```

**Thay thế, không thêm.** `watchByMonth` chỉ có **một** chỗ gọi (datasource), nên giữ
lại nó là để hai đường đọc cùng một bảng với **hai quy ước biên khác nhau** — xem bẫy 1.

### 3.1 Biên đổi từ đóng sang nửa mở

`watchByMonth` hiện dùng biên **đóng** cả hai đầu:

```dart
final from = DateTime(year, month, 1);
final to   = DateTime(year, month + 1, 0, 23, 59, 59);
…  t.date.isBiggerOrEqualValue(from) & t.date.isSmallerOrEqualValue(to)
```

`Ky` dùng `[from, to)`. Lấy theo `Ky`, vì đó là quy ước đã ghi trong **chính DAO ấy**
cho `tuanTruoc` / `tongThuChi`: *"Biên `to` mở … lấy biên đóng thì một khoản ghi đúng
nửa đêm bị đếm vào hai tuần."* Trộn hai quy ước biên trong một DAO là chỗ hỏng im lặng.

### 3.2 Bỏ phép lọc lần hai trong bloc

`_emitLoadedState` nhận `allTx` rồi lọc lại theo `year/month` thành `monthlyTransactions`.
Phép ấy **thừa** — DAO đã trả đúng tháng — và sau khi đổi sang kỳ thì hai danh sách
bằng nhau từng phần tử.

Đo trước khi bỏ: **không nơi nào đọc `state.transactions`**; bốn chỗ nhắc tới nó đều
nằm trong chính bloc/state/event. Nên state còn **một** danh sách.

### 3.3 Bốn chỗ dựng state rỗng

`transaction_bloc.dart` dòng 89, 110, 160 (và 208) điền `now.year` / `now.month` làm giá
trị giữ chỗ khi chưa có state nào. Chúng thành **`Ky.thang(now.year, now.month)`** — chữ ký là `Ky.thang(int nam, int thang)`,
**không** nhận một `DateTime`. (Bản đầu của tài liệu này viết `Ky.thang(now)`; lượt tự
soát bắt được.)

---

## 4. Hợp đồng bộ lọc

### 4.1 `KhoangTien` — tệp mới `transaction/domain/khoang_tien.dart`

```dart
class KhoangTien {
  const KhoangTien({this.tu, this.den});
  final double? tu;    // null = không chặn dưới
  final double? den;   // null = không chặn trên

  bool get rong  => tu == null && den == null;
  bool get hopLe => tu == null || den == null || tu! <= den!;
}
```

**Vì sao một lớp chứ không hai trường phẳng.** `TransactionFilter.copyWith` dùng khuôn
cờ `clearWallet` / `clearCategory` để phân biệt *"không truyền"* với *"truyền null"*.
Khoảng tiền có **hai** vế nên khuôn ấy vỡ: một cờ `clearSoTien` sẽ xoá nhầm cả cặp khi
người dùng chỉ muốn bỏ vế dưới. Gói thành một khái niệm thì `copyWith` nhận cặp
`khoangTien` + `clearKhoangTien` đúng khuôn đã có, và phép hợp lệ hoá có **một** chỗ.

Lợi ích thứ ba, cho nửa sau của 2.1: mô hình sinh ra **một** đối tượng chứ không hai số
rời, nên schema kiểm được.

### 4.2 `TransactionFilter`

Thêm **một** trường `KhoangTien? khoangTien` (`null` = không lọc); `isActive` thêm một
vế `khoangTien != null`; `copyWith` thêm `khoangTien` + `clearKhoangTien`.

### 4.3 Phép lọc

```dart
final kt = filter.khoangTien;
if (kt != null) {
  if (kt.tu  != null && t.amount < kt.tu!  - 0.5) return false;
  if (kt.den != null && t.amount > kt.den! + 0.5) return false;
}
```

**`amount` luôn dương** trong SQLite client — chiều tiền nằm ở `type`, `.abs()` áp ở cả
đường ghi tay lẫn nhánh kéo về, dấu chỉ áp lúc đẩy lên server. Nguồn: docstring của cột
`amount` ở `core/database/tables/transactions_table.dart` (đã sửa 2026-09-12 — trước đó
nó nói *"Amount giữ dấu ±"*, tức mô tả cột PostgreSQL, và chính chú thích sai ấy đã đẻ
ra lỗi **A3** trong đặc tả Edge-SLM do backend quản).

Nên so thẳng là đúng, **không** cần `.abs()`, và bộ lọc áp cho cả `thu`, `chi` lẫn
`transfer`: câu *"khoản trên 500k"* không phân biệt chiều.

**Ngưỡng nửa đồng.** Xem bẫy 4.

---

## 5. Giao diện

⚠️ **Vẽ Stitch trước khi dựng.** Hai khối dưới đây đều mới với dự án.

### 5.1 Header — thay `_buildMonthSelector`

```
┌──────────────────────────────────┐
│  ‹    📅 Tháng này (T9 2026)   › │
└──────────────────────────────────┘
     ↑          ↑              ↑
  lui 1 kỳ   mở sheet      tiến 1 kỳ
```

- Nhãn giữa lấy từ **`nhanRong(ky, DateTime.now())`** — hàm đã có, tự thêm nếp
  *"Tháng này (…)"* khi kỳ **chứa** hôm nay và bỏ nếp ấy khi không.
- Chạm nhãn → `moChonPhamVi(context, kyHienTai: _ky, moc: now)` — **cùng** sheet hai tầng
  mà trang Phân tích và trang Xuất báo cáo đang dùng. Không dựng bộ chọn thứ hai.
- ‹ › gọi `lui(_ky, 1)` và `lui(_ky, -1)`.

### 5.2 Chip "Số tiền" trên thanh lọc

Thêm một chip sau chip "Danh mục", cùng khuôn `_chip(...)` đã có. Nhãn đổi theo trạng
thái: `Số tiền` → `Từ 500.000 đ` → `500.000 – 2.000.000 đ` → `Đến 2.000.000 đ`.

Chạm chip → bottom sheet hai ô:

```
┌──────────────────────────┐
│  Lọc theo số tiền        │
│  Từ   [ 500.000      đ ] │
│  Đến  [ (mọi mức)    đ ] │
│         [Xoá]  [Áp dụng] │
└──────────────────────────┘
```

- Cả hai ô **được phép để trống**.
- `tu > den` → nút **Áp dụng tắt** kèm một dòng giải thích. Không tự hoán đổi: hoán đổi
  là đoán ý người dùng, và đoán sai thì kết quả trông vẫn hợp lý.
- Cả hai ô **bắt buộc** mang `GioiHanSoChuSo(kSoChuSoToiDaSoTien)` — xem bẫy 5.

### 5.3 Không đổi

Thẻ tổng vẫn tính trên **tập đã lọc** (`summarizeTransactions(txs)`), giữ nguyên chủ ý
đã ghi ở `transaction_page.dart:167-169`: *"thẻ tổng và danh sách cùng tính trên tập đã
lọc để hai thứ luôn nói cùng một chuyện."* Nên lọc "từ 500k" thì thẻ tổng cộng đúng các
khoản trên 500k, **không** phải tổng cả kỳ.

`_filter` vẫn **giữ nguyên khi đổi kỳ** — chủ ý đã có (`transaction_page.dart:49-50`).

---

## 6. Sáu cái bẫy, và cách canh từng cái

| # | Bẫy | Hỏng thế nào | Ca test canh |
|---|---|---|---|
| 1 | **Biên nửa mở** `[from, to)` | giao dịch ghi đúng mốc `to` bị đếm vào **hai** kỳ | khoản đặt đúng `to` **không** thuộc kỳ này, **thuộc** kỳ sau |
| 2 | **`lui` với kỳ Tuỳ chọn** | mũi tên phải lùi đúng **độ dài khoảng**, không phải một tháng | kỳ tuỳ chọn 17 ngày, bấm ‹ → lùi đúng 17 ngày |
| 3 | **Nhãn header** | header này hẹp hơn trang Phân tích vì **hai mũi tên** chiếm chỗ | ca ở **tầng thuần**, đòi mọi nhãn ≤ độ dài nhãn tháng |
| 4 | **`± 0.5`** | khoản đúng bằng biên rơi khỏi bộ lọc, im lặng | `amount = 499999.99999994`, lọc "từ 500.000" → **vẫn khớp** |
| 5 | **Trần số chữ số** | tràn `numeric(15,2)` → `22003` → `DB_ERROR` → bản ghi **gửi lại mọi chu kỳ đồng bộ** | **test quét thứ tám** `test/core/utils/o_nhap_tien_co_tran_test.dart` tự đỏ nếu quên |
| 6 | **`initialWalletId`** | đường tắt từ màn Quản lý ví phải còn chạy sau khi đổi nguồn | ca widget đã có, giữ nguyên |

### Bẫy 3 nói rõ thêm

Luật *"không nhãn nào được dài hơn nhãn tháng"* đã tồn tại từ lát P1 của trang Phân tích
(mục **3.20** `ANALYTICS_FEATURE.md`): nhãn quý phải là `Q3 2026` chứ không `Quý 3 2026`,
vì dạng đầy đủ làm ô header cụt mất cả năm trên máy thật. Header của trang Sổ giao dịch
**còn hẹp hơn** vì hai mũi tên ăn chỗ hai bên.

⚠️ Ca test phải ở **tầng thuần** (so độ dài chuỗi), **không** đo bề rộng ở 411dp: font
của bộ test rộng gấp đôi ngoài đời nên ở khổ ấy chuỗi nào cũng cụt và ca test vô nghĩa.

### Bẫy 4 nói rõ thêm

`amount` là `double`, và khoản **điều chỉnh số dư** mang đuôi lẻ có thật. Một khoản đúng
`500.000` mà máy giữ là `499999.99999994` sẽ rơi khỏi bộ lọc "từ 500.000" — không lỗi,
không log, chỉ một dòng biến mất. Đây là **ngưỡng nửa đồng**, cùng phép mà
`dieu_chinh_so_du_service.dart` và `ranhVuotTrungBinh` đã dùng.

---

## 7. Ngoài bộ test

⚠️ **Nghiệm thu máy ảo 411dp bắt buộc.** Lát này đụng cả ba vùng mù của `flutter test`:

1. **Tràn bố cục** — header ba phần ở 411dp, và nhãn kỳ dài nhất (`26/08 – 11/09/2026`).
2. **Điều hướng** — trang Sổ giao dịch nằm **trong** `StatefulShellRoute`; sheet mở từ
   đây phải dùng đúng `context`.
3. **Thứ tự hai luồng bất đồng bộ** — đổi kỳ huỷ subscription cũ rồi đăng ký mới; nếu
   stream cũ phát nốt một lần sau khi huỷ thì danh sách nháy dữ liệu kỳ cũ.

Cộng **hai** tệp test hiện dùng `watchTransactionsByMonth` phải đổi theo:
`test/features/category/presentation/category_test_fakes.dart` và
`test/shared/widgets/main_shell_tab_so_giao_dich_test.dart`.

---

## 8. Cố ý KHÔNG làm

- **Không** chip nhanh cho khoảng tiền — mục 2.2.
- **Không** chuyển `pham_vi_ky.dart` lên `core/` — mục 2.3.
- **Không** đổi thẻ tổng sang "tổng cả kỳ" — mục 5.3.
- **Không** đụng schema, **không** thêm trường đồng bộ, **không** đụng repository của
  mảng nào khác. Bộ lọc chạy thuần Dart trên tập đã nạp, đúng như hôm nay.
- **Không** làm nửa sau của 2.1 (function calling cho mô hình) trong lát này. Nửa sau
  cần phép đo tỉ lệ chọn đúng hàm, và nó chỉ có nghĩa khi bộ lọc đã có đủ trường để
  chọn.

---

## 9. Xong khi

- ✅ `flutter test` **trọn bộ** xanh — **3200/3200, 1 skip** (mức nền trước lát này là
  3169, cộng **31** ca mới).
- ✅ `flutter analyze` **26 issue, 0 error**.
- ✅ Mọi ca test mới **đỏ với bản sai có chủ ý** — đã thử **năm** bản sai: bỏ dung sai
  nửa đồng · bỏ vế `khoangTien` khỏi `isActive` · đổi biên nửa mở thành biên đóng ·
  đảo chiều mũi tên trái · bỏ `GioiHanSoChuSo` khỏi ô tiền (test quét thứ tám bắt, và
  gọi đúng tên tệp). Mỗi bản sai làm **đúng** ca tương ứng đỏ.
- Nghiệm thu máy ảo 411dp: đổi kỳ bằng cả ‹ › lẫn sheet, lọc tiền ba dạng (chỉ "từ",
  chỉ "đến", cả hai), và đường tắt từ màn Quản lý ví.
- Màn Stitch cho header và sheet lọc tiền đã vẽ.
