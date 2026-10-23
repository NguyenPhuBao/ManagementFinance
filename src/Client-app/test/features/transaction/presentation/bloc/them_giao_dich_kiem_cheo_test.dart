/// C4 §3.4 — kiểm chéo số tiền trong `ThemGiaoDichCubit.dienTuCau`.
///
/// Người dùng chốt 2026-10-22: Gemma chỉ kiểm khi câu còn số tiền NGOÀI cụm luật đã đọc (`KetQuaDocCau.soTienKhac` —
/// số còn sót trong ghi chú). Số ấy nằm trong ghi chú nên câu luôn có ô thiếu `ghiChu` → C2 hỏi Gemma TRƯỚC khi điền,
/// và chính lượt ấy kiểm luôn số tiền. Đường *"điền ngay, kiểm ở nền"* (dòng *"Đang kiểm số tiền bằng AI…"*) đã gỡ:
/// không còn câu nào đi vào nó.
library;

import 'dart:async';

import 'package:flowmoney/features/category/data/models/category_entity.dart';
import 'package:flowmoney/features/category/domain/category_suggestion_engine.dart';
import 'package:flowmoney/features/transaction/data/doc_cau_bang_ai.dart';
import 'package:flowmoney/features/transaction/domain/doc_cau_giao_dich.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/them_giao_dich_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/them_giao_dich_nguon_gia.dart';
import '../../../category/presentation/category_test_fakes.dart';

/// AI giả: mỗi lời `doc` một Completer, test tự trả.
class _AiKiem implements DocCauBangAi {
  _AiKiem({this.san = true});
  bool san;
  final luot = <Completer<KetQuaAi?>>[];
  int soLanHuy = 0;
  @override
  Future<bool> Function() get sanSang => () async => san;
  @override
  Future<bool> chuanBi() async => san;
  @override
  Future<KetQuaAi?> doc(String cau,
      {required DateTime now, required List<String> tenVi, required List<String> tenDanhMuc}) {
    final c = Completer<KetQuaAi?>();
    luot.add(c);
    return c.future;
  }

  @override
  Future<void> huy() async => soLanHuy++;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Luật đọc N2 *"năm chục"* = 50.000; *"20 quả"* còn trong ghi chú là cách đọc 20.000 — Gemma chọn nó là lệch thật.
const kCauHaiSo = 'mua 20 quả trứng năm chục';

void main() {
  final tienMat = makeWallet(id: 'cash', name: 'Tiền mặt');
  final anUong = makeCategory(id: 'food', name: 'Ăn uống', isDefault: true);

  Future<ThemGiaoDichCubit> moi(_AiKiem ai, {List<CategoryEntity> danhMuc = const []}) async {
    final c = ThemGiaoDichCubit(
      nguon: NguonThemGiaoDichGia(vi: [tienMat], danhMuc: danhMuc, docAiGia: ai),
      taiKhoan: () => 1,
      boGoiY: const CategorySuggestionEngine(),
    );
    addTearDown(c.close);
    await c.moTrang();
    return c;
  }

  /// Điền [cau] (lượt hỏi Gemma TRƯỚC khi điền), trả [traLoi] cho lượt ấy, chờ xong.
  Future<void> dienVaTra(ThemGiaoDichCubit c, _AiKiem ai, String cau, KetQuaAi? traLoi) async {
    final f = c.dienTuCau(cau);
    await pumpEventQueue();
    expect(ai.luot, isNotEmpty, reason: 'tiền đề: câu còn ô thiếu → C2 hỏi Gemma trước khi điền');
    ai.luot.last.complete(traLoi);
    await f;
    await pumpEventQueue();
  }

  test('⭐ "một triệu hai" — câu một cụm: điền 1.200.000 ngay, KHÔNG gọi Gemma', () async {
    // Đo Realme 2026-10-21: Gemma đọc câu này thành 1.000.000 2/2 lần → hai chip oan mỗi lần, sau ~16 s chờ.
    final ai = _AiKiem();
    final c = await moi(ai);
    await c.dienTuCau('tiền điện một triệu hai');
    expect(c.state.soTienDangCo, 1200000.0);
    expect(ai.luot, isEmpty, reason: 'câu không còn số tiền nào ngoài cụm luật — lượt Gemma không đổi được gì');
    expect(c.state.dangDocAi, isFalse);
  });

  test('⭐ "đổ xăng năm chục" — câu một cụm: điền 50.000 ngay, KHÔNG gọi Gemma', () async {
    final ai = _AiKiem();
    final c = await moi(ai);
    await c.dienTuCau('đổ xăng năm chục');
    expect(c.state.soTienDangCo, 50000.0);
    expect(ai.luot, isEmpty, reason: 'cachDocSoTien chỉ có 50.000 — Gemma chỉ có thể khớp');
  });

  test('⭐ "một triệu hai" + ô thiếu: Gemma lấp ô trả 1.000.000 → giữ 1.200.000, không chip', () async {
    final ai = _AiKiem();
    final c = await moi(ai, danhMuc: [anUong]); // "tiền điện" không khớp danh mục → ô danh mục thiếu → hỏi AI trước
    await dienVaTra(c, ai, 'tiền điện một triệu hai', const KetQuaAi(soTien: 1000000));
    expect(ai.luot, hasLength(1));
    expect(c.state.luaChonTienCau, isEmpty, reason: '1.000.000 là bản cụt của chính cụm luật, không phải số tiền khác');
    expect(c.state.soTienDangCo, 1200000.0);
  });

  test('câu hai số tiền: Gemma chọn số kia → ô trống + hai chip (AI trước); chạm chip thì điền, chip biến mất',
      () async {
    final ai = _AiKiem();
    final c = await moi(ai);
    await dienVaTra(c, ai, kCauHaiSo, const KetQuaAi(soTien: 20000));
    expect(ai.luot, hasLength(1), reason: 'một lượt AI duy nhất — lấp ô và kiểm số tiền cùng lúc');
    expect(c.state.soTienDangCo, isNull);
    expect(c.state.luaChonTienCau, [20000.0, 50000.0]);
    c.chonSoTien(50000);
    expect(c.state.soTienDangCo, 50000.0);
    expect(c.state.luaChonTienCau, isEmpty);
  });

  test('câu hai số tiền: Gemma khớp số luật → giữ, không chip', () async {
    final ai = _AiKiem();
    final c = await moi(ai);
    await dienVaTra(c, ai, kCauHaiSo, const KetQuaAi(soTien: 50000));
    expect(c.state.luaChonTienCau, isEmpty);
    expect(c.state.soTienDangCo, 50000.0);
  });

  test('số AI không phải một cách đọc của câu → bỏ, giữ số luật', () async {
    final ai = _AiKiem();
    final c = await moi(ai);
    await dienVaTra(c, ai, kCauHaiSo, const KetQuaAi(soTien: 999999));
    expect(c.state.luaChonTienCau, isEmpty);
    expect(c.state.soTienDangCo, 50000.0);
  });

  test('P15: lượt AI trả null → giữ số luật', () async {
    final ai = _AiKiem();
    final c = await moi(ai);
    await dienVaTra(c, ai, kCauHaiSo, null);
    expect(c.state.luaChonTienCau, isEmpty);
    expect(c.state.soTienDangCo, 50000.0);
  });

  test('máy chưa sẵn sàng AI → không hỏi, điền số luật', () async {
    final ai = _AiKiem(san: false);
    final c = await moi(ai);
    await c.dienTuCau(kCauHaiSo);
    expect(ai.luot, isEmpty);
    expect(c.state.soTienDangCo, 50000.0);
  });

  test('số có đơn vị ("45k") → không kiểm', () async {
    final ai = _AiKiem();
    final c = await moi(ai);
    await c.dienTuCau('ăn phở 45k');
    expect(ai.luot, isEmpty);
  });

  test('P7: lệch → dòng "Đã điền" không còn nói số tiền luật đã điền; chỉ còn số tiền thì bỏ hẳn dòng', () async {
    final ai = _AiKiem();
    final c = await moi(ai);
    await dienVaTra(c, ai, kCauHaiSo, const KetQuaAi(soTien: 20000));
    expect(c.state.luaChonTienCau, isNotEmpty);
    // Tóm tắt trước khi chốt là "Đã điền: 50.000 đ" — bỏ số tiền thì không còn gì để nói, AI không đổi ô nào, không cảnh
    // báo. Chỉ đòi "không chứa 50.000" thì một bản để lại "Đã điền: " cụt hay xoá nhầm cả dòng có chữ vẫn xanh.
    expect(c.state.ketQuaDien, isNull);
  });

  test('P7 (có ngày): lệch → tóm tắt còn ngày, mất số tiền', () async {
    final ai = _AiKiem();
    final c = await moi(ai);
    await dienVaTra(c, ai, 'hôm qua $kCauHaiSo', const KetQuaAi(soTien: 20000));
    expect(c.state.luaChonTienCau, isNotEmpty);
    expect(c.state.ketQuaDien?.tomTat, 'Đã điền: Hôm qua');
  });

  test('P7 (có danh mục): lệch → tóm tắt còn danh mục, mất số tiền', () async {
    final ai = _AiKiem();
    final c = await moi(ai, danhMuc: [anUong]);
    await dienVaTra(c, ai, 'ăn uống 20 quả trứng năm chục', const KetQuaAi(soTien: 20000));
    expect(c.state.luaChonTienCau, isNotEmpty);
    expect(c.state.ketQuaDien?.tomTat, 'Đã điền: Ăn uống');
  });

  group('G104 — luật để hai cách đọc ("một triệu hai tiền sách") → hai chip, Gemma không lấp', () {
    test('⭐ không AI, câu chỉ có số tiền mơ hồ → hai chip, không dòng "chưa đọc được"', () async {
      // Câu không đọc ra ngày / ví / danh mục: `khongDocDuocGi` từng cắt `dienKetQua` trước mọi ô.
      final ai = _AiKiem(san: false);
      final c = await moi(ai);
      await c.dienTuCau('chi hai triệu năm nay');
      expect(c.state.luaChonTienCau, [2000000.0, 2500000.0]);
      expect(c.state.soTienDangCo, isNull);
      expect(c.state.ketQuaDien, isNull, reason: 'không còn gì để tóm tắt — khối chip tự nói');
    });

    test('⭐ Gemma trả bản cụt 1.000.000 → ô trống + hai chip; chạm chip 1.200.000 thì điền', () async {
      final ai = _AiKiem();
      final c = await moi(ai);
      await dienVaTra(c, ai, 'một triệu hai tiền sách', const KetQuaAi(soTien: 1000000));
      expect(c.state.soTienDangCo, isNull, reason: 'trước G104: form điền 1.000.000 không hỏi');
      expect(c.state.luaChonTienCau, [1000000.0, 1200000.0]);
      c.chonSoTien(1200000);
      expect(c.state.soTienDangCo, 1200000.0);
      expect(c.state.luaChonTienCau, isEmpty);
    });

    test('số đã gõ trước đó bị bỏ — câu nói rõ có số tiền, chỉ chưa rõ cách đọc', () async {
      final ai = _AiKiem(san: false);
      final c = await moi(ai);
      c.goPhim('5');
      c.goPhim('000');
      expect(c.state.soTienDangCo, 5000.0, reason: 'tiền đề');
      await c.dienTuCau('một triệu hai tiền sách');
      expect(c.state.soTienDangCo, isNull);
      expect(c.state.luaChonTienCau, [1000000.0, 1200000.0]);
    });

    test('Huỷ lượt AI đang đọc → luật điền, vẫn hai chip', () async {
      final ai = _AiKiem();
      final c = await moi(ai);
      final f = c.dienTuCau('một triệu hai tiền sách');
      await pumpEventQueue();
      expect(ai.luot, hasLength(1), reason: 'tiền đề: ghi chú còn số → hỏi Gemma');
      await c.huyDocAi('một triệu hai tiền sách');
      expect(c.state.luaChonTienCau, [1000000.0, 1200000.0]);
      ai.luot.single.complete(null);
      await f;
    });
  });

  test('⭐ điền câu mới khi chip còn hiện → chip bị dọn ngay', () async {
    final ai = _AiKiem();
    final c = await moi(ai);
    await dienVaTra(c, ai, kCauHaiSo, const KetQuaAi(soTien: 20000));
    expect(c.state.luaChonTienCau, isNotEmpty);
    final f = c.dienTuCau(kCauHaiSo);
    expect(c.state.luaChonTienCau, isEmpty);
    await pumpEventQueue();
    ai.luot.last.complete(null);
    await f;
  });
}
