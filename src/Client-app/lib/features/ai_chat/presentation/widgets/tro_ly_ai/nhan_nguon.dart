import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../../../domain/duong_hoi.dart';

/// Nguồn của một câu trả lời AI (spec trợ lý online 2026-10-11 §3.4). Câu cố định
/// của hệ thống không có nhãn — chúng không đến từ AI nào.
enum NguonTraLoi { trenMay, online }

/// Stitch `1896d02b…` dùng #454743 cho chữ nhãn — không dùng `AppColors.onSurfaceVariant`
/// (#767872: 3,8:1 trên nền trang, dưới AA 4,5 cho chữ 12 px) — cùng lý do với
/// `hop_thoai_bi_day_ra.dart`, `bill_page.dart`.
const Color _mauChu = Color(0xFF454743);

/// Nhãn dưới bong bóng (Stitch `1896d02b…`): chấm 6 px + chữ 12 px. Chấm xanh = online êm,
/// đỏ = có ghi chú (rơi / gián đoạn / đã dừng), xám = trên máy bình thường.
class NhanNguon extends StatelessWidget {
  const NhanNguon({super.key, required this.nguon, this.ghiChu});
  final NguonTraLoi nguon;
  final String? ghiChu;

  @override
  Widget build(BuildContext context) {
    final ten = nguon == NguonTraLoi.online ? kNguonOnline : kNguonTrenMay;
    final Color mauCham = ghiChu != null
        ? AppColors.error
        : (nguon == NguonTraLoi.online ? const Color(0xFF006E1C) : _mauChu);
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const Key('cham-nguon'),
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: mauCham, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              ghiChu == null ? ten : '$ten · $ghiChu',
              key: const Key('nhan-nguon'),
              style: const TextStyle(fontSize: 12, color: _mauChu),
            ),
          ),
        ],
      ),
    );
  }
}
