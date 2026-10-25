import 'package:flowmoney/features/khoa_app/data/datasources/dong_ho_khoi_dong.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('docThoiGianKhoiDong: null (nền tảng không đọc được) hoặc số không âm tăng đều — không bao giờ ném', () {
    final a = docThoiGianKhoiDong();
    final b = docThoiGianKhoiDong();
    if (a == null) {
      expect(b, isNull, reason: 'khả năng đọc không được lúc có lúc không');
      return;
    }
    expect(a.isNegative, isFalse);
    expect(b, isNotNull);
    expect(b! >= a, isTrue, reason: 'đồng hồ đơn điệu');
  });
}
