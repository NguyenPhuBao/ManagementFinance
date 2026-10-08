/// A5 mục 3, 5.7 — màn `/quet` ("Đang đọc ảnh…"): luật trước, AI chỉ khi Premium + còn ô thiếu, Huỷ hai pha, thay
/// chính nó bằng form (Back từ form về trang trước, không về màn chờ).
///
/// ⚠️ Không `pumpAndSettle` khi vòng xoay còn quay — dùng [_cho].
library;

import 'dart:async';
import 'dart:io';

import 'package:flowmoney/core/ocr/doc_chu_anh.dart';
import 'package:flowmoney/core/ocr/dong_ocr.dart';
import 'package:flowmoney/core/ocr/kho_anh_quet.dart';
import 'package:flowmoney/features/transaction/data/doc_anh_bang_ai.dart';
import 'package:flowmoney/features/transaction/domain/doc_anh_quet.dart';
import 'package:flowmoney/features/transaction/presentation/pages/quet_anh_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/bat_thong_bao.dart';

class _DocChuGia implements DocChuAnh {
  _DocChuGia(this.hang, {this.cho});
  final List<String> hang;
  final Completer<void>? cho;
  @override
  Future<List<DongOcr>> doc(String duongDan) async {
    await cho?.future;
    return [
      for (var i = 0; i < hang.length; i++)
        DongOcr(hang[i], trai: 10, tren: 100.0 + 40 * i, phai: 300, duoi: 130.0 + 40 * i),
    ];
  }
}

class _AiGia implements DocAnhBangAi {
  _AiGia(this.kq, {this.cho});
  final KetQuaAiAnh? kq;
  final Completer<KetQuaAiAnh?>? cho;
  int soLanDoc = 0;
  int soLanHuy = 0;

  @override
  Future<KetQuaAiAnh?> doc(String vanBan, {required DateTime now}) async {
    soLanDoc++;
    if (cho != null) return cho!.future;
    return kq;
  }

  @override
  Future<void> huy() async {
    soLanHuy++;
    if (cho != null && !cho!.isCompleted) cho!.complete(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _hoaDon = [
  'CO.OPMART NGUYEN TRAI',
  'Ngay: 28/09/2026 18:42',
  'OMO 3KG 120.000',
  'GIAY VS 45.000',
  'TONG CONG 165.000',
];

/// Biên lai không nhãn nội dung → `oThieu = {ghiChu}` → AI được gọi (Premium).
const _bienLaiThieuNoiDung = ['Giao dịch thành công', 'Số tiền 150.000 VND', 'Thời gian 02/10/2026 18:45'];

void main() {
  late Directory goc;
  late KhoAnhQuet kho;
  late String anhGoc;
  final now = DateTime(2026, 10, 8, 9, 30);

  setUp(() {
    goc = Directory.systemTemp.createTempSync('quet');
    kho = KhoAnhQuet(thuMuc: () async => goc);
    anhGoc = (File('${goc.path}/chup.jpg')..writeAsBytesSync([1, 2, 3])).path;
  });
  tearDown(() => goc.deleteSync(recursive: true));

  Future<GoRouter> mo(
    WidgetTester tester, {
    required DocChuAnh docChu,
    DocAnhBangAi? ai,
    bool laPremium = true,
  }) async {
    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, __) => const Scaffold(body: Text('Trang trước'))),
        GoRoute(
          path: '/quet',
          builder: (_, s) => QuetAnhPage(
            duongDanAnh: s.extra! as String,
            docChu: docChu,
            kho: kho,
            docAi: ai,
            laPremium: laPremium,
            now: () => now,
          ),
        ),
        GoRoute(path: '/add', builder: (_, s) => Scaffold(body: Text('FORM ${s.uri}'))),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    unawaited(router.push('/quet', extra: anhGoc));
    await tester.pump();
    return router;
  }

  Future<void> cho(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Uri? form() {
    final t = find.textContaining('FORM ').evaluate();
    if (t.isEmpty) return null;
    return Uri.parse((t.single.widget as Text).data!.substring(5));
  }

  testWidgets('⭐ hoá đơn, luật đủ → KHÔNG gọi AI, thay bằng form có khoá quet:, tiền; Back về trang trước',
      (tester) async {
    final ai = _AiGia(null);
    final router = await mo(tester, docChu: _DocChuGia(_hoaDon), ai: ai);
    await cho(tester);
    final u = form();
    expect(u, isNotNull);
    expect(u!.queryParameters['khoa'], startsWith('quet:'));
    expect(u.queryParameters['amount'], '165000');
    expect(ai.soLanDoc, 0, reason: 'luật đọc đủ ba ô → không có ô nào cho AI lấp');
    router.pop();
    await cho(tester);
    expect(find.text('Trang trước'), findsOneWidget, reason: 'màn "Đang đọc ảnh…" đã bị thay, không nằm trong ngăn xếp');
  });

  testWidgets('hoá đơn có món → danh sách món lưu cạnh ảnh', (tester) async {
    await mo(tester, docChu: _DocChuGia(_hoaDon));
    await cho(tester);
    final ten = form()!.queryParameters['anh']!;
    expect((await kho.docMon(ten)).map((m) => m.soTien), [120000, 45000]);
  });

  testWidgets('còn ô thiếu + Premium → AI một lần, chữ "Đang đọc bằng AI…" trong lúc chờ, form có ai=1',
      (tester) async {
    final c = Completer<KetQuaAiAnh?>();
    final ai = _AiGia(null, cho: c);
    await mo(tester, docChu: _DocChuGia(_bienLaiThieuNoiDung), ai: ai);
    await cho(tester);
    expect(find.text('Đang đọc bằng AI…'), findsOneWidget);
    c.complete(const KetQuaAiAnh(noiDung: 'Giao dịch thành công'));
    await cho(tester);
    expect(ai.soLanDoc, 1);
    expect(form()!.queryParameters['ai'], '1');
  });

  testWidgets('Basic → KHÔNG gọi AI, không chữ "AI" nào', (tester) async {
    final ai = _AiGia(const KetQuaAiAnh(noiDung: 'Giao dịch thành công'));
    await mo(tester, docChu: _DocChuGia(_bienLaiThieuNoiDung), ai: ai, laPremium: false);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.textContaining('AI'), findsNothing);
    await cho(tester);
    expect(ai.soLanDoc, 0);
    expect(form()!.queryParameters.containsKey('ai'), isFalse);
  });

  testWidgets('Huỷ ở pha luật → về trang trước, ảnh trong kho bị xoá, không mở form', (tester) async {
    final c = Completer<void>();
    await mo(tester, docChu: _DocChuGia(_hoaDon, cho: c));
    await cho(tester);
    await tester.tap(find.byKey(const Key('quet-huy')));
    await tester.pump();
    expect(find.text('Đang huỷ…'), findsOneWidget);
    c.complete();
    await cho(tester);
    expect(find.text('Trang trước'), findsOneWidget);
    expect(form(), isNull);
    final d = Directory('${goc.path}/$kThuMucAnhQuet');
    expect(d.existsSync() ? d.listSync() : const [], isEmpty);
  });

  testWidgets('Huỷ ở pha AI → dừng lượt sinh, mở form với kết quả luật (không ai=1)', (tester) async {
    final c = Completer<KetQuaAiAnh?>();
    final ai = _AiGia(null, cho: c);
    await mo(tester, docChu: _DocChuGia(_bienLaiThieuNoiDung), ai: ai);
    await cho(tester);
    await tester.tap(find.byKey(const Key('quet-huy')));
    await cho(tester);
    expect(ai.soLanHuy, 1);
    final u = form()!;
    expect(u.queryParameters['amount'], '150000');
    expect(u.queryParameters.containsKey('ai'), isFalse);
  });

  testWidgets('ảnh không chữ → form vẫn mở + toast "Chưa đọc được ảnh"; không tiền → toast "Chưa đọc được số tiền"',
      (tester) async {
    final bat = batThongBao();
    await mo(tester, docChu: _DocChuGia(const []));
    await cho(tester);
    expect(form(), isNotNull);
    expect(bat.cau, contains(kCauChuaDocAnh));
  });

  testWidgets('chữ không có số tiền → toast "Chưa đọc được số tiền", form không có amount', (tester) async {
    final bat = batThongBao();
    await mo(tester, docChu: _DocChuGia(const ['Cam on quy khach', 'Hen gap lai']), laPremium: false);
    await cho(tester);
    expect(form()!.queryParameters.containsKey('amount'), isFalse);
    expect(bat.cau, contains(kCauChuaDocTien));
  });

  testWidgets('moQuet: sheet hai nguồn; huỷ máy ảnh → không đi đâu; chọn ảnh → push /quet', (tester) async {
    String? pushed;
    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(
          path: '/start',
          builder: (ctx, __) => Scaffold(
            body: Column(children: [
              TextButton(onPressed: () => moQuet(ctx, chonAnh: (_) async => null), child: const Text('Q-huy')),
              TextButton(onPressed: () => moQuet(ctx, chonAnh: (_) async => '/tmp/a.jpg'), child: const Text('Q-co')),
            ]),
          ),
        ),
        GoRoute(
          path: '/quet',
          builder: (_, s) {
            pushed = s.extra as String?;
            return const Scaffold(body: Text('MAN QUET'));
          },
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Q-huy'));
    await tester.pumpAndSettle();
    expect(find.text('Chụp ảnh'), findsOneWidget);
    expect(find.text('Chọn ảnh có sẵn'), findsOneWidget);
    await tester.tap(find.text('Chụp ảnh'));
    await tester.pumpAndSettle();
    expect(find.text('MAN QUET'), findsNothing);
    await tester.tap(find.text('Q-co'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn ảnh có sẵn'));
    await tester.pumpAndSettle();
    expect(find.text('MAN QUET'), findsOneWidget);
    expect(pushed, '/tmp/a.jpg');
  });
}
