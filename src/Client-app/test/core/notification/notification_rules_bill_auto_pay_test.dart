/// Luật thông báo cho các kỳ **tự động thanh toán hoá đơn**.
///
/// Đây là chỗ thứ hai trong app tự chuyển tiền khi người dùng vắng mặt. Im
/// lặng nghĩa là họ chỉ thấy số dư ví hụt đi mà không biết vì sao — và khoản
/// ấy nằm lẫn giữa các giao dịch khác trong sổ. Thành công cũng phải báo, thất
/// bại càng phải báo.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/notification/notification_rules.dart';
import 'package:flowmoney/core/notification/prefs/notification_prefs.dart';
import 'package:flowmoney/features/bill/domain/bill_auto_pay.dart';
import 'package:flowmoney/features/bill/domain/bill_auto_pay_runner.dart';

void main() {
  final now = DateTime(2026, 9, 15, 10);
  final ky = DateTime(2026, 9, 15);

  BillAutoPayEvent suKien({
    LoaiTuTra loai = LoaiTuTra.traDu,
    double soTien = 300000,
    String? tenVi = 'Tiền mặt',
  }) =>
      BillAutoPayEvent(
        billId: 'hd1',
        billName: 'Tiền điện',
        ky: ky,
        loai: loai,
        soTien: soTien,
        tenVi: tenVi,
      );

  List<NotificationCandidate> chay(List<BillAutoPayEvent> autoPays,
      {DateTime? silenceBefore}) {
    return buildNotificationCandidates(NotificationRuleInput(
      now: now,
      autoPays: autoPays,
      silenceBefore: silenceBefore,
    ));
  }

  test('trả xong thì báo: tên, số tiền, ví', () {
    final c = chay([suKien()]).single;

    expect(c.kind, NotificationKind.billAutoPaid);
    expect(c.body, contains('Tiền điện'));
    expect(c.body, contains('300'));
    expect(c.body, contains('Tiền mặt'),
        reason: 'Câu báo phải nói rõ bao nhiêu và từ ví nào, nếu không người '
            'dùng chỉ thấy ví hụt đi.');
    expect(c.severity, NotificationSeverity.info);
    expect(c.subjectType, 'bill');
    expect(c.subjectId, 'hd1');
    expect(c.deeplink, '/bills');
  });

  test('khoá chống trùng theo KỲ, không theo lượt quét', () {
    final c = chay([suKien()]).single;

    expect(c.dedupeKey, 'billAuto:hd1:2026-09-15',
        reason: 'Quét chạy sau mọi lần đồng bộ. Thiếu đơn vị lặp lại là mỗi '
            'lần mở app lại thêm một "Đã tự trả" cho việc chỉ xảy ra một lần.');
  });

  test('ví không đủ thì báo cảnh báo và nói sẽ tự thử lại', () {
    final c = chay([suKien(loai: LoaiTuTra.viKhongDu, soTien: 0)]).single;

    expect(c.kind, NotificationKind.billAutoPayFailed);
    expect(c.severity, NotificationSeverity.warning);
    expect(c.body, contains('Tiền mặt'));
    expect(c.body, contains('không đủ'));
    expect(c.body, contains('thử lại'),
        reason: 'Bỏ qua một kỳ vì ví cạn mà không nói gì là để người dùng tin '
            'rằng hoá đơn đã trả, rồi phát hiện khi bị cắt điện.');
    expect(c.dedupeKey, 'billAutoFail:hd1:2026-09-15',
        reason: 'Một lần cho mỗi kỳ dù lượt quét nào cũng thử lại và thất bại.');
  });

  test('không chạy được (ví/danh mục không còn) thì chỉ người dùng đi sửa', () {
    final c =
        chay([suKien(loai: LoaiTuTra.khongChayDuoc, soTien: 0, tenVi: null)])
            .single;

    expect(c.kind, NotificationKind.billAutoPayFailed);
    expect(c.body, contains('Tiền điện'));
    expect(c.body.toLowerCase(), contains('chọn lại'));
  });

  test('mốc sự kiện là LÚC TRẢ nên cửa sổ im lặng không nuốt nó', () {
    final ra = chay(
      [suKien()],
      silenceBefore: now.subtract(const Duration(days: 30)),
    );

    expect(ra, hasLength(1),
        reason: 'Tiền rời ví lúc quét, không phải lúc kỳ đến hạn. Một khoản trả '
            'bù cho kỳ hai tháng trước vẫn phải được báo — trần 3 kỳ mỗi lượt '
            'đã chặn cơn lũ rồi, không cần chặn thêm ở đây.');
    expect(ra.single.createdAt, now);
  });

  test('hai kỳ khác nhau là hai thông báo', () {
    final ra = chay([
      suKien(),
      BillAutoPayEvent(
        billId: 'hd1',
        billName: 'Tiền điện',
        ky: DateTime(2026, 8, 15),
        loai: LoaiTuTra.traDu,
        soTien: 300000,
        tenVi: 'Tiền mặt',
      ),
    ]);

    expect(ra.map((c) => c.dedupeKey).toSet(), hasLength(2),
        reason: 'Trả bù hai tháng là hai lần tiền rời ví.');
  });

  test('hai loại mới thuộc nhóm hoá đơn', () {
    expect(nhomCua(NotificationKind.billAutoPaid), NotificationGroup.bill);
    expect(
        nhomCua(NotificationKind.billAutoPayFailed), NotificationGroup.bill);
    const p = NotificationPrefs(nhomTat: {NotificationGroup.bill});
    expect(p.chapNhan(NotificationKind.billAutoPaid), isFalse,
        reason: 'Tắt nhóm hoá đơn là tắt luôn, người dùng không có công tắc '
            'thứ năm để tìm.');
  });
}
