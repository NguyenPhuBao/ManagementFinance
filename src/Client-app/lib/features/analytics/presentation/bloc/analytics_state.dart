import 'package:equatable/equatable.dart';

import '../../data/analytics_repository.dart';
import '../../domain/pham_vi_ky.dart';

abstract class AnalyticsState extends Equatable {
  const AnalyticsState();

  @override
  List<Object?> get props => [];
}

class AnalyticsInitial extends AnalyticsState {
  const AnalyticsInitial();
}

class AnalyticsLoading extends AnalyticsState {
  final Ky ky;

  const AnalyticsLoading({required this.ky});

  @override
  List<Object?> get props => [ky];
}

class AnalyticsLoaded extends AnalyticsState {
  final ThongKeKy thongKe;

  /// Số đọc của `clock` lúc dựng state.
  ///
  /// Bộ chọn phải lướt được danh sách của **đơn vị người dùng đang xem** trước
  /// khi họ chọn kỳ nào; bắt cubit giữ danh sách ấy nghĩa là mỗi lần chạm một
  /// chip là một vòng cubit → state → dựng lại cả trang, cho một thao tác chưa
  /// đổi dữ liệu. Sheet tự gọi `cacKyGanNhat(moc, donVi)` — luật "12 kỳ" vẫn có
  /// đúng một chỗ định nghĩa ở domain và vẫn được test ở đó.
  ///
  /// Lấy từ đây chứ không gọi `DateTime.now()` trong widget, để widget test
  /// không phụ thuộc đồng hồ máy chạy nó.
  final DateTime moc;

  /// Nhóm đang chọn ở khối "Cơ cấu theo danh mục" — một trong
  /// `kCategoryClassifies`, mặc định `'chi'`. Không null: mức gốc ba lát
  /// (A8 #2) đã bỏ ngày 2026-09-14, nên luôn có đúng một nhóm đang mở.
  ///
  /// Nằm ở state chứ không ở widget vì **hai** khối phải đọc cùng một lựa
  /// chọn — donut và danh sách danh mục cuối trang. Hai chỗ giữ hai bản là
  /// donut nói 8.2M mà danh sách cộng ra 8.5M.
  final String phanLoaiDangXem;

  /// Các danh mục đang vẽ ở khối xu hướng; rỗng là hai đường Thu/Chi. Tối đa
  /// `kToiDaDuongXuHuong` phần tử — cubit chốt, trang chỉ phản ánh.
  final Set<String> danhMucXuHuong;

  const AnalyticsLoaded({
    required this.thongKe,
    required this.moc,
    this.phanLoaiDangXem = 'chi',
    this.danhMucXuHuong = const {},
  });

  @override
  List<Object?> get props => [thongKe, moc, phanLoaiDangXem, danhMucXuHuong];
}

class AnalyticsError extends AnalyticsState {
  final String message;

  const AnalyticsError(this.message);

  @override
  List<Object?> get props => [message];
}
