/// Test quét `lib/` thứ **tám**: mọi ô nhập TIỀN phải có trần số chữ số.
///
/// ## Canh chừng điều gì
///
/// Tám cột tiền trên PostgreSQL đều là **`numeric(15,2)`** — `transaction`,
/// `bill`, `budget` (bốn cột), `goal`, `wallet` — tức nhiều nhất **13 chữ số
/// phần nguyên**. Tràn cho SQLSTATE `22003`, mà `sync.service.js` **không có
/// nhánh nào** cho mã ấy nên nó rơi về `DB_ERROR`; và `_permanentCodes` của
/// `SyncEngine` là **danh sách trắng**, `DB_ERROR` không nằm trong đó.
///
/// Kết quả: bản ghi bị **gửi lại ở mọi chu kỳ đồng bộ** — không lỗi, không log,
/// chỉ một hàng đợi càng lúc càng chậm. Đúng vòng lặp mà G31 và G14 sinh ra để
/// chặn, và là lỗ hổng của G45 (ví, 2026-09-18) rồi lặp lại ở **bốn mảng
/// khác** khi soát tiếp cùng ngày.
///
/// ## Vì sao phải quét thay vì tin vào lượt sửa
///
/// Thiếu trần **không gây lỗi nào** lúc gõ: ô vẫn nhận, màn vẫn lưu, SQLite vẫn
/// ghi. Chỉ hàng đợi đẩy là hỏng, và nó hỏng ở nơi không ai nhìn. Một ô tiền
/// mới thêm vào sáu tháng nữa sẽ mở lại đúng lỗ hổng ấy mà không gì báo.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Ô nhập tiền được nhận diện bằng **tên controller**: dự án đặt tên nhất
  /// quán (`_amountController`, `_targetAmountController`, …). Đây là phép
  /// nhận diện thô nhưng đúng chiều an toàn — thêm một ô tiền với tên lạ thì
  /// ca này im, còn đổi tên một ô đã có thì nó kêu.
  const tenOTien = [
    '_amountController',
    '_targetAmountController',
    '_depositAmountController',
    '_thresholdController',
    '_balanceController',
    // Hai ô của sheet "Lọc theo số tiền" ở sổ giao dịch (2026-09-21). Chúng
    // **không ghi gì xuống CSDL** — chỉ lọc danh sách đang hiện — nhưng vẫn
    // phải có trần: một chuỗi 20 chữ số làm `double.tryParse` ra số vô nghĩa và
    // ô nhập phình ra khỏi sheet. Thêm vào đây để lưới quét bắt được, vì phép
    // nhận diện là **tên controller**: đặt tên lạ thì ca này im lặng.
    '_soTienTuController',
    '_soTienDenController',
  ];

  /// Tệp cố ý KHÔNG có trần, kèm lý do. Danh sách này phải **ngắn** và mỗi
  /// dòng phải giải thích được.
  const boQua = <String, String>{
    // Ô phần trăm, không phải ô tiền: `Threshold_Warning_Percent` có CHECK
    // 0–100 và form đã có validator 1–100 riêng.
    '_thresholdPercentController': 'ô phần trăm, đã có validator 1–100',
  };

  test('mọi ô nhập tiền đều có trần số chữ số', () {
    final thieu = <String>[];

    for (final tep in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final ma = tep.readAsStringSync();

      final coOTien = tenOTien.any((t) => ma.contains('controller: $t,'));
      if (!coOTien) continue;

      // Hai cách chặn hợp lệ: bộ lọc của `TextField`, hoặc phép gõ thuần của
      // bàn phím tự vẽ (màn Thêm giao dịch).
      final coTran = ma.contains('GioiHanSoChuSo') ||
          ma.contains('themPhimSoTien');
      if (!coTran) thieu.add(tep.path);
    }

    expect(
      thieu,
      isEmpty,
      reason: 'Những tệp này có ô nhập tiền mà KHÔNG có trần số chữ số:\n'
          '${thieu.join('\n')}\n\n'
          'Tám cột tiền trên PostgreSQL đều là numeric(15,2). Chữ số thứ 14 '
          'cho SQLSTATE 22003, backend trả DB_ERROR, và danh sách lỗi vĩnh '
          'viễn của SyncEngine KHÔNG chứa mã ấy — nên bản ghi bị gửi lại ở mọi '
          'chu kỳ đồng bộ, im lặng.\n\n'
          'Cách sửa: thêm `GioiHanSoChuSo(kSoChuSoToiDaSoTien)` vào '
          '`inputFormatters`. Ô nào cố ý không cần thì ghi vào `boQua` kèm lý '
          'do — danh sách ấy đang có ${boQua.length} dòng.',
    );
  });

  test('bàn phím tự vẽ của màn giao dịch đi qua hàm thuần có trần', () {
    final man = File(
      'lib/features/transaction/presentation/pages/add_transaction_page.dart',
    ).readAsStringSync();

    expect(man.contains('themPhimSoTien'), isTrue,
        reason: 'Màn này không dùng TextField nên `inputFormatters` không với '
            'tới. Phép gõ phải đi qua `ban_phim_so_tien.dart`, nơi trần được '
            'chặn và có test riêng.');
    expect(man.contains("_amountString += key"), isFalse,
        reason: 'Khối gõ viết tay đã được thay. Dựng lại nó là mở lại lỗ hổng '
            'ở đúng chỗ dễ vấp nhất — bàn phím này có phím "000".');
  });
}
