/// Màn xác nhận xoá hoá đơn (`/bills/:id/delete`, Stitch `124611f0…`).
///
/// Trang chỉ HỎI: *Xác nhận Xóa* trả `true`, *Hủy bỏ* / Back trả không-`true`; chỗ gọi tự gửi `DeleteBillEvent`
/// vào `BillBloc` của nó (luồng ở `xac_nhan_xoa_hoa_don_test.dart`). Câu phụ đổi theo trạng thái kỳ — xoá chỉ gỡ
/// đúng MỘT hàng (một kỳ), nên câu "dừng mọi lời nhắc" của Stitch chỉ đúng với kỳ còn phải trả (người dùng chốt
/// 2026-10-17).
library;

import '../../../../helpers/nguon_doc_gia.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/bill/data/models/bill_entity.dart';
import 'package:flowmoney/features/bill/domain/bill_recurrence.dart';
import 'package:flowmoney/features/bill/presentation/pages/bill_delete_page.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    if (sl.isRegistered<AppDatabase>()) await sl.unregister<AppDatabase>();
    sl.registerSingleton<AppDatabase>(db);
    dangKyNguonDocGia(db);
    await db.walletDao.insert(WalletsCompanion.insert(
      id: 'w1',
      idaccount: 10,
      name: 'Tiền mặt',
      balance: const drift.Value(5000000),
      updatedAt: DateTime(2026, 9, 1),
    ));
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: 'c1',
      idaccount: 10,
      name: 'Điện nước',
      classify: 'chi',
      icon: const drift.Value('receipt'),
      colour: const drift.Value('#4CAF50'),
      updatedAt: DateTime(2026, 9, 1),
    ));
  });

  tearDown(() async {
    await sl.unregister<AppDatabase>();
    await db.close();
  });

  Future<BillEntity> hoaDon(
    String id, {
    String ten = 'Tiền điện',
    double soTien = 250000,
    bool paid = false,
    bool boQua = false,
    bool lap = true,
  }) async {
    await db.billDao.insert(BillsCompanion.insert(
      id: id,
      idaccount: 10,
      walletId: const drift.Value('w1'),
      categoryId: const drift.Value('c1'),
      name: ten,
      amount: soTien,
      dueDate: DateTime(2026, 9, 8),
      payStatus: drift.Value(boQua ? 'Skipped' : (paid ? 'Payed' : 'Pending')),
      isPaid: drift.Value(paid),
      isRecurrence: drift.Value(lap),
      timeRecurrence: const drift.Value(kBillCycleMonth),
      updatedAt: DateTime(2026, 9, 1),
    ));
    return BillEntity.fromDrift((await db.billDao.getById(id))!);
  }

  /// Dựng trang trên một trang chủ giả rồi `push` — để đọc được giá trị `pop` trả về.
  Future<List<Object?>> moTrang(WidgetTester tester, String id,
      {Size kho = const Size(411, 1400)}) async {
    tester.view.physicalSize = kho;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final ketQua = <Object?>[];
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              ketQua.add(await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => BillDeletePage(id: id)),
              ));
            },
            child: const Text('mở'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    return ketQua;
  }

  group('cauXacNhanXoaHoaDon — câu phụ theo trạng thái kỳ', () {
    test('kỳ còn phải trả của hoá đơn lặp: câu Stitch + không tạo kỳ kế tiếp', () async {
      final cau = cauXacNhanXoaHoaDon(await hoaDon('a'));
      expect(cau, startsWith('Thao tác này sẽ dừng tất cả các lời nhắc nhở'));
      expect(cau, contains('không tạo kỳ kế tiếp'),
          reason: 'Kỳ kế tiếp chỉ sinh khi trả / bỏ qua kỳ này — xoá kỳ đang mở là chuỗi dừng.');
      expect(cau, contains('vẫn sẽ được giữ lại'));
    });

    test('kỳ còn phải trả của hoá đơn KHÔNG lặp: không nhắc tới kỳ kế tiếp', () async {
      final cau = cauXacNhanXoaHoaDon(await hoaDon('a', lap: false));
      expect(cau, startsWith('Thao tác này sẽ dừng tất cả các lời nhắc nhở'));
      expect(cau, isNot(contains('kỳ kế tiếp')),
          reason: 'Hoá đơn một lần không có kỳ kế tiếp — nhắc tới là nói một chuyện không có.');
    });

    test('kỳ ĐÃ trả: chỉ gỡ khỏi danh sách, tiền không về ví, hoàn tác TRƯỚC khi xoá', () async {
      final cau = cauXacNhanXoaHoaDon(await hoaDon('a', paid: true));
      expect(cau, isNot(contains('dừng tất cả các lời nhắc')),
          reason: 'Kỳ kế tiếp (nếu có) là một hàng khác, vẫn được nhắc và vẫn tự trả.');
      expect(cau, contains('chỉ gỡ nó khỏi danh sách hoá đơn'));
      expect(cau, contains('số dư ví không đổi'));
      expect(cau, contains('Hoàn tác trước khi xoá'),
          reason: 'Xoá xong thì nút Hoàn tác biến mất cùng hoá đơn, còn khoản chi ở sổ bị khoá.');
    });

    test('kỳ BỎ QUA: chỉ gỡ khỏi danh sách — xét trước nhánh đã trả', () async {
      final cau = cauXacNhanXoaHoaDon(await hoaDon('a', boQua: true));
      expect(cau, contains('đã bỏ qua'));
      expect(cau, contains('chỉ gỡ nó khỏi danh sách hoá đơn'));
      expect(cau, isNot(contains('Hoàn tác')),
          reason: 'Kỳ bỏ qua chưa từng trừ tiền — không có gì để trả lại ví.');
    });
  });

  testWidgets('thẻ hiện dữ liệu THẬT của hoá đơn, không còn dữ liệu mẫu', (tester) async {
    await hoaDon('a');
    await moTrang(tester, 'a');

    expect(find.text('Xóa Hóa đơn'), findsOneWidget);
    expect(find.text('Bạn có chắc chắn muốn xóa hóa đơn này?'), findsOneWidget);
    expect(find.text('Tiền điện'), findsOneWidget);
    expect(find.text('Thanh toán hàng tháng'), findsOneWidget);
    expect(find.text('250.000 đ'), findsOneWidget, reason: 'Số tiền đi qua CurrencyFormatter.');
    expect(find.text('Hạn 08/09/2026'), findsOneWidget,
        reason: 'Cùng dạng ngày với thẻ danh sách và trang chi tiết.');
    expect(find.text('Điện nước'), findsOneWidget);
    expect(find.text('Tiền mặt'), findsOneWidget);
    expect(find.textContaining('Netflix'), findsNothing);
    expect(find.textContaining('Visa'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hoá đơn không lặp: "Thanh toán một lần"', (tester) async {
    await hoaDon('a', lap: false);
    await moTrang(tester, 'a');
    expect(find.text('Thanh toán một lần'), findsOneWidget);
  });

  testWidgets('Xác nhận Xóa trả true — trang KHÔNG tự xoá', (tester) async {
    await hoaDon('a');
    final ketQua = await moTrang(tester, 'a');

    await tester.tap(find.text('Xác nhận Xóa'));
    await tester.pumpAndSettle();

    expect(ketQua, [true]);
    expect(find.byType(BillDeletePage), findsNothing);
    expect((await db.billDao.getById('a'))!.isDeleted, isFalse,
        reason: 'Trang chỉ hỏi; chỗ gọi gửi DeleteBillEvent vào BillBloc của nó.');
  });

  testWidgets('Hủy bỏ trả false', (tester) async {
    await hoaDon('a');
    final ketQua = await moTrang(tester, 'a');

    await tester.tap(find.text('Hủy bỏ'));
    await tester.pumpAndSettle();

    expect(ketQua, [false]);
    expect(find.byType(BillDeletePage), findsNothing);
  });

  testWidgets('không tìm thấy hoá đơn: không có nút xác nhận', (tester) async {
    await moTrang(tester, 'khong-co');
    expect(find.text('Không tìm thấy hoá đơn'), findsOneWidget);
    expect(find.text('Xác nhận Xóa'), findsNothing);
  });

  testWidgets('320 dp: tên dài + số tiền 13 chữ số không tràn, số tiền một dòng', (tester) async {
    await hoaDon('a',
        ten: 'Tiền thuê căn hộ chung cư tầng mười hai khu đô thị mới',
        soTien: 9999999999999);
    await moTrang(tester, 'a', kho: const Size(320, 1400));

    expect(tester.takeException(), isNull);
    final soTien = find.text('9.999.999.999.999 đ');
    expect(soTien, findsOneWidget);
    final hop = tester.getRect(soTien);
    expect(hop.height, lessThan(30),
        reason: 'Text ngắt dòng không báo tràn — phải đo chiều cao thật (một dòng ~ 18–24 px).');
    expect(hop.right, lessThanOrEqualTo(320));
    expect(tester.renderObject<RenderParagraph>(soTien).didExceedMaxLines, isFalse,
        reason: '`maxLines: 1` không có FittedBox thì CẮT số tiền im lặng — không tràn, không ngắt dòng, '
            'chỉ thiếu chữ số. Số phải co lại cho đủ.');
  });
}
