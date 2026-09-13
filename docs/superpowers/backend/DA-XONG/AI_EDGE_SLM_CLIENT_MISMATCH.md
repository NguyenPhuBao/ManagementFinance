# `AI_Edge-SLM.md/Client-app.md` — sáu chỗ lệch mã client đang chạy, cộng bốn chỗ tự mâu thuẫn

**Ngày:** 2026-09-13 · **Xin từ:** client (`src/Client-app`) · **Cỡ việc:** **chỉ sửa chữ trong
tài liệu** — không đổi mã `src/Backend`, không migration, không đụng CSDL. Hai tệp:
[`docs/AI/AI_Edge-SLM.md/Client-app.md`](../../../AI/AI_Edge-SLM.md/Client-app.md) (436 dòng) và
[`Project.md`](../../../../Project.md) mục 11.39.

> **Vì sao client viết tài liệu này thay vì tự sửa:** cả hai tệp do backend tạo
> (`git log --follow --format='%an'` → `NPBao`), nên theo mục 3 README này chúng là vùng chỉ đọc
> với client. Nhưng nội dung của chúng lại **mô tả `src/Client-app`** và tự xưng là *"Nguồn sự thật
> (Source of Truth)"* (dòng 3), nên chỗ sai sẽ dẫn người thực thi đi lệch ngay từ Tầng 1.
>
> **Cách đo:** đọc mã client trên nhánh `TranQuangDat` sau khi gộp `main` @ `eb071bb`
> (merge `04d1352`); `grep` toàn `src/Client-app/lib` cho từng định danh tài liệu nhắc tới; đếm bằng
> script, không đếm bằng mắt. Mỗi khẳng định dưới đây kèm tệp và số dòng để kiểm lại.

---

## 1. Tóm tắt

| # | Chỗ lệch | Dòng | Hậu quả nếu làm theo nguyên văn | Mức |
|---|---|---|---|---|
| **1** | **A3 dùng sai quy ước dấu tiền.** SQLite của client lưu `amount` **luôn dương**; chiều tiền nằm ở cột `type` | 295 (và 38) | Luật A3 **không khớp hàng nào** — không lỗi, không log. Đúng loại hỏng im lặng | 🔴 |
| **2** | **Ba cột A1/A2 cần chưa tồn tại**: `is_outlier`, `is_one_time`, `is_recurring_hint` | 76, 293, 294 | Người thực thi tưởng chỉ phải đọc; thực ra phải thêm cột + nâng schema Drift | 🟡 |
| **3** | **`saving_goal_ratio` là khái niệm chưa có.** Mục tiêu của client là **số tiền đích**, không phải % thu nhập | 186, 335, 337 | D3, D5 và §2.4 không có dữ liệu đầu vào | 🟡 |
| **4** | **`income` không được lưu ở đâu cả** | 109, 186, 333–334 | D1 (`avg_income_3m`), D2 phải dựng mới hoàn toàn | 🟡 |
| **5** | **Mô hình ngân sách không khớp**: `categoryId` **nullable** (có ngân sách tổng), kỳ theo `startDate`/`endDate` chứ không bắt buộc theo tháng | 109, 147, 149, 401 | `budget_limit[i]`, `deficit[i]`, `slack[j]` thiếu định nghĩa cho ngân sách tổng và cho kỳ không phải tháng | 🟡 |
| **6** | **F2 mô tả sai client**: nói AI "đọc và giải mã cục bộ" ghi chú đã mã hoá AES‑256 | 371 | Hứa một lớp bảo vệ client **không có**; người đọc tưởng dữ liệu cục bộ đã được mã hoá | 🟠 |

Cộng bốn chỗ **tự mâu thuẫn trong chính tài liệu** (§9): "7 nhóm (A‑G)" nhưng có 8 nhóm; H4 nói 2 bảng
nhưng khai 3; `Project.md` thiếu **C7** và **D5**; và `Project.md` gán nhầm nhãn C5/C6.

**Không có mục nào trong tài liệu này đòi backend đổi mã.** Toàn bộ là sửa câu chữ.

---

## 2. Chỗ 1 — A3 dùng sai quy ước dấu tiền (🔴 nguy hiểm nhất)

### 2.1. Tài liệu đang nói gì

Dòng **295**, luật A3:

> Khi phát sinh giao dịch hoàn tiền (`amount < 0` trong danh mục Chi tiêu), số tiền hoàn được cộng
> bù trực tiếp vào `current_spend` của **tháng ghi nhận refund**…

Và dòng **38** đặt đầu vào của Tầng 1 là `Raw Transactions (SQLite/local DB)`.

### 2.2. Đo được

Ở **SQLite cục bộ của client, `amount` luôn dương**; chiều tiền nằm ở cột `type`
(`'chi' | 'thu' | 'transfer'`). Cả hai đường ghi đều giữ bất biến ấy:

- **Ghi tay** — `lib/features/transaction/data/repositories/transaction_repository.dart:106-116`:
  ```dart
  final amount = t.amount * sign;
  switch (t.type) {
    case 'chi':
      await _adjust(t.walletId, -amount);   // trừ ví bằng dấu trừ, không bằng amount âm
    case 'thu':
      await _adjust(t.walletId, amount);
  ```
- **Kéo về từ server** — `lib/core/sync/sync_engine.dart:555-561` ghi `.abs()` rồi **suy `type` từ
  dấu** của server, nên số âm của PostgreSQL không bao giờ lọt xuống SQLite:
  ```dart
  amount: Value((num.tryParse(t['amount'].toString()) ?? 0.0).abs().toDouble()),
  type:   Value(SyncPayloadNormalizer.transactionTypeFromBackend(...)),
  ```

Dấu **chỉ** được áp ở bước **đẩy lên**, trong
`lib/core/sync/sync_payload_normalizer.dart:66-72` — `'thu'` → `amount.abs()`, `'chi'` →
`-amount.abs()`. Nói cách khác, quy ước `amount < 0` của tài liệu là quy ước của **PostgreSQL và
payload**, không phải của SQLite.

Kiểm bằng bộ test client: **204** ca test dựng giao dịch với `amount` dương, **1** ca dùng số âm — và
ca đó là `budget_repository_test.dart:342`, test *từ chối* hạn mức ngân sách âm, không phải giao dịch
(đếm bằng script 2026-09-13).

### 2.3. Vì sao chỗ này đáng sửa trước hết

Nếu Tầng 1 lọc `WHERE amount < 0` trên SQLite, nó trả về **0 hàng** trên mọi máy. Không exception,
không log, không test đỏ — luật A3 đơn giản là không bao giờ chạy. Dự án đã có nhiều lỗi cùng dạng
(quy tắc 4 của `CLAUDE.md`), nên đây là chỗ client xin sửa dứt điểm.

**Nguồn gốc có thể là lỗi của chính client:** docstring bảng Drift và chú thích cột `amount` ở
`lib/core/database/tables/transactions_table.dart` (dòng 6 và 20 trước hôm nay) vẫn ghi *"Amount giữ
dấu ±: dương (+) = tiền vào, âm (-) = tiền ra"* — mô tả cột PostgreSQL chứ không phải cột Drift. Ai
đọc bảng ấy để viết luật A3 thì sẽ viết đúng như tài liệu đang viết. **Client đã sửa hai chú thích
ấy ngày 2026-09-13** trong cùng lượt này, nên không cần backend làm gì thêm ở phía mã.

### 2.4. Câu thay

Dòng **295**, thay vế định nghĩa refund:

> Khi phát sinh giao dịch hoàn tiền — ở SQLite cục bộ là một hàng `type = 'thu'` gắn danh mục chi
> tiêu, **không phải** `amount < 0`, vì `amount` ở SQLite luôn dương và chiều tiền nằm ở `type` — số
> tiền hoàn được **trừ** khỏi `current_spend` của **tháng ghi nhận refund**. Tuyệt đối không trừ lùi
> vào tháng gốc trong quá khứ.

Và thêm một dòng ngay dưới sơ đồ luồng ở dòng **38**:

> ⚠️ Quy ước dấu: `transaction.Amount` trên PostgreSQL giữ dấu ± (âm = tiền ra), nhưng **SQLite của
> client thì không** — `amount` luôn dương, chiều tiền đọc ở `type` (`'chi' | 'thu' | 'transfer'`).
> Tầng 1 đọc SQLite nên mọi công thức dưới đây dùng `type`, không dùng dấu.

### 2.5. Kiểm lại

```bash
# phải ra 0 dòng sau khi sửa
grep -n "amount < 0" docs/AI/AI_Edge-SLM.md/Client-app.md
```

---

## 3. Chỗ 2 — ba cột mà A1/A2 cần đều chưa tồn tại

### 3.1. Đo được

`grep` toàn `src/Client-app/lib` (cả dạng snake_case lẫn camelCase), 2026-09-13:

| Định danh tài liệu dùng | Dòng | Số chỗ trong `lib/` |
|---|---|---|
| `is_recurring_hint` / `isRecurringHint` | 76 | **0** |
| `is_outlier` / `isOutlier` | 293 | **0** |
| `is_one_time` / `isOneTime` | 294 | **0** |

Bảng `Transactions` (`lib/core/database/tables/transactions_table.dart`) hiện có: `id`, `walletId`,
`idaccount`, `categoryId`, `amount`, `type`, `status`, `provider`, `note`, `date`, `images`, `goalId`,
`billId`, `walletTransfer`, `bankTranId`, `deletedAt`, cộng sáu cột đồng bộ. Không cột nào trong ba
cột trên.

### 3.2. Câu thay

Thêm một dòng vào §1.2 (ngay dưới khối `Transaction = { … }`, dòng 76):

> ⚠️ `is_recurring_hint`, `is_outlier` (A1) và `is_one_time` (A2) **chưa tồn tại** trong bảng
> `Transactions` của client (đo 2026-09-13). Ba cột này phải được thêm bằng một migration Drift
> (schema hiện tại **v21**) trước khi nhóm A chạy được; `is_outlier` là giá trị **suy ra** nên có thể
> đặt ở bảng cache `local_category_features` thay vì bảng giao dịch, còn `is_one_time` là cờ **do
> người dùng bấm** nên bắt buộc nằm ở hàng giao dịch.

### 3.3. Kiểm lại

```bash
grep -rn "is_outlier\|is_one_time\|is_recurring_hint" src/Client-app/lib --include=*.dart | wc -l   # hôm nay: 0
```

---

## 4. Chỗ 3 — `saving_goal_ratio` là khái niệm client chưa có

### 4.1. Đo được

`grep` `saving_goal_ratio` và `savingGoalRatio` trong `src/Client-app/lib`: **0 chỗ**.

Mục tiêu tiết kiệm của client (bảng `Goals`, `lib/core/database/tables/other_tables.dart:254`) là
**một số tiền đích kèm hạn**, không phải một tỷ lệ trên thu nhập: `startDate`, `targetDate`,
`cycleTakeMoney`, `timeCycleTakeMoney`, `autoDepositAmount`, `autoDepositWalletId`,
`autoDepositLastRun`. Một tài khoản có **nhiều** mục tiêu song song, mỗi mục tiêu một hạn riêng — nên
không có một `saving_goal_ratio` duy nhất để đặt vào công thức `income * (1 - saving_goal_ratio)`
(dòng 186) hay D5 (dòng 337).

### 4.2. Câu thay

Thêm ngay dưới công thức ở dòng **186**:

> ⚠️ `saving_goal_ratio` **chưa tồn tại** ở client (đo 2026-09-13): mục tiêu tiết kiệm là **số tiền
> đích kèm hạn** (`Goals.targetDate`, `autoDepositAmount`), và một tài khoản có nhiều mục tiêu song
> song. Trước khi D3/D5 chạy được, phải chốt một trong hai: (a) thêm một thiết lập "tỷ lệ tiết kiệm
> mục tiêu" ở cấp tài khoản, hoặc (b) suy `saving_goal_ratio` cho tháng hiện tại từ tổng số tiền các
> mục tiêu **còn hạn** cần tích luỹ trong tháng chia cho `income`. Phương án (b) không cần schema mới.

### 4.3. Kiểm lại

```bash
grep -rn "saving_goal_ratio\|savingGoalRatio" src/Client-app/lib --include=*.dart | wc -l   # hôm nay: 0
```

---

## 5. Chỗ 4 — `income` không được lưu ở đâu cả

### 5.1. Đo được

Client **không có** bảng, cột hay thiết lập nào lưu thu nhập. Con số thu nhập duy nhất trong app
được cộng **tại chỗ, cho tháng hiện tại**, rồi vứt đi — `lib/features/home/presentation/pages/home_page.dart:151-156`:

```dart
double monthlyIncome = 0;
…
if (t.type == 'thu') monthlyIncome += t.amount;
```

`grep avgIncome3m` → **0 chỗ**. Nên D1 (*"Trung bình trượt 3 tháng gần nhất"*, dòng 333) và D2
(*"sụt giảm > 30% so với mức trung bình 3 tháng"*, dòng 334) đều chưa có dữ liệu đầu vào; cả hai phải
tự tính từ giao dịch `type = 'thu'` và tự lưu vào cache của Tầng 1.

### 5.2. Câu thay

Thêm một dòng vào ô "Nội dung" của **D1** (dòng 333), cuối ô:

> ⚠️ Client **không lưu** thu nhập ở đâu cả (đo 2026-09-13) — con số ở Trang chủ được cộng tại chỗ
> cho tháng hiện tại rồi bỏ. `avg_income_3m` phải do Tầng 1 tự tính bằng cách cộng các giao dịch
> `type = 'thu'` theo tháng và lưu vào `local_category_features` (hoặc một bảng `local_income_stats`
> riêng), chứ không đọc được từ trường nào có sẵn.

### 5.3. Kiểm lại

```bash
grep -rn "avgIncome3m\|avg_income_3m" src/Client-app/lib --include=*.dart | wc -l   # hôm nay: 0
```

---

## 6. Chỗ 5 — mô hình ngân sách của client không khớp giả định của tài liệu

### 6.1. Đo được

Bảng `Budgets` (`lib/core/database/tables/other_tables.dart:6-101`):

- **`categoryId` là `nullable`** — client có **ngân sách tổng** (không gắn danh mục nào), bên cạnh
  ngân sách theo danh mục.
- Kỳ ngân sách chạy theo **`startDate` / `endDate` tuỳ ý** cộng `recurrence` + `timeRecurrence`
  (`BudgetRecurrence.month` chỉ là **một** giá trị, không phải mặc định bắt buộc), chứ **không**
  luôn là tháng dương lịch. Có cả khái niệm hết hạn — `budget_impact.dart:58` gọi
  `b.isExpired(now)` trước khi tính.

Trong khi đó tài liệu giả định mỗi danh mục có đúng một `budget_limit` theo **tháng**:
`"budget_limit": 4500000` trong JSON tháng (dòng 109), `deficit[i] = projected_spend[i] -
budget_limit[i]` (dòng 147), `slack[j]` (dòng 149), và cột `budget_limit REAL` khoá theo
`category_id` + `month` trong `local_category_features` (dòng 394–401).

### 6.2. Ba câu hỏi tài liệu chưa trả lời

1. Ngân sách **tổng** (`categoryId = NULL`) đóng vai gì — một `budget_limit` cấp tài khoản, hay bị bỏ
   qua? Nếu bỏ qua, người dùng chỉ dùng ngân sách tổng sẽ không bao giờ thấy đề xuất nào.
2. Ngân sách có kỳ **không phải tháng** (ví dụ 10 ngày, hoặc một kỳ tuỳ chọn) quy về `month`
   `'YYYY-MM'` bằng cách nào?
3. Ngân sách **đã hết hạn** (`isExpired`) có vào `slack` không? Client đã vấp đúng chỗ này một lần ở
   trang Phân tích — mục "% ngân sách" **phải lọc `isExpired`** (`docs/ANALYTICS_FEATURE.md`).

### 6.3. Câu thay

Thêm một khối ngay dưới JSON output của Tầng 1 (sau dòng 118):

> ⚠️ **Mô hình ngân sách thật của client rộng hơn giả định trên** (đo 2026-09-13):
> `budgets.categoryId` **nullable** — có ngân sách **tổng** không gắn danh mục; và kỳ ngân sách chạy
> theo `startDate`/`endDate` tuỳ ý cộng `timeRecurrence`, **không** bắt buộc là tháng dương lịch, lại
> có trạng thái hết hạn (`isExpired`). Vì vậy trước khi hiện thực Tầng 1 phải chốt: (a) ngân sách
> tổng là `budget_limit` cấp tài khoản hay bị loại khỏi bài toán; (b) ngân sách kỳ không phải tháng
> quy về `month` bằng cách nào; (c) ngân sách hết hạn **bị loại** khỏi `slack` — theo đúng tiền lệ
> "% ngân sách" ở trang Phân tích.

### 6.4. Kiểm lại

Đọc lại `lib/core/database/tables/other_tables.dart:6-101` — `categoryId` phải còn `nullable()`, và
`budget_impact.dart:58` phải còn gọi `isExpired`.

---

## 7. Chỗ 6 — F2 mô tả một lớp mã hoá mà client không có

### 7.1. Tài liệu đang nói gì

Dòng **371**, luật F2:

> …Toàn bộ ghi chú giao dịch, thông tin nhạy cảm đã được mã hóa AES-256 theo chuẩn `Data_Security.md`.
> Hệ thống AI Điên chỉ đọc và **giải mã cục bộ trên máy** để tính toán đặc trưng.

### 7.2. Đo được

Client **không mã hoá và không giải mã** ghi chú. `note` đi qua đồng bộ ở dạng chữ thô theo cả hai
chiều: đẩy lên ở `lib/core/sync/sync_engine.dart:1222` (`'note': g.note`) và `:1263`; kéo về ở
`:562`, `:795`, `:854`, `:945` (`note: Value(t['note']?.toString() ?? '')`). Không tệp nào trong
`lib/` gọi AES hay một thư viện mã hoá nào cho mục đích này — chỗ duy nhất `grep` bắt được chữ
"encrypt" là `features/wallet/presentation/pages/bank_link_page.dart`, thuộc luồng liên kết ngân hàng,
không liên quan tới `note`.

Thứ client **có** thực sự đặt vào `note` là một **quy ước chuỗi mang ý nghĩa** — ba khuôn
`Tích lũy mục tiêu: <tên>`, `… (tự động)`, `Rút từ mục tiêu: <tên>` — đã được mô tả ở
[`../TRANSACTION_NOTE_ENCODING.md`](../TRANSACTION_NOTE_ENCODING.md) (2026-09-08). Đó là *mã hoá ý
nghĩa*, không phải mã hoá mật mã. Việc `transaction.Note` được mã hoá **at-rest ở PostgreSQL** (nếu
có) là chuyện phía backend và không cho client thêm lớp bảo vệ nào trên máy.

### 7.3. Vì sao đáng sửa

F2 nằm trong nhóm "Bảo mật & Quyền riêng tư", là nơi người đọc tra để biết dữ liệu trên máy được bảo
vệ tới đâu. Câu hiện tại hứa một lớp bảo vệ **không tồn tại**, và còn mô tả một bước "giải mã cục bộ"
mà nếu ai đó đi hiện thực theo thì sẽ tìm khoá không có.

### 7.4. Câu thay

> **F2 — Ranh giới mã hoá.** Ghi chú giao dịch nằm **dạng thô** trong SQLite của client và đi qua
> `/sync/push` / `/sync/pull` cũng ở dạng thô (`sync_engine.dart:1222`, `:562`); client **không** mã
> hoá và **không** giải mã trường này. Việc mã hoá AES-256 theo `Data_Security.md` là lớp **at-rest
> phía server**, không thay đổi gì trên máy người dùng. Vì vậy quyền riêng tư của Tầng 1–2 dựa hoàn
> toàn vào F1 (dữ liệu không rời thiết bị) và F3 (SLM không có mạng), chứ không dựa vào mã hoá. Nếu
> sau này cần mã hoá dữ liệu cục bộ, đó là một hạng mục riêng chưa có trong lộ trình.

### 7.5. Kiểm lại

```bash
grep -rn "AES" src/Client-app/lib --include=*.dart | wc -l   # hôm nay: 0 cho đường note
```

---

## 8. Hai ghi chú triển khai (không phải lỗi, nhưng thiếu thì người thực thi sẽ vấp)

1. **Client không chạy SQL tay.** Phần IV (dòng 390–430) viết ba bảng bằng `CREATE TABLE IF NOT
   EXISTS` với kiểu `VARCHAR(36)`, `BOOLEAN`, `TIMESTAMP`. Client dùng **Drift**: bảng khai bằng
   Dart trong `lib/core/database/tables/`, sinh mã bằng
   `dart run build_runner build --delete-conflicting-outputs`, và mỗi thay đổi phải **tăng
   `schemaVersion`** (hiện **v21**, `lib/core/database/app_database.dart:59`) kèm một bước migration.
   Nên viết ba bảng ấy dưới dạng khai báo Drift, hoặc ghi rõ rằng SQL trên chỉ là đặc tả cột.
2. **Màn hình chat đã có sẵn.** `lib/features/ai_chat/presentation/pages/ai_chat_page.dart` (436
   dòng) đã tồn tại và **chưa nối API nào** (`grep` không thấy lời gọi HTTP/Gemini nào trong thư mục
   ấy). Tầng 3 nên dùng lại màn này thay vì dựng màn mới — tài liệu hiện không nhắc nó.

---

## 9. Bốn chỗ tài liệu tự mâu thuẫn

Đếm bằng script 2026-09-13, trên `04d1352`:

| # | Chỗ | Đo được | Câu thay |
|---|---|---|---|
| **9.1** | Dòng **285** mở đầu Phần III: *"kết hợp chặt chẽ giữa **7 nhóm quy tắc kinh doanh (A-G)**"* | Tài liệu có **8** nhóm — A, B, C, D, E, **H**, F, G (dòng 289, 302, 315, 329, 341, 353, 366, 376), tổng **39** quy tắc | *"…giữa **8 nhóm quy tắc kinh doanh (A–H)**"*. Nhân tiện, nhóm **H** đang nằm **giữa E và F** (dòng 353); chuyển nó xuống sau G cho khớp thứ tự chữ cái, hoặc đổi câu mở đầu thành *"A–G cộng nhóm H về hiệu năng"* |
| **9.2** | Dòng **362**, luật H4: *"Thiết lập **2 bảng** SQLite nội bộ"* | Phần IV khai **3** bảng: `local_category_features` (394), `local_rebalancing_feedback` (412), `local_ai_alert_history` (424) — bảng thứ ba phục vụ chính B3 và B6 | *"Thiết lập **3 bảng** SQLite nội bộ"*, và bổ sung `local_ai_alert_history` vào danh sách liệt kê ngay sau đó |
| **9.3** | [`Project.md`](../../../../Project.md) dòng **2710–2711** | Liệt kê **thiếu C7 và D5**: nhóm C dừng ở C6, nhóm D dừng ở D4. Tài liệu gốc có C1–C**7** và D1–D**5** | Thêm *"C7 (xử lý cạn kiệt nguồn bù `insufficient_slack`)"* và *"D5 (ràng buộc trần ngân sách tuyệt đối)"* |
| **9.4** | [`Project.md`](../../../../Project.md) dòng **2710** | **Gán nhầm nhãn**: ghi *"C4 (vùng đệm donor ≥ 100.000đ, min transfer), C5 (trạng thái `insufficient_slack` trung thực), C6 (xếp hạng donor theo slack × (1 − essentiality))"*. Trong tài liệu gốc: **C4** = vùng đệm, **C5** = ngưỡng điều chuyển có ý nghĩa, **C6** = chỉ số ưu tiên donor, **C7** = insufficient slack. Tức `Project.md` gộp C4+C5 rồi dồn C6→C5, C7→C6 | *"C4 (vùng đệm donor ≥ 100.000đ), C5 (ngưỡng điều chuyển có ý nghĩa), C6 (xếp hạng donor theo slack × (1 − essentiality)), C7 (xử lý cạn kiệt nguồn bù)"* |

Riêng **9.2**, `Project.md` dòng **2713** chép lại con số sai của H4 (*"H4 (2 bảng SQLite cục bộ
`local_category_features`, `local_rebalancing_feedback`)"*) nên phải sửa cùng lượt.

### Kiểm lại cả bốn

```bash
F=docs/AI/AI_Edge-SLM.md/Client-app.md
grep -c "^### .*NHÓM" "$F"                       # phải = 8, và câu dòng 285 phải nói 8
grep -c "^CREATE TABLE IF NOT EXISTS" "$F"       # phải = 3, và H4 phải nói 3
awk '/### 11.39/,/^$/' Project.md | grep -oE "\b[A-H][0-9]\b" | sort -u | tr '\n' ' '
# phải liệt kê đủ: A1..A6 B1..B6 C1..C7 D1..D5 E1..E5 F1..F3 G1..G3 H1..H4
```

---

## 10. Client đã làm gì ở phía mình

- **Sửa hai chú thích sai** ở `lib/core/database/tables/transactions_table.dart` (docstring bảng, và
  chú thích cột `amount`) — chúng nói `amount` giữ dấu ±, trong khi bảng ấy luôn lưu số dương. Đây
  nhiều khả năng là nguồn gốc của chỗ lệch §2, và là tài liệu do client tạo nên client tự sửa.
- **Không** đổi gì khác trong `src/Client-app`: tính năng Edge SLM chưa được lên lịch làm, và tài
  liệu này không xin backend hiện thực nó.

## 11. Liên quan

- [`../TRANSACTION_NOTE_ENCODING.md`](../TRANSACTION_NOTE_ENCODING.md) — quy ước chuỗi trong
  `transaction.Note`, nền cho §7.
- `docs/PROJECT_CONTEXT.md` mục 14 — trạng thái client hôm nay; `docs/CLIENT_APP_KNOWN_GAPS.md` —
  các lỗ hổng còn mở (G28, G36).
- Quy tắc 4 của `CLAUDE.md` (*"Tên trường sai thì im lặng, không báo lỗi"*) — lý do §2 được xếp 🔴 dù
  chỉ là một dòng chữ.
