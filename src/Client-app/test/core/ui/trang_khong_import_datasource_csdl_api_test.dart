/// Test quét `lib/` thứ **31** — trang không cầm datasource bọc CSDL / API backend (luật người dùng chốt 2026-10-19, mục 8
/// `KIEN_TRUC_CLIENT_APP.md`; báo cáo soát kiến trúc 2026-10-18 mục 3).
///
/// Luật: tệp dưới `lib/features/*/presentation/` và `lib/shared/` (1) không import tệp nào dưới `data/datasources/` mà tệp
/// ấy import `core/database/`, `core/api/` hoặc gói Dio — đọc / ghi CSDL và gọi backend đi qua repository hoặc nguồn DI của
/// mảng; (2) không import gói Dio. Cổng NỀN TẢNG dưới `datasources/` (kênh sang Kotlin, tệp cục bộ, gói hệ điều hành) thì
/// trang được gọi thẳng — chúng không chạm hai thứ trên.
///
/// `conCho`: chỗ lệch đo được lúc viết quét, gỡ dần — chỉ được bớt, không được thêm.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../helpers/chi_thi_dart.dart';

const conCho = <String>{
  'lib/features/ai_chat/presentation/pages/ai_chat_page.dart',
  'lib/features/notification/presentation/pages/notification_center_page.dart',
};

final _goiDio = RegExp(r'^package:dio/');

bool _laDatasourceCsdlApi(String dich) {
  if (!dich.contains('/data/datasources/')) return false;
  final f = File(dich);
  if (!f.existsSync()) return false;
  for (final d in duongChiThi(f.readAsStringSync())) {
    if (_goiDio.hasMatch(d)) return true;
    final t = dichTrongLib(dich, d);
    if (t != null && (t.startsWith('lib/core/database/') || t.startsWith('lib/core/api/'))) return true;
  }
  return false;
}

Map<String, List<String>> _viPham() {
  final ra = <String, List<String>>{};
  for (final goc in ['lib/features', 'lib/shared']) {
    for (final f in Directory(goc).listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final tep = f.path.replaceAll(r'\', '/');
      if (goc == 'lib/features' && !tep.contains('/presentation/')) continue;
      for (final d in duongChiThi(f.readAsStringSync())) {
        final lyDo = _goiDio.hasMatch(d)
            ? 'import gói Dio ($d)'
            : (() {
                final t = dichTrongLib(tep, d);
                return t != null && _laDatasourceCsdlApi(t) ? 'import datasource bọc CSDL / API ($t)' : null;
              })();
        if (lyDo != null) (ra[tep] ??= []).add(lyDo);
      }
    }
  }
  return ra;
}

void main() {
  test('trang không import datasource bọc CSDL / API backend, không import gói Dio', () {
    final moi = {for (final e in _viPham().entries) if (!conCho.contains(e.key)) e.key: e.value};
    expect(moi, isEmpty,
        reason: 'Đọc / ghi qua repository (hoặc nguồn DI) của mảng. Cổng nền tảng thì được gọi thẳng — xem mục 8 '
            'KIEN_TRUC_CLIENT_APP.md. Thấy: $moi');
  });

  test('conCho còn đúng: mỗi tệp trong đó vẫn còn lệch (gỡ xong thì xoá khỏi danh sách)', () {
    final vp = _viPham();
    for (final tep in conCho) {
      expect(vp.containsKey(tep), isTrue, reason: '"$tep" đã sạch — xoá nó khỏi conCho.');
    }
  });

  test('bộ nhận diện thấy đúng loại datasource (ca canh bộ đọc)', () {
    expect(_laDatasourceCsdlApi('lib/features/notification/data/datasources/nhat_ky_thong_bao.dart'), isTrue);
    expect(_laDatasourceCsdlApi('lib/features/ai_chat/data/datasources/tro_ly_online_remote_data_source.dart'), isTrue);
    expect(_laDatasourceCsdlApi('lib/features/notification/data/datasources/kenh_bien_dong.dart'), isFalse);
    // Cổng kênh `flowmoney/luu_anh` — từ Step 2b bộ tải ảnh Dio trần nằm ở tệp riêng, nên cổng không import Dio.
    expect(File('lib/features/premium/data/datasources/luu_anh_qr.dart').existsSync(), isTrue);
    expect(_laDatasourceCsdlApi('lib/features/premium/data/datasources/luu_anh_qr.dart'), isFalse);
  });
}
