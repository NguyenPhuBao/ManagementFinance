import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/goi_repository.dart';
import '../../domain/quyen_tinh_nang.dart';
import '../../domain/trang_thai_goi.dart';

/// Phát `TrangThaiGoi` cho mọi màn (thẻ Cá nhân, dòng nhắc Trang chủ, băng
/// khoá Trợ lý AI, ô Nhập nhanh, màn Nâng cấp). Mỏng: luật nằm ở
/// `GoiRepository`. Singleton trong DI, cung cấp ở gốc cây (`main.dart`).
class GoiCubit extends Cubit<TrangThaiGoi> {
  GoiCubit(this._repo, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now,
        super(_repo.hienTai) {
    _sub = _repo.theoDoi.listen(emit);
  }

  final GoiRepository _repo;
  final DateTime Function() _now;
  late final StreamSubscription<TrangThaiGoi> _sub;

  /// Premium **theo giờ máy lúc hỏi** — hết hạn offline tự về Basic ở lần đọc
  /// kế, không cần sự kiện nào (spec Premium 6.3; giới hạn 15.3).
  bool get laPremium => state.laPremium(_now());

  /// Tài khoản đang đăng nhập được dùng tính năng [ma] không — theo giờ máy lúc hỏi (`duocDung`, spec phân quyền
  /// 2026-10-08 mục 4.1).
  bool coQuyen(MaQuyen ma) => duocDung(ma, state, _now());

  Future<void> lamMoi() => _repo.lamMoi();

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
