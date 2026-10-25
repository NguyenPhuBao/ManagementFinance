import 'dart:async';

import 'package:flowmoney/features/khoa_app/application/khoa_app_service.dart';
import 'package:flowmoney/features/khoa_app/data/datasources/kenh_sinh_trac.dart';
import 'package:flowmoney/features/khoa_app/data/khoa_app_store.dart';
import 'package:flowmoney/features/khoa_app/data/models/cau_hinh_khoa_app.dart';
import 'package:flowmoney/features/khoa_app/domain/luat_khoa_app.dart';
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

  group('C1 — mất phiên khi đang che (có tín hiệu router)', () {
    late ValueNotifier<bool> yen;
    late KhoaAppCubit c;

    setUp(() {
      yen = ValueNotifier<bool>(false);
      c = KhoaAppCubit(
        service: sv,
        vongDoi: vongDoi.stream,
        phien: phien.stream,
        clock: () => nay,
        dungYenOCongKhai: yen,
        vanAnToanRoi: const Duration(hours: 1),
      );
    });

    tearDown(() async {
      await c.close();
      yen.dispose();
    });

    test('đang Khoa, router chưa yên → DangRoi; yên → Tat', () async {
      await sv.datPin(10, '246810');
      await c.nhanPhien(10);
      expect(c.state, isA<KhoaAppKhoa>());
      await c.nhanPhien(null);
      expect(c.state, const KhoaAppDangRoi());
      yen.value = true;
      expect(c.state, const KhoaAppTat());
    });

    test('đang Khoa, router đã yên từ trước → Tat ngay (Quên PIN)', () async {
      await sv.datPin(10, '246810');
      await c.nhanPhien(10);
      yen.value = true;
      await c.nhanPhien(null);
      expect(c.state, const KhoaAppTat());
    });

    test('đang DangXet có phiên rồi mất phiên → DangRoi (phiên chết lúc mở lạnh)', () async {
      // DangXet có phiên: nhanPhien(10) chưa đọc xong kho thì nhanPhien(null) tới.
      final lan = c.nhanPhien(10);
      expect(c.state, const KhoaAppDangXet());
      await c.nhanPhien(null);
      expect(c.state, const KhoaAppDangRoi());
      await lan;
      expect(c.state, const KhoaAppDangRoi(), reason: 'lượt đọc kho về muộn không được đè lên DangRoi');
    });

    test('đang Mo (đã mở khoá) rồi đăng xuất → Tat ngay, không che', () async {
      await sv.datPin(10, '246810');
      await c.nhanPhien(10);
      await c.nhapPin('246810');
      await pumpEventQueue();
      expect(c.state, const KhoaAppMo(daBat: true));
      await c.nhanPhien(null);
      expect(c.state, const KhoaAppTat());
    });

    test('lần ĐẦU nhận phiên null (chưa từng có phiên) → Tat, dù có tín hiệu (không hồi quy P2)', () async {
      await c.nhanPhien(null);
      expect(c.state, const KhoaAppTat());
    });
  });

  test('I2: đọc hỏng lúc nhập PIN → vẫn Khoa + kCauKhongKiemDuoc (không mở bằng PIN bất kỳ)', () async {
    await sv.datPin(10, '246810');
    await moPhien(10);
    kho.hongKhiDoc = true;
    await cubit.nhapPin('000000');
    await pumpEventQueue();
    final s = cubit.state as KhoaAppKhoa;
    expect(s.loiNhan, kCauKhongKiemDuoc);
  });

  test('I2: đọc hỏng ngay sau mở khoá → cấu hình RAM còn, ở nền ≥ mức vẫn khoá', () async {
    await sv.datPin(10, '246810');
    await moPhien(10);
    final kho2 = _KhoHongTuLanDocThu(kho, 2); // lần đọc nghiêm ngặt thứ hai (trong _mo) hỏng
    final c2 = KhoaAppCubit(
      service: KhoaAppService(store: kho2, kenh: kenh, bam: bamNhanh, clock: () => nay),
      vongDoi: vongDoi.stream,
      phien: phien.stream,
      clock: () => nay,
    );
    addTearDown(c2.close);
    await c2.nhanPhien(10); // đọc 1 (lenient doc)
    await c2.nhapPin('246810'); // kiemPin: docNghiemNgat #1 ok; _mo: docNghiemNgat #2 hỏng
    await pumpEventQueue();
    expect(c2.state, const KhoaAppMo(daBat: true), reason: 'hỏng tạm thời không được báo "chưa bật"');
    vongDoi.add(AppLifecycleState.paused);
    nay = nay.add(const Duration(minutes: 10));
    vongDoi.add(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(c2.state, isA<KhoaAppKhoa>(), reason: 'mất cấu hình RAM = tắt tự khoá cả phiên');
  });

  test('I2: napLai gặp đọc hỏng → giữ cấu hình cũ (vẫn tự khoá)', () async {
    await sv.datPin(10, '246810');
    await moPhien(10);
    await cubit.nhapPin('246810');
    await pumpEventQueue();
    kho.hongKhiDoc = true;
    await cubit.napLai();
    kho.hongKhiDoc = false;
    vongDoi.add(AppLifecycleState.paused);
    nay = nay.add(const Duration(minutes: 10));
    vongDoi.add(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(cubit.state, isA<KhoaAppKhoa>());
  });

  group('I1 — tự khoá đo thêm bằng đồng hồ khởi động', () {
    Future<KhoaAppCubit> dung(Duration? Function() kd) async {
      await sv.datPin(10, '246810');
      await sv.datTuKhoaSau(10, TuKhoaSau.phut5);
      final c = KhoaAppCubit(
        service: sv,
        vongDoi: vongDoi.stream,
        phien: phien.stream,
        clock: () => nay,
        dongHoKhoiDong: kd,
      );
      addTearDown(c.close);
      await c.nhanPhien(10);
      await c.nhapPin('246810');
      await pumpEventQueue();
      expect(c.state, const KhoaAppMo(daBat: true));
      return c;
    }

    test('ở nền 60 phút, giờ tường chỉnh lùi (+1 phút), đồng hồ khởi động +60 phút → Khoa', () async {
      var khoiDong = const Duration(hours: 5);
      final c = await dung(() => khoiDong);
      vongDoi.add(AppLifecycleState.hidden);
      vongDoi.add(AppLifecycleState.paused);
      await pumpEventQueue();
      nay = nay.add(const Duration(minutes: 1)); // người cầm máy đặt giờ về mốc rời + 1 phút
      khoiDong += const Duration(minutes: 60);
      vongDoi.add(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(c.state, isA<KhoaAppKhoa>(), reason: 'chỉ giờ tường thì 1 phút < 5 phút = vượt khoá');
    });

    test('cả hai đo ngắn → không khoá; đồng hồ khởi động null → ca cũ', () async {
      var khoiDong = const Duration(hours: 5);
      final c = await dung(() => khoiDong);
      vongDoi.add(AppLifecycleState.paused);
      nay = nay.add(const Duration(minutes: 1));
      khoiDong += const Duration(minutes: 1);
      vongDoi.add(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(c.state, const KhoaAppMo(daBat: true));

      final c2 = await dung(() => null);
      vongDoi.add(AppLifecycleState.paused);
      nay = nay.add(const Duration(minutes: 6));
      vongDoi.add(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(c2.state, isA<KhoaAppKhoa>(), reason: 'giờ tường vẫn khoá khi không đọc được đồng hồ khởi động');
    });
  });

  test('T7: AuthSuccess tài khoản KHÁC (10 → 11) nạp cấu hình của 11', () async {
    await sv.datPin(10, '246810');
    await sv.datPin(11, '135790');
    await sv.datTuKhoaSau(11, TuKhoaSau.phut5);
    await moPhien(10);
    await cubit.nhapPin('246810');
    await pumpEventQueue();
    expect(cubit.state, const KhoaAppMo(daBat: true));
    await moPhien(11);
    expect(cubit.state, isA<KhoaAppKhoa>(), reason: 'đổi tài khoản = mở lạnh của tài khoản mới');
    await cubit.nhapPin('246810');
    await pumpEventQueue();
    expect(cubit.state, isA<KhoaAppKhoa>(), reason: 'PIN của 10 không mở được 11');
    await cubit.nhapPin('135790');
    await pumpEventQueue();
    expect(cubit.state, const KhoaAppMo(daBat: true));
    vongDoi.add(AppLifecycleState.paused);
    nay = nay.add(const Duration(minutes: 1));
    vongDoi.add(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(cubit.state, const KhoaAppMo(daBat: true), reason: 'mức 5 phút của tài khoản 11, không phải 30 giây mặc định của 10');
  });

  test('T7: mức Ngay — rời rồi quay lại tức thì vẫn khoá', () async {
    await sv.datPin(10, '246810');
    await sv.datTuKhoaSau(10, TuKhoaSau.ngay);
    await moPhien(10);
    await cubit.nhapPin('246810');
    await pumpEventQueue();
    vongDoi.add(AppLifecycleState.hidden);
    vongDoi.add(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(cubit.state, isA<KhoaAppKhoa>());
  });
}

/// Kho bọc: [docNghiemNgat] hỏng từ lần gọi thứ [tuLan] (đếm từ 1).
class _KhoHongTuLanDocThu extends InMemoryKhoaAppStore {
  _KhoHongTuLanDocThu(this._goc, this.tuLan) {
    duLieu.addAll(_goc.duLieu);
  }
  final InMemoryKhoaAppStore _goc;
  final int tuLan;
  int _dem = 0;

  @override
  Future<CauHinhKhoaApp?> docNghiemNgat(int idaccount) async {
    _dem++;
    if (_dem >= tuLan) throw StateError('kho hỏng khi đọc');
    return duLieu[idaccount];
  }
}
