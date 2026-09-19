/// Gói số Phân tích: số từ `ThongKeKy` qua đúng các hàm trang đang dùng
/// (`phanTramSoVoi`, `thuNhapCua`, `tyLeTietKiem`). Kỳ vọng tính bằng chính
/// các hàm ấy chứ không ghi cứng.
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so_phan_tich.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_so.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';
import 'package:flowmoney/features/analytics/data/analytics_repository.dart';
import 'package:flowmoney/features/analytics/domain/bao_cao_xuat.dart';
import 'package:flowmoney/features/analytics/domain/du_bao_dong_tien.dart';
import 'package:flowmoney/features/analytics/domain/pham_vi_ky.dart';
import 'package:flowmoney/features/analytics/domain/thong_ke_thang.dart';
import 'package:flowmoney/features/analytics/domain/tong_tai_san.dart';
import 'package:flowmoney/features/analytics/domain/vai_vay_no.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rút gọn của helper `_tk` ở `analytics_page_test.dart` — chỉ các trường gói
/// số đọc; phần còn lại là cấu trúc rỗng hợp lệ.
ThongKeKy _tk({
  double thu = 12615385,
  double chi = 8200000,
  double chiTruoc = 7288889,
  List<DiemVayNo>? chuoiVayNo,
  List<DongGiaoDich> topChi = const [],
  DuBaoDongTien? duBao,
}) {
  final ky = Ky.thang(2026, 9);
  final chuoi = chuoiTheoKy(const [], ky: ky);
  return ThongKeKy(
    ky: ky,
    tong: TongThuChi(thu: thu, chi: chi),
    tongTruoc: TongThuChi(thu: 0, chi: chiTruoc),
    tongNamTruoc: const TongThuChi(thu: 0, chi: 0),
    chiTheoDanhMuc: const [],
    danhMuc: const [],
    chuoi: chuoi,
    latPhanLoai: const [],
    danhMucTheoLat: const {},
    chuoiDanhMuc: const {},
    soLieu: const SoLieuNhanh(
      chiMoiNgay: 0,
      ngayChiNhieuNhat: null,
      chiNgayNhieuNhat: 0,
      khoanChiLonNhat: null,
    ),
    theoVi: const [],
    topChi: topChi,
    lichChiTieu: const {},
    dongTien: null,
    duBao: duBao,
    taiSan: tongTaiSanCua(const [], const [], ky: ky, now: DateTime(2026, 9, 8)),
    giaoDichDauTien: null,
    chuoiVayNo: chuoiVayNo ?? [for (final d in chuoi) DiemVayNo(ky: d.ky)],
  );
}

DongGiaoDich _gd(double soTien) => DongGiaoDich(
      id: 'x',
      ngay: DateTime(2026, 9, 3),
      soTien: soTien,
      loai: 'chi',
      categoryId: 'c',
      tenDanhMuc: 'Ăn uống',
      mauHex: null,
      icon: null,
      walletId: 'w',
      tenVi: 'Tiền mặt',
      tieuDe: 'Bữa trưa 12/09',
    );

void main() {
  test('kỳ rỗng → thiếu dữ liệu', () {
    final nx = GoiSoPhanTich.tu(_tk(thu: 0, chi: 0, chiTruoc: 0)).mauCau();
    expect(nx.muc, MucNhanXet.thieuDuLieu);
    expect(nx.cau, 'Kỳ này chưa có giao dịch để nhận xét.');
    expect(nx.theSoLieu, isEmpty);
  });

  test('có kỳ trước: câu nêu chi, tăng/giảm % so kỳ trước, để dành % thu nhập',
      () {
    final tk = _tk();
    final g = GoiSoPhanTich.tu(tk);
    final pt = phanTramSoVoi(tk.tong.chi, tk.tongTruoc.chi)!;
    final nx = g.mauCau();
    expect(nx.muc, MucNhanXet.binhThuong);
    expect(nx.cau, startsWith('Kỳ này chi 8.200.000 đ, tăng 12,5% so với kỳ trước'));
    expect(pt, closeTo(12.5, 0.01));
    expect(nx.cau, contains('để dành 35,0% thu nhập'));
    expect(g.man, 'phan_tich');
  });

  test('kỳ trước bằng 0 → KHÔNG in phần trăm so sánh (nền bằng 0)', () {
    final nx = GoiSoPhanTich.tu(_tk(chiTruoc: 0)).mauCau();
    expect(nx.cau, isNot(contains('so với kỳ trước')));
    expect(nx.theSoLieu.map((s) => s.nhan), isNot(contains('So kỳ trước')));
  });

  test('chuỗi vay/nợ rỗng → không có vế để dành', () {
    final nx = GoiSoPhanTich.tu(_tk(chuoiVayNo: const [])).mauCau();
    expect(nx.cau, isNot(contains('để dành')));
  });

  test('thu nhập không dương → không có vế để dành (tyLeTietKiem null)', () {
    final nx = GoiSoPhanTich.tu(_tk(thu: 0, chi: 500000)).mauCau();
    expect(nx.cau, isNot(contains('để dành')));
  });

  test('chi vượt thu → mức cảnh báo, vế "chi vượt thu nhập" với trị tuyệt đối',
      () {
    final nx = GoiSoPhanTich.tu(_tk(thu: 1000000, chi: 8200000)).mauCau();
    expect(nx.muc, MucNhanXet.canhBao);
    expect(nx.cau, contains('chi vượt thu nhập 720,0%'));
    expect(nx.cau, isNot(contains('-720')));
  });

  test('giảm so kỳ trước → chữ "giảm" và phần trăm dương', () {
    final nx = GoiSoPhanTich.tu(_tk(chi: 6000000, chiTruoc: 8000000)).mauCau();
    expect(nx.cau, contains('giảm 25,0% so với kỳ trước'));
  });

  test('có dự báo với cam kết → thêm vế cam kết; không cam kết → không', () {
    final duBao = DuBaoDongTien(
      tu: DateTime(2026, 9, 22),
      soDuHienTai: 13054000,
      camKet: [
        CamKet(
          ngay: DateTime(2026, 9, 28),
          ten: 'Netflix',
          loai: LoaiCamKet.hoaDon,
          walletId: 'w',
          tenVi: 'Tiền mặt',
          soTien: 100000,
          categoryId: 'c',
          quaHan: false,
          laKyChieu: false,
          tacDongTong: -100000,
        ),
      ],
      tongCamKet: 100000,
      nganSachConLai: 0,
      viThieu: const [],
      chuoi: const [],
    );
    final co = GoiSoPhanTich.tu(_tk(duBao: duBao)).mauCau();
    expect(co.cau, contains('1 cam kết phải trả, tổng 100.000 đ'));
    final khong = GoiSoPhanTich.tu(_tk()).mauCau();
    expect(khong.cau, isNot(contains('cam kết')));
  });

  test('có top chi → vế khoản chi lớn nhất, KHÔNG in tiêu đề (có thể chứa số)',
      () {
    final nx = GoiSoPhanTich.tu(_tk(topChi: [_gd(2500000)])).mauCau();
    expect(nx.cau, contains('Khoản chi lớn nhất 2.500.000 đ'));
    expect(nx.cau, isNot(contains('12/09')));
  });

  test('mẫu câu tự qua bộ kiểm số ở mọi nhánh', () {
    for (final tk in [
      _tk(),
      _tk(chiTruoc: 0),
      _tk(chuoiVayNo: const []),
      _tk(thu: 1000000, chi: 8200000),
      _tk(topChi: [_gd(2500000)]),
      _tk(thu: 0, chi: 0, chiTruoc: 0),
    ]) {
      final g = GoiSoPhanTich.tu(tk);
      expect(kiemSo(g.mauCau().cau, g), isTrue, reason: g.mauCau().cau);
    }
  });
}
