/// Dòng trạng thái một dòng dưới ô Nhập nhanh — *"Đang ghi âm…"*, *"Đang chép lời bằng AI trên máy…"* (C4 §2.1). Dòng
/// *"Đang kiểm số tiền bằng AI…"* (C4 §3.4) đã gỡ 2026-10-22 cùng đường kiểm chéo ở nền. Vòng xoay nhỏ, hoặc chấm đỏ
/// khi đang ghi; nút chữ Huỷ tuỳ chọn.
library;

import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';

class DongDangNghe extends StatelessWidget {
  const DongDangNghe({super.key, required this.chu, this.onHuy, this.khoaHuy, this.chamDo = false});

  final String chu;
  final VoidCallback? onHuy;
  final Key? khoaHuy;

  /// Chấm đỏ thay vòng xoay — đang GHI âm (người dùng đang nói), chưa phải đang chờ máy.
  final bool chamDo;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            if (chamDo)
              // Đỏ lỗi — Stitch `d696e81e…` (người dùng chốt 2026-10-16).
              Container(
                key: const Key('dong-dang-nghe-cham'),
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
              )
            else
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(chu, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
            if (onHuy != null) TextButton(key: khoaHuy, onPressed: onHuy, child: const Text('Huỷ')),
          ],
        ),
      );
}
