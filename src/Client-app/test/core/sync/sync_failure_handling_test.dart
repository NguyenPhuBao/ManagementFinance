/// Kiểm chứng việc phân loại lỗi đẩy dữ liệu.
///
/// Trước đây mọi thất bại đều như nhau: bản ghi giữ `pending` và được gửi lại
/// mỗi chu kỳ, kể cả khi thử lại chắc chắn vô ích. Với lỗi vỡ khoá ngoại
/// `fk_*_account` (tài khoản không còn tồn tại), vòng lặp đó chạy mãi mà người
/// dùng không hề được báo.
library;

import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
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
  final _FailingAdapter adapter;
}

/// Trả về lỗi [failureMessage] cho MỌI thao tác được đẩy lên, và đếm số lần
/// endpoint /sync/push được gọi.
class _FailingAdapter implements HttpClientAdapter {
  _FailingAdapter(this.failureMessage);

  final String failureMessage;
  int pushCallCount = 0;

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path.contains('/sync/push')) {
      pushCallCount++;
      final ops =
          (o.data as Map<String, dynamic>)['operations'] as List<dynamic>;
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'success',
          'results': ops
              .map((op) => {
                    'localId': op['localId'],
                    'status': 'error',
                    'message': failureMessage,
                  })
              .toList(),
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        },
      );
    }
    return ResponseBody.fromString(jsonEncode({'data': const {}}), 200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

class _Run {
  _Run({
    required this.adapter,
    required this.sessionInvalid,
    required this.finalStatus,
  });
  final _FailingAdapter adapter;
  final bool sessionInvalid;
  final SyncStatus finalStatus;
}

void main() {
  const accountId = 9; // tài khoản đã bị xoá khỏi server
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  /// Tạo một danh mục đang chờ đồng bộ để chắc chắn có gì đó để đẩy lên.
  Future<void> seedPendingCategory() => db.categoryDao.insert(
        CategoriesCompanion.insert(
          id: 'fee25499-c4a9-4924-b69b-43081c563d95',
          idaccount: accountId,
          name: 'Danh mục mới',
          classify: 'chi',
          syncStatus: const Value('pending'),
          updatedAt: DateTime(2026, 9, 2),
        ),
      );

  Future<_Run> runWith(String message) async {
    final adapter = _FailingAdapter(message);
    final engine = SyncEngine(
      dioClient: _Client(adapter),
      db: db,
      connectivity: _Online(),
    );
    var signalled = false;
    final sub = engine.sessionInvalidStream.listen((_) => signalled = true);
    final done =
        engine.statusStream.where((s) => s.isTerminal).first;
    await engine.start(idaccount: accountId);
    await done.timeout(const Duration(seconds: 5));
    final finalStatus = engine.status;
    await sub.cancel();
    engine.dispose();
    return _Run(
      adapter: adapter,
      sessionInvalid: signalled,
      finalStatus: finalStatus,
    );
  }

  test(
      'Vỡ khoá ngoại fk_*_account → phát tín hiệu phiên chết và KHÔNG thử lại',
      () async {
    await seedPendingCategory();

    final r = await runWith(
      'Invalid `prisma.category.create()` invocation\n'
      'Foreign key constraint violated on the constraint: `fk_category_account`',
    );

    expect(r.sessionInvalid, true,
        reason: 'Phải báo ra ngoài để AuthBloc xử lý, thay vì lặp im lặng');
    expect(r.adapter.pushCallCount, 1,
        reason: 'Trước đây điều kiện retry chỉ là `failed > 0` nên lỗi vĩnh '
            'viễn cũng bị gửi lại, nhân đôi số request hỏng mỗi chu kỳ');
  });

  test('Khoá ngoại KHÁC (fk_transaction_category) vẫn được thử lại', () async {
    await seedPendingCategory();

    final r = await runWith(
      'Foreign key constraint violated on the constraint: '
      '`fk_transaction_category`',
    );

    expect(r.sessionInvalid, false,
        reason: 'Đây chỉ là sai thứ tự đẩy, không phải phiên chết');
    expect(r.adapter.pushCallCount, 2,
        reason: 'Pull xong mới có UUID danh mục từ backend nên đáng thử lại');
  });

  test('Ownership mismatch KHÔNG bị coi là phiên chết', () async {
    await seedPendingCategory();

    final r = await runWith(
      'Ownership mismatch: payload.idaccount does not match token',
    );

    expect(r.sessionInvalid, false,
        reason: 'Đó là dòng dữ liệu sót của tài khoản khác — cần dọn dữ liệu, '
            'đăng xuất người dùng ở đây là sai');
    expect(r.adapter.pushCallCount, 1, reason: 'Lỗi vĩnh viễn → không thử lại');
  });

  test(
      'Chu kỳ mà mọi thao tác đẩy đều hỏng KHÔNG được kết thúc ở trạng thái idle',
      () async {
    await seedPendingCategory();

    final r = await runWith(
      'Ownership mismatch: payload.idaccount does not match token',
    );

    expect(
      r.finalStatus,
      SyncStatus.error,
      reason: 'Canh chừng G1: trước đây _runSync() luôn kết thúc bằng '
          '_setStatus(SyncStatus.idle) bất kể kết quả, nên SyncStatus.error '
          'gần như là mã chết — _sendBatch không ném lỗi ra ngoài nên khối '
          'catch không bao giờ chạm tới. Giao diện báo "đã đồng bộ xong" '
          'trong khi không một bản ghi nào lên được server.',
    );
  });

  test('Phiên chết kết thúc ở authExpired, phân biệt được với lỗi thường',
      () async {
    await seedPendingCategory();

    final r = await runWith(
      'Foreign key constraint violated on the constraint: `fk_category_account`',
    );

    expect(
      r.finalStatus,
      SyncStatus.authExpired,
      reason: 'Phiên chết không phải lỗi "sẽ thử lại": đồng bộ đã dừng hẳn và '
          'chỉ đăng nhập lại mới cứu được. Gộp chung vào error sẽ khiến giao '
          'diện hứa một lần thử lại không bao giờ xảy ra.',
    );
  });

  test('Chu kỳ thành công vẫn kết thúc ở idle', () async {
    // Không seed gì → không có thao tác nào để đẩy, pull rỗng.
    final r = await runWith('không dùng tới');

    expect(r.finalStatus, SyncStatus.idle);
    expect(r.adapter.pushCallCount, 0);
  });

  test(
      'Thao tác bị conflict (bản server mới hơn) KHÔNG được đẩy lại ở chu kỳ sau',
      () async {
    await seedPendingCategory();

    final adapter = _ConflictAdapter();
    final engine = SyncEngine(
      dioClient: _ConflictClient(adapter),
      db: db,
      connectivity: _Online(),
    );
    addTearDown(engine.dispose);

    Future<void> runCycle() async {
      final done = engine.statusStream.where((s) => s.isTerminal).first;
      await engine.syncNow();
      await done.timeout(const Duration(seconds: 5));
    }

    await engine.start(idaccount: accountId);
    final pushesAfterFirst = adapter.pushCallCount;

    final row = await db.categoryDao
        .getById('fee25499-c4a9-4924-b69b-43081c563d95');
    expect(
      row?.syncStatus,
      'synced',
      reason: 'Canh chừng G9: conflict nghĩa là LWW đã phân xử và server '
          'thắng. Để bản ghi ở pending thì nó được đẩy lại mỗi chu kỳ và lại '
          'thua đúng như vậy — không có gì thay đổi, chỉ tốn request.',
    );

    await runCycle();

    expect(
      adapter.pushCallCount,
      pushesAfterFirst,
      reason: 'Chu kỳ sau không được gửi lại thao tác đã bị conflict.',
    );
  });

  group('Giãn cách luỹ tiến sau các chu kỳ hỏng (G2)', () {
    /// Đồng hồ tự điều khiển — để khỏi phải chờ thật 30 giây trong test.
    late DateTime clock;
    DateTime now() => clock;

    setUp(() => clock = DateTime(2026, 9, 3, 8, 0, 0));

    Future<SyncEngine> failingEngine(_FailingAdapter adapter) async {
      final engine = SyncEngine(
        dioClient: _Client(adapter),
        db: db,
        connectivity: _Online(),
        now: now,
      );
      addTearDown(engine.dispose);
      final done = engine.statusStream.where((s) => s.isTerminal).first;
      await engine.start(idaccount: accountId);
      await done.timeout(const Duration(seconds: 5));
      return engine;
    }

    test('Chu kỳ hỏng chặn chu kỳ kế tiếp cho tới khi hết giãn cách', () async {
      await seedPendingCategory();
      final adapter =
          _FailingAdapter('Ownership mismatch: payload.idaccount does not match token');
      final engine = await failingEngine(adapter);

      expect(engine.consecutiveFailures, 1);
      expect(engine.nextAllowedSyncAt, clock.add(const Duration(seconds: 30)));

      final pushesAfterFirst = adapter.pushCallCount;
      await engine.syncNow(); // ngay lập tức, vẫn trong giãn cách

      expect(
        adapter.pushCallCount,
        pushesAfterFirst,
        reason: 'Canh chừng G2: không có giãn cách thì mỗi lần ghi dữ liệu '
            '(debounce 2 giây), mỗi lần đổi mạng và mỗi timer 15 phút đều bắn '
            'lại đúng batch hỏng đó — server đang sự cố nhận nguyên lượng '
            'request lặp vô hạn.',
      );
      expect(engine.status, SyncStatus.pending);
    });

    test('Hết giãn cách thì thử lại, và lần hỏng sau giãn xa hơn', () async {
      await seedPendingCategory();
      final adapter =
          _FailingAdapter('Ownership mismatch: payload.idaccount does not match token');
      final engine = await failingEngine(adapter);
      final pushesAfterFirst = adapter.pushCallCount;

      clock = clock.add(const Duration(seconds: 31));
      final done = engine.statusStream.where((s) => s.isTerminal).first;
      await engine.syncNow();
      await done.timeout(const Duration(seconds: 5));

      expect(adapter.pushCallCount, greaterThan(pushesAfterFirst));
      expect(engine.consecutiveFailures, 2);
      expect(
        engine.nextAllowedSyncAt,
        clock.add(const Duration(minutes: 1)),
        reason: 'Bậc giãn cách phải nới ra: 30 giây → 1 phút → 5 phút → '
            '15 phút → 60 phút.',
      );
    });

    test('Một chu kỳ thành công xoá sạch giãn cách', () async {
      // Không seed gì → không có thao tác nào để đẩy → chu kỳ sạch.
      final adapter = _FailingAdapter('không dùng tới');
      final engine = await failingEngine(adapter);

      expect(engine.consecutiveFailures, 0);
      expect(engine.nextAllowedSyncAt, isNull);
    });

    test('Đăng nhập lại xoá giãn cách của phiên trước', () async {
      await seedPendingCategory();
      final adapter =
          _FailingAdapter('Ownership mismatch: payload.idaccount does not match token');
      final engine = await failingEngine(adapter);
      expect(engine.nextAllowedSyncAt, isNotNull);

      engine.stop();

      expect(
        engine.nextAllowedSyncAt,
        isNull,
        reason: 'Người dùng đăng xuất rồi đăng nhập lại là hành động chủ '
            'động — bắt họ ngồi chờ hết một chu kỳ backoff cũ là sai.',
      );
    });

    // ── Kích hoạt bị chặn phải được hẹn lại ─────────────────────────────────
    //
    // Đo được trên app thật ngày 2026-09-04: xoá một ngân sách trong lúc engine
    // đang giãn cách thì thao tác đó KHÔNG lên tới backend, kể cả sau khi hết
    // giãn cách — phải chờ tới lần mở app sau. Người dùng thấy mục biến mất
    // ngay nên tin là đã xong, còn máy khác thì vẫn thấy nó nguyên vẹn.
    //
    // Nguyên nhân: nhánh chặn chỉ `return`, không hẹn lại. Các nguồn kích hoạt
    // còn lại đều thưa hoặc ngẫu nhiên (timer 15 phút, đổi mạng, mở app), nên
    // khoảng chờ thật dài hơn bậc giãn cách rất nhiều.

    test('Kích hoạt bị chặn vì giãn cách phải được hẹn lại, không bị bỏ rơi',
        () async {
      await seedPendingCategory();
      final adapter = _FailingAdapter(
          'Ownership mismatch: payload.idaccount does not match token');
      final engine = await failingEngine(adapter);

      expect(engine.backoffRetryAt, isNull,
          reason: 'Chưa có kích hoạt nào bị chặn thì chưa nợ ai lần chạy nào.');

      await engine.syncNow(); // bị chặn vì đang trong giãn cách

      expect(
        engine.backoffRetryAt,
        engine.nextAllowedSyncAt,
        reason: 'Engine vừa từ chối một yêu cầu đồng bộ, nên nó NỢ người gọi '
            'một lần chạy. Không hẹn lại thì thay đổi vừa ghi nằm chờ một '
            'nguồn kích hoạt khác — có thể tới 15 phút, hoặc tới lần mở app '
            'sau.',
      );
    });

    test('Hết giãn cách thì hẹn giờ tự nổ và đẩy lại, không cần ai kích hoạt',
        () async {
      await seedPendingCategory();
      final adapter = _FailingAdapter(
          'Ownership mismatch: payload.idaccount does not match token');
      final engine = await failingEngine(adapter);
      final pushesTruoc = adapter.pushCallCount;

      // Đẩy đồng hồ tới sát mốc hết giãn cách để hẹn giờ chỉ còn ~150ms thật —
      // test không phải chờ đủ 30 giây.
      clock = clock
          .add(const Duration(seconds: 30) - const Duration(milliseconds: 150));
      await engine.syncNow();
      expect(engine.backoffRetryAt, isNotNull);
      expect(adapter.pushCallCount, pushesTruoc,
          reason: 'Vẫn còn trong giãn cách nên chưa được gửi gì.');

      // Tới lúc hẹn giờ nổ thì đồng hồ đã qua mốc.
      clock = clock.add(const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(adapter.pushCallCount, greaterThan(pushesTruoc),
          reason: 'Hẹn giờ phải tự chạy lại chu kỳ. Chỉ ghi nhớ mốc mà không '
              'có gì đánh thức thì cũng như không hẹn.');
    });

    test('Nhiều kích hoạt bị chặn liên tiếp dùng chung một hẹn giờ', () async {
      await seedPendingCategory();
      final adapter = _FailingAdapter(
          'Ownership mismatch: payload.idaccount does not match token');
      final engine = await failingEngine(adapter);

      await engine.syncNow();
      final hen1 = engine.backoffRetryAt;
      await engine.syncNow();
      await engine.syncNow();

      expect(engine.backoffRetryAt, hen1,
          reason: 'Mỗi lần ghi dữ liệu đều gọi scheduleSync. Dựng hẹn giờ mới '
              'cho từng lần sẽ đẩy mốc chạy lại lùi mãi về sau.');
    });

    test('stop() huỷ luôn hẹn giờ đang chờ', () async {
      await seedPendingCategory();
      final adapter = _FailingAdapter(
          'Ownership mismatch: payload.idaccount does not match token');
      final engine = await failingEngine(adapter);
      await engine.syncNow();
      expect(engine.backoffRetryAt, isNotNull);

      engine.stop();

      expect(engine.backoffRetryAt, isNull,
          reason: 'Sau đăng xuất, một hẹn giờ còn sống sẽ chạy đồng bộ cho tài '
              'khoản vừa thoát.');
    });
  });

  group('Trạng thái thất bại theo từng bản ghi (G3)', () {
    const catId = 'fee25499-c4a9-4924-b69b-43081c563d95';
    late DateTime clock;
    DateTime now() => clock;

    setUp(() => clock = DateTime(2026, 9, 3, 8, 0, 0));

    Future<SyncEngine> runOnce(HttpClientAdapter adapter) async {
      final engine = SyncEngine(
        dioClient: _AdapterClient(adapter),
        db: db,
        connectivity: _Online(),
        now: now,
      );
      addTearDown(engine.dispose);
      final done = engine.statusStream.where((s) => s.isTerminal).first;
      await engine.start(idaccount: accountId);
      await done.timeout(const Duration(seconds: 5));
      return engine;
    }

    test('Lỗi vĩnh viễn ghi lại dấu vết và chặn bản ghi theo thời gian',
        () async {
      await seedPendingCategory();

      await runOnce(_FailingAdapter(
          'Ownership mismatch: payload.idaccount does not match token'));

      final row = await db.categoryDao.getById(catId);
      expect(row?.syncStatus, 'pending',
          reason: 'Vẫn phải là pending: chặn theo thời gian chứ không loại '
              'vĩnh viễn khỏi hàng đợi.');
      expect(row?.syncRetryCount, 1);
      expect(row?.syncError, contains('Ownership mismatch'));
      expect(
        row?.syncBlockedUntil,
        clock.add(const Duration(seconds: 30)),
        reason: 'Canh chừng G3: trước đây lược đồ không có chỗ nào ghi trạng '
            'thái thất bại, nên một bản ghi hỏng vĩnh viễn nằm ở pending MÃI '
            'MÃI và được gửi lại ở mọi chu kỳ.',
      );
    });

    test('Bản ghi đang bị chặn KHÔNG được gom vào batch', () async {
      await seedPendingCategory();
      await db.categoryDao.markSyncBlocked(
        catId,
        clock.add(const Duration(hours: 1)),
        'hỏng từ chu kỳ trước',
      );

      final adapter = _FailingAdapter('không nên được gọi tới');
      await runOnce(adapter);

      expect(
        adapter.pushCallCount,
        0,
        reason: 'Còn trong thời gian chặn thì không được gửi lại — đó chính '
            'là mục đích của cột syncBlockedUntil.',
      );
    });

    test('Hết hạn chặn thì bản ghi tự quay lại hàng đợi', () async {
      await seedPendingCategory();
      await db.categoryDao.markSyncBlocked(
        catId,
        clock.add(const Duration(minutes: 5)),
        'hỏng từ chu kỳ trước',
      );

      clock = clock.add(const Duration(minutes: 6));
      final adapter = _FailingAdapter(
          'Ownership mismatch: payload.idaccount does not match token');
      await runOnce(adapter);

      expect(
        adapter.pushCallCount,
        1,
        reason: 'Chặn là tạm thời. Loại vĩnh viễn sẽ giết luôn các lỗi chỉ tự '
            'khỏi sau khi Pull xong — ví dụ giao dịch còn trỏ tới ID danh mục '
            'mặc định cũ.',
      );
    });

    test('Đẩy thành công xoá sạch dấu vết thất bại cũ', () async {
      await seedPendingCategory();
      await db.categoryDao.markSyncBlocked(
        catId,
        clock.add(const Duration(minutes: 5)),
        'hỏng từ chu kỳ trước',
      );
      clock = clock.add(const Duration(minutes: 6));

      await runOnce(_SucceedingAdapter());

      final row = await db.categoryDao.getById(catId);
      expect(row?.syncStatus, 'synced');
      expect(row?.syncBlockedUntil, isNull,
          reason: 'Không xoá thì bản ghi vẫn mang mốc chặn của lần hỏng trước '
              'và bị gạt oan ở chu kỳ sau.');
      expect(row?.syncRetryCount, 0);
      expect(row?.syncError, isNull);
    });
  });

  group('Nhận diện phiên chết qua hợp đồng backend mới (2026-09-03)', () {
    late DateTime clock;
    DateTime now() => clock;

    setUp(() => clock = DateTime(2026, 9, 3, 9, 0, 0));

    Future<_Probe> runWithAdapter(HttpClientAdapter adapter) async {
      final engine = SyncEngine(
        dioClient: _AdapterClient(adapter),
        db: db,
        connectivity: _Online(),
        now: now,
      );
      addTearDown(engine.dispose);
      var signalled = false;
      final sub = engine.sessionInvalidStream.listen((_) => signalled = true);
      final done = engine.statusStream.where((s) => s.isTerminal).first;
      await engine.start(idaccount: accountId);
      await done.timeout(const Duration(seconds: 5));
      final status = engine.status;
      await sub.cancel();
      return _Probe(sessionInvalid: signalled, finalStatus: status);
    }

    test(
        'Mã ACCOUNT_NOT_FOUND được tin, kể cả khi thông báo lỗi KHÔNG khớp regex cũ',
        () async {
      await seedPendingCategory();
      // Backend đổi tên constraint / nâng version Prisma → chuỗi thông báo đổi
      // theo, nhưng `code` thì ổn định. Đây chính là kịch bản mà
      // SESSION_VALIDITY_FINDINGS.md gọi là "hỏng âm thầm".
      final adapter = _CodedFailureAdapter(
        code: 'ACCOUNT_NOT_FOUND',
        message: 'Ràng buộc dữ liệu bị vi phạm ở tầng lưu trữ',
      );

      final r = await runWithAdapter(adapter);

      expect(
        r.sessionInvalid,
        isTrue,
        reason: 'Client phải tin trường `code` ổn định do backend gửi. Nếu chỉ '
            'khớp regex fk_*_account trên thông báo Prisma thì đổi tên '
            'constraint là mất luôn khả năng phát hiện phiên chết, mà không có '
            'lỗi nào báo ra.',
      );
      expect(r.finalStatus, SyncStatus.authExpired);
      expect(adapter.pushCallCount, 1, reason: 'Phiên chết thì không thử lại');
    });

    test('Regex cũ vẫn là đường dự phòng khi backend chưa gửi `code`', () async {
      await seedPendingCategory();
      final adapter = _CodedFailureAdapter(
        code: null,
        message: 'Foreign key constraint violated on the constraint: '
            '`fk_category_account`',
      );

      final r = await runWithAdapter(adapter);

      expect(r.sessionInvalid, isTrue,
          reason: 'Không được bỏ regex: backend cũ vẫn đang chạy ở máy khác.');
    });

    test('HTTP 401 từ /sync/push được hiểu là phiên chết, không phải lỗi mạng',
        () async {
      await seedPendingCategory();
      final adapter = _StatusOnlyAdapter(401);

      final r = await runWithAdapter(adapter);

      expect(
        r.sessionInvalid,
        isTrue,
        reason: 'Từ 2026-09-03 backend trả 401 cho CẢ batch khi mọi thao tác '
            'đều hỏng vì tài khoản không còn tồn tại. Trước đây nhánh '
            'DioException trả về SyncResult có `failures` RỖNG nên '
            'hasSessionInvalid là false — engine im lặng, và việc phát hiện '
            'phiên chết phụ thuộc hoàn toàn vào đường vòng qua AuthInterceptor.',
      );
      expect(r.finalStatus, SyncStatus.authExpired);
      expect(adapter.pushCallCount, 1);
    });

    test('Lỗi 5xx là sự cố truyền tải: KHÔNG coi là phiên chết, không thử lại',
        () async {
      await seedPendingCategory();
      final adapter = _StatusOnlyAdapter(503);

      final r = await runWithAdapter(adapter);

      expect(r.sessionInvalid, isFalse,
          reason: 'Máy chủ sự cố không phải phiên chết — đăng xuất người dùng '
              'ở đây là phá vỡ cam kết offline-first.');
      expect(r.finalStatus, SyncStatus.error);
      expect(adapter.pushCallCount, 1,
          reason: 'Cả batch không tới nơi thì thử lại ngay trong cùng chu kỳ '
              'là vô ích; giãn cách luỹ tiến (G2) lo phần thử lại.');
    });
  });
}

class _Probe {
  _Probe({required this.sessionInvalid, required this.finalStatus});
  final bool sessionInvalid;
  final SyncStatus finalStatus;
}

/// Trả về `results` có kèm trường `code` như backend từ 2026-09-03.
class _CodedFailureAdapter implements HttpClientAdapter {
  _CodedFailureAdapter({required this.code, required this.message});

  final String? code;
  final String message;
  int pushCallCount = 0;

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path.contains('/sync/push')) {
      pushCallCount++;
      final ops =
          (o.data as Map<String, dynamic>)['operations'] as List<dynamic>;
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'success',
          'results': ops
              .map((op) => {
                    'localId': op['localId'],
                    'status': 'error',
                    'message': message,
                    if (code != null) 'code': code,
                  })
              .toList(),
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        },
      );
    }
    return ResponseBody.fromString(jsonEncode({'data': const {}}), 200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

/// Trả về đúng một mã HTTP cho /sync/push (không có thân `results`).
class _StatusOnlyAdapter implements HttpClientAdapter {
  _StatusOnlyAdapter(this.status);

  final int status;
  int pushCallCount = 0;

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path.contains('/sync/push')) {
      pushCallCount++;
      return ResponseBody.fromString(
        jsonEncode({'success': false, 'message': 'Account no longer exists'}),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        },
      );
    }
    return ResponseBody.fromString(jsonEncode({'data': const {}}), 200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

class _AdapterClient implements DioClient {
  _AdapterClient(HttpClientAdapter adapter) {
    dio.httpClientAdapter = adapter;
  }
  @override
  final Dio dio = Dio();
}

/// Chấp nhận mọi thao tác đẩy lên.
class _SucceedingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path.contains('/sync/push')) {
      final ops =
          (o.data as Map<String, dynamic>)['operations'] as List<dynamic>;
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
    return ResponseBody.fromString(jsonEncode({'data': const {}}), 200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

class _ConflictClient implements DioClient {
  _ConflictClient(this.adapter) {
    dio.httpClientAdapter = adapter;
  }
  @override
  final Dio dio = Dio();
  final _ConflictAdapter adapter;
}

/// Trả 'conflict' cho mọi thao tác đẩy lên — mô phỏng backend khi bản trên
/// server có `update_at` mới hơn payload.
class _ConflictAdapter implements HttpClientAdapter {
  int pushCallCount = 0;

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path.contains('/sync/push')) {
      pushCallCount++;
      final ops =
          (o.data as Map<String, dynamic>)['operations'] as List<dynamic>;
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'success',
          'results': ops
              .map((op) => {
                    'localId': op['localId'],
                    'status': 'conflict',
                    'message': 'Server version is newer',
                  })
              .toList(),
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        },
      );
    }
    return ResponseBody.fromString(jsonEncode({'data': const {}}), 200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}
