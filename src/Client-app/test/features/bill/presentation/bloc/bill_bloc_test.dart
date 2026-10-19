import 'package:flowmoney/features/bill/data/models/bill_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/data/datasources/bill_local_datasource.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository_impl.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_bloc.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_event.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_state.dart';

void main() {
  late AppDatabase db;
  late BillRepositoryImpl repository;
  late BillBloc bloc;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = BillRepositoryImpl(
      dataSource: BillLocalDataSource(db),
      db: db,
    );
    bloc = BillBloc(repository: repository);
  });

  tearDown(() async {
    await bloc.close();
    await db.close();
  });

  test('LoadBillsEvent emits BillLoaded with correct unpaid summary', () async {
    await db.billDao.insert(
      BillsCompanion.insert(
        id: '1',
        idaccount: 1,
        name: 'Internet',
        amount: 300000.0,
        dueDate: DateTime.now(),
        isPaid: const Value(false),
        updatedAt: DateTime.now(),
      ),
    );

    bloc.add(LoadBillsEvent(idaccount: 1));

    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<BillLoaded>().having(
          (s) => s.totalUnpaidAmount,
          'totalUnpaidAmount',
          300000.0,
        ),
      ),
    );
  });

  test('thanh toán hoá đơn đã trả báo đúng lý do, không phải lỗi chung chung',
      () async {
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w1',
        idaccount: 1,
        name: 'Ví',
        balance: const Value(1000000.0),
        updatedAt: DateTime.now(),
      ),
    );
    await db.billDao.insert(
      BillsCompanion.insert(
        id: 'paid-1',
        idaccount: 1,
        walletId: const Value('w1'),
        name: 'Internet',
        amount: 100000.0,
        dueDate: DateTime.now(),
        payStatus: const Value('Payed'),
        isPaid: const Value(true),
        updatedAt: DateTime.now(),
      ),
    );
    final bill = (await db.billDao.getAll(1)).single;

    bloc.add(PayBillEvent(bill: BillEntity.fromDrift(bill), walletId: 'w1', idaccount: 1));

    final state = await bloc.stream.firstWhere((s) => s is BillError) as BillError;
    expect(
      state.message,
      'Hóa đơn này đã được thanh toán rồi.',
      reason: 'Ném nguyên exception ra màn hình cho người dùng đọc một chuỗi '
          'kỹ thuật, trong khi đây là tình huống bình thường: bấm nút hai lần.',
    );
  });

  test('hoàn tác khoản trả kiểu cũ (không billId) chỉ đường sang Sổ giao dịch',
      () async {
    // Kỳ đã trả mà KHÔNG có khoản chi nào mang billId — khoản trả ghi trước
    // 2026-09-12 (tiền tố ghi chú, cột nối trống) → undoPayment ném
    // BillUndoUnavailableException.
    await db.billDao.insert(
      BillsCompanion.insert(
        id: 'kieu-cu',
        idaccount: 1,
        name: 'Internet',
        amount: 100000.0,
        dueDate: DateTime.now(),
        payStatus: const Value('Payed'),
        isPaid: const Value(true),
        updatedAt: DateTime.now(),
      ),
    );

    bloc.add(UndoPaymentEvent(billId: 'kieu-cu'));

    final state =
        await bloc.stream.firstWhere((s) => s is BillError) as BillError;
    expect(
      state.message,
      'Không tìm thấy khoản chi của lần thanh toán này. Mở lại trang rồi bấm '
      'Hoàn tác để đưa kỳ về chưa trả.',
      reason: 'Trang chỉ gửi UndoPaymentEvent khi bản đồ khoản chi của nó CÓ '
          'khoản gắn billId — tới được đây là bản đồ cũ hơn CSDL. Câu cũ bảo '
          '"xoá ở Sổ, kỳ vẫn ghi là đã trả": ngõ cụt, kỳ không bao giờ về chưa '
          'trả. Trang không nạp lại sau BillError, nên "bấm lại" mở lại đúng '
          'hộp cũ — phải mở lại trang.',
    );
  });

  group('DatLaiChuaTraEvent (kỳ kiểu cũ về chưa trả, không hoàn tiền)', () {
    Future<void> kyDaTra(String id) => db.billDao.insert(
          BillsCompanion.insert(
            id: id,
            idaccount: 1,
            name: 'Internet',
            amount: 100000.0,
            dueDate: DateTime.now(),
            payStatus: const Value('Payed'),
            isPaid: const Value(true),
            updatedAt: DateTime.now(),
          ),
        );

    test('thành công: báo đã đưa về chưa thanh toán, kỳ về Pending', () async {
      await kyDaTra('kieu-cu');

      bloc.add(DatLaiChuaTraEvent(billId: 'kieu-cu'));

      final state = await bloc.stream
          .firstWhere((s) => s is BillOperationSuccess) as BillOperationSuccess;
      expect(state.message, 'Đã đưa kỳ về chưa thanh toán',
          reason: 'Không được bắt đầu bằng "Xóa": trang Chi tiết đóng trang '
              'theo `startsWith(\'Xóa\')`.');
      expect((await db.billDao.getById('kieu-cu'))!.payStatus, 'Pending');
    });

    test('còn khoản chi gắn billId: chỉ sang Hoàn tác, không lỗi chung chung',
        () async {
      await kyDaTra('con-khoan');
      await db.walletDao.insert(WalletsCompanion.insert(
        id: 'w',
        idaccount: 1,
        name: 'Ví',
        updatedAt: DateTime.now(),
      ));
      await db.transactionDao.insert(TransactionsCompanion.insert(
        id: 'tx-con',
        idaccount: 1,
        walletId: 'w',
        amount: 100000,
        type: 'chi',
        billId: const Value('con-khoan'),
        date: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      bloc.add(DatLaiChuaTraEvent(billId: 'con-khoan'));

      final state =
          await bloc.stream.firstWhere((s) => s is BillError) as BillError;
      expect(
        state.message,
        'Kỳ này còn khoản chi của lần thanh toán. Mở lại trang rồi bấm Hoàn tác '
        'để trả tiền về ví.',
        reason: 'Hộp hỏi mở theo bản đồ của trang; bản đồ cũ hơn CSDL thì '
            'repository từ chối — câu phải chỉ đường, không in exception.',
      );
    });
  });
}
