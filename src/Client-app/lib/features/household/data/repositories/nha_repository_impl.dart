import 'dart:async';
import 'dart:ui' show AppLifecycleState;

import 'package:flutter/foundation.dart';

import '../../../../core/realtime/realtime_event.dart';
import '../../../../core/sync/sync_models.dart';
import '../../domain/cau_loi_nha.dart';
import '../../domain/ma_moi.dart';
import '../../domain/vai_nha.dart';
import '../datasources/household_api.dart';
import '../models/loi_moi.dart';
import '../models/nha_cua_toi.dart';
import '../nha_store.dart';
import 'nha_repository.dart';

class NhaRepositoryImpl implements NhaRepository {
  NhaRepositoryImpl({required HouseholdApi api, required NhaStore kho, DateTime Function()? clock})
      : _api = api,
        _kho = kho,
        _now = clock ?? DateTime.now {
    _hienTai = NhaCuaToi.khongCo(_now());
  }

  final HouseholdApi _api;
  final NhaStore _kho;
  final DateTime Function() _now;
  final _theoDoi = StreamController<NhaCuaToi>.broadcast();
  final _doiNha = StreamController<DoiNha>.broadcast();
  final _theoDoiLoiMoi = StreamController<List<LoiMoiToiEntity>>.broadcast();
  final _subs = <StreamSubscription<Object?>>[];

  late NhaCuaToi _hienTai;
  List<LoiMoiToiEntity> _loiMoiToi = const [];
  int? _idaccount;
  Future<void>? _dangLamMoi;
  Future<void>? _dangLamMoiLoiMoi;
  Future<void>? _dangNapKho;

  /// Hàng đợi áp trạng thái: hai lượt (làm mới + thao tác) cùng đọc nhà cũ trước khi lượt kia ghi là phát [DoiNha] hai lần.
  Future<void> _hangApDung = Future.value();

  @override
  NhaCuaToi get hienTai => _hienTai;
  @override
  Stream<NhaCuaToi> get theoDoi => _theoDoi.stream;
  @override
  Stream<DoiNha> get doiNha => _doiNha.stream;
  @override
  int? get idaccount => _idaccount;
  @override
  List<LoiMoiToiEntity> get loiMoiToi => _loiMoiToi;
  @override
  Stream<List<LoiMoiToiEntity>> get theoDoiLoiMoi => _theoDoiLoiMoi.stream;

  @override
  Future<void> choNapKho() => _dangNapKho ?? Future.value();

  void _phat(NhaCuaToi t) {
    _hienTai = t;
    if (!_theoDoi.isClosed) _theoDoi.add(t);
  }

  void _phatLoiMoi(List<LoiMoiToiEntity> ds) {
    _loiMoiToi = List.unmodifiable(ds);
    if (!_theoDoiLoiMoi.isClosed) _theoDoiLoiMoi.add(_loiMoiToi);
  }

  @override
  Future<void> datTaiKhoan(int idaccount) {
    _idaccount = idaccount;
    return _dangNapKho = _napKho(idaccount);
  }

  Future<void> _napKho(int id) async {
    final daLuu = await _kho.doc(id);
    if (_idaccount != id) return; // phiên đã đổi trong lúc chờ
    _phat(daLuu ?? NhaCuaToi.khongCo(_now()));
  }

  @override
  void xoaPhien() {
    _idaccount = null;
    _dangNapKho = null;
    _phat(NhaCuaToi.khongCo(_now()));
    _phatLoiMoi(const []);
  }

  @override
  Future<int?> nhaDaLuu(int idaccount) async => (await _kho.doc(idaccount))?.nha?.id;

  /// Nhà TRƯỚC, lời mời SAU — tuần tự để thứ tự lời gọi cố định (test canh) và `/me` không phải chờ `/invitations`.
  @override
  Future<void> lamMoi() {
    final dang = _dangLamMoi;
    if (dang != null) return dang;
    final f = _lamMoiNhaThat().then((_) => lamMoiLoiMoi()).whenComplete(() => _dangLamMoi = null);
    _dangLamMoi = f;
    return f;
  }

  Future<void> _lamMoiNhaThat() async {
    final id = _idaccount;
    if (id == null) return;
    try {
      await choNapKho(); // nhà "cũ" để so phải là bản trong kho
      final json = await _api.cuaToi();
      if (_idaccount != id) return;
      await _apDung(id, nhaCuaToiTuJson(json, nhanLuc: _now()));
    } catch (e) {
      debugPrint('[GiaDinh] lamMoi hỏng, giữ trạng thái cũ: ${e.runtimeType}');
    }
  }

  @override
  Future<void> lamMoiLoiMoi() {
    final dang = _dangLamMoiLoiMoi;
    if (dang != null) return dang;
    final f = _lamMoiLoiMoiThat().whenComplete(() => _dangLamMoiLoiMoi = null);
    _dangLamMoiLoiMoi = f;
    return f;
  }

  Future<void> _lamMoiLoiMoiThat() async {
    final id = _idaccount;
    if (id == null) return;
    try {
      final ds = [
        for (final j in await _api.dsLoiMoiToi())
          if (loiMoiToiTuJson(j) case final m?) m,
      ];
      if (_idaccount != id) return;
      _phatLoiMoi(ds);
    } catch (e) {
      debugPrint('[GiaDinh] lamMoiLoiMoi hỏng, giữ danh sách cũ: ${e.runtimeType}');
    }
  }

  @override
  Future<void> lamMoiNeuCu(Duration gian) {
    if (_idaccount == null) return Future.value();
    if (_now().difference(_hienTai.nhanLuc) < gian) return Future.value();
    return lamMoi();
  }

  Future<void> _apDung(int id, NhaCuaToi moi) {
    final f = _hangApDung.then((_) => _apDungNgay(id, moi));
    _hangApDung = f.catchError((Object _) {});
    return f;
  }

  Future<void> _apDungNgay(int id, NhaCuaToi moi) async {
    if (_idaccount != id) return;
    final tu = _hienTai.nha?.id;
    await _kho.ghi(id, moi);
    if (_idaccount != id) return;
    _phat(moi);
    final den = moi.nha?.id;
    if (tu != den && !_doiNha.isClosed) _doiNha.add(DoiNha(idaccount: id, tu: tu, den: den));
  }

  /// Lỗi bắt được → [LoiNha]; lỗi cho thấy nhà đã đổi nơi khác thì làm mới (không chờ).
  LoiNha _loi(Object e) {
    final loai = loaiLoiNhaTu(e);
    if (loiChoThayNhaDaDoi(loai)) unawaited(lamMoi());
    return LoiNha(loai);
  }

  Future<T> _goi<T>(Future<T> Function() goi) async {
    if (_idaccount == null) throw const LoiNha(LoaiLoiNha.khac);
    try {
      return await goi();
    } catch (e) {
      throw _loi(e);
    }
  }

  /// Thao tác đổi nhà. Thân LÀ trạng thái nhà (#1, #7, #9, #11, #15 — `laThanTrangThaiNha`) → áp như một lượt làm mới; thân
  /// KHÔNG phải (#8 `{targetIdaccount, newRole}`, #10 `{removed}`, #12 `{dissolved}` — `docs/Family/04` mục 2) → hỏi lại `/me`:
  /// đọc thân ấy là "chưa có nhà" → `DoiNha(nhà → null)` → máy chủ nhà tự xoá dữ liệu nhà sau một lần đổi vai (preflight
  /// 2026-10-28 #2). Hàng thô của #1 không có `members` (đơn 57.1): áp ngay cho nhà hiện tức thì rồi hỏi lại — hàng đợi áp
  /// trạng thái bảo đảm `DoiNha` phát MỘT lần (người dùng chốt 2026-10-28).
  Future<void> _thaoTac(Future<Map<String, Object?>> Function() goi) async {
    final id = _idaccount;
    await choNapKho();
    final json = await _goi(goi);
    if (id == null || _idaccount != id) return;
    if (!laThanTrangThaiNha(json)) {
      await lamMoi();
      return;
    }
    await _apDung(id, nhaCuaToiTuJson(json, nhanLuc: _now()));
    if (_hienTai.coNha && _hienTai.thanhVien.isEmpty) await lamMoi();
  }

  @override
  Future<void> taoNha(String ten) => _thaoTac(() => _api.taoNha(ten.trim()));

  @override
  Future<MaMoiEntity> taoMaMoi(VaiNha vai) async {
    final m = maMoiTuJson(await _goi(() => _api.taoMaMoi(khoaServerCuaVai(vai))));
    if (m == null) throw const LoiNha(LoaiLoiNha.khac);
    return m;
  }

  @override
  Future<List<MaMoiEntity>> dsMaMoi() async => [
        for (final j in await _goi(_api.dsMaMoi))
          if (maMoiTuJson(j) case final m?) m,
      ];

  @override
  Future<void> huyMaMoi(String ma) => _goi(() => _api.huyMaMoi(ma));

  @override
  Future<XemTruocLoiMoi> xemTruoc(String ma) async =>
      xemTruocTuJson(await _goi(() => _api.xemTruoc(chuanHoaMaMoi(ma))));

  @override
  Future<void> thamGia(String ma) => _thaoTac(() => _api.thamGia(chuanHoaMaMoi(ma)));

  @override
  Future<void> doiVai(int idaccount, VaiNha vai) => _thaoTac(() => _api.doiVai(idaccount, khoaServerCuaVai(vai)));

  @override
  Future<void> chuyenChu(int idaccount) => _thaoTac(() => _api.chuyenChu(idaccount));

  @override
  Future<void> moiRa(int idaccount) => _thaoTac(() => _api.moiRa(idaccount));

  @override
  Future<void> roiNha() => _thaoTac(_api.roiNha);

  @override
  Future<void> giaiTan() => _thaoTac(_api.giaiTan);

  @override
  Future<KetQuaMoiEmail> moiQuaEmail(String email, VaiNha vai) async =>
      ketQuaMoiEmailTuJson(await _goi(() => _api.moiQuaEmail(email.trim().toLowerCase(), khoaServerCuaVai(vai))));

  @override
  Future<void> chapNhanLoiMoi(String ma) => _thaoTac(() => _api.chapNhanLoiMoi(chuanHoaMaMoi(ma)));

  @override
  Future<void> tuChoiLoiMoi(String ma) async {
    await _goi(() => _api.tuChoiLoiMoi(chuanHoaMaMoi(ma)));
    await lamMoiLoiMoi();
  }

  @override
  void noiPhien(Stream<int?> phien) {
    int? daNoi;
    _subs.add(phien.listen((id) async {
      if (id == null) {
        daNoi = null;
        if (_idaccount != null) xoaPhien();
        return;
      }
      if (id == daNoi) return;
      daNoi = id;
      await datTaiKhoan(id);
      await lamMoi();
    }));
  }

  @override
  void noiVongDoi(Stream<AppLifecycleState> vongDoi, {Duration gian = const Duration(minutes: 5)}) {
    _subs.add(vongDoi.listen((s) {
      if (s == AppLifecycleState.resumed) unawaited(lamMoiNeuCu(gian));
    }));
  }

  @override
  void noiSuKien(Stream<RealtimeEvent> suKien) {
    _subs.add(suKien.listen((e) {
      if (e == RealtimeEvent.nhaDoi) unawaited(lamMoi());
      if (e == RealtimeEvent.loiMoiNha) unawaited(lamMoiLoiMoi());
    }));
  }

  @override
  void noiKetQuaDay(Stream<SyncResult> ketQua) {
    _subs.add(ketQua.listen((kq) {
      if (kq.failures.any((f) => kMaDayLoiNha.contains(f.code))) unawaited(lamMoi());
    }));
  }

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _theoDoi.close();
    await _doiNha.close();
    await _theoDoiLoiMoi.close();
  }
}
