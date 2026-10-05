/// C6 (đường nhanh, người dùng chọn 2026-10-05: *"Gemma viết + lưới kiểm đủ dòng"*) — câu hỏi muốn KỂ TÊN các khoản
/// thì câu Gemma viết phải nêu tên MỌI hàng tool trả; thiếu thì màn hiện mẫu câu đủ dòng. Đo Realme 2026-10-04: C6
/// *"tháng trước tôi có khoản chi nào trên 1 triệu không"* — sổ trả 2 khoản, Gemma kể 1, mọi lớp chắn im vì câu không
/// sai số nào.
library;

import 'package:flowmoney/features/ai_edge/domain/ke_du_ten.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cauHoiKeTen — câu hỏi muốn kể tên các khoản', () {
    test('⭐ C6 và họ hàng: "khoản … nào", "giao dịch nào", "những / các khoản", "liệt kê", "N khoản"', () {
      for (final c in [
        'thang truoc toi co khoan chi nao tren 1 trieu khong',
        'Tháng trước tôi có khoản chi nào trên 1 triệu không?',
        'tuan nay co giao dich nao o vi tien mat',
        'nhung khoan an uong thang nay',
        'cac giao dich tren 500k',
        'liet ke khoan thu thang 9',
        '3 khoan chi gan day',
        'lan nao toi tra tien nha',
      ]) {
        expect(cauHoiKeTen(c), isTrue, reason: c);
      }
    });

    test('câu hỏi TỔNG / ĐẾM / một đối tượng thì không', () {
      for (final c in [
        'thang nay toi chi bao nhieu',
        'bao nhieu khoan chi thang nay',
        'danh muc nao chi nhieu nhat',
      ]) {
        expect(cauHoiKeTen(c), isFalse, reason: c);
      }
    });
  });

  group('tenChuaNeu — tên hàng câu trả lời chưa nêu', () {
    test('⭐ C6: câu kể một trong hai khoản → còn thiếu đúng khoản kia', () {
      expect(
        tenChuaNeu('Có khoản chi: Tien nha T9 với Số tiền: 3.000.000 đ.', ['Tien nha T9', 'An toi lien hoan']),
        ['An toi lien hoan'],
      );
    });

    test('so bỏ dấu, không phân biệt hoa thường, gom khoảng trắng: "Tiền nhà t9" nêu đúng "Tien nha T9"', () {
      expect(tenChuaNeu('Bạn có Tiền nhà  t9 và Ăn tối liên hoan.', ['Tien nha T9', 'An toi lien hoan']), isEmpty);
    });

    test('khớp TRỌN từ: tên "Gra" không được coi là đã nêu nhờ chữ "Grab"', () {
      expect(tenChuaNeu('Khoản Grab 50.000 đ.', ['Gra']), ['Gra'], reason: '"Gra" không phải một từ trong câu');
      expect(tenChuaNeu('Khoản Grab 50.000 đ.', ['Grab']), isEmpty);
    });

    test('tên trùng nhau chỉ xét một lần; danh sách tên rỗng → không thiếu gì', () {
      expect(tenChuaNeu('Ăn trưa 50.000 đ.', ['Ăn trưa', 'Ăn trưa']), isEmpty);
      expect(tenChuaNeu('bất kỳ', const []), isEmpty);
    });
  });
}
