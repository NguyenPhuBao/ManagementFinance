/// Kỳ hoá đơn **trùng** — cùng chuỗi, cùng ngày hạn, nhiều hàng sống (G87, 2026-10-09).
///
/// Mỗi kỳ của hoá đơn lặp là một hàng, sinh ra lúc trả kỳ trước (`generatedFromBillId`). Hai máy cùng trả một kỳ
/// thì mỗi máy sinh một kỳ kế tiếp. Máy thua cuộc đua `BILL_ALREADY_PAID` có xoá kỳ con của mình, nhưng kỳ ấy đã
/// lên server **trước** (hoá đơn đẩy trước giao dịch vì khoá ngoại) và bước Pull ngay sau trong **cùng chu kỳ** ghi
/// đè lệnh xoá cục bộ bằng bản sống của server (`billDao.upsertAll` không xét hàng đang chờ đẩy) — kỳ trùng sống
/// lại. Đo trên PostgreSQL dev (tài khoản 10, Netflix tự trả): ba kỳ 05/10, bộ tự trả của máy khác trả cả ba (trừ
/// tiền 3 lần, chốt `chanTraHaiLan` của server chỉ chặn trả hai lần CÙNG một `Idbill`), rồi năm kỳ 12/10 dưới ba cha.
///
/// Không đổi luật Pull cho mọi bảng (thay kiến trúc LWW): lỗ ấy đóng bằng phép **gộp sau mỗi lượt quét** ở đây —
/// lệnh xoá bị Pull nuốt thì lượt quét kế tiếp xoá lại theo cùng luật.
///
/// Hàm thuần, không Drift truy vấn, không đồng hồ.
library;

import '../../../core/database/app_database.dart';
import 'bill_chain.dart';
import 'bill_pay_status.dart';

bool _song(Bill b) => !b.isDeleted && b.deletedAt == null;

/// Gốc chuỗi của [bill]: đi ngược `generatedFromBillId` qua [theoId] — gồm cả hàng **đã xoá** (cha của một kỳ có
/// thể đã bị gỡ). Cha chưa có trên máy thì id cha ấy là gốc; lượt Pull sau sẽ mang nó về và mọi máy hội tụ.
String _gocCua(Bill bill, Map<String, Bill> theoId) {
  final truoc = kyTruocCua(bill, theoId);
  final dinh = truoc.isEmpty ? bill : truoc.last;
  // Đỉnh còn trỏ tới một cha không có trên máy → id cha ấy là gốc (khác `chuoiKyCua`, nơi đỉnh là kỳ cuối nhìn thấy):
  // hai kỳ anh em mà cha chưa kéo về vẫn phải rơi vào cùng một nhóm.
  final cha = dinh.generatedFromBillId;
  return (cha != null && !theoId.containsKey(cha)) ? cha : dinh.id;
}

/// Khoá gộp: gốc chuỗi + ngày hạn (so theo NGÀY — cùng quy ước `markOverdue`). Gộp theo **cha** là sai: năm kỳ
/// 12/10 của Netflix nằm dưới ba cha khác nhau (chính các kỳ trùng 05/10).
String _khoa(Bill bill, Map<String, Bill> theoId) {
  final d = bill.dueDate;
  return '${_gocCua(bill, theoId)}|${d.year}-${d.month}-${d.day}';
}

Map<String, List<Bill>> _nhomSong(Iterable<Bill> tatCa) {
  final theoId = {for (final b in tatCa) b.id: b};
  final nhom = <String, List<Bill>>{};
  for (final b in tatCa) {
    if (!_song(b)) continue;
    nhom.putIfAbsent(_khoa(b, theoId), () => []).add(b);
  }
  return nhom;
}

/// Id các kỳ trùng phải **xoá mềm**. [tatCa] là mọi hàng hoá đơn của tài khoản, **kể cả hàng đã xoá** (để lần gốc).
///
/// Luật trong mỗi nhóm (cùng gốc, cùng ngày hạn, các hàng sống):
/// - Có kỳ **đã đóng** (đã trả / bỏ qua — `conPhaiTra` sai) → gỡ mọi kỳ **còn phải trả**. Kỳ đã đóng KHÔNG BAO GIỜ
///   bị gỡ: xoá kỳ đã trả là mất khoản chi khỏi lịch sử mà không hoàn tiền; trả thừa thì người dùng tự Hoàn tác, kỳ
///   ấy về còn phải trả và lượt sau gỡ nó.
/// - Chưa kỳ nào đóng → giữ id **nhỏ nhất**, gỡ phần còn lại.
///
/// ⚠️ Vì sao các máy hội tụ mà không cần biết nhau: máy thấy tập con S của nhóm chỉ gỡ những hàng ≠ min(S), nên
/// min **toàn cục** không bao giờ bị máy nào gỡ. Giới hạn: sửa tay (số tiền, ghi chú) trên một kỳ trùng bị gỡ thì mất.
Set<String> kyTrungCanGo(Iterable<Bill> tatCa) {
  final go = <String>{};
  for (final nhom in _nhomSong(tatCa).values) {
    if (nhom.length < 2) continue;
    final conPhai = nhom.where(conPhaiTra).toList();
    if (conPhai.length < nhom.length) {
      go.addAll(conPhai.map((b) => b.id));
    } else {
      final giu = conPhai.map((b) => b.id).reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
      go.addAll(conPhai.map((b) => b.id).where((id) => id != giu));
    }
  }
  return go;
}

/// Kỳ [bill] có một kỳ trùng (cùng gốc, cùng ngày hạn) **đã đóng** không — chốt của `payBill`: trả nó là trừ tiền
/// lần thứ hai cho cùng một kỳ mà server không chặn được (khác `Idbill`).
bool kyCungKyDaDong(Bill bill, Iterable<Bill> tatCa) {
  final theoId = {for (final b in tatCa) b.id: b};
  final khoa = _khoa(bill, theoId);
  return tatCa.any((b) => b.id != bill.id && _song(b) && !conPhaiTra(b) && _khoa(b, theoId) == khoa);
}
