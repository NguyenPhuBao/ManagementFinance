import 'dart:async';

import 'package:flowmoney/features/khoa_app/application/khoa_app_service.dart';
import 'package:flowmoney/features/khoa_app/data/datasources/kenh_sinh_trac.dart';
import 'package:flowmoney/features/khoa_app/data/khoa_app_store.dart';
import 'package:flowmoney/features/khoa_app/presentation/bloc/khoa_app_cubit.dart';
import 'package:flowmoney/features/khoa_app/presentation/bloc/khoa_app_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/khoa_app_gia.dart';

void main() {
  late InMemoryKhoaAppStore kho;
  late KenhGia kenh;
  late KhoaAppService sv;
  late StreamController<AppLifecycleState> vongDoi;
  late StreamController<int?> phien;
  late DateTime nay;
  late KhoaAppCubit cubit;

  setUp(() {
    kho = InMemoryKhoaAppStore();
    kenh = KenhGia();
    nay = DateTime(2026, 10, 24, 21);
    sv = KhoaAppService(store: kho, kenh: kenh, bam: bamNhanh, clock: () => nay);
    vongDoi = StreamController<AppLifecycleState>.broadcast(sync: true);
    phien = StreamController<int?>.broadcast();
    cubit = KhoaAppCubit(service: sv, vongDoi: vongDoi.stream, phien: phien.stream, clock: () => nay);
  });

  tearDown(() async {
    await cubit.close();
    await vongDoi.close();
    await phien.close();
  });

  Future<void> moPhien(int? id) async {
    phien.add(id);
    await pumpEventQueue();
  }

  test('bắt đầu ở DangXet; phiên không cấu hình → Mo(daBat:false); không phiên → Tat', () async {
    expect(cubit.state, const KhoaAppDangXet());
    await moPhien(10);
    expect(cubit.state, const KhoaAppMo(daBat: false));
    await moPhien(null);
    expect(cubit.state, const KhoaAppTat());
  });

  test('phiên có cấu hình → khoá (mở lạnh)', () async {
    await sv.datPin(10, '246810');
    await moPhien(10);
    expect(cubit.state, isA<KhoaAppKhoa>());
    expect((cubit.state as KhoaAppKhoa).lanKhoa, 1);
  });

  test('AuthSuccess lặp lại cùng tài khoản KHÔNG khoá lại', () async {
    await sv.datPin(10, '246810');
    await moPhien(10);
    await cubit.nhapPin('246810');
    await pumpEventQueue();
    expect(cubit.state, const KhoaAppMo(daBat: true));
    await moPhien(10);
    expect(cubit.state, const KhoaAppMo(daBat: true), reason: 'verifySession phát lại AuthSuccess — không phải mở lạnh');
  });

  test('ở nền 29 s → không khoá; 30 s → khoá (mức mặc định)', () async {
    await sv.datPin(10, '246810');
    await moPhien(10);
    await cubit.nhapPin('246810');
    await pumpEventQueue();
    vongDoi.add(AppLifecycleState.hidden);
    vongDoi.add(AppLifecycleState.paused);
    await pumpEventQueue();
    nay = nay.add(const Duration(seconds: 29));
    vongDoi.add(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(cubit.state, const KhoaAppMo(daBat: true));
    vongDoi.add(AppLifecycleState.paused);
    await pumpEventQueue();
    nay = nay.add(const Duration(seconds: 30));
    vongDoi.add(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(cubit.state, isA<KhoaAppKhoa>());
  });

  test('chỉ inactive (hộp vân tay / hộp quyền) → không tính là rời app', () async {
    await sv.datPin(10, '246810');
    await moPhien(10);
    await cubit.nhapPin('246810');
    await pumpEventQueue();
    vongDoi.add(AppLifecycleState.inactive);
    nay = nay.add(const Duration(minutes: 10));
    vongDoi.add(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(cubit.state, const KhoaAppMo(daBat: true));
  });

  test('nhập sai → câu sai; sai lần 5 → choDen, không câu sai khi đang chờ', () async {
    await sv.datPin(10, '246810');
    await moPhien(10);
    await cubit.nhapPin('000000');
    await pumpEventQueue();
    expect((cubit.state as KhoaAppKhoa).loiNhan, kCauSaiPin);
    for (var i = 0; i < 4; i++) {
      await cubit.nhapPin('000000');
      await pumpEventQueue();
    }
    final s = cubit.state as KhoaAppKhoa;
    expect(s.soLanSai, 5);
    expect(s.choDen, nay.add(const Duration(seconds: 30)));
    await cubit.nhapPin('246810');
    await pumpEventQueue();
    expect(cubit.state, isA<KhoaAppKhoa>(), reason: 'đang chờ thì PIN đúng cũng chưa mở');
  });

  test('P13: lanKiem tăng đúng 1 sau mỗi lượt kiểm kết thúc (sai, và bị chặn vì đang chờ)', () async {
    await sv.datPin(10, '246810');
    await moPhien(10);
    expect((cubit.state as KhoaAppKhoa).lanKiem, 0);
    await cubit.nhapPin('000000');
    await pumpEventQueue();
    expect((cubit.state as KhoaAppKhoa).lanKiem, 1, reason: 'màn khoá xoá chấm theo số này');
    for (var i = 0; i < 4; i++) {
      await cubit.nhapPin('000000');
    }
    expect((cubit.state as KhoaAppKhoa).lanKiem, 5);
    await cubit.nhapPin('246810'); // đang chờ → bị chặn, vẫn là một lượt kết thúc
    expect((cubit.state as KhoaAppKhoa).lanKiem, 6);
  });

  test('kho hỏng khi kiểm → câu kCauKhongKiemDuoc, không tăng đếm', () async {
    await sv.datPin(10, '246810');
    await moPhien(10);
    kho.hongKhiGhi = true;
    await cubit.nhapPin('000000');
    await pumpEventQueue();
    final s = cubit.state as KhoaAppKhoa;
    expect([s.loiNhan, s.soLanSai, s.dangKiem], [kCauKhongKiemDuoc, 0, false]);
    expect(s.lanKiem, 1);
  });

  test('vân tay: thành công → Mo; HUY → giữ nguyên; VO_HIEU → coVanTay false + câu', () async {
    await sv.datPin(10, '246810');
    await sv.batVanTay(10);
    await moPhien(10);
    expect((cubit.state as KhoaAppKhoa).coVanTay, isTrue);

    kenh.loiMo = LoiSinhTrac.huy;
    final truoc = cubit.state;
    await cubit.moBangVanTay();
    expect(cubit.state, truoc);

    kenh.loiMo = LoiSinhTrac.voHieu;
    await cubit.moBangVanTay();
    final s = cubit.state as KhoaAppKhoa;
    expect([s.coVanTay, s.loiNhan], [false, kCauVanTayDaDoi]);

    await sv.batVanTay(10);
    kenh.loiMo = null;
    await cubit.napLai();
    await moPhien(null);
    await moPhien(10);
    await cubit.moBangVanTay();
    expect(cubit.state, const KhoaAppMo(daBat: true));
  });

  test('vân tay: kho hỏng khi service ghi → không ném, vẫn khoá với kCauVanTayHong', () async {
    await sv.datPin(10, '246810');
    await sv.batVanTay(10);
    // Có lần sai cũ → mở được sẽ phải ghi đếm về 0 → kho hỏng làm service ném.
    kho.duLieu[10] = kho.duLieu[10]!.voiLanSai(2, null);
    await moPhien(10);
    kho.hongKhiGhi = true;
    await cubit.moBangVanTay();
    final s = cubit.state as KhoaAppKhoa;
    expect(s.loiNhan, kCauVanTayHong);
    expect(s.coVanTay, isTrue);
  });

  test('napLai sau khi bật khoá ở Cài đặt KHÔNG khoá app', () async {
    await moPhien(10);
    await sv.datPin(10, '246810');
    await cubit.napLai();
    expect(cubit.state, const KhoaAppMo(daBat: true));
  });

  test('P9: quay lại từ nền → khoá ngay, rồi hiện choDen / soLanSai MỚI HƠN của kho', () async {
    await sv.datPin(10, '246810');
    await moPhien(10);
    await cubit.nhapPin('246810');
    await pumpEventQueue();
    vongDoi.add(AppLifecycleState.paused);
    await pumpEventQueue();
    nay = nay.add(const Duration(minutes: 2));
    // Nơi khác (trang Đổi PIN) đã ghi lần sai mà cubit chưa napLai.
    final cho = nay.add(const Duration(minutes: 5));
    kho.duLieu[10] = kho.duLieu[10]!.voiLanSai(7, cho);
    vongDoi.add(AppLifecycleState.resumed);
    // Đồng bộ: đã khoá bằng bản RAM, chưa có đếm ngược.
    final ngay = cubit.state as KhoaAppKhoa;
    expect([ngay.soLanSai, ngay.choDen], [0, null]);
    await pumpEventQueue();
    final s = cubit.state as KhoaAppKhoa;
    expect([s.soLanSai, s.choDen], [7, cho]);
    expect(s.lanKhoa, ngay.lanKhoa);
  });

  test('lần ĐẦU nhận phiên null (chưa đăng nhập) → Tat, không kẹt DangXet', () async {
    expect(cubit.state, const KhoaAppDangXet());
    await moPhien(null);
    expect(cubit.state, const KhoaAppTat());
  });

  test('lượt kiểm PIN hỏng sau khi phiên đã về null KHÔNG đè Tat', () async {
    final cho = Completer<void>();
    Future<String> bamCho(String pin, List<int> salt, int soVong) async {
      await cho.future;
      return bamNhanh(pin, salt, soVong);
    }

    final sv2 = KhoaAppService(store: kho, kenh: kenh, bam: bamNhanh, clock: () => nay);
    await sv2.datPin(10, '246810');
    final svCho = KhoaAppService(store: kho, kenh: kenh, bam: bamCho, clock: () => nay);
    final c2 = KhoaAppCubit(service: svCho, vongDoi: vongDoi.stream, phien: phien.stream, clock: () => nay);
    addTearDown(c2.close);
    await c2.nhanPhien(10);
    expect(c2.state, isA<KhoaAppKhoa>());
    final lan = c2.nhapPin('000000');
    await pumpEventQueue();
    await c2.nhanPhien(null);
    expect(c2.state, const KhoaAppTat());
    kho.hongKhiGhi = true;
    cho.complete();
    await lan;
    await pumpEventQueue();
    expect(c2.state, const KhoaAppTat(), reason: 'catch không được emit Khoa cũ đè lên phiên mới');
  });
}
