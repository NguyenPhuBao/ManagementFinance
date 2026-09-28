/// Bộ chỉnh tham số `tim_giao_dich` theo CÂU HỎI — tất định, chạy trước khi tool
/// kiểm và tra cứu (cổng D lần 9–11: tham số 13/20, sáu câu hỏng theo bốn họ mà
/// ví dụ trong lời hệ thống không chữa được — mục 9.26–9.27 `AI_EDGE_FEATURE.md`).
///
/// Mỗi ca là đúng câu hỏi và args đã đo trên Realme.
library;

import 'package:flowmoney/features/ai_edge/domain/chinh_tham_so.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_tong_quan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const danhMuc = ['Ăn uống', 'Di chuyển', 'Mua sắm', 'Giáo dục', 'Cho vay', 'Chi khác', 'test1'];
  const vi = ['Tiền mặt', 'Tiết kiệm', 'test'];
  final now = DateTime(2026, 9, 27, 10);

  Map<String, dynamic> chinh(String cauHoi, Map<String, dynamic> args) =>
      chinhThamSoTimGiaoDich(cauHoi, args, tenDanhMuc: danhMuc, tenVi: vi, now: now).args;

  group('1. tách hai tên trong một ô (C14, C19)', () {
    test('⭐ C14: "mua sam tu vi tien mat" trong danh_muc → danh_muc Mua sắm, vi Tiền mặt', () {
      final r = chinh('thang nay toi chi gi cho mua sam tu vi tien mat', {
        'ky': 'thang_nay', 'chieu': 'khoan_chi', 'danh_muc': 'mua sam tu vi tien mat',
      });
      expect(r['danh_muc'], 'Mua sắm');
      expect(r['vi'], 'Tiền mặt');
    });

    test('⭐ C19: "giao duc tu vi test" → danh_muc Giáo dục, vi test; và không có chữ kỳ → moi_luc', () {
      final r = chinh('cac khoan chi cho giao duc tu vi test', {
        'ky': 'thang_nay', 'chieu': 'khoan_chi', 'danh_muc': 'giao duc tu vi test',
      });
      expect(r['danh_muc'], 'Giáo dục');
      expect(r['vi'], 'test');
      expect(r['ky'], 'moi_luc');
    });

    test('cụm ở tu_khoa cũng được tách; tu_khoa được xoá khi đã giải hết', () {
      final r = chinh('thang nay toi chi gi cho mua sam tu vi tien mat', {
        'ky': 'thang_nay', 'chieu': 'khoan_chi', 'tu_khoa': 'mua sam tu vi tien mat',
      });
      expect(r['danh_muc'], 'Mua sắm');
      expect(r['vi'], 'Tiền mặt');
      expect(r['tu_khoa'], isNull);
    });

    test('tên có ở CẢ hai danh sách: chữ "vi" đứng trước quyết định', () {
      final r = chinh('cac khoan chi cho test1 tu vi test', {
        'ky': 'moi_luc', 'danh_muc': 'test1 tu vi test',
      });
      expect(r['danh_muc'], 'test1');
      expect(r['vi'], 'test');
    });

    test('giá trị đã khớp tên thật thì không đụng', () {
      final r = chinh('liet ke cac khoan an uong thang nay', {
        'ky': 'thang_nay', 'chieu': 'khoan_chi', 'danh_muc': 'an uong',
      });
      expect(r['danh_muc'], 'an uong');
      expect(r.containsKey('vi'), isFalse);
    });

    test('giá trị không chứa tên thật nào thì để nguyên cho tool từ chối', () {
      final r = chinh('cac khoan chi cho danh muc abc thang nay', {
        'ky': 'thang_nay', 'danh_muc': 'abc',
      });
      expect(r['danh_muc'], 'abc');
    });
  });

  group('2. danh mục nêu trong câu hỏi (C15)', () {
    test('⭐ C15: "chi cho di chuyen" → danh_muc Di chuyển, chieu khoan_chi (không phải chuyển ví), moi_nhat', () {
      final r = chinh('lan gan nhat toi chi cho di chuyen la ngay nao', {
        'ky': 'moi_luc', 'chieu': 'chuyen_vi', 'sap_xep': 'moi_nhat',
      });
      expect(r['danh_muc'], 'Di chuyển');
      expect(r['chieu'], 'khoan_chi');
      expect(r['sap_xep'], 'moi_nhat');
    });

    test('câu hỏi có chữ chuyển tiền thật thì chieu chuyen_vi giữ nguyên', () {
      final r = chinh('thang nay toi da chuyen tien sang vi tiet kiem nhung lan nao', {
        'ky': 'thang_nay', 'chieu': 'chuyen_vi', 'vi': 'tiet kiem',
      });
      expect(r['chieu'], 'chuyen_vi');
      expect(r.containsKey('danh_muc'), isFalse);
    });

    test('⭐ C17 lần 13: tên danh mục trùng TỪ KHOÁ ghi chú ("hoa don" ↔ danh mục Hóa đơn) thì KHÔNG điền danh_muc', () {
      final r = chinhThamSoTimGiaoDich(
        'tim cac giao dich co ghi chu hoa don',
        {'ky': 'thang_nay', 'tu_khoa': 'hoa don'},
        tenDanhMuc: [...danhMuc, 'Hóa đơn'],
        tenVi: vi, now: now,
      ).args;
      expect(r.containsKey('danh_muc'), isFalse,
          reason: 'Trên Realme luật 2 điền danh_muc=Hóa đơn cạnh tu_khoa "hoa don" → 0 khoản, '
              'câu đúng của lần 9 thành mẫu câu lệch.');
      expect(r['tu_khoa'], 'hoa don');
      expect(r['ky'], 'moi_luc');
    });

    test('⭐ C17 lần 14 (OnePlus): mô hình KHÔNG điền tu_khoa — tên đứng sau "ghi chú" trong câu hỏi vẫn không phải danh mục', () {
      final r = chinhThamSoTimGiaoDich(
        'tim cac giao dich co ghi chu hoa don',
        {'ky': 'moi_luc'},
        tenDanhMuc: [...danhMuc, 'Hóa đơn'],
        tenVi: vi, now: now,
      ).args;
      expect(r.containsKey('danh_muc'), isFalse,
          reason: 'vế "trùng tu_khoa" không cứu được khi tu_khoa trống; câu hỏi nói "ghi chú X" '
              'thì X là chữ trong ghi chú');
      expect(r['tu_khoa'], 'hoa don', reason: 'chữ sau "ghi chú" đi vào tu_khoa');
    });

    test('danh_muc mô hình đã điền đúng thì không đè bằng tên khác trong câu', () {
      final r = chinh('cac khoan an uong va di chuyen', {
        'ky': 'thang_nay', 'danh_muc': 'an uong',
      });
      expect(r['danh_muc'], 'an uong');
    });
  });

  group('3. chiều thiếu (C7)', () {
    test('câu nói "khoan chi" mà chieu trống → khoan_chi', () {
      final r = chinh('cac khoan chi hon nua trieu trong quy nay', {'ky': 'quy_nay'});
      expect(r['chieu'], 'khoan_chi');
    });
    test('câu nói "nhan duoc" / "khoan thu" → khoan_thu', () {
      expect(chinh('thang nay toi nhan duoc nhung khoan thu nao', {'ky': 'thang_nay'})['chieu'],
          'khoan_thu');
    });
    test('câu không nói chiều thì để trống', () {
      expect(chinh('hom nay toi co giao dich nao khong', {'ky': 'hom_nay'}).containsKey('chieu'),
          isFalse);
    });
    test('⭐ C20 lần 12: "tiêu" trong "mục tiêu" KHÔNG phải động từ chi — chieu để trống', () {
      final r = chinh('lan cuoi toi nap tien cho muc tieu muaxe la ngay nao', {
        'ky': 'moi_luc', 'tu_khoa': 'muaxe',
      });
      expect(r.containsKey('chieu'), isFalse,
          reason: 'Trên Realme bộ chỉnh điền khoan_chi và tool bỏ mất khoản chuyển ví 08/09 '
              '— khoản nạp mục tiêu là chuyển ví, câu hỏi không nói chi hay thu.');
      expect(r['sap_xep'], 'moi_nhat');
    });
    test('chieu mô hình đã điền (đúng hay sai) không bị đè — trừ luật 2', () {
      expect(chinh('cac khoan chi hon nua trieu', {'ky': 'quy_nay', 'chieu': 'khoan_thu'})['chieu'],
          'khoan_thu');
    });
  });

  group('4. ngưỡng từ câu hỏi thắng tham số mô hình (C7, C9)', () {
    test('⭐ C7: "hon nua trieu" → so_tien_tu 500000, đè 1000000 của mô hình', () {
      final r = chinh('cac khoan chi hon nua trieu trong quy nay', {
        'ky': 'quy_nay', 'so_tien_tu': 1000000,
      });
      expect(r['so_tien_tu'], 500000);
      expect(r.containsKey('so_tien_den'), isFalse);
    });

    test('⭐ C9: "tu 200k den 1 trieu" → cả hai ngưỡng', () {
      final r = chinh('liet ke cac khoan chi tu 200k den 1 trieu thang nay', {
        'ky': 'thang_nay', 'chieu': 'khoan_chi', 'so_tien_den': 1000000, 'tu_khoa': '',
      });
      expect(r['so_tien_tu'], 200000);
      expect(r['so_tien_den'], 1000000);
    });

    test('"tren 500k", "duoi 100 nghin", "tu 5 trieu tro len" — có dấu lẫn không dấu', () {
      expect(chinh('thang nay toi tieu gi tren 500k', {'ky': 'thang_nay'})['so_tien_tu'], 500000);
      expect(chinh('tuần này có khoản chi nào dưới 100 nghìn không', {'ky': 'tuan_nay'})['so_tien_den'],
          100000);
      expect(chinh('năm nay tôi có khoản thu nào từ 5 triệu trở lên không', {'ky': 'nam_nay'})['so_tien_tu'],
          5000000);
      expect(chinh('khoản chi hơn một triệu rưỡi', {'ky': 'thang_nay'})['so_tien_tu'], 1500000);
    });

    test('câu hỏi không có số tiền thì GỠ ngưỡng của mô hình (G2 cổng F — đảo luật 6 cũ cho so_tien_*)', () {
      // Trước 2026-09-28 ca này đòi GIỮ 300000 (luật 6 "không đụng thứ câu hỏi
      // không nói tới"). F2 cổng F đo được mặt trái: "từ 1/9 đến 15/9" → mô hình
      // điền từ 1 đ đến 15 đ, lượt rỗng. Người dùng chọn gỡ (G2).
      final r = chinh('khoan chi lon nhat thang nay la gi', {'ky': 'thang_nay', 'so_tien_tu': 300000});
      expect(r.containsKey('so_tien_tu'), isFalse);
    });

    test('số đứng riêng không kèm đơn vị hay chữ ngưỡng thì không phải ngưỡng ("5 khoan chi")', () {
      final r = chinh('5 khoan chi gan day nhat cua toi', {'ky': 'moi_luc'});
      expect(r.containsKey('so_tien_tu'), isFalse);
      expect(r.containsKey('so_tien_den'), isFalse);
    });
  });

  group('5. sắp xếp và kỳ (C20, C19)', () {
    test('⭐ C20: "lan cuoi" → sap_xep moi_nhat; ky moi_luc giữ', () {
      final r = chinh('lan cuoi toi nap tien cho muc tieu muaxe la ngay nao', {
        'ky': 'moi_luc', 'tu_khoa': 'muaxe',
      });
      expect(r['sap_xep'], 'moi_nhat');
      expect(r['ky'], 'moi_luc');
    });
    test('"gan day nhat" → moi_nhat; "lan gan nhat" với ky hom_nay → moi_luc', () {
      expect(chinh('5 khoan chi gan day nhat cua toi', {'ky': 'moi_luc'})['sap_xep'], 'moi_nhat');
      expect(chinh('lan gan nhat toi chi cho di chuyen la ngay nao', {'ky': 'hom_nay'})['ky'], 'moi_luc');
    });
    test('câu có chữ kỳ thì ky mô hình giữ nguyên', () {
      expect(chinh('tuan truoc toi da tieu nhung khoan nao', {'ky': 'tuan_truoc'})['ky'], 'tuan_truoc');
      expect(chinh('hom qua toi da chi nhung gi', {'ky': 'hom_qua'})['ky'], 'hom_qua');
    });
    test('⭐ E5 cổng E: "ke tu dau nam" LÀ chữ kỳ — ky nam_nay của mô hình giữ, không đổi moi_luc', () {
      expect(chinh('ke tu dau nam toi da chi cho giai tri tong cong bao nhieu', {'ky': 'nam_nay'})['ky'], 'nam_nay',
          reason: 'cổng E lần 1: bộ chỉnh ghi "câu hỏi không nêu kỳ → ky=moi_luc" cho câu này');
      expect(chinh('tu dau thang toi chi bao nhieu', {'ky': 'thang_nay'})['ky'], 'thang_nay');
    });
  });

  test('6. ghi chú nêu từng luật đã áp; không luật nào áp thì rỗng', () {
    final co = chinhThamSoTimGiaoDich(
      'cac khoan chi hon nua trieu trong quy nay',
      {'ky': 'quy_nay', 'so_tien_tu': 1000000},
      tenDanhMuc: danhMuc,
      tenVi: vi, now: now,
    );
    expect(co.ghiChu, isNotEmpty);
    final khong = chinhThamSoTimGiaoDich(
      'hom qua toi da chi nhung gi',
      {'ky': 'hom_qua', 'chieu': 'khoan_chi'},
      tenDanhMuc: danhMuc,
      tenVi: vi, now: now,
    );
    expect(khong.ghiChu, isEmpty);
    expect(khong.args, {'ky': 'hom_qua', 'chieu': 'khoan_chi'});
  });

  test('câu hỏi rỗng → không chỉnh gì, kể cả ky (tool gọi không kèm cauHoi giữ hành vi cũ)', () {
    final r = chinhThamSoTimGiaoDich('', {'ky': 'thang_nay', 'chieu': 'chuyen_vi'},
        tenDanhMuc: danhMuc, tenVi: vi, now: now);
    expect(r.ghiChu, isEmpty);
    expect(r.args, {'ky': 'thang_nay', 'chieu': 'chuyen_vi'});
  });
  group('7. chọn: nhiều nhất / ít nhất (E3 lần đo 15)', () {
    test('⭐ E3 "danh muc nao toi it tieu nhat trong thang" → chon it_nhat, gop danh_muc', () {
      final r = chinh('danh muc nao toi it tieu nhat trong thang', {'ky': 'thang_nay'});
      expect(r['chon'], 'it_nhat');
      expect(r['gop'], 'danh_muc');
    });
    test('"chi nhieu nhat vao danh muc nao" → nhieu_nhat + gop danh_muc; ghi đè giá trị mô hình', () {
      final r = chinh('thang nay toi chi nhieu nhat vao danh muc nao', {'ky': 'thang_nay', 'chon': 'it_nhat'});
      expect(r['chon'], 'nhieu_nhat');
      expect(r['gop'], 'danh_muc');
    });
    test('⚠️ "it nhat" đứng trước số tiền là NGƯỠNG (luật 4), không phải chọn', () {
      final r = chinh('cac khoan chi it nhat 200k thang nay', {'ky': 'thang_nay'});
      expect(r['so_tien_tu'], 200000);
      expect(r.containsKey('chon'), isFalse);
    });
    test('phản ví dụ: câu không có "nhất" thì không đặt chon', () {
      expect(chinh('thang nay toi chi bao nhieu', {'ky': 'thang_nay'}).containsKey('chon'), isFalse);
    });
    test('⭐ luật 10 — C9, C16 cổng E: mô hình điền chon mà câu không có "… nhất" → GỠ', () {
      final c9 = chinh('liet ke cac khoan chi tu 200k den 1 trieu thang nay',
          {'ky': 'thang_nay', 'chieu': 'khoan_chi', 'so_tien_den': 1000000, 'chon': 'nhieu_nhat'});
      expect(c9.containsKey('chon'), isFalse,
          reason: 'C9: chon thừa làm "liệt kê" còn một hàng — tụt so lần 13');
      expect(c9['so_tien_tu'], 200000);
      final c16 = chinh('5 khoan chi gan day nhat cua toi', {'ky': 'moi_luc', 'chieu': 'khoan_chi', 'chon': 'nhieu_nhat'});
      expect(c16.containsKey('chon'), isFalse, reason: 'C16: "gần đây nhất" là sắp xếp, không phải chọn');
      expect(c16['sap_xep'], 'moi_nhat');
    });
    test('luật 10 KHÔNG gỡ khi câu có "… nhất" thật (C18, E16)', () {
      expect(chinh('khoan chi lon nhat thang nay la gi', {'ky': 'thang_nay', 'chon': 'nhieu_nhat'})['chon'], 'nhieu_nhat');
      expect(chinh('khoan thu lon nhat nam nay la gi', {'ky': 'nam_nay', 'chon': 'nhieu_nhat'})['chon'], 'nhieu_nhat');
    });
    test('"it nhat 200k" là ngưỡng: chon mô hình điền cũng bị gỡ', () {
      final r = chinh('cac khoan chi it nhat 200k thang nay', {'ky': 'thang_nay', 'chon': 'it_nhat'});
      expect(r.containsKey('chon'), isFalse);
      expect(r['so_tien_tu'], 200000);
    });
  });

  group('8. gộp: danh mục / ví nói chung (không nêu tên)', () {
    test('"theo danh muc" / "vi nao" → gop', () {
      expect(chinh('thang nay chi theo danh muc the nao', {'ky': 'thang_nay'})['gop'], 'danh_muc');
      expect(chinh('vi nao thang nay chi nhieu nhat', {'ky': 'thang_nay'})['gop'], 'vi');
    });
    test('⭐ E5: nêu TÊN danh mục → danh_muc điền, gop KHÔNG đặt', () {
      final r = chinhThamSoTimGiaoDich(
        'ke tu dau nam toi da chi cho giai tri tong cong bao nhieu', {'ky': 'nam_nay'},
        tenDanhMuc: [...danhMuc, 'Giải trí'], tenVi: vi, now: now,
      ).args;
      expect(r['danh_muc'], 'Giải trí');
      expect(r.containsKey('gop'), isFalse);
    });
    test('phản ví dụ: "tieu bao nhieu" một mình không đặt gop', () {
      expect(chinh('thang nay toi tieu bao nhieu', {'ky': 'thang_nay'}).containsKey('gop'), isFalse);
    });
  });

  group('9. hai chiều: câu có cả từ chi lẫn từ thu → tat_ca (E15)', () {
    test('⭐ E15 "cho vay bao nhieu va thu ve duoc bao nhieu" → chieu tat_ca, danh_muc Cho vay', () {
      final r = chinh('toi da cho vay bao nhieu va thu ve duoc bao nhieu', {'ky': 'thang_nay', 'chieu': 'khoan_thu'});
      expect(r['chieu'], 'tat_ca');
      expect(r['danh_muc'], 'Cho vay');
    });
    test('phản ví dụ: chỉ một chiều thì giữ nguyên chiều mô hình', () {
      expect(chinh('thang nay toi nhan duoc nhung khoan thu nao', {'ky': 'thang_nay', 'chieu': 'khoan_thu'})['chieu'], 'khoan_thu');
    });
  });

  group('chinhThamSoNganSach', () {
    test('⭐ E18 "chua dung den mot nua" → duoi_nua; "qua nua" → tren_nua; "sap het" → nhieu_nhat; không từ khoá → giữ', () {
      expect(chinhThamSoNganSach('ngan sach nao toi chua dung den mot nua', {}).args['chon'], 'duoi_nua');
      expect(chinhThamSoNganSach('ngan sach nao da qua nua', {}).args['chon'], 'tren_nua');
      expect(chinhThamSoNganSach('ngan sach nao sap het', {'chon': 'it_nhat'}).args['chon'], 'nhieu_nhat');
      expect(chinhThamSoNganSach('ngan sach nao it dung nhat', {}).args['chon'], 'it_nhat');
      expect(chinhThamSoNganSach('con bao nhieu tien ngan sach', {'chon': 'duoi_nua'}).args.containsKey('chon'), isFalse,
          reason: 'luật 10 (E10 cổng E): mô hình điền duoi_nua cho "ngân sách ăn uống còn lại bao nhiêu" — không bằng chứng → gỡ');
    });
  });

  test('⭐ chinhThamSoNganSach: "chua dat / chua co / khong co ngan sach" → chua_dat, xét trước tỉ lệ', () {
    expect(chinhThamSoNganSach('cac danh muc chua dat ngan sach', {}).args['chon'], 'chua_dat');
    expect(chinhThamSoNganSach('các danh mục chưa đặt ngân sách', {'chon': 'duoi_nua'}).args['chon'], 'chua_dat');
    expect(chinhThamSoNganSach('danh muc nao chua co ngan sach', {}).args['chon'], 'chua_dat');
    expect(chinhThamSoNganSach('danh muc nao khong co ngan sach', {}).args['chon'], 'chua_dat');
    expect(chinhThamSoNganSach('cac danh muc da dat ngan sach', {}).args.containsKey('chon'), isFalse,
        reason: '"đã đặt" là câu hỏi chung — liệt kê mọi ngân sách');
  });

  test('⭐ lát 3 Task 11: F15 "nen chuyen bot ngan sach nao sang ngan sach nao" → can_doi, xét TRƯỚC tỉ lệ', () {
    for (final cau in [
      'nen chuyen bot ngan sach nao sang ngan sach nao',
      'Nên chuyển bớt ngân sách nào sang ngân sách nào?',
      'can doi ngan sach giup toi',
      'lay tu ngan sach nao de bu cho an uong',
      'ngan sach nao sap het thi nen bu tu dau',
    ]) {
      expect(chinhThamSoNganSach(cau, {'chon': 'nhieu_nhat'}).args['chon'], 'can_doi', reason: cau);
    }
    expect(chinhThamSoNganSach('ngan sach nao sap het', {}).args['chon'], 'nhieu_nhat',
        reason: 'phản ví dụ: hỏi tỉ lệ, không hỏi chuyển');
  });

  group('chinhThamSoHoaDon (lát 3, spec mở rộng §5.1)', () {
    test('⭐ F11 "thang toi toi phai tra hoa don nao" → ky_toi; có dấu và không dấu', () {
      expect(chinhThamSoHoaDon('thang toi toi phai tra hoa don nao', {}).args['ky'], 'ky_toi');
      expect(chinhThamSoHoaDon('Tháng tới tôi phải trả hoá đơn nào?', {}).args['ky'], 'ky_toi');
      expect(chinhThamSoHoaDon('hoa don thang sau', {'ky': 'ky_nay'}).args['ky'], 'ky_toi');
      expect(chinhThamSoHoaDon('Hoá đơn kỳ tới gồm những gì?', {}).args['ky'], 'ky_toi');
      expect(chinhThamSoHoaDon('hoa don nao den han thang toi', {}).args['ky'], 'ky_toi');
    });
    test('⚠️ "thang nay toi…" / "thang toi da tra…": chữ "toi" là TÔI, không phải kỳ tới', () {
      expect(chinhThamSoHoaDon('thang nay toi con phai tra hoa don nao', {}).args.containsKey('ky'), isFalse);
      expect(chinhThamSoHoaDon('Tháng này tôi còn phải trả hoá đơn nào?', {}).args.containsKey('ky'), isFalse);
      expect(chinhThamSoHoaDon('trong thang toi da tra hoa don nao', {}).args.containsKey('ky'), isFalse,
          reason: '"thang toi da" — sau "toi" không phải toi/phai/can/se/co/hết câu');
    });
    test('"tat ca / moi / toan bo hoa don" → tat_ca', () {
      expect(chinhThamSoHoaDon('liet ke tat ca hoa don chua tra', {}).args['ky'], 'tat_ca');
      expect(chinhThamSoHoaDon('Tất cả các hoá đơn của tôi', {}).args['ky'], 'tat_ca');
      expect(chinhThamSoHoaDon('toan bo hoa don', {}).args['ky'], 'tat_ca');
    });
    test('luật 10: câu không nêu kỳ mà mô hình điền ky → gỡ; câu rỗng → không đụng', () {
      expect(chinhThamSoHoaDon('hoa don nao qua han', {'ky': 'ky_toi', 'trang_thai': 'qua_han'}).args,
          {'trang_thai': 'qua_han'});
      expect(chinhThamSoHoaDon('', {'ky': 'ky_toi'}).args['ky'], 'ky_toi');
    });
    test('⭐ G3 cổng F — F12 "hoa don nao tu tra" → tu_tra, kỳ không nêu → tat_ca (không để mô hình dò ba kỳ)', () {
      // Trước 2026-09-28 ca này đòi KHÔNG đổi tham số ("số đã có trong tổng hợp").
      // Cổng F: mô hình gọi ba lần với ba ky rồi trả lời "2 hoá đơn quá hạn".
      final r = chinhThamSoHoaDon('hoa don nao tu tra', {});
      expect(r.args, {'tu_tra': true, 'ky': 'tat_ca'});
      expect(chinhThamSoHoaDon('Hoá đơn nào tự động thanh toán?', {}).args['tu_tra'], isTrue);
      expect(chinhThamSoHoaDon('Tháng tới hoá đơn nào tự trả?', {}).args, {'tu_tra': true, 'ky': 'ky_toi'});
    });
    test('phản ví dụ F12: "phải tự trả" là trả TAY; câu không nói tự trả mà có tu_tra → gỡ', () {
      expect(chinhThamSoHoaDon('hoa don nao toi phai tu tra', {}).args.containsKey('tu_tra'), isFalse);
      expect(chinhThamSoHoaDon('hoa don nao qua han', {'tu_tra': true}).args.containsKey('tu_tra'), isFalse);
    });
  });

  group('chinhThamSoMucTieu (E11 cổng E)', () {
    test('⭐ "muc tieu nao dang cham ke hoach" → cham_ke_hoach; "qua han" → qua_han; "dung ke hoach" → dung_ke_hoach', () {
      expect(chinhThamSoMucTieu('muc tieu nao dang cham ke hoach', {}).args['chon'], 'cham_ke_hoach');
      expect(chinhThamSoMucTieu('Mục tiêu nào đang chậm kế hoạch?', {}).args['chon'], 'cham_ke_hoach');
      expect(chinhThamSoMucTieu('muc tieu nao bi tre', {}).args['chon'], 'cham_ke_hoach');
      expect(chinhThamSoMucTieu('muc tieu nao da qua han', {'chon': 'cham_ke_hoach'}).args['chon'], 'qua_han');
      expect(chinhThamSoMucTieu('muc tieu nao dang dung ke hoach', {}).args['chon'], 'dung_ke_hoach');
    });
    test('⭐ lát 3: "vi khong du / thieu tien trich" → vi_khong_du, xét TRƯỚC quá hạn / chậm', () {
      expect(chinhThamSoMucTieu('muc tieu nao vi khong du tien trich', {}).args['chon'], 'vi_khong_du');
      expect(chinhThamSoMucTieu('Mục tiêu nào đang thiếu tiền trích?', {}).args['chon'], 'vi_khong_du');
      expect(chinhThamSoMucTieu('muc tieu nao khong du de trich bi cham', {}).args['chon'], 'vi_khong_du');
    });
    test('⚠️ F13 "vi co du tien trich cho muc tieu khong" là câu hỏi CHUNG — không chon', () {
      expect(chinhThamSoMucTieu('vi co du tien trich cho muc tieu khong', {'chon': 'vi_khong_du'}).args.containsKey('chon'),
          isFalse, reason: '"co du … khong" hỏi có hay không — phải thấy cả mục tiêu đủ lẫn thiếu');
    });
    test('không nêu trạng thái → gỡ chon mô hình điền; câu rỗng → không đụng', () {
      expect(chinhThamSoMucTieu('khi nao toi dat muc tieu muaxe', {'chon': 'cham_ke_hoach'}).args.containsKey('chon'), isFalse);
      expect(chinhThamSoMucTieu('', {'chon': 'cham_ke_hoach'}).args['chon'], 'cham_ke_hoach');
    });
  });

  group('11. kỳ tự do từ câu hỏi (spec mở rộng tool §3.1)', () {
    test('⭐ "thang 8" → ky=tuy_chon, tu_ngay 01/08/2026, den_ngay 31/08/2026; đè thang_nay của mô hình', () {
      final r = chinh('thang 8 toi chi bao nhieu', {'ky': 'thang_nay', 'chieu': 'khoan_chi'});
      expect(r['ky'], 'tuy_chon');
      expect(r['tu_ngay'], '01/08/2026');
      expect(r['den_ngay'], '31/08/2026');
    });
    test('"tu 1/9 den 15/9" và "tu ngay 1/9 den ngay 15/9" → den_ngay 15/09/2026 (bao gồm)', () {
      final r = chinh('cac khoan chi tu 1/9 den 15/9', {'ky': 'moi_luc'});
      expect((r['tu_ngay'], r['den_ngay']), ('01/09/2026', '15/09/2026'));
      final r2 = chinh('cac khoan chi tu ngay 1/9 den ngay 15/9', {'ky': 'moi_luc'});
      expect((r2['ky'], r2['tu_ngay'], r2['den_ngay']), ('tuy_chon', '01/09/2026', '15/09/2026'));
    });
    test('kỳ tự do THẮNG luật 5 (không đổi thành moi_luc) — kể cả câu không có chữ "tháng/tuần/quý"', () {
      expect(chinh('3 thang gan nhat toi chi gi', {'ky': 'moi_luc'})['ky'], 'tuy_chon');
      expect(chinh('nam ngoai toi chi bao nhieu', {'ky': 'nam_nay'})['ky'], 'tuy_chon');
      expect(chinh('30 ngay qua toi chi gi', {'ky': 'thang_nay'})['ky'], 'tuy_chon');
      expect(chinh('thang nay toi chi bao nhieu', {'ky': 'thang_nay'})['ky'], 'thang_nay');
    });
    test('⚠️ "3 thang gan nhat" KHÔNG phải "lần gần nhất": không đặt sap_xep=moi_nhat', () {
      expect(chinh('3 thang gan nhat toi chi gi', {'ky': 'moi_luc'}).containsKey('sap_xep'), isFalse);
      expect(chinh('lan gan nhat toi chi an uong', {'ky': 'thang_nay'})['sap_xep'], 'moi_nhat');
    });
    test('⚠️ năm của kỳ KHÔNG phải ngưỡng tiền: "tu nam 2025", "den thang 8/2025"', () {
      final r = chinh('cac khoan chi tu 1/9/2026 den 15/9/2026', {'ky': 'moi_luc'});
      expect(r.containsKey('so_tien_tu'), isFalse);
      expect(r.containsKey('so_tien_den'), isFalse);
    });
    test('mốc không hợp lệ → không điền, không ép tuy_chon (tool sẽ từ chối nếu mô hình tự điền)', () {
      final r = chinh('tu 31/6 den 5/7 toi chi gi', {'ky': 'thang_nay'});
      expect(r.containsKey('tu_ngay'), isFalse);
      expect(r['ky'], isNot('tuy_chon'));
    });
  });

  group('12. so_voi (E13)', () {
    test('⭐ E13 "chi nhieu hon hay it hon thang truoc" → so_voi=ky_truoc, ky ép về thang_nay', () {
      final r = chinh('thang nay toi chi nhieu hon hay it hon thang truoc',
          {'ky': 'thang_truoc', 'chieu': 'khoan_chi'});
      expect(r['so_voi'], 'ky_truoc');
      expect(r['ky'], 'thang_nay');
    });
    test('không nêu kỳ gốc: đơn vị của kỳ so sánh quyết định ("hon tuan truoc" → tuan_nay)', () {
      final r = chinh('toi chi nhieu hon tuan truoc khong', {'ky': 'tuan_truoc'});
      expect((r['so_voi'], r['ky']), ('ky_truoc', 'tuan_nay'));
    });
    test('"so voi cung ky nam ngoai" → cung_ky_nam_truoc, ky GỐC giữ thang_nay (không thành năm ngoái)', () {
      final r = chinh('thang nay chi so voi cung ky nam ngoai', {'ky': 'thang_nay'});
      expect((r['so_voi'], r['ky']), ('cung_ky_nam_truoc', 'thang_nay'));
      expect(r.containsKey('tu_ngay'), isFalse,
          reason: '"nam ngoai" ở đây là kỳ SO SÁNH, không phải kỳ đang hỏi');
      expect(chinh('tuan nay so voi tuan truoc', {'ky': 'tuan_nay'})['so_voi'], 'ky_truoc');
    });
    test('kỳ gốc là kỳ tự do: "thang 8 chi nhieu hon thang truoc khong" giữ tuy_chon tháng 8', () {
      final r = chinh('thang 8 chi nhieu hon thang truoc khong', {'ky': 'thang_nay'});
      expect((r['so_voi'], r['ky'], r['tu_ngay']), ('ky_truoc', 'tuy_chon', '01/08/2026'));
    });
    test('so sánh mà không nêu kỳ nào → kỳ gốc thang_nay, không phải moi_luc', () {
      expect(chinh('toi chi nhieu hon cung ky nam ngoai khong', {'ky': 'moi_luc'})['ky'], 'thang_nay');
    });
    test('phản ví dụ: "thang truoc toi chi bao nhieu" KHÔNG phải so sánh; so_voi mô hình điền thừa bị gỡ', () {
      expect(chinh('thang truoc toi chi bao nhieu', {'ky': 'thang_truoc'}).containsKey('so_voi'), isFalse);
      final r = chinh('thang truoc toi chi bao nhieu', {'ky': 'thang_truoc', 'so_voi': 'ky_truoc'});
      expect(r.containsKey('so_voi'), isFalse);
      expect(r['ky'], 'thang_truoc');
    });
  });

  group('13. định tuyến theo câu hỏi — congCuTheoCauHoi (mục 9.33, L5–L7)', () {
    test('⭐ ba câu đích của lát 1 → du_bao_dong_tien', () {
      for (final cau in [
        'tien trong vi co du tra hoa don khong',
        'tra het hoa don thi con bao nhieu',
        '30 ngay toi toi phai chi gi',
        'Tiền trong ví có đủ trả hoá đơn không?',
        'Trả hết hoá đơn thì còn bao nhiêu?',
        'toi con tieu duoc bao nhieu',
        'sap toi toi phai tra nhung gi',
        'tien trong vi co du tra hoa don va trich muc tieu khong',
        '30 ngay toi toi phai tra va trich bao nhieu',
      ]) {
        expect(congCuTheoCauHoi(cau), 'du_bao_dong_tien', reason: cau);
      }
    });
    test('⭐ lát 3 (người dùng chốt 2026-09-28): câu về TRÍCH cho mục tiêu → danh_sach_muc_tieu', () {
      for (final cau in [
        'vi co du tien trich cho muc tieu khong',
        'Ví có đủ tiền trích cho mục tiêu không?',
        'ky trich tiep theo cua MuaDT la khi nao',
        'moi thang tu dong trich bao nhieu cho muaxe',
        'muc tieu nao vi khong du tien trich',
      ]) {
        expect(congCuTheoCauHoi(cau), kTenCongCuMucTieu, reason: cau);
      }
    });
    test('⚠️ câu về LỊCH SỬ trích → giữ đường cũ (tool giao dịch có lịch sử nạp, tool mục tiêu thì không)', () {
      for (final cau in [
        'lan trich gan nhat cho muaxe la khi nao',
        'thang nay da trich bao nhieu cho muc tieu',
      ]) {
        expect(congCuTheoCauHoi(cau), isNot(kTenCongCuMucTieu), reason: cau);
      }
    });
    test('⚠️ phản ví dụ: câu về quá khứ, về ngân sách, về hoá đơn nói chung KHÔNG bị đổi tool', () {
      for (final cau in [
        'thang nay toi chi bao nhieu',
        'hoa don nao qua han',
        'vi nao dang am',
        'ngan sach an uong con tieu duoc bao nhieu',
        'toi da tra hoa don nao',
        '30 ngay qua toi chi gi',
        'muc tieu muaxe con thieu bao nhieu',
        '',
      ]) {
        expect(congCuTheoCauHoi(cau), isNull, reason: cau);
      }
    });
  });

  group('14. kỳ TƯƠNG LAI không phải "không nêu kỳ" (L7)', () {
    test('⭐ "30 ngay toi", "thang sau", "tuần tới" → ky=ky_tuong_lai, KHÔNG moi_luc', () {
      for (final cau in [
        '30 ngay toi toi chi gi',
        'thang sau toi chi bao nhieu',
        'Tuần tới tôi chi những gì',
        '2 tuan nua toi chi gi',
      ]) {
        expect(chinh(cau, {'ky': 'thang_nay'})['ky'], 'ky_tuong_lai', reason: cau);
      }
    });
    test('⚠️ "toi" bỏ dấu là TÔI: "thang nay toi chi", "thang 8 toi chi" không phải tương lai', () {
      expect(chinh('thang nay toi chi bao nhieu', {'ky': 'thang_nay'})['ky'], 'thang_nay');
      expect(chinh('thang 8 toi chi bao nhieu', {'ky': 'thang_nay'})['ky'], 'tuy_chon');
      expect(chinh('Tháng này tôi chi bao nhiêu', {'ky': 'thang_nay'})['ky'], 'thang_nay');
      expect(chinh('lan gan nhat toi chi an uong', {'ky': 'thang_nay'})['ky'], 'moi_luc');
    });
  });

  group('15. định tuyến lát 2 — tổng quan tài chính và danh mục', () {
    test('⭐ câu về thu nhập, tiết kiệm, trung bình ngày, tài sản, dư nợ → tong_quan_tai_chinh', () {
      for (final cau in [
        'thu nhap thang nay cua toi la bao nhieu',
        'toi de danh duoc bao nhieu phan tram',
        'ty le tiet kiem cua toi',
        'toi chi trung binh moi ngay bao nhieu',
        'ngay nao thang nay toi chi nhieu nhat',
        'tong tai san thang nay tang hay giam',
        'toi dang cho vay bao nhieu chua thu ve',
        'toi con no bao nhieu',
        'Thu nhập tháng này của tôi là bao nhiêu?',
      ]) {
        expect(congCuTheoCauHoi(cau), 'tong_quan_tai_chinh', reason: cau);
      }
    });
    test('⭐ câu liệt kê / đếm danh mục → danh_sach_danh_muc', () {
      for (final cau in [
        'toi co nhung danh muc nao',
        'co bao nhieu danh muc chi',
        'liet ke cac danh muc cua toi',
      ]) {
        expect(congCuTheoCauHoi(cau), 'danh_sach_danh_muc', reason: cau);
      }
    });
    test('⚠️ phản ví dụ — câu CŨ đang đúng không bị đổi tool', () {
      for (final cau in [
        'khoan chi lon nhat thang nay la gi',
        'thang nay chi nhieu nhat vao danh muc nao',
        'danh muc nao toi it tieu nhat',
        'cac danh muc chua dat ngan sach',
        'toi da cho vay bao nhieu va thu ve bao nhieu',
        'tong tai san cua toi la bao nhieu',
        'toi nen de danh bao nhieu moi thang cho muc tieu muaxe',
        'thang nay toi nhan duoc nhung khoan thu nao',
      ]) {
        expect(congCuTheoCauHoi(cau), isNull, reason: cau);
      }
    });
  });

  group('17. G1 cổng F — trích tự động chỉ khi câu hỏi nói về trích; câu số dư ví → tool ví', () {
    test('⭐ cauHoiVeTrich: câu về trích / ví nguồn → true', () {
      for (final cau in [
        'vi co du tien trich cho muc tieu khong',
        'ky trich tiep theo cua MuaDT la khi nao',
        'Kỳ trích tiếp theo của MuaDT là khi nào?',
        'muc tieu nao vi khong du tien trich',
        'vi nguon cua muaxe con bao nhieu',
        'moi thang tu dong trich bao nhieu cho muaxe',
      ]) {
        expect(cauHoiVeTrich(cau), isTrue, reason: cau);
      }
    });
    test('⭐ B1, DC1, B2: câu mục tiêu chung → false (chữ trích là tiếng ồn, kéo mô hình đi)', () {
      for (final cau in [
        'khi nao toi dat muc tieu muaxe',
        'Lai suat tiet kiem cua toi la bao nhieu?',
        'moi thang toi can de danh bao nhieu cho muaxe',
        'muc tieu nao dang cham ke hoach',
        '',
      ]) {
        expect(cauHoiVeTrich(cau), isFalse, reason: cau);
      }
    });
    test('⭐ E7 "Vi Tiet kiem hien co bao nhieu tien?" và họ số dư ví → danh_sach_vi', () {
      for (final cau in [
        'Vi Tiet kiem hien co bao nhieu tien?',
        'Ví Tiết kiệm hiện có bao nhiêu tiền?',
        'vi tien mat con bao nhieu',
        'so du cac vi cua toi',
        'so du vi test la bao nhieu',
      ]) {
        expect(congCuTheoCauHoi(cau), kTenCongCuVi, reason: cau);
      }
    });
    test('⚠️ phản ví dụ — câu ví khác KHÔNG đổi sang tool ví, hay giữ tool đích cũ', () {
      expect(congCuTheoCauHoi('vi tien mat co bao nhieu giao dich thang nay'), isNull,
          reason: '"bao nhiêu giao dịch" là câu giao dịch');
      expect(congCuTheoCauHoi('vi tien mat thang nay chi nhung gi'), isNull);
      expect(congCuTheoCauHoi('thang nay toi da chuyen tien sang vi tiet kiem nhung lan nao'), isNull);
      expect(congCuTheoCauHoi('toi co may vi tat ca'), isNull);
      expect(congCuTheoCauHoi('tien trong vi co du tra hoa don khong'), 'du_bao_dong_tien');
      expect(congCuTheoCauHoi('vi co du tien trich cho muc tieu khong'), kTenCongCuMucTieu);
    });
  });

  group('18. G2 cổng F — bốn lỗ của bộ chỉnh (C13, C20, F2)', () {
    test('⭐ C13: mảnh tên ví "vi tien" lọt vào danh_muc — câu đã nêu ví → gỡ mảnh ấy', () {
      final r = chinh('vi tien mat thang nay chi nhung gi',
          {'ky': 'thang_nay', 'chieu': 'khoan_chi', 'danh_muc': 'vi tien'});
      expect(r['vi'], 'Tiền mặt');
      expect(r.containsKey('danh_muc'), isFalse, reason: 'tool từng từ chối "không có danh mục nào tên vi tien" (L1b)');
      final r2 = chinh('vi tien mat thang nay chi nhung gi', {'ky': 'thang_nay', 'tu_khoa': 'tien'});
      expect(r2.containsKey('tu_khoa'), isFalse, reason: 'mảnh "tien" ở tu_khoa cũng thế');
    });
    test('phản ví dụ C13: tên lạ KHÔNG phải mảnh của ví đã nêu thì để nguyên cho tool từ chối (DC3)', () {
      expect(chinh('cac khoan chi cho danh muc abc tu vi tien mat', {'ky': 'thang_nay', 'danh_muc': 'abc'})['danh_muc'],
          'abc');
    });

    Map<String, dynamic> chinhMt(String cau, Map<String, dynamic> args) => chinhThamSoTimGiaoDich(cau, args,
            tenDanhMuc: danhMuc, tenVi: vi, now: now, tenMucTieu: const ['MuaXe', 'MuaDT'])
        .args;
    test('⭐ C20: câu nêu "mục tiêu <tên>" mà mô hình bỏ trống tu_khoa → tu_khoa = tên mục tiêu', () {
      final r = chinhMt('lan cuoi toi nap tien cho muc tieu muaxe la ngay nao',
          {'ky': 'moi_luc', 'sap_xep': 'moi_nhat', 'chon': 'nhieu_nhat'});
      expect(r['tu_khoa'], 'MuaXe');
      expect(r.containsKey('chon'), isFalse);
      expect(r['sap_xep'], 'moi_nhat');
    });
    test('E6: tu_khoa mô hình đã đúng tên thì không đụng; câu không có chữ "mục tiêu" thì không đoán', () {
      expect(chinhMt('Nhung lan toi nap tien vao muc tieu MuaDT', {'ky': 'moi_luc', 'tu_khoa': 'MuaDT'})['tu_khoa'],
          'MuaDT');
      expect(chinhMt('thang nay toi chi bao nhieu', {'ky': 'thang_nay'}).containsKey('tu_khoa'), isFalse);
    });

    test('⭐ F2: câu KHÔNG có số tiền nào → gỡ so_tien_* mô hình điền (số của kỳ 1/9, 15/9 không phải tiền)', () {
      final r = chinh('tu 1/9 den 15/9 toi chi nhung gi',
          {'ky': 'tuy_chon', 'so_tien_tu': 1, 'so_tien_den': 15, 'tu_khoa': 'chi'});
      expect(r.containsKey('so_tien_tu'), isFalse);
      expect(r.containsKey('so_tien_den'), isFalse);
      expect(r.containsKey('tu_khoa'), isFalse, reason: '"chi" là chữ CHIỀU, luật 3 đã đọc thành chieu=khoan_chi');
      expect((r['ky'], r['tu_ngay'], r['den_ngay'], r['chieu']),
          ('tuy_chon', '01/09/2026', '15/09/2026', 'khoan_chi'));
    });
    test('phản ví dụ F2: câu CÓ số tiền giữ ngưỡng; tu_khoa "chi" đến từ "ghi chú chi" thì giữ', () {
      expect(chinh('khoan chi lon nhat thang nay', {'ky': 'thang_nay', 'so_tien_tu': 1000000}).containsKey('so_tien_tu'),
          isFalse, reason: 'không có số trong câu — không bằng chứng');
      expect(chinh('khoan 500000 hom qua la gi', {'ky': 'hom_qua', 'so_tien_tu': 500000})['so_tien_tu'], 500000);
      expect(chinh('cac khoan chi hon nua trieu trong quy nay', {'ky': 'quy_nay'})['so_tien_tu'], 500000);
      expect(chinh('tim giao dich co ghi chu chi', {'ky': 'moi_luc'})['tu_khoa'], 'chi');
      expect(chinh('toi da cho vay nhung ai', {'ky': 'moi_luc', 'tu_khoa': 'cho vay'})['tu_khoa'], 'cho vay',
          reason: 'trùng tên danh mục thật — không phải chữ chiều trần');
    });
  });

  group('19. tenNeuTrongCau — tên đối tượng có thật câu hỏi nêu (G2 E10, G3 E8, G4 F14)', () {
    test('⭐ nêu tên → tên gốc; không nêu → null', () {
      expect(tenNeuTrongCau('Ngan sach an uong con lai bao nhieu?', ['Giáo dục', 'Ăn uống'], tuLoai: 'ngân sách'),
          'Ăn uống');
      expect(tenNeuTrongCau('Hoa don Netflix khi nao den han?', ['Kiem', 'Netflix', 'di h0c'], tuLoai: 'hoá đơn'),
          'Netflix');
      expect(tenNeuTrongCau('hoa don di h0c con phai tra bao nhieu', ['Kiem', 'Netflix', 'di h0c'], tuLoai: 'hoá đơn'),
          'di h0c');
      expect(tenNeuTrongCau('ky trich tiep theo cua MuaDT la khi nao', ['MuaXe', 'MuaDT'], tuLoai: 'mục tiêu'), 'MuaDT');
      expect(tenNeuTrongCau('hoa don nao qua han', ['Kiem', 'Netflix'], tuLoai: 'hoá đơn'), isNull);
      expect(tenNeuTrongCau('', ['Kiem'], tuLoai: 'hoá đơn'), isNull);
    });
    test('⚠️ tên NGẮN chỉ nhận khi đứng ngay sau từ loại: hoá đơn "Kiem" nằm trong "tiết kiệm"', () {
      expect(tenNeuTrongCau('vi tiet kiem co du tra hoa don khong', ['Kiem'], tuLoai: 'hoá đơn'), isNull);
      expect(tenNeuTrongCau('hoa don kiem con bao nhieu', ['Kiem'], tuLoai: 'hoá đơn'), 'Kiem');
    });
    test('tên dài thắng tên là tiền tố của nó', () {
      expect(tenNeuTrongCau('hoa don tien nha t9 den han chua', ['Tiền nhà', 'Tiền nhà T9'], tuLoai: 'hoá đơn'),
          'Tiền nhà T9');
    });
  });

  group('20. G4 cổng F — câu cân đối ngân sách → tool ngân sách (F15)', () {
    test('⭐ "chuyển bớt / cân đối / bù ngân sách" → danh_sach_ngan_sach (phiên một tool)', () {
      for (final cau in [
        'nen chuyen bot ngan sach nao sang ngan sach nao',
        'Nên chuyển bớt ngân sách nào sang ngân sách nào?',
        'can doi ngan sach giup toi',
        'lay tu ngan sach nao de bu cho an uong',
      ]) {
        expect(congCuTheoCauHoi(cau), kTenCongCuNganSach, reason: cau);
      }
    });
    test('phản ví dụ: câu ngân sách khác vẫn không định tuyến', () {
      for (final cau in ['ngan sach nao sap het', 'ngan sach an uong con tieu duoc bao nhieu', 'thang sau toi nen dat ngan sach bao nhieu']) {
        expect(congCuTheoCauHoi(cau), isNull, reason: cau);
      }
    });
  });

  group('16. nhomTongQuanTheoCauHoi', () {
    test('mỗi câu đích của lát 2 → đúng nhóm', () {
      expect(nhomTongQuanTheoCauHoi('thu nhap thang nay cua toi la bao nhieu'), {NhomTongQuan.thuNhap});
      expect(nhomTongQuanTheoCauHoi('toi de danh duoc bao nhieu phan tram'), {NhomTongQuan.thuNhap});
      expect(nhomTongQuanTheoCauHoi('toi chi trung binh moi ngay bao nhieu'), {NhomTongQuan.chiTieu});
      expect(nhomTongQuanTheoCauHoi('ngay nao thang nay toi chi nhieu nhat'), {NhomTongQuan.chiTieu});
      expect(nhomTongQuanTheoCauHoi('tong tai san thang nay tang hay giam'), {NhomTongQuan.taiSan});
      expect(nhomTongQuanTheoCauHoi('toi dang cho vay bao nhieu chua thu ve'), {NhomTongQuan.vayNo});
      expect(nhomTongQuanTheoCauHoi('Tôi còn nợ bao nhiêu?'), {NhomTongQuan.vayNo});
    });
    test('câu chung chung hoặc rỗng → tập rỗng (tool trả mọi nhóm)', () {
      expect(nhomTongQuanTheoCauHoi('tinh hinh tai chinh cua toi the nao'), isEmpty);
      expect(nhomTongQuanTheoCauHoi(''), isEmpty);
    });
  });
}
