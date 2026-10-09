import '../../../core/database/app_database.dart';

/// Các kỳ TRƯỚC của [bill] theo `generatedFromBillId`, gần nhất đứng đầu — định nghĩa duy nhất của phép lần ngược
/// chuỗi kỳ (dùng ở [chuoiKyCua] và phép gộp kỳ trùng `kyTrungCanGo`). Dừng khi cha không có trong [theoId] hoặc gặp
/// lại một kỳ đã đi qua (dữ liệu hỏng thành vòng), không lặp vô hạn.
List<Bill> kyTruocCua(Bill bill, Map<String, Bill> theoId) {
  final daTham = <String>{bill.id};
  final truoc = <Bill>[];
  var hienTai = bill;
  while (hienTai.generatedFromBillId != null) {
    final cha = theoId[hienTai.generatedFromBillId!];
    if (cha == null || !daTham.add(cha.id)) break;
    truoc.add(cha);
    hienTai = cha;
  }
  return truoc;
}

/// Chuỗi kỳ chứa hoá đơn [id], **kỳ mới nhất đứng đầu**.
///
/// Mỗi kỳ của hoá đơn lặp là một hàng mới, nối với kỳ trước bằng
/// `generatedFromBillId` (khoá đồng bộ `previous_bill_id` từ 2026-09-12; hàng
/// cũ hơn trên server còn để trống nên chuỗi của chúng có thể chỉ một phần tử —
/// đừng đoán theo tên). Lần ngược về gốc rồi xuôi tới kỳ mới nhất.
List<Bill> chuoiKyCua(List<Bill> all, String id) {
  final theoId = {for (final b in all) b.id: b};
  final goc = theoId[id];
  if (goc == null) return const [];

  final truoc = kyTruocCua(goc, theoId);
  final daTham = <String>{id, ...truoc.map((b) => b.id)};

  // Xuôi tới kỳ mới nhất. Bình thường một kỳ sinh đúng một kỳ sau; có hai
  // (kỳ trùng — G87, xảy ra thật khi hai máy cùng tự trả) thì lấy cái đầu tiên.
  final sinhTu = <String, Bill>{};
  for (final b in all) {
    final tu = b.generatedFromBillId;
    if (tu != null) sinhTu.putIfAbsent(tu, () => b);
  }
  final sau = <Bill>[];
  var hienTai = goc;
  while (true) {
    final con = sinhTu[hienTai.id];
    if (con == null || !daTham.add(con.id)) break;
    sau.add(con);
    hienTai = con;
  }

  return [...sau.reversed, goc, ...truoc];
}
