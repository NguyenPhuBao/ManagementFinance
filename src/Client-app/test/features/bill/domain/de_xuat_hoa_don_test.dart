/// Chọn gợi ý tạo hoá đơn từ khoản lặp (B2) — loại nhóm đã có hoá đơn đang sống
/// hoặc đã bị phản hồi ẩn, trần 3, `null` khi không còn gì.
///
/// Spec: docs/superpowers/specs/2026-09-28-b2-khoan-lap-goi-y-hoa-don-design.md
/// mục 2 (hoá đơn trùng tên), 3 (phản hồi), 4 (chọn).
library;

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/domain/bill_pay_status.dart';
import 'package:flowmoney/features/bill/domain/de_xuat_hoa_don.dart';
import 'package:flowmoney/features/transaction/domain/khoan_lap.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 20);

KhoanLap _kl(String ghiChu, {String cat = 'c-nha', int soLan = 3, DateTime? ganNhat}) => KhoanLap(
      khoaNhom: '$ghiChu|$cat',
      ten: ghiChu,
      soTien: 100000,
      chuKy: kBillCycleMonth,
      ngayGoc: 5,
      ngayGanNhat: ganNhat ?? DateTime(2026, 11, 5),
      categoryId: cat,
      walletId: 'v1',
      soLan: soLan,
    );

Bill _bill(
  String ten, {
  String payStatus = kBillPending,
  bool isPaid = false,
  bool isRecurrence = false,
  bool xoa = false,
}) =>
    Bill(
      id: 'b-$ten',
      idaccount: 10,
      walletId: 'w1',
      categoryId: 'c-nha',
      name: ten,
      amount: 100000,
      startDate: DateTime(2026, 10, 1),
      dueDate: DateTime(2026, 11, 1),
      payStatus: payStatus,
      isPaid: isPaid,
      autoPayEnabled: false,
      timeNotification: '3',
      isRecurrence: isRecurrence,
      timeRecurrence: kBillCycleMonth,
      recurrence: 'monthly',
      icon: 'receipt',
      colour: '#4CAF50',
      note: '',
      isDeleted: xoa,
      syncStatus: 'synced',
      syncRetryCount: 0,
      updatedAt: DateTime(2026, 10, 1),
    );

GoiYHoaDonPhanHoi _ph(String khoa, String ketQua, DateTime luc) => GoiYHoaDonPhanHoi(
      id: '$khoa-$ketQua-${luc.toIso8601String()}',
      idaccount: 10,
      khoaNhom: khoa,
      ketQua: ketQua,
      createdAt: luc,
    );

Transaction _gd(DateTime ngay, {String note = 'Tiền nhà', String cat = 'c-nha'}) => Transaction(
      id: '${ngay.toIso8601String()}-$note',
      walletId: 'v1',
      idaccount: 10,
      categoryId: cat,
      amount: 100000,
      type: 'chi',
      status: 'completed',
      provider: 'Manual',
      note: note,
      date: ngay,
      images: '',
      syncStatus: 'synced',
      syncRetryCount: 0,
      updatedAt: ngay,
      isDeleted: false,
    );

List<KhoanLap>? _chon({
  List<KhoanLap>? ds,
  List<Bill> hoaDon = const [],
  List<GoiYHoaDonPhanHoi> phanHoi = const [],
  List<Transaction> giaoDich = const [],
}) =>
    chonDeXuatHoaDon(
      ds: ds ?? [_kl('tien nha'), _kl('netflix', cat: 'c-giai')],
      hoaDon: hoaDon,
      phanHoi: phanHoi,
      giaoDich: giaoDich,
      now: _now,
    );

List<String> _khoa(List<KhoanLap>? r) => [for (final k in r!) k.khoaNhom];

void main() {
  test('đối chứng: không hoá đơn, không phản hồi → trả cả hai', () {
    expect(_khoa(_chon()), containsAll(['tien nha|c-nha', 'netflix|c-giai']));
  });

  group('hoá đơn đang sống trùng tên', () {
    test('hoá đơn còn phải trả tên "Tiền nhà T10" → nhóm tien nha bị loại', () {
      expect(_khoa(_chon(hoaDon: [_bill('Tiền nhà T10')])), ['netflix|c-giai'],
          reason: 'người dùng đã có hoá đơn thì không gợi ý lại khoản ghi tay cùng tên');
    });
    test('hoá đơn đã trả nhưng LẶP → vẫn là đang sống, vẫn loại', () {
      expect(
          _khoa(_chon(hoaDon: [_bill('Tiền nhà', payStatus: kBillPayed, isPaid: true, isRecurrence: true)])),
          ['netflix|c-giai']);
    });
    test('hoá đơn cùng tên đã XOÁ → không loại', () {
      expect(_khoa(_chon(hoaDon: [_bill('Tiền nhà', xoa: true)])), contains('tien nha|c-nha'));
    });
    test('hoá đơn đã trả hết và KHÔNG lặp → không loại', () {
      expect(_khoa(_chon(hoaDon: [_bill('Tiền nhà', payStatus: kBillPayed, isPaid: true)])),
          contains('tien nha|c-nha'),
          reason: 'một hoá đơn một lần đã xong không phải cái người dùng đang theo dõi');
    });
  });

  group('phản hồi', () {
    final moc = DateTime(2026, 10, 1, 12);
    final boQua = [_ph('tien nha|c-nha', kGoiYBoQua, moc)];
    final truocMoc = [for (var d = 1; d <= 5; d++) _gd(DateTime(2026, 9, d))];

    test('bo_qua, chỉ khoản TRƯỚC mốc → ẩn (khoản cũ không phải bằng chứng mới)', () {
      expect(_khoa(_chon(phanHoi: boQua, giaoDich: truocMoc)), ['netflix|c-giai']);
    });
    test('bo_qua + 2 khoản sau mốc → vẫn ẩn', () {
      final sau = [_gd(DateTime(2026, 10, 5)), _gd(DateTime(2026, 11, 5))];
      expect(_khoa(_chon(phanHoi: boQua, giaoDich: [...truocMoc, ...sau])), ['netflix|c-giai']);
    });
    test('bo_qua + 3 khoản sau mốc → hiện lại', () {
      final sau = [_gd(DateTime(2026, 10, 5)), _gd(DateTime(2026, 11, 5)), _gd(DateTime(2026, 11, 6))];
      expect(_khoa(_chon(phanHoi: boQua, giaoDich: sau)), contains('tien nha|c-nha'),
          reason: 'bằng chứng mới thắng lời từ chối cũ (cùng luật B1)');
    });
    test('khoản sau mốc của NHÓM KHÁC không tính', () {
      final sau = [for (var d = 2; d <= 6; d++) _gd(DateTime(2026, 11, d), note: 'Netflix', cat: 'c-giai')];
      expect(_khoa(_chon(phanHoi: boQua, giaoDich: sau)), ['netflix|c-giai']);
    });
    test('mốc là lần bo_qua CUỐI', () {
      final hai = [
        _ph('tien nha|c-nha', kGoiYBoQua, DateTime(2026, 9, 1)),
        _ph('tien nha|c-nha', kGoiYBoQua, DateTime(2026, 11, 1)),
      ];
      final giua = [_gd(DateTime(2026, 10, 1)), _gd(DateTime(2026, 10, 2)), _gd(DateTime(2026, 10, 3))];
      expect(_khoa(_chon(phanHoi: hai, giaoDich: giua)), ['netflix|c-giai'],
          reason: 'ba khoản nằm giữa hai lần bỏ qua — lần bỏ qua sau đã từ chối chúng');
    });
    test('da_tao → ẩn dù có 10 khoản sau', () {
      final sau = [for (var d = 2; d <= 11; d++) _gd(DateTime(2026, 11, d))];
      expect(
          _khoa(_chon(phanHoi: [_ph('tien nha|c-nha', kGoiYDaTao, DateTime(2026, 11, 1))], giaoDich: sau)),
          ['netflix|c-giai'],
          reason: 'người dùng có thể đổi tên trong form — phép so tên không bắt được nữa');
    });
  });

  test('5 ứng viên → trả 3, xếp theo soLan giảm dần rồi ngayGanNhat mới nhất', () {
    final r = _chon(ds: [
      _kl('a', soLan: 3, ganNhat: DateTime(2026, 11, 1)),
      _kl('b', soLan: 5, ganNhat: DateTime(2026, 10, 1)),
      _kl('c', soLan: 3, ganNhat: DateTime(2026, 11, 9)),
      _kl('d', soLan: 4, ganNhat: DateTime(2026, 11, 1)),
      _kl('e', soLan: 3, ganNhat: DateTime(2026, 11, 5)),
    ]);
    expect(_khoa(r), ['b|c-nha', 'd|c-nha', 'c|c-nha']);
  });

  test('không còn ứng viên → null, không phải danh sách rỗng', () {
    expect(_chon(ds: const []), isNull);
    expect(_chon(ds: [_kl('tien nha')], hoaDon: [_bill('Tiền nhà')]), isNull,
        reason: 'chỗ gọi ẩn hẳn thẻ; danh sách rỗng buộc widget tự nghĩ ra luật ẩn');
  });
}
