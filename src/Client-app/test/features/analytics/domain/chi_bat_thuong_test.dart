/// Chi bất thường theo danh mục (B3) — trung vị + MAD, z hiệu chỉnh > 3,5 và
/// phần vượt > ngưỡng có nghĩa. Spec
/// docs/superpowers/specs/2026-09-28-b3-chi-bat-thuong-theo-danh-muc-design.md §2.
library;

import 'package:flowmoney/features/analytics/domain/chi_bat_thuong.dart';
import 'package:flowmoney/features/analytics/domain/thong_ke_thang.dart';
import 'package:flutter_test/flutter_test.dart';

KhoanThuChi _k(
  DateTime ngay,
  double tien, {
  String cat = 'an',
  String loai = 'chi',
  String? classify = 'chi',
  String? ghiChu,
}) =>
    KhoanThuChi(
      ngay: ngay,
      soTien: tien,
      loai: loai,
      categoryId: cat,
      classify: classify,
      ghiChu: ghiChu,
    );

void main() {
  // Sáu tháng Ăn uống (3/2026 → 8/2026) quanh 900.000, tháng xét 9/2026.
  List<KhoanThuChi> lichSu({String cat = 'an'}) => [
        for (final (m, v) in [
          (3, 850000.0),
          (4, 900000.0),
          (5, 950000.0),
          (6, 880000.0),
          (7, 920000.0),
          (8, 900000.0),
        ])
          _k(DateTime(2026, m, 10), v, cat: cat),
      ];
  final now = DateTime(2026, 9, 28);
  final thang = DateTime(2026, 9, 1);

  test('tháng xét 2.400.000 → bất thường, thường lệ = trung vị 900.000', () {
    final r = chiBatThuong([...lichSu(), _k(DateTime(2026, 9, 5), 2400000)],
        thang: thang, now: now, nguong: 50000);
    expect(r.single.categoryId, 'an');
    expect(r.single.chi, 2400000);
    expect(r.single.thuongLe, 900000);
    expect(r.single.soThangMau, 6);
    expect(r.single.vuot, 1500000);
  });

  test('tháng xét 990.000 → không (z ≈ 3,0); 1.100.000 → CÓ (z ≈ 6,7)', () {
    // Lịch sử rất đều: trung vị 900.000, MAD 20.000. Tính tay:
    // 990k → 0,6745 × 90k / 20k ≈ 3,04 ≤ 3,5; 1,1M → 0,6745 × 200k / 20k ≈ 6,7.
    expect(
        chiBatThuong([...lichSu(), _k(DateTime(2026, 9, 5), 990000)],
            thang: thang, now: now, nguong: 50000),
        isEmpty);
    expect(
        chiBatThuong([...lichSu(), _k(DateTime(2026, 9, 5), 1100000)],
            thang: thang, now: now, nguong: 50000),
        hasLength(1),
        reason: 'lịch sử càng đều thì lệch 22 % càng lạ — đúng tinh thần MAD, không phải lỗi');
  });

  test('chỉ 3 tháng lịch sử → im', () {
    final ls = lichSu().sublist(3);
    expect(
        chiBatThuong([...ls, _k(DateTime(2026, 9, 5), 5000000)],
            thang: thang, now: now, nguong: 50000),
        isEmpty,
        reason: 'cần ≥ 4 tháng đã đóng có phát sinh — thiếu mẫu thì im hẳn (lo ngại của 17/09)');
  });

  test('tháng 0 đồng KHÔNG vào mẫu (danh mục chi thưa)', () {
    // Du lịch: 4 tháng có chi (2,8 / 3,0 / 3,2 / 3,0 triệu), xen kẽ tháng không chi.
    // Mẫu có phát sinh: trung vị 3,0M, MAD 100k → 3,1M có z ≈ 0,67.
    // Nếu tính cả tháng 0 trong cửa sổ 12 tháng thì trung vị 0 → 3,1M thành bất thường.
    final ds = [
      for (final (m, v) in [(2, 2800000.0), (4, 3000000.0), (6, 3200000.0), (8, 3000000.0)])
        _k(DateTime(2026, m, 1), v, cat: 'dl'),
      _k(DateTime(2026, 9, 3), 3100000, cat: 'dl'),
    ];
    expect(chiBatThuong(ds, thang: thang, now: now, nguong: 50000), isEmpty,
        reason: 'tính tháng 0 thì trung vị 0 và 3.100.000 thành bất thường');
  });

  test('MAD = 0 và độ lệch trung bình = 0 → z = +∞, chỉ vế tiền quyết', () {
    final ds = [
      for (final m in [5, 6, 7, 8]) _k(DateTime(2026, m, 10), 500000, cat: 'net'),
      _k(DateTime(2026, 9, 10), 800000, cat: 'net'),
    ];
    expect(chiBatThuong(ds, thang: thang, now: now, nguong: 50000), hasLength(1));
    expect(chiBatThuong(ds, thang: thang, now: now, nguong: 400000), isEmpty,
        reason: 'vượt 300.000 < ngưỡng 400.000 → vế tiền chặn');
  });

  test('MAD = 0 nhưng độ lệch trung bình > 0 → nhánh Iglewicz–Hoaglin (meanAd)', () {
    // 500k ×3 và 700k: trung vị 500k, MAD 0, meanAd = 200k / 4 = 50k.
    // x = 600k → z = 100k / (1,2533 × 50k) ≈ 1,6 → không; x = 800k → z ≈ 4,8 → có.
    List<KhoanThuChi> ds(double x) => [
          for (final (m, v) in [(5, 500000.0), (6, 500000.0), (7, 500000.0), (8, 700000.0)])
            _k(DateTime(2026, m, 10), v, cat: 'net'),
          _k(DateTime(2026, 9, 10), x, cat: 'net'),
        ];
    expect(chiBatThuong(ds(600000), thang: thang, now: now, nguong: 50000), isEmpty);
    expect(chiBatThuong(ds(800000), thang: thang, now: now, nguong: 50000), hasLength(1));
  });

  test('khoản chuyển / điều chỉnh số dư / vay-nợ không vào chuỗi', () {
    final ds = [
      ...lichSu(),
      _k(DateTime(2026, 9, 5), 5000000, loai: 'transfer'),
      _k(DateTime(2026, 9, 6), 5000000, classify: 'vay_no'),
      // Khoản điều chỉnh số dư thật KHÔNG có danh mục (`laKhoanDieuChinh` đòi
      // cặp dấu hiệu) nên đã bị bỏ ở vế "không danh mục" — xem ca riêng dưới.
      // Gắn danh mục cho nó là thành khoản người dùng tự gõ, được tính đúng.
    ];
    expect(chiBatThuong(ds, thang: thang, now: now, nguong: 50000), isEmpty);
  });

  test('tháng đang chạy chỉ tính khoản TỚI now', () {
    final ds = [...lichSu(), _k(DateTime(2026, 9, 5), 900000), _k(DateTime(2026, 9, 29), 3000000)];
    expect(chiBatThuong(ds, thang: thang, now: now, nguong: 50000), isEmpty,
        reason: 'khoản 29/9 ở sau now 28/9');
  });

  test('xem THÁNG ĐÃ QUA: lịch sử là các tháng TRƯỚC nó, tháng sau không tính', () {
    final ds = [...lichSu(), _k(DateTime(2026, 9, 5), 9000000)];
    final r = chiBatThuong(ds, thang: DateTime(2026, 8, 1), now: now, nguong: 50000);
    expect(r, isEmpty,
        reason: 'tháng 8 là 900.000 bình thường; tháng 9 KHÔNG thuộc lịch sử của tháng 8');
  });

  test('biên đầu cửa sổ: tháng thứ 13 về trước KHÔNG vào mẫu, kể cả ngày cuối của nó', () {
    // Tháng xét 9/2026 → lịch sử 9/2025 … 8/2026. Ba tháng trong cửa sổ + một
    // khoản ngày 31/8/2025 (sát trước biên) → chỉ 3 tháng mẫu → im.
    final ds = [
      for (final m in [6, 7, 8]) _k(DateTime(2026, m, 10), 900000),
      _k(DateTime(2025, 8, 31), 900000),
      _k(DateTime(2026, 9, 5), 5000000),
    ];
    expect(chiBatThuong(ds, thang: thang, now: now, nguong: 50000), isEmpty,
        reason: 'cửa sổ tối đa 12 tháng đã đóng — lệch biên một ngày là tháng thứ 13 lọt vào mẫu');
  });

  test('biên cuối: tháng SAU tháng đang xem không bao giờ vào lịch sử', () {
    // Xem tháng 8: lịch sử 5–7 (3 tháng) → im. Khoản 5/9 (≤ now) mà lọt vào
    // lịch sử thì thành 4 tháng và tháng 8 bị gắn cờ.
    final ds = [
      for (final m in [5, 6, 7]) _k(DateTime(2026, m, 10), 900000),
      _k(DateTime(2026, 8, 10), 3000000),
      _k(DateTime(2026, 9, 5), 900000),
    ];
    expect(chiBatThuong(ds, thang: DateTime(2026, 8, 1), now: now, nguong: 50000), isEmpty);
  });

  test('xếp theo phần vượt giảm dần', () {
    final ds = [
      ...lichSu(cat: 'an'),
      _k(DateTime(2026, 9, 5), 2400000, cat: 'an'),
      ...lichSu(cat: 'ms'),
      _k(DateTime(2026, 9, 5), 4000000, cat: 'ms'),
    ];
    expect(chiBatThuong(ds, thang: thang, now: now, nguong: 50000).map((e) => e.categoryId),
        ['ms', 'an']);
  });

  test('khoản không danh mục bị bỏ qua (không có danh mục để nói)', () {
    final ds = [
      for (final m in [4, 5, 6, 7, 8])
        KhoanThuChi(ngay: DateTime(2026, m, 10), soTien: 900000, loai: 'chi', categoryId: null),
      KhoanThuChi(ngay: DateTime(2026, 9, 5), soTien: 5000000, loai: 'chi', categoryId: null),
    ];
    expect(chiBatThuong(ds, thang: thang, now: now, nguong: 50000), isEmpty);
  });

  test('tháng 1 lùi lịch sử qua năm trước; tháng 3 năm nhuận không lệch biên', () {
    final ds = [
      for (final m in [8, 9, 10, 11, 12]) _k(DateTime(2027, m, 10), 900000),
      _k(DateTime(2028, 1, 31), 3000000),
    ];
    expect(
        chiBatThuong(ds,
            thang: DateTime(2028, 1, 1), now: DateTime(2028, 1, 31, 12), nguong: 50000),
        hasLength(1));
    final ds2 = [
      for (final m in [10, 11, 12]) _k(DateTime(2027, m, 10), 900000),
      _k(DateTime(2028, 2, 29), 900000), // năm nhuận, ngày cuối tháng 2
      _k(DateTime(2028, 3, 1), 3000000),
    ];
    final r2 =
        chiBatThuong(ds2, thang: DateTime(2028, 3, 1), now: DateTime(2028, 3, 20), nguong: 50000);
    expect(r2.single.soThangMau, 4, reason: '29/2 thuộc tháng 2, không rơi sang tháng 3');
  });
}
