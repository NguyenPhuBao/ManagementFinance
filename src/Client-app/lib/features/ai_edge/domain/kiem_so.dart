/// Bộ kiểm số — điều kiện 10 của mục 13 bản đánh giá: **mọi** con số trong câu
/// phải có trong gói số; sai thì người gọi rơi về mẫu câu.
///
/// Dùng cho cả hai bản diễn giải: mẫu câu (mọi mẫu phải tự qua được bộ kiểm,
/// nếu không P3 sẽ rơi về một câu mà bộ kiểm cũng chặn — có ca test canh ở từng
/// gói số) và SLM (P3). Đây là lớp chắn **duy nhất** giữa mô hình và người
/// dùng, nên nó không được nới vì mô hình lớn hơn (spec mục 4.4).
///
/// Ngày tháng (`12/09`, `12/09/2026`) là một LOẠI số riêng từ bước 2
/// (`LoaiSo.ngayThang`): [trichSo] tách ngày **trước** rồi mới trích số, và
/// ngày chỉ khớp mục ngày. Chỉ `dd/mm` và `dd/mm/yyyy` là ngày — nới thêm dạng
/// (`12/09/26`, "12 tháng 9") là mở cửa cho số bịa.
///
/// ⚠️ Chữ số nằm **trong tên một đối tượng** của gói (`Tiền nhà T9`) không phải
/// con số — [trichSoNgoaiTen] bỏ những tên ấy khỏi câu trước khi trích (bước
/// 1c, 2026-09-23). Trước đó 5/9 hoá đơn của tài khoản 10 mang chữ số trong
/// tên, và mọi câu đúng nêu tên chúng đều bị chặn, im lặng.
///
/// ⚠️ Số viết **bằng chữ** (*"một triệu"*, *"nửa triệu"*, *"hai trăm nghìn"*)
/// cũng là con số (bẫy 4.42, 2026-09-24): cổng D C7 hỏi *"hơn nửa triệu"*, mô
/// hình viết *"hơn một triệu"* rồi liệt kê bốn danh mục đều dưới một triệu — số
/// và tên đều thật, mệnh đề sai, và vì không có chữ số nào ngoài gói nên ba lớp
/// chắn im. [trichSo] tách cụm *số chữ + đơn vị* **trước** chữ số; lượng từ mơ
/// hồ (*"vài triệu"*) thành một số không bao giờ khớp. Chữ số kèm đơn vị chữ
/// (*"500 nghìn"*, *"2 triệu"*, *"500k"*) **cố ý** giữ nguyên cách đọc cũ (500,
/// 2): đọc thành 500.000 là mở cửa cho câu *"trên 500k là … (500.000 đ)"* của
/// lần đo 2 lọt — người dùng chốt 2026-09-24.
library;

import '../../../core/category/category_name.dart';
import 'goi_so.dart';

class SoTrich {
  final double giaTri;
  final bool laPhanTram;

  /// Một NGÀY `dd/mm` hoặc `dd/mm/yyyy` (bước 2). Khi ấy [giaTri] là
  /// `tháng·100 + ngày`, và [nam] là năm nếu câu có ghi — `null` khi câu chỉ ghi
  /// ngày/tháng.
  final bool laNgay;
  final int? nam;

  const SoTrich(
    this.giaTri, {
    required this.laPhanTram,
    this.laNgay = false,
    this.nam,
  });
}

/// Ngày `dd/mm` hoặc `dd/mm/yyyy` đứng riêng — không chữ số hay `/` dính hai
/// bên. `12/09/26` không khớp (năm hai chữ số) và đi tiếp như ba con số.
final RegExp _mauNgay =
    RegExp(r'(?<![\d/])(\d{1,2})/(\d{1,2})(?:/(\d{4}))?(?![\d/])');

/// Từ số bằng chữ → giá trị; lượng từ mơ hồ → `NaN` (không khớp gì, tức bị
/// chặn). *"không"* cố ý vắng: "không có" không phải số 0.
const Map<String, double> _soChu = {
  'nửa': 0.5,
  'một': 1,
  'hai': 2,
  'ba': 3,
  'bốn': 4,
  'năm': 5,
  'sáu': 6,
  'bảy': 7,
  'tám': 8,
  'chín': 9,
  'mười': 10,
  'vài': double.nan,
  'mấy': double.nan,
  'dăm': double.nan,
};

const Map<String, double> _donViChu = {
  'trăm': 100,
  'nghìn': 1000,
  'ngàn': 1000,
  'triệu': 1000000,
  'tỷ': 1000000000,
  'tỉ': 1000000000,
};

/// Một NHÓM: từ số + một hay nhiều đơn vị (nhân nhau: *"hai trăm nghìn"*),
/// tuỳ chọn *"rưỡi"*. Nhiều nhóm liền nhau cộng lại (*"một triệu hai trăm
/// nghìn"*). Từ số phải có đơn vị ngay sau — *"một khoản"*, *"năm nay"* không
/// phải số; đơn vị đứng một mình (*"hàng triệu"*) cũng không. Hai đầu phải là
/// ranh giới từ, không phân biệt hoa thường.
final RegExp _mauSoChu = () {
  final so = _soChu.keys.join('|');
  final dv = _donViChu.keys.join('|');
  final nhom = '(?:$so)(?:\\s+(?:$dv))+(?:\\s+rưỡi)?';
  return RegExp(
    '(?<![\\p{L}\\p{N}])$nhom(?:\\s+$nhom)*(?![\\p{L}\\p{N}])',
    unicode: true,
    caseSensitive: false,
  );
}();

final RegExp _khoangTrang = RegExp(r'\s+');

/// Giá trị của một cụm khớp [_mauSoChu]. `NaN` lan qua phép cộng nên một
/// nhóm mơ hồ làm cả cụm mơ hồ.
double _giaTriSoChu(String cum) {
  var tong = 0.0;
  var nhom = double.nan;
  var boi = 1.0;
  for (final tu in cum.toLowerCase().split(_khoangTrang)) {
    if (_soChu.containsKey(tu)) {
      if (!nhom.isNaN || boi != 1.0) tong += nhom * boi;
      nhom = _soChu[tu]!;
      boi = 1.0;
    } else if (_donViChu.containsKey(tu)) {
      boi *= _donViChu[tu]!;
    } else if (tu == 'rưỡi') {
      nhom += 0.5;
    }
  }
  return tong + nhom * boi;
}

/// Nhóm 1: dấu âm (`-` hoặc `−`); nhóm 2: phần nguyên có chấm nghìn
/// (`2.100.000`) hoặc số trần; nhóm 3: phần thập phân sau **phẩy**; nhóm 4: hậu
/// tố `%`. Dấu âm phải bắt được vì `soPhanTram` giữ dấu (`-8,3%`): mất dấu là
/// đảo nghĩa tăng/giảm mà bộ kiểm vẫn cho qua. Không bắt `đ` — có hay không thì
/// cũng là một con số, và `9 đ` với `9 ngày` khác nhau ở **loại** của số liệu
/// chứ không ở cách trích.
final RegExp _mau =
    RegExp(r'(-|−)?(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d+))?\s*(%)?');

/// Mọi chuỗi số trong [cau], đã chuẩn hoá về `double`, theo thứ tự trong câu.
///
/// Ngày tách **trước**: `12/09` không được thành hai con số 12 và 9. Ngày hợp lệ
/// được thay bằng khoảng trắng **cùng độ dài** — giữ vị trí để kết quả theo thứ
/// tự câu, và để hai cụm số hai bên không dính thành một số mới. Dạng khớp mẫu
/// mà không hợp lệ (`45/13`) để nguyên cho phép trích số: không phải ngày thì
/// là số, và số không có trong gói thì bị chặn.
List<SoTrich> trichSo(String cau) {
  final theoViTri = <(int, SoTrich)>[];
  final conLai = StringBuffer();
  var daChep = 0;
  for (final m in _mauNgay.allMatches(cau)) {
    final ngay = int.parse(m.group(1)!);
    final thang = int.parse(m.group(2)!);
    if (ngay < 1 || ngay > 31 || thang < 1 || thang > 12) continue;
    theoViTri.add((
      m.start,
      SoTrich(
        (thang * 100 + ngay).toDouble(),
        laPhanTram: false,
        laNgay: true,
        nam: m.group(3) == null ? null : int.parse(m.group(3)!),
      ),
    ));
    conLai
      ..write(cau.substring(daChep, m.start))
      ..write(' ' * (m.end - m.start));
    daChep = m.end;
  }
  conLai.write(cau.substring(daChep));
  // Số bằng chữ tách TRƯỚC chữ số, cũng thay bằng khoảng trắng cùng độ dài.
  final sauNgay = conLai.toString();
  final sauChu = StringBuffer();
  daChep = 0;
  for (final m in _mauSoChu.allMatches(sauNgay)) {
    theoViTri.add((
      m.start,
      SoTrich(_giaTriSoChu(m.group(0)!), laPhanTram: false),
    ));
    sauChu
      ..write(sauNgay.substring(daChep, m.start))
      ..write(' ' * (m.end - m.start));
    daChep = m.end;
  }
  sauChu.write(sauNgay.substring(daChep));
  for (final m in _mau.allMatches(sauChu.toString())) {
    theoViTri.add((
      m.start,
      SoTrich(
        (m.group(1) == null ? 1 : -1) *
            double.parse(
              '${m.group(2)!.replaceAll('.', '')}.${m.group(3) ?? '0'}',
            ),
        laPhanTram: m.group(4) != null,
      ),
    ));
  }
  theoViTri.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final x in theoViTri) x.$2];
}

bool _khop(SoTrich x, SoLieu s) {
  // Ngày chỉ khớp mục ngày và ngược lại — "còn 12 ngày" không được lọt nhờ
  // một ngày 12/09 có thật, ngày 12/09 không được lọt nhờ số đếm 912.
  if (x.laNgay != (s.loai == LoaiSo.ngayThang)) return false;
  final lech = (x.giaTri - s.soTho).abs();
  return switch (s.loai) {
    // Nửa đồng: đuôi lẻ của double, cùng ngưỡng với đối soát số dư.
    LoaiSo.tien => !x.laPhanTram && lech <= 0.5,
    // Một chữ số thập phân (G2) → sai số làm tròn tối đa 0,05.
    LoaiSo.phanTram => x.laPhanTram && lech <= 0.05,
    LoaiSo.soNgay || LoaiSo.soDem => !x.laPhanTram && lech == 0,
    // Ngày và tháng phải trùng; năm chỉ so khi câu có ghi năm.
    LoaiSo.ngayThang => _cungNgay(x, s.soTho.round()),
  };
}

bool _cungNgay(SoTrich x, int soTho) =>
    soTho % 10000 == x.giaTri.round() &&
    (x.nam == null || x.nam == soTho ~/ 10000);

final RegExp _coChuCai = RegExp(r'\p{L}', unicode: true);
final RegExp _coChuSo = RegExp(r'\d');
final RegExp _motChuHoacSo = RegExp(r'^[\p{L}\p{N}]$', unicode: true);

/// Mọi chuỗi số trong [cau], **trừ** chữ số nằm trong một tên đối tượng mà
/// [goi] mang theo (`GoiSo.tenDoiTuong`) — định nghĩa duy nhất của "con số
/// trong một câu trả lời". Bộ kiểm số, `kiemNhan` và `theCuaCau` cùng đọc nó,
/// nên ba nơi không bao giờ nói hai chuyện khác nhau về cùng một câu.
///
/// Chỉ tên xuất hiện **trọn**: khớp theo `normalizeCategoryName` (không phân
/// biệt hoa thường, NFC) và đứng **trọn từ** — ký tự liền trước và liền sau
/// không phải chữ hay số. Một mẩu tên đứng riêng ("9" của `Tiền nhà T9`), hay
/// một tên tình cờ trùng giữa một từ khác ("an 5" trong "Ban 5"), vẫn bị trích
/// như con số: nới hơn thế là mở cửa cho số bịa.
///
/// Tên **không có chữ cái nào** (`2027`) không được miễn — không phân biệt
/// được với một con số. Tên dài bỏ trước, để `Quỹ 9` không cắt mất phần đầu
/// của `Quỹ 9 2026`.
///
/// Tên là dữ liệu của gói, không do mô hình sinh, nên phép bỏ này không cho
/// mô hình cách nào giấu một con số bịa.
List<SoTrich> trichSoNgoaiTen(String cau, List<GoiSo> goi) {
  final ten = <String>{
    for (final g in goi)
      for (final t in g.tenDoiTuong)
        if (_coChuSo.hasMatch(t) && _coChuCai.hasMatch(t))
          normalizeCategoryName(t),
  }.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  if (ten.isEmpty) return trichSo(cau);
  // Chuẩn hoá cả câu chỉ để TRÍCH SỐ: chữ thường, NFC và gom khoảng trắng
  // không đổi chữ số nào, cũng không đổi dấu chấm, phẩy, trừ hay phần trăm.
  var con = normalizeCategoryName(cau);
  for (final t in ten) {
    con = _boTenTron(con, t);
  }
  return trichSo(con);
}

/// Thay mọi lần [ten] đứng trọn từ trong [cau] bằng một khoảng trắng — khoảng
/// trắng để hai cụm số hai bên không dính thành một số mới.
String _boTenTron(String cau, String ten) {
  final kq = StringBuffer();
  var daChep = 0;
  var tim = 0;
  while (true) {
    final i = cau.indexOf(ten, tim);
    if (i < 0) break;
    final j = i + ten.length;
    final truoc = i == 0 ? null : cau.substring(0, i).runes.last;
    final sau = j >= cau.length ? null : cau.substring(j).runes.first;
    if (_laChuHoacSo(truoc) || _laChuHoacSo(sau)) {
      tim = i + 1;
      continue;
    }
    kq
      ..write(cau.substring(daChep, i))
      ..write(' ');
    daChep = j;
    tim = j;
  }
  kq.write(cau.substring(daChep));
  return kq.toString();
}

bool _laChuHoacSo(int? ma) =>
    ma != null && _motChuHoacSo.hasMatch(String.fromCharCode(ma));

/// Mọi [SoLieu] của mọi gói trong [goi] khớp con số [x] — cùng phép khớp với
/// `kiemSo`, mở ra cho `kiemNhan` (kiểm **nhãn** của số) dùng lại thay vì
/// chép phép khớp thành bản thứ hai. Rỗng nghĩa là số bịa.
List<SoLieu> soLieuKhop(SoTrich x, List<GoiSo> goi) => [
      for (final g in goi)
        for (final s in g.soLieu)
          if (_khop(x, s)) s,
    ];

/// `true` khi MỌI số trong [cau] khớp một [SoLieu] của [goi]. Câu không có số
/// nào thì lọt — không có gì để bịa.
bool kiemSo(String cau, GoiSo goi) => trichSoNgoaiTen(cau, [goi])
    .every((x) => goi.soLieu.any((s) => _khop(x, s)));

/// Bản cho **hỏi đáp tự do** (P3 Task 8), nơi câu trả lời được phép rút số từ
/// nhiều màn cùng lúc: mỗi số phải khớp một [SoLieu] của **một gói bất kỳ**.
///
/// ⚠️ Đây **không** phải `goi.any(kiemSo)`. Viết như thế là đòi cả câu nằm gọn
/// trong một gói, nên một câu hoàn toàn đúng kiểu *"tháng này chi 1.200.000 đ,
/// mục tiêu còn thiếu 3.000.000 đ"* sẽ bị chặn — im lặng, vì người gọi chỉ
/// thấy câu rơi về mẫu.
bool kiemSoNhieuGoi(String cau, List<GoiSo> goi) =>
    trichSoNgoaiTen(cau, goi).every(
      (x) => goi.any((g) => g.soLieu.any((s) => _khop(x, s))),
    );
