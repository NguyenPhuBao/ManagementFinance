import 'package:dio/dio.dart';

/// Bốn API của module thanh toán backend (`api/payment.routes.js`, spec Premium
/// 6.2). Bọc sau interface để repository và màn test được bằng bản giả; bản Dio
/// mỏng — chỉ `bocData` / `bocDanhSach` có test.
abstract class PaymentApi {
  /// `GET /payment/subscription-info` → `data` thô (đọc bằng `trangThaiTuJson`).
  Future<Map<String, Object?>> thongTinGoi();

  /// `POST /payment/create-order` → `data` thô (đọc bằng `donTuJson`).
  Future<Map<String, Object?>> taoDon();

  /// `GET /payment/order-status/:orderCode` → `data` thô (`status`).
  Future<Map<String, Object?>> trangThaiDon(int orderCode);

  /// `GET /payment/history` → `items`.
  Future<List<Map<String, Object?>>> lichSu({int page = 1, int limit = 20});
}

/// Bóc `data` khỏi bao `{success, message, data}` của backend. Không có `data`
/// (hoặc `data` không phải Map) thì coi cả thân là data; thân không phải Map →
/// `{}` — người đọc tiếp (`trangThaiTuJson`, `donTuJson`) tự rơi về mặc định.
Map<String, Object?> bocData(Object? body) {
  if (body is! Map) return const {};
  final d = body['data'];
  if (d is Map) return d.cast<String, Object?>();
  return body.cast<String, Object?>();
}

List<Map<String, Object?>> bocDanhSach(Object? body, String khoa) {
  final d = bocData(body)[khoa];
  if (d is! List) return const [];
  return [for (final x in d) if (x is Map) x.cast<String, Object?>()];
}

class DioPaymentApi implements PaymentApi {
  DioPaymentApi(this._dio);

  /// `sl<DioClient>().dio` — `AuthInterceptor` gắn token, base URL có `/api`.
  final Dio _dio;

  @override
  Future<Map<String, Object?>> thongTinGoi() async =>
      bocData((await _dio.get('/payment/subscription-info')).data);

  @override
  Future<Map<String, Object?>> taoDon() async => bocData((await _dio.post(
        '/payment/create-order',
        data: {'packageType': 'PREMIUM_1_MONTH'},
      ))
          .data);

  @override
  Future<Map<String, Object?>> trangThaiDon(int orderCode) async =>
      bocData((await _dio.get('/payment/order-status/$orderCode')).data);

  @override
  Future<List<Map<String, Object?>>> lichSu({int page = 1, int limit = 20}) async =>
      bocDanhSach(
        (await _dio.get(
          '/payment/history',
          queryParameters: {'page': page, 'limit': limit},
        ))
            .data,
        'items',
      );
}
