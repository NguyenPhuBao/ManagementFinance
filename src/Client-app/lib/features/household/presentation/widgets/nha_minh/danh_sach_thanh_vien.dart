import 'package:flutter/material.dart';

import '../../../data/models/nha_cua_toi.dart';
import '../avatar_chu_cai.dart';
import '../khung_the_nha.dart';
import '../nhan_vai.dart';
import '../ten_thanh_vien.dart';

class DanhSachThanhVien extends StatelessWidget {
  const DanhSachThanhVien({super.key, required this.thanhVien, required this.idToi});

  final List<ThanhVienNhaEntity> thanhVien;
  final int? idToi;

  @override
  Widget build(BuildContext context) => KhungTheNha(
        child: Column(
          children: [
            for (var i = 0; i < thanhVien.length; i++) ...[
              if (i > 0) const Divider(height: 24),
              Row(
                children: [
                  AvatarChuCai(ten: thanhVien[i].tenHienThi),
                  const SizedBox(width: 12),
                  Expanded(child: TenThanhVien(ten: thanhVien[i].tenHienThi, laToi: thanhVien[i].idaccount == idToi)),
                  const SizedBox(width: 8),
                  NhanVai(vai: thanhVien[i].vai),
                ],
              ),
            ],
          ],
        ),
      );
}
