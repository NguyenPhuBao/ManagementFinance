/// Tải ảnh từ host bên thứ BA (`img.vietqr.io` — ảnh VietQR của đơn) bằng `Dio()` TRẦN: Dio chung của app
/// (`sl<DioClient>().dio`) có `AuthInterceptor` gắn token người dùng cho mọi host. Tách khỏi `LuuAnhQr` (2026-10-19) để cổng
/// kênh `flowmoney/luu_anh` không import Dio — trang Chờ thanh toán gọi thẳng cổng ấy (quét 31). Chỉ DI gọi hàm này.
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';

Future<Uint8List> taiAnhBangDioTran(Uri url) async {
  final r = await Dio().getUri<List<int>>(url, options: Options(responseType: ResponseType.bytes));
  final b = r.data;
  if (b == null || b.isEmpty) throw StateError('ảnh rỗng');
  return Uint8List.fromList(b);
}
