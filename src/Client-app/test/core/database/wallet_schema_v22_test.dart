/// Migration v21 → v22: đánh dấu ví đang lưu trữ để đẩy lại (G28).
///
/// ## Vì sao cần canh
///
/// `wallets.status` bắt đầu đi qua đồng bộ từ 2026-09-14. Nhưng ví đã lưu trữ
/// **trước** bản ấy đang ở `sync_status = 'synced'`, nên nhánh đẩy không bao
/// giờ gửi lại chúng — trong khi cột `Status` của PostgreSQL là `NOT NULL
/// DEFAULT 'Active'`, tức server đang giữ `'Active'` cho đúng những ví ấy.
///
/// Không có bước này thì lượt pull **đầu tiên** sau khi cập nhật app lặng lẽ
/// bỏ lưu trữ chúng: ví quay lại mọi bộ chọn, quay lại tổng tài sản, và hai bộ
/// chạy tự động dùng lại nó — không một dòng log nào.
///
/// Bước này **đủ** vì Push chạy TRƯỚC Pull trong cùng chu kỳ (`_sendBatch` rồi
/// `_pullFromBackend`), nên ví lên tới server trước khi pull đọc về.
///
/// ⚠️ Nó cũng chỉ chạy **một lần trong đời** mỗi máy. Đó là lý do bốn mảnh của
/// G28 phải vào cùng một commit: phát hành migration trước nhánh đẩy là đánh
/// dấu ví, đẩy lên **không kèm `status`**, rồi `synced` lại — và lượt mở đồng
/// bộ sau đó không còn gì để đánh dấu.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';

/// Drift ghi `DateTime` theo **giây** Unix (không phải mili-giây) — chèn
/// mili-giây vào fixture là đọc lại ra năm 58687.
int _giay(int y, int m, int d) =>
    DateTime(y, m, d).millisecondsSinceEpoch ~/ 1000;

/// Bảng `wallets` của một CSDL v21 — lược đồ ví không đổi từ v20.
///
/// Tệp này **cố ý không dựng `bills`**: đặt `PRAGMA user_version = 21` nghĩa là
/// chỉ khối `from < 22` chạy, và khối ấy chỉ đụng `wallets`. Dựng thêm bảng
/// cho vui là thêm chỗ để lệch khi lược đồ thật đổi.
void _createV21Wallets(dynamic database) {
  // Schema v24 (Edge-SLM P2) thêm cột `ai_co_dinh` vào `categories` bằng
  // ALTER TABLE, nên fixture phải CÓ bảng ấy — như `wallets` phải có sẵn cho
  // v20/v22/v23. Hình dạng tối thiểu trước v24 (không có ai_co_dinh).
  database.execute('''
    CREATE TABLE categories (
      id TEXT NOT NULL PRIMARY KEY, idaccount INTEGER NOT NULL,
      name TEXT NOT NULL, classify TEXT NOT NULL,
      icon TEXT NOT NULL DEFAULT 'category', colour TEXT NOT NULL DEFAULT '#4CAF50',
      is_default INTEGER NOT NULL DEFAULT 0, is_deleted INTEGER NOT NULL DEFAULT 0,
      parent_id TEXT, is_group INTEGER NOT NULL DEFAULT 0,
      is_local_only INTEGER NOT NULL DEFAULT 0, deleted_at INTEGER,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      sync_retry_count INTEGER NOT NULL DEFAULT 0, sync_error TEXT,
      sync_blocked_until INTEGER, updated_at INTEGER NOT NULL
    )
  ''');
  database.execute('''
    CREATE TABLE wallets (
      id TEXT NOT NULL PRIMARY KEY, idaccount INTEGER NOT NULL,
      name TEXT NOT NULL, type TEXT NOT NULL DEFAULT 'cash',
      balance REAL NOT NULL DEFAULT 0, currency TEXT NOT NULL DEFAULT 'VND',
      icon TEXT NOT NULL DEFAULT 'wallet', colour TEXT NOT NULL DEFAULT '#4CAF50',
      is_default INTEGER NOT NULL DEFAULT 0, is_deleted INTEGER NOT NULL DEFAULT 0,
      include_in_total INTEGER NOT NULL DEFAULT 1, bank_casso_id TEXT,
      status TEXT NOT NULL DEFAULT 'active',
      sync_status TEXT NOT NULL DEFAULT 'pending',
      sync_retry_count INTEGER NOT NULL DEFAULT 0, sync_error TEXT,
      sync_blocked_until INTEGER, updated_at INTEGER NOT NULL, deleted_at INTEGER
    )
  ''');
}

Future<int> _mocCapNhat(AppDatabase db, String id) async {
  final rows = await db
      .customSelect('SELECT updated_at FROM wallets WHERE id = ?',
          variables: [Variable<String>(id)])
      .get();
  return rows.single.data['updated_at'] as int;
}

Future<String> _trangThaiDongBo(AppDatabase db, String id) async {
  final rows = await db
      .customSelect('SELECT sync_status FROM wallets WHERE id = ?',
          variables: [Variable<String>(id)])
      .get();
  return rows.single.data['sync_status'] as String;
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory(
      setup: (database) {
        _createV21Wallets(database);

        // Ví lưu trữ đã đồng bộ xong. Đây là hàng mà migration phải cứu: server
        // đang giữ 'Active' cho nó, và không ai đẩy lại nữa.
        database.execute('''
          INSERT INTO wallets (id, idaccount, name, status, sync_status, is_deleted, updated_at)
          VALUES ('vi-luu-tru', 7, 'The cu', 'inactive', 'synced', 0, ${_giay(2026, 9, 1)})
        ''');

        // Ví đang dùng — KHÔNG được đụng tới.
        database.execute('''
          INSERT INTO wallets (id, idaccount, name, status, sync_status, is_deleted, updated_at)
          VALUES ('vi-hoat-dong', 7, 'Tien mat', 'active', 'synced', 0, ${_giay(2026, 9, 1)})
        ''');

        // Ví lưu trữ nhưng ĐÃ XOÁ mềm — trạng thái lưu trữ của nó vô nghĩa.
        database.execute('''
          INSERT INTO wallets (id, idaccount, name, status, sync_status, is_deleted, updated_at)
          VALUES ('vi-da-xoa', 7, 'Da xoa', 'inactive', 'synced', 1, ${_giay(2026, 9, 1)})
        ''');

        // Ví lưu trữ vốn đã chờ đẩy — migration không được đổi gì (luỹ đẳng).
        database.execute('''
          INSERT INTO wallets (id, idaccount, name, status, sync_status, is_deleted, updated_at)
          VALUES ('vi-dang-cho', 7, 'Cho day', 'inactive', 'pending', 0, ${_giay(2026, 9, 1)})
        ''');

        // Drift đọc phiên bản CSDL từ `PRAGMA user_version`; đặt 21 để chuỗi
        // migration chạy đúng một bước sang v22. Thiếu dòng này thì Drift coi
        // đây là CSDL mới và không migration nào chạy cả.
        database.execute('PRAGMA user_version = 21');
      },
      logStatements: false,
    ));
  });

  tearDown(() async => db.close());

  test('ví đang lưu trữ được đánh dấu để đẩy lại', () async {
    expect(await _trangThaiDongBo(db, 'vi-luu-tru'), 'pending',
        reason: 'Ví lưu trữ trước khi mở G28 đang ở synced nên nhánh đẩy không '
            'bao giờ gửi lại chúng, trong khi server giữ Active. Không có bước '
            'này thì lượt pull ĐẦU TIÊN sau khi cập nhật app tự bỏ lưu trữ '
            'chúng — im lặng. Push chạy trước Pull trong cùng chu kỳ nên phép '
            'đánh dấu này kịp.');
  });

  test('ví được đánh dấu cũng nhận mốc cập nhật MỚI', () async {
    // ⚠️ Ca này sinh ra từ lượt nghiệm thu máy thật 2026-09-14, sau khi bản
    // migration đầu tiên — chỉ đổi `sync_status` — **hỏng im lặng**.
    //
    // `upsertWallet` phía server chỉ ghi khi
    // `new Date(mapped.update_at) > new Date(existing.update_at)`. Ví lưu trữ
    // cũ ĐÃ từng được đẩy lên (chỉ thiếu cột `status`), nên mốc của nó bằng
    // đúng mốc trên server. Đẩy lại nguyên mốc ấy là **không lớn hơn** → server
    // trả `conflict`, giữ bản của nó, và client `markSynced` để thoát vòng lặp
    // (luật G9). Kết quả: ví lưu trữ cũ KHÔNG BAO GIỜ lên được server, tức
    // bước cứu tự nó hỏng theo đúng cách nó sinh ra để ngăn.
    //
    // Đo thật trên máy ảo: `Sending batch 1 operations` rồi
    // `Push conflict (bản server mới hơn, lấy theo server)` → `0/1 synced`.
    final moc = await _mocCapNhat(db, 'vi-luu-tru');
    expect(moc, greaterThan(_giay(2026, 9, 1)),
        reason: 'Migration phải đẩy `updated_at` lên mốc hiện tại, không giữ '
            'nguyên mốc cũ — nếu không thì LWW của server từ chối hàng ấy và '
            'trạng thái lưu trữ không bao giờ rời khỏi máy này.');
  });

  test('ví KHÔNG được đánh dấu thì giữ nguyên mốc cập nhật', () async {
    expect(await _mocCapNhat(db, 'vi-hoat-dong'), _giay(2026, 9, 1),
        reason: 'Đổi mốc của hàng không cần đẩy là tự tạo một cuộc đua LWW: '
            'máy này sẽ đè lên bản mới hơn của máy khác mà không có lý do gì.');
  });

  test('ví đang hoạt động KHÔNG bị đụng tới', () async {
    expect(await _trangThaiDongBo(db, 'vi-hoat-dong'), 'synced',
        reason: 'Quét cả bảng là ép đẩy lại mọi ví ở lần mở app kế tiếp — một '
            'đợt request thừa cho thứ không hề đổi. Cùng lập luận với v20.');
  });

  test('ví đã xoá mềm KHÔNG bị đánh thức', () async {
    expect(await _trangThaiDongBo(db, 'vi-da-xoa'), 'synced',
        reason: 'Ví đã xoá thì trạng thái lưu trữ của nó vô nghĩa; đẩy lại chỉ '
            'tốn một vòng request.');
  });

  test('ví lưu trữ đang chờ đẩy vẫn ở pending', () async {
    expect(await _trangThaiDongBo(db, 'vi-dang-cho'), 'pending',
        reason: 'Luỹ đẳng: chạy lên hàng đã pending không được đổi gì.');
  });
}
