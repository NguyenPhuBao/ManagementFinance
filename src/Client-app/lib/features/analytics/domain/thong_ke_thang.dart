/// Tầng thuần của trang Phân tích: tổng thu/chi một tháng, so với tháng trước,
/// và chi tiêu chia theo danh mục.
///
/// Tách khỏi widget vì trang này từng là **số cứng** suốt nhiều tuần, và lớp
/// lỗi thay thế nó hỏng **im lặng**: một khoản đếm hai lần ở biên tháng, một
/// khoản chuyển ví bị coi là chi tiêu, tháng 2 năm nhuận mất ngày 29. Không
/// exception, chỉ con số khác đi — nên phần khó phải kiểm được bằng danh sách,
/// không cần CSDL.
library;

/// Một giao dịch rút gọn khỏi hàng Drift: chỉ bốn thứ phép thống kê cần.
class KhoanThuChi {
  final DateTime ngay;
  final double soTien;

  /// `'thu'`, `'chi'` hoặc `'transfer'`. Giá trị cuối là tiền **đổi chỗ**
  /// (nạp mục tiêu, chuyển giữa hai ví) — không phải thu, không phải chi.
  final String loai;

  /// `null` là khoản chưa phân loại. Vẫn phải gom, nếu không tổng các lát nhỏ
  /// hơn tổng chi trên thẻ.
  final String? categoryId;

  const KhoanThuChi({
    required this.ngay,
    required this.soTien,
    required this.loai,
    required this.categoryId,
  });
}

/// Biên của một tháng dương lịch, **biên `to` mở**: `[from, to)`.
///
/// Cùng quy ước với ngân sách (`BudgetLocalDataSource.getExpenses`): bộ chọn
/// ngày trả về 00:00, nên khoản ghi ngày đầu tháng sau nằm đúng mốc `to` của
/// tháng trước — đóng biên là đếm nó ở cả hai tháng.
///
/// Tháng 12 tự cuộn sang năm sau nhờ `DateTime` chuẩn hoá tháng 13; năm nhuận
/// và tháng ngắn cũng do đó mà đúng, không tự cộng "30 ngày".
({DateTime from, DateTime to}) bienThang(int nam, int thang) =>
    (from: DateTime(nam, thang, 1), to: DateTime(nam, thang + 1, 1));

// Biên `to` MỞ — `isBefore(to)` chứ không phải `!isAfter(to)`. Bản sai có chủ
// ý dùng vế sau đã đếm khoản 00:00 ngày đầu tháng sau vào tháng trước.
bool _trongKhoang(DateTime ngay, DateTime from, DateTime to) =>
    !ngay.isBefore(from) && ngay.isBefore(to);

/// Tổng thu và tổng chi của một khoảng.
class TongThuChi {
  final double thu;
  final double chi;

  const TongThuChi({required this.thu, required this.chi});

  /// "Số dư còn lại" của tháng: thu trừ chi. Âm khi chi vượt thu — hiện số
  /// âm, đừng kẹp về 0.
  double get conLai => thu - chi;
}

TongThuChi tongThuChi(
  List<KhoanThuChi> ds, {
  required DateTime from,
  required DateTime to,
}) {
  var thu = 0.0;
  var chi = 0.0;
  for (final k in ds) {
    if (!_trongKhoang(k.ngay, from, to)) continue;
    // Chỉ hai loại. `'transfer'` cố ý rơi qua: tiền đổi chỗ không phải chi
    // tiêu — đếm nó là mỗi kỳ trích tự động vào mục tiêu làm "Tổng chi" tăng.
    if (k.loai == 'thu') thu += k.soTien;
    if (k.loai == 'chi') chi += k.soTien;
  }
  return TongThuChi(thu: thu, chi: chi);
}

/// Phần trăm thay đổi của [nay] so với [truoc]; `null` khi không so được.
///
/// [truoc] bằng 0 thì trả `null` chứ không phải vô cực hay 100%: cả hai đều là
/// số bịa, và người dùng đọc "tăng 100%" sẽ tưởng tháng trước có một nửa.
double? phanTramSoVoi(double nay, double truoc) {
  if (truoc == 0) return null;
  return (nay - truoc) / truoc * 100;
}

/// Một danh mục trong bảng chi tiêu, hoặc lát "Khác" của donut.
class ChiTheoDanhMuc {
  /// `null` là "Chưa phân loại" — **trừ khi** [laKhac] bật.
  final String? categoryId;
  final double soTien;

  /// Tỉ lệ trên tổng chi của khoảng, trong `[0, 1]`.
  final double tiLe;

  /// Lát gom "phần còn lại" của donut, không ứng với danh mục nào.
  final bool laKhac;

  const ChiTheoDanhMuc({
    required this.categoryId,
    required this.soTien,
    required this.tiLe,
    this.laKhac = false,
  });
}

/// Chi tiêu gom theo danh mục, **sắp giảm dần** theo số tiền.
///
/// Hoà thì sắp theo `categoryId` để hai lần vẽ không đảo chỗ nhau; `null`
/// (chưa phân loại) xếp sau các id thật khi hoà.
List<ChiTheoDanhMuc> chiTheoDanhMuc(
  List<KhoanThuChi> ds, {
  required DateTime from,
  required DateTime to,
}) {
  final gom = <String?, double>{};
  var tong = 0.0;
  for (final k in ds) {
    if (k.loai != 'chi' || !_trongKhoang(k.ngay, from, to)) continue;
    gom[k.categoryId] = (gom[k.categoryId] ?? 0) + k.soTien;
    tong += k.soTien;
  }
  if (tong <= 0) return const [];

  final ra = [
    for (final e in gom.entries)
      ChiTheoDanhMuc(categoryId: e.key, soTien: e.value, tiLe: e.value / tong),
  ]..sort((a, b) {
      final c = b.soTien.compareTo(a.soTien);
      if (c != 0) return c;
      if (a.categoryId == null) return 1;
      if (b.categoryId == null) return -1;
      return a.categoryId!.compareTo(b.categoryId!);
    });
  return ra;
}

/// [top] lát đầu, phần còn lại gom thành một lát "Khác".
///
/// Chú giải của thiết kế có đúng bốn ô, nên lát thứ năm — dù chỉ có một — vẫn
/// thành "Khác" chứ không hiện tên thật; thiếu lát ấy thì vòng donut hở một
/// khoảng trông như lỗi vẽ.
List<ChiTheoDanhMuc> topVaKhac(List<ChiTheoDanhMuc> ds, {int top = 4}) {
  if (ds.length <= top) return ds;
  final dau = ds.take(top).toList();
  final conLai = ds.skip(top);
  dau.add(ChiTheoDanhMuc(
    categoryId: null,
    soTien: conLai.fold(0.0, (s, x) => s + x.soTien),
    tiLe: conLai.fold(0.0, (s, x) => s + x.tiLe),
    laKhac: true,
  ));
  return dau;
}

/// Số tiền rút gọn cho tâm donut: `6.5M`, `950K`, `1.5B`; dưới nghìn giữ nguyên.
///
/// Một chữ số lẻ, **làm tròn** chứ không cắt (1,25 triệu → `1.3M`), và bỏ
/// `.0` thừa (`6M` chứ không `6.0M`). Dấu chấm thập phân theo kiểu Anh vì hậu
/// tố K/M/B cũng vậy — trộn "6,5M" là nửa nọ nửa kia.
String rutGon(double x) {
  String mot(double v, String hauTo) {
    final s = v.toStringAsFixed(1);
    return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}$hauTo';
  }

  final a = x.abs();
  final dau = x < 0 ? '-' : '';
  if (a >= 1e9) return '$dau${mot(a / 1e9, 'B')}';
  if (a >= 1e6) return '$dau${mot(a / 1e6, 'M')}';
  if (a >= 1e3) return '$dau${mot(a / 1e3, 'K')}';
  return '$dau${a.round()}';
}

/// [soThang] tháng gần nhất tính từ [now], **mới nhất trước**, cho bộ chọn tháng.
///
/// Lùi bằng `DateTime(nam, thang - i, 1)` để tháng 0, -1… tự cuộn về năm
/// trước; tự trừ rồi cộng 12 là chỗ đã sinh lỗi ở nhiều app khác.
List<({int nam, int thang})> cacThangGanNhat(DateTime now, {int soThang = 12}) =>
    [
      for (var i = 0; i < soThang; i++)
        () {
          final d = DateTime(now.year, now.month - i, 1);
          return (nam: d.year, thang: d.month);
        }(),
    ];

/// Một điểm trên biểu đồ xu hướng: tổng thu và tổng chi của trọn một tháng.
class DiemThoiGian {
  final int nam;
  final int thang;
  final TongThuChi tong;

  const DiemThoiGian({
    required this.nam,
    required this.thang,
    required this.tong,
  });
}

/// [soThang] tháng liên tiếp kết thúc ở ([nam], [thang]), **cũ nhất trước**.
///
/// Thứ tự **ngược** với `cacThangGanNhat`: hàm kia phục vụ bộ chọn tháng nên
/// xếp mới nhất trước, còn trục thời gian thì đọc từ trái sang phải. Lấy nhầm
/// hàm là biểu đồ chạy lùi mà không lỗi nào báo.
///
/// Tháng không có giao dịch vẫn là một điểm mang số 0 chứ không bị bỏ: bỏ đi
/// là trục co lại, hai tháng cách nhau nửa năm hiện ra như liền kề.
///
/// Mọi luật đếm mượn nguyên `tongThuChi` — biên `[from, to)`, `'transfer'`
/// không phải thu cũng không phải chi — nên ở đây không có luật mới nào.
List<DiemThoiGian> chuoiTheoThang(
  List<KhoanThuChi> ds, {
  required int nam,
  required int thang,
  int soThang = 6,
}) =>
    [
      for (var i = soThang - 1; i >= 0; i--)
        () {
          // `thang - i` bằng 0 hay âm tự cuộn về năm trước nhờ `DateTime`.
          final d = DateTime(nam, thang - i, 1);
          final b = bienThang(d.year, d.month);
          return DiemThoiGian(
            nam: d.year,
            thang: d.month,
            tong: tongThuChi(ds, from: b.from, to: b.to),
          );
        }(),
    ];
