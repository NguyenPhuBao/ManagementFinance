import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/goal/domain/goal_auto_deposit.dart';

void main() {
  group('mocKeTiep — bước sang kỳ kế tiếp', () {
    test('ngày, tuần, quý, năm', () {
      expect(mocKeTiep(DateTime(2026, 3, 10), 'Day'), DateTime(2026, 3, 11));
      expect(mocKeTiep(DateTime(2026, 3, 10), 'Week'), DateTime(2026, 3, 17));
      expect(mocKeTiep(DateTime(2026, 3, 10), 'Quarter'), DateTime(2026, 6, 10));
      expect(mocKeTiep(DateTime(2026, 3, 10), 'Year'), DateTime(2027, 3, 10));
    });

    test('chu kỳ trống hoặc lạ thì coi như hàng tháng', () {
      expect(mocKeTiep(DateTime(2026, 3, 10), null), DateTime(2026, 4, 10));
      expect(mocKeTiep(DateTime(2026, 3, 10), 'Fortnight'),
          DateTime(2026, 4, 10));
    });

    test('31/01 + 1 tháng là 28/02, KHÔNG phải 03/03', () {
      expect(mocKeTiep(DateTime(2026, 1, 31), 'Month'), DateTime(2026, 2, 28),
          reason: 'DateTime(2026, 2, 31) tự chuẩn hoá thành 03/03 chứ không '
              'ném lỗi. Không kẹp về ngày cuối tháng thì mọi mục tiêu đặt vào '
              'ngày 29–31 sẽ trôi dần sang tháng sau, mỗi kỳ một ít, và không '
              'có gì báo.');
    });

    test('31/01 + 1 tháng trong NĂM NHUẬN là 29/02', () {
      expect(mocKeTiep(DateTime(2028, 1, 31), 'Month'), DateTime(2028, 2, 29),
          reason: '2028 là năm nhuận. Kẹp cứng về 28 là mất một ngày mỗi bốn '
              'năm — đúng loại lỗi chỉ lộ ra sau khi bàn giao.');
    });

    test('31/01 + 1 quý là 30/04', () {
      expect(mocKeTiep(DateTime(2026, 1, 31), 'Quarter'), DateTime(2026, 4, 30),
          reason: 'Quý cũng là phép cộng THÁNG nên dính đúng cái bẫy ấy.');
    });

    test('29/02 năm nhuận + 1 năm là 28/02', () {
      expect(mocKeTiep(DateTime(2028, 2, 29), 'Year'), DateTime(2029, 2, 28),
          reason: 'Năm sau không có 29/02.');
    });

    test('giữ nguyên giờ phút của mốc', () {
      expect(mocKeTiep(DateTime(2026, 3, 10, 8, 30), 'Month'),
          DateTime(2026, 4, 10, 8, 30),
          reason: 'Mốc trích là một thời điểm, không phải một ngày. Cắt giờ đi '
              'làm kỳ đầu tiên đến sớm hơn dự tính tới gần một ngày.');
    });
  });

  group('cacKyDenHan — những kỳ đã tới hạn', () {
    test('chưa tới kỳ nào thì rỗng', () {
      final ra = cacKyDenHan(
        lanChayGanNhat: DateTime(2026, 9, 5),
        chuKy: 'Month',
        now: DateTime(2026, 9, 20),
      );
      expect(ra, isEmpty,
          reason: 'Bật công tắc ngày 5 thì kỳ đầu tiên rơi vào ngày 5 tháng '
              'sau. Trích ngay lúc bật là lấy tiền người dùng chưa đồng ý.');
    });

    test('đúng một kỳ đã qua', () {
      final ra = cacKyDenHan(
        lanChayGanNhat: DateTime(2026, 8, 5),
        chuKy: 'Month',
        now: DateTime(2026, 9, 20),
      );
      expect(ra, [DateTime(2026, 9, 5)]);
    });

    test('bỏ app nhiều tháng thì trả về ĐỦ các kỳ, theo thứ tự', () {
      final ra = cacKyDenHan(
        lanChayGanNhat: DateTime(2026, 6, 15),
        chuKy: 'Month',
        now: DateTime(2026, 9, 20),
      );
      expect(ra, [
        DateTime(2026, 7, 15),
        DateTime(2026, 8, 15),
        DateTime(2026, 9, 15),
      ]);
    });

    test('mốc rơi ĐÚNG hiện tại thì tính là đã tới hạn', () {
      final ra = cacKyDenHan(
        lanChayGanNhat: DateTime(2026, 8, 5),
        chuKy: 'Month',
        now: DateTime(2026, 9, 5),
      );
      expect(ra, [DateTime(2026, 9, 5)],
          reason: 'Biên phải nằm về phía "đã tới hạn", nếu không kỳ ấy trượt '
              'sang lượt chạy sau mà không có lý do nào giải thích được.');
    });

    test('có TRẦN số kỳ mỗi lượt chạy', () {
      final ra = cacKyDenHan(
        lanChayGanNhat: DateTime(2020, 1, 1),
        chuKy: 'Day',
        now: DateTime(2026, 9, 20),
        toiDa: 12,
      );
      expect(ra.length, 12,
          reason: 'Máy để lâu không mở, chu kỳ ngày, là hàng nghìn kỳ. Trích '
              'hết trong một lượt sẽ rút cạn ví nguồn ngay khi người dùng vừa '
              'mở app. Phần dư để lượt sau xử lý tiếp — không mất kỳ nào.');
      expect(ra.first, DateTime(2020, 1, 2),
          reason: 'Cắt ở ĐUÔI, không ở đầu: các kỳ phải chạy theo đúng thứ tự '
              'thời gian, nếu không mốc chạy gần nhất sẽ nhảy cóc.');
    });

    test('chưa từng chạy lần nào thì không đoán bừa', () {
      expect(
        cacKyDenHan(
          lanChayGanNhat: null,
          chuKy: 'Month',
          now: DateTime(2026, 9, 20),
        ),
        isEmpty,
        reason: 'Mốc null nghĩa là chưa bật trích tự động. Lấy ngày tạo mục '
            'tiêu làm mốc là bật công tắc hôm nay rồi bị trích ngược lại sáu '
            'tháng cùng một lúc.',
      );
    });
  });

  group('quyetDinhTrich — trích bao nhiêu cho MỘT kỳ', () {
    test('đủ tiền và còn thiếu nhiều thì trích đúng số đã cài', () {
      final qd = quyetDinhTrich(
          soTienCai: 500000, conThieu: 2000000, soDuViNguon: 900000);
      expect(qd.loai, LoaiTrich.trichDu);
      expect(qd.soTien, 500000);
    });

    test('còn thiếu ÍT hơn số cài thì chỉ trích phần còn thiếu', () {
      final qd = quyetDinhTrich(
          soTienCai: 500000, conThieu: 120000, soDuViNguon: 900000);
      expect(qd.loai, LoaiTrich.trichPhanConLai);
      expect(qd.soTien, 120000,
          reason: 'Nạp vượt mục tiêu bằng tay thì app CẢNH BÁO rồi cho qua — '
              'người dùng đang nhìn màn hình. Trích tự động thì họ vắng mặt, '
              'nên vượt bao nhiêu cũng không ai duyệt. Kẹp ở phần còn thiếu.');
    });

    test('ví nguồn không đủ thì KHÔNG trích một phần', () {
      final qd = quyetDinhTrich(
          soTienCai: 500000, conThieu: 2000000, soDuViNguon: 300000);
      expect(qd.loai, LoaiTrich.viKhongDu);
      expect(qd.soTien, 0,
          reason: 'Trích một phần làm sổ sách khó đọc (một kỳ ra hai con số '
              'khác nhau) và vẫn không giải quyết được việc thiếu tiền. Bỏ kỳ '
              'đó và BÁO cho người dùng.');
    });

    test('ví vừa đủ đúng bằng số cần trích thì vẫn trích', () {
      final qd = quyetDinhTrich(
          soTienCai: 500000, conThieu: 2000000, soDuViNguon: 500000);
      expect(qd.loai, LoaiTrich.trichDu,
          reason: 'Số dư 0 sau khi trích là hợp lệ; chỉ số dư ÂM mới sai. '
              'Chặt hơn ở đây là từ chối một thao tác đúng.');
    });

    test('mục tiêu đã đủ thì dừng hẳn', () {
      final qd = quyetDinhTrich(
          soTienCai: 500000, conThieu: 0, soDuViNguon: 900000);
      expect(qd.loai, LoaiTrich.mucTieuDaXong);
      expect(qd.soTien, 0);
    });

    test('số cài ≤ 0 thì không trích', () {
      expect(
        quyetDinhTrich(soTienCai: 0, conThieu: 2000000, soDuViNguon: 900000)
            .loai,
        LoaiTrich.mucTieuDaXong,
        reason: 'Không có số tiền hợp lệ thì không có gì để trích. Trả về một '
            'nhánh DỪNG chứ không phải nhánh "thiếu tiền" — báo "ví không đủ" '
            'cho một cấu hình sai làm người dùng đi nạp tiền vô ích.',
      );
    });
  });

  group('khoaKyTrich — khoá chống trùng của một kỳ', () {
    test('cùng mục tiêu, cùng kỳ thì cùng khoá', () {
      expect(
        khoaKyTrich('g1', DateTime(2026, 9, 5, 8, 30)),
        khoaKyTrich('g1', DateTime(2026, 9, 5, 21, 0)),
        reason: 'Khoá gộp theo NGÀY. Hai lượt chạy trong cùng một ngày cho '
            'cùng một kỳ phải ra cùng một khoá, nếu không mỗi lần mở app lại '
            'đẻ thêm một thông báo cho việc đã làm rồi.',
      );
    });

    test('khác mục tiêu hoặc khác kỳ thì khác khoá', () {
      expect(khoaKyTrich('g1', DateTime(2026, 9, 5)),
          isNot(khoaKyTrich('g2', DateTime(2026, 9, 5))));
      expect(khoaKyTrich('g1', DateTime(2026, 9, 5)),
          isNot(khoaKyTrich('g1', DateTime(2026, 10, 5))));
    });
  });
}
