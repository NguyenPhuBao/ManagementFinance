import 'package:flutter/material.dart';

import '../../../../../core/utils/date_formatter.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../data/models/nha_cua_toi.dart';
import '../../../domain/vai_nha.dart';
import '../avatar_chu_cai.dart';
import '../ten_thanh_vien.dart';
import '../khung_the_nha.dart';

/// Dòng phụ dưới tên thành viên (spec 12.2: dòng phụ = ngày vào nhà), dùng cho cả dòng của mình lẫn dòng người khác.
class NgayVaoNha extends StatelessWidget {
  const NgayVaoNha({super.key, required this.vao});

  final DateTime vao;

  @override
  Widget build(BuildContext context) => Text('Vào nhà ${DateFormatter.formatDate(vao.toLocal())}',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary));
}

class TheThanhVienQuanLy extends StatelessWidget {
  const TheThanhVienQuanLy({
    super.key,
    required this.tv,
    required this.khoa,
    required this.onDoiVai,
    required this.onChuyenChu,
    required this.onMoiRa,
  });

  final ThanhVienNhaEntity tv;
  final bool khoa;
  final ValueChanged<VaiNha> onDoiVai;
  final VoidCallback onChuyenChu;
  final VoidCallback onMoiRa;

  /// Chip đang chọn = nền đen chữ trắng, chưa chọn = nền xám nhạt (Stitch `456078e5…`). Chip vai hiện tại không bao giờ ở
  /// kiểu "vô hiệu" (chạm vào là không làm gì); chỉ khi [khoa] mới đóng, và khi ấy vẫn phải đọc ra là đang chọn.
  Widget _chipVai(VaiNha v) {
    final chon = tv.vai == v;
    final mau = chon ? AppColors.primary : AppColors.surfaceContainerLow;
    final chu = TextStyle(color: chon ? AppColors.onPrimary : AppColors.textPrimary);
    return ChoiceChip(
      label: Text(tenVai(v)),
      selected: chon,
      showCheckmark: false,
      selectedColor: mau,
      backgroundColor: mau,
      disabledColor: mau,
      labelStyle: chu,
      side: BorderSide.none,
      onSelected: khoa
          ? null
          : (_) {
              if (!chon) onDoiVai(v);
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final vao = tv.vaoLuc;
    return KhungTheNha(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarChuCai(ten: tv.tenHienThi, co: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TenThanhVien(ten: tv.tenHienThi, laToi: false),
                    if (vao != null) NgayVaoNha(vao: vao),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final v in const [VaiNha.thanhVien, VaiNha.chiXem]) _chipVai(v),
            ],
          ),
          const Divider(height: 20, color: AppColors.outlineVariant),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              children: [
                TextButton(onPressed: khoa ? null : onChuyenChu, child: const Text('Chuyển chủ nhà')),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  onPressed: khoa ? null : onMoiRa,
                  icon: const Icon(Icons.person_remove_outlined),
                  label: const Text('Mời ra'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
