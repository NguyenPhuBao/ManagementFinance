/// Bộ kiểm số — điều kiện 10 của mục 13 bản đánh giá: mọi con số trong câu
/// phải có trong gói số, sai thì rơi về mẫu câu. Đây là câu hội đồng sẽ hỏi
/// ("mô hình bịa số thì sao?"), nên ca "câu bịa một số bị chặn" là ca quan
/// trọng nhất của tệp.
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_so.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gia extends GoiSo {
  @override
  final String man = 'ngan_sach';
  @override
  final List<SoLieu> soLieu;
  _Gia(this.soLieu);
  @override
  bool get thieuDuLieu => false;
  @override
  NhanXet mauCau() =>
      NhanXet(cau: '', theSoLieu: soLieu, muc: MucNhanXet.binhThuong);
}

void main() {
  final goi = _Gia([
    soTien('Đã chi', 2100000),
    soPhanTram('Tỉ lệ', 70),
    soNgay('Còn', 9),
  ]);

  test('trichSo đọc được tiền có chấm nghìn, phần trăm có phẩy, số trần', () {
    final s = trichSo('Bạn đã dùng 2.100.000 đ (70,0%), còn 9 ngày.');
    expect(s.map((x) => x.giaTri).toList(), [2100000, 70, 9]);
    expect(s[0].laPhanTram, isFalse);
    expect(s[1].laPhanTram, isTrue);
    expect(s[2].laPhanTram, isFalse);
  });

  test('câu đúng số lọt', () {
    expect(kiemSo('Bạn đã dùng 2.100.000 đ (70,0%), còn 9 ngày.', goi), isTrue);
  });

  test('câu BỊA một số bị chặn', () {
    expect(kiemSo('Bạn đã dùng 2.150.000 đ, còn 9 ngày.', goi), isFalse,
        reason: '2.150.000 không có trong gói — mô hình vừa bịa');
  });

  test('câu không có số nào thì lọt', () {
    expect(kiemSo('Bạn đang chi tiêu đúng nhịp.', goi), isTrue);
  });

  test('phần trăm lệch trong 0,05 lọt, lệch hơn bị chặn', () {
    expect(kiemSo('Bạn đã dùng 70,04%.', goi), isTrue);
    expect(kiemSo('Bạn đã dùng 70,2%.', goi), isFalse);
  });

  test('số tiền lệch 1 đồng bị chặn (ngưỡng nửa đồng)', () {
    expect(kiemSo('Bạn đã dùng 2.100.001 đ.', goi), isFalse);
  });

  test('trichSo giữ dấu âm — soPhanTram in -8,3% khi giảm', () {
    final g = _Gia([soPhanTram('So kỳ trước', -8.3)]);
    expect(trichSo('giảm -8,3%').single.giaTri, closeTo(-8.3, 1e-9));
    expect(kiemSo('Kỳ này -8,3% so với kỳ trước.', g), isTrue);
    expect(kiemSo('Kỳ này 8,3% so với kỳ trước.', g), isFalse,
        reason: 'mất dấu là đảo nghĩa tăng/giảm — phải chặn');
  });

  test('số có % không được khớp với số liệu TIỀN cùng giá trị', () {
    final g = _Gia([soTien('Đã chi', 70)]);
    expect(kiemSo('Bạn đã dùng 70%.', g), isFalse,
        reason: '70 đ và 70% là hai con số khác nhau; loại phải khớp');
  });

  test('số trần khớp số ngày hoặc số đếm, không khớp tiền', () {
    final g = _Gia([soNgay('Còn', 9), soTien('Đã chi', 9)]);
    expect(kiemSo('Còn 9 ngày.', g), isTrue);
    expect(kiemSo('Đã chi 9 đ.', g), isTrue,
        reason: 'số trần theo sau đ vẫn là một con số, khớp tiền được');
  });

  // ── Tên đối tượng có chữ số (bước 1c, 2026-09-23) ───────────────────────
  //
  // Đo trên CSDL máy ảo, tài khoản 10: 5/9 hoá đơn và 1/16 danh mục mang chữ
  // số trong tên. `trichSo` đọc chữ số ấy là một con số không có trong gói,
  // nên câu ĐÚNG nêu tên những hoá đơn ấy luôn bị chặn — cổng C không thấy vì
  // hoá đơn đo được tên `Kiem`.
  group('tên đối tượng có chữ số (bước 1c)', () {
    _Gia hoaDon(String ten) => _Gia([soTien('Số tiền', 50000, ten: ten)]);

    test('⭐ chữ số nằm TRONG tên đối tượng không bị đọc là một con số', () {
      expect(
        kiemSo(
          'Hoá đơn Kiem thu hoa don 123 chưa trả, số tiền 50.000 đ.',
          hoaDon('Kiem thu hoa don 123'),
        ),
        isTrue,
        reason: 'Đúng câu đã chạy thử trên mã 2026-09-23: "123" là một phần của '
            'tên hoá đơn. Đọc nó là số thì mọi câu đúng nêu tên hoá đơn ấy đều '
            'bị chặn, im lặng — người dùng chỉ thấy câu rơi về mẫu.',
      );
    });

    test('tên viết hoa khác vẫn là tên', () {
      expect(
        kiemSo('TIỀN NHÀ T9 chưa trả 50.000 đ.', hoaDon('Tiền nhà T9')),
        isTrue,
      );
    });

    test('số BỊA đứng cạnh tên vẫn bị chặn', () {
      expect(
        kiemSo('Tiền nhà T9 chưa trả 99.000 đ.', hoaDon('Tiền nhà T9')),
        isFalse,
        reason: 'Chỉ chữ số NẰM TRONG tên được bỏ qua — 99.000 thì không.',
      );
    });

    test('một MẨU của tên đứng riêng vẫn bị kiểm như một con số', () {
      expect(
        kiemSo('Còn 9 ngày nữa.', hoaDon('Tiền nhà T9')),
        isFalse,
        reason: '"9" đứng riêng không phải tên "Tiền nhà T9". Bỏ qua mọi chữ số '
            'từng xuất hiện trong một tên là mở cửa cho số bịa.',
      );
    });

    test('tên phải khớp TRỌN TỪ ở cả hai đầu', () {
      expect(
        kiemSo('Ban 5 người chi 50.000 đ.', hoaDon('An 5')),
        isFalse,
        reason: '"an 5" là chuỗi con của "Ban 5" — khớp chuỗi con thì con số 5 '
            'bịa lọt qua nhờ một tên tình cờ trùng mẩu chữ.',
      );
      final coSoDem5 = _Gia([
        soTien('Số tiền', 50000, ten: 'Quỹ 9'),
        soDem('Chưa trả', 5),
      ]);
      expect(
        kiemSo('Quỹ 95 chưa trả 50.000 đ.', coSoDem5),
        isFalse,
        reason: '"Quỹ 95" không phải "Quỹ 9". Bỏ mẩu "Quỹ 9" thì phần "5" còn '
            'sót khớp nhầm số đếm 5 của gói, và 95 bịa lọt qua.',
      );
    });

    test('tên KHÔNG có chữ cái nào thì không được miễn', () {
      expect(
        kiemSo('Còn 2027 ngày, chưa trả 50.000 đ.', hoaDon('2027')),
        isFalse,
        reason: 'Tên toàn chữ số thì không phân biệt được "tên" với "con số" — '
            'miễn nó là để mọi số 2027 trong câu đều lọt.',
      );
    });

    test('hai tên lồng nhau: tên DÀI được bỏ trước', () {
      final g = _Gia([
        soTien('Số tiền', 50000, ten: 'Quỹ 9'),
        soTien('Số tiền', 70000, ten: 'Quỹ 9 2026'),
      ]);
      expect(
        kiemSo('Quỹ 9 2026 chưa trả 70.000 đ.', g),
        isTrue,
        reason: 'Bỏ "Quỹ 9" trước thì phần "2026" còn lại bị đọc là số, và câu '
            'đúng về "Quỹ 9 2026" bị chặn.',
      );
    });

    test('kiemSoNhieuGoi: tên ở gói này, số ở gói kia', () {
      final pt = _Gia([soTien('Tổng chi', 2141000)]);
      expect(
        kiemSoNhieuGoi(
          'Tiền nhà T9 chưa trả 50.000 đ, tổng chi 2.141.000 đ.',
          [pt, hoaDon('Tiền nhà T9')],
        ),
        isTrue,
      );
    });
  });

  // ── Ngày tháng (bước 2, 2026-09-23) ─────────────────────────────────────
  //
  // Hàng giao dịch mang NGÀY (`12/09`). Trước bước 2, `trichSo` đọc nó là hai
  // con số 12 và 9 — không có trong gói — nên mọi câu nêu ngày đều bị chặn.
  // Ngày phải là một LOẠI số riêng: số trần không được khớp mục ngày, và ngày
  // không được khớp mục tiền / số đếm, nếu không số bịa lọt nhờ trùng chữ số.
  // Cổng D lần 4–6 (mục 9.20–9.23): C7 hỏi "hơn nửa triệu", mô hình viết
  // "hơn MỘT TRIỆU" bằng chữ rồi liệt kê bốn danh mục đều dưới một triệu. Không
  // chữ số nào ngoài gói nên kiemSo im — ba lần đo trước câu ấy chỉ bị chặn
  // DO MAY vì mô hình chép "1 triệu" bằng chữ số.
  group('số viết bằng CHỮ là một con số — bẫy 4.42', () {
    final tongKet = _Gia([
      soTien('Tổng chi', 2141000),
      soTien('Chi', 800000, ten: 'Cho vay'),
      soTien('Chi', 500000, ten: 'Chưa phân loại'),
      soTien('Chi', 355000, ten: 'Di chuyển'),
      soTien('Chi', 301000, ten: 'Chi khác'),
    ]);

    test('⭐ câu C7 đo trên Realme 2026-09-24 bị chặn vì "một triệu" không có trong gói', () {
      expect(
        kiemSo(
          'Các khoản chi có giá trị hơn một triệu là: Cho vay (800.000 đ), '
          'Chưa phân loại (500.000 đ), Di chuyển (355.000 đ), và Chi khác (301.000 đ).',
          tongKet,
        ),
        isFalse,
        reason: 'Nguyên văn C7 lần 4, 5, 6 — mọi số và tên đều thật, mệnh đề '
            '"hơn một triệu" sai. Đọc "một triệu" là 1.000.000 thì gói không có '
            'và câu rơi mẫu câu như ba lần chặn-do-may trước đó.',
      );
    });

    test('trichSo đọc đúng các dạng số chữ + đơn vị', () {
      double mot(String cau) => trichSo(cau).single.giaTri;
      expect(mot('hơn một triệu'), 1000000);
      expect(mot('nửa triệu'), 500000);
      expect(mot('hai trăm nghìn'), 200000);
      expect(mot('năm trăm ngàn'), 500000);
      expect(mot('mười nghìn'), 10000);
      expect(mot('ba tỷ'), 3000000000);
      expect(mot('một triệu rưỡi'), 1500000);
      expect(mot('một triệu hai trăm nghìn'), 1200000,
          reason: 'hai nhóm liền nhau cộng lại');
    });

    test('không phân biệt hoa thường', () {
      expect(trichSo('Hơn Một Triệu đồng').single.giaTri, 1000000);
    });

    test('số chữ CÓ trong gói thì qua — diễn đạt lại một con số thật không phải bịa', () {
      final g = _Gia([soTien('Tổng chi', 1000000)]);
      expect(kiemSo('Tổng chi là một triệu đồng.', g), isTrue);
    });

    test('lượng từ mơ hồ ("vài triệu", "mấy nghìn") là số KHÔNG BAO GIỜ khớp gói', () {
      expect(trichSo('vài triệu').single.giaTri.isNaN, isTrue);
      expect(kiemSo('Bạn đã chi vài triệu.', tongKet), isFalse,
          reason: 'một lượng không kiểm được thì không được hiện');
      expect(kiemSo('Còn mấy nghìn.', tongKet), isFalse);
    });

    test('từ số KHÔNG đi kèm đơn vị không phải con số: "một khoản", "năm nay", "một hóa đơn"', () {
      expect(trichSo('Có một khoản chi trong năm nay và một hóa đơn.'), isEmpty);
    });

    test('đơn vị đứng một mình ("hàng triệu") không phải con số', () {
      expect(trichSo('bạn có hàng triệu lý do'), isEmpty);
    });

    test('thứ tự theo câu, và số chữ không dính với chữ số cạnh nó', () {
      final s = trichSo('hơn một triệu ở 2 khoản');
      expect(s.map((x) => x.giaTri).toList(), [1000000, 2]);
    });
  });

  group('ngày tháng — LoaiSo.ngayThang (bước 2)', () {
    final now = DateTime(2026, 9, 23);
    _Gia coNgay() => _Gia([
          soTien('Số tiền', 50000, ten: 'Ăn uống'),
          soNgayThang('Ngày', DateTime(2026, 9, 12), ten: 'Ăn uống', now: now),
        ]);

    test('⭐ trichSo tách NGÀY trước số: 12/09 là một ngày, không phải 12 và 9', () {
      final s = trichSo('Ăn uống 50.000 đ ngày 12/09.');
      expect(s.map((x) => x.laNgay).toList(), [false, true]);
      expect(s[1].giaTri, 912, reason: 'ngày mã hoá tháng·100 + ngày');
      expect(s[1].nam, isNull, reason: 'câu không ghi năm');
    });

    test('kết quả theo đúng thứ tự trong câu', () {
      final s = trichSo('Ngày 12/09 chi 50.000 đ.');
      expect(s.map((x) => x.laNgay).toList(), [true, false]);
      expect(s[1].giaTri, 50000);
    });

    test('câu nêu đúng ngày lọt; ngày sai bị chặn', () {
      expect(kiemSo('Ăn uống 50.000 đ ngày 12/09.', coNgay()), isTrue);
      expect(kiemSo('Ăn uống 50.000 đ ngày 13/09.', coNgay()), isFalse,
          reason: '13/09 không có trong gói — mô hình vừa bịa một ngày');
    });

    test('năm chỉ so khi câu có ghi năm', () {
      expect(kiemSo('Ngày 12/09/2026.', coNgay()), isTrue);
      expect(kiemSo('Ngày 12/09/2025.', coNgay()), isFalse);
      final khacNam = _Gia([soNgayThang('Ngày', DateTime(2025, 12, 28), now: now)]);
      expect(kiemSo('Ngày 28/12.', khacNam), isTrue,
          reason: 'câu không ghi năm thì không có năm nào để sai');
    });

    test('⭐ số trần KHÔNG khớp mục ngày, ngày KHÔNG khớp mục số', () {
      expect(kiemSo('Còn 12 ngày.', coNgay()), isFalse,
          reason: '"12" trần không phải ngày 12/09 — khớp thì một số bịa lọt nhờ '
              'trùng chữ số với một ngày có thật');
      final soThuong = _Gia([soDem('Số khoản', 912), soNgay('Còn', 12)]);
      expect(kiemSo('Ngày 12/09.', soThuong), isFalse,
          reason: 'ngày 12/09 (mã 912) không phải số đếm 912');
    });

    test('dạng không hợp lệ không phải ngày — đi tiếp như số (chiều an toàn)', () {
      expect(trichSo('45/13').map((x) => (x.giaTri, x.laNgay)).toList(),
          [(45.0, false), (13.0, false)]);
      final hai = trichSo('12/09/26');
      expect(hai.length, 3, reason: 'năm hai chữ số không phải dạng ngày hợp lệ');
      expect(hai.every((x) => !x.laNgay), isTrue);
      expect(kiemSo('Ngày 12/09/26.', coNgay()), isFalse);
    });

    test('mô hình viết "ngày 12 tháng 9" → hai số trần → bị chặn', () {
      expect(kiemSo('Ăn uống 50.000 đ ngày 12 tháng 9.', coNgay()), isFalse,
          reason: 'hỏng theo chiều an toàn: rơi về mẫu câu; prompt dặn chép nguyên ngày');
    });
  });
}
