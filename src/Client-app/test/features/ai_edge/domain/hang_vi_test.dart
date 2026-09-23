/// Tool `danh_sach_vi`: hàng theo TÊN, ví âm đứng đầu, trạng thái do
/// `viTinhVaoTong` + `viDangAm` quyết — cùng luật với gói ví (chặng 1.5).
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so_vi.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_vi.dart';
import 'package:flutter_test/flutter_test.dart';

ViChoGoiSo _vi(
  String ten,
  double soDu, {
  bool trongTong = true,
  String status = 'active',
  bool daXoa = false,
  bool choPhepAm = false,
}) =>
    ViChoGoiSo(
      ten: ten,
      soDu: soDu,
      includeInTotal: trongTong,
      status: status,
      isDeleted: daXoa,
      allowNegative: choPhepAm,
    );

void main() {
  test('⭐ ví âm đứng đầu, trạng thái "đang âm", cờ cảnh báo; ví thường "bình thường"', () {
    final kq = hangVi([
      _vi('Tiền mặt', 9903000),
      _vi('test', -100000),
      _vi('Tiết kiệm', 3201000),
    ]);
    expect(kq.hang.map((h) => h.ten).toList(), ['test', 'Tiết kiệm', 'Tiền mặt']);
    expect(kq.hang.first.trangThai, 'đang âm');
    expect(kq.hang.first.canhBao, isTrue);
    expect(kq.hang.first.json, {'ten': 'test', 'trang_thai': 'đang âm', 'Số dư': '-100.000 đ'});
    expect(kq.hang[1].trangThai, 'bình thường');
    expect(kq.hang[1].canhBao, isFalse);
    expect(kq.hang.every((h) => h.soLieu.single.ten == h.ten), isTrue);
  });

  test('ví được phép âm (G27) không phải "đang âm"', () {
    final kq = hangVi([_vi('Thẻ tín dụng', -2000000, choPhepAm: true)]);
    expect(kq.hang.single.trangThai, 'bình thường');
    expect(kq.hang.single.canhBao, isFalse);
  });

  test('ví ngoài tổng và ví lưu trữ có trạng thái riêng, không cộng vào tổng', () {
    final kq = hangVi([
      _vi('Tiền mặt', 1000000),
      _vi('Quỹ riêng', 500000, trongTong: false),
      _vi('Ví cũ', 300000, status: 'inactive'),
    ]);
    final theoTen = {for (final h in kq.hang) h.ten: h.trangThai};
    expect(theoTen['Quỹ riêng'], 'ngoài tổng');
    expect(theoTen['Ví cũ'], 'lưu trữ');
    expect(kq.tongHop.map((s) => '${s.nhan}=${s.chuoi}').toList(),
        ['Tổng tài sản=1.000.000 đ', 'Số ví=1']);
  });

  test('ví xoá mềm không thành hàng, không vào tổng', () {
    final kq = hangVi([_vi('Cũ', 500000, daXoa: true), _vi('Tiền mặt', 100000)]);
    expect(kq.hang.map((h) => h.ten).toList(), ['Tiền mặt']);
    expect(kq.tongHop.first.chuoi, '100.000 đ');
  });

  test('trần kToiDaMucMoiGoi hàng; Số ví vẫn đếm đủ', () {
    final kq = hangVi([for (var i = 0; i < 6; i++) _vi('V$i', 1000.0 * (i + 1))]);
    expect(kq.hang.length, 4);
    expect(kq.tongHop[1].chuoi, '6');
  });

  test('viDangAm là MỘT định nghĩa dùng chung với gói ví', () {
    final am = _vi('test', -100000);
    expect(viDangAm(am), isTrue);
    expect(GoiSoVi.tu([am]).soViAm, 1,
        reason: 'gói ví và tool ví phải cùng đếm một ví là âm');
    expect(viDangAm(_vi('không đáng kể', -0.4)), isFalse,
        reason: 'ngưỡng nửa đồng: đuôi lẻ của double không phải ví âm');
  });
}
