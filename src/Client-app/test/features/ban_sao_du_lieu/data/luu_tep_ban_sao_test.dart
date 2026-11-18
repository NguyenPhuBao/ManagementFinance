import 'dart:typed_data';

import 'package:flowmoney/features/analytics/data/datasources/luu_tep_platform.dart';
import 'package:flowmoney/features/ban_sao_du_lieu/data/datasources/ban_sao_du_lieu_api.dart';
import 'package:flowmoney/features/ban_sao_du_lieu/data/luu_tep_ban_sao.dart';
import 'package:flutter_test/flutter_test.dart';

class _LuuGia extends LuuTepPlatform {
  _LuuGia(this.traVe);
  final String? traVe;
  String? ten;
  String? mime;
  @override
  Future<String?> luuVaoTaiVe({required String ten, required String mime, required Uint8List bytes}) async {
    this.ten = ten;
    this.mime = mime;
    return traVe;
  }
}

void main() {
  final tep = TepTaiVe(ten: 'a.csv', mime: 'text/csv', bytes: Uint8List.fromList([1, 2]));

  test('Tải về được → trả đường dẫn, KHÔNG mở chia sẻ', () async {
    final p = _LuuGia('Tải về/a.csv');
    var chiaSe = 0;
    final noi = await LuuTepBanSao(luuTep: p, chiaSe: (_) async => chiaSe++).luu(tep);
    expect(noi, 'Tải về/a.csv');
    expect((p.ten, p.mime), ('a.csv', 'text/csv'));
    expect(chiaSe, 0);
  });

  test('Tải về trả null → mở chia sẻ, trả null', () async {
    var chiaSe = 0;
    final noi = await LuuTepBanSao(luuTep: _LuuGia(null), chiaSe: (_) async => chiaSe++).luu(tep);
    expect(noi, isNull);
    expect(chiaSe, 1);
  });
}
