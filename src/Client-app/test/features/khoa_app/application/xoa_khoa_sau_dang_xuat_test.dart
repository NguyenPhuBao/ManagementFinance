import 'dart:async';

import 'package:flowmoney/features/khoa_app/application/khoa_app_service.dart';
import 'package:flowmoney/features/khoa_app/application/xoa_khoa_sau_dang_xuat.dart';
import 'package:flowmoney/features/khoa_app/data/khoa_app_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/khoa_app_gia.dart';

void main() {
  late InMemoryKhoaAppStore kho;
  late KenhGia kenh;
  late KhoaAppService sv;

  setUp(() async {
    kho = InMemoryKhoaAppStore();
    kenh = KenhGia();
    sv = KhoaAppService(store: kho, kenh: kenh, bam: bamNhanh);
    await sv.datPin(10, '246810');
  });

  test('CHƯA đăng xuất xong thì chưa xoá; xong rồi mới xoá cấu hình + khoá Keystore', () async {
    final xong = Completer<Object?>();
    final f = xoaKhoaSauDangXuat(daDangXuat: xong.future, idaccount: 10, service: sv);
    await Future<void>.delayed(Duration.zero);
    expect(await kho.doc(10), isNotNull,
        reason: 'đăng xuất chưa xong (token còn): xoá PIN lúc này là mở lạnh vào thẳng app không cần mật khẩu');
    xong.complete(null);
    await f;
    expect(await kho.doc(10), isNull);
    expect(kenh.soLanXoa, 1);
  });

  test('đăng xuất không bao giờ tới (luồng lỗi) → giữ khoá, không ném', () async {
    final f = xoaKhoaSauDangXuat(daDangXuat: Future<Object?>.error(StateError('x')), idaccount: 10, service: sv);
    await f;
    expect(await kho.doc(10), isNotNull);
  });

  test('không biết tài khoản → không làm gì', () async {
    await xoaKhoaSauDangXuat(daDangXuat: Future<Object?>.value(null), idaccount: null, service: sv);
    expect(await kho.doc(10), isNotNull);
  });
}
