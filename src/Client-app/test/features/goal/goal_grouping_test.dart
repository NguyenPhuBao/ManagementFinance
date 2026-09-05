/// Chia mục tiêu thành hai tab "Đang theo đuổi" / "Đã hoàn thành".
///
/// Tách thành hàm thuần để test được mà không dựng widget: phần khó ở đây là
/// **định nghĩa thế nào là xong** và **thứ tự**, cả hai đều kiểm bằng dữ liệu
/// chứ không cần một cây widget nào.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/goal/domain/goal_grouping.dart';

void main() {
  GoalEntity mucTieu({
    required String id,
    double target = 1000000,
    double current = 0,
    bool isCompleted = false,
    bool isDeleted = false,
    DateTime? han,
  }) {
    return GoalEntity(
      id: id,
      idaccount: 1,
      name: id,
      targetAmount: target,
      currentAmount: current,
      targetDate: han ?? DateTime(2027, 1, 1),
      isCompleted: isCompleted,
      isDeleted: isDeleted,
      updatedAt: DateTime(2026, 9, 5),
    );
  }

  group('chiaMucTieu', () {
    test('cờ hoàn thành đưa mục tiêu sang tab đã xong', () {
      final nhom = chiaMucTieu([
        mucTieu(id: 'dang-chay'),
        mucTieu(id: 'xong', isCompleted: true),
      ]);

      expect(nhom.dangTheoDuoi.map((g) => g.id), ['dang-chay']);
      expect(nhom.daHoanThanh.map((g) => g.id), ['xong']);
    });

    test('tích đủ tiền cũng là xong, dù cờ chưa kịp bật', () {
      final nhom = chiaMucTieu([
        mucTieu(id: 'du-tien', target: 1000000, current: 1000000),
      ]);

      expect(nhom.daHoanThanh.map((g) => g.id), ['du-tien'],
          reason: 'Dùng chung định nghĩa với luật thông báo '
              '(`GoalEntity.daHoanThanh`). Chỉ nhìn cờ `isCompleted` thì một '
              'mục tiêu vừa đủ tiền nhưng cờ chưa được ghi xuống sẽ nằm ở tab '
              '"đang theo đuổi" với thanh tiến độ đầy 100% — hai chỗ trên cùng '
              'một màn hình nói ngược nhau.');
    });

    test('mục tiêu đã xoá mềm không xuất hiện ở tab nào', () {
      final nhom = chiaMucTieu([
        mucTieu(id: 'con-song'),
        mucTieu(id: 'da-xoa', isDeleted: true),
        mucTieu(id: 'xoa-va-xong', isCompleted: true, isDeleted: true),
      ]);

      expect(nhom.dangTheoDuoi.map((g) => g.id), ['con-song']);
      expect(nhom.daHoanThanh, isEmpty,
          reason: 'Nguồn dữ liệu (`goalDao.watchAll`) đã lọc `deletedAt`, '
              'nhưng hàm này phải tự đứng vững: nó là hàm thuần và sẽ bị gọi '
              'từ test lẫn từ nơi khác về sau.');
    });

    test('tab đang theo đuổi xếp theo hạn GẦN NHẤT trước', () {
      final nhom = chiaMucTieu([
        mucTieu(id: 'xa', han: DateTime(2027, 12, 1)),
        mucTieu(id: 'gan', han: DateTime(2026, 10, 1)),
        mucTieu(id: 'giua', han: DateTime(2027, 3, 1)),
      ]);

      expect(nhom.dangTheoDuoi.map((g) => g.id), ['gan', 'giua', 'xa'],
          reason: '`goalDao.watchAll` KHÔNG có `orderBy` nào — thứ tự trả về '
              'là tuỳ SQLite. Việc gấp nhất phải nằm trên đầu, nếu không danh '
              'sách sắp xếp ngẫu nhiên mỗi lần mở.');
    });

    test('tab đã hoàn thành xếp NGƯỢC LẠI, mới xong trước', () {
      final nhom = chiaMucTieu([
        mucTieu(id: 'cu', isCompleted: true, han: DateTime(2026, 1, 1)),
        mucTieu(id: 'moi', isCompleted: true, han: DateTime(2026, 8, 1)),
      ]);

      expect(nhom.daHoanThanh.map((g) => g.id), ['moi', 'cu'],
          reason: 'Đã xong rồi thì "gấp" không còn nghĩa gì; thứ đáng lên đầu '
              'là cái vừa đạt được.');
    });

    test('danh sách rỗng thì cả hai tab rỗng, không ném', () {
      final nhom = chiaMucTieu(const []);
      expect(nhom.dangTheoDuoi, isEmpty);
      expect(nhom.daHoanThanh, isEmpty);
    });
  });

  group('GoalEntity.daHoanThanh', () {
    test('mục tiêu 0 đồng tính là xong, khớp với progress', () {
      final g = mucTieu(id: 'khong-dong', target: 0);
      expect(g.progress, 1.0);
      expect(g.daHoanThanh, isTrue,
          reason: 'Mục tiêu 0 đồng làm `progress` trả thẳng 1.0 và màn hình '
              'hiện 100%. Để nó ở tab "đang theo đuổi" là lặp lại đúng lỗi cũ: '
              'thông báo chúc mừng "đã hoàn thành" trong khi màn hình nói khác.');
    });

    test('chưa đủ tiền và chưa có cờ thì chưa xong', () {
      expect(mucTieu(id: 'g', target: 1000000, current: 999999).daHoanThanh,
          isFalse);
    });
  });
}
