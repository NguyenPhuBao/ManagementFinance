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

  /// Hai lựa chọn của người dùng, giữ **ngoài** state để chúng sống sót qua
  /// mỗi lần repository phát lại. Xem [_dungLoaded].
  String? _phanLoaiDangXem;
  String? _danhMucXuHuong;

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
    // Đổi tháng là đổi câu hỏi — bắt đầu lại từ mức gốc. Danh mục xu hướng thì
    // GIỮ: chuỗi của nó nhìn xa sáu tháng nên vẫn có nghĩa ở tháng khác.
    _phanLoaiDangXem = null;
    emit(AnalyticsLoading(nam: nam, thang: thang));
    // Huỷ đăng ký cũ TRƯỚC. Không huỷ là hai stream cùng phát và cái tới sau
    // thắng — không có gì bảo đảm đó là tháng người dùng vừa chọn. Bản sai có
    // chủ ý bỏ dòng này đã làm đúng test ấy đỏ.
    _sub?.cancel();
    _sub = repository
        .watchThang(_idaccount!, nam: nam, thang: thang, now: now)
        .listen(
          (tk) => emit(_dungLoaded(tk, now)),
          onError: (Object e) => emit(AnalyticsError(e.toString())),
        );
  }

  /// Dựng `AnalyticsLoaded` **kèm hai lựa chọn đang giữ**, sau khi kiểm rằng
  /// chúng còn trỏ vào thứ có thật.
  ///
  /// ⚠️ Đây là chỗ chống cái bẫy im lặng lớn nhất của lát này: repository phát
  /// lại mỗi khi giao dịch, danh mục **hoặc** ngân sách đổi — kể cả khi đồng bộ
  /// nền kéo về. Quên chép lựa chọn sang state mới thì cứ mỗi chu kỳ đồng bộ là
  /// donut tự nhảy về mức gốc trong khi người dùng đang xem. Không exception,
  /// không log.
  AnalyticsLoaded _dungLoaded(ThongKeThang tk, DateTime now) {
    // Lát đã chọn có thể biến mất: tháng này không có khoản vay/nợ nào. Giữ
    // nguyên là vẽ một vòng tròn trống không nút nào thoát ra được.
    if (_phanLoaiDangXem != null &&
        !tk.latPhanLoai.any((l) => l.phanLoai == _phanLoaiDangXem)) {
      _phanLoaiDangXem = null;
    }
    // Danh mục đã chọn cũng vậy — bị xoá, hoặc tháng khác không có phát sinh.
    if (_danhMucXuHuong != null &&
        !tk.chuoiDanhMuc.containsKey(_danhMucXuHuong)) {
      _danhMucXuHuong = null;
    }
    return AnalyticsLoaded(
      thongKe: tk,
      cacThang: cacThangGanNhat(now),
      phanLoaiDangXem: _phanLoaiDangXem,
      danhMucXuHuong: _danhMucXuHuong,
    );
  }

  /// Mở một lát của vòng tròn, hoặc `null` để về mức gốc.
  void chonPhanLoai(String? phanLoai) {
    final s = state;
    if (s is! AnalyticsLoaded) return;
    _phanLoaiDangXem = phanLoai;
    emit(AnalyticsLoaded(
      thongKe: s.thongKe,
      cacThang: s.cacThang,
      phanLoaiDangXem: phanLoai,
      danhMucXuHuong: s.danhMucXuHuong,
    ));
  }

  /// Chọn danh mục cho khối xu hướng, hoặc `null` để về hai đường Thu/Chi.
  void chonDanhMucXuHuong(String? categoryId) {
    final s = state;
    if (s is! AnalyticsLoaded) return;
    _danhMucXuHuong = categoryId;
    emit(AnalyticsLoaded(
      thongKe: s.thongKe,
      cacThang: s.cacThang,
      phanLoaiDangXem: s.phanLoaiDangXem,
      danhMucXuHuong: categoryId,
    ));
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
