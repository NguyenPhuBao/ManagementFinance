/// Test "hợp đồng" (contract) cho ánh xạ tên trường giữa Client và Backend.
///
/// Vì sao cần: payload push được dựng THỦ CÔNG ở client, đi qua
/// `SyncPayloadNormalizer`, rồi mới tới `mapEntityFields()` ở backend. Ba nơi
/// này không chia sẻ một định nghĩa chung nào, nên một tên trường sai sẽ **không
/// gây lỗi** — nó chỉ lặng lẽ bị bỏ qua. Dự án đã dính đúng lớp lỗi này nhiều
/// lần (giao dịch kẹt vĩnh viễn vì `cat_food`; nhóm danh mục không bao giờ được
/// đẩy lên backend).
///
/// File này khoá lại tập khoá của từng payload. Đổi tên trường mà quên cập nhật
/// phía kia sẽ làm test đỏ ngay thay vì hỏng âm thầm.
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
  _Client() {
    dio.httpClientAdapter = adapter;
  }
  @override
  final Dio dio = Dio();
  final _Adapter adapter = _Adapter();
}

class _Adapter implements HttpClientAdapter {
  List<Map<String, dynamic>> pushed = [];
  Map<String, dynamic> pullData = const {};

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path.contains('/sync/push')) {
      final ops =
          (o.data as Map<String, dynamic>)['operations'] as List<dynamic>;
      pushed.addAll(ops.cast<Map<String, dynamic>>());
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
    return ResponseBody.fromString(jsonEncode({'data': pullData}), 200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const accountId = 7;
  const walletId = '11111111-1111-4111-8111-111111111111';
  const categoryId = '22222222-2222-4222-8222-222222222222';
  const goalId = '66666666-6666-4666-8666-666666666666';

  late AppDatabase db;
  late _Client client;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    client = _Client();
    engine =
        SyncEngine(dioClient: client, db: db, connectivity: _Online());
  });

  tearDown(() async {
    engine.dispose();
    await db.close();
  });

  Future<void> runSync() async {
    final done = engine.statusStream.where((s) => s.isTerminal).first;
    engine.start(idaccount: accountId);
    await done.timeout(const Duration(seconds: 5));
  }

  Map<String, dynamic> payloadOf(String entity) {
    final op = client.adapter.pushed.firstWhere(
      (op) => op['entity'] == entity,
      orElse: () => throw StateError('Không có op nào cho entity "$entity"'),
    );
    return op['payload'] as Map<String, dynamic>;
  }

  group('PUSH — tập khoá của payload gửi lên backend', () {
    setUp(() async {
      final now = DateTime.now();
      await db.walletDao.insert(WalletsCompanion(
        id: const Value(walletId),
        idaccount: const Value(accountId),
        name: const Value('Ví tiền mặt'),
        type: const Value('cash'),
        balance: const Value(1000),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ));
      await db.categoryDao.insert(CategoriesCompanion.insert(
        id: categoryId,
        idaccount: accountId,
        name: 'Cà phê',
        classify: 'chi',
        updatedAt: now,
      ));
      await db.transactionDao.insert(TransactionsCompanion(
        id: const Value('33333333-3333-4333-8333-333333333333'),
        idaccount: const Value(accountId),
        walletId: const Value(walletId),
        categoryId: const Value(categoryId),
        amount: const Value(-45000),
        type: const Value('chi'),
        date: Value(now),
        // Nối với mục tiêu bằng ID. Trước 2026-09-07 cột này là cục bộ nên
        // hàng kéo về từ server luôn trống, và `watchByGoal` phải rơi xuống
        // nhánh so TÊN — nhánh mang đúng khuyết điểm mà cột này sinh ra để
        // chữa ("Mua" nuốt lịch sử của "Mua xe").
        goalId: const Value(goalId),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ));
      // Ba kiểu giao dịch của client, để canh phép quy đổi sang bộ giá trị mà
      // PostgreSQL chấp nhận. Xem group "PUSH — giá trị `type` và dấu của
      // `amount`" bên dưới.
      await db.transactionDao.insert(TransactionsCompanion(
        id: const Value('66666666-6666-4666-8666-666666666667'),
        idaccount: const Value(accountId),
        walletId: const Value(walletId),
        categoryId: const Value(categoryId),
        amount: const Value(120000),
        type: const Value('thu'),
        date: Value(now),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ));
      await db.transactionDao.insert(TransactionsCompanion(
        id: const Value('55555555-5555-4555-8555-555555555555'),
        idaccount: const Value(accountId),
        walletId: const Value(walletId),
        categoryId: const Value(categoryId),
        walletTransfer: const Value(walletId),
        amount: const Value(700000),
        type: const Value('transfer'),
        date: Value(now),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ));
      // Khoản chuyển do bản app TRƯỚC 2026-09-05 tạo: màn thêm giao dịch gán
      // `categoryId = 'cat_transfer'`, một id chưa từng được seed. Xem test
      // "transfer mang categoryId không phân giải được vẫn được đẩy".
      await db.transactionDao.insert(TransactionsCompanion(
        id: const Value('77777777-7777-4777-8777-777777777777'),
        idaccount: const Value(accountId),
        walletId: const Value(walletId),
        categoryId: const Value('cat_transfer'),
        walletTransfer: const Value(walletId),
        amount: const Value(50000),
        type: const Value('transfer'),
        date: Value(now),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ));
      await db.budgetDao.insert(BudgetsCompanion(
        id: const Value('44444444-4444-4444-8444-444444444444'),
        idaccount: const Value(accountId),
        categoryId: const Value(categoryId),
        amount: const Value(500000),
        startDate: Value(now),
        // Client không tự sinh giá trị cho cột này (chu kỳ neo vào ngày bắt
        // đầu), nhưng hàng kéo về từ backend hoặc Admin-web có thể mang sẵn —
        // và khi đó phải được đẩy lại nguyên vẹn.
        nextTimeRecurrence: Value(DateTime.utc(2026, 10, 5)),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ));
      await db.billDao.insert(BillsCompanion(
        id: const Value('55555555-5555-4555-8555-555555555555'),
        idaccount: const Value(accountId),
        walletId: const Value(walletId),
        categoryId: const Value(categoryId),
        name: const Value('Tiền điện'),
        amount: const Value(300000),
        dueDate: Value(now),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ));
      await db.goalDao.insert(GoalsCompanion(
        id: const Value('66666666-6666-4666-8666-666666666666'),
        idaccount: const Value(accountId),
        name: const Value('Mua laptop'),
        targetAmount: const Value(20000000),
        targetDate: Value(now),
        // Bật trích tự động để payload mang giá trị thật chứ không phải null —
        // một trường luôn null thì test không phân biệt được "có gửi" với
        // "gửi nhầm tên".
        autoDepositAmount: const Value(500000),
        autoDepositWalletId: const Value(walletId),
        autoDepositLastRun: Value(DateTime.utc(2026, 9, 1, 3)),
        // Cùng lý do như ba cột trên: một giá trị THẬT chứ không phải null,
        // nếu không test không phân biệt được "có gửi" với "gửi nhầm tên".
        priority: const Value(200),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ));
      await runSync();
    });

    test('wallet', () {
      expect(
        payloadOf('wallet').keys.toSet(),
        {
          'id', 'name', 'type', 'balance', 'currency', 'icon',
          'color', // normalizer đổi colour → color
          'is_default', 'is_deleted', 'include_in_total',
          // ⚠️ `status` (lưu trữ ví) CỐ Ý vắng mặt — nhóm PUSH ngay dưới
          // canh riêng điều đó, kèm con số đo được.
          'update_at', // normalizer đổi updated_at → update_at
          'idaccount',
        },
      );
    });

    test('ví lưu trữ KHÔNG được mang `status` lên server', () async {
      // Lý do ban đầu, đo thẳng trên CSDL ngày 2026-09-10
      // (`information_schema.columns`): cột `Status` của PostgreSQL là
      // **varchar(7)**, còn giá trị cần gửi lên là `'Inactive'` — **8 ký tự**.
      // Đẩy lên là hàng ví vỡ ở tầng CSDL, backend trả về lỗi ràng buộc, và ví
      // kẹt hàng đợi đẩy: thử lại ở MỌI chu kỳ, kéo chậm cả hàng đợi. Đã vấp
      // thật trên máy ảo.
      //
      // Tối cùng ngày CSDL dev đã nới cột lên `varchar(20)` (áp `database/7`),
      // nhưng `status` vẫn là cột CỤC BỘ cho tới khi mở lại G28 — người dùng
      // chốt để sau; mở lại thì test này đổi sang canh chiều ngược lại. Cùng
      // diện với `bills.autoPayEnabled` và `bills.anchorDay`. Xem G28
      // `docs/CLIENT_APP_KNOWN_GAPS.md` và
      // `docs/superpowers/backend/DA-XONG/WALLET_STATUS_COLUMN_WIDTH.md`.
      const viLuuTru = '22222222-2222-4222-8222-222222222222';
      await db.walletDao.insert(WalletsCompanion(
        id: const Value(viLuuTru),
        idaccount: const Value(accountId),
        name: const Value('Ví thẻ cũ'),
        type: const Value('bank'),
        balance: const Value(0),
        status: const Value('inactive'),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ));
      await runSync();

      final payloads = client.adapter.pushed
          .where((op) => op['entity'] == 'wallet')
          .map((op) => op['payload'] as Map<String, dynamic>)
          .toList();

      for (final p in payloads) {
        expect(p.containsKey('status'), isFalse,
            reason: 'Ví ${p['id']} mang `status` lên server, trong khi `status` '
                'là cột cục bộ cho tới khi mở lại G28. Ở CSDL nào chưa nới cột '
                '(varchar(7)), ví lưu trữ gửi chuỗi 8 ký tự — bản ghi kẹt hàng '
                'đợi đẩy và thử lại vĩnh viễn.');
      }
      expect(payloads.any((p) => p['id'] == viLuuTru), isTrue,
          reason: 'Ví lưu trữ VẪN phải được đẩy lên — tên, số dư, cờ mặc định '
              'của nó vẫn phải tới được máy khác. Chỉ riêng trạng thái lưu trữ '
              'là ở lại máy này.');
    });

    test('mục tiêu mang priority 0 cũ thì đẩy lên null — G32', () async {
      // Backend trước `7675b35` gọi `Number(null)` nên mục tiêu CHƯA SẮP kéo về
      // máy mang 0, và hàng cục bộ lưu từ hồi ấy vẫn có thể giữ 0. Client không
      // bao giờ tự sinh priority <= 0 (`goal_priority.dart`), nên 0 là một null
      // bị ép. Đẩy lại 0 là giữ cái sai ấy trên server mãi; đẩy null thì hàng
      // tự lành ở lần sửa kế — `mapEntityFields` nay giữ `null` (đo 2026-09-11).
      const mucTieuCu = '77777777-7777-4777-8777-777777777777';
      await db.goalDao.insert(GoalsCompanion(
        id: const Value(mucTieuCu),
        idaccount: const Value(accountId),
        name: const Value('Quỹ khẩn cấp'),
        targetAmount: const Value(10000000),
        targetDate: Value(DateTime.now()),
        priority: const Value(0),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ));
      await runSync();

      final p = client.adapter.pushed
          .where((op) => op['entity'] == 'goal')
          .map((op) => op['payload'] as Map<String, dynamic>)
          .firstWhere((p) => p['id'] == mucTieuCu);
      expect(p.containsKey('priority'), isTrue,
          reason: 'Khoá vẫn phải có mặt — tập khoá của payload mục tiêu được '
              'khoá ở ca "goal" bên dưới.');
      expect(p['priority'], isNull,
          reason: 'Đẩy 0 lên là server giữ 0 mãi, và mọi máy khác kéo về một '
              'mục tiêu "đứng đầu" mà người dùng chưa từng sắp.');
    });

    test('category — phải có isGroup/parentId để backend dựng lại cây nhóm', () {
      expect(
        payloadOf('category').keys.toSet(),
        {
          'id', 'name', 'namecategory', 'classify', 'icon',
          // normalizer đổi colour → color, như ví. Trước 2026-09-11 dòng
          // này khoá `'colour'` — tức canh đúng bản sai: backend không có
          // nhánh nào đọc `colour`, nên màu danh mục bị bỏ qua im lặng (G24).
          'color',
          'is_default', 'is_deleted',
          'isGroup', // mapEntityFields: isGroup → Is_group
          'parentId', // mapEntityFields: parentId → Idgroup
          'update_at', 'idaccount',
          // `keyword` KHÔNG có mặt ở đây có chủ đích: danh mục trong bộ dựng
          // này không có từ khoá nào, và gửi chuỗi rỗng là lệnh XOÁ phía
          // server. Nhóm "PUSH — từ khoá phân loại của danh mục" canh ca có.
        },
      );
    });

    test('transaction', () {
      expect(
        payloadOf('transaction').keys.toSet(),
        {
          'id',
          'walletId', // normalizer đổi wallet_id → walletId
          'categoryId', // normalizer đổi category_id → categoryId
          'idwallet_transfer',
          'amount', 'type', 'note',
          'dateTransaction', // normalizer đổi date → dateTransaction
          'is_deleted', 'update_at', 'idaccount',
          // Khoá nối tới mục tiêu, mở khoá 2026-09-07 khi backend thêm cột
          // `transaction.Idgoal`. Tên payload là `idgoal` — KHÔNG phải
          // `goal_id`, vốn là tên cột Drift cục bộ và vẫn nằm trong danh sách
          // cấm rò rỉ bên dưới. Hai cái tên khác nhau ở đúng một chỗ này, và
          // gửi nhầm tên thì backend bỏ qua trong im lặng.
          'idgoal',
        },
      );
    });

    test('mục tiêu phải được đẩy TRƯỚC giao dịch nạp vào nó', () {
      final thuTu = client.adapter.pushed
          .map((op) => op['entity'].toString())
          .toList();
      final viTriGoal = thuTu.indexOf('goal');
      final viTriTran = thuTu.indexOf('transaction');
      expect(viTriGoal, isNonNegative);
      expect(viTriTran, isNonNegative);
      expect(
        viTriGoal,
        lessThan(viTriTran),
        reason: 'Từ 2026-09-07 payload giao dịch mang `idgoal`, và phía server '
            'cột ấy có khoá ngoại `fk_transaction_goal`. Đẩy giao dịch trước '
            'mục tiêu thì hàng bị từ chối vì mục tiêu chưa tồn tại — đúng ca '
            'người dùng tạo mục tiêu rồi nạp tiền trong lúc offline, cả hai '
            'cùng nằm chờ trong một lô. Cùng lý do khiến categories phải đứng '
            'trước transactions.',
      );
    });
    test('hoá đơn phải được đẩy TRƯỚC giao dịch trả cho nó', () {
      final thuTu = client.adapter.pushed
          .map((op) => op['entity'].toString())
          .toList();
      final viTriBill = thuTu.indexOf('bill');
      final viTriTran = thuTu.indexOf('transaction');
      expect(viTriBill, isNonNegative);
      expect(viTriTran, isNonNegative);
      expect(
        viTriBill,
        lessThan(viTriTran),
        reason: 'Từ 2026-09-12 payload giao dịch mang khoá nối tới hoá đơn, và '
            'phía server cột ấy có khoá ngoại `fk_transaction_bill`. Đẩy giao '
            'dịch trước hoá đơn thì khoản trả bị từ chối vì hoá đơn chưa tồn '
            'tại, rồi KẸT hàng đợi đẩy và thử lại mãi — im lặng. Đúng ca người '
            'dùng tạo hoá đơn rồi trả luôn trong lúc offline, cả hai cùng nằm '
            'chờ trong một lô. Cùng lý do đã khiến mục tiêu phải đứng trước '
            'giao dịch hồi 2026-09-07.',
      );
    });
    test('payload giao dịch mang idgoal của khoản nạp mục tiêu', () {
      final p = payloadOf('transaction');
      expect(p['idgoal'], goalId,
          reason: 'Thiếu giá trị này thì hàng lên server mang Idgoal = NULL, '
              'và máy thứ hai kéo về vẫn phải đoán chủ sở hữu bằng cách so '
              'TÊN mục tiêu trong ghi chú — đúng khuyết điểm G18.');
    });

    group('giá trị `type` và dấu của `amount`', () {
      /// Canh chừng điều gì: PostgreSQL có
      /// `chk_transaction_type CHECK ("Type" IN ('Transaction','Transfer'))`,
      /// nên bộ giá trị nội bộ của client (`chi`/`thu`/`transfer`) KHÔNG được
      /// đi thẳng lên. Chiều tiền phía server nằm ở **dấu của `Amount`** chứ
      /// không ở `Type`: âm là chi, dương là thu.
      ///
      /// `SyncPayloadNormalizer.transactionForPush` làm phép quy đổi này, và
      /// hợp đồng cũ chỉ khoá TÊN khoá nên không có gì canh giá trị. Mất phép
      /// quy đổi thì mọi giao dịch bị ràng buộc CHECK từ chối — hàng nằm lại
      /// trên máy, số dư ví vẫn đồng bộ nên hai bên lệch nhau mà không ai thấy.
      Map<String, dynamic> payloadCuaGiaoDich(String id) {
        final op = client.adapter.pushed.firstWhere(
          (op) =>
              op['entity'] == 'transaction' &&
              (op['payload'] as Map)['id'] == id,
          orElse: () => throw StateError('Không có op cho giao dịch $id'),
        );
        return op['payload'] as Map<String, dynamic>;
      }

      test('chi → Transaction, số tiền ÂM', () {
        final p = payloadCuaGiaoDich('33333333-3333-4333-8333-333333333333');
        expect(p['type'], 'Transaction',
            reason: "'chi' không nằm trong bộ giá trị PostgreSQL cho phép.");
        expect((p['amount'] as num) < 0, isTrue,
            reason: 'Dấu âm là thứ DUY NHẤT phân biệt chi với thu ở phía '
                'server — cả hai đều mang Type "Transaction".');
      });

      test('thu → Transaction, số tiền DƯƠNG', () {
        final p = payloadCuaGiaoDich('66666666-6666-4666-8666-666666666667');
        expect(p['type'], 'Transaction');
        expect((p['amount'] as num) > 0, isTrue);
      });

      test('transfer → Transfer, giữ ví đích, bỏ danh mục', () {
        final p = payloadCuaGiaoDich('55555555-5555-4555-8555-555555555555');
        expect(p['type'], 'Transfer',
            reason: 'Chuyển tiền giữa hai ví của cùng người dùng là loại '
                'riêng, không phải một khoản chi.');
        expect(p['idwallet_transfer'], isNotNull,
            reason: 'Ví đích là chỗ duy nhất ghi lại tiền đã đi đâu.');
        expect(p['categoryId'], isNull,
            reason: 'Khoản chuyển ví không thuộc danh mục chi tiêu nào; để '
                'nguyên là phần thống kê đếm nó thành chi tiêu thật.');
      });

      test('transfer mang categoryId không phân giải được vẫn được đẩy', () {
        /// Canh chừng điều gì: `_collectPendingOps` hoãn mọi giao dịch có
        /// `categoryId` mà `_resolveCategoryId` không tìm ra, để chờ pull về
        /// danh mục. Với khoản chuyển thì danh mục là vô nghĩa (payload bỏ
        /// nó đi), nhưng bản app cũ từng gán `'cat_transfer'` — id không có
        /// thật — nên những hàng ấy nằm lại máy VĨNH VIỄN, im lặng, trong khi
        /// số dư hai ví vẫn lên server. Khoản chuyển phải đi thẳng, bỏ danh mục.
        final p = payloadCuaGiaoDich('77777777-7777-4777-8777-777777777777');
        expect(p['type'], 'Transfer');
        expect(p['categoryId'], isNull);
        expect(p['idwallet_transfer'], isNotNull,
            reason: 'Ví đích vẫn phải giữ — chỉ danh mục là thứ bị bỏ.');
      });

      test('KHÔNG giá trị nội bộ nào lọt lên backend', () {
        for (final op in client.adapter.pushed) {
          if (op['entity'] != 'transaction') continue;
          final type = (op['payload'] as Map)['type'];
          expect(const ['Transaction', 'Transfer'].contains(type), isTrue,
              reason: 'Gửi "$type" lên sẽ bị chk_transaction_type từ chối.');
        }
      });
    });

    test('budget — gửi thẳng tên field Prisma', () {
      expect(
        payloadOf('budget').keys.toSet(),
        {
          'id', 'idcategory', 'total_amount', 'spent',
          'threshold_warning_amount',
          // Thêm ở lược đồ v11. Backend đã có cột `Threshold_Warning_Percent`
          // từ đợt DB v2 nhưng client thì chưa, nên ngưỡng cảnh báo theo phần
          // trăm không bao giờ sang được máy khác — im lặng, vì trường thiếu
          // chỉ đơn giản là không được ghi.
          'threshold_warning_percent',
          'over_spending', 'over_amount',
          'start', 'end', 'recurrence', 'time_recurrence',
          'nexttime_recurrence', 'note', 'is_deleted', 'update_at',
          'idaccount',
        },
      );
    });

    test('budget — mốc chu kỳ có sẵn phải được đẩy lại nguyên vẹn', () {
      expect(
        payloadOf('budget')['nexttime_recurrence'],
        '2026-10-05T00:00:00.000Z',
        reason: 'Bỏ rơi cột này khi đẩy sẽ xoá mốc mà máy khác đã đặt: backend '
            'lưu null, và chu kỳ lặng lẽ nhảy về neo theo ngày bắt đầu.',
      );
    });

    test('bill', () {
      expect(
        payloadOf('bill').keys.toSet(),
        {
          'id', 'idwallet', 'idcategory', 'name', 'amount', 'start_date',
          'due_date', 'pay_status', 'recurrence', 'time_recurrence',
          'time_notification', 'icon', 'color', 'note', 'is_deleted',
          'update_at', 'idaccount',
        },
      );
    });

    test('goal', () {
      expect(
        payloadOf('goal').keys.toSet(),
        {
          'id', 'name', 'target_amount', 'current_amount', 'start_date',
          'target_date', 'idwallet', 'cycle_take_money',
          'time_cycle_take_money', 'status_complete', 'recurrence',
          'time_recurrence', 'icon', 'color', 'note', 'is_deleted',
          'update_at', 'idaccount',
          // Ba cột trích tự động, mở khoá 2026-09-07 khi backend thêm chúng
          // vào bảng `goal`. Chúng phải đi CÙNG NHAU: thiếu `last_run` thì mỗi
          // máy giữ một mốc riêng và cả hai cùng chuyển tiền khi tới kỳ — hỏng
          // nặng hơn hiện trạng "máy thứ hai không trích gì".
          'auto_deposit_amount', 'auto_deposit_wallet_id',
          'auto_deposit_last_run',
          // Thứ tự ưu tiên, mở khoá 2026-09-08. Cột `Priority` phía backend
          // có từ 2026-09-07. Đây là thứ tự người dùng tự sắp bằng kéo thả —
          // công sức bỏ ra, không suy lại được — nên nó KHÔNG được làm cột
          // cục bộ; đó đúng là bệnh mà G21 đã ghi lại.
          'priority',
        },
      );
    });

    test('payload mục tiêu mang GIÁ TRỊ của thứ tự ưu tiên', () {
      expect(payloadOf('goal')['priority'], 200,
          reason: 'Đúng tên khoá mà sai giá trị thì backend ghi null, và thứ '
              'tự người dùng vừa kéo biến mất khi sang máy khác — im lặng y '
              'như sai tên. Số NHỎ hơn đứng trước, các giá trị cách nhau 100.');
    });

    test('payload mục tiêu mang đủ GIÁ TRỊ của ba cột trích tự động', () {
      final p = payloadOf('goal');
      expect(p['auto_deposit_amount'], 500000,
          reason: 'Số tiền trích mỗi kỳ. Đúng tên khoá mà sai giá trị thì '
              'backend ghi null, và người dùng thấy công tắc bật mà không '
              'trích — im lặng y như sai tên.');
      expect(p['auto_deposit_wallet_id'], walletId,
          reason: 'Ví NGUỒN của khoản trích, khác `idwallet` là ví NHẬN.');
      expect(p['auto_deposit_last_run'], '2026-09-01T03:00:00.000Z',
          reason: 'Mốc kỳ gần nhất đã trích, gửi dạng ISO 8601 UTC như mọi cột '
              'thời gian khác. Đây là cột chống trích hai lần: sai định dạng '
              'thì backend lưu null và máy kia coi như chưa từng trích.');
    });

    test('KHÔNG được rò rỉ trường thuần client lên backend', () {
      for (final op in client.adapter.pushed) {
        final payload = op['payload'] as Map<String, dynamic>;
        for (final forbidden in const [
          'syncStatus',
          'sync_status',
          'isLocalOnly',
          'is_local_only',
          'keywords',
          'goal_id', // cột cục bộ của transactions (schema v14)
          'updatedAt', // phải đã được đổi thành update_at
        ]) {
          expect(payload.containsKey(forbidden), false,
              reason: '${op['entity']} không được gửi "$forbidden"');
        }
      }
    });
  });

  group('PULL — mapper phải đọc đúng tên field Prisma backend trả về', () {
    test('đọc được đúng các trường của mọi thực thể', () async {
      client.adapter.pullData = {
        'wallets': [
          {
            'idwallet': walletId,
            'idaccount': accountId,
            'name': 'Ví ngân hàng',
            'balance': 5000,
            'color': '#123456',
            'include_in_total': false,
            'update_at': '2026-09-01T10:00:00.000Z',
          },
        ],
        'categories': [
          {
            'idcategory': categoryId,
            'name_category': 'Ăn uống',
            'classify': 'Chi',
            'is_group': true,
            'create_by': accountId,
            'color': '#ABCDEF',
            'update_at': '2026-09-01T10:00:00.000Z',
          },
        ],
        'budgets': [
          {
            'idbudget': '44444444-4444-4444-8444-444444444444',
            'idaccount': accountId,
            'idcategory': categoryId,
            'total_amount': 750000,
            'over_spending': 'Stop',
            'start': '2026-09-01T00:00:00.000Z',
            'update_at': '2026-09-01T10:00:00.000Z',
          },
        ],
        'transactions': [
          {
            'idtran': '99999999-9999-4999-8999-999999999999',
            'idaccount': accountId,
            'idwallet': walletId,
            'idcategory': categoryId,
            'amount': -100000,
            'type': 'Transaction',
            'note': 'Tích lũy mục tiêu: Mua laptop',
            'date_transaction': '2026-09-01T02:00:00.000Z',
            'idgoal': goalId,
            'update_at': '2026-09-01T10:00:00.000Z',
          },
        ],
        'goals': [
          {
            'idgoal': '66666666-6666-4666-8666-666666666666',
            'idaccount': accountId,
            'name': 'Mua laptop',
            'target_amount': 20000000,
            'current_amount': 1000,
            'target_date': '2026-12-01T00:00:00.000Z',
            'status_complete': 'True',
            'auto_deposit_amount': 750000,
            'auto_deposit_wallet_id': walletId,
            'auto_deposit_last_run': '2026-09-01T03:00:00.000Z',
            'update_at': '2026-09-01T10:00:00.000Z',
          },
        ],
      };

      await runSync();

      final wallet = await db.walletDao.getById(walletId);
      expect(wallet?.balance, 5000, reason: 'đọc "balance"');
      expect(wallet?.colour, '#123456', reason: 'backend dùng "color"');
      expect(wallet?.includeInTotal, false,
          reason: 'Nửa còn lại của cờ này: nó NẰM trong payload đẩy lên nhưng '
              'nhánh kéo về không đọc, nên máy thứ hai KHÔNG BAO GIỜ biết '
              'ví nào bị loại khỏi tổng tài sản. Hỏng im lặng, quy tắc 4.');

      final category = await db.categoryDao.getById(categoryId);
      expect(category?.name, 'Ăn uống', reason: 'backend dùng "name_category"');
      expect(category?.isGroup, true, reason: 'backend dùng "is_group"');
      expect(category?.colour, '#ABCDEF',
          reason: 'backend trả "color" (`sync.repository.js:228`), không phải '
              '"colour" — đọc nhầm khoá là mọi máy khác thấy màu mặc định (G24).');

      final budgets = await db.budgetDao.getAll(accountId);
      expect(budgets.single.amount, 750000,
          reason: 'backend dùng "total_amount", không phải "amount"');
      expect(budgets.single.overSpending, 'Stop');

      final tran = (await db.transactionDao.getAll(accountId))
          .firstWhere((t) => t.id == '99999999-9999-4999-8999-999999999999');
      expect(tran.goalId, goalId,
          reason: 'Nửa còn lại của G18: đẩy `idgoal` lên mà không đọc lại thì '
              'hàng kéo về máy thứ hai vẫn trống cột nối, và nó vẫn phải so '
              'TÊN mục tiêu trong ghi chú để đoán chủ sở hữu.');

      final goals = await db.goalDao.getAll(accountId);
      expect(goals.single.isCompleted, true,
          reason: 'backend dùng "status_complete" dạng chuỗi "True"');
      expect(goals.single.autoDepositAmount, 750000,
          reason: 'Chiều KÉO VỀ là nửa còn lại của G21: đẩy lên mà không đọc '
              'lại thì máy thứ hai vẫn không biết trích tự động đang bật.');
      expect(goals.single.autoDepositWalletId, walletId);
      // So bằng `.toUtc()` chứ không so thẳng: Drift trả DateTime **local**,
      // nên `DateTime.utc(...)` không bao giờ bằng nó dù cùng một thời điểm
      // (Dart so cả cờ isUtc). Phép so này VẪN bắt được lỗi múi giờ thật —
      // nếu mã đọc bỏ hậu tố Z và hiểu 03:00 là giờ địa phương thì `.toUtc()`
      // ra 2026-08-31T20:00Z và test đỏ.
      expect(goals.single.autoDepositLastRun?.toUtc(),
          DateTime.utc(2026, 9, 1, 3),
          reason: 'Mốc kỳ gần nhất phải về được máy thứ hai, nếu không nó sẽ '
              'trích lại đúng kỳ mà máy thứ nhất vừa trích xong.');
    });

    test('server chưa có màu danh mục thì màu cục bộ phải còn nguyên — G24',
        () async {
      // Trạng thái THẬT ngay sau khi client đổi sang khoá `color`: danh mục đã
      // `synced` từ trước vẫn nằm trên server với `Color = NULL`, vì màu chỉ lên
      // server khi danh mục được đẩy lại với `update_at` MỚI HƠN (cùng mốc thì
      // server trả xung đột và giữ bản của nó — đo trên máy ảo 2026-09-11). Nhánh
      // kéo về mà ghi đè thẳng thì mỗi chu kỳ đồng bộ xoá màu người dùng đã chọn.
      await db.categoryDao.insert(CategoriesCompanion.insert(
        id: categoryId,
        idaccount: accountId,
        name: 'Ăn uống',
        classify: 'chi',
        colour: const Value('#FF5722'),
        syncStatus: const Value('synced'),
        updatedAt: DateTime(2026, 9, 1),
      ));

      client.adapter.pullData = {
        'categories': [
          {
            'idcategory': categoryId,
            'name_category': 'Ăn uống',
            'classify': 'Chi',
            'create_by': accountId,
            'color': null, // hàng cũ trên server: cột có, giá trị chưa có
            'update_at': '2026-09-02T10:00:00.000Z',
          },
        ],
      };

      await runSync();

      final category = await db.categoryDao.getById(categoryId);
      expect(category?.colour, '#FF5722',
          reason: 'Server trả `color: null` nghĩa là CHƯA BIẾT, không phải "xoá '
              'màu" — cùng bài học với `idgoal` ở ca ngay dưới.');
    });

    test('hàng server KHÔNG có idgoal thì liên kết cục bộ phải còn nguyên',
        () async {
      // Đây là trạng thái THẬT ngay sau khi backend thêm cột: mọi hàng đã nằm
      // sẵn trên server đều mang `Idgoal = NULL`, vì chúng được đẩy lên từ
      // trước khi client biết gửi trường này. Nhánh pull ghi đè thẳng sẽ xoá
      // sạch liên kết cục bộ ở đúng chu kỳ đồng bộ đầu tiên — và lịch sử tích
      // luỹ lặng lẽ rơi hết xuống nhánh so TÊN, tức tái hiện nguyên vẹn G18.
      // Ví phải có trước: `transactions.wallet_id` là khoá ngoại thật.
      await db.walletDao.insert(WalletsCompanion(
        id: const Value(walletId),
        idaccount: const Value(accountId),
        name: const Value('Ví tiền mặt'),
        type: const Value('cash'),
        balance: const Value(1000),
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime(2026, 9, 1)),
      ));
      await db.transactionDao.insert(TransactionsCompanion(
        id: const Value('88888888-8888-4888-8888-888888888888'),
        idaccount: const Value(accountId),
        walletId: const Value(walletId),
        amount: const Value(-70000),
        type: const Value('chi'),
        date: Value(DateTime(2026, 9, 1)),
        goalId: const Value(goalId),
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime(2026, 9, 1)),
      ));

      client.adapter.pullData = {
        'transactions': [
          {
            'idtran': '88888888-8888-4888-8888-888888888888',
            'idaccount': accountId,
            'idwallet': walletId,
            'amount': -70000,
            'type': 'Transaction',
            'date_transaction': '2026-09-01T02:00:00.000Z',
            // KHÔNG có khoá 'idgoal' — đúng như hàng cũ trên server.
            'update_at': '2026-09-02T10:00:00.000Z',
          },
        ],
      };

      await runSync();

      final tran = (await db.transactionDao.getAll(accountId))
          .firstWhere((t) => t.id == '88888888-8888-4888-8888-888888888888');
      expect(tran.goalId, goalId,
          reason: 'Server im lặng về idgoal nghĩa là CHUA BIET, không phải '
              'HAY XOA. Ghi đè null vào đây là mất liên kết mà không có lỗi '
              'nào báo ra.');
    });
    test('server KHÔNG bỏ được lưu trữ của ví — kể cả khi nó gửi status',
        () async {
      // Đây là nửa thứ hai của việc `status` là cột cục bộ, và là nửa dễ
      // quên: client không đẩy cột này lên, nên server giữ `'Active'` cho MỌI
      // ví của tài khoản còn dùng (chỉ ví của tài khoản đã bị xoá hẳn mới bị
      // `scheduler.service.js` đặt `'Inactive'`). Lý do ban đầu của việc không
      // đẩy: cột `Status` là varchar(7) còn `'Inactive'` dài 8 ký tự; CSDL dev
      // đã nới lên varchar(20) tối 2026-09-10, nhưng việc nối lại — G28 —
      // người dùng chốt để sau. Đọc cột ấy về là ví vừa lưu trữ lặng lẽ sống
      // lại ở đúng lượt pull kế tiếp.
      //
      // Payload dưới đây cố ý mang `'status': 'Active'` — dạng KHÓ nhất, vì
      // một bản đọc thẳng sẽ vượt qua ca 'server im lặng' mà vỡ ở đây.
      await db.walletDao.insert(WalletsCompanion(
        id: const Value(walletId),
        idaccount: const Value(accountId),
        name: const Value('Ví thẻ cũ'),
        type: const Value('bank'),
        balance: const Value(1000),
        status: const Value('inactive'),
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime(2026, 9, 1)),
      ));

      client.adapter.pullData = {
        'wallets': [
          {
            'idwallet': walletId,
            'idaccount': accountId,
            'name': 'Ví thẻ cũ',
            'balance': 1000,
            'status': 'Active',
            'update_at': '2026-09-02T10:00:00.000Z',
          },
        ],
      };

      await runSync();

      expect((await db.walletDao.getById(walletId))?.status, 'inactive',
          reason: 'Lưu trữ ví sống hoàn toàn trên máy này. Đọc `status` từ '
              'payload là mọi ví lưu trữ tự bỏ lưu trữ sau đúng một chu kỳ '
              'đồng bộ — im lặng, không thông báo nào.');
    });
    test('hàng server KHÔNG có include_in_total thì cờ cục bộ phải còn nguyên',
        () async {
      // Ví này đang bị người dùng cố ý loại khỏi tổng tài sản ở máy hiện tại.
      // Payload thiếu khoá là trạng thái THẬT của mọi backend chưa trả cột ấy,
      // và `doiSangBool(null)` trả `false` — nên bản đọc thẳng không "giữ
      // nguyên", nó ĐỔI cờ. Đây là ca phân biệt được hai cách cài đặt.
      await db.walletDao.insert(WalletsCompanion(
        id: const Value(walletId),
        idaccount: const Value(accountId),
        name: const Value('Ví tiết kiệm'),
        type: const Value('saving'),
        balance: const Value(1000),
        includeInTotal: const Value(true),
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime(2026, 9, 1)),
      ));

      client.adapter.pullData = {
        'wallets': [
          {
            'idwallet': walletId,
            'idaccount': accountId,
            'name': 'Ví tiết kiệm',
            'balance': 1000,
            // KHÔNG có khoá 'include_in_total' — đúng như hàng cũ trên server.
            'update_at': '2026-09-02T10:00:00.000Z',
          },
        ],
      };

      await runSync();

      expect((await db.walletDao.getById(walletId))?.includeInTotal, true,
          reason: 'Server im lặng về cờ này nghĩa là CHƯA BIẾT, không phải '
              'HÃY LOẠI. Ghi `false` vào đây là lặng lẽ cộng lại vào tổng tài '
              'sản một ví mà người dùng đã cố ý loại ra.');
    });
    test('cờ đúng/sai của mục tiêu đọc được ở MỌI dạng backend có thể gửi',
        () async {
      client.adapter.pullData = {
        'goals': [
          {
            'idgoal': '77777777-7777-4777-8777-777777777777',
            'idaccount': accountId,
            'name': 'Quỹ Tết',
            'target_amount': 5000000,
            'current_amount': 5000000,
            'target_date': '2027-01-01T00:00:00.000Z',
            // Viết THƯỜNG, khác hẳn "True" ở test trên. Cột là VarChar(20)
            // không ràng buộc gì, nên một lần ghi từ Admin-web hay một
            // migration là đủ để giá trị thành dạng này.
            'status_complete': 'true',
            // Số 1 thay cho boolean thật: vài trình điều khiển tuần tự hoá
            // boolean kiểu đó.
            'recurrence': 1,
            'time_recurrence': 'Month',
            'update_at': '2026-09-01T10:00:00.000Z',
          },
        ],
      };

      await runSync();

      final goal = (await db.goalDao.getAll(accountId)).single;
      expect(goal.isCompleted, true,
          reason: 'Phép so cứng `== "True"` biến "true" viết thường thành CHƯA '
              'hoàn thành — im lặng, không exception, không log. Mục tiêu biến '
              'khỏi tab "Đã hoàn thành" mà không ai biết vì sao.');
      expect(goal.recurrence, true,
          reason: 'Phép so cứng `== true` biến số 1 thành `false`, và mục tiêu '
              'mất cờ lặp lại cùng lời nhắc vòng mới của nó.');
      expect(goal.timeRecurrence, 'Month');
    });

    test('BỐN cờ còn lại cũng đọc được ở mọi dạng, không riêng mục tiêu',
        () async {
      client.adapter.pullData = {
        'wallets': [
          {
            'idwallet': walletId,
            'idaccount': accountId,
            'name': 'Ví mặc định',
            'balance': 1000,
            // chuỗi viết thường thay cho boolean thật
            'is_default': 'true',
            'update_at': '2026-09-01T10:00:00.000Z',
          },
        ],
        'categories': [
          {
            'idcategory': categoryId,
            'name_category': 'Nhóm chi',
            'classify': 'Chi',
            // số 1 thay cho boolean thật, ở CẢ HAI cờ
            'is_group': 1,
            'is_default': 1,
            'create_by': accountId,
            'update_at': '2026-09-01T10:00:00.000Z',
          },
        ],
        'budgets': [
          {
            'idbudget': '44444444-4444-4444-8444-444444444444',
            'idaccount': accountId,
            'idcategory': categoryId,
            'total_amount': 750000,
            'over_spending': 'Stop',
            'start': '2026-09-01T00:00:00.000Z',
            'recurrence': 1,
            'time_recurrence': 'Month',
            'update_at': '2026-09-01T10:00:00.000Z',
          },
        ],
        'bills': [
          {
            'idbill': '88888888-8888-4888-8888-888888888888',
            'idaccount': accountId,
            'idwallet': walletId,
            'idcategory': categoryId,
            'name': 'Tiền mạng',
            'amount': 250000,
            'due_date': '2026-10-01T00:00:00.000Z',
            // chuỗi viết hoa chữ đầu, dạng `Status_complete` của mục tiêu
            'recurrence': 'True',
            'time_recurrence': 'Month',
            'update_at': '2026-09-01T10:00:00.000Z',
          },
        ],
      };

      await runSync();

      expect((await db.walletDao.getById(walletId))?.isDefault, true,
          reason: 'Cả bốn cờ này từng so cứng `== true`. Một cái rơi về `false` '
              'trong im lặng thì ví mặc định mất nhãn, nhóm danh mục sập thành '
              'danh mục con, ngân sách và hoá đơn mất tính lặp — không '
              'exception, không log.');

      final category = await db.categoryDao.getById(categoryId);
      expect(category?.isGroup, true);
      expect(category?.isDefault, true);

      final budget = (await db.budgetDao.getAll(accountId)).single;
      expect(budget.recurrence, true);

      final bill = (await db.billDao.getAll(accountId)).single;
      expect(bill.isRecurrence, true,
          reason: 'Hoá đơn còn nặng hơn: `recurrence` (cột chuỗi cũ) được SUY '
              'RA từ cờ này, nên đọc sai một chỗ làm hỏng luôn cột thứ hai.');
    });
  });

  group('PUSH RESULT — hợp đồng chiều ngược lại (backend → client)', () {
    test('Mã lỗi "tài khoản không tồn tại" phải khớp đúng chuỗi backend gửi',
        () {
      expect(
        SyncEngine.accountNotFoundCode,
        'ACCOUNT_NOT_FOUND',
        reason: 'Backend gắn `code` này vào từng phần tử `results[]` của '
            '/sync/push khi lỗi vỡ khoá ngoại tới bảng account '
            '(sync.service.js, từ 2026-09-03). Đây là tên trường đi qua ranh '
            'giới hai phía y như payload đẩy lên: lệch một ký tự thì client '
            'lặng lẽ quay về khớp regex trên thông báo Prisma, và không có lỗi '
            'nào báo ra. Đổi chuỗi này thì phải đổi cả backend cùng lúc.',
      );
    });
  });

  group('PUSH — từ khoá phân loại của danh mục', () {
    setUp(() async {
      final now = DateTime.now();
      await db.walletDao.insert(WalletsCompanion(
        id: const Value(walletId),
        idaccount: const Value(accountId),
        name: const Value('Ví tiền mặt'),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ));
      await db.categoryDao.insert(CategoriesCompanion.insert(
        id: categoryId,
        idaccount: accountId,
        name: 'Cà phê',
        classify: 'chi',
        updatedAt: now,
      ));
      await db.categoryDao.replaceKeywords(
        accountId: accountId,
        categoryId: categoryId,
        keywords: ['cà phê', 'trà sữa'],
        now: now,
      );
      await runSync();
    });

    test('payload mang keyword, nối bằng dấu phẩy', () {
      expect(payloadOf('category')['keyword'], 'cà phê,trà sữa',
          reason: 'Backend lưu từ khoá thành MỘT chuỗi nối bằng dấu phẩy trên '
              'chính hàng category (cột Keyword, @db.Text), và /sync/push đã '
              'nhận nó ở cả nhánh tạo lẫn nhánh cập nhật. Sai tên trường hoặc '
              'sai định dạng thì KHÔNG có lỗi nào báo ra — từ khoá chỉ đơn '
              'giản không bao giờ tới nơi, và mất hẳn khi người dùng cài lại '
              'app.');
    });
  });
}
