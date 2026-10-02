/// Dự án B — đặc trưng và phép ĐOÁN của bộ định tuyến học (spec
/// `2026-10-02-du-an-b-mo-hinh-dinh-tuyen-cau-hoi-design.md` mục 4.1).
///
/// Canh chừng điều gì: phép đoán này quyết một câu hỏi có bị thu về phiên MỘT
/// tool hay không. Đặc trưng lệch giữa lúc học (`test/tool/dinh_tuyen/`) và lúc
/// đoán là mô hình đoán trên thứ nó chưa từng thấy — không exception nào báo.
library;

import 'dart:math' as math;

import 'package:flowmoney/features/ai_edge/domain/dinh_tuyen_hoc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('amTietDinhTuyen', () {
    test('bỏ dấu, chữ thường, bỏ dấu câu; âm tiết có chữ số thành ký hiệu số', () {
      expect(amTietDinhTuyen('Tháng này tôi tiêu gì trên 500k?'),
          ['thang', 'nay', 'toi', 'tieu', 'gi', 'tren', kKyHieuSo]);
    });

    test('các con số đứng liền nhau gom thành MỘT ký hiệu', () {
      expect(amTietDinhTuyen('tu 1/9 den 15/9'), ['tu', kKyHieuSo, 'den', kKyHieuSo],
          reason: '"1/9" tách thành hai số — đếm hai lần là dạy mô hình rằng ngày tháng khác số tiền');
    });

    test('câu có dấu và câu không dấu là MỘT mẫu; gạch dưới đọc là dấu cách', () {
      expect(chuanHoaDinhTuyen('Ngân sách nào sắp hết?'), chuanHoaDinhTuyen('ngan sach nao sap het'));
      expect(chuanHoaDinhTuyen('tien_mat'), 'tien mat');
    });

    test('câu rỗng hoặc toàn dấu câu → không âm tiết nào', () {
      expect(amTietDinhTuyen(''), isEmpty);
      expect(amTietDinhTuyen(' ?! '), isEmpty);
    });
  });

  test('dacTrungCua: âm tiết đơn + cặp âm tiết LIỀN NHAU', () {
    expect(dacTrungCua('ngan sach nao'), {'ngan', 'sach', 'nao', 'ngan sach', 'sach nao'});
    expect(dacTrungCua('vi'), {'vi'});
  });

  group('doanDinhTuyen', () {
    final w = TrongSoDinhTuyen(
      nhan: ['a', 'b'],
      tuVung: ['tieu', 'ngan sach'],
      thienLech: [0, 0],
      maTran: [2, 0, 0, 2],
    );

    test('cộng trọng số của đặc trưng có mặt rồi softmax', () {
      final d = doanDinhTuyen(w, 'tôi tiêu gì');
      expect(d.nhan, 'a');
      expect(d.xacSuat, closeTo(math.exp(2) / (math.exp(2) + 1), 1e-9));
    });

    test('hai đặc trưng kéo hai phía bằng nhau → 0,5', () {
      expect(doanDinhTuyen(w, 'tiêu hết ngân sách').xacSuat, closeTo(0.5, 1e-9));
    });

    test('⭐ câu không có đặc trưng nào trong từ vựng → không định tuyến, xác suất 0', () {
      final d = doanDinhTuyen(w, 'xin chào');
      expect(d.nhan, kNhanKhongDinhTuyen);
      expect(d.xacSuat, 0,
          reason: 'không có bằng chứng nào thì thiên lệch của nhãn đông nhất không được thành "tự tin"');
    });

    test('điểm rất lớn không ra NaN', () {
      final lon = TrongSoDinhTuyen(
          nhan: ['a', 'b'], tuVung: ['tieu'], thienLech: [0, 0], maTran: [1000, -1000]);
      final d = doanDinhTuyen(lon, 'tieu');
      expect(d.xacSuat.isNaN, isFalse);
      expect(d.xacSuat, closeTo(1, 1e-9));
    });
  });

  test('TrongSoDinhTuyen từ chối kích thước lệch', () {
    expect(
        () => TrongSoDinhTuyen(nhan: ['a', 'b'], tuVung: ['x'], thienLech: [0, 0], maTran: [1]),
        throwsArgumentError);
    expect(
        () => TrongSoDinhTuyen(nhan: ['a', 'b'], tuVung: ['x'], thienLech: [0], maTran: [1, 2]),
        throwsArgumentError);
  });
}
