/// Tool `danh_sach_danh_muc` — hàng theo TÊN, không số (spec mở rộng tool
/// 2026-09-27 §4.3). Trước tool này không tool nào liệt kê danh mục: câu *"tôi
/// có những danh mục nào"* không trả lời được.
///
/// ⚠️ Trần RIÊNG [kToiDaDanhMuc], không phải `kToiDaMucMoiGoi`: hàng ở đây chỉ
/// có tên và trạng thái (không số liệu) nên rẻ, và câu hỏi là *liệt kê* — cắt
/// còn bốn thì câu trả lời sai. Tài khoản thật có 16 danh mục (đo 2026-09-27).
///
/// Phân loại so bằng `kCategoryClassifies` — không viết lại chuỗi phân loại ở
/// đây (test quét 14).
library;

import '../../../core/category/category_classify.dart';
import '../../../core/category/category_name.dart';
import '../../../core/database/app_database.dart';
import 'goi_so.dart';
import 'hang_so_lieu.dart';
import 'loi_tham_so.dart';

const int kToiDaDanhMuc = 20;

/// Mã tham số `loai` → phân loại danh mục; `null` = mọi loại.
final Map<String, String?> kLoaiDanhMuc = {
  'khoan_chi': kCategoryClassifies[0],
  'khoan_thu': kCategoryClassifies[1],
  'vay_no': kCategoryClassifies[2],
  'tat_ca': null,
};

const String kLoaiDanhMucMacDinh = 'tat_ca';

String _chuLoai(String classify) {
  final i = kCategoryClassifies.indexOf(classify);
  return const ['khoản chi', 'khoản thu', 'vay nợ'][i < 0 ? 0 : i];
}

/// [danhMuc]: danh mục CON chọn được của tài khoản (đã bỏ hàng xoá mềm, bỏ
/// nhóm). [coNganSach]: id danh mục đang có ngân sách chạy.
KetQuaCongCu hangDanhMuc(
  List<Category> danhMuc, {
  required Set<String> coNganSach,
  String loai = kLoaiDanhMucMacDinh,
}) {
  if (!kLoaiDanhMuc.containsKey(loai)) {
    return tuChoiGiaTri('loai', loai, kLoaiDanhMuc.keys);
  }
  final loc = kLoaiDanhMuc[loai];
  int dem(int i) =>
      danhMuc.where((c) => c.classify == kCategoryClassifies[i]).length;
  final chon = [
    for (final c in danhMuc)
      if (loc == null || c.classify == loc) c,
  ]..sort((a, b) {
      final x = kCategoryClassifies
          .indexOf(a.classify)
          .compareTo(kCategoryClassifies.indexOf(b.classify));
      return x != 0 ? x : _khoaXep(a.name).compareTo(_khoaXep(b.name));
    });
  return KetQuaCongCu(
    hang: [
      for (final c in chon.take(kToiDaDanhMuc))
        HangSoLieu(
          ten: c.name,
          trangThai: coNganSach.contains(c.id)
              ? '${_chuLoai(c.classify)} · có ngân sách'
              : _chuLoai(c.classify),
          canhBao: false,
          soLieu: const [],
        ),
    ],
    // ⚠️ Nhãn KHÔNG để chữ loại đứng ngay sau "danh mục": `kiemTen` đọc cụm sau
    // từ loại là một TÊN, và "Số danh mục vay nợ" làm mẫu câu của chính gói bị
    // chặn vì không có danh mục nào tên "vay nợ". Dạng ấy chỉ là nhãn thay thế.
    tongHop: [
      soDem('Tổng số danh mục', danhMuc.length,
          nhanKhac: const ['Số danh mục', 'Danh mục']),
      soDem('Nhóm chi', dem(0), nhanKhac: const ['Danh mục chi']),
      soDem('Nhóm thu', dem(1), nhanKhac: const ['Danh mục thu']),
      soDem('Nhóm vay nợ', dem(2), nhanKhac: const ['Danh mục vay nợ']),
      soDem('Đã có ngân sách',
          danhMuc.where((c) => coNganSach.contains(c.id)).length,
          nhanKhac: const ['Có ngân sách', 'Đã đặt ngân sách']),
    ],
    boLoc: [if (loc != null) 'danh mục ${_chuLoai(loc)}'],
    // Hàng không có số liệu nên tên không nằm trên `SoLieu` nào — đưa vào tên
    // liên quan để `kiemTen` và bộ kiểm số nhận ra chúng.
    // "vay nợ" để câu "một danh mục vay nợ" của mô hình không bị `kiemTen` coi
    // là nêu một danh mục TÊN "vay nợ".
    tenLienQuan: [for (final c in chon) c.name, 'vay nợ'],
  );
}

/// Khoá xếp theo bảng chữ cái: bỏ dấu để "Ăn uống" đứng ở A chứ không sau "z".
/// Chỉ để XẾP — không dùng cho so trùng tên (quy tắc 7 `CLAUDE.md`).
String _khoaXep(String ten) => removeVietnameseTones(normalizeCategoryName(ten));
