/// Mốc lượt nền kế tiếp của hai bộ tự chuyển tiền — tự trả hoá đơn, trích mục tiêu (spec
/// `2026-10-10-tu-chuyen-tien-chay-nen-design.md` mục 3.1).
///
/// Từ 2026-10-15 (G88 gạch 4) phép tính của từng phần ở mảng của nó — `mocTuTraNen` (`features/bill/domain/moc_tu_tra_nen.dart`)
/// và `mocTrichNen` (`features/goal/domain/moc_trich_nen.dart`); DI chọn phần theo quyền gói rồi gọi [gopLichNen]. Tệp này
/// không biết mảng nào.
library;

import 'kenh_tu_chuyen_tien.dart';

/// `moc` — mốc **ở tương lai** gần nhất cho lượt một-lần (`null` = không hẹn).
/// `coTuDong` — còn thứ gì bật tự động → giữ lượt định kỳ 6 giờ.
typedef LichNenKeTiep = ({DateTime? moc, bool coTuDong});

/// Gộp lịch của các phần: mốc = SỚM NHẤT trong các mốc khác `null` (mỗi phần đã chỉ trả mốc ở tương lai), `coTuDong` = còn
/// phần nào bật tự động. Không phần nào (không quyền gói nào) → `(null, false)` — Basic không cần đánh thức máy.
LichNenKeTiep gopLichNen(Iterable<LichNenKeTiep> phan) {
  DateTime? moc;
  var coTuDong = false;
  for (final p in phan) {
    coTuDong = coTuDong || p.coTuDong;
    final m = p.moc;
    final cu = moc;
    if (m != null && (cu == null || m.isBefore(cu))) moc = m;
  }
  return (moc: moc, coTuDong: coTuDong);
}

/// Hẹn lượt nền qua kênh Kotlin — **chỉ engine của app** dùng. Lượt nền trả mốc qua `nenXong` thay vì gọi đây: tự
/// `REPLACE` công việc đang chạy là WorkManager huỷ nó giữa chừng.
class LichNen {
  LichNen({required this.tinh, required this.kenh});

  final Future<LichNenKeTiep> Function(int idaccount, DateTime now) tinh;
  final KenhTuChuyenTien kenh;

  /// Lịch đã gửi lần trước — chỉ gửi lại khi đổi.
  LichNenKeTiep? _daHen;

  Future<LichNenKeTiep> tinhCho(int idaccount, {DateTime? now}) => tinh(idaccount, now ?? DateTime.now());

  /// Gửi kênh chỉ khi lịch ĐỔI — `resync` chạy sau mọi chu kỳ đồng bộ 15 phút.
  Future<void> henNeuDoi(int idaccount, {DateTime? now}) async {
    final l = await tinhCho(idaccount, now: now);
    if (l == _daHen) return;
    await kenh.henNen(l);
    _daHen = l;
  }

  /// Đăng xuất / phiên chết: không ai đăng nhập thì không ai uỷ quyền chuyển tiền.
  Future<void> huy() async {
    await kenh.henNen((moc: null, coTuDong: false));
    _daHen = null;
  }
}
