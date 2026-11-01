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

/// Cửa sổ giãn cách cho `household.changed`. Từ PR #170 backend từng phát sự kiện này sau MỖI `/sync/push` có hàng mang
/// `idhousehold` (hai GET `/me` + `/invitations` theo nhịp đẩy của cả nhà); từ `5ff06db4` đường đồng bộ KHÔNG còn phát nó
/// (`docs/Family/04` mục 2a — chỉ còn `sync.completed`). Nay nó chỉ tới từ thao tác nhà (vào / rời / mời ra / đổi vai / chuyển chủ
/// / trạng thái), nhưng thao tác dồn dập (mời ra nhiều người, đổi vai liền tay) vẫn nổ cả loạt: giãn cách là lớp phòng cho
/// chuyện đó. Luật: sự kiện đầu cửa sổ chạy ngay, các sự kiện trong cửa sổ gộp thành MỘT lượt bù lúc hết cửa sổ. Chỉ áp cho
/// `nhaDoi`; `loiMoiNha` hiếm và nhắm đúng người nên không giãn.
const Duration kGianCachNhaDoi = Duration(seconds: 30);

class NhaRepositoryImpl implements NhaRepository {
  /// [dayTruocKhiRoi] đẩy hàng chưa lên server và CHỜ xong (DI: `SyncEngine.dayVaCho`); [demHangChuaDay] đếm hàng `pending` của
  /// một nhà ở năm bảng đồng bộ (DI: `AppDatabase.demHangChuaDayCuaNha`). Không truyền = không đẩy / không chặn (test cũ).
  NhaRepositoryImpl({
    required HouseholdApi api,
    required NhaStore kho,
    DateTime Function()? clock,
    Future<void> Function()? dayTruocKhiRoi,
    Future<int> Function(int idNha)? demHangChuaDay,
  })  : _api = api,
        _kho = kho,
        _dayTruocKhiRoi = dayTruocKhiRoi,
        _demHangChuaDay = demHangChuaDay,
        _now = clock ?? DateTime.now {
    _hienTai = NhaCuaToi.khongCo(_now());
  }

  final HouseholdApi _api;
  final NhaStore _kho;
  final Future<void> Function()? _dayTruocKhiRoi;
  final Future<int> Function(int idNha)? _demHangChuaDay;
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
  _Luot _luotNha = _Luot();
  _Luot _luotLoiMoi = _Luot();

  /// Thế hệ trạng thái nhà: tăng khi một thao tác thành công (trước khi áp) và khi tài khoản đổi. Lượt /me ghi thế hệ TRƯỚC khi
  /// gửi; về mà thế hệ đã đổi thì ảnh chụp server là của trước thao tác — bỏ, lượt chạy bù (cờ [_Luot.bu]) hỏi lại.
  int _theHe = 0;

  /// Kỳ phiên: tăng khi tài khoản đổi — lượt lời mời của phiên cũ về muộn bị bỏ.
  int _kyPhien = 0;
  Future<void>? _dangNapKho;

  /// Kho trạng thái nhà của phiên này VẮNG (`doc` trả `null`: chưa ghi, mất, hoặc đọc hỏng) — khác kho GHI "không nhà".
  bool _khoVang = false;

  /// Dấu "đã xử lý tới nhà X" mà kho VẮNG không xác nhận được (spec gia đình 2026-11-01 mục 7.3): chưa biết đã rời nhà X hay chỉ
  /// mất kho, nên CHƯA phát [DoiNha] — phát `DoiNha(X → null)` lúc mở phiên làm `xoaHangCuaNha(X)` xoá luôn hàng chưa đẩy mà
  /// `purgeDataForOtherAccounts` vừa giữ. Hỏi `/me` rồi mới quyết, trong [_apDungNgay]. Hỏng thì giữ, lượt sau làm lại.
  int? _dauChoXacNhan;

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
    if (_idaccount != idaccount) _doiPhien();
    _idaccount = idaccount;
    return _dangNapKho = _napKho(idaccount);
  }

  Future<void> _napKho(int id) async {
    final daLuu = await _kho.doc(id);
    if (_idaccount != id) return; // phiên đã đổi trong lúc chờ
    _khoVang = daLuu == null;
    _phat(daLuu ?? NhaCuaToi.khongCo(_now()));
  }

  @override
  void xoaPhien() {
    _doiPhien();
    _idaccount = null;
    _dangNapKho = null;
    _phat(NhaCuaToi.khongCo(_now()));
    _phatLoiMoi(const []);
  }

  /// Tài khoản đổi: gỡ hai `Future` gộp (lượt của phiên cũ không được nhận làm lượt của phiên mới — nếu không tài khoản mới
  /// không bao giờ hỏi `/me`), tăng thế hệ / kỳ phiên để lượt cũ về muộn bị bỏ, xoá lời mời của tài khoản cũ.
  void _doiPhien() {
    _theHe++;
    _kyPhien++;
    _khoVang = false;
    _dauChoXacNhan = null;
    _dangLamMoi = null;
    _dangLamMoiLoiMoi = null;
    _huyGianCachNhaDoi();
    if (_loiMoiToi.isNotEmpty) _phatLoiMoi(const []);
  }

  @override
  Future<int?> nhaDaLuu(int idaccount) async => (await _kho.doc(idaccount))?.nha?.id;

  /// Nhà TRƯỚC, lời mời SAU — tuần tự để thứ tự lời gọi cố định (test canh) và `/me` không phải chờ `/invitations`.
  ///
  /// Lời gọi tới khi lượt đang bay CHƯA gửi `/me` thì gộp (một lời gọi). Tới SAU khi lượt đã gửi thì ảnh chụp server của lượt
  /// ấy có thể là của trước thao tác / sự kiện người gọi vừa biết → đặt cờ chạy bù: lượt đang bay chạy thêm một vòng, gửi
  /// SAU yêu cầu, rồi mới hoàn tất — `await lamMoi()` luôn nhận kết quả của một lượt gửi sau lời gọi.
  @override
  Future<void> lamMoi() {
    final dang = _dangLamMoi;
    if (dang != null) {
      if (_luotNha.daGui) _luotNha.bu = true;
      return dang;
    }
    final luot = _luotNha = _Luot();
    late final Future<void> f;
    f = _chayLamMoi(luot).whenComplete(() {
      if (identical(_dangLamMoi, f)) _dangLamMoi = null;
    });
    _dangLamMoi = f;
    return f;
  }

  Future<void> _chayLamMoi(_Luot luot) async {
    final id = _idaccount;
    if (id == null) return;
    do {
      luot.bu = false;
      luot.daGui = false;
      await _vongNha(luot, id);
      await lamMoiLoiMoi();
    } while (luot.bu && _idaccount == id);
  }

  Future<void> _vongNha(_Luot luot, int id) async {
    try {
      await choNapKho(); // nhà "cũ" để so phải là bản trong kho
      if (_idaccount != id) return;
      final he = _theHe;
      luot.daGui = true;
      final json = await _api.cuaToi();
      if (_idaccount != id) return;
      // Cùng chốt với `_thaoTac`: thân 200 không có khoá `household` (rỗng, hình dạng lạ) đọc thành "không nhà" →
      // `DoiNha(nhà → null)` → xoá hàng nhà. `{household: null, …}` có khoá nên vẫn qua.
      if (!laThanTrangThaiNha(json)) {
        debugPrint('[GiaDinh] lamMoi: thân /me không phải trạng thái nhà, giữ trạng thái cũ');
        return;
      }
      await _apDung(id, nhaCuaToiTuJson(json, nhanLuc: _now()), he: he);
    } catch (e) {
      debugPrint('[GiaDinh] lamMoi hỏng, giữ trạng thái cũ: ${e.runtimeType}');
    }
  }

  @override
  Future<void> lamMoiLoiMoi() {
    final dang = _dangLamMoiLoiMoi;
    if (dang != null) {
      if (_luotLoiMoi.daGui) _luotLoiMoi.bu = true;
      return dang;
    }
    final luot = _luotLoiMoi = _Luot();
    late final Future<void> f;
    f = _chayLoiMoi(luot).whenComplete(() {
      if (identical(_dangLamMoiLoiMoi, f)) _dangLamMoiLoiMoi = null;
    });
    _dangLamMoiLoiMoi = f;
    return f;
  }

  Future<void> _chayLoiMoi(_Luot luot) async {
    final id = _idaccount;
    if (id == null) return;
    do {
      luot.bu = false;
      final ky = _kyPhien;
      try {
        luot.daGui = true;
        final ds = [
          for (final j in await _api.dsLoiMoiToi())
            if (loiMoiToiTuJson(j) case final m?) m,
        ];
        if (_idaccount == id && _kyPhien == ky) _phatLoiMoi(ds);
      } catch (e) {
        debugPrint('[GiaDinh] lamMoiLoiMoi hỏng, giữ danh sách cũ: ${e.runtimeType}');
      }
    } while (luot.bu && _idaccount == id);
  }

  @override
  Future<void> lamMoiNeuCu(Duration gian) {
    if (_idaccount == null) return Future.value();
    if (_now().difference(_hienTai.nhanLuc) < gian) return Future.value();
    return lamMoi();
  }

  Future<void> _apDung(int id, NhaCuaToi moi, {int? he}) {
    final f = _hangApDung.then((_) => _apDungNgay(id, moi, he));
    _hangApDung = f.catchError((Object _) {});
    return f;
  }

  Future<void> _apDungNgay(int id, NhaCuaToi moi, int? he) async {
    if (_idaccount != id) return;
    if (he != null && he != _theHe) return; // ảnh chụp trước một thao tác đã thành công — bỏ
    var tu = _hienTai.nha?.id;
    final den = moi.nha?.id;
    // Kho vắng + dấu nói nhà X (xem [_dauChoXacNhan]): server là người quyết. Vẫn ở X → `DoiNha(null → X)` kéo lại toàn bộ
    // (purge đã xoá hàng đã đồng bộ; hàng chưa đẩy ở lại); không còn ở X → dọn X như đã rời.
    final dau = _dauChoXacNhan;
    if (dau != null && tu == null) tu = den == dau ? null : dau;
    await _kho.ghi(id, moi);
    if (_idaccount != id) return;
    _dauChoXacNhan = null;
    _phat(moi);
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
  /// 2026-10-28 #2). Thân #1 từ PR #172 đã lồng, đủ `members` (`docs/Family/04` mục 2a): áp một lần, không hỏi lại.
  Future<void> _thaoTac(Future<Map<String, Object?>> Function() goi) async {
    final id = _idaccount;
    await choNapKho();
    final json = await _goi(goi);
    if (id == null || _idaccount != id) return;
    _theHe++; // ảnh chụp /me gửi trước thao tác này (đang bay) không còn được áp
    if (!laThanTrangThaiNha(json)) {
      await lamMoi();
      return;
    }
    await _apDung(id, nhaCuaToiTuJson(json, nhanLuc: _now()));
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
  Future<void> thamGia(String ma) async {
    await _thaoTac(() => _api.thamGia(chuanHoaMaMoi(ma)));
    // Mã trong thư của chính nhà vừa vào: thẻ lời mời email của nhà ấy hết chờ (01 mục 2.1; I2).
    await lamMoiLoiMoi();
  }

  @override
  Future<void> doiVai(int idaccount, VaiNha vai) => _thaoTac(() => _api.doiVai(idaccount, khoaServerCuaVai(vai)));

  @override
  Future<void> chuyenChu(int idaccount) => _thaoTac(() => _api.chuyenChu(idaccount));

  @override
  Future<void> moiRa(int idaccount) => _thaoTac(() => _api.moiRa(idaccount));

  /// Trước khi Rời / Giải tán (spec 2026-11-01 mục 7.3): đẩy (lỗi của hook chỉ ghi log — mất mạng thì API cũng tự báo đúng
  /// câu), đếm hàng của nhà còn chưa đẩy, còn mà không [boQua] thì ném — API CHƯA được gọi. Phép đếm hỏng coi như còn hàng.
  Future<void> _chuanBiRoi({required bool boQua}) async {
    try {
      await _dayTruocKhiRoi?.call();
    } catch (e) {
      debugPrint('[GiaDinh] đẩy trước khi rời hỏng: ${e.runtimeType}');
    }
    final dem = _demHangChuaDay;
    final nha = _hienTai.nha?.id; // đọc SAU lượt đẩy: lượt đẩy có thể đã làm mới trạng thái nhà
    if (boQua || dem == null || nha == null) return;
    var con = 1;
    try {
      con = await dem(nha);
    } catch (e) {
      debugPrint('[GiaDinh] đếm hàng chưa đẩy hỏng, coi như còn: ${e.runtimeType}');
    }
    if (con > 0) throw const LoiNha(LoaiLoiNha.hangChuaDay);
  }

  @override
  Future<void> roiNha({bool boQuaHangChuaDay = false}) async {
    await _chuanBiRoi(boQua: boQuaHangChuaDay);
    await _thaoTac(_api.roiNha);
  }

  @override
  Future<void> giaiTan({bool boQuaHangChuaDay = false}) async {
    await _chuanBiRoi(boQua: boQuaHangChuaDay);
    await _thaoTac(_api.giaiTan);
  }

  @override
  Future<KetQuaMoiEmail> moiQuaEmail(String email, VaiNha vai) async =>
      ketQuaMoiEmailTuJson(await _goi(() => _api.moiQuaEmail(email.trim().toLowerCase(), khoaServerCuaVai(vai))));

  static bool _loiMoiDaChet(LoaiLoiNha l) =>
      l == LoaiLoiNha.maHetHan ||
      l == LoaiLoiNha.maKhongCo ||
      l == LoaiLoiNha.maDaDung ||
      l == LoaiLoiNha.loiMoiDaTuChoi;

  @override
  Future<void> chapNhanLoiMoi(String ma) async {
    try {
      await _thaoTac(() => _api.chapNhanLoiMoi(chuanHoaMaMoi(ma)));
    } on LoiNha catch (e) {
      if (_loiMoiDaChet(e.loai)) await lamMoiLoiMoi();
      rethrow;
    }
    await lamMoiLoiMoi(); // 01 mục 2.8: lời mời vừa nhận không còn nằm trong danh sách
  }

  @override
  Future<void> tuChoiLoiMoi(String ma) async {
    try {
      await _goi(() => _api.tuChoiLoiMoi(chuanHoaMaMoi(ma)));
    } on LoiNha catch (e) {
      if (_loiMoiDaChet(e.loai)) await lamMoiLoiMoi();
      rethrow;
    }
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
      await _doiChieuDauXuLy(id);
      await lamMoi();
    }));
  }

  /// Dấu "đã xử lý tới nhà X" lệch kho ⇒ lần trước tiến trình chết giữa chừng, phát lại đúng cặp (G113 lỗ hổng 1). Chỉ ở đây, từ
  /// kho: `DoiNha` của `lamMoi` chỉ phát khi server khác kho, nên không chạy hai lần cho một cặp.
  Future<void> _doiChieuDauXuLy(int id) async {
    final dau = await _kho.docDauXuLy(id);
    final nha = _hienTai.nha?.id;
    if (_idaccount != id || dau == nha) return;
    // Kho VẮNG (khác kho ghi "không nhà"): không biết đã rời nhà hay chỉ mất kho → chưa dọn, hỏi `/me` (spec 7.3).
    if (_khoVang) {
      _dauChoXacNhan = dau;
      return;
    }
    if (!_doiNha.isClosed) _doiNha.add(DoiNha(idaccount: id, tu: dau, den: nha));
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
      if (e == RealtimeEvent.nhaDoi) _khiNhaDoi();
      if (e == RealtimeEvent.loiMoiNha) unawaited(lamMoiLoiMoi());
    }));
  }

  Timer? _henNhaDoi; // != null ⇔ cửa sổ đang mở
  bool _choBuNhaDoi = false;

  void _khiNhaDoi() {
    if (_henNhaDoi != null) {
      _choBuNhaDoi = true;
      return;
    }
    unawaited(lamMoi());
    _henNhaDoi = Timer(kGianCachNhaDoi, _hetCuaSoNhaDoi);
  }

  void _hetCuaSoNhaDoi() {
    _henNhaDoi = null;
    if (!_choBuNhaDoi) return;
    _choBuNhaDoi = false;
    _khiNhaDoi();
  }

  void _huyGianCachNhaDoi() {
    _henNhaDoi?.cancel();
    _henNhaDoi = null;
    _choBuNhaDoi = false;
  }

  @override
  void noiKetQuaDay(Stream<SyncResult> ketQua) {
    _subs.add(ketQua.listen((kq) {
      if (kq.failures.any((f) => kMaDayLoiNha.contains(f.code))) unawaited(lamMoi());
    }));
  }

  @override
  Future<void> dispose() async {
    _huyGianCachNhaDoi();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _theoDoi.close();
    await _doiNha.close();
    await _theoDoiLoiMoi.close();
  }
}

/// Một lượt làm mới: [daGui] = đã gửi lời gọi mạng của vòng hiện tại; [bu] = có yêu cầu tới sau đó, cần chạy thêm một vòng.
class _Luot {
  bool daGui = false;
  bool bu = false;
}
