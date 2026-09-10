import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

/// Thứ tự danh sách ví.
///
/// Trước bản này `getAll`/`watchAll` sắp theo `updatedAt` giảm dần, và mọi giao
/// dịch đều cập nhật `updatedAt` của ví qua `walletDao.updateBalance` — nên
/// danh sách ví **tự xáo lại mỗi lần người dùng ghi chép**. Đó cũng là lý do
/// thiết kế Stitch có nút "SẮP XẾP" trên màn Quản lý ví: không có thứ tự nào để
/// giữ.
///
/// ⚠️ `walletDao.getAll` được gọi từ 14 chỗ — hoá đơn, mục tiêu, ngân sách,
/// phân tích, thêm giao dịch, `SyncEngine`. Đổi thứ tự ở đây là đổi thứ tự MỌI
/// bộ chọn ví trong app, có chủ ý: chúng phải giống nhau.
///
/// Bảng `wallets` **không có `createdAt`**, nên tên là mốc ổn định duy nhất
/// hiện có. Khi làm tính năng sắp xếp tay, cột thứ tự chèn vào **trước** hai
/// khoá này chứ không thay chúng.
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
    bool isDefault = false,
    required DateTime updatedAt,
  }) async {
    await db.walletDao.insert(WalletsCompanion.insert(
      id: 'w_$name',
      idaccount: idaccount,
      name: name,
      isDefault: Value(isDefault),
      updatedAt: updatedAt,
    ));
  }

  Future<List<String>> ten() async =>
      (await db.walletDao.getAll(idaccount)).map((w) => w.name).toList();

  test('sắp theo tên, KHÔNG theo lần sửa gần nhất', () async {
    // `updatedAt` cố ý ngược hẳn thứ tự tên: luật cũ trả về đúng chiều ngược
    // lại, nên đây là ca phân biệt được hai cách cài đặt.
    await them('An', updatedAt: DateTime(2026, 9, 1));
    await them('Bao', updatedAt: DateTime(2026, 9, 5));
    await them('Cuc', updatedAt: DateTime(2026, 9, 9));

    expect(await ten(), ['An', 'Bao', 'Cuc'],
        reason: 'Mỗi giao dịch đều bump `updatedAt` của ví, nên sắp theo cột '
            'ấy là danh sách ví đổi chỗ ngay khi người dùng ghi một khoản chi.');
  });

  test('ví mặc định luôn đứng đầu, bất kể tên và lần sửa', () async {
    await them('An', updatedAt: DateTime(2026, 9, 9));
    await them('Zalo Pay', isDefault: true, updatedAt: DateTime(2026, 9, 1));

    expect((await ten()).first, 'Zalo Pay',
        reason: 'Thiết kế Stitch vẽ ví mặc định ở đầu danh sách kèm nhãn '
            '"MẶC ĐỊNH", và nó cũng là ví được chọn sẵn khi ghi giao dịch.');
  });

  test('chữ hoa và chữ thường không bị tách thành hai khối', () async {
    // Phép so mặc định của SQLite là nhị phân: 'Z' (90) đứng trước 'v' (118),
    // nên không có `lower()` thì "Zalo Pay" nhảy lên trước "ví chính".
    await them('ví chính', updatedAt: DateTime(2026, 9, 1));
    await them('Zalo Pay', updatedAt: DateTime(2026, 9, 2));

    expect(await ten(), ['ví chính', 'Zalo Pay'],
        reason: 'Người dùng đặt tên ví tuỳ ý chữ hoa chữ thường; xếp mọi tên '
            'viết hoa lên trước là thứ tự trông như ngẫu nhiên.');
  });

  test('watchAll trả cùng thứ tự với getAll', () async {
    // Ba phương thức đọc, một luật. Màn Quản lý ví dùng `getAll` qua Cubit,
    // nhưng các chỗ khác dựng `StreamBuilder` trên `watchAll` — hai thứ tự
    // khác nhau là cùng một danh sách ví hiện hai kiểu ở hai màn.
    await them('Cuc', updatedAt: DateTime(2026, 9, 9));
    await them('An', updatedAt: DateTime(2026, 9, 1));
    await them('Bao', isDefault: true, updatedAt: DateTime(2026, 9, 5));

    final theoStream = (await db.walletDao.watchAll(idaccount).first)
        .map((w) => w.name)
        .toList();

    expect(theoStream, await ten(),
        reason: 'Hai đường đọc cùng một bảng phải cho cùng một thứ tự.');
  });
}
