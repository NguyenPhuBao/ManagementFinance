/// Phần **quyết định** của tự động thanh toán hoá đơn — hàm thuần.
///
/// Đây là chỗ thứ hai trong app tự chuyển tiền khi người dùng vắng mặt (chỗ
/// đầu là trích tiền mục tiêu), nên mọi luật về *dừng đúng lúc* phải test được
/// mà không cần dựng CSDL.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/domain/bill_auto_pay.dart';

Bill _hoaDon({
  bool autoPay = true,
  bool isPaid = false,
  String payStatus = 'Pending',
  bool isDeleted = false,
  String? walletId = 'w1',
  String? categoryId = 'c1',
  DateTime? dueDate,
}) =>
    Bill(
      id: 'b1',
      idaccount: 7,
      walletId: walletId,
      categoryId: categoryId,
      name: 'Tiền điện',
      amount: 200000,
      startDate: DateTime(2025, 8, 5),
      dueDate: dueDate ?? DateTime(2025, 9, 5, 23, 0),
      payStatus: payStatus,
      isPaid: isPaid,
      autoPayEnabled: autoPay,
      timeNotification: '3',
      isRecurrence: true,
      timeRecurrence: kBillCycleMonth,
      recurrence: 'monthly',
      icon: 'receipt',
      colour: '#4CAF50',
      note: '',
      isDeleted: isDeleted,
      syncStatus: 'synced',
      syncRetryCount: 0,
      updatedAt: DateTime(2025, 8, 5),
    );

void main() {
  group('denLuotTuTra', () {
    // Hạn 05/09 23:00, mở app 05/09 07:00.
    final sangNgayHan = DateTime(2025, 9, 5, 7);

    test('đúng ngày đến hạn là đến lượt, kể cả trước giờ ghi trên hạn', () {
      expect(denLuotTuTra(_hoaDon(), sangNgayHan), isTrue,
          reason: 'So theo NGÀY, cùng quy ước với `markOverdue` và nhãn trạng '
              'thái. So DateTime thô thì trả hay không tuỳ giờ người dùng mở '
              'app — hỏng ngẫu nhiên.');
    });

    test('KHÔNG tự trả kỳ đã Skipped dù công tắc bật và đã tới ngày', () {
      expect(denLuotTuTra(_hoaDon(payStatus: 'Skipped'), sangNgayHan), isFalse,
          reason: 'Đây là một trong hai chỗ app tự chuyển tiền khi người dùng '
              'vắng mặt. Trừ ví cho một kỳ họ đã chủ động bỏ là mất tiền thật, '
              'và không có gì trên màn hình báo cho họ biết.');
    });

    test('chưa tới ngày đến hạn thì KHÔNG trả sớm', () {
      expect(denLuotTuTra(_hoaDon(), DateTime(2025, 9, 4, 23, 59)), isFalse,
          reason: 'Trả sớm một ngày là rút tiền trước khi người dùng kịp nạp '
              'lương vào ví.');
    });

    test('đã quá hạn vẫn đến lượt (trả bù)', () {
      expect(denLuotTuTra(_hoaDon(), DateTime(2025, 10, 1)), isTrue);
    });

    test('không bật thì không bao giờ đến lượt', () {
      expect(denLuotTuTra(_hoaDon(autoPay: false), sangNgayHan), isFalse);
    });

    test('đã trả theo isPaid thì thôi', () {
      expect(denLuotTuTra(_hoaDon(isPaid: true), sangNgayHan), isFalse,
          reason: 'Cờ đã trả là chốt DUY NHẤT chống trả hai lần — không có '
              'cột "lần chạy cuối" nào khác.');
    });

    test('đã trả theo payStatus (hàng kéo về từ backend) cũng thôi', () {
      expect(denLuotTuTra(_hoaDon(payStatus: 'Payed'), sangNgayHan), isFalse,
          reason: 'Đọc CẢ HAI cột: hàng do bản client cũ ghi có thể lệch nhau, '
              'và trả một hoá đơn đã trả là trừ tiền hai lần.');
    });

    test('đã xoá mềm thì thôi', () {
      expect(denLuotTuTra(_hoaDon(isDeleted: true), sangNgayHan), isFalse);
    });

    test('thiếu ví thì không chạy', () {
      expect(denLuotTuTra(_hoaDon(walletId: null), sangNgayHan), isFalse,
          reason: 'Không có ví thì không biết trừ đâu.');
    });

    test('thiếu danh mục thì không chạy', () {
      expect(denLuotTuTra(_hoaDon(categoryId: null), sangNgayHan), isFalse,
          reason: 'Khoản chi thiếu danh mục bị /sync/push từ chối ở MỌI chu '
              'kỳ — sinh ra nó là kẹt hàng đợi đẩy.');
    });
  });

  group('quyetDinhTuTra', () {
    test('ví đủ thì trả đủ', () {
      final q = quyetDinhTuTra(soTien: 200000, soDuVi: 500000);
      expect(q.loai, LoaiTuTra.traDu);
      expect(q.soTien, 200000);
    });

    test('số dư 0 sau khi trả là hợp lệ', () {
      expect(quyetDinhTuTra(soTien: 200000, soDuVi: 200000).loai,
          LoaiTuTra.traDu);
    });

    test('ví thiếu thì KHÔNG trả, không trả một phần', () {
      final q = quyetDinhTuTra(soTien: 200000, soDuVi: 199999);
      expect(q.loai, LoaiTuTra.viKhongDu);
      expect(q.soTien, 0,
          reason: 'Trả một phần làm một kỳ ra hai con số mà vẫn không hết nợ. '
              'Bỏ kỳ, báo, và lượt sau tự thử lại.');
    });

    test('số tiền không dương là cấu hình hỏng', () {
      expect(quyetDinhTuTra(soTien: 0, soDuVi: 500000).loai,
          LoaiTuTra.khongChayDuoc);
    });
  });

  test('khoaKyTuTra định danh theo NGÀY đến hạn', () {
    expect(khoaKyTuTra('b1', DateTime(2025, 9, 5, 23, 0)), 'b1:2025-09-05',
        reason: 'Đi thẳng vào dedupeKey của thông báo. Mỗi kỳ là một hàng '
            'riêng nên id + ngày hạn là đủ; gộp theo lượt quét thì mỗi lần mở '
            'app lại thêm một "Đã tự trả" cho việc chỉ xảy ra một lần.');
  });

  test('trần số kỳ mỗi lượt là 3', () {
    expect(tranKyTuTraMoiLuot, 3,
        reason: 'Bỏ app nửa năm thì sáu tháng tiền điện trả một lúc là rút '
            'cạn ví ngay khi mở app. Phần dư không mất, nó ở lại lượt sau.');
  });
}
