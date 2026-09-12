/// Ngày gốc của chuỗi hoá đơn (`Bills.anchorDay`, DB v18).
///
/// Chuỗi hoá đơn nối đuôi nhau — ngày bắt đầu kỳ sau là ngày kết thúc kỳ trước
/// (trước v21: ngày đến hạn) —
/// nên số ngày người dùng chọn ban đầu **biến mất** sau kỳ thứ hai. Nhìn vào
/// một mốc 28/02 đơn độc thì không biết nó từ 31/01 kẹp xuống hay do người dùng
/// tự chọn, mà hai thứ ấy phải cho ra hai kết quả khác nhau.
///
/// Bản trước đoán bằng "quy tắc ngày cuối tháng" và đoán sai với người đăng ký
/// lần đầu vào ngày cuối tháng Hai — lỗi người dùng báo 2026-09-08. Nay ngày
/// gốc được lưu và **chép sang từng kỳ**; quên chép là hoá đơn "ngày 31 hàng
/// tháng" tụt về 28 vĩnh viễn ngay sau tháng Hai đầu tiên, hoàn toàn im lặng.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/data/datasources/bill_local_datasource.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository_impl.dart';

void main() {
  late AppDatabase db;
  late BillRepositoryImpl repository;

  const accountId = 7;
  const walletId = 'wallet-1';
  const categoryId = 'cat-nha';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = BillRepositoryImpl(
      dataSource: BillLocalDataSource(db),
      db: db,
    );
    await db.walletDao.insert(WalletsCompanion.insert(
      id: walletId,
      idaccount: accountId,
      name: 'Ví chính',
      balance: const Value(100000000),
      updatedAt: DateTime(2026, 1, 1),
    ));
  });

  tearDown(() => db.close());

  Future<Bill> seed({
    required DateTime start,
    required DateTime due,
    int? anchorDay,
    String id = 'bill-goc',
  }) async {
    await db.billDao.insert(BillsCompanion.insert(
      id: id,
      idaccount: accountId,
      walletId: const Value(walletId),
      categoryId: const Value(categoryId),
      name: 'Tiền nhà',
      amount: 5000000,
      startDate: Value(start),
      dueDate: due,
      isRecurrence: const Value(true),
      timeRecurrence: const Value(kBillCycleMonth),
      recurrence: const Value('monthly'),
      anchorDay: Value(anchorDay),
      syncStatus: const Value('synced'),
      updatedAt: DateTime(2026, 1, 1),
    ));
    return (await db.billDao.getById(id))!;
  }

  /// Trả [soKy] kỳ liên tiếp, trả về ngày đến hạn của từng kỳ mới sinh ra.
  Future<List<DateTime>> traNhieuKy(Bill dau, int soKy) async {
    final ra = <DateTime>[];
    var hienTai = dau;
    for (var i = 0; i < soKy; i++) {
      await repository.payBill(
        bill: hienTai,
        walletId: walletId,
        idaccount: accountId,
        amount: hienTai.amount,
      );
      final ke = (await db.billDao.getAll(accountId))
          .firstWhere((b) => b.generatedFromBillId == hienTai.id);
      ra.add(ke.dueDate);
      hienTai = ke;
    }
    return ra;
  }

  test('chuỗi ngày 31 quay lại được ngày 31 sau tháng Hai', () async {
    final goc = await seed(
      start: DateTime(2025, 12, 31),
      due: DateTime(2026, 1, 31),
      anchorDay: 31,
    );

    expect(
      await traNhieuKy(goc, 4),
      [
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 30),
        DateTime(2026, 5, 31),
      ],
      reason: 'Tiền nhà "ngày 31 hàng tháng" phải quay lại 31 sau khi tháng Hai '
          'kẹp nó xuống 28. Không chép ngày gốc sang kỳ mới thì chuỗi đứng im '
          'ở 28 từ kỳ thứ hai — im lặng, không lỗi nào báo ra.',
    );
  });

  test('chuỗi ngày 28 KHÔNG bị kéo lên cuối tháng', () async {
    final goc = await seed(
      start: DateTime(2026, 1, 28),
      due: DateTime(2026, 2, 28),
      anchorDay: 28,
    );

    expect(
      await traNhieuKy(goc, 3),
      [
        DateTime(2026, 3, 28),
        DateTime(2026, 4, 28),
        DateTime(2026, 5, 28),
      ],
      reason: 'Người đăng ký lần đầu vào 28/02 muốn NGÀY 28. Bản trước cho ra '
          '31/03, 30/04, 31/05 vì đoán 28/02 nghĩa là "cuối tháng" — chính lỗi '
          'người dùng báo 2026-09-08.',
    );
  });

  test('hai chuỗi cùng đi qua 28/02 vẫn tách được nhau', () async {
    // Cùng một ngày đến hạn 28/02, khác nhau đúng ở ngày gốc.
    final goc31 = await seed(
      id: 'chuoi-31',
      start: DateTime(2026, 1, 31),
      due: DateTime(2026, 2, 28),
      anchorDay: 31,
    );
    final ky31 = (await traNhieuKy(goc31, 1)).single;

    final goc28 = await seed(
      id: 'chuoi-28',
      start: DateTime(2026, 1, 28),
      due: DateTime(2026, 2, 28),
      anchorDay: 28,
    );
    final ky28 = (await traNhieuKy(goc28, 1)).single;

    expect(
      [ky31, ky28],
      [DateTime(2026, 3, 31), DateTime(2026, 3, 28)],
      reason: 'Đây là cả lý do cột anchorDay tồn tại. Không có nó thì hai hoá '
          'đơn này không phân biệt được, và bất kỳ quy tắc nào cũng phải đoán '
          'sai một trong hai.',
    );
  });

  test('hoá đơn cũ chưa có ngày gốc thì neo vào ngày đến hạn hiện tại',
      () async {
    // Hàng kéo từ server, hoặc tạo trước v18 mà migration chưa chạm tới.
    final goc = await seed(
      start: DateTime(2026, 1, 31),
      due: DateTime(2026, 2, 28),
    );

    final ke = (await traNhieuKy(goc, 1)).single;
    expect(
      ke,
      DateTime(2026, 3, 28),
      reason: 'Không biết ý định gốc thì neo vào mốc hiện tại — giữ nguyên '
          'hành vi cũ thay vì đoán. Đoán sai ở đây là đổi ngày trả tiền nhà '
          'của người dùng mà không hỏi.',
    );

    final hang = (await db.billDao.getAll(accountId))
        .firstWhere((b) => b.generatedFromBillId == goc.id);
    expect(
      hang.anchorDay,
      28,
      reason: 'Kỳ mới phải được gán ngày gốc để chuỗi từ đây trở đi ổn định, '
          'thay vì mỗi kỳ lại suy lại một lần.',
    );
  });
}
