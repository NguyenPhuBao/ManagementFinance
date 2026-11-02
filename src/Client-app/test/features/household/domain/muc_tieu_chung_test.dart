import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/household/domain/muc_tieu_chung.dart';

void main() {
  final now = DateTime(2026, 11, 2);
  final moc = DateTime(2026, 11, 1);

  GoalEntity goal({DateTime? han}) => GoalEntity(
        id: 'g',
        idaccount: 10,
        idhousehold: 5,
        name: 'Quỹ',
        targetAmount: 20000000,
        targetDate: han ?? DateTime(2027, 12, 31),
        walletId: 'v',
        updatedAt: moc,
      );

  test('60 %, còn thiếu, ví dụ 8 triệu / 2 tháng = 4 triệu', () {
    final t = tienDoMucTieuChung(mucTieu: goal(han: DateTime(2026, 12, 31)), soDuVi: 12000000, now: now);
    expect(t.tiLe, closeTo(.6, 1e-9));
    expect(t.conThieu, 8000000);
    expect(t.conNgay, 59);
    expect(t.canGopMoiThang, 4000000);
    expect(t.trangThai, TrangThaiMucTieuChung.dangChay);
  });

  test('số dư âm tính 0 %, còn thiếu đủ mục tiêu', () {
    final t = tienDoMucTieuChung(mucTieu: goal(), soDuVi: -500000, now: now);
    expect(t.tiLe, 0);
    expect(t.soDu, 0);
    expect(t.conThieu, 20000000);
  });

  test('vượt mục tiêu là đã đạt, kể cả đã quá hạn; không còn câu cần góp', () {
    final t = tienDoMucTieuChung(mucTieu: goal(han: DateTime(2026, 1, 1)), soDuVi: 21000000, now: now);
    expect(t.trangThai, TrangThaiMucTieuChung.daDat);
    expect(t.tiLe, 1);
    expect(t.conThieu, 0);
    expect(t.canGopMoiThang, isNull);
  });

  test('quá hạn chưa đạt: không có câu cần góp; đúng ngày hạn chưa phải quá hạn', () {
    expect(tienDoMucTieuChung(mucTieu: goal(han: DateTime(2026, 11, 1)), soDuVi: 1, now: now).trangThai,
        TrangThaiMucTieuChung.quaHan);
    expect(tienDoMucTieuChung(mucTieu: goal(han: DateTime(2026, 11, 1)), soDuVi: 1, now: now).canGopMoiThang,
        isNull);
    expect(tienDoMucTieuChung(mucTieu: goal(han: now), soDuVi: 1, now: now).trangThai,
        TrangThaiMucTieuChung.dangChay);
  });

  test('cờ isCompleted cũ không làm giả trạng thái đã đạt (03 mục 3: suy ra, không ghi cờ)', () {
    final g = goal().copyWith(isCompleted: true);
    expect(tienDoMucTieuChung(mucTieu: g, soDuVi: 1, now: now).trangThai, TrangThaiMucTieuChung.dangChay,
        reason: 'Mục tiêu chung suy "đã đạt" từ số dư ví; cờ cũ không được quyết');
  });

  test('không đọc currentAmount', () {
    final g = goal().copyWith(currentAmount: 19000000);
    expect(tiLeMucTieuChung(g, 2000000), closeTo(.1, 1e-9),
        reason: 'Tiến độ lấy từ số dư ví, không từ cột cộng dồn mà nhiều người góp offline sẽ đè nhau');
  });

  test('hạn còn dưới 1 tháng tính 1 tháng; làm tròn lên', () {
    expect(soThangConLai(now, DateTime(2026, 11, 20)), 1);
    final t = tienDoMucTieuChung(
        mucTieu: goal(han: DateTime(2027, 2, 2)).copyWith(targetAmount: 1000000), soDuVi: 0, now: now);
    expect(t.canGopMoiThang, 333334);
  });

  test('tháng ngắn và năm nhuận theo lịch thật', () {
    expect(soThangConLai(DateTime(2026, 1, 31), DateTime(2026, 2, 28)), 1);
    expect(soThangConLai(DateTime(2026, 1, 31), DateTime(2026, 3, 1)), 2);
    expect(soThangConLai(DateTime(2028, 1, 31), DateTime(2028, 2, 29)), 1);
    expect(soThangConLai(DateTime(2027, 1, 31), DateTime(2027, 2, 28)), 1);
  });

  test('hai hàng sống cùng ví: lấy updatedAt mới nhất; bỏ hàng không có ví, hàng đã xoá', () {
    final cu = goal().copyWith(id: 'cu', updatedAt: DateTime(2026, 1, 1));
    final moi = goal().copyWith(id: 'moi', updatedAt: DateTime(2026, 2, 1));
    expect(mucTieuTheoVi([moi, cu])['v']!.id, 'moi');
    expect(mucTieuTheoVi([cu, moi])['v']!.id, 'moi');
    expect(mucTieuTheoVi([goal().copyWith(isDeleted: true)]), isEmpty);
  });

  test('kiểm ô nhập', () {
    expect(loiNhapMucTieu(soTienChu: '', han: now, hanLucMo: null, now: now), 'Vui lòng nhập số tiền mục tiêu');
    expect(loiNhapMucTieu(soTienChu: '0', han: now, hanLucMo: null, now: now), 'Vui lòng nhập số tiền mục tiêu');
    expect(loiNhapMucTieu(soTienChu: '1.000', han: null, hanLucMo: null, now: now), 'Vui lòng chọn hạn');
    expect(loiNhapMucTieu(soTienChu: '1.000', han: DateTime(2026, 11, 1), hanLucMo: null, now: now),
        'Hạn phải từ hôm nay trở đi');
    // Sửa mục tiêu đã quá hạn mà giữ hạn cũ: đổi số tiền vẫn được.
    expect(loiNhapMucTieu(soTienChu: '1.000', han: DateTime(2026, 1, 1), hanLucMo: DateTime(2026, 1, 1), now: now),
        isNull);
    expect(loiNhapMucTieu(soTienChu: '1.000', han: now, hanLucMo: null, now: now), isNull);
  });
}
