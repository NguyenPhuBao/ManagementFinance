// Thẻ tiến độ mục tiêu chung (đợt 2, Task 7; Stitch 7b5f0f89).
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/household/domain/muc_tieu_chung.dart';
import 'package:flowmoney/features/household/presentation/widgets/tien_do_muc_tieu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/font_that.dart';
import '../../../../helpers/nha_gia.dart';

final _homNay = DateTime(2026, 11, 2, 10);

TienDoMucTieuChung _tienDo({double soDu = 12000000, double dich = 20000000, DateTime? han}) => tienDoMucTieuChung(
      mucTieu: GoalEntity(
        id: 'g',
        idaccount: 18,
        idhousehold: 12,
        name: 'Mục tiêu',
        targetAmount: dich,
        targetDate: han ?? DateTime(2026, 12, 31),
        walletId: 'v1',
        updatedAt: DateTime(2026, 11, 1),
      ),
      soDuVi: soDu,
      now: _homNay,
    );

Color _mauDay(WidgetTester t) => t.widget<ColoredBox>(find.byKey(const Key('tien-do-day'))).color;

Future<void> _dung(WidgetTester t, Widget w) async {
  dat360(t);
  await t.pumpWidget(MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: w))));
}

void main() {
  setUpAll(napFontThat);

  group('TienDoGon', () {
    testWidgets('60 %: dòng a / b và phần trăm, thanh xanh', (t) async {
      await _dung(t, TienDoGon(tienDo: _tienDo()));
      expect(find.text('12.000.000 / 20.000.000 đ'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
      expect(_mauDay(t), const Color(0xFF006E1C));
    });

    testWidgets('đạt: nhãn Đã đạt mục tiêu, 100%, không còn dòng a / b', (t) async {
      await _dung(t, TienDoGon(tienDo: _tienDo(soDu: 25000000)));
      expect(find.text('Đã đạt mục tiêu'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.textContaining(' / '), findsNothing, reason: 'đạt rồi thì dòng a / b nhường chỗ cho nhãn');
    });

    testWidgets('quá hạn: nhãn Quá hạn, vẫn a / b, thanh cam', (t) async {
      await _dung(t, TienDoGon(tienDo: _tienDo(han: DateTime(2026, 10, 31))));
      expect(find.text('Quá hạn'), findsOneWidget);
      expect(find.text('12.000.000 / 20.000.000 đ'), findsOneWidget);
      expect(_mauDay(t), const Color(0xFFE65100));
    });

    testWidgets('360 dp, hai số 13 chữ số: không tràn, dòng a / b một dòng', (t) async {
      await _dung(t, SizedBox(width: 200, child: TienDoGon(tienDo: _tienDo(soDu: 1234567890123, dich: 9999999999999))));
      expect(t.takeException(), isNull);
      final chu = find.textContaining(' / ');
      expect(chu, findsOneWidget);
      expect(t.getSize(chu).height, lessThan(20), reason: 'Text xuống dòng không báo tràn: đo chiều cao một dòng cỡ 11');
    });
  });

  group('KhoiMucTieuChiTiet', () {
    testWidgets('đang chạy: MỤC TIÊU, a / b — 60%, Còn thiếu, Còn lại + hạn, Cần góp', (t) async {
      await _dung(t, KhoiMucTieuChiTiet(tienDo: _tienDo()));
      expect(find.text('MỤC TIÊU'), findsOneWidget);
      expect(find.text('12.000.000 / 20.000.000 đ — 60%'), findsOneWidget);
      expect(find.text('Còn thiếu'), findsOneWidget);
      expect(find.text('8.000.000 đ'), findsOneWidget);
      expect(find.text('Còn lại'), findsOneWidget);
      expect(find.textContaining('59 ngày', findRichText: true), findsOneWidget);
      expect(find.textContaining('(hạn 31/12/2026)', findRichText: true), findsOneWidget);
      expect(find.text('Cần góp'), findsOneWidget);
      expect(find.text('khoảng 4.000.000 đ mỗi tháng'), findsOneWidget);
    });

    testWidgets('quá hạn: MỤC TIÊU (QUÁ HẠN), Đã hết hạn ngày, không Cần góp', (t) async {
      await _dung(t, KhoiMucTieuChiTiet(tienDo: _tienDo(han: DateTime(2026, 10, 31))));
      expect(find.text('MỤC TIÊU (QUÁ HẠN)'), findsOneWidget);
      expect(find.text('Đã hết hạn ngày 31/10/2026'), findsOneWidget);
      expect(find.text('Thời hạn'), findsOneWidget);
      expect(_mauDay(t), const Color(0xFFE65100));
    });

    testWidgets('quá hạn: không có dòng Cần góp', (t) async {
      await _dung(t, KhoiMucTieuChiTiet(tienDo: _tienDo(han: DateTime(2026, 10, 31))));
      expect(find.text('Cần góp'), findsNothing, reason: 'quá hạn thì không còn câu cần góp mỗi tháng');
    });

    testWidgets('đạt: Đã đạt mục tiêu, không Còn thiếu, không Cần góp', (t) async {
      await _dung(t, KhoiMucTieuChiTiet(tienDo: _tienDo(soDu: 20000000)));
      expect(find.text('Đã đạt mục tiêu'), findsOneWidget);
      expect(find.text('Còn thiếu'), findsNothing);
      expect(find.text('Cần góp'), findsNothing);
    });

    testWidgets('360 dp, hai số 13 chữ số: không tràn, dòng a / b một dòng', (t) async {
      await _dung(t, KhoiMucTieuChiTiet(tienDo: _tienDo(soDu: 1234567890123, dich: 9999999999999)));
      expect(t.takeException(), isNull);
      final chu = find.textContaining(' / ');
      expect(chu, findsOneWidget);
      expect(t.getSize(chu).height, lessThan(20), reason: 'dòng a / b — % cỡ 12 phải một dòng, co bằng FittedBox');
    });
  });
}
