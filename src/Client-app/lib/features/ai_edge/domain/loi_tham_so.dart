/// Lời từ chối tham số của mọi tool — chỗ DUY NHẤT dựng lời từ chối (spec bước
/// 2b mục 2.1). Mỗi hàm `tuChoi…` trả `KetQuaCongCu` mang đủ: câu cho mô hình
/// (`loi` — đủ để nó gọi lại đúng ngay lần sau), câu cho NGƯỜI DÙNG
/// (`choNguoiDung`), tham số gỡ (`thamSoGo`) và tên liên quan.
///
/// ⚠️ Lượt bị từ chối KHÔNG còn tính là đã tra cứu, và vẫn tốn một suất trong
/// trần 3 (bước 2b lật vế ấy của chốt L1, spec 4b mục 3.6): cổng D lần 1 đo được
/// E2B đọc lời từ chối thành "không có dữ liệu" (bẫy 4.40).
///
/// Ba luật cho câu người dùng: không lộ mã tham số (và không có `_` kể cả trong
/// tên mô hình gõ — bước 2c), không chép số từ tham số của mô hình (chỉ nhắc
/// lại TÊN), không khẳng định gì về giao dịch hay dữ liệu.
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
  'so_voi': 'chưa hiểu kỳ cần so sánh',
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

/// Hai mốc của `ky=tuy_chon` thiếu, sai dạng, không tồn tại trên lịch, hoặc
/// ngược (spec mở rộng tool §3.1) — không tự cuộn 31/6 sang 1/7, không tự hoán
/// đổi. ⚠️ Câu cho người dùng KHÔNG chép hai mốc: chúng là số của mô hình.
KetQuaCongCu tuChoiKhoangNgay(Object? tu, Object? den) => KetQuaCongCu.loi(
      'ky tuy_chon cần tu_ngay và den_ngay dạng dd/mm/yyyy, ngày có thật, tu_ngay '
      'không sau den_ngay; nhận: "${tu ?? ''}" – "${den ?? ''}".',
      choNguoiDung: 'chưa hiểu khoảng ngày trong câu hỏi',
      thamSoGo: const ['tu_ngay', 'den_ngay'],
    );

/// Câu hỏi nêu một kỳ CHƯA TỚI (mục 9.33, L7): sổ giao dịch chỉ có quá khứ.
/// Trước đó bộ chỉnh đọc *"30 ngày tới"* là "không nêu kỳ" và tool liệt kê khoản
/// đã qua — trả lời một câu hỏi khác.
KetQuaCongCu tuChoiKyTuongLai() => const KetQuaCongCu.loi(
      'Kỳ trong câu hỏi chưa tới nên chưa có giao dịch. Hỏi khoản sắp phải trả thì '
      'gọi du_bao_dong_tien.',
      choNguoiDung: 'kỳ trong câu hỏi chưa tới nên chưa có giao dịch',
      thamSoGo: ['ky'],
    );

/// `so_voi` đi với `ky=moi_luc`: mọi thời gian không có kỳ trước để so.
KetQuaCongCu tuChoiSoSanhThieuKy() => const KetQuaCongCu.loi(
      'so_voi cần ky là một kỳ cụ thể (thang_nay, tuan_nay, tuy_chon…), không '
      'phải moi_luc.',
      choNguoiDung: 'chưa hiểu kỳ cần so sánh',
      thamSoGo: ['ky'],
    );

/// Số tiền nằm nhầm trong `tu_khoa` (bước 2b, bẫy 4.43). Gỡ khi lượt sau điền
/// `so_tien_tu` hoặc `so_tien_den` — tức mô hình đã dời số tiền về đúng chỗ.
KetQuaCongCu tuChoiTuKhoaLaSoTien(String giaTri) => KetQuaCongCu.loi(
      'tu_khoa "$giaTri" là số tiền — tu_khoa chỉ tìm chữ trong ghi chú; số tiền '
      'dùng so_tien_tu / so_tien_den, số đồng, ví dụ 500000.',
      choNguoiDung: _chuaHieuSoTien,
      thamSoGo: const ['so_tien_tu', 'so_tien_den'],
    );

/// Tên mô hình gõ, in cho NGƯỜI DÙNG: `_` đọc là dấu cách (bước 2c, bẫy 4.45 —
/// luật (a) của spec 2b áp cả giá trị mô hình gõ, không chỉ mã tham số).
String _tenChoNguoiDoc(String hoi) => hoi.replaceAll('_', ' ');

/// Tên liên quan của một tên mô hình gõ: dạng gõ, và dạng đã đổi `_` nếu khác.
List<String> _hoiVaBanDoc(String hoi) => [
      hoi,
      if (hoi.contains('_')) _tenChoNguoiDoc(hoi),
    ];

/// [loai]: chữ người đọc được của tham số — 'danh mục' · 'ví' · 'danh mục chi'.
KetQuaCongCu tuChoiKhongKhop(
  String thamSo,
  String hoi,
  List<String> tenCo, {
  required String loai,
}) =>
    KetQuaCongCu.loi(
      '$thamSo "$hoi" không khớp tên nào. Chỉ có: ${tenCo.join(', ')}.',
      choNguoiDung: 'không có $loai nào tên "${_tenChoNguoiDoc(hoi)}"',
      thamSoGo: [thamSo],
      tenLienQuan: [...tenCo, ..._hoiVaBanDoc(hoi)],
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
      choNguoiDung:
          'tên "${_tenChoNguoiDoc(hoi)}" khớp nhiều $loai: ${tenKhop.join(', ')}',
      thamSoGo: [thamSo],
      tenLienQuan: [...tenKhop, ..._hoiVaBanDoc(hoi)],
    );
