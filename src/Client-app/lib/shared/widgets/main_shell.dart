import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/di/injection_container.dart';
import '../../core/ui/thong_bao_nhanh.dart';
import '../theme/app_colors.dart';
import 'thoat_hai_lan.dart';

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  void _onItemTapped(int index, BuildContext context) {
    if (index == 2) {
      // FAB tapped. Use push so it covers the screen.
      context.push('/add');
      return;
    }

    // Map UI Index back to Branch Index
    int branchIndex = index;
    if (index > 2) {
      branchIndex = index - 1;
    }

    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  int _getUIIndex(int branchIndex) {
    if (branchIndex >= 2) return branchIndex + 1;
    return branchIndex;
  }

  @override
  Widget build(BuildContext context) {
    final uiIndex = _getUIIndex(navigationShell.currentIndex);

    return Scaffold(
      // Back ở tab khác thì về Trang chủ; ở Trang chủ thì "Nhấn lần nữa để
      // thoát" (UX 2026-09-19, E3). Bản trước không có PopScope: Back là ra
      // launcher ngay.
      body: ThoatHaiLan(
        laTabDau: () => navigationShell.currentIndex == 0,
        veTabDau: () => navigationShell.goBranch(0),
        baoNhanLanNua: () =>
            sl<ThongBaoNhanh>().hien('Nhấn lần nữa để thoát'),
        child: navigationShell,
      ),
      backgroundColor: AppColors.background,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onItemTapped(2, context),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 4, 
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 32),
      ),
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(context, 'Trang chủ', Icons.home_outlined, 0, uiIndex),
            _buildNavItem(context, 'Phân tích', Icons.analytics_outlined, 1, uiIndex),
            const SizedBox(width: 72), // Space for FAB
            // ⚠️ Nhãn "Giao dịch" chứ KHÔNG "Sổ giao dịch": ô nhãn rộng CỐ
            // ĐỊNH 72dp (xem `_buildNavItem`) và mọi nhãn vừa được đều ≤ 9 ký
            // tự — "Sổ giao dịch" là 12. Tên đầy đủ vẫn ở tiêu đề trang.
            //
            // Icon `list_alt` chứ không `receipt_long`: `receipt_long` đã là
            // "Hóa đơn & Dịch vụ" trong drawer, và một glyph mang hai nghĩa
            // đúng là lỗi D8 vừa gỡ cùng ngày (heo đất từng vừa là Ngân sách
            // vừa là Mục tiêu tiết kiệm).
            _buildNavItem(context, 'Giao dịch', Icons.list_alt_outlined, 3, uiIndex),
            _buildNavItem(context, 'Cá nhân', Icons.person_outline, 4, uiIndex),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, String label, IconData icon, int itemIndex, int currentIndex) {
    final isSelected = itemIndex == currentIndex;

    return GestureDetector(
      onTap: () => _onItemTapped(itemIndex, context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 72,
        height: 64,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceContainerHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
