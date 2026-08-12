import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../shared/theme/app_colors.dart';

class ChooseCategoryPage extends StatefulWidget {
  final int idaccount;

  const ChooseCategoryPage({
    super.key,
    this.idaccount = 1,
  });

  @override
  State<ChooseCategoryPage> createState() => _ChooseCategoryPageState();
}

class _ChooseCategoryPageState extends State<ChooseCategoryPage> {
  int _selectedTab = 0; // 0: Khoản chi, 1: Khoản thu
  List<Category> _categories = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final classify = _selectedTab == 0 ? 'chi' : 'thu';
    final db = sl<AppDatabase>();

    final authState = context.read<AuthBloc>().state;
    final user = (authState is AuthSuccess) ? authState.user : null;
    final userIdAccount = int.tryParse(user?.id ?? '') ?? widget.idaccount;

    final list = await db.categoryDao.getByClassify(userIdAccount, classify);
    setState(() {
      _categories = list;
      _isLoading = false;
    });
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'restaurant': return Icons.restaurant;
      case 'directions_car': return Icons.directions_car;
      case 'shopping_bag': return Icons.shopping_bag;
      case 'local_hospital': return Icons.local_hospital;
      case 'school': return Icons.school;
      case 'sports_esports': return Icons.sports_esports;
      case 'home': return Icons.home;
      case 'receipt': return Icons.receipt;
      case 'attach_money': return Icons.attach_money;
      case 'trending_up': return Icons.trending_up;
      case 'card_giftcard': return Icons.card_giftcard;
      case 'work': return Icons.work;
      default: return Icons.category;
    }
  }

  List<Category> get _filteredCategories {
    if (_searchQuery.isEmpty) return _categories;
    return _categories
        .where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()))
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
          icon: const Icon(Icons.arrow_back, color: AppColors.primary, size: 28),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Chọn danh mục',
          style: TextStyle(
            color: AppColors.primary,
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  children: [
                    _buildSegmentControl(),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                    const SizedBox(height: 24),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildCategoriesGrid(),
                  ],
                ),
              ),
            ),
            _buildActionBottom(),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentControl() {
    return Container(
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
  }

  Widget _buildSegmentButton(int index, String title) {
    bool isSelected = _selectedTab == index;

    return GestureDetector(
      onTap: () {
        if (_selectedTab != index) {
          setState(() {
            _selectedTab = index;
          });
          _loadCategories();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  )
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        decoration: const InputDecoration(
          hintText: 'Tìm kiếm nhóm...',
          hintStyle: TextStyle(color: AppColors.outlineVariant, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: AppColors.outline),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    final list = _filteredCategories;

    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Text(
          'Không tìm thấy danh mục',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.75,
        mainAxisSpacing: 24,
        crossAxisSpacing: 8,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final cat = list[index];
        return InkWell(
          onTap: () {
            context.pop(cat);
          },
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFE3E3DF),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getCategoryIcon(cat.icon), color: const Color(0xFF444748)),
              ),
              const SizedBox(height: 8),
              Text(
                cat.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionBottom() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add, color: Colors.white, size: 18),
        label: const Text(
          'Thêm nhóm mới',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }
}
