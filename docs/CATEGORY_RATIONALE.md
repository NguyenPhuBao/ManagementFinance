# Vì sao phần Danh mục phải thay đổi

> **Tài liệu này trả lời câu "tại sao", không phải câu "cái gì".**
> Mô tả trạng thái hiện tại nằm ở mục 4 và mục 12 của `PROJECT_CONTEXT.md`;
> quy tắc tóm tắt nằm ở `CLAUDE.md`. Ở đây chỉ ghi **lý do buộc phải thay đổi**,
> **bằng chứng đo được**, và **những phương án đã cân nhắc rồi loại bỏ** — đó là
> phần dễ mất nhất khi người khác đọc lại đoạn mã sau này.

**Ngày:** 2026-09-03 · **Phạm vi:** `src/Client-app` · **Commit:** `6b93ee8`, `0f8a820`, `d2cea8c`, `e7c7a44`, `103d381` · **Cập nhật:** 2026-09-07 (thay đổi 5), 2026-09-10 (thay đổi 6), 2026-09-11 (trạng thái G24, G31 và mục 8 sau khi gộp `main` @ `cc65f4f`; G24 đóng cùng ngày), 2026-09-29 (thay đổi 7 — gợi ý danh mục học từ ghi chú, mục 5d), 2026-09-29 tối (thay đổi 8 — gắn danh mục hàng loạt C1, mục 5e)

---

## 0. Tóm tắt cho người vội

Sáu thay đổi, mỗi cái do một lỗi **có thật** buộc phải làm — không có cái nào là dọn dẹp cho đẹp. Bảng này từng ghi "Bốn" và thiếu hàng của thay đổi 5 dù thân tài liệu đã có mục 5b; bổ sung 2026-09-10:

| Thay đổi | Lỗi buộc phải sửa |
|---|---|
| Quy tắc trùng tên: bỏ `classify` và nhóm cha khỏi khoá, tính cả danh mục mặc định | Bốn đường tạo được danh mục trùng tên; ba trong số đó client cho tạo còn PostgreSQL chặn, nên thao tác đẩy **thất bại im lặng** |
| Gom mọi phép so tên về **một định nghĩa duy nhất**, thêm bước gộp Unicode NFC | Ba biến thể so tên cùng tồn tại và đã lệch nhau; một trong số đó nằm trên đường đồng bộ và **không chuẩn hoá gì cả** |
| Bộ danh mục mặc định khớp đúng 13 mục của backend; 5 mục thừa thành danh mục cá nhân | Hai phía chỉ khớp **10/18** tên, khiến giao dịch dùng 8 mục còn lại **không bao giờ đẩy lên được** |
| ✅ *(backend làm xong 2026-09-07)* ID cố định cho danh mục mặc định | Nguyên nhân gốc của cả bốn lỗi 11.3–11.6 |
| Bản sao riêng của bộ mặc định cho từng tài khoản; hàng toàn cục lui về làm khuôn (2026-09-07) | Hàng mặc định dùng chung nên người dùng không sửa, đổi tên hay xoá được; bảng phụ `CategoryGroupMemberships` tồn tại chỉ vì thế (G10) |
| Tên danh mục dừng ở 200 code point (2026-09-10) | `NameCategory` là `varchar(200)`; tên dài hơn vỡ `P2000`, rơi xuống `DB_ERROR`, và bị gửi lại ở mọi chu kỳ đồng bộ (G31). ✅ 2026-09-11: backend nay trả `CONSTRAINT_VIOLATION` nên hết gửi lại mãi, nhưng bản ghi kẹt vĩnh viễn — giới hạn ô nhập vẫn cần |
| *(thay đổi 7, 2026-09-29 — **tính năng**, không phải sửa lỗi)* Gợi ý danh mục **học từ ghi chú** (Naive Bayes cục bộ), đi trước bộ từ khoá; bảng phản hồi cục bộ v25 | Bộ từ khoá **không học** — từ khoá phải có người gõ vào — và **không ghi** việc người dùng bấm *Chọn* hay *Bỏ qua*. Nghiệm thu còn lộ một từ khoá mặc định **gây nhầm** (`grab` → Ăn uống, seed backend) mà B1 sửa được — mục 5d |
| *(thay đổi 8, 2026-09-29 — **tính năng**)* **Gắn danh mục hàng loạt** (C1): thẻ trên Sổ giao dịch → màn duyệt, mô hình B1 tick sẵn, người dùng bấm *Áp dụng* mới ghi | Khoản trống danh mục (kéo từ server / bản cũ) nằm ở lát *Chưa phân loại*, nên donut, ngân sách theo danh mục và B3 mù với chúng. Trên Realme thật `demChuaGan = 0` — mọi hàng trống đều do máy sinh — mục 5e |

Hai hàng cuối là **ngoại lệ** của câu mở đầu: B1 (dự án con đầu tiên của mảng máy học) và C1 (việc đầu tiên của nhóm C, dựa trên B1) là việc người dùng chọn làm, không do lỗi nào ép. Chúng đứng trong tài liệu này vì vẫn cần đúng thứ tài liệu này giữ: quyết định, phương án đã loại, và con số đo được.

Kết quả **đo ngay sau đợt ấy** (2026-09-03): `flutter test` từ **144 → 180 test**, `flutter analyze` **29 issue, không error**. Đây là con số *lịch sử của đợt này*, không phải mức nền hôm nay — mức nền hiện tại nằm ở `CLAUDE.md`.

---

## 1. Một nguyên nhân gốc, nhiều triệu chứng

Vùng danh mục là nơi nhiều lỗi nhất dự án. Không phải ngẫu nhiên — nó có hai đặc điểm mà cộng lại thì mọi sai sót đều **hỏng âm thầm**:

**(a) Tên đang bị dùng làm khoá nối giữa hai phía.** Backend sinh ID danh mục mặc định bằng `crypto.randomUUID()`, client thì seed id dạng `cat_food`. Hai bên không có khoá chung nào, nên `_resolveCategoryId` phải dò theo **tên**. Bất kỳ khác biệt nào về dấu, hoa/thường, dạng Unicode hay danh sách seed đều làm ánh xạ trượt.

**(b) Danh mục mặc định là hàng dùng chung.** Nó không thuộc về ai (`Create_by = 1` ở backend, `idaccount = 0` ở client), nên mọi quy tắc "theo từng người dùng" đều phải có một vế riêng cho nó.

Và điều khiến cả hai trở nên nguy hiểm: **`/sync/push` trả HTTP 200 kể cả khi mọi thao tác đều hỏng.** Thao tác thất bại chỉ nằm trong `results[]` với `status: "failed"`. Không có ngoại lệ nào được ném ra, không có gì hiện lên màn hình. Người dùng chỉ thấy dữ liệu "không lên server" mà không ai biết vì sao.

> Đây là lý do vì sao mọi thay đổi dưới đây đều đi kèm test tái hiện viết **trước**: lớp lỗi này không tự lộ ra khi dùng tay.

---

## 2. Thay đổi 1 — Quy tắc trùng tên

### Lỗi buộc phải sửa

Bộ kiểm tra cũ khoá theo `(idaccount, classify, parentId, tên)` và tách nhóm với danh mục con làm hai không gian tên riêng. PostgreSQL thì khoá theo `(Create_by, NameCategory, Classify)`. **Hai bên khác nhau**, nên có những trường hợp client cho tạo mà CSDL từ chối:

| Đường tạo trùng | Client | PostgreSQL | Hậu quả |
|---|---|---|---|
| Cùng tên, khác `classify` | cho qua | cho qua | trái quy tắc nghiệp vụ |
| Cùng tên, khác nhóm cha | **cho qua** | **chặn** | đẩy lên vỡ ràng buộc → `failed` im lặng |
| Nhóm trùng tên danh mục con | **cho qua** | **chặn** | như trên |
| Trùng tên danh mục mặc định | **cho qua** | cho qua | hai mục không phân biệt được trong danh sách chọn |

### Một lỗi nằm ngay trong chính lớp kiểm tra

Cả hai hàm kiểm tra đều quét trên kết quả của `getCategoryRows`, mà hàm đó **khử trùng lặp theo tên trước khi trả về**. Nếu bản sống sót là danh mục mặc định thì bộ lọc `!category.isDefault` lại loại nó ra — hàm báo "không trùng" dù tên đó đã tồn tại. Đây là **âm tính giả sinh ra từ chính công cụ đang dùng để kiểm tra**, không phải do thiếu điều kiện.

Vì vậy bản sửa không thêm tham số cho hàm cũ mà tách hẳn một truy vấn riêng (`CategoryDao.getNamesInUse`) không lọc `classify` và không khử trùng lặp.

### Vì sao chỉ xét trùng khi tên **thật sự đổi**

Quy tắc mới áp cho cả thao tác sửa. Nhưng bản client trước đây loại danh mục mặc định khỏi phép kiểm tra, nên máy người dùng có thể đang giữ một danh mục riêng trùng tên với danh mục mặc định. Chặn tuyệt đối sẽ khiến họ **không sửa nổi danh mục đó nữa** — kể cả chỉ đổi icon — và không có đường thoát nào ngoài việc đổi tên.

Đây là chủ ý, không phải lỗ hổng: tạo mới và đổi tên sang một tên đã bị chiếm vẫn bị chặn đầy đủ.

---

## 3. Thay đổi 2 — Một định nghĩa chuẩn hoá duy nhất

### Lỗi buộc phải sửa

Trong cùng một dự án có **ba biến thể so tên** cùng tồn tại:

| Nơi | Cách so |
|---|---|
| 6 khoá khử trùng lặp trong `CategoryDao` | `trim().toLowerCase()` |
| `_normalize` trong repository | `trim().toLowerCase()` + gom khoảng trắng |
| **`CategoryDao.getByName`** | **`t.name.equals(name)` — không chuẩn hoá gì** |

`getByName` là hàm `_resolveCategoryId` dùng để ánh xạ danh mục mặc định cục bộ sang UUID backend. Nó nằm **đúng trên đường đồng bộ**, và so phân biệt hoa/thường: lệch một chữ hoa là ánh xạ trượt, trả `null`, giao dịch bị hoãn đẩy **vĩnh viễn**. Đó chính là lớp lỗi 11.4 và 11.6, chỉ đợi một lần lệch tên là tái phát.

### Vì sao thêm bước gộp Unicode NFC

Đo bằng Dart, không phải suy đoán:

```
"Cà phê" dạng dựng sẵn (NFC) : 6 ký tự
"Cà phê" dạng tách dấu (NFD) : 8 ký tự
Bằng nhau sau khi trim + toLowerCase : false
```

Hai chuỗi **nhìn y hệt nhau** mà hệ thống coi là hai tên khác nhau — nên vẫn tạo trùng được, và không có cách nào nhìn ra bằng mắt. Tiếng Việt gõ từ bàn phím iOS, Android hay dán từ web đều có thể ra dạng khác nhau.

### Vì sao chốt đủ bốn bước ngay thay vì thêm dần

> **Nới lỏng về sau là miễn phí. Siết chặt về sau thì phải dọn dữ liệu.**

Nếu hôm nay chỉ so bằng chữ thường, mai muốn thêm gom khoảng trắng, thì những cặp `"Ca  phe"` / `"Ca phe"` đã tồn tại sẽ **vi phạm ràng buộc mới** — `CREATE UNIQUE INDEX` phía PostgreSQL sẽ thất bại cho tới khi có người đi sửa dữ liệu của người dùng thật. Ngược lại, bỏ bớt một bước thì không dòng nào vi phạm.

Chi phí làm bây giờ gần như bằng không: dữ liệu mặc định trên CSDL hiện **13/13 đều ở dạng NFC**.

---

## 4. Thay đổi 3 — Bộ danh mục mặc định

### Lỗi buộc phải sửa

Đối chiếu trực tiếp hai danh sách (client seed với truy vấn CSDL):

| | Số mục |
|---|---|
| Client seed | 18 |
| Backend | 13 |
| **Khớp tên** | **10** |
| Chỉ có ở client | 8 |
| Chỉ có ở backend | 3 |

Vì danh mục mặc định được ánh xạ **bằng tên**, 8 mục chỉ có ở client không tìm được bản UUID nào → `_resolveCategoryId` trả `null` → **mọi giao dịch dùng chúng bị hoãn đẩy vĩnh viễn**.

Trong 8 mục đó có `Chi khác` và `Thu khác` — thứ người dùng bấm khi không có mục nào hợp, tức **đường hay đi nhất lại đang là đường hỏng** — cùng `Trả nợ` và `Thu nợ`, một nửa nghiệp vụ vay nợ.

Đáng chú ý cặp `"Hoá đơn & Dịch vụ"` với `"Hóa đơn"`: khác cả hậu tố lẫn vị trí dấu (`Hoá` với `Hóa`). Chuẩn hoá chữ thường **không** cứu được — đó là hai chuỗi khác nhau thật.

### Vì sao 8 mục được chia làm hai nhóm

**Ba mục chỉ khác nhãn** (`Sức khoẻ`→`Y tế`, `Nhà ở`→`Nhà cửa`, `Hoá đơn & Dịch vụ`→`Hóa đơn`) — cùng một khái niệm. Đổi tên seed là xong, và bộ máy sẵn có tự ánh xạ chúng sang UUID khi pull.

**Năm mục backend không có** — không sửa được bằng cách đổi tên. Chỉ có ba lựa chọn: backend thêm vào, client xoá đi, hoặc chuyển chủ sở hữu.

### Vì sao chuyển thành danh mục cá nhân chứ không xoá

Xoá là cách hiểu đen của "bỏ phần thừa", nhưng nó hỏng ở hai chỗ:

1. **Xoá hàng seed khi giao dịch còn trỏ vào nó chính là lỗi 11.6** — lỗi mà dự án đã dính đúng một lần. Làm với 5 mục cùng lúc là tái hiện nó hàng loạt.
2. **Không có đích nào hợp lý để chuyển giao dịch sang.** Bộ 13 của backend không có mục "Khác" nào cả.

Chuyển chủ sở hữu giải quyết trọn vẹn: bộ **mặc định** của client còn đúng 13 mục khớp backend, không ai mất danh mục, và 5 mục kia **đẩy lên được** — vì danh mục người dùng thì có đồng bộ, còn danh mục mặc định thì không. Backend không phải thêm gì.

### Một chi tiết suýt làm hỏng cả cách sửa

Ban đầu định chuyển tại chỗ, giữ nguyên id `cat_other_chi` cho khỏi phải repoint. Nhưng `_resolveCategoryId` chỉ chấp nhận danh mục **không phải mặc định** khi id là **UUID hợp lệ**:

```dart
if (!localCategory.isDefault) {
  return _isValidUuidFormat(categoryId) ? categoryId : null;
}
```

Giữ id dạng slug thì giao dịch kẹt y như cũ, chỉ đổi nguyên nhân. Nên bắt buộc phải tạo UUID mới và repoint dữ liệu cũ — ở **cả ba bảng** có `categoryId` (transactions, budgets, bills), và **repoint trước, xoá mềm sau**.

---

## 5. Thay đổi 4 — ID cố định (✅ backend đã làm, 2026-09-07)

> ✅ **Đã xong 2026-09-07.** `seed.js` nay đóng băng **13 stable UUID**, hết
> `crypto.randomUUID()` cho danh mục; backend còn cấp thêm
> `GET /api/sync/default-categories`. Phần dưới giữ làm hồ sơ vì nó ghi *vì sao*
> tên danh mục từng bị dùng làm khoá nối.

`prisma/seed.js` **từng** sinh ID bằng `crypto.randomUUID()`, nên seed lại là ra bộ khác hoàn toàn. Đây là lý do tên bị dùng làm khoá nối ngay từ đầu, và là nguyên nhân gốc của bốn lỗi 11.3–11.6 cùng cả lớp mã vá víu quanh chúng.

Sau thay đổi 3 thì ánh xạ **đang chạy đúng** (13/13 khớp tên), nên việc này không còn gấp. Nhưng nó vẫn là thứ duy nhất khiến không phải làm lại lần nữa: chỉ cần ai đó sửa một nhãn cho đẹp hơn là ánh xạ đứt, **không test hay lỗi nào bắt được**; và reset CSDL vẫn phá mọi thứ.

Đề xuất chi tiết: `docs/superpowers/backend/DA-XONG/CATEGORY_STABLE_IDS.md`.

---

## 5b. Thay đổi 5 — bản sao riêng cho từng tài khoản (2026-09-07)

**Đảo lại thay đổi 3.** Thay đổi 3 đẩy năm danh mục *ra khỏi* bộ riêng để chúng
thành mặc định toàn cục; thay đổi 5 làm ngược: **toàn bộ** bộ mặc định được sao
chép *vào* từng tài khoản, còn hàng toàn cục lui về làm **khuôn** và không hiện
ra ở đâu nữa.

### Vì sao đổi hướng

Danh mục mặc định là hàng dùng chung, nên người dùng **không sửa, không đổi tên,
không xoá** được — mọi thao tác ấy sẽ đụng vào dữ liệu của mọi người. Bản sao
riêng gỡ được điều đó, và kéo theo hai thứ miễn phí:

- **`CategoryGroupMemberships` hết việc.** Bảng phụ ấy tồn tại chỉ vì không ghi
  `Idgroup` riêng cho từng tài khoản lên một hàng dùng chung được. Bản sao thì
  ghi thẳng vào `parentId` — cột đã có và đã đồng bộ. **G10 đóng mà backend
  không phải làm gì.**
- **Lỗ hổng phân quyền của `appendCategoryKeyword()` hẹp bán kính lại**: phản
  hồi phân loại không còn ghi vào hàng mọi người cùng đọc. Nó **chưa được vá** —
  xem `CATEGORY_KEYWORD_SYNC.md`. ✅ *Đo lại 2026-09-11:* đã vá trong đợt backend
  2026-09-07 — kiểm `is_default` + `create_by`, trả 403
  (`classify.repository.js:75-76`).

### Chỗ dễ làm hỏng nhất

Luật tạo bản sao đếm **cả hàng đã xoá mềm**. Ba chữ ấy là khác biệt **duy nhất**
với `ensureMissing()` — thứ đã sinh ra G16. Bỏ chúng đi là danh mục người dùng
vừa xoá mọc lại ở mỗi lần mở app, và mỗi lần mọc lại là một thao tác đẩy hỏng
vĩnh viễn.

### Hai giới hạn đã biết

- **Bản sao chỉ đầy đủ khi bộ mặc định cục bộ đầy đủ.** Pull tăng dần theo
  `since`, nên một máy có thể chỉ biết một phần bộ mặc định của server. Đo được
  2026-09-07 (sáng): server có 18 hàng, máy kiểm thử tạo được 13 bản sao.
  ⚠️ **Chiều cùng ngày con số đổi:** đợt migration của backend thu bộ khuôn về
  đúng 13 stable UUID, **xoá mềm** 5 hàng `Chi khác`, `Thu khác`, `Làm thêm`,
  `Trả nợ`, `Thu nợ`. Server nay có **13 hàng sống + 5 hàng đã xoá mềm**; máy
  nào đã pull 5 hàng ấy sẽ nhận cờ xoá ở lượt pull sau.
- **Màu không theo được.** Ngày 2026-09-07 bảng `category` không có cột màu, nên
  màu của bản sao chỉ sống trên máy đã tạo. Tài liệu xin:
  `DA-XONG/CATEGORY_COLOUR_COLUMN.md`.
  ⚠️ **2026-09-11 — lý do đã đổi, hậu quả thì chưa.** Sau khi gộp `main` @
  `cc65f4f` server **có** cột `category.Color` (`varchar(9)`), `/sync/push` nhận
  và `/sync/pull` trả khoá **`color`**. Nhưng client đẩy danh mục bằng khoá
  **`colour`** (`categoryForPush` không đổi tên khoá — chỉ `walletForPush` đổi) và
  nhánh kéo về đọc `c['colour']`, nên màu **vẫn không đi theo chiều nào**, im
  lặng. Nay là lỗi **phía client** — **G24**, ✅ đã sửa cùng ngày (khoá `color` ở cả hai chiều; kiểm trên máy ảo)
  `docs/CLIENT_APP_KNOWN_GAPS.md`; chi tiết mục 2.3
  `docs/superpowers/backend/CAN-LAM/VERIFY_7675B35_REMAINING.md`.

Thiết kế đầy đủ:
`docs/superpowers/specs/2026-09-07-per-account-default-categories-design.md`.

---

## 5c. Thay đổi 6 — tên danh mục dừng ở 200 code point (2026-09-10)

### Lỗi buộc phải sửa

`category."NameCategory"` là `varchar(200)` (đo `information_schema.columns`
ngày 2026-09-10). Ô tên ở màn Thêm/Sửa danh mục và màn Nhóm danh mục không giới
hạn gì, còn `upsertCategory` phía backend không cắt chuỗi. Tên dài hơn vỡ `P2000`
ở `/sync/push`; backend chưa ánh xạ mã ấy nên trả `DB_ERROR`, và client xếp
`DB_ERROR` là lỗi tạm thời — danh mục bị gửi lại ở mọi chu kỳ đồng bộ, không lỗi
nào hiện ra. Nhóm danh mục cũng là một hàng `category`, nên màn Nhóm là đường
ghi thứ hai vào đúng cột ấy. **G31** `docs/CLIENT_APP_KNOWN_GAPS.md`.

✅ **2026-09-11 — vế server đã đóng.** Sau khi gộp `main` @ `cc65f4f`,
`sync.service.js` ánh xạ `22001`/`P2000` về `CONSTRAINT_VIOLATION` — mã client xếp
vĩnh viễn — nên danh mục tên quá dài không còn bị gửi lại mãi. Bộ lọc ô nhập
**vẫn cần**: không có nó, bản ghi ấy kẹt vĩnh viễn và không bao giờ lên server.
Đoạn trên giữ nguyên làm hồ sơ của lý do.

### Vì sao đếm code point, không dùng `maxLength`

PostgreSQL đếm `varchar(n)` theo **code point**; `maxLength` của Flutter đếm theo
**cụm grapheme**. Hai cách đếm lệch nhau đúng ở những tên dễ gặp trong app này:
chữ có dấu gõ ở dạng tách (một chữ "ề" là 3 code point) và emoji (một emoji gia
đình là 5). `maxLength` còn vẽ bộ đếm "0/200" dưới ô, thứ thiết kế Stitch không
có. Bộ lọc riêng ở `lib/core/utils/gioi_han_do_dai.dart` đếm code point, cắt
theo trọn cụm grapheme, và theo đúng chính sách của Flutter về việc cắt lúc bộ gõ
đang ghép chữ.

Cùng một bộ lọc chặn cả tên ví, mục tiêu, hoá đơn ở 100 — tài liệu này chỉ ghi
phần thuộc danh mục.

---

## 5d. Thay đổi 7 — gợi ý danh mục học từ ghi chú (B1, 2026-09-29)

**Không phải sửa lỗi** — mục này ghi quyết định và số đo của một tính năng. Thiết
kế đầy đủ: `docs/superpowers/specs/2026-09-28-goi-y-danh-muc-hoc-tu-ghi-chu-design.md`.

### Vì sao làm, và vì sao làm trước

Thẻ *"Gợi ý danh mục"* của màn Thêm giao dịch khớp **bảng từ khoá**
(`CategorySuggestionEngine`). Bảng ấy **không học** — từ khoá phải có người gõ
vào — và **không ghi** việc người dùng bấm *Chọn* hay *Bỏ qua*. Trong năm hướng
máy học người dùng muốn làm, đây là hướng duy nhất **tưởng như** có sẵn dữ liệu
học: mỗi giao dịch đã lưu có ghi chú + danh mục người dùng tự chốt là một mẫu có
nhãn. Tiền đề ấy **sai với dữ liệu hiện có** — xem số đo bên dưới.

### Ba quyết định người dùng chốt (2026-09-28)

| Câu hỏi | Chốt |
|---|---|
| Đoán được thì làm gì | **Gợi ý trên thẻ sẵn có**, người dùng vẫn bấm *Chọn* / *Bỏ qua* — **không** tự chọn sẵn |
| Ghi phản hồi không | **Có** — bảng cục bộ `GoiYDanhMucPhanHois`, schema **v25**, không đồng bộ (test quét 15 canh) |
| Thuật toán | **Naive Bayes đa thức nhị phân hoá** trên âm tiết bỏ dấu, làm trơn Laplace; học lại mỗi lần mở màn |

Mô hình đi **trước** bảng từ khoá; trả `null` (sổ mỏng, ghi chú lạ, hậu nghiệm dưới
0,6, hoà, cặp đang bị thôi gợi ý) thì rơi về bảng từ khoá như cũ. Dòng lý do đổi
theo nguồn: *"Bạn thường ghi “grab” cho Di chuyển (5/5 lần)."* với nguồn học. Hàm
thuần nằm ở `category/domain/phan_loai_ghi_chu.dart`, **không** ở `ai_edge/`: nó
đọc sổ giao dịch, thứ test quét 14 cấm trong `ai_edge/`.

### Chỗ dễ làm hỏng nhất

- **Ghi chú do máy sinh phải bị loại** (`laGhiChuMay`: khoản điều chỉnh số dư, mở
  sổ, nạp/rút mục tiêu kể cả tiền tố cũ, trả hoá đơn). Học chúng là dạy mô hình
  rằng *"thanh toán hóa đơn"* là một danh mục.
- **Xác suất tính trên MỌI danh mục đã học, `hopLe` chỉ lọc ứng viên**, kèm chốt
  *bằng chứng* (danh mục đoán phải có ít nhất một âm tiết của ghi chú). Chuẩn hoá
  chỉ trên danh mục chọn được thì danh mục vừa xoá đẩy danh mục còn lại lên 100 %
  cho một ghi chú không hề liên quan.
- **Bỏ dấu chỉ dùng ở đây**, không bao giờ cho quy tắc trùng tên (quy tắc 7
  `CLAUDE.md`): đoán sai chỉ tốn một cú chạm.
- **Thôi gợi ý có luật mở lại**: hai lần *Bỏ qua* cùng cặp (cụm, danh mục) thì
  thôi; ba giao dịch mới người dùng tự lưu cho đúng cặp ấy thì mở lại. Không có
  vế sau thì một lần bỏ qua lúc mới dùng app khoá cặp ấy vĩnh viễn.

### Số đo leave-one-out

Công cụ `test/tool/do_goi_y_danh_muc_test.dart` (chạy tay): với mỗi mẫu, học trên
mọi mẫu còn lại rồi đoán nó; **độ phủ** = phần trăm mẫu được gợi ý, **độ đúng** =
trong số được gợi ý, phần trăm trúng.

| CSDL (2026-09-29) | Mẫu | Học: phủ · đúng | Từ khoá: phủ · đúng |
|---|---|---|---|
| Máy ảo, tài khoản 10 (39 giao dịch) | **1** | 0 % · — | chưa ghi |
| PostgreSQL dev, mọi tài khoản (chỉ đọc) | **≤ 3** mỗi tài khoản | dưới ngưỡng 10 mẫu — im | — |
| Realme, tài khoản 10, **sau** nghiệm thu | 12 (**11 mẫu thử** + 1 ghi chú thật) | 91,7 % · 100 % | 50 % · **0 %** |

⭐ **Kết luận thật nằm ở hai hàng đầu: dữ liệu hiện có gần như không có ghi chú
người dùng tự gõ.** Giá trị của B1 phụ thuộc hẳn vào thói quen gõ ghi chú; không có
thói quen ấy thì B1 im và rơi về từ khoá — sai theo chiều an toàn. Hàng Realme do
chính lượt nghiệm thu gõ theo khuôn cố định (*grab …* → Di chuyển, *ca phe …* → Ăn
uống), nên nó **minh hoạ cơ chế**, không đo thói quen thật.

⚠️ **Công cụ đo từng sai** (sửa `9f407e6`): bản đầu lấy ứng viên từ khoá từ bảng
tra tên, tức **cả hàng mặc định toàn cục** — mà hàng toàn cục mang cùng từ khoá với
bản sao của tài khoản, nên hai danh mục cùng khớp một từ khoá cùng độ dài và bộ từ
khoá coi là **hoà**, im lặng. Bản ấy báo từ khoá *"phủ 0 %"* trên Realme trong khi
thẻ trên máy vẫn gợi ý. Nay ứng viên đi đúng đường của màn (`selectableChildrenAll`
+ `loadAllKeywords`). Chưa tài liệu nào từng ghi con số từ khoá của bản cũ.

### Nghiệm thu trên máy thật (Realme RMX2205, bản release, 2026-09-29)

- Gõ *"grab"*, chưa chọn danh mục → thẻ học *"Bạn thường ghi “grab” cho Di chuyển
  (5/5 lần)."*; *"ca phe"* → Ăn uống (5/5); hai ghi chú lạ → không thẻ nào. Bố cục
  không vỡ.
- *Bỏ qua* lần một, mở lại màn → thẻ học vẫn hiện; *Bỏ qua* lần hai, mở lại màn →
  thẻ học **thôi** hiện.
- Bảng phản hồi có **đúng ba hàng** khớp ba thao tác: hai `bo_qua` nguồn `hoc` (cụm
  *grab*, Di chuyển) và một `khac` nguồn `tu_khoa` (gợi ý Ăn uống, người dùng chọn Di
  chuyển). Đọc bằng cách cài **bản debug đè lên** — bản release ký bằng khoá debug
  (`build.gradle.kts`) nên `adb install -r` giữ nguyên dữ liệu và `run-as` chạy được
  — rồi cài lại bản release.
- Lỗi **có từ trước B1** lộ ra: thẻ gợi ý (cả nguồn từ khoá) vỡ bố cục với theme thật
  — nút *Chọn danh mục này* trần trong `Row`, bẫy 4.11 `ANALYTICS_FEATURE.md`; sửa
  `4ef4a5b`, có ca dựng bằng `AppTheme.lightTheme`.

### Một từ khoá mặc định gây nhầm — đã xin backend sửa seed

Seed backend (`src/Backend/prisma/seed.js:14–15`) gắn từ khoá `grab` cho **Ăn uống**
(ý là GrabFood) và `grabcar` cho **Di chuyển**. Bộ từ khoá khớp khi ghi chú
**chứa** từ khoá, nên mọi ghi chú *"grab …"* — cách gõ thường gặp cho một cuốc xe —
được gợi ý **Ăn uống**; trên Realme bộ từ khoá đúng **0/6** ghi chú *grab*. Tầng 1
phân loại của backend (`keyword.matcher.js`) cùng khớp chuỗi con nên cũng xếp nhầm,
trái với chính dữ liệu huấn luyện của nó (`training-data.csv:11`: *"grab di lam"* →
Di chuyển). B1 đi trước nên sửa được điều ấy khi người dùng đã có lịch sử. Nhưng
sau khi họ bấm *Bỏ qua* thẻ học hai lần, màn rơi về từ khoá và lại gợi ý Ăn uống —
ngược với mọi lần họ đã tự chốt Di chuyển.

Người dùng chốt ngày 2026-09-29, hai quyết định:

- **Xin backend sửa seed** — đơn `docs/superpowers/backend/DA-XONG/SEED_TU_KHOA_GRAB.md`
  (`grab` sang Di chuyển, `grabfood` cho Ăn uống). ⚠️ Chỉ tài khoản / máy **mới** nhận
  bộ mới: client gieo từ khoá kéo về chỉ khi danh mục chưa có từ khoá nào
  (`_gieoTuKhoaKhiTrong`), cố ý để thao tác xoá từ khoá của người dùng không hồi sinh.
  ✅ **Backend sửa ở `main` @ `a7c03b7`** (gộp 2026-10-01, `71234eb`): `prisma/seed.js` và
  `database/14_fix_grab_keyword_category.sql`, chỉ hai hàng `Is_default`. CSDL dev của máy
  này **đã áp** tệp 14 cùng ngày (người dùng cho phép đích danh): hai hàng khuôn nay là
  `an uong, food, grabfood` và `di chuyen, xang, grab, grabcar`; 12 bản sao của các tài
  khoản đã có **giữ nguyên** bộ cũ — với họ, lối sửa là dòng *đề xuất chuyển từ khoá*
  (mục 5f).
- **Giữ luật *Bỏ qua* như spec** — thôi gợi ý chỉ tắt đúng cặp (cụm, danh mục) của nguồn
  học; bộ từ khoá vẫn chạy như trước B1. Lỗi thật nằm ở từ khoá sai, và nó được xử lý ở
  gốc (seed), không bằng một luật chặn thứ hai ở màn.

### Nơi dùng thứ ba — ô Nhập nhanh (C2, 2026-09-30) — và một rủi ro học sai

Sau thẻ gợi ý và C1, B1 có nơi dùng thứ ba: ô **Nhập nhanh** màn Thêm giao dịch (spec
`2026-09-28-c2-nhap-giao-dich-bang-cau-design.md`, mục 9.41 `AI_EDGE_FEATURE.md`). Danh
mục đoán theo **tên nêu trong câu → B1 khi chắc → từ khoá → mô hình Gemma** — cùng thứ
tự thẻ gợi ý (B1 trước từ khoá), khớp từ khoá bằng chính `CategorySuggestionEngine`; câu
nói rõ chiều thì chỉ danh mục hợp chiều (`hopLeTheoChieu` của C1). Danh mục đến từ B1
**hoặc từ khoá** thì màn đặt `_choPhanXu` như thẻ gợi ý, nên lúc lưu vẫn ghi phản hồi
`chon` / `khac` đúng nguồn. Không đổi mã danh mục, không đổi schema.

Từ *đổi lần hai* (2026-09-30): mô hình **chỉ được gọi khi câu còn ô luật không điền
được**. Lượt thi công đầu (`05c6ce2`) để danh mục trống **không** gọi mô hình; người dùng
thấy *"mua 2 ly trà sữa 60k"* trống danh mục và sửa lại (`ed397be`): *"tôi muốn chỗ nào
không điền được thì sẽ cho AI vào để điền mà"* — nay tên / B1 / từ khoá đều im mà ghi chú
còn chữ thì **gọi mô hình** cho danh mục (~18 s). Dùng càng lâu, B1 và từ khoá (việc *đề
xuất thêm từ khoá*) càng lấp trước, ca phải chờ càng ít. Câu chuyển giữa hai ví (§2.9 spec
C2) không có danh mục.

Bước **từ khoá** thêm sau lượt đo Realme (*"đổ xăng"*, *"grab"* bị mô hình xếp Ăn uống).
Người dùng chốt việc riêng kế tiếp là **đề xuất thêm từ khoá từ thói quen** (một chữ lặp
với một danh mục mà chưa khai từ khoá → mời thêm; chữ đang là từ khoá danh mục khác —
*grab* ở Ăn uống — thì mời **chuyển**). ✅ Thi công 2026-09-30 — mục **5f**.

⚠️ **Vòng lặp học sai — người dùng chọn chưa làm gì thêm, theo dõi sau đo** (§8 câu 8
spec C2, 2026-09-30): với luật gọi mô hình mới, ca mô hình điền danh mục hiếm hơn hẳn. B1 học lại từ sổ
mỗi lần mở màn, gồm cả giao dịch nhập qua Nhập nhanh. Danh mục mô hình đoán sai mà người
dùng lưu luôn không sửa (*"xăng" → Ăn uống*) thành mẫu của B1; vì B1 đứng **trước** mô
hình, lần sau B1 nói lại đúng cái sai ấy và nó bị **khoá lại**. Giao dịch hôm nay không
lưu nguồn danh mục, nên muốn loại mẫu *"do AI điền, chưa xác nhận"* khỏi phép học thì phải
có chỗ đánh dấu nguồn trước.

---

## 5e. Thay đổi 8 — gắn danh mục hàng loạt (C1, 2026-09-29)

**Không phải sửa lỗi** — việc đầu tiên của **nhóm C**: nhóm mà người dùng duyệt đổi bất biến ④
thành *"không tool nào ghi **thẳng**"* (2026-09-28) — AI điền sẵn, người dùng bấm mới ghi. Thiết
kế: `docs/superpowers/specs/2026-09-28-c1-gan-danh-muc-hang-loat-design.md`. Không đổi schema,
không thêm trường đồng bộ.

### Nó làm gì

Thẻ *"Có N giao dịch chưa có danh mục"* trên Sổ giao dịch (dưới thẻ tổng, Stitch `a829606a…`)
mở màn *Gắn danh mục nhanh* (route con `/transactions/gan-danh-muc`, navigator gốc, Stitch
`5023f081…`). Mô hình **B1** — không phải mô hình riêng — đoán danh mục cho từng khoản, **tick
sẵn** dòng đoán được kèm câu lý do của B1; dòng không đoán được nằm ở nhóm *"CHƯA ĐOÁN ĐƯỢC"* với
chip nét đứt *"+ Chọn danh mục"*. Bấm *Áp dụng N* mới ghi, từng dòng qua
`TransactionRepository.updateTransaction`.

### Chỗ dễ làm hỏng nhất

- **Một định nghĩa của "khoản cần gắn"** — `xetGan` (`category/domain/gan_hang_loat.dart`):
  chưa xoá, trống danh mục, không phải `transfer`, và **không** do máy sinh (`laGhiChuMay` của
  B1). Thẻ đếm bằng `demChuaGan` trên **cùng** hàm, nên thẻ không bao giờ hứa N dòng mà màn hiện
  số khác. Khoản điều chỉnh số dư, mở sổ, nạp/rút mục tiêu, trả hoá đơn cố ý không có danh mục.
- **Lọc theo chiều tiền** — `hopLeTheoChieu`: khoản chi chỉ nhận danh mục `chi` / `vay_no`,
  khoản thu chỉ `thu` / `vay_no`. B1 học trên **cả ba** phân loại, nên thiếu bộ lọc là gắn được
  *"Lương"* cho một khoản chi (bản sai bỏ lọc làm ca ⭐ đỏ). Bảng chọn danh mục của màn là
  **bảng riêng** lọc bằng đúng hàm ấy — trang *Chọn danh mục* có sẵn mở đủ ba tab.
- **Ghi từ hàng TƯƠI** — `apDungGan` đọc lại hàng trước khi ghi: `updateTransaction` ghi đủ mọi
  cột của entity, nên ghi từ ảnh chụp lúc mở màn là đè mất một lần sửa vừa kéo về từ máy khác,
  rồi mốc `updatedAt` mới làm bản cũ ấy **thắng** trên server. Hàng đã có danh mục / đã xoá từ lúc
  mở màn thì từ chối (tính là "chưa lưu được").
- **Tôn trọng luật thôi gợi ý của B1** (`tatCap`) — và chính điều này làm lượt nghiệm thu bất
  ngờ: trên Realme cả ba khoản *"grab …"* thử **không** được đoán, vì lượt nghiệm thu B1 đã bấm
  *Bỏ qua* cặp (*grab*, Di chuyển) hai lần. Đúng thiết kế.
- **Phản hồi** vào bảng B1 (`nguon = hoc`) **chỉ** cho dòng có dự đoán **đang tick**: giữ dự
  đoán → `chon`, đổi → `khac`. Dòng bỏ tick không ghi — bỏ tick là *"chưa muốn sửa dòng này"*,
  không phải *"dự đoán sai"*.
- **Thẻ đọc stream** (`transactionDao.watchAll` → `demChuaGan`), toàn sổ, không theo kỳ: tự đổi
  sau lần áp dụng, lần pull và lần thêm giao dịch — không cần nạp lại sau `pop`.
- **Toast không nêu số** (*"Đã gắn danh mục"*, *"… — có giao dịch chưa lưu được"*): spec §4 viết
  kèm số N, nhưng nếp thông báo tạm thời của dự án là tối giản, và con số còn lại đã hiện trên thẻ
  ngay khi quay về.

### Đo trên dữ liệu thật

| CSDL (2026-09-29) | Giao dịch sống | Mẫu học B1 | `demChuaGan` |
|---|---|---|---|
| Realme, tài khoản 10 | 66 | 26 | **0** |

16 hàng trống danh mục của tài khoản ấy **đều do máy sinh** (15 nạp/rút mục tiêu, 1 điều chỉnh
số dư) và bị loại đúng — thẻ **không hiện** trên dữ liệu thật. Giao diện bắt buộc chọn danh mục
khi lưu, nên khoản trống danh mục chỉ đến từ server hoặc bản app cũ; giá trị của C1 nằm ở những
tài khoản ấy (17 hàng như thế trên PostgreSQL, đo 2026-09-10).

### Nghiệm thu trên máy thật (Realme RMX2205, 2026-09-29)

Người dùng duyệt **nhập 4 khoản chi thử qua giao diện rồi xoá**. Sau khi nhập, CSDL trên máy
được sửa **chỉ** `category_id = NULL` (giả lập khoản trống kéo từ server) và đổi ghi chú hai
khoản để có dòng đoán được: *gui xe may*, *ca phe sua da*, *grab ra ga*, *mua do linh tinh*.

- Thẻ *"Có 4 giao dịch chưa có danh mục"*, dòng chính xuống hai dòng ở 360 dp, không tràn.
- Màn: *gui xe may* → Di chuyển (*"…“gui xe” … (3/3 lần)"*) và *ca phe sua da* → Ăn uống
  (*"…(4/4 lần)"*) tick sẵn; *grab ra ga* (thôi gợi ý) và *mua do linh tinh* ở *CHƯA ĐOÁN ĐƯỢC*;
  *Áp dụng 2*. Chọn Di chuyển cho *grab ra ga* qua bảng chọn (chỉ danh mục chi + *Cho vay*, *Đi
  vay*) → tự tick, *Áp dụng 3*.
- Áp dụng → quay về, toast *"Đã gắn danh mục"*, thẻ *"Có 1 …"*, tổng chi không đổi. Trang Phân
  tích: *Chưa phân loại* **255.000 → 120.000 đ**, Ăn uống +38.000, Di chuyển +97.000.
- CSDL: ba hàng có danh mục, `pending`, `updated_at` mới; bảng phản hồi thêm **đúng 2** hàng
  `chon` (cụm *gui xe*, *ca phe*), **không** hàng nào cho *grab ra ga*.
- Mở lại với một dòng còn lại: câu *"Chưa đoán được danh mục nào…"*, không tiêu đề nhóm, *Áp dụng
  0* tắt.
- Dọn: xoá 4 khoản qua giao diện (tổng chi về −6.741.000 đ, thẻ biến mất), xoá 2 hàng phản hồi
  thử. Realme **không tới được backend** nên lần đẩy lên server chưa đo. Máy về bản release
  `d79b9b34…`.
- Một chỗ thô chỉ máy thật thấy: đường kẻ dưới tiêu đề bảng chọn là vạch **đen đậm** (`Divider`
  lấy màu theme) — sửa cùng ngày sang xám nhạt như Stitch.

---

## 5f. Thay đổi 9 — đề xuất thêm từ khoá từ thói quen (2026-09-30)

**Không phải sửa lỗi** — nhưng kéo theo sửa **một** lỗ hổng có sẵn (bên dưới). Người dùng đề xuất
sau lượt đo C2: *"khi người dùng không nhập từ khoá vào danh mục nhưng họ thường lặp đi lặp lại từ
khoá đó với 1 danh mục cụ thể thì sẽ đề xuất thêm từ khoá vào danh mục đó"*. Thiết kế:
`docs/superpowers/specs/2026-09-30-de-xuat-them-tu-khoa-design.md`; màn Stitch `8ca1338e…`. Không
đổi schema, không thêm trường đồng bộ.

### Vì sao

Từ khoá là lớp **rẻ nhất, tất định nhất** của thứ tự đoán danh mục (*tên → B1 → từ khoá → AI*):
không cần 10 mẫu như B1, không cần ~18 s như AI, và người dùng đọc hiểu được vì sao. Nhưng bộ từ
khoá **không học** — phải có người gõ vào trang *Từ khoá của tôi*, và hầu như không ai gõ. Đề xuất
biến thói quen ghi chú thành từ khoá **khi người dùng đồng ý** (bất biến ④ nhóm C: bấm mới ghi).

### Nó làm gì

Ở màn Thêm giao dịch (tạo mới **và** sửa), khi form có danh mục — bất kể nguồn — và ghi chú có một
cụm đi với danh mục ấy **≥ 3 lần, ≥ 60 %** (đúng ngưỡng B1, tính cả lần đang nhập), một dòng hiện
ngay dưới hàng Danh mục: *"Thêm ‘trà sữa’ làm từ khoá của Ăn uống? [Thêm] [✕]"*. Cụm đang là từ
khoá của **đúng một** danh mục khác → *"‘grab’ đang là từ khoá của Ăn uống — chuyển sang Di chuyển?
[Chuyển] [✕]"* (lối sửa trên máy cho từ khoá seed `grab` sai). Bấm là **ghi ngay**; dòng thành
*"Đã thêm …"* rồi **tự ẩn sau 2 giây** (người dùng chốt khi duyệt màn Stitch). ✕ ghi `bo_qua` và ẩn
cả lượt; lưu giao dịch mà không bấm gì thì **không** ghi gì.

### Chỗ dễ làm hỏng nhất

- **Một định nghĩa "thường ghi"** — hàm thuần `deXuatTuKhoa` (`category/domain/de_xuat_tu_khoa.dart`)
  dùng `kToiThieuMauDanhMuc` / `kNguongXacSuat` của B1 và mẫu `mauHocTu` của B1 (ghi chú máy sinh
  không đếm). Hàm **tự cộng lần đang nhập**; người gọi truyền mẫu **đã trừ** giao dịch đang sửa
  (`_mauDeXuat` của màn), nếu không đường sửa đếm một giao dịch hai lần.
- **Chọn cụm dài nhất TRƯỚC, rồi mới áp luật chặn** (đã phủ bởi từ khoá của danh mục · cặp đang tắt
  · xung đột ≥ 2). Áp trong vòng lặp là ✕ *"trà sữa"* xong nhận ngay đề xuất *"trà"* — bản sai ấy
  có ca test đỏ.
- **"Đã phủ" so CHUỖI CON bỏ dấu**, đúng như bộ so `CategorySuggestionEngine`: ghi chú đã chứa một
  từ khoá của danh mục → im (bộ so đã bắt được); cụm nằm trong một từ khoá đã có → im (bản rộng
  hơn). Cũng vì bộ so khớp chuỗi con mà cụm **dưới 3 chữ cái** và cụm **chỉ gồm chữ chung**
  (`kChuChung`: *ăn, mua, đi, tiền…*) không bao giờ được đề xuất — *"ăn"* khớp cả *"căn hộ"*.
  ⚠️ Vế *"cụm nằm trong một từ khoá đã có"* **chỉ áp khi không xung đột** (sửa 2026-10-01, người
  dùng chọn sau lượt đo Realme): seed cũ cho mọi tài khoản `grab` ở Ăn uống **và** `grabcar` ở Di
  chuyển, nên *grab* ⊂ *grabcar* từng chặn đúng ca *chuyển* mà tính năng sinh ra để sửa — trong
  khi *grabcar* không bắt được ghi chú *"grab đi làm"* (bộ so tìm từ khoá **trong** ghi chú). Ca
  ⭐ *chuyển* cũ xanh vì fixture không có `grabcar`; ca mới dựng đúng bộ từ khoá của tài khoản thật.
- **Đoạn có chữ số cắt dãy** (*"trà sữa 40k"* → *"trà sữa"*). Ca test đầu dùng mẫu *"35k"* khác số
  nên **xanh cả trên bản bỏ phép cắt** — ca đúng dùng mẫu cùng *"40k"*.
- **Luật tắt / mở là `tatCapTu`**, thêm tham số `nguon`; nguồn `de_xuat_tu_khoa` có tập tắt
  **riêng** — ✕ đề xuất không tắt thẻ gợi ý B1 của cùng cặp, và ngược lại.
- **Chuyển bỏ ở danh mục cũ TRƯỚC** rồi mới thêm vào danh mục mới: có một khoảnh khắc cụm thuộc hai
  danh mục thì bộ so coi là **hoà** và thôi đoán.
- **Nút `ElevatedButton` có `minimumSize` hữu hạn** (bẫy 4.11) — ca theme thật 360 × 640 canh.

### Lỗ hổng có sẵn đã sửa: `saveKeywords` không đẩy lên server

Từ khoá lên server **trong payload danh mục** (khoá `keyword`), không có thực thể riêng. Nhưng
`CategoryManagementRepository.saveKeywords` **không** đánh dấu danh mục `pending` và **không**
`scheduleSync()` — nên sửa từ khoá ở trang *Từ khoá của tôi* chỉ lên server khi danh mục bị sửa vì
lý do khác; đổi máy là mất. Nay nó đánh dấu danh mục riêng của tài khoản `pending` + `updatedAt`
mới (LWW) và gọi `scheduleSync()`; hàng mặc định toàn cục không đánh dấu (không bao giờ đẩy).

⚠️ **Giới hạn, không sửa ở đây:** danh sách từ khoá **rỗng** thì client không gửi khoá `keyword`,
và nhánh kéo về `_gieoTuKhoaKhiTrong` gieo lại từ khoá server khi danh mục trên máy không còn từ
khoá nào — nên **Chuyển** làm danh mục cũ rỗng thì từ khoá cũ **quay lại sau lượt pull kế**. Với
`grab` không xảy ra (Ăn uống còn từ khoá khác).

### Nghiệm thu trên máy thật

✅ **Đo 2026-10-01 trên Realme RMX2205** (360 dp, tài khoản 10, bản **debug** để đọc được SQLite
bằng `run-as`: `5ffc0123…` cho ca thêm và ✕, `259d273c…` sau bản sửa cho ca chuyển). Kịch bản ở
spec §6. Phần *đồng bộ lên PostgreSQL* **không đo** — bản debug trên máy thật trỏ `10.0.2.2`.

| Ca | Kỳ vọng | Thấy trên máy | |
|---|---|---|---|
| *trà sữa* + Ăn uống, lần 1 và 2 | chưa có dòng | không có dòng | ✅ |
| Lần 3 | dòng *"Thêm ‘trà sữa’ làm từ khoá của Ăn uống?"* | hiện, hai dòng chữ + nút, không tràn | ✅ |
| Bấm **Thêm** | ghi ngay | `category_keywords` có *trà sữa* (có dấu), Ăn uống thành `pending`, phản hồi `de_xuat_tu_khoa` / `chon` | ✅ |
| Khoản 4, Nhập nhanh *"trà sữa 40k"* | Ăn uống, không gọi AI | *"Đã điền: 40.000 đ · Ăn uống"*, *"Đọc bằng luật"*, dưới 2,5 s | ✅ ⚠️ |
| *gui xe* + Di chuyển → **✕** | ẩn cả lượt, ghi `bo_qua` | ẩn; gõ lại vẫn ẩn; phản hồi `de_xuat_tu_khoa` / `bo_qua` | ✅ |
| *grab* + Di chuyển | dòng *chuyển* | **không có dòng nào** (bản `5ffc0123…`) → sửa → hiện *"‘grab’ đang là từ khoá của Ăn uống — chuyển sang Di chuyển?"* | ✗ → ✅ |
| Bấm **Chuyển** | bỏ ở cũ, thêm ở mới | Ăn uống `an uong · food · trà sữa`; Di chuyển `di chuyen · grabcar · xang · grab`; phản hồi `chon` | ✅ |
| Dòng xác nhận tự ẩn sau 2 s | thấy rồi mất | *"Đã chuyển ‘grab’ sang Di chuyển"* có ở khung 0,5 s → 2,1 s sau cú chạm, mất ở khung 2,5 s | ✅ |
| Nhập nhanh *"grab 35k"* | Di chuyển | *"Đã điền: 35.000 đ · Di chuyển"*, *"Khớp với “grab” trong ghi chú."*, đọc bằng luật | ✅ |

Ba điều lượt đo cho thấy mà bộ test không:

- **Ca *chuyển* hỏng trên dữ liệu thật** vì `grabcar` — xem mục *Chỗ dễ làm hỏng nhất*. Sửa trong
  cùng lượt, hai ca test mới (một đỏ trên mã cũ).
- ⚠️ **Khoản 4 *trà sữa* ra Ăn uống là nhờ B1, không phải nhờ từ khoá vừa thêm**: dòng lý do là
  *"Bạn thường ghi “trà sữa” cho Ăn uống (3/3 lần)"*. Đề xuất từ khoá và B1 dùng **chung** ngưỡng
  3 lần / 60 % và B1 đứng trước từ khoá, nên ở chỗ B1 còn nói thì từ khoá học được không thêm gì.
  Giá trị riêng của nó lộ ở ca *grab*: cặp (*grab*, Di chuyển) đang bị B1 **thôi gợi ý** (hai lần
  bỏ qua ngày 29/09), nên trước lượt này *"grab 35k"* rơi xuống từ khoá seed và ra Ăn uống; sau
  **Chuyển** nó ra Di chuyển bằng từ khoá.
- **Dòng *"Đã thêm…"* chỉ sống 2 s** — một lệnh `screencap` gửi sau cú chạm là trễ (lần đo đầu
  không bắt được). Phải cho vòng chụp chạy nền **trên máy** trước khi chạm.

Dữ liệu sau lượt đo: ba khoản *trà sữa* 1.000 đ đã **xoá mềm qua giao diện**, ví Tiền mặt về
−6.097.000 đ; từ khoá *trà sữa* (Ăn uống) và *grab* (Di chuyển) **giữ** (người dùng chọn).

⚠️ Lượt đo còn lộ **G61** (`CLIENT_APP_KNOWN_GAPS.md`): người dùng **không còn chỗ nào để tự gõ
từ khoá** — trang *Từ khóa của tôi* chỉ mở được từ mục *Danh mục mặc định*, mục ấy trống từ khi
mỗi tài khoản dùng bản sao riêng (2026-09-07). Nên tới lượt đo này đề xuất là lối **duy nhất** thêm
từ khoá trên máy, và câu *"đảo được trong trang Từ khoá"* của spec chưa đúng. **Sửa ở mã cùng ngày**:
form Thêm / Chỉnh sửa danh mục nay có khối *Từ khóa nhận diện* (đúng màn Stitch `a5a6ecb3…`), nên
từ khoá thêm nhầm qua đề xuất **gỡ được** ở đó. ✅ Nghiệm thu Realme cùng ngày (thêm · gõ dở rồi
Lưu · gỡ, kiểm SQLite) — G61 đóng.

---

## 6. Những phương án đã cân nhắc rồi loại bỏ

Ghi lại để người sau không mất công đề xuất lại:

| Phương án | Vì sao loại |
|---|---|
| Giữ bản mặc định hiện **song song** với bản sao (2026-09-07) | Người dùng thấy 36 dòng với 18 cặp trùng tên, và quy tắc trùng tên chặn họ đổi tên bất kỳ bản nào |
| Đếm bản sao **theo tài khoản** thay vì theo từng danh mục (2026-09-07) | Tài khoản đã có sẵn danh mục riêng sẽ bị từ chối seed, trong khi bản mặc định của nó đã bị ẩn — nó còn lại đúng vài danh mục |
| Đếm bản sao **bỏ qua hàng đã xoá mềm** (2026-09-07) | Chính là `ensureMissing()` cũ, tức tái hiện nguyên vẹn G16 |
| Xoá hẳn 5 mục backend không có | Tái hiện lỗi 11.6 hàng loạt; mất cả hai mục "Khác" và một nửa nghiệp vụ vay nợ; giao dịch cũ không có đích để chuyển sang |
| Chuyển 5 mục tại chỗ, giữ id `cat_*` | `_resolveCategoryId` từ chối danh mục người dùng có id không phải UUID → giao dịch vẫn kẹt |
| Giữ mỗi nhóm là một không gian tên riêng | PostgreSQL không có `Idgroup` trong unique index nên vẫn chặn — client cho tạo rồi đẩy lên mới vỡ |
| Chỉ chuẩn hoá chữ thường, chưa cần NFC | Siết chặt về sau đắt hơn hẳn: dữ liệu đang tồn tại sẽ vi phạm và `CREATE UNIQUE INDEX` thất bại |
| Chặn tuyệt đối cả khi sửa | Người dùng có dữ liệu cũ sẽ không sửa nổi danh mục đó nữa, kể cả chỉ đổi icon |
| Sửa `getCategoryRows` cho dùng chung | Hàm đó khử trùng lặp theo tên — sửa nó sẽ đổi hành vi hiển thị ở nhiều nơi khác; tách truy vấn riêng an toàn hơn |
| Đổi tên 3 mục ngay, làm ID cố định sau | Hai lần migration trên máy người dùng cho cùng một vấn đề |
| *(B1)* Đoán được thì **tự chọn sẵn** danh mục | Đoán sai là lưu sai mà người dùng không để ý; gợi ý trên thẻ thì sai chỉ tốn một cú chạm |
| *(B1)* Khoanh vùng gợi ý theo đoạn **Chi/Thu đang chọn** (bản trình trong chat) | Màn cố ý không khoanh vùng: chiều tiền suy từ danh mục, không phải ngược lại — B1 theo nếp ấy |
| *(B1)* Chuẩn hoá xác suất **chỉ trên danh mục chọn được** | Danh mục vừa xoá đẩy danh mục còn lại lên 100 % cho một ghi chú không liên quan |
| *(B1)* Đếm đa thức **theo số lần lặp** | Ghi chú *"cafe cafe"* không phải hai lần bằng chứng — đếm theo số ghi chú chứa âm tiết |
| *(B1)* Học **cả ghi chú máy sinh** | Dạy mô hình rằng *"thanh toán hóa đơn"* là một danh mục |
| *(B1)* Câu lý do in **một âm tiết** | *"phê"* thay vì *"cà phê"* trông như máy lỗi — in cụm âm tiết luôn đi cùng nhau, ở dạng người dùng đã gõ |
| *(B1)* Thôi gợi ý **vĩnh viễn** sau hai lần bỏ qua | Một lần bỏ qua lúc mới dùng app khoá cặp ấy mãi, kể cả khi thói quen đã rõ |
| *(B1)* **Đồng bộ** mô hình hay bảng phản hồi giữa hai máy | Mỗi máy tự học từ sổ đã đồng bộ, nên kết quả gần như nhau |

---

## 7. Nguyên tắc rút ra

Bốn điều lặp lại trong suốt đợt thay đổi này, đáng nhớ cho lần sau:

1. **Nới lỏng về sau là miễn phí, siết chặt về sau thì phải dọn dữ liệu.** Quyết định mức chặt của một ràng buộc thì chọn chặt ngay từ đầu.
2. **Repoint trước, xoá sau.** Mọi lần đụng tới danh mục mà có dữ liệu trỏ vào nó. Đây là bài học của 11.6 và nó lặp lại nguyên vẹn ở thay đổi 3.
3. **Một phép so, một định nghĩa.** Ba biến thể so tên trong cùng dự án đã lệch nhau, và cái lệch nhất lại nằm đúng trên đường đồng bộ.
4. **Đo trước, kết luận sau.** Trong đợt này có hai lần test **xanh giả**: ký tự Unicode dạng tách dấu bị công cụ ghi file âm thầm gộp về NFC, nên hai chuỗi "khác nhau" hoá ra bằng nhau. Chỉ khi dựng fixture bằng escape code point và khẳng định cả độ dài chuỗi thì test mới thật sự canh được thứ nó nói là đang canh.

Cũng trong đợt này, ba lần test đỏ hoá ra là **fixture sai chứ không phải mã sai** — do đặt tên trùng danh mục seed sẵn, hoặc thiếu ví nên vỡ khoá ngoại. Đọc thông báo lỗi trước khi sửa mã.

B1 (2026-09-29) thêm một điều cùng họ với điều 3: **công cụ đo phải đi đúng đường của màn nó đo.** Phép đo leave-one-out tự dựng danh sách ứng viên từ khoá thay vì gọi `selectableChildrenAll` như màn, gom luôn hàng mặc định toàn cục, và báo bộ từ khoá *"phủ 0 %"* trong khi trên máy thẻ từ khoá vẫn hiện. Nó chỉ lộ ra vì con số trái với điều vừa thấy trên màn — nên khi một con số đo được trái với quan sát, nghi công cụ trước.

---

## 8. Cái gì còn phụ thuộc backend

> ✅ **Cả bốn tài liệu dưới đây đã đóng ngày 2026-09-07** và nay nằm ở
> `docs/superpowers/backend/DA-XONG/` (ghi chú *đóng bằng cách nào* ở mục 1 README
> của thư mục ấy): hai partial unique index `uq_category_owner_name` /
> `uq_category_default_name` thi hành đúng quy tắc của client và có `WHERE
> "Delete_at" IS NULL`, nên "xoá rồi tạo lại cùng tên" không còn bị từ chối; 13
> UUID cố định; lỗ hổng từ khoá bịt bằng 403; bảng nhóm bãi bỏ. Đoạn và bảng dưới
> là ảnh chụp ngày 2026-09-03. Đo lại 2026-09-11: vùng danh mục **không còn việc
> nào chờ backend** — màu danh mục là lỗi phía client (G24, mục 5b), ✅ đã sửa cùng ngày.

Quy tắc hiện **chỉ được client thi hành**. Admin-web và mọi đường ghi khác vẫn tạo được dữ liệu vi phạm, và trường hợp "xoá rồi tạo lại cùng tên" vẫn bị CSDL từ chối khi đẩy lên — **hỏng âm thầm**.

| Tài liệu trong `docs/superpowers/backend/` | Nội dung |
|---|---|
| `CATEGORY_NAME_UNIQUENESS.md` | Thay hai unique index; vế "người dùng với mặc định" cần trigger vì không viết được thành index |
| `CATEGORY_STABLE_IDS.md` | Đóng băng 13 UUID đang có |
| `CATEGORY_KEYWORD_SYNC.md` | Từ khoá phân loại không đồng bộ, kèm một lỗ hổng phân quyền |
| `CATEGORY_GROUP_MEMBERSHIP_SYNC.md` | Việc gán danh mục mặc định vào nhóm chỉ tồn tại trên một máy |

---

## 9. Kiểm chứng

```bash
cd src/Client-app
flutter test test/features/category/ test/core/category/ test/core/database/category_dao_test.dart
flutter analyze
```

Mức nền **tại thời điểm đóng đợt** (2026-09-03): **180/180 test pass**, **29 issue, không error**. Toàn dự án đã đi xa khỏi con số ấy — xem `CLAUDE.md` để biết mức nền hôm nay.

Riêng phần danh mục nay có **125 test** trên 10 file (đo lại 2026-09-08 bằng chính lệnh trên; con số cũ ghi ở đây là 74 test/5 file). Nhiều test ghi rõ trong `reason:` là nó đang canh chừng lỗi nào — vì lớp lỗi này không tự lộ ra khi dùng tay.
