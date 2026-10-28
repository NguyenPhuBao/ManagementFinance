/// Test quét `lib/` thứ **37** — dữ liệu của NHÀ không lọt vào màn cá nhân (spec gia đình 2026-10-23 mục 7.2 và 10: rủi
/// ro lớn nhất của "nhà là chủ sở hữu thứ ba" là hàng của nhà nằm CÙNG bảng với hàng riêng).
///
/// Luật: mọi câu truy vấn Drift trên năm bảng có cột `idhousehold` (`wallets`, `transactions`, `goals`, `budgets`,
/// `categories`) mà lọc theo tài khoản (`idaccount.equals(`) thì phải ràng cả `idhousehold` (`isNull()` / `isNotNull()` /
/// `equals(`). Thiếu là hàng của nhà — tôi tạo, hoặc chủ nhà tạo mang `idaccount` của chủ — hiện ở Trang chủ, Sổ, Phân
/// tích, Ngân sách, và tổng cá nhân lẫn tiền của nhà, im lặng.
///
/// Đơn vị quét là **câu lệnh** (giữa hai dấu `;`) trong từng thành viên lớp: một hàm có hai truy vấn mà chỉ một câu ràng
/// thì câu kia vẫn đỏ. Phần sau `//` của mỗi dòng bị bỏ trước khi quét. Miễn trừ theo `tệp#thành viên`, mỗi mục một lý do.
///
/// Thấy cả bảng KHÔNG tiền tố (`select(wallets)` trong DAO / `AppDatabase`) lẫn CÓ tiền tố (`db.select(db.wallets)`,
/// `_db.update(_db.categories)` ở repository) — bản đầu chỉ thấy dạng thứ nhất và bỏ sót năm câu ngoài DAO (soát chéo
/// 2026-10-28: số dư cuối kỳ của Phân tích / Báo cáo cộng cả quỹ chung do tôi tạo).
///
/// Giới hạn đã biết (đo 2026-10-24, đo lại 2026-10-28): không đọc SQL thô (`customSelect` / `customStatement`) — ngoài bước di
/// trú không câu thô nào chạm năm bảng; không bắt truy vấn KHÔNG lọc tài khoản (tra theo id, theo cờ `isDefault`) — bốn hàm
/// không lọc gì đã gỡ cùng đợt; không bắt bộ lọc Dart (`_tachKhuon` của `category_dao.dart` lọc lại trong Dart — ca hành vi
/// `du_lieu_nha_khong_lot_test` canh).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _truyVanBangDongBo =
    RegExp(r'\b(?:select|selectOnly|update|delete)\((?:\w+\.)?(?:wallets|transactions|goals|budgets|categories)\)');
final _locTaiKhoan = RegExp(r'idaccount\.equals\(');
final _rangNha = RegExp(r'idhousehold\.(?:isNull|isNotNull|equals)\(');

/// Dòng mở một thành viên lớp: thụt đúng hai dấu cách rồi một ký tự không phải khoảng trắng / chú thích / `@` / đóng.
final _dauThanhVien = RegExp(r'^  [^\s/@})\]]');
final _tenThanhVien = RegExp(r'(_?[A-Za-z]\w*)\s*(?:\(|=>)');

const _lyDoDay = 'đường ĐẨY (2026-10-24): hàng chờ gồm cả hàng tôi ghi vào nhà (`idaccount` = người tạo) — ràng '
    '`idhousehold IS NULL` là hàng của nhà không bao giờ lên server. ⚠️ Ghi nợ lát 2 (sửa danh mục / khoản của nhà): '
    'lọc theo `idaccount` ở lối đẩy là hàng của nhà do NGƯỜI KHÁC tạo mà tôi sửa cục bộ không bao giờ vào lô '
    '(`getSyncableCategories` và khối 1b `thu_gom_day.dart`) — phải đổi thành `idaccount = tôi ∨ idhousehold = nhà tôi`';

/// `tệp#thành viên` → lý do. Mục hết hiệu lực (không còn câu nào thiếu ràng nhà ở đó) làm ca thứ ba đỏ.
const _mienTru = <String, String>{
  'lib/core/database/daos/wallet_dao.dart#getPending': _lyDoDay,
  'lib/core/database/daos/transaction_dao.dart#getPending': _lyDoDay,
  'lib/core/database/daos/budget_dao.dart#getPending': _lyDoDay,
  'lib/core/database/daos/goal_dao.dart#getPending': _lyDoDay,
  'lib/core/database/daos/category_dao.dart#getSyncableCategories': _lyDoDay,
  // TẠM (Task 2, 2026-10-28): Task 3 thêm vế `idhousehold` vào năm câu xoá của phép dọn — Task 3 GỠ dòng này; ca thứ ba
  // đỏ nếu quên.
  'lib/core/database/app_database.dart#purgeDataForOtherAccounts': 'TẠM — Task 3 sửa, gỡ ngay khi Task 3 xong',
};

/// Mọi câu lệnh trong `lib/` có truy vấn năm bảng VÀ lọc tài khoản, kèm `tệp#thành viên` chứa nó.
List<({String noi, String cau})> _cauLocTaiKhoan() {
  final ra = <({String noi, String cau})>[];
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart') || f.path.endsWith('.g.dart')) continue;
    final tep = f.path.replaceAll(r'\', '/');
    var thanhVien = '';
    final cau = StringBuffer();
    void chot() {
      final s = cau.toString();
      cau.clear();
      if (_truyVanBangDongBo.hasMatch(s) && _locTaiKhoan.hasMatch(s)) ra.add((noi: '$tep#$thanhVien', cau: s));
    }

    for (final goc in f.readAsLinesSync()) {
      final cat = goc.indexOf('//');
      final dong = cat < 0 ? goc : goc.substring(0, cat);
      if (_dauThanhVien.hasMatch(dong)) {
        chot();
        thanhVien = _tenThanhVien.firstMatch(dong)?.group(1) ?? thanhVien;
      }
      final manh = dong.split(';');
      for (var i = 0; i < manh.length; i++) {
        cau.writeln(manh[i]);
        if (i < manh.length - 1) chot();
      }
    }
    chot();
  }
  return ra;
}

void main() {
  final cau = _cauLocTaiKhoan();

  test('tiền đề: phép quét thấy các câu lọc tài khoản trên năm bảng', () {
    expect(cau.length, greaterThanOrEqualTo(40),
        reason:
            'đo 2026-10-28 trên HEAD ab633a26: 47 câu (5 DAO + app_database 7 + 3 repository 5). Ít hơn nhiều là mẫu '
            'regex hỏng — phép quét xanh vì mù');
    expect(cau.map((c) => c.noi), contains('lib/core/database/daos/wallet_dao.dart#getAll'));
    expect(cau.map((c) => c.noi), contains('lib/core/database/daos/category_dao.dart#_hangKemKhuon'),
        reason: 'thành viên nắm câu truy vấn danh sách chọn danh mục từ 2026-10-27 — mẫu tên thành viên phải thấy nó');
    expect(cau.map((c) => c.noi),
        contains('lib/features/analytics/data/repositories/analytics_repository_impl.dart#watchKy'),
        reason:
            'bảng có tiền tố (`db.select(db.wallets)`) — mẫu regex phải thấy; bản đầu mù đúng chỗ này (soát chéo C1)');
  });

  test('mọi câu lọc tài khoản trên năm bảng đều ràng idhousehold', () {
    final vi = [
      for (final c in cau)
        if (!_rangNha.hasMatch(c.cau) && !_mienTru.containsKey(c.noi)) c.noi,
    ];
    expect(vi, isEmpty,
        reason:
            'Thêm `& t.idhousehold.isNull()` cạnh vế idaccount. Thiếu là hàng của nhà hiện ở màn cá nhân và cộng vào '
            'tổng cá nhân (spec gia đình mục 10). Lối ĐẨY thì thêm vào _mienTru kèm lý do.');
  });

  test('mỗi miễn trừ còn hiệu lực', () {
    for (final k in _mienTru.keys) {
      expect(cau.any((c) => c.noi == k && !_rangNha.hasMatch(c.cau)), isTrue,
          reason: '$k không còn câu nào cần miễn — gỡ khỏi _mienTru');
    }
  });
}
