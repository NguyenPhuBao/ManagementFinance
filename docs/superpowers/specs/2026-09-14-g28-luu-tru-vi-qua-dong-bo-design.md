# G28 — mở `wallet.status` (lưu trữ ví) qua đồng bộ hai chiều

**Ngày:** 2026-09-14 · **Nhánh:** `TranQuangDat` · **Trạng thái:** đã duyệt, chờ kế hoạch triển khai

> Mọi con số trong tài liệu này **đo bằng máy ngày 2026-09-14** trên CSDL dev
> và trên mã nguồn tại HEAD `a399592`, không chép lại từ tài liệu cũ.

---

## 1. Vấn đề

Tính năng **lưu trữ ví** (đóng băng, không phải xoá) làm xong ngày 2026-09-10,
nhưng cột `wallets.status` là **cột cục bộ**: nó không đi chiều nào của đồng bộ.
Hệ quả là **lưu trữ ví chỉ có hiệu lực trên chính máy đã bấm** — máy thứ hai của
cùng tài khoản vẫn thấy ví ấy trong mọi bộ chọn, vẫn cộng nó vào tổng tài sản,
và hai bộ chạy tự động (trả hoá đơn, nạp mục tiêu) vẫn dùng nó.

Đây là **G28** trong `docs/CLIENT_APP_KNOWN_GAPS.md`, và là khoảng trống cuối
cùng mà client tự đóng được — không còn việc nào chờ backend.

### 1.1. Vì sao nó từng bị tắt

Lý do ban đầu là **một con số**, đo trên PostgreSQL ngày 2026-09-10: lược đồ tự
mâu thuẫn ở đúng cột này — `chk_wallet_status` cho phép `'Inactive'` trong khi
kiểu cột `Status` là `varchar(7)`, còn chuỗi ấy dài **8 ký tự**. Đẩy lên là hàng
ví vỡ ở tầng CSDL và **kẹt hàng đợi đẩy, thử lại ở mọi chu kỳ, im lặng**. Đã vấp
thật trên máy ảo.

Tối cùng ngày CSDL dev áp `database/7` và cột nới lên `varchar(20)`, nhưng người
dùng chốt **để sau** chứ không phải *không làm*.

---

## 2. Đo lại phía server (2026-09-14)

### 2.1. Cột đã hết chặn

```
Status | character varying | max_length = 20 | default 'Active' | NOT NULL
chk_wallet_status CHECK (Status = ANY (ARRAY['Active','Inactive']))
```

Chuỗi 8 ký tự vừa thoải mái. **Chỗ chặn phía server đã hết.**

⚠️ Chú ý `NOT NULL` + `DEFAULT 'Active'`: server **không bao giờ im lặng** về cột
này. Điều đó khác hẳn `anchor_day`/`period_end` — nơi `NULL` nghĩa là "chưa biết"
và nhánh kéo về phải dùng `Value.absent()`. Xem mục 5.1.

### 2.2. Đường đi đã sẵn ở cả hai chiều

| Chiều | Nơi | Hành vi hiện tại |
|---|---|---|
| Đẩy | `sync.repository.js:267` (`upsertWallet`, nhánh update) | `status: mapped.status ?? existing.status` — client gửi thì server ghi, không gửi thì **giữ nguyên** |
| Đẩy | `sync.repository.js:249` (nhánh create) | `status: mapped.status \|\| 'Active'` |
| Kéo về | `sync.repository.js:281` (`getWalletsByAccount`) | `findMany` **không có `select`** → trả **mọi** cột, gồm `status` |

`mapEntityFields('wallet')` (`sync.repository.js:21-28`) **không đổi tên** khoá
`status`, nên client gửi thẳng `'status'` là đúng tên Prisma.

Không tầng validation nào chạm `wallet.status`: phép kiểm `status` ở
`sync.validation.js:158-163` nằm gọn trong nhánh `op.entity === 'transaction'`
(nó canh `Pending/Confirmed/Rejected/Fail` của giao dịch, không liên quan ví).

**Tức là payload pull vốn đã mang `status` từ trước — client chủ động bỏ qua nó.**

### 2.3. Nghĩa thứ hai của cột, và vì sao nó không va chạm

Server dùng chính cột ấy cho một nghĩa khác: *"ví thuộc tài khoản đã bị xoá"*.
Trên CSDL dev có **2 hàng** `Inactive`, cả hai của tài khoản 12 — tài khoản ấy
`Status = 'Deleted'`, `Delete_at = 2026-09-12`.

Chỉ **hai** chỗ trong backend ghi `Inactive` vào ví:

| Chỗ | Khi nào | Tài khoản sau đó |
|---|---|---|
| `core/scheduler.service.js:76` | xoá hẳn sau 30 ngày chờ | đã xoá, không đăng nhập được |
| `modules/admin/admin.repository.js:163` (`softDeleteUser`) | admin xoá mềm người dùng | 401 `ACCOUNT_DELETED`, bị buộc đăng xuất |

Đã kiểm **hai** đường có thể va chạm, cả hai đều sạch:

- **Admin khoá tài khoản** (`updateAccountStatus`, `admin.repository.js:96`) chỉ
  đổi `account.status` + `reason_inactive`, **không đụng bảng `wallet`**.
- **Người dùng tự yêu cầu xoá** (chờ 30 ngày, G33 — vẫn dùng app bình thường
  trong khoảng ấy) đi qua `modules/auth/auth.service.js`, và tệp ấy **không nhắc
  tới `wallet` lấy một lần**.

Và **không có đường khôi phục tài khoản đã xoá mềm** — `grep` trong
`modules/admin/` chỉ tìm thấy phép khôi phục **danh mục hệ thống**
(`admin.service.js:265-274`), không phải tài khoản.

**Kết luận:** tài khoản nào còn đăng nhập được thì ví của nó không bị server đặt
`Inactive`. Xung đột nghĩa là **lý thuyết**, không xảy ra trong đời thật.

⚠️ **Giả định cần kiểm lại nếu backend thêm chức năng khôi phục tài khoản.** Khi
ấy ví sẽ sống lại mang `Inactive`, và với G28 đã mở thì **mọi ví của người dùng
biến khỏi bộ chọn** ngay lượt pull đầu tiên — im lặng.

---

## 3. Thiết kế

### 3.1. Bốn chỗ chạm, **cùng một commit**

| # | Tệp | Thay đổi |
|---|---|---|
| 1 | `lib/core/sync/sync_engine.dart:1225` | Dòng chú thích *"`status` CỐ Ý KHÔNG có mặt"* → `'status': w.status,` |
| 2 | `lib/core/sync/sync_payload_normalizer.dart:91` | `walletForPush` chuẩn hoá `status` qua `WalletStatus.tuKhoa(...).khoaGuiLen` |
| 3 | `lib/core/sync/sync_engine.dart:573` | Nhánh kéo về đọc `w['status']` |
| 4 | `test/core/sync/sync_payload_contract_test.dart:266` | Hợp đồng ví **12 → 13 trường**; ca *"KHÔNG được mang `status`"* **đảo chiều** |

### 3.2. Phép chuẩn hoá đặt ở normalizer, không ở engine

`walletForPush` là nơi duy nhất đúng, vì hai lý do:

1. `lib/features/wallet/domain/wallet_status.dart` cố ý là **Dart thuần** (không
   import Flutter) và docstring của nó đã dành sẵn chỗ cho ngày này:
   *"khi nối lại G28 thì `sync_payload_normalizer.dart` — tầng hợp đồng giữa
   client và server — sẽ dùng nó"*.
2. Cùng khuôn `type` ngay bên trên nó: engine dựng payload **thô**, normalizer
   là tầng dịch sang từ vựng của server.

**Chốt chặn giá trị lạ.** `WalletStatus.tuKhoa` đưa `null`, chuỗi rỗng và mọi
giá trị lạ về `hoatDong` → gửi lên `'Active'`. Nhờ đó **không chuỗi lạ nào tới
được `chk_wallet_status`** — đúng bài học của `ewallet`/`debt` ở cột `Type`, nơi
giá trị lạ từng làm ví kẹt hàng đợi vĩnh viễn (migration v20).

### 3.3. Nhánh kéo về

```dart
status: w['status'] != null
    ? Value(WalletStatus.tuKhoa(w['status']?.toString()).khoa)
    : const Value.absent(),
```

Cùng khuôn `include_in_total` ngay bên trên. Server hiện `NOT NULL` nên luôn trả
giá trị (mục 2.1), nhưng `Value.absent()` là **lớp phòng thủ** trước một bản
backend không trả khoá ấy: đọc thẳng `null` thành `hoatDong` sẽ lặng lẽ bỏ lưu
trữ mọi ví ngay lượt pull đầu tiên gặp payload thiếu khoá — đúng bài học của
`include_in_total` và `idgoal`.

⚠️ Phép đổi `khoaGuiLen` → `khoa` là **bắt buộc**: SQLite lưu chữ thường
(`'active'`/`'inactive'`, mặc định của cột và hợp đồng ghi ở
`wallet_entity.dart:24`) còn PostgreSQL đòi chữ hoa đầu theo
`chk_wallet_status`. Ghi thẳng chuỗi của server vào SQLite là để cột mang **hai
cách viết lẫn lộn**.

Các đường **đọc** đã được phòng thủ sẵn từ 2026-09-10 và **không** vỡ vì chuyện
đó: `WalletDao.getActive` cố ý lọc ở tầng Dart qua `WalletStatus.laHoatDong`
(thứ đã `.toLowerCase()`) chứ không viết `status.equals('active')` vào câu SQL —
docstring của nó ở `wallet_dao.dart:49-52` nói thẳng lý do là *"hàng kéo về từ
server mang chữ hoa `'Active'` cho tới khi nhánh pull chuẩn hoá"*. Đây chính là
nhánh pull ấy, nên phép chuẩn hoá là việc trả nợ cho một chỗ đã chờ sẵn.

Thứ **thật sự vỡ** nếu bỏ phép đổi là các câu **SQL thô**, và mục 3.4 ngay dưới
có đúng một câu như thế: `WHERE status = 'inactive'` của migration v22 phân biệt
hoa thường. Thứ tự cứu nó lần này (migration chạy lúc mở CSDL, trước mọi lượt
pull), nhưng không nên để hai cách viết cùng tồn tại rồi trông vào thứ tự.

### 3.4. Di trú — schema Drift **v21 → v22**

Không đổi cột nào, chỉ một câu trong `onUpgrade`:

```sql
UPDATE wallets SET sync_status = 'pending'
WHERE status = 'inactive' AND is_deleted = 0
```

**Vì sao bắt buộc.** Ví đã lưu trữ *trước* khi mở G28 đang ở `sync_status =
'synced'`, nên nhánh đẩy không bao giờ gửi lại chúng — trong khi server giữ
`'Active'` cho chúng. Không có bước này thì **lượt pull đầu tiên sau khi cập nhật
app sẽ tự bỏ lưu trữ chúng, im lặng**.

**Vì sao nó đủ.** Push chạy **trước** Pull trong cùng chu kỳ — đo trên mã:
`_sendBatch` ở `sync_engine.dart:408`, `_pullFromBackend` ở dòng 440. Ví lưu trữ
cũ lên tới server trước khi pull đọc về, nên lượt pull ấy trả về đúng
`'Inactive'`.

Đúng khuôn G11 đã dùng (schema v7→v8 đánh dấu lại `categories` để đẩy).

### 3.5. Không đụng giao diện

G28 là đường ống dữ liệu. Màn Quản lý ví, màn Sửa ví, mọi bộ chọn đều **giữ
nguyên** — chúng đã đọc `status` qua `WalletStatus.laHoatDong` từ 2026-09-10.
Không có khối giao diện mới, nên **không cần lên Stitch**.

Máy nhận một ví vừa bị lưu trữ ở máy khác thì **im lặng** — không toast, không
hộp thoại. Cùng lý lẽ với `sync.completed` (G34): máy vừa đẩy cũng nhận lại thay
đổi của chính mình, nên một thông báo sẽ nói sai trên đúng máy vừa bấm.

### 3.6. Không xin backend gì

Cột đã có, độ rộng đã đủ, cả hai chiều đã thông. Không viết tài liệu vào
`CAN-LAM/`.

---

## 4. Chế độ hỏng đã lường

| Rủi ro | Vì sao im lặng | Chốt chặn |
|---|---|---|
| **Mở nửa vời** — chỉ nhánh đẩy | Server giữ `'Active'` cho mọi ví, ví vừa lưu trữ **tự bỏ lưu trữ** sau một chu kỳ pull | Bốn chỗ + migration vào **cùng một commit**; hợp đồng payload canh |
| **Mở nửa vời** — chỉ nhánh kéo về | Thao tác lưu trữ không bao giờ rời máy; trông y hệt như chưa làm gì | nt |
| **Quên migration v22** | Ví lưu trữ cũ sống lại một lần sau khi cập nhật app | Test migration riêng ở `core/database/` |
| **Giá trị lạ lọt lên** | Vỡ `chk_wallet_status` → ví **kẹt hàng đợi đẩy vĩnh viễn** | `tuKhoa` gộp mọi giá trị lạ về `'Active'` |
| **Quên đổi hoa/thường** | Cột SQLite mang hai cách viết; đường đọc chịu được (mục 3.3) nhưng mọi câu SQL thô so chuỗi thì không | Test canh: pull `'Inactive'` → SQLite lưu `'inactive'` |
| **Máy chủ chưa áp `database/7`** | Cột còn `varchar(7)`, chuỗi 8 ký tự vỡ ở tầng CSDL | Không chặn được từ client — ghi cảnh báo vào tài liệu |
| **Backend thêm khôi phục tài khoản** | Ví sống lại mang `Inactive` → mọi ví biến khỏi bộ chọn | Giả định ghi ở mục 2.3, kiểm lại khi backend đổi |

---

## 5. Những chỗ **không** làm theo khuôn cũ, và vì sao

### 5.1. Đây **không** phải trường hợp `Value.absent()` như `anchor_day`

Ba cột hoá đơn (`anchor_day`, `previous_bill_id`, `period_end`) dùng
`Value.absent()` vì server trả `NULL` cho hàng cũ, và `NULL` ở đó nghĩa là *"chưa
biết"*. Đọc thẳng là cắt chuỗi kỳ.

`wallet.status` khác hẳn: `NOT NULL DEFAULT 'Active'`. Server **luôn** trả một
giá trị, và giá trị ấy cho hàng cũ là `'Active'` — một khẳng định sai, không phải
một khoảng trống. `Value.absent()` ở đây chỉ phòng bản backend thiếu khoá
(mục 3.3); thứ giải quyết hàng cũ là **migration**, không phải phép đọc.

### 5.2. Đây **không** phải trường hợp "chờ người dùng lưu lại" như màu danh mục

G24 (màu danh mục) chấp nhận rằng hàng đã `synced` chỉ lên màu khi được lưu lại,
vì hậu quả của việc chờ là **vô hại**: màu cục bộ vẫn đúng, chỉ server chưa biết.

Ở đây hậu quả ngược dấu: chờ không phải là "server chưa biết" mà là **máy này
mất trạng thái người dùng đã đặt**. Nên phải có migration.

---

## 6. Kiểm chứng

### 6.1. Test (TDD — đỏ trước, và đỏ **đúng lý do**)

| Vùng | Canh gì |
|---|---|
| `test/core/sync/sync_payload_contract_test.dart` | Hợp đồng ví **13 trường**; ví lưu trữ gửi lên đúng chuỗi `'Inactive'`; ví hoạt động gửi `'Active'`; giá trị lạ gửi `'Active'` |
| `test/core/sync/` (nhánh kéo về) | Pull `'Inactive'` → SQLite `'inactive'`; pull thiếu khoá → **không** đổi trạng thái hiện có |
| `test/core/database/` | Migration v21→v22 đánh dấu ví `inactive` thành `pending`, **không** đụng ví hoạt động và ví đã xoá |
| `test/core/sync/sync_payload_normalizer_test.dart` | `walletForPush` chuẩn hoá đủ ba ca (hoạt động / lưu trữ / giá trị lạ) |

### 6.2. Nghiệm thu hai máy ảo — **bắt buộc**

Đây đúng loại thay đổi mà `flutter test` không bắt được (thứ tự giữa hai luồng
bất đồng bộ — loại lỗi thứ ba). Kịch bản tối thiểu:

1. Hai máy cùng tài khoản, cùng thấy một ví.
2. Máy A lưu trữ ví → máy B pull → ví **biến khỏi bộ chọn** của máy B, vẫn hiện
   ở màn Quản lý ví với nhãn "Đã lưu trữ".
3. Máy B bỏ lưu trữ → máy A pull → ví quay lại bộ chọn của máy A.
4. **Ca di trú:** lưu trữ một ví bằng APK cũ (trước G28), cài APK mới, mở app →
   ví **vẫn** lưu trữ sau chu kỳ đồng bộ đầu tiên, và server nhận `'Inactive'`.

Đo lại trên PostgreSQL sau mỗi bước — chỉ đọc, không xoá cứng hàng nào (quy tắc 5).

### 6.3. Mức nền phải giữ

`flutter test` **2339/2339** (cộng ca mới) · `flutter analyze` **25 issue, 0 error**.

---

## 7. Việc tài liệu đi kèm

Mở G28 làm **sai** một loạt chú thích và tài liệu đang mô tả trạng thái cũ. Phải
sửa trong cùng lượt, nếu không chúng thành bẫy cho phiên sau:

| Tệp | Chỗ nói sai sau khi mở |
|---|---|
| `lib/features/wallet/domain/wallet_status.dart` | Docstring: *"`khoaGuiLen` hiện KHÔNG được dùng ở đâu ngoài test"*, *"`status` là cột cục bộ"* |
| `lib/core/sync/sync_payload_normalizer.dart:91` | Khối chú thích *"KHÔNG chuẩn hoá `status` ở đây"* |
| `lib/core/sync/sync_engine.dart:573` | Khối chú thích dài ở nhánh kéo về |
| `CLAUDE.md` | Hàng *"Đụng vào loại ví"*, hàng *"Đụng vào quản lý ví"*, quy tắc 4 (payload ví **12 trường** → 13) |
| `docs/CLIENT_APP_KNOWN_GAPS.md` | G28 → đóng |
| `docs/PROJECT_CONTEXT.md` mục 14 | Khối trạng thái đồng bộ, schema v21 → v22 |

**Grep theo từ khoá của quyết định cũ**, không chỉ sửa chỗ vừa đụng: `"cột cục
bộ"`, `"G28"`, `"12 trường"`, `"varchar(7)"`.

---

## 8. Việc **không** thuộc phạm vi

- **Không** đổi ngữ nghĩa của lưu trữ ví (vẫn là đóng băng, không phải xoá).
- **Không** thêm màn hình, thông báo, hay bất kỳ khối giao diện nào.
- **Không** đụng `wallet.currency` (đa tiền tệ là việc riêng, mục 4.3 của kế
  hoạch buổi sau).
- **Không** sửa `src/Backend`, `src/Admin-web`, hay tài liệu do backend tạo.
