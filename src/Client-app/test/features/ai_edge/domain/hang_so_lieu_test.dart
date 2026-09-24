/// Một HÀNG đầy đủ — thứ chặng 4a đo được là còn thiếu: gói số 4a mang tên trên
/// từng `SoLieu` rời và E2B không nối được hai mục rời. Hàng gom tên + trạng
/// thái + số của một đối tượng vào MỘT object JSON cho mô hình.
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_so_lieu.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('json của hàng: ten, trang_thai, rồi nhãn → CHUỖI đã định dạng', () {
    final h = HangSoLieu(
      ten: 'Kiem',
      trangThai: 'đã quá hạn',
      canhBao: true,
      soLieu: [soTien('Số tiền', 45000, ten: 'Kiem')],
    );
    expect(
      h.json,
      {'ten': 'Kiem', 'trang_thai': 'đã quá hạn', 'Số tiền': '45.000 đ'},
      reason: 'Mô hình chép nguyên chuỗi thì kiemSo khớp; bơm soTho (45000.0) '
          'là dạy nó viết một con số không có trong gói.',
    );
  });

  test('hàng không trạng thái (danh mục chi) không có khoá trang_thai', () {
    final h = HangSoLieu(
      ten: 'Ăn uống',
      trangThai: null,
      canhBao: false,
      soLieu: [soTien('Chi', 800000, ten: 'Ăn uống')],
    );
    expect(h.json.containsKey('trang_thai'), isFalse);
    expect(h.json, {'ten': 'Ăn uống', 'Chi': '800.000 đ'});
  });

  test('json của kết quả: hang + tổng hợp + chữ kèm không số', () {
    final kq = KetQuaCongCu(
      hang: [
        HangSoLieu(
          ten: 'Ăn uống',
          trangThai: null,
          canhBao: false,
          soLieu: [soTien('Chi', 800000, ten: 'Ăn uống')],
        ),
      ],
      tongHop: [soTien('Tổng chi', 2141000), soTien('Tổng thu', 15135000)],
      chuThem: const {'ky': 'tháng trước'},
    );
    expect(kq.json, {
      'hang': [
        {'ten': 'Ăn uống', 'Chi': '800.000 đ'}
      ],
      'Tổng chi': '2.141.000 đ',
      'Tổng thu': '15.135.000 đ',
      'ky': 'tháng trước',
    });
    expect(kq.loi, isNull);
  });

  test('từ chối tham số lạ: không hàng, không tổng hợp, chỉ lời nói vì sao', () {
    const kq = KetQuaCongCu.loi('ky "hom_qua" không hợp lệ',
        choNguoiDung: 'chưa hiểu khoảng thời gian trong câu hỏi', thamSoGo: ['ky']);
    expect(kq.hang, isEmpty);
    expect(kq.tongHop, isEmpty);
    expect(kq.json, {'loi': 'ky "hom_qua" không hợp lệ'},
        reason: 'Không có khoá "hang" rỗng: mô hình đọc `{}` rỗng là "không có '
            'gì" trong khi thật ra là "tham số sai" — hai câu trả lời khác nhau.');
  });

  test('tenLienQuan KHÔNG vào json — tên đã có trong trang_thai / loi (bước 2)', () {
    const kq = KetQuaCongCu(hang: [], tongHop: [], tenLienQuan: ['test1']);
    expect(kq.json.containsKey('tenLienQuan'), isFalse);
    expect(kq.json, isEmpty);
    const tuChoi = KetQuaCongCu.loi('danh_muc "x" không khớp.',
        choNguoiDung: 'không có danh mục nào tên "x"', thamSoGo: ['danh_muc'], tenLienQuan: ['Ăn uống']);
    expect(tuChoi.tenLienQuan, ['Ăn uống']);
    expect(tuChoi.json, {'loi': 'danh_muc "x" không khớp.'});
  });

  test('⭐ câu cho người dùng và tham số gỡ KHÔNG vào json — mô hình chỉ thấy loi (bước 2b)', () {
    const kq = KetQuaCongCu.loi('vi "x" không khớp tên nào.',
        choNguoiDung: 'không có ví nào tên "x"', thamSoGo: ['vi']);
    expect(kq.json, {'loi': 'vi "x" không khớp tên nào.'});
    expect(kq.choNguoiDung, 'không có ví nào tên "x"');
    expect(kq.thamSoGo, ['vi']);
  });

  test('⭐ bộ lọc dội lại (bước 2c): soLieuBoLoc vào json y như tongHop; boLoc và rongTheoBoLoc KHÔNG vào', () {
    final kq = KetQuaCongCu(
      hang: const [],
      tongHop: [soDem('Số giao dịch', 0)],
      soLieuBoLoc: [soTien('Đến', 1000000)],
      boLoc: const ['ghi chú chứa "chi"', 'đến 1.000.000 đ'],
      rongTheoBoLoc: true,
      chuThem: const {'ky': 'tháng này'},
    );
    expect(
      kq.json,
      {'Số giao dịch': '0', 'Đến': '1.000.000 đ', 'ky': 'tháng này'},
      reason: 'JSON gửi mô hình KHÔNG đổi so với khi Từ/Đến còn ở tongHop — mô hình vẫn '
          'thấy khoảng đã hiểu; boLoc chứa chữ số nên không được lọt vào JSON',
    );
    expect(kq.rongTheoBoLoc, isTrue);
    expect(kq.boLoc, hasLength(2));
  });

  test('mặc định không rỗng theo bộ lọc, không bộ lọc; lời từ chối cũng vậy', () {
    const kq = KetQuaCongCu(hang: [], tongHop: []);
    expect(kq.rongTheoBoLoc, isFalse);
    expect(kq.boLoc, isEmpty);
    expect(kq.soLieuBoLoc, isEmpty);
    const tc = KetQuaCongCu.loi('x', choNguoiDung: 'y', thamSoGo: ['ky']);
    expect(tc.rongTheoBoLoc, isFalse);
    expect(tc.boLoc, isEmpty);
    expect(tc.soLieuBoLoc, isEmpty);
    expect(tc.json, {'loi': 'x'});
  });

  test('kết quả THÀNH CÔNG không mang câu từ chối hay tham số gỡ', () {
    const kq = KetQuaCongCu(hang: [], tongHop: []);
    expect(kq.loi, isNull);
    expect(kq.choNguoiDung, isNull);
    expect(kq.thamSoGo, isEmpty);
  });
}
