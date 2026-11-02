/// Nhà biến mất KHI form `/nha/khoan` đang mở (Chủ giải tán, bị mời ra, `/me` trả không nhà): redirect chỉ bảo đảm có nhà
/// lúc VÀO, nên builder và closure `napCay` không được `nha!` — null-check ném là trang thành ErrorWidget / spinner quay mãi.
library;

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/core/router/app_router.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/household/data/nha_store.dart';
import 'package:flowmoney/features/household/data/repositories/du_lieu_nha_repository.dart';
import 'package:flowmoney/features/household/data/repositories/nha_repository.dart';
import 'package:flowmoney/features/household/data/repositories/nha_repository_impl.dart';
import 'package:flowmoney/features/household/data/them_giao_dich_nguon_nha.dart';
import 'package:flowmoney/features/household/presentation/pages/nha_minh_page.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/choose_category_page.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/category/presentation/category_test_fakes.dart';
import '../../helpers/bat_thong_bao.dart';
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

class _DuLieuNhaGia implements DuLieuNhaRepository {
  // Nhà mình dựng khối Ví chung từ nguồn đã đăng ký (1B Task 5): ca này không xem ví, chỉ cần luồng không ném.
  @override
  Stream<List<WalletEntity>> theoDoiViChung(int idNha) => const Stream.empty();
  @override
  Stream<List<GoalEntity>> theoDoiMucTieuChung(int idNha) => const Stream.empty();
  @override
  Future<List<WalletEntity>> viChungChoForm(int idNha, {Set<String> giuLai = const {}, String? uuTien}) async => const [];
  @override
  Future<CategoryTree> napCayDanhMuc(int idNha, String classify) async => CategoryTree(
        groups: const [],
        ungroupedChildren: const [],
        defaultChildren: [makeCategory(id: 'c-$classify', name: 'Danh mục $classify', classify: classify)],
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(napFontThat);

  testWidgets('nhà biến mất khi bộ chọn danh mục của form nhà đang mở: không ném, về Nhà mình', (t) async {
    t.view.physicalSize = const Size(411, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    batThongBao();
    final api = HouseholdApiGia()..cuaToiJson = nhaJson();
    final repo = NhaRepositoryImpl(api: api, kho: InMemoryNhaStore());
    addTearDown(repo.dispose);
    await repo.datTaiKhoan(18);
    await repo.lamMoi();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final duLieu = _DuLieuNhaGia();
    sl.registerSingleton<NhaRepository>(repo);
    sl.registerSingleton<DuLieuNhaRepository>(duLieu);
    sl.registerFactoryParam<ThemGiaoDichNguonNha, ThamSoNguonNha, void>((p, _) => ThemGiaoDichNguonNha(
          idNha: p.idNha,
          duLieu: duLieu,
          categoryDao: db.categoryDao,
          viUuTien: p.uuTien,
          viGiuLai: p.giuLai,
        ));
    sl.registerFactory<TransactionBloc>(() => TransactionBloc(transactionRepository: FakeTransactionRepository()));
    addTearDown(() async {
      await sl.unregister<NhaRepository>();
      await sl.unregister<DuLieuNhaRepository>();
      await sl.unregister<ThemGiaoDichNguonNha>();
      await sl.unregister<TransactionBloc>();
    });
    final auth = _AuthCoDinh(AuthSuccess(user: UserModel(id: '18', username: 'an', name: 'An', email: 'an@x.vn')));
    addTearDown(auth.close);
    final r = AppRouter.createRouter('/nha', auth);
    addTearDown(r.dispose);
    await t.pumpWidget(MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: r));
    await t.pumpAndSettle();

    // Vào form khi còn nhà (Chủ → có quyền ghi), rồi mở bộ chọn danh mục.
    r.push('/nha/khoan');
    await t.pumpAndSettle();
    expect(find.text('Khoản chi của nhà'), findsOneWidget, reason: 'tiền đề: form nhà đã mở');
    await t.tap(find.text('Danh mục'));
    await t.pumpAndSettle();
    expect(find.byType(ChooseCategoryPage), findsOneWidget, reason: 'tiền đề: bộ chọn đã mở khi còn nhà');
    expect(find.text('Danh mục chi'), findsOneWidget);

    // Nhà biến mất giữa chừng (Chủ giải tán / bị mời ra → `/me` không nhà).
    api.cuaToiJson = const {'household': null};
    await repo.lamMoi();
    expect(repo.hienTai.nha, isNull, reason: 'tiền đề: kho không còn nhà');

    // Đổi tab: `napCay` bắt id nhà MỘT lần lúc dựng route, không đọc lại `hienTai.nha!`.
    await t.tap(find.byKey(const Key('category-classify-thu')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: 'null-check trong closure napCay → spinner quay mãi');
    expect(find.text('Danh mục thu'), findsOneWidget);

    // Đường mở LẠI route sau khi nhà mất: builder trả Nhà mình, không ErrorWidget.
    r.pop();
    await t.pumpAndSettle();
    r.push('/nha/khoan/category');
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: 'builder `t.nha!` ném khi nhà đã mất');
    expect(find.byType(ChooseCategoryPage), findsNothing);
    expect(find.byType(NhaMinhPage), findsWidgets);
  });
}
