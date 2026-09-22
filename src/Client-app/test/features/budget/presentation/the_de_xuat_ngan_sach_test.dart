/// Thẻ "Chưa đặt ngân sách" trên trang Ngân sách (mục ④, Task 6).
///
/// Canh chừng bốn điều, và cả bốn hỏng **im lặng** nếu phá:
///
/// 1. **Không có gì để gợi ý thì ẩn HẲN thẻ** — `chonDeXuat` trả `null`, trang
///    không dựng thẻ. Một thẻ rỗng chiếm chỗ mà không mang tin (luật chốt ở
///    mục 3.34 `ANALYTICS_FEATURE.md`). Ca này **đòi kết quả**: nó khẳng định
///    phần còn lại của trang vẫn dựng, kẻo một bản sai ẩn cả thân trang cũng
///    làm nó xanh.
/// 2. Tối đa ba dòng, và nút **Tạo** gọi đúng đề xuất của dòng mình đứng.
/// 3. Cửa sổ ngắn hơn 90 ngày thì **nói ra** — "Suy từ 20 ngày gần nhất". Hứa
///    một mức "mỗi tháng" dựng từ hai tuần mà không nói gì là bịa một lời hứa
///    (bẫy 6 của spec).
/// 4. Cửa sổ đủ 90 ngày thì **không** có dòng phụ ấy — nó chỉ là lời cảnh báo
///    về mẫu ngắn, nói khi mẫu đã đủ dài là tiếng ồn.
///
/// Và chỗ đứng: **dưới** khối Nhận xét / thẻ kế hoạch, **trên** tiêu đề
/// "Danh mục chi tiêu".
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/domain/de_xuat_ngan_sach.dart';
import 'package:flowmoney/features/budget/presentation/bloc/budget_state.dart';
import 'package:flowmoney/features/budget/presentation/pages/budget_tabs_view.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

BudgetView _view(String id, {String ten = 'Ăn uống'}) => BudgetView(
      budget: BudgetEntity(
        id: id,
        idaccount: 7,
        categoryId: 'c-$id',
        amount: 1000000,
        spent: 200000,
        startDate: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      ),
      categoryName: ten,
    );

DeXuatNganSach _dx(String id, String ten, double muc) =>
    DeXuatNganSach(categoryId: id, tenDanhMuc: ten, mucThang: muc);

Future<List<DeXuatNganSach>> _dung(
  WidgetTester tester, {
  GoiDeXuat? goi,
}) async {
  final bam = <DeXuatNganSach>[];
  tester.view.physicalSize = const Size(411, 914);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: BudgetTabsView(
      now: DateTime(2026, 9, 21, 12),
      state: BudgetLoaded(
        active: [_view('b1')],
        expired: const [],
        totalAmount: 1000000,
        totalSpent: 200000,
        deXuat: goi,
      ),
      onCreate: () {},
      onEdit: (_) {},
      onDelete: (_) async => false,
      onShowDetail: (_) {},
      onTaoTuDeXuat: bam.add,
    ),
  ));
  await tester.pumpAndSettle();
  return bam;
}

void main() {
  testWidgets('không có đề xuất nào thì ẩn HẲN thẻ, trang vẫn dựng',
      (tester) async {
    await _dung(tester, goi: null);

    expect(find.text('CHƯA ĐẶT NGÂN SÁCH'), findsNothing,
        reason: 'không có gì để gợi ý thì thẻ không được chiếm chỗ');
    // Đòi KẾT QUẢ, không chỉ đòi vắng mặt: một bản sai ẩn cả thân trang cũng
    // làm khẳng định trên xanh.
    expect(find.text('Danh mục chi tiêu'), findsOneWidget,
        reason: 'phần còn lại của trang phải vẫn dựng bình thường');
  });

  testWidgets('hiện đúng ba dòng, nút Tạo gọi đúng đề xuất của dòng mình',
      (tester) async {
    final bam = await _dung(
      tester,
      goi: GoiDeXuat(
        ds: [
          _dx('c-giai-tri', 'Giải trí', 450000),
          _dx('c-chi-khac', 'Chi khác', 320000),
          _dx('c-y-te', 'Y tế', 280000),
        ],
        soNgayCuaSo: 20,
      ),
    );

    expect(find.text('CHƯA ĐẶT NGÂN SÁCH'), findsOneWidget);
    expect(find.text('3 nhóm'), findsOneWidget);
    expect(find.text('Giải trí'), findsOneWidget);
    expect(find.text('khoảng 450.000 đ mỗi tháng'), findsOneWidget);
    expect(find.text('khoảng 320.000 đ mỗi tháng'), findsOneWidget);
    expect(find.text('khoảng 280.000 đ mỗi tháng'), findsOneWidget);
    expect(find.text('Tạo'), findsNWidgets(3));

    await tester.tap(find.byKey(const ValueKey('de-xuat-tao-c-chi-khac')));
    await tester.pump();
    expect(bam.map((d) => d.categoryId), ['c-chi-khac'],
        reason: 'nút Tạo phải mang đúng đề xuất của dòng nó đứng, '
            'không phải dòng đầu');
  });

  testWidgets('cửa sổ ngắn hơn 90 ngày thì nói rõ suy từ bao nhiêu ngày',
      (tester) async {
    await _dung(
      tester,
      goi: GoiDeXuat(ds: [_dx('c1', 'Giải trí', 450000)], soNgayCuaSo: 20),
    );

    expect(find.text('Suy từ 20 ngày gần nhất'), findsOneWidget,
        reason: 'mẫu ngắn phải được nói ra, không thì đó là một lời hứa bịa');
  });

  testWidgets('cửa sổ đủ 90 ngày thì KHÔNG có dòng phụ ấy', (tester) async {
    await _dung(
      tester,
      goi: GoiDeXuat(ds: [_dx('c1', 'Giải trí', 450000)], soNgayCuaSo: 90),
    );

    expect(find.textContaining('Suy từ'), findsNothing,
        reason: 'mẫu đã đủ dài thì câu cảnh báo chỉ là tiếng ồn');
    // Đòi kết quả: thẻ vẫn phải ở đó, chỉ thiếu dòng phụ.
    expect(find.text('CHƯA ĐẶT NGÂN SÁCH'), findsOneWidget);
  });

  testWidgets('thẻ đứng TRÊN tiêu đề "Danh mục chi tiêu"', (tester) async {
    await _dung(
      tester,
      goi: GoiDeXuat(ds: [_dx('c1', 'Giải trí', 450000)], soNgayCuaSo: 20),
    );

    final the = tester.getRect(find.text('CHƯA ĐẶT NGÂN SÁCH')).top;
    final tieuDe = tester.getRect(find.text('Danh mục chi tiêu')).top;
    expect(the, lessThan(tieuDe),
        reason: 'thẻ là gợi ý cho phần danh sách ngay dưới nó');
  });
}
