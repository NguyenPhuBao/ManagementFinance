/// G78 — chữ phụ bị cụt ở màn HẸP (Realme để cỡ hiển thị lớn: mật độ 540 →
/// 320 dp), hai thẻ trên trang Ngân sách: tiêu đề *"ĐỀ XUẤT CÂN ĐỐI · KH…"*
/// (thẻ kế hoạch tái phân bổ) và *"khoảng 2.010.000 đ m…"* (thẻ Chưa đặt ngân
/// sách). Sửa: chữ phụ được xuống tối đa hai dòng thay vì cắt; số tiền dính liền
/// với "đ" (`formatLienKhoi`).
///
/// ⚠️ `napFontThat` nạp font cho cả isolate — tệp này chỉ chứa ca đo font thật.
library;

import 'package:flowmoney/features/ai_edge/domain/tai_phan_bo.dart';
import 'package:flowmoney/features/ai_edge/presentation/widgets/the_ke_hoach.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/domain/de_xuat_ngan_sach.dart';
import 'package:flowmoney/features/budget/presentation/widgets/the_de_xuat_ngan_sach.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/font_that.dart';

BudgetView _v(String id, String ten,
        {required double amount, double spent = 0}) =>
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
      categoryName: ten,
    );

KeHoachTaiPhanBo _thieuMotPhan() => KeHoachTaiPhanBo(
      thieu: _v('an', 'Ăn uống', amount: 3000000, spent: 2800000),
      duPhong: 3900000,
      thamHut: 900000,
      dong: [
        DongTaiPhanBo(
            nguon: _v('gt', 'Giải trí', amount: 2000000, spent: 300000),
            duDia: 1700000,
            soTien: 600000),
      ],
      trangThai: TrangThaiKeHoach.thieuNguonBu,
      soThieu: 300000,
    );

void main() {
  setUp(napFontThat);

  Future<void> dung(WidgetTester tester, double man, Widget con) async {
    tester.view.physicalSize = Size(man, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          // Lề ngang của trang Ngân sách.
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: con,
        ),
      ),
    ));
    await tester.pump();
  }

  void veTron(WidgetTester tester, Finder o, String vi) {
    expect(o, findsOneWidget);
    final rp = tester.renderObject<RenderParagraph>(o);
    expect(rp.didExceedMaxLines, isFalse,
        reason: '$vi: "${rp.text.toPlainText()}" bị cắt');
  }

  for (final man in [320.0, 300.0]) {
    testWidgets(
        'G78 · $man dp: tiêu đề thẻ cân đối "… KHÔNG ĐỦ DƯ ĐỊA" vẽ trọn',
        (tester) async {
      await dung(
          tester, man, TheKeHoach(keHoach: _thieuMotPhan(), onXem: null));
      expect(tester.takeException(), isNull);
      veTron(tester, find.textContaining('ĐỀ XUẤT CÂN ĐỐI'), '$man dp');
    });

    testWidgets('G78 · $man dp: dòng "khoảng … mỗi tháng" vẽ trọn',
        (tester) async {
      await dung(
        tester,
        man,
        TheDeXuatNganSach(
          goi: const GoiDeXuat(
            ds: [
              DeXuatNganSach(
                categoryId: 'nha',
                tenDanhMuc: 'Nhà cửa',
                mucThang: 2010000,
              ),
            ],
            soNgayCuaSo: 19,
            soUngVien: 1,
          ),
          onTao: (_) {},
        ),
      );
      expect(tester.takeException(), isNull);
      veTron(tester, find.textContaining('mỗi tháng'), '$man dp');
    });
  }
}
