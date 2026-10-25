/// Bản phát hành không được gọi máy chủ CÔNG KHAI qua `http://` (siết bảo mật đợt 2, 2026-10-24).
///
/// Vì sao: mật khẩu, OTP, token làm mới, token socket và toàn bộ dữ liệu đồng bộ đi qua địa chỉ này; `dart:io` (Dio,
/// socket) KHÔNG đọc network-security-config của Android nên hệ điều hành không chặn cleartext (bẫy 4.20
/// `AI_EDGE_FEATURE.md`). Địa chỉ nội bộ (loopback, máy ảo `10.0.2.2`, IP LAN) vẫn cho `http` — đo máy thật với backend
/// dev qua `adb reverse` hoặc IP Wi-Fi của máy tính.
library;

import 'package:flowmoney/core/constants/dia_chi_may_chu.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('kiemDiaChiMayChu — bản phát hành', () {
    test('https tới máy chủ công khai → dùng được', () {
      expect(kiemDiaChiMayChu('https://managementfinance.onrender.com/api', phatHanh: true),
          'https://managementfinance.onrender.com/api');
    });

    for (final url in [
      'http://managementfinance.onrender.com/api',
      'http://172.32.0.1:3000/api', // ngay ngoài dải 172.16–31
      'http://192.169.1.1:3000/api', // ngay ngoài 192.168
      'http://11.0.0.1:3000/api',
      'http://8.8.8.8/api',
      'managementfinance.onrender.com/api', // thiếu scheme: không biết đi đường nào → không cho
    ]) {
      test('$url → từ chối', () {
        expect(() => kiemDiaChiMayChu(url, phatHanh: true),
            throwsA(isA<StateError>().having((e) => e.message, 'message', contains('https'))),
            reason: 'bản phát hành gửi mật khẩu / token qua địa chỉ này — http tới máy chủ công khai là ai cùng mạng '
                'cũng đọc được');
      });
    }

    for (final url in [
      'http://10.0.2.2:3000/api', // máy ảo Android → máy tính
      'http://127.0.0.1:3000/api', // adb reverse
      'http://localhost:3000/api',
      'http://[::1]:3000/api',
      'http://10.1.2.3:3000/api',
      'http://172.16.0.3:3000/api',
      'http://172.31.255.1:3000/api',
      'http://192.168.1.5:3000/api', // IP Wi-Fi của máy tính khi đo máy thật
    ]) {
      test('$url (nội bộ) → vẫn cho http', () {
        expect(kiemDiaChiMayChu(url, phatHanh: true), url,
            reason: 'đo máy thật với backend dev dùng đúng các địa chỉ này — chặn là hỏng cách làm việc của nhóm');
      });
    }
  });

  test('bản debug: http tới máy chủ công khai vẫn cho (chỉ bản phát hành bị chặn)', () {
    expect(kiemDiaChiMayChu('http://managementfinance.onrender.com/api', phatHanh: false),
        'http://managementfinance.onrender.com/api');
  });

  group('chonDiaChiMayChu', () {
    test('không truyền tham số build → địa chỉ mặc định', () {
      expect(chonDiaChiMayChu(tuBuild: '', macDinh: 'http://10.0.2.2:3000/api', phatHanh: true),
          'http://10.0.2.2:3000/api');
    });

    test('có --dart-define=API_BASE_URL → thắng mặc định', () {
      expect(
          chonDiaChiMayChu(
              tuBuild: 'https://managementfinance.onrender.com/api',
              macDinh: 'http://10.0.2.2:3000/api',
              phatHanh: true),
          'https://managementfinance.onrender.com/api');
    });

    test('địa chỉ từ tham số build cũng qua phép kiểm', () {
      expect(
          () => chonDiaChiMayChu(
              tuBuild: 'http://managementfinance.onrender.com/api',
              macDinh: 'http://10.0.2.2:3000/api',
              phatHanh: true),
          throwsStateError);
    });
  });
}
