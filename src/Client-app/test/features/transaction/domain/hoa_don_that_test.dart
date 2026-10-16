/// A5 — luật đọc ảnh quét chạy trên chữ OCR THẬT của 15 hoá đơn (Realme, 2026-10-08; dữ liệu ở
/// `hoa_don_that_du_lieu.dart`). Đáp án chấm bằng mắt trên ảnh. Mỗi nhóm canh một lỗi đo được trên máy:
/// - Tổng: luật lấy nhầm số trên cả ảnh RÕ (năm *2026*, *Total* trước VAT, *Thành tiền* trước chiết khấu, số dòng dưới
///   nhãn thay vì dòng trên) — chữ OCR có đúng số tổng ở cả 15/15 tờ.
/// - Ngày: máy POS MAXIDI in THÁNG/NGÀY (*9/2/2026* = 02/09) → luật cũ nhận 09/02, sai im lặng; giờ lấy nhầm dấu ảnh
///   *"Shot on … 14:46"*; ngày tiếng Anh / chữ (*Sep 28, 2026*, *Ngày 19 tháng 09 năm 2026*) không đọc ra.
/// - Cửa hàng: lấy chữ trên đồ vật phía sau tờ hoá đơn (nhãn laptop *ASUS*, *CORE*, *IRIS*, *"rtel"*) hoặc dòng địa chỉ.
/// - Chốt tổng AI / luật: Gemma CPU sai 5/15 tờ, 4 lần là số không in trên hoá đơn.
library;

import 'package:flowmoney/features/transaction/domain/chot_tong_quet.dart';
import 'package:flowmoney/features/transaction/domain/doc_anh_quet.dart';
import 'package:flowmoney/features/transaction/domain/doc_hoa_don.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hoa_don_that_du_lieu.dart';

void main() {
  final luc = DateTime(2026, 10, 8, 12, 20);
  KetQuaAnhQuet doc(String ma) => docAnhQuet(vanBan: kHoaDonThat[ma]!, luc: luc);

  group('tổng — luật', () {
    const dapAn = {
      'R01': 262000,
      'R02': 158000,
      'R03': 217500, // ⭐ "Téng tiên" (OCR méo) phải thắng "Thành tiền" 246.000 trước chiết khấu
      'R04': 55500,
      'R05': 57000,
      'R06': 76872, // ⭐ "Töng Tian" + "Số tiền thanh toán" — không lấy năm 2026 của dòng ngày
      'R07': 44700,
      'R08': 75700,
      'R10': 45000,
      'R11': 79243, // ⭐ số nằm Ở DÒNG TRÊN nhãn "Tong tien:"; dòng dưới là "…i9.243" đọc nhầm
      'R12': 300240, // ⭐ "Payment Amount" (thực trả, đã VAT) thắng "Total" 278.000; OCR đọc "300,24O"
      'R13': 72127, // ⭐ số ở dòng trên nhãn "21 Tong"
      'R14': 44745,
      // Tổng tiền 32.160; thực trả 30.000 sau trừ điểm nằm ở dòng "chuyển khoản" OCR méo — luật cố ý dừng ở Tổng tiền,
      // chip AI / luật quyết (Gemma đọc ra 30.000).
      'R15': 32160,
      'R16': 36000,
    };
    for (final e in dapAn.entries) {
      test('${e.key} → ${e.value}', () => expect(doc(e.key).soTien, e.value.toDouble()));
    }
  });

  test('⭐ "Payment Method: Cash" không phải dòng tổng — không lấy tiền khách đưa / tiền thối', () {
    expect(docHoaDonTuChu('Cafe A\nTotal 100,000\nPayment Method: Cash\nCash 150,000\nChange 50,000').tong, 100000);
  });

  test('"Phương thức thanh toán:" rồi "Tiền mặt 150.000" không phải dòng tổng', () {
    expect(docHoaDonTuChu('Quan A\nTong tien 100.000\nPhuong thuc thanh toan:\nTien mat 150.000').tong, 100000);
  });

  test('⭐ "Tổng" OCR đọc MẤT nguyên âm ("Tng tien:", BHX trên OnePlus 2026-10-08) vẫn là nhãn tổng', () {
    expect(docHoaDonTuChu('PHIEU THANH TOAN BACH HOA XANH\ndua hau do 16.588\nTng tien: 79.243').tong, 79243);
  });

  test('⭐ không nhãn tổng nào: số có NGĂN NGHÌN thắng số trần 5 chữ số (mã nhân viên "NV:99184")', () {
    expect(docHoaDonTuChu('BACH HOA XANH\n29/08/2026 18:37 - NV:99184\nkhoai tay 3.802\nxyz 79.243').tong, 79243);
  });

  group('ngày giờ — luật', () {
    const coNgay = {
      'R01': (2026, 9, 28, 14, 19), // ⭐ "Sep 28, 2026 2:19PM" — tiếng Anh, giờ chiều
      'R03': (2026, 10, 2, 14, 33),
      'R06': (2026, 8, 20, 16, 43),
      'R07': (2026, 9, 21, 18, 55),
      'R08': (2026, 9, 11, 19, 42),
      'R10': (2026, 9, 19, 18, 6),
      'R13': (2026, 9, 2, 13, 28), // ⭐ "9/2/2026" in tháng/ngày — KHÔNG phải 09/02
      'R14': (2026, 10, 1, 20, 2), // ⭐ "10/1/2026" — KHÔNG phải 10/01
      'R16': (2026, 9, 19, 21, 29), // ⭐ "Ngày 19 tháng 09 năm 2026/ 21:29"
    };
    for (final e in coNgay.entries) {
      test('${e.key} → ${e.value}', () {
        final (y, m, d, h, p) = e.value;
        expect(doc(e.key).thoiGian, DateTime(y, m, d, h, p));
      });
    }

    test('⭐ R02 — ngày 02/10, giờ KHÔNG lấy từ dấu ảnh "Shot on … 14:46"', () {
      final t = doc('R02').thoiGian;
      expect((t.year, t.month, t.day), (2026, 10, 2));
      expect(t.hour == 14 && t.minute == 46, isFalse, reason: '14:46 là giờ chụp in trên ảnh, không phải giờ mua');
    });

    test('R05 — 30/08/2026 (giờ in không có dấu hai chấm)', () {
      final t = doc('R05').thoiGian;
      expect((t.year, t.month, t.day), (2026, 8, 30));
    });

    for (final ma in ['R04', 'R11', 'R12', 'R15']) {
      test('$ma — năm OCR đọc hỏng → lúc quét, ô thiếu', () {
        final kq = doc(ma);
        expect(kq.thoiGian, luc);
        expect(kq.oThieu, contains(OAnhQuet.thoiGian));
      });
    }

    test('ngày dd/MM có số 0 đầu vẫn đọc NGÀY/THÁNG dù đảo ra ngày gần hơn (05/03 không thành 03/05)', () {
      final kq = docAnhQuet(vanBan: 'Quan A\nNgay 05/03/2026\nTong cong 50.000', luc: luc);
      expect(kq.thoiGian, DateTime(2026, 3, 5));
    });
  });

  group('cửa hàng — luật', () {
    const dapAn = {
      'R01': 'STARBUCKS',
      'R02': 'ỦA TEA', // ⭐ trước đây lấy dòng địa chỉ
      'R03': 'ỦA TEA', // ⭐ trước đây "ASUS Vivobook" (logo laptop phía sau)
      'R05': 'eco-shop Invoice',
      'R08': 'MAXIDI ORE',
      'R12': 'DOOKKI Topokki Buftet',
      'R13': 'MAXIDI', // ⭐ trước đây "CORE" (nhãn Intel Core)
      'R16': 'BEE BEE MART 18K', // ⭐ trước đây "rtel" (mẩu nhãn intel)
    };
    for (final e in dapAn.entries) {
      test('${e.key} → ${e.value}', () => expect(doc(e.key).ghiChu, e.value));
    }

    for (final ma in ['R07', 'R10', 'R14']) {
      test('$ma — tờ không in tên cửa hàng đọc được → TRỐNG, không đoán bằng địa chỉ / dòng món', () {
        expect(doc(ma).ghiChu, '');
        expect(doc(ma).oThieu, contains(OAnhQuet.ghiChu));
      });
    }

    test('R15 — không lấy nhãn dán laptop ("el IRIS", "CORe")', () {
      expect(doc('R15').ghiChu, isNot(anyOf(contains('IRIS'), contains('CORe'))));
    });
  });

  group('chốt tổng AI / luật (Gemma CPU Realme đọc ảnh, prompt chỉ món + tổng)', () {
    // Số Gemma trả trên Realme ngày 2026-10-08 — năm lần sai: R02, R04, R08, R11, R13.
    const ai = {
      'R01': 262000, 'R02': 78000, 'R03': 217500, 'R04': 83500, 'R05': 57000, 'R06': 76872, 'R07': 44700,
      'R08': 55000, 'R10': 45000, 'R11': 16588, 'R12': 300240, 'R13': 17800, 'R14': 44745, 'R15': 30000,
      'R16': 36000,
    };
    const dung = {
      'R01': 262000, 'R02': 158000, 'R03': 217500, 'R04': 55500, 'R05': 57000, 'R06': 76872, 'R07': 44700,
      'R08': 75700, 'R10': 45000, 'R11': 79243, 'R12': 300240, 'R13': 72127, 'R14': 44745, 'R15': 30000,
      'R16': 36000,
    };

    ChotTong chot(String ma) => chotTongQuet(luat: doc(ma).soTien, ai: ai[ma], vanBan: kHoaDonThat[ma]!);

    test('⭐ không tờ nào bị ĐIỀN SẴN một số sai', () {
      for (final ma in kHoaDonThat.keys) {
        final c = chot(ma);
        if (c.soTien != null) expect(c.soTien, dung[ma]!.toDouble(), reason: ma);
      }
    });

    test('tờ không điền sẵn thì số đúng nằm trong các chip', () {
      for (final ma in kHoaDonThat.keys) {
        final c = chot(ma);
        if (c.soTien == null) expect(c.luaChon, contains(dung[ma]!.toDouble()), reason: ma);
      }
    });

    test('13/15 điền sẵn, 2 tờ hỏi bằng chip (R11 nhoè mực · R15 trừ điểm)', () {
      final hoi = [for (final ma in kHoaDonThat.keys) if (chot(ma).soTien == null) ma];
      expect(hoi, ['R11', 'R15']);
    });
  });

  group('chốt tổng — luật chọn', () {
    const van = 'Quan A\nTong cong 50.000\nTien mat 100.000';

    test('AI khớp luật (lệch ≤ 1%) → điền số AI', () {
      final c = chotTongQuet(luat: 50000, ai: 50000, vanBan: van);
      expect(c.soTien, 50000);
      expect(c.luaChon, isEmpty);
    });

    test('AI là số có trên ảnh nhưng lệch luật > 1% → không điền, hai chip (AI trước)', () {
      final c = chotTongQuet(luat: 50000, ai: 100000, vanBan: van);
      expect(c.soTien, isNull);
      expect(c.luaChon, [100000, 50000]);
    });

    test('⭐ AI là số KHÔNG in trên ảnh, cũng không gần số nào → bỏ AI, điền số luật', () {
      final c = chotTongQuet(luat: 50000, ai: 83500, vanBan: van);
      expect(c.soTien, 50000);
      expect(c.luaChon, isEmpty);
    });

    test('⭐ AI không có trên ảnh nhưng khác MỘT chữ số với số luật, lệch ≤ 1% → điền số AI (OCR đọc nhầm 75.700)', () {
      final c = chotTongQuet(luat: 75706, ai: 75700, vanBan: 'MAXIDI\nTeng 75,706');
      expect(c.soTien, 75700);
    });

    test('AI không có trên ảnh, khác một chữ số với số luật nhưng lệch > 1% → hai chip', () {
      final c = chotTongQuet(luat: 50000, ai: 80000, vanBan: 'Quan A\nTong cong 50.000');
      expect(c.soTien, isNull);
      expect(c.luaChon, [80000, 50000]);
    });

    test('AI không có trên ảnh, chỉ "gần" một dòng MÓN (không phải số luật) → bỏ AI', () {
      final c = chotTongQuet(luat: 72127, ai: 17800, vanBan: 'Bot chien 19,800\n72.127\n21 Tong');
      expect(c.soTien, 72127);
    });

    test('không có AI → số luật', () {
      expect(chotTongQuet(luat: 50000, ai: null, vanBan: van).soTien, 50000);
    });

    test('luật không đọc ra, AI có trên ảnh → số AI', () {
      expect(chotTongQuet(luat: null, ai: 100000, vanBan: van).soTien, 100000);
    });

    test('cả hai không có → trống, không chip', () {
      final c = chotTongQuet(luat: null, ai: null, vanBan: van);
      expect(c.soTien, isNull);
      expect(c.luaChon, isEmpty);
    });
  });

  group('cùng tờ, OCR OnePlus (nghiệm thu /quet 2026-10-08)', () {
    KetQuaAnhQuet op(String ma) => docAnhQuet(vanBan: kHoaDonOnePlus[ma]!, luc: luc);

    test('⭐ P04 — "Tbng tiễn:" (OCR đọc "ổ" thành "b") là nhãn tổng; số ở dòng TRÊN → 55.500, không lấy "2006" của '
        'dòng làm tròn dưới câu "…thanh toán tin mặt"', () {
      expect(op('P04').soTien, 55500);
    });

    test('⭐ P05 — ngày "3O/08/2026" (chữ O thay số 0) vẫn đọc ra 30/08/2026', () {
      final t = op('P05').thoiGian;
      expect((t.year, t.month, t.day), (2026, 8, 30));
      expect(op('P05').oThieu, isNot(contains(OAnhQuet.thoiGian)));
    });

    test('P05 tổng 57.000 · P07 "Tng tien: 79.243" vẫn đúng', () {
      expect(op('P05').soTien, 57000);
      expect(op('P07').soTien, 79243);
    });
  });
}
