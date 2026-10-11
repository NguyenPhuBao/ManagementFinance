// lib/features/transaction/presentation/bloc/them_giao_dich_state.dart
/// Trạng thái form Thêm / Sửa giao dịch (spec `2026-10-11-tach-trang-them-giao-dich-cubit-design.md` mục 4.1).
///
/// Chỉ giữ thứ ĐƯỢC VẼ hoặc được Cubit so lại sau một lần chờ; thứ nội bộ (mô hình, tập tắt, hẹn giờ) nằm trong Cubit.
/// Cố ý không kế thừa `Equatable` (nếp `BudgetDetailState`).
library;

import '../../../../core/database/app_database.dart';
import '../../../category/data/models/category_suggestion.dart';
import '../../../category/domain/category_classify.dart';
import '../../../category/domain/de_xuat_tu_khoa.dart';
import '../../domain/ban_phim_so_tien.dart';
import '../../domain/dien_san_bien_dong.dart';
import '../../domain/doc_mon_hang.dart';
import '../../domain/goi_y_chuyen_khoan.dart';
import '../../domain/tach_giao_dich.dart';

/// Dòng tóm tắt dưới ô Nhập nhanh. Dời từ `widgets/them_giao_dich/o_nhap_nhanh.dart` (widget import lại từ đây).
typedef KetQuaDien = ({String tomTat, bool docDuoc, bool quaAi, List<String> canhBao, String? lyDo});

/// Đề xuất thêm / chuyển từ khoá đang hiện dưới hàng Danh mục; `tenCu` khác `null` = đề xuất chuyển.
typedef DeXuatDangHien = ({DeXuatTuKhoa dx, String tenDanhMuc, String? tenCu});

/// Lính canh của [ThemGiaoDichState.copyWith]: "không truyền" khác "truyền `null`" (xoá về `null`).
const Object _giu = Object();

class ThemGiaoDichState {
  const ThemGiaoDichState({
    required this.laSua,
    required this.huong,
    required this.chuoiSoTien,
    required this.hienBanPhimSo,
    required this.ngay,
    this.ghiChu = '',
    this.vi = const [],
    this.dangNapVi = true,
    this.viNguon,
    this.viDich,
    this.danhMuc,
    this.chieuNo,
    this.goiY,
    this.deXuat,
    this.daThemTuKhoa,
    this.ketQuaDien,
    this.dangDocAi = false,
    this.trungTrongSo = const [],
    this.goiYChuyen,
    this.phanTach = const [],
    this.monQuet = const [],
    this.dmTheoId = const {},
    this.duongDanAnh,
    this.soLanDatGhiChu = 0,
    this.soLanCuonGoiY = 0,
  });

  /// Đang SỬA một giao dịch đã ghi.
  final bool laSua;

  /// Đoạn đầu màn: `'chi'` | `'thu'` | `'transfer'`. ⚠️ Lối vào, không phải sự thật — chiều GHI suy từ danh mục
  /// ([loaiGhi], luật 2026-09-05).
  final String huong;

  /// Chuỗi THÔ đang gõ — có thể là biểu thức (`"50000+30000"`) hoặc số lẻ từ đường sửa (`"12.5"`).
  final String chuoiSoTien;

  /// 16 phím có đang mở theo cờ không (bàn phím hệ thống mở thì trang giấu chúng dù cờ bật — G58).
  final bool hienBanPhimSo;
  final DateTime ngay;

  /// Chữ ô ghi chú, THÔ (chưa trim) — trùng `TextEditingController.text` của trang.
  final String ghiChu;

  /// Ví đang dùng (bộ chọn ví — không ví lưu trữ).
  final List<Wallet> vi;
  final bool dangNapVi;
  final Wallet? viNguon;
  final Wallet? viDich;
  final Category? danhMuc;

  /// Chiều tiền khi danh mục là vay/nợ (`'chi'` | `'thu'`), `null` với mọi danh mục khác.
  final String? chieuNo;

  /// Thẻ gợi ý danh mục đang hiện.
  final CategorySuggestion? goiY;
  final DeXuatDangHien? deXuat;

  /// "Đã thêm / Đã chuyển …" — tự ẩn sau 2 giây.
  final String? daThemTuKhoa;
  final KetQuaDien? ketQuaDien;
  final bool dangDocAi;

  /// D1: khoản trong sổ cùng tiền + chiều + ngày với tin.
  final List<KhoanSo> trungTrongSo;
  final GoiYChuyenKhoan? goiYChuyen;

  /// A5 mục 11 — các phần TÁCH khỏi khoản chi (ngoài phần chính = [danhMuc]).
  final List<PhanTach> phanTach;
  final List<MonHang> monQuet;

  /// Danh mục chi chọn được — tra tên / màu cho khối tách.
  final Map<String, Category> dmTheoId;
  final String? duongDanAnh;

  /// Tăng mỗi lần CHÍNH Cubit đặt ghi chú (Nhập nhanh, biến động, C4) — trang chỉ chép sang ô khi số này đổi.
  final int soLanDatGhiChu;

  /// Tăng khi thẻ gợi ý nguồn số tiền vừa hiện hoặc đổi danh mục — trang cuộn thẻ vào khung nhìn.
  final int soLanCuonGoiY;

  bool get laChuyen => huong == 'transfer';

  /// `type` sẽ ghi xuống SQLite (`chi` | `thu` | `transfer`), suy từ đoạn và danh mục. `null` = chưa đủ dữ kiện.
  String? get loaiGhi {
    if (laChuyen) return 'transfer';
    final c = danhMuc;
    if (c == null) return null;
    if (isDebtClassify(c.classify)) return chieuNo;
    return c.classify == 'thu' ? 'thu' : 'chi';
  }

  /// Dòng *"Tách theo danh mục"* chỉ khi TẠO MỚI một khoản CHI (spec A5 11.1 ý 1).
  bool get choTach => !laSua && huong == 'chi';

  /// Số tiền dưới dạng MỘT con số, `null` khi chưa có (0) hay phép tính còn dở (`"30000+"`).
  double? get soTienDangCo {
    if (coToanTu(chuoiSoTien) && !coPhepToanDangCho(chuoiSoTien)) return null;
    final x = ketQuaBieuThuc(chuoiSoTien);
    return x > 0 ? x : null;
  }

  ThemGiaoDichState copyWith({
    String? huong,
    String? chuoiSoTien,
    bool? hienBanPhimSo,
    DateTime? ngay,
    String? ghiChu,
    List<Wallet>? vi,
    bool? dangNapVi,
    Object? viNguon = _giu,
    Object? viDich = _giu,
    Object? danhMuc = _giu,
    Object? chieuNo = _giu,
    Object? goiY = _giu,
    Object? deXuat = _giu,
    Object? daThemTuKhoa = _giu,
    Object? ketQuaDien = _giu,
    bool? dangDocAi,
    List<KhoanSo>? trungTrongSo,
    Object? goiYChuyen = _giu,
    List<PhanTach>? phanTach,
    List<MonHang>? monQuet,
    Map<String, Category>? dmTheoId,
    Object? duongDanAnh = _giu,
    int? soLanDatGhiChu,
    int? soLanCuonGoiY,
  }) =>
      ThemGiaoDichState(
        laSua: laSua,
        huong: huong ?? this.huong,
        chuoiSoTien: chuoiSoTien ?? this.chuoiSoTien,
        hienBanPhimSo: hienBanPhimSo ?? this.hienBanPhimSo,
        ngay: ngay ?? this.ngay,
        ghiChu: ghiChu ?? this.ghiChu,
        vi: vi ?? this.vi,
        dangNapVi: dangNapVi ?? this.dangNapVi,
        viNguon: identical(viNguon, _giu) ? this.viNguon : viNguon as Wallet?,
        viDich: identical(viDich, _giu) ? this.viDich : viDich as Wallet?,
        danhMuc: identical(danhMuc, _giu) ? this.danhMuc : danhMuc as Category?,
        chieuNo: identical(chieuNo, _giu) ? this.chieuNo : chieuNo as String?,
        goiY: identical(goiY, _giu) ? this.goiY : goiY as CategorySuggestion?,
        deXuat: identical(deXuat, _giu) ? this.deXuat : deXuat as DeXuatDangHien?,
        daThemTuKhoa: identical(daThemTuKhoa, _giu) ? this.daThemTuKhoa : daThemTuKhoa as String?,
        ketQuaDien: identical(ketQuaDien, _giu) ? this.ketQuaDien : ketQuaDien as KetQuaDien?,
        dangDocAi: dangDocAi ?? this.dangDocAi,
        trungTrongSo: trungTrongSo ?? this.trungTrongSo,
        goiYChuyen: identical(goiYChuyen, _giu) ? this.goiYChuyen : goiYChuyen as GoiYChuyenKhoan?,
        phanTach: phanTach ?? this.phanTach,
        monQuet: monQuet ?? this.monQuet,
        dmTheoId: dmTheoId ?? this.dmTheoId,
        duongDanAnh: identical(duongDanAnh, _giu) ? this.duongDanAnh : duongDanAnh as String?,
        soLanDatGhiChu: soLanDatGhiChu ?? this.soLanDatGhiChu,
        soLanCuonGoiY: soLanCuonGoiY ?? this.soLanCuonGoiY,
      );
}
