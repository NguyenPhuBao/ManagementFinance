/// Gói số Phân tích: số từ `ThongKeKy` qua đúng các hàm trang đang dùng
/// (`phanTramSoVoi`, `thuNhapCua`, `tyLeTietKiem`). Kỳ vọng tính bằng chính
/// các hàm ấy chứ không ghi cứng.
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so_phan_tich.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_cau_tra_loi.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_nhan.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_so.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';
import 'package:flowmoney/features/analytics/data/analytics_repository.dart';
import 'package:flowmoney/features/analytics/domain/bao_cao_xuat.dart';
import 'package:flowmoney/features/analytics/domain/chi_bat_thuong.dart';
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
  List<DongDanhMuc> danhMuc = const [],
  List<DongChiBatThuong>? chiBatThuong,
}) {
  final ky = Ky.thang(2026, 9);
  final chuoi = chuoiTheoKy(const [], ky: ky);
  return ThongKeKy(
    ky: ky,
    tong: TongThuChi(thu: thu, chi: chi),
    tongTruoc: TongThuChi(thu: 0, chi: chiTruoc),
    tongNamTruoc: const TongThuChi(thu: 0, chi: 0),
    chiTheoDanhMuc: const [],
    danhMuc: danhMuc,
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
    taiSan:
        tongTaiSanCua(const [], const [], ky: ky, now: DateTime(2026, 9, 8)),
    giaoDichDauTien: null,
    chuoiVayNo: chuoiVayNo ?? [for (final d in chuoi) DiemVayNo(ky: d.ky)],
    chiBatThuong: chiBatThuong,
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
    expect(nx.cau,
        startsWith('Kỳ này chi 8.200.000 đ, tăng 12,5% so với kỳ trước'));
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

  test('chi vượt thu DƯỚI 2 lần → cảnh báo, "chi vượt thu nhập" phần trăm dương',
      () {
    final nx = GoiSoPhanTich.tu(_tk(thu: 10000000, chi: 13000000)).mauCau();
    expect(nx.muc, MucNhanXet.canhBao);
    expect(nx.cau, contains('chi vượt thu nhập 30,0%'));
    expect(nx.cau, isNot(contains('-30')));
  });

  test('⚠️ chi từ 2 lần thu nhập → "chi gấp N lần thu nhập", không in phần trăm (G56)',
      () {
    // Bản cũ in "chi vượt thu nhập 720,0%"; tuần thu nhập gần 0 trên Realme
    // ra "26360,0%" — đúng mà không đọc được. Người dùng chốt ngưỡng 2 lần.
    for (final (thu, chi, chuoi) in [
      (1000000.0, 8200000.0, 'chi gấp 8,2 lần thu nhập'),
      (20000.0, 5292000.0, 'chi gấp 265 lần thu nhập'),
    ]) {
      final g = GoiSoPhanTich.tu(_tk(thu: thu, chi: chi));
      final nx = g.mauCau();
      expect(nx.muc, MucNhanXet.canhBao);
      expect(nx.cau, contains(chuoi));
      expect(nx.cau, isNot(contains('vượt thu nhập')));
      expect(kiemCauTraLoi(nx.cau, [g]), isTrue,
          reason: 'mẫu câu của chính gói phải qua sáu lớp chắn: ${nx.cau}');
    }
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

  group('top danh mục có TÊN (chặng 4a)', () {
    DongDanhMuc dm(String ten, double soTien) => DongDanhMuc(
          categoryId: 'c-$ten',
          ten: ten,
          icon: null,
          mauHex: null,
          soTien: soTien,
          tiLeTongChi: 0,
        );

    test('mỗi danh mục chi góp một mục mang TÊN', () {
      final g = GoiSoPhanTich.tu(_tk(danhMuc: [
        dm('Ăn uống', 800000),
        dm('Di chuyển', 355000),
      ]));
      final ten = g.soLieu.where((s) => s.nhan == 'Chi').map((s) => s.ten);
      expect(ten, containsAll(<String>['Ăn uống', 'Di chuyển']),
          reason: 'Câu 8 của bảng đo — "chi nhiều nhất vào danh mục nào" — '
              'nhận về "Khoản lớn nhất là 800.000 đ": một con số của GIAO '
              'DỊCH, không phải tên danh mục.');
    });

    test('mục Chi theo danh mục khai xung đột "Thu" (bẫy 4.42) — cùng khuôn hàng tool tổng kết', () {
      final g = GoiSoPhanTich.tu(_tk(danhMuc: [dm('Ăn uống', 800000)]));
      final chi = g.soLieu.where((s) => s.nhan == 'Chi').toList();
      expect(chi, isNotEmpty);
      expect(chi.map((s) => s.nhanXungDot).toSet(), {
        ['Thu']
      });
      expect(g.soLieu.where((s) => s.ten == null).every((s) => s.nhanXungDot.isEmpty), isTrue);
    });

    test('danh mục chi nhiều nhất đứng đầu', () {
      final g = GoiSoPhanTich.tu(_tk(danhMuc: [
        dm('Ăn uống', 800000),
        dm('Di chuyển', 355000),
      ]));
      final chi = g.soLieu.where((s) => s.nhan == 'Chi').toList();
      expect(chi.first.ten, 'Ăn uống');
      expect(chi.first.soTho, 800000);
    });

    test('không vượt trần kToiDaMucMoiGoi danh mục', () {
      final g = GoiSoPhanTich.tu(_tk(danhMuc: [
        for (var i = 0; i < 6; i++) dm('DM $i', 100000 - i * 1000),
      ]));
      expect(g.soLieu.where((s) => s.nhan == 'Chi').length,
          lessThanOrEqualTo(kToiDaMucMoiGoi));
    });

    test('không có danh mục nào thì không mục Chi nào', () {
      final g = GoiSoPhanTich.tu(_tk());
      expect(g.soLieu.where((s) => s.nhan == 'Chi'), isEmpty,
          reason: 'Mục rỗng là ô trống đội lốt số liệu — cùng luật đã bỏ thẻ '
              '"Quá hạn: 0" ở gói hoá đơn.');
    });
  });

  test('G5 (b): kyCua — chuKy "tháng này" gắn cho số của kỳ; Cam kết không kỳ; không chuKy thì không xét', () {
    final g = GoiSoPhanTich.tu(_tk(), chuKy: 'tháng này');
    final tongChi = g.soLieu.firstWhere((s) => s.nhan == 'Tổng chi');
    expect(g.kyCua(tongChi), {'tháng này'});
    final soKyTruoc = g.soLieu.firstWhere((s) => s.nhan == 'So kỳ trước');
    expect(g.kyCua(soKyTruoc), {'tháng này', 'tháng trước'});
    final khong = GoiSoPhanTich.tu(_tk());
    expect(khong.kyCua(khong.soLieu.first), isNull);
  });
  // ── B3 — chi bất thường theo danh mục (2026-09-29) ─────────────────────────
  group('chi bất thường (B3)', () {
    DongChiBatThuong bt(String ten, double chi, double thuongLe) => (
          d: ChiBatThuong(
              categoryId: 'c-$ten', chi: chi, thuongLe: thuongLe, soThangMau: 6),
          ten: ten,
        );
    DongDanhMuc dmB3(String ten, double soTien) => DongDanhMuc(
          categoryId: 'c-$ten',
          ten: ten,
          icon: null,
          mauHex: null,
          soTien: soTien,
          tiLeTongChi: 0,
        );
    final motDong = [bt('Ăn uống', 2400000, 900000)];
    final danhMuc = [dmB3('Ăn uống', 2400000), dmB3('Di chuyển', 355000)];

    test('boChiBatThuong (không có quyền anomaly_spending_insights) → câu không nhắc danh mục bất thường', () {
      final n = GoiSoPhanTich.tu(_tk(chiBatThuong: motDong, danhMuc: danhMuc), boChiBatThuong: true)
          .mauCau();
      expect(n.cau, isNot(contains('thường lệ')),
          reason: 'spec phân quyền 2026-10-08: thay bằng dòng khoá ở trang, không lộ số trong câu');
      expect(n.cau, isNot(contains('2.400.000')));
    });

    test('một dòng → câu nêu tên + hai số, mức cảnh báo', () {
      final n = GoiSoPhanTich.tu(_tk(chiBatThuong: motDong, danhMuc: danhMuc)).mauCau();
      expect(
          n.cau,
          contains('Riêng Ăn uống kỳ này đã chi 2.400.000 đ, '
              'cao hơn hẳn mức thường lệ 900.000 đ.'));
      expect(n.muc, MucNhanXet.canhBao,
          reason: 'thu > chi nhưng có danh mục lạ — khối phải báo, không nói "bình thường"');
    });

    test('hai dòng → thêm câu "Thêm 1 danh mục khác cũng cao bất thường."', () {
      final n = GoiSoPhanTich.tu(_tk(
        chiBatThuong: [bt('Mua sắm', 4000000, 1000000), bt('Ăn uống', 2400000, 900000)],
        danhMuc: danhMuc,
      )).mauCau();
      expect(n.cau, contains('Riêng Mua sắm kỳ này đã chi 4.000.000 đ'),
          reason: 'dòng ĐẦU (phần vượt lớn nhất) là dòng được kể tên');
      expect(n.cau, contains('Thêm 1 danh mục khác cũng cao bất thường.'));
    });

    test('⭐ mẫu câu tự qua SÁU lớp chắn — có và không có chữ kỳ "tháng này"', () {
      for (final chuKy in [null, 'tháng này']) {
        for (final ds in [
          motDong,
          [bt('Mua sắm', 4000000, 1000000), bt('Ăn uống', 2400000, 900000)],
        ]) {
          final g = GoiSoPhanTich.tu(_tk(chiBatThuong: ds, danhMuc: danhMuc), chuKy: chuKy);
          final cau = g.mauCau().cau;
          expect(kiemCauTraLoi(cau, [g]), isTrue, reason: '$chuKy | $cau');
        }
      }
    });

    test('câu gán NGƯỢC số chi bất thường thành khoản "thu" bị kiemNhan chặn (bẫy 4.42)', () {
      // Y tế KHÔNG nằm trong top danh mục (tk.danhMuc) nên không mục nào khác
      // mang 700.000 để "cứu" câu — chỉ mục Chi bất thường quyết.
      final g = GoiSoPhanTich.tu(_tk(
        chiBatThuong: [bt('Y tế', 700000, 200000)],
        danhMuc: [for (var i = 0; i < 4; i++) dmB3('DM $i', 3000000.0 - i * 100000)],
      ));
      // Gán ngược = câu có từ khoá nhãn xung đột ("thu") mà KHÔNG đủ từ khoá của
      // chính nhãn ("chi bất thường") — xem `ganNhanNguoc`.
      expect(kiemNhan('Riêng Y tế kỳ này thu 700.000 đ.', [g]), isFalse,
          reason: 'thiếu xung đột "Thu" thì câu nói Y tế là khoản THU 700.000 đ vẫn lọt — '
              'số thật, tên thật, mệnh đề sai');
      expect(kiemNhan('Riêng Y tế kỳ này đã chi 700.000 đ, cao hơn hẳn mức thường lệ 200.000 đ.', [g]),
          isTrue);
    });

    test('null hoặc rỗng → câu và số liệu Y HỆT trước B3', () {
      final goc = GoiSoPhanTich.tu(_tk(danhMuc: danhMuc));
      for (final g in [
        GoiSoPhanTich.tu(_tk(danhMuc: danhMuc, chiBatThuong: const [])),
        GoiSoPhanTich.tu(_tk(danhMuc: danhMuc)),
      ]) {
        expect(g.mauCau().cau, goc.mauCau().cau);
        expect(g.mauCau().muc, goc.mauCau().muc);
        expect(g.soLieu.map((s) => s.nhan), goc.soLieu.map((s) => s.nhan));
      }
    });

    test('kyCua: Chi bất thường thuộc kỳ; Thường lệ và số danh mục khác không thuộc kỳ nào', () {
      final g = GoiSoPhanTich.tu(
          _tk(
            chiBatThuong: [bt('Mua sắm', 4000000, 1000000), bt('Ăn uống', 2400000, 900000)],
            danhMuc: danhMuc,
          ),
          chuKy: 'tháng này');
      SoLieu m(String nhan) => g.soLieu.firstWhere((s) => s.nhan == nhan);
      expect(g.kyCua(m('Chi bất thường')), {'tháng này'});
      expect(g.kyCua(m('Thường lệ')), isNull,
          reason: 'trung vị các tháng TRƯỚC — gán "tháng này" là kiemKy chặn câu đúng');
      expect(g.kyCua(m('Số danh mục khác bất thường')), isNull);
    });
  });
}
