/// Nối dây `SoDuViService` có nguồn phiên (`taiKhoanPhien`) ở MỌI đường ghi sổ (G113 nợ 1). Ví nhà mà dịch vụ không biết tài
/// khoản đăng nhập thì `so_du_vi_service` luôn bỏ qua neo: người tạo ví trả hoá đơn / nạp mục tiêu từ ví chưa có neo là mất số dư
/// ban đầu, im lặng. `sl` là lazy — sai tên hay thiếu đối số chỉ nổ lúc chạy trên máy, nên đọc tệp DI.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final di = File('lib/core/di/injection_container.dart').readAsStringSync();

  String khoi(String dau) {
    final i = di.indexOf(dau);
    expect(i, isNonNegative, reason: 'mất khối DI `$dau`');
    return di.substring(i, di.indexOf('sl.register', i));
  }

  test('SoDuViService đăng ký với taiKhoanPhien', () {
    expect(di, contains('SoDuViService(db: sl(), taiKhoanPhien: () => sl<GoiRepository>().idaccount)'));
  });

  test('BillRepositoryImpl nhận soDuVi từ DI (không tự dựng bản thiếu nguồn phiên)', () {
    expect(khoi('BillRepositoryImpl('), contains('soDuVi: sl<SoDuViService>()'));
  });

  test('GoalRepositoryImpl nhận soDuVi từ DI (bốn đường nạp / rút / tích luỹ)', () {
    expect(khoi('GoalRepositoryImpl('), contains('soDuVi: sl<SoDuViService>()'));
  });

  test('goal_repository_impl không dựng SoDuViService tại chỗ ngoài nhánh dự phòng của test', () {
    final src = File('lib/features/goal/data/repositories/goal_repository_impl.dart').readAsStringSync();
    expect(RegExp(r'SoDuViService\(db:').allMatches(src).length, 1, reason: 'đúng MỘT chỗ dựng (nhánh dự phòng khi không tiêm)');
  });
}
