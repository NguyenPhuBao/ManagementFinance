import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../domain/loi_ban_sao.dart';
import '../models/yeu_cau_ban_sao.dart';

export '../../domain/loi_ban_sao.dart';

/// Ba API bản sao dữ liệu cá nhân (`/api/account/data-export…`, đơn client-app mục 52). Bọc sau interface để
/// repository / cubit test bằng bản giả. `idaccount` không gửi — backend lấy từ JWT (`AuthInterceptor`).
abstract class BanSaoDuLieuApi {
  /// `GET /account/data-export/latest` → `null` khi chưa từng yêu cầu.
  Future<YeuCauBanSao?> layMoiNhat();

  /// `POST /account/data-export` (202).
  Future<YeuCauBanSao> yeuCau();

  /// `GET /account/data-export/:id/download?format=json|csv` — bytes nguyên.
  Future<TepTaiVe> taiTep(String id, String dinhDang);
}

class TepTaiVe {
  const TepTaiVe({required this.ten, required this.mime, required this.bytes});
  final String ten;
  final String mime;
  final Uint8List bytes;
}

/// Lỗi bắt được → [LoiBanSao]. Không nhìn `dart:io` (app còn chạy web) — khuôn `loaiLoiThanhToanTu`.
LoiBanSao loiBanSaoTu(Object e) {
  if (e is LoiBanSao) return e;
  if (e is! DioException) return const LoiBanSao(LoaiLoiBanSao.khac);
  switch (e.response?.statusCode) {
    case 429:
      final s = int.tryParse(e.response?.headers.value('retry-after') ?? '');
      return LoiBanSao(LoaiLoiBanSao.daGioiHan, choThem: s == null ? null : Duration(seconds: s));
    case 410:
      return const LoiBanSao(LoaiLoiBanSao.hetHan);
    case 409:
      return const LoiBanSao(LoaiLoiBanSao.chuaXong);
    case 404:
      return const LoiBanSao(LoaiLoiBanSao.khongCo);
  }
  switch (e.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const LoiBanSao(LoaiLoiBanSao.matMang);
    default:
      return const LoiBanSao(LoaiLoiBanSao.khac);
  }
}

final RegExp _tenTrongHeader = RegExp(r'filename="?([^";]+)"?');
final RegExp _tenAnToan = RegExp(r'^[A-Za-z0-9._-]+$');

/// Tên tệp từ `Content-Disposition`. Tên đi vào `MediaStore` / đường dẫn tạm nên chỉ nhận `[A-Za-z0-9._-]` và
/// đúng đuôi định dạng; còn lại dựng tên mặc định theo ngày máy (khớp tên backend đặt).
String tenTepTuHeader(String? contentDisposition, String dinhDang, DateTime nay) {
  final ten = contentDisposition == null ? null : _tenTrongHeader.firstMatch(contentDisposition)?.group(1)?.trim();
  if (ten != null && _tenAnToan.hasMatch(ten) && ten.endsWith('.$dinhDang') && !ten.startsWith('.')) return ten;
  final ngay = '${nay.year}${nay.month.toString().padLeft(2, '0')}${nay.day.toString().padLeft(2, '0')}';
  return dinhDang == 'csv' ? 'flowmoney-giao-dich-$ngay.csv' : 'flowmoney-du-lieu-ca-nhan-$ngay.json';
}

class DioBanSaoDuLieuApi implements BanSaoDuLieuApi {
  DioBanSaoDuLieuApi(this._dio, {DateTime Function()? dongHo}) : _dongHo = dongHo ?? DateTime.now;

  /// `sl<DioClient>().dio` — `AuthInterceptor` gắn token + `x-device-name`, base URL có `/api`.
  final Dio _dio;
  final DateTime Function() _dongHo;

  static Object? _data(Object? body) => body is Map ? body['data'] : null;

  @override
  Future<YeuCauBanSao?> layMoiNhat() async {
    try {
      final res = await _dio.get<Object?>('/account/data-export/latest');
      return yeuCauBanSaoTuJson(_data(res.data));
    } catch (e) {
      throw loiBanSaoTu(e);
    }
  }

  @override
  Future<YeuCauBanSao> yeuCau() async {
    try {
      final res = await _dio.post<Object?>('/account/data-export');
      final y = yeuCauBanSaoTuJson(_data(res.data));
      if (y == null) throw const LoiBanSao(LoaiLoiBanSao.khac);
      return y;
    } catch (e) {
      throw loiBanSaoTu(e);
    }
  }

  @override
  Future<TepTaiVe> taiTep(String id, String dinhDang) async {
    try {
      final res = await _dio.get<List<int>>(
        '/account/data-export/${Uri.encodeComponent(id)}/download',
        queryParameters: {'format': dinhDang},
        options: Options(responseType: ResponseType.bytes),
      );
      return TepTaiVe(
        ten: tenTepTuHeader(res.headers.value('content-disposition'), dinhDang, _dongHo()),
        mime: dinhDang == 'csv' ? 'text/csv' : 'application/json',
        bytes: Uint8List.fromList(res.data ?? const []),
      );
    } catch (e) {
      throw loiBanSaoTu(e);
    }
  }
}
