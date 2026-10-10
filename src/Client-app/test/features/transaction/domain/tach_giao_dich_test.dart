/// A5 mục 11 — tách một khoản chi thành nhiều giao dịch theo danh mục: phần CHÍNH nhận tổng − Σ các phần.
library;

import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/domain/tach_giao_dich.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final mau = TransactionEntity(
    id: 'x',
    walletId: 'w',
    idaccount: 7,
    categoryId: 'an',
    amount: 412000,
    type: 'chi',
    note: 'Bach Hoa Xanh',
    date: DateTime(2026, 10, 7, 18, 42),
    images: const [],
    syncStatus: 'pending',
    isDeleted: false,
    updatedAt: DateTime(2026, 10, 7),
  );
  const p1 = PhanTach(categoryId: 'gd', soTien: 120000, monIds: {2, 3});
  const p2 = PhanTach(categoryId: 'ms', soTien: 42000);

  test('còn lại = tổng − Σ phần', () => expect(conLai(412000, [p1, p2]), 250000));

  test('⭐ kiemTach: còn lại ≤ 0 (cả đuôi lẻ double) → lỗi; hợp lệ → null', () {
    expect(kiemTach(tong: 412000, chinh: 'an', phan: [p1, p2]), isNull);
    expect(kiemTach(tong: 162000, chinh: 'an', phan: [p1, p2]), LoiTach.conLaiKhongDuong);
    expect(kiemTach(tong: 162000.3, chinh: 'an', phan: [p1, p2]), LoiTach.conLaiKhongDuong,
        reason: 'ngưỡng nửa đồng — 0,3 đ không phải một giao dịch');
  });

  test('phần ≤ 0, trùng danh mục (kể cả với chính), một món hai phần', () {
    expect(kiemTach(tong: 9e5, chinh: 'an', phan: [p1.copyWith(soTien: 0)]), LoiTach.phanKhongDuong);
    expect(kiemTach(tong: 9e5, chinh: 'gd', phan: [p1]), LoiTach.trungDanhMuc);
    expect(kiemTach(tong: 9e5, chinh: 'an', phan: [p1, p1.copyWith(categoryId: 'ms')]), LoiTach.monHaiPhan);
  });

  test('đổi danh mục chính sang một danh mục đang tách → bỏ phần ấy', () {
    expect(gopKhiDoiDanhMucChinh('gd', [p1, p2]).map((p) => p.categoryId), ['ms']);
  });

  test('⭐ dựng N giao dịch: chính đứng đầu nhận còn lại; id khác nhau; chung ví, tài khoản, ghi chú, ngày', () {
    var n = 0;
    final ds = dungGiaoDichTach(mau: mau, phan: [p1, p2], taoId: () => 'id${n++}');
    expect([for (final t in ds) (t.categoryId, t.amount)], [('an', 250000.0), ('gd', 120000.0), ('ms', 42000.0)]);
    expect(ds.map((t) => t.id).toSet().length, 3);
    expect(
        ds.every((t) =>
            t.walletId == 'w' &&
            t.idaccount == 7 &&
            t.note == 'Bach Hoa Xanh' &&
            t.date == mau.date &&
            t.type == 'chi' &&
            t.syncStatus == 'pending'),
        isTrue);
  });

  test('id mặc định là uuid khác nhau', () {
    final ds = dungGiaoDichTach(mau: mau, phan: [p1]);
    expect(ds[0].id, isNot(ds[1].id));
    expect(ds[0].id, isNot('x'), reason: 'id của bản mẫu không được dùng lại');
  });
}
