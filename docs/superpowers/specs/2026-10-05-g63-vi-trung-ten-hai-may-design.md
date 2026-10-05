# G63 — Ví trùng tên giữa hai máy cùng tài khoản — thiết kế

**Ngày:** 2026-10-05. **Trạng thái:** thiết kế người dùng duyệt trong chat (sáu lượt AskUserQuestion: phạm vi · cờ mặc
định · bốn phần thiết kế); **bản viết chờ người dùng đọc**; chưa có kế hoạch, **chưa có mã**.

Mục **G63** của `docs/CLIENT_APP_KNOWN_GAPS.md` mở ngày 2026-10-03 và hoãn cùng ngày; ngày 2026-10-05 người dùng chọn
làm. Bản này thi hành *phác thảo lối sửa* mà người dùng đã chọn từng điểm ở cuối mục ấy, và chốt những chỗ phác thảo còn
để ngỏ.

> **Hai chỗ thêm lúc viết, chưa nói trong chat — đọc kỹ khi duyệt:**
> 1. **Bước 9 của Gộp** (mục 6.2): gỡ các thông báo số dư còn mở của ví bị bỏ. Không có nó thì sau khi gộp, trung tâm
>    thông báo còn một dòng *"Ví … sắp cạn"* trỏ vào một ví không còn tồn tại.
> 2. **Mục tiêu chỉ dùng ví bị giữ làm ví NGUỒN trích tự động cũng bị giữ** (mục 4.4), dù server không có khoá ngoại ở
>    cột ấy. Lý do: không đẩy lên server một mã ví mà server chưa hề có.

Trong cả bản này: **R** là ví trên máy này bị server từ chối; **P** là ví cùng tên đã nằm trên server (và đã kéo về máy).

---

## 1. Vì sao

Đo trên CSDL Realme và PostgreSQL dev, tài khoản 10, ngày 2026-10-03 (chi tiết ở mục G63):

1. Hai máy cùng tài khoản mỗi máy tự tạo một ví **cùng tên** trước khi kịp đồng bộ. Client chỉ chặn trùng tên với ví
   **trên chính máy ấy** (`WalletLocalDataSourceImpl._kiemRangBuocServer`), nên cả hai đều tạo được.
2. Máy đẩy sau nhận `WALLET_NAME_DUPLICATE` (index `uq_wallet_account_name_active`). `SyncEngine` xếp mã ấy là
   `permanent`, nhưng `permanent` chỉ **chặn theo thời gian**: hết hạn là gửi lại, hỏng lại, mãi mãi.
3. Nhánh kéo về ghi ví **theo id** (`walletDao.upsertAll`), không xét tên. Máy ấy có **hai ví trùng tên** ở màn Quản lý
   ví và ở mọi bộ chọn ví.
4. Giao dịch của R vỡ `fk_transaction_wallet`. Lỗi khoá ngoại là `transient` nên chúng bị **gửi lại ở mọi chu kỳ**; mỗi
   chu kỳ kết thúc bằng lỗi, và giãn cách luỹ tiến làm chậm cả dữ liệu không liên quan.

Ba triệu chứng đi kèm, cùng ghi trong G63:

- **Hai ví mang cờ mặc định** sau khi kéo về (cờ của R cộng cờ của ví mặc định server gửi xuống).
- **Cả R lẫn P không sửa được gì ở trang Sửa ví**, kể cả đổi biểu tượng: chốt trùng tên chạy ở mọi lần lưu, và ví kia đã
  nằm trên máy.
- Không màn nào nói cho người dùng biết có chuyện gì; lối thoát duy nhất là tự đoán ra phải đổi tên hoặc xoá.

## 2. Quyết định đã chốt

| # | Quyết định | Chốt khi nào |
|---|---|---|
| 1 | Cờ cục bộ `wallets.bi_tu_choi_trung_ten`, đặt bởi một bộ nghe `pushResultStream` theo khuôn `BillPaymentConflictResolver` | Phác thảo 2026-10-03 |
| 2 | Hàm thuần `capViTrungTen` là định nghĩa duy nhất của "cặp trùng" | Phác thảo 2026-10-03 |
| 3 | Trong lúc chờ, `_collectPendingOps` bỏ qua R và mọi thứ dính tới nó | Phác thảo 2026-10-03 |
| 4 | Thẻ **Gộp / Đổi tên** ở Quản lý ví, kèm dòng nhắc ở Trang chủ | Phác thảo 2026-10-03 |
| 5 | Gộp dời giao dịch, hoá đơn, mục tiêu, bảng *nguồn → ví* sang P; bỏ R **cùng khoản "Số dư ban đầu"** của nó; hộp xác nhận nêu số giao dịch và số dư sau gộp | Phác thảo 2026-10-03 |
| 6 | Đổi tên điền sẵn "‹tên› (2)" | Phác thảo 2026-10-03 |
| 7 | **Phạm vi: chỉ ví.** Danh mục trùng tên (`CATEGORY_NAME_DUPLICATE`) để lượt sau, dùng lại phần lõi | Chat 2026-10-05, câu 1 |
| 8 | **Cờ mặc định: bản server thắng.** Kéo về xong, ví mặc định server gửi xuống là ví mặc định duy nhất trên máy | Chat 2026-10-05, câu 2 |
| 9 | Trong lúc chờ, **bộ chọn ví không đổi** (hai ví cùng tên vẫn hiện như hôm nay) | Chat 2026-10-05, phần 1 |
| 10 | Dòng nhắc Trang chủ **có nút ✕**: ẩn trong lần mở app này, lần mở sau hiện lại nếu chưa xử lý | Chat 2026-10-05, phần 2 |
| 11 | Giữ hàng đợi **đồng loạt**, không phân biệt R đã từng lên server hay chưa | Chat 2026-10-05, phần 1 |

## 3. Người dùng thấy gì

**Trước:** đồng bộ báo lỗi mãi; hai ví cùng tên; hai nhãn MẶC ĐỊNH; Sửa ví không lưu được; không lời giải thích nào.

**Sau:**

- Lần đồng bộ đầu tiên sau khi tạo ví trùng vẫn báo lỗi **một lần**. Từ chu kỳ sau, đồng bộ sạch và dữ liệu khác không
  bị kéo chậm.
- Màn Quản lý ví có thẻ **"VÍ TRÙNG TÊN"** ở trên cùng với hai nút **Đổi tên** và **Gộp**; dòng của R trong danh sách
  mang nhãn **CHƯA ĐỒNG BỘ**.
- Trang chủ có một dòng nhắc dẫn tới Quản lý ví.
- Chỉ còn một ví mặc định. Sửa ví lưu được như thường.
- R và mọi thứ gắn với nó **nằm yên trên máy** (không mất, không lên server) cho tới khi người dùng bấm Gộp hoặc Đổi tên.

---

## 4. Phát hiện và giữ hàng đợi

### 4.1 Cờ cục bộ (schema v28)

- Cột `Wallets.biTuChoiTrungTen` (`bi_tu_choi_trung_ten`, bool, mặc định `false`). Di trú: `if (from < 28)
  m.addColumn(wallets, wallets.biTuChoiTrungTen)`; không điền dữ liệu cũ.
- **Cục bộ.** Không vào payload đẩy (ví vẫn **13 trường**), nhánh kéo về không đọc. `insertAllOnConflictUpdate` chỉ ghi
  cột companion có mang nên cờ sống qua mọi lượt kéo về.
- `WalletEntity` mang cờ để **đọc** (màn Quản lý ví cần). `_toCompanion` của datasource **không** ghi cờ: người dùng không
  sửa nó qua form, chỉ ba chỗ dưới đây ghi.
- Ba phép ghi ở `WalletDao`:
  - `danhDauTrungTen(id)` đặt cờ.
  - `goCoTrungTen(id)` gỡ cờ **và** xoá `syncBlockedUntil`, `syncError`, `syncRetryCount` (xem bẫy 1, mục 8).
  - `markSynced(id)` gỡ thêm cờ: ví đã lên server thì không còn bị từ chối.

### 4.2 "Ví đang bị giữ" — một định nghĩa

Tệp mới `wallet/domain/vi_trung_ten.dart`, Dart thuần, chạy trên một kiểu tối thiểu (`id`, `ten`, `biTuChoi`, `daXoa`) để
engine (hàng Drift) lẫn giao diện (`WalletEntity`) dùng chung, cùng lối `ViChoGoiSo`.

```
capViTrungTen(vi) → danh sách cặp (R, P)
```

Ví **R đang bị giữ** khi và chỉ khi đủ ba điều:

1. R còn sống (chưa xoá mềm);
2. R mang cờ `biTuChoi`;
3. tồn tại ví sống **khác**, **không mang cờ**, có `chuanHoaTenVi(tên)` bằng của R. Ví ấy là P.

Phép so tên đi qua `chuanHoaTenVi` sẵn có; không viết lại. Nhiều ứng viên P thì ưu tiên ví trùng **nguyên văn** tên, rồi
tới id nhỏ hơn (chỉ để tất định).

**Cờ mà không còn cặp thì vô hiệu.** R khi ấy không bị giữ, quay lại hàng đợi, và đẩy được thì `markSynced` gỡ cờ. Điều
này phủ ba ca: P bị xoá hoặc đổi tên ở máy khác; hàng R bị một lượt kéo về ghi đè tên; server trả `UNIQUE_VIOLATION` vì
lý do không phải tên.

Mọi nơi cần biết "ví nào đang bị giữ" (engine, thẻ, nhãn, dòng nhắc, dịch vụ gộp) đều gọi hàm này.

### 4.3 Bộ nghe

Lớp mới `ViTrungTenResolver` (`wallet/data/services/`), khuôn `BillPaymentConflictResolver`:

- Nghe `SyncEngine.pushResultStream`. Với mỗi thất bại có `entity == wallet` **và** `code` thuộc
  {`WALLET_NAME_DUPLICATE`, `UNIQUE_VIOLATION`}: gọi `danhDauTrungTen(localId)`.
- Bỏ qua mọi thực thể khác và mọi mã khác. Thất bại không mang `code` (backend cũ, lỗi truyền tải) thì không đặt cờ —
  hành vi như trước bản này.
- Luỹ đẳng: engine phát kết quả đẩy hai lượt cho cùng một thất bại (trước Pull, và sau lần thử lại); đặt cờ hai lần
  không đổi gì.
- Đăng ký lazy singleton; nối **một lần** ở `main.dart`, cạnh bộ nghe hoá đơn. Có test quét canh việc nối, cùng lối
  `bill_conflict_resolver_wiring_test.dart`.

Engine **không** đổi cách xếp loại: mã vẫn là `permanent`, mốc chặn theo giờ vẫn được đặt. Cờ chỉ thêm một lớp giữ theo
*cặp tên*; khi cặp không còn thì mốc chặn theo giờ cũ lo phần còn lại.

### 4.4 Tập bản ghi bị giữ

Hàm thuần `banGhiBiGiu` (cùng tệp `vi_trung_ten.dart`) nhận tập id ví đang bị giữ cùng các hàng đang chờ đẩy, trả về id
phải bỏ khỏi lô:

| Thực thể | Bị giữ khi |
|---|---|
| Ví | chính nó đang bị giữ |
| Hoá đơn | `walletId` là ví bị giữ; **hoặc** `generatedFromBillId` là một hoá đơn bị giữ (lặp tới khi không thêm được) |
| Mục tiêu | `walletId` **hoặc** `autoDepositWalletId` là ví bị giữ |
| Giao dịch | `walletId` hoặc `walletTransfer` là ví bị giữ; **hoặc** `billId` là hoá đơn bị giữ; **hoặc** `goalId` là mục tiêu bị giữ |

Các vế gián tiếp theo đúng khoá ngoại phía server: `fk_bill_previous_bill`, `fk_transaction_bill`, `fk_transaction_goal`.
Bị giữ thì bỏ qua **mọi** loại thao tác, kể cả lệnh xoá.

`_collectPendingOps` tính tập này một lần ở đầu hàm rồi `continue` ở từng vòng. ⚠️ `sync_engine.dart` **không nhắc tên
cột cờ**: nó hỏi "ví nào đang bị giữ" qua lớp `ViTrungTenNguon` (`wallet/data/vi_trung_ten_nguon.dart`: đọc DAO →
`capViTrungTen`). Cùng lớp ấy nuôi thẻ ở mục 5.1, nên engine và giao diện không thể đếm trên hai tập khác nhau. Nhờ vậy
test canh cờ cục bộ giữ được dạng đơn giản của `wallet_cho_phep_am_test.dart`.

**Giữ đồng loạt** (quyết định 11): ca "đổi tên một ví **đã đồng bộ** thành tên trùng" cũng giữ cả giao dịch của nó, dù
ví ấy có trên server và khoá ngoại không vỡ. Giữ hơi thừa ở một ca rất hiếm, đổi lại không cần cột "đã từng lên server".

**Chu kỳ đầu tiên:** bộ nghe chạy bất đồng bộ, và P chỉ về máy ở bước Pull. Nên lần thử lại ngay trong chu kỳ bị từ chối
có thể còn mang các bản ghi ấy và hỏng thêm một lượt. Chấp nhận: đúng một chu kỳ lỗi, từ chu kỳ kế là sạch.

### 4.5 Chốt trùng tên chỉ chạy khi tên đổi

`WalletLocalDataSourceImpl.update` đọc hàng đang lưu trước khi kiểm:

- `chuanHoaTenVi(tên cũ) == chuanHoaTenVi(tên mới)` → **bỏ qua** `_kiemRangBuocServer`. Lưu lại một ví mà không đổi tên
  không thể sinh thêm cặp trùng nào.
- Tên đổi → kiểm như cũ; ghi xong thì `goCoTrungTen(id)`.

`insert` giữ nguyên: tạo mới luôn kiểm. Đây là cùng luật với danh mục (quy tắc 7 `CLAUDE.md`).

### 4.6 Kéo về xong chỉ còn một ví mặc định

Trong `_pullFromBackend`, ngay sau `walletDao.upsertAll(companions)`: nếu lô kéo về có một ví `is_default` và chưa xoá
(server bảo đảm nhiều nhất một, `uq_wallet_default_active`) thì gọi `walletDao.clearDefaultExcept(idaccount, keepId)`.

- Lô kéo về **không** có ví mặc định thì không làm gì. Pull là tăng dần; "không thấy" không có nghĩa "server không có".
- `clearDefaultExcept` đánh `pending` các hàng nó chạm (hành vi sẵn có) để cờ đã bỏ lên được server.
- Luật này cũng chữa vòng lặp `WALLET_DEFAULT_DUPLICATE` khi hai máy cùng đổi ví mặc định: máy đẩy sau mất cờ ở lượt kéo
  về, rồi đẩy lại ví của mình ở dạng không mặc định.

---

## 5. Giao diện

### 5.1 Thẻ "VÍ TRÙNG TÊN" ở Quản lý ví

Đứng **trên cùng**, trên thẻ Tổng tài sản. Khuôn viền mảnh của thẻ *"Có vẻ là khoản lặp"* (`the_khoan_lap.dart`). Không
có cặp nào thì không dựng gì, kể cả khoảng cách.

```
┌─────────────────────────────────────────┐
│ ⚠ VÍ TRÙNG TÊN                    1 ví  │
│ Tên này đã có trên tài khoản (tạo từ    │
│ thiết bị khác) nên ví trên máy này      │
│ chưa đồng bộ được.                      │
│                                         │
│ Ví MB Bank                              │
│ Máy này: 1.250.000 đ · 7 giao dịch      │
│ Đã đồng bộ: 3.400.000 đ                 │
│                    [Đổi tên]   [Gộp]    │
└─────────────────────────────────────────┘
```

- Mỗi cặp một dòng; nhiều cặp thì ngăn bằng đường kẻ như thẻ mẫu.
- "N giao dịch" đếm giao dịch sống dính tới R theo mọi vai, **không tính** khoản "Số dư ban đầu". Con số này bằng *số
  giao dịch sẽ chuyển* cộng *số khoản chuyển giữa hai ví* của hộp Gộp (mục 5.3).
- Thẻ tự nạp qua `ViTrungTenNguon` (như `TheKhoanLap` tự nạp qua nguồn của nó), không đi qua `WalletCubit`; xong Gộp /
  Đổi tên thì nạp lại thẻ và gọi `loadWallets`.
- P là ví `banking` → không có nút Gộp, thay bằng dòng *"Ví kia là ví liên kết ngân hàng nên không gộp được."*

### 5.2 Nhãn trên dòng ví

`_WalletItem` thêm nhãn **CHƯA ĐỒNG BỘ** cạnh tên của ví đang bị giữ, cùng kiểu nhãn MẶC ĐỊNH / LƯU TRỮ. Trang tính "bị
giữ" từ danh sách ví nó đã nạp, qua `capViTrungTen`.

### 5.3 Hộp xác nhận Gộp

In ra **chính bản kế hoạch** của mục 6.1:

- Số giao dịch, hoá đơn, mục tiêu sẽ chuyển sang ví đã đồng bộ.
- Số khoản chuyển giữa hai ví sẽ bị bỏ (chỉ khi có).
- Khoản "Số dư ban đầu" của ví trên máy này, kèm số tiền, sẽ bị bỏ.
- Tên mục tiêu sẽ bị tắt trích tự động (chỉ khi có).
- **Số dư sau gộp.**
- Loại của ví giữ lại, và "đang lưu trữ" nếu có.
- Câu *"Không hoàn tác được."*

Nút: **Huỷ** / **Gộp**.

### 5.4 Hộp Đổi tên

Một ô nhập, điền sẵn tên gợi ý của hàm thuần `tenGoiYKhiTrung`: "‹tên› (2)", rồi (3), (4)… tới số đầu tiên chưa có ví
sống nào dùng; tên gốc bị cắt bớt nếu cả chuỗi vượt 100 ký tự.

- Ô có bộ lọc `GioiHanDoRong` với độ rộng cột tên ví, như mọi ô tên khác.
- Kiểm ngay trong hộp bằng `viTrungTen`: rỗng hoặc trùng thì nút Lưu tắt và hiện câu lỗi.
- Nút: **Huỷ** / **Lưu**.

### 5.5 Dòng nhắc ở Trang chủ

Một dòng mảnh ngay dưới thanh tiêu đề, cùng chỗ `TheChoXoaTrangChu`: *"N ví trùng tên đang chờ bạn xử lý ›"*.

- Chạm → mở `/wallets` bằng `push` (Trang chủ nằm trong shell, Quản lý ví ở ngoài).
- **✕** ẩn dòng trong lần mở app này, qua một `ValueNotifier` đăng ký ở DI theo khuôn `AnTheChoXoa`; đặt lại khi đăng
  nhập, cùng chỗ `AnTheChoXoa` được đặt lại trong `AuthBloc`.
- Tự mất khi không còn cặp nào. Khoảng cách phía trên nằm **trong** widget, để ẩn dòng thì không còn khoảng trống.

### 5.6 Phản hồi và thông báo

- Xong việc: một câu ngắn không số, *"Đã gộp ví."* / *"Đã đổi tên ví."*
- **Không thêm loại thông báo nào** vào chuông hay khay hệ thống. Khác ca hoá đơn bị gỡ, ở đây không có gì đổi sau lưng
  người dùng.

### 5.7 Stitch

Cả ba phần đều chưa có thiết kế. **Bước đầu của kế hoạch** là đưa lên dự án Stitch `FlowMoney` ba màn mới bằng
`generate_screen_from_text` (hệ *Kinetic Finance*): (a) Quản lý ví có thẻ và nhãn; (b) hộp Gộp kèm hộp Đổi tên; (c) Trang
chủ có dòng nhắc. Người dùng xem trên Stitch rồi mới dựng Flutter. Chữ trên giao diện ở mục 5 là bản nháp; bản trên
Stitch đã duyệt thắng.

---

## 6. Gộp

### 6.1 Một kế hoạch, hai nơi dùng

Hàm thuần `keHoachGop` (`wallet/domain/gop_vi.dart`) nhận R, P cùng giao dịch, hoá đơn, mục tiêu liên quan và trả một
`KeHoachGop`: các id sẽ đổi ví, các id sẽ xoá mềm, mục tiêu sẽ tắt trích, số dư ban đầu bị bỏ, **số dư sau gộp**, và
`coTheGop` kèm lý do khi không.

`GopViService` (`wallet/data/services/`) có đúng hai việc: `lapKeHoach(idR)` đọc CSDL rồi gọi hàm thuần; `gop(keHoach)`
thi hành. Hộp xác nhận in `KeHoachGop`; bước thi hành làm theo `KeHoachGop`. Không chỗ nào tự đếm lại.

### 6.2 Các bước

Chạy trong **một giao tác CSDL**; lỗi giữa chừng thì hoàn nguyên tất cả.

0. Đặt neo cho P nếu thiếu (`SoDuViService.datNeoNhieuVi({P})`) — **trước** khi đụng sổ.
1. **Giao dịch** sống có `walletId == R` hoặc `walletTransfer == R` → đổi sang P; đánh `pending`, `updatedAt` mới.
2. **Khoản "Số dư ban đầu" của R** (id tất định `idKhoanMoSo(R)`) → xoá mềm, không chuyển.
3. **Khoản chuyển giữa R và P** → xoá mềm (sau gộp nó là chuyển từ ví sang chính nó).
4. **Hoá đơn** sống có `walletId == R` → P. **Mục tiêu** sống có `walletId == R` hoặc `autoDepositWalletId == R` → P. Mục
   tiêu nào sau đó có ví nguồn trùng ví nhận → tắt trích tự động (ba cột `auto_deposit_*` về `NULL` cùng nhau).
5. **Bảng nguồn → ví** (`ViTheoNguonStore`): mọi dòng trỏ R → P. Cần thêm phép `doiVi(idaccount, tu, sang)` ở cả hai bản
   cài đặt. Bảng nằm ở secure storage, ngoài giao tác; ghi **sau** khi giao tác thành công, lỗi ghi bị nuốt như mọi phép
   ghi khác của kho ấy.
6. **R bị xoá mềm**, gỡ cờ và mốc chặn (`goCoTrungTen`). Lệnh xoá **vẫn đẩy lên**: server coi "không có sẵn" là xong
   (`Already absent`), nên an toàn cả khi R chưa từng lên, và đúng khi R có trên server.
7. **Số dư P** tính lại bằng `SoDuViService.tinhLaiSoDu(P)`.
8. **Thuộc tính của P giữ nguyên** (loại, biểu tượng, màu, lưu trữ, tính vào tổng, cho phép âm). Riêng cờ mặc định: R
   đang mang cờ thì P nhận cờ (đánh `pending`). Theo mục 4.6, R chỉ còn mang cờ khi server không có ví mặc định nào khác.
9. **Thông báo số dư còn mở của R** (`walletNegative`, `walletLowBalance` có `subjectId == R`) → đánh dấu đã gỡ.

Xong thì `scheduleSync()`. Gộp chạy được khi mất mạng; phần đẩy đi sau.

Dịch vụ này **cố ý đi vòng** bốn ràng buộc của `WalletLocalDataSourceImpl.softDelete` (còn số dư, có giao dịch, gắn mục
tiêu, gắn hoá đơn): nó tự dời hết phụ thuộc trước khi xoá. Chỉ dịch vụ này được làm vậy; không mở đường chung nào.

### 6.3 Số dư sau gộp

```
số dư sau gộp = số dư P + tổng sổ của R − khoản mở sổ của R
```

- "Tổng sổ của R" là `TransactionDao.tongTheoVi(R)`; "khoản mở sổ" lấy dấu theo `type` (`thu` dương, `chi` âm), bằng 0
  nếu R không có.
- Khoản chuyển giữa R và P tự triệt tiêu trong phép cộng, nên không cần vế riêng.
- Ví dụ: 3.400.000 + 1.250.000 − 1.000.000 = **3.650.000 đ**.
- Hộp xác nhận in "Số dư ban đầu bị bỏ" = *số dư R − (tổng sổ của R − khoản mở sổ)*, để phần số dư R chưa từng vào sổ
  (ví tạo trước 2026-09-13) cũng được nói ra.
- Ca test bắt buộc: sau `gop`, `balance` của P lệch con số trong kế hoạch dưới nửa đồng.

### 6.4 Khi không gộp được

P là ví `banking` (liên kết ngân hàng cũ): `SoDuViService` cố ý không tính lại loại ấy, nên dời sổ sang nó không đổi số
dư. `coTheGop = false`; thẻ chỉ có nút Đổi tên.

P đang lưu trữ **vẫn gộp được**; P giữ trạng thái lưu trữ và hộp xác nhận nói rõ.

## 7. Đổi tên

Hộp 5.4 → `WalletRepository.updateWallet(R.copyWith(name: tên mới))` — đúng đường của trang Sửa ví:

1. Datasource thấy tên đổi → `_kiemRangBuocServer` với tên mới → ghi → `goCoTrungTen` (mục 4.5).
2. R hết bị giữ; R cùng giao dịch, hoá đơn, mục tiêu của nó vào lô đẩy ở chu kỳ kế (ví trước, phụ thuộc sau — thứ tự sẵn
   có của `_collectPendingOps`).
3. Nếu tên mới lại đụng một ví trên server chưa kéo về: bộ nghe đặt cờ lại, thẻ hiện lại.

Cờ mặc định của R không đổi. Nếu R còn mang cờ mà server đã có ví mặc định khác, lần đẩy bị từ chối bằng
`WALLET_DEFAULT_DUPLICATE`; lượt kéo về cùng chu kỳ bỏ cờ của R (mục 4.6) và chu kỳ sau R lên được.

---

## 8. Chỗ dễ hỏng im lặng

Mỗi chỗ có ít nhất một ca test, và ca ấy phải **đỏ trên một bản sai có chủ ý**.

1. **Gỡ cờ phải gỡ luôn mốc chặn theo giờ.** Lần bị từ chối để lại `syncBlockedUntil` (tới 60 phút). Gỡ mỗi cờ thì giao
   dịch của R được thả ra trước R, vỡ khoá ngoại và quay lại đúng vòng lặp cũ cho tới khi mốc hết hạn.
2. **"Bị giữ" là cờ VÀ còn cặp.** Đọc mỗi cờ: ví bị giữ mãi sau khi máy kia đã đổi tên hoặc xoá ví của nó. Đọc mỗi cặp
   tên: giữ cả những ví chưa hề bị từ chối.
3. **Bộ nghe chỉ đọc mã của thực thể ví.** `UNIQUE_VIOLATION` của hoá đơn hay danh mục không được đặt cờ ví.
4. **Kế hoạch gộp là nguồn duy nhất** cho hộp xác nhận lẫn bước thi hành. Đếm lại ở giao diện là hai con số có thể lệch.
5. **Khoản mở sổ của R tìm bằng id tất định**, không bằng ghi chú (ghi chú sửa được).
6. **Mọi phép ghi số dư đi qua `SoDuViService`**, và neo của P đặt **trước** khi dời sổ. Test quét `so_du_mot_noi_ghi_test`
   canh vế đầu.
7. **`sync_engine.dart`, `sync_payload_normalizer.dart` và hợp đồng payload không nhắc tên cột cờ.**
8. **Luật một ví mặc định chỉ chạy khi lô kéo về có ví mặc định.** Chạy vô điều kiện là xoá cờ mặc định của máy ở mọi
   lượt kéo về không mang ví ấy.
9. **Thẻ, nhãn, dòng nhắc, engine cùng gọi `capViTrungTen`.** Viết lại vế so tên ở một chỗ là bốn nơi đếm trên bốn tập.
10. **Hộp Đổi tên là một ô nhập tên**: thiếu `GioiHanDoRong` thì tên dài vỡ độ rộng cột và ví không bao giờ lên server.
11. **Bộ nghe phải được nối**, không chỉ được dựng (test quét).
12. **Giao diện mới phải thử ở 360 dp bằng theme thật.** Nút trong `Row` với theme của app rộng vô hạn (bẫy 4.11 của
    `ANALYTICS_FEATURE.md`).

## 9. Kiểm thử

Viết test trước. Mốc trước khi làm: `flutter test` **5715/5715** (8 skip), `flutter analyze` **26**, schema **v27**.

- **Hàm thuần:** `capViTrungTen` (ba điều kiện, cờ không cặp, nhiều ứng viên, ví đã xoá, ví lưu trữ vẫn tính);
  `banGhiBiGiu` (từng dòng của bảng 4.4, chuỗi kỳ hoá đơn); `keHoachGop` (từng bước, khoản chuyển nội bộ, mục tiêu tắt
  trích, `banking`); `tenGoiYKhiTrung` ((2) đã có, tên dài).
- **Bộ nghe:** hai mã đặt cờ; mã khác, thực thể khác, thất bại không mã thì không; hai lượt phát.
- **Engine:** lô đẩy không chứa R và phần phụ thuộc; cờ không cặp thì R có trong lô; kéo về có ví mặc định → một ví mặc
  định; kéo về không có → cờ cục bộ giữ nguyên; payload ví 13 trường.
- **Datasource / DAO:** lưu không đổi tên qua được khi có ví trùng; đổi sang tên trùng vẫn bị chặn; đổi tên gỡ cờ và mốc
  chặn; `markSynced` gỡ cờ.
- **Dịch vụ Gộp:** từng bước 0–9; số dư khớp kế hoạch; lỗi giữa chừng hoàn nguyên; từ chối khi `coTheGop` sai; R chưa
  từng lên server và R đã có trên server.
- **Giao diện** (theme thật, 360 dp): thẻ có và không có nút Gộp, nhiều cặp, không tràn; nhãn chỉ trên ví bị giữ; hộp Gộp
  in đúng kế hoạch; hộp Đổi tên chặn rỗng / trùng / quá dài; dòng nhắc, ✕, hiện lại sau khi đặt lại.
- **Di trú** v27 → v28, theo khuôn `schema_v27_test.dart`.
- **Test quét:** bộ nghe được nối; cờ không lọt vào đường đồng bộ.

## 10. Nghiệm thu hai máy

Hai máy thật cùng một tài khoản, backend dev chạy trên máy phát triển (`adb reverse tcp:3000 tcp:3000`). Chọn cặp máy và
tài khoản với người dùng lúc nghiệm thu (Realme là máy dùng hằng ngày; OnePlus đang đăng nhập tài khoản khác).

1. Hai máy cùng mất đồng bộ; mỗi máy tạo ví cùng tên với số dư ban đầu khác nhau, ghi vài giao dịch. Trên máy B đặt ví ấy
   làm mặc định.
2. Máy A đồng bộ trước, rồi máy B. Trên B kiểm: báo lỗi **đúng một lần** rồi sạch; thẻ, nhãn, dòng nhắc; ✕ ẩn dòng nhắc
   và mở lại app thì hiện lại; **một** ví mặc định; Sửa ví lưu được cho cả R lẫn P; PostgreSQL chỉ có ví của A.
3. **Gộp** trên B: số dư bằng con số trong hộp xác nhận. PostgreSQL: một ví, giao dịch của B nằm dưới ví ấy, không còn
   hàng nào của R sống. Máy A kéo về thấy đủ, số dư hai máy bằng nhau.
4. Lặp lại bước 1–2 với tên khác, rồi **Đổi tên** trên B: PostgreSQL có hai ví hai tên, giao dịch của B dưới ví đã đổi tên.
5. Dọn dữ liệu thử qua giao diện (xoá mềm), không xoá cứng ở PostgreSQL.

## 11. Tài liệu phải cập nhật khi xong

- `docs/CLIENT_APP_KNOWN_GAPS.md`: đóng G63 ở **cả** thân lẫn bảng tóm tắt, đếm lại số mục bằng máy.
- `docs/PROJECT_CONTEXT.md` mục 14.
- `CLAUDE.md`: hàng *"Đụng vào quản lý ví"*, hàng *"Đụng vào đồng bộ"* (bộ nghe thứ hai của `pushResultStream`), schema
  v28, số ca test đo lại.
- `docs/superpowers/sync/SYNC_DOCUMENTATION.md` nếu nó tả cách gom hàng đợi đẩy.
- Bản này: banner trạng thái và mọi chỗ bản thi công khác bản viết.
- Không cần đơn `CAN-LAM/`: không đổi payload, không xin backend đổi mã.

## 12. Ngoài phạm vi và giới hạn

**Ngoài phạm vi lượt này:**

- Danh mục trùng tên giữa hai máy.
- Hoàn tác sau khi Gộp.
- Ẩn hoặc gắn nhãn ví bị giữ ở các bộ chọn ví.
- Hai tên chỉ khác hoa/thường hay khoảng trắng mà server nhận cả hai. Không kẹt đồng bộ; mục 4.5 đã cho sửa hai ví ấy.
- Mọi thay đổi phía server.

**Giới hạn biết trước, không xử lý:**

- Ca "đổi tên một ví đã đồng bộ thành tên trùng" rồi Gộp, trong lúc máy kia vẫn ghi thêm vào ví cũ: các khoản ghi muộn
  ấy trỏ tới ví đã xoá. Cùng lớp với việc xoá một ví mà máy khác còn đang dùng.
- Chu kỳ đồng bộ đầu tiên sau khi bị từ chối vẫn kết thúc bằng lỗi (mục 4.4).
- Backend không gửi `code` thì không có gì đổi so với hôm nay.
