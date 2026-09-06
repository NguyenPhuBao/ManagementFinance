import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/presentation/widgets/bill_payment_sheet.dart';

/// Bảng thanh toán hoá đơn: ngoài số tiền và ví, hỏi thêm **ngày trả**.
///
/// Vì sao: người dùng hay ghi lại sau — trả hôm qua bằng tiền mặt, hôm nay mới
/// mở app. Không có ô ngày thì khoản chi luôn mang ngày mở app, và thống kê
/// theo ngày lệch. Ngày không được ở tương lai (repository cũng chặn).
void main() {
  final homNay = DateTime(2026, 9, 6, 10);

  Wallet vi(String id, String ten) => Wallet(
        id: id,
        idaccount: 10,
        name: ten,
        type: 'cash',
        balance: 5000000,
        currency: 'VND',
        icon: 'wallet',
        colour: '#4CAF50',
        isDefault: false,
        isDeleted: false,
        includeInTotal: true,
        status: 'active',
        syncStatus: 'synced',
        syncRetryCount: 0,
        updatedAt: DateTime(2026, 9, 1),
      );

  /// Mở bảng qua modal thật để `Navigator.pop` bên trong có chỗ mà pop.
  Future<void> moBang(
    WidgetTester tester, {
    required void Function(Wallet, double, DateTime) onConfirmed,
  }) async {
    tester.view.physicalSize = const Size(411, 900);
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
                wallets: [vi('w1', 'Tiền mặt')],
                initialAmount: 200000,
                preferredWalletId: 'w1',
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

  testWidgets('có ô ngày trả, điền sẵn hôm nay', (tester) async {
    await moBang(tester, onConfirmed: (_, __, ___) {});

    expect(find.byKey(const ValueKey('bill-pay-date')), findsOneWidget,
        reason: 'Trả hôm qua, hôm nay mới ghi — phải có chỗ chọn ngày.');
    expect(find.text('06/09/2026'), findsOneWidget,
        reason: 'Mặc định là hôm nay, cùng định dạng dd/MM/yyyy của trang.');
    expect(tester.takeException(), isNull,
        reason: 'Thêm một hàng không được làm bảng tràn ở 411dp.');
  });

  testWidgets('chọn ngày khác rồi chọn ví → callback nhận đúng ngày',
      (tester) async {
    DateTime? ngayNhan;
    double? soTienNhan;
    await moBang(tester, onConfirmed: (_, soTien, ngay) {
      soTienNhan = soTien;
      ngayNhan = ngay;
    });

    await tester.tap(find.byKey(const ValueKey('bill-pay-date')));
    await tester.pumpAndSettle();
    final picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(picker.lastDate, DateTime(2026, 9, 6),
        reason: 'Khoản chi không được mang ngày chưa tới; repository sẽ ném '
            'ArgumentError, nên chặn ngay từ bộ chọn.');

    await tester.tap(find.text('4'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('04/09/2026'), findsOneWidget);

    await tester.tap(find.text('Tiền mặt'));
    await tester.pumpAndSettle();

    expect(ngayNhan, DateTime(2026, 9, 4));
    expect(soTienNhan, 200000);
  });

  testWidgets('không đổi ngày thì callback nhận hôm nay', (tester) async {
    DateTime? ngayNhan;
    await moBang(tester, onConfirmed: (_, __, ngay) => ngayNhan = ngay);

    await tester.tap(find.text('Tiền mặt'));
    await tester.pumpAndSettle();

    expect(ngayNhan, DateTime(2026, 9, 6),
        reason: 'Chỉ lấy phần ngày, bỏ giờ — giờ là chi tiết của lúc bấm nút, '
            'không phải của sự việc.');
  });
}
