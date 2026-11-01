import 'package:flowmoney/features/notification/domain/notification_prefs.dart';
import 'package:flowmoney/features/notification/domain/notification_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 31, 9);
  NotificationRuleInput dau(List<LoiMoiNhaThongBao> ds) =>
      NotificationRuleInput(now: now, budgets: const [], bills: const [], goals: const [], wallets: const [], loiMoiNha: ds);

  test('một lời mời → một ứng viên, khoá loiMoiNha:<mã>, deeplink /nha, câu theo 01 mục 2.7', () {
    final c = buildNotificationCandidates(dau([(ma: 'ABCD2345', tenNha: 'Nhà An', tenNguoiMoi: 'Trần An', hetHan: null)])).single;
    expect(c.kind, NotificationKind.loiMoiNha);
    expect(c.dedupeKey, 'loiMoiNha:ABCD2345');
    expect(c.deeplink, '/nha');
    expect(c.body, 'Trần An mời bạn vào nhà Nhà An');
    expect(c.severity, NotificationSeverity.info);
    expect(c.createdAt, now);
  });

  test('lời mời đã qua hạn trên máy → không sinh', () {
    final ds = [(ma: 'ABCD2345', tenNha: 'A', tenNguoiMoi: 'B', hetHan: now.subtract(const Duration(minutes: 1)))];
    expect(buildNotificationCandidates(dau(ds)), isEmpty,
        reason: 'server trả danh sách tại lần hỏi trước; mời chấp nhận một mã đã chết là mời bấm vào lỗi');
  });

  test('nhóm Gia đình, chịu công tắc nhóm, mặc định bật', () {
    expect(nhomCua(NotificationKind.loiMoiNha), NotificationGroup.giaDinh);
    expect(luonBao(NotificationKind.loiMoiNha), isFalse);
    expect(NotificationPrefs.macDinh.chapNhan(NotificationKind.loiMoiNha), isTrue);
    expect(const NotificationPrefs(nhomTat: {NotificationGroup.giaDinh}).chapNhan(NotificationKind.loiMoiNha), isFalse);
  });
}
