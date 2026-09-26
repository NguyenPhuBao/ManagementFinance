// test/features/ai_edge/domain/slm_prompt_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/ai_edge/domain/slm_prompt.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';

class _GoiGia extends GoiSo {
  @override
  final String man;
  @override
  final List<SoLieu> soLieu;

  /// Mức của hệ luật — prompt phải chở nó xuống (dòng MỨC), nên lớp giả phải
  /// đặt được. Mặc định `binhThuong` để mọi ca cũ dựng không đổi.
  final MucNhanXet muc;
  final String cauMau;
  _GoiGia(this.man, this.soLieu,
      [this.muc = MucNhanXet.binhThuong, this.cauMau = 'mẫu']);
  @override
  bool get thieuDuLieu => muc == MucNhanXet.thieuDuLieu;
  @override
  NhanXet mauCau() => NhanXet(cau: cauMau, theSoLieu: soLieu, muc: muc);
  @override
  String get dauVan => 'gia';
}

void main() {
  final goi = _GoiGia('ngan_sach', [
    soTien('Đã chi', 45000),
    soPhanTram('Tỉ lệ', 90),
    soNgay('Còn', 11),
  ]);

  test('prompt chở ĐÚNG chuỗi đã định dạng của gói, không phải số thô', () {
    // `SoLieu.chuoi` là ba thứ cùng lúc: thẻ người dùng thấy, tập cho phép của
    // bộ kiểm số, và phần bơm vào prompt. Bơm `soTho` (45000.0) thì mô hình sẽ
    // chép lại "45000" — một chuỗi mà `kiemSo` vẫn cho qua nhưng người dùng
    // đọc là sai định dạng tiền của app.
    final p = promptCauTheoMan(goi);
    expect(p, contains('Đã chi: 45.000 đ'));
    expect(p, contains('Tỉ lệ: 90,0%'));
    expect(p, contains('Còn: 11 ngày'));
    expect(p, isNot(contains('45000')));
  });

  test('có prompt hệ thống và HAI ví dụ few-shot', () {
    final p = promptCauTheoMan(goi);
    expect(p, contains(kPromptHeThong));
    expect('Ví dụ'.allMatches(p).length, 2,
        reason: 'Spec mục 4.3 chốt hai ví dụ. Một ví dụ thì mô hình hay bịa '
            'thêm câu dẫn; ba thì tốn token vô ích ở trần 1024.');
  });

  test('⚠️ ví dụ few-shot KHÔNG được chứa số ngoài gói của chính nó', () {
    // Bẫy 4.1: bộ kiểm số không phân biệt số trang trí với số bịa. Nếu ví dụ
    // dạy mô hình nói một con số không có trong gói thật, mọi câu sinh ra đều
    // bị `kiemSo` chặn và P3 rơi về mẫu câu — im lặng, trông như mô hình kém.
    final p = promptCauTheoMan(goi);
    // ⚠️ Mốc cắt là đầu câu CHỈ DẪN ("Viết MỘT câu…"), không phải 'Số liệu:'
    // cuối: chỉ dẫn đứng giữa ví dụ và số liệu thật, mang "dưới 40 từ", và
    // con số 40 ấy từng chỉ qua được vì tình cờ là chuỗi con của "400.000"
    // (lộ ra 2026-09-22 khi bản hỏi đáp mang "dưới 80 từ"). Và bỏ dòng nhãn:
    // số thứ tự của ví dụ không phải số liệu.
    final khoiViDu = p
        .substring(p.indexOf('Ví dụ 1'), p.lastIndexOf('Viết MỘT câu'))
        .split('\n')
        .where((l) => !l.startsWith('Ví dụ '))
        .join('\n');
    for (final m in RegExp(r'\d[\d.,]*').allMatches(khoiViDu)) {
      expect(khoiViDu.split(m.group(0)!).length - 1, greaterThanOrEqualTo(2),
          reason: 'Số "${m.group(0)}" trong ví dụ phải xuất hiện ở CẢ phần số '
              'liệu lẫn phần câu của chính ví dụ ấy — nếu không, ví dụ đang '
              'dạy mô hình bịa.');
    }
  });

  test('prompt mang dòng MỨC đúng với mức của hệ luật', () {
    final canh = _GoiGia('ngan_sach', [soPhanTram('Tỉ lệ', 90)], MucNhanXet.canhBao);
    expect(promptCauTheoMan(canh), contains('MỨC: CẢNH BÁO'));
    expect(promptCauTheoMan(goi), contains('MỨC: BÌNH THƯỜNG'));
  });

  test('hỏi đáp: chở câu hỏi và gói của MỌI màn', () {
    final p = promptHoiDap('Tháng này tôi tiêu nhiều không?', [
      goi,
      _GoiGia('muc_tieu', [soPhanTram('Tiến độ', 55)]),
    ]);
    expect(p, contains('Tháng này tôi tiêu nhiều không?'));
    expect(p, contains('Đã chi: 45.000 đ'));
    expect(p, contains('Tiến độ: 55,0%'));
  });

  group('hỏi đáp có bộ few-shot RIÊNG (việc số 1, 2026-09-22)', () {
    // Trước đó `promptHoiDap` dùng chung hai ví dụ nhận xét với
    // `promptCauTheoMan`: không ví dụ hỏi–đáp nào, không ví dụ "không có dữ
    // liệu" nào — một trong bốn nguyên nhân đo được của "AI trả lời sai".
    final p = promptHoiDap('Tháng này tôi tiêu nhiều không?', [goi]);

    test('BỐN ví dụ, mỗi ví dụ có Câu hỏi và Trả lời', () {
      // Ví dụ thứ tư thêm ở chặng 4a: dạng "cái nào", đáp bằng TÊN. Bốn câu
      // nhóm A của bảng đo (mục 5.6 `AI_AGENT_ARCHITECTURE.md`) đều là dạng
      // ấy, và E2B không tự suy ra được từ chỉ dẫn suông.
      expect('Ví dụ'.allMatches(p).length, 4);
      expect('Câu hỏi:'.allMatches(p).length, 5,
          reason: 'bốn của ví dụ + một của câu hỏi thật');
      expect('Trả lời:'.allMatches(p).length, 5);
    });

    test('⭐ có ví dụ dạng "cái NÀO" — đáp bằng tên, không bằng con số trần',
        () {
      final viDu = p.substring(p.indexOf('Ví dụ 1'), p.lastIndexOf('Số liệu:'));
      expect(viDu.toLowerCase(), contains('nào'),
          reason: 'Câu 3, 8, 13, 15 của bảng đo đều hỏi "cái nào" và đều nhận '
              'về một con số trần — "Ngân sách căng nhất là 90,0%" thay vì '
              '"Giáo dục".');
      expect(viDu, contains('Giáo dục'),
          reason: 'câu trả lời mẫu phải NÊU TÊN, đó là cả điểm của ví dụ này');
    });

    test('⭐ có ví dụ hỏi thứ KHÔNG CÓ số liệu → trả lời không con số nào', () {
      // Đây là hành vi điểm 4 cổng A đòi. Ví dụ phải cho mô hình thấy một câu
      // từ chối trông ra sao — E2B không tự suy ra được từ chỉ dẫn suông.
      final viDu = p.substring(p.indexOf('Ví dụ 1'), p.lastIndexOf('Số liệu:'));
      final traLoi = RegExp(r'Trả lời: (.*)')
          .allMatches(viDu)
          .map((m) => m.group(1)!)
          .toList();
      expect(traLoi, hasLength(4));
      expect(
        traLoi.where((c) => !RegExp(r'\d').hasMatch(c)),
        isNotEmpty,
        reason: 'phải có ít nhất một câu trả lời không chứa chữ số nào',
      );
    });

    test('⚠️ ví dụ hỏi đáp cũng KHÔNG được chứa số ngoài gói của chính nó', () {
      // Mốc cắt là đầu câu chỉ dẫn (mang "dưới 80 từ") — cùng lý do với ca
      // của prompt nhận xét ở trên.
      final khoiViDu = p
          .substring(p.indexOf('Ví dụ 1'), p.lastIndexOf('Trả lời câu hỏi'))
          .split('\n')
          .where((l) => !l.startsWith('Ví dụ '))
          .join('\n');
      for (final m in RegExp(r'\d[\d.,]*').allMatches(khoiViDu)) {
        expect(khoiViDu.split(m.group(0)!).length - 1, greaterThanOrEqualTo(2),
            reason: 'Số "${m.group(0)}" phải có ở cả số liệu lẫn câu trả lời '
                'của chính ví dụ ấy');
      }
    });

    test('dòng số liệu nêu TÊN đối tượng khi có (chặng 4a)', () {
      final pTen = promptHoiDap('ngan sach nao sap het', [
        _GoiGia('ngan_sach', [soPhanTram('Tỉ lệ', 90.0, ten: 'Giáo dục')]),
      ]);
      expect(pTen, contains('Giáo dục · Tỉ lệ: 90,0%'),
          reason: 'Mô hình chỉ nói được tên nếu tên có trong prompt.');
    });

    test('không có tên thì dòng số liệu giữ nguyên dạng cũ', () {
      final pKhongTen = promptHoiDap('thang nay chi bao nhieu', [
        _GoiGia('phan_tich', [soTien('Tổng chi', 2141000)]),
      ]);
      expect(pKhongTen, contains('Tổng chi: 2.141.000 đ'));
      expect(pKhongTen, isNot(contains('null')),
          reason: '`ten` null là ca THƯỜNG — không được rò chữ "null" ra '
              'prompt, thứ mô hình sẽ chép lại nguyên vào câu trả lời.');
    });

    test('câu trả lời trong ví dụ CHÉP NGUYÊN NHÃN — dạy mô hình gọi đúng tên số',
        () {
      // Lý do của `kiemNhan`: mô hình gắn nhãn của câu hỏi vào con số gần
      // nghĩa nhất. Ví dụ phải làm mẫu ngược lại.
      expect(p, contains('dùng đúng nhãn'));
    });

    test('số liệu có TIÊU ĐỀ theo màn để nhãn trùng tên không lẫn nhau', () {
      // `Còn thiếu` có ở cả ngân sách lẫn mục tiêu, `Tiến độ` ở cả mục tiêu
      // lẫn hoá đơn, `Còn` ở ngân sách lẫn mục tiêu.
      final p2 = promptHoiDap('?', [
        goi,
        _GoiGia('muc_tieu', [soPhanTram('Tiến độ', 55)]),
      ]);
      expect(p2, contains('== Ngân sách =='));
      expect(p2, contains('== Mục tiêu =='));
      expect(p2.indexOf('== Ngân sách =='), lessThan(p2.indexOf('Đã chi:')));
      expect(p2.indexOf('== Mục tiêu =='), lessThan(p2.indexOf('Tiến độ:')));
    });

    test('gói THIẾU DỮ LIỆU in đúng câu mẫu của nó thay vì im lặng', () {
      // Im lặng là để mô hình lấy số của gói khác trả lời thay. Câu mẫu
      // ("Chưa có mục tiêu nào đang theo đuổi.") cho nó thứ để chép.
      final p2 = promptHoiDap('Mục tiêu của tôi sao rồi?', [
        goi,
        _GoiGia('muc_tieu', const [], MucNhanXet.thieuDuLieu,
            'Chưa có mục tiêu nào đang theo đuổi.'),
      ]);
      expect(p2, contains('== Mục tiêu ==\nChưa có mục tiêu nào đang theo đuổi.'));
    });

    test('prompt nhận xét theo màn KHÔNG đổi — vẫn hai ví dụ, không tiêu đề', () {
      final p1 = promptCauTheoMan(goi);
      expect('Ví dụ'.allMatches(p1).length, 2);
      expect(p1, isNot(contains('==')));
    });
  });

  test('gói rỗng vẫn cho prompt hợp lệ, không ném', () {
    expect(() => promptCauTheoMan(_GoiGia('trang_chu', const [])),
        returnsNormally);
  });

  group('kPromptHeThongCongCu (bậc tool, chặng 4b)', () {
    test('bảo gọi công cụ TRƯỚC khi trả lời và chép nguyên chuỗi số', () {
      expect(kPromptHeThongCongCu, contains('công cụ'));
      expect(kPromptHeThongCongCu, contains('TRƯỚC'));
      expect(kPromptHeThongCongCu, contains('chép nguyên'));
    });
    test('bước 2: nêu mục tiêu, gợi ý hạn mức, giao dịch; dặn chép nguyên NGÀY tháng', () {
      expect(kPromptHeThongCongCu, contains('mục tiêu'));
      expect(kPromptHeThongCongCu, contains('gợi ý hạn mức'));
      expect(kPromptHeThongCongCu, contains('từng giao dịch'));
      expect(kPromptHeThongCongCu, contains('ngày tháng'));
    });
    test('không mang con số nào ngoài giới hạn độ dài', () {
      final so = RegExp(r'\d+')
          .allMatches(kPromptHeThongCongCu)
          .map((m) => m.group(0))
          .toList();
      expect(so, ['60'],
          reason: 'Một số khác trong chỉ dẫn hệ thống là một số mô hình có thể '
              'chép vào câu — mà nó không có trong gói nào.');
    });
    test('bước 2b: dặn gọi lại khi công cụ trả "loi" (cổng D lần 1: không lượt nào gọi lại)', () {
      expect(kPromptHeThongCongCu, contains('"loi"'));
      expect(kPromptHeThongCongCu, contains('gọi lại ngay'));
    });
    // Cổng D lần 4–8: sáu câu có ĐIỀU KIỆN (số tiền, khoản thu, ví, danh mục, khoản
    // lớn nhất) gọi tổng kết bốn lần liền dù mô tả chéo (2b) đã dặn — "không
    // few-shot ở bậc tool" (spec 4b §3.7) là giả định chưa từng đo. Ví dụ định
    // tuyến: câu hỏi kiểu nào → tool nào, tham số nào; KHÔNG chữ số.
    test('⭐ ví dụ ĐỊNH TUYẾN (lần đo 9): nêu cả hai tool cạnh tranh và các kiểu câu có điều kiện', () {
      expect(kPromptHeThongCongCu, contains('Ví dụ'));
      expect(kPromptHeThongCongCu, contains(kTenCongCuGiaoDich));
      expect(kPromptHeThongCongCu, contains(kTenCongCuTongKet));
      for (final dieuKien in ['số tiền', 'khoản thu', 'ví', 'danh mục', 'lớn nhất']) {
        expect(kPromptHeThongCongCu, contains(dieuKien), reason: dieuKien);
      }
      expect(kPromptHeThongCongCu, contains('chieu'));
      expect(kPromptHeThongCongCu, contains('so_tien_tu'));
      expect(kPromptHeThongCongCu.indexOf(kTenCongCuGiaoDich),
          lessThan(kPromptHeThongCongCu.indexOf(kTenCongCuTongKet)),
          reason: 'ví dụ về tool liệt kê đứng trước — mô hình đọc từ trên xuống');
    });
    // Lần đo 9: tool 18/20 nhưng tham số 9/20 — ba họ lỗi: thiếu chieu (C1 C5 C6),
    // tên danh mục / ví nhét vào tu_khoa (C12 C14 C19), ngưỡng và kỳ (C7 "nửa triệu"
    // → một triệu, C9 thiếu sàn, C15 hom_nay cho "lần gần nhất").
    test('⭐ ví dụ ĐIỀN THAM SỐ (lần đo 10): chiều, tên vào đúng ô, hai ngưỡng, kỳ moi_luc', () {
      expect(kPromptHeThongCongCu, contains('Điền tham số'));
      for (final tu in [
        'chieu=khoan_chi', 'chieu=khoan_thu', 'chuyen_vi',
        'danh_muc', 'không', 'tu_khoa',
        'so_tien_tu', 'so_tien_den', 'nửa triệu', 'năm trăm nghìn',
        'moi_luc', 'sap_xep=moi_nhat', 'hom_nay',
      ]) {
        expect(kPromptHeThongCongCu, contains(tu), reason: tu);
      }
      expect(kPromptHeThongCongCu.indexOf('Điền tham số'),
          greaterThan(kPromptHeThongCongCu.indexOf('Ví dụ chọn công cụ')),
          reason: 'chọn tool trước, điền tham số sau');
    });
  });
}
