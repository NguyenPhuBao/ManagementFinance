/// Vòng lặp tool — trần, thang lùi L1–L4, huỷ. Mọi ca chạy trên `PhienCongCuGia`
/// (kịch bản theo lượt) và một tool giả; hai bất biến mới của spec 4b:
/// (1) tool đã chạy thì mọi số trong câu hiện ra đều có trong hàng;
/// (2) chưa tool nào chạy thì KHÔNG câu nào của mô hình được hiện.
library;

import 'package:flowmoney/features/ai_edge/data/bo_cong_cu.dart';
import 'package:flowmoney/features/ai_edge/data/phien_cong_cu.dart';
import 'package:flowmoney/features/ai_edge/data/slm_runtime.dart';
import 'package:flowmoney/features/ai_edge/data/vong_lap_cong_cu.dart';
import 'package:flowmoney/features/ai_edge/domain/canary_cong_cu.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flowmoney/features/ai_edge/domain/gac_cau.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so_tra_cuu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_so_lieu.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_so.dart';
import 'package:flutter_test/flutter_test.dart';

class _RuntimeGia implements SlmRuntime {
  _RuntimeGia(this.phien, {this.loiMoPhien});
  final PhienCongCu phien;

  /// Có giá trị thì `moPhien` ném nó thay vì mở phiên.
  final Object? loiMoPhien;
  String? heThongDaNhan;
  String? cauHoiDaNhan;
  List<KhaiBaoCongCu>? khaiBaoDaNhan;

  @override
  bool get dangSan => true;
  @override
  Future<void> moHinhSan(String duongTep) async {}
  @override
  Future<String> sinh(String prompt, {int tranToken = 120}) async => '';
  @override
  Stream<String> sinhDan(String prompt, {int tranToken = 300}) => const Stream.empty();
  @override
  Future<void> huy() async {}
  @override
  Future<void> dong() async {}
  @override
  Future<PhienCongCu> moPhien({
    required String heThong,
    required String cauHoi,
    required List<KhaiBaoCongCu> congCu,
  }) async {
    final loi = loiMoPhien;
    if (loi != null) throw loi;
    heThongDaNhan = heThong;
    cauHoiDaNhan = cauHoi;
    khaiBaoDaNhan = congCu;
    return phien;
  }
}

class _CongCuGia implements CongCu {
  _CongCuGia(this.ten, this.ketQua);
  final String ten;
  final KetQuaCongCu ketQua;
  final List<Map<String, dynamic>> argsDaNhan = [];
  @override
  KhaiBaoCongCu get khaiBao => KhaiBaoCongCu(
      ten: ten, moTa: 'giả', thamSo: const {'type': 'object', 'properties': <String, dynamic>{}});
  @override
  Future<KetQuaCongCu> chay(Map<String, dynamic> args, {required int idaccount, required DateTime now}) async {
    argsDaNhan.add(args);
    return ketQua;
  }
}

/// Phiên ném ngay lượt đầu — L4.
class _PhienNem implements PhienCongCu {
  bool daDong = false;
  @override
  Stream<SuKienLuot> sinhLuot() => Stream.error(StateError('engine chết'));
  @override
  Future<void> traKetQua(String ten, Map<String, dynamic> json) async {}
  @override
  Future<void> huy() async {}
  @override
  Future<void> dong() async => daDong = true;
}

KetQuaCongCu _kiem() => KetQuaCongCu(
      hang: [
        HangSoLieu(ten: 'Kiem', trangThai: 'đã quá hạn', canhBao: true, soLieu: [soTien('Số tiền', 45000, ten: 'Kiem')]),
      ],
      tongHop: [soTien('Còn phải trả', 155000), soDem('Quá hạn', 1)],
    );

const goiHoaDon = GoiCongCu(kTenCongCuHoaDon, {'trang_thai': 'qua_han'});

void main() {
  final now = DateTime(2026, 9, 23);
  late _CongCuGia tool;
  late BoCongCu bo;
  late List<String> log;

  setUp(() {
    tool = _CongCuGia(kTenCongCuHoaDon, _kiem());
    bo = BoCongCu([tool]);
    log = [];
  });

  /// Chạy trọn vòng lặp trên một kịch bản, trả (sự kiện, gói, phiên, runtime).
  Future<(List<SuKienGac>, GoiSoTraCuu, PhienCongCuGia, _RuntimeGia)> chay(
      List<List<SuKienLuot>> kichBan, {int tranGoi = kTranGoiCongCu}) async {
    final phien = PhienCongCuGia(kichBan);
    final rt = _RuntimeGia(phien);
    final goi = GoiSoTraCuu();
    final sk = await hoiBangCongCu(
      'Hoa don nao qua han?',
      runtime: rt, boCongCu: bo, goi: goi, idaccount: 10, now: now,
      tranGoi: tranGoi, log: log.add,
    ).toList();
    return (sk, goi, phien, rt);
  }

  test('⭐ gọi tool → hàng vào gói, JSON về phiên, câu cuối kiểm trên gói và hiện', () async {
    final (sk, goi, phien, rt) = await chay([
      [goiHoaDon],
      [const Chu('Kiem đã quá hạn '), const Chu('45.000 đ.')],
    ]);
    expect(sk, [
      const DangTraCuu(kTenCongCuHoaDon),
      const DangTraCuu(null),
      const CauQua('Kiem đã quá hạn 45.000 đ.'),
    ]);
    expect(tool.argsDaNhan, [{'trang_thai': 'qua_han'}]);
    // ⚠️ Không so thẳng danh sách RECORD chứa `Map` — record so `==` từng
    // trường, `Map` so bằng danh tính, matcher `equals` không so sâu vào
    // record: ca viết thế đỏ trên cả mã đúng (cùng khuôn Task 3).
    expect([for (final (ten, json) in phien.ketQuaDaNhan) [ten, json]], [
      [kTenCongCuHoaDon, _kiem().json],
    ]);
    expect(goi.daTraCuu, isTrue);
    expect(goi.hang.single.ten, 'Kiem');
    expect(rt.khaiBaoDaNhan!.single.ten, kTenCongCuHoaDon);
    expect(rt.cauHoiDaNhan, 'Hoa don nao qua han?');
    expect(rt.heThongDaNhan, isNotEmpty);
    expect(phien.daDong, isTrue);
    expect(log.any((l) => l.contains('gọi $kTenCongCuHoaDon')), isTrue);
  });

  test('⭐ L1: lượt đầu không gọi tool → KhongTraCuu, câu (kể cả không số) KHÔNG hiện', () async {
    final (sk, goi, phien, _) = await chay([
      [const Chu('Bạn có hoá đơn Kiem quá hạn.')],
    ]);
    expect(sk, [const KhongTraCuu()],
        reason: 'kiemSo mù với câu bịa tên không có số — chưa dữ liệu thì không hiện gì');
    expect(goi.daTraCuu, isFalse);
    expect(phien.daDong, isTrue);
    expect(log.any((l) => l.contains('L1')), isTrue);
  });

  // ⚠️ Hai ca dưới cho câu trượt đến khi luồng CÒN MỞ (khoảng trắng theo sau +
  // một token nữa): `gacTheoCau` chỉ gọi `huy` khi câu trượt giữa luồng — câu
  // cuối kiểm lúc luồng đã đóng thì "không còn gì để huỷ". Bản đầu của kế hoạch
  // đưa câu sai ở token cuối không khoảng trắng rồi đòi `soLanHuy == 1`, nên đỏ
  // trên cả mã đúng. Token sau câu trượt thì không bao giờ được xét.
  test('⭐ câu bịa số → BiChan + huỷ, rồi MẪU CÂU của gói (L2)', () async {
    final (sk, goi, phien, _) = await chay([
      [goiHoaDon],
      [const Chu('Kiem đã quá hạn 99.000 đ. '), const Chu('Còn nữa.')],
    ]);
    final mau = goi.mauCau().cau;
    expect(sk, [
      const DangTraCuu(kTenCongCuHoaDon),
      const DangTraCuu(null),
      const BiChan('Kiem đã quá hạn 99.000 đ.'),
      CauQua(mau),
    ]);
    expect(phien.soLanHuy, 1, reason: 'gacTheoCau huỷ lượt sinh khi câu trượt');
    expect(mau, contains('45.000 đ'));
    expect(kiemSo(mau, goi), isTrue, reason: 'câu rơi về phải tự qua bộ kiểm');
  });

  test('câu qua kiểm rồi mới trượt → GIỮ câu đã hiện, không mẫu câu', () async {
    final (sk, _, phien, _) = await chay([
      [goiHoaDon],
      [const Chu('Kiem đã quá hạn 45.000 đ. '), const Chu('Tổng 99 đ. '), const Chu('Thêm.')],
    ]);
    expect(sk.whereType<CauQua>().toList(), [const CauQua('Kiem đã quá hạn 45.000 đ.')]);
    expect(sk.last, const BiChan('Tổng 99 đ.'));
    expect(phien.soLanHuy, 1);
  });

  test('L3: quá trần lời gọi → mẫu câu, không chạy tool thứ tư', () async {
    final (sk, _, phien, _) = await chay([
      [goiHoaDon], [goiHoaDon], [goiHoaDon], [goiHoaDon], [const Chu('không tới đây')],
    ]);
    expect(tool.argsDaNhan.length, 3);
    expect(phien.ketQuaDaNhan.length, 3);
    expect(sk.last, isA<CauQua>());
    expect((sk.last as CauQua).cau, contains('Kiem'));
    expect(sk.whereType<CauQua>().any((c) => c.cau.contains('không tới đây')), isFalse);
    expect(log.any((l) => l.contains('L3')), isTrue);
  });

  test('tool bịa tên: mô hình nhận lỗi kèm tên tool thật; KHÔNG tính là đã tra cứu', () async {
    final (sk, goi, phien, _) = await chay([
      [const GoiCongCu('bay_gio_may_gio', {})],
      [const Chu('Không biết.')],
    ]);
    expect(phien.ketQuaDaNhan.single.$1, 'bay_gio_may_gio');
    expect(phien.ketQuaDaNhan.single.$2['loi'], contains(kTenCongCuHoaDon));
    expect(goi.daTraCuu, isFalse);
    expect(sk, [const DangTraCuu('bay_gio_may_gio'), const DangTraCuu(null), const KhongTraCuu()]);
  });

  test('tool từ chối tham số lạ vẫn là ĐÃ tra cứu: câu không số của mô hình được hiện', () async {
    tool = _CongCuGia(kTenCongCuHoaDon, const KetQuaCongCu.loi('trang_thai lạ',
        choNguoiDung: 'chưa hiểu trạng thái hoá đơn', thamSoGo: ['trang_thai']));
    bo = BoCongCu([tool]);
    final (sk, goi, _, _) = await chay([
      [const GoiCongCu(kTenCongCuHoaDon, {'trang_thai': 'sap_toi'})],
      [const Chu('Mình không có dữ liệu cho trạng thái đó.')],
    ]);
    expect(goi.daTraCuu, isTrue);
    expect(sk.last, const CauQua('Mình không có dữ liệu cho trạng thái đó.'));
  });

  test('trả lời rỗng sau tool → mẫu câu (L2)', () async {
    final (sk, goi, _, _) = await chay([
      [goiHoaDon],
      <SuKienLuot>[],
    ]);
    expect(sk.last, CauQua(goi.mauCau().cau));
    expect(log.any((l) => l.contains('L2')), isTrue);
  });

  test('chữ ở lượt gọi tool TRƯỚC khi có hàng bị bỏ, chỉ ghi log', () async {
    final (sk, _, _, _) = await chay([
      [const Chu('Để mình xem. '), goiHoaDon],
      [const Chu('Kiem đã quá hạn 45.000 đ.')],
    ]);
    expect(sk.whereType<CauQua>().toList(), [const CauQua('Kiem đã quá hạn 45.000 đ.')]);
    expect(log.any((l) => l.contains('bỏ')), isTrue);
  });

  test('L4: phiên ném → lỗi lan lên người gọi, phiên vẫn đóng', () async {
    final phien = _PhienNem();
    final goi = GoiSoTraCuu();
    await expectLater(
      hoiBangCongCu('x', runtime: _RuntimeGia(phien), boCongCu: bo, goi: goi, idaccount: 10, now: now, log: log.add).toList(),
      throwsStateError,
    );
    expect(phien.daDong, isTrue);
  });

  test('bậc tool ĐÃ TẮT trên máy này (canary 1b) → bậc 1, im lặng — không phải L4',
      () async {
    final phien = PhienCongCuGia([
      [goiHoaDon],
    ]);
    final sk = await hoiBangCongCu('Hoa don nao qua han?',
            runtime: _RuntimeGia(phien, loiMoPhien: const BacCongCuDaTat()),
            boCongCu: bo,
            goi: GoiSoTraCuu(),
            idaccount: 10,
            now: now,
            log: log.add)
        .toList();

    expect(sk, [const KhongTraCuu()],
        reason: 'máy từng sập native ở phiên có tool vẫn có bậc 1 chạy tốt — '
            'đi thẳng về đó, không hiện câu "mô hình không chạy được"');
    expect(tool.argsDaNhan, isEmpty);
    expect(log.any((l) => l.contains('đã tắt')), isTrue,
        reason: 'lượt đo trên máy thật phải thấy vì sao không có lời gọi tool');
  });
}
