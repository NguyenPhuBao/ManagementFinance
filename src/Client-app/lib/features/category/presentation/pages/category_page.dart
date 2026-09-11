import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/current_account.dart';
import '../../../../core/category/category_classify.dart';
import '../../../../core/category/category_visuals.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/models/category_tree.dart';
import '../../data/repositories/category_management_repository.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({
    super.key,
    this.repository,
    this.accountId,
  });

  final CategoryManagementRepository? repository;
  final int? accountId;

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  late final CategoryManagementRepository _repository;
  final Set<String> _expandedGroups = <String>{};
  String _classify = 'chi';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? sl<CategoryManagementRepository>();
  }

  /// Mã tài khoản của phiên đăng nhập, hoặc `null` khi chưa có phiên dùng
  /// được. KHÔNG rơi về 1 — đó là tài khoản admin thật (G35, quy tắc 2
  /// `CLAUDE.md`). Cũng không rơi về 0: 0 là bộ khuôn danh mục mặc định toàn
  /// cục, đọc nó là hiện bộ khuôn ra màn hình.
  int? get _accountId => widget.accountId ?? currentAccountIdOrNull(context);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Danh mục'),
          leading: IconButton(
            tooltip: 'Quay lại',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Thêm danh mục',
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          onPressed: () => _showCreateCategoryMenu(context),
          child: const Icon(Icons.add),
        ),
        body: StreamBuilder<CategoryTree>(
          // Chưa có phiên thì không mở luồng đọc nào (G35).
          stream: _accountId == null
              ? const Stream<CategoryTree>.empty()
              : _repository.watchTree(
                  accountId: _accountId!,
                  classify: _classify,
                ),
          builder: (context, snapshot) {
            if (_accountId == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Chưa xác định được tài khoản đăng nhập. '
                    'Vui lòng đăng nhập lại.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text('Không thể tải danh mục: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final tree = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                const Text(
                  'Quản lý danh mục',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                _TypeFilters(
                  selected: _classify,
                  onChanged: (value) => setState(() => _classify = value),
                ),
                const SizedBox(height: 24),
                _Section(
                  title: 'Nhóm của bạn',
                  child: tree.groups.isEmpty
                      ? const _EmptySection('Chưa có nhóm danh mục')
                      : Column(
                          children: tree.groups
                              .map((node) => _groupNode(context, node))
                              .toList(),
                        ),
                ),
                const SizedBox(height: 20),
                _Section(
                  title: 'Chưa nhóm',
                  child: tree.ungroupedChildren.isEmpty
                      ? const _EmptySection('Chưa có danh mục chưa nhóm')
                      : Column(
                          children: tree.ungroupedChildren
                              .map((category) => _childRow(context, category))
                              .toList(),
                        ),
                ),
                const SizedBox(height: 20),
                _Section(
                  title: 'Danh mục mặc định',
                  child: tree.defaultChildren.isEmpty
                      ? const _EmptySection('Chưa có danh mục mặc định')
                      : Column(
                          children: tree.defaultChildren
                              .map((category) => _defaultRow(context, category))
                              .toList(),
                        ),
                ),
              ],
            );
          },
        ),
      );

  Widget _groupNode(BuildContext context, CategoryGroupNode node) {
    final isExpanded = _expandedGroups.contains(node.group.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() {
              isExpanded
                  ? _expandedGroups.remove(node.group.id)
                  : _expandedGroups.add(node.group.id);
            }),
            leading: _CategoryAvatar(category: node.group, folder: true),
            title: Text(node.group.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${node.children.length} danh mục'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Sửa nhóm',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      context.push('/categories/group/${node.group.id}/edit'),
                ),
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
              child: node.children.isEmpty
                  ? const _EmptySection('Nhóm này chưa có danh mục')
                  : Column(
                      children: node.children
                          .map((child) =>
                              _childRow(context, child, nested: true))
                          .toList(),
                    ),
            ),
        ],
      ),
    );
  }

  void _showCreateCategoryMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Tạo danh mục con'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('/categories/child/new');
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_tree_outlined),
              title: const Text('Tạo nhóm danh mục'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('/categories/group/new');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _childRow(BuildContext context, Category category,
          {bool nested = false}) =>
      Card(
        margin: EdgeInsets.only(bottom: 8, left: nested ? 8 : 0),
        child: ListTile(
          leading: _CategoryAvatar(category: category),
          title: Text(category.name),
          trailing: IconButton(
            tooltip: 'Sửa danh mục',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                context.push('/categories/child/${category.id}/edit'),
          ),
        ),
      );

  Widget _defaultRow(BuildContext context, Category category) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: _CategoryAvatar(category: category),
          title: Text(category.name),
          subtitle: const Text('Danh mục mặc định'),
          trailing: TextButton(
            onPressed: () =>
                context.push('/categories/${category.id}/keywords'),
            child: const Text('Từ khóa của tôi'),
          ),
        ),
      );
}

class _TypeFilters extends StatelessWidget {
  const _TypeFilters({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: kCategoryClassifies
              .map(
                (classify) => Expanded(
                  child: Semantics(
                    selected: selected == classify,
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onChanged(classify),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected == classify
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          categoryClassifyLabel(classify),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected == classify
                                ? AppColors.onPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          child,
        ],
      );
}

class _EmptySection extends StatelessWidget {
  const _EmptySection(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(message,
            style: const TextStyle(color: AppColors.textSecondary)),
      );
}

class _CategoryAvatar extends StatelessWidget {
  const _CategoryAvatar({required this.category, this.folder = false});
  final Category category;
  final bool folder;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(category.colour);
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: .16),
      foregroundColor: color,
      child: Icon(folder ? Icons.folder_outlined : _iconFor(category.icon)),
    );
  }
}

// Uỷ quyền về định nghĩa chung (2026-09-06): bản cũ ở đây chỉ hiểu tên Material
// nên danh mục mặc định kéo từ backend (`food`, `bill`, `lend`…) toàn rơi về
// icon mặc định.
Color _parseColor(String value) =>
    categoryColorFrom(value, fallback: const Color(0xFF10B981));

IconData _iconFor(String icon) => categoryIconFor(icon);
