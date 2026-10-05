/// Vòng lặp tool — trần, thang lùi L1–L4, huỷ. Mọi ca chạy trên `PhienCongCuGia`
/// (kịch bản theo lượt) và một tool giả; hai bất biến mới của spec 4b:
/// (1) tool đã chạy thì mọi số trong câu hiện ra đều có trong hàng;
/// (2) chưa lượt tool nào THÀNH CÔNG, hoặc còn lời từ chối chưa gỡ, thì KHÔNG câu nào của mô hình được hiện (bước 2b).
library;

import 'package:flowmoney/features/ai_edge/data/bo_cong_cu.dart';
import 'package:flowmoney/features/ai_edge/data/phien_cong_cu.dart';
import 'package:flowmoney/features/ai_edge/data/slm_runtime.dart';
import 'package:flowmoney/features/ai_edge/data/vong_lap_cong_cu.dart';
import 'package:flowmoney/features/ai_edge/domain/canary_cong_cu.dart';
import 'package:flowmoney/features/ai_edge/domain/chinh_tham_so.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flowmoney/features/ai_edge/domain/dinh_tuyen.dart';
import 'package:flowmoney/features/ai_edge/domain/gac_cau.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so_tra_cuu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_so_lieu.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_so.dart';
import 'package:flowmoney/features/ai_edge/domain/loi_tham_so.dart';
import 'package:flowmoney/features/ai_edge/domain/slm_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

class _RuntimeGia implements SlmRuntime {
  _RuntimeGia(this.phien, {this.loiMoPhien, this.chuSinhDan = const []});
  final PhienCongCu phien;

  /// Có giá trị thì `moPhien` ném nó thay vì mở phiên.
  final Object? loiMoPhien;

  /// Token `sinhDan` phát — lượt viết câu của đường nhanh.
  final List<String> chuSinhDan;
  final List<String> promptSinhDan = [];

  /// Số lần `moPhien` được GỌI (kể cả lần ném `loiMoPhien`) — đường nhanh không mở.
  int soLanMoPhien = 0;
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
  Stream<String> sinhDan(String prompt, {int tranToken = 300}) {
    promptSinhDan.add(prompt);
    return Stream.fromIterable(chuSinhDan);
  }
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
    soLanMoPhien++;
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
  Future<KetQuaCongCu> chay(Map<String, dynamic> args, {required int idaccount, required DateTime now, String cauHoi = ''}) async {
    argsDaNhan.add(args);
    return ketQua;
  }
}

/// Tool trả lần lượt từng kết quả của [kichBan]; hết kịch bản thì lặp kết quả cuối.
class _CongCuKichBan implements CongCu {
  _CongCuKichBan(this.ten, this.kichBan);
  final String ten;
  final List<KetQuaCongCu> kichBan;
  final List<Map<String, dynamic>> argsDaNhan = [];
  @override
  KhaiBaoCongCu get khaiBao => KhaiBaoCongCu(
      ten: ten, moTa: 'giả', thamSo: const {'type': 'object', 'properties': <String, dynamic>{}});
  @override
  Future<KetQuaCongCu> chay(Map<String, dynamic> args,
      {required int idaccount, required DateTime now, String cauHoi = ''}) async {
    argsDaNhan.add(args);
    final i = argsDaNhan.length - 1;
    return kichBan[i < kichBan.length ? i : kichBan.length - 1];
  }
}

KetQuaCongCu _tuChoiDanhMuc(String hoi) =>
    tuChoiKhongKhop('danh_muc', hoi, const ['Ăn uống'], loai: 'danh mục');

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

/// Câu mẫu của khung `chay` — phải KHÔNG định tuyến: các ca dùng khung này kiểm
/// cơ chế vòng lặp khi mô hình tự chọn tool (L1, L1b, tool bịa tên). Câu cũ
/// *"Hoa don nao qua han?"* nay đi phiên một tool (A2, 2026-09-29) nên ba ca ấy
/// rơi vào nhánh định tuyến; *"đã trả"* nằm trong danh sách loại của họ hoá đơn.
const _cauKhongDinhTuyen = 'Hoa don nao toi da tra?';

/// Lượt `tim_giao_dich` THÀNH CÔNG mà 0 khoản — C9 cổng D lần 2 (bước 2c).
KetQuaCongCu _timRong() => KetQuaCongCu(
      hang: const [],
      tongHop: [soDem('Số giao dịch', 0), soTien('Tổng chi', 0)],
      soLieuBoLoc: [soTien('Đến', 1000000)],
      boLoc: const ['ghi chú chứa "chi"', 'đến 1.000.000 đ'],
      rongTheoBoLoc: true,
      chuThem: const {'ky': 'tháng này'},
    );

KetQuaCongCu _timCoHang() => KetQuaCongCu(
      hang: [
        HangSoLieu(ten: 'Cho vay', trangThai: 'khoản chi · test1 · Tiền mặt', canhBao: false,
            soLieu: [soTien('Số tiền', 800000, ten: 'Cho vay')]),
      ],
      tongHop: [soDem('Số giao dịch', 1), soTien('Tổng chi', 800000)],
      boLoc: const ['khoản chi'],
      chuThem: const {'ky': 'tháng này'},
      tenLienQuan: const ['test1', 'Tiền mặt'],
    );

const goiTimChi = GoiCongCu(kTenCongCuTruyVan, {'ky': 'thang_nay', 'tu_khoa': 'chi', 'so_tien_den': 1000000});

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
      _cauKhongDinhTuyen,
      runtime: rt, boCongCu: bo, goi: goi, idaccount: 10, now: now,
      tranGoi: tranGoi, log: log.add, dinhTuyen: dinhTuyenChiLuat,
    ).toList();
    return (sk, goi, phien, rt);
  }

  test('tiền đề: câu mẫu của khung KHÔNG định tuyến — luật định tuyến giành nó thì ca L1/L1b mất nghĩa', () {
    expect(congCuTheoCauHoi(_cauKhongDinhTuyen), isNull);
  });

  group('định tuyến theo CÂU HỎI ở tầng mã (mục 9.33: tool dự báo 0/3)', () {
    KetQuaCongCu duBao() => KetQuaCongCu(
          hang: const [],
          tongHop: [soTien('Số dư hiện tại', 300000), soTien('Còn tiêu được', 150000)],
          chuThem: const {'tinh_trang': 'đủ trả mọi cam kết'},
        );
    late _CongCuGia toolDuBao;

    Future<(List<SuKienGac>, GoiSoTraCuu, PhienCongCuGia)> hoi(
        String cauHoi, List<List<SuKienLuot>> kichBan) async {
      toolDuBao = _CongCuGia(kTenCongCuDuBao, duBao());
      final phien = PhienCongCuGia(kichBan);
      final goi = GoiSoTraCuu();
      final sk = await hoiBangCongCu(
        cauHoi,
        runtime: _RuntimeGia(phien),
        boCongCu: BoCongCu([tool, toolDuBao]),
        goi: goi, idaccount: 10, now: now, log: log.add, dinhTuyen: dinhTuyenChiLuat,
      ).toList();
      return (sk, goi, phien);
    }

    test('⭐ L6: mô hình gọi tool hoá đơn cho "trả hết hoá đơn thì còn bao nhiêu" → chạy tool DỰ BÁO', () async {
      final (sk, goi, phien) = await hoi('tra het hoa don thi con bao nhieu', [
        [goiHoaDon],
        [const Chu('Bạn còn tiêu được 150.000 đ.')],
      ]);
      expect(tool.argsDaNhan, isEmpty, reason: 'tool mô hình chọn KHÔNG chạy');
      expect(toolDuBao.argsDaNhan, [<String, dynamic>{}], reason: 'tool dự báo không tham số');
      expect(goi.tenCongCuDaChay, [kTenCongCuDuBao]);
      expect(phien.ketQuaDaNhan.single.$1, kTenCongCuHoaDon,
          reason: 'phiên chờ kết quả của ĐÚNG lời gọi nó đã phát');
      expect(phien.ketQuaDaNhan.single.$2['Còn tiêu được'], '150.000 đ');
      expect(sk.first, const DangTraCuu(kTenCongCuDuBao), reason: 'dòng chỉ báo nói tool THẬT chạy');
      expect(sk.last, const CauQua('Bạn còn tiêu được 150.000 đ.'));
      expect(log.any((l) => l.contains('định tuyến theo câu hỏi: $kTenCongCuHoaDon → $kTenCongCuDuBao')), isTrue);
    });

    test('⭐ câu đã định tuyến: phiên chỉ khai MỘT tool đích; câu không định tuyến: không khai tool chỉ-qua-định-tuyến', () async {
      Future<List<String>> khaiBaoCua(String cauHoi) async {
        toolDuBao = _CongCuGia(kTenCongCuDuBao, duBao());
        final rt = _RuntimeGia(PhienCongCuGia([
          [const Chu('x')],
        ]));
        await hoiBangCongCu(cauHoi,
            runtime: rt, boCongCu: BoCongCu([tool, toolDuBao]), goi: GoiSoTraCuu(),
            idaccount: 10, now: now, log: log.add, dinhTuyen: dinhTuyenChiLuat).toList();
        return [for (final k in rt.khaiBaoDaNhan!) k.ten];
      }

      expect(await khaiBaoCua('tra het hoa don thi con bao nhieu'), [kTenCongCuDuBao]);
      expect(await khaiBaoCua(_cauKhongDinhTuyen), [kTenCongCuHoaDon]);
    });

    // 2026-10-04: lời hệ thống đi theo phiên — phiên một tool không nạp ví dụ của tool
    // khác; phiên sáu tool giữ đúng lời đã đo.
    test('⭐ lời hệ thống theo đích: câu định tuyến → heThongCho(đích); câu không định tuyến → lời cũ', () async {
      Future<String?> heThongCua(String cauHoi) async {
        toolDuBao = _CongCuGia(kTenCongCuDuBao, duBao());
        final rt = _RuntimeGia(PhienCongCuGia([
          [const Chu('x')],
        ]));
        await hoiBangCongCu(cauHoi,
            runtime: rt, boCongCu: BoCongCu([tool, toolDuBao]), goi: GoiSoTraCuu(),
            idaccount: 10, now: now, log: log.add, dinhTuyen: dinhTuyenChiLuat).toList();
        return rt.heThongDaNhan;
      }

      expect(await heThongCua('tra het hoa don thi con bao nhieu'), heThongCho(kTenCongCuDuBao));
      expect(heThongCho(kTenCongCuDuBao), isNot(kPromptHeThongCongCu),
          reason: 'tiền đề: hai lời phải khác nhau thì ca trên mới canh được gì');
      expect(await heThongCua(_cauKhongDinhTuyen), kPromptHeThongCongCu);
    });

    test('mô hình gọi đúng tool dự báo → chạy bình thường, không log định tuyến', () async {
      final (_, goi, _) = await hoi('tra het hoa don thi con bao nhieu', [
        [const GoiCongCu(kTenCongCuDuBao, {})],
        [const Chu('Bạn còn tiêu được 150.000 đ.')],
      ]);
      expect(goi.tenCongCuDaChay, [kTenCongCuDuBao]);
      expect(log.any((l) => l.contains('định tuyến theo câu hỏi')), isFalse,
          reason: 'không lời gọi nào bị đổi');
      expect(log.first, contains('định tuyến: luật → $kTenCongCuDuBao'));
    });

    test('chỉ đổi lời gọi ĐẦU: tool dự báo đã chạy thì lời gọi sau chạy đúng tool mô hình chọn', () async {
      final (_, goi, _) = await hoi('tra het hoa don thi con bao nhieu', [
        [goiHoaDon],
        [goiHoaDon],
        [const Chu('Kiem đã quá hạn 45.000 đ.')],
      ]);
      expect(goi.tenCongCuDaChay, [kTenCongCuDuBao, kTenCongCuHoaDon]);
    });

    test('⭐ mô hình KHÔNG gọi tool nào mà câu hỏi có đích → tự chạy tool ấy, hiện MẪU CÂU, không rơi bậc 1', () async {
      final (sk, goi, _) = await hoi('toi con tieu duoc bao nhieu', [
        [const Chu('Bạn còn nhiều tiền.')],
      ]);
      expect(goi.tenCongCuDaChay, [kTenCongCuDuBao]);
      expect(sk.whereType<KhongTraCuu>(), isEmpty);
      expect(sk.last, CauQua(goi.mauCau().cau));
      expect((sk.last as CauQua).cau, contains('150.000 đ'));
      expect(sk.whereType<CauQua>().any((c) => c.cau.contains('nhiều tiền')), isFalse,
          reason: 'chữ viết trước khi có dữ liệu không bao giờ hiện (chốt L1)');
    });

    test('câu hỏi không có đích → y như cũ', () async {
      final (_, goi, _) = await hoi(_cauKhongDinhTuyen, [
        [goiHoaDon],
        [const Chu('Kiem đã quá hạn 45.000 đ.')],
      ]);
      expect(goi.tenCongCuDaChay, [kTenCongCuHoaDon]);
      expect(toolDuBao.argsDaNhan, isEmpty);
    });

    test('bộ tool không có tool đích (test cũ, bộ một tool) → không đổi gì', () async {
      final phien = PhienCongCuGia([
        [goiHoaDon],
        [const Chu('Kiem đã quá hạn 45.000 đ.')],
      ]);
      final goi = GoiSoTraCuu();
      await hoiBangCongCu('tra het hoa don thi con bao nhieu',
          runtime: _RuntimeGia(phien), boCongCu: bo, goi: goi, idaccount: 10, now: now,
          log: log.add, dinhTuyen: dinhTuyenChiLuat).toList();
      expect(goi.tenCongCuDaChay, [kTenCongCuHoaDon]);
    });
  });

  group('định tuyến MỀM — nguồn là mô hình nhỏ (dự án B, spec mục 3.1)', () {
    // Luật là thứ đã đo trên máy thật, mô hình nhỏ thì chưa: ở nguồn `moHinh`
    // định tuyến chỉ làm MỘT việc — thu phiên về một tool. Hai hành vi "ép"
    // (tự chạy tool đích với `{}`, đổi lời gọi sang tool đích) không áp.
    late _CongCuGia toolTruyVan;

    KetQuaDinhTuyen theoMoHinh(String _) => const KetQuaDinhTuyen(
        ten: kTenCongCuTruyVan,
        nguon: NguonDinhTuyen.moHinh,
        nhanMoHinh: kTenCongCuTruyVan,
        xacSuat: 0.93);
    KetQuaDinhTuyen theoLuat(String _) =>
        const KetQuaDinhTuyen(ten: kTenCongCuTruyVan, nguon: NguonDinhTuyen.luat);

    Future<(List<SuKienGac>, GoiSoTraCuu, _RuntimeGia)> hoi(
        List<List<SuKienLuot>> kichBan, KetQuaDinhTuyen Function(String) dinhTuyen) async {
      toolTruyVan = _CongCuGia(kTenCongCuTruyVan, _timCoHang());
      final rt = _RuntimeGia(PhienCongCuGia(kichBan));
      final goi = GoiSoTraCuu();
      final sk = await hoiBangCongCu(
        _cauKhongDinhTuyen,
        runtime: rt,
        boCongCu: BoCongCu([tool, toolTruyVan]),
        goi: goi, idaccount: 10, now: now, log: log.add, dinhTuyen: dinhTuyen,
      ).toList();
      return (sk, goi, rt);
    }

    test('⭐ phiên chỉ khai MỘT tool đích; log ghi nguồn và xác suất', () async {
      final (_, _, rt) = await hoi([
        [const Chu('x')],
      ], theoMoHinh);
      expect([for (final k in rt.khaiBaoDaNhan!) k.ten], [kTenCongCuTruyVan]);
      expect(log.first, contains('định tuyến: mô hình → $kTenCongCuTruyVan (p=0,93)'));
    });

    test('⭐ mô hình KHÔNG gọi tool → bậc 1 (L1): tool đích KHÔNG tự chạy, không mẫu câu', () async {
      final (sk, goi, _) = await hoi([
        [const Chu('Chào bạn, mình giúp gì được?')],
      ], theoMoHinh);
      expect(sk, [const KhongTraCuu()],
          reason: 'một câu chào bị định tuyến nhầm mà ép chạy tool giao dịch với {} thì người dùng '
              'nhận "chưa tra được số liệu: thiếu kỳ" — định tuyến mềm để Gemma tự từ chối gọi tool');
      expect(toolTruyVan.argsDaNhan, isEmpty);
      expect(goi.daTraCuu, isFalse);
    });

    test('⭐ mô hình gọi tên tool KHÁC → không đổi sang tool đích', () async {
      final (sk, goi, _) = await hoi([
        [goiHoaDon],
        [const Chu('Kiem đã quá hạn 45.000 đ.')],
      ], theoMoHinh);
      expect(toolTruyVan.argsDaNhan, isEmpty, reason: 'tool đích không nhận {} thay cho lời gọi của mô hình');
      expect(tool.argsDaNhan, [{'trang_thai': 'qua_han'}]);
      expect(goi.tenCongCuDaChay, [kTenCongCuHoaDon]);
      expect(sk.last, const CauQua('Kiem đã quá hạn 45.000 đ.'));
      expect(log.any((l) => l.contains('định tuyến theo câu hỏi')), isFalse);
    });

    test('mô hình gọi đúng tool đích → chạy với tham số CỦA MÔ HÌNH', () async {
      final (_, goi, _) = await hoi([
        [const GoiCongCu(kTenCongCuTruyVan, {'ky': 'thang_nay', 'chieu': 'khoan_chi'})],
        [const Chu('Cho vay 800.000 đ.')],
      ], theoMoHinh);
      expect(toolTruyVan.argsDaNhan, [{'ky': 'thang_nay', 'chieu': 'khoan_chi'}]);
      expect(goi.tenCongCuDaChay, [kTenCongCuTruyVan]);
    });

    test('đối chứng — CÙNG kịch bản, nguồn LUẬT: không gọi tool thì tool đích tự chạy; gọi tool khác thì đổi', () async {
      final (sk1, goi1, _) = await hoi([
        [const Chu('Chào bạn, mình giúp gì được?')],
      ], theoLuat);
      expect(toolTruyVan.argsDaNhan, [<String, dynamic>{}]);
      expect(sk1.last, CauQua(goi1.mauCau().cau));
      expect(log.first, contains('định tuyến: luật → $kTenCongCuTruyVan'));

      final (_, goi2, _) = await hoi([
        [goiHoaDon],
        [const Chu('Cho vay 800.000 đ.')],
      ], theoLuat);
      expect(goi2.tenCongCuDaChay, [kTenCongCuTruyVan]);
    });

    test('không định tuyến: log ghi nhãn mô hình đã đoán — đo máy thật phải thấy vì sao câu đi phiên sáu tool', () async {
      await hoi([
        [const Chu('x')],
      ], (_) => const KetQuaDinhTuyen(
          ten: null, nguon: NguonDinhTuyen.khong, nhanMoHinh: kTenCongCuHoaDon, xacSuat: 0.412));
      expect(log.first, contains('định tuyến: không (mô hình: $kTenCongCuHoaDon p=0,41)'));
    });

    test('mặc định (không truyền dinhTuyen) là đường ghép thật: câu luật bắt vẫn theo luật', () async {
      final rt = _RuntimeGia(PhienCongCuGia([
        [const Chu('x')],
      ]));
      await hoiBangCongCu('Hoa don nao qua han?',
          runtime: rt, boCongCu: bo, goi: GoiSoTraCuu(), idaccount: 10, now: now, log: log.add).toList();
      expect(log.first, contains('định tuyến: luật → $kTenCongCuHoaDon'));
    });
  });

  // Spec 2026-10-02 "đường nhanh": câu giao dịch mà luật đọc đủ tham số → tool chạy
  // TRƯỚC với {} (bộ chỉnh trong tool điền tham số), Gemma chỉ viết câu. Đo Realme
  // 2026-10-04: lượt Gemma điền tham số chiếm ~20 s / 26 s của một câu giao dịch.
  group('ĐƯỜNG NHANH — câu giao dịch luật đọc đủ (spec 2026-10-02)', () {
    late _CongCuGia toolTruyVan;
    KetQuaDinhTuyen veGiaoDich(String _) => const KetQuaDinhTuyen(
        ten: kTenCongCuTruyVan,
        nguon: NguonDinhTuyen.moHinh,
        nhanMoHinh: kTenCongCuTruyVan,
        xacSuat: 0.99);
    const cauDu = 'thang nay toi chi bao nhieu';
    const cauDung = 'Tháng này bạn đã chi 800.000 đ cho Cho vay.';

    Future<(List<SuKienGac>, GoiSoTraCuu, _RuntimeGia)> hoi(
      String cau, {
      KetQuaCongCu? ketQua,
      List<String> chu = const [],
      List<List<SuKienLuot>> kichBan = const [
        [Chu('x')],
      ],
      KetQuaDinhTuyen Function(String)? dinhTuyen,
      Object? loiMoPhien,
    }) async {
      toolTruyVan = _CongCuGia(kTenCongCuTruyVan, ketQua ?? _timCoHang());
      final rt = _RuntimeGia(PhienCongCuGia(kichBan), loiMoPhien: loiMoPhien, chuSinhDan: chu);
      final goi = GoiSoTraCuu();
      final sk = await hoiBangCongCu(cau,
              runtime: rt, boCongCu: BoCongCu([tool, toolTruyVan]), goi: goi,
              idaccount: 10, now: now, log: log.add, dinhTuyen: dinhTuyen ?? veGiaoDich)
          .toList();
      return (sk, goi, rt);
    }

    test('⭐ không mở phiên có tool; tool chạy với {}; Gemma chỉ viết câu từ kết quả', () async {
      final (sk, goi, rt) = await hoi(cauDu, chu: ['Tháng này bạn đã chi ', '800.000 đ cho Cho vay.']);
      expect(rt.soLanMoPhien, 0);
      expect(toolTruyVan.argsDaNhan, [<String, dynamic>{}]);
      expect(goi.tenCongCuDaChay, [kTenCongCuTruyVan]);
      expect(rt.promptSinhDan.single, contains('Kết quả tra cứu:'));
      expect(rt.promptSinhDan.single, contains('Câu hỏi: $cauDu'));
      expect(sk, [
        const DangTraCuu(kTenCongCuTruyVan),
        const DangTraCuu(null),
        const CauQua(cauDung),
      ]);
      expect(log.any((l) => l.contains('đường nhanh: luật đọc đủ → $kTenCongCuTruyVan')), isTrue);
      expect(log.last, contains('xong sau'));
    });

    test('⭐ 0 khoản theo bộ lọc → mẫu câu ngay, KHÔNG gọi Gemma', () async {
      final (sk, goi, rt) = await hoi(cauDu, ketQua: _timRong(), chu: ['Không có khoản nào.']);
      expect(rt.promptSinhDan, isEmpty);
      expect(rt.soLanMoPhien, 0);
      expect(sk.last, CauQua(goi.mauCau().cau));
    });

    test('⭐ câu Gemma trượt kiểm → mẫu câu (L2)', () async {
      final (sk, goi, _) = await hoi(cauDu, chu: ['Tháng này bạn chi 1.000.000 đ cho Cho vay.']);
      expect(sk.whereType<CauQua>().single, CauQua(goi.mauCau().cau));
    });

    test('⭐ tool TỪ CHỐI → đường cũ: mở phiên một tool, lượt từ chối không vào gói', () async {
      final (_, goi, rt) = await hoi(cauDu, ketQua: _tuChoiDanhMuc('abc'));
      expect(rt.soLanMoPhien, 1);
      expect(goi.tuChoiChuaGo, isEmpty, reason: 'lời từ chối của đường nhanh bị bỏ — không thành L1b');
      expect(log.any((l) => l.contains('đường nhanh: tool từ chối')), isTrue);
    });

    test('câu luật không đọc đủ → đường cũ', () async {
      final (_, _, rt) = await hoi('Quy nay danh muc nao ngon nhieu tien nhat?');
      expect(rt.soLanMoPhien, 1);
      expect(toolTruyVan.argsDaNhan, isEmpty);
    });

    test('đích không phải tool giao dịch → đường cũ', () async {
      final (_, _, rt) = await hoi(cauDu,
          dinhTuyen: (_) => const KetQuaDinhTuyen(ten: kTenCongCuHoaDon, nguon: NguonDinhTuyen.luat));
      expect(rt.soLanMoPhien, 1);
    });

    // C6 (người dùng chọn 2026-10-05): câu hỏi KỂ TÊN + ≥ 2 hàng → câu Gemma phải nêu tên mọi hàng, thiếu → mẫu câu.
    KetQuaCongCu haiKhoan() => KetQuaCongCu(
          hang: [
            HangSoLieu(ten: 'Tien nha T9', trangThai: 'khoản chi', canhBao: false,
                soLieu: [soTien('Số tiền', 3000000, ten: 'Tien nha T9')]),
            HangSoLieu(ten: 'An toi lien hoan', trangThai: 'khoản chi', canhBao: false,
                soLieu: [soTien('Số tiền', 1500000, ten: 'An toi lien hoan')]),
          ],
          tongHop: [soDem('Số giao dịch', 2), soTien('Tổng chi', 4500000)],
          soLieuBoLoc: [soTien('Từ', 1000000)],
          boLoc: const ['khoản chi', 'từ 1.000.000 đ'],
          chuThem: const {'ky': 'tháng trước'},
        );
    const cauC6 = 'thang truoc toi co khoan chi nao tren 1 trieu khong';

    test('⭐ C6: câu kể tên mà Gemma kể THIẾU một khoản → mẫu câu đủ dòng thay vào, câu thiếu không hiện', () async {
      final (sk, goi, rt) = await hoi(cauC6,
          ketQua: haiKhoan(), chu: ['Có khoản chi: Tien nha T9 với Số tiền: 3.000.000 đ.']);
      expect(rt.promptSinhDan, hasLength(1), reason: 'Gemma vẫn được gọi viết câu');
      expect(sk.whereType<CauQua>().map((c) => c.cau), [goi.mauCau().cau]);
      expect(goi.mauCau().cau, allOf(contains('Tien nha T9'), contains('An toi lien hoan')));
      expect(log.any((l) => l.contains('thiếu 1/2')), isTrue);
    });

    test('⭐ C6: Gemma kể ĐỦ mọi khoản → câu Gemma hiện (mọi câu, đúng thứ tự)', () async {
      final (sk, _, _) = await hoi(cauC6, ketQua: haiKhoan(), chu: [
        'Tháng trước bạn có hai khoản chi. ',
        'Đó là Tien nha T9 3.000.000 đ và An toi lien hoan 1.500.000 đ.',
      ]);
      expect(sk.whereType<CauQua>().map((c) => c.cau), [
        'Tháng trước bạn có hai khoản chi.',
        'Đó là Tien nha T9 3.000.000 đ và An toi lien hoan 1.500.000 đ.',
      ]);
    });

    test('câu hỏi TỔNG (không kể tên) với hai khoản → câu Gemma hiện dù không nêu tên từng khoản', () async {
      final (sk, _, _) = await hoi(cauDu, ketQua: haiKhoan(), chu: ['Tháng trước bạn đã chi 4.500.000 đ.']);
      expect(sk.whereType<CauQua>().map((c) => c.cau), ['Tháng trước bạn đã chi 4.500.000 đ.']);
    });

    test('⭐ máy đã tắt bậc tool (canary 1b) vẫn đi đường nhanh', () async {
      final (sk, _, rt) = await hoi(cauDu, chu: [cauDung], loiMoPhien: const BacCongCuDaTat());
      expect(sk.whereType<KhongTraCuu>(), isEmpty);
      expect(sk.last, const CauQua(cauDung));
      expect(rt.soLanMoPhien, 0);
    });
  });

  test('⭐ L2d: tool đòi MẪU CÂU → chữ mô hình (dù đúng số) KHÔNG hiện, mẫu câu in chữ kết luận', () async {
    tool = _CongCuGia(
      kTenCongCuHoaDon,
      KetQuaCongCu(
        hang: const [],
        tongHop: [soTien('Tổng tài sản', 12904000)],
        chuThem: const {'ket_qua': 'chưa đủ dữ liệu để biết tài sản tăng hay giảm'},
        chiMauCau: true,
      ),
    );
    bo = BoCongCu([tool]);
    final (sk, goi, _, _) = await chay([
      [goiHoaDon],
      [const Chu('Tổng tài sản tháng này là 12.904.000 đ.')],
    ]);
    expect(sk.whereType<CauQua>().single.cau,
        'Tổng tài sản: 12.904.000 đ — chưa đủ dữ liệu để biết tài sản tăng hay giảm.');
    expect(goi.daTraCuu, isTrue);
    expect(log.any((l) => l.contains('L2d')), isTrue);
  });

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
    expect(rt.cauHoiDaNhan, _cauKhongDinhTuyen);
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

  test('⭐ L1b: mọi lời gọi bị TỪ CHỐI → chữ mô hình KHÔNG hiện, mẫu câu trung thực, không rơi về bậc 1 (bẫy 4.40)', () async {
    tool = _CongCuGia(kTenCongCuHoaDon,
        tuChoiGiaTri('trang_thai', 'sap_toi', const ['qua_han', 'chua_tra']));
    bo = BoCongCu([tool]);
    final (sk, goi, _, _) = await chay([
      [const GoiCongCu(kTenCongCuHoaDon, {'trang_thai': 'sap_toi'})],
      [const Chu('Mình không có dữ liệu cho trạng thái đó.')],
    ]);
    expect(goi.daTraCuu, isFalse);
    expect(sk, [
      const DangTraCuu(kTenCongCuHoaDon),
      const DangTraCuu(null),
      const CauQua('Chưa tra được số liệu cho câu này: chưa hiểu trạng thái hoá đơn. '
          'Bạn thử hỏi lại cụ thể hơn.'),
    ], reason: 'Bản trước coi lượt bị từ chối là ĐÃ tra cứu nên câu "không có dữ liệu" '
        'được hiện — đúng kiểu C11, C12 của cổng D lần 1: không số nên lọt ba lớp chắn. '
        'Và KHÔNG phát KhongTraCuu: bậc 1 không có hàng giao dịch nào để trả lời.');
    expect(log.any((l) => l.contains('L1b')), isTrue);
  });

  test('L3 khi mọi lời gọi đều bị từ chối → mẫu câu trung thực, không "Không tìm thấy dữ liệu"', () async {
    tool = _CongCuGia(kTenCongCuHoaDon, tuChoiGiaTri('trang_thai', 'x', const ['qua_han']));
    bo = BoCongCu([tool]);
    final (sk, _, _, _) = await chay([
      [goiHoaDon], [goiHoaDon], [goiHoaDon], [goiHoaDon],
    ]);
    final cau = (sk.last as CauQua).cau;
    expect(cau, startsWith('Chưa tra được số liệu cho câu này'));
    expect(cau, isNot(contains('Không tìm thấy')),
        reason: 'câu SAI C8 của cổng D lần 1 sinh ra từ mẫu câu của app ở nhánh này');
  });

  test('⭐ L2b: có lượt thành công + lời từ chối chưa gỡ → chữ mô hình KHÔNG hiện; dữ liệu + câu chưa tra được', () async {
    final tuChoi = _CongCuGia(kTenCongCuTruyVan, _tuChoiDanhMuc('abc'));
    bo = BoCongCu([tool, tuChoi]);
    final (sk, goi, _, _) = await chay([
      [goiHoaDon, const GoiCongCu(kTenCongCuTruyVan, {'danh_muc': 'abc'})],
      [const Chu('Kiem đã quá hạn 45.000 đ. Không có khoản chi nào cho abc.')],
    ]);
    final cauQua = sk.whereType<CauQua>().toList();
    expect(cauQua, hasLength(1),
        reason: 'không câu nào của mô hình được hiện — kể cả câu đúng về Kiem');
    expect(cauQua.single.cau, goi.mauCau().cau);
    expect(cauQua.single.cau, contains('Kiem'));
    expect(cauQua.single.cau,
        endsWith('Chưa tra được phần còn lại: không có danh mục nào tên "abc".'));
    expect(log.any((l) => l.contains('L2b')), isTrue);
  });

  test('câu đã hiện rồi mới bị từ chối → GIỮ câu cũ, nối câu chưa tra được (L2b)', () async {
    final tuChoi = _CongCuGia(kTenCongCuTruyVan, _tuChoiDanhMuc('abc'));
    bo = BoCongCu([tool, tuChoi]);
    final (sk, _, _, _) = await chay([
      [goiHoaDon],
      [const Chu('Kiem đã quá hạn 45.000 đ. '), const GoiCongCu(kTenCongCuTruyVan, {'danh_muc': 'abc'})],
      [const Chu('Không có khoản chi nào cho abc.')],
    ]);
    expect(sk.whereType<CauQua>().map((c) => c.cau).toList(), [
      'Kiem đã quá hạn 45.000 đ.',
      'Chưa tra được phần còn lại: không có danh mục nào tên "abc".',
    ]);
  });

  test('⭐ gọi lại ĐIỀN đúng tham số bị từ chối → đã gỡ, chữ viết sau đó được hiện', () async {
    final giaoDich = _CongCuKichBan(kTenCongCuTruyVan, [_tuChoiDanhMuc('an uong x'), _kiem()]);
    bo = BoCongCu([giaoDich]);
    final (sk, goi, _, _) = await chay([
      [const GoiCongCu(kTenCongCuTruyVan, {'danh_muc': 'an uong x'})],
      [const GoiCongCu(kTenCongCuTruyVan, {'danh_muc': 'Ăn uống'})],
      [const Chu('Kiem đã quá hạn 45.000 đ.')],
    ]);
    expect(goi.tuChoiChuaGo, isEmpty);
    expect(sk.last, const CauQua('Kiem đã quá hạn 45.000 đ.'));
    expect(giaoDich.argsDaNhan.last, {'danh_muc': 'Ăn uống'});
  });

  test('⭐ gọi lại BỎ tham số bị từ chối → vẫn chưa gỡ: chữ mô hình không hiện (ca "abc")', () async {
    final giaoDich = _CongCuKichBan(kTenCongCuTruyVan, [_tuChoiDanhMuc('abc'), _kiem()]);
    bo = BoCongCu([giaoDich]);
    final (sk, goi, _, _) = await chay([
      [const GoiCongCu(kTenCongCuTruyVan, {'danh_muc': 'abc'})],
      [const GoiCongCu(kTenCongCuTruyVan, {})],
      [const Chu('Các khoản chi cho danh mục abc: Kiem 45.000 đ.')],
    ]);
    expect(goi.tuChoiChuaGo, hasLength(1));
    final cau = sk.whereType<CauQua>().single.cau;
    expect(cau, goi.mauCau().cau,
        reason: 'câu mô hình có tên thật, số thật mà mệnh đề sai (bẫy 4.42) — không được hiện');
    expect(cau, contains('không có danh mục nào tên "abc"'));
  });

  test('⭐ L2c: tim_giao_dich thành công mà 0 khoản + mô hình viết chữ → chữ KHÔNG hiện, mẫu câu nêu bộ lọc, không KhongTraCuu (bẫy 4.44)', () async {
    final giaoDich = _CongCuGia(kTenCongCuTruyVan, _timRong());
    bo = BoCongCu([giaoDich]);
    final (sk, goi, _, _) = await chay([
      [goiTimChi],
      [const Chu('Không có giao dịch chi tiêu nào từ 200k đến 1 triệu trong tháng này.')],
    ]);
    expect(goi.daTraCuu, isTrue);
    final cau = sk.whereType<CauQua>().single.cau;
    expect(cau, goi.mauCau().cau);
    expect(cau, 'Tháng này, ghi chú chứa "chi", đến 1.000.000 đ — không có giao dịch nào khớp.',
        reason: 'C9 cổng D lần 2: mẫu câu L2 nói "Số giao dịch: 0" trong khi có 2 khoản — người đọc phải thấy bộ lọc đã hẹp ở đâu');
    expect(sk.whereType<KhongTraCuu>(), isEmpty);
    expect(log.any((l) => l.contains('(L2c)')), isTrue);
    expect(log.any((l) => l.contains('lượt rỗng theo bộ lọc')), isTrue, reason: 'log bỏ chữ phải nêu lý do');
  });

  test('đã có câu hiện rồi mới gặp lượt rỗng → giữ câu cũ, nối cauNoiThem (L2c)', () async {
    final giaoDich = _CongCuGia(kTenCongCuTruyVan, _timRong());
    bo = BoCongCu([tool, giaoDich]);
    final (sk, _, _, _) = await chay([
      [goiHoaDon],
      [const Chu('Kiem đã quá hạn 45.000 đ. '), goiTimChi],
      [const Chu('Không có khoản chi nào như vậy.')],
    ]);
    expect(sk.whereType<CauQua>().map((c) => c.cau).toList(), [
      'Kiem đã quá hạn 45.000 đ.',
      'Không có giao dịch nào khớp: tháng này, ghi chú chứa "chi", đến 1.000.000 đ.',
    ]);
  });

  test('⭐ rỗng rồi gọi lại rộng hơn có hàng → chữ vẫn KHÔNG hiện; mẫu câu hai nhóm', () async {
    final giaoDich = _CongCuKichBan(kTenCongCuTruyVan, [_timRong(), _timCoHang()]);
    bo = BoCongCu([giaoDich]);
    final (sk, goi, _, _) = await chay([
      [goiTimChi],
      [const GoiCongCu(kTenCongCuTruyVan, {'ky': 'thang_nay', 'chieu': 'khoan_chi'})],
      [const Chu('Các khoản chi từ 200k đến 1 triệu: Cho vay 800.000 đ.')],
    ]);
    final cau = sk.whereType<CauQua>().single.cau;
    expect(cau, goi.mauCau().cau, reason: 'câu có tên thật, số thật mà mệnh đề sai — cùng họ bẫy 4.42');
    expect(cau, contains('không có giao dịch nào khớp'));
    expect(cau, contains('Tháng này, khoản chi — Cho vay'));
  });

  test('cả lời từ chối lẫn lượt rỗng → một lần nối theo thứ tự xảy ra, log (L2b+L2c)', () async {
    final giaoDich = _CongCuKichBan(kTenCongCuTruyVan, [_tuChoiDanhMuc('abc'), _timRong()]);
    bo = BoCongCu([tool, giaoDich]);
    final (sk, _, _, _) = await chay([
      [goiHoaDon],
      [const Chu('Kiem đã quá hạn 45.000 đ. '), const GoiCongCu(kTenCongCuTruyVan, {'danh_muc': 'abc'})],
      [goiTimChi],
      [const Chu('Không có gì cả.')],
    ]);
    expect(sk.whereType<CauQua>().map((c) => c.cau).toList(), [
      'Kiem đã quá hạn 45.000 đ.',
      'Chưa tra được phần còn lại: không có danh mục nào tên "abc". '
          'Không có giao dịch nào khớp: tháng này, ghi chú chứa "chi", đến 1.000.000 đ.',
    ]);
    expect(log.any((l) => l.contains('(L2b+L2c)')), isTrue);
  });

  test('tool KHÁC trả 0 hàng (không cờ) → chữ mô hình hiện như cũ (spec 2c mục 1.2 hàng 6)', () async {
    tool = _CongCuGia(kTenCongCuHoaDon, const KetQuaCongCu(hang: [], tongHop: []));
    bo = BoCongCu([tool]);
    final (sk, _, _, _) = await chay([
      [goiHoaDon],
      [const Chu('Không có hoá đơn nào quá hạn.')],
    ]);
    expect(sk.last, const CauQua('Không có hoá đơn nào quá hạn.'),
        reason: '0 hoá đơn quá hạn là sự thật — chỉ tim_giao_dich mới đóng cổng');
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
      hoiBangCongCu('x', runtime: _RuntimeGia(phien), boCongCu: bo, goi: goi, idaccount: 10, now: now, log: log.add, dinhTuyen: dinhTuyenChiLuat).toList(),
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
            log: log.add,
            dinhTuyen: dinhTuyenChiLuat)
        .toList();

    expect(sk, [const KhongTraCuu()],
        reason: 'máy từng sập native ở phiên có tool vẫn có bậc 1 chạy tốt — '
            'đi thẳng về đó, không hiện câu "mô hình không chạy được"');
    expect(tool.argsDaNhan, isEmpty);
    expect(log.any((l) => l.contains('đã tắt')), isTrue,
        reason: 'lượt đo trên máy thật phải thấy vì sao không có lời gọi tool');
  });
}
