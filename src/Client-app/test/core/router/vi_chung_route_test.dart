/// Hai route ví chung của đợt 1B (Task 5) qua router THẬT: cửa quyền quản lý ví chung chặn Thành viên / nhà chỉ xem ở `redirect`
/// (deeplink không qua nút), Chủ nhà vào được cả Tạo lẫn Sửa.
library;

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/core/router/app_router.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/household/data/nha_store.dart';
import 'package:flowmoney/features/household/data/repositories/du_lieu_nha_repository.dart';
import 'package:flowmoney/features/household/data/repositories/nha_repository.dart';
import 'package:flowmoney/features/household/data/repositories/nha_repository_impl.dart';
import 'package:flowmoney/features/household/presentation/pages/chi_tiet_vi_chung_page.dart';
import 'package:flowmoney/features/household/presentation/pages/nha_minh_page.dart';
import 'package:flowmoney/features/household/presentation/pages/vi_chung_form_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/bat_thong_bao.dart';
import '../../helpers/du_lieu_nha_gia.dart';
import '../../helpers/font_that.dart';
import '../../helpers/household_api_gia.dart';

class _RepoGia implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthCoDinh extends AuthBloc {
  _AuthCoDinh(this._s) : super(authRepository: _RepoGia());
  final AuthState _s;
  @override
  AuthState get state => _s;
}

void main() {
  setUpAll(napFontThat);

  Future<GoRouter> mo(WidgetTester t, {required String vai, String status = 'Active', Map<String, Object?>? nha}) async {
    t.view.physicalSize = const Size(411, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    batThongBao();
    final repo = NhaRepositoryImpl(api: HouseholdApiGia()..cuaToiJson = nha ?? nhaJson(myRole: vai, status: status), kho: InMemoryNhaStore());
    addTearDown(repo.dispose);
    await repo.datTaiKhoan(18);
    await repo.lamMoi();
    final nguon = DuLieuNhaGia(vi: [viChungGia('a', 'Tiền chợ', 100)]);
    sl.registerSingleton<NhaRepository>(repo);
    sl.registerSingleton<DuLieuNhaRepository>(nguon);
    addTearDown(() async {
      await sl.unregister<NhaRepository>();
      await sl.unregister<DuLieuNhaRepository>();
    });
    final auth = _AuthCoDinh(AuthSuccess(user: UserModel(id: '18', username: 'an', name: 'An', email: 'an@x.vn')));
    addTearDown(auth.close);
    final r = AppRouter.createRouter('/nha', auth);
    addTearDown(r.dispose);
    await t.pumpWidget(MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: r));
    await t.pumpAndSettle();
    return r;
  }

  testWidgets('Chủ nhà: /nha/vi/tao mở form Tạo, /nha/vi/:id/sua mở form Sửa', (t) async {
    final r = await mo(t, vai: 'Owner');
    r.push('/nha/vi/tao');
    await t.pumpAndSettle();
    expect(find.byType(ViChungFormPage), findsOneWidget);
    expect(find.text('SỐ DƯ BAN ĐẦU'), findsOneWidget);
    r.pop();
    await t.pumpAndSettle();
    r.push('/nha/vi/a/sua');
    await t.pumpAndSettle();
    expect(find.text('Sửa ví chung'), findsOneWidget);
    expect(t.widget<TextField>(find.byKey(const Key('o-ten-vi-chung'))).controller!.text, 'Tiền chợ');
  });

  testWidgets('/nha/vi/:id đứng SAU /nha/vi/tao: tao vẫn mở form Tạo chứ không bị đọc thành id', (t) async {
    final r = await mo(t, vai: 'Owner');
    r.push('/nha/vi/tao');
    await t.pumpAndSettle();
    expect(find.byType(ViChungFormPage), findsOneWidget);
    expect(find.byType(ChiTietViChungPage), findsNothing, reason: 'thứ tự ngược là "tao" thành idVi');
  });

  testWidgets('/nha/vi/a khi đã không còn nhà: về Nhà mình, không ném', (t) async {
    final r = await mo(t, vai: 'Owner', nha: const {'household': null, 'myRole': null, 'members': [], 'formerMembers': []});
    r.push('/nha/vi/a');
    await t.pumpAndSettle();
    expect(find.byType(ChiTietViChungPage), findsNothing);
    expect(find.byType(NhaMinhPage), findsWidgets);
    expect(t.takeException(), isNull);
  });

  // Mọi vai xem được chi tiết ví (kể cả Chỉ xem, nhà chỉ xem): không cửa quyền ở route; nút trong trang tự theo vai.
  for (final c in [(vai: 'Owner', status: 'Active'), (vai: 'Member', status: 'Active'), (vai: 'Viewer', status: 'Active'), (vai: 'Owner', status: 'ReadOnly')]) {
    testWidgets('/nha/vi/a mở Chi tiết ví cho ${c.vai}/${c.status}', (t) async {
      final r = await mo(t, vai: c.vai, status: c.status);
      r.push('/nha/vi/a');
      await t.pumpAndSettle();
      expect(find.byType(ChiTietViChungPage), findsOneWidget);
      expect(find.text('SỐ DƯ'), findsOneWidget);
    });
  }

  for (final c in [(vai: 'Member', status: 'Active'), (vai: 'Viewer', status: 'Active'), (vai: 'Owner', status: 'ReadOnly')]) {
    testWidgets('deeplink ${c.vai}/${c.status}: redirect về Nhà mình, không form', (t) async {
      final r = await mo(t, vai: c.vai, status: c.status);
      for (final duong in ['/nha/vi/tao', '/nha/vi/a/sua']) {
        r.push(duong);
        await t.pumpAndSettle();
        expect(find.byType(ViChungFormPage), findsNothing, reason: '$duong: cửa quyền phải chặn ở redirect');
        expect(find.byType(NhaMinhPage), findsWidgets, reason: '$duong: về Nhà mình');
      }
    });
  }
}
