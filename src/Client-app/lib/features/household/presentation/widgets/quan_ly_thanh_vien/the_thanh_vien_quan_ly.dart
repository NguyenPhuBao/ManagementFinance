import 'package:flutter/material.dart';

import '../../../../../core/utils/date_formatter.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../data/models/nha_cua_toi.dart';
import '../../../domain/vai_nha.dart';
import '../avatar_chu_cai.dart';
import '../chip_vai_nha.dart';
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

  /// Chip vai hiện tại không bao giờ ở kiểu "vô hiệu" (chạm vào là không làm gì); chỉ khi [khoa] mới đóng, và khi ấy vẫn
  /// phải đọc ra là đang chọn. Kiểu chip dùng chung với màn Mời (`ChipVaiNha`).
  Widget _chipVai(VaiNha v) {
    final chon = tv.vai == v;
    return ChipVaiNha(
      vai: v,
      chon: chon,
      onChon: khoa
          ? null
          : () {
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
              AvatarChuCai(ten: tv.tenHienThi, idaccount: tv.idaccount, co: 44),
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
          // Số đo Stitch `quan_ly_tv`: hàng thao tác sát vạch và đáy thẻ, *Mời ra* sát mép phải vạch.
          const Divider(height: 4, color: AppColors.outlineVariant),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              children: [
                // `shrinkWrap`: vùng chạm tối thiểu 48 dp làm hàng cao hơn nút và dư một khoảng dưới thẻ.
                TextButton(
                  style: TextButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  onPressed: khoa ? null : onChuyenChu,
                  child: const Text('Chuyển chủ nhà'),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.fromLTRB(8, 4, 0, 4),
                  ),
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
