/// Điều hướng khi người dùng bấm vào một thông báo.
///
/// ## Lỗi mà bộ test này canh
///
/// Bấm vào thông báo ngân sách làm app **chết màn đỏ**:
///
/// ```
/// navigator.dart: Failed assertion: '!keyReservation.contains(key)'
/// ```
///
/// Nguyên nhân: `/budget` nằm **bên trong** `StatefulShellRoute.indexedStack`
/// (thanh tab), còn `/notifications` nằm ngoài. `context.push('/budget')` từ
/// trang thông báo bắt go_router dựng thêm **một bản shell thứ hai** chồng lên
/// bản đang có, và hai bản ấy mang cùng một page key — Navigator từ chối.
///
/// Route nằm ngoài shell (`/bills`, `/goals`, `/wallets`) thì `push` bình
/// thường, nên lỗi chỉ xảy ra với đúng một trong bốn loại deeplink. Đó là lý do
/// nó lọt qua mọi vòng kiểm trước: ba loại kia chạy tốt.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/notification/notification_deeplink.dart';
import 'package:flowmoney/core/notification/notification_actions.dart';
import 'package:flowmoney/core/notification/notification_rules.dart';
import 'package:flowmoney/core/notification/reminder_scheduler.dart';
import 'package:flowmoney/features/bill/domain/bill_auto_pay.dart';
import 'package:flowmoney/features/bill/domain/bill_auto_pay_runner.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/goal/domain/goal_auto_deposit.dart';
import 'package:flowmoney/features/goal/domain/goal_auto_deposit_runner.dart';

void main() {
  group('deeplink nằm trong thanh tab', () {
    test('nhận ra các route thuộc StatefulShellRoute', () {
      expect(thuocThanhTab('/budget'), isTrue,
          reason: 'Đây chính là route làm app chết màn đỏ khi dùng push().');
      expect(thuocThanhTab('/home'), isTrue);
      expect(thuocThanhTab('/analytics'), isTrue);
      expect(thuocThanhTab('/profile'), isTrue);
    });

    test('route con của một nhánh tab cũng thuộc thanh tab', () {
      expect(thuocThanhTab('/analytics/export'), isTrue,
          reason: '/analytics/export khai bên trong nhánh /analytics, nên nó '
              'cũng kéo theo shell.');
    });
  });

  group('deeplink nằm ngoài thanh tab', () {
    test('các route thông báo hiện dùng đều push được', () {
      expect(thuocThanhTab('/bills'), isFalse);
      expect(thuocThanhTab('/goals'), isFalse);
      expect(thuocThanhTab('/wallets'), isFalse);
      expect(thuocThanhTab('/notifications'), isFalse);
    });

    test('đường dẫn tới MỘT mục tiêu cũng push được', () {
      expect(thuocThanhTab('/goals/dc2656fa-1397-4435-99d4-09e619226a14'),
          isFalse,
          reason: 'Thông báo mục tiêu dẫn thẳng tới `/goals/<id>`. Route ấy '
              'nằm ngoài StatefulShellRoute y như `/goals`, nên push là đúng — '
              'nếu một bản sau kéo nó vào một nhánh tab mà quên cập nhật '
              '`nhanhThanhTab`, bấm thông báo sẽ làm app chết màn đỏ và test '
              'này là thứ duy nhất bắt được trước khi ra máy thật.');
    });
  });

  group('không được nhầm theo tiền tố chuỗi', () {
    test('/budgets không phải là /budget', () {
      expect(thuocThanhTab('/budgets'), isFalse,
          reason: 'So khớp bằng startsWith trần sẽ nuốt luôn mọi route bắt đầu '
              'bằng cùng mấy chữ cái. Hôm nay chưa có /budgets, nhưng một cái '
              'tên như thế là chuyện rất dễ xảy ra, và hậu quả là điều hướng '
              'thay cả stack thay vì chồng lên.');
      expect(thuocThanhTab('/homepage'), isFalse);
      expect(thuocThanhTab('/profiles'), isFalse);
    });
  });

  group('đầu vào lạ không được làm chết điều hướng', () {
    test('chuỗi rỗng và route không tồn tại đều trả false', () {
      expect(thuocThanhTab(''), isFalse);
      expect(thuocThanhTab('/khong-ton-tai'), isFalse,
          reason: 'Trả false nghĩa là đi đường push — go_router tự xử lý route '
              'không khớp, còn ném ở đây thì mất cả trang thông báo.');
    });
  });

  // ── deeplinkTuDedupeKey ────────────────────────────────────────────────────
  //
  // Cú chạm vào thông báo cấp hệ điều hành chỉ mang theo `payload = dedupeKey`.
  // Ở **cold start** — lịch nhắc nổ khi app đã đóng hẳn, tức là ca CHÍNH của
  // loại lịch này — hàng tương ứng còn chưa tồn tại trong SQLite, nên không
  // tra cột `deeplink` ra được. Phải suy từ chính chuỗi khoá.
  group('deeplink suy từ dedupeKey', () {
    final now = DateTime(2026, 9, 15, 10);

    BudgetView nganSach({required String id, required double spent}) {
      return BudgetView(
        budget: BudgetEntity(
          id: id,
          idaccount: 7,
          categoryId: 'cat-an-uong',
          amount: 5000000,
          spent: spent,
          overSpending: 'Over',
          startDate: DateTime(2026, 9, 1),
          recurrence: true,
          timeRecurrence: BudgetRecurrence.month,
          note: '',
          isDeleted: false,
          syncStatus: 'synced',
          updatedAt: DateTime(2026, 9, 1),
        ),
        categoryName: 'Ăn uống',
      );
    }

    Bill hoaDon({required String id, required DateTime denHan}) => Bill(
          id: id,
          idaccount: 7,
          name: 'Tiền điện',
          amount: 300000,
          dueDate: denHan,
          payStatus: 'Pending',
          isPaid: false,
          autoPayEnabled: false,
          timeNotification: '3',
          isRecurrence: true,
          timeRecurrence: 'Month',
          recurrence: 'monthly',
          icon: 'receipt',
          colour: '#4CAF50',
          note: '',
          isDeleted: false,
          syncStatus: 'synced',
          syncRetryCount: 0,
          updatedAt: DateTime(2026, 9, 1),
        );

    GoalEntity mucTieu({
      required String id,
      required double current,
      bool lapLai = false,
    }) =>
        GoalEntity(
          id: id,
          idaccount: 7,
          name: 'MacBook',
          targetAmount: 10000000,
          currentAmount: current,
          startDate: DateTime(2026, 1, 1),
          targetDate: DateTime(2026, 12, 31),
          recurrence: lapLai,
          timeRecurrence: lapLai ? 'Month' : null,
          updatedAt: DateTime(2026, 9, 1),
        );

    Wallet vi({required String id, required double soDu}) => Wallet(
          id: id,
          idaccount: 7,
          name: 'Tiền mặt',
          type: 'cash',
          balance: soDu,
          currency: 'VND',
          icon: 'wallet',
          colour: '#4CAF50',
          isDefault: false,
          status: 'active',
          isDeleted: false,
          syncRetryCount: 0,
          includeInTotal: true,
          syncStatus: 'synced',
          updatedAt: DateTime(2026, 9, 1),
        );

    /// Một đầu vào cố tình dựng đủ rộng để bộ luật sinh ra **cả 15 loại**.
    List<NotificationCandidate> tatCaUngVien() =>
        buildNotificationCandidates(NotificationRuleInput(
          now: now,
          budgets: [
            nganSach(id: 'ns-sap', spent: 4600000),
            nganSach(id: 'ns-vuot', spent: 6000000),
          ],
          bills: [
            hoaDon(id: 'hd-sap', denHan: DateTime(2026, 9, 17)),
            hoaDon(id: 'hd-qua', denHan: DateTime(2026, 9, 10)),
          ],
          goals: [
            mucTieu(id: 'mt-xong', current: 10000000, lapLai: true),
            // 20% — dưới mốc 25 nên hàng này CHỈ sinh `goalBehind`. Nâng nó
            // lên cho tiện là mất luôn ca "trễ mà chưa tới mốc nào".
            mucTieu(id: 'mt-tre', current: 2000000),
            // 50% — hàng duy nhất sinh `goalMilestone`.
            mucTieu(id: 'mt-moc', current: 5000000),
          ],
          wallets: [
            vi(id: 'vi-am', soDu: -50000),
            vi(id: 'vi-can', soDu: 1000),
          ],
          lowBalanceThreshold: 100000,
          autoDeposits: [
            GoalAutoDepositEvent(
              goalId: 'mt-trich',
              goalName: 'MacBook',
              ky: DateTime(2026, 9, 15, 8),
              loai: LoaiTrich.trichDu,
              soTien: 500000,
              tenViNguon: 'Tiền mặt',
            ),
            GoalAutoDepositEvent(
              goalId: 'mt-hut',
              goalName: 'iPhone',
              ky: DateTime(2026, 9, 15, 8),
              loai: LoaiTrich.viKhongDu,
              soTien: 0,
              tenViNguon: 'Tiền mặt',
            ),
          ],
          autoPays: [
            BillAutoPayEvent(
              billId: 'hd-tra',
              billName: 'Tiền điện',
              ky: DateTime(2026, 9, 15),
              loai: LoaiTuTra.traDu,
              soTien: 300000,
              tenVi: 'Tiền mặt',
            ),
            BillAutoPayEvent(
              billId: 'hd-hut',
              billName: 'Tiền nước',
              ky: DateTime(2026, 9, 15),
              loai: LoaiTuTra.viKhongDu,
              soTien: 0,
              tenVi: 'Tiền mặt',
            ),
          ],
          syncFailed: true,
        ));

    test('đầu vào của phép canh phủ đủ cả 15 loại thông báo', () {
      final phu = tatCaUngVien().map((c) => c.kind).toSet();

      expect(phu, containsAll(NotificationKind.values),
          reason: 'Phép canh bên dưới chỉ có giá trị khi nó thật sự chạy qua '
              'mọi loại. Thêm loại thứ 15 mà quên dựng đầu vào cho nó thì '
              'chính test này đỏ, chứ không phải im lặng bỏ sót.');
    });

    test('mọi loại: suy từ khoá ra ĐÚNG deeplink mà bộ luật đã đặt', () {
      for (final c in tatCaUngVien()) {
        // `syncFailed` cố ý không có deeplink — không có màn nào để mở. Khi ấy
        // hợp đồng là rơi về trung tâm thông báo, chỗ luôn mở được.
        final mongDoi = c.deeplink ?? '/notifications';

        expect(deeplinkTuDedupeKey(c.dedupeKey), mongDoi,
            reason: '${c.kind.name}: khoá "${c.dedupeKey}" phải suy ra đúng '
                'route mà bộ luật đặt vào cột deeplink. Đây là một bản SAO của '
                'thông tin ấy — tồn tại chỉ vì cold start không tra CSDL được '
                '— nên nó phải được canh, nếu không hai nơi sẽ lệch nhau âm '
                'thầm và cú chạm đưa người dùng tới sai màn.');
      }
    });

    test('khoá lạ hoặc rỗng rơi về trung tâm thông báo', () {
      expect(deeplinkTuDedupeKey(''), '/notifications');
      expect(deeplinkTuDedupeKey('khongBietLaGi:123'), '/notifications',
          reason: 'Khoá đến từ payload của hệ điều hành — nó có thể là lịch do '
              'một bản app CŨ đặt, còn nằm trong AlarmManager từ trước khi '
              'nâng cấp. Ném hay trả null ở đây là làm chết cú chạm.');
      expect(deeplinkTuDedupeKey('goalDone'), '/notifications',
          reason: 'Đúng tiền tố nhưng thiếu id: không dựng nổi /goals/<id>, '
              'nên phải lùi về chỗ an toàn thay vì ghép ra "/goals/".');
    });

    test('khoá kỳ trích tự động có thêm dấu hai chấm trong mốc giờ', () {
      // `khoaKyTrich` sinh "<goalId>:<yyyy-MM-dd>T<HH>:<mm>" — chuỗi khoá đầy
      // đủ vì thế có BỐN đoạn, không phải ba. Cắt bằng `split(':')[1]` vẫn ra
      // đúng id, nhưng ai đó dùng `split(':').last` sẽ ra "00".
      final khoa = 'goalAuto:${khoaKyTrich('mt-abc', DateTime(2026, 9, 15, 8))}';

      expect(khoa.split(':').length, greaterThan(3));
      expect(deeplinkTuDedupeKey(khoa), '/goals/mt-abc');
    });

    test('lời nhắc ghi chép dẫn thẳng tới trang thêm giao dịch', () {
      final khoa = ghiChepDedupeKey(DateTime(2026, 9, 15));

      expect(khoa, 'ghiChep:2026-09-15',
          reason: 'Ngày phải nằm trong khoá và phải đệm 0: đó là thứ làm '
              'resync luỹ đẳng, và cũng là thứ deeplink cắt bằng chữ.');
      expect(deeplinkTuDedupeKey(khoa), '/add',
          reason: 'Đây là loại nhắc DUY NHẤT bảo người dùng đi làm một việc cụ '
              'thể. Đổ họ về /notifications là bắt tự tìm đường tới chỗ ghi — '
              'và lời nhắc mất gần hết tác dụng.');
      expect(thuocThanhTab('/add'), false,
          reason: '/add nằm NGOÀI StatefulShellRoute nên phải `push`. Nếu ai '
              'đó kéo nó vào một nhánh tab mà quên cập nhật nhanhThanhTab thì '
              'chạm vào lời nhắc sẽ làm app chết màn đỏ — bẫy 7.8.');
    });

    test('nút "Trả ngay" mở ĐÚNG hoá đơn ấy, không phải danh sách', () {
      final payload = payloadTraNgay('billDue:hd1:2026-09-20:3');

      expect(payload, 'billOpen:hd1');
      expect(deeplinkTuDedupeKey(payload!), '/bills/hd1',
          reason: 'Cú CHẠM thường vẫn mở /bills — đó là cột deeplink bộ luật '
              'đặt và có phép canh cả 15 loại. Nhưng cái NÚT đã biết chính xác '
              'hoá đơn nào, nên đổ về danh sách là vứt đi thông tin đang cầm.');
      expect(thuocThanhTab('/bills/hd1'), false,
          reason: '/bills/<id> nằm ngoài StatefulShellRoute nên phải `push`. '
              'Kéo nó vào một nhánh tab mà quên cập nhật nhanhThanhTab thì bấm '
              'nút sẽ làm app chết màn đỏ — bẫy 7.8.');
    });

    test('billOpen thiếu id rơi về danh sách hoá đơn', () {
      expect(deeplinkTuDedupeKey('billOpen'), '/bills');
      expect(deeplinkTuDedupeKey('billOpen:'), '/bills',
          reason: 'Không bao giờ được dựng "/bills/" — route ấy không khớp gì '
              'và người dùng rơi vào màn trống.');
    });

    test('khoá ghi chép của bản app cũ không làm gì hỏng', () {
      // Lịch đã đặt vẫn nằm trong AlarmManager sau khi nâng cấp app, nên hàm
      // này phải chịu được cả những khoá nó không còn hiểu.
      expect(deeplinkTuDedupeKey('ghiChep'), '/add');
      expect(deeplinkTuDedupeKey('ghiChep:'), '/add');
    });
  });
}
