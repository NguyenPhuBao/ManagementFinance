/// Hàm thuần của form chế độ nhà (gia đình 1B, Task 3; ruling I-4).
library;

import 'package:flowmoney/features/transaction/presentation/state/che_do_nha_form.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('huongFormNha', () {
    const bang = <(String?, bool, String?)>[
      ('transfer', false, null),
      ('transfer', true, 'transfer'),
      ('thu', false, 'thu'),
      ('chi', false, 'chi'),
      (null, false, null),
      (null, true, null),
    ];
    for (final (huong, choChuyen, mong) in bang) {
      test('huong=$huong choChuyen=$choChuyen → $mong', () {
        expect(huongFormNha(huong, choChuyen: choChuyen), mong,
            reason: 'Thành viên mở ?huong=transfer thì form ở Chi tiêu: khoản chuyển bị server từ chối rồi biến mất im lặng (G120 #7)');
      });
    }
  });

  group('tieuDeFormNha', () {
    test('sửa thắng chiều', () => expect(tieuDeFormNha(true, 'thu'), 'Sửa khoản của nhà'));
    test('chi', () => expect(tieuDeFormNha(false, 'chi'), 'Khoản chi của nhà'));
    test('thu', () => expect(tieuDeFormNha(false, 'thu'), 'Khoản thu của nhà'));
    test('transfer', () => expect(tieuDeFormNha(false, 'transfer'), 'Chuyển giữa ví chung'));
    test('chiều lạ rơi về chi', () => expect(tieuDeFormNha(false, 'zzz'), 'Khoản chi của nhà'));
  });
}
