/// Hàng NHÓM của `truy_van_giao_dich` (spec mục 2.3): tên nhóm là `ten`, hai đầu
/// mang trạng thái, trần 4 với hàng cuối là nhóm ÍT NHẤT, `chon` một hàng, tổng
/// hợp đếm trên trọn tập. Không tính gì ngoài `gopGiaoDich`.
library;

import 'package:flowmoney/features/ai_edge/domain/hang_nhom_giao_dich.dart';
import 'package:flowmoney/features/transaction/domain/gop_giao_dich.dart';
import 'package:flowmoney/features/transaction/domain/tim_giao_dich.dart';
import 'package:flutter_test/flutter_test.dart';

DongTimThay _d(String? dm, double tien, ChieuTim chieu) => DongTimThay(
      tieuDe: '${dm ?? 'x'} $tien',
      tenDanhMuc: dm,
      tenVi: 'Tiền mặt',
      tenViDich: null,
      soTien: tien,
      chieu: chieu,
      ngay: DateTime(2026, 9, 5),
    );

KetQuaTimGiaoDich _kq(List<DongTimThay> dong) => KetQuaTimGiaoDich(
      dong: dong,
      soKhop: dong.length,
      tongChi: dong.where((d) => d.chieu == ChieuTim.chi).fold(0, (s, d) => s + d.soTien),
      tongThu: dong.where((d) => d.chieu == ChieuTim.thu).fold(0, (s, d) => s + d.soTien),
      tongChuyen: 0,
    );

void main() {
  const tc = TieuChiTim(chieu: ChieuTim.chi);
  final nam = _kq([
    _d('Cho vay', 800000, ChieuTim.chi),
    _d('Ăn uống', 600000, ChieuTim.chi),
    _d('Di chuyển', 355000, ChieuTim.chi),
    _d('Mua sắm', 60000, ChieuTim.chi),
    _d('Giải trí', 30000, ChieuTim.chi),
  ]);

  test('⭐ năm nhóm → bốn hàng: top ba + nhóm ÍT NHẤT; hai đầu mang trạng thái; Số danh mục 5', () {
    final kq = hangNhomGiaoDich(nam, tieuChi: tc, theo: NhomTheo.danhMuc, chuKy: 'tháng này');
    expect(kq.hang.map((h) => h.ten).toList(), ['Cho vay', 'Ăn uống', 'Di chuyển', 'Giải trí']);
    expect(kq.hang.first.trangThai, kTrangThaiChiNhieuNhat);
    expect(kq.hang.last.trangThai, kTrangThaiChiItNhat);
    expect(kq.hang[1].trangThai, isNull);
    expect(kq.hang.first.json,
        {'ten': 'Cho vay', 'trang_thai': 'chi nhiều nhất', 'Chi': '800.000 đ', 'Số giao dịch': '1'});
    expect(kq.tongHop.map((s) => '${s.nhan}=${s.chuoi}').toList(),
        ['Tổng chi=1.845.000 đ', 'Số giao dịch=5', 'Số danh mục=5']);
    expect(kq.chuThem, {'ky': 'tháng này'});
    expect(kq.boLoc, ['khoản chi', 'gộp theo danh mục']);
  });

  test('⭐ chon it_nhat → đúng MỘT hàng, là nhóm nhỏ nhất, tổng hợp vẫn trọn tập', () {
    final kq = hangNhomGiaoDich(nam, tieuChi: tc, theo: NhomTheo.danhMuc, chuKy: 'tháng này', chon: 'it_nhat');
    expect(kq.hang.single.ten, 'Giải trí');
    expect(kq.hang.single.trangThai, kTrangThaiChiItNhat);
    expect(kq.tongHop.first.chuoi, '1.845.000 đ');
    expect(kq.boLoc, ['khoản chi', 'gộp theo danh mục', 'chọn ít nhất']);
  });

  test('chon nhieu_nhat → một hàng lớn nhất', () {
    final kq = hangNhomGiaoDich(nam, tieuChi: tc, theo: NhomTheo.danhMuc, chuKy: 'tháng này', chon: 'nhieu_nhat');
    expect(kq.hang.single.ten, 'Cho vay');
    expect(kq.hang.single.trangThai, kTrangThaiChiNhieuNhat);
  });

  test('mọi SoLieu của hàng mang tên nhóm (kiemNhan); nhãn Chi khai xung đột Thu; Số giao dịch có nhãn thay thế', () {
    final kq = hangNhomGiaoDich(nam, tieuChi: tc, theo: NhomTheo.danhMuc, chuKy: 'tháng này');
    for (final h in kq.hang) {
      for (final s in h.soLieu) {
        expect(s.ten, h.ten);
      }
      expect(h.soLieu.firstWhere((s) => s.nhan == 'Chi').nhanXungDot, ['Thu']);
      expect(h.soLieu.firstWhere((s) => s.nhan == 'Số giao dịch').nhanKhac, ['Số khoản']);
    }
  });

  test('chiều thu: nhãn Thu, trạng thái "thu nhiều nhất"; không có nhãn Chi', () {
    final kq = hangNhomGiaoDich(
      _kq([_d('Lương', 9000000, ChieuTim.thu), _d('Thưởng', 25000, ChieuTim.thu)]),
      tieuChi: const TieuChiTim(chieu: ChieuTim.thu),
      theo: NhomTheo.danhMuc,
      chuKy: 'tháng này',
    );
    expect(kq.hang.first.trangThai, kTrangThaiThuNhieuNhat);
    expect(kq.hang.first.soLieu.map((s) => s.nhan).toList(), ['Thu', 'Số giao dịch']);
  });

  test('khoản không danh mục → nhóm "Chưa phân loại" nằm trong tenLienQuan (kiemTen không chặn oan)', () {
    final kq = hangNhomGiaoDich(_kq([_d(null, 500000, ChieuTim.chi)]),
        tieuChi: tc, theo: NhomTheo.danhMuc, chuKy: 'tháng này');
    expect(kq.hang.single.ten, kTenChuaPhanLoai);
    expect(kq.tenLienQuan, contains(kTenChuaPhanLoai));
  });

  test('0 khoản → 0 hàng, rongTheoBoLoc, tổng hợp vẫn có', () {
    final kq = hangNhomGiaoDich(_kq(const []), tieuChi: tc, theo: NhomTheo.vi, chuKy: 'tuần này');
    expect(kq.hang, isEmpty);
    expect(kq.rongTheoBoLoc, isTrue);
    expect(kq.tongHop.map((s) => s.nhan), contains('Số ví'));
  });

  test('một nhóm → không so sánh gì: trạng thái null', () {
    final kq = hangNhomGiaoDich(_kq([_d('Ăn uống', 1, ChieuTim.chi)]),
        tieuChi: tc, theo: NhomTheo.danhMuc, chuKy: 'tháng này');
    expect(kq.hang.single.trangThai, isNull);
  });

  test('chon lạ → từ chối, không dựng hàng', () {
    final kq = hangNhomGiaoDich(nam, tieuChi: tc, theo: NhomTheo.danhMuc, chuKy: 'tháng này', chon: 'tat_ca');
    expect(kq.loi, contains('nhieu_nhat'));
    expect(kq.hang, isEmpty);
  });
}
