import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lưu trữ ví ở tầng DAO — phép lọc "ví còn dùng được".
///
/// Lưu trữ là **đóng băng**, không phải xoá: ví lưu trữ phải biến khỏi mọi bộ
/// chọn ví, nhưng vẫn **đọc được** ở màn Quản lý ví, ở bảng tra tên ví của sổ
/// giao dịch và báo cáo, và ở đường đồng bộ.
///
/// Vì thế có **hai** phép đọc chứ không phải một:
///
/// - `getAll`/`watchAll` — mọi ví chưa xoá, **kể cả lưu trữ**. Đổi nghĩa hai
///   hàm này là dòng giao dịch cũ thuộc ví lưu trữ hiện "Ví đã xoá".
/// - `getActive`/`watchActive` — chỉ ví đang hoạt động. Đây là thứ mà các bộ
///   chọn ví phải gọi.
///
/// Cột `status` **đã có sẵn** trong SQLite từ trước (mặc định `'active'`), nên
/// tính năng này KHÔNG cần migration — schema vẫn v20.
void main() {
  late AppDatabase db;
  const idaccount = 7;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> them(
    String name, {
    String? status,
    bool isDefault = false,
    double balance = 0,
  }) async {
    await db.walletDao.insert(WalletsCompanion.insert(
      id: 'w_$name',
      idaccount: idaccount,
      name: name,
      isDefault: Value(isDefault),
      balance: Value(balance),
      status: status == null ? const Value.absent() : Value(status),
      updatedAt: DateTime(2026, 9, 10),
    ));
  }

  Future<List<String>> tenHoatDong() async =>
      (await db.walletDao.getActive(idaccount)).map((w) => w.name).toList();

  test('ví mới không khai status thì mặc định là ĐANG HOẠT ĐỘNG', () async {
    await them('Tien mat');

    expect(await tenHoatDong(), ['Tien mat'],
        reason: 'Mặc định của cột là "active". Nếu ví mới không lọt qua phép '
            'lọc thì mọi bộ chọn ví rỗng ngay sau khi người dùng tạo ví đầu '
            'tiên — hỏng im lặng, không thông báo nào.');
  });

  test('getActive bỏ ví lưu trữ, getAll thì giữ', () async {
    await them('Tien mat');
    await them('The cu', status: 'inactive');

    expect(await tenHoatDong(), ['Tien mat']);
    expect((await db.walletDao.getAll(idaccount)).map((w) => w.name).toList(),
        ['The cu', 'Tien mat'],
        reason: 'Màn Quản lý ví, bảng tra tên ví của sổ giao dịch/báo cáo, và '
            'đường đồng bộ đều phải còn thấy ví lưu trữ. Lọc luôn ở getAll là '
            'dòng giao dịch cũ hiện "Ví đã xoá".');
  });

  test('getActive giữ nguyên thứ tự hiển thị chung', () async {
    await them('Cuc');
    await them('An');
    await them('Bao', isDefault: true);

    expect(await tenHoatDong(), ['Bao', 'An', 'Cuc'],
        reason: 'Chỉ có MỘT định nghĩa thứ tự ví (_thuTuHienThi: mặc định lên '
            'đầu, rồi tên). Phép lọc mới không được đẻ ra thứ tự thứ hai.');
  });

  test('getActive vẫn bỏ ví đã xoá mềm', () async {
    await them('Con song');
    await them('Da xoa');
    await db.walletDao.softDelete('w_Da xoa');

    expect(await tenHoatDong(), ['Con song'],
        reason: 'Lưu trữ là một trạng thái ĐỘC LẬP với xoá mềm; phép lọc mới '
            'phải cộng thêm vào chốt cũ chứ không thay nó.');
  });

  test('getActive không nhìn sang tài khoản khác', () async {
    await them('Cua toi');
    await db.walletDao.insert(WalletsCompanion.insert(
      id: 'w_nguoi_khac',
      idaccount: 99,
      name: 'Cua nguoi khac',
      updatedAt: DateTime(2026, 9, 10),
    ));

    expect(await tenHoatDong(), ['Cua toi']);
  });

  test('watchActive phát lại khi một ví bị lưu trữ', () async {
    await them('Tien mat');
    await them('The cu');

    final phat = db.watchActiveNames(idaccount);

    expect(
      phat,
      emitsInOrder([
        ['The cu', 'Tien mat'],
        ['Tien mat'],
      ]),
    );

    // Cho stream phát lần đầu trước khi đổi dữ liệu.
    await Future<void>.delayed(Duration.zero);
    await db.walletDao.setStatus('w_The cu', luuTru: true);
  });

  test('setStatus đánh dấu pending để trạng thái đi ra được máy khác', () async {
    await them('The cu');
    await db.walletDao.markSynced('w_The cu');

    await db.walletDao.setStatus('w_The cu', luuTru: true);

    final w = await db.walletDao.getById('w_The cu');
    expect(w!.status, 'inactive');
    expect(w.syncStatus, 'pending',
        reason: 'Không vào hàng đợi đẩy thì máy này thấy ví đã lưu trữ còn máy '
            'kia vẫn thấy nó trong mọi bộ chọn, vĩnh viễn — cùng bài học với '
            'clearDefaultExcept.');
  });

  test('setStatus bỏ lưu trữ đưa ví về lại danh sách hoạt động', () async {
    await them('The cu', status: 'inactive');

    await db.walletDao.setStatus('w_The cu', luuTru: false);

    expect(await tenHoatDong(), ['The cu']);
    expect((await db.walletDao.getById('w_The cu'))!.status, 'active');
  });
}

extension on AppDatabase {
  /// Lối tắt cho ca stream — giữ phần `expect` đọc được.
  Stream<List<String>> watchActiveNames(int idaccount) =>
      walletDao.watchActive(idaccount).map((rows) => [
            for (final w in rows) w.name,
          ]);
}
