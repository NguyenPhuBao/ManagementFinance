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
  String _phanLoaiDangXem = 'chi';
  final Set<String> _danhMucXuHuong = {};

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
    // Đổi tháng là đổi câu hỏi — bắt đầu lại từ Chi. Danh mục xu hướng thì
    // GIỮ: chuỗi của nó nhìn xa sáu tháng nên vẫn có nghĩa ở tháng khác.
    _phanLoaiDangXem = 'chi';
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
  /// donut tự nhảy về nhóm Chi trong khi người dùng đang xem. Không exception,
  /// không log.
  AnalyticsLoaded _dungLoaded(ThongKeThang tk, DateTime now) {
    // Nhóm đã chọn có thể biến mất: tháng này không có khoản vay/nợ nào. Giữ
    // nguyên là vẽ một vòng tròn trống dưới một chip đã biến mất. Rơi về Chi;
    // Chi cũng rỗng (tháng chỉ có thu) thì rơi về nhóm đầu còn phát sinh —
    // nếu không donut trống dù có dữ liệu để vẽ.
    final coNhom = tk.latPhanLoai.any((l) => l.phanLoai == _phanLoaiDangXem);
    if (!coNhom) {
      final coChi = tk.latPhanLoai.any((l) => l.phanLoai == 'chi');
      _phanLoaiDangXem = coChi
          ? 'chi'
          : (tk.latPhanLoai.isEmpty ? 'chi' : tk.latPhanLoai.first.phanLoai);
    }
    // Danh mục đã chọn cũng vậy — bị xoá, hoặc tháng khác không có phát sinh.
    // Chỉ loại đúng khoá ấy: xoá cả tập là người dùng mất luôn những đường
    // còn hợp lệ.
    _danhMucXuHuong.removeWhere((id) => !tk.chuoiDanhMuc.containsKey(id));
    return AnalyticsLoaded(
      thongKe: tk,
      cacThang: cacThangGanNhat(now),
      phanLoaiDangXem: _phanLoaiDangXem,
      danhMucXuHuong: Set.unmodifiable(_danhMucXuHuong),
    );
  }

  /// Chọn nhóm cho khối "Cơ cấu theo danh mục" — một trong
  /// `kCategoryClassifies`.
  void chonPhanLoai(String phanLoai) {
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

  /// Bật/tắt một danh mục trên khối xu hướng. Tập rỗng là hai đường Thu/Chi.
  ///
  /// Trần `kToiDaDuongXuHuong`: đang đủ trần mà bật thêm thì **không làm gì**
  /// — trang khoá chip tương ứng nên người dùng thấy được vì sao. Chốt đặt ở
  /// đây chứ không chỉ ở widget, để một đường gọi khác (test, deep link sau
  /// này) không vượt được.
  void batTatDanhMucXuHuong(String categoryId) {
    final s = state;
    if (s is! AnalyticsLoaded) return;
    if (_danhMucXuHuong.contains(categoryId)) {
      _danhMucXuHuong.remove(categoryId);
    } else {
      if (_danhMucXuHuong.length >= kToiDaDuongXuHuong) return;
      _danhMucXuHuong.add(categoryId);
    }
    emit(AnalyticsLoaded(
      thongKe: s.thongKe,
      cacThang: s.cacThang,
      phanLoaiDangXem: s.phanLoaiDangXem,
      danhMucXuHuong: Set.unmodifiable(_danhMucXuHuong),
    ));
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
