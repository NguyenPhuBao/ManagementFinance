/// Khối "Nhận xét" dùng chung cho bốn màn: nhận gói số, hiện mẫu câu ngay,
/// thay bằng câu của bộ diễn giải khi xong; thẻ số liệu in đúng chuỗi của gói.
library;

import 'package:flowmoney/features/ai_edge/domain/bo_dien_giai.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';
import 'package:flowmoney/features/ai_edge/presentation/widgets/khoi_nhan_xet.dart';
import 'package:flowmoney/features/ai_edge/presentation/widgets/the_so_lieu.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gia extends GoiSo {
  @override
  final String man = 'ngan_sach';
  @override
  final List<SoLieu> soLieu;
  final String cau;
  final MucNhanXet muc;
  _Gia(this.cau, this.soLieu, {this.muc = MucNhanXet.binhThuong});
  @override
  bool get thieuDuLieu => muc == MucNhanXet.thieuDuLieu;
  @override
  NhanXet mauCau() => NhanXet(cau: cau, theSoLieu: soLieu, muc: muc);
}

class _BoCham implements BoDienGiai {
  final String cau;
  int soLanGoi = 0;
  _BoCham(this.cau);
  @override
  Future<NhanXet> dienGiai(GoiSo goi) async {
    soLanGoi++;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return NhanXet(
        cau: cau,
        theSoLieu: goi.soLieu,
        muc: MucNhanXet.binhThuong,
        tuMoHinh: true);
  }
}

class _BoLoi implements BoDienGiai {
  @override
  Future<NhanXet> dienGiai(GoiSo goi) async => throw StateError('runtime');
}

Widget _app(Widget child, {double rong = 411}) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Center(child: SizedBox(width: rong, child: child)),
      ),
    );

void main() {
  final goi = _Gia('Giáo dục: đã dùng 2.100.000 đ / 3.000.000 đ (70,0%).', [
    soTien('Đã chi', 2100000),
    soTien('Hạn mức', 3000000),
    soPhanTram('Tỉ lệ', 70),
  ]);

  testWidgets('mẫu câu và từng chuỗi số liệu hiện ra; không nhãn AI',
      (tester) async {
    await tester.pumpWidget(_app(KhoiNhanXet(goi: goi)));
    await tester.pumpAndSettle();
    expect(find.text(goi.cau), findsOneWidget);
    expect(find.textContaining('2.100.000 đ'), findsWidgets);
    expect(find.textContaining('3.000.000 đ'), findsWidgets);
    expect(find.textContaining('70,0%'), findsWidgets);
    expect(find.text('AI'), findsNothing);
    expect(find.text('NHẬN XÉT'), findsOneWidget);
  });

  testWidgets(
      'bộ diễn giải chậm: mẫu câu hiện NGAY, câu mô hình thay sau, có nhãn AI',
      (tester) async {
    final bo = _BoCham('Câu của mô hình.');
    await tester.pumpWidget(_app(KhoiNhanXet(goi: goi, boDienGiai: bo)));
    await tester.pump();
    expect(find.text(goi.cau), findsOneWidget,
        reason: 'không được để trống trong lúc chờ');
    expect(find.text('AI'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Câu của mô hình.'), findsOneWidget);
    expect(find.text(goi.cau), findsNothing);
    expect(find.text('AI'), findsOneWidget);
    expect(bo.soLanGoi, 1);
  });

  testWidgets('thiếu dữ liệu: câu hiện, KHÔNG có thẻ số liệu', (tester) async {
    final rong = _Gia('Chưa đủ dữ liệu tháng này để nhận xét.', const [],
        muc: MucNhanXet.thieuDuLieu);
    await tester.pumpWidget(_app(KhoiNhanXet(goi: rong)));
    await tester.pumpAndSettle();
    expect(find.text(rong.cau), findsOneWidget);
    expect(find.byType(TheSoLieu), findsNothing);
  });

  testWidgets('câu dài 200 ký tự ở 411dp không tràn', (tester) async {
    final dai = _Gia('Bạn đã dùng ' * 12 + 'hết.', goi.soLieu);
    await tester.pumpWidget(_app(KhoiNhanXet(goi: dai)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('bộ diễn giải ném lỗi → vẫn hiện mẫu câu, không exception',
      (tester) async {
    await tester.pumpWidget(_app(KhoiNhanXet(goi: goi, boDienGiai: _BoLoi())));
    await tester.pumpAndSettle();
    expect(find.text(goi.cau), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mức cảnh báo: có viền trái màu lỗi', (tester) async {
    final cb = _Gia('Đã vượt.', goi.soLieu, muc: MucNhanXet.canhBao);
    await tester.pumpWidget(_app(KhoiNhanXet(goi: cb)));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('nhan-xet-vien-canh-bao')), findsOneWidget);
    // Gói giả `cb` và `goi` cùng số liệu → cùng dấu vân, nên pump thẳng widget
    // mới sẽ giữ State cũ (đúng thiết kế: stream phát lại cùng số thì không
    // dựng lại). Tháo ra trước để ca này đo bản dựng mới.
    await tester.pumpWidget(_app(const SizedBox()));
    await tester.pumpWidget(_app(KhoiNhanXet(goi: goi)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nhan-xet-vien-canh-bao')), findsNothing);
  });

  testWidgets('nền tối (Trang chủ) vẫn hiện đủ câu và chip', (tester) async {
    await tester.pumpWidget(_app(KhoiNhanXet(goi: goi, nenToi: true)));
    await tester.pumpAndSettle();
    expect(find.text(goi.cau), findsOneWidget);
    expect(find.byType(TheSoLieu), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
