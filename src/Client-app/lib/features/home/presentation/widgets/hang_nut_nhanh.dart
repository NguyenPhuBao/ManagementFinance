// lib/features/home/presentation/widgets/hang_nut_nhanh.dart
/// Hàng nút nhanh ở Trang chủ — tách từ `_buildActionItem` của `home_page.dart` ngày 2026-10-12 khi thêm nút *Nói* (C4
/// §2.3, Stitch *"Trang chủ - Năm nút nhanh có Nói"*). Năm vòng 56 dp `spaceBetween` tràn ở 320 dp; nay mỗi nút một ô
/// `Expanded`, vòng 52 dp. Nhãn co **đều** cả năm (`NhanCoDeu`, theo nhãn rộng nhất) và mỗi ô chừa 2 dp hai bên — từ
/// 2026-10-26 (Realme 320 dp: *"Thêm thuThêm chi"* dính nhau; cỡ chữ 1,6: *"Quét"* / *"Nói"* to hơn hẳn — mỗi nhãn
/// từng tự co riêng bằng `FittedBox`). Kiểu dáng theo Stitch từ 2026-10-16 (người dùng chốt): chỉ *Thêm
/// chi* nền đặc `#1A1A19`, bốn nút còn lại nền trắng viền `#D5D5CE`, nhãn cách vòng 6 dp. Giữ `Expanded` thay
/// `justify-between` của Stitch — kiểu ấy tràn ở 320 dp.
library;

import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/nhan_co_deu.dart';
import '../../../premium/domain/quyen_tinh_nang.dart';
import '../../../premium/presentation/bloc/co_quyen.dart';
import '../../../premium/presentation/widgets/nut_nang_cap.dart';
import '../../../premium/presentation/widgets/the_khoa_quyen.dart';

class NutNhanh {
  const NutNhanh({required this.bieuTuong, required this.nhan, required this.dam, required this.onTap, this.khoa});

  final IconData bieuTuong;
  final String nhan;

  /// Nền đặc `#1A1A19` — chỉ *Thêm chi* (Stitch `c8f09f19…`); còn lại nền trắng viền.
  final bool dam;
  final VoidCallback onTap;
  final Key? khoa;
}

/// Đích của nút *Nói*: có quyền *Nhập nhanh bằng câu* → form mở và nghe ngay; Basic → màn Nâng cấp mở bằng tên tính năng.
String duongNutNoi({required bool coQuyen}) => coQuyen ? '/add?noi=1' : duongNangCap(quyen: MaQuyen.aiQuickInput);

class HangNutNhanh extends StatelessWidget {
  const HangNutNhanh({super.key, required this.nut});

  final List<NutNhanh> nut;

  @override
  Widget build(BuildContext context) {
    // Quyền `quick_action_shortcuts` (B1, spec 2026-10-27 mục 3): MỘT dòng khoá mỏng thay cả hàng — nút [+] thanh dưới
    // vẫn mở form Thêm giao dịch.
    if (!context.coQuyen(MaQuyen.quickActionShortcuts)) {
      return const DongKhoaQuyen(ma: MaQuyen.quickActionShortcuts);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final n in nut) Expanded(child: _Nut(n, nhom: [for (final m in nut) m.nhan]))
      ],
    );
  }
}

class _Nut extends StatelessWidget {
  const _Nut(this.n, {required this.nhom});
  final NutNhanh n;

  /// Nhãn cả năm nút — để mọi nhãn co cùng một hệ số.
  final List<String> nhom;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: n.khoa,
        onTap: n.onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              // Stitch `c8f09f19…`: đậm = `bg-[#1A1A19] shadow-md`, trắng = `border-[#D5D5CE] shadow-sm`.
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: n.dam ? AppColors.primary : Colors.white,
                border: n.dam ? null : Border.all(color: const Color(0xFFD5D5CE)),
                boxShadow: n.dam
                    ? const [
                        BoxShadow(color: Color(0x1A000000), offset: Offset(0, 4), blurRadius: 6, spreadRadius: -1),
                        BoxShadow(color: Color(0x1A000000), offset: Offset(0, 2), blurRadius: 4, spreadRadius: -2),
                      ]
                    : const [BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2)],
              ),
              child: Icon(n.bieuTuong, color: n.dam ? Colors.white : AppColors.primary, size: 24),
            ),
            const SizedBox(height: 6),
            // 2 dp mỗi bên: hai nhãn kề nhau không bao giờ chạm (Realme 320 dp).
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: NhanCoDeu(
                n.nhan,
                nhom: nhom,
                kieu: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.primary),
              ),
            ),
          ],
        ),
      );
}
