/// Ba con số tổng hợp của một mục tiêu: số lần nạp, trung bình mỗi lần, và
/// chuỗi kỳ nạp liên tiếp.
///
/// Hai con số đầu chỉ là phép đếm. Con số thứ ba là phép **chia thời gian
/// thành kỳ** — đúng vùng mà tháng ngắn và năm nhuận làm sai im lặng — nên cả
/// tệp nằm ở tầng thuần và có test riêng.
library;

import 'goal_auto_deposit.dart';
import 'goal_history_filter.dart';

/// Trần số kỳ được duyệt.
///
/// Dữ liệu hỏng (mốc gốc năm 1970 kèm chu kỳ ngày) không được treo giao diện.
/// Vượt trần thì **chuỗi trả `null`** chứ không kẹp: một con số tính trên cửa
/// sổ bị cắt cụt trông vẫn như thật, và không ai kiểm lại được.
const int _tranSoKy = 5000;

/// Kết quả tổng hợp; `chuoiKy` là `null` khi không đủ căn cứ chia kỳ.
class ThongKeMucTieu {
  final int soLanNap;
  final double trungBinhMoiLan;

  /// Số kỳ liên tiếp gần nhất có ít nhất một khoản nạp.
  ///
  /// `null` khi mục tiêu không có mốc gốc — cùng kỷ luật im lặng với
  /// `GoalEntity.isBehindSchedule`. Hai con số kia vẫn có giá trị.
  final int? chuoiKy;

  const ThongKeMucTieu({
    required this.soLanNap,
    required this.trungBinhMoiLan,
    required this.chuoiKy,
  });
}

/// Tổng hợp lịch sử tích luỹ, hoặc `null` khi chưa có khoản nạp nào.
///
/// Cả ba con số nói về thói quen **bỏ tiền vào**, nên khoản rút bị loại từ
/// đầu: đếm cả lần rút là trộn hai chiều tiền vào một con số, và "trung bình
/// mỗi lần" trên một danh sách toàn khoản rút là phép chia cho 0.
ThongKeMucTieu? thongKeMucTieu({
  required List<KhoanTichLuy> khoan,
  required DateTime? ngayBatDau,
  required String? chuKy,
  required DateTime now,
}) {
  final nap = [
    for (final x in khoan)
      if (!x.laKhoanRut) x,
  ];
  if (nap.isEmpty) return null;

  var tong = 0.0;
  for (final x in nap) {
    tong += x.soTien;
  }

  return ThongKeMucTieu(
    soLanNap: nap.length,
    trungBinhMoiLan: tong / nap.length,
    chuoiKy: _chuoiKy(nap: nap, goc: ngayBatDau, chuKy: chuKy, now: now),
  );
}

/// Đếm ngược từ kỳ hiện tại, dừng ở kỳ rỗng đầu tiên.
///
/// Kỳ được cắt bằng [mocThuN] **neo vào mốc gốc** — cùng phép bước kỳ mà bộ
/// trích tự động dùng, và đã kẹp đúng ngày cuối tháng lẫn năm nhuận. Tự cộng
/// tháng ở đây là bản thứ tư của cùng một luật, và là bản duy nhất không có
/// test năm nhuận.
int? _chuoiKy({
  required List<KhoanTichLuy> nap,
  required DateTime? goc,
  required String? chuKy,
  required DateTime now,
}) {
  if (goc == null) return null;

  final tang = [...nap]..sort((a, b) => a.ngay.compareTo(b.ngay));

  // Duyệt xuôi MỘT lượt, con trỏ `i` chạy theo — O(số kỳ + số khoản) thay vì
  // quét lại cả danh sách cho từng kỳ.
  final coKhoan = <bool>[];
  var i = 0;
  var dau = goc; // `mocThuN(goc, chuKy, 0)` chính là mốc gốc.
  var k = 0;

  while (k < _tranSoKy) {
    final cuoi = mocThuN(goc, chuKy, k + 1);
    var co = false;
    while (i < tang.length && tang[i].ngay.isBefore(cuoi)) {
      // Khoản ghi TRƯỚC mốc gốc không thuộc kỳ nào: không có kỳ số âm.
      if (!tang[i].ngay.isBefore(dau)) co = true;
      i++;
    }
    coKhoan.add(co);

    if (now.isBefore(cuoi)) break; // `now` nằm trong kỳ k — dừng ở đây.
    dau = cuoi;
    k++;
  }
  if (k >= _tranSoKy) return null;

  var idx = coKhoan.length - 1;
  // Kỳ hiện tại đang dở, chưa hết hạn để nói là đứt. Không có dòng này thì mỗi
  // đầu kỳ chuỗi của mọi người tụt về 0 và con số hết nghĩa.
  if (!coKhoan[idx]) idx--;

  var chuoi = 0;
  while (idx >= 0 && coKhoan[idx]) {
    chuoi++;
    idx--;
  }
  return chuoi;
}

/// Danh từ chỉ đơn vị kỳ, cho nhãn "N tháng liên tiếp".
///
/// Chu kỳ trống hoặc lạ (giá trị từ Admin-web, bản app cũ) quy về **tháng** —
/// đúng lựa chọn của [mocKeTiep], vốn cũng là phép cắt kỳ mà `_chuoiKy` đi
/// qua. Nhãn nói "quý" trong khi phép đếm cắt theo tháng là một con số không
/// ai kiểm lại được.
///
/// Cố ý tách khỏi `moTaTrichTuDong` bên `goal_config_card.dart`: hàm kia dựng
/// cụm trạng ngữ ("mỗi tháng"), hàm này cần danh từ trần.
String tenDonViKy(String? chuKy) => switch (chuKy) {
      'Day' => 'ngày',
      'Week' => 'tuần',
      'Quarter' => 'quý',
      'Year' => 'năm',
      _ => 'tháng',
    };
