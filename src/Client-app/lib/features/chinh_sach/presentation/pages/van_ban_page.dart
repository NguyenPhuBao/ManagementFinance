import 'package:flutter/material.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/van_ban.dart';

/// `/chinh-sach/:ma` — đọc một văn bản viết cứng (spec điều khoản viết cứng 2026-11-16 mục 1).
/// Mở được khi chưa / đã đăng nhập: router xếp nó vào loại route "mở cho cả hai phía".
class VanBanPage extends StatelessWidget {
  const VanBanPage({super.key, required this.ma});

  final String? ma;

  static const _chu = TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary);

  @override
  Widget build(BuildContext context) {
    final v = vanBanTheoMa(ma);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(v?.tenNgan ?? 'Văn bản')),
      body: v == null
          ? const Center(child: Text('Không tìm thấy văn bản'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(v.tieuDe,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700, height: 1.3, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                Text(dongPhienBan(v), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                Text(v.moDau, style: _chu),
                for (final m in v.muc) ...[
                  const SizedBox(height: 20),
                  Text(m.tieuDe,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  for (final k in m.khoi) _khoi(k),
                ],
              ],
            ),
    );
  }

  Widget _khoi(KhoiVanBan k) {
    switch (k.loai) {
      case LoaiKhoi.doan:
        return Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(k.chu, style: _chu));
      case LoaiKhoi.tieuDeCon:
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: Text(k.chu, style: _chu.copyWith(fontWeight: FontWeight.w600)),
        );
      case LoaiKhoi.gach:
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('•  ', style: _chu),
            Expanded(child: Text(k.chu, style: _chu)),
          ]),
        );
    }
  }
}

/// "Phiên bản 1.0 · Có hiệu lực từ ngày 16/11/2026".
String dongPhienBan(VanBan v) =>
    'Phiên bản ${v.phienBan} · Có hiệu lực từ ngày ${DateFormatter.formatDate(v.ngayHieuLuc)}';
