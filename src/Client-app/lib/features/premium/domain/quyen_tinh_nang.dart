/// Quyền tính năng bật/tắt theo gói — spec `2026-10-08-phan-quyen-tinh-nang-client-design.md` mục 3 và 4.1.
///
/// [duocDung] là ĐỊNH NGHĨA DUY NHẤT của "tài khoản này được dùng tính năng ấy không"; mọi chỗ đọc
/// `TrangThaiGoi.quyenTinhNang` đi qua đây (test quét `lib/` thứ 21). Bảng quyền do admin cấu hình ở Admin-web
/// `/permissions`, server trả ở `features` của `/payment/subscription-info`.
library;

import 'tran_goi.dart';
import 'trang_thai_goi.dart';

/// 11 quyền bật/tắt (`financial_health_fhs` bỏ: app không có màn FHS). [macDinhKhiThieu] là giá trị khi server
/// không trả khoá — người dùng chốt 2026-10-08: **mở**, trừ ba quyền AI giữ chốt 06/10 là khoá với Basic.
enum MaQuyen {
  aiAssistant('ai_assistant', 'Trợ lý AI', false),
  aiQuickInput('ai_quick_input', 'Nhập nhanh bằng câu', false),
  aiEdgeModel('ai_edge_model', 'AI trên máy', false),
  ocrReceipt('ocr_receipt', 'Quét hóa đơn, biên lai', true),
  smartBudgetRebalancing('smart_budget_rebalancing', 'Đề xuất cân đối ngân sách', true),
  exportReports('export_reports', 'Xuất báo cáo', true),
  cashflowForecast('cashflow_forecast', 'Dự báo 30 ngày tới', true),
  anomalySpendingInsights('anomaly_spending_insights', 'Cảnh báo chi bất thường', true),
  billAutoPay('bill_auto_pay', 'Tự động trả hóa đơn', true),
  goalAutoDeposit('goal_auto_deposit', 'Trích tiền tự động', true),
  bankNotificationParser('bank_notification_parser', 'Đọc biến động số dư', true);

  const MaQuyen(this.maServer, this.ten, this.macDinhKhiThieu);

  /// Khoá trong `features` của server — admin đổi GIÁ TRỊ, không đổi tên khoá.
  final String maServer;

  /// Tên hiện trên thẻ khoá và câu mở đầu màn Nâng cấp.
  final String ten;
  final bool macDinhKhiThieu;
}

MaQuyen? maQuyenTuServer(String? ma) {
  for (final m in MaQuyen.values) {
    if (m.maServer == ma) return m;
  }
  return null;
}

/// 1. Premium còn hạn theo [now] → được, bỏ qua bảng.
/// 2. Bảng đã lưu là của **Basic** — tức lúc nhận bảng (`goi.nhanLuc`) tài khoản không phải Premium còn hạn — và có
///    khoá → theo khoá. ⚠️ KHÔNG xét `goi.loai`: server trả `accountType` là gói GỐC (vẫn `'Premium'` khi đã hết hạn)
///    còn `features` là bảng của gói HIỆU LỰC (`payment.service.js`, `effectiveType`).
/// 3. Còn lại — Basic thiếu khoá, hoặc Premium hết hạn SAU lúc nhận (bảng lưu là của Premium, đọc nó là mở mọi tính
///    năng cho tài khoản đã hết hạn lúc offline) → [MaQuyen.macDinhKhiThieu].
bool duocDung(MaQuyen ma, TrangThaiGoi goi, DateTime now) {
  if (goi.laPremium(now)) return true;
  final bangCuaBasic = !goi.laPremium(goi.nhanLuc);
  final v = goi.quyenTinhNang[ma.maServer];
  if (bangCuaBasic && v != null) return v;
  return ma.macDinhKhiThieu;
}

/// Danh sách *"Đặc quyền Premium"* ở màn Nâng cấp — đúng những thứ Basic đang THIẾU theo bảng server (người dùng chốt
/// 2026-10-08 sau nghiệm thu: danh sách cố định từng kể 4 dòng của 06/10, còn quyền thật do admin đặt). Bảng đã lưu là
/// của Basic (cùng phép xét với [duocDung]) → mỗi trần có số + mỗi quyền Basic bị tắt; bảng là của Premium (người đang
/// Premium mở màn này) → mặc định: [TranGoi.macDinh] + quyền có `macDinhKhiThieu == false`.
List<String> dacQuyenPremium(TrangThaiGoi goi) {
  final bangCuaBasic = !goi.laPremium(goi.nhanLuc);
  final tran = bangCuaBasic ? goi.tran : TranGoi.macDinh;
  bool basicCo(MaQuyen m) =>
      bangCuaBasic ? (goi.quyenTinhNang[m.maServer] ?? m.macDinhKhiThieu) : m.macDinhKhiThieu;
  return [
    for (final l in LoaiTran.values)
      if (tran.cua(l) != null) 'Không giới hạn ${tenTran(l)}',
    for (final m in MaQuyen.values)
      if (!basicCo(m)) m.ten,
  ];
}
