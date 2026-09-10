/// Canh chừng G15: bản ghi vừa hết hạn vừa hỏng đồng bộ thì kẹt không lối ra.
///
/// Tab "Đã hết hạn" khoá cả sửa lẫn xoá — đúng yêu cầu, số liệu đã chốt sổ
/// không được đổi về sau. Nhưng khoá ấy không phân biệt **"đã chốt sổ"** với
/// **"hỏng, chưa bao giờ lên tới server"**.
///
/// Một ngân sách rơi vào cả hai trạng thái thì không đẩy lên được (backend từ
/// chối vĩnh viễn) mà người dùng cũng không mở ra sửa hay xoá được. Đã gặp thật
/// ngày 2026-09-04 với một ngân sách có `end = start`, vi phạm
/// `chk_budget_end_after_start`; lối thoát duy nhất là xoá dữ liệu site của
/// trình duyệt rồi pull lại từ server.
///
/// Nguyên tắc: **khoá thao tác là để bảo vệ số liệu đã chốt, không phải để nhốt
/// dữ liệu hỏng.**
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/domain/budget_locking.dart';

BudgetEntity _nganSach({String? loiDongBo}) => BudgetEntity(
      id: 'b1',
      idaccount: 7,
      categoryId: 'cat-an-uong',
      amount: 5000000,
      spent: 1000000,
      overSpending: 'Over',
      startDate: DateTime(2026, 8, 1),
      recurrence: false,
      note: '',
      isDeleted: false,
      syncStatus: loiDongBo == null ? 'synced' : 'pending',
      syncError: loiDongBo,
      updatedAt: DateTime(2026, 8, 1),
    );

void main() {
  group('budgetActionsLocked', () {
    test('đang chạy thì luôn mở', () {
      expect(
        budgetActionsLocked(expired: false, budget: _nganSach()),
        false,
      );
    });

    test('hết hạn và đồng bộ sạch thì khoá', () {
      expect(
        budgetActionsLocked(expired: true, budget: _nganSach()),
        true,
        reason: 'Đây là yêu cầu gốc và KHÔNG được nới: số liệu của một kỳ đã '
            'chốt sổ không được sửa về sau, vì tab hết hạn là nền cho phần '
            'thống kê.',
      );
    });

    test('hết hạn NHƯNG hỏng đồng bộ thì phải mở', () {
      final b = _nganSach(
        loiDongBo: 'new row for relation budget violates check constraint '
            'chk_budget_end_after_start',
      );
      expect(
        budgetActionsLocked(expired: true, budget: b),
        false,
        reason: 'Canh chừng G15. Bản ghi này không đẩy lên được và cũng không '
            'mở ra sửa hay xoá được — kẹt vĩnh viễn, lối thoát duy nhất là xoá '
            'dữ liệu site của trình duyệt. Khoá thao tác là để bảo vệ số liệu '
            'đã chốt, không phải để nhốt dữ liệu hỏng.',
      );
    });

    test('đang chạy và hỏng đồng bộ thì vẫn mở', () {
      expect(
        budgetActionsLocked(expired: false, budget: _nganSach(loiDongBo: 'x')),
        false,
      );
    });

    test('chuỗi lỗi RỖNG không tính là hỏng', () {
      expect(
        budgetActionsLocked(expired: true, budget: _nganSach(loiDongBo: '')),
        true,
        reason: 'Cột `syncError` được xoá về rỗng chứ không phải null ở vài '
            'đường ghi. Coi chuỗi rỗng là "đang hỏng" sẽ mở khoá cho mọi ngân '
            'sách hết hạn — tức bỏ luôn yêu cầu gốc mà không ai nhận ra.',
      );
    });
  });
}
