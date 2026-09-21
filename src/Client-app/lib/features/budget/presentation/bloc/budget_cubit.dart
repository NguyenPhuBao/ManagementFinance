import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/budget_entity.dart';
import '../../../ai_edge/domain/tai_phan_bo.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/tai_phan_bo_nguon.dart';
import 'budget_state.dart';

export 'budget_state.dart';

/// UI → BudgetCubit → BudgetRepository → BudgetLocalDataSource → Drift
///
/// Không có nhánh nào gọi thẳng API: ngân sách đi lên backend qua `SyncEngine`
/// như mọi thực thể khác.
class BudgetCubit extends Cubit<BudgetState> {
  final BudgetRepository repository;

  /// Nguồn thời gian dùng để phân tab. Tách ra để test không phụ thuộc đồng hồ
  /// máy chạy nó: "hết hạn chưa" là câu hỏi về thời điểm.
  final DateTime Function() clock;

  /// Nguồn dữ liệu Tầng 2 tái phân bổ (Edge-SLM). `null` = không tính kế
  /// hoạch — đường của test cũ và của trang không cần; khi ấy state phát
  /// **đồng bộ** như trước, không thêm một microtask nào.
  final TaiPhanBoNguon? taiPhanBoNguon;

  StreamSubscription<List<BudgetView>>? _subscription;

  /// Số thứ tự lượt phát — lượt `nap` chậm về sau lượt mới hơn thì bỏ, không
  /// để dữ liệu cũ đè dữ liệu mới.
  int _lan = 0;

  BudgetCubit({
    required this.repository,
    DateTime Function()? clock,
    this.taiPhanBoNguon,
  })  : clock = clock ?? DateTime.now,
        super(const BudgetInitial());

  /// Theo dõi danh sách ngân sách. Phát lại cả khi có giao dịch mới.
  ///
  /// [idaccount] phải là mã của phiên đăng nhập hiện tại. Nơi gọi truyền `null`
  /// khi chưa đăng nhập thì cubit **không đọc gì cả** thay vì đoán một mã tài
  /// khoản — xem `core/auth/current_account.dart`.
  void watchBudgets(int? idaccount) {
    if (idaccount == null || idaccount <= 0) {
      emit(const BudgetError('Chưa đăng nhập — không đọc được ngân sách.'));
      return;
    }
    emit(const BudgetLoading());
    _subscription?.cancel();
    _subscription = repository.watchBudgets(idaccount).listen(
          (views) => _phat(views, idaccount),
          onError: (Object e) => emit(BudgetError(e.toString())),
        );
  }

  Future<void> loadBudgets(int? idaccount) async {
    if (idaccount == null || idaccount <= 0) {
      emit(const BudgetError('Chưa đăng nhập — không đọc được ngân sách.'));
      return;
    }
    emit(const BudgetLoading());
    try {
      await _phat(await repository.getBudgets(idaccount), idaccount);
    } catch (e) {
      emit(BudgetError(e.toString()));
    }
  }

  /// Phát `BudgetLoaded`: đồng bộ khi không có nguồn Tầng 2; có nguồn thì nạp
  /// dữ liệu rồi tính kế hoạch, và chỉ phát nếu vẫn là lượt mới nhất.
  Future<void> _phat(List<BudgetView> views, int idaccount) async {
    final n = ++_lan;
    final loaded = _loadedFrom(views);
    final nguon = taiPhanBoNguon;
    if (nguon == null) {
      emit(loaded);
      return;
    }
    try {
      final now = clock();
      final d = await nguon.nap(idaccount, loaded.active, now);
      final kh = taiPhanBoCua(
        dangChay: loaded.active,
        now: now,
        coDinh: d.coDinh,
        thuNhapMoiThang: d.thuNhapMoiThang,
        mucThangTheoNganSach: d.mucThangTheoNganSach,
        phanHoi: d.phanHoi,
      );
      if (n != _lan || isClosed) return;
      emit(BudgetLoaded(
        active: loaded.active,
        expired: loaded.expired,
        totalAmount: loaded.totalAmount,
        totalSpent: loaded.totalSpent,
        keHoach: kh,
      ));
    } catch (e) {
      // Kế hoạch là phần phụ: nguồn hỏng thì trang vẫn hiện ngân sách.
      if (n != _lan || isClosed) return;
      emit(loaded);
    }
  }

  /// Chia danh sách thành hai tab và cộng tổng **chỉ trên tab đang hoạt động**.
  BudgetLoaded _loadedFrom(List<BudgetView> views) {
    final now = clock();
    final active = <BudgetView>[];
    final expired = <BudgetView>[];
    var amount = 0.0;
    var spent = 0.0;

    for (final v in views) {
      if (v.budget.isExpired(now)) {
        expired.add(v);
        continue;
      }
      active.add(v);
      amount += v.budget.amount;
      spent += v.budget.spent;
    }

    return BudgetLoaded(
      active: active,
      expired: expired,
      totalAmount: amount,
      totalSpent: spent,
    );
  }

  /// Nạp mọi thứ trang cấu hình cần: danh mục chi, và ngân sách đang sửa nếu
  /// [budgetId] khác null.
  ///
  /// Cố ý dùng một cubit RIÊNG ở trang đó: state này thay thế [BudgetLoaded]
  /// nên gọi nó trên cùng cubit với danh sách sẽ làm trang danh sách trắng xoá.
  Future<void> loadEditor(int? idaccount, {String? budgetId}) async {
    if (idaccount == null || idaccount <= 0) {
      emit(const BudgetError('Chưa đăng nhập — không mở được ngân sách.'));
      return;
    }
    emit(const BudgetLoading());
    try {
      final categories = await repository.getExpenseCategories(idaccount);
      final editing = budgetId == null
          ? null
          : (await repository.getBudgetById(budgetId))?.budget;
      if (budgetId != null && editing == null) {
        emit(const BudgetError('Ngân sách này không còn tồn tại.'));
        return;
      }
      emit(BudgetEditorReady(categories: categories, editing: editing));
    } catch (e) {
      emit(BudgetError(e.toString()));
    }
  }

  Future<void> addBudget({
    required int? idaccount,
    required double amount,
    String? categoryId,
    double? thresholdWarningAmount,
    double? thresholdWarningPercent,
    String overSpending = BudgetOverSpending.over,
    DateTime? startDate,
    DateTime? endDate,
    bool recurrence = true,
    String? timeRecurrence = BudgetRecurrence.month,
    DateTime? nextTimeRecurrence,
    String note = '',
  }) async {
    if (idaccount == null || idaccount <= 0) {
      emit(const BudgetError('Chưa đăng nhập — không tạo được ngân sách.'));
      return;
    }
    try {
      await repository.addBudget(
        idaccount: idaccount,
        amount: amount,
        categoryId: categoryId,
        thresholdWarningAmount: thresholdWarningAmount,
        thresholdWarningPercent: thresholdWarningPercent,
        overSpending: overSpending,
        startDate: startDate,
        endDate: endDate,
        recurrence: recurrence,
        timeRecurrence: timeRecurrence,
        nextTimeRecurrence: nextTimeRecurrence,
        note: note,
      );
      emit(const BudgetSaved('Đã tạo ngân sách.'));
    } catch (e) {
      emit(BudgetError(_readable(e)));
    }
  }

  /// Gợi ý hạn mức cho form. Không đổi state: form nhận qua callback, và một
  /// lỗi ở đây không đáng để thay cả trang bằng `BudgetError`.
  Future<double?> suggestAmount(int? idaccount, String categoryId) async {
    if (idaccount == null || idaccount <= 0) return null;
    try {
      return await repository.suggestAmount(idaccount, categoryId);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateBudget(BudgetEntity budget) async {
    try {
      await repository.updateBudget(budget);
      emit(const BudgetSaved('Đã cập nhật ngân sách.'));
    } catch (e) {
      emit(BudgetError(_readable(e)));
    }
  }

  Future<void> deleteBudget(String id) async {
    try {
      await repository.deleteBudget(id);
      emit(const BudgetSaved('Đã xoá ngân sách.'));
    } catch (e) {
      emit(BudgetError(_readable(e)));
    }
  }

  /// `ArgumentError.toString()` in ra cả tên tham số và giá trị — không phải
  /// thứ để đưa thẳng cho người dùng đọc.
  String _readable(Object e) => e is ArgumentError
      ? (e.message?.toString() ?? e.toString())
      : e.toString();

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
