import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../constants/app_constants.dart';

/// AuthInterceptor tự động:
/// 1. Gắn `Authorization: Bearer <accessToken>` vào mỗi request
/// 2. Khi nhận 401 → gọi `/auth/refresh` lấy token mới → retry request gốc
/// 3. Nếu refresh cũng thất bại → xóa token → ném lỗi để app redirect /login
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

  // Tạo Dio riêng cho refresh call (không đi qua interceptor này — tránh vòng lặp)
  late final Dio _refreshDio;

  AuthInterceptor({required this.secureStorage}) {
    _refreshDio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.connectionTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
      ),
    );
  }

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

  // ─── Bước 2: Xử lý 401 → thử refresh token ─────────────────────────────
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Chỉ xử lý 401, bỏ qua mọi lỗi khác
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    try {
      final newAccessToken = await _tryRefreshToken();

      if (newAccessToken == null) {
        // Refresh thất bại → xóa token → force logout
        await _clearTokens();
        return handler.next(err);
      }

      // Lưu token mới
      await secureStorage.write(
        key: AppConstants.accessTokenKey,
        value: newAccessToken,
      );

      // Retry request gốc với token mới
      final retryResponse = await _retryRequest(err.requestOptions, newAccessToken);
      return handler.resolve(retryResponse);
    } catch (_) {
      // Nếu refresh exception → xóa token
      await _clearTokens();
      return handler.next(err);
    }
  }

  // ─── Gọi /auth/refresh để lấy access token mới ──────────────────────────
  Future<String?> _tryRefreshToken() async {
    final refreshToken = await secureStorage.read(
      key: AppConstants.refreshTokenKey,
    );

    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final response = await _refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;

        // Lưu refresh token mới nếu server trả về (token rotation)
        final newRefreshToken = data['refreshToken'] as String?;
        if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
          await secureStorage.write(
            key: AppConstants.refreshTokenKey,
            value: newRefreshToken,
          );
        }

        return data['accessToken'] as String?;
      }
      return null;
    } on DioException {
      return null;
    }
  }

  // ─── Retry request gốc với token mới ────────────────────────────────────
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

  // ─── Xóa toàn bộ tokens khi không thể refresh ───────────────────────────
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
