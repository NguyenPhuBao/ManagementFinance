import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/domain/transaction_owner.dart';
import 'package:flutter_test/flutter_test.dart';

/// Canh chừng điều gì: sổ giao dịch chỉ được cho xoá khi bản thân giao dịch là
/// nguồn sự thật DUY NHẤT của hệ quả nó gây ra. Khoản nạp/rút mục tiêu còn
/// một bộ đếm `current_amount` ở bảng goal, khoản trả hoá đơn còn cờ Payed và
/// kỳ kế tiếp — xoá ở sổ chỉ hoàn ví, ba thứ kia đứng nguyên (đã thấy trên
/// máy ảo 2026-09-06: xoá hai khoản nạp, tiến độ MuaXe vẫn 1.100.000).
void main() {
  TransactionEntity tx({String? goalId, String note = '', String type = 'chi'}) =>
      TransactionEntity(
        id: 't',
        walletId: 'w',
        idaccount: 1,
        goalId: goalId,
        amount: 1000,
        type: type,
        note: note,
        date: DateTime(2026, 9, 6),
        updatedAt: DateTime(2026, 9, 6),
      );

  group('transactionOwnerOf', () {
    test('giao dịch thường và chuyển khoản thường là của chính nó', () {
      expect(transactionOwnerOf(tx()), TransactionOwner.transaction);
      expect(transactionOwnerOf(tx(note: 'Cà phê sáng')),
          TransactionOwner.transaction);
      expect(transactionOwnerOf(tx(type: 'transfer')),
          TransactionOwner.transaction);
    });

    test('có goalId là của mục tiêu, bất kể ghi chú', () {
      expect(transactionOwnerOf(tx(goalId: 'g1', note: 'ghi chú tự sửa')),
          TransactionOwner.goal);
    });

    test('hàng kéo từ server không có goalId thì nhận theo tiền tố ghi chú',
        () {
      // Hàng cũ trên server mang `Idgoal = NULL` (goal_id đồng bộ từ 2026-09-07,
      // hàng tạo trước đó thì chưa) — máy khác chỉ còn ghi chú.
      expect(transactionOwnerOf(tx(note: 'Tích lũy mục tiêu: MuaXe')),
          TransactionOwner.goal);
      expect(transactionOwnerOf(tx(note: 'Rút từ mục tiêu: MuaXe')),
          TransactionOwner.goal);
    });

    test('dạng cũ hai hàng rời "Tích lũy nhận từ …" cũng là của mục tiêu', () {
      // Bản app trước 2026-09-05 ghi mỗi lần nạp thành cặp chi/thu; nửa "thu"
      // mang tiền tố này và vẫn còn trong dữ liệu thật.
      expect(
        transactionOwnerOf(tx(note: 'Tích lũy nhận từ Tiền mặt: MuaXe', type: 'thu')),
        TransactionOwner.goal,
      );
    });

    test('tiền tố phải ở ĐẦU ghi chú — người dùng gõ giữa câu thì không tính',
        () {
      expect(transactionOwnerOf(tx(note: 'đã Tích lũy mục tiêu: xong')),
          TransactionOwner.transaction);
    });

    test('khoản trả hoá đơn nhận theo tiền tố do BillRepository sinh', () {
      expect(transactionOwnerOf(tx(note: 'Thanh toán hóa đơn: Tiền điện')),
          TransactionOwner.bill);
    });
  });

  group('lyDoKhongXoaTaiSo', () {
    test('giao dịch thường thì không có lý do — xoá được', () {
      expect(lyDoKhongXoaTaiSo(TransactionOwner.transaction), isNull);
    });

    test('mục tiêu và hoá đơn có câu chỉ đường riêng', () {
      expect(lyDoKhongXoaTaiSo(TransactionOwner.goal), contains('mục tiêu'));
      expect(lyDoKhongXoaTaiSo(TransactionOwner.bill), contains('hoá đơn'));
    });
  });
}
