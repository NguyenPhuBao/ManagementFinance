/// Chín mã sự kiện của nhật ký thông báo (B5a) — **Dart thuần, không import gì**.
///
/// Tách khỏi `nhat_ky_thong_bao.dart` vì `cham_hdh.dart` cần các mã này, mà
/// `os_notifier.dart` import `cham_hdh.dart`: trừu tượng ấy phải giữ thuần cho
/// web build (bẫy 7.7 `NOTIFICATION_FEATURE.md`), không được kéo `drift` hay
/// `app_database.dart` theo qua cửa ghi.
library;

/// Chữ thô vì là giá trị lưu trong SQLite — đổi một chữ là dữ liệu cũ đọc
/// không ra, im lặng. Thêm mã mới thì được, đổi mã cũ thì không.
abstract final class SuKienThongBao {
  static const moTrongApp = 'mo_trong_app';
  static const gatBo = 'gat_bo';
  static const khoiPhuc = 'khoi_phuc';
  static const docTatCa = 'doc_tat_ca';
  static const chamHdh = 'cham_hdh';
  static const nutTraNgay = 'nut_tra_ngay';
  static const hoan = 'hoan';
  static const datLich = 'dat_lich';
  static const huyLich = 'huy_lich';
}
