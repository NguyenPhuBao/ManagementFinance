// lib/core/api/khung_sse.dart
/// Bộ tách khung **Server-Sent Events** — hạ tầng HTTP thuần, không biết mảng nào
/// (mục 4 `docs/KIEN_TRUC_CLIENT_APP.md`: `core/api` = HTTP). Dùng bởi datasource
/// trợ lý online (`features/ai_chat/data/datasources/`).
///
/// Chuẩn: khung kết thúc bằng một dòng trống; `event:` đặt tên; nhiều `data:` nối
/// bằng `\n`; dòng bắt đầu `:` là chú thích; `\r\n` coi như `\n`. Gói mạng cắt
/// KHÔNG theo khung — vì thế giữ đệm qua các lần [nhan], và [dong] đẩy phần dư.
library;

class KhungSse {
  const KhungSse({required this.event, required this.data});
  final String event;
  final String data;
}

class BoTachSse {
  final StringBuffer _dem = StringBuffer();
  String? _event;
  final List<String> _data = [];

  /// Nhận một đoạn chữ (đã giải mã UTF-8); trả các khung vừa đủ.
  List<KhungSse> nhan(String doan) {
    _dem.write(doan);
    final chuoi = _dem.toString().replaceAll('\r\n', '\n');
    final cuoi = chuoi.lastIndexOf('\n');
    if (cuoi < 0) return const [];
    final duLieu = chuoi.substring(0, cuoi + 1);
    final du = chuoi.substring(cuoi + 1);
    _dem
      ..clear()
      ..write(du);
    final ra = <KhungSse>[];
    // `duLieu` kết bằng '\n' nên split để lại một phần tử rỗng cuối: đó là dấu
    // kết dòng, KHÔNG phải dòng trống — bỏ đi, kẻo chốt khung sớm.
    final cacDong = duLieu.split('\n')..removeLast();
    for (final dong in cacDong) {
      final k = _xuLyDong(dong);
      if (k != null) ra.add(k);
    }
    return ra;
  }

  /// Cuối luồng: khung đang dở (không có dòng trống kết) vẫn được phát.
  List<KhungSse> dong() {
    final con = _dem.toString().replaceAll('\r\n', '\n');
    _dem.clear();
    final ra = <KhungSse>[];
    if (con.isNotEmpty) {
      final k = _xuLyDong(con);
      if (k != null) ra.add(k);
    }
    final cuoi = _chot();
    if (cuoi != null) ra.add(cuoi);
    return ra;
  }

  KhungSse? _xuLyDong(String dong) {
    if (dong.isEmpty) return _chot();
    if (dong.startsWith(':')) return null;
    final i = dong.indexOf(':');
    final ten = i < 0 ? dong : dong.substring(0, i);
    var giaTri = i < 0 ? '' : dong.substring(i + 1);
    if (giaTri.startsWith(' ')) giaTri = giaTri.substring(1);
    if (ten == 'event') {
      _event = giaTri;
    } else if (ten == 'data') {
      _data.add(giaTri);
    }
    return null;
  }

  KhungSse? _chot() {
    if (_data.isEmpty) {
      _event = null;
      return null;
    }
    final k = KhungSse(event: _event ?? 'message', data: _data.join('\n'));
    _event = null;
    _data.clear();
    return k;
  }
}
