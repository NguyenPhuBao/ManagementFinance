/// Số ngày nhắc trước hạn của hoá đơn — `bill_nhac_truoc.dart`.
///
/// `timeNotification` NULL nghĩa là **tắt nhắc** (form Thêm hoá đơn ghi NULL khi
/// tắt công tắc "Nhắc trước hạn"; màn Chi tiết và sheet Thanh toán hiện
/// "Không nhắc"; mục 7b `BILL_DOCUMENTATION.md`). Trước 2026-10-16 bộ luật và
/// bộ đặt lịch đọc NULL thành "theo tuỳ chọn chung" nên hoá đơn đã tắt nhắc vẫn
/// được nhắc — người dùng chốt "tắt là tắt thật".
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/bill/data/models/bill_entity.dart';
import 'package:flowmoney/features/bill/domain/bill_nhac_truoc.dart';
import 'package:flowmoney/features/bill/domain/bill_recurrence.dart';

BillEntity _hoaDon(String? nhac) => BillEntity(
      id: 'b1',
      idaccount: 10,
      walletId: 'w1',
      categoryId: 'c1',
      name: 'Tiền điện',
      amount: 100000,
      startDate: DateTime(2026, 9, 1),
      dueDate: DateTime(2026, 9, 30),
      payStatus: 'Pending',
      isPaid: false,
      autoPayEnabled: false,
      timeNotification: nhac,
      isRecurrence: true,
      timeRecurrence: kBillCycleMonth,
      recurrence: 'monthly',
      icon: 'receipt',
      colour: '#4CAF50',
      note: '',
      isDeleted: false,
      syncStatus: 'synced',
      updatedAt: DateTime(2026, 9, 1),
    );

void main() {
  group('soNgayNhacRieng', () {
    test('hoá đơn đặt số ngày thì trả đúng số ấy', () {
      expect(soNgayNhacRieng(_hoaDon('7')), 7,
          reason: 'Bốn mốc form cho chọn là 1 · 3 · 5 · 7.');
      expect(soNgayNhacRieng(_hoaDon('1')), 1,
          reason: 'Mốc nhỏ nhất của form cũng phải đọc ra đúng số.');
    });

    test('NULL là TẮT nhắc — không có số ngày nào', () {
      expect(soNgayNhacRieng(_hoaDon(null)), isNull,
          reason: 'Form ghi NULL khi tắt công tắc "Nhắc trước hạn". Đọc NULL '
              'thành một số mặc định là hoá đơn đã tắt nhắc vẫn bị nhắc.');
    });

    test('chuỗi rỗng hay chữ lạ cũng là tắt nhắc, không phải mặc định', () {
      expect(soNgayNhacRieng(_hoaDon('')), isNull,
          reason: 'Mục 7b chỉ cho 1 · 3 · 5 · 7 hoặc NULL; giá trị không đọc '
              'được không được biến thành một lời nhắc người dùng không chọn.');
      expect(soNgayNhacRieng(_hoaDon('abc')), isNull,
          reason: 'Cùng lý lẽ với chuỗi rỗng.');
    });
  });

  group('billLeadDays (nhãn "Sắp đến hạn")', () {
    test('hoá đơn tắt nhắc dùng số ngày mặc định nơi gọi truyền vào', () {
      expect(billLeadDays(_hoaDon(null), fallback: 7), 7,
          reason: 'Nhãn vẫn cần một ngưỡng cho hoá đơn tắt nhắc — lấy từ tuỳ '
              'chọn "Nhắc trước" trong Cài đặt thông báo.');
    });

    test('hoá đơn đặt số ngày thì số ấy thắng mặc định', () {
      expect(billLeadDays(_hoaDon('1'), fallback: 7), 1,
          reason: 'Cùng số ngày bộ nhắc dùng cho hoá đơn ấy — nhãn và dải '
              'nhắc phải nói cùng một chuyện.');
    });
  });
}
