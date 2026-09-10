import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/errors/app_exceptions.dart';
import 'package:flowmoney/features/wallet/data/datasources/wallet_local_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lưu trữ ví ở tầng datasource — **hai chốt chặn** và đường mang `status`.
///
/// Chốt chặn ở đây cố ý **khác hẳn** ba ràng buộc của `softDelete` (còn số dư
/// / đã có giao dịch / đang gắn mục tiêu). Lưu trữ sinh ra chính là **lối
/// thoát** cho ba ràng buộc ấy: ví dùng thật gần như không bao giờ xoá được,
/// nên nếu lưu trữ cũng đòi số dư 0 và không giao dịch thì nó vô dụng.
///
/// Hai chốt còn lại là chốt về *tính dùng được của app*, không phải về dữ liệu:
///
/// 1. **Ví mặc định** — nó được chọn sẵn mỗi lần ghi giao dịch
///    (`vi_chon_san.dart`). Lưu trữ nó là màn thêm giao dịch mở ra với một ví
///    không còn nằm trong danh sách chọn.
/// 2. **Ví hoạt động cuối cùng** — lưu trữ hết thì không ghi được giao dịch
///    nào nữa, và không màn nào nói vì sao.
///
/// Hai chốt độc lập nhau: một tài khoản có thể không có ví nào mang cờ mặc
/// định (trạng thái ấy đến được từ server), nên chốt 1 không bao hàm chốt 2.
///
/// Ví đang gắn mục tiêu hoặc hoá đơn tự động thì **vẫn cho lưu trữ** — cảnh
/// báo là việc của hộp thoại xác nhận, không phải của chốt chặn.
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

  Future<void> them(
    String id, {
    bool isDefault = false,
    String? status,
    double balance = 0,
  }) async {
    await db.walletDao.insert(WalletsCompanion.insert(
      id: id,
      idaccount: idaccount,
      name: 'Ví $id',
      isDefault: Value(isDefault),
      balance: Value(balance),
      status: status == null ? const Value.absent() : Value(status),
      updatedAt: DateTime(2026, 9, 10),
    ));
  }

  group('mang trạng thái ra khỏi tầng Drift', () {
    test('entity đọc được status của hàng', () async {
      await them('a');
      await them('b', status: 'inactive');

      final vi = await dataSource.getAll(idaccount);
      expect(vi.firstWhere((w) => w.id == 'a').status, 'active');
      expect(vi.firstWhere((w) => w.id == 'b').status, 'inactive',
          reason: 'WalletEntity không mang cột này thì trạng thái chết ngay ở '
              'ranh giới Drift → domain, và không đường nào lên tới giao diện '
              'lẫn hợp đồng đồng bộ.');
    });

    test('ghi entity mang trạng thái mới thì CSDL đổi theo', () async {
      await them('b');

      final vi = (await dataSource.getAll(idaccount)).single;
      await dataSource.update(vi.copyWith(status: 'inactive'));

      expect((await db.walletDao.getById('b'))!.status, 'inactive',
          reason: 'Đây là đường mà công tắc "Kích hoạt hoạt động" ở màn Sửa ví '
              'đi qua. Companion thiếu cột `status` thì `update_` không ghi cột '
              'ấy, công tắc bấm xong không làm gì cả — im lặng, đúng như công '
              'tắc chết đã gỡ ở `095c95f`.');
      // ⚠️ Ca này cố ý đi theo chiều active → inactive. Chiều ngược lại KHÔNG
      // phân biệt được hai cách cài đặt: `update_` chỉ ghi những cột companion
      // có mang, nên cột vắng mặt được giữ nguyên và một bản thiếu hẳn dòng
      // `status` vẫn xanh. Một bản sai có chủ ý đã chứng minh điều đó.
    });

    test('getActive của datasource bỏ ví lưu trữ', () async {
      await them('a');
      await them('b', status: 'inactive');

      expect((await dataSource.getActive(idaccount)).map((w) => w.id), ['a']);
      expect((await dataSource.getAll(idaccount)).map((w) => w.id),
          ['a', 'b']);
    });
  });

  group('chốt chặn khi lưu trữ', () {
    test('KHÔNG cho lưu trữ ví mặc định', () async {
      await them('mac_dinh', isDefault: true);
      await them('khac');

      await expectLater(
        () => dataSource.setArchived('mac_dinh', luuTru: true),
        throwsA(isA<CacheException>()),
        reason: 'Ví mặc định được chọn sẵn mỗi lần ghi giao dịch. Lưu trữ nó là '
            'màn thêm giao dịch mở ra với một ví không còn trong danh sách.',
      );
      expect((await db.walletDao.getById('mac_dinh'))!.status, 'active');
    });

    test('KHÔNG cho lưu trữ ví hoạt động cuối cùng', () async {
      // Cố ý không ví nào mang cờ mặc định: trạng thái ấy đến được từ server,
      // và nó là ca phân biệt chốt 2 với chốt 1.
      await them('duy_nhat');

      await expectLater(
        () => dataSource.setArchived('duy_nhat', luuTru: true),
        throwsA(isA<CacheException>()),
        reason: 'Lưu trữ hết ví thì không ghi được giao dịch nào nữa, và không '
            'màn nào nói vì sao.',
      );
      expect((await db.walletDao.getById('duy_nhat'))!.status, 'active');
    });

    test('ví lưu trữ sẵn KHÔNG được tính là ví hoạt động còn lại', () async {
      await them('con_lai');
      await them('da_luu_tru', status: 'inactive');

      await expectLater(
        () => dataSource.setArchived('con_lai', luuTru: true),
        throwsA(isA<CacheException>()),
        reason: 'Đếm cả ví đã lưu trữ là chốt chặn đếm nhầm và cho lưu trữ nốt '
            'ví cuối — đúng thứ nó sinh ra để ngăn.',
      );
    });

    test('CHO lưu trữ ví còn số dư và đã có giao dịch', () async {
      await them('mac_dinh', isDefault: true);
      await them('cu', balance: 250000);
      await db.transactionDao.insert(TransactionsCompanion.insert(
        id: 't1',
        idaccount: idaccount,
        walletId: 'cu',
        amount: 250000,
        type: 'thu',
        date: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
      ));

      await dataSource.setArchived('cu', luuTru: true);

      expect((await db.walletDao.getById('cu'))!.status, 'inactive',
          reason: 'Lưu trữ là LỐI THOÁT cho ba ràng buộc của xoá ví. Bắt ví có '
              'số dư 0 và không giao dịch là làm nó vô dụng đúng với những ví '
              'người dùng thật sự muốn cất đi.');
      expect((await db.walletDao.getById('cu'))!.balance, 250000,
          reason: 'Đóng băng, không phải xoá: số dư giữ nguyên để bỏ lưu trữ là '
              'mọi con số cũ quay lại.');
    });

    test('bỏ lưu trữ KHÔNG bị chốt chặn nào cản', () async {
      await them('mac_dinh', isDefault: true);
      await them('cu', status: 'inactive');

      await dataSource.setArchived('cu', luuTru: false);

      expect((await db.walletDao.getById('cu'))!.status, 'active');
    });

    test('bỏ lưu trữ ví mặc định vẫn chạy', () async {
      // Trạng thái này đến được từ server: máy khác đặt cờ mặc định cho một ví
      // mà máy này đã lưu trữ. Chốt chặn chỉ canh chiều LƯU TRỮ.
      await them('vua_thanh_mac_dinh', isDefault: true, status: 'inactive');

      await dataSource.setArchived('vua_thanh_mac_dinh', luuTru: false);

      expect((await db.walletDao.getById('vua_thanh_mac_dinh'))!.status,
          'active');
    });
  });
}
