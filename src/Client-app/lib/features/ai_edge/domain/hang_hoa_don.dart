/// Tool `danh_sach_hoa_don` — hàng theo TÊN kèm trạng thái và số tiền (spec 4b
/// mục 3.4). Không tính gì: trạng thái từ `billDisplayStatusOf`, tổng hợp từ
/// `summarizeBills`, bộ lọc kỳ chép đúng `GoiSoHoaDon` — hàng và tổng phải nói
/// về **một** tập hoá đơn.
library;

import '../../../core/database/app_database.dart';
import '../../bill/domain/bill_pay_status.dart';
import '../../bill/domain/bill_status.dart';
import 'goi_so.dart';
import 'hang_so_lieu.dart';

const List<String> kTrangThaiHoaDon = ['qua_han', 'chua_tra', 'da_tra', 'tat_ca'];
const String kTrangThaiHoaDonMacDinh = 'chua_tra';

String chuTrangThaiHoaDon(BillDisplayStatus s) => switch (s) {
      BillDisplayStatus.paid => 'đã trả',
      BillDisplayStatus.skipped => 'bỏ qua',
      BillDisplayStatus.overdue => 'đã quá hạn',
      BillDisplayStatus.dueSoon => 'sắp đến hạn',
      BillDisplayStatus.pending => 'chưa trả',
    };

KetQuaCongCu hangHoaDon(
  List<Bill> bills, {
  required DateTime now,
  String trangThai = kTrangThaiHoaDonMacDinh,
}) {
  if (!kTrangThaiHoaDon.contains(trangThai)) {
    return KetQuaCongCu.loi(
      'trang_thai "$trangThai" không hợp lệ. Chỉ nhận: ${kTrangThaiHoaDon.join(', ')}.',
    );
  }
  final tom = summarizeBills(bills, now);

  // Cùng phép chặn cuối tháng với `summarizeBills` và `GoiSoHoaDon.tu`.
  final cuoiKy = DateTime(now.year, now.month + 1, 1);
  final kyNay = [
    for (final b in bills)
      if (b.dueDate.isBefore(cuoiKy)) b,
  ];
  var quaHan = 0;
  for (final b in kyNay) {
    if (billDisplayStatusOf(b, now) == BillDisplayStatus.overdue) quaHan++;
  }

  bool chon(Bill b) => switch (trangThai) {
        'qua_han' => billDisplayStatusOf(b, now) == BillDisplayStatus.overdue,
        'chua_tra' => conPhaiTra(b),
        'da_tra' => daCoKhoanChi(b),
        _ => true,
      };
  // Hạn sớm trước: hoá đơn quá hạn tự đứng đầu — mô hình đọc từ trên xuống.
  final chonRa = [
    for (final b in kyNay)
      if (chon(b)) b,
  ]..sort((x, y) => x.dueDate.compareTo(y.dueDate));

  final hang = [
    for (final b in chonRa.take(kToiDaMucMoiGoi))
      HangSoLieu(
        ten: b.name,
        trangThai: chuTrangThaiHoaDon(billDisplayStatusOf(b, now)),
        canhBao: billDisplayStatusOf(b, now) == BillDisplayStatus.overdue,
        soLieu: [soTien('Số tiền', b.amount, ten: b.name)],
      ),
  ];
  return KetQuaCongCu(
    hang: hang,
    tongHop: [
      soTien('Còn phải trả', tom.unpaidAmount),
      soDem('Quá hạn', quaHan),
      soDem('Chưa trả', tom.unpaidCount),
    ],
  );
}
