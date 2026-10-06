/// `GoiRepository` — nguồn sự thật phía client về gói (spec Premium 6.3–6.5):
/// `lamMoi` không bao giờ ném, hỏng thì GIỮ trạng thái; kho thắng `type` của
/// phiên; hai lượt chồng nhau dùng một lời gọi; ba nguồn làm mới (phiên, vòng
/// đời `resumed` giãn 5 phút, socket `account.upgraded` ngay).
library;

import 'dart:async';

import 'package:flowmoney/core/realtime/realtime_event.dart';
import 'package:flowmoney/features/premium/data/goi_repository.dart';
import 'package:flowmoney/features/premium/data/goi_store.dart';
import 'package:flowmoney/features/premium/data/payment_api.dart';
import 'package:flowmoney/features/premium/domain/trang_thai_goi.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _ApiGia implements PaymentApi {
  Map<String, Object?>? thongTin; // null → ném
  int soLanHoi = 0;
  Completer<void>? treo;

  @override
  Future<Map<String, Object?>> thongTinGoi() async {
    soLanHoi++;
    if (treo != null) await treo!.future;
    final t = thongTin;
    if (t == null) throw StateError('server hỏng');
    return t;
  }

  @override
  Future<Map<String, Object?>> taoDon() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> trangThaiDon(int orderCode) =>
      throw UnimplementedError();
  @override
  Future<List<Map<String, Object?>>> lichSu({int page = 1, int limit = 20}) =>
      throw UnimplementedError();
}

Future<void> _nghi() => Future<void>.delayed(Duration.zero);

void main() {
  var now = DateTime(2026, 10, 6, 10);
  late _ApiGia api;
  late InMemoryGoiStore kho;
  late GoiRepository repo;
  const premiumJson = {
    'accountType': 'Premium',
    'premiumExpiresAt': '2026-11-05T00:00:00.000Z',
  };

  setUp(() {
    now = DateTime(2026, 10, 6, 10);
    api = _ApiGia()..thongTin = premiumJson;
    kho = InMemoryGoiStore();
    repo = GoiRepository(api: api, kho: kho, clock: () => now);
  });
  tearDown(() => repo.dispose());

  test('chưa đặt tài khoản: Basic mặc định, lamMoi không gọi API', () async {
    expect(repo.hienTai.laPremium(now), isFalse);
    await repo.lamMoi();
    expect(api.soLanHoi, 0);
  });

  test('datTaiKhoan: kho trống → rơi về type của phiên; có kho → kho thắng type',
      () async {
    await repo.datTaiKhoan(10, loaiPhien: 'Premium');
    expect(repo.hienTai.laPremium(now), isTrue);
    expect(repo.hienTai.hetHan, isNull, reason: 'type không mang hạn');

    await kho.ghi(11, TrangThaiGoi.basicMacDinh(now));
    await repo.datTaiKhoan(11, loaiPhien: 'Premium');
    expect(repo.hienTai.laPremium(now), isFalse,
        reason: 'kho thắng type (spec 6.3, giới hạn 15.2)');
  });

  test('lamMoi: ghi kho, phát stream, hienTai đổi', () async {
    await repo.datTaiKhoan(10);
    final phat = <TrangThaiGoi>[];
    final sub = repo.theoDoi.listen(phat.add);
    await repo.lamMoi();
    await _nghi();
    expect(repo.hienTai.laPremium(now), isTrue);
    expect((await kho.doc(10))!.laPremium(now), isTrue);
    expect(phat.last.laPremium(now), isTrue);
    await sub.cancel();
  });

  test('lamMoi hỏng: GIỮ trạng thái đang có, không ném', () async {
    await kho.ghi(
        10,
        TrangThaiGoi(
            loai: LoaiGoi.premium,
            hetHan: DateTime(2026, 11, 5),
            nhanLuc: now));
    await repo.datTaiKhoan(10);
    api.thongTin = null;
    await repo.lamMoi();
    expect(repo.hienTai.laPremium(now), isTrue);
  });

  test('hai lamMoi chồng nhau → một lời gọi API', () async {
    await repo.datTaiKhoan(10);
    api.treo = Completer<void>();
    final a = repo.lamMoi();
    final b = repo.lamMoi();
    api.treo!.complete();
    await Future.wait([a, b]);
    expect(api.soLanHoi, 1);
  });

  test('lamMoiNeuCu: trong 5 phút không hỏi, quá 5 phút hỏi', () async {
    await repo.datTaiKhoan(10);
    await repo.lamMoi();
    expect(api.soLanHoi, 1);
    now = now.add(const Duration(minutes: 4));
    await repo.lamMoiNeuCu(const Duration(minutes: 5));
    expect(api.soLanHoi, 1);
    now = now.add(const Duration(minutes: 2));
    await repo.lamMoiNeuCu(const Duration(minutes: 5));
    expect(api.soLanHoi, 2);
  });

  test('xoaPhien: RAM về Basic, kho GIỮ', () async {
    await repo.datTaiKhoan(10);
    await repo.lamMoi();
    repo.xoaPhien();
    expect(repo.hienTai.laPremium(now), isFalse);
    expect(repo.idaccount, isNull);
    expect((await kho.doc(10))!.laPremium(now), isTrue);
  });

  group('nối nguồn', () {
    test(
        'phiên: AuthSuccess → đặt tài khoản + làm mới; null → xoá phiên; '
        'cùng tài khoản phát lại không hỏi thêm', () async {
      final phien = StreamController<PhienGoi?>();
      repo.noiPhien(phien.stream);
      phien.add((idaccount: 10, loaiPhien: 'Basic'));
      await _nghi();
      await _nghi();
      expect(repo.idaccount, 10);
      expect(api.soLanHoi, 1);
      phien.add((idaccount: 10, loaiPhien: 'Basic'));
      await _nghi();
      expect(api.soLanHoi, 1,
          reason: 'AuthSuccess re-emit không phải lý do hỏi lại');
      phien.add(null);
      await _nghi();
      expect(repo.idaccount, isNull);
      await phien.close();
    });

    test('vòng đời: resumed → lamMoiNeuCu(5 phút)', () async {
      await repo.datTaiKhoan(10);
      await repo.lamMoi();
      final vd = StreamController<AppLifecycleState>();
      repo.noiVongDoi(vd.stream);
      vd.add(AppLifecycleState.resumed);
      await _nghi();
      expect(api.soLanHoi, 1, reason: 'vừa làm mới, chưa cũ');
      now = now.add(const Duration(minutes: 6));
      vd.add(AppLifecycleState.resumed);
      await _nghi();
      expect(api.soLanHoi, 2);
      vd.add(AppLifecycleState.paused);
      await _nghi();
      expect(api.soLanHoi, 2);
      await vd.close();
    });

    test('socket: taiKhoanNangCap → lamMoi NGAY (không giãn); sự kiện khác im',
        () async {
      await repo.datTaiKhoan(10);
      await repo.lamMoi();
      final sk = StreamController<RealtimeEvent>();
      repo.noiSuKien(sk.stream);
      sk.add(RealtimeEvent.dongBoXong);
      await _nghi();
      expect(api.soLanHoi, 1);
      sk.add(RealtimeEvent.taiKhoanNangCap);
      await _nghi();
      expect(api.soLanHoi, 2);
      await sk.close();
    });
  });
}
