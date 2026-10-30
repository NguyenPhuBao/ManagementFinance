/// G110 (2026-10-28) — mục *"Đang tạm ngừng (N)"* cuối màn Danh mục + dải nhắc ở form Sửa danh mục.
///
/// Danh mục trùng (tên, loại) một khuôn admin đã xoá bị `dangAnTheoKhuon` ẩn khỏi MỌI bộ chọn, kể cả màn Danh mục — trước
/// G110 người dùng không có chỗ nào để thấy hay đổi tên nó cho hiện lại (chốt 2 spec 2026-10-27: đổi tên → hết khớp → hiện).
library;

import 'package:flowmoney/features/category/data/models/category_entity.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/category/presentation/pages/category_add_page.dart';
import 'package:flowmoney/features/category/presentation/pages/category_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/font_that.dart';
import 'category_test_fakes.dart';

CategoryEntity _dm(String id, String ten, {String? parentId}) => CategoryEntity(
      id: id,
      idaccount: 1,
      name: ten,
      classify: 'chi',
      icon: 'local_cafe',
      colour: '#10B981',
      parentId: parentId,
      isGroup: false,
      isDefault: false,
      isDeleted: false,
      aiCoDinh: false,
      syncStatus: 'synced',
      updatedAt: DateTime(2026, 10, 28),
    );

final _caPhe = _dm('ca-phe', 'Cà phê');
final _xangXe = _dm('xang-xe', 'Xăng xe bản dài để thử xuống dòng ở khổ hẹp ba trăm hai mươi');

FakeCategoryRepository _kho({List<CategoryEntity> an = const []}) => FakeCategoryRepository(
      tree: CategoryTree(
        groups: const [],
        ungroupedChildren: [_dm('an-uong', 'Ăn uống')],
        defaultChildren: const [],
        dangTamNgung: an,
      ),
    );

/// Router thật để đo đường dẫn bút mở (kể cả `?tamNgung=1`).
Future<List<Uri>> _dungMan(WidgetTester tester, FakeCategoryRepository kho, {double rong = 411}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(rong, 1400);
  addTearDown(tester.view.reset);
  final daMo = <Uri>[];
  final router = GoRouter(initialLocation: '/categories', routes: [
    GoRoute(path: '/categories', builder: (_, __) => CategoryPage(repository: kho, accountId: 1)),
    GoRoute(
      path: '/categories/child/:id/edit',
      builder: (_, s) {
        daMo.add(s.uri);
        return Scaffold(body: Text('SỬA ${s.pathParameters['id']}'));
      },
    ),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return daMo;
}

void main() {
  group('màn Danh mục — mục "Đang tạm ngừng"', () {
    testWidgets('không có danh mục nào đang ẩn → không dựng mục', (tester) async {
      await _dungMan(tester, _kho());
      expect(find.textContaining('Đang tạm ngừng'), findsNothing);
      expect(find.byKey(const Key('muc-dang-tam-ngung')), findsNothing);
    });

    testWidgets('⭐ có 2 → tiêu đề "Đang tạm ngừng (2)" thu gọn sẵn; chạm mở ra hai dòng + "Đổi tên để dùng tiếp"',
        (tester) async {
      await _dungMan(tester, _kho(an: [_caPhe, _xangXe]));
      final muc = find.byKey(const Key('muc-dang-tam-ngung'));
      await tester.ensureVisible(muc);
      expect(find.text('Đang tạm ngừng (2)'), findsOneWidget);
      expect(find.text('Cà phê'), findsNothing, reason: 'thu gọn sẵn — người dùng chốt');

      await tester.tap(find.text('Đang tạm ngừng (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Cà phê'), findsOneWidget);
      expect(find.text(_xangXe.name), findsOneWidget);
      expect(find.text('Đổi tên để dùng tiếp'), findsNWidgets(2));
      expect(find.text('Ăn uống'), findsOneWidget, reason: 'mục mới không đụng các mục cũ');
    });

    testWidgets('⭐ bút của dòng tạm ngừng mở form Sửa kèm ?tamNgung=1', (tester) async {
      final daMo = await _dungMan(tester, _kho(an: [_caPhe]));
      await tester.ensureVisible(find.byKey(const Key('muc-dang-tam-ngung')));
      await tester.tap(find.text('Đang tạm ngừng (1)'));
      await tester.pumpAndSettle();
      final but = find.byKey(const Key('tam-ngung-sua-ca-phe'));
      await tester.ensureVisible(but);
      await tester.tap(but);
      await tester.pumpAndSettle();
      expect(find.text('SỬA ca-phe'), findsOneWidget);
      expect(daMo.single.queryParameters['tamNgung'], '1');
    });

    testWidgets('320 dp, font thật: mục mở ra không tràn, tên dài xuống dòng không cắt', (tester) async {
      await napFontThat();
      await _dungMan(tester, _kho(an: [_caPhe, _xangXe]), rong: 320);
      await tester.ensureVisible(find.byKey(const Key('muc-dang-tam-ngung')));
      await tester.tap(find.text('Đang tạm ngừng (2)'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final t in [_xangXe.name, 'Đổi tên để dùng tiếp', 'Đang tạm ngừng (2)']) {
        final r = tester.renderObject<RenderParagraph>(find.text(t).first);
        expect(r.didExceedMaxLines, isFalse, reason: t);
      }
    });
  });

  group('form Sửa danh mục — dải nhắc', () {
    Future<void> dungForm(WidgetTester tester, {required bool tamNgung}) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(411, 1600);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          home: CategoryAddPage(
              categoryId: 'ca-phe', tamNgung: tamNgung, repository: _kho(an: [_caPhe]), accountId: 1)));
      await tester.pumpAndSettle();
    }

    testWidgets('⭐ danh mục đang ẩn vẫn MỞ được ở form (tìm cả trong dangTamNgung) + có dải nhắc', (tester) async {
      await dungForm(tester, tamNgung: true);
      expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, 'Cà phê',
          reason: 'form tìm danh mục trong cây — hàng đang ẩn nằm ở dangTamNgung, thiếu vế ấy là form trống');
      expect(find.byKey(const Key('dai-nhac-tam-ngung')), findsOneWidget);
      expect(find.textContaining('‘Cà phê’ đang tạm ngừng'), findsOneWidget);
    });

    testWidgets('mở thường (không ?tamNgung) → không dải nhắc', (tester) async {
      await dungForm(tester, tamNgung: false);
      expect(find.byKey(const Key('dai-nhac-tam-ngung')), findsNothing);
    });
  });
}
