/// `AppConstants.baseUrl` kết thúc bằng `/api` vì mọi endpoint REST nằm dưới
/// tiền tố ấy. Socket.io thì gắn vào **gốc** máy chủ (đường dẫn mặc định
/// `/socket.io/`), nên nối thẳng `baseUrl` là bắt tay sai đường dẫn — và hỏng
/// theo kiểu khó lần: server không trả lỗi có nghĩa, client chỉ thấy
/// `connect_error` chung chung rồi thử lại mãi.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/realtime/socket_base_url.dart';

void main() {
  test('bỏ hậu tố /api của địa chỉ máy ảo Android', () {
    expect(socketBaseUrlFrom('http://10.0.2.2:3000/api'), 'http://10.0.2.2:3000',
        reason: 'Đây là địa chỉ thật client dùng trên máy ảo. Giữ /api lại là '
            'bắt tay vào sai đường dẫn.');
  });

  test('bỏ hậu tố /api của địa chỉ web/desktop', () {
    expect(
        socketBaseUrlFrom('http://127.0.0.1:3000/api'), 'http://127.0.0.1:3000');
  });

  test('chịu được dấu gạch chéo thừa ở cuối', () {
    expect(socketBaseUrlFrom('http://127.0.0.1:3000/api/'),
        'http://127.0.0.1:3000');
  });

  test('địa chỉ không có /api thì giữ nguyên', () {
    expect(socketBaseUrlFrom('https://managementfinance.onrender.com'),
        'https://managementfinance.onrender.com',
        reason: 'Bản cloud có thể đổi cách đặt tiền tố; hàm này không được tự '
            'ý cắt thứ nó không thấy.');
  });

  test('không cắt chữ "api" nằm trong tên miền', () {
    expect(socketBaseUrlFrom('https://apihost.example.com/api'),
        'https://apihost.example.com',
        reason: 'Canh chừng một bản cài đặt cắt theo chuỗi con: '
            "replaceAll('api', '') sẽ biến apihost thành host — sai tên miền, "
            'và không có gì báo lỗi.');
  });

  test('đoạn /api nằm GIỮA thì không đụng tới', () {
    expect(socketBaseUrlFrom('http://127.0.0.1:3000/api/v1'),
        'http://127.0.0.1:3000/api/v1',
        reason: "Canh chừng replaceAll('/api', ''): nó sẽ khoét mất khúc giữa "
            'và cho ra một địa chỉ chưa từng tồn tại. Hàm này chỉ bỏ đúng hậu '
            'tố ở CUỐI; thứ nó không nhận ra thì để nguyên, đúng như trường '
            'hợp địa chỉ không có /api.');
  });

  test('khoảng trắng thừa không làm lệch kết quả', () {
    expect(socketBaseUrlFrom('  http://127.0.0.1:3000/api  '),
        'http://127.0.0.1:3000');
  });
}
