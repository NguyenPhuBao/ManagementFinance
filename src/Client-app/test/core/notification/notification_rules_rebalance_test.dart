/// Luật **Đề xuất cân đối ngân sách** (`budgetRebalance`) — loại thông báo mới
/// của Edge-SLM P2, Task 16.
///
/// ## Canh chừng điều gì
///
/// Ba thứ, cả ba hỏng **im lặng**:
///
/// 1. **Khoá là TUẦN, không phải ngân sách.** Kế hoạch tái phân bổ đổi mỗi lần
///    người dùng tiêu thêm một đồng — dự phóng là một hàm của `spent`. Nhét
///    `budget.id` hay số tiền vào khoá là biến mỗi lượt quét thành một thông
///    báo mới, đúng cái bẫy mà cột `dedupeKey` sinh ra để chặn (mục 4.2
///    `NOTIFICATION_FEATURE.md`). Một tuần một lần là trần cố ý.
/// 2. **Câu chữ không nêu số.** Con số duy nhất đúng là con số *tại lúc mở
///    trang*; in nó vào thông báo là hứa một điều sẽ sai ngay khi người dùng
///    tiêu tiếp. Cùng lý lẽ với Tổng kết tuần (mục 5d).
/// 3. **Nguồn kế hoạch là `taiPhanBoCua`, không phải một phép tính thứ hai.**
///    Bộ luật chỉ *nhận* kế hoạch đã dựng — nó không được biết gì về thâm hụt,
///    dư địa hay ngưỡng. Tính lại ở đây là bản định nghĩa thứ hai, và hai bản
///    sẽ nói hai chuyện khác nhau trên cùng một màn hình.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/notification/notification_rules.dart';
import 'package:flowmoney/core/notification/notification_deeplink.dart';
import 'package:flowmoney/core/notification/prefs/notification_prefs.dart';
import 'package:flowmoney/features/ai_edge/domain/tai_phan_bo.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';

/// Thứ Năm 17/09/2026 — tuần ISO **38**. Thứ Hai của tuần ấy là 14/09, Chủ
/// nhật là 20/09; 21/09 đã sang tuần 39.
final _now = DateTime(2026, 9, 17, 12);

BudgetView _v(String id, {String ten = 'Ăn uống'}) => BudgetView(
      budget: BudgetEntity(
        id: id,
        idaccount: 7,
        categoryId: 'c-$id',
        amount: 3000000,
        spent: 2600000,
        startDate: DateTime(2026, 9, 1),
        recurrence: true,
        timeRecurrence: BudgetRecurrence.month,
        updatedAt: DateTime(2026, 9, 1),
      ),
      categoryName: ten,
    );

/// Kế hoạch dựng **bằng tay** chứ không qua `taiPhanBoCua`: bộ luật chỉ đọc
/// `thieu` và `dong`, nên kéo cả tầng 2 vào đây là buộc ca test phải dựng một
/// trạng thái thâm hụt hợp lệ để hỏi một câu không liên quan tới nó.
KeHoachTaiPhanBo _keHoach({
  String ten = 'Ăn uống',
  int soDong = 2,
}) {
  final thieu = _v('b-thieu', ten: ten);
  return KeHoachTaiPhanBo(
    thieu: thieu,
    duPhong: 3900000,
    thamHut: 900000,
    dong: [
      for (var i = 0; i < soDong; i++)
        DongTaiPhanBo(
          nguon: _v('b-nguon-$i', ten: 'Nguồn $i'),
          duDia: 1000000,
          soTien: 250000,
        ),
    ],
    trangThai: soDong > 0
        ? TrangThaiKeHoach.duNguonBu
        : TrangThaiKeHoach.thieuNguonBu,
    soThieu: soDong > 0 ? 0 : 900000,
  );
}

NotificationRuleInput _vao({
  KeHoachTaiPhanBo? keHoach,
  DateTime? now,
  DateTime? silenceBefore,
}) =>
    NotificationRuleInput(
      now: now ?? _now,
      keHoachTaiPhanBo: keHoach,
      silenceBefore: silenceBefore,
    );

List<NotificationCandidate> _chay(NotificationRuleInput vao) =>
    buildNotificationCandidates(vao)
        .where((c) => c.kind == NotificationKind.budgetRebalance)
        .toList();

void main() {
  group('không có kế hoạch thì im', () {
    test('⚠️ `keHoachTaiPhanBo` null → KHÔNG ứng viên nào', () {
      // Mặc định của trường ấy là `null`, và nó là `null` ở mọi lượt quét của
      // tài khoản không có ngân sách nào thâm hụt — tức phần lớn thời gian.
      // Sinh thông báo ở đây là báo một việc chưa xảy ra.
      expect(_chay(_vao()), isEmpty,
          reason: 'Không có kế hoạch nghĩa là không có gì để đề xuất.');
    });
  });

  group('có kế hoạch', () {
    test('đúng MỘT ứng viên, khoá theo tuần ISO', () {
      final ra = _chay(_vao(keHoach: _keHoach()));

      expect(ra, hasLength(1),
          reason: 'Mỗi lượt quét chỉ một kế hoạch (ngân sách thâm hụt lớn '
              'nhất), nên cũng chỉ một thông báo.');
      expect(ra.single.dedupeKey, 'budgetRebalance:2026-W38',
          reason: '17/09/2026 là thứ Năm của tuần ISO 38. Khoá KHÔNG chứa '
              'budget id và KHÔNG chứa số tiền — kế hoạch đổi mỗi lần người '
              'dùng tiêu thêm một đồng, nên hai thứ ấy biến mỗi lượt quét '
              'thành một thông báo mới.');
    });

    test('mang đúng nhãn, mức độ, chủ thể và deeplink', () {
      final ra = _chay(_vao(keHoach: _keHoach())).single;

      expect(ra.title, 'Đề xuất cân đối ngân sách');
      expect(ra.severity, NotificationSeverity.warning,
          reason: 'Đáng nhìn lại, không phải dấu hiệu có gì đó đã sai — '
              '`critical` dành cho ví âm và ngân sách ĐÃ vượt.');
      expect(ra.subjectType, 'budget');
      expect(ra.subjectId, 'b-thieu',
          reason: 'Chủ thể là ngân sách thâm hụt, không phải nguồn bù.');
      expect(ra.deeplink, '/budget');
      expect(ra.createdAt, _now,
          reason: '"Dự kiến vượt" là trạng thái TẠI LÚC QUÉT — không có mốc '
              'sự kiện nào khác để lấy, khác `largeExpense` (ngày giao dịch).');
    });

    test('⚠️ body KHÔNG chứa chữ số', () {
      final ra = _chay(_vao(keHoach: _keHoach())).single;

      expect(RegExp(r'[0-9]').hasMatch(ra.body), isFalse,
          reason: 'Con số duy nhất đúng là con số tại lúc mở trang: dự phóng '
              'là hàm của `spent`, nên số in vào thông báo sai ngay khi người '
              'dùng tiêu tiếp. Thông báo là cái cửa, không phải bản báo cáo. '
              'Thực tế body là: "${ra.body}"');
      expect(ra.body, contains('Ăn uống'),
          reason: 'Vẫn phải nói TÊN ngân sách — không có nó thì người dùng '
              'phải mở app ra mới biết thông báo nói về cái gì.');
    });

    test('kế hoạch KHÔNG còn nguồn bù vẫn báo, bằng câu khác', () {
      // Ca đáng báo nhất: ngân sách sắp vượt mà không cứu được bằng cách san
      // sẻ. Thẻ trên trang Ngân sách vẫn hiện (viền đỏ, không có nút "Xem kế
      // hoạch"), nên thông báo im ở đây là hai khối nói hai chuyện.
      final ra = _chay(_vao(keHoach: _keHoach(soDong: 0))).single;

      expect(RegExp(r'[0-9]').hasMatch(ra.body), isFalse,
          reason: 'Cùng luật không-nêu-số. Thực tế: "${ra.body}"');
      expect(ra.body, isNot(contains('Xem kế hoạch')),
          reason: 'Không dòng nguồn bù nào thì không có kế hoạch để xem — '
              'sheet rỗng là ngõ cụt, và `TheKeHoach` cũng giấu nút ấy. Mời '
              'người dùng xem một thứ không tồn tại là lời hứa suông.');
    });
  });

  group('trần một tuần một lần', () {
    test('hai lượt quét khác ngày TRONG cùng tuần → CÙNG khoá', () {
      // Thứ Hai và Chủ nhật của tuần 38. Đây là phép chặn thật sự: một lượt
      // quét nổ mỗi khi đồng bộ xong hoặc app quay lại từ nền, tức vài lần mỗi
      // ngày.
      final a = _chay(_vao(keHoach: _keHoach(), now: DateTime(2026, 9, 14, 8)));
      final b = _chay(_vao(keHoach: _keHoach(), now: DateTime(2026, 9, 20, 23)));

      expect(a.single.dedupeKey, b.single.dedupeKey,
          reason: 'insertOrIgnore chống trùng theo đúng chuỗi này; khoá khác '
              'nhau là một thông báo mới mỗi ngày.');
      expect(a.single.dedupeKey, 'budgetRebalance:2026-W38');
    });

    test('sang tuần mới → khoá KHÁC', () {
      final a = _chay(_vao(keHoach: _keHoach(), now: DateTime(2026, 9, 20, 23)));
      final b = _chay(_vao(keHoach: _keHoach(), now: DateTime(2026, 9, 21, 0)));

      expect(a.single.dedupeKey, isNot(b.single.dedupeKey),
          reason: 'Chủ nhật 20/09 sang thứ Hai 21/09 là một tuần ISO mới. '
              'Không đổi khoá là im lặng vĩnh viễn sau lần báo đầu tiên.');
      expect(b.single.dedupeKey, 'budgetRebalance:2026-W39');
    });

    test('tuần ISO bắc qua năm dương lịch vẫn cho khoá đúng', () {
      // 31/12/2025 thuộc `2026-W01` — năm ISO khác `date.year`. Lấy
      // `now.year` thay vì năm ISO là hai tuần khác nhau dùng chung một khoá.
      final ra =
          _chay(_vao(keHoach: _keHoach(), now: DateTime(2025, 12, 31, 9)));
      expect(ra.single.dedupeKey, 'budgetRebalance:2026-W01');
    });
  });

  group('cửa sổ im lặng', () {
    test('`silenceBefore` sau `now` → bị lọc', () {
      final ra = _chay(_vao(
        keHoach: _keHoach(),
        silenceBefore: _now.add(const Duration(days: 1)),
      ));
      expect(ra, isEmpty,
          reason: 'Mốc sự kiện là `now`, nên nó phải đi qua cùng bộ lọc với '
              'mọi loại khác — lần bật tính năng đầu tiên không được bắn một '
              'loạt đề xuất của quá khứ.');
    });
  });

  group('nhóm công tắc', () {
    test('thuộc nhóm Ngân sách, không phải nhóm mới', () {
      expect(nhomCua(NotificationKind.budgetRebalance),
          NotificationGroup.budget,
          reason: 'Cùng bản chất "chi tiêu vượt một mức" với ba loại sẵn có. '
              'Một nhóm riêng là chip thứ tám trên dải đã phải cuộn ngang, và '
              'phải sửa ca canh `NotificationGroup.values.length + 2`.');
    });

    test('CHỊU công tắc nhóm', () {
      expect(luonBao(NotificationKind.budgetRebalance), isFalse,
          reason: '`luonBao` dành riêng cho những loại báo việc app tự rút '
              'tiền lúc người dùng vắng mặt. Đây là một lời đề xuất — người '
              'dùng phải tắt được, nếu không họ sẽ tắt công tắc tổng và mất '
              'mọi thứ.');
    });
  });

  group('cold start', () {
    test('suy từ khoá ra đúng route', () {
      expect(deeplinkTuDedupeKey('budgetRebalance:2026-W38'), '/budget',
          reason: 'Cú chạm vào thông báo cấp hệ điều hành chỉ mang theo '
              '`dedupeKey`. Thiếu nhánh là rơi về trung tâm thông báo — mất '
              'đúng một cú chạm, không gì báo lỗi.');
    });

    test('⚠️ `/budget` KHÔNG thuộc thanh tab nên phải `push`', () {
      // Nhóm D (2026-09-19) đưa `/budget` ra khỏi shell. Nếu ai đó đưa nó trở
      // lại `nhanhThanhTab` mà quên chỗ này thì cú chạm `go` tới một route
      // ngoài shell — thanh tab biến mất, không còn đường quay lại.
      expect(thuocThanhTab('/budget'), isFalse);
    });
  });
}
