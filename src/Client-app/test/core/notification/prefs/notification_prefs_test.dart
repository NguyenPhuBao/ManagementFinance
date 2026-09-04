/// `NotificationPrefs` — tuỳ chọn thông báo của một tài khoản.
///
/// Đây là dữ liệu đọc từ đĩa, nên hai thứ đáng canh nhất **không phải** là
/// getter/setter mà là:
///
/// 1. **Mặc định khi thiếu.** Người dùng đang có sẵn tài khoản sẽ đọc lên một
///    khoá không tồn tại. Nếu mặc định là "tắt hết" thì tính năng thông báo
///    lặng lẽ chết với mọi người đã cài app trước bản này, và không ai báo lỗi
///    vì "không có thông báo" trông y hệt "không có gì đáng báo".
/// 2. **Chịu được dữ liệu hỏng.** JSON méo, thiếu trường, sai kiểu, giờ nằm
///    ngoài 0–23 — tất cả phải quy về giá trị dùng được chứ không ném, vì nơi
///    gọi là vòng quét và một ngoại lệ ở đó làm chết cả trung tâm thông báo.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/notification/notification_rules.dart';
import 'package:flowmoney/core/notification/prefs/notification_prefs.dart';

void main() {
  group('mặc định', () {
    test('bật hết mọi nhóm và bật cả thông báo hệ điều hành', () {
      const p = NotificationPrefs.macDinh;

      expect(p.osBat, isTrue);
      for (final nhom in NotificationGroup.values) {
        expect(p.batNhom(nhom), isTrue,
            reason: 'Nhóm ${nhom.name} phải bật sẵn. Mặc định tắt là tính năng '
                'lặng lẽ chết với mọi người đã cài app trước bản này, và không '
                'ai báo lỗi vì "không có thông báo" trông y hệt "không có gì '
                'đáng báo".');
      }
    });

    test('giờ nhắc là 08:00 và nhắc trước 3 ngày', () {
      const p = NotificationPrefs.macDinh;
      expect(p.gioNhac, 8,
          reason: 'Mốc mặc định phải nằm trong giờ thức. 0 giờ là nhắc hoá đơn '
              'lúc nửa đêm — xem bẫy 7.3.');
      expect(p.phutNhac, 0);
      expect(p.soNgayNhacHoaDon, 3,
          reason: 'Khớp @default("3") của cột Time_notification phía backend, '
              'để hoá đơn tạo ở client và ở nơi khác hành xử như nhau.');
    });
  });

  group('đọc/ghi JSON', () {
    test('đi một vòng không mất gì', () {
      const goc = NotificationPrefs(
        osBat: false,
        nhomTat: {NotificationGroup.goal, NotificationGroup.system},
        gioNhac: 21,
        phutNhac: 30,
        soNgayNhacHoaDon: 7,
      );

      final ve = NotificationPrefs.fromJson(goc.toJson());

      expect(ve.osBat, isFalse);
      expect(ve.batNhom(NotificationGroup.goal), isFalse);
      expect(ve.batNhom(NotificationGroup.system), isFalse);
      expect(ve.batNhom(NotificationGroup.bill), isTrue);
      expect(ve.batNhom(NotificationGroup.budget), isTrue);
      expect(ve.gioNhac, 21);
      expect(ve.phutNhac, 30);
      expect(ve.soNgayNhacHoaDon, 7);
    });

    test('JSON rỗng cho ra đúng bản mặc định', () {
      expect(NotificationPrefs.fromJson(const {}), NotificationPrefs.macDinh,
          reason: 'Đây là đường đi của mọi tài khoản đã tồn tại trước bản này.');
    });

    test('trường sai kiểu bị bỏ qua chứ không ném', () {
      final p = NotificationPrefs.fromJson(const {
        'osBat': 'có',
        'nhomTat': 'bill',
        'gioNhac': '21',
        'soNgayNhacHoaDon': null,
      });

      expect(p, NotificationPrefs.macDinh,
          reason: 'Nơi gọi là vòng quét thông báo; một ngoại lệ ở đó làm chết '
              'cả trung tâm thông báo trong app. Dữ liệu hỏng phải quy về mặc '
              'định dùng được.');
    });

    test('tên nhóm lạ trong dữ liệu cũ bị bỏ qua', () {
      final p = NotificationPrefs.fromJson(const {
        'nhomTat': ['bill', 'nhom_khong_ton_tai'],
      });

      expect(p.batNhom(NotificationGroup.bill), isFalse);
      expect(p.batNhom(NotificationGroup.budget), isTrue,
          reason: 'Một tên lạ — do bản app cũ hoặc do sửa tay — chỉ được làm '
              'hỏng chính nó, không được kéo cả bản ghi về mặc định.');
    });
  });

  group('giờ nhắc nằm ngoài dải', () {
    test('giờ 24 và giờ âm quy về mặc định', () {
      expect(NotificationPrefs.fromJson(const {'gioNhac': 24}).gioNhac, 8);
      expect(NotificationPrefs.fromJson(const {'gioNhac': -1}).gioNhac, 8,
          reason: 'zonedSchedule nhận giờ ngoài dải sẽ trôi sang ngày khác — '
              'nhắc hoá đơn nổ sai ngày mà không có lỗi nào báo ra.');
    });

    test('phút 60 quy về mặc định', () {
      expect(NotificationPrefs.fromJson(const {'phutNhac': 60}).phutNhac, 0);
    });

    test('giờ 0 và giờ 23 là hợp lệ', () {
      expect(NotificationPrefs.fromJson(const {'gioNhac': 0}).gioNhac, 0,
          reason: 'Biên dưới hợp lệ — đừng nhầm 0 với "chưa đặt".');
      expect(NotificationPrefs.fromJson(const {'gioNhac': 23}).gioNhac, 23);
    });

    test('số ngày nhắc âm hoặc quá lớn quy về mặc định', () {
      expect(NotificationPrefs.fromJson(const {'soNgayNhacHoaDon': -1})
          .soNgayNhacHoaDon, 3);
      expect(
          NotificationPrefs.fromJson(const {'soNgayNhacHoaDon': 400})
              .soNgayNhacHoaDon,
          3,
          reason: 'Cửa sổ quét chỉ 30 ngày; nhắc trước 400 ngày là một mốc '
              'không bao giờ tới, tức là người dùng tưởng đã bật mà không bao '
              'giờ nhận được gì.');
    });

    test('số ngày nhắc 0 là hợp lệ — nhắc đúng ngày đến hạn', () {
      expect(
          NotificationPrefs.fromJson(const {'soNgayNhacHoaDon': 0})
              .soNgayNhacHoaDon,
          0);
    });
  });

  group('ánh xạ loại thông báo sang nhóm', () {
    test('mỗi loại thuộc đúng một nhóm', () {
      expect(nhomCua(NotificationKind.billDueSoon), NotificationGroup.bill);
      expect(nhomCua(NotificationKind.billOverdue), NotificationGroup.bill);
      expect(nhomCua(NotificationKind.budgetNearLimit),
          NotificationGroup.budget);
      expect(nhomCua(NotificationKind.budgetOverspent),
          NotificationGroup.budget);
      expect(nhomCua(NotificationKind.goalCompleted), NotificationGroup.goal);
      expect(nhomCua(NotificationKind.goalBehind), NotificationGroup.goal);
      expect(nhomCua(NotificationKind.syncFailed), NotificationGroup.system);
      expect(nhomCua(NotificationKind.walletNegative),
          NotificationGroup.system);
    });

    test('tắt một nhóm thì chặn đúng các loại của nhóm đó', () {
      const p = NotificationPrefs(nhomTat: {NotificationGroup.budget});

      expect(p.chapNhan(NotificationKind.budgetNearLimit), isFalse);
      expect(p.chapNhan(NotificationKind.budgetOverspent), isFalse);
      expect(p.chapNhan(NotificationKind.billDueSoon), isTrue,
          reason: 'Tắt nhóm ngân sách không được làm im nhóm hoá đơn — đó là '
              'lý do người dùng có bốn công tắc chứ không phải một.');
    });
  });

  test('copyWith chỉ đổi thứ được nêu', () {
    const goc = NotificationPrefs.macDinh;
    final moi = goc.copyWith(gioNhac: 20);

    expect(moi.gioNhac, 20);
    expect(moi.phutNhac, goc.phutNhac);
    expect(moi.osBat, goc.osBat);
    expect(moi.soNgayNhacHoaDon, goc.soNgayNhacHoaDon);
  });
}
