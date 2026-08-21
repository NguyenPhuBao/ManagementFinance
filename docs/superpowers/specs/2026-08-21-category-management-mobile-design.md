# Module 2: Category Management — Mobile Design

**Status:** Approved design; implementation has not started.

**Scope owner:** Client-app (Flutter) only. This design does not authorize changes to Backend or Admin-web.

## Purpose

Provide offline category management for a FlowMoney user. A user can organize personal child categories under personal parent groups, manage local recognition keywords, select a child category for transactions, and receive a non-binding category suggestion from text.

The feature must work without backend support. A separate handoff document will describe the backend schema, APIs, and sync contract required in a later phase.

## In scope

- Create, edit, and soft-delete personal parent groups.
- Create, edit, group, ungroup, and soft-delete personal child categories.
- Classify groups and ungrouped children as `chi`, `thu`, or `vay_no`.
- Configure local, per-account recognition keywords for both personal and default child categories.
- Suggest one child category from a note, OCR result, or future AI-produced text; the user must explicitly accept it.
- Preserve historical transaction category references when a child category is deleted.
- Produce a backend handoff specification only; do not modify backend code or schema.

## Out of scope

- Backend persistence, APIs, sync changes, or admin-web changes.
- Automatic transaction categorization or automatic saving.
- Nested groups deeper than one parent-group level.
- Editing or deleting default category content. Default categories expose only a per-user keyword configuration action.

## Approved Stitch sources

Only the following new Stitch screens are design references for this module. Legacy category screens are ignored.

| Screen | Stitch screen ID | Responsibility |
| --- | --- | --- |
| Quản lý danh mục - FlowMoney | `583f82329e5349049602b2dd387407f9` | Category tree, filters, actions, default-category keyword entry point |
| Thêm / Chỉnh sửa danh mục con - FlowMoney | `5a58b9e2a2a54729bec3da32a500f174` | Child-category creation, editing, group selection, keyword chips |
| Thêm / Chỉnh sửa nhóm danh mục - FlowMoney | `25804eac36e14cb29b0f58b055bf4ec4` | Group lifecycle, child membership, type-change confirmation |
| Chọn danh mục giao dịch - FlowMoney | `acab2a45450e4f9fa400a669b67d3327` | Child-category selection for transactions |
| Thêm giao dịch - Gợi ý danh mục AI | `20700200afbc4d5f98962bc9be79b780` | Explicitly accepted category suggestion |

## Data model

### Categories extension

The existing local `Categories` table remains the source for category identity, presentation, ownership, deletion state, and timestamps. Add:

- `parentId` — nullable category ID. `null` means an ungrouped child or a parent group.
- `isGroup` — boolean; `true` marks a personal parent group.

Application invariants:

- A group has `isGroup = true` and `parentId = null`.
- A child has `isGroup = false`; it may have a `parentId` or be ungrouped.
- Groups are personal only (`isDefault = false`).
- A child that belongs to a group inherits its `classify` value from the group.
- Default categories are read-only aside from their user-owned keyword records.
- Group names are unique within a transaction type for an account.
- Child names are unique within the same parent (including the ungrouped area) and transaction type for an account.

### CategoryKeywords table

Create a local-only normalized table rather than storing a shared comma-separated string on `Categories`:

| Field | Meaning |
| --- | --- |
| `id` | Local UUID |
| `idaccount` | Account that owns the keyword setting |
| `categoryId` | Child-category ID; may reference a default category |
| `keyword` | Trimmed display value for the chip |
| `normalizedKeyword` | Lower-cased normalized value used for matching and uniqueness |
| `createdAt`, `updatedAt` | Local audit timestamps |

The uniqueness rule is `(idaccount, categoryId, normalizedKeyword)`. This prevents the same user from entering a keyword twice while keeping each user’s keyword choices separate for a default category.

## UI and user flows

### Manage categories

The mobile management page filters by `Khoản chi`, `Khoản thu`, and `Vay / nợ`. It renders, in order:

1. The personal group tree, with expandable parent groups and indented child categories.
2. The personal `Chưa nhóm` area.
3. Locked default categories with only a `Từ khóa của tôi` action.

The add action presents exactly two choices: add a parent group or add a child category. Personal rows can be edited or deleted; default rows cannot.

### Child category form

Users can create an ungrouped child first or select an optional parent group. An ungrouped child chooses its own type. A grouped child inherits the parent type. If a selected parent type differs from the child’s existing type, the app asks for confirmation before changing the child’s type.

Names are required, trimmed, and validated against the approved uniqueness rules before saving. The form supports an icon and colour.

The keyword field accepts Enter, comma-separated input, and pasted comma-separated input. Tokens become removable chips; empty or case-insensitive duplicate keywords are discarded. The default-category edit variant exposes only keyword chips and save/cancel controls.

### Group form

The group form creates or edits a personal parent group, selects zero or more child categories, and previews the resulting hierarchy. Type changes that affect selected children require explicit confirmation. Deleting a group performs an ungroup operation for every child, then soft-deletes the group.

### Transaction category picker

The picker displays parent groups as non-selectable headers and permits selection only of child categories or ungrouped children. Soft-deleted categories do not appear in this picker. The picker leads to category management rather than presenting a group-creation shortcut.

### Suggestion card

When transaction text is available, the add-transaction screen may show one suggestion card. The user must choose `Chọn danh mục này` or `Bỏ qua`; no suggestion changes the transaction automatically.

## Local operations and error handling

Use a single SQLite transaction for every operation that changes group membership:

- Assigning or removing a child from a group.
- Applying a confirmed type inheritance change.
- Deleting a group and clearing all its children’s `parentId` values.

Deleting a child sets its existing local soft-delete state. Existing transactions retain their `categoryId`, so historical views continue to resolve the retained category record and show its prior name.

On validation failure, the form remains intact and reports the field-level problem. On a database failure, preserve the form draft and show a recoverable error message. If a selected category was deleted before save, require the user to select a valid category again.

## Suggestion engine

`CategorySuggestionEngine` is local-only and accepts raw text from manual notes, OCR, or a future AI result. It:

1. Normalizes raw text and candidate keywords.
2. Counts matching keywords for each eligible, non-deleted child category in the current transaction type.
3. Selects the category with the highest match count.
4. Breaks a tie using the longest matched keyword.
5. Produces no suggestion if a tie remains or nothing matches.

The engine has no permission to write a transaction or change the currently selected category.

## Client boundaries

- `CategoryRepository`: category/group persistence, tree queries, soft deletion, and membership transactions.
- `CategoryKeywordRepository`: per-account keyword CRUD and normalization rules.
- `CategorySuggestionEngine`: pure ranking logic with no persistence dependency.
- Presentation state: category tree, category form, group form, picker, and suggestion-card state remain separate so each can be tested independently.

## Future backend handoff requirements

Write a follow-on document for backend maintainers after client behavior is implemented. It must define:

- Parent-group relation and group marker in the backend category model.
- Soft-delete behavior for categories and group deletion/un-grouping.
- A per-user category-keyword model that supports default categories without changing global default data.
- Pull and push payloads for parent relation, group state, and keyword records.
- Conflict and last-write-wins behavior for the new client-owned fields.
- A mapping from the normalized local keyword rows to the backend’s eventual API representation.

## Verification plan

- DAO tests: tree queries, ownership filtering, group deletion, soft delete, uniqueness checks, and keyword persistence.
- Suggestion-engine tests: single match, multi-match, longest-keyword tie-break, unresolved tie, case normalization, and no match.
- Widget/state tests: default-category restrictions, type-change confirmation, child-only picker selection, ignored suggestion, and accepted suggestion.
- Manual verification against the five approved Stitch screens.
