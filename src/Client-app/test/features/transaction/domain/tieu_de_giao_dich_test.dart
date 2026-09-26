/// Tiêu đề một dòng giao dịch — MỘT định nghĩa cho Sổ giao dịch và tool
/// `tim_giao_dich` (bước 2). Ghi chú → tên danh mục → nhãn loại.
library;

import 'package:flowmoney/features/transaction/domain/tieu_de_giao_dich.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ghi chú thắng (đã trim)', () {
    expect(tieuDeGiaoDich(loai: 'chi', ghiChu: '  Cà phê ', tenDanhMuc: 'Ăn uống'), 'Cà phê');
  });
  test('không ghi chú → tên danh mục', () {
    expect(tieuDeGiaoDich(loai: 'chi', ghiChu: ' ', tenDanhMuc: 'Ăn uống'), 'Ăn uống');
  });
  test('không ghi chú, không danh mục → nhãn loại', () {
    expect(tieuDeGiaoDich(loai: 'chi', ghiChu: '', tenDanhMuc: null), 'Khoản chi');
    expect(tieuDeGiaoDich(loai: 'thu', ghiChu: '', tenDanhMuc: null), 'Khoản thu');
  });
  test('⭐ khoản chuyển không ghi chú là "Chuyển khoản" — kể cả khi có tên danh mục', () {
    expect(tieuDeGiaoDich(loai: 'transfer', ghiChu: '', tenDanhMuc: 'Ăn uống'), 'Chuyển khoản',
        reason: 'buildTransactionRowContent chưa bao giờ đặt tên danh mục cho khoản chuyển');
  });
}
