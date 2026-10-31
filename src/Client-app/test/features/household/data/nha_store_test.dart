import 'package:flowmoney/features/household/data/models/nha_cua_toi.dart';
import 'package:flowmoney/features/household/data/nha_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/household_api_gia.dart';

void main() {
  test('khoá theo tài khoản', () {
    expect(SecureStorageNhaStore.khoa(18), 'nha_tai_khoan_18');
  });

  test('kho RAM: hai tài khoản không lẫn nhau', () async {
    final kho = InMemoryNhaStore();
    await kho.ghi(18, nhaCuaToiTuJson(nhaJson(), nhanLuc: DateTime.utc(2026, 10, 24)));
    expect((await kho.doc(18))!.nha!.id, 12);
    expect(await kho.doc(25), isNull);
  });

  test('InMemory: dấu vắng là null; ghi null là xoá', () async {
    final k = InMemoryNhaStore();
    expect(await k.docDauXuLy(18), isNull);
    await k.ghiDauXuLy(18, 12);
    expect(await k.docDauXuLy(18), 12);
    await k.ghiDauXuLy(18, null);
    expect(await k.docDauXuLy(18), isNull);
    expect(await k.docDauXuLy(19), isNull, reason: 'theo tài khoản');
  });
}
