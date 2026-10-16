/// Mẫu học cho hai bộ gợi ý danh mục, dựng từ hàng sổ giao dịch — B1 (ghi chú, `category/domain/phan_loai_ghi_chu.dart`)
/// và dự án C (số tiền, `category/domain/phan_loai_so_tien.dart`). Hàm thuần.
///
/// Tách khỏi hai tệp mô hình 2026-10-16 (quét 29, spec `2026-10-16-go-vong-mang-domain-design.md`): bộ lọc mẫu đọc
/// luật của hàng sổ ([laGhiChuMay]) nên nằm ở mảng giao dịch; mô hình chỉ nhận mẫu nên ở lại category.
library;

import '../../category/domain/phan_loai_ghi_chu.dart';
import '../../category/domain/phan_loai_so_tien.dart';
import 'khoan_vao_thong_ke.dart';

/// Mẫu có nhãn: giao dịch có danh mục, ghi chú người dùng gõ, còn ít nhất một âm tiết.
List<MauGhiChu> mauHocTu(
        Iterable<({String loai, String? categoryId, String? ghiChu, DateTime ngay})> giaoDich) =>
    [
      for (final t in giaoDich)
        if (t.categoryId != null &&
            !laGhiChuMay(loai: t.loai, categoryId: t.categoryId, ghiChu: t.ghiChu))
          if (amTietCua(t.ghiChu ?? '') case final a when a.isNotEmpty)
            MauGhiChu(categoryId: t.categoryId!, amTiet: a, ngay: t.ngay),
    ];

/// Mẫu có nhãn: khoản thu / chi có danh mục, chưa xoá, số tiền dương, không do máy sinh (`laGhiChuMay` của B1 — trả
/// hoá đơn, nạp / rút mục tiêu, điều chỉnh số dư, số dư ban đầu). Có hay không có ghi chú đều tính — khác `mauHocTu`
/// của B1 ở đúng chỗ ấy: tín hiệu ở đây là số tiền, không phải chữ.
List<MauSoTien> mauSoTienTu(
        Iterable<
                ({
                  String loai,
                  String? categoryId,
                  String? ghiChu,
                  double soTien,
                  String walletId,
                  DateTime ngay,
                  bool daXoa
                })>
            giaoDich) =>
    [
      for (final t in giaoDich)
        if (!t.daXoa &&
            t.categoryId != null &&
            (t.loai == 'thu' || t.loai == 'chi') &&
            t.soTien > 0 &&
            !laGhiChuMay(loai: t.loai, categoryId: t.categoryId, ghiChu: t.ghiChu))
          MauSoTien(
            categoryId: t.categoryId!,
            chieu: t.loai,
            maBac: maBacCua(bacTienCua(t.soTien)),
            nhomThu: nhomThuCua(t.ngay),
            walletId: t.walletId,
            ngay: t.ngay,
          ),
    ];
