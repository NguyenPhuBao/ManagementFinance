/// "Ví này có được cộng vào tổng tài sản không" — **một luật, một chỗ**.
///
/// Trước bản này luật ấy tồn tại ở **ba** bản chép tay không khớp nhau:
///
/// - `WalletRepositoryImpl.getTotalBalance` lọc `includeInTotal` — đúng;
/// - `home_page.dart` cộng `fold` trần trên **mọi** ví — quên hẳn phép lọc,
///   nên ví người dùng đã cố ý loại ra vẫn phình tổng tài sản ở trang chủ;
/// - `bao_cao_repository_impl.dart` chép theo trang chủ ("cùng phép cộng với
///   trang chủ"), nên "số dư cuối kỳ" của báo cáo thừa đúng khoản ấy.
///
/// `WalletCubit.addWallet` từng là bản thứ tư và đã đóng ở `6fd2ce9`. Tệp này
/// tồn tại để không có bản thứ năm.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/wallet/domain/vi_tinh_vao_tong.dart';

void main() {
  test('ví bình thường thì được cộng', () {
    expect(viTinhVaoTong(includeInTotal: true, status: 'active'), isTrue);
  });

  test('ví tắt "Tính vào tổng tài sản" thì không được cộng', () {
    expect(viTinhVaoTong(includeInTotal: false, status: 'active'), isFalse);
  });

  test('ví lưu trữ không được cộng, dù cờ tính vào tổng còn bật', () {
    expect(viTinhVaoTong(includeInTotal: true, status: 'inactive'), isFalse,
        reason: 'Lưu trữ là đóng băng: số dư ví cũ không được phình tổng tài '
            'sản nữa. Đây là nửa "không cộng vào tổng" của mức đóng băng đã '
            'chốt, và là lý do chính Money Lover có tính năng này.');
  });

  test('bỏ lưu trữ thì số cũ tự quay lại — luật là SUY RA, không ghi đè', () {
    // Cùng một ví, chỉ đổi mỗi trạng thái: cờ `includeInTotal` không hề bị
    // chạm tới khi lưu trữ, nên bỏ lưu trữ là con số cũ về nguyên vẹn.
    expect(viTinhVaoTong(includeInTotal: true, status: 'inactive'), isFalse);
    expect(viTinhVaoTong(includeInTotal: true, status: 'active'), isTrue);

    // Còn ví vốn đã bị loại khỏi tổng thì bỏ lưu trữ vẫn cứ bị loại.
    expect(viTinhVaoTong(includeInTotal: false, status: 'inactive'), isFalse);
    expect(viTinhVaoTong(includeInTotal: false, status: 'active'), isFalse);
  });

  test('trạng thái vắng mặt đọc là đang hoạt động', () {
    expect(viTinhVaoTong(includeInTotal: true, status: null), isTrue,
        reason: 'Server im lặng về cột này nghĩa là chưa biết. Đọc thành lưu '
            'trữ là tổng tài sản của người dùng tụt về 0 ở lượt pull đầu tiên '
            'gặp payload thiếu khoá.');
  });

  test('đọc được chữ hoa của server', () {
    expect(viTinhVaoTong(includeInTotal: true, status: 'Active'), isTrue);
    expect(viTinhVaoTong(includeInTotal: true, status: 'Inactive'), isFalse);
  });
}
