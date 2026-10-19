import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';

const String kTieuDeToOnline = 'Trợ lý online';
const String kThanToOnline =
    'Khi có mạng, câu hỏi của bạn cùng bản tóm tắt tài chính (tỉ lệ chi theo nhóm, điểm sức khoẻ tài chính; khi cần, số tiền một vài giao dịch với ghi chú đã che thông tin cá nhân) và vài tin gần nhất của cuộc trò chuyện được gửi tới máy chủ FlowMoney và Google Gemini để trả lời. Mất mạng thì AI trên máy trả lời, không gửi gì. Đổi lại được ở Cài đặt AI.';

/// Stitch `7a6519d6…` dùng #454743 cho thân; `AppColors.onSurfaceVariant` là #767872 (không đủ tương phản).
const Color _mauThan = Color(0xFF454743);

enum LuaChonToThongTin { daHieu, chiTrenMay }

/// Tờ thông tin lần đầu dùng Trợ lý online (Stitch `7a6519d6…`). Trả `null` khi người dùng
/// vuốt / chạm ngoài tắt tờ — người gọi coi như chưa chọn.
Future<LuaChonToThongTin?> moToThongTinOnline(BuildContext context) {
  return showModalBottomSheet<LuaChonToThongTin>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
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
                Icon(Icons.cloud_outlined, size: 24, color: AppColors.primary),
                SizedBox(width: 8),
                Text(kTieuDeToOnline, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              kThanToOnline,
              style: TextStyle(fontSize: 14, height: 1.45, color: _mauThan),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('to-da-hieu'),
              onPressed: () => Navigator.pop(ctx, LuaChonToThongTin.daHieu),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size.fromHeight(48),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              child: const Text('Đã hiểu'),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('to-chi-tren-may'),
              onPressed: () => Navigator.pop(ctx, LuaChonToThongTin.chiTrenMay),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              child: const Text('Chỉ dùng AI trên máy'),
            ),
          ],
        ),
      ),
    ),
  );
}
