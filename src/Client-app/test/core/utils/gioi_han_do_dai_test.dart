/// Giới hạn độ dài tên cho khớp độ rộng cột trên PostgreSQL — G31.
///
/// Vì sao cần: `wallet.Name`, `goal.Name`, `bill.Name` là `varchar(100)` và
/// `category.NameCategory` là `varchar(200)`. Trước bộ lọc này form client không
/// giới hạn gì, nên một tên dài hơn vỡ `P2000` ở `/sync/push`; backend khi ấy
/// trả `DB_ERROR`, và `SyncEngine` xếp mã ấy là lỗi TẠM THỜI — gửi lại bản ghi ở
/// mọi chu kỳ, kéo giãn cách luỹ tiến lên cả hàng đợi, không một lỗi nào hiện
/// ra. Từ `7675b35` backend trả `CONSTRAINT_VIOLATION` (đọc mã 2026-09-11): hết
/// gửi lại, nhưng bản ghi thành lỗi vĩnh viễn và không lên server — nên vẫn
/// phải chặn ở ô nhập.
///
/// Vì sao đếm theo CODE POINT chứ không theo ký tự nhìn thấy: PostgreSQL đếm
/// `varchar(n)` theo code point, còn `maxLength` của Flutter đếm theo cụm
/// grapheme. Chữ "ề" gõ ở dạng tách dấu là 3 code point; emoji gia đình là 5.
/// Giới hạn theo grapheme vẫn để lọt những tên ấy lên server và vỡ y như cũ.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/utils/gioi_han_do_dai.dart';

TextEditingValue _gt(
  String text, {
  int? conTro,
  TextRange composing = TextRange.empty,
}) =>
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: conTro ?? text.length),
      composing: composing,
    );

/// Bộ gõ Telex đang ghép hai chữ "e" cuối thành "ê" — vùng ghép là [4, 6).
final _dangGhep = _gt('abcdee', composing: const TextRange(start: 4, end: 6));

void main() {
  group('catVuaDoRong', () {
    test('chuỗi trong giới hạn thì giữ nguyên', () {
      expect(catVuaDoRong('Tiền điện', 100), 'Tiền điện');
    });

    test('chuỗi dài hơn thì cắt còn đúng giới hạn', () {
      expect(catVuaDoRong('a' * 150, 100), 'a' * 100);
    });

    test('đếm theo code point, và không cắt ngang một chữ có dấu', () {
      // "ề" dạng TÁCH dấu: e + dấu mũ + dấu huyền = 3 code point, 1 chữ.
      const tachDau = 'Tie\u0302\u0300n';

      expect(catVuaDoRong(tachDau, 5), 'Tie\u0302\u0300',
          reason: 'Năm code point đầu là "T", "i" và trọn chữ "ề" — với server '
              'chữ ấy dài 3, không phải 1.');
      expect(catVuaDoRong(tachDau, 4), 'Ti',
          reason: 'Không được cắt ngang chữ "ề": giữ lại "Tie" là bỏ mất dấu '
              'người dùng đã gõ và tự bịa ra một chữ khác.');
    });

    test('emoji ghép bằng ZWJ là 5 code point, và không bị cắt ngang', () {
      const giaDinh = '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}';
      expect(giaDinh.runes.length, 5);

      expect(catVuaDoRong('ab$giaDinh', 6), 'ab',
          reason: 'Giữ nửa emoji là để lại một ký tự rác trong tên. Và đếm theo '
              'grapheme (3) thay vì code point (7) là để lọt lên server.');
      expect(catVuaDoRong('ab$giaDinh', 7), 'ab$giaDinh');
    });
  });

  group('GioiHanDoRong', () {
    const catNgay = GioiHanDoRong(5, cheDo: MaxLengthEnforcement.enforced);
    const choGhepXong = GioiHanDoRong(
      5,
      cheDo: MaxLengthEnforcement.truncateAfterCompositionEnds,
    );

    test('trong giới hạn thì để yên', () {
      final moi = _gt('abc');
      expect(catNgay.formatEditUpdate(_gt('ab'), moi), moi);
    });

    test('dán vượt giới hạn thì cắt, và con trỏ không vượt cuối chuỗi', () {
      final kq = catNgay.formatEditUpdate(_gt(''), _gt('abcdefgh'));

      expect(kq.text, 'abcde');
      expect(kq.selection, const TextSelection.collapsed(offset: 5),
          reason: 'Con trỏ giữ vị trí 8 trên chuỗi dài 5 là ném RangeError '
              'ở lần gõ kế tiếp.');
    });

    test('đã đủ giới hạn mà gõ thêm thì giữ nguyên chuỗi cũ', () {
      final cu = _gt('abcde', conTro: 2);
      final kq = catNgay.formatEditUpdate(cu, _gt('abXcde', conTro: 3));

      expect(kq, cu,
          reason: 'Con trỏ đang ở GIỮA chuỗi. Cắt đuôi thì chữ "X" vừa gõ được '
              'giữ, còn chữ "e" ở cuối — thứ người dùng không đụng tới — biến '
              'mất mà không ai thấy.');
    });

    test('chế độ cắt ngay thì cắt cả khi bộ gõ đang ghép chữ', () {
      expect(catNgay.formatEditUpdate(_gt('abcd'), _dangGhep).text, 'abcde',
          reason: 'Đây là chế độ mặc định của Android. Chờ ghép xong mới cắt thì '
              'người dùng bấm Lưu lúc chữ cuối chưa chốt vẫn lưu được tên dài '
              'hơn cột — đúng lỗi đang sửa.');
    });

    test('chế độ chờ ghép xong thì chưa cắt giữa phiên ghép', () {
      expect(choGhepXong.formatEditUpdate(_gt('abcd'), _dangGhep), _dangGhep,
          reason: 'Chế độ mặc định của iOS và web, nơi chữ đang ghép còn là '
              'dạng trung gian của bộ gõ: cắt lúc ấy làm hỏng phiên ghép.');
    });

    test('chế độ chờ ghép xong: ghép xong mà vẫn vượt thì cắt', () {
      final kq = choGhepXong.formatEditUpdate(_dangGhep, _gt('abcdêf'));

      expect(kq.text, 'abcdê');
    });

    test('không truyền chế độ thì theo mặc định nền tảng, như maxLength',
        () {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const macDinh = GioiHanDoRong(5);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(macDinh.formatEditUpdate(_gt('abcd'), _dangGhep).text, 'abcde',
          reason: 'Android: cắt ngay, như `maxLength` của Flutter.');

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(macDinh.formatEditUpdate(_gt('abcd'), _dangGhep), _dangGhep,
          reason: 'iOS: chờ ghép xong, như `maxLength` của Flutter. Tự chọn '
              'chính sách khác Flutter là tự gánh những ca bộ gõ mà Flutter '
              'đã phải xử lý.');
    });
  });

  test('độ rộng khớp cột trên PostgreSQL', () {
    expect(DoRongCot.tenVi, 100);
    expect(DoRongCot.tenMucTieu, 100);
    expect(DoRongCot.tenHoaDon, 100);
    expect(DoRongCot.tenDanhMuc, 200,
        reason: 'Đo 2026-09-10 bằng information_schema.columns: wallet, goal, '
            'bill "Name" varchar(100); category "NameCategory" varchar(200). '
            'Đổi số ở đây mà không đo lại CSDL là mở lại G31.');
  });
}
