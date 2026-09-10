import '../data/models/goal_entity.dart';

/// Khoảng cách giữa hai giá trị `priority` liền nhau.
///
/// **Vì sao thưa chứ không phải 1, 2, 3:** chèn một mục tiêu vào giữa mà đánh
/// số liên tục thì phải ghi lại **cả danh sách**, tức một thao tác kéo thả
/// sinh ra *n* bản ghi `pending` cùng lúc. Với khe này, chèn giữa hai hàng chỉ
/// ghi **một** hàng.
///
/// Quy ước chốt từ 2026-09-05 ở
/// `docs/superpowers/backend/DA-XONG/2026-09-05-backend-goal-priority.md`
/// mục 4. Đừng đổi con số mà không đọc mục ấy.
const int buocUuTien = 100;

/// Đổi `newIndex` của `ReorderableListView.onReorder` thành vị trí **thật**.
///
/// Flutter trả `newIndex` tính trên danh sách **còn nguyên** phần tử đang kéo,
/// nên khi kéo **xuống** con số ấy lớn hơn vị trí cuối cùng đúng một đơn vị.
/// Dùng thẳng nó thì mục tiêu rơi lệch một ô — không ném, không log, chỉ là
/// thứ tự khác chỗ người dùng vừa thả tay.
///
/// Kéo **lên** thì không phải trừ: phần tử đang kéo nằm sau vị trí đích nên gỡ
/// nó ra không làm đích dịch đi.
int viTriThaThucTe({required int cu, required int moi}) =>
    moi > cu ? moi - 1 : moi;

/// Giá trị `priority` mới cho từng mục tiêu sau một lần kéo thả.
///
/// Khoá là id mục tiêu. Trả về **map rỗng** nghĩa là không có gì để ghi.
///
/// [dangHien] là danh sách **đang hiển thị**, theo đúng thứ tự trên màn hình
/// trước khi kéo — tức là đã đi qua `chiaMucTieu`. Hàm này không tự sắp lại:
/// nó tin vào thứ tự nó nhận được, vì đó chính là thứ người dùng đang nhìn khi
/// họ thả tay.
///
/// ## Hai chế độ, và vì sao cần cả hai
///
/// | Khi nào | Ghi mấy hàng |
/// |---|---|
/// | Mọi hàng đã có số **phân biệt** và chỗ thả còn khe | **một** |
/// | Còn hàng `null`, có số trùng nhau, hoặc hết khe | **cả danh sách** |
///
/// Lần kéo đầu tiên luôn rơi vào chế độ thứ hai vì mọi hàng đang mang `null`.
/// Đó là *một* lần ghi *n* hàng trong đời danh sách, không phải mỗi lần kéo —
/// từ lần sau mọi hàng đã có số thưa nên chỉ một hàng phải ghi.
///
/// ## Vì sao đánh số lại thay vì ép một giá trị vào chỗ chật
///
/// Giữa 100 và 101 không còn số nguyên nào. Ép đại một giá trị vào đó là hai
/// hàng trùng số, và khi ấy thứ tự rơi về `targetDate` — tức thao tác kéo thả
/// người dùng vừa làm **biến mất ở lần mở app sau**, không có lỗi, không có
/// dấu hiệu gì.
Map<String, int> uuTienSauKhiKeo({
  required List<GoalEntity> dangHien,
  required int tuViTri,
  required int toiViTri,
}) {
  if (dangHien.length < 2) return const {};

  // Vị trí ngoài dải thì bỏ qua thay vì ném. Hàm này chạy từ callback của
  // `ReorderableListView`; ném ở đó là màn đỏ ngay giữa một thao tác kéo thả,
  // còn bỏ qua thì tệ nhất là thứ tự không đổi.
  if (tuViTri < 0 || tuViTri >= dangHien.length) return const {};
  if (toiViTri < 0 || toiViTri >= dangHien.length) return const {};
  if (tuViTri == toiViTri) return const {};

  final sauKhiKeo = [...dangHien];
  sauKhiKeo.insert(toiViTri, sauKhiKeo.removeAt(tuViTri));

  final moc = _mocChenDuoc(sauKhiKeo, toiViTri);
  if (moc != null) return {sauKhiKeo[toiViTri].id: moc};

  return {
    for (var i = 0; i < sauKhiKeo.length; i++)
      sauKhiKeo[i].id: (i + 1) * buocUuTien,
  };
}

/// Giá trị chèn được vào [viTri] của danh sách **đã sắp lại**, hoặc `null` nếu
/// phải đánh số lại cả danh sách.
int? _mocChenDuoc(List<GoalEntity> ds, int viTri) {
  // Một hàng `null` ở bất cứ đâu là bỏ chế độ ghi-một-hàng. Không suy ra được
  // hàng ấy đứng trước hay sau một số cụ thể, nên chen một giá trị vào cạnh nó
  // cho ra một thứ tự không xác định.
  final so = <int>[];
  for (final g in ds) {
    final p = g.priority;
    if (p == null) return null;
    so.add(p);
  }

  // Số trùng nhau cũng vậy: khe tính từ hai giá trị bằng nhau là khe rỗng.
  if (so.toSet().length != so.length) return null;

  final truoc = viTri == 0 ? null : so[viTri - 1];
  final sau = viTri == ds.length - 1 ? null : so[viTri + 1];

  // Thả xuống cuối: nối tiếp hàng cuối. Đây là nhánh duy nhất không có trần.
  if (sau == null) return truoc! + buocUuTien;

  // Thả lên đầu: lùi xuống dưới hàng đầu, nhưng phải còn chỗ. `priority` luôn
  // **dương** — 0 và số âm đi qua đường đồng bộ thì không phân biệt được với
  // "chưa sắp", và một mục tiêu đã sắp mà bị đọc thành chưa sắp sẽ nhảy xuống
  // cuối danh sách.
  if (truoc == null) {
    final moi = sau - buocUuTien;
    return moi > 0 ? moi : (sau > 1 ? sau ~/ 2 : null);
  }

  // Chèn giữa: điểm giữa hai hàng kề. Cần chênh ít nhất 2 mới có số nguyên
  // nằm hẳn ở giữa.
  if (sau - truoc < 2) return null;
  return truoc + (sau - truoc) ~/ 2;
}
