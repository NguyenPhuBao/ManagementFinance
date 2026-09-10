/// Loại ví — **một nguồn duy nhất**, thay cho các danh sách hardcode.
///
/// ## Vì sao chỉ còn ba loại chọn được
///
/// PostgreSQL có ràng buộc, đo thẳng trên CSDL ngày 2026-09-09:
///
/// ```
/// chk_wallet_type CHECK (Type = ANY (ARRAY['Cash','Bank','Saving','Banking']))
/// ```
///
/// Trước bản này, giao diện cho chọn `cash | bank | ewallet | debt` (hardcode
/// **trùng lặp** ở `wallet_add_page` và `wallet_edit_page`), còn
/// `wallet_list_page` thì lại biết thêm cả `investment`. Hai giá trị `ewallet`
/// và `debt` **không nằm trong ràng buộc**, nên ví tạo bằng chúng đẩy lên là
/// vỡ CHECK, bị phân loại lỗi vĩnh viễn, và **kẹt hàng đợi đẩy mãi mãi** — mà
/// không một dòng nào trên màn hình nói ra.
///
/// `Banking` thì client **không được phép tạo**: ràng buộc `chk_wallet_banking_link`
/// đòi nó phải đi kèm `Id_bank_casso`, thứ chỉ luồng liên kết ngân hàng mới có.
/// Nó vẫn phải **đọc được** vì server có thể trả về.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/wallet/domain/wallet_type.dart';
import 'package:flowmoney/features/wallet/presentation/widgets/wallet_type_icon.dart';

void main() {
  test('chỉ ba loại được phép chọn, đúng thứ tự', () {
    expect(WalletType.chonDuoc, [
      WalletType.cash,
      WalletType.bank,
      WalletType.saving,
    ]);
  });

  test('banking đọc được nhưng KHÔNG chọn được', () {
    expect(WalletType.chonDuoc.contains(WalletType.banking), isFalse,
        reason: 'chk_wallet_banking_link đòi Banking phải kèm Id_bank_casso — '
            'thứ chỉ luồng liên kết ngân hàng mới tạo ra. Cho chọn ở đây là '
            'sinh ra một ví không bao giờ đẩy lên được.');
    expect(WalletType.tuKhoa('banking'), WalletType.banking,
        reason: 'Server vẫn trả về loại này, nên phép ĐỌC phải hiểu nó.');
    expect(WalletType.banking.nhan.trim(), isNotEmpty);
  });

  test('mọi loại đều đẩy lên đúng chữ mà CHECK constraint cho phép', () {
    const choPhep = {'Cash', 'Bank', 'Saving', 'Banking'};
    for (final t in WalletType.values) {
      expect(choPhep.contains(t.khoaGuiLen), isTrue,
          reason: 'chk_wallet_type chỉ nhận đúng bốn chuỗi này. Đẩy lên chuỗi '
              'khác là vỡ CHECK, và bản ghi kẹt hàng đợi vĩnh viễn.');
    }
    expect(WalletType.cash.khoaGuiLen, 'Cash');
    expect(WalletType.bank.khoaGuiLen, 'Bank');
    expect(WalletType.saving.khoaGuiLen, 'Saving');
    expect(WalletType.banking.khoaGuiLen, 'Banking');
  });

  test('khoá lưu cục bộ là chữ thường', () {
    expect(WalletType.cash.khoa, 'cash');
    expect(WalletType.bank.khoa, 'bank');
    expect(WalletType.saving.khoa, 'saving');
    expect(WalletType.banking.khoa, 'banking');
  });

  group('đọc giá trị lạ', () {
    test('hai loại đã bỏ đọc thành ví ngân hàng', () {
      expect(WalletType.tuKhoa('ewallet'), WalletType.bank,
          reason: 'Ví điện tử giữ tiền dưới dạng điện tử — gần "ngân hàng" hơn '
              '"tiền mặt". Migration cục bộ cũng chuyển sang đúng loại này, hai '
              'chỗ phải khớp nhau.');
      expect(WalletType.tuKhoa('debt'), WalletType.bank,
          reason: 'Thẻ tín dụng không khớp hẳn loại nào trong ba; ngân hàng là '
              'gần nhất, và người dùng sửa lại được bằng một cú chạm.');
    });

    test('giá trị không nhận ra thì về tiền mặt, KHÔNG giữ nguyên', () {
      expect(WalletType.tuKhoa('investment'), WalletType.cash);
      expect(WalletType.tuKhoa('linh tinh'), WalletType.cash);
      expect(WalletType.tuKhoa(''), WalletType.cash);
      expect(WalletType.tuKhoa(null), WalletType.cash,
          reason: 'Giữ nguyên giá trị lạ là để nó đi thẳng lên server rồi vỡ '
              'CHECK — đúng cái bẫy mà bản này sinh ra để đóng. Về tiền mặt thì '
              'ví vẫn đồng bộ được, và người dùng sửa lại được.');
    });

    test('không phân biệt hoa thường', () {
      expect(WalletType.tuKhoa('Cash'), WalletType.cash);
      expect(WalletType.tuKhoa('SAVING'), WalletType.saving);
      expect(WalletType.tuKhoa('Banking'), WalletType.banking);
    });
  });

  test('mọi loại đều có nhãn tiếng Việt và biểu tượng riêng', () {
    final nhan = <String>{};
    final icon = <int>{};
    for (final t in WalletType.values) {
      expect(t.nhan.trim(), isNotEmpty,
          reason: 'Thêm loại mà quên nhãn thì ô chọn hiện ra rỗng, và không có '
              'gì báo lỗi.');
      nhan.add(t.nhan);
      icon.add(t.icon.codePoint);
    }
    expect(nhan, hasLength(WalletType.values.length),
        reason: 'Hai loại trùng nhãn thì người dùng không phân biệt được.');
    expect(icon, hasLength(WalletType.values.length),
        reason: 'Trùng biểu tượng cũng vậy — danh sách ví trông như một loại.');
  });
}
