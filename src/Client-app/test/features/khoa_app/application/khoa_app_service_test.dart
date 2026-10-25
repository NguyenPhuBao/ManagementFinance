import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flowmoney/features/khoa_app/application/khoa_app_service.dart';
import 'package:flowmoney/features/khoa_app/data/datasources/kenh_sinh_trac.dart';
import 'package:flowmoney/features/khoa_app/data/khoa_app_store.dart';
import 'package:flowmoney/features/khoa_app/domain/luat_khoa_app.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/khoa_app_gia.dart';

/// Kho giả hỏng: `readAll` ném; `delete` ném với khoá [khoaHong] (null = mọi khoá).
class _KhoHong implements FlutterSecureStorage {
  _KhoHong(this.du, {this.khoaHong});
  final Map<String, String> du;
  final String? khoaHong;
  @override
  Future<Map<String, String>> readAll({AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions,
          WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) async =>
      throw StateError('readAll hỏng');
  @override
  Future<void> delete({required String key, AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions,
      WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) async {
    if (khoaHong == null || key == khoaHong) throw StateError('delete hỏng');
    du.remove(key);
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

  test('moBangVanTay: MAT_KHOA (alias đã bị xoá — đăng xuất bị cắt giữa chừng, M14) → tự tắt vân tay, trả matKhoa', () async {
    await sv.datPin(10, '246810');
    await sv.batVanTay(10);
    kenh.loiMo = LoiSinhTrac.matKhoa;
    expect(await sv.moBangVanTay(10), LoiSinhTrac.matKhoa);
    expect((await kho.doc(10))!.vanTay, isNull, reason: 'cấu hình còn trỏ alias đã mất — phải tắt, không thì mỗi lần khoá lại báo lỗi');
    expect(kenh.soLanXoa, greaterThan(0));
  });

  test('moBangVanTay khi chưa bật vân tay → khongHoTro', () async {
    await sv.datPin(10, '246810');
    expect(await sv.moBangVanTay(10), LoiSinhTrac.khongHoTro);
  });

  test('tatKhoa xoá cấu hình + alias', () async {
    await sv.datPin(10, '246810');
    await sv.datPin(11, '246810');
    await sv.tatKhoa(10);
    expect(await kho.doc(10), isNull);
    expect(await kho.doc(11), isNotNull);
  });

  test('xoaVanTayHet: gọi kênh xoá, cấu hình PIN CÒN (đăng xuất bị ngắt giữa chừng vẫn đòi PIN)', () async {
    await sv.datPin(10, '246810');
    await sv.xoaVanTayHet();
    expect(kenh.soLanXoa, 1);
    expect(await kho.doc(10), isNotNull);
  });

  test('datLaiSauDangNhap: xoá cấu hình tài khoản này lẫn tài khoản khác + khoá Keystore', () async {
    await sv.datPin(10, '246810');
    await sv.datPin(11, '135790');
    await sv.datLaiSauDangNhap(10);
    expect(await kho.doc(10), isNull);
    expect(await kho.doc(11), isNull);
    expect(kenh.soLanXoa, 1);
  });

  test('datLaiSauDangNhap: kho hỏng (readAll + delete ném) → không ném; kênh vẫn bị xoá', () async {
    final hong = KhoaAppService(
        store: SecureStorageKhoaAppStore(_KhoHong({'khoa_app_10': 'x'})), kenh: kenh, bam: bamNhanh);
    await hong.datLaiSauDangNhap(10);
    expect(kenh.soLanXoa, 1);
  });

  test('datLaiSauDangNhap: readAll hỏng nhưng delete được → khoa_app_<id> vẫn bị xoá THẲNG theo khoá', () async {
    final du = {'khoa_app_10': 'x'};
    final kho2 = _KhoHong(du, khoaHong: 'khoa_khac');
    await KhoaAppService(store: SecureStorageKhoaAppStore(kho2), kenh: kenh, bam: bamNhanh).datLaiSauDangNhap(10);
    expect(du, isEmpty);
  });

  test('I2: đọc hỏng khi kiểm PIN → ném, KHÔNG báo đúng, không ghi đếm', () async {
    await sv.datPin(10, '246810');
    kho.hongKhiDoc = true;
    await expectLater(sv.kiemPin(10, '000000'), throwsStateError);
    await expectLater(sv.kiemPin(10, '246810'), throwsStateError);
    kho.hongKhiDoc = false;
    expect((await kho.doc(10))!.soLanSai, 0);
  });

  test('I3: batVanTay khi vân tay ĐÃ bật → không gọi kênh bat (Kotlin xoá khoá cũ trước khi hỏi)', () async {
    await sv.datPin(10, '246810');
    expect(await sv.batVanTay(10), isNull);
    final truoc = (await kho.doc(10))!.vanTay!;
    kenh.loiBat = LoiSinhTrac.huy; // nếu lỡ gọi kênh, người dùng Huỷ -> trả lỗi
    expect(await sv.batVanTay(10), isNull, reason: 'đã bật: coi như xong, không hỏi lại');
    expect((await kho.doc(10))!.vanTay!.banMa, truoc.banMa);
  });

  test('M3: PIN SAI lúc đang chờ → không băm, không đếm, không đổi choDen; kết quả GIỐNG HỆT PIN đúng (không oracle)', () async {
    var soLanBam = 0;
    Future<String> bamDem(String pin, List<int> salt, int soVong) {
      soLanBam++;
      return bamNhanh(pin, salt, soVong);
    }

    final sv2 = KhoaAppService(store: kho, kenh: kenh, bam: bamDem, clock: () => nay);
    await sv2.datPin(10, '246810');
    for (var i = 0; i < 5; i++) {
      await sv2.kiemPin(10, '000000');
    }
    final truoc = (await kho.doc(10))!;
    soLanBam = 0;
    final sai = await sv2.kiemPin(10, '111111');
    final dung = await sv2.kiemPin(10, '246810');
    expect(soLanBam, 0, reason: 'đang chờ: không băm PIN nào — băm rồi so là có oracle thời gian / đếm');
    for (final k in [sai, dung]) {
      expect([k.dung, k.dangCho, k.soLanSai, k.choDen], [false, true, truoc.soLanSai, truoc.choDen]);
    }
    final sau = (await kho.doc(10))!;
    expect([sau.soLanSai, sau.choDen], [truoc.soLanSai, truoc.choDen], reason: 'PIN sai lúc chờ không cộng thêm lần sai / kéo dài chờ');
  });

  test('T6: soVong đã cất được dùng khi kiểm — đổi kSoVongMacDinh không vỡ PIN cũ', () async {
    final soVongDaGoi = <int>[];
    Future<String> bamGhi(String pin, List<int> salt, int soVong) {
      soVongDaGoi.add(soVong);
      return bamNhanh(pin, salt, soVong);
    }

    final cu = KhoaAppService(store: kho, kenh: kenh, bam: bamGhi, clock: () => nay, soVong: 1);
    await cu.datPin(10, '246810');
    final moi = KhoaAppService(store: kho, kenh: kenh, bam: bamGhi, clock: () => nay, soVong: 2);
    soVongDaGoi.clear();
    final kq = await moi.kiemPin(10, '246810');
    expect(soVongDaGoi, [1], reason: 'kiểm phải dùng số vòng đã cất cùng băm (1), không phải mặc định của service mới (2)');
    expect(kq.dung, isTrue);
  });
}
