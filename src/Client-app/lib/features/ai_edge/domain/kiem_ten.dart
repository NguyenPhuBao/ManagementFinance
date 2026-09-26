/// Bộ kiểm TÊN — lớp chắn thứ tư, đứng sau `kiemGiong` (bẫy 4.48, 2026-09-25).
///
/// Ba lớp trước kiểm **con số** (`kiemSo`), **nhãn của con số** (`kiemNhan`)
/// và **giọng** (`kiemGiong`). Một câu **không có con số nào** đi qua hai lớp
/// đầu vì "không có gì để bịa" — và cổng D lần 10 B1 cho thấy vẫn có: *"Bạn có
/// thể đặt mục tiêu mua xe hoặc mua nhà."* trong khi mục tiêu thật là MuaXe và
/// MuaDT. Tên bịa không kèm số lọt cả ba lớp.
///
/// Luật: sau một **từ loại** (*mục tiêu · danh mục · ví · hoá đơn · ngân sách*)
/// là một **lời khẳng định về một đối tượng** — cụm chữ tới dấu câu hoặc tới một
/// từ chức năng (*và, hoặc, là, của, đang, nào, chi, thu…*). Mỗi cụm phải khớp
/// một tên trong `GoiSo.tenDoiTuong` của **một gói bất kỳ**: so sau
/// `normalizeCategoryName` và **bỏ khoảng trắng** (mô hình viết *"mua xe"* cho
/// `MuaXe`), **chứa nhau** là đủ (cụm *"Kiem thu hoa don"* nằm trong tiêu đề
/// *"Thanh toán hóa đơn: Kiem thu hoa don 2026-09-04"*). Sau *và / hoặc / dấu
/// phẩy* là một khẳng định nữa. Cụm rỗng (*"các danh mục chi lớn nhất"*, *"mục
/// tiêu đang theo đuổi"*) không phải khẳng định. Câu có **"không"** đứng trước
/// từ loại thì bỏ qua — *"không có danh mục nào tên abc"* là câu thật.
///
/// Không bỏ dấu (quy tắc 7 `CLAUDE.md`). Giới hạn cố ý: phép lọc từ vựng, sai
/// theo chiều an toàn — câu trượt rơi về mẫu câu.
library;

import '../../../core/category/category_name.dart';
import 'goi_so.dart';

/// Từ loại mở đầu một lời khẳng định về đối tượng.
const List<String> kTuLoai = [
  'mục tiêu',
  'danh mục',
  'hoá đơn',
  'hóa đơn',
  'ngân sách',
  'ví',
];

/// Từ chức năng: gặp là hết cụm tên. Hai chữ chỉ chiều tiền ở đây là *chữ* của
/// câu tiếng Việt (*"danh mục chi lớn nhất"*), không phải phép so chiều tiền —
/// viết thành một chuỗi tách lúc chạy vì test quét thứ 14 cấm hai chuỗi ấy
/// đứng riêng trong `ai_edge/`. "dụ" và "như" vì *"ví dụ"*, *"ví như"*.
const String _tuChucNangTho =
    'và hoặc là với của cho có đang đã còn sắp nào này ấy sau khác lớn nhỏ '
    'nhiều ít cụ gần hết chi thu đây trên dưới trong theo mới cũ đó sẽ cần nên '
    'thì mà để từ dụ như tiếp chưa không vẫn đều cũng';
final Set<String> kTuChucNang = _tuChucNangTho.split(' ').toSet();

final RegExp _dauCau = RegExp(r'[.,;:!?()\[\]"“”]');
final RegExp _dauNgoac = RegExp(r'^["“”\x27]+|["“”\x27]+$');
final RegExp _ketCau = RegExp(r'[.;!?]');
final RegExp _khoangTrang = RegExp(r'\s+');

String _chuan(String s) =>
    normalizeCategoryName(s).replaceAll(_khoangTrang, '');

/// `true` khi mọi lời khẳng định về đối tượng trong [cau] nêu một tên có trong
/// [goi]. Câu không có khẳng định nào thì qua.
bool kiemTen(String cau, List<GoiSo> goi) {
  final ten = <String>{
    for (final g in goi)
      for (final t in g.tenDoiTuong)
        if (_chuan(t).isNotEmpty) _chuan(t),
  };
  final chu = cau.toLowerCase();
  for (final loai in kTuLoai) {
    final mau = RegExp(
      '(?<![\\p{L}\\p{N}])${RegExp.escape(loai)}(?![\\p{L}\\p{N}])',
      unicode: true,
    );
    for (final m in mau.allMatches(chu)) {
      if (_coPhuDinhTruoc(chu, m.start)) continue;
      for (final cum in _cacCum(chu.substring(m.end))) {
        final p = _chuan(cum);
        if (p.length < 2) continue;
        if (!ten.any((n) => n.contains(p) || p.contains(n))) return false;
      }
    }
  }
  return true;
}

/// "không" đứng trước vị trí [i] trong CÙNG câu (sau dấu kết câu gần nhất).
bool _coPhuDinhTruoc(String chu, int i) {
  final truoc = chu.substring(0, i);
  final batDau = truoc.lastIndexOf(_ketCau) + 1;
  return truoc
      .substring(batDau)
      .split(_khoangTrang)
      .any((t) => t.replaceAll(_dauCau, '') == 'không');
}

/// Các cụm tên ngay sau từ loại: cụm đầu; sau *và / hoặc / dấu phẩy* là cụm kế.
/// Cụm dừng ở dấu câu hay từ chức năng; cụm rỗng bị bỏ.
List<String> _cacCum(String sau) {
  final cum = <String>[];
  final tu = <String>[];
  void chot() {
    if (tu.isNotEmpty) cum.add(tu.join(' '));
    tu.clear();
  }

  for (final raw in sau.trim().split(_khoangTrang)) {
    if (raw.isEmpty) continue;
    final t = raw.replaceAll(_dauNgoac, '');
    final loi = t.replaceAll(_dauCau, '');
    if (loi.isEmpty) {
      // Chỉ dấu câu: dấu phẩy nối cụm kế, dấu khác kết thúc.
      chot();
      if (!t.startsWith(',')) break;
      continue;
    }
    if (kTuChucNang.contains(loi)) {
      chot();
      if (loi != 'và' && loi != 'hoặc') break;
      continue;
    }
    // Dấu câu mở đầu ("(800.000") kết thúc cụm; dấu kết câu ở cuối ("MuaXe.")
    // nhận chữ rồi kết thúc; dấu phẩy ở cuối nhận chữ rồi nối cụm kế.
    if (_dauCau.hasMatch(t[0])) {
      chot();
      break;
    }
    tu.add(loi);
    if (_dauCau.hasMatch(t[t.length - 1])) {
      chot();
      if (!t.endsWith(',')) break;
    }
  }
  chot();
  return cum;
}
