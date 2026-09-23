/// Gói tích luỹ của một câu hỏi ở bậc tool. Hai điều nó phải giữ: (1) ba lớp
/// chắn và thẻ số liệu dùng NGUYÊN — nó chỉ là một `GoiSo` nữa; (2) `daTraCuu`
/// là chốt L1 của vòng lặp — tool trả 0 hàng vẫn là đã tra cứu.
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so_tra_cuu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_so_lieu.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_cau_tra_loi.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_so.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';
import 'package:flowmoney/features/ai_edge/domain/the_cua_cau.dart';
import 'package:flutter_test/flutter_test.dart';

KetQuaCongCu _hoaDonQuaHan() => KetQuaCongCu(
      hang: [
        HangSoLieu(
          ten: 'Kiem',
          trangThai: 'đã quá hạn',
          canhBao: true,
          soLieu: [soTien('Số tiền', 45000, ten: 'Kiem')],
        ),
      ],
      tongHop: [soTien('Còn phải trả', 155000), soDem('Quá hạn', 1)],
    );

void main() {
  test('mới dựng: chưa tra cứu, thiếu dữ liệu, câu thật, man = tra_cuu', () {
    final g = GoiSoTraCuu();
    expect(g.daTraCuu, isFalse);
    expect(g.thieuDuLieu, isTrue);
    expect(g.soLieu, isEmpty);
    expect(g.man, 'tra_cuu');
    final nx = g.mauCau();
    expect(nx.muc, MucNhanXet.thieuDuLieu);
    expect(nx.cau, isNotEmpty);
  });

  test('them: tổng hợp đứng TRƯỚC hàng trong soLieu', () {
    final g = GoiSoTraCuu()..them('danh_sach_hoa_don', _hoaDonQuaHan());
    expect(g.soLieu.map((s) => s.nhan).toList(),
        ['Còn phải trả', 'Quá hạn', 'Số tiền'],
        reason: 'chuoiTheoNhan lấy mục đầu; mục tổng hợp không tên phải gặp trước');
    expect(g.soLieu.last.ten, 'Kiem');
    expect(g.tenCongCuDaChay, ['danh_sach_hoa_don']);
  });

  test('⭐ tool chạy mà trả 0 hàng VẪN là đã tra cứu (chốt L1)', () {
    final g = GoiSoTraCuu()
      ..them('danh_sach_hoa_don', const KetQuaCongCu(hang: [], tongHop: []));
    expect(g.daTraCuu, isTrue,
        reason: '"Không có hoá đơn quá hạn" là dữ liệu thật trước mắt mô hình. '
            'Coi nó là chưa tra cứu thì câu đúng ấy rơi về bậc 1 vô cớ.');
    expect(g.thieuDuLieu, isFalse);
    final nx = g.mauCau();
    expect(nx.cau, 'Không tìm thấy dữ liệu khớp câu hỏi.');
    expect(nx.muc, MucNhanXet.binhThuong);
  });

  test('tool từ chối tham số cũng là đã chạy', () {
    final g = GoiSoTraCuu()
      ..them('chi_tieu_theo_ky', const KetQuaCongCu.loi('ky lạ'));
    expect(g.daTraCuu, isTrue);
  });

  test('⭐ mẫu câu nêu TÊN trước số và tự qua bộ kiểm số', () {
    final g = GoiSoTraCuu()..them('danh_sach_hoa_don', _hoaDonQuaHan());
    final nx = g.mauCau();
    expect(nx.cau, contains('Kiem đã quá hạn: Số tiền 45.000 đ'));
    expect(nx.cau, contains('Còn phải trả: 155.000 đ'));
    expect(kiemSo(nx.cau, g), isTrue,
        reason: 'Đây là câu L2/L3 rơi về; mẫu câu bị chính bộ kiểm chặn là '
            'bẫy 4.1 tái phát.');
    expect(nx.theSoLieu, g.soLieu);
  });

  test('mức cảnh báo theo CỜ canhBao của hàng, không theo chữ trạng thái', () {
    final coCo = GoiSoTraCuu()..them('t', _hoaDonQuaHan());
    expect(coCo.mauCau().muc, MucNhanXet.canhBao);

    final khongCo = GoiSoTraCuu()
      ..them(
        't',
        KetQuaCongCu(
          hang: [
            HangSoLieu(
              ten: 'Kiem',
              trangThai: 'đã quá hạn', // cùng chữ, nhưng tool không giơ cờ
              canhBao: false,
              soLieu: [soTien('Số tiền', 45000, ten: 'Kiem')],
            ),
          ],
          tongHop: const [],
        ),
      );
    expect(khongCo.mauCau().muc, MucNhanXet.binhThuong,
        reason: 'Đọc chuỗi để đoán mức là để một lần đổi nhãn đổi luôn giọng '
            'câu, im lặng.');
  });

  test('tích luỹ qua hai tool', () {
    final g = GoiSoTraCuu()
      ..them('danh_sach_hoa_don', _hoaDonQuaHan())
      ..them(
        'danh_sach_vi',
        KetQuaCongCu(
          hang: [
            HangSoLieu(
              ten: 'test',
              trangThai: 'đang âm',
              canhBao: true,
              soLieu: [soTien('Số dư', -100000, ten: 'test')],
            ),
          ],
          tongHop: [soTien('Tổng tài sản', 13004000)],
        ),
      );
    expect(g.hang.length, 2);
    expect(g.tenCongCuDaChay, ['danh_sach_hoa_don', 'danh_sach_vi']);
    expect(g.soLieu.length, 5);
  });

  group('ba lớp chắn và thẻ dùng NGUYÊN trên [goiTraCuu]', () {
    final g = GoiSoTraCuu()..them('danh_sach_hoa_don', _hoaDonQuaHan());

    test('câu nêu tên + số thật → lọt', () {
      expect(kiemCauTraLoi('Kiem đã quá hạn 45.000 đ.', [g]), isTrue);
    });

    test('số thật nhưng KHÔNG nêu tên → kiemNhan chặn (luật 4a)', () {
      expect(kiemCauTraLoi('Có 45.000 đ hoá đơn quá hạn.', [g]), isFalse);
    });

    test('số bịa → kiemSo chặn', () {
      expect(kiemCauTraLoi('Kiem đã quá hạn 99.000 đ.', [g]), isFalse);
    });

    test('thẻ số liệu nêu tên', () {
      expect(theCuaCau('Kiem đã quá hạn 45.000 đ.', [g]),
          ['Kiem · Số tiền 45.000 đ']);
    });
  });
}
