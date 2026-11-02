/// Form danh mục ở chế độ NHÀ (gia đình 1B Task 11): `CategoryAddPage(idNha:)`. Danh mục của nhà không có nhóm cha (không có
/// form nhóm), không từ khoá (cột `Keyword` chung, các thành viên đè nhau — ruling M-17), không cờ Cố định (cột cục bộ, không
/// đồng bộ). Đọc một hàng qua `getById` và kiểm hàng ấy thuộc nhà, không đọc cây cá nhân.
library;

import 'package:flowmoney/features/category/data/models/category_entity.dart';
import 'package:flowmoney/features/category/data/repositories/category_management_repository.dart';
import 'package:flowmoney/features/category/presentation/pages/category_add_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/bat_thong_bao.dart';
import '../../../helpers/font_that.dart';
import '../../../helpers/nha_gia.dart';
import 'category_test_fakes.dart';

CategoryEntity _hang(String id, {int? nha = 7, String ten = 'Điện nước', bool coDinh = true, String? cha, bool xoa = false}) =>
    CategoryEntity(
      id: id,
      idaccount: 25,
      idhousehold: nha,
      name: ten,
      classify: 'thu',
      icon: 'restaurant',
      colour: '#3B82F6',
      parentId: cha,
      aiCoDinh: coDinh,
      isDeleted: xoa,
      updatedAt: DateTime(2026, 11, 1),
    );

void main() {
  setUpAll(napFontThat);

  Future<void> mo(WidgetTester t, Widget trang, {bool router = false}) async {
    dat360(t);
    // Cao hẳn lên: ListView chỉ dựng phần gần khung, khối từ khoá / thẻ Cố định ở cuối mà không dựng thì `findsNothing` xanh rỗng.
    t.view.physicalSize = const Size(360, 2400);
    if (router) {
      final r = routerThu(trang);
      await t.pumpWidget(bocRouterNha(r));
      r.push('/dich');
    } else {
      await t.pumpWidget(bocTrangNha(trang));
    }
    await t.pumpAndSettle();
  }

  final oTuKhoa = find.byKey(const Key('keyword-input'));

  testWidgets('form THÊM của nhà: tiêu đề riêng, không nhóm cha, từ khoá, thẻ Cố định, câu kế thừa nhóm cha', (t) async {
    await mo(t, CategoryAddPage(idNha: 7, repository: FakeCategoryRepository(), accountId: 20));
    expect(find.text('Thêm danh mục của nhà'), findsOneWidget);
    expect(find.text('Tên danh mục'), findsOneWidget, reason: 'tiền đề: đây là form đầy đủ');
    expect(find.text('Nhóm cha'), findsNothing);
    expect(find.byKey(const Key('parent-selector')), findsNothing);
    expect(find.text('Từ khóa nhận diện'), findsNothing);
    expect(oTuKhoa, findsNothing);
    expect(find.byKey(const ValueKey('cong-tac-ai-co-dinh')), findsNothing);
    expect(find.textContaining('Kế thừa từ nhóm cha'), findsNothing, reason: 'không có nhóm cha thì không có câu ấy');
    expect(find.text('Chọn biểu tượng'), findsOneWidget);
    expect(find.text('Màu sắc chủ đạo'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('form THÊM cá nhân (không idNha) vẫn đủ khối cũ — không hỏng đường cá nhân', (t) async {
    await mo(t, CategoryAddPage(repository: FakeCategoryRepository(), accountId: 20));
    expect(find.text('Thêm danh mục mới'), findsOneWidget);
    expect(find.text('Nhóm cha'), findsOneWidget);
    expect(find.text('Từ khóa nhận diện'), findsOneWidget);
    expect(find.byKey(const ValueKey('cong-tac-ai-co-dinh')), findsOneWidget);
  });

  testWidgets('Lưu thêm mới: saveChild nhận idhousehold = idNha, từ khoá rỗng, accountId = người lưu', (t) async {
    final kho = FakeCategoryRepository();
    await mo(t, CategoryAddPage(idNha: 7, repository: kho, accountId: 20));
    await t.enterText(find.byType(TextField).first, 'Tiền chợ');
    await t.tap(find.text('Lưu danh mục'));
    await t.pump();
    final d = kho.savedChild!;
    expect(d.idhousehold, 7, reason: 'thiếu idhousehold là tạo danh mục RIÊNG của người lưu, không ai trong nhà thấy');
    expect(d.keywords, isEmpty);
    expect(d.accountId, 20);
    expect(d.name, 'Tiền chợ');
    expect(d.id, isNull);
  });

  testWidgets('FINAL I-3: mất quyền sửa danh mục nhà giữa chừng — Lưu không gọi saveChild, báo câu, thoát form', (t) async {
    final bat = batThongBao();
    final kho = FakeCategoryRepository();
    await mo(t, CategoryAddPage(idNha: 7, repository: kho, accountId: 20, conDuocGhi: () => false), router: true);
    await t.enterText(find.byType(TextField).first, 'Tiền chợ');
    await t.tap(find.text('Lưu danh mục'));
    await t.pumpAndSettle();
    expect(kho.savedChild, isNull, reason: 'READ_ONLY / ROLE_FORBIDDEN ở server: hàng kẹt pending hoặc bị xoá im lặng');
    expect(bat.cau, isNotEmpty, reason: 'phải có câu, không im lặng');
    expect(find.text('GOC'), findsOneWidget, reason: 'thoát form về trang trước');
  });

  testWidgets('FINAL I-3: còn quyền (conDuocGhi => true) hoặc đường cá nhân (null) — lưu như cũ', (t) async {
    final kho = FakeCategoryRepository();
    await mo(t, CategoryAddPage(idNha: 7, repository: kho, accountId: 20, conDuocGhi: () => true));
    await t.enterText(find.byType(TextField).first, 'Tiền chợ');
    await t.tap(find.text('Lưu danh mục'));
    await t.pump();
    expect(kho.savedChild?.name, 'Tiền chợ');
  });

  testWidgets('form SỬA đọc một hàng qua getById (không loadTree), điền sẵn và giữ cờ Cố định + nhóm cha khi Lưu', (t) async {
    final kho = FakeCategoryRepository(hangTheoId: {'dn': _hang('dn', cha: 'nhom')});
    await mo(t, CategoryAddPage(idNha: 7, categoryId: 'dn', repository: kho, accountId: 20));
    expect(find.text('Sửa danh mục của nhà'), findsOneWidget);
    expect(kho.idDaHoi, ['dn']);
    expect(kho.loadedClassifies, isEmpty, reason: 'cây cá nhân không chứa hàng của nhà — đọc nó là form trống');
    expect(find.widgetWithText(TextField, 'Điện nước'), findsOneWidget);
    await t.tap(find.text('Lưu danh mục'));
    await t.pump();
    final d = kho.savedChild!;
    expect(d.id, 'dn');
    expect(d.idhousehold, 7);
    expect(d.aiCoDinh, isTrue, reason: 'insertOrReplace: bỏ cờ này là mỗi lần sửa tắt Cố định dù form không có công tắc');
    expect(d.parentId, 'nhom', reason: 'form nhà không có ô nhóm cha — sửa tên không được gỡ danh mục khỏi nhóm');
    expect(d.classify, 'thu');
    expect(d.icon, 'restaurant');
    expect(d.colour, '#3B82F6');
    expect(d.keywords, isEmpty);
  });

  for (final (ten, hang) in [
    ('hàng riêng (không thuộc nhà nào)', _hang('x', nha: null)),
    ('hàng của nhà KHÁC', _hang('x', nha: 8)),
    ('hàng của nhà đã xoá', _hang('x', xoa: true)),
  ]) {
    testWidgets('mở sửa $ten: báo và đóng, không nạp vào form nhà', (t) async {
      final bat = batThongBao();
      final kho = FakeCategoryRepository(hangTheoId: {'x': hang});
      await mo(t, CategoryAddPage(idNha: 7, categoryId: 'x', repository: kho, accountId: 20), router: true);
      expect(bat.cau, ['Danh mục này không còn trong nhà.'],
          reason: 'nạp hàng riêng vào form nhà rồi Lưu là HOUSEHOLD_SCOPE_MISMATCH (hoặc kéo hàng riêng sang nhà)');
      expect(find.text('GOC'), findsOneWidget, reason: 'form tự đóng về trang trước');
    });
  }

  testWidgets('mở sửa id không có: báo và đóng', (t) async {
    final bat = batThongBao();
    final kho = FakeCategoryRepository(hangTheoId: const {});
    await mo(t, CategoryAddPage(idNha: 7, categoryId: 'mat', repository: kho, accountId: 20), router: true);
    expect(bat.cau, ['Danh mục này không còn trong nhà.']);
    expect(find.text('GOC'), findsOneWidget);
  });

  testWidgets('trùng tên trong nhà: hiện đúng câu của repository ("…trong nhà…")', (t) async {
    final bat = batThongBao();
    final kho = FakeCategoryRepository()
      ..loiSaveChild = const CategoryValidationException(
          'Tên danh mục đã tồn tại trong nhà. Mỗi nhà không được có hai danh mục trùng tên.');
    await mo(t, CategoryAddPage(idNha: 7, repository: kho, accountId: 20));
    await t.enterText(find.byType(TextField).first, 'Tiền chợ');
    await t.tap(find.text('Lưu danh mục'));
    await t.pump();
    expect(bat.cau.single, contains('trong nhà'));
    expect(kho.savedChild, isNull);
  });

  testWidgets('360 dp, tên 200 ký tự: không tràn, ô tên cắt đúng 200', (t) async {
    final dai = 'Đ' * 200;
    final kho = FakeCategoryRepository(hangTheoId: {'dn': _hang('dn', ten: dai)});
    await mo(t, CategoryAddPage(idNha: 7, categoryId: 'dn', repository: kho, accountId: 20));
    expect(t.takeException(), isNull);
    final o = t.widget<TextField>(find.widgetWithText(TextField, dai));
    expect(o.controller!.text.length, 200);
    await t.enterText(find.byType(TextField).first, '${dai}XYZ');
    expect(o.controller!.text.length, 200, reason: 'GioiHanDoRong(DoRongCot.tenDanhMuc) vẫn áp ở chế độ nhà');
  });
}
