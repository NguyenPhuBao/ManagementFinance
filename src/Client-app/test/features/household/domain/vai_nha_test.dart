import 'package:flowmoney/features/household/domain/vai_nha.dart';
import 'package:flutter_test/flutter_test.dart';

/// Vai / trạng thái nhà ↔ chữ của server (đơn 50 mục 1, C.1).
void main() {
  test('vai server ↔ enum, đi hai chiều', () {
    for (final v in VaiNha.values) {
      expect(vaiNhaTuServer(khoaServerCuaVai(v)), v);
    }
    expect(khoaServerCuaVai(VaiNha.chu), 'Owner');
    expect(khoaServerCuaVai(VaiNha.thanhVien), 'Member');
    expect(khoaServerCuaVai(VaiNha.chiXem), 'Viewer');
  });

  test('vai lạ / thiếu → chỉ xem (quyền ít nhất)', () {
    expect(vaiNhaTuServer('Admin'), VaiNha.chiXem,
        reason: 'đoán rộng là mở nút ghi cho người server sẽ từ chối — lỗi vĩnh viễn ở mọi lần đẩy');
    expect(vaiNhaTuServer(null), VaiNha.chiXem);
  });

  test('trạng thái server ↔ enum; lạ / thiếu → chỉ xem', () {
    for (final t in TrangThaiNha.values) {
      expect(trangThaiNhaTuServer(khoaServerCuaTrangThai(t)), t);
    }
    expect(khoaServerCuaTrangThai(TrangThaiNha.chiXem), 'ReadOnly');
    expect(trangThaiNhaTuServer('Frozen'), TrangThaiNha.chiXem);
  });

  test('tên vai tiếng Việt (spec mục 1)', () {
    expect(VaiNha.values.map(tenVai), ['Chủ nhà', 'Thành viên', 'Chỉ xem']);
  });
}
