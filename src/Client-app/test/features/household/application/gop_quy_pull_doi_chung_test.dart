/// Ca đầu cuối (vòng sửa 1 của Task 9, ca của người soát): pull KHÔNG được làm sống lại nửa riêng vừa gỡ.
/// Mô phỏng ĐÚNG thứ tự của `SyncEngine._chayMotChuKy`: sendBatch đánh dấu nửa riêng `synced`, phát kết quả, resolver gỡ,
/// RỒI Pull trả lại nửa riêng vừa được server tạo (`server_update_at` > mốc, `sync.repository.js:547`), `upsertAll` ghi đè
/// (`transaction_dao.dart:515`, `is_deleted: false`, `syncStatus: synced`), `tinhLaiNhieuVi`, rồi cổng `sauKeoVe`.
/// Cả hai ca được kỳ vọng ĐỎ trên 16184b8d.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/api/dio_client.dart';
import 'package:flowmoney/core/sync/ap_du_lieu_keo_ve.dart';
import 'package:flowmoney/core/sync/sync_models.dart';
import 'package:flowmoney/features/household/application/gop_quy_conflict_resolver.dart';
import 'package:flowmoney/features/household/application/gop_quy_service.dart';
import 'package:flowmoney/features/household/data/models/nha_cua_toi.dart';
import 'package:flowmoney/features/household/data/repositories/nha_repository.dart';
import 'package:flowmoney/features/household/domain/vai_nha.dart';
import 'package:flowmoney/features/transaction/data/datasources/transaction_local_data_source.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:flowmoney/features/wallet/data/so_du_vi_service.dart';

import '../../transaction/data/repositories/transaction_repository_test.dart' show DummySyncEngine;

class _Client implements DioClient {
  _Client(Map<String, dynamic> pull) {
    dio.httpClientAdapter = _Adapter(pull);
  }
  @override
  final Dio dio = Dio();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.pull);
  final Map<String, dynamic> pull;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async =>
      ResponseBody.fromString(jsonEncode({'data': pull}), 200, headers: {
        Headers.contentTypeHeader: ['application/json']
      });
  @override
  void close({bool force = false}) {}
}

class _NhaGia implements NhaRepository {
  _NhaGia(this.hienTaiGia);
  NhaCuaToi hienTaiGia;
  @override
  NhaCuaToi get hienTai => hienTaiGia;
  @override
  int? get idaccount => 10;
  @override
  Future<bool> lamMoi() async => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

NhaCuaToi _nhaDangO(int id) => NhaCuaToi(
      nha: NhaEntity(id: id, ten: 'Nhà', trangThai: TrangThaiNha.hoatDong, toiDaThanhVien: 6),
      vai: VaiNha.chu,
      thanhVien: const [],
      nhanLuc: DateTime(2026, 11, 1),
    );

void main() {
  late AppDatabase db;
  late GopQuyService gop;
  late SoDuViService soDuVi;
  late _NhaGia nha;
  late GopQuyConflictResolver resolver;
  final ngay = DateTime(2026, 11, 1, 9);
  final moc = DateTime(2026, 10, 1);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    soDuVi = SoDuViService(db: db, taiKhoanPhien: () => 10);
    gop = GopQuyService(
      giaoDich: TransactionRepositoryImpl(
        localDataSource: TransactionLocalDataSourceImpl(db),
        syncEngine: DummySyncEngine(),
        soDuVi: soDuVi,
      ),
      db: db,
      soDuVi: soDuVi,
      henDongBo: () {},
    );
    nha = _NhaGia(_nhaDangO(7));
    resolver = GopQuyConflictResolver(
      db: db,
      gopQuy: gop,
      nha: nha,
      soDuVi: soDuVi,
      taiKhoanPhien: () => 10,
      henDongBo: () {},
    );
    await db.walletDao.insert(WalletsCompanion.insert(
        id: 'vr', idaccount: 10, name: 'Ví MB', balance: const Value(5000000), updatedAt: moc));
    await db.walletDao.insert(WalletsCompanion.insert(
        id: 'vn', idaccount: 10, name: 'Tiền chợ', balance: const Value(1000000), idhousehold: const Value(7), updatedAt: moc));
  });
  tearDown(() => db.close());

  /// Một chu kỳ thật: lô chứa cả hai nửa, nửa riêng được nhận, nửa nhà bị từ chối [ma], rồi Pull, rồi `sauKeoVe`.
  Future<({String id, String maCap})> chuKy(String ma) async {
    final p = await gop.gop(
        idNha: 7, idaccount: 10, viChungId: 'vn', tenViChung: 'Tiền chợ', soTien: 2000000, viRiengId: 'vr', ngay: ngay);
    final cap = await gop.docCap(p);
    final rieng = cap.rieng!;
    final nuaNha = cap.nha!;
    await db.transactionDao.markSynced(rieng.id); // sendBatch: status == synced
    await resolver.xuLy(SyncResult(totalOps: 2, succeeded: 1, failed: 1, failures: [
      SyncOpFailure(
          localId: nuaNha.id, entity: SyncEntityType.transaction, message: 'từ chối', kind: SyncFailureKind.permanent, code: ma),
    ]));
    expect((await gop.docCap(p)).rieng, isNull, reason: 'tiền đề: resolver đã gỡ');
    // Pull: server vừa tạo nửa riêng nên trả nó về, còn sống.
    // Qua ApDuLieuKeoVe THẬT (đã gồm tính lại số dư), không gọi thẳng DAO.
    await ApDuLieuKeoVe(
      dioClient: _Client({
        'transactions': [
          {
            'idtran': rieng.id,
            'idaccount': 10,
            'idwallet': 'vr',
            'amount': -2000000,
            'type': 'Transaction',
            'note': rieng.note,
            'idfund_pair': p,
            'date_transaction': ngay.toUtc().toIso8601String(),
            'update_at': rieng.updatedAt.toUtc().toIso8601String(),
          }
        ],
      }),
      db: db,
      soDuVi: soDuVi,
    ).pullFromBackend(10);
    await resolver.xuLyNuaNhaBiXoa(10); // cổng sauKeoVe
    return (id: rieng.id, maCap: p);
  }

  test('bị mời ra (/me không nhà): sau Pull tiền vẫn phải ở ví riêng, đúng lời thông báo đã báo', () async {
    nha.hienTaiGia = NhaCuaToi.khongCo(DateTime(2026, 11, 1));
    final k = await chuKy('HOUSEHOLD_NOT_MEMBER');
    expect((await db.transactionDao.getById(k.id))!.deletedAt, isNotNull,
        reason: 'Pull không được làm sống lại nửa riêng đã gỡ; đã báo "đã trả tiền về Ví MB"');
    expect((await db.walletDao.getById('vr'))!.balance, 5000000);
  });

  test('nhà chỉ đọc (/me còn nhà 7): một thông báo gopTraVe, KHÔNG có "Chủ nhà đã xoá"', () async {
    final k = await chuKy('HOUSEHOLD_READ_ONLY');
    final khoa = (await db.notificationDao.getAll(10)).map((t) => t.dedupeKey).toList();
    expect(khoa, ['gopTraVe:${k.maCap}'], reason: 'không có Chủ nhà nào xoá; câu "Chủ nhà đã xoá khoản góp" là sai sự thật');
    expect((await db.walletDao.getById('vr'))!.balance, 5000000);
  });
}
