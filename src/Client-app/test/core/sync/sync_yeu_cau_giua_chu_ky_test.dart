/// Một yêu cầu đồng bộ đến **giữa lúc** chu kỳ khác đang chạy thì không được
/// biến mất.
///
/// `_runSync` từ chối chạy chồng bằng `if (_status == SyncStatus.syncing)
/// return;`. Việc không chạy chồng là đúng — nhưng chỉ `return` thì yêu cầu ấy
/// **mất hẳn**, và thay đổi vừa ghi phải nằm chờ một nguồn kích hoạt khác:
/// timer 15 phút, đổi trạng thái mạng, hoặc lần mở app sau.
///
/// Nhánh giãn cách ngay bên dưới trong cùng hàm đã xử lý đúng tình huống song
/// sinh này và ghi rõ lý lẽ: *"Từ chối một yêu cầu đồng bộ nghĩa là NỢ người
/// gọi một lần chạy."* Test này buộc nhánh `syncing` theo cùng lý lẽ ấy.
///
/// Vì sao đáng canh: nguồn kích hoạt dày nhất lại chính là nguồn hay trùng vào
/// lúc đang chạy — `scheduleSync()` sau mỗi lần ghi (debounce 2 giây) và sự
/// kiện `sync.completed` của socket (G34) đánh thức `syncNow()` khi máy khác
/// vừa đẩy xong. Mất một lượt ở đây là dữ liệu hai máy lệch nhau cho tới chu
/// kỳ sau, **im lặng**.
library;

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/api/dio_client.dart';
import 'package:flowmoney/core/database/app_database.dart';
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

class _Client implements DioClient {
  _Client(this.adapter) {
    dio.httpClientAdapter = adapter;
  }
  @override
  final Dio dio = Dio();
  final _ChamAdapter adapter;
}

/// Giữ lượt `/sync/pull` **đầu tiên** treo cho tới khi test gọi [tha], để chu
/// kỳ thứ nhất chắc chắn vẫn đang chạy lúc yêu cầu thứ hai tới.
class _ChamAdapter implements HttpClientAdapter {
  final Completer<void> _cho = Completer<void>();
  int soLanPull = 0;

  void tha() {
    if (!_cho.isCompleted) _cho.complete();
  }

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path.contains('/sync/pull')) {
      soLanPull++;
      if (soLanPull == 1) await _cho.future;
      return ResponseBody.fromString(
        jsonEncode({'data': const <String, dynamic>{}}),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        },
      );
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

/// Chờ [dieuKien] thành true, tối đa 5 giây. Cố ý **không** dùng `pumpAndSettle`
/// hay `FakeAsync`: engine chạy trên timer và Future thật, và test này đo đúng
/// thứ tự giữa hai luồng bất đồng bộ.
Future<void> _doiToiKhi(bool Function() dieuKien, {required String vi}) async {
  final han = DateTime.now().add(const Duration(seconds: 5));
  while (!dieuKien()) {
    if (DateTime.now().isAfter(han)) {
      fail('Hết 5 giây chờ: $vi');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  const accountId = 7;
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('yêu cầu đến giữa chu kỳ đang chạy được NỢ lại và chạy bù, '
      'không bị nuốt', () async {
    final adapter = _ChamAdapter();
    final engine = SyncEngine(
      dioClient: _Client(adapter),
      db: db,
      connectivity: _Online(),
    );
    addTearDown(() {
      adapter.tha(); // đừng để dispose treo vì completer chưa xong
      engine.dispose();
    });

    // KHÔNG await: `start()` kết thúc bằng `await syncNow()`, nên chờ nó là
    // chờ hết cả chu kỳ thứ nhất — đúng cái cửa sổ test này cần đứng bên trong.
    unawaited(engine.start(idaccount: accountId));
    await _doiToiKhi(
      () => adapter.soLanPull == 1,
      vi: 'chu kỳ thứ nhất đi tới /sync/pull',
    );
    expect(
      engine.status,
      SyncStatus.syncing,
      reason: 'Chu kỳ thứ nhất phải đang chạy thì test này mới có nghĩa',
    );

    // Đúng cửa sổ cần canh: người dùng vừa ghi một giao dịch, hoặc socket báo
    // `sync.completed` vì máy khác vừa đẩy xong.
    await engine.syncNow();

    adapter.tha(); // thả cho chu kỳ thứ nhất chạy nốt

    await _doiToiKhi(
      () => adapter.soLanPull >= 2,
      vi: 'chu kỳ thứ hai chạy bù cho yêu cầu bị từ chối',
    );
    expect(
      adapter.soLanPull,
      2,
      reason: 'Nợ đúng MỘT lần chạy bù — không nuốt, cũng không nhân lên',
    );
  });

  test('nhiều yêu cầu dồn vào giữa một chu kỳ chỉ nợ MỘT lần chạy bù', () async {
    final adapter = _ChamAdapter();
    final engine = SyncEngine(
      dioClient: _Client(adapter),
      db: db,
      connectivity: _Online(),
    );
    addTearDown(() {
      adapter.tha();
      engine.dispose();
    });

    // KHÔNG await: `start()` kết thúc bằng `await syncNow()`, nên chờ nó là
    // chờ hết cả chu kỳ thứ nhất — đúng cái cửa sổ test này cần đứng bên trong.
    unawaited(engine.start(idaccount: accountId));
    await _doiToiKhi(
      () => adapter.soLanPull == 1,
      vi: 'chu kỳ thứ nhất đi tới /sync/pull',
    );

    // Ba nguồn cùng đòi đồng bộ trong một cửa sổ — chuyện thường: ghi liên tiếp
    // vài bản ghi, hoặc socket bắn nhiều sự kiện.
    await engine.syncNow();
    await engine.syncNow();
    await engine.syncNow();

    adapter.tha();

    await _doiToiKhi(
      () => adapter.soLanPull >= 2,
      vi: 'lần chạy bù',
    );
    // Cho engine thêm thời gian để lộ ra nếu nó chạy bù nhiều lần.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(
      adapter.soLanPull,
      2,
      reason: 'Ba yêu cầu dồn lại vẫn chỉ là một lần chạy bù — nếu không, mỗi '
          'lượt ghi trong lúc đồng bộ sẽ đẻ thêm một chu kỳ mạng',
    );
  });
}
