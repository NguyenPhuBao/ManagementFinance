import 'package:flowmoney/features/notification/domain/notification_prefs.dart';
import 'package:flowmoney/features/notification/domain/notification_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 2, 9);
  NotificationRuleInput dau(List<MucTieuNhaThongBao> ds) => NotificationRuleInput(now: now, mucTieuNha: ds);
  MucTieuNhaThongBao muc(double tiLe, {bool daThay = true, String id = 'g'}) =>
      (idGoal: id, tenVi: 'Quỹ du lịch', tiLe: tiLe, daThay: daThay);

  Map<String, NotificationCandidate> theoKhoa(List<NotificationCandidate> ds) => {for (final c in ds) c.dedupeKey: c};
  List<String> hien(List<NotificationCandidate> ds) => [for (final c in ds) if (!c.imLang) c.dedupeKey];

  test('tiến độ 10 %: chỉ có dấu nhaMucTieu:g:0, im lặng', () {
    final ra = buildNotificationCandidates(dau([muc(.1)]));
    expect(hien(ra), isEmpty, reason: 'chưa qua mốc nào, người dùng không thấy gì');
    expect(theoKhoa(ra)['nhaMucTieu:g:0']!.imLang, isTrue);
  });

  test('tiến độ 30 %: mốc 25 hiện, câu và deeplink đúng', () {
    final ra = buildNotificationCandidates(dau([muc(.3)]));
    expect(hien(ra), ['nhaMucTieu:g:25']);
    final c = theoKhoa(ra)['nhaMucTieu:g:25']!;
    expect(c.kind, NotificationKind.nhaMucTieuMoc);
    expect(c.body, 'Quỹ du lịch đã được 25% mục tiêu');
    expect(c.deeplink, '/nha');
    expect(c.subjectType, 'nhaMucTieu');
    expect(c.subjectId, 'g');
    expect(c.createdAt, now);
  });

  test('tiến độ 80 %: chỉ mốc 75 hiện; 50, 25 và dấu :0 im lặng (Q7)', () {
    final ra = buildNotificationCandidates(dau([muc(.8)]));
    expect(hien(ra), ['nhaMucTieu:g:75'], reason: 'giảm dần: chỉ mốc cao nhất mang tin mới');
    final k = theoKhoa(ra);
    expect(k['nhaMucTieu:g:50']!.imLang, isTrue);
    expect(k['nhaMucTieu:g:25']!.imLang, isTrue);
    expect(k['nhaMucTieu:g:0']!.imLang, isTrue);
  });

  test('biên mốc: .25 báo 25, .249 chỉ dấu :0; .5 báo 50, .75 báo 75', () {
    expect(hien(buildNotificationCandidates(dau([muc(.25)]))), ['nhaMucTieu:g:25'], reason: 'đúng 25 % là đã vượt mốc 25');
    expect(hien(buildNotificationCandidates(dau([muc(.249)]))), isEmpty, reason: '24,9 % chưa tới mốc 25');
    expect(hien(buildNotificationCandidates(dau([muc(.5)]))), ['nhaMucTieu:g:50']);
    expect(hien(buildNotificationCandidates(dau([muc(.75)]))), ['nhaMucTieu:g:75']);
  });

  test('tiến độ 100 %: nhaMucTieuDat hiện, ba mốc im lặng', () {
    final ra = buildNotificationCandidates(dau([muc(1)]));
    expect(hien(ra), ['nhaMucTieuDat:g']);
    final c = theoKhoa(ra)['nhaMucTieuDat:g']!;
    expect(c.kind, NotificationKind.nhaMucTieuDat);
    expect(c.body, 'Quỹ du lịch đã đạt mục tiêu');
    final k = theoKhoa(ra);
    for (final moc in [75, 50, 25]) {
      expect(k['nhaMucTieu:g:$moc']!.imLang, isTrue, reason: 'mốc $moc đi kèm khi đạt, chỉ giữ khoá');
    }
  });

  test('lần đầu thấy mục tiêu (daThay false): mọi ứng viên im lặng, kể cả mốc 75', () {
    final ra = buildNotificationCandidates(dau([muc(.8, daThay: false)]));
    expect(hien(ra), isEmpty, reason: 'người mới vào nhà không nhận mốc cũ (03 mục 4)');
    expect(ra.every((c) => c.imLang), isTrue);
    expect(ra.map((c) => c.dedupeKey), contains('nhaMucTieu:g:75'), reason: 'khoá vẫn được giữ để lần sau không báo lại');
  });

  test('nhóm, luonBao, mặc định, tắt nhóm', () {
    for (final k in [NotificationKind.nhaMucTieuMoc, NotificationKind.nhaMucTieuDat]) {
      expect(nhomCua(k), NotificationGroup.giaDinh);
      expect(luonBao(k), isFalse);
      expect(NotificationPrefs.macDinh.chapNhan(k), isTrue);
      expect(const NotificationPrefs(nhomTat: {NotificationGroup.giaDinh}).chapNhan(k), isFalse);
    }
  });

  test('mục tiêu khác id → khoá khác, báo lại từ đầu', () {
    final ra = buildNotificationCandidates(dau([muc(.3), muc(.3, id: 'h')]));
    expect(hien(ra), ['nhaMucTieu:g:25', 'nhaMucTieu:h:25']);
    expect(khoaDaThayMucTieuNha('h'), 'nhaMucTieu:h:0');
  });
}
