/// Tool `danh_sach_danh_muc` — hàng theo tên, không số; trần RIÊNG 20; tên phải
/// tới được `kiemTen` (spec mở rộng tool §4.3).
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so_tra_cuu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_danh_muc.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_cau_tra_loi.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_ten.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../category/presentation/category_test_fakes.dart';

void main() {
  final ds = [
    makeCategory(id: 'c1', name: 'Ăn uống'),
    makeCategory(id: 'c2', name: 'Di chuyển'),
    makeCategory(id: 'c3', name: 'Giải trí'),
    makeCategory(id: 'c4', name: 'Lương', classify: 'thu'),
    makeCategory(id: 'c5', name: 'Cho vay', classify: 'vay_no'),
    makeCategory(id: 'c6', name: 'test1'),
  ];
  const coNganSach = {'c1', 'c2'};

  test('⭐ mọi loại: xếp chi → thu → vay nợ rồi theo tên; trạng thái nói loại và ngân sách', () {
    final r = hangDanhMuc(ds, coNganSach: coNganSach);
    expect(r.hang.map((h) => h.ten).toList(),
        ['Ăn uống', 'Di chuyển', 'Giải trí', 'test1', 'Lương', 'Cho vay']);
    expect(r.hang[0].trangThai, 'khoản chi · có ngân sách');
    expect(r.hang[2].trangThai, 'khoản chi');
    expect(r.hang[4].trangThai, 'khoản thu');
    expect(r.hang[5].trangThai, 'vay nợ');
    expect(r.hang.every((h) => h.soLieu.isEmpty && !h.canhBao), isTrue);
  });

  test('không lọc: tổng và ba nhóm', () {
    final r = hangDanhMuc(ds, coNganSach: coNganSach);
    expect(r.json['Tổng số danh mục'], '6');
    expect(r.json['Nhóm chi'], '4');
    expect(r.json['Nhóm thu'], '1');
    expect(r.json['Nhóm vay nợ'], '1');
    expect(r.json['Đã có ngân sách'], '2');
  });

  test('⭐ P8: LỌC theo loại → gói chỉ mang số của nhóm ấy; "Có 6 danh mục chi" bị chặn', () {
    final r = hangDanhMuc(ds, coNganSach: coNganSach, loai: 'khoan_chi');
    expect(r.hang, hasLength(4));
    expect(r.json['Số danh mục'], '4');
    expect(r.json['Đã có ngân sách'], '2');
    expect(r.json.containsKey('Tổng số danh mục'), isFalse,
        reason: 'OnePlus 2026-09-28: "Có 15 danh mục chi tiêu" lọt vì 15 (tổng) có trong gói');
    expect(r.boLoc, ['nhóm khoản chi']);
    final g = GoiSoTraCuu()..them('danh_sach_danh_muc', r);
    expect(kiemCauTraLoi('Có 6 danh mục chi tiêu.', [g]), isFalse);
    expect(kiemCauTraLoi('Có 4 danh mục chi tiêu.', [g]), isTrue);
    expect(kiemCauTraLoi(g.mauCau().cau, [g]), isTrue, reason: g.mauCau().cau);
  });

  test('lọc khoản thu: một hàng, đếm một', () {
    final r = hangDanhMuc(ds, coNganSach: coNganSach, loai: 'khoan_thu');
    expect(r.hang.map((h) => h.ten).toList(), ['Lương']);
    expect(r.json['Số danh mục'], '1');
    expect(r.json['Đã có ngân sách'], '0');
  });

  test('loai lạ → từ chối, liệt kê giá trị đúng', () {
    final r = hangDanhMuc(ds, coNganSach: coNganSach, loai: 'chi_tieu');
    expect(r.loi, contains('khoan_chi'));
  });

  test('⚠️ trần RIÊNG 20, không phải 4: hai mươi lăm danh mục → hai mươi hàng, đếm vẫn đủ', () {
    final nhieu = [for (var i = 1; i <= 25; i++) makeCategory(id: 'x$i', name: 'Muc ${i.toString().padLeft(2, '0')}')];
    final r = hangDanhMuc(nhieu, coNganSach: const {});
    expect(r.hang, hasLength(kToiDaDanhMuc));
    expect(r.json['Tổng số danh mục'], '25');
    expect(r.hang.first.ten, 'Muc 01');
  });

  group('qua các lớp chắn', () {
    final g = GoiSoTraCuu()..them('danh_sach_danh_muc', hangDanhMuc(ds, coNganSach: coNganSach));

    test('⭐ câu liệt kê tên (không số) qua kiemTen — tên hàng KHÔNG số liệu vẫn tới được bộ kiểm', () {
      const cau = 'Bạn có các danh mục Ăn uống, Di chuyển, Giải trí, test1, Lương và Cho vay.';
      expect(kiemTen(cau, [g]), isTrue);
      expect(kiemCauTraLoi(cau, [g]), isTrue);
    });

    test('tên bịa bị chặn: "danh mục Du lịch"', () {
      expect(kiemTen('Bạn có danh mục Du lịch và Ăn uống.', [g]), isFalse);
    });

    test('câu đếm qua: "Bạn có 6 danh mục, 4 danh mục chi"', () {
      expect(kiemCauTraLoi('Bạn có 6 danh mục, trong đó 4 danh mục chi.', [g]), isTrue);
    });

    test('⭐ mẫu câu của gói tự qua sáu lớp chắn; hàng không số liệu KHÔNG in dấu hai chấm trơ', () {
      final cau = g.mauCau().cau;
      expect(kiemCauTraLoi(cau, [g]), isTrue, reason: cau);
      expect(cau, startsWith('Ăn uống khoản chi · có ngân sách; Di chuyển'));
      expect(cau, isNot(contains(': ;')));
    });

    test('câu "1 danh mục vay nợ" của mô hình không bị coi là nêu danh mục TÊN "vay nợ"', () {
      expect(kiemCauTraLoi('Bạn có 1 danh mục vay nợ.', [g]), isTrue);
    });
  });
}
