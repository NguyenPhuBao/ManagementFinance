/// C4 §3.4 — kiểm chéo số tiền trong `ThemGiaoDichCubit.dienTuCau`.
library;

import 'dart:async';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/data/services/category_suggestion_engine.dart';
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

void main() {
  final tienMat = makeWallet(id: 'cash', name: 'Tiền mặt');
  final anUong = makeCategory(id: 'food', name: 'Ăn uống', isDefault: true);

  Future<ThemGiaoDichCubit> moi(_AiKiem ai, {List<Category> danhMuc = const []}) async {
    final c = ThemGiaoDichCubit(
      nguon: NguonThemGiaoDichGia(vi: [tienMat], danhMuc: danhMuc, docAiGia: ai),
      taiKhoan: () => 1,
      boGoiY: const CategorySuggestionEngine(),
    );
    addTearDown(c.close);
    await c.moTrang();
    return c;
  }

  test('⭐ câu không còn ô thiếu: điền ngay bằng luật, Gemma kiểm ở nền; khớp → giữ, dòng kiểm tắt', () async {
    final ai = _AiKiem();
    final c = await moi(ai);
    await c.dienTuCau('tiền điện một triệu hai');
    expect(c.state.soTienDangCo, 1200000.0, reason: 'luật điền NGAY, không chờ AI');
    expect(c.state.dangKiemSoTien, isTrue);
    expect(ai.luot, hasLength(1));
    ai.luot.single.complete(const KetQuaAi(soTien: 1200000));
    await pumpEventQueue();
    expect(c.state.dangKiemSoTien, isFalse);
    expect(c.state.luaChonTienCau, isEmpty);
    expect(c.state.soTienDangCo, 1200000.0);
  });

  test('lệch → ô số tiền trống + hai chip (AI trước); chạm chip thì điền và chip biến mất', () async {
    final ai = _AiKiem();
    final c = await moi(ai);
    await c.dienTuCau('tiền điện một triệu hai');
    ai.luot.single.complete(const KetQuaAi(soTien: 1000000));
    await pumpEventQueue();
    expect(c.state.soTienDangCo, isNull);
    expect(c.state.luaChonTienCau, [1000000.0, 1200000.0]);
    c.chonSoTien(1200000);
    expect(c.state.soTienDangCo, 1200000.0);
    expect(c.state.luaChonTienCau, isEmpty);
  });

  test('số AI không phải một cách đọc của câu → bỏ, giữ số luật', () async {
    final ai = _AiKiem();
    final c = await moi(ai);
    await c.dienTuCau('tiền điện một triệu hai');
    ai.luot.single.complete(const KetQuaAi(soTien: 999999));
    await pumpEventQueue();
    expect(c.state.luaChonTienCau, isEmpty);
    expect(c.state.soTienDangCo, 1200000.0);
  });

  test('⚠️ người dùng đã sửa số trước khi AI về → AI không đụng', () async {
    final ai = _AiKiem();
    final c = await moi(ai);
    await c.dienTuCau('tiền điện một triệu hai');
    c.goPhim('5');
    final dangCo = c.state.chuoiSoTien;
    ai.luot.single.complete(const KetQuaAi(soTien: 1000000));
    await pumpEventQueue();
    expect(c.state.luaChonTienCau, isEmpty);
    expect(c.state.chuoiSoTien, dangCo);
  });

  test('Huỷ kiểm: dòng tắt, mô hình thôi giải mã, kết quả về sau bị bỏ', () async {
    final ai = _AiKiem();
    final c = await moi(ai);
    await c.dienTuCau('tiền điện một triệu hai');
    await c.huyKiemSoTien();
    expect(c.state.dangKiemSoTien, isFalse);
    expect(ai.soLanHuy, 1);
    ai.luot.single.complete(const KetQuaAi(soTien: 1000000));
    await pumpEventQueue();
    expect(c.state.luaChonTienCau, isEmpty);
  });

  test('máy chưa sẵn sàng AI → không kiểm', () async {
    final ai = _AiKiem(san: false);
    final c = await moi(ai);
    await c.dienTuCau('tiền điện một triệu hai');
    expect(ai.luot, isEmpty);
    expect(c.state.dangKiemSoTien, isFalse);
  });

  test('số có đơn vị ("45k") → không kiểm', () async {
    final ai = _AiKiem();
    final c = await moi(ai);
    await c.dienTuCau('ăn phở 45k');
    expect(ai.luot, isEmpty);
  });

  test('câu còn ô thiếu → lượt AI lấp ô kiểm luôn số tiền, KHÔNG gọi lần hai', () async {
    final ai = _AiKiem();
    final c = await moi(ai, danhMuc: [anUong]); // "tiền điện" không khớp danh mục → ô danh mục thiếu → hỏi AI trước
    final f = c.dienTuCau('tiền điện một triệu hai');
    await pumpEventQueue();
    expect(ai.luot, hasLength(1));
    ai.luot.single.complete(const KetQuaAi(soTien: 1000000));
    await f;
    await pumpEventQueue();
    expect(ai.luot, hasLength(1));
    expect(c.state.luaChonTienCau, [1000000.0, 1200000.0]);
  });

  test('P15: lượt kiểm nền trả null → giữ số luật, dòng đang kiểm tắt', () async {
    final ai = _AiKiem();
    final c = await moi(ai);
    await c.dienTuCau('tiền điện một triệu hai');
    expect(c.state.dangKiemSoTien, isTrue);
    ai.luot.single.complete(null);
    await pumpEventQueue();
    expect(c.state.dangKiemSoTien, isFalse);
    expect(c.state.luaChonTienCau, isEmpty);
    expect(c.state.soTienDangCo, 1200000.0);
  });

  test('P7: lệch → dòng "Đã điền" không còn nói số tiền luật đã điền', () async {
    final ai = _AiKiem();
    final c = await moi(ai);
    await c.dienTuCau('tiền điện một triệu hai');
    expect(c.state.ketQuaDien?.tomTat, contains('1.200.000'), reason: 'tiền đề: lúc đầu có nói số');
    ai.luot.single.complete(const KetQuaAi(soTien: 1000000));
    await pumpEventQueue();
    expect(c.state.luaChonTienCau, isNotEmpty);
    expect(c.state.ketQuaDien?.tomTat ?? '', isNot(contains('1.200.000')));
  });
}
