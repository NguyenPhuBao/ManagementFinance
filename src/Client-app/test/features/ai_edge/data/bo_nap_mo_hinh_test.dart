// test/features/ai_edge/data/bo_nap_mo_hinh_test.dart
/// C4 vòng sửa 1 — điều phối nạp: tuần tự hoá, huỷ trong pha nạp, và `SlmRuntimeThat` thật đi qua nó.
library;

import 'dart:async';
import 'dart:io';

import 'package:flowmoney/features/ai_edge/data/bo_nap_mo_hinh.dart';
import 'package:flowmoney/features/ai_edge/domain/nap_da_phuong_thuc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mô hình giả: nạp / đóng mất thời gian (Completer) để ép các lượt chồng nhau.
class _Gia {
  _Gia({this.baoGiu});

  /// G100 — nơi nhận lời báo "tiến trình đang giữ mô hình"; `null` = như trước.
  final Future<void> Function(bool giu)? baoGiu;

  bool co = false;
  int soLanNap = 0, soLanDong = 0, dangNapDongThoi = 0, napDongThoiToiDa = 0;
  Completer<void>? choNap;
  late final BoNapMoHinh bo = BoNapMoHinh(
    baoGiu: baoGiu,
    coMoHinh: () => co,
    dong: () async {
      soLanDong++;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      co = false;
    },
    nap: (duongTep, {required anh, required am}) async {
      soLanNap++;
      dangNapDongThoi++;
      if (dangNapDongThoi > napDongThoiToiDa) napDongThoiToiDa = dangNapDongThoi;
      await (choNap?.future ?? Future<void>.delayed(const Duration(milliseconds: 20)));
      co = true;
      dangNapDongThoi--;
    },
  );
}

void main() {
  test('⭐ hai lượt am đồng thời, chưa có mô hình → nạp 1 lần, đóng 0', () async {
    final g = _Gia();
    await Future.wait([g.bo.can(CanMoHinh.am, '/m'), g.bo.can(CanMoHinh.am, '/m')]);
    expect((g.soLanNap, g.soLanDong), (1, 0), reason: 'lượt hai phải chờ rồi thấy bản hai cờ, không nạp song song');
    expect(g.napDongThoiToiDa, 1);
  });

  test('⭐ đang có bản chữ, anh + am đồng thời → đóng ≤ 1, nạp 1', () async {
    final g = _Gia();
    await g.bo.can(CanMoHinh.chu, '/m');
    g.soLanNap = 0;
    await Future.wait([g.bo.can(CanMoHinh.anh, '/m'), g.bo.can(CanMoHinh.am, '/m')]);
    expect(g.soLanDong, 1);
    expect(g.soLanNap, 1);
    expect((g.bo.coAnh, g.bo.coAm), (true, true));
  });

  test('⭐ huỷ giữa pha nạp → lượt ấy ném LuotNapBiHuy, mô hình vẫn giữ', () async {
    final g = _Gia()..choNap = Completer<void>();
    final moc = g.bo.moc;
    final f = g.bo.can(CanMoHinh.am, '/m', moc: moc);
    final bat = expectLater(f, throwsA(isA<LuotNapBiHuy>()));
    await Future<void>.delayed(Duration.zero);
    g.bo.huy();
    g.choNap!.complete();
    await bat;
    expect(g.co, isTrue, reason: 'không đóng mô hình vừa nạp (đóng là phá luật ≤ 1 lần)');
    expect(g.soLanDong, 0);
  });

  test('lượt mới sau huỷ (moc mới) không bị ảnh hưởng', () async {
    final g = _Gia();
    g.bo.huy();
    await g.bo.can(CanMoHinh.am, '/m', moc: g.bo.moc);
    expect(g.co, isTrue);
  });

  test('một lượt nạp ném lỗi không làm kẹt hàng đợi', () async {
    var lan = 0;
    final bo = BoNapMoHinh(
      coMoHinh: () => false,
      dong: () async {},
      nap: (duongTep, {required anh, required am}) async {
        if (++lan == 1) throw StateError('máy không chạy được');
      },
    );
    await expectLater(bo.can(CanMoHinh.chu, '/m'), throwsStateError);
    await bo.can(CanMoHinh.chu, '/m');
    expect(lan, 2);
  });

  group('⚠️ G100 — báo native "tiến trình đang giữ mô hình" (MainActivity giết tiến trình khi gỡ task)', () {
    /// Bản giả có ghi lại các lần báo, theo thứ tự.
    (_Gia, List<bool>) dung() {
      final bao = <bool>[];
      return (_Gia(baoGiu: (giu) async => bao.add(giu)), bao);
    }

    test('nạp xong → báo true', () async {
      final (g, bao) = dung();
      await g.bo.can(CanMoHinh.chu, '/m');
      expect(bao, [true]);
    });

    test('đổi bản (đóng rồi nạp) → báo false sau khi đóng, true sau khi nạp', () async {
      final (g, bao) = dung();
      await g.bo.can(CanMoHinh.chu, '/m');
      await g.bo.can(CanMoHinh.anh, '/m');
      expect(g.soLanDong, 1);
      expect(bao, [true, false, true]);
    });

    test('⭐ đang nạp thì CHƯA báo true — giết tiến trình giữa pha nạp là để dấu canary GPU sót, đánh dấu GPU hỏng oan',
        () async {
      final (g, bao) = dung();
      g.choNap = Completer<void>();
      final f = g.bo.can(CanMoHinh.chu, '/m');
      await Future<void>.delayed(Duration.zero);
      expect(bao, isEmpty, reason: 'báo trước khi nạp xong thì MainActivity có thể giết tiến trình lúc engine còn nạp');
      g.choNap!.complete();
      await f;
      expect(bao, [true]);
    });

    test('nạp ném lỗi → không báo true', () async {
      final bao = <bool>[];
      final bo = BoNapMoHinh(
        coMoHinh: () => false,
        dong: () async {},
        nap: (duongTep, {required anh, required am}) async => throw StateError('máy không chạy được'),
        baoGiu: (giu) async => bao.add(giu),
      );
      await expectLater(bo.can(CanMoHinh.chu, '/m'), throwsStateError);
      expect(bao, isEmpty);
    });

    test('huỷ giữa pha nạp → mô hình vẫn giữ nên vẫn báo true', () async {
      final (g, bao) = dung();
      g.choNap = Completer<void>();
      final f = g.bo.can(CanMoHinh.am, '/m', moc: g.bo.moc);
      final bat = expectLater(f, throwsA(isA<LuotNapBiHuy>()));
      await Future<void>.delayed(Duration.zero);
      g.bo.huy();
      g.choNap!.complete();
      await bat;
      expect(bao, [true], reason: 'bản vừa nạp nằm trong bộ nhớ dù lượt bị huỷ');
    });
  });

  test('⭐ nối dây: docAnh / chepLoi / moHinhSan cùng đi qua đường nạp chung, không còn khối inline cũ', () {
    final s = File('lib/features/ai_edge/data/datasources/slm_runtime.dart').readAsStringSync();
    expect(s, contains('CanMoHinh.anh'), reason: 'docAnh phải đi qua luật nạp chung');
    expect(s, contains('CanMoHinh.am'), reason: 'chepLoi phải đi qua luật nạp chung');
    expect(s, contains('CanMoHinh.chu'), reason: 'moHinhSan phải đi qua luật nạp chung (nhánh chu của quyetDinhNap)');
    expect(s, isNot(contains('!_coAnh || _coAm')), reason: 'khối inline cũ của docAnh từ chối bản có âm thanh (A5)');
    expect('_boNap.can('.allMatches(s).length, 3);
    expect(s, contains('identical(_chatDangSinh, chat)'), reason: 'finally của lượt cũ xoá mất chat của lượt mới');
  });
}
