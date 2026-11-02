// Thanh tiến độ mục tiêu ở dòng ví của Nhà mình (đợt 2, Task 7).
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/household/presentation/widgets/nha_minh/khoi_vi_chung.dart';
import 'package:flowmoney/features/household/presentation/widgets/tien_do_muc_tieu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/du_lieu_nha_gia.dart';
import '../../../../../helpers/font_that.dart';
import '../../../../../helpers/nha_gia.dart';

GoalEntity _muc(String vi) => GoalEntity(
      id: 'g-$vi',
      idaccount: 18,
      idhousehold: 12,
      name: 'Mục tiêu',
      targetAmount: 20000000,
      targetDate: DateTime(2026, 12, 31),
      walletId: vi,
      updatedAt: DateTime(2026, 11, 1),
    );

void main() {
  setUpAll(napFontThat);

  Future<void> dung(WidgetTester t, KhoiViChung k) async {
    dat360(t);
    await t.pumpWidget(bocTrangNha(Scaffold(body: SingleChildScrollView(child: k)), idaccount: 18));
  }

  testWidgets('dongHo sau hạn thì dòng ví có nhãn Quá hạn', (t) async {
    await dung(
      t,
      KhoiViChung(
        vi: [viChungGia('a', 'Tiền chợ', 12000000)],
        tongQuy: 12000000,
        coTheTao: true,
        mucTieu: {'a': _muc('a')},
        dongHo: () => DateTime(2027, 1, 5),
      ),
    );
    final dong = find.byKey(const Key('dong-vi-a'));
    expect(find.descendant(of: dong, matching: find.text('Quá hạn')), findsOneWidget,
        reason: 'đồng hồ tiêm sau hạn 31/12/2026: phải dùng dongHo, không đọc giờ máy');
  });

  testWidgets('ví có mục tiêu có thanh, ví không có thì không; ví lưu trữ vẫn hiện thanh', (t) async {
    await dung(
      t,
      KhoiViChung(
        vi: [
          viChungGia('a', 'Tiền chợ', 12000000),
          viChungGia('b', 'Điện nước', 500000),
          viChungGia('c', 'Cũ', 5000000, status: 'inactive'),
        ],
        tongQuy: 12500000,
        coTheTao: true,
        mucTieu: {'a': _muc('a'), 'c': _muc('c')},
        dongHo: () => DateTime(2026, 11, 2, 10),
      ),
    );
    Finder thanhTrong(String id) =>
        find.descendant(of: find.byKey(Key('dong-vi-$id')), matching: find.byType(TienDoGon));
    expect(thanhTrong('a'), findsOneWidget);
    expect(thanhTrong('b'), findsNothing, reason: 'ví không đặt mục tiêu: không có gì thêm');
    expect(thanhTrong('c'), findsOneWidget, reason: 'ví lưu trữ đóng băng nhưng mục tiêu vẫn còn nên vẫn hiện tiến độ');
    expect(find.text('12.000.000 / 20.000.000 đ'), findsNWidgets(1), reason: 'ví a: 12tr/20tr; ví c: 5tr nên chữ khác');
    expect(t.takeException(), isNull);
  });
}
