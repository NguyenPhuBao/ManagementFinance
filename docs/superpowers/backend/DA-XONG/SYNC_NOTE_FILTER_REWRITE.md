# `/sync/push` viết lại ghi chú người dùng — bộ lọc nhạy cảm bắt nhầm, và bản đã lọc đè lên máy

**Ngày:** 2026-09-10 · **Xin từ:** client (`src/Client-app`) · **Cỡ việc:** sửa
hai biểu thức chính quy trong `utils/content-filter.util.js` và thêm bộ test cho
chúng. **Không migration, không đổi hợp đồng đồng bộ.**

> ✅ **2026-09-11 — soát lại sau `7675b35`:** mục 6.1–6.3 xong — bảng 15 ca chạy đúng 15/15
> bằng `filterSensitiveNote` thật, kể cả hậu tố `(tự động)` và `Thay pin: 350000`; 8.2 và 8.3
> xong. Nên phía server của G29 đã hết. **Còn 8.1** (khoá mã hoá rơi về chuỗi viết cứng):
> `CAN-LAM/VERIFY_7675B35_REMAINING.md` §2.6.

---

## 1. Tóm tắt

Đợt `main` ngày 2026-09-10 cho `/sync/push` chạy mọi `note` (giao dịch, ngân
sách, hoá đơn, mục tiêu) qua `filterSensitiveNote()` rồi mới mã hoá. Mục đích
đúng — NĐ 13/2023 và PCI-DSS, `docs/Rule_Project/Data_Security.md` mục 10.4 —
và client **không xin bỏ bộ lọc**.

Vấn đề là bộ lọc **bắt nhầm những ghi chú bình thường**, và vì kiến trúc
offline-first, bản bị viết lại **đi ngược về máy người dùng ở ngay chu kỳ đồng
bộ đó** rồi đè lên bản gốc. Kết quả: nội dung người dùng gõ **mất vĩnh viễn ở cả
hai đầu**, không có lỗi, không có thông báo, hàng vẫn mang cờ `synced`.

Xin **thu hẹp hai biểu thức** (mục 6) cho tới khi chúng chỉ bắt đúng thứ chúng
định bắt. Bộ lọc giữ nguyên chỗ đứng và vai trò.

---

## 2. Tái hiện đầu-cuối — đo trên máy ảo, không suy luận

Backend chạy mã `main` đã gộp (`bef37d3`), CSDL dev, tài khoản kiểm thử id 10,
APK dựng từ `HEAD` của nhánh client. Thêm một khoản chi **qua giao diện** với ghi
chú:

```
KiemThuDongBo STK 1903 4567 8901 23 mat khau wifi
```

(Không dấu vì `adb input text` chỉ gõ được ASCII — bộ lọc có nhánh riêng cho
`mat khau` nên phép thử vẫn đúng.)

**Log backend** — một chu kỳ đẩy rồi kéo, cùng một giây:

```
15:58:09 Sync push received {"idaccount":10,"count":3}
15:58:09 POST /api/sync/push 200
15:58:09 Sync pull requested {"idaccount":10,"since":"2026-09-10T05:03:19"}
15:58:09 GET /api/sync/pull?since=2026-09-10T05%3A03%3A19.000Z 200
```

**PostgreSQL** (đọc, giải mã bằng chính `utils/crypto.util.js`):

```
enc=true | rawLen=256 | decrypted=KiemThuDongBo STK [THÔNG TIN THẺ ĐÃ ĐƯỢC LƯỢC BỎ] Mật khẩu: [ĐÃ LƯỢC BỎ]
```

**SQLite trên máy ảo** (kéo bản sao `app_flutter/flowmoney.db` kèm `-wal`):

```
f9e9c46a-… | KiemThuDongBo STK [THÔNG TIN THẺ ĐÃ ĐƯỢC LƯỢC BỎ] Mật khẩu: [ĐÃ LƯỢC BỎ] | synced
```

Màn "Sổ giao dịch" và màn chi tiết khoản ấy hiện đúng chuỗi đã lọc. Chữ `wifi` —
thứ người dùng thật sự muốn ghi — không còn ở đâu cả.

Khoản thử đã được **xoá mềm qua giao diện** sau khi đo (`Deleted_at` có giá trị,
số dư ví trở về như cũ). Hàng ấy vẫn nằm trên server ở dạng đã xoá.

---

## 3. Vì sao bản đã lọc về tới máy — và vì sao client không chặn nó

Ba mắt xích, đọc từ mã:

1. `mapEntityFields` gán `update_at` của server **bằng `updatedAt` của client**
   (`sync.repository.js`, các nhánh trong `switch`). Hàng vừa đẩy vì thế mang
   mốc mới hơn mốc `since` mà client giữ.
2. `getTransactionsByAccount` lọc `update_at > since` rồi `restoreSafeNote()` —
   trả về chuỗi **đã lọc**, đã giải mã (`sync.repository.js:318-328`; ba thực
   thể còn lại cùng khuôn ở `:392`, `:454`, `:526`).
3. Client ghi đè bằng `insertAllOnConflictUpdate`, gán thẳng
   `note: Value(t['note'])` (`sync_engine.dart:545`, và `:767`, `:826`, `:895`).

**Client cố ý không vá mắt xích 3.** `docs/progress/Client-app.md` mục **13.9**
ghi rõ ý đồ của backend: *"`note`: Backend đã giải mã sẵn → Client lưu thẳng vào
SQLite"*. Tức làm sạch cả bản sao trên máy là **chủ ý** — với một số thẻ thật,
đó chính là điều nên xảy ra. Giữ bản gốc trên máy sẽ vô hiệu bộ lọc đúng ở chỗ
nó có ích. Nên chỗ sửa là **độ chính xác của bộ lọc**, không phải đường kéo về.

---

## 4. Bộ lọc bắt nhầm gì

Chạy thẳng `filterSensitiveNote()` (hàm thuần, không đụng CSDL) ngày 2026-09-10:

| Ghi chú người dùng gõ | Server lưu | Đúng hay nhầm |
|---|---|---|
| `Mua sổ ghi mật khẩu wifi` | `Mua sổ ghi Mật khẩu: [ĐÃ LƯỢC BỎ]` | ❌ nhầm |
| `Trả tiền password manager 1Password` | `Trả tiền Mật khẩu: [ĐÃ LƯỢC BỎ] 1Password` | ❌ nhầm |
| `CK cho Nam STK 1903 4567 8901 23` | `CK cho Nam STK [THÔNG TIN THẺ ĐÃ ĐƯỢC LƯỢC BỎ]` | ❌ nhầm — số tài khoản, không phải số thẻ |
| `Chuyển tiền 0912345678 2500000` | `Chuyển tiền [THÔNG TIN THẺ ĐÃ ĐƯỢC LƯỢC BỎ]` | ❌ nhầm — **hai** số rời nhau bị cộng thành một |
| `Tích lũy mục tiêu: Két mật khẩu (tự động)` | `Tích lũy mục tiêu: Két Mật khẩu: [ĐÃ LƯỢC BỎ] động)` | ❌ nhầm — **chuỗi do app sinh** bị cắt |
| `Điều chỉnh số dư: lệch sổ tháng 9` | giữ nguyên | ✅ |
| `Chuyển 2500000 cho mẹ ngày 10 09 2026` | giữ nguyên | ✅ |
| `Tiền điện 2026-09 mã KH 1234 5678 90` | giữ nguyên | ✅ (10 chữ số, dưới ngưỡng) |

Hai nguyên nhân, mỗi biểu thức một cái:

**Số thẻ** — `/\b(?:\d[ -]*?){13,19}\b/g` (`content-filter.util.js:128`). Mỗi chữ
số được phép theo sau bởi **bao nhiêu dấu cách hoặc gạch cũng được**, nên hai số
**không liên quan** đứng cạnh nhau bị đếm gộp: `0912345678` (10) + `2500000` (7)
= 17 chữ số → "số thẻ". Và không có phép kiểm **Luhn**, nên mọi dãy 13–19 chữ số —
số tài khoản ngân hàng dài, mã hợp đồng, mã vận đơn — đều bị coi là thẻ.

**Mật khẩu** — `/(?:mật khẩu|mat khau|password|pwd)[\s:]*([^\s,;]+)/gi`
(`:141`). `[\s:]*` cho phép **không có dấu `:` nào**, nên cụm từ khoá đứng trong
câu thường vẫn khớp và **từ ngay sau nó bị nuốt**, bất kể đó có phải mật khẩu hay
không: `wifi`, `manager`, và `(tự` — nửa đầu của hậu tố do app sinh.

Nhánh **CVV** (`:138`) không có vấn đề tương tự: nó đòi 3–4 chữ số theo sau từ
khoá, nên *"cvv"* đứng một mình trong câu không khớp.

---

## 5. Hệ quả

- **Mất dữ liệu không đảo ngược, ở cả hai đầu.** Server chỉ còn bản đã lọc (đã
  mã hoá); máy người dùng bị đè ở chu kỳ đồng bộ đó. Bản gốc không còn ở đâu.
- **Im lặng.** Người dùng lưu xong, thấy đúng chữ mình gõ; vài giây sau chữ ấy
  đổi. Không lỗi, không thông báo, không có gì trong hàng đợi.
- **Phá quy ước ghi chú của app.** Client mã hoá ý nghĩa vào `Note`
  ([`../TRANSACTION_NOTE_ENCODING.md`](../TRANSACTION_NOTE_ENCODING.md), yêu cầu
  số 1 ở đó là *"đừng cắt, chuẩn hoá, hay viết lại `Note`"*). Hậu tố
  ` (tự động)` bị cắt thì khoản trích tự động đọc thành **khoản nạp tay**. Tiền
  tố (`Tích lũy mục tiêu:`, `Rút từ mục tiêu:`, `Điều chỉnh số dư`) chỉ vỡ khi
  bộ lọc số thẻ nuốt qua nó — hiếm, nhưng không phải không thể.
- **Nhân với mọi máy.** Máy thứ hai của cùng tài khoản kéo về bản đã lọc ngay lần
  đầu, không bao giờ thấy bản gốc.

**Dữ liệu hiện có chưa hỏng gì.** Đo 2026-09-10: chạy bộ lọc trên mọi ghi chú
không rỗng đang có — `transaction` 23, `budget` 1, `bill` 2, `goal` 0 — chỉ đúng
**một** hàng sẽ bị viết lại, và đó là khoản thử ở mục 2. Không có ghi chú cũ nào
bị mã hoá (0 hàng `enc:` trước phép thử), vì bộ lọc chỉ chạy lúc **ghi**. Nên
đây là lỗi **đang chờ nổ** ở lần ghi kế tiếp, chưa phải lỗi đã gây thiệt hại.

---

## 6. Việc cần làm

### 6.1. Số thẻ — chỉ bắt hình dạng của số thẻ, và phải qua Luhn

Hai điều kiện, **cả hai**:

1. **Hình dạng:** 13–19 chữ số **liền nhau**, *hoặc* các nhóm được ngăn bởi
   **đúng một** dấu cách/gạch theo cách thẻ thật được in (`4-4-4-4`,
   `4-4-4-4-3`, `4-6-5`). Không cho phép gộp hai số cách nhau bằng chữ hoặc nhiều
   dấu cách.
2. **Luhn hợp lệ.** Mọi số thẻ Visa/MasterCard/JCB/Amex/NAPAS đều qua Luhn; số tài
   khoản ngân hàng, số điện thoại ghép số tiền, mã hoá đơn thì phần lớn không.

Phác thảo (tham khảo, không bắt buộc đúng từng dòng):

```js
const CARD_SHAPE = /\b(?:\d{13,19}|\d{4}(?:[ -]\d{4}){3}(?:[ -]\d{3})?|\d{4}[ -]\d{6}[ -]\d{5})\b/g;

function luhnOk(digits) {
  let sum = 0;
  for (let i = 0; i < digits.length; i++) {
    let d = Number(digits[digits.length - 1 - i]);
    if (i % 2 === 1) { d *= 2; if (d > 9) d -= 9; }
    sum += d;
  }
  return sum % 10 === 0;
}

cleaned = cleaned.replace(CARD_SHAPE, (m) => {
  const digits = m.replace(/[ -]/g, '');
  return luhnOk(digits) ? '[THÔNG TIN THẺ ĐÃ ĐƯỢC LƯỢC BỎ]' : m;
});
```

⚠️ Luhn vẫn cho qua khoảng **1/10** dãy số ngẫu nhiên. Đó là lý do cần **cả**
điều kiện hình dạng: riêng Luhn không đủ, riêng hình dạng cũng không.

### 6.2. Mật khẩu / PIN — đòi dấu ngăn tường minh

Chỉ coi là mật khẩu khi từ khoá **có `:` hoặc `=` theo sau**:

```js
cleaned = cleaned.replace(
  /(mật khẩu|mat khau|password|passcode|pwd)\s*[:=]\s*[^\s,;]+/giu,
  'Mật khẩu: [ĐÃ LƯỢC BỎ]',
);
```

`mật khẩu: abc123` và `password=hunter2` vẫn bị lọc. `mật khẩu wifi` — câu
thường — thì không. Cờ `u` cần cho phép so chữ có dấu; thêm `\b` trước từ khoá nếu
muốn tránh `pwd` khớp giữa một từ dài hơn.

⚠️ **Đừng thêm `pin` vào danh sách từ khoá**, dù nghe hợp lý. Trong tiếng Việt
"pin" trước hết là **pin điện thoại**: đo 2026-09-10, thêm `pin` vào biểu thức
trên thì `Thay pin: 350000` bị lọc thành `Thay Mật khẩu: [ĐÃ LƯỢC BỎ]`. Mã PIN
thẻ là 4–6 chữ số, không ai cần ghi kèm chữ "pin" để nhận ra nó.

**Đã chạy thử** hai phác thảo 6.1 + 6.2 (cùng nhánh CVV hiện có) trên đủ 15 ca
của bảng 6.3 ngày 2026-09-10: **15/15 đúng**. Không có `pin` là điều kiện của
con số ấy.

### 6.3. Bộ test bắt buộc

Mỗi ca dưới đây là một dòng test cho `filterSensitiveNote()`. Cột **phải giữ
nguyên** quan trọng ngang cột **phải lọc** — thiếu nó thì một bản sửa quá tay (ví
dụ bỏ hẳn nhánh số thẻ) vẫn xanh.

| Phải giữ nguyên | Phải lọc |
|---|---|
| `Mua sổ ghi mật khẩu wifi` | `mật khẩu: abc123` |
| `Trả tiền password manager` | `password=hunter2` |
| `CK cho Nam STK 1903 4567 8901 23` | `Thẻ 4111 1111 1111 1111` (Luhn hợp lệ) |
| `Chuyển tiền 0912345678 2500000` | `4111111111111111` |
| `Tích lũy mục tiêu: Két mật khẩu (tự động)` | `cvv 123` |
| `Rút từ mục tiêu: Du lịch 2026` | |
| `Điều chỉnh số dư: đếm lại ví` | |
| `Tích lũy mục tiêu: MuaXe (tự động)` | |

Ba dòng cuối cột trái là **chuỗi do app sinh** — khuôn đầy đủ ở
`TRANSACTION_NOTE_ENCODING.md` mục 1 và `src/Client-app/lib/features/wallet/domain/dieu_chinh_so_du.dart`.
Chúng phải đi qua bộ lọc **nguyên vẹn từng ký tự**.

### 6.4. Không xin gì thêm

- **Không** bỏ bộ lọc, **không** đổi đường kéo về (mục 3 giải thích vì sao).
- **Không** đổi sang "từ chối bằng mã lỗi thay vì viết lại". Đã cân nhắc và loại:
  với offline-first, bản ghi **đã nằm trong SQLite** lúc bị từ chối, nên nó thành
  một thao tác đẩy hỏng vĩnh viễn, thử lại mỗi chu kỳ, và người dùng không có
  cách nào biết phải sửa gì. Viết lại **đúng chỗ** vẫn là hành vi tốt nhất —
  miễn là đúng chỗ.

---

## 7. Kiểm lại sau khi sửa

**Hàm thuần** — chạy từ `src/Backend`, không đụng CSDL:

```bash
node -e "
const {filterSensitiveNote}=require('./utils/content-filter.util');
for (const s of [
  'Mua sổ ghi mật khẩu wifi',
  'CK cho Nam STK 1903 4567 8901 23',
  'Chuyển tiền 0912345678 2500000',
  'Tích lũy mục tiêu: Két mật khẩu (tự động)',
  'Thẻ 4111 1111 1111 1111',
  'mật khẩu: abc123',
]) console.log((filterSensitiveNote(s)===s?'GIU ':'LOC ')+'| '+s+' => '+filterSensitiveNote(s));
"
```

Bốn dòng đầu phải `GIU`, hai dòng cuối phải `LOC`.

**Đầu-cuối** — lặp lại mục 2: thêm một khoản có ghi chú ở cột trái bảng 6.3, chờ
một chu kỳ, rồi so `Note` đã giải mã trên server với cột `note` trong SQLite. Hai
chuỗi phải **bằng nhau và bằng chuỗi đã gõ**.

---

## 8. Cùng gốc, đáng soát — không chặn client hôm nay

Ba điểm tìm thấy trong lúc lần theo đường đi của `Note`. Không cái nào làm hỏng
app hiện tại, nhưng cả ba đều hỏng **im lặng** nếu gặp đúng điều kiện:

1. **Khoá mã hoá đang là giá trị mặc định viết trong mã.** `.env` trên máy dev có
   16 biến, **không có** `DATA_ENCRYPTION_KEY` lẫn `BLIND_INDEX_SECRET` (chỉ kiểm
   **tên** biến), nên `crypto.util.js:10-11` rơi về chuỗi viết cứng. Kèm theo,
   `decrypt()` khi hỏng **trả nguyên chuỗi `enc:…`** thay vì báo lỗi
   (`:87-90`). Ghép hai điều: nếu về sau có người đặt khoá thật mà không mã hoá lại
   dữ liệu cũ, mọi lượt kéo về gửi `enc:…` xuống client, client ghi đè ghi chú
   thật bằng chuỗi mã hoá (mục 3), và mọi phép đọc theo tiền tố ở client đọc về
   mặc định. Đề xuất: từ chối khởi động khi thiếu khoá ở môi trường không phải dev,
   và có kế hoạch xoay khoá trước khi đặt khoá lần đầu.
2. **`modules/ai/features/dedup/dedup.repository.js` đọc `note` mà không giải
   mã** (`select note` ở `:45`, `:108`, `:186`; so khớp trên chuỗi ấy ở `:117`,
   `:150`, `:197` — dòng `:77` cùng dạng nhưng nằm trong nhánh dữ liệu giả
   `_mockExistingTransactions`, không đọc CSDL). Ghi chú từ
   `/sync/push` nay là `enc:…`, nên phép so tên cửa hàng khi khử trùng hoá đơn so
   với **chuỗi mã hoá** và không bao giờ khớp. Client chưa có tính năng quét hoá
   đơn nên chưa ai chạm tới.
3. **`workers/bank.worker.js:195` ghi `note` dạng rõ**, trong khi
   `modules/bank/bank.repository.js:196` mã hoá cùng cột. Cùng một cột mang hai
   dạng lưu trữ tuỳ đường vào. `decrypt()` cho chuỗi rõ đi qua nên đọc vẫn đúng;
   nhưng nó cũng có nghĩa ghi chú giao dịch ngân hàng **không** qua bộ lọc lẫn
   mã hoá.

---

## 9. Client sẽ làm gì

**Không cần làm gì để đóng mục này** — toàn bộ phần sửa nằm ở backend.

Liên quan về sau: `docs/progress/Client-app.md` mục **13.3** xin client thêm bộ
kiểm cảnh báo *trước khi lưu* (mã mẫu `SensitiveNoteValidator` ở 13.10.2). Mã mẫu
ấy dùng **đúng biểu thức số thẻ đang bắt nhầm** ở mục 4, từ khoá mật khẩu không
đòi dấu ngăn, và **có `pin`**. Đo 2026-09-10 (dịch nguyên văn hai biểu thức sang JS,
chạy trên cột "phải giữ nguyên" của bảng 6.3 cộng hai ca `pin`): nó **chặn nhầm 5
trong 10** ghi chú hợp lệ — `Trả tiền password manager`, hai ca số tài khoản và
số điện thoại, `Thay pin: 350000`, `Mua pin sạc dự phòng`. Dán thẳng vào client
là chặn những ghi chú ấy ngay lúc người dùng bấm lưu. Khi client làm 13.3, nó sẽ theo **quy
tắc đã sửa ở mục 6** chứ không theo mã mẫu, và phải chừa các chuỗi do app sinh.
Hai đầu nên dùng **cùng một** định nghĩa; lệch nhau thì client cho qua thứ server
viết lại, hoặc chặn thứ server giữ nguyên.
