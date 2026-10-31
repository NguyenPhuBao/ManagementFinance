import 'dart:async';

import 'package:flowmoney/features/household/domain/cau_loi_nha.dart';
import 'package:flowmoney/features/household/domain/vai_nha.dart';
import 'package:flowmoney/features/household/presentation/bloc/moi_thanh_vien_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/household_api_gia.dart';
import '../../../../helpers/nha_gia.dart';

void main() {
  final now = DateTime.utc(2026, 11, 1, 8);
  Map<String, Object?> dong(String ma, {String status = 'Pending', String? email, DateTime? han}) => {
        'code': ma,
        'role': 'Member',
        'email': email,
        'createAt': '2026-10-31T08:00:00.000Z',
        'expiresAt': (han ?? now.add(const Duration(days: 1))).toIso8601String(),
        'status': status,
      };

  Future<(MoiThanhVienCubit, HouseholdApiGia, List<String>)> dung() async {
    final api = HouseholdApiGia()..cuaToiJson = nhaJson();
    final repo = await repoNhaThu(api);
    final c = MoiThanhVienCubit(repo, clock: () => now);
    addTearDown(c.close);
    final bao = <String>[];
    c.canBao.listen(bao.add);
    return (c, api, bao);
  }

  test('nap: lấy danh sách; soConHieuLuc bỏ mã đã chết và mã quá hạn trên máy', () async {
    final (c, api, _) = await dung();
    api.dsMaMoiJson = [
      dong('AAAA2222'),
      dong('BBBB3333', status: 'Declined', email: 'a@x.vn'),
      dong('CCCC4444', han: now.subtract(const Duration(minutes: 1))),
    ];
    await c.nap();
    expect(c.state.daNap, isTrue);
    expect(c.soConHieuLuc, 1, reason: 'đếm sai là khoá nhầm hai nút khi nhà còn chỗ');
  });

  test('taoMa: giữ mã vừa tạo, nạp lại danh sách', () async {
    final (c, api, _) = await dung();
    await c.taoMa(VaiNha.chiXem);
    expect(api.goi, contains('taoMaMoi:Viewer'));
    expect(c.state.maVuaTao!.ma, 'ABCD2345');
    expect(api.goi, contains('dsMaMoi'));
  });

  test('guiEmail: chuẩn hoá, ghi câu đã gửi; mọi email một câu (chống dò)', () async {
    final (c, api, _) = await dung();
    await c.guiEmail('  AN@X.com ', VaiNha.thanhVien);
    expect(api.goi, contains('moiQuaEmail:an@x.com:Member'));
    expect(c.state.emailVuaGui, 'an@x.com');
  });

  test('huy: gọi API; huỷ đúng mã vừa tạo thì gỡ khối mã', () async {
    final (c, api, _) = await dung();
    await c.taoMa(VaiNha.thanhVien);
    await c.huy('ABCD2345');
    expect(api.goi, contains('huyMaMoi:ABCD2345'));
    expect(c.state.maVuaTao, isNull);
  });

  test('lỗi: báo đúng câu, mở khoá nút; 429 thư quá nhiều dùng câu riêng', () async {
    final (c, api, bao) = await dung();
    api.loi = loiServer(429, 'HOUSEHOLD_INVITE_RATE_LIMIT');
    await c.guiEmail('an@x.com', VaiNha.thanhVien);
    await Future<void>.delayed(Duration.zero);
    expect(bao, [cauLoiNha(LoaiLoiNha.guiMoiQuaNhieu)]);
    expect(c.state.dangGuiEmail, isFalse);
    expect(c.state.emailVuaGui, isNull);
  });

  test('nap hỏng lượt đầu: báo, daNap vẫn true để màn không quay mãi', () async {
    final (c, api, bao) = await dung();
    api.loi = loiServer(500, 'HOUSEHOLD_ERROR');
    await c.nap();
    await Future<void>.delayed(Duration.zero);
    expect(c.state.daNap, isTrue);
    expect(bao, [cauLoiNha(LoaiLoiNha.mayChu)]);
  });

  test('huy chạm đôi: chỉ một DELETE trong lúc lượt đầu chưa xong, dangHuy giữ mã', () async {
    final (c, api, bao) = await dung();
    api.treo = Completer<void>();
    final a = c.huy('AAAA2222');
    await Future<void>.delayed(Duration.zero);
    expect(c.state.dangHuy, 'AAAA2222');
    final b = c.huy('AAAA2222');
    api.treo!.complete();
    await Future.wait([a, b]);
    expect(api.goi.where((g) => g == 'huyMaMoi:AAAA2222'), hasLength(1), reason: 'lượt hai 404 hiện toast lỗi oan');
    expect(c.state.dangHuy, isNull);
    expect(bao, isEmpty);
  });

  test('napTuDong: danh sách mới về khi gọi; 403 lặp thì không vòng (một lần gọi)', () async {
    final (c, api, _) = await dung();
    api.dsMaMoiJson = [dong('AAAA2222')];
    await c.napTuDong();
    expect(c.soConHieuLuc, 1);
    api.dsMaMoiJson = const [];
    await c.napTuDong();
    expect(c.soConHieuLuc, 0, reason: 'nhà đổi từ máy khác phải nạp lại');

    api.loi = loiServer(403, 'HOUSEHOLD_NOT_OWNER');
    final truoc = api.goi.where((g) => g == 'dsMaMoi').length;
    await c.napTuDong();
    await c.napTuDong();
    await c.napTuDong();
    expect(api.goi.where((g) => g == 'dsMaMoi').length - truoc, 1, reason: 'lượt trước hỏng thì lượt tự động bị bỏ');

    api.loi = null;
    await c.taoMa(VaiNha.thanhVien);
    final sau = api.goi.where((g) => g == 'dsMaMoi').length;
    await c.napTuDong();
    expect(api.goi.where((g) => g == 'dsMaMoi').length, sau + 1, reason: 'người dùng thao tác đặt lại cờ');
  });
}
