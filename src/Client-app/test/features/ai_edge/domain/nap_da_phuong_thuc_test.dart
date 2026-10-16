// test/features/ai_edge/domain/nap_da_phuong_thuc_test.dart
/// C4 §4.3 — một bản mô hình CÓ CẢ cờ ảnh lẫn âm thanh; mỗi tiến trình đóng nhiều nhất MỘT lần (A5: OnePlus 13R GPU sập
/// native ở lần ĐÓNG thứ hai). Luật cũ của `docAnh` từ chối bản có âm thanh → chuỗi Quét → Nói → Quét đóng hai lần.
library;

import 'package:flowmoney/features/ai_edge/domain/nap_da_phuong_thuc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mô phỏng `SlmRuntimeThat`: mỗi lần cần, áp quyết định rồi ghi lại trạng thái.
class _MoHinh {
  bool co = false, anh = false, am = false;
  int soLanDong = 0, soLanNap = 0;
  void can(CanMoHinh c) {
    final q = quyetDinhNap(coMoHinh: co, coAnh: anh, coAm: am, can: c);
    if (q.dong) {
      soLanDong++;
      co = false;
    }
    if (q.nap) {
      soLanNap++;
      co = true;
      anh = q.anh;
      am = q.am;
    }
  }
}

void main() {
  for (final (ten, chuoi) in [
    ('Trợ lý → Quét → Nói', [CanMoHinh.chu, CanMoHinh.anh, CanMoHinh.am]),
    ('Trợ lý → Nói → Quét', [CanMoHinh.chu, CanMoHinh.am, CanMoHinh.anh]),
    ('Nói → Quét → Nói', [CanMoHinh.am, CanMoHinh.anh, CanMoHinh.am]),
    ('Quét → Trợ lý → Nói', [CanMoHinh.anh, CanMoHinh.chu, CanMoHinh.am]),
    ('Trợ lý → Quét → Trợ lý → Nói → Quét', [CanMoHinh.chu, CanMoHinh.anh, CanMoHinh.chu, CanMoHinh.am, CanMoHinh.anh]),
  ]) {
    test('⭐ $ten: đóng ≤ 1 lần', () {
      final m = _MoHinh();
      chuoi.forEach(m.can);
      expect(m.soLanDong, lessThanOrEqualTo(1), reason: 'lần đóng thứ hai làm OnePlus GPU sập native (A5)');
      expect((m.anh, m.am), (true, true), reason: 'bản đa phương thức có CẢ hai cờ');
    });
  }

  test('đã có bản đủ hai cờ → không đóng, không nạp', () {
    final q = quyetDinhNap(coMoHinh: true, coAnh: true, coAm: true, can: CanMoHinh.am);
    expect((q.dong, q.nap), (false, false));
  });
  test('đang có bản chữ → đóng một lần, nạp bản hai cờ', () {
    final q = quyetDinhNap(coMoHinh: true, coAnh: false, coAm: false, can: CanMoHinh.anh);
    expect((q.dong, q.nap, q.anh, q.am), (true, true, true, true));
  });
  test('chưa có mô hình, cần chữ → nạp bản chữ (đường Trợ lý giữ nguyên)', () {
    final q = quyetDinhNap(coMoHinh: false, coAnh: false, coAm: false, can: CanMoHinh.chu);
    expect((q.dong, q.nap, q.anh, q.am), (false, true, false, false));
  });
}
