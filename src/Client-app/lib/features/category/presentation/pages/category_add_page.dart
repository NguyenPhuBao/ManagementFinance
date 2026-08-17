import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../core/sync/category_icon_registry.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class CategoryAddPage extends StatefulWidget {
  const CategoryAddPage({super.key});

  @override
  State<CategoryAddPage> createState() => _CategoryAddPageState();
}

class _CategoryAddPageState extends State<CategoryAddPage> {
  int _selectedTypeIndex = 0; // 0: Khoản chi, 1: Khoản thu
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _keywordInputController = TextEditingController();
  
  String _selectedIcon = 'restaurant';
  Color _selectedColor = const Color(0xFF10B981); // Emerald Green default
  bool _isSaving = false;

  final List<String> _keywords = ['phở', 'cafe', 'highland', 'grabfood'];

  final List<Map<String, dynamic>> _iconList = [
    {'name': 'restaurant', 'icon': Icons.restaurant, 'label': 'Ăn uống'},
    {'name': 'directions_car', 'icon': Icons.directions_car, 'label': 'Di chuyển'},
    {'name': 'shopping_bag', 'icon': Icons.shopping_bag, 'label': 'Mua sắm'},
    {'name': 'receipt_long', 'icon': Icons.receipt_long, 'label': 'Hóa đơn'},
    {'name': 'movie', 'icon': Icons.movie, 'label': 'Giải trí'},
    {'name': 'favorite', 'icon': Icons.favorite, 'label': 'Sức khỏe'},
    {'name': 'school', 'icon': Icons.school, 'label': 'Giáo dục'},
    {'name': 'more_horiz', 'icon': Icons.more_horiz, 'label': 'Khác'},
  ];

  final List<Color> _colorList = [
    const Color(0xFF10B981), // Emerald
    const Color(0xFF3B82F6), // Blue
    const Color(0xFFF59E0B), // Yellow/Orange
    const Color(0xFFEF4444), // Red
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFF14B8A6), // Teal
  ];

  void _addKeyword() {
    final text = _keywordInputController.text.trim();
    if (text.isNotEmpty && !_keywords.contains(text)) {
      setState(() {
        _keywords.add(text);
        _keywordInputController.clear();
      });
    }
  }

  void _removeKeyword(String kw) {
    setState(() {
      _keywords.remove(kw);
    });
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên danh mục'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final authState = context.read<AuthBloc>().state;
      final user = (authState is AuthSuccess) ? authState.user : null;
      final userIdAccount = int.tryParse(user?.id ?? '') ?? 1;

      final db = sl<AppDatabase>();
      final now = DateTime.now();
      final newId = 'cat_${now.millisecondsSinceEpoch}';

      final colorHex = '#${_selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      final companion = CategoriesCompanion(
        id: Value(newId),
        idaccount: Value(userIdAccount),
        name: Value(name),
        classify: Value(_selectedTypeIndex == 0 ? 'chi' : 'thu'),
        icon: Value(_selectedIcon),
        colour: Value(colorHex),
        isDefault: const Value(false),
        isDeleted: const Value(false),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      );

      await CategoryIconRegistry.saveIcon(newId, name, _selectedIcon, colorHex);
      await db.categoryDao.insert(companion);

      if (sl.isRegistered<SyncEngine>()) {
        sl<SyncEngine>().scheduleSync();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã tạo danh mục mới thành công!'),
            backgroundColor: Color(0xFF006E1C),
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu danh mục: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keywordInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1C1A)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Thêm danh mục mới',
          style: TextStyle(
            color: Color(0xFF1A1C1A),
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Category Type Selection (Segmented Control)
                    Container(
                      padding: const EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F4F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedTypeIndex = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedTypeIndex == 0 ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: _selectedTypeIndex == 0
                                      ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))]
                                      : [],
                                ),
                                child: Text(
                                  'Khoản chi',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: _selectedTypeIndex == 0 ? const Color(0xFF1A1C1A) : const Color(0xFF444748),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedTypeIndex = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedTypeIndex == 1 ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: _selectedTypeIndex == 1
                                      ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))]
                                      : [],
                                ),
                                child: Text(
                                  'Khoản thu',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: _selectedTypeIndex == 1 ? const Color(0xFF1A1C1A) : const Color(0xFF444748),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 2. Category Name Input
                    const Text(
                      'TÊN DANH MỤC',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF444748),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F4F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(fontSize: 16, color: Color(0xFF1A1C1A)),
                        decoration: const InputDecoration(
                          hintText: 'e.g. Thuê nhà, Ăn uống...',
                          hintStyle: TextStyle(color: Color(0xFFC4C7C7)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 3. Icon Picker Grid (4 columns, Tactile Circular Icons)
                    const Text(
                      'CHỌN BIỂU TƯỢNG',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF444748),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _iconList.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemBuilder: (context, index) {
                          final item = _iconList[index];
                          final isSelected = _selectedIcon == item['name'];
                          return GestureDetector(
                            onTap: () => setState(() => _selectedIcon = item['name']),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? const Color(0xFF212121) : const Color(0xFFEEEEEA),
                              ),
                              child: Icon(
                                item['icon'] as IconData,
                                color: isSelected ? Colors.white : const Color(0xFF444748),
                                size: 26,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 4. Color Picker Section
                    const Text(
                      'MÀU SẮC CHỦ ĐẠO',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF444748),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: _colorList.map((color) {
                          final isSelected = _selectedColor.value == color.value;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedColor = color),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected ? Border.all(color: const Color(0xFF1A1C1A), width: 2) : null,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 5. AI Keywords Section (Chips / Pills)
                    Row(
                      children: const [
                        Icon(Icons.auto_awesome, color: Color(0xFF006E1C), size: 18),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'THIẾT LẬP TỪ KHÓA NHẬN DIỆN CHO AI:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF444748),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ..._keywords.map((kw) => Chip(
                                    label: Text(kw, style: const TextStyle(fontSize: 13, color: Color(0xFF1A1C1A))),
                                    backgroundColor: const Color(0xFFF4F4F0),
                                    deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFF747878)),
                                    onDeleted: () => _removeKeyword(kw),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: const BorderSide(color: Color(0xFFE3E3DF)),
                                    ),
                                  )),
                              ActionChip(
                                label: const Text('+ Thêm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF444748))),
                                backgroundColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: const BorderSide(color: Color(0xFFC4C7C7), style: BorderStyle.solid),
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Thêm từ khóa AI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      content: TextField(
                                        controller: _keywordInputController,
                                        autofocus: true,
                                        decoration: const InputDecoration(
                                          hintText: 'Nhập từ khóa (vd: phở, cafe...)',
                                        ),
                                        onSubmitted: (_) {
                                          _addKeyword();
                                          Navigator.pop(ctx);
                                        },
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Hủy'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            _addKeyword();
                                            Navigator.pop(ctx);
                                          },
                                          child: const Text('Thêm'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // 6. Bottom Action Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A0A0A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Lưu danh mục',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
