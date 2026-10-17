/// Cổng hỏi "hoá đơn mà khoản này trả cho đã xoá chưa" — việc 4c (spec
/// `docs/superpowers/specs/2026-10-17-chu-so-huu-khoan-tra-hoa-don-design.md` mục 3.2).
///
/// Khoản chi có `billId` mà hoá đơn đã xoá mềm (xoá kỳ đã trả qua màn xác nhận, hoặc xoá ở máy khác rồi kéo về) là
/// khoản **mồ côi**: nút Hoàn tác mất theo hoá đơn, nên sổ mở khoá có cảnh báo (`canhBaoXoaTaiSo`). Hỏi lúc thao tác
/// (vuốt / mở bảng chi tiết), không nạp sẵn bảng tra.
///
/// Mảng transaction chỉ khai cổng; DI truyền hàm đọc thật (`injection_container.dart`, điểm ghép) — không thêm cạnh
/// `transaction → bill` ở tầng nào (quét 29). Cùng khuôn `bill/data/so_ngay_nhac_nguon.dart`.
library;

import 'models/transaction_entity.dart';

class HoaDonDaXoaNguon {
  const HoaDonDaXoaNguon(this._doc);

  final Future<bool> Function(String billId) _doc;

  /// `true` chỉ khi hàng hoá đơn [billId] CÓ trên máy và đã xoá mềm. Không có hàng (chưa kéo về) hay kho lỗi →
  /// `false` = khoá: chưa biết thì không mở.
  Future<bool> daXoa(String billId) async {
    try {
      return await _doc(billId);
    } catch (_) {
      return false;
    }
  }
}

/// Phép hỏi chung của ba chỗ gọi (vuốt ở Sổ giao dịch, bảng chi tiết của Sổ và của Chi tiết ngân sách). Khoản không
/// gắn hoá đơn → `false` mà không đọc kho; trang chưa có cổng ([nguon] `null`) → `false`, khoá như cũ.
Future<bool> hoaDonDaXoaCua(
  TransactionEntity transaction,
  HoaDonDaXoaNguon? nguon,
) async {
  final billId = transaction.billId;
  if (billId == null || nguon == null) return false;
  return nguon.daXoa(billId);
}
