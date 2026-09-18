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

  // ── Chốt đối xứng: chiều NGƯỢC LẠI của "không lưu trữ ví mặc định" ────────
  //
  // Nhóm trên chặn *lưu trữ một ví đang mặc định*. Tới 2026-09-18 chiều kia
  // vẫn bỏ ngỏ: **đặt một ví đã lưu trữ làm mặc định**. Kết quả giống hệt nhau
  // — cờ mặc định trỏ vào một ví không nằm trong bộ chọn nào — nhưng đường đi
  // khác nên chốt cũ không bắt được.
  //
  // Hỏng **im lặng**: `chonViChonSan` tìm ví mặc định trong danh sách đã lọc
  // (`getActive`), không thấy thì lặng lẽ rơi về ví đầu. Không lỗi, không
  // cảnh báo — người dùng chỉ thấy cờ mình vừa bật chẳng làm gì cả.
  group('chốt chặn khi đặt ví mặc định', () {
    test('KHÔNG cho đặt ví ĐANG LƯU TRỮ làm ví mặc định', () async {
      await them('luu_tru', status: 'inactive');
      await them('dang_dung');

      final vi = (await dataSource.getById('luu_tru'))!;

      await expectLater(
        () => dataSource.update(vi.copyWith(isDefault: true)),
        throwsA(isA<CacheException>().having(
          (e) => e.message,
          'message',
          contains('lưu trữ'),
        )),
        reason: 'Cờ mặc định chỉ có MỘT tác dụng: chọn sẵn ví khi ghi giao '
            'dịch. Ví lưu trữ không nằm trong bộ chọn, nên đặt cờ cho nó là '
            'bật một công tắc không nối vào đâu.',
      );
      expect((await db.walletDao.getById('luu_tru'))!.isDefault, isFalse);
    });

    test('vẫn cho đặt mặc định cho ví đang hoạt động', () async {
      await them('dang_dung');
      final vi = (await dataSource.getById('dang_dung'))!;

      await dataSource.update(vi.copyWith(isDefault: true));

      expect((await db.walletDao.getById('dang_dung'))!.isDefault, isTrue);
    });

    test('nhánh kéo về KHÔNG bị chốt này cản', () async {
      // Máy khác đặt cờ mặc định cho một ví mà máy này đã lưu trữ. Đường pull
      // ghi thẳng qua DAO, không qua datasource — chốt trên chỉ canh đường
      // người dùng chủ động bật. Chặn cả chiều này là ví kẹt hàng đợi kéo về.
      await them('tu_server', isDefault: true, status: 'inactive');

      final row = await db.walletDao.getById('tu_server');
      expect(row!.isDefault, isTrue);
      expect(row.status, 'inactive');
    });
  });

  group('G27 — cờ "cho phép âm" đi qua đường ghi của datasource', () {
    test('⚠️ GẠT được cờ qua đường update — cả bật lẫn tắt', () async {
      // ⚠️ Triệu chứng thật của việc quên cột trong `_toCompanion` **không**
      // phải "cờ tự tắt": `update_` gọi `write(companion)`, mà companion thiếu
      // cột thì Drift **không ghi** cột ấy — giá trị cũ ở lại. Nên bug là cờ
      // **không đổi được**: người dùng gạt công tắc, bấm Lưu, màn hình báo
      // thành công, và cờ đứng nguyên.
      //
      // Bản đầu của ca này khẳng định điều ngược lại (sửa tên thì cờ tự tắt) và
      // vì thế **xanh với cả bản sai** — bản sai có chủ ý bắt được, đúng bài
      // học "ca test phải đòi KẾT QUẢ".
      //
      // ⚠️ Chú thích của `status` ngay cạnh trong `_toCompanion` mang đúng nhận
      // định sai ấy (*"sửa tên ví là ví tự bỏ lưu trữ"*). Chưa sửa vì nó thuộc
      // hạng mục khác; ghi lại đây để người sau không chép lại.
      await db.walletDao.insert(WalletsCompanion.insert(
        id: 'w-the',
        idaccount: 1,
        name: 'Thẻ tín dụng',
        allowNegative: const Value(true),
        updatedAt: DateTime(2026, 9, 17),
      ));

      final truoc = await dataSource.getById('w-the');
      expect(truoc!.allowNegative, isTrue);

      // TẮT cờ, kèm đổi tên để chắc rằng lượt ghi đi đúng đường thường.
      await dataSource
          .update(truoc.copyWith(name: 'Thẻ VISA', allowNegative: false));
      final sauKhiTat = await dataSource.getById('w-the');
      expect(sauKhiTat!.name, 'Thẻ VISA');
      expect(sauKhiTat.allowNegative, isFalse,
          reason: 'Thiếu cột trong `_toCompanion` thì Drift bỏ qua nó và cờ '
              'đứng nguyên — công tắc trông như hỏng, không một lỗi nào báo.');

      // BẬT lại, để ca này canh cả hai chiều.
      await dataSource.update(sauKhiTat.copyWith(allowNegative: true));
      expect((await dataSource.getById('w-the'))!.allowNegative, isTrue);
    });

    test('cờ mặc định TẮT với ví tạo bình thường', () async {
      await db.walletDao.insert(WalletsCompanion.insert(
        id: 'w-thuong',
        idaccount: 1,
        name: 'Tiền mặt',
        updatedAt: DateTime(2026, 9, 17),
      ));

      final vi = await dataSource.getById('w-thuong');
      expect(vi!.allowNegative, isFalse,
          reason: 'Mặc định `false` chính là hành vi trước bản này — mọi ví '
              'đang nằm trên máy người dùng phải giữ nguyên cách hành xử.');
    });
  });
}
