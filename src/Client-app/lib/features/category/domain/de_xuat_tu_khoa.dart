/// Đề xuất thêm từ khoá từ thói quen (spec `2026-09-30-de-xuat-them-tu-khoa-design.md`). Hàm thuần: không Drift, không
/// Flutter, không đồng hồ.
///
/// Bộ so từ khoá (`CategorySuggestionEngine`) khớp theo CHUỖI CON trên chữ bỏ dấu — nên mọi phép "đã phủ" ở đây cũng so
/// chuỗi con bỏ dấu: một ghi chú đã chứa từ khoá của danh mục thì bộ so đã bắt được, đề xuất thêm là tiếng ồn.
///
/// Ngưỡng thói quen là CHÍNH ngưỡng của B1 (`kToiThieuMauDanhMuc`, `kNguongXacSuat`) — một định nghĩa "thường ghi".
library;

import '../../../core/category/category_name.dart';
import 'phan_loai_ghi_chu.dart';

/// Từ khoá ngắn là bẫy cho chính người dùng: bộ so khớp chuỗi con, *"ăn"* khớp cả *"căn hộ"*.
const int kToiThieuChuCai = 3;

/// Chữ quá chung để một mình làm từ khoá — một chuỗi tách lúc chạy (cùng nếp `kTuChucNang` của Trợ lý AI). Danh sách
/// khởi điểm của spec §2.2, sửa theo số đo.
const String _kChuChungTho = 'ăn uống mua bán trả đóng nạp tiền đi cho với và của hết mất tốn cái con chiếc lần hôm '
    'nay qua này nữa thêm rồi đã đang sẽ là có không được bị về ra vào lên xuống ở tại từ đến sang';

/// So trên chữ BỎ DẤU, như âm tiết của mẫu.
final Set<String> kChuChung = {for (final t in _kChuChungTho.split(' ')) _boDau(t)};

final RegExp _coChuSo = RegExp(r'\p{N}', unicode: true);
final RegExp _khongPhaiChu = RegExp(r'[^\p{L}]', unicode: true);

String _boDau(String s) => removeVietnameseTones(normalizeCategoryName(s));

class DeXuatTuKhoa {
  /// Chữ người dùng gõ (có dấu), qua `normalizeCategoryName` — thứ sẽ lưu làm từ khoá.
  final String tuKhoa;

  /// Cụm âm tiết bỏ dấu — khoá của luật tắt (`tatCapTu` nguồn `kNguonDeXuatTuKhoa`).
  final String cumBoDau;
  final String categoryId;

  /// Khác `null` = cụm đang là từ khoá của đúng danh mục này → đề xuất CHUYỂN sang [categoryId].
  final String? tuDanhMuc;

  /// Số mẫu của [categoryId] chứa cụm, kể cả lần đang nhập.
  final int soLanCung;

  /// Số mẫu (mọi danh mục) chứa cụm, kể cả lần đang nhập.
  final int soLanTong;
  const DeXuatTuKhoa({
    required this.tuKhoa,
    required this.cumBoDau,
    required this.categoryId,
    required this.tuDanhMuc,
    required this.soLanCung,
    required this.soLanTong,
  });
}

/// Hai từ khoá là MỘT: trùng sau chữ thường + gom khoảng trắng (như `_normalizeKeyword` của DAO), hoặc trùng sau bỏ dấu
/// (bộ so có bước bỏ dấu).
bool cungTuKhoa(String a, String b) =>
    normalizeCategoryName(a) == normalizeCategoryName(b) || _boDau(a) == _boDau(b);

/// `null` = không đề xuất. [mau] là mẫu học của B1 (`mauHocTu`) ĐÃ TRỪ giao dịch đang sửa; lần đang nhập do hàm này cộng
/// vào. [tuKhoa] chỉ gồm từ khoá của danh mục còn sống.
///
/// Chọn cụm DÀI NHẤT (hoà: đứng trước) thoả thói quen + đáng làm từ khoá, RỒI mới áp các luật chặn — áp trước là ✕
/// *"trà sữa"* xong nhận ngay đề xuất *"trà"*.
DeXuatTuKhoa? deXuatTuKhoa({
  required String ghiChu,
  required String categoryId,
  required List<MauGhiChu> mau,
  required Map<String, List<String>> tuKhoa,
  Set<(String, String)> tatCap = const {},
}) {
  final amTiet = amTietCua(ghiChu);
  if (amTiet.isEmpty) return null;
  final ghiChuBoDau = _boDau(ghiChu);
  final cuaC = tuKhoa[categoryId] ?? const <String>[];
  // Ghi chú đã chứa một từ khoá của danh mục → bộ so đã bắt được.
  if (cuaC.any((k) => ghiChuBoDau.contains(_boDau(k)))) return null;

  final tatCa = [...mau, MauGhiChu(categoryId: categoryId, amTiet: amTiet, ngay: DateTime(0))];
  final goc = tuGocCua(ghiChu);
  final bo = [for (final t in goc) _boDau(t)];
  ({int i, int j, int cung, int tong})? tot;
  for (var i = 0; i < goc.length; i++) {
    for (var j = i + 1; j <= goc.length; j++) {
      // Đoạn có chữ số (*"40k"*, *"2026"*) cắt dãy: số không phải từ khoá.
      if (_coChuSo.hasMatch(bo[j - 1])) break;
      if (tot != null && j - i <= tot.j - tot.i) continue;
      final cum = bo.sublist(i, j);
      if (cum.join().replaceAll(_khongPhaiChu, '').length < kToiThieuChuCai) continue;
      if (cum.every(kChuChung.contains)) continue;
      final cung = tatCa.where((x) => x.categoryId == categoryId && chuaLienTiep(x.amTiet, cum)).length;
      final tong = tatCa.where((x) => chuaLienTiep(x.amTiet, cum)).length;
      if (cung < kToiThieuMauDanhMuc || cung / tong < kNguongXacSuat) continue;
      tot = (i: i, j: j, cung: cung, tong: tong);
    }
  }
  if (tot == null) return null;

  final cumBoDau = bo.sublist(tot.i, tot.j).join(' ');
  final hienThi = normalizeCategoryName(goc.sublist(tot.i, tot.j).join(' '));
  // Cụm nằm trong một từ khoá đã có của danh mục → bản rộng hơn, không đề xuất.
  if (cuaC.any((k) => _boDau(k).contains(cumBoDau))) return null;
  if (tatCap.contains((cumBoDau, categoryId))) return null;
  final khac = [
    for (final e in tuKhoa.entries)
      if (e.key != categoryId && e.value.any((k) => cungTuKhoa(k, hienThi))) e.key,
  ];
  // Thuộc ≥ 2 danh mục khác → không biết bỏ ở đâu (spec §4).
  if (khac.length > 1) return null;
  return DeXuatTuKhoa(
    tuKhoa: hienThi,
    cumBoDau: cumBoDau,
    categoryId: categoryId,
    tuDanhMuc: khac.isEmpty ? null : khac.single,
    soLanCung: tot.cung,
    soLanTong: tot.tong,
  );
}
