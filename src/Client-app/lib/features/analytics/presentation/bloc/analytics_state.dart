import 'package:equatable/equatable.dart';

import '../../data/analytics_repository.dart';

abstract class AnalyticsState extends Equatable {
  const AnalyticsState();

  @override
  List<Object?> get props => [];
}

class AnalyticsInitial extends AnalyticsState {
  const AnalyticsInitial();
}

class AnalyticsLoading extends AnalyticsState {
  final int nam;
  final int thang;

  const AnalyticsLoading({required this.nam, required this.thang});

  @override
  List<Object?> get props => [nam, thang];
}

class AnalyticsLoaded extends AnalyticsState {
  final ThongKeThang thongKe;

  /// Các tháng bộ chọn cho phép, mới nhất trước. Tính ở cubit chứ không ở
  /// widget, để test được và để "12 tháng" có đúng một chỗ định nghĩa.
  final List<({int nam, int thang})> cacThang;

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
    required this.cacThang,
    this.phanLoaiDangXem = 'chi',
    this.danhMucXuHuong = const {},
  });

  @override
  List<Object?> get props =>
      [thongKe, cacThang, phanLoaiDangXem, danhMucXuHuong];
}

class AnalyticsError extends AnalyticsState {
  final String message;

  const AnalyticsError(this.message);

  @override
  List<Object?> get props => [message];
}
