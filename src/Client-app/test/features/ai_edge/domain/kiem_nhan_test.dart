/// Bộ kiểm NHÃN — lớp chắn thứ ba, sinh ra từ điểm 4 cổng A hỏng theo đường
/// không ai lường (mục 9.5 `AI_EDGE_FEATURE.md`): mô hình không bịa **con
/// số** mà bịa **cái tên** của con số. *"Tỉ lệ phân bổ là 85,4%"* — mọi số
/// đều thật (85,4 % là tỉ lệ *để dành*), nên `kiemSo` cho qua.
///
/// Ca quan trọng nhất của tệp là ca chép **nguyên văn** câu đo trên máy thật.
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_nhan.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gia extends GoiSo {
  @override
  final String man;
  @override
  final List<SoLieu> soLieu;
  _Gia(this.man, this.soLieu);
  @override
  bool get thieuDuLieu => false;
  @override
  NhanXet mauCau() =>
      NhanXet(cau: '', theSoLieu: soLieu, muc: MucNhanXet.binhThuong);
}

void main() {
  // Đúng gói phân tích của tài khoản 10 ngày 2026-09-22 (mục 9.5).
  final phanTich = _Gia('phan_tich', [
    soTien('Tổng chi', 2141000),
    soTien('Tổng thu', 15135000),
    soPhanTram('Để dành', 85.4),
  ]);

  group('tuKhoaNhan', () {
    test('bỏ âm tiết chung (tổng, số, đã, so, với, là), giữ phần có nghĩa',
        () {
      expect(tuKhoaNhan('Tổng chi'), ['chi']);
      expect(tuKhoaNhan('Để dành'), ['để', 'dành']);
      expect(tuKhoaNhan('Số cam kết'), ['cam', 'kết']);
      expect(tuKhoaNhan('So kỳ trước'), ['kỳ', 'trước']);
    });

    test('nhãn chỉ toàn âm tiết chung thì giữ nguyên nhãn', () {
      expect(tuKhoaNhan('Tổng'), ['tổng']);
    });

    test('nhãn một âm tiết có nghĩa giữ nguyên', () {
      expect(tuKhoaNhan('Còn'), ['còn']);
    });
  });

  test('⭐ câu đo trên máy thật 2026-09-22 bị chặn ở vế gán sai nhãn', () {
    expect(
      kiemNhan('Tỉ lệ phân bổ là 85,4%.', [phanTich]),
      isFalse,
      reason: '85,4 chỉ khớp nhãn "Để dành" mà câu không có chữ "để dành" — '
          'đây là đúng câu mô hình đã nói, mọi số đều thật',
    );
  });

  test('câu dùng đúng nhãn thì qua', () {
    expect(
      kiemNhan(
        'Chi tiêu tháng này là 2.141.000 đ trên tổng thu 15.135.000 đ.',
        [phanTich],
      ),
      isTrue,
    );
    expect(kiemNhan('Bạn để dành được 85,4% thu nhập.', [phanTich]), isTrue);
  });

  test('không phân biệt hoa thường', () {
    expect(kiemNhan('Để Dành 85,4%.', [phanTich]), isTrue);
  });

  test('câu không có số nào thì qua — không có nhãn nào để gán sai', () {
    expect(kiemNhan('Bạn đang chi tiêu đúng nhịp.', [phanTich]), isTrue);
  });

  test('số không khớp nhãn nào thì chặn — không có nhãn để thoả', () {
    expect(kiemNhan('Bạn để dành 99,0%.', [phanTich]), isFalse);
  });

  test('số khớp HAI nhãn ở hai gói: đủ một nhãn là qua', () {
    // `Tổng chi` (phân tích) và `Chi` (trang chủ) cùng giá trị — có thật,
    // hai gói cùng đọc `tk.tong.chi`.
    final trangChu = _Gia('trang_chu', [soTien('Chi', 2141000)]);
    expect(
      kiemNhan('Tháng này chi 2.141.000 đ.', [phanTich, trangChu]),
      isTrue,
    );
  });

  test('nhãn nhiều âm tiết: đủ mọi âm tiết là qua, thứ tự và chen chữ tự do',
      () {
    final g = _Gia('phan_tich', [soTien('Khoản lớn nhất', 500000)]);
    expect(kiemNhan('Khoản chi lớn nhất là 500.000 đ.', [g]), isTrue);
    expect(kiemNhan('Lớn nhất là 500.000 đ.', [g]), isFalse,
        reason: 'thiếu "khoản" — nửa nhãn không đủ');
  });

  test('từ khoá so theo ÂM TIẾT, không theo chuỗi con', () {
    expect(
      kiemNhan('Chiều nay tiêu 2.141.000 đ.', [phanTich]),
      isFalse,
      reason: '"chiều" chứa "chi" nhưng không phải chữ "chi" — so chuỗi con '
          'là để một nhãn lọt qua nhờ một từ khác tình cờ chứa nó',
    );
  });

  test('mỗi số kiểm riêng: một số sai nhãn là cả câu bị chặn', () {
    expect(
      kiemNhan(
        'Tổng chi 2.141.000 đ, tỉ lệ phân bổ 85,4%.',
        [phanTich],
      ),
      isFalse,
    );
  });

  group('vế TÊN đối tượng (chặng 4a)', () {
    // Đúng gói ngân sách của tài khoản 10: ngân sách căng nhất là Giáo dục,
    // 90,0% (bảng đo mục 5.6 `AI_AGENT_ARCHITECTURE.md`).
    final nganSach = _Gia('ngan_sach', [
      soPhanTram('Tỉ lệ', 90.0, ten: 'Giáo dục'),
    ]);

    test('câu nêu đúng TÊN thì lọt, dù không có từ khoá của nhãn', () {
      expect(
        kiemNhan('Giáo dục đã dùng 90,0%.', [nganSach]),
        isTrue,
        reason: 'Đây là câu tự nhiên nhất cho câu hỏi "ngân sách nào sắp '
            'hết" — câu 3 của bảng đo. Trước chặng 4a nó bị chặn vì thiếu '
            '"tỉ" và "lệ", nên mô hình phải trả lời bằng con số trần.',
      );
    });

    test('câu chỉ nêu NHÃN của một mục CÓ TÊN thì bị chặn', () {
      expect(
        kiemNhan('Tỉ lệ là 90,0%.', [nganSach]),
        isFalse,
        reason: 'Ca này từng kỳ vọng `true` (lát 4a bản đầu chấp nhận nhãn '
            'HOẶC tên). Phép đo máy thật 2026-09-23 lật nó: gói mang nhiều '
            'mục cùng nhãn — bốn ngân sách cùng `Tỉ lệ`, các ví cùng `Số dư` '
            '— nên một câu chỉ nhắc nhãn KHÔNG nói được nó đang nói về cái '
            'nào. Chính lỗ ấy để lọt "Số ví đang âm: -100.000 đ", câu mà bản '
            'trước lát 4a vẫn chặn được.',
      );
    });

    test('câu bịa nhãn VẪN bị chặn — vế tên không mở toang lớp chắn', () {
      expect(
        kiemNhan('Dự báo tiết kiệm là 90,0%.', [nganSach]),
        isFalse,
        reason: 'Không chứa đủ từ khoá của "Tỉ lệ" lẫn của "Giáo dục". Đây '
            'chính là lớp chắn việc số 1 dựng ra; nới quá tay là phá nó.',
      );
    });

    test('tên cũng so theo ÂM TIẾT, không theo chuỗi con', () {
      final g = _Gia('vi', [soTien('Số dư', 100000, ten: 'Ví A')]);
      expect(
        kiemNhan('Vía của bạn là 100.000 đ.', [g]),
        isFalse,
        reason: '"vía" chứa "ví" nhưng không phải chữ "ví" — cùng luật đã '
            'chặn "chiều"/"chi" ở nhóm trên.',
      );
    });

    test('ten null thì luật cũ nguyên vẹn', () {
      expect(kiemNhan('Tổng chi là 2.141.000 đ.', [phanTich]), isTrue);
      expect(kiemNhan('Tổng thu là 2.141.000 đ.', [phanTich]), isFalse);
    });

    test('⭐ mục CÓ TÊN đòi câu nêu TÊN — nhãn đúng thôi chưa đủ', () {
      // Hồi quy đo được trên máy thật 2026-09-23: gói ví mang
      // `test · Đang âm: -100.000 đ`, và mô hình sinh *"Số ví đang âm:
      // -100.000 đ"* — chứa đủ từ khoá của nhãn ("đang", "âm") nên lọt, dù
      // câu SAI NGHĨA: số ví là 1, không phải -100.000 đ. Trước lát 4a câu
      // ấy bị chặn; nhãn mới làm nó lọt.
      final vi = _Gia('vi', [soTien('Đang âm', -100000, ten: 'test')]);
      expect(
        kiemNhan('Số ví đang âm: -100.000 đ.', [vi]),
        isFalse,
        reason: 'Con số thuộc về MỘT ví có tên; câu không nêu tên ấy thì '
            'không có gì buộc nó nói về đúng ví đó.',
      );
      expect(kiemNhan('Ví test đang âm -100.000 đ.', [vi]), isTrue);
    });

    group('tên có chữ số hoặc dấu câu (bước 1c)', () {
      test('⭐ mục có tên mang chữ số: câu nêu đúng tên thì qua', () {
        final g = _Gia(
            'tra_cuu', [soTien('Số tiền', 50000, ten: 'Kiem thu hoa don 123')]);
        expect(
          kiemNhan('Hoá đơn Kiem thu hoa don 123 chưa trả 50.000 đ.', [g]),
          isTrue,
          reason: 'Hai chỗ cùng hỏng: "123" bị trích như một con số không khớp '
              'nhãn nào, và phép tách âm tiết của câu bỏ chữ số nên "123" của '
              'tên không bao giờ có mặt — câu đúng bị chặn ở cả hai vế.',
        );
      });

      test('tên có dấu câu: tên và câu tách âm tiết bằng CÙNG một phép', () {
        final g =
            _Gia('tra_cuu', [soTien('Số tiền', 300000, ten: 'Điện/Nước')]);
        expect(
          kiemNhan('Điện/Nước chưa trả 300.000 đ.', [g]),
          isTrue,
          reason: 'Tên tách theo khoảng trắng ra "điện/nước", câu tách theo mọi '
              'ký tự không phải chữ ra "điện" và "nước" — hai phép khác nhau '
              'thì tên có dấu gạch không bao giờ khớp.',
        );
      });

      test('mục có tên mang chữ số: câu KHÔNG nêu tên vẫn bị chặn', () {
        final g =
            _Gia('tra_cuu', [soTien('Số tiền', 50000, ten: 'Tiền nhà T9')]);
        expect(
          kiemNhan('Hoá đơn chưa trả 50.000 đ.', [g]),
          isFalse,
          reason: 'Luật 4a giữ nguyên: số thuộc một đối tượng có tên thì câu '
              'phải nêu tên ấy.',
        );
      });

      test('nêu thiếu chữ số của tên thì chưa phải nêu tên', () {
        final g =
            _Gia('tra_cuu', [soTien('Số tiền', 50000, ten: 'Tiền nhà T9')]);
        expect(
          kiemNhan('Tiền nhà chưa trả 50.000 đ.', [g]),
          isFalse,
          reason: '"Tiền nhà" và "Tiền nhà T9" có thể là hai hoá đơn khác nhau '
              '— chữ số là một phần của tên, bỏ nó đi là nói về đối tượng khác.',
        );
      });
    });

    test('mục có tên vẫn lọt khi một mục KHÔNG tên cùng giá trị khớp nhãn',
        () {
      // Câu 3 của bảng đo: 90,0% vừa là `Giáo dục · Tỉ lệ` của gói ngân sách,
      // vừa là `Ngân sách căng nhất` của gói trang chủ — mục sau không có tên
      // nên vế nhãn vẫn dùng được, và câu đúng không bị siết oan.
      final ns = _Gia('ngan_sach', [soPhanTram('Tỉ lệ', 90.0, ten: 'Giáo dục')]);
      final tc = _Gia('trang_chu', [soPhanTram('Ngân sách căng nhất', 90.0)]);
      expect(
        kiemNhan('Ngân sách căng nhất là 90,0%.', [ns, tc]),
        isTrue,
      );
    });
  });

  group('nhãn có TỪ ĐỒNG NGHĨA — bẫy 4.47 (cổng D lần 4–5, 2026-09-24)', () {
    // Đúng tổng hợp của tim_giao_dich cho câu C8: nhãn chính "Số giao dịch",
    // mô hình khi thì nói "khoản", khi thì nói "giao dịch".
    final giaoDich = _Gia('tra_cuu', [
      soDem('Số giao dịch', 2, nhanKhac: const ['Số khoản']),
      soTien('Tổng thu', 14000000),
    ]);

    test('⭐ câu dùng nhãn THAY THẾ ("2 khoản thu") qua', () {
      expect(kiemNhan('Có 2 khoản thu trong năm nay.', [giaoDich]), isTrue,
          reason: 'C8 lần 5: nhãn "Số giao dịch" chặn câu đúng "Có 2 khoản thu…"; '
              'nhãn cũ "Số khoản" thì chặn "6 giao dịch" (C5 lần 4) — cần cả hai');
    });

    test('câu dùng nhãn CHÍNH ("2 giao dịch") vẫn qua', () {
      expect(kiemNhan('Bạn có 2 giao dịch.', [giaoDich]), isTrue);
    });

    test('đối chứng: không có nhãn thay thế thì "2 khoản" bị chặn', () {
      final khong = _Gia('tra_cuu', [soDem('Số giao dịch', 2)]);
      expect(kiemNhan('Có 2 khoản.', [khong]), isFalse);
    });

    test('nhãn thay thế KHÔNG mở cửa cho chữ khác ("2 hoá đơn")', () {
      expect(kiemNhan('Có 2 hoá đơn.', [giaoDich]), isFalse);
    });
  });

  // Cổng D lần 4–6 (mục 9.20–9.23), câu C10 "tháng này tôi nhận được những khoản
  // thu nào": mô hình gọi tổng kết rồi viết "Các khoản thu bao gồm: Cho vay
  // (800.000 đ)…" — 800.000 là CHI của Cho vay. Mục có tên chỉ bị đòi nêu tên
  // (phép nới 4a), nên số thật + tên thật gán vào nhãn NGƯỢC vẫn lọt.
  group('nhãn XUNG ĐỘT của mục có tên — bẫy 4.42 (cổng D C10, 2026-09-24)', () {
    // Đúng gói tổng kết của C10: hàng danh mục nhãn "Chi", xung đột với "Thu".
    final tongKet = _Gia('tra_cuu', [
      soTien('Tổng chi', 2141000),
      soTien('Tổng thu', 15135000),
      soTien('Chi', 800000, ten: 'Cho vay', nhanXungDot: const ['Thu']),
      soTien('Chi', 500000, ten: 'Chưa phân loại', nhanXungDot: const ['Thu']),
    ]);

    test('⭐ câu C10 đo trên Realme 2026-09-24 bị chặn: gán số CHI của Cho vay làm "khoản thu"', () {
      expect(
        kiemNhan(
          'Trong tháng này, tổng thu là 15.135.000 đ. Các khoản thu bao gồm: '
          'Cho vay (800.000 đ), Chưa phân loại (500.000 đ).',
          [tongKet],
        ),
        isFalse,
        reason: 'Nguyên văn C10 lần 4, 5, 6: câu có "thu" (nhãn xung đột) mà '
            'không có "chi" (nhãn của con số) — mệnh đề sai dù số và tên thật.',
      );
    });

    test('câu đúng A8 nêu tên VÀ có chữ "chi" thì qua', () {
      expect(
        kiemNhan(
          'Trong tháng này, tổng chi là 2.141.000 đ. Các danh mục chi lớn nhất '
          'là: Cho vay (800.000 đ), Chưa phân loại (500.000 đ).',
          [tongKet],
        ),
        isTrue,
      );
    });

    test('câu chỉ nêu TÊN, không nhắc nhãn nào, vẫn qua — phép nới 4a nguyên vẹn', () {
      expect(kiemNhan('Cho vay: 800.000 đ.', [tongKet]), isTrue,
          reason: 'xung đột chỉ chặn khi câu GÁN nhãn ngược, không đòi nhãn chính');
    });

    test('câu có cả hai nhãn (chi lẫn thu) thì qua — lớp chắn từ vựng không định vị', () {
      expect(
        kiemNhan(
          'Tổng thu 15.135.000 đ; khoản chi lớn nhất là Cho vay 800.000 đ.',
          [tongKet],
        ),
        isTrue,
      );
    });

    test('nhãn THAY THẾ cũng đủ để không bị coi là gán ngược', () {
      final g = _Gia('tra_cuu', [
        soTien('Chi', 800000,
            ten: 'Cho vay', nhanKhac: const ['Tiêu'], nhanXungDot: const ['Thu']),
        soTien('Tổng thu', 1),
      ]);
      expect(kiemNhan('Khoản thu 1 đ; đã tiêu cho Cho vay 800.000 đ.', [g]), isTrue);
    });

    test('đối chứng: không khai xung đột thì câu C10 vẫn lọt (đúng luật 4a cũ)', () {
      final khong = _Gia('tra_cuu', [
        soTien('Tổng thu', 15135000),
        soTien('Chi', 800000, ten: 'Cho vay'),
      ]);
      expect(
        kiemNhan('Tổng thu 15.135.000 đ. Các khoản thu: Cho vay (800.000 đ).', [khong]),
        isTrue,
      );
    });

    test('mục KHÔNG tên không đổi: vẫn phải nêu đúng nhãn', () {
      expect(kiemNhan('Tổng thu là 2.141.000 đ.', [tongKet]), isFalse);
    });
  });

  test('mục NGÀY của một hàng mang tên → câu nêu ngày phải nêu tên (bước 2)', () {
    final g = _Gia('tra_cuu', [
      soNgayThang('Ngày', DateTime(2026, 9, 4), ten: 'Ăn uống', now: DateTime(2026, 9, 23)),
    ]);
    expect(kiemNhan('Ăn uống ngày 04/09.', [g]), isTrue);
    expect(kiemNhan('Có một khoản ngày 04/09.', [g]), isFalse,
        reason: 'luật 4a không đổi: mục có tên đòi câu nêu tên');
  });
}
