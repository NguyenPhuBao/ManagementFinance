import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/analytics_repository.dart';
import '../../domain/thong_ke_thang.dart';
import 'analytics_state.dart';

export 'analytics_state.dart';

/// UI → AnalyticsCubit → AnalyticsRepository → Drift + BudgetRepository.
///
/// Cubit là chỗ quyết định **tháng nào** được hỏi và **mã tài khoản nào** đi
/// xuống. Cả hai đều không được đoán: tháng lấy từ [clock] (trang cũ hiện
/// "T6 2026" cứng trong khi đang là tháng 9), tài khoản lấy từ phiên đăng nhập
/// (quy tắc 2 `CLAUDE.md`).
class AnalyticsCubit extends Cubit<AnalyticsState> {
  final AnalyticsRepository repository;

  /// Tiêm được để test không phụ thuộc đồng hồ máy chạy nó.
  final DateTime Function() clock;

  StreamSubscription<ThongKeThang>? _sub;
  int? _idaccount;

  AnalyticsCubit({required this.repository, DateTime Function()? clock})
      : clock = clock ?? DateTime.now,
        super(const AnalyticsInitial());

  /// Xem tháng hiện tại của tài khoản [idaccount]. `null` là chưa đăng nhập —
  /// báo lỗi chứ không đoán một mã.
  void xem(int? idaccount) {
    if (idaccount == null || idaccount <= 0) {
      emit(const AnalyticsError('Chưa đăng nhập — không đọc được thống kê.'));
      return;
    }
    _idaccount = idaccount;
    final now = clock();
    _dangKy(now.year, now.month);
  }

  /// Đổi tháng đang xem. Không làm gì khi chưa có tài khoản.
  void chonThang(int nam, int thang) {
    if (_idaccount == null) return;
    _dangKy(nam, thang);
  }

  void _dangKy(int nam, int thang) {
    final now = clock();
    emit(AnalyticsLoading(nam: nam, thang: thang));
    // Huỷ đăng ký cũ TRƯỚC. Không huỷ là hai stream cùng phát và cái tới sau
    // thắng — không có gì bảo đảm đó là tháng người dùng vừa chọn. Bản sai có
    // chủ ý bỏ dòng này đã làm đúng test ấy đỏ.
    _sub?.cancel();
    _sub = repository
        .watchThang(_idaccount!, nam: nam, thang: thang, now: now)
        .listen(
          (tk) => emit(AnalyticsLoaded(
            thongKe: tk,
            cacThang: cacThangGanNhat(now),
          )),
          onError: (Object e) => emit(AnalyticsError(e.toString())),
        );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
