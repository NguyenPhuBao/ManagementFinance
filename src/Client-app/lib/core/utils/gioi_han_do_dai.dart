/// Giữ tên người dùng gõ nằm trong độ rộng cột chuỗi trên PostgreSQL — G31.
///
/// ## Vì sao có tệp này
///
/// `wallet.Name`, `goal.Name`, `bill.Name` là `varchar(100)` và
/// `category.NameCategory` là `varchar(200)` (đo 2026-09-10 bằng
/// `information_schema.columns`). Tên dài hơn vỡ `P2000` ở `/sync/push`. Trước
/// `7675b35` backend không ánh xạ mã ấy nên trả `DB_ERROR`, mà `SyncEngine` xếp
/// `DB_ERROR` là lỗi tạm thời: bản ghi bị gửi lại ở mọi chu kỳ, không lỗi nào
/// hiện ra. Nay `sync.service.js` đưa `22001`/`P2000` về `CONSTRAINT_VIOLATION`
/// (đọc mã 2026-09-11), mã client xếp **vĩnh viễn**: hết vòng gửi lại, nhưng bản
/// ghi đứng lỗi hẳn và không bao giờ lên server. Riêng ví thì server cắt âm thầm
/// còn 100 ký tự rồi kéo bản đã cắt về máy.
///
/// Tài liệu xin phía server (đã đóng):
/// `docs/superpowers/backend/DA-XONG/SYNC_PUSH_ERROR_MAPPING.md`. Client vẫn
/// chặn ở ô nhập: đó là chỗ duy nhất người dùng thấy giới hạn lúc đang gõ, và
/// là cách duy nhất để một tên dài không biến bản ghi thành lỗi vĩnh viễn.
///
/// ## Vì sao không dùng `maxLength`
///
/// Hai lý do. PostgreSQL đếm `varchar(n)` theo **code point**, còn `maxLength`
/// và `LengthLimitingTextInputFormatter` đếm theo **cụm grapheme** — nên để lọt
/// chữ có dấu gõ ở dạng tách (3 code point một chữ) và emoji ghép (5 trở lên).
/// Và `maxLength` vẽ thêm bộ đếm "0/100" dưới ô, thứ mà thiết kế Stitch của cả
/// bảy ô tên đều không có (dò HTML ngày 2026-09-10).
///
/// Mọi thứ khác theo **đúng chính sách của Flutter**, kể cả việc có cắt giữa lúc
/// bộ gõ đang ghép chữ hay không — để khỏi tự gánh những ca bộ gõ mà Flutter đã
/// xử lý.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

/// Độ rộng cột mà mỗi loại tên phải nằm trong — một định nghĩa cho cả app.
abstract final class DoRongCot {
  /// `wallet."Name"` — `varchar(100)`.
  static const int tenVi = 100;

  /// `goal."Name"` — `varchar(100)`.
  static const int tenMucTieu = 100;

  /// `bill."Name"` — `varchar(100)`.
  static const int tenHoaDon = 100;

  /// `category."NameCategory"` — `varchar(200)`. Nhóm danh mục cũng là một
  /// hàng `category`, nên dùng chung con số này.
  static const int tenDanhMuc = 200;
}

/// Số chữ số phần nguyên tối đa cho một ô nhập tiền.
///
/// `wallet."Balance"` là **`numeric(15,2)`** (đo 2026-09-18): 15 chữ số tổng,
/// hai trong đó dành cho phần thập phân, nên phần nguyên còn **13**.
///
/// ## Vì sao phải chặn ở ô nhập
///
/// Cùng một lớp lỗi với G31 nhưng ở cột kiểu số. Tràn `numeric` cho SQLSTATE
/// **`22003`**, mà `sync.service.js` không có nhánh nào cho mã ấy — nó rơi về
/// `DB_ERROR`. Danh sách lỗi vĩnh viễn của `SyncEngine` là danh sách **trắng**,
/// và `DB_ERROR` không nằm trong đó, nên ví bị **gửi lại ở mọi chu kỳ đồng
/// bộ**: không lỗi, không log, chỉ một hàng đợi càng lúc càng chậm. Đúng vòng
/// lặp mà G31 và G14 sinh ra để chặn.
///
/// Với tiền Việt, 13 chữ số là gần mười nghìn tỷ đồng — xa hơn mọi số dư thật,
/// nên giới hạn này chỉ chạm tới khi người dùng gõ nhầm (giữ phím 0).
const int kSoChuSoToiDaSoTien = 13;

/// Bộ lọc ô nhập tiền: không cho vượt [toiDa] **chữ số**.
///
/// Khác [GioiHanDoRong] ở chỗ nó đếm **chữ số**, không đếm ký tự: ô số dư tự
/// chèn dấu chấm ngăn nghìn sau mỗi lần gõ, nên đếm cả dấu chấm sẽ chặn sớm hơn
/// thật khoảng một phần tư.
///
/// Đặt **sau** `FilteringTextInputFormatter.digitsOnly` trong danh sách
/// `inputFormatters` — tuy phép đếm ở đây tự bỏ mọi ký tự không phải chữ số nên
/// thứ tự không đổi kết quả.
class GioiHanSoChuSo extends TextInputFormatter {
  const GioiHanSoChuSo(this.toiDa);

  final int toiDa;

  static int _demChuSo(String s) {
    var n = 0;
    for (final ma in s.codeUnits) {
      // '0' = 48, '9' = 57.
      if (ma >= 48 && ma <= 57) n++;
    }
    return n;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (_demChuSo(newValue.text) <= toiDa) return newValue;
    // Đã đủ mà gõ thêm thì giữ nguyên chuỗi cũ thay vì cắt đuôi — cùng cách xử
    // lý với `GioiHanDoRong`, vì con trỏ có thể đang ở giữa và cắt đuôi là xoá
    // chữ số người dùng không đụng tới.
    return oldValue;
  }
}

/// Phần đầu dài nhất của [chuoi] có tổng số code point không quá [toiDa].
///
/// Cắt theo **trọn cụm grapheme**: không bao giờ để lại nửa emoji hay một chữ
/// đã mất dấu. Vì thế kết quả có thể ngắn hơn [toiDa] vài code point.
String catVuaDoRong(String chuoi, int toiDa) {
  if (chuoi.runes.length <= toiDa) return chuoi;

  final ketQua = StringBuffer();
  var daDung = 0;
  for (final cum in chuoi.characters) {
    final soCodePoint = cum.runes.length;
    if (daDung + soCodePoint > toiDa) break;
    ketQua.write(cum);
    daDung += soCodePoint;
  }
  return ketQua.toString();
}

/// Bộ lọc ô nhập giống `LengthLimitingTextInputFormatter`, nhưng đếm code point.
class GioiHanDoRong extends TextInputFormatter {
  const GioiHanDoRong(this.toiDa, {this.cheDo});

  /// Số code point tối đa.
  final int toiDa;

  /// Có cắt giữa lúc bộ gõ đang ghép chữ hay không. `null` là theo mặc định
  /// nền tảng của Flutter: Android cắt ngay, iOS và web chờ ghép xong.
  final MaxLengthEnforcement? cheDo;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.runes.length <= toiDa) return newValue;

    final daDuTruocDo = oldValue.text.runes.length == toiDa;
    switch (cheDo ??
        LengthLimitingTextInputFormatter.getDefaultMaxLengthEnforcement()) {
      case MaxLengthEnforcement.none:
        return newValue;
      case MaxLengthEnforcement.enforced:
        // Đã đủ mà gõ thêm thì giữ nguyên chuỗi cũ thay vì cắt đuôi: con trỏ có
        // thể đang ở giữa, và cắt đuôi là xoá chữ người dùng không đụng tới.
        if (daDuTruocDo && oldValue.selection.isCollapsed) return oldValue;
        return _cat(newValue);
      case MaxLengthEnforcement.truncateAfterCompositionEnds:
        if (daDuTruocDo && !oldValue.composing.isValid) return oldValue;
        // Bộ gõ đang ghép chữ: để yên, framework gọi lại khi ghép xong.
        if (newValue.composing.isValid) return newValue;
        return _cat(newValue);
    }
  }

  TextEditingValue _cat(TextEditingValue giaTri) {
    final text = catVuaDoRong(giaTri.text, toiDa);
    int kep(int viTri) => viTri > text.length ? text.length : viTri;
    return TextEditingValue(
      text: text,
      selection: giaTri.selection.copyWith(
        baseOffset: kep(giaTri.selection.baseOffset),
        extentOffset: kep(giaTri.selection.extentOffset),
      ),
    );
  }
}
