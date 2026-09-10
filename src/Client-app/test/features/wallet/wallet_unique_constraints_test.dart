import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/errors/app_exceptions.dart';
import 'package:flowmoney/features/wallet/data/datasources/wallet_local_data_source.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/domain/rang_buoc_vi.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hai ràng buộc của PostgreSQL trên `wallet`, thi hành ở tầng datasource —
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

  group('một ví Tiết kiệm', () {
    test('thêm ví saving thứ hai bị từ chối', () async {
      await dataSource.insert(vi('a', name: 'Tiết kiệm', type: 'saving'));

      await expectLater(
        dataSource.insert(vi('b', name: 'Quỹ dự phòng', type: 'saving')),
        throwsA(isA<CacheException>()
            .having((e) => e.message, 'message', thongBaoMotViTietKiem)),
      );
      expect((await db.walletDao.getAll(idaccount)).length, 1);
    });

    test('đổi loại ví khác sang saving khi đã có một ví saving bị từ chối',
        () async {
      await dataSource.insert(vi('a', name: 'Tiết kiệm', type: 'saving'));
      await dataSource.insert(vi('b', name: 'VCB', type: 'bank'));

      await expectLater(
        dataSource.update(vi('b', name: 'VCB', type: 'saving')),
        throwsA(isA<CacheException>()),
      );
      expect((await db.walletDao.getById('b'))!.type, 'bank');
    });

    test('sửa chính ví saving thì được', () async {
      await dataSource.insert(vi('a', name: 'Tiết kiệm', type: 'saving'));

      await dataSource.update(
          vi('a', name: 'Tiết kiệm dài hạn', type: 'saving'));

      expect((await db.walletDao.getById('a'))!.name, 'Tiết kiệm dài hạn');
    });

    test('ví saving đã xoá mềm không chặn ví saving mới', () async {
      await dataSource.insert(vi('a', name: 'Tiết kiệm', type: 'saving'));
      await db.walletDao.softDelete('a');

      await dataSource.insert(vi('b', name: 'Tiết kiệm mới', type: 'saving'));

      expect((await db.walletDao.getById('b'))!.type, 'saving');
    });

    test('ví của TÀI KHOẢN KHÁC không tính', () async {
      await db.walletDao.insert(WalletsCompanion.insert(
        id: 'x',
        idaccount: 99,
        name: 'Tiết kiệm',
        type: const Value('saving'),
        updatedAt: DateTime(2026, 9, 10),
      ));

      await dataSource.insert(vi('b', name: 'Tiết kiệm', type: 'saving'));

      expect((await db.walletDao.getById('b'))!.type, 'saving',
          reason: 'Cả hai index đều có `Idaccount` ở vế đầu; chặn chéo tài '
              'khoản là từ chối thứ server cho phép — và dữ liệu tài khoản '
              'khác trên cùng máy chỉ tồn tại tới lần dọn kế tiếp.');
    });
  });
}
