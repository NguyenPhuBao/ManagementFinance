/// Mục tiêu chung là công tắc trên ví chung (`docs/Family/03`): tiến độ suy từ số dư ví, không đọc `currentAmount`, nên nhiều
/// người góp offline không đè mất khoản của nhau. Mọi phép tính đi qua `GoalEntity.progress` để không có luật thứ hai.
library;

import 'dart:math' as math;

import '../../goal/data/models/goal_entity.dart';
import '../../goal/domain/goal_auto_deposit.dart' show mocThuN;

enum TrangThaiMucTieuChung { dangChay, daDat, quaHan }

class TienDoMucTieuChung {
  const TienDoMucTieuChung({
    required this.soDu,
    required this.mucTieu,
    required this.tiLe,
    required this.conThieu,
    required this.conNgay,
    required this.canGopMoiThang,
    required this.trangThai,
    required this.han,
  });

  final double soDu;
  final double mucTieu;
  final double tiLe;
  final double conThieu;
  final int conNgay;

  /// `null` khi đã đạt hoặc đã quá hạn: không còn câu "cần góp".
  final double? canGopMoiThang;
  final TrangThaiMucTieuChung trangThai;
  final DateTime han;
}

/// Bỏ cờ `isCompleted`: mục tiêu chung suy "đã đạt" từ số dư, không bao giờ ghi cờ.
GoalEntity _chieu(GoalEntity g, double soDuVi) =>
    g.copyWith(currentAmount: math.max(0.0, soDuVi), isCompleted: false);

double tiLeMucTieuChung(GoalEntity mucTieu, double soDuVi) => _chieu(mucTieu, soDuVi).progress;

/// Số nguyên `n ≥ 1` nhỏ nhất sao cho cộng `n` tháng lịch từ hôm nay không trước hạn. `mocThuN` kẹp ngày cuối tháng.
int soThangConLai(DateTime now, DateTime han) {
  final homNay = DateTime(now.year, now.month, now.day);
  final den = DateTime(han.year, han.month, han.day);
  var n = 1;
  while (mocThuN(homNay, 'Month', n).isBefore(den)) {
    n++;
  }
  return n;
}

TienDoMucTieuChung tienDoMucTieuChung({
  required GoalEntity mucTieu,
  required double soDuVi,
  required DateTime now,
}) {
  final g = _chieu(mucTieu, soDuVi);
  final conNgay = g.daysLeft(now);
  final daDat = g.daHoanThanh;
  final quaHan = !daDat && conNgay < 0;
  return TienDoMucTieuChung(
    soDu: g.currentAmount,
    mucTieu: g.targetAmount,
    tiLe: g.progress,
    conThieu: g.remainingAmount,
    conNgay: conNgay,
    canGopMoiThang: daDat || quaHan ? null : (g.remainingAmount / soThangConLai(now, g.targetDate)).ceilToDouble(),
    trangThai: daDat
        ? TrangThaiMucTieuChung.daDat
        : quaHan
            ? TrangThaiMucTieuChung.quaHan
            : TrangThaiMucTieuChung.dangChay,
    han: g.targetDate,
  );
}

/// Mục tiêu sống theo ví. Hai hàng cùng ví (hai máy Chủ cùng bật offline, trước khi resolver gỡ hàng thua): hàng mới nhất.
Map<String, GoalEntity> mucTieuTheoVi(Iterable<GoalEntity> ds) {
  final ra = <String, GoalEntity>{};
  for (final g in ds) {
    final vi = g.walletId;
    if (vi == null || g.isDeleted) continue;
    final dang = ra[vi];
    if (dang == null || g.updatedAt.isAfter(dang.updatedAt)) ra[vi] = g;
  }
  return ra;
}

/// Câu lỗi của hai ô, `null` = hợp lệ. [hanLucMo] là hạn đang lưu: mục tiêu đã quá hạn vẫn đổi được số tiền mà không phải đổi hạn.
String? loiNhapMucTieu({
  required String soTienChu,
  required DateTime? han,
  required DateTime? hanLucMo,
  required DateTime now,
}) {
  final soTien = double.tryParse(soTienChu.replaceAll('.', '')) ?? 0;
  if (soTien <= 0) return 'Vui lòng nhập số tiền mục tiêu';
  if (han == null) return 'Vui lòng chọn hạn';
  final homNay = DateTime(now.year, now.month, now.day);
  final ngayHan = DateTime(han.year, han.month, han.day);
  if (ngayHan.isBefore(homNay) && han != hanLucMo) return 'Hạn phải từ hôm nay trở đi';
  return null;
}

/// Việc với mục tiêu khi lưu ví chung.
sealed class ThayDoiMucTieu {
  const ThayDoiMucTieu();
}

class GiuMucTieu extends ThayDoiMucTieu {
  const GiuMucTieu();
}

class BoMucTieu extends ThayDoiMucTieu {
  const BoMucTieu();
}

class DatMucTieu extends ThayDoiMucTieu {
  const DatMucTieu({required this.soTien, required this.han, required this.idaccount});

  final double soTien;
  final DateTime han;

  /// Người tạo khi là hàng mới. Từ phiên.
  final int idaccount;
}
