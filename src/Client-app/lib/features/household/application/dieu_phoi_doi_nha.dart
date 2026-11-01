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
///   mềm — không trái quy tắc 5). ⚠️ Xoá CẢ hàng `pending`: hàng chưa đẩy phải được đẩy TRƯỚC khi rời (`NhaRepository.roiNha`
///   / `giaiTan` đẩy-và-chờ rồi từ chối nếu còn hàng, spec 2026-11-01 mục 7.3), và `NhaRepositoryImpl` không phát `DoiNha(X → null)`
///   khi kho nhà vắng mà chưa hỏi `/me` — nếu không đường này xoá luôn hàng chưa đẩy mà phép dọn lúc mở phiên vừa giữ.
///   TRƯỚC khi xoá, [truocKhiDon] trả tiền về ví riêng cho khoản góp / rút của nhà chưa đẩy (xoá hàng trước là mất dấu khoản
///   góp, tiền không về). Ngoài ra, sau mỗi lần `/me` được áp ([NhaDaDoc]) hàng của nhà khác nhà đó cũng được dọn như vậy.
/// - Vào nhà [DoiNha.den] → `keoLaiToanBo`: dữ liệu cũ của nhà nằm dưới mốc kéo tăng dần.
///
/// Tuần tự (hàng đợi): dọn trước, kéo sau; sự kiện sau chờ sự kiện trước; lỗi một lượt không chặn lượt sau.
/// Lỗi dọn cũng không chặn lượt kéo của CÙNG sự kiện (dọn hỏng vẫn kéo, rồi ném lại lỗi dọn cho hàng đợi ghi log).
class DieuPhoiDoiNha {
  DieuPhoiDoiNha({
    required AppDatabase db,
    required Future<void> Function(int idaccount) keoLaiToanBo,
    Future<void> Function(int idaccount, int? idNha)? ghiDau,
    Future<void> Function(int idNha, int idaccount)? truocKhiDon,
  })  : _db = db,
        _keoLaiToanBo = keoLaiToanBo,
        _ghiDau = ghiDau,
        _truocKhiDon = truocKhiDon;

  final Future<void> Function(int idaccount, int? idNha)? _ghiDau;

  /// Việc phải làm TRƯỚC khi xoá hàng của nhà [idNha] (DI: trả tiền về ví riêng cho khoản góp / rút chưa đẩy).
  final Future<void> Function(int idNha, int idaccount)? _truocKhiDon;
  final AppDatabase _db;
  final Future<void> Function(int idaccount) _keoLaiToanBo;
  StreamSubscription<DoiNha>? _sub;
  StreamSubscription<NhaDaDoc>? _subDaDoc;
  Future<void> _hang = Future.value();

  /// Nối MỘT lần cho cả vòng đời app (`main.dart`). [daDocNha]: sau mỗi lần `/me` được áp, dọn hàng của nhà KHÁC nhà đó
  /// (hàng kẹt khi kho nhà vắng + dấu vắng + `/me` không nhà thì không có cặp [DoiNha] nào để dọn) — cùng hàng việc với
  /// [xuLy] nên không đua nhau.
  void batDauNghe(Stream<DoiNha> doiNha, {Stream<NhaDaDoc>? daDocNha}) {
    unawaited(_sub?.cancel());
    unawaited(_subDaDoc?.cancel());
    _sub = doiNha.listen((d) {
      _hang = _hang.then((_) => xuLy(d)).catchError((Object e) {
        debugPrint('[GiaDinh] xử lý nhà đổi hỏng: ${e.runtimeType}');
      });
    });
    _subDaDoc = daDocNha?.listen((d) {
      _hang = _hang.then((_) => donHangKet(d)).catchError((Object e) {
        debugPrint('[GiaDinh] dọn hàng nhà kẹt hỏng: ${e.runtimeType}');
      });
    });
  }

  /// Trả tiền (nếu có) RỒI xoá hàng của nhà [idNha]. Lỗi của bước trước KHÔNG chặn bước sau (nửa riêng ở lại như một khoản
  /// riêng còn hơn hàng kẹt mãi); ném lỗi đầu tiên sau khi cả hai bước đã chạy.
  Future<void> _donNha(int idNha, int idaccount) async {
    Object? loi;
    StackTrace? dau;
    try {
      await _truocKhiDon?.call(idNha, idaccount);
    } catch (e, s) {
      loi = e;
      dau = s;
    }
    try {
      await _db.xoaHangCuaNha(idNha);
    } catch (e, s) {
      loi ??= e;
      dau ??= s;
    }
    if (loi != null) Error.throwWithStackTrace(loi, dau!);
  }

  /// Dọn hàng của mọi nhà còn trên máy mà KHÔNG phải nhà `/me` vừa xác nhận. Không dựa vào dấu, không xin kéo toàn bộ;
  /// lỗi một nhà không chặn nhà khác.
  Future<void> donHangKet(NhaDaDoc d) async {
    for (final x in await _db.cacNhaConTrenMay()) {
      if (x == d.idNha) continue;
      try {
        await _donNha(x, d.idaccount);
      } catch (e) {
        debugPrint('[GiaDinh] dọn hàng nhà kẹt hỏng: ${e.runtimeType}');
      }
    }
  }

  Future<void> xuLy(DoiNha d) async {
    final tu = d.tu;
    Object? loiDon;
    StackTrace? dauVetDon;
    if (tu != null) {
      try {
        await _donNha(tu, d.idaccount);
      } catch (e, s) {
        // Giữ lỗi, KHÔNG thoát: kho trạng thái nhà đã mang nhà [DoiNha.den] nên không lượt làm mới nào phát lại sự kiện
        // này — bỏ lượt kéo là lịch sử nhà mới không bao giờ về máy, im lặng.
        loiDon = e;
        dauVetDon = s;
      }
    }
    if (d.den != null) await _keoLaiToanBo(d.idaccount);
    if (loiDon != null) Error.throwWithStackTrace(loiDon, dauVetDon!);
    // Sau khi dọn xong và đã xin kéo toàn bộ (G113 lỗ hổng 1; mốc đã lưu đã xoá nên lượt kéo hỏng vẫn đi lại từ 1970).
    // Tiến trình chết TRƯỚC dòng này thì lần mở phiên sau chạy lại đúng cặp. Dấu KHÔNG nói dữ liệu đã về. Còn hở: lượt nền
    // ghi mốc đè, hoặc xoá mốc hỏng rồi tiến trình chết (G113 lỗ hổng 1a, 1b).
    await _ghiDau?.call(d.idaccount, d.den);
  }

  /// Chờ hàng việc hiện tại xong (test).
  Future<void> choXong() => _hang;

  Future<void> dung() async {
    await _sub?.cancel();
    _sub = null;
    await _subDaDoc?.cancel();
    _subDaDoc = null;
  }
}
