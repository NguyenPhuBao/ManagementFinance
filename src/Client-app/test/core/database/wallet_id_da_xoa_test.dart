import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

/// `WalletDao.idDaXoa` — nguồn của G71 (2026-10-06): bộ quét gỡ thông báo số dư
/// của ví đã xoá. Phải trả ĐÚNG ví đã xoá mềm của ĐÚNG tài khoản: thiếu là
/// thông báo treo, thừa (ví đang dùng, ví lưu trữ, ví tài khoản khác) là gỡ
/// nhầm một cảnh báo còn đúng.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> them(String id, {int idaccount = 7, String? status}) =>
      db.walletDao.insert(WalletsCompanion.insert(
        id: id,
        idaccount: idaccount,
        name: id,
        status: status == null ? const Value.absent() : Value(status),
        updatedAt: DateTime(2026, 10, 6),
      ));

  test('chỉ ví đã xoá mềm của đúng tài khoản', () async {
    await them('dang-dung');
    await them('luu-tru', status: 'inactive');
    await them('da-xoa');
    await them('khac-tk', idaccount: 8);
    await db.walletDao.softDelete('da-xoa');
    await db.walletDao.softDelete('khac-tk');

    expect(await db.walletDao.idDaXoa(7), {'da-xoa'},
        reason: 'ví lưu trữ là đóng băng, không phải xoá — cảnh báo của nó vẫn có thể đúng');
  });

  test('hàng kéo về chỉ mang cờ isDeleted (deletedAt trống) vẫn tính là đã xoá', () async {
    await them('cu');
    await (db.update(db.wallets)..where((t) => t.id.equals('cu')))
        .write(const WalletsCompanion(isDeleted: Value(true)));
    expect(await db.walletDao.idDaXoa(7), {'cu'});
  });
}
