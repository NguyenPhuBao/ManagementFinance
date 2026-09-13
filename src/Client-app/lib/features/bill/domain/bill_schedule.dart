import 'package:intl/intl.dart';
import '../../../core/bill/bill_recurrence.dart';
import '../../../core/database/app_database.dart';
import 'bill_an_han.dart';

/// Lịch của một hoá đơn.
///
/// **Hoá đơn luôn có một chu kỳ** — khác màn ngân sách, nơi còn lựa chọn "Ngày
/// cụ thể" để tự nhập ngày kết thúc. Quyết định 2026-09-04: hoá đơn không cần
/// đường thoát đó, nên ngày kết thúc kỳ [ketThucKy] **luôn** suy ra từ
/// [startDate] + chu kỳ và ô ấy trên form là chỉ đọc.
///
/// Từ v21 (2026-09-12) hạn trả tách khỏi ngày kết thúc kỳ: [dueDate] =
/// [ketThucKy] + [anHanNgay]. Ân hạn 0 (mặc định) cho kết quả y hệt trước đó.
/// Xem `bill_an_han.dart` và spec
/// `docs/superpowers/specs/2026-09-12-bill-an-han-period-end-design.md`.
///
/// Còn lại đúng một công tắc, [repeat]: thanh toán xong có sinh kỳ mới không.
/// Nó độc lập với chu kỳ, nên trạng thái *"hạn trả tính theo chu kỳ tháng
/// nhưng chỉ chạy một kỳ"* vẫn diễn đạt được.
class BillSchedule {
  final DateTime startDate;

  /// Một trong `kBillCycle*`. Không bao giờ null.
  final String timeRecurrence;

  final bool repeat;

  /// Ngày trong tháng mà người dùng thật sự chọn — xem `Bills.anchorDay`.
  ///
  /// `null` nghĩa là *chưa biết*, và khi ấy ngày của [startDate] đóng vai trò
  /// ấy. Hai thứ này chỉ khác nhau ở **hoá đơn thuộc chuỗi**: kỳ thứ ba của một
  /// chuỗi bắt đầu ngày 31 có [startDate] 28/02 nhưng ngày gốc vẫn là 31.
  final int? anchorDay;

  /// Số ngày hạn trả muộn hơn ngày kết thúc kỳ. 0 = trả đúng ngày kết thúc kỳ
  /// (hành vi trước v21). Xem `bill_an_han.dart`.
  final int anHanNgay;

  /// Hạn trả đang lưu trong bản ghi khi nó **không khớp** chu kỳ.
  ///
  /// Chỉ để cảnh báo, không phải giá trị sẽ ghi xuống. Xem [canhBaoHanCu].
  final DateTime? hanCuKhongKhop;

  const BillSchedule({
    required this.startDate,
    required this.timeRecurrence,
    required this.repeat,
    this.anchorDay,
    this.anHanNgay = 0,
    this.hanCuKhongKhop,
  });

  /// Ngày gốc dùng để tính hạn. Suy từ [startDate] khi chưa có.
  int get anchorDayHieuLuc => anchorDay ?? startDate.day;

  /// Ngày KẾT THÚC KỲ TÍNH TIỀN — luôn do chu kỳ và ngày gốc quyết định.
  /// Trước v21 đây chính là [dueDate].
  DateTime get ketThucKy =>
      nextBillDueDate(startDate, timeRecurrence, anchorDay: anchorDayHieuLuc);

  /// Ngày kết thúc của kỳ KẾ TIẾP — mốc mà hạn trả kỳ này phải đứng trước.
  DateTime get ketThucKyKeTiep =>
      nextBillDueDate(ketThucKy, timeRecurrence, anchorDay: anchorDayHieuLuc);

  /// Hạn trả = kết thúc kỳ + ân hạn.
  DateTime get dueDate => hanTraTu(ketThucKy, anHanNgay);

  bool get isRecurring => repeat;

  /// Giá trị ghi vào cột `timeRecurrence` (NOT NULL bên client).
  String get storedTimeRecurrence => timeRecurrence;

  /// Bất biến: ngày bắt đầu phải nằm trước ngày kết thúc kỳ, và ân hạn hợp lệ.
  ///
  /// Vế đầu với mọi chu kỳ hợp lệ thì luôn đúng, nhưng giữ lại làm lưới an
  /// toàn cho trường hợp `timeRecurrence` mang một giá trị lạ từ backend —
  /// `nextBillDueDate` khi đó trả nguyên mốc cũ. Vế sau là ba luật của
  /// `loiAnHan`, trong đó luật "hạn trả phải trước kỳ kế tiếp" chặn hai kỳ
  /// cùng mở.
  String? get dateError {
    if (!startDate.isBefore(ketThucKy)) {
      return 'Chu kỳ "$timeRecurrence" không tính được ngày đến hạn hợp lệ';
    }
    return loiAnHan(
      anHanNgay: anHanNgay,
      ketThucKy: ketThucKy,
      ketThucKyKeTiep: ketThucKyKeTiep,
    );
  }

  /// Lời cảnh báo khi bản ghi đang mang một hạn trả không khớp chu kỳ.
  ///
  /// Hoá đơn do bản client cũ, hoặc do Admin-web, có thể có cửa sổ trả bất kỳ
  /// (bắt đầu 04/09, hạn 11/09, chu kỳ tháng). Nay hạn luôn suy từ chu kỳ (cộng
  /// ân hạn), nên mở form ra rồi lưu lại là **đổi hạn trả của người dùng**. Đổi
  /// mà không nói gì đúng là lớp lỗi âm thầm mà dự án này đã dính nhiều lần,
  /// nên phải báo ra.
  String? get canhBaoHanCu {
    final cu = hanCuKhongKhop;
    if (cu == null) return null;
    final f = DateFormat('dd/MM/yyyy');
    return 'Hoá đơn này đang có hạn trả ${f.format(cu)}, không khớp chu kỳ đã '
        'chọn. Lưu lại sẽ đổi thành ${f.format(dueDate)}.';
  }

  BillSchedule copyWith({
    DateTime? startDate,
    String? timeRecurrence,
    bool? repeat,
    int? anHanNgay,
  }) {
    // Người dùng vừa chọn một ngày bắt đầu khác nghĩa là họ vừa nói lại ý định
    // của mình, nên ngày gốc đi theo ngày mới. Giữ ngày gốc cũ ở đây là để một
    // hoá đơn vừa được đổi sang ngày 15 vẫn đến hạn vào ngày 31. Đổi ân hạn thì
    // KHÔNG đụng ngày gốc — hai trục độc lập.
    final anchorMoi = startDate != null ? startDate.day : anchorDay;
    final moi = BillSchedule(
      startDate: startDate ?? this.startDate,
      timeRecurrence: timeRecurrence ?? this.timeRecurrence,
      repeat: repeat ?? this.repeat,
      anchorDay: anchorMoi,
      anHanNgay: anHanNgay ?? this.anHanNgay,
      hanCuKhongKhop: hanCuKhongKhop,
    );
    // Người dùng vừa chỉnh cho khớp lại thì cảnh báo tự tắt.
    return moi.hanCuKhongKhop == moi.dueDate
        ? BillSchedule(
            startDate: moi.startDate,
            timeRecurrence: moi.timeRecurrence,
            repeat: moi.repeat,
            anchorDay: moi.anchorDay,
            anHanNgay: moi.anHanNgay,
          )
        : moi;
  }

  static BillSchedule fromBill(Bill bill) {
    final batDau = bill.startDate ?? bill.dueDate;
    // Ngày gốc của **bản ghi**, không suy lại từ ngày bắt đầu: với kỳ thứ ba
    // của một chuỗi ngày 31, ngày bắt đầu là 28/02 nhưng ngày gốc vẫn là 31.
    // Suy lại ở đây là mở form ra rồi lưu là hạ hoá đơn ấy xuống ngày 28 —
    // đúng lớp lỗi âm thầm mà `canhBaoHanCu` sinh ra để chặn.
    final goc = bill.anchorDay;
    // Ân hạn đọc từ HÀNG (dueDate − periodEnd). Hàng cũ (periodEnd NULL) ra 0
    // nên hạn tính ra y hệt trước v21 — đây là chốt để mở form Sửa rồi lưu
    // không đổi hạn của ai.
    final anHan = anHanCua(bill);
    final hanTheoChuKy = hanTraTu(
      nextBillDueDate(
        batDau,
        bill.timeRecurrence,
        anchorDay: goc ?? batDau.day,
      ),
      anHan,
    );
    return BillSchedule(
      startDate: batDau,
      timeRecurrence: bill.timeRecurrence,
      repeat: bill.isRecurrence,
      anchorDay: goc,
      anHanNgay: anHan,
      hanCuKhongKhop: hanTheoChuKy == bill.dueDate ? null : bill.dueDate,
    );
  }
}
