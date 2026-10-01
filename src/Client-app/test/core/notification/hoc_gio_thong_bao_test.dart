/// `deXuatThongBao` — học giờ nhắc và nhóm bị lờ từ nhật ký B5a (B5b).
///
/// Spec `docs/superpowers/specs/2026-09-28-b5b-hoc-gio-thong-bao-design.md`.
/// Mọi đề xuất là **gợi ý**; hàm này không đổi tuỳ chọn nào. Ba điều hỏng im
/// lặng nếu sai: khoảng cách giờ phải tính **vòng 24 giờ**; "tới máy" của lịch
/// đặt trước đếm **theo khoá** (`dat_lich` đã qua > `huy_lich`), vì `luc` của
/// `dat_lich` là giờ NỔ còn của `huy_lich` là lúc HUỶ; và loại **luôn báo** không
/// được đếm vào nhóm bị lờ — tắt nhóm không làm im được chúng.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/notification/hoc_gio_thong_bao.dart';
import 'package:flowmoney/core/notification/prefs/notification_prefs.dart';
import 'package:flowmoney/core/notification/su_kien_thong_bao.dart';

var _id = 0;

AppNotificationEvent _sk(String khoa, String suKien, DateTime luc) =>
    AppNotificationEvent(
      id: 'e${_id++}',
      idaccount: 7,
      dedupeKey: khoa,
      suKien: suKien,
      luc: luc,
      osId: null,
    );

AppNotification _tb(String khoa, {DateTime? daBan}) => AppNotification(
      id: 'n${_id++}',
      idaccount: 7,
      kind: 'x',
      dedupeKey: khoa,
      title: 't',
      body: 'b',
      severity: 'info',
      createdAt: daBan ?? DateTime(2027, 1, 1),
      osDeliveredAt: daBan,
    );

void main() {
  final now = DateTime(2027, 3, 1, 9);
  const khoaHd = 'billDue:b1:2027-02-10:3';
  const prefs = NotificationPrefs(gioNhac: 8, phutNhac: 0);

  List<DeXuatThongBao> chay({
    List<AppNotificationEvent> nhatKy = const [],
    List<AppNotification> thongBao = const [],
    List<DateTime> mocGhi = const [],
    NotificationPrefs p = prefs,
    bool coQuyen = true,
  }) =>
      deXuatThongBao(
        nhatKy: nhatKy,
        thongBao: thongBao,
        mocGhiGiaoDich: mocGhi,
        prefs: p,
        coQuyen: coQuyen,
        now: now,
      );

  DeXuatThongBao? loai(List<DeXuatThongBao> r, LoaiDeXuat l) =>
      r.where((e) => e.loai == l).firstOrNull;

  /// 12 cú lúc 20:00–20:11 + 13 cú rải 07:45 → 18:45 (ô 07:30 được 2).
  List<AppNotificationEvent> chamHd({String khoa = khoaHd, String suKien = SuKienThongBao.chamHdh, int bot = 0}) => [
        for (var i = 0; i < 12; i++) _sk(khoa, suKien, DateTime(2027, 1, 1 + i, 20, i)),
        for (var i = 0; i < 13 - bot; i++)
          _sk(khoa, suKien, DateTime(2027, 2, 1 + i, 7 + (i % 12), 45)),
      ];

  group('giờ nhắc hoá đơn', () {
    test('⭐ 25 cú, 12 cú lúc 20:00–20:29 → đề xuất 20:00', () {
      final d = loai(chay(nhatKy: chamHd()), LoaiDeXuat.gioHoaDon);
      expect(d, isNotNull);
      expect(d!.gio, (gio: 20, phut: 0));
      expect(d.soMau, 25);
      expect(d.khoa, 'deXuat:gioHoaDon');
    });

    test('giờ đang đặt đã là 20:00 → không đề xuất', () {
      expect(
          loai(chay(nhatKy: chamHd(), p: const NotificationPrefs(gioNhac: 20)),
              LoaiDeXuat.gioHoaDon),
          isNull);
    });

    test('19 cú (dưới cửa 20) → không', () {
      expect(loai(chay(nhatKy: chamHd(bot: 6)), LoaiDeXuat.gioHoaDon), isNull);
    });

    test('25 cú rải 25 ô khác nhau → không ô nào ≥ 35 % → không', () {
      final nk = [
        for (var i = 0; i < 25; i++)
          _sk(khoaHd, SuKienThongBao.chamHdh, DateTime(2027, 1, 1 + i, i ~/ 2, (i % 2) * 30)),
      ];
      expect(loai(chay(nhatKy: nk), LoaiDeXuat.gioHoaDon), isNull);
    });

    test('khoảng cách tính VÒNG 24 giờ: 23:30 và 00:00 cách 30 phút', () {
      final nk = [
        for (var i = 0; i < 12; i++) _sk(khoaHd, SuKienThongBao.chamHdh, DateTime(2027, 1, 1 + i, 0, i)),
        for (var i = 0; i < 13; i++) _sk(khoaHd, SuKienThongBao.chamHdh, DateTime(2027, 2, 1 + i, 7 + i, 0)),
      ];
      expect(
          loai(chay(nhatKy: nk, p: const NotificationPrefs(gioNhac: 23, phutNhac: 30)),
              LoaiDeXuat.gioHoaDon),
          isNull,
          reason: '|0 − 1410| = 1410 phút nếu không tính vòng — đề xuất một giờ '
              'chỉ lệch 30 phút');
      expect(
          loai(chay(nhatKy: nk, p: const NotificationPrefs(gioNhac: 23, phutNhac: 0)),
                  LoaiDeXuat.gioHoaDon)
              ?.gio,
          (gio: 0, phut: 0));
    });

    test('gat_bo / hoan / doc_tat_ca KHÔNG phải phản ứng tích cực', () {
      final nk = [
        for (final m in [SuKienThongBao.gatBo, SuKienThongBao.hoan, SuKienThongBao.docTatCa])
          ...chamHd(suKien: m),
      ];
      expect(loai(chay(nhatKy: nk), LoaiDeXuat.gioHoaDon), isNull);
    });

    test('nut_tra_ngay và mo_trong_app CÓ đếm', () {
      final nk = [
        ...chamHd(suKien: SuKienThongBao.nutTraNgay).take(13),
        ...chamHd(suKien: SuKienThongBao.moTrongApp).skip(13),
      ];
      expect(loai(chay(nhatKy: nk), LoaiDeXuat.gioHoaDon)?.gio, (gio: 20, phut: 0));
    });

    test('hai ô bằng nhau → ô gần giờ đang đặt hơn', () {
      final nk = [
        for (var i = 0; i < 10; i++) _sk(khoaHd, SuKienThongBao.chamHdh, DateTime(2027, 1, 1 + i, 19, 5)),
        for (var i = 0; i < 10; i++) _sk(khoaHd, SuKienThongBao.chamHdh, DateTime(2027, 1, 11 + i, 21, 5)),
        for (var i = 0; i < 5; i++) _sk(khoaHd, SuKienThongBao.chamHdh, DateTime(2027, 2, 1 + i, 9 + i, 0)),
      ];
      expect(loai(chay(nhatKy: nk, p: const NotificationPrefs(gioNhac: 22, phutNhac: 30)), LoaiDeXuat.gioHoaDon)?.gio,
          (gio: 21, phut: 0), reason: '21:00 cách 90 phút, 19:00 cách 210 phút');
      expect(loai(chay(nhatKy: nk, p: const NotificationPrefs(gioNhac: 17)), LoaiDeXuat.gioHoaDon)?.gio,
          (gio: 19, phut: 0), reason: '19:00 cách 120 phút, 21:00 cách 240 phút');
    });

    test('phản ứng của nhóm KHÁC không đếm cho giờ nhắc hoá đơn', () {
      expect(loai(chay(nhatKy: chamHd(khoa: 'budgetNear:n1:2027-01:70')), LoaiDeXuat.gioHoaDon), isNull);
    });

    test('nhóm Hoá đơn đang tắt hoặc công tắc tổng tắt → không đề xuất giờ', () {
      expect(
          loai(chay(nhatKy: chamHd(), p: const NotificationPrefs(nhomTat: {NotificationGroup.bill})),
              LoaiDeXuat.gioHoaDon),
          isNull,
          reason: 'đổi giờ của một lời nhắc đang tắt là lời mời vô nghĩa');
      expect(chay(nhatKy: chamHd(), p: const NotificationPrefs(osBat: false)), isEmpty);
    });

    test('phản ứng cũ hơn 180 ngày không đếm', () {
      final nk = [
        for (final e in chamHd()) e.copyWith(luc: e.luc.subtract(const Duration(days: 200))),
      ];
      expect(loai(chay(nhatKy: nk), LoaiDeXuat.gioHoaDon), isNull);
    });
  });

  group('tổng kết tuần', () {
    /// 25 thứ Bảy liền, 09:05 — lùi từ 27/02/2027.
    final chamTuan = [
      for (var i = 0; i < 25; i++)
        _sk('weekly:2027-W0$i:2027-01-04', SuKienThongBao.chamHdh,
            DateTime(2027, 2, 27, 9, 5).subtract(Duration(days: 7 * i))),
    ];

    test('đề xuất thứ Bảy 09:00 khi đang đặt thứ Hai 08:00', () {
      final d = loai(
          chay(nhatKy: chamTuan, p: const NotificationPrefs(tongKetTuanBat: true)),
          LoaiDeXuat.gioTongKet);
      expect(d?.gio, (gio: 9, phut: 0));
      expect(d?.thu, DateTime.saturday);
    });

    test('thứ đã đúng → chỉ đề xuất giờ (thu == null)', () {
      final d = loai(
          chay(
              nhatKy: chamTuan,
              p: const NotificationPrefs(tongKetTuanBat: true, thuTongKet: DateTime.saturday)),
          LoaiDeXuat.gioTongKet);
      expect(d?.gio, (gio: 9, phut: 0));
      expect(d?.thu, isNull);
    });

    test('giờ đã đúng → chỉ đề xuất thứ (gio == null)', () {
      final d = loai(
          chay(
              nhatKy: chamTuan,
              p: const NotificationPrefs(tongKetTuanBat: true, gioTongKet: 9)),
          LoaiDeXuat.gioTongKet);
      expect(d?.gio, isNull);
      expect(d?.thu, DateTime.saturday);
    });

    test('tổng kết tuần đang tắt → không đề xuất', () {
      expect(loai(chay(nhatKy: chamTuan), LoaiDeXuat.gioTongKet), isNull);
    });
  });

  group('giờ nhắc ghi chép', () {
    final moc = [for (var i = 0; i < 25; i++) DateTime(2027, 1, 1 + i, 21, 10)];

    test('25 lần ghi lúc 21:10 → đề xuất 21:00 khi đang đặt 20:00', () {
      final d = loai(chay(mocGhi: moc, p: const NotificationPrefs(nhacGhiChepBat: true)),
          LoaiDeXuat.gioGhiChep);
      expect(d?.gio, (gio: 21, phut: 0));
      expect(d?.soMau, 25);
    });

    test('nhắc ghi chép đang tắt → không đề xuất', () {
      expect(loai(chay(mocGhi: moc), LoaiDeXuat.gioGhiChep), isNull);
    });
  });

  group('nhóm bị lờ', () {
    /// 20 thông báo Ngân sách bắn ngay, rải 60 ngày tới 03/02 — mọi lượt đã hết
    /// cửa 48 giờ tính tới `now`.
    final budget = [
      for (var i = 0; i < 20; i++)
        _tb('budgetNear:n$i:2027-01:70', daBan: DateTime(2027, 2, 3, 10).subtract(Duration(days: 3 * i))),
    ];

    test('⭐ 20 tới máy, 10 gần nhất không được mở → đề xuất tắt nhóm Ngân sách', () {
      final d = loai(chay(thongBao: budget), LoaiDeXuat.tatNhom);
      expect(d?.nhom, NotificationGroup.budget);
      expect(d?.khoa, 'deXuat:tatNhom:budget');
      expect(d?.soMau, 20);
    });

    test('một trong 10 gần nhất được chạm sau 30 giờ → không', () {
      final nk = [_sk('budgetNear:n2:2027-01:70', SuKienThongBao.chamHdh, budget[2].osDeliveredAt!.add(const Duration(hours: 30)))];
      expect(loai(chay(thongBao: budget, nhatKy: nk), LoaiDeXuat.tatNhom), isNull);
    });

    test('chạm sau 50 giờ (quá cửa 48) → vẫn đề xuất', () {
      final nk = [_sk('budgetNear:n2:2027-01:70', SuKienThongBao.chamHdh, budget[2].osDeliveredAt!.add(const Duration(hours: 50)))];
      expect(loai(chay(thongBao: budget, nhatKy: nk), LoaiDeXuat.tatNhom)?.nhom, NotificationGroup.budget);
    });

    test('19 tới máy → dưới cửa, không', () {
      expect(loai(chay(thongBao: budget.skip(1).toList()), LoaiDeXuat.tatNhom), isNull);
    });

    test('lượt còn trong cửa 48 giờ chưa được tính — chưa biết người dùng có mở', () {
      final moi = [...budget.skip(1), _tb('budgetNear:moi:2027-03:70', daBan: now.subtract(const Duration(hours: 5)))];
      expect(loai(chay(thongBao: moi), LoaiDeXuat.tatNhom), isNull,
          reason: 'chỉ còn 19 lượt đã hết cửa theo dõi');
    });

    test('nhóm đang tắt → không xét; quyền tắt → không đề xuất tắt nhóm', () {
      expect(
          loai(chay(thongBao: budget, p: const NotificationPrefs(nhomTat: {NotificationGroup.budget})),
              LoaiDeXuat.tatNhom),
          isNull);
      final r = chay(thongBao: budget, nhatKy: chamHd(), coQuyen: false);
      expect(loai(r, LoaiDeXuat.tatNhom), isNull,
          reason: 'quyền tắt thì "tới máy" có thể không có thật (giới hạn B5a)');
      expect(loai(r, LoaiDeXuat.gioHoaDon), isNotNull, reason: 'giờ vẫn đề xuất');
    });

    test('⚠️ loại LUÔN BÁO không đếm — tắt nhóm không làm im được chúng', () {
      final tuTra = [
        for (var i = 0; i < 20; i++)
          _tb('billAuto:b$i:2027-01-0$i', daBan: DateTime(2027, 2, 3).subtract(Duration(days: 2 * i))),
      ];
      expect(loai(chay(thongBao: tuTra), LoaiDeXuat.tatNhom), isNull);
    });

    group('lịch đặt trước — đếm theo khoá', () {
      /// 20 lời nhắc hoá đơn nổ 08:00, lùi từ 01/02.
      List<AppNotificationEvent> dat() => [
            for (var i = 0; i < 20; i++)
              _sk('billDue:h$i:2027-01-01:3', SuKienThongBao.datLich,
                  DateTime(2027, 2, 1, 8).subtract(Duration(days: 3 * i))),
          ];

      test('20 dat_lich đã nổ, không huỷ, không phản ứng → đề xuất tắt nhóm Hoá đơn', () {
        expect(loai(chay(nhatKy: dat()), LoaiDeXuat.tatNhom)?.nhom, NotificationGroup.bill);
      });

      test('⚠️ huy_lich (luc = lúc HUỶ, SỚM hơn giờ nổ) vẫn loại được lịch ấy', () {
        final d = dat();
        final huy = _sk(d.first.dedupeKey, SuKienThongBao.huyLich,
            d.first.luc.subtract(const Duration(days: 1)));
        expect(loai(chay(nhatKy: [...d, huy]), LoaiDeXuat.tatNhom), isNull,
            reason: 'còn 19 lượt tới máy. Luật "huy_lich SAU dat_lich" so theo '
                'luc thì không bao giờ khớp, và hoá đơn trả trước giờ nhắc bị '
                'tính là "tới máy mà bị lờ"');
      });

      test('đổi giờ khi đang chờ (2 dat_lich + 1 huy_lich cùng khoá) → tới máy MỘT lần', () {
        final d = dat();
        final k = d.first.dedupeKey;
        final them = [
          _sk(k, SuKienThongBao.huyLich, d.first.luc.subtract(const Duration(hours: 2))),
          _sk(k, SuKienThongBao.datLich, d.first.luc.add(const Duration(hours: 12))),
        ];
        final r = loai(chay(nhatKy: [...d, ...them]), LoaiDeXuat.tatNhom);
        expect(r?.soMau, 20, reason: 'khoá ấy tới máy đúng một lần, không phải hai');
      });

      test('dat_lich chưa tới giờ nổ không đếm', () {
        final d = [
          ...dat().skip(1),
          _sk('billDue:tuonglai:2027-03-10:3', SuKienThongBao.datLich, now.add(const Duration(days: 7))),
        ];
        expect(loai(chay(nhatKy: d), LoaiDeXuat.tatNhom), isNull);
      });
    });
  });

  group('Bỏ qua', () {
    test('bo_qua_de_xuat 29 ngày trước → im; 31 ngày → hiện lại', () {
      AppNotificationEvent boQua(int ngay) => _sk('deXuat:gioHoaDon', SuKienThongBao.boQuaDeXuat,
          now.subtract(Duration(days: ngay)));
      expect(loai(chay(nhatKy: [...chamHd(), boQua(29)]), LoaiDeXuat.gioHoaDon), isNull);
      expect(loai(chay(nhatKy: [...chamHd(), boQua(31)]), LoaiDeXuat.gioHoaDon), isNotNull);
    });

    test('bỏ qua một đề xuất không làm im đề xuất khác', () {
      final r = chay(
          nhatKy: [
            ...chamHd(),
            _sk('deXuat:tatNhom:budget', SuKienThongBao.boQuaDeXuat, now.subtract(const Duration(days: 1))),
          ],
          thongBao: [
            for (var i = 0; i < 20; i++)
              _tb('budgetNear:n$i:2027-01:70', daBan: DateTime(2027, 2, 3).subtract(Duration(days: 3 * i))),
          ]);
      expect(loai(r, LoaiDeXuat.tatNhom), isNull);
      expect(loai(r, LoaiDeXuat.gioHoaDon), isNotNull);
    });
  });
}
