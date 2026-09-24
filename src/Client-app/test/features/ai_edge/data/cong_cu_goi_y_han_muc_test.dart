/// Adapter tool gợi ý hạn mức: khớp tên danh mục TRƯỚC khi hỏi suggestAmount,
/// ngân sách hết hạn không tính là "đã có", cửa sổ null thì không hỏi gì thêm.
library;

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/ai_edge/data/cong_cu_goi_y_han_muc.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../category/presentation/category_test_fakes.dart';

class _NganSach implements BudgetRepository {
  _NganSach({this.cuaSo = 19, this.coDuLieu = 19, List<Category>? danhMuc})
      : danhMuc = danhMuc ??
            [
              makeCategory(id: 'c-an', name: 'Ăn uống', idaccount: 10),
              makeCategory(id: 'c-dc', name: 'Di chuyển', idaccount: 10),
              makeCategory(id: 'c-mo', name: 'Mới', idaccount: 10),
            ];
  final int? cuaSo;
  final int? coDuLieu;
  final List<Category> danhMuc;
  final daGoiY = <String>[];

  @override
  Future<int?> soNgayCuaSoNhinLai(int idaccount, {DateTime? now}) async => cuaSo;
  @override
  Future<int?> soNgayCoDuLieu(int idaccount, {DateTime? now}) async => coDuLieu;
  @override
  Future<List<Category>> getExpenseCategories(int idaccount) async => danhMuc;
  @override
  Future<double?> suggestAmount(int idaccount, String categoryId, {DateTime? now}) async {
    daGoiY.add(categoryId);
    return switch (categoryId) { 'c-an' => 80000, 'c-dc' => 570000, _ => null };
  }

  @override
  Stream<List<BudgetView>> watchBudgets(int idaccount, {DateTime? now}) => Stream.value([
        BudgetView(
          budget: BudgetEntity(
            id: 'b1', idaccount: 10, categoryId: 'c-an', amount: 1000000, spent: 50000,
            startDate: DateTime(2026, 9, 1), recurrence: true, timeRecurrence: BudgetRecurrence.month,
            updatedAt: DateTime(2026, 9, 1),
          ),
          categoryName: 'Ăn uống',
        ),
        // Hết hạn (không lặp, kỳ tháng 8) → KHÔNG được tính là "đã có ngân sách".
        BudgetView(
          budget: BudgetEntity(
            id: 'b2', idaccount: 10, categoryId: 'c-dc', amount: 300000, spent: 0,
            startDate: DateTime(2026, 8, 1), recurrence: false, timeRecurrence: BudgetRecurrence.month,
            updatedAt: DateTime(2026, 8, 1),
          ),
          categoryName: 'Di chuyển',
        ),
      ]);

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

void main() {
  final now = DateTime(2026, 9, 23, 10);

  test('khai báo: danh_muc tuỳ chọn, mô tả có "Gọi khi"', () {
    final k = CongCuGoiYHanMuc(_NganSach()).khaiBao;
    expect(k.ten, kTenCongCuGoiYHanMuc);
    expect(k.moTa, contains('Gọi khi'));
    expect((k.thamSo['properties'] as Map).keys, ['danh_muc']);
    expect(k.thamSo['required'], isNull);
  });

  test('không tham số: mọi danh mục có gợi ý; ngân sách HẾT HẠN không tính', () async {
    final kq = await CongCuGoiYHanMuc(_NganSach()).chay({}, idaccount: 10, now: now);
    expect(kq.hang.map((h) => (h.ten, h.trangThai)).toList(),
        [('Di chuyển', 'chưa có ngân sách'), ('Ăn uống', 'đã có ngân sách')]);
  });

  test('⭐ danh_muc gõ không dấu → chỉ hàng ấy', () async {
    final kq = await CongCuGoiYHanMuc(_NganSach()).chay({'danh_muc': 'an uong'}, idaccount: 10, now: now);
    expect(kq.hang.single.ten, 'Ăn uống');
  });

  test('danh_muc không khớp → từ chối kèm tên thật, KHÔNG hỏi suggestAmount', () async {
    final repo = _NganSach();
    final kq = await CongCuGoiYHanMuc(repo).chay({'danh_muc': 'xang xe'}, idaccount: 10, now: now);
    expect(kq.loi, contains('Ăn uống'));
    expect(kq.tenLienQuan, ['Ăn uống', 'Di chuyển', 'Mới', 'xang xe']);
    expect(kq.choNguoiDung, 'không có danh mục chi nào tên "xang xe"');
    expect(repo.daGoiY, isEmpty);
  });

  test('danh_muc khớp nhiều → từ chối kèm các tên đã khớp', () async {
    final repo = _NganSach(danhMuc: [
      makeCategory(id: 'a', name: 'Dá', idaccount: 10),
      makeCategory(id: 'b', name: 'Đá', idaccount: 10),
    ]);
    final kq = await CongCuGoiYHanMuc(repo).chay({'danh_muc': 'da'}, idaccount: 10, now: now);
    expect(kq.tenLienQuan, ['Dá', 'Đá', 'da']);
    expect(kq.loi, contains('khớp nhiều'));
  });

  test('danh mục khớp mà không có gợi ý → 0 hàng + chữ kèm', () async {
    final kq = await CongCuGoiYHanMuc(_NganSach()).chay({'danh_muc': 'Mới'}, idaccount: 10, now: now);
    expect(kq.hang, isEmpty);
    expect(kq.chuThem['ghi_chu'], contains('không có khoản chi'));
  });

  test('cửa sổ null → "Cần thêm dữ liệu", không hỏi suggestAmount', () async {
    final repo = _NganSach(cuaSo: null, coDuLieu: 9);
    final kq = await CongCuGoiYHanMuc(repo).chay({}, idaccount: 10, now: now);
    expect(kq.tongHop.single.chuoi, '5 ngày');
    expect(repo.daGoiY, isEmpty);
  });
}
