import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../data/models/nha_cua_toi.dart';

/// Phản ứng khi nhà của tài khoản ĐỔI (spec gia đình 2026-10-23 mục 4.3 + 4.6 đường 2; một bộ thay cho `tham_gia_nha` +
/// `don_du_lieu_nha` của spec 7.1 — kế hoạch lát 1). Nguồn là `NhaRepository.doiNha`, nên MỌI lối nhà đổi đi chung một
/// đường: thao tác trên máy này (tạo / tham gia / rời / giải tán), sự kiện `household.changed`, lượt làm mới thấy khác kho
/// — kể cả máy thứ hai của cùng tài khoản và kho bị mất.
///
/// - Rời nhà [DoiNha.tu] → `xoaHangCuaNha`: bản sao cục bộ của dữ liệu không còn thuộc người dùng (server giữ / đã xoá
///   mềm — không trái quy tắc 5). Phần 1 không có hàng của nhà nào do máy ghi, nên không có gì phải đẩy nốt.
/// - Vào nhà [DoiNha.den] → `keoLaiToanBo`: dữ liệu cũ của nhà nằm dưới mốc kéo tăng dần.
///
/// Tuần tự (hàng đợi): dọn trước, kéo sau; sự kiện sau chờ sự kiện trước; lỗi một lượt không chặn lượt sau.
/// Lỗi dọn cũng không chặn lượt kéo của CÙNG sự kiện (dọn hỏng vẫn kéo, rồi ném lại lỗi dọn cho hàng đợi ghi log).
class DieuPhoiDoiNha {
  DieuPhoiDoiNha({required AppDatabase db, required Future<void> Function(int idaccount) keoLaiToanBo})
      : _db = db,
        _keoLaiToanBo = keoLaiToanBo;

  final AppDatabase _db;
  final Future<void> Function(int idaccount) _keoLaiToanBo;
  StreamSubscription<DoiNha>? _sub;
  Future<void> _hang = Future.value();

  /// Nối MỘT lần cho cả vòng đời app (`main.dart`).
  void batDauNghe(Stream<DoiNha> doiNha) {
    unawaited(_sub?.cancel());
    _sub = doiNha.listen((d) {
      _hang = _hang.then((_) => xuLy(d)).catchError((Object e) {
        debugPrint('[GiaDinh] xử lý nhà đổi hỏng: ${e.runtimeType}');
      });
    });
  }

  Future<void> xuLy(DoiNha d) async {
    final tu = d.tu;
    Object? loiDon;
    StackTrace? dauVetDon;
    if (tu != null) {
      try {
        await _db.xoaHangCuaNha(tu);
      } catch (e, s) {
        // Giữ lỗi, KHÔNG thoát: kho trạng thái nhà đã mang nhà [DoiNha.den] nên không lượt làm mới nào phát lại sự kiện
        // này — bỏ lượt kéo là lịch sử nhà mới không bao giờ về máy, im lặng.
        loiDon = e;
        dauVetDon = s;
      }
    }
    if (d.den != null) await _keoLaiToanBo(d.idaccount);
    if (loiDon != null) Error.throwWithStackTrace(loiDon, dauVetDon!);
  }

  /// Chờ hàng việc hiện tại xong (test).
  Future<void> choXong() => _hang;

  Future<void> dung() async {
    await _sub?.cancel();
    _sub = null;
  }
}
