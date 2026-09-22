/// Gác theo CÂU — cách hoà streaming với bộ kiểm, người dùng chốt 2026-09-22
/// (việc số 1 của lộ trình `2026-09-21-ai-viec-tiep-theo.md`).
///
/// Bộ kiểm (`kiemCauTraLoi`) chỉ có nghĩa trên một câu **đầy đủ**; hiện chữ
/// theo từng token là để người đọc thấy con số **trước khi** nó bị chặn. Nên
/// token đổ vào bộ đệm, đủ một câu thì kiểm rồi mới phát; trượt thì gọi
/// [huy] (dừng engine native) và phát [BiChan]. Người dùng **không bao giờ**
/// thấy một câu chưa qua kiểm, và chữ vẫn hiện dần — theo câu.
///
/// Hàm **thuần** về dữ liệu: không biết runtime, không biết widget; test được
/// bằng `Stream.fromIterable`.
library;

sealed class SuKienGac {
  const SuKienGac();
}

/// Một câu đã qua kiểm — được phép hiện.
class CauQua extends SuKienGac {
  final String cau;
  const CauQua(this.cau);

  @override
  bool operator ==(Object other) => other is CauQua && other.cau == cau;
  @override
  int get hashCode => cau.hashCode;
  @override
  String toString() => 'CauQua($cau)';
}

/// Câu trượt bộ kiểm — **không** hiện; sinh đã bị huỷ, không còn sự kiện nào
/// sau nó.
class BiChan extends SuKienGac {
  final String cau;
  const BiChan(this.cau);

  @override
  bool operator ==(Object other) => other is BiChan && other.cau == cau;
  @override
  int get hashCode => cau.hashCode;
  @override
  String toString() => 'BiChan($cau)';
}

/// Dấu kết câu **theo sau bởi khoảng trắng hoặc hết chuỗi** — dấu chấm ngăn
/// nghìn (`2.141.000`) theo sau bởi chữ số nên không khớp.
final RegExp _ketCau = RegExp(r'[.!?](?=\s|$)');

/// Tách [dem] thành (các câu hoàn chỉnh đã trim, phần còn lại chưa có dấu
/// kết). Phần còn lại giữ nguyên chữ, chỉ bỏ khoảng trắng đầu.
(List<String>, String) tachCauHoanChinh(String dem) {
  final cau = <String>[];
  var batDau = 0;
  for (final m in _ketCau.allMatches(dem)) {
    final c = dem.substring(batDau, m.end).trim();
    if (c.isNotEmpty) cau.add(c);
    batDau = m.end;
  }
  return (cau, dem.substring(batDau).trimLeft());
}

/// Phát [CauQua] cho từng câu qua [kiem]; câu đầu tiên trượt thì gọi [huy]
/// **một lần**, phát [BiChan] và **dừng đọc** [token] — token đến sau không
/// bao giờ được xét. Hết luồng mà còn phần chưa có dấu kết thì phần ấy cũng
/// là một câu phải kiểm (mô hình hết token giữa chừng vẫn không được lọt).
Stream<SuKienGac> gacTheoCau(
  Stream<String> token, {
  required bool Function(String cau) kiem,
  required Future<void> Function() huy,
}) async* {
  var dem = '';
  await for (final t in token) {
    dem += t;
    final (cau, conLai) = tachCauHoanChinh(dem);
    dem = conLai;
    for (final c in cau) {
      if (kiem(c)) {
        yield CauQua(c);
      } else {
        await huy();
        yield BiChan(c);
        return;
      }
    }
  }
  final cuoi = dem.trim();
  if (cuoi.isEmpty) return;
  // Luồng đã đóng: không còn gì để huỷ.
  yield kiem(cuoi) ? CauQua(cuoi) : BiChan(cuoi);
}
