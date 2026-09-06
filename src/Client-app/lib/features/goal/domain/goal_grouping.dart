import '../data/models/goal_entity.dart';

/// Hai nhóm mục tiêu, đúng bằng hai tab trên màn hình.
class NhomMucTieu {
  const NhomMucTieu({required this.dangTheoDuoi, required this.daHoanThanh});

  final List<GoalEntity> dangTheoDuoi;
  final List<GoalEntity> daHoanThanh;
}

/// Chia mục tiêu thành "đang theo đuổi" và "đã hoàn thành", kèm thứ tự.
///
/// ## Vì sao là hàm thuần, không phải logic trong widget
///
/// Phần khó ở đây không phải phần vẽ mà là hai quyết định: **thế nào là xong**
/// và **thứ tự nào**. Cả hai kiểm được bằng dữ liệu, và test cho chúng không
/// cần dựng một cây widget nào — thứ vốn chậm và hay vỡ vì lý do không liên
/// quan.
///
/// ## Thứ tự, và vì sao hai tab ngược nhau
///
/// `goalDao.watchAll` **không có `orderBy` nào**, nên thứ tự trả về là tuỳ
/// SQLite: danh sách có thể xáo lại giữa hai lần mở app mà không ai đụng gì.
///
/// - **Đang theo đuổi** xếp theo hạn **gần nhất trước**: việc gấp nhất lên đầu.
/// - **Đã hoàn thành** xếp **ngược lại**. Đã xong rồi thì "gấp" không còn nghĩa
///   gì; thứ đáng lên đầu là cái vừa đạt được.
///
/// Cả hai dùng `targetDate` chứ không phải một mốc "hoàn thành lúc nào" — cột
/// ấy không tồn tại, và `updatedAt` thì đổi theo mọi lần sửa nên không thay thế
/// được.
NhomMucTieu chiaMucTieu(List<GoalEntity> tatCa) {
  final dangTheoDuoi = <GoalEntity>[];
  final daHoanThanh = <GoalEntity>[];

  for (final g in tatCa) {
    // Nguồn dữ liệu đã lọc hàng xoá mềm, nhưng hàm này phải tự đứng vững: nó
    // là hàm thuần và sẽ được gọi từ test lẫn từ nơi khác về sau.
    if (g.isDeleted) continue;
    (g.daHoanThanh ? daHoanThanh : dangTheoDuoi).add(g);
  }

  dangTheoDuoi.sort((a, b) => a.targetDate.compareTo(b.targetDate));
  daHoanThanh.sort((a, b) => b.targetDate.compareTo(a.targetDate));

  return NhomMucTieu(dangTheoDuoi: dangTheoDuoi, daHoanThanh: daHoanThanh);
}
