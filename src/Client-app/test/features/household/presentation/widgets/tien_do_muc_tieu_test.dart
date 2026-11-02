// Thẻ tiến độ mục tiêu chung (đợt 2, Task 7; Stitch 7b5f0f89).
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/household/domain/muc_tieu_chung.dart';
import 'package:flowmoney/features/household/presentation/widgets/tien_do_muc_tieu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  await t.pumpWidget(bocTrangNha(Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: w)), idaccount: 18));
}

/// Phần đầy / bề rộng thanh (cùng ClipRRect bọc cả hai).
double _doDay(WidgetTester t) {
  final day = find.byKey(const Key('tien-do-day'));
  final thanh = find.ancestor(of: day, matching: find.byType(ClipRRect));
  return t.getSize(day).width / t.getSize(thanh).width;
}

/// Chữ số `a / b` không bị cụt: bọc `FittedBox`, không quá số dòng, và bề rộng HIỂN THỊ (sau co) nằm trong [rong].
void _kiemSoKhongCut(WidgetTester t, double rong) {
  final chu = find.textContaining(' / ');
  expect(chu, findsOneWidget);
  expect(find.ancestor(of: chu, matching: find.byType(FittedBox)), findsOneWidget,
      reason: 'số 13 chữ số rộng hơn chỗ: phải co bằng FittedBox, không cụt');
  expect((t.renderObject(chu) as RenderParagraph).didExceedMaxLines, isFalse, reason: 'không bị cắt chữ');
  final hienThi = t.getBottomRight(chu).dx - t.getTopLeft(chu).dx;
  expect(hienThi, lessThanOrEqualTo(rong), reason: 'bề rộng hiển thị phải nằm trong chỗ cho phép');
  expect(t.getSize(chu).width, greaterThan(rong), reason: 'tiền đề: bề rộng tự nhiên vượt chỗ, nên phải co');
}

void main() {
  setUpAll(napFontThat);

  group('TienDoGon', () {
    testWidgets('60 %: dòng a / b và phần trăm, thanh xanh', (t) async {
      await _dung(t, TienDoGon(tienDo: _tienDo()));
      expect(find.text('12.000.000 / 20.000.000 đ'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
      expect(_mauDay(t), const Color(0xFF006E1C));
      expect(_doDay(t), closeTo(.6, .001), reason: 'phần đầy phải đúng 60 % bề rộng thanh');
    });

    testWidgets('độ đầy: 0 % thì phần đầy rộng 0, đạt thì kín thanh', (t) async {
      await _dung(t, TienDoGon(tienDo: _tienDo(soDu: 0)));
      expect(_doDay(t), 0, reason: '0 % không được vẽ thanh đầy');
      await _dung(t, TienDoGon(tienDo: _tienDo(soDu: 25000000)));
      expect(_doDay(t), closeTo(1, .001), reason: 'đạt (kể cả vượt) thì thanh kín, không tràn');
    });

    testWidgets('99,6 % chưa đạt: chữ 99%, không 100%, Semantics cũng 99%', (t) async {
      final sem = t.ensureSemantics();
      await _dung(t, TienDoGon(tienDo: _tienDo(soDu: 19920000)));
      expect(find.text('99%'), findsOneWidget);
      expect(find.text('100%'), findsNothing, reason: 'chưa đạt mà hiện 100% là nói dối khi còn thiếu tiền');
      expect(find.bySemanticsLabel('Tiến độ 99%'), findsOneWidget);
      sem.dispose();
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
      expect(t.getSize(chu).height, lessThan(20), reason: 'Text xuống dòng không báo tràn: đo chiều cao một dòng cỡ 11');
      _kiemSoKhongCut(t, 200);
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
      expect(find.text('Còn thiếu'), findsOneWidget, reason: 'quá hạn vẫn còn thiếu tiền');
      expect(find.text('Còn lại'), findsNothing, reason: 'hạn đã qua: không còn "n ngày"');
      expect(_mauDay(t), const Color(0xFFE65100));
    });

    testWidgets('quá hạn: không có dòng Cần góp', (t) async {
      await _dung(t, KhoiMucTieuChiTiet(tienDo: _tienDo(han: DateTime(2026, 10, 31))));
      expect(find.text('Cần góp'), findsNothing, reason: 'quá hạn thì không còn câu cần góp mỗi tháng');
    });

    testWidgets('99,6 % chưa đạt: dòng a / b — 99%, không 100%', (t) async {
      await _dung(t, KhoiMucTieuChiTiet(tienDo: _tienDo(soDu: 19920000)));
      expect(find.text('19.920.000 / 20.000.000 đ — 99%'), findsOneWidget);
      expect(find.text('Còn thiếu'), findsOneWidget);
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
      expect(t.getSize(chu).height, lessThan(20), reason: 'dòng a / b — % cỡ 12 phải một dòng, co bằng FittedBox');
      _kiemSoKhongCut(t, 270);
      expect(find.textContaining('Cần góp'), findsOneWidget);
      expect(find.textContaining('khoảng', findRichText: true), findsOneWidget);
    });
  });
}
