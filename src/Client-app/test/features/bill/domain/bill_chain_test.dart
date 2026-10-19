import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/bill/data/models/bill_entity.dart';
import 'package:flowmoney/features/bill/domain/bill_recurrence.dart';
import 'package:flowmoney/features/bill/domain/bill_chain.dart';

/// Chuỗi kỳ của một hoá đơn lặp: mỗi kỳ là **một hàng mới**, nối với kỳ trước
/// bằng `generatedFromBillId` (cột v16, đồng bộ `previous_bill_id` từ 2026-09-12). Trang chi tiết cần cả chuỗi để
/// hiện "Lịch sử các kỳ" — từ kỳ đang mở lần ngược về gốc và xuôi tới kỳ mới
/// nhất, không kể hoá đơn khác trùng tên.
BillEntity _bill(String id, DateTime due, {String? tu, bool paid = false}) => BillEntity(
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

  /// Kỳ sau mà `BillRepository.datLaiChuaTra` sẽ gỡ — hộp "Đưa về chưa trả"
  /// chỉ nhắc kỳ sau khi hàm này trả một kỳ (người dùng chốt 2026-10-17).
  group('kySauConPhaiTra', () {
    test('kỳ sau nối chuỗi và còn phải trả → trả kỳ ấy', () {
      expect(kySauConPhaiTra([k1, k2, k3, khac], 'k2')?.id, 'k3');
    });

    test('kỳ sau ĐÃ trả → null (datLaiChuaTra không gỡ nó)', () {
      expect(kySauConPhaiTra([k1, k2, k3], 'k1'), isNull,
          reason: 'Nhắc "gỡ kỳ kế tiếp" khi kỳ ấy đã trả là hứa một việc '
              'repository cố ý không làm.');
    });

    test('kỳ sau BỎ QUA → null', () {
      final boQua = _bill('s', DateTime(2026, 8, 6), tu: 'k1')
          .copyWith(payStatus: 'Skipped');
      expect(kySauConPhaiTra([k1, boQua], 'k1'), isNull);
    });

    test('kỳ cùng tên KHÔNG nối chuỗi → null, không đoán theo tên', () {
      // di h0c 16/09 → 23/09 trên máy ảo 2026-10-17: kỳ 23/09 cùng tên, chưa
      // trả, nhưng tạo trước cột generatedFromBillId.
      final cu = _bill('cu', DateTime(2026, 9, 16), paid: true);
      final roi = _bill('roi', DateTime(2026, 9, 23));
      expect(kySauConPhaiTra([cu, roi], 'cu'), isNull,
          reason: 'Đoán theo tên + hạn là phép so cột nối sinh ra để thay — '
              'hai hoá đơn trùng tên là gỡ nhầm.');
    });

    test('kỳ sau đã xoá mềm → null', () {
      final daXoa = _bill('d', DateTime(2026, 10, 6), tu: 'k3')
          .copyWith(isDeleted: true);
      expect(kySauConPhaiTra([k3, daXoa], 'k3'), isNull);
    });
  });
}
