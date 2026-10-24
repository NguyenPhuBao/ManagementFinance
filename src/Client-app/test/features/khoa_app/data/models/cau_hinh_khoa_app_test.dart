import 'package:flowmoney/features/khoa_app/data/models/cau_hinh_khoa_app.dart';
import 'package:flowmoney/features/khoa_app/domain/luat_khoa_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = CauHinhKhoaApp(
    salt: 'c2FsdA==',
    bam: 'YmFt',
    soVong: 30000,
    tuKhoaSau: TuKhoaSau.phut1,
    vanTay: const VanTayDaBat(banMa: 'YQ==', iv: 'Yg==', bamBiMat: 'Yw=='),
    soLanSai: 6,
    choDen: DateTime.fromMillisecondsSinceEpoch(1792850000000),
  );

  test('JSON đi rồi về giữ nguyên mọi trường', () {
    final ve = CauHinhKhoaApp.tuJson(day.toJson())!;
    expect(ve.salt, day.salt);
    expect(ve.bam, day.bam);
    expect(ve.soVong, 30000);
    expect(ve.tuKhoaSau, TuKhoaSau.phut1);
    expect(ve.vanTay!.banMa, 'YQ==');
    expect(ve.soLanSai, 6);
    expect(ve.choDen, day.choDen);
  });

  test('hàng hỏng / thiếu trường bắt buộc → null', () {
    expect(CauHinhKhoaApp.tuJson('chuoi'), isNull);
    expect(CauHinhKhoaApp.tuJson({'salt': 'a', 'bam': 'b'}), isNull, reason: 'thiếu soVong');
  });

  test('voiPin giữ mức tự khoá + vân tay, xoá đếm sai', () {
    final m = day.voiPin(salt: 'MQ==', bam: 'Mg==', soVong: 40000);
    expect(m.tuKhoaSau, TuKhoaSau.phut1);
    expect(m.vanTay, isNotNull);
    expect(m.soLanSai, 0);
    expect(m.choDen, isNull);
    expect(m.soVong, 40000);
  });

  test('voiVanTay(null) gỡ vân tay; voiLanSai(0, null) xoá chờ', () {
    expect(day.voiVanTay(null).vanTay, isNull);
    final m = day.voiLanSai(0, null);
    expect(m.soLanSai, 0);
    expect(m.choDen, isNull);
  });
}
