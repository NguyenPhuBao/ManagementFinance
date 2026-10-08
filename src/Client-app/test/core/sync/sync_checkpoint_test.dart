import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/api/dio_client.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_checkpoint_store.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';
import 'package:flowmoney/core/sync/sync_models.dart';

class _Online implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      [ConnectivityResult.wifi];
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeStore implements SyncCheckpointStore {
  final Map<int, DateTime> values = {};

  @override
  Future<DateTime?> read(int idaccount) async => values[idaccount];
  @override
  Future<void> write(int idaccount, DateTime value) async =>
      values[idaccount] = value;
  @override
  Future<void> clear(int idaccount) async => values.remove(idaccount);
}

class _Client implements DioClient {
  _Client() {
    dio.httpClientAdapter = adapter;
  }
  @override
  final Dio dio = Dio();
  final _Adapter adapter = _Adapter();
}

class _Adapter implements HttpClientAdapter {
  Map<String, dynamic> pullData = const {};
  String? lastPullSince;

  /// Phản hồi đúng dạng server từ migration 20: `{pulledAt, maxSince, data}`
  /// nằm trong `data` của `ResponseHandler`. `null` = server cũ (chỉ `pullData`).
  Map<String, dynamic>? pullMoi;

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path.contains('/sync/pull')) {
      lastPullSince = o.queryParameters['since']?.toString();
      return ResponseBody.fromString(
          jsonEncode({'success': true, 'data': pullMoi ?? pullData}), 200,
          headers: {
            Headers.contentTypeHeader: ['application/json']
          });
    }
    if (o.path.contains('/sync/push')) {
      final ops = (o.data as Map<String, dynamic>)['operations'] as List<dynamic>;
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'success',
          'results': ops
              .map((op) => {'localId': op['localId'], 'status': 'synced'})
              .toList(),
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        },
      );
    }
    return ResponseBody.fromString('{}', 404);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const accountId = 7;
  late AppDatabase db;
  late _Client client;
  late _FakeStore store;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    client = _Client();
    store = _FakeStore();
    engine = SyncEngine(
      dioClient: client,
      db: db,
      connectivity: _Online(),
      checkpointStore: store,
    );
  });

  tearDown(() async {
    engine.dispose();
    await db.close();
  });

  Future<void> seedWallet() => db.walletDao.insert(WalletsCompanion(
        id: const Value('11111111-1111-4111-8111-111111111111'),
        idaccount: const Value(accountId),
        name: const Value('Ví'),
        type: const Value('cash'),
        balance: const Value(0),
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime.now()),
      ));

  Future<void> runSync() async {
    final done = engine.statusStream.where((s) => s.isTerminal).first;
    engine.start(idaccount: accountId);
    await done.timeout(const Duration(seconds: 5));
  }

  // ── Mốc pull ở TƯƠNG LAI (2026-09-05) ────────────────────────────────────
  //
  // Đo được trên máy ảo Android. Log của app: `Pulling ... since
  // 2026-11-10T08:12:38Z` trong khi hôm ấy mới là 05/09. Mốc lấy theo `update_at`
  // LỚN NHẤT trong payload, nên chỉ cần MỘT hàng mang dấu thời gian tương lai là
  // mốc bị đẩy vọt lên — và vì mốc chỉ tiến chứ không lùi, tài khoản ấy **không
  // nhận được bất cứ dữ liệu mới nào** cho tới khi thời gian thật đuổi kịp.
  //
  // Trên máy ảo là 15 hàng của một tài khoản, xa nhất 10/11/2026: đồng bộ chiều
  // kéo về chết hai tháng mà không có lỗi nào báo ra.
  //
  // Chữa ở hai đầu: KHÔNG ghi mốc vượt quá hiện tại, và mốc ĐÃ LƯU mà ở tương
  // lai thì coi như không có — máy đang kẹt tự thoát ra ở lần mở app kế tiếp.

  group('Mốc pull không bao giờ được vượt quá hiện tại', () {
    test('payload có một hàng mốc tương lai thì mốc lưu bị kẹp về hiện tại',
        () async {
      await seedWallet();
      final truoc = DateTime.now().toUtc();
      client.adapter.pullData = {
        'wallets': [
          {
            'idwallet': '99999999-9999-4999-8999-999999999999',
            'idaccount': accountId,
            'name': 'Ví thật',
            'balance': 0,
            'update_at': '2026-09-01T10:00:00.000Z',
          },
          {
            'idwallet': '88888888-8888-4888-8888-888888888888',
            'idaccount': accountId,
            'name': 'Ví có dấu thời gian hỏng',
            'balance': 0,
            'update_at': '2027-11-10T08:12:38.000Z',
          },
        ],
      };

      await runSync();

      final moc = store.values[accountId]!;
      expect(moc.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 1))),
          isFalse,
          reason: 'Ghi thẳng mốc 2027 vào là tự khoá chiều kéo về suốt hơn một '
              'năm, và không có lỗi nào báo ra.');
      expect(moc.isBefore(truoc.subtract(const Duration(minutes: 1))), isFalse,
          reason: 'Kẹp về HIỆN TẠI chứ không phải vứt bỏ: dữ liệu vừa nhận đã '
              'là tất cả những gì server có, nên hỏi lại từ mốc cũ chỉ tốn công.');
    });

    test('mốc đã lưu ở tương lai thì bị bỏ, pull quay về kéo toàn bộ', () async {
      await seedWallet(); // CSDL cục bộ KHÔNG rỗng — không có đường ép full pull nào khác
      store.values[accountId] = DateTime.utc(2027, 11, 10, 8, 12, 38);
      client.adapter.pullData = const {};

      await runSync();

      expect(client.adapter.lastPullSince, '1970-01-01T00:00:00.000Z',
          reason: 'Máy đã dính mốc hỏng phải tự thoát ra được. Chỉ chặn ở đầu '
              'GHI thì những máy đang kẹt vẫn kẹt cho tới khi thời gian thật '
              'đuổi kịp — trên máy ảo là hai tháng.');
    });

    test('mốc đã lưu hợp lệ thì vẫn dùng như cũ', () async {
      await seedWallet();
      store.values[accountId] = DateTime.utc(2026, 9, 1, 10);
      client.adapter.pullData = const {};

      await runSync();

      expect(client.adapter.lastPullSince, '2026-09-01T10:00:00.000Z',
          reason: 'Phép kiểm chỉ được đụng tới mốc ở TƯƠNG LAI. Ép full pull '
              'nhầm là kéo lại toàn bộ dữ liệu ở mỗi lần mở app.');
    });
  });

  test('Mốc đồng bộ được lưu lại bền vững sau khi pull', () async {
    await seedWallet();
    client.adapter.pullData = {
      'wallets': [
        {
          'idwallet': '99999999-9999-4999-8999-999999999999',
          'idaccount': accountId,
          'name': 'Ví ngân hàng',
          'balance': 0,
          'update_at': '2026-09-01T10:00:00.000Z',
        },
      ],
    };

    await runSync();

    expect(store.values[accountId], isNotNull);
  });

  test(
      'Mốc lấy theo update_at LỚN NHẤT trong dữ liệu, không phải giờ của client',
      () async {
    await seedWallet();
    client.adapter.pullData = {
      'wallets': [
        {
          'idwallet': '99999999-9999-4999-8999-999999999999',
          'idaccount': accountId,
          'name': 'Ví A',
          'balance': 0,
          'update_at': '2026-09-01T10:00:00.000Z',
        },
        {
          'idwallet': '88888888-8888-4888-8888-888888888888',
          'idaccount': accountId,
          'name': 'Ví B',
          'balance': 0,
          'update_at': '2026-09-01T12:30:00.000Z',
        },
      ],
    };

    await runSync();

    expect(store.values[accountId], DateTime.utc(2026, 9, 1, 12, 30));
  });

  test('Lần mở app sau dùng lại mốc đã lưu thay vì kéo lại từ 1970', () async {
    await seedWallet();
    store.values[accountId] = DateTime.utc(2026, 8, 20, 8);

    await runSync();

    expect(client.adapter.lastPullSince, '2026-08-20T08:00:00.000Z');
  });

  test('SQLite cục bộ rỗng thì vẫn full pull dù đã có mốc lưu sẵn', () async {
    // Không seed ví nào → isLocalDbEmpty = true (mô phỏng cài lại app).
    store.values[accountId] = DateTime.utc(2026, 8, 20, 8);

    await runSync();

    expect(client.adapter.lastPullSince, '1970-01-01T00:00:00.000Z');
  });

  test('Không nhận được bản ghi nào thì giữ nguyên mốc cũ', () async {
    await seedWallet();
    store.values[accountId] = DateTime.utc(2026, 8, 20, 8);
    client.adapter.pullData = const {};

    await runSync();

    expect(store.values[accountId], DateTime.utc(2026, 8, 20, 8));
  });

  // ── G67 — mốc theo giờ-server `maxSince` (2026-10-08) ────────────────────
  //
  // Đo được trong nghiệm thu G63: máy B ghi hai giao dịch lúc offline (14:43),
  // máy A kéo về lúc 14:44; hai giao dịch lên server lúc 14:45 nhưng mang GIỜ GHI
  // 14:43 → A không bao giờ nhận. Mốc phải theo giờ server nhận bản ghi.
  group('G67 — mốc lấy từ maxSince của server', () {
    Map<String, dynamic> viMoi(String updateAt) => {
          'idwallet': '99999999-9999-4999-8999-999999999999',
          'idaccount': accountId,
          'name': 'Ví từ máy B',
          'balance': 0,
          'update_at': updateAt,
        };

    test('⭐ hàng mang update_at MỚI hơn giờ-server: mốc theo giờ-server', () async {
      await seedWallet();
      client.adapter.pullMoi = {
        'pulledAt': '2026-10-08T07:50:00.000Z',
        'maxSince': {'wallet': '2026-10-08T07:45:32.000Z'},
        'data': {
          'wallets': [viMoi('2026-10-08T07:46:00.000Z')],
        },
      };

      await runSync();

      expect(store.values[accountId], DateTime.utc(2026, 10, 8, 7, 45, 32, 1),
          reason: 'Giờ ghi của máy (update_at) không nói gì về lúc server nhận. '
              'Lấy 07:46 là bỏ sót mọi bản ghi server nhận trong (07:45:32, 07:46] '
              'mà giờ ghi cũ hơn — đúng G67.');
    });

    test('⭐ hàng mang update_at CŨ hơn giờ-server: mốc vẫn theo giờ-server', () async {
      await seedWallet();
      client.adapter.pullMoi = {
        'pulledAt': '2026-10-08T07:50:00.000Z',
        'maxSince': {'wallet': '2026-10-08T07:45:32.000Z'},
        'data': {
          'wallets': [viMoi('2026-10-08T07:43:31.000Z')],
        },
      };

      await runSync();

      expect(store.values[accountId], DateTime.utc(2026, 10, 8, 7, 45, 32, 1),
          reason: 'Mốc 07:43:31 không sai dữ liệu nhưng kéo lại thừa; điều quan '
              'trọng là hai đường cho cùng một mốc theo server.');
    });

    test('maxSince rỗng (không bảng nào có hàng) → giữ nguyên mốc cũ', () async {
      await seedWallet();
      store.values[accountId] = DateTime.utc(2026, 10, 8, 7);
      client.adapter.pullMoi = {
        'pulledAt': '2026-10-08T07:50:00.000Z',
        'maxSince': <String, dynamic>{},
        'data': <String, dynamic>{},
      };

      await runSync();

      expect(store.values[accountId], DateTime.utc(2026, 10, 8, 7));
    });

    test('lượt kéo sau gửi đúng mốc theo giờ-server', () async {
      await seedWallet();
      client.adapter.pullMoi = {
        'pulledAt': '2026-10-08T07:50:00.000Z',
        'maxSince': {
          'wallet': '2026-10-08T07:40:00.000Z',
          'transaction': '2026-10-08T07:45:00.000Z',
        },
        'data': {
          'wallets': [viMoi('2026-10-08T07:49:00.000Z')],
        },
      };
      await runSync();
      engine.stop();

      client.adapter.pullMoi = {
        'pulledAt': '2026-10-08T07:55:00.000Z',
        'maxSince': <String, dynamic>{},
        'data': <String, dynamic>{},
      };
      await runSync();

      expect(client.adapter.lastPullSince, '2026-10-08T07:45:00.001Z',
          reason: 'Lớn nhất giữa các bảng theo GIỜ-SERVER (07:45), không phải '
              'update_at của hàng (07:49 — giờ ghi của máy).');
    });
  });
}
