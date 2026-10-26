/// Tin admin phát qua `system.broadcast` (spec `2026-10-26-tin-tu-flowmoney-broadcast-design.md`). [docTinHeThong] là chỗ
/// DUY NHẤT đọc payload của sự kiện này — ngoại lệ hộp đen thứ hai sau `account.force_logout` (chú thích đầu
/// `realtime_event.dart`). Backend: `notification.service.js` `broadcast` → `core/socket.js` `emitSystemBroadcast`.
///
/// Dart thuần, không import `features/` (luật 5 của test quét 25) — nên mức độ có enum riêng, bộ nhận ở mảng thông báo
/// đổi sang `NotificationSeverity` theo tên.
library;

enum MucDoTinHeThong { info, warning, critical }

class TinHeThong {
  const TinHeThong({required this.id, required this.tieuDe, required this.noiDung, required this.mucDo});

  /// UUID backend cấp cho mỗi lần phát — khoá chống trùng (event bus có thể phát một tin HAI lần: cục bộ + Redis).
  final String id;
  final String tieuDe;
  final String noiDung;
  final MucDoTinHeThong mucDo;
}

/// Một tin kèm tài khoản của phiên socket đã nhận nó (danh tính chỉ từ phiên — quy tắc 2 `CLAUDE.md`).
typedef TinHeThongNhan = ({int idaccount, TinHeThong tin});

const kTieuDeTinHeThongMacDinh = 'Tin từ FlowMoney';

/// Trần tiêu đề — Admin-web cho gõ tối đa 120 ký tự (`BroadcastPage.jsx`).
const kTranTieuDeTinHeThong = 120;
const kTranNoiDungTinHeThong = 1000;

/// `null` = không hiện gì: payload không phải `Map`; tin bảo trì tự động (`metadata.type` là chuỗi khác rỗng —
/// `maintenance.manager.js`, người dùng chốt chỉ hiện tin admin gõ tay); thiếu `id`; tiêu đề và nội dung cùng rỗng.
TinHeThong? docTinHeThong(Object? payload) {
  if (payload is! Map) return null;
  final meta = payload['metadata'];
  if (meta is Map) {
    final loai = meta['type'];
    if (loai is String && loai.trim().isNotEmpty) return null;
  }
  final id = payload['id'];
  if (id is! String || id.trim().isEmpty) return null;
  final tieuDe = _chuoi(payload['title']);
  final noiDung = _chuoi(payload['message']);
  if (tieuDe.isEmpty && noiDung.isEmpty) return null;
  return TinHeThong(
    id: id.trim(),
    tieuDe: _cat(tieuDe.isEmpty ? kTieuDeTinHeThongMacDinh : tieuDe, kTranTieuDeTinHeThong),
    noiDung: _cat(noiDung, kTranNoiDungTinHeThong),
    mucDo: _mucDo(payload['level']),
  );
}

String _chuoi(Object? v) => v is String ? v.trim() : '';

/// Cắt theo code point — cắt theo `length` (UTF-16) để lại nửa cặp surrogate của emoji.
String _cat(String s, int tran) => s.runes.length <= tran ? s : String.fromCharCodes(s.runes.take(tran));

MucDoTinHeThong _mucDo(Object? level) => switch (level is String ? level.trim().toLowerCase() : '') {
      'warning' => MucDoTinHeThong.warning,
      'critical' => MucDoTinHeThong.critical,
      _ => MucDoTinHeThong.info,
    };
