import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flowmoney/features/ban_sao_du_lieu/data/datasources/ban_sao_du_lieu_api.dart';
import 'package:flowmoney/features/ban_sao_du_lieu/domain/trang_thai_ban_sao.dart';
import 'package:flutter_test/flutter_test.dart';

class _MayChu implements HttpClientAdapter {
  int ma = 200;
  Object body = const {'success': true, 'data': null};
  Map<String, List<String>> header = {};
  bool matMang = false;
  RequestOptions? cuoi;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    cuoi = o;
    if (matMang) {
      throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
    }
    final bytes = body is Uint8List ? body as Uint8List : utf8.encode(jsonEncode(body));
    return ResponseBody.fromBytes(bytes, ma, headers: {
      Headers.contentTypeHeader: [body is Uint8List ? 'text/csv; charset=utf-8' : Headers.jsonContentType],
      ...header,
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _MayChu mc;
  late DioBanSaoDuLieuApi api;
  final nay = DateTime(2026, 11, 16, 9);

  setUp(() {
    mc = _MayChu();
    final dio = Dio(BaseOptions(baseUrl: 'http://x/api'))..httpClientAdapter = mc;
    api = DioBanSaoDuLieuApi(dio, dongHo: () => nay);
  });

  test('layMoiNhat: data null → null; READY → đọc được', () async {
    expect(await api.layMoiNhat(), isNull);
    expect(mc.cuoi!.path, '/account/data-export/latest');
    mc.body = {
      'success': true,
      'data': {'id': 'a', 'status': 'READY', 'files': ['json']},
    };
    expect((await api.layMoiNhat())!.trangThai, TrangThaiBanSao.sanSang);
  });

  test('yeuCau: 202 → PROCESSING + email', () async {
    mc
      ..ma = 202
      ..body = {
        'success': true,
        'data': {'id': 'b', 'status': 'PROCESSING', 'email': 'an***@gmail.com'},
      };
    final y = await api.yeuCau();
    expect(mc.cuoi!.method, 'POST');
    expect(y.email, 'an***@gmail.com');
  });

  test('429 đọc Retry-After (giây); thiếu header → choThem null', () async {
    mc
      ..ma = 429
      ..body = {'success': false, 'code': 'DATA_EXPORT_RATE_LIMITED'}
      ..header = {
        'retry-after': ['18720'],
      };
    await expectLater(
        api.yeuCau(),
        throwsA(isA<LoiBanSao>()
            .having((e) => e.loai, 'loai', LoaiLoiBanSao.daGioiHan)
            .having((e) => e.choThem, 'choThem', const Duration(seconds: 18720))));
    mc.header = {};
    await expectLater(api.yeuCau(), throwsA(isA<LoiBanSao>().having((e) => e.choThem, 'choThem', isNull)));
  });

  test('410 / 409 / 404 / mất mạng / 500 → đúng loại', () async {
    Future<LoaiLoiBanSao> loai(int ma) async {
      mc.ma = ma;
      mc.body = {'success': false};
      try {
        await api.taiTep('a', 'json');
      } on LoiBanSao catch (e) {
        return e.loai;
      }
      fail('không ném');
    }

    expect(await loai(410), LoaiLoiBanSao.hetHan);
    expect(await loai(409), LoaiLoiBanSao.chuaXong);
    expect(await loai(404), LoaiLoiBanSao.khongCo);
    expect(await loai(500), LoaiLoiBanSao.khac);
    mc.matMang = true;
    await expectLater(api.layMoiNhat(), throwsA(isA<LoiBanSao>().having((e) => e.loai, 'loai', LoaiLoiBanSao.matMang)));
  });

  test('taiTep: bytes nguyên (giữ BOM CSV), query format, tên từ Content-Disposition, mime', () async {
    final csv = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('a;b\n')]);
    mc
      ..body = csv
      ..header = {
        'content-disposition': ['attachment; filename="flowmoney-giao-dich-20261116.csv"'],
      };
    final t = await api.taiTep('id/1', 'csv');
    expect(t.bytes, csv);
    expect(t.ten, 'flowmoney-giao-dich-20261116.csv');
    expect(t.mime, 'text/csv');
    expect(mc.cuoi!.queryParameters['format'], 'csv');
    expect(mc.cuoi!.path, '/account/data-export/id%2F1/download', reason: 'id đi vào đường dẫn phải được mã hoá');
  });

  test('tenTepTuHeader: có nháy / không nháy / thiếu / rác / sai đuôi', () {
    expect(tenTepTuHeader('attachment; filename="a-1.json"', 'json', nay), 'a-1.json');
    expect(tenTepTuHeader('attachment; filename=a_2.csv', 'csv', nay), 'a_2.csv');
    expect(tenTepTuHeader(null, 'json', nay), 'flowmoney-du-lieu-ca-nhan-20261116.json');
    expect(tenTepTuHeader('attachment; filename="../../x.csv"', 'csv', nay), 'flowmoney-giao-dich-20261116.csv',
        reason: 'tên đi vào MediaStore / đường dẫn tạm — chỉ nhận [A-Za-z0-9._-], không "/"');
    expect(tenTepTuHeader('attachment; filename="a.exe"', 'json', nay), 'flowmoney-du-lieu-ca-nhan-20261116.json');
  });
}
