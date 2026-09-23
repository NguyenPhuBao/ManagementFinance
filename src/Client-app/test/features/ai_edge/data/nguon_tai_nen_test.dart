/// Giao diện `NguonTaiNen` và bản giả của nó.
///
/// Bản giả là thứ mọi test tầng trên dùng — nó phải cư xử đúng như bản thật ở
/// những chỗ có thể đo được mà không cần máy Android.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/ai_edge/data/nguon_tai_nen.dart';

void main() {
  test('bản giả: chưa bắt đầu thì KHÔNG có lượt nào đang sống', () async {
    final n = NguonTaiNenGia();
    expect(await n.luotDangSong(), isNull,
        reason: '`null` nghĩa là "không có lượt", khác hẳn "có lượt ở 0%".');
  });

  test('bản giả: batDau phát dangChay và nhớ được chiWifi', () async {
    final n = NguonTaiNenGia();
    final thu = <TinLuot>[];
    final dk = n.tin.listen(thu.add);

    await n.batDau(url: 'u', tenTep: 't', chiWifi: false);
    await Future<void>.delayed(Duration.zero);

    expect(thu.single.trangThai, TrangThaiLuot.dangChay);
    expect(n.chiWifiLanCuoi, isFalse,
        reason: 'Task 6 cần đọc lại giá trị này để kiểm hộp thoại 4G.');
    await dk.cancel();
  });

  test('bản giả: tamDung rồi tiepTuc đi qua đúng hai trạng thái', () async {
    final n = NguonTaiNenGia();
    final thu = <TrangThaiLuot>[];
    final dk = n.tin.listen((t) => thu.add(t.trangThai));

    await n.batDau(url: 'u', tenTep: 't', chiWifi: true);
    await n.tamDung();
    await n.tiepTuc();
    await Future<void>.delayed(Duration.zero);

    expect(thu, [
      TrangThaiLuot.dangChay,
      TrangThaiLuot.tamDung,
      TrangThaiLuot.dangChay,
    ]);
    await dk.cancel();
  });

  test('bản giả: huy xong thì KHÔNG còn lượt đang sống', () async {
    final n = NguonTaiNenGia();
    await n.batDau(url: 'u', tenTep: 't', chiWifi: true);
    expect(await n.luotDangSong(), isNotNull);

    await n.huy();
    expect(await n.luotDangSong(), isNull,
        reason: 'Huỷ mà vẫn báo "còn lượt" thì màn sẽ hiện tiến độ ma.');
  });

  test('bản giả: tienToi() đẩy phần trăm cho test tầng trên', () async {
    final n = NguonTaiNenGia();
    await n.batDau(url: 'u', tenTep: 't', chiWifi: true);
    n.tienToi(0.5);
    final luot = await n.luotDangSong();
    expect(luot?.phanTram, 0.5);
  });
}
