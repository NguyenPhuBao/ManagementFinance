/// Test quét `lib/` thứ **29**: `features/*/domain/` không tạo vòng phụ thuộc MỚI giữa các mảng.
///
/// Đồ thị cấp mảng: cạnh `A->B` khi một tệp dưới `lib/features/A/domain/` có chỉ thị `import` / `export` / `part` (đọc qua
/// `test/helpers/chi_thi_dart.dart`) tới một tệp bất kỳ dưới `lib/features/B/` — mọi tầng của B, kể cả `data/models/` —
/// với A ≠ B. Nguồn CHỈ là `domain/`: cạnh từ tầng `application/` (vd. `bill/application/bill_payment_conflict_resolver.dart →
/// notification/domain`) không thuộc phạm vi quét này.
///
/// **Luật (một luật trên CẠNH):** một cạnh `A->B` nằm trên một vòng ⇔ A và B cùng một thành phần liên thông mạnh (B đi ngược
/// về được A). Mọi cạnh có hai đầu cùng một thành phần liên thông mạnh lớn hơn một mảng phải nằm trong [conCho]; cạnh trong
/// [conCho] mà không còn tồn tại hoặc không còn nằm trên vòng thì đỏ "đã gỡ — rút". Luật này bắt MỌI vòng mới: cặp hai chiều
/// mới, vòng dài kéo thêm mảng vào cụm, cạnh mới giữa hai mảng đã trong cụm (thiết kế "cặp + cụm" bị bỏ vì mù ca cuối).
/// Giới hạn: luật đếm CẠNH, không đếm tệp — thêm một tệp import dọc một cạnh xuôi chiều đã có (vd. thêm import
/// `analytics → bill`) không đỏ, vì không tạo vòng mới.
///
/// **Vì sao:** mảng phụ thuộc vòng thì không tách và không thay được mảng nào ra khỏi vòng; luật thuần phải nằm ở mảng của
/// DỮ LIỆU nó đọc (khuôn `bill/domain/bill_nhac_truoc.dart`, 2026-10-16: `billLeadDays` dời khỏi `notification` để gỡ vòng
/// `bill` ↔ `notification`).
///
/// [conCho] — **rỗng từ 2026-10-16**. Đo gốc cùng ngày: mười cạnh của cụm {analytics, bill, category, transaction} — bốn
/// cặp hai chiều (`analytics|category`, `analytics|transaction`, `bill|transaction`, `category|transaction`) và hai cạnh
/// một chiều trong cụm (`analytics->bill`, `category->bill`); gỡ hết theo spec `2026-10-16-go-vong-mang-domain-design.md`
/// (chiều chuẩn `analytics → bill → transaction → category`): lát 1 rút năm (`khoan_vao_thong_ke`, `LuaChonLoc` về
/// transaction), lát 2 rút ba (`kGhiChuTraHoaDon` về `transaction_owner`, `khoan_lap` về bill), lát 3 rút hai
/// (`laGhiChuMay`, `mauHocTu`, `mauSoTienTu`, `gan_hang_loat` về transaction; `hopLeTheoChieu` về `category_classify`;
/// `kDungSaiTien` ra `core/utils`). Giữ hằng làm khuôn danh sách chờ của quét 22 / 25 / 27 / 28: thêm vào là mở lại nợ
/// (phải có lý do + ngày).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../helpers/chi_thi_dart.dart';

/// Cạnh `'nguồn->đích'` còn nằm trên vòng — rỗng từ 2026-10-16 (ba lát gỡ cụm, xem docstring).
const conCho = <String>{};

String _duong(FileSystemEntity e) => e.path.replaceAll('\\', '/');

/// Mọi tệp `.dart` dưới `lib/features/*/domain/` (kể cả thư mục con).
List<File> _tepDomain() => [
      for (final f in Directory('lib/features')
          .listSync(recursive: true)
          .whereType<File>())
        if (_duong(f).endsWith('.dart') && _duong(f).contains('/domain/')) f,
    ];

/// Tên mảng của đường `lib/features/<mảng>/…`; `null` nếu đường không nằm dưới `features/`.
String? _mang(String duongLib) {
  const goc = 'lib/features/';
  if (!duongLib.startsWith(goc)) return null;
  final phan = duongLib.substring(goc.length).split('/');
  return phan.length >= 2 ? phan.first : null;
}

class _DoThi {
  final Map<String, Set<String>> ke = {};
  final Map<String, List<String>> chungCu = {}; // 'a->b' → ['tệp nguồn → đích']
  int soTepDomain = 0;
}

_DoThi _dung() {
  final g = _DoThi();
  final tep = _tepDomain();
  g.soTepDomain = tep.length;
  for (final f in tep) {
    final d = _duong(f);
    final a = _mang(d);
    if (a == null) continue;
    g.ke.putIfAbsent(a, () => <String>{});
    for (final duong in duongChiThi(f.readAsStringSync())) {
      final dich = dichTrongLib(d, duong);
      if (dich == null) continue;
      final b = _mang(dich);
      if (b == null || b == a) continue;
      g.ke[a]!.add(b);
      g.ke.putIfAbsent(b, () => <String>{});
      g.chungCu.putIfAbsent('$a->$b', () => []).add('$d → $dich');
    }
  }
  return g;
}

/// Tarjan: trả về từng thành phần liên thông mạnh.
List<Set<String>> _thanhPhan(Map<String, Set<String>> ke) {
  var chiSo = 0;
  final idx = <String, int>{};
  final thap = <String, int>{};
  final ngan = <String>[];
  final trongNgan = <String>{};
  final kq = <Set<String>>[];
  void duyet(String v) {
    idx[v] = thap[v] = chiSo++;
    ngan.add(v);
    trongNgan.add(v);
    for (final w in ke[v] ?? const <String>{}) {
      if (!idx.containsKey(w)) {
        duyet(w);
        thap[v] = thap[v]! < thap[w]! ? thap[v]! : thap[w]!;
      } else if (trongNgan.contains(w)) {
        thap[v] = thap[v]! < idx[w]! ? thap[v]! : idx[w]!;
      }
    }
    if (thap[v] == idx[v]) {
      final tp = <String>{};
      String w;
      do {
        w = ngan.removeLast();
        trongNgan.remove(w);
        tp.add(w);
      } while (w != v);
      kq.add(tp);
    }
  }

  for (final v in ke.keys.toList()) {
    if (!idx.containsKey(v)) duyet(v);
  }
  return kq;
}

void main() {
  test('tiền đề: phép quét thấy đủ mảng, tệp domain và cạnh (chạy từ src/Client-app)',
      () {
    final g = _dung();
    final soMang = Directory('lib/features').listSync().whereType<Directory>().length;
    expect(soMang, greaterThanOrEqualTo(14),
        reason: 'Phải thấy ≥ 14 mảng dưới lib/features (đo 2026-10-16: 14; hai mảng ai_chat, profile không có domain/).');
    expect(g.soTepDomain, greaterThan(80),
        reason: 'Phải thấy features/*/domain (đo 2026-10-16 sau gỡ cụm: 180 tệp) — đang quét sai thư mục.');
    expect(g.chungCu.length, greaterThan(20),
        reason: 'Phải thấy > 20 cạnh mảng (đo 2026-10-16 sau gỡ cụm: 26) — đọc chỉ thị hỏng thì đồ thị rỗng, luật xanh im lặng.');
  });

  test(
      'domain không tạo vòng mới giữa các mảng — mọi cạnh trên vòng phải nằm trong conCho rút dần',
      () {
    final g = _dung();
    final thanhPhan = _thanhPhan(g.ke).where((t) => t.length > 1).toList();
    final cumCua = <String, Set<String>>{
      for (final t in thanhPhan)
        for (final m in t) m: t,
    };
    final canhTrenVong = <String>{
      for (final e in g.chungCu.keys)
        if (cumCua[e.split('->')[0]] != null &&
            cumCua[e.split('->')[0]]!.contains(e.split('->')[1]))
          e,
    };
    final loi = <String>[];
    for (final e in canhTrenVong.toList()..sort()) {
      if (conCho.contains(e)) continue;
      final cum = (cumCua[e.split('->')[0]]!.toList()..sort()).join(', ');
      final tep = g.chungCu[e]!.take(4).map((s) => '    $s').join('\n');
      loi.add("Cạnh '$e' nằm trên một vòng (thành phần liên thông {$cum}):\n$tep\n"
          '  Hướng sửa: dời luật thuần về mảng của dữ liệu nó đọc (khuôn bill/domain/bill_nhac_truoc.dart), '
          'đừng kéo thêm cạnh vào cụm.');
    }
    for (final c in conCho.toList()..sort()) {
      if (!canhTrenVong.contains(c)) {
        loi.add("$c: đã gỡ — rút khỏi conCho (cạnh không còn tồn tại hoặc không còn nằm trên vòng).");
      }
    }
    expect(loi, isEmpty,
        reason: 'Vòng phụ thuộc giữa các mảng ở domain/ chỉ được giảm, không được thêm:\n${loi.join('\n')}');
  });
}
