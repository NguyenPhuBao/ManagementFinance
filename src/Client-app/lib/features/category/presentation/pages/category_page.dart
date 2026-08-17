import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  bool _isExpense = true;
  int _selectedCategoryIndex = 0;
  bool _isLoading = true;
  List<Category> _categories = [];

  final TextEditingController _newKeywordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _newKeywordController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final authState = context.read<AuthBloc>().state;
    final user = (authState is AuthSuccess) ? authState.user : null;
    final userIdAccount = int.tryParse(user?.id ?? '') ?? 1;

    final classify = _isExpense ? 'chi' : 'thu';
    final db = sl<AppDatabase>();
    final list = await db.categoryDao.getByClassify(userIdAccount, classify);

    if (mounted) {
      setState(() {
        _categories = list;
        _isLoading = false;
        if (_selectedCategoryIndex >= _categories.length) {
          _selectedCategoryIndex = 0;
        }
      });
    }
  }

  IconData _getCategoryIcon(String iconName, [String? categoryName]) {
    switch (iconName) {
      case 'restaurant': return Icons.restaurant;
      case 'directions_car': return Icons.directions_car;
      case 'shopping_bag': return Icons.shopping_bag;
      case 'receipt_long':
      case 'receipt': return Icons.receipt_long;
      case 'movie': return Icons.movie;
      case 'sports_esports': return Icons.sports_esports;
      case 'favorite': return Icons.favorite;
      case 'local_hospital': return Icons.local_hospital;
      case 'school': return Icons.school;
      case 'home': return Icons.home;
      case 'work': return Icons.work;
      case 'card_giftcard': return Icons.card_giftcard;
      case 'trending_up': return Icons.trending_up;
      case 'laptop': return Icons.laptop;
      case 'person_add': return Icons.person_add;
      case 'person_remove': return Icons.person_remove;
      case 'payment': return Icons.payment;
      case 'attach_money': return Icons.attach_money;
      case 'more_horiz': return Icons.more_horiz;
    }

    if (categoryName != null) {
      final name = categoryName.toLowerCase();
      if (name.contains('ăn') || name.contains('uống')) return Icons.restaurant;
      if (name.contains('xe') || name.contains('di chuyển')) return Icons.directions_car;
      if (name.contains('sắm')) return Icons.shopping_bag;
      if (name.contains('y tế') || name.contains('sức khoẻ') || name.contains('sức khỏe') || name.contains('thuốc')) return Icons.local_hospital;
      if (name.contains('học') || name.contains('giáo dục')) return Icons.school;
      if (name.contains('trí') || name.contains('game') || name.contains('phim')) return Icons.sports_esports;
      if (name.contains('nhà')) return Icons.home;
      if (name.contains('đơn') || name.contains('dịch vụ')) return Icons.receipt_long;
      if (name.contains('lương')) return Icons.work;
      if (name.contains('thưởng') || name.contains('quà')) return Icons.card_giftcard;
      if (name.contains('đầu tư') || name.contains('lãi')) return Icons.trending_up;
      if (name.contains('vay') || name.contains('nợ')) return Icons.attach_money;
    }

    return Icons.category;
  }

  Color _parseColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) return const Color(0xFF10B981);
    try {
      final hex = colorHex.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF10B981);
  }

  List<String> _getKeywordsForCategory(Category cat) {
    // Mặc định hoặc lấy từ csdl
    if (cat.name.contains('Ăn uống')) return ['grabfood', 'phở', 'cafe', 'highland', 'shopeefood'];
    if (cat.name.contains('Di chuyển')) return ['grab', 'be', 'xăng', 'gửi xe'];
    if (cat.name.contains('Mua sắm')) return ['shopee', 'lazada', 'quần áo', 'siêu thị'];
    if (cat.name.contains('Hoá đơn') || cat.name.contains('Hóa đơn')) return ['điện', 'nước', 'internet', 'tiền nhà'];
    if (cat.name.contains('Lương')) return ['lương', 'thu nhập', 'thưởng'];
    if (cat.name.contains('Thưởng')) return ['quà', 'lì xì', 'thưởng nóng'];
    if (cat.name.contains('Đầu tư')) return ['lãi suất', 'chứng khoán', 'cổ tức'];
    return [cat.name.toLowerCase(), 'thanh toán'];
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = (_categories.isNotEmpty && _selectedCategoryIndex < _categories.length)
        ? _categories[_selectedCategoryIndex]
        : null;

    final keywords = selectedCategory != null ? _getKeywordsForCategory(selectedCategory) : <String>[];

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F5),
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1C1A)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Danh mục chi tiêu',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1C1A),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Segmented Tabs Control (Khoản chi / Khoản thu)
              Container(
                padding: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E8E4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (!_isExpense) {
                            setState(() {
                              _isExpense = true;
                              _selectedCategoryIndex = 0;
                            });
                            _loadCategories();
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          decoration: BoxDecoration(
                            color: _isExpense ? const Color(0xFF1A1A19) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Khoản chi',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isExpense ? Colors.white : const Color(0xFF006E1C),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_isExpense) {
                            setState(() {
                              _isExpense = false;
                              _selectedCategoryIndex = 0;
                            });
                            _loadCategories();
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          decoration: BoxDecoration(
                            color: !_isExpense ? const Color(0xFF1A1A19) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Khoản thu',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: !_isExpense ? Colors.white : const Color(0xFF006E1C),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24.0),

              // 2. Main Container
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD6D6D2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_categories.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Text('Chưa có danh mục nào.'),
                              ),
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _categories.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.1,
                              ),
                              itemBuilder: (context, index) {
                                final cat = _categories[index];
                                final isSelected = _selectedCategoryIndex == index;
                                final catColor = _parseColor(cat.colour);
                                final iconData = _getCategoryIcon(cat.icon, cat.name);

                                return GestureDetector(
                                  onTap: () => setState(() => _selectedCategoryIndex = index),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFFAF9F5) : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF1A1A19) : const Color(0xFFE3E3DF),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: catColor.withOpacity(0.15),
                                          ),
                                          child: Icon(
                                            iconData,
                                            color: catColor,
                                            size: 26,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          cat.name,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1C1A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                          if (selectedCategory != null) ...[
                            const SizedBox(height: 24.0),
                            const Divider(color: Color(0xFFE3E3DF), height: 1),
                            const SizedBox(height: 20.0),

                            // Selected Category Header
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _parseColor(selectedCategory.colour).withOpacity(0.15),
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(selectedCategory.icon, selectedCategory.name),
                                    color: _parseColor(selectedCategory.colour),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  selectedCategory.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1C1A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // AI Keywords Title
                            const Text(
                              'Thiết lập từ khóa nhận diện cho AI (tách biệt bằng dấu phẩy):',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF006E1C),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // AI Keywords Chips List + Add Keyword Action Button
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ...keywords.map((kw) => Chip(
                                      label: Text(kw, style: const TextStyle(fontSize: 12, color: Color(0xFF1A1C1A))),
                                      backgroundColor: const Color(0xFFF4F4F0),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        side: const BorderSide(color: Color(0xFFC7C6CD)),
                                      ),
                                    )),
                                ActionChip(
                                  label: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add, size: 14, color: Color(0xFF1A1C1A)),
                                      SizedBox(width: 2),
                                      Text('Thêm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1A))),
                                    ],
                                  ),
                                  backgroundColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: const BorderSide(color: Color(0xFF77767D), style: BorderStyle.solid),
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Thêm từ khóa AI mới', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        content: TextField(
                                          controller: _newKeywordController,
                                          autofocus: true,
                                          decoration: const InputDecoration(
                                            hintText: 'Nhập từ khóa (vd: phở, cafe...)',
                                          ),
                                          onSubmitted: (txt) {
                                            if (txt.trim().isNotEmpty) {
                                              setState(() {
                                                keywords.add(txt.trim());
                                                _newKeywordController.clear();
                                              });
                                            }
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
                                              if (_newKeywordController.text.trim().isNotEmpty) {
                                                setState(() {
                                                  keywords.add(_newKeywordController.text.trim());
                                                  _newKeywordController.clear();
                                                });
                                              }
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
                          const SizedBox(height: 24),

                          // Big Action Button: "Thêm danh mục mới"
                          ElevatedButton(
                            onPressed: () async {
                              await context.push('/categories/add');
                              _loadCategories();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A1A19),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Thêm nhóm mới',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
