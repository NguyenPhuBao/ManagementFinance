/// Quyền tính năng bật/tắt theo gói — spec `2026-10-08-phan-quyen-tinh-nang-client-design.md` mục 3 và 4.1; luật bảng thay
/// bằng spec B1 `2026-10-27-phan-quyen-cot-premium-va-cong-tac-design.md` mục 2 (Premium cũng theo bảng).
///
/// [trangThaiQuyen] là ĐỊNH NGHĨA DUY NHẤT của "tài khoản này dùng tính năng ấy được không, và nếu không thì vì sao";
/// [duocDung] là vế `bool` của nó. Mọi chỗ đọc `TrangThaiGoi.quyenTinhNang` / `quyenPremium` / `tranPremium` đi qua đây
/// (test quét `lib/` thứ 21). Bảng do admin cấu hình ở Admin-web `/permissions`; server trả `features` (gói hiệu lực) và
/// `premiumFeatures` (cột Premium — chỉ cho tài khoản Basic, đơn CAN-LAM 55 A1) ở `/payment/subscription-info`.
///
/// **Chín mã server KHÔNG BAO GIỜ khoá** (spec B1 mục 3 — không vào [MaQuyen], client bỏ qua giá trị):
/// `transaction_management` · `offline_first_sync` (lõi; đồng bộ không tách theo gói) · `vietqr_payment` (khoá là Basic
/// không nâng cấp được) · `account_deletion` (quyền của người dùng) · `biometric_auth` (trên app là khoá ứng dụng — miễn phí
/// mọi gói) · `payment_history` (Lịch sử mua là lối vào Chi tiết đơn — chỗ duy nhất xác nhận / hoàn tiền) ·
/// `ai_model_management` (khoá là không xoá được mô hình 2,4 GB) · `offline_login`, `financial_health_fhs` (app không có
/// tính năng).
library;

import 'tran_goi.dart';
import '../data/models/tran_goi.dart';
import 'hang_goi.dart';
import '../data/models/trang_thai_goi.dart';

/// 22 quyền bật/tắt. [macDinhKhiThieu] là giá trị khi server không trả khoá — người dùng chốt 2026-10-08: **mở**, trừ ba quyền AI giữ chốt 06/10 là khoá với Basic. 11 mã thêm ở B1 (2026-10-27) đều mở khi thiếu.
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
  bankNotificationParser('bank_notification_parser', 'Đọc biến động số dư', true),
  // B1 (spec 2026-10-27 mục 3) — `ten` người dùng chốt phiên 17.
  netWorthOverview('net_worth_overview', 'Tổng tài sản', true),
  quickActionShortcuts('quick_action_shortcuts', 'Nút ghi nhanh', true),
  dailyRecordingReminder('daily_recording_reminder', 'Nhắc ghi chép hằng ngày', true),
  billReminderNotifications('bill_reminder_notifications', 'Nhắc trước hạn hóa đơn', true),
  budgetOverspendAlert('budget_overspend_alert', 'Cảnh báo vượt ngân sách', true),
  walletBalanceAdjustment('wallet_balance_adjustment', 'Điều chỉnh số dư ví', true),
  walletExcludeTotal('wallet_exclude_total', 'Loại ví khỏi tổng tài sản', true),
  goalDepositWithdraw('goal_deposit_withdraw', 'Nạp / rút mục tiêu', true),
  quickCategoryAssignment('quick_category_assignment', 'Gắn danh mục hàng loạt', true),
  categoryKeywordsMatching('category_keywords_matching', 'Từ khoá nhận diện danh mục', true),
  inAppCalculator('in_app_calculator', 'Phép tính trên bàn phím số', true);

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

/// Ba trạng thái của một quyền (spec B1 mục 2): [mo] dùng được · [canPremium] khoá, mua Premium là mở · [tamNgung] admin
/// tắt ở cột của gói người dùng đang có (Premium) hoặc sẽ có (Basic, cột Premium) — mua không mở, nên giao diện KHÔNG mời
/// nâng cấp.
enum TrangThaiQuyen { mo, canPremium, tamNgung }

/// 1. Premium còn hạn: bảng dùng được ([bangDungDuoc]) và ghi `false` → [TrangThaiQuyen.tamNgung]; còn lại (kể cả thiếu
///    khoá) → mở.
/// 2. Không Premium: bảng dùng được và có khoá → theo khoá; không → [MaQuyen.macDinhKhiThieu]. Mở → [TrangThaiQuyen.mo].
/// 3. Khoá: cột Premium (chỉ có khi server gửi `premiumFeatures`) ghi `false` → tạm ngừng; không → cần Premium.
/// ⚠️ KHÔNG xét `goi.loai`: server trả `accountType` là gói GỐC (vẫn `'Premium'` khi đã hết hạn) còn `features` là bảng
/// của gói HIỆU LỰC (`payment.service.js`, `effectiveType`).
TrangThaiQuyen trangThaiQuyen(MaQuyen ma, TrangThaiGoi goi, DateTime now) {
  final premium = goi.laPremium(now);
  final bang = bangDungDuoc(goi, now);
  final v = bang ? goi.quyenTinhNang[ma.maServer] : null;
  if (premium) return v == false ? TrangThaiQuyen.tamNgung : TrangThaiQuyen.mo; // vắng → mở (như trước B1)
  if (v ?? ma.macDinhKhiThieu) return TrangThaiQuyen.mo;
  final cotPremium = bang ? goi.quyenPremium[ma.maServer] : null;
  return cotPremium == false ? TrangThaiQuyen.tamNgung : TrangThaiQuyen.canPremium;
}

/// Vế `bool` của [trangThaiQuyen] — giữ chữ ký cho mọi chỗ chỉ cần "được dùng không".
bool duocDung(MaQuyen ma, TrangThaiGoi goi, DateTime now) => trangThaiQuyen(ma, goi, now) == TrangThaiQuyen.mo;

/// Danh sách *"Đặc quyền Premium"* ở màn Nâng cấp — đúng những thứ Basic đang THIẾU (người dùng chốt 2026-10-08), theo bảng
/// của gói đang hiệu lực ([bangDungDuoc]); trần đọc qua [tranHieuLuc], không đọc `goi.tran` thô (G109):
/// - bảng là của **Basic** → mỗi trần có số + mỗi quyền Basic bị tắt; server đã gửi cột Premium (B1, chốt 10) → trần Premium
///   `null` kể *"Không giới hạn ví"*, số kể *"Tới 10 ví"* chỉ khi lớn hơn trần Basic; quyền Premium cũng tắt thì KHÔNG kể;
/// - người xem **Premium còn hạn** → bảng đã lưu CHÍNH LÀ cột Premium, so với mặc định Basic ([TranGoi.macDinh] +
///   `macDinhKhiThieu`) — màn mở đầu *"Gói Premium hiện cho tạo tối đa 10 ví."* thì danh sách nói *"Tới 10 ví"*;
/// - bảng không dùng được (Premium hết hạn lúc offline, Premium không hạn) → mặc định, như trước B1.
List<String> dacQuyenPremium(TrangThaiGoi goi, DateTime now) {
  final premium = goi.laPremium(now);
  final bang = bangDungDuoc(goi, now);
  // Bên "Basic": Basic với bảng dùng được → trần đã lưu; còn lại → mặc định (`tranHieuLuc` của Basic hết hạn offline cũng
  // là macDinh; Premium không hạn thì tranHieuLuc là không giới hạn — không phải mức Basic).
  final tranBasic = premium ? TranGoi.macDinh : tranHieuLuc(goi, now);
  final TranGoi? tranPremium = !bang ? null : (premium ? tranHieuLuc(goi, now) : goi.tranPremium);
  final Map<String, bool> cotPremium = !bang ? const {} : (premium ? goi.quyenTinhNang : goi.quyenPremium);
  bool basicCo(MaQuyen m) =>
      bang && !premium ? (goi.quyenTinhNang[m.maServer] ?? m.macDinhKhiThieu) : m.macDinhKhiThieu;
  bool premiumCo(MaQuyen m) => cotPremium[m.maServer] != false;
  return [
    for (final l in LoaiTran.values)
      if (_dongTranPremium(l, tranBasic.cua(l), tranPremium) case final d?) d,
    for (final m in MaQuyen.values)
      if (!basicCo(m) && premiumCo(m)) m.ten,
  ];
}

/// Một dòng trần của [dacQuyenPremium]. Basic không giới hạn → không phải đặc quyền. Cột Premium chưa gửi → như trước B1.
String? _dongTranPremium(LoaiTran l, int? basic, TranGoi? tranPremium) {
  if (basic == null) return null;
  final p = tranPremium?.cua(l);
  if (p == null) return 'Không giới hạn ${tenTran(l)}'; // cột chưa gửi (như trước B1) hoặc Premium không giới hạn
  return p > basic ? 'Tới $p ${tenTran(l)}' : null;
}
