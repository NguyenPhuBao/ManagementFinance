/// G87 (2026-10-09) — kỳ hoá đơn TRÙNG: cùng chuỗi, cùng ngày hạn, nhiều hàng sống.
///
/// Đo trên PostgreSQL dev, tài khoản 10, hoá đơn Netflix tự trả: kỳ 20/9 (`31617105`) đã trả có BA kỳ con
/// 05/10 (máy offline tự trả lại kỳ cha; kỳ con lên server vì hoá đơn đẩy TRƯỚC giao dịch, rồi lệnh xoá của bộ
/// gỡ xung đột bị Pull cùng chu kỳ ghi đè). OnePlus trả nốt hai kỳ trùng — kỳ 05/10 bị trừ 3 lần — và đẻ ra NĂM
/// kỳ 12/10 dưới BA cha khác nhau. Nên khoá gộp là GỐC CHUỖI + ngày, không phải cha.
library;

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/domain/bill_ky_trung.dart';
import 'package:flowmoney/features/bill/domain/bill_pay_status.dart';
import 'package:flutter_test/flutter_test.dart';

Bill _ky(
  String id, {
  String? cha,
  required DateTime han,
  String trangThai = kBillPending,
  bool daXoa = false,
}) =>
    Bill(
      id: id,
      idaccount: 10,
      walletId: 'w1',
      categoryId: 'c1',
      name: 'Netflix',
      amount: 100000,
      startDate: han.subtract(const Duration(days: 8)),
      dueDate: han,
      payStatus: trangThai,
      isPaid: trangThai == kBillPayed,
      autoPayEnabled: true,
      timeNotification: '3',
      isRecurrence: true,
      timeRecurrence: kBillCycleWeek,
      recurrence: 'weekly',
      icon: 'receipt',
      colour: '#4CAF50',
      note: '',
      generatedFromBillId: cha,
      isDeleted: daXoa,
      deletedAt: daXoa ? DateTime(2026, 10, 3) : null,
      syncStatus: 'synced',
      syncRetryCount: 0,
      updatedAt: DateTime(2026, 10, 1),
    );

final h0510 = DateTime(2026, 10, 5, 7);
final h1210 = DateTime(2026, 10, 12, 7);

void main() {
  group('kyTrungCanGo', () {
    test('một chuỗi bình thường (mỗi kỳ một hàng) → không gỡ gì', () {
      final ds = [
        _ky('a', han: DateTime(2026, 9, 28), trangThai: kBillPayed),
        _ky('b', cha: 'a', han: h0510, trangThai: kBillPayed),
        _ky('c', cha: 'b', han: h1210),
      ];
      expect(kyTrungCanGo(ds), isEmpty);
    });

    test('⭐ Netflix trước 08/10: 1 kỳ con đã trả + 2 kỳ con chưa trả cùng 05/10 → gỡ hai kỳ chưa trả', () {
      final ds = [
        _ky('31617105', han: DateTime(2026, 9, 28), trangThai: kBillPayed),
        _ky('8027c914', cha: '31617105', han: h0510, trangThai: kBillPayed),
        _ky('22bb274a', cha: '31617105', han: h0510, trangThai: kBillOverdue),
        _ky('cccb14ee', cha: '31617105', han: h0510, trangThai: kBillOverdue),
        _ky('c0038a49', cha: '8027c914', han: h1210),
      ];
      expect(kyTrungCanGo(ds), {'22bb274a', 'cccb14ee'},
          reason: 'đã có kỳ trả cho 05/10 thì kỳ còn phải trả cùng ngày là trùng — để lại là bộ tự trả trừ tiền lần nữa');
    });

    test('⭐ Netflix hiện tại: năm kỳ 12/10 dưới BA cha khác nhau → giữ đúng một (id nhỏ nhất)', () {
      final ds = [
        _ky('31617105', han: DateTime(2026, 9, 28), trangThai: kBillPayed),
        _ky('8027c914', cha: '31617105', han: h0510, trangThai: kBillPayed),
        _ky('22bb274a', cha: '31617105', han: h0510, trangThai: kBillPayed),
        _ky('cccb14ee', cha: '31617105', han: h0510, trangThai: kBillPayed),
        _ky('c0038a49', cha: '8027c914', han: h1210),
        _ky('780e51b2', cha: '8027c914', han: h1210),
        _ky('7ebadb82', cha: '8027c914', han: h1210),
        _ky('65ece89a', cha: 'cccb14ee', han: h1210),
        _ky('9886bc31', cha: '22bb274a', han: h1210),
      ];
      expect(kyTrungCanGo(ds), {'780e51b2', '7ebadb82', 'c0038a49', '9886bc31'},
          reason: 'gộp theo GỐC chuỗi, không theo cha — gộp theo cha thì còn ba kỳ 12/10');
      expect(kyTrungCanGo(ds).intersection({'8027c914', '22bb274a', 'cccb14ee'}), isEmpty,
          reason: 'kỳ đã trả KHÔNG BAO GIỜ bị gỡ: xoá nó là mất khoản chi khỏi lịch sử mà không hoàn tiền');
    });

    test('máy chỉ thấy MỘT PHẦN nhóm vẫn không bao giờ gỡ kỳ mà máy khác giữ (hội tụ)', () {
      final day = [
        _ky('g', han: DateTime(2026, 9, 28), trangThai: kBillPayed),
        _ky('k1', cha: 'g', han: h1210),
        _ky('k2', cha: 'g', han: h1210),
        _ky('k3', cha: 'g', han: h1210),
      ];
      final giuToanCuc = {'k1', 'k2', 'k3'}.difference(kyTrungCanGo(day));
      expect(giuToanCuc, {'k1'});
      // Máy chỉ có k2, k3 (chưa kéo k1 về): nó gỡ k3, giữ k2 — không chạm k1.
      final motPhan = [day[0], day[2], day[3]];
      expect(kyTrungCanGo(motPhan), {'k3'});
    });

    test('đi ngược qua cả hàng ĐÃ XOÁ để tìm gốc; hàng đã xoá không bao giờ bị gỡ lần nữa', () {
      final ds = [
        _ky('g', han: DateTime(2026, 9, 28), trangThai: kBillPayed),
        _ky('cha-da-xoa', cha: 'g', han: h0510, trangThai: kBillPayed, daXoa: true),
        _ky('cha-song', cha: 'g', han: h0510, trangThai: kBillPayed),
        _ky('x', cha: 'cha-da-xoa', han: h1210),
        _ky('y', cha: 'cha-song', han: h1210),
        _ky('z-da-xoa', cha: 'cha-song', han: h1210, daXoa: true),
      ];
      expect(kyTrungCanGo(ds), {'y'}, reason: 'x và y cùng gốc g; giữ id nhỏ nhất là x');
    });

    test('cha chưa có trên máy → lấy id cha làm gốc', () {
      final ds = [
        _ky('k1', cha: 'cha-chua-keo-ve', han: h1210),
        _ky('k2', cha: 'cha-chua-keo-ve', han: h1210),
      ];
      expect(kyTrungCanGo(ds), {'k2'});
    });

    test('cùng chuỗi nhưng KHÁC ngày hạn → không trùng', () {
      final ds = [
        _ky('g', han: DateTime(2026, 9, 28), trangThai: kBillPayed),
        _ky('k1', cha: 'g', han: h0510, trangThai: kBillPayed),
        _ky('k2', cha: 'k1', han: h1210),
      ];
      expect(kyTrungCanGo(ds), isEmpty);
    });

    test('so theo NGÀY: lệch giờ trong cùng ngày vẫn là trùng', () {
      final ds = [
        _ky('g', han: DateTime(2026, 9, 28), trangThai: kBillPayed),
        _ky('k1', cha: 'g', han: DateTime(2026, 10, 5, 0)),
        _ky('k2', cha: 'g', han: DateTime(2026, 10, 5, 7)),
      ];
      expect(kyTrungCanGo(ds), {'k2'});
    });

    test('kỳ BỎ QUA cũng là kỳ đã đóng: kỳ còn phải trả cùng ngày bị gỡ', () {
      final ds = [
        _ky('g', han: DateTime(2026, 9, 28), trangThai: kBillPayed),
        _ky('k1', cha: 'g', han: h0510, trangThai: kBillSkipped),
        _ky('k2', cha: 'g', han: h0510),
      ];
      expect(kyTrungCanGo(ds), {'k2'});
    });

    test('hai hoá đơn khác chuỗi trùng tên + trùng hạn KHÔNG bị gộp (hoá đơn tạo tay)', () {
      final ds = [
        _ky('tay1', han: h1210),
        _ky('tay2', han: h1210),
      ];
      expect(kyTrungCanGo(ds), isEmpty);
    });

    test('chuỗi có vòng (dữ liệu hỏng) không treo', () {
      final ds = [
        _ky('a', cha: 'b', han: h0510),
        _ky('b', cha: 'a', han: h1210),
      ];
      expect(() => kyTrungCanGo(ds), returnsNormally);
    });
  });

  group('kyCungKyDaDong — chốt của payBill', () {
    test('kỳ trùng của một kỳ đã trả → true', () {
      final ds = [
        _ky('g', han: DateTime(2026, 9, 28), trangThai: kBillPayed),
        _ky('k1', cha: 'g', han: h0510, trangThai: kBillPayed),
        _ky('k2', cha: 'g', han: h0510, trangThai: kBillOverdue),
      ];
      expect(kyCungKyDaDong(ds[2], ds), isTrue);
    });

    test('kỳ đơn lẻ → false; anh em đã xoá không tính', () {
      final ds = [
        _ky('g', han: DateTime(2026, 9, 28), trangThai: kBillPayed),
        _ky('k1', cha: 'g', han: h0510, trangThai: kBillPayed, daXoa: true),
        _ky('k2', cha: 'g', han: h0510),
      ];
      expect(kyCungKyDaDong(ds[2], ds), isFalse);
    });
  });
}
