/// API gia đình GIẢ cho test. Mỗi lời gọi ghi vào [goi]; [loi] khác `null` thì MỌI lời gọi ném nó; [treo] giữ lời gọi lại tới
/// khi hoàn thành. [cuaToiJson] là thân `GET /households/me`; thao tác trả trạng thái trả [traVe] (mặc định [cuaToiJson]).
/// Hình dạng mẫu: [nhaJson] (lồng, `docs/Family/01` mục 4 — hình dạng duy nhất của backend từ PR #172).
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flowmoney/features/household/data/datasources/household_api.dart';

/// `doiVai`, `moiRa`, `giaiTan` không trả trạng thái nhà, nên repository hỏi lại `/me` ([cuaToiJson]): test muốn giả nhà
/// đổi sau thao tác thì đổi [cuaToiJson] trước khi gọi.
class HouseholdApiGia implements HouseholdApi {
  Map<String, Object?> cuaToiJson = const {'household': null};
  Map<String, Object?>? traVe;
  Object? loi;
  Completer<void>? treo;

  /// Chỉ giữ lời gọi `dsMaMoi` (không đụng `treo`); [loiHuy] chỉ ném ở `huyMaMoi`.
  Completer<void>? treoDsMaMoi;

  /// Giữ riêng `huyMaMoi` của từng mã.
  final treoHuyTheoMa = <String, Completer<void>>{};
  Object? loiHuy;
  final goi = <String>[];
  Map<String, Object?> maMoiJson = const {
    'code': 'ABCD2345',
    'role': 'Member',
    'expiresAt': '2026-10-26T08:00:00.000Z'
  };
  List<Map<String, Object?>> dsMaMoiJson = const [];
  Map<String, Object?> xemTruocJson = const {
    'householdName': 'Nhà An – Bình',
    'ownerName': 'Trần An',
    'memberCount': 2,
    'maxMembers': 6,
    'role': 'Member',
    'expiresAt': '2026-10-26T08:00:00.000Z',
  };
  List<Map<String, Object?>> dsLoiMoiToiJson = const [];
  Map<String, Object?> moiEmailJson = const {
    'sent': true,
    'email': 'an@x.com',
    'role': 'Member',
    'expiresAt': '2026-11-02T08:00:00.000Z',
  };

  Future<T> _chay<T>(String ten, T Function() ketQua) async {
    goi.add(ten);
    final t = treo;
    if (t != null) await t.future;
    final l = loi;
    if (l != null) throw l;
    return ketQua();
  }

  Map<String, Object?> _trangThai() => traVe ?? cuaToiJson;

  @override
  Future<Map<String, Object?>> cuaToi() => _chay('cuaToi', () => cuaToiJson);
  @override
  Future<Map<String, Object?>> taoNha(String ten) => _chay('taoNha:$ten', _trangThai);
  @override
  Future<Map<String, Object?>> taoMaMoi(String vai) => _chay('taoMaMoi:$vai', () => maMoiJson);
  @override
  Future<List<Map<String, Object?>>> dsMaMoi() async {
    final r = await _chay('dsMaMoi', () => dsMaMoiJson);
    await treoDsMaMoi?.future;
    return r;
  }
  @override
  Future<void> huyMaMoi(String ma) => _chay('huyMaMoi:$ma', () async {
        await treoHuyTheoMa[ma]?.future;
        final l = loiHuy;
        if (l != null) throw l;
      });
  @override
  Future<Map<String, Object?>> xemTruoc(String ma) => _chay('xemTruoc:$ma', () => xemTruocJson);
  @override
  Future<Map<String, Object?>> thamGia(String ma) => _chay('thamGia:$ma', _trangThai);
  @override
  Future<Map<String, Object?>> doiVai(int idaccount, String vai) =>
      _chay('doiVai:$idaccount:$vai', () => traVe ?? {'targetIdaccount': idaccount, 'newRole': vai});
  @override
  Future<Map<String, Object?>> chuyenChu(int idaccount) => _chay('chuyenChu:$idaccount', _trangThai);
  @override
  Future<Map<String, Object?>> moiRa(int idaccount) =>
      _chay('moiRa:$idaccount', () => traVe ?? const {'removed': true});
  @override
  Future<Map<String, Object?>> roiNha() => _chay('roiNha', () => traVe ?? const {'household': null, 'myRole': null, 'members': [], 'formerMembers': []});
  @override
  Future<Map<String, Object?>> giaiTan() => _chay('giaiTan', () => traVe ?? const {'dissolved': true});
  @override
  Future<Map<String, Object?>> moiQuaEmail(String email, String vai) =>
      _chay('moiQuaEmail:$email:$vai', () => moiEmailJson);
  @override
  Future<List<Map<String, Object?>>> dsLoiMoiToi() => _chay('dsLoiMoiToi', () => dsLoiMoiToiJson);
  @override
  Future<Map<String, Object?>> chapNhanLoiMoi(String ma) => _chay('chapNhanLoiMoi:$ma', _trangThai);
  @override
  Future<void> tuChoiLoiMoi(String ma) => _chay('tuChoiLoiMoi:$ma', () {});
}

/// Thân trạng thái nhà theo `docs/Family/01` mục 4 — hình dạng LỒNG, đích (tên thành viên là dữ liệu mẫu, không phải người
/// thật).
Map<String, Object?> nhaJson({
  int id = 12,
  String ten = 'Nhà An – Bình',
  String status = 'Active',
  String myRole = 'Owner',
  int maxMembers = 6,
  List<Map<String, Object?>>? members,
}) =>
    {
      'household': {
        'id': id,
        'name': ten,
        'status': status,
        'maxMembers': maxMembers,
        'ownerId': 18,
        'createAt': '2026-10-23T08:00:00.000Z',
        'maxSharedWallets': 10,
      },
      'myRole': myRole,
      'members': members ??
          [
            {'idaccount': 18, 'displayName': 'Trần An', 'role': 'Owner', 'joinedAt': '2026-10-23T08:00:00.000Z'},
            {'idaccount': 25, 'displayName': 'Nguyễn Bình', 'role': 'Member', 'joinedAt': '2026-10-23T09:12:00.000Z'},
          ],
      'formerMembers': [
        {'idaccount': 31, 'displayName': 'Lê Bình', 'leftAt': '2026-10-24T03:00:00.000Z'},
      ],
    };

/// Lỗi 4xx của server, `code` ở cấp gốc (đơn 50 C.3; `middleware/error-handler.js`).
DioException loiServer(int status, String code) {
  final r = RequestOptions(path: '/households');
  return DioException(
    requestOptions: r,
    response: Response<Object?>(
      requestOptions: r,
      statusCode: status,
      data: {'success': false, 'statusCode': status, 'code': code, 'message': code},
    ),
    type: DioExceptionType.badResponse,
  );
}
