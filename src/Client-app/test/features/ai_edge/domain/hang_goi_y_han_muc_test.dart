/// Tool `goi_y_han_muc` (bước 2): mức chi trung bình mỗi tháng từ
/// `suggestAmount` (đã làm tròn lên bội 10.000), kèm hạn mức hiện tại. Tool chỉ
/// XẾP và CẮT — không tính.
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so_tra_cuu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_goi_y_han_muc.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_so_lieu.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_nhan.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_so.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, String> _so(HangSoLieu h) => {for (final s in h.soLieu) s.nhan: s.chuoi};

void main() {
  const goiY = [
    GoiYDanhMuc(ten: 'Ăn uống', mucThang: 80000, hanMucHienTai: 1000000),
    GoiYDanhMuc(ten: 'Di chuyển', mucThang: 570000),
    GoiYDanhMuc(ten: 'Giáo dục', mucThang: 80000, hanMucHienTai: 50000),
    GoiYDanhMuc(ten: 'Giải trí', mucThang: 50000),
    GoiYDanhMuc(ten: 'Mua sắm', mucThang: 100000),
  ];

  test('⭐ xếp GIẢM DẦN theo mức, trần kToiDaMucMoiGoi; trạng thái có/chưa ngân sách', () {
    final kq = hangGoiYHanMuc(goiY: goiY, soNgayCuaSo: 19, soNgayConThieu: null);
    expect(kq.hang.map((h) => h.ten).toList(), ['Di chuyển', 'Mua sắm', 'Ăn uống', 'Giáo dục']);
    expect(kq.hang[0].trangThai, 'chưa có ngân sách');
    expect(kq.hang[2].trangThai, 'đã có ngân sách');
    expect(_so(kq.hang[2]), {'Chi trung bình mỗi tháng': '80.000 đ', 'Hạn mức hiện tại': '1.000.000 đ'});
    expect(_so(kq.hang[0]).containsKey('Hạn mức hiện tại'), isFalse);
    expect(kq.hang.every((h) => !h.canhBao), isTrue);
  });

  test('tổng hợp "Số ngày gần nhất" — câu "suy từ 19 ngày gần nhất" qua được kiemNhan', () {
    final kq = hangGoiYHanMuc(goiY: goiY, soNgayCuaSo: 19, soNgayConThieu: null);
    expect({for (final s in kq.tongHop) s.nhan: s.chuoi}, {'Số ngày gần nhất': '19 ngày'});
    final goi = GoiSoTraCuu()..them('goi_y_han_muc', kq);
    expect(kiemNhan('Di chuyển nên đặt 570.000 đ mỗi tháng, suy từ 19 ngày gần nhất.', [goi]), isTrue);
  });

  test('⭐ chưa đủ dữ liệu: 0 hàng, "Cần thêm dữ liệu" khi có số, chữ kèm không chữ số', () {
    final kq = hangGoiYHanMuc(goiY: const [], soNgayCuaSo: null, soNgayConThieu: 5);
    expect(kq.hang, isEmpty);
    expect({for (final s in kq.tongHop) s.nhan: s.chuoi}, {'Cần thêm dữ liệu': '5 ngày'});
    expect(kq.chuThem['ghi_chu'], 'chưa đủ dữ liệu để gợi ý hạn mức');
    final khongSo = hangGoiYHanMuc(goiY: const [], soNgayCuaSo: null, soNgayConThieu: null);
    expect(khongSo.tongHop, isEmpty, reason: 'null là chưa biết — không in "0 ngày"');
  });

  test('danh mục khớp mà không có gợi ý: chữ kèm nói rõ, tên vào tenLienQuan', () {
    final kq = hangGoiYHanMuc(goiY: const [], soNgayCuaSo: 19, soNgayConThieu: null, tenDaKhop: 'test1');
    expect(kq.hang, isEmpty);
    expect(kq.chuThem['ghi_chu'], 'không có khoản chi nào cho danh mục này trong cửa sổ');
    expect(kq.tenLienQuan, ['test1']);
  });

  test('mức <= 0 không thành hàng', () {
    final kq = hangGoiYHanMuc(
        goiY: const [GoiYDanhMuc(ten: 'X', mucThang: 0)], soNgayCuaSo: 19, soNgayConThieu: null);
    expect(kq.hang, isEmpty);
  });

  test('chữ kèm không chứa chữ số; mẫu câu tự qua kiemSo', () {
    for (final kq in [
      hangGoiYHanMuc(goiY: goiY, soNgayCuaSo: 19, soNgayConThieu: null),
      hangGoiYHanMuc(goiY: const [], soNgayCuaSo: null, soNgayConThieu: 5),
    ]) {
      expect(kq.chuThem.values.any((v) => RegExp(r'\d').hasMatch(v)), isFalse);
      final goi = GoiSoTraCuu()..them('goi_y_han_muc', kq);
      expect(kiemSo(goi.mauCau().cau, goi), isTrue, reason: goi.mauCau().cau);
    }
  });
}
