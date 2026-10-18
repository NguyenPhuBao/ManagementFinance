/// Câu lỗi ngắn cho mọi lỗi API của mảng thanh toán (spec Premium 5.5). KHÔNG
/// in URL, mã lỗi, stack — bài học `cauLoiTai`: thông báo lỗi tải mô hình từng
/// in nguyên URL ký hàng nghìn ký tự lên màn.
///
/// Dart thuần (KIEN_TRUC mục 4): phép đọc lỗi HTTP → [LoaiLoiThanhToan] ở
/// `data/datasources/payment_api.dart` (`loaiLoiThanhToanTu`); repository ném
/// [LoiThanhToan] nên giao diện không nhìn thấy Dio (spec G94 2026-10-18 mục 4).
enum LoaiLoiThanhToan { phienHetHan, mayChu, matMang, biTuChoi, khac }

/// Lỗi đã phân loại mà `DonThanhToanRepository` ném.
class LoiThanhToan implements Exception {
  const LoiThanhToan(this.loai);

  final LoaiLoiThanhToan loai;

  @override
  String toString() => 'LoiThanhToan(${loai.name})';
}

/// Loại của một lỗi bắt được ở giao diện — [LoiThanhToan] mang loại của nó, lỗi khác là [LoaiLoiThanhToan.khac].
LoaiLoiThanhToan loaiLoiCua(Object e) => e is LoiThanhToan ? e.loai : LoaiLoiThanhToan.khac;

/// [cauTuChoi] thay câu cho lỗi bị server từ chối (4xx trừ 401) — câu mặc định nói về *tạo đơn*,
/// sai với thao tác khác (`confirm-upgrade` trả 400 khi đơn không còn chờ xác nhận).
String cauLoiThanhToan(
  LoaiLoiThanhToan loai, {
  String cauTuChoi = 'Không tạo được đơn thanh toán. Thử lại sau.',
}) =>
    switch (loai) {
      LoaiLoiThanhToan.phienHetHan => 'Phiên đăng nhập hết hạn. Hãy đăng nhập lại.',
      LoaiLoiThanhToan.mayChu => 'Máy chủ chưa phản hồi. Thử lại sau.',
      LoaiLoiThanhToan.matMang => 'Không có kết nối. Thử lại khi có mạng.',
      LoaiLoiThanhToan.biTuChoi => cauTuChoi,
      LoaiLoiThanhToan.khac => 'Có lỗi xảy ra. Thử lại sau.',
    };
