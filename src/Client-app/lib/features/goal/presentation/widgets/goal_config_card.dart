import 'package:flutter/material.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'package:intl/intl.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../data/models/goal_entity.dart';

/// Câu mô tả hạn chót: đếm ngược, hoặc nói rõ đã quá bao lâu.
///
/// Không bao giờ hiện **số ngày âm**. `daysLeft` trả số âm khi quá hạn — đúng
/// về số học, nhưng "Còn -7 ngày" đọc lên thì vô nghĩa, và đó lại là ca hay
/// gặp nhất với mục tiêu cũ bỏ dở.
///
/// Mục tiêu **đã đạt** thì thôi đếm ngược: màn hình hô "Quá hạn 7 ngày" cho một
/// việc người dùng đã làm xong là trách họ vì chính thành quả của họ.
String moTaHanChot(GoalEntity goal, DateTime now) {
  if (goal.daHoanThanh) return 'Đã đạt mục tiêu';

  final conLai = goal.daysLeft(now);
  if (conLai == 0) return 'Hôm nay là hạn';
  if (conLai < 0) return 'Quá hạn ${-conLai} ngày';
  return 'Còn $conLai ngày';
}

/// Câu mô tả cấu hình trích tiền tự động.
///
/// Dùng chung `GoalEntity.autoDepositEnabled` — **định nghĩa duy nhất** của
/// "đang bật", vốn đòi cả ba mảnh cấu hình. Tự viết lại phép kiểm ở đây là để
/// màn hình nói đang bật trong khi bộ chạy không chạy.
///
/// [tenViNguon] có thể `null` khi ví đã bị xoá mềm. Khi ấy vẫn nói phần biết
/// chắc: giấu luôn dòng này là giấu việc app đang trừ tiền mỗi kỳ.
String moTaTrichTuDong(GoalEntity goal, {required String? tenViNguon}) {
  if (!goal.autoDepositEnabled) return 'Đang tắt';

  final nhip = switch (goal.cycleTakeMoney) {
    'Day' => 'mỗi ngày',
    'Week' => 'mỗi tuần',
    'Quarter' => 'mỗi quý',
    'Year' => 'mỗi năm',
    _ => 'mỗi tháng',
  };

  final soTien = CurrencyFormatter.format(goal.autoDepositAmount ?? 0);
  return tenViNguon == null
      ? '$soTien $nhip'
      : '$soTien $nhip từ $tenViNguon';
}

/// Khối "Cấu hình" trên trang chi tiết mục tiêu.
///
/// Người dùng báo trang chi tiết **thiếu nội dung** (2026-09-08). Đo lại thì
/// trang không thiếu *dữ liệu* — nó thiếu chỗ **hiển thị**: cả bốn dòng dưới
/// đây đều nằm sẵn trên `GoalEntity` mà không dòng nào trên trang nói tới.
///
/// Nghiêm trọng nhất là dòng trích tự động: app tự chuyển tiền của người dùng
/// mỗi kỳ mà trang chính của mục tiêu **không nói gì**, phải mở trang Sửa mới
/// biết. Với một tính năng chuyển tiền lúc người dùng vắng mặt thì đó là chỗ
/// im lặng không chấp nhận được.
class GoalConfigCard extends StatelessWidget {
  final GoalEntity goal;

  /// `null` khi mục tiêu chưa gán ví, hoặc ví đã bị xoá mềm.
  final String? tenViTichLuy;
  final String? tenViNguonTrich;

  /// `null` = đồng hồ máy; test truyền mốc cố định.
  final DateTime? now;

  const GoalConfigCard({
    super.key,
    required this.goal,
    this.tenViTichLuy,
    this.tenViNguonTrich,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final moc = now ?? DateTime.now();
    final chamTienDo = goal.isBehindSchedule(moc);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          _Dong(
            icon: Icons.event_outlined,
            nhan: 'Hạn chót',
            giaTri: DateFormat('dd/MM/yyyy').format(goal.targetDate),
            phu: moTaHanChot(goal, moc),
          ),
          const _VachNgan(),
          _Dong(
            icon: chamTienDo
                ? Icons.trending_down_rounded
                : Icons.trending_up_rounded,
            nhan: 'Tiến độ',
            giaTri: chamTienDo ? 'Chậm so với nhịp' : 'Đang đúng nhịp',
            mauGiaTri: chamTienDo ? AppColors.error : null,
          ),
          const _VachNgan(),
          _Dong(
            icon: Icons.account_balance_wallet_outlined,
            // Ví **nhận** tiền tích luỹ, khác ví nguồn ở dòng dưới. Hai ví
            // khác nhau và người dùng chọn riêng từng cái.
            nhan: 'Ví tích lũy',
            giaTri: tenViTichLuy ?? 'Chưa gán ví',
          ),
          const _VachNgan(),
          _Dong(
            icon: Icons.autorenew_rounded,
            nhan: 'Trích tự động',
            giaTri: moTaTrichTuDong(goal, tenViNguon: tenViNguonTrich),
          ),
        ],
      ),
    );
  }
}

class _VachNgan extends StatelessWidget {
  const _VachNgan();

  @override
  Widget build(BuildContext context) => Divider(
        height: 20,
        thickness: 1,
        color: AppColors.outlineVariant.withValues(alpha: 0.35),
      );
}

class _Dong extends StatelessWidget {
  final IconData icon;
  final String nhan;
  final String giaTri;
  final String? phu;
  final Color? mauGiaTri;

  const _Dong({
    required this.icon,
    required this.nhan,
    required this.giaTri,
    this.phu,
    this.mauGiaTri,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(
          nhan,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        // `Expanded` + `TextAlign.end`: giá trị là dữ liệu người dùng nhập
        // (tên ví) hoặc số tiền dài tuỳ ý, còn khổ thật là 411dp. Để `Text`
        // trần ở đây là hàng tràn ngay khi ai đó đặt tên ví dài.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                giaTri,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: mauGiaTri ?? AppColors.primary,
                ),
              ),
              if (phu != null) ...[
                const SizedBox(height: 2),
                Text(
                  phu!,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
