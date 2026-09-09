/// Tầng thuần của trang **Xuất báo cáo**: từ bộ lọc người dùng chọn ra một
/// [BaoCao] đầy đủ cho màn Xem trước.
///
/// Tách khỏi widget vì cùng lý do với `thong_ke_thang.dart`: trang này từng là
/// **số cứng** (ví "Techcombank" bịa, lịch sử xuất bịa), và lớp lỗi thay thế nó
/// hỏng **im lặng** — một khoản rơi khỏi khoảng vì biên đóng/mở, một khoản
/// chuyển ví bị đếm thành chi tiêu, một quý bị cắt còn hai tháng.
///
/// Mọi luật **đếm tiền** ở đây mượn nguyên `thong_ke_thang.dart` (biên
/// `[from, to)`, `'transfer'` không phải thu cũng không phải chi, cách gom và
/// sắp danh mục). Đừng viết lại biến thể khác: hai trang cùng nói về một tháng
/// mà ra hai con số là lỗi khó thấy nhất trong app này.
library;

import 'thong_ke_thang.dart';

export 'thong_ke_thang.dart' show TongThuChi;

/// Phạm vi thời gian trên trang Xuất báo cáo — đúng bốn nút của màn Stitch.
enum PhamViThoiGian { thangNay, thangTruoc, quyNay, tuyChinh }

/// Biên `[from, to)` ứng với [pv].
///
/// [tuyChon] là khoảng người dùng chọn từ bộ chọn ngày, **cả hai đầu là ngày**
/// (00:00). Biên `to` trả về đã cộng thêm một ngày để ngày cuối cùng người dùng
/// chọn nằm TRONG báo cáo — lấy thẳng `tuyChon.to` là mất trọn ngày ấy.
///
/// [tuyChon] `null` khi người dùng bấm "Tuỳ chỉnh" rồi thoát bộ chọn; khi ấy
/// lùi về tháng này thay vì nổ.
({DateTime from, DateTime to}) khoangCuaPhamVi(
  PhamViThoiGian pv, {
  required DateTime now,
  ({DateTime from, DateTime to})? tuyChon,
}) {
  switch (pv) {
    case PhamViThoiGian.thangNay:
      return bienThang(now.year, now.month);
    case PhamViThoiGian.thangTruoc:
      // `month - 1` bằng 0 tự cuộn về tháng 12 năm trước nhờ `DateTime`.
      return bienThang(now.year, now.month - 1);
    case PhamViThoiGian.quyNay:
      final thangDauQuy = ((now.month - 1) ~/ 3) * 3 + 1;
      return (
        from: DateTime(now.year, thangDauQuy, 1),
        to: DateTime(now.year, thangDauQuy + 3, 1),
      );
    case PhamViThoiGian.tuyChinh:
      if (tuyChon == null) return bienThang(now.year, now.month);
      final t = tuyChon.to;
      return (
        from: DateTime(tuyChon.from.year, tuyChon.from.month, tuyChon.from.day),
        // `day + 1` tự cuộn qua cuối tháng, cuối năm và 29/02 năm nhuận.
        to: DateTime(t.year, t.month, t.day + 1),
      );
  }
}

/// Bộ lọc của một báo cáo. [walletId]/[categoryId] `null` nghĩa là **tất cả**.
class LocBaoCao {
  final DateTime from;
  final DateTime to;
  final String? walletId;
  final String? categoryId;

  const LocBaoCao({
    required this.from,
    required this.to,
    this.walletId,
    this.categoryId,
  });
}

/// Một giao dịch đã tra sẵn tên ví và tên danh mục.
///
/// Việc tra tên nằm ở repository chứ không ở đây, để tầng này kiểm được bằng
/// danh sách thuần, không cần CSDL.
class DongGiaoDich {
  final String id;
  final DateTime ngay;
  final double soTien;

  /// `'thu'`, `'chi'` hoặc `'transfer'` — giá trị cuối bị loại khỏi báo cáo.
  final String loai;

  /// `null` là khoản chưa phân loại; [tenDanhMuc] khi ấy là nhãn thay thế.
  final String? categoryId;
  final String tenDanhMuc;

  /// Mã màu `#RRGGBB` và tên biểu tượng như lưu ở cột `colour`/`icon`. Giữ
  /// chuỗi để tầng này không kéo `material.dart` vào.
  final String? mauHex;
  final String? icon;

  final String walletId;
  final String tenVi;

  /// Dòng chữ chính của giao dịch: ghi chú, hoặc tên danh mục khi không ghi chú.
  final String tieuDe;

  const DongGiaoDich({
    required this.id,
    required this.ngay,
    required this.soTien,
    required this.loai,
    required this.categoryId,
    required this.tenDanhMuc,
    required this.mauHex,
    required this.icon,
    required this.walletId,
    required this.tenVi,
    required this.tieuDe,
  });
}

/// Một dòng của bảng "Chi theo danh mục" trên màn Xem trước.
class DongDanhMucBaoCao {
  final String? categoryId;
  final String ten;
  final String? mauHex;
  final String? icon;
  final double soTien;

  /// Tỉ lệ trên **tổng chi** của báo cáo, trong `[0, 1]`.
  final double tiLe;

  const DongDanhMucBaoCao({
    required this.categoryId,
    required this.ten,
    required this.mauHex,
    required this.icon,
    required this.soTien,
    required this.tiLe,
  });
}

/// Các giao dịch của cùng một ngày, dưới một tiêu đề ngày.
class NhomNgay {
  /// Ngày đã cắt về 00:00 — khoá gom nhóm.
  final DateTime ngay;
  final List<DongGiaoDich> dong;

  const NhomNgay({required this.ngay, required this.dong});
}

/// Toàn bộ nội dung màn Xem trước báo cáo.
class BaoCao {
  final DateTime from;
  final DateTime to;
  final TongThuChi tong;
  final List<DongDanhMucBaoCao> theoDanhMuc;

  /// Giao dịch gom theo ngày, **mới nhất trước**.
  final List<NhomNgay> nhom;

  final int soGiaoDich;

  const BaoCao({
    required this.from,
    required this.to,
    required this.tong,
    required this.theoDanhMuc,
    required this.nhom,
    required this.soGiaoDich,
  });

  /// Không giao dịch nào lọt bộ lọc. Màn hình nói rỗng thay vì vẽ toàn số 0.
  bool get rong => soGiaoDich == 0;
}

/// Dựng báo cáo từ [ds] theo [loc].
///
/// `'transfer'` bị loại **khỏi cả danh sách**, không chỉ khỏi tổng: để nó lại
/// thì ba thẻ tổng ở đầu trang không cộng ra được các dòng bên dưới.
BaoCao dungBaoCao(List<DongGiaoDich> ds, {required LocBaoCao loc}) {
  final loc0 = <DongGiaoDich>[
    for (final d in ds)
      if (d.loai != 'transfer' &&
          !d.ngay.isBefore(loc.from) &&
          d.ngay.isBefore(loc.to) &&
          (loc.walletId == null || d.walletId == loc.walletId) &&
          (loc.categoryId == null || d.categoryId == loc.categoryId))
        d,
  ];

  final khoan = [
    for (final d in loc0)
      KhoanThuChi(
        ngay: d.ngay,
        soTien: d.soTien,
        loai: d.loai,
        categoryId: d.categoryId,
      ),
  ];

  // Tên/màu/biểu tượng của một danh mục lấy từ dòng đầu gặp được: mọi dòng
  // cùng `categoryId` đều mang cùng bộ ấy, do repository tra một lần.
  final nhan = <String?, DongGiaoDich>{};
  for (final d in loc0) {
    nhan.putIfAbsent(d.categoryId, () => d);
  }

  final theoDanhMuc = [
    for (final c in chiTheoDanhMuc(khoan, from: loc.from, to: loc.to))
      DongDanhMucBaoCao(
        categoryId: c.categoryId,
        ten: nhan[c.categoryId]?.tenDanhMuc ?? 'Chưa phân loại',
        mauHex: nhan[c.categoryId]?.mauHex,
        icon: nhan[c.categoryId]?.icon,
        soTien: c.soTien,
        tiLe: c.tiLe,
      ),
  ];

  final gom = <DateTime, List<DongGiaoDich>>{};
  for (final d in loc0) {
    final ngay = DateTime(d.ngay.year, d.ngay.month, d.ngay.day);
    (gom[ngay] ??= []).add(d);
  }
  final nhom = [
    for (final ngay in gom.keys.toList()..sort((a, b) => b.compareTo(a)))
      NhomNgay(
        ngay: ngay,
        dong: gom[ngay]!..sort((a, b) => b.ngay.compareTo(a.ngay)),
      ),
  ];

  return BaoCao(
    from: loc.from,
    to: loc.to,
    tong: tongThuChi(khoan, from: loc.from, to: loc.to),
    theoDanhMuc: theoDanhMuc,
    nhom: nhom,
    soGiaoDich: loc0.length,
  );
}
