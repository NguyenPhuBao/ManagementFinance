/// G113 nợ 1, 9 (spec gia đình mục 12.7; `docs/Family/02A` mục 1, 7.1): neo của ví nhà mang `idhousehold`, chỉ máy tạo ví đặt
/// neo, và số dư ví nhà là cache cục bộ: mọi máy tính cùng số từ sổ, không đẩy.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/wallet/data/so_du_vi_service.dart';
import 'package:flowmoney/features/wallet/domain/so_du_mo_so.dart';
import 'package:flutter_test/flutter_test.dart';

const _toi = 10;
const _nguoiKhac = 11;
const _nha = 5;

void main() {
  late AppDatabase db;
  final ngay = DateTime(2026, 10, 20);

  Future<void> vi(String id, int acc, {int? nha, double soDu = 500000}) => db.walletDao.insert(WalletsCompanion(
      id: Value(id),
      idaccount: Value(acc),
      name: Value(id),
      balance: Value(soDu),
      idhousehold: Value(nha),
      syncStatus: const Value('synced'),
      updatedAt: Value(ngay)));

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('nợ 1: neo', () {
    test('ví nhà TÔI tạo: neo mang idhousehold của ví', () async {
      await vi('v', _toi, nha: _nha);
      await SoDuViService(db: db, taiKhoanPhien: () => _toi).datNeoNhieuVi({'v'});
      final neo = await db.transactionDao.getById(idKhoanMoSo('v'));
      expect(neo, isNotNull);
      expect(neo!.idhousehold, _nha,
          reason: 'neo NULL trỏ ví nhà là thứ khoá phép dọn; hàng ấy cũng hiện ở Sổ giao dịch cá nhân');
      expect(neo.amount, 500000);
    });

    test('ví nhà NGƯỜI KHÁC tạo: máy này không đặt neo', () async {
      await vi('v', _nguoiKhac, nha: _nha);
      await SoDuViService(db: db, taiKhoanPhien: () => _toi).datNeoNhieuVi({'v'});
      expect(await db.transactionDao.getById(idKhoanMoSo('v')), isNull,
          reason: '02A: chỉ máy tạo ví đặt neo, máy khác nhận qua kéo về. Đặt ở đây là neo thứ hai, đẩy lên thành '
              '`HOUSEHOLD_ROLE_FORBIDDEN` hoặc nhân đôi số dư');
    });

    test('không biết tài khoản phiên: ví nhà không đặt neo, ví riêng vẫn đặt', () async {
      await vi('nha', _toi, nha: _nha);
      await vi('rieng', _toi);
      final dv = SoDuViService(db: db);
      await dv.datNeoNhieuVi({'nha', 'rieng'});
      expect(await db.transactionDao.getById(idKhoanMoSo('nha')), isNull);
      final neoRieng = await db.transactionDao.getById(idKhoanMoSo('rieng'));
      expect(neoRieng, isNotNull);
      expect(neoRieng!.idhousehold, isNull);
    });
  });

  group('nợ 9: số dư ví nhà là cache cục bộ', () {
    test('tính lại ví nhà: đổi balance, KHÔNG pending, KHÔNG đổi updatedAt', () async {
      await vi('v', _nguoiKhac, nha: _nha, soDu: 0);
      await db.transactionDao.insert(TransactionsCompanion(
          id: const Value('g'),
          idaccount: const Value(_nguoiKhac),
          walletId: const Value('v'),
          amount: const Value(50000),
          type: const Value('thu'),
          date: Value(ngay),
          idhousehold: const Value(_nha),
          updatedAt: Value(ngay)));
      await SoDuViService(db: db, taiKhoanPhien: () => _toi).tinhLaiSoDu('v');
      final w = await db.walletDao.getById('v');
      expect(w!.balance, 50000);
      expect(w.syncStatus, 'synced',
          reason: 'pending trên máy thành viên nằm mãi; trên máy người tạo thì đẩy lại sau mỗi lượt kéo, `updatedAt = now` '
              'thắng LWW trước sửa thật, và thành vòng `HOUSEHOLD_ROLE_FORBIDDEN` khi người tạo không còn là Chủ');
      expect(w.updatedAt, ngay);
    });

    test('ví nhà đang pending (sửa tên chưa đẩy): tính lại số dư GIỮ pending và updatedAt, không nuốt bản sửa', () async {
      await db.walletDao.insert(WalletsCompanion(
          id: const Value('v'),
          idaccount: const Value(_toi),
          name: const Value('Tên mới chưa đẩy'),
          balance: const Value(0),
          idhousehold: const Value(_nha),
          syncStatus: const Value('pending'),
          updatedAt: Value(ngay)));
      await db.transactionDao.insert(TransactionsCompanion(
          id: const Value('g'),
          idaccount: const Value(_nguoiKhac),
          walletId: const Value('v'),
          amount: const Value(70000),
          type: const Value('thu'),
          date: Value(ngay),
          idhousehold: const Value(_nha),
          updatedAt: Value(ngay)));
      await SoDuViService(db: db, taiKhoanPhien: () => _toi).tinhLaiSoDu('v');
      final w = await db.walletDao.getById('v');
      expect(w!.balance, 70000);
      expect(w.syncStatus, 'pending', reason: 'đổi sang synced là bản sửa tên chưa đẩy không bao giờ lên server');
      expect(w.updatedAt, ngay);
      expect(w.name, 'Tên mới chưa đẩy');
    });

    test('tính lại ví RIÊNG giữ nguyên hành vi cũ: pending + updatedAt mới', () async {
      await vi('v', _toi, soDu: 0);
      await db.transactionDao.insert(TransactionsCompanion(
          id: const Value('g'),
          idaccount: const Value(_toi),
          walletId: const Value('v'),
          amount: const Value(50000),
          type: const Value('thu'),
          date: Value(ngay),
          updatedAt: Value(ngay)));
      await SoDuViService(db: db).tinhLaiSoDu('v');
      final w = await db.walletDao.getById('v');
      expect(w!.syncStatus, 'pending');
      expect(w.updatedAt.isAfter(ngay), isTrue);
    });
  });

  test('getViNhaDoToiTao: chỉ ví nhà do tôi tạo, bỏ ví riêng / ví người khác / ví đã xoá', () async {
    await vi('nha-toi', _toi, nha: _nha);
    await vi('nha-khac', _nguoiKhac, nha: _nha);
    await vi('rieng', _toi);
    await db.walletDao.insert(WalletsCompanion(
        id: const Value('nha-xoa'),
        idaccount: const Value(_toi),
        name: const Value('nha-xoa'),
        idhousehold: const Value(_nha),
        deletedAt: Value(ngay),
        updatedAt: Value(ngay)));
    expect((await db.walletDao.getViNhaDoToiTao(_toi)).map((w) => w.id), ['nha-toi']);
  });
}
