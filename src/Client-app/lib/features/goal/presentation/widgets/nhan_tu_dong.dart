import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

/// Nhãn "Tự động" gắn vào một dòng lịch sử tích luỹ.
///
/// ## Vì sao nó tồn tại
///
/// Khoản do `GoalAutoDepositRunner` trích và khoản người dùng tự bấm **giống
/// hệt nhau trên mọi cột** — cùng kiểu `'transfer'`, cùng `goalId`, cùng tiền
/// tố ghi chú. Sự giống nhau ấy là có chủ ý (mục 3.12 `GOAL_FEATURE.md`), vì
/// nó cho `laKhoanRutKhoiMucTieu` đọc đúng chiều tiền cho cả hai. Cái giá là
/// người dùng mở lịch sử ra không biết được khoản nào do chính họ chuyển, và
/// đây là **chỗ duy nhất** trên màn hình nói ra điều đó.
///
/// ## Vì sao là chip chứ không phải một chữ trong dòng ngày
///
/// Theo hệ thiết kế "Kinetic Finance": chip mang hình viên thuốc, nền là bản
/// 10% độ đục của màu ngữ nghĩa còn chữ giữ nguyên 100% để còn đọc được, và
/// chữ nhãn dùng khổ `label-sm` (11px/500). Nhét thêm chữ vào dòng ngày thì
/// nó lẫn vào phần siêu dữ liệu và người dùng đọc lướt qua mất.
///
/// Màu chọn **trung tính** chứ không phải xanh "thu nhập": nhãn này nói *ai đã
/// chuyển tiền*, không nói khoản ấy tốt hay xấu. Mượn màu ngữ nghĩa ở đây là
/// thêm một tầng nghĩa mà tính năng không hề khẳng định.
class NhanTuDong extends StatelessWidget {
  const NhanTuDong({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Tự động',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
