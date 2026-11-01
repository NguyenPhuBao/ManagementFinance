// Màn Danh mục của nhà (đợt 1B, Task 11; Stitch 8A `6dc96c4a`). Mọi vai xem được; thêm / sửa theo ViecNha.suaDanhMuc.
import 'dart:io';

import 'package:flowmoney/features/category/data/models/category_entity.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/household/presentation/pages/danh_muc_nha_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/du_lieu_nha_gia.dart';
import '../../../../helpers/font_that.dart';
import '../../../../helpers/household_api_gia.dart';
import '../../../../helpers/nha_gia.dart';

CategoryEntity _dm(String id, String ten, {String classify = 'chi', String icon = 'restaurant', String colour = '#F97316'}) =>
    CategoryEntity(
      id: id,
      idaccount: 25,
      idhousehold: 12,
      name: ten,
      classify: classify,
      icon: icon,
      colour: colour,
      updatedAt: DateTime(2026, 11, 1),
    );

CategoryTree _cay({List<CategoryEntity> roi = const [], CategoryEntity? nhom, List<CategoryEntity> con = const []}) =>
    CategoryTree(
      groups: [if (nhom != null) CategoryGroupNode(group: nhom, children: con)],
      ungroupedChildren: roi,
      defaultChildren: const [],
    );

void main() {
  setUpAll(napFontThat);

  late DuLieuNhaGia nguon;
  late GoRouter router;

  Future<void> mo(
    WidgetTester t, {
    String vai = 'Member',
    String status = 'Active',
    void Function(DuLieuNhaGia)? dat,
  }) async {
    dat360(t);
    nguon = DuLieuNhaGia();
    (dat ?? (n) {
      n.datCay('chi', _cay(roi: [_dm('c1', 'Ăn uống'), _dm('c2', 'Đi lại', icon: 'directions_car', colour: '#3B82F6')]));
    })(nguon);
    final api = HouseholdApiGia()..cuaToiJson = nhaJson(myRole: vai, status: status);
    final repo = await repoNhaThu(api);
    router = GoRouter(initialLocation: '/', routes: [
      GoRoute(path: '/', builder: (_, __) => DanhMucNhaPage(repo: repo, duLieu: nguon)),
      GoRoute(path: '/nha/danh-muc/them', builder: (_, __) => const Scaffold(body: Text('FORM THEM'))),
      GoRoute(path: '/nha/danh-muc/:id/sua', builder: (_, s) => Scaffold(body: Text('FORM SUA ${s.pathParameters['id']}'))),
    ]);
    addTearDown(router.dispose);
    await t.pumpWidget(bocRouterNha(router));
    await t.pumpAndSettle();
  }

  testWidgets('Thành viên: thấy +, chevron, câu chú thích và danh sách theo màn 8A', (t) async {
    await mo(t);
    expect(find.text('Danh mục của nhà'), findsOneWidget);
    expect(find.byTooltip('Thêm danh mục'), findsOneWidget);
    expect(find.text('Danh mục dùng chung cho cả nhà, không lẫn với danh mục cá nhân của bạn.'), findsOneWidget);
    expect(find.text('Ăn uống'), findsOneWidget);
    expect(find.text('Đi lại'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
    expect(find.byIcon(Icons.restaurant), findsOneWidget);
    expect(find.byIcon(Icons.directions_car), findsOneWidget);
    expect(nguon.goiCay.first, (12, 'chi'));
    expect(t.takeException(), isNull);
  });

  testWidgets('tiêu đề căn giữa', (t) async {
    await mo(t);
    final tieuDe = t.getRect(find.descendant(of: find.byType(AppBar), matching: find.text('Danh mục của nhà')));
    expect(tieuDe.center.dx, closeTo(180, 1), reason: 'centerTitle: true; mặc định Android căn trái');
  });

  testWidgets('chạm + mở form thêm; chạm dòng mở form sửa đúng id', (t) async {
    await mo(t);
    await t.tap(find.byTooltip('Thêm danh mục'));
    await t.pumpAndSettle();
    expect(find.text('FORM THEM'), findsOneWidget);
    router.pop();
    await t.pumpAndSettle();
    await t.tap(find.text('Đi lại'));
    await t.pumpAndSettle();
    expect(find.text('FORM SUA c2'), findsOneWidget);
  });

  testWidgets('Chủ nhà cũng thêm / sửa được', (t) async {
    await mo(t, vai: 'Owner');
    expect(find.byTooltip('Thêm danh mục'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
  });

  testWidgets('Chỉ xem: thấy danh sách, không +, không chevron, chạm dòng không đi đâu', (t) async {
    await mo(t, vai: 'Viewer');
    expect(find.text('Ăn uống'), findsOneWidget, reason: 'mọi vai xem được danh sách');
    expect(find.byTooltip('Thêm danh mục'), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    await t.tap(find.text('Ăn uống'));
    await t.pumpAndSettle();
    expect(find.textContaining('FORM'), findsNothing, reason: 'dòng không phản ứng khi chạm');
    expect(find.text('Danh mục của nhà'), findsOneWidget);
  });

  testWidgets('nhà chỉ xem (Chủ hết Premium): vẫn xem, kể cả Chủ nhà không + không chevron', (t) async {
    await mo(t, vai: 'Owner', status: 'ReadOnly');
    expect(find.text('Ăn uống'), findsOneWidget);
    expect(find.byTooltip('Thêm danh mục'), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('ba tab theo kCategoryClassifies đổi danh sách và nguồn theo dõi', (t) async {
    await mo(t, dat: (n) {
      n.datCay('chi', _cay(roi: [_dm('c1', 'Ăn uống')]));
      n.datCay('thu', _cay(roi: [_dm('t1', 'Lương', classify: 'thu', icon: 'payments')]));
      n.datCay('vay_no', _cay(roi: [_dm('v1', 'Cho vay', classify: 'vay_no', icon: 'person_add')]));
    });
    expect(find.text('Khoản chi'), findsOneWidget);
    expect(find.text('Khoản thu'), findsOneWidget);
    expect(find.text('Vay / nợ'), findsOneWidget);
    expect(find.text('Ăn uống'), findsOneWidget);
    await t.tap(find.text('Khoản thu'));
    await t.pumpAndSettle();
    expect(find.text('Lương'), findsOneWidget);
    expect(find.text('Ăn uống'), findsNothing);
    await t.tap(find.text('Vay / nợ'));
    await t.pumpAndSettle();
    expect(find.text('Cho vay'), findsOneWidget);
    expect(find.text('Lương'), findsNothing);
    expect(nguon.goiCay.map((e) => e.$2).toSet(), {'chi', 'thu', 'vay_no'});
  });

  testWidgets('nhóm phẳng hoá: tiêu đề nhóm rồi các con (tiêu đề nhóm không phải dòng sửa)', (t) async {
    await mo(t, dat: (n) {
      n.datCay('chi', _cay(nhom: _dm('g', 'Sinh hoạt'), con: [_dm('c1', 'Điện'), _dm('c2', 'Nước')], roi: [_dm('c3', 'Lẻ')]));
    });
    final nhom = t.getRect(find.text('Sinh hoạt')).top;
    expect(t.getRect(find.text('Điện')).top, greaterThan(nhom));
    expect(t.getRect(find.text('Nước')).top, greaterThan(t.getRect(find.text('Điện')).top));
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(3), reason: 'chỉ ba danh mục con có chevron, nhóm thì không');
    await t.tap(find.text('Sinh hoạt'));
    await t.pumpAndSettle();
    expect(find.textContaining('FORM'), findsNothing);
  });

  testWidgets('danh sách rỗng có câu', (t) async {
    await mo(t, dat: (_) {});
    expect(find.text('Chưa có danh mục nào.'), findsOneWidget);
    expect(find.byTooltip('Thêm danh mục'), findsOneWidget, reason: 'rỗng vẫn thêm được');
  });

  testWidgets('360 dp, tên 200 ký tự và nhóm tên dài: không tràn, một dòng', (t) async {
    final dai = 'Đ' * 200;
    await mo(t, dat: (n) {
      n.datCay('chi', _cay(nhom: _dm('g', 'N' * 200), con: [_dm('c1', dai)]));
    });
    expect(t.takeException(), isNull);
    final h = t.getRect(find.text(dai)).height;
    expect(h, lessThan(30), reason: 'maxLines 1 + ellipsis: tên dài không đẩy dòng cao lên');
    expect(t.getRect(find.text(dai)).right, lessThanOrEqualTo(360));
  });

  test('route nhà (đọc app_router.dart): không redirectTaoTheoGoi, hai route ghi khoá theo suaDanhMuc, builder không `!`', () {
    final ma = File('lib/core/router/app_router.dart').readAsStringSync();
    final dong = ma.split('\n');
    String khoi(String path) {
      final i = dong.indexWhere((l) => l.contains("path: '$path'"));
      expect(i, greaterThanOrEqualTo(0), reason: 'thiếu route $path');
      // Từ dòng `path:` tới trước khai báo `GoRoute(` kế tiếp = đúng khối của route ấy.
      var j = dong.indexWhere((l) => l.contains('GoRoute('), i + 1);
      if (j < 0) j = i + 12;
      return dong.sublist(i, j).join('\n');
    }

    for (final p in ['/nha/danh-muc', '/nha/danh-muc/them', '/nha/danh-muc/:id/sua']) {
      final k = khoi(p);
      expect(k, isNot(contains('redirectTaoTheoGoi')),
          reason: '$p: trần danh mục riêng Basic không áp lên danh mục của nhà (đếm đã loại hàng nhà)');
      expect(k, isNot(contains('nha!')), reason: '$p: nhà có thể mất lúc builder chạy lại — trả Nhà mình');
    }
    expect(khoi('/nha/danh-muc'), isNot(contains('redirect:')), reason: 'xem: mọi vai');
    for (final p in ['/nha/danh-muc/them', '/nha/danh-muc/:id/sua']) {
      expect(khoi(p), contains('_veNhaNeuKhongSuaDanhMucDuoc'), reason: '$p: ghi thì khoá theo ViecNha.suaDanhMuc');
    }
    expect(ma, contains('ViecNha.suaDanhMuc'));
    expect(dong.indexWhere((l) => l.contains("path: '/nha/danh-muc/them'")),
        lessThan(dong.indexWhere((l) => l.contains("path: '/nha/danh-muc/:id/sua'"))));
    expect(ma, contains("duongQuanLy: '/nha/danh-muc'"), reason: 'nút Quản lý danh mục ở bộ chọn danh mục của nhà trỏ về đây');
  });
}
