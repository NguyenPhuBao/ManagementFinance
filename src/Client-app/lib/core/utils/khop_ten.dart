/// Khớp một TÊN do mô hình gõ (tham số `danh_muc`, `vi` của tool — bước 2) với
/// danh sách tên thật. Dùng chung cho `goi_y_han_muc` và `truy_van_giao_dich`.
///
/// Bỏ dấu ở đây là **đúng chỗ** của `removeVietnameseTones` (tìm kiếm — đoán
/// sai chỉ tốn một lần hỏi lại), khác quy tắc trùng tên danh mục (quy tắc 7
/// `CLAUDE.md`), nơi bỏ dấu bị cấm.
///
/// Ba bậc, bậc trước thắng: bằng nhau sau chuẩn hoá → bằng nhau sau bỏ dấu →
/// bằng nhau sau khi đọc `_` là dấu cách rồi bỏ dấu (bước 2c: E2B gõ
/// `vi: "tiet_kiem"`, bẫy 4.45).
///
/// ⚠️ Không so chuỗi con: "tiết kiệm" khớp ví **Tiết kiệm**, không khớp "tiết
/// kiệm mua nhà". ⚠️ Danh sách đem khớp phải là của CHÍNH tài khoản — lẫn hàng
/// khuôn mặc định toàn cục (`idaccount = 0`) thì mọi tên mặc định khớp hai hàng
/// (spec bước 2, bẫy 14).
///
/// Khác [khopTheoTen] (so TRỌN chuỗi), [timTenTrongCau] / [tenNeuTrongCau] tìm một tên có thật NẰM TRONG một câu — dời
/// từ `ai_edge/domain/chinh_tham_so.dart` ngày 2026-09-29 (C2 task 4) để ô Nhập nhanh của màn Thêm giao dịch dùng chung.
library;

import 'package:unorm_dart/unorm_dart.dart' as unorm;

import '../category/category_name.dart';

sealed class KetQuaKhopTen<T> {
  const KetQuaKhopTen();
}

final class KhopMot<T> extends KetQuaKhopTen<T> {
  const KhopMot(this.muc);
  final T muc;
}

final class KhopNhieu<T> extends KetQuaKhopTen<T> {
  const KhopNhieu(this.ds);
  final List<T> ds;
}

final class KhongKhop<T> extends KetQuaKhopTen<T> {
  const KhongKhop();
}

KetQuaKhopTen<T> khopTheoTen<T>(
  String hoi,
  Iterable<T> ds,
  String Function(T) tenCua,
) {
  final khoa = normalizeCategoryName(hoi);
  if (khoa.isEmpty) return KhongKhop<T>();
  KetQuaKhopTen<T>? theo(String Function(String) chuan) {
    final k = chuan(khoa);
    final trung = [
      for (final x in ds)
        if (chuan(normalizeCategoryName(tenCua(x))) == k) x,
    ];
    if (trung.length == 1) return KhopMot<T>(trung.single);
    if (trung.length > 1) return KhopNhieu<T>(trung);
    return null;
  }

  return theo((s) => s) ??
      theo(removeVietnameseTones) ??
      theo(_gachDuoiLaDauCach) ??
      KhongKhop<T>();
}

/// Bậc ba (bước 2c, bẫy 4.45): E2B gõ tên theo kiểu `snake_case` — `_` đọc là
/// dấu cách ở CẢ hai vế, rồi so bỏ dấu. Chỉ chạy khi hai bậc đầu trượt, nên tên
/// thật có `_` vẫn thắng ở bậc 1 khi gõ y hệt.
String _gachDuoiLaDauCach(String s) =>
    removeVietnameseTones(normalizeCategoryName(s.replaceAll('_', ' ')));

/// Tên NGẮN hơn chừng này ký tự (bỏ dấu) chỉ nhận khi đứng ngay sau từ loại: hoá đơn *"Kiem"* nằm trong *"tiết kiệm"*.
const int _kDaiTenTuDo = 5;

/// Một tên có thật mà câu nêu, kèm `[batDau, ketThuc)` trong câu **đã NFC** (câu dựng sẵn trùng với chính nó). Với tên
/// ngắn, đoạn ấy gồm cả từ loại đứng trước.
typedef TenTrongCau = ({String ten, int batDau, int ketThuc});

/// Tên đối tượng CÓ THẬT mà [cau] nêu (vòng sửa cổng F của Trợ lý AI: E10, E8, F14, C20; C2 dùng cho ví và danh mục).
/// Khớp trọn từ trên chữ bỏ dấu, tên dài trước. ⚠️ Tên ngắn (dưới [_kDaiTenTuDo] ký tự bỏ dấu) chỉ nhận khi đứng ngay
/// sau [tuLoai]. `null` khi không tên nào khớp.
TenTrongCau? timTenTrongCau(String cau, Iterable<String> ten, {required String tuLoai}) {
  final thuong = unorm.nfc(cau).toLowerCase().replaceAll('_', ' ');
  final q = removeVietnameseTones(thuong);
  // Bỏ dấu giữ độ dài với chữ tiếng Việt dựng sẵn; ký tự lạ làm lệch thì vị trí không tin được.
  if (q.length != thuong.length || q.trim().isEmpty) return null;
  final loai = _mauCum(_boDau(tuLoai));
  final bang = [
    for (final t in ten.toSet())
      if (_boDau(t).isNotEmpty) (_boDau(t), t),
  ]..sort((a, b) => b.$1.length.compareTo(a.$1.length));
  for (final (b, goc) in bang) {
    final mau = b.length >= _kDaiTenTuDo ? _mauCum(b) : '$loai\\s+${_mauCum(b)}';
    final m = RegExp('(?<![a-z0-9])$mau(?![a-z0-9])').firstMatch(q);
    if (m != null) return (ten: goc, batDau: m.start, ketThuc: m.end);
  }
  return null;
}

String? tenNeuTrongCau(String cau, Iterable<String> ten, {required String tuLoai}) =>
    timTenTrongCau(cau, ten, tuLoai: tuLoai)?.ten;

/// Bỏ dấu + chuẩn hoá (chữ thường, gom khoảng trắng); `_` đọc là dấu cách.
String _boDau(String s) => removeVietnameseTones(normalizeCategoryName(s.replaceAll('_', ' ')));

/// Mẫu cho một cụm đã chuẩn hoá: các từ nối bằng `\s+`, để khớp câu chưa gom khoảng trắng.
String _mauCum(String b) => b.split(' ').map(RegExp.escape).join(r'\s+');
