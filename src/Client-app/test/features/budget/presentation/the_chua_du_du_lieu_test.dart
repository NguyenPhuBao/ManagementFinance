/// Thẻ "Cần thêm N ngày dữ liệu" — ngoại lệ có chủ ý với luật "khối rỗng thì ẩn
/// hẳn": đây là tin, không phải khối rỗng. Hai chốt: chỉ dựng khi KHÔNG có đề
/// xuất và tài khoản còn trẻ; và câu phải nêu ĐÚNG số ngày.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/domain/de_xuat_ngan_sach.dart';
import 'package:flowmoney/features/budget/presentation/bloc/budget_state.dart';
import 'package:flowmoney/features/budget/presentation/pages/budget_tabs_view.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

BudgetView _view() => BudgetView(
      budget: BudgetEntity(
        id: 'b1',
        idaccount: 7,
        categoryId: 'c1',
        amount: 1000000,
        spent: 200000,
        startDate: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      ),
      categoryName: 'Ăn uống',
    );

Future<void> _dung(WidgetTester t, {GoiDeXuat? deXuat, int? thieu}) async {
  t.view.physicalSize = const Size(411, 914);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: BudgetTabsView(
      now: DateTime(2026, 9, 21, 12),
      state: BudgetLoaded(
        active: [_view()],
        expired: const [],
        totalAmount: 1000000,
        totalSpent: 200000,
        deXuat: deXuat,
        soNgayConThieu: thieu,
      ),
      onCreate: () {},
      onEdit: (_) {},
      onDelete: (_) async => false,
      onShowDetail: (_) {},
      onTaoTuDeXuat: (_) {},
    ),
  ));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('tài khoản trẻ: thẻ NÓI RA số ngày còn thiếu', (t) async {
    await _dung(t, deXuat: null, thieu: 4);
    expect(find.byKey(const ValueKey('the-chua-du-du-lieu')), findsOneWidget);
    expect(find.textContaining('4 ngày'), findsOneWidget,
        reason: 'ĐÒI KẾT QUẢ: phải nêu đúng con số, không phải một câu chung chung');
    expect(find.text('CHƯA ĐẶT NGÂN SÁCH'), findsNothing);
  });

  testWidgets('đủ dữ liệu mà không có đề xuất: KHÔNG có thẻ nào (luật ẩn hẳn)',
      (t) async {
    await _dung(t, deXuat: null, thieu: null);
    expect(find.byKey(const ValueKey('the-chua-du-du-lieu')), findsNothing);
    expect(find.text('Danh mục chi tiêu'), findsOneWidget,
        reason: 'phần còn lại của trang vẫn dựng');
  });

  testWidgets('có đề xuất thì thẻ đề xuất thắng, không hiện câu thiếu', (t) async {
    await _dung(
      t,
      deXuat: const GoiDeXuat(
        ds: [
          DeXuatNganSach(
              categoryId: 'c2', tenDanhMuc: 'Giải trí', mucThang: 50000),
        ],
        soNgayCuaSo: 20,
      ),
      thieu: null,
    );
    expect(find.text('CHƯA ĐẶT NGÂN SÁCH'), findsOneWidget);
    expect(find.byKey(const ValueKey('the-chua-du-du-lieu')), findsNothing);
  });

  testWidgets('⚠️ lớp phòng thủ: có CẢ HAI thì thẻ đề xuất thắng', (t) async {
    // Trạng thái này cubit không bao giờ dựng ra (`soNgayConThieu` chỉ khác
    // null khi `deXuat` là null), nên ca trên KHÔNG canh được vế `when` ở
    // widget — bỏ vế ấy đi mà ca trên vẫn xanh. Đây là lớp thứ hai, cùng lối
    // với chốt hai lớp của Lịch chi tiêu: phá một lớp thì còn lớp kia.
    await _dung(
      t,
      deXuat: const GoiDeXuat(
        ds: [
          DeXuatNganSach(
              categoryId: 'c2', tenDanhMuc: 'Giải trí', mucThang: 50000),
        ],
        soNgayCuaSo: 20,
      ),
      thieu: 4,
    );
    expect(find.text('CHƯA ĐẶT NGÂN SÁCH'), findsOneWidget);
    expect(find.byKey(const ValueKey('the-chua-du-du-lieu')), findsNothing,
        reason: 'hai thẻ cùng lúc là hai lời khuyên ngược nhau trên một trang');
  });
}
