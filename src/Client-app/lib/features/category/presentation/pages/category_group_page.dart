import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/category_tree.dart';
import '../../data/repositories/category_management_repository.dart';

class CategoryGroupPage extends StatefulWidget {
  const CategoryGroupPage({
    super.key,
    this.groupId,
    this.repository,
    this.accountId,
  });

  final String? groupId;
  final CategoryManagementRepository? repository;
  final int? accountId;

  @override
  State<CategoryGroupPage> createState() => _CategoryGroupPageState();
}

class _CategoryGroupPageState extends State<CategoryGroupPage> {
  late final CategoryManagementRepository _repository;
  final _nameController = TextEditingController();
  final Set<String> _selectedChildIds = <String>{};
  List<Category> _children = [];
  String _classify = 'chi';
  String _icon = 'folder';
  String _colour = '#10B981';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? sl<CategoryManagementRepository>();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  int get _accountId {
    if (widget.accountId != null) return widget.accountId!;
    final state = context.read<AuthBloc>().state;
    return int.tryParse((state is AuthSuccess ? state.user?.id : null) ?? '') ??
        1;
  }

  Future<void> _load() async {
    if (widget.groupId != null) {
      const classifies = ['chi', 'thu', 'vay_no'];
      final trees = await Future.wait(classifies.map(
        (classify) =>
            _repository.loadTree(accountId: _accountId, classify: classify),
      ));
      for (final tree in trees) {
        for (final node in tree.groups) {
          if (node.group.id != widget.groupId) continue;
          _nameController.text = node.group.name;
          _classify = node.group.classify;
          _icon = node.group.icon;
          _colour = node.group.colour;
          _selectedChildIds.addAll(node.children.map((child) => child.id));
          break;
        }
      }
    }
    await _loadChildren();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadChildren() async {
    final children = await _repository.selectableChildren(
      accountId: _accountId,
      classify: _classify,
    );
    if (!mounted) return;
    setState(() {
      _children = children.where((child) => !child.isDeleted).toList();
      _selectedChildIds.retainAll(_children.map((child) => child.id).toSet());
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _repository.saveGroup(CategoryGroupDraft(
        id: widget.groupId,
        accountId: _accountId,
        name: _nameController.text,
        classify: _classify,
        icon: _icon,
        colour: _colour,
        childIds: _selectedChildIds.toList(),
      ));
      if (mounted && context.canPop()) context.pop();
    } on CategoryValidationException catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) _message('Không thể lưu nhóm danh mục. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa nhóm danh mục?'),
        content: const Text('Các danh mục con sẽ trở về Chưa nhóm.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa nhóm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.deleteGroup(
          accountId: _accountId, groupId: widget.groupId!);
      if (mounted && context.canPop()) context.pop();
    } on CategoryValidationException catch (error) {
      if (mounted) _message(error.message);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop()),
          title: Text(
              widget.groupId == null ? 'Thêm nhóm danh mục' : 'Chỉnh sửa nhóm'),
          actions: [
            TextButton(
                onPressed: _saving ? null : _save, child: const Text('Lưu')),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const Text('Tên nhóm lớn (danh mục cha)',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                                hintText: 'e.g. Chi tiêu Sinh hoạt'),
                          ),
                          const SizedBox(height: 24),
                          const Text('Chọn biểu tượng nhóm',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          _GroupIconPicker(
                              selected: _icon,
                              onChanged: (value) =>
                                  setState(() => _icon = value)),
                          const SizedBox(height: 24),
                          const Text('Loại giao dịch',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          _GroupTypeSelector(
                            selected: _classify,
                            onChanged: (value) async {
                              if (value == _classify) return;
                              setState(() => _classify = value);
                              await _loadChildren();
                            },
                          ),
                          const SizedBox(height: 24),
                          const Text('Chọn danh mục con gộp vào nhóm',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Card(
                            child: Column(
                              children: _children.isEmpty
                                  ? const [
                                      Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Text(
                                            'Chưa có danh mục con phù hợp'),
                                      ),
                                    ]
                                  : _children
                                      .map((child) => CheckboxListTile(
                                            value: _selectedChildIds
                                                .contains(child.id),
                                            title: Text(child.name),
                                            subtitle: Text(child.isDefault
                                                ? 'Danh mục mặc định • Chỉ có thể sửa từ khóa'
                                                : child.parentId == null
                                                    ? 'Chưa nhóm'
                                                    : 'Đang ở nhóm khác'),
                                            onChanged: (selected) =>
                                                setState(() {
                                              selected == true
                                                  ? _selectedChildIds
                                                      .add(child.id)
                                                  : _selectedChildIds
                                                      .remove(child.id);
                                            }),
                                          ))
                                      .toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _Preview(
                              name: _nameController.text,
                              children: _children
                                  .where((child) =>
                                      _selectedChildIds.contains(child.id))
                                  .toList()),
                          if (widget.groupId != null) ...[
                            const SizedBox(height: 20),
                            OutlinedButton.icon(
                              onPressed: _delete,
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Xóa nhóm'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label:
                            Text(_saving ? 'Đang lưu...' : 'Lưu Nhóm Danh Mục'),
                      ),
                    ),
                  ],
                ),
              ),
      );
}

class _GroupTypeSelector extends StatelessWidget {
  const _GroupTypeSelector({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;
  static const labels = {
    'chi': 'Khoản chi',
    'thu': 'Khoản thu',
    'vay_no': 'Vay / nợ'
  };

  @override
  Widget build(BuildContext context) => Row(
        children: labels.entries
            .map((entry) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: selected == entry.key,
                      onSelected: (_) => onChanged(entry.key),
                    ),
                  ),
                ))
            .toList(),
      );
}

class _GroupIconPicker extends StatelessWidget {
  const _GroupIconPicker({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;
  static const icons = {
    'folder': Icons.folder_outlined,
    'home': Icons.home_outlined,
    'restaurant': Icons.restaurant_outlined,
    'shopping_bag': Icons.shopping_bag_outlined
  };

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        children: icons.entries
            .map((entry) => InkResponse(
                  onTap: () => onChanged(entry.key),
                  child: CircleAvatar(
                    backgroundColor: selected == entry.key
                        ? AppColors.primary
                        : AppColors.surfaceContainer,
                    foregroundColor: selected == entry.key
                        ? Colors.white
                        : AppColors.textPrimary,
                    child: Icon(entry.value),
                  ),
                ))
            .toList(),
      );
}

class _Preview extends StatelessWidget {
  const _Preview({required this.name, required this.children});
  final String name;
  final List<Category> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CẤU TRÚC XEM TRƯỚC',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text(
                '${name.isEmpty ? 'Nhóm danh mục' : name} (${children.length} danh mục)',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            ...children.map((child) => Padding(
                  padding: const EdgeInsets.only(top: 8, left: 16),
                  child: Text('• ${child.name}'),
                )),
          ],
        ),
      );
}
