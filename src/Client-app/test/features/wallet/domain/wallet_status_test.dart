/// Trạng thái ví — **nguồn duy nhất** cho phép ánh xạ giữa ba cách viết.
///
/// Cột `status` đã có ở CẢ hai đầu từ trước tính năng lưu trữ ví, nhưng viết
/// khác nhau: SQLite mặc định `'active'` (chữ thường), còn PostgreSQL có ràng
/// buộc, đo thẳng trên CSDL:
///
/// ```
/// chk_wallet_status CHECK (Status = ANY (ARRAY['Active','Inactive']))
/// ```
///
/// Đây đúng cái bẫy mà `wallet_type.dart` sinh ra để đóng: giá trị không nằm
/// trong CHECK đẩy lên là **kẹt hàng đợi vĩnh viễn, im lặng** — không log,
/// không gì trên màn hình. Nên ba phép ánh xạ (khoá cục bộ, khoá gửi lên, phép
/// đọc ngược) phải khớp nhau và được canh ở đây.
///
/// ⚠️ **`khoaGuiLen` hôm nay không có chỗ gọi nào ngoài tệp test này**, và đó
/// là chủ ý — không phải mã chết bỏ quên. Lý do ban đầu, đo 2026-09-10: lược
/// đồ PostgreSQL tự mâu thuẫn ở đúng cột này — CHECK cho phép `'Inactive'`
/// trong khi kiểu cột là `varchar(7)`, mà chuỗi ấy dài **8 ký tự**. Tối cùng
/// ngày CSDL dev đã nới cột lên `varchar(20)`, nhưng `status` vẫn là cột
/// **cục bộ** cho tới khi mở lại G28 (người dùng chốt để sau), và phép ánh xạ
/// ở đây được giữ sống bằng test để ngày nối lại chỉ tốn một dòng.
/// Xem G28 `docs/CLIENT_APP_KNOWN_GAPS.md` và
/// `docs/superpowers/backend/DA-XONG/WALLET_STATUS_COLUMN_WIDTH.md`.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/wallet/domain/wallet_status.dart';

void main() {
  test('khoá lưu cục bộ là chữ thường', () {
    expect(WalletStatus.hoatDong.khoa, 'active');
    expect(WalletStatus.luuTru.khoa, 'inactive');
  });

  test('mọi trạng thái đẩy lên đúng chữ mà CHECK constraint cho phép', () {
    const choPhep = {'Active', 'Inactive'};
    for (final s in WalletStatus.values) {
      expect(choPhep.contains(s.khoaGuiLen), isTrue,
          reason: 'chk_wallet_status chỉ nhận đúng hai chuỗi này. Đẩy lên chuỗi '
              'khác là vỡ CHECK, và bản ghi kẹt hàng đợi đẩy vĩnh viễn — im '
              'lặng, đúng như ewallet/debt của loại ví trước đây.');
    }
    expect(WalletStatus.hoatDong.khoaGuiLen, 'Active');
    expect(WalletStatus.luuTru.khoaGuiLen, 'Inactive');
  });

  test('đọc được cả chữ hoa của server lẫn chữ thường của SQLite', () {
    expect(WalletStatus.tuKhoa('Active'), WalletStatus.hoatDong);
    expect(WalletStatus.tuKhoa('active'), WalletStatus.hoatDong);
    expect(WalletStatus.tuKhoa('Inactive'), WalletStatus.luuTru);
    expect(WalletStatus.tuKhoa('inactive'), WalletStatus.luuTru);
  });

  test('giá trị lạ và null đọc thành ĐANG HOẠT ĐỘNG', () {
    expect(WalletStatus.tuKhoa(null), WalletStatus.hoatDong,
        reason: 'Server im lặng về cột này nghĩa là CHƯA BIẾT, không phải "hãy '
            'lưu trữ ví". Đọc thành luuTru là ví của người dùng lặng lẽ biến '
            'khỏi mọi bộ chọn ngay lượt pull đầu tiên gặp payload thiếu khoá — '
            'cùng bài học với include_in_total và idgoal.');
    expect(WalletStatus.tuKhoa(''), WalletStatus.hoatDong);
    expect(WalletStatus.tuKhoa('archived'), WalletStatus.hoatDong,
        reason: 'Giá trị lạ KHÔNG được giữ nguyên: giữ nguyên là để nó đi thẳng '
            'lên server rồi vỡ chk_wallet_status.');
  });

  test('laHoatDong là phép hỏi duy nhất cho "ví này dùng được không"', () {
    expect(WalletStatus.laHoatDong('active'), isTrue);
    expect(WalletStatus.laHoatDong('Active'), isTrue);
    expect(WalletStatus.laHoatDong(null), isTrue);
    expect(WalletStatus.laHoatDong('inactive'), isFalse);
    expect(WalletStatus.laHoatDong('Inactive'), isFalse);
  });

  test('nhãn hiển thị không rỗng', () {
    for (final s in WalletStatus.values) {
      expect(s.nhan.trim(), isNotEmpty);
    }
  });
}
