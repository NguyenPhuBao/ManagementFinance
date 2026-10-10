/// C3 — form tạo mục tiêu nhận query điền sẵn `/goals/add?name&target&deadline` (spec
/// `2026-09-28-c3-lenh-tao-hoa-don-muc-tieu-ngan-sach-design.md` §4). Khung dựng chép từ
/// `goal_add_name_limit_test.dart` (ảnh mạng giả, bề ngang rộng — lý do ở đầu tệp ấy).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/goal/domain/dien_san_muc_tieu.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/goal/data/repositories/goal_repository.dart';
import 'package:flowmoney/features/goal/presentation/bloc/goal_cubit.dart';
import 'package:flowmoney/features/goal/presentation/pages/goal_add_page.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/data/repositories/wallet_repository.dart';
import 'package:flowmoney/features/wallet/presentation/bloc/wallet_cubit.dart';
import 'package:flowmoney/features/premium/data/goi_repository.dart';
import 'package:flowmoney/features/premium/data/goi_store.dart';
import 'package:flowmoney/features/premium/data/payment_api.dart';
import 'package:flowmoney/features/premium/domain/trang_thai_goi.dart';
import 'package:flowmoney/features/premium/presentation/cubit/goi_cubit.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedAuthBloc extends AuthBloc {
  _FixedAuthBloc(this._fixed) : super(authRepository: _StubAuthRepository());
  final AuthState _fixed;
  @override
  AuthState get state => _fixed;
}

class _StubGoalRepository implements GoalRepository {
  @override
  Future<GoalEntity?> getGoalById(String id) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubWalletRepository implements WalletRepository {
  @override
  Future<List<WalletEntity>> getAll(int idaccount) async => [
        WalletEntity(
          id: 'w1',
          idaccount: 10,
          name: 'Tiết kiệm',
          type: 'saving',
          balance: 0,
          updatedAt: DateTime(2026, 9, 10),
        ),
      ];

  @override
  Future<double> getTotalBalance(int idaccount) async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// PNG trong suốt 1×1, thay cho ảnh mạng ở đầu trang.
const List<int> _pngTrongSuot = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
];

class _HttpClientGia implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _YeuCauGia();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _YeuCauGia implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => _PhanHoiGia();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PhanHoiGia extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _pngTrongSuot.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(_pngTrongSuot).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}


void main() {
  group('dienSanMucTieuTuQuery', () {
    test('đủ ba khoá', () {
      final d = dienSanMucTieuTuQuery({'name': 'mua xe', 'target': '50000000', 'deadline': '2027-06-30'})!;
      expect((d.ten, d.soTienDich, d.han), ('mua xe', 50000000.0, DateTime(2027, 6, 30)));
    });
    test('không khoá nào của mình → null (form mở như thường)', () {
      expect(dienSanMucTieuTuQuery({}), isNull);
      expect(dienSanMucTieuTuQuery({'x': '1'}), isNull);
    });
    test('giá trị hỏng → trường ấy null, không ném', () {
      final d = dienSanMucTieuTuQuery({'name': '  ', 'target': 'abc', 'deadline': '2027-02-30'})!;
      expect((d.ten, d.soTienDich, d.han), (null, null, null));
      expect(dienSanMucTieuTuQuery({'target': '-5', 'deadline': '30/06/2027'})!.soTienDich, isNull);
      expect(dienSanMucTieuTuQuery({'target': '99999999999999'})!.soTienDich, isNull, reason: 'numeric(15,2)');
    });
  });

  setUp(() async {
    if (sl.isRegistered<GoalCubit>()) await sl.unregister<GoalCubit>();
    sl.registerFactory<GoalCubit>(() => GoalCubit(repository: _StubGoalRepository()));
    if (sl.isRegistered<WalletCubit>()) await sl.unregister<WalletCubit>();
    sl.registerFactory<WalletCubit>(() => WalletCubit(repository: _StubWalletRepository()));
  });

  tearDown(() async {
    if (sl.isRegistered<GoalCubit>()) await sl.unregister<GoalCubit>();
    if (sl.isRegistered<WalletCubit>()) await sl.unregister<WalletCubit>();
  });

  Future<void> dung(WidgetTester tester, GoalAddPage trang, {Map<String, bool>? quyen}) async {
    tester.view.physicalSize = const Size(1600, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final auth = _FixedAuthBloc(AuthSuccess(
      user: UserModel(id: '10', username: 'dat', name: 'Đạt', email: 'dat@example.com'),
    ));
    addTearDown(auth.close);
    Widget cay = MaterialApp(theme: AppTheme.lightTheme, home: trang);
    if (quyen != null) {
      final goiRepo = GoiRepository(api: _ApiGoiIm(), kho: InMemoryGoiStore());
      final goi = GoiCubit(goiRepo);
      goi.emit(TrangThaiGoi(loai: LoaiGoi.basic, nhanLuc: DateTime.now(), quyenTinhNang: quyen));
      addTearDown(() async {
        await goi.close();
        await goiRepo.dispose();
      });
      cay = BlocProvider<GoiCubit>.value(value: goi, child: cay);
    }
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(value: auth, child: cay));
    await tester.pumpAndSettle();
  }

  testWidgets('quyền goal_auto_deposit tắt → mục tiêu MỚI: công tắc trích tắt sẵn, khoá, "Cần Premium"',
      (tester) async {
    debugNetworkImageHttpClientProvider = _HttpClientGia.new;
    try {
      await dung(tester, const GoalAddPage(dienSan: (ten: 'mua xe', soTienDich: 50000000, han: null)),
          quyen: const {'goal_auto_deposit': false});
      final sw = tester.widget<Switch>(find.byType(Switch).first);
      expect(sw.value, isFalse, reason: 'mặc định form là bật — Basic không có quyền thì tạo mục tiêu không trích');
      expect(sw.onChanged, isNull);
      expect(find.text('Cần Premium'), findsOneWidget);
    } finally {
      debugNetworkImageHttpClientProvider = null;
    }
  });

  String oTen(WidgetTester tester) => tester
      .widget<TextField>(find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'e.g. Mua Laptop MacBook Pro'))
      .controller!
      .text;

  testWidgets('⭐ điền sẵn tên, số tiền đích, hạn', (tester) async {
    debugNetworkImageHttpClientProvider = _HttpClientGia.new;
    try {
      await dung(
          tester, GoalAddPage(dienSan: (ten: 'mua xe', soTienDich: 50000000, han: DateTime(2027, 6, 30))));
      expect(oTen(tester), 'mua xe');
      expect(find.text('50.000.000'), findsOneWidget, reason: 'ô số tiền đích hiển thị có dấu chấm nghìn');
      expect(find.text('30/06/2027'), findsOneWidget,
          reason: 'hạn từ lệnh tạo, không phải mặc định "một năm nữa"');
    } finally {
      debugNetworkImageHttpClientProvider = null;
    }
  });

  testWidgets('chỉ một phần query → ô còn lại giữ mặc định', (tester) async {
    debugNetworkImageHttpClientProvider = _HttpClientGia.new;
    try {
      await dung(tester, const GoalAddPage(dienSan: (ten: 'du lịch', soTienDich: null, han: null)));
      expect(oTen(tester), 'du lịch');
    } finally {
      debugNetworkImageHttpClientProvider = null;
    }
  });

  testWidgets('đường SỬA bỏ qua điền sẵn', (tester) async {
    debugNetworkImageHttpClientProvider = _HttpClientGia.new;
    try {
      await dung(tester,
          GoalAddPage(goalId: 'g1', dienSan: (ten: 'mua xe', soTienDich: 50000000, han: DateTime(2027, 6, 30))));
      expect(find.text('mua xe'), findsNothing, reason: 'sửa một mục tiêu có sẵn không được bị query ghi đè');
    } finally {
      debugNetworkImageHttpClientProvider = null;
    }
  });
}

class _ApiGoiIm implements PaymentApi {
  @override
  Future<Map<String, Object?>> thongTinGoi() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> taoDon() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> trangThaiDon(int orderCode) => throw UnimplementedError();
  @override
  Future<List<Map<String, Object?>>> lichSu({int page = 1, int limit = 20}) => throw UnimplementedError();
}
