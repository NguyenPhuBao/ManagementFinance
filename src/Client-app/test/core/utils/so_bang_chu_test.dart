/// Bộ đọc số viết bằng CHỮ — một định nghĩa cho ba nơi (C2 task 1, spec
/// `2026-09-28-c2-nhap-giao-dich-bang-cau-design.md` §2.6 + banner mục 1):
/// ô Nhập nhanh (`docCauGiaoDich`), bộ kiểm số của Trợ lý AI (`kiem_so.dart`)
/// và bộ chỉnh tham số (`chinh_tham_so.dart`).
///
/// Trước lượt này có HAI bộ đọc riêng tư và cả hai mù hàng chục — đo 2026-09-29:
/// *"năm mươi nghìn"*, *"hai mươi lăm nghìn"*, *"nam muoi nghin"* đều ra rỗng, và
/// *"dưới năm mươi nghìn"* không thành ngưỡng nào trong khi *"dưới 50k"* thì có.
library;

import 'package:flowmoney/core/utils/so_bang_chu.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

void main() {
  List<double> giaTri(String cau) => [for (final c in timSoBangChu(cau)) c.giaTri];
  double mot(String cau) => timSoBangChu(cau).single.giaTri;

  group('các dạng của bộ đọc cũ — giữ nguyên', () {
    test('số + một hay nhiều đơn vị, "rưỡi", "nửa", nhiều nhóm cộng lại', () {
      expect(mot('hơn một triệu'), 1000000);
      expect(mot('nửa triệu'), 500000);
      expect(mot('hai trăm nghìn'), 200000);
      expect(mot('năm trăm ngàn'), 500000);
      expect(mot('mười nghìn'), 10000);
      expect(mot('ba tỷ'), 3000000000);
      expect(mot('một triệu rưỡi'), 1500000);
      expect(mot('một triệu hai trăm nghìn'), 1200000);
      expect(mot('một nghìn tỷ'), 1000000000000,
          reason: 'đơn vị liền nhau NHÂN nhau, như bộ đọc cũ');
    });

    test('lượng từ mơ hồ là NaN — không bao giờ khớp một số thật', () {
      expect(mot('vài triệu').isNaN, isTrue);
      expect(mot('mấy nghìn').isNaN, isTrue);
      expect(mot('mấy chục nghìn').isNaN, isTrue);
    });

    test('từ số không có đơn vị ngay sau KHÔNG phải số: "một khoản", "năm nay"', () {
      expect(timSoBangChu('Có một khoản chi trong năm nay và một hóa đơn.'), isEmpty);
    });

    test('đơn vị đứng một mình ("hàng triệu") không phải số', () {
      expect(timSoBangChu('bạn có hàng triệu lý do'), isEmpty);
    });

    test('không phân biệt hoa thường; vị trí theo câu gốc', () {
      final c = timSoBangChu('Hơn Một Triệu đồng').single;
      expect(c.giaTri, 1000000);
      expect('Hơn Một Triệu đồng'.substring(c.batDau, c.ketThuc), 'Một Triệu');
    });
  });

  group('⭐ hàng chục — bộ đọc cũ mù chỗ này', () {
    test('"năm mươi nghìn" = 50.000 (đo 2026-09-29: bộ cũ trả rỗng)', () {
      expect(mot('năm mươi nghìn'), 50000);
    });

    test('mươi + mốt / tư / lăm / nhăm / chữ số thường', () {
      expect(mot('hai mươi mốt nghìn'), 21000);
      expect(mot('ba mươi tư nghìn'), 34000);
      expect(mot('hai mươi lăm nghìn'), 25000);
      expect(mot('bốn mươi nhăm nghìn'), 45000);
      expect(mot('sáu mươi hai nghìn'), 62000);
    });

    test('mười + chữ số: mười lăm, mười hai', () {
      expect(mot('mười lăm nghìn'), 15000);
      expect(mot('mười hai nghìn'), 12000,
          reason: 'bộ cũ đọc cụm này thành "hai nghìn" = 2.000');
    });

    test('"chục" là hàng chục kiểu nói: "ba chục nghìn" = 30.000', () {
      expect(mot('ba chục nghìn'), 30000);
    });

    test('trăm + chục + đơn vị, linh / lẻ', () {
      expect(mot('hai trăm năm mươi nghìn'), 250000);
      expect(mot('một trăm linh năm nghìn'), 105000);
      expect(mot('một trăm lẻ năm nghìn'), 105000);
      expect(mot('một triệu hai trăm năm mươi nghìn'), 1250000);
      expect(mot('hai trăm rưỡi nghìn'), 250000);
      expect(mot('hai nghìn rưỡi'), 2500);
      expect(mot('hai nghìn năm trăm'), 2500);
    });

    test('"tư", "lăm", "mốt" chỉ là chữ số ngay sau hàng chục', () {
      expect(timSoBangChu('tư nghìn'), isEmpty);
      expect(timSoBangChu('lăm nghìn'), isEmpty);
    });
  });

  group('không dấu — người gõ nhanh', () {
    test('mỗi từ khớp dạng có dấu HOẶC dạng không dấu', () {
      expect(mot('nam muoi nghin'), 50000);
      expect(mot('hai muoi lam nghin'), 25000);
      expect(mot('mot trieu ruoi'), 1500000);
      expect(mot('muoi nghin'), 10000,
          reason: '"muoi" không có chữ số trước là mười');
      expect(mot('nua trieu'), 500000);
    });

    test('⚠️ chữ CÓ dấu khác thì không phải số: "tí" không phải "tỉ"', () {
      expect(timSoBangChu('thêm một tí nữa'), isEmpty,
          reason: 'bỏ dấu cả câu thì "một tí" thành "mot ti" = một tỉ');
    });
  });

  group('batBuocDonVi: false — cụm có hàng chục mà thiếu đơn vị (lớp kiểm AI, C2 §2.8)', () {
    double? khong(String cau) {
      final c = timSoBangChu(cau, batBuocDonVi: false);
      return c.isEmpty ? null : c.single.giaTri;
    }

    test('"ba chục", "hai mươi lăm", "mười lăm" là số', () {
      expect(khong('cà phê mất ba chục'), 30);
      expect(khong('hết hai mươi lăm'), 25);
      expect(khong('mười lăm'), 15);
    });
    test('có đơn vị thì vẫn đọc trọn cụm', () {
      expect(khong('hai mươi lăm nghìn'), 25000);
    });
    test('chữ số đứng một mình vẫn KHÔNG phải số: "một khoản", "năm nay"', () {
      expect(timSoBangChu('mua một ly trong năm nay', batBuocDonVi: false), isEmpty);
    });
    test('mặc định không đổi: "ba chục" thiếu đơn vị không phải cụm', () {
      expect(timSoBangChu('cà phê mất ba chục'), isEmpty);
    });
  });

  group('ranh giới cụm', () {
    test('"hai triệu năm nay" → chỉ "hai triệu"; "năm" là năm lịch', () {
      final c = timSoBangChu('chi hai triệu năm nay').single;
      expect(c.giaTri, 2000000);
      expect('chi hai triệu năm nay'.substring(c.batDau, c.ketThuc), 'hai triệu');
    });

    test('dấu câu cắt cụm; hai cụm theo thứ tự câu', () {
      expect(giaTri('hai trăm nghìn và ba triệu'), [200000, 3000000]);
      expect(giaTri('hai trăm, năm mươi nghìn'), [200, 50000]);
    });

    test('vị trí cụm nằm giữa câu', () {
      const cau = 'ăn phở năm mươi nghìn nhé';
      final c = timSoBangChu(cau).single;
      expect(cau.substring(c.batDau, c.ketThuc), 'năm mươi nghìn');
    });

    test('chữ số dính liền trước từ số thì không phải cụm', () {
      expect(timSoBangChu('mã 5một nghìn'), isEmpty);
    });

    test('câu tách dấu (NFD) vẫn đọc, vị trí theo chính chuỗi ấy', () {
      final cau = unorm.nfd('ăn năm mươi nghìn');
      final c = timSoBangChu(cau).single;
      expect(c.giaTri, 50000);
      expect(unorm.nfc(cau.substring(c.batDau, c.ketThuc)), 'năm mươi nghìn');
    });
  });
}
