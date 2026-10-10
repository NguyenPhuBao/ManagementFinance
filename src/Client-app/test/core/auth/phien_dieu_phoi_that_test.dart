/// `PhienDieuPhoiThat` — bộ điều phối vòng đời phiên tách từ AuthBloc (spec bịt điểm rò 2026-10-10, mục 6). Ba spy
/// chép từ `session_validation_test` / `auth_bloc_buoc_dang_xuat_test`; hook là closure ghi nhật ký.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/api/dio_client.dart';
import 'package:flowmoney/core/api/interceptors/auth_interceptor.dart';
import 'package:flowmoney/core/auth/buoc_dang_xuat.dart';
import 'package:flowmoney/core/auth/phien_dieu_phoi_that.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/notification/notification_scanner.dart';
import 'package:flowmoney/core/realtime/realtime_channel.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';

class _FakeDioClient implements DioClient {
  @override
  final Dio dio = Dio();
}

class _Offline implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [ConnectivityResult.none];
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _SpySyncEngine extends SyncEngine {
  _SpySyncEngine({required super.dioClient, required super.db, super.connectivity});
  final nhatKy = <String>[];
  bool daKeoVe = false;
  final _chet = StreamController<void>.broadcast();
  @override
  Stream<void> get sessionInvalidStream => _chet.stream;
  void phienChet() => _chet.add(null);
  @override
  bool get hasCompletedPull => daKeoVe;
  @override
  Future<void> start({required int idaccount}) async => nhatKy.add('start $idaccount');
  @override
  void stop() => nhatKy.add('stop');
  @override
  void scheduleSync() => nhatKy.add('hen');
  @override
  void dispose() { _chet.close(); super.dispose(); }
}

class _SpyAuthInterceptor extends AuthInterceptor {
  _SpyAuthInterceptor() : super(secureStorage: const FlutterSecureStorage());
  final _hetHan = StreamController<void>.broadcast();
  final _tuChoi = StreamController<ThongBaoBuocDangXuat>.broadcast();
  @override
  Stream<void> get sessionExpiredStream => _hetHan.stream;
  @override
  Stream<ThongBaoBuocDangXuat> get taiKhoanBiTuChoi => _tuChoi.stream;
  void hetHan() => _hetHan.add(null);
  void tuChoi(ThongBaoBuocDangXuat tb) => _tuChoi.add(tb);
  @override
  void dispose() { _hetHan.close(); _tuChoi.close(); super.dispose(); }
}

class _SpyRealtime extends RealtimeChannel {
  _SpyRealtime() : super(secureStorage: const FlutterSecureStorage(), connectivity: _Offline());
  final nhatKy = <String>[];
  final _buoc = StreamController<ThongBaoBuocDangXuat>.broadcast();
  @override
  Stream<ThongBaoBuocDangXuat> get buocDangXuat => _buoc.stream;
  void ban(ThongBaoBuocDangXuat tb) => _buoc.add(tb);
  @override
  Future<void> start({required int idaccount}) async => nhatKy.add('start $idaccount');
  @override
  Future<void> stop() async => nhatKy.add('stop');
  void dong() => _buoc.close();
}

class _SpyScanner extends NotificationScanner {
  _SpyScanner(AppDatabase db, [this.chung])
      : super(dao: db.notificationDao, loadBudgets: (id, at) async => [], loadBills: (id, at) async => [],
            syncStatus: const Stream.empty());
  final goi = <String>[];
  /// Nhật ký chung với hook của test — để canh THỨ TỰ giữa hook và bộ quét.
  final List<String>? chung;
  @override
  Future<void> start(int idaccount) async {
    goi.add('start $idaccount');
    chung?.add('quet $idaccount');
  }
  @override
  Future<void> stop() async => goi.add('stop');
}

const _tb = ThongBaoBuocDangXuat(
    lyDo: LyDoBuocDangXuat.biKhoa, nguon: NguonBuocDangXuat.socket, loiNhan: 'khoá', idaccount: 10);

void main() {
  late AppDatabase db;
  late _SpySyncEngine sync;
  late _SpyAuthInterceptor interceptor;
  late _SpyRealtime realtime;
  late _SpyScanner scanner;
  late List<String> hook;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sync = _SpySyncEngine(dioClient: _FakeDioClient(), db: db, connectivity: _Offline());
    interceptor = _SpyAuthInterceptor();
    realtime = _SpyRealtime();
    hook = [];
    scanner = _SpyScanner(db, hook);
  });
  tearDown(() async { sync.dispose(); interceptor.dispose(); realtime.dong(); await db.close(); });

  PhienDieuPhoiThat dung({int daDon = 0, int banSao = 0, bool coDongBo = true, bool coQuet = true}) {
    final p = PhienDieuPhoiThat(
      dongBo: coDongBo ? sync : null,
      thoiGianThuc: realtime,
      boQuet: coQuet ? scanner : null,
      interceptor: interceptor,
      donTaiKhoanKhac: (id) async { hook.add('don $id'); return daDon; },
      xoaBanSao: (id) async { hook.add('xoaBanSao $id'); return 1; },
      xoaCacheSlm: () async => hook.add('xoaCache'),
      chuyenHangSeedCu: (id) async => hook.add('seedCu $id'),
      taoBanSaoDanhMuc: (id) async { hook.add('banSao $id'); return banSao; },
      seedTaiKhoanMoi: (id) async => hook.add('seedMoi $id'),
      xoaAnhQuet: () async => hook.add('xoaAnh'),
      datLaiCoGiaoDien: () => hook.add('coUI'),
    );
    addTearDown(p.dispose);
    return p;
  }

  test('moPhienCucBo: dọn → (xoá cache chỉ khi có hàng bị dọn) → hàng seed cũ → bộ quét', () async {
    await dung(daDon: 3).moPhienCucBo(10);
    expect(hook, ['don 10', 'xoaCache', 'seedCu 10', 'quet 10']);
    expect(scanner.goi, ['start 10']);
    hook.clear(); scanner.goi.clear();
    await dung(daDon: 0).moPhienCucBo(10);
    expect(hook, ['don 10', 'seedCu 10', 'quet 10'], reason: 'không hàng nào bị dọn thì GIỮ cache SLM (đăng nhập lại cùng tài khoản)');
  });

  test('moPhienCucBo: thứ tự trên MỘT nhật ký chung — dọn → xoá cache → hàng seed cũ → bộ quét', () async {
    await dung(daDon: 2).moPhienCucBo(10);
    expect(hook, ['don 10', 'xoaCache', 'seedCu 10', 'quet 10'],
        reason: 'bộ quét phải chạy SAU khi dọn dữ liệu tài khoản khác và chuyển hàng seed cũ');
  });

  test('dispose() huỷ subscription — nguồn phát tiếp thì không lỗi, luồng gộp không nhận gì', () async {
    final p = dung();
    final chet = <void>[]; final buoc = <ThongBaoBuocDangXuat>[];
    p.phienCoTheChet.listen(chet.add, onError: (_) {});
    p.buocDangXuat.listen(buoc.add, onError: (_) {});
    await p.dispose();
    // Bản thiếu `cancel`: các lời gọi dưới đây `add` vào controller đã đóng → StateError không ai bắt → test đỏ.
    sync.phienChet(); interceptor.hetHan(); realtime.ban(_tb); interceptor.tuChoi(_tb);
    await pumpEventQueue();
    expect(chet, isEmpty); expect(buoc, isEmpty);
  });

  test('không có SyncEngine thì moPhienCucBo / batDongBo không làm gì — đúng khối if cũ', () async {
    final p = dung(coDongBo: false);
    await p.moPhienCucBo(10); await p.batDongBo(10, cho: true);
    expect(hook, isEmpty); expect(scanner.goi, isEmpty); expect(sync.nhatKy, isEmpty);
  });

  test('batDongBo cho: true — đợi start, tạo bản sao khi đã kéo về, hẹn đẩy khi có bản sao mới', () async {
    sync.daKeoVe = true;
    await dung(banSao: 13).batDongBo(10, cho: true);
    expect(sync.nhatKy, ['start 10', 'hen']);
    expect(hook, ['banSao 10']);
  });

  test('batDongBo cho: true — chưa kéo về thì KHÔNG tạo bản sao (G14)', () async {
    await dung(banSao: 13).batDongBo(10, cho: true);
    expect(sync.nhatKy, ['start 10']);
    expect(hook, isEmpty);
  });

  test('batDongBo cho: false — không chặn, bản sao nối sau start', () async {
    sync.daKeoVe = true;
    final p = dung(banSao: 1);
    await p.batDongBo(10, cho: false);
    await pumpEventQueue();
    expect(sync.nhatKy, ['start 10', 'hen']);
    expect(hook, ['banSao 10']);
  });

  test('batThoiGianThuc / sauDangNhap / dongPhien / xoaDuLieu', () async {
    final p = dung();
    await p.batThoiGianThuc(10);
    expect(realtime.nhatKy, ['start 10']);
    await p.sauDangNhap(10);
    expect(hook, ['seedMoi 10', 'coUI']);
    await p.dongPhien();
    expect(sync.nhatKy, ['stop']); expect(scanner.goi, ['stop']); expect(realtime.nhatKy.last, 'stop');
    expect(hook.last, 'xoaAnh');
    await p.xoaDuLieu(7);
    expect(hook.last, 'xoaBanSao 7');
  });

  test('sauDangNhap không có SyncEngine: bỏ seed, vẫn đặt lại cờ giao diện', () async {
    await dung(coDongBo: false).sauDangNhap(10);
    expect(hook, ['coUI']);
  });

  test('dongPhien chịu được dịch vụ null', () async {
    await dung(coQuet: false).dongPhien();
    expect(sync.nhatKy, ['stop']); expect(scanner.goi, isEmpty);
  });

  test('hai luồng gộp phát lại từ cả hai nguồn', () async {
    final p = dung();
    final chet = <void>[]; final buoc = <ThongBaoBuocDangXuat>[];
    p.phienCoTheChet.listen(chet.add); p.buocDangXuat.listen(buoc.add);
    sync.phienChet(); interceptor.hetHan(); realtime.ban(_tb); interceptor.tuChoi(_tb);
    await pumpEventQueue();
    expect(chet, hasLength(2)); expect(buoc, hasLength(2));
  });
}
