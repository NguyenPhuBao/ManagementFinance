/// Luật "đơn cần xử lý" của màn Nâng cấp và lý do hoàn tiền của màn Chi tiết đơn (spec G94 2026-10-18 mục 5.1).
library;

import 'package:flowmoney/features/premium/data/models/dong_lich_su.dart';
import 'package:flowmoney/features/premium/domain/don_can_xu_ly.dart';
import 'package:flowmoney/features/premium/domain/trang_thai_don.dart';
import 'package:flutter_test/flutter_test.dart';

DongLichSu _don(int ma, TrangThaiDon t, {int? daChuyen, DateTime? tao}) => DongLichSu(
    orderCode: ma, soTien: 49000, trangThai: t, soDaChuyen: daChuyen, taoLuc: tao ?? DateTime.utc(2026, 10, ma));

void main() {
  test('donChoXacNhan / donChoHoanTien lọc đúng trạng thái, mới nhất trước', () {
    final ds = [
      _don(1, TrangThaiDon.waitingConfirmation),
      _don(2, TrangThaiDon.paid),
      _don(3, TrangThaiDon.refundPending),
      _don(4, TrangThaiDon.waitingConfirmation),
    ];
    expect(donChoXacNhan(ds).map((d) => d.orderCode), [4, 1]);
    expect(donChoHoanTien(ds).map((d) => d.orderCode), [3]);
    expect(donChoXacNhan(const []), isEmpty);
  });

  test('lyDoHoanTien ba nhánh: thiếu · đã từ chối (thừa) · không rõ (bằng / thiếu số)', () {
    expect(lyDoHoanTien(_don(1, TrangThaiDon.refundPending, daChuyen: 40000)), LyDoHoanTien.chuyenThieu);
    expect(lyDoHoanTien(_don(1, TrangThaiDon.refundPending, daChuyen: 60000)), LyDoHoanTien.daTuChoi);
    expect(lyDoHoanTien(_don(1, TrangThaiDon.refundPending, daChuyen: 49000)), LyDoHoanTien.khongRo);
    expect(lyDoHoanTien(_don(1, TrangThaiDon.refundPending)), LyDoHoanTien.khongRo,
        reason: 'thiếu số đã chuyển thì không đoán lý do');
  });

  test('soTienLech = đã chuyển − giá gói; thiếu số → null', () {
    expect(soTienLech(_don(1, TrangThaiDon.waitingConfirmation, daChuyen: 60000)), 11000);
    expect(soTienLech(_don(1, TrangThaiDon.refundPending, daChuyen: 40000)), -9000);
    expect(soTienLech(_don(1, TrangThaiDon.refundPending)), isNull);
  });
}
