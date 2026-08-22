# Category management — Client-app implementation status

**Updated:** 2026-08-22  
**Scope:** Client-app only; Backend and Admin-web were not modified.

## Delivered behavior

- Users create personal parent groups and personal child categories.
- New personal children and unassigned default categories are displayed in
  `Chưa nhóm`.
- A default category is globally shared and stays read-only for name, type,
  icon, colour, and deletion. A user may configure personal keywords and place
  it in one of their personal groups.
- Default placement is stored locally per account. Moving a default from group
  A to group B is atomic and does not affect another account or mutate the
  shared category record.
- Deleting a group returns its personal children and default memberships to
  `Chưa nhóm`; transaction history remains unchanged.
- The transaction picker selects leaves only. Group headers never become a
  selected transaction category.
- Keyword suggestions are informational until the user taps `Chọn danh mục
  này`; stale async suggestions are discarded after a transaction type change.

## Local storage and sync boundary

The local Drift schema is version 4. It contains `category_keywords` and
`category_group_memberships`. Group rows, personal children, keywords, and
default-category memberships remain local-only. SyncEngine excludes local-only
category rows and does not send or pull membership records.

See [CATEGORY_MANAGEMENT_BACKEND_HANDOFF.md](CATEGORY_MANAGEMENT_BACKEND_HANDOFF.md)
for the future backend contract. It is documentation only, not authorization to
change backend behavior.

## UI routes

- `/categories` — management tree and `Chưa nhóm`
- `/categories/child/new` — create personal child
- `/categories/group/new` — create personal group
- `/categories/:id/keywords` — keyword-only default-category form

The `+` button on `/categories` opens a menu for both child and parent-group
creation.

## Verification record

- Final Client-app command: `flutter test --no-pub`
- Result after the default-membership reassignment fix: **60/60 tests passed**.
- The final cross-layer review found no Critical or Important issue.

## Relevant commits

`d2fa3ad` through `a938f36` implement the category-management module and the
default-category membership extension. The parent-group creation menu is in
`b517c4f`.
