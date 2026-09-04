/// Điều hướng khi người dùng bấm vào một thông báo.
///
/// ## Lỗi mà bộ test này canh
///
/// Bấm vào thông báo ngân sách làm app **chết màn đỏ**:
///
/// ```
/// navigator.dart: Failed assertion: '!keyReservation.contains(key)'
/// ```
///
/// Nguyên nhân: `/budget` nằm **bên trong** `StatefulShellRoute.indexedStack`
/// (thanh tab), còn `/notifications` nằm ngoài. `context.push('/budget')` từ
/// trang thông báo bắt go_router dựng thêm **một bản shell thứ hai** chồng lên
/// bản đang có, và hai bản ấy mang cùng một page key — Navigator từ chối.
///
/// Route nằm ngoài shell (`/bills`, `/goals`, `/wallets`) thì `push` bình
/// thường, nên lỗi chỉ xảy ra với đúng một trong bốn loại deeplink. Đó là lý do
/// nó lọt qua mọi vòng kiểm trước: ba loại kia chạy tốt.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/notification/notification_deeplink.dart';

void main() {
  group('deeplink nằm trong thanh tab', () {
    test('nhận ra các route thuộc StatefulShellRoute', () {
      expect(thuocThanhTab('/budget'), isTrue,
          reason: 'Đây chính là route làm app chết màn đỏ khi dùng push().');
      expect(thuocThanhTab('/home'), isTrue);
      expect(thuocThanhTab('/analytics'), isTrue);
      expect(thuocThanhTab('/profile'), isTrue);
    });

    test('route con của một nhánh tab cũng thuộc thanh tab', () {
      expect(thuocThanhTab('/analytics/export'), isTrue,
          reason: '/analytics/export khai bên trong nhánh /analytics, nên nó '
              'cũng kéo theo shell.');
    });
  });

  group('deeplink nằm ngoài thanh tab', () {
    test('các route thông báo hiện dùng đều push được', () {
      expect(thuocThanhTab('/bills'), isFalse);
      expect(thuocThanhTab('/goals'), isFalse);
      expect(thuocThanhTab('/wallets'), isFalse);
      expect(thuocThanhTab('/notifications'), isFalse);
    });
  });

  group('không được nhầm theo tiền tố chuỗi', () {
    test('/budgets không phải là /budget', () {
      expect(thuocThanhTab('/budgets'), isFalse,
          reason: 'So khớp bằng startsWith trần sẽ nuốt luôn mọi route bắt đầu '
              'bằng cùng mấy chữ cái. Hôm nay chưa có /budgets, nhưng một cái '
              'tên như thế là chuyện rất dễ xảy ra, và hậu quả là điều hướng '
              'thay cả stack thay vì chồng lên.');
      expect(thuocThanhTab('/homepage'), isFalse);
      expect(thuocThanhTab('/profiles'), isFalse);
    });
  });

  group('đầu vào lạ không được làm chết điều hướng', () {
    test('chuỗi rỗng và route không tồn tại đều trả false', () {
      expect(thuocThanhTab(''), isFalse);
      expect(thuocThanhTab('/khong-ton-tai'), isFalse,
          reason: 'Trả false nghĩa là đi đường push — go_router tự xử lý route '
              'không khớp, còn ném ở đây thì mất cả trang thông báo.');
    });
  });
}
