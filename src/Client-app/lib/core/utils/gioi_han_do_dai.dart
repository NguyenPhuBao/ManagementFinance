/// Giữ tên người dùng gõ nằm trong độ rộng cột chuỗi trên PostgreSQL — G31.
///
/// ## Vì sao có tệp này
///
/// `wallet.Name`, `goal.Name`, `bill.Name` là `varchar(100)` và
/// `category.NameCategory` là `varchar(200)` (đo 2026-09-10 bằng
/// `information_schema.columns`). Tên dài hơn vỡ `P2000` ở `/sync/push`. Backend
/// chưa ánh xạ mã ấy nên trả `DB_ERROR`, và `SyncEngine` xếp `DB_ERROR` là lỗi
/// tạm thời: bản ghi bị gửi lại ở mọi chu kỳ, không lỗi nào hiện ra. Riêng ví
/// thì server cắt âm thầm còn 100 ký tự rồi kéo bản đã cắt về máy.
///
/// Phía server đã có tài liệu xin
/// (`docs/superpowers/backend/CAN-LAM/SYNC_PUSH_ERROR_MAPPING.md`). Client vẫn
/// chặn ở ô nhập, vì đó là chỗ duy nhất người dùng thấy giới hạn lúc đang gõ.
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
