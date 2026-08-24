import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/category/data/models/category_tree.dart';
import '../../../../features/category/data/repositories/category_management_repository.dart';
import '../../../../shared/theme/app_colors.dart';

class ChooseCategoryPage extends StatefulWidget {
  const ChooseCategoryPage({
    super.key,
    this.idaccount = 1,
    this.classify = 'chi',
    this.repository,
  });

  final int idaccount;
  final String classify;
  final CategoryManagementRepository? repository;

  @override
  State<ChooseCategoryPage> createState() => _ChooseCategoryPageState();
}

class _ChooseCategoryPageState extends State<ChooseCategoryPage> {
  late int _selectedTab;
  CategoryTree? _tree;
  bool _isLoading = true;
  String _searchQuery = '';
  final Set<String> _expandedGroups = <String>{};

  CategoryManagementRepository get _repository =>
      widget.repository ?? sl<CategoryManagementRepository>();

  String get _classify => _selectedTab == 0 ? 'chi' : 'thu';

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.classify == 'thu' ? 1 : 0;
    _loadTree();
  }

  int _accountId() {
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthSuccess) {
        return int.tryParse(authState.user?.id ?? '') ?? widget.idaccount;
      }
    } catch (_) {
      // Widget tests and route previews may not provide the auth bloc.
    }
    return widget.idaccount;
  }

  Future<void> _loadTree() async {
    setState(() => _isLoading = true);
    final tree = await _repository.loadTree(
      accountId: _accountId(),
      classify: _classify,
    );
    if (!mounted) return;
    setState(() {
      _tree = tree;
      _isLoading = false;
    });
  }

  List<Category> _matchingChildren(Iterable<Category> children) {
    final query = _searchQuery.trim().toLowerCase();
    return children
        .where((child) =>
            !child.isDeleted &&
            !child.isGroup &&
            (query.isEmpty || child.name.toLowerCase().contains(query)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: context.pop,
        ),
        title: const Text(
          'Chọn danh mục',
          style:
              TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSegmentControl(),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                    const SizedBox(height: 20),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      _buildTree(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: OutlinedButton.icon(
                onPressed: () => context.push('/categories'),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Quản lý danh mục'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: AppColors.outlineVariant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentControl() => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(child: _buildSegmentButton(0, 'Khoản chi')),
            Expanded(child: _buildSegmentButton(1, 'Khoản thu')),
          ],
        ),
      );

  Widget _buildSegmentButton(int index, String label) => GestureDetector(
        onTap: () {
          if (_selectedTab == index) return;
          setState(() {
            _selectedTab = index;
            _expandedGroups.clear();
          });
          _loadTree();
        },
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: _selectedTab == index ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _selectedTab == index
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
          ),
        ),
      );

  Widget _buildSearchBar() => TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm danh mục...',
          prefixIcon: const Icon(Icons.search, color: AppColors.outline),
          filled: true,
          fillColor: AppColors.surfaceContainerLow,
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

  Widget _buildTree() {
    final tree = _tree;
    if (tree == null) return const SizedBox.shrink();
    final sections = <Widget>[];
    for (final node in tree.groups) {
      final children = _matchingChildren(node.children);
      if (children.isNotEmpty) {
        sections.add(_buildGroup(node, children));
      }
    }
    final ungrouped = _matchingChildren(tree.ungroupedChildren);
    if (ungrouped.isNotEmpty) {
      sections.add(_buildLeafSection('Chưa nhóm', ungrouped));
    }
    final defaults = _matchingChildren(tree.defaultChildren);
    if (defaults.isNotEmpty) {
      sections.add(_buildLeafSection('Danh mục mặc định', defaults));
    }
    if (sections.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text('Không tìm thấy danh mục'),
      );
    }
    return Column(children: sections);
  }

  Widget _buildGroup(CategoryGroupNode node, List<Category> children) {
    final isExpanded = _expandedGroups.contains(node.group.id);
    final searchActive = _searchQuery.trim().isNotEmpty;
    final showChildren = isExpanded || searchActive;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      child: Column(
        children: [
          ListTile(
            key: Key('category-group-${node.group.id}'),
            leading:
                const Icon(Icons.folder_outlined, color: AppColors.primary),
            title: Text(
              node.group.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: Icon(isExpanded || searchActive
                ? Icons.expand_less
                : Icons.expand_more),
            onTap: () => setState(() {
              if (isExpanded) {
                _expandedGroups.remove(node.group.id);
              } else {
                _expandedGroups.add(node.group.id);
              }
            }),
          ),
          if (showChildren) ...children.map(_buildChildTile),
        ],
      ),
    );
  }

  Widget _buildLeafSection(String title, List<Category> children) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        color: Colors.white,
        child: Column(
          children: [
            ListTile(
              leading:
                  const Icon(Icons.category_outlined, color: AppColors.primary),
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            ...children.map(_buildChildTile),
          ],
        ),
      );

  Widget _buildChildTile(Category child) => ListTile(
        key: Key('category-child-${child.id}'),
        contentPadding: const EdgeInsets.only(left: 32, right: 16),
        leading: const Icon(Icons.label_outline, color: AppColors.secondary),
        title: Text(child.name),
        trailing: const Icon(Icons.chevron_right, color: AppColors.outline),
        onTap: () => context.pop<Category>(child),
      );
}
