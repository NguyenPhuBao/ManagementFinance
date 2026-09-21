/// Header chọn kỳ của trang Sổ giao dịch (2026-09-21).
///
/// ## Vì sao cần widget test, không chỉ test thuần
///
/// Phép lùi/tiến kỳ và luật nhãn đều đã có ca ở `pham_vi_ky_test.dart`, nên thứ
/// tệp này canh là **chỗ NỐI**: hai mũi tên có gọi đúng chiều không, và nhãn
/// giữa có thật sự mở được bộ chọn không.
///
/// ⚠️ Cái thứ hai là bài học của **G43**: nút "Tuỳ chọn" của bộ chọn phạm vi
/// trang Phân tích từng **chết im lặng** — không toast, không màn đỏ, chỉ là
/// không có gì xảy ra — và ca test khi ấy chỉ đòi `takeException()` trả `null`
/// nên nó xanh với một nút chết. Ca ở đây phải chạm THẬT vào nhãn và đòi
/// `ChonPhamViSheet` hiện ra.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/analytics/presentation/widgets/chon_pham_vi_sheet.dart';
import 'package:flowmoney/features/auth/data/models/user_model.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository.dart';
import 'package:flowmoney/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:flowmoney/features/transaction/presentation/pages/transaction_page.dart';
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

/// Ghi lại **khoảng** mà trang hỏi tới, để biết mũi tên lùi hay tiến.
class _GhiKhoangRepository implements TransactionRepository {
  final List<({DateTime from, DateTime to})> daHoi = [];

  @override
  Stream<List<TransactionEntity>> watchKhoang(
    int idaccount,
    DateTime from,
    DateTime to,
  ) {
    daHoi.add((from: from, to: to));
    return Stream.value(const <TransactionEntity>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late _GhiKhoangRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = _GhiKhoangRepository();
    sl.registerSingleton<AppDatabase>(db);
    sl.registerFactory<TransactionBloc>(
      () => TransactionBloc(transactionRepository: repo),
    );
  });

  tearDown(() async {
    await sl.reset();
    await db.close();
  });

  /// ⚠️ **BẮT BUỘC gọi ở cuối MỖI ca**, trong thân ca chứ không phải
  /// `addTearDown` — `addTearDown` chạy *sau* khi khung kiểm của Flutter đã chốt
  /// nên nó quá muộn (vấp thật ngày 2026-09-21: lần chạy đầu treo quá 400 giây,
  /// lần sau vẫn đỏ với "A Timer is still pending").
  ///
  /// Trang giữ hai `StreamBuilder` trên stream của drift; lúc chúng huỷ đăng ký
  /// thì `StreamQueryStore.markAsClosed` đặt một `Timer`. `pump()` KHÔNG tham số
  /// chỉ dựng lại khung hình — nó không đẩy đồng hồ, mà Timer chỉ nổ khi có thời
  /// gian trôi qua. Thiếu `Duration` ở đây là **cả tệp kẹt lại**.
  ///
  /// Cùng khuôn với `dongTrang` của `notification_center_page_test.dart`
  /// (bẫy 7.13 `NOTIFICATION_FEATURE.md`).
  Future<void> dongTrang(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> moTrang(WidgetTester tester) async {
    final auth = _FixedAuthBloc(AuthSuccess(
      user: UserModel(
        id: '7',
        username: 'dat',
        name: 'Đạt',
        email: 'dat@example.com',
      ),
    ));
    addTearDown(auth.close);

    await tester.pumpWidget(
      MaterialApp(
        // ⚠️ Theme thật, không `MaterialApp` trần: theme của app ép mọi
        // `ElevatedButton` rộng vô hạn (bẫy 4.11), nên một bố cục hỏng chỉ lộ
        // ra khi dựng bằng đúng theme đang chạy.
        theme: AppTheme.lightTheme,
        home: BlocProvider<AuthBloc>.value(
          value: auth,
          child: const TransactionPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('nhãn giữa mang nếp "… này" khi kỳ chứa hôm nay', (tester) async {
    await moTrang(tester);
    expect(find.textContaining('Tháng này'), findsOneWidget,
        reason: 'mở trang là ở tháng hiện tại, và `nhanRong` thêm nếp ấy');
    await dongTrang(tester);
  });

  testWidgets('mũi tên trái LÙI một kỳ, mũi tên phải TIẾN lại', (tester) async {
    await moTrang(tester);
    final khoangDau = repo.daHoi.last;

    await tester.tap(find.byTooltip('Kỳ trước'));
    await tester.pumpAndSettle();
    final sauKhiLui = repo.daHoi.last;
    expect(sauKhiLui.from.isBefore(khoangDau.from), isTrue,
        reason: 'mũi tên TRÁI phải lùi — đổi dấu là nó tiến, và nhãn vẫn đổi '
            'nên nhìn qua trông vẫn đúng');
    expect(sauKhiLui.to, khoangDau.from,
        reason: 'kỳ liền trước khép lại đúng lúc kỳ này bắt đầu — biên [from, to)');

    await tester.tap(find.byTooltip('Kỳ sau'));
    await tester.pumpAndSettle();
    expect(repo.daHoi.last.from, khoangDau.from,
        reason: 'tiến lại một kỳ phải về đúng chỗ cũ');
    await dongTrang(tester);
  });

  testWidgets('nhãn giữa KHÔNG phải chữ chết: chạm vào là mở bộ chọn kỳ',
      (tester) async {
    await moTrang(tester);
    await tester.tap(find.byKey(const Key('so-giao-dich-chon-ky')));
    await tester.pumpAndSettle();

    expect(find.byType(ChonPhamViSheet), findsOneWidget,
        reason: 'dùng CHUNG sheet với trang Phân tích và Xuất báo cáo — dựng bộ '
            'chọn thứ hai là hai luật kỳ phải giữ đồng bộ bằng tay');
    expect(tester.takeException(), isNull);
    await dongTrang(tester);
  });

  testWidgets('chọn một kỳ khác trong sheet thì trang hỏi đúng khoảng ấy',
      (tester) async {
    await moTrang(tester);
    final khoangDau = repo.daHoi.last;

    await tester.tap(find.byKey(const Key('so-giao-dich-chon-ky')));
    await tester.pumpAndSettle();
    // Tầng một: đổi đơn vị sang Năm. Tầng hai: chọn kỳ đầu danh sách.
    await tester.tap(find.text('Năm').last);
    await tester.pumpAndSettle();
    // ⚠️ `textContaining`, không `find.text`: dòng đầu danh sách mang nhãn
    // **"Năm nay (2026)"** — `nhanRong` thêm nếp "… này" cho kỳ chứa hôm nay,
    // nên so khớp chính xác không tìm thấy gì.
    await tester.tap(find.textContaining('Năm nay').last);
    await tester.pumpAndSettle();

    final sauKhiChon = repo.daHoi.last;
    expect(sauKhiChon.from, isNot(khoangDau.from),
        reason: 'kỳ năm bắt đầu 1/1, khác mốc đầu tháng');
    expect(sauKhiChon.to.difference(sauKhiChon.from).inDays, greaterThan(300),
        reason: 'một năm chứ không phải một tháng');
    await dongTrang(tester);
  });
}
