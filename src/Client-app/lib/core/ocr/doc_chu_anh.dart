import 'dong_ocr.dart';

/// Đọc chữ trên một ảnh trong máy → các dòng kèm khung. Giao diện thuần để `NhapBienLai` test được bằng bản giả;
/// bản thật (`DocChuAnhMlKit`) là tệp DUY NHẤT của `lib/` (ngoài màn spike C4) import gói ML Kit —
/// `chi_mot_noi_import_mlkit_test.dart` canh.
abstract class DocChuAnh {
  /// Không ném với ảnh hỏng — trả danh sách rỗng.
  Future<List<DongOcr>> doc(String duongDan);
}
