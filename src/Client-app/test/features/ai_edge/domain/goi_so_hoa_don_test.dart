/// Gói số của trang Hoá đơn (chặng 1.3) — gói số **thứ năm**, và là tệp mẫu
/// cho gói mục tiêu mở rộng (1.4) lẫn gói ví (1.5).
///
/// Mọi con số phải đến từ hàm domain của mảng hoá đơn (`summarizeBills`,
/// `billDisplayStatusOf`); lớp `ai_edge/` không tính — test quét thứ 14 canh.
library;

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so_hoa_don.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_so.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';
import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

Bill _bill({
  String id = 'b1',
  required DateTime dueDate,
  double amount = 100000,
  bool isPaid = false,
  String payStatus = 'Pending',
  String ten = 'Tiền điện',
}) =>
    Bill(
      id: id,
      idaccount: 10,
      walletId: 'w1',
      categoryId: 'c1',
      name: ten,
      amount: amount,
      startDate: dueDate.subtract(const Duration(days: 30)),
      dueDate: dueDate,
      payStatus: payStatus,
      isPaid: isPaid,
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
  final now = DateTime(2026, 9, 6, 10, 30);

  group('thiếu dữ liệu', () {
    test('kỳ không có hoá đơn nào: câu THẬT, không phải khối rỗng', () {
      final g = GoiSoHoaDon.tu(const [], now: now);
      expect(g.thieuDuLieu, isTrue);
      final nx = g.mauCau();
      expect(nx.muc, MucNhanXet.thieuDuLieu);
      expect(nx.cau, isNotEmpty);
      expect(g.soLieu, isEmpty);
    });

    test('hoá đơn của kỳ SAU không kéo kỳ này ra khỏi trạng thái rỗng', () {
      // `summarizeBills` chặn ở cuối tháng của `now` — hoá đơn 05/10 không
      // thuộc kỳ này, nên gói vẫn phải nói "chưa có hoá đơn nào".
      final g = GoiSoHoaDon.tu([_bill(dueDate: DateTime(2026, 10, 5))], now: now);
      expect(g.thieuDuLieu, isTrue);
    });
  });

  group('số liệu', () {
    test('lấy đúng con số của summarizeBills, tiến độ ở thang 0–100', () {
      final g = GoiSoHoaDon.tu([
        _bill(id: 'a', dueDate: DateTime(2026, 9, 20), amount: 300000),
        _bill(
            id: 'b',
            dueDate: DateTime(2026, 9, 10),
            amount: 100000,
            isPaid: true,
            payStatus: 'Payed'),
      ], now: now);

      final s = {for (final x in g.soLieu) x.nhan: x.soTho};
      expect(s['Còn phải trả'], 300000);
      expect(s['Đã trả'], 100000);
      expect(s['Tiến độ'], closeTo(25, 0.001));
      expect(s['Chưa trả'], 1);
    });

    test('không có hoá đơn quá hạn thì KHÔNG dựng thẻ "Quá hạn"', () {
      final g = GoiSoHoaDon.tu(
          [_bill(dueDate: DateTime(2026, 9, 20))], now: now);
      expect(g.soLieu.map((e) => e.nhan), isNot(contains('Quá hạn')),
          reason: 'thẻ "Quá hạn: 0" là một ô trống đội lốt số liệu');
    });

    test('kỳ bỏ qua không vào vế nào — không phải nợ, cũng không phải đã chi',
        () {
      final g = GoiSoHoaDon.tu([
        _bill(id: 'a', dueDate: DateTime(2026, 9, 20), payStatus: 'Skipped'),
      ], now: now);
      expect(g.thieuDuLieu, isTrue,
          reason: 'một kỳ bỏ qua duy nhất thì kỳ này không còn gì để nói');
    });
  });

  group('mẫu câu', () {
    test('quá hạn → mức cảnh báo và câu nói rõ số hoá đơn quá hạn', () {
      final g = GoiSoHoaDon.tu([
        _bill(id: 'a', dueDate: DateTime(2026, 9, 2), amount: 200000),
        _bill(id: 'b', dueDate: DateTime(2026, 9, 20), amount: 100000),
      ], now: now);
      final nx = g.mauCau();
      expect(nx.muc, MucNhanXet.canhBao);
      expect(nx.cau, contains('quá hạn'));
    });

    test('còn nợ nhưng không quá hạn → mức bình thường', () {
      final g = GoiSoHoaDon.tu(
          [_bill(dueDate: DateTime(2026, 9, 20))], now: now);
      expect(g.mauCau().muc, MucNhanXet.binhThuong);
      expect(g.mauCau().cau, isNot(contains('quá hạn')));
    });

    test('trả xong cả kỳ → câu mừng, không có vế "còn phải trả"', () {
      final g = GoiSoHoaDon.tu([
        _bill(
            id: 'a',
            dueDate: DateTime(2026, 9, 2),
            isPaid: true,
            payStatus: 'Payed'),
      ], now: now);
      final nx = g.mauCau();
      expect(nx.muc, MucNhanXet.binhThuong);
      expect(nx.cau, isNot(contains('chưa trả')));
    });

    test('chưa trả đồng nào thì câu KHÔNG nói "đã trả 0 đ (0,0%)"', () {
      final g = GoiSoHoaDon.tu(
          [_bill(dueDate: DateTime(2026, 9, 20))], now: now);
      expect(g.mauCau().cau, isNot(contains('đã trả')),
          reason: 'vế rỗng chỉ làm câu dài ra mà không nói thêm gì');
    });
  });

  group('bộ kiểm số', () {
    // ⚠️ Ca BẮT BUỘC của mọi gói số (bẫy 4.1): mẫu câu phải tự qua `kiemSo`.
    // Thiếu nó thì tới P3 mô hình sẽ rơi về một câu mà chính bộ kiểm cũng
    // chặn — và khối hiện ra trống trong im lặng.
    final caTest = <String, List<Bill>>{
      'kỳ rỗng': const [],
      'còn nợ': [_bill(dueDate: DateTime(2026, 9, 20))],
      'có quá hạn': [
        _bill(id: 'a', dueDate: DateTime(2026, 9, 2), amount: 250000),
        _bill(id: 'b', dueDate: DateTime(2026, 9, 20), amount: 130000),
      ],
      'đã trả một phần': [
        _bill(id: 'a', dueDate: DateTime(2026, 9, 20), amount: 300000),
        _bill(
            id: 'b',
            dueDate: DateTime(2026, 9, 10),
            amount: 100000,
            isPaid: true,
            payStatus: 'Payed'),
      ],
      'trả xong cả kỳ': [
        _bill(
            id: 'a',
            dueDate: DateTime(2026, 9, 2),
            isPaid: true,
            payStatus: 'Payed'),
      ],
    };

    for (final e in caTest.entries) {
      test('mẫu câu tự qua bộ kiểm số — ${e.key}', () {
        final g = GoiSoHoaDon.tu(e.value, now: now);
        final cau = g.mauCau().cau;
        expect(kiemSo(cau, g), isTrue, reason: cau);
      });
    }
  });

  group('danh sách hoá đơn có TÊN (chặng 4a)', () {
    final now = DateTime(2026, 9, 22);

    test('mỗi hoá đơn còn phải trả góp một mục mang TÊN', () {
      final g = GoiSoHoaDon.tu([
        _bill(id: 'h1', ten: 'Kiem', dueDate: DateTime(2026, 9, 18)),
        _bill(id: 'h2', ten: 'di h0c', dueDate: DateTime(2026, 9, 25)),
      ], now: now);
      final ten = g.soLieu.where((s) => s.nhan == 'Phải trả').map((s) => s.ten);
      expect(ten, containsAll(<String>['Kiem', 'di h0c']),
          reason: 'Câu 13 của bảng đo — "hoá đơn nào quá hạn" — trả lời sang '
              'hẳn chủ đề khác ("Ngân sách căng nhất là 90,0%") vì gói hoá '
              'đơn không mang tên nào.');
    });

    test('hoá đơn QUÁ HẠN đứng đầu', () {
      final g = GoiSoHoaDon.tu([
        _bill(id: 'h2', ten: 'di h0c', dueDate: DateTime(2026, 9, 25)),
        _bill(id: 'h1', ten: 'Kiem', dueDate: DateTime(2026, 9, 18)),
      ], now: now);
      final muc = g.soLieu.where((s) => s.nhan == 'Phải trả').toList();
      expect(muc.first.ten, 'Kiem');
    });

    test('hoá đơn ĐÃ TRẢ không vào danh sách', () {
      final g = GoiSoHoaDon.tu([
        _bill(id: 'h1', ten: 'Kiem', dueDate: DateTime(2026, 9, 18)),
        _bill(
          id: 'h3',
          ten: 'Đã đóng',
          dueDate: DateTime(2026, 9, 10),
          isPaid: true,
          payStatus: 'Payed',
        ),
      ], now: now);
      final ten = g.soLieu.where((s) => s.nhan == 'Phải trả').map((s) => s.ten);
      expect(ten, isNot(contains('Đã đóng')),
          reason: 'Vị từ "còn phải trả" có MỘT định nghĩa duy nhất ở '
              '`bill/domain/bill_pay_status.dart` — `conPhaiTra`.');
    });

    test('⚠️ hoá đơn KỲ SAU không vào danh sách — cùng bộ lọc summarizeBills',
        () {
      final g = GoiSoHoaDon.tu([
        _bill(id: 'h1', ten: 'Kiem', dueDate: DateTime(2026, 9, 18)),
        _bill(id: 'h9', ten: 'Kỳ sau', dueDate: DateTime(2026, 10, 5)),
      ], now: now);
      final ten = g.soLieu.where((s) => s.nhan == 'Phải trả').map((s) => s.ten);
      expect(ten, isNot(contains('Kỳ sau')),
          reason: 'Không lặp phép chặn ở cuối tháng thì danh sách nói về một '
              'tập hoá đơn khác với các con số tổng ngay cạnh nó — hai vế của '
              'cùng một câu, đếm trên hai tập, và không có gì báo.');
    });

    test('không vượt trần kToiDaMucMoiGoi hoá đơn', () {
      final g = GoiSoHoaDon.tu([
        for (var i = 0; i < 6; i++)
          _bill(id: 'h$i', ten: 'HĐ $i', dueDate: DateTime(2026, 9, 10 + i)),
      ], now: now);
      expect(g.soLieu.where((s) => s.nhan == 'Phải trả').length,
          lessThanOrEqualTo(kToiDaMucMoiGoi));
    });
  });
}
