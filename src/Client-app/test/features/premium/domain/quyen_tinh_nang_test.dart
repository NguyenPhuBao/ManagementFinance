import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/premium/domain/quyen_tinh_nang.dart';
import 'package:flowmoney/features/premium/domain/tran_goi.dart';
import 'package:flowmoney/features/premium/data/models/tran_goi.dart';
import 'package:flowmoney/features/premium/data/models/trang_thai_goi.dart';
import 'package:flowmoney/features/premium/domain/hang_goi.dart';

/// Spec phân quyền client 2026-10-08 mục 4.1 — `duocDung` là định nghĩa duy nhất.
void main() {
  final now = DateTime.utc(2026, 10, 8, 12);
  TrangThaiGoi goi(LoaiGoi loai,
          {DateTime? hetHan, Map<String, bool> q = const {}, DateTime? nhan}) =>
      TrangThaiGoi(loai: loai, hetHan: hetHan, nhanLuc: nhan ?? now, quyenTinhNang: q);

  group('B1 — trangThaiQuyen ba trạng thái (spec 2026-10-27 mục 2)', () {
    test('⭐ Premium còn hạn + bảng ghi false → TẠM NGỪNG (thay luật "Premium mở hết" 2026-10-08)', () {
      final g = goi(LoaiGoi.premium,
          hetHan: now.add(const Duration(days: 3)), q: {for (final m in MaQuyen.values) m.maServer: false});
      for (final m in MaQuyen.values) {
        expect(trangThaiQuyen(m, g, now), TrangThaiQuyen.tamNgung, reason: m.maServer);
        expect(duocDung(m, g, now), isFalse, reason: m.maServer);
      }
    });

    test('Premium còn hạn + thiếu khoá → mở (kể cả ba quyền AI)', () {
      final g = goi(LoaiGoi.premium, hetHan: now.add(const Duration(days: 3)));
      for (final m in MaQuyen.values) {
        expect(trangThaiQuyen(m, g, now), TrangThaiQuyen.mo, reason: m.maServer);
      }
    });

    test('⭐ Premium KHÔNG hạn (hetHan null) + bảng ghi false → MỞ: bảng ấy là của Basic (server coi tài khoản là Basic — B4)',
        () {
      final g = goi(LoaiGoi.premium, q: const {'export_reports': false, 'ai_assistant': false});
      expect(trangThaiQuyen(MaQuyen.exportReports, g, now), TrangThaiQuyen.mo,
          reason: 'payment.service.js coi Premium không premium_expires_at là Basic và trả bảng Basic; client coi là '
              'Premium còn hạn — đọc bảng ấy là mọi thứ Basic tắt hiện "Đang tạm ngừng" với người Premium.');
      expect(trangThaiQuyen(MaQuyen.aiAssistant, g, now), TrangThaiQuyen.mo);
    });

    test('Basic + false + cột Premium false → tamNgung (mua cũng không có)', () {
      final g = TrangThaiGoi(
          loai: LoaiGoi.basic,
          nhanLuc: now,
          quyenTinhNang: const {'export_reports': false},
          quyenPremium: const {'export_reports': false});
      expect(trangThaiQuyen(MaQuyen.exportReports, g, now), TrangThaiQuyen.tamNgung);
    });

    test('⭐ Basic + false + cột Premium VẮNG (server chưa gửi) → canPremium (như trước B1)', () {
      final g = goi(LoaiGoi.basic, q: const {'export_reports': false});
      expect(trangThaiQuyen(MaQuyen.exportReports, g, now), TrangThaiQuyen.canPremium);
    });

    test('Basic + false + cột Premium true → canPremium; Basic thiếu khoá AI → canPremium', () {
      final g = TrangThaiGoi(
          loai: LoaiGoi.basic,
          nhanLuc: now,
          quyenTinhNang: const {'export_reports': false},
          quyenPremium: const {'export_reports': true});
      expect(trangThaiQuyen(MaQuyen.exportReports, g, now), TrangThaiQuyen.canPremium);
      expect(trangThaiQuyen(MaQuyen.aiAssistant, goi(LoaiGoi.basic), now), TrangThaiQuyen.canPremium);
    });

    test('Premium hết hạn lúc offline: cột Premium đã lưu KHÔNG được đọc (bảng không dùng được)', () {
      final g = TrangThaiGoi(
          loai: LoaiGoi.premium,
          hetHan: now.subtract(const Duration(hours: 1)),
          nhanLuc: now.subtract(const Duration(days: 2)),
          quyenPremium: const {'ai_assistant': false});
      expect(trangThaiQuyen(MaQuyen.aiAssistant, g, now), TrangThaiQuyen.canPremium);
    });

    test('duocDung ⇔ trangThaiQuyen == mo trên mọi tổ hợp', () {
      final ds = [
        goi(LoaiGoi.basic),
        goi(LoaiGoi.basic, q: {for (final m in MaQuyen.values) m.maServer: false}),
        goi(LoaiGoi.premium, hetHan: now.add(const Duration(days: 1)), q: const {'export_reports': false}),
        goi(LoaiGoi.premium, hetHan: now.subtract(const Duration(hours: 1)), nhan: now.subtract(const Duration(days: 1))),
      ];
      for (final g in ds) {
        for (final m in MaQuyen.values) {
          expect(duocDung(m, g, now), trangThaiQuyen(m, g, now) == TrangThaiQuyen.mo, reason: m.maServer);
        }
      }
    });
  });

  test('⭐ Premium HẾT HẠN sau lúc nhận, bảng là của Premium → mặc định Basic (lỗi 1)', () {
    final g = goi(LoaiGoi.premium,
        hetHan: now.subtract(const Duration(hours: 1)),
        nhan: now.subtract(const Duration(days: 2)),
        q: {for (final m in MaQuyen.values) m.maServer: true});
    expect(duocDung(MaQuyen.aiAssistant, g, now), isFalse,
        reason: 'Bảng lưu là của Premium (lúc nhận còn hạn) — đọc nó là mở AI cho tài '
            'khoản đã hết hạn lúc offline.');
    expect(duocDung(MaQuyen.exportReports, g, now), isTrue,
        reason: 'mặc định khi thiếu = mở');
  });

  test('Premium hết hạn Ở SERVER (accountType Premium, hết hạn trước lúc nhận) → theo bảng Basic',
      () {
    final g = goi(LoaiGoi.premium,
        hetHan: now.subtract(const Duration(days: 1)),
        nhan: now.subtract(const Duration(hours: 1)),
        q: const {'export_reports': false});
    expect(duocDung(MaQuyen.exportReports, g, now), isFalse,
        reason: 'server trả `features` của gói hiệu lực (Basic) dù `accountType` vẫn Premium');
  });

  test('Basic có khoá → theo khoá', () {
    final g = goi(LoaiGoi.basic,
        q: const {'cashflow_forecast': false, 'ai_assistant': true});
    expect(duocDung(MaQuyen.cashflowForecast, g, now), isFalse);
    expect(duocDung(MaQuyen.aiAssistant, g, now), isTrue);
  });

  test('Basic thiếu khoá → ba quyền AI khoá, còn lại mở', () {
    final g = goi(LoaiGoi.basic);
    const khoa = {MaQuyen.aiAssistant, MaQuyen.aiQuickInput, MaQuyen.aiEdgeModel};
    for (final m in MaQuyen.values) {
      expect(duocDung(m, g, now), !khoa.contains(m), reason: m.maServer);
    }
  });

  test('đọc lại từ kho giữ nguyên bảng quyền', () {
    final g = goi(LoaiGoi.basic, q: const {'export_reports': false});
    final lai = TrangThaiGoi.tuJsonKho(g.toJson())!;
    expect(duocDung(MaQuyen.exportReports, lai, now), isFalse);
  });

  test('22 mã server, đôi một khác nhau, đúng migration 23 (bỏ financial_health_fhs) + 11 mã B1', () {
    expect(MaQuyen.values.map((m) => m.maServer).toSet(), {
      'ai_assistant',
      'ai_quick_input',
      'ai_edge_model',
      'ocr_receipt',
      'smart_budget_rebalancing',
      'export_reports',
      'cashflow_forecast',
      'anomaly_spending_insights',
      'bill_auto_pay',
      'goal_auto_deposit',
      'bank_notification_parser',
      'net_worth_overview',
      'quick_action_shortcuts',
      'daily_recording_reminder',
      'bill_reminder_notifications',
      'budget_overspend_alert',
      'wallet_balance_adjustment',
      'wallet_exclude_total',
      'goal_deposit_withdraw',
      'quick_category_assignment',
      'category_keywords_matching',
      'in_app_calculator',
    });
    expect(MaQuyen.values.length, 22);
    expect(maQuyenTuServer('export_reports'), MaQuyen.exportReports);
    expect(maQuyenTuServer('financial_health_fhs'), isNull);
    expect(maQuyenTuServer(null), isNull);
  });

  group('dacQuyenPremium — danh sách đặc quyền màn Nâng cấp theo bảng của server (2026-10-08)', () {
    test('Basic với bảng server: mỗi trần có số + mỗi quyền tắt; quyền BẬT không được kể', () {
      final g = TrangThaiGoi(
          loai: LoaiGoi.basic,
          nhanLuc: now,
          tran: const TranGoi(vi: 3, nganSach: 3, mucTieu: 3, hoaDon: 3, danhMucRieng: 5),
          quyenTinhNang: const {'ocr_receipt': true, 'export_reports': false, 'cashflow_forecast': false});
      final d = dacQuyenPremium(g);
      expect(d, containsAll(['Không giới hạn ví', 'Không giới hạn hóa đơn định kỳ', 'Không giới hạn danh mục riêng']));
      expect(d, containsAll([MaQuyen.exportReports.ten, MaQuyen.cashflowForecast.ten, MaQuyen.aiAssistant.ten]));
      expect(d, isNot(contains(MaQuyen.ocrReceipt.ten)),
          reason: 'Basic đang dùng được Quét — kể nó là đặc quyền Premium là nói sai.');
      expect(d, isNot(contains(MaQuyen.bankNotificationParser.ten)),
          reason: 'thiếu khoá = mở (macDinhKhiThieu) → không phải đặc quyền');
    });

    test('⭐ B1: Basic có cột Premium → trần Premium null "Không giới hạn …", số lớn hơn trần Basic "Tới N …", không lớn hơn thì không kể',
        () {
      final g = TrangThaiGoi(
          loai: LoaiGoi.basic,
          nhanLuc: now,
          tran: const TranGoi(vi: 3, nganSach: 3, mucTieu: 3, hoaDon: 3, danhMucRieng: 5),
          tranPremium: const TranGoi(vi: 10, mucTieu: 3, hoaDon: 2));
      final d = dacQuyenPremium(g);
      expect(d, contains('Tới 10 ví'));
      expect(d, contains('Không giới hạn ngân sách'));
      expect(d, contains('Không giới hạn danh mục riêng'));
      expect(d, isNot(contains('Không giới hạn ví')), reason: 'cột Premium nói 10, không phải vô hạn');
      expect(d.where((x) => x.contains('mục tiêu tiết kiệm')), isEmpty, reason: 'Premium 3 = Basic 3');
      expect(d.where((x) => x.contains('hóa đơn định kỳ')), isEmpty, reason: 'Premium 2 < Basic 3');
    });

    test('⭐ B1: quyền Basic tắt mà cột Premium CŨNG tắt → không kể; cột Premium thiếu khoá → kể', () {
      final g = TrangThaiGoi(
          loai: LoaiGoi.basic,
          nhanLuc: now,
          quyenTinhNang: const {'export_reports': false, 'cashflow_forecast': false},
          quyenPremium: const {'export_reports': false});
      final d = dacQuyenPremium(g);
      expect(d, isNot(contains(MaQuyen.exportReports.ten)), reason: 'kể là hứa thứ mua rồi vẫn khoá');
      expect(d, contains(MaQuyen.cashflowForecast.ten));
    });

    test('trần null (không giới hạn với Basic) không được kể', () {
      final g = TrangThaiGoi(loai: LoaiGoi.basic, nhanLuc: now, tran: const TranGoi(vi: 3));
      final d = dacQuyenPremium(g);
      expect(d, contains('Không giới hạn ví'));
      expect(d.where((x) => x.startsWith('Không giới hạn')), hasLength(1));
    });

    test('bảng lưu là của Premium → dùng mặc định: 3 trần + 3 quyền AI', () {
      final g = TrangThaiGoi(
          loai: LoaiGoi.premium,
          hetHan: now.add(const Duration(days: 10)),
          nhanLuc: now,
          tran: const TranGoi(),
          quyenTinhNang: {for (final m in MaQuyen.values) m.maServer: true});
      expect(dacQuyenPremium(g), [
        'Không giới hạn ví',
        'Không giới hạn ngân sách',
        'Không giới hạn mục tiêu tiết kiệm',
        MaQuyen.aiAssistant.ten,
        MaQuyen.aiQuickInput.ten,
        MaQuyen.aiEdgeModel.ten,
      ]);
    });
  });

  group('tomTatTran — dòng phụ thẻ Gói tab Cá nhân', () {
    test('mọi trần có số, theo thứ tự cố định', () {
      expect(tomTatTran(const TranGoi(vi: 3, nganSach: 3, mucTieu: 3, hoaDon: 3, danhMucRieng: 5)),
          '3\u00A0ví · 3\u00A0ngân\u00A0sách · 3\u00A0mục\u00A0tiêu · 3\u00A0hoá\u00A0đơn · 5\u00A0danh\u00A0mục\u00A0riêng');
    });
    test('trần null bị bỏ, không in "null ví"', () {
      expect(tomTatTran(const TranGoi(vi: 3, mucTieu: 2)), '3\u00A0ví · 2\u00A0mục\u00A0tiêu');
      expect(tomTatTran(const TranGoi()), '');
    });
  });
}
