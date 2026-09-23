/// Bản giả của phiên có tool — kịch bản theo LƯỢT. Vòng lặp (Task 7) dựng mọi
/// ca trên nó, nên nó phải chạy đúng kịch bản và ghi lại đúng thứ đã nhận.
library;

import 'package:flowmoney/features/ai_edge/data/phien_cong_cu.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mỗi sinhLuot là MỘT lượt của kịch bản, theo thứ tự', () async {
    final p = PhienCongCuGia([
      [const GoiCongCu('danh_sach_vi', {})],
      [const Chu('Ví test '), const Chu('đang âm.')],
    ]);
    expect(await p.sinhLuot().toList(), [const GoiCongCu('danh_sach_vi', {})]);
    expect(await p.sinhLuot().toList(),
        [const Chu('Ví test '), const Chu('đang âm.')]);
    expect(p.luotDaSinh, 2);
  });

  test('hết kịch bản → lượt rỗng (mô hình im lặng), không ném', () async {
    final p = PhienCongCuGia([]);
    expect(await p.sinhLuot().toList(), isEmpty);
  });

  test('traKetQua ghi lại (tên, json) theo thứ tự; huy đếm; dong đánh dấu',
      () async {
    final p = PhienCongCuGia([]);
    await p.traKetQua('danh_sach_vi', {'Số ví': '4'});
    await p.traKetQua('danh_sach_hoa_don', {'loi': 'x'});
    // ⚠️ Không so thẳng hai danh sách RECORD: record so `==` từng trường, mà
    // `Map` so bằng danh tính, và matcher `equals` không so sâu vào record —
    // ca viết thế đỏ trên cả mã đúng. Trải cặp ra thành danh sách thì `equals`
    // so sâu được cả tên lẫn JSON, vẫn giữ nguyên thứ tự.
    expect([for (final (ten, json) in p.ketQuaDaNhan) [ten, json]], [
      ['danh_sach_vi', {'Số ví': '4'}],
      ['danh_sach_hoa_don', {'loi': 'x'}],
    ]);
    await p.huy();
    expect(p.soLanHuy, 1);
    expect(p.daDong, isFalse);
    await p.dong();
    expect(p.daDong, isTrue);
  });

  test('GoiCongCu so bằng theo tên và args — để expect(events, [...]) dùng được',
      () {
    expect(const GoiCongCu('a', {'k': 'v'}), const GoiCongCu('a', {'k': 'v'}));
    expect(const GoiCongCu('a', {'k': 'v'}),
        isNot(const GoiCongCu('a', {'k': 'w'})));
  });
}
