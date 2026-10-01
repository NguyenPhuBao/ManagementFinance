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
  mainTongKetTuan();
  mainBienDong();
  group('mặc định', () {
    test('bật hết mọi nhóm và bật cả thông báo hệ điều hành', () {
      const p = NotificationPrefs.macDinh;

      expect(p.osBat, isTrue);
      for (final nhom in NotificationGroup.values) {
        // Ngoại lệ DUY NHẤT: nhóm Biến động số dư (D1) — xem `mainBienDong`.
        if (nhom == NotificationGroup.bienDong) continue;
        expect(p.batNhom(nhom), isTrue,
            reason: 'Nhóm ${nhom.name} phải bật sẵn. Mặc định tắt là tính năng '
                'lặng lẽ chết với mọi người đã cài app trước bản này, và không '
                'ai báo lỗi vì "không có thông báo" trông y hệt "không có gì '
                'đáng báo".');
      }
      expect(p.batNhom(NotificationGroup.bienDong), isFalse,
          reason: 'Nhóm Biến động số dư là công tắc TÍNH NĂNG đọc thông báo '
              'ngân hàng, đứng sau một màn xin đồng ý bắt buộc (backend, Nghị '
              'định 13) — bật sẵn là bỏ qua màn ấy.');
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

  group('nhắc ghi chép hằng ngày', () {
    test('mặc định TẮT, và giờ mặc định là 20:00', () {
      const p = NotificationPrefs.macDinh;
      expect(p.nhacGhiChepBat, false,
          reason: 'Bật sẵn nghĩa là mọi bản đã cài bỗng nhiên nhận một thông '
              'báo mỗi ngày mà không ai báo trước — cùng lý lẽ đã dùng cho giờ '
              'im lặng và ngưỡng số dư thấp.');
      expect(p.gioNhacGhiChep, 20,
          reason: 'Giờ RIÊNG, không dùng chung gioNhac. Giờ nhắc chung mặc '
              'định 8h sáng vì nó là của hoá đơn; một lời nhắc "hôm nay ghi '
              'chép chưa" lúc 8h sáng là hỏi trước khi có gì để ghi.');
      expect(p.phutNhacGhiChep, 0);
    });

    test('JSON đi một vòng không mất gì', () {
      const goc = NotificationPrefs(
        nhacGhiChepBat: true,
        gioNhacGhiChep: 21,
        phutNhacGhiChep: 30,
      );
      final lai = NotificationPrefs.fromJson(goc.toJson());

      expect(lai.nhacGhiChepBat, true);
      expect(lai.gioNhacGhiChep, 21);
      expect(lai.phutNhacGhiChep, 30);
    });

    test('hai bản chỉ khác ba trường mới thì KHÔNG bằng nhau', () {
      // ⚠️ `expect(lai, goc)` ở test đi-một-vòng KHÔNG canh được điều này: mọi
      // trường khác vẫn bằng nhau, nên hai đối tượng so ra bằng ngay cả khi ba
      // trường mới bị bỏ quên trong `==`. Phải so hai bản chỉ khác đúng chúng.
      const bat = NotificationPrefs(nhacGhiChepBat: true);
      const tat = NotificationPrefs(nhacGhiChepBat: false);
      const khacGio = NotificationPrefs(nhacGhiChepBat: true, gioNhacGhiChep: 21);
      const khacPhut =
          NotificationPrefs(nhacGhiChepBat: true, phutNhacGhiChep: 30);

      expect(bat == tat, false,
          reason: 'Bỏ quên một trường trong == là trang cài đặt tưởng không có '
              'gì đổi và bỏ qua lần ghi — người dùng gạt công tắc rồi thấy nó '
              'tự trở về chỗ cũ.');
      expect(bat == khacGio, false);
      expect(bat == khacPhut, false);
      expect(bat.hashCode == tat.hashCode, false,
          reason: '`Object.hash` là hàm tất định, nên hai đầu vào khác nhau '
              'phải cho hai mã khác nhau. Bằng nhau ở đây nghĩa là trường ấy '
              'không được truyền vào hash — == và hashCode lệch nhau.');
    });

    test('bản ghi cũ thiếu ba trường thì rơi về TẮT', () {
      final cu = NotificationPrefs.fromJson(const {'osBat': true});
      expect(cu.nhacGhiChepBat, false,
          reason: 'Mọi bản ghi đang nằm trên máy người dùng đều thiếu trường '
              'này. Rơi về bật là đổi hành vi sau một lần cập nhật app.');
      expect(cu.gioNhacGhiChep, 20);
    });

    test('giờ và phút ngoài dải quy về mặc định', () {
      final xau = NotificationPrefs.fromJson(const {
        'nhacGhiChepBat': true,
        'gioNhacGhiChep': 24,
        'phutNhacGhiChep': 60,
      });
      expect(xau.gioNhacGhiChep, 20);
      expect(xau.phutNhacGhiChep, 0);
      expect(xau.nhacGhiChepBat, true,
          reason: 'Một trường hỏng chỉ được làm hỏng chính nó, không kéo cả '
              'bản ghi về mặc định.');
    });

    test('copyWith giữ nguyên ba trường khi không truyền', () {
      const goc = NotificationPrefs(
        nhacGhiChepBat: true,
        gioNhacGhiChep: 19,
        phutNhacGhiChep: 15,
      );
      final moi = goc.copyWith(osBat: false);

      expect(moi.nhacGhiChepBat, true);
      expect(moi.gioNhacGhiChep, 19);
      expect(moi.phutNhacGhiChep, 15);
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

  group('ngưỡng khoản chi lớn', () {
    test('mặc định là 0, nghĩa là TẮT', () {
      expect(NotificationPrefs.macDinh.nguongChiLon, 0,
          reason: 'Cùng lý lẽ với ngưỡng số dư: mọi bản ghi đang nằm trên máy '
              'người dùng đều thiếu trường này, nên bật sẵn là lặng lẽ bắn '
              'thông báo cho những khoản chính họ đã gõ từ mấy tháng trước.');
    });

    test('đi trọn vòng qua JSON', () {
      const goc = NotificationPrefs(nguongChiLon: 2000000);

      expect(NotificationPrefs.fromJson(goc.toJson()), goc,
          reason: 'Quên trường trong toJson/fromJson thì ngưỡng người dùng đặt '
              'biến mất sau mỗi lần mở app, mà không có lỗi nào báo ra.');
    });

    test('thiếu trường, sai kiểu, số âm và số vượt trần đều quy về 0', () {
      expect(NotificationPrefs.fromJson(const {}).nguongChiLon, 0);
      expect(
          NotificationPrefs.fromJson(const {'nguongChiLon': '2000000'})
              .nguongChiLon,
          0);
      expect(NotificationPrefs.fromJson(const {'nguongChiLon': -1}).nguongChiLon,
          0);
      expect(
          NotificationPrefs.fromJson(const {'nguongChiLon': 1000000000000})
              .nguongChiLon,
          0,
          reason: 'Một ngưỡng vô nghĩa lớn biến cảnh báo thành luôn-TẮT, thứ '
              'người dùng đọc thành "tính năng không chạy".');
    });

    test('copyWith đổi được ngưỡng', () {
      expect(
        NotificationPrefs.macDinh.copyWith(nguongChiLon: 1000000).nguongChiLon,
        1000000,
      );
    });

    test('⚠️ hai ngưỡng tiền là HAI trường độc lập', () {
      // Cùng kiểu, cùng khuôn, cùng trần — đúng điều kiện để một lần sửa nhầm
      // làm chúng dùng chung một ô nhớ mà không test nào khác bắt được.
      const p = NotificationPrefs(nguongSoDuThap: 200000, nguongChiLon: 5000000);

      expect(p.nguongSoDuThap, 200000);
      expect(p.nguongChiLon, 5000000);
      expect(NotificationPrefs.fromJson(p.toJson()), p);
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

/// Tuỳ chọn giờ **Tổng kết tuần** — thêm 2026-09-09.
///
/// Người dùng chốt (a) của spec theo phương án "giờ do người dùng chọn" thay
/// vì mốc cố định. Lý do nằm ở chỗ lịch đặt trước **không đi qua giờ im lặng**
/// (mục 5c `NOTIFICATION_FEATURE.md`): thứ khiến nhắc hoá đơn không phiền
/// không phải giờ của nó, mà là việc giờ ấy do người dùng đặt và đang nhìn
/// thấy trên màn hình.
void mainTongKetTuan() {
  group('NotificationPrefs — giờ tổng kết tuần', () {
    test('mặc định TẮT', () {
      expect(
        NotificationPrefs.macDinh.tongKetTuanBat,
        isFalse,
        reason: 'Cùng lý lẽ với nhacGhiChepBat và imLangBat: mọi bản ghi đang '
            'nằm trên máy người dùng đều thiếu trường này, nên bật sẵn là lặng '
            'lẽ cho cả tập người dùng hiện tại một thông báo mỗi tuần. Nặng '
            'hơn một bậc vì loại này nổ khi app đã ĐÓNG và không đi qua giờ im '
            'lặng.',
      );
    });

    test('bản ghi cũ không có trường công tắc thì vẫn TẮT', () {
      expect(
        NotificationPrefs.fromJson({'osBat': true}).tongKetTuanBat,
        isFalse,
      );
    });

    test('công tắc khứ hồi được qua JSON và copyWith', () {
      const p = NotificationPrefs(tongKetTuanBat: true);
      expect(NotificationPrefs.fromJson(p.toJson()).tongKetTuanBat, isTrue);
      expect(p.copyWith(tongKetTuanBat: false).tongKetTuanBat, isFalse);
    });

    test('mặc định là thứ Hai 08:00', () {
      const p = NotificationPrefs.macDinh;
      expect(p.thuTongKet, DateTime.monday);
      expect(p.gioTongKet, 8);
      expect(p.phutTongKet, 0);
    });

    test('bản ghi cũ thiếu ba trường vẫn đọc được, về mặc định', () {
      final p = NotificationPrefs.fromJson({'osBat': true});
      expect(
        (p.thuTongKet, p.gioTongKet, p.phutTongKet),
        (DateTime.monday, 8, 0),
        reason: 'Mọi bản ghi đang nằm trên máy người dùng đều thiếu ba trường '
            'này. Ném ở đây là chết cả trung tâm thông báo vì một tuỳ chọn.',
      );
    });

    test('thứ ngoài dải 1–7 quy về thứ Hai', () {
      for (final xau in [0, 8, -3, 99]) {
        expect(
          NotificationPrefs.fromJson({'thuTongKet': xau}).thuTongKet,
          DateTime.monday,
          reason: 'DateTime.weekday chạy 1–7. Một giá trị 0 hay 8 lọt vào phép '
              'tính mốc kế tiếp sẽ đẩy lịch lệch hẳn một tuần, im lặng.',
        );
      }
    });

    test('giờ và phút ngoài dải quy về mặc định', () {
      expect(NotificationPrefs.fromJson({'gioTongKet': 24}).gioTongKet, 8);
      expect(NotificationPrefs.fromJson({'phutTongKet': 60}).phutTongKet, 0);
    });

    test('khứ hồi JSON giữ nguyên ba trường', () {
      const p = NotificationPrefs(
        thuTongKet: DateTime.friday,
        gioTongKet: 20,
        phutTongKet: 30,
      );
      final lai = NotificationPrefs.fromJson(p.toJson());
      expect((lai.thuTongKet, lai.gioTongKet, lai.phutTongKet),
          (DateTime.friday, 20, 30));
    });

    test('copyWith đổi được từng trường một', () {
      const p = NotificationPrefs.macDinh;
      expect(p.copyWith(thuTongKet: DateTime.sunday).thuTongKet,
          DateTime.sunday);
      expect(p.copyWith(gioTongKet: 21).gioTongKet, 21);
      expect(p.copyWith(phutTongKet: 45).phutTongKet, 45);
    });
  });
}

/// D1 (2026-09-30) — cờ `docBienDong`: công tắc tính năng *đọc biến động số dư*.
///
/// Người dùng chốt: cờ RIÊNG thay vì đưa nhóm vào `nhomTat`, vì kho lưu nhóm bị
/// TẮT nên mọi nhóm mới tự bật với bản ghi cũ — đúng với thông báo thường, sai
/// với một tính năng đứng sau màn xin đồng ý bắt buộc.
void mainBienDong() {
  group('D1 — cờ docBienDong (nhóm Biến động số dư)', () {
    test('⭐ mặc định TẮT, kể cả với bản ghi cũ không có khoá', () {
      expect(NotificationPrefs.macDinh.docBienDong, isFalse);
      expect(NotificationPrefs.fromJson({'osBat': true}).docBienDong, isFalse,
          reason: 'Bản ghi lưu trước D1 không có khoá này; đọc thành BẬT là tự '
              'bật một tính năng đọc thông báo ngân hàng mà người dùng chưa '
              'từng đồng ý.');
    });

    test('đi một vòng JSON và copyWith', () {
      const p = NotificationPrefs(docBienDong: true);
      expect(NotificationPrefs.fromJson(p.toJson()).docBienDong, isTrue);
      expect(p.copyWith(docBienDong: false).docBienDong, isFalse);
      expect(p.copyWith(gioNhac: 9).docBienDong, isTrue,
          reason: 'copyWith không đụng tới thì giữ nguyên');
    });

    test('⭐ batNhom(bienDong) đọc CỜ, không đọc nhomTat', () {
      const bat = NotificationPrefs(
          docBienDong: true, nhomTat: {NotificationGroup.bienDong});
      expect(bat.batNhom(NotificationGroup.bienDong), isTrue,
          reason: 'nhomTat có chứa bienDong (bản ghi sửa tay / bản cũ) cũng '
              'không tắt được cờ — một công tắc, một nguồn sự thật.');
      const tat = NotificationPrefs(docBienDong: false);
      expect(tat.batNhom(NotificationGroup.bienDong), isFalse);
      expect(tat.batNhom(NotificationGroup.bill), isTrue,
          reason: 'các nhóm khác vẫn theo nhomTat như cũ');
    });

    test('⭐ Task 6: cờ dongYBienDong — mặc định CHƯA, đi một vòng JSON, tách khỏi docBienDong', () {
      expect(NotificationPrefs.macDinh.dongYBienDong, isFalse);
      expect(NotificationPrefs.fromJson({'docBienDong': true}).dongYBienDong, isFalse,
          reason: 'bản ghi không có khoá = chưa từng thấy màn xin đồng ý (backend bắt buộc) — '
              'đọc thành ĐÃ là bỏ qua màn ấy');
      const p = NotificationPrefs(dongYBienDong: true);
      expect(NotificationPrefs.fromJson(p.toJson()).dongYBienDong, isTrue);
      expect(p.copyWith(docBienDong: false).dongYBienDong, isTrue,
          reason: 'tắt tính năng KHÔNG xoá lần đồng ý — bật lại không hỏi lần nữa');
      expect(p == const NotificationPrefs(), isFalse);
      expect(p.hashCode == const NotificationPrefs().hashCode, isFalse);
    });

    test('hai bản chỉ khác docBienDong thì KHÔNG bằng nhau (canh == và hashCode)', () {
      const bat = NotificationPrefs(docBienDong: true);
      const tat = NotificationPrefs(docBienDong: false);
      expect(bat == tat, isFalse,
          reason: 'quên đưa trường mới vào == là hai bản khác cờ so ra bằng — '
              'trang Cài đặt bỏ qua một lần ghi vì "không đổi gì"');
      expect(bat.hashCode == tat.hashCode, isFalse);
    });

    test('loại bienDongSoDu thuộc nhóm bienDong, chịu công tắc, không luonBao', () {
      expect(nhomCua(NotificationKind.bienDongSoDu), NotificationGroup.bienDong);
      expect(luonBao(NotificationKind.bienDongSoDu), isFalse,
          reason: 'không phải tiền rời ví lúc vắng mặt — người dùng phải tắt '
              'được, nếu không họ tắt công tắc tổng');
      expect(
          const NotificationPrefs(docBienDong: true)
              .chapNhan(NotificationKind.bienDongSoDu),
          isTrue);
      expect(NotificationPrefs.macDinh.chapNhan(NotificationKind.bienDongSoDu),
          isFalse);
    });
  });
}
