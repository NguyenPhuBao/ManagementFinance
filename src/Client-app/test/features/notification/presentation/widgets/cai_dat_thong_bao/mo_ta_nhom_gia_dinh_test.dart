import 'package:flowmoney/features/notification/domain/notification_prefs.dart';
import 'package:flowmoney/features/notification/presentation/widgets/cai_dat_thong_bao/ten_nhom_thong_bao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mô tả nhóm Gia đình nêu cả góp quỹ và mục tiêu, không chỉ lời mời', () {
    expect(moTaNhomThongBao(NotificationGroup.giaDinh), 'Lời mời, góp quỹ và mục tiêu của nhà.',
        reason: 'nhóm giaDinh nay còn gồm góp quỹ và mục tiêu chung; câu cũ "Lời mời vào nhà." nói thiếu');
  });
}
