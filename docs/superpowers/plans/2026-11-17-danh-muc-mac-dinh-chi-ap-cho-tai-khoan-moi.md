# Kế hoạch: Danh mục mặc định chỉ áp cho tài khoản mới (2026-11-17)

Trạng thái: **chờ Chủ dự án duyệt**. Phạm vi: `src/Backend`, `src/Admin-web`, tài liệu. Không sửa `src/Client-app`.

## 1. Mục tiêu

1. Tài khoản người dùng mới được tạo kèm một bản danh mục riêng, chép từ bộ danh mục mặc định đang hoạt động (`create_by` = id tài khoản đó).
2. Admin-web thêm / sửa / xoá danh mục mặc định chỉ đổi khuôn trong CSDL. Thay đổi chỉ áp cho tài khoản tạo **sau** lúc đổi. Danh mục của tài khoản đã có không bị tác động.

## 2. Quyết định đã chốt (Chủ dự án, 2026-11-17)

| # | Quyết định |
|---|---|
| Q1 | Ngừng gửi hàng khuôn (`is_default = true`) trong `/sync/pull` **ngay**, không chờ Client-app. |
| Q2 | Viết script bù cho tài khoản chưa có danh mục riêng; chạy CSDL thử trước, Supabase chỉ khi Chủ dự án xác nhận đích danh. |

## 3. Hiện trạng (đã đối chiếu mã, 2026-11-17)

- Backend **không** tạo danh mục lúc đăng ký (`auth.repository.createAccountWithUser`). Bản riêng do Client-app tạo (`DefaultCategorySeeder`, chạy sau **mỗi** lần kéo).
- `/sync/pull` trả khuôn cho mọi tài khoản (`sync.repository.getCategoriesByAccount`, điều kiện `{ is_default: true }`).
- Admin sửa danh mục ⇒ `emitCategoryUpdated` phát `sync.completed` tới **mọi** socket ⇒ máy kéo về ngay.
- Client-app có 3 cơ chế đưa thay đổi khuôn vào tài khoản cũ (spec client 2026-10-27): lan truyền khuôn (`LanTruyenKhuon`), tạo bản sao cho khuôn mới sau mỗi lần kéo, ẩn bản sao khi khuôn bị xoá (`dangAnTheoKhuon`).
- Mobile **hiển thị bản đã cá nhân hoá**: danh sách chọn chỉ lấy hàng `idaccount` của tài khoản (`category_dao._hangKemKhuon`); khuôn chỉ dùng để so.
- Khuôn trong `seed.js` đều `is_group = false`. Chỉ mục `uq_category_owner_name` khoá (Create_by, tên chuẩn hoá) cho hàng `Is_default = false`, chưa xoá, không thuộc nhà.

## 4. Thiết kế

### B1. Hàm tạo bản riêng (dùng chung cho đăng ký và script bù)

Tệp mới `src/Backend/modules/account/personal-categories.js`:
- `buildPersonalCopies(templates, idaccount)`: hàm thuần. Lọc khuôn còn sống, không nhóm, không thuộc nhà; khử trùng theo tên chuẩn hoá giống chỉ mục (NFC, trim, gộp khoảng trắng, chữ thường), giữ khuôn tạo sớm nhất; mỗi bản: UUID mới, `create_by = idaccount`, `is_default = false`, `is_group = false`, `idgroup = null`, chép `name_category`, `classify`, `keyword`, `icon`, `color`.
- `seedPersonalCategories(tx, idaccount)`: đọc khuôn bằng `tx`, gọi hàm trên, `createMany`. Trả số bản đã tạo.

### B2. Đăng ký

Mọi loại tài khoản (Chủ dự án chốt 2026-11-17): `auth.repository.createAccountWithUser` (người dùng đăng ký) và `admin.repository` (tạo tài khoản quản trị) gọi `seedPersonalCategories(tx, idaccount)` trong **cùng giao tác** tạo tài khoản (lỗi thì không tạo tài khoản).

Tương thích client: `DefaultCategorySeeder` so theo tên (kể cả hàng xoá mềm) nên không đẻ bản trùng; sau Q1 client không còn nhận khuôn nên bộ tạo bản sao tự dừng (`khuon.isEmpty ⇒ return 0`).

### B3. Ngừng gửi khuôn trong `/sync/pull` (Q1)

`sync.repository.getCategoriesByAccount`: bỏ điều kiện `{ is_default: true }`. `countCategory` bỏ theo. Giữ nguyên: chặn client sửa / xoá khuôn (`FORBIDDEN_SYSTEM_DEFAULT`), `/sync/default-categories` (client không gọi), phân loại AI phía server (đọc khuôn trực tiếp).

### B4. Ngừng báo mọi máy khi Admin sửa danh mục

`core/socket.emitCategoryUpdated`: bỏ `io.emit('sync.completed', …)`, giữ `admin.category_updated` tới `admin_room`.

### B5. Admin-web

`locales/vi.js`, `locales/en.js` → `categories.syncModal.description`: "Thay đổi chỉ áp dụng cho tài khoản tạo sau khi lưu. Danh mục của tài khoản hiện có không đổi. Nhập mã PIN để xác nhận." Soát `categories.subtitle` cùng ý.

### B6. Script bù `src/Backend/scripts/bu_danh_muc_ca_nhan.js`

- Mặc định `--dry-run` (chỉ đếm, không ghi); `--apply` mới ghi. Luỹ đẳng.
- (a) Mọi tài khoản chưa xoá **chưa từng** có danh mục riêng (`create_by` = id, không thuộc nhà, `is_default = false`, **kể cả hàng xoá mềm**) ⇒ `seedPersonalCategories`.
- (b) Dời tham chiếu: `transaction` / `budget` / `bill` của tài khoản người dùng đang trỏ vào khuôn ⇒ trỏ sang bản riêng cùng tên chuẩn hoá của chính tài khoản đó. Không có bản cùng tên thì chỉ báo, không đoán.
- In báo cáo: số tài khoản được bù, số tham chiếu dời được / không dời được. Không in tên, email.
- Lý do (b): sau Q1, máy cài mới không còn khuôn ⇒ dữ liệu còn trỏ vào khuôn sẽ thành mồ côi.

### B7. Đơn cho Client-app và tài liệu

- `docs/superpowers/client-app/CAN-LAM/DANH_MUC_MAC_DINH_CHI_CHO_TAI_KHOAN_MOI.md`: gỡ `LanTruyenKhuon`; gỡ luật ẩn theo khuôn và mục "Đang tạm ngừng"; bộ tạo bản sao không chạy theo khuôn nữa (server đã tạo khi đăng ký); khuôn không còn về qua `/sync/pull`.
- `SYNC_DOCUMENTATION.md` mục *Trao đổi*: ghi việc `/sync/pull` không còn trả khuôn.
- `docs/progress/Backend.md`, đặc tả danh mục của Admin-web (`docs/Admin-web/`): cập nhật hành vi.

## 5. Kiểm thử (viết trước, phải ĐỎ rồi mới code)

| Tầng | Ca | Tệp |
|---|---|---|
| 1 | `buildPersonalCopies`: khử trùng theo tên chuẩn hoá, bỏ khuôn đã xoá / nhóm / của nhà, đúng `create_by`, `is_default = false`, UUID khác khuôn | `tests/unit/personal-categories.test.js` (mới) |
| 2 | Đăng ký ⇒ tài khoản có đúng N danh mục riêng, chạy trên CSDL thử | `tests/unit/personal-categories.test.js` |
| 2 | `/sync/pull` không còn hàng `is_default` | test sync hiện có / mới |
| 2 | Admin thêm / sửa / xoá danh mục ⇒ **không** phát `sync.completed`; vẫn phát `admin.category_updated` | `tests/unit/category.realtime.client.test.js` (sửa theo nghiệp vụ mới) |
| 2 | Tài khoản có sẵn: sau khi Admin đổi tên / xoá khuôn, danh mục riêng giữ nguyên | test mới |
| 2 | Script bù: dry-run không ghi; apply tạo bản cho tài khoản thiếu, không đụng tài khoản đã có, dời tham chiếu, chạy lần 2 không đổi gì | test mới |
| 1 | Admin-web: hộp xác nhận hiện câu mới | `src/Admin-web/src/tests/` |

Chạy: `npm test` (Backend, chỉ qua npm, CSDL thử), `npm test` + lint (Admin-web).

## 6. Rủi ro

| Rủi ro | Xử lý |
|---|---|
| Máy cài mới của tài khoản cũ có dữ liệu trỏ vào khuôn | B6(b) dời tham chiếu trước khi bật Q1 trên Supabase |
| Bản sao đang "tạm ngừng" ở máy cũ sẽ hiện lại trên máy cài mới (máy mới không có khuôn để so) | Đúng nghiệp vụ mới (danh mục riêng không theo khuôn); client gỡ luật ẩn ở B7 |
| Máy cũ còn khuôn cũ trong CSDL cục bộ | Khuôn cũ đứng yên, không còn thay đổi nào về; client dọn ở B7 |
| `data.export` test có thể đang kỳ vọng khuôn | FullStack báo lại nếu test ấy đỏ vì Q1, không tự sửa |

Phương án lùi: revert commit B3 / B4 (khuôn lại về qua pull).

## 7. Thứ tự và người làm

1. B1 → B2 → B3 → B4 → B5 → B6 → B7, mỗi bước test đỏ → xanh, commit nhỏ (chỉ khi Chủ dự án ra lệnh commit).
2. Hiện thực: **Lead FullStack (Sonnet 5.5, effort High)**. Nghiệm thu: Lead PO (Opus 5.5, Medium).
3. Script bù chạy trên Supabase: **chỉ khi Chủ dự án xác nhận đích danh**, chạy `--dry-run` trước và báo số liệu.
