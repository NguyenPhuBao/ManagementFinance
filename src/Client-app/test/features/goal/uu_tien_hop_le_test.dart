/// Đọc `priority` của mục tiêu cho đúng nghĩa — G32.
///
/// Vì sao cần: client gửi `priority: null` cho mục tiêu CHƯA sắp, nhưng
/// `mapEntityFields('goal')` phía backend gọi `Number(null)` và lưu `0`. Lượt kéo
/// về mang `0` về máy, và `0` đứng trước mọi số đã sắp — mục tiêu chưa sắp nhảy
/// lên ĐẦU danh sách. Đã tái hiện đầu-cuối trên máy ảo ngày 2026-09-10.
///
/// Đọc `<= 0` như `null` là an toàn vì client KHÔNG BAO GIỜ tự sinh số ấy: mọi
/// nhánh của `uuTienSauKhiKeo` cho ra số `>= 1` (`goal_priority.dart`).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/goal/domain/uu_tien_hop_le.dart';

void main() {
  test('null giữ nguyên là chưa sắp', () {
    expect(uuTienHopLe(null), isNull);
  });

  test('0 là một null bị ép, đọc thành chưa sắp', () {
    expect(uuTienHopLe(0), isNull,
        reason: 'Backend lưu 0 cho mục tiêu chưa sắp (`Number(null)`). Đọc là '
            'số thì 0 đứng trước 100, 200, và mục tiêu chưa sắp nhảy lên đầu '
            'danh sách.');
  });

  test('số âm cũng không phải thứ client sinh ra', () {
    expect(uuTienHopLe(-100), isNull);
  });

  test('số dương giữ nguyên, kể cả 1 và điểm giữa hai hàng', () {
    expect(uuTienHopLe(1), 1,
        reason: 'Thả lên đầu khi hàng đầu mang 2 cho ra 1 — giá trị hợp lệ nhỏ '
            'nhất. Đọc nó thành chưa sắp là đẩy một mục tiêu đã sắp xuống cuối.');
    expect(uuTienHopLe(150), 150);
    expect(uuTienHopLe(200), 200);
  });
}
