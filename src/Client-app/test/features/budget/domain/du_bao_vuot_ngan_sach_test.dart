// Bản thử NCKH: `duBaoVuotNganSach` phải cho ĐÚNG số của `core.py` (Python) trên năm người dùng đã nạp vào
// app. Số Python ở `research/.../results/app_m23.json` (`python -u app_m23.py`); dữ liệu ở `app_users.json`.
// Thiếu hai tệp ấy (máy khác) thì bỏ qua.
import 'dart:convert';
import 'dart:io';

import 'package:flowmoney/features/budget/domain/du_bao_vuot_ngan_sach.dart';
import 'package:flutter_test/flutter_test.dart';

const _thuMuc = '../../research/du-bao-vuot-ngan-sach/experiment/results';

void main() {
  final tepNguoi = File('$_thuMuc/app_users.json');
  final tepPy = File('$_thuMuc/app_m23.json');
  final coDuLieu = tepNguoi.existsSync() && tepPy.existsSync();

  test('khớp core.py (Python) cho năm người dùng đã nạp vào app, ngày 10/11/2026', () {
    final nguoi = (jsonDecode(tepNguoi.readAsStringSync()) as List).cast<Map<String, dynamic>>();
    final py = (jsonDecode(tepPy.readAsStringSync()) as List).cast<Map<String, dynamic>>();
    for (var n = 0; n < nguoi.length; n++) {
      // Tháng 4..10 đủ ngày, tháng 11 tới ngày 10.
      final thang = [
        for (var mon = 4; mon <= 11; mon++)
          List<double>.filled(mon == 11 ? 10 : DateTime.utc(2026, mon + 1, 0).day, 0)
      ];
      for (final tx in (nguoi[n]['transactions'] as List).cast<Map<String, dynamic>>()) {
        final d = DateTime.parse(tx['date'] as String);
        thang[d.month - 4][d.day - 1] += (tx['amount'] as num).toDouble();
      }
      final b = ((nguoi[n]['budget'] as num) / 1000).round() * 1000.0;
      final kq = duBaoVuotNganSach(thang: thang, soNgayKyNay: 30, nganSach: b)!;
      final mong = py[n];
      expect(kq.soKy, mong['K'], reason: 'người ${n + 1}: số kỳ có chi');
      for (final (ten, thuc, ky) in [
        ('p0', kq.p0, mong['p0']),
        ('p1', kq.p1, mong['p1']),
        ('p2', kq.p2, mong['p2']),
        ('p3', kq.p3, mong['p3']),
      ]) {
        expect(thuc, closeTo((ky as num).toDouble(), 1e-6), reason: 'người ${n + 1}: $ten lệch Python');
      }
    }
  }, skip: coDuLieu ? false : 'thiếu dữ liệu research/ trên máy này');

  test('chưa đủ sáu tháng trước tháng hiện tại → null (không đoán bừa)', () {
    final thang = [for (var i = 0; i < 6; i++) List<double>.filled(30, 1000), List<double>.filled(5, 1000)];
    expect(duBaoVuotNganSach(thang: thang.sublist(1), soNgayKyNay: 30, nganSach: 30000), isNull);
    expect(duBaoVuotNganSach(thang: thang, soNgayKyNay: 30, nganSach: 30000), isNotNull);
  });

  test('ngân sách 0 hoặc không kỳ nào có chi → null', () {
    final rong = [for (var i = 0; i < 6; i++) List<double>.filled(30, 0), List<double>.filled(5, 1000)];
    expect(duBaoVuotNganSach(thang: rong, soNgayKyNay: 30, nganSach: 30000), isNull);
    final co = [for (var i = 0; i < 6; i++) List<double>.filled(30, 1000), List<double>.filled(5, 1000)];
    expect(duBaoVuotNganSach(thang: co, soNgayKyNay: 30, nganSach: 0), isNull);
  });

  test('chi đã vượt hẳn ngân sách → cả ba xác suất cao', () {
    final thang = [for (var i = 0; i < 6; i++) List<double>.filled(30, 1000), List<double>.filled(10, 5000)];
    final kq = duBaoVuotNganSach(thang: thang, soNgayKyNay: 30, nganSach: 30000)!;
    expect(kq.p1, greaterThan(0.9));
    expect(kq.p2, greaterThan(0.9));
    expect(kq.p3, greaterThan(0.9));
  });
}
