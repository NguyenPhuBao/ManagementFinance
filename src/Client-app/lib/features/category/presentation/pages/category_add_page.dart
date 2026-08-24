import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/category_tree.dart';
import '../../data/repositories/category_management_repository.dart';

class CategoryAddPage extends StatefulWidget {
  const CategoryAddPage({
    super.key,
    this.categoryId,
    this.keywordOnly = false,
    this.repository,
    this.accountId,
  });

  final String? categoryId;
  final bool keywordOnly;
  final CategoryManagementRepository? repository;
  final int? accountId;

  @override
  State<CategoryAddPage> createState() => _CategoryAddPageState();
}

class _CategoryAddPageState extends State<CategoryAddPage> {
  static const _classifies = ['chi', 'thu', 'vay_no'];
  static const _icons = [
    'restaurant',
    'directions_car',
    'shopping_bag',
    'receipt_long',
    'calendar_month',
    'favorite',
    'school',
    'more_horiz',
  ];
  static const _colours = [
    '#10B981',
    '#3B82F6',
    '#F59E0B',
    '#EF4444',
    '#8B5CF6',
    '#14B8A6',
  ];

  late final CategoryManagementRepository _repository;
  final _nameController = TextEditingController();
  final _keywordController = TextEditingController();
  final List<String> _keywords = [];
  List<Category> _groups = [];
  String _classify = 'chi';
  String? _parentId;
  String _icon = 'restaurant';
  String _colour = '#10B981';
  bool _showKeywordOnly = false;
  bool _loading = true;
  bool _saving = false;

  bool get _isKeywordOnly => widget.keywordOnly || _showKeywordOnly;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? sl<CategoryManagementRepository>();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  int get _accountId {
    if (widget.accountId != null) return widget.accountId!;
    final state = context.read<AuthBloc>().state;
    return int.tryParse((state is AuthSuccess ? state.user?.id : null) ?? '') ??
        1;
  }

  Future<void> _load() async {
    if (widget.keywordOnly) {
      if (widget.categoryId != null) {
        _keywords.addAll(await _repository.loadKeywords(
          accountId: _accountId,
          categoryId: widget.categoryId!,
        ));
      }
      if (mounted) setState(() => _loading = false);
      return;
    }

    final trees = await Future.wait(_classifies.map(
      (classify) =>
          _repository.loadTree(accountId: _accountId, classify: classify),
    ));
    final categories = <Category>[];
    final groups = <Category>[];
    for (final tree in trees) {
      groups.addAll(tree.groups.map((node) => node.group));
      categories
        ..addAll(tree.ungroupedChildren)
        ..addAll(tree.defaultChildren);
      for (final node in tree.groups) {
        categories.addAll(node.children);
      }
    }
    final current = widget.categoryId == null
        ? null
        : categories.where((item) => item.id == widget.categoryId).firstOrNull;
    if (current != null) {
      if (current.isDefault) {
        _keywords.addAll(await _repository.loadKeywords(
          accountId: _accountId,
          categoryId: current.id,
        ));
        if (mounted) {
          setState(() {
            _showKeywordOnly = true;
            _loading = false;
          });
        }
        return;
      }
      _nameController.text = current.name;
      _classify = current.classify;
      _parentId = current.parentId;
      _icon = current.icon;
      _colour = current.colour;
      _keywords.addAll(await _repository.loadKeywords(
        accountId: _accountId,
        categoryId: current.id,
      ));
    }
    if (mounted) {
      setState(() {
        _groups = groups;
        _loading = false;
      });
    }
  }

  void _addKeywordText(String value) {
    _addKeywords(value.split(','));
    _keywordController.clear();
  }

  void _addKeywords(Iterable<String> values) {
    final normalized =
        values.map((item) => item.trim()).where((item) => item.isNotEmpty);
    setState(() {
      for (final keyword in normalized) {
        if (!_keywords.any(
            (existing) => existing.toLowerCase() == keyword.toLowerCase())) {
          _keywords.add(keyword);
        }
      }
    });
  }

  void _onKeywordChanged(String value) {
    if (!value.contains(',')) return;
    _addKeywords(value.split(','));
    _keywordController.clear();
  }

  Future<void> _chooseParent(String? parentId) async {
    if (parentId == null) {
      setState(() => _parentId = null);
      return;
    }
    final parent = _groups.where((group) => group.id == parentId).first;
    if (parent.classify == _classify) {
      setState(() => _parentId = parentId);
      return;
    }
    final shouldChange = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi loại giao dịch?'),
        content: const Text(
          'Nhóm cha thuộc loại khác. Danh mục sẽ dùng loại giao dịch của nhóm cha.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xác nhận')),
        ],
      ),
    );
    if (shouldChange == true && mounted) {
      setState(() {
        _parentId = parentId;
        _classify = parent.classify;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (_isKeywordOnly) {
        await _repository.saveKeywords(
          accountId: _accountId,
          categoryId: widget.categoryId!,
          keywords: _keywords,
        );
      } else {
        await _repository.saveChild(CategoryChildDraft(
          id: widget.categoryId,
          accountId: _accountId,
          name: _nameController.text,
          classify: _classify,
          parentId: _parentId,
          icon: _icon,
          colour: _colour,
          keywords: _keywords,
        ));
      }
      if (mounted && context.canPop()) context.pop();
    } on CategoryValidationException catch (error) {
      if (mounted) _showError(error.message);
    } catch (_) {
      if (mounted) _showError('Không thể lưu danh mục. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

  @override
  Widget build(BuildContext context) {
    final editing = widget.categoryId != null;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(_isKeywordOnly
            ? 'Từ khóa của tôi'
            : editing
                ? 'Chỉnh sửa danh mục'
                : 'Thêm danh mục mới'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _isKeywordOnly
              ? _keywordOnlyBody()
              : _formBody(editing),
    );
  }

  Widget _keywordOnlyBody() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Từ khóa của tôi',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text('Nhập từ khóa rồi nhấn Enter hoặc dấu phẩy để tạo thẻ.'),
          const SizedBox(height: 16),
          _KeywordsEditor(
            controller: _keywordController,
            keywords: _keywords,
            onSubmitted: _addKeywordText,
            onChanged: _onKeywordChanged,
            onRemoved: (keyword) => setState(() => _keywords.remove(keyword)),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Đang lưu...' : 'Lưu từ khóa'),
          ),
        ],
      );

  Widget _formBody(bool editing) => SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  const Text('Loại giao dịch',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _CategoryTypeSelector(
                    selected: _classify,
                    onChanged: (value) => setState(() => _classify = value),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('* Kế thừa từ nhóm cha nếu được chọn',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ),
                  const SizedBox(height: 24),
                  const Text('Nhóm cha',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(hintText: 'Chưa nhóm'),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        key: const Key('parent-selector'),
                        value: _parentId,
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String?>(
                              value: null, child: Text('Chưa nhóm')),
                          ..._groups.map((group) => DropdownMenuItem<String?>(
                                value: group.id,
                                child: Text(group.name),
                              )),
                        ],
                        onChanged: _chooseParent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Tên danh mục',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration:
                        const InputDecoration(hintText: 'e.g. Thuê nhà'),
                  ),
                  const SizedBox(height: 24),
                  const Text('Chọn biểu tượng',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _IconPicker(
                      selected: _icon,
                      onChanged: (value) => setState(() => _icon = value)),
                  const SizedBox(height: 24),
                  const Text('Màu sắc chủ đạo',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _ColourPicker(
                      selected: _colour,
                      onChanged: (value) => setState(() => _colour = value)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => context.pop(),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving
                          ? 'Đang lưu...'
                          : editing
                              ? 'Lưu danh mục'
                              : 'Lưu danh mục'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _KeywordsEditor extends StatelessWidget {
  const _KeywordsEditor({
    required this.controller,
    required this.keywords,
    required this.onSubmitted,
    required this.onChanged,
    required this.onRemoved,
  });

  final TextEditingController controller;
  final List<String> keywords;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onRemoved;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: keywords
                .map((keyword) => InputChip(
                      label: Text(keyword),
                      onDeleted: () => onRemoved(keyword),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('keyword-input'),
            controller: controller,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            decoration: const InputDecoration(hintText: 'Thêm từ khóa'),
          ),
        ],
      );
}

class _CategoryTypeSelector extends StatelessWidget {
  const _CategoryTypeSelector(
      {required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;
  static const labels = {
    'chi': 'Khoản chi',
    'thu': 'Khoản thu',
    'vay_no': 'Vay / nợ'
  };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: labels.entries
              .map((entry) => Expanded(
                    child: InkWell(
                      onTap: () => onChanged(entry.key),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected == entry.key
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(entry.value,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected == entry.key
                                    ? Colors.white
                                    : AppColors.textSecondary)),
                      ),
                    ),
                  ))
              .toList(),
        ),
      );
}

class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;
  static const icons = _CategoryAddPageState._icons;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: icons
            .map((icon) => InkResponse(
                  onTap: () => onChanged(icon),
                  child: CircleAvatar(
                    backgroundColor: selected == icon
                        ? AppColors.primary
                        : AppColors.surfaceContainer,
                    foregroundColor:
                        selected == icon ? Colors.white : AppColors.textPrimary,
                    child: Icon(_iconData(icon)),
                  ),
                ))
            .toList(),
      );
}

class _ColourPicker extends StatelessWidget {
  const _ColourPicker({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;
  static const colours = _CategoryAddPageState._colours;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        children: colours.map((colour) {
          final active = colour == selected;
          return InkResponse(
            onTap: () => onChanged(colour),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _categoryColour(colour),
                shape: BoxShape.circle,
                border: active
                    ? Border.all(color: AppColors.primary, width: 2)
                    : null,
              ),
              child: active
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          );
        }).toList(),
      );
}

Color _categoryColour(String value) =>
    Color(int.parse('FF${value.replaceAll('#', '')}', radix: 16));

IconData _iconData(String icon) => switch (icon) {
      'restaurant' => Icons.restaurant,
      'directions_car' => Icons.directions_car,
      'shopping_bag' => Icons.shopping_bag,
      'receipt_long' => Icons.receipt_long,
      'calendar_month' => Icons.calendar_month,
      'favorite' => Icons.favorite,
      'school' => Icons.school,
      _ => Icons.more_horiz,
    };
