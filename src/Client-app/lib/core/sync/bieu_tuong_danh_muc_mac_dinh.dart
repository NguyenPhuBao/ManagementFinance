/// Biểu tượng và màu mặc định cho danh mục kéo về không mang hai cột ấy — đoán theo tên. Thân dời nguyên văn từ
/// `SyncEngine` (spec `docs/superpowers/specs/2026-10-19-tach-sync-engine-design.md`); chỉ nhánh kéo về dùng.
library;

String defaultIconForCategoryName(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('ăn') || lower.contains('uống')) return 'restaurant';
  if (lower.contains('xe') || lower.contains('di chuyển'))
    return 'directions_car';
  if (lower.contains('sắm')) return 'shopping_bag';
  if (lower.contains('y tế') ||
      lower.contains('sức khoẻ') ||
      lower.contains('sức khỏe') ||
      lower.contains('thuốc')) return 'local_hospital';
  if (lower.contains('học') || lower.contains('giáo dục')) return 'school';
  if (lower.contains('trí') ||
      lower.contains('game') ||
      lower.contains('phim')) return 'sports_esports';
  if (lower.contains('nhà')) return 'home';
  if (lower.contains('đơn') || lower.contains('dịch vụ')) return 'receipt';
  if (lower.contains('lương')) return 'work';
  if (lower.contains('thưởng') || lower.contains('quà'))
    return 'card_giftcard';
  if (lower.contains('đầu tư') || lower.contains('lãi')) return 'trending_up';
  if (lower.contains('vay') || lower.contains('nợ')) return 'attach_money';
  return 'category';
}

String defaultColorForCategoryName(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('ăn') || lower.contains('uống')) return '#FF5722';
  if (lower.contains('xe') || lower.contains('di chuyển')) return '#2196F3';
  if (lower.contains('sắm')) return '#9C27B0';
  if (lower.contains('y tế') ||
      lower.contains('sức khoẻ') ||
      lower.contains('sức khỏe')) return '#F44336';
  if (lower.contains('học') || lower.contains('giáo dục')) return '#3F51B5';
  if (lower.contains('trí') || lower.contains('game')) return '#E91E63';
  if (lower.contains('nhà')) return '#607D8B';
  if (lower.contains('đơn')) return '#795548';
  if (lower.contains('lương')) return '#4CAF50';
  if (lower.contains('thưởng')) return '#8BC34A';
  if (lower.contains('đầu tư')) return '#009688';
  return '#4CAF50';
}
