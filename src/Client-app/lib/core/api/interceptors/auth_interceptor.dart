import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../constants/app_constants.dart';
import 'ket_qua_lam_moi.dart';

/// AuthInterceptor tự động:
/// 1. Gắn `Authorization: Bearer <accessToken>` vào mỗi request
/// 2. Khi nhận 401 → gọi `/auth/refresh` lấy token mới → thử lại request gốc
/// 3. Chỉ khi server TRẢ LỜI `/auth/refresh` bằng 400/401 (hoặc máy không còn
///    refresh token) mới là phiên chết: xoá token, phát [sessionExpiredStream].
///    Không có phản hồi, hết giờ hay 5xx thì giữ token và trả lỗi ấy cho nơi
///    gọi — lần gọi API sau tự làm mới lại (spec cưỡng chế đăng xuất §3.8).
class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage secureStorage;

  /// Phát tín hiệu khi phiên đăng nhập không thể cứu được nữa (làm mới token
  /// thất bại nên token đã bị xoá).
  ///
  /// Vì sao cần: trước đây interceptor xoá token trong im lặng và không có mã
  /// nào trong `lib/` biết chuyện đó. App vẫn ở trạng thái `AuthSuccess` với
  /// kho token rỗng, nên mọi request tiếp theo đi ra không có header → 401 →
  /// lại refresh hỏng → lại xoá, quay vòng cho tới khi người dùng tự khởi
  /// động lại app.
  final _sessionExpiredController = StreamController<void>.broadcast();

  Stream<void> get sessionExpiredStream => _sessionExpiredController.stream;

  /// Dio riêng cho `/auth/refresh` và cho lượt thử lại — không đi qua
  /// interceptor này (tránh vòng lặp). Test tiêm một Dio có adapter giả.
  final Dio _refreshDio;

  AuthInterceptor({required this.secureStorage, Dio? dioLamMoi})
      : _refreshDio = dioLamMoi ??
            Dio(
              BaseOptions(
                baseUrl: AppConstants.baseUrl,
                connectTimeout: AppConstants.connectionTimeout,
                receiveTimeout: AppConstants.receiveTimeout,
              ),
            );

  // ─── Bước 1: Gắn Bearer token vào mỗi request ──────────────────────────
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await secureStorage.read(key: AppConstants.accessTokenKey);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  // ─── Bước 2: Xử lý 401 → làm mới token ─────────────────────────────────
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Chỉ xử lý 401, bỏ qua mọi lỗi khác
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    final ketQua = await _lamMoi();
    switch (ketQua) {
      case LamMoiPhienChet():
        // Token đã bị xoá và tín hiệu đã phát trong _lamMoi.
        return handler.next(err);
      case LamMoiTamThoi(:final loi):
        // Giữ hai token, không phát tín hiệu. Trả lỗi của chính lượt làm mới
        // (mất mạng / 5xx) chứ KHÔNG trả 401 gốc: verifySession coi 401 là
        // phiên chết và AuthBloc sẽ đăng xuất — đúng cái lỗi §3.8 muốn đóng.
        return handler.next(_loiTamThoiChoRequest(err.requestOptions, loi));
      case LamMoiThanhCong(:final accessToken):
        return _thuLai(err.requestOptions, accessToken, handler);
    }
  }

  /// Thử lại request gốc bằng [accessToken]. Thử lại hỏng thì trả lỗi ấy và
  /// GIỮ token: token vừa được cấp, lỗi này không nói gì về phiên (trước đây
  /// nhánh này xoá cả hai token — lỗi thứ ba tìm ra khi sửa §3.8).
  Future<void> _thuLai(
    RequestOptions goc,
    String accessToken,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      final retryResponse = await _retryRequest(goc, accessToken);
      return handler.resolve(retryResponse);
    } on DioException catch (loiThuLai) {
      return handler.next(loiThuLai);
    }
  }

  // ─── Gọi /auth/refresh ──────────────────────────────────────────────────
  /// Phiên chết (không còn refresh token, hoặc server trả 400/401) thì xoá
  /// token và phát tín hiệu NGAY TẠI ĐÂY, một lần cho một lượt làm mới —
  /// không để từng request chờ tự xoá, vì `_clearTokens` đọc kho rồi mới xoá
  /// và N request đan xen sẽ phát tín hiệu N lần.
  Future<KetQuaLamMoi> _lamMoi() async {
    final refreshToken = await secureStorage.read(
      key: AppConstants.refreshTokenKey,
    );
    if (refreshToken == null || refreshToken.isEmpty) {
      await _clearTokens();
      return const LamMoiPhienChet();
    }

    final Response<dynamic> response;
    try {
      response = await _refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
    } on DioException catch (e) {
      final ketQua = ketQuaTuLoiLamMoi(e);
      if (ketQua is LamMoiPhienChet) await _clearTokens();
      return ketQua;
    }

    final body = response.data;
    final data = body is Map && body['success'] == true ? body['data'] : null;
    final accessToken = data is Map ? data['accessToken'] : null;
    if (accessToken is! String || accessToken.isEmpty) {
      // 200 mà không đọc được token: không kết luận gì về phiên.
      return LamMoiTamThoi(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.unknown,
          message: 'Phản hồi /auth/refresh không có accessToken',
        ),
      );
    }

    // Lưu refresh token mới nếu server trả về (token rotation)
    final newRefreshToken = data['refreshToken'];
    if (newRefreshToken is String && newRefreshToken.isNotEmpty) {
      await secureStorage.write(
        key: AppConstants.refreshTokenKey,
        value: newRefreshToken,
      );
    }
    await secureStorage.write(
      key: AppConstants.accessTokenKey,
      value: accessToken,
    );
    return LamMoiThanhCong(accessToken);
  }

  /// Lỗi của lượt làm mới, gắn lên request gốc để nơi gọi nhận đúng bản chất
  /// (mất mạng → `NetworkException`, 5xx → `ServerException(5xx)` ở
  /// `auth_remote_data_source.dart`) thay vì một 401 nhìn như phiên chết.
  DioException _loiTamThoiChoRequest(RequestOptions goc, DioException loiLamMoi) =>
      DioException(
        requestOptions: goc,
        type: loiLamMoi.type,
        response: loiLamMoi.response,
        error: loiLamMoi.error,
        message: 'Làm mới token không thành công tạm thời: '
            '${loiLamMoi.message ?? loiLamMoi.type.name}',
      );

  // ─── Thử lại request gốc với token mới ──────────────────────────────────
  Future<Response<dynamic>> _retryRequest(
    RequestOptions requestOptions,
    String newToken,
  ) async {
    final options = Options(
      method: requestOptions.method,
      headers: {
        ...requestOptions.headers,
        'Authorization': 'Bearer $newToken',
      },
    );

    return _refreshDio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }

  // ─── Xóa toàn bộ tokens khi phiên chết ──────────────────────────────────
  Future<void> _clearTokens() async {
    // Chỉ coi là "phiên vừa chết" khi thật sự có token để mất. Sau lần xoá đầu
    // tiên, mọi request tiếp theo vẫn nhận 401 và vẫn chạy qua đây; phát tín
    // hiệu mỗi lần sẽ dội sự kiện vào AuthBloc — mà chính lời gọi
    // verifySession() của nó cũng đi qua Dio này, nên vòng lặp sẽ tự nuôi nhau.
    final hadSession =
        (await secureStorage.read(key: AppConstants.accessTokenKey))
                ?.isNotEmpty ==
            true ||
        (await secureStorage.read(key: AppConstants.refreshTokenKey))
                ?.isNotEmpty ==
            true;

    await secureStorage.delete(key: AppConstants.accessTokenKey);
    await secureStorage.delete(key: AppConstants.refreshTokenKey);

    if (hadSession && !_sessionExpiredController.isClosed) {
      _sessionExpiredController.add(null);
    }
  }

  /// Đóng kênh tín hiệu. Interceptor sống cùng vòng đời app nên thực tế hiếm
  /// khi gọi tới, nhưng test thì cần để không rò StreamController.
  void dispose() {
    _sessionExpiredController.close();
  }
}
