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

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../category/data/models/category_entity.dart';
import '../../../wallet/data/models/wallet_entity.dart';
import '../../../../core/ui/thong_bao_nhanh.dart' show LoaiThongBao;
import '../../../../core/utils/currency_formatter.dart';
import '../../../budget/data/models/budget_entity.dart';
import '../../../budget/domain/budget_impact.dart';
import '../../../category/data/models/category_suggestion.dart';
import '../../../category/domain/category_suggestion_engine.dart';
import '../../../category/domain/category_classify.dart';
import '../../../category/domain/de_xuat_tu_khoa.dart';
import '../../../category/domain/gan_hang_loat.dart' show hopLeTheoChieu;
import '../../../category/domain/phan_loai_ghi_chu.dart';
import '../../../category/domain/phan_loai_so_tien.dart';
import '../../data/dong_hang_bien_dong.dart';
import '../../data/models/transaction_entity.dart';
import '../../data/them_giao_dich_nguon.dart';
import '../../domain/ban_phim_so_tien.dart';
import '../../domain/chot_so_tien_cau.dart';
import '../../domain/dien_san_bien_dong.dart';
import '../../domain/doc_cau_giao_dich.dart';
import '../../domain/goi_y_chuyen_khoan.dart';
import '../../domain/tach_giao_dich.dart';
import '../../domain/vi_chon_san.dart';
import 'them_giao_dich_state.dart';

/// Kết quả [ThemGiaoDichCubit.chuanBiLuu].
sealed class KetQuaChuanBiLuu {
  const KetQuaChuanBiLuu();
}

/// Không lưu được — trang báo [cau] bằng toast lỗi.
class LoiLuu extends KetQuaChuanBiLuu {
  const LoiLuu(this.cau);
  final String cau;
}

/// Sẵn sàng gửi cho `TransactionBloc`.
class SanSangLuu extends KetQuaChuanBiLuu {
  const SanSangLuu({
    required this.giaoDich,
    required this.truoc,
    required this.laTach,
    required this.tacDong,
    required this.canXacNhan,
  });

  /// Một phần tử, trừ khi [laTach].
  final List<TransactionEntity> giaoDich;

  /// Giao dịch đang sửa → `UpdateTransactionEvent(before: truoc, after: giaoDich.single)`.
  final TransactionEntity? truoc;
  final bool laTach;

  /// Tác động ngân sách cho lời nhắn sau lưu.
  final BudgetImpact? tacDong;

  /// Ngân sách *Chặn* bị vượt — rỗng = không hỏi. Tách: MỘT hộp cho cả lô.
  final List<BudgetImpact> canXacNhan;
}

class ThemGiaoDichCubit extends Cubit<ThemGiaoDichState> {
  ThemGiaoDichCubit({
    required ThemGiaoDichNguon nguon,
    required int? Function() taiKhoan,
    required CategorySuggestionEngine boGoiY,
    TransactionEntity? dangSua,
    CategoryEntity? danhMucDangSua,
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
  final CategorySuggestionEngine _boGoiY;
  final TransactionEntity? _dangSua;

  /// D1 / biên lai / A5 — `null` ở đường sửa.
  final DienSanBienDong? _bienDong;
  final bool _choTickMon;

  /// ⚠️ Chốt quan trọng nhất của chặng 1.2: một phép đoán từ lịch sử KHÔNG BAO GIỜ đè lựa chọn người dùng vừa làm.
  bool _nguoiDungDaChonVi = false;
  Map<String, String> _viHayDung = const {};
  BoPhanLoaiGhiChu? _boPhanLoai;
  BoPhanLoaiSoTien? _boSoTien;
  List<MauGhiChu>? _mauDeXuat;

  bool get laSua => _dangSua != null;
  DienSanBienDong? get bienDong => _bienDong;

  static ThemGiaoDichState _dauTien(
      TransactionEntity? dangSua, CategoryEntity? danhMuc, String? huongBanDau, DienSanBienDong? bienDong) {
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
    final d = _bienDong;
    if (d != null) unawaited(_napAnh(d));
    await Future.wait([_napVi(), _napLichSu().then((_) => _napTatCap())]);
    // Đường sửa mở với danh mục + ghi chú sẵn → tính đề xuất từ khoá sau khi có mẫu và tập tắt.
    unawaited(_tinhDeXuat());
    // D1: điền sau khi có cả ví (chọn sẵn theo nguồn) lẫn mô hình B1 + tập tắt (đoán danh mục).
    if (d != null) await _dienTuBienDong();
  }

  Future<void> _napVi() async {
    final r = _nguon.napViDangDung(_taiKhoan());
    final ds = r is List<WalletEntity> ? r : await r;
    if (isClosed) return;
    final chon = chonViChonSan<WalletEntity>(ds, laMacDinh: (w) => w.isDefault);
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

  static WalletEntity? _timVi(List<WalletEntity> ds, String? id) {
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
    _henGoiYTheoForm();
  }

  /// Chạm khối số tiền. Bàn phím hệ thống đang mở (gõ ghi chú) thì 16 phím bị G58 giấu dù cờ bật — đảo cờ lúc ấy là tắt
  /// phím mà người dùng không thấy gì đổi; nên MỞ 16 phím (trang tự đóng bàn phím hệ thống).
  void chamSoTien({required bool banPhimHeThongMo}) =>
      _phat(state.copyWith(hienBanPhimSo: banPhimHeThongMo || !state.hienBanPhimSo));

  /// Điền một số (chip của ảnh quét, điền sẵn) — từng chữ số qua `themPhimSoTien`, cùng trần; ẩn 16 phím.
  void chonSoTien(double v) =>
      _phat(state.copyWith(chuoiSoTien: _goSo(v), hienBanPhimSo: false, luaChonTienCau: const []));

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
    _choPhanXu = null;
    _phat(s.copyWith(goiY: null));
    unawaited(_tinhDeXuat());
    // Đoạn Chi / Thu là thông tin CHIỀU duy nhất của gợi ý theo số tiền (dự án C): đổi đoạn là đổi tập mẫu được học.
    _henGoiYTheoForm();
  }

  /// Đường DUY NHẤT để đặt danh mục — bảng chọn, thẻ gợi ý, điền sẵn đều qua đây, để chiều tiền vay/nợ luôn được gợi
  /// sẵn kèm theo. Danh mục là sự thật, đoạn đầu màn phản ánh nó.
  void chonDanhMuc(CategoryEntity c) {
    final laVayNo = isDebtClassify(c.classify);
    final no = laVayNo ? suggestDebtDirection(c.name) : null;
    _phat(state.copyWith(
      danhMuc: c,
      // A5 11.2: danh mục chính mới trùng một phần đang tách → phần ấy gộp vào phần chính.
      phanTach: gopKhiDoiDanhMucChinh(c.id, state.phanTach),
      viNguon: _viHayDungCho(c) ?? state.viNguon,
      chieuNo: no,
      huong: laVayNo ? (no ?? 'chi') : (c.classify == 'thu' ? 'thu' : 'chi'),
      goiY: null,
    ));
    unawaited(_tinhDeXuat());
  }

  /// Ví người dùng HAY DÙNG cho [c] — ba cửa chặn: đang sửa (ví của giao dịch là sự thật), người dùng đã tự đặt ví
  /// (lựa chọn cố ý thắng phép đoán), tra không thấy (`null` = chưa biết → giữ ví đang có).
  WalletEntity? _viHayDungCho(CategoryEntity c) {
    if (_dangSua != null || _nguoiDungDaChonVi) return null;
    return _timVi(state.vi, _viHayDung[c.id]);
  }

  void chonChieuNo(String d) => _phat(state.copyWith(chieuNo: d, huong: d));

  void chonVi(WalletEntity w) {
    _nguoiDungDaChonVi = true;
    _phat(state.copyWith(viNguon: w));
    // Ví là một tín hiệu của gợi ý theo số tiền (dự án C); ví ĐÍCH thì không.
    _henGoiYTheoForm();
  }

  void chonViDich(WalletEntity w) => _phat(state.copyWith(viDich: w));

  void chonNgay(DateTime d) {
    _phat(state.copyWith(ngay: d));
    // Nhóm thứ (ngày thường / cuối tuần) là một tín hiệu của gợi ý theo số tiền (dự án C).
    _henGoiYTheoForm();
  }

  // ── Gợi ý danh mục (B1 · từ khoá · số tiền) và đề xuất từ khoá ──────────────────────────────────────────────────
  /// Cặp (cụm, danh mục) đang bị thôi gợi ý (`tatCapTu`) — nạp một lần sau khi có mô hình.
  Set<(String, String)> _tatCap = const {};

  /// Cặp (mã bậc, danh mục) của nguồn số tiền đang bị thôi gợi ý (`tatCapSoTienTu`).
  Set<(String, String)> _tatCapSoTien = const {};

  /// Cặp (cụm, danh mục) đang bị thôi ĐỀ XUẤT TỪ KHOÁ — tập riêng của nguồn `kNguonDeXuatTuKhoa` (spec 2026-09-30 §2.4).
  Set<(String, String)> _tatCapTuKhoa = const {};

  /// Cặp người dùng vừa bấm *Bỏ qua* trong lượt mở màn này. Thẻ nguồn số tiền tính lại ở MỖI phím số, nên thiếu tập
  /// này thì bấm Bỏ qua xong gõ thêm một chữ số cùng bậc là thẻ bật lại ngay (cùng nếp [_boQuaLuotNay]).
  final Set<(String, String)> _boQuaSoTienLuotNay = {};

  /// Cặp người dùng vừa ✕ đề xuất từ khoá trong lượt này — dòng ẩn tới khi rời màn.
  final Set<(String, String)> _boQuaLuotNay = {};

  /// Gợi ý đã HIỆN mà người dùng chưa phân xử, kèm ghi chú lúc nó hiện.
  ///
  /// ⚠️ Tách khỏi `state.goiY`: [chonDanhMuc] xoá thẻ ngay khi người dùng chọn qua bảng, nhưng lựa chọn ấy CHÍNH LÀ
  /// phán xét (`khac`) — ghi lúc lưu. Ghi chú đổi / đổi đoạn thì bỏ, không ghi (không phải phán xét).
  ({CategorySuggestion goiY, String ghiChu})? _choPhanXu;

  /// Hoãn việc tra cứu gợi ý cho tới khi người dùng ngừng gõ.
  ///
  /// `TextEditingController` phát tín hiệu ở MỖI ký tự. Không hoãn thì một ghi chú 30 ký tự sinh 30 lượt đọc CSDL, mỗi
  /// lượt lại đọc thêm từ khoá — và mọi kết quả trừ cái cuối đều bị vứt đi.
  Timer? _hoanGoiY;
  Timer? _hoanDeXuat;
  Timer? _anDaThem;
  static const Duration _doTreGoiY = Duration(milliseconds: 300);

  /// Nguồn số tiền có được dùng ở lượt mở màn này không — MỘT định nghĩa cho cả chỗ hẹn lẫn chỗ đoán: đã có mô hình,
  /// không ở chế độ sửa, không phải form biến động số dư (người dùng không chọn hai chỗ ấy cho lần này — spec mục 2
  /// hàng 4). Hai chỗ mỗi nơi một bản chép thì bỏ một vế ở MỘT chỗ vẫn xanh (đo bằng bản sai 2026-10-02).
  bool get _coNguonSoTien => _boSoTien != null && !laSua && _bienDong == null;

  /// Từ `_napTatCap` của trang. Đọc phản hồi cũ → cặp đang bị thôi gợi ý. Lỗi thì bỏ qua: thẻ vẫn gợi ý như chưa ai
  /// từng bỏ qua.
  Future<void> _napTatCap() async {
    final bo = _boPhanLoai;
    final boTien = _boSoTien;
    final id = _taiKhoan();
    // Hai mô hình độc lập: B1 học lỗi (`null`) không được kéo theo việc bỏ nạp tập tắt của nguồn số tiền.
    if ((bo == null && boTien == null) || id == null) return;
    try {
      final phanHoi = await _nguon.docPhanHoi(id);
      if (phanHoi == null || isClosed) return;
      _tatCap = bo == null ? const {} : tatCapTu(phanHoi, bo.mau);
      _tatCapTuKhoa = bo == null ? const {} : tatCapTu(phanHoi, _mauDeXuat ?? bo.mau, nguon: kNguonDeXuatTuKhoa);
      _tatCapSoTien = boTien == null ? const {} : tatCapSoTienTu(phanHoi, boTien.mau);
    } catch (e) {
      debugPrint('[GoiYDanhMuc] đọc phản hồi lỗi: $e');
    }
  }

  /// Ghi một phản hồi. Lỗi ghi do nguồn nuốt (`unawaited` + `catchError`): phản hồi hỏng KHÔNG được chặn việc chọn hay
  /// lưu giao dịch.
  void _ghiPhanHoi(CategorySuggestion goiY, String ketQua, {String? chon}) {
    final id = _taiKhoan();
    if (id == null) return;
    _nguon.ghiPhanHoi(idaccount: id, goiY: goiY, ketQua: ketQua, chon: chon);
  }

  /// Từ `_onNoteChanged` + `_henDeXuat` của trang. Trùng chữ (trang chép ô sau khi Cubit đặt ghi chú, hay chỉ đổi con
  /// trỏ) thì thoát — không vòng lặp, không hoãn lại hẹn giờ.
  void ghiChuDoi(String chu) {
    if (chu == state.ghiChu) return;
    _phat(state.copyWith(ghiChu: chu));
    _hoanDeXuat?.cancel();
    _hoanDeXuat = Timer(_doTreGoiY, () => unawaited(_tinhDeXuat()));
    _hoanGoiY?.cancel();
    final note = chu.trim();
    // Controller phát cả khi chỉ đổi con trỏ — so CHỮ, không coi mỗi lần phát là "đổi ghi chú".
    if (_choPhanXu != null && note != _choPhanXu!.ghiChu) _choPhanXu = null;
    if (state.laChuyen || state.danhMuc != null) {
      if (state.goiY != null) _phat(state.copyWith(goiY: null));
      return;
    }
    if (note.isEmpty) {
      // Thẻ B1 / từ khoá nói về chữ vừa bị xoá — gỡ NGAY như trước dự án C; thẻ số tiền thì chính là của ô trống.
      if (state.goiY != null && state.goiY!.nguon != kNguonGoiYSoTien) _phat(state.copyWith(goiY: null));
      // Không có mô hình số tiền thì ghi chú trống là hết việc — đúng hành vi trước dự án C.
      if (_boSoTien == null) return;
    } else if (state.goiY?.nguon == kNguonGoiYSoTien) {
      // Chữ đầu tiên vừa vào ô ghi chú: thẻ số tiền chỉ dành cho ô TRỐNG — gỡ NGAY, không chờ độ trễ; để nó đứng thêm
      // 300 ms là người dùng thấy thẻ cãi lại chữ họ đang gõ.
      _phat(state.copyWith(goiY: null));
    }
    // Đọc lại từ state thay vì dùng `note` đã bắt ở trên: trong lúc chờ người dùng có thể đã gõ tiếp, và thứ đáng gợi
    // ý là văn bản HIỆN TẠI.
    _hoanGoiY = Timer(_doTreGoiY, () {
      if (!isClosed) unawaited(_napGoiY(state.ghiChu.trim()));
    });
  }

  /// Từ `_henGoiYTheoForm` của trang (dự án C) — hẹn tính lại thẻ gợi ý khi một tín hiệu của nguồn SỐ TIỀN đổi (số tiền,
  /// ví, ngày, đoạn). Dùng CÙNG timer với ghi chú: thẻ chỉ có một, nên chỉ một lượt tính đang chờ.
  ///
  /// Thoát sớm khi nguồn số tiền không dùng được ([_coNguonSoTien]) → mọi đường cũ (B1, từ khoá) không đổi một bước nào.
  void _henGoiYTheoForm() {
    if (!_coNguonSoTien) return;
    // Gợi ý số tiền đã hiện mà bậc vừa đổi: thẻ ấy nói về bậc cũ — huỷ, không phải phán xét của người dùng (spec 3.4).
    // Đặt Ở ĐÂY chứ không chỉ trong `_napGoiY`: khi người dùng đã chọn danh mục qua bảng rồi mới đổi số tiền,
    // `_napGoiY` không chạy nữa, và gợi ý cũ sẽ bị ghi `khac` lúc lưu cho một khoản ở bậc khác hẳn.
    final cho = _choPhanXu;
    if (cho != null && cho.goiY.nguon == kNguonGoiYSoTien) {
      final x = state.soTienDangCo;
      if (x == null || maBacCua(bacTienCua(x)) != cho.goiY.amTietChinh) _choPhanXu = null;
    }
    // Ghi chú có chữ thì thẻ thuộc về B1 / từ khoá, mà số tiền, ví, ngày, đoạn không phải tín hiệu của hai nguồn ấy —
    // không hẹn gì. ⚠️ Hẹn ở đây là ĐỔI hành vi cũ: đổi đoạn Chi ↔ Thu vốn gỡ thẻ B1 cho tới khi ghi chú đổi (và
    // "đổi đoạn → không ghi phản hồi" dựa vào đó); hẹn lại là thẻ B1 tự bật lên sau mỗi lần chạm đoạn.
    if (state.ghiChu.trim().isNotEmpty) return;
    _hoanGoiY?.cancel();
    if (state.laChuyen || state.danhMuc != null) return;
    _hoanGoiY = Timer(_doTreGoiY, () {
      if (!isClosed) unawaited(_napGoiY(state.ghiChu.trim()));
    });
  }

  /// Từ `_goiYSoTien` của trang — nguồn thứ ba của thẻ gợi ý (dự án C), CHỈ gọi khi ghi chú trống: đoán theo bậc tiền +
  /// nhóm thứ + ví, chỉ danh mục đúng chiều của đoạn đang chọn. `null` = chưa đủ để nói.
  CategorySuggestion? _goiYSoTien(List<CategoryEntity> categories) {
    final bo = _boSoTien;
    if (bo == null || !_coNguonSoTien || state.laChuyen) return null;
    final soTien = state.soTienDangCo;
    if (soTien == null) return null;
    final d = bo.doan(
      chieu: state.huong,
      soTien: soTien,
      ngay: state.ngay,
      walletId: state.viNguon?.id,
      hopLe: hopLeTheoChieu(state.huong, categories),
      tatCap: {..._tatCapSoTien, ..._boQuaSoTienLuotNay},
    );
    if (d == null) return null;
    final cat = categories.firstWhere((c) => c.id == d.categoryId);
    return CategorySuggestion(
      category: cat,
      matchedKeyword: d.maBac,
      nguon: kNguonGoiYSoTien,
      amTietChinh: d.maBac,
      lyDo: cauLyDoSoTien(d, tenDanhMuc: cat.name),
    );
  }

  /// Từ `_loadSuggestion` của trang — MỘT cửa cho cả ba nguồn của thẻ.
  Future<void> _napGoiY(String note) async {
    final accountId = _taiKhoan();
    // Chưa có phiên thì không gợi ý gì — đọc danh mục bằng mã admin là gợi ý danh mục của người khác.
    if (accountId == null) return;
    // MỘT cửa cho cả ba nguồn (dự án C): hàm này nay được hẹn cả khi số tiền / ví / ngày / đoạn đổi, không chỉ khi ghi
    // chú đổi — nên tự nó phải chặn hai trạng thái không bao giờ có thẻ.
    if (state.laChuyen || state.danhMuc != null) return;
    final luc = state;
    // Đoạn Chi/Thu chỉ là lối vào, không khoanh vùng gợi ý: tìm trên cả ba phân loại vì chiều tiền suy từ danh mục được
    // chọn, không phải ngược lại.
    final categories = await _nguon.danhMucChonDuoc(accountId);
    CategorySuggestion? suggestion;
    if (note.isEmpty) {
      // Dự án C: ghi chú TRỐNG → đoán theo số tiền. KHÁC hai nguồn dưới, nguồn này khoanh theo đoạn Chi/Thu: số tiền
      // không mang nghĩa chiều, đoạn đang chọn là thông tin chiều duy nhất.
      //
      // ⚠️ CHỈ khi ghi chú trống (người dùng chốt 2026-10-02 sau phép đo CSDL thật): bản đầu còn dùng nguồn này khi
      // ghi chú có chữ mà B1 lẫn từ khoá đều im, và 3/4 lần thẻ sai rơi đúng vào đó — *"ca phe sang"* 10.000 → Di
      // chuyển, thẻ nói ngược chữ người dùng vừa gõ.
      suggestion = _goiYSoTien(categories);
    } else {
      // B1: mô hình HỌC đi trước — nó nói từ chính các lần người dùng tự chốt danh mục. `null` = chưa đủ để nói
      // (sổ mỏng, ghi chú lạ, hậu nghiệm thấp, cặp đang bị thôi gợi ý) → bảng từ khoá như trước B1.
      // `hopLe` = mọi danh mục chọn được, cả ba phân loại — cùng nếp "đoạn Chi/Thu không khoanh vùng gợi ý" ở trên.
      final doan = _boPhanLoai?.doan(note, hopLe: {for (final c in categories) c.id}, tatCap: _tatCap);
      if (doan != null) {
        final cat = categories.firstWhere((c) => c.id == doan.categoryId);
        suggestion = CategorySuggestion(
          category: cat,
          matchedKeyword: doan.cumBoDau,
          nguon: kNguonGoiYHoc,
          amTietChinh: doan.cumBoDau,
          lyDo: cauLyDoHoc(doan, ghiChuGoc: note, tenDanhMuc: cat.name),
        );
      } else {
        // MỘT truy vấn cho cả tài khoản. Trước đây chỗ này gọi `loadKeywords` một lần cho mỗi danh mục, nên tài khoản có
        // 20 danh mục là 20 truy vấn — nhân với mỗi lần ghi chú thay đổi.
        final keywordsByCategory = await _nguon.tuKhoa(accountId);
        final candidates = <CategoryKeywordCandidate>[
          for (final category in categories)
            for (final keyword in keywordsByCategory[category.id] ?? const <String>[])
              CategoryKeywordCandidate(category: category, keyword: keyword),
        ];
        suggestion = _boGoiY.suggest(rawText: note, candidates: candidates);
      }
    }
    final s = state;
    if (isClosed ||
        s.huong != luc.huong ||
        s.laChuyen ||
        s.danhMuc != null ||
        s.ghiChu.trim() != note ||
        s.chuoiSoTien != luc.chuoiSoTien ||
        s.viNguon?.id != luc.viNguon?.id ||
        s.ngay != luc.ngay) {
      return;
    }
    final truoc = s.goiY;
    if (suggestion != null) {
      _choPhanXu = (goiY: suggestion, ghiChu: note);
    } else if (_choPhanXu?.goiY.nguon == kNguonGoiYSoTien) {
      // Thẻ số tiền vừa bị thay bằng "không có gì" (bậc / ví / ngày / đoạn đổi): gợi ý cũ không còn là thứ người dùng
      // đang nhìn — bỏ, không ghi phản hồi nào cho nó.
      _choPhanXu = null;
    }
    // Chỉ khi thẻ nguồn số tiền VỪA hiện (hoặc đổi sang danh mục khác) thì tăng bộ đếm cuộn. Cùng một gợi ý được tính lại
    // ở mỗi phím số thì không cuộn — người dùng đã cuộn đi là có chủ ý. ⚠️ KHÔNG cho thẻ B1 / từ khoá: hai thẻ ấy hiện lúc
    // người dùng đang gõ GHI CHÚ, và ô ghi chú nằm DƯỚI thẻ — kéo đáy thẻ về sát bàn phím là đẩy chính ô đang gõ ra sau
    // bàn phím.
    final cuon = suggestion != null &&
        suggestion.nguon == kNguonGoiYSoTien &&
        (truoc?.nguon != kNguonGoiYSoTien || truoc?.category.id != suggestion.category.id);
    emit(s.copyWith(goiY: suggestion, soLanCuonGoiY: cuon ? s.soLanCuonGoiY + 1 : s.soLanCuonGoiY));
  }

  /// Chạm *Chọn* trên thẻ. [s] là thẻ LÚC DỰNG — không đọc lại `state.goiY` lúc chạm.
  void chonGoiY(CategorySuggestion s) {
    _ghiPhanHoi(s, kKetQuaGoiYChon, chon: s.categoryId);
    _choPhanXu = null;
    chonDanhMuc(s.category);
  }

  void boQuaGoiY(CategorySuggestion s) {
    _ghiPhanHoi(s, kKetQuaGoiYBoQua);
    if (s.nguon == kNguonGoiYSoTien) _boQuaSoTienLuotNay.add((s.amTietChinh, s.categoryId));
    _choPhanXu = null;
    _phat(state.copyWith(goiY: null));
  }

  /// Từ `_tinhDeXuat` của trang — đề xuất thêm từ khoá (spec 2026-09-30), tính lại khi ghi chú hoặc danh mục đổi. Mọi
  /// nguồn danh mục như nhau (chọn tay, thẻ gợi ý, Nhập nhanh). Không phiên / không mẫu học → im.
  Future<void> _tinhDeXuat() async {
    final cat = state.danhMuc;
    final ghiChu = state.ghiChu.trim();
    final mau = _mauDeXuat ?? _boPhanLoai?.mau;
    final id = _taiKhoan();
    if (cat == null || state.laChuyen || ghiChu.isEmpty || mau == null || id == null) {
      if (state.deXuat != null) _phat(state.copyWith(deXuat: null));
      return;
    }
    final (chonDuoc, tuKhoa) = await _nguon.napDanhMucVaTuKhoa(id);
    if (isClosed || state.danhMuc?.id != cat.id || state.laChuyen || state.ghiChu.trim() != ghiChu) return;
    final ten = {for (final c in chonDuoc) c.id: c.name};
    final d = deXuatTuKhoa(
      ghiChu: ghiChu,
      categoryId: cat.id,
      mau: mau,
      // Chỉ danh mục còn sống: từ khoá của danh mục đã xoá không phải xung đột.
      tuKhoa: {for (final e in tuKhoa.entries) if (ten.containsKey(e.key)) e.key: e.value},
      tatCap: {..._tatCapTuKhoa, ..._boQuaLuotNay},
    );
    emit(state.copyWith(
      deXuat: d == null ? null : (dx: d, tenDanhMuc: cat.name, tenCu: d.tuDanhMuc == null ? null : ten[d.tuDanhMuc]),
    ));
  }

  static CategorySuggestion _goiYCua(DeXuatTuKhoa d, CategoryEntity c) =>
      CategorySuggestion(category: c, matchedKeyword: d.tuKhoa, nguon: kNguonDeXuatTuKhoa, amTietChinh: d.cumBoDau);

  /// Từ `_chapNhanDeXuat` — Thêm / Chuyển GHI NGAY (spec 2026-09-30 §2.3). Chuyển bỏ ở danh mục cũ TRƯỚC: không có
  /// khoảnh khắc cụm thuộc hai danh mục (bộ so coi hai danh mục khớp ngang nhau là hoà → thôi đoán).
  Future<void> chapNhanDeXuat() async {
    final d = state.deXuat;
    final id = _taiKhoan();
    final cat = state.danhMuc;
    if (d == null || id == null || cat == null) return;
    final goiY = _goiYCua(d.dx, cat);
    _phat(state.copyWith(deXuat: null));
    try {
      final tuKhoa = await _nguon.tuKhoa(id);
      final cu = d.dx.tuDanhMuc;
      if (cu != null) {
        await _nguon.luuTuKhoa(
          idaccount: id,
          categoryId: cu,
          tuKhoa: [for (final k in tuKhoa[cu] ?? const <String>[]) if (!cungTuKhoa(k, d.dx.tuKhoa)) k],
        );
      }
      await _nguon.luuTuKhoa(
        idaccount: id,
        categoryId: d.dx.categoryId,
        tuKhoa: [...?tuKhoa[d.dx.categoryId], d.dx.tuKhoa],
      );
    } catch (e) {
      debugPrint('[DeXuatTuKhoa] ghi từ khoá lỗi: $e');
      return;
    }
    _ghiPhanHoi(goiY, kKetQuaGoiYChon, chon: d.dx.categoryId);
    if (isClosed) return;
    // "Đã thêm / Đã chuyển …" tự ẩn sau 2 giây (người dùng chốt 2026-09-30, Stitch `8ca1338e…`).
    emit(state.copyWith(
      daThemTuKhoa: d.tenCu == null
          ? 'Đã thêm ‘${d.dx.tuKhoa}’ vào ${d.tenDanhMuc}'
          : 'Đã chuyển ‘${d.dx.tuKhoa}’ sang ${d.tenDanhMuc}',
    ));
    _anDaThem?.cancel();
    _anDaThem = Timer(const Duration(seconds: 2), () => _phat(state.copyWith(daThemTuKhoa: null)));
  }

  void boQuaDeXuat() {
    final d = state.deXuat;
    final cat = state.danhMuc;
    if (d == null || cat == null) return;
    _ghiPhanHoi(_goiYCua(d.dx, cat), kKetQuaGoiYBoQua);
    _boQuaLuotNay.add((d.dx.cumBoDau, d.dx.categoryId));
    _phat(state.copyWith(deXuat: null));
  }

  /// B1: thẻ gợi ý đã hiện mà người dùng chọn qua bảng rồi lưu — chọn đúng danh mục gợi ý là `chon`, khác là `khac`.
  /// Khoản đã tách: chỉ cho DANH MỤC CHÍNH (thẻ gợi ý hiện cho nó; phần chọn tay không ghi — spec 11.5).
  void _ghiPhanHoiKhiLuu() {
    final cho = _choPhanXu;
    final daChon = state.danhMuc;
    if (cho != null && daChon != null && !state.laChuyen) {
      _ghiPhanHoi(cho.goiY, daChon.id == cho.goiY.categoryId ? kKetQuaGoiYChon : kKetQuaGoiYKhac, chon: daChon.id);
      _choPhanXu = null;
    }
  }

  // ── Lưu ──────────────────────────────────────────────────────────────────────────────────────────────────────
  /// Tác động lên ngân sách của khoản vừa gửi đi, để listener chọn lời nhắn sau khi lưu xong. Đặt ngay trước khi gửi
  /// event, xoá ngay khi đã dùng. Đặt ở [daGuiLuu], đọc ở [cauSauLuu].
  BudgetImpact? _tacDongChoLoiNhan;

  /// Số giao dịch của lần Lưu đang chờ `actionSuccess` — toast *"Đã lưu N giao dịch"*.
  int _soGiaoDichVuaLuu = 1;

  /// Từ `_saveTransaction` + `_luuTach` của trang: kiểm, dựng giao dịch, tra ngân sách. Không hộp thoại, không event —
  /// trang hỏi xác nhận ([SanSangLuu.canXacNhan]) rồi mới gửi và báo [daGuiLuu].
  Future<KetQuaChuanBiLuu> chuanBiLuu() async {
    final s = state;
    // ⚠️ KHÔNG `replaceAll('.', '')` (A12, 2026-09-19). `chuoiSoTien` là chuỗi **thô** đang gõ, không phải chuỗi đã
    // ngăn nghìn — phép ngăn nghìn chỉ áp ở `_getFormattedAmount` của trang. Coi dấu chấm là dấu ngăn nghìn thì một số
    // lẻ bị mất dấu rồi đọc tiếp: `12.5` lưu thành **125**, sai gấp mười, không exception, không log. Bàn phím nay hết
    // phím `.`, nhưng chuỗi có dấu chấm vẫn vào được qua chế độ sửa (`_dauTien` đọc `editing.amount.toString()`) — và số
    // lẻ có thật, `transaction."Amount"` là `numeric(15,2)`. Nên chốt phải nằm ở ĐÂY, không chỉ ở bàn phím.
    // ⚠️ Phải RÚT GỌN, không `double.tryParse` thẳng: từ 2026-09-19 bàn phím dựng được biểu thức (`"50000+30000"`), mà
    // parse thẳng chuỗi ấy trả `null` rồi rơi về 0 — chốt `amount <= 0` ngay dưới sẽ báo "Vui lòng nhập số tiền hợp lệ"
    // cho một con số người dùng vừa gõ đúng.
    final amount = ketQuaBieuThuc(s.chuoiSoTien);
    if (amount <= 0) return const LoiLuu('Vui lòng nhập số tiền hợp lệ');
    final viNguon = s.viNguon;
    if (viNguon == null) return const LoiLuu('Vui lòng chọn ví thanh toán');
    final danhMuc = s.danhMuc;
    if (!s.laChuyen && danhMuc == null) return const LoiLuu('Vui lòng chọn danh mục');
    final viDich = s.viDich;
    if (s.laChuyen && viDich == null) return const LoiLuu('Vui lòng chọn ví đích');
    final type = s.loaiGhi;
    if (type == null) return const LoiLuu('Vui lòng chọn chiều tiền');
    // ⚠️ Chốt cuối, và là chốt quan trọng nhất trong chuỗi này: KHÔNG ghi giao dịch khi chưa biết nó thuộc về ai. Trước
    // 2026-09-14 nhánh này rơi về mã `1` — tài khoản admin thật — nên giao dịch ghi trong lúc phiên chưa sẵn sàng sẽ
    // mang chủ sở hữu sai, rồi đẩy lên và vỡ "Ownership mismatch" mà không ai lần được từ đâu. Sửa giao dịch cũ thì
    // `editing` đã mang sẵn chủ sở hữu, nên đường ấy không cần chốt.
    final editing = _dangSua;
    final accountId = editing?.idaccount ?? _taiKhoan();
    if (accountId == null) return const LoiLuu('Chưa xác định được tài khoản đăng nhập');

    final tx = TransactionEntity(
      // Sửa thì giữ nguyên id (và những gì form không đụng tới) — tạo id mới là nhân đôi giao dịch.
      id: editing?.id ?? const Uuid().v4(),
      walletId: viNguon.id,
      idaccount: accountId,
      // Khoản chuyển KHÔNG có danh mục. Trước đây chỗ này gán 'cat_transfer' — một id chưa từng được seed — và
      // SyncEngine hoãn đẩy hàng ấy vĩnh viễn vì không phân giải được danh mục.
      categoryId: s.laChuyen ? null : danhMuc!.id,
      walletTransfer: s.laChuyen ? viDich!.id : null,
      goalId: editing?.goalId,
      amount: amount,
      type: type,
      note: s.ghiChu.trim(),
      date: s.ngay,
      images: editing?.images ?? const [],
      syncStatus: 'pending',
      isDeleted: false,
      updatedAt: DateTime.now(),
    );

    // A5 mục 11 — khoản chi đã TÁCH: N giao dịch, ghi hết hoặc không gì, một toast.
    if (s.phanTach.isNotEmpty && editing == null && type == 'chi') {
      return _chuanBiLuuTach(tx, amount);
    }

    // Ngân sách của danh mục: "Chặn" thì hỏi trước khi ghi khoản làm vượt, "Cảnh báo" thì ghi luôn rồi báo. Đây là nơi
    // DUY NHẤT đọc `OverSpending`.
    final impact = await _tacDongNganSach(tx, editing);
    return SanSangLuu(
      giaoDich: [tx],
      truoc: editing,
      laTach: false,
      tacDong: impact,
      canXacNhan: impact != null && impact.requiresConfirmation ? [impact] : const [],
    );
  }

  /// A5 mục 11.4–11.5 — lưu khoản đã tách: kiểm hợp lệ, ngân sách TỪNG phần (một hộp cho cả lô nếu có ngân sách *Chặn*
  /// bị vượt), rồi MỘT `AddTransactionsEvent`. Ở đây chỉ dựng và kiểm — event do trang gửi.
  Future<KetQuaChuanBiLuu> _chuanBiLuuTach(TransactionEntity tx, double tong) async {
    final phanTach = state.phanTach;
    final loi = kiemTach(tong: tong, chinh: tx.categoryId, phan: phanTach);
    if (loi != null) {
      return LoiLuu(switch (loi) {
        LoiTach.conLaiKhongDuong => 'Phần còn lại phải lớn hơn 0',
        LoiTach.phanKhongDuong => 'Mỗi phần phải lớn hơn 0',
        LoiTach.trungDanhMuc => 'Mỗi danh mục chỉ một phần',
        LoiTach.monHaiPhan => 'Một món chỉ thuộc một phần',
      });
    }
    final ds = dungGiaoDichTach(mau: tx, phan: phanTach);
    final impacts = <BudgetImpact>[];
    for (final t in ds) {
      final i = await _tacDongNganSach(t, null);
      if (i != null) impacts.add(i);
    }
    return SanSangLuu(
      giaoDich: ds,
      truoc: null,
      laTach: true,
      tacDong: impacts.where((i) => i.exceeds || i.nearLimitAfter).firstOrNull,
      canXacNhan: [for (final i in impacts) if (i.requiresConfirmation) i],
    );
  }

  /// Trang đã gửi event cho `TransactionBloc` (sau hộp xác nhận nếu có). Đường tạo mới ghi phản hồi thẻ gợi ý (khoản
  /// tách: cho danh mục chính).
  void daGuiLuu(SanSangLuu r) {
    _tacDongChoLoiNhan = r.tacDong;
    _soGiaoDichVuaLuu = r.laTach ? r.giaoDich.length : 1;
    if (r.truoc == null) _ghiPhanHoiKhiLuu();
  }

  /// Câu toast sau `actionSuccess`. Đọc xong thì đặt lại.
  ({String cau, LoaiThongBao loai}) cauSauLuu() {
    // Lời nhắn về ngân sách thay lời nhắn mặc định — chung chung, không con số (banner tạm thời tối giản theo ý người
    // dùng).
    final soGd = _soGiaoDichVuaLuu;
    _soGiaoDichVuaLuu = 1;
    final impactGoc = budgetImpactSnackText(_tacDongChoLoiNhan);
    final impactText = soGd > 1 ? impactGoc?.replaceFirst('Đã lưu.', 'Đã lưu $soGd giao dịch.') : impactGoc;
    _tacDongChoLoiNhan = null;
    return (
      cau: impactText ?? (laSua ? 'Đã lưu thay đổi' : (soGd > 1 ? 'Đã lưu $soGd giao dịch' : 'Thêm giao dịch thành công!')),
      // Lưu kèm cảnh báo ngân sách ("Đã lưu. Ngân sách X đã vượt hạn mức.") là THÔNG TIN, không phải xong trơn.
      loai: impactText == null ? LoaiThongBao.xong : LoaiThongBao.thongTin,
    );
  }

  /// Từ `_budgetImpactFor` của trang. Tra hỏng → `null` (không được chặn việc ghi).
  Future<BudgetImpact?> _tacDongNganSach(TransactionEntity tx, TransactionEntity? editing) async {
    final categoryId = tx.categoryId;
    if (tx.type != 'chi' || categoryId == null) return null;

    BudgetView? view;
    try {
      view = await _nguon.traNganSach(tx.idaccount, categoryId);
    } catch (_) {
      // Tra ngân sách hỏng không được chặn việc ghi giao dịch.
      return null;
    }
    if (view == null) return null;

    final now = DateTime.now();
    // Sửa: số cũ đã nằm trong "đã chi" nếu nó cùng danh mục và cùng kỳ — phải trừ ra, không thì báo vượt oan.
    var previous = 0.0;
    if (editing != null &&
        editing.type == 'chi' &&
        editing.categoryId == categoryId &&
        budgetPeriodContains(view.budget, editing.date, now)) {
      previous = editing.amount;
    }
    return budgetImpactOf(
      view: view,
      amount: tx.amount,
      previousAmount: previous,
      date: tx.date,
      now: now,
    );
  }

  // ── Điền sẵn: Nhập nhanh (C2) · biến động / biên lai (D1) · ảnh quét (A5) · gợi ý chuyển khoản ────────────────────
  bool _dangDien = false;

  /// Mỗi lần Điền / Huỷ một số mới: kết quả AI về muộn của lượt đã huỷ thì bỏ.
  int _luotDien = 0;

  /// D1: bảng nguồn → ví đã có một ví HOẠT ĐỘNG cho cặp nguồn + đuôi này — khi ấy Lưu không ghi đè (spec §3.3: ghi ở
  /// lần Lưu đầu của mỗi cặp).
  bool _viNguonDaNho = false;

  /// Ví đoán cho hai phía của gợi ý Chuyển khoản đang hiện; `null` = không gợi ý (spec gợi ý chuyển khoản §4).
  ({String? tu, String? den, bool daNhoTu, bool daNhoDen})? _viGoiY;

  /// Gợi ý người dùng ĐÃ áp — Lưu ở đoạn Chuyển khoản thì xoá cả hàng cặp và nhớ ví hai phía (§5).
  GoiYChuyenKhoan? _goiYDaApDung;

  bool get dangDien => _dangDien;

  /// Ô Nhập nhanh có focus → nạp mô hình ngầm (người dùng chốt 2026-09-30).
  void chuanBiAi() => unawaited(_nguon.docAi?.chuanBi());

  /// Cubit tự đặt ghi chú: đi qua [ghiChuDoi] (cùng hệ quả như khi gõ) rồi tăng bộ đếm để trang chép sang ô.
  void _datGhiChu(String chu) {
    ghiChuDoi(chu);
    _phat(state.copyWith(soLanDatGhiChu: state.soLanDatGhiChu + 1));
  }

  /// C2 — đọc câu ở ô *Nhập nhanh* (`docCauGiaoDich`) rồi ĐIỀN SẴN những ô đọc được; ô không đọc được giữ nguyên.
  /// Bất biến ④ nhóm C: không lưu — người dùng xem lại rồi bấm ✓. Trang đóng bàn phím trước khi gọi.
  ///
  /// Mỗi ô đi qua ĐÚNG đường người dùng vẫn đi, để mọi hệ quả chạy như khi chạm tay (xem [dienKetQua]).
  Future<void> dienTuCau(String cau) async {
    if (cau.isEmpty || _dangDien) return;
    _dangDien = true;
    final luot = ++_luotDien;
    // Lượt kiểm chéo của câu trước (nếu còn) bị bỏ — bộ đếm lượt đã tăng; mô hình thôi giải mã.
    if (state.dangKiemSoTien) unawaited(_nguon.docAi?.huy());
    if (state.dangKiemSoTien || state.luaChonTienCau.isNotEmpty) {
      _phat(state.copyWith(dangKiemSoTien: false, luaChonTienCau: const []));
    }
    final (chonDuoc, tuKhoa) = await _nguon.napDanhMucVaTuKhoa(_taiKhoan());
    // Người dùng chốt 2026-09-30 (spec C2 banner "ĐỔI LẦN HAI"): luật trước — chỉ hỏi mô hình (~18 s trên Realme) khi còn
    // ô câu có nhắc mà luật không đọc được (số tiền, ngày, ví); AI về thì luật kiểm từng ô và chỉ LẤP ô luật để trống.
    KetQuaAi? ai;
    final docAi = _nguon.docAi;
    final luat = _docCau(cau, chonDuoc, tuKhoa);
    final soLuat = luat.soTien;
    final canKiem = luat.soTienCanKiem && soLuat != null;
    final coAi = (luat.oThieu.isNotEmpty || canKiem) && docAi != null && !isClosed && await docAi.sanSang();
    if (luat.oThieu.isNotEmpty && coAi) {
      if (isClosed || luot != _luotDien) return;
      emit(state.copyWith(dangDocAi: true));
      ai = await docAi.doc(
        cau,
        now: DateTime.now(),
        tenVi: [for (final w in state.vi) w.name],
        tenDanhMuc: [for (final c in chonDuoc) if (!c.isDeleted && !c.isGroup) c.name],
      );
    }
    // Người dùng đã bấm Huỷ — lượt ấy đã điền bằng luật.
    if (isClosed || luot != _luotDien) return;
    _dangDien = false;
    if (state.dangDocAi) emit(state.copyWith(dangDocAi: false));
    _apDungKetQua(cau, chonDuoc, tuKhoa, ai: ai);
    // C4 §3.4 — kiểm chéo số luật đọc bằng dạng nói. Câu còn ô thiếu thì lượt AI vừa rồi kiểm luôn — không gọi lần hai.
    if (!canKiem || !coAi) return;
    if (luat.oThieu.isNotEmpty) {
      if (ai != null) _chotSoTien(cau, soLuat, ai);
      return;
    }
    unawaited(_kiemSoTienNen(cau, soLuat, luot, chonDuoc));
  }

  /// C4 §3.4 — một lượt Gemma ở NỀN; form đã điền số luật. Người dùng đổi số trong lúc chờ → kết quả bị bỏ.
  Future<void> _kiemSoTienNen(String cau, double soLuat, int luot, List<CategoryEntity> chonDuoc) async {
    final chuoiLuat = state.chuoiSoTien;
    _phat(state.copyWith(dangKiemSoTien: true));
    final ai = await _nguon.docAi!.doc(
      cau,
      now: DateTime.now(),
      tenVi: [for (final w in state.vi) w.name],
      tenDanhMuc: [for (final c in chonDuoc) if (!c.isDeleted && !c.isGroup) c.name],
    );
    if (isClosed || luot != _luotDien) return;
    _phat(state.copyWith(dangKiemSoTien: false));
    if (ai != null && state.chuoiSoTien == chuoiLuat) _chotSoTien(cau, soLuat, ai);
  }

  void _chotSoTien(String cau, double soLuat, KetQuaAi ai) {
    final c = chotSoTienCau(luat: soLuat, ai: soTienAiHopLe(cau, ai, now: DateTime.now()));
    if (c.luaChon.isEmpty) return;
    // Ô số tiền trống: dòng "Đã điền" không được còn nói số luật đã điền (preflight P7).
    final kq = state.ketQuaDien;
    KetQuaDien? kqMoi = kq;
    if (kq != null && kq.docDuoc) {
      final dau = 'Đã điền: ${CurrencyFormatter.format(soLuat)}';
      if (kq.tomTat.startsWith(dau)) {
        final conLai = kq.tomTat.substring(dau.length).replaceFirst(' · ', '');
        // Hết chữ để nói mà còn cảnh báo / nguồn AI thì giữ KetQuaDien (tóm tắt rỗng); không còn gì thì bỏ hẳn dòng.
        kqMoi = conLai.isEmpty && kq.canhBao.isEmpty && !kq.quaAi
            ? null
            : (
                tomTat: conLai.isEmpty ? '' : 'Đã điền: $conLai',
                docDuoc: true,
                quaAi: kq.quaAi,
                canhBao: kq.canhBao,
                lyDo: kq.lyDo,
              );
      }
    }
    _phat(state.copyWith(chuoiSoTien: '0', hienBanPhimSo: false, luaChonTienCau: c.luaChon, ketQuaDien: kqMoi));
  }

  /// Bấm Huỷ ở dòng *"Đang kiểm số tiền bằng AI…"*: giữ số luật.
  Future<void> huyKiemSoTien() async {
    // Không có lượt kiểm nào thì thôi — tăng bộ đếm lúc ấy là giết nhầm một lượt Điền đang chạy.
    if (!state.dangKiemSoTien) return;
    _luotDien++;
    unawaited(_nguon.docAi?.huy());
    _phat(state.copyWith(dangKiemSoTien: false));
  }

  /// Huỷ lượt đọc bằng AI: điền ngay bằng luật, mô hình thôi giải mã.
  Future<void> huyDocAi(String cau) async {
    _luotDien++;
    unawaited(_nguon.docAi?.huy());
    final (chonDuoc, tuKhoa) = await _nguon.napDanhMucVaTuKhoa(_taiKhoan());
    if (isClosed) return;
    _dangDien = false;
    emit(state.copyWith(dangDocAi: false));
    if (cau.isNotEmpty) _apDungKetQua(cau, chonDuoc, tuKhoa);
  }

  KetQuaDocCau _docCau(String cau, List<CategoryEntity> chonDuoc, Map<String, List<String>> tuKhoa, {KetQuaAi? ai}) =>
      docCauGiaoDich(
        cau,
        now: DateTime.now(),
        vi: state.vi,
        chonDuoc: chonDuoc,
        mo: _boPhanLoai,
        tatCap: _tatCap,
        ai: ai,
        tuKhoa: tuKhoa,
        // Dòng nguồn "Đọc bằng AI" chỉ khi AI làm ĐỔI một ô — chiều / ví đang chọn không tính (người dùng chốt 2026-09-30).
        chieuDangChon: state.huong,
        viDangChon: state.viNguon?.id,
      );

  /// Đọc câu rồi điền những ô đọc được vào form (xem [dienTuCau]).
  void _apDungKetQua(String cau, List<CategoryEntity> chonDuoc, Map<String, List<String>> tuKhoa, {KetQuaAi? ai}) =>
      dienKetQua(_docCau(cau, chonDuoc, tuKhoa, ai: ai), chonDuoc: chonDuoc);

  /// Điền một [KetQuaDocCau] đã dựng sẵn vào form — phần ÁP, tách khỏi phần đọc câu (2026-09-30, mở D1): ô Nhập nhanh
  /// đi qua [_apDungKetQua], form điền sẵn từ tin biến động số dư (D1) dựng `KetQuaDocCau` từ query rồi gọi thẳng đây,
  /// và giọng nói (C4) sẽ dùng chính cửa này. Mỗi ô đi đúng đường người dùng vẫn đi:
  /// - chiều qua [chonHuong] (bỏ danh mục thuộc chiều kia) — gán thẳng `huong` là để danh mục chi dưới đoạn Thu;
  /// - số tiền qua `themPhimSoTien` từng chữ số (cùng trần 13 chữ số, không để biểu thức dở);
  /// - ví đọc từ câu đặt [_nguoiDungDaChonVi] — luật ví hay dùng theo danh mục không được đè lựa chọn trong câu;
  /// - danh mục qua [chonDanhMuc] (chiều vay/nợ, đoạn Chi/Thu, xoá thẻ gợi ý);
  /// - ghi chú đặt SAU danh mục: [ghiChuDoi] thấy đã có danh mục thì không hẹn gợi ý;
  /// - danh mục đến từ B1 hoặc từ khoá thì đặt [_choPhanXu] như thẻ gợi ý, để lúc lưu ghi phản hồi `chon` / `khac`.
  void dienKetQua(KetQuaDocCau kq, {required List<CategoryEntity> chonDuoc}) {
    if (isClosed) return;
    final now = DateTime.now();
    if (kq.khongDocDuocGi) {
      emit(state.copyWith(
          ketQuaDien: (tomTat: kCauChuaDocDuoc, docDuoc: false, quaAi: kq.quaAi, canhBao: kq.canhBao, lyDo: null)));
      return;
    }

    final loai = kq.loai;
    if (loai != null && loai != state.huong) chonHuong(loai);
    WalletEntity? vi;
    WalletEntity? viDen;
    for (final w in state.vi) {
      if (w.id == kq.walletId) vi = w;
      if (w.id == kq.walletToId) viDen = w;
    }
    var s = state;
    final soTien = kq.soTien;
    if (soTien != null) s = s.copyWith(chuoiSoTien: _goSo(soTien), hienBanPhimSo: false);
    final ngay = kq.ngay;
    if (ngay != null) s = s.copyWith(ngay: DateTime(ngay.year, ngay.month, ngay.day, s.ngay.hour, s.ngay.minute));
    if (vi != null) {
      s = s.copyWith(viNguon: vi);
      _nguoiDungDaChonVi = true;
    }
    // Chuyển ví (§2.9). Câu chỉ nêu ví đích mà ví nguồn đang chọn lại chính là nó → để trống ví nguồn cho người dùng
    // chọn: chuyển vào chính nó là khoản vô nghĩa, và màn không chặn lúc lưu.
    if (viDen != null) {
      s = s.copyWith(viDich: viDen);
      if (vi == null && s.viNguon?.id == viDen.id) s = s.copyWith(viNguon: null);
    }
    emit(s);
    CategoryEntity? danhMuc;
    if (!state.laChuyen && kq.categoryId != null) {
      for (final c in chonDuoc) {
        if (c.id == kq.categoryId) danhMuc = c;
      }
      if (danhMuc != null) chonDanhMuc(danhMuc);
    }
    // Rỗng = câu chỉ có số / ngày / ví: ghi chú người dùng đã gõ giữ nguyên.
    if (kq.ghiChu.isNotEmpty) _datGhiChu(kq.ghiChu);
    final goiY = danhMuc != null ? kq.goiY : null;
    final lyDo = danhMuc != null ? kq.lyDoDanhMuc : null;
    if (goiY != null) _choPhanXu = (goiY: goiY, ghiChu: state.ghiChu.trim());
    emit(state.copyWith(
      ketQuaDien: (
        tomTat: cauDaDien(kq, tenVi: vi?.name, tenViDen: viDen?.name, tenDanhMuc: danhMuc?.name, now: now),
        docDuoc: true,
        quaAi: kq.quaAi,
        canhBao: kq.canhBao,
        lyDo: lyDo,
      ),
    ));
    // Ô Nhập nhanh điền xong mà danh mục VÀ ghi chú còn trống (câu chỉ có số tiền) → nguồn số tiền được thử (dự án C).
    // Form biến động, hoặc câu có để lại ghi chú, thì hàm tự thoát.
    _henGoiYTheoForm();
  }

  /// D1 — điền form từ hàng biến động số dư, qua ĐÚNG đường điền của C2 ([dienKetQua]). Không lưu.
  Future<void> _dienTuBienDong() async {
    final d = _bienDong;
    final id = _taiKhoan();
    if (d == null || isClosed) return;
    final (chonDuoc, tuKhoa) = await _nguon.napDanhMucVaTuKhoa(id);
    String? viId;
    // A5: ảnh quét không gắn nguồn ngân hàng → không bảng "nguồn → ví"; giữ ví mặc định đã chọn sẵn.
    if (id != null && !d.laQuet) {
      try {
        // Dòng nhắc (không đuôi TK) thì thử thêm ví của cả NGUỒN — chỉ khi nó chắc (một ví duy nhất).
        final nho = await _nguon.viTheoNguon(id, d.nguon, d.duoi) ??
            (d.phien != null ? await _nguon.viTheoNguonChung(id, d.nguon) : null);
        // Chỉ ví HOẠT ĐỘNG (`state.vi` là `getActive`): ví đã lưu trữ / xoá thì coi như chưa nhớ.
        if (nho != null && state.vi.any((w) => w.id == nho)) viId = nho;
      } catch (e) {
        debugPrint('[BienDong] đọc ví theo nguồn lỗi: $e');
      }
    }
    if (isClosed) return;
    _viNguonDaNho = viId != null;
    final kq = ketQuaTuBienDong(d, chonDuoc: chonDuoc, mo: _boPhanLoai, tatCap: _tatCap, tuKhoa: tuKhoa, walletId: viId);
    dienKetQua(kq, chonDuoc: chonDuoc);
    var s = state;
    // Lần đầu của cặp nguồn + đuôi: ví TRỐNG, không phải ví mặc định — để ví mặc định là để bảng nguồn → ví học nhầm
    // nó ở lần Lưu đầu, rồi chọn sẵn sai mãi.
    if (viId == null && !d.laQuet) s = s.copyWith(viNguon: null);
    // `dienKetQua` chỉ đổi phần ngày; giờ trong tin là giờ giao dịch (spec §3.3).
    final t = d.thoiGian;
    if (t != null) s = s.copyWith(ngay: t);
    _phat(s);
    // A5 (spec 5.6): gợi ý chuyển khoản và nhắc trùng của D1 không áp cho ảnh quét.
    if (id == null || d.laQuet) return;
    unawaited(_tinhGoiYChuyen(d, id));
    try {
      final so = await _nguon.khoanTrongSo(id);
      final trung = khoanCoTheDaGhi(so, soTien: d.soTien, chieu: d.chieu, ngay: d.thoiGian);
      _phat(state.copyWith(trungTrongSo: trung));
    } catch (e) {
      debugPrint('[BienDong] đọc sổ để nhắc trùng lỗi: $e');
    }
  }

  /// Gợi ý Chuyển khoản (spec 2026-09-30 §2–3): luật cặp trên các hàng đang chờ, rồi luật nội dung tin. Ví phía nguồn
  /// của tin theo luật D1 (chỉ ví đã nhớ); phía kia: đã nhớ → ví duy nhất trùng tên nguồn → trống. Lỗi → không gợi ý.
  Future<void> _tinhGoiYChuyen(DienSanBienDong d, int id) async {
    try {
      final cho = await _nguon.hangBienDongCho(id);
      final gy = goiYChuyenKhoan(d, cho);
      if (gy == null) return;
      Future<String?> nho(String nguon, String? duoi) async {
        final v = await _nguon.viTheoNguon(id, nguon, duoi);
        return v != null && state.vi.any((w) => w.id == v) ? v : null;
      }

      final nhoTu = await nho(gy.nguonTu, gy.duoiTu);
      final nhoDen = await nho(gy.nguonDen, gy.duoiDen);
      if (isClosed) return;
      final ds = [for (final w in state.vi) (id: w.id, ten: w.name)];
      String? doan(String nguon, String? daNho) => daNho ?? (nguon == d.nguon ? null : viTheoTenNguon(nguon, ds));
      _viGoiY = (
        tu: doan(gy.nguonTu, nhoTu),
        den: doan(gy.nguonDen, nhoDen),
        daNhoTu: nhoTu != null,
        daNhoDen: nhoDen != null,
      );
      emit(state.copyWith(goiYChuyen: gy));
    } catch (e) {
      debugPrint('[BienDong] gợi ý chuyển khoản lỗi: $e');
    }
  }

  /// Bấm *Ghi là chuyển khoản*: đổi đoạn qua ĐÚNG [chonHuong], điền hai ví; ô không đoán được để TRỐNG — ví mặc định
  /// ở đây là để bảng nguồn → ví học nhầm (D1 §3.3). Không lưu (bất biến ④ nhóm C).
  void apGoiYChuyen() {
    final gy = state.goiYChuyen;
    final v = _viGoiY;
    if (gy == null || v == null) return;
    chonHuong('transfer');
    _nguoiDungDaChonVi = true;
    _goiYDaApDung = gy;
    _phat(state.copyWith(viNguon: _timVi(state.vi, v.tu), viDich: _timVi(state.vi, v.den), goiYChuyen: null));
  }

  Future<void> _napAnh(DienSanBienDong d) async {
    // Chia sẻ biên lai: hàng đang mở mang ảnh → tìm tệp. Tệp đã mất thì dải nguồn dựng như không có ảnh.
    final anh = d.anh;
    if (anh == null) return;
    // A5: ảnh quét nằm ở kho RIÊNG (`anh_quet/`), kèm danh sách món (mục 11.2b).
    unawaited(_nguon.duongDanAnh(d).then((p) {
      if (p != null) _phat(state.copyWith(duongDanAnh: p));
    }));
    if (d.laQuet && _choTickMon) {
      unawaited(_nguon.docMonQuet(anh).then((m) => _phat(state.copyWith(monQuet: m))));
    }
  }

  /// D1 — xử lý xong một hàng (Lưu): xoá cứng hàng loại 20, nhớ ví ở lần Lưu đầu của cặp. ⚠️ Chạy SAU khi trang `pop`
  /// (Cubit có thể đã đóng): mọi giá trị chốt ĐỒNG BỘ ở đầu hàm, và hàm KHÔNG `emit`. Không bao giờ ném.
  Future<void> dongSauLuu() async {
    final d = _bienDong;
    final id = _taiKhoan();
    if (d == null || id == null) return;
    final gy = _goiYDaApDung;
    final v = _viGoiY;
    final s = state;
    if (gy != null && v != null && s.laChuyen) {
      await dongHangChuyenKhoan(_nguon, d, gy, id,
          viTu: s.viNguon?.id, viDen: s.viDich?.id, daNhoTu: v.daNhoTu, daNhoDen: v.daNhoDen);
    } else {
      await dongHangBienDong(_nguon, d, id, viDaLuu: s.viNguon?.id, nhoVi: !_viNguonDaNho);
    }
  }

  /// Bỏ qua một hàng biến động: xoá nó, không tạo giao dịch.
  Future<void> boQuaBienDong() async {
    final d = _bienDong;
    final id = _taiKhoan();
    if (d != null && id != null) await dongHangBienDong(_nguon, d, id);
  }

  @override
  Future<void> close() {
    _hoanGoiY?.cancel();
    _hoanDeXuat?.cancel();
    _anDaThem?.cancel();
    // A5: ảnh quét chỉ sống tới khi form đóng — MỘT chỗ cho mọi đường thoát (Lưu, Bỏ qua, Back hệ thống, nút ←).
    final d = _bienDong;
    if (d != null && d.laQuet) unawaited(_nguon.xoaAnhQuet(d.anh));
    // C4 §3.4: lượt Gemma đang đọc / kiểm số tiền không được giải mã tiếp 12–18 s sau khi form đã đóng.
    if (state.dangKiemSoTien || state.dangDocAi) unawaited(_nguon.docAi?.huy());
    return super.close();
  }

  /// Danh mục cho sheet *Thêm phần*: danh mục CHI hợp lệ; nạp luôn bảng tra tên / màu cho khối tách.
  Future<List<CategoryEntity>> danhMucChoTach() async {
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
}
