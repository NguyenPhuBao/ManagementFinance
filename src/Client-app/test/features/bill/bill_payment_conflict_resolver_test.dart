/// `BillPaymentConflictResolver` — gỡ khoản trả mà server đã từ chối.
///
/// Chốt `chanTraHaiLan` ở `upsertTransaction` (backend, CAN-LAM 20 §2.1) cho
/// máy nào đẩy trước thì thắng. Không có lớp này, máy thua giữ một khoản chi mà
/// server không có, ví bị trừ một lần không ai hoàn, và sổ hai máy lệch nhau
/// **im lặng**.
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_models.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository.dart';
import 'package:flowmoney/features/bill/data/services/bill_payment_conflict_resolver.dart';

/// Chỉ ghi lại lời gọi và ném thứ được dặn — đủ để đo hành vi của resolver mà
/// không phải dựng cả `BillRepositoryImpl`.
class _FakeBills implements BillRepository {
  final List<String> daGoiUndo = [];
  Object? nemRa;

  @override
  Future<void> undoPayment({required String billId}) async {
    daGoiUndo.add(billId);
    if (nemRa != null) throw nemRa!;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  const accountId = 7;
  const idVi = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const idBill = 'bill-1';
  const idKhoanChi = 'tx-1';

  late AppDatabase db;
  late _FakeBills bills;
  late BillPaymentConflictResolver resolver;
  late StreamController<SyncResult> pushResults;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    bills = _FakeBills();
    pushResults = StreamController<SyncResult>.broadcast();
    resolver = BillPaymentConflictResolver(db: db, bills: bills);
    resolver.batDauNghe(pushResults.stream);

    await db.walletDao.insert(WalletsCompanion.insert(
      id: idVi,
      idaccount: accountId,
      name: 'Tiền mặt',
      updatedAt: DateTime(2026, 9, 1),
    ));
    await db.billDao.insert(BillsCompanion.insert(
      id: idBill,
      idaccount: accountId,
      name: 'Tiền điện',
      amount: 350000,
      dueDate: DateTime(2026, 9, 20),
      syncStatus: const Value('pending'),
      updatedAt: DateTime(2026, 9, 20),
    ));
  });

  tearDown(() async {
    await resolver.dung();
    await pushResults.close();
    await db.close();
  });

  Future<void> themKhoanChi({String? billId = idBill}) =>
      db.transactionDao.insert(TransactionsCompanion.insert(
        id: idKhoanChi,
        walletId: idVi,
        idaccount: accountId,
        amount: 350000,
        type: 'chi',
        date: DateTime(2026, 9, 20),
        billId: Value(billId),
        syncStatus: const Value('pending'),
        updatedAt: DateTime(2026, 9, 20),
      ));

  SyncResult ketQuaVoi({
    required String? code,
    SyncEntityType entity = SyncEntityType.transaction,
    String localId = idKhoanChi,
  }) {
    return SyncResult(
      totalOps: 1,
      succeeded: 0,
      failed: 1,
      failures: [
        SyncOpFailure(
          localId: localId,
          entity: entity,
          message: 'Hoá đơn này đã có khoản chi',
          kind: SyncFailureKind.permanent,
          code: code,
        ),
      ],
    );
  }

  /// Đẩy một kết quả vào stream rồi nhường cho microtask của resolver chạy.
  Future<void> phat(SyncResult r) async {
    pushResults.add(r);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test('gọi undoPayment đúng MỘT lần cho khoản chi bị BILL_ALREADY_PAID',
      () async {
    await themKhoanChi();
    await phat(ketQuaVoi(code: 'BILL_ALREADY_PAID'));
    expect(bills.daGoiUndo, [idBill],
        reason: 'Đây là cả việc của lớp này: máy khác đã trả hoá đơn ấy, nên '
            'khoản trả của máy này phải được gỡ.');
  });

  test('BỎ QUA thất bại mang mã khác', () async {
    await themKhoanChi();
    await phat(ketQuaVoi(code: 'WALLET_NAME_DUPLICATE'));
    expect(bills.daGoiUndo, isEmpty,
        reason: 'Hoàn tác theo một mã không phải của mình là tự xoá tiền của '
            'người dùng vì một lỗi chẳng liên quan.');
  });

  test('BỎ QUA thất bại không có mã', () async {
    await themKhoanChi();
    await phat(ketQuaVoi(code: null));
    expect(bills.daGoiUndo, isEmpty);
  });

  test('BỎ QUA thất bại của entity khác transaction', () async {
    await themKhoanChi();
    await phat(ketQuaVoi(
      code: 'BILL_ALREADY_PAID',
      entity: SyncEntityType.bill,
      localId: idBill,
    ));
    expect(bills.daGoiUndo, isEmpty,
        reason: 'Mã này chỉ có nghĩa cho thao tác đẩy KHOẢN CHI; đọc nó ở một '
            'entity khác là hiểu sai hợp đồng.');
  });

  test('sau hoàn tác, KHOẢN CHI được markSynced', () async {
    await themKhoanChi();
    await phat(ketQuaVoi(code: 'BILL_ALREADY_PAID'));
    final tx = await db.transactionDao.getById(idKhoanChi);
    expect(tx!.syncStatus, 'synced',
        reason: '`undoPayment` xoá MỀM khoản chi, nên nó quay lại hàng đợi với '
            'cờ xoá — trong khi server CHƯA BAO GIỜ có nó (chính nó vừa bị từ '
            'chối). Xoá một bản ghi không tồn tại là vòng lặp `Record not '
            'found` ở mọi chu kỳ, đúng cái đã vấp 2026-09-04.');
  });

  test('sau hoàn tác, HOÁ ĐƠN được markSynced', () async {
    await themKhoanChi();
    await phat(ketQuaVoi(code: 'BILL_ALREADY_PAID'));
    final b = await db.billDao.getById(idBill);
    expect(b!.syncStatus, 'synced',
        reason: '`undoPayment` kéo hoá đơn về chưa trả với `updatedAt` mới hơn '
            'bản `Payed` mà máy thắng vừa ghi. Đẩy lên là LWW cho MÁY THUA '
            'thắng — nó xoá đúng kết quả vừa được server chấp nhận. Trạng thái '
            'thật phải đến từ nhánh kéo về.');
  });

  test('BillNotPaidException không làm vỡ chu kỳ, và hai bản ghi vẫn thoát '
      'hàng đợi', () async {
    await themKhoanChi();
    bills.nemRa = const BillNotPaidException(idBill);
    await phat(ketQuaVoi(code: 'BILL_ALREADY_PAID'));
    expect((await db.transactionDao.getById(idKhoanChi))!.syncStatus, 'synced');
    expect((await db.billDao.getById(idBill))!.syncStatus, 'synced',
        reason: 'Ngoại lệ ở đây nghĩa là "không còn gì để gỡ" — một chu kỳ pull '
            'trước đã kéo hoá đơn về chưa trả. Không phải lỗi, và không được '
            'để hai bản ghi kẹt lại hàng đợi.');
  });

  test('BillUndoUnavailableException cũng vậy', () async {
    await themKhoanChi();
    bills.nemRa = const BillUndoUnavailableException(idBill);
    await phat(ketQuaVoi(code: 'BILL_ALREADY_PAID'));
    expect((await db.transactionDao.getById(idKhoanChi))!.syncStatus, 'synced');
    expect((await db.billDao.getById(idBill))!.syncStatus, 'synced');
  });

  test('khoản chi không mang billId (bản app cũ) thì không gọi undoPayment, '
      'nhưng vẫn thoát hàng đợi', () async {
    await themKhoanChi(billId: null);
    await phat(ketQuaVoi(code: 'BILL_ALREADY_PAID'));
    expect(bills.daGoiUndo, isEmpty,
        reason: 'Không lần ngược được về hoá đơn thì không đoán — đúng cách '
            '`undoPayment` từ chối thay vì suy từ ghi chú.');
    expect((await db.transactionDao.getById(idKhoanChi))!.syncStatus, 'synced',
        reason: 'Vẫn phải thoát hàng đợi, nếu không nó bị đẩy lại mãi và lần '
            'nào cũng bị từ chối y như vậy.');
  });

  group('thông báo', () {
    Future<List<AppNotification>> doc() =>
        db.notificationDao.getAll(accountId);

    test('hoàn tác xong thì sinh MỘT thông báo nhóm bill', () async {
      await themKhoanChi();
      await phat(ketQuaVoi(code: 'BILL_ALREADY_PAID'));

      final ds = await doc();
      expect(ds, hasLength(1),
          reason: 'Việc này xảy ra lúc đồng bộ nền, có thể khi app đóng, nên '
              'toast sẽ trôi mất — mà số dư ví thì vừa đổi hai lần.');
      expect(ds.single.kind, 'billPaidOnOtherDevice');
      expect(ds.single.subjectType, 'bill');
      expect(ds.single.subjectId, idBill);
    });

    test('thông báo KHÔNG nêu số tiền', () async {
      await themKhoanChi();
      await phat(ketQuaVoi(code: 'BILL_ALREADY_PAID'));

      final n = (await doc()).single;
      expect('${n.title} ${n.body}', isNot(contains('350')),
          reason: 'Nếp thông báo tối giản của dự án: không nêu số liệu. Số tiền '
              'còn nằm ở khoản chi và ở ví, người dùng mở ra xem được.');
    });

    test('hai lần hoàn tác cùng một hoá đơn chỉ sinh MỘT thông báo', () async {
      await themKhoanChi();
      await phat(ketQuaVoi(code: 'BILL_ALREADY_PAID'));
      await phat(ketQuaVoi(code: 'BILL_ALREADY_PAID'));

      expect(await doc(), hasLength(1),
          reason: 'Một chu kỳ đồng bộ hỏng rồi thử lại là hai lượt phát cùng '
              'một thất bại; `dedupeKey` phải nuốt lượt sau.');
    });

    test('KHÔNG sinh thông báo khi không có gì để gỡ', () async {
      await themKhoanChi();
      bills.nemRa = const BillNotPaidException(idBill);
      await phat(ketQuaVoi(code: 'BILL_ALREADY_PAID'));

      expect(await doc(), isEmpty,
          reason: 'Hoá đơn vốn đã ở trạng thái chưa trả — không có gì đổi trên '
              'máy này, nên báo là làm phiền vô cớ.');
    });

    test('KHÔNG sinh thông báo cho thất bại mang mã khác', () async {
      await themKhoanChi();
      await phat(ketQuaVoi(code: 'WALLET_NAME_DUPLICATE'));
      expect(await doc(), isEmpty);
    });
  });
}
