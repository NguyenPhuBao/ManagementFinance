import 'dart:async';

import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/household/presentation/bloc/vi_chung_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/du_lieu_nha_gia.dart';

void main() {
  mucTieuMain();

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

GoalEntity _muc(String viId, {double dich = 20000000}) => GoalEntity(
      id: 'g-$viId',
      idaccount: 18,
      idhousehold: 12,
      name: 'Mục tiêu',
      targetAmount: dich,
      targetDate: DateTime(2026, 12, 31),
      walletId: viId,
      updatedAt: DateTime(2026, 11, 1),
    );

/// Luồng mục tiêu do ca điều khiển: chưa phát gì cho tới khi gọi `phat`, hoặc ném lỗi.
class _NguonMucTre extends DuLieuNhaGia {
  _NguonMucTre({super.vi});

  final ctl = StreamController<List<GoalEntity>>();

  @override
  Stream<List<GoalEntity>> theoDoiMucTieuChung(int idNha) => ctl.stream;
}

void mucTieuMain() {
  test('daNap chỉ đúng khi CẢ HAI luồng đã phát lần đầu', () async {
    final nguon = _NguonMucTre(vi: [viChungGia('a', 'Tiền chợ', 100)]);
    final c = ViChungCubit(nguon, 12);
    addTearDown(() async {
      await c.close();
      await nguon.ctl.close();
    });
    await Future<void>.delayed(Duration.zero);
    expect(c.state.vi, hasLength(1));
    expect(c.state.daNap, isFalse,
        reason: 'ví về trước mục tiêu mà đã daNap thì thẻ hiện không thanh rồi nhấp nháy sang có thanh');
    nguon.ctl.add([_muc('a')]);
    await Future<void>.delayed(Duration.zero);
    expect(c.state.daNap, isTrue);
    expect(c.state.mucTieu.keys, ['a']);
  });

  test('mục tiêu về sau ví vẫn dựng đúng; mục tiêu đổi thì state đổi', () async {
    final nguon = DuLieuNhaGia(vi: [viChungGia('a', 'Tiền chợ', 100)]);
    final c = ViChungCubit(nguon, 12);
    addTearDown(c.close);
    await Future<void>.delayed(Duration.zero);
    expect(c.state.mucTieu, isEmpty);
    nguon.datMucTieu([_muc('a')]);
    await Future<void>.delayed(Duration.zero);
    expect(c.state.mucTieu['a']?.targetAmount, 20000000);
    expect(c.state.vi, hasLength(1), reason: 'mục tiêu về không làm mất ví');
  });

  test('luồng mục tiêu hỏng: daNap vẫn đúng, mucTieu rỗng, ví vẫn hiện', () async {
    final nguon = _NguonMucTre(vi: [viChungGia('a', 'Tiền chợ', 100)]);
    final c = ViChungCubit(nguon, 12);
    addTearDown(() async {
      await c.close();
      await nguon.ctl.close();
    });
    nguon.ctl.addError(StateError('hỏng'));
    await Future<void>.delayed(Duration.zero);
    expect(c.state.daNap, isTrue, reason: 'khối không được quay mãi vì luồng mục tiêu hỏng');
    expect(c.state.mucTieu, isEmpty);
    expect(c.state.vi, hasLength(1));
  });

  test('close huỷ cả hai luồng', () async {
    final nguon = _NguonMucTre(vi: [viChungGia('a', 'X', 1)]);
    final c = ViChungCubit(nguon, 12);
    await Future<void>.delayed(Duration.zero);
    expect(nguon.ctl.hasListener, isTrue);
    await c.close();
    expect(nguon.ctl.hasListener, isFalse, reason: 'luồng mục tiêu phải bị huỷ khi đóng cubit');
    await nguon.ctl.close();
  });
}
