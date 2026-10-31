import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../../../data/models/nha_cua_toi.dart';
import '../../../domain/vai_nha.dart';
import 'khung_the_nha.dart';

class AvatarChuCai extends StatelessWidget {
  const AvatarChuCai({super.key, required this.ten, this.co = 40});

  final String ten;
  final double co;

  @override
  Widget build(BuildContext context) {
    final t = ten.trim();
    final chu = t.isEmpty ? '?' : String.fromCharCode(t.runes.first).toUpperCase();
    // Nền và chữ khác nhau thật: `primary` trên `primaryContainer` là một màu (quét 13).
    return Container(
      width: co,
      height: co,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppColors.surfaceContainerHigh, shape: BoxShape.circle),
      child: Text(chu, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    );
  }
}

class NhanVai extends StatelessWidget {
  const NhanVai({super.key, required this.vai});

  final VaiNha vai;

  @override
  Widget build(BuildContext context) {
    final chu = vai == VaiNha.chu;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chu ? AppColors.primary : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tenVai(vai),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: chu ? AppColors.onPrimary : AppColors.textPrimary),
      ),
    );
  }
}

/// Tên + nhãn *Bạn*: chỉ tên bị cắt, nhãn luôn còn nguyên (spec 12.2).
class TenThanhVien extends StatelessWidget {
  const TenThanhVien({super.key, required this.ten, required this.laToi});

  final String ten;
  final bool laToi;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Flexible(child: Text(ten, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (laToi) ...[
            const SizedBox(width: 6),
            Text('Bạn', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          ],
        ],
      );
}

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
