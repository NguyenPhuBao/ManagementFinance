# Category management backend handoff

> **Documentation only.** This document defines the backend contract needed for
> future category-management sync. The Client-app remains local-only for user
> category groups and keyword settings until the backend deploys this contract.
> Until then, the client must not add these fields or keyword records to the
> existing category sync payload.

## Category records

Keep the existing stable category identifier as `id`/`uuid`. A backend category
record must additionally support:

| Field | Meaning |
| --- | --- |
| `parent_id` | Nullable ID of a user-owned group. `null` means an ungrouped child. |
| `is_group` | `true` for a group header; groups have no `parent_id` and are never transaction-selectable. |
| `is_deleted` | Soft-delete marker. Deleted rows must be retained for pull/tombstone propagation and excluded from visible trees and pickers. |
| `updated_at` | Server-comparable modification timestamp used by the metadata conflict rule below. |

Recommended database constraints and indexes:

- Foreign-key `parent_id` to the category ID when the storage model permits it;
  reject a parent from another account, a deleted/default parent, a non-group,
  or a nested group.
- A visible-tree index such as `(owner_account_id, classify, is_deleted,
  is_group, parent_id)`.
- A tombstone/pull index such as `(owner_account_id, updated_at)` (including
  soft-deleted rows).
- A uniqueness constraint for personal groups on normalized name within
  `(owner_account_id, classify)`, and for personal children within
  `(owner_account_id, classify, parent_id)`. The nullable parent scope must be
  handled deliberately so two ungrouped normalized names conflict.

The server must soft-delete a group without deleting its children: in the same
transaction, clear each affected child `parent_id`, then mark only the group
deleted. Deleting a child must not affect historical transactions.

## Ownership and keyword records

System/default categories are globally owned (`owner_account_id`/current client
`idaccount` equals `0`) and are read-only as category metadata. They may be
shown to every account, but no account may rename, reparent, or delete them.
Their per-account group placement is represented only by the separate
membership record below; it must never mutate the global category row.

## Deferred default-category group membership contract

To place a global default category under a personal group, the backend needs a
separate, account-scoped membership resource. This is intentionally not the
category record's `parent_id`.

```json
{
  "id": "cgm_8a2e",
  "account_id": 42,
  "group_id": "grp_home",
  "category_id": "cat_food",
  "updated_at": "2026-08-21T09:30:00.000Z"
}
```

Required validation and storage rules:

- `group_id` must reference an active, personal, same-account group; the group
  and default category must have the same `classify`.
- `category_id` must reference an active global default category. It remains
  read-only category metadata and a transaction-picker leaf.
- Enforce uniqueness on `(account_id, category_id)`, so a default category can
  belong to at most one personal group for that account.
- Index memberships by `(account_id, group_id)` for tree assembly, and retain a
  lookup on `(account_id, category_id)` for uniqueness and reassignment.

### Current local-only fence

The Client-app currently stores default-category memberships only in SQLite.
They are excluded from sync payloads and must be preserved when category data
is pulled. Do not add this resource to backend/admin/sync flows until the
contract above, authorization, indexes, tombstones, and conflict rules are
deployed together; removing this fence requires a separately reviewed client
migration.

Keywords are separate, account-scoped records, not a shared field on a default
category. A record contains at least:

```json
{
  "id": "kw_8a2e",
  "account_id": 42,
  "category_id": "cat_food",
  "keyword": "GrabFood",
  "normalized_keyword": "grabfood",
  "is_deleted": false,
  "updated_at": "2026-08-21T09:30:00.000Z"
}
```

The category may be either a global default or a category owned by that same
account. Enforce one active keyword per `(account_id, category_id,
normalized_keyword)`, with an index/unique constraint on those columns. Client
and server normalization is trim + lowercase + collapse internal whitespace.

## Push payloads

Use entity-specific operations; these examples use `upsert` and `delete`.
The client sends local groups/keywords only after this backend contract is
deployed and the local-only fence is explicitly removed.

### Group upsert

```json
{
  "entity": "category",
  "operation": "upsert",
  "payload": {
    "id": "grp_home",
    "owner_account_id": 42,
    "name": "Nhà cửa",
    "classify": "chi",
    "parent_id": null,
    "is_group": true,
    "is_default": false,
    "is_deleted": false,
    "updated_at": "2026-08-21T09:20:00.000Z"
  }
}
```

### Child upsert

```json
{
  "entity": "category",
  "operation": "upsert",
  "payload": {
    "id": "cat_rent",
    "owner_account_id": 42,
    "name": "Tiền nhà",
    "classify": "chi",
    "parent_id": "grp_home",
    "is_group": false,
    "is_default": false,
    "is_deleted": false,
    "updated_at": "2026-08-21T09:21:00.000Z"
  }
}
```

### Keyword upsert

```json
{
  "entity": "category_keyword",
  "operation": "upsert",
  "payload": {
    "id": "kw_8a2e",
    "account_id": 42,
    "category_id": "cat_food",
    "keyword": "GrabFood",
    "normalized_keyword": "grabfood",
    "is_deleted": false,
    "updated_at": "2026-08-21T09:30:00.000Z"
  }
}
```

### Deletion tombstone

```json
{
  "entity": "category",
  "operation": "delete",
  "payload": {
    "id": "cat_rent",
    "owner_account_id": 42,
    "is_deleted": true,
    "updated_at": "2026-08-21T09:40:00.000Z"
  }
}
```

## Pull payloads

The server may return the same canonical resource shapes in a `changes` list;
it must include tombstones rather than filtering them out. For example:

```json
{
  "cursor": "2026-08-21T09:45:00.000Z",
  "changes": [
    {
      "entity": "category",
      "id": "grp_home",
      "owner_account_id": 42,
      "name": "Nhà cửa",
      "classify": "chi",
      "parent_id": null,
      "is_group": true,
      "is_default": false,
      "is_deleted": false,
      "updated_at": "2026-08-21T09:20:00.000Z"
    },
    {
      "entity": "category",
      "id": "cat_rent",
      "owner_account_id": 42,
      "name": "Tiền nhà",
      "classify": "chi",
      "parent_id": "grp_home",
      "is_group": false,
      "is_default": false,
      "is_deleted": false,
      "updated_at": "2026-08-21T09:21:00.000Z"
    },
    {
      "entity": "category_keyword",
      "id": "kw_8a2e",
      "account_id": 42,
      "category_id": "cat_food",
      "keyword": "GrabFood",
      "normalized_keyword": "grabfood",
      "is_deleted": false,
      "updated_at": "2026-08-21T09:30:00.000Z"
    },
    {
      "entity": "category",
      "id": "cat_rent",
      "owner_account_id": 42,
      "is_deleted": true,
      "updated_at": "2026-08-21T09:40:00.000Z"
    }
  ]
}
```

## Conflict policy

Apply last-write-wins (LWW) by `updated_at` to category metadata, including
`name`, `classify`, `parent_id`, `is_group`, and `is_deleted`. The server should
break equal timestamps deterministically (for example, by server revision then
resource ID) and return the canonical row.

Keyword uniqueness is a separate normalized-key conflict policy, not merely
LWW metadata. For the same `(account_id, category_id, normalized_keyword)`,
there can be only one active record. Concurrent creates that normalize to the
same value must converge to one canonical record; the server returns that record
and the client removes/merges the losing duplicate. A keyword tombstone wins
only according to its own newer `updated_at`; it must not delete another
account's keyword record or a different normalized keyword.

## Current migration fence

The Client-app’s SQLite schema currently has local `parent_id`, `is_group`,
`is_local_only`, and `category_keywords` support. Its migration to schema v3
creates those fields and the keyword table, while the sync layer deliberately
excludes `is_local_only == true` category rows and preserves local-only rows on
pull. This is a compatibility fence, not a partial backend protocol.

Backend deployment must land the schema, ownership/authorization checks,
indexes, push/pull resources, and conflict handling together. Only after that
deployment and a separately reviewed client migration may the fence be removed
and local category groups/keywords be synchronized.
