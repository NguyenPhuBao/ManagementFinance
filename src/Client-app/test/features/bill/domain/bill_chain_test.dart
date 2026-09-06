import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/domain/bill_chain.dart';

/// Chuỗi kỳ của một hoá đơn lặp: mỗi kỳ là **một hàng mới**, nối với kỳ trước
/// bằng `generatedFromBillId` (cột cục bộ v16). Trang chi tiết cần cả chuỗi để
/// hiện "Lịch sử các kỳ" — từ kỳ đang mở lần ngược về gốc và xuôi tới kỳ mới
/// nhất, không kể hoá đơn khác trùng tên.
Bill _bill(String id, DateTime due, {String? tu, bool paid = false}) => Bill(
      id: id,
      idaccount: 10,
      walletId: 'w1',
      categoryId: 'c1',
      generatedFromBillId: tu,
      name: 'Tiền điện',
      amount: 100000,
      startDate: due.subtract(const Duration(days: 30)),
      dueDate: due,
      payStatus: paid ? 'Payed' : 'Pending',
      isPaid: paid,
      autoPayEnabled: false,
      timeNotification: '3',
      isRecurrence: true,
      timeRecurrence: kBillCycleMonth,
      recurrence: 'monthly',
      icon: 'receipt',
      colour: '#4CAF50',
      note: '',
      isDeleted: false,
      syncStatus: 'synced',
      syncRetryCount: 0,
      updatedAt: DateTime(2026, 9, 1),
    );

void main() {
  final k1 = _bill('k1', DateTime(2026, 7, 6), paid: true);
  final k2 = _bill('k2', DateTime(2026, 8, 6), tu: 'k1', paid: true);
  final k3 = _bill('k3', DateTime(2026, 9, 6), tu: 'k2');
  // Hoá đơn khác, trùng tên, không thuộc chuỗi.
  final khac = _bill('x1', DateTime(2026, 9, 10));

  test('từ kỳ giữa lần được cả gốc lẫn kỳ sau, mới nhất đứng đầu', () {
    final chuoi = chuoiKyCua([khac, k3, k1, k2], 'k2');
    expect(chuoi.map((b) => b.id), ['k3', 'k2', 'k1'],
        reason: 'Lịch sử đọc từ kỳ mới nhất xuống; hoá đơn trùng tên nhưng '
            'không nối bằng generatedFromBillId thì không được lẫn vào.');
  });

  test('hoá đơn không lặp là chuỗi một phần tử', () {
    expect(chuoiKyCua([khac, k1], 'x1').map((b) => b.id), ['x1']);
  });

  test('id không có trong danh sách → chuỗi rỗng', () {
    expect(chuoiKyCua([k1, k2], 'k9'), isEmpty);
  });

  test('vòng lặp trong dữ liệu không làm treo', () {
    // Dữ liệu hỏng: a sinh từ b và b sinh từ a. Không được lặp vô hạn.
    final a = _bill('a', DateTime(2026, 8, 6), tu: 'b');
    final b = _bill('b', DateTime(2026, 9, 6), tu: 'a');
    final chuoi = chuoiKyCua([a, b], 'a');
    expect(chuoi.length, 2);
  });
}
