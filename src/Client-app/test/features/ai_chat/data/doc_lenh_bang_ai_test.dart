/// C3 §8.2 — `DocLenhBangAi`: chỗ DUY NHẤT màn Trợ lý gọi mô hình cho lệnh tạo. Mọi đường hỏng trả `null` (màn dùng
/// luật dự phòng); không tool nào có tham số tầng 4 (tự trả / trích tự động).
library;

import 'dart:async';

import 'package:flowmoney/features/ai_chat/data/doc_lenh_bang_ai.dart';
import 'package:flowmoney/features/ai_edge/data/phien_cong_cu.dart';
import 'package:flowmoney/features/ai_edge/data/slm_runtime.dart';
import 'package:flowmoney/features/ai_edge/domain/canary_cong_cu.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flowmoney/features/ai_edge/domain/lenh_tao.dart';
import 'package:flowmoney/features/transaction/data/doc_cau_bang_ai.dart' show kThoiHanDocAi;
import 'package:flutter_test/flutter_test.dart';

class _RuntimeGia implements SlmRuntime {
  _RuntimeGia(this.taoPhien);
  final PhienCongCu Function() taoPhien;
  bool _san = false;
  int soLanNap = 0;
  final List<({String heThong, String cauHoi, List<KhaiBaoCongCu> congCu})> daMo = [];

  @override
  bool get dangSan => _san;

  @override
  Future<void> moHinhSan(String duongTep) async {
    soLanNap++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
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
  const goiHoaDon = GoiCongCu(kTenCongCuTaoHoaDon,
      {'ten': 'gym', 'so_tien': 300000, 'chu_ky': 'thang', 'ngay_goc': 5, 'vi': '', 'danh_muc': 'Giải trí'});

  DocLenhBangAi ai(_RuntimeGia r, {bool sanSang = true, Duration thoiHan = kThoiHanDocAi}) => DocLenhBangAi(
        runtime: r,
        sanSang: () async => sanSang,
        duongTep: () async => '/gia/gemma.litertlm',
        thoiHan: thoiHan,
      );
  Future<KetQuaLenhAi?> doc(DocLenhBangAi a, [String cau = 'mỗi tháng trả gym 300k vào mùng 5']) =>
      a.doc(cau, now: now, tenVi: const ['Tiền mặt'], tenDanhMuc: const ['Ăn uống', 'Giải trí']);

  test('⭐ đọc được: lời gọi tool lệnh đầu tiên → KetQuaLenhAi; ba khai báo; phiên đóng; hôm nay trong lời hệ thống',
      () async {
    final phien = PhienCongCuGia([
      [goiHoaDon],
    ]);
    final r = _RuntimeGia(() => phien);
    final kq = (await doc(ai(r)))!;
    expect((kq.loai, kq.ten, kq.soTien, kq.chuKy, kq.ngayGoc, kq.vi, kq.danhMuc),
        (LoaiLenhTao.hoaDon, 'gym', 300000.0, 'thang', 5, null, 'Giải trí'));
    expect(phien.daDong, isTrue, reason: 'mỗi câu một phiên — không đóng là rò phiên native');
    expect(r.daMo.single.congCu.map((k) => k.ten).toSet(), kTenCongCuLenhTao);
    expect(r.daMo.single.heThong, contains('30/09/2026'), reason: 'mô hình phải biết hôm nay để đọc "hè năm sau"');
  });

  test('mô hình gọi tool lạ rồi im → null; chỉ viết chữ (không gọi tool) → null = "không phải lệnh tạo"', () async {
    expect(
        await doc(ai(_RuntimeGia(() => PhienCongCuGia([
              [const GoiCongCu('bay_gio', {})],
            ])))),
        isNull);
    expect(
        await doc(ai(_RuntimeGia(() => PhienCongCuGia([
              [const Chu('Bạn nên tiết kiệm đều mỗi tháng.')],
            ])))),
        isNull);
  });

  test('chưa sẵn sàng (chưa tải mô hình / công tắc tắt) → null, KHÔNG nạp gì', () async {
    final r = _RuntimeGia(() => PhienCongCuGia(const []));
    expect(await doc(ai(r, sanSang: false)), isNull);
    expect(r.soLanNap, 0);
  });

  test('máy từng sập native ở phiên có tool (canary 1b) → null', () async {
    expect(await doc(ai(_RuntimeGia(() => throw const BacCongCuDaTat()))), isNull);
  });

  test('⚠️ lượt sinh treo → quá thời hạn thì null, phiên vẫn được đóng', () async {
    final phien = _PhienTreo();
    expect(await doc(ai(_RuntimeGia(() => phien), thoiHan: const Duration(milliseconds: 50))), isNull);
    expect(phien.daDong, isTrue);
  });

  test('người dùng bấm Huỷ giữa lượt → null, phiên đóng', () async {
    final phien = _PhienTreo();
    final a = ai(_RuntimeGia(() => phien));
    final f = doc(a);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await a.huy();
    expect(await f, isNull);
    expect(phien.daDong, isTrue);
  });

  test('⚠️ Huỷ khi mô hình CÒN ĐANG NẠP → null, không mở phiên nào', () async {
    final r = _RuntimeGia(() => PhienCongCuGia([
          [goiHoaDon],
        ]));
    final a = ai(r);
    final f = doc(a);
    await a.huy();
    expect(await f, isNull, reason: 'lượt đã bị huỷ mà vẫn trả kết quả là thẻ hiện ra sau khi người dùng bấm Huỷ');
    expect(r.daMo, isEmpty);
  });

  group('khaiBaoLenhTao', () {
    final kb = khaiBaoLenhTao(tenVi: const ['Tiền mặt'], tenDanhMuc: const ['Ăn uống']);

    test('⚠️ tầng 4: không tham số nào là tự trả / trích / lặp tự động', () {
      final khoa = [
        for (final k in kb) ...((k.thamSo['properties'] as Map).keys.cast<String>()),
      ];
      expect(khoa, isNotEmpty);
      expect(
          khoa.where((k) => k.contains('tu_tra') || k.contains('auto') || k.contains('trich') || k.contains('lap')),
          isEmpty,
          reason: 'bật tự trả / trích tự động là việc của người dùng trong form, không tool nào được mang nó');
    });

    test('enum ví / danh mục có chỗ rỗng để mô hình được phép không chọn', () {
      final hd = kb.firstWhere((k) => k.ten == kTenCongCuTaoHoaDon).thamSo['properties'] as Map;
      expect((hd['vi'] as Map)['enum'], ['Tiền mặt', '']);
      expect((hd['danh_muc'] as Map)['enum'], ['Ăn uống', '']);
      final ns = kb.firstWhere((k) => k.ten == kTenCongCuDatNganSach).thamSo['properties'] as Map;
      expect((ns['danh_muc'] as Map)['enum'], ['Ăn uống', '']);
    });

    test('mọi tham số đều required — mô hình phải điền rỗng / 0 thay vì bỏ khoá', () {
      for (final k in kb) {
        expect(k.thamSo['required'], (k.thamSo['properties'] as Map).keys.toList(), reason: k.ten);
      }
    });

    test('⭐ tools_json ba tool với 30 danh mục + 5 ví không dài hơn con số đã đo trên máy', () {
      const kTranToolsJsonLenhDaDo = 0; // Task 5 đặt số đo Realme rồi bỏ skip
      final n = toolsJsonCua(khaiBaoLenhTao(
        tenVi: [for (var i = 0; i < 5; i++) 'Ví số $i'],
        tenDanhMuc: [for (var i = 0; i < 30; i++) 'Danh mục dài số $i'],
      )).length;
      expect(n, lessThanOrEqualTo(kTranToolsJsonLenhDaDo),
          reason: 'tools_json $n ký tự — đo lại phiên trên Realme rồi mới nâng');
    }, skip: 'chờ đo Realme (C3 AI task 5)');
  });
}
