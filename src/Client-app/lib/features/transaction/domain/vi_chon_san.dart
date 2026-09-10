/// Ví được chọn sẵn khi mở trang thêm giao dịch.
///
/// [nguon] là ví ghi khoản thu/chi; [dich] chỉ dùng cho khoản chuyển tiền.
class ViChonSan<T> {
  const ViChonSan({required this.nguon, required this.dich});

  final T? nguon;
  final T? dich;
}

/// Chọn sẵn ví nguồn và ví đích từ [danhSach].
///
/// Ví nguồn là ví mang cờ mặc định; không có thì lấy ví đầu danh sách. Trước
/// bản này trang thêm giao dịch lấy `_wallets.first` vô điều kiện, mà
/// `WalletDao.getAll` sắp theo `updatedAt` giảm dần — nên ví chọn sẵn là ví
/// **vừa bị đổi gần nhất**, không phải ví mặc định. Cờ mặc định có mục đích duy
/// nhất là chỗ này (thiết kế Stitch ghi phụ đề "Tự động chọn khi ghi chép giao
/// dịch"), và ngoài vùng ví thì `getDefault` không được gọi ở đâu trong `lib/`.
///
/// Ví đích là ví **khác** ví nguồn, không phải ví ở chỉ số 1. Luật cũ dùng chỉ
/// số 1 cứng; giữ nó lại khi ví nguồn đã đổi sẽ cho khoản chuyển tiền có ví
/// nguồn trùng ví đích ngay khi ví mặc định nằm ở giữa danh sách.
///
/// Danh sách một ví thì đích trùng nguồn — hành vi cũ, cố ý giữ: trang thêm
/// giao dịch tự chặn khoản chuyển khi chưa có đủ hai ví.
///
/// Hàm thuần, không import Flutter lẫn Drift, nên nhận [laMacDinh] thay vì biết
/// về kiểu ví cụ thể. Nhờ vậy luật test được mà không phải dựng cả trang.
ViChonSan<T> chonViChonSan<T>(
  List<T> danhSach, {
  required bool Function(T) laMacDinh,
}) {
  if (danhSach.isEmpty) return ViChonSan<T>(nguon: null, dich: null);

  final viTriMacDinh = danhSach.indexWhere(laMacDinh);
  final viTriNguon = viTriMacDinh >= 0 ? viTriMacDinh : 0;
  // Ví đầu tiên KHÁC ví nguồn. So bằng chỉ số chứ không bằng `==` để không phụ
  // thuộc vào phép so sánh của kiểu ví được truyền vào.
  final viTriDich =
      danhSach.length == 1 ? viTriNguon : (viTriNguon == 0 ? 1 : 0);

  return ViChonSan<T>(
    nguon: danhSach[viTriNguon],
    dich: danhSach[viTriDich],
  );
}
