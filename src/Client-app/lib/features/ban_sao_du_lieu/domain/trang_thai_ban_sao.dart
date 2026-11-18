/// Trạng thái yêu cầu bản sao dữ liệu cá nhân (đơn client-app mục 52; spec 2026-11-16).
/// `chuaYeuCau` không đến từ chuỗi server — đó là `data: null` của `GET /latest`.
library;

enum TrangThaiBanSao { chuaYeuCau, dangTao, sanSang, hetHan, loi }

/// Chuỗi `status` của backend. Lạ / thiếu → [TrangThaiBanSao.loi]: cho người dùng yêu cầu lại (server tự chặn
/// bằng 429 nếu chưa đủ 24 giờ) thay vì khoá nút mãi ở "đang tạo".
TrangThaiBanSao trangThaiTuChuoi(String? s) {
  switch (s) {
    case 'PROCESSING':
      return TrangThaiBanSao.dangTao;
    case 'READY':
      return TrangThaiBanSao.sanSang;
    case 'EXPIRED':
      return TrangThaiBanSao.hetHan;
    default:
      return TrangThaiBanSao.loi;
  }
}

/// Thời gian còn phải chờ (từ `Retry-After`) → chữ. Làm tròn LÊN theo phút: báo ngắn hơn thật là người dùng
/// bấm lại và nhận thêm một lần 429.
String chuChoYeuCauLai(Duration d) {
  final giay = d.inSeconds;
  if (giay < 60) return 'dưới 1 phút';
  final phutTong = (giay + 59) ~/ 60;
  final gio = phutTong ~/ 60;
  final phut = phutTong % 60;
  if (gio == 0) return '$phut phút';
  if (phut == 0) return '$gio giờ';
  return '$gio giờ $phut phút';
}
