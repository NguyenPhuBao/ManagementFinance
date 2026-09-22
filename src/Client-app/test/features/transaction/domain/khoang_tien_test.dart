import 'package:flowmoney/features/transaction/domain/khoang_tien.dart';
import 'package:flutter_test/flutter_test.dart';

/// Khoảng số tiền của bộ lọc sổ giao dịch — hàm thuần, test bằng `expect`
/// thường.
void main() {
  test('khoảng rỗng chứa mọi số tiền và tự nhận là rỗng', () {
    const kt = KhoangTien();
    expect(kt.rong, isTrue);
    expect(kt.chua(0), isTrue);
    expect(kt.chua(999999999), isTrue);
  });

  test('chỉ có vế "từ" nghĩa là LỚN HƠN, không chặn trên', () {
    const kt = KhoangTien(tu: 500000);
    expect(kt.rong, isFalse);
    expect(kt.chua(499000), isFalse);
    expect(kt.chua(500000), isTrue);
    expect(kt.chua(50000000), isTrue);
  });

  test('chỉ có vế "đến" nghĩa là NHỎ HƠN, không chặn dưới', () {
    const kt = KhoangTien(den: 100000);
    expect(kt.chua(0), isTrue);
    expect(kt.chua(100000), isTrue);
    expect(kt.chua(100001), isFalse);
  });

  test('có cả hai vế là một khoảng đóng ở hai đầu', () {
    const kt = KhoangTien(tu: 100000, den: 500000);
    expect(kt.chua(99000), isFalse);
    expect(kt.chua(100000), isTrue);
    expect(kt.chua(300000), isTrue);
    expect(kt.chua(500000), isTrue);
    expect(kt.chua(500001), isFalse);
  });

  // ⚠️ Bẫy 4 của spec. `amount` là double và khoản ĐIỀU CHỈNH SỐ DƯ mang đuôi
  // lẻ có thật, nên một khoản "đúng 500.000" có thể được máy giữ là
  // 499999.99999994. Không có dung sai thì nó rơi khỏi bộ lọc "từ 500.000" mà
  // không một dòng log nào. Cùng ngưỡng nửa đồng với `dieu_chinh_so_du_service`.
  test('dung sai nửa đồng: đuôi lẻ của double không làm khoản rơi khỏi khoảng',
      () {
    const kt = KhoangTien(tu: 500000, den: 2000000);
    expect(kt.chua(499999.99999994), isTrue,
        reason: 'thiếu dung sai thì khoản đúng bằng biên dưới bị loại, im lặng');
    expect(kt.chua(2000000.0000001), isTrue, reason: 'và biên trên cũng vậy');
  });

  test('dung sai KHÔNG nuốt một khoản lệch thật', () {
    const kt = KhoangTien(tu: 500000);
    expect(kt.chua(499999), isFalse,
        reason: 'lệch một đồng là lệch thật, không phải đuôi lẻ của double');
  });

  test('hopLe false khi người dùng gõ ngược hai ô', () {
    expect(const KhoangTien(tu: 500000, den: 100000).hopLe, isFalse);
    expect(const KhoangTien(tu: 100000, den: 500000).hopLe, isTrue);
    expect(const KhoangTien(tu: 100000).hopLe, isTrue);
    expect(const KhoangTien(den: 100000).hopLe, isTrue);
    expect(const KhoangTien().hopLe, isTrue);
  });

  test('hai khoảng cùng giá trị thì bằng nhau', () {
    expect(const KhoangTien(tu: 1, den: 2), const KhoangTien(tu: 1, den: 2));
    expect(const KhoangTien(tu: 1), isNot(const KhoangTien(tu: 2)));
  });

  group('nhãn chip', () {
    test('rỗng hoặc null thì là tên chip trần', () {
      expect(nhanKhoangTien(null), 'Số tiền');
      expect(nhanKhoangTien(const KhoangTien()), 'Số tiền');
    });

    test('một vế thì nói rõ chiều', () {
      expect(nhanKhoangTien(const KhoangTien(tu: 500000)), 'Từ 500.000 đ');
      expect(nhanKhoangTien(const KhoangTien(den: 500000)), 'Đến 500.000 đ');
    });

    test('hai vế thì là một khoảng, ký hiệu tiền chỉ hiện MỘT lần ở cuối', () {
      expect(nhanKhoangTien(const KhoangTien(tu: 100000, den: 500000)),
          '100.000 – 500.000 đ');
    });
  });
}
