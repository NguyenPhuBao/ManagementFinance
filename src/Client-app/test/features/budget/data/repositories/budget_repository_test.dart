/// Ngân sách: số "đã chi" phải tính lại từ bảng giao dịch, không tin cột `spent`.
///
/// Vì sao cần: cột `Spent` có ở cả SQLite lẫn PostgreSQL nhưng **không bên nào
/// cập nhật nó** — backend không có tác vụ nền tính lại, còn giao dịch thì
/// người dùng ghi được khi offline. Nếu giao diện đọc thẳng cột đó, thanh tiến
/// trình sẽ đứng ở 0 mãi mãi trong khi tiền vẫn ra: sai **âm thầm**, không
/// exception, không log — đúng lớp lỗi mà bộ test này canh chừng.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/budget/data/datasources/budget_local_data_source.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository_impl.dart';

void main() {
  const idaccount = 7;
  const walletId = '11111111-1111-4111-8111-111111111111';
  const anUong = '22222222-2222-4222-8222-222222222222';
  const muaSam = '33333333-3333-4333-8333-333333333333';

  // Mốc thời gian cố định — test không được phụ thuộc đồng hồ máy chạy nó.
  final now = DateTime(2026, 6, 15, 12);
  final dauThang = DateTime(2026, 6, 1);

  late AppDatabase db;
  late BudgetRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BudgetRepositoryImpl(
      localDataSource: BudgetLocalDataSourceImpl(db: db),
      // syncEngine để null: test này đo logic tính toán, không đo việc đẩy dữ
      // liệu. Repository phải chạy được khi chưa có engine.
      syncEngine: null,
    );

    await db.walletDao.insert(WalletsCompanion(
      id: const Value(walletId),
      idaccount: const Value(idaccount),
      name: const Value('Tiền mặt'),
      balance: const Value(10000000),
      updatedAt: Value(now),
    ));
    await db.categoryDao.insert(CategoriesCompanion(
      id: const Value(anUong),
      idaccount: const Value(idaccount),
      name: const Value('Ăn uống'),
      classify: const Value('chi'),
      updatedAt: Value(now),
    ));
    await db.categoryDao.insert(CategoriesCompanion(
      id: const Value(muaSam),
      idaccount: const Value(idaccount),
      name: const Value('Mua sắm'),
      classify: const Value('chi'),
      updatedAt: Value(now),
    ));
  });

  tearDown(() => db.close());

  Future<void> ghiGiaoDich({
    required String id,
    required double amount,
    String type = 'chi',
    String? categoryId = anUong,
    DateTime? date,
  }) {
    return db.transactionDao.insert(TransactionsCompanion(
      id: Value(id),
      idaccount: const Value(idaccount),
      walletId: const Value(walletId),
      categoryId: Value(categoryId),
      amount: Value(amount),
      type: Value(type),
      date: Value(date ?? now),
      updatedAt: Value(now),
    ));
  }

  Future<BudgetEntity> taoNganSach({
    String? categoryId = anUong,
    double amount = 5000000,
    DateTime? startDate,
    bool recurrence = true,
    String timeRecurrence = BudgetRecurrence.month,
    double? thresholdWarningAmount,
  }) {
    return repo.addBudget(
      idaccount: idaccount,
      amount: amount,
      categoryId: categoryId,
      startDate: startDate ?? dauThang,
      recurrence: recurrence,
      timeRecurrence: timeRecurrence,
      thresholdWarningAmount: thresholdWarningAmount,
    );
  }

  group('Số đã chi được tính từ giao dịch', () {
    test('cộng đúng các khoản chi thuộc danh mục của ngân sách', () async {
      await taoNganSach();
      await ghiGiaoDich(id: 't1', amount: 200000);
      await ghiGiaoDich(id: 't2', amount: 300000);

      final views = await repo.getBudgets(idaccount, now: now);

      expect(views.single.budget.spent, 500000,
          reason: 'Phải cộng từ bảng giao dịch. Cột `spent` lúc tạo là 0, nên '
              'nếu kết quả ra 0 nghĩa là giao diện đang đọc thẳng cột đó.');
      expect(views.single.budget.remaining, 4500000);
    });

    test('bỏ qua khoản thu — chỉ tính chi', () async {
      await taoNganSach();
      await ghiGiaoDich(id: 't1', amount: 200000);
      await ghiGiaoDich(id: 't2', amount: 900000, type: 'thu');

      final views = await repo.getBudgets(idaccount, now: now);

      expect(views.single.budget.spent, 200000,
          reason: 'Ngân sách là hạn mức CHI. Khoản thu lọt vào sẽ làm hạn mức '
              'phình ra một cách vô nghĩa.');
    });

    test('bỏ qua khoản chi thuộc danh mục khác', () async {
      await taoNganSach(categoryId: anUong);
      await ghiGiaoDich(id: 't1', amount: 200000, categoryId: anUong);
      await ghiGiaoDich(id: 't2', amount: 800000, categoryId: muaSam);

      final views = await repo.getBudgets(idaccount, now: now);

      expect(views.single.budget.spent, 200000);
    });

    test('ngân sách tổng (không danh mục) cộng mọi khoản chi', () async {
      await taoNganSach(categoryId: null);
      await ghiGiaoDich(id: 't1', amount: 200000, categoryId: anUong);
      await ghiGiaoDich(id: 't2', amount: 800000, categoryId: muaSam);
      await ghiGiaoDich(id: 't3', amount: 50000, categoryId: null);

      final views = await repo.getBudgets(idaccount, now: now);

      expect(views.single.budget.spent, 1050000,
          reason: 'categoryId null nghĩa là ngân sách tổng — kể cả giao dịch '
              'chưa gán danh mục cũng phải tính vào.');
      expect(views.single.displayName, 'Ngân sách tổng');
    });

    test('bỏ qua giao dịch đã xoá mềm', () async {
      await taoNganSach();
      await ghiGiaoDich(id: 't1', amount: 200000);
      await ghiGiaoDich(id: 't2', amount: 300000);
      await db.transactionDao.softDelete('t2');

      final views = await repo.getBudgets(idaccount, now: now);

      expect(views.single.budget.spent, 200000,
          reason: 'Xoá giao dịch phải trả lại hạn mức đã dùng.');
    });
  });

  group('Chu kỳ ngân sách', () {
    test('chu kỳ tháng không tính giao dịch của tháng trước', () async {
      await taoNganSach(startDate: DateTime(2026, 1, 1));
      await ghiGiaoDich(
          id: 't-cu', amount: 900000, date: DateTime(2026, 5, 20));
      await ghiGiaoDich(id: 't-nay', amount: 100000, date: now);

      final views = await repo.getBudgets(idaccount, now: now);

      expect(views.single.budget.spent, 100000,
          reason: 'Ngân sách lặp hàng tháng phải reset mỗi chu kỳ. Cộng dồn cả '
              'các tháng trước sẽ báo vượt hạn mức ngay đầu tháng.');
    });

    test('chu kỳ tuần chỉ tính trong tuần đang chạy', () async {
      await taoNganSach(
        startDate: DateTime(2026, 6, 1),
        timeRecurrence: BudgetRecurrence.week,
      );
      // 2026-06-15 nằm trong chu kỳ 15/6–22/6 (mốc nhảy 7 ngày từ 1/6).
      await ghiGiaoDich(
          id: 't-tuan-truoc', amount: 400000, date: DateTime(2026, 6, 10));
      await ghiGiaoDich(
          id: 't-tuan-nay', amount: 70000, date: DateTime(2026, 6, 16));

      final views = await repo.getBudgets(idaccount, now: now);

      expect(views.single.budget.spent, 70000);
    });

    test('không lặp thì cộng dồn từ ngày bắt đầu tới hiện tại', () async {
      await taoNganSach(
        startDate: DateTime(2026, 1, 1),
        recurrence: false,
      );
      await ghiGiaoDich(id: 't1', amount: 400000, date: DateTime(2026, 2, 3));
      await ghiGiaoDich(id: 't2', amount: 100000, date: now);

      final views = await repo.getBudgets(idaccount, now: now);

      expect(views.single.budget.spent, 500000);
    });

    test('ngân sách đặt cho tương lai chưa tính khoản nào', () async {
      await taoNganSach(
        startDate: DateTime(2026, 12, 1),
        recurrence: false,
      );
      await ghiGiaoDich(id: 't1', amount: 400000, date: now);

      final views = await repo.getBudgets(idaccount, now: now);

      expect(views.single.budget.spent, 0,
          reason: 'Khoảng cộng dồn phải rỗng chứ không được đảo ngược thành '
              '[tương lai, hiện tại] rồi quét ngược về quá khứ.');
    });
  });

  group('Cảnh báo và vượt hạn mức', () {
    test('tiêu vượt: percentSpent cắt trần ở 1.0, overAmount cho số thật',
        () async {
      await taoNganSach(amount: 1000000);
      await ghiGiaoDich(id: 't1', amount: 1500000);

      final b = (await repo.getBudgets(idaccount, now: now)).single.budget;

      expect(b.isOverBudget, isTrue);
      expect(b.percentSpent, 1.0,
          reason: 'Thanh tiến trình không được tràn ra ngoài khung.');
      expect(b.rawPercentSpent, 1.5);
      expect(b.overAmount, 500000);
      expect(b.remaining, -500000);
    });

    test('ngưỡng theo số tiền còn lại được ưu tiên hơn mốc 90%', () async {
      await taoNganSach(amount: 1000000, thresholdWarningAmount: 400000);
      // Mới tiêu 50% — chưa chạm mốc 90% mặc định, nhưng còn lại 500k > 400k
      // nên cũng chưa cảnh báo.
      await ghiGiaoDich(id: 't1', amount: 500000);
      expect(
          (await repo.getBudgets(idaccount, now: now)).single.budget.isNearLimit,
          isFalse);

      // Còn lại đúng 400k → chạm ngưỡng người dùng đặt, dù mới tiêu 60%.
      await ghiGiaoDich(id: 't2', amount: 100000);
      expect(
          (await repo.getBudgets(idaccount, now: now)).single.budget.isNearLimit,
          isTrue,
          reason: 'Ngưỡng người dùng đặt phải thắng mốc mặc định 90%.');
    });

    test('không đặt ngưỡng thì dùng mốc 90%', () async {
      await taoNganSach(amount: 1000000);
      await ghiGiaoDich(id: 't1', amount: 890000);
      expect(
          (await repo.getBudgets(idaccount, now: now)).single.budget.isNearLimit,
          isFalse);

      await ghiGiaoDich(id: 't2', amount: 20000);
      expect(
          (await repo.getBudgets(idaccount, now: now)).single.budget.isNearLimit,
          isTrue);
    });

    test('đã vượt hẳn thì không còn là "gần chạm ngưỡng"', () async {
      await taoNganSach(amount: 1000000);
      await ghiGiaoDich(id: 't1', amount: 1200000);

      final b = (await repo.getBudgets(idaccount, now: now)).single.budget;
      expect(b.isOverBudget, isTrue);
      expect(b.isNearLimit, isFalse,
          reason: 'Hai trạng thái loại trừ nhau — giao diện chọn màu theo cặp '
              'này, để cả hai cùng bật sẽ hiện hai cảnh báo chồng nhau.');
    });
  });

  group('Ghi dữ liệu', () {
    test('tạo ngân sách sinh id UUID hợp lệ và đánh dấu chờ đẩy', () async {
      final b = await taoNganSach();

      expect(
        b.id,
        matches(RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            caseSensitive: false)),
        reason: 'Backend khai báo Idbudget VarChar(36) và /sync/push từ chối '
            'id không đúng dạng UUID.',
      );
      expect(b.syncStatus, 'pending');
      expect(await db.budgetDao.getPending(idaccount), hasLength(1));
    });

    test('từ chối tạo khi chưa có phiên đăng nhập', () async {
      expect(
        () => repo.addBudget(idaccount: 0, amount: 1000),
        throwsArgumentError,
        reason: 'idaccount CHỈ đến từ phiên đăng nhập. Mặc định về 1 sẽ ghi dữ '
            'liệu dưới danh nghĩa tài khoản admin THẬT.',
      );
    });

    test('từ chối hạn mức không dương', () async {
      expect(() => repo.addBudget(idaccount: idaccount, amount: 0),
          throwsArgumentError);
      expect(() => repo.addBudget(idaccount: idaccount, amount: -5),
          throwsArgumentError);
    });

    test('xoá là xoá mềm — hàng vẫn còn để đẩy cờ xoá lên backend', () async {
      final b = await taoNganSach();
      await repo.deleteBudget(b.id);

      expect(await repo.getBudgets(idaccount, now: now), isEmpty);

      final row = await db.budgetDao.getById(b.id);
      expect(row, isNotNull,
          reason: 'Không xoá vật lý dữ liệu người dùng.');
      expect(row!.isDeleted, isTrue);
      expect(row.deletedAt, isNotNull,
          reason: 'Cả hai cờ phải được đặt: getAll lọc theo deletedAt.');
    });

    test('sửa hạn mức không làm mất số đã chi vừa tính', () async {
      final b = await taoNganSach(amount: 1000000);
      await ghiGiaoDich(id: 't1', amount: 300000);
      await repo.getBudgets(idaccount, now: now); // để cacheSpent chạy

      await repo.updateBudget(b.copyWith(amount: 2000000));

      final view = (await repo.getBudgets(idaccount, now: now)).single;
      expect(view.budget.amount, 2000000);
      expect(view.budget.spent, 300000,
          reason: 'updateBudget cố ý không ghi cột spent — đưa nó vào companion '
              'sẽ đè mất con số cacheSpent vừa tính.');
    });
  });

  group('Cột spent được lưu lại nhưng không sinh thao tác đẩy thừa', () {
    test('đọc xong thì cột spent khớp với số tính được', () async {
      final b = await taoNganSach();
      await ghiGiaoDich(id: 't1', amount: 250000);

      await repo.getBudgets(idaccount, now: now);

      final row = await db.budgetDao.getById(b.id);
      expect(row!.spent, 250000,
          reason: 'Ghi lại để lần đẩy sau gửi đúng số, thay vì gửi 0 rồi ghi đè '
              'giá trị trên server.');
    });

    test('cập nhật spent không làm đổi updatedAt', () async {
      final b = await taoNganSach();
      final truoc = (await db.budgetDao.getById(b.id))!.updatedAt;

      await ghiGiaoDich(id: 't1', amount: 250000);
      await repo.getBudgets(idaccount, now: now);

      final sau = (await db.budgetDao.getById(b.id))!.updatedAt;
      expect(sau, truoc,
          reason: 'updatedAt nhảy lên sẽ khiến LWW cho client thắng oan trước '
              'một thay đổi thật từ máy khác.');
    });
  });

  group('Theo dõi thay đổi', () {
    test('ghi giao dịch mới làm stream phát lại số đã chi', () async {
      await taoNganSach();

      final stream = repo.watchBudgets(idaccount, now: now);
      final phatRa = <double>[];
      final sub = stream.listen((views) {
        if (views.isNotEmpty) phatRa.add(views.single.budget.spent);
      });

      // Chờ lần phát đầu tiên rồi mới ghi giao dịch.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await ghiGiaoDich(id: 't1', amount: 120000);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await sub.cancel();

      expect(phatRa, isNotEmpty);
      expect(phatRa.first, 0);
      expect(phatRa.last, 120000,
          reason: 'Thanh tiến trình phải nhúc nhích ngay khi ghi khoản chi, '
              'không đợi người dùng mở lại trang.');
    });
  });
}
