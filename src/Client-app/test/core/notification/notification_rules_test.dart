/// Bộ luật sinh thông báo — phần ngân sách.
///
/// Hai điều đáng canh nhất, và cả hai đều hỏng âm thầm:
///
/// 1. **Luật phải GỌI `BudgetEntity`, không được cài lại mốc.** Cài lại là hai
///    nơi cùng quyết định "sắp vượt": màu trên thẻ nói một đằng, thông báo nói
///    một nẻo, và không ai biết bên nào đúng.
/// 2. **`dedupeKey` không được chứa số biến thiên.** Nhét `spent` vào là mỗi
///    giao dịch đẻ một thông báo mới — người dùng tắt thông báo và không bao
///    giờ bật lại.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/notification/notification_rules.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';

void main() {
  final now = DateTime(2026, 9, 15, 10);

  BudgetView nganSach({
    String id = 'b1',
    double amount = 5000000,
    required double spent,
    double? nguongTien,
    double? nguongPhanTram,
    DateTime? batDau,
    String? chuKy = BudgetRecurrence.month,
    bool lapLai = true,
    String? tenDanhMuc = 'Ăn uống',
  }) {
    return BudgetView(
      budget: BudgetEntity(
        id: id,
        idaccount: 7,
        categoryId: 'cat-an-uong',
        amount: amount,
        spent: spent,
        thresholdWarningAmount: nguongTien,
        thresholdWarningPercent: nguongPhanTram,
        overSpending: 'Over',
        startDate: batDau ?? DateTime(2026, 9, 1),
        recurrence: lapLai,
        timeRecurrence: chuKy,
        note: '',
        isDeleted: false,
        syncStatus: 'synced',
        updatedAt: DateTime(2026, 9, 1),
      ),
      categoryName: tenDanhMuc,
    );
  }

  List<NotificationCandidate> chay(List<BudgetView> budgets) {
    return buildNotificationCandidates(
      NotificationRuleInput(now: now, budgets: budgets),
    );
  }

  group('khi nào sinh', () {
    test('dưới ngưỡng thì không sinh gì', () {
      expect(chay([nganSach(spent: 2000000)]), isEmpty,
          reason: '40% hạn mức — chưa có gì để báo. Báo sớm quá thì người dùng '
              'quen với việc bỏ qua thông báo.');
    });

    test('chạm ngưỡng mặc định 90% thì sinh cảnh báo', () {
      final ra = chay([nganSach(spent: 4500000)]).single;
      expect(ra.kind, NotificationKind.budgetNearLimit);
      expect(ra.severity, NotificationSeverity.warning);
      expect(ra.deeplink, '/budget');
    });

    test('vượt hạn mức thì sinh budgetOverspent, KHÔNG sinh cả hai', () {
      final ra = chay([nganSach(spent: 6000000)]);
      expect(ra.length, 1,
          reason: 'Một ngân sách vượt hạn mức không được vừa báo "sắp vượt" '
              'vừa báo "đã vượt" — `isNearLimit` trả false khi đã vượt, và '
              'luật phải tôn trọng điều đó thay vì tự kiểm lại tỉ lệ.');
      expect(ra.single.kind, NotificationKind.budgetOverspent);
      expect(ra.single.severity, NotificationSeverity.critical);
    });

    test('ngưỡng theo số tiền thắng ngưỡng phần trăm', () {
      // 60% hạn mức nên ngưỡng 90% chưa chạm, nhưng còn lại 2tr ≤ ngưỡng 2tr.
      final ra = chay([
        nganSach(spent: 3000000, nguongTien: 2000000, nguongPhanTram: 90)
      ]);
      expect(ra.length, 1,
          reason: 'Đây là phép canh việc luật GỌI BudgetEntity.isNearLimit. '
              'Bất kỳ ai cài lại bằng `rawPercentSpent >= 0.9` sẽ làm test này '
              'đỏ ngay.');
      expect(ra.single.kind, NotificationKind.budgetNearLimit);
    });

    test('ngân sách đã hết hạn thì không nhắc nữa', () {
      final ra = chay([
        nganSach(
          spent: 4900000,
          batDau: DateTime(2026, 1, 1),
          lapLai: false,
          chuKy: BudgetRecurrence.month,
        )
      ]);
      expect(ra, isEmpty,
          reason: 'Ngân sách chết từ tháng 2 mà tháng 9 vẫn nhắc là nhiễu '
              'thuần tuý — người dùng không làm gì được với nó.');
    });

    test('hạn mức 0 không sinh cảnh báo lạ', () {
      final ra = chay([nganSach(amount: 0, spent: 0)]);
      expect(ra, isEmpty,
          reason: 'Hạn mức 0 kéo về từ backend cho ra Infinity/NaN khi chia. '
              'NaN so với mọi mốc đều false nên dễ lọt thành "an toàn" — '
              'nhưng cũng không được biến thành cảnh báo giả.');
    });
  });

  group('dedupeKey', () {
    String khoa(List<BudgetView> b) => chay(b).single.dedupeKey;

    test('KHÔNG đổi khi số đã chi tăng trong cùng một bậc', () {
      // 4.5tr và 4.7tr đều nằm trong bậc `critical` (≥90%, chưa vượt).
      expect(khoa([nganSach(spent: 4500000)]),
          khoa([nganSach(spent: 4700000)]),
          reason: 'Đây là cách hỏng kinh điển: nhét `spent` vào khoá thì mỗi '
              'giao dịch mới đẻ thêm một thông báo giống hệt.');
    });

    test('ĐỔI khi leo lên một bậc mới', () {
      // Ngưỡng 60% để bậc `caution` (70%) cũng sinh được cảnh báo.
      final canhBao = khoa([nganSach(spent: 3600000, nguongPhanTram: 60)]);
      final nguyKich = khoa([nganSach(spent: 4600000, nguongPhanTram: 60)]);
      expect(canhBao == nguyKich, false,
          reason: 'Mỗi bậc được nhắc đúng một lần trong kỳ. Không phân biệt '
              'bậc thì người dùng chỉ được báo ở mốc 70% rồi im lặng cho tới '
              'lúc vượt hẳn.');
    });

    test('ĐỔI khi sang kỳ ngân sách mới', () {
      final thangNay = buildNotificationCandidates(NotificationRuleInput(
        now: DateTime(2026, 9, 15),
        budgets: [nganSach(spent: 4600000)],
      )).single.dedupeKey;
      final thangSau = buildNotificationCandidates(NotificationRuleInput(
        now: DateTime(2026, 10, 15),
        budgets: [nganSach(spent: 4600000)],
      )).single.dedupeKey;

      expect(thangNay == thangSau, false,
          reason: 'Kỳ mới là sự kiện mới. Khoá không đổi thì ngân sách chỉ '
              'được cảnh báo đúng một lần trong đời.');
    });

    test('khác ngân sách thì khác khoá', () {
      expect(
        khoa([nganSach(id: 'b1', spent: 4600000)]) ==
            khoa([nganSach(id: 'b2', spent: 4600000)]),
        false,
      );
    });
  });

  group('nội dung', () {
    test('nhắc tên danh mục, đúng như thiết kế', () {
      final ra = chay([nganSach(spent: 4600000, tenDanhMuc: 'Ăn uống')]).single;
      expect(ra.body, contains('Ăn uống'),
          reason: 'Thiết kế Stitch viết "Bạn đã chi tiêu vượt 80% ngân sách Ăn '
              'uống" — không có tên danh mục thì người dùng phải mở app ra mới '
              'biết thông báo nói về cái gì.');
      expect(ra.subjectType, 'budget');
      expect(ra.subjectId, 'b1');
    });

    test('ngân sách tổng không có tên danh mục vẫn đọc được', () {
      final ra = chay([nganSach(spent: 4600000, tenDanhMuc: null)]).single;
      expect(ra.body, contains('Ngân sách tổng'),
          reason: 'BudgetView.displayName đã lo sẵn nhánh này — luật chỉ việc '
              'dùng, không tự ghép chuỗi null.');
    });
  });
}
