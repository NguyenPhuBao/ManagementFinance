/// Adapter tool hoá đơn: bộ chỉnh tham số theo câu hỏi (`chinhThamSoHoaDon`) →
/// đọc `watchBills` đúng tài khoản → `hangHoaDon`. Fake ghi đè noSuchMethod —
/// hàm mới lỡ gọi thêm sẽ ném.
library;

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/ai_edge/data/cong_cu_hoa_don.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_hoa_don.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Bill _bill(String ten, DateTime dueDate, {bool tuTra = false}) => Bill(
      id: ten,
      idaccount: 10,
      walletId: 'w1',
      categoryId: 'c1',
      name: ten,
      amount: 45000,
      startDate: dueDate.subtract(const Duration(days: 30)),
      dueDate: dueDate,
      payStatus: 'Pending',
      isPaid: false,
      autoPayEnabled: tuTra,
      timeNotification: '3',
      isRecurrence: true,
      timeRecurrence: kBillCycleMonth,
      recurrence: 'monthly',
      icon: 'receipt',
      colour: '#4CAF50',
      note: '',
      isDeleted: false,
      syncStatus: 'synced',
      syncRetryCount: 0,
      updatedAt: DateTime(2026, 9, 1),
    );

class _HoaDon implements BillRepository {
  final daHoi = <int>[];
  @override
  Stream<List<Bill>> watchBills(int idaccount) {
    daHoi.add(idaccount);
    return Stream.value([
      _bill('Kiem', DateTime(2026, 9, 1)),
      _bill('Netflix', DateTime(2026, 9, 28), tuTra: true),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

void main() {
  final now = DateTime(2026, 9, 22, 10);

  test('khai báo: ky ba giá trị, trang_thai bốn giá trị, không tham số bắt buộc; mô tả nêu câu hỏi mới', () {
    final k = CongCuHoaDon(_HoaDon()).khaiBao;
    expect(k.ten, kTenCongCuHoaDon);
    expect(k.moTa, contains('Gọi khi'));
    expect(k.moTa, contains('tháng tới'));
    expect(k.moTa, contains('tự trả'));
    expect(k.moTa, contains('cố định mỗi tháng'));
    expect(k.thamSo['required'], isNull);
    final p = k.thamSo['properties'] as Map;
    expect((p['ky'] as Map)['enum'], kKyHoaDon);
    expect((p['trang_thai'] as Map)['enum'], kTrangThaiHoaDon);
  });

  test('⭐ F11 đầu-cuối: "thang toi toi phai tra hoa don nao" với args rỗng → kỳ dự kiến tháng 10', () async {
    final log = <String>[];
    final kq = await CongCuHoaDon(_HoaDon(), log: log.add).chay({}, idaccount: 10, now: now,
        cauHoi: 'thang toi toi phai tra hoa don nao');
    expect(kq.hang.map((h) => '${h.ten}|${h.trangThai}|${h.json['Đến hạn']}').toList(),
        ['Kiem|dự kiến|01/10', 'Netflix|dự kiến · tự trả|28/10']);
    expect(kq.chuThem['ky'], 'kỳ tới');
    expect(log.single, contains('ky=ky_toi'));
  });

  test('mô hình điền ky thừa cho câu về kỳ này → gỡ, trả hoá đơn kỳ này', () async {
    final kq = await CongCuHoaDon(_HoaDon(), log: (_) {}).chay({'ky': 'ky_toi'}, idaccount: 10, now: now,
        cauHoi: 'hoa don nao qua han');
    expect(kq.hang.map((h) => h.ten).toList(), ['Kiem', 'Netflix']);
    expect(kq.chuThem.containsKey('ky'), isFalse);
  });

  test('đọc watchBills đúng tài khoản; không câu hỏi thì tham số mô hình đi thẳng', () async {
    final repo = _HoaDon();
    final kq = await CongCuHoaDon(repo, log: (_) {})
        .chay({'ky': 'tat_ca', 'trang_thai': 'qua_han'}, idaccount: 10, now: now);
    expect(repo.daHoi, [10]);
    expect(kq.hang.map((h) => h.ten).toList(), ['Kiem']);
    expect(kq.chuThem['ky'], 'mọi kỳ');
  });

  test('ky lạ của mô hình, không câu hỏi → từ chối chứ không đoán', () async {
    final kq = await CongCuHoaDon(_HoaDon(), log: (_) {})
        .chay({'ky': 'thang_nay'}, idaccount: 10, now: now);
    expect(kq.loi, contains('ky_nay'));
  });
}
