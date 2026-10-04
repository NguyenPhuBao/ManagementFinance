/// Mẫu nhịp chi dùng chung cho các ca test dự án C việc hai — CÙNG con số với bảng
/// mục 3.3 của spec `2026-10-04-du-an-c-nhip-chi-ngan-sach-design.md`. Tệp không
/// kết thúc bằng `_test.dart` nên `flutter test` không chạy nó.
library;

import 'package:flowmoney/features/budget/domain/nhip_chi.dart';

/// Mốc chung: trưa 06/11/2026 — đã qua 5,5/30 ngày của tháng 11 (x ≈ 0,1833).
final mocMau = DateTime(2026, 11, 6, 12);

KyChi kyThang(int nam, int thang, List<(int, double)> khoan) => KyChi(
      from: DateTime(nam, thang, 1),
      to: DateTime(nam, thang + 1, 1),
      khoan: [
        for (final (ngay, tien) in khoan)
          (ngay: DateTime(nam, thang, ngay), soTien: tien),
      ],
    );

/// Nhà ở: 4.000.000 ngày 1 + 200.000 các ngày 10, 20, 28 → 4.600.000 mỗi kỳ (8–10/2026).
List<KyChi> kyNhaO() => [
      for (final t in [8, 9, 10])
        kyThang(2026, t,
            [(1, 4000000), (10, 200000), (20, 200000), (28, 200000)]),
    ];

/// Ăn uống: 100.000 mỗi ngày từ ngày 1 tới 28 → 2.800.000 mỗi kỳ, chi đều.
List<KyChi> kyAnUong() => [
      for (final t in [8, 9, 10])
        kyThang(2026, t, [for (var n = 1; n <= 28; n++) (n, 100000)]),
    ];

/// Mua sắm: 300.000 các ngày 5, 12, 19, 26 → 1.200.000 mỗi kỳ.
List<KyChi> kyMuaSam() => [
      for (final t in [8, 9, 10])
        kyThang(
            2026, t, [(5, 300000), (12, 300000), (19, 300000), (26, 300000)]),
    ];

/// Giáo dục (tool ngân sách, now 22/09/2026 → x = 0,7): 90.000 ngày 5 + 10.000 ngày 25
/// → mọi khi tới x = 0,7 đã chi 90 % (6–8/2026).
List<KyChi> kyGiaoDuc() => [
      for (final t in [6, 7, 8]) kyThang(2026, t, [(5, 90000), (25, 10000)]),
    ];

NhipChi nhipNhaO() => hocNhipChi(kyNhaO())!;
NhipChi nhipAnUong() => hocNhipChi(kyAnUong())!;
NhipChi nhipMuaSam() => hocNhipChi(kyMuaSam())!;
NhipChi nhipGiaoDuc() => hocNhipChi(kyGiaoDuc())!;
