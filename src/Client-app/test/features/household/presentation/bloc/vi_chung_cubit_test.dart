import 'package:flowmoney/features/household/presentation/bloc/vi_chung_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/du_lieu_nha_gia.dart';

void main() {
  test('chưa có dữ liệu: chưa nạp; có luồng đầu thì daNap và đủ ví', () async {
    final nguon = DuLieuNhaGia(vi: [viChungGia('a', 'Tiền chợ', 3200000)]);
    final c = ViChungCubit(nguon, 12);
    addTearDown(c.close);
    expect(c.state.daNap, isFalse, reason: 'trước khi luồng trả lời, khối không được nói "chưa có ví"');
    await Future<void>.delayed(Duration.zero);
    expect(c.state.daNap, isTrue);
    expect(c.state.vi.map((v) => v.id), ['a']);
  });

  test('tongQuy và soDangHoatDong bỏ ví lưu trữ', () async {
    final nguon = DuLieuNhaGia(vi: [
      viChungGia('a', 'Tiền chợ', 3200000),
      viChungGia('b', 'Điện nước', 1250000, loai: 'bank'),
      viChungGia('c', 'Cũ', 9000000, status: 'inactive'),
    ]);
    final c = ViChungCubit(nguon, 12);
    addTearDown(c.close);
    await Future<void>.delayed(Duration.zero);
    expect(c.tongQuy, 4450000, reason: 'ví đã lưu trữ đóng băng, không cộng vào quỹ');
    expect(c.soDangHoatDong, 2, reason: 'ví lưu trữ không tính vào trần');
    expect(c.state.vi, hasLength(3), reason: 'nhưng vẫn ở trong danh sách để còn bỏ lưu trữ được');
  });

  test('ví đổi ở nơi khác (kéo về) thì state đổi theo luồng', () async {
    final nguon = DuLieuNhaGia(vi: [viChungGia('a', 'Tiền chợ', 100)]);
    final c = ViChungCubit(nguon, 12);
    addTearDown(c.close);
    await Future<void>.delayed(Duration.zero);
    nguon.datVi([viChungGia('a', 'Tiền chợ', 100), viChungGia('b', 'Mới', 50)]);
    await Future<void>.delayed(Duration.zero);
    expect(c.soDangHoatDong, 2);
    expect(c.tongQuy, 150);
  });

  test('đóng cubit rồi luồng phát tiếp: không ném', () async {
    final nguon = DuLieuNhaGia();
    final c = ViChungCubit(nguon, 12);
    await Future<void>.delayed(Duration.zero);
    await c.close();
    nguon.datVi([viChungGia('a', 'X', 1)]);
    await Future<void>.delayed(Duration.zero);
  });
}
