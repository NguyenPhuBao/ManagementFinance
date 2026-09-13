# Số dư ví suy từ sổ giao dịch (đóng G37)

**Ngày:** 2026-09-13 · **Trạng thái:** đã duyệt, chưa thi công · **Phạm vi:** chỉ `src/Client-app`;
**không xin backend gì** — không cột mới, không trường đồng bộ mới, **không đổi schema Drift**.

> Đóng **G37** trong `docs/CLIENT_APP_KNOWN_GAPS.md`. G37 lộ ra ở lượt nghiệm thu bước 12 ngày
> 2026-09-13, sau khi bốn lỗi im lặng của luồng tự động trả hoá đơn đã được sửa — nó là phần *còn
> lại* của cùng một gốc, ở nhánh mà tầng hoá đơn không bù được.

---

## 1. Vì sao cần

### 1.1. Triệu chứng đo được

Hai máy ảo cùng một tài khoản, hoá đơn tự động trả. Sau khi cuộc đua kết thúc: máy **thắng** giữ
khoản chi hợp lệ −350.000 mà ví vẫn là **2.000.000** thay vì 1.650.000. Máy thua thì đúng, vì
khoản chi của nó đã được gỡ và tiền đã hoàn.

Không có lỗi, không có log, không có gì báo cho người dùng. Sổ và số dư lệch nhau im lặng.

### 1.2. Gốc rễ

`wallets.balance` là một **giá trị tuyệt đối đồng bộ theo LWW**, và đó là đường **duy nhất** để máy
B biết máy A vừa tiêu tiền. Ba phép đo ngày 2026-09-13 dựng nên kết luận ấy:

| Đo | Kết quả |
|---|---|
| Nhánh pull giao dịch có áp delta vào số dư? | **Không** — 0 dòng nhắc `balance` trong nhánh ấy |
| Backend có tính lại `Balance` từ giao dịch? | **Không** — `sync.repository.js:247,265` chỉ nhận con số client gửi |
| Điều kiện LWW của ví | `sync.repository.js:259`: `new Date(mapped.update_at) > new Date(existing.update_at)` — client thua thì **cả hàng ví** bị bỏ qua |

Chuỗi hỏng, đúng như đã đo:

1. máy trả hoá đơn → `updateBalance` trừ ví cục bộ, hàng thành `pending`;
2. push ví → **xung đột**, `_markSyncedById` đánh dấu đã đồng bộ và client "lấy theo server";
3. pull ghi đè `balance` bằng con số server — **lần trừ biến mất không dấu vết**, và vì hàng vừa
   bị đánh dấu `synced` nên không còn gì để đẩy lại.

Mất update là **tất yếu** với LWW trên một giá trị tích luỹ, không phải lỗi lập trình ở một dòng
nào. Nên sửa phải đổi *cách số dư được quyết định*, không phải vá thêm một điều kiện.

### 1.3. Vì sao "mỗi tài khoản chỉ một phiên" KHÔNG thay được việc này

Đã cân nhắc và loại, ngày 2026-09-13. Ràng buộc ấy khoá *phiên đăng nhập*, không khoá *thời điểm
dữ liệu được ghi* — mà app này là **offline-first**. Kịch bản vẫn hỏng nguyên vẹn với đúng một
phiên:

1. máy A đăng nhập, mất mạng, ghi 5 giao dịch → nằm hàng đợi đẩy;
2. người dùng sang máy B, đăng nhập, máy A bị đá;
3. máy B ghi giao dịch và đẩy lên, số dư server đổi;
4. quay lại máy A, đăng nhập lại → A đẩy 5 giao dịch cũ **kèm `balance` tính từ dữ liệu chưa hề
   biết gì về B**;
5. LWW cho `update_at` của A mới hơn → số dư của B bị đè.

Và nó **tạo một rủi ro nặng hơn cái nó sửa**: đăng nhập máy mới đá máy cũ, trong khi `auth_bloc`
hiện **không** đợi đẩy xong trước khi đăng xuất (đo: 0 dòng), còn máy bị đá thì không có cả cơ hội
đẩy. Dữ liệu offline chưa đẩy hoặc **mất thật**, hoặc quay lại đúng kịch bản trên. Số dư lệch là
lỗi *im lặng*; mất giao dịch offline là lỗi *mất dữ liệu* — đổi cái sau lấy cái trước là lỗ.

Thêm nữa nó cần backend thu hồi token cũ khi đăng nhập mới (hiện cho nhiều phiên: tài khoản 10 có
**18** refresh token còn sống, tk 11 có 14), tức một tài liệu xin backend.

Kết luận: ép một phiên là một **tính năng sản phẩm** (bảo mật, chống dùng chung tài khoản), hợp lệ
nếu làm vì lý do ấy — nhưng nó **không** đóng G37.

---

## 2. Bốn quyết định đã chốt

| Câu hỏi | Chốt | Vì sao |
|---|---|---|
| Điểm neo để tính số dư | **Một giao dịch "Số dư ban đầu"** trong chính sổ | Không thêm cột, không migration schema, không thêm trường đồng bộ — và số dư thành **đúng một** công thức. Cùng khuôn với đối soát số dư đã có |
| Còn đẩy `balance` lên server? | **Vẫn đẩy, chỉ thôi đọc** | Hai máy tính ra cùng kết quả nên LWW giữa hai số bằng nhau là vô hại; server vẫn mang con số đúng để truy vấn PostgreSQL còn dùng để đo được |
| Ví đã có từ trước | **Bộ sinh chạy sau mỗi lần pull**, luỹ đẳng, id tất định | Đúng khuôn `DefaultCategorySeeder`. Chạy sau pull nên tính trên tập giao dịch đầy đủ nhất máy biết; id tất định nên hai máy sinh ra **một** hàng chứ không hai |
| Một phiên mỗi tài khoản | **Không dùng để thay G37** | §1.3 |

---

## 3. Thiết kế

### 3.1. Công thức — định nghĩa duy nhất

```
balance(w) = Σ thu(w) − Σ chi(w) − Σ transfer TỪ w + Σ transfer ĐẾN w
```

Chỉ đếm giao dịch **còn sống** (`deletedAt IS NULL`). Luật lấy nguyên văn từ
`TransactionRepository._applyBalances`, kể cả ngoại lệ của nó: khoản `transfer` **không có ví đích**
thì không tính bên nào — *"đừng trừ một nửa"*.

`wallets.balance` thôi là dữ liệu gốc; nó trở thành **cache của công thức trên**. Vì sổ giao dịch
**đã đồng bộ đúng**, hai máy có cùng tập giao dịch sẽ tính ra cùng một số — xung đột LWW không phá
được nữa, vì không còn gì để mất.

### 3.2. Khoản mở sổ

Ví mới sinh một khoản `thu` (hoặc `chi` nếu số dư ban đầu âm) mang **cặp** dấu hiệu:

- **không danh mục**, và
- ghi chú bắt đầu bằng tiền tố `Số dư ban đầu`.

Đây đúng khuôn `wallet/domain/dieu_chinh_so_du.dart` đã dùng cho khoản đối soát, và vì cùng lý do:
`transaction.Note` **sửa được**, nên một dấu hiệu chỉ nằm trong ghi chú có thể mất; chân thứ hai là
cấu trúc — giao diện thêm giao dịch **bắt buộc chọn danh mục** cho mọi khoản `thu`/`chi`, nên một
khoản thu/chi không danh mục là thứ giao diện không tạo ra được.

Khoản mở sổ **không vào thống kê**: nó là phép *mở sổ*, không phải thu nhập. Luật loại trừ có một
định nghĩa duy nhất ở `analytics/domain/khoan_vao_thong_ke.dart` — thêm vế thứ ba vào đó, cạnh
`transfer` và khoản điều chỉnh.

**`id` suy tất định từ `walletId`:** UUID **v5** với một namespace là hằng số UUID do dự án đặt, khai
báo cạnh chính hàm sinh. Phải là UUID hợp lệ vì cột `transaction.Idtran` là `VarChar(36)`; và phải
tất định vì đó là **chốt chặn duy nhất** giữ cho bộ sinh ở §3.6 không đẻ khoản mở sổ trùng — hai máy
cùng sinh thì ra **cùng một id**, nên `/sync/push` ghép làm một hàng thay vì hai.

Khoản mở sổ **không mang danh mục**, và điều đó hợp lệ ở cả hai đầu: `transaction.idcategory` là
nullable trên PostgreSQL (đọc `schema.prisma` 2026-09-13). Số dư ban đầu bằng 0 thì **không sinh gì**
— `chk_transaction_nonzero_amount` bắt `Amount <> 0`, nên một khoản 0đ là bản ghi vỡ ở tầng CSDL rồi
kẹt hàng đợi đẩy, im lặng.

### 3.3. `tinhLaiSoDu(walletId)` — nơi duy nhất ghi `balance`

Một hàm, đọc thẳng từ SQLite theo công thức §3.1, rồi ghi kết quả vào `wallets.balance`.

⚠️ **Nó tự đặt neo nếu ví chưa có** (`datNeoNeuThieu`, luỹ đẳng), TRƯỚC khi tính. Không có bước ấy
thì công thức thiếu đúng phần neo và trả về một số sai hẳn — ví dựng với số dư 1.000.000 rồi trả
một hoá đơn 350.000 sẽ ra **−350.000** thay vì 650.000. Đây không phải trường hợp hiếm: **mọi** ví
trong bộ test hiện có đều được dựng thẳng qua `walletDao.insert`, không đi qua đường tạo ví, nên
không ví nào có neo. Một hàm tên là "tính lại" mà lại ghi thêm một hàng là điều cần nói rõ — nó
được chấp nhận vì bước ấy luỹ đẳng và là **điều kiện tiên quyết** của phép tính, không phải tác
dụng phụ.

Nó **thay** cả **7** lời gọi `updateBalance` hiện có (đếm bằng script 2026-09-13): `bill` 2,
`goal` 4, `transaction` 1. Sau bản này, `WalletDao.updateBalance` chỉ còn **một** nơi gọi là chính
hàm này — và có test quét `lib/` canh điều đó, cùng khuôn bốn test quét đã có.

⚠️ **50 chỗ đọc `.balance` không sửa dòng nào.** Chúng vẫn đọc cột ấy như cũ. Đây là lý do chọn
"cache của công thức" thay vì "cột tính động": bán kính thay đổi nhỏ hơn hẳn, mà kết quả như nhau.

### 3.4. Hai mốc gọi

1. **Sau mỗi lần ghi giao dịch** — thay chỗ `_applyBalances` đang cộng dồn. Ví bị ảnh hưởng là ví
   của giao dịch, cộng ví đích nếu là khoản chuyển.
2. **Sau mỗi lần pull** — cho những ví có giao dịch vừa kéo về. Đây là mốc **mới**, và là mốc đóng
   G37: giao dịch của máy khác về tới đâu, số dư máy này đúng tới đó.

### 3.5. Đồng bộ

- **Nhánh kéo về:** `balance: Value.absent()` — thôi đọc. Cùng khuôn `anchor_day`, `period_end`,
  `auto_pay`. Đây chính là chỗ đang nuốt mất lần trừ.
- **Nhánh đẩy:** giữ nguyên. Payload ví vẫn **12 trường**, `sync_payload_contract_test.dart` không
  đổi.

### 3.6. Ví đã có — vá neo sau mỗi lần pull

Mượn **tinh thần** `DefaultCategorySeeder` (luỹ đẳng, chạy lại được, không hỏi "đã chạy lần nào
chưa") nhưng **không** mượn chỗ đặt của nó: lớp ấy thực ra chạy trong `.then()` của `engine.start()`
ở hai đường vào phiên (`auth_bloc.dart:304,359`), tức **một lần mỗi phiên**, chứ không phải sau mọi
lần pull như chú thích của nó nói. Neo số dư cần chặt hơn thế, vì ví có thể được kéo về ở bất kỳ
chu kỳ nào — nên nó nằm trong chính `SyncEngine`, cuối `_pullFromBackend`, cùng chỗ với bước tính
lại số dư ở §3.4.

⚠️ **Ví kéo về từ máy khác không cần `balance` của server để đúng.** `Value.absent()` ở nhánh pull
nghĩa là lần INSERT đầu tiên cột lấy mặc định `0`; nhưng neo là **một giao dịch**, nên nó cũng được
pull về cùng lượt — tổng sổ ra đúng số. Đây là lý do chọn "neo là giao dịch" thay vì "neo là một
cột": cột thì phải đồng bộ riêng, giao dịch thì đã đồng bộ sẵn.

Với mỗi ví chưa có khoản mở sổ: sinh một khoản với giá trị

```
soDuBanDau = balance hiện tại − Σ(giao dịch đã biết của ví)
```

Chạy **sau** pull nên tính trên tập giao dịch đầy đủ nhất máy ấy biết. Không sinh gì khi chênh lệch
nhỏ hơn ngưỡng nửa đồng (§4.2).

⚠️ **Tính luỹ đẳng là thứ tuyệt đối không được làm hỏng** — cùng cảnh báo đã ghi cho
`DefaultCategorySeeder`. Nó chạy sau mỗi lần pull chứ không phải một lần trong đời, vì ví có thể
được kéo về ở bất kỳ chu kỳ nào.

---

## 4. Hai chỗ phải chặn trước

### 4.1. Ví `banking` — phép tính lại phải BỎ QUA

Server tự ghi `wallet.balance` cho ví ngân hàng từ SePay (`workers/bank.worker.js:213`), và số dư
ngân hàng thật có thể khác tổng sổ (phí, lãi, giao dịch chưa về). Nếu client tính lại và ghi đè thì
nó xoá đúng con số server vừa ghi.

Hiện **0 ví `Banking` và 0 `bank_account`** trên CSDL (đo 2026-09-13; 45 giao dịch đều `Manual`), nên
chưa hỏng được — nhưng không chặn là để sẵn một hồi quy im lặng cho ngày luồng ngân hàng chạy thật.

→ `tinhLaiSoDu` **bỏ qua** ví loại `banking`, và bộ sinh §3.6 cũng vậy. Có ca test canh.

### 4.2. Ngưỡng nửa đồng

`double` cộng dồn để lại đuôi lẻ. Dùng lại **đúng** ngưỡng `0.5` đồng của `dieu_chinh_so_du.dart`
khi so số dư cũ với số dư vừa tính: chênh dưới ngưỡng thì **không ghi**. Không có nó thì mỗi lần
pull lại ghi một giá trị lệch `0,0000001` và hàng ví quay lại hàng đợi đẩy — một vòng lặp đẩy vô
tận, im lặng.

---

## 5. Kiểm thử

Tầng domain thuần (công thức, nhận dạng khoản mở sổ) test trực tiếp. Tầng repository test trên
SQLite in-memory, cùng khuôn `bill_payment_test.dart`.

| Ca | Canh chừng điều gì |
|---|---|
| Công thức với đủ bốn vế | `thu`, `chi`, `transfer` đi và `transfer` đến cùng một ví |
| `transfer` thiếu ví đích | **Không** tính bên nào — giữ nguyên luật `_applyBalances` |
| Giao dịch đã xoá mềm | Không được tính |
| Khoản mở sổ bị loại khỏi thống kê | `khoanVaoThongKe()` trả `false` cho nó |
| Nhận dạng đòi **cặp** điều kiện | Ghi chú đúng tiền tố nhưng **có** danh mục → vẫn là thu nhập thật |
| Pull mang giao dịch máy khác về | Số dư máy này đổi theo — **ca tái hiện G37** |
| Pull mang `balance` của server về | **Không** ghi đè số dư cục bộ |
| Bộ sinh chạy hai lần | Chỉ một khoản mở sổ (luỹ đẳng) |
| Hai máy cùng sinh khoản mở sổ | Cùng `id` — một hàng, không phải hai |
| Ví `banking` | Không bị tính lại, không bị sinh khoản mở sổ |
| Chênh dưới nửa đồng | Không ghi gì |
| Test quét `lib/` | Chỉ `tinhLaiSoDu` được gọi `updateBalance` |

**Nghiệm thu cuối phải trên hai máy ảo** — bốn lỗi của bước 12 đều lọt qua 2296 ca test và chỉ lộ ra
ở đó. Phép đếm quyết định: sau một cuộc đua, số dư hai máy **bằng nhau** và **bằng tổng sổ**.

---

## 6. Rủi ro và giới hạn

- **Máy chưa pull đủ giao dịch thấy số dư tạm thấp.** Đây là đánh đổi có chủ ý: khác hẳn hôm nay,
  nơi sai là **vĩnh viễn**. Pull xong là đúng.
- **Hai máy chạy bộ sinh khi đang offline** có thể ra hai giá trị khác nhau cho cùng một id; LWW
  chọn bản đẩy sau. Chỉ xảy ra **một lần** trong đời mỗi ví, ở đúng lượt nâng cấp, và sau đó khoản
  mở sổ là bất biến.
- **Chi phí tính lại**: một câu `SUM` trên `transactions` theo `walletId`, chạy sau mỗi lần ghi và
  mỗi lần pull. Với cỡ dữ liệu của app này (45 giao dịch trên CSDL thật) là không đáng kể; nếu về
  sau thành vấn đề thì chỗ sửa là thêm index, không phải đổi thiết kế.
- **Không đụng `wallet.status`** (G28) và không mở lại nó — việc khác, người dùng đã chốt để sau.
