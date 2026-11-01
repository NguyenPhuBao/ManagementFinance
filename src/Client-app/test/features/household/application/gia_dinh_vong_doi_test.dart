// Đo của người soát toàn nhánh gia đình 1A. Engine thật + SQLite thật + server giả theo mã `sync.service.js`.
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:flowmoney/core/api/dio_client.dart';
import 'package:flowmoney/core/auth/don_tai_khoan_khac.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';
import 'package:flowmoney/features/household/application/dieu_phoi_doi_nha.dart';
import 'package:flowmoney/features/household/application/gop_quy_conflict_resolver.dart';
import 'package:flowmoney/features/household/application/gop_quy_service.dart';
import 'package:flowmoney/features/household/data/models/nha_cua_toi.dart';
import 'package:flowmoney/features/household/data/repositories/du_lieu_nha_repository_impl.dart';
import 'package:flowmoney/features/household/data/repositories/nha_repository.dart';
import 'package:flowmoney/features/household/domain/vai_nha.dart';
import 'package:flowmoney/features/transaction/data/datasources/transaction_local_data_source.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:flowmoney/features/wallet/data/datasources/wallet_local_data_source.dart';
import 'package:flowmoney/features/wallet/data/so_du_vi_service.dart';
import 'package:flowmoney/features/wallet/data/vi_bi_giu_dong_bo.dart';

void row(String s) {
  // ignore: avoid_print
  print('ROW| $s');
}

class _Online implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [ConnectivityResult.wifi];
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Server giả: bám `processPush` / `enforceHouseholdPermission` / `softDelete` / `getTransactionsByAccount`.
class ServerGia {
  final vi = <String, Map<String, dynamic>>{};
  final gd = <String, Map<String, dynamic>>{};

  /// tài khoản → (nhà, vai). Vắng = không ở nhà nào.
  final thanhVien = <int, ({int nha, String vai})>{};
  final nhaChiXem = <int>{};
  int nhip = 0;
  int soLanPush = 0;
  int soLanPull = 0;
  final tuChoi = <String>[];

  /// Id hàng mà server trả lỗi KHÔNG phải của nhà (không mã) — để canh "lượt có cả lỗi khác vẫn tính hỏng".
  final hongKhac = <String>{};

  String _gio() {
    nhip++;
    return DateTime.now().toUtc().add(Duration(milliseconds: nhip)).toIso8601String();
  }

  Map<String, dynamic> xuLyPush(int tk, List ops) {
    final kq = <Map<String, dynamic>>[];
    for (final op in ops) {
      final p = Map<String, dynamic>.from(op['payload'] as Map);
      final entity = op['entity'] as String;
      final xoa = op['operation'] == 'delete';
      if (hongKhac.contains(p['id'])) {
        kq.add({'localId': op['localId'], 'status': 'error', 'message': 'boom'});
        continue;
      }
      final bang = entity == 'wallet' ? vi : gd;
      final cu = bang[p['id']];
      final nha = cu != null ? cu['idhousehold'] : p['idhousehold'];
      String? ma;
      if (nha != null) {
        final tv = thanhVien[tk];
        if (tv == null || tv.nha != nha) {
          ma = 'HOUSEHOLD_NOT_MEMBER';
        } else if (tv.vai == 'Viewer' || nhaChiXem.contains(nha)) {
          ma = 'HOUSEHOLD_READ_ONLY';
        } else if (entity == 'wallet' && tv.vai != 'Owner') {
          ma = 'HOUSEHOLD_ROLE_FORBIDDEN';
        } else if (entity == 'transaction' && cu != null) {
          final nguoiGhi = cu['idaccount'];
          if (tv.vai != 'Owner' && nguoiGhi != tk) ma = 'HOUSEHOLD_ROLE_FORBIDDEN';
          if (cu['idfund_pair'] != null && !xoa && nguoiGhi != tk) ma = 'HOUSEHOLD_ROLE_FORBIDDEN';
        }
        if (ma == null && cu == null && p['idaccount'] != null && p['idaccount'] != tk) ma = 'NOT_OWNER';
      } else if (p['idaccount'] != null && p['idaccount'] != tk) {
        ma = 'OWNERSHIP';
      }
      if (ma != null) {
        tuChoi.add('$entity:${p['id']}:$ma');
        kq.add({'localId': op['localId'], 'status': 'error', 'code': ma == 'OWNERSHIP' ? null : ma, 'message': ma});
        continue;
      }
      if (xoa) {
        if (cu != null) {
          final g = _gio();
          cu[entity == 'wallet' ? 'delete_at' : 'deleted_at'] = g;
          cu['update_at'] = g;
          cu['server_update_at'] = g;
        }
        kq.add({'localId': op['localId'], 'status': 'synced'});
        continue;
      }
      if (cu != null && !DateTime.parse(p['update_at']).isAfter(DateTime.parse(cu['update_at']))) {
        kq.add({'localId': op['localId'], 'status': 'conflict', 'message': 'newer'});
        continue;
      }
      if (entity == 'wallet') {
        vi[p['id']] = {
          'idwallet': p['id'],
          'idaccount': cu?['idaccount'] ?? p['idaccount'],
          'idhousehold': cu?['idhousehold'] ?? p['idhousehold'],
          'name': p['name'],
          'type': p['type'],
          'currency': p['currency'],
          'icon': p['icon'],
          'color': p['color'],
          'is_default': p['is_default'],
          'include_in_total': p['include_in_total'],
          'status': p['status'],
          'delete_at': cu?['delete_at'],
          'update_at': p['update_at'],
          'server_update_at': _gio(),
        };
      } else {
        gd[p['id']] = {
          'idtran': p['id'],
          'idaccount': cu?['idaccount'] ?? p['idaccount'],
          'idhousehold': cu?['idhousehold'] ?? p['idhousehold'],
          'idwallet': p['walletId'],
          'idcategory': p['categoryId'],
          'idwallet_transfer': p['idwallet_transfer'],
          'idfund_pair': p['idfund_pair'] ?? cu?['idfund_pair'],
          'amount': p['amount'],
          'type': p['type'],
          'note': p['note'],
          'date_transaction': p['dateTransaction'],
          'deleted_at': cu?['deleted_at'],
          'update_at': p['update_at'],
          'server_update_at': _gio(),
        };
      }
      kq.add({'localId': op['localId'], 'status': 'synced'});
    }
    return {'results': kq};
  }

  Map<String, dynamic> xuLyPull(int tk, String since) {
    final s = DateTime.parse(since);
    final nha = thanhVien[tk]?.nha;
    bool trong(Map<String, dynamic> r) =>
        ((r['idaccount'] == tk && r['idhousehold'] == null) || (nha != null && r['idhousehold'] == nha)) &&
        DateTime.parse(r['server_update_at']).isAfter(s);
    final v = vi.values.where(trong).toList();
    final g = gd.values.where(trong).toList();
    g.sort((a, b) => a['server_update_at'].compareTo(b['server_update_at']));
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'pulledAt': now,
      'maxSince': {
        if (v.isNotEmpty) 'wallet': v.last['server_update_at'],
        if (g.isNotEmpty) 'transaction': g.last['server_update_at'],
      },
      'data': {'wallets': v, 'transactions': g, 'categories': [], 'budgets': [], 'bills': [], 'goals': []},
    };
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.server, this.tk);
  final ServerGia server;
  final int tk;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    Map<String, dynamic> than = {};
    if (o.path.contains('/sync/pull')) {
      server.soLanPull++;
      than = {'data': server.xuLyPull(tk, o.queryParameters['since'] as String)};
    } else if (o.path.contains('/sync/push')) {
      server.soLanPush++;
      than = server.xuLyPush(tk, jsonDecode(jsonEncode(o.data))['operations'] as List);
    }
    return ResponseBody.fromString(jsonEncode(than), 200, headers: {
      Headers.contentTypeHeader: ['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}

class _Client implements DioClient {
  _Client(ServerGia s, int tk) {
    dio.httpClientAdapter = _Adapter(s, tk);
  }
  @override
  final Dio dio = Dio();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _NhaGia implements NhaRepository {
  _NhaGia(this.tk, this.hien);
  final int tk;
  NhaCuaToi hien;
  @override
  NhaCuaToi get hienTai => hien;
  @override
  int? get idaccount => tk;
  @override
  Future<bool> lamMoi() async => true;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

NhaCuaToi dangO(int id) => NhaCuaToi(
    nha: NhaEntity(id: id, ten: 'Nhà', trangThai: TrangThaiNha.hoatDong, toiDaThanhVien: 6),
    vai: VaiNha.chu,
    thanhVien: const [],
    nhanLuc: DateTime(2026, 11, 1));

class May {
  May(this.tk, this.server, int? nha, {DateTime Function()? now}) {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    nhaGia = _NhaGia(tk, nha == null ? NhaCuaToi.khongCo(DateTime(2026)) : dangO(nha));
    soDu = SoDuViService(db: db, taiKhoanPhien: () => phien);
    engine = SyncEngine(
      dioClient: _Client(server, tk),
      db: db,
      soDuVi: soDu,
      viBiGiu: ViBiGiuDongBo(db: db),
      connectivity: _Online(),
      now: now,
      nhaPhien: () => nhaGia.hienTai.nha?.id,
      sauKeoVe: (id, _) async {
        await resolver.xuLyNuaNhaBiXoa(id);
        return 0;
      },
    );
    final repo = TransactionRepositoryImpl(
        localDataSource: TransactionLocalDataSourceImpl(db), syncEngine: engine, soDuVi: soDu);
    gop = GopQuyService(giaoDich: repo, db: db, soDuVi: soDu, henDongBo: () {});
    resolver = GopQuyConflictResolver(
        db: db,
        gopQuy: gop,
        nha: nhaGia,
        soDuVi: soDu,
        taiKhoanPhien: () => phien,
        henDongBo: () {},
        xinKeoLai: (id) => engine.keoLaiToanBo(id));
    resolver.batDauNghe(engine.pushResultStream);
    duLieu = DuLieuNhaRepositoryImpl(
        db: db, localDataSource: WalletLocalDataSourceImpl(db: db), soDuVi: soDu, syncEngine: engine);
    dieuPhoi = DieuPhoiDoiNha(
        db: db,
        keoLaiToanBo: (id) async {},
        truocKhiDon: (n, id) => resolver.traVeKhiBoNha(n, id),
        taiKhoanPhien: () => phien);
    phien = tk;
  }
  final int tk;
  final ServerGia server;
  late AppDatabase db;
  late _NhaGia nhaGia;
  late SoDuViService soDu;
  late SyncEngine engine;
  late GopQuyService gop;
  late GopQuyConflictResolver resolver;
  late DuLieuNhaRepositoryImpl duLieu;
  late DieuPhoiDoiNha dieuPhoi;
  int? phien;

  Future<void> dongBo() async {
    await engine.syncMotLuot(tk);
    await Future<void>.delayed(const Duration(milliseconds: 60));
  }

  Future<double?> du(String id) async => (await db.walletDao.getById(id))?.balance;
  Future<int> soThongBao() async => (await db.notificationDao.getAll(tk)).length;
  Future<int> dem(int nha) => db.demHangChuaDayCuaNha(nha);
}

double soDuServer(ServerGia s, String vi) {
  var t = 0.0;
  for (final g in s.gd.values) {
    if (g['idwallet'] == vi && g['deleted_at'] == null) t += (g['amount'] as num).toDouble();
  }
  return t;
}


/// Dựng một hàng chi của nhà [nha] do tài khoản [tk] ghi, còn `pending`, trên ví chung [vc].
Future<String> ghiChiNha(May m, String vc, int nha, {String? id}) async {
  final hang = id ?? const Uuid().v4();
  await m.db.transactionDao.insert(TransactionsCompanion.insert(
      id: hang,
      walletId: vc,
      idaccount: m.tk,
      idhousehold: Value(nha),
      amount: 50000,
      type: 'chi',
      date: DateTime(2026, 11, 1),
      syncStatus: const Value('pending'),
      updatedAt: DateTime(2026, 11, 1)));
  return hang;
}

void main() {
  test('I-1: khoản thường của nhà bị từ chối vĩnh viễn KHÔNG giãn cách cả tài khoản', () async {
    final s = ServerGia();
    s.thanhVien[10] = (nha: 5, vai: 'Viewer');
    var gio = DateTime(2026, 11, 1, 8);
    final m = May(10, s, 5, now: () => gio);
    final vcId = const Uuid().v4();
    final vrId = const Uuid().v4();
    await m.db.walletDao.insert(WalletsCompanion.insert(
        id: vcId,
        idaccount: 20,
        name: 'Quỹ',
        idhousehold: const Value(5),
        syncStatus: const Value('synced'),
        updatedAt: DateTime(2026, 10, 1)));
    await m.db.walletDao.insert(WalletsCompanion.insert(
        id: vrId,
        idaccount: 10,
        name: 'Ví',
        balance: const Value(100),
        syncStatus: const Value('synced'),
        updatedAt: DateTime(2026, 10, 1)));
    final nhaId = await ghiChiNha(m, vcId, 5);
    // Bậc chặn của RIÊNG hàng: 30 s, 1 phút, 5 phút, 15 phút, 60 phút theo `syncRetryCount` của hàng.
    const bac = [30, 60, 300, 900, 3600];
    for (var i = 0; i < 5; i++) {
      await m.dongBo();
      final hang = await m.db.transactionDao.getById(nhaId);
      expect(m.engine.consecutiveFailures, 0,
          reason: 'lượt $i: chỉ có từ chối phạm vi nhà (vai không đủ, không tự hết) — không phải chu kỳ hỏng, không giãn cách '
              'cả tài khoản (I-1)');
      expect(m.engine.nextAllowedSyncAt, isNull, reason: 'lượt $i: không hẹn giờ cho cả tài khoản');
      expect(hang!.syncStatus, 'pending', reason: 'lượt $i: Chủ gia hạn thì hàng tự lên — vẫn pending');
      expect(hang.syncBlockedUntil!.difference(gio).inSeconds, bac[i],
          reason: 'lượt $i: hàng bị gửi lại theo thang của chính nó, không phải mỗi 30 s khi engine thôi giãn cách');
      gio = hang.syncBlockedUntil!.add(const Duration(seconds: 1));
    }
    // Khoản RIÊNG ghi sau cùng lên server ngay trong chu kỳ kế, dù hàng của nhà còn bị chặn 60 phút.
    final riengId = const Uuid().v4();
    await m.db.transactionDao.insert(TransactionsCompanion.insert(
        id: riengId,
        walletId: vrId,
        idaccount: 10,
        amount: 10,
        type: 'chi',
        date: DateTime(2026, 11, 1),
        syncStatus: const Value('pending'),
        updatedAt: DateTime(2026, 11, 1)));
    gio = gio.add(const Duration(minutes: 30));
    await m.dongBo();
    expect(s.gd.containsKey(riengId), isTrue, reason: 'khoản riêng phải lên cùng chu kỳ (trước sửa: kẹt giãn cách 60 phút)');
    m.engine.dispose();
    await m.db.close();
  });

  test('I-1: lượt có cả lỗi khác vẫn tính hỏng như cũ', () async {
    final s = ServerGia();
    s.thanhVien[10] = (nha: 5, vai: 'Viewer');
    final m = May(10, s, 5);
    final vcId = const Uuid().v4();
    final vrId = const Uuid().v4();
    await m.db.walletDao.insert(WalletsCompanion.insert(
        id: vcId,
        idaccount: 20,
        name: 'Quỹ',
        idhousehold: const Value(5),
        syncStatus: const Value('synced'),
        updatedAt: DateTime(2026, 10, 1)));
    await m.db.walletDao.insert(WalletsCompanion.insert(
        id: vrId,
        idaccount: 10,
        name: 'Ví',
        syncStatus: const Value('synced'),
        updatedAt: DateTime(2026, 10, 1)));
    await ghiChiNha(m, vcId, 5);
    final hong = const Uuid().v4();
    s.hongKhac.add(hong);
    await m.db.transactionDao.insert(TransactionsCompanion.insert(
        id: hong,
        walletId: vrId,
        idaccount: 10,
        amount: 10,
        type: 'chi',
        date: DateTime(2026, 11, 1),
        syncStatus: const Value('pending'),
        updatedAt: DateTime(2026, 11, 1)));
    await m.dongBo();
    expect(m.engine.consecutiveFailures, 1,
        reason: 'một lỗi KHÔNG phải từ chối phạm vi nhà trong cùng lô: chu kỳ vẫn tính hỏng, giãn cách như cũ');
    m.engine.dispose();
    await m.db.close();
  });

  test('I-2: Chủ bị hạ xuống Thành viên, xoá hộ khi offline: kéo toàn bộ trả bản server, số dư ví chung khớp', () async {
    final s = ServerGia();
    s.thanhVien[20] = (nha: 5, vai: 'Owner');
    s.thanhVien[10] = (nha: 5, vai: 'Member');
    final o = May(20, s, 5);
    final m = May(10, s, 5);
    final vr = const Uuid().v4();
    await m.db.walletDao.insert(WalletsCompanion.insert(
        id: vr, idaccount: 10, name: 'Ví', balance: const Value(1000000), updatedAt: DateTime(2026, 10, 1)));
    await m.soDu.datNeoNhieuVi({vr});
    final vc = await o.duLieu.taoViChung(
        idNha: 5, idaccount: 20, ten: 'Quỹ', loai: 'cash', soDuBanDau: 500000, icon: 'wallet', mau: '#000000');
    await o.dongBo();
    await m.dongBo();
    final p = await m.gop.gop(
        idNha: 5,
        idaccount: 10,
        viChungId: vc.id,
        tenViChung: 'Quỹ',
        soTien: 200000,
        viRiengId: vr,
        ngay: DateTime(2026, 11, 1));
    await m.dongBo();
    await o.dongBo();
    expect(await o.du(vc.id), 700000, reason: 'tiền đề: hai máy cùng thấy khoản góp 200k');
    // O offline xoá hộ nửa nhà của M; trong lúc đó bị chuyển xuống Thành viên.
    await o.gop.xoa(p);
    s.thanhVien[20] = (nha: 5, vai: 'Member');
    await o.dongBo();
    expect(s.tuChoi.any((x) => x.endsWith('HOUSEHOLD_ROLE_FORBIDDEN')), isTrue, reason: 'tiền đề: lệnh xoá hộ bị từ chối');
    // M sửa khoản góp trên server (đổi đúng hàng ấy).
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await m.gop.sua(maCap: p, soTien: 250000, ngay: DateTime(2026, 11, 2), ghiChu: 'x');
    await m.dongBo();
    // Lượt kéo toàn bộ do resolver xin: O trả về bản server.
    await o.dongBo();
    await o.dongBo();
    final tongServer = soDuServer(s, vc.id);
    expect(tongServer, 750000, reason: 'tiền đề: server cộng 500k mở sổ + 250k góp');
    expect(await o.du(vc.id), tongServer,
        reason: 'O (Chủ cũ) phải thấy đúng quỹ như server; trước sửa: 500.000 vì hàng xoá-hộ pending chặn Pull ghi đè mãi (I-2)');
    expect(await o.dem(5), 0, reason: 'không còn hàng chưa đẩy của nhà: Rời nhà không bị chặn oan');
    expect((await o.db.transactionDao.theoMaCap(p)).where((t) => t.idhousehold != null), hasLength(1),
        reason: 'nửa nhà của M sống lại trên máy O');
    expect(await o.soThongBao(), 0, reason: 'nhánh này không báo người dùng');
    o.engine.dispose();
    m.engine.dispose();
    await o.db.close();
    await m.db.close();
  });

  test('M-1: phép dọn lúc mở phiên, kho đã nói nhà MỚI: nửa nhà CŨ chưa đẩy được trả tiền trước khi bị xoá', () async {
    final s = ServerGia();
    final m = May(10, s, 8);
    await m.db.walletDao.insert(WalletsCompanion.insert(
        id: 'vr', idaccount: 10, name: 'Ví MB', balance: const Value(1000000), updatedAt: DateTime(2026, 10, 1)));
    await m.db.walletDao.insert(WalletsCompanion.insert(
        id: 'vg', idaccount: 30, name: 'Quỹ G', idhousehold: const Value(7), updatedAt: DateTime(2026, 10, 1)));
    final p = await m.gop.gop(
        idNha: 7,
        idaccount: 10,
        viChungId: 'vg',
        tenViChung: 'Quỹ G',
        soTien: 200000,
        viRiengId: 'vr',
        ngay: DateTime(2026, 11, 1));
    expect(await m.du('vr'), 800000, reason: 'tiền đề: 200k đã ra khỏi ví riêng, nửa nhà cũ chưa đẩy');
    final daDon = await donVaTinhLaiViNha(
      nhaGiu: 8,
      idaccount: 10,
      cacNhaConTrenMay: () => m.db.cacNhaConTrenMay(),
      traVeKhiBoNha: (idNha, id) => m.resolver.traVeKhiBoNha(idNha, id),
      don: () => m.db.purgeDataForOtherAccounts(10, nhaGiu: 8),
      tinhLaiViNha: () async {},
    );
    expect(daDon, greaterThan(0), reason: 'tiền đề: phép dọn có xoá hàng nhà cũ');
    expect(await m.du('vr'), 1000000,
        reason: 'tiền về ví riêng: trước sửa, purge xoá nửa nhà cũ còn nửa riêng ở lại → 800.000 mãi, quỹ không nhận (M-1)');
    expect((await m.gop.docCap(p)).rieng, isNull, reason: 'nửa riêng bị gỡ cùng nửa nhà');
    expect(await m.soThongBao(), 1);
    m.engine.dispose();
    await m.db.close();
  });

  test('I-2: Chủ cũ tự sửa ví chung của mình sau khi bị hạ vai: kéo toàn bộ trả bản server, hàng thoát hàng đợi', () async {
    final s = ServerGia();
    s.thanhVien[20] = (nha: 5, vai: 'Owner');
    final o = May(20, s, 5);
    final vc = await o.duLieu.taoViChung(
        idNha: 5, idaccount: 20, ten: 'Quỹ', loai: 'cash', soDuBanDau: 500000, icon: 'wallet', mau: '#000000');
    await o.dongBo();
    s.thanhVien[20] = (nha: 5, vai: 'Member');
    await (o.db.update(o.db.wallets)..where((w) => w.id.equals(vc.id))).write(WalletsCompanion(
        name: const Value('Tên mới offline'), syncStatus: const Value('pending'), updatedAt: Value(DateTime.now())));
    await o.dongBo();
    expect(s.tuChoi.any((x) => x.startsWith('wallet:') && x.endsWith('HOUSEHOLD_ROLE_FORBIDDEN')), isTrue,
        reason: 'tiền đề: sửa ví bị từ chối vì vai');
    await o.dongBo();
    await o.dongBo();
    final v = (await o.db.walletDao.getById(vc.id))!;
    expect(v.name, 'Quỹ', reason: 'bản server thắng: tên cũ trở lại');
    expect(v.isDeleted, isFalse);
    expect(v.syncStatus, 'synced', reason: 'thoát hàng đợi: không bị đẩy lại mãi');
    expect(await o.du(vc.id), 500000);
    o.engine.dispose();
    await o.db.close();
  });
}
