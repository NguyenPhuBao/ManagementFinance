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

  group('viNguonTrichMacDinh', () {
    // Canh chừng điều gì: biểu mẫu tạo mục tiêu chọn sẵn ví nguồn trích theo
    // ví mặc định của tài khoản, và phép chọn ấy trước đây KHÔNG biết ví tích
    // luỹ là ví nào. Người dùng chọn đúng ví mặc định làm ví tích luỹ — việc
    // rất dễ xảy ra vì đó là ví họ dùng nhiều nhất — thì lần bấm Lưu đầu tiên
    // luôn bị từ chối, dù họ chưa hề chạm vào ô ví nguồn.
    test('ví ưu tiên dùng được thì lấy nó', () {
      expect(
        viNguonTrichMacDinh(
          viCoSan: ['tien-mat', 'tiet-kiem', 'ngan-hang'],
          viNhan: 'tiet-kiem',
          viUuTien: 'ngan-hang',
        ),
        'ngan-hang',
        reason: 'Ví mặc định của tài khoản là phỏng đoán tốt nhất khi nó hợp '
            'lệ — bỏ ưu tiên ấy đi là bắt người dùng sửa lại ở mọi mục tiêu.',
      );
    });

    test('ví ưu tiên CHÍNH LÀ ví tích luỹ thì rơi về ví khác', () {
      expect(
        viNguonTrichMacDinh(
          viCoSan: ['tiet-kiem', 'tien-mat'],
          viNhan: 'tiet-kiem',
          viUuTien: 'tiet-kiem',
        ),
        'tien-mat',
        reason: 'Đây là chính cái lỗi cần sửa: ví mặc định trùng ví tích luỹ '
            'thì biểu mẫu mở ra đã ở trạng thái không lưu được, và người dùng '
            'chỉ biết sau khi bấm Lưu.',
      );
    });

    test('ví ưu tiên không còn trong danh sách thì bỏ qua', () {
      expect(
        viNguonTrichMacDinh(
          viCoSan: ['tien-mat', 'tiet-kiem'],
          viNhan: 'tiet-kiem',
          viUuTien: 'vi-da-bi-xoa',
        ),
        'tien-mat',
        reason: 'Ví mặc định có thể đã bị xoá mềm trong lúc biểu mẫu đang mở. '
            'Trả về một id không có trong danh sách làm ô chọn hiện rỗng mà '
            'biến trạng thái vẫn khác null — nút Lưu qua được phép kiểm rồi '
            'ghi một khoá ngoại trỏ vào hư không.',
      );
    });

    test('không có ví ưu tiên thì hành xử y hệt viNguonMacDinh', () {
      for (final ds in [
        <String>[],
        ['tiet-kiem'],
        ['tiet-kiem', 'tien-mat'],
        ['tien-mat', 'tiet-kiem'],
      ]) {
        expect(
          viNguonTrichMacDinh(viCoSan: ds, viNhan: 'tiet-kiem'),
          viNguonMacDinh(viCoSan: ds, viNhan: 'tiet-kiem'),
          reason: 'ds=$ds — hai hàm phải giữ MỘT định nghĩa duy nhất của '
              '"ví nguồn hợp lệ"; hàm mới chỉ thêm lớp ưu tiên lên trên.',
        );
      }
    });

    test('chỉ có đúng ví tích luỹ, và nó là ví ưu tiên, thì trả null', () {
      expect(
        viNguonTrichMacDinh(
          viCoSan: ['tiet-kiem'],
          viNhan: 'tiet-kiem',
          viUuTien: 'tiet-kiem',
        ),
        isNull,
        reason: 'Không có ví nào trích được. Nơi gọi phải nói ra điều đó thay '
            'vì để ô ví nguồn trống trơn không rõ lý do.',
      );
    });

    test('bất biến: kết quả không bao giờ là ví tích luỹ', () {
      for (final nhan in ['a', 'b', 'c', 'khong-co']) {
        for (final uuTien in [null, 'a', 'b', 'c', 'khong-co']) {
          for (final ds in [
            <String>[],
            ['a'],
            ['a', 'b'],
            ['a', 'b', 'c'],
          ]) {
            final nguon =
                viNguonTrichMacDinh(viCoSan: ds, viNhan: nhan, viUuTien: uuTien);
            expect(nguon == nhan, isFalse,
                reason: 'ds=$ds, ví tích luỹ=$nhan, ưu tiên=$uuTien');
            if (nguon != null) {
              expect(ds.contains(nguon), isTrue,
                  reason: 'ds=$ds, ví tích luỹ=$nhan, ưu tiên=$uuTien');
            }
          }
        }
      }
    });
  });
}
