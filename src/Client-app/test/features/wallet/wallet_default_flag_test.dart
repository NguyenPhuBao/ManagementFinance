import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/wallet/data/datasources/wallet_local_data_source.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bất biến "mỗi tài khoản có nhiều nhất MỘT ví mặc định".
///
/// Trước bản này chỉ đường THÊM ví giữ bất biến ấy (`WalletRepositoryImpl
/// .addWallet` xoá cờ của ví cũ), còn đường SỬA ví thì ghi thẳng. Sửa một ví
/// thứ hai thành mặc định là có hai hàng cùng cờ — và `WalletDao.getDefault`
/// dùng `getSingleOrNull()`, thứ **ném lỗi** khi có hơn một hàng. Đường đi thật
/// tới lỗi: đặt A mặc định → sửa B thành mặc định → thêm ví C có tích "đặt làm
/// mặc định" → `addWallet` gọi `getDefault` → nổ, người dùng thấy `WalletError`.
///
/// Không có unique index nào chặn ở cả SQLite lẫn PostgreSQL (đo `pg_constraint`
/// ngày 2026-09-09), nên bất biến này chỉ do mã giữ.
///
/// ⚠️ Có HAI luật độc lập ở đây, và một bản sai có chủ ý đã chứng minh chúng
/// cần hai ca test riêng: phép **thoát sớm** ở `_giuMotViMacDinh` (không mặc
/// định thì đừng chạy gì cả) và câu **`WHERE`** của `clearDefaultExcept` (chỉ
/// chạm hàng đang mang cờ). Gỡ `isDefault.equals(true)` khỏi câu `WHERE` đi lọt
/// qua ca thoát sớm, vì ca ấy không bao giờ chạy tới câu `WHERE`.
void main() {
  late AppDatabase db;
  late WalletLocalDataSourceImpl dataSource;

  const idaccount = 7;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dataSource = WalletLocalDataSourceImpl(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  /// Ghi thẳng qua DAO để dựng trạng thái đầu vào — cố ý KHÔNG đi qua
  /// datasource, vì đây là đường mà `SyncEngine.upsertAll` dùng khi kéo dữ liệu
  /// về, tức đường có thật sinh ra hai hàng mặc định.
  Future<void> ghiThang(
    String id, {
    required bool isDefault,
    String syncStatus = 'synced',
    DateTime? updatedAt,
  }) async {
    await db.walletDao.insert(WalletsCompanion.insert(
      id: id,
      idaccount: idaccount,
      name: 'Ví $id',
      isDefault: Value(isDefault),
      syncStatus: Value(syncStatus),
      updatedAt: updatedAt ?? DateTime(2026, 9, 1),
    ));
  }

  WalletEntity vi(String id, {required bool isDefault}) => WalletEntity(
        id: id,
        idaccount: idaccount,
        name: 'Ví $id',
        type: 'cash',
        balance: 0,
        isDefault: isDefault,
        updatedAt: DateTime(2026, 9, 2),
      );

  Future<List<String>> viMacDinh() async => (await db.walletDao.getAll(idaccount))
      .where((w) => w.isDefault)
      .map((w) => w.id)
      .toList();

  test('sửa một ví thành mặc định thì ví mặc định cũ mất cờ', () async {
    await ghiThang('a', isDefault: true);
    await ghiThang('b', isDefault: false);

    await dataSource.update(vi('b', isDefault: true));

    expect(await viMacDinh(), ['b'],
        reason: 'Đường SỬA phải giữ đúng bất biến mà đường THÊM đã giữ. Hai '
            'hàng cùng cờ là trạng thái làm `getDefault` ném lỗi.');
  });

  test('thêm một ví mặc định thì ví mặc định cũ cũng mất cờ', () async {
    // Đường THÊM vốn đã được bảo vệ, nhưng chốt ấy đã chuyển từ repository
    // xuống datasource. Ca này canh việc chuyển nhà không làm mất tính năng.
    await ghiThang('a', isDefault: true);

    await dataSource.insert(vi('b', isDefault: true));

    expect(await viMacDinh(), ['b'],
        reason: 'Chốt bảo vệ đường thêm đã rời `WalletRepositoryImpl.addWallet` '
            'xuống datasource — nó phải còn nguyên tác dụng ở chỗ mới.');
  });

  test('ví bị xoá cờ mặc định phải thành pending để lan sang máy khác', () async {
    await ghiThang('a', isDefault: true, syncStatus: 'synced');
    await ghiThang('b', isDefault: false);

    await dataSource.update(vi('b', isDefault: true));

    expect((await db.walletDao.getById('a'))?.syncStatus, 'pending',
        reason: 'Xoá cờ mà không đánh dấu pending thì máy này có một ví mặc '
            'định còn máy kia vẫn có hai — và không lần đẩy nào sửa được, vì '
            'hàng ấy không bao giờ vào hàng đợi.');
  });

  test('lưu ví KHÔNG mặc định thì không chạy phép xoá cờ nào cả', () async {
    // Ca này canh phép THOÁT SỚM ở `_giuMotViMacDinh`, KHÔNG canh câu `WHERE`
    // của `clearDefaultExcept` — bản sai gỡ `isDefault.equals(true)` đi lọt qua
    // đây, vì luồng thoát sớm không bao giờ chạy tới câu `WHERE`. Câu ấy có ca
    // riêng ngay dưới.
    await ghiThang('a', isDefault: true, syncStatus: 'synced');
    await ghiThang('b', isDefault: false, syncStatus: 'synced');

    await dataSource.update(vi('b', isDefault: false));

    expect(await viMacDinh(), ['a'],
        reason: 'Lưu một ví không mặc định không được cướp cờ của ví khác.');
    expect((await db.walletDao.getById('a'))?.syncStatus, 'synced',
        reason: 'Cũng không được đẩy ví ấy vào hàng đợi: nó không hề đổi.');
  });

  test('phép xoá cờ chỉ chạm hàng ĐANG mang cờ mặc định', () async {
    // Ca dành riêng cho câu `WHERE`. Ví 'thuong' là hàng "không được đụng" và
    // nó mang sẵn dấu vết phân biệt được: KHÔNG mặc định và đã `synced`. Vì lần
    // lưu này CÓ đặt mặc định, phép xoá cờ chạy thật — nên nếu câu `WHERE`
    // thiếu chốt `isDefault`, nó quét cả bảng và kéo 'thuong' về `pending`.
    await ghiThang('cu', isDefault: true, syncStatus: 'synced');
    await ghiThang('thuong', isDefault: false, syncStatus: 'synced');
    await ghiThang('moi', isDefault: false, syncStatus: 'synced');

    await dataSource.update(vi('moi', isDefault: true));

    expect((await db.walletDao.getById('cu'))?.syncStatus, 'pending',
        reason: 'Hàng mất cờ thì phải vào hàng đợi.');
    expect((await db.walletDao.getById('thuong'))?.syncStatus, 'synced',
        reason: 'Hàng không mang cờ thì không liên quan. Thiếu chốt '
            '`isDefault.equals(true)` là mỗi lần đặt ví mặc định lại làm bẩn '
            'cả bảng, sinh ra một loạt lần đẩy vô ích.');
  });

  test('getDefault không ném khi dữ liệu kéo về có hai ví mặc định', () async {
    // Trạng thái này đến từ server: máy khác hoặc Admin-web đặt cờ, `upsertAll`
    // ghi thẳng, không qua chốt nào của client. Làm nổ luồng "thêm ví" vì dữ
    // liệu người khác gửi về là sai — client phải đọc được một câu trả lời
    // xác định.
    await ghiThang('cu', isDefault: true, updatedAt: DateTime(2026, 9, 1));
    await ghiThang('moi', isDefault: true, updatedAt: DateTime(2026, 9, 5));

    expect((await db.walletDao.getDefault(idaccount))?.id, 'moi',
        reason: 'Hai hàng cùng cờ thì lấy hàng ĐƯỢC SỬA GẦN NHẤT — ý định mới '
            'nhất của người dùng. `getSingleOrNull()` ném `StateError` ở đây.');
  });
}
