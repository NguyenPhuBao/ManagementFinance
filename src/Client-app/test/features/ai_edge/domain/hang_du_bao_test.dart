/// Tool `du_bao_dong_tien` — phần CHÉP của ai_edge (spec mở rộng tool §4.1): mọi
/// con số là của `DuBaoDongTien` (`duBaoCua`), hàng là cam kết theo TÊN. Tool
/// này sinh ra cho câu 16–17 chặng 3 — "tiền có đủ trả hoá đơn không", "trả hết
/// thì còn bao nhiêu" — những câu đòi phép TRỪ mà mô hình không được làm.
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so_tra_cuu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_du_bao.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_so_lieu.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_cau_tra_loi.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_nhan.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_so.dart';
import 'package:flowmoney/features/analytics/domain/du_bao_dong_tien.dart';
import 'package:flutter_test/flutter_test.dart';

CamKet _ck(
  String ten,
  DateTime ngay,
  double soTien, {
  LoaiCamKet loai = LoaiCamKet.hoaDon,
  bool quaHan = false,
}) =>
    CamKet(
      ngay: ngay,
      ten: ten,
      loai: loai,
      walletId: 'w1',
      tenVi: 'Tiền mặt',
      soTien: soTien,
      categoryId: null,
      quaHan: quaHan,
      laKyChieu: false,
      tacDongTong: -soTien,
    );

DuBaoDongTien _db({
  double soDu = 300000,
  List<CamKet> camKet = const [],
  double nganSachConLai = 0,
  List<ViThieu> viThieu = const [],
}) =>
    DuBaoDongTien(
      tu: DateTime(2026, 9, 23),
      soDuHienTai: soDu,
      camKet: camKet,
      tongCamKet: camKet.fold(0, (s, c) => s + c.soTien),
      nganSachConLai: nganSachConLai,
      viThieu: viThieu,
      chuoi: const [],
    );

void main() {
  final now = DateTime(2026, 9, 23, 10);
  final haiCamKet = [
    _ck('Tiền nhà T9', DateTime(2026, 9, 26), 100000),
    _ck('MuaXe', DateTime(2026, 10, 1), 50000, loai: LoaiCamKet.trichTuDong),
  ];
  Map<String, String> so(HangSoLieu h) => {for (final s in h.soLieu) s.nhan: s.chuoi};

  test('⭐ ba con số đã TRỪ SẴN: số dư, tổng cam kết, còn tiêu được', () {
    final r = hangDuBao(_db(camKet: haiCamKet), now: now);
    expect(r.loi, isNull);
    expect(r.json['Số dư hiện tại'], '300.000 đ');
    expect(r.json['Tổng cam kết'], '150.000 đ');
    expect(r.json['Còn tiêu được'], '150.000 đ');
    expect(r.json['Số cam kết'], '2');
    expect(r.json['Số ví không đủ tiền'], '0');
    expect(r.chuThem['tinh_trang'], 'đủ trả mọi cam kết');
    expect(r.json.containsKey('Nếu tiêu đúng ngân sách còn'), isFalse,
        reason: 'không có ngân sách thì vế tầng hai là tiếng ồn');
  });

  test('hàng cam kết: tên, loại là trạng thái, Số tiền + Ngày mang tên hàng', () {
    final r = hangDuBao(_db(camKet: haiCamKet), now: now);
    expect(r.hang.map((h) => h.ten).toList(), ['Tiền nhà T9', 'MuaXe']);
    expect(r.hang[0].trangThai, 'hoá đơn');
    expect(r.hang[1].trangThai, 'trích tự động');
    expect(so(r.hang[0]), {'Số tiền': '100.000 đ', 'Ngày': '26/09'});
    expect(r.hang.expand((h) => h.soLieu).every((s) => s.ten != null), isTrue);
  });

  test('hoá đơn quá hạn: trạng thái nói rõ và hàng mang cờ cảnh báo', () {
    final r = hangDuBao(
      _db(camKet: [_ck('Kiem', DateTime(2026, 9, 23), 45000, quaHan: true)]),
      now: now,
    );
    expect(r.hang.single.trangThai, 'hoá đơn đã quá hạn');
    expect(r.hang.single.canhBao, isTrue);
  });

  test('⚠️ một hàng quá hạn: mẫu câu tự qua sáu lớp chắn (chữ trạng thái không bị đọc làm tên)', () {
    final g = GoiSoTraCuu()
      ..them(
        'du_bao_dong_tien',
        hangDuBao(_db(camKet: [_ck('Kiem', DateTime(2026, 9, 23), 45000, quaHan: true)]), now: now),
      );
    final cau = g.mauCau().cau;
    expect(kiemCauTraLoi(cau, [g]), isTrue,
        reason: 'trạng thái "hoá đơn · quá hạn" làm kiemTen đọc "· quá hạn" là tên hoá đơn: $cau');
  });

  test('có ngân sách: thêm con số "nếu tiêu đúng ngân sách"', () {
    final r = hangDuBao(_db(camKet: haiCamKet, nganSachConLai: 40000), now: now);
    expect(r.json['Nếu tiêu đúng ngân sách còn'], '110.000 đ');
  });

  test('⚠️ thiếu tiền: in số DƯƠNG dưới nhãn "Thiếu sau cam kết", không in số âm', () {
    final r = hangDuBao(
      _db(soDu: 100000, camKet: haiCamKet, viThieu: [
        ViThieu(walletId: 'w1', ten: 'Tiền mặt', thieu: 50000, ngay: DateTime(2026, 10, 1)),
      ]),
      now: now,
    );
    expect(r.json['Thiếu sau cam kết'], '50.000 đ',
        reason: 'mô hình nói "thiếu 50.000 đ" — số âm trong gói không khớp số dương của câu');
    expect(r.json.containsKey('Còn tiêu được'), isFalse);
    expect(r.json['Số ví không đủ tiền'], '1');
    expect(r.chuThem['tinh_trang'], 'thiếu tiền cho cam kết');
    expect(r.hang.first.ten, 'Tiền mặt', reason: 'ví thiếu đứng ĐẦU — mô hình đọc từ trên xuống');
    expect(r.hang.first.trangThai, 'ví không đủ');
    expect(r.hang.first.canhBao, isTrue);
    expect(so(r.hang.first), {'Thiếu': '50.000 đ', 'Ngày': '01/10'});
  });

  test('tổng còn dương nhưng MỘT ví thiếu → vẫn là "thiếu tiền cho cam kết"', () {
    final r = hangDuBao(
      _db(soDu: 900000, camKet: haiCamKet, viThieu: [
        ViThieu(walletId: 'w2', ten: 'test', thieu: 20000, ngay: DateTime(2026, 9, 26)),
      ]),
      now: now,
    );
    expect(r.chuThem['tinh_trang'], 'thiếu tiền cho cam kết');
    expect(r.json['Còn tiêu được'], '750.000 đ');
  });

  test('trần bốn hàng; Số cam kết vẫn đếm TRỌN tập', () {
    final r = hangDuBao(
      _db(soDu: 9000000, camKet: [
        for (var i = 1; i <= 6; i++) _ck('HD$i', DateTime(2026, 9, 23 + i), 10000),
      ]),
      now: now,
    );
    expect(r.hang, hasLength(4));
    expect(r.hang.first.ten, 'HD1', reason: 'gần nhất trước');
    expect(r.json['Số cam kết'], '6');
  });

  test('null (không có ví) → không hàng, không số, chữ nói chưa có ví — KHÔNG phải lời từ chối', () {
    final r = hangDuBao(null, now: now);
    expect(r.hang, isEmpty);
    expect(r.tongHop, isEmpty);
    expect(r.chuThem['tinh_trang'], 'chưa có ví');
    expect(r.loi, isNull);
  });

  test('chuThem KHÔNG chứa chữ số', () {
    final r = hangDuBao(_db(camKet: haiCamKet, nganSachConLai: 40000), now: now);
    expect(RegExp(r'\d').hasMatch(r.chuThem.values.join()), isFalse);
  });

  group('qua các lớp chắn', () {
    final g = GoiSoTraCuu()
      ..them('du_bao_dong_tien', hangDuBao(_db(camKet: haiCamKet), now: now));

    test('⭐ mẫu câu của gói tự qua sáu lớp chắn', () {
      final cau = g.mauCau().cau;
      expect(kiemSo(cau, g), isTrue, reason: cau);
      expect(kiemNhan(cau, [g]), isTrue, reason: cau);
      // Ca này từng chỉ gọi hai lớp đầu, nên nhãn "Ví thiếu" (kiemTen đọc
      // "thiếu" là tên ví) làm mẫu câu trượt từ lát 1 mà không ca nào đỏ.
      expect(kiemCauTraLoi(cau, [g]), isTrue, reason: cau);
    });

    test('⭐ câu 17 chặng 3: "trả hết cam kết thì còn 150.000 đ" qua', () {
      const cau = 'Sau khi trả hết các cam kết trong 30 ngày tới, bạn còn tiêu được 150.000 đ.';
      expect(kiemSo(cau, g), isTrue, reason: '"30 ngày tới" là tên tầm nhìn, không phải số bịa');
      expect(kiemNhan(cau, [g]), isTrue);
    });

    test('câu 16: "số dư 300.000 đ, phải trả 150.000 đ" qua', () {
      const cau = 'Số dư hiện tại là 300.000 đ, tổng cam kết phải trả là 150.000 đ nên bạn đủ tiền.';
      expect(kiemSo(cau, g), isTrue);
      expect(kiemNhan(cau, [g]), isTrue);
    });

    test('số bịa vẫn bị chặn; "45 ngày tới" không phải tầm nhìn của gói', () {
      expect(kiemSo('Bạn còn tiêu được 200.000 đ.', g), isFalse);
      expect(kiemSo('Trong 45 ngày tới bạn còn 150.000 đ.', g), isFalse);
    });
  });

  group('A3 — kỳ quá hạn trùng gộp một hàng', () {
    final haiKy = [
      _ck('Kiem', DateTime(2026, 9, 23), 45000, quaHan: true),
      _ck('Kiem', DateTime(2026, 9, 23), 45000, quaHan: true),
      _ck('Netflix', DateTime(2026, 10, 5), 100000),
    ];

    test('⭐ hai kỳ Kiem → MỘT hàng: Tổng quá hạn 90.000, Mỗi kỳ 45.000, Số kỳ quá hạn 2', () {
      final r = hangDuBao(_db(camKet: haiKy), now: now);
      expect(r.hang.map((h) => h.ten).toList(), ['Kiem', 'Netflix']);
      expect(so(r.hang[0]), {
        'Tổng quá hạn': '90.000 đ',
        'Mỗi kỳ': '45.000 đ',
        'Số kỳ quá hạn': '2',
        'Ngày': '23/09',
      });
      expect(r.hang[0].trangThai, 'hoá đơn đã quá hạn');
      expect(so(r.hang[1]), {'Số tiền': '100.000 đ', 'Ngày': '05/10'});
    });

    test('Số cam kết và Tổng cam kết vẫn của TRỌN tập — khớp trang Phân tích', () {
      final r = hangDuBao(_db(camKet: haiKy), now: now);
      expect(r.json['Số cam kết'], '3');
      expect(r.json['Tổng cam kết'], '190.000 đ');
    });

    test('các kỳ khác số tiền → không có Mỗi kỳ', () {
      final r = hangDuBao(
        _db(camKet: [
          _ck('Kiem', DateTime(2026, 9, 23), 45000, quaHan: true),
          _ck('Kiem', DateTime(2026, 9, 23), 50000, quaHan: true),
        ]),
        now: now,
      );
      expect(so(r.hang.single).containsKey('Mỗi kỳ'), isFalse);
      expect(so(r.hang.single)['Tổng quá hạn'], '95.000 đ');
    });

    test('⭐ mẫu câu của gói tự qua sáu lớp chắn; câu tự nhiên nêu tổng và mỗi kỳ đều qua', () {
      final g = GoiSoTraCuu()..them('du_bao_dong_tien', hangDuBao(_db(camKet: haiKy), now: now));
      final cau = g.mauCau().cau;
      expect(kiemCauTraLoi(cau, [g]), isTrue, reason: cau);
      expect('Kiem'.allMatches(cau).length, 1, reason: 'tên chỉ in MỘT lần — đó là cả mục đích của A3: $cau');
      expect(kiemCauTraLoi('Hoá đơn Kiem quá hạn 2 kỳ, tổng 90.000 đ, mỗi kỳ 45.000 đ.', [g]), isTrue);
      // Không dấu phẩy: `kiemTen` đọc cụm sau dấu phẩy ngay sau "hoá đơn X" là
      // một tên nữa — luật có sẵn, ngoài phạm vi A3. Ca này canh nhãn thay thế.
      expect(kiemCauTraLoi('Hoá đơn Kiem quá hạn phải trả 90.000 đ.', [g]), isTrue,
          reason: 'nhãn thay thế "Phải trả"');
    });

    test('trần bốn hàng tính trên hàng ĐÃ GỘP', () {
      final r = hangDuBao(
        _db(soDu: 9000000, camKet: [
          _ck('Kiem', DateTime(2026, 9, 23), 45000, quaHan: true),
          _ck('Kiem', DateTime(2026, 9, 23), 45000, quaHan: true),
          for (var i = 1; i <= 3; i++) _ck('HD$i', DateTime(2026, 9, 23 + i), 10000),
        ]),
        now: now,
      );
      expect(r.hang.map((h) => h.ten).toList(), ['Kiem', 'HD1', 'HD2', 'HD3']);
    });
  });

  test('⭐ đo Realme 2026-10-04: "…tiêu đúng ngân sách, bạn sẽ thiếu X" qua sáu lớp chắn', () {
    // soDu 100.000 − cam kết 150.000 − ngân sách còn 40.000 → thiếu 90.000.
    final g = GoiSoTraCuu()
      ..them('du_bao_dong_tien',
          hangDuBao(_db(soDu: 100000, camKet: haiCamKet, nganSachConLai: 40000), now: now));
    const cau = 'Dựa trên thông tin, nếu bạn tiêu đúng ngân sách, bạn sẽ thiếu 90.000 đ.';
    expect(kiemCauTraLoi(cau, [g]), isTrue,
        reason: 'kiemTen từng đọc "bạn" sau "ngân sách," là tên một ngân sách — câu đúng '
            'rơi về mẫu câu liệt kê dài');
  });
}
