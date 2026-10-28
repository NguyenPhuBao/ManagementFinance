/// Khung thẻ và các kiểu hàng (công tắc, bấm, giờ im lặng), dòng chú thích và màn "chưa đăng nhập" của trang Cài đặt
/// thông báo (`notification_settings_page.dart`), dời nguyên văn khỏi trang.
library;

import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../../../../premium/presentation/widgets/the_khoa_quyen.dart';

class TheCaiDat extends StatelessWidget {
  const TheCaiDat({
    super.key,
    required this.tieuDe,
    required this.children,
    this.nhanMoi = false,
  });

  final String tieuDe;
  final List<Widget> children;
  final bool nhanMoi;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tieuDe,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (nhanMoi)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Mới',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSecondaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class HangCongTac extends StatelessWidget {
  const HangCongTac({
    super.key,
    required this.khoa,
    required this.icon,
    required this.nhan,
    required this.phu,
    required this.giaTri,
    required this.onChanged,
    this.biKhoa = false,
  });

  final Key khoa;
  final IconData icon;
  final String nhan;
  final String phu;
  final bool giaTri;
  final ValueChanged<bool> onChanged;

  /// Công tắc khoá theo quyền gói (B1) — vẽ mờ + ổ khoá qua [CongTacTheoQuyen] (G111).
  final bool biKhoa;

  @override
  Widget build(BuildContext context) {
    return KhungCaiDat(
      icon: icon,
      nhan: nhan,
      phu: phu,
      trailing: CongTacTheoQuyen(
        khoaCongTac: khoa,
        value: giaTri,
        onChanged: onChanged,
        biKhoa: biKhoa,
        activeThumbColor: Colors.white,
        activeTrackColor: const Color(0xFF006E1C),
      ),
    );
  }
}

class HangBam extends StatelessWidget {
  const HangBam({
    super.key,
    required this.icon,
    required this.nhan,
    required this.phu,
    required this.trailing,
    required this.onTap,
    this.khoa,
  });

  final IconData icon;
  final String nhan;
  final String phu;
  final Widget trailing;
  final VoidCallback onTap;
  final Key? khoa;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: khoa,
      onTap: onTap,
      child: KhungCaiDat(icon: icon, nhan: nhan, phu: phu, trailing: trailing),
    );
  }
}

/// Một mốc của khoảng im lặng. Lưu bằng **số phút từ nửa đêm**, nên phải quy
/// đổi cả hai chiều ngay tại đây — chỗ duy nhất biết cả hai đơn vị.
class HangGioImLang extends StatelessWidget {
  const HangGioImLang({
    super.key,
    required this.nhan,
    required this.phut,
    required this.onChon,
  });

  final String nhan;
  final int phut;
  final ValueChanged<int> onChon;

  @override
  Widget build(BuildContext context) {
    final gio = TimeOfDay(hour: phut ~/ 60, minute: phut % 60);

    return HangBam(
      icon: Icons.nightlight_outlined,
      nhan: nhan,
      phu: nhan == 'Từ' ? 'Bắt đầu im lặng.' : 'Kết thúc im lặng.',
      trailing: Text(
        '${gio.hour.toString().padLeft(2, '0')}:'
        '${gio.minute.toString().padLeft(2, '0')}',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
      onTap: () async {
        final chon = await showTimePicker(context: context, initialTime: gio);
        if (chon == null) return;
        onChon(chon.hour * 60 + chon.minute);
      },
    );
  }
}

class KhungCaiDat extends StatelessWidget {
  const KhungCaiDat({
    super.key,
    required this.icon,
    required this.nhan,
    required this.phu,
    required this.trailing,
  });

  final IconData icon;
  final String nhan;
  final String phu;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nhan,
                  style:
                      const TextStyle(fontSize: 16, color: AppColors.primary),
                ),
                const SizedBox(height: 2),
                Text(
                  phu,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

/// Dòng chú thích cuối thẻ. Chữ nhỏ, màu phụ — nó giải thích một ngoại lệ chứ
/// không phải một hàng điều khiển.
class GhiChuCaiDat extends StatelessWidget {
  const GhiChuCaiDat(this.noiDung, {super.key});

  final String noiDung;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Text(
        noiDung,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }
}

class ChuaDangNhapCaiDat extends StatelessWidget {
  const ChuaDangNhapCaiDat({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Vui lòng đăng nhập để cài đặt thông báo.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
