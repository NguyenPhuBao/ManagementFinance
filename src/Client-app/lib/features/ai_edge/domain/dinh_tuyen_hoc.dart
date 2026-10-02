/// Dự án B — bộ định tuyến HỌC: đặc trưng của câu hỏi và phép ĐOÁN (spec
/// `2026-10-02-du-an-b-mo-hinh-dinh-tuyen-cau-hoi-design.md` mục 4). Hàm thuần.
///
/// Phép đoán là tuyến tính + softmax, dùng chung cho cả Naive Bayes lẫn hồi quy
/// logistic — hai mô hình chỉ khác ở phép HỌC, thứ nằm ngoài `lib/`
/// (`test/tool/dinh_tuyen/huan_luyen.dart`) và gọi lại chính các hàm ở đây để
/// dựng đặc trưng. Một định nghĩa đặc trưng cho cả lúc học lẫn lúc đoán: lệch
/// nhau là mô hình đoán trên thứ nó chưa từng thấy, im lặng.
///
/// Bỏ dấu (`removeVietnameseTones`) ở đây đúng chỗ của nó: đây là GỢI Ý đường
/// đi, không phải quy tắc trùng tên (quy tắc 7 `CLAUDE.md`).
library;

import 'dart:math' as math;

import '../../../core/category/category_name.dart';

/// Nhãn ÂM: ngoài phạm vi, chào hỏi, câu mơ hồ, câu cần hai tool. Mô hình đoán
/// nhãn này thì câu đi phiên sáu tool như trước khi có bộ định tuyến học.
const String kNhanKhongDinhTuyen = 'khong_dinh_tuyen';

/// Nhãn mà app ĐƯỢC PHÉP định tuyến theo mô hình. Mô hình học đủ mười nhãn —
/// để biết câu nào KHÔNG phải câu giao dịch — nhưng app chỉ nghe nó khi nó đoán
/// một nhãn ở đây; đoán tool khác thì câu đi phiên sáu tool như cũ.
///
/// Người dùng chốt 2026-10-02 (hướng 1) sau lần huấn luyện đầu: trên 405 câu
/// luật bỏ lại, mô hình đoán đúng 134/147 câu giao dịch, nhưng với tám tool còn
/// lại mỗi tool chỉ còn 14–29 câu và nó sai ở xác suất 0,91–0,93 — định tuyến cả
/// chín tool mà không câu nào sai thì ngưỡng phải 0,98 và chỉ phủ 6,4 %. Mở thêm
/// nhãn vào tập này khi có dữ liệu thật để tin, không cần huấn luyện lại kiểu khác.
///
/// Ghép chuỗi thay vì import `cong_cu.dart`: tệp này phải thuần đến mức phép học
/// ở `test/tool/` dùng lại được mà không kéo theo tầng tool.
const Set<String> kNhanMoHinhDuocDinhTuyen = {'truy_van_giao_dich'};

/// Mọi âm tiết có chữ số (*500k*, *15*, *h0c*) thành một ký hiệu: với việc chọn
/// tool, *"trên 500k"* và *"trên 2 triệu"* là một dấu hiệu.
const String kKyHieuSo = '0';

final RegExp _ngoaiChu = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
final RegExp _coSo = RegExp(r'\p{N}', unicode: true);

/// Âm tiết của câu hỏi: chuẩn hoá → bỏ dấu → tách ở mọi ký tự không phải chữ /
/// số → âm tiết có chữ số thành [kKyHieuSo], các ký hiệu số LIỀN NHAU gom một
/// (*"1/9"* là một ngày, không phải hai con số).
List<String> amTietDinhTuyen(String cau) {
  final ra = <String>[];
  final s = removeVietnameseTones(normalizeCategoryName(cau.replaceAll('_', ' ')));
  for (final t in s.split(_ngoaiChu)) {
    if (t.isEmpty) continue;
    final x = _coSo.hasMatch(t) ? kKyHieuSo : t;
    if (x == kKyHieuSo && ra.isNotEmpty && ra.last == kKyHieuSo) continue;
    ra.add(x);
  }
  return ra;
}

/// Dạng chuẩn hoá của câu — khoá khử trùng của bộ dữ liệu.
String chuanHoaDinhTuyen(String cau) => amTietDinhTuyen(cau).join(' ');

/// Đặc trưng nhị phân: âm tiết đơn và cặp âm tiết liền nhau.
Set<String> dacTrungCua(String cau) {
  final a = amTietDinhTuyen(cau);
  return {...a, for (var i = 0; i + 1 < a.length; i++) '${a[i]} ${a[i + 1]}'};
}

class TrongSoDinhTuyen {
  TrongSoDinhTuyen({
    required this.nhan,
    required this.tuVung,
    required this.thienLech,
    required this.maTran,
  }) : _viTri = {for (var i = 0; i < tuVung.length; i++) tuVung[i]: i} {
    if (thienLech.length != nhan.length || maTran.length != tuVung.length * nhan.length) {
      throw ArgumentError('kích thước trọng số lệch: ${nhan.length} nhãn, '
          '${tuVung.length} đặc trưng, ${thienLech.length} thiên lệch, '
          '${maTran.length} trọng số');
    }
  }

  final List<String> nhan;
  final List<String> tuVung;

  /// Một số mỗi nhãn.
  final List<double> thienLech;

  /// `tuVung.length × nhan.length`, theo HÀNG đặc trưng: trọng số của đặc trưng
  /// `i` cho nhãn `c` ở `i * nhan.length + c`.
  final List<double> maTran;

  final Map<String, int> _viTri;

  int? viTriCua(String dacTrung) => _viTri[dacTrung];
}

class DoanDinhTuyen {
  const DoanDinhTuyen(this.nhan, this.xacSuat);
  final String nhan;
  final double xacSuat;
}

/// Nhãn có điểm cao nhất và xác suất softmax của nó. ⚠️ Câu không mang đặc
/// trưng nào của từ vựng → [kNhanKhongDinhTuyen] với xác suất 0: không có bằng
/// chứng thì thiên lệch của nhãn đông mẫu nhất không được đọc thành "tự tin".
DoanDinhTuyen doanDinhTuyen(TrongSoDinhTuyen w, String cau) {
  final k = w.nhan.length;
  final diem = List<double>.of(w.thienLech);
  var co = false;
  for (final f in dacTrungCua(cau)) {
    final i = w.viTriCua(f);
    if (i == null) continue;
    co = true;
    for (var c = 0; c < k; c++) {
      diem[c] += w.maTran[i * k + c];
    }
  }
  if (!co) return const DoanDinhTuyen(kNhanKhongDinhTuyen, 0);
  final lon = diem.reduce(math.max);
  var tong = 0.0;
  var nhat = 0;
  for (var c = 0; c < k; c++) {
    diem[c] = math.exp(diem[c] - lon);
    tong += diem[c];
    if (diem[c] > diem[nhat]) nhat = c;
  }
  return DoanDinhTuyen(w.nhan[nhat], diem[nhat] / tong);
}
