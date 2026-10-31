import 'dart:async';

import 'package:flowmoney/features/household/data/models/nha_cua_toi.dart';
import 'package:flowmoney/features/household/data/nha_store.dart';
import 'package:flowmoney/features/household/data/repositories/nha_repository_impl.dart';
import 'package:flowmoney/features/household/domain/cau_loi_nha.dart';
import 'package:flowmoney/features/household/domain/vai_nha.dart';
import 'package:flowmoney/features/household/presentation/bloc/nha_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/household_api_gia.dart';
import '../../../../helpers/nha_gia.dart';

void main() {
  test('moTrang: đọc trạng thái kho, đánh dấu đã nạp, hỏi lại /me', () async {
    final api = HouseholdApiGia()..cuaToiJson = nhaJson();
    final repo = await repoNhaThu(api);
    api.goi.clear();
    final c = NhaCubit(repo);
    addTearDown(c.close);
    await c.moTrang();
    await Future<void>.delayed(Duration.zero);
    expect(c.state.daNap, isTrue);
    expect(c.state.nha.nha!.id, 12);
    expect(api.goi, contains('cuaToi'));
  });

  test('nhà đổi ở nơi khác → state đổi theo luồng của repository', () async {
    final api = HouseholdApiGia()..cuaToiJson = nhaJson();
    final repo = await repoNhaThu(api);
    final c = NhaCubit(repo);
    addTearDown(c.close);
    await c.moTrang();
    api.cuaToiJson = const {'household': null};
    await repo.lamMoi();
    await Future<void>.delayed(Duration.zero);
    expect(c.state.nha.coNha, isFalse);
  });

  test('đổi vai thành công: true, gọi đúng API; không báo gì', () async {
    final api = HouseholdApiGia()..cuaToiJson = nhaJson();
    final repo = await repoNhaThu(api);
    final c = NhaCubit(repo);
    addTearDown(c.close);
    final bao = <String>[];
    c.canBao.listen(bao.add);
    expect(await c.doiVai(25, VaiNha.chiXem), isTrue);
    expect(api.goi, contains('doiVai:25:Viewer'));
    expect(bao, isEmpty);
    expect(c.state.dangXuLy, isFalse);
  });

  test('thao tác hỏng: false, báo đúng câu của cauLoiNha, mở khoá nút', () async {
    final api = HouseholdApiGia()..cuaToiJson = nhaJson();
    final repo = await repoNhaThu(api);
    final c = NhaCubit(repo);
    addTearDown(c.close);
    final bao = <String>[];
    c.canBao.listen(bao.add);
    api.loi = loiServer(500, 'HOUSEHOLD_ERROR');
    expect(await c.giaiTan(), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(bao, [cauLoiNha(LoaiLoiNha.mayChu)]);
    expect(c.state.dangXuLy, isFalse);
    expect(c.state.nha.coNha, isTrue, reason: 'giải tán hỏng thì nhà giữ nguyên');
  });

  test('tạo nhà bị 403 FEATURE_DISABLED: dùng câu trang truyền vào (G113 nợ 7); tham gia thì câu trung tính', () async {
    final api = HouseholdApiGia();
    final repo = await repoNhaThu(api);
    final c = NhaCubit(repo);
    addTearDown(c.close);
    final bao = <String>[];
    c.canBao.listen(bao.add);
    api.loi = loiServer(403, 'FEATURE_DISABLED');
    await c.taoNha('Nhà An', cauKhiTatQuyen: 'CÂU CỦA TRANG');
    await c.chapNhan('ABCD2345');
    await Future<void>.delayed(Duration.zero);
    expect(bao, ['CÂU CỦA TRANG', cauLoiNha(LoaiLoiNha.tinhNangKhongMo)]);
  });

  test('chạm đôi: thao tác đang chạy thì lần sau bị bỏ, API chỉ một lời gọi', () async {
    final api = HouseholdApiGia()..cuaToiJson = nhaJson(myRole: 'Member');
    final repo = await repoNhaThu(api);
    final c = NhaCubit(repo);
    addTearDown(c.close);
    api.goi.clear();
    final f1 = c.roiNha();
    final f2 = c.roiNha();
    expect(await f2, isFalse);
    await f1;
    expect(api.goi.where((g) => g == 'roiNha'), hasLength(1));
  });

  test('đóng cubit giữa chừng rồi API hỏng: trả false, không ném StateError', () async {
    final api = HouseholdApiGia()..cuaToiJson = nhaJson();
    final repo = await repoNhaThu(api);
    final c = NhaCubit(repo);
    api.treo = Completer<void>();
    final f = c.giaiTan();
    await c.close();
    api.loi = loiServer(500, 'HOUSEHOLD_ERROR');
    api.treo!.complete();
    expect(await f, isFalse);
  });

  test('daNap chờ kho: trước khi kho trả lời thì chưa nạp, sau đó đúng nhà từ kho', () async {
    final kho = _KhoTreo();
    final repo = NhaRepositoryImpl(api: HouseholdApiGia(), kho: kho);
    addTearDown(repo.dispose);
    unawaited(repo.datTaiKhoan(18));
    final c = NhaCubit(repo);
    addTearDown(c.close);
    final xong = c.moTrang();
    await Future<void>.delayed(Duration.zero);
    expect(c.state.daNap, isFalse);
    expect(c.state.nha.coNha, isFalse);
    kho.cho.complete(nhaCuaToiTuJson(nhaJson(), nhanLuc: DateTime(2026, 11, 1)));
    await xong;
    expect(c.state.daNap, isTrue);
    expect(c.state.nha.coNha, isTrue);
  });
}

class _KhoTreo implements NhaStore {
  final cho = Completer<NhaCuaToi?>();

  @override
  Future<NhaCuaToi?> doc(int idaccount) => cho.future;

  @override
  Future<void> ghi(int idaccount, NhaCuaToi trangThai) async {}
}
