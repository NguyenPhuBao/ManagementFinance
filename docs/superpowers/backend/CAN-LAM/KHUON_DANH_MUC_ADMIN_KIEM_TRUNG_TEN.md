# Mục 54 — Danh mục mặc định ở Admin-web: khôi phục / thêm không kiểm trùng tên (500); client nay theo thao tác admin

> **Client đặt 2026-10-27** (phiên 15). Người nhận: backend (NPBao). Mức: **TRUNG BÌNH** — admin nhận 500 thay vì một câu báo; dữ
> liệu không hỏng (giao tác bị CSDL từ chối nguyên vẹn).
>
> Client soát bằng đọc mã HEAD (`6b2b210b`; tệp backend cuối cùng đổi ở `36f1ea43`) + truy vấn **chỉ đọc** trên CSDL Supabase của
> `.env`. Chưa chạy thử trên Admin-web — kết luận rút từ mã và định nghĩa chỉ mục đo được; mỗi vế có cách kiểm lại.
>
> - **A, B** — xin sửa mã.
> - **C** — thông báo: client vừa thiết kế xong việc **theo thao tác admin** trên danh mục mặc định, và **hai điều client dựa vào**
>   (xin giữ nguyên). Không đòi sửa mã.

---

## Số đo (2026-10-27, Supabase `postgres`, `pg_indexes`)

```
uq_category_default_name  ON category (lower(regexp_replace(btrim(NORMALIZE("NameCategory", NFC)), '\s+', ' ', 'g')))
                          WHERE "Is_default" = true AND "Delete_at" IS NULL
uq_category_owner_name    ON category ("Create_by", lower(regexp_replace(btrim(NORMALIZE("NameCategory", NFC)), '\s+', ' ', 'g')))
                          WHERE "Is_default" = false AND "Delete_at" IS NULL
```

Cả hai khoá theo **tên chuẩn hoá — không có `Classify`** (định nghĩa từng nằm ở `database/)2_can_lam_all_migrations.sql:17`, `:44` — tệp đã bị xoá ở `850fe23b`, xem bản `6e6a783d`; nay không tệp `database/N` nào chứa định nghĩa đang chạy, chỉ `database/5` mang bản cũ `lower(NameCategory)`). Danh mục
hệ thống hiện có: 16 hàng sống, 0 hàng xoá mềm.

Lỗi vỡ chỉ mục là `PrismaClientKnownRequestError` mã `P2002`, không mang `statusCode` → `admin.controller.js` (`addCategory`,
`restoreCategory`: `error.statusCode || 500`) trả **500** với `error.message` là chuỗi nội bộ của Prisma.

## A — `restoreCategory` không kiểm trùng tên trước khi gỡ xoá

**Mã.** `admin.service.js` `restoreCategory` (`:525–542`) chỉ kiểm tồn tại + `is_default`, rồi `admin.repository.js`
`restoreCategory` (`:285–295`) ghi `delete_at: null`. Không có phép kiểm *"đã có danh mục hệ thống SỐNG cùng tên"* như
`updateCategory` (`:479–489`) đang làm.

**Kịch bản.** Admin xoá *"Trả nợ"* (Vay/no) → thêm *"Trả nợ"* loại **Chi** (`addCategory` chỉ tìm hàng đã xoá cùng **tên + loại**, không
thấy, nên tạo hàng mới) → bấm Khôi phục hàng Vay/no cũ → `UPDATE` vỡ `uq_category_default_name` → **500**. Cùng kết quả khi admin
đổi tên một danh mục khác thành tên của hàng đang xoá rồi khôi phục hàng ấy.

**Xin làm.**
1. Trước khi gỡ xoá: tìm danh mục hệ thống **sống** khác cùng tên → ném `statusCode: 409` với câu rõ ràng, vd *"Đã có danh mục hệ
   thống 'Trả nợ' đang hoạt động — đổi tên một trong hai trước khi khôi phục."*
2. Phép so phải **cùng chuẩn hoá với chỉ mục**: Prisma `mode: 'insensitive'` chỉ hạ chữ, không `NORMALIZE NFC`, không `btrim`, không
   gom khoảng trắng — tên *"Trả  nợ"* (hai dấu cách) hoặc dạng tổ hợp dấu vẫn lọt và vỡ chỉ mục. Hoặc so bằng `$queryRaw` với đúng
   biểu thức của chỉ mục, hoặc (tối thiểu) **bắt `P2002`** quanh lệnh ghi và đổi thành 409 cùng câu trên. Nên làm cả hai.

## B — `addCategory` kiểm theo (tên, loại) trong khi chỉ mục chỉ có tên

**Mã.** `addCategory` (`admin.service.js:365–446`): `existingDefault` tìm danh mục hệ thống sống cùng **tên VÀ `classify`**. Chỉ mục
không có `classify`.

**Kịch bản.** Đang có *"Trả nợ"* (Vay/no) sống. Admin thêm *"Trả nợ"* loại Chi → phép kiểm không thấy (khác loại) → `create` vỡ
`uq_category_default_name` → **500**. Cùng lớp: nhánh *"mở lại hàng đã xoá"* cũng chỉ khớp tên + loại.

**Xin làm.** Phép kiểm *"đã tồn tại"* bỏ vế `classify` (như `updateCategory`), cùng chuẩn hoá với chỉ mục, và bắt `P2002` → 409. Nhánh
mở lại hàng đã xoá giữ khớp tên + loại (đúng ý: khôi phục đúng khái niệm cũ).

**Kiểm lại A + B.** Ca test backend: (1) khôi phục khi đã có danh mục hệ thống sống cùng tên → 409 + câu, hàng vẫn xoá; (2) như (1)
với tên khác chỉ ở khoảng trắng / chữ hoa → 409; (3) thêm tên trùng khác loại → 409; (4) khôi phục khi không trùng → 200, `delete_at`
NULL, `server_update_at` mới. SQL kiểm sau mỗi ca:

```sql
SELECT "Idcategory", "NameCategory", "Classify", "Delete_at", "Server_update_at"
FROM category WHERE "Is_default" = true ORDER BY "NameCategory";
```

## C — Thông báo: client nay theo thao tác admin trên danh mục mặc định

Thiết kế: `docs/superpowers/specs/2026-10-27-danh-muc-mac-dinh-theo-thao-tac-admin-design.md` (đã duyệt từng phần; **chưa thi công**).
Mỗi tài khoản có **bản sao** riêng của bộ mặc định (spec 2026-09-07); từ khi thi công xong, sau lượt kéo về kế tiếp:

| Admin làm (Admin-web) | Máy người dùng |
|---|---|
| Xoá mềm danh mục hệ thống | Bản sao **ẩn** khỏi mọi danh sách chọn; giao dịch / ngân sách / hoá đơn cũ giữ tên và vẫn chạy. Chỉ áp cho hàng có `Delete_at` từ 2026-10-27 |
| Khôi phục | Bản sao hiện lại (bản người dùng tự xoá vẫn xoá) |
| Đổi tên · đổi biểu tượng · thêm từ khoá | Bản sao còn giữ giá trị cũ đổi theo, rồi đẩy lên `/sync/push` như một lượt sửa bình thường |
| Đổi loại (`Classify`) | **Không** theo — bản sao giữ loại cũ |
| Thêm | Như trước: tài khoản chưa có danh mục cùng tên nhận bản sao |

**Hai điều client dựa vào — xin giữ nguyên** (đổi là tính năng trên hỏng im lặng):

1. `/sync/pull` trả hàng danh mục hệ thống **kể cả đã xoá mềm**, kèm `delete_at` (`sync.repository.js` `getCategoriesByAccount`
   `:245` — không lọc `delete_at`). Lọc bỏ hàng đã xoá thì bản sao không bao giờ ẩn và khôi phục không bao giờ tới máy.
2. Xoá / khôi phục / sửa danh mục hệ thống **nâng `Server_update_at`** (repository ghi thẳng + trigger `set_server_update_at`,
   `database/20`). Thiếu thì máy đã kéo về không bao giờ thấy thay đổi.

**Đề nghị cho Admin-web (không chặn, tuỳ PO):** hộp xác nhận *Xoá* / *Đổi tên* danh mục hệ thống nói rõ hệ quả trên máy mọi người
dùng (bảng trên); cân nhắc cảnh báo hoặc khoá *đổi loại* với danh mục hệ thống vì máy người dùng không theo. ⚠️ Thử trên **CSDL
riêng** — tạo / xoá danh mục hệ thống trên Supabase dùng chung làm mọi tài khoản thật mọc / mất danh mục.
