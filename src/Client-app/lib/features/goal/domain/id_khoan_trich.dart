import 'package:uuid/uuid.dart';

/// Namespace riêng — KHÔNG dùng chung với khoản mở sổ (`so_du_mo_so.dart`): hai không gian tên khác nhau thì không
/// bao giờ va id.
const String _namespaceTrich = '8d1e4b77-2c39-4f05-9a6e-5b3f0c2d71e8';

/// Id **tất định** của khoản trích tự động cho [goalId] ở kỳ [ky] (spec 2026-10-10-tu-chuyen-tien-chay-nen-design.md
/// mục 5).
///
/// Chạy nền làm "hai máy cùng tới kỳ 08:00" thành ca thường. Cùng id thì `/sync/push` ghép làm một hàng (LWW) —
/// cùng khuôn `idKhoanMoSo`. Băm **mili-giây UTC**, không băm chuỗi giờ địa phương: hai máy khác múi giờ phải ra cùng
/// một id cho cùng một thời khắc.
String idKhoanTrichTuDong(String goalId, DateTime ky) =>
    const Uuid().v5(_namespaceTrich, '$goalId|${ky.toUtc().millisecondsSinceEpoch}');
