// test/features/transaction/presentation/bloc/nghe_giong_noi_cubit_test.dart
/// C4 §2.1–2.2 — trạng thái micro: quyền → chọn lối → nghe / ghi → (chép lời) → một câu cho ô Nhập nhanh.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flowmoney/features/transaction/data/chep_loi_bang_gemma.dart';
import 'package:flowmoney/features/transaction/data/datasources/ghi_am.dart';
import 'package:flowmoney/features/transaction/data/datasources/kenh_micro.dart';
import 'package:flowmoney/features/transaction/data/datasources/nghe_android.dart';
import 'package:flowmoney/features/transaction/data/nguon_giong_noi.dart';
import 'package:flowmoney/features/transaction/domain/chon_loi_nghe.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/nghe_giong_noi_cubit.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/nghe_giong_noi_state.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

class _Android implements NgheAndroid {
  bool sanSang = true;
  bool? trenMay;
  bool ngheNem = false;
  int soLanNghe = 0, soLanDung = 0, soLanHuy = 0;
  late void Function(String, bool) onChu;
  late void Function(String) onLoi;
  late void Function() onDung;
  @override
  Future<bool> khoiTao() async => sanSang;
  @override
  Future<void> nghe({
    required bool trenMay,
    required void Function(String chu, bool xong) onChu,
    required void Function(String ma) onLoi,
    required void Function() onDung,
  }) async {
    if (ngheNem) throw StateError('nghe lỗi');
    soLanNghe++;
    this.trenMay = trenMay;
    this.onChu = onChu;
    this.onLoi = onLoi;
    this.onDung = onDung;
  }

  @override
  Future<void> dung() async => soLanDung++;
  @override
  Future<void> huy() async => soLanHuy++;
}

class _GhiAm implements GhiAm {
  bool quyen = true;
  String? tep;
  int soLanHuy = 0;
  bool dungNem = false, batDauNem = false;
  void Function(double)? onBienDo;
  @override
  Future<bool> coQuyen() async => quyen;
  @override
  Future<void> batDau(String duongTep, {required void Function(double dbfs) onBienDo}) async {
    if (batDauNem) throw StateError('ghi lỗi');
    tep = duongTep;
    this.onBienDo = onBienDo;
  }

  @override
  Future<String?> dung() async {
    if (dungNem) throw StateError('dừng lỗi');
    return tep;
  }

  @override
  Future<void> huy() async => soLanHuy++;
}

class _Micro implements KenhMicro {
  bool chan = false;
  @override
  Future<bool> biChan() async => chan;
  @override
  Future<void> moCaiDat() async {}
}

class _Gemma implements ChepLoiBangGemma {
  bool san = true;
  String? tra = 'Hôm qua ăn phở 45.000';
  Completer<String?>? treo;
  int soLanChep = 0;
  int soLanHuy = 0;
  @override
  Future<bool> sanSangChua() async => san;
  @override
  Future<String?> chep(Uint8List wav) async {
    soLanChep++;
    final t = treo;
    if (t != null) {
      treo = null;
      return t.future;
    }
    return tra;
  }

  @override
  Future<void> huy() async => soLanHuy++;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late _Android a;
  late _GhiAm g;
  late _Micro m;
  late List<String> daXoa;
  late List<String> teps;

  setUp(() {
    a = _Android();
    g = _GhiAm();
    m = _Micro();
    daXoa = [];
    teps = [];
  });

  void napHaiTep() => teps.addAll(['/tam/a.wav', '/tam/b.wav']);

  NgheGiongNoiCubit tao({bool coMang = true, _Gemma? gemma, Future<Uint8List> Function(String)? docTep}) {
    final c = NgheGiongNoiCubit(
      nguon: NguonGiongNoi(
        android: a,
        ghiAm: g,
        micro: m,
        coMang: () async => coMang,
        gemma: gemma,
        tepTam: () async => teps.isEmpty ? '/tam/a.wav' : teps.removeAt(0),
        docTep: docTep ?? (_) async => Uint8List(4),
        xoaTep: (p) async => daXoa.add(p),
      ),
    );
    addTearDown(c.close);
    return c;
  }

  test('⭐ có mạng: nghe Android, chữ tạm vào chuTam, chữ cuối thành một câu', () async {
    final c = tao();
    await c.bam();
    expect(c.state.trangThai, TrangThaiNghe.dangNghe);
    expect(a.trenMay, isFalse);
    a.onChu('hôm qua ăn', false);
    expect(c.state.chuTam, 'hôm qua ăn');
    a.onChu('hôm qua ăn phở 45 nghìn', true);
    expect(c.state.trangThai, TrangThaiNghe.cho);
    expect((c.state.cauXong, c.state.soLanXong), ('hôm qua ăn phở 45 nghìn', 1));
  });

  test('bấm khi đang nghe → dừng Android (chữ cuối về sau)', () async {
    final c = tao();
    await c.bam();
    await c.bam();
    expect(a.soLanDung, 1);
  });

  test('quyền bị từ chối → thông báo, không nghe', () async {
    g.quyen = false;
    final c = tao();
    await c.bam();
    expect(c.state.thongBao, ThongBaoNghe.tuChoiQuyen);
    expect(a.soLanNghe, 0);
  });

  test('quyền bị chặn hẳn → thông báo có lối mở cài đặt', () async {
    g.quyen = false;
    m.chan = true;
    final c = tao();
    await c.bam();
    expect(c.state.thongBao, ThongBaoNghe.biChanQuyen);
  });

  test('mất mạng, máy không có dịch vụ nhận dạng, không Gemma → không lối nào', () async {
    a.sanSang = false;
    final c = tao(coMang: false);
    await c.bam();
    expect(c.state.thongBao, ThongBaoNghe.khongCoLoi);
  });

  test('mất mạng, Gemma chưa sẵn sàng → Android trên máy (onDevice)', () async {
    final c = tao(coMang: false, gemma: _Gemma()..san = false);
    await c.bam();
    expect(a.trenMay, isTrue);
  });

  test('⭐ mất mạng + Gemma: ghi âm, nói rồi im 2 giây → tự dừng, chép lời, tệp bị xoá', () async {
    final c = tao(coMang: false, gemma: _Gemma());
    await c.bam();
    expect(c.state.trangThai, TrangThaiNghe.dangGhi);
    for (var i = 0; i < 5; i++) {
      g.onBienDo!(-20);
    }
    for (var i = 0; i < 20; i++) {
      g.onBienDo!(-50);
    }
    await pumpEventQueue();
    expect(c.state.trangThai, TrangThaiNghe.cho);
    expect(c.state.cauXong, 'Hôm qua ăn phở 45.000');
    expect(daXoa, ['/tam/a.wav'], reason: 'không lưu âm thanh (spec §2.4)');
    expect(c.state.giay, 2);
  });

  test('⚠️ 6 giây không có tiếng → KHÔNG đưa bản ghi cho Gemma, báo "không nghe rõ", tệp bị xoá', () async {
    final gm = _Gemma();
    final c = tao(coMang: false, gemma: gm);
    await c.bam();
    for (var i = 0; i < 60; i++) {
      g.onBienDo!(-60);
    }
    await pumpEventQueue();
    expect(gm.soLanChep, 0,
        reason: 'Realme 2026-10-21: bản ghi im lặng đem đi chép → Gemma trả lại câu lệnh và app điền nó vào ô; '
            'còn tốn ~8 s mô hình chặn hàng đợi chép');
    expect(c.state.trangThai, TrangThaiNghe.cho);
    expect(c.state.thongBao, ThongBaoNghe.khongNgheRo);
    expect(c.state.soLanXong, 0);
    expect(daXoa, ['/tam/a.wav']);
  });

  test('bấm ■ khi bộ đo chưa thấy tiếng vẫn chép (ngưỡng dBFS chưa đo mọi máy — người dùng đã nói thì đừng vứt)',
      () async {
    final gm = _Gemma();
    final c = tao(coMang: false, gemma: gm);
    await c.bam();
    for (var i = 0; i < 20; i++) {
      g.onBienDo!(-60);
    }
    await c.bam(); // bấm ■
    await pumpEventQueue();
    expect(gm.soLanChep, 1);
    expect(c.state.cauXong, 'Hôm qua ăn phở 45.000');
  });

  test('Gemma chép rỗng → "không nghe rõ", tệp vẫn bị xoá', () async {
    final c = tao(coMang: false, gemma: _Gemma()..tra = null);
    await c.bam();
    await c.bam(); // bấm ■
    await pumpEventQueue();
    expect(c.state.thongBao, ThongBaoNghe.khongNgheRo);
    expect(daXoa, ['/tam/a.wav']);
  });

  test('⭐ Android mất mạng giữa chừng + Gemma → gợi ý nói lại; lượt sau đi Gemma dù có mạng', () async {
    final c = tao(gemma: _Gemma());
    await c.bam();
    a.onLoi('error_network');
    expect(c.state.thongBao, ThongBaoNghe.matMangThuGemma);
    expect(c.state.trangThai, TrangThaiNghe.cho);
    await c.bam();
    expect(c.state.trangThai, TrangThaiNghe.dangGhi);
  });

  test('Android xong mà không có chữ → "không nghe rõ"', () async {
    final c = tao();
    await c.bam();
    a.onDung();
    expect(c.state.thongBao, ThongBaoNghe.khongNgheRo);
    expect(c.state.trangThai, TrangThaiNghe.cho);
  });

  test('Huỷ khi đang ghi: dừng bộ ghi, xoá tệp, mẫu biên độ về sau bị bỏ', () async {
    final c = tao(coMang: false, gemma: _Gemma());
    await c.bam();
    await c.huy();
    expect(g.soLanHuy, 1);
    expect(daXoa, ['/tam/a.wav']);
    g.onBienDo!(-50);
    expect(c.state.trangThai, TrangThaiNghe.cho);
  });

  test('đóng Cubit khi đang nghe Android → huỷ Android', () async {
    final c = tao();
    await c.bam();
    await c.close();
    expect(a.soLanHuy, 1);
  });

  test('P9: error_language_unavailable + Gemma sẵn sàng → khongCoGoiThuGemma, lượt sau đi Gemma dù có mạng', () async {
    final c = tao(gemma: _Gemma());
    await c.bam();
    a.onLoi('error_language_unavailable');
    expect(c.state.thongBao, ThongBaoNghe.khongCoGoiThuGemma);
    await c.bam();
    expect(c.state.trangThai, TrangThaiNghe.dangGhi);
  });

  test('P11: nghe() ném → về chờ + loiChung', () async {
    a.ngheNem = true;
    final c = tao();
    await c.bam();
    expect(c.state.trangThai, TrangThaiNghe.cho);
    expect(c.state.thongBao, ThongBaoNghe.loiChung);
  });

  test('P12: close() khi đang ghi → huỷ bộ ghi đúng 1 lần, tệp đã xoá', () async {
    final c = tao(coMang: false, gemma: _Gemma());
    await c.bam();
    await c.close();
    expect(g.soLanHuy, 1);
    expect(daXoa, ['/tam/a.wav']);
  });

  test('P13: hai close() đồng thời không huỷ hai lần', () async {
    final c = tao();
    await c.bam();
    unawaited(c.close());
    await c.close();
    expect(a.soLanHuy, 1);
  });

  test('hạn chót: dangNghe mà gói không callback → huỷ, về chờ, loiChung', () {
    fakeAsync((fa) {
      final c = tao();
      unawaited(c.bam());
      fa.flushMicrotasks();
      expect(c.state.trangThai, TrangThaiNghe.dangNghe);
      fa.elapse(kHanNgheAndroid - const Duration(seconds: 1));
      expect(c.state.trangThai, TrangThaiNghe.dangNghe);
      fa.elapse(const Duration(seconds: 2));
      fa.flushMicrotasks();
      expect(c.state.trangThai, TrangThaiNghe.cho);
      expect(c.state.thongBao, ThongBaoNghe.loiChung);
      expect(a.soLanHuy, 1);
    });
  });

  test('hạn chót bị huỷ khi lượt kết thúc đúng hạn', () {
    fakeAsync((fa) {
      final c = tao();
      unawaited(c.bam());
      fa.flushMicrotasks();
      a.onChu('xong', true);
      fa.elapse(kHanNgheAndroid * 2);
      fa.flushMicrotasks();
      expect(c.state.thongBao, isNull);
      expect(a.soLanHuy, 0);
      expect(c.state.cauXong, 'xong');
    });
  });

  test('lượt cũ về muộn không xoá tệp của lượt mới', () async {
    napHaiTep();
    final gm = _Gemma()..treo = Completer<String?>();
    final cu = gm.treo!;
    final c = tao(coMang: false, gemma: gm);
    await c.bam();
    unawaited(c.bam());
    await pumpEventQueue();
    await c.huy();
    await c.bam(); // lượt mới ghi tệp b
    expect(c.state.trangThai, TrangThaiNghe.dangGhi);
    cu.complete('cũ');
    await pumpEventQueue();
    expect(daXoa.contains('/tam/b.wav'), isFalse, reason: 'tệp lượt mới còn đang ghi');
    expect(c.state.trangThai, TrangThaiNghe.dangGhi);
  });

  test('M1: Huỷ rơi vào khe đọc tệp → KHÔNG gọi mô hình (không chặn hàng đợi 10–60 s)', () async {
    final doc = Completer<Uint8List>();
    final gm = _Gemma();
    final c = tao(coMang: false, gemma: gm, docTep: (_) => doc.future);
    await c.bam();
    unawaited(c.bam());
    await pumpEventQueue();
    expect(c.state.trangThai, TrangThaiNghe.dangChep);
    await c.huy();
    doc.complete(Uint8List(4));
    await pumpEventQueue();
    expect(gm.soLanChep, 0, reason: 'lượt đã huỷ không được tốn lượt mô hình');
    expect(c.state.trangThai, TrangThaiNghe.cho);
  });

  test('onDung sau chữ tạm vẫn lấy chuTam làm câu', () async {
    final c = tao();
    await c.bam();
    a.onChu('ăn phở', false);
    a.onDung();
    expect(c.state.cauXong, 'ăn phở');
  });

  test('ghiAm.dung() ném → không kẹt dangChep: dùng tệp của lượt, xoá tệp, báo không nghe rõ', () async {
    g.dungNem = true;
    final c = tao(coMang: false, gemma: _Gemma());
    await c.bam();
    await c.bam();
    expect(c.state.trangThai, TrangThaiNghe.cho);
    expect(daXoa, ['/tam/a.wav']);
  });

  test('ghiAm.batDau ném → loiChung, tệp xoá', () async {
    g.batDauNem = true;
    final c = tao(coMang: false, gemma: _Gemma());
    await c.bam();
    expect(c.state.thongBao, ThongBaoNghe.loiChung);
    expect(c.state.trangThai, TrangThaiNghe.cho);
    expect(daXoa, ['/tam/a.wav']);
  });

  test('chữ cuối rỗng → dùng chuTam; cả hai rỗng → không nghe rõ (không cauXong rỗng)', () async {
    final c = tao();
    await c.bam();
    a.onChu('ăn phở', false);
    a.onChu('  ', true);
    expect(c.state.cauXong, 'ăn phở');
    await c.bam();
    a.onChu('  ', true);
    expect(c.state.thongBao, ThongBaoNghe.khongNgheRo);
    expect(c.state.soLanXong, 1);
  });
}
