import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/goal/domain/goal_deposit_wallets.dart';

/// Canh chừng điều gì: ví nhận của một mục tiêu là **cố định** — chọn lúc tạo,
/// chỉ đổi qua "Đổi ví nhận". Phiếu nạp tiền vì thế chỉ còn một ô chọn: ví
/// nguồn. Ví nguồn không được trùng ví nhận, nếu không tiền chuyển sang chính
/// nó mà tiến độ mục tiêu vẫn tăng — tích luỹ được tiền từ hư không.
void main() {
  group('viNguonMacDinh', () {
    test('bỏ qua ví nhận, lấy ví đầu tiên còn lại', () {
      expect(
        viNguonMacDinh(viCoSan: ['tien-mat', 'tiet-kiem'], viNhan: 'tiet-kiem'),
        'tien-mat',
      );
    });

    test('ví nhận đứng đầu danh sách thì nhảy sang ví kế tiếp', () {
      expect(
        viNguonMacDinh(viCoSan: ['tien-mat', 'tiet-kiem'], viNhan: 'tien-mat'),
        'tiet-kiem',
        reason: 'Lấy thẳng phần tử đầu là chọn trúng ví nhận — đúng cặp làm '
            'phiếu nạp vô nghĩa.',
      );
    });

    test('chỉ có đúng ví nhận thì KHÔNG có ví nguồn nào', () {
      expect(
        viNguonMacDinh(viCoSan: ['tiet-kiem'], viNhan: 'tiet-kiem'),
        isNull,
        reason: 'Nơi gọi phải chặn phiếu lại và bảo người dùng tạo thêm ví, '
            'chứ không được mở phiếu rồi để nút xác nhận nổ.',
      );
    });

    test('không còn ví nào thì trả null', () {
      expect(viNguonMacDinh(viCoSan: const [], viNhan: 'tiet-kiem'), isNull);
    });

    test('ví nhận không còn trong danh sách thì mọi ví đều dùng được', () {
      expect(
        viNguonMacDinh(
          viCoSan: ['tien-mat', 'tiet-kiem'],
          viNhan: 'vi-da-bi-xoa',
        ),
        'tien-mat',
      );
    });

    test('bất biến: kết quả không bao giờ là ví nhận', () {
      for (final nhan in ['a', 'b', 'c', 'khong-co']) {
        for (final ds in [
          <String>[],
          ['a'],
          ['a', 'b'],
          ['a', 'b', 'c'],
        ]) {
          final nguon = viNguonMacDinh(viCoSan: ds, viNhan: nhan);
          expect(nguon == nhan, isFalse,
              reason: 'ds=$ds, ví nhận=$nhan');
          if (nguon != null) expect(ds.contains(nguon), isTrue);
        }
      }
    });
  });
}
