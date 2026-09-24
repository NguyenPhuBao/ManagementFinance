/// Hằng tên tool và chữ dòng chỉ báo — một chỗ, để adapter, vòng lặp và màn
/// không mỗi nơi gõ lại tên.
library;

import 'dart:convert';

import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toolsJsonCua: đúng khuôn gói gửi xuống SDK — type function · name · description · parameters', () {
    const k = KhaiBaoCongCu(
      ten: 'a_b',
      moTa: 'Gọi khi x.',
      thamSo: {'type': 'object', 'properties': <String, dynamic>{}},
    );
    expect(jsonDecode(toolsJsonCua(const [k])), [
      {
        'type': 'function',
        'function': {
          'name': 'a_b',
          'description': 'Gọi khi x.',
          'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
        },
      },
    ]);
  });

  test('bốn tên tool là snake_case ASCII — định danh cho mô hình', () {
    for (final t in [
      kTenCongCuNganSach,
      kTenCongCuHoaDon,
      kTenCongCuVi,
      kTenCongCuTongKet,
    ]) {
      expect(RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(t), isTrue, reason: t);
    }
  });

  test('trần lời gọi là 3 (spec 4b mục 3.6)', () {
    expect(kTranGoiCongCu, 3);
  });

  test('chữ dòng chỉ báo theo tool; tool lạ vẫn có câu chung', () {
    expect(cauDangTraCuu(kTenCongCuHoaDon), 'Đang tra cứu hoá đơn…');
    expect(cauDangTraCuu(kTenCongCuVi), 'Đang tra cứu ví…');
    expect(cauDangTraCuu(kTenCongCuNganSach), 'Đang tra cứu ngân sách…');
    expect(cauDangTraCuu(kTenCongCuTongKet), 'Đang tổng kết thu chi…');
    expect(cauDangTraCuu(kTenCongCuMucTieu), 'Đang tra cứu mục tiêu…');
    expect(cauDangTraCuu(kTenCongCuGoiYHanMuc), 'Đang tính gợi ý hạn mức…');
    expect(cauDangTraCuu(kTenCongCuGiaoDich), 'Đang tìm giao dịch…');
    expect(cauDangTraCuu('bay_gio_may_gio'), 'Đang tra cứu…',
        reason: 'mô hình bịa tên tool thì dòng chỉ báo không được vỡ');
  });
}
