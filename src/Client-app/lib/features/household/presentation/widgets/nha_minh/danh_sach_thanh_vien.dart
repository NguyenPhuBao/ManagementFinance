import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../../../data/models/nha_cua_toi.dart';
import '../../../domain/vai_nha.dart';
import '../avatar_chu_cai.dart';
import '../khung_the_nha.dart';
import '../nhan_vai.dart';
import '../ten_thanh_vien.dart';

/// Chủ nhà đứng đầu, còn lại giữ thứ tự máy chủ trả (Stitch `e462a7e8…`). Sắp ổn định: không đụng danh sách gốc.
List<ThanhVienNhaEntity> chuNhaDungDau(List<ThanhVienNhaEntity> ds) =>
    [...ds.where((t) => t.vai == VaiNha.chu), ...ds.where((t) => t.vai != VaiNha.chu)];

class DanhSachThanhVien extends StatelessWidget {
  const DanhSachThanhVien({super.key, required this.thanhVien, required this.idToi});

  final List<ThanhVienNhaEntity> thanhVien;
  final int? idToi;

  @override
  Widget build(BuildContext context) {
    final ds = chuNhaDungDau(thanhVien);
    return KhungTheNha(
      child: Column(
        children: [
          for (var i = 0; i < ds.length; i++) ...[
            if (i > 0) const Divider(height: 24, color: AppColors.outlineVariant),
            Row(
              children: [
                AvatarChuCai(ten: ds[i].tenHienThi, idaccount: ds[i].idaccount),
                const SizedBox(width: 12),
                Expanded(child: TenThanhVien(ten: ds[i].tenHienThi, laToi: ds[i].idaccount == idToi)),
                const SizedBox(width: 8),
                NhanVai(vai: ds[i].vai),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
