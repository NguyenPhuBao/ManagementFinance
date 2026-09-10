import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Mọi chỗ trong `lib/` đọc **danh sách ví** phải được phân loại rõ ràng.
///
/// Sau khi có tính năng lưu trữ ví, có **hai** phép đọc danh sách chứ không
/// còn một:
///
/// - `getActive` / `watchActive` — chỉ ví đang hoạt động. Đây là thứ **mọi bộ
///   chọn ví** phải gọi: thêm giao dịch, hoá đơn, mục tiêu, ngân sách.
/// - `getAll` / `watchAll` — mọi ví chưa xoá, **kể cả lưu trữ**. Chỉ đúng ở
///   những chỗ cần thấy ví lưu trữ: màn Quản lý ví, bảng tra tên ví của sổ
///   giao dịch và báo cáo, và đường đồng bộ.
///
/// Chọn nhầm giữa hai hàm **không gây lỗi nào**: bộ chọn gọi `getAll` thì ví
/// lưu trữ hiện lại như chưa từng cất đi, còn bảng tra tên gọi `getActive` thì
/// dòng giao dịch cũ hiện "Ví đã xoá". Cả hai đều im lặng, đúng loại lỗi mà
/// quy tắc 4 của dự án nói tới — nên chỗ gọi phải được liệt kê tay ở đây,
/// giống cách `currency_formatter_test` quét cả `lib/` để cấm dựng
/// `NumberFormat` ngoài một chỗ.
///
/// Thêm một chỗ gọi mới mà quên cập nhật danh sách này thì test đỏ, và người
/// thêm buộc phải trả lời câu hỏi "chỗ này có được thấy ví lưu trữ không?".
void main() {
  /// Các tệp được phép đọc **mọi** ví, kèm lý do. Đường dẫn tương đối `lib/`.
  const duocDocMoiVi = <String, String>{
    'core/database/app_database.dart':
        'Chỉ là chú thích tài liệu ở đầu tệp, không phải chỗ gọi thật.',
    'core/database/daos/wallet_dao.dart':
        'Chính nó — `getActive` được dựng bằng cách lọc trên `getAll`.',
    'core/sync/sync_engine.dart':
        'Đồng bộ phải đẩy và kéo cả ví lưu trữ, nếu không trạng thái ấy không '
            'bao giờ ra khỏi được máy này.',
    'core/di/injection_container.dart':
        'Vòng quét thông báo: nó cần biết cả ví lưu trữ để không nhắc về ví đã '
            'cất đi một cách sai lệch.',
    'features/analytics/data/bao_cao_repository_impl.dart':
        'Bảng tra TÊN ví cho từng dòng báo cáo — giao dịch cũ vẫn trỏ vào ví '
            'nay đã lưu trữ, và chúng phải hiện đúng tên.',
    'features/home/presentation/pages/home_page.dart':
        'Bảng tra tên ví cho "Giao dịch gần đây", và tổng tài sản — phép cộng '
            'ấy tự lọc bằng `viTinhVaoTong` chứ không lọc bằng phép đọc.',
    'features/transaction/presentation/pages/transaction_page.dart':
        'Bảng tra tên ví cho sổ giao dịch.',
    'features/wallet/data/datasources/wallet_local_data_source.dart':
        'Màn Quản lý ví phải thấy cả hai nhóm để còn bỏ lưu trữ được. Và '
            'chốt `_kiemRangBuocServer` phải nhìn CẢ ví lưu trữ: hai partial '
            'unique index của server không nhìn `Status`.',
    'features/bill/presentation/pages/bill_page.dart':
        'Bảng tra tên ví (`TransactionLookup`) cho thẻ hoá đơn, KHÔNG phải '
            'bộ chọn — hoá đơn cũ trỏ vào ví nay đã lưu trữ vẫn phải hiện '
            'đúng tên.',
    'features/bill/presentation/pages/bill_detail_page.dart':
        'Cũng là bảng tra tên: trang chi tiết dựng `TransactionLookup` cho '
            'chuỗi kỳ và lịch sử trả.',
    'features/budget/data/datasources/budget_local_data_source.dart':
        '`getWallets` chỉ nuôi `BudgetRepositoryImpl.lookupFor`, tức lại là '
            'một bảng tra tên chứ không phải bộ chọn ví.',
  };

  /// Các tệp là **bộ chọn ví** — chúng phải gọi `getActive`/`watchActive`.
  const laBoChonVi = <String>{
    'features/transaction/presentation/pages/add_transaction_page.dart',
    'features/bill/presentation/pages/bill_add_page.dart',
    'features/bill/presentation/pages/bill_edit_page.dart',
    'features/bill/presentation/widgets/bill_actions.dart',
    'features/goal/presentation/pages/goal_detail_page.dart',
  };

  late Map<String, String> noiDung;

  setUpAll(() {
    noiDung = {};
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('.g.dart')) continue;
      final key = f.path.replaceAll(r'\', '/').substring('lib/'.length);
      noiDung[key] = f.readAsStringSync();
    }
  });

  Set<String> tepChua(String mau) =>
      {for (final e in noiDung.entries) if (e.value.contains(mau)) e.key};

  test('không chỗ nào ngoài danh sách được đọc MỌI ví', () {
    final thay = {
      ...tepChua('walletDao.getAll('),
      ...tepChua('walletDao.watchAll('),
    };

    expect(thay.difference(duocDocMoiVi.keys.toSet()), isEmpty,
        reason: 'Một chỗ gọi mới `getAll`/`watchAll` chưa được phân loại. Nếu '
            'đó là bộ chọn ví thì phải đổi sang `getActive`/`watchActive`; nếu '
            'nó thật sự cần thấy ví lưu trữ thì thêm vào `duocDocMoiVi` kèm lý '
            'do. Chọn nhầm KHÔNG gây lỗi nào — nó chỉ làm ví đã cất đi hiện '
            'lại, im lặng.');
  });

  test('mọi bộ chọn ví đều đọc qua getActive/watchActive', () {
    for (final tep in laBoChonVi) {
      expect(noiDung.containsKey(tep), isTrue,
          reason: 'Tệp "$tep" không còn tồn tại — sửa lại danh sách.');

      final doc = noiDung[tep]!;
      expect(doc.contains('walletDao.getActive(') ||
              doc.contains('walletDao.watchActive('),
          isTrue,
          reason: 'Bộ chọn ví "$tep" không gọi getActive/watchActive, nên ví '
              'đã lưu trữ vẫn hiện ra cho người dùng chọn — và ghi được giao '
              'dịch mới vào một ví lẽ ra đã đóng băng.');
      expect(doc.contains('walletDao.getAll(') ||
              doc.contains('walletDao.watchAll('),
          isFalse,
          reason: 'Bộ chọn ví "$tep" còn một đường đọc MỌI ví. Hai đường song '
              'song là một trong hai chỗ sẽ lệch, im lặng.');
    }
  });

  test('mọi phép cộng tổng tài sản đều đi qua viTinhVaoTong', () {
    // Luật này từng tồn tại ở BỐN bản chép tay không khớp nhau. Ba trong số đó
    // quên hẳn phép lọc `includeInTotal`, nên ví người dùng đã cố ý loại ra
    // vẫn phình con số — ở trang chủ, ở "số dư cuối kỳ" của báo cáo, và một
    // nhịp trên màn Quản lý ví (`6fd2ce9`).
    const congTongTaiSan = <String>{
      'features/home/presentation/pages/home_page.dart',
      'features/analytics/data/bao_cao_repository_impl.dart',
      'features/wallet/data/repositories/wallet_repository_impl.dart',
    };

    for (final tep in congTongTaiSan) {
      expect(noiDung[tep]?.contains('viTinhVaoTong'), isTrue,
          reason: 'Tệp "$tep" cộng số dư ví mà không đi qua định nghĩa duy '
              'nhất. Một bản chép tay nữa là một con số nữa lệch với ba con số '
              'còn lại — và người dùng thấy ba con số khác nhau cho cùng một '
              'thứ.');
    }
  });
}
