import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/errors/app_exceptions.dart';
import 'package:flowmoney/features/wallet/data/datasources/wallet_local_data_source.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/domain/rang_buoc_vi.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ràng buộc của PostgreSQL trên `wallet`, thi hành ở tầng datasource —
/// nơi CẢ đường thêm lẫn đường sửa đều đi qua (cùng chỗ với chốt "một ví mặc
/// định"). Xem `rang_buoc_vi_test.dart` cho luật thuần; tệp này canh rằng
/// datasource THẬT SỰ gọi luật ấy trước khi ghi.
///
/// Không chặn ở đây thì ví vẫn ghi vào SQLite bình thường, rồi kẹt hàng đợi
/// đẩy vĩnh viễn ở lần đồng bộ kế tiếp — người dùng thấy ví trên máy này và
/// không bao giờ thấy nó ở máy khác.
void main() {
  late AppDatabase db;
  late WalletLocalDataSourceImpl dataSource;

  const idaccount = 7;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dataSource = WalletLocalDataSourceImpl(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  WalletEntity vi(String id, {required String name, String type = 'cash'}) =>
      WalletEntity(
        id: id,
        idaccount: idaccount,
        name: name,
        type: type,
        balance: 0,
        updatedAt: DateTime(2026, 9, 10),
      );

  group('trùng tên', () {
    test('thêm ví trùng tên bị từ chối, và KHÔNG ghi gì', () async {
      await dataSource.insert(vi('a', name: 'Tiền mặt'));

      await expectLater(
        dataSource.insert(vi('b', name: 'tiền mặt')),
        throwsA(isA<CacheException>().having(
            (e) => e.message, 'message', thongBaoTrungTen('tiền mặt'))),
      );
      expect((await db.walletDao.getAll(idaccount)).length, 1,
          reason: 'Chốt phải chạy TRƯỚC khi ghi. Ghi rồi mới ném là hàng đã '
              'nằm trong SQLite và vẫn bị đẩy lên.');
    });

    test('sửa ví sang tên của ví khác bị từ chối', () async {
      await dataSource.insert(vi('a', name: 'Tiền mặt'));
      await dataSource.insert(vi('b', name: 'VCB'));

      await expectLater(
        dataSource.update(vi('b', name: 'Tiền mặt')),
        throwsA(isA<CacheException>()),
      );
      expect((await db.walletDao.getById('b'))!.name, 'VCB');
    });

    test('sửa ví mà giữ nguyên tên thì được', () async {
      await dataSource.insert(vi('a', name: 'Tiền mặt'));

      await dataSource.update(vi('a', name: 'Tiền mặt').copyWith(balance: 5));

      expect((await db.walletDao.getById('a'))!.balance, 5,
          reason: 'Ví đang sửa phải được loại khỏi phép so, nếu không mọi '
              'lần Lưu ở màn Sửa ví đều bị từ chối.');
    });

    test('tên của ví đã xoá mềm dùng lại được', () async {
      await dataSource.insert(vi('a', name: 'Tiền mặt'));
      await db.walletDao.softDelete('a');

      await dataSource.insert(vi('b', name: 'Tiền mặt'));

      expect((await db.walletDao.getById('b'))!.name, 'Tiền mặt');
    });
  });

  group('nhiều ví Tiết kiệm — G30', () {
    // Server từng có `uq_wallet_saving_active` (một ví Tiết kiệm mỗi tài khoản),
    // luật chỉ tồn tại ở SQL. `database/12` đã bỏ index ấy (CSDL dev áp
    // 2026-09-11), nên chốt tạm phía client — từ chối ví Tiết kiệm thứ hai — nay
    // là từ chối thứ server cho phép.

    test('thêm ví saving thứ hai được', () async {
      await dataSource.insert(vi('a', name: 'Tiết kiệm', type: 'saving'));

      await dataSource.insert(vi('b', name: 'Quỹ dự phòng', type: 'saving'));

      final saving = (await db.walletDao.getAll(idaccount))
          .where((w) => w.type == 'saving')
          .map((w) => w.id)
          .toSet();
      expect(saving, {'a', 'b'},
          reason: 'App thị trường cho nhiều ví tiết kiệm, và server không còn '
              'chặn. Chặn ở đây là người dùng phải tạo quỹ thứ hai dưới loại '
              'Ngân hàng — sai nghĩa.');
    });

    test('đổi loại ví khác sang saving khi đã có một ví saving được', () async {
      await dataSource.insert(vi('a', name: 'Tiết kiệm', type: 'saving'));
      await dataSource.insert(vi('b', name: 'VCB', type: 'bank'));

      await dataSource.update(vi('b', name: 'VCB', type: 'saving'));

      expect((await db.walletDao.getById('b'))!.type, 'saving');
    });

    test('hai ví saving trùng tên vẫn bị từ chối', () async {
      await dataSource.insert(vi('a', name: 'Tiết kiệm', type: 'saving'));

      await expectLater(
        dataSource.insert(vi('b', name: 'tiết kiệm', type: 'saving')),
        throwsA(isA<CacheException>().having(
            (e) => e.message, 'message', thongBaoTrungTen('tiết kiệm'))),
        reason: 'Gỡ luật "một ví Tiết kiệm" KHÔNG được gỡ theo luật trùng tên — '
            '`uq_wallet_account_name_active` vẫn còn trên server.',
      );
      expect((await db.walletDao.getAll(idaccount)).length, 1);
    });
  });
}
