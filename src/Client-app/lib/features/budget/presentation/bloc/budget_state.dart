import '../../../ai_edge/domain/tai_phan_bo.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/database/app_database.dart';
import '../../data/models/budget_entity.dart';
import '../../domain/de_xuat_ngan_sach.dart';

abstract class BudgetState extends Equatable {
  const BudgetState();

  @override
  List<Object?> get props => [];
}

class BudgetInitial extends BudgetState {
  const BudgetInitial();
}

class BudgetLoading extends BudgetState {
  const BudgetLoading();
}

class BudgetLoaded extends BudgetState {
  /// Ngân sách còn trong hạn dùng — tab "Đang hoạt động". Sửa và xoá được.
  final List<BudgetView> active;

  /// Ngân sách đã qua hạn — tab "Đã hết hạn". Chỉ xem được chi tiết.
  ///
  /// Tách thành hai danh sách ngay ở state thay vì để giao diện tự lọc: điều
  /// kiện hết hạn quyết định luôn việc khoá sửa/xoá, nên nó phải có **một** chỗ
  /// đúng duy nhất chứ không phải lặp lại ở mỗi widget.
  final List<BudgetView> expired;

  /// Tổng hạn mức, **chỉ cộng ngân sách đang hoạt động**.
  ///
  /// Thẻ tổng quan nói về số tiền còn tiêu được; gộp cả hạn mức của một ngân
  /// sách đã chết vào thì con số đó không còn nghĩa gì.
  final double totalAmount;

  /// Tổng đã chi của các ngân sách đang hoạt động, tính từ bảng giao dịch.
  final double totalSpent;

  /// Kế hoạch tái phân bổ cho ngân sách thâm hụt lớn nhất (Edge-SLM Tầng 2),
  /// hoặc `null` khi không ngân sách nào thâm hụt — hoặc khi cubit được dựng
  /// không có `TaiPhanBoNguon` (test cũ, trang không cần).
  final KeHoachTaiPhanBo? keHoach;

  /// Danh mục chi đáng đặt ngân sách mà chưa có, kèm độ dài cửa sổ đã dùng để
  /// suy ra chúng. `null` = không có gì để gợi ý → thẻ ẩn hẳn.
  ///
  /// ⚠️ Tính **độc lập** với [keHoach]: `_phat` thoát sớm khi không có nguồn
  /// Tầng 2, nên đặt phép tính này sau phép rẽ nhánh ấy là để thẻ **không bao
  /// giờ hiện** ở mọi chỗ không nối nguồn tái phân bổ — im lặng.
  final GoiDeXuat? deXuat;

  /// Số ngày còn thiếu để cửa sổ nhìn lại đủ 14 ngày; `null` = không cần nói.
  /// Chỉ khác `null` khi [deXuat] là `null` vì tài khoản còn trẻ — thẻ đề xuất
  /// khi ấy nhường chỗ cho câu "cần thêm N ngày dữ liệu".
  final int? soNgayConThieu;

  const BudgetLoaded({
    required this.active,
    required this.expired,
    required this.totalAmount,
    required this.totalSpent,
    this.keHoach,
    this.deXuat,
    this.soNgayConThieu,
  });

  /// Chỉ gắn thêm [deXuat], giữ nguyên mọi thứ khác.
  ///
  /// Cố ý **không** phải một `copyWith` đầy đủ: chỗ duy nhất cần nó là đường
  /// phát của cubit, và một `copyWith` tổng quát mời gọi việc dựng state bằng
  /// cách vá từng mảnh — thứ làm trạng thái khó lần.
  BudgetLoaded copyWithDeXuat(GoiDeXuat? deXuat, {int? soNgayConThieu}) =>
      BudgetLoaded(
        active: active,
        expired: expired,
        totalAmount: totalAmount,
        totalSpent: totalSpent,
        keHoach: keHoach,
        deXuat: deXuat,
        soNgayConThieu: soNgayConThieu,
      );

  double get totalRemaining => totalAmount - totalSpent;

  /// Cắt trần ở 1.0 để thanh tiến trình không tràn khung khi tiêu vượt.
  double get percentSpent {
    if (totalAmount <= 0) return 0.0;
    final ratio = totalSpent / totalAmount;
    return ratio > 1.0 ? 1.0 : ratio;
  }

  /// Rỗng chỉ khi **cả hai** tab đều không có gì. Hiện màn hình "Chưa có ngân
  /// sách nào" trong lúc tab hết hạn đang có dữ liệu sẽ làm người dùng tưởng
  /// mất sạch.
  bool get isEmpty => active.isEmpty && expired.isEmpty;

  @override
  List<Object?> get props =>
      [active, expired, totalAmount, totalSpent, keHoach, deXuat, soNgayConThieu];
}

/// Trang cấu hình đã có đủ thứ cần để dựng form.
///
/// Gộp danh mục và ngân sách đang sửa vào **một** state thay vì hai: form chỉ
/// dựng được khi có cả hai, tách ra sẽ đẻ thêm một trạng thái trung gian mà
/// giao diện phải xử lý mà không mang lại gì.
class BudgetEditorReady extends BudgetState {
  final List<Category> categories;

  /// null = đang tạo mới.
  final BudgetEntity? editing;

  /// Độ dài cửa sổ nhìn lại đã sinh ra con số gợi ý hạn mức. `null` = chưa
  /// biết (tài khoản quá trẻ, hoặc phép đo hỏng) — nhãn của form im vế
  /// "suy từ N ngày" chứ không đoán một con số.
  final int? soNgayCuaSo;

  /// Số ngày còn thiếu để gợi ý được; `null` = không cần nói. Xem
  /// `soNgayConThieu` ở `cua_so_nhin_lai.dart`.
  final int? soNgayConThieu;

  const BudgetEditorReady({
    required this.categories,
    this.editing,
    this.soNgayCuaSo,
    this.soNgayConThieu,
  });

  bool get isCreating => editing == null;

  @override
  List<Object?> get props => [
        categories,
        editing?.id,
        editing?.updatedAt,
        soNgayCuaSo,
        soNgayConThieu,
      ];
}

/// Đã ghi xong một thay đổi. Mang theo lời nhắn để giao diện hiện snackbar.
class BudgetSaved extends BudgetState {
  final String message;

  const BudgetSaved(this.message);

  @override
  List<Object?> get props => [message];
}

class BudgetError extends BudgetState {
  final String message;

  const BudgetError(this.message);

  @override
  List<Object?> get props => [message];
}
