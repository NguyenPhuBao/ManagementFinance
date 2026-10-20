import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../network/trang_thai_may_chu.dart';

/// Ghi [TrangThaiMayChu] từ phản hồi của Dio CHUNG (spec G89 2026-10-20 mục 3.2), và báo [khiBiTatQuyen] khi server trả
/// 403 `FEATURE_DISABLED` (mục 6.2 — `account.downgraded` chỉ phát lúc 0 giờ, còn server chặn từ lúc hết hạn). Không đổi
/// phản hồi nào — luôn `next`: mọi lỗi phân loại / hook đều bị nuốt có log, interceptor không bao giờ đổi lỗi của nơi gọi.
///
/// Chỉ `DioClient` dựng lớp này (test quét 36): Dio chung CHỈ nói chuyện với backend của app. Một lời gọi tới host bên thứ
/// ba đi qua đây trả 2xx sẽ xoá nhầm dòng nhắc bảo trì.
///
/// Đứng SAU `AuthInterceptor` trong chuỗi. `/auth/refresh` đi Dio riêng của `AuthInterceptor`; 503 của nó tới được đây chỉ
/// vì `AuthInterceptor` chép `response` sang lỗi của request gốc (`_loiTamThoiChoRequest`) rồi `next`. Lượt phát lại thành
/// công sau khi làm mới token đi `handler.resolve` — Dio không gọi `onResponse` của interceptor sau đó, nên 2xx ấy KHÔNG
/// xoá dòng nhắc; request 2xx kế tiếp xoá.
///
/// Chỉ ghi từ request MANG PHIÊN (header `Authorization`): đăng nhập / đăng ký / quên mật khẩu tự nói lỗi trên màn của
/// chúng (mục 4.3) — ghi từ đó là toast "Chưa đồng bộ được…" chồng lên câu lỗi màn Đăng nhập, lúc chưa có gì để đồng bộ.
///
/// Lỗi của request SSE (trợ lý online, `ResponseType.stream`) mang body là luồng, không phải `Map` → không phân loại; trợ lý
/// đã tự rơi về mô hình trên máy (mục 15 `AI_EDGE_FEATURE.md`).
class MayChuInterceptor extends Interceptor {
  MayChuInterceptor({
    required TrangThaiMayChu trangThai,
    Future<void> Function()? khiBiTatQuyen,
    DateTime Function()? now,
  })  : _trangThai = trangThai,
        _khiBiTatQuyen = khiBiTatQuyen,
        _now = now ?? DateTime.now;

  /// Hai lần báo `FEATURE_DISABLED` cách nhau ít nhất chừng này — mỗi lần báo là một `GET /payment/subscription-info`.
  static const gianTatQuyen = Duration(seconds: 30);

  final TrangThaiMayChu _trangThai;
  final Future<void> Function()? _khiBiTatQuyen;
  final DateTime Function() _now;
  DateTime? _lanBaoTatQuyen;

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    try {
      final ma = response.statusCode ?? 0;
      if (ma >= 200 && ma < 300 && _mangPhien(response.requestOptions) && _trangThai.value is! MayChuBinhThuong) {
        _trangThai.value = const MayChuBinhThuong();
      }
    } catch (e) {
      debugPrint('[MayChuInterceptor] onResponse bỏ qua lỗi: $e');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    try {
      final res = err.response;
      if (res != null) {
        if (_mangPhien(err.requestOptions)) {
          // `headers.value` NÉM khi header có từ hai giá trị — đọc danh sách, lấy phần tử đầu.
          final ra = res.headers['retry-after'];
          final moi = phanLoaiPhanHoi(
            status: res.statusCode,
            body: res.data,
            retryAfter: (ra != null && ra.isNotEmpty) ? ra.first : null,
            bayGio: _now(),
          );
          if (moi != null) _trangThai.value = moi;
        }
        _xetTatQuyen(res);
      }
    } catch (e) {
      debugPrint('[MayChuInterceptor] onError bỏ qua lỗi: $e');
    }
    handler.next(err);
  }

  void _xetTatQuyen(Response<dynamic> res) {
    final body = res.data;
    if (res.statusCode != 403 || body is! Map || body['code'] != 'FEATURE_DISABLED') return;
    final bao = _khiBiTatQuyen;
    if (bao == null) return;
    final now = _now();
    final truoc = _lanBaoTatQuyen;
    if (truoc != null && now.difference(truoc) < gianTatQuyen) return;
    _lanBaoTatQuyen = now;
    unawaited(bao());
  }

  static bool _mangPhien(RequestOptions o) {
    final h = o.headers['Authorization'];
    return h is String && h.isNotEmpty;
  }
}
