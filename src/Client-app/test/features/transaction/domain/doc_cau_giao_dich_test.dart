/// C2 — đọc một câu thành các ô của form Thêm giao dịch (spec `2026-09-28-c2-nhap-giao-dich-bang-cau-design.md` §2).
/// Hàm thuần, chỉ luật: ô nào không đọc được thì `null` và form GIỮ NGUYÊN ô ấy — không bao giờ bịa số.
library;

import 'package:flowmoney/features/transaction/domain/doc_cau_giao_dich.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

void main() {
  // Thứ Tư 30/9/2026, 15 giờ.
  final now = DateTime(2026, 9, 30, 15);
  KetQuaDocCau doc(String cau) => docCauGiaoDich(cau, now: now, vi: const [], chonDuoc: const []);

  group('§2.1 số tiền — bốn cách nói', () {
    const bang = {
      'ăn phở 45k': 45000.0,
      'cafe 45 k': 45000.0,
      'bún 45 nghìn': 45000.0,
      'bún 45 ngàn': 45000.0,
      'bun 45 nghin': 45000.0,
      'tiền nhà 2tr': 2000000.0,
      'tiền nhà 2 triệu': 2000000.0,
      'sửa xe 1tr2': 1200000.0,
      'laptop 1tr200': 1200000.0,
      'đồng hồ 1tr25': 1250000.0,
      'học phí 1,2 triệu': 1200000.0,
      'đồ 1.5tr': 1500000.0,
      'mua đt 2 củ': 2000000.0,
      'nhậu 2 lít': 200000.0,
      'nhậu 3 xị': 300000.0,
      'năm mươi nghìn tiền gửi xe': 50000.0,
      'một triệu rưỡi tiền điện': 1500000.0,
      'nam muoi nghin gui xe': 50000.0,
      'ăn trưa 45.000': 45000.0,
      'ăn trưa 45000': 45000.0,
      'ăn trưa 45.000đ': 45000.0,
      'ăn trưa 45000 đồng': 45000.0,
      'đổ 2 lít xăng 50k': 50000.0,
    };
    for (final e in bang.entries) {
      test('"${e.key}"', () => expect(doc(e.key).soTien, e.value, reason: e.key));
    }

    test('"2 ly cà phê" → không đọc: số trần dưới 1.000 là số lượng', () {
      expect(doc('2 ly cà phê').soTien, isNull);
    });

    test('hai số tiền cùng hạng → số đầu + cảnh báo', () {
      final r = doc('ăn sáng 30k, grab 50k');
      expect(r.soTien, 30000);
      expect(r.canhBao.single, contains('nhiều số tiền'));
    });

    test('lít đứng sau k: "đổ 2 lít xăng 50k" không cảnh báo nhiều số tiền', () {
      expect(doc('đổ 2 lít xăng 50k').canhBao, isEmpty);
    });

    test('14 chữ số → không đọc + cảnh báo (trần numeric(15,2))', () {
      final r = doc('chuyển 12345678901234');
      expect(r.soTien, isNull);
      expect(r.canhBao, isNotEmpty);
    });

    test('số điện thoại (0 đứng đầu) và năm ("năm 2026") không phải tiền', () {
      final r = doc('nạp thẻ 0912345678 100k');
      expect(r.soTien, 100000);
      expect(r.canhBao, isEmpty);
      final r2 = doc('học phí năm 2026 2tr');
      expect(r2.soTien, 2000000);
      expect(r2.canhBao, isEmpty);
    });

    test('ngày không phải tiền', () {
      final r = doc('ngày 5/9 mua sách 120k');
      expect(r.soTien, 120000);
      expect(r.ngay, DateTime(2026, 9, 5));
    });

    test('⚠️ số chữ mơ hồ → không điền, kèm cảnh báo — không bao giờ bịa số', () {
      final r = doc('một triệu hai tiền sách');
      expect(r.soTien, isNull, reason: '"một triệu hai" là 1.200.000 hay 1.000.000 + chữ khác — không chắc thì không điền');
      expect(r.canhBao, isNotEmpty);
      final r2 = doc('mấy trăm nghìn tiền chợ');
      expect(r2.soTien, isNull);
      expect(r2.canhBao, isNotEmpty);
    });
  });

  group('§2.2 loại', () {
    test('từ chỉ thu → thu', () {
      expect(doc('nhận lương 9tr').loai, 'thu');
      expect(doc('bán xe đạp 2tr').loai, 'thu');
      expect(doc('hoàn tiền 50k').loai, 'thu');
      expect(doc('lãi tiết kiệm 120k').loai, 'thu');
      expect(doc('lì xì 500k').loai, 'thu');
      expect(doc('được cho 500k').loai, 'thu');
      expect(doc('thưởng tết 3tr').loai, 'thu');
      expect(doc('nhan luong 9tr').loai, 'thu', reason: 'gõ không dấu');
    });

    test('vay / nợ → null, để người dùng chọn chiều', () {
      expect(doc('thu nợ anh Nam 500k').loai, isNull);
      expect(doc('vay tiền bạn 2tr').loai, isNull);
    });

    test('câu trơn → null (form giữ chiều đang chọn)', () {
      expect(doc('ăn phở 45k').loai, isNull);
    });

    test('⚠️ bỏ dấu cả câu là đọc sai: "bạn" không phải "bán", "lại" không phải "lãi", "thường" không phải "thưởng"', () {
      expect(doc('ăn với bạn 200k').loai, isNull);
      expect(doc('mua lại áo 200k').loai, isNull);
      expect(doc('cơm bình thường 40k').loai, isNull);
      expect(doc('an voi ban 200k').loai, isNull, reason: '"ban" không dấu có thể là bạn — không đoán');
      expect(doc('mua được áo 200k').loai, isNull, reason: '"được" một mình không phải khoản thu');
    });

    test('"thứ 2" không làm câu thành khoản thu', () {
      final r = doc('thứ 2 đổ xăng 50k');
      expect(r.loai, isNull);
      expect(r.ngay, DateTime(2026, 9, 28));
    });
  });

  group('§2.3 ngày', () {
    test('hôm qua → 29/9; không nêu → null', () {
      expect(doc('hôm qua ăn phở 45k').ngay, DateTime(2026, 9, 29));
      expect(doc('ăn phở 45k').ngay, isNull);
    });
  });

  group('§2.7 ghi chú', () {
    test('bỏ số tiền và ngày; giữ dấu và chữ hoa', () {
      expect(doc('hôm qua ăn Phở 45k').ghiChu, 'ăn Phở');
    });
    test('bỏ luôn "hết / mất / tốn" đứng ngay trước số tiền, và "đồng" ngay sau', () {
      expect(doc('ăn phở hết 45k').ghiChu, 'ăn phở');
      expect(doc('ăn trưa 45000 đồng với bạn').ghiChu, 'ăn trưa với bạn');
    });
    test('số tiền thứ hai (không dùng) ở lại ghi chú; dấu câu gọn lại', () {
      expect(doc('ăn sáng 30k, grab 50k').ghiChu, 'ăn sáng, grab 50k');
    });
    test('ngày có chữ "ngày" bỏ cả cụm', () {
      expect(doc('ngày 5/9 mua sách 120k').ghiChu, 'mua sách');
    });
    test('câu tách dấu (NFD) → ghi chú dựng sẵn (NFC)', () {
      expect(doc(unorm.nfd('hôm qua ăn phở 45k')).ghiChu, 'ăn phở');
    });
  });

  group('không đọc được gì', () {
    test('câu không có ô nào đọc được → khongDocDuocGi, ghi chú là cả câu', () {
      final r = doc('xin chào');
      expect(r.khongDocDuocGi, isTrue);
      expect(r.ghiChu, 'xin chào');
    });
    test('có số tiền thì không phải "không đọc được gì"', () {
      expect(doc('45k').khongDocDuocGi, isFalse);
    });
  });
}
