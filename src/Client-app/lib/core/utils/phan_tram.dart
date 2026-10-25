/// Chữ phần trăm từ một tỉ lệ — định nghĩa duy nhất (test quét `lib/` thứ 33, 2026-10-19).
library;

/// `0.426` → `'43%'`: nhân 100, làm tròn về số nguyên gần nhất (`round()` — nửa làm tròn ra xa số 0), thêm `%`.
///
/// Không kẹp: `1.37` → `'137%'` (chi vượt ngân sách phải hiện đúng mức vượt); số âm giữ dấu.
///
/// ⚠️ [tiLe] là NaN / vô cực thì `round()` NÉM `UnsupportedError` — giữ đúng hành vi của bảy bản viết tay trước đây;
/// chỗ gọi không được đưa NaN vào (vd. tỉ lệ trên mẫu số 0).
String chuPhanTram(double tiLe) => '${(tiLe * 100).round()}%';
