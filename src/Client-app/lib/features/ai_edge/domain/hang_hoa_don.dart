/// Tool `danh_sach_hoa_don` — hàng theo TÊN kèm trạng thái và số tiền (spec 4b
/// mục 3.4). Không tính gì: trạng thái từ `billDisplayStatusOf`, tổng hợp từ
/// `summarizeBills`, bộ lọc kỳ chép đúng `GoiSoHoaDon` — hàng và tổng phải nói
/// về **một** tập hoá đơn.
///
/// [ky] (spec mở rộng tool 2026-09-27 §5.1) chọn TẬP hoá đơn; hàng, số đếm và
/// tổng tiền luôn tính trên cùng tập ấy:
/// - `ky_nay` (mặc định): hạn trước đầu tháng sau, kể cả nợ cũ — tập của thẻ tổng.
/// - `ky_toi`: hàng thật có hạn trong tháng dương lịch kế tiếp, CỘNG kỳ **dự
///   kiến** chiếu từ hàng còn phải trả ở cuối chuỗi (`cacKyChieuCua` — đúng luật
///   `payBill` sinh hàng thật, cùng phép với dự báo 30 ngày). ⚠️ Spec viết "chiếu
///   từ hoá đơn đã trả kỳ này"; mã thật thì trả tiền là SINH LUÔN hàng kỳ sau,
///   nên hàng đã trả không còn gì để chiếu — chiếu từ nó là đếm đôi.
/// - `tat_ca`: mọi hàng bất kể tháng — tập của tab *Cần thanh toán*.
///
/// *Cố định mỗi tháng* luôn là của KỲ NÀY (hoá đơn lặp chu kỳ tháng, kể cả đã
/// trả), không theo [ky]: nó trả lời "mỗi tháng tôi gánh bao nhiêu".
library;

import '../../../core/bill/bill_recurrence.dart';
import '../../../core/database/app_database.dart';
import '../../bill/domain/bill_ky_ke_tiep.dart';
import '../../bill/domain/bill_pay_status.dart';
import '../../bill/domain/bill_status.dart';
import 'goi_so.dart';
import 'hang_so_lieu.dart';
import 'loi_tham_so.dart';

const List<String> kTrangThaiHoaDon = ['qua_han', 'chua_tra', 'da_tra', 'tat_ca'];
const String kTrangThaiHoaDonMacDinh = 'chua_tra';

const List<String> kKyHoaDon = ['ky_nay', 'ky_toi', 'tat_ca'];
const String kKyHoaDonMacDinh = 'ky_nay';

/// Chữ kỳ cho mô hình và tiền tố mẫu câu — không chữ số. `ky_nay` không có
/// chữ: kết quả của câu hỏi cũ giữ nguyên từng ký tự.
const Map<String, String> kChuKyHoaDon = {
  'ky_toi': 'kỳ tới',
  'tat_ca': 'mọi kỳ',
};

const String kChuDuKien = 'dự kiến';
const String kHauToTuTra = ' · tự trả';

String chuTrangThaiHoaDon(BillDisplayStatus s) => switch (s) {
      BillDisplayStatus.paid => 'đã trả',
      BillDisplayStatus.skipped => 'bỏ qua',
      BillDisplayStatus.overdue => 'đã quá hạn',
      BillDisplayStatus.dueSoon => 'sắp đến hạn',
      BillDisplayStatus.pending => 'chưa trả',
    };

/// Một phần tử của tập: hàng thật, hoặc kỳ dự kiến (bản sao của hàng gốc mang
/// ba mốc của kỳ chiếu — để `summarizeBills` và `conPhaiTra` đọc nó như mọi hàng).
typedef _Muc = ({Bill b, bool duKien});

List<_Muc> _tapKyToi(List<Bill> bills, DateTime dauKyToi, DateTime dauKySauNua) {
  bool trongKy(DateTime d) => !d.isBefore(dauKyToi) && d.isBefore(dauKySauNua);
  final daSinhKySau = <String>{
    for (final b in bills)
      if (b.generatedFromBillId != null) b.generatedFromBillId!,
  };
  // Ngày cuối của tháng tới (biên đóng của `cacKyChieuCua`).
  final cuoi = DateTime(dauKySauNua.year, dauKySauNua.month, 0);
  return [
    for (final b in bills)
      if (trongKy(b.dueDate)) (b: b, duKien: false),
    for (final b in bills)
      if (!b.isDeleted && conPhaiTra(b) && !daSinhKySau.contains(b.id))
        for (final k in cacKyChieuCua(b, denHetNgay: cuoi))
          if (trongKy(k.hanTra))
            (
              b: b.copyWith(dueDate: k.hanTra),
              duKien: true,
            ),
  ];
}

KetQuaCongCu hangHoaDon(
  List<Bill> bills, {
  required DateTime now,
  String trangThai = kTrangThaiHoaDonMacDinh,
  String ky = kKyHoaDonMacDinh,
}) {
  if (!kTrangThaiHoaDon.contains(trangThai)) {
    return tuChoiGiaTri('trang_thai', trangThai, kTrangThaiHoaDon);
  }
  if (!kKyHoaDon.contains(ky)) {
    return tuChoiGiaTri('ky', ky, kKyHoaDon);
  }

  // Cùng phép chặn cuối tháng với `summarizeBills` và `GoiSoHoaDon.tu`.
  final cuoiKy = DateTime(now.year, now.month + 1, 1);
  final kyNay = [
    for (final b in bills)
      if (b.dueDate.isBefore(cuoiKy)) b,
  ];

  // Tập của [ky] và MỐC đưa cho `summarizeBills` — hàm ấy chặn ở cuối tháng
  // của mốc, nên mốc phải nằm trong tháng của hạn xa nhất trong tập.
  final List<_Muc> tap;
  final DateTime mocTom;
  switch (ky) {
    case 'ky_toi':
      tap = _tapKyToi(bills, cuoiKy, DateTime(now.year, now.month + 2, 1));
      mocTom = cuoiKy;
    case 'tat_ca':
      tap = [for (final b in bills) (b: b, duKien: false)];
      var xa = now;
      for (final b in bills) {
        if (b.dueDate.isAfter(xa)) xa = b.dueDate;
      }
      mocTom = xa;
    default:
      tap = [for (final b in kyNay) (b: b, duKien: false)];
      mocTom = now;
  }
  final tom = summarizeBills([for (final m in tap) m.b], mocTom);

  BillDisplayStatus trangThaiCua(_Muc m) => billDisplayStatusOf(m.b, now);
  var quaHan = 0;
  var tuTra = 0;
  for (final m in tap) {
    if (trangThaiCua(m) == BillDisplayStatus.overdue) quaHan++;
    if (m.b.autoPayEnabled && conPhaiTra(m.b)) tuTra++;
  }

  bool chon(_Muc m) => switch (trangThai) {
        'qua_han' => trangThaiCua(m) == BillDisplayStatus.overdue,
        'chua_tra' => conPhaiTra(m.b),
        'da_tra' => daCoKhoanChi(m.b),
        _ => true,
      };
  // Hạn sớm trước: hoá đơn quá hạn tự đứng đầu — mô hình đọc từ trên xuống.
  final chonRa = [
    for (final m in tap)
      if (chon(m)) m,
  ]..sort((x, y) => x.b.dueDate.compareTo(y.b.dueDate));

  // Hoá đơn lặp THÁNG của kỳ này; `summarizeBills` tự bỏ kỳ đã bỏ qua.
  final coDinh = summarizeBills([
    for (final b in kyNay)
      if (b.isRecurrence && b.timeRecurrence == kBillCycleMonth) b,
  ], now);

  // Ngày đến hạn thêm 2026-09-27 (lần đo 15, câu E8): thiếu nó, "Netflix khi nào
  // đến hạn?" chỉ nhận được "sắp đến hạn" — mô hình không thể nói ngày nó không
  // có. `soNgayThang` để `kiemSo` bóc ngày/tháng và câu nêu "28/09" qua được chắn.
  final hang = [
    for (final m in chonRa.take(kToiDaMucMoiGoi))
      HangSoLieu(
        ten: m.b.name,
        trangThai:
            '${m.duKien ? kChuDuKien : chuTrangThaiHoaDon(trangThaiCua(m))}'
            '${m.b.autoPayEnabled && conPhaiTra(m.b) ? kHauToTuTra : ''}',
        canhBao: trangThaiCua(m) == BillDisplayStatus.overdue,
        soLieu: [
          soTien('Số tiền', m.b.amount, ten: m.b.name),
          soNgayThang('Đến hạn', m.b.dueDate, ten: m.b.name, now: now),
        ],
      ),
  ];
  final chuKy = kChuKyHoaDon[ky];
  return KetQuaCongCu(
    hang: hang,
    tongHop: [
      soTien('Còn phải trả', tom.unpaidAmount),
      soDem('Quá hạn', quaHan),
      soDem('Chưa trả', tom.unpaidCount),
      soDem('Tự trả', tuTra),
      soTien('Cố định mỗi tháng', coDinh.paidAmount + coDinh.unpaidAmount),
    ],
    chuThem: {if (chuKy != null) 'ky': chuKy},
    // Kỳ do câu hỏi chọn mà không hàng nào khớp là báo cáo về bộ lọc — mẫu câu
    // "Kỳ tới — không có hoá đơn nào khớp", không để mô hình tự diễn giải.
    rongTheoBoLoc: chuKy != null && hang.isEmpty,
    doiTuongRong: 'hoá đơn',
  );
}
