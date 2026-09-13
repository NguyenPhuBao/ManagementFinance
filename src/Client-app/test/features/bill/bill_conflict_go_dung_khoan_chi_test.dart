/// Resolver phải gỡ **đúng khoản chi bị server từ chối**, không phải một khoản
/// chi nào đó của cùng hoá đơn.
///
/// Vì sao cần bộ test riêng, dựng `BillRepositoryImpl` THẬT: ca này đo *hàng
/// nào trong SQLite bị xoá mềm*, mà `_FakeBills` của
/// `bill_payment_conflict_resolver_test.dart` chỉ ghi lại `billId` được truyền
/// vào — nó không thể thấy lỗi này.
///
/// **Đã vấp thật trên hai máy ảo ngày 2026-09-13.** Trên máy thua, tới lúc
/// resolver chạy, SQLite chứa **hai** khoản chi sống mang cùng `billId`: của
/// chính nó (vừa bị từ chối) và của máy thắng (vừa pull về — `transactions.
/// billId` đi qua đồng bộ từ 2026-09-12). `undoPayment` không nhận khoản chi
/// cần gỡ mà tự tìm bằng `TransactionDao.getByBill`, thứ là `LIMIT 1` **không
/// `ORDER BY`** — phép chọn không xác định. Nó gỡ nhầm khoản của máy thắng, rồi
/// cờ xoá ấy được đẩy lên server.
///
/// Đo trên PostgreSQL sau lượt ấy (tài khoản 17): hoá đơn
/// `d2332790-e781-40a0-b18f-1868681e527d` còn `Payed`, nhưng khoản chi **duy
/// nhất** của nó — `f2963fff-1e03-47c8-8528-c194f9b89cb8`, tức khoản đã lên
/// được server, tức khoản của máy **thắng** — mang `Deleted_at`. Sổ hai máy
/// lệch nhau mà không lỗi nào báo ra.
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_models.dart';
import 'package:flowmoney/features/bill/data/datasources/bill_local_datasource.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository_impl.dart';
import 'package:flowmoney/features/bill/data/services/bill_payment_conflict_resolver.dart';

void main() {
  const accountId = 7;
  const idBill = 'bill-1';
  const idViNay = 'wallet-may-nay';
  const idViKia = 'wallet-may-kia';

  /// Khoản chi của **máy này** — chính nó vừa bị server từ chối.
  const idKhoanBiTuChoi = 'tx-may-nay';

  /// Khoản chi của **máy thắng**, kéo về ở một chu kỳ pull trước. Hàng này đã
  /// được server chấp nhận, nên nó là sự thật — đụng vào là sai.
  const idKhoanCuaMayThang = 'tx-may-thang';

  const soTien = 350000.0;
  const soDuSauKhiTra = 650000.0;

  late AppDatabase db;
  late BillRepositoryImpl repository;
  late BillPaymentConflictResolver resolver;
  late StreamController<SyncResult> pushResults;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = BillRepositoryImpl(
      dataSource: BillLocalDataSource(db),
      db: db,
    );
    pushResults = StreamController<SyncResult>.broadcast();
    resolver = BillPaymentConflictResolver(db: db, bills: repository);
    resolver.batDauNghe(pushResults.stream);

    for (final v in [idViNay, idViKia]) {
      await db.walletDao.insert(WalletsCompanion.insert(
        id: v,
        idaccount: accountId,
        name: 'Ví $v',
        // Số dư đã bị trừ một lần, bởi chính lần trả vừa bị từ chối.
        balance: const Value(soDuSauKhiTra),
        updatedAt: DateTime(2026, 9, 1),
      ));
    }

    // Hoá đơn đang ở trạng thái ĐÃ TRẢ: máy này vừa tự trả nó xong.
    await db.billDao.insert(BillsCompanion.insert(
      id: idBill,
      idaccount: accountId,
      name: 'Tiền điện',
      amount: soTien,
      dueDate: DateTime(2026, 9, 20),
      isPaid: const Value(true),
      payStatus: const Value('Payed'),
      syncStatus: const Value('pending'),
      updatedAt: DateTime(2026, 9, 20),
    ));
  });

  tearDown(() async {
    await resolver.dung();
    await pushResults.close();
    await db.close();
  });

  Future<void> themKhoanChi(String id, {String viId = idViNay}) =>
      db.transactionDao.insert(TransactionsCompanion.insert(
        id: id,
        walletId: viId,
        idaccount: accountId,
        amount: soTien,
        type: 'chi',
        date: DateTime(2026, 9, 20),
        billId: const Value(idBill),
        syncStatus: const Value('pending'),
        updatedAt: DateTime(2026, 9, 20),
      ));

  Future<void> phatTuChoi() async {
    pushResults.add(const SyncResult(
      totalOps: 1,
      succeeded: 0,
      failed: 1,
      failures: [
        SyncOpFailure(
          localId: idKhoanBiTuChoi,
          entity: SyncEntityType.transaction,
          message: 'Hoá đơn này đã có khoản chi',
          kind: SyncFailureKind.permanent,
          code: 'BILL_ALREADY_PAID',
        ),
      ],
    ));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  Future<bool> conSong(String id) async =>
      (await db.transactionDao.getById(id))!.deletedAt == null;

  test('gỡ ĐÚNG khoản bị từ chối, dù khoản của máy thắng được chèn trước',
      () async {
    // Thứ tự này là ca đã vấp thật: một chu kỳ pull mang khoản của máy thắng về
    // trước khi resolver kịp chạy.
    await themKhoanChi(idKhoanCuaMayThang);
    await themKhoanChi(idKhoanBiTuChoi);

    await phatTuChoi();

    expect(await conSong(idKhoanCuaMayThang), isTrue,
        reason: 'Khoản của máy thắng ĐÃ được server chấp nhận — nó là sự thật. '
            'Gỡ nó là đẩy cờ xoá lên server và xoá đúng bản ghi hợp lệ: hoá đơn '
            'còn `Payed` mà không còn khoản chi nào, sổ hai máy lệch nhau im '
            'lặng. Đo được trên PostgreSQL ngày 2026-09-13 (tài khoản 17, hoá '
            'đơn d2332790).');
    expect(await conSong(idKhoanBiTuChoi), isFalse,
        reason: 'Khoản bị từ chối CHƯA BAO GIỜ lên được server, nên nó mới là '
            'khoản thừa phải gỡ. Để nó lại là ví bị trừ một lần không ai hoàn.');
  });

  test('gỡ ĐÚNG khoản bị từ chối, dù khoản của máy thắng được chèn sau',
      () async {
    // Ca đối chứng: bug gốc là một phép chọn KHÔNG XÁC ĐỊNH (`LIMIT 1` không
    // `ORDER BY`), nên hành vi phải đúng bất kể thứ tự hàng trong bảng. Ca này
    // có thể đã xanh sẵn trước khi sửa — nó ở đây để khoá lại, không phải để
    // chứng minh lỗi.
    await themKhoanChi(idKhoanBiTuChoi);
    await themKhoanChi(idKhoanCuaMayThang);

    await phatTuChoi();

    expect(await conSong(idKhoanCuaMayThang), isTrue);
    expect(await conSong(idKhoanBiTuChoi), isFalse);
  });

  test('phát lại cùng một thất bại KHÔNG hoàn tiền lần thứ hai', () async {
    await themKhoanChi(idKhoanCuaMayThang);
    await themKhoanChi(idKhoanBiTuChoi);

    // Một chu kỳ đồng bộ hỏng rồi thử lại là hai lượt phát cùng một thất bại.
    await phatTuChoi();
    await phatTuChoi();

    expect((await db.walletDao.getById(idViNay))!.balance, 1000000.0,
        reason: 'Chỉ được hoàn ĐÚNG MỘT LẦN. Lớp chắn hôm nay là '
            '`TransactionDao.getByBill` lọc `deletedAt.isNull()`: khoản đã gỡ '
            'thì không tìm thấy nữa, `undoPayment` ném và không ai cộng tiền '
            'thêm. ⚠️ Bản sửa "gỡ đúng khoản mang localId" dễ đánh mất lớp chắn '
            'ấy, vì `TransactionDao.getById` CỐ Ý đọc cả hàng đã xoá mềm — tra '
            'thẳng bằng nó rồi hoàn tiền là TẶNG TIỀN cho ví mỗi lượt phát lại.');
  });

  /// Kéo hoá đơn về `Pending` — đúng những gì một chu kỳ **pull** làm khi
  /// server còn giữ trạng thái ấy.
  Future<void> pullKeoVePending() =>
      db.billDao.updateFields(const BillsCompanion(
        id: Value(idBill),
        isPaid: Value(false),
        payStatus: Value('Pending'),
      ));

  test('vẫn gỡ và hoàn tiền khi chu kỳ pull đã kéo hoá đơn về Pending',
      () async {
    await themKhoanChi(idKhoanCuaMayThang);
    await themKhoanChi(idKhoanBiTuChoi);
    await pullKeoVePending();

    await phatTuChoi();

    expect(await conSong(idKhoanBiTuChoi), isFalse,
        reason: 'ĐÃ VẤP THẬT trên hai máy ảo ngày 2026-09-13: trong CÙNG một '
            'chu kỳ, push bị từ chối rồi pull kéo hoá đơn về `Pending` TRƯỚC '
            'khi resolver kịp chạy. `undoPayment` thấy hoá đơn chưa trả nên ném '
            '`BillNotPaidException` và không gỡ gì — khoản chi thừa ở lại, ví '
            'không được hoàn. Đo được: máy B giữ ví 2.000.000 mà sổ có hai '
            'khoản chi 350.000, lệch 700.000 và im lặng.\n'
            'Chốt `daCoKhoanChi` chỉ để bảo vệ NÚT BẤM TAY, nơi hàm phải tự tìm '
            'khoản chi. Khi nơi gọi đã truyền đích danh `transactionId` thì nó '
            'biết chắc chắn hơn hoá đơn.');
    expect((await db.walletDao.getById(idViNay))!.balance, 1000000.0,
        reason: 'Tiền phải quay về ví, dù hoá đơn đang mang trạng thái nào.');
    expect(await conSong(idKhoanCuaMayThang), isTrue);
  });

  test('hoá đơn Ở LẠI hàng đợi đẩy, để "đã trả" tới được server', () async {
    await themKhoanChi(idKhoanCuaMayThang);
    await themKhoanChi(idKhoanBiTuChoi);
    await pullKeoVePending();

    await phatTuChoi();

    final b = (await db.billDao.getById(idBill))!;
    expect(b.payStatus, 'Payed');
    expect(b.syncStatus, 'pending',
        reason: 'Spec §4.3b từng cho hoá đơn `markSynced` với lý lẽ "trạng thái '
            'thật sẽ đến từ nhánh kéo về ở chu kỳ sau". ĐO THẬT ngày 2026-09-13 '
            'cho thấy giả định ấy SAI: bản `Payed` của máy thắng cũng bị LWW '
            'đánh bại — mỗi máy bị pull ghi đè rồi đẩy bản cũ hơn lên — nên '
            'server giữ `Pending` vĩnh viễn (đo: bill d0f455fe, '
            'Update_at 11:21:18.938). Không máy nào dạy được server sự thật, và '
            'bộ tự trả cứ thế trả lại sau mỗi lần pull.\n'
            'Lý lẽ cũ dựa trên việc máy thua đẩy `Pending` lên — nhưng từ bản '
            'sửa lỗi 1, máy thua giữ `Payed`, tức ĐÚNG sự thật. Đẩy nó lên là '
            'hội tụ, không phải giẫm đạp.');
  });

  test('hoàn tiền vào ĐÚNG ví của khoản bị từ chối', () async {
    // Hai máy trả cùng một hoá đơn bằng hai ví khác nhau — chuyện thường, vì ví
    // mặc định của mỗi máy do người dùng chọn riêng.
    await themKhoanChi(idKhoanCuaMayThang, viId: idViKia);
    await themKhoanChi(idKhoanBiTuChoi, viId: idViNay);

    await phatTuChoi();

    expect((await db.walletDao.getById(idViNay))!.balance, 1000000.0,
        reason: 'Ví bị trừ là ví của khoản vừa bị từ chối, nên tiền phải quay '
            'về đúng ví ấy.');
    expect((await db.walletDao.getById(idViKia))!.balance, soDuSauKhiTra,
        reason: 'Ví của máy thắng không được cộng thêm gì: khoản chi của nó vẫn '
            'đứng, tiền ấy đã tiêu thật. Cộng vào đây là TẶNG TIỀN cho một ví '
            'chưa hề bị trừ trên máy này.');
  });
}
