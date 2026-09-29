import '../../../../core/database/app_database.dart';
import '../../domain/phan_loai_ghi_chu.dart';

class CategorySuggestion {
  const CategorySuggestion({
    required this.category,
    required this.matchedKeyword,
    this.nguon = kNguonGoiYTuKhoa,
    String? lyDo,
    String? amTietChinh,
  })  : _lyDo = lyDo,
        _amTietChinh = amTietChinh;

  final Category category;
  final String matchedKeyword;

  /// [kNguonGoiYHoc] | [kNguonGoiYTuKhoa] — cũng là cột `nguon` của bảng phản hồi (B1).
  final String nguon;
  final String? _lyDo;
  final String? _amTietChinh;

  /// Dòng lý do in trên thẻ. Nguồn từ khoá mặc định câu cũ, nên bộ máy từ khoá không phải biết B1.
  String get lyDo => _lyDo ?? cauLyDoTuKhoa(matchedKeyword);

  /// Khoá của luật thôi gợi ý: cụm âm tiết bỏ dấu (nguồn học) hoặc từ khoá khớp.
  String get amTietChinh => _amTietChinh ?? matchedKeyword;

  String get categoryId => category.id;
}

class CategoryKeywordCandidate {
  const CategoryKeywordCandidate({
    required this.category,
    required this.keyword,
  });

  final Category category;
  final String keyword;
}
