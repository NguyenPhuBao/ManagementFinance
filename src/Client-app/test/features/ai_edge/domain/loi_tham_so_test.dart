/// Lời từ chối tham số — chỗ DUY NHẤT dựng đủ hai câu (spec bước 2b mục 2.1):
/// câu cho mô hình (`loi`, đủ để gọi lại đúng) và câu cho NGƯỜI DÙNG
/// (`choNguoiDung`, thứ mẫu câu trung thực L1b / L2b nói ra), cộng tham số gỡ.
///
/// Cổng D lần 1 (bẫy 4.40): lượt bị từ chối từng được tính là "đã tra cứu", và
/// E2B đọc lời từ chối thành "không có dữ liệu" — câu không số lọt ba lớp chắn.
library;

import 'package:flowmoney/features/ai_edge/domain/hang_so_lieu.dart';
import 'package:flowmoney/features/ai_edge/domain/loi_tham_so.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loiGiaTri: câu cho mô hình nêu giá trị nhận được và mọi giá trị đúng', () {
    expect(loiGiaTri('chieu', 'chi', ['khoan_chi', 'khoan_thu']),
        'chieu "chi" không hợp lệ. Chỉ nhận: khoan_chi, khoan_thu.');
  });

  test('⭐ enum lạ: câu cho người dùng theo tham số, không lộ mã; gỡ bằng chính tham số ấy', () {
    const mong = {
      'ky': 'chưa hiểu khoảng thời gian trong câu hỏi',
      'chieu': 'chưa hiểu loại giao dịch',
      'sap_xep': 'chưa hiểu cách sắp xếp',
      'trang_thai': 'chưa hiểu trạng thái hoá đơn',
    };
    for (final e in mong.entries) {
      final kq = tuChoiGiaTri(e.key, 'la', const ['a', 'b']);
      expect(kq.loi, loiGiaTri(e.key, 'la', const ['a', 'b']), reason: e.key);
      expect(kq.choNguoiDung, e.value, reason: e.key);
      expect(kq.thamSoGo, [e.key], reason: e.key);
      expect(kq.hang, isEmpty, reason: e.key);
    }
  });

  test('số tiền sai: ví dụ số đồng cho mô hình; người dùng không thấy số của mô hình', () {
    final kq = tuChoiSoTien('so_tien_tu', '500k');
    expect(kq.loi, 'so_tien_tu "500k" phải là số đồng, ví dụ 500000.');
    expect(kq.choNguoiDung, 'chưa hiểu số tiền trong câu hỏi');
    expect(kq.thamSoGo, ['so_tien_tu']);
  });

  test('khoảng ngược: nêu hai số cho mô hình; gỡ bằng một trong hai đầu', () {
    final kq = tuChoiKhoangNguoc('1000000', '200000');
    expect(kq.loi,
        'so_tien_tu (1000000) lớn hơn so_tien_den (200000). Gọi lại với khoảng đúng chiều.');
    expect(kq.choNguoiDung, 'khoảng số tiền bị ngược');
    expect(kq.thamSoGo, ['so_tien_tu', 'so_tien_den']);
  });

  test('⭐ tên không khớp: câu người dùng nêu TÊN đã hỏi theo đúng loại; tên sai vào tenLienQuan', () {
    final kq = tuChoiKhongKhop('vi', 'vi gia', const ['Tiền mặt', 'test1'], loai: 'ví');
    expect(kq.loi, 'vi "vi gia" không khớp tên nào. Chỉ có: Tiền mặt, test1.');
    expect(kq.choNguoiDung, 'không có ví nào tên "vi gia"');
    expect(kq.thamSoGo, ['vi']);
    expect(kq.tenLienQuan, ['Tiền mặt', 'test1', 'vi gia'],
        reason: 'tên sai vào tenDoiTuong để chữ số trong nó không bị đọc là số (bước 1c)');
    expect(
      tuChoiKhongKhop('danh_muc', 'muaxe', const ['Ăn uống'], loai: 'danh mục chi').choNguoiDung,
      'không có danh mục chi nào tên "muaxe"',
    );
  });

  test('tên khớp nhiều: liệt kê các tên đã khớp cho cả mô hình lẫn người dùng', () {
    final kq = tuChoiKhopNhieu('danh_muc', 'da', const ['Dá', 'Đá'], loai: 'danh mục');
    expect(kq.loi, 'danh_muc "da" khớp nhiều tên: Dá, Đá. Gọi lại với đúng một tên.');
    expect(kq.choNguoiDung, 'tên "da" khớp nhiều danh mục: Dá, Đá');
    expect(kq.thamSoGo, ['danh_muc']);
    expect(kq.tenLienQuan, ['Dá', 'Đá', 'da']);
  });

  test('⭐ tên gõ kiểu snake_case: câu người dùng đọc `_` là dấu cách; loi giữ chữ gõ; tenLienQuan cả hai (bẫy 4.45)', () {
    final kq = tuChoiKhongKhop('vi', 'vi_gia_2', const ['Tiền mặt'], loai: 'ví');
    expect(kq.choNguoiDung, 'không có ví nào tên "vi gia 2"',
        reason: 'C11 cổng D lần 2 hiện "tiet_kiem" cho người dùng — luật (a) spec 2b áp cả giá trị mô hình gõ');
    expect(kq.loi, contains('"vi_gia_2"'), reason: 'mô hình gọi lại bằng đúng chữ nó đã gõ');
    expect(kq.tenLienQuan, ['Tiền mặt', 'vi_gia_2', 'vi gia 2'],
        reason: 'câu mẫu in dạng đã đổi, mô hình có thể chép dạng gõ — cả hai không được đọc "2" là số');
    expect(
      tuChoiKhopNhieu('vi', 'tiet_kiem', const ['Tiết kiệm', 'Tiet kiem'], loai: 'ví').choNguoiDung,
      'tên "tiet kiem" khớp nhiều ví: Tiết kiệm, Tiet kiem',
    );
    expect(tuChoiKhongKhop('vi', 'vi gia', const ['Tiền mặt'], loai: 'ví').tenLienQuan,
        ['Tiền mặt', 'vi gia'], reason: 'không có `_` thì không thêm bản trùng');
  });

  test('⭐ số tiền trong tu_khoa: chỉ mô hình chỗ đúng; gỡ khi lượt sau điền so_tien_*', () {
    final kq = tuChoiTuKhoaLaSoTien('500k');
    expect(kq.loi, contains('so_tien_tu'));
    expect(kq.loi, contains('500000'));
    expect(kq.choNguoiDung, 'chưa hiểu số tiền trong câu hỏi');
    expect(kq.thamSoGo, ['so_tien_tu', 'so_tien_den']);
    expect(RegExp(r'\d').hasMatch(kq.choNguoiDung!), isFalse);
  });

  test('⭐ ba luật của câu cho người dùng — mọi loại từ chối (spec 2b mục 2.1)', () {
    final moiLoai = <KetQuaCongCu>[
      for (final p in ['ky', 'chieu', 'sap_xep', 'trang_thai'])
        tuChoiGiaTri(p, 'x_1', const ['a']),
      tuChoiSoTien('so_tien_tu', '500k'),
      tuChoiSoTien('so_tien_den', -1),
      tuChoiKhoangNguoc('1000000', '200000'),
      tuChoiKhongKhop('danh_muc', 'abc', const ['Ăn uống'], loai: 'danh mục'),
      tuChoiKhopNhieu('vi', 'tiet kiem', const ['Tiết kiệm', 'Tiet kiem'], loai: 'ví'),
      // Bước 2c: luật (a) áp cả giá trị mô hình gõ, không chỉ mã tham số.
      tuChoiKhongKhop('vi', 'tiet_kiem', const ['Tiền mặt'], loai: 'ví'),
      tuChoiKhopNhieu('danh_muc', 'an_uong', const ['Ăn uống', 'An uong'], loai: 'danh mục'),
    ];
    for (final kq in moiLoai) {
      final c = kq.choNguoiDung!;
      expect(c, isNot(contains('_')), reason: 'lộ mã tham số: $c');
      expect(RegExp(r'\d').hasMatch(c), isFalse, reason: 'chép số từ tham số mô hình: $c');
      expect(c.toLowerCase(), isNot(contains('không có giao dịch')), reason: c);
      expect(c.toLowerCase(), isNot(contains('không tìm thấy dữ liệu')), reason: c);
      expect(kq.thamSoGo, isNotEmpty, reason: c);
    }
  });
}
