/// Gói tích luỹ của một câu hỏi ở bậc tool. Hai điều nó phải giữ: (1) ba lớp
/// chắn và thẻ số liệu dùng NGUYÊN — nó chỉ là một `GoiSo` nữa; (2) `daTraCuu`
/// là chốt L1 của vòng lặp — tool trả 0 hàng vẫn là đã tra cứu, lượt bị TỪ CHỐI
/// thì không (bước 2b).
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so_tra_cuu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_so_lieu.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_cau_tra_loi.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_so.dart';
import 'package:flowmoney/features/ai_edge/domain/loi_tham_so.dart';
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

  test('⭐ lượt bị TỪ CHỐI không phải đã tra cứu (bẫy 4.40 — lật một vế chốt L1 của spec 4b)', () {
    final g = GoiSoTraCuu()
      ..them('chi_tieu_theo_ky', tuChoiGiaTri('ky', 'hom_kia', const ['thang_nay']));
    expect(g.daTraCuu, isFalse,
        reason: 'Lời từ chối nói "câu hỏi gửi tool bị hỏng", không nói "không có gì". '
            'Cổng D lần 1: tính nó là đã tra cứu thì câu "không có dữ liệu" của '
            'mô hình được hiện — C11, C12 SAI mà không chứa số nào.');
    expect(g.thieuDuLieu, isTrue);
    expect(g.tenCongCuDaChay, isEmpty);
    expect(g.tuChoiChuaGo.single.ten, 'chi_tieu_theo_ky');
    expect(g.choHienChuMoHinh, isFalse);
  });

  test('⭐ mọi lượt bị từ chối → mẫu câu TRUNG THỰC: nêu lý do, không khẳng định gì về dữ liệu', () {
    final g = GoiSoTraCuu()
      ..them('tim_giao_dich',
          tuChoiKhongKhop('danh_muc', 'tiet kiem', const ['Ăn uống'], loai: 'danh mục'));
    final nx = g.mauCau();
    expect(nx.cau,
        'Chưa tra được số liệu cho câu này: không có danh mục nào tên "tiet kiem". '
        'Bạn thử hỏi lại cụ thể hơn.');
    expect(nx.cau, isNot(contains('Không tìm thấy')),
        reason: 'C8 của cổng D lần 1 nhận đúng câu ấy từ MẪU CÂU của app, trong khi có 2 khoản');
    expect(nx.theSoLieu, isEmpty);
    expect(nx.muc, MucNhanXet.thieuDuLieu);
  });

  test('lý do trùng nhau chỉ nói một lần, theo thứ tự', () {
    final g = GoiSoTraCuu()
      ..them('tim_giao_dich', tuChoiGiaTri('ky', 'x', const ['thang_nay']))
      ..them('tim_giao_dich', tuChoiGiaTri('ky', 'y', const ['thang_nay']))
      ..them('tim_giao_dich', tuChoiSoTien('so_tien_tu', '500k'));
    expect(g.mauCau().cau,
        'Chưa tra được số liệu cho câu này: chưa hiểu khoảng thời gian trong câu hỏi; '
        'chưa hiểu số tiền trong câu hỏi. Bạn thử hỏi lại cụ thể hơn.');
  });

  test('⭐ lẫn: dữ liệu của lượt thành công + câu chưa tra được — cổng hiện chữ ĐÓNG', () {
    final g = GoiSoTraCuu()
      ..them('danh_sach_hoa_don', _hoaDonQuaHan())
      ..them('goi_y_han_muc',
          tuChoiKhongKhop('danh_muc', 'muaxe', const ['Ăn uống'], loai: 'danh mục chi'));
    expect(g.daTraCuu, isTrue);
    expect(g.choHienChuMoHinh, isFalse,
        reason: 'spike S3: mô hình nói "Tôi đã gợi ý hạn mức…" trong khi goi_y_han_muc bị từ chối');
    expect(g.cauChuaTraDuoc,
        'Chưa tra được phần còn lại: không có danh mục chi nào tên "muaxe".');
    final nx = g.mauCau();
    expect(nx.cau,
        'Kiem đã quá hạn: Số tiền 45.000 đ; Còn phải trả: 155.000 đ; Quá hạn: 1. '
        'Chưa tra được phần còn lại: không có danh mục chi nào tên "muaxe".');
    expect(kiemSo(nx.cau, g), isTrue, reason: 'câu rơi về phải tự qua bộ kiểm số');
    expect(nx.muc, MucNhanXet.canhBao);
  });

  test('tên sai có chữ số không đẻ ra thẻ số liệu', () {
    final g = GoiSoTraCuu()
      ..them('danh_sach_hoa_don', _hoaDonQuaHan())
      ..them('tim_giao_dich',
          tuChoiKhongKhop('danh_muc', 'abc 1', const ['Ăn uống'], loai: 'danh mục'));
    expect(theCuaCau(g.cauChuaTraDuoc!, [g]), isEmpty,
        reason: '"1" trong tên SAI không phải con số — không được đẻ thẻ "Quá hạn 1"');
  });

  group('gỡ lời từ chối THEO THAM SỐ (spec 2b mục 1.2 hàng 4)', () {
    final tuChoi =
        tuChoiKhongKhop('danh_muc', 'abc', const ['Ăn uống'], loai: 'danh mục');
    final thanhCong = KetQuaCongCu(hang: const [], tongHop: [soDem('Số khoản', 0)]);

    test('cùng tool thành công mà ĐIỀN tham số → gỡ, cổng mở', () {
      final g = GoiSoTraCuu()
        ..them('tim_giao_dich', tuChoi)
        ..them('tim_giao_dich', thanhCong, args: const {'danh_muc': 'Ăn uống'});
      expect(g.tuChoiChuaGo, isEmpty);
      expect(g.choHienChuMoHinh, isTrue);
      expect(g.cauChuaTraDuoc, isNull);
    });

    test('⭐ cùng tool thành công mà BỎ tham số → CHƯA gỡ', () {
      final g = GoiSoTraCuu()
        ..them('tim_giao_dich', tuChoi)
        ..them('tim_giao_dich', thanhCong);
      expect(g.tuChoiChuaGo, hasLength(1),
          reason: 'bỏ bộ lọc sai rồi nói về kết quả rộng hơn như thể trả lời câu hẹp: '
              '"các khoản chi cho danh mục abc: …" — SAI mà lọt cả ba lớp chắn');
      expect(g.choHienChuMoHinh, isFalse);
    });

    test('điền bằng giá trị giữ chỗ → CHƯA gỡ', () {
      final g = GoiSoTraCuu()
        ..them('tim_giao_dich', tuChoi)
        ..them('tim_giao_dich', thanhCong, args: const {'danh_muc': 'tat_ca'});
      expect(g.tuChoiChuaGo, hasLength(1));
    });

    test('tool KHÁC thành công → CHƯA gỡ', () {
      final g = GoiSoTraCuu()
        ..them('tim_giao_dich', tuChoi)
        ..them('chi_tieu_theo_ky', thanhCong, args: const {'danh_muc': 'Ăn uống'});
      expect(g.tuChoiChuaGo, hasLength(1));
    });

    test('lượt thành công đứng TRƯỚC lời từ chối không gỡ nó', () {
      final g = GoiSoTraCuu()
        ..them('tim_giao_dich', thanhCong, args: const {'danh_muc': 'Ăn uống'})
        ..them('tim_giao_dich', tuChoi);
      expect(g.tuChoiChuaGo, hasLength(1));
    });

    test('số tiền trong tu_khoa gỡ bằng so_tien_tu', () {
      const tuKhoaLaSoTien = KetQuaCongCu.loi('tu_khoa "500k" là số tiền',
          choNguoiDung: 'chưa hiểu số tiền trong câu hỏi',
          thamSoGo: ['so_tien_tu', 'so_tien_den']);
      final g = GoiSoTraCuu()
        ..them('tim_giao_dich', tuKhoaLaSoTien)
        ..them('tim_giao_dich', thanhCong, args: const {'so_tien_tu': 500000});
      expect(g.tuChoiChuaGo, isEmpty);
    });
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

  test('mẫu câu tự qua bộ kiểm số khi TÊN có chữ số (bước 1c)', () {
    final g = GoiSoTraCuu()
      ..them(
        'danh_sach_hoa_don',
        KetQuaCongCu(
          hang: [
            HangSoLieu(
              ten: 'Tiền nhà T9',
              trangThai: 'chưa trả',
              canhBao: false,
              soLieu: [soTien('Số tiền', 50000, ten: 'Tiền nhà T9')],
            ),
          ],
          tongHop: [soTien('Còn phải trả', 50000)],
        ),
      );
    final cau = g.mauCau().cau;
    expect(cau, contains('Tiền nhà T9 chưa trả: Số tiền 50.000 đ'));
    expect(kiemSo(cau, g), isTrue,
        reason: 'L2/L3 rơi về đúng câu này. 5/9 hoá đơn của tài khoản 10 có '
            'chữ số trong tên — mẫu câu phải tự qua bộ kiểm với chúng.');
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

  group('mẫu câu sau NHIỀU lời gọi — bẫy 4.35 (chặng 4b, OnePlus 2026-09-23)', () {
    KetQuaCongCu chiTieu(String ky, {required bool coDuLieu}) => KetQuaCongCu(
          hang: [
            if (coDuLieu)
              HangSoLieu(
                ten: 'Cho vay',
                trangThai: null,
                canhBao: false,
                soLieu: [soTien('Chi', 800000, ten: 'Cho vay')],
              ),
          ],
          tongHop: [
            soTien('Tổng chi', coDuLieu ? 2141000 : 0),
            soTien('Tổng thu', coDuLieu ? 15135000 : 0),
          ],
          chuThem: {'ky': ky},
        );

    test('⭐ mỗi nhóm nêu KỲ; lượt trùng nội dung gộp nhãn kỳ, không lặp hàng', () {
      // Đúng chuỗi lời gọi OnePlus đo được cho câu ĐC1 rồi chạm trần (L3).
      final g = GoiSoTraCuu()
        ..them('chi_tieu_theo_ky', chiTieu('tháng này', coDuLieu: true))
        ..them('chi_tieu_theo_ky', chiTieu('năm nay', coDuLieu: true))
        ..them('chi_tieu_theo_ky', chiTieu('tháng trước', coDuLieu: false));
      final cau = g.mauCau().cau;
      expect(
        cau,
        'Tháng này, năm nay — Cho vay: Chi 800.000 đ; Tổng chi: 2.141.000 đ; '
        'Tổng thu: 15.135.000 đ. Tháng trước — Tổng chi: 0 đ; Tổng thu: 0 đ.',
        reason: 'Bản đầu nối mọi hàng và mọi tổng không nhãn kỳ: "Tổng chi: '
            '2.141.000 đ" đứng cạnh "Tổng chi: 0 đ", và cả bộ hàng lặp hai lần '
            '— đúng câu máy thật hiện ra.',
      );
      expect(kiemSo(cau, g), isTrue, reason: 'câu rơi về phải tự qua bộ kiểm số');
    });

    test('hai lời gọi y hệt (không kỳ) → hàng chỉ nói một lần', () {
      final g = GoiSoTraCuu()
        ..them('danh_sach_hoa_don', _hoaDonQuaHan())
        ..them('danh_sach_hoa_don', _hoaDonQuaHan());
      final cau = g.mauCau().cau;
      expect('Kiem'.allMatches(cau).length, 1);
      expect(cau, isNot(contains('—')), reason: 'không có kỳ thì không tiền tố');
    });
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

    test('⭐ câu đúng nêu tên hoá đơn CÓ CHỮ SỐ → qua cả ba lớp (bước 1c)', () {
      final coSo = GoiSoTraCuu()
        ..them(
          'danh_sach_hoa_don',
          KetQuaCongCu(
            hang: [
              HangSoLieu(
                ten: 'Kiem thu hoa don 123',
                trangThai: 'chưa trả',
                canhBao: false,
                soLieu: [
                  soTien('Số tiền', 50000, ten: 'Kiem thu hoa don 123'),
                ],
              ),
            ],
            tongHop: [soTien('Còn phải trả', 50000)],
          ),
        );
      expect(
        kiemCauTraLoi(
          'Hoá đơn Kiem thu hoa don 123 chưa trả, số tiền 50.000 đ.',
          [coSo],
        ),
        isTrue,
        reason: 'Đúng câu đã chạy thử trên mã 2026-09-23: trước bước 1c cả '
            'kiemSoNhieuGoi lẫn kiemNhan chặn nó, còn cùng câu với tên "Kiem" '
            'thì qua.',
      );
    });
  });

  test('⭐ tenLienQuan của mọi lượt vào tenDoiTuong — chữ số trong tên không bị đọc là số (bước 2)', () {
    final g = GoiSoTraCuu()
      ..them(
        'tim_giao_dich',
        KetQuaCongCu(
          hang: [
            HangSoLieu(
              ten: 'Cà phê',
              trangThai: 'khoản chi · test1 · Tiền mặt',
              canhBao: false,
              soLieu: [soTien('Số tiền', 35000, ten: 'Cà phê')],
            ),
          ],
          tongHop: const [],
          tenLienQuan: const ['test1', 'Tiền mặt'],
        ),
      );
    expect(g.tenDoiTuong, containsAll(['Cà phê', 'test1', 'Tiền mặt']));
    expect(kiemSo('Cà phê 35.000 đ, danh mục test1.', g), isTrue,
        reason: '"1" của tên danh mục test1 không phải một con số (1/16 danh mục '
            'thật mang chữ số)');
    expect(kiemSo('Cà phê 35.000 đ, danh mục test1.', GoiSoTraCuu()), isFalse);
  });
}
