/// Spec cưỡng chế đăng xuất §3.8 điểm 1: chỉ 400/401 do server TRẢ LỜI
/// `/auth/refresh` mới là phiên chết. Đây là hàm thuần, không chạm mạng.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/api/interceptors/ket_qua_lam_moi.dart';

DioException _loiTraLoi(int ma) {
  final opts = RequestOptions(path: '/auth/refresh');
  return DioException.badResponse(
    statusCode: ma,
    requestOptions: opts,
    response: Response<dynamic>(
      requestOptions: opts,
      statusCode: ma,
      data: {'success': false, 'message': 'gia'},
    ),
  );
}

void main() {
  group('ketQuaTuLoiLamMoi', () {
    for (final ma in [400, 401]) {
      test('$ma do server trả lời → phiên chết, giữ lỗi để Phần 1 đọc body', () {
        final kq = ketQuaTuLoiLamMoi(_loiTraLoi(ma));
        expect(kq, isA<LamMoiPhienChet>(),
            reason: 'spec §3.8 điểm 1: đúng hai mã mà `refresh` của '
                'auth.service.js tự ném');
        expect((kq as LamMoiPhienChet).loi?.response?.statusCode, ma,
            reason: 'Phần 1 (§3.3) sẽ đọc body 401 của /auth/refresh tìm `code`');
      });
    }

    for (final ma in [403, 404, 429, 500, 502, 503]) {
      test('$ma → tạm thời, không kết luận gì về phiên', () {
        expect(ketQuaTuLoiLamMoi(_loiTraLoi(ma)), isA<LamMoiTamThoi>(),
            reason: 'Mã khác 400/401 không phải lời khẳng định phiên chết; '
                'auth.controller.js:77 đưa lỗi không mang statusCode về 500');
      });
    }

    for (final loai in [
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.unknown,
    ]) {
      test('${loai.name} (không có phản hồi) → tạm thời, giữ nguyên lỗi', () {
        final loi = DioException(
          requestOptions: RequestOptions(path: '/auth/refresh'),
          type: loai,
        );
        final kq = ketQuaTuLoiLamMoi(loi);
        expect(kq, isA<LamMoiTamThoi>(),
            reason: 'Mất mạng đúng lúc token hết hạn không được biến thành '
                'đăng xuất — cam kết offline-first');
        expect((kq as LamMoiTamThoi).loi, same(loi));
      });
    }
  });
}
