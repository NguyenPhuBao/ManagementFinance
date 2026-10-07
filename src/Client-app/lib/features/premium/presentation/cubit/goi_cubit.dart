import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/goi_repository.dart';
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

  /// Quyền dùng Trợ lý AI (hỏi đáp + lệnh tạo)
  bool get duocDungAiAssistant =>
      state.duocDung('ai_assistant', fallback: () => laPremium);

  /// Quyền dùng Nhập nhanh giao dịch bằng câu
  bool get duocDungAiQuickInput =>
      state.duocDung('ai_quick_input', fallback: () => laPremium);

  /// Quyền quét hóa đơn / biên lai OCR AI
  bool get duocOcrReceipt =>
      state.duocDung('ocr_receipt', fallback: () => true);

  /// Quyền dùng mô hình Edge AI on-device
  bool get duocDungEdgeAi =>
      state.duocDung('ai_edge_model', fallback: () => laPremium);

  /// Quyền xuất báo cáo PDF / Excel
  bool get duocXuatBaoCao =>
      state.duocDung('export_reports', fallback: () => laPremium);

  /// Quyền dự báo dòng tiền 30 ngày
  bool get duocDuBaoDongTien =>
      state.duocDung('cashflow_forecast', fallback: () => laPremium);

  /// Quyền tự động thanh toán hóa đơn
  bool get duocTuDongTraHoaDon =>
      state.duocDung('bill_auto_pay', fallback: () => laPremium);

  /// Quyền tự động trích tiền mục tiêu
  bool get duocTuDongTrichMucTieu =>
      state.duocDung('goal_auto_deposit', fallback: () => laPremium);

  Future<void> lamMoi() => _repo.lamMoi();

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
