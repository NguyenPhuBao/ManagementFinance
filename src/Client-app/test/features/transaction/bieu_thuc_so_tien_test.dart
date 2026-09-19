/// Phép cộng/trừ trên bàn phím Thêm giao dịch — A11 phím `+` `−`, 2026-09-19.
///
/// ## Vì sao có
///
/// Hai phím ấy có trên **cả hai** màn Stitch và vẽ như phím sống, nhưng
/// `themPhimSoTien` trả nguyên chuỗi cho cả hai — nút chết, đúng như `done`
/// từng bị trước nhóm C. ⚠️ Test quét `khong_co_nut_chet_test.dart` **không
/// thấy** chúng: `onTap` trỏ tới `_onKeyPress`, một hàm thật. Chỉ đọc hàm
/// thuần mới lộ ra — bài học là **một nút có thể chết ở tầng dưới nút**.
///
/// Người dùng chốt làm phép tính thật (2026-09-19): gõ `50000 + 30000` rồi ✓
/// thì lưu 80.000 đ. Money Lover và MISA đều có, và nó tiện thật khi chia tiền
/// hay cộng mấy món trong một hoá đơn.
///
/// ## Văn phạm — cố ý hẹp
///
/// Chuỗi giữ **nhiều nhất MỘT phép toán đang chờ**: `"50000"`, `"50000+"`,
/// `"50000+30000"`. Bấm toán tử khi đã đủ hai vế thì **rút gọn trước** rồi mới
/// nối toán tử mới (nếp máy tính bỏ túi) — nhờ vậy không cần bộ phân tích biểu
/// thức nào, và không có thứ tự ưu tiên toán tử để hiểu sai.
///
/// ## Ba chỗ hỏng im lặng
///
/// 1. **Trần số chữ số đếm theo TỪNG VẾ**, không đếm cả chuỗi: `_demChuSo` cũ
///    cộng hết chữ số của cả biểu thức, nên `1+1` đã ăn hai suất và vế sau bị
///    chặn sớm hơn thật 12 chữ số.
/// 2. **Kết quả cũng phải kẹp trần**: hai vế 13 chữ số cộng lại ra **14** chữ
///    số, vượt `numeric(15,2)` — đúng cái bẫy G31/G14/G46, giao dịch kẹt hàng
///    đợi đẩy vĩnh viễn, im lặng.
/// 3. **Hiệu được phép ÂM** và không kẹp về 0: `_saveTransaction` đã có chốt
///    `amount <= 0` báo ra màn hình, còn kẹp ở đây thì `30000-50000` lặng lẽ
///    thành 0 rồi bị chốt kia từ chối với một lời nhắn chẳng ăn nhập.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/utils/gioi_han_do_dai.dart';
import 'package:flowmoney/features/transaction/domain/ban_phim_so_tien.dart';

void main() {
  group('gõ toán tử', () {
    test('nối toán tử vào sau vế đang gõ', () {
      expect(themPhimSoTien('50000', '+'), '50000+');
      expect(themPhimSoTien('50000', '-'), '50000-');
    });

    test('bấm toán tử khác ngay sau đó thì THAY, không nối thêm', () {
      expect(themPhimSoTien('50000+', '-'), '50000-',
          reason: 'Bấm lỡ tay phải sửa được bằng chính phím kia; nối thành '
              '"50000+-" là một chuỗi không đọc được.');
      expect(themPhimSoTien('50000-', '-'), '50000-');
    });

    test('KHÔNG làm gì khi số 0 đang đứng một mình', () {
      expect(themPhimSoTien('0', '+'), '0',
          reason: 'Cùng luật với phím 000: mở đầu bằng "0 +" không có nghĩa.');
    });

    test('gõ tiếp chữ số thì vào vế sau', () {
      expect(themPhimSoTien('50000+', '3'), '50000+3');
      expect(themPhimSoTien('50000+3', '0'), '50000+30');
    });

    test('⚠️ bấm toán tử khi đã đủ hai vế thì RÚT GỌN trước', () {
      expect(themPhimSoTien('50000+30000', '+'), '80000+',
          reason: 'Nếp máy tính bỏ túi. Giữ cả chuỗi là phải viết bộ phân '
              'tích biểu thức và phải định nghĩa thứ tự ưu tiên toán tử — '
              'thừa cho một bàn phím nhập tiền.');
      expect(themPhimSoTien('50000-30000', '-'), '20000-');
    });

    test('xoá lùi gỡ được toán tử', () {
      expect(themPhimSoTien('50000+', 'backspace'), '50000');
      expect(themPhimSoTien('50000+3', 'backspace'), '50000+');
    });
  });

  group('⚠️ trần số chữ số đếm theo TỪNG VẾ', () {
    const day = '1234567890123'; // 13 chữ số

    test('vế sau vẫn gõ được khi vế trước đã đầy', () {
      expect(themPhimSoTien('$day+1', '2'), '$day+12',
          reason: 'Đếm chữ số của cả chuỗi thì vế trước đã ăn hết suất và vế '
              'sau bị chặn ngay chữ số thứ hai — sai 12 chữ số.');
    });

    test('mỗi vế vẫn dừng ở đúng trần của nó', () {
      expect(themPhimSoTien(day, '4'), day);
      expect(themPhimSoTien('1+$day', '4'), '1+$day');
    });

    test('phím 000 cũng kẹp theo vế đang gõ', () {
      expect(themPhimSoTien('1+12345678901', '000'), '1+1234567890100');
      expect(themPhimSoTien('1+12345678901', '000').split('+').last.length,
          kSoChuSoToiDaSoTien);
    });
  });

  group('rút gọn biểu thức', () {
    test('một vế thì trả chính nó', () {
      expect(ketQuaBieuThuc('80000'), 80000);
      expect(ketQuaBieuThuc('0'), 0);
    });

    test('cộng và trừ', () {
      expect(ketQuaBieuThuc('50000+30000'), 80000);
      expect(ketQuaBieuThuc('50000-30000'), 20000);
    });

    test('toán tử lẻ ở cuối thì bỏ qua', () {
      expect(ketQuaBieuThuc('50000+'), 50000,
          reason: 'Người dùng bấm ✓ ngay sau toán tử — hiểu là chưa nhập vế '
              'sau, không phải cộng thêm chính nó.');
    });

    test('⚠️ hiệu ÂM giữ nguyên dấu, không kẹp về 0', () {
      expect(ketQuaBieuThuc('30000-50000'), -20000,
          reason: '`_saveTransaction` đã có chốt `amount <= 0` báo ra màn '
              'hình. Kẹp về 0 ở đây thì lời nhắn ấy chẳng ăn nhập với thứ '
              'người dùng vừa gõ.');
    });

    test('⚠️ tổng cũng phải KẸP TRẦN số chữ số', () {
      const day = '9999999999999'; // 13 chữ số, lớn nhất
      expect(ketQuaBieuThuc('$day+$day'), 9999999999999,
          reason: 'Hai vế 13 chữ số cộng lại ra 14 chữ số, vượt '
              '`numeric(15,2)`. Tràn cho SQLSTATE 22003 → `DB_ERROR` → không '
              'nằm trong danh sách trắng `_permanentCodes` → giao dịch gửi '
              'lại ở MỌI chu kỳ đồng bộ, im lặng. Cùng vòng lặp G31/G14/G46.');
    });

    test('hiệu nhỏ nhất đạt tới được đúng bằng âm trần, không cần kẹp', () {
      // Văn phạm chỉ cho `a-b` với a, b đều không âm và mỗi vế tối đa 13 chữ
      // số, nên hiệu không bao giờ vượt trần ở phía âm — ghi lại để đừng ai
      // thêm một phép kẹp thứ hai chẳng chặn được gì.
      expect(ketQuaBieuThuc('0-9999999999999'), -9999999999999);
    });
  });

  group('phép toán đang chờ', () {
    test('đủ hai vế thì có', () {
      expect(coPhepToanDangCho('50000+30000'), isTrue);
      expect(coPhepToanDangCho('50000-30000'), isTrue);
    });

    test('chưa đủ hai vế thì không', () {
      expect(coPhepToanDangCho('50000+'), isFalse,
          reason: 'Chưa có gì để rút gọn thì đừng hiện dòng "= …" trống nghĩa.');
      expect(coPhepToanDangCho('50000'), isFalse);
      expect(coPhepToanDangCho('0'), isFalse);
    });
  });

  group('có toán tử hay không', () {
    test('phân biệt được cả toán tử LẺ ở cuối', () {
      expect(coToanTu('50000+'), isTrue,
          reason: '`coPhepToanDangCho` trả false cho chuỗi này vì chưa đủ hai '
              'vế, nhưng dòng số vẫn phải hiện dạng biểu thức ("50.000 +") '
              'chứ không phải dạng số tiền ("50.000 đ") — hai câu hỏi khác '
              'nhau, đừng dùng chung một vị từ.');
      expect(coToanTu('50000+30000'), isTrue);
    });

    test('một vế thì không', () {
      expect(coToanTu('50000'), isFalse);
      expect(coToanTu('0'), isFalse);
      expect(coToanTu('12.5'), isFalse,
          reason: 'Chuỗi có phần lẻ từ chế độ sửa không phải biểu thức.');
    });
  });

  group('nhãn hiển thị của biểu thức', () {
    test('mỗi vế ngăn nghìn riêng, toán tử có khoảng trắng hai bên', () {
      expect(nhanBieuThuc('50000+30000'), '50.000 + 30.000');
      expect(nhanBieuThuc('50000-30000'), '50.000 − 30.000');
    });

    test('toán tử lẻ ở cuối vẫn hiện, để thấy mình đang gõ dở', () {
      expect(nhanBieuThuc('50000+'), '50.000 +');
    });

    test('⚠️ dùng dấu trừ THẬT (−) chứ không phải gạch nối', () {
      expect(nhanBieuThuc('50000-30000').contains('−'), isTrue);
      expect(nhanBieuThuc('50000-30000').contains('-'), isFalse,
          reason: 'Phím trên lưới vẽ `−` (U+2212); hiện `-` ở dòng số là hai '
              'ký hiệu cho cùng một phép, và `-` dễ đọc nhầm thành dấu âm.');
    });
  });
}
