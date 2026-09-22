import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/budget_entity.dart';
import '../../../ai_edge/domain/tai_phan_bo.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/tai_phan_bo_nguon.dart';
import '../../domain/cua_so_nhin_lai.dart';
import '../../domain/de_xuat_ngan_sach.dart';
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
    var loaded = _loadedFrom(views);
    // ⚠️ Đề xuất tạo ngân sách tính TRƯỚC phép rẽ nhánh dưới đây, và đi vào cả
    // hai đường phát. Nó **không** phụ thuộc nguồn Tầng 2; đặt nó sau `return`
    // là để thẻ không bao giờ hiện ở mọi chỗ không nối `TaiPhanBoNguon` — và
    // hỏng im lặng, vì một thẻ không hiện trông y hệt một thẻ không có gì để
    // nói.
    final deXuat = await _deXuat(idaccount, loaded.active);
    // "Cần thêm N ngày" chỉ có nghĩa khi không có đề xuất nào; và phép đo này
    // là phần phụ — hỏng thì im, không đổi cả trang thành lỗi.
    int? thieu;
    if (deXuat == null) {
      try {
        thieu = soNgayConThieu(await repository.soNgayCoDuLieu(idaccount));
      } catch (_) {
        thieu = null;
      }
    }
    if (n != _lan || isClosed) return;
    loaded = loaded.copyWithDeXuat(deXuat, soNgayConThieu: thieu);

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
        deXuat: loaded.deXuat,
        soNgayConThieu: loaded.soNgayConThieu,
      ));
    } catch (e) {
      // Kế hoạch là phần phụ: nguồn hỏng thì trang vẫn hiện ngân sách.
      if (n != _lan || isClosed) return;
      emit(loaded);
    }
  }

  /// Danh mục chi đáng đặt ngân sách mà chưa có.
  ///
  /// Mỗi ứng viên một lời gọi `suggestAmount`, tức mỗi ứng viên một truy vấn.
  /// Danh mục chi của một tài khoản là con số nhỏ nên chấp nhận được; nếu có
  /// ngày nó chậm thấy rõ thì chỗ sửa là ở repository, không phải ở đây.
  ///
  /// Nuốt mọi lỗi: đây là một gợi ý phụ, không đáng để thay cả trang bằng
  /// `BudgetError`. Cùng lối với `suggestAmount` của form.
  Future<GoiDeXuat?> _deXuat(int idaccount, List<BudgetView> dangChay) async {
    try {
      final soNgay = await repository.soNgayCuaSoNhinLai(idaccount);
      if (soNgay == null) return null;

      final daCo = {
        for (final v in dangChay)
          if (v.budget.categoryId case final id?) id,
      };
      // `getExpenseCategories` ĐÃ lọc `classify = 'chi'` — đừng lọc lần nữa.
      final cats = await repository.getExpenseCategories(idaccount);

      final muc = <String, double?>{};
      for (final c in cats) {
        if (daCo.contains(c.id)) continue;
        muc[c.id] = await repository.suggestAmount(idaccount, c.id);
      }

      return chonDeXuat(
        danhMucChi: [
          for (final c in cats)
            (id: c.id, ten: c.name, icon: c.icon, colour: c.colour),
        ],
        daCoNganSach: daCo,
        mucThangTheoDanhMuc: muc,
        soNgayCuaSo: soNgay,
      );
    } catch (_) {
      return null;
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
      // Số ngày của cửa sổ là phần **phụ** của nhãn gợi ý: nó hỏng thì nhãn
      // im vế ấy, chứ không đổi cả form thành một màn lỗi.
      int? soNgay;
      try {
        soNgay = await repository.soNgayCuaSoNhinLai(idaccount);
      } catch (_) {
        soNgay = null;
      }
      // Cửa sổ chưa mở thì nhãn form NÓI RA còn thiếu bao nhiêu ngày, thay vì
      // im — cùng lý lẽ với thẻ ở trang danh sách.
      int? thieu;
      if (soNgay == null) {
        try {
          thieu = soNgayConThieu(await repository.soNgayCoDuLieu(idaccount));
        } catch (_) {
          thieu = null;
        }
      }
      emit(BudgetEditorReady(
        categories: categories,
        editing: editing,
        soNgayCuaSo: soNgay,
        soNgayConThieu: thieu,
      ));
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
