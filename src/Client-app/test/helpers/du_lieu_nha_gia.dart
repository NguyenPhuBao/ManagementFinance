/// Nguồn dữ liệu nhà giả cho widget test của mảng gia đình: ví chung đọc từ một danh sách tiêm được, mọi lệnh ghi được ghi lại.
/// Chỉ phần ví chung và `hangChuaDay` có thật; phần còn lại rơi vào `noSuchMethod` (ném) để ca nào lỡ gọi thì đỏ ngay.
library;

import 'dart:async';

import 'package:flowmoney/features/category/data/models/category_entity.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/household/data/repositories/du_lieu_nha_repository.dart';
import 'package:flowmoney/features/household/domain/muc_tieu_chung.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
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

  List<TransactionEntity> _khoan = const [];
  List<CategoryEntity> _danhMuc = const [];
  final _ctlKhoan = StreamController<List<TransactionEntity>>.broadcast();
  final _ctlDanhMuc = StreamController<List<CategoryEntity>>.broadcast();

  /// Lời gọi `theoDoiKhoan` (idNha, walletId) và `theoDoiBangTraDanhMuc` (idaccount).
  final goiKhoan = <(int, String?)>[];
  final goiBangTra = <int>[];

  /// Đổi danh sách khoản của nhà (phát ngay cho người đang nghe).
  void datKhoan(List<TransactionEntity> ds) {
    _khoan = ds;
    _ctlKhoan.add(ds);
  }

  void datDanhMuc(List<CategoryEntity> ds) {
    _danhMuc = ds;
    _ctlDanhMuc.add(ds);
  }

  @override
  Stream<List<TransactionEntity>> theoDoiKhoan(int idNha, {String? walletId}) async* {
    goiKhoan.add((idNha, walletId));
    yield _khoan;
    yield* _ctlKhoan.stream;
  }

  @override
  Stream<List<CategoryEntity>> theoDoiBangTraDanhMuc(int idaccount) async* {
    goiBangTra.add(idaccount);
    yield _danhMuc;
    yield* _ctlDanhMuc.stream;
  }

  final _cay = <String, CategoryTree>{};
  final _ctlCay = StreamController<MapEntry<String, CategoryTree>>.broadcast();

  /// Lời gọi `theoDoiCayDanhMuc` (idNha, classify).
  final goiCay = <(int, String)>[];

  /// Đặt cây của một phân loại (phát ngay cho người đang nghe); phân loại chưa đặt là cây rỗng.
  void datCay(String classify, CategoryTree cay) {
    _cay[classify] = cay;
    _ctlCay.add(MapEntry(classify, cay));
  }

  static CategoryTree _cayRong() =>
      CategoryTree(groups: const [], ungroupedChildren: const [], defaultChildren: const []);

  @override
  Stream<CategoryTree> theoDoiCayDanhMuc(int idNha, String classify) async* {
    goiCay.add((idNha, classify));
    yield _cay[classify] ?? _cayRong();
    yield* _ctlCay.stream.where((e) => e.key == classify).map((e) => e.value);
  }

  @override
  Future<HangChuaDayNha> hangChuaDay(int idNha, {required int? idaccount}) async {
    goi.add((idNha, idaccount));
    return tra;
  }

  /// Lời gọi `viChungChoForm` (idNha, giuLai, uuTien); ném `loiChoForm` nếu có.
  final goiChoForm = <(int, Set<String>, String?)>[];
  Object? loiChoForm;

  /// Như bản thật: ví đang hoạt động cộng ví trong [giuLai] dù lưu trữ, ví [uuTien] đứng đầu.
  @override
  Future<List<WalletEntity>> viChungChoForm(int idNha, {Set<String> giuLai = const {}, String? uuTien}) async {
    goiChoForm.add((idNha, giuLai, uuTien));
    final loi = loiChoForm;
    if (loi != null) throw loi;
    final ds = [for (final v in _vi) if (!v.isDeleted && (v.status == 'active' || giuLai.contains(v.id))) v];
    final dau = ds.where((v) => v.id == uuTien).toList();
    return [...dau, ...ds.where((v) => v.id != uuTien)];
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
    DatMucTieu? mucTieu,
  }) async {
    final loi = loiTao;
    if (loi != null) throw loi;
    taoMuc.add(mucTieu);
    tao.add((idNha: idNha, idaccount: idaccount, ten: ten, loai: loai, soDu: soDuBanDau, icon: icon, mau: mau));
    return viChungGia('moi', ten, soDuBanDau, loai: loai, icon: icon, mau: mau, idNha: idNha);
  }

  @override
  Future<void> suaViChung(WalletEntity vi, {ThayDoiMucTieu mucTieu = const GiuMucTieu()}) async {
    final loi = loiSua;
    if (loi != null) throw loi;
    sua.add(vi);
    suaMuc.add(mucTieu);
  }

  /// Mục tiêu đi kèm mỗi lệnh tạo / sửa ví (cùng thứ tự với `tao` / `sua`).
  final suaMuc = <ThayDoiMucTieu>[];
  final taoMuc = <DatMucTieu?>[];

  List<GoalEntity> _muc = const [];
  final _ctlMuc = StreamController<List<GoalEntity>>.broadcast();

  void datMucTieu(List<GoalEntity> ds) {
    _muc = ds;
    _ctlMuc.add(ds);
  }

  @override
  Stream<List<GoalEntity>> theoDoiMucTieuChung(int idNha) async* {
    yield _muc;
    yield* _ctlMuc.stream;
  }

  @override
  Future<List<({GoalEntity mucTieu, WalletEntity vi})>> mucTieuKemVi(int idNha) async => const [];

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
