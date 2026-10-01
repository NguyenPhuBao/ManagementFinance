/// Thu nhập trung bình MỖI THÁNG từ một cửa sổ nhìn lại (B3 dời về
/// `analytics/domain` để trang Phân tích dùng mà không phụ thuộc `ai_edge`).
///
/// ⚠️ Thu nhập KHÔNG gồm tiền đi vay / thu nợ (bẫy A8 #8): lấy `type = 'thu'`
/// trần là tháng nào vay tiền thì "thu nhập" phồng lên.
library;

import 'package:flowmoney/features/analytics/domain/thong_ke_thang.dart';
import 'package:flowmoney/features/analytics/domain/thu_nhap_moi_thang.dart';
import 'package:flowmoney/features/budget/domain/cua_so_nhin_lai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 28, 12);
  final moc = now.subtract(const Duration(days: 30));

  KhoanThuChi k(int truocNgay, double tien, String loai,
          {String? cat, String? classify, String? ten}) =>
      KhoanThuChi(
        ngay: now.subtract(Duration(days: truocNgay)),
        soTien: tien,
        loai: loai,
        categoryId: cat,
        classify: classify,
        tenDanhMuc: ten,
      );

  test('cửa sổ 30 ngày: lương 15.000.000 → 15.000.000 mỗi tháng; tiền ĐI VAY không tính', () {
    final cuaSo = cuaSoNhinLai(now, moc)!;
    expect(cuaSo.soNgay, 30, reason: 'tiền đề: cửa sổ đúng 30 ngày');
    final khoan = [
      k(20, 15000000, 'thu', cat: 'luong', classify: 'thu', ten: 'Lương'),
      k(10, 5000000, 'thu', cat: 'vay', classify: 'vay_no', ten: 'Đi vay'),
      k(5, 300000, 'chi', cat: 'an', classify: 'chi', ten: 'Ăn uống'),
    ];
    expect(thuNhapMoiThangTu(khoan, cuaSo), 15000000.0 / 30 * kSoNgayMotThang,
        reason: 'thu nhập = tổng thu − tiền vào nhóm vay/nợ (bẫy A8 #8); tháng vay tiền '
            'mà "thu nhập" phồng lên là phép neo ngưỡng giãn sai, im lặng');
  });

  test('khoản ngoài cửa sổ (trước mốc, hoặc ở tương lai) không tính', () {
    final cuaSo = cuaSoNhinLai(now, moc)!;
    final khoan = [
      k(20, 15000000, 'thu', cat: 'luong', classify: 'thu', ten: 'Lương'),
      k(45, 9000000, 'thu', cat: 'luong', classify: 'thu', ten: 'Lương'),
      k(-10, 9000000, 'thu', cat: 'luong', classify: 'thu', ten: 'Lương'),
    ];
    expect(thuNhapMoiThangTu(khoan, cuaSo), 15000000.0);
  });

  test('không có khoản nào → 0', () {
    expect(thuNhapMoiThangTu(const [], cuaSoNhinLai(now, moc)!), 0);
  });
}
