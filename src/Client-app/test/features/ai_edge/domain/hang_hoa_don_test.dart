/// Tool `danh_sach_hoa_don`: hàng theo TÊN kèm trạng thái của `billDisplayStatusOf`,
/// tổng hợp từ `summarizeBills` — CÙNG bộ lọc kỳ, để hàng và tổng nói về một
/// tập hoá đơn (bẫy của gói hoá đơn 1.3).
library;

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_hoa_don.dart';
import 'package:flowmoney/features/bill/domain/bill_status.dart';
import 'package:flutter_test/flutter_test.dart';

Bill _bill({
  String id = 'b1',
  required DateTime dueDate,
  double amount = 100000,
  bool isPaid = false,
  String payStatus = 'Pending',
  String ten = 'Tiền điện',
}) =>
    Bill(
      id: id,
      idaccount: 10,
      walletId: 'w1',
      categoryId: 'c1',
      name: ten,
      amount: amount,
      startDate: dueDate.subtract(const Duration(days: 30)),
      dueDate: dueDate,
      payStatus: payStatus,
      isPaid: isPaid,
      autoPayEnabled: false,
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

void main() {
  final now = DateTime(2026, 9, 6, 10, 30);
  final kiem = _bill(id: 'k', ten: 'Kiem', amount: 45000, dueDate: DateTime(2026, 9, 1));
  final dien = _bill(id: 'd', ten: 'Tiền điện', amount: 110000, dueDate: DateTime(2026, 9, 20));
  final daTra = _bill(
      id: 'p',
      ten: 'Internet',
      amount: 200000,
      dueDate: DateTime(2026, 9, 3),
      isPaid: true,
      payStatus: 'Payed');
  final kySau = _bill(id: 's', ten: 'Nước', amount: 70000, dueDate: DateTime(2026, 10, 5));

  test('⭐ qua_han: chỉ hàng quá hạn — TÊN + trạng thái + số tiền, cờ cảnh báo', () {
    final kq = hangHoaDon([dien, kiem, daTra], now: now, trangThai: 'qua_han');
    expect(kq.hang.length, 1);
    final h = kq.hang.single;
    expect(h.ten, 'Kiem');
    expect(h.trangThai, 'đã quá hạn');
    expect(h.canhBao, isTrue);
    expect(h.soLieu.single.nhan, 'Số tiền');
    expect(h.soLieu.single.chuoi, '45.000 đ');
    expect(h.soLieu.single.ten, 'Kiem',
        reason: 'kiemNhan đòi câu nêu tên: SoLieu của hàng phải mang tên hàng');
    expect(h.json, {'ten': 'Kiem', 'trang_thai': 'đã quá hạn', 'Số tiền': '45.000 đ'});
  });

  test('tổng hợp khớp summarizeBills: Còn phải trả, Quá hạn, Chưa trả', () {
    final kq = hangHoaDon([dien, kiem, daTra], now: now);
    final tom = summarizeBills([dien, kiem, daTra], now);
    expect(kq.tongHop.map((s) => '${s.nhan}=${s.chuoi}').toList(), [
      'Còn phải trả=155.000 đ',
      'Quá hạn=1',
      'Chưa trả=2',
    ]);
    expect(kq.tongHop.first.soTho, tom.unpaidAmount);
  });

  test('mặc định chua_tra: quá hạn LẪN chưa trả, hạn sớm trước', () {
    final kq = hangHoaDon([dien, kiem], now: now);
    expect(kq.hang.map((h) => h.ten).toList(), ['Kiem', 'Tiền điện']);
    expect(kq.hang.map((h) => h.trangThai).toList(), ['đã quá hạn', 'chưa trả']);
    expect(kq.hang.map((h) => h.canhBao).toList(), [true, false]);
  });

  test('da_tra: chỉ hoá đơn đã trả', () {
    final kq = hangHoaDon([dien, kiem, daTra], now: now, trangThai: 'da_tra');
    expect(kq.hang.map((h) => h.ten).toList(), ['Internet']);
    expect(kq.hang.single.trangThai, 'đã trả');
  });

  test('kỳ SAU bị loại — cùng phép chặn cuối tháng với thẻ tổng', () {
    final kq = hangHoaDon([kiem, kySau], now: now, trangThai: 'tat_ca');
    expect(kq.hang.map((h) => h.ten).toList(), ['Kiem'],
        reason: 'Hàng liệt kê Nước trong khi tổng bên cạnh không tính Nước là '
            'hai vế của một câu đếm trên hai tập.');
    expect(kq.tongHop[2].chuoi, '1');
  });

  test('trần kToiDaMucMoiGoi hàng; số đếm vẫn đủ', () {
    final nhieu = [
      for (var i = 0; i < 6; i++)
        _bill(id: 'n$i', ten: 'HĐ $i', dueDate: DateTime(2026, 9, 10 + i)),
    ];
    final kq = hangHoaDon(nhieu, now: now);
    expect(kq.hang.length, 4);
    expect(kq.tongHop[2].chuoi, '6');
  });

  test('enum lạ → từ chối, không đoán', () {
    final kq = hangHoaDon([kiem], now: now, trangThai: 'sap_toi');
    expect(kq.hang, isEmpty);
    expect(kq.tongHop, isEmpty);
    expect(kq.loi, contains('sap_toi'));
    expect(kq.loi, contains('qua_han'), reason: 'nói mô hình còn được chọn gì');
  });

  test('chuTrangThaiHoaDon phủ đủ năm trạng thái hiển thị', () {
    expect(chuTrangThaiHoaDon(BillDisplayStatus.overdue), 'đã quá hạn');
    expect(chuTrangThaiHoaDon(BillDisplayStatus.dueSoon), 'sắp đến hạn');
    expect(chuTrangThaiHoaDon(BillDisplayStatus.pending), 'chưa trả');
    expect(chuTrangThaiHoaDon(BillDisplayStatus.paid), 'đã trả');
    expect(chuTrangThaiHoaDon(BillDisplayStatus.skipped), 'bỏ qua');
  });
}
