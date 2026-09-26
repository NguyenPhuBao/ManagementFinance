/// Phép kiểm MỘT CÂU trả lời của màn Trợ lý AI có một định nghĩa duy nhất:
/// số (`kiemSoNhieuGoi`) **và** nhãn (`kiemNhan`) **và** giọng (`kiemGiong`
/// theo mức tổng hợp của mọi gói). Trước 2026-09-22 đường hỏi đáp chỉ gọi
/// `kiemSoNhieuGoi` — điểm 5 cổng A ghi "chưa đo" nhưng thật ra là **chưa
/// nối**.
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_cau_tra_loi.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gia extends GoiSo {
  @override
  final String man;
  @override
  final List<SoLieu> soLieu;
  final MucNhanXet muc;
  _Gia(this.man, this.soLieu, this.muc);
  @override
  bool get thieuDuLieu => muc == MucNhanXet.thieuDuLieu;
  @override
  NhanXet mauCau() => NhanXet(cau: '', theSoLieu: soLieu, muc: muc);
}

void main() {
  final nganSachCang = _Gia(
    'ngan_sach',
    [soTien('Đã chi', 450000), soTien('Hạn mức', 500000)],
    MucNhanXet.canhBao,
  );
  final phanTichOn = _Gia(
    'phan_tich',
    [soTien('Tổng chi', 2141000)],
    MucNhanXet.binhThuong,
  );
  final mucTieuRong = _Gia('muc_tieu', const [], MucNhanXet.thieuDuLieu);

  group('mucTongHop', () {
    test('một gói cảnh báo là cả câu trả lời ở mức cảnh báo', () {
      expect(mucTongHop([phanTichOn, nganSachCang]), MucNhanXet.canhBao);
    });
    test('không gói nào cảnh báo thì bình thường; gói thiếu dữ liệu không đổi',
        () {
      expect(mucTongHop([phanTichOn, mucTieuRong]), MucNhanXet.binhThuong);
    });
    test('mọi gói thiếu dữ liệu thì thiếu dữ liệu', () {
      expect(mucTongHop([mucTieuRong]), MucNhanXet.thieuDuLieu);
    });
  });

  group('kiemCauTraLoi', () {
    test('câu đúng số, đúng nhãn, đúng giọng thì qua', () {
      expect(
        kiemCauTraLoi(
          'Ngân sách đã chi 450.000 đ trên hạn mức 500.000 đ, sắp hết.',
          [phanTichOn, nganSachCang],
        ),
        isTrue,
      );
    });

    test('số bịa bị chặn', () {
      expect(
        kiemCauTraLoi('Đã chi 460.000 đ.', [phanTichOn, nganSachCang]),
        isFalse,
      );
    });

    test('số thật gán sai nhãn bị chặn', () {
      expect(
        kiemCauTraLoi('Hạn mức là 450.000 đ.', [phanTichOn, nganSachCang]),
        isFalse,
        reason: '450.000 là "Đã chi", câu gọi nó là hạn mức',
      );
    });

    test('⭐ trấn an khi có gói cảnh báo bị chặn — điểm 5 cổng A', () {
      expect(
        kiemCauTraLoi(
          'Bạn đang kiểm soát tốt, đã chi 450.000 đ.',
          [phanTichOn, nganSachCang],
        ),
        isFalse,
      );
    });

    test('báo động khi mọi gói bình thường bị chặn', () {
      expect(
        kiemCauTraLoi('Tổng chi 2.141.000 đ, nguy hiểm!', [phanTichOn]),
        isFalse,
      );
    });

    test('⭐ lớp thứ tư kiemTen đã NỐI: câu không số nêu tên bịa bị chặn (bẫy 4.48, B1 lần 10)', () {
      final mucTieu = _Gia('tra_cuu', [
        soTien('Còn thiếu', 899000, ten: 'MuaXe'),
        soTien('Còn thiếu', 4000000, ten: 'MuaDT'),
      ], MucNhanXet.binhThuong);
      expect(
        kiemCauTraLoi('Bạn có thể đặt mục tiêu mua xe hoặc mua nhà.', [mucTieu]),
        isFalse,
        reason: 'Ba lớp cũ cho qua (không số, không nhãn, giọng thường) — chỉ kiemTen bắt',
      );
      expect(
        kiemCauTraLoi('Bạn có hai mục tiêu "MuaXe" và "MuaDT".', [mucTieu]),
        isTrue,
      );
    });

    test('phủ định trong ba từ đảo nghĩa cụm — luật của kiemGiong giữ nguyên',
        () {
      expect(
        kiemCauTraLoi(
          'Đã chi 450.000 đ, chưa kiểm soát tốt.',
          [nganSachCang],
        ),
        isTrue,
      );
    });
  });
}
