# Danh mục mặc định thành bản sao riêng của từng tài khoản

> **Trạng thái: thiết kế đã duyệt 2026-09-07, chưa viết mã.**
>
> Thay đổi này **đảo lại** quyết định ngày 2026-09-05 (`foldIntoBackendDefaults`).
> Đọc `docs/CATEGORY_RATIONALE.md` trước — nó ghi vì sao vùng này đã thay đổi
> ba lần, và mục 6 của nó liệt kê những phương án đã bị loại bỏ kèm lý do.

## 1. Yêu cầu

Khi người dùng đăng nhập lần đầu, hệ thống dựa trên bộ danh mục mặc định có sẵn
trên backend để **tạo cho tài khoản ấy những danh mục giống như thế**, rồi đồng
bộ chúng lên backend.

Ba quyết định đã chốt với người dùng:

| Câu hỏi | Chốt |
|---|---|
| Sau khi có bản sao, bản mặc định toàn cục còn hiện không? | **Ẩn hẳn — cho MỌI tài khoản, không điều kiện.** Bản mặc định chỉ còn là khuôn để sao chép |
| Làm sao biết đã seed rồi, để không seed lại? | **Đếm bản sao, kể cả hàng đã xoá mềm** |
| Đơn vị của phép đếm | **Theo từng danh mục**, không theo tài khoản — xem mục 4 |
| Bản sao có kế thừa **nhóm** của bản mặc định không? | **Không** |
| Bản sao có mang theo **từ khoá phân loại** không? | **Có**, và từ khoá **phải sống sót** qua cài lại app / máy khác — xem mục 10 |
| Backend thêm danh mục mặc định thứ 19 về sau thì sao? | **Tài khoản đã seed vẫn nhận bản sao của nó** ở lần chạy kế tiếp |

## 2. Hiện trạng đo được (2026-09-07)

**Backend có 18 danh mục mặc định** (`Is_default = true`, `Create_by = 1`,
`Delete_at IS NULL`): 9 Chi, 5 Thu, 4 Vay/nợ.

**Hai unique index trên bảng `category`** — đây là dữ kiện quyết định, vì nó
nói việc này có làm được không:

```sql
uq_category_owner_name_classify
  UNIQUE ("Create_by", "NameCategory", "Classify")
uq_category_default_name_classify
  UNIQUE ("NameCategory", "Classify") WHERE ("Is_default" = true)
```

Bản sao riêng (`Create_by = <tài khoản>`, `Is_default = false`) nằm ở **không
gian tên khác** với bản mặc định (`Create_by = 1`, `Is_default = true`). CSDL
**không cản** việc này.

⚠️ Hệ quả: bản sao **bắt buộc** phải mang `Is_default = false`. Sao chép mà giữ
cờ ấy là đụng thẳng index thứ hai.

**Client hiện hiện cả hai loại trong cùng danh sách.** `sync_engine` quy
`is_default = true` thành `idaccount = 0`, và mọi truy vấn danh sách lọc theo
`idaccount = 0 OR idaccount = <tài khoản>`.

**Pull mang cả hàng đã xoá về.** Backend trả `delete_at`, và nhánh pull ánh xạ
nó sang `isDeleted` (`sync_engine.dart` ~dòng 621). Đây là thứ khiến phép đếm
"kể cả đã xoá" sống sót qua một lần cài lại app — nếu không thì mọi bản sao đã
xoá sẽ mọc lại trên máy mới.

**Tài khoản 10** (tài khoản kiểm thử) đang có **3 danh mục riêng** và đang dùng
bộ mặc định toàn cục.

## 3. Cái gì phải gỡ, và vì sao

`PersonalDefaultCategories.foldIntoBackendDefaults()` gộp **bản riêng → bản mặc
định** rồi xoá mềm bản riêng. Thiết kế này đi **ngược chiều** đúng nghĩa đen. Để
cả hai chạy là một vòng lặp huỷ lẫn nhau: seed tạo bản sao, fold gộp chúng trở
lại rồi xoá, lượt sau seed thấy hàng đã xoá nên không tạo lại — tài khoản mất
sạch danh mục sau đúng hai chu kỳ.

**`foldIntoBackendDefaults()` phải bị gỡ trong cùng lần thay đổi**, không phải
sau đó.

`convertLegacyRows()` thì **giữ nguyên**: nó xử lý hàng seed `cat_*` của bản
client cũ, một việc khác hẳn, và vẫn cần cho máy đã cài từ trước.

## 4. Luật seed — và vì sao nó KHÔNG phải `ensureMissing()`

> Với **mỗi** danh mục mặc định, nếu tài khoản **chưa từng** có danh mục riêng
> nào cùng (tên chuẩn hoá, `classify`) — **tính cả hàng đã xoá mềm** — thì tạo
> một bản.

⚠️ "Danh mục riêng nào" nghĩa là **bất kỳ** danh mục thuộc tài khoản, không
riêng bản do lần seed trước tạo ra. Dự án không đánh dấu "hàng này do seed sinh
ra", và cũng **không nên** thêm dấu ấy: người dùng tự tay tạo "Ăn uống" trước
khi seed chạy thì bản sao thứ hai cùng tên vi phạm quy tắc 7 ngay ở client, và
vi phạm `uq_category_owner_name_classify` khi đẩy lên.

Phép đếm theo **từng danh mục**, không theo tài khoản. Đây là chỗ gỡ mâu thuẫn
giữa hai quyết định đã chốt: "ẩn mặc định cho mọi tài khoản" khiến tài khoản 10
mất 18 mục nó đang dùng, trong khi luật đếm theo tài khoản lại từ chối seed nó
(vì nó đã có 3 danh mục riêng).

| Tình huống | Kết quả |
|---|---|
| Tài khoản mới | chưa có bản sao nào → tạo đủ 18 |
| Tài khoản 10 | chưa có bản sao nào → tạo 18, **giữ nguyên** 3 mục riêng sẵn có |
| Người dùng xoá bản sao "Ăn uống" | hàng xoá mềm còn đó → **không tạo lại** |
| Cài lại app rồi đăng nhập | pull mang cả hàng đã xoá về → **không tạo lại** |
| Đăng nhập máy thứ hai | pull mang 18 bản sao về → không tạo lại |

⚠️ **Khác biệt duy nhất với `ensureMissing()` cũ — thứ đã sinh ra G16 — là ba
chữ "kể cả đã xoá".** `ensureMissing()` chỉ nhìn hàng đang sống, nên xoá một
danh mục là nó mọc lại ở **mỗi lần mở app**, và mỗi lần mọc lại là một thao tác
đẩy hỏng vĩnh viễn. Ai sửa phần này về sau mà "dọn dẹp" bằng cách bỏ điều kiện
đếm hàng đã xoá sẽ tái hiện nguyên vẹn G16. Đọc G16 trong
`docs/CLIENT_APP_KNOWN_GAPS.md` trước khi đụng vào.

Phép so tên dùng **`normalizeCategoryName()`** ở `lib/core/category/category_name.dart`
— định nghĩa duy nhất trong dự án. ⚠️ **Tuyệt đối không dùng
`removeVietnameseTones()`**: bỏ dấu là phép so mất thông tin.

Phép so `classify` dùng `SyncPayloadNormalizer.sameCategoryClassify()`, như
`foldIntoBackendDefaults` đang làm — backend viết hoa chữ đầu (`Chi`, `Thu`,
`Vay/no`) còn client dùng chữ thường.

## 5. Chạy ở đâu, theo thứ tự nào

**Sau lần pull đầu tiên**, đúng chỗ `foldIntoBackendDefaults` đang đứng. Bản mặc
định chỉ có mặt ở máy này **sau khi** pull mang nó về.

⚠️ **Tuyệt đối không chạy trước pull.** Tạo danh mục khi CSDL cục bộ còn rỗng là
**tạo mù** — đó chính là **G14**: trên máy mới nó sinh ra đúng những bản trùng
tên với bản đã có trên backend, đẩy lên hỏng vĩnh viễn và kéo cả engine vào giãn
cách luỹ tiến.

Thứ tự trong một lần chạy, **không được đảo**:

1. Đọc bộ mặc định đã pull về.
2. Với mỗi mục còn thiếu bản sao → tạo bản sao (`isDefault = false`, UUID mới,
   `syncStatus = 'pending'`).
3. **Repoint** mọi `transactions` / `budgets` / `bills` đang trỏ vào bản mặc
   định sang bản sao tương ứng — dùng `db.repointCategoryReferences()` sẵn có.
4. Chỉ sau đó bản mặc định mới biến mất khỏi giao diện.

**Repoint TRƯỚC, ẩn SAU.** Đảo lại là lỗi 11.6 — bài học đã lặp lại hai lần
trong vùng này.

⚠️ **Ẩn vô điều kiện có một mặt sau phải xử lý:** nếu bước seed hỏng — pull
lỗi, mất mạng giữa chừng, ngoại lệ bị nuốt — thì tài khoản không có bản sao nào
mà bản mặc định cũng đã bị ẩn, tức người dùng thấy **danh sách danh mục rỗng**
và không ghi nổi một giao dịch. Trước đây bộ mặc định toàn cục chính là tấm lưới
đỡ cho tình huống ấy.

Vì thế bước seed **không được nuốt lỗi im lặng** như hai bộ tự chuyển tiền, và
phải chạy lại được ở lượt đồng bộ kế tiếp. Luật đếm ở mục 4 vốn đã luỹ đẳng nên
chạy lại là an toàn; điều cần thêm là **đừng đánh dấu "đã seed" cho tới khi thật
sự tạo xong**.

## 6. Ẩn bản mặc định — bán kính đo được

**6 chỗ lọc `idaccount.equals(0)`**: 5 trong `lib/core/database/daos/category_dao.dart`,
1 trong `lib/core/database/app_database.dart`.

Thêm **`category_dao.dart:138`** dùng `idaccount.equals(accountId) | isDefault.equals(true)`
— cùng tác dụng, khác cách viết, nên `grep` một mẫu là bỏ sót.

Ngoài ra khoảng **30 chỗ chạm `isDefault` thuộc về danh mục** (không tính ví,
vốn có cờ `isDefault` riêng, và không tính `app_database.g.dart` sinh tự động):
`category_management_repository.dart` 12, `sync_engine.dart` 7,
`personal_default_categories.dart` 4, `category_dao.dart` 4, còn lại rải ở
`categories_table.dart`, `category_add_page.dart`, `category_group_page.dart`.

Không phải chỗ nào cũng phải sửa, nhưng **phải đọc hết** trước khi kết luận:
một nhánh `isDefault` bỏ sót sẽ là một danh mục hiện ra ở đúng một màn hình.

## 7. `_resolveCategoryId` được đơn giản hoá, nhưng đừng xoá nhánh cũ

Sau thay đổi này, giao dịch trỏ vào **bản sao** — `isDefault = false`, id là
UUID thật — nên rơi vào nhánh đầu của `_resolveCategoryId` (`sync_engine.dart:1235`)
và trả về ngay.

Nhánh **ánh xạ theo tên** (dòng 1245–1258) trở thành đường chết với dữ liệu mới,
nhưng **vẫn phải giữ**: nó là đường duy nhất cứu hàng `cat_*` của bản client cũ
còn nằm trên máy người dùng đã cài từ trước.

## 8. Rủi ro đã biết

- **Backend phình 18 hàng mỗi tài khoản.** Đây là thay đổi thật về dữ liệu, đã
  nói rõ với người dùng và được chấp nhận.
- **Nhóm danh mục không đi theo — đã chốt.** Bản sao được tạo **không thuộc
  nhóm nào**. `CategoryGroupMemberships` không đồng bộ được (**G10**, chặn ở
  backend) nên việc gán nhóm chỉ tồn tại trên một máy; kế thừa nó sẽ là chép
  một thứ vốn đã không đi đâu.
  ⚠️ Hệ quả phải xử lý: hàng membership đang trỏ vào **bản mặc định** sẽ trỏ
  vào một danh mục không còn hiện ra. Trang nhóm danh mục phải chịu được điều
  đó, hoặc những hàng ấy phải được dọn cùng lúc.
- **Đường ghi khác vẫn tạo được dữ liệu vi phạm.** Quy tắc trùng tên hiện chỉ
  client thi hành; `/sync/push` **chưa kiểm gì cả**. 18 hàng mới mỗi tài khoản
  đi qua đúng đường đó.
- **Người dùng nay sửa/xoá được mọi danh mục.** Trước đây bản mặc định là toàn
  cục nên bị chặn; nay chúng là của họ. Phải rà lại các nhánh chặn trong
  `category_management_repository.dart` để chúng không chặn oan.

## 9. Test — viết đỏ trước

- **Luật seed:** tài khoản chưa có gì → tạo đủ 18; chạy lần hai → không tạo
  thêm; xoá mềm một bản sao rồi chạy lại → **không** tạo lại (đây là phép canh
  G16, ghi rõ điều đó trong `reason:`); tài khoản đã có danh mục riêng trùng
  tên với một mặc định → không tạo bản thứ hai.
- **Thứ tự:** repoint chạy trước, và một giao dịch đang trỏ vào bản mặc định
  phải kết thúc ở bản sao — không được kết thúc ở một danh mục đã xoá.
- **Chạy trước pull thì không tạo gì** — phép canh G14.
- **Bản sao mang `isDefault = false` và UUID hợp lệ**, nếu không `_resolveCategoryId`
  trả `null` và giao dịch kẹt vĩnh viễn.
- **Truy vấn danh sách không còn trả hàng `idaccount = 0`** — một test cho mỗi
  truy vấn đã sửa, vì bỏ sót một cái là bỏ sót đúng một màn hình.
- **Từ khoá được chép sang bản sao**, và chép **không đè** từ khoá người dùng
  đã tự sửa.
- **Payload đẩy của danh mục mang `keyword`** — và `sync_payload_contract_test.dart`
  canh chừng nó, vì tên trường sai thì im lặng (quy tắc 4).
- **Từ khoá sống sót một vòng đẩy–kéo**: đẩy lên rồi xoá CSDL cục bộ và pull lại
  thì từ khoá của bản sao vẫn còn. Đây là phép canh cho đúng yêu cầu người dùng
  đặt ra; test đơn vị trên payload **không** đủ để khẳng định điều đó.
- **Bản sao không thuộc nhóm nào**, và trang nhóm danh mục chịu được hàng
  membership trỏ vào một bản mặc định đã bị ẩn.
- **Danh mục mặc định thứ 19 xuất hiện sau khi tài khoản đã seed** → lần chạy
  kế tiếp tạo đúng **một** bản sao cho nó, không đụng 18 bản đã có.
- Cập nhật `sync_payload_contract_test.dart` nếu payload đẩy đổi hình dạng.
  ⚠️ Payload danh mục hiện có **12 khoá** và **không** có `keyword` — nếu
  ai đó định thêm từ khoá vào đường đẩy thì phải sửa hợp đồng cùng lúc, nếu
  không tên trường sai sẽ **im lặng** (quy tắc 4 của `CLAUDE.md`).

## 10. Từ khoá phân loại — chép, VÀ đưa vào đường đẩy

**Đã chốt: bản sao mang theo từ khoá, và từ khoá phải sống sót qua cài lại app
hoặc đăng nhập máy khác.**

Vế thứ hai **làm được, và thuần client** — kiểm ngày 2026-09-07:

| Chặng | Trạng thái |
|---|---|
| Cột `Keyword` trong bảng `category` | **có thật** (`schema.prisma:113`, `@db.Text`) |
| `/sync/push` nhánh **tạo** | **đã nhận** — `keyword: mapped.keyword \|\| null` (`sync.repository.js:133`) |
| `/sync/push` nhánh **cập nhật** | **đã nhận** — `keyword: mapped.keyword !== undefined ? … : existing.keyword` (`:153`) |
| `mapEntityFields('category')` | truyền `keyword` qua **không đổi tên** |
| Pull | **đã đọc** — tách chuỗi nối bằng dấu phẩy rồi `_gieoTuKhoaKhiTrong` |
| **Payload đẩy của client** | ❌ **thiếu** — 12 khoá (`id`, `name`, `namecategory`, `classify`, `icon`, `colour`, `is_default`, `is_deleted`, `isGroup`, `parentId`, `updated_at`, `idaccount`) và **không có `keyword`** (`sync_engine.dart:950` và `:1025`) |

Nên việc phải làm là **thêm `keyword` vào payload đẩy**, nối các từ khoá bằng
dấu phẩy đúng như backend đang lưu. Không cần backend làm gì.

⚠️ **Bắt buộc cập nhật `sync_payload_contract_test.dart` trong CÙNG lần sửa** —
quy tắc 4 của `CLAUDE.md`: tên trường sai thì **im lặng**, không báo lỗi.

⚠️ **Rủi ro ghi đè phải cân nhắc khi thi công.** Backend cũng tự ghi vào cột ấy:
`recordFeedback()` → `appendCategoryKeyword()` **nối thêm** từ khoá học được từ
phản hồi người dùng. Client đẩy lên một danh sách đầy đủ là **thay cả chuỗi**,
nên từ khoá server vừa học có thể bị xoá. Cần quyết ở bước lập kế hoạch: chỉ đẩy
khi client thật sự có thay đổi, hay hợp nhất hai danh sách trước khi đẩy.

**Một tác dụng phụ tốt:** `appendCategoryKeyword()` không đối chiếu chủ sở hữu
(lỗ hổng ở mục 4 `CATEGORY_KEYWORD_SYNC.md`), nên phản hồi trên một danh mục
**mặc định** hiện ghi vào hàng **mọi người cùng đọc**. Sau thay đổi này người
dùng không còn dùng hàng mặc định nữa, nên bán kính của lỗ hổng ấy **hẹp lại** —
nhưng nó **chưa được vá**, và tài liệu backend vẫn phải làm.

`_gieoTuKhoaKhiTrong` chỉ gieo khi danh mục **chưa có** từ khoá nào, nên nó
không đè lên thứ người dùng đã tự sửa. Đường chép ở bước seed phải giữ đúng tính
chất ấy.

### ⚠️ Phát hiện kèm theo: màu danh mục KHÔNG có chỗ trên server

Bảng `category` có đúng 12 cột và **không có cột màu**:
`Idcategory, Create_by, NameCategory, Classify, Is_default, Is_group, Idgroup,
Keyword, Icon, Create_at, Update_at, Delete_at`.

Client vẫn đẩy `colour` lên — `categoryForPush` **không** đổi tên khoá này
(phép đổi `colour` → `color` chỉ có ở `walletForPush`) — và backend **bỏ qua
im lặng** — đúng kiểu hỏng mà quy tắc 4 mô tả. Nghĩa là **màu của bản sao cũng
chỉ sống trên máy đã seed**, y hệt vấn đề từ khoá vừa gỡ, nhưng lần này **không
gỡ được ở client** vì không có cột để ghi vào.

Đây là lỗi **có sẵn từ trước**, không phải do thay đổi này sinh ra, và nằm ngoài
phạm vi spec. Ghi lại vì nó sẽ lộ ra ngay khi ai đó kiểm "bản sao có giống bản
mặc định không" trên máy thứ hai. Muốn sửa thì cần một tài liệu xin backend thêm
cột — chưa viết.

## 11. Danh mục mặc định thêm về sau

**Đã chốt: tài khoản đã seed vẫn nhận bản sao của danh mục mặc định mới.**

Việc này **không cần cơ chế riêng** — luật ở mục 4 đã cho sẵn: danh mục mặc định
thứ 19 xuất hiện thì tài khoản chưa từng có bản sao cùng (tên, `classify`), nên
lần chạy kế tiếp tạo một bản. Đừng thêm một "đường dọn" thứ hai cho việc này;
hai cơ chế cùng tạo danh mục là đúng cách G16 và G14 đã sinh ra.

Điều đi kèm: bước seed vì thế **không phải việc chỉ chạy một lần**, mà là một
phép đối chiếu chạy sau **mọi** lần pull. Tính luỹ đẳng ở mục 4 là thứ khiến
điều đó an toàn, và là thứ tuyệt đối không được làm hỏng.
