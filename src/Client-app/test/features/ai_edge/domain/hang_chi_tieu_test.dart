/// Tool `chi_tieu_theo_ky`: tham số là MÃ KỲ chữ (E2B sinh ngày ISO là rủi ro),
/// hàng theo TÊN danh mục từ `ThongKeKy.danhMuc`, kỳ ghi bằng chữ không số.
library;

import 'package:flowmoney/features/ai_edge/domain/hang_chi_tieu.dart';
import 'package:flowmoney/features/analytics/data/analytics_repository.dart';
import 'package:flowmoney/features/analytics/domain/bao_cao_xuat.dart';
import 'package:flowmoney/features/analytics/domain/pham_vi_ky.dart';
import 'package:flowmoney/features/analytics/domain/thong_ke_thang.dart';
import 'package:flowmoney/features/analytics/domain/tong_tai_san.dart';
import 'package:flowmoney/features/analytics/domain/vai_vay_no.dart';
import 'package:flutter_test/flutter_test.dart';

DongDanhMuc _dm(String ten, double soTien) => DongDanhMuc(
      categoryId: 'c-$ten',
      ten: ten,
      icon: null,
      mauHex: null,
      soTien: soTien,
      tiLeTongChi: 0,
    );

/// Rút gọn của `_tk` ở `goi_so_phan_tich_test.dart` — chỉ các trường tool đọc.
ThongKeKy _tk({double thu = 15135000, double chi = 2141000, List<DongDanhMuc> danhMuc = const []}) {
  final ky = Ky.thang(2026, 9);
  final chuoi = chuoiTheoKy(const [], ky: ky);
  return ThongKeKy(
    ky: ky,
    tong: TongThuChi(thu: thu, chi: chi),
    tongTruoc: const TongThuChi(thu: 0, chi: 0),
    tongNamTruoc: const TongThuChi(thu: 0, chi: 0),
    chiTheoDanhMuc: const [],
    danhMuc: danhMuc,
    chuoi: chuoi,
    latPhanLoai: const [],
    danhMucTheoLat: const {},
    chuoiDanhMuc: const {},
    soLieu: const SoLieuNhanh(chiMoiNgay: 0, ngayChiNhieuNhat: null, chiNgayNhieuNhat: 0, khoanChiLonNhat: null),
    theoVi: const [],
    topChi: const [],
    lichChiTieu: const {},
    dongTien: null,
    duBao: null,
    taiSan: tongTaiSanCua(const [], const [], ky: ky, now: DateTime(2026, 9, 8)),
    giaoDichDauTien: null,
    chuoiVayNo: [for (final d in chuoi) DiemVayNo(ky: d.ky)],
  );
}

void main() {
  final now = DateTime(2026, 9, 23, 10);

  group('kyTuMa — năm mã, cùng phép dựng với bộ chọn kỳ trang Phân tích', () {
    test('thang_nay / thang_truoc / nam_nay', () {
      expect(kyTuMa('thang_nay', now)!.from, DateTime(2026, 9, 1));
      expect(kyTuMa('thang_truoc', now)!.from, DateTime(2026, 8, 1));
      expect(kyTuMa('thang_truoc', now)!.to, DateTime(2026, 9, 1));
      expect(kyTuMa('nam_nay', now)!.from, DateTime(2026, 1, 1));
    });
    test('tuan_nay chứa hôm nay; quy_nay là quý 3', () {
      expect(kyTuMa('tuan_nay', now)!.chua(now), isTrue);
      expect(kyTuMa('quy_nay', now)!.from, DateTime(2026, 7, 1));
    });
    test('mã lạ → null', () {
      expect(kyTuMa('hom_qua', now), isNull);
      expect(kyTuMa('', now), isNull);
    });
  });

  test('⭐ hàng theo danh mục có TÊN, thứ tự như tk.danhMuc, trần kToiDaMucMoiGoi', () {
    final kq = hangChiTieu(
      _tk(danhMuc: [_dm('Cho vay', 800000), _dm('Ăn uống', 600000), _dm('Di chuyển', 355000), _dm('Mua sắm', 60000), _dm('Giáo dục', 45000)]),
      ma: 'thang_nay',
    );
    expect(kq.hang.map((h) => h.ten).toList(), ['Cho vay', 'Ăn uống', 'Di chuyển', 'Mua sắm']);
    expect(kq.hang.first.json, {'ten': 'Cho vay', 'Chi': '800.000 đ'});
    expect(kq.hang.first.trangThai, isNull);
    expect(kq.hang.first.canhBao, isFalse);
  });

  test('tổng hợp Tổng chi / Tổng thu + kỳ bằng CHỮ, không số', () {
    final kq = hangChiTieu(_tk(), ma: 'thang_truoc');
    expect(kq.tongHop.map((s) => '${s.nhan}=${s.chuoi}').toList(),
        ['Tổng chi=2.141.000 đ', 'Tổng thu=15.135.000 đ']);
    expect(kq.chuThem, {'ky': 'tháng trước'});
    expect(RegExp(r'\d').hasMatch(kq.json['ky'] as String), isFalse,
        reason: 'số trong chữ kèm không có trong gói → câu chép nó bị chặn');
  });

  test('mã lạ → từ chối, không đoán kỳ', () {
    final kq = hangChiTieu(_tk(), ma: 'hom_qua');
    expect(kq.hang, isEmpty);
    expect(kq.loi, loiMaKy('hom_qua'));
    expect(kq.loi, contains('thang_truoc'));
  });
}
