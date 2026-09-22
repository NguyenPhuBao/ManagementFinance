import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

/// Một mục trong drawer: nhãn, icon, và route đích.
class MucDrawer {
  const MucDrawer(this.nhan, this.icon, this.duong);

  final String nhan;
  final IconData icon;
  final String duong;
}

/// Danh sách mục của drawer Trang chủ.
///
/// ⚠️ **Nguyên tắc từ 2026-09-19 (nhóm D, lối B):** thanh dưới giữ việc hằng
/// ngày, drawer giữ **mọi thứ còn lại**, và không đích nào xuất hiện ở cả hai
/// chỗ. Ba mục "Thống kê", "Cá nhân", "Cài đặt" đã rút khỏi đây vì chúng có
/// tab riêng; "Ngân sách" thì đi ngược chiều — rời thanh dưới về đây. Bản
/// trước theo màn Stitch *"FlowMoney Home with Side Menu Drawer"* có 9 mục
/// chia hai nhóm, trong đó **bốn** mục lặp lại đúng thứ thanh dưới đã có.
///
/// Là hằng công khai để test đối chiếu **từng đường với router thật**: bản
/// trước trỏ "Xuất báo cáo" vào `/reports` — một route không tồn tại — rồi
/// che bằng SnackBar "đang phát triển" trong khi trang ấy đã có từ 2026-09-09
/// ở `/export-report`. Route và lời gọi là hai chuỗi rời nhau nên
/// `flutter analyze` không nói gì (cùng loại lỗi với test quét đường liên kết
/// ngân hàng đã gỡ — và test ấy quét cả chú thích, nên đừng viết nguyên văn
/// chuỗi ấy ở đây).
const List<MucDrawer> kMucDrawer = [
  MucDrawer('Quản lý ví', Icons.account_balance_wallet, '/wallets'),
  MucDrawer('Mục tiêu tiết kiệm', Icons.track_changes, '/goals'),
  MucDrawer('Ngân sách', Icons.savings, '/budget'),
  MucDrawer('Hóa đơn & Dịch vụ', Icons.receipt_long, '/bills'),
  // ⚠️ Mục này **chưa bao giờ** có trong drawer cũ — nó sống ở nhóm "QUẢN LÝ
  // TÀI KHOẢN" của tab Cá nhân, nên drawer không cần. Nhóm D bỏ nhóm ấy đi và
  // bản spec sáu mục thừa hưởng đúng chỗ thiếu, nên trang Quản lý danh mục
  // **mất hẳn lối vào qua menu** — chỉ còn một nút chôn trong bảng chọn danh
  // mục của màn Thêm giao dịch. Người dùng báo ngay trong ngày.
  //
  // Bài học: chuyển một nhóm menu đi thì phải soát **từng mục** xem đích đến
  // đã có cửa nào chưa, đừng cho rằng danh sách nhận là đủ. Ca
  // "MỌI trang tính năng đều vào được từ menu" nay canh chỗ đó.
  MucDrawer('Danh mục', Icons.category_outlined, '/categories'),
  MucDrawer('Xuất báo cáo', Icons.description, '/export-report'),
  MucDrawer('Trợ lý AI', Icons.smart_toy, '/ai-chat'),
];

/// Drawer của Trang chủ. Chỉ nhận dữ liệu và callback — không đọc bloc, không
/// điều hướng — để test dựng được một mình.
///
/// Tách khỏi `HomePage` ngày 2026-09-19 sau lượt đánh giá UX. Ba lỗi đo trên
/// máy ảo, cả ba nằm ở đây: đường `/reports` sai (xem [kMucDrawer]); avatar là
/// vòng đen trống vì chữ cái đầu tô `AppColors.primary` trên nền
/// `AppColors.primaryContainer` mà hai màu ấy là **một**; và thiếu "Đăng xuất"
/// ở đáy dù màn Stitch có.
class DrawerTrangChu extends StatelessWidget {
  const DrawerTrangChu({
    super.key,
    required this.ten,
    required this.email,
    required this.onChon,
    required this.onDangXuat,
  });

  /// Tên hiển thị; rỗng thì avatar hiện "U" như bản cũ.
  final String ten;
  final String email;

  /// Người dùng chạm một mục; nhận [MucDrawer.duong].
  final void Function(String duong) onChon;
  final VoidCallback onDangXuat;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            _dauDrawer(),
            const Divider(color: AppColors.outlineVariant),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                // Vạch ngăn giữa danh sách đã bỏ cùng nhóm tài khoản
                // (2026-09-19): sáu mục còn lại là một nhóm duy nhất — "mọi
                // thứ không có ở thanh dưới".
                children: [for (final m in kMucDrawer) _muc(m)],
              ),
            ),
            const Divider(color: AppColors.outlineVariant),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.expense),
              title: const Text(
                'Đăng xuất',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.expense),
              ),
              dense: true,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 32),
              onTap: onDangXuat,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _dauDrawer() {
    final chuCai = ten.isNotEmpty ? ten[0].toUpperCase() : 'U';
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primaryContainer,
            child: Text(
              chuCai,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                // `onPrimaryContainer`, KHÔNG phải `primary`: `primary` và
                // `primaryContainer` cùng là #1A1A19, chữ đen trên nền đen.
                color: AppColors.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ten.isNotEmpty ? ten : 'Người dùng',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _muc(MucDrawer m) {
    return ListTile(
      leading: Icon(m.icon, color: AppColors.primary),
      title: Text(m.nhan,
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: AppColors.primary)),
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () => onChon(m.duong),
    );
  }
}
