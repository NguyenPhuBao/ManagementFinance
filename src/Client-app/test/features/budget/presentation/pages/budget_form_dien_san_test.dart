/// Form ngân sách mở **đã điền sẵn** từ thẻ "Chưa đặt ngân sách" (Task 6), và
/// nhãn gợi ý **nói ra độ dài cửa sổ** đã suy ra con số.
///
/// Hai thứ đi cùng nhau vì chúng trả lời cùng một câu hỏi: thẻ hứa "khoảng
/// 450.000 đ mỗi tháng, suy từ 20 ngày gần nhất", nên form mở ra từ nút Tạo
/// của thẻ phải nói **đúng cùng một lời hứa**, không được lùi về một câu mơ hồ
/// hơn. Người dùng chốt điều này ngày 2026-09-21.
///
/// ⚠️ Vế "suy từ N ngày" chỉ hiện khi cửa sổ **ngắn hơn** 90 ngày — mẫu đã đủ
/// dài thì câu ấy là tiếng ồn. `null` nghĩa là **chưa biết độ dài**, và khi ấy
/// nhãn cũng im vế đó chứ không đoán.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/presentation/pages/budget_form.dart';

Category _cat(String id, String ten) => Category(
      id: id,
      idaccount: 7,
      name: ten,
      classify: 'chi',
      icon: 'movie',
      colour: '#F25F5C',
      isDefault: false,
      isGroup: false,
      isLocalOnly: false,
      aiCoDinh: false,
      isDeleted: false,
      syncStatus: 'synced',
      syncRetryCount: 0,
      updatedAt: DateTime(2026, 9, 1),
    );

final _danhMuc = [_cat('c-giai-tri', 'Giải trí'), _cat('c-an', 'Ăn uống')];

Future<void> _dung(
  WidgetTester tester, {
  String? danhMucChonSan,
  double? soTienChonSan,
  int? soNgayCuaSo,
  int? soNgayConThieu,
  BudgetEntity? editing,
  Future<double?> Function(String)? suggestFor,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: BudgetForm(
      categories: _danhMuc,
      editing: editing,
      onSubmit: (_) {},
      suggestFor: suggestFor ?? (_) async => 450000,
      danhMucChonSan: danhMucChonSan,
      soTienChonSan: soTienChonSan,
      soNgayCuaSo: soNgayCuaSo,
      soNgayConThieu: soNgayConThieu,
    ),
  ));
  await tester.pumpAndSettle();
}

String _oHanMuc(WidgetTester tester) =>
    tester
        .widget<TextFormField>(find.byKey(const ValueKey('budget-amount')))
        .controller
        ?.text ??
    '';

void main() {
  testWidgets('mở từ thẻ thì danh mục và số tiền đã điền sẵn', (tester) async {
    await _dung(
      tester,
      danhMucChonSan: 'c-giai-tri',
      soTienChonSan: 450000,
      soNgayCuaSo: 20,
    );

    expect(find.text('Giải trí'), findsWidgets,
        reason: 'danh mục của dòng được bấm phải là danh mục đang chọn');
    expect(_oHanMuc(tester), '450000',
        reason: 'số thô như khi người dùng tự gõ, để `CurrencyFormatter.parse` '
            'đọc được lúc lưu');
  });

  testWidgets('không truyền gì thì form trống như cũ', (tester) async {
    await _dung(tester);

    expect(_oHanMuc(tester), '',
        reason: 'ĐÒI KẾT QUẢ: đường cũ (nút "Tạo ngân sách mới") không được '
            'tự điền số nào');
  });

  testWidgets('ngân sách đang SỬA thắng mọi giá trị điền sẵn', (tester) async {
    await _dung(
      tester,
      danhMucChonSan: 'c-giai-tri',
      soTienChonSan: 450000,
      editing: BudgetEntity(
        id: 'b1',
        idaccount: 7,
        categoryId: 'c-an',
        amount: 3000000,
        startDate: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      ),
    );

    expect(_oHanMuc(tester), '3000000',
        reason: 'giá trị điền sẵn chỉ dành cho đường TẠO MỚI; đè lên một ngân '
            'sách đang sửa là lặng lẽ đổi hạn mức người dùng đã đặt');
  });

  testWidgets('cửa sổ ngắn thì nhãn nói ra số ngày', (tester) async {
    await _dung(tester, danhMucChonSan: 'c-giai-tri', soNgayCuaSo: 20);

    expect(find.textContaining('suy từ 20 ngày gần nhất'), findsOneWidget,
        reason: 'thẻ trên trang Ngân sách đã nói câu này; form mở ra từ nó '
            'không được lùi về một lời hứa mơ hồ hơn');
  });

  testWidgets('cửa sổ đủ 90 ngày thì nhãn im vế ấy', (tester) async {
    await _dung(tester, danhMucChonSan: 'c-giai-tri', soNgayCuaSo: 90);

    expect(find.textContaining('trung bình'), findsOneWidget,
        reason: 'ĐÒI KẾT QUẢ: nhãn vẫn phải có mặt');
    expect(find.textContaining('suy từ'), findsNothing,
        reason: 'mẫu đã đủ dài thì câu cảnh báo chỉ là tiếng ồn');
  });

  testWidgets('chưa biết độ dài cửa sổ thì nhãn cũng im vế ấy',
      (tester) async {
    await _dung(tester, danhMucChonSan: 'c-giai-tri', soNgayCuaSo: null);

    expect(find.textContaining('trung bình'), findsOneWidget);
    expect(find.textContaining('suy từ'), findsNothing,
        reason: '`null` là "chưa biết", không phải một con số để đoán ra');
  });

  testWidgets('tài khoản trẻ: nhãn nói "cần thêm N ngày" thay vì im',
      (tester) async {
    await _dung(
      tester,
      danhMucChonSan: 'c-giai-tri',
      soNgayCuaSo: null,
      soNgayConThieu: 4,
      suggestFor: (_) async => null, // cửa sổ chưa mở → không có con số
    );
    expect(find.textContaining('Cần thêm 4 ngày'), findsOneWidget);
    expect(find.text('Dùng số này'), findsNothing,
        reason: 'không có số nào để dùng');
  });

  testWidgets('đủ dữ liệu nhưng danh mục không có khoản chi: vẫn im như cũ',
      (tester) async {
    await _dung(
      tester,
      danhMucChonSan: 'c-giai-tri',
      soNgayCuaSo: 20,
      soNgayConThieu: null,
      suggestFor: (_) async => null,
    );
    expect(find.textContaining('Cần thêm'), findsNothing);
    expect(find.textContaining('trung bình'), findsNothing,
        reason: '"trung bình 0 đ" tệ hơn không gợi ý — luật cũ giữ nguyên');
  });
}
