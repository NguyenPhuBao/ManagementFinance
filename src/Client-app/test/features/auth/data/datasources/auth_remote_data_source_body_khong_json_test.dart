/// Body KHÔNG phải JSON object (trang HTML của proxy / Render khi dịch vụ ngủ, câu thuần chữ, mảng) — G97.
///
/// Trước đây mọi lời gọi đọc `data['message']` thẳng: body là `String` thì Dart gọi `String[]` với khoá chuỗi và ném
/// `TypeError`; `AuthBloc` bắt bằng `catch (e)` nên màn Đăng nhập in nguyên văn
/// *"type 'String' is not a subtype of type 'int' of 'index'"*. Nay câu đi qua một định nghĩa — body không phải `Map`
/// hoặc `message` không phải chuỗi có chữ thì dùng câu mặc định của lời gọi ấy.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/errors/app_exceptions.dart';
import 'package:flowmoney/features/auth/data/datasources/auth_remote_data_source.dart';

/// Trả body THÔ với `content-type` cho sẵn — Dio chỉ giải mã JSON khi `content-type` là JSON, còn lại `data` là `String`.
class _AdapterTho implements HttpClientAdapter {
  _AdapterTho(this.status, this.body, {this.loai = 'text/html; charset=utf-8'});
  final int status;
  final String body;
  final String loai;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async =>
      ResponseBody.fromString(body, status, headers: {
        Headers.contentTypeHeader: [loai],
      });

  @override
  void close({bool force = false}) {}
}

const _html502 = '<!DOCTYPE html><html><head><title>502 Bad Gateway</title></head>'
    '<body><h1>Bad Gateway</h1></body></html>';

/// Mỗi lời gọi của datasource với tham số giả — đủ 14 lời gọi của interface.
final Map<String, Future<Object?> Function(AuthRemoteDataSource)> _loiGoi = {
  'login': (d) => d.login('dat', 'x'),
  'logout': (d) => d.logout('tk'),
  'changePassword': (d) => d.changePassword('a', 'b'),
  'forgotPassword': (d) => d.forgotPassword('a@b.c'),
  'verifyOtp': (d) => d.verifyOtp('a@b.c', '123456'),
  'resetPassword': (d) => d.resetPassword('rt', 'b'),
  'deleteAccount': (d) => d.deleteAccount('x'),
  'cancelDelete': (d) => d.cancelDelete(),
  'getProfile': (d) => d.getProfile(),
  'updateProfile': (d) => d.updateProfile(fullname: 'Đạt'),
  'requestEmailChange': (d) => d.requestEmailChange('a@b.c'),
  'confirmEmailChange': (d) => d.confirmEmailChange('a@b.c', '123456'),
  'registerSendOtp': (d) => d.registerSendOtp(username: 'dat', fullname: 'Đạt', email: 'a@b.c', password: 'x'),
  'registerVerifyOtp': (d) =>
      d.registerVerifyOtp(username: 'dat', fullname: 'Đạt', email: 'a@b.c', password: 'x', otp: '123456'),
};

void main() {
  AuthRemoteDataSourceImpl ds(HttpClientAdapter a) =>
      AuthRemoteDataSourceImpl(dio: Dio(BaseOptions(baseUrl: 'http://x/api'))..httpClientAdapter = a);

  /// Lỗi ném ra là `Exception` mang đúng câu — không phải `TypeError` (câu của nó lọt ra màn hình).
  Matcher cau(String c) => throwsA(predicate((e) => e is Exception && e.toString() == 'Exception: $c', c));

  group('502 HTML của proxy → câu mặc định của lời gọi, không TypeError', () {
    const macDinh = {
      'login': 'Lỗi máy chủ',
      'logout': 'Lỗi đăng xuất',
      'changePassword': 'Lỗi máy chủ',
      'forgotPassword': 'Lỗi máy chủ',
      'verifyOtp': 'Lỗi máy chủ',
      'resetPassword': 'Lỗi máy chủ',
      'deleteAccount': 'Lỗi máy chủ',
      'cancelDelete': 'Lỗi máy chủ',
      'updateProfile': 'Lỗi máy chủ',
      'requestEmailChange': 'Lỗi máy chủ',
      'confirmEmailChange': 'Lỗi máy chủ',
      'registerSendOtp': 'Lỗi máy chủ',
      'registerVerifyOtp': 'Lỗi máy chủ',
    };
    test('bảng phủ mọi lời gọi trừ getProfile (ca riêng bên dưới)', () {
      expect(macDinh.keys.toSet(), _loiGoi.keys.toSet().difference({'getProfile'}),
          reason: 'thêm lời gọi mới vào datasource thì thêm vào bảng này');
    });
    for (final e in macDinh.entries) {
      test(e.key, () async {
        await expectLater(_loiGoi[e.key]!(ds(_AdapterTho(502, _html502))), cau(e.value));
      });
    }
  });

  group('2xx nhưng body không phải JSON object → câu thất bại của lời gọi, không TypeError', () {
    // `logout`, `forgotPassword` không đọc body 2xx.
    const macDinh = {
      'login': 'Đăng nhập thất bại',
      'changePassword': 'Đổi mật khẩu thất bại',
      'verifyOtp': 'OTP không hợp lệ',
      'resetPassword': 'Đặt lại mật khẩu thất bại',
      'deleteAccount': 'Yêu cầu xóa tài khoản thất bại',
      'cancelDelete': 'Hủy yêu cầu xóa tài khoản thất bại',
      'getProfile': 'Không lấy được thông tin',
      'updateProfile': 'Cập nhật thất bại',
      'requestEmailChange': 'Không thể gửi OTP',
      'confirmEmailChange': 'Xác nhận thất bại',
      'registerSendOtp': 'Không thể gửi OTP',
      'registerVerifyOtp': 'OTP không hợp lệ',
    };
    for (final e in macDinh.entries) {
      test(e.key, () async {
        await expectLater(_loiGoi[e.key]!(ds(_AdapterTho(200, '<html>Đăng nhập Wi-Fi</html>'))), cau(e.value));
      });
    }
  });

  test('login: 400 JSON mà `message` không phải chuỗi → câu mặc định, không in mảng thô', () async {
    final a = _AdapterTho(400, '{"success":false,"message":["a","b"]}', loai: 'application/json');
    await expectLater(ds(a).login('dat', 'x'), cau('Lỗi máy chủ'));
  });

  test('login: 400 JSON có `message` → vẫn câu của server', () async {
    final a = _AdapterTho(400, '{"success":false,"message":"Thiếu tên đăng nhập"}', loai: 'application/json');
    await expectLater(ds(a).login('dat', 'x'), cau('Thiếu tên đăng nhập'));
  });

  group('getProfile — mã HTTP chỉ được tin khi body là JSON của backend', () {
    Matcher loiMayChu(int? ma) => throwsA(isA<ServerException>()
        .having((e) => e.message, 'message', 'Lỗi máy chủ')
        .having((e) => e.statusCode, 'statusCode', ma));

    test('404 HTML (proxy / Render không thấy dịch vụ) → statusCode null, KHÔNG phải "phiên chết"', () async {
      // `verifySession` đọc 401/404 là phiên chết → đăng xuất. Trang 404 của proxy không nói gì về tài khoản; trước khi
      // sửa, TypeError tình cờ đưa ca này về `SessionStatus.unknown` — giữ nguyên kết quả ấy.
      await expectLater(ds(_AdapterTho(404, '<html>Not Found</html>')).getProfile(), loiMayChu(null));
    });

    test('404 JSON của backend → giữ statusCode 404 như cũ', () async {
      final a = _AdapterTho(404, '{"success":false,"message":"Lỗi máy chủ"}', loai: 'application/json');
      await expectLater(ds(a).getProfile(), loiMayChu(404));
    });
  });
}
