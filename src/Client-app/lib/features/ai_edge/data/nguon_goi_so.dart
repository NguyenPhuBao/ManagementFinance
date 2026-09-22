// lib/features/ai_edge/data/nguon_goi_so.dart
/// Gom **bốn gói số** của P2 cho màn Trợ lý AI (P3 Task 8).
///
/// Khác mọi chỗ dùng gói số khác: bốn khối Nhận xét đều dựng gói từ state mà
/// *trang của chúng* đã nạp sẵn, còn màn Trợ lý AI không thuộc màn nào — nó
/// phải tự hỏi dữ liệu. Đây là chỗ duy nhất làm việc ấy.
///
/// ⚠️ **Lớp này vẫn KHÔNG tính gì** (test quét thứ 14 canh cả thư mục
/// `ai_edge/`): nó chỉ lấy dữ liệu rồi đưa cho đúng `GoiSo...tu()` đã có. Mọi
/// con số vẫn từ hàm domain của từng mảng.
///
/// ⚠️ Đọc `.first` của các stream chứ không nghe lâu dài: một câu trả lời là
/// **ảnh chụp tại lúc hỏi**. Nghe tiếp thì câu đã hiện sẽ nói một đằng còn số
/// liệu sau lưng nó đổi một nẻo, mà người dùng không có cách nào biết.
library;

import '../../analytics/data/analytics_repository.dart';
import '../../analytics/domain/pham_vi_ky.dart';
import '../../budget/data/repositories/budget_repository.dart';
import '../../goal/data/repositories/goal_repository.dart';
import '../../wallet/data/repositories/wallet_repository.dart';
import '../../wallet/domain/vi_tinh_vao_tong.dart';
import '../domain/goi_so.dart';
import '../domain/goi_so_muc_tieu.dart';
import '../domain/goi_so_ngan_sach.dart';
import '../domain/goi_so_phan_tich.dart';
import '../domain/goi_so_trang_chu.dart';

class NguonGoiSo {
  NguonGoiSo({
    required this.phanTich,
    required this.nganSach,
    required this.mucTieu,
    required this.vi,
  });

  final AnalyticsRepository phanTich;
  final BudgetRepository nganSach;
  final GoalRepository mucTieu;
  final WalletRepository vi;

  /// Bốn gói, theo thứ tự: phân tích · ngân sách · mục tiêu · trang chủ.
  ///
  /// Kỳ là **tháng hiện tại** — cùng kỳ mà khối Nhận xét trang Phân tích dùng
  /// mặc định, nên hai chỗ không nói hai con số khác nhau cho cùng một câu.
  Future<List<GoiSo>> tatCa(int idaccount, {DateTime? now}) async {
    final moc = now ?? DateTime.now();
    final ky = Ky.thang(moc.year, moc.month);

    final tk = await phanTich.watchKy(idaccount, ky: ky, now: moc).first;

    // ⚠️ Chỉ ngân sách **đang chạy**, cùng phép lọc `isExpired` mà trang Ngân
    // sách và bộ quét thông báo dùng. Gói một ngân sách đã hết hạn vào đây là
    // đưa mô hình một con số không còn nghĩa gì với hôm nay.
    final tatCaNganSach = await nganSach.watchBudgets(idaccount, now: moc).first;
    final dangChay = [
      for (final v in tatCaNganSach)
        if (!v.budget.isExpired(moc)) v,
    ];

    final goals = await mucTieu.watchGoals(idaccount).first;

    final vis = await vi.watchAll(idaccount).first;
    var tongSoDu = 0.0;
    for (final w in vis) {
      if (viTinhVaoTong(
        includeInTotal: w.includeInTotal,
        status: w.status,
        isDeleted: w.isDeleted,
      )) {
        tongSoDu += w.balance;
      }
    }

    return [
      GoiSoPhanTich.tu(tk),
      GoiSoNganSach.tu(dangChay, now: moc),
      GoiSoMucTieu.tu(goals, now: moc),
      GoiSoTrangChu.tu(
        thu: tk.tong.thu,
        chi: tk.tong.chi,
        tongSoDu: tongSoDu,
        nganSach: dangChay,
        now: moc,
      ),
    ];
  }
}
