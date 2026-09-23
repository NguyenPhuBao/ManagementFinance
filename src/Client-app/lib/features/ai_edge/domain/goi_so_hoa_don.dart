/// Gói số của trang Hoá đơn — nhận xét **kỳ này**, đúng phạm vi mà thẻ tổng
/// đầu trang đang nói tới.
///
/// Mọi con số đến từ `summarizeBills` và `billDisplayStatusOf`; lớp này không
/// tính gì (test quét thứ 14). Riêng phép đếm quá hạn phải lặp lại **cùng hai
/// bộ lọc** của `summarizeBills` — xem chú thích ở [GoiSoHoaDon.tu].
library;

import '../../../core/database/app_database.dart';
import '../../bill/domain/bill_pay_status.dart';
import '../../bill/domain/bill_status.dart';
import 'goi_so.dart';
import 'nhan_xet.dart';

class GoiSoHoaDon extends GoiSo {
  @override
  String get man => 'hoa_don';

  final BillSummary tom;

  /// Số hoá đơn **của kỳ này** đang quá hạn.
  final int quaHan;

  @override
  final List<SoLieu> soLieu;

  GoiSoHoaDon._({
    required this.tom,
    required this.quaHan,
    required this.soLieu,
  });

  factory GoiSoHoaDon.tu(List<Bill> bills, {required DateTime now}) {
    final tom = summarizeBills(bills, now);

    // ⚠️ Phải lọc đúng như `summarizeBills`, nếu không con số quá hạn nói về
    // một tập hoá đơn khác với con số tiền ngay cạnh nó — hai vế của cùng một
    // câu, đếm trên hai tập khác nhau, và không có gì báo.
    //
    // `billDisplayStatusOf` tự trả `skipped` cho kỳ bỏ qua nên vế ấy không cần
    // lặp lại; vế còn phải lặp là **chặn ở cuối tháng** (hoá đơn kỳ sau không
    // thuộc kỳ này).
    final cuoiKy = DateTime(now.year, now.month + 1, 1);
    var quaHan = 0;
    for (final b in bills) {
      if (!b.dueDate.isBefore(cuoiKy)) continue;
      if (billDisplayStatusOf(b, now) == BillDisplayStatus.overdue) quaHan++;
    }

    // Chặng 4a: mỗi hoá đơn còn phải trả góp một mục mang TÊN, để câu hỏi
    // "hoá đơn nào quá hạn" đáp được bằng tên (câu 13 bảng đo, mục 5.6
    // `docs/AI_AGENT_ARCHITECTURE.md` — câu ấy trả lời sang hẳn chủ đề khác).
    //
    // ⚠️ Lặp ĐÚNG phép chặn ở cuối tháng của vòng đếm quá hạn ngay trên: nếu
    // không, danh sách nói về một tập hoá đơn khác với các con số tổng ngay
    // cạnh nó — hai vế của cùng một câu, đếm trên hai tập, và không gì báo.
    //
    // ⚠️ Vị từ "còn phải trả" có MỘT định nghĩa duy nhất ở `bill_pay_status`.
    // Hạn gần nhất trước, nên hoá đơn quá hạn tự đứng đầu.
    final conTra = [
      for (final b in bills)
        if (b.dueDate.isBefore(cuoiKy) && conPhaiTra(b)) b,
    ]..sort((x, y) => x.dueDate.compareTo(y.dueDate));
    // ⚠️ Hoá đơn quá hạn mang nhãn NÓI RÕ là quá hạn, không dùng chung nhãn
    // `Phải trả`. Đo máy thật 2026-09-23: gói nói `Quá hạn: 1` và riêng rẽ
    // `Kiem · Phải trả: 45.000 đ`, **không chỗ nào nói Kiem LÀ cái quá hạn** —
    // mô hình phải nối hai mục bằng suy luận, và E2B trả lời bằng con số tổng
    // thay vì bằng tên. Danh sách có tên là **cần nhưng chưa đủ**: nhãn phải
    // mang chính trạng thái mà câu hỏi hỏi.
    //
    // ⚠️ Nhãn là `Đã quá hạn`, KHÁC `Quá hạn` của mục đếm: mẫu câu tra
    // `s['Quá hạn']` và phải nhận số đếm. `chuoiTheoNhan` lấy mục ĐẦU và mục
    // đếm đứng trước danh sách, nên nhãn khác nhau là lớp chắn thứ hai.
    final theoHoaDon = <SoLieu>[
      for (final b in conTra.take(kToiDaMucMoiGoi))
        soTien(
          billDisplayStatusOf(b, now) == BillDisplayStatus.overdue
              ? 'Đã quá hạn'
              : 'Phải trả',
          b.amount,
          ten: b.name,
        ),
    ];

    // Kỳ không có hoá đơn nào đáng nói: không thẻ số liệu nào, chỉ một câu.
    // Thẻ "Quá hạn: 0" hay "Tiến độ: 0,0%" ở đây là ô trống đội lốt số liệu.
    final rong = tom.unpaidCount == 0 && tom.paidCount == 0;

    return GoiSoHoaDon._(
      tom: tom,
      quaHan: quaHan,
      soLieu: rong
          ? const []
          : [
              soTien('Còn phải trả', tom.unpaidAmount),
              soTien('Đã trả', tom.paidAmount),
              soPhanTram('Tiến độ', tom.progress * 100),
              if (tom.unpaidCount > 0) soDem('Chưa trả', tom.unpaidCount),
              if (quaHan > 0) soDem('Quá hạn', quaHan),
              // Đặt CUỐI: mẫu câu tra mục theo nhãn, các mục tổng hợp ở trên
              // phải gặp trước.
              ...theoHoaDon,
            ],
    );
  }

  @override
  bool get thieuDuLieu => tom.unpaidCount == 0 && tom.paidCount == 0;

  @override
  NhanXet mauCau() {
    if (thieuDuLieu) {
      return const NhanXet(
        cau: 'Kỳ này chưa có hoá đơn nào.',
        theSoLieu: [],
        muc: MucNhanXet.thieuDuLieu,
      );
    }
    final s = chuoiTheoNhan(soLieu);

    // Quá hạn nói trước mọi thứ khác: đó là thứ duy nhất ở đây cần làm ngay.
    if (quaHan > 0) {
      return NhanXet(
        cau: 'Có ${s['Quá hạn']} hoá đơn quá hạn; kỳ này còn phải trả '
            '${s['Còn phải trả']}.',
        theSoLieu: soLieu,
        muc: MucNhanXet.canhBao,
      );
    }

    if (tom.unpaidCount > 0) {
      // Vế "đã trả" chỉ thêm vào khi có tiền đã trả thật — "đã trả 0 đ (0,0%)"
      // làm câu dài ra mà không nói thêm gì.
      final veDaTra = tom.paidAmount > 0
          ? '; đã trả ${s['Đã trả']} (${s['Tiến độ']})'
          : '';
      return NhanXet(
        cau: 'Kỳ này còn ${s['Chưa trả']} hoá đơn chưa trả, tổng '
            '${s['Còn phải trả']}$veDaTra.',
        theSoLieu: soLieu,
        muc: MucNhanXet.binhThuong,
      );
    }

    return NhanXet(
      cau: 'Đã trả xong toàn bộ hoá đơn kỳ này, tổng ${s['Đã trả']}.',
      theSoLieu: soLieu,
      muc: MucNhanXet.binhThuong,
    );
  }
}
