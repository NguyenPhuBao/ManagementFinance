import 'dart:typed_data';

import 'package:flowmoney/features/ai_chat/presentation/widgets/tro_ly_ai/thanh_nhap_tro_ly.dart';
import 'package:flowmoney/features/transaction/data/datasources/ghi_am.dart';
import 'package:flowmoney/features/transaction/data/datasources/kenh_micro.dart';
import 'package:flowmoney/features/transaction/data/datasources/nghe_android.dart';
import 'package:flowmoney/features/transaction/data/nguon_giong_noi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Micro ở màn Trợ lý AI (người dùng chốt 2026-11-20): nói xong câu VÀO Ô, không tự gửi; đang nghe thì Gửi khoá; AI đang
/// trả lời thì micro khoá; ô khoá (Basic / tạm ngừng) hoặc không có bộ giọng nói thì không micro.
class _AndroidGia implements NgheAndroid {
  int soLanNghe = 0;
  late void Function(String, bool) onChu;
  @override
  Future<bool> khoiTao() async => true;
  @override
  Future<void> nghe({
    required bool trenMay,
    required void Function(String chu, bool xong) onChu,
    required void Function(String ma) onLoi,
    required void Function() onDung,
  }) async {
    soLanNghe++;
    this.onChu = onChu;
  }

  @override
  Future<void> dung() async {}
  @override
  Future<void> huy() async {}
}

class _GhiAmGia implements GhiAm {
  @override
  Future<bool> coQuyen() async => true;
  @override
  Future<void> batDau(String duongTep, {required void Function(double dbfs) onBienDo}) async {}
  @override
  Future<String?> dung() async => '/tam/a.wav';
  @override
  Future<void> huy() async {}
}

class _MicroGia implements KenhMicro {
  @override
  Future<bool> biChan() async => false;
  @override
  Future<void> moCaiDat() async {}
}

void main() {
  late _AndroidGia a;
  late TextEditingController o;
  late List<String> daGui;

  setUp(() {
    a = _AndroidGia();
    o = TextEditingController();
    daGui = [];
  });

  NguonGiongNoi nguon() => NguonGiongNoi(
        android: a,
        ghiAm: _GhiAmGia(),
        micro: _MicroGia(),
        coMang: () async => true,
        tepTam: () async => '/tam/a.wav',
        docTep: (_) async => Uint8List(4),
        xoaTep: (_) async {},
      );

  Widget app({bool dangHoi = false, bool khoaCaO = false, NguonGiongNoi? giongNoi}) => MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ThanhNhapTroLy(
              controller: o,
              dangHoi: dangHoi,
              khoaCaO: khoaCaO,
              goiY: 'Hỏi về số liệu của bạn…',
              toiDaKyTu: 500,
              onGui: daGui.add,
              giongNoi: giongNoi,
            ),
          ),
        ),
      );

  IconButton nut(WidgetTester t, String k) => t.widget<IconButton>(find.byKey(Key(k)));

  testWidgets('⭐ nói xong → câu VÀO Ô, KHÔNG tự gửi; bấm Gửi mới gửi', (tester) async {
    await tester.pumpWidget(app(giongNoi: nguon()));
    await tester.tap(find.byKey(const Key('tro-ly-micro')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(a.soLanNghe, 1);
    expect(find.byKey(const Key('tro-ly-dang-nghe')), findsOneWidget);
    expect(find.byKey(const Key('tro-ly-dung')), findsOneWidget, reason: 'nút micro thành nút Dừng');

    a.onChu('tháng này chi', false);
    await tester.pump();
    expect(o.text, 'tháng này chi', reason: 'chữ tạm hiện dần trong ô');
    expect(nut(tester, 'tro-ly-gui').onPressed, isNull, reason: 'đang nghe thì Gửi khoá (không gửi chữ tạm)');

    a.onChu('tháng này chi bao nhiêu cho ăn uống', true);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(o.text, 'tháng này chi bao nhiêu cho ăn uống');
    expect(daGui, isEmpty, reason: 'người dùng chốt: nói xong không tự gửi');
    expect(find.byKey(const Key('tro-ly-dang-nghe')), findsNothing);

    await tester.tap(find.byKey(const Key('tro-ly-gui')));
    await tester.pump();
    expect(daGui, ['tháng này chi bao nhiêu cho ăn uống']);
  });

  testWidgets('AI đang trả lời → micro khoá', (tester) async {
    await tester.pumpWidget(app(giongNoi: nguon(), dangHoi: true));
    expect(nut(tester, 'tro-ly-micro').onPressed, isNull);
    expect(nut(tester, 'tro-ly-gui').onPressed, isNull);
  });

  testWidgets('ô khoá (Basic / tạm ngừng) → không micro', (tester) async {
    await tester.pumpWidget(app(giongNoi: nguon(), khoaCaO: true));
    expect(find.byKey(const Key('tro-ly-micro')), findsNothing);
  });

  testWidgets('không có bộ giọng nói → không micro, Gửi vẫn dùng được', (tester) async {
    await tester.pumpWidget(app());
    expect(find.byKey(const Key('tro-ly-micro')), findsNothing);
    await tester.enterText(find.byType(TextField), 'chi ăn uống tháng này');
    await tester.tap(find.byKey(const Key('tro-ly-gui')));
    expect(daGui, ['chi ăn uống tháng này']);
  });
}
