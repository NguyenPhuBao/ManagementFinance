/// Tầng thuần của trang Phân tích: tổng thu/chi một tháng, so với tháng trước,
/// và chi tiêu chia theo danh mục.
///
/// Tách khỏi widget vì trang này từng là **số cứng** suốt nhiều tuần, và lớp
/// lỗi thay thế nó hỏng **im lặng**: một khoản đếm hai lần ở biên tháng, một
/// khoản chuyển ví bị coi là chi tiêu, tháng 2 năm nhuận mất ngày 29. Không
/// exception, chỉ con số khác đi — nên phần khó phải kiểm được bằng danh sách,
/// không cần CSDL.
library;

import 'khoan_vao_thong_ke.dart';
import 'pham_vi_ky.dart';

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

  /// Ghi chú thô — chỉ dùng để nhận ra khoản **điều chỉnh số dư**, thứ phải
  /// nằm ngoài thống kê. Để `null` là "nơi gọi chưa điền", và khi ấy hàng
  /// được TÍNH: mặc định an toàn, vì giấu nhầm một khoản chi thật tệ hơn.
  final String? ghiChu;

  /// `classify` của danh mục mà khoản này gắn: `'thu'`, `'chi'` hoặc
  /// `'vay_no'`. `null` là "nơi gọi chưa điền" hoặc "không tra được danh mục";
  /// khi ấy `phanLoaiCua()` rơi về [loai]. Mặc định an toàn, vì đoán bừa một
  /// phân loại là báo cáo sai mà không ai biết.
  final String? classify;

  /// **Tên** danh mục mà khoản này gắn. Thêm 2026-09-15 cho hai biểu đồ vay/nợ.
  ///
  /// Vì sao tầng thuần lại cần một cái tên: bốn vai *cho vay · thu nợ · đi vay ·
  /// trả nợ* **không có chỗ nào lưu**, và chiều tiền chỉ tách được hai nhóm —
  /// thứ duy nhất tách được bốn là tên. Xem `vai_vay_no.dart`.
  ///
  /// `null` là "nơi gọi chưa điền"; khi ấy vai rơi về `VaiVayNo.khac`, tức
  /// khoản vẫn được đếm nhưng không bị xếp bừa vào một vai.
  final String? tenDanhMuc;

  const KhoanThuChi({
    required this.ngay,
    required this.soTien,
    required this.loai,
    required this.categoryId,
    this.ghiChu,
    this.classify,
    this.tenDanhMuc,
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
    // Phép lọc có ĐÚNG MỘT định nghĩa ở `khoan_vao_thong_ke.dart`: nó loại cả
    // khoản chuyển (tiền đổi chỗ) lẫn khoản điều chỉnh số dư (phép sửa sổ).
    if (!khoanVaoThongKe(
      loai: k.loai,
      categoryId: k.categoryId,
      ghiChu: k.ghiChu,
    )) {
      continue;
    }
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
/// [loai] mặc định `'chi'` — tên hàm giữ nguyên vì trang Phân tích chỉ dùng
/// chiều ấy. Trang Xuất báo cáo gọi lại nó với `'thu'` để dựng bảng thu theo
/// danh mục: một định nghĩa cho cả hai chiều, đừng viết bản sao thứ hai.
List<ChiTheoDanhMuc> chiTheoDanhMuc(
  List<KhoanThuChi> ds, {
  required DateTime from,
  required DateTime to,
  String loai = 'chi',
}) {
  final gom = <String?, double>{};
  var tong = 0.0;
  for (final k in ds) {
    if (k.loai != loai || !_trongKhoang(k.ngay, from, to)) continue;
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
  final nguyen = a.round();
  // ⚠️ Làm tròn ra 0 thì **bỏ dấu**: "-0" là một con số không tồn tại. Cùng
  // luật với `CurrencyFormatter.formatCoDau`.
  //
  // Không phải ca hiếm: biểu đồ nào có phần âm thì biên trên tính bằng
  // `san + 3 * buoc`, và sai số dấu phẩy động cho ra chừng -1e-16 ngay tại vị
  // trí lẽ ra là 0 — nhãn trục tung in "-0". Thấy trên máy ảo 2026-09-15 ở
  // khối "Dòng tiền tự do"; `flutter test` mù hẳn vì nhãn trục vẽ trong canvas
  // của fl_chart.
  return nguyen == 0 ? '0' : '$dau$nguyen';
}

/// Một điểm trên biểu đồ xu hướng: tổng thu và tổng chi của **trọn một kỳ**.
///
/// Mang thẳng [Ky] chứ không mang `(nam, thang)`: từ 2026-09-15 điểm có thể là
/// một tuần, một quý hay một năm, và nhãn trục lấy từ `ky.nhanTruc` nên trang
/// không phải đoán đơn vị từ hai con số.
class DiemThoiGian {
  final Ky ky;
  final TongThuChi tong;

  const DiemThoiGian({required this.ky, required this.tong});
}

/// [soKy] kỳ liên tiếp kết thúc ở [ky], **cũ nhất trước**.
///
/// Thứ tự **ngược** với `cacKyGanNhat`: hàm kia phục vụ bộ chọn nên xếp mới
/// nhất trước, còn trục thời gian thì đọc từ trái sang phải. Lấy nhầm hàm là
/// biểu đồ chạy lùi mà không lỗi nào báo.
///
/// Kỳ không có giao dịch vẫn là một điểm mang số 0 chứ không bị bỏ: bỏ đi là
/// trục co lại, hai kỳ cách nhau nửa năm hiện ra như liền kề.
///
/// Mọi luật đếm mượn nguyên `tongThuChi` — biên `[from, to)`, `'transfer'`
/// không phải thu cũng không phải chi — và việc lùi kỳ mượn nguyên `lui`, nên
/// tháng ngắn, năm nhuận và mốc năm đã đúng sẵn. Ở đây không có luật mới nào.
List<DiemThoiGian> chuoiTheoKy(
  List<KhoanThuChi> ds, {
  required Ky ky,
  int soKy = kSoKyXuHuong,
}) =>
    [
      for (var i = soKy - 1; i >= 0; i--)
        () {
          final k = lui(ky, i);
          return DiemThoiGian(
            ky: k,
            tong: tongThuChi(ds, from: k.from, to: k.to),
          );
        }(),
    ];

/// Số đường tối đa trên khối xu hướng khi người dùng chọn danh mục.
///
/// Ở 411dp, quá năm đường trên một ô cao 180px là một búi chỉ không đọc được
/// — và màu danh mục có thể trùng nhau. Chip thứ sáu bị **khoá nhìn thấy
/// được**, không phải bấm mà không có gì xảy ra. Định nghĩa ở tầng domain để
/// cubit (chốt) và trang (chữ hướng dẫn, khoá chip) cùng đọc một con số.
const int kToiDaDuongXuHuong = 5;

/// Chuỗi [soKy] kỳ cho **từng** danh mục có phát sinh, khoá là `categoryId`
/// (`null` = chưa phân loại). Mỗi chuỗi **cũ nhất trước**, cùng quy ước với
/// [chuoiTheoKy].
///
/// ## Vì sao một lượt duyệt
///
/// Gọi [chuoiTheoKy] một lần cho mỗi danh mục là `số danh mục × soKy` lượt quét
/// toàn bộ giao dịch: với 30 danh mục và 5.000 giao dịch đó là 900.000 phép so
/// ngày **mỗi lần stream phát**, mà stream này phát lại sau **mọi** chu kỳ đồng
/// bộ nền. Ở đây chỉ duyệt một lần, phân thẳng vào ô `(categoryId, kỳ)`.
///
/// Danh mục **không** có khoản nào trong khoảng thì không có khoá — bộ chọn
/// trên khối xu hướng chỉ nên liệt kê thứ vẽ ra được một đường có nội dung.
/// Nhưng danh mục **có** khoản thì chuỗi của nó **đủ** [soKy] điểm, kỳ rỗng
/// mang số 0: bỏ điểm rỗng là trục co lại và hai kỳ cách nhau nửa năm hiện ra
/// như liền kề.
///
/// Luật đếm mượn nguyên [tongThuChi] — biên `[from, to)` và
/// `khoanVaoThongKe()` — nên ở đây không có luật mới nào.
Map<String?, List<DiemThoiGian>> chuoiTheoDanhMuc(
  List<KhoanThuChi> ds, {
  required Ky ky,
  int soKy = kSoKyXuHuong,
}) {
  // Kỳ của từng cột, cũ nhất trước. Việc lùi mượn nguyên `lui`, nên tháng ngắn,
  // năm nhuận và mốc năm đã đúng sẵn.
  final cot = [for (var i = soKy - 1; i >= 0; i--) lui(ky, i)];

  final thu = <String?, List<double>>{};
  final chi = <String?, List<double>>{};

  for (final k in ds) {
    if (!khoanVaoThongKe(
      loai: k.loai,
      categoryId: k.categoryId,
      ghiChu: k.ghiChu,
    )) {
      continue;
    }
    if (k.loai != 'thu' && k.loai != 'chi') continue;
    // Tìm cột chứa khoản này. Số cột nhỏ (6) nên quét thẳng rẻ hơn dựng khoá.
    var i = -1;
    for (var j = 0; j < cot.length; j++) {
      if (_trongKhoang(k.ngay, cot[j].from, cot[j].to)) {
        i = j;
        break;
      }
    }
    if (i < 0) continue;

    thu.putIfAbsent(k.categoryId, () => List<double>.filled(soKy, 0));
    chi.putIfAbsent(k.categoryId, () => List<double>.filled(soKy, 0));
    if (k.loai == 'thu') {
      thu[k.categoryId]![i] += k.soTien;
    } else {
      chi[k.categoryId]![i] += k.soTien;
    }
  }

  return {
    for (final id in thu.keys)
      id: [
        for (var i = 0; i < soKy; i++)
          DiemThoiGian(
            ky: cot[i],
            tong: TongThuChi(thu: thu[id]![i], chi: chi[id]![i]),
          ),
      ],
  };
}
