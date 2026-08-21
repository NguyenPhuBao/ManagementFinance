# Task 5 report — child-only picker and explicit suggestions

## Delivered

- Replaced the transaction category picker’s flat DAO grid with the Task 3 category repository tree. Group headers only expand or collapse; eligible leaf children return through `context.pop<Category>(child)`.
- Added child-name search, including group-header retention only when matching children remain, plus the `Chưa nhóm` and default-child sections.
- Added a `Quản lý danh mục` action that navigates to `/categories`.
- Passed the active expense/income classify value into the picker route.
- Added note-driven suggestions using `CategoryManagementRepository.selectableChildren`, per-category account keywords, and the pure `CategorySuggestionEngine`.
- Suggestions remain unselected until `Chọn danh mục này` is pressed. `Bỏ qua`, an empty note, a type change, and manual category selection clear the card.

## Tests

- `flutter test test/features/category/presentation/category_management_widget_test.dart` — 7 passing tests.
- `flutter test` — 46 passing tests.

## TDD evidence

The new widget tests were run before production changes. The first run failed because the picker and form had no repository-backed seams (`repository` and `categoryRepository` named parameters were absent). The test passed after the minimal implementation.

## Stitch inspection

Both approved screens were confirmed in Stitch project `5106367939423432838`:

- Child picker: `acab2a45450e4f9fa400a669b67d3327`
- Add Transaction suggestion: `20700200afbc4d5f98962bc9be79b780`

The chooser’s direct Stitch `get_screen` call returned `Request contains an invalid argument`, but `list_screens` exposed its title, screenshot, and HTML metadata. No required screen asset was missing.

## Follow-up: stale async suggestion guard

- Captured the request segment and classify before loading selectable categories and keywords. A completed request is ignored when the active transaction type has changed.
- Added a delayed-future widget regression: start an expense suggestion, switch to income before the category future completes, then complete the old request and verify no stale suggestion card is rendered.
- Verification after the fix: focused widget suite 8 passing tests; full Client-app suite 47 passing tests.
