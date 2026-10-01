/// D1 Task 8 — chạm thông báo tóm tắt *"Có N biến động số dư mới"* (do Kotlin bắn, không qua
/// `flutter_local_notifications`) thì mở trung tâm thông báo lọc sẵn nhóm Biến động.
///
/// Kotlin giữ một cờ "lần mở này đến từ tóm tắt" (`moTuThongBao`, đọc là TIÊU). Hai đường vào: app đang đóng
/// (cờ đặt lúc khởi động) và app nằm nền (`onNewIntent` → Flutter `resumed`). Chưa đăng nhập thì giữ lại tới
/// khi có phiên — cùng luật `NotificationTapRouter`.
library;

import 'dart:async';

import 'package:flowmoney/core/notification/kenh_bien_dong.dart';
import 'package:flowmoney/core/notification/mo_tu_tom_tat_bien_dong.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _KenhGia extends KenhBienDongTrong {
  bool co = false;
  int soLanHoi = 0;

  @override
  Future<bool> moTuThongBao() async {
    soLanHoi++;
    final c = co;
    co = false; // đọc là tiêu
    return c;
  }
}

void main() {
  late _KenhGia kenh;
  late List<String> daDi;
  late bool dangNhap;
  late StreamController<void> phien;
  late StreamController<AppLifecycleState> vongDoi;
  late MoTuTomTatBienDong mo;

  setUp(() {
    kenh = _KenhGia();
    daDi = [];
    dangNhap = true;
    phien = StreamController<void>.broadcast();
    vongDoi = StreamController<AppLifecycleState>.broadcast();
    mo = MoTuTomTatBienDong(
      kenh: kenh,
      dieuHuong: daDi.add,
      dangDangNhap: () => dangNhap,
      phienDoi: phien.stream,
      vongDoi: vongDoi.stream,
    );
  });
  tearDown(() async {
    await mo.stop();
    await phien.close();
    await vongDoi.close();
  });

  Future<void> nhip() => Future<void>.delayed(Duration.zero);

  test('route đích là trung tâm thông báo lọc nhóm bienDong', () {
    expect(kRouteBienDongChuaGhi, '/notifications?nhom=bienDong');
  });

  test('⭐ mở app bằng cú chạm tóm tắt (app đang đóng) → đi đúng một lần', () async {
    kenh.co = true;
    await mo.start();
    expect(daDi, [kRouteBienDongChuaGhi]);
  });

  test('mở app thường → không đi đâu', () async {
    await mo.start();
    expect(daDi, isEmpty);
  });

  test('⭐ app nằm nền, chạm tóm tắt → resumed hỏi lại kênh và đi', () async {
    await mo.start();
    kenh.co = true;
    vongDoi.add(AppLifecycleState.resumed);
    await nhip();
    await nhip();
    expect(daDi, [kRouteBienDongChuaGhi]);
    vongDoi.add(AppLifecycleState.paused);
    await nhip();
    expect(kenh.soLanHoi, 2, reason: 'chỉ hỏi ở start và resumed');
  });

  test('⭐ chưa đăng nhập → giữ lại, đi khi có phiên (không đi hai lần)', () async {
    dangNhap = false;
    kenh.co = true;
    await mo.start();
    expect(daDi, isEmpty);
    phien.add(null);
    await nhip();
    expect(daDi, isEmpty, reason: 'sự kiện phiên có thể là bước trung gian của luồng đăng nhập');
    dangNhap = true;
    phien.add(null);
    await nhip();
    phien.add(null);
    await nhip();
    expect(daDi, [kRouteBienDongChuaGhi]);
  });

  test('stop() thôi nghe', () async {
    await mo.start();
    await mo.stop();
    kenh.co = true;
    vongDoi.add(AppLifecycleState.resumed);
    await nhip();
    expect(daDi, isEmpty);
  });
}
