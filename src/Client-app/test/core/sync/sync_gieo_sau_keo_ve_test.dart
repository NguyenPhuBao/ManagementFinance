/// Quy tắc 8 `CLAUDE.md` — bộ gieo danh mục mặc định chạy sau **MỌI** lần kéo về thành công (spec
/// `2026-09-07-per-account-default-categories-design.md` mục 5 + đoạn cuối: *"phép đối chiếu chạy sau mọi lần pull"*).
///
/// Tới 2026-10-19 mã chỉ gieo MỘT lần mỗi phiên (`PhienDieuPhoiThat.batDongBo`, sau `start()` khi `hasCompletedPull`):
/// lượt kéo đầu hỏng thì cả phiên không gieo, kể cả khi lượt đồng bộ nền sau đó kéo về được — tài khoản mới thấy màn
/// Danh mục rỗng tới lần mở app sau. Từ 2026-10-20 việc ấy là cổng `SyncEngine.sauKeoVe`, gọi trong `_runSync` ngay
/// sau bước Pull, chỉ khi `soLanKeoVeXong` vừa tăng.
library;

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/api/dio_client.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';
import 'package:flowmoney/core/sync/sync_models.dart';
import 'package:flowmoney/features/category/application/default_category_seeder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/sync_engine_thu.dart';

const acc = 7;
const idMacDinh = 'bbbbbbbb-0000-4000-8000-000000000001';

class _Online implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [ConnectivityResult.wifi];
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Mỗi lượt `/sync/pull` lấy phần tử kế của [keoVe] (hết thì lặp phần tử cuối): `null` = server trả 500 (lượt kéo
/// hỏng — `pullFromBackend` nuốt lỗi), danh sách = các hàng danh mục trả về. Ghi `pull` / `push` vào [nhatKy].
class _Adapter implements HttpClientAdapter {
  _Adapter(this.keoVe, this.nhatKy, {this.khiKeo, this.coVi = false});
  final bool coVi;
  final List<List<Map<String, dynamic>>?> keoVe;
  final List<String> nhatKy;
  final void Function()? khiKeo;
  var _luot = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    const json = {
      Headers.contentTypeHeader: ['application/json']
    };
    if (o.path.contains('/sync/pull')) {
      nhatKy.add('pull');
      khiKeo?.call();
      final lo = keoVe[_luot < keoVe.length ? _luot : keoVe.length - 1];
      _luot++;
      if (lo == null) return ResponseBody.fromString('{}', 500, headers: json);
      return ResponseBody.fromString(jsonEncode({
        'data': {
          'categories': lo,
          if (coVi)
            'wallets': [
              {
                'idwallet': 'cccccccc-0000-4000-8000-000000000001',
                'idaccount': acc,
                'name': 'Ví thử',
                'balance': 0,
                'update_at': '2026-10-01T00:00:00.000Z',
              }
            ],
        }
      }), 200, headers: json);
    }
    nhatKy.add('push');
    final ops = (o.data as Map<String, dynamic>)['operations'] as List<dynamic>;
    return ResponseBody.fromString(
      jsonEncode({
        'status': 'success',
        'results': [
          for (final op in ops) {'localId': op['localId'], 'status': 'synced'}
        ],
      }),
      200,
      headers: json,
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Client implements DioClient {
  _Client(HttpClientAdapter a) {
    dio.httpClientAdapter = a;
  }
  @override
  final Dio dio = Dio();
}

/// Engine thật, chỉ đếm `scheduleSync` (không dựng timer debounce 2 giây).
class _DemHen extends SyncEngine {
  _DemHen({required super.dioClient, required super.db, super.connectivity, super.sauKeoVe})
      : super(soDuVi: congSoDuViThat(db), viBiGiu: congViBiGiuThat(db));
  var hen = 0;
  @override
  void scheduleSync() => hen++;
}

Map<String, dynamic> macDinhServer() => {
      'idcategory': idMacDinh,
      'name_category': 'Ăn uống',
      'classify': 'Chi',
      'is_default': true,
      'update_at': '2026-10-01T00:00:00.000Z',
    };

Map<String, dynamic> khuon({String ten = 'Ăn uống', String? keyword, String? deleteAt, String? icon}) => {
      'idcategory': idMacDinh,
      'name_category': ten,
      'classify': 'Chi',
      'is_default': true,
      if (keyword != null) 'keyword': keyword,
      if (icon != null) 'icon': icon,
      if (deleteAt != null) 'delete_at': deleteAt,
      'update_at': '2026-10-01T00:00:00.000Z',
    };

void main() {
  late AppDatabase db;
  late List<String> nhatKy;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    nhatKy = [];
  });
  tearDown(() => db.close());

  _DemHen dung(
    List<List<Map<String, dynamic>>?> keoVe, {
    ViecSauKeoVe? sauKeoVe,
    void Function()? khiKeo,
    bool coVi = false,
  }) {
    final e = _DemHen(
      dioClient: _Client(_Adapter(keoVe, nhatKy, khiKeo: khiKeo, coVi: coVi)),
      db: db,
      connectivity: _Online(),
      sauKeoVe: sauKeoVe,
    );
    addTearDown(e.dispose);
    return e;
  }

  Future<List<Category>> banSao() async =>
      (await db.categoryDao.getOwnedIncludingDeleted(acc)).where((c) => !c.isDeleted).toList();

  test('⭐ lượt kéo ĐẦU hỏng, lượt sau kéo về được → bản sao danh mục mặc định có ngay ở lượt ấy', () async {
    final seeder = DefaultCategorySeeder(db: db);
    final e = dung([null, [macDinhServer()]], sauKeoVe: (id, _) => seeder.seedForAccount(id));

    await e.start(idaccount: acc);
    expect(await banSao(), isEmpty, reason: 'Lượt kéo hỏng: CSDL cục bộ chưa đáng tin, không tạo gì (G14).');

    await e.syncNow();
    // `forTesting` đã có bộ mặc định cục bộ — bộ gieo sao cả bộ, nên đòi CÓ bản sao của hàng server vừa gửi, không
    // đòi đúng một hàng.
    final ds = await banSao();
    expect(ds.map((c) => c.name), contains('Ăn uống'),
        reason: 'Quy tắc 8: bộ gieo chạy sau MỌI lần kéo về thành công — bản cũ chỉ gieo sau lượt đầu của start(), '
            'nên lượt đầu hỏng là màn Danh mục rỗng tới lần mở app sau.');
    expect(ds.every((c) => !c.isDefault && c.syncStatus == 'pending'), isTrue);
  });

  test('gọi ĐÚNG MỘT lần mỗi lượt kéo về thành công, không gọi khi lượt kéo hỏng', () async {
    var goi = 0;
    final e = dung([[], [], null, []], sauKeoVe: (_, __) async { goi++; return 0; });

    await e.start(idaccount: acc);
    expect(goi, 1);
    await e.syncNow();
    expect(goi, 2);
    await e.syncNow();
    expect(goi, 2, reason: 'Lượt kéo hỏng: `hasCompletedPull` vẫn true từ lượt trước — phải gác theo số lần kéo xong.');
    await e.syncNow();
    expect(goi, 3);
  });

  test('chạy SAU bước Pull trong cùng chu kỳ, nhận idaccount của chu kỳ', () async {
    final e = dung([[]], sauKeoVe: (id, _) async { nhatKy.add('gieo $id'); return 0; });
    await e.start(idaccount: acc);
    expect(nhatKy, ['pull', 'gieo $acc']);
  });

  test('luỹ đẳng qua hai lượt kéo cùng bộ mặc định — một bản sao, chỉ lượt tạo được mới hẹn đẩy', () async {
    final seeder = DefaultCategorySeeder(db: db);
    final ketQua = <int>[];
    final e = dung([[macDinhServer()]], sauKeoVe: (id, _) async {
      final n = await seeder.seedForAccount(id);
      ketQua.add(n);
      return n;
    });

    await e.start(idaccount: acc);
    expect(e.hen, 1, reason: 'Hàng vừa gieo nằm sau bước đẩy của chu kỳ này — phải hẹn đẩy.');
    final sauLuot1 = (await banSao()).length;
    await e.syncNow();

    expect(ketQua.length, 2);
    expect(ketQua.first, greaterThan(0));
    expect(ketQua.last, 0, reason: 'Lượt thứ hai cùng bộ mặc định không được tạo thêm bản nào.');
    expect((await banSao()).length, sauLuot1);
    expect(e.hen, 1, reason: 'Không có hàng mới thì không hẹn thêm chu kỳ.');
  });

  test('việc sau kéo về ném lỗi → chu kỳ vẫn kết thúc idle, lượt kéo sau thử lại', () async {
    var goi = 0;
    final e = dung([[]], sauKeoVe: (_, __) async {
      goi++;
      if (goi == 1) throw StateError('CSDL hỏng giữa chừng');
      return 0;
    });

    await e.start(idaccount: acc);
    expect(e.status, SyncStatus.idle,
        reason: 'Đẩy và kéo đã xong — lỗi của bộ gieo không được biến chu kỳ thành lỗi đồng bộ (giãn cách luỹ tiến).');
    await e.syncNow();
    expect(goi, 2);
  });

  test('phiên đóng giữa lượt kéo → không gọi (stop() đặt lại tài khoản)', () async {
    var goi = 0;
    late _DemHen e;
    e = dung([[]], sauKeoVe: (_, __) async { goi++; return 0; }, khiKeo: () => e.stop());

    await e.start(idaccount: acc);
    expect(goi, 0, reason: 'Gieo cho phiên đã đóng là ghi danh mục vào tài khoản vừa đăng xuất.');
  });

  test('không nối cổng → chu kỳ chạy như cũ', () async {
    final e = dung([[macDinhServer()]]);
    await e.start(idaccount: acc);
    expect(e.status, SyncStatus.idle);
    expect(await banSao(), isEmpty);
  });

  test('⭐ admin đổi tên khuôn → cổng nhận MỘT ThayDoiKhuon (tên cũ → mới, loại cũ); lượt đầu không có', () async {
    final nhan = <List<ThayDoiKhuon>>[];
    final e = dung([[khuon()], [khuon(ten: 'Ăn ngoài')]], sauKeoVe: (_, doi) async {
      nhan.add(doi);
      return 0;
    });
    await e.start(idaccount: acc);
    await e.syncNow();

    expect(nhan.first, isEmpty, reason: 'Máy chưa từng thấy khuôn — không có bản cũ để so (spec mục 7).');
    final d = nhan.last.single;
    expect([d.id, d.tenCu, d.tenMoi, d.loai], [idMacDinh, 'Ăn uống', 'Ăn ngoài', 'chi']);
  });

  test('khuôn về không đổi gì → danh sách rỗng', () async {
    final nhan = <List<ThayDoiKhuon>>[];
    final e = dung([[khuon()], [khuon()]], sauKeoVe: (_, doi) async {
      nhan.add(doi);
      return 0;
    });
    await e.start(idaccount: acc);
    await e.syncNow();
    expect(nhan.last, isEmpty, reason: 'Cùng tên, cùng biểu tượng — không có gì để lan truyền.');
  });

  test('thêm từ khoá ở khuôn → ThayDoiKhuon mang tập cũ / mới', () async {
    final nhan = <List<ThayDoiKhuon>>[];
    final e = dung([[khuon(keyword: 'an uong')], [khuon(keyword: 'an uong, quan an')]], coVi: true, sauKeoVe: (_, doi) async {
      nhan.add(doi);
      return 0;
    });
    await e.start(idaccount: acc);
    await e.syncNow();
    final d = nhan.last.single;
    expect(d.tuKhoaCu, ['an uong'], reason: 'Tập cũ đọc từ máy (lượt có ví → kéo tăng dần).');
    expect(d.tuKhoaMoi, ['an uong', 'quan an']);
  });

  test('khuôn trên máy CHƯA có từ khoá, bản về có → tuKhoaCu rỗng (đọc TRƯỚC khi gieo của chính lượt ấy)', () async {
    final nhan = <List<ThayDoiKhuon>>[];
    final e = dung([[khuon()], [khuon(keyword: 'quan an')]], coVi: true, sauKeoVe: (_, doi) async {
      nhan.add(doi);
      return 0;
    });
    await e.start(idaccount: acc);
    await e.syncNow();
    final d = nhan.last.single;
    expect(d.tuKhoaCu, isEmpty,
        reason: 'Đọc từ khoá cũ SAU gieoTuKhoaKhiTrong là thấy bộ mới — mất thay đổi, không lan truyền từ khoá.');
    expect(d.tuKhoaMoi, ['quan an']);
  });

  test('⭐ khuôn về ở trạng thái ĐÃ XOÁ vẫn lan truyền đổi TÊN (đổi tên rồi xoá giữa hai lượt kéo)', () async {
    final nhan = <List<ThayDoiKhuon>>[];
    final e = dung([[khuon()], [khuon(ten: 'Ăn ngoài', deleteAt: '2026-10-28T00:00:00.000Z')]],
        sauKeoVe: (_, doi) async {
      nhan.add(doi);
      return 0;
    });
    await e.start(idaccount: acc);
    await e.syncNow();
    final d = nhan.last.single;
    expect(d.tenMoi, 'Ăn ngoài',
        reason: 'Bỏ qua khuôn đã xoá thì bản sao "Ăn uống" không khớp khuôn đã xoá nào và vẫn hiện; admin khôi phục là '
            'bộ tạo bản sao mọc thêm bản "Ăn ngoài" (người dùng chốt 2026-10-27).');
    expect(d.tuKhoaCu, d.tuKhoaMoi, reason: 'Khuôn đã xoá không so từ khoá.');
  });

  test('khuôn đã xoá chỉ đổi từ khoá → không ThayDoiKhuon', () async {
    final nhan = <List<ThayDoiKhuon>>[];
    final e = dung([
      [khuon(keyword: 'an uong')],
      [khuon(keyword: 'an uong, quan an', deleteAt: '2026-10-28T00:00:00.000Z')],
    ], coVi: true, sauKeoVe: (_, doi) async {
      nhan.add(doi);
      return 0;
    });
    await e.start(idaccount: acc);
    await e.syncNow();
    expect(nhan.last, isEmpty, reason: 'Từ khoá của khuôn đã xoá không còn gì để thêm vào bản sao.');
  });

  test('lượt kéo TOÀN BỘ (dữ liệu tài khoản bị dọn, khuôn còn trên máy) → không có ThayDoiKhuon từ khoá', () async {
    final nhan = <List<ThayDoiKhuon>>[];
    final e = dung([[khuon(keyword: 'an uong')], [khuon(keyword: 'an uong')]], sauKeoVe: (_, doi) async {
      nhan.add(doi);
      return 0;
    });
    await e.start(idaccount: acc);
    await (db.delete(db.categoryKeywords)..where((t) => t.idaccount.equals(acc))).go(); // mô phỏng purge
    await e.syncNow();
    expect(nhan, hasLength(2), reason: 'Hai lượt kéo — `nhan.last` phải là của lượt SAU purge, không phải lượt đầu.');
    expect(nhan.last, isEmpty,
        reason: 'Đổi tài khoản trên cùng máy: khuôn ở lại, từ khoá của tài khoản bị dọn — so từ khoá sẽ sinh thay đổi giả '
            'và lan truyền lại những từ khoá người dùng đã xoá.');
  });

  test('⭐ máy CÓ ví nhưng chưa có mốc kéo (lượt kéo toàn bộ) → không so từ khoá', () async {
    // Khuôn đã có trên máy kèm từ khoá, và có ví (nên CSDL KHÔNG rỗng) — nhưng `_lastPullTime == null` (chưa có checkpoint)
    // vẫn là lượt KHÔNG CÓ trạng thái cũ (`khongCoTrangThaiCu`): từ khoá lưu theo tài khoản có thể đã bị dọn, so sẽ sinh thay
    // đổi từ khoá giả.
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: idMacDinh,
      idaccount: 0,
      name: 'Ăn uống',
      classify: 'chi',
      icon: const Value('restaurant'), // đúng biểu tượng mặc định theo tên — không sinh thay đổi biểu tượng giả
      isDefault: const Value(true),
      updatedAt: DateTime(2026, 9, 1),
    ));
    await db.categoryDao.replaceKeywords(accountId: acc, categoryId: idMacDinh, keywords: ['an uong'], now: DateTime(2026, 9, 1));
    await db.walletDao.insert(WalletsCompanion.insert(id: 'vi-co-san', idaccount: acc, name: 'Ví có sẵn', updatedAt: DateTime(2026, 9, 1)));
    final nhan = <List<ThayDoiKhuon>>[];
    final e = dung([[khuon(keyword: 'an uong, quan an')]], sauKeoVe: (_, doi) async {
      nhan.add(doi);
      return 0;
    });
    await e.start(idaccount: acc);
    expect(nhan, hasLength(1));
    expect(nhan.single, isEmpty,
        reason: 'Điều kiện `khongCoTrangThaiCu` là `CSDL rỗng || chưa có mốc` — thiếu vế sau thì máy có ví mà mất '
            'checkpoint sinh thay đổi từ khoá giả.');
  });

  test('⭐ admin đổi BIỂU TƯỢNG khuôn → ThayDoiKhuon mang iconCu / iconMoi', () async {
    final nhan = <List<ThayDoiKhuon>>[];
    final e = dung([[khuon(icon: 'fuel')], [khuon(icon: 'gas')]], sauKeoVe: (_, doi) async {
      nhan.add(doi);
      return 0;
    });
    await e.start(idaccount: acc);
    await e.syncNow();
    final d = nhan.last.single;
    expect([d.iconCu, d.iconMoi], ['fuel', 'gas'],
        reason: 'Biểu tượng là một trong ba thứ lan truyền — bỏ qua thì chỉ đổi tên / từ khoá mới tới được bản sao.');
    expect(d.tenCu, d.tenMoi);
  });

  test('lượt kéo toàn bộ vẫn ghi đổi TÊN', () async {
    final nhan = <List<ThayDoiKhuon>>[];
    final e = dung([[khuon(keyword: 'an uong')], [khuon(ten: 'Ăn ngoài', keyword: 'an uong')]],
        sauKeoVe: (_, doi) async {
      nhan.add(doi);
      return 0;
    });
    await e.start(idaccount: acc);
    await e.syncNow();
    expect(nhan, hasLength(2));
    final d = nhan.last.single;
    expect(d.tenMoi, 'Ăn ngoài', reason: 'Hàng khuôn dùng chung cả máy — phép so tên đúng ở mọi lượt.');
    expect(d.tuKhoaCu, d.tuKhoaMoi);
  });
}
