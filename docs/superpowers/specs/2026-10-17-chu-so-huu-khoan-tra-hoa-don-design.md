# Spec — Nhận khoản trả hoá đơn bằng `billId`; mở khoá có cảnh báo cho khoản kiểu cũ và khoản mồ côi (việc 4c)

**Ngày:** 2026-10-17 · **Nhánh:** `TranQuangDat` · **Trạng thái:** thiết kế đã duyệt, **chưa** có kế hoạch thi công.
**Phạm vi:** chỉ `src/Client-app`. Không đổi lược đồ Drift (v31), không đổi payload đồng bộ, không cần backend.

## 0. Người dùng đã chốt (2026-10-17)

1. Khoản trả hoá đơn **kiểu cũ** (có tiền tố ghi chú `kGhiChuTraHoaDon`, không có `billId`) → **mở khoá có cảnh báo** ở
   Sổ giao dịch: sửa / xoá được, hộp xác nhận xoá nói rõ hệ quả.
2. Khoản chi **mồ côi** (có `billId`, hoá đơn đã bị xoá mềm) → **mở khoá có cảnh báo**, cùng cách.
3. Cách dựng **A — hỏi ngay lúc thao tác** qua một cổng nhỏ (mục 3.2), không nạp sẵn bảng tra, không đổi dữ liệu.
   Áp cho Sổ giao dịch **và** bảng chi tiết mở từ trang Chi tiết ngân sách.

## 1. Vấn đề — người dùng thấy gì

`transactionOwnerOf` (`lib/features/transaction/domain/transaction_owner.dart`) quyết khoản nào bị **khoá** ở Sổ giao dịch
(vuốt xoá bị từ chối; bảng chi tiết ẩn Sửa / Xoá, hiện ổ khoá). Nó nhận khoản trả hoá đơn **bằng tiền tố ghi chú**
`'Thanh toán hóa đơn: '`, không đọc cột `billId`. Hệ quả:

- **Khoản kiểu cũ kẹt vĩnh viễn.** Hàng ghi trước 2026-09-06 (trước schema v16), hoặc ghi từ 06/09 tới 12/09 rồi kéo
  về ở máy khác (đẩy lên chưa kèm `idbill`), có tiền tố mà `billId` NULL. Ở trang Hoá đơn, *Hoàn tác* ném
  `BillUndoUnavailableException` và báo *"…ghi bằng bản ứng dụng cũ. Hãy xoá nó thủ công ở sổ giao dịch."* — nhưng sổ
  khoá đúng hàng ấy vì tiền tố. Không lối nào gỡ được. **Đo máy ảo 2026-10-17** (tài khoản 10, bản sao CSDL chỉ đọc):
  **3** khoản kiểu cũ sống, 6 khoản có cả tiền tố lẫn `billId`, 0 khoản `billId` mà thiếu tiền tố. Realme 2026-09-29: 3
  hàng như thế trong cửa sổ 90 ngày (`analytics_repository_impl.dart`).
- **Khoản mồ côi kẹt vĩnh viễn.** Từ 2026-10-17 xoá được kỳ **đã trả** qua màn xác nhận (`BILL_DOCUMENTATION.md` mục
  6.10): hoá đơn và nút Hoàn tác biến mất, khoản chi ở lại sổ và vẫn bị khoá (owner theo tiền tố). Hoá đơn bị xoá ở máy
  khác rồi đồng bộ về cũng vậy. Đo máy ảo hôm nay: 0 khoản mồ côi — nhưng màn xoá mới mở đường sinh ra chúng.
- **Ghi chú hỏng thì mất khoá.** Nhánh kéo về ghi đè `note` vô điều kiện (`sync_engine.dart` ~:707); `decrypt()` hỏng
  trả chuỗi `enc:…` (`docs/superpowers/backend/TRANSACTION_NOTE_ENCODING.md`). Khi tiền tố mất, khoản trả hoá đơn có
  `billId` thành giao dịch thường — xoá rời được, đúng loại hỏng im lặng mà khoá sinh ra để chặn.
- **Chú thích nói sai.** Chú thích `kGhiChuTraHoaDon` bảo `TransactionEntity` không mang `billId` và hàng kéo về luôn
  trống cột — sai từ `a8deac2a` (2026-10-14) và `285b0093` (2026-09-12).

Tiền lệ đọc *`billId` trước, tiền tố sau* đã có: `_laKhoanCamKet` (`analytics/data/repositories/analytics_repository_impl.dart`).

## 2. Hiện trạng mã (đo 2026-10-17)

- **Nơi ghi khoản trả** — duy nhất `BillRepositoryImpl.payBill` (trả tay qua `BillBloc`, tự trả qua
  `BillAutoPayRunner`): ghi **cả** `note: ghiChuTraHoaDon(...)` lẫn `billId` trong một `db.transaction`.
- **`TransactionEntity.billId`** có từ `a8deac2a`, **chỉ đọc** (`toCompanion` không mang; sửa giao dịch qua `.write` giữ
  cột vắng mặt). Không đường giao diện nào đổi / xoá được `billId`.
- **Đồng bộ**: đẩy `idbill` (`sync_engine.dart` ~:1555, khoá trong `sync_payload_contract_test.dart`); kéo về đọc
  `idbill` / `bill_id`, thiếu thì `Value.absent()` (~:728). **Chưa có** ca test kéo về giao dịch mang / thiếu `idbill`.
- **Người gọi `transactionOwnerOf`** — chỉ hai, đều qua `lyDoKhongXoaTaiSo`:
  - `transaction/presentation/widgets/transaction_list_row.dart` `confirmDismiss` — có lý do thì toast + trả `false`;
    không lý do thì trả `true` **không hỏi gì** (vuốt là xoá).
  - `transaction/presentation/widgets/transaction_detail_sheet.dart` — có lý do thì hiện khung ổ khoá, ẩn Sửa / Xoá.
    Bảng mở từ ba chỗ: Sổ (`transaction_page.dart` `_showDetail`), Chi tiết ngân sách (`budget_detail_page.dart`),
    trang Hoá đơn (`bill_page.dart` `_moKhoanChi` — `onDelete` luôn từ chối, chỉ đường Hoàn tác).
- **`BillRepository.getById`** đọc cả hàng đã xoá mềm (`billDao.getById`), `BillEntity.isDeleted` có sẵn.
- **Kiến trúc**: `bill/domain/bill_note.dart` import `transaction_owner.dart` (cạnh `bill → transaction`); chiều chuẩn
  `analytics → bill → transaction → category` (quét 29, `conCho` rỗng). Mảng transaction **không** được import bill.

## 3. Thiết kế

### 3.1 Luật chủ sở hữu và câu cảnh báo (`transaction/domain/transaction_owner.dart`)

```dart
TransactionOwner transactionOwnerOf(TransactionEntity tx, {bool hoaDonDaXoa = false});
String? canhBaoXoaTaiSo(TransactionEntity tx, {bool hoaDonDaXoa = false});
```

| # | Điều kiện (xét theo thứ tự) | Owner | `lyDoKhongXoaTaiSo` | `canhBaoXoaTaiSo` |
|---|---|---|---|---|
| 1 | `goalId != null`, hoặc ghi chú mang tiền tố mục tiêu (ba tiền tố hiện có) | `goal` | câu mục tiêu (giữ nguyên) | `null` |
| 2 | `billId != null` và **không** `hoaDonDaXoa` | `bill` | câu hoá đơn (giữ nguyên) | `null` |
| 3 | `billId != null` và `hoaDonDaXoa` (**mồ côi**) | `transaction` | `null` | *"Hoá đơn của khoản này đã xoá — xoá ở đây chỉ trả tiền về ví."* |
| 4 | `billId == null` và ghi chú bắt đầu bằng `kGhiChuTraHoaDon` (**kiểu cũ**) | `transaction` | `null` | *"Khoản trả hoá đơn ghi bằng bản cũ — xoá ở đây chỉ trả tiền về ví, hoá đơn vẫn ghi là đã trả."* |
| 5 | còn lại | `transaction` | `null` | `null` |

- Hàng 2 **không xét ghi chú**: khoản trả có `billId` bị khoá kể cả khi ghi chú đã hỏng lúc kéo về (vá vế thứ ba mục 1).
- Mặc định `hoaDonDaXoa = false` ⇒ nơi nào chưa hỏi cổng (trang Hoá đơn, mọi người gọi tương lai) coi khoản có
  `billId` là **còn khoá** — mặc định an toàn.
- `canhBaoXoaTaiSo` là hàm thuần, câu chữ ở **một** chỗ. So tiền tố bằng `startsWith` trên ghi chú thô (không
  `trimLeft`) — cùng phép với `transactionOwnerOf` hiện nay và `laGhiChuMay`.
- Enum `TransactionOwner` không đổi (không thêm giá trị) — `lyDoKhongXoaTaiSo` vẫn là `switch` đủ ba nhánh.

### 3.2 Cổng `HoaDonDaXoaNguon` (`transaction/data/hoa_don_da_xoa_nguon.dart`)

```dart
class HoaDonDaXoaNguon {
  const HoaDonDaXoaNguon(this._doc);
  final Future<bool> Function(String billId) _doc;
  /// `true` chỉ khi hàng hoá đơn CÓ trên máy và đã xoá mềm. Không có hàng (chưa kéo về) hay kho lỗi → `false` (khoá).
  Future<bool> daXoa(String billId) async { try { return await _doc(billId); } catch (_) { return false; } }
}
```

- Cùng khuôn `bill/data/so_ngay_nhac_nguon.dart`: mảng transaction chỉ khai cổng; **DI** (`core/di/injection_container.dart`,
  điểm ghép) nối `(id) async => (await sl<BillRepository>().getById(id))?.isDeleted ?? false`. Không thêm cạnh
  `transaction → bill` ở tầng nào; quét 29 không đổi.
- `billId` trỏ vào hoá đơn **chưa có** trên máy → `false` → khoá: chưa biết thì không mở.

### 3.3 Sổ giao dịch — vuốt xoá (`TransactionListRow`)

- Thêm tham số tuỳ chọn `HoaDonDaXoaNguon? hoaDonDaXoa`. `TransactionPage` truyền `sl<HoaDonDaXoaNguon>()` nếu đã đăng
  ký (`sl.isRegistered`), không thì `null` (test dựng dòng đơn lẻ, mọi hành vi như cũ).
- `confirmDismiss`:
  1. `daXoa = tx.billId != null && nguon != null ? await nguon.daXoa(tx.billId!) : false`;
  2. có `lyDoKhongXoaTaiSo(transactionOwnerOf(tx, hoaDonDaXoa: daXoa))` → toast lý do, trả `false` (như cũ);
  3. có `canhBaoXoaTaiSo(tx, hoaDonDaXoa: daXoa)` → `ConfirmDialog.show(title: 'Xoá giao dịch?', message: <câu cảnh báo>)`,
     trả kết quả hộp thoại (huỷ → dòng bật lại, không xoá);
  4. còn lại trả `true` — **giao dịch thường giữ nguyên hành vi vuốt-là-xoá** (không thêm hộp thoại).
- Kiểm `context.mounted` sau mỗi `await` trước khi mở hộp thoại.

### 3.4 Bảng chi tiết (`TransactionDetailSheet`) và hai trang mở nó

- Bảng nhận thêm `bool hoaDonDaXoa = false`, dùng cho cả `transactionOwnerOf` (ẩn / hiện Sửa · Xoá) — bảng vẫn **không**
  tự hỏi cổng (giữ là widget thuần, test được không cần `sl`).
- `TransactionPage._showDetail` và `BudgetDetailPage` (hàm mở bảng tương ứng): khoản có `billId` thì `await
  nguon.daXoa(...)` **trước** khi `showModalBottomSheet`, truyền kết quả vào bảng.
- Nhánh `onDelete` của hai trang: `message` của `ConfirmDialog` = câu cảnh báo (nếu có) + `' '` + câu cũ *"Số dư ví sẽ
  được hoàn lại. Không hoàn tác được."*; không cảnh báo thì như cũ.
- **Trang Hoá đơn (`_moKhoanChi`) không đổi**: nó chỉ mở khoản của hoá đơn **đang hiện** trên trang (tra theo `billId`
  của hàng sống), nên không bao giờ gặp hàng 3 / 4 của bảng; truyền mặc định `false`, `onDelete` vẫn chỉ đường Hoàn tác.

### 3.5 Câu của *Hoàn tác* với khoản kiểu cũ

- `BillBloc._onUndoPayment` nhánh `BillUndoUnavailableException`: đổi câu cho khớp lối đi nay có thật —
  *"Không hoàn tác được: khoản chi của lần thanh toán này được ghi bằng bản ứng dụng cũ. Xoá nó ở Sổ giao dịch để trả
  tiền về ví — kỳ này vẫn ghi là đã trả."*
- `BillPaymentConflictResolver` bắt cùng ngoại lệ nhưng chỉ `debugPrint` — không đổi.

### 3.6 Chú thích lỗi thời phải sửa cùng lượt

| Chỗ | Câu sai | Sửa thành (ý) |
|---|---|---|
| `transaction_owner.dart`, chú thích `kGhiChuTraHoaDon` | `TransactionEntity` không mang `billId`; hàng kéo về luôn trống cột; tiền tố là mối nối duy nhất | hằng là cách **ghi** + nhận diện **hàng kiểu cũ**; `billId` là mối nối chính (bảng 3.1) |
| `transaction_entity.dart` chú thích `goalId` | cột cục bộ, không đi qua đồng bộ, hàng kéo về luôn trống | đồng bộ dưới tên `idgoal` từ 2026-09-07; hàng **cũ** trên server vẫn NULL (G18) |
| `bill_repository.dart` chú thích `BillUndoUnavailableException` | `billId` cục bộ; mọi hàng kéo về để trống | `billId` đồng bộ (`idbill`) từ 2026-09-12; hàng trống là hàng ghi trước ấy |
| `transaction_dao.dart` chú thích `getBillPayments` | hoá đơn kéo về không có mục ở đây (cột cục bộ) | chỉ hàng ghi trước 2026-09-12 không có mục |
| `test/…/bill_page_payment_info_test.dart` `reason` | *"Hàng kéo về không có `billId`"* | *"Hàng không có `billId` (ghi trước 2026-09-12)"* |

Chú thích bước di trú v16 ở `app_database.dart` là **lịch sử** của bước ấy — giữ, chỉ thêm *"(đồng bộ từ 2026-09-12)"*
nếu câu đứng ở thì hiện tại.

## 4. Ngoài phạm vi (cố ý)

- **Các chỗ đọc tiền tố vì lý do khác** — không phải câu "ai sở hữu": `laGhiChuMay` (loại ghi chú do máy viết khỏi mẫu
  học B1 / C1), `xetGan` / `demChuaGan`, `_laKhoanCamKet` (đã `billId` trước), `khoaNhomCua` (chỉ `billId` — hàng kiểu
  cũ lọt vào phép tìm khoản lặp B2; ghi nhận, không sửa lượt này).
- **Không đổi cách ghi**: `payBill` vẫn ghi cả tiền tố lẫn `billId` — tiền tố còn là chữ người dùng đọc và là dấu cho
  `laGhiChuMay`.
- **Không suy `billId` cho hàng kiểu cũ** (cùng lý lẽ `BillUndoUnavailableException`: đoán trượt là hoàn tiền bằng khoản
  chi khác).
- **Không đổi trạng thái hoá đơn** khi xoá khoản ở sổ: kỳ vẫn `Payed` — câu cảnh báo nói đúng điều ấy.
- **Không mở khoá ở trang Hoá đơn**, không thêm hộp xác nhận cho vuốt xoá giao dịch thường.

## 5. Ca biên

| Ca | Hành vi |
|---|---|
| Người dùng tự gõ ghi chú bắt đầu bằng tiền tố (không `billId`) | hàng 4: xoá được kèm câu "bản cũ" — câu thừa nhưng vô hại; trước đây bị **khoá nhầm** |
| Ghi chú khoản trả có `billId` bị hỏng / mã hoá lúc kéo về | hàng 2: vẫn khoá (trước đây mất khoá) |
| Hoá đơn bị xoá ở máy B, máy A chưa kéo bản xoá | A vẫn khoá tới khi kéo về |
| `billId` trỏ hoá đơn chưa kéo về máy | khoá (cổng trả `false`) |
| Kho / `getById` ném | khoá (cổng nuốt lỗi, `false`) |
| Sửa khoản mồ côi / kiểu cũ ở sổ | `toCompanion` không mang `billId` → cột giữ nguyên; hàng vẫn mồ côi / kiểu cũ |
| Xoá khoản mồ côi → đồng bộ | đẩy xoá mềm giao dịch như mọi giao dịch; hoá đơn trên server đã xoá; không đụng chốt trả hai lần |

## 6. Kiểm thử (TDD — mỗi ca canh thử bằng một bản sai có chủ ý)

- `test/features/transaction/domain/transaction_owner_test.dart` — helper `tx()` thêm `billId`:
  - `billId` + hoá đơn còn → `bill`, **kể cả** ghi chú `'enc:…'` / ghi chú thường;
  - `billId` + `hoaDonDaXoa` → `transaction`, cảnh báo "Hoá đơn của khoản này đã xoá";
  - tiền tố + `billId` NULL → `transaction`, cảnh báo "bản cũ";
  - mặc định không truyền `hoaDonDaXoa` → khoản có `billId` vẫn `bill`;
  - giao dịch thường / mục tiêu → `canhBaoXoaTaiSo` `null`; mục tiêu xét trước hoá đơn.
- `test/features/transaction/data/hoa_don_da_xoa_nguon_test.dart` (mới): đã xoá → `true`; còn → `false`; không có hàng →
  `false`; hàm đọc ném → `false`.
- `transaction_list_row_test.dart`: kiểu cũ → hộp xác nhận mang câu cảnh báo (Huỷ → không xoá, Xoá → `onDelete`); mồ côi
  với cổng `true` → hộp xác nhận; với cổng `false` → toast khoá; giao dịch thường → **không** hộp thoại (vuốt là xoá).
- `transaction_detail_sheet_test.dart`: `hoaDonDaXoa: true` / kiểu cũ → hiện Sửa · Xoá; `billId` còn → ổ khoá (ca hoá
  đơn đầu tiên của tệp — hiện chỉ có ca mục tiêu).
- Một ca nối dây cho `TransactionPage._showDetail` và một cho `BudgetDetailPage`: cổng giả trả `true` → bảng hiện nút Xoá
  với hàng mồ côi; hộp xác nhận mang câu cảnh báo.
- `bill_bloc` (hoặc ca hiện có của *Hoàn tác* kiểu cũ): câu mới.
- `test/core/sync/…`: kéo về giao dịch **có** `idbill` → `billId` ghi; **thiếu** khoá → `billId` cục bộ giữ nguyên
  (`Value.absent()`), cùng khuôn ca `idgoal` hiện có.
- Không thêm test quét mới.

## 7. Kiến trúc — đối chiếu luật (soát trước khi trình)

- Quét 29: không cạnh mảng mới ở `domain/`; cổng ở `transaction/data`, DI ở điểm ghép. Chiều `bill → transaction` giữ.
- Quét 22: trang đọc qua cổng / `sl`, không cầm `AppDatabase` / DAO. Quét 27: interface và trang chỉ thấy Entity.
- Quét 25 (luật vị trí): tệp cổng ở `features/transaction/data/` (cùng chỗ với các cổng `*_nguon.dart` khác); test soi
  gương `test/features/transaction/data/`.
- Quét 12: không thêm `IconButton`. Quét 19: hộp xác nhận dùng `ConfirmDialog` sẵn có, phản hồi qua `baoNhanh`.

## 8. Nghiệm thu

- **Máy ảo** `FlowMoney_16G`, tài khoản 10 — có sẵn **3** khoản kiểu cũ: vuốt một khoản → hộp xác nhận mang câu "bản
  cũ" → Huỷ (không xoá). Mở bảng chi tiết → có Sửa / Xoá.
- **Khoản mồ côi**: tạo hoá đơn thử, trả, xoá kỳ đã trả qua màn xác nhận → ở sổ, khoản chi ấy vuốt được với câu "Hoá đơn
  của khoản này đã xoá"; xoá → số dư ví tăng lại đúng số tiền. Khoản trả của hoá đơn **còn** vẫn khoá.
- `flutter test` toàn bộ (mốc 7.178 + ca mới), `flutter analyze` 20.

## 9. Tài liệu cập nhật khi thi công

`BILL_DOCUMENTATION.md` (mục 6.3 câu Hoàn tác kiểu cũ; mục 6.10 bẫy khoản chi bị khoá → đã gỡ), `CLAUDE.md` (hàng
hoá đơn: câu ⚠️ về bẫy 6.10), `PROJECT_CONTEXT.md` mục 14, `CATEGORY_RATIONALE` / tài liệu sổ nếu có nhắc
`transactionOwnerOf` theo tiền tố (grep `transactionOwnerOf`, `kGhiChuTraHoaDon`, `tiền tố` trên `docs/`).
