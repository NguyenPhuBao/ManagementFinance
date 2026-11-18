/// Hàm nạp nhóm ví chung cho form Thêm giao dịch thường (spec 2026-11-16 mục 2.2): chỉ khi tôi ĐƯỢC ghi khoản ở nhà đang
/// hoạt động và nhà có ví chung; chờ kho trước khi đọc vai (G92); quyền hỏi lại lúc Lưu đọc vai LÚC GỌI.
library;

import 'package:flowmoney/features/household/application/nhom_vi_chung_cho_form.dart';
import 'package:flowmoney/features/household/data/models/nha_cua_toi.dart';
import 'package:flowmoney/features/household/data/repositories/nha_repository.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/household_api_gia.dart';
import '../../../helpers/nha_gia.dart';
import '../../../helpers/them_giao_dich_nguon_gia.dart';
import '../../category/presentation/category_test_fakes.dart';

final _viNha = makeWallet(id: 'nha-v', name: 'Tiền chợ').copyWith(idhousehold: 12);

Future<List<WalletEntity>> Function(int) _vi(List<WalletEntity> ds, [List<int>? goi]) => (id) async {
      goi?.add(id);
      return ds;
    };

/// Kho chỉ có nhà SAU `choNapKho` — bản sai đọc `hienTai` trước khi chờ sẽ thấy "không có nhà".
class _NhaChoKho implements NhaRepository {
  _NhaChoKho(this._sau);
  final NhaCuaToi _sau;
  bool _daCho = false;

  @override
  NhaCuaToi get hienTai => _daCho ? _sau : NhaCuaToi.khongCo(DateTime(2026, 11, 16));

  @override
  Future<void> choNapKho() async => _daCho = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('không ở nhà → null', () async {
    final repo = await repoNhaThu(HouseholdApiGia());
    expect(await napNhomViChung(nha: repo, viChung: _vi([_viNha]), nguon: (_) => NguonThemGiaoDichGia()), isNull);
  });

  test('vai Chỉ xem → null; nhà chỉ xem → null', () async {
    final xem = await repoNhaThu(HouseholdApiGia()..cuaToiJson = nhaJson(myRole: 'Viewer'));
    expect(await napNhomViChung(nha: xem, viChung: _vi([_viNha]), nguon: (_) => NguonThemGiaoDichGia()), isNull);
    final chiXem = await repoNhaThu(HouseholdApiGia()..cuaToiJson = nhaJson(status: 'ReadOnly'));
    expect(await napNhomViChung(nha: chiXem, viChung: _vi([_viNha]), nguon: (_) => NguonThemGiaoDichGia()), isNull);
  });

  test('Thành viên, nhà hoạt động, 0 ví chung → null (không dựng nhóm rỗng)', () async {
    final repo = await repoNhaThu(HouseholdApiGia()..cuaToiJson = nhaJson(myRole: 'Member'));
    expect(await napNhomViChung(nha: repo, viChung: _vi(const []), nguon: (_) => NguonThemGiaoDichGia()), isNull);
  });

  test('Chủ nhà có ví chung → nhóm mang id / tên nhà, ví, nguồn của nhà ấy, route danh mục nhà từ /add', () async {
    final repo = await repoNhaThu(HouseholdApiGia()..cuaToiJson = nhaJson());
    final goiVi = <int>[];
    final goiNguon = <int>[];
    final nguonNha = NguonThemGiaoDichGia();
    final n = await napNhomViChung(
      nha: repo,
      viChung: _vi([_viNha], goiVi),
      nguon: (id) {
        goiNguon.add(id);
        return nguonNha;
      },
    );
    expect(n, isNotNull);
    expect(n!.idNha, 12);
    expect(n.tenNha, 'Nhà An – Bình');
    expect(n.vi.single.id, 'nha-v');
    expect(n.nguon, same(nguonNha));
    expect(goiVi, [12]);
    expect(goiNguon, [12]);
    expect(n.duongChonDanhMuc, '/add/nha-category');
    expect(n.conDuocGhi(), isTrue);
  });

  test('chờ kho TRƯỚC khi đọc vai (G92)', () async {
    final that = await repoNhaThu(HouseholdApiGia()..cuaToiJson = nhaJson());
    final n = await napNhomViChung(
        nha: _NhaChoKho(that.hienTai), viChung: _vi([_viNha]), nguon: (_) => NguonThemGiaoDichGia());
    expect(n?.idNha, 12, reason: 'đọc hienTai trước choNapKho là thấy "không có nhà" trong khe mở app');
  });

  test('conDuocGhi đọc vai LÚC GỌI: hạ xuống Chỉ xem sau khi nạp → false', () async {
    final api = HouseholdApiGia()..cuaToiJson = nhaJson(myRole: 'Member');
    final repo = await repoNhaThu(api);
    final n = await napNhomViChung(nha: repo, viChung: _vi([_viNha]), nguon: (_) => NguonThemGiaoDichGia());
    expect(n!.conDuocGhi(), isTrue);
    api.cuaToiJson = nhaJson(myRole: 'Viewer');
    await repo.lamMoi();
    expect(n.conDuocGhi(), isFalse, reason: 'FINAL I-3: vai đổi khi form mở thì Lưu phải bị chặn');
  });
}
