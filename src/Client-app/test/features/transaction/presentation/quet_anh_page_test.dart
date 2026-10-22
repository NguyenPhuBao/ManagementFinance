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
import 'package:flowmoney/features/transaction/data/datasources/kho_anh_quet.dart';
import 'dart:typed_data';

import 'package:flowmoney/features/transaction/data/doc_anh_bang_gemma.dart';
import 'package:flowmoney/features/transaction/data/doc_danh_muc_bang_ai.dart';
import 'package:flowmoney/features/transaction/domain/doc_anh_gemma.dart';
import 'package:flowmoney/features/transaction/domain/doc_mon_hang.dart';
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
  _GemmaGia(this.kq, {this.cho, this.ngatNgay = true});
  final KetQuaGemmaAnh? kq;
  final Completer<KetQuaGemmaAnh?>? cho;

  /// `false`: như máy thật — lời gọi đọc ảnh native không ngắt được tức thì (Realme ~5 s), `huy()` không làm `doc` về.
  final bool ngatNgay;
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
    if (ngatNgay && cho != null && !cho!.isCompleted) cho!.complete(null);
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

/// Kho thật, nhưng [luuMon] đợi [cho] — giữ màn ở khoảng giữa phép xét Huỷ pha luật và lúc sang pha AI.
class _KhoChoLuuMon extends KhoAnhQuet {
  _KhoChoLuuMon({required super.thuMuc, required this.cho});
  final Completer<void> cho;
  @override
  Future<void> luuMon(String tep, List<MonHang> mon) async {
    await cho.future;
    return super.luuMon(tep, mon);
  }
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
        GoRoute(path: '/khac', builder: (_, __) => const Scaffold(body: Text('MAN KHAC'))),
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

  // G101 (Realme 2026-10-21): OCR đọc nhầm dòng tổng; form từng điền sẵn số sai — Basic không bao giờ đi qua phép chốt.
  const r08 = ['MAXIDI', 'BANH 24.900 VO8', 'TONG CONG 75.706', 'VAT 8% 75.700 5.607'];
  const r13 = ['MAXIDI', 'BOT CHIEN 19.800 VO5', 'TRUNG GA 15.990 VO5', 'TONG CONG 2.127'];

  testWidgets('⭐ G101 Basic — tờ in một số khác lệch ≤ 1% so với tổng → hai chip, không amount, không chữ AI',
      (tester) async {
    final g = _GemmaGia(const KetQuaGemmaAnh(tong: 75700));
    await mo(tester, docChu: _DocChuGia(r08), gemma: g, laPremium: false);
    await cho(tester);
    final u = form()!;
    expect(u.queryParameters.containsKey('amount'), isFalse);
    expect(u.queryParameters['chon'], '75706,75700');
    expect(u.queryParameters.containsKey('ai'), isFalse);
    expect(g.soLanDoc, 0);
  });

  testWidgets('⭐ G101 Basic — tổng nhỏ hơn một dòng món → không amount, không chip, toast "Chưa đọc được số tiền"',
      (tester) async {
    final bat = batThongBao();
    await mo(tester, docChu: _DocChuGia(r13), laPremium: false);
    await cho(tester);
    final u = form()!;
    expect(u.queryParameters.containsKey('amount'), isFalse);
    expect(u.queryParameters.containsKey('chon'), isFalse);
    expect(bat.cau, contains(kCauChuaDocTien));
  });

  // Cô lập ĐƯỜNG SỐ TIỀN: không có bộ chọn danh mục. Trên máy thật Gemma gần như luôn chọn được danh mục, và danh mục
  // AI chọn bật `ai=1` như cũ (ca dưới) — phép chốt chỉ không TỰ bật cờ cho hai chip của OCR.
  testWidgets('⭐ G101 Premium — Gemma bị bỏ, số luật có số gần → hai chip của OCR; phép chốt KHÔNG bật ai=1',
      (tester) async {
    await mo(tester, docChu: _DocChuGia(r08), gemma: _GemmaGia(const KetQuaGemmaAnh(tong: 55000)));
    await cho(tester);
    final u = form()!;
    expect(u.queryParameters['chon'], '75706,75700');
    expect(u.queryParameters.containsKey('ai'), isFalse, reason: 'không số nào trên form là của Gemma');
  });

  testWidgets('G101 Premium — như trên nhưng Gemma chọn được danh mục → hai chip của OCR, ai=1 (vì danh mục)',
      (tester) async {
    await mo(tester,
        docChu: _DocChuGia(r08),
        gemma: _GemmaGia(const KetQuaGemmaAnh(tong: 55000)),
        danhMuc: _DanhMucGia('Ăn uống'));
    await cho(tester);
    final u = form()!;
    expect(u.queryParameters['chon'], '75706,75700');
    expect(u.queryParameters['dm'], 'Ăn uống');
    expect(u.queryParameters['ai'], '1');
  });

  testWidgets('G101 Premium — Gemma hơn số luật đúng một chữ số → hai chip (AI trước), ai=1', (tester) async {
    await mo(tester, docChu: _DocChuGia(r13), gemma: _GemmaGia(const KetQuaGemmaAnh(tong: 72127)));
    await cho(tester);
    final u = form()!;
    expect(u.queryParameters.containsKey('amount'), isFalse);
    expect(u.queryParameters['chon'], '72127,2127');
    expect(u.queryParameters['ai'], '1');
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

  // Realme 2026-10-22 (đọc mã khi đo khe Huỷ): phép xét `_huyLuat` chạy TRƯỚC `await kho.luuMon` — Huỷ bấm trong lúc ấy
  // bật cờ, nút thành "Đang huỷ…" và bị khoá, mà không ai xét lại: Premium vào pha AI chạy trọn (~30 s) không Huỷ được,
  // Basic mở form như chưa từng Huỷ.
  for (final premium in [true, false]) {
    testWidgets('⭐ Huỷ trong lúc lưu món (giữa pha luật và pha AI) → như Huỷ pha luật — ${premium ? 'Premium' : 'Basic'}',
        (tester) async {
      final c = Completer<void>();
      kho = _KhoChoLuuMon(thuMuc: () async => goc, cho: c);
      final g = _GemmaGia(const KetQuaGemmaAnh(tong: 165000));
      await mo(tester, docChu: _DocChuGia(_hoaDon), gemma: g, laPremium: premium);
      await cho(tester);
      expect(find.text('Đang đọc bằng AI…'), findsNothing, reason: 'tiền đề: chưa sang pha AI');
      await tester.tap(find.byKey(const Key('quet-huy')));
      await tester.pump();
      expect(find.text('Đang huỷ…'), findsOneWidget);
      c.complete();
      await cho(tester);
      expect(g.soLanDoc, 0, reason: 'đã Huỷ — không gọi Gemma');
      expect(form(), isNull, reason: 'đã Huỷ — không mở form');
      expect(find.text('Trang trước'), findsOneWidget);
      final d = Directory('${goc.path}/$kThuMucAnhQuet');
      expect(d.existsSync() ? d.listSync() : const [], isEmpty, reason: 'ảnh và tệp món bị xoá');
    });
  }

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

  testWidgets('⭐ Huỷ ở pha AI khi lượt đọc ảnh native KHÔNG ngắt được → vẫn mở form NGAY; lượt cũ về sau bị bỏ',
      (tester) async {
    // Nghiệm thu Realme 2026-10-21: màn "Đang đọc bằng AI…" đứng ~5 s sau khi bấm Huỷ (huỷ 14:23:53, native trả
    // 14:23:58). Người dùng duyệt 2026-10-22: sang form ngay; lời gọi mô hình kế tiếp chờ lượt cũ (`LuotKhongNgatDuoc`).
    final c = Completer<KetQuaGemmaAnh?>();
    final g = _GemmaGia(null, cho: c, ngatNgay: false);
    final dm = _DanhMucGia('Ăn uống');
    await mo(tester, docChu: _DocChuGia(_hoaDon), gemma: g, danhMuc: dm);
    await cho(tester);
    expect(find.text('Đang đọc bằng AI…'), findsOneWidget, reason: 'tiền đề: đang ở pha AI');
    await tester.tap(find.byKey(const Key('quet-huy')));
    await cho(tester);
    expect(g.soLanHuy, 1);
    final u = form();
    expect(u, isNotNull, reason: 'không chờ lượt native về mới mở form');
    expect(u!.queryParameters['amount'], '165000');
    expect(u.queryParameters.containsKey('ai'), isFalse);
    expect(dm.daHoi, isEmpty);
    c.complete(const KetQuaGemmaAnh(tong: 999000));
    await cho(tester);
    expect(form()!.queryParameters['amount'], '165000', reason: 'kết quả về muộn không đụng form');
    expect(dm.daHoi, isEmpty, reason: 'lượt về muộn không mở lượt chọn danh mục');
  });

  // Nghiệm thu OnePlus 2026-10-08: một màn khác (form trống của nút +, deeplink thông báo) mở ĐÈ lên `/quet` trong lúc
  // Gemma đọc. `pushReplacement` thay màn TRÊN CÙNG — tức màn của người dùng — còn `/quet` nằm lại bên dưới, `_chay` đã
  // xong nên Huỷ / Back không làm gì: người dùng kẹt ở "Đang đọc bằng AI…", phải tắt app.
  testWidgets('⭐ màn khác đè lên lúc đang đọc → form mở TRÊN màn ấy (không thay nó); quay về tới /quet thì nó tự đóng',
      (tester) async {
    final c = Completer<KetQuaGemmaAnh?>();
    final router = await mo(tester, docChu: _DocChuGia(_hoaDon), gemma: _GemmaGia(null, cho: c));
    await cho(tester);
    expect(find.text('Đang đọc bằng AI…'), findsOneWidget);
    unawaited(router.push('/khac'));
    await cho(tester);
    c.complete(const KetQuaGemmaAnh(tong: 165000));
    await cho(tester);
    expect(form()?.queryParameters['amount'], '165000', reason: 'kết quả quét vẫn tới tay người dùng');
    router.pop();
    await cho(tester);
    expect(find.text('MAN KHAC'), findsOneWidget, reason: 'màn người dùng mở không bị form thay mất');
    router.pop();
    await cho(tester);
    // Hai lần đóng màn liền nhau (màn khác, rồi /quet tự đóng) — chờ hết hai hiệu ứng chuyển cảnh.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Đang đọc bằng AI…'), findsNothing, reason: '/quet đã xong thì không được nằm lại trong ngăn xếp');
    expect(find.text('Trang trước'), findsOneWidget);
  });

  testWidgets('⭐ Huỷ ở pha luật rồi màn khác đè lên trước khi OCR xong → KHÔNG đóng nhầm màn ấy; quay về thì /quet tự đóng',
      (tester) async {
    final c = Completer<void>();
    final router = await mo(tester, docChu: _DocChuGia(_hoaDon, cho: c));
    await cho(tester);
    await tester.tap(find.byKey(const Key('quet-huy')));
    await tester.pump();
    unawaited(router.push('/khac'));
    await cho(tester);
    c.complete();
    await cho(tester);
    expect(find.text('MAN KHAC'), findsOneWidget, reason: 'context.pop() của /quet sẽ đóng màn trên cùng — màn của người dùng');
    expect(form(), isNull);
    router.pop();
    await cho(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Đang'), findsNothing);
    expect(find.text('Trang trước'), findsOneWidget);
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

  // Stitch `8027b781…` *"Trang chủ - Chọn nguồn ảnh để Quét"*: tiêu đề, dòng khoá, hai lựa chọn có dòng phụ, nút Huỷ — cộng
  // dòng nhắc chụp (G105, người dùng chọn 2026-10-22: ảnh dính vật có chữ ở mép thì ghi chú ra chữ của vật ấy).
  group('sheet chọn nguồn ảnh theo Stitch', () {
    Future<void> moSheet(WidgetTester tester, {Size kho = const Size(411, 914), double coChu = 1.0}) async {
      tester.view.physicalSize = kho * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(coChu)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(builder: (ctx) => TextButton(onPressed: () => moQuet(ctx), child: const Text('Q'))),
        ),
      ));
      await tester.tap(find.text('Q'));
      await tester.pumpAndSettle();
    }

    testWidgets('⭐ đủ chữ của màn Stitch + dòng nhắc chụp', (tester) async {
      await moSheet(tester);
      for (final chu in [
        'Quét hoá đơn / biên lai',
        'Ảnh được đọc ngay trên máy, không gửi đi đâu',
        kNhacChupSat,
        'Chụp ảnh',
        'Hoá đơn giấy, màn hình máy khác',
        'Chọn ảnh có sẵn',
        'Ảnh chụp màn hình biên lai chuyển khoản',
        'Huỷ',
      ]) {
        expect(find.text(chu), findsOneWidget, reason: chu);
      }
      expect(kNhacChupSat, 'Chụp sát tờ hoá đơn, đừng để vật có chữ lọt vào khung');
      expect(tester.takeException(), isNull);
    });

    for (final (kho, coChu) in [(const Size(320, 640), 1.3), (const Size(360, 800), 1.0), (const Size(360, 800), 1.3)]) {
      testWidgets('không tràn, dòng nhắc và dòng phụ xuống dòng chứ không cắt — ${kho.width.toInt()} dp, chữ ×$coChu',
          (tester) async {
        await moSheet(tester, kho: kho, coChu: coChu);
        expect(tester.takeException(), isNull, reason: 'tràn bố cục');
        for (final chu in [kNhacChupSat, 'Ảnh chụp màn hình biên lai chuyển khoản']) {
          final t = tester.widget<Text>(find.text(chu));
          expect(t.overflow, isNot(TextOverflow.ellipsis), reason: '$chu — cắt chữ là mất lời nhắc');
          expect(t.maxLines, isNull, reason: chu);
        }
        // Nút Huỷ nằm trọn trong màn (sheet cao hơn khung thì cuộn được — Huỷ vẫn phải chạm được).
        await tester.ensureVisible(find.text('Huỷ'));
        await tester.pumpAndSettle();
        final r = tester.getRect(find.text('Huỷ'));
        expect(r.bottom, lessThanOrEqualTo(kho.height));
      });
    }

    testWidgets('Huỷ đóng sheet, không mở máy ảnh / thư viện', (tester) async {
      await moSheet(tester);
      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();
      expect(find.text('Quét hoá đơn / biên lai'), findsNothing);
      expect(find.text('Q'), findsOneWidget);
    });
  });
}
