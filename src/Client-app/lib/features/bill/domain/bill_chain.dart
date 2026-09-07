import '../../../core/database/app_database.dart';

/// Chuỗi kỳ chứa hoá đơn [id], **kỳ mới nhất đứng đầu**.
///
/// Mỗi kỳ của hoá đơn lặp là một hàng mới, nối với kỳ trước bằng
/// `generatedFromBillId` (cột **cục bộ** v16 — hàng kéo về từ server để trống,
/// nên chuỗi của chúng chỉ có một phần tử; đừng đoán theo tên). Lần ngược về
/// gốc rồi xuôi tới kỳ mới nhất. Dữ liệu hỏng thành vòng thì dừng ở chỗ gặp
/// lại, không lặp vô hạn.
List<Bill> chuoiKyCua(List<Bill> all, String id) {
  final theoId = {for (final b in all) b.id: b};
  final goc = theoId[id];
  if (goc == null) return const [];

  final daTham = <String>{id};

  // Ngược về gốc.
  final truoc = <Bill>[];
  var hienTai = goc;
  while (hienTai.generatedFromBillId != null) {
    final cha = theoId[hienTai.generatedFromBillId!];
    if (cha == null || !daTham.add(cha.id)) break;
    truoc.add(cha);
    hienTai = cha;
  }

  // Xuôi tới kỳ mới nhất. Một kỳ chỉ sinh đúng một kỳ sau; có hai (dữ liệu
  // hỏng) thì lấy cái chưa xoá đầu tiên.
  final sinhTu = <String, Bill>{};
  for (final b in all) {
    final tu = b.generatedFromBillId;
    if (tu != null) sinhTu.putIfAbsent(tu, () => b);
  }
  final sau = <Bill>[];
  hienTai = goc;
  while (true) {
    final con = sinhTu[hienTai.id];
    if (con == null || !daTham.add(con.id)) break;
    sau.add(con);
    hienTai = con;
  }

  return [...sau.reversed, goc, ...truoc];
}
