/// Tool `tong_ket_thu_chi_ky`: tham số là MÃ KỲ chữ (E2B sinh ngày ISO là rủi ro),
/// hàng theo TÊN danh mục từ `ThongKeKy.danhMuc`, kỳ ghi bằng chữ không số.
library;

import 'package:flowmoney/features/ai_edge/domain/hang_chi_tieu.dart';
import 'package:flowmoney/features/ai_edge/domain/loi_tham_so.dart';
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
  test('⭐ hàng theo danh mục có TÊN: top (trần − 1) + danh mục ÍT NHẤT, kèm trạng thái '
      'nhiều nhất / ít nhất và Số danh mục (lần đo 15 câu E3: trần 4 hàng cắt mất '
      'danh mục nhỏ nên "ít tiêu nhất" không trả lời được)', () {
    final kq = hangChiTieu(
      _tk(danhMuc: [_dm('Cho vay', 800000), _dm('Ăn uống', 600000), _dm('Di chuyển', 355000), _dm('Mua sắm', 60000), _dm('Giáo dục', 45000)]),
      ma: 'thang_nay',
    );
    expect(kq.hang.map((h) => h.ten).toList(), ['Cho vay', 'Ăn uống', 'Di chuyển', 'Giáo dục'],
        reason: 'vẫn đúng trần 4 hàng, nhưng hàng cuối là danh mục nhỏ nhất chứ không '
            'phải hàng thứ tư theo thứ tự giảm dần');
    expect(kq.hang.first.json, {'ten': 'Cho vay', 'trang_thai': 'chi nhiều nhất', 'Chi': '800.000 đ'});
    expect(kq.hang.last.json, {'ten': 'Giáo dục', 'trang_thai': 'chi ít nhất', 'Chi': '45.000 đ'});
    expect(kq.hang[1].trangThai, isNull);
    expect(kq.hang.first.canhBao, isFalse);
    expect(kq.tongHop.map((s) => '${s.nhan}=${s.chuoi}'), contains('Số danh mục=5'),
        reason: 'mô hình phải biết còn danh mục không hiện trong bốn hàng');
  });

  test('≤ trần danh mục: đủ hàng theo thứ tự giảm dần; hai đầu mang trạng thái, một '
      'danh mục thì không so sánh gì', () {
    final hai = hangChiTieu(_tk(danhMuc: [_dm('Ăn uống', 600000), _dm('Giáo dục', 45000)]), ma: 'thang_nay');
    expect(hai.hang.map((h) => h.ten).toList(), ['Ăn uống', 'Giáo dục']);
    expect(hai.hang.map((h) => h.trangThai).toList(), ['chi nhiều nhất', 'chi ít nhất']);
    expect(hai.tongHop.map((s) => '${s.nhan}=${s.chuoi}'), contains('Số danh mục=2'));

    final mot = hangChiTieu(_tk(danhMuc: [_dm('Ăn uống', 600000)]), ma: 'thang_nay');
    expect(mot.hang.single.trangThai, isNull);

    final khong = hangChiTieu(_tk(), ma: 'thang_nay');
    expect(khong.hang, isEmpty);
    expect(khong.tongHop.map((s) => '${s.nhan}=${s.chuoi}'), contains('Số danh mục=0'));
  });

  test('⭐ hàng danh mục nhãn "Chi" khai xung đột "Thu" — câu C10 gán chi thành thu bị chặn (bẫy 4.42)', () {
    final kq = hangChiTieu(_tk(danhMuc: [_dm('Cho vay', 800000)]), ma: 'thang_nay');
    for (final h in kq.hang) {
      for (final s in h.soLieu) {
        expect(s.nhanXungDot, ['Thu'], reason: '${h.ten} · ${s.nhan}');
      }
    }
    for (final s in kq.tongHop) {
      expect(s.nhanXungDot, isEmpty, reason: 'mục không tên vốn đã bị đòi nhãn');
    }
  });

  test('tổng hợp Tổng chi / Tổng thu + kỳ bằng CHỮ, không số', () {
    final kq = hangChiTieu(_tk(), ma: 'thang_truoc');
    expect(kq.tongHop.map((s) => '${s.nhan}=${s.chuoi}').toList(),
        ['Tổng chi=2.141.000 đ', 'Tổng thu=15.135.000 đ', 'Số danh mục=0']);
    expect(kq.chuThem, {'ky': 'tháng trước'});
    expect(RegExp(r'\d').hasMatch(kq.json['ky'] as String), isFalse,
        reason: 'số trong chữ kèm không có trong gói → câu chép nó bị chặn');
  });

  test('mã lạ → từ chối, không đoán kỳ', () {
    final kq = hangChiTieu(_tk(), ma: 'hom_kia');
    expect(kq.hang, isEmpty);
    expect(kq.loi, loiGiaTri('ky', 'hom_kia', kMaKy.keys));
    expect(kq.loi, contains('thang_truoc'));
    expect(kq.choNguoiDung, 'chưa hiểu khoảng thời gian trong câu hỏi');
    expect(kq.thamSoGo, ['ky']);
  });
}
