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

    test('bốn loại báo TIỀN VỪA RỜI VÍ không chịu công tắc nhóm', () {
      const p = NotificationPrefs(nhomTat: {
        NotificationGroup.bill,
        NotificationGroup.goal,
      });

      expect(p.chapNhan(NotificationKind.billAutoPaid), isTrue);
      expect(p.chapNhan(NotificationKind.billAutoPayFailed), isTrue);
      expect(p.chapNhan(NotificationKind.goalAutoDeposited), isTrue);
      expect(p.chapNhan(NotificationKind.goalAutoDepositFailed), isTrue,
          reason: 'Đây là bốn loại DUY NHẤT báo việc tiền thật rời ví trong '
              'lúc người dùng vắng mặt. "Đừng nhắc tôi hoá đơn sắp tới hạn" và '
              '"đừng cho tôi biết app vừa rút tiền của tôi" là hai câu hoàn '
              'toàn khác nhau, và người dùng chỉ gạt được một công tắc. Muốn '
              'im hẳn thì đã có công tắc tổng cho thông báo hệ điều hành.');
    });

    test('tắt nhóm vẫn chặn các loại KHÁC của chính nhóm ấy', () {
      const p = NotificationPrefs(nhomTat: {
        NotificationGroup.bill,
        NotificationGroup.goal,
      });

      expect(p.chapNhan(NotificationKind.billDueSoon), isFalse);
      expect(p.chapNhan(NotificationKind.billOverdue), isFalse);
      expect(p.chapNhan(NotificationKind.goalBehind), isFalse);
      expect(p.chapNhan(NotificationKind.goalCompleted), isFalse,
          reason: 'Ngoại lệ chỉ dành cho bốn loại tự chuyển tiền. Nới rộng ra '
              'cả nhóm là công tắc mất tác dụng và người dùng sẽ tắt luôn công '
              'tắc tổng — mất hết.');
    });
  });

  group('giờ im lặng', () {
    DateTime luc(int gio, [int phut = 0]) =>
        DateTime(2026, 9, 15, gio, phut);

    test('mặc định TẮT — không im lặng giờ nào cả', () {
      const p = NotificationPrefs.macDinh;

      expect(p.imLangBat, isFalse);
      for (var gio = 0; gio < 24; gio++) {
        expect(p.dangImLang(luc(gio)), isFalse,
            reason: 'Bật sẵn là lặng lẽ đổi hành vi của mọi bản đã cài: cảnh '
                'báo vượt ngân sách lúc 23h thôi hiện ra ngoài mà không ai '
                'báo. Cùng lý lẽ với việc lưu nhóm bị TẮT thay vì nhóm bật.');
      }
    });

    test('khoảng QUA NỬA ĐÊM là ca chính, phải đúng cả hai phía', () {
      const p = NotificationPrefs(
        imLangBat: true,
        imLangTuPhut: 22 * 60,
        imLangDenPhut: 7 * 60,
      );

      expect(p.dangImLang(luc(23)), isTrue);
      expect(p.dangImLang(luc(2)), isTrue,
          reason: '2 giờ sáng nằm SAU nửa đêm nên số phút của nó nhỏ hơn mốc '
              'bắt đầu. Phép so "tu <= x < den" trần sẽ trả false ở đây, và '
              'giờ im lặng im lặng hỏng đúng nửa khoảng.');
      expect(p.dangImLang(luc(12)), isFalse);
    });

    test('khoảng trong CÙNG NGÀY vẫn phải đúng', () {
      const p = NotificationPrefs(
        imLangBat: true,
        imLangTuPhut: 13 * 60,
        imLangDenPhut: 15 * 60,
      );

      expect(p.dangImLang(luc(14)), isTrue);
      expect(p.dangImLang(luc(9)), isFalse);
      expect(p.dangImLang(luc(23)), isFalse);
    });

    test('biên: tính từ mốc đầu, không tính mốc cuối', () {
      const p = NotificationPrefs(
        imLangBat: true,
        imLangTuPhut: 22 * 60 + 30,
        imLangDenPhut: 7 * 60,
      );

      expect(p.dangImLang(luc(22, 29)), isFalse);
      expect(p.dangImLang(luc(22, 30)), isTrue);
      expect(p.dangImLang(luc(6, 59)), isTrue);
      expect(p.dangImLang(luc(7, 0)), isFalse,
          reason: 'Mốc cuối là lúc im lặng KẾT THÚC. Tính cả nó thì một khoảng '
              '22:00–22:00 sẽ thành im lặng cả ngày.');
    });

    test('hai mốc trùng nhau nghĩa là KHÔNG im lặng, không phải cả ngày', () {
      const p = NotificationPrefs(
        imLangBat: true,
        imLangTuPhut: 22 * 60,
        imLangDenPhut: 22 * 60,
      );

      expect(p.dangImLang(luc(22)), isFalse);
      expect(p.dangImLang(luc(3)), isFalse,
          reason: 'Người dùng lỡ tay đặt hai mốc bằng nhau không được mất sạch '
              'thông báo hệ điều hành — đó là kiểu hỏng họ sẽ không bao giờ '
              'lần ra nguyên nhân.');
    });

    test('JSON hỏng hoặc ngoài dải quy về mặc định chứ không ném', () {
      final p = NotificationPrefs.fromJson(const {
        'imLangBat': 'có',
        'imLangTuPhut': 5000,
        'imLangDenPhut': -3,
      });

      expect(p.imLangBat, isFalse);
      expect(p.imLangTuPhut, NotificationPrefs.macDinh.imLangTuPhut);
      expect(p.imLangDenPhut, NotificationPrefs.macDinh.imLangDenPhut);
    });

    test('đi trọn vòng qua JSON', () {
      const goc = NotificationPrefs(
        imLangBat: true,
        imLangTuPhut: 21 * 60 + 45,
        imLangDenPhut: 6 * 60 + 15,
      );

      final ve = NotificationPrefs.fromJson(goc.toJson());

      expect(ve, goc,
          reason: 'Thiếu một trường trong toJson/fromJson thì tuỳ chọn im lặng '
              'trở về mặc định sau mỗi lần mở app — hỏng im lặng, đúng nghĩa '
              'đen.');
    });
  });

  group('ngưỡng số dư ví thấp', () {
    test('mặc định là 0, nghĩa là TẮT', () {
      expect(NotificationPrefs.macDinh.nguongSoDuThap, 0,
          reason: 'Bật sẵn là lặng lẽ đổi hành vi của mọi bản đã cài — cùng lý '
              'lẽ với giờ im lặng và với việc lưu nhóm bị TẮT. Người dùng chưa '
              'từng thấy tuỳ chọn này không được đột nhiên nhận thông báo mới.');
    });

    test('đi trọn vòng qua JSON', () {
      const goc = NotificationPrefs(nguongSoDuThap: 250000);

      expect(NotificationPrefs.fromJson(goc.toJson()), goc,
          reason: 'Quên trường trong toJson/fromJson thì ngưỡng người dùng đặt '
              'biến mất sau mỗi lần mở app, mà không có lỗi nào báo ra.');
    });

    test('thiếu trường quy về 0 chứ không ném', () {
      expect(NotificationPrefs.fromJson(const {}).nguongSoDuThap, 0,
          reason: 'Mọi bản ghi có sẵn trên máy người dùng đều thiếu trường này.');
    });

    test('sai kiểu quy về 0', () {
      expect(
        NotificationPrefs.fromJson(const {'nguongSoDuThap': '250000'})
            .nguongSoDuThap,
        0,
      );
    });

    test('số âm quy về 0', () {
      expect(
        NotificationPrefs.fromJson(const {'nguongSoDuThap': -1}).nguongSoDuThap,
        0,
        reason: 'Ngưỡng âm chỉ có thể đến từ dữ liệu hỏng, và nếu lọt qua thì '
            'nó bật cảnh báo cho mọi ví có số dư dương.',
      );
    });

    test('số vượt trần quy về 0', () {
      expect(
        NotificationPrefs.fromJson(
                const {'nguongSoDuThap': 1000000000000}).nguongSoDuThap,
        0,
        reason: 'Một con số vô nghĩa lớn biến cảnh báo thành luôn-bật cho mọi '
            'ví — cùng kiểu hỏng mà BudgetEntity.warningRatio đã chặn.',
      );
    });

    test('copyWith đổi được ngưỡng', () {
      expect(
        NotificationPrefs.macDinh.copyWith(nguongSoDuThap: 100000)
            .nguongSoDuThap,
        100000,
      );
    });
  });

  test('copyWith chỉ đổi thứ được nêu', () {
    const goc = NotificationPrefs.macDinh;
    final moi = goc.copyWith(gioNhac: 20);

    expect(moi.gioNhac, 20);
    expect(moi.phutNhac, goc.phutNhac);
    expect(moi.osBat, goc.osBat);
    expect(moi.soNgayNhacHoaDon, goc.soNgayNhacHoaDon);
    expect(moi.nguongSoDuThap, goc.nguongSoDuThap);
  });
}
