/// Đọc lời "tài khoản này không dùng được nữa" từ hai hình dạng của server.
///
/// Luật một chiều của spec §3.1: đọc nhầm thành `biKhoa` chỉ GIỮ dữ liệu, đọc
/// nhầm thành `daXoa` là XOÁ dữ liệu người dùng. Nên mọi thứ lạ → `biKhoa`.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/auth/buoc_dang_xuat.dart';

void main() {
  group('tuSuKienSocket', () {
    test('payload đủ trường của admin xoá → daXoa, giữ nguyên câu và id', () {
      final tb = tuSuKienSocket({
        'idaccount': 11,
        'reason': 'ACCOUNT_DELETED',
        'message':
            'Tài khoản của bạn đã bị ngừng hoạt động hoặc xóa bởi quản trị viên.',
      });

      expect(tb.lyDo, LyDoBuocDangXuat.daXoa);
      expect(tb.nguon, NguonBuocDangXuat.socket);
      expect(tb.idaccount, 11);
      expect(tb.loiNhan, contains('quản trị viên'));
    });

    test('admin khoá gửi ACCOUNT_INACTIVE → biKhoa', () {
      final tb = tuSuKienSocket({
        'idaccount': 11,
        'reason': 'ACCOUNT_INACTIVE',
        'message': 'Tài khoản của bạn đã bị vô hiệu hóa. Lý do: Vi phạm điều khoản.',
      });

      expect(tb.lyDo, LyDoBuocDangXuat.biKhoa,
          reason:
              'ACCOUNT_INACTIVE là khoá tạm (admin mở lại được) — hộp thoại phải nói "bị vô hiệu hoá", không "đã bị xoá"');
    });

    test('reason lạ → biKhoa', () {
      expect(tuSuKienSocket({'reason': 'SOMETHING_NEW'}).lyDo,
          LyDoBuocDangXuat.biKhoa,
          reason: 'mã mới của backend rơi về lý do nhẹ hơn (bị khoá) — không được báo nhầm "tài khoản đã bị xoá"');
    });

    test('thiếu hẳn reason → biKhoa, câu rỗng, id vẫn đọc được', () {
      final tb = tuSuKienSocket({'idaccount': 11});

      expect(tb.lyDo, LyDoBuocDangXuat.biKhoa);
      expect(tb.loiNhan, isEmpty);
      expect(tb.idaccount, 11);
    });

    test('payload không phải Map vẫn ra thông báo biKhoa, không nuốt sự kiện',
        () {
      final tb = tuSuKienSocket('xin chào');

      expect(tb.lyDo, LyDoBuocDangXuat.biKhoa);
      expect(tb.idaccount, isNull);
      expect(tb.loiNhan, isEmpty,
          reason: 'bỏ qua sự kiện là để người dùng ở lại trong app');
    });

    test('payload null cũng vậy', () {
      expect(tuSuKienSocket(null).lyDo, LyDoBuocDangXuat.biKhoa);
    });

    test('idaccount là chuỗi số vẫn đọc được', () {
      expect(tuSuKienSocket({'idaccount': '11'}).idaccount, 11);
    });

    test('idaccount là chuỗi không phải số → null, không ném', () {
      expect(tuSuKienSocket({'idaccount': 'muoi mot'}).idaccount, isNull);
    });

    test('message không phải chuỗi → câu rỗng', () {
      expect(tuSuKienSocket({'message': 42}).loiNhan, isEmpty);
    });

    test('đọc được cả khoá code (hình dạng HTTP) lẫn reason', () {
      expect(tuSuKienSocket({'code': 'ACCOUNT_DELETED'}).lyDo,
          LyDoBuocDangXuat.daXoa);
    });
  });

  group('tuBody401', () {
    test('code ở CẤP GỐC → đọc được, mang đúng nguồn', () {
      final tb = tuBody401({
        'success': false,
        'message': 'Account no longer exists or has been deleted',
        'code': 'ACCOUNT_DELETED',
        'idaccount': 11,
        'reason_inactive': null,
        'errors': null,
      }, nguon: NguonBuocDangXuat.http);

      expect(tb, isNotNull);
      expect(tb!.lyDo, LyDoBuocDangXuat.daXoa);
      expect(tb.nguon, NguonBuocDangXuat.http);
      expect(tb.idaccount, 11);
      expect(tb.loiNhan, 'Account no longer exists or has been deleted');
    });

    test('nguồn lamMoi được giữ nguyên', () {
      final tb =
          tuBody401({'code': 'ACCOUNT_INACTIVE'}, nguon: NguonBuocDangXuat.lamMoi);

      expect(tb, isNotNull);
      expect(tb!.nguon, NguonBuocDangXuat.lamMoi,
          reason: 'nguồn của lượt đăng xuất chỉ phân biệt được nhờ trường này (dữ liệu SQLite giữ tới khi tài khoản khác đăng nhập)');
      expect(tb.lyDo, LyDoBuocDangXuat.biKhoa);
    });

    test('code nằm DƯỚI errors → null (hình dạng lối tắt ResponseHandler.error)',
        () {
      final tb = tuBody401({
        'success': false,
        'message': 'Token expired',
        'errors': {'code': 'ACCOUNT_DELETED'},
      }, nguon: NguonBuocDangXuat.http);

      expect(tb, isNull,
          reason: 'tài liệu AUTH_401_BODY_CODE.md đã bác hình dạng này');
    });

    test('401 token hết hạn thật (không có code) → null, đi đường làm mới', () {
      final tb = tuBody401({
        'success': false,
        'message': 'Token expired',
        'errors': null,
      }, nguon: NguonBuocDangXuat.http);

      expect(tb, isNull,
          reason: 'đọc thành bị khoá là đá người dùng ra vì access token hết hạn');
    });

    test('body không phải Map → null', () {
      expect(tuBody401('<html>502</html>', nguon: NguonBuocDangXuat.http), isNull);
      expect(tuBody401(null, nguon: NguonBuocDangXuat.http), isNull);
    });

    test('code rỗng hoặc không phải chuỗi → null', () {
      expect(tuBody401({'code': ''}, nguon: NguonBuocDangXuat.http), isNull);
      expect(tuBody401({'code': 7}, nguon: NguonBuocDangXuat.http), isNull);
    });

    test('code lạ → biKhoa chứ không phải null', () {
      final tb = tuBody401({'code': 'RATE_LIMITED'}, nguon: NguonBuocDangXuat.http);

      expect(tb, isNotNull,
          reason: 'có code nghĩa là server nói về tài khoản, đừng làm mới token');
      expect(tb!.lyDo, LyDoBuocDangXuat.biKhoa);
    });
  });

  group('bằng nhau theo giá trị', () {
    test('hai thông báo cùng nội dung thì bằng nhau', () {
      const a = ThongBaoBuocDangXuat(
        lyDo: LyDoBuocDangXuat.daXoa,
        nguon: NguonBuocDangXuat.socket,
        loiNhan: 'x',
        idaccount: 11,
      );
      const b = ThongBaoBuocDangXuat(
        lyDo: LyDoBuocDangXuat.daXoa,
        nguon: NguonBuocDangXuat.socket,
        loiNhan: 'x',
        idaccount: 11,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('khác nguồn thì khác nhau', () {
      const a = ThongBaoBuocDangXuat(
          lyDo: LyDoBuocDangXuat.daXoa, nguon: NguonBuocDangXuat.socket);
      const b = ThongBaoBuocDangXuat(
          lyDo: LyDoBuocDangXuat.daXoa, nguon: NguonBuocDangXuat.lamMoi);

      expect(a, isNot(b),
          reason: 'AuthUnauthenticated so sánh bằng props, hai lần đẩy ra khác '
              'nguồn phải là hai state khác nhau');
    });
  });

  group('tuLoiBatTaySocket (G89 mục 5)', () {
    test('dạng gói tin {message, data: {code, idaccount}} → lời buộc đăng xuất nguồn socket, KHÔNG đọc message', () {
      final tb = tuLoiBatTaySocket({
        'message': 'Authentication error: Tài khoản đã bị vô hiệu hoá',
        'data': {'code': 'ACCOUNT_INACTIVE', 'idaccount': 11, 'reason_inactive': 'Vi phạm'},
      });
      expect(tb, isNotNull);
      expect(tb!.lyDo, LyDoBuocDangXuat.biKhoa);
      expect(tb.nguon, NguonBuocDangXuat.socket);
      expect(tb.idaccount, 11);
      expect(tb.loiNhan, '', reason: 'câu "Authentication error: …" cố ý không đọc — hộp thoại dùng câu mặc định');
    });

    test('dạng phẳng {code, idaccount} → cũng nhận', () {
      final tb = tuLoiBatTaySocket({'code': 'ACCOUNT_DELETED', 'idaccount': '12'});
      expect(tb!.lyDo, LyDoBuocDangXuat.daXoa);
      expect(tb.idaccount, 12);
    });

    test('lỗi token / lược đồ / nội bộ (không code) → null → nối lại như cũ', () {
      expect(tuLoiBatTaySocket('lỗi giả'), isNull);
      expect(tuLoiBatTaySocket(null), isNull);
      expect(tuLoiBatTaySocket({'message': 'Authentication error: Token expired'}), isNull);
      expect(tuLoiBatTaySocket({'message': 'x', 'data': const {}}), isNull);
      expect(
          tuLoiBatTaySocket({
            'data': {'code': ''}
          }),
          isNull);
    });
  });
}
