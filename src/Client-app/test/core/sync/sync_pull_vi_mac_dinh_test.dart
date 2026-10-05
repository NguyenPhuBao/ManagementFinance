/// G63 — kéo về xong, ví mặc định server gửi xuống là ví mặc định DUY NHẤT trên máy (spec mục 4.6; người dùng chốt
/// "bản server thắng" 2026-10-05). Realme 2026-10-03 từng mang HAI ví mặc định: cờ của ví máy này + cờ "Tiền mặt"
/// kéo về — `upsertAll` ghi đúng hàng kéo về nhưng không đụng hàng chỉ có trên máy.
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
import 'package:flutter_test/flutter_test.dart';

const acc = 7;
const idP = 'aaaaaaaa-0000-4000-8000-000000000001';
const idR = 'aaaaaaaa-0000-4000-8000-000000000002';

class _Online implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [ConnectivityResult.wifi];
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.viKeoVe);
  final List<Map<String, dynamic>> viKeoVe;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    const json = {
      Headers.contentTypeHeader: ['application/json']
    };
    if (o.path.contains('/sync/pull')) {
      return ResponseBody.fromString(jsonEncode({'data': {'wallets': viKeoVe}}), 200, headers: json);
    }
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

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // R: ví mặc định của máy này, đã đồng bộ (để không bị đẩy trong chu kỳ thử).
    await db.walletDao.insert(WalletsCompanion.insert(
      id: idR,
      idaccount: acc,
      name: 'Ví MB Bank',
      isDefault: const Value(true),
      syncStatus: const Value('synced'),
      updatedAt: DateTime(2026, 10, 5),
    ));
  });
  tearDown(() => db.close());

  Map<String, dynamic> viServer({bool macDinh = true, String? xoaLuc}) => {
        'idwallet': idP,
        'idaccount': acc,
        'name': 'Tiền mặt',
        'type': 'Cash',
        'is_default': macDinh,
        if (xoaLuc != null) 'delete_at': xoaLuc,
        'update_at': DateTime.now().toIso8601String(),
      };

  Future<void> chay(List<Map<String, dynamic>> viKeoVe) async {
    final engine = SyncEngine(dioClient: _Client(_Adapter(viKeoVe)), db: db, connectivity: _Online());
    final xong = engine.statusStream.where((s) => s.isTerminal).first;
    unawaited(engine.start(idaccount: acc));
    await xong.timeout(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    engine.dispose();
  }

  test('⭐ lô kéo về có ví mặc định → máy chỉ còn MỘT ví mặc định, cờ bỏ đi lên được server', () async {
    await chay([viServer()]);

    final r = (await db.walletDao.getById(idR))!;
    expect((await db.walletDao.getById(idP))!.isDefault, isTrue);
    expect(r.isDefault, isFalse);
    expect(r.syncStatus, 'pending', reason: 'Cờ bỏ đi phải được đẩy, nếu không máy kia vẫn thấy hai ví mặc định.');
  });

  test('⭐ lô kéo về KHÔNG có ví mặc định → cờ cục bộ giữ nguyên (bẫy 8)', () async {
    await chay([viServer(macDinh: false)]);
    expect((await db.walletDao.getById(idR))!.isDefault, isTrue,
        reason: 'Pull là tăng dần: "không thấy" không có nghĩa "server không có".');
  });

  test('ví mặc định trong lô mà đã XOÁ → không tính', () async {
    await chay([viServer(xoaLuc: '2026-10-05T00:00:00.000Z')]);
    expect((await db.walletDao.getById(idR))!.isDefault, isTrue);
  });
}
