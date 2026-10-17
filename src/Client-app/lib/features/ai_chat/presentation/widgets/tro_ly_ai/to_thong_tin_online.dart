import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';

const String kTieuDeToOnline = 'Trợ lý online';
const String kThanToOnline =
    'Khi có mạng, câu hỏi của bạn cùng bản tóm tắt tài chính (tỉ lệ chi theo nhóm, điểm sức khoẻ tài chính; khi cần, số tiền một vài giao dịch với ghi chú đã che thông tin cá nhân) được gửi tới máy chủ FlowMoney và Google Gemini để trả lời. Mất mạng thì AI trên máy trả lời, không gửi gì. Đổi lại được ở Cài đặt AI.';

enum LuaChonToThongTin { daHieu, chiTrenMay }

/// Tờ thông tin lần đầu dùng Trợ lý online (Stitch `7a6519d6…`). Trả `null` khi người dùng
/// vuốt / chạm ngoài tắt tờ — người gọi coi như chưa chọn.
Future<LuaChonToThongTin?> moToThongTinOnline(BuildContext context) {
  return showModalBottomSheet<LuaChonToThongTin>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Row(
              children: [
                Icon(Icons.cloud_outlined, size: 24),
                SizedBox(width: 8),
                Text(kTieuDeToOnline, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              kThanToOnline,
              style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton(
                key: const Key('to-da-hieu'),
                onPressed: () => Navigator.pop(ctx, LuaChonToThongTin.daHieu),
                child: const Text('Đã hiểu'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('to-chi-tren-may'),
              onPressed: () => Navigator.pop(ctx, LuaChonToThongTin.chiTrenMay),
              child: const Text('Chỉ dùng AI trên máy'),
            ),
          ],
        ),
      ),
    ),
  );
}
