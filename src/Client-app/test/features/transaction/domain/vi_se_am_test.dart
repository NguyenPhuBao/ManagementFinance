import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/domain/vi_se_am.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionEntity _gd(String type, double amount, {String vi = 'A', String? den, String id = 't1'}) =>
    TransactionEntity(
      id: id,
      walletId: vi,
      idaccount: 10,
      walletTransfer: den,
      amount: amount,
      type: type,
      date: DateTime(2026, 11, 20),
      updatedAt: DateTime(2026, 11, 20),
    );

ViKiemAm _vi(String id, double soDu, {bool choPhepAm = false}) =>
    ViKiemAm(id: id, ten: 'Ví $id', soDu: soDu, choPhepAm: choPhepAm);

void main() {
  test('khoản chi vượt số dư của ví KHÔNG cho âm → báo ví ấy kèm số dư sau', () {
    final r = viSeAm(vi: [_vi('A', 100000)], moi: [_gd('chi', 150000)]);
    expect(r.map((v) => (v.ten, v.soDuSau)), [('Ví A', -50000.0)],
        reason: 'lỗi người dùng báo 2026-11-20: ví tắt "Cho phép số dư âm" vẫn âm mà không hỏi gì');
  });

  test('ví CHO PHÉP âm → không hỏi', () {
    expect(viSeAm(vi: [_vi('A', 100000, choPhepAm: true)], moi: [_gd('chi', 150000)]), isEmpty);
  });

  test('vừa đủ (về đúng 0) và khoản thu → không hỏi', () {
    expect(viSeAm(vi: [_vi('A', 100000)], moi: [_gd('chi', 100000)]), isEmpty);
    expect(viSeAm(vi: [_vi('A', -5000)], moi: [_gd('thu', 1000)]), isEmpty,
        reason: 'khoản làm ví TĂNG không bao giờ là lý do hỏi, kể cả khi ví vẫn còn âm');
  });

  test('chuyển khoản: chỉ ví nguồn bị trừ', () {
    final r = viSeAm(
      vi: [_vi('A', 10000), _vi('B', 0)],
      moi: [_gd('transfer', 30000, vi: 'A', den: 'B')],
    );
    expect(r.map((v) => v.ten), ['Ví A']);
  });

  test('khoản tách: cộng mọi phần cùng ví', () {
    final r = viSeAm(
      vi: [_vi('A', 100000)],
      moi: [_gd('chi', 60000, id: 'p1'), _gd('chi', 60000, id: 'p2')],
    );
    expect(r.single.soDuSau, -20000);
  });

  test('sửa: số dư đã gồm khoản cũ — chỉ phần TĂNG thêm mới tính', () {
    // Số dư 20.000 là SAU khi đã trừ khoản chi cũ 80.000; sửa thành 90.000 → còn 10.000, không âm.
    expect(viSeAm(vi: [_vi('A', 20000)], moi: [_gd('chi', 90000)], truoc: _gd('chi', 80000)), isEmpty);
    // Sửa thành 120.000 → -20.000.
    expect(viSeAm(vi: [_vi('A', 20000)], moi: [_gd('chi', 120000)], truoc: _gd('chi', 80000)).single.soDuSau,
        -20000);
  });

  test('sửa: chuyển khoản cũ vào ví B bị đổi đích → ví B mất tiền, có thể âm', () {
    final r = viSeAm(
      vi: [_vi('A', 0), _vi('B', 10000), _vi('C', 0)],
      truoc: _gd('transfer', 50000, vi: 'A', den: 'B'),
      moi: [_gd('transfer', 50000, vi: 'A', den: 'C')],
    );
    expect(r.map((v) => (v.ten, v.soDuSau)), [('Ví B', -40000.0)]);
  });

  test('ví đang âm sẵn mà khoản chi làm âm thêm → vẫn hỏi', () {
    expect(viSeAm(vi: [_vi('A', -1000)], moi: [_gd('chi', 1000)]).single.soDuSau, -2000);
  });

  test('lệch dưới nửa đồng (số dư mang đuôi lẻ) → không hỏi', () {
    expect(viSeAm(vi: [_vi('A', 99999.7)], moi: [_gd('chi', 100000)]), isEmpty);
  });
}
