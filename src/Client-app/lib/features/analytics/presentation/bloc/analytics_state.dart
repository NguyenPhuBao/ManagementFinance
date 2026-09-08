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

  const AnalyticsLoaded({required this.thongKe, required this.cacThang});

  @override
  List<Object?> get props => [thongKe, cacThang];
}

class AnalyticsError extends AnalyticsState {
  final String message;

  const AnalyticsError(this.message);

  @override
  List<Object?> get props => [message];
}
