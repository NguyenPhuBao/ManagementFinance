import 'package:dio/dio.dart';

import '../../domain/cau_loi_nha.dart';

/// 16 API của module gia đình backend — đường dẫn / method như mã `177dd0e1` (`api/households.routes.js:10-31`; `docs/Family/04`
/// mục 2; backend đổi thì sửa ở đây và ca hợp đồng `household_api_test`). Bọc sau interface để repository test được bằng bản
/// giả (`test/helpers/household_api_gia.dart`). Vai gửi lên là chữ server (`khoaServerCuaVai`). Trả `data` thô — đọc bằng bộ
/// đọc ở `data/models/`; thân nào KHÔNG phải trạng thái nhà (#8, #10, #12, #16) repository không áp (`laThanTrangThaiNha`).
abstract class HouseholdApi {
  /// #2 `GET /households/me` → trạng thái nhà (hiện PHẲNG — đơn 57.1; `{household: null}` khi không ở nhà).
  Future<Map<String, Object?>> cuaToi();

  /// #1 `POST /households {name}` → hiện hàng thô + `myRole`, không `members` (đơn 57.1). Cần Premium (hiện chưa chặn — 56.4).
  Future<Map<String, Object?>> taoNha(String ten);

  /// #3 `POST /households/invites {role}` → `{code, role, expiresAt}`.
  Future<Map<String, Object?>> taoMaMoi(String vai);

  /// #4 `GET /households/invites` → mảng `{code, role, email|null, createAt, expiresAt, status}` — gồm cả lời mời email đã
  /// hết hiệu lực (đơn 57.8.5).
  Future<List<Map<String, Object?>>> dsMaMoi();

  /// #5 `DELETE /households/invites/:code` — cả mã thường lẫn lời mời email.
  Future<void> huyMaMoi(String ma);

  /// #6 `GET /households/invites/:code` → bản xem trước (lời mời email: hiện luôn 403 — đơn 57.2).
  Future<Map<String, Object?>> xemTruoc(String ma);

  /// #7 `POST /households/join {code}` → trạng thái nhà.
  Future<Map<String, Object?>> thamGia(String ma);

  /// #8 `PATCH /households/members/:idaccount {role}` → `{targetIdaccount, newRole}` — KHÔNG phải trạng thái nhà.
  Future<Map<String, Object?>> doiVai(int idaccount, String vai);

  /// #9 `POST /households/transfer-owner {idaccount}` → trạng thái nhà (của chủ cũ, nay Member).
  Future<Map<String, Object?>> chuyenChu(int idaccount);

  /// #10 `DELETE /households/members/:idaccount` → `{removed: true}` — KHÔNG phải trạng thái nhà.
  Future<Map<String, Object?>> moiRa(int idaccount);

  /// #11 `POST /households/leave` → `{household: null}`.
  Future<Map<String, Object?>> roiNha();

  /// #12 `POST /households/dissolve` → `{dissolved: true}` — KHÔNG phải trạng thái nhà. (Đơn 50 viết `DELETE /` — route ấy
  /// không có.)
  Future<Map<String, Object?>> giaiTan();

  /// #13 `POST /households/invites/email {email, role}` → `202 {sent, email, role, expiresAt}` — luôn cùng hình dạng.
  Future<Map<String, Object?>> moiQuaEmail(String email, String vai);

  /// #14 `GET /households/invitations` → mảng lời mời gửi tới tôi (hiện chỉ lời mời đã gắn `Invitee_idaccount` — đơn 57.2).
  Future<List<Map<String, Object?>>> dsLoiMoiToi();

  /// #15 `POST /households/invitations/:code/accept` → trạng thái nhà (như #7).
  Future<Map<String, Object?>> chapNhanLoiMoi(String ma);

  /// #16 `POST /households/invitations/:code/decline` → `{declined: true}`.
  Future<void> tuChoiLoiMoi(String ma);
}

/// Bóc `{success, data}` của backend — cùng khuôn `features/premium/data/datasources/payment_api.dart` `bocData`, chép cục bộ
/// để mảng này không cầm datasource của mảng khác (người dùng chốt 2026-10-28). Thân không có `data` thì trả chính nó.
Map<String, Object?> _bocData(Object? body) {
  if (body is! Map) return const {};
  final d = body['data'];
  if (d is Map) return d.cast<String, Object?>();
  return body.cast<String, Object?>();
}

/// `data` là MẢNG (#4, #14) — `_bocData` chỉ bóc Map. Phần tử không phải Map bị bỏ.
List<Map<String, Object?>> bocMang(Object? body) {
  final d = body is Map ? body['data'] : body;
  if (d is! List) return const [];
  return [
    for (final x in d)
      if (x is Map) x.cast<String, Object?>(),
  ];
}

/// Đọc một lỗi bắt được ở lời gọi API → [LoaiLoiNha] (cùng khuôn `loaiLoiThanhToanTu`). 401 là việc của
/// `AuthInterceptor` — không đọc `code` của nó. Không nhìn `dart:io`: app còn chạy trên web.
LoaiLoiNha loaiLoiNhaTu(Object e) {
  if (e is LoiNha) return e.loai;
  if (e is! DioException) return LoaiLoiNha.khac;
  final status = e.response?.statusCode;
  if (status == 401) return LoaiLoiNha.phienHetHan;
  if (status != null && status >= 500) return LoaiLoiNha.mayChu;
  switch (e.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return LoaiLoiNha.matMang;
    case DioExceptionType.badResponse:
      final body = e.response?.data;
      return loaiLoiTuMa(body is Map ? body['code']?.toString() : null) ?? LoaiLoiNha.khac;
    case DioExceptionType.badCertificate:
    case DioExceptionType.cancel:
    case DioExceptionType.transformTimeout:
    case DioExceptionType.unknown:
      return LoaiLoiNha.khac;
  }
}

class DioHouseholdApi implements HouseholdApi {
  DioHouseholdApi(this._dio);

  /// `sl<DioClient>().dio` — `AuthInterceptor` gắn token, base URL có `/api`.
  final Dio _dio;

  String _ma(String ma) => Uri.encodeComponent(ma);

  @override
  Future<Map<String, Object?>> cuaToi() async => _bocData((await _dio.get('/households/me')).data);

  @override
  Future<Map<String, Object?>> taoNha(String ten) async =>
      _bocData((await _dio.post('/households', data: {'name': ten})).data);

  @override
  Future<Map<String, Object?>> taoMaMoi(String vai) async =>
      _bocData((await _dio.post('/households/invites', data: {'role': vai})).data);

  @override
  Future<List<Map<String, Object?>>> dsMaMoi() async => bocMang((await _dio.get('/households/invites')).data);

  @override
  Future<void> huyMaMoi(String ma) async {
    await _dio.delete('/households/invites/${_ma(ma)}');
  }

  @override
  Future<Map<String, Object?>> xemTruoc(String ma) async =>
      _bocData((await _dio.get('/households/invites/${_ma(ma)}')).data);

  @override
  Future<Map<String, Object?>> thamGia(String ma) async =>
      _bocData((await _dio.post('/households/join', data: {'code': ma})).data);

  @override
  Future<Map<String, Object?>> doiVai(int idaccount, String vai) async =>
      _bocData((await _dio.patch('/households/members/$idaccount', data: {'role': vai})).data);

  @override
  Future<Map<String, Object?>> chuyenChu(int idaccount) async =>
      _bocData((await _dio.post('/households/transfer-owner', data: {'idaccount': idaccount})).data);

  @override
  Future<Map<String, Object?>> moiRa(int idaccount) async =>
      _bocData((await _dio.delete('/households/members/$idaccount')).data);

  @override
  Future<Map<String, Object?>> roiNha() async => _bocData((await _dio.post('/households/leave')).data);

  @override
  Future<Map<String, Object?>> giaiTan() async => _bocData((await _dio.post('/households/dissolve')).data);

  @override
  Future<Map<String, Object?>> moiQuaEmail(String email, String vai) async =>
      _bocData((await _dio.post('/households/invites/email', data: {'email': email, 'role': vai})).data);

  @override
  Future<List<Map<String, Object?>>> dsLoiMoiToi() async => bocMang((await _dio.get('/households/invitations')).data);

  @override
  Future<Map<String, Object?>> chapNhanLoiMoi(String ma) async =>
      _bocData((await _dio.post('/households/invitations/${_ma(ma)}/accept')).data);

  @override
  Future<void> tuChoiLoiMoi(String ma) async {
    await _dio.post('/households/invitations/${_ma(ma)}/decline');
  }
}
