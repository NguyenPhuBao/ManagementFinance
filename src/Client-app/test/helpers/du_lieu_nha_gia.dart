/// Nguồn dữ liệu nhà giả cho widget test của mảng gia đình: ví chung đọc từ một danh sách tiêm được, mọi lệnh ghi được ghi lại.
/// Chỉ phần ví chung và `hangChuaDay` có thật; phần còn lại rơi vào `noSuchMethod` (ném) để ca nào lỡ gọi thì đỏ ngay.
library;

import 'dart:async';

import 'package:flowmoney/features/household/data/repositories/du_lieu_nha_repository.dart';
import 'package:flowmoney/features/household/domain/hang_chua_day.dart';
import 'package:flowmoney/features/wallet/application/dieu_chinh_so_du_service.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';

WalletEntity viChungGia(
  String id,
  String ten,
  double soDu, {
  String loai = 'cash',
  String icon = 'payments',
  String mau = '#006E1C',
  String status = 'active',
  int idNha = 12,
}) =>
    WalletEntity(
      id: id,
      idaccount: 18,
      name: ten,
      type: loai,
      balance: soDu,
      icon: icon,
      colour: mau,
      status: status,
      idhousehold: idNha,
      includeInTotal: false,
      updatedAt: DateTime(2026, 11, 1),
    );

class DuLieuNhaGia implements DuLieuNhaRepository {
  DuLieuNhaGia({this.tra = const HangChuaDayNha(), List<WalletEntity> vi = const []}) : _vi = vi;

  final HangChuaDayNha tra;
  List<WalletEntity> _vi;
  final _ctl = StreamController<List<WalletEntity>>.broadcast();

  /// Lời gọi `hangChuaDay` (idNha, idaccount).
  final goi = <(int, int?)>[];
  final tao = <({int idNha, int idaccount, String ten, String loai, double soDu, String icon, String mau})>[];
  final sua = <WalletEntity>[];
  final luuTru = <({String id, bool luuTru})>[];
  final xoa = <String>[];

  /// Ném ở lệnh tương ứng (nếu khác `null`).
  Object? loiTao, loiLuuTru, loiXoa, loiSua;

  void datVi(List<WalletEntity> ds) {
    _vi = ds;
    _ctl.add(ds);
  }

  /// Nhà đã được theo dõi (mỗi lần dựng một cubit mới là một phần tử).
  final daTheoDoi = <int>[];

  @override
  Stream<List<WalletEntity>> theoDoiViChung(int idNha) async* {
    daTheoDoi.add(idNha);
    yield _vi;
    yield* _ctl.stream;
  }

  @override
  Future<HangChuaDayNha> hangChuaDay(int idNha, {required int? idaccount}) async {
    goi.add((idNha, idaccount));
    return tra;
  }

  @override
  Future<WalletEntity> taoViChung({
    required int idNha,
    required int idaccount,
    required String ten,
    required String loai,
    required double soDuBanDau,
    required String icon,
    required String mau,
  }) async {
    final loi = loiTao;
    if (loi != null) throw loi;
    tao.add((idNha: idNha, idaccount: idaccount, ten: ten, loai: loai, soDu: soDuBanDau, icon: icon, mau: mau));
    return viChungGia('moi', ten, soDuBanDau, loai: loai, icon: icon, mau: mau, idNha: idNha);
  }

  @override
  Future<void> suaViChung(WalletEntity vi) async {
    final loi = loiSua;
    if (loi != null) throw loi;
    sua.add(vi);
  }

  @override
  Future<void> luuTruViChung({required int idNha, required String id, required bool luuTru}) async {
    final loi = loiLuuTru;
    if (loi != null) throw loi;
    this.luuTru.add((id: id, luuTru: luuTru));
  }

  @override
  Future<void> xoaViChung({required int idNha, required String id}) async {
    final loi = loiXoa;
    if (loi != null) throw loi;
    xoa.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Chỉ `dieuChinh` có thật; ghi lại tham số.
class DieuChinhGia implements DieuChinhSoDuService {
  final goi = <({String walletId, double soDu, int? nguoiGhi})>[];
  Object? loi;

  @override
  Future<void> dieuChinh({
    required String walletId,
    required double soDuThucTe,
    required String lyDo,
    DateTime? vaoLuc,
    int? nguoiGhi,
  }) async {
    final l = loi;
    if (l != null) throw l;
    goi.add((walletId: walletId, soDu: soDuThucTe, nguoiGhi: nguoiGhi));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
