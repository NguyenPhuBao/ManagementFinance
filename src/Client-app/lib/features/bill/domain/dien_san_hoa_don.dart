/// Điền sẵn form tạo hoá đơn từ một khoản lặp (B2) — dịch qua lại giữa
/// `KhoanLap` và query của route `/bills/add`. Dart thuần.
///
/// Spec: docs/superpowers/specs/2026-09-28-b2-khoan-lap-goi-y-hoa-don-design.md
/// mục 5. Query hỏng thì bỏ đúng trường ấy, không ném: route đọc query từ URL,
/// thứ ai cũng gõ tay được.
library;

import '../../../core/bill/bill_recurrence.dart';
import '../../transaction/domain/khoan_lap.dart';

typedef DienSanHoaDon = ({
  String? ten,
  double? soTien,
  String? chuKy,
  int? ngayGoc,
  DateTime? batDau,
  String? categoryId,
  String? walletId,
});

const Set<String> _khoa = {'name', 'amount', 'cycle', 'anchor', 'start', 'category', 'wallet'};

const Set<String> _chuKyHopLe = {
  kBillCycleWeek,
  kBillCycleMonth,
  kBillCycleQuarter,
  kBillCycleYear,
};

final RegExp _ngayIso = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// `null` khi query không có khoá nào của mình — form trống như khi mở thường.
DienSanHoaDon? dienSanTuQuery(Map<String, String> q) {
  if (!q.keys.any(_khoa.contains)) return null;
  final ck = q['cycle'];
  final ng = int.tryParse(q['anchor'] ?? '');
  final ten = q['name']?.trim();
  final tien = double.tryParse(q['amount'] ?? '');
  final start = q['start'] ?? '';
  return (
    ten: (ten == null || ten.isEmpty) ? null : ten,
    soTien: (tien != null && tien > 0) ? tien : null,
    chuKy: _chuKyHopLe.contains(ck) ? ck : null,
    ngayGoc: (ng != null && ng >= 1 && ng <= 31) ? ng : null,
    batDau: _ngayIso.hasMatch(start) ? DateTime.tryParse(start) : null,
    categoryId: (q['category']?.isEmpty ?? true) ? null : q['category'],
    walletId: (q['wallet']?.isEmpty ?? true) ? null : q['wallet'],
  );
}

String _hai(int n) => n.toString().padLeft(2, '0');

/// `start` là ngày của lần gần nhất: hạn kỳ đầu của hoá đơn tạo ra
/// (`BillSchedule.ketThucKy`) khi ấy rơi đúng vào LẦN LẶP KẾ TIẾP. Cộng thêm
/// một chu kỳ là hạn kỳ đầu trễ một kỳ — người dùng lỡ đúng lần nhắc đầu tiên.
Map<String, String> queryTuKhoanLap(KhoanLap k) => {
      'name': k.ten,
      'amount': k.soTien.round().toString(),
      'cycle': k.chuKy,
      if (k.ngayGoc != null) 'anchor': '${k.ngayGoc}',
      'start': '${k.ngayGanNhat.year.toString().padLeft(4, '0')}-'
          '${_hai(k.ngayGanNhat.month)}-${_hai(k.ngayGanNhat.day)}',
      if (k.categoryId != null && k.categoryId!.isNotEmpty) 'category': k.categoryId!,
      'wallet': k.walletId,
    };
