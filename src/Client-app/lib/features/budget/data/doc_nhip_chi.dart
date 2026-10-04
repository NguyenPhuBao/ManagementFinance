/// Cửa đọc nhịp chi cho ba nơi dùng — `TaiPhanBoNguonImpl.nap`, `BudgetDetailCubit`,
/// tool `danh_sach_ngan_sach`. Nhịp là phần PHỤ: đọc hỏng thì trả `{}` và mọi chỗ
/// dùng rơi về giả định chi đều — y như trước dự án C — chứ không làm hỏng trang,
/// kế hoạch cân đối hay câu trả lời của tool. Một định nghĩa cho cả ba.
library;

import 'package:flutter/foundation.dart';

import '../domain/nhip_chi.dart';
import 'models/budget_entity.dart';
import 'repositories/budget_repository.dart';

Future<Map<String, NhipChi?>> docNhipChi(
  BudgetRepository repo,
  int idaccount,
  List<BudgetEntity> budgets,
  DateTime now,
) async {
  if (budgets.isEmpty) return const {};
  try {
    return await repo.nhipChiTheoNganSach(idaccount, budgets, now: now);
  } catch (e) {
    debugPrint('[NhipChi] đọc hỏng, rơi về phép chi đều: $e');
    return const {};
  }
}
