/// Trạng thái máy chủ nhìn từ client — bảo trì (503 `MAINTENANCE_MODE`) hay phong toả mạng (403 `AIOPS_QUARANTINED`) — spec
/// G89 2026-10-20 mục 3.1. Một định nghĩa cho ba nơi đọc: `SyncEngine` (hẹn thử lại), dòng nhắc Trang chủ + toast, màn Đăng
/// nhập.
///
/// Phần phân loại là Dart thuần, KHÔNG import Dio: interceptor đưa vào mã / body / header thô, nên trang được đọc tệp này
/// (tinh thần quét 31). Trạng thái không gắn tài khoản (bảo trì là chung, phong toả theo IP) và không lưu xuống đĩa.
///
/// Socket không bị kiểm bảo trì / phong toả phía server, và client không nghe `system.maintenance_changed` (payload hộp đen —
/// quyết định 2026-09-30) — nên client KHÔNG biết giờ kết thúc bảo trì, và không chữ nào được hứa giờ ấy.
library;

import 'package:flutter/foundation.dart';

import '../utils/date_formatter.dart';

/// Sàn cho MỌI lần hẹn thử lại vì máy chủ chặn. Server hôm nay gửi `Retry-After: 60` cố định, nhưng một bản sau gửi `1` —
/// hoặc giờ hết phong toả đã qua (máy chạy nhanh giờ, 403 cũ về muộn) — thì không có sàn là vòng request dồn dập vào đúng
/// IP mà AIOps đang theo dõi vì nghi DoS (spec mục 3.3). Đó là kết cục duy nhất tính năng này không được phép sinh ra.
const Duration kSanThuLai = Duration(seconds: 30);

/// `Retry-After` thiếu hoặc không phải số nguyên dương.
const Duration kThuLaiBaoTriMacDinh = Duration(seconds: 60);

sealed class TinhTrangMayChu {
  const TinhTrangMayChu();
}

final class MayChuBinhThuong extends TinhTrangMayChu {
  const MayChuBinhThuong();
}

/// ⚠️ Hai lớp chặn dưới đây cố ý KHÔNG có constructor `const` và không `==` theo giá trị: mỗi phản hồi bị chặn phải là một
/// đối tượng MỚI. `SyncEngine` dựa vào đó (`identical`) để chỉ tính lời chặn ghi TRONG chu kỳ vừa chạy, và `ValueNotifier`
/// phát lại mốc mới sau mỗi 503. `const MayChuPhongToa()` sẽ bị chuẩn tắc hoá thành MỘT đối tượng cho mọi lần chặn không giờ.
final class MayChuBaoTri extends TinhTrangMayChu {
  MayChuBaoTri({required this.thuLaiLuc});

  /// Lúc nên thử lại — đã có sàn [kSanThuLai].
  final DateTime thuLaiLuc;
}

final class MayChuPhongToa extends TinhTrangMayChu {
  MayChuPhongToa({this.hetHanLuc});

  /// Giờ SERVER hết phong toả, quy về giờ địa phương; `null` = server không nói (hoặc nói thứ không đọc được).
  final DateTime? hetHanLuc;
}

/// `null` = phản hồi này KHÔNG nói gì về trạng thái máy chủ → nơi gọi không đổi gì.
///
/// Chỉ đọc `code` ở CẤP GỐC của body là `Map` (hình dạng `maintenance.middleware.js` / `auth.controller.js` /
/// `aiops.quarantine.js` đo 2026-10-20), và luôn đi CẶP với mã HTTP. Không bao giờ phân loại theo mã HTTP một mình: 503 quá
/// tải (`SERVER_OVERLOADED`, `DB_POOL_OVERLOADED`), 503 lỗi lược đồ không `code`, 403 `FEATURE_DISABLED`, 403 trạng thái
/// tài khoản lúc đăng nhập đều trả `null` — giữ hành vi hôm nay.
TinhTrangMayChu? phanLoaiPhanHoi({
  required int? status,
  Object? body,
  String? retryAfter,
  required DateTime bayGio,
}) {
  if (body is! Map) return null;
  final ma = body['code'];
  if (status == 503 && ma == 'MAINTENANCE_MODE') {
    final giay = int.tryParse(retryAfter?.trim() ?? '');
    final cho = (giay != null && giay > 0) ? Duration(seconds: giay) : kThuLaiBaoTriMacDinh;
    return MayChuBaoTri(thuLaiLuc: bayGio.add(cho < kSanThuLai ? kSanThuLai : cho));
  }
  if (status == 403 && ma == 'AIOPS_QUARANTINED') {
    final het = body['quarantineExpiresAt'];
    return MayChuPhongToa(hetHanLuc: het is String ? DateTime.tryParse(het)?.toLocal() : null);
  }
  return null;
}

/// Mốc `SyncEngine` hẹn thử lại khi máy chủ đang chặn; `null` = không hẹn riêng (bình thường, hoặc phong toả không nói giờ
/// — khi ấy giãn cách như hôm nay). Luôn ≥ `bayGio + kSanThuLai`.
DateTime? mocThuLaiKhiBiChan(TinhTrangMayChu t, DateTime bayGio) {
  final DateTime? moc = switch (t) {
    MayChuBaoTri(:final thuLaiLuc) => thuLaiLuc,
    MayChuPhongToa(:final hetHanLuc) => hetHanLuc,
    MayChuBinhThuong() => null,
  };
  if (moc == null) return null;
  final san = bayGio.add(kSanThuLai);
  return moc.isBefore(san) ? san : moc;
}

/// `15:30` khi [hetHan] cùng ngày với [bayGio], ngược lại `09:00 21/10` — một định nghĩa cho dòng nhắc Trang chủ và màn
/// Đăng nhập (spec mục 4.1, 4.3).
String chuGioHetHan(DateTime hetHan, DateTime bayGio) {
  final h = hetHan.toLocal();
  final n = bayGio.toLocal();
  final cungNgay = h.year == n.year && h.month == n.month && h.day == n.day;
  return cungNgay ? DateFormatter.formatTime(h) : DateFormatter.formatTimeDayMonth(h);
}

/// Trạng thái hiện tại — DI singleton, sống trong RAM. Chỉ interceptor của `DioClient` ghi (test quét 36).
class TrangThaiMayChu extends ValueNotifier<TinhTrangMayChu> {
  TrangThaiMayChu() : super(const MayChuBinhThuong());
}
