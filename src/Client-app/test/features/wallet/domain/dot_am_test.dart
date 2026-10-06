/// Đợt âm của một ví (E6 lượt UX, 2026-10-06): giao dịch làm số dư tụt dưới 0 lần
/// gần nhất — mốc của khoá thông báo "Số dư ví đang âm", để mỗi đợt âm báo một lần.
library;

import 'package:flowmoney/features/wallet/domain/dot_am.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BienDongSo bd(String id, int ngay, double soTien) =>
      (id: id, ngay: DateTime(2026, 10, ngay), soTien: soTien);

  test('sổ rỗng / kết thúc không âm → null', () {
    expect(giaoDichMoDotAm(const []), isNull);
    expect(giaoDichMoDotAm([bd('neo', 1, 100000), bd('a', 2, -100000)]), isNull,
        reason: 'số dư 0 không phải âm — cùng luật walletNegative (balance >= 0)');
  });

  test('⭐ giao dịch làm tụt dưới 0 là mốc; chi thêm khi đang âm KHÔNG đổi mốc', () {
    final so = [bd('neo', 1, 100000), bd('a', 3, -150000)];
    expect(giaoDichMoDotAm(so), 'a');
    expect(giaoDichMoDotAm([...so, bd('b', 4, -20000)]), 'a',
        reason: 'E6: ví còn âm thì không nhắc lại — mốc phải đứng yên');
  });

  test('⭐ hồi lên rồi âm lại → mốc mới (đợt mới báo lại)', () {
    expect(
      giaoDichMoDotAm([
        bd('neo', 1, 100000),
        bd('a', 2, -150000),
        bd('nap', 3, 200000),
        bd('d', 5, -300000),
      ]),
      'd',
    );
  });

  test('xếp theo NGÀY giao dịch chứ không theo thứ tự đưa vào; cùng ngày thì theo id', () {
    expect(giaoDichMoDotAm([bd('a', 3, -150000), bd('neo', 1, 100000)]), 'a');
    expect(giaoDichMoDotAm([bd('y', 2, -60000), bd('x', 2, -60000), bd('neo', 1, 100000)]), 'y',
        reason: 'x trước y: 100k − 60k = 40k còn dương, y mới làm tụt');
  });

  test('âm ngay từ khoản đầu tiên (không có khoản mở sổ) → khoản ấy là mốc', () {
    expect(giaoDichMoDotAm([bd('a', 2, -50000)]), 'a');
  });
}
