/// A5 mục 11 — tách MỘT khoản chi thành nhiều giao dịch theo danh mục (hoá đơn siêu thị nhiều món thuộc nhiều danh
/// mục). Hàm thuần.
///
/// Ô số tiền trên form vẫn là TỔNG; danh mục đang chọn trên form là phần CHÍNH và nhận `tổng − Σ các phần` — người
/// dùng không bao giờ bị kẹt vì cộng lệch (người dùng chốt 2026-10-08). Các phần không nối với nhau (không cột mới).
library;

import 'package:uuid/uuid.dart';

import '../data/models/transaction_entity.dart';
import 'khoang_tien.dart';

class PhanTach {
  const PhanTach({required this.categoryId, required this.soTien, this.monIds = const {}});

  final String categoryId;
  final double soTien;

  /// Món (`MonHang.id`) người dùng tick cho phần này; rỗng khi phần nhập số tay.
  final Set<int> monIds;

  PhanTach copyWith({String? categoryId, double? soTien, Set<int>? monIds}) => PhanTach(
        categoryId: categoryId ?? this.categoryId,
        soTien: soTien ?? this.soTien,
        monIds: monIds ?? this.monIds,
      );
}

enum LoiTach { conLaiKhongDuong, phanKhongDuong, trungDanhMuc, monHaiPhan }

double conLai(double tong, List<PhanTach> phan) => phan.fold(tong, (s, p) => s - p.soTien);

/// `null` = hợp lệ. Ngưỡng nửa đồng ([kDungSaiTien]) vì `amount` là `double`.
LoiTach? kiemTach({required double tong, required String? chinh, required List<PhanTach> phan}) {
  if (phan.any((p) => p.soTien <= kDungSaiTien)) return LoiTach.phanKhongDuong;
  final dm = [if (chinh != null) chinh, ...phan.map((p) => p.categoryId)];
  if (dm.toSet().length != dm.length) return LoiTach.trungDanhMuc;
  final mon = [for (final p in phan) ...p.monIds];
  if (mon.toSet().length != mon.length) return LoiTach.monHaiPhan;
  if (conLai(tong, phan) <= kDungSaiTien) return LoiTach.conLaiKhongDuong;
  return null;
}

/// Đổi danh mục chính sang một danh mục đang tách → phần ấy GỘP vào phần chính (bỏ dòng ấy).
List<PhanTach> gopKhiDoiDanhMucChinh(String chinhMoi, List<PhanTach> phan) =>
    [for (final p in phan) if (p.categoryId != chinhMoi) p];

/// [mau] là giao dịch form dựng như khi không tách (tổng, danh mục chính, ví, ngày, ghi chú). Trả phần CHÍNH đứng đầu,
/// mỗi hàng một id mới.
List<TransactionEntity> dungGiaoDichTach({
  required TransactionEntity mau,
  required List<PhanTach> phan,
  String Function()? taoId,
}) {
  final id = taoId ?? () => const Uuid().v4();
  return [
    mau.copyWith(id: id(), amount: conLai(mau.amount, phan)),
    for (final p in phan) mau.copyWith(id: id(), categoryId: p.categoryId, amount: p.soTien),
  ];
}
