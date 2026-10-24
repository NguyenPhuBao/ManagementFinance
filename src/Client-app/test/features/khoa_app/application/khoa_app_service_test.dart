import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flowmoney/features/khoa_app/application/khoa_app_service.dart';
import 'package:flowmoney/features/khoa_app/data/datasources/kenh_sinh_trac.dart';
import 'package:flowmoney/features/khoa_app/data/khoa_app_store.dart';
import 'package:flowmoney/features/khoa_app/domain/luat_khoa_app.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/khoa_app_gia.dart';

void main() {
  late InMemoryKhoaAppStore kho;
  late KenhGia kenh;
  late DateTime nay;
  late KhoaAppService sv;

  setUp(() {
    kho = InMemoryKhoaAppStore();
    kenh = KenhGia();
    nay = DateTime(2026, 10, 24, 21);
    sv = KhoaAppService(store: kho, kenh: kenh, bam: bamNhanh, clock: () => nay);
  });

  test('datPin: salt 16 byte ngẫu nhiên, mặc định 30 giây, không cất PIN thô', () async {
    await sv.datPin(10, '246810');
    final c = (await kho.doc(10))!;
    expect(base64Decode(c.salt), hasLength(16));
    expect(c.tuKhoaSau, TuKhoaSau.giay30);
    expect(jsonEncode(c.toJson()), isNot(contains('246810')));
  });

  test('datPin từ chối PIN không đủ 6 số', () async {
    expect(() => sv.datPin(10, '12345'), throwsArgumentError);
  });

  test('kiemPin đúng → dung; sai → đếm; lần 5 có mốc chờ 30 s, GHI xuống kho', () async {
    await sv.datPin(10, '246810');
    expect((await sv.kiemPin(10, '246810')).dung, isTrue);
    for (var i = 1; i <= 4; i++) {
      final k = await sv.kiemPin(10, '000000');
      expect([k.dung, k.soLanSai, k.choDen], [false, i, null]);
    }
    final k5 = await sv.kiemPin(10, '000000');
    expect(k5.choDen, nay.add(const Duration(seconds: 30)));
    expect((await kho.doc(10))!.soLanSai, 5, reason: 'đếm phải nằm trong kho — tắt app không xoá được lần sai');
  });

  test('đang chờ: PIN đúng cũng bị chặn; hết chờ thì đúng mở và đếm về 0', () async {
    await sv.datPin(10, '246810');
    for (var i = 0; i < 5; i++) {
      await sv.kiemPin(10, '000000');
    }
    final k = await sv.kiemPin(10, '246810');
    expect([k.dung, k.dangCho], [false, true]);
    nay = nay.add(const Duration(seconds: 30));
    expect((await sv.kiemPin(10, '246810')).dung, isTrue);
    expect((await kho.doc(10))!.soLanSai, 0);
  });

  test('kho hỏng khi ghi lần sai → ném (không được báo "sai" mà chưa ghi)', () async {
    await sv.datPin(10, '246810');
    kho.hongKhiGhi = true;
    expect(() => sv.kiemPin(10, '000000'), throwsStateError);
  });

  test('đổi PIN giữ mức tự khoá + vân tay', () async {
    await sv.datPin(10, '246810');
    await sv.datTuKhoaSau(10, TuKhoaSau.phut5);
    expect(await sv.batVanTay(10), isNull);
    await sv.datPin(10, '135790');
    final c = (await kho.doc(10))!;
    expect(c.tuKhoaSau, TuKhoaSau.phut5);
    expect(c.vanTay, isNotNull);
    expect((await sv.kiemPin(10, '135790')).dung, isTrue);
  });

  test('batVanTay cất bản mã + iv + SHA-256(bí mật), không cất bí mật', () async {
    await sv.datPin(10, '246810');
    expect(await sv.batVanTay(10), isNull);
    final v = (await kho.doc(10))!.vanTay!;
    final biMat = Uint8List.fromList(base64Decode(v.banMa).reversed.toList());
    expect(v.bamBiMat, base64Encode(sha256.convert(biMat).bytes));
    expect(jsonEncode((await kho.doc(10))!.toJson()), isNot(contains(base64Encode(biMat))));
  });

  test('moBangVanTay: thành công đếm về 0; bí mật lạ → loi; VO_HIEU → tự tắt vân tay + xoá alias', () async {
    await sv.datPin(10, '246810');
    await sv.batVanTay(10);
    await sv.kiemPin(10, '000000');
    expect(await sv.moBangVanTay(10), isNull);
    expect((await kho.doc(10))!.soLanSai, 0);

    kenh.traVeKhac = Uint8List.fromList(List.filled(32, 7));
    expect(await sv.moBangVanTay(10), LoiSinhTrac.loi, reason: 'băm không khớp thì không mở');
    kenh.traVeKhac = null;

    kenh.loiMo = LoiSinhTrac.voHieu;
    expect(await sv.moBangVanTay(10), LoiSinhTrac.voHieu);
    expect((await kho.doc(10))!.vanTay, isNull);
    expect(kenh.soLanXoa, greaterThan(0));
  });

  test('moBangVanTay khi chưa bật vân tay → khongHoTro', () async {
    await sv.datPin(10, '246810');
    expect(await sv.moBangVanTay(10), LoiSinhTrac.khongHoTro);
  });

  test('tatKhoa xoá cấu hình + alias; xoaHet xoá mọi tài khoản', () async {
    await sv.datPin(10, '246810');
    await sv.datPin(11, '246810');
    await sv.tatKhoa(10);
    expect(await kho.doc(10), isNull);
    expect(await kho.doc(11), isNotNull);
    await sv.xoaHet();
    expect(await kho.doc(11), isNull);
  });
}
