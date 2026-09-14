/// Luật "một khoản thuộc phân loại nào", và phép gom tổng của từng phân loại
/// — nguồn cho ba chip của khối "Cơ cấu theo danh mục".
///
/// Canh chừng điều gì: app có HAI thứ dễ nhầm là một — `transaction.type`
/// (chiều tiền) và `category.classify` (phân loại danh mục). Một khoản Trả nợ
/// mang `type = 'chi'` nhưng `classify = 'vay_no'`. Lẫn hai thứ ấy thì vòng
/// tròn nói sai tỷ trọng mà không lỗi nào báo. Và ba nhóm phải RỜI NHAU: đếm
/// một khoản ở hai nhóm thì tổng vượt 100%, và một khoản chi gắn danh mục
/// vay/nợ bị cộng vào cả hai chip.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/analytics/domain/phan_loai_dong_tien.dart';
import 'package:flowmoney/features/analytics/domain/thong_ke_thang.dart';

final _from = DateTime(2026, 9, 1);
final _to = DateTime(2026, 10, 1);

KhoanThuChi _k({
  required double soTien,
  required String loai,
  String? categoryId = 'c1',
  String? classify,
  DateTime? ngay,
  String? ghiChu,
}) =>
    KhoanThuChi(
      ngay: ngay ?? DateTime(2026, 9, 15),
      soTien: soTien,
      loai: loai,
      categoryId: categoryId,
      classify: classify,
      ghiChu: ghiChu,
    );

void main() {
  group('phanLoaiCua', () {
    test('lấy classify của danh mục khi tra được', () {
      expect(
        phanLoaiCua(loai: 'chi', classifyDanhMuc: 'vay_no'),
        'vay_no',
        reason: 'Khoản Trả nợ mang type=chi nhưng phải xếp vào lát vay/nợ',
      );
    });

    test('rơi về type khi không tra được danh mục', () {
      expect(
        phanLoaiCua(loai: 'chi', classifyDanhMuc: null),
        'chi',
        reason: 'Đo 2026-09-10: server có 17 hàng giao dịch trống danh mục — '
            'loại chúng khỏi thống kê là giấu mất chi tiêu thật',
      );
      expect(phanLoaiCua(loai: 'thu', classifyDanhMuc: null), 'thu');
    });

    test('rơi về type khi classify là giá trị lạ', () {
      expect(
        phanLoaiCua(loai: 'chi', classifyDanhMuc: 'khong_ton_tai'),
        'chi',
        reason: 'Giá trị ngoài ba phân loại hợp lệ không được tạo ra lát thứ tư',
      );
    });
  });

  group('theoPhanLoai', () {
    test('ba nhóm rời nhau, tổng tỉ lệ bằng 1', () {
      final ds = [
        _k(soTien: 6000, loai: 'thu', classify: 'thu'),
        _k(soTien: 3000, loai: 'chi', classify: 'chi'),
        _k(soTien: 1000, loai: 'chi', classify: 'vay_no'),
      ];

      final lat = theoPhanLoai(ds, from: _from, to: _to);

      expect(lat.length, 3);
      expect(lat.map((l) => l.phanLoai).toList(), ['thu', 'chi', 'vay_no'],
          reason: 'Sắp giảm dần theo số tiền');
      expect(lat.map((l) => l.soTien).toList(), [6000, 3000, 1000]);
      expect(
        lat.fold<double>(0, (s, l) => s + l.tiLe),
        closeTo(1.0, 1e-9),
        reason: 'Ba lát rời nhau nên tổng tỉ lệ phải đúng 100%',
      );
    });

    test('khoản chi gắn danh mục vay/nợ KHÔNG nằm ở lát chi', () {
      final ds = [
        _k(soTien: 3000, loai: 'chi', classify: 'chi'),
        _k(soTien: 1000, loai: 'chi', classify: 'vay_no'),
      ];

      final lat = theoPhanLoai(ds, from: _from, to: _to);
      final chi = lat.firstWhere((l) => l.phanLoai == 'chi');

      expect(
        chi.soTien,
        3000,
        reason: 'Lát Chi cố ý KHÁC Tổng chi (4000) — phần vay/nợ đã sang lát '
            'riêng; xem §2.1 của spec',
      );
    });

    test('lát rỗng bị bỏ, không vẽ lát 0', () {
      final ds = [
        _k(soTien: 5000, loai: 'thu', classify: 'thu'),
        _k(soTien: 2000, loai: 'chi', classify: 'chi'),
      ];

      final lat = theoPhanLoai(ds, from: _from, to: _to);

      expect(lat.map((l) => l.phanLoai).toList(), ['thu', 'chi'],
          reason: 'Tài khoản không dùng vay/nợ thì không có lát vay/nợ');
    });

    test('khoản chuyển ví và khoản mở sổ không lọt vào lát nào', () {
      final ds = [
        _k(soTien: 5000, loai: 'thu', classify: 'thu'),
        _k(soTien: 9000, loai: 'transfer', classify: null),
        _k(
          soTien: 7000,
          loai: 'thu',
          categoryId: null,
          ghiChu: 'Số dư ban đầu',
        ),
      ];

      final lat = theoPhanLoai(ds, from: _from, to: _to);

      expect(lat.length, 1);
      expect(lat.single.soTien, 5000,
          reason: 'khoanVaoThongKe() loại transfer và khoản mở sổ trước mọi '
              'phép gom — đừng viết luật lọc thứ hai ở đây');
    });

    test('khoản ngoài khoảng bị loại', () {
      final ds = [
        _k(soTien: 5000, loai: 'thu', classify: 'thu'),
        _k(
          soTien: 9000,
          loai: 'thu',
          classify: 'thu',
          ngay: DateTime(2026, 10, 1),
        ),
      ];

      final lat = theoPhanLoai(ds, from: _from, to: _to);

      expect(lat.single.soTien, 5000,
          reason: 'Biên `to` MỞ: khoản 00:00 ngày 1/10 thuộc tháng 10');
    });

    test('không khoản nào thì trả danh sách rỗng', () {
      expect(theoPhanLoai(const [], from: _from, to: _to), isEmpty);
    });
  });

  group('danhMucTheoPhanLoai', () {
    test('chỉ gom danh mục trong lát được hỏi', () {
      final ds = [
        _k(soTien: 3000, loai: 'chi', categoryId: 'an', classify: 'chi'),
        _k(soTien: 1000, loai: 'chi', categoryId: 'di', classify: 'chi'),
        _k(soTien: 5000, loai: 'chi', categoryId: 'no', classify: 'vay_no'),
      ];

      final chi =
          danhMucTheoPhanLoai(ds, from: _from, to: _to, phanLoai: 'chi');

      expect(chi.map((c) => c.categoryId).toList(), ['an', 'di']);
      expect(chi.map((c) => c.soTien).toList(), [3000, 1000]);
      expect(chi.first.tiLe, closeTo(0.75, 1e-9),
          reason: 'Tỉ lệ tính trên tổng CỦA LÁT (4000), không phải tổng chi');
    });

    test('lát vay/nợ gom cả hai chiều tiền', () {
      final ds = [
        _k(soTien: 2000, loai: 'chi', categoryId: 'cho_vay', classify: 'vay_no'),
        _k(soTien: 3000, loai: 'thu', categoryId: 'di_vay', classify: 'vay_no'),
      ];

      final vn =
          danhMucTheoPhanLoai(ds, from: _from, to: _to, phanLoai: 'vay_no');

      expect(vn.map((c) => c.categoryId).toList(), ['di_vay', 'cho_vay'],
          reason: 'Vay/nợ là phân loại duy nhất gom cả tiền vào lẫn tiền ra');
      expect(vn.fold<double>(0, (s, c) => s + c.tiLe), closeTo(1.0, 1e-9));
    });

    test('khoản chưa phân loại vẫn được gom, khoá null', () {
      final ds = [
        _k(soTien: 1000, loai: 'chi', categoryId: 'an', classify: 'chi'),
        _k(soTien: 500, loai: 'chi', categoryId: null),
      ];

      final chi =
          danhMucTheoPhanLoai(ds, from: _from, to: _to, phanLoai: 'chi');

      expect(chi.map((c) => c.categoryId).toList(), ['an', null],
          reason: 'null xếp sau id thật khi sắp; tổng các lát phải bằng lát cha');
    });

    test('lát không có khoản nào thì rỗng', () {
      final ds = [_k(soTien: 1000, loai: 'chi', classify: 'chi')];

      expect(
        danhMucTheoPhanLoai(ds, from: _from, to: _to, phanLoai: 'thu'),
        isEmpty,
      );
    });

    test('tổng các danh mục bằng đúng số tiền của lát', () {
      final ds = [
        _k(soTien: 3000, loai: 'chi', categoryId: 'an', classify: 'chi'),
        _k(soTien: 1000, loai: 'chi', categoryId: 'di', classify: 'chi'),
        _k(soTien: 5000, loai: 'thu', categoryId: 'luong', classify: 'thu'),
      ];

      final lat = theoPhanLoai(ds, from: _from, to: _to);
      final latChi = lat.firstWhere((l) => l.phanLoai == 'chi');
      final dm = danhMucTheoPhanLoai(ds, from: _from, to: _to, phanLoai: 'chi');

      expect(
        dm.fold<double>(0, (s, c) => s + c.soTien),
        latChi.soTien,
        reason: 'Donut và danh sách dưới nó phải nói cùng một con số — §3.2 spec',
      );
    });
  });

  group('nhãn', () {
    test('nhanTongCua: mỗi phân loại một mẫu số', () {
      expect(nhanTongCua('chi'), 'tổng chi');
      expect(nhanTongCua('thu'), 'tổng thu');
      expect(nhanTongCua('vay_no'), 'vay/nợ');
    });

    test('tenLat: nhãn ngắn theo màn Stitch', () {
      expect(tenLat('chi'), 'Chi');
      expect(tenLat('thu'), 'Thu');
      expect(tenLat('vay_no'), 'Vay / nợ');
    });
  });
}
