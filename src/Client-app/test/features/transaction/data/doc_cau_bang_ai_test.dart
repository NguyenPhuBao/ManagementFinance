/// C2 §2.8 — `DocCauBangAi`: chỗ DUY NHẤT ô Nhập nhanh gọi mô hình. Mọi đường hỏng phải trả `null` (người gọi dùng
/// luật) — không đường nào được ném ra màn, và không đường nào được treo màn quá thời hạn.
library;

import 'dart:async';

import 'package:flowmoney/features/ai_edge/data/phien_cong_cu.dart';
import 'package:flowmoney/features/ai_edge/data/slm_runtime.dart';
import 'package:flowmoney/features/ai_edge/domain/canary_cong_cu.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flowmoney/features/transaction/data/doc_cau_bang_ai.dart';
import 'package:flutter_test/flutter_test.dart';

class _RuntimeGia implements SlmRuntime {
  _RuntimeGia(this.taoPhien, {this.napLoi = false});
  final PhienCongCu Function() taoPhien;
  final bool napLoi;
  bool _san = false;
  int soLanNap = 0;
  final List<({String heThong, String cauHoi, List<KhaiBaoCongCu> congCu})> daMo = [];

  @override
  bool get dangSan => _san;

  @override
  Future<void> moHinhSan(String duongTep) async {
    soLanNap++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (napLoi) throw StateError('máy không chạy được');
    _san = true;
  }

  @override
  Future<PhienCongCu> moPhien({
    required String heThong,
    required String cauHoi,
    required List<KhaiBaoCongCu> congCu,
  }) async {
    daMo.add((heThong: heThong, cauHoi: cauHoi, congCu: congCu));
    return taoPhien();
  }

  @override
  Future<String> sinh(String prompt, {int tranToken = 0}) => throw UnimplementedError();
  @override
  Stream<String> sinhDan(String prompt, {int tranToken = 0}) => throw UnimplementedError();
  @override
  Future<void> huy() async {}
  @override
  Future<void> dong() async {}
}

/// Phiên không bao giờ tự kết thúc — như một lượt sinh bị treo. `huy` đóng luồng, như engine thật thôi giải mã.
class _PhienTreo implements PhienCongCu {
  final _luong = StreamController<SuKienLuot>();
  bool daDong = false;
  @override
  Stream<SuKienLuot> sinhLuot() => _luong.stream;
  @override
  Future<void> traKetQua(String ten, Map<String, dynamic> json) async {}
  @override
  Future<void> huy() async {
    if (!_luong.isClosed) await _luong.close();
  }

  @override
  Future<void> dong() async => daDong = true;
}

void main() {
  final now = DateTime(2026, 9, 30, 15);
  const thamSo = {
    'so_tien': 45000,
    'loai': 'chi',
    'ngay': '29/09/2026',
    'vi': 'Tiền mặt',
    'danh_muc': 'Ăn uống',
    'ghi_chu': 'ăn phở',
  };

  DocCauBangAi ai(_RuntimeGia r, {bool sanSang = true, Duration thoiHan = kThoiHanDocAi}) => DocCauBangAi(
        runtime: r,
        sanSang: () async => sanSang,
        duongTep: () async => '/gia/gemma.litertlm',
        thoiHan: thoiHan,
      );

  Future<dynamic> doc(DocCauBangAi a, [String cau = 'hôm qua ăn phở 45k tiền mặt']) =>
      a.doc(cau, now: now, tenVi: const ['Tiền mặt'], tenDanhMuc: const ['Ăn uống', 'Di chuyển']);

  test('⭐ đọc được: lời gọi tool đầu tiên → KetQuaAi; phiên được huỷ và đóng', () async {
    final phien = PhienCongCuGia([
      [const GoiCongCu(kTenCongCuDienGiaoDich, thamSo)],
    ]);
    final r = _RuntimeGia(() => phien);
    final kq = await doc(ai(r));
    expect(kq, isNotNull);
    expect(kq.soTien, 45000);
    expect(kq.loai, 'chi');
    expect(kq.vi, 'Tiền mặt');
    expect(kq.ghiChu, 'ăn phở');
    expect(phien.daDong, isTrue, reason: 'mỗi câu một phiên — không đóng là rò phiên native');
    expect(r.daMo.single.congCu.single.ten, kTenCongCuDienGiaoDich, reason: 'đúng MỘT tool — prompt ngắn (bẫy 4.51)');
    expect(r.daMo.single.heThong, contains('30/09/2026'), reason: 'mô hình phải biết hôm nay để đọc "hôm qua"');
  });

  test('máy chưa sẵn sàng (chưa tải mô hình / công tắc tắt) → null, KHÔNG nạp gì', () async {
    final r = _RuntimeGia(() => PhienCongCuGia(const []));
    expect(await doc(ai(r, sanSang: false)), isNull);
    expect(r.soLanNap, 0);
  });

  test('nạp một lần: chuanBi và doc gọi chồng nhau thì chờ chung một lượt nạp', () async {
    final r = _RuntimeGia(() => PhienCongCuGia([
          [const GoiCongCu(kTenCongCuDienGiaoDich, thamSo)],
        ]));
    final a = ai(r);
    final f1 = a.chuanBi();
    final f2 = a.chuanBi();
    final kq = await doc(a);
    await Future.wait([f1, f2]);
    expect(r.soLanNap, 1);
    expect(kq, isNotNull);
  });

  test('nạp lỗi → null; lần sau thử nạp lại', () async {
    final r = _RuntimeGia(() => PhienCongCuGia(const []), napLoi: true);
    final a = ai(r);
    expect(await doc(a), isNull);
    expect(await doc(a), isNull);
    expect(r.soLanNap, 2, reason: 'lượt nạp hỏng không được giữ lại làm kết quả vĩnh viễn');
  });

  test('mô hình không gọi tool (chỉ viết chữ) → null', () async {
    final r = _RuntimeGia(() => PhienCongCuGia([
          [const Chu('Tôi không hiểu câu này.')],
        ]));
    expect(await doc(ai(r)), isNull);
  });

  test('máy từng sập native ở phiên có tool (canary 1b) → null', () async {
    final r = _RuntimeGia(() => throw const BacCongCuDaTat());
    expect(await doc(ai(r)), isNull);
  });

  test('⚠️ lượt sinh treo → quá thời hạn thì null, phiên vẫn được đóng', () async {
    final phien = _PhienTreo();
    final r = _RuntimeGia(() => phien);
    expect(await doc(ai(r, thoiHan: const Duration(milliseconds: 50))), isNull);
    expect(phien.daDong, isTrue);
  });

  test('người dùng bấm Huỷ giữa lượt → null ngay khi engine dừng', () async {
    final phien = _PhienTreo();
    final r = _RuntimeGia(() => phien);
    final a = ai(r);
    final f = doc(a);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await a.huy();
    expect(await f, isNull);
    expect(phien.daDong, isTrue);
  });

  test('schema: vi và danh_muc là ENUM tên có thật (cộng chuỗi rỗng); loai chỉ ba giá trị', () {
    final k = khaiBaoDienGiaoDich(tenVi: const ['Tiền mặt', 'MB'], tenDanhMuc: const ['Ăn uống']);
    final p = k.thamSo['properties'] as Map<String, dynamic>;
    expect((p['vi'] as Map)['enum'], ['Tiền mặt', 'MB', '']);
    expect((p['danh_muc'] as Map)['enum'], ['Ăn uống', '']);
    expect((p['loai'] as Map)['enum'], ['chi', 'thu', 'khong_ro']);
    // Trần maxTokens là trần TỔNG (bẫy 4.39): 30 danh mục + 5 ví vẫn phải gọn.
    final lon = khaiBaoDienGiaoDich(
      tenVi: [for (var i = 0; i < 5; i++) 'Ví số $i'],
      tenDanhMuc: [for (var i = 0; i < 30; i++) 'Danh mục dài số $i'],
    );
    expect(toolsJsonCua([lon]).length, lessThan(3000));
  });
}
