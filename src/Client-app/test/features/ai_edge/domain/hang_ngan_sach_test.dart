/// Tool `danh_sach_ngan_sach`: hàng theo displayName, căng nhất trước, trạng
/// thái từ `isOverBudget` / `BudgetPace.status`; kỳ vọng tính bằng CHÍNH
/// `budgetPaceOf` chứ không ghi cứng (nếp của gói ngân sách).
library;

import 'package:flowmoney/features/ai_edge/domain/hang_ngan_sach.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/domain/budget_pace.dart';
import 'package:flutter_test/flutter_test.dart';

BudgetView _ns({
  String id = 'b1',
  String ten = 'Giáo dục',
  required double amount,
  required double spent,
  DateTime? start,
}) {
  final s = start ?? DateTime(2026, 9, 1);
  return BudgetView(
    budget: BudgetEntity(
      id: id,
      idaccount: 7,
      categoryId: 'c-$id',
      amount: amount,
      spent: spent,
      startDate: s,
      recurrence: true,
      timeRecurrence: BudgetRecurrence.month,
      updatedAt: s,
    ),
    categoryName: ten,
  );
}

void main() {
  final now = DateTime(2026, 9, 22);

  test('⭐ căng nhất trước; TÊN là displayName; số từ domain', () {
    final giaoDuc = _ns(id: 'gd', ten: 'Giáo dục', amount: 50000, spent: 45000);
    final anUong = _ns(id: 'au', ten: 'Ăn uống', amount: 500000, spent: 50000);
    final kq = hangNganSach([anUong, giaoDuc], now: now);
    expect(kq.hang.map((h) => h.ten).toList(), ['Giáo dục', 'Ăn uống']);
    final h = kq.hang.first;
    final nhip = budgetPaceOf(giaoDuc.budget, now);
    expect({for (final s in h.soLieu) s.nhan: s.chuoi}, {
      'Đã chi': '45.000 đ',
      'Hạn mức': '50.000 đ',
      'Tỉ lệ': '90,0%',
      'Còn lại': '5.000 đ',
      'Còn': '${nhip.daysLeft} ngày',
    });
    expect(h.soLieu.every((s) => s.ten == 'Giáo dục'), isTrue);
    expect(h.trangThai, chuNhipNganSach(nhip.status));
    expect(h.canhBao, isFalse);
  });

  test('vượt hạn mức: trạng thái "vượt hạn mức", cờ cảnh báo, KHÔNG có Còn lại', () {
    final kq = hangNganSach([_ns(amount: 3000000, spent: 3400000)], now: now);
    final h = kq.hang.single;
    expect(h.trangThai, 'vượt hạn mức');
    expect(h.canhBao, isTrue);
    expect(h.soLieu.any((s) => s.nhan == 'Còn lại'), isFalse,
        reason: '"Còn lại -400.000 đ" là một con số âm người đọc phải tự đảo nghĩa');
  });

  test('tổng hợp: Tổng còn lại = Σ remaining (khớp thẻ tổng trang Ngân sách), Số ngân sách', () {
    final kq = hangNganSach([
      _ns(id: 'a', ten: 'A', amount: 50000, spent: 45000),
      _ns(id: 'b', ten: 'B', amount: 500000, spent: 50000),
      _ns(id: 'c', ten: 'C', amount: 450000, spent: 355000),
      _ns(id: 'd', ten: 'D', amount: 850000, spent: 60000),
    ], now: now);
    expect(kq.tongHop.map((s) => '${s.nhan}=${s.chuoi}').toList(),
        ['Tổng còn lại=1.340.000 đ', 'Số ngân sách=4']);
  });

  test('trần kToiDaMucMoiGoi hàng; Số ngân sách vẫn đủ', () {
    final kq = hangNganSach(
      [for (var i = 0; i < 6; i++) _ns(id: 'n$i', ten: 'N$i', amount: 100000, spent: 10000.0 * i)],
      now: now,
    );
    expect(kq.hang.length, 4);
    expect(kq.tongHop[1].chuoi, '6');
  });

  test('không ngân sách nào: 0 hàng nhưng tool ĐÃ chạy — tổng hợp vẫn có', () {
    final kq = hangNganSach(const [], now: now);
    expect(kq.hang, isEmpty);
    expect(kq.tongHop.map((s) => s.chuoi).toList(), ['0 đ', '0']);
    expect(kq.loi, isNull);
  });

  test('chuNhipNganSach phủ ba nhịp', () {
    expect(chuNhipNganSach(BudgetPaceStatus.fast), 'tiêu nhanh');
    expect(chuNhipNganSach(BudgetPaceStatus.onTrack), 'đúng nhịp');
    expect(chuNhipNganSach(BudgetPaceStatus.slow), 'tiêu chậm');
  });
}
