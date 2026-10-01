/// Tool `tong_quan_tai_chinh` — phần CHÉP của ai_edge (spec mở rộng tool §4.2).
/// Ca ⭐ là E1 của cổng E: hỏi *thu nhập* mà nhận *tổng thu* — con số gồm cả
/// tiền thu nợ. Ở đây thu nhập phải là `thuNhapCua`, và tool KHÔNG mang `Tổng
/// thu` để hai con số không lẫn được.
library;

import 'package:flowmoney/core/category/category_classify.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so_tra_cuu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_so_lieu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_tong_quan.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_nhan.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_so.dart';
import 'package:flowmoney/features/analytics/data/analytics_repository.dart';
import 'package:flowmoney/features/analytics/domain/bao_cao_xuat.dart';
import 'package:flowmoney/features/analytics/domain/dong_tien_tu_do.dart';
import 'package:flowmoney/features/analytics/domain/pham_vi_ky.dart';
import 'package:flowmoney/features/analytics/domain/thong_ke_thang.dart';
import 'package:flowmoney/features/analytics/domain/vai_vay_no.dart';
import 'package:flutter_test/flutter_test.dart';

final _ky = Ky.thang(2026, 9);
final _kyTruoc = Ky.thang(2026, 8);

DongGiaoDich _khoan() => DongGiaoDich(
      id: 'g1',
      ngay: DateTime(2026, 9, 19),
      soTien: 800000,
      loai: kCategoryClassifies[0],
      categoryId: 'c-cv',
      tenDanhMuc: 'Cho vay',
      mauHex: null,
      icon: null,
      walletId: 'w1',
      tenVi: 'Tiền mặt',
      tieuDe: 'Cho vay',
      ghiChu: 'Cho vay',
    );

/// Chuỗi hai kỳ (tháng 8, tháng 9) cho thu/chi, vay/nợ và tài sản.
ThongKeKy _tk({
  TongThuChi tong = const TongThuChi(thu: 15135000, chi: 2141000),
  double thuNo = 500000,
  double traNo = 0,
  double taiSanTruoc = 10000000,
  double taiSanNay = 12904000,
  DateTime? giaoDichDauTien,
  bool coSoLieu = true,
}) =>
    ThongKeKy(
      ky: _ky,
      tong: tong,
      tongTruoc: const TongThuChi(thu: 0, chi: 0),
      chiTheoDanhMuc: const [],
      danhMuc: const [],
      chuoi: [
        DiemThoiGian(ky: _kyTruoc, tong: const TongThuChi(thu: 0, chi: 0)),
        DiemThoiGian(ky: _ky, tong: tong),
      ],
      chuoiVayNo: [
        DiemVayNo(ky: _kyTruoc),
        DiemVayNo(ky: _ky, choVay: 800000, thuNo: thuNo, traNo: traNo),
      ],
      soLieu: coSoLieu
          ? SoLieuNhanh(
              chiMoiNgay: 71367,
              ngayChiNhieuNhat: DateTime(2026, 9, 19),
              chiNgayNhieuNhat: 923000,
              khoanChiLonNhat: _khoan(),
            )
          : const SoLieuNhanh(
              chiMoiNgay: 0,
              ngayChiNhieuNhat: null,
              chiNgayNhieuNhat: 0,
              khoanChiLonNhat: null,
            ),
      taiSan: [
        (ky: _kyTruoc, moc: DateTime(2026, 9, 1), tong: taiSanTruoc),
        (ky: _ky, moc: DateTime(2026, 10, 1), tong: taiSanNay),
      ],
      giaoDichDauTien: giaoDichDauTien ?? DateTime(2026, 7, 1),
    );

const _vayNoMoiLuc = (choVay: 800000.0, thuNo: 500000.0, diVay: 2000000.0, traNo: 300000.0);

void main() {
  final now = DateTime(2026, 9, 23, 10);
  DiemVayNo moiLuc() => DiemVayNo(
        ky: Ky.tuyChon(from: DateTime(1970), to: DateTime(2026, 9, 24)),
        choVay: _vayNoMoiLuc.choVay,
        thuNo: _vayNoMoiLuc.thuNo,
        diVay: _vayNoMoiLuc.diVay,
        traNo: _vayNoMoiLuc.traNo,
      );

  test('⭐ E1: Thu nhập là thuNhapCua (14.635.000), KHÔNG phải tổng thu (15.135.000); không có nhãn Tổng thu', () {
    final tk = _tk();
    final r = hangTongQuan(tk, vayNoMoiLuc: moiLuc(), now: now, chuKy: 'tháng này');
    expect(r.json['Thu nhập'], '14.635.000 đ');
    expect(r.json.containsKey('Tổng thu'), isFalse,
        reason: 'đứng cạnh nhau thì câu "thu nhập 15.135.000 đ" lọt kiemNhan nhờ chữ "thu"');
    expect(r.json.values, isNot(contains('15.135.000 đ')));
    expect(r.json['Tổng chi'], '2.141.000 đ');
    // Cùng MỘT định nghĩa với trang Phân tích.
    expect(14635000, thuNhapCua(tong: tk.tong, vayNo: tk.chuoiVayNo.last));
  });

  test('tỉ lệ tiết kiệm, dòng tiền tự do, thống kê nhanh', () {
    final r = hangTongQuan(_tk(traNo: 135000), vayNoMoiLuc: null, now: now, chuKy: 'tháng này');
    expect(r.json['Tỉ lệ tiết kiệm'], '85,4%');
    expect(r.json['Dòng tiền tự do'], '14.500.000 đ');
    expect(r.json['Chi trung bình mỗi ngày'], '71.367 đ');
    expect(r.json['Ngày chi nhiều nhất'], '19/09');
    expect(r.json['Chi ngày nhiều nhất'], '923.000 đ');
  });

  test('khoản chi lớn nhất là một HÀNG mang tên — không phải mục tổng hợp', () {
    final r = hangTongQuan(_tk(), vayNoMoiLuc: null, now: now, chuKy: 'tháng này');
    expect(r.hang.single.ten, 'Cho vay');
    expect(r.hang.single.trangThai, 'khoản chi lớn nhất · Cho vay · Tiền mặt');
    expect({for (final s in r.hang.single.soLieu) s.nhan: s.chuoi},
        {'Số tiền': '800.000 đ', 'Ngày': '19/09'});
    expect(r.tongHop.every((s) => s.ten == null), isTrue);
  });

  test('tài sản: tổng hiện tại và thay đổi TRONG KỲ (điểm cuối so điểm liền trước)', () {
    final r = hangTongQuan(_tk(), vayNoMoiLuc: null, now: now, chuKy: 'tháng này');
    expect(r.json['Tổng tài sản'], '12.904.000 đ');
    expect(r.json['Tài sản tăng'], '2.904.000 đ');
    expect(r.chuThem['ket_qua'], 'tài sản tăng');
  });

  test('tài sản GIẢM: số dương dưới nhãn "Tài sản giảm"', () {
    final r = hangTongQuan(_tk(taiSanTruoc: 13000000), vayNoMoiLuc: null, now: now, chuKy: 'tháng này');
    expect(r.json['Tài sản giảm'], '96.000 đ');
    expect(r.json.containsKey('Tài sản tăng'), isFalse);
    expect(r.chuThem['ket_qua'], 'tài sản giảm');
  });

  test('⚠️ điểm trước rơi vào quãng CHƯA BIẾT (trước giao dịch đầu tiên) → không in thay đổi tài sản', () {
    final r = hangTongQuan(_tk(giaoDichDauTien: DateTime(2026, 9, 2)),
        vayNoMoiLuc: null, now: now, chuKy: 'tháng này');
    expect(r.json['Tổng tài sản'], '12.904.000 đ');
    expect(r.json.keys.where((k) => k.startsWith('Tài sản ')), isEmpty,
        reason: 'số 0 "chưa biết" của tháng 8 sẽ in ra nguyên cả tài sản như một khoản tăng');
    expect(r.chuThem.containsKey('ket_qua'), isFalse);
  });

  test('dư nợ vay/nợ tính MỌI THỜI GIAN, chữ kèm nói rõ', () {
    final r = hangTongQuan(_tk(), vayNoMoiLuc: moiLuc(), now: now, chuKy: 'tháng này');
    expect(r.json['Đang cho vay chưa thu về'], '300.000 đ');
    expect(r.json['Đang nợ'], '1.700.000 đ');
    expect(r.chuThem['vay_no'], 'vay nợ tính mọi thời gian');
  });

  test('không có điểm vay/nợ mọi thời gian → bỏ hai con số dư nợ và chữ kèm', () {
    final r = hangTongQuan(_tk(), vayNoMoiLuc: null, now: now, chuKy: 'tháng này');
    expect(r.json.containsKey('Đang nợ'), isFalse);
    expect(r.chuThem.containsKey('vay_no'), isFalse);
  });

  test('⚠️ thu nhập không dương → KHÔNG in tỉ lệ (chia cho mẫu số âm là tỉ lệ đảo dấu)', () {
    final r = hangTongQuan(
      _tk(tong: const TongThuChi(thu: 400000, chi: 100000), thuNo: 500000),
      vayNoMoiLuc: null, now: now, chuKy: 'tháng này',
    );
    expect(r.json.keys.any((k) => k.contains('Tỉ lệ') || k.contains('vượt')), isFalse);
  });

  test('chi vượt thu nhập → số dương dưới nhãn "Chi vượt thu nhập", chữ kết luận', () {
    final r = hangTongQuan(
      _tk(tong: const TongThuChi(thu: 1500000, chi: 1500000), thuNo: 500000),
      vayNoMoiLuc: null, now: now, chuKy: 'tháng này',
    );
    expect(r.json['Chi vượt thu nhập'], '50,0%');
    expect(r.json.containsKey('Tỉ lệ tiết kiệm'), isFalse);
    expect(r.chuThem['ket_qua'], contains('chi vượt thu nhập'));
  });

  test('⚠️ chi từ 2 lần thu nhập → "Gấp thu nhập" số lần, không phần trăm vượt (G56)', () {
    // Thu nhập 1.000.000 − 500.000 thu nợ = 500.000; chi 4.100.000 → gấp 8,2 lần.
    final r = hangTongQuan(
      _tk(tong: const TongThuChi(thu: 1000000, chi: 4100000), thuNo: 500000),
      vayNoMoiLuc: null, now: now, chuKy: 'tháng này',
    );
    expect(r.json['Gấp thu nhập'], '8,2');
    expect(r.json.containsKey('Chi vượt thu nhập'), isFalse,
        reason: 'cùng một đại lượng không được mang hai nhãn — "720,0%" chính '
            'là thứ G56 bỏ đi');
    expect(r.chuThem['ket_qua'], contains('chi vượt thu nhập'),
        reason: 'chữ kết luận vẫn nói chiều; chỉ con số đổi đơn vị');
  });

  test('kỳ không có khoản chi nào → không hàng, không ngày chi nhiều nhất', () {
    final r = hangTongQuan(_tk(coSoLieu: false), vayNoMoiLuc: null, now: now, chuKy: 'tháng này');
    expect(r.hang, isEmpty);
    expect(r.json.containsKey('Ngày chi nhiều nhất'), isFalse);
  });

  test('chuThem KHÔNG chứa chữ số', () {
    final r = hangTongQuan(_tk(), vayNoMoiLuc: moiLuc(), now: now, chuKy: 'tháng này');
    expect(RegExp(r'\d').hasMatch(r.chuThem.values.join()), isFalse);
  });

  group('qua các lớp chắn', () {
    final g = GoiSoTraCuu()
      ..them('tong_quan_tai_chinh',
          hangTongQuan(_tk(), vayNoMoiLuc: moiLuc(), now: now, chuKy: 'tháng này'));

    test('⭐ mẫu câu của gói tự qua kiemSo + kiemNhan', () {
      final cau = g.mauCau().cau;
      expect(kiemSo(cau, g), isTrue, reason: cau);
      expect(kiemNhan(cau, [g]), isTrue, reason: cau);
    });

    test('câu tự nhiên: thu nhập + để dành; ngày chi nhiều nhất; đang nợ', () {
      for (final cau in [
        'Thu nhập tháng này của bạn là 14.635.000 đ, để dành được 85,4%.',
        'Ngày chi nhiều nhất là 19/09 với 923.000 đ.',
        'Bạn đang cho vay 300.000 đ chưa thu về và đang nợ 1.700.000 đ.',
        'Tổng tài sản hiện là 12.904.000 đ, tăng 2.904.000 đ.',
      ]) {
        expect(kiemSo(cau, g), isTrue, reason: cau);
        expect(kiemNhan(cau, [g]), isTrue, reason: cau);
      }
    });

    test('⚠️ tổng thu đội lốt thu nhập bị chặn: 15.135.000 không có trong gói', () {
      expect(kiemSo('Thu nhập tháng này là 15.135.000 đ.', g), isFalse);
    });
  });

  group('rút theo CÂU HỎI — nhom (mục 9.34: mẫu câu từng liệt kê cả 11 số)', () {
    KetQuaCongCu theo(Set<NhomTongQuan> nhom, {DateTime? dauTien}) => hangTongQuan(
          _tk(giaoDichDauTien: dauTien),
          vayNoMoiLuc: moiLuc(), now: now, chuKy: 'tháng này', nhom: nhom,
        );

    test('⭐ thu nhập: Thu nhập, Tổng chi, Tỉ lệ, Dòng tiền tự do — không tài sản, không dư nợ, không hàng', () {
      final r = theo({NhomTongQuan.thuNhap});
      expect(r.tongHop.map((s) => s.nhan).toList(),
          ['Thu nhập', 'Tổng chi', 'Tỉ lệ tiết kiệm', 'Dòng tiền tự do']);
      expect(r.hang, isEmpty);
      expect(r.chuThem.containsKey('vay_no'), isFalse);
    });

    test('chi tiêu: Tổng chi, trung bình ngày, ngày chi nhiều nhất + hàng khoản lớn nhất', () {
      final r = theo({NhomTongQuan.chiTieu});
      expect(r.tongHop.map((s) => s.nhan).toList(),
          ['Tổng chi', 'Chi trung bình mỗi ngày', 'Ngày chi nhiều nhất', 'Chi ngày nhiều nhất']);
      expect(r.hang.single.ten, 'Cho vay');
    });

    test('vay nợ: chỉ hai con số dư nợ', () {
      final r = theo({NhomTongQuan.vayNo});
      expect(r.tongHop.map((s) => s.nhan).toList(), ['Đang cho vay chưa thu về', 'Đang nợ']);
    });

    test('⭐ N5: hỏi đích danh tài sản mà thay đổi CHƯA BIẾT → chữ kết luận nói ra', () {
      final r = theo({NhomTongQuan.taiSan}, dauTien: DateTime(2026, 9, 2));
      expect(r.tongHop.map((s) => s.nhan).toList(), ['Tổng tài sản']);
      expect(r.chuThem['ket_qua'], 'chưa đủ dữ liệu để biết tài sản tăng hay giảm');
      expect(r.chiMauCau, isTrue,
          reason: 'OnePlus 2026-09-28 P5: mô hình nêu tổng tài sản, bỏ qua chữ "chưa đủ dữ liệu"');
      final g = GoiSoTraCuu()..them('tong_quan_tai_chinh', r);
      expect(g.choHienChuMoHinh, isFalse);
      expect(g.mauCau().cau,
          'Tháng này — Tổng tài sản: 12.904.000 đ — chưa đủ dữ liệu để biết tài sản tăng hay giảm.');
    });

    test('câu hỏi chung chung (tập rỗng) KHÔNG in câu "chưa đủ dữ liệu" — không ai hỏi', () {
      final r = theo(const {}, dauTien: DateTime(2026, 9, 2));
      expect(r.chuThem.containsKey('ket_qua'), isFalse);
      expect(r.tongHop.length, greaterThan(8));
    });

    test('tài sản BIẾT thay đổi → không đòi mẫu câu', () {
      final r = theo({NhomTongQuan.taiSan});
      expect(r.chiMauCau, isFalse);
      expect(r.chuThem['ket_qua'], 'tài sản tăng');
    });

    test('hai nhóm cùng lúc', () {
      final r = theo({NhomTongQuan.thuNhap, NhomTongQuan.taiSan});
      expect(r.tongHop.map((s) => s.nhan), containsAll(<String>['Thu nhập', 'Tổng tài sản', 'Tài sản tăng']));
      expect(r.tongHop.map((s) => s.nhan), isNot(contains('Đang nợ')));
    });
  });
}
