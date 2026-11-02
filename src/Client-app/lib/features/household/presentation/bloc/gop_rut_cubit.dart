import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../transaction/data/models/transaction_entity.dart';
import '../../../transaction/domain/ban_phim_so_tien.dart';
import '../../../wallet/data/models/wallet_entity.dart';
import '../../../wallet/domain/wallet_type.dart';
import '../../application/gop_quy_service.dart';
import '../../data/repositories/du_lieu_nha_repository.dart';

enum CheDoQuy { gop, rut }

const _cauKhoanMat = 'Khoản này không còn.';
const _cauKhongDoc = 'Không đọc được dữ liệu. Thử lại sau.';
const _cauKhongGhi = 'Không ghi được khoản. Thử lại sau.';
const _cauKhongPhien = 'Không xác định được tài khoản. Hãy đăng nhập lại.';
const _cauDangLuu = 'Đang lưu khoản, chờ một chút.';

class GopRutState {
  const GopRutState({
    required this.cheDo,
    this.chuoiSoTien = '0',
    this.viChung = const [],
    this.viRieng = const [],
    this.chonChung,
    this.chonRieng,
    this.tienMat = false,
    required this.ngay,
    this.ghiChu = '',
    this.dangSua = false,
    this.dangLuu = false,
    this.daNap = false,
    this.hienBanPhimSo = true,
    this.cauDong,
  });

  final CheDoQuy cheDo;

  /// Chuỗi gõ của bàn phím số (có thể là biểu thức `a+b`); số tiền thật là `ketQuaBieuThuc`.
  final String chuoiSoTien;
  final List<WalletEntity> viChung, viRieng;
  final WalletEntity? chonChung, chonRieng;

  /// Chỉ góp: không trừ ví riêng nào, chỉ nửa của nhà.
  final bool tienMat;
  final DateTime ngay;
  final String ghiChu;
  final bool dangSua, dangLuu, daNap, hienBanPhimSo;

  /// Có câu thì trang báo rồi tự đóng (khoản đã mất, nạp hỏng).
  final String? cauDong;

  GopRutState copyWith({
    CheDoQuy? cheDo,
    String? chuoiSoTien,
    List<WalletEntity>? viChung,
    List<WalletEntity>? viRieng,
    WalletEntity? chonChung,
    WalletEntity? chonRieng,
    bool? tienMat,
    DateTime? ngay,
    String? ghiChu,
    bool? dangSua,
    bool? dangLuu,
    bool? daNap,
    bool? hienBanPhimSo,
    String? cauDong,
  }) =>
      GopRutState(
        cheDo: cheDo ?? this.cheDo,
        chuoiSoTien: chuoiSoTien ?? this.chuoiSoTien,
        viChung: viChung ?? this.viChung,
        viRieng: viRieng ?? this.viRieng,
        chonChung: chonChung ?? this.chonChung,
        chonRieng: chonRieng ?? this.chonRieng,
        tienMat: tienMat ?? this.tienMat,
        ngay: ngay ?? this.ngay,
        ghiChu: ghiChu ?? this.ghiChu,
        dangSua: dangSua ?? this.dangSua,
        dangLuu: dangLuu ?? this.dangLuu,
        daNap: daNap ?? this.daNap,
        hienBanPhimSo: hienBanPhimSo ?? this.hienBanPhimSo,
        cauDong: cauDong ?? this.cauDong,
      );
}

/// Màn Góp vào quỹ / Rút về ví riêng (`docs/Family/02A` mục 5). Có [maCap] là sửa một cặp: ví khoá, chiều lấy theo nửa của nhà.
///
/// - `idaccount` chỉ từ [taiKhoan] (phiên), đọc trước mọi `await` của [luu]; không phiên thì không ghi (quy tắc 2).
/// - Số tiền gõ qua `themPhimSoTien` (trần 13 chữ số) và đọc bằng `ketQuaBieuThuc`.
class GopRutCubit extends Cubit<GopRutState> {
  GopRutCubit({
    required GopQuyService gopQuy,
    required DuLieuNhaRepository duLieu,
    required Future<List<WalletEntity>> Function() napViRieng,
    required this.idNha,
    required int? Function() taiKhoan,
    required CheDoQuy cheDo,
    this.viChungId,
    this.maCap,
    DateTime Function()? bayGio,
  })  : _gopQuy = gopQuy,
        _duLieu = duLieu,
        _napViRieng = napViRieng,
        _taiKhoan = taiKhoan,
        super(GopRutState(cheDo: cheDo, ngay: (bayGio ?? DateTime.now)()));

  final GopQuyService _gopQuy;
  final DuLieuNhaRepository _duLieu;
  final Future<List<WalletEntity>> Function() _napViRieng;
  final int? Function() _taiKhoan;
  final int idNha;
  final String? viChungId;
  final String? maCap;

  Future<void> moTrang() async {
    try {
      var cheDo = state.cheDo;
      TransactionEntity? nuaNha, nuaRieng;
      final ma = maCap;
      if (ma != null) {
        final cap = await _gopQuy.docCap(ma);
        if (isClosed) return;
        nuaNha = cap.nha;
        nuaRieng = cap.rieng;
        if (nuaNha == null) {
          emit(state.copyWith(daNap: true, dangSua: true, cauDong: _cauKhoanMat));
          return;
        }
        // Chỉ người ghi sửa khoản có mã cặp (`Family/01` mục 3): nửa riêng chỉ nằm trên máy họ, máy khác sửa nửa nhà là lệch cặp
        // và server từ chối. `GopQuyService.sua` không kiểm quyền nên chốt ở đây, không chỉ ở nút Sửa của sheet.
        if (nuaNha.idaccount != _taiKhoan()) {
          emit(state.copyWith(daNap: true, dangSua: true, cauDong: 'Chỉ người ghi mới sửa được khoản này.'));
          return;
        }
        // Nửa của nhà: `thu` là góp, `chi` là rút (cùng luật `phanLoaiKhoanNha`).
        cheDo = nuaNha.type == 'thu' ? CheDoQuy.gop : CheDoQuy.rut;
      }
      final idViChung = nuaNha?.walletId ?? viChungId;
      final viChung = await _duLieu.viChungChoForm(idNha, giuLai: {if (nuaNha != null) nuaNha.walletId}, uuTien: idViChung);
      // Ví `banking` chỉ có nghĩa với liên kết ngân hàng đã bỏ: không cho chọn.
      final viRieng = [for (final v in await _napViRieng()) if (WalletType.tuKhoa(v.type) != WalletType.banking) v];
      if (isClosed) return;
      final chung = viChung.where((v) => v.id == idViChung).firstOrNull ?? viChung.firstOrNull;
      final riengDaChon = nuaRieng == null
          ? (viRieng.where((v) => v.isDefault).firstOrNull ?? viRieng.firstOrNull)
          : viRieng.where((v) => v.id == nuaRieng!.walletId).firstOrNull;
      emit(GopRutState(
        cheDo: cheDo,
        chuoiSoTien: nuaNha == null ? state.chuoiSoTien : _goSo(nuaNha.amount),
        viChung: viChung,
        viRieng: viRieng,
        chonChung: chung,
        chonRieng: riengDaChon,
        // Sửa mà máy không còn nửa riêng (tiền mặt trao tay, hoặc nửa riêng đã bị gỡ): chỉ còn nửa của nhà để sửa.
        tienMat: nuaNha != null && nuaRieng == null,
        ngay: nuaNha?.date ?? state.ngay,
        ghiChu: nuaNha?.note ?? '',
        dangSua: nuaNha != null,
        daNap: true,
        hienBanPhimSo: nuaNha == null,
      ));
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(daNap: true, cauDong: _cauKhongDoc));
    }
  }

  static String _goSo(double v) {
    var a = '0';
    for (final c in v.toInt().toString().split('')) {
      a = themPhimSoTien(a, c);
    }
    return a;
  }

  void goPhim(String k) => emit(state.copyWith(chuoiSoTien: themPhimSoTien(state.chuoiSoTien, k)));

  /// Chạm khối số tiền. Bàn phím hệ thống đang mở (gõ ghi chú) thì 16 phím bị giấu dù cờ bật — đảo cờ lúc ấy là tắt phím mà
  /// không thấy gì đổi; nên MỞ 16 phím (trang tự đóng bàn phím hệ thống). Cùng luật G58 của form Thêm giao dịch.
  void chamSoTien({required bool banPhimHeThongMo}) =>
      emit(state.copyWith(hienBanPhimSo: banPhimHeThongMo || !state.hienBanPhimSo));

  /// Sửa thì ví khoá (hai nửa đã nằm ở ví cố định, `GopQuyService.sua` không đổi ví).
  void chonChung(WalletEntity v) {
    if (!state.dangSua) emit(state.copyWith(chonChung: v));
  }

  void chonRieng(WalletEntity v) {
    if (!state.dangSua) emit(state.copyWith(chonRieng: v));
  }

  /// Chỉ góp, chỉ lúc tạo: rút luôn về một ví riêng.
  void datTienMat(bool bat) {
    if (state.dangSua || state.cheDo != CheDoQuy.gop) return;
    emit(state.copyWith(tienMat: bat));
  }

  void chonNgay(DateTime d) => emit(state.copyWith(ngay: d));

  void ghiChuDoi(String s) => emit(state.copyWith(ghiChu: s));

  /// `null` = đã lưu; chuỗi = câu lỗi để trang báo.
  Future<String?> luu() async {
    if (state.dangLuu) return _cauDangLuu;
    if (state.cauDong != null) return state.cauDong;
    // Quy tắc 2: idaccount chỉ từ phiên, đọc trước mọi `await`.
    final idaccount = _taiKhoan();
    if (idaccount == null) return _cauKhongPhien;
    final soTien = ketQuaBieuThuc(state.chuoiSoTien);
    if (!(soTien > 0)) return 'Vui lòng nhập số tiền lớn hơn 0.';
    final chung = state.chonChung;
    if (chung == null) return 'Vui lòng chọn ví chung.';
    final cheDo = state.cheDo;
    final dungViRieng = cheDo == CheDoQuy.rut || !state.tienMat;
    final rieng = state.chonRieng;
    if (!state.dangSua && dungViRieng && rieng == null) return 'Vui lòng chọn ví riêng.';
    emit(state.copyWith(dangLuu: true));
    try {
      final ma = maCap;
      if (ma != null) {
        final ok = await _gopQuy.sua(maCap: ma, soTien: soTien, ngay: state.ngay, ghiChu: state.ghiChu.trim());
        if (ok) return null;
        // Cặp đã bị gỡ ở máy khác rồi kéo về: không còn gì để sửa, trang báo và đóng.
        emit(state.copyWith(cauDong: _cauKhoanMat));
        return _cauKhoanMat;
      }
      if (cheDo == CheDoQuy.gop) {
        await _gopQuy.gop(
          idNha: idNha,
          idaccount: idaccount,
          viChungId: chung.id,
          tenViChung: chung.name,
          soTien: soTien,
          viRiengId: state.tienMat ? null : rieng!.id,
          ngay: state.ngay,
          ghiChu: state.ghiChu.trim(),
        );
      } else {
        await _gopQuy.rut(
          idNha: idNha,
          idaccount: idaccount,
          viChungId: chung.id,
          tenViChung: chung.name,
          soTien: soTien,
          viRiengId: rieng!.id,
          ngay: state.ngay,
          ghiChu: state.ghiChu.trim(),
        );
      }
      return null;
    } on CacheException catch (e) {
      return e.message;
    } catch (_) {
      return _cauKhongGhi;
    } finally {
      if (!isClosed) emit(state.copyWith(dangLuu: false));
    }
  }
}
