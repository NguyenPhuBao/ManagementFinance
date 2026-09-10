/// Thứ tự ưu tiên do người dùng kéo thả.
///
/// Quy ước giá trị **không** được đặt ra ở đây — nó chốt sẵn từ 2026-09-05 ở
/// `docs/superpowers/backend/DA-XONG/2026-09-05-backend-goal-priority.md`
/// mục 4, và backend đã thêm cột `Priority Int?` ngày 2026-09-07:
///
/// - số **cách nhau 100** (100, 200, 300…), số nhỏ đứng trước;
/// - `NULL` xếp **cuối**, không phải đầu;
/// - trùng số là **chấp nhận được**, sắp tiếp theo `targetDate`.
///
/// Vì sao thưa chứ không phải 1, 2, 3: chèn một mục tiêu vào giữa mà đánh số
/// liên tục thì phải ghi lại **cả danh sách**, tức một thao tác kéo thả sinh ra
/// *n* bản ghi `pending` cùng lúc. Với khe 100, chèn giữa hai hàng chỉ ghi
/// **một** hàng.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/goal/domain/goal_priority.dart';

void main() {
  GoalEntity mt(String id, {int? uuTien}) => GoalEntity(
        id: id,
        idaccount: 1,
        name: id,
        targetAmount: 1000000,
        targetDate: DateTime(2027, 1, 1),
        priority: uuTien,
        updatedAt: DateTime(2026, 9, 8),
      );

  group('viTriThaThucTe', () {
    test('kéo XUỐNG thì trừ một, vì Flutter đếm trước khi gỡ', () {
      expect(viTriThaThucTe(cu: 0, moi: 3), 2,
          reason: '`ReorderableListView.onReorder` trả `newIndex` tính trên '
              'danh sách CÒN NGUYÊN phần tử đang kéo. Dùng thẳng con số ấy '
              'thì mục tiêu rơi lệch một ô — không ném, không log, chỉ là thứ '
              'tự sai đi một bậc so với chỗ người dùng vừa thả tay.');
    });

    test('kéo LÊN thì giữ nguyên', () {
      expect(viTriThaThucTe(cu: 3, moi: 1), 1,
          reason: 'Kéo lên thì phần tử đang kéo nằm SAU vị trí đích, nên việc '
              'gỡ nó ra không làm đích dịch đi. Trừ một ở cả hai chiều là lỗi '
              'đối xứng của việc không trừ gì.');
    });

    test('thả lại đúng chỗ cũ ra chính nó', () {
      expect(viTriThaThucTe(cu: 2, moi: 2), 2);
      expect(viTriThaThucTe(cu: 2, moi: 3), 2,
          reason: 'Thả ngay dưới chính mình cũng là không đổi gì.');
    });
  });

  group('uuTienSauKhiKeo', () {
    test('lần kéo đầu tiên đánh số lại cả danh sách, cách nhau 100', () {
      final ra = uuTienSauKhiKeo(
        dangHien: [mt('a'), mt('b'), mt('c')],
        tuViTri: 2,
        toiViTri: 0,
      );

      expect(ra, {'c': 100, 'a': 200, 'b': 300},
          reason: 'Mọi mục tiêu đang mang `null` thì không có khe nào để chèn '
              'vào. Đây là lần DUY NHẤT phải ghi cả danh sách; từ lần sau mọi '
              'hàng đã có số thưa nên chỉ một hàng phải ghi.');
    });

    test('chèn vào giữa hai hàng còn khe thì chỉ ghi MỘT hàng', () {
      final ra = uuTienSauKhiKeo(
        dangHien: [
          mt('a', uuTien: 100),
          mt('b', uuTien: 200),
          mt('c', uuTien: 300),
        ],
        tuViTri: 2,
        toiViTri: 1,
      );

      expect(ra.length, 1,
          reason: 'Đây là lý do tồn tại của khe 100. Ghi cả danh sách ở mỗi lần '
              'kéo là *n* bản ghi pending cho một thao tác.');
      expect(ra['c'], 150);
    });

    test('kéo lên đầu thì lấy số nhỏ hơn hàng đầu', () {
      final ra = uuTienSauKhiKeo(
        dangHien: [
          mt('a', uuTien: 200),
          mt('b', uuTien: 300),
          mt('c', uuTien: 400),
        ],
        tuViTri: 2,
        toiViTri: 0,
      );

      expect(ra, {'c': 100});
    });

    test('kéo xuống cuối thì lấy số lớn hơn hàng cuối', () {
      final ra = uuTienSauKhiKeo(
        dangHien: [
          mt('a', uuTien: 100),
          mt('b', uuTien: 200),
          mt('c', uuTien: 300),
        ],
        tuViTri: 0,
        toiViTri: 2,
      );

      expect(ra, {'a': 400});
    });

    test('hết khe giữa hai hàng thì đánh số lại cả danh sách', () {
      final ra = uuTienSauKhiKeo(
        dangHien: [
          mt('a', uuTien: 100),
          mt('b', uuTien: 101),
          mt('c', uuTien: 300),
        ],
        tuViTri: 2,
        toiViTri: 1,
      );

      expect(ra, {'a': 100, 'c': 200, 'b': 300},
          reason: 'Giữa 100 và 101 không còn số nguyên nào. Ép một giá trị vào '
              'đó là hai hàng trùng số, và thứ tự người dùng vừa kéo biến mất '
              'ngay ở lần mở app sau — im lặng.');
    });

    test('kéo lên đầu mà hàng đầu đã là 1 thì đánh số lại cả danh sách', () {
      final ra = uuTienSauKhiKeo(
        dangHien: [mt('a', uuTien: 1), mt('b', uuTien: 200)],
        tuViTri: 1,
        toiViTri: 0,
      );

      expect(ra, {'b': 100, 'a': 200},
          reason: 'Không còn số nguyên dương nào nhỏ hơn 1. Ưu tiên phải luôn '
              'dương: 0 và số âm đi qua đường đồng bộ thì không phân biệt được '
              'với "chưa sắp".');
    });

    test('thả lại đúng chỗ cũ thì không ghi gì', () {
      final ra = uuTienSauKhiKeo(
        dangHien: [mt('a', uuTien: 100), mt('b', uuTien: 200)],
        tuViTri: 1,
        toiViTri: 1,
      );

      expect(ra, isEmpty,
          reason: 'Ghi một bản ghi pending cho một thao tác không đổi gì là '
              'đẩy rác lên server.');
    });

    test('hàng chưa có số nằm lẫn hàng đã có số thì đánh số lại cả danh sách',
        () {
      final ra = uuTienSauKhiKeo(
        dangHien: [mt('a', uuTien: 100), mt('b'), mt('c', uuTien: 300)],
        tuViTri: 2,
        toiViTri: 0,
      );

      expect(ra, {'c': 100, 'a': 200, 'b': 300},
          reason: 'Mục tiêu tạo sau lần sắp gần nhất mang `null`. Chen một số '
              'vào cạnh nó thì không suy ra được nó đứng trước hay sau — chỉ '
              'đánh số lại mới cho một thứ tự xác định.');
    });

    test('danh sách một phần tử thì không ghi gì', () {
      expect(
        uuTienSauKhiKeo(dangHien: [mt('a')], tuViTri: 0, toiViTri: 0),
        isEmpty,
      );
    });

    test('vị trí ngoài dải thì không ghi gì thay vì ném', () {
      final ds = [mt('a', uuTien: 100), mt('b', uuTien: 200)];

      expect(uuTienSauKhiKeo(dangHien: ds, tuViTri: 5, toiViTri: 0), isEmpty);
      expect(uuTienSauKhiKeo(dangHien: ds, tuViTri: 0, toiViTri: -1), isEmpty);
      expect(uuTienSauKhiKeo(dangHien: ds, tuViTri: 0, toiViTri: 9), isEmpty,
          reason: 'Hàm này chạy từ callback của ReorderableListView. Ném ở đó '
              'là màn đỏ giữa một thao tác kéo thả, còn bỏ qua thì tệ nhất là '
              'thứ tự không đổi.');
    });

    test('mọi giá trị sinh ra đều dương và không trùng nhau', () {
      final ra = uuTienSauKhiKeo(
        dangHien: [mt('a'), mt('b'), mt('c'), mt('d')],
        tuViTri: 3,
        toiViTri: 1,
      );

      expect(ra.values.every((v) => v > 0), isTrue);
      expect(ra.values.toSet().length, ra.length,
          reason: 'Trùng số thì thứ tự rơi về `targetDate` — tức là thao tác '
              'kéo thả vừa rồi không có tác dụng.');
    });
  });
}
