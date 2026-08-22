# Default category group membership — mobile design

## Goal

Allow each mobile user to place a default category into a personal parent group without mutating the shared default category or affecting another user.

## Data model

Add a local-only membership table keyed by `(accountId, groupId, categoryId)`.

- `accountId` identifies the user-specific view.
- `groupId` must identify that account's active personal group.
- `categoryId` may identify either a shared default category or an active personal child category.
- The tuple is unique, so a category can belong to at most one group for one account.
- Membership rows never enter SyncEngine push payloads and are ignored during pull.

The existing global default `Categories` rows (`idaccount = 0`) remain unchanged: their name, type, icon, colour, deletion state, and `parentId` are not written by group management.

## Behavior

- A default category with no membership is shown in `Chưa nhóm`.
- A membership moves it under its referenced personal parent group only in that account's tree.
- The group editor lists default categories as selectable children alongside eligible personal children.
- Removing a category from a group removes only its membership.
- Deleting a group removes its memberships; all affected categories return to `Chưa nhóm`. Personal child behavior retains the existing `parentId` clearing rule.
- Default categories remain read-only for all metadata and deletion. Their allowed mutations are account-scoped keywords and local group membership.
- A grouped default category remains a selectable transaction leaf, never a group.

## Repository and UI boundary

The repository owns membership validation and updates atomically with group changes. `CategoryTree` resolves membership before rendering, so management and transaction-picker pages consume the same tree and need no direct database logic.

The existing group form keeps its child selection UI; its candidate list expands to include defaults. Existing UI labels and the new creation menu remain unchanged.

## Tests

Test the following before implementation:

1. A default category starts ungrouped for each account.
2. Grouping a default category affects only the requesting account and does not change the global category row.
3. Deleting a group removes its default memberships and returns them to `Chưa nhóm`.
4. A default category appears as a child leaf in the management tree and transaction picker after grouping.
5. Sync collection and pull remain unaware of membership rows.

## Scope

Only Client-app schema, repository, category/group UI, picker tests, and client-owned backend handoff documentation may change. Backend and Admin-web source remain untouched.
