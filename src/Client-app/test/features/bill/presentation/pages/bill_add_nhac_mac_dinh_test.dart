/// Form Thêm hoá đơn chọn sẵn chip "Nhắc trước hạn" theo tuỳ chọn "Nhắc trước" của Cài đặt thông báo (người dùng
/// chốt 2026-10-17: hàng ấy là MẶC ĐỊNH cho hoá đơn mới). Đọc qua cổng `SoNgayNhacNguon` — cùng cổng với nhãn
/// "Sắp đến hạn" của trang danh sách.
library;

import 'dart:async';

import '../../../../helpers/nguon_doc_gia.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/bill/data/models/bill_entity.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository.dart';
import 'package:flowmoney/features/bill/data/so_ngay_nhac_nguon.dart';
import 'package:flowmoney/features/bill/domain/bill_draft.dart';
import 'package:flowmoney/features/bill/domain/bill_recurrence.dart';
import 'package:flowmoney/features/bill/presentation/bloc/bill_bloc.dart';
import 'package:flowmoney/features/bill/presentation/pages/bill_add_page.dart';

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

/// Ghi lại BillDraft form gửi lên.
class _GhiThem implements BillRepository {
  BillDraft? daThem;
  @override
  Stream<List<BillEntity>> watchBills(int idaccount) => const Stream.empty();
  @override
  Future<void> addBill(BillDraft draft, {required String id, required int idaccount, required DateTime now}) async =>
      daThem = draft;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  final moc = DateTime(2026, 9, 1);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    if (sl.isRegistered<AppDatabase>()) await sl.unregister<AppDatabase>();
    sl.registerSingleton<AppDatabase>(db);
    dangKyNguonDocGia(db);
    await db.into(db.wallets).insert(WalletsCompanion.insert(id: 'wA', idaccount: 10, name: 'Ví', updatedAt: moc));
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'cA', idaccount: 10, name: 'Điện nước', classify: 'chi', updatedAt: moc));
  });

  tearDown(() async {
    await sl.unregister<AppDatabase>();
    await db.close();
  });

  /// Mở form qua router (Lưu `pop(true)` cần một trang bên dưới), điền sẵn tên + tiền để Lưu đi được.
  Future<_GhiThem> mo(WidgetTester tester, SoNgayNhacNguon? nguon) async {
    tester.view.physicalSize = const Size(411, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final auth = _AuthCoDinh(AuthSuccess(
      user: UserModel(id: '10', username: 'dat', name: 'Đạt', email: 'dat@example.com'),
    ));
    addTearDown(auth.close);
    final repo = _GhiThem();
    final bloc = BillBloc(repository: repo);
    addTearDown(bloc.close);
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (c, _) => Scaffold(
          body: TextButton(onPressed: () => c.push<bool>('/bills/add'), child: const Text('mo form')),
        ),
      ),
      GoRoute(
        path: '/bills/add',
        builder: (_, __) => BillAddPage(
          soNgayNhac: nguon,
          dienSan: (
            ten: 'Tiền điện',
            soTien: 250000,
            chuKy: kBillCycleMonth,
            ngayGoc: null,
            batDau: DateTime(2026, 9, 1),
            categoryId: null,
            walletId: null,
          ),
        ),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: auth),
        BlocProvider<BillBloc>.value(value: bloc),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.tap(find.text('mo form'));
    await tester.pumpAndSettle();
    return repo;
  }

  Future<String?> luu(WidgetTester tester, _GhiThem repo) async {
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(repo.daThem, isNotNull, reason: 'Form phải lưu được để đọc số ngày nhắc đã ghi.');
    return repo.daThem!.timeNotification;
  }

  testWidgets('tuỳ chọn "Nhắc trước" 7 → chip 7 chọn sẵn, lưu ra "7"', (tester) async {
    final repo = await mo(tester, SoNgayNhacNguon((_) async => 7));
    expect(await luu(tester, repo), '7',
        reason: 'Hàng "Nhắc trước" ở Cài đặt là mặc định cho hoá đơn mới — form phải chọn sẵn đúng số ấy.');
  });

  testWidgets('không có nguồn (DI chưa đăng ký) → chip 3 như trước', (tester) async {
    final repo = await mo(tester, null);
    expect(await luu(tester, repo), '3');
  });

  testWidgets('giá trị cũ ngoài 1 · 3 · 5 · 7 (vd. 2) → chip 3, không lưu số form không hiện', (tester) async {
    final repo = await mo(tester, SoNgayNhacNguon((_) async => 2));
    expect(await luu(tester, repo), '3',
        reason: 'Lưu "2" là hoá đơn mang một mức không chip nào hiện — form Sửa cũng không có mức ấy.');
  });

  testWidgets('người dùng bấm chip TRƯỚC khi tuỳ chọn đọc xong → không bị đè', (tester) async {
    final cho = Completer<int>();
    final repo = await mo(tester, SoNgayNhacNguon((_) => cho.future));
    await tester.tap(find.text('5 ngày'));
    await tester.pump();
    cho.complete(7);
    await tester.pumpAndSettle();
    expect(await luu(tester, repo), '5', reason: 'Lựa chọn tay của người dùng thắng mặc định về muộn.');
  });
}
