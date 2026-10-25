/// Nguồn ví / danh mục cho lệnh tạo C3 (`ai_chat/data/nguon_lenh_tao.dart`) đọc qua REPOSITORY của mảng (mục 5 KIEN_TRUC),
/// không `sl<AppDatabase>()` — và lấy danh mục chi bằng `selectableChildren(classify: 'chi')` thay cho phép lọc tay.
/// Test chỉ đăng ký hai repository (không `AppDatabase`): bản đọc DAO thẳng sẽ ném, bị nuốt, và trả danh sách rỗng.
library;

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/ai_chat/data/nguon_lenh_tao.dart';
import 'package:flowmoney/features/category/data/models/category_entity.dart';
import 'package:flowmoney/features/category/data/repositories/category_management_repository.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _ViGia implements WalletRepository {
  _ViGia(this.vi);
  final List<WalletEntity> vi;
  int? hoi;
  @override
  Future<List<WalletEntity>> getActive(int idaccount) async {
    hoi = idaccount;
    return vi;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _DanhMucGia implements CategoryManagementRepository {
  _DanhMucGia(this.chi);
  final List<CategoryEntity> chi;
  @override
  Future<List<CategoryEntity>> selectableChildren({required int accountId, required String classify}) async =>
      classify == 'chi' ? chi : const [];

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  tearDown(() => sl.reset());

  test('ví hoạt động qua WalletRepository.getActive, danh mục chi qua selectableChildren', () async {
    final luc = DateTime(2026, 10, 19);
    final vi = _ViGia([
      WalletEntity(id: 'v1', idaccount: 10, name: 'Tiền mặt', type: 'cash', balance: 0, updatedAt: luc),
    ]);
    sl.registerSingleton<WalletRepository>(vi);
    sl.registerSingleton<CategoryManagementRepository>(_DanhMucGia([
      CategoryEntity(id: 'c1', idaccount: 10, name: 'Ăn uống', classify: 'chi', updatedAt: luc),
    ]));

    final nguon = await napNguonLenhTao(10);

    expect(vi.hoi, 10);
    expect(nguon.vi, [(id: 'v1', ten: 'Tiền mặt')]);
    expect(nguon.danhMucChi, [(id: 'c1', ten: 'Ăn uống')]);
  });
}
