// lib/features/transaction/presentation/bloc/them_giao_dich_cubit.dart
/// Trạng thái và quyết định của form Thêm / Sửa giao dịch (spec `2026-10-11-tach-trang-them-giao-dich-cubit-design.md`).
///
/// Mỗi hành động người dùng một hàm. Cubit KHÔNG biết `BuildContext`: không hộp thoại, không toast, không gửi event cho
/// `TransactionBloc` — trang làm. Mọi đọc / ghi dữ liệu qua [ThemGiaoDichNguon].
///
/// ⚠️ Luật xuyên suốt (C2, D1, C4): mỗi ô được điền đi ĐÚNG đường người dùng vẫn đi — chiều qua [chonHuong], số tiền
/// qua `themPhimSoTien`, danh mục qua [chonDanhMuc] — để mọi hệ quả chạy như khi chạm tay.
library;

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/database/app_database.dart';
import '../../../category/data/services/category_suggestion_engine.dart';
import '../../../category/domain/category_classify.dart';
import '../../../category/domain/gan_hang_loat.dart' show hopLeTheoChieu;
import '../../../category/domain/phan_loai_ghi_chu.dart';
import '../../../category/domain/phan_loai_so_tien.dart';
import '../../data/models/transaction_entity.dart';
import '../../data/them_giao_dich_nguon.dart';
import '../../domain/ban_phim_so_tien.dart';
import '../../domain/dien_san_bien_dong.dart';
import '../../domain/tach_giao_dich.dart';
import '../../domain/vi_chon_san.dart';
import 'them_giao_dich_state.dart';

class ThemGiaoDichCubit extends Cubit<ThemGiaoDichState> {
  ThemGiaoDichCubit({
    required ThemGiaoDichNguon nguon,
    required int? Function() taiKhoan,
    required CategorySuggestionEngine boGoiY,
    TransactionEntity? dangSua,
    Category? danhMucDangSua,
    String? huongBanDau,
    DienSanBienDong? bienDong,
    bool choTickMon = false,
  })  : _nguon = nguon,
        _taiKhoan = taiKhoan,
        _boGoiY = boGoiY,
        _dangSua = dangSua,
        _bienDong = dangSua == null ? bienDong : null,
        _choTickMon = choTickMon,
        super(_dauTien(dangSua, danhMucDangSua, huongBanDau, dangSua == null ? bienDong : null));

  final ThemGiaoDichNguon _nguon;

  /// Mã tài khoản của phiên, đọc ở MỖI lần cần (như `_accountId` của trang) — không chụp một lần lúc mở.
  final int? Function() _taiKhoan;
  // ignore: unused_field — Task 3 (thẻ gợi ý, Nhập nhanh) dùng.
  final CategorySuggestionEngine _boGoiY;
  final TransactionEntity? _dangSua;

  /// D1 / biên lai / A5 — `null` ở đường sửa.
  final DienSanBienDong? _bienDong;
  // ignore: unused_field — Task 4 (D1 / ảnh quét) dùng.
  final bool _choTickMon;

  /// ⚠️ Chốt quan trọng nhất của chặng 1.2: một phép đoán từ lịch sử KHÔNG BAO GIỜ đè lựa chọn người dùng vừa làm.
  bool _nguoiDungDaChonVi = false;
  Map<String, String> _viHayDung = const {};
  BoPhanLoaiGhiChu? _boPhanLoai;
  BoPhanLoaiSoTien? _boSoTien;
  List<MauGhiChu>? _mauDeXuat;

  bool get laSua => _dangSua != null;
  DienSanBienDong? get bienDong => _bienDong;

  // ⏳ TẠM (trang lai): cụm gợi ý còn ở trang tới Task 3 / Task 4. Gỡ theo bảng "Mã nối tạm" của kế hoạch.
  BoPhanLoaiGhiChu? get boPhanLoai => _boPhanLoai;
  BoPhanLoaiSoTien? get boSoTien => _boSoTien;
  List<MauGhiChu>? get mauDeXuat => _mauDeXuat;

  static ThemGiaoDichState _dauTien(
      TransactionEntity? dangSua, Category? danhMuc, String? huongBanDau, DienSanBienDong? bienDong) {
    if (dangSua != null) {
      final a = dangSua.amount;
      final chuoi = a == a.roundToDouble() ? a.toInt().toString() : a.toString();
      return ThemGiaoDichState(
        laSua: true,
        huong: dangSua.type,
        chuoiSoTien: chuoi,
        hienBanPhimSo: chuoi == '0',
        ngay: dangSua.date,
        ghiChu: dangSua.note,
        danhMuc: danhMuc,
        // Chiều tiền đã chọn lúc tạo nằm ở `type`; không gợi lại theo tên.
        chieuNo: danhMuc != null && isDebtClassify(danhMuc.classify) ? dangSua.type : null,
      );
    }
    return ThemGiaoDichState(
      laSua: false,
      huong: const {'chi', 'thu', 'transfer'}.contains(huongBanDau) ? huongBanDau! : 'chi',
      chuoiSoTien: '0',
      // D1 điền số tiền SAU (chờ ví + mô hình) — quyết từ tin ngay lúc mở, kẻo 16 phím chớp lên rồi tắt.
      hienBanPhimSo: bienDong?.soTien == null,
      ngay: DateTime.now(),
    );
  }

  void _phat(ThemGiaoDichState s) {
    if (!isClosed) emit(s);
  }

  /// Nạp mọi thứ lúc mở form. Đường tiêm sẵn (ví, lịch sử) chạy ĐỒNG BỘ — khung đầu đã có ví, như trước đợt tách.
  Future<void> moTrang() async {
    await Future.wait([_napVi(), _napLichSu()]);
  }

  Future<void> _napVi() async {
    final r = _nguon.napViDangDung(_taiKhoan());
    final ds = r is List<Wallet> ? r : await r;
    if (isClosed) return;
    final chon = chonViChonSan<Wallet>(ds, laMacDinh: (w) => w.isDefault);
    var nguon = chon.nguon;
    var dich = chon.dich;
    // Ở chế độ sửa, ví của giao dịch phải thắng ví đầu danh sách.
    final sua = _dangSua;
    if (sua != null) {
      nguon = _timVi(ds, sua.walletId) ?? nguon;
      dich = _timVi(ds, sua.walletTransfer) ?? dich;
    }
    emit(state.copyWith(vi: ds, viNguon: nguon, viDich: dich, dangNapVi: false));
  }

  /// MỘT lần đọc sổ cho bảng ví hay dùng và hai mô hình gợi ý.
  Future<void> _napLichSu() async {
    final r = _nguon.napLichSu(_taiKhoan(), dangSua: _dangSua?.id);
    final ls = r is LichSuHoc ? r : await r;
    if (isClosed) return;
    _viHayDung = ls.viHayDung;
    _boPhanLoai = ls.boPhanLoai;
    _boSoTien = ls.boSoTien;
    _mauDeXuat = ls.mauDeXuat;
  }

  static Wallet? _timVi(List<Wallet> ds, String? id) {
    if (id == null) return null;
    for (final w in ds) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// Phép gõ ở `domain/ban_phim_so_tien.dart`. ⚠️ Màn này tự vẽ bàn phím nên `inputFormatters` không với tới — trần 13
  /// chữ số (`numeric(15,2)`) phải chặn ngay trong phép gõ, kẻo giao dịch kẹt hàng đợi đẩy vĩnh viễn, im lặng.
  void goPhim(String k) {
    _phat(state.copyWith(chuoiSoTien: themPhimSoTien(state.chuoiSoTien, k)));
  }

  /// Chạm khối số tiền. Bàn phím hệ thống đang mở (gõ ghi chú) thì 16 phím bị G58 giấu dù cờ bật — đảo cờ lúc ấy là tắt
  /// phím mà người dùng không thấy gì đổi; nên MỞ 16 phím (trang tự đóng bàn phím hệ thống).
  void chamSoTien({required bool banPhimHeThongMo}) =>
      _phat(state.copyWith(hienBanPhimSo: banPhimHeThongMo || !state.hienBanPhimSo));

  /// Điền một số (chip của ảnh quét, điền sẵn) — từng chữ số qua `themPhimSoTien`, cùng trần; ẩn 16 phím.
  void chonSoTien(double v) => _phat(state.copyWith(chuoiSoTien: _goSo(v), hienBanPhimSo: false));

  static String _goSo(double v) {
    var a = '0';
    for (final c in v.toInt().toString().split('')) {
      a = themPhimSoTien(a, c);
    }
    return a;
  }

  /// Chạm một đoạn Chi tiêu / Thu nhập / Chuyển khoản. Vay/nợ gom cả hai chiều: đoạn chính là công tắc chiều tiền;
  /// danh mục thuộc chiều kia thì bỏ — giữ danh mục chi dưới đoạn Thu là hai sự thật trái nhau.
  void chonHuong(String huong) {
    var s = state.copyWith(huong: huong);
    // Tách chỉ cho khoản chi (spec A5 11.1 ý 1).
    if (huong != 'chi') s = s.copyWith(phanTach: const []);
    final cat = state.danhMuc;
    if (huong != 'transfer' && cat != null) {
      if (isDebtClassify(cat.classify)) {
        s = s.copyWith(chieuNo: huong);
      } else if ((cat.classify == 'thu' ? 'thu' : 'chi') != huong) {
        s = s.copyWith(danhMuc: null);
      }
    }
    _phat(s);
  }

  /// Đường DUY NHẤT để đặt danh mục — bảng chọn, thẻ gợi ý, điền sẵn đều qua đây, để chiều tiền vay/nợ luôn được gợi
  /// sẵn kèm theo. Danh mục là sự thật, đoạn đầu màn phản ánh nó.
  void chonDanhMuc(Category c) {
    final laVayNo = isDebtClassify(c.classify);
    final no = laVayNo ? suggestDebtDirection(c.name) : null;
    _phat(state.copyWith(
      danhMuc: c,
      // A5 11.2: danh mục chính mới trùng một phần đang tách → phần ấy gộp vào phần chính.
      phanTach: gopKhiDoiDanhMucChinh(c.id, state.phanTach),
      viNguon: _viHayDungCho(c) ?? state.viNguon,
      chieuNo: no,
      huong: laVayNo ? (no ?? 'chi') : (c.classify == 'thu' ? 'thu' : 'chi'),
    ));
  }

  /// Ví người dùng HAY DÙNG cho [c] — ba cửa chặn: đang sửa (ví của giao dịch là sự thật), người dùng đã tự đặt ví
  /// (lựa chọn cố ý thắng phép đoán), tra không thấy (`null` = chưa biết → giữ ví đang có).
  Wallet? _viHayDungCho(Category c) {
    if (_dangSua != null || _nguoiDungDaChonVi) return null;
    return _timVi(state.vi, _viHayDung[c.id]);
  }

  void chonChieuNo(String d) => _phat(state.copyWith(chieuNo: d, huong: d));

  void chonVi(Wallet w) {
    _nguoiDungDaChonVi = true;
    _phat(state.copyWith(viNguon: w));
  }

  void chonViDich(Wallet w) => _phat(state.copyWith(viDich: w));

  void chonNgay(DateTime d) => _phat(state.copyWith(ngay: d));

  /// Danh mục cho sheet *Thêm phần*: danh mục CHI hợp lệ; nạp luôn bảng tra tên / màu cho khối tách.
  Future<List<Category>> danhMucChoTach() async {
    final (chonDuoc, _) = await _nguon.napDanhMucVaTuKhoa(_taiKhoan());
    final hopLe = hopLeTheoChieu('chi', chonDuoc);
    final chi = [for (final c in chonDuoc) if (hopLe.contains(c.id)) c];
    _phat(state.copyWith(dmTheoId: {for (final c in chi) c.id: c}));
    return chi;
  }

  /// Thêm phần mới, hoặc thay [thay] bằng [p].
  void luuPhan(PhanTach p, {PhanTach? thay}) =>
      _phat(state.copyWith(phanTach: [for (final x in state.phanTach) if (x != thay) x, p]));

  void boPhan(PhanTach p) => _phat(state.copyWith(phanTach: [for (final x in state.phanTach) if (x != p) x]));

  /// ⏳ TẠM (Task 2–3): đường điền sẵn còn ở trang ghi thẳng ô lõi, KHÔNG kèm hệ quả của các hàm chọn. Task 4 dời các
  /// đường ấy vào Cubit rồi XOÁ hàm này.
  void ghiOLoi({
    Wallet? viNguon,
    bool datViNguon = false,
    Wallet? viDich,
    bool datViDich = false,
    DateTime? ngay,
    bool? nguoiDungDaChonVi,
  }) {
    if (nguoiDungDaChonVi != null) _nguoiDungDaChonVi = nguoiDungDaChonVi;
    var s = state;
    if (datViNguon) s = s.copyWith(viNguon: viNguon);
    if (datViDich) s = s.copyWith(viDich: viDich);
    if (ngay != null) s = s.copyWith(ngay: ngay);
    _phat(s);
  }
}
