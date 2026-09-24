/// Lời từ chối tham số của mọi tool — chỗ DUY NHẤT dựng lời từ chối (spec bước
/// 2b mục 2.1). Mỗi hàm `tuChoi…` trả `KetQuaCongCu` mang đủ: câu cho mô hình
/// (`loi` — đủ để nó gọi lại đúng ngay lần sau), câu cho NGƯỜI DÙNG
/// (`choNguoiDung`), tham số gỡ (`thamSoGo`) và tên liên quan.
///
/// ⚠️ Lượt bị từ chối KHÔNG còn tính là đã tra cứu, và vẫn tốn một suất trong
/// trần 3 (bước 2b lật vế ấy của chốt L1, spec 4b mục 3.6): cổng D lần 1 đo được
/// E2B đọc lời từ chối thành "không có dữ liệu" (bẫy 4.40).
///
/// Ba luật cho câu người dùng: không lộ mã tham số, không chép số từ tham số của
/// mô hình (chỉ nhắc lại TÊN), không khẳng định gì về giao dịch hay dữ liệu.
library;

import 'hang_so_lieu.dart';

/// Câu cho MÔ HÌNH khi một tham số enum nhận giá trị lạ.
String loiGiaTri(String thamSo, Object? giaTri, Iterable<String> hopLe) =>
    '$thamSo "$giaTri" không hợp lệ. Chỉ nhận: ${hopLe.join(', ')}.';

/// Câu cho người dùng theo tham số enum — không lộ mã.
const Map<String, String> _chuaHieu = {
  'ky': 'chưa hiểu khoảng thời gian trong câu hỏi',
  'chieu': 'chưa hiểu loại giao dịch',
  'sap_xep': 'chưa hiểu cách sắp xếp',
  'trang_thai': 'chưa hiểu trạng thái hoá đơn',
};

const String _chuaHieuSoTien = 'chưa hiểu số tiền trong câu hỏi';

KetQuaCongCu tuChoiGiaTri(String thamSo, Object? giaTri, Iterable<String> hopLe) =>
    KetQuaCongCu.loi(
      loiGiaTri(thamSo, giaTri, hopLe),
      choNguoiDung: _chuaHieu[thamSo] ?? 'chưa hiểu một phần câu hỏi',
      thamSoGo: [thamSo],
    );

KetQuaCongCu tuChoiSoTien(String thamSo, Object? giaTri) => KetQuaCongCu.loi(
      '$thamSo "$giaTri" phải là số đồng, ví dụ 500000.',
      choNguoiDung: _chuaHieuSoTien,
      thamSoGo: [thamSo],
    );

/// [tu], [den] là số đồng in thô — đúng dạng mô hình vừa gửi.
KetQuaCongCu tuChoiKhoangNguoc(String tu, String den) => KetQuaCongCu.loi(
      'so_tien_tu ($tu) lớn hơn so_tien_den ($den). Gọi lại với khoảng đúng chiều.',
      choNguoiDung: 'khoảng số tiền bị ngược',
      thamSoGo: const ['so_tien_tu', 'so_tien_den'],
    );

/// Số tiền nằm nhầm trong `tu_khoa` (bước 2b, bẫy 4.43). Gỡ khi lượt sau điền
/// `so_tien_tu` hoặc `so_tien_den` — tức mô hình đã dời số tiền về đúng chỗ.
KetQuaCongCu tuChoiTuKhoaLaSoTien(String giaTri) => KetQuaCongCu.loi(
      'tu_khoa "$giaTri" là số tiền — tu_khoa chỉ tìm chữ trong ghi chú; số tiền '
      'dùng so_tien_tu / so_tien_den, số đồng, ví dụ 500000.',
      choNguoiDung: _chuaHieuSoTien,
      thamSoGo: const ['so_tien_tu', 'so_tien_den'],
    );

/// [loai]: chữ người đọc được của tham số — 'danh mục' · 'ví' · 'danh mục chi'.
KetQuaCongCu tuChoiKhongKhop(
  String thamSo,
  String hoi,
  List<String> tenCo, {
  required String loai,
}) =>
    KetQuaCongCu.loi(
      '$thamSo "$hoi" không khớp tên nào. Chỉ có: ${tenCo.join(', ')}.',
      choNguoiDung: 'không có $loai nào tên "$hoi"',
      thamSoGo: [thamSo],
      tenLienQuan: [...tenCo, hoi],
    );

KetQuaCongCu tuChoiKhopNhieu(
  String thamSo,
  String hoi,
  List<String> tenKhop, {
  required String loai,
}) =>
    KetQuaCongCu.loi(
      '$thamSo "$hoi" khớp nhiều tên: ${tenKhop.join(', ')}. '
      'Gọi lại với đúng một tên.',
      choNguoiDung: 'tên "$hoi" khớp nhiều $loai: ${tenKhop.join(', ')}',
      thamSoGo: [thamSo],
      tenLienQuan: [...tenKhop, hoi],
    );
