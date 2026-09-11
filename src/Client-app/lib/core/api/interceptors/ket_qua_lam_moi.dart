import 'package:dio/dio.dart';

/// Kết quả một lượt gọi `/auth/refresh`, phân loại theo spec cưỡng chế đăng
/// xuất §3.8 điểm 1: chỉ 400/401 do server TRẢ LỜI (hoặc máy không còn refresh
/// token) mới là phiên chết. Không có phản hồi, hết giờ, 5xx, body lạ — là
/// tạm thời, và KHÔNG được xoá token.
sealed class KetQuaLamMoi {
  const KetQuaLamMoi();
}

/// `/auth/refresh` trả 200 với token mới; interceptor đã ghi cả hai token.
class LamMoiThanhCong extends KetQuaLamMoi {
  const LamMoiThanhCong(this.accessToken);

  final String accessToken;
}

/// Server trả 400/401 cho `/auth/refresh`, hoặc máy không còn refresh token
/// ([loi] null). Phần 1 (§3.3) sẽ đọc body 401 qua [loi] để tìm `code`.
class LamMoiPhienChet extends KetQuaLamMoi {
  const LamMoiPhienChet([this.loi]);

  final DioException? loi;
}

/// Không kết luận được gì về phiên: giữ hai token, không phát tín hiệu, trả
/// [loi] cho nơi gọi; lần gọi API sau tự làm mới lại.
class LamMoiTamThoi extends KetQuaLamMoi {
  const LamMoiTamThoi(this.loi);

  final DioException loi;
}

/// Hai mã `refresh` ở `auth.service.js:372-418` tự ném. Lỗi không mang
/// `statusCode` thành 500 ở `auth.controller.js:77`, nên không lọt vào đây.
const _maPhienChet = {400, 401};

KetQuaLamMoi ketQuaTuLoiLamMoi(DioException loi) {
  final ma = loi.response?.statusCode;
  if (ma != null && _maPhienChet.contains(ma)) return LamMoiPhienChet(loi);
  return LamMoiTamThoi(loi);
}
