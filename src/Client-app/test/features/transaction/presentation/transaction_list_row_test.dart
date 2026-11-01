import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/cap_gop_quy_nguon.dart';
import 'package:flowmoney/features/transaction/data/hoa_don_da_xoa_nguon.dart';
import 'package:flowmoney/features/transaction/domain/transaction_lookup.dart';
import 'package:flowmoney/features/transaction/domain/transaction_owner.dart';
import 'package:flowmoney/features/transaction/presentation/widgets/transaction_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/ui/thong_bao_nhanh.dart';
import '../../../helpers/bat_thong_bao.dart';

import '../../category/presentation/category_test_fakes.dart';

/// Hàng trong sổ giao dịch: vuốt trái để xoá, NHƯNG khoản thuộc mục tiêu, hay
/// khoản trả của hoá đơn còn sống, thì bật lại và chỉ đường thay vì xoá; khoản
/// trả hoá đơn kiểu cũ / mồ côi (việc 4c) hỏi xác nhận kèm câu cảnh báo. Tách thành widget riêng vì
/// `TransactionPage` nối thẳng vào `sl` và `AuthBloc`, không dựng được trong
/// test.
void main() {
  TransactionEntity tx({
    String? goalId,
    String? billId,
    String note = '',
    String type = 'chi',
  }) =>
      TransactionEntity(
        id: 'tx-$note-$goalId',
        walletId: 'w',
        idaccount: 1,
        goalId: goalId,
        billId: billId,
        amount: 25000,
        type: type,
        note: note,
        date: DateTime(2026, 9, 6),
        updatedAt: DateTime(2026, 9, 6),
      );

  /// Câu phản hồi đi qua `ThongBaoNhanh` (E4) — gom ở [bat].
  late BatThongBao bat;

  /// Số lần `onDelete` được gọi trong lượt dựng gần nhất.
  var soLanXoa = 0;

  /// Dựng một dòng rồi vuốt trái hết cỡ. Có hộp xác nhận thì dừng ở hộp (chưa bấm gì).
  Future<void> vuot(
    WidgetTester tester,
    TransactionEntity transaction, {
    HoaDonDaXoaNguon? nguon,
  }) async {
    bat = batThongBao();
    soLanXoa = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TransactionListRow(
          transaction: transaction,
          onDelete: () => soLanXoa++,
          nguonHoaDonDaXoa: nguon,
        ),
      ),
    ));
    // Tìm theo key chứ không theo kiểu (từ hồi SnackBar — cũng là một Dismissible).
    await tester.drag(find.byKey(Key(transaction.id)), const Offset(-600, 0));
    await tester.pumpAndSettle();
  }

  Future<int> vuotXoa(WidgetTester tester, TransactionEntity transaction) async {
    await vuot(tester, transaction);
    return soLanXoa;
  }

  testWidgets('giao dịch thường: vuốt là xoá và báo đã xoá', (tester) async {
    final deleted = await vuotXoa(tester, tx(note: 'Cà phê'));

    expect(deleted, 1);
    expect(find.byType(AlertDialog), findsNothing,
        reason: 'Giao dịch thường giữ nguyên vuốt-là-xoá — việc 4c không thêm '
            'hộp thoại cho nó (spec mục 4).');
    expect(bat.cau, ['Đã xóa giao dịch']);
    expect(bat.cuoi!.loai, LoaiThongBao.xong);
  });

  group('việc 4c — khoản trả hoá đơn đã mở khoá: hỏi xác nhận kèm cảnh báo', () {
    const ghiChuTra = '${kGhiChuTraHoaDon}Tiền điện';

    testWidgets('kiểu cũ (tiền tố, không billId): hộp mang câu "bản cũ" — Hủy thì KHÔNG xoá',
        (tester) async {
      final khoan = tx(note: ghiChuTra);
      await vuot(tester, khoan);

      expect(find.text('Xoá giao dịch?'), findsOneWidget);
      expect(find.textContaining('ghi bằng bản cũ'), findsOneWidget,
          reason: 'Người dùng phải biết hoá đơn vẫn ghi là đã trả.');

      await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
      await tester.pumpAndSettle();
      expect(soLanXoa, 0);
      expect(find.byKey(Key(khoan.id)), findsOneWidget,
          reason: 'Huỷ thì hàng phải bật lại.');
    });

    testWidgets('kiểu cũ: bấm Xóa thì xoá và báo đã xoá', (tester) async {
      await vuot(tester, tx(note: ghiChuTra));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Xóa'));
      await tester.pumpAndSettle();
      expect(soLanXoa, 1,
          reason: 'Trước 4c khoản này khoá vĩnh viễn — Hoàn tác không lần được.');
      expect(bat.cau, ['Đã xóa giao dịch']);
    });

    testWidgets('mồ côi (cổng nói hoá đơn đã xoá): hộp mang câu "đã xoá"',
        (tester) async {
      await vuot(tester, tx(billId: 'b1', note: ghiChuTra),
          nguon: HoaDonDaXoaNguon((_) async => true));

      expect(find.textContaining('Hoá đơn của khoản này đã xoá'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Xóa'));
      await tester.pumpAndSettle();
      expect(soLanXoa, 1);
    });

    testWidgets('có billId, cổng nói hoá đơn còn: khoá như cũ, không hộp thoại',
        (tester) async {
      await vuot(tester, tx(billId: 'b1', note: ghiChuTra),
          nguon: HoaDonDaXoaNguon((_) async => false));

      expect(find.byType(AlertDialog), findsNothing);
      expect(soLanXoa, 0);
      expect(bat.cau.single, contains('không xoá được từ sổ giao dịch'));
    });
  });

  testWidgets('khoản của mục tiêu: KHÔNG xoá, hàng bật lại, chỉ sang trang mục tiêu',
      (tester) async {
    final khoanNap = tx(goalId: 'g1', type: 'transfer');
    final deleted = await vuotXoa(tester, khoanNap);

    expect(deleted, 0,
        reason: 'Xoá ở sổ chỉ hoàn ví; current_amount của mục tiêu đứng nguyên '
            'nên tiến độ và lịch sử nói ngược nhau.');
    expect(find.byKey(Key(khoanNap.id)), findsOneWidget,
        reason: 'confirmDismiss trả false thì hàng phải còn đó.');
    expect(bat.cau.single, contains('mục tiêu'));
    expect(bat.cuoi!.loai, LoaiThongBao.loi);
  });

  testWidgets('khoản trả hoá đơn còn (có billId): KHÔNG xoá, báo lý do',
      (tester) async {
    final khoanTra = tx(billId: 'b1', note: 'Thanh toán hóa đơn: Tiền điện');
    final deleted = await vuotXoa(tester, khoanTra);

    expect(deleted, 0,
        reason: 'Trả hoá đơn là bốn bước trong một transaction (Payed, giao '
            'dịch, trừ ví, kỳ kế tiếp); xoá một bước thì ba bước kia còn nguyên.');
    expect(find.byKey(Key(khoanTra.id)), findsOneWidget);
    expect(bat.cau.single, contains('hoá đơn'));
    expect(bat.cau.single, contains('không xoá được từ sổ giao dịch'),
        reason: 'Chưa có cổng (dòng đơn lẻ) thì khoản có billId mặc định khoá.');
  });

  testWidgets('hàng không ghi chú hiện nhãn theo loại', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TransactionListRow(
          transaction: tx(type: 'transfer'),
          onDelete: () {},
        ),
      ),
    ));
    expect(find.text('Chuyển khoản'), findsOneWidget);
  });

  testWidgets('bấm vào dòng gọi onTap — đường vào bảng chi tiết', (tester) async {
    var taps = 0;
    final khoanChi = tx(note: 'Cà phê');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TransactionListRow(
          transaction: khoanChi,
          onDelete: () {},
          onTap: () => taps++,
        ),
      ),
    ));

    await tester.tap(find.byKey(Key(khoanChi.id)));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('có lookup thì hiện tên ví và danh mục, không bao giờ in UUID',
      (tester) async {
    final lookup = TransactionLookup(
      wallets: [makeWallet(id: 'w', name: 'Tiền mặt')],
      categories: [makeCategory(id: 'c-food', name: 'Ăn uống')],
    );
    final khoanChi = TransactionEntity(
      id: '6f8e6b7a-5a61-4089-be4b-eb7ef8ae9426',
      walletId: 'w',
      idaccount: 1,
      categoryId: 'c-food',
      amount: 25000,
      type: 'chi',
      note: 'Cà phê',
      date: DateTime(2026, 9, 6),
      updatedAt: DateTime(2026, 9, 6),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TransactionListRow(
          transaction: khoanChi,
          onDelete: () {},
          lookup: lookup,
        ),
      ),
    ));

    expect(find.text('Cà phê'), findsOneWidget);
    expect(find.text('Ăn uống • Tiền mặt'), findsOneWidget);
    expect(find.textContaining('6f8e6b7a'), findsNothing,
        reason: 'Trước 2026-09-06 dòng phụ là "Ví: <UUID>".');
    expect(find.text('-25.000 đ'), findsOneWidget);
  });

  group('nửa riêng của khoản góp / rút (hoiCap, onXoaCap)', () {
    final nuaRieng = TransactionEntity(
      id: 'tx-nua-rieng',
      walletId: 'w',
      idaccount: 1,
      fundPairId: 'cap-1',
      amount: 200000,
      type: 'chi',
      note: 'Góp quỹ · Quỹ chợ',
      date: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    );

    Future<void> dung(
      WidgetTester tester, {
      required Future<CapGopQuy?> Function(TransactionEntity) hoiCap,
      Future<void> Function(String)? onXoaCap,
    }) async {
      bat = batThongBao();
      soLanXoa = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TransactionListRow(
            transaction: nuaRieng,
            onDelete: () => soLanXoa++,
            hoiCap: hoiCap,
            onXoaCap: onXoaCap,
          ),
        ),
      ));
      await tester.drag(find.byKey(Key(nuaRieng.id)), const Offset(-600, 0));
      await tester.pumpAndSettle();
    }

    const cap = CapGopQuy(maCap: 'cap-1', laGop: true, cauXoa: 'Quỹ chợ cũng giảm 200.000 đ.', choThaoTac: true);

    testWidgets('còn cặp: hộp nêu câu của cặp, đồng ý thì xoaCap và KHÔNG onDelete', (tester) async {
      final daXoaCap = <String>[];
      await dung(tester, hoiCap: (_) async => cap, onXoaCap: (m) async => daXoaCap.add(m));

      expect(find.text('Xoá khoản góp?'), findsOneWidget);
      expect(find.text('Quỹ chợ cũng giảm 200.000 đ.'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Xóa'));
      await tester.pumpAndSettle();

      expect(daXoaCap, ['cap-1']);
      expect(soLanXoa, 0,
          reason: 'onDelete gỡ MỘT nửa: trả true cho Dismissible là chạy onDismissed → lệch cặp, đúng lỗi đang chặn.');
      expect(bat.cau, ['Đã xóa giao dịch'], reason: 'onDismissed không chạy khi trả false nên confirmDismiss tự báo.');
    });

    testWidgets('còn cặp, bấm Huỷ: không xoá gì, không báo', (tester) async {
      final daXoaCap = <String>[];
      await dung(tester, hoiCap: (_) async => cap, onXoaCap: (m) async => daXoaCap.add(m));
      await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
      await tester.pumpAndSettle();

      expect(daXoaCap, isEmpty);
      expect(soLanXoa, 0);
      expect(bat.cau, isEmpty);
      expect(find.byKey(Key(nuaRieng.id)), findsOneWidget);
    });

    testWidgets('nhà chỉ xem: báo lỗi, không hộp, không xoá', (tester) async {
      var goi = 0;
      await dung(
        tester,
        hoiCap: (_) async => const CapGopQuy(maCap: 'cap-1', laGop: true, cauXoa: 'x', choThaoTac: false),
        onXoaCap: (_) async => goi++,
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(goi, 0);
      expect(soLanXoa, 0);
      expect(bat.cuoi?.cau, 'Nhà đang ở chế độ chỉ xem.');
      expect(bat.cuoi?.loai, LoaiThongBao.loi);
    });

    testWidgets('xoaCap ném: báo lỗi, hàng không biến mất', (tester) async {
      await dung(tester, hoiCap: (_) async => cap, onXoaCap: (_) async => throw StateError('hỏng'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Xóa'));
      await tester.pumpAndSettle();

      expect(bat.cuoi?.loai, LoaiThongBao.loi, reason: 'Không được báo "Đã xóa" khi chưa xoá.');
      expect(soLanXoa, 0);
      expect(find.byKey(Key(nuaRieng.id)), findsOneWidget);
    });

    testWidgets('hoiCap trả null (khoản thường / đã rời nhà): đường cũ, vuốt là xoá', (tester) async {
      await dung(tester, hoiCap: (_) async => null);
      expect(soLanXoa, 1);
      expect(bat.cau, ['Đã xóa giao dịch']);
    });
  });
}
