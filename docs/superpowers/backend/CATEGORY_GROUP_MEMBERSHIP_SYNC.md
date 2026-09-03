# Đồng bộ việc gán danh mục MẶC ĐỊNH vào nhóm

**Người nhận:** đội Backend
**Trạng thái:** cần backend bổ sung, phía Client-app **không thể tự làm**.
**Mức độ:** không gây lỗi, nhưng một phần dữ liệu người dùng chỉ tồn tại trên đúng một máy.

---

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

### Lựa chọn B — "Nhân bản" danh mục mặc định thành danh mục riêng

Khi người dùng gán một danh mục mặc định vào nhóm, tạo một bản sao thuộc về họ
(`Create_by = idaccount`, `is_default = false`, `Idgroup` trỏ tới nhóm).

**Không khuyến nghị:** làm phình bảng `category`, phá vỡ ràng buộc
`uq_category_owner_name_classify` khi tên trùng, và mọi giao dịch cũ vẫn trỏ tới
`Idcategory` gốc nên báo cáo sẽ tách làm đôi.

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
