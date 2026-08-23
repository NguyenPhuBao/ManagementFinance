# Backend — Tài liệu cần đọc để implement

> Folder này tập hợp toàn bộ tài liệu backend cần để thực hiện phần còn thiếu.
> Đọc theo thứ tự bên dưới.

---

## Thứ tự đọc & implement

### Bước 1 — Đọc tổng quan (BẮT BUỘC ĐỌC TRƯỚC)

| File | Mô tả |
|---|---|
| [PROGRESS-BACKEND.md](./PROGRESS-BACKEND.md) | Danh sách task B1→B7, checklist từng bước, thứ tự implement |
| [2026-08-10-backend-sync-spec.md](./2026-08-10-backend-sync-spec.md) | Spec đầy đủ: schema 5 bảng mới, API push/pull, request/response format, conflict resolution LWW |

### Bước 2 — Implement schema bổ sung (đọc sau khi có schema sync)

| File | Việc cần làm |
|---|---|
| [2026-08-22-backend-wallet-include-in-total.md](./2026-08-22-backend-wallet-include-in-total.md) | Thêm cột `include_in_total BOOLEAN` vào bảng `wallet` |
| [2026-08-23-backend-goal-wallet-id.md](./2026-08-23-backend-goal-wallet-id.md) | Thêm cột `wallet_id VARCHAR(36)` vào bảng `goal` |

### Bước 3 — Category (đọc sau khi sync API ổn định)

| File | Việc cần làm |
|---|---|
| [CATEGORY_MANAGEMENT_BACKEND_HANDOFF.md](./CATEGORY_MANAGEMENT_BACKEND_HANDOFF.md) | Thêm `parent_id`, `is_group`, `is_deleted`, `updated_at` vào `category`; thêm bảng `category_keywords` và `category_group_memberships` |

---

## Sơ đồ thứ tự implement

```
[Bước 1 — Đọc tổng quan]
  PROGRESS-BACKEND.md
  2026-08-10-backend-sync-spec.md
          |
          v
[Bước 2 — B1: Prisma Schema + Migration]
  Thêm 5 bảng: wallet, transaction, budget, bill, goal
  + wallet.include_in_total
  + goal.wallet_id
  → npx prisma migrate dev --name add_sync_tables
          |
          v
[Bước 3 — B2+B4: POST /sync/push + Conflict Resolution]
          |
          v
[Bước 4 — B3: GET /sync/pull]
          |
          v
[Bước 5 — Category sync (fence riêng, deploy sau)]
  CATEGORY_MANAGEMENT_BACKEND_HANDOFF.md
```

---

## Ghi chú

- Tất cả bảng offline-first dùng `VARCHAR(36) UUID` làm PK — client tự sinh, không dùng SERIAL.
- File gốc vẫn còn ở vị trí ban đầu trong `docs/superpowers/plans/`, `docs/superpowers/specs/`, `docs/category/`.
- Folder này là bản copy để backend team tiện tham khảo tập trung.
