/// Tầng 3 của khối Dự báo (B4) — ước tính CHI TUỲ Ý 30 ngày tới theo thói quen,
/// dạng khoảng p25–p75 của các tuần ISO đã đóng. Spec
/// docs/superpowers/specs/2026-09-28-b4-uoc-tinh-chi-tuy-y-design.md §2–§3.
///
/// Canh chừng điều gì: mọi lỗi ở đây là một KHOẢNG SỐ KHÁC trên màn hình, không
/// exception — đếm đôi với tầng 1/2, nửa tuần kéo phân vị xuống, tuần vắt năm
/// bị cắt đôi.
library;

import 'package:flowmoney/features/analytics/domain/nguong_co_nghia.dart';
import 'package:flowmoney/features/analytics/domain/thong_ke_thang.dart';
import 'package:flowmoney/features/analytics/domain/uoc_tinh_chi_tuy_y.dart';
import 'package:flowmoney/features/budget/domain/cua_so_nhin_lai.dart';
import 'package:flutter_test/flutter_test.dart';

KhoanThuChi _k(DateTime ngay, double tien,
        {String? cat = 'an', bool camKet = false, String loai = 'chi'}) =>
    KhoanThuChi(
      ngay: ngay,
      soTien: tien,
      loai: loai,
      categoryId: cat,
      // Nhóm của khoản theo `phanLoaiCua` là `classify` của danh mục — khoản
      // thu nằm ở danh mục thu, không phải danh mục chi.
      classify: loai == 'thu' ? 'thu' : 'chi',
      ghiChu: '',
      laKhoanCamKet: camKet,
    );

void main() {
  // now = thứ Hai 30/11/2026 10:00; mốc đầu 28/09 (thứ Hai) → cửa sổ 63 ngày.
  // Tuần của now bắt đầu 30/11, nên chín tuần đóng trọn: 28/9, 5/10, …, 23/11.
  final now = DateTime(2026, 11, 30, 10);
  final cuaSo = cuaSoNhinLai(now, DateTime(2026, 9, 28));

  // Chi tuỳ ý mỗi tuần; sắp xếp: [0, 0, .3, .4, .4, .5, .5, .6, .7] triệu →
  // p25 (chỉ số 0,25 × 8 = 2) = 300.000; p75 (chỉ số 6) = 500.000.
  const moiTuan = [
    300000.0, 500000.0, 0.0, 700000.0, 400000.0, 600000.0, 0.0, 500000.0, 400000.0,
  ];
  List<KhoanThuChi> chinTuan() => [
        for (var i = 0; i < moiTuan.length; i++)
          if (moiTuan[i] > 0) _k(DateTime(2026, 9, 30 + 7 * i), moiTuan[i]),
      ];

  UocTinhChiTuyY? tinh(List<KhoanThuChi> ds,
          {CuaSoNhinLai? cs, Set<String> nganSach = const {}, bool tong = false}) =>
      uocTinhChiTuyY(ds,
          now: now,
          cuaSo: cs ?? cuaSo,
          danhMucCoNganSach: nganSach,
          coNganSachTong: tong);

  test('tiền đề: cửa sổ bắt đầu đúng mốc 28/09', () {
    expect(cuaSo!.from, DateTime(2026, 9, 28),
        reason: 'mọi kỳ vọng dưới đây đếm tuần từ mốc này — lệch là tính lại tay');
  });

  test('⭐ chín tuần (có hai tuần 0) → khoảng đúng phân vị tính tay', () {
    final r = tinh(chinTuan())!;
    expect(r.soTuan, 9);
    expect(r.thap, 1290000,
        reason: 'p25 = 300.000 × 30/7 ≈ 1.285.714 → làm tròn 10.000');
    expect(r.cao, 2140000, reason: 'p75 = 500.000 × 30/7 ≈ 2.142.857');
  });

  test('ba tuần đóng → null (cần ≥ $kSoTuanToiThieu)', () {
    final cs = cuaSoNhinLai(now, DateTime(2026, 11, 9)); // 9/11, 16/11, 23/11
    expect(tinh(chinTuan(), cs: cs), isNull);
  });

  test('⚠️ tuần đầu bị cửa sổ cắt ngang KHÔNG vào mẫu', () {
    final cs = cuaSoNhinLai(now, DateTime(2026, 10, 1)); // thứ Năm — tuần 28/9 bị cắt
    final coKhoanLon = [...chinTuan(), _k(DateTime(2026, 10, 2), 9000000)];
    final r = tinh(coKhoanLon, cs: cs)!;
    expect(r.soTuan, 8);
    expect(r.cao, tinh(chinTuan(), cs: cs)!.cao,
        reason: 'khoản 9 triệu nằm trong tuần bị cắt — không được kéo phân vị lên');
  });

  test('⚠️ khoản cam kết và danh mục có ngân sách KHÔNG vào (tầng 1, 2 đã tính)', () {
    final them = [
      ...chinTuan(),
      _k(DateTime(2026, 10, 7), 5000000, camKet: true),
      _k(DateTime(2026, 10, 8), 5000000, cat: 'co_ns'),
    ];
    final r = tinh(them, nganSach: {'co_ns'})!;
    expect((r.thap, r.cao), (1290000.0, 2140000.0),
        reason: 'đếm lại là đếm đôi với tầng 1 (hoá đơn, mục tiêu) và tầng 2');
  });

  test('khoản thu, khoản chuyển KHÔNG phải chi tuỳ ý', () {
    final them = [
      ...chinTuan(),
      _k(DateTime(2026, 10, 7), 5000000, loai: 'thu'),
      _k(DateTime(2026, 10, 8), 5000000, loai: 'transfer'),
    ];
    expect(tinh(them)!.cao, 2140000);
  });

  test('có ngân sách tổng → null', () {
    expect(tinh(chinTuan(), tong: true), isNull,
        reason: 'tầng 2 đã phủ mọi khoản chi — tầng 3 là đếm đôi');
  });

  test('không có chi tuỳ ý nào → null (không in "0 – 0")', () {
    expect(tinh([_k(DateTime(2026, 10, 7), 500000, camKet: true)]), isNull);
  });

  test('cửa sổ null (tài khoản quá trẻ) → null', () {
    expect(
        uocTinhChiTuyY(chinTuan(),
            now: now, cuaSo: null, danhMucCoNganSach: const {}, coNganSachTong: false),
        isNull);
  });

  test('⚠️ tuần vắt qua năm: 29/12/2025 – 4/1/2026 là MỘT tuần', () {
    final n = DateTime(2026, 2, 2, 10); // thứ Hai
    final cs = cuaSoNhinLai(n, DateTime(2025, 12, 29)); // tuần 1 ISO 2026
    final ds = [
      _k(DateTime(2025, 12, 30), 200000),
      _k(DateTime(2026, 1, 2), 300000), // cùng tuần với khoản trên
      for (final d in [
        DateTime(2026, 1, 7),
        DateTime(2026, 1, 14),
        DateTime(2026, 1, 21),
        DateTime(2026, 1, 28),
      ])
        _k(d, 500000),
    ];
    final r = uocTinhChiTuyY(ds,
        now: n, cuaSo: cs, danhMucCoNganSach: const {}, coNganSachTong: false)!;
    expect(r.soTuan, 5, reason: 'năm tuần đóng từ 29/12 tới 2/2; tách theo year là sáu mảnh');
    expect(r.thap, lamTronBuoc(500000 * 30 / 7, 10000),
        reason: 'năm tuần đều 500.000 (tuần đầu = 200k + 300k) → p25 = p75 = 500.000');
  });
}
