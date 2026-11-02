import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';

/// Viên nhãn dưới thanh chiều tiền ở chế độ nhà (Stitch `5a53df6e` mục 6.3): *"Nhà An Bình · ghi vào quỹ chung"*. Căn giữa,
/// tên nhà dài thì co về một dòng bằng dấu ba chấm (cột cố định phía trên không được cao thêm).
class NhanNha extends StatelessWidget {
  const NhanNha({super.key, required this.tenNha});

  final String tenNha;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4EB),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFD6E3CB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.home, size: 15, color: AppColors.onSecondaryContainer),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$tenNha · ghi vào quỹ chung',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
