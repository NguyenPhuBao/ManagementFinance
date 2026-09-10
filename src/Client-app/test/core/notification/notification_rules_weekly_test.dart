/// Luật thông báo **Tổng kết tuần** — thêm 2026-09-09.
///
/// Spec: `docs/superpowers/specs/2026-09-07-weekly-summary-notification-design.md`.
/// Bốn câu hỏi mở đã chốt với người dùng 2026-09-09; mục 5 của spec ghi cả
/// quyết định lẫn lý do.
///
/// Câu chữ **cố ý không nêu số**: thông báo là *cái cửa*, không phải bản báo
/// cáo. Hệ quả kỹ thuật là luật này gần như không cần dữ liệu — nó chỉ cần
/// biết tuần vừa khép **có giao dịch nào không**.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/notification/notification_rules.dart';

void main() {
  // 09/09/2026 là thứ Tư ⇒ tuần vừa khép là 31/08 → 06/09 (ISO 2026-W36).
  final now = DateTime(2026, 9, 9, 10, 30);

  List<NotificationCandidate> ungVien({
    bool coGiaoDich = true,
    DateTime? moc,
    DateTime? chan,
  }) =>
      buildNotificationCandidates(NotificationRuleInput(
        now: moc ?? now,
        tuanQuaCoGiaoDich: coGiaoDich,
        silenceBefore: chan,
      )).where((c) => c.kind == NotificationKind.weeklySummary).toList();

  group('_weeklySummaryCandidates', () {
    test('tuần vừa khép có giao dịch thì có đúng một thông báo', () {
      expect(ungVien().length, 1);
    });

    test('tuần trống thì KHÔNG báo', () {
      expect(
        ungVien(coGiaoDich: false),
        isEmpty,
        reason: 'Tổng kết của việc không có gì là nhiễu thuần tuý. Đây cũng là '
            'dữ liệu duy nhất mà luật này cần đọc — chốt (c) của spec.',
      );
    });

    test('câu chữ tối giản, KHÔNG nêu số', () {
      final c = ungVien().single;
      expect(c.title, 'Tổng kết tuần');
      expect(
        c.body,
        'Tuần qua đã khép lại. Xem lại bạn đã tiêu vào đâu.',
        reason: 'Ba phương án có số đã bị loại khi chốt với người dùng: so với '
            'tuần trước, thu/chi trần, và danh mục tiêu nhiều nhất. Thông báo '
            'là cái cửa, không phải bản báo cáo.',
      );
      expect(c.severity, NotificationSeverity.info);
    });

    test('khoá chống trùng mang tuần ISO của tuần VỪA KHÉP', () {
      expect(
        ungVien().single.dedupeKey,
        startsWith('weekly:2026-W36:'),
        reason: 'Khoá phải là của tuần đã khép (31/08–06/09), không phải tuần '
            'đang chạy — nếu không thì tuần hiện tại bị khoá trước khi nó kết '
            'thúc, và tổng kết thật của nó không bao giờ được sinh ra.',
      );
    });

    test('mọi ngày trong cùng một tuần cho CÙNG một khoá', () {
      // Thứ Hai 07/09 → Chủ nhật 13/09 đều tổng kết tuần 2026-W36.
      final khoa = {
        for (var d = 7; d <= 13; d++)
          ungVien(moc: DateTime(2026, 9, d, 8)).single.dedupeKey,
      };
      expect(
        khoa.length,
        1,
        reason: 'Người dùng mở app nhiều lần trong tuần. Khoá đổi theo ngày là '
            'bảy thông báo cho một tuần.',
      );
    });

    test('khoá mang thêm ngày thứ Hai để khởi động nguội dựng lại được khoảng',
        () {
      expect(
        ungVien().single.dedupeKey,
        'weekly:2026-W36:2026-08-31',
        reason: 'Đoạn thứ ba tồn tại vì `deeplinkTuDedupeKey` chạy ở COLD '
            'START: nó không tra được CSDL, và phép nghịch đảo của số tuần ISO '
            'là một hàm dễ sai mà không ai kiểm lại. Chở sẵn ngày đi là rẻ hơn '
            'và tự nói ra nghĩa của nó.',
      );
    });

    test('mốc sự kiện là THỜI ĐIỂM TUẦN KHÉP, không phải lúc quét', () {
      expect(
        ungVien().single.createdAt,
        DateTime(2026, 9, 7),
        reason: 'Cửa sổ `silenceBefore` 30 ngày lọc theo `createdAt`. Đặt bằng '
            'mốc quét thì một tuần cũ vẫn lọt qua phép lọc ấy chỉ vì người '
            'dùng vừa mở app.',
      );
    });

    test('deeplink trỏ vào trang Xuất báo cáo, phạm vi đúng tuần vừa khép', () {
      expect(
        ungVien().single.deeplink,
        '/export-report?from=2026-08-31&to=2026-09-06',
        reason: 'Chốt (d) của spec. `to` là ngày CUỐI CÙNG được tính vào — '
            'trang ấy tự cộng thêm một ngày để ra biên mở, đúng như bộ chọn '
            'khoảng ngày vẫn làm. Đưa thẳng biên mở 07/09 vào đây là báo cáo '
            'nuốt thêm trọn ngày thứ Hai của tuần sau.',
      );
      expect(ungVien().single.subjectType, 'week');
    });

    test('cửa sổ im lặng vẫn chặn được thông báo tuần', () {
      expect(
        ungVien(chan: DateTime(2026, 9, 8)),
        isEmpty,
        reason: 'Lần bật tính năng đầu tiên không được nổ tổng kết của một '
            'tuần người dùng chưa từng thấy app.',
      );
    });

    test('vắt qua giao thừa: tuần trước thuộc năm dương lịch khác', () {
      // 01/01/2026 là thứ Năm ⇒ tuần vừa khép là 22/12 → 28/12/2025.
      final c = ungVien(moc: DateTime(2026, 1, 1, 9)).single;
      expect(c.dedupeKey, 'weekly:2025-W52:2025-12-22');
      expect(c.deeplink, '/export-report?from=2025-12-22&to=2025-12-28');
    });
  });
}
