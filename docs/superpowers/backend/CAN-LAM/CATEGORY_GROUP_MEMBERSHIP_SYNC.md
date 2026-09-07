# [ĐÃ BÃI BỎ] Đồng bộ việc gán danh mục MẶC ĐỊNH vào nhóm

> [!CAUTION]
> **TÀI LIỆU NÀY ĐÃ BỊ BÃI BỎ HOÀN TOÀN (DEPRECATED & OBSOLETE - 2026-09-07)**
> Theo quyết định của Product Owner (PO) và Nguyên tắc Kiến trúc Dự án:
> 1. Toàn dự án thống nhất áp dụng **Mô hình Danh mục Template & Cloned**: Danh mục hệ thống (`is_default = true`) chỉ đóng vai trò là khung mẫu chuẩn. Mỗi người dùng sở hữu bộ danh mục cá nhân độc lập (`is_default = false`, `create_by = idaccount`).
> 2. Phân nhóm danh mục được xử lý **trực tiếp qua quan hệ tự tham chiếu** `category.idgroup` (với `is_group = true`), hoàn toàn không sử dụng bảng trung gian.
> 3. Bảng `category_group_membership` là đề xuất sai lệch trước đây của thành viên làm Client-app. **Bảng này đã bị xóa hoàn toàn khỏi PostgreSQL / Supabase (`DROP TABLE IF EXISTS "category_group_membership" CASCADE;`), gỡ bỏ khỏi Prisma Schema và Backend Sync Engine.**
> 4. Phía Client-app không được phép tạo bảng hay đẩy entity này lên server nữa.

**Người nhận:** đội Backend & đội Client-app
**Trạng thái:** ❌ **ĐÃ BÃI BỎ VÀ XÓA BỎ HOÀN TOÀN**

## 1. Vấn đề

Từ phiên 2026-09-02, cấu trúc nhóm danh mục **của người dùng** đã đồng bộ được hai chiều
qua `Is_group` / `Idgroup` (xem mục 11.7 của `docs/PROJECT_CONTEXT.md`).

Nhưng còn một loại quan hệ **chưa** đồng bộ: việc người dùng gán một **danh mục mặc định**
(danh mục hệ thống, `is_default = true`, `Create_by = 1`) vào một nhóm của riêng họ.

Client lưu quan hệ này ở bảng cục bộ `CategoryGroupMemberships`:

```
CategoryGroupMemberships(id, idaccount, groupId, categoryId, createdAt, updatedAt)
UNIQUE (idaccount, categoryId)
```

Nó **không** có `SyncEntityType` tương ứng — `sync_models.dart` chỉ có
`wallet, transaction, category, budget, bill, goal`. Nên dữ liệu này chưa bao giờ rời khỏi máy.

## 2. Vì sao client không tự giải quyết được

Đã kiểm chứng bằng cách đọc mã nguồn backend ngày 2026-09-03:

| Nơi | Nội dung |
|---|---|
| `sync.service.js` — `UPSERT_MAP` | chỉ có 6 entity: wallet, transaction, budget, bill, goal, category |
| `sync.service.js` — `ENTITY_PRIORITY` | cùng 6 entity đó |
| `sync.service.js` | entity lạ → `results[i] = { status: 'error', message: 'Unknown entity: ...' }` |
| `prisma/schema.prisma` | **không có** bảng membership nào; quan hệ nhóm chỉ là cây tự tham chiếu `category.idgroup` |

Nếu client tự thêm một `SyncEntityType` mới, mọi thao tác sẽ trả `error` và bản ghi kẹt lại
vĩnh viễn — tệ hơn hiện trạng.

**Vì sao không dùng thẳng `category.idgroup`:** danh mục mặc định là dữ liệu **dùng chung**
(`Create_by = 1`). Ghi `Idgroup` lên hàng đó sẽ đổi cách phân nhóm cho **mọi người dùng**,
không phải riêng người vừa thao tác.

## 3. Hai lựa chọn

### Lựa chọn A — Bảng quan hệ riêng · **khuyến nghị**

```sql
CREATE TABLE "category_group_membership" (
  "Idmembership" VARCHAR(36) PRIMARY KEY,
  "Idaccount"    INT         NOT NULL,
  "Idcategory"   VARCHAR(36) NOT NULL,   -- danh mục mặc định được gán
  "Idgroup"      VARCHAR(36) NOT NULL,   -- nhóm của chính người dùng đó
  "Update_at"    TIMESTAMP   NOT NULL,
  "Delete_at"    TIMESTAMP   NULL,
  CONSTRAINT "fk_membership_account"  FOREIGN KEY ("Idaccount")  REFERENCES "account"("Idaccount"),
  CONSTRAINT "fk_membership_category" FOREIGN KEY ("Idcategory") REFERENCES "category"("Idcategory"),
  CONSTRAINT "fk_membership_group"    FOREIGN KEY ("Idgroup")    REFERENCES "category"("Idcategory"),
  CONSTRAINT "uq_membership_owner_category" UNIQUE ("Idaccount", "Idcategory")
);
```

Rồi bổ sung phía sync:

1. `UPSERT_MAP`: `categoryGroupMembership: 'upsertCategoryGroupMembership'`
2. `ENTITY_PRIORITY`: đặt **sau** `category` (ví dụ `15`) — nó tham chiếu tới hai hàng category,
   đẩy trước sẽ vỡ khoá ngoại.
3. `PULL_MAP` + `getCategoryGroupMembershipsByAccount(idaccount, since)`
4. `mapEntityFields()`: `categoryId → idcategory`, `groupId → idgroup`, `idaccount → idaccount`
5. Kiểm tra quyền sở hữu như các entity khác: `payload.idaccount === token.idaccount`

Giữ nguyên mô hình dữ liệu hiện có, không đụng tới danh mục dùng chung.

> **Cập nhật 2026-09-07:** Backend đã hoàn thành tạo bảng `category_group_membership` và hỗ trợ đầy đủ Sync Push/Pull/SoftDelete với `ENTITY_PRIORITY: 15`. Đồng thời, theo mô hình Template & Cloned được PO duyệt, người dùng có bộ danh mục cá nhân riêng độc lập để quản lý và phân nhóm.

## 4. Phía Client-app cần làm gì sau khi backend xong

1. Thêm `categoryGroupMembership` vào `SyncEntityType` (`sync_models.dart`).
2. Thêm nhánh gom/đẩy trong `_collectPendingOps` — xếp **sau** category trong batch.
3. Thêm nhánh đọc trong `_pullFromBackend`, dùng `insertAllOnConflictUpdate`
   (**không** `insertOrReplace` — xem mục 11.8 của `PROJECT_CONTEXT.md`).
4. **Cập nhật `test/core/sync/sync_payload_contract_test.dart` cùng lúc.** Tên trường đi qua ba
   nơi định nghĩa độc lập và một tên sai **không gây lỗi, chỉ lặng lẽ bị bỏ qua**.

## 5. Ghi chú

Toàn bộ khảo sát chỉ **đọc** mã nguồn backend. **Không có dòng mã backend nào bị thay đổi.**
Mọi thay đổi mã nguồn của phiên 2026-09-03 đều nằm trong `src/Client-app/`.

Xem thêm `CATEGORY_KEYWORD_SYNC.md` (cùng thư mục) — cùng một khuôn mẫu: một quan hệ thuộc
về từng người dùng lại được gắn vào hàng danh mục dùng chung.
