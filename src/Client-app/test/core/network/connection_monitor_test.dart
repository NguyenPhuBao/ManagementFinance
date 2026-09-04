/// `ConnectionMonitor` — biến luồng thay đổi kết nối thô của hệ điều hành
/// thành hai sự kiện đáng nói với người dùng: **mất mạng** và **có lại**.
///
/// Toàn bộ giá trị của lớp này nằm ở **ngưỡng ổn định**. `onConnectivityChanged`
/// bắn rất nhiều: đi thang máy, qua hầm, chuyển giữa Wi-Fi và 4G — mỗi cú đều
/// là một sự kiện. Báo thẳng ra giao diện thì banner nhấp nháy liên tục và
/// người dùng học được cách phớt lờ nó, kể cả lúc mất mạng thật.
///
/// Vì thế: chỉ báo khi trạng thái **giữ nguyên** đủ lâu. Mất mạng nửa giây rồi
/// có lại thì coi như chưa từng mất — vì với người dùng, đúng là chưa từng.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/network/connection_monitor.dart';

/// Connectivity giả: test tự quyết định khi nào "đổi mạng".
class _ConnectivityGia implements Connectivity {
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();
  List<ConnectivityResult> hienTai = [ConnectivityResult.wifi];

  void doi(List<ConnectivityResult> moi) {
    hienTai = moi;
    _controller.add(moi);
  }

  void mat() => doi([ConnectivityResult.none]);
  void co() => doi([ConnectivityResult.wifi]);

  Future<void> dong() => _controller.close();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => hienTai;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  // Ngưỡng ngắn để test chạy nhanh; trên máy thật là vài giây.
  const nguong = Duration(milliseconds: 60);

  late _ConnectivityGia mang;
  late ConnectionMonitor monitor;
  late List<ConnectionEvent> daNhan;
  late StreamSubscription<ConnectionEvent> sub;

  setUp(() async {
    mang = _ConnectivityGia();
    monitor = ConnectionMonitor(connectivity: mang, onDinhSau: nguong);
    daNhan = [];
    sub = monitor.events.listen(daNhan.add);
    await monitor.start();
  });

  tearDown(() async {
    await sub.cancel();
    monitor.dispose();
    await mang.dong();
  });

  /// Chờ quá ngưỡng để bộ đếm ổn định kịp nổ.
  Future<void> choOnDinh() =>
      Future<void>.delayed(nguong + const Duration(milliseconds: 40));

  test('mất mạng đủ lâu thì báo mất', () async {
    mang.mat();
    await choOnDinh();

    expect(daNhan, [ConnectionEvent.mat]);
  });

  test('có mạng lại sau khi đã mất thì báo khôi phục', () async {
    mang.mat();
    await choOnDinh();
    mang.co();
    await choOnDinh();

    expect(daNhan, [ConnectionEvent.mat, ConnectionEvent.khoiPhuc]);
  });

  test('mất mạng CHỚP NHOÁNG dưới ngưỡng thì không báo gì', () async {
    mang.mat();
    await Future<void>.delayed(const Duration(milliseconds: 15));
    mang.co();
    await choOnDinh();

    expect(daNhan, isEmpty,
        reason: 'Đây là lý do lớp này tồn tại. Một cú nhấp nháy của sóng mà '
            'bắn banner "mất kết nối" rồi "đã kết nối lại" trong nửa giây là '
            'dạy người dùng phớt lờ banner — kể cả lúc mất mạng thật.');
  });

  test('nhiều cú nhấp nháy liên tiếp vẫn không báo gì', () async {
    for (var i = 0; i < 5; i++) {
      mang.mat();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      mang.co();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await choOnDinh();

    expect(daNhan, isEmpty,
        reason: 'Đi tàu hoả qua vùng sóng yếu sinh ra đúng chuỗi này.');
  });

  test('đang online lúc khởi động thì KHÔNG báo "khôi phục"', () async {
    await choOnDinh();

    expect(daNhan, isEmpty,
        reason: 'Mở app khi mạng vẫn tốt mà hiện "Đã kết nối lại" là nói về '
            'một sự cố chưa từng xảy ra.');
  });

  test('mất mạng hai lần thật thì báo hai lần', () async {
    mang.mat();
    await choOnDinh();
    mang.co();
    await choOnDinh();
    mang.mat();
    await choOnDinh();

    expect(daNhan, [
      ConnectionEvent.mat,
      ConnectionEvent.khoiPhuc,
      ConnectionEvent.mat,
    ], reason: 'Khác với thông báo lưu trong CSDL, banner không chống trùng '
        'theo ngày — mất mạng lần thứ hai vẫn là tin người dùng cần biết.');
  });

  test('trạng thái mạng giữ nguyên thì không sinh sự kiện thừa', () async {
    mang.doi([ConnectivityResult.wifi]);
    await choOnDinh();
    mang.doi([ConnectivityResult.mobile]);
    await choOnDinh();

    expect(daNhan, isEmpty,
        reason: 'Chuyển từ Wi-Fi sang 4G vẫn là có mạng. Người dùng không cần '
            'biết, và báo là nhiễu.');
  });

  test('dispose rồi thì không phát thêm gì', () async {
    monitor.dispose();
    mang.mat();
    await choOnDinh();

    expect(daNhan, isEmpty,
        reason: 'Đăng xuất xong mà bộ theo dõi còn sống là banner của phiên cũ '
            'hiện trên màn hình phiên mới.');
  });
}
