import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../auth/buoc_dang_xuat.dart';
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

  /// Server nói thẳng rằng tài khoản này không được dùng nữa — 401 mang `code`
  /// ở cấp gốc (spec cưỡng chế đăng xuất §3.3).
  ///
  /// Khác hẳn [sessionExpiredStream]: luồng kia nói *phiên hỏng, hỏi lại server
  /// đi* và `AuthBloc` sẽ gọi `verifySession()` trước khi quyết định. Luồng này
  /// mang sẵn **lý do**, nên không còn gì để hỏi — đưa người dùng ra kèm câu
  /// giải thích.
  final _taiKhoanBiTuChoiController =
      StreamController<ThongBaoBuocDangXuat>.broadcast();

  Stream<ThongBaoBuocDangXuat> get taiKhoanBiTuChoi =>
      _taiKhoanBiTuChoiController.stream;

  void _phatBiTuChoi(ThongBaoBuocDangXuat thongBao) {
    if (!_taiKhoanBiTuChoiController.isClosed) {
      _taiKhoanBiTuChoiController.add(thongBao);
    }
  }

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

  /// Lượt làm mới đang chạy — mọi 401 tới trong lúc ấy chờ chung lượt này
  /// (§3.8 điểm 2): hai lượt song song gửi cùng một refresh token, lượt sau
  /// vấp Token Reuse Detection và server thu hồi cả cặp token vừa cấp.
  Future<KetQuaLamMoi>? _lamMoiDangChay;

  Future<KetQuaLamMoi> _lamMoiChung() =>
      _lamMoiDangChay ??= _lamMoi().whenComplete(() => _lamMoiDangChay = null);

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

    // §3.3 chỗ 1 — 401 của một request thường mang mã trạng thái tài khoản.
    // Làm mới token lúc này là vô ích (server đã thu hồi refresh token ở
    // `auth.service.js:411`) và còn có hại: lượt làm mới ấy vấp Token Reuse
    // Detection, nhận về một 401 KHÔNG mã, rồi phát `sessionExpiredStream` —
    // một lượt đăng xuất trơn chạy đua với hộp thoại có lý do.
    //
    // Chốt "token cũ" bên dưới cố ý đứng SAU: mã này nói về *tài khoản*, không
    // nói về *token*, nên token có cũ hay không cũng không đổi kết luận.
    final thongBaoHttp =
        tuBody401(err.response?.data, nguon: NguonBuocDangXuat.http);
    if (thongBaoHttp != null) {
      _phatBiTuChoi(thongBaoHttp);
      await _clearTokens(phatTinHieu: false);
      return handler.next(err);
    }

    // Token của request này đã bị một lượt làm mới khác thay rồi → chỉ cần
    // thử lại bằng token hiện có, không gọi /auth/refresh lần nữa. Đọc hỏng
    // (kho token lỗi) thì bỏ chốt này và đi tiếp _lamMoiChung() — nơi
    // _lamMoi() sẽ bắt lỗi ấy và trả LamMoiTamThoi.
    final bearerCu = err.requestOptions.headers['Authorization'];
    String? tokenHienCo;
    try {
      tokenHienCo = await secureStorage.read(key: AppConstants.accessTokenKey);
    } catch (_) {
      tokenHienCo = null;
    }
    if (bearerCu is String &&
        tokenHienCo != null &&
        tokenHienCo.isNotEmpty &&
        bearerCu != 'Bearer $tokenHienCo') {
      return _thuLai(err.requestOptions, tokenHienCo, handler);
    }

    final ketQua = await _lamMoiChung();
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
  ///
  /// Toàn bộ thân hàm nằm trong `try/catch (Object)`: vì `_lamMoiChung()`
  /// dùng chung một Future cho mọi request đang chờ (§3.8 điểm 2), bất kỳ
  /// lỗi nào thoát ra khỏi đây — kể cả lỗi không phải `DioException`, như
  /// `PlatformException` thật của keystore khi đọc/ghi kho token (keystore
  /// hỏng, huỷ sinh trắc học, khôi phục OS…) — sẽ tới MỌI request đang chờ.
  /// Lỗi kho token không nói gì về phiên: giữ token, không phát tín hiệu,
  /// nơi gọi nhận lỗi tạm thời chứ không phải bị treo.
  ///
  /// NGOẠI LỆ duy nhất là `phanQuyet`: khi đã xác định được phiên chết thì
  /// `catch (Object)` không được hạ cấp phán quyết ấy — xem chú thích tại chỗ.
  Future<KetQuaLamMoi> _lamMoi() async {
    // Phán quyết "phiên chết" ghi lại TRƯỚC khi gọi `_clearTokens()`, vì lệnh
    // xoá có thể ném (kho token hỏng) và `catch (Object)` bên dưới sẽ biến một
    // phiên đã xác định là chết thành `LamMoiTamThoi`: token xoá dở, không
    // phát tín hiệu, app quay vòng 401 → refresh → 401 trong im lặng — đúng
    // hình dạng G12 mà `sessionExpiredStream` sinh ra để chặn.
    KetQuaLamMoi? phanQuyet;
    try {
      final refreshToken = await secureStorage.read(
        key: AppConstants.refreshTokenKey,
      );
      if (refreshToken == null || refreshToken.isEmpty) {
        phanQuyet = const LamMoiPhienChet();
        await _clearTokens();
        return phanQuyet;
      }

      final Response<dynamic> response;
      try {
        response = await _refreshDio.post(
          '/auth/refresh',
          data: {'refreshToken': refreshToken},
        );
      } on DioException catch (e) {
        final ketQua = ketQuaTuLoiLamMoi(e);
        if (ketQua is LamMoiPhienChet) {
          phanQuyet = ketQua;
          // §3.3 chỗ 2 — `/auth/refresh` cũng kiểm trạng thái tài khoản và trả
          // 401 cùng hình dạng body (`auth.controller.js:79-85`). Phép quyết
          // định nằm ở ĐÂY chứ không ở `onError`: `_clearTokens()` chạy trong
          // này, nên để `onError` tự đọc `LamMoiPhienChet.loi` thì tín hiệu
          // `sessionExpiredStream` đã phát mất rồi (spec §3.8 ghi sẵn điểm
          // vướng này cho Phần 1).
          //
          // ⚠️ Chỉ đọc `code` ở **401**. `/auth/refresh` còn trả 400, mà body
          // 400 của repo này cũng mang `code` (ví dụ `VALIDATION_ERROR`) — đọc
          // nó là hiện hộp thoại "Tài khoản đã bị vô hiệu hoá" cho một lỗi nhập
          // liệu.
          final thongBao = e.response?.statusCode == 401
              ? tuBody401(e.response?.data, nguon: NguonBuocDangXuat.lamMoi)
              : null;
          if (thongBao != null) {
            _phatBiTuChoi(thongBao);
            await _clearTokens(phatTinHieu: false);
          } else {
            await _clearTokens();
          }
        }
        return ketQua;
      }

      final body = response.data;
      final data =
          body is Map && body['success'] == true ? body['data'] : null;
      final accessToken = data is Map ? data['accessToken'] : null;
      if (accessToken is! String || accessToken.isEmpty) {
        // 200 mà không đọc được token: không kết luận gì về phiên.
        //
        // KHÔNG gắn `response` vào đây: lỗi này được `_loiTamThoiChoRequest`
        // chép sang lỗi của request gốc, và `SyncEngine` in `e.response?.data`
        // bằng `debugPrint` (không bị lược ở bản release). Hôm nay nhánh này
        // chỉ chạy khi body thiếu `accessToken`, nhưng nếu backend đổi tên
        // khoá (`access_token`, hay bọc thêm một lớp) thì body ấy VẪN mang
        // refreshToken và nó sẽ ra logcat qua lỗi của một request khác.
        return LamMoiTamThoi(
          DioException(
            requestOptions: response.requestOptions,
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
    } catch (e, st) {
      // Phiên chết đã xác định thì giữ nguyên phán quyết: lỗi ở đây chỉ có thể
      // là lỗi của chính lượt xoá token, và nó không làm phiên sống lại.
      if (phanQuyet != null) return phanQuyet;
      return LamMoiTamThoi(
        DioException(
          requestOptions: RequestOptions(path: '/auth/refresh'),
          type: DioExceptionType.unknown,
          error: e,
          stackTrace: st,
          message: 'Lỗi ngoài HTTP khi làm mới token: $e',
        ),
      );
    }
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
        stackTrace: loiLamMoi.stackTrace,
        message: 'Làm mới token không thành công tạm thời: '
            '${loiLamMoi.message ?? loiLamMoi.type.name}',
      );

  // ─── Thử lại request gốc với token mới ──────────────────────────────────
  /// ⚠️ `Options` dựng lại ở đây chỉ mang `method` + `headers`, nên lượt thử
  /// lại MẤT `responseType`, `contentType`, `sendTimeout`, `validateStatus`,
  /// `extra`, `cancelToken`, `onSendProgress`/`onReceiveProgress` của request
  /// gốc. Hôm nay vô hại — quét cả `lib/` không có chỗ nào dùng `ResponseType`,
  /// `FormData`, `CancelToken`, `validateStatus` hay `on*Progress`. Nhưng chốt
  /// "token cũ" ở `onError` vừa thêm **đường phát lại thứ hai** vào đây, nên ai
  /// thêm tải/gửi tệp về sau phải chép đủ `Options` từ `requestOptions`.
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
  /// [phatTinHieu] đặt `false` khi đã có một lời từ chối **mang lý do** đi ra
  /// bằng [taiKhoanBiTuChoi]: `AuthBloc` sắp đăng xuất kèm hộp thoại, và một
  /// lượt `sessionExpiredStream` song song chỉ tạo ra một lượt đăng xuất trơn
  /// chạy đua với nó (spec §3.3).
  Future<void> _clearTokens({bool phatTinHieu = true}) async {
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

    // `finally`: kho token hỏng thì lệnh xoá ném, nhưng tín hiệu VẪN phải phát.
    // Không xoá được token càng là lúc `AuthBloc` cần biết — nó không đăng xuất
    // ngay mà hỏi lại server bằng `verifySession()`, nên phát ở đây không tự nó
    // đăng xuất ai; im lặng thì mới đúng hình dạng G12 (app quay vòng
    // 401 → refresh → 401). Lỗi xoá vẫn thoát ra cho `_lamMoi()`, nơi phán
    // quyết "phiên chết" đã được giữ lại trước khi gọi vào đây.
    try {
      await secureStorage.delete(key: AppConstants.accessTokenKey);
      await secureStorage.delete(key: AppConstants.refreshTokenKey);
    } finally {
      if (phatTinHieu && hadSession && !_sessionExpiredController.isClosed) {
        _sessionExpiredController.add(null);
      }
    }
  }

  /// Đóng kênh tín hiệu. Interceptor sống cùng vòng đời app nên thực tế hiếm
  /// khi gọi tới, nhưng test thì cần để không rò StreamController.
  void dispose() {
    _sessionExpiredController.close();
    _taiKhoanBiTuChoiController.close();
  }
}
