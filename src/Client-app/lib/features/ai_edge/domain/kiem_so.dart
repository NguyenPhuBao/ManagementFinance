/// Bộ kiểm số — điều kiện 10 của mục 13 bản đánh giá: **mọi** con số trong câu
/// phải có trong gói số; sai thì người gọi rơi về mẫu câu.
///
/// Dùng cho cả hai bản diễn giải: mẫu câu (mọi mẫu phải tự qua được bộ kiểm,
/// nếu không P3 sẽ rơi về một câu mà bộ kiểm cũng chặn — có ca test canh ở từng
/// gói số) và SLM (P3). Đây là lớp chắn **duy nhất** giữa mô hình và người
/// dùng, nên nó không được nới vì mô hình lớn hơn (spec mục 4.4).
///
/// Giới hạn cố ý: ngày tháng (`12/09`) cũng là số. Mẫu câu của app không in
/// ngày; nếu sau này gói số cần ngày thì thêm `LoaiSo.ngayThang` chứ đừng nới
/// regex.
///
/// ⚠️ Chữ số nằm **trong tên một đối tượng** của gói (`Tiền nhà T9`) không phải
/// con số — [trichSoNgoaiTen] bỏ những tên ấy khỏi câu trước khi trích (bước
/// 1c, 2026-09-23). Trước đó 5/9 hoá đơn của tài khoản 10 mang chữ số trong
/// tên, và mọi câu đúng nêu tên chúng đều bị chặn, im lặng.
library;

import '../../../core/category/category_name.dart';
import 'goi_so.dart';

class SoTrich {
  final double giaTri;
  final bool laPhanTram;
  const SoTrich(this.giaTri, {required this.laPhanTram});
}

/// Nhóm 1: dấu âm (`-` hoặc `−`); nhóm 2: phần nguyên có chấm nghìn
/// (`2.100.000`) hoặc số trần; nhóm 3: phần thập phân sau **phẩy**; nhóm 4: hậu
/// tố `%`. Dấu âm phải bắt được vì `soPhanTram` giữ dấu (`-8,3%`): mất dấu là
/// đảo nghĩa tăng/giảm mà bộ kiểm vẫn cho qua. Không bắt `đ` — có hay không thì
/// cũng là một con số, và `9 đ` với `9 ngày` khác nhau ở **loại** của số liệu
/// chứ không ở cách trích.
final RegExp _mau =
    RegExp(r'(-|−)?(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d+))?\s*(%)?');

/// Mọi chuỗi số trong [cau], đã chuẩn hoá về `double`.
List<SoTrich> trichSo(String cau) => [
      for (final m in _mau.allMatches(cau))
        SoTrich(
          (m.group(1) == null ? 1 : -1) *
              double.parse(
                '${m.group(2)!.replaceAll('.', '')}.${m.group(3) ?? '0'}',
              ),
          laPhanTram: m.group(4) != null,
        ),
    ];

bool _khop(SoTrich x, SoLieu s) {
  final lech = (x.giaTri - s.soTho).abs();
  return switch (s.loai) {
    // Nửa đồng: đuôi lẻ của double, cùng ngưỡng với đối soát số dư.
    LoaiSo.tien => !x.laPhanTram && lech <= 0.5,
    // Một chữ số thập phân (G2) → sai số làm tròn tối đa 0,05.
    LoaiSo.phanTram => x.laPhanTram && lech <= 0.05,
    LoaiSo.soNgay || LoaiSo.soDem => !x.laPhanTram && lech == 0,
  };
}

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
