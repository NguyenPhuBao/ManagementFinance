/// Migration từ v12 lên schema hiện tại.
///
/// - **v12 → v13**: thêm bảng thông báo cục bộ `app_notifications`.
/// - **v13 → v14**: thêm cột cục bộ `transactions.goal_id`.
///
/// Fixture dựng một CSDL v12 có dữ liệu thật rồi để `onUpgrade` chạy hết chuỗi,
/// nên mỗi migration mới đụng bảng nào thì bảng ấy **phải** có mặt trong
/// `_createV12Schema` — thiếu là nổ "no such table" ngay ở setUp.
///
/// Vì sao cần canh: bảng mới được tạo bằng `createTable` chứ không phải
/// `TableMigration`, nên bản thân nó không có dữ liệu để mất. Thứ dễ hỏng là
/// **những bảng khác** — một nhánh `onUpgrade` viết sai có thể dựng lại bảng
/// hoặc đánh dấu lại toàn bộ bản ghi là cần đẩy, và cả hai đều không ném
/// exception nào. Test này mở một CSDL đang ở v12 có sẵn dữ liệu thật rồi
/// khẳng định: bảng mới dùng được, dữ liệu cũ nguyên vẹn, và không bản ghi nào
/// bị đẩy vào hàng đợi đồng bộ.
library;

import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';

/// Bảng ở hình dạng **v12** — `budgets.time_recurrence` đã nullable, và chưa
/// có `app_notifications`.
void _createV12Schema(dynamic database) {
  database.execute('''
    CREATE TABLE budgets (
      id TEXT NOT NULL PRIMARY KEY, idaccount INTEGER NOT NULL,
      category_id TEXT, amount REAL NOT NULL, spent REAL NOT NULL DEFAULT 0,
      over_spending TEXT NOT NULL DEFAULT 'Over', over_amount REAL,
      threshold_warning_amount REAL, threshold_warning_percent REAL,
      start_date INTEGER NOT NULL, end_date INTEGER,
      recurrence INTEGER NOT NULL DEFAULT 0, time_recurrence TEXT,
      note TEXT NOT NULL DEFAULT '', next_time_recurrence INTEGER,
      deleted_at INTEGER, is_deleted INTEGER NOT NULL DEFAULT 0,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      sync_retry_count INTEGER NOT NULL DEFAULT 0, sync_error TEXT,
      sync_blocked_until INTEGER, updated_at INTEGER NOT NULL
    )
  ''');
  database.execute('''
    CREATE TABLE bills (
      id TEXT NOT NULL PRIMARY KEY, idaccount INTEGER NOT NULL, wallet_id TEXT,
      category_id TEXT, name TEXT NOT NULL, amount REAL NOT NULL,
      start_date INTEGER, due_date INTEGER NOT NULL,
      pay_status TEXT NOT NULL DEFAULT 'Pending', is_paid INTEGER NOT NULL DEFAULT 0,
      time_notification TEXT, is_recurrence INTEGER NOT NULL DEFAULT 0,
      time_recurrence TEXT NOT NULL DEFAULT 'Month',
      recurrence TEXT NOT NULL DEFAULT 'monthly',
      icon TEXT NOT NULL DEFAULT 'receipt', colour TEXT NOT NULL DEFAULT '#4CAF50',
      note TEXT NOT NULL DEFAULT '', deleted_at INTEGER,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      sync_retry_count INTEGER NOT NULL DEFAULT 0, sync_error TEXT,
      sync_blocked_until INTEGER, updated_at INTEGER NOT NULL
    )
  ''');
  // Ví và giao dịch: migration v13 → v14 thêm cột `goal_id` vào `transactions`,
  // nên fixture phải có bảng ấy. Thiếu nó thì migration nổ với "no such table"
  // — lỗi của fixture chứ không phải của mã.
  database.execute('''
    CREATE TABLE wallets (
      id TEXT NOT NULL PRIMARY KEY, idaccount INTEGER NOT NULL,
      name TEXT NOT NULL, balance REAL NOT NULL DEFAULT 0,
      type TEXT NOT NULL DEFAULT 'cash', deleted_at INTEGER,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      sync_retry_count INTEGER NOT NULL DEFAULT 0, sync_error TEXT,
      sync_blocked_until INTEGER, updated_at INTEGER NOT NULL
    )
  ''');
  database.execute('''
    CREATE TABLE transactions (
      id TEXT NOT NULL PRIMARY KEY, wallet_id TEXT NOT NULL,
      idaccount INTEGER NOT NULL, category_id TEXT, amount REAL NOT NULL,
      type TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'Confirmed',
      provider TEXT NOT NULL DEFAULT 'Manual',
      note TEXT NOT NULL DEFAULT '', date INTEGER NOT NULL,
      images TEXT NOT NULL DEFAULT '[]', wallet_transfer TEXT,
      bank_tran_id TEXT, deleted_at INTEGER,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      sync_retry_count INTEGER NOT NULL DEFAULT 0, sync_error TEXT,
      sync_blocked_until INTEGER, updated_at INTEGER NOT NULL
    )
  ''');
  // v15 thêm ba cột trích tự động vào `goals`, nên fixture phải có bảng ấy —
  // cùng lý do với `wallets` và `transactions` ở trên.
  database.execute('''
    CREATE TABLE goals (
      id TEXT NOT NULL PRIMARY KEY, idaccount INTEGER NOT NULL,
      name TEXT NOT NULL, target_amount REAL NOT NULL,
      current_amount REAL NOT NULL DEFAULT 0, start_date INTEGER,
      target_date INTEGER NOT NULL, wallet_id TEXT,
      cycle_take_money TEXT, time_cycle_take_money INTEGER,
      recurrence INTEGER NOT NULL DEFAULT 0, time_recurrence TEXT,
      icon TEXT NOT NULL DEFAULT 'flag', colour TEXT NOT NULL DEFAULT '#4CAF50',
      note TEXT NOT NULL DEFAULT '',
      is_completed INTEGER NOT NULL DEFAULT 0, deleted_at INTEGER,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      sync_retry_count INTEGER NOT NULL DEFAULT 0, sync_error TEXT,
      sync_blocked_until INTEGER, updated_at INTEGER NOT NULL
    )
  ''');
}

void main() {
  // Drift ở dự án này lưu DateTime dạng Unix **giây**.
  const startSec = 1780315200; // 2026-06-01 12:00 UTC
  const dueSec = 1789000000;
  const updatedSec = 1780401600;

  group('migration v12 lên v13', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory(
        setup: (database) {
          _createV12Schema(database);
          database.execute('''
            INSERT INTO budgets (
              id, idaccount, category_id, amount, spent, threshold_warning_percent,
              start_date, recurrence, time_recurrence, note, sync_status, updated_at
            ) VALUES (
              'b-cu', 7, 'cat-an-uong', 5000000, 4600000, 80,
              $startSec, 1, 'Month', 'ngan sach cu', 'synced', $updatedSec
            )
          ''');
          database.execute('''
            INSERT INTO bills (
              id, idaccount, wallet_id, category_id, name, amount,
              start_date, due_date, time_notification, is_recurrence,
              time_recurrence, sync_status, updated_at
            ) VALUES (
              'hd-cu', 7, 'vi-1', 'cat-hoa-don', 'Tien dien', 300000,
              $startSec, $dueSec, '3', 1, 'Month', 'synced', $updatedSec
            )
          ''');
          database.execute('''
            INSERT INTO wallets (id, idaccount, name, balance, updated_at)
            VALUES ('vi-1', 7, 'Vi tien mat', 2000000, $updatedSec)
          ''');
          database.execute('''
            INSERT INTO transactions (
              id, wallet_id, idaccount, category_id, amount, type,
              note, date, sync_status, updated_at
            ) VALUES (
              'gd-cu', 'vi-1', 7, 'cat-an-uong', 150000, 'chi',
              'Tích lũy mục tiêu: Mua xe', $startSec, 'synced', $updatedSec
            )
          ''');
          database.execute('PRAGMA user_version = 12');
        },
      ));
    });

    tearDown(() => db.close());

    test('bảng thông báo mới dùng được ngay sau migration', () async {
      final chen = await db.notificationDao.insertIfAbsent(
        AppNotificationsCompanion.insert(
          id: 'n1',
          idaccount: 7,
          kind: 'budgetNearLimit',
          dedupeKey: 'budgetNear:b-cu:2026-06-01:critical',
          title: 'Sắp vượt ngân sách',
          body: 'Bạn đã chi tiêu vượt 90% ngân sách Ăn uống',
          severity: 'warning',
          createdAt: DateTime(2026, 9, 4),
        ),
      );
      expect(chen, true);
      expect((await db.notificationDao.getAll(7)).length, 1);
    });

    test('ràng buộc chống trùng được tạo cùng bảng, không bị bỏ sót', () async {
      Future<bool> chen(String id) => db.notificationDao.insertIfAbsent(
            AppNotificationsCompanion.insert(
              id: id,
              idaccount: 7,
              kind: 'budgetNearLimit',
              dedupeKey: 'cung-mot-khoa',
              title: 't',
              body: 'b',
              severity: 'warning',
              createdAt: DateTime(2026, 9, 4),
            ),
          );

      expect(await chen('n1'), true);
      expect(await chen('n2'), false,
          reason: 'createTable phải mang theo cả uniqueKeys. Thiếu ràng buộc '
              'thì migration vẫn chạy êm, chỉ có điều mỗi vòng quét đẻ thêm '
              'một bản sao — hỏng âm thầm đúng nghĩa.');
    });

    test('dữ liệu ngân sách và hoá đơn cũ sống sót nguyên vẹn', () async {
      final ns = await db.budgetDao.getById('b-cu');
      expect(ns, isNotNull);
      expect(ns!.amount, 5000000);
      expect(ns.spent, 4600000);
      expect(ns.thresholdWarningPercent, 80);
      expect(ns.note, 'ngan sach cu');

      final hd = (await db.billDao.getAll(7)).single;
      expect(hd.name, 'Tien dien');
      expect(hd.timeNotification, '3',
          reason: 'Cột này là nguyên liệu cho nhắc hoá đơn — mất nó là mất cấu '
              'hình nhắc của người dùng.');
      expect(hd.timeRecurrence, 'Month');
    });

    test('không bản ghi nào bị đẩy vào hàng đợi đồng bộ', () async {
      expect((await db.budgetDao.getPending(7)).length, 0,
          reason: 'Migration này không sửa dữ liệu. Đánh dấu lại là cần đẩy sẽ '
              'dựng cả CSDL vào hàng đợi và gửi lên backend một lượt.');
      expect((await db.billDao.getPending(7)).length, 0);
      expect((await db.transactionDao.getPending(7)).length, 0);
    });

    group('v13 lên v14 — cột goal_id cục bộ', () {
      test('giao dịch cũ sống sót và nhận goal_id rỗng', () async {
        final gd = (await db.transactionDao.getAll(7)).single;
        expect(gd.id, 'gd-cu');
        expect(gd.amount, 150000);
        expect(gd.note, 'Tích lũy mục tiêu: Mua xe');
        expect(gd.goalId, isNull,
            reason: 'Migration cố ý KHÔNG suy ngược ID mục tiêu từ ghi chú. '
                'Suy ngược chính là phép so bằng tên mà cột này sinh ra để '
                'thay thế, nên nó sẽ đóng băng luôn lỗi tiền tố vào dữ liệu.');
      });

      test('lịch sử tích luỹ cũ vẫn tra được qua nhánh ghi chú', () async {
        final ls = await db.transactionDao
            .watchByGoal(7, 'id-nao-do-khong-khop', 'Mua xe')
            .first;
        expect(ls.length, 1,
            reason: 'Hàng cũ không mang goalId. Bỏ nhánh ghi chú là lịch sử '
                'tích luỹ của người dùng biến mất sau khi cập nhật app.');
      });
    });

    group('v14 lên v15 — ba cột trích tự động', () {
      setUp(() async {
        await db.customStatement(
          // `sync_status` phải là 'synced' như các hàng fixture khác: mặc định
          // của cột là 'pending', và để nguyên thì test "không bản ghi nào bị
          // đẩy vào hàng đợi" đỏ vì chính dữ liệu dựng sẵn chứ không phải vì
          // migration.
          "INSERT INTO goals (id, idaccount, name, target_amount, "
          "current_amount, target_date, cycle_take_money, sync_status, "
          "updated_at) "
          "VALUES ('mt-cu', 7, 'Mua xe', 20000000, 5000000, $dueSec, "
          "'Month', 'synced', $updatedSec)",
        );
      });

      test('mục tiêu cũ sống sót, ba cột mới để trống', () async {
        final mt = (await db.goalDao.getAll(7)).single;
        expect(mt.id, 'mt-cu');
        expect(mt.currentAmount, 5000000);
        expect(mt.autoDepositAmount, isNull);
        expect(mt.autoDepositWalletId, isNull);
        expect(mt.autoDepositLastRun, isNull);
      });

      test('mục tiêu cũ CÓ chu kỳ vẫn KHÔNG bị bật trích tự động', () async {
        final mt = GoalEntity.fromDrift((await db.goalDao.getAll(7)).single);

        expect(mt.cycleTakeMoney, 'Month',
            reason: 'Chu kỳ cũ phải còn nguyên — hộp dự báo đọc nó.');
        expect(mt.autoDepositEnabled, isFalse,
            reason: 'Trang tạo của mọi bản trước đều BẬT SẴN công tắc và luôn '
                'lưu chu kỳ, nên gần như mọi mục tiêu cũ đều mang một chu kỳ. '
                'Suy ra "đã đồng ý cho trích tự động" từ đó là bắt đầu chuyển '
                'tiền của người dùng dựa trên một lựa chọn họ chưa từng đưa '
                'ra — và họ chỉ biết khi thấy số dư ví hụt đi.');
      });

      test('không mục tiêu nào bị đẩy vào hàng đợi đồng bộ', () async {
        expect((await db.goalDao.getPending(7)).length, 0,
            reason: 'Ba cột này là CỤC BỘ. Đánh dấu cần đẩy cho một thay đổi '
                'không có mặt trong payload là đẩy rỗng, và nó xảy ra với mọi '
                'mục tiêu của mọi người dùng ngay sau khi cập nhật app.');
      });
    });
  });
}
