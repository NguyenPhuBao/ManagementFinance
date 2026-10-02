/// Dự án C, việc đầu — gợi ý danh mục theo SỐ TIỀN (spec `2026-10-02-du-an-c-goi-y-danh-muc-theo-so-tien-design.md`).
/// Luật thuần; chỗ nối trên màn ở `transaction/presentation/add_transaction_goi_y_so_tien_test.dart`.
library;

import 'package:flowmoney/features/bill/domain/bill_note.dart';
import 'package:flowmoney/features/category/domain/phan_loai_ghi_chu.dart';
import 'package:flowmoney/features/category/domain/phan_loai_so_tien.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _GiaoDich = ({
  String loai,
  String? categoryId,
  String? ghiChu,
  double soTien,
  String walletId,
  DateTime ngay,
  bool daXoa
});

/// Mặc định: khoản chi, không ghi chú, ví cash, 01/09/2026 (thứ Ba).
_GiaoDich _gd(
  String? c,
  double soTien, {
  String loai = 'chi',
  String? ghiChu = '',
  String vi = 'cash',
  DateTime? ngay,
  bool daXoa = false,
}) =>
    (
      loai: loai,
      categoryId: c,
      ghiChu: ghiChu,
      soTien: soTien,
      walletId: vi,
      ngay: ngay ?? DateTime(2026, 9, 1),
      daXoa: daXoa,
    );

void main() {
  group('bacTienCua — thang 1·2·5', () {
    test('biên từng bậc', () {
      expect(bacTienCua(9999), (duoi: 0, tren: 10000));
      expect(bacTienCua(10000), (duoi: 10000, tren: 20000));
      expect(bacTienCua(19999), (duoi: 10000, tren: 20000));
      expect(bacTienCua(20000), (duoi: 20000, tren: 50000));
      expect(bacTienCua(35000), (duoi: 20000, tren: 50000));
      expect(bacTienCua(49999), (duoi: 20000, tren: 50000));
      expect(bacTienCua(50000), (duoi: 50000, tren: 100000), reason: 'biên dưới thuộc bậc trên');
      expect(bacTienCua(1000000), (duoi: 1000000, tren: 2000000));
      expect(bacTienCua(3000000), (duoi: 2000000, tren: 5000000));
    });

    test('con số lớn nhất bàn phím cho gõ (13 chữ số) vẫn có bậc', () {
      expect(bacTienCua(9999999999999), (duoi: 5000000000000, tren: 10000000000000));
    });

    test('đuôi lẻ double: 49999,99999994 là 50.000 (ngưỡng nửa đồng)', () {
      expect(bacTienCua(49999.99999994), (duoi: 50000, tren: 100000));
    });

    test('dung sai chỉ NỬA đồng: 49999,4 vẫn ở bậc dưới', () {
      expect(bacTienCua(49999.4), (duoi: 20000, tren: 50000));
      expect(bacTienCua(9999.4), (duoi: 0, tren: 10000));
    });

    test('mã bậc', () {
      expect(maBacCua(bacTienCua(35000)), '20000-50000');
      expect(maBacCua(bacTienCua(7000)), '0-10000');
    });
  });

  group('nhomThuCua', () {
    test('thứ Sáu là ngày thường, thứ Bảy và Chủ nhật là cuối tuần, thứ Hai lại là ngày thường', () {
      expect(nhomThuCua(DateTime(2026, 9, 4)), kNhomNgayThuong); // thứ Sáu
      expect(nhomThuCua(DateTime(2026, 9, 5)), kNhomCuoiTuan); // thứ Bảy
      expect(nhomThuCua(DateTime(2026, 9, 6)), kNhomCuoiTuan); // Chủ nhật
      expect(nhomThuCua(DateTime(2026, 9, 7)), kNhomNgayThuong); // thứ Hai
    });

    test('29/02 năm nhuận (thứ Ba)', () => expect(nhomThuCua(DateTime(2028, 2, 29)), kNhomNgayThuong));
  });

  group('mauSoTienTu', () {
    test('⭐ khoản KHÔNG ghi chú vẫn là mẫu — tín hiệu ở đây là số tiền', () {
      final m = mauSoTienTu([_gd('food', 30000, ghiChu: null), _gd('food', 30000, ghiChu: '')]);
      expect(m, hasLength(2));
      expect(m.first.categoryId, 'food');
      expect(m.first.chieu, 'chi');
      expect(m.first.maBac, '20000-50000');
      expect(m.first.nhomThu, kNhomNgayThuong);
      expect(m.first.walletId, 'cash');
    });

    test('bỏ khoản chuyển khoản', () => expect(mauSoTienTu([_gd('food', 30000, loai: 'transfer')]), isEmpty));
    test('bỏ khoản không danh mục', () => expect(mauSoTienTu([_gd(null, 30000)]), isEmpty));
    test('bỏ khoản đã xoá', () => expect(mauSoTienTu([_gd('food', 30000, daXoa: true)]), isEmpty));
    test('bỏ khoản số tiền 0', () => expect(mauSoTienTu([_gd('food', 0)]), isEmpty));
    test('bỏ khoản do máy gắn ghi chú (trả hoá đơn)', () {
      expect(mauSoTienTu([_gd('food', 30000, ghiChu: '${kGhiChuTraHoaDon}Tiền nhà')]), isEmpty);
    });

    test('ghi chú do người gõ không làm mất mẫu', () {
      expect(mauSoTienTu([_gd('food', 30000, ghiChu: 'cafe sáng')]), hasLength(1));
    });
  });

  test('hằng nguồn không trùng nguồn nào của B1', () {
    expect({kNguonGoiYSoTien, kNguonGoiYHoc, kNguonGoiYTuKhoa, kNguonDeXuatTuKhoa}, hasLength(4));
  });
}
