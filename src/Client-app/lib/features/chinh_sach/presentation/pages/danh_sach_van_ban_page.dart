import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/van_ban.dart';

/// `/chinh-sach` — Cá nhân → "Điều khoản & chính sách" (Stitch `8b53d373…` "Cá nhân - Điều khoản & chính sách").
class DanhSachVanBanPage extends StatelessWidget {
  const DanhSachVanBanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Điều khoản & chính sách')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            // Material trong suốt: ListTile trong Container có màu cần Material riêng (assertion Flutter 3.47).
            child: Material(
              type: MaterialType.transparency,
              child: Column(children: [
                for (final (i, v) in danhSachVanBan.indexed) ...[
                  if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.outlineVariant),
                  ListTile(
                    key: Key('van-ban-${v.ma}'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(v.tenNgan,
                        style: const TextStyle(fontSize: 16, color: AppColors.textPrimary)),
                    subtitle: Text('Phiên bản ${v.phienBan} · ${DateFormatter.formatDate(v.ngayHieuLuc)}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    onTap: () => context.push('/chinh-sach/${v.ma}'),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
