/// Áp dụng kế hoạch tái phân bổ — hai hàm thuần (Edge-SLM P2, Task 15).
///
/// `hanMucMoi`: hạn mức mới của từng bên; **tổng hạn mức không đổi** (cắt X ở
/// nguồn bù thì cộng đúng X vào ngân sách thâm hụt) — đó là lý do D5 bỏ được.
/// `phanHoiTu`: mỗi dòng kế hoạch thành một hàng `AiRebalancingFeedbacks` với
/// `action` đúng quyết định của người dùng.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flowmoney/features/ai_edge/domain/ap_dung_ke_hoach.dart';
import 'package:flowmoney/features/ai_edge/domain/tai_phan_bo.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 9, 21, 10);

BudgetView _v(String id, {required double amount, double spent = 0}) =>
    BudgetView(
      budget: BudgetEntity(
        id: id,
        idaccount: 7,
        categoryId: 'c-$id',
        amount: amount,
        spent: spent,
        startDate: DateTime(2026, 9, 1),
        recurrence: true,
        timeRecurrence: BudgetRecurrence.month,
        updatedAt: DateTime(2026, 9, 1),
      ),
      categoryName: id,
    );

final _thieu = _v('an', amount: 3000000, spent: 2800000);
final _d1 = _v('giaiTri', amount: 2000000, spent: 300000);
final _d2 = _v('muaSam', amount: 1500000, spent: 400000);

KeHoachTaiPhanBo _keHoach({List<DongTaiPhanBo>? dong}) => KeHoachTaiPhanBo(
      thieu: _thieu,
      duPhong: 3600000,
      thamHut: 600000,
      dong: dong ??
          [
            DongTaiPhanBo(nguon: _d1, duDia: 1700000, soTien: 500000),
            DongTaiPhanBo(nguon: _d2, duDia: 1100000, soTien: 100000),
          ],
      trangThai: TrangThaiKeHoach.duNguonBu,
      soThieu: 0,
    );

double _tong(List<(BudgetEntity, double)> ds) =>
    ds.fold(0.0, (s, e) => s + e.$2);

void main() {
  group('hanMucMoi', () {
    test('chọn cả hai dòng giữ số đề xuất → hai nguồn trừ, thâm hụt cộng Σ',
        () {
      final ra = hanMucMoi(_keHoach(), {'giaiTri': 500000, 'muaSam': 100000});

      final theoId = {for (final e in ra) e.$1.id: e.$2};
      expect(theoId['giaiTri'], 1500000);
      expect(theoId['muaSam'], 1400000);
      expect(theoId['an'], 3600000);
      expect(ra, hasLength(3));
    });

    test('chọn một dòng và sửa số → chỉ dòng ấy trừ, thâm hụt cộng đúng số sửa',
        () {
      final ra = hanMucMoi(_keHoach(), {'giaiTri': 300000});

      final theoId = {for (final e in ra) e.$1.id: e.$2};
      expect(theoId['giaiTri'], 1700000);
      expect(theoId.containsKey('muaSam'), isFalse,
          reason: 'Dòng không tick thì không sinh lượt updateBudget nào.');
      expect(theoId['an'], 3300000);
    });

    test('⚠️ TỔNG HẠN MỨC KHÔNG ĐỔI — Σ trước = Σ sau', () {
      final kh = _keHoach();
      final truoc = kh.thieu.budget.amount +
          kh.dong.fold(0.0, (s, d) => s + d.nguon.budget.amount);
      final ra = hanMucMoi(kh, {'giaiTri': 500000, 'muaSam': 100000});
      // Cộng cả ngân sách không đổi (ở đây không có) để so đúng tổng.
      final sau = _tong(ra);
      expect(sau, truoc,
          reason: 'Tái phân bổ là chuyển hạn mức, không phải thêm: cắt X thì '
              'cộng đúng X. Đó là lý do D5 (trần Σ hạn mức) bỏ được — vi phạm '
              'ở đây là D5 phải quay lại.');
    });

    test('không dòng nào chọn → rỗng, không đụng ngân sách thâm hụt', () {
      expect(hanMucMoi(_keHoach(), const {}), isEmpty);
      expect(hanMucMoi(_keHoach(), {'giaiTri': 0}), isEmpty);
    });

    test('số cắt vượt dư địa hoặc âm → ArgumentError', () {
      expect(() => hanMucMoi(_keHoach(), {'giaiTri': 1700001}),
          throwsArgumentError,
          reason: 'Cắt quá dư địa là đẩy nguồn bù vào thâm hụt — sheet phải '
              'chặn trước, hàm thuần chặn lần nữa.');
      expect(() => hanMucMoi(_keHoach(), {'giaiTri': -1}), throwsArgumentError);
    });

    test('id lạ (không phải nguồn bù của kế hoạch) bị bỏ qua', () {
      expect(hanMucMoi(_keHoach(), {'la': 100000}), isEmpty);
    });
  });

  group('phanHoiTu', () {
    test('tick giữ số → accepted; tick đổi số → modified; không tick → rejected',
        () {
      final ra = phanHoiTu(
        _keHoach(),
        {'giaiTri': 500000},
        idaccount: 7,
        now: _now,
        boQua: false,
      );
      expect(ra, hasLength(2));
      final theoDonor = {for (final r in ra) r.donorBudgetId.value: r};
      expect(theoDonor['giaiTri']!.action.value, 'accepted');
      expect(theoDonor['giaiTri']!.actualAmount.value, 500000);
      expect(theoDonor['giaiTri']!.suggestedAmount.value, 500000);
      expect(theoDonor['muaSam']!.action.value, 'rejected');
      expect(theoDonor['muaSam']!.actualAmount.value, 0);

      final sua = phanHoiTu(_keHoach(), {'giaiTri': 300000},
          idaccount: 7, now: _now, boQua: false);
      final r = sua.firstWhere((x) => x.donorBudgetId.value == 'giaiTri');
      expect(r.action.value, 'modified');
      expect(r.actualAmount.value, 300000);
    });

    test('boQua → mọi dòng rejected dù có số', () {
      final ra = phanHoiTu(_keHoach(), {'giaiTri': 500000, 'muaSam': 100000},
          idaccount: 7, now: _now, boQua: true);
      expect(ra.every((r) => r.action.value == 'rejected'), isTrue);
      expect(ra.every((r) => r.actualAmount.value == 0), isTrue);
    });

    test('hàng mang đủ khoá C3: deficit, donor, danh mục nguồn, kỳ của NGUỒN',
        () {
      final ra = phanHoiTu(_keHoach(), {'giaiTri': 500000},
          idaccount: 7, now: _now, boQua: false);
      final r = ra.first;
      expect(r.idaccount.value, 7);
      expect(r.deficitBudgetId.value, 'an');
      expect(r.donorCategoryId.value, 'c-giaiTri');
      expect(r.createdAt.value, _now);
      // Kỳ tháng 9 của nguồn bù — luật C3 đếm "hai kỳ liền trước" bằng cặp này,
      // qua chính `currentPeriod` của ngân sách nguồn.
      final ky = _d1.budget.currentPeriod(_now);
      expect(r.periodFrom.value, ky.from);
      expect(r.periodTo.value, ky.to);
      expect(r.id, isA<Value<String>>());
      expect(r.id.value, isNotEmpty);
      expect(ra.map((x) => x.id.value).toSet(), hasLength(ra.length),
          reason: 'Mỗi hàng một id — khoá chính.');
    });
  });
}
