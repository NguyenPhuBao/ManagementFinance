/// Cổng hỏi "nửa RIÊNG này của khoản góp / rút còn cặp để giữ khớp không" (đợt 1B Task 9, `docs/Family/02A` mục 6).
///
/// Sổ giao dịch và Chi tiết ngân sách sửa, xoá từng hàng. Nửa riêng của khoản góp, rút mà sửa hay xoá MỘT mình thì hai nửa
/// lệch nhau (quỹ một số, ví riêng một số khác), nên khi cổng nhận ra cặp, hai trang dẫn người dùng sang đường đi theo cả
/// cặp (`/nha/gop`, `GopQuyService.xoa`). Đã rời nhà (không còn nửa nhà) thì nửa riêng là khoản thường: cổng trả `null`.
///
/// Mảng transaction chỉ khai cổng; DI truyền hàm đọc thật (`injection_container.dart`, điểm ghép) — không thêm cạnh
/// `transaction → household` ở tầng nào (quét 29). Cùng khuôn `HoaDonDaXoaNguon`.
library;

import 'models/transaction_entity.dart';

class CapGopQuy {
  const CapGopQuy({required this.maCap, required this.laGop, required this.cauXoa, required this.choThaoTac});

  final String maCap;

  /// `true` là khoản góp (nửa riêng là chi), `false` là khoản rút.
  final bool laGop;

  /// Câu hộp xoá, DI dựng bằng `cauXoaKhoanGop` (transaction không import household).
  final String cauXoa;

  /// Nhà đang cho ghi (`ViecNha.ghiKhoan`). `false` (nhà chỉ xem, hoặc vai Chỉ xem): ẩn Sửa và Xoá của nửa riêng, vì server
  /// từ chối nửa nhà.
  final bool choThaoTac;

  /// Màn sửa theo cả cặp (route `/nha/gop`, đợt 1B Task 8): `ma` = mã cặp (chiều lấy theo nửa của nhà), `che` chỉ để dự
  /// phòng khi route bỏ qua `ma`.
  String get duongSua => '/nha/gop?ma=${Uri.encodeQueryComponent(maCap)}&che=${laGop ? 'gop' : 'rut'}';
}

class CapGopQuyNguon {
  const CapGopQuyNguon({
    required Future<CapGopQuy?> Function(TransactionEntity) doc,
    required Future<void> Function(String maCap) xoa,
  })  : _doc = doc,
        _xoa = xoa;

  final Future<CapGopQuy?> Function(TransactionEntity) _doc;
  final Future<void> Function(String maCap) _xoa;

  /// `null` = khoản thường. Lỗi đọc cũng `null`: khoản đi đường thường, server không biết cặp nên lệch sẽ không tệ hơn
  /// trước khi có cổng.
  Future<CapGopQuy?> cua(TransactionEntity t) async {
    try {
      return await _doc(t);
    } catch (_) {
      return null;
    }
  }

  /// Xoá CẢ HAI nửa. Ném tiếp khi hàm xoá ném: trang báo lỗi, không nuốt.
  Future<void> xoaCap(String maCap) => _xoa(maCap);
}
