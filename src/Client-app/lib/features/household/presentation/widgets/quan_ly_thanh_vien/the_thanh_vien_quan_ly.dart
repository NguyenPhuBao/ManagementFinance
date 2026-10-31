import 'package:flutter/material.dart';

import '../../../../../core/utils/date_formatter.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../data/models/nha_cua_toi.dart';
import '../../../domain/vai_nha.dart';
import '../nha_minh/danh_sach_thanh_vien.dart';
import '../nha_minh/khung_the_nha.dart';

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
                    if (vao != null)
                      Text('Vào nhà ${DateFormatter.formatDate(vao.toLocal())}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final v in const [VaiNha.thanhVien, VaiNha.chiXem])
                ChoiceChip(
                  label: Text(tenVai(v)),
                  selected: tv.vai == v,
                  onSelected: khoa || tv.vai == v ? null : (_) => onDoiVai(v),
                ),
            ],
          ),
          const Divider(height: 20),
          Wrap(
            alignment: WrapAlignment.end,
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
        ],
      ),
    );
  }
}
