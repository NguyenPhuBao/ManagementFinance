/// Adapter tool `danh_sach_danh_muc`: danh mục con chọn được + ngân sách ĐANG
/// CHẠY (đã lọc hết hạn) → `hangDanhMuc`.
library;

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/ai_edge/data/cong_cu_danh_muc.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository.dart';
import 'package:flowmoney/features/category/data/repositories/category_management_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../category/presentation/category_test_fakes.dart';

class _DanhMuc implements CategoryManagementRepository {
  final daHoi = <int>[];
  @override
  Future<List<Category>> selectableChildrenAll({required int accountId}) async {
    daHoi.add(accountId);
    return [
      makeCategory(id: 'c1', name: 'Ăn uống'),
      makeCategory(id: 'c2', name: 'Giải trí'),
      makeCategory(id: 'c3', name: 'Lương', classify: 'thu'),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

BudgetView _ns(String categoryId, {required DateTime start, required bool lapLai}) => BudgetView(
      budget: BudgetEntity(
        id: 'b-$categoryId', idaccount: 10, categoryId: categoryId, amount: 100000, spent: 0,
        startDate: start, recurrence: lapLai, timeRecurrence: BudgetRecurrence.month, updatedAt: start,
      ),
      categoryName: categoryId,
    );

class _NganSach implements BudgetRepository {
  @override
  Stream<List<BudgetView>> watchBudgets(int idaccount, {DateTime? now}) => Stream.value([
        _ns('c1', start: DateTime(2026, 9, 1), lapLai: true),
        // Không lặp, kỳ tháng 8 → đã hết hạn: KHÔNG được tính là "có ngân sách".
        _ns('c2', start: DateTime(2026, 8, 1), lapLai: false),
      ]);
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

void main() {
  final now = DateTime(2026, 9, 23, 10);
  late _DanhMuc dm;
  late CongCuDanhMuc cc;
  setUp(() {
    dm = _DanhMuc();
    cc = CongCuDanhMuc(danhMuc: dm, nganSach: _NganSach());
  });

  test('khai báo: một tham số loai, không bắt buộc; mô tả chỉ đường sang tool ngân sách', () {
    final k = cc.khaiBao;
    expect(k.ten, kTenCongCuDanhMuc);
    expect(k.moTa, contains('Gọi khi'));
    expect(k.moTa, contains(kTenCongCuNganSach));
    expect((k.thamSo['properties'] as Map).keys, ['loai']);
    expect(k.thamSo.containsKey('required'), isFalse);
  });

  test('⭐ đọc đúng tài khoản; ngân sách HẾT HẠN không tính là có ngân sách', () async {
    final kq = await cc.chay({}, idaccount: 10, now: now);
    expect(dm.daHoi, [10]);
    expect(kq.hang.map((h) => '${h.ten}|${h.trangThai}').toList(), [
      'Ăn uống|khoản chi · có ngân sách',
      'Giải trí|khoản chi',
      'Lương|khoản thu',
    ]);
    expect(kq.json['Đã có ngân sách'], '1');
  });

  test('câu hỏi nêu loại → lọc; không nêu → gỡ loai mô hình điền thừa', () async {
    final thu = await cc.chay({}, idaccount: 10, now: now, cauHoi: 'toi co nhung danh muc thu nao');
    expect(thu.hang.map((h) => h.ten).toList(), ['Lương']);
    final tatCa = await cc.chay({'loai': 'khoan_thu'}, idaccount: 10, now: now, cauHoi: 'toi co nhung danh muc nao');
    expect(tatCa.hang, hasLength(3));
  });

  test('loai lạ (không có câu hỏi để chỉnh) → từ chối', () async {
    expect((await cc.chay({'loai': 'abc'}, idaccount: 10, now: now)).loi, contains('khoan_chi'));
  });
}
