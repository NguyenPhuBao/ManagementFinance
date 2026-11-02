/// `GopQuyConflictResolver` — giữ hai nửa góp / rút khớp nhau (gia đình 1A, Task 9; `docs/Family/02A` mục 6). SQLite thật,
/// như `gop_quy_service_test`: ba lối vào (server từ chối, Chủ nhà xoá nửa của nhà, rời nhà khi chưa đẩy) + dọn hàng nhà kẹt.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_models.dart';
import 'package:flowmoney/features/household/application/dieu_phoi_doi_nha.dart';
import 'package:flowmoney/features/household/application/gop_quy_conflict_resolver.dart';
import 'package:flowmoney/features/household/application/gop_quy_service.dart';
import 'package:flowmoney/features/household/data/models/nha_cua_toi.dart';
import 'package:flowmoney/features/household/data/nha_store.dart';
import 'package:flowmoney/features/household/data/repositories/nha_repository.dart';
import 'package:flowmoney/features/household/data/repositories/nha_repository_impl.dart';
import 'package:flowmoney/features/household/domain/cau_loi_nha.dart' show kMaDayLoiNha;
import 'package:flowmoney/features/household/domain/vai_nha.dart';
import 'package:flowmoney/features/notification/domain/notification_rules.dart';
import 'package:flowmoney/features/transaction/data/datasources/transaction_local_data_source.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:flowmoney/features/wallet/data/so_du_vi_service.dart';

import '../../../helpers/household_api_gia.dart';
import '../../transaction/data/repositories/transaction_repository_test.dart' show DummySyncEngine;

/// `NhaRepository` giả: chỉ những gì resolver đọc. Mọi thứ khác ném (`noSuchMethod`) để bắt chỗ gọi ngoài ý.
class _NhaGia implements NhaRepository {
  _NhaGia(this.hienTaiGia);

  NhaCuaToi hienTaiGia;
  bool lamMoiThanhCong = true;
  int soLanLamMoi = 0;
  int? idaccountGia = 10;

  @override
  NhaCuaToi get hienTai => hienTaiGia;
  @override
  int? get idaccount => idaccountGia;
  @override
  Future<bool> lamMoi() async {
    soLanLamMoi++;
    return lamMoiThanhCong;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

NhaCuaToi _nhaDangO(int id, {TrangThaiNha trangThai = TrangThaiNha.hoatDong}) => NhaCuaToi(
      nha: NhaEntity(id: id, ten: 'Nhà', trangThai: trangThai, toiDaThanhVien: 6),
      vai: VaiNha.chu,
      thanhVien: const [],
      nhanLuc: DateTime(2026, 11, 1),
    );

SyncResult _thatBai(String localId, String? code, {SyncEntityType entity = SyncEntityType.transaction}) => SyncResult(
      totalOps: 1,
      succeeded: 0,
      failed: 1,
      failures: [
        SyncOpFailure(
            localId: localId, entity: entity, message: 'từ chối', kind: SyncFailureKind.permanent, code: code),
      ],
    );

void main() {
  late AppDatabase db;
  late GopQuyService gop;
  late SoDuViService soDuVi;
  late DummySyncEngine sync;
  late _NhaGia nha;
  late GopQuyConflictResolver resolver;
  int? phien;
  var soLanHen = 0;
  final xinKeoLaiGoi = <int>[];
  final ngay = DateTime(2026, 11, 1, 9);
  final moc = DateTime(2026, 10, 1);

  Future<void> themVi(String id, String ten, {required double soDu, int? nhaId}) =>
      db.walletDao.insert(WalletsCompanion.insert(
        id: id,
        idaccount: 10,
        name: ten,
        balance: Value(soDu),
        idhousehold: Value(nhaId),
        updatedAt: moc,
      ));

  GopQuyConflictResolver dungResolver(NhaRepository n) => GopQuyConflictResolver(
        db: db,
        gopQuy: gop,
        nha: n,
        soDuVi: soDuVi,
        taiKhoanPhien: () => phien,
        henDongBo: () => soLanHen++,
        xinKeoLai: (id) async => xinKeoLaiGoi.add(id),
      );

  setUp(() async {
    soLanHen = 0;
    xinKeoLaiGoi.clear();
    phien = 10;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sync = DummySyncEngine();
    soDuVi = SoDuViService(db: db, taiKhoanPhien: () => 10);
    gop = GopQuyService(
      giaoDich: TransactionRepositoryImpl(
        localDataSource: TransactionLocalDataSourceImpl(db),
        syncEngine: sync,
        soDuVi: soDuVi,
      ),
      db: db,
      soDuVi: soDuVi,
      henDongBo: () {},
    );
    nha = _NhaGia(_nhaDangO(7));
    resolver = dungResolver(nha);
    await themVi('vr', 'Ví MB', soDu: 5000000);
    await themVi('vn', 'Tiền chợ', soDu: 1000000, nhaId: 7);
  });
  tearDown(() => db.close());

  Future<double> soDu(String id) async => (await db.walletDao.getById(id))!.balance;
  Future<List<AppNotification>> thongBao() => db.notificationDao.getAll(10);
  Future<Transaction> hang(String id) async => (await db.transactionDao.getById(id))!;

  Future<String> gopMau({String? viRieng = 'vr', double soTien = 2000000}) => gop.gop(
      idNha: 7,
      idaccount: 10,
      viChungId: 'vn',
      tenViChung: 'Tiền chợ',
      soTien: soTien,
      viRiengId: viRieng,
      ngay: ngay);

  /// Chủ nhà xoá nửa của nhà: kéo về là hàng đã xoá mềm, đã đồng bộ.
  Future<void> chuNhaXoaNuaNha(String maCap) async {
    final cap = await gop.docCap(maCap);
    await db.transactionDao.softDelete(cap.nha!.id);
    await db.transactionDao.markSynced(cap.nha!.id);
  }

  group('server từ chối nửa của nhà', () {
    for (final m in kMaDayLoiNha) {
      test('mã $m: gỡ cả hai nửa, số dư về, nửa nhà thôi pending, một thông báo', () async {
        final p = await gopMau();
        final nuaNha = (await gop.docCap(p)).nha!;
        final nuaRieng = (await gop.docCap(p)).rieng!;
        expect(await soDu('vr'), 3000000);
        expect(await soDu('vn'), 3000000);

        await resolver.xuLy(_thatBai(nuaNha.id, m));

        expect((await gop.docCap(p)).rieng, isNull, reason: 'nửa riêng phải bị gỡ');
        expect((await gop.docCap(p)).nha, isNull, reason: 'nửa của nhà phải bị gỡ');
        expect(await soDu('vr'), 5000000, reason: 'tiền về ví riêng');
        expect(await soDu('vn'), 1000000, reason: 'ví chung về đúng số cũ');
        expect((await hang(nuaNha.id)).syncStatus, 'synced',
            reason: 'mã vĩnh viễn KHÔNG làm hàng thôi pending: không markSynced thì lệnh xoá bị đẩy lại mãi và lần nào cũng bị chính mã ấy từ chối ở '
                'kiểm quyền, trước khi tới xoá (hàng server CÒN nếu bản sửa bị từ chối — G119)');
        expect((await hang(nuaRieng.id)).syncStatus, 'pending', reason: 'nửa riêng đã/ sẽ lên server: cờ xoá phải đi lên');
        final tb = await thongBao();
        expect(tb, hasLength(1));
        expect(tb.single.dedupeKey, 'gopTraVe:$p');
        expect(tb.single.kind, NotificationKind.gopQuyBiTraVe.name);
        expect(tb.single.body, 'Chưa góp được vào quỹ Tiền chợ, đã trả tiền về Ví MB.');
        expect(tb.single.deeplink, '/transactions');
        expect(tb.single.subjectType, 'nha', reason: 'biểu tượng ngôi nhà ở trung tâm thông báo');
      });
    }

    test('sau khi gỡ, nửa nhà không còn pending và không hiện ở danh sách của nhà', () async {
      final p = await gopMau();
      final nuaNha = (await gop.docCap(p)).nha!;
      await resolver.xuLy(_thatBai(nuaNha.id, 'HOUSEHOLD_READ_ONLY'));
      expect(await db.transactionDao.getPending(10, 7), isNot(contains(predicate<Transaction>((t) => t.id == nuaNha.id))),
          reason: 'nhà ReadOnly từ chối: nửa nhà không được nằm trong lô đẩy nữa');
      expect((await db.transactionDao.watchTheoNha(7).first).where((t) => t.fundPairId != null), isEmpty,
          reason: 'không còn nửa góp nào của nhà (neo "Số dư ban đầu" của ví chung không phải khoản góp)');
      expect(await soDu('vn'), 1000000);
      expect(await soDu('vr'), 5000000);
    });

    test('hai lượt phát cho cùng một thất bại: lượt sau không làm gì, không báo thêm', () async {
      final p = await gopMau();
      final nuaNha = (await gop.docCap(p)).nha!;
      final kq = _thatBai(nuaNha.id, 'HOUSEHOLD_NOT_MEMBER');
      await resolver.xuLy(kq);
      final henLan1 = soLanHen;
      await resolver.xuLy(kq);
      expect(await thongBao(), hasLength(1));
      expect(soLanHen, henLan1, reason: 'lượt hai không đổi gì thì không xin đồng bộ');
      expect(await soDu('vr'), 5000000);
      expect(await soDu('vn'), 1000000);
    });

    test('hai lượt phát CHỒNG nhau (không await giữa) vẫn chỉ gỡ và báo một lần', () async {
      final p = await gopMau();
      final nuaNha = (await gop.docCap(p)).nha!;
      final kq = _thatBai(nuaNha.id, 'HOUSEHOLD_NOT_MEMBER');
      await Future.wait([resolver.xuLy(kq), resolver.xuLy(kq)]);
      expect(await thongBao(), hasLength(1));
      expect(soLanHen, 1,
          reason: 'tuần tự: lượt hai thấy nửa nhà đã xoá nên chỉ markSynced. Chạy chồng thì cả hai cùng gỡ và xin đồng bộ hai lần');
      expect(await soDu('vr'), 5000000);
      expect(await soDu('vn'), 1000000);
    });

    test('mã khác nhóm từ chối của gia đình: không đụng gì', () async {
      final p = await gopMau();
      final nuaNha = (await gop.docCap(p)).nha!;
      await resolver.xuLy(_thatBai(nuaNha.id, 'DB_ERROR'));
      await resolver.xuLy(_thatBai(nuaNha.id, null));
      expect((await gop.docCap(p)).nha, isNotNull);
      expect((await gop.docCap(p)).rieng, isNotNull);
      expect(await thongBao(), isEmpty);
    });

    test('thất bại của entity khác (cùng mã): không đụng gì', () async {
      final p = await gopMau();
      final nuaNha = (await gop.docCap(p)).nha!;
      await resolver.xuLy(_thatBai(nuaNha.id, 'HOUSEHOLD_NOT_MEMBER', entity: SyncEntityType.wallet));
      expect((await gop.docCap(p)).nha, isNotNull);
      expect(await thongBao(), isEmpty);
    });

    test('thất bại của nửa riêng: không đụng', () async {
      final p = await gopMau();
      final nuaRieng = (await gop.docCap(p)).rieng!;
      await resolver.xuLy(_thatBai(nuaRieng.id, 'HOUSEHOLD_NOT_MEMBER'));
      expect((await gop.docCap(p)).rieng, isNotNull);
      expect((await gop.docCap(p)).nha, isNotNull);
      expect(await soDu('vr'), 3000000);
    });

    test('nửa của nhà do NGƯỜI KHÁC ghi (sửa / xoá hộ bị ROLE_FORBIDDEN): trả bản server, KHÔNG đụng nửa riêng', () async {
      final p = await gopMau();
      final nuaNha = (await gop.docCap(p)).nha!;
      await db.transactionDao.updateRow(nuaNha.id, const TransactionsCompanion(idaccount: Value(99), syncStatus: Value('pending')));
      await resolver.xuLy(_thatBai(nuaNha.id, 'HOUSEHOLD_ROLE_FORBIDDEN'));
      final sau = await hang(nuaNha.id);
      expect(sau.deletedAt, isNotNull,
          reason: 'bản sửa / xoá hộ vĩnh viễn bị từ chối: gỡ khỏi máy để kéo toàn bộ trả bản server (hàng kẹt pending ở lại chặn '
              'Pull, số dư ví chung lệch mãi — I-2)');
      expect(sau.syncStatus, 'synced', reason: 'thoát hàng đợi: không đẩy lại mãi');
      expect((await gop.docCap(p)).rieng, isNotNull, reason: 'nửa riêng là của người ghi, không thuộc máy này');
      expect(await soDu('vr'), 3000000);
      expect(await soDu('vn'), 1000000, reason: 'ví chung tính lại không còn nửa vừa gỡ; kéo toàn bộ sẽ đưa nó về');
      expect(await thongBao(), isEmpty, reason: 'nhánh này không báo người dùng');
      expect(xinKeoLaiGoi, [10], reason: 'xin kéo toàn bộ đúng một lần, cho tài khoản phiên');
    });

    test('hai lượt phát chồng nhau cho hàng sửa hộ: gỡ và xin kéo toàn bộ một lần', () async {
      final p = await gopMau();
      final nuaNha = (await gop.docCap(p)).nha!;
      await db.transactionDao.updateRow(nuaNha.id, const TransactionsCompanion(idaccount: Value(99), syncStatus: Value('pending')));
      final kq = _thatBai(nuaNha.id, 'HOUSEHOLD_ROLE_FORBIDDEN');
      await Future.wait([resolver.xuLy(kq), resolver.xuLy(kq)]);
      expect(xinKeoLaiGoi, [10], reason: 'lượt hai thấy hàng đã gỡ + synced thì không làm gì, không xin kéo thêm');
    });

    test('khoản thường của người khác trong nhà (không mã cặp): cũng trả bản server', () async {
      await db.transactionDao.insert(TransactionsCompanion.insert(
          id: 'tn',
          walletId: 'vn',
          idaccount: 99,
          idhousehold: const Value(7),
          amount: 30000,
          type: 'chi',
          date: ngay,
          syncStatus: const Value('pending'),
          updatedAt: moc));
      await resolver.xuLy(_thatBai('tn', 'HOUSEHOLD_ROLE_FORBIDDEN'));
      expect((await hang('tn')).deletedAt, isNotNull);
      expect((await hang('tn')).syncStatus, 'synced');
      expect(xinKeoLaiGoi, [10]);
    });

    test('khoản thường của TÔI trong nhà bị ROLE_FORBIDDEN: gỡ, xin kéo toàn bộ', () async {
      await db.transactionDao.insert(TransactionsCompanion.insert(
          id: 'tt',
          walletId: 'vn',
          idaccount: 10,
          idhousehold: const Value(7),
          amount: 30000,
          type: 'chi',
          date: ngay,
          syncStatus: const Value('pending'),
          updatedAt: moc));
      await resolver.xuLy(_thatBai('tt', 'HOUSEHOLD_ROLE_FORBIDDEN'));
      expect((await hang('tt')).deletedAt, isNotNull);
      expect((await hang('tt')).syncStatus, 'synced');
      expect(xinKeoLaiGoi, [10]);
    });

    test('mã KHÁC ROLE_FORBIDDEN trên khoản thường của nhà: không đụng, không xin kéo', () async {
      await db.transactionDao.insert(TransactionsCompanion.insert(
          id: 'tk',
          walletId: 'vn',
          idaccount: 99,
          idhousehold: const Value(7),
          amount: 30000,
          type: 'chi',
          date: ngay,
          syncStatus: const Value('pending'),
          updatedAt: moc));
      await resolver.xuLy(_thatBai('tk', 'HOUSEHOLD_READ_ONLY'));
      expect((await hang('tk')).deletedAt, isNull,
          reason: 'READ_ONLY có thể tự hết (Chủ gia hạn): hàng ở lại pending, KHÔNG gỡ');
      expect((await hang('tk')).syncStatus, 'pending');
      expect(xinKeoLaiGoi, isEmpty);
    });

    test('khoản thường KHÔNG thuộc nhà bị ROLE_FORBIDDEN: không đụng', () async {
      await db.transactionDao.insert(TransactionsCompanion.insert(
          id: 'tr',
          walletId: 'vr',
          idaccount: 10,
          amount: 30000,
          type: 'chi',
          date: ngay,
          syncStatus: const Value('pending'),
          updatedAt: moc));
      await resolver.xuLy(_thatBai('tr', 'HOUSEHOLD_ROLE_FORBIDDEN'));
      expect((await hang('tr')).deletedAt, isNull);
      expect(xinKeoLaiGoi, isEmpty);
    });

    test('ví của nhà sửa hộ bị ROLE_FORBIDDEN: gỡ khỏi máy, thoát hàng đợi, xin kéo toàn bộ', () async {
      await resolver.xuLy(_thatBai('vn', 'HOUSEHOLD_ROLE_FORBIDDEN', entity: SyncEntityType.wallet));
      final v = (await db.walletDao.getById('vn'))!;
      expect(v.isDeleted, isTrue);
      expect(v.syncStatus, 'synced');
      expect(xinKeoLaiGoi, [10]);
    });

    test('ví KHÔNG thuộc nhà bị ROLE_FORBIDDEN: không đụng', () async {
      await resolver.xuLy(_thatBai('vr', 'HOUSEHOLD_ROLE_FORBIDDEN', entity: SyncEntityType.wallet));
      expect((await db.walletDao.getById('vr'))!.isDeleted, isFalse);
      expect(xinKeoLaiGoi, isEmpty);
    });

    test('danh mục của nhà sửa hộ bị ROLE_FORBIDDEN: gỡ khỏi máy, thoát hàng đợi, xin kéo toàn bộ', () async {
      await db.categoryDao.insert(CategoriesCompanion.insert(
          id: 'dm',
          idaccount: 99,
          name: 'Điện',
          classify: 'chi',
          idhousehold: const Value(7),
          syncStatus: const Value('pending'),
          updatedAt: moc));
      await resolver.xuLy(_thatBai('dm', 'HOUSEHOLD_ROLE_FORBIDDEN', entity: SyncEntityType.category));
      final c = (await db.categoryDao.getById('dm'))!;
      expect(c.isDeleted, isTrue);
      expect(c.syncStatus, 'synced');
      expect(xinKeoLaiGoi, [10]);
    });

    test('ngân sách của nhà bị ROLE_FORBIDDEN: không đụng (ghi G)', () async {
      await db.budgetDao.insert(BudgetsCompanion.insert(
          id: 'b1',
          idaccount: 10,
          idhousehold: const Value(7),
          amount: 1000000,
          startDate: DateTime(2026, 11, 1),
          syncStatus: const Value('pending'),
          updatedAt: moc));
      await resolver.xuLy(_thatBai('b1', 'HOUSEHOLD_ROLE_FORBIDDEN', entity: SyncEntityType.budget));
      final b = (await db.budgetDao.getById('b1'))!;
      expect(b.deletedAt, isNull, reason: 'ngân sách chưa có bậc gỡ: hàng ở lại pending với bậc chặn riêng');
      expect(b.syncStatus, 'pending');
      expect(xinKeoLaiGoi, isEmpty);
    });

    test('nửa của nhà do tôi ghi bị UNIQUE_VIOLATION (entity giao dịch): không đụng cặp', () async {
      final p = await gopMau();
      final nuaNha = (await gop.docCap(p)).nha!;
      await resolver.xuLy(_thatBai(nuaNha.id, 'UNIQUE_VIOLATION'));
      expect((await gop.docCap(p)).nha, isNotNull,
          reason: 'nửa của nhà do tôi ghi mà lọt nhánh UNIQUE_VIOLATION là gỡ cả cặp và trả tiền về ví riêng');
      expect((await gop.docCap(p)).rieng, isNotNull);
      expect(await soDu('vr'), 3000000);
      expect(await soDu('vn'), 3000000);
      expect(await thongBao(), isEmpty);
      expect(xinKeoLaiGoi, isEmpty);
    });

    Future<void> themMucTieu(String id, {int? nhaId, String trangThai = 'pending'}) =>
        db.goalDao.insert(GoalsCompanion.insert(
          id: id,
          idaccount: 10,
          idhousehold: Value(nhaId),
          name: 'Du lịch',
          targetAmount: 5000000,
          targetDate: DateTime(2027, 1, 1),
          syncStatus: Value(trangThai),
          updatedAt: moc,
        ));
    Future<Goal> mucTieu(String id) async => (await db.goalDao.getById(id))!;

    test('mục tiêu của nhà bị ROLE_FORBIDDEN: gỡ khỏi máy, thoát hàng đợi, xin kéo toàn bộ một lần', () async {
      await themMucTieu('g1', nhaId: 7);
      await resolver.xuLy(_thatBai('g1', 'HOUSEHOLD_ROLE_FORBIDDEN', entity: SyncEntityType.goal));
      final g = await mucTieu('g1');
      expect(g.deletedAt, isNotNull, reason: 'bản sửa / xoá bị từ chối vĩnh viễn: gỡ khỏi máy để kéo toàn bộ trả bản server');
      expect(g.syncStatus, 'synced');
      expect(xinKeoLaiGoi, [10]);
    });

    test('mục tiêu của nhà ĐÃ xoá mềm + pending bị ROLE_FORBIDDEN: chỉ markSynced, deletedAt giữ nguyên, xin kéo một lần', () async {
      await themMucTieu('g1', nhaId: 7);
      await db.goalDao.softDelete('g1');
      final truoc = (await mucTieu('g1')).deletedAt;
      expect(truoc, isNotNull);
      expect((await mucTieu('g1')).syncStatus, 'pending', reason: 'tiền đề: xoá mềm đặt lại pending (Chủ tắt mục tiêu offline)');
      await resolver.xuLy(_thatBai('g1', 'HOUSEHOLD_ROLE_FORBIDDEN', entity: SyncEntityType.goal));
      final g = await mucTieu('g1');
      expect(g.syncStatus, 'synced', reason: 'lệnh xoá bị từ chối ở kiểm quyền: phải thoát hàng đợi, không đẩy lại mãi');
      expect(g.deletedAt, truoc);
      expect(xinKeoLaiGoi, [10]);
    });

    test('mục tiêu của nhà bị UNIQUE_VIOLATION (hai máy Chủ cùng bật offline): gỡ, thoát hàng đợi, xin kéo', () async {
      await themMucTieu('g1', nhaId: 7);
      await resolver.xuLy(_thatBai('g1', 'UNIQUE_VIOLATION', entity: SyncEntityType.goal));
      final g = await mucTieu('g1');
      expect(g.deletedAt, isNotNull, reason: 'thiếu nhánh này thì máy đẩy sau thua chỉ mục duy nhất và hàng kẹt pending mãi');
      expect(g.syncStatus, 'synced');
      expect(xinKeoLaiGoi, [10]);
    });

    test('mục tiêu của nhà: phát lại cùng thất bại lần hai thì chỉ xin kéo một lần', () async {
      await themMucTieu('g1', nhaId: 7);
      final kq = _thatBai('g1', 'UNIQUE_VIOLATION', entity: SyncEntityType.goal);
      await resolver.xuLy(kq);
      await resolver.xuLy(kq);
      expect(xinKeoLaiGoi, [10], reason: 'lượt hai thấy hàng đã gỡ + synced thì không làm gì');
    });

    test('mục tiêu RIÊNG bị UNIQUE_VIOLATION: không đụng, không xin kéo', () async {
      await themMucTieu('g1');
      await resolver.xuLy(_thatBai('g1', 'UNIQUE_VIOLATION', entity: SyncEntityType.goal));
      final g = await mucTieu('g1');
      expect(g.deletedAt, isNull, reason: 'chỉ hàng của nhà được đi cửa này');
      expect(g.syncStatus, 'pending');
      expect(xinKeoLaiGoi, isEmpty);
    });

    test('ví bị UNIQUE_VIOLATION: hành vi cũ, không đụng', () async {
      await resolver.xuLy(_thatBai('vn', 'UNIQUE_VIOLATION', entity: SyncEntityType.wallet));
      final v = (await db.walletDao.getById('vn'))!;
      expect(v.isDeleted, isFalse, reason: 'chỉ mục tiêu mới được đi cửa UNIQUE_VIOLATION');
      expect(xinKeoLaiGoi, isEmpty);
    });

    test('mục tiêu của nhà bị READ_ONLY: giữ pending (Chủ gia hạn là lên)', () async {
      await themMucTieu('g1', nhaId: 7);
      await resolver.xuLy(_thatBai('g1', 'HOUSEHOLD_READ_ONLY', entity: SyncEntityType.goal));
      final g = await mucTieu('g1');
      expect(g.deletedAt, isNull);
      expect(g.syncStatus, 'pending');
      expect(xinKeoLaiGoi, isEmpty);
    });

    test('chưa có phiên (taiKhoanPhien null): không gỡ gì', () async {
      final p = await gopMau();
      final nuaNha = (await gop.docCap(p)).nha!;
      phien = null;
      await resolver.xuLy(_thatBai(nuaNha.id, 'HOUSEHOLD_NOT_MEMBER'));
      expect((await gop.docCap(p)).nha, isNotNull);
      expect(await thongBao(), isEmpty);
    });

    test('nửa nhà ĐÃ xoá mềm (người ghi xoá cặp offline): chỉ markSynced, không báo, số dư giữ', () async {
      final p = await gopMau();
      final nuaNha = (await gop.docCap(p)).nha!;
      await gop.xoa(p);
      expect((await hang(nuaNha.id)).syncStatus, 'pending');
      await resolver.xuLy(_thatBai(nuaNha.id, 'HOUSEHOLD_CLOSED'));
      expect((await hang(nuaNha.id)).syncStatus, 'synced', reason: 'phải thoát hàng đợi, không đẩy lại mãi');
      expect(await thongBao(), isEmpty, reason: 'người dùng tự xoá: không cần báo');
      expect(await soDu('vr'), 5000000);
      expect(await soDu('vn'), 1000000);
    });

    test('tiền mặt trao tay: gỡ nửa nhà, câu không nói trả tiền', () async {
      final p = await gopMau(viRieng: null, soTien: 1000);
      final nuaNha = (await gop.docCap(p)).nha!;
      expect(await soDu('vn'), 1001000);
      await resolver.xuLy(_thatBai(nuaNha.id, 'HOUSEHOLD_NOT_MEMBER'));
      expect(await soDu('vn'), 1000000);
      expect(await soDu('vr'), 5000000, reason: 'không ví riêng nào bị đụng');
      final tb = await thongBao();
      expect(tb.single.body, 'Chưa ghi được khoản góp vào quỹ Tiền chợ.');
      expect(tb.single.body, isNot(contains('trả tiền')));
    });

    test('khoản rút: nửa nhà chi, nửa riêng thu — câu nói đúng rút, số dư về', () async {
      final p = await gop.rut(
          idNha: 7, idaccount: 10, viChungId: 'vn', tenViChung: 'Tiền chợ', soTien: 400000, viRiengId: 'vr', ngay: ngay);
      expect(await soDu('vr'), 5400000);
      expect(await soDu('vn'), 600000);
      final nuaNha = (await gop.docCap(p)).nha!;
      await resolver.xuLy(_thatBai(nuaNha.id, 'HOUSEHOLD_READ_ONLY'));
      expect(await soDu('vr'), 5000000);
      expect(await soDu('vn'), 1000000);
      final tb = await thongBao();
      expect(tb.single.body, 'Chưa rút được từ quỹ Tiền chợ, đã huỷ khoản nhận ở Ví MB.');
      expect(tb.single.title, 'Chưa rút được từ quỹ');
    });
  });

  group('Chủ nhà xoá nửa của nhà', () {
    test('nhà Active và mình còn ở: gỡ nửa riêng, thông báo gopBiXoa, không đụng nửa nhà', () async {
      final p = await gopMau();
      await chuNhaXoaNuaNha(p);
      await resolver.xuLyNuaNhaBiXoa(10);
      expect((await gop.docCap(p)).rieng, isNull);
      expect(await soDu('vr'), 5000000, reason: 'tiền về ví riêng');
      final tb = await thongBao();
      expect(tb, hasLength(1));
      expect(tb.single.dedupeKey, 'gopBiXoa:$p');
      expect(tb.single.kind, NotificationKind.gopQuyBiXoa.name);
      expect(tb.single.body, 'Chủ nhà đã xoá khoản góp vào quỹ Tiền chợ, đã trả tiền về Ví MB.');
      await resolver.xuLyNuaNhaBiXoa(10);
      expect(await thongBao(), hasLength(1), reason: 'lượt kéo sau: không còn mồ côi, không báo thêm');
    });

    test('nhà đã giải tán / không còn nhà: giữ nửa riêng', () async {
      final p = await gopMau();
      await chuNhaXoaNuaNha(p);
      nha.hienTaiGia = NhaCuaToi.khongCo(DateTime(2026, 11, 1));
      await resolver.xuLyNuaNhaBiXoa(10);
      expect((await gop.docCap(p)).rieng, isNotNull);
      expect(await soDu('vr'), 3000000);
      expect(await thongBao(), isEmpty);
    });

    test('đang ở một NHÀ KHÁC: giữ nửa riêng (rời nhà thì nửa riêng ở lại thành khoản riêng)', () async {
      final p = await gopMau();
      await chuNhaXoaNuaNha(p);
      nha.hienTaiGia = _nhaDangO(8);
      await resolver.xuLyNuaNhaBiXoa(10);
      expect((await gop.docCap(p)).rieng, isNotNull, reason: 'không so idNha mồ côi với nhà hiện tại là gỡ nhầm khoản của nhà cũ');
      expect(await soDu('vr'), 3000000);
      expect(await thongBao(), isEmpty);
    });

    test('đọc /me hỏng: hoãn, không gỡ; lượt sau /me đọc được thì gỡ', () async {
      final p = await gopMau();
      await chuNhaXoaNuaNha(p);
      nha.lamMoiThanhCong = false;
      await resolver.xuLyNuaNhaBiXoa(10);
      expect((await gop.docCap(p)).rieng, isNotNull,
          reason: 'lamMoi nuốt lỗi và giữ trạng thái cũ trong kho: nhà đã giải tán vẫn trông như còn');
      expect(await thongBao(), isEmpty);
      nha.lamMoiThanhCong = true;
      await resolver.xuLyNuaNhaBiXoa(10);
      expect((await gop.docCap(p)).rieng, isNull);
      expect(await thongBao(), hasLength(1));
    });

    test('phiên của repository nhà khác tài khoản: không gỡ', () async {
      final p = await gopMau();
      await chuNhaXoaNuaNha(p);
      nha.idaccountGia = 11;
      await resolver.xuLyNuaNhaBiXoa(10);
      expect((await gop.docCap(p)).rieng, isNotNull);
    });

    test('người góp tự xoá trên máy này (hai nửa cùng xoá): không báo, không hỏi /me', () async {
      final p = await gopMau();
      await gop.xoa(p);
      await resolver.xuLyNuaNhaBiXoa(10);
      expect(await thongBao(), isEmpty);
      expect(nha.soLanLamMoi, 0, reason: 'không có mồ côi thì không tốn một lượt /me');
    });

    test('nửa của nhà đã bị dọn khi rời nhà (không còn hàng nào): nửa riêng ở lại, không hỏi /me', () async {
      final p = await gopMau();
      await db.xoaHangCuaNha(7);
      await resolver.xuLyNuaNhaBiXoa(10);
      expect((await gop.docCap(p)).rieng, isNotNull);
      expect(nha.soLanLamMoi, 0);
    });

    test('khoản rút bị Chủ nhà xoá: huỷ khoản nhận, số dư về', () async {
      final p = await gop.rut(
          idNha: 7, idaccount: 10, viChungId: 'vn', tenViChung: 'Tiền chợ', soTien: 400000, viRiengId: 'vr', ngay: ngay);
      await chuNhaXoaNuaNha(p);
      await resolver.xuLyNuaNhaBiXoa(10);
      expect(await soDu('vr'), 5000000);
      expect((await thongBao()).single.body, 'Chủ nhà đã xoá khoản rút từ quỹ Tiền chợ, đã huỷ khoản nhận ở Ví MB.');
    });
  });

  group('rời nhà khi nửa của nhà còn pending', () {
    test('trả tiền về: gỡ cả hai nửa, số dư về, thông báo', () async {
      final p = await gopMau();
      await resolver.traVeKhiBoNha(7, 10);
      expect((await gop.docCap(p)).rieng, isNull);
      expect((await gop.docCap(p)).nha, isNull);
      expect(await soDu('vr'), 5000000);
      expect(await soDu('vn'), 1000000);
      expect((await thongBao()).single.dedupeKey, 'gopTraVe:$p');
    });

    test('nửa của nhà đã lên server (synced): giữ nửa riêng', () async {
      final p = await gopMau();
      await db.transactionDao.markSynced((await gop.docCap(p)).nha!.id);
      await resolver.traVeKhiBoNha(7, 10);
      expect((await gop.docCap(p)).rieng, isNotNull);
      expect(await soDu('vr'), 3000000);
      expect(await thongBao(), isEmpty);
    });

    test('tiền mặt trao tay chưa đẩy: gỡ nửa nhà, câu không nói trả tiền', () async {
      await gopMau(viRieng: null, soTien: 1000);
      await resolver.traVeKhiBoNha(7, 10);
      expect(await soDu('vn'), 1000000);
      expect((await thongBao()).single.body, 'Chưa ghi được khoản góp vào quỹ Tiền chợ.');
    });

    test('hàng của người khác / của nhà khác: không đụng', () async {
      final p = await gopMau();
      await resolver.traVeKhiBoNha(8, 10);
      await resolver.traVeKhiBoNha(7, 99);
      expect((await gop.docCap(p)).nha, isNotNull);
      expect(await thongBao(), isEmpty);
    });
  });

  group('DieuPhoiDoiNha + resolver thật', () {
    test('rời nhà: traVeKhiBoNha chạy TRƯỚC xoaHangCuaNha — tiền về ví riêng, rồi hàng nhà mới biến mất', () async {
      final p = await gopMau();
      final dieuPhoi = DieuPhoiDoiNha(
        db: db,
        keoLaiToanBo: (_) async {},
        truocKhiDon: (idNha, id) => resolver.traVeKhiBoNha(idNha, id),
      );
      await dieuPhoi.xuLy(const DoiNha(idaccount: 10, tu: 7, den: null));
      expect(await soDu('vr'), 5000000, reason: 'xoá hàng trước là mất dấu khoản góp chưa đẩy, tiền không về ví riêng');
      expect(await db.walletDao.getById('vn'), isNull, reason: 'hàng của nhà đã dọn');
      expect((await gop.docCap(p)).rieng, isNull);
      expect(await thongBao(), hasLength(1));
      await dieuPhoi.dung();
    });

    test('hàng kẹt: kho nhà vắng + dấu vắng + /me không nhà → hàng pending được dọn, khoản góp trả tiền về', () async {
      final p = await gopMau();
      final api = HouseholdApiGia(); // /me mặc định: không nhà
      final repo = NhaRepositoryImpl(api: api, kho: InMemoryNhaStore());
      final r = dungResolver(repo);
      final dieuPhoi = DieuPhoiDoiNha(
        db: db,
        keoLaiToanBo: (_) async {},
        truocKhiDon: (idNha, id) => r.traVeKhiBoNha(idNha, id),
      )..batDauNghe(repo.doiNha, daDocNha: repo.daDocNha);
      await repo.datTaiKhoan(10);
      expect(await repo.lamMoi(), isTrue);
      await dieuPhoi.choXong();
      await Future<void>.delayed(Duration.zero);
      await dieuPhoi.choXong();

      expect(await db.cacNhaConTrenMay(), isEmpty, reason: 'không còn hàng nào của nhà kẹt');
      expect(await soDu('vr'), 5000000, reason: 'khoản góp chưa đẩy: tiền về ví riêng');
      expect((await gop.docCap(p)).rieng, isNull);
      expect((await thongBao()).single.dedupeKey, 'gopTraVe:$p');
      await dieuPhoi.dung();
      await repo.dispose();
    });
  });

  group('conflict (LWW thua) trên mục tiêu của nhà', () {
    // Pull bỏ qua hàng mục tiêu nhà đang pending (`GoalDao.upsertKeoVe`); lần đẩy sau thua LWW thì engine `markSynced` và Pull
    // cùng chu kỳ có thể không mang bản thắng về (mốc kéo đã tiến qua). Resolver xin kéo toàn bộ để máy này không giữ giá trị
    // thua kèm `synced`.
    Future<void> themMuc(String id, {int? nhaId}) => db.goalDao.insert(GoalsCompanion.insert(
          id: id,
          idaccount: 10,
          name: id,
          targetAmount: 1000,
          targetDate: DateTime(2027, 1, 1),
          idhousehold: Value(nhaId),
          walletId: const Value('vn'),
          updatedAt: moc,
        ));

    SyncResult conflict(String id) => SyncResult(totalOps: 1, succeeded: 0, failed: 0, conflictIds: [id]);

    test('conflict trên goal của nhà → xin kéo toàn bộ đúng một lần', () async {
      await themMuc('gn', nhaId: 7);
      await resolver.xuLy(conflict('gn'));
      expect(xinKeoLaiGoi, [10],
          reason: 'bản thắng của server có thể không về ở Pull cùng chu kỳ: phải xin kéo toàn bộ, nếu không máy giữ giá trị thua + synced');
    });

    test('conflict trên goal RIÊNG → không xin', () async {
      await themMuc('gr');
      await resolver.xuLy(conflict('gr'));
      expect(xinKeoLaiGoi, isEmpty, reason: 'mục tiêu riêng: Pull tăng dần vẫn mang bản thắng về như trước');
    });

    test('conflict trên ví của nhà (id không phải goal) → không xin', () async {
      await resolver.xuLy(conflict('vn'));
      expect(xinKeoLaiGoi, isEmpty);
    });
  });
}
