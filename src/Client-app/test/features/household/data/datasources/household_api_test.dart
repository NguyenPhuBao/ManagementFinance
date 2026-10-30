import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flowmoney/features/household/data/datasources/household_api.dart';
import 'package:flowmoney/features/household/domain/cau_loi_nha.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/household_api_gia.dart';

/// Hợp đồng đường dẫn / thân của 16 endpoint — như mã backend `177dd0e1` (`api/households.routes.js:10-31`, `docs/Family/04`
/// mục 2); backend đổi đường thì sửa ở đây + `DioHouseholdApi`. Giải tán là `POST /dissolve` (đơn 50 viết `DELETE /`).
class _Ghi implements HttpClientAdapter {
  final goi = <String>[];
  Object? traVe = const {
    'success': true,
    'data': {'household': null}
  };

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    goi.add('${o.method} ${o.path}${o.data == null ? '' : ' ${jsonEncode(o.data)}'}');
    return ResponseBody.fromString(jsonEncode(traVe), 200, headers: {
      Headers.contentTypeHeader: ['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Ghi ghi;
  late DioHouseholdApi api;
  setUp(() {
    ghi = _Ghi();
    api = DioHouseholdApi(Dio()..httpClientAdapter = ghi);
  });

  test('16 endpoint đúng phương thức, đường dẫn, thân (api/households.routes.js:10-31)', () async {
    await api.cuaToi();
    await api.taoNha('Nhà An');
    await api.taoMaMoi('Member');
    ghi.traVe = const {'success': true, 'data': []};
    await api.dsMaMoi();
    await api.huyMaMoi('ABCD2345');
    ghi.traVe = const {'success': true, 'data': {}};
    await api.xemTruoc('ABCD2345');
    await api.thamGia('ABCD2345');
    await api.doiVai(25, 'Viewer');
    await api.chuyenChu(25);
    await api.moiRa(25);
    await api.roiNha();
    await api.giaiTan();
    await api.moiQuaEmail('an@x.com', 'Viewer');
    ghi.traVe = const {'success': true, 'data': []};
    await api.dsLoiMoiToi();
    ghi.traVe = const {'success': true, 'data': {}};
    await api.chapNhanLoiMoi('ABCD2345');
    await api.tuChoiLoiMoi('ABCD2345');
    expect(ghi.goi, [
      'GET /households/me',
      'POST /households {"name":"Nhà An"}',
      'POST /households/invites {"role":"Member"}',
      'GET /households/invites',
      'DELETE /households/invites/ABCD2345',
      'GET /households/invites/ABCD2345',
      'POST /households/join {"code":"ABCD2345"}',
      'PATCH /households/members/25 {"role":"Viewer"}',
      'POST /households/transfer-owner {"idaccount":25}',
      'DELETE /households/members/25',
      'POST /households/leave',
      'POST /households/dissolve', // KHÔNG `DELETE /households` như đơn 50 — route ấy không tồn tại (routes.js:13)
      'POST /households/invites/email {"email":"an@x.com","role":"Viewer"}',
      'GET /households/invitations',
      'POST /households/invitations/ABCD2345/accept',
      'POST /households/invitations/ABCD2345/decline',
    ]);
  });

  test('bóc data: Map cho trạng thái, mảng cho danh sách mã', () async {
    ghi.traVe = {'success': true, 'data': nhaJson()};
    expect((await api.cuaToi())['myRole'], 'Owner');
    ghi.traVe = const {
      'success': true,
      'data': [
        {'code': 'ABCD2345', 'role': 'Member'},
        'rác',
      ],
    };
    expect(await api.dsMaMoi(), [
      {'code': 'ABCD2345', 'role': 'Member'},
    ]);
    expect(
        bocMang(const {
          'data': {'khong': 'phai mang'}
        }),
        isEmpty);
  });

  group('loaiLoiNhaTu', () {
    DioException loiMang(DioExceptionType t) =>
        DioException(requestOptions: RequestOptions(path: '/households'), type: t);

    test('code ở cấp gốc thân 4xx → loại (đơn 50 C.3)', () {
      expect(loaiLoiNhaTu(loiServer(400, 'HOUSEHOLD_INVITE_EXPIRED')), LoaiLoiNha.maHetHan,
          reason: 'mã thật trả 400 (đơn 50 viết 410) — phân loại theo `code`, không theo status');
      expect(loaiLoiNhaTu(loiServer(409, 'HOUSEHOLD_ALREADY_IN_ONE')), LoaiLoiNha.daONhaKhac);
      expect(loaiLoiNhaTu(loiServer(403, 'FEATURE_DISABLED')), LoaiLoiNha.tinhNangKhongMo);
      expect(loaiLoiNhaTu(loiServer(400, 'VALIDATION_LA')), LoaiLoiNha.khac);
    });

    test('401 / 5xx / mất mạng / lỗi lạ', () {
      expect(loaiLoiNhaTu(loiServer(401, 'HOUSEHOLD_CLOSED')), LoaiLoiNha.phienHetHan,
          reason: '401 là phiên — AuthInterceptor lo; đừng đọc code của nó');
      expect(loaiLoiNhaTu(loiServer(503, 'MAINTENANCE_MODE')), LoaiLoiNha.mayChu);
      expect(loaiLoiNhaTu(loiMang(DioExceptionType.connectionError)), LoaiLoiNha.matMang);
      expect(loaiLoiNhaTu(loiMang(DioExceptionType.receiveTimeout)), LoaiLoiNha.matMang);
      expect(loaiLoiNhaTu(const LoiNha(LoaiLoiNha.nhaDu)), LoaiLoiNha.nhaDu);
      expect(loaiLoiNhaTu(StateError('x')), LoaiLoiNha.khac);
    });
  });
}
