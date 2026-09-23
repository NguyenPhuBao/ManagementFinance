// lib/features/ai_edge/data/nguon_goi_so.dart
/// Gom **sáu gói số** cho màn Trợ lý AI (P3 Task 8: bốn; việc số 1 ngày
/// 2026-09-22 thêm hoá đơn và ví — hai gói đã có cho khối Nhận xét mà màn
/// Trợ lý AI không thấy, nên hỏi về hoá đơn là mô hình lấy số của gói khác
/// trả lời thay).
///
/// Khác mọi chỗ dùng gói số khác: sáu khối Nhận xét đều dựng gói từ state mà
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
import '../../bill/data/repositories/bill_repository.dart';
import '../../budget/data/models/budget_entity.dart';
import '../../budget/data/repositories/budget_repository.dart';
import '../../goal/data/repositories/goal_repository.dart';
import '../../wallet/data/models/wallet_entity.dart';
import '../../wallet/data/repositories/wallet_repository.dart';
import '../../wallet/domain/vi_tinh_vao_tong.dart';
import '../domain/goi_so.dart';
import '../domain/goi_so_hoa_don.dart';
import '../domain/goi_so_muc_tieu.dart';
import '../domain/goi_so_ngan_sach.dart';
import '../domain/goi_so_phan_tich.dart';
import '../domain/goi_so_trang_chu.dart';
import '../domain/goi_so_vi.dart';

/// Ví entity → kiểu thuần của gói số (gói số cố ý không biết `WalletEntity`).
/// Một chỗ chép cho cả `NguonGoiSo` (gói ví) lẫn tool `danh_sach_vi` (chặng
/// 4b): hai bản chép là hai lần quên một trường — `allowNegative` là trường dễ
/// quên nhất, và quên nó là mọi thẻ tín dụng thành "ví đang âm".
///
/// ⚠️ Trang Quản lý ví còn một bản riêng, `_choGoiSo` ở `wallet_list_page.dart`,
/// cùng phép quy đổi — chưa gộp về đây.
List<ViChoGoiSo> viChoGoiSoTu(List<WalletEntity> vis) => [
      for (final w in vis)
        ViChoGoiSo(
          ten: w.name,
          soDu: w.balance,
          includeInTotal: w.includeInTotal,
          status: w.status,
          isDeleted: w.isDeleted,
          allowNegative: w.allowNegative,
        ),
    ];

/// Ngân sách ĐANG CHẠY — cùng phép lọc `isExpired` mà trang Ngân sách và bộ quét
/// thông báo dùng. Tool `danh_sach_ngan_sach` gọi lại hàm này: đưa một ngân sách
/// đã hết hạn cho mô hình là đưa một con số không còn nghĩa gì với hôm nay.
List<BudgetView> nganSachDangChay(List<BudgetView> tatCa, DateTime now) => [
      for (final v in tatCa)
        if (!v.budget.isExpired(now)) v,
    ];

class NguonGoiSo {
  NguonGoiSo({
    required this.phanTich,
    required this.nganSach,
    required this.mucTieu,
    required this.vi,
    required this.hoaDon,
  });

  final AnalyticsRepository phanTich;
  final BudgetRepository nganSach;
  final GoalRepository mucTieu;
  final WalletRepository vi;
  final BillRepository hoaDon;

  /// Sáu gói, theo thứ tự: phân tích · ngân sách · mục tiêu · hoá đơn · ví ·
  /// trang chủ.
  ///
  /// Kỳ là **tháng hiện tại** — cùng kỳ mà khối Nhận xét trang Phân tích dùng
  /// mặc định, nên hai chỗ không nói hai con số khác nhau cho cùng một câu.
  Future<List<GoiSo>> tatCa(int idaccount, {DateTime? now}) async {
    final moc = now ?? DateTime.now();
    final ky = Ky.thang(moc.year, moc.month);

    final tk = await phanTich.watchKy(idaccount, ky: ky, now: moc).first;

    // ⚠️ Chỉ ngân sách **đang chạy** — xem `nganSachDangChay`.
    final tatCaNganSach = await nganSach.watchBudgets(idaccount, now: moc).first;
    final dangChay = nganSachDangChay(tatCaNganSach, moc);

    final goals = await mucTieu.watchGoals(idaccount).first;

    final bills = await hoaDon.watchBills(idaccount).first;

    // Đọc ví MỘT lần cho cả gói ví lẫn tổng số dư của trang chủ — đọc hai lần
    // là hai ảnh chụp khác nhau của cùng dữ liệu.
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
    final viChoGoi = viChoGoiSoTu(vis);

    return [
      GoiSoPhanTich.tu(tk),
      GoiSoNganSach.tu(dangChay, now: moc),
      GoiSoMucTieu.tu(goals, now: moc),
      GoiSoHoaDon.tu(bills, now: moc),
      GoiSoVi.tu(viChoGoi),
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
