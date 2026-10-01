/// Spike C4 — giọng nói và chụp hoá đơn (kế hoạch `plans/2026-09-28-c4-spike-giong-noi-chup-hoa-don.md`). Đường ĐO
/// TẠM: chỉ sống khi build với `--dart-define=SPIKE_C4=true`; bản thường hằng [kSpikeC4] là `false` và trình biên dịch
/// loại cả nhánh. Mã ở đây là mã BỎ ĐI — đầu ra của spike là một bảng số đo, không phải tính năng.
///
/// Tệp này giữ phần THUẦN (luật đọc hoá đơn từ chữ OCR, đọc JSON của mô hình, prompt) để test được; màn đo ở
/// `spike_c4_page.dart`.
library;

import 'dart:convert';

import '../../../core/category/category_name.dart';

/// Bật bằng `flutter build apk --debug --dart-define=SPIKE_C4=true`.
const bool kSpikeC4 = bool.fromEnvironment('SPIKE_C4');

/// Lối B giọng nói, kiểu 1: chép lời — để so ngang với lối A (câu → `docCauGiaoDich`).
const String kPromptChepLoi = 'Chép lại chính xác câu tiếng Việt trong đoạn ghi âm. Chỉ trả về câu ấy, không giải thích.';

/// Lối B giọng nói, kiểu 2: hỏi thẳng thứ cần (mục 8.7 `AI_EDGE_FEATURE.md`: đi qua bản chép là thêm một nguồn sai).
const String kPromptYDinh = 'Người nói vừa kể một khoản thu hoặc chi. Trả về đúng một dòng dạng: '
    '<số tiền bằng chữ số, đơn vị đồng> | <nội dung ngắn>. Không giải thích.';

/// Lối B chụp hoá đơn.
const String kPromptHoaDon = 'Đây là ảnh một hoá đơn hoặc biên lai. Trả về DUY NHẤT một JSON: '
    '{"tong": <tổng tiền phải trả, số nguyên đồng>, "cua_hang": "<tên cửa hàng>", "ngay": "<dd/MM/yyyy hoặc rỗng>"}. '
    'Không giải thích.';

class KetQuaHoaDon {
  final int? tong;
  final String? cuaHang;
  final String? ngay;

  /// Dòng mà luật lấy tổng từ đó — để người chấm thấy vì sao (chỉ lối A).
  final String? canCu;
  const KetQuaHoaDon({this.tong, this.cuaHang, this.ngay, this.canCu});

  @override
  String toString() => 'tong=$tong | cua_hang=$cuaHang | ngay=$ngay${canCu == null ? '' : ' | can_cu="$canCu"'}';
}

String _bo(String s) => removeVietnameseTones(normalizeCategoryName(s));

/// Nhãn của dòng tổng, theo thứ tự ƯU TIÊN (đứng trước thắng). So trên chữ bỏ dấu.
const List<String> _nhanTong = [
  'tong thanh toan',
  'can thanh toan',
  'phai thanh toan',
  'khach phai tra',
  'phai tra',
  'tong cong',
  'tong tien',
  'thanh tien',
  'grand total',
  'total',
  'thanh toan',
  'so tien',
  'tong',
];

/// Dòng trông như tổng nhưng không phải số phải trả.
const List<String> _nhanLoai = [
  'khach dua',
  'tien khach',
  'tien thoi',
  'thoi lai',
  'tien thua',
  'tra lai',
  'giam gia',
  'chiet khau',
  'tong so luong',
  'tong sl',
  'subtotal',
  'tam tinh',
];

final RegExp _so = RegExp(r'\d[\d.,]*\d|\d');
final RegExp _ngay = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4}|\d{2})\b');

/// Một chuỗi số trên hoá đơn → số nguyên đồng. `.` / `,` theo sau bởi đúng 3 chữ số là ngăn nghìn; phần lẻ sau dấu
/// cuối (1–2 chữ số) bị bỏ. `null` khi không ra số.
int? docSoHoaDon(String s) {
  final m = RegExp(r'^(\d{1,3}(?:[.,]\d{3})+)(?:[.,]\d{1,2})?$').firstMatch(s);
  if (m != null) return int.tryParse(m.group(1)!.replaceAll(RegExp(r'[.,]'), ''));
  final le = RegExp(r'^(\d+)[.,]\d{1,2}$').firstMatch(s);
  if (le != null) return int.tryParse(le.group(1)!);
  return int.tryParse(s);
}

/// Số tiền hợp lý trên một dòng: từ 1.000 đ, dưới 10 chữ số. Bỏ chuỗi bắt đầu bằng `0` (số điện thoại) và chuỗi liền
/// từ 9 chữ số không ngăn nghìn (mã vạch, mã số thuế, số tài khoản).
List<int> _tienTrenDong(String dong) => [
      for (final m in _so.allMatches(dong))
        if (!(m.group(0)!.startsWith('0') && m.group(0)!.length > 1) &&
            !(m.group(0)!.length > 8 && !m.group(0)!.contains(RegExp(r'[.,]'))))
          if (docSoHoaDon(m.group(0)!) case final v? when v >= 1000 && v < 1000000000) v,
    ];

/// Một dòng chữ OCR kèm khung của nó trên ảnh (điểm ảnh, gốc ở góc trên trái). Kiểu thuần — màn đo chép từ
/// `TextLine.boundingBox` của ML Kit sang, để phép ghép hàng test được mà không cần gói ấy.
class DongOcr {
  final String chu;
  final double trai, tren, phai, duoi;
  const DongOcr(this.chu, {required this.trai, required this.tren, required this.phai, required this.duoi});
}

/// Ghép các dòng OCR CÙNG HÀNG thành một dòng chữ, hàng xếp từ trên xuống, trong hàng xếp từ trái sang.
///
/// ⚠️ ML Kit trả `blocks → lines` theo CỘT: hoá đơn hai cột ra cả khối nhãn rồi mới tới khối số, nên nối theo thứ tự
/// trả về thì nhãn *TỔNG CỘNG* không có số nào cạnh nó (đo Realme 2026-10-01: ảnh thử ra tiền khách đưa).
///
/// Hai dòng cùng hàng ⇔ tâm dọc của MỖI dòng nằm trong khung dọc của dòng KIA. Đòi cả hai chiều để một dòng chữ to
/// (tên cửa hàng) không nuốt dòng nhỏ sát dưới nó. Khung là khung thẳng trục — ảnh nghiêng nhiều thì hai đầu một hàng
/// lệch quá nửa chiều cao chữ và phép này tách chúng ra; giới hạn của spike, đo bằng ảnh thật.
String ghepDongTheoHang(List<DongOcr> dong) {
  double tam(DongOcr d) => (d.tren + d.duoi) / 2;
  bool cungHang(DongOcr a, DongOcr b) =>
      tam(a) >= b.tren && tam(a) <= b.duoi && tam(b) >= a.tren && tam(b) <= a.duoi;

  final hang = <List<DongOcr>>[];
  for (final d in [...dong]..sort((a, b) => tam(a).compareTo(tam(b)))) {
    // Xét MỌI hàng đã có, không chỉ hàng cuối: ảnh nghiêng thì đầu phải của hàng trên có thể thấp hơn đầu trái hàng dưới.
    final h = hang.where((h) => h.any((x) => cungHang(x, d))).firstOrNull;
    h == null ? hang.add([d]) : h.add(d);
  }
  double dinh(List<DongOcr> h) => h.map((d) => d.tren).reduce((a, b) => a < b ? a : b);
  hang.sort((a, b) => dinh(a).compareTo(dinh(b)));
  return [
    for (final h in hang) ([...h]..sort((a, b) => a.trai.compareTo(b.trai))).map((d) => d.chu).join(' '),
  ].join('\n');
}

/// Lối A chụp hoá đơn: chữ OCR (mỗi dòng một dòng) → tổng tiền + tên cửa hàng + ngày.
///
/// Tổng: dòng mang nhãn tổng (ưu tiên theo [_nhanTong], hoà thì dòng SAU thắng — tổng cuối cùng nằm dưới), lấy số lớn
/// nhất trên dòng ấy; dòng nhãn không có số thì nhìn dòng kế (OCR hay tách nhãn và số). Không có nhãn nào → số lớn nhất
/// của cả hoá đơn.
KetQuaHoaDon docHoaDonTuChu(String vanBan) {
  final dong = [for (final d in vanBan.split('\n')) if (d.trim().isNotEmpty) d.trim()];
  if (dong.isEmpty) return const KetQuaHoaDon();
  final bo = [for (final d in dong) _bo(d)];

  int? tong;
  String? canCu;
  var hang = _nhanTong.length;
  for (var i = 0; i < dong.length; i++) {
    if (_nhanLoai.any(bo[i].contains)) continue;
    final h = _nhanTong.indexWhere(bo[i].contains);
    if (h < 0 || h > hang) continue;
    var tien = _tienTrenDong(dong[i]);
    var nguon = dong[i];
    if (tien.isEmpty && i + 1 < dong.length && !_nhanLoai.any(bo[i + 1].contains)) {
      tien = _tienTrenDong(dong[i + 1]);
      nguon = '${dong[i]} ⏎ ${dong[i + 1]}';
    }
    if (tien.isEmpty) continue;
    hang = h;
    tong = tien.reduce((a, b) => a > b ? a : b);
    canCu = nguon;
  }
  if (tong == null) {
    for (var i = 0; i < dong.length; i++) {
      if (_nhanLoai.any(bo[i].contains)) continue;
      for (final v in _tienTrenDong(dong[i])) {
        if (tong == null || v > tong) {
          tong = v;
          canCu = '(không nhãn — số lớn nhất) ${dong[i]}';
        }
      }
    }
  }

  final cuaHang = dong.where((d) => RegExp(r'\p{L}{3,}', unicode: true).hasMatch(d)).firstOrNull;
  final n = _ngay.firstMatch(vanBan);
  return KetQuaHoaDon(
    tong: tong,
    cuaHang: cuaHang,
    ngay: n == null
        ? null
        : '${n.group(1)!.padLeft(2, '0')}/${n.group(2)!.padLeft(2, '0')}/'
            '${n.group(3)!.length == 2 ? '20${n.group(3)}' : n.group(3)}',
    canCu: canCu,
  );
}

/// Lối B chụp hoá đơn: chữ mô hình trả về → [KetQuaHoaDon]. Bỏ rào ```json```, lấy khối `{…}` đầu tiên. `null` khi
/// không đọc ra JSON — người chấm xem chữ thô.
KetQuaHoaDon? docHoaDonTuJson(String chuMoHinh) {
  final a = chuMoHinh.indexOf('{');
  final b = chuMoHinh.lastIndexOf('}');
  if (a < 0 || b <= a) return null;
  try {
    final j = jsonDecode(chuMoHinh.substring(a, b + 1));
    if (j is! Map) return null;
    final t = j['tong'];
    final tong = switch (t) {
      final int v => v,
      final double v => v.round(),
      final String v => docSoHoaDon(v.replaceAll(RegExp(r'[^\d.,]'), '')),
      _ => null,
    };
    String? chu(Object? v) => (v is String && v.trim().isNotEmpty) ? v.trim() : null;
    return KetQuaHoaDon(tong: tong, cuaHang: chu(j['cua_hang']), ngay: chu(j['ngay']));
  } catch (_) {
    return null;
  }
}
