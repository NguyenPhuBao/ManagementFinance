/// Bộ chỉnh tham số `tim_giao_dich` theo CÂU HỎI — tất định, chạy trước khi tool
/// kiểm và tra cứu (cổng D lần 9–11: tham số 13/20, sáu câu hỏng theo bốn họ mà
/// ví dụ trong lời hệ thống không chữa được — mục 9.26–9.27 `AI_EDGE_FEATURE.md`).
///
/// Mỗi ca là đúng câu hỏi và args đã đo trên Realme.
library;

import 'package:flowmoney/features/ai_edge/domain/chinh_tham_so.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const danhMuc = ['Ăn uống', 'Di chuyển', 'Mua sắm', 'Giáo dục', 'Cho vay', 'Chi khác', 'test1'];
  const vi = ['Tiền mặt', 'Tiết kiệm', 'test'];

  Map<String, dynamic> chinh(String cauHoi, Map<String, dynamic> args) =>
      chinhThamSoTimGiaoDich(cauHoi, args, tenDanhMuc: danhMuc, tenVi: vi).args;

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
        tenVi: vi,
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
        tenVi: vi,
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

    test('câu hỏi không có số tiền thì giữ nguyên ngưỡng của mô hình', () {
      final r = chinh('khoan chi lon nhat thang nay la gi', {'ky': 'thang_nay', 'so_tien_tu': 300000});
      expect(r['so_tien_tu'], 300000);
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
  });

  test('6. ghi chú nêu từng luật đã áp; không luật nào áp thì rỗng', () {
    final co = chinhThamSoTimGiaoDich(
      'cac khoan chi hon nua trieu trong quy nay',
      {'ky': 'quy_nay', 'so_tien_tu': 1000000},
      tenDanhMuc: danhMuc,
      tenVi: vi,
    );
    expect(co.ghiChu, isNotEmpty);
    final khong = chinhThamSoTimGiaoDich(
      'hom qua toi da chi nhung gi',
      {'ky': 'hom_qua', 'chieu': 'khoan_chi'},
      tenDanhMuc: danhMuc,
      tenVi: vi,
    );
    expect(khong.ghiChu, isEmpty);
    expect(khong.args, {'ky': 'hom_qua', 'chieu': 'khoan_chi'});
  });

  test('câu hỏi rỗng → không chỉnh gì, kể cả ky (tool gọi không kèm cauHoi giữ hành vi cũ)', () {
    final r = chinhThamSoTimGiaoDich('', {'ky': 'thang_nay', 'chieu': 'chuyen_vi'},
        tenDanhMuc: danhMuc, tenVi: vi);
    expect(r.ghiChu, isEmpty);
    expect(r.args, {'ky': 'thang_nay', 'chieu': 'chuyen_vi'});
  });
}
