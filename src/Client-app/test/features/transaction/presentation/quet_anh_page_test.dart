/// A5 mục 3, 5.7, 13 — màn `/quet` ("Đang đọc ảnh…"): luật trước; hoá đơn + Premium → Gemma NHÌN ẢNH đọc món + tổng,
/// số chốt bằng `chotTongQuet` (khớp → điền, lệch → hai chip); Huỷ hai pha; thay chính nó bằng form (Back từ form về
/// trang trước, không về màn chờ).
///
/// ⚠️ Không `pumpAndSettle` khi vòng xoay còn quay — dùng [_cho].
library;

import 'dart:async';
import 'dart:io';

import 'package:flowmoney/core/ocr/doc_chu_anh.dart';
import 'package:flowmoney/core/ocr/dong_ocr.dart';
import 'package:flowmoney/core/ocr/kho_anh_quet.dart';
import 'dart:typed_data';

import 'package:flowmoney/features/transaction/data/doc_anh_bang_gemma.dart';
import 'package:flowmoney/features/transaction/data/doc_danh_muc_bang_ai.dart';
import 'package:flowmoney/features/transaction/domain/doc_anh_gemma.dart';
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

class _GemmaGia implements DocAnhBangGemma {
  _GemmaGia(this.kq, {this.cho});
  final KetQuaGemmaAnh? kq;
  final Completer<KetQuaGemmaAnh?>? cho;
  int soLanDoc = 0;
  int soLanHuy = 0;

  @override
  Future<KetQuaGemmaAnh?> doc(Uint8List anh) async {
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

class _DanhMucGia implements DocDanhMucBangAi {
  _DanhMucGia(this.tra);
  final String? tra;
  final List<({String cuaHang, List<String> mon, List<String> ten})> daHoi = [];

  @override
  Future<String?> chon({required String cuaHang, required List<String> mon, required List<String> tenDanhMuc}) async {
    daHoi.add((cuaHang: cuaHang, mon: mon, ten: tenDanhMuc));
    return tra;
  }

  @override
  Future<void> huy() async {}

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

const _bienLai = ['Giao dịch thành công', 'Số tiền 150.000 VND', 'Thời gian 02/10/2026 18:45'];

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
    DocAnhBangGemma? gemma,
    DocDanhMucBangAi? danhMuc,
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
            docGemma: gemma,
            docDanhMuc: danhMuc,
            tenDanhMucChi: () async => const ['Ăn uống', 'Mua sắm'],
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

  testWidgets('⭐ Basic: luật → form có khoá quet:, tiền; KHÔNG gọi Gemma, không chữ "AI"; Back về trang trước',
      (tester) async {
    final g = _GemmaGia(const KetQuaGemmaAnh(tong: 165000));
    final router = await mo(tester, docChu: _DocChuGia(_hoaDon), gemma: g, laPremium: false);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.textContaining('AI'), findsNothing);
    await cho(tester);
    final u = form();
    expect(u, isNotNull);
    expect(u!.queryParameters['khoa'], startsWith('quet:'));
    expect(u.queryParameters['amount'], '165000');
    expect(u.queryParameters.containsKey('ai'), isFalse);
    expect(g.soLanDoc, 0);
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

  testWidgets('⭐ hoá đơn + Premium → Gemma MỘT lần dù luật đã đủ, "Đang đọc bằng AI…" lúc chờ; khớp luật → điền, ai=1',
      (tester) async {
    final c = Completer<KetQuaGemmaAnh?>();
    final g = _GemmaGia(null, cho: c);
    await mo(tester, docChu: _DocChuGia(_hoaDon), gemma: g);
    await cho(tester);
    expect(find.text('Đang đọc bằng AI…'), findsOneWidget);
    c.complete(const KetQuaGemmaAnh(tong: 165000));
    await cho(tester);
    expect(g.soLanDoc, 1);
    final u = form()!;
    expect(u.queryParameters['amount'], '165000');
    expect(u.queryParameters['ai'], '1');
    expect(u.queryParameters.containsKey('chon'), isFalse);
  });

  testWidgets('⭐ Gemma ra một số CÓ trên ảnh nhưng lệch luật > 1% → không amount, hai chip (AI trước), ai=1',
      (tester) async {
    await mo(tester, docChu: _DocChuGia(_hoaDon), gemma: _GemmaGia(const KetQuaGemmaAnh(tong: 120000)));
    await cho(tester);
    final u = form()!;
    expect(u.queryParameters.containsKey('amount'), isFalse);
    expect(u.queryParameters['chon'], '120000,165000');
    expect(u.queryParameters['ai'], '1');
  });

  testWidgets('Gemma ra số KHÔNG in trên ảnh → bỏ, số luật, không ai=1, không chip', (tester) async {
    await mo(tester, docChu: _DocChuGia(_hoaDon), gemma: _GemmaGia(const KetQuaGemmaAnh(tong: 83500)));
    await cho(tester);
    final u = form()!;
    expect(u.queryParameters['amount'], '165000');
    expect(u.queryParameters.containsKey('ai'), isFalse);
    expect(u.queryParameters.containsKey('chon'), isFalse);
  });

  testWidgets('⭐ hoá đơn + Premium → Gemma lần hai chọn danh mục từ cửa hàng + MÓN Gemma đọc; query dm', (tester) async {
    final dm = _DanhMucGia('Ăn uống');
    await mo(tester,
        docChu: _DocChuGia(_hoaDon),
        gemma: _GemmaGia(const KetQuaGemmaAnh(tong: 165000, mon: [(ten: 'OMO 3KG', soTien: 120000)])),
        danhMuc: dm);
    await cho(tester);
    expect(dm.daHoi.single.cuaHang, 'CO.OPMART NGUYEN TRAI');
    expect(dm.daHoi.single.mon, ['OMO 3KG']);
    expect(dm.daHoi.single.ten, ['Ăn uống', 'Mua sắm']);
    expect(form()!.queryParameters['dm'], 'Ăn uống');
  });

  testWidgets('Gemma ảnh không đọc ra món → dùng món LUẬT đọc cho câu hỏi danh mục', (tester) async {
    final dm = _DanhMucGia(null);
    await mo(tester, docChu: _DocChuGia(_hoaDon), gemma: _GemmaGia(null), danhMuc: dm);
    await cho(tester);
    expect(dm.daHoi.single.mon, ['OMO 3KG', 'GIAY VS']);
    expect(form()!.queryParameters.containsKey('dm'), isFalse);
  });

  testWidgets('Basic → KHÔNG hỏi danh mục', (tester) async {
    final dm = _DanhMucGia('Ăn uống');
    await mo(tester, docChu: _DocChuGia(_hoaDon), gemma: _GemmaGia(null), danhMuc: dm, laPremium: false);
    await cho(tester);
    expect(dm.daHoi, isEmpty);
  });

  testWidgets('biên lai → KHÔNG gọi Gemma (câu hỏi đo trên hoá đơn giấy), dù Premium', (tester) async {
    final g = _GemmaGia(const KetQuaGemmaAnh(tong: 150000));
    await mo(tester, docChu: _DocChuGia(_bienLai), gemma: g);
    await cho(tester);
    expect(g.soLanDoc, 0);
    expect(form()!.queryParameters['amount'], '150000');
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
    final c = Completer<KetQuaGemmaAnh?>();
    final g = _GemmaGia(null, cho: c);
    final dmHuy = _DanhMucGia('Ăn uống');
    await mo(tester, docChu: _DocChuGia(_hoaDon), gemma: g, danhMuc: dmHuy);
    await cho(tester);
    await tester.tap(find.byKey(const Key('quet-huy')));
    await cho(tester);
    expect(g.soLanHuy, 1);
    expect(dmHuy.daHoi, isEmpty, reason: 'đã Huỷ — không gọi mô hình lần hai');
    final u = form()!;
    expect(u.queryParameters['amount'], '165000');
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

  testWidgets('⭐ moQuet mở sheet trên navigator GỐC — không nằm dưới thanh điều hướng + nút + của shell', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (ctx) => TextButton(onPressed: () => moQuet(ctx), child: const Text('Q')),
          ),
        ),
      ),
    ));
    final goc = tester.state<NavigatorState>(find.byType(Navigator).first);
    await tester.tap(find.text('Q'));
    await tester.pumpAndSettle();
    expect(Navigator.of(tester.element(find.text('Chụp ảnh'))), same(goc),
        reason: 'nghiệm thu OnePlus 2026-10-08: sheet trong navigator nhánh bị thanh dưới đè, nút Huỷ khuất');
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
