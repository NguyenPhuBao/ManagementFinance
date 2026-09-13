import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/presentation/widgets/bill_payment_sheet.dart';

/// Bảng thanh toán hoá đơn (người dùng chốt 2026-09-06): bấm "Thanh toán" là
/// thấy **thông tin hoá đơn** ở trên, dưới cùng là nút **"Thanh toán bằng
/// <ví của hoá đơn>"**, có "Chọn ví khác". Giữa là ba ô: số tiền thật của
/// kỳ, ngày trả (không cho tương lai), ghi chú riêng của lần trả.
void main() {
  final homNay = DateTime(2026, 9, 6, 10);

  Wallet vi(String id, String ten, {bool macDinh = false}) => Wallet(
        id: id,
        idaccount: 10,
        name: ten,
        type: 'cash',
        balance: 5000000,
        currency: 'VND',
        icon: 'wallet',
        colour: '#4CAF50',
        isDefault: macDinh,
        isDeleted: false,
        includeInTotal: true,
        status: 'active',
        syncStatus: 'synced',
        syncRetryCount: 0,
        updatedAt: DateTime(2026, 9, 1),
      );

  Bill hoaDon({
    String walletId = 'w1',
    DateTime? dueDate,
    String note = '',
    bool tuTra = false,
    DateTime? periodEnd,
  }) =>
      Bill(
        id: 'a',
        idaccount: 10,
        walletId: walletId,
        categoryId: 'c1',
        name: 'Tiền điện',
        amount: 200000,
        startDate: (dueDate ?? DateTime(2026, 9, 8))
            .subtract(const Duration(days: 31)),
        periodEnd: periodEnd,
        dueDate: dueDate ?? DateTime(2026, 9, 8),
        payStatus: 'Pending',
        isPaid: false,
        autoPayEnabled: tuTra,
        timeNotification: '3',
        isRecurrence: true,
        timeRecurrence: kBillCycleMonth,
        recurrence: 'monthly',
        icon: 'receipt',
        colour: '#4CAF50',
        note: note,
        isDeleted: false,
        syncStatus: 'synced',
        syncRetryCount: 0,
        updatedAt: DateTime(2026, 9, 1),
      );

  /// Mở bảng qua modal thật để `Navigator.pop` bên trong có chỗ mà pop.
  Future<void> moBang(
    WidgetTester tester, {
    required void Function(Wallet, double, DateTime, String?) onConfirmed,
    List<Wallet>? wallets,
    Bill? bill,
  }) async {
    tester.view.physicalSize = const Size(411, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => BillPaymentSheet(
                bill: bill ?? hoaDon(),
                wallets: wallets ?? [vi('w1', 'Tiền mặt'), vi('w2', 'Ví phụ')],
                categoryName: 'Điện nước',
                today: homNay,
                onConfirmed: onConfirmed,
              ),
            ),
            child: const Text('mở'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
  }

  testWidgets('hiện thông tin hoá đơn và nút trả bằng ví của hoá đơn',
      (tester) async {
    await moBang(tester, onConfirmed: (_, __, ___, ____) {});

    expect(find.byKey(const ValueKey('bill-pay-info')), findsOneWidget);
    expect(find.text('Tiền điện'), findsOneWidget,
        reason: 'Bấm Thanh toán là phải thấy ngay mình đang trả hoá đơn nào.');
    // Người dùng muốn thấy NHIỀU hơn tên + hạn: đủ như trang chi tiết.
    expect(find.text('SẮP ĐẾN HẠN'), findsOneWidget,
        reason: 'Cùng bốn nhãn trạng thái với danh sách.');
    expect(find.text('08/09/2026 (còn 2 ngày)'), findsOneWidget,
        reason: 'Đến hạn kèm còn bao nhiêu ngày, tính từ `today` tiêm vào.');
    expect(find.text('08/08/2026 → 08/09/2026'), findsOneWidget,
        reason: 'Khoảng kỳ tính tiền, từ startDate tới dueDate.');
    expect(find.text('Hàng tháng'), findsOneWidget);
    expect(find.text('Điện nước'), findsOneWidget);
    expect(find.text('Tiền mặt'), findsOneWidget,
        reason: 'Ví của hoá đơn, tra tên từ danh sách ví.');
    expect(find.text('3 ngày'), findsOneWidget, reason: 'Nhắc trước.');
    expect(find.text('Tắt'), findsOneWidget, reason: 'Tự động trả.');
    expect(find.text('Ghi chú'), findsNothing,
        reason: 'Hoá đơn không có ghi chú thì không bày hàng trống.');
    expect(find.text('Thanh toán bằng Tiền mặt'), findsOneWidget,
        reason: 'Ví mặc định là ví đã gắn với hoá đơn — một nút, không phải '
            'một danh sách phải chọn.');
    expect(find.byKey(const ValueKey('bill-pay-wallet-w2')), findsNothing,
        reason: 'Danh sách ví chỉ mở khi bấm "Chọn ví khác".');
    expect(find.text('06/09/2026'), findsOneWidget,
        reason: 'Ngày trả mặc định hôm nay, định dạng dd/MM/yyyy.');
    expect(tester.takeException(), isNull, reason: 'Không tràn ở 411dp.');
  });

  testWidgets('bấm nút chính → callback nhận ví của hoá đơn, số tiền, hôm nay',
      (tester) async {
    Wallet? viNhan;
    double? soTienNhan;
    DateTime? ngayNhan;
    String? ghiChu = 'chưa gọi';
    await moBang(tester, onConfirmed: (w, s, d, n) {
      viNhan = w;
      soTienNhan = s;
      ngayNhan = d;
      ghiChu = n;
    });

    await tester.tap(find.byKey(const ValueKey('bill-pay-confirm')));
    await tester.pumpAndSettle();

    expect(viNhan?.id, 'w1');
    expect(soTienNhan, 200000);
    expect(ngayNhan, DateTime(2026, 9, 6),
        reason: 'Chỉ lấy phần ngày, bỏ giờ.');
    expect(ghiChu, isNull, reason: 'Không gõ ghi chú thì null.');
    expect(find.byType(BillPaymentSheet), findsNothing,
        reason: 'Xác nhận xong thì bảng đóng.');
  });

  testWidgets(
      'Chọn ví khác → danh sách → chọn Ví phụ → nút đổi tên, trả bằng ví ấy',
      (tester) async {
    Wallet? viNhan;
    await moBang(tester, onConfirmed: (w, __, ___, ____) => viNhan = w);

    await tester.tap(find.byKey(const ValueKey('bill-pay-other-wallet')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bill-pay-wallet-w2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bill-pay-wallet-w2')));
    await tester.pumpAndSettle();
    expect(find.text('Thanh toán bằng Ví phụ'), findsOneWidget);
    expect(find.byKey(const ValueKey('bill-pay-wallet-w2')), findsNothing,
        reason: 'Chọn xong thì danh sách gập lại.');

    await tester.tap(find.byKey(const ValueKey('bill-pay-confirm')));
    await tester.pumpAndSettle();
    expect(viNhan?.id, 'w2');
  });

  testWidgets('ví của hoá đơn không còn → dùng ví có cờ mặc định',
      (tester) async {
    await moBang(
      tester,
      bill: hoaDon(walletId: 'w-da-xoa'),
      wallets: [vi('w1', 'Tiền mặt'), vi('w2', 'Ví phụ', macDinh: true)],
      onConfirmed: (_, __, ___, ____) {},
    );
    expect(find.text('Thanh toán bằng Ví phụ'), findsOneWidget,
        reason: 'Ví gắn với hoá đơn đã bị xoá thì rơi về ví mặc định của '
            'tài khoản, không phải ví đầu danh sách một cách tình cờ.');
  });

  testWidgets('số tiền ≤ 0 → không đóng bảng, báo lỗi tại chỗ', (tester) async {
    var goi = false;
    await moBang(tester, onConfirmed: (_, __, ___, ____) => goi = true);

    await tester.enterText(find.byKey(const ValueKey('bill-pay-amount')), '0');
    await tester.tap(find.byKey(const ValueKey('bill-pay-confirm')));
    await tester.pumpAndSettle();

    expect(goi, isFalse);
    expect(find.text('Nhập số tiền lớn hơn 0'), findsOneWidget);
    expect(find.byType(BillPaymentSheet), findsOneWidget,
        reason: 'Đóng rồi báo lỗi thì người dùng mất luôn số vừa gõ.');
  });

  testWidgets('chọn ngày khác → callback nhận đúng ngày, tương lai bị khoá',
      (tester) async {
    DateTime? ngayNhan;
    await moBang(tester, onConfirmed: (_, __, d, ___) => ngayNhan = d);

    await tester.tap(find.byKey(const ValueKey('bill-pay-date')));
    await tester.pumpAndSettle();
    final picker =
        tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(picker.lastDate, DateTime(2026, 9, 6),
        reason: 'Khoản chi không được mang ngày chưa tới; repository sẽ ném '
            'ArgumentError, nên chặn ngay từ bộ chọn.');

    await tester.tap(find.text('4'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('04/09/2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bill-pay-confirm')));
    await tester.pumpAndSettle();
    expect(ngayNhan, DateTime(2026, 9, 4));
  });

  testWidgets('ô ghi chú: có gõ thì callback nhận', (tester) async {
    String? ghiChu;
    await moBang(tester, onConfirmed: (_, __, ___, n) => ghiChu = n);

    await tester.enterText(
        find.byKey(const ValueKey('bill-pay-note')), 'Số công tơ 1234');
    await tester.tap(find.byKey(const ValueKey('bill-pay-confirm')));
    await tester.pumpAndSettle();
    expect(ghiChu, 'Số công tơ 1234');
  });

  testWidgets('quá hạn, có ghi chú, bật tự trả → khối thông tin nói đủ',
      (tester) async {
    await moBang(
      tester,
      bill: hoaDon(
        dueDate: DateTime(2026, 9, 3),
        note: 'Số công tơ tháng trước 1200',
        tuTra: true,
      ),
      onConfirmed: (_, __, ___, ____) {},
    );
    expect(find.text('QUÁ HẠN'), findsOneWidget);
    expect(find.text('03/09/2026 (quá hạn 3 ngày)'), findsOneWidget);
    expect(find.text('Số công tơ tháng trước 1200'), findsOneWidget,
        reason: 'Ghi chú cố định của hoá đơn khác ghi chú của lần trả.');
    expect(find.text('Bật'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Không tràn ở 411dp.');
  });

  testWidgets('đến hạn hôm nay → "(hôm nay)"', (tester) async {
    await moBang(
      tester,
      bill: hoaDon(dueDate: DateTime(2026, 9, 6, 23)),
      onConfirmed: (_, __, ___, ____) {},
    );
    expect(find.text('06/09/2026 (hôm nay)'), findsOneWidget,
        reason:
            'So theo NGÀY, không theo giờ: hạn 23h hôm nay vẫn là hôm nay.');
  });
  testWidgets('dòng Kỳ dùng ngày kết thúc kỳ khi có ân hạn', (tester) async {
    // helper `hoaDon` đặt startDate = dueDate − 31 ngày; với due 16/10 là 15/09.
    await moBang(
      tester,
      onConfirmed: (_, __, ___, ____) {},
      bill: hoaDon(
          dueDate: DateTime(2026, 10, 16), periodEnd: DateTime(2026, 10, 1)),
    );
    expect(find.text('15/09/2026 → 01/10/2026'), findsOneWidget,
        reason: 'Kỳ tính tiền kết thúc ở periodEnd, không phải hạn trả.');
    expect(find.textContaining('16/10/2026'), findsOneWidget);
  });
}
