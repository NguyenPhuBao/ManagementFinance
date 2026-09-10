# Backend — CHỈ ĐỌC THƯ MỤC NÀY

**Cập nhật:** 2026-09-10 (thêm mục 13–16 sau lượt rà soát CSDL mới — `AUTH_401_BODY_CODE.md`, `GOAL_PRIORITY_NULL_TO_ZERO.md`, `SYNC_PUSH_ERROR_MAPPING.md`, `RULE_PROJECT_DOC_DRIFT.md`. Trước đó cùng ngày: mục 10 `SYNC_NOTE_FILTER_REWRITE.md`, mục 11 `DEV_DB_MIGRATIONS_7_11.md` sau khi gộp `main`, và mục 12 `WALLET_SAVING_INDEX.md` sau lượt rà soát ví; mục 9 gộp vào mục 11. Lần trước: 2026-09-09, thêm mục 7 và 8 — hai tệp `SOCKET_*`. Banner đợt 2026-09-07 bên dưới giữ nguyên vì nó nói về đợt ấy)

> ## ✅ Đợt backend 2026-09-07 — client đã kiểm chứng bằng mã, không tin báo cáo
>
> `main` mang về một đợt sửa lớn. Client đọc mã nguồn và truy vấn thẳng
> PostgreSQL để đối chiếu từng tuyên bố, thay vì đọc bảng trạng thái của
> backend. Kết quả: **mục 1, 3, 4, 5, 7 xong; mục 6 bãi bỏ; mục 8, 9 và cả
> `goal.Priority` lẫn `Idaccount` cho `uq_transaction_external` xong**.
> Còn lại trong nhóm 1: **(D)** của mục 2, và **7b** (cột màu).
>
> ⚠️ **Đợt migration ban đầu KHÔNG chạy được.** `)2_can_lam_all_migrations.sql`
> có một câu `DELETE FROM "category"` xoá cứng 5 danh mục mặc định ngoài bộ
> 13 stable UUID. Trên CSDL thật, `fk_bill_category` là **RESTRICT** và có 6
> hoá đơn trỏ tới, nên câu ấy ném 23503 và **toàn bộ tệp roll back** — đó là
> lý do CSDL chưa từng có cột nào của đợt này. Ngoài ra `fk_transaction_category`
> là **SET NULL**: nếu gỡ vướng cho DELETE chạy lọt thì 7 giao dịch mất danh
> mục mà không báo lỗi. Client đã đổi thành xoá mềm (`UPDATE ... SET
> "Delete_at" = NOW()`) trên nhánh `patch2`, chạy thử trong giao dịch rồi
> `ROLLBACK` để kiểm, sau đó áp dụng thật. **Xin nhận bản vá ấy trước khi
> chạy migration ở bất kỳ môi trường nào khác.**
>
> ✅ **Đã bàn giao 2026-09-08:** người dùng đã thông báo cho người phụ trách
> backend. Việc sửa tệp thuộc về phía backend; nhánh `patch2` giữ nguyên tại
> chỗ làm bản tham chiếu.
>
> ⚠️ Bản vá **(B)** tuy đúng thứ client xin nhưng làm hỏng một chỗ phía
> client mà không ai lường: `message` không còn mang mã SQLSTATE nên mọi
> regex phân loại lỗi mất khả năng khớp, và lỗi vĩnh viễn im lặng tụt xuống
> nhánh `transient`. Client đã tự vá (`_permanentCodes`) — **không cần
> backend làm gì**, ghi lại để lần sau đổi hợp đồng lỗi thì báo trước.

> Thư mục cha nay chỉ còn **mục lục và ba tệp bối cảnh** (đếm lại bằng máy 2026-09-10 sau khi nhánh `main` **chuyển `New_Database.md` sang `docs/Rule_Project/`** — con số "bốn" đúng cho tới hôm đó;
> dòng cũ ở đây ghi "20 tài liệu" và đã lạc hậu từ lúc dọn sang `DA-XONG/`).
> Thư mục này giữ **cả tài liệu còn việc lẫn tài liệu vừa đóng** — giữ cả hai để
> đội backend thấy được cái gì đã xong mà không phải dò lại. Sau đợt 2026-09-07
> chỉ còn **mười lăm** mục thật sự phải làm (đếm lại 2026-09-10 lần bốn: thêm mục
> 13–16 sau lượt rà soát CSDL mới; lần ba thêm mục 10, 11 sau khi gộp `main`, rồi
> mục 12 sau lượt rà soát ví; mục 9 gộp vào mục 11 — các con số "chín", "mười",
> "mười một" ghi ở đây trước đó đúng cho tới lúc ấy); danh
> sách ngắn ấy ở **mục 2**, đọc nó
> trước bảng phân nhóm bên dưới. Không cần mở gì ở thư mục cha ngoài ba tệp bối
> cảnh liệt kê ở mục 4 — **ba** tệp, đúng như dòng đầu khối này nói (dòng này từng
> ghi "bốn", tự mâu thuẫn với chính câu nó dẫn; sửa 2026-09-10).

---

## 1. Câu hỏi quan trọng nhất: việc nào chặn tính năng đã có?

Client-app **đã phát hành** một số tính năng mà backend chưa theo kịp. Những
việc ấy khác hẳn về mức khẩn so với những việc phục vụ một tính năng client
**chưa hề bắt đầu**.

Bảng dưới chia đúng theo ranh giới đó.

### 🔴 Nhóm 1 — client ĐÃ CÓ, backend đang chặn hoặc gây hại

Làm nhóm này trước. Mỗi mục ở đây tương ứng với một thứ người dùng **có thể
chạm vào hôm nay**.

| # | Tài liệu | Client đã có gì | Backend thiếu gì | Chi phí |
|---|---|---|---|---|
| **1** | [2026-09-04-backend-idempotent-delete.md](./2026-09-04-backend-idempotent-delete.md) | Toàn bộ đồng bộ offline-first, và ngân sách **"Ngày cụ thể"** | **(A)** ✅ xoá luỹ đẳng — trả `synced` + `'Already absent'`. **(B)** ✅ mã lỗi có cấu trúc — `code` + `constraint` + thông báo tiếng Việt. **(C)** ✅ `time_recurrence === undefined ? 'Month' : ...`, `null` sống sót → ngân sách "Ngày cụ thể" thông. **(D)** ⛔ **CÒN** — nhánh tạo của `upsertBudget` vẫn `threshold_warning_percent ?? 0`, và schema vẫn `@default(0)` | **(D)** vài dòng |
| **2** | [CATEGORY_COLOUR_COLUMN.md](./CATEGORY_COLOUR_COLUMN.md) | Chọn màu cho danh mục — client **vẫn gửi `colour` lên ở mỗi lần đẩy** | ⛔ **CÒN** — bảng `category` vẫn 12 cột, không cột nào cho màu, nên trường ấy bị bỏ qua **im lặng**. ⚠️ Tài liệu này **chưa từng lên origin** tính tới 2026-09-07, nên backend chưa hề thấy nó — đợt migration bỏ sót là vì vậy, không phải vì từ chối. Lưu ý bảng `bill` **đã có** cột `Color`, nên đây là chuyện nhất quán chứ không phải kiểu dữ liệu mới | một cột + hai dòng |

> 📁 **Mọi mục đã đóng của thư mục này nay nằm ở [`../DA-XONG/`](../DA-XONG/README.md)**
> — **16 tài liệu** (đếm lại 2026-09-08; dòng cũ ghi "tám"), kèm ghi chú *đóng
> bằng cách nào*. Giữ lại vì lý lẽ trong đó
> vẫn là thứ giải thích **vì sao** lược đồ hôm nay có hình dạng như vậy; chỉ là
> không còn việc để làm.

### 🟡 Nhóm 2 — client ĐÃ CÓ nhưng không có gì hỏng; đây là *mở khoá*

Không ai mất dữ liệu và không có gì sai số nếu chưa làm. Nhưng tính năng ấy
**không theo người dùng sang máy thứ hai**.

| # | Tài liệu | Client đã có gì | Backend thiếu gì | Chi phí |
|---|---|---|---|---|
| **3** | [2026-09-06-bill-chuoi-ky-va-an-han.md](./2026-09-06-bill-chuoi-ky-va-an-han.md) — **việc A và B** | **Hoàn tác thanh toán hoá đơn** (schema v16) | Hai cột nullable `transaction.Idbill` và `bill.Previous_bill_id` — hai đầu của sợi dây từ hoá đơn về khoản chi và về kỳ kế tiếp. Thiếu chúng, hoàn tác chỉ chạy trên đúng cái máy đã trả; máy khác từ chối có thông báo. Cột B còn mở luôn **lịch sử theo hoá đơn** ("sáu tháng qua tiền điện hết bao nhiêu") | hai cột |
| **4** | [2026-09-06-bill-chuoi-ky-va-an-han.md](./2026-09-06-bill-chuoi-ky-va-an-han.md) — **việc D** | **Tự động thanh toán hoá đơn** (schema v17) | Cột `bill.Auto_pay` để cấu hình theo người dùng sang máy khác, và **chốt chặn trả hai lần** ở `/sync/push` (từ chối `transaction` thứ hai cùng `Idbill` chưa xoá mềm — phụ thuộc việc A). Thiếu chốt, hai máy cùng bật và cùng offline qua ngày đến hạn là hai khoản chi; client chỉ nhắc được "chỉ nên bật trên một thiết bị" | một cột + một phép kiểm |

> ⚠️ Mục 9 có một cái bẫy: **ba cột phải lên cùng một lúc.** Đưa hai cột đầu mà
> bỏ `auto_deposit_last_run` là mỗi máy giữ một mốc riêng và **cả hai cùng
> chuyển tiền** — hỏng nặng hơn hiện trạng. Đọc mục 2 của tài liệu ấy trước.

### ⚪ Nhóm 3 — client CHƯA làm; để sau cũng được

| Tài liệu | Vì sao chưa gấp |
|---|---|
| [2026-09-06-bill-chuoi-ky-va-an-han.md](./2026-09-06-bill-chuoi-ky-va-an-han.md) — **việc C** | Client **chưa làm** ân hạn hoá đơn, và cố ý chưa làm cho tới khi có cột — cùng lối với `goal.Priority`. Bảng `bill` chỉ có `Start_date` và `Due_date`, hai đầu của CÙNG một kỳ, nên hoá đơn điện "kỳ 01–30/09 nhưng hạn trả 15/10" không diễn đạt được. Người dùng hôm nay vẫn dùng được bằng cách đặt hạn trả là mốc kết thúc kỳ |
| [2026-09-06-bill-chuoi-ky-va-an-han.md](./2026-09-06-bill-chuoi-ky-va-an-han.md) — **việc E** | Client **chưa làm** "bỏ qua kỳ này" cho hoá đơn lặp, và cố ý chưa làm cho tới khi backend xác nhận nhận giá trị `Pay_status = 'Skipped'` — hàng bị từ chối ở `/sync/push` là kẹt hàng đợi đẩy vĩnh viễn | **Không thêm cột** (`VarChar(7)` vừa khít); chỉ rà whitelist/validator và chỗ tính nợ. Có thể chỉ là một câu xác nhận |
| [2026-09-04-ocr-classify-review.md](./2026-09-04-ocr-classify-review.md) — **phần OCR/Classify** (mục 2–8 của tài liệu) | Client-app **chưa có tính năng quét hoá đơn**: không có màn hình, không có repository, không có endpoint nào được gọi. `classifyBatch` sai kiểu tham số, `GEMINI_API_KEY` thiếu (`.env` trên máy này **không có biến ấy**), dedup Quy tắc 3 chặn nhầm, cửa hậu `_mock*` — tất cả đều thật, nhưng **không ai chạm tới được từ app**. ✅ Riêng `uq_transaction_external` nay **đã có `Idaccount`** (`UNIQUE ("Idaccount", "Provider", "Bank_tran_id")`, đo 2026-09-07), nên điều kiện chặn client nối luồng OCR đã được gỡ. ⚠️ Backend cũng đã đổi nhà cung cấp ngân hàng **Casso → SePay**; client vẫn còn cột `bank_casso_id` và giá trị provider `'Casso'` — không gãy đồng bộ vì hai trường ấy không nằm trong hợp đồng, nhưng là món nợ tên gọi |

---

## 2. Còn lại phải làm gì

Năm bước đầu của kế hoạch cũ **đã xong** trong đợt 2026-09-07 (Socket.io,
(A) và (C) của `/sync/push`, `validClassify`, lỗ hổng phân quyền từ khoá, và
cả đợt migration). Phần còn lại, xếp theo mức thiệt hại:

1. **(D) của `/sync/push`** (nhóm 1 mục 2) — vài dòng. Bỏ `?? 0` ở nhánh tạo
   của `upsertBudget` **và** `@default(0)` trong `schema.prisma`. Cùng khuôn
   với (C) đã sửa. Đây là mục duy nhất còn lại của một tài liệu mà backend
   đã làm ba phần tư.
2. **Cột màu danh mục** (nhóm 1 mục 7b) — một cột. ⚠️ Tài liệu ấy chưa từng
   lên origin nên backend chưa hề thấy; đây không phải mục bị từ chối.
3. **Hai cột hoá đơn** (nhóm 2 mục 10): `transaction.Idbill` và
   `bill.Previous_bill_id`. Đo 2026-09-07: bảng `bill` có 18 cột, không có
   cột nào trong hai cột ấy; `transaction` cũng chưa có `Idbill`.
4. **`bill.Auto_pay` + chốt chặn trả hai lần** (nhóm 2 mục 10b) — làm **sau**
   bước 3 vì phép kiểm đọc `transaction.Idbill`. Là mã kiểm ở tầng ứng dụng,
   không phải unique index (hoàn tác rồi trả lại là hợp lệ).
5. **`Pay_status = 'Skipped'`** (việc E của tài liệu hoá đơn) — không cần
   migration; client chờ **một câu xác nhận** rồi mới mở tính năng "bỏ qua
   kỳ này".
6. **`bill.Anchor_day`** (`BILL_ANCHOR_DAY.md`, thêm 2026-09-08) — một cột
   `SMALLINT` nullable. Client đã làm xong phần của mình ở DB v18 nhưng cột
   đang là **cục bộ**, nên hoá đơn đi qua đường đồng bộ mất ngày gốc và chuỗi
   tạo trên máy khác vẫn có thể tụt dần. ⚠️ Ràng buộc **duy nhất**: server
   không bao giờ được tự tính lại cột này từ `Due_date` — nó là *ý định của
   người dùng*, không phải giá trị suy ra được.

7. **Bắc `sync.completed` ra socket** ([SOCKET_SYNC_COMPLETED.md](./SOCKET_SYNC_COMPLETED.md),
   thêm 2026-09-09) — một listener cộng một hàm phát, không migration. Sự kiện
   **đã được publish** vào EventBus ở `sync.service.js:194` nhưng không ai bắc
   ra socket. Đây là mục duy nhất trong danh sách này biến một hạng mục đã xong
   về hạ tầng thành thứ người dùng cảm nhận được: chênh lệch giữa **15 phút** và
   **tức thì** cho thay đổi từ máy khác.
8. **Thống nhất payload `bank_transaction.incoming`**
   ([SOCKET_BANK_EVENT_PAYLOAD.md](./SOCKET_BANK_EVENT_PAYLOAD.md), thêm
   2026-09-09) — sự kiện này phát ra **hai hình dạng khác nhau** tuỳ đường
   (`bank.worker.js` snake_case, `notification.service.js` camelCase), và
   trường `type` mang **hai nghĩa** khác nhau. Không chặn client hôm nay vì
   client cố ý không đọc trường nào, nhưng nó sẽ hỏng **im lặng** với bất kỳ ai
   bắt đầu đọc payload.
9. **Nới cột `wallet.Status`**
   ([WALLET_STATUS_COLUMN_WIDTH.md](./WALLET_STATUS_COLUMN_WIDTH.md), thêm
   2026-09-10) — một dòng `ALTER TABLE`, không đụng mã ứng dụng. Cột là
   `varchar(7)` còn giá trị cần ghi là `'Inactive'` — **8 ký tự**. Client đã
   làm xong tính năng **lưu trữ ví** nhưng phải để cột `status` **cục bộ**,
   nên lưu trữ chỉ có hiệu lực trên máy đã bấm. ⚠️ Điểm đáng chú ý: **lược đồ
   tự mâu thuẫn ở đúng cột này** — `chk_wallet_status` cho phép `'Inactive'`
   nhưng kiểu cột không chứa nổi nó, nên không giá trị nào vừa cả hai ngoài
   `'Active'`. Không cần đụng CHECK, chỉ nới kiểu cột cho khớp ràng buộc đã
   có. CSDL dev trên máy người dùng từng bị đổi sang `varchar(16)` **ngoài quy
   trình** ngày 2026-09-10 và **đã hoàn tác cùng ngày** — mục 3b của tài liệu ấy
   ghi diễn biến và phép đo sau hoàn tác. Tài liệu
   cũng ghi lại **một phép đo sai của chính phiên ấy** (kết luận nhầm rằng bảng
   không có CHECK nào, do lọc output qua `tail`) — giữ lại vì bài học về cách
   đo, không phải vì kết luận.

   ⚠️ **Cập nhật sau khi gộp `main` (2026-09-10):** phần **mã** của mục này
   backend **đã làm** từ 2026-09-09 — `7523c8c` đổi `schema.prisma` sang
   `VarChar(20)` và bước 4 của `database/7_Update_Account_User_Delete_Rules.sql`
   nới đúng cột ấy. Việc còn lại chỉ là **áp tệp 7**, nên mục này **không đếm
   riêng nữa** — nó nằm trong mục 11.

10. **Thu hẹp bộ lọc ghi chú của `/sync/push`**
    ([SYNC_NOTE_FILTER_REWRITE.md](./SYNC_NOTE_FILTER_REWRITE.md), thêm
    2026-09-10) — sửa hai biểu thức chính quy trong `utils/content-filter.util.js`,
    không migration. Bộ lọc của đợt 2026-09-10 bắt nhầm số tài khoản, cặp "số điện
    thoại + số tiền", "mật khẩu wifi", và cả hậu tố `(tự động)` do app sinh; bản
    đã lọc **đè lên máy người dùng** ngay chu kỳ đồng bộ ấy — tái hiện đầu-cuối
    trên máy ảo. **Chưa hỏng dữ liệu thật**, nhưng nổ ở lần ghi kế tiếp. Tài liệu
    kèm bảng test 15 ca (phác thảo đề xuất đã chạy đúng 15/15) và ba điểm cùng
    gốc: khoá mã hoá đang là mặc định viết cứng, `dedup.repository.js` so khớp trên
    chuỗi đã mã hoá, `bank.worker.js` ghi ghi chú dạng rõ.
11. **Áp các tệp `database/7`–`11`, và sửa fail-open ở `middleware/auth.js`**
    ([DEV_DB_MIGRATIONS_7_11.md](./DEV_DB_MIGRATIONS_7_11.md), thêm 2026-09-10) —
    không viết mã mới, chỉ áp năm tệp đã có theo đúng thứ tự rồi `prisma
    generate`. Đo trên CSDL dev: 5 và 6 đã áp, **7–11 chưa áp bước nào**, còn
    Prisma Client trong `node_modules` sinh từ 2026-09-07. Hệ quả: phép kiểm tài
    khoản vỡ ở **mọi** request và **cho qua** — tài khoản bị khoá vẫn gọi được
    API; đường xoá / huỷ xoá tài khoản mà client gọi thì hỏng. ⚠️ **Đừng `prisma
    generate` trước khi áp 8 và 9** — làm thế là tắt luôn đăng nhập. Và đặt khoá
    mã hoá thật **trước** tệp 11.
12. **Bỏ `uq_wallet_saving_active`, và mã lỗi có cấu trúc cho 23505 trên `wallet`**
    ([WALLET_SAVING_INDEX.md](./WALLET_SAVING_INDEX.md), thêm 2026-09-10) — một
    dòng `DROP INDEX`. Luật "một ví Tiết kiệm mỗi tài khoản" chỉ tồn tại ở SQL
    (bản 2026-08-26), không có trong `Rule_project.md`; client tạo sẵn ví Tiết
    kiệm cho tài khoản mới nên ví Tiết kiệm thứ hai của người dùng **kẹt hàng
    đợi đẩy vĩnh viễn, im lặng**. Client đã chặn tạm ở cả datasource lẫn màn
    Thêm ví (2026-09-10) và sẽ gỡ khi backend xác nhận. Kèm xin
    `WALLET_NAME_DUPLICATE` / `WALLET_DEFAULT_DUPLICATE` theo khuôn
    `CATEGORY_NAME_DUPLICATE`. ⚠️ Cùng lượt đo phát hiện bảng `wallet` có **bốn**
    partial unique index mà tài liệu client từng ghi là "không có" — phép đo cũ
    dùng `pg_constraint`, nơi chúng không hiện.

Bốn mục dưới đây thêm 2026-09-10 sau lượt **rà soát CSDL mới** — đọc toàn bộ
`docs/Rule_Project/`, `schema.prisma`, `database/*.sql` và module đồng bộ, đo
lại trên CSDL dev. Đều **không cần migration**.

13. **Body 401 phải mang `code` / `reason_inactive`**
    ([AUTH_401_BODY_CODE.md](./AUTH_401_BODY_CODE.md)) — vài dòng ở
    `core/response-handler.js`. `unauthorized(res, message)` chỉ nhận **hai**
    tham số nên đối số thứ ba mà `middleware/auth.js:89` truyền vào **rơi mất**:
    body 401 thật không có `code`, `idaccount` lẫn `reason_inactive` — đo bằng
    cách chạy `ResponseHandler` với một `res` giả. JSON mẫu ở `Rule_project.md`
    11.3, `docs/progress/Client-app.md` 10.3/11.3 và `docs/progress/Backend.md`
    12.1/12.4 chưa từng được sinh ra. Client vì thế không phân biệt được *tài
    khoản bị khoá* với *token hết hạn*, nên nhánh HTTP của cưỡng chế đăng xuất
    chưa có gì để đọc; nhánh socket thì không phụ thuộc mục này. Kèm: handshake
    socket gắn `ACCOUNT_DELETED` cho **cả** tài khoản bị khoá. ⚠️ Chỉ kiểm
    đầu-cuối được **sau** mục 11 — hôm nay middleware cho qua trước khi tới dòng
    ấy.
14. **`goal.Priority`: `null` thành `0` sau một vòng đồng bộ**
    ([GOAL_PRIORITY_NULL_TO_ZERO.md](./GOAL_PRIORITY_NULL_TO_ZERO.md)) — một
    dòng ở `mapEntityFields('goal')`. `Number(null) === 0`, nên mục tiêu **chưa
    sắp** (NULL, xếp cuối — thoả thuận 2026-09-05) được lưu là `0`, và kéo về máy
    thành mục tiêu **đứng đầu** danh sách. Client cứng hoá phía mình trong cùng
    đợt, nhưng giá trị sai vẫn nằm trên server cho mọi máy khác. Kèm: nhánh tạo
    mặc định `1` thay vì `null`.
15. **Ánh xạ lỗi `/sync/push` thiếu `22001`/`P2000` và `23502`; lớp kiểm tra
    lệch CHECK** ([SYNC_PUSH_ERROR_MAPPING.md](./SYNC_PUSH_ERROR_MAPPING.md)) —
    hai nhánh `else if`. Tên mục tiêu hoặc hoá đơn dài hơn 100 ký tự, tên danh mục
    dài hơn 200, rơi xuống `DB_ERROR`; client coi mã ấy là tạm thời và **gửi lại
    mãi**. Xin ánh xạ về `CONSTRAINT_VIOLATION` — client đã xếp mã ấy vĩnh viễn
    nên không phải đổi gì. Kèm: một giá trị bị `sync.validation.js` từ chối làm
    **cả lô** trả 400, và client giữ lại **mọi** thao tác đang chờ. ⚠️ Liên quan
    mục 5: thêm `'Skipped'` vào CHECK mà quên lớp kiểm tra là tắc cả hàng đợi.
16. **Sửa `docs/Rule_Project/` và `docs/progress/Backend.md` cho khớp mã và
    CSDL** ([RULE_PROJECT_DOC_DRIFT.md](./RULE_PROJECT_DOC_DRIFT.md)) — chỉ sửa
    tài liệu. **31** chỗ lệch, chia bốn nhóm theo *sửa ở đâu*: 23 chỗ tài liệu
    sai, 3 chỗ đúng với tệp SQL chưa áp (đừng sửa), 3 chỗ mô tả tính năng chưa
    có như đã có, 2 chỗ tài liệu đúng mà mã sai. `New_Database.md` tự nhận
    "Source of Truth" nhưng thiếu năm cột client đang đồng bộ và ghi sai unique
    index của cả `category`, `wallet` lẫn `transaction`. ⚠️ Và mục 9 của
    `docs/progress/Backend.md` — danh sách "cần làm để khớp Client-App" — **không
    nhắc mục nào** của thư mục này, nên đội backend có thể chưa thấy chúng.

> ⚠️ **Trước khi chạy migration ở môi trường mới:** lấy bản vá xoá mềm ở
> nhánh `patch2`. Bản `)2_can_lam_all_migrations.sql` trên `main` sẽ roll back
> toàn bộ khi gặp dữ liệu thật — xem banner đầu tài liệu này.

---

## 3. Ranh giới trách nhiệm

Client-app **không sửa `src/Backend`**. Mọi việc cần backend đều được viết
thành tài liệu ở đây thay vì sửa thẳng. Nếu một mục nào đó đọc thấy vô lý hoặc
tốn hơn dự kiến, hãy ghi lại lý do vào chính tài liệu ấy — client sẽ đọc và tìm
đường vòng ở phía mình.

---

## 4. Ba tệp bối cảnh ở thư mục cha, cộng lược đồ chuẩn nay nằm chỗ khác

Không phải việc cần làm, nhưng cần để hiểu phần trên:

- [`New_Database.md`](../../../Rule_Project/New_Database.md) — lược đồ chuẩn của PostgreSQL (đã chuyển vào `docs/Rule_Project/`).
  Đây là **nguồn sự thật** cho schema.
- [`../2026-08-10-backend-sync-spec.md`](../2026-08-10-backend-sync-spec.md) —
  hợp đồng `/sync/push` và `/sync/pull`.
- [`../PROGRESS-BACKEND.md`](../PROGRESS-BACKEND.md) — checklist B1→B7.
- [`../TRANSACTION_NOTE_ENCODING.md`](../TRANSACTION_NOTE_ENCODING.md)
  (2026-09-08) — **không xin gì**, chỉ báo rằng client mã hoá ý nghĩa vào
  `transaction.Note`.

⚠️ `New_Database.md` **không còn ở thư mục cha**: nhánh `main` chuyển nó sang
`docs/Rule_Project/` ngày 2026-09-10. Tiêu đề mục này từng ghi "Ba", rồi "Bốn",
nay lại là ba — **đếm bằng máy mỗi lần chạm vào, đừng chép con số cũ**.

⚠️ **Backend lệch tên cột giữa các bảng**, ít nhất ba kiểu: `category` dùng
`Delete_at`, `transaction` dùng `Deleted_at`, và cột ngày của giao dịch là
`DateTransaction` (không gạch dưới). Đừng suy tên từ bảng này sang bảng kia —
mở `schema.prisma` ra đọc. Sai tên cột ở PostgreSQL thì báo lỗi ngay, nhưng sai
trong payload đồng bộ thì **im lặng**.
