// lib/features/transaction/presentation/widgets/hop_vi_se_am.dart
/// Hộp *"Số dư ví sẽ âm — Vẫn ghi?"* — MỘT hộp cho mọi lối trừ tiền do người dùng bấm: form Thêm / Sửa giao dịch và
/// bảng Thanh toán hoá đơn (người dùng chốt 2026-11-20: hỏi rồi cho lưu, không chặn). Danh sách ví từ
/// `domain/vi_se_am.dart`.
library;

import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/vi_se_am.dart';

/// `true` = Vẫn ghi; `false` / đóng hộp = Huỷ.
Future<bool> hoiViSeAm(BuildContext context, List<ViSeAm> ds) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const Key('hop-vi-se-am'),
      title: const Text('Số dư ví sẽ âm'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final v in ds)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Ví "${v.ten}" sẽ còn ${CurrencyFormatter.format(v.soDuSau)}.'),
            ),
          Text(ds.length == 1
              ? 'Ví này đang tắt "Cho phép số dư âm". Bạn vẫn muốn ghi?'
              : 'Các ví này đang tắt "Cho phép số dư âm". Bạn vẫn muốn ghi?'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Huỷ')),
        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Vẫn ghi')),
      ],
    ),
  );
  return ok == true;
}
